# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Status: planning phase, docs-first

**No real application code exists yet.** `app/` is an unmodified `flutter create` scaffold
(default counter-app `lib/main.dart`, default `pubspec.yaml`). `design/app`, `design/backend`,
and `design/assets` are empty placeholders. The actual substance of this repository is in
`docs/` — do not start implementing Flutter screens, Cloud Functions, or the domain model
without first reading the relevant numbered doc, and confirm with the user before writing the
first real feature code, since the README states infra/mobile/backend code is intentionally
withheld until the docs are reviewed and approved.

## What this project is

StudyHall OS: a B2B2C SaaS platform for Indian Study Hall / Paid Reading Room owners
(seat/branch/staff/fee/attendance management for the **Owner**), with a companion experience
for **Students** to discover, join, pay for, and use a seat.

## Reading order for `docs/`

Each doc builds on the ones before it — read in numeric order when onboarding to a new part of
the system, or jump directly to the one relevant doc for a narrow task:

| Doc | Answers |
|---|---|
| `01_Product_Vision.md` | Why this exists, who it's for |
| `02_Product_Requirements_Document.md` | Full functional & non-functional requirements |
| `03_User_Personas.md` | Owner, Branch Manager/Receptionist, Student, Platform Admin |
| `04_User_Flows.md` | End-to-end journeys per persona |
| `05_Feature_List.md` | Feature catalog, module by module |
| `06_Database_Design.md` | Logical data model, entities, relationships |
| `07_Firestore_Schema.md` | Physical Firestore collections, documents, indexes, security rules |
| `08_System_Architecture.md` | Clean Architecture layering, services, tech stack, *why* |
| `09_UI_UX_Guidelines.md` | Design language, accessibility, localization |
| `10_Business_Rules.md` | Domain rules (BR-1..BR-29) that constrain every feature |
| `11_Subscription_Model.md` | Our pricing (Owner → Us) and billing mechanics |
| `12_MVP.md` | What ships first, and explicitly what does not |
| `13_Product_Roadmap.md` | Phased plan beyond MVP |
| `14_Domain_Model.md` | DDD model: entities, value objects, aggregates, invariants |
| `15_Technical_Architecture.md` | Engineering handbook: stack, conventions, testing, CI/CD, security — **single source of truth for implementation** |

`15_Technical_Architecture.md` is the one to consult before writing any code — it pins down
exact conventions (not just intent) and states explicit "Project standards" per topic.

## Architecture (from `08_System_Architecture.md` and `15_Technical_Architecture.md`)

**Four deployables, one backend:**
- **Owner/Staff app** — Flutter, Android+iOS. Serves both Owner (org-wide, all Branches) and
  Receptionist (locked to one Branch) roles in a single codebase — dense, speed-optimized,
  operational UI.
- **Student app** — Flutter, Android+iOS. Separate codebase from Owner/Staff (deliberate split,
  not role-based views in one app — see §8.3 for the reasoning). Light, consumer-grade UX.
- **Cloud Functions** — TypeScript, Node.js, Firebase Functions **v2** (not v1, not Dart).
  HTTPS callables, Firestore triggers, scheduled jobs (Cloud Scheduler + Pub/Sub).
- **Admin web console** — React/Next.js, internal-only, talks to admin-only callable functions.

Both Flutter apps and the Cloud Functions backend share the **same Clean Architecture layering**:

```
Presentation → Application/Use Cases → Domain → Infrastructure/Adapters
```

- **Domain**: entities, value objects (`Money`, `PhoneNumber`, `DateRange`), domain services —
  zero Firebase/Flutter imports.
- **Application**: one class per use case (`EnrollStudentUseCase`, `RecordPaymentUseCase`),
  depends only on repository/gateway *interfaces* it defines.
- **Infrastructure**: `Firestore{Aggregate}Repository`, `RazorpayPaymentGateway`, etc. — the
  only layer allowed to import `cloud_firestore`, `razorpay_flutter`, or any vendor SDK.
- **Presentation**: Flutter widgets/Notifiers, or thin Cloud Function handler shims (validate
  input → resolve caller authority → invoke exactly one use case → map result).

**Branch isolation is enforced twice, deliberately, never assumed covered by the other layer:**
Firestore security rules protect direct client access; every Cloud Function handler explicitly
re-derives the caller's `orgAccess` claim and checks it against the target
`organizationId`/`branchId` before invoking a use case, because Admin SDK calls bypass Firestore
rules entirely. Every Branch-scoped repository method takes `organizationId`/`branchId` as
required leading parameters (never optional filters) — this is a compile-time constraint, not a
runtime habit.

