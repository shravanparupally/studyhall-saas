# 08. System Architecture

## 8.1 Architectural goals

Directly serving the non-functional requirements in the
[PRD](02_Product_Requirements_Document.md) §2.6: multi-tenant isolation,
offline resilience, horizontal scalability to thousands of tenants, and
correctness-over-completeness in anything touching money or attendance.
Clean Architecture and SOLID are not process checkboxes here — they are how
we keep "Firestore" and "Flutter" from becoming load-bearing assumptions
baked into business logic, which is what would make the eventual scale-driven
changes (a reporting data warehouse, a second mobile platform, a payment
gateway swap) expensive instead of routine.

## 8.2 High-level system map

```
                         ┌────────────────────────┐
                         │   Public Discovery Web  │  (P2 — Next.js, SSR/SEO)
                         └────────────┬────────────┘
                                      │
┌──────────────────┐        ┌────────▼─────────┐        ┌──────────────────────┐
│  Owner/Staff App  │        │   Student App     │        │  Admin Web Console   │
│  (Flutter,        │        │  (Flutter,        │        │  (React/Next.js,     │
│   Android+iOS)    │        │   Android+iOS)     │        │   internal, desktop) │
└─────────┬─────────┘        └─────────┬─────────┘        └───────────┬──────────┘
          │                            │                              │
          └───────────────┬────────────┴───────────────┬──────────────┘
                           │                            │
                  ┌────────▼────────┐         ┌─────────▼─────────┐
                  │ Firebase Auth    │         │  Cloud Functions   │
                  │ (Phone OTP)      │         │  (application/use- │
                  └──────────────────┘         │  case layer, HTTPS │
                                                │  + Firestore       │
                                                │  triggers +        │
                                                │  scheduled jobs)   │
                                                └─────────┬──────────┘
                                                           │
                       ┌───────────────────────────────────┼───────────────────────────┐
                       │                                    │                           │
              ┌────────▼────────┐                 ┌─────────▼─────────┐       ┌─────────▼─────────┐
              │ Firestore        │                 │ Cloud Storage      │       │ External services  │
              │ (system of       │                 │ (ID docs, photos)  │       │ Razorpay (payments) │
              │ record, §07)     │                 └────────────────────┘       │ WhatsApp/SMS gateway │
              └──────────────────┘                                              │ FCM (push)           │
                                                                                  └───────────────────────┘
```

## 8.3 Client applications: why two Flutter apps, not one

Decision (resolving PRD §2.9 open question 1): **separate Owner/Staff app
and Student app**, sharing a common internal Flutter package for design
tokens, networking, and domain models — not a single app with role-based
views.

Reasoning: the two personas have fundamentally different usage shapes (see
[`03_User_Personas.md`](03_User_Personas.md)). The Owner/Staff app serves
both the Owner role (org-wide: every Branch) and the Receptionist role
(locked to their one assigned Branch) — the app's navigation is
role-aware from login (a Receptionist never even sees a Branch switcher;
an Owner does), but it is one codebase because both roles share the same
dense, operational usage shape described next. Receptionists/Staff need a
dense,
speed-optimized operational tool used all day at a fixed front-desk device.
Students need a light, consumer-grade app used briefly, a few times a week,
judged against Swiggy/PhonePe-grade UX expectations. Conflating them
produces a worse experience for both — either the Student app carries
operational clutter it doesn't need, or the Staff app gets watered down by
consumer-app pacing. Splitting them also lets each app's release cadence,
permission model, and store listing evolve independently, which matters
once we're supporting thousands of tenants' daily operations through the
Staff app specifically — that app's reliability bar is categorically higher.

Both apps consume the same backend (Cloud Functions + Firestore) and the
same domain layer package — the split is a presentation-layer decision, not
a backend one, which is exactly what Clean Architecture's separation is
supposed to make cheap.

## 8.4 Clean Architecture layering

Applied identically on both the Flutter clients and the Cloud Functions
backend — the layer boundaries are the same shape on both sides of the
network call, which is deliberate: it means "where does this logic live" has
one consistent answer across the whole codebase.

```
┌─────────────────────────────────────────────────────────┐
│ Presentation                                              │
│  Flutter: widgets, view-models/controllers                │
│  Backend: Cloud Function HTTPS/trigger handlers (thin)     │
├─────────────────────────────────────────────────────────┤
│ Application / Use Cases                                   │
│  "EnrollStudent", "RecordPayment", "CheckInStudent",       │
│  "ComputeOverdueFeeCycles" — one class per use case,        │
│  orchestrating domain entities + repository interfaces.    │
├─────────────────────────────────────────────────────────┤
│ Domain                                                     │
│  Entities (Organization, Enrollment, FeeCycle, ...),        │
│  value objects (Money, DateRange, PhoneNumber),             │
│  domain services (double-booking rule, overdue-grace-period │
│  rule) — pure, no Firebase/Flutter imports of any kind.     │
├─────────────────────────────────────────────────────────┤
│ Infrastructure / Adapters                                  │
│  FirestoreEnrollmentRepository implements EnrollmentRepository│
│  RazorpayPaymentGateway implements PaymentGateway            │
│  WhatsAppNotifier implements NotificationSender               │
└─────────────────────────────────────────────────────────┘
```

