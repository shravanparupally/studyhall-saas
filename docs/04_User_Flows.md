# 04. User Flows

End-to-end journeys per persona (see [`03_User_Personas.md`](03_User_Personas.md)).
These are logical flows — step sequences and decision points — not wireframes
(see [`09_UI_UX_Guidelines.md`](09_UI_UX_Guidelines.md) for visual treatment).
Flows marked **(MVP)** are in initial scope per [`12_MVP.md`](12_MVP.md); others
are full-vision flows for later phases.

---

## 4.1 Owner: Organization signup & first Branch setup **(MVP)**

1. Owner opens the app/web signup, enters phone number, verifies via OTP.
2. Owner enters Organization name (their business name) and creates their
   first Branch: name, address, contact number, operating hours.
3. Owner is prompted to select a starting Platform Subscription tier (trial
   defaults available — see [`11_Subscription_Model.md`](11_Subscription_Model.md)).
4. Owner defines Shifts for the Branch (system offers sensible defaults:
   Morning, Evening, Full Day, 24-Hour — editable).
5. Owner adds Seats: either one-by-one, or in bulk ("add 60 seats, zone
   Ground Floor, type Non-AC" — generates A-1..A-60).
6. Owner defines at least one Membership Plan (Shift + Duration + Price)
   before the Branch is marked "ready."
7. System surfaces the Branch's public seat-map dashboard — empty state
   shows "no students yet, add your first student" as the clear next action.

**Decision points**: If the Owner has more than one physical location, step 2
loops — each additional Branch repeats steps 2-6 independently (Shifts, Seats,
and Plans are Branch-scoped, not shared, since pricing/hours legitimately
differ by location).

**Failure/edge handling**: OTP delivery failure → fallback to voice call OTP.
Owner abandons mid-setup → Organization persists in "incomplete setup" state,
resumable, and is excluded from any Owner-facing analytics until first Branch
is marked ready.

---

## 4.2 Staff: Walk-in student enrollment **(MVP)**

This is the single highest-frequency flow in the whole product and is
optimized above all others for speed (see Sunita persona, §3.2).

1. Staff taps "New Student" from the seat map or a dedicated quick-action.
2. Staff captures: name, phone number, photo (camera), optional ID document
   photo.
3. Staff selects a Membership Plan (Branch's existing plans shown as tappable
   cards, not a form).
4. System shows only Seats available for that Plan's Shift; staff taps a
   seat (or "auto-assign nearest available").
5. Staff selects start date (defaults to today) and payment method:
   - **Paid now (cash)**: staff marks amount received, system generates a
     receipt.
   - **Paid now (online)**: system generates a payment link/QR, student pays
     on their own phone, staff sees live confirmation.
   - **Pay later**: Enrollment is created with a due fee dated per the Plan's
     terms (see [`10_Business_Rules.md`](10_Business_Rules.md) for grace
     period rules).
6. Enrollment is created; the seat map updates immediately; a welcome
   message is queued to the student (SMS/WhatsApp) with their login link and
   receipt.

**Decision points**: If the phone number already has a Student record *at
this Branch* (a returning student re-enrolling after a lapsed Enrollment),
staff is shown "existing student found at this Branch" and reuses that
Student record rather than duplicating it, then simply adds a new
Enrollment. A phone number that exists as a Student at a *different*
Branch or Organization is not matched — per FR-4.4, Student records are
Branch-owned, so this is always treated as a new Student record here, even
though the person's sign-in (phone number) is the same one they may use
elsewhere.

**Failure/edge handling**: Selected seat gets taken by a concurrent
Enrollment attempt (race condition, e.g. two staff members on two devices)
→ system rejects the second attempt with an immediate "seat just taken,
choose another" — this must never silently overbook (see NFR-6, and
optimistic-locking approach in [`08_System_Architecture.md`](08_System_Architecture.md)).

---

## 4.3 Staff: Daily check-in **(MVP)**

1. Student arrives, shows their in-app QR (or staff looks them up by
   name/phone if the student has no smartphone access that day).
2. Staff scans the QR with the front-desk device.
3. System validates: Enrollment is active, fee is not overdue beyond grace
   period (see [`10_Business_Rules.md`](10_Business_Rules.md)), Shift is
   currently valid for check-in.
4. On success: attendance recorded, seat map shows "occupied," done — no
   further taps.
5. On failure (e.g. overdue): staff sees a clear reason and a one-tap path
   to "record payment now" before allowing entry, at the Owner's configured
   policy (see business rules — this can be a hard block or a soft warning
   depending on Branch settings).

