# 14. Domain Model

This is the **Domain layer** of the system, per Clean Architecture
([`08_System_Architecture.md`](08_System_Architecture.md) §8.4): pure
business logic and rules, with zero knowledge of Firestore, Flutter, HTTP,
or any other delivery/persistence mechanism. Nothing in this document should
ever need to change because we swapped a database or a mobile framework —
if it would, that content doesn't belong here.

This document is the bridge between the *product* decisions already made
(docs 01–13) and the *code* not yet written. It is deliberately not code —
no Dart, no TypeScript, no Firestore documents — but it is precise enough
that implementing it should be a mostly mechanical translation.

## 14.1 Method

We use standard Domain-Driven Design (DDD) tactical patterns:

- **Entity**: has identity and a lifecycle; two entities with identical
  fields are still different if their identity differs; mutable over time.
- **Value Object (VO)**: has no identity; defined entirely by its
  attributes; immutable — a change produces a new VO, never a mutation.
- **Aggregate**: a cluster of one or more Entities/VOs with a single
  **Aggregate Root** — the only member addressable from outside the
  cluster. Everything inside an aggregate is loaded, validated, and saved
  together, which is what makes the aggregate the true **transactional
  consistency boundary**. Aggregates reference other aggregates **by ID
  only**, never by holding a direct object reference — this is what keeps
  aggregates small and the system able to scale to thousands of
  Organizations without every write contending on a shared object graph.
- **Domain Service**: business logic that doesn't naturally belong to any
  single aggregate, typically because it coordinates *across* aggregates.
- **Domain Event**: a fact that something happened, raised by an aggregate,
  consumed by domain services or read-model projections.

**A note on what is deliberately excluded from this document.** Fields you
will see in [`07_Firestore_Schema.md`](07_Firestore_Schema.md) that exist
purely to make a query fast — e.g. `studentName`/`seatLabel` cached onto an
Enrollment document for list rendering — are **not** part of this Domain
Model. They are an Infrastructure-layer read optimization *over* this
model, owned by the repository implementation that maps domain Entities to
Firestore documents. If a field here doesn't earn its place in the
business rules, it isn't listed. The one exception, explained in §14.2, is
`organizationId`/`branchId` on every Branch-scoped aggregate — that is a
genuine domain invariant (FR-1.4), not a query optimization, so it belongs
here.

## 14.2 Branch-scoping is a domain invariant, stated once

Per [`02_Product_Requirements_Document.md`](02_Product_Requirements_Document.md)
FR-1.4 and [`06_Database_Design.md`](06_Database_Design.md) §6.6, every
Branch-scoped aggregate carries `organizationId` and `branchId` as core
identity-adjacent fields, not as an afterthought. This is stated once here
rather than re-justified in every entity section below: **an aggregate that
represents Branch-owned data cannot exist without knowing which Branch owns
it**, full stop. This is what makes Branch isolation enforceable at every
layer above this one (repositories, security rules) — the domain model
itself makes an "unscoped" Seat, Student, Enrollment, FeeCycle, Payment,
Attendance, Expense, Announcement, or Locker inexpressible.

## 14.3 Bounded contexts

Two bounded contexts exist in this system today, deliberately kept
linguistically and structurally separate:

1. **Branch Operations** — the core context. Everything about running a
   Study Hall day to day: Organizations, Branches, Owners, Receptionists,
   Seats, Shifts, Membership Plans, Students, Enrollments, Fee Cycles,
   Payments, Attendance, Expenses, Announcements, and the Dashboard read
   model.
2. **Platform Billing** — our relationship with the Organization as our
   paying customer: Subscription only, at this stage.

They share the `OrganizationId` identity as a reference point, but nothing
else crosses the boundary directly. This split already exists implicitly
in [`02_Product_Requirements_Document.md`](02_Product_Requirements_Document.md)
§2.2's insistence on keeping "Membership Plan" (a Branch's pricing catalog
for Students) and "Platform Subscription" (our pricing tier for the
Organization) as unrelated concepts, even though a careless model could
have called both "Plan" and merged them. That naming discipline **is**
bounded-context thinking, applied before we had the vocabulary for it — see
§14.11 for what a third bounded context (Discovery, P2) will look like when
it's built.

## 14.4 Value Objects

VOs have no identity and no independent lifecycle — they are created fresh
and replaced, never mutated in place. Listed once here; referenced by name
in the entity sections that follow.

| Value Object | Shape | Validation |
|---|---|---|
| **Money** | integer amount in paise + fixed currency (INR) | Never negative unless explicitly representing a refund/credit; never a float, anywhere, at any layer (BR-29) |
| **PhoneNumber** | E.164 string | Must match E.164; this is the identity anchor for every human-associated entity (Owner, Receptionist, Student) |
| **TimeWindow** | `{start: TimeOfDay, end: TimeOfDay}` | `start != end`; overnight windows (e.g. a "Night" shift 22:00–06:00) are valid and must be interpreted as spanning midnight, not rejected as "end before start" |
| **WeekdaySet** | set of 1–7 (ISO weekday) | Non-empty |
| **DateRange** | `{start: Date, end: Date}` | `end >= start`; used for both Enrollment periods and FeeCycle billing periods |
| **Address** | free-text line + `GeoCoordinates` | Address text non-empty |
| **GeoCoordinates** | `{lat, lng}` | `lat ∈ [-90,90]`, `lng ∈ [-180,180]` |
| **OperatingHours** | map of weekday → `TimeWindow` | At most one window per weekday |
| **SeatLabel** | short string (e.g. `"A-12"`) | Non-empty, ≤ 20 chars; **uniqueness within a Branch** is enforced by a Domain Service (§14.10), not by the VO itself — a VO cannot know about its siblings |
| **PlanSnapshot** | `{durationMonths, price: Money, seatType: SeatType}` | Frozen copy taken from a MembershipPlan at Enrollment creation time (BR-5) — this is the concrete DDD technique of embedding a VO snapshot to intentionally decouple an aggregate from another aggregate's future changes |
| **CheckInPolicy** | enum: `hard_block \| soft_warn \| allow` | Branch-configurable (BR-16) |
| **GracePeriod** | integer days | `>= 0` |

**Enumerated Value Objects** (closed sets, no independent validation beyond
membership): `OrganizationStatus`, `BranchStatus`, `GrantStatus`,
`SeatType`, `SeatLayout`, `SeatStatus`, `LockerStatus`, `StudentStatus`,
`EnrollmentStatus`, `FeeCycleStatus`, `PaymentMethod`, `PaymentStatus`,
`AttendanceMethod`, `AnnouncementAudience`, `AnnouncementChannel`,
`SubscriptionTier`, `SubscriptionStatus`, `BillingCycle`.

**Identity Value Objects**: every `{X}Id` (e.g. `OrganizationId`,
`BranchId`, `EnrollmentId`) is an opaque, globally unique, non-guessable
string wrapper (per [`06_Database_Design.md`](06_Database_Design.md) §6.7)
— technically a Value Object itself (immutable, defined by its value), but
its purpose is to *carry* an Entity's identity rather than describe an
attribute, so it's called out separately from the VOs above. `UserId`
refers to the Firebase Auth identity and is external to this domain — the
domain treats it as an opaque reference, never modeling authentication
itself.

## 14.5 Aggregate map

