# 07. Firestore Schema

Physical mapping of the logical model in [`06_Database_Design.md`](06_Database_Design.md)
onto Firestore. Every decision here is an *infrastructure* decision in Clean
Architecture terms (see [`08_System_Architecture.md`](08_System_Architecture.md))
— the domain layer must not leak these shapes upward.

**This revision's driving constraint**: multi-branch is a core domain
concept (see [`06_Database_Design.md`](06_Database_Design.md) §6.6), so the
physical schema is structured so that Branch isolation is enforced by the
*shape of the data itself* — a document's path, not just a field a query
might forget to filter on.

## 7.1 Collection layout strategy

**Nearly everything Branch-scoped is a subcollection under
`/organizations/{organizationId}/branches/{branchId}/...`.** This is a
deliberate change from treating Branch-scoped data as top-level collections
with a `branchId` field: nesting makes the Branch boundary structural —
there is no way to construct a Firestore reference to a Seat, Student,
Enrollment, FeeCycle, Payment, or Attendance record without supplying the
`organizationId` and `branchId` segments first. A query, a security rule,
or a repository method literally cannot address this data without a Branch
context, because the address requires one. This is what "enforced by
design" means concretely, and it is the direct data-layer answer to the
two-tier access model in [`06_Database_Design.md`](06_Database_Design.md)
§6.6: an Owner's `orgAccess` claim grants them the parent
`/organizations/{orgId}/branches/*` path; a Receptionist's grants them
exactly one `branches/{branchId}` subtree.

Two things are **not** Branch-nested, because they are not Branch
operational data:

- **Organization-level**: `/organizations/{orgId}`, its `owners`
  subcollection, and `/platformSubscriptions/{orgId}` (our billing
  relationship with the Organization — not a Branch concern at all).
- **Platform-level**: `/roles/{roleId}` (mostly static platform defaults)
  and `/auditLog/{entryId}` (server-side-only, written via the Admin SDK,
  never exposed to client Firestore access — see §7.4).

Every Branch-scoped document **also** carries `organizationId` and
`branchId` as plain fields, even though they're already encoded in the
path. This looks redundant but is required: Firestore `collectionGroup`
queries (used for the legitimate cross-Branch cases — an Owner's
multi-branch rollup, Platform Admin lookups) can only filter on fields, not
path segments.

## 7.2 Collections

### `/organizations/{organizationId}`
```
name: string
status: "setup_incomplete" | "active" | "suspended"
createdAt: timestamp
```

### `/organizations/{organizationId}/owners/{userId}`
Document ID **is** the owner's `userId` — makes "is this user an Owner of
this Organization" a direct key lookup, not a query, and is the source
document a Cloud Function reads to (re)issue that user's Auth custom claims
(§7.4).
```
name: string
phoneNumber: string
addedAt: timestamp
addedBy: string        // userId of the owner who added them (co-owner support)
```

### `/organizations/{organizationId}/branches/{branchId}`
```
name: string
address: string
geoLocation: geopoint
contactPhone: string
operatingHours: map<dayOfWeek, {open: string, close: string}>
timezone: string
status: "active" | "inactive"
createdAt: timestamp
```

### `/organizations/{organizationId}/branches/{branchId}/receptionists/{userId}`
Document ID **is** the receptionist's `userId` — a person can be a
Receptionist of at most one Branch at a time by construction (creating a
second `receptionists/{userId}` doc under a different Branch is a distinct
assignment and is exactly how a reassignment is modeled: revoke the old,
create the new — never a merge).
```
name: string
phoneNumber: string
status: "active" | "revoked"
invitedAt: timestamp
acceptedAt: timestamp | null
invitedBy: string       // ownerUserId
```

### `/organizations/{organizationId}/branches/{branchId}/seats/{seatId}`
```
label: string              // "A-12"
zone: string                // "Ground Floor"
seatType: "ac" | "non_ac"
layout: "cabin" | "open"
hasLocker: boolean
status: "active" | "maintenance" | "inactive"
```
No occupancy field — see [`06_Database_Design.md`](06_Database_Design.md)
§6.4. Current occupancy is served by a denormalized **read model** (§7.6),
never stored here.

