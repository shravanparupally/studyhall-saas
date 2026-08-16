# 03. User Personas

Four personas cover every user type in the system. Two are Organization-side
(Owner, Receptionist), one is the end customer (Student), and one is
internal to us (Platform Admin). Every feature and flow in this repo should be
traceable to at least one of these.

---

## 3.1 Owner — "Rajeev, 38, runs 2 Study Hall branches in Prayagraj"

**Role in system**: Organization super-admin. The Platform Subscription payer.

**Background**: Rajeev started one Study Hall five years ago in a building
near a coaching institute cluster, renting out 60 seats. It did well enough
that he opened a second branch two years later. He is not a software person
— he ran both branches on a physical register and a shared WhatsApp group
per branch for two years, then moved to an Excel sheet a relative set up for
him, which he now maintains inconsistently.

**Goals**:
- Know, without asking anyone, how many seats are free right now and how
  much money is owed to him this month.
- Stop losing money to students who "forgot" to pay and he forgot to chase.
- Spend less time doing the books at night and more time on the business.
- Eventually open a third branch, and not have that mean re-learning his
  own tools.

**Pain points today**:
- Excel breaks when his brother-in-law (who helps at Branch 2) edits the
  wrong row.
- He finds out a seat has been empty for three weeks only when a walk-in
  asks and he has to physically check.
- Fee reminders are manual WhatsApp messages he sends when he remembers.
- No way to compare Branch 1 vs Branch 2 performance without redoing the
  Excel sheet by hand.

**Tech comfort**: Comfortable with WhatsApp, UPI apps (PhonePe/GPay), and
basic Android usage. Not comfortable with anything that feels like "enterprise
software" — jargon, multi-step configuration, or anything requiring a laptop
to operate day-to-day. **Primary device: Android phone.** Will use a
desktop/laptop occasionally for reports, if available, but it cannot be
required for daily operation.

**What he needs from the product**: Radical simplicity in the common path
(seat map, who owes money, mark payment received), with power underneath for
when he wants it (multi-branch comparison, exports). Trust is earned by the
numbers being right, every time, without him double-checking against his old
notebook for the first few months.

**Represented in**: FR-1, FR-2, FR-3, FR-5, FR-8, FR-11 in the
[PRD](02_Product_Requirements_Document.md).

---

## 3.2 Receptionist — "Sunita, 26, front-desk receptionist at Rajeev's Branch 2"

**Role in system**: Receptionist — one of exactly two default roles
(alongside Owner). Assigned to exactly one Branch at a time. No billing/
subscription access, and structurally no ability to read or act on any
other Branch's data, including other Branches within the same
Organization — see [`06_Database_Design.md`](06_Database_Design.md) §6.6
for why this is enforced as a hard boundary, not a configurable default.

**Background**: Sunita runs the front desk: she checks students in, handles
walk-in enquiries, collects cash payments when students don't pay online, and
fields "is seat A-12 free" questions all day. She did not choose this
software — Rajeev did — and she will judge it entirely on whether it makes
her job faster or slower during a busy morning check-in rush.

**Goals**:
- Check a student in/mark a cash payment in under 10 seconds, without
  hunting through menus, while a queue is forming.
- Know instantly which seats are free when a walk-in asks.
- Not be blamed for a billing/seat mistake that the software's confusing
  UI caused.

**Pain points today**: Handwritten registers get illegible or lost. She has
no independent way to double check what Rajeev's Excel says versus what she
observes in the room.

**Tech comfort**: Similar to Rajeev — comfortable with everyday consumer
apps, no patience for anything that requires training to use. **Primary
device: the Branch's shared Android tablet/phone at the front desk.**

**What she needs from the product**: A front-desk-optimized, low-friction
flow above everything else — seat map, check-in, record-cash-payment are the
three actions she needs to be nearly instant. Anything that requires more
than 2-3 taps for these core actions will get abandoned in favor of going
back to paper during a rush.

**Represented in**: FR-1.4, FR-4, FR-5.2, FR-6, FR-7 in the [PRD](02_Product_Requirements_Document.md).

