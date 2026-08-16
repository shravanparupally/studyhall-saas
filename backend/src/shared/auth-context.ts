/**
 * Resolves and checks a Cloud Function caller's authority from their ID
 * token's `orgAccess` custom claim — the Cloud Functions surface's
 * independent enforcement layer.
 *
 * Per docs/08_System_Architecture.md §8.5 and
 * docs/15_Technical_Architecture.md §15.26: Cloud Functions run with
 * Admin SDK privileges that bypass Firestore security rules entirely, so
 * every HTTPS callable handler re-derives the caller's `orgAccess` claim
 * and checks it against the target organizationId/branchId *in code*,
 * independently of firestore.rules. This module is that check,
 * deliberately duplicating the `hasOrgAccess`/`isOwner`/`canAccessBranch`
 * logic in firestore.rules — neither layer is ever "covered by the other
 * one anyway."
 */

export type OrgAccessClaim = { role: 'owner' } | { role: 'receptionist'; branchId: string };

/** The full custom-claims shape issued to a user's Firebase Auth token. */
export type OrgAccessClaims = Record<string, OrgAccessClaim>;

export interface CallerAuthContext {
  uid: string;
  orgAccess: OrgAccessClaims;
}

function isOrgAccessClaim(value: unknown): value is OrgAccessClaim {
  if (typeof value !== 'object' || value === null) return false;
  const record = value as Record<string, unknown>;
  if (record.role === 'owner') return true;
  return record.role === 'receptionist' && typeof record.branchId === 'string';
}

function isOrgAccessClaims(value: unknown): value is OrgAccessClaims {
  if (typeof value !== 'object' || value === null) return false;
  return Object.values(value as Record<string, unknown>).every(isOrgAccessClaim);
}

/**
 * Resolves the caller's authority from the Functions v2 `CallableRequest.auth`
 * value. Returns `null` for an unauthenticated caller — the handler is
 * responsible for rejecting that case explicitly.
 */
export function resolveCallerAuthContext(
  auth: { uid: string; token: Record<string, unknown> } | undefined,
): CallerAuthContext | null {
  if (!auth) return null;
  const rawClaim = auth.token.orgAccess;
  const orgAccess = isOrgAccessClaims(rawClaim) ? rawClaim : {};
  return { uid: auth.uid, orgAccess };
}

/** True when `context` holds org-wide Owner access to `organizationId`. */
export function isOwnerOf(context: CallerAuthContext, organizationId: string): boolean {
  return context.orgAccess[organizationId]?.role === 'owner';
}

/**
 * True when `context` can access `branchId` under `organizationId` — an
 * Owner of the Organization (every Branch, uniformly), or the one
 * Receptionist assigned to this specific Branch. Mirrors
 * `canAccessBranch()` in firestore.rules exactly.
 */
export function canAccessBranch(context: CallerAuthContext, organizationId: string, branchId: string): boolean {
  const access = context.orgAccess[organizationId];
  if (!access) return false;
  return access.role === 'owner' || (access.role === 'receptionist' && access.branchId === branchId);
}