### `/organizations/{organizationId}/branches/{branchId}/shifts/{shiftId}`
```
name: string                // "Morning"
startTime: string           // "06:00"
endTime: string             // "14:00"
activeDays: array<number>   // [1,2,3,4,5,6,7]
isActive: boolean
```

### `/organizations/{organizationId}/branches/{branchId}/membershipPlans/{planId}`
```
shiftId: string
seatType: "ac" | "non_ac"
durationMonths: number
price: number                // paise, integer — never float currency
isActive: boolean
createdAt: timestamp
```

### `/organizations/{organizationId}/branches/{branchId}/lockers/{lockerId}`
```
label: string
linkedSeatId: string | null
status: "available" | "assigned" | "maintenance"
```

### `/organizations/{organizationId}/branches/{branchId}/expenses/{expenseId}`
```
category: string
amount: number
note: string
incurredAt: timestamp
recordedBy: string           // userId
```

### `/organizations/{organizationId}/branches/{branchId}/coupons/{couponId}`
```
code: string
discountType: "flat" | "percent"
value: number
validFrom: timestamp
validTo: timestamp
usageLimit: number
timesUsed: number
```

### `/organizations/{organizationId}/branches/{branchId}/students/{studentId}`
```
organizationId: string        // denormalized, see §7.1
branchId: string                // denormalized, see §7.1
authUid: string | null          // links to Firebase Auth once the person signs in themselves
phoneNumber: string
name: string
photoUrl: string | null
idDocumentUrl: string | null    // access-controlled, see §7.4
createdAt: timestamp
```
**Branch-owned, per [`06_Database_Design.md`](06_Database_Design.md) §6.3**
— the same person enrolling at a different Branch gets a distinct document
here, not a shared one. `authUid` is what lets one sign-in resolve to
possibly multiple Branch-owned Student records (§7.3's `authUid`
collection-group index is what makes that lookup efficient).

### `/organizations/{organizationId}/branches/{branchId}/enrollments/{enrollmentId}`
```
organizationId: string        // denormalized
branchId: string                // denormalized
studentId: string
seatId: string
shiftId: string
planId: string
planSnapshot: { durationMonths: number, price: number, seatType: string }
startDate: timestamp
endDate: timestamp
status: "active" | "overdue" | "at_risk" | "ended" | "cancelled"
// Denormalized for list-view rendering without extra reads:
studentName: string
studentPhone: string
seatLabel: string
shiftName: string
createdAt: timestamp
updatedAt: timestamp
```

### `/organizations/{organizationId}/branches/{branchId}/enrollments/{enrollmentId}/feeCycles/{feeCycleId}`
```
organizationId: string        // denormalized
branchId: string                // denormalized
periodStart: timestamp
periodEnd: timestamp
dueDate: timestamp
amountDue: number
amountPaid: number
status: "pending" | "partially_paid" | "paid" | "overdue"
```
Branch-wide "all overdue" dashboards query a `collectionGroup('feeCycles')`
filtered by `branchId` (§7.3) — this is the one place a `collectionGroup`
query is the primary access path, not a fallback, and it's indexed
accordingly.

### `/organizations/{organizationId}/branches/{branchId}/enrollments/{enrollmentId}/feeCycles/{feeCycleId}/payments/{paymentId}`
```
organizationId: string        // denormalized
branchId: string                // denormalized
amount: number
method: "cash" | "upi" | "card" | "other"
recordedBy: string            // userId, or "student_self_service"
gatewayReference: string | null
status: "succeeded" | "refunded"
refundOf: string | null       // paymentId this refunds, if applicable
createdAt: timestamp
```
Append-only by convention and by security rule (§7.4) — no `update`/`delete`
rule is granted on this path at all, ever, including to Owners.

### `/organizations/{organizationId}/branches/{branchId}/enrollments/{enrollmentId}/attendance/{attendanceId}`
```
organizationId: string        // denormalized
branchId: string                // denormalized
studentId: string             // denormalized
checkInAt: timestamp
checkOutAt: timestamp | null
method: "qr_staff" | "qr_self" | "biometric" | "geofence"
recordedBy: string
```