---

## 3.3 Student / Member — "Ananya, 22, moved to Prayagraj to prepare for the UPSC prelims"

**Role in system**: End customer of the Study Hall (the Organization's
customer, not ours directly — but a first-class user of the platform).

**Background**: Ananya moved from a smaller town to Prayagraj six months ago
specifically to be near coaching institutes and study halls. She does not
know the city. She found her current study hall by walking past three of
them and asking at each. She pays her monthly fee in cash because that's how
she was onboarded, and once forgot to renew for four days because no one
reminded her, losing her seat to someone else in that window.

**Goals**:
- Find a good, quiet, reasonably priced seat near her without needing local
  knowledge or word of mouth.
- Never lose her seat or get blindsided by a due date she didn't know about.
- Pay easily (she already pays for everything else via UPI) and have proof
  of payment without asking for a handwritten receipt.
- Know her attendance/study consistency is being tracked, without it
  feeling like surveillance — some students find this motivating.

**Pain points today**: No visibility into which study halls near her have
open seats before physically visiting. No reminder system for her own dues.
No easy way to see her own attendance pattern. If she wants a different
shift than her current one, she has to negotiate with the owner in person.

**Tech comfort**: High. She is a smartphone-native user (this generation of
exam aspirants is extremely online), comfortable with UPI, and expects
consumer-app-grade UX — she will compare this app, consciously or not, to
Swiggy/PhonePe/Instagram, not to "SaaS software."

**Primary device**: Android phone, budget-to-mid-range.

**What she needs from the product**: A consumer-grade experience, not an
enterprise one — this is the persona most likely to be disappointed by
anything that feels like "business software." Discovery (Phase 2), painless
payment, and reliable reminders are her core value.

**Represented in**: FR-4, FR-5, FR-6, FR-9, FR-10 in the [PRD](02_Product_Requirements_Document.md).

---

## 3.4 Platform Admin — "Our own Ops/Support team member"

**Role in system**: Internal, cross-tenant operator. Not exposed to Owners
or Students. Operates the platform itself.

**Background**: This persona represents our own team (support, billing ops,
and — once discovery ships — content moderation for Branch listings and
reviews). They are the one role in the system with legitimate cross-Organization
visibility, and therefore the role whose access must be the most tightly
controlled and audited.

**Goals**:
- Diagnose and resolve an Owner's support ticket (e.g. "my fee report looks
  wrong") without needing raw database access.
- Manage an Organization's Platform Subscription state (plan changes,
  trial extensions, suspensions for non-payment) without touching Organization
  operational data (seats, students, attendance).
- Once discovery ships: moderate flagged listings/reviews.

**Pain points this persona must never cause**: Accidental cross-tenant data
exposure. Any Platform Admin action against Organization data must be scoped,
role-gated, and logged — an internal tool built carelessly here is the
single biggest trust and compliance risk in the whole system (see NFR-1 and
NFR-9 in the [PRD](02_Product_Requirements_Document.md)).

**Tech comfort**: High — internal power-user tooling is acceptable here in
a way it is not for Owner/Student personas. Desktop-first.

**Represented in**: FR-11 in the [PRD](02_Product_Requirements_Document.md);
drives the security model in [`08_System_Architecture.md`](08_System_Architecture.md).

---

## 3.5 Persona summary table

| Persona | Pays us? | Primary device | Tolerance for complexity | Core need | Branch access |
|---|---|---|---|---|---|
| Owner | Yes (Platform Subscription) | Android phone | Very low | Trustworthy numbers, minimal effort | Every Branch in their Organization |
| Receptionist | No | Shared front-desk Android device | Very low, speed-critical | Sub-10-second check-in/payment recording | Exactly one assigned Branch |
| Student | No (pays the Owner) | Android phone | Low, consumer-grade expectations | Discovery, painless payment, reminders | N/A — belongs to one Branch's roster |
| Platform Admin | No (internal) | Desktop | High | Safe, scoped, audited cross-tenant tooling | Cross-Organization, action-scoped only |
