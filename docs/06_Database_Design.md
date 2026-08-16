# 06. Database Design

This document defines the **logical data model**: entities, their key
attributes, and their relationships — independent of the physical database
engine. The physical mapping onto Firestore (collection layout, denormalization,
indexes, security rules) is in [`07_Firestore_Schema.md`](07_Firestore_Schema.md).
Keeping these separate is deliberate: per Clean Architecture (see
[`08_System_Architecture.md`](08_System_Architecture.md)), the domain model
must not be defined in terms of a specific database's document/collection
shape.

## 6.1 Why this order matters

Firestore is a document database with no joins and no enforced foreign keys.
It is tempting to design "Firestore-shaped" from the start, but that produces
a model that's hard to reason about and hard to migrate. Instead: model the
real-world entities and relationships first, as if for any relational or
document store, then deliberately decide denormalization/embedding trade-offs
in §07 with the access patterns from [`04_User_Flows.md`](04_User_Flows.md)
as the driver.

## 6.2 Entity overview

| Entity | Summary |
|---|---|
| **Organization** | A Study Hall business — the SaaS tenant. |
| **PlatformSubscription** | The Organization's billing relationship with us. |
| **Branch** | A physical location owned by an Organization. |
| **Shift** | A named recurring time window defined per Branch. |
| **Seat** | An individually bookable unit of space within a Branch. |
| **Locker** | An individually assignable storage unit, optionally tied to a Seat/Branch. |
| **MembershipPlan** | A priced (Shift × Seat Type × Duration) offering, defined per Branch. |
| **Student** | A Branch-owned roster record — a person's membership relationship with one specific Branch. |
| **Enrollment** | A Student's instance of holding a Plan on a Seat at a Branch, over a date range. |
| **FeeCycle** | A single billing period's due amount within an Enrollment's lifetime. |
| **Payment** | A recorded money movement against a FeeCycle (online or manual/cash). |
| **Attendance** | A single check-in (and optional check-out) event against an Enrollment. |
| **StaffMembership** | An Owner's org-wide grant, or a Receptionist's single-Branch grant — see §6.3 for why these are two distinct concrete forms. |
| **Role** | A named permission set. |
| **Expense** | A manually recorded outgoing cost against a Branch. |
| **Announcement** | A broadcast message from a Branch to a set of Students. |
| **Coupon** | A discount code applicable to Plans. |
| **Waitlist Entry** | A Student's queued request for a full Seat/Shift. |
| **AuditLogEntry** | An immutable record of a sensitive mutation. |
| **Lead / Review** *(P2)* | Discovery-portal entities: a prospective Student's interest, and post-visit ratings. |

## 6.3 Entity detail

### Organization
- `id`, `name`, `createdAt`, `status` (active / suspended / setup_incomplete)
- Owns: many Branches, one current PlatformSubscription (+ history)
- **This is the tenancy root.** Every Branch-scoped entity ultimately traces
  back to exactly one Organization. See §6.6.

### PlatformSubscription
- `organizationId`, `planTier`, `billingCycle`, `status` (trialing / active /
  past_due / suspended / cancelled), `currentPeriodStart/End`, `seatLimit`,
  `branchLimit`, `staffLimit`, `messagingCreditsRemaining`
- One *current* record per Organization; changes over time are historized
  (see [`11_Subscription_Model.md`](11_Subscription_Model.md)), never
  overwritten silently — a plan change is an event, not just a field update.

### Branch
- `id`, `organizationId`, `name`, `address`, `geoLocation`, `contactPhone`,
  `operatingHours`, `timezone`, `status` (active / inactive)
- Owns: many Shifts, Seats, Lockers, MembershipPlans, Expenses,
  Announcements, Students, Enrollments, and Receptionist grants — see §6.6.
  This is the complete list of what "a Branch has its own X" (per FR-1.4)
  means concretely.

