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
- View booking history
- Cancel booking
- Receive notifications

### Driver

Can:
- Manage profile
- Manage vehicles
- Manage availability calendar
- Accept bookings
- Update trip status

### Administrator

Can:
- Manage users
- Manage bookings
- View reports
- Configure pricing

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
- capacity
- vehicle_type

## bookings
- id
- customer_id
- driver_id
- vehicle_id
- pickup_location
- dropoff_location
- booking_date
- start_time
- end_time
- status
- total_price

Status:
- Pending
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

Select Location → Choose Date → Choose Time → Check Availability → Payment → Booking Confirmed

---

# Driver Flow

Receive Booking → Accept → Start Trip → Complete Trip → Earnings Recorded

---

# Pricing Engine

Base Rate + Distance Fee + Add-ons = Total Price

---

# Reports

- Daily trips
- Monthly revenue
- Utilization rate

---

# Security

- Customers see only own bookings
- Drivers see assigned bookings
- Admin has full access

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