**Dependency rule**: arrows point inward only. Domain depends on nothing.
Application depends on Domain and on repository/gateway *interfaces* it
defines, never on their Firestore/Razorpay implementations. Infrastructure
depends inward (implements those interfaces) and is the only layer allowed
to import `cloud_firestore`, `razorpay_flutter`, or any other vendor SDK.

**Why this matters concretely for this product, not abstractly**: the
double-booking rule (§7.5), the fee-overdue grace-period rule (§10), and the
proration rule for mid-cycle plan changes are exactly the kind of logic that
tends to leak into UI code or Firestore trigger handlers under time
pressure. Keeping them as pure, independently testable Domain/Application
classes is what lets us unit-test "does the overdue rule handle a leap-year
billing cycle correctly" without spinning up an emulator, and what lets us
change the payment gateway later without touching a single business rule.

**Branch isolation is a repository-interface-level guarantee, not just a
Firestore rules-level one.** Every repository interface in the Application
layer that touches Branch-scoped data takes `organizationId` and
`branchId` as required, leading parameters — never optional filters bolted
on for convenience:

```
abstract class StudentRepository {
  Future<Student> getById(String organizationId, String branchId, String studentId);
  Future<List<Student>> listActive(String organizationId, String branchId);
}
```

The Firestore implementation of this interface builds its document path
directly from those two parameters
(`organizations/$organizationId/branches/$branchId/students`). There is
therefore no method signature anywhere in the Application layer that
*could* issue a cross-Branch query by accident — it's not a runtime check
someone has to remember to add, it's a compile-time shape every use case is
forced to satisfy. This matters specifically because
[`07_Firestore_Schema.md`](07_Firestore_Schema.md) §7.4 notes that
server-side Cloud Functions run with Admin-SDK privileges that bypass
Firestore security rules entirely — for that code path, this
repository-interface constraint plus the explicit `orgAccess` check in
§8.5 are the *only* enforcement of Branch isolation, so they are treated as
load-bearing, not a style preference.

## 8.5 Backend structure (Cloud Functions)

Organized by trigger type, each a thin Presentation-layer shim over shared
Application-layer use cases:

- **HTTPS callable functions**: client-invoked actions requiring
  server-side authority (e.g. `enrollStudent`, `recordPayment`,
  `checkInStudent`, `createOrganization`). Auth + permission check happens
  here before delegating to a use case.
- **Firestore triggers**: reactive consistency maintenance —
  `onPaymentCreated` recomputes the parent FeeCycle's `status`/`amountPaid`;
  `onOwnerWrite`/`onReceptionistWrite` re-issue that user's Auth custom
  claims (§7.4); `onEnrollmentWrite` updates the `dashboardStats` rollup
  (§7.6).