### Shift
- `id`, `branchId`, `name`, `startTime`, `endTime`, `activeDays[]`
- Branch-defined, not a global enum — different Branches run different shift
  structures (e.g. some sell a "Night" shift, some don't).

### Seat
- `id`, `branchId`, `label`, `zone`, `seatType` (AC/Non-AC, Cabin/Open),
  `hasLocker`, `status` (active / maintenance / inactive)
- A Seat's *occupancy* is not a field on the Seat itself — it is derived from
  active Enrollments referencing it per Shift (see §6.4, "no stored
  occupancy state"). This avoids two sources of truth going out of sync.

### Locker
- `id`, `branchId`, `label`, `status` (available / assigned / maintenance)
- Optionally linked 1:1 to a Seat, or independently assignable depending on
  the Branch's physical layout.

### MembershipPlan
- `id`, `branchId`, `shiftId`, `seatType`, `durationMonths`, `price`,
  `isActive`
- Immutable once referenced by an active Enrollment's pricing snapshot (see
  FR-3.3 in the [PRD](02_Product_Requirements_Document.md)) — price changes
  create a new effective version, they do not mutate history.

### Student
- `id`, `branchId`, `organizationId`, `authUid` (nullable — links to the
  person's Firebase Auth account once they've signed in; a Student can
  exist as a Staff-entered roster record before the person has ever signed
  in themselves, e.g. an offline walk-in), `phoneNumber`, `name`,
  `photoUrl`, `idDocumentUrl` (access-controlled), `createdAt`
- **Owned entirely by its Branch** (FR-1.4, FR-4.4) — this is a deliberate
  simplification from an earlier draft of this model that treated Student
  as a platform-level identity. A Branch-owned Student record is what
  "each Branch has its own Students" (isolation requirement) means
  concretely: a person enrolling at two different Branches (their own
  Organization's second Branch, or an entirely different Organization) is
  represented as two separate, fully independent Student records — never
  one record with cross-Branch visibility. See §6.6 for why this is the
  stronger and simpler choice given the isolation requirement, and how the
  person still gets a single sign-in identity (`authUid`) despite their
  data being fully partitioned.

### Enrollment
- `id`, `studentId`, `organizationId`, `branchId`, `seatId`, `shiftId`,
  `planId` (+ a frozen price snapshot), `startDate`, `endDate`,
  `status` (active / overdue / at_risk / ended / cancelled)
- The central join entity: Student ↔ Branch ↔ Seat ↔ Shift ↔ Plan, over a
  concrete time range. Owns many FeeCycles and Attendance records.
- **Invariant**: no two Enrollments may hold `active` status for the same
  (`seatId`, `shiftId`) with overlapping date ranges. This is the
  double-booking guard from FR-4.3 and is enforced transactionally (see
  [`08_System_Architecture.md`](08_System_Architecture.md) §Concurrency).

### FeeCycle
- `id`, `enrollmentId`, `periodStart`, `periodEnd`, `amountDue`, `dueDate`,
  `status` (pending / paid / partially_paid / overdue), `amountPaid`
- One row per billing period of an Enrollment's life — this is what makes
  "days overdue," "next due date," and revenue-by-period reporting possible
  without recomputation from raw payments.

### Payment
- `id`, `feeCycleId`, `enrollmentId` (denormalized for query convenience),
  `amount`, `method` (cash / upi / card / other), `recordedBy` (User or
  "student_self_service"), `gatewayReference` (nullable), `status`
  (succeeded / refunded), `createdAt`
- **Append-only.** A refund is a new Payment-linked record referencing the
  original, never a mutation/deletion of the original (NFR-9, FR-11.3).

### Attendance
- `id`, `enrollmentId`, `studentId` (denormalized), `branchId`
  (denormalized), `checkInAt`, `checkOutAt` (nullable), `method` (qr_staff /
  qr_self / biometric / geofence), `recordedBy`

### StaffMembership (conceptual — two concrete forms, deliberately not one shared collection)
- **OrgOwnership**: `userId`, `organizationId`, `name`, `phoneNumber`,
  `addedAt`. Grants org-wide access to every Branch under that
  Organization — access follows from this record's existence, with no
  `branchId` to set or possibly leave stale.
- **BranchReceptionist**: `userId`, `organizationId`, `branchId`, `name`,
  `phoneNumber`, `status` (active / revoked), `invitedAt`, `acceptedAt`.
  Grants access to exactly the one `branchId` on the record. A person
  reassigned to a different Branch gets a new record, not an edited
  `branchId` field on the old one (see BR-23) — this keeps a full history
  of which Branch a Receptionist was assigned to at any point in time,
  which a single mutable `branchId` field would destroy.
- These are modeled as two distinct forms, not one `StaffMembership` with a
  nullable `branchId`, because "org-wide access" and "single-Branch access"
  are different *kinds* of grants with different holders (Owners vs.
  Receptionists) and different write-permission rules (BR-24) — collapsing
  them into one shape with an optional field is exactly the kind of
  implicit-exception modeling that let the earlier draft of this document
  treat Student's tenancy exception as reasonable (§6.4/§6.6). A person can
  hold an OrgOwnership and separately be a Receptionist elsewhere (uncommon
  but not forbidden) — the two forms don't interact.

### Role
- `id`, `organizationId` (nullable for platform-default roles), `name`,
  `permissions[]`
- The two default roles — Owner, Receptionist — are platform-defined and
  available to every Organization; custom roles (P1), still Branch-scoped,
  are Organization-owned.

### Expense
- `id`, `branchId`, `category`, `amount`, `note`, `incurredAt`, `recordedBy`

### Announcement
- `id`, `branchId`, `title`, `body`, `audienceFilter` (all / overdue_only /
  custom segment), `sentAt`, `channel[]` (push / sms / whatsapp)

### Coupon *(P1)*
- `id`, `branchId` (or `organizationId` for org-wide), `code`,
  `discountType` (flat / percent), `value`, `validFrom/To`, `usageLimit`,
  `timesUsed`

### WaitlistEntry *(P1)*
- `id`, `branchId`, `shiftId`, `seatType`, `studentId`, `requestedAt`,
  `status` (waiting / offered / expired / converted)

### AuditLogEntry
- `id`, `organizationId`, `actorId`, `actorType` (user / platform_admin /
  system_job), `action`, `entityType`, `entityId`, `beforeSnapshot`,
  `afterSnapshot`, `at`
- Append-only, never edited. Every FeeCycle/Payment/Enrollment/Subscription
  mutation writes one of these (NFR-9).

### Lead / Review *(P2 — discovery)*
- `Lead`: `id`, `branchId`, `studentId` (nullable if anonymous browse),
  `source`, `status` (new / contacted / converted)
- `Review`: `id`, `branchId`, `studentId`, `rating`, `body`, `createdAt`,
  `moderationStatus`

## 6.4 Key design decisions

**No stored "current occupancy" field.** Seat occupancy, Branch occupancy %,
and dashboard tiles are all *derived* from querying active Enrollments (and,
for "right now," Attendance) — never a counter field that could drift from
reality. This trades a small amount of read-time computation (mitigated by
denormalized read models, see §07) for the elimination of an entire class of
"the dashboard says something different from the seat map" bugs, which would
directly destroy Owner trust (see [`01_Product_Vision.md`](01_Product_Vision.md) §1.7).

**FeeCycle as its own entity, not just fields on Enrollment.** An Enrollment
spans many billing periods over its life (e.g. a 12-month Enrollment billed
monthly has 12 FeeCycles). Modeling each cycle explicitly is what makes
"overdue since," partial payments, and period-accurate revenue reporting
correct without inferring history from a single mutable balance field.

**Payment is append-only; FeeCycle is the mutable rollup.** This is a
standard ledger pattern: the FeeCycle's `status`/`amountPaid` is a
maintained projection over its Payments, recomputed transactionally on each
new Payment — never trust a single field as the sole source of truth for
money without an underlying immutable trail (NFR-9).

**Student is Branch-owned; only the sign-in identity is shared.** A Student
record — dues, attendance, history — lives entirely within its Branch and
is never visible to, or merged with, that same person's Student record at
a different Branch. The one thing that *is* shared is the underlying
Firebase Auth account (keyed by phone number, `authUid`): a person signs in
once, and the Student app resolves that sign-in to whichever Branch-owned
Student record(s) reference it. This keeps the isolation guarantee absolute
(no entity in the system crosses the Branch boundary — see §6.6) while
still giving the person a single login rather than a new account per
Branch. The trade-off, made consciously: a Student relocating to a new
Branch does not carry their attendance streak or history with them — they
start a fresh record. That trade is worth it here because unbroken
isolation is the explicit requirement this model serves; a future
Phase 2 discovery layer (P2, ratings/reviews) can still surface a
*person's* aggregate reputation without requiring their operational
Branch data to be merged — that's a separate, deliberately scoped concern
for whenever P2 is actually designed, not something to solve by weakening
isolation now.

**No cascading deletes.** Deactivating a Seat, ending an Enrollment, or
suspending an Organization never deletes historical data (Payments,
Attendance, AuditLog). Status fields represent lifecycle state; hard deletes
are reserved for explicit privacy-compliance requests (P1, GDPR/DPDP-style
data deletion), and even then the audit trail's immutable snapshots are
handled per a documented retention policy, not ad hoc.

## 6.5 Relationship diagram (logical)

```
Organization ──1:N── Branch ──1:N── Shift
     │                  ├──1:N── Seat ──1:1?── Locker
     │                  ├──1:N── MembershipPlan (refs Shift)
     │                  ├──1:N── Expense
     │                  ├──1:N── Announcement
     │                  ├──1:N── StaffMembership ──N:1── Role   (Receptionist: scoped to this Branch)
     │                  └──1:N── Student                          (Branch-owned roster)
     │                                │
     │                                └──1:N── Enrollment ──N:1── Seat
     │                                              │        ──N:1── Shift
     │                                              │        ──N:1── MembershipPlan (price snapshot)
     │                                              ├──1:N── FeeCycle ──1:N── Payment
     │                                              └──1:N── Attendance
     │
     ├──1:1(current)── PlatformSubscription
     └──1:N── StaffMembership (Owner: org-wide, branchId = null)

AuditLogEntry ──N:1── Organization (references any entity by type+id)
```
Every relationship inside a Branch's box is Branch-owned; nothing below
the Branch node in this diagram is reachable except through that specific
Branch — there is no arrow from Student or Enrollment back up to
Organization directly, only through their owning Branch.

## 6.6 Multi-tenancy strategy: two isolation boundaries, no exceptions

Multi-branch is a **core domain concept**, not a later-stage enterprise
feature bolted onto a single-tenant model — every Branch-scoped entity is
architected with Branch isolation from its first field, whether the owning
Organization has one Branch or fifty. There are exactly two nested
isolation boundaries in this system, and every entity sits inside both,
with **zero exceptions**:

1. **Organization boundary** (cross-tenant): one Organization's data is
   never visible to another Organization, under any role. This is the
   boundary NFR-1 refers to.
2. **Branch boundary** (within-tenant): within a single Organization, a
   Branch's operational data — Seats, Students, Memberships (Membership
   Plans + Enrollments), Payments, Attendance, Receptionists, Reports — is
   never visible to a Receptionist assigned to a different Branch in the
   *same* Organization. Only the Owner role crosses this boundary, and it
   does so for every Branch in their Organization uniformly, by virtue of
   being the Owner — never as a per-Branch grant that could be
   inconsistently applied.

Every Branch-scoped entity carries both `organizationId` and `branchId`
(directly, or structurally via its position in the document hierarchy —
see [`07_Firestore_Schema.md`](07_Firestore_Schema.md) §7.1, where the
physical schema makes the Branch boundary literally part of every
document's path, not just a field to remember to filter on). This is what
it means for isolation to be "enforced by design": a query, a security
rule, or a repository method cannot address Branch-scoped data *without*
supplying a `branchId`, because the address itself requires one.

There is no entity in this model — including Student, after the revision
in §6.3 — that crosses the Branch boundary. Role rows that are genuinely
platform-default (not Organization-specific) and the append-only
`AuditLogEntry` collection are the only two things that are not
Branch-scoped, and neither represents Organization operational data: Role
defaults are static platform configuration, and AuditLogEntry is a
server-side-only, Admin-SDK-written record used for compliance/support,
never exposed through client-facing Firestore access at all (see
[`07_Firestore_Schema.md`](07_Firestore_Schema.md) §7.4).

**Why this reads as simpler than a typical multi-tenant model, not more
complex**: most SaaS products bolt a second isolation tier onto an
already-shipped single-tenant model, which is where inconsistency bugs
come from (some tables get the new tenant column, some don't; some queries
get updated, some are missed). Because Branch isolation is designed in at
the same time as Organization isolation — before any entity is
implemented — every entity gets exactly one consistent treatment. Nothing
in this system was "single-tenant, then upgraded."

## 6.7 Identifiers

All entity IDs are opaque, globally unique strings (not sequential
integers) — this is both a Firestore-native fit (document IDs) and a
security property (IDs are not guessable/enumerable, which matters given
FeeCycle/Payment/Student data sensitivity).

## 6.8 Why Firestore (and what that trades away)

Chosen for: native real-time listeners (seat map, dashboard live-updating
without polling — directly serves NFR-5 and the offline resilience need in
NFR-3), generous free tier and pay-per-use pricing that fits a
thousands-of-small-tenants cost curve, mature Flutter SDK with built-in
offline persistence (directly serves NFR-3), and no infrastructure to
operate at our team size.

Traded away: no multi-document ACID transactions across collections beyond
Firestore's transaction API limits (bounded, but real — informs the
Enrollment double-booking guard design in §07), no server-side joins
(informs deliberate denormalization choices in §07), and eventual-consistency
characteristics on some read paths that must be designed around explicitly,
not discovered in production.

This trade-off is revisited explicitly, not assumed permanent — see
[`08_System_Architecture.md`](08_System_Architecture.md) for how Clean
Architecture's dependency boundary keeps this a swappable infrastructure
decision, and the roadmap's note on a future analytics-oriented data
warehouse export (P2/P3) for reporting workloads Firestore is not suited to.