### `/organizations/{organizationId}/branches/{branchId}/announcements/{announcementId}`
```
title: string
body: string
audienceFilter: "all" | "overdue_only" | "custom"
channels: array<"push"|"sms"|"whatsapp">
sentAt: timestamp
```

### `/organizations/{organizationId}/branches/{branchId}/waitlistEntries/{entryId}` *(P1)*
```
shiftId: string
seatType: string
studentPhone: string
requestedAt: timestamp
status: "waiting" | "offered" | "expired" | "converted"
```

### `/organizations/{organizationId}/branches/{branchId}/seatShiftLocks/{seatId}_{shiftId}`
```
activeEnrollmentId: string | null
```
The double-booking concurrency guard — see §7.5.

### `/organizations/{organizationId}/branches/{branchId}/dashboardStats/current`
```
occupiedSeatsByShift: map<shiftId, number>
totalSeatsByShift: map<shiftId, number>
overdueCount: number
overdueAmount: number
todayCheckIns: number
updatedAt: timestamp
```
The Branch's "Reports" read model — see §7.6.

### `/platformSubscriptions/{organizationId}`
Document ID **is** the `organizationId` — enforces the "exactly one current
Subscription per Organization" invariant (FR-11.1) structurally.
```
planTier: "starter" | "growth" | "pro" | "enterprise"
billingCycle: "monthly" | "annual"
status: "trialing" | "active" | "past_due" | "suspended" | "cancelled"
currentPeriodStart: timestamp
currentPeriodEnd: timestamp
seatLimit: number
branchLimit: number
staffLimit: number
messagingCreditsRemaining: number
```

### `/platformSubscriptions/{organizationId}/history/{eventId}`
```
type: "created" | "upgraded" | "downgraded" | "renewed" | "suspended" | "cancelled" | "trial_extended"
fromTier: string | null
toTier: string | null
actorId: string
at: timestamp
```

### `/roles/{roleId}`
```
organizationId: string | null  // null = platform-default role (Owner, Receptionist)
name: string
permissions: array<string>
```
At MVP, Owner and Receptionist are fixed platform-default rows, not
independently configurable per Organization — the collection exists now so
custom, still-Branch-scoped roles (P1) don't require a schema change later.

### `/auditLog/{entryId}`
```
organizationId: string
branchId: string | null        // null for org-level events (e.g. subscription changes)
actorId: string
actorType: "user" | "platform_admin" | "system_job"
action: string                 // "payment.recorded", "subscription.suspended", ...
entityType: string
entityId: string
beforeSnapshot: map | null
afterSnapshot: map | null
at: timestamp
```
Written only by Cloud Functions via the Admin SDK — never directly reachable
by any client Firestore call, Owner or Receptionist included (§7.4).

### `/leads/{leadId}`, `/reviews/{reviewId}` *(P2 — discovery)*
Deferred detail until Phase 2 scoping. When designed, `Review` will follow
the same Branch-nesting pattern (`/organizations/{orgId}/branches/{branchId}/reviews/{id}`)
for consistency, since a review is inherently about one Branch.

## 7.3 Indexes

Composite indexes required beyond Firestore's automatic single-field
indexes. Note how few of these are `collectionGroup` indexes now that
Branch-scoped data is nested — most Owner/Receptionist queries are answered
by a direct subcollection query against a known `branchId`, requiring no
cross-Branch index at all.

| Collection (or collection group) | Fields | Serves |
|---|---|---|
| `enrollments` (within a Branch) | `status ASC` | Branch seat map / roster — no collectionGroup needed, this is a direct subcollection query |
| `students` (collectionGroup) | `authUid ASC` | Resolving a Student's sign-in to their Branch-owned record(s) — the one legitimate cross-Branch Student query (§7.2) |
| `feeCycles` (collectionGroup) | `branchId ASC, status ASC, dueDate ASC` | Owner "overdue" dashboard for one Branch |
| `feeCycles` (collectionGroup) | `organizationId ASC, periodStart ASC` | Owner's cross-Branch revenue rollup (P1) |
| `payments` (collectionGroup) | `branchId ASC, createdAt DESC` | Revenue-by-date-range reports for one Branch |
| `attendance` (collectionGroup) | `branchId ASC, checkInAt DESC` | Branch daily attendance view |
| `auditLog` | `organizationId ASC, at DESC` | Platform Admin / Owner audit views |
| `auditLog` | `branchId ASC, at DESC` | Branch-scoped audit views |