**Repository Pattern**: one repository interface **per Aggregate Root** (`OrganizationRepository`,
`BranchRepository`, `SeatRepository`, `StudentRepository`, `EnrollmentRepository`,
`FeeCycleRepository`, `AttendanceRepository`, ... — see §15.15 for the full list), never one per
Firestore collection. Notably **no `PaymentRepository`** — Payment is a child entity accessed only
through `FeeCycleRepository`.

**State/DI**: Riverpod is both the state management and dependency-injection mechanism (no
second DI framework). Code-gen (`@riverpod`), `autoDispose` by default, `family` for ID-scoped
state. Four state tiers (ephemeral UI → screen state → shared session state → server-synced
Firestore-stream state) — always use the narrowest tier that fits; see §15.29.

**Error handling**: every Application-layer use case returns a `Result`-shaped
(`Success`/`Failure`) type, never a thrown raw exception reaching Presentation. Closed `Failure`
hierarchy: `NetworkFailure`, `ValidationFailure`, `PermissionFailure`, `ConflictFailure`,
`NotFoundFailure`.

**Concurrency**: Firestore transactions guard every cross-aggregate invariant (the
Seat-Availability lock-document pattern in `07_Firestore_Schema.md` §7.5 is the canonical example
— reuse this pattern for new invariants, don't invent a new concurrency strategy per feature).
Denormalized per-Branch rollup documents (not per-Org or platform-wide) back dashboard tiles,
maintained by triggers, because of Firestore's ~1 write/sec/document limit.

**Payments**: Razorpay. Payment confirmation is only ever trusted from a signature-verified
webhook → Cloud Function → `RecordPaymentUseCase`, never from client-reported success.

**Folder structure**: feature-first, layered within each feature (mirrors the Aggregate map in
`14_Domain_Model.md` §14.5), not a top-level domain/application/infrastructure split:

```
lib/
  core/            (shared VOs, Result/Failure, session/auth-context, go_router shell config)
  features/
    organization/
      domain/  application/  infrastructure/  presentation/
    branch/  seat/  enrollment/  fee_cycle/  attendance/  ...
```

Features depend on `core`, never reach into another feature's internals directly — cross-feature
data access goes through that feature's public repository interface.

## Key conventions (full table in `15_Technical_Architecture.md` §15.21)

| Concept | Convention | Example |
|---|---|---|
| Repository interfaces | `{Aggregate}Repository` | `StudentRepository` |
| Repository implementations | `Firestore{Aggregate}Repository` | `FirestoreStudentRepository` |
| Use cases | `{Verb}{Noun}UseCase` | `RecordPaymentUseCase` |
| Riverpod Notifiers | `{Feature}Notifier` | `EnrollmentNotifier` |
| Riverpod providers | `{feature}Provider` | `enrollmentProvider` |
| Screens | `{Feature}Screen` | `SeatMapScreen` |
| Failure types | `{Reason}Failure` | `ConflictFailure` |
| Firestore collections | plural camelCase | `enrollments`, `feeCycles` |
| Cloud Functions | `verbNoun` | `enrollStudent`, `recordPayment` |

Generated files (`*.g.dart`, `*.freezed.dart`) are **never committed** — `.gitignore`d, generated
as a required CI step. Approved codegen packages: `freezed`, `riverpod_generator`,
`json_serializable` only.

## Non-negotiables worth knowing before touching any future code here

- **No direct Firestore SDK use outside a repository implementation** — no widget or Notifier
  ever imports `cloud_firestore` directly.
- **No PII in logs, Crashlytics custom keys, or Analytics params** — no phone numbers, names, or
  ID document references, ever, on client or server.
- **Every fee/dues notification goes out via both FCM and WhatsApp/SMS** — push alone for
  anything financially consequential is treated as a bug, not an MVP shortcut.
- **A `go_router` `redirect` guard is UX only, never the security boundary** — real enforcement
  is Firestore rules + the Cloud Function `orgAccess` check.
- Testing is unit-test-heavy: every rule in `10_Business_Rules.md` (BR-#) must have a unit test
  referencing its BR-# in the description; the Firebase emulator suite is reserved for what
  genuinely needs Firestore/Auth semantics (transactions, security rules), never as a substitute
  for a fast fake-repository unit test.

## Commands

None yet — no build tooling, CI, or test suite exists in this repo. Once implementation starts,
per `15_Technical_Architecture.md` §15.22–24: `dart format --set-exit-if-changed` and
`flutter analyze` (zero warnings) are required, blocking checks; `flutter test` covers unit/
widget/golden tests; a Firebase-emulator-backed integration suite covers transactions and
security rules; all local dev and CI target the emulator suite exclusively, never a real
Firebase project.