| # | Aggregate Root | Context | Child entities (inside the boundary) | References (by ID, cross-aggregate) |
|---|---|---|---|---|
| 1 | Organization | Branch Operations | — | — |
| 2 | Owner | Branch Operations | — | `organizationId` |
| 3 | Branch | Branch Operations | — | `organizationId` |
| 4 | Receptionist | Branch Operations | — | `organizationId`, `branchId` |
| 5 | Shift | Branch Operations | — | `branchId` |
| 6 | Seat | Branch Operations | — | `branchId` |
| 7 | Locker | Branch Operations | — | `branchId`, `linkedSeatId`, `assignedEnrollmentId` |
| 8 | MembershipPlan | Branch Operations | — | `branchId`, `shiftId` |
| 9 | Student | Branch Operations | — | `branchId`, `organizationId` |
| 10 | Enrollment | Branch Operations | — | `studentId`, `seatId`, `shiftId`, `planId` |
| 11 | FeeCycle | Branch Operations | **Payment** | `enrollmentId` |
| 12 | Attendance | Branch Operations | — | `enrollmentId`, `studentId` |
| 13 | Expense | Branch Operations | — | `branchId` |
| 14 | Announcement | Branch Operations | — | `branchId` |
| — | **Dashboard** — read model, *not* an aggregate | Branch Operations (query side) | — | derived from Enrollment/FeeCycle/Attendance/Seat events |
| 15 | Subscription | Platform Billing | **SubscriptionEvent** | `organizationId` |

Fifteen true Aggregate Roots, two child Entities that only exist inside a
parent aggregate (Payment inside FeeCycle, SubscriptionEvent inside
Subscription), and one read model (Dashboard) — seventeen concepts total,
matching the full list this document was asked to cover. Identifying which
of the seventeen are *not* independent aggregate roots is as important a
design decision as identifying which are — see each entity's own section
for the reasoning.

**Why no `Person`/`User` aggregate.** There is no shared `Person` entity
that `Owner`, `Receptionist`, and `Student` all point to. Each is an
independent Entity in its own right, scoped to its own consistency
boundary, even though the same real human might be linked — via `UserId`
— across more than one of them (e.g. someone who is a Receptionist at one
Branch and also, separately, a Student at another). This is the same
reasoning already applied to Student's Branch-ownership in
[`06_Database_Design.md`](06_Database_Design.md) §6.3/§6.6, generalized
consistently to every role, rather than making Student the one exception.

## 14.6 Domain Events (summary)

Raised by aggregates on meaningful state changes; consumed by the Domain
Services in §14.10 and by the Dashboard read model. Not an exhaustive
protocol specification — listed so relationships and lifecycles in the
sections below are traceable to something concrete.

`OrganizationCreated`, `OwnerAdded`, `OwnerRevoked`, `BranchCreated`,
`ReceptionistAssigned`, `ReceptionistRevoked`, `SeatCreated`,
`SeatDeactivated`, `EnrollmentCreated`, `EnrollmentEnded`,
`EnrollmentStatusChanged`, `FeeCycleGenerated`, `PaymentRecorded`,
`PaymentRefunded`, `FeeCycleBecameOverdue`, `AttendanceRecorded`,
`LockerAssigned`, `LockerReleased`, `SubscriptionSuspended`,
`SubscriptionReactivated`.

---

# Entities

Grouped by bounded context, in dependency order. Every entity follows the
same template: Purpose, Fields, Relationships, Lifecycle, Business Rules,
Creation Rules, Update Rules, Delete Rules, Validation Rules, Future
Extensions.

## Branch Operations context

### 1. Organization

**Aggregate Root.**

**Purpose**: The tenancy root. Represents one Study Hall business — the
paying SaaS customer. Every Branch-scoped aggregate ultimately traces back
to exactly one Organization; this is the outermost isolation boundary in
the whole system (NFR-1).

**Fields**
| Field | Type |
|---|---|
| `id` | `OrganizationId` |
| `name` | string |
| `status` | `OrganizationStatus` (`setup_incomplete \| active \| suspended`) |
| `createdAt` | DateTime |

**Relationships**: Referenced by every Branch (via `organizationId`), by
every Owner grant, and by its Subscription (Platform Billing context, 1:1
by shared ID). Holds no direct references to its Branches or Owners —
those aggregates point back to it, not the reverse, keeping Organization
itself tiny and cheap to load.

**Lifecycle**: `setup_incomplete → active` (once the first Branch and
first Owner both exist — see the Domain Service in §14.10) `→ suspended`
(driven by a `SubscriptionSuspended` event from the Platform Billing
context, never self-initiated) `→ active` (on `SubscriptionReactivated`).
There is no terminal "deleted" state modeled — see Delete Rules.

**Business Rules**
- An Organization must have at least one active Owner at all times
  (enforced by the Ownership Guard domain service, §14.10, not by this
  aggregate alone — see §14.9 for why this is a cross-aggregate rule, not
  a hard aggregate invariant).
- `status == suspended` puts every Branch under this Organization into the
  read-only mode described in BR-27 — Organization is the single source of
  truth for that flag; Branches don't carry their own suspended state.

**Creation Rules**: Created via self-serve signup
([`04_User_Flows.md`](04_User_Flows.md) §4.1), which atomically also
creates the founding Owner — an Organization is never created without at
least one Owner, so "zero-owner Organization" is not a state that ever
exists, even transiently. Starts `setup_incomplete`.

**Update Rules**: `name` is editable by any Owner. `status` transitions
only through the paths in Lifecycle above — never set directly by
arbitrary application code.

**Delete Rules**: **Never hard-deleted.** An Organization that stops
paying is `suspended`, not removed — consistent with the business-continuity
guarantee in BR-27. A genuine account-closure/data-deletion request is a
distinct, explicit compliance operation (P1, see
[`05_Feature_List.md`](05_Feature_List.md) §5.14), not a consequence of
ordinary Subscription lapse.

**Validation Rules**: `name` non-empty, ≤ 200 chars.

**Future Extensions**: Multi-currency support (P3, if we ever expand
beyond India) would add a `currency` field here, propagating into every
`Money` VO used by that Organization's Branches — flagged now precisely
because `Money`'s VO shape (§14.4) fixes INR today and this is the field
that would need to widen.

---

### 2. Owner

**Aggregate Root.**

**Purpose**: Represents one person's org-wide authority over an
Organization — implicit access to every Branch under it (FR-7.4). Kept as
its own small aggregate, not embedded in Organization, specifically so
adding/removing an Owner never requires locking the Organization aggregate
itself, and so a full history of who has held ownership is preserved.

**Fields**
| Field | Type |
|---|---|
| `id` | `OwnerId` |
| `organizationId` | `OrganizationId` |
| `userId` | `UserId` |
| `name` | string |
| `phoneNumber` | `PhoneNumber` |
| `status` | `GrantStatus` (`active \| revoked`) |
| `addedAt` | DateTime |
| `addedBy` | `OwnerId \| null` (null only for the founding Owner) |

**Relationships**: References `Organization` by `organizationId`. Not
referenced by any other aggregate — Branches, Seats, etc. don't point to
an Owner; Owner access is resolved by *querying* active Owner grants for
an Organization, not by a forward reference anywhere.

**Lifecycle**: `active → revoked` (one-way; a person re-invited as Owner
later gets a **new** grant record, preserving the fact that the earlier
grant was genuinely revoked at a point in time, per BR-23's reasoning
applied to Owner as well as Receptionist).

**Business Rules**
- FR-7.4 / BR-24: an active Owner grant is what makes org-wide Branch
  access implicit and uniform.
- The "at least one active Owner" invariant (§14.10) is checked on every
  attempted revoke, not just at Organization creation.

**Creation Rules**: The founding Owner is created atomically with the
Organization (§Organization Creation Rules). Subsequent Owners are added
only by an existing active Owner.

