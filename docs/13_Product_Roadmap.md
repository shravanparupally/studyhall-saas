# 13. Product Roadmap

Phased plan beyond [`12_MVP.md`](12_MVP.md). Phases are defined by **what
must be true before the next one starts**, not by calendar dates — this
repo is a planning artifact, and hard-coding dates here would make it stale
on arrival. Feature-to-phase mapping is the source of truth in
[`05_Feature_List.md`](05_Feature_List.md); this document explains the
sequencing logic.

## 13.1 Phase 0 — MVP

Covered fully in [`12_MVP.md`](12_MVP.md). Single-Branch operational core:
seats, shifts, plans, enrollment, attendance, fees, payments, reminders,
Owner dashboard, Student dashboard. Gate to exit this phase: MVP success
criteria (§12.5) met with a real pilot cohort, not a demo.

## 13.2 Phase 1 — Growth (operational depth + multi-branch)

**Entry condition**: MVP has proven Owners trust the core numbers and the
fee-collection value proposition holds in practice.

**Focus**: deepen the operational toolset for Owners who are actively
running their business on the platform, and support the natural next step
for a successful pilot Owner — opening or onboarding a second Branch.

Includes (see [`05_Feature_List.md`](05_Feature_List.md) for the full P1
list): Organization-level multi-branch roll-up dashboard, Branch cloning,
fully self-service Student enrollment, waitlist management, locker
management as a tracked entity, partial payments/installments, mid-cycle
plan proration (BR-8), coupons, expense tracking and Branch P&L,
Branch-vs-Branch analytics, custom roles, multi-language UI (Hindi first),
the fuller internal Platform Admin console, and shift/seat-change requests
for Students.

**Why multi-branch depth before discovery**: an Owner who's proven the
model at one Branch and is opening a second is the highest-confidence,
lowest-risk growth surface available — they already trust us. Chasing the
discovery/marketplace opportunity before this is solid risks distracting
from the customers who are actually paying and expanding today.

## 13.3 Phase 2 — Discovery (the two-sided network)

**Entry condition**: sufficient Owner density in at least one launch city
that a Student searching "study hall near me" would find a genuinely useful
set of real options — not a directory with three listings. This is a
supply-density gate, not a time-based one; shipping discovery before this
condition holds produces a marketplace nobody uses, which is explicitly
called out as a mistake to avoid in
[`01_Product_Vision.md`](01_Product_Vision.md) §1.6.

**Focus**: turn platform density into a demand-generation channel for every
Owner on it, closing the loop described in the vision doc's §1.4-1.5.

Includes: public discovery portal (web, SEO-oriented — see the Next.js
surface in [`08_System_Architecture.md`](08_System_Architecture.md) §8.2),
map-based search with filters (shift type, AC/Non-AC, price, distance),
seat availability preview pre-visit, ratings & reviews (with moderation
tooling for Platform Admin), in-app trial-visit booking, referral programs,
lead tracking from portal to conversion, QR-per-seat self-check-in, and
geofenced/biometric attendance options for Branches that want them.

**Why this is a genuinely separate phase, architecturally**: this is the
first phase where the platform has a direct relationship with Students as
an audience in their own right (not just as an Owner's customer passing
through our software) — it introduces public-facing content moderation,
SEO/marketing-site concerns, and a "Lead" concept that doesn't exist before
this point. The `Lead`/`Review` collections are reserved but deliberately
unspecified in [`07_Firestore_Schema.md`](07_Firestore_Schema.md) §7.2 for
exactly this reason — they get designed against real discovery-flow
requirements when this phase actually starts, not guessed at now.

## 13.4 Phase 3 — Scale & expansion

**Entry condition**: Phase 2's network effects are validated (discovery
measurably drives Owner-side conversions/retention) and the business is
operating at a scale where enterprise/franchise customers and platform
extensibility become worth building for.

**Focus**: capture the largest and most sophisticated customers, and open
the platform up.

Includes: API access for Organizations to integrate their own tools,
white-label offering for large multi-city franchise Organizations, a
custom report builder, cohort/advanced analytics, and — architecturally —
the BigQuery export pipeline flagged in
[`08_System_Architecture.md`](08_System_Architecture.md) §8.13 for
cross-tenant analytics workloads Firestore was never meant to serve
directly.

This phase is also where the flat-fee-only pricing philosophy in
[`11_Subscription_Model.md`](11_Subscription_Model.md) §11.1 gets
revisited on purpose, if warranted — Razorpay Route's split-settlement
capability is a real option for a revenue-share model at Enterprise tier
once the relationship with large franchise Owners is mature enough for that
conversation, not before.

## 13.5 What doesn't have a phase yet, on purpose

Category expansion (coaching institutes, student housing/PG, generic
co-working) is named as long-term optionality in
[`01_Product_Vision.md`](01_Product_Vision.md) §1.5 but intentionally has
no phase assignment here. Assigning it a phase now, before the core Study
Hall vertical is proven at scale, would be planning theater — it gets
scoped for real once Phase 2/3 density and retention data exist to justify
the adjacency thesis, not before.

## 13.6 Sequencing summary

```
Phase 0 (MVP)        Phase 1 (Growth)         Phase 2 (Discovery)        Phase 3 (Scale)
Single-branch    →   Multi-branch depth   →   Two-sided network      →   Enterprise/API/
operational core     + Owner power tools      (public portal,             white-label +
proves trust          for existing Owners     ratings, self-serve         analytics warehouse
                                               discovery)

Gate: MVP success    Gate: Owners actively    Gate: real Owner         Gate: Phase 2 network
criteria met (§12.5) expanding branches on    density per launch       effects validated
                      the platform             city
```

Each gate is a **decision point to re-review this roadmap**, not an
automatic trigger — the right move at each boundary is to revisit
[`01_Product_Vision.md`](01_Product_Vision.md) and this document against
what was actually learned, not to execute the plan as originally written
regardless of evidence.
