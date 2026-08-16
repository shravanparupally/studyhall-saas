# 15. Technical Architecture

**This document is the single source of truth for implementation.** Where
[`08_System_Architecture.md`](08_System_Architecture.md) established *why*
the system is shaped the way it is (Clean Architecture, Firebase, two
Flutter apps) and [`14_Domain_Model.md`](14_Domain_Model.md) established
*what* the business logic is, this document pins down exactly *how* we
build it: specific technologies, specific versions, specific conventions.
Every decision below states why we picked it, what we considered and
rejected, and — critically — what "doing it right" and "doing it wrong"
look like in this codebase specifically. This is not generic Flutter/
Firebase advice; every "Project Standard" is a decision this team is
bound by until a future revision of this document changes it.

No Flutter or Dart code is generated here, consistent with the planning
phase — this document specifies conventions precisely enough that
implementation is a mechanical translation, not a design exercise.

## 15.0 Stack overview & language boundaries

Stated once, up front, because several sections below (Cloud Functions,
Repository Pattern, Code Generation) only make sense with this boundary
clear:

| Surface | Language / Framework | Why |
|---|---|---|
| Owner/Staff app, Student app | **Dart** (Flutter) | §15.1/15.2 |
| Cloud Functions (backend) | **TypeScript** (Node.js, Firebase Functions v2) | §15.8 |
| Admin web console | **TypeScript** (React/Next.js) — per [`08_System_Architecture.md`](08_System_Architecture.md) §8.10 | Consistency with Cloud Functions; internal tool, not a mobile client |
| Firestore Security Rules | Firestore Rules language | §15.7 |

This is a deliberately polyglot stack: Dart is exclusive to the two
Flutter clients; everything server-side is TypeScript. We do **not** use
Dart Cloud Functions (`functions_framework`) despite the language-consistency
appeal — see §15.8 for why.

---

## 1. Flutter Version

**Why we selected it**: Flutter is the client framework for both apps per
[`08_System_Architecture.md`](08_System_Architecture.md) §8.3 — one
codebase per app, compiled natively to Android and iOS, with first-party,
actively maintained Firebase SDKs (`firebase_core`, `cloud_firestore`,
`firebase_auth`, etc.) that include built-in offline persistence, which is
load-bearing for NFR-3. Flutter's widget-rebuild model also fits this
product's dominant UI pattern — dense, real-time, list/grid-heavy screens
(the seat map, the dues list) — very well.

**Alternatives considered**:
- **React Native**: mature, large ecosystem, but weaker first-party
  Firestore offline-persistence story historically and a JS bridge
  performance profile less suited to the seat-map's real-time-heavy
  rendering. Team would also need to maintain both a Dart-adjacent
  (Cloud Functions/TypeScript) and a JS mental model with less code
  sharing than Flutter's single-language client story.
- **Native (separate Android/iOS codebases)**: best possible per-platform
  performance and polish, but doubles engineering effort for a small team
  building two apps already (Owner/Staff + Student) — not justified at
  this stage.
- **Kotlin Multiplatform**: promising but immature UI story (Compose
  Multiplatform for iOS is newer/less battle-tested than Flutter) and a
  much smaller Firebase-ecosystem track record; revisit only if Flutter
  becomes a genuine bottleneck, which is not expected.

**Best practices**:
- Track the **stable** channel only, never `beta`/`dev`/`master` in any
  build that ships to a real Owner or Student.
- Pin the exact version project-wide via **FVM** (Flutter Version
  Management) — every developer machine and every CI runner resolves the
  same Flutter version from a committed config, never "whatever's on my
  machine."
- Upgrade deliberately: a dedicated branch, full regression pass (§15.23),
  and a changelog review of breaking changes before merging a version
  bump — never as a side effect of an unrelated feature branch.

**Common mistakes**: developers on different Flutter versions producing
"works on my machine" bugs; upgrading mid-sprint without a regression
pass; ignoring deprecation warnings until a forced upgrade makes them
compile errors all at once; using `beta`/`master` channel because "it has
the feature I want" in a production app.

**Project standards**: Flutter version is pinned via a committed FVM
config at the repository root; CI installs the exact pinned version;
current target is the latest stable release as of implementation kickoff
(verify against `flutter --version` / flutter.dev at that time — this
document intentionally does not hardcode a specific patch number that
will be stale within a quarter). Version bumps happen on their own
reviewed PR, gated by the full test suite (§15.23), roughly once per
quarter — not on every new stable release, and not left to drift for a
year either.

---

## 2. Dart Version

**Why we selected it**: Dart ships bundled with Flutter, so this isn't an
independent choice — but it's worth stating why Dart itself is a good fit,
not just an unavoidable consequence: sound null safety, a real static type
system (important for a Clean Architecture codebase with many typed
domain interfaces per [`14_Domain_Model.md`](14_Domain_Model.md)), Dart 3's
pattern matching and sealed classes (a near-perfect fit for the
`EnrollmentStatus`-style closed enums and the `Result`/`Failure` hierarchy
in §15.17), and first-class `async`/`await`, which the entire Firestore
streaming/offline model depends on.

**Alternatives considered**: N/A as a language choice for the Flutter
clients — Dart is Flutter's language. The real decision this section
guards against is *scope creep of Dart outside the clients* — i.e. using
Dart for Cloud Functions "for consistency." Explicitly rejected; see
§15.8.

**Best practices**: enable and keep all sound-null-safety and strict-mode
analyzer options on (§15.22); use Dart 3 pattern matching for exhaustive
handling of domain enums/sealed unions rather than `if`/`else` chains,
which the compiler cannot verify are exhaustive.

**Common mistakes**: using `dynamic` to route around the type system
instead of modeling the actual union/nullable type; catching this late
because a chain of `if`/`else` on an enum silently does nothing on an
unhandled case instead of failing to compile.

**Project standards**: Dart SDK version is whatever ships with the pinned
Flutter version (§15.1) — never pinned independently, to avoid an
impossible-to-satisfy mismatch. Sealed classes / exhaustive `switch`
required for every domain status enum and every `Result`/`Failure` type
(§15.17) — a non-exhaustive `switch` on one of these is a lint failure
(§15.22), not a style suggestion.

---

## 3. Firebase Services

**Why we selected it**: established in
[`08_System_Architecture.md`](08_System_Architecture.md) §8.2 and
[`06_Database_Design.md`](06_Database_Design.md) §6.8 — real-time
listeners, generous small-tenant pricing, mature Flutter SDKs with
built-in offline persistence, and no infrastructure to operate at our team
size. This section is the concrete list of which Firebase products are
approved for use and why each earns its place.

