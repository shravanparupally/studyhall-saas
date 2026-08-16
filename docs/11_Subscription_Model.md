# 11. Subscription Model

This is **our** pricing: what the Organization (Study Hall Owner) pays us
for the Platform Subscription (see [`02_Product_Requirements_Document.md`](02_Product_Requirements_Document.md)
§2.2 for the Platform Subscription vs. Membership Plan distinction — this
document never discusses what Students pay Owners). Fields referenced below
(`seatLimit`, `branchLimit`, `staffLimit`, `messagingCreditsRemaining`) map
directly onto `/platformSubscriptions/{organizationId}` in
[`07_Firestore_Schema.md`](07_Firestore_Schema.md).

## 11.1 Pricing philosophy

Owners think in **seats and branches**, not in abstract SaaS units like
"API calls" or "users" — a Study Hall owner knows exactly how many seats
they operate, because that's their entire physical inventory. Pricing tiers
are therefore structured around seat and branch count, which makes the
value proposition self-evident at signup ("your 60-seat branch fits the
Growth tier") rather than requiring the Owner to guess which abstract tier
applies to them.

**`branchLimit` is a commercial lever, not an architectural one.** Every
Organization, including a single-Branch Starter customer, runs on the same
fully Branch-isolated data model (see
[`06_Database_Design.md`](06_Database_Design.md) §6.6 and
[`10_Business_Rules.md`](10_Business_Rules.md) BR-25) — there is no
"simplified single-branch mode" that a customer graduates out of. Tier
limits only gate *how many* Branches an Organization is billed for, the
same way `seatLimit` gates seat count; they never gate whether Branch
isolation itself is present.

Consistent with the vision ([`01_Product_Vision.md`](01_Product_Vision.md)
§1.6): we are a flat-fee vertical SaaS, not a payments company taking a cut
of Student fees. This keeps the pitch to a skeptical, non-technical Owner
simple and trustworthy ("you pay us one predictable monthly amount"), and
avoids the compliance/settlement complexity of being in the Student payment
flow ourselves (see [`08_System_Architecture.md`](08_System_Architecture.md)
§8.8). A revenue-share model is explicitly not ruled out forever — Razorpay
Route makes it technically feasible later — but it is not the MVP or
Phase 1 model.

## 11.2 Tiers

| Tier | Seats (`seatLimit`) | Branches (`branchLimit`) | Staff accounts (`staffLimit`) | Messaging credits/mo | Indicative price (monthly billing) |
|---|---|---|---|---|---|
| **Starter** | Up to 50 | 1 | 2 (Owner + 1) | 200 | ₹999/month |
| **Growth** | Up to 150 | Up to 2 | 5 | 750 | ₹2,499/month |
| **Pro** | Up to 500 | Up to 5 | 15 | 2,500 | ₹4,999/month |
| **Enterprise** | Unlimited | Unlimited | Unlimited | Custom | Custom (sales-assisted) |

Prices are **indicative starting points for planning**, not final —
finalized pricing requires market testing during MVP rollout (see
[`12_MVP.md`](12_MVP.md)) and is out of scope for this document to lock in
prematurely. What *is* being decided here is the **shape** of the model
(seat/branch-tiered, flat monthly fee, messaging credits as the
usage-sensitive dimension) — that shape is a real product/architecture
decision (it's what `platformSubscriptions` fields exist to enforce, per
BR-26) and should hold even as the numbers are tuned.

Annual billing: discounted relative to monthly (indicative: ~2 months free,
i.e. ~17% off), reflecting standard SaaS practice and improving our own
cash-flow predictability — offered as a toggle at checkout, never the only
option, since a cash-conscious small-business Owner needs the monthly
option to exist.

## 11.3 What differs across tiers beyond limits

Not just quotas — some capabilities are tier-gated because they only make
sense (and only justify their engineering cost) once an Owner has outgrown
Starter:

| Capability | Starter | Growth | Pro | Enterprise |
|---|---|---|---|---|
| Core seat/shift/fee/attendance management | ✓ | ✓ | ✓ | ✓ |
| Automated WhatsApp/SMS reminders | ✓ | ✓ | ✓ | ✓ |
| Online (UPI/card) payment collection | ✓ | ✓ | ✓ | ✓ |
| Organization-level multi-branch roll-up dashboard | — | ✓ | ✓ | ✓ |
| Custom roles (beyond default Owner/Receptionist) | — | — | ✓ | ✓ |
| Priority support | — | — | ✓ | ✓ |
| API access *(P3)* | — | — | — | ✓ |
| White-label branding *(P3)* | — | — | — | ✓ |

## 11.4 Free trial

A 14-day, full-feature trial (mapped to `status: "trialing"` in
[`07_Firestore_Schema.md`](07_Firestore_Schema.md)) at Growth-tier limits,
**no payment method required to start** — this is a deliberate choice for
this specific customer: a Study Hall Owner deciding whether to trust a new
system with their fee collection is not going to hand over a card number
before they've seen a seat map they believe. Friction at signup directly
works against PRD §2.8's activation metric.

At trial expiry with no plan selected: the Organization moves to a
restricted, **not suspended**, state — read access to everything they've
entered remains, but new Enrollments/Payments require selecting a paid
tier first. This is distinct from BR-27's non-payment suspension (which
implies an existing paid relationship lapsing); trial expiry is a
"decide now" prompt, not a penalty.

## 11.5 Upgrades, downgrades, and limit enforcement

- Upgrades take effect immediately, prorated for the remainder of the
  current billing period.
- Downgrades take effect at the next billing cycle boundary, and are
  **blocked at confirmation time** (not silently accepted and then broken)
  if the Organization currently exceeds the target tier's limits — e.g. an
  Organization with 3 Branches cannot downgrade to Starter (1 Branch) until
  they've consolidated, and the UI explains exactly what's blocking it.
  This is the enforcement-at-write-time principle from BR-26 applied to the
  subscription change itself, not just to day-to-day Seat/Branch creation.

## 11.6 Add-ons

Available independent of tier, for Organizations close to but not wanting a
full tier jump:

- **Extra messaging credit packs** (WhatsApp/SMS) — the most likely
  overage, since reminder volume scales with active Student count, not
  seat count, and a high-turnover Branch may need more messaging headroom
  than its seat tier implies.
- **Extra Branch** beyond tier limit, for an Owner who's opened one more
  location than their tier covers but isn't ready for a full tier jump.
- **Extra Staff account** beyond tier limit.

## 11.7 Non-payment handling

Governed by BR-27: a `past_due` Subscription triggers escalating
reminders to the Owner (not the Students — this is entirely an Owner-facing
billing relationship) over a defined dunning window before moving to
`suspended`. Suspension is read-only, never data-destructive, per the
business-continuity guarantee in BR-27 — a small business's operational
records are never used as leverage.

## 11.8 Early-adopter considerations

Not a pricing tier, but worth recording as a go-to-market input to this
model rather than losing it to a Slack thread later: early Organizations
(first cohort in each launch city) are a reasonable candidate for
locked-in preferential pricing as a reward for adoption risk and as a
referral-driving mechanism — consistent with the two-sided network logic in
[`01_Product_Vision.md`](01_Product_Vision.md) §1.5, where early owner
density in a city is what makes Phase 2 discovery valuable at all. This is
a pricing/GTM decision to finalize alongside MVP launch planning, not an
architectural one — the `planTier`/`billingCycle` fields in
[`07_Firestore_Schema.md`](07_Firestore_Schema.md) already support
per-Organization overrides without any schema change.