## 7.4 Security model

**Authentication**: Firebase Auth, phone number as the sign-in method for
Owners, Receptionists, and Students alike (consistent with the phone-first
identity decision in the [PRD](02_Product_Requirements_Document.md) §2.7).

**Authorization**: Cloud Function triggers on writes to
`/organizations/{orgId}/owners/{userId}` and
`/organizations/{orgId}/branches/{branchId}/receptionists/{userId}` compute
and set that user's Firebase Auth custom claims:
```
orgAccess: {
  [organizationId]: { role: "owner" }
                     | { role: "receptionist", branchId: "<the one branch>" }
}
```
An Owner's claim carries no `branchId` at all — access to every Branch
follows from `role == "owner"` alone, which is exactly the "Owners can
access every branch" requirement expressed as a token claim rather than a
per-Branch grant that could drift out of sync. A Receptionist's claim
carries exactly one `branchId`; being assigned to a second Branch would
require a second, distinct claim entry, which the invite flow does not
offer (BR-23/24) — a Receptionist is, by construction, single-Branch.

Claims are re-issued (and the client forced to refresh its token) on every
`owners`/`receptionists` write, so revocation takes effect on next token
refresh, not "eventually." Custom claims (not a `get()`-based rule lookup)
are used deliberately for performance: this check runs on every single
Firestore call the app makes, and a claims-based check costs nothing extra
per call, whereas a document-lookup-based rule would add a read (and
latency) to every operation — unacceptable given the front-desk speed
requirement in [`03_User_Personas.md`](03_User_Personas.md) §3.2.

Representative rule shape (illustrative, not final syntax) — note that a
**single rule block governs the entire Branch subtree**, so no current or
future nested collection under a Branch can be reached by an unauthorized
user; this is the concrete mechanism behind "Firestore queries and security
rules must enforce branch isolation by design":
```
function hasOrgAccess(orgId) {
  return request.auth != null
    && 'orgAccess' in request.auth.token
    && orgId in request.auth.token.orgAccess;
}
function access(orgId) { return request.auth.token.orgAccess[orgId]; }
function isOwner(orgId) {
  return hasOrgAccess(orgId) && access(orgId).role == "owner";
}
function canAccessBranch(orgId, branchId) {
  return hasOrgAccess(orgId)
    && (access(orgId).role == "owner" || access(orgId).branchId == branchId);
}

// One rule covers every collection nested under a Branch, present or future.
match /organizations/{orgId}/branches/{branchId}/{document=**} {
  allow read: if canAccessBranch(orgId, branchId);
  allow write: if canAccessBranch(orgId, branchId);
}

// Branch configuration (pricing, shifts, seat inventory, receptionist
// assignment) is tightened to Owner-only writes, layered on top of the
// broader read rule above:
match /organizations/{orgId}/branches/{branchId}/{coll}/{docId} {
  allow write: if coll in ["shifts", "membershipPlans", "seats", "lockers",
                            "coupons", "receptionists"]
    ? isOwner(orgId)
    : canAccessBranch(orgId, branchId);   // day-to-day ops: students,
                                            // enrollments, attendance
}

// Payments are append-only, no exceptions, not even for Owners:
match /organizations/{orgId}/branches/{branchId}/enrollments/{eId}/feeCycles/{fId}/payments/{pId} {
  allow read: if canAccessBranch(orgId, branchId);
  allow create: if canAccessBranch(orgId, branchId);
  allow update, delete: if false;
}

// A Student's own read access to their Branch-owned record, via their
// linked sign-in — independent of Owner/Receptionist access:
match /organizations/{orgId}/branches/{branchId}/students/{studentId} {
  allow read: if canAccessBranch(orgId, branchId)
    || (request.auth != null && resource.data.authUid == request.auth.uid);
}

match /organizations/{orgId} {
  allow read: if hasOrgAccess(orgId);
  allow write: if isOwner(orgId);
}
```

