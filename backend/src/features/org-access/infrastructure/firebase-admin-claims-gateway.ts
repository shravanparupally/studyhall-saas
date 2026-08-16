import * as admin from 'firebase-admin';
import { ClaimsGateway } from '../application/claims-gateway';
import { OrgAccessClaims } from '../domain/org-access';

/**
 * The only place this feature imports `firebase-admin` directly, per
 * docs/15_Technical_Architecture.md §15.15 applied to the backend.
 */
export class FirebaseAdminClaimsGateway implements ClaimsGateway {
  async getCurrentClaims(userId: string): Promise<OrgAccessClaims> {
    const user = await admin.auth().getUser(userId);
    return (user.customClaims?.orgAccess as OrgAccessClaims | undefined) ?? {};
  }

  async setClaims(userId: string, claims: OrgAccessClaims): Promise<void> {
    await admin.auth().setCustomUserClaims(userId, { orgAccess: claims });
  }
}
