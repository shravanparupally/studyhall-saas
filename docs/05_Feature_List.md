# 05. Feature List

Complete feature catalog, organized by module. This is the full-vision list;
each feature is tagged with its target phase so scope is unambiguous:

- **MVP** — in [`12_MVP.md`](12_MVP.md)
- **P1** — Phase 1 (first post-MVP growth phase)
- **P2** — Phase 2 (discovery/marketplace phase)
- **P3** — Phase 3+ (scale/expansion)

See [`13_Product_Roadmap.md`](13_Product_Roadmap.md) for what these phases mean.

## 5.1 Organization & Branch Management

| Feature | Phase |
|---|---|
| Self-serve Organization signup (phone OTP) | MVP |
| Single Branch setup (address, hours, contact) | MVP |
| Multiple Branches per Organization | MVP |
| Branch operating-hours & holiday calendar | MVP |
| Organization-level roll-up dashboard across Branches | P1 |
| Branch cloning (copy Shifts/Plans/Seat layout to a new Branch) | P1 |
| Branch-level custom branding (logo, receipt header) | P1 |

## 5.2 Seat & Layout Management

| Feature | Phase |
|---|---|
| Seat creation (single & bulk) with label, zone, type, locker flag | MVP |
| Visual seat map with real-time per-shift occupancy | MVP |
| Seat deactivation (maintenance) without losing history | MVP |
| Seat types (AC/Non-AC, Cabin/Open, With/Without Locker) | MVP |
| Drag-and-drop visual floor-plan editor | P1 |
| Seat-level idle-time alerts (flag seats unused N+ days) | P1 |
| QR code per seat for student self-check-in at the seat | P2 |

## 5.3 Shift & Membership Plan Management

| Feature | Phase |
|---|---|
| Branch-defined Shifts (name, time window, active days) | MVP |
| Membership Plans (Shift × Seat Type × Duration × Price) | MVP |
| Plan activation/deactivation without affecting existing Enrollments | MVP |
| Mid-cycle plan upgrade/downgrade with proration | P1 |
| Seasonal/promotional pricing (time-boxed plan pricing) | P1 |
| Coupon & discount codes | P1 |

## 5.4 Student Enrollment & Onboarding

| Feature | Phase |
|---|---|
| Staff-assisted walk-in enrollment | MVP |
| Student identity capture (name, phone, photo, ID doc) | MVP |
| Platform-level Student identity (portable across Branches/Organizations) | MVP |
| Seat assignment (specific or auto-assign) with double-booking prevention | MVP |
| Student self-registration (pre-register online, staff finalizes in person) | P1 |
| Fully self-service online enrollment (no staff step) | P1 |
| Waitlist when a Branch/Shift is fully booked | P1 |
| Shift-change / seat-change requests | P1 |
| Referral program (student refers student) | P2 |

## 5.5 Fee & Payment Management

| Feature | Phase |
|---|---|
| Auto-generated fee schedule from Plan billing cycle | MVP |
| Manual/cash payment recording by staff | MVP |
| Online payment via payment gateway (UPI-first) | MVP |
| Outstanding dues tracking per Student and per Branch | MVP |
| Automated fee-due reminders (push/SMS/WhatsApp) | MVP |
| Digital receipts (auto-generated, shareable) | MVP |
| Overdue/at-risk Enrollment flagging | MVP |
| Bulk reminder broadcast to all overdue Students | MVP |
| Partial payments / installment support | P1 |
| Owner-side revenue reports (daily/monthly/custom range) | MVP |
| Refund recording & tracking | P1 |
| Locker fee as a separate line item | P1 |
| Security deposit tracking (collected/refunded) | P1 |
| Auto-reconciliation with payment gateway settlement reports | P1 |

## 5.6 Attendance Management

| Feature | Phase |
|---|---|
| QR-code check-in/out (staff-scanned) | MVP |
| Attendance history per Student and per Seat | MVP |
| No-show / low-utilization reporting | MVP |
| Student self-check-in (scan Branch/seat QR with own phone) | P1 |
| Geofenced check-in (auto-detect arrival within Branch radius) | P1 |
| Biometric device integration (for Branches that already own hardware) | P2 |
| Attendance streaks / study-consistency stats for Students | P1 |

## 5.7 Staff & Access Control

| Feature | Phase |
|---|---|
| Staff invite & role assignment (Owner, Receptionist) | MVP |
| Branch-scoped permissions (Receptionist: exactly one Branch; Owner: every Branch) | MVP |
| Server-side permission enforcement on every write | MVP |
| Custom roles with granular permission toggles | P1 |
| Staff activity log (who did what, when) | MVP |
| Staff shift scheduling / attendance (staff's own attendance) | P2 |

## 5.8 Reporting & Analytics

| Feature | Phase |
|---|---|
| Occupancy %, revenue, overdue-total dashboard tiles | MVP |
| CSV export of core reports | MVP |
| Branch-vs-Branch comparison dashboard | P1 |
| Student churn / retention analytics | P1 |
| Revenue forecasting (based on active Enrollment expiry dates) | P1 |
| Cohort analysis (e.g. by acquisition month, by Plan type) | P2 |
| Custom report builder | P3 |

## 5.9 Expense Tracking

| Feature | Phase |
|---|---|
| Manual expense entry (rent, electricity, staff salary, maintenance) | P1 |
| Expense categorization & monthly summary | P1 |
| Branch P&L view (revenue − expenses) | P1 |
| Recurring expense templates | P2 |

## 5.10 Communication

| Feature | Phase |
|---|---|
| Automated lifecycle messages (welcome, due, paid, expiry warning) | MVP |
| Manual broadcast announcements (all / filtered Students) | MVP |
| WhatsApp Business API integration | MVP |
| SMS fallback channel | MVP |
| In-app push notifications | MVP |
| Two-way chat/support between Student and Branch | P2 |

## 5.11 Student-Facing Experience

| Feature | Phase |
|---|---|
| Student dashboard (dues, attendance, receipts, announcements) | MVP |
| In-app payment | MVP |
| Digital membership card / QR for check-in | MVP |
| Public discovery portal (search/browse Study Halls by city) | P2 |
| Seat availability preview before visiting in person | P2 |
| Ratings & reviews | P2 |
| Map-based Branch search with filters | P2 |
| In-app trial-visit booking | P2 |

## 5.12 Locker Management

| Feature | Phase |
|---|---|
| Locker inventory tied to Seats/Branch | P1 |
| Locker assignment & release as part of Enrollment lifecycle | P1 |
| Locker-specific fee | P1 |

## 5.13 Platform & Billing (us ↔ Organization)

| Feature | Phase |
|---|---|
| Platform Subscription tiers, gated feature/usage limits | MVP |
| Free trial period | MVP |
| Self-serve plan upgrade/downgrade | MVP |
| Usage-based add-ons (extra messaging credits, extra seats) | P1 |
| Internal Platform Admin console (support, subscription ops) | MVP (minimal) → P1 (full) |
| Append-only audit trail for all financial events | MVP |
| Automated dunning for Organization's own Platform Subscription non-payment | P1 |

## 5.14 Platform-Wide / Cross-Cutting

| Feature | Phase |
|---|---|
| Multi-tenant data isolation (architectural, always-on) | MVP |
| Offline-tolerant check-in & seat-map sync | MVP |
| Multi-language UI (English/Hindi at minimum) | P1 |
| Audit logging for all sensitive mutations | MVP |
| Data export / account deletion (privacy compliance) | P1 |
| API access for Organizations (integrate with their own tools) | P3 |
| White-label option for large franchise Organizations | P3 |