**Update Rules**: `name`/`phoneNumber` editable by the Owner themself only
(no one else edits another Owner's identity fields). `status` only
transitions `active → revoked`, and only by another active Owner of the
same Organization — an Owner cannot revoke their own last-remaining grant
(see Business Rules).

**Delete Rules**: Never hard-deleted — revoked instead, preserving audit
history (BR-28).

**Validation Rules**: `phoneNumber` valid E.164; `name` non-empty.

**Future Extensions**: Differentiated Owner permission tiers (e.g. a
"co-owner with financial visibility only") are a plausible P2/P3 evolution
once the Role entity (§14.12) gains real configurability — today, every
active Owner grant is equally powerful by design, matching the MVP's
two-role simplicity (FR-7.3).

---

### 3. Branch

**Aggregate Root.**

**Purpose**: A physical Study Hall location. The primary operational unit
of the whole system — nearly every other aggregate in this context exists
*because* a Branch exists. Kept deliberately small (no embedded Seats,
Students, etc.) so that editing a Branch's operating hours never contends
with the high write-volume happening inside it (check-ins, payments).

**Fields**
| Field | Type |
|---|---|
| `id` | `BranchId` |
| `organizationId` | `OrganizationId` |
| `name` | string |
| `address` | `Address` |
| `operatingHours` | `OperatingHours` |
| `timezone` | string (IANA tz, e.g. `Asia/Kolkata`) |
| `status` | `BranchStatus` (`active \| inactive`) |
| `createdAt` | DateTime |

**Relationships**: Referenced by every Branch-scoped aggregate
(`branchId`). References `Organization` by `organizationId`.

**Lifecycle**: `active ⇄ inactive` (an Owner can temporarily deactivate a
Branch, e.g. seasonal closure — this does not cancel in-progress
Enrollments, mirroring BR-3's Seat-deactivation reasoning at the Branch
level).

**Business Rules**
- FR-1.4: everything this Branch owns (Seats, Students, Memberships,
  Payments, Receptionists, Reports) is exclusively its own — no other
  Branch, even in the same Organization, can read or reference it.
- A Branch's `operatingHours`/`timezone` are advisory context for the UI
  and for Shift scheduling; they do not themselves restrict when
  check-ins or payments can be recorded (that's governed by Shift windows
  and the Branch's `CheckInPolicy`, not by opening hours).

**Creation Rules**: Created only by an active Owner of the parent
Organization (BR-24), subject to the Organization's Subscription
`branchLimit` (BR-26) — creation is rejected outright if the limit is
already met, never allowed and cleaned up later.

**Update Rules**: `name`, `address`, `operatingHours`, `timezone` editable
by any active Owner of the parent Organization. `status` toggled by an
Owner only.

**Delete Rules**: Never hard-deleted (would orphan or force-cascade-delete
every Branch-scoped aggregate it owns, violating the no-cascading-deletes
principle in [`06_Database_Design.md`](06_Database_Design.md) §6.4).
Deactivation (`status = inactive`) is the only supported "removal."

**Validation Rules**: `name` non-empty, ≤ 200 chars; `address.text`
non-empty; `timezone` must be a valid IANA identifier.

**Future Extensions**: Branch cloning (P1, copy Shifts/Seats/Plans from an
existing Branch to a new one) is a Domain Service operating *across* two
Branch aggregates plus their Shift/Seat/MembershipPlan aggregates — it
does not change Branch's own shape, only adds an orchestration service on
top of creation.

---

### 4. Receptionist

**Aggregate Root.**

**Purpose**: Represents one person's authority over exactly one Branch —
the operational counterpart to Owner. Its existence is the entire
enforcement mechanism behind "Receptionists can only access their
assigned branch" (FR-7.4).

**Fields**
| Field | Type |
|---|---|
| `id` | `ReceptionistId` |
| `organizationId` | `OrganizationId` |
| `branchId` | `BranchId` |
| `userId` | `UserId` |
| `name` | string |
| `phoneNumber` | `PhoneNumber` |
| `status` | `GrantStatus` (`invited \| active \| revoked`) |
| `invitedAt` | DateTime |
| `acceptedAt` | DateTime `\| null` |
| `invitedBy` | `OwnerId` |

**Relationships**: References `Branch` (`branchId`) and `Organization`
(`organizationId`, denormalized for the FR-1.4 reasons in §14.2). Not
referenced by any other aggregate.

**Lifecycle**: `invited → active` (on the person's first successful
sign-in) `→ revoked` (one-way, by an Owner).

**Business Rules**
- BR-23: a single Receptionist grant names exactly one `branchId`; there
  is no multi-Branch Receptionist grant, and no permission escalation path
  that changes that.
- Reassigning a Receptionist to a different Branch is modeled as
  **revoke + create-new**, never as editing `branchId` in place — this
  preserves an accurate history of who was assigned where and when.

**Creation Rules**: Created only by an active Owner of the Branch's
Organization, subject to the Subscription's `staffLimit` (BR-26).

**Update Rules**: `name`/`phoneNumber` editable by the Receptionist
themself. `status` transitions only via the Lifecycle paths above, and
only an Owner can move it to `revoked`.

**Delete Rules**: Never hard-deleted — revoked instead (mirrors Owner).

**Validation Rules**: `phoneNumber` valid E.164; exactly one `branchId`
per record (structural, not a runtime check — the field is singular, not
an array, precisely so this can't be violated).

**Future Extensions**: Custom, finer-grained Branch-scoped roles (P1) —
e.g. a Receptionist who can record payments but not view financial
reports — extend this same aggregate's `roleId` reference to a
configurable `Role` (§14.12) without changing Receptionist's own shape or
its single-Branch scoping guarantee.

---

### 5. Shift

**Aggregate Root.**

**Purpose**: A Branch-defined, named recurring time window that seats are
sold against. Exists as its own aggregate (not a value inlined into Seat
or MembershipPlan) because multiple MembershipPlans and many Enrollments
reference the same Shift, and a Shift's own definition (name, hours,
active days) changes independently of any of them.

**Fields**
| Field | Type |
|---|---|
| `id` | `ShiftId` |
| `branchId` | `BranchId` |
| `name` | string |
| `window` | `TimeWindow` |
| `activeDays` | `WeekdaySet` |
| `isActive` | boolean |

**Relationships**: Referenced by `MembershipPlan.shiftId` and
`Enrollment.shiftId`. References `Branch` by `branchId`.

**Lifecycle**: `isActive: true → false` (an Owner retires a Shift it no
longer sells). Deactivation never affects existing Enrollments already
tied to it (same "don't retroactively break the past" principle as BR-5).

**Business Rules**
- Shifts are Branch-defined, not a global enum (§6.3 of
  [`06_Database_Design.md`](06_Database_Design.md)) — different Branches
  run entirely different shift structures.
- A Seat's occupancy is always Shift-relative (BR-2) — this is the
  Shift entity's core reason for existing as a first-class concept rather
  than a simple field on Seat.

**Creation Rules**: Created by an active Owner (or, per BR-23's write
rules, possibly delegated — but MVP restricts Shift configuration to
Owners, per BR-24).

**Update Rules**: `name`/`window`/`activeDays` editable by an Owner.
Changing `window` does not retroactively move already-scheduled
Attendance or FeeCycle records tied to Enrollments created under the old
window.

**Delete Rules**: Never hard-deleted; `isActive = false` is the only
retirement path, for the same historical-integrity reason as Branch and
Seat deactivation.

**Validation Rules**: `window.start != window.end`; `activeDays`
non-empty; `name` non-empty, unique within the Branch (enforced by the
Shift Uniqueness domain service, §14.10).

**Future Extensions**: Shift templates shareable across Branches within
an Organization (P1, part of Branch cloning) build on top of this
aggregate without changing it.

---

### 6. Seat

**Aggregate Root.**

**Purpose**: An individually bookable unit of physical space. The core
inventory unit of the entire product — see
[`01_Product_Vision.md`](01_Product_Vision.md) §1.1 for why seat-level
modeling (not a generic "resource") is the whole point of this being a
Study Hall product and not a repurposed coworking tool.

**Fields**
| Field | Type |
|---|---|
| `id` | `SeatId` |
| `branchId` | `BranchId` |
| `label` | `SeatLabel` |
| `zone` | string |
| `seatType` | `SeatType` (`ac \| non_ac`) |
| `layout` | `SeatLayout` (`cabin \| open`) |
| `hasLocker` | boolean |
| `status` | `SeatStatus` (`active \| maintenance \| inactive`) |

**Relationships**: Referenced by `Enrollment.seatId` and, optionally, by
`Locker.linkedSeatId`. References `Branch` by `branchId`. **Deliberately
holds no reference to its current occupant(s)** — per
[`06_Database_Design.md`](06_Database_Design.md) §6.4, occupancy is always
derived from active Enrollments, never stored on Seat, eliminating an
entire class of "two sources of truth disagree" bugs.

**Lifecycle**: `active → maintenance → active` (temporary) or `active →
inactive` (retirement). None of these transitions touch existing
Enrollments (BR-3) — they only gate *new* Enrollments.

**Business Rules**
- BR-1: at most one `active` Enrollment per (Seat, Shift) at a time —
  enforced by the Seat Availability domain service (§14.10), since this
  invariant spans the Seat and Enrollment aggregates.
- BR-2: a Seat may be sold across multiple different Shifts
  simultaneously to different Students.
- BR-3: deactivating a Seat blocks new Enrollments only; it never evicts
  an existing occupant.
- BR-4: "auto-assign nearest available" only considers `active` Seats
  matching the requested `seatType` with no conflicting Enrollment for the
  target Shift/date range.

**Creation Rules**: Created (individually or in bulk) by an active Owner.
Subject to the Subscription's `seatLimit` (BR-26) — rejected outright past
the limit.

**Update Rules**: `zone`/`seatType`/`layout`/`hasLocker` editable by an
Owner; changing `seatType` does not retroactively alter any
`PlanSnapshot` already frozen into an existing Enrollment (BR-5). `status`
toggled by Owner or, for `maintenance`, potentially a Receptionist
(day-to-day operational concern) — write-permission specifics live in
[`07_Firestore_Schema.md`](07_Firestore_Schema.md) §7.4's rule table.

**Delete Rules**: Never hard-deleted — `status = inactive` only, to
preserve every historical Enrollment/Attendance/Payment record that
references it.

**Validation Rules**: `label` non-empty, ≤ 20 chars, unique within the
Branch (Domain Service, §14.10).

**Future Extensions**: A visual floor-plan `position: {x, y}` field (P1)
is an additive, backward-compatible extension — every rule above is
unaffected by adding spatial coordinates.

---

### 7. Locker

**Aggregate Root.** *(P1 feature; modeled now for schema stability, per
[`10_Business_Rules.md`](10_Business_Rules.md) BR-18/19.)*

**Purpose**: An individually assignable storage unit, optionally linked to
a Seat. Kept as its own aggregate rather than a field on Seat because its
lifecycle (assign/release, tied to Enrollment) is independent of a Seat's
own configuration lifecycle — a Seat's zone or type can change without
ever touching its Locker's assignment state, and vice versa.

**Fields**
| Field | Type |
|---|---|
| `id` | `LockerId` |
| `branchId` | `BranchId` |
| `label` | string |
| `linkedSeatId` | `SeatId \| null` |
| `status` | `LockerStatus` (`available \| assigned \| maintenance`) |
| `assignedEnrollmentId` | `EnrollmentId \| null` |

**Relationships**: References `Branch`, optionally `Seat`, and
(while assigned) `Enrollment`.

**Lifecycle**: `available → assigned → available` (on Enrollment end,
automatically — BR-19) or `available ⇄ maintenance`.

**Business Rules**
- BR-18: a Locker is assigned only as part of an active Enrollment whose
  Plan/Seat includes `hasLocker` — it is never independently rentable.
- BR-19: ending an Enrollment automatically releases its Locker (`assign
  → available`), unlike Seats, because Locker release carries no
  reassignment ambiguity — only a physical-cleanout step for staff.

**Creation Rules**: Created by an active Owner, optionally linked to a
Seat at creation time.

**Update Rules**: `assignedEnrollmentId`/`status` are set by the
`Enrollment.end()` / Enrollment-creation domain behavior (§14.10's
Locker Assignment service), not edited directly by a UI form.

**Delete Rules**: Never hard-deleted; `status = maintenance` is the
closest "removal" state (a genuinely destroyed locker is simply left
`maintenance` indefinitely, which is an acceptable real-world outcome —
no special "decommissioned" state is needed for MVP+P1 scope).

**Validation Rules**: `label` non-empty; `assignedEnrollmentId` set
if and only if `status == assigned`.

**Future Extensions**: A distinct Locker-only fee line item (P1, already
flagged in [`05_Feature_List.md`](05_Feature_List.md) §5.5) would add a
`feeCycleContribution: Money` concept — most naturally modeled as an
additional line on `FeeCycle` (§14.6 of that entity) rather than a change
to Locker itself.

---

### 8. MembershipPlan

**Aggregate Root.**

**Purpose**: A Branch's priced catalog entry — the (Shift × Seat Type ×
Duration × Price) combination Students choose from. Distinct, by
deliberate naming, from `Subscription.planTier` (Platform Billing context)
— see §14.3.

**Fields**
| Field | Type |
|---|---|
| `id` | `MembershipPlanId` |
| `branchId` | `BranchId` |
| `shiftId` | `ShiftId` |
| `seatType` | `SeatType` |
| `durationMonths` | integer |
| `price` | `Money` |
| `isActive` | boolean |
| `createdAt` | DateTime |

**Relationships**: References `Branch` and `Shift`. Referenced by
`Enrollment.planId` — but only at creation time; after that, Enrollment
carries its own frozen `PlanSnapshot` VO and no longer depends on this
aggregate's current state (BR-5).

**Lifecycle**: `isActive: true → false` (retired from sale; existing
Enrollments unaffected, per BR-5).

**Business Rules**
- BR-5: an Enrollment's `PlanSnapshot` is frozen at creation; later price
  changes here never retroactively alter it.
- FR-3.3: this is the concrete mechanism that makes FR-3.3 true.

**Creation Rules**: Created by an active Owner; must reference an existing
`Shift` on the same Branch.

**Update Rules**: `price`/`durationMonths`/`isActive` editable by an
Owner — every such edit only affects *future* Enrollments.

**Delete Rules**: Never hard-deleted — `isActive = false` only, since
historical Enrollments' `PlanSnapshot` VOs must remain meaningful even
after the originating Plan is retired (the snapshot doesn't need the Plan
to still exist, but retiring rather than deleting keeps reporting/audit
trails coherent — e.g. "show me the Plan an old Enrollment came from").

**Validation Rules**: `durationMonths > 0`; `price.amount > 0`; `shiftId`
must reference a Shift on the same `branchId`.

**Future Extensions**: Coupons (P1) apply a discount *at Enrollment
creation time*, producing a modified `PlanSnapshot.price` — Coupon itself
does not change MembershipPlan's shape, it's an input to the Enrollment
creation Domain Service (§14.10). Mid-cycle proration (BR-8, P1) similarly
extends Enrollment's behavior, not this entity's.

---

### 9. Student

**Aggregate Root.**

**Purpose**: A Branch's roster record for one person — dues, attendance,
and enrollment history, scoped entirely to this Branch. See
[`06_Database_Design.md`](06_Database_Design.md) §6.3/§6.4 for the full
reasoning behind Branch-ownership over a platform-level identity; this
section restates the resulting shape.

**Fields**
| Field | Type |
|---|---|
| `id` | `StudentId` |
| `branchId` | `BranchId` |
| `organizationId` | `OrganizationId` |
| `authUid` | `UserId \| null` |
| `phoneNumber` | `PhoneNumber` |
| `name` | string |
| `photoUrl` | string `\| null` |
| `idDocumentUrl` | string `\| null` (access-controlled) |
| `status` | `StudentStatus` (`active \| archived`) |
| `createdAt` | DateTime |

**Relationships**: References `Branch`/`Organization`. Referenced by
`Enrollment.studentId` and `Attendance.studentId`. **Not** referenced by,
or referencing, any Student record at a different Branch — by design,
there is no edge in this graph that crosses a Branch boundary for Student
data.

**Lifecycle**: `active → archived` (the Student is no longer a going
concern at this Branch — moved away, stopped attending — but their history
is retained, never deleted). `authUid` transitions `null → set` exactly
once, the first time this person signs into the Student app themself
(a Staff-entered walk-in Student may never make this transition at all,
and that's a fully valid permanent state, not an incomplete one).

**Business Rules**
- FR-4.4: a Student record belongs to exactly one Branch; the same person
  at a different Branch is a different Student record, linked only by a
  shared `authUid` if they've signed in.
- FR-9.3: the person's sign-in persists across Branches; their Student
  *record*, and everything in it, does not.

**Creation Rules**: Created by Staff during walk-in enrollment
([`04_User_Flows.md`](04_User_Flows.md) §4.2) or via Student
self-registration (P1) at this specific Branch. Phone-number matching an
*existing* Student record only reuses that record if it's at the **same**
Branch (§4.2's decision point) — never across Branches.

**Update Rules**: `name`/`photoUrl`/`idDocumentUrl` editable by Staff at
this Branch or by the Student themself (once `authUid` is set), scoped to
their own record only. `authUid` is set exactly once by the sign-in flow,
never reassigned.

**Delete Rules**: Never hard-deleted in the ordinary course of business —
`status = archived`. A genuine data-deletion request (privacy compliance,
P1) is a distinct, explicit, logged operation, not an ordinary lifecycle
transition.

**Validation Rules**: `phoneNumber` valid E.164; `name` non-empty.

**Future Extensions**: A portable, opt-in "Student reputation" concept for
the Phase 2 Discovery context (ratings a Student leaves, aggregated
per-person rather than per-Branch-record) is explicitly **not** solved by
loosening Student's Branch-ownership — see
[`06_Database_Design.md`](06_Database_Design.md) §6.4's note that this is
a separate, deliberately-deferred concern for whenever Discovery is
actually designed, kept out of this aggregate on purpose.

---

### 10. Enrollment

**Aggregate Root.**

**Purpose**: The central join — a Student holding a MembershipPlan on a
Seat for a Shift, over a concrete date range. This is the single most
important aggregate in the system: nearly every user-facing flow in
[`04_User_Flows.md`](04_User_Flows.md) either creates one, reads its
state, or reacts to a change in it.

**Fields**
| Field | Type |
|---|---|
| `id` | `EnrollmentId` |
| `branchId` | `BranchId` |
| `organizationId` | `OrganizationId` |
| `studentId` | `StudentId` |
| `seatId` | `SeatId` |
| `shiftId` | `ShiftId` |
| `planId` | `MembershipPlanId` |
| `planSnapshot` | `PlanSnapshot` |
| `period` | `DateRange` (`startDate`/`endDate`) |
| `status` | `EnrollmentStatus` (`active \| overdue \| at_risk \| ended \| cancelled`) |
| `createdAt` | DateTime |
| `updatedAt` | DateTime |

**Relationships**: References `Student`, `Seat`, `Shift`, `MembershipPlan`
by ID only — **never embeds or loads them as part of this aggregate**.
Owns no child entities (FeeCycle and Attendance are separate aggregate
roots that reference `enrollmentId` back, not the reverse) — this keeps
Enrollment small and fast to load/update even though a lot of activity
happens "around" it.

**Lifecycle**:
```
        ┌────────────────────────────────────────────┐
        │                                              │
 (create) → active → overdue → at_risk → ended         │
        │       ↑________________|          ↑          │
        │                                    |          │
        └──────────────────────────→ cancelled          │
```
`active → overdue`: automatic, when the current FeeCycle passes its due
date unpaid (BR-6). `overdue → at_risk`: automatic, after the Branch's
configured grace period (BR-6). `at_risk`/`overdue` → `active`: automatic,
on payment. `→ ended`: **always a manual Owner/Receptionist decision**
(BR-7) — never automatic, regardless of how overdue. `→ cancelled`: a
distinct terminal state for an Enrollment that never really started (e.g.
created in error, or cancelled before its start date) — kept separate from
`ended` so reporting can distinguish "ran its course or was ended for
non-payment" from "never actually happened."

**Business Rules**
- BR-1: no two `active` Enrollments may overlap on the same
  (`seatId`, `shiftId`) — enforced by the Seat Availability Domain Service
  (§14.10), a cross-aggregate concern.
- BR-5: `planSnapshot` is frozen at creation and never changes even if the
  source MembershipPlan does.
- BR-6/BR-7: status transitions as described in Lifecycle above.
- BR-8 *(P1)*: mid-cycle Plan/Seat/Shift changes reprice the *current*
  FeeCycle via proration — a behavior on this aggregate
  (`Enrollment.changePlan(...)`) that emits a recalculation request to the
  affected FeeCycle aggregate, not a direct field mutation on it (aggregates
  don't reach into each other).

**Creation Rules**: Created via the Seat Availability Domain Service
transaction (§14.10), which is what actually enforces BR-1 — Enrollment
creation and the availability check are not separable steps. Requires an
existing `active` Student, Seat, Shift, and MembershipPlan, all on the
same Branch (cross-Branch references are structurally impossible, not
just disallowed — see §14.2).

**Update Rules**: `status` transitions only via the paths in Lifecycle,
never set to an arbitrary value directly. `seatId`/`shiftId` change (P1,
seat/shift-change requests) goes through the same Seat Availability check
as creation — an Enrollment can't be "moved" into a seat conflict any more
than it could be created into one.

**Delete Rules**: Never hard-deleted — `ended`/`cancelled` are the
terminal states; the full history remains queryable indefinitely (subject
to future, explicit data-retention policy, not ordinary deletion).

**Validation Rules**: `period.end > period.start`; `seatId`/`shiftId`/
`planId`/`studentId` must all resolve to aggregates on the same
`branchId` as this Enrollment.

**Future Extensions**: Waitlist conversion (P1, BR-20/21) creates an
Enrollment from a `WaitlistEntry` rather than a direct Staff/Student
action — an alternate creation path into the same aggregate, not a change
to its shape.

---

### 11. FeeCycle (with child entity Payment)

**Aggregate Root** (owns **Payment** as a child Entity).

**Purpose**: One billing period's due amount within an Enrollment's life.
Split out from Enrollment specifically because an Enrollment accumulates
many FeeCycles over time (e.g. twelve for a 12-month Plan billed monthly),
and each one's payment activity should be independently loadable/writable
without contending on the parent Enrollment.

**Fields**
| Field | Type |
|---|---|
| `id` | `FeeCycleId` |
| `enrollmentId` | `EnrollmentId` |
| `branchId` | `BranchId` |
| `organizationId` | `OrganizationId` |
| `period` | `DateRange` (`periodStart`/`periodEnd`) |
| `dueDate` | Date |
| `amountDue` | `Money` |
| `amountPaid` | `Money` (maintained projection over `payments`, never set directly) |
| `status` | `FeeCycleStatus` (`pending \| partially_paid \| paid \| overdue`) |
| `payments` | `Payment[]` (child entities, inside this aggregate's boundary) |

**Payment** (child entity — no identity or meaning outside its parent
FeeCycle):
| Field | Type |
|---|---|
| `id` | `PaymentId` |
| `amount` | `Money` |
| `method` | `PaymentMethod` (`cash \| upi \| card \| other`) |
| `recordedBy` | `UserId` (or a sentinel for Student self-service) |
| `gatewayReference` | string `\| null` |
| `status` | `PaymentStatus` (`succeeded \| refunded`) |
| `refundOf` | `PaymentId \| null` |
| `createdAt` | DateTime |

**Relationships**: References `Enrollment` by `enrollmentId`. `Payment`
exists only as a member of a `FeeCycle`'s `payments` collection — it is
never independently addressed, created, or queried outside that context.

**Lifecycle (FeeCycle)**: `pending → partially_paid* → paid`, or
`pending → overdue → (partially_paid* →) paid`. *`partially_paid` is a
P1-scope status (BR-11); at MVP, FeeCycles are paid in full or remain
`pending`/`overdue` — the state is modeled now so P1 doesn't require a
schema change.

**Lifecycle (Payment)**: `succeeded` (terminal, immutable) or, via a
**new**, separate Payment record with `status = refunded`,
`refundOf = <original id>` — the original Payment is never edited
(§Business Rules).

**Business Rules**
- BR-9: FeeCycles are generated ahead of `periodStart` (default 7 days) by
  a scheduled process — never lazily on read.
- BR-10: a Payment can only be recorded against a FeeCycle with remaining
  balance (`amountDue - amountPaid > 0`); overpayment is rejected, not
  silently accepted.
- BR-11 *(P1)*: partial payments set `status = partially_paid`; this does
  not reset `dueDate`.
- BR-12: refunds are new, linked Payment records, never edits/deletions of
  the original — `amountPaid` is recomputed as the sum of non-refunded
  Payments.
- BR-13: cash Payments recorded by Staff take effect immediately, no
  approval step — `recordedBy` is the accountability mechanism, not a
  blocking gate.
- This is the aggregate where the **append-only Payment invariant** is
  enforced structurally: `Payment.update()`/`Payment.delete()` do not
  exist as operations at all, anywhere in this model — the only way to
  affect a Payment's economic effect is to add a new, linked refund
  Payment (BR-12/BR-29's "ledger, not a mutable field" pattern).

**Creation Rules (FeeCycle)**: Created by the scheduled FeeCycle
generation process (§14.10) from an active Enrollment's `planSnapshot`
billing cycle. **Creation Rules (Payment)**: added to a FeeCycle's
`payments` collection only via the `FeeCycle.recordPayment(...)` /
`FeeCycle.refund(...)` behaviors, which atomically recompute `amountPaid`
and `status` in the same operation — this is precisely the kind of
strong, same-transaction invariant that justifies Payment being a child
entity inside FeeCycle's boundary rather than its own aggregate root.

**Update Rules**: FeeCycle's `amountPaid`/`status` are never set directly
by any caller — they are always derived, inside the aggregate, from its
`payments`. `amountDue` can be adjusted (P1, proration, BR-8) by an
explicit `FeeCycle.reprice(...)` behavior, not a raw field write.

**Delete Rules**: Never hard-deleted, for either FeeCycle or Payment —
this is the system's financial ledger; deleting any part of it would
violate BR-27/BR-29's trust guarantees outright.

**Validation Rules**: `amountDue.amount > 0`; `amountPaid` is always the
sum of non-refunded child `Payment.amount`s (structural invariant of this
aggregate, not a rule that can be violated by construction); `period.end >
period.start`.

**Future Extensions**: Payment-gateway auto-reconciliation (P1) adds a
background process that cross-checks `gatewayReference` against the
gateway's settlement report — a new Domain Service consuming this
aggregate's data, not a change to its shape. Installment schedules beyond
simple partial payment (P2) would likely still fit within the existing
FeeCycle/Payment relationship rather than requiring a new entity.

---

### 12. Attendance

**Aggregate Root.**

**Purpose**: A single check-in (and optional check-out) event. Kept as its
own aggregate, not embedded in Enrollment, because attendance events are
high-frequency, independent, and never need to be updated together as a
group — each one is written once and essentially never touched again.

**Fields**
| Field | Type |
|---|---|
| `id` | `AttendanceId` |
| `enrollmentId` | `EnrollmentId` |
| `branchId` | `BranchId` |
| `organizationId` | `OrganizationId` |
| `studentId` | `StudentId` |
| `checkInAt` | DateTime |
| `checkOutAt` | DateTime `\| null` |
| `method` | `AttendanceMethod` (`qr_staff \| qr_self \| biometric \| geofence`) |
| `recordedBy` | `UserId` |

**Relationships**: References `Enrollment` and `Student` by ID.

**Lifecycle**: created with `checkOutAt = null`; optionally transitions to
`checkOutAt = <time>` once. There is no further mutation after that — an
Attendance record, once checked out (or once its Shift window has simply
passed with no checkout), is effectively immutable.

**Business Rules**
- BR-15: check-in is validated, at the moment of the attempt, against the
  Enrollment's status, the current time vs. the Shift window (with a
  configurable grace buffer), and the Branch's `CheckInPolicy` — this
  validation is a Domain Service (§14.10) reading across Enrollment,
  Shift, and Branch, not something Attendance can check about itself.
- BR-16: the specific policy (`hard_block`/`soft_warn`/`allow`) is a
  Branch-level setting (`CheckInPolicy` VO on Branch), not hardcoded here.
- BR-17: `checkOutAt = null` is a valid terminal state, not an error —
  checkout is never mandatory.

**Creation Rules**: Created by the check-in validation Domain Service
only — never constructed directly by a UI action without passing through
that validation.

**Update Rules**: The one permitted update is setting `checkOutAt`, once.

**Delete Rules**: Never hard-deleted — this is attendance history, subject
to the same permanence guarantee as Payments.

**Validation Rules**: `checkOutAt`, if set, must be `>= checkInAt`.

**Future Extensions**: Geofenced/biometric methods (P1/P2) are already
represented in the `method` enum — adopting them requires no schema
change, only a new implementation of the check-in Domain Service's
validation step for that method.

---

### 13. Expense

**Aggregate Root.** *(P1 feature; modeled now for schema stability.)*

**Purpose**: A manually recorded outgoing cost against a Branch (rent,
electricity, staff wages, maintenance) — gives the Owner P&L visibility
without becoming an accounting system (per the Non-goals in
[`02_Product_Requirements_Document.md`](02_Product_Requirements_Document.md)
§2.4).

**Fields**
| Field | Type |
|---|---|
| `id` | `ExpenseId` |
| `branchId` | `BranchId` |
| `organizationId` | `OrganizationId` |
| `category` | string |
| `amount` | `Money` |
| `note` | string |
| `incurredAt` | Date |
| `recordedBy` | `UserId` |

**Relationships**: References `Branch`/`Organization` only — a
self-contained record with no downstream dependents.

**Lifecycle**: Created once; editable until "closed" by a future
reporting-period-lock concept (not modeled at P1 scope) — for now, simply
mutable by an Owner at any time.

**Business Rules**: Expenses are purely informational — they do not gate
or interact with any Enrollment/FeeCycle/Payment behavior; this is a
deliberate scope boundary (we are not accounting software).

**Creation Rules**: Created by an active Owner (financial visibility is
Owner-only per the reasoning in BR-24, though the specific write-permission
grant is a §07 rules-table detail, not a domain constraint).

**Update Rules**: `category`/`amount`/`note`/`incurredAt` editable by an
Owner.

**Delete Rules**: Owner may delete an Expense record outright — unlike
Payment/Attendance, an Expense is not a trust-critical financial ledger
entry *from the Student relationship's perspective*; it's the Owner's own
private bookkeeping, so the append-only guarantee that governs Payment
does not apply here. (If this changes — e.g. Expense data ever feeds a
shared/audited P&L export — this rule should be revisited before P1 ships,
not silently inherited from Payment's stricter model.)

**Validation Rules**: `amount.amount > 0`; `category` non-empty.

**Future Extensions**: Recurring expense templates (P2) generate
Expense records on a schedule — an added Domain Service, not a change to
this aggregate.

---

### 14. Announcement

**Aggregate Root.**

**Purpose**: A Branch's broadcast message to some or all of its Students.

**Fields**
| Field | Type |
|---|---|
| `id` | `AnnouncementId` |
| `branchId` | `BranchId` |
| `organizationId` | `OrganizationId` |
| `title` | string |
| `body` | string |
| `audienceFilter` | `AnnouncementAudience` (`all \| overdue_only \| custom`) |
| `channels` | `AnnouncementChannel[]` (`push \| sms \| whatsapp`) |
| `sentAt` | DateTime |

**Relationships**: References `Branch`/`Organization`. Its `audienceFilter`
is resolved against the Branch's Student/Enrollment aggregates at send
time by a Domain Service (§14.10) — Announcement does not hold a list of
recipient IDs itself, which would make it enormous and stale the moment
any Enrollment's overdue status changed.

**Lifecycle**: Created and immediately sent (`sentAt` set at creation) —
there is no "draft" state at MVP scope.

**Business Rules**: FR-10.1's manual broadcast and FR-10.2's automated
lifecycle messages (welcome, due, paid, expiry warning) are two different
originators of an Announcement-like send, but automated lifecycle
messages are **not** modeled as Announcement records — they're a direct
notification side effect of Enrollment/FeeCycle Domain Events (§14.6),
kept out of this aggregate because they're per-Student, not
per-broadcast, and have no meaningful "audience filter" of their own.

**Creation Rules**: Created by an Owner or Receptionist at the Branch.

**Update Rules**: Immutable once sent (no "edit a sent announcement").

**Delete Rules**: Retained indefinitely as a record of what was
communicated and when — not deleted.

**Validation Rules**: `title`/`body` non-empty; `channels` non-empty.

**Future Extensions**: Two-way chat (P2) is a materially different
concept (per-conversation, not per-broadcast) and would be a new
aggregate, not an extension of Announcement.

---

### Dashboard — Read Model (not an Aggregate)

**Explicitly not a DDD Entity or Aggregate** — flagged prominently because
correctly recognizing this is itself the point. A Dashboard has no
identity beyond "the current state of one Branch's numbers," no lifecycle
of its own transitions, and no business rules to protect — it is a
**projection**, continuously recomputed from Domain Events raised by the
real aggregates (Enrollment, FeeCycle, Attendance, Seat). This is a
CQRS-style read model sitting on the query side, deliberately separate
from the write-side aggregates described everywhere else in this
document.

**Purpose**: Serve the Owner's "Reports" (FR-1.4, FR-8.1) — occupancy,
revenue, overdue totals — in roughly constant time regardless of how much
history a Branch has accumulated, per
[`08_System_Architecture.md`](08_System_Architecture.md) §8.13 and
[`07_Firestore_Schema.md`](07_Firestore_Schema.md) §7.6.

**Fields** (all derived, never independently authored):
`branchId`, `occupiedSeatsByShift`, `totalSeatsByShift`, `overdueCount`,
`overdueAmount: Money`, `todayCheckIns`, `updatedAt`.

**Relationships**: Consumes `EnrollmentCreated`, `EnrollmentStatusChanged`,
`EnrollmentEnded`, `PaymentRecorded`, `FeeCycleBecameOverdue`,
`AttendanceRecorded`, `SeatCreated`/`SeatDeactivated` events, all scoped
to one `branchId`.

**"Lifecycle"**: recomputed (fully or incrementally) on every relevant
Domain Event; never independently created, updated, or deleted by a user
action.

**"Business Rules"**: **eventual consistency is acceptable and expected**
— a Dashboard tile may lag the true aggregate state by a short window
(seconds), and that is an explicit, intentional trade-off (§8.6/§8.13),
distinct from every write-side aggregate in this document, where
correctness is never allowed to lag (NFR-6).

**"Creation/Update/Delete Rules"**: Initialized alongside its Branch;
recomputed continuously thereafter; removed only if the Branch itself is
(which, per Branch's own Delete Rules, effectively never happens).

**Validation Rules**: N/A — a read model has nothing to validate; it can
only be "stale" or "current," never "invalid," since it's never the
source of truth for anything.

**Future Extensions**: A cross-Branch Organization rollup (P1) and a
future BigQuery-backed analytics warehouse (P2/P3, per
[`08_System_Architecture.md`](08_System_Architecture.md) §8.13) are both
*more* read models of the same kind, layered on top of the same
write-side aggregates — never a reason to add fields or logic to the
write-side domain model itself.

---

## Platform Billing context

### 15. Subscription (with child entity SubscriptionEvent)

**Aggregate Root** (owns **SubscriptionEvent** as a child Entity).

**Purpose**: Our billing relationship with the Organization — entirely
distinct from anything a Student pays (§14.3). Lives in its own bounded
context because its stakeholders (us and the Owner, as a *commercial*
relationship) and its language (`planTier`, `billingCycle`) are genuinely
different from the Branch Operations context, even though both mention
"plans."

**Fields**
| Field | Type |
|---|---|
| `id` | `SubscriptionId` (always equal to the owning `OrganizationId`) |
| `organizationId` | `OrganizationId` |
| `planTier` | `SubscriptionTier` (`starter \| growth \| pro \| enterprise`) |
| `billingCycle` | `BillingCycle` (`monthly \| annual`) |
| `status` | `SubscriptionStatus` (`trialing \| active \| past_due \| suspended \| cancelled`) |
| `currentPeriod` | `DateRange` |
| `seatLimit` | integer |
| `branchLimit` | integer |
| `staffLimit` | integer |
| `messagingCreditsRemaining` | integer |
| `history` | `SubscriptionEvent[]` (child entities) |

**SubscriptionEvent** (child entity):
| Field | Type |
|---|---|
| `id` | `SubscriptionEventId` |
| `type` | `created \| upgraded \| downgraded \| renewed \| suspended \| cancelled \| trial_extended` |
| `fromTier` | `SubscriptionTier \| null` |
| `toTier` | `SubscriptionTier \| null` |
| `actorId` | `UserId` |
| `at` | DateTime |

**Relationships**: `id == organizationId` structurally enforces FR-11.1
("exactly one current Subscription per Organization") — this is an
identity design choice doing the work of an invariant, not a rule that
needs separate runtime enforcement. References `Organization` by ID only;
Organization does not reference it back (Subscription state changes
should never require loading/locking the Organization aggregate).

**Lifecycle**:
```
trialing → active ⇄ past_due → suspended → active/cancelled
    │                                          ↑
    └──────────────────────────────────────────┘ (upgrade from trial)
```
Every transition appends a `SubscriptionEvent` in the same operation —
`history` is never out of sync with `status`, because they're the same
aggregate and the same transaction (unlike the Organization-level
"suspended" flag it drives, which is a separate aggregate reacting to a
Domain Event, per Organization's own Lifecycle section).

**Business Rules**
- FR-11.1/FR-11.2: exactly one Subscription per Organization; feature/
  usage gates read from this aggregate's `*Limit` fields.
- BR-26: limits are enforced at the point of the write that would exceed
  them (in the *other* aggregate being created — Seat, Branch,
  Receptionist), by reading this aggregate's current limits — a
  cross-aggregate check, not something Subscription enforces on itself.
- BR-27: `suspended` triggers Organization-level read-only mode via a
  Domain Event; Subscription itself never reaches into Branch/Enrollment
  data directly.

**Creation Rules**: Created atomically with the Organization
(`status = trialing`), per [`11_Subscription_Model.md`](11_Subscription_Model.md)
§11.4 — there is no window where an Organization exists without a
Subscription.

**Update Rules**: `planTier`/`billingCycle`/limits change only via
explicit upgrade/downgrade behaviors that also append a
`SubscriptionEvent` — never a raw field write. Downgrade is rejected
(§11.5) if current usage (Seats, Branches, Staff — read cross-aggregate at
the Application layer, not by this aggregate reaching out itself) already
exceeds the target tier's limits.

**Delete Rules**: Never hard-deleted — `cancelled` is terminal but
retained, preserving full billing history indefinitely.

**Validation Rules**: `currentPeriod.end > currentPeriod.start`; all
`*Limit` fields `>= 0`.

**Future Extensions**: A revenue-share billing model (P3, via Razorpay
Route per [`08_System_Architecture.md`](08_System_Architecture.md) §8.8)
would likely add a `takeRatePercent`-style field here rather than
requiring a new aggregate — it's still fundamentally "our commercial terms
with this Organization."

---

## 14.7 Consolidated relationship diagram

```
                              Platform Billing context
                              ┌─────────────────────┐
                              │  Subscription        │
                              │   └─ SubscriptionEvent│
                              └──────────▲───────────┘
                                         │ organizationId
Branch Operations context               │
┌────────────────────────────────────────────────────────────────────┐
│  Organization ◄──────────────┐                                      │
│       ▲                      │ organizationId                       │
│       │ organizationId       │                                      │
│    Owner                  Branch ◄─────────────────────────┐        │
│                               │ branchId                    │        │
│              ┌────────────────┼────────────────┬───────────┤        │
│              ▼                ▼                 ▼           │        │
│         Receptionist        Shift             Seat ◄── Locker        │
│                                │                 │  (linkedSeatId)   │
│                                │ shiftId          │                  │
│                                ▼                 │                  │
│                          MembershipPlan           │                  │
│                                │ planId            │ seatId          │
│                                └────────┬──────────┘                 │
│                                         ▼                            │
│         Student ──studentId──►    Enrollment ◄──shiftId── (Shift)    │
│                                         │                            │
│                          ┌──────────────┼──────────────┐             │
│                          ▼                             ▼             │
│                     FeeCycle                       Attendance        │
│                       └─ Payment (child)                             │
│                                                                       │
│    Branch ──► Expense          Branch ──► Announcement                │
│                                                                       │
│    (Enrollment/FeeCycle/Attendance/Seat events) ──► Dashboard         │
│                                              (read model, not an     │
│                                               aggregate)              │
└────────────────────────────────────────────────────────────────────┘
```
Solid ownership (`◄──`/tree nesting) = child entity, same aggregate
boundary. Named-field arrows (`studentId`, `shiftId`, etc.) = reference to
a different aggregate root, by ID only, resolved by a repository at the
Infrastructure layer — never a live object graph at the Domain layer.

## 14.8 Lifecycle summary table

| Entity | States | Automatic transitions | Manual-only transitions |
|---|---|---|---|
| Organization | setup_incomplete, active, suspended | suspended (from Subscription event) | activation (via Domain Service, §14.10) |
| Owner | active, revoked | — | revoke (by another Owner) |
| Branch | active, inactive | — | both, by Owner |
| Receptionist | invited, active, revoked | invited→active (first sign-in) | revoke (by Owner) |
| Shift | isActive true/false | — | by Owner |
| Seat | active, maintenance, inactive | — | all, by Owner/Receptionist |
| Locker | available, assigned, maintenance | assigned→available (Enrollment end) | assign (Enrollment create), maintenance (Owner) |
| MembershipPlan | isActive true/false | — | by Owner |
| Student | active, archived | — | by Owner/Receptionist |
| Enrollment | active, overdue, at_risk, ended, cancelled | active→overdue→at_risk (fee-driven) | ended, cancelled (Owner/Receptionist only) |
| FeeCycle | pending, partially_paid, overdue, paid | all, driven by Payment events and due-date | — |
| Payment | succeeded, refunded | — | refund is a new linked record |
| Attendance | (open), (checked out) | — | checkout, once |
| Expense | (mutable) | — | edit/delete by Owner |
| Announcement | (sent) | — | none — immutable after send |
| Subscription | trialing, active, past_due, suspended, cancelled | active→past_due→suspended (non-payment) | upgrade/downgrade/cancel |

## 14.9 Hard invariants vs. cross-aggregate business rules

A disciplined DDD model distinguishes two very different kinds of "rule,"
and conflating them is a common source of either over-large aggregates or
silently-violable business rules:

**Hard invariants** — enforced automatically, inside a single aggregate's
transactional boundary, because the aggregate's own behavior makes the
violation structurally impossible:
- `FeeCycle.amountPaid` always equals the sum of its non-refunded child
  `Payment.amount`s (§FeeCycle).
- `Subscription.id == organizationId` (at most one Subscription per
  Organization, by construction).
- A `Receptionist` record names exactly one `branchId` (a singular field,
  not a collection).

**Cross-aggregate business rules** — cannot be hard invariants, because
the aggregates involved are, by design, independently transactable; these
are enforced by **Domain Services** (§14.10) at the moment of the relevant
write, and are check-then-act rather than automatically-impossible-to-violate:
- BR-1 (no double-booking) — spans Seat and Enrollment.
- "At least one active Owner" — spans Organization and Owner.
- BR-26 (Subscription limits) — spans Subscription and whatever's being
  created (Seat, Branch, Receptionist).
- BR-16 (check-in policy) — spans Branch, Enrollment, FeeCycle, and
  Attendance.

This is a deliberate design stance, not a gap: making every one of these
into a single mega-aggregate (e.g. "Organization owns everything") would
make the system correct in theory and unable to scale in practice — every
Branch's daily check-in/payment volume would contend on a single lock. The
chosen model keeps aggregates small and pushes cross-cutting correctness
into explicit, testable Domain Services instead.

## 14.10 Domain Services

Logic that legitimately spans more than one aggregate lives here, not
inside any single Entity:

- **Ownership Guard** — enforces "at least one active Owner" on every
  Owner-revoke attempt; enforces "Organization becomes `active` only once
  it has ≥1 Branch and ≥1 active Owner" on Organization activation.
- **Receptionist Assignment** — enforces the single-current-assignment
  rule (BR-23) on every Receptionist create/reassign.
- **Seat Availability** — the transactional double-booking guard (BR-1);
  the one service every Enrollment creation and seat/shift-change must go
  through. (Its physical realization as a Firestore lock document is an
  Infrastructure-layer detail — see
  [`07_Firestore_Schema.md`](07_Firestore_Schema.md) §7.5 — but the rule
  it enforces is a Domain concept, defined here.)
- **FeeCycle Generation** — creates upcoming FeeCycles ahead of their
  `periodStart` from each active Enrollment's `planSnapshot` (BR-9).
- **Overdue Evaluation** — drives Enrollment's automatic
  `active → overdue → at_risk` transitions and FeeCycle's `→ overdue`
  transition, against each Branch's configured grace period.
- **Check-In Validation** — BR-15/BR-16; reads Enrollment, Shift, and
  Branch's `CheckInPolicy` to decide whether an Attendance record may be
  created, and how (hard-block vs. warn).
- **Subscription Limit Enforcement** — BR-26; consulted by Seat/Branch/
  Receptionist creation before they're allowed to proceed.
- **Proration Calculator** *(P1)* — BR-8; computes a `FeeCycle.reprice(...)`
  amount when an Enrollment's Plan/Seat/Shift changes mid-cycle.
- **Announcement Audience Resolution** — resolves an
  `AnnouncementAudience` filter against current Student/Enrollment state
  at send time.

## 14.11 Extensibility themes (roadmap tie-in)

- **A third bounded context, Discovery (P2)**: `Lead` and `Review` become
  real aggregates once Phase 2 is scoped (see
  [`13_Product_Roadmap.md`](13_Product_Roadmap.md) §13.3) — deliberately
  not designed now, and deliberately not solved by weakening Student's
  Branch-ownership (§14.6's Student Future Extensions note).
- **Role-based permission granularity (P1/P2)**: `Role` becomes a
  genuinely configurable aggregate (today it's two fixed platform
  defaults) — Owner and Receptionist's shapes don't need to change, only
  the permission set a Receptionist's `roleId` resolves to.
- **Multi-currency (P3)**: isolated to the `Money` VO and a new
  `Organization.currency` field (§Organization Future Extensions) — no
  other aggregate references currency directly, by design, which is
  exactly the point of using a VO for it.
- **API access & white-label (P3)**: additive — external API consumers
  become another Infrastructure-layer client of the same Application-layer
  use cases described in
  [`08_System_Architecture.md`](08_System_Architecture.md) §8.4; this
  Domain Model does not change shape to support it.

## 14.12 Intentionally out of scope for this document

Referenced elsewhere in the architecture but not given full entity
treatment here, because they weren't in this pass's explicit list and
don't yet have enough real design pressure behind them to model correctly
rather than speculatively: **Role** (sketched in §14.6/§14.11 only),
**AuditLogEntry** (a cross-cutting, append-only record of Domain Events
rather than a business entity in its own right — see
[`07_Firestore_Schema.md`](07_Firestore_Schema.md) §7.2), **Coupon** and
**WaitlistEntry** (P1, briefly noted under MembershipPlan's and
Enrollment's Future Extensions respectively), and **Lead**/**Review**
(P2 Discovery context, §14.11). Each should get this same full template
treatment when its phase is actually scoped — modeling them precisely now,
ahead of real requirements pressure, would be exactly the kind of
speculative design this whole exercise is meant to avoid.
