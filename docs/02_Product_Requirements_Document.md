# 02. Product Requirements Document (PRD)

Status: Draft for review. Scope described here is the **full product vision**,
not the MVP — MVP scope is cut down explicitly in
[`12_MVP.md`](12_MVP.md). Treat every requirement below as "the system must
eventually support this," not "this ships first."

## 2.1 Scope of this document

This PRD covers the product as a whole: the Owner-facing management system,
the Student-facing membership experience, and the platform-level concerns
(billing us, multi-tenancy, the public discovery layer). Detailed screen-by-screen
UX is not specified here — see [`04_User_Flows.md`](04_User_Flows.md) and
[`09_UI_UX_Guidelines.md`](09_UI_UX_Guidelines.md). Detailed field-level data
requirements live in [`06_Database_Design.md`](06_Database_Design.md).

## 2.2 Definitions (used consistently across every doc in this repo)

| Term | Meaning |
|---|---|
| **Organization** (Tenant) | A Study Hall business — the paying SaaS customer. May own 1..N Branches. |
| **Branch** | A single physical location belonging to an Organization. Has its own seats, shifts, staff, and fee collection. |
| **Seat** | A single, individually bookable unit of physical space within a Branch (a chair/desk/cabin). |
| **Shift** | A named, recurring time window a Branch sells seat access for (e.g. Morning 6am-2pm, Full Day, 24-Hour). Branch-defined, not global. |
| **Membership Plan** | A priced combination of (Shift + Seat Type + Duration) that a Branch offers to Students. |
| **Enrollment** | An instance of a Student holding an active or past Membership Plan on a specific Seat at a specific Branch. |
| **Platform Subscription** | The recurring fee the **Organization pays us** to use the software. Entirely separate from Membership Plans. |
| **Owner** | The individual (or individuals) who own/administer an Organization. Our paying customer's primary user. |
| **Receptionist** | Staff-level user scoped to exactly one Branch, with a restricted, day-to-day-operations permission set. One of exactly two default roles, alongside Owner. |
| **Student / Member** | The end customer of the Study Hall, who holds an Enrollment. |
| **Platform Admin** | Our internal team, operating the platform itself (support, billing ops, content moderation). |

## 2.3 Goals

1. Replace notebook/Excel/WhatsApp-based operations with a single system of
   record for seats, shifts, fees, and attendance.
2. Make fee collection predictable: automated dues tracking, reminders, and
   online payment, reducing owner revenue leakage from missed/forgotten dues.
3. Give owners real-time visibility into occupancy, revenue, and churn
   without manual reconciliation.
4. Provide a student-facing experience good enough that owners can point new
   walk-ins to "download the app" instead of manually onboarding them.
5. Build a foundation (multi-tenant, multi-branch, RBAC) that scales to
   thousands of Organizations without re-architecture.
6. (Phase 2+) Enable student discovery of study halls, turning platform
   density into a demand-generation channel for every Owner on it.

## 2.4 Non-goals

- We are not building general-purpose coworking/gym/library software with a
  generic "resource" abstraction — seats and shifts are modeled specifically
  for the exam-prep study hall use case (see [`10_Business_Rules.md`](10_Business_Rules.md)).
- We are not building a payments/settlement company. We integrate a
  third-party payment gateway (Razorpay, India-first, UPI-capable) rather
  than handling money movement ourselves.
- We are not building accounting/GST-filing software. Expense tracking is
  operational visibility for the owner, not a Tally/QuickBooks replacement.
- We are not supporting non-Indian markets, currencies, or tax regimes in
  the initial architecture (though nothing should make it structurally
  impossible later — see [`08_System_Architecture.md`](08_System_Architecture.md)).

## 2.5 Functional requirements

Grouped by module. Full feature-level detail is in
[`05_Feature_List.md`](05_Feature_List.md); this section states the
requirement, not the UI.

### FR-1: Organization & Branch Management
- FR-1.1: A new Organization can be created via self-serve signup (Owner
  identity verified via phone OTP).
- FR-1.2: An Organization can have one or more Branches, each with its own
  address, contact number, operating hours, and timezone (India-only at
  launch, but not hardcoded).
- FR-1.3: Data belonging to one Organization must never be readable or
  writable by another Organization under any role, including staff error.
- FR-1.4: **Branch is a first-class isolation boundary, not just a
  grouping field.** Every Branch-scoped resource — Seats, Students,
  Memberships (Membership Plans + Enrollments), Payments, Receptionists,
  and Reports — is exclusively owned by its Branch. This is architected
  identically for every Organization regardless of how many Branches it
  has (a 1-Branch Organization is not a "simplified special case" — it is
  the same model with one Branch). See FR-7.4 for the two-tier access
  model this enables, and
  [`06_Database_Design.md`](06_Database_Design.md) §6.6 for how this is
  enforced at the data-model level.

### FR-2: Seat & Layout Management
- FR-2.1: A Branch defines a set of Seats, each with a human-readable label
  (e.g. "A-12"), a zone/floor, a type (e.g. AC/Non-AC, Cabin/Open), and
  whether it includes a locker.
