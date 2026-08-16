# StudyHall OS

**The operating system for Study Hall / Paid Reading Room businesses in India.**

> Working product name. Branding is not yet finalized — see [`docs/01_Product_Vision.md`](docs/01_Product_Vision.md).

## What this is

StudyHall OS is a B2B2C SaaS platform for the owners of Study Halls (also known as
Paid Reading Rooms, PRRs, or libraries) — commercial spaces where students rent a
seat, by shift or full-day, to study for competitive exams (UPSC, SSC, banking,
JEE/NEET, state PCS, and others). This is a large, fragmented, cash-and-notebook-run
market across India, concentrated in exam-prep hubs like Kota, Delhi/NCR, Patna,
Prayagraj, Indore, Jaipur, Lucknow, and Bangalore.

We sell software to the **Owner** (branch/seat/staff/fee/attendance management).
The Owner's **Students** use a companion experience to discover, join, pay for,
and use their seat. See [`docs/03_User_Personas.md`](docs/03_User_Personas.md)
for the full breakdown of who uses what.

## Status

**Planning phase.** No application code exists yet. This repository currently
contains only product and architecture documentation. Flutter/mobile code,
backend services, and infrastructure will not be created until the docs below
are reviewed and approved.

## Repository structure

```
docs/                           Product, architecture, and business documentation
  01_Product_Vision.md          Why this exists, who it's for, what "winning" looks like
  02_Product_Requirements_Document.md   Full functional & non-functional requirements
  03_User_Personas.md           Owner, Branch Manager, Student, Platform Admin
  04_User_Flows.md              End-to-end journeys for each persona
  05_Feature_List.md            Complete feature catalog, module by module
  06_Database_Design.md         Logical data model, entities, relationships
  07_Firestore_Schema.md        Physical Firestore collections, documents, indexes, rules
  08_System_Architecture.md     Clean Architecture layering, services, tech stack
  09_UI_UX_Guidelines.md        Design language, accessibility, localization
  10_Business_Rules.md          Domain rules that constrain every feature
  11_Subscription_Model.md      Our pricing (Owner → Us) and billing mechanics
  12_MVP.md                     What ships first, and explicitly what does not
  13_Product_Roadmap.md         Phased plan beyond MVP
  14_Domain_Model.md            DDD domain model: entities, value objects, aggregates, invariants
  15_Technical_Architecture.md  Engineering handbook: stack, conventions, testing, CI/CD, security

design/                         Design artifacts (Figma exports, diagrams, tokens)
  app/                           Mobile/web app UI design assets
  backend/                       Architecture & infra diagrams
  assets/                        Shared brand assets (logos, icons, illustrations)
```

## Guiding principles

- **No demo or placeholder code, ever.** Every line shipped is production-intended.
- **Clean Architecture.** Domain logic is persistence- and framework-agnostic;
  Firestore, Flutter, and third-party APIs are swappable infrastructure details.
- **SOLID.** Every module has one reason to change.
- **Design for thousands of tenants from day one**, even though the MVP scope
  is deliberately narrow. Multi-tenancy, data isolation, and horizontal scaling
  are architectural defaults, not later refactors.

## Reading order

If you're reviewing this for the first time, read in numeric order — each doc
builds on the decisions made in the ones before it. Start with
[`01_Product_Vision.md`](docs/01_Product_Vision.md).