**Decision points**: Student self-check-in (scanning a Branch-posted QR with
their own phone, no staff involved) is a later-phase flow, layered on top of
the same underlying attendance model — not a separate system.

---

## 4.4 Owner: Morning review **(MVP)**

1. Owner opens the app, lands on a Branch (or Organization roll-up if
   multi-branch) dashboard.
2. Sees at a glance: occupancy % right now, students overdue on fees (count
   + total ₹ amount), any seats flagged idle for N+ days.
3. Taps into "Overdue" → sees list, can trigger a reminder broadcast to all
   of them in one action, or call/message individuals.
4. Taps into "Occupancy" → sees the seat map, can identify long-idle seats
   for follow-up (e.g. a student who stopped showing up but hasn't formally
   left).

---

## 4.5 Owner: Fee reminder & renewal cycle **(MVP)**

1. System auto-computes each Enrollment's next due date from its Plan's
   billing cycle.
2. N days before due (Branch-configurable, sensible default), an automated
   reminder is sent to the Student (push if app installed, else
   SMS/WhatsApp).
3. On the due date, if unpaid, Enrollment enters "overdue" state; a second
   reminder fires.
4. After the Branch's configured grace period, Enrollment is flagged
   "at risk" on the Owner dashboard; check-in policy per §4.3 applies.
5. Student pays (online self-serve, or staff records cash) → Enrollment
   returns to "active," receipt generated, confirmation sent.
6. If unresolved beyond a second, longer threshold, Owner/Staff can mark the
   seat "released," ending the Enrollment and freeing the seat for
   reassignment — this is a manual Owner/Staff decision, never fully
   automatic (see [`10_Business_Rules.md`](10_Business_Rules.md)).

---

## 4.6 Student: Self-registration & first payment **(MVP for the payment/dues portion; discovery search is Phase 2)**

1. Student receives a Branch-specific join link/QR from the Owner (physical
   poster, WhatsApp share, or in later phases, finds the Branch via
   in-app discovery search).
2. Student signs up via phone OTP (creating their Firebase Auth sign-in if
   new, or logging into their existing one — this sign-in is shared across
   any Branch, but the Student *record* created at step 3 is owned solely
   by this Branch, per FR-4.4).
3. Student sees the Branch's available Plans and live seat availability,
   selects one, and (if self-service enrollment is enabled by that Branch)
   completes enrollment and pays online — or is directed to visit in person
   if the Branch requires in-person verification/ID capture.
4. Student lands on their personal dashboard: current Enrollment, next due
   date, attendance history, receipts.

**Decision points**: Some Branches (Owner-configurable) require staff to
complete the ID-verification step in person even if the Student initiated
signup online — the flow supports "Student pre-registers, staff confirms and
finalizes on arrival" as a valid path, not just fully self-service.

---

## 4.7 Student: Ongoing use **(MVP)**

1. Student opens app → sees days-until-due prominently, current seat/shift,
   and any Branch announcements.
2. Pays dues in-app when due (one tap to a pre-filled payment).
3. Views attendance calendar/streak.
4. (Later phase) Requests a shift change or seat change, subject to
   availability and Owner approval.

---

## 4.8 Owner: Multi-branch comparison **(Post-MVP, single-branch at MVP)**

1. Owner with 2+ Branches opens an Organization-level dashboard.
2. Sees side-by-side: occupancy, revenue, overdue totals per Branch.
3. Drills into any Branch for the full single-branch dashboard (§4.4).

---

## 4.9 Student: Discovery & comparison **(Phase 2, see roadmap)**

1. Student searches by city/area on the public discovery portal (web or
   in-app), no login required to browse.
2. Sees a list/map of Study Halls with live-ish availability, pricing,
   photos, and ratings.
3. Filters by shift type, AC/Non-AC, price range, distance.
4. Selects a Branch → sees detail page → either books a seat directly
   (where the Branch allows self-service enrollment) or requests a callback/
   visit.

---

## 4.10 Platform Admin: Support & subscription operations **(Post-MVP internal tooling; a minimal version may exist earlier as an ops necessity)**

1. Admin looks up an Organization by name/phone/ID (never browses raw
   Student data casually — access is action-scoped and logged, per §3.4).
2. Views Organization's Platform Subscription status, billing history,
   usage against plan limits.
3. Can extend a trial, apply a manual plan change, or suspend a Subscription
   for non-payment (which flips the Organization into a restricted-access
   state — read-only for the Owner, not data-destructive).
4. Every such action writes to the audit trail (FR-11.3) with the Admin's
   identity attached.