- FR-2.2: Owners/Managers can view a visual seat map showing real-time
  occupancy status per shift.
- FR-2.3: A Seat's availability is computed per Shift, not just per day — the
  same physical seat can be sold to different Students for different Shifts.
- FR-2.4: Deactivating a Seat (e.g. under maintenance) must not delete its
  historical enrollment/attendance data.

### FR-3: Shift & Membership Plan Management
- FR-3.1: A Branch defines its own Shifts (name, start time, end time, days
  of week active).
- FR-3.2: A Branch defines Membership Plans as a priced combination of Shift
  + Seat Type + Duration (e.g. 1 month / 3 months / 6 months / 12 months).
- FR-3.3: Plan pricing changes must not retroactively alter already-active
  Enrollments' pricing.

### FR-4: Student Enrollment & Onboarding
- FR-4.1: A Student can be onboarded by staff (walk-in flow) or can self-register
  via the Student app/portal (see FR-9).
- FR-4.2: Enrollment requires: identity capture (name, phone, photo,
  optional ID document), Plan selection, Seat assignment (specific seat or
  "any available"), and start date.
- FR-4.3: The system must prevent double-booking: the same Seat cannot have
  two overlapping active Enrollments for the same Shift.
- FR-4.4: **A Student record is owned by exactly one Branch**, consistent
  with FR-1.4 — Students are not a platform-level identity. If the same
  person joins a second Branch (their own or a different Organization
  entirely), that is a second, independent Student record, isolated from
  the first. What *is* shared across Branches is the person's sign-in
  identity (phone number / Firebase Auth account) — the Student app uses
  that single sign-in to look up every Branch-owned Student record linked
  to it (see [`07_Firestore_Schema.md`](07_Firestore_Schema.md) §7.2,
  `authUid` field), so the person still has one login, even though their
  data at each Branch is fully isolated and does not merge.

### FR-5: Fee & Payment Management
- FR-5.1: Every Enrollment generates a fee schedule based on its Plan
  (billing cycle, amount, due dates).
- FR-5.2: Students/staff can record a payment against a due fee: online
  (payment gateway) or offline (cash/manual entry by staff, reconciled by
  the Owner).
- FR-5.3: The system tracks outstanding dues per Student and surfaces
  overdue accounts to Owners/Managers.
- FR-5.4: Automated reminders (push/SMS/WhatsApp) fire on a configurable
  schedule ahead of and after a due date.
- FR-5.5: Every payment produces an auditable, immutable record (see
  FR-11.3) sufficient to reconstruct an Owner's revenue for any date range.

### FR-6: Attendance Management
- FR-6.1: Students check in/out via a method appropriate to the Branch's
  tier (QR code scan at MVP; biometric/geofence-assisted in later phases).
- FR-6.2: Attendance is attributed to a specific Enrollment/Shift, enabling
  no-show and utilization reporting.
- FR-6.3: Owners can view attendance history per Student and per Seat.

### FR-7: Staff & Role-Based Access Control
- FR-7.1: The system ships two default roles: **Owner** and
  **Receptionist**. An Owner can invite Receptionists and assign each one
  to exactly one Branch.
- FR-7.2: Permissions are enforced server-side for every operation, not just
  hidden in the UI (see [`08_System_Architecture.md`](08_System_Architecture.md) §Security).
- FR-7.3: Custom roles (finer-grained permission sets, still Branch-scoped)
  are a later-phase capability; Owner and Receptionist cover the MVP
  operating model.
- FR-7.4: **Two-tier access, enforced identically everywhere**: an Owner
  has implicit read/write access to every Branch under their Organization
  (no per-Branch grant needed — access follows from the Owner relationship
  itself); a Receptionist has access to exactly one assigned Branch and
  none other, with no exceptions or escalation path short of the Owner
  reassigning them. This rule must hold at every layer independently —
  Firestore queries, security rules, repository interfaces, and UI — per
  [`06_Database_Design.md`](06_Database_Design.md) §6.6 and
  [`07_Firestore_Schema.md`](07_Firestore_Schema.md) §7.4.

### FR-8: Reporting & Analytics
- FR-8.1: Owners see, at minimum: current occupancy %, monthly revenue,
  outstanding dues total, and Student churn, per Branch and rolled up across
  the Organization.
- FR-8.2: Reports must be exportable (CSV at minimum) for the Owner's own
  offline recordkeeping.

### FR-9: Student-Facing Experience
- FR-9.1: A Student can search/browse Branches (Phase 2 discovery; single-Branch
  deep link at MVP), view seat availability and pricing, and request/complete
  enrollment.
- FR-9.2: A Student can view their own dues, pay online, view their
  attendance history, and receive Branch announcements.
- FR-9.3: A Student's sign-in (phone number) persists across Organizations
  and Branches, so relocating to a new Study Hall never requires a new
  account — but per FR-4.4, their Student *record* (dues, attendance,
  history) at the old Branch does not travel with them; a fresh Student
  record is created at the new Branch.

