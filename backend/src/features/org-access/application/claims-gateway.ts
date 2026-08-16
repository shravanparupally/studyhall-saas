import { OrgAccessClaims } from '../domain/org-access';

/**
 * A repository-shaped port for reading/writing a user's `orgAccess` custom
 * claim, per docs/15_Technical_Architecture.md §15.15's Repository
 * Pattern — the use cases in this feature depend on this interface only,
 * never on `firebase-admin` directly, so they're unit-testable with a fake.
 */
export interface ClaimsGateway {
  getCurrentClaims(userId: string): Promise<OrgAccessClaims>;
  setClaims(userId: string, claims: OrgAccessClaims): Promise<void>;
}
