# Product Backlog

Status Legend:
- [ ] Not Started
- [~] In Progress
- [x] Done

---

## Infrastructure & Setup

| ID | Feature | Status | Priority |
|----|---------|--------|----------|
| INF-01 | Supabase project setup | [x] | High |
| INF-02 | Database schema creation | [x] | High |
| INF-03 | Flutter project initialization | [x] | High |
| INF-04 | Google Maps API integration | [x] | High |
| INF-05 | PayMongo/Xendit integration | [ ] | High |
| INF-06 | Resend email setup | [ ] | Medium |
| INF-07 | Authentication flow (Supabase Auth) | [x] | High |

---

## Database Tables

| ID | Feature | Status | Priority |
|----|---------|--------|----------|
| DB-01 | users table | [x] | High |
| DB-02 | vehicles table | [x] | High |
| DB-03 | bookings table | [x] | High |
| DB-04 | payments table | [x] | High |
| DB-05 | availability_blocks table | [x] | High |
| DB-06 | pricing_config table | [x] | High |
| DB-07 | pricing_addons table | [x] | High |
| DB-08 | booking_addons table | [x] | Medium |
| DB-09 | driver_earnings table | [x] | Medium |
| DB-10 | Row Level Security policies | [x] | High |

---

## Customer Features

### Authentication
| ID | Feature | Status | Priority |
|----|---------|--------|----------|
| CUST-01 | Customer registration | [x] | High |
| CUST-02 | Customer login | [x] | High |
| CUST-03 | Password reset | [ ] | Medium |

### Booking Creation
| ID | Feature | Status | Priority |
|----|---------|--------|----------|
| CUST-10 | Select pickup location (autocomplete) | [x] | High |
| CUST-11 | Select dropoff location (autocomplete) | [x] | High |
| CUST-12 | Swap pickup/dropoff button | [ ] | Low |
| CUST-13 | View route on mini map | [ ] | Medium |
| CUST-14 | Display estimated distance | [ ] | High |
| CUST-15 | Display estimated duration | [ ] | High |
| CUST-16 | Select booking date | [ ] | High |
| CUST-17 | Select pickup time | [ ] | High |
| CUST-18 | Select vehicle | [ ] | High |
| CUST-19 | Check availability | [ ] | High |
| CUST-20 | View price breakdown | [ ] | High |
| CUST-21 | Select add-ons | [ ] | Medium |
| CUST-22 | Select payment method (GCash/Card) | [ ] | High |
| CUST-23 | Process payment | [ ] | High |
| CUST-24 | Generate booking reference number | [ ] | High |
| CUST-25 | Booking confirmation screen | [ ] | High |

### Booking History
| ID | Feature | Status | Priority |
|----|---------|--------|----------|
| CUST-30 | View booking list | [ ] | High |
| CUST-31 | Booking card with reference number | [ ] | High |
| CUST-32 | Display booking status pill | [ ] | High |
| CUST-33 | Show driver name | [ ] | High |
| CUST-34 | Show vehicle + plate number | [ ] | High |
| CUST-35 | View booking details | [ ] | High |
| CUST-36 | Cancel booking | [ ] | High |
| CUST-37 | Show cancellation deadline | [ ] | Medium |

### Notifications
| ID | Feature | Status | Priority |
|----|---------|--------|----------|
| CUST-40 | Booking confirmation email | [ ] | High |
| CUST-41 | Booking status update notification | [ ] | Medium |
| CUST-42 | Trip reminder notification | [ ] | Medium |

---

## Driver Features

### Authentication & Profile
| ID | Feature | Status | Priority |
|----|---------|--------|----------|
| DRV-01 | Driver login | [x] | High |
| DRV-02 | Manage profile | [ ] | Medium |

### Vehicle Management
| ID | Feature | Status | Priority |
|----|---------|--------|----------|
| DRV-10 | Add vehicle | [x] | High |
| DRV-11 | Edit vehicle details | [x] | Medium |
| DRV-12 | Set vehicle plate number | [x] | High |
| DRV-13 | Set vehicle capacity | [x] | High |
| DRV-14 | Delete/deactivate vehicle | [x] | Low |

### Availability Calendar
| ID | Feature | Status | Priority |
|----|---------|--------|----------|
| DRV-20 | Monthly calendar view | [x] | High |
| DRV-21 | Day status indicators (Available/Booked/Blocked) | [x] | High |
| DRV-22 | Calendar legend | [x] | Low |
| DRV-23 | Daily schedule view (hourly slots) | [x] | High |
| DRV-24 | Block time off (full day) | [x] | High |
| DRV-25 | Block time off (partial hours) | [x] | High |
| DRV-26 | Set block reason (vacation/maintenance) | [x] | Medium |
| DRV-27 | Auto-block on confirmed booking | [x] | High |