### FR-10: Communication
- FR-10.1: Owners/Managers can broadcast announcements to all active
  Students of a Branch, or to a filtered subset (e.g. only overdue accounts).
- FR-10.2: Automated lifecycle messages (welcome, payment due, payment
  received, expiry warning) are sent without manual staff action.

### FR-11: Platform & Billing (us ↔ Organization)
- FR-11.1: Every Organization has exactly one Platform Subscription at a
  time, on a plan defined in [`11_Subscription_Model.md`](11_Subscription_Model.md).
- FR-11.2: Feature access and usage limits (seats, branches, staff seats,
  messaging credits) are gated by the active Platform Subscription tier.
- FR-11.3: All financially significant events (payments, refunds, plan
  changes) are written to an append-only audit trail, independent of the
  mutable "current state" documents.

## 2.6 Non-functional requirements

| ID | Requirement |
|---|---|
| NFR-1 | **Multi-tenancy isolation**: cross-Organization data leakage is a Sev-1 class defect, tested explicitly, not assumed from correct query filters alone (see security rules in [`07_Firestore_Schema.md`](07_Firestore_Schema.md)). |
| NFR-2 | **Availability**: core Owner operations (check-in, seat assignment, payment recording) target 99.9% availability; a single Branch's downtime must never be caused by another Branch's load or data volume. |
| NFR-3 | **Offline resilience**: the Student check-in flow and the Owner's seat map must degrade gracefully (queue-and-sync) under intermittent connectivity, reflecting real network conditions in tier-2/3 towns. |
| NFR-4 | **Scalability**: architecture must support tens of thousands of Organizations and millions of Students without a data-model rewrite; horizontal scaling is a default assumption, not a future migration. |
| NFR-5 | **Latency**: seat map and dues views must render in under ~1.5s on a mid-range Android device on 4G, given this is the dominant device/network profile for the target market. |
| NFR-6 | **Data correctness over data completeness**: it is preferable for a feature to be unavailable than for it to show incorrect fee/attendance numbers to an Owner — this drives conservative defaults throughout (see [`10_Business_Rules.md`](10_Business_Rules.md)). |
| NFR-7 | **Security & privacy**: Student PII (ID documents, phone numbers) is access-controlled per Organization and per role; see [`08_System_Architecture.md`](08_System_Architecture.md) §Security and data-retention policy. |
| NFR-8 | **Localization-ready**: UI strings are never hardcoded in a way that blocks future Hindi/regional-language support, even though English/Hindi-mixed is sufficient at MVP. |
| NFR-9 | **Auditability**: every mutation to fee, attendance, or Enrollment state is traceable to an actor (user or system job) and a timestamp. |
| NFR-10 | **Upgrade safety**: schema and API changes must be backward-compatible or migration-scripted; we will have live production tenants from very early on, and there is no "maintenance window" acceptable to a small business running daily operations through us. |

## 2.7 Assumptions & constraints

- Primary device for both Owners and Students is Android; iOS support is
  expected but not assumed to be the dominant platform at launch.
- Phone number (not email) is the primary identity anchor for both Owners
  and Students, consistent with Indian consumer product norms.
- Internet connectivity at Branch locations is often WiFi-optional,
  mobile-data-primary, and not always reliable — this is a constraint on
  every real-time feature (check-in, seat map), not an edge case.
- Cash remains a legitimate, common payment method at Branches for the
  foreseeable future; the product must represent offline/cash payments as
  first-class, not as a workaround.
- We build for India-specific payment rails (UPI-first) and communication
  channels (SMS + WhatsApp, not email, as the reliable reach channel to
  Students).

## 2.8 Success metrics (product-level, not business-plan-level)

- **Owner activation**: % of newly signed-up Organizations that complete
  Branch + Seat + first Student Enrollment setup within 7 days.
- **Fee-collection lift**: reduction in average days-fee-overdue for
  Organizations, pre- vs. post-adoption (self-reported baseline at onboarding).
- **Retention**: Organization month-over-month Platform Subscription
  retention.
- **Student engagement**: % of Enrollments where the Student completes at
  least one in-app payment (vs. cash-only, staff-recorded).

## 2.9 Open questions to resolve before/at MVP build

These are flagged, not answered, here — they should be resolved during MVP
scoping ([`12_MVP.md`](12_MVP.md)) or explicitly deferred with a documented
reason.

1. Do we build one Flutter app with role-based views (Owner/Staff/Student),
   or two separate apps? (Leaning: two apps — the Owner/Staff experience is
   dense/operational, the Student experience is consumer-light; conflating
   them risks a mediocre experience for both. Final call belongs in
   [`08_System_Architecture.md`](08_System_Architecture.md).)
2. Which payment gateway partner (Razorpay vs. Cashfree vs. others) and
   what settlement model (platform account vs. Owner's own merchant
   account via Razorpay Route) — affects compliance scope significantly.
3. WhatsApp Business API provider selection and cost model, given
   per-message pricing affects the Platform Subscription's unit economics.