| Service | Used for |
|---|---|
| Authentication | Phone OTP sign-in for Owners, Receptionists, Students (§15.6) |
| Firestore | System of record (§15.7, and [`07_Firestore_Schema.md`](07_Firestore_Schema.md)) |
| Cloud Functions (v2) | Application-layer use cases, triggers, scheduled jobs (§15.8) |
| Cloud Storage | ID documents, photos (§15.9) |
| Cloud Messaging (FCM) | Push notifications (§15.10) |
| Crashlytics | Crash/error reporting (§15.11) |
| Analytics | Product/funnel metrics (§15.12) |
| Remote Config | App-wide feature flags & tunables (§15.13) |
| App Check | Abuse/bot prevention (§15.26) |
| Cloud Scheduler + Pub/Sub | Backing infrastructure for scheduled Functions (BR-9's FeeCycle generation, reminders) |

**Alternatives considered**: Supabase (attractive Postgres-based
alternative with real-time subscriptions, but a smaller managed-service
maturity track record at our reliability bar and a less battle-tested
Flutter SDK); AWS Amplify (viable but pulls in a heavier, more
general-purpose cloud surface than this product needs, and a weaker
offline-persistence story for Flutter specifically); a fully custom
Node.js + PostgreSQL backend (maximum control, but requires us to build
and operate auth, real-time sync, and offline support ourselves — direct
opposition to "no infrastructure to operate at our team size," and a
worse fit for NFR-3's offline requirement out of the box).

**Best practices**: three separate Firebase projects (dev/staging/
production, per [`08_System_Architecture.md`](08_System_Architecture.md)
§8.12); the Firebase **emulator suite** for all local development and CI
— no developer or CI job ever runs tests against a real Firebase project;
budget alerts configured on every project from day one; least-privilege
IAM for every service account, never the default broad `Editor` role.

**Common mistakes**: developing or testing against the production
project "just this once"; skipping budget alerts and discovering a cost
spike (e.g. a runaway Cloud Function loop) only when the bill arrives;
treating Firebase security rules as the *only* security layer instead of
one of two (§15.26); adding a new Firebase product to the stack without
recording the decision here first.

**Project standards**: the table above is the exhaustive approved-service
list; adding a new Firebase product to the stack requires updating this
document, not just shipping it. Every environment has budget alerts
configured before it accepts any real traffic. Local development and CI
both target the emulator suite exclusively.

---

## 4. Riverpod Strategy

**Why we selected it**: Riverpod is both the state-management **and**
dependency-injection mechanism for the Flutter clients (see §15.16 — we
deliberately do not run a second DI framework alongside it). It is
compile-safe (no runtime "provider not found" class of bugs that
`Provider`'s `BuildContext`-based lookup allows), testable without a
widget tree, and its `ref`-based composition is a natural fit for Clean
Architecture's dependency-inversion boundary (Notifiers depend on
repository *interfaces*, and the concrete Firestore implementation is
supplied only at the composition root — see §15.4/§15.16).

**Alternatives considered**:
- **Provider** (Riverpod's predecessor): still `BuildContext`-coupled,
  runtime-only provider resolution, no compile-time safety — the exact
  problem Riverpod was built to fix.
- **Bloc/Cubit**: a legitimate, well-structured alternative with strong
  discipline around events/states; rejected mainly for ceremony —
  Bloc's separate Event classes for every action add boilerplate this
  project doesn't get proportional value from, especially given
  Riverpod's `AsyncNotifier` already gives us a disciplined
  loading/data/error state shape (see §15.17's synergy with `Result`
  types) without a parallel Event-class hierarchy.
- **GetX**: rejected outright — its magic dependency lookup and
  all-in-one (state + routing + DI) design actively works against Clean
  Architecture's explicit boundaries, and its testing story is weak
  compared to Riverpod's `ProviderContainer` overrides.
- **`setState`/`InheritedWidget` only**: fine for the most local, purely
  visual state (§15.29's Tier 1); does not scale as a whole-app strategy.

**Best practices**: use **code generation** (`@riverpod` annotations via
`riverpod_generator`, §15.30) rather than hand-written providers — less
boilerplate, more consistent shape across the codebase. Keep each
Notifier scoped to one use case or one feature slice — a Notifier that
spans multiple unrelated concerns is a sign a feature boundary is wrong,
not that Riverpod is failing. Use `autoDispose` by default for
screen-scoped providers so state doesn't leak past the screens that need
it (relevant for a front-desk device running for a full shift). Use
`family` for anything parameterized by an ID (a Branch's Enrollment list
provider is naturally `family<List<Enrollment>, BranchId>`, matching the
Branch-scoping requirement from FR-1.4 directly in the state layer). Use
`ref.watch(provider.select(...))` when a widget only needs one field of a
larger state object, to avoid rebuilding on unrelated changes.

**Common mistakes**: watching an entire large state object in a widget's
`build` method when only one field is used, causing unnecessary rebuilds
(use `.select`); putting business logic directly inside a widget instead
of a Notifier (violates the Presentation/Application boundary from
[`08_System_Architecture.md`](08_System_Architecture.md) §8.4); forgetting
`autoDispose` on screen-scoped state, leaking memory over a long
front-desk session; mixing `setState` and Riverpod inconsistently within
the same feature.

**Project standards**: one `AsyncNotifier` per use case wherever the use
case is asynchronous (nearly always, given this is a Firestore-backed
app); naming convention `XyzNotifier`/`xyzProvider` (§15.21); every
Notifier's public behavior is unit-tested via `ProviderContainer` with
fake repository implementations injected (§15.15/§15.23) — no Notifier
ships without a test exercising its state transitions, including its
error path.

---

## 5. Go Router Navigation

**Why we selected it**: `go_router` is the Flutter team's own official
declarative routing package. It supports deep linking natively — required
because a Student's first interaction with the app is very often a
Branch-specific join link/QR code, per
[`04_User_Flows.md`](04_User_Flows.md) §4.6 — and supports the redirect-based
auth/role guarding this system needs (an unauthenticated user or a
Receptionist attempting to reach a route outside their assigned Branch
must be redirected, not merely hidden behind a disabled button).

**Alternatives considered**:
- **Navigator 1.0 (imperative push/pop)**: poor deep-link support, and
  reasoning about the full route graph becomes difficult as screen count
  grows — a real cost for two separate apps with meaningfully different
  navigation shapes (§Persona differences in
  [`08_System_Architecture.md`](08_System_Architecture.md) §8.3).
- **`auto_route`**: a strong, code-gen-based alternative with a similar
  declarative model. `go_router` was chosen for being first-party
  (long-term maintenance confidence) and because our navigation
  structure — a handful of shells (Owner/Receptionist bottom-nav, Student
  bottom-nav) each with nested feature routes — doesn't need
  `auto_route`'s heavier code-gen machinery to stay manageable.
- **Beamer**: smaller community, less first-party confidence than
  `go_router`; not chosen.

**Best practices**: one centralized route configuration per app (not
scattered `Navigator.push` calls); `ShellRoute` for the persistent
bottom-navigation shell in each app; `redirect` callbacks for auth and
role guards — resolved from the same `orgAccess`-shaped session state
used everywhere else (§15.6), never a parallel, separately-maintained
permission check; typed route parameters instead of stringly-typed query
params for anything that identifies a domain entity (a `BranchId`, an
`EnrollmentId`).

**Common mistakes**: scattering imperative navigation calls throughout
feature code instead of routing through the central config, which makes
the app's navigable surface impossible to audit; treating a `redirect`
guard as sufficient security — **it is a UX convenience only**; the real
enforcement is the security rules and Cloud Function authority checks in
[`07_Firestore_Schema.md`](07_Firestore_Schema.md) §7.4 and
[`08_System_Architecture.md`](08_System_Architecture.md) §8.5, and a
`go_router` guard bypass must never be treated as a data-access breach on
its own, but also must never be relied upon as the *only* guard; not
handling a cold-start deep link (app not yet running) distinctly from a
warm deep link (app already open) — both must resolve to the same
destination reliably.

**Project standards**: one router config file per app; every route that
touches Branch-scoped data resolves its `branchId` guard from the same
session-context provider described in §15.29's Tier 3; a dedicated,
consistently-styled "not authorized" / "not found" route for both guard
failures and bad deep links (never a blank screen or a crash).

---

## 6. Firebase Auth

**Why we selected it**: phone-number OTP as the **primary and only**
sign-in method for every human role (Owner, Receptionist, Student),
matching the phone-first identity decision already made in
[`02_Product_Requirements_Document.md`](02_Product_Requirements_Document.md)
§2.7 — no password to forget, no email required, and it matches how this
demographic already expects to authenticate with consumer apps (UPI,
WhatsApp).

**Alternatives considered**: email/password (rejected as primary —
password fatigue and email is a secondary, often-unchecked channel for
this demographic per the Persona research in
[`03_User_Personas.md`](03_User_Personas.md)); Google/Apple Sign-In
(plausible *secondary* option later, not primary — deferred, not
rejected outright, since it adds no value for a Receptionist on a shared
front-desk device and only marginal value for Students who are already
comfortable with OTP); a fully custom auth backend (rejected — no reason
to rebuild what Firebase Auth already provides reliably, and it would
forfeit the direct integration with custom claims that §07's
authorization model depends on).

**Best practices**: **Firebase App Check** (§15.26) is enabled on the Auth
API specifically to blunt OTP-toll-fraud/abuse (a real, well-known attack
against phone-auth-based apps — attackers trigger OTP sends to run up SMS
costs); rate-limit OTP send attempts per phone number and per device; test
against the Auth emulator with designated test phone numbers in every
environment except production; force a token refresh immediately after a
custom-claims-affecting write (an Owner/Receptionist grant change, per
[`07_Firestore_Schema.md`](07_Firestore_Schema.md) §7.4) rather than
waiting for the SDK's natural refresh interval, since a stale claim
here directly means stale Branch-access — a real isolation concern, not
just a UX one.

**Common mistakes**: forgetting the forced-claims-refresh step after a
grant change, leaving a revoked Receptionist with working (cached) access
for up to an hour; not handling Android's SMS auto-retrieval permission
gracefully when denied; logging phone numbers in plaintext anywhere in
client logs or Crashlytics custom keys (§15.11/§15.18 — this is a PII
rule stated once and enforced everywhere); no OTP resend cooldown UX,
inviting SMS-cost abuse via rapid resend taps.

**Project standards**: OTP resend cooldown of no less than 30 seconds
client-side, backed by the same limit server-side (client-side alone is
not enforcement, per the general security posture in §15.26); every
custom-claims-affecting write triggers an explicit client-side forced
token refresh on the affected session where technically reachable (push
notification / next app-foreground check as a fallback for the case
where the affected device isn't currently online); sign-out clears all
locally cached Firestore data for the signed-out user, never left behind
for the next person to use a shared front-desk device.

---

## 7. Firestore

The data model itself is fully specified in
[`06_Database_Design.md`](06_Database_Design.md) and
[`07_Firestore_Schema.md`](07_Firestore_Schema.md) — this section covers
*implementation* discipline: how the app is allowed to talk to Firestore
day to day.

**Why we selected it**: recapped from
[`06_Database_Design.md`](06_Database_Design.md) §6.8 — real-time
listeners for the seat map and dashboards, mature offline persistence,
and a cost/operational model that fits thousands of small tenants.

**Alternatives considered**: recapped from the same section — a
relational database (Postgres) with a custom real-time layer bolted on,
or Supabase/MongoDB Atlas as managed alternatives; all rejected primarily
for the amount of infrastructure we'd have to build and operate ourselves
to match what Firestore + the Flutter SDK give natively, at a team size
where that's not a good trade.

**Best practices**: real-time UI (the seat map, live dashboard tiles) uses
Firestore **streams**, never one-shot polling; large lists (the overdue
roster, the full Student list) are **paginated with query cursors**, never
`offset`-based pagination and never a full unbounded fetch; the
Seat-Availability lock-document transaction pattern
([`07_Firestore_Schema.md`](07_Firestore_Schema.md) §7.5) is used for
*every* write with a cross-aggregate invariant to protect, not just
Enrollment creation — the pattern generalizes, and new features that
introduce a similar invariant should reach for it rather than inventing a
new concurrency strategy.

**Common mistakes**: a stream subscription left open past a widget's
`dispose()`, silently consuming reads/battery for the life of the app
session; fetching an entire collection client-side and filtering in Dart
instead of writing the right Firestore query (defeats indexing, doesn't
scale, and directly costs money at thousands-of-tenants volume); treating
Firestore security rules as validation — **rules are access control, not
data validation**; malformed-but-authorized writes must still be rejected
by application-layer validation (§15.17) before they ever reach
Firestore; performing a read-then-write sequence outside a transaction
when the write's correctness depends on the read (a direct re-introduction
of the double-booking race BR-1 exists to prevent, just in a different
feature).

**Project standards**: **no widget or Notifier ever imports
`cloud_firestore` directly** — all Firestore access is behind a
repository interface (§15.15); every repository implementation is
responsible for converting between domain Entities/VOs and Firestore
document shapes, and that conversion code is the *only* place
`Timestamp`, `DocumentSnapshot`, or similar Firestore-specific types are
allowed to appear; every list-rendering screen backed by Firestore is
paginated from the first implementation, not retrofitted after a
performance complaint.

---

## 8. Cloud Functions

**Why we selected it (and TypeScript specifically)**: Cloud Functions is
the Application-layer execution environment per
[`08_System_Architecture.md`](08_System_Architecture.md) §8.5 — HTTPS
callables, Firestore triggers, and scheduled jobs. **TypeScript on
Node.js**, specifically Firebase Functions **v2** (Cloud-Run-based, not
the legacy v1 runtime), is the implementation language: it has the most
mature Firebase Admin SDK support, the largest ecosystem of examples and
first-party documentation, and the strongest hiring/onboarding pool for a
startup that needs to grow its engineering team.

**Alternatives considered**:
- **Dart Cloud Functions** (`functions_framework`): appealing purely for
  language consistency with the Flutter clients, but meaningfully less
  mature — smaller community, fewer production examples, and a real risk
  of hitting rough edges in exactly the areas (webhook handling,
  background triggers) that matter most for a financial system. Rejected
  for a production system at this trust bar; language consistency is not
  worth the maturity gap.
- **Python Cloud Functions**: viable in the abstract, but less idiomatic
  for Firebase-heavy trigger/event work specifically, and would add a
  third language to the stack (alongside Dart and TypeScript) for no
  offsetting benefit.
- **A standalone Node/Express server on Cloud Run**: considered for
  cold-start and long-running-connection control; deferred rather than
  rejected — Functions v2 already runs on Cloud Run under the hood, so
  migrating a specific hot-path function to a dedicated Cloud Run service
  later is a cheap, incremental move if cold starts ever become a real
  problem, not an architectural fork we need to decide now.

**Best practices**: every HTTPS callable/trigger handler is a **thin
shim** — validate input, resolve caller authority (§15.26), invoke exactly
one Application-layer use-case class, map the result — per
[`08_System_Architecture.md`](08_System_Architecture.md) §8.5; **payment
webhook handlers are idempotent** (a retried webhook delivery must never
double-record a Payment — check for an existing record with the same
gateway reference before writing); Functions v2 with an explicit
`minInstances` set for latency-critical functions on the check-in/payment
path, to avoid cold-start latency violating the Receptionist speed
requirement ([`03_User_Personas.md`](03_User_Personas.md) §3.2); secrets
(Razorpay keys, WhatsApp BSP credentials) live in **Secret Manager**, never
in function source or environment-variable literals committed to the repo.

**Common mistakes**: business logic embedded directly in a trigger
handler instead of delegated to a use-case class (the single most likely
way this codebase would quietly violate its own Clean Architecture
mandate); missing idempotency on a webhook handler, causing a Student to
be double-charged or a Payment to be recorded twice on a network retry;
oversized function memory/timeout settings chosen defensively "to be
safe," inflating cost at thousands-of-tenants scale; forgetting to verify
a webhook's cryptographic signature before trusting its payload.

**Project standards**: one source file per use case, grouped by feature
area, mirroring the Flutter clients' feature-first folder structure
(§15.20); shared cross-cutting code (auth-context resolution, the
`Result`/`Failure` mapping from §15.17) lives in a small shared package
imported by every function, not copy-pasted; Functions v2 exclusively —
v1 is not used for any new function; every webhook handler has an
idempotency test in its test suite (§15.23) before it ships.

---

## 9. Firebase Storage

**Why we selected it**: Cloud Storage with Firebase's client SDK and
security-rules integration — direct, secure client uploads of ID
documents and photos without routing binary data through a Cloud
Function, while still enforcing the same `organizationId`/`branchId`
access model as Firestore.

**Alternatives considered**: raw Google Cloud Storage without the
Firebase SDK/rules layer (functionally the same underlying service, just
without the convenient client-side rules integration — no real reason to
choose this over Firebase Storage); routing all uploads through a Cloud
Function that writes to Storage server-side with a signed URL (considered
specifically for ID documents, given their sensitivity — deferred rather
than adopted broadly: direct client upload under strict security rules is
sufficient and simpler, but this pattern is the fallback if a future
compliance requirement demands server-mediated uploads).

**Best practices**: Storage paths **mirror the Firestore path structure**
exactly (`organizations/{orgId}/branches/{branchId}/students/{studentId}/…`)
so the security rules for Storage can apply the identical
`canAccessBranch` logic already established in
[`07_Firestore_Schema.md`](07_Firestore_Schema.md) §7.4, rather than a
second, independently-maintained authorization scheme; enforce file-size
and MIME-type limits **both** client-side (fast feedback, doesn't waste a
Student's mobile data on an upload that will be rejected) **and** in
Storage security rules (the actual enforcement — client-side checks are
UX only, matching the general security posture in §15.26); compress
images on-device before upload.

**Common mistakes**: a Storage path that doesn't mirror the Firestore
structure, forcing a second, drifting authorization scheme to be
hand-maintained; validating file type/size only client-side, allowing a
modified client or direct API call to upload an oversized or wrong-type
file; leaving orphaned files in Storage when a Student's photo is
replaced (no cleanup step), slowly accumulating storage cost across
thousands of tenants; unoptimized multi-megabyte photos causing slow
roster-list rendering.

**Project standards**: max upload size 5MB; allowed types JPEG/PNG/PDF
(ID documents) and JPEG/PNG (photos) only; client-side compression
target before upload; a Cloud Function trigger generates a thumbnail
variant for any newly-uploaded Student photo, and roster list views use
the thumbnail, never the full-resolution original.

---

## 10. Firebase Messaging

**Why we selected it**: native, zero-additional-vendor push notification
delivery, tightly integrated with the rest of the Firebase stack already
in use. Per
[`08_System_Architecture.md`](08_System_Architecture.md) §8.9, push is
one of three reach channels (alongside WhatsApp and SMS), and explicitly
**not** the primary one for reminders that must reliably reach a Student
— that's WhatsApp/SMS, because push assumes the app is installed and
notification permission was granted, which is not guaranteed for this
demographic.

**Alternatives considered**: OneSignal or a similar third-party push
provider — rejected as an unnecessary added vendor given FCM's native fit
and the fact that push is a secondary channel here, not the primary
reliability-critical one (which would raise the bar for provider
selection significantly higher than it is).

**Best practices**: **token-based** targeting for personalized
notifications (a specific Student's fee-due reminder), **topic-based**
targeting for Branch-wide broadcasts (an Announcement, per
[`14_Domain_Model.md`](14_Domain_Model.md) §Announcement); handle FCM
token refresh/rotation and keep the current token associated with the
right user server-side; every notification's payload carries enough data
to deep-link directly to the relevant `go_router` route (§15.5) on tap,
tested in both foreground and background/terminated app states; respect a
quiet-hours policy for non-urgent notifications.

**Common mistakes**: treating push as the sole reminder channel when our
own architecture explicitly designed WhatsApp/SMS as the reliable
fallback — a feature that only sends push for something as consequential
as a fee-due reminder is a bug, not a minimal viable implementation;
letting stale/invalidated tokens accumulate without cleanup; not testing
tap-to-deep-link behavior from a fully terminated app state, which
behaves differently from a backgrounded one; sending non-urgent
notifications at inappropriate hours.

**Project standards**: every fee/dues-related notification is sent via
**both** FCM (if a valid token exists) and WhatsApp/SMS (per
[`08_System_Architecture.md`](08_System_Architecture.md) §8.9's channel
priority) — never FCM alone for anything financially consequential; a
documented deep-link payload schema, versioned so an older app build
doesn't crash on a newer payload shape; no non-urgent push between
22:00–07:00 Branch-local time.

---

## 11. Crashlytics

**Why we selected it**: zero-additional-cost, tightly integrated crash
and non-fatal error reporting with actionable, symbolicated stack traces,
sufficient for this project's current scale.

**Alternatives considered**: **Sentry** — a genuinely strong alternative
with richer cross-platform error grouping and breadcrumb/user-context
tooling in some workflows. Not chosen for now, specifically because
Crashlytics' tighter Firebase integration and zero marginal cost outweigh
Sentry's extra capability at our current scale — this is flagged as an
explicit, open **re-evaluation point**, not a permanent lock-in: if
Crashlytics' triage experience proves insufficient as the team and error
volume grow, Sentry is the documented fallback, not a decision to
re-litigate from scratch.

**Best practices**: set **custom keys** for triage context —
`organizationId`, `branchId`, and the caller's role — **never** PII (no
phone numbers, no names, no ID document references); log caught-but-notable
non-fatal exceptions, not just uncaught crashes, since a caught error that
silently degrades a feature (e.g. a failed background sync) is invisible
otherwise; upload debug symbols for every release build in CI so stack
traces are actually symbolicated, not just raw addresses; track
crash-free-users rate as an explicit release-health gate (§15.24).

**Common mistakes**: logging PII into custom keys or exception messages —
a genuine compliance risk, not a style nitpick, given this system holds
phone numbers and ID documents; shipping a release build without
verifying crash reporting actually works end-to-end in that build
configuration (a common trap: works in debug, silently misconfigured in
release); treating non-fatal error trends as noise until they eventually
become a fatal crash that could have been caught earlier; no alert
threshold configured, so a crash-rate spike goes unnoticed until a Owner
or Receptionist complains.

**Project standards**: PII redaction is enforced the same way everywhere
it applies in this document (Crashlytics, Analytics §15.12, Logging
§15.18) — one rule, stated multiple places for visibility, not three
independent policies; crash-free-users rate below a set threshold blocks
a release rollout (§15.24) rather than being a dashboard nobody checks.

---

## 12. Analytics

**Why we selected it**: Firebase Analytics (GA4-based), free, integrated,
sufficient for the funnel/activation metrics already defined in
[`02_Product_Requirements_Document.md`](02_Product_Requirements_Document.md)
§2.8 — Owner activation rate, Student payment engagement — without
committing to a dedicated product-analytics vendor before we know exactly
what deeper questions we'll need answered.

**Alternatives considered**: Mixpanel or Amplitude — richer
product-analytics feature sets (better funnel/retention tooling, cohort
analysis) that are a strong fit for [`13_Product_Roadmap.md`](13_Product_Roadmap.md)
Phase 1/2's deeper analytics needs; deliberately deferred rather than
adopted now, to avoid over-instrumenting a taxonomy before product
validation tells us what actually matters (and to avoid a second vendor
integration before it's earned).

**Best practices**: define an explicit **event taxonomy** up front, tied
directly to the PRD §2.8 metrics, rather than letting event names
accumulate ad hoc per developer; consistent `snake_case` naming per GA4
convention; instrument signal, not every tap — over-instrumentation
produces noise that makes the metrics that matter harder to find, not
easier; respect user consent/opt-out.

**Common mistakes**: logging PII (phone number, name) as an event
parameter — explicitly against GA4's own terms of service, not just our
internal policy; inconsistent event naming between the Owner/Staff app
and the Student app, which breaks any attempt at a cross-app funnel;
adding events without a clear tie-back to a metric anyone is actually
watching, producing a taxonomy nobody trusts or uses.

**Project standards**: a canonical event taxonomy document is created
alongside implementation kickoff (referenced from here, not duplicated
here) mapping every tracked event directly to a PRD §2.8 metric; only a
short, named list of people (product + engineering leads) can add new
top-level event names, to keep the taxonomy coherent as the team grows;
the PII rule from §15.11 applies identically here.

---

## 13. Remote Config

**Why we selected it**: app-wide feature flags, gradual rollout
percentages, and **app-behavior** tunables that shouldn't require an app
store release to change — kill switches for a risky new feature, staged
rollout of a redesigned check-in flow.

**A distinction that matters more than the tool itself**: Remote Config
is for **platform-wide app behavior**, never for **per-tenant business
configuration**. A Branch's `CheckInPolicy` or grace-period days
([`14_Domain_Model.md`](14_Domain_Model.md) BR-16) is Firestore **domain
data** — it varies per Branch, an Owner controls it, and it's part of the
Domain Model. It is never modeled as a Remote Config value. Conflating
these two is the single most likely misuse of this tool in this codebase,
so it's called out explicitly rather than left to be discovered the hard
way.

**Alternatives considered**: a dedicated feature-flag/experimentation
platform (LaunchDarkly, Split) — richer targeting and experimentation
tooling, but an added vendor and cost not justified before we have real
experimentation needs; deferred, revisit if A/B testing becomes a real
product practice. Hardcoded constants — rejected outright: no
runtime tunability means every small operational tweak requires a full
app-store release cycle, which is both slow and risky for anything
we'd want to roll back quickly.

**Best practices**: every Remote Config value ships with a **sane
in-app default** so the app functions correctly even if the config fetch
fails or the device is offline (this directly serves NFR-3 — never let a
config-fetch failure be a functional outage); use staged rollout
percentages for anything risky rather than a global flip; remove a flag
from code once its feature is fully rolled out and stable for one release
cycle — flags that live forever accumulate complexity nobody remembers
the reason for.

**Common mistakes**: using Remote Config for per-tenant business settings
(the mistake flagged above); no default value, so an offline first-launch
breaks; leaving a "temporary" rollout flag in code indefinitely; changing
a production flag with no audit trail of who changed it and when.

**Project standards**: flag naming convention `feature_<name>` for
rollout flags and `config_<name>` for tunables; every flag has a
documented owner and a removal target date at creation time; production
Remote Config changes are restricted to the same Owner-tier internal
permission used for Platform Admin actions
([`07_Firestore_Schema.md`](07_Firestore_Schema.md) §7.4), and every
change is logged.

---

## 14. Offline Strategy

**Why this approach**: expands
[`08_System_Architecture.md`](08_System_Architecture.md) §8.7. NFR-3
(offline resilience) reflects real tier-2/3-town connectivity, not an
edge case. The chosen approach: lean on Firestore's SDK-native offline
persistence for the common case (reads, most UI state), and layer
**explicit, honest pending-state UX** on top for the specific
correctness-critical writes where an optimistic local write could
mislead someone about money or a seat.

**Alternatives considered**: a fully custom offline-sync engine built
from scratch — rejected as reinventing what the Firestore SDK already
provides natively, at real engineering cost for no benefit; treating
*every* local write as immediately authoritative (simpler to build, but
directly reintroduces the double-booking risk the Seat-Availability lock
mechanism exists to prevent — rejected outright, this is exactly the
NFR-6-over-NFR-3 trade-off [`08_System_Architecture.md`](08_System_Architecture.md)
§8.7 already settled).

**Best practices**: enable Firestore's offline persistence with a bounded
cache size (not unlimited — a front-desk device may run for months
without a restart); distinguish, per screen/action, "safe to show
optimistically" (most reads, most UI navigation) from "must show
pending-until-confirmed" — check-in, payment recording, and Enrollment
creation are always in the second category, because all three interact
with the Seat-Availability lock or money; test explicitly under flaky
conditions (airplane-mode toggling mid-action), not just "fully offline
the whole time," since real-world connectivity drops and returns rather
than staying off.

**Common mistakes**: assuming a queued offline write will "just work" and
skipping the pending-state UI entirely, which is exactly how a
Receptionist could believe a double-booked check-in succeeded when it
will actually fail once connectivity returns and the transaction
re-evaluates; unbounded local cache growth over a long-lived device
session; assuming FCM will reliably reach a device that's actually
offline (it won't — plan the UX around eventual reconnect, not
notification delivery).

**Project standards**: the "must show pending-until-confirmed" set is
exactly: check-in, payment recording, Enrollment creation/seat-change —
matching the correctness-critical set already identified in
[`08_System_Architecture.md`](08_System_Architecture.md) §8.7; Firestore
cache size is bounded and configured explicitly, never left at an
unbounded default; every pending-state UI has a corresponding
integration test (§15.23) that simulates the reconnect-and-resolve path,
including the failure branch (seat taken by someone else while offline).

---

## 15. Repository Pattern

**Why we selected it**: the concrete mechanism for Clean Architecture's
Dependency Inversion, already established in
[`08_System_Architecture.md`](08_System_Architecture.md) §8.4/§8.14 — the
Application layer depends on repository *interfaces* it owns; Firestore
implementations live in the Infrastructure layer and are swapped in only
at the composition root (§15.16). This is what makes business logic
(§15.23's unit-test majority) testable without Firebase running at all,
and what makes Branch isolation a **repository-interface-level**
guarantee (§08 §8.4) rather than something every call site has to
remember.

**Alternatives considered**: direct Firestore SDK calls from Notifiers or
widgets — rejected outright, the single fastest way to violate every
Clean Architecture guarantee this system depends on; a single generic
"DataService" covering all collections — rejected, violates Interface
Segregation ([`08_System_Architecture.md`](08_System_Architecture.md)
§8.14) and produces exactly the kind of god-object that makes a codebase
harder to reason about as it grows, not easier.

**Best practices**: **one repository interface per Aggregate Root**
(§14.5's aggregate map is the authoritative list — `OrganizationRepository`,
`OwnerRepository`, `BranchRepository`, `ReceptionistRepository`,
`SeatRepository`, `ShiftRepository`, `LockerRepository`,
`MembershipPlanRepository`, `StudentRepository`, `EnrollmentRepository`,
`FeeCycleRepository`, `AttendanceRepository`, `ExpenseRepository`,
`AnnouncementRepository`, `SubscriptionRepository`) — **not** one per
Firestore collection, and specifically **no `PaymentRepository`**, since
Payment is a child entity accessed exclusively through
`FeeCycleRepository` per its aggregate boundary in
[`14_Domain_Model.md`](14_Domain_Model.md); every Branch-scoped
repository method takes `organizationId`/`branchId` as required, leading
parameters, never optional filters (restated from
[`08_System_Architecture.md`](08_System_Architecture.md) §8.4 as a hard
project standard, not a suggestion); methods accept and return domain
Entities/VOs exclusively.

**Common mistakes**: a Firestore-specific type (`Timestamp`,
`DocumentSnapshot`, `DocumentReference`) leaking through a repository
interface into the Application layer — this breaks the abstraction
entirely and is the most common way a "Clean Architecture" codebase stops
being one in practice; creating a repository per collection instead of
per aggregate (a `PaymentRepository` existing at all is a signal
something's wrong); putting business-rule validation *inside* a
repository implementation — repositories are pure data access, business
rules belong in the Domain/Application layers (§15.17).

**Project standards**: repository interfaces live in each feature's
domain layer folder (§15.20); Firestore implementations live in the
matching infrastructure layer folder; every Application-layer use case's
unit test (§15.23) is written against a fake/in-memory implementation of
its repository interfaces, never a real or emulated Firestore — that's
what the separate, smaller set of infrastructure-layer integration tests
(§15.23) is for.

---

## 16. Dependency Injection

**Why we selected it**: **Riverpod is the DI mechanism**, not a separate
framework — providers are the composition root, and Notifiers/use cases
declare their dependencies (repository interfaces) as `ref.watch`/`ref.read`
of a provider, which Riverpod resolves. Running a second DI framework
alongside Riverpod would be pure duplication.

**Alternatives considered**: `get_it` + `injectable` — a popular,
legitimate service-locator-based alternative; rejected in favor of
Riverpod's approach specifically because it avoids running two competing
paradigms (state management and DI) side by side, and Riverpod's
provider-override mechanism for testing (§15.4/§15.23) is more direct
than swapping registrations in a service locator. Fully manual
constructor injection with no framework at all — too much boilerplate at
this project's scale (dozens of use cases across many features).

**Best practices**: concrete repository implementations are provided
**exactly once**, at a small, explicit composition-root provider set (not
scattered `Provider`s created ad hoc per feature); tests override these
same providers with fakes via `ProviderContainer`, never by reaching into
a global service locator; scope providers deliberately — repositories as
effectively-global singletons, feature/screen state as `autoDispose` or
`family`-scoped (§15.4/§15.29).

**Common mistakes**: instantiating a Firestore repository implementation
directly inside a widget or Notifier instead of receiving it via `ref`
— this silently bypasses DI and makes the code untestable without a real
Firestore, exactly what the Repository Pattern (§15.15) exists to
prevent; treating a top-level provider as a global mutable bag instead of
a well-scoped dependency; circular provider dependencies, usually a sign
two features should not depend on each other directly.

**Project standards**: the composition root (where every repository
interface is bound to its Firestore implementation) lives in one clearly
named location per app, not duplicated per feature; every use-case-level
test overrides its repository dependencies explicitly — a test that
accidentally exercises a real implementation because an override was
forgotten is treated as a test-suite bug, not a passing test.

---

## 17. Error Handling

**Why we selected this approach**: a typed, explicit **Result**-style
return (a sealed `Success`/`Failure` union) from every Application-layer
use case, rather than letting exceptions — especially raw infrastructure
exceptions — propagate up to the Presentation layer. This pairs directly
with Riverpod's `AsyncNotifier`/`AsyncValue`, which already models
loading/data/error natively (§15.4), and it directly serves the UX
principle from [`09_UI_UX_Guidelines.md`](09_UI_UX_Guidelines.md) §9.2
("errors explain the fix, not just the failure") — a typed `Failure`
carries enough structure to render a specific, actionable message, where
a caught generic exception does not.

**Alternatives considered**: raw `try`/`catch` with unstructured
exceptions surfaced directly to the UI — rejected, this is precisely how
a non-technical Owner ends up staring at "Error 409" or a raw stack trace,
which [`09_UI_UX_Guidelines.md`](09_UI_UX_Guidelines.md) explicitly
identifies as unacceptable; typed domain exceptions caught only at the
Presentation boundary (a valid alternative pattern) — considered, but a
`Result` type was chosen because it makes the possibility of failure
visible **at every call site's type signature**, rather than depending on
every developer remembering to wrap every call in a `try`/`catch` —
stronger consistency guarantee at scale.

**Best practices**: a small, closed `Failure` hierarchy —
`NetworkFailure`, `ValidationFailure`, `PermissionFailure`,
`ConflictFailure` (the seat-just-taken case from
[`04_User_Flows.md`](04_User_Flows.md) §4.2 maps directly to this),
`NotFoundFailure` — mapped from raw infrastructure exceptions **at the
repository boundary**; a `FirebaseException` must never escape the
Infrastructure layer as itself. User-facing error copy is centralized and
separate from the `Failure` type itself, so it stays localization-ready
(NFR-8) and so tone (§09's guidance) is reviewed in one place, not
scattered per call site.

**Common mistakes**: swallowing a `Failure` silently (no UI feedback at
all) instead of surfacing it appropriately; showing a raw
`exception.toString()` to a Receptionist mid-rush; inconsistent handling
— some features using the `Result` pattern, others reverting to ad hoc
`try`/`catch` — undermining the whole point of a project-wide standard;
treating every failure as equally fatal instead of distinguishing
recoverable (offer retry) from terminal (explain and stop).

**Project standards**: every Application-layer use case returns a
`Result`-shaped type; the `Failure` hierarchy above is the exhaustive,
closed set — a new failure kind is a deliberate addition to this
document's list, not an ad hoc subclass added in a feature branch; the
mapping from infrastructure exception to domain `Failure` happens in
exactly one place per repository implementation, tested explicitly.

---

## 18. Logging

**Why we selected this approach**: structured, consistently-shaped
logging on both the client and Cloud Functions side, extending the shape
already specified for Functions in
[`08_System_Architecture.md`](08_System_Architecture.md) §8.11
(`organizationId`, `branchId`, `actorId`, `action`, `latency`) to the
client as well — debugging an issue for one of thousands of tenants
requires being able to filter logs down to exactly that tenant's activity,
which unstructured `print`/`console.log` output cannot support.

**Alternatives considered**: ad hoc `print`/`console.log` statements —
rejected, unfilterable, and stripped or ignored in release builds anyway;
a dedicated third-party logging platform (Datadog, etc.) — deferred,
Cloud Logging plus Crashlytics breadcrumbs are sufficient at current
scale; revisit if/when log volume or cross-service correlation needs
outgrow what Firebase's own tooling provides.

**Best practices**: every log entry, client or server, carries the same
core shape (`organizationId`, `branchId`, `actorId`, `action`, and where
relevant `latency`); use log levels (`debug`/`info`/`warn`/`error`) with
`debug` compiled out of release builds entirely, not just filtered at
runtime; correlate a client-initiated action with its server-side
Cloud-Function log entries via a shared request/trace identifier where
technically feasible, to make end-to-end debugging tractable.

**Common mistakes**: logging PII — phone numbers, names, ID document
URLs, payment details — in plaintext anywhere, client or server (the same
rule as §15.11/§15.12, restated because logs are the easiest place for
this to slip in unnoticed during debugging); leaving verbose debug
logging active in a production build, both a performance cost and a
noise problem when it's time to actually find something; inconsistent log
shape between features making cross-cutting debugging (e.g. "show me
everything that happened for this Enrollment") impractical.

**Project standards**: the structured shape above is mandatory for every
log call, enforced by a shared logging utility rather than each feature
rolling its own; a PII-redaction check is part of code review for any new
logging call (and ideally a lint rule, once tooling for that is in place)
— this is treated with the same seriousness as the equivalent Crashlytics
and Analytics rules, because it is, in effect, the same rule restated for
a third surface.

---

## 19. Environment Configuration

**Why we selected this approach**: three fully separate Firebase projects
— dev, staging, production — per
[`08_System_Architecture.md`](08_System_Architecture.md) §8.12, plus
Flutter **flavors** combined with `--dart-define-from-file` for
client-side environment/config selection, keeping secrets out of source
control.

**Alternatives considered**: a single Firebase project with
environment-prefixed collections — already rejected in
[`08_System_Architecture.md`](08_System_Architecture.md) §8.12 for
weaker isolation and no safe place to test destructive changes; committed
`.env`-style files with real keys in the repository — rejected outright,
a direct secret-leakage risk; Flutter flavors alone without
`--dart-define`, relying only on separate native build configs — workable
but more fragmented across Android/iOS build systems than a single
Dart-level config mechanism; **chosen**: flavors for the native
build-target split, `--dart-define-from-file` pointing at a per-environment,
**gitignored** JSON file for runtime config, with CI injecting the real
values from a secure secret store at build time.

**Best practices**: never hardcode a Firebase project's config in source;
never commit `google-services.json`/`GoogleService-Info.plist` for
anything other than the intended environment (each environment's file is
gitignored and provided by CI/local secure config, matching the
`--dart-define-from-file` approach); staging is treated as a
first-class environment with full feature parity to production — it's
where regression testing (§15.23/§15.24) actually happens before a
release, not a "lesser" afterthought environment.

**Common mistakes**: a debug or staging build accidentally pointed at the
production Firebase project (a serious, plausible mistake without a
strict per-flavor config file convention); developers hand-editing a
shared config file instead of using the flavor mechanism, causing drift
between what's committed and what's actually running; secrets committed
"temporarily" to unblock a build and never removed from git history.

**Project standards**: exactly three flavors — `dev`, `staging`, `prod`
— per app; each flavor's config file lives at a fixed, documented,
gitignored path; CI injects the real per-environment secrets from its
secret store at build time, never from a file checked into the repo;
every release build is built with the `prod` flavor explicitly and that
flavor choice is a visible, reviewed step in the CI/CD pipeline (§15.24),
never an implicit default.

---

## 20. Folder Structure

**Why we selected this structure**: **feature-first, layered within each
feature** — not a top-level `lib/domain/`, `lib/application/`,
`lib/infrastructure/`, `lib/presentation/` split containing every
feature's files mixed together. Each feature folder mirrors the
Aggregate/feature boundaries from
[`14_Domain_Model.md`](14_Domain_Model.md) directly, so "everything about
Enrollment" is findable in one place, and a growing team can work on
different features without constant merge conflicts in shared top-level
layer folders.

**Alternatives considered**: pure layer-first organization (all
Notifiers together, all repositories together, regardless of feature) —
workable for a small app, but doesn't scale as feature count grows; the
question "what does the Enrollment feature touch" becomes a
cross-folder search instead of "open the `enrollment/` folder." Rejected
for this project's expected size (a system with fifteen-plus aggregate
roots per [`14_Domain_Model.md`](14_Domain_Model.md) §14.5, growing over
several roadmap phases).

**Best practices**: a `core`/`shared` folder holds only genuinely
cross-cutting concerns — the Value Objects from
[`14_Domain_Model.md`](14_Domain_Model.md) §14.4 (`Money`, `PhoneNumber`,
`DateRange`, …), the `Result`/`Failure` hierarchy (§15.17), the session/
auth-context providers (§15.29 Tier 3) — and is actively guarded against
becoming a dumping ground for anything that doesn't obviously belong to
one feature; features depend on `core`, never on each other's internals
directly (a feature needing another feature's data goes through that
feature's public repository interface, not its private Notifier/state).

**Common mistakes**: a feature reaching directly into another feature's
`infrastructure` or internal `domain` folder instead of through its
public interface; `shared`/`common`/`utils` growing unchecked into a
second, disorganized application; Presentation-layer code (widgets)
appearing inside a `domain` folder, or vice versa, eroding the layer
boundary the whole folder structure exists to make visible.

**Project standards** — the tree below (feature list illustrative, not
exhaustive; mirrors [`14_Domain_Model.md`](14_Domain_Model.md) §14.5's
aggregate map):

```
lib/
  core/
    domain/            (Money, PhoneNumber, DateRange, other shared VOs)
    result/            (Result/Failure hierarchy, §15.17)
    session/           (auth/org/branch context providers, §15.29 Tier 3)
    routing/           (go_router shell config, §15.5)
  features/
    organization/
      domain/          (Organization entity, OrganizationRepository interface)
      application/     (use cases: CreateOrganization, ...)
      infrastructure/  (FirestoreOrganizationRepository)
      presentation/    (screens, widgets, Notifiers)
    branch/
      domain/  application/  infrastructure/  presentation/
    seat/
      ...
    enrollment/
      ...
    fee_cycle/
      ...
    attendance/
      ...
    (one folder per feature/aggregate area from §14.5's map)
  app.dart             (app entrypoint, flavor wiring)
```
The Cloud Functions codebase mirrors this same feature-first convention
under its own root, per §15.8's "grouped by feature area" standard.

---

## 21. Naming Conventions

**Why we selected these conventions**: consistency reduces cognitive load
across a codebase that will span dozens of features and, over time,
multiple engineers who didn't write each other's code — a naming
convention is a small, cheap investment that pays off continuously at
scale, and its absence is a compounding tax.

**Alternatives considered**: no enforced convention, left to individual
developer preference — rejected, guaranteed to produce entropy as the
team grows; adopting a heavier, more verbose enterprise-Java-style
convention — rejected as unidiomatic for Dart/Flutter and TypeScript,
fighting the grain of both ecosystems' own community norms instead of
building on them.

**Best practices / Project standards** (stated together here, as this
section is itself a standards reference):

| Concept | Convention | Example |
|---|---|---|
| Dart files | `snake_case.dart` | `enrollment_repository.dart` |
| Dart classes | `PascalCase` | `EnrollmentRepository` |
| Repository interfaces | `{Aggregate}Repository` | `StudentRepository` |
| Repository implementations | `Firestore{Aggregate}Repository` | `FirestoreStudentRepository` |
| Use cases | `{Verb}{Noun}UseCase` | `RecordPaymentUseCase` |
| Riverpod Notifiers | `{Feature}Notifier` | `EnrollmentNotifier` |
| Riverpod providers (generated) | `{feature}Provider` (camelCase) | `enrollmentProvider` |
| Screens | `{Feature}Screen` | `SeatMapScreen` |
| Reusable widgets | `{Purpose}Widget` or a specific descriptive name, never generic `CustomWidget` | `SeatTileWidget` |
| Failure types | `{Reason}Failure` | `ConflictFailure` |
| Firestore collections | plural camelCase | `enrollments`, `feeCycles` |
| Cloud Functions | `verbNoun` | `enrollStudent`, `recordPayment` |
| Domain Events | `{Entity}{PastTenseVerb}` | `EnrollmentCreated` |

**Common mistakes**: inventing a one-off naming pattern for a single
feature instead of following the table above; naming a class for its
implementation detail rather than its role (`EnrollmentHelper` instead of
`EnrollmentNotifier` or a properly named use case); generic, meaningless
names (`Manager`, `Handler`, `Util`) that convey no information about
what the thing actually does.

---

## 22. Code Style

**Why we selected it**: `dart format` (non-negotiable, zero-configuration
formatting) plus a **stricter-than-default** analyzer rule set — `very_good_analysis`
as the base, with a small number of project-specific additions — rather
than Flutter's own lighter-touch `flutter_lints` alone, given this
project's production-financial-system bar.

**Alternatives considered**: `flutter_lints` only — the default,
lighter-touch option; considered insufficiently strict for a codebase
where correctness around money and concurrency (§15.7's Seat-Availability
pattern, §15.17's Failure handling) matters this much; a fully custom
lint set built from scratch — rejected as unnecessary ongoing maintenance
overhead when `very_good_analysis` already codifies most of what we'd
want.

**Best practices**: format-on-save configured in every editor;
`dart format --set-exit-if-changed` and `flutter analyze` (equivalently,
the TypeScript/ESLint pair for Cloud Functions) run as a required,
blocking CI check (§15.24) — never a local-only courtesy step; lints
disabled only with an inline comment explaining *why*, reviewed like any
other code change, never disabled silently or project-wide to make a
warning go away.

**Common mistakes**: inconsistent formatting creating noisy, hard-to-review
diffs; analyzer warnings allowed to accumulate until they're too numerous
to meaningfully review, defeating the point of having them at all;
disabling a lint rule broadly (at the project level) to fix one
inconvenient false positive, silencing it everywhere else too.

**Project standards**: `very_good_analysis` (Dart/Flutter) and a
comparable strict shared ESLint config (TypeScript/Cloud Functions) are
the baseline; zero analyzer/lint warnings is a required, CI-enforced merge
gate, not an aspiration; a pre-commit hook runs formatting and static
analysis locally before a commit can even be pushed, catching issues
before they reach CI at all.

---

## 23. Testing Strategy

**Why we selected this mix**: a **unit-test-heavy** pyramid, because
Clean Architecture's entire value proposition
([`08_System_Architecture.md`](08_System_Architecture.md) §8.4) is that
business logic — the BR-1 through BR-29 rules in
[`10_Business_Rules.md`](10_Business_Rules.md), and every Domain Service in
[`14_Domain_Model.md`](14_Domain_Model.md) §14.10 — is testable without
Firebase running at all. If that promise isn't backed by a real,
comprehensive unit-test layer, the architecture's cost was paid without
collecting its main benefit.

**Test layers**:
- **Unit tests** (majority, fast, no Firebase): every domain rule, every
  use case, every Domain Service, tested against fake repository
  implementations (§15.15/§15.16).
- **Widget tests**: individual Presentation-layer components, especially
  the seat map and dashboard tiles where
  [`09_UI_UX_Guidelines.md`](09_UI_UX_Guidelines.md) §9.2's "communicate
  at a glance" requirement is a real, testable constraint.
- **Golden tests**: visual-regression coverage specifically for the seat
  map and dashboard — screens where a subtle visual regression (a broken
  color-coding) is a real product-quality risk, not just a cosmetic one.
- **Integration tests** (small, curated set, Firebase **emulator**-backed):
  the critical end-to-end flows — Enrollment creation and its
  double-booking guard, Payment recording, check-in — run against the
  emulator suite, plus **security-rule tests** validating the
  `canAccessBranch` isolation guarantee from
  [`07_Firestore_Schema.md`](07_Firestore_Schema.md) §7.4 directly.

**Alternatives considered**: an integration-test-heavy strategy as the
primary layer — rejected as the *primary* approach: slow, comparatively
flaky, and expensive to run at the frequency a PR-gate demands; still
used, deliberately, for the small set of flows above where only a real
(emulated) Firestore can validate the thing that matters (a transaction,
a security rule). No automated testing beyond manual QA — rejected
outright as unacceptable for a system this dependent on financial
correctness (NFR-6).

**Best practices**: one unit test file per use case and per Domain
Service, each covering its documented business rule(s) by BR-# reference
directly in the test description, so the mapping from
[`10_Business_Rules.md`](10_Business_Rules.md) to test coverage is
auditable; the emulator suite is used **only** for what genuinely needs
Firestore/Auth semantics (transactions, security rules) — never as a
substitute for a fast unit test that could have used a fake repository
instead.

**Common mistakes**: testing implementation details (internal state
shape) instead of observable behavior, producing brittle tests that
break on harmless refactors; skipping a test for a business rule that
"obviously" won't have edge cases — the leap-year-billing-cycle example
in [`08_System_Architecture.md`](08_System_Architecture.md) §8.4 is
exactly the kind of case this discipline catches; relying on manual QA as
the real safety net with automated tests as an afterthought; letting a
flaky integration test get skipped/ignored repeatedly instead of fixed,
which quietly erodes trust in the whole suite until nobody looks at test
results anymore.

**Project standards**: every rule in
[`10_Business_Rules.md`](10_Business_Rules.md) has at least one unit test
referencing its BR-# in the test description; coverage targets — Domain/
Application layers: high (explicit numeric target set at implementation
kickoff, enforced in CI); Presentation: moderate, focused on
critical/complex widgets rather than blanket coverage; Infrastructure:
covered by the emulator-backed integration suite, not unit tests: the
emulator suite (transactions + security rules) is a **required**, not
optional, CI stage (§15.24); golden-test baselines are reviewed and
approved as part of any PR that intentionally changes seat-map or
dashboard visuals.

---

## 24. CI/CD Strategy

**Why we selected it**: automated, staged pipelines per deployable unit —
Owner/Staff app, Student app, Cloud Functions, Admin console — because a
regression reaching a real Owner's daily operations has real business
cost (NFR-2), and because the four deployables have genuinely different
release cadences and shouldn't be coupled into one pipeline.

**Alternatives considered**: manual deployment — rejected outright,
unacceptable risk and no repeatability at any real scale; one monolithic
pipeline covering every deployable — rejected, an unrelated Cloud
Functions failure shouldn't block a mobile app release ready to ship, and
vice versa. **Tooling**: GitHub Actions as the primary CI/CD platform,
with **Fastlane** handling mobile build-signing/store-submission
complexity within it; **Codemagic** (a Flutter-specialized, fully-managed
CI option) was considered specifically for its mobile-release ergonomics
and is the documented fallback if GitHub Actions + Fastlane proves too
much undifferentiated pipeline maintenance — not adopted now, to keep the
whole pipeline (mobile and backend) in one platform while the team is
still small.

**Best practices**: separate pipeline definitions per deployable, each
with its own required-checks gate; every pipeline runs, at minimum: lint/
format (§15.22) → unit + widget tests → the emulator-backed integration
suite (§15.23) → build; Cloud Functions deploy automatically to
**staging** on merge to `main`, promoted to **production** only via an
explicit, separate manual-approval step — never auto-promoted; mobile
builds are distributed internally (Firebase App Distribution) for QA
before any store submission.

**Common mistakes**: one giant pipeline where an unrelated failure blocks
every deployable; no rollback plan for a Cloud Functions deploy (a bad
deploy to production with no fast, rehearsed rollback path is a real
incident-severity risk); secrets stored as plaintext pipeline
configuration instead of the CI platform's secret store; skipping the
emulator-test stage "to save time" on a hot-fix, which is precisely the
moment the NFR-1 isolation guarantee is least likely to have been
re-verified.

**Project standards**: the stage list above is mandatory for every
pipeline, no exceptions for hot-fixes; `main` → auto-deploy to
**staging** (Cloud Functions) / auto-build for internal distribution
(mobile); a version tag → production deploy, gated by manual approval;
every production Cloud Functions deploy has a documented, rehearsed
rollback procedure (redeploy the previous version tag) that's actually
been exercised at least once, not just written down.

---

## 25. Git Branch Strategy

**Why we selected it**: **trunk-based development** — `main` is always
in a deployable-to-staging state, feature branches are short-lived, and
incomplete work ships behind a Remote Config flag (§15.13) rather than
living on a long branch. This is a direct consequence of §15.24's CI/CD
design (auto-deploy to staging on every merge to `main`) and fits a small,
fast-moving team better than a heavier branching model.

**Alternatives considered**: GitFlow (release branches, develop branch,
hotfix branches) — rejected as too heavyweight for this team's size and
velocity needs; the continuous-staging-deploy model this project uses
doesn't need GitFlow's release-branch ceremony, since "what's on `main`"
already answers "what's on staging" at all times. A single shared branch
with direct commits and no PR review — rejected outright, unacceptable
for a system handling money without a review gate.

**Best practices**: feature branches live days, not weeks; every merge to
`main` requires a passing CI pipeline (§15.24) and at least one review;
incomplete or risky features ship behind a Remote Config flag instead of
staying unmerged on a long branch, keeping `main` close to what's
actually running; commit messages follow a consistent, semantic
convention to support automated changelog generation.

**Common mistakes**: a feature branch that lives for weeks, accumulating
painful merge conflicts and drifting far from `main`'s actual state;
force-pushing to a shared branch; merging with a failing or skipped CI
check via an override, which defeats the entire purpose of §15.24's
gates; no branch-protection rules configured, making the "required
review + passing CI" policy unenforced in practice rather than actually
guaranteed.

**Project standards**: branch prefixes `feature/`, `fix/`, `chore/`;
`main` is protected — direct pushes disabled, PR + passing CI + at least
one review required; release tags follow semantic versioning; feature
flags (§15.13) are the standard mechanism for incomplete work, not long
-lived branches.

---

## 26. Security Strategy

**Why we selected this posture**: **defense in depth**, consolidating and
extending the two-layer authorization model already established in
[`07_Firestore_Schema.md`](07_Firestore_Schema.md) §7.4 and
[`08_System_Architecture.md`](08_System_Architecture.md) §8.5 — Firestore
security rules protect direct client access; explicit application-layer
`orgAccess` checks protect Cloud Functions (which run with Admin-SDK
privileges that bypass rules entirely). Neither layer is ever treated as
"covered by the other one anyway" — this is restated here as the
project's canonical, non-negotiable security policy, with the additional
concrete controls below layered on top.

**Alternatives considered**: relying on Firestore rules alone (rejected
— leaves every server-side Cloud Function code path unprotected, since
Admin SDK bypasses rules by definition); reCAPTCHA alone for abuse
prevention instead of App Check (rejected — App Check is the modern,
stronger superset, integrating with Auth, Firestore, and Functions
uniformly rather than being bolted onto one surface).

**Best practices**:
- **Firebase App Check** enabled across Auth, Firestore, and Functions —
  rolled out in **monitor mode first**, then switched to **enforced**
  once verified clean, guarding specifically against the OTP-toll-fraud
  and scripted-abuse risks named in §15.6.
- **Secrets** (Razorpay keys, WhatsApp BSP credentials, service account
  keys) live in **Secret Manager** exclusively — never in source, never
  in a CI config file in plaintext.
- **Least-privilege IAM**: every service account gets a scoped custom
  role, never the default broad `Editor`/`Owner` project role.
- **Dependency scanning** (Dependabot or equivalent) enabled on both the
  Dart/Flutter and TypeScript/Node dependency trees, with a defined
  response SLA for high-severity findings.
- **PCI scope stays minimal by design**: card data is handled entirely
  within Razorpay's hosted checkout/SDK — this system never receives,
  stores, or transmits raw card numbers, consistent with the payment
  architecture already chosen in
  [`08_System_Architecture.md`](08_System_Architecture.md) §8.8.
- Data is encrypted in transit (TLS, by default across the Firebase/GCP
  stack) and at rest (GCP default encryption) — stated explicitly here as
  a baseline that's true by platform default, not something we
  separately implement, but worth confirming and documenting for any
  future compliance review.

**Common mistakes**: leaving App Check in monitor-only mode indefinitely
"to be safe," which means it's never actually blocking anything; a
service account JSON key committed to git — a real, common, and
catastrophic mistake, named explicitly so it's never treated as a minor
slip; granting a broad IAM role to a service account "to avoid permission
errors" instead of scoping it precisely; trusting client-side validation
as if it were enforcement (the same mistake as §15.7/§15.9's Storage
rules point, restated as a general principle).

**Project standards**: App Check enforcement is a tracked rollout item
with a committed target date, not an indefinite monitor-mode state;
secrets rotation happens on a defined schedule (at minimum annually, or
immediately on any suspected exposure); the two-layer authorization rule
(rules **and** application-layer checks, always both) is treated as
architectural law — a PR that adds a new Cloud Function without an
explicit `orgAccess`/`canAccessBranch`-equivalent check is a blocking
review finding, not a style comment.

---

## 27. Performance Guidelines

**Why this matters**: NFR-5 (seat map and dues views render in under
~1.5s on a mid-range Android device on 4G) is a **hard product
requirement**, directly tied to the dominant device/network profile of
this product's actual users
([`03_User_Personas.md`](03_User_Personas.md)), not an aspirational
nice-to-have.

**Approaches considered** (performance guidelines aren't a
library-vs-library choice, so "alternatives" here means approaches to
meeting NFR-5): server-side rendering or heavier server-driven UI for the
seat map — considered and rejected; Flutter's own rendering plus
Firestore's offline cache is sufficient for the target device profile
without the added complexity of a server-rendering layer, provided the
practices below are actually followed.

**Best practices**:
- **Client**: minimize unnecessary widget rebuilds via `const`
  constructors and Riverpod's `.select` (§15.4); paginate every large
  list (§15.7) rather than rendering an unbounded roster; compress
  images before upload (§15.9); move CPU-heavy work (e.g. any client-side
  image processing) off the main isolate via `compute()`.
- **Server**: set `minInstances` on Cloud Functions in the check-in/
  payment critical path (§15.8) to avoid cold-start latency where speed
  is a persona-level requirement, not just a nice-to-have
  ([`03_User_Personas.md`](03_User_Personas.md) §3.2); every query
  Firestore serves is backed by a real index (§15.28) — never a
  client-side filter over an over-fetched result set.

**Common mistakes**: profiling and testing only on a developer's own
high-end phone, missing exactly the performance problems that show up on
the mid-range-Android/4G profile NFR-5 targets; an unbounded Firestore
listener fetching far more data than a screen actually renders; heavy
synchronous work blocking the UI thread and causing visible jank on the
seat map specifically, where
[`09_UI_UX_Guidelines.md`](09_UI_UX_Guidelines.md) §9.2 demands
sub-second at-a-glance legibility; ignoring cold-start latency on a
function that sits on the Receptionist's speed-critical check-in path.

**Project standards**: NFR-5's budget is treated as a target for future
automated performance-regression tooling (flagged for setup once the app
has enough real usage to benchmark meaningfully, not deferred
indefinitely); `minInstances >= 1` for the check-in and payment-recording
Cloud Functions specifically; standard list-pagination page size is set
once and reused consistently rather than chosen ad hoc per screen.

---

## 28. Firestore Index Strategy

**Why we selected this approach**: every composite index is defined in a
single, **source-controlled** `firestore.indexes.json` file, deployed via
CI (§15.24) — never created ad hoc through the Firebase console in any
environment, especially not production. This builds directly on
[`07_Firestore_Schema.md`](07_Firestore_Schema.md) §7.3's index table,
turning it from documentation into an enforced, reproducible artifact.

**Why source control specifically**: the three-environment setup
([`08_System_Architecture.md`](08_System_Architecture.md) §8.12) requires
**identical** index sets across dev, staging, and production — a
console-managed, per-environment approach drifts silently and is
error-prone by construction; a checked-in file deployed identically to
all three environments cannot drift.

**Alternatives considered**: manually managing indexes per environment
through the console — rejected for exactly the drift risk above, and
because it leaves no code-review trail for *why* an index exists (§07's
table already gives every listed index a stated purpose — that pairing
should never be lost).

**Best practices**: `firestore.indexes.json` is the single source of
truth, deployed with `firebase deploy --only firestore:indexes` as an
explicit CI step; every new composite-query pattern introduced in a PR is
reviewed against this file **in the same PR** — a new query that needs an
index is a code-review checklist item, not something discovered live in
production via a "failed precondition: index required" error; index
additions are deliberate, not speculative — an index for a query that
doesn't exist yet is pure write-cost/storage overhead with zero benefit
(YAGNI applied specifically to indexes).

**Common mistakes**: adding an index manually in the production console
to unblock an urgent bug, "just this once," and forgetting to backport it
into the tracked file — this is the single most likely way the three
environments drift out of sync; defensively over-indexing fields that
aren't actually queried against yet; a new composite query shipping in a
PR without a reviewer catching that it needs a matching index, only
discovered when it fails live.

**Project standards**: `firestore.indexes.json` lives at the repository
root and is deployed as a required stage in every environment's CI/CD
pipeline (§15.24); a PR-review checklist item explicitly asks "does any
new or changed query in this PR require an index change" for every PR
touching a repository implementation (§15.15); a periodic (quarterly)
audit removes indexes that are no longer backing any live query, keeping
the file honest over time.

---

## 29. State Management Guidelines

This section defines **where state lives**, building on §15.4's "why
Riverpod" with a concrete classification every feature is expected to
follow.

**Why this taxonomy**: without an explicit classification, a Riverpod
codebase drifts toward two failure modes — everything shoved into
global, always-alive providers (memory and unnecessary-rebuild cost), or
server state duplicated into ad hoc local mutable state that silently
drifts from what Firestore actually holds. A four-tier taxonomy makes
"where does this state belong" a checklist question, not a judgment call
made differently by every developer.

**The four tiers**:
1. **Ephemeral UI state** — a form field's current value, a toggle mid-
   interaction. Scoped as narrowly as possible, typically local widget
   state, never promoted to a global provider.
2. **Feature/screen state** — a screen's loading/data/error state for one
   use case (e.g. "the Enrollment creation flow's current step"). An
   `autoDispose`-scoped Notifier, alive only while the screen is.
3. **Shared session state** — the small, well-known set of top-level
   providers every feature may `ref.watch`: the current authenticated
   user, their resolved `orgAccess`/role, and (for a Receptionist) their
   one assigned Branch, or (for an Owner) their currently-selected Branch
   context. Deliberately small and stable — this is the client-side
   analogue of the `orgAccess` claim from
   [`07_Firestore_Schema.md`](07_Firestore_Schema.md) §7.4, and every
   Branch-scoped screen resolves its `branchId` from here, not by
   re-deriving it independently (directly reused by §15.5's routing
   guards).
4. **Server-synced state** — the majority of this app's actual data:
   Firestore-stream-backed `AsyncNotifier`s (the seat map, the roster,
   the dashboard). This tier is never duplicated into a separately
   maintained local copy — the stream **is** the state.

**Alternatives considered**: a single global app-state object
(Redux/single-store style) — rejected, too coarse-grained for Riverpod's
fine-grained rebuild model, and it would cause unrelated features to
rebuild on each other's changes; no classification at all, left to
individual judgment — rejected as inconsistent at the scale this project
is expected to reach.

**Best practices**: always default to the **narrowest tier that
correctly serves the need** — reaching for Tier 3 (shared session state)
when Tier 2 (screen-scoped) would do is the most common over-broadening
mistake; prefer a stream-backed Tier 4 `AsyncNotifier` over manually
fetching once and holding the result in Tier 2 state, since the latter
silently goes stale; let `AsyncValue`'s built-in loading/data/error union
do the work instead of hand-rolling three separate boolean flags for the
same concept.

**Common mistakes**: duplicating Firestore-sourced data into local
mutable state that drifts from the source of truth; a Tier 3-worthy
concept (the current Branch context) accidentally re-derived
independently in multiple features instead of read from the one shared
provider, risking two parts of the same screen disagreeing about which
Branch they're looking at; hand-rolled loading/error booleans instead of
`AsyncValue`, which reintroduces exactly the bug class (forgetting to
reset an error flag, showing stale data during a reload) `AsyncValue`
exists to eliminate.

**Project standards**: the four-tier taxonomy above is a mandatory
code-review checklist question for any new state introduced in a PR; the
Tier 3 shared-session provider set is small, explicitly enumerated, and
changes to it are reviewed with extra scrutiny given how many features
depend on it; every Tier 4 provider is backed by a repository's stream
method (§15.15), never a one-shot fetch dressed up as a stream.

---

## 30. Code Generation

**Why we selected it**: `build_runner`-based code generation —
specifically **`riverpod_generator`** (§15.4's `@riverpod` annotations),
**`freezed`** (immutable Entities/VOs and the sealed `Result`/`Failure`
hierarchy from §15.17), and **`json_serializable`** where genuine JSON
boundaries exist (Cloud Function payloads; most Firestore document
mapping does not need this, since the Firestore SDK's native type support
covers it). This directly serves
[`14_Domain_Model.md`](14_Domain_Model.md)'s Value-Object-heavy design —
`freezed` gives correct-by-construction immutability and value equality
for every VO in §14.4 without hand-written, error-prone `==`/`hashCode`/
`copyWith` boilerplate, and its exhaustive `when`/`map` on sealed unions
is exactly what makes the `Failure` hierarchy and every closed domain
status enum safe to extend without silently missing a case somewhere.

**Alternatives considered**: hand-written immutable classes with manual
equality/`copyWith` — rejected as tedious and error-prone at the scale of
[`14_Domain_Model.md`](14_Domain_Model.md)'s VO catalog, and a realistic
source of subtle equality bugs (a forgotten field in a hand-written
`==`); no code generation at all, avoiding `build_runner` overhead
entirely — rejected; the team-familiarity and safety benefits of
`freezed`/`riverpod_generator` are worth the build step at this project's
scale. `go_router_builder` (typed route code-gen) — considered and
explicitly **deferred**: start with hand-written `go_router` config
(§15.5) given the current route count is manageable without it; revisit
if the route surface grows large enough that manual typed parameters
become error-prone.

**Best practices**: run `build_runner` in **watch mode** during active
development for fast feedback; keep the `build_runner`/`freezed`/
`riverpod_generator` package versions pinned together and reviewed
alongside every Flutter/Dart SDK version bump (§15.1/§15.2), since
generator/SDK version mismatches are a common source of confusing build
failures.

**Common mistakes**: committing generated files and then hitting
merge conflicts *inside* generated code, which is both noisy and
pointless to resolve by hand; forgetting to re-run `build_runner` after
changing an annotated class, leading to a confusing runtime mismatch
between the hand-written source and stale generated code; reaching for
`freezed` on a trivial class where it adds more ceremony than value
(a single-field wrapper with no equality/copy needs may not be worth it
— judgment applies, this isn't a blanket rule for every class in the
codebase).

**Project standards**: generated files (`*.g.dart`, `*.freezed.dart`) are
**not committed** to the repository — they're `.gitignore`d and generated
as an explicit, required CI step before build/test (§15.24), keeping
diffs clean and avoiding generated-code merge conflicts entirely;
approved code-gen packages are exactly `freezed`, `riverpod_generator`,
and `json_serializable` (for the narrow Cloud-Function-payload case) —
`go_router_builder` is explicitly not adopted for now, per above.

---

## Appendix: quick-reference standards table

| # | Topic | Project standard in one line |
|---|---|---|
| 1 | Flutter | Latest stable, pinned via FVM, quarterly reviewed bumps |
| 2 | Dart | Bundled with Flutter; exhaustive `switch` required on sealed types |
| 3 | Firebase Services | Table in §15.3 is the exhaustive approved list |
| 4 | Riverpod | Code-gen (`@riverpod`), `autoDispose` default, `family` for ID-scoped state |
| 5 | GoRouter | Centralized config per app; `redirect` guards are UX only, not security |
| 6 | Auth | Phone OTP only; forced claims refresh on grant change |
| 7 | Firestore | No direct SDK use outside repositories; paginate everything |
| 8 | Cloud Functions | TypeScript, Functions v2, idempotent webhooks |
| 9 | Storage | Path mirrors Firestore; 5MB limit; client + rule-enforced validation |
| 10 | Messaging | Push + WhatsApp/SMS together for financial reminders, never push alone |
| 11 | Crashlytics | No PII in custom keys; crash-free-rate is a release gate |
| 12 | Analytics | Canonical taxonomy tied to PRD §2.8 metrics; no PII params |
| 13 | Remote Config | App-wide only, never per-tenant business config |
| 14 | Offline | Pending-state UX for check-in/payment/enrollment; bounded cache |
| 15 | Repository Pattern | One interface per Aggregate Root; no Firestore types leak out |
| 16 | DI | Riverpod only, no second DI framework |
| 17 | Error Handling | `Result`/`Failure` from every use case; closed Failure hierarchy |
| 18 | Logging | Structured shape everywhere; no PII, ever |
| 19 | Env Config | 3 Firebase projects, 3 flavors, gitignored per-env config |
| 20 | Folder Structure | Feature-first, layered within feature |
| 21 | Naming | Table in §15.21 is canonical |
| 22 | Code Style | `very_good_analysis`; zero warnings to merge |
| 23 | Testing | Unit-heavy; every BR-# has a test; emulator suite required in CI |
| 24 | CI/CD | Per-deployable pipelines; staging auto-deploy, production manual gate |
| 25 | Git Strategy | Trunk-based; short branches; flags over long branches |
| 26 | Security | Rules + app-layer checks always both; App Check enforced |
| 27 | Performance | NFR-5 is a hard budget, tested on real mid-range hardware |
| 28 | Index Strategy | `firestore.indexes.json` source-controlled, deployed via CI |
| 29 | State Management | 4-tier taxonomy; narrowest tier that fits |
| 30 | Code Generation | `freezed` + `riverpod_generator`; generated files never committed |
