# 09. UI/UX Guidelines

Design principles for both Flutter apps and the discovery web surface.
Visual assets (design tokens, Figma exports, icon sets) belong in
`design/app/`, `design/backend/` (architecture/infra diagrams), and
`design/assets/` (shared brand assets) — this document defines the
principles those assets must follow, not the assets themselves.

## 9.1 Two apps, two design postures — same underlying system

Per [`08_System_Architecture.md`](08_System_Architecture.md) §8.3, the
Owner/Staff app and Student app are separate applications with different UX
postures, but they must share one design token system (color, type scale,
spacing, iconography) so the brand reads as one coherent product and so
`design/assets/` stays a single source of truth rather than forking.

| | Owner/Staff app | Student app |
|---|---|---|
| Posture | Operational tool | Consumer app |
| Primary context | Front desk, all-day use, often mid-queue | Personal phone, brief sessions |
| Density | Higher — more data per screen is acceptable | Lower — generous whitespace, one clear action per screen |
| Speed bar | Core actions (check-in, record payment) ≤ 2-3 taps, sub-10-second completion | Standard consumer-app responsiveness |
| Tone | Efficient, neutral, business-like | Warm, encouraging (attendance streaks, "you're on track") |

## 9.2 Design principles

1. **The seat map is the product's visual signature.** For the Owner/Staff
   app, the seat map (per [`04_User_Flows.md`](04_User_Flows.md) §4.2-4.4)
   is the single most-viewed screen. It must communicate occupancy status
   at a glance via color/shape alone, readable in under a second, before any
   text label is read.
2. **Never show a number the system isn't sure about.** Per NFR-6 (PRD
   §2.6), if a value is stale, syncing, or pending confirmation (e.g. an
   offline-queued check-in, per [`08_System_Architecture.md`](08_System_Architecture.md)
   §8.7), the UI must visibly say so — a spinner-then-silently-correct
   pattern is not acceptable when the number is money or attendance. Use
   explicit "syncing..." / "pending" states, not optimistic UI that could
   mislead an Owner about revenue or a Student about their dues.
3. **Every core Staff action survives interruption.** Front-desk work is
   constantly interrupted (a phone call, a walk-in question mid-flow).
   Multi-step flows (enrollment, per §4.2) must be resumable, not force a
   restart from step one.
4. **Design for the thumb, not the cursor.** Both apps are phone-first (see
   [`03_User_Personas.md`](03_User_Personas.md) — every persona's primary
   device is a phone or shared tablet). Tap targets are generously sized;
   nothing depends on hover states or fine pointer precision.
5. **Empty states are onboarding, not dead ends.** A new Owner's first
   seat-map view, a new Student's first dashboard — every empty state
   names the next concrete action ("Add your first seat," not a blank
   screen with no call to action).
6. **Errors explain the fix, not just the failure.** "This seat was just
   taken — choose another" (§4.2's race-condition case), not "Error 409."
   Every error message in the Owner/Staff app is written for a
   non-technical operator (per the Owner/Staff persona's low tolerance for
   jargon, §3.1-3.2).

## 9.3 Accessibility & literacy

- Target users include operators and students for whom English is a second
  language and reading-dense UI is friction, not neutral. Icons + color
  carry meaning redundantly with text, never as the sole signal (also
  serves colorblind accessibility).
- Minimum tap target size follows platform accessibility guidelines
  (Material's 48dp minimum) without exception in the Owner/Staff app, where
  speed-under-pressure use is the norm.
- Text sizing respects system-level font-scaling settings on both platforms
  — do not lock text size, since some Owner users are older and may run
  larger system font sizes.
- Color contrast meets WCAG AA at minimum across both apps; the
  occupancy-status seat map (principle 1) especially cannot rely on
  low-contrast color coding.

## 9.4 Localization

- UI strings are never hardcoded inline in widget code (serves NFR-8, PRD
  §2.6) — even though MVP ships English (with Hindi-mixed terminology where
  that's the natural term, e.g. "Seat," "Shift" are used as-is even in
  Hindi UX research, matching how operators actually speak) — the
  string-resource structure supports adding full Hindi and other regional
  languages without refactoring.
- Currency, date, and time formatting is locale-aware from day one
  (₹ symbol, DD/MM/YYYY, 12-hour time with AM/PM — matching Indian
  conventions), not US-default formatting patched later.
- Names and addresses must not assume a Western name/address structure —
  no forced "first name / last name" split where a single "full name"
  field is more natural to how Owners actually register students.

## 9.5 Notifications & communication tone

- Fee reminders (§4.5) are firm but respectful — this is a small business's
  livelihood being protected, but an aggressive/shaming tone toward
  Students damages both the Student experience and, downstream, the
  Owner's own reputation with their customers. Copy is reviewed for tone,
  not just correctness.
- WhatsApp/SMS messages always identify the sending Branch by name (not
  just "StudyHall OS") — the Student's relationship is with their Study
  Hall, not with us; the platform brand is secondary in Student-facing
  communication at MVP (this may evolve once discovery/Phase 2 makes our
  own brand relevant to Students directly).

## 9.6 Visual identity status

Brand identity (logo, color palette, typography) is **not yet finalized** —
this is a deliberate gap, not an oversight, since branding decisions belong
after product-market validation of the core workflows, not before. Until
then, any interim visual work in `design/assets/` should use a clearly
placeholder-marked palette so early UI work isn't mistaken for final brand
direction.

## 9.7 What belongs in `design/` vs this document

This document is principles and constraints, reviewed and versioned like
any other doc in `docs/`. Actual design artifacts — Figma files/exports,
component specs, icon sets, architecture/infra diagrams — belong in the
`design/` tree (`app/`, `backend/`, `assets/`) and are expected to change
far more frequently than this document as the product is designed
screen-by-screen against the flows in
[`04_User_Flows.md`](04_User_Flows.md).
