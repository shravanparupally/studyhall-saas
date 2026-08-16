# 10. Business Rules

The domain rules that constrain every feature. These are the rules that
must live in the Domain/Application layers per
[`08_System_Architecture.md`](08_System_Architecture.md) §8.4 — not in UI
code, not assumed implicitly. Where a rule is Branch-configurable, that's
called out explicitly; everything else is a platform-wide invariant.

## 10.1 Seat & booking rules

- **BR-1**: A Seat may have at most one `active` Enrollment per Shift at any
  given time. Overlapping Enrollments for the same (Seat, Shift) are
  rejected at creation time (§7.5's lock-document mechanism), never merely
  discouraged in the UI.
- **BR-2**: A Seat can be sold for multiple different Shifts simultaneously
  (e.g. one Student holds it Morning, a different Student holds it Evening)
  — a Seat's "occupied" status is always Shift-relative, never a single
  Branch-wide flag.
- **BR-3**: Deactivating a Seat (maintenance) does not cancel existing
  active Enrollments on it; it only prevents *new* Enrollments from being
  created against it. An Owner must explicitly handle existing occupants
  (reassign or let the Enrollment run its course) — deactivation is never a
  silent eviction.
- **BR-4**: "Auto-assign nearest available" (§4.2) considers only Seats
  matching the selected Plan's required `seatType`, currently `active`, and
  with no conflicting Enrollment for the target Shift and date range.

## 10.2 Enrollment lifecycle rules

- **BR-5**: An Enrollment's `planSnapshot` (price, duration, seat type) is
  frozen at creation time. Subsequent changes to the Branch's
  MembershipPlan (price changes, deactivation) never retroactively alter an
  existing Enrollment (PRD FR-3.3).
- **BR-6**: An Enrollment transitions `active → overdue` automatically when
  its current FeeCycle passes `dueDate` unpaid, and `overdue → at_risk`
  after a Branch-configurable grace period (default: 3 days) with no
  payment.
- **BR-7**: An Enrollment never transitions to `ended` automatically. Ending
  an Enrollment (freeing the Seat for reassignment) is always an explicit
  Owner/Staff action, even for long-overdue accounts (§4.5) — the system
  surfaces the recommendation, it does not act unilaterally on a Student's
  seat access without a human decision, because the cost of a wrongful
  auto-eviction (an Owner's angry, paying-in-person-tomorrow Student loses
  their seat) is asymmetrically worse than the cost of one more day of an
  unresolved overdue account.
- **BR-8**: Mid-cycle Plan changes (upgrade/downgrade, shift change) prorate
  the remaining balance of the current FeeCycle rather than either
  double-charging or giving free days — proration is calculated on a
  per-day basis over the FeeCycle's `periodStart`/`periodEnd`. *(P1 feature;
  rule specified now so the FeeCycle model in §06/§07 doesn't need
  reshaping when it ships.)*

## 10.3 Fee & payment rules

- **BR-9**: FeeCycles are generated ahead of their `periodStart` (default:
  7 days ahead) by the scheduled `generateFeeCycles` function
  ([`08_System_Architecture.md`](08_System_Architecture.md) §8.5), never
  generated lazily on read — this guarantees the "next due date" is always
  known in advance for reminders, and guarantees a FeeCycle exists to
  attribute a payment to before that payment happens.
- **BR-10**: A Payment can only be recorded against a FeeCycle with
  remaining balance (`amountDue - amountPaid > 0`). Overpayment is rejected
  at the use-case layer, not silently accepted and left to reconcile later.
- **BR-11**: Partial payments are allowed *(P1)*; a FeeCycle's `status`
  becomes `partially_paid` when `0 < amountPaid < amountDue`, and it still
  counts toward "overdue" surfacing once past `dueDate`, regardless of
  partial payment — a partial payment does not reset the due-date clock.
- **BR-12**: Refunds are new, linked Payment records (`refundOf`), never
  edits or deletions of the original Payment (§07 append-only rule). A
  refunded FeeCycle's `amountPaid` is recomputed as the sum of its
  non-refunded Payments.
- **BR-13**: Cash payments recorded by Staff are immediately reflected in
  the Enrollment's status (no "pending owner confirmation" step) — Staff is
  trusted to record accurately at time of collection, with the audit trail
  (`recordedBy`) providing after-the-fact accountability rather than a
  blocking approval step that would slow down front-desk operations
  (conflicts directly with the Staff persona's speed requirement, §3.2, if
  handled otherwise).
- **BR-14**: Security deposits *(P1)*, where a Branch collects one, are
  tracked as a distinct ledger line from FeeCycle payments — a deposit is
  refundable independent of fee-payment history and must never be
  conflated with regular membership fee revenue in reporting.

## 10.4 Attendance & check-in rules

- **BR-15**: Check-in is validated against three conditions at the moment
  of scan: the Enrollment is not `ended`/`cancelled`, the current time
  falls within the Enrollment's Shift window (with a Branch-configurable
  grace buffer, default 30 minutes either side), and the Enrollment's
  overdue status is within the Branch's configured check-in policy
  (below).
