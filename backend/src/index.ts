import * as admin from 'firebase-admin';

admin.initializeApp();

export { onOwnerWrite } from './features/org-access/presentation/on-owner-write';
export { onReceptionistWrite } from './features/org-access/presentation/on-receptionist-write';
export { inviteReceptionist } from './features/receptionist/presentation/invite-receptionist';
export { reassignReceptionist } from './features/receptionist/presentation/reassign-receptionist';
