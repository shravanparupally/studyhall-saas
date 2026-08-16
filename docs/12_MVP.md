# 12. MVP

## 12.1 MVP thesis

The MVP proves one thing: **a single-branch Study Hall Owner will trust this
system to run their seats, fees, and attendance instead of Excel/WhatsApp/
notebook, and that trust measurably reduces their fee-collection pain.**
Everything in scope serves that thesis directly. Everything deferred is
deferred because it either doesn't serve it, or depends on having proven it
first (discovery, multi-branch scale, franchise tooling).

This is deliberately narrower than the full vision in
[`01_Product_Vision.md`](01_Product_Vision.md) and the full requirement set
in the [PRD](02_Product_Requirements_Document.md) — see
[`13_Product_Roadmap.md`](13_Product_Roadmap.md) for how the rest gets
built up in phases after MVP validates the core.

## 12.2 Target user for MVP

The **Owner** persona (§3.1) running **one Branch**, with **one Staff
member (a Receptionist)** helping at most. Multi-branch Owners can sign up
and use MVP fully — Branch isolation is architecturally present from day
one (see [`06_Database_Design.md`](06_Database_Design.md) §6.6), so each
Branch works completely and the Owner can read every Branch they operate.
What's out of scope at MVP is purely a presentation-layer convenience: a
single combined Organization-level rollup screen. An MVP multi-branch
Owner switches between Branches to view each one's full dashboard, rather
than seeing all Branches side-by-side in one view.

## 12.3 In scope

Every item below is tagged **MVP** in [`05_Feature_List.md`](05_Feature_List.md);
restated here as a single coherent scope statement, organized by the
flows it enables end-to-end (per [`04_User_Flows.md`](04_User_Flows.md)):

**Setup**
- Organization signup (phone OTP), first Branch creation, Shift definition,
  bulk/individual Seat creation, Membership Plan definition.

**Daily operations**
- Visual seat map with real-time per-shift occupancy.
- Staff-assisted walk-in enrollment (identity capture, plan/seat selection,
  double-booking prevention).
- QR-based check-in (staff-scanned).
- Cash and online (Razorpay/UPI) payment recording, with immediate
  Enrollment status reflection.
- Digital receipts.

**Fee management**
- Auto-generated fee schedules per Enrollment.
- Overdue/at-risk status tracking with Branch-configurable check-in policy
  (BR-16).
- Automated due-date reminders (WhatsApp primary, SMS fallback, push if app
  installed).
- Bulk reminder broadcast to overdue Students.

**Owner visibility**
- Single-Branch dashboard: occupancy %, revenue, outstanding dues, overdue
  list.
- CSV export of core reports.

**Staff & access**
- Staff invite with the two default roles (Owner, Receptionist),
  Branch-scoped permissions, server-side enforcement.
- Staff activity log.

**Student experience**
- Student dashboard: current Enrollment, dues, next due date, attendance
  history, receipts.
- In-app payment.
- Digital membership card/QR for check-in.
- Student self-registration is **pre-registration only** at MVP — a
  Student can start the process online, but enrollment finalizes with
  Staff in person (full self-service enrollment is P1, per §5.4); this
  keeps ID-verification quality high while the Owner is still building
  trust in the system.

**Platform**
- Platform Subscription tiers with trial, self-serve upgrade/downgrade,
  usage-limit enforcement (BR-26).
- Append-only audit trail for financial events.
- A minimal internal Platform Admin console: enough to look up an
  Organization, view its Subscription status, and handle support/billing
  issues manually — not the full tooling suite (§4.10 is P1 for its fuller
  form).
- Multi-tenant data isolation, offline-tolerant seat map/check-in sync —
  these are architectural defaults present from the first commit, not
  MVP-scoped features to be added later (see
  [`08_System_Architecture.md`](08_System_Architecture.md)).

## 12.4 Explicitly out of scope for MVP

Stated explicitly so scope creep has something concrete to be checked
against:

- The **combined, single-screen** Organization-level multi-branch rollup
  dashboard, and Branch cloning. (Owner access to each individual Branch's
  full dashboard is in scope and architecturally unconditional — see
  §12.2 — this exclusion is specifically about the aggregated
  side-by-side comparison view.)
- Public discovery portal, ratings/reviews, map-based search — the entire
  Phase 2 demand side. MVP Students arrive via a Branch-specific link/QR
  the Owner shares directly, not via in-app search.
- Fully self-service Student enrollment (no Staff step).
- Waitlist management.
- Locker management as a distinct tracked entity (a Branch can still
  informally manage lockers off-platform at MVP).
- Coupons/discount codes, referral programs.
- Partial payments/installments — MVP fee cycles are paid in full or not
  at all; installment support is P1.
- Mid-cycle plan proration (BR-8 is specified for when this ships, not
  built now).
- Expense tracking / P&L view.
- Custom roles beyond the three defaults.
- Biometric/geofenced attendance.
- Multi-language UI (English-first at MVP; the string-resource structure
  supports it per NFR-8, but translated content isn't produced yet).
- API access, white-labeling.

## 12.5 MVP success criteria

Directly derived from the metrics in the [PRD](02_Product_Requirements_Document.md)
§2.8, made concrete enough to actually evaluate at the end of the MVP
period:

1. A cohort of pilot Owners (target: a handful of Branches in one launch
   city, small enough for hands-on onboarding support) completes full setup
   (Branch + Seats + Plans + first real Student Enrollment) within 7 days
   of signup, unassisted after initial onboarding.
2. Pilot Owners report (qualitatively, via direct check-in — we are not
   waiting for a large enough sample for statistical confidence at this
   stage) that they trust the dues/revenue numbers enough to stop
   cross-checking against their old notebook/Excel within the first month.
3. Measurable reduction in average days-fee-overdue for pilot Branches,
   comparing their self-reported pre-adoption baseline to their in-product
   numbers after 60 days.
4. Zero cross-tenant data isolation incidents (NFR-1) — this is a
   go/no-go gate for continuing to onboard beyond the pilot cohort, not
   just a metric to track.
5. Core check-in/payment-recording flow completes reliably under real
   Branch network conditions (NFR-3), validated by pilot Staff actually
   using it during a live check-in rush, not just in a controlled demo.

## 12.6 Why this scope, not a smaller or larger one

**Why not smaller** (e.g. cut online payments, ship cash-only): fee
collection reliability is the core value proposition (§12.1). A version
that can't take an online payment or send an automated reminder isn't
meaningfully better than the Owner's existing WhatsApp-and-cash process —
it would fail to prove the thesis at all.

**Why not larger** (e.g. include discovery, or full self-service
enrollment): those features assume the operational core already works and
is trusted — building discovery before Owners trust the seat/fee data would
mean building a marketplace on top of data nobody believes yet, which per
[`01_Product_Vision.md`](01_Product_Vision.md) §1.6 is explicitly the
mistake we're avoiding. Full self-service enrollment removes the Staff
identity-verification step before we've validated that Owners are
comfortable with that trust transfer at all.