- **BR-16**: **Overdue check-in policy is Branch-configurable**, not
  platform-fixed: a Branch may choose `hard_block` (no entry until paid),
  `soft_warn` (Staff sees a warning, can override), or `allow` (no
  restriction). Default is `soft_warn` — this reflects that different
  Owners have different tolerance for the social cost of turning away a
  regular Student over a short delay, and it is not our place to force one
  policy (this is explicitly called out because it's the kind of rule that
  gets hardcoded by accident during implementation if not stated
  up front).
- **BR-17**: A check-out is optional, not required to close out a valid
  attendance session — many Study Hall use patterns don't involve a strict
  checkout ritual, and mandating one would create friction with no
  corresponding value; `checkOutAt` being null is a valid terminal state,
  not an error condition, once the Shift window has passed.

## 10.5 Locker rules *(P1)*

- **BR-18**: A Locker is assigned only as part of an active Enrollment
  whose Plan/Seat includes `hasLocker`; it cannot be independently rented
  without a corresponding Enrollment.
- **BR-19**: Ending an Enrollment automatically releases its Locker back to
  `available` status — unlike Seats (BR-3, human-decision required),
  Locker release is safe to automate because it carries no seat-reassignment
  ambiguity, only a physical-cleanout operational step for Staff.

## 10.6 Waitlist rules *(P1)*

- **BR-20**: A WaitlistEntry is created only when no matching Seat exists
  for the requested (Shift, seatType) combination at the time of request.
- **BR-21**: When a matching Seat becomes available (Enrollment ends or
  Seat is added), the oldest `waiting` WaitlistEntry for that (Shift,
  seatType) is notified first and given a Branch-configurable holding
  window (default 24 hours) to convert before the offer passes to the next
  entry — first-come-first-served, not Owner-discretionary, to keep the
  mechanism trustworthy to Students.

## 10.7 Branch isolation & access-control rules

- **BR-22**: Every write operation is authorized server-side against the
  actor's `orgAccess` claim (§7.4) — the Flutter apps' UI hiding a button
  from an unauthorized role is a UX convenience, never the actual security
  boundary.
- **BR-23**: A Receptionist cannot read or act on any Branch other than
  the single one they're assigned to, even within the same Organization,
  under any circumstance — there is no role or permission escalation path
  that grants a Receptionist a second Branch; reassignment means revoking
  the old assignment and creating a new one (§7.2), never adding to it.
  This is enforced at four independent layers simultaneously — Firestore
  document paths (§7.1), security rules (§7.4), repository interface
  signatures (§8.4), and Cloud Function authority checks (§8.5) — precisely
  because "the rules will catch it" is not true for server-side code paths
  that use the Admin SDK.
- **BR-24**: Only the Owner role can manage the Organization's Platform
  Subscription, invite/revoke Receptionists, define/edit Shifts, Seats, or
  Membership Plans, or view the Organization-level cross-Branch rollup.
  Owner access to every Branch is implicit and uniform (it follows from
  the `owners/{userId}` record existing at the Organization level, per
  [`07_Firestore_Schema.md`](07_Firestore_Schema.md) §7.2) — never a
  per-Branch grant that a Branch could be accidentally left out of.
- **BR-25**: Multi-branch isolation is a day-one architectural invariant,
  not a feature that gets "turned on" past some tier or scale — an
  Organization with exactly one Branch is modeled identically to one with
  fifty; there is no simplified single-Branch code path that skips the
  Branch-scoping requirement. This is what makes it safe for an
  Organization to add a second Branch at any time without a data migration
  (see [`11_Subscription_Model.md`](11_Subscription_Model.md) for the
  *pricing* limits on branch count, which are a separate, commercial
  concern from this architectural one).

## 10.8 Platform Subscription enforcement rules

- **BR-26**: Feature/usage gates (seat limit, branch limit, staff limit,
  messaging credits) are enforced at the point of the write that would
  exceed them (e.g. adding the Nth+1 Seat when `seatLimit == N` is
  rejected with a clear upgrade prompt), never after the fact via a
  retroactive cleanup — this avoids ever needing to decide "which of these
  already-created Seats do we now disable" (see
  [`11_Subscription_Model.md`](11_Subscription_Model.md) for tier limits).
- **BR-27**: A `suspended` Platform Subscription (non-payment) puts the
  Organization into read-only mode for Owners and Receptionists alike —
  existing data remains fully visible and exportable, but no new
  Enrollments, Payments, or Attendance can be recorded, and Student-facing
  check-in/payment flows for that Branch are disabled with a clear
  message, until the Subscription is reactivated. **Suspension never
  deletes or hides historical Organization data** — this is a
  business-continuity guarantee we make explicitly to Owners, given how
  much operational trust is at stake if a small business ever perceived us
  as holding their own records hostage.

## 10.9 Cross-cutting rules

- **BR-28**: Every mutation to Enrollment, FeeCycle, Payment, or
  PlatformSubscription state writes an AuditLogEntry in the same logical
  operation (same use case, same transaction where feasible) — audit
  logging is not a best-effort side effect bolted on later.
- **BR-29**: Monetary values are never represented or compared as
  floating-point numbers anywhere in the system, client or server (§7.7) —
  this rule is stated here, not just in the schema doc, because it governs
  application-layer arithmetic (proration, partial-payment remainder
  calculation, refund math) just as much as storage.
