# Car Booking Platform Project Plan (MVP First)

## Vision

Build a booking platform for independent chauffeurs, limousine operators, airport transfer providers, and private drivers.

The first version targets:

- One driver
- One or more vehicles
- Direct customer bookings
- Calendar-based availability
- Online payments

The goal is to help drivers stop managing bookings through Messenger, WhatsApp, spreadsheets, and phone calls.

---

# Phase 1: MVP (8–12 Weeks)

## Core User Roles

### Customer

Can:
- Register/Login
- Create booking
  - Select pickup/dropoff locations
  - Swap pickup/dropoff
  - View route on mini map
  - See estimated distance & time
  - Select date and time
  - Select vehicle
  - Select payment method (GCash, Card)
  - View price breakdown (base + distance + add-ons)
- View booking history
  - See booking reference number
  - See driver name and vehicle plate number
  - See booking status
- Cancel booking (free up to 12 hours before)
- Receive notifications

### Driver

Can:
- Manage profile
- Manage vehicles (with plate number)
- Manage availability calendar
  - View monthly calendar with status indicators
  - View daily schedule with hourly slots
  - Block time off with reason (vacation, maintenance, etc.)
- Accept or decline booking requests
- Update trip status via lifecycle stepper
  - Booking received
  - Accepted
  - Trip started
  - Trip completed
- View earnings tracker
  - Weekly earnings summary
  - Pending earnings
  - Completed trip count

### Administrator

Can:
- Manage users
- Manage bookings
- View dashboard
  - KPIs with trends (trips today, revenue MTD, utilization, active cars)
  - Recent bookings list
- View reports
  - Monthly revenue bar chart
  - Daily trips average
  - Fleet utilization
  - Per-vehicle utilization breakdown
- Configure pricing
  - Base rate (flat)
  - Distance fee (per km)
  - Add-ons (Airport meet & greet, Child seat, Extra waiting)
  - Sample fare calculator preview

---

# Recommended Technology Stack

## Frontend

Mobile + Web: Flutter

## Backend

Supabase:
- Authentication
- PostgreSQL
- Storage
- Realtime

## Maps

Google Maps Platform:
- Address autocomplete
- Route calculation
- Distance calculation

## Payments (PH)

- PayMongo
- Xendit

## Notifications

- Email: Resend

---

# Database Design

## users
- id (UUID)
- email
- name
- phone
- role (customer/driver/admin)

## vehicles
- id
- driver_id
- make
- model
- year
- plate_number
- capacity
- vehicle_type

## bookings
- id
- reference_number (e.g., MRD-4471)
- customer_id
- driver_id
- vehicle_id
- pickup_location
- dropoff_location
- estimated_distance_km
- estimated_duration_minutes
- booking_date
- start_time
- end_time
- status
- total_price
- cancellation_deadline

Status:
- Pending
- Awaiting Payment
- Confirmed
- In Progress
- Completed
- Cancelled

## payments
- id
- booking_id
- amount
- payment_status
- payment_method

## availability_blocks
- id
- driver_id
- start_time
- end_time
- reason

Examples:
- booking
- vacation
- maintenance

## pricing_config
- id
- base_rate
- distance_fee_per_km
- created_at
- updated_at

## pricing_addons
- id
- name (e.g., Airport meet & greet, Child seat, Extra waiting)
- price
- unit (flat, per_hour)
- is_active

## booking_addons
- id
- booking_id
- addon_id
- quantity
- subtotal

## driver_earnings
- id
- driver_id
- booking_id
- amount
- week_start
- status (pending, paid)

---

# Availability Calendar (Simple Version)

## Monthly View

June 2026

Mon Tue Wed Thu Fri Sat Sun

A = Available
B = Booked

## Daily View

08:00 Available
09:00 Available
10:00 Booked
11:00 Booked
12:00 Available

---

## Rules

When booking is created:
- Check conflicts with bookings
- Check availability_blocks

If conflict:
- Reject booking

---

## Automatic Blocking

When booking is confirmed:
- Create availability block

---

## Driver Manual Blocking

Drivers can block:
- Full day
- Partial hours
- Vacation

---

# Customer Flow

Select Pickup/Dropoff → View Route on Map → Choose Date/Time → Select Vehicle → Check Availability & Price → View Price Breakdown → Select Payment Method → Pay → Booking Confirmed

Booking Card Shows:
- Reference number
- Status pill
- Route summary
- Date/time
- Driver name
- Vehicle with plate number

---

# Driver Flow

Receive Booking Request → Accept/Decline → Trip Started → Trip Completed → Earnings Recorded

Trip Lifecycle Stepper:
1. Booking received
2. Accepted
3. Trip started (En route)
4. Complete trip

Earnings Dashboard:
- Weekly earnings total
- Pending earnings
- Trip count

---

# Pricing Engine

Base Rate + (Distance × Per-km Fee) + Add-ons = Total Price

Configurable Components:
- Base rate (flat fee)
- Distance fee (per km)
- Add-ons:
  - Airport meet & greet
  - Child seat
  - Extra waiting (per hour)

Features:
- Sample fare calculator for admin preview
- Price breakdown shown to customer before payment

---

# Reports

- Daily trips (with average)
- Monthly revenue (with bar chart)
- Utilization rate (overall and per-vehicle)
- Trend comparisons (vs average, % change)

---

# Security

- Customers see only own bookings
- Drivers see assigned bookings
- Admin has full access

---

# UI Components

## Status Pills
- Pending (amber)
- Awaiting Payment (amber)
- Confirmed (green)
- In Progress (blue)
- Completed (gray)
- Cancelled (red/clay)

## Booking Card
- Reference number
- Status pill
- Route (pickup → dropoff)
- Date/time
- Driver name (for customer)
- Vehicle + plate number

## Calendar Views
- Monthly grid with day status (Available/Booked/Blocked)
- Daily hourly slots with status bars
- Legend for status colors

## KPI Cards
- Value display
- Trend indicator (▲ up / ▼ down)
- Comparison text

---

# Cancellation Policy

- Free cancellation up to 12 hours before pickup
- Show deadline on booking confirmation

---

# Future Roadmap

## Phase 2
- Ratings
- Driver verification
- Matching system

## Phase 3
- Fleet management
- Dispatch system
- Corporate accounts

## Phase 4
- Dynamic pricing
- Flight tracking
- Promo codes