This is what makes NFR-1 (cross-tenant isolation) and FR-1.4/FR-7.4
(Branch isolation) **database-enforced** guarantees: even a bug in
application/Cloud-Function *client-facing* code cannot leak data across
Organization or Branch boundaries, because the rules engine blocks it
independent of what the calling code intended.

**The one place this guarantee does not automatically apply: server-side
Cloud Functions using the Admin SDK**, which bypasses Firestore security
rules entirely by design (that's what lets `generateFeeCycles`,
`sendDueReminders`, and Platform Admin tooling operate across every
Organization). This means Branch/Organization isolation for
*server-side* code is an application-layer responsibility, not a rules-layer
one — see [`08_System_Architecture.md`](08_System_Architecture.md) §8.5 for
how every Cloud Function handler is required to resolve and check the
caller's `orgAccess` scope explicitly before invoking a use case, precisely
because the rules engine isn't there to catch a mistake on that path.

**Platform Admin access** runs exclusively through server-side Cloud
Functions (Admin SDK), with every call individually authorized against the
admin's own role and logged to `/auditLog` (§7.2) — this keeps "can bypass
tenant/branch isolation" confined to a small, audited, server-side surface
instead of being a client security-rule edge case.

**Sensitive fields** (`idDocumentUrl`, phone numbers) are stored in
Firestore/Storage with access rules mirroring the same `orgAccess` claim
check as above, scoped to the specific Branch that owns the relevant
Student/Enrollment.

## 7.5 Concurrency: preventing double-booking

Firestore transactions cannot run an arbitrary query and then act on it
atomically across documents in a way that's safe under high contention.
Instead, the dedicated lock document per (Seat, Shift) introduced in
[`06_Database_Design.md`](06_Database_Design.md) — now at
`/organizations/{orgId}/branches/{branchId}/seatShiftLocks/{seatId}_{shiftId}`
— makes the guard explicit and atomic.

Creating an Enrollment for a given Seat+Shift is a single Firestore
transaction that: reads the lock doc, verifies `activeEnrollmentId` is
`null` (or belongs to an Enrollment whose date range doesn't overlap the
new one), writes the new Enrollment, and updates the lock doc — all inside
one transaction. A concurrent second attempt fails the transaction's
optimistic read-write conflict check and retries against the now-updated
lock, correctly seeing the seat as taken (this is the mechanism behind the
"seat just taken, choose another" failure path in
[`04_User_Flows.md`](04_User_Flows.md) §4.2).

## 7.6 Derived/read-model data

Dashboard aggregates (occupancy %, total overdue ₹, today's attendance
count) — the "Reports" a Branch owns — are **not** computed client-side over
raw collections at read time. Cloud Function triggers on
`enrollments`, `feeCycles`, and `attendance` writes maintain the
`dashboardStats/current` document (§7.2) per Branch. This is the standard
Firestore "maintain an aggregate document via triggers" pattern, and it's
what keeps the Owner's morning-review dashboard
(FR-8.1/[`04_User_Flows.md`](04_User_Flows.md) §4.4) fast regardless of how
much historical data a Branch has accumulated — reads scale with "1
document per Branch," not "every Enrollment ever created at that Branch."

An Owner viewing a roll-up across all their Branches (P1) reads *N* such
documents — one per Branch — rather than a single cross-Branch aggregate
document, preserving the same per-Branch write-rate isolation described in
[`08_System_Architecture.md`](08_System_Architecture.md) §8.13.

## 7.7 Numeric & currency conventions

All money fields are integers in the smallest currency unit (paise), never
floats — this is a hard rule, not a style preference, given this system's
entire value proposition rests on the fee numbers being trustworthy (NFR-6).
Dates/times are stored as Firestore `timestamp`, always written and read in
UTC, converted to the Branch's `timezone` only at the presentation layer.