- **Scheduled functions** (Cloud Scheduler + Pub/Sub): `generateFeeCycles`
  (daily, creates upcoming FeeCycles per Enrollment billing cycle),
  `sendDueReminders` (daily, drives §4.5's reminder flow),
  `flagOverdueEnrollments` (daily, transitions Enrollment status).
- **Admin-only callable functions**: Platform Admin actions (subscription
  suspension, trial extension), authorized against the caller's own admin
  role (not an `orgAccess` claim) and always writing to `/auditLog`.

Every callable/trigger handler validates input, resolves the caller's
authority, invokes exactly one Application-layer use case, and maps the
result/error to a response — no business logic in the handler itself.

**"Resolves the caller's authority" is a mandatory, explicit step, not an
assumption.** Because Cloud Functions run with Admin SDK privileges that
bypass Firestore security rules (§7.4), every HTTPS callable handler
re-derives the caller's `orgAccess` claim from their auth token and
compares it against the `organizationId`/`branchId` the request targets
*before* invoking the use case — the same `canAccessBranch(orgId, branchId)`
check that the Firestore rules apply on the client side is applied again
here, explicitly, in code. This is deliberate duplication: the rules
engine protects direct client Firestore access, this check protects the
Cloud Functions surface, and neither is allowed to be "covered by the
other one anyway."

## 8.6 Concurrency & consistency

Covered in detail in [`07_Firestore_Schema.md`](07_Firestore_Schema.md) §7.5
(seat-shift lock documents) and §7.6 (denormalized dashboard rollups
maintained by triggers). The general principle: Firestore transactions are
used for anything with a correctness invariant (no double-booking, no
double-counted payment), and eventually-consistent trigger-maintained
rollups are used for anything that's "a fast approximate read is fine, and
self-heals within seconds" (dashboard tiles).

## 8.7 Offline resilience

The Flutter SDK's built-in Firestore offline persistence handles the common
case (client loses connectivity mid-session, keeps working off cached data,
syncs on reconnect) for read-heavy views (seat map, Student dashboard).
Write paths that have a correctness invariant (check-in, payment recording)
are explicitly queued client-side with a visible "pending sync" state rather
than silently relying on SDK offline writes for anything the seat-shift lock
mechanism needs to arbitrate — a check-in or Enrollment creation performed
offline is not treated as final until the transaction actually commits
server-side, and the UI reflects that honestly instead of assuming success
(directly serving NFR-3 and NFR-6 together: offline-tolerant, but never at
the cost of showing a number that isn't real yet).

## 8.8 Payments

Razorpay as the payment gateway partner (PRD §2.9 open question 2, resolved
here): India-first, strong UPI support, and offers **Razorpay Route** for
split settlements — relevant if we ever take a transaction fee rather than
pure Platform Subscription revenue. At MVP, integration is the simpler
direct model: Organization's own Razorpay sub-merchant account receives
Student payments directly; we are not in the money-movement path, which
keeps our compliance scope minimal (see Non-goals in the
[PRD](02_Product_Requirements_Document.md) §2.4). Payment confirmation
arrives via Razorpay webhook → Cloud Function → `recordPayment` use case,
never trusted from the client alone (a client could claim success
fraudulently; the webhook, signature-verified, is the source of truth for
online payments).

## 8.9 Communication infrastructure

- **Push**: Firebase Cloud Messaging, native fit with the Flutter/Firebase
  stack.
- **WhatsApp**: WhatsApp Business API via a BSP (Business Solution Provider
  — e.g. Gupshup or a similar India-focused provider), chosen once pricing
  is finalized (PRD §2.9 open question 3). This is the primary reach
  channel for Students without the app installed, given WhatsApp's
  near-universal penetration in the target demographic.
- **SMS**: fallback channel when WhatsApp delivery fails or opt-out applies.

## 8.10 Admin web console

A separate internal React/Next.js application (not Flutter — internal
tooling has different constraints: desktop-first, no app-store distribution
need, faster iteration for an internal-only surface). Talks to the same
Cloud Functions backend through admin-only callable functions, using Admin
SDK privileges server-side rather than client Firestore access, per the
security model in [`07_Firestore_Schema.md`](07_Firestore_Schema.md) §7.4.

## 8.11 Observability

- **Structured logging**: every Cloud Function logs with a consistent
  shape (organizationId, actorId, action, latency) to enable per-tenant
  debugging without grepping unstructured text.
- **Error tracking**: crash/exception reporting on both Flutter apps and
  Cloud Functions, alerting on error-rate spikes scoped by function/screen,
  not just globally.
- **Business metrics, not just system metrics**: dashboards tracking the
  product metrics in PRD §2.8 (activation, fee-collection lift, retention)
  are treated as a first-class observability concern, not an afterthought
  — because "the system is up" and "the product is working for Owners" are
  different questions, and only the second one is what we're actually
  optimizing for.

## 8.12 Deployment & environments

Three environments (`dev`, `staging`, `production`) as separate Firebase
projects — never separate "modes" within one project, since Firestore
security rules and data must be genuinely isolated to make staging a safe
place to test destructive changes. CI runs the Firestore emulator suite for
security-rule tests and use-case unit tests on every change; nothing
touching `payments`, `feeCycles`, or `auditLog` rule logic merges without an
emulator-backed test proving the isolation/append-only guarantees in
§07 actually hold.

## 8.13 Scaling posture

Firestore scales horizontally by design (no single-writer bottleneck at the
collection level once hot-document write patterns are avoided — which is
exactly why §7.6's dashboard rollups are per-Branch documents, not one
global counter). Cloud Functions scale by concurrency automatically. The
architectural limits worth naming now, before they're surprises later:

- Firestore's ~1 write/second sustained limit *per document* — this is why
  `dashboardStats` is one document per Branch (bounded write rate: one
  Branch's check-in/payment volume) rather than one document per
  Organization or, worse, a single platform-wide stats document.
- Any future cross-tenant analytics (e.g. "average occupancy across all
  Organizations in Kota") is explicitly **not** something we compute by
  querying Firestore directly at scale — it's a reason a BigQuery export
  pipeline (Firestore → BigQuery extension, standard pattern) enters the
  roadmap once that reporting need is real (see
  [`13_Product_Roadmap.md`](13_Product_Roadmap.md)), rather than something
  we try to force out of the operational database.

## 8.14 SOLID in practice, concretely

- **Single Responsibility**: one class per use case (`RecordPaymentUseCase`
  does one thing); repository implementations only translate between domain
  entities and Firestore documents, nothing else.
- **Open/Closed**: adding a new notification channel (e.g. future email)
  means implementing `NotificationSender`, not modifying every use case that
  sends notifications.
- **Liskov Substitution**: any `PaymentGateway` implementation (Razorpay
  today, a different provider later) must be swappable behind the interface
  without use-case code changes — enforced by the use cases being tested
  against a fake/in-memory implementation of the interface, not a live
  Razorpay sandbox.
- **Interface Segregation**: `EnrollmentRepository` and `FeeCycleRepository`
  are separate interfaces even though both live in Firestore — a use case
  that only needs to read Enrollments never depends on FeeCycle methods it
  doesn't use.
- **Dependency Inversion**: Application-layer use cases depend on
  repository/gateway interfaces they own; Infrastructure implements those
  interfaces. The direction of the `import` statement always points from
  infrastructure to application, never the reverse.
