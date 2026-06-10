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
| INF-06 | Email setup (Gmail SMTP) | [x] | Medium |
| INF-09 | Migrate email sender from Gmail SMTP to Resend API | [ ] | Low |
| INF-07 | Authentication flow (Supabase Auth) | [x] | High |
| INF-08 | Firebase project setup & FCM credentials | [x] | Medium |

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
| CUST-03 | Password reset | [x] | Medium |

### Booking Creation
| ID | Feature | Status | Priority |
|----|---------|--------|----------|
| CUST-10 | Select pickup location (autocomplete) | [x] | High |
| CUST-11 | Select dropoff location (autocomplete) | [x] | High |
| CUST-12 | Swap pickup/dropoff button | [x] | Low |
| CUST-13 | View route on mini map | [x] | Medium |
| CUST-14 | Display estimated distance | [x] | High |
| CUST-15 | Display estimated duration | [x] | High |
| CUST-16 | Select booking date | [x] | High |
| CUST-17 | Select pickup time | [x] | High |
| CUST-18 | Select vehicle | [x] | High |
| CUST-19 | Check availability | [x] | High |
| CUST-20 | View price breakdown | [x] | High |
| CUST-21 | Select add-ons | [x] | Medium |
| CUST-22 | Select payment method (GCash/Card) | [ ] | High |
| CUST-23 | Process payment | [ ] | High |
| CUST-24 | Generate booking reference number | [x] | High |
| CUST-25 | Booking confirmation screen | [x] | High |

### Booking History
| ID | Feature | Status | Priority |
|----|---------|--------|----------|
| CUST-30 | View booking list | [x] | High |
| CUST-31 | Booking card with reference number | [x] | High |
| CUST-32 | Display booking status pill | [x] | High |
| CUST-33 | Show driver name | [x] | High |
| CUST-34 | Show vehicle + plate number | [x] | High |
| CUST-35 | View booking details | [x] | High |
| CUST-36 | Cancel booking | [x] | High |
| CUST-37 | Show cancellation deadline | [x] | Medium |

### Notifications
| ID | Feature | Status | Priority |
|----|---------|--------|----------|
| CUST-40 | Booking confirmation email | [x] | High |
| CUST-41 | Booking status update notification (email) | [x] | Medium |
| CUST-42 | Trip reminder notification | [x] | Medium |
| CUST-43 | Save FCM device token to Supabase on login | [x] | Medium |
| CUST-44 | FCM push: driver assigned notification | [x] | Medium |
| CUST-45 | FCM push: trip started notification | [ ] | Medium |
| CUST-46 | FCM push: trip completed notification | [ ] | Medium |
| CUST-47 | FCM push: trip reminder (scheduled via Cloud Scheduler or Supabase cron) | [ ] | Low |

---

## Driver Features

### Authentication & Profile
| ID | Feature | Status | Priority |
|----|---------|--------|----------|
| DRV-01 | Driver login | [x] | High |
| DRV-02 | Manage profile | [x] | Medium |

### Vehicle Management
| ID | Feature | Status | Priority |
|----|---------|--------|----------|
| DRV-10 | Add vehicle | [x] | High |
| DRV-11 | Edit vehicle details | [x] | Medium |
| DRV-12 | Set vehicle plate number | [x] | High |
| DRV-13 | Set vehicle capacity | [x] | High |
| DRV-14 | Delete/deactivate vehicle | [x] | Low |
| DRV-15 | Add vehicle year, model, color | [x] | High |
| DRV-16 | Upload vehicle photos (front, back, left, right, interior) | [x] | High |
| DRV-17 | Upload vehicle OR/CR documents | [x] | High |

### Driver Documents
| ID | Feature | Status | Priority |
|----|---------|--------|----------|
| DRV-60 | Upload driver's license | [x] | High |
| DRV-61 | View uploaded documents | [x] | Medium |
| DRV-62 | Document expiry tracking | [x] | Low |

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
| DRV-30 | View incoming booking requests | [x] | High |
| DRV-31 | Accept booking | [x] | High |
| DRV-32 | ~~Decline booking~~ (removed - bookings remain visible) | [-] | - |
| DRV-33 | View booking details | [x] | High |

### Trip Lifecycle
| ID | Feature | Status | Priority |
|----|---------|--------|----------|
| DRV-40 | Trip lifecycle stepper UI | [x] | High |
| DRV-41 | Mark trip as started | [x] | High |
| DRV-42 | Mark trip as completed | [x] | High |
| DRV-43 | Trip status history | [x] | Medium |

### Earnings
| ID | Feature | Status | Priority |
|----|---------|--------|----------|
| DRV-50 | Weekly earnings summary | [x] | High |
| DRV-51 | Pending earnings display | [x] | High |
| DRV-52 | Completed trip count | [x] | Medium |

---

## Admin Features

### User Management
| ID | Feature | Status | Priority |
|----|---------|--------|----------|
| ADM-01 | View all users | [x] | High |
| ADM-02 | Edit user details | [x] | Medium |
| ADM-03 | Deactivate user | [x] | Medium |