### Booking Management
| ID | Feature | Status | Priority |
|----|---------|--------|----------|
| DRV-30 | View incoming booking requests | [ ] | High |
| DRV-31 | Accept booking | [ ] | High |
| DRV-32 | Decline booking | [ ] | High |
| DRV-33 | View booking details | [ ] | High |

### Trip Lifecycle
| ID | Feature | Status | Priority |
|----|---------|--------|----------|
| DRV-40 | Trip lifecycle stepper UI | [ ] | High |
| DRV-41 | Mark trip as started | [ ] | High |
| DRV-42 | Mark trip as completed | [ ] | High |
| DRV-43 | Trip status history | [ ] | Medium |

### Earnings
| ID | Feature | Status | Priority |
|----|---------|--------|----------|
| DRV-50 | Weekly earnings summary | [ ] | High |
| DRV-51 | Pending earnings display | [ ] | High |
| DRV-52 | Completed trip count | [ ] | Medium |

---

## Admin Features

### User Management
| ID | Feature | Status | Priority |
|----|---------|--------|----------|
| ADM-01 | View all users | [ ] | High |
| ADM-02 | Edit user details | [ ] | Medium |
| ADM-03 | Deactivate user | [ ] | Medium |

### Booking Management
| ID | Feature | Status | Priority |
|----|---------|--------|----------|
| ADM-10 | View all bookings | [ ] | High |
| ADM-11 | Filter bookings by status | [ ] | Medium |
| ADM-12 | Edit booking | [ ] | Medium |
| ADM-13 | Cancel booking | [ ] | Medium |

### Dashboard
| ID | Feature | Status | Priority |
|----|---------|--------|----------|
| ADM-20 | KPI: Trips today | [ ] | High |
| ADM-21 | KPI: Revenue MTD | [ ] | High |
| ADM-22 | KPI: Fleet utilization | [ ] | High |
| ADM-23 | KPI: Active cars | [ ] | Medium |
| ADM-24 | Trend indicators (vs average, % change) | [ ] | Medium |
| ADM-25 | Recent bookings list | [ ] | High |

### Reports
| ID | Feature | Status | Priority |
|----|---------|--------|----------|
| ADM-30 | Daily trips report | [ ] | High |
| ADM-31 | Monthly revenue report | [ ] | High |
| ADM-32 | Monthly revenue bar chart | [ ] | Medium |
| ADM-33 | Fleet utilization report | [ ] | High |
| ADM-34 | Per-vehicle utilization breakdown | [ ] | Medium |

### Pricing Configuration
| ID | Feature | Status | Priority |
|----|---------|--------|----------|
| ADM-40 | Set base rate | [ ] | High |
| ADM-41 | Set distance fee per km | [ ] | High |
| ADM-42 | Manage add-ons list | [ ] | High |
| ADM-43 | Add-on: Airport meet & greet | [ ] | High |
| ADM-44 | Add-on: Child seat | [ ] | Medium |
| ADM-45 | Add-on: Extra waiting (per hour) | [ ] | Medium |
| ADM-46 | Sample fare calculator preview | [ ] | Medium |

---

## UI Components

| ID | Feature | Status | Priority |
|----|---------|--------|----------|
| UI-01 | Status pill component | [x] | High |
| UI-02 | Booking card component | [ ] | High |
| UI-03 | Monthly calendar component | [x] | High |
| UI-04 | Daily schedule component | [x] | High |
| UI-05 | KPI card component | [x] | High |
| UI-06 | Price breakdown component | [ ] | High |
| UI-07 | Trip lifecycle stepper component | [ ] | High |
| UI-08 | Route mini map component | [x] | Medium |

---

## Future (Phase 2+)

| ID | Feature | Status | Priority | Phase |
|----|---------|--------|----------|-------|
| FUT-01 | Customer ratings | [ ] | - | 2 |
| FUT-02 | Driver verification | [ ] | - | 2 |
| FUT-03 | Matching system | [ ] | - | 2 |
| FUT-04 | Fleet management | [ ] | - | 3 |
| FUT-05 | Dispatch system | [ ] | - | 3 |
| FUT-06 | Corporate accounts | [ ] | - | 3 |
| FUT-07 | Dynamic pricing | [ ] | - | 4 |
| FUT-08 | Flight tracking | [ ] | - | 4 |
| FUT-09 | Promo codes | [ ] | - | 4 |

---

## Summary

| Category | Total | Not Started | In Progress | Done |
|----------|-------|-------------|-------------|------|
| Infrastructure | 7 | 2 | 0 | 5 |
| Database | 10 | 0 | 0 | 10 |
| Customer | 22 | 18 | 0 | 4 |
| Driver | 23 | 9 | 0 | 14 |
| Admin | 21 | 21 | 0 | 0 |
| UI Components | 8 | 3 | 0 | 5 |
| **Total MVP** | **91** | **53** | **0** | **38** |