### Booking Management
| ID | Feature | Status | Priority |
|----|---------|--------|----------|
| ADM-10 | View all bookings | [x] | High |
| ADM-11 | Filter bookings by status | [x] | Medium |
| ADM-12 | Edit booking | [x] | Medium |
| ADM-13 | Cancel booking | [x] | Medium |

### Dashboard
| ID | Feature | Status | Priority |
|----|---------|--------|----------|
| ADM-20 | KPI: Trips today | [x] | High |
| ADM-21 | KPI: Revenue MTD | [x] | High |
| ADM-22 | KPI: Fleet utilization | [x] | High |
| ADM-23 | KPI: Active cars | [x] | Medium |
| ADM-24 | Trend indicators (vs average, % change) | [x] | Medium |
| ADM-25 | Recent bookings list | [x] | High |

### Reports
| ID | Feature | Status | Priority |
|----|---------|--------|----------|
| ADM-30 | Daily trips report | [x] | High |
| ADM-31 | Monthly revenue report | [x] | High |
| ADM-32 | Monthly revenue bar chart | [x] | Medium |
| ADM-33 | Fleet utilization report | [x] | High |
| ADM-34 | Per-vehicle utilization breakdown | [x] | Medium |

### Pricing Configuration
| ID | Feature | Status | Priority |
|----|---------|--------|----------|
| ADM-40 | Set base rate | [x] | High |
| ADM-41 | Set distance fee per km | [x] | High |
| ADM-42 | Manage add-ons list | [x] | High |
| ADM-43 | Add-on: Airport meet & greet | [x] | High |
| ADM-44 | Add-on: Child seat | [x] | Medium |
| ADM-45 | Add-on: Extra waiting (per hour) | [x] | Medium |
| ADM-46 | Sample fare calculator preview | [x] | Medium |

---

## UI Components

| ID | Feature | Status | Priority |
|----|---------|--------|----------|
| UI-01 | Status pill component | [x] | High |
| UI-02 | Booking card component | [x] | High |
| UI-03 | Monthly calendar component | [x] | High |
| UI-04 | Daily schedule component | [x] | High |
| UI-05 | KPI card component | [x] | High |
| UI-06 | Price breakdown component | [x] | High |
| UI-07 | Trip lifecycle stepper component | [x] | High |
| UI-08 | Route mini map component | [x] | Medium |

---

## Vehicle Categories Feature

### Database Changes
| ID | Feature | Status | Priority |
|----|---------|--------|----------|
| CAT-01 | Add vehicle_category enum (Sedan, MPV/SUV, Van) | [x] | High |
| CAT-02 | Add category field to vehicles table | [x] | High |
| CAT-03 | Add category, num_bags, additional_info to bookings table | [x] | High |
| CAT-04 | Add category-based pricing to pricing_config | [x] | High |

### Admin Features
| ID | Feature | Status | Priority |
|----|---------|--------|----------|
| CAT-10 | Configure base rate per category | [x] | High |
| CAT-11 | Configure distance fee per category | [x] | High |

### Customer Booking Flow
| ID | Feature | Status | Priority |
|----|---------|--------|----------|
| CAT-20 | Select vehicle category (Sedan/MPV-SUV/Van) | [x] | High |
| CAT-21 | Enter number of bags | [x] | High |
| CAT-22 | Enter optional additional info | [x] | Medium |
| CAT-23 | Display category-based pricing | [x] | High |

### Driver Booking Flow
| ID | Feature | Status | Priority |
|----|---------|--------|----------|
| CAT-30 | Display customer name on pending bookings | [x] | High |
| CAT-31 | Display number of bags on pending bookings | [x] | High |
| CAT-32 | Display additional info on pending bookings | [x] | Medium |
| CAT-33 | Display selected category on pending bookings | [x] | High |
| CAT-34 | Category-based acceptance rules | [x] | High |

**Category Acceptance Rules:**
- **Van** can accept: Van, MPV/SUV, Sedan (price follows selected category)
- **MPV/SUV** can accept: MPV/SUV, Sedan (price follows selected category)
- **Sedan** can accept: Sedan only

---

## In-App Messaging

| ID | Feature | Status | Priority |
|----|---------|--------|----------|
| MSG-01 | Chat/messages table in database | [ ] | Low |
| MSG-02 | Conversations table (booking-based) | [ ] | Low |
| MSG-03 | Real-time messaging with Supabase Realtime | [ ] | Low |
| MSG-04 | Customer can message driver after booking confirmed | [ ] | Low |
| MSG-05 | Driver can message customer after accepting | [ ] | Low |
| MSG-06 | Chat screen UI | [ ] | Low |
| MSG-07 | Unread message badge/indicator | [ ] | Low |
| MSG-08 | Push notifications for new messages | [ ] | Low |
| MSG-09 | Message history per booking | [ ] | Low |

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
| Infrastructure | 9 | 3 | 0 | 6 |
| Database | 10 | 0 | 0 | 10 |
| Customer | 35 | 10 | 0 | 25 |
| Driver | 32 | 0 | 0 | 32 |
| Admin | 25 | 0 | 0 | 25 |
| UI Components | 8 | 0 | 0 | 8 |
| Vehicle Categories | 15 | 0 | 0 | 15 |
| In-App Messaging | 9 | 9 | 0 | 0 |
| **Total MVP** | **142** | **23** | **0** | **119** |
