# Zippy

> A Flutter fintech prototype exploring low-friction merchant payments and social bill splitting for the South African market.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev/)
[![Appwrite](https://img.shields.io/badge/Backend-Appwrite-FD366E?logo=appwrite&logoColor=white)](https://appwrite.io/)
[![Tests](https://img.shields.io/badge/Testing-Flutter_Test-16C784)](#testing)
[![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub_Actions-2088FF)](#cicd)

**Developer:** Reamogetswe Molefe  
**Status:** Fintech Prototype / Active Development

---

## Overview

**Zippy** is a cross-platform Flutter application exploring faster and simpler payment experiences for everyday South African transactions.

The project focuses on two common payment scenarios:

### Merchant Payments

Customers can identify a merchant using a simple four-digit **Zippy Till Number**, enter an amount and complete a simulated payment flow.

### Social Bill Splitting

Users can divide a shared expense between friends, choose equal or custom portions and track the simulated settlement status of each participant.

The project was built as a **product and software engineering prototype** rather than a production payment processor.

Current payment flows use local simulation and prototype serverless functions. No real funds are transferred by the repository in its current state.

---

# Product Concept

Zippy explores a payment experience designed around:

- simple merchant identification
- minimal payment friction
- clear ZAR-based interfaces
- transparent fee calculations
- social bill splitting
- merchant transaction visibility
- mobile-first usability

The core experience is:

```text
                    ZIPPY

          ┌───────────────────────┐
          │      Customer         │
          └───────────┬───────────┘
                      │
          ┌───────────┴────────────┐
          │                        │
          ▼                        ▼
 ┌─────────────────┐      ┌─────────────────┐
 │ Merchant Payment │      │   Split Fare    │
 └────────┬────────┘      └────────┬────────┘
          │                        │
          ▼                        ▼
   Enter Till Code          Enter Bill Total
          │                        │
          ▼                        ▼
   Verify Merchant          Select Friends
          │                        │
          ▼                        ▼
    Enter Amount          Equal / Custom Split
          │                        │
          ▼                        ▼
 Simulated Settlement     Settlement Tracking
          │                        │
          └────────────┬───────────┘
                       ▼
               Transaction State
```

---

# Technology Stack

## Application

- Flutter
- Dart
- Material UI

## State & Application Services

- Flutter stateful widgets
- Riverpod dependency available for broader state-management evolution
- SharedPreferences
- JSON serialisation

## Backend Architecture

- Appwrite client
- Appwrite Databases
- Appwrite Functions
- Appwrite Realtime foundations
- Serverless JavaScript functions

## Device & Interaction

- QR functionality
- Mobile scanner support
- Haptic feedback
- Responsive Flutter layouts

## Testing & Delivery

- Flutter Test
- Widget tests
- Unit tests
- Service tests
- GitHub Actions
- Flutter Web
- GitHub Pages deployment

---

# Cross-Platform Architecture

Zippy is structured as a Flutter application targeting multiple platforms.

```text
                     Flutter Application
                            │
            ┌───────────────┼────────────────┐
            │               │                │
            ▼               ▼                ▼
         Android            iOS             Web
            │               │                │
            └───────────────┼────────────────┘
                            │
                            ▼
                 Application Services
                            │
          ┌─────────────────┼──────────────────┐
          │                 │                  │
          ▼                 ▼                  ▼
     Fee Engine      Payment Service      Storage Service
          │                 │                  │
          └─────────────────┼──────────────────┘
                            │
                ┌───────────┴───────────┐
                │                       │
                ▼                       ▼
         Local Prototype          Appwrite Layer
          Persistence            / Serverless
```

The repository also contains generated platform projects for:

```text
Android
iOS
Web
Windows
macOS
Linux
```

---

# Core Features

## 4-Digit Merchant Till Numbers

Merchants are represented by a short Zippy identifier such as:

```text
#4523
```

Customers can enter a till number and retrieve the matching merchant profile.

The interface displays information such as:

- merchant name
- business category
- bank name
- verification state

Unknown till numbers are rejected by the interface.

---

# Merchant Registration

The prototype allows new merchant profiles to be created with:

- business name
- category
- owner name
- phone number
- bank
- account number
- optional preferred till number

If the requested four-digit number is unavailable or invalid, the service generates another available prototype number.

Merchant profiles are persisted locally for later sessions.

---

# Merchant Payments

The customer payment flow currently supports:

```text
Select / enter merchant
        ↓
Verify four-digit till
        ↓
Enter ZAR amount
        ↓
Review payment
        ↓
Run prototype settlement logic
        ↓
Generate transaction record
        ↓
Display receipt
```

The current implementation creates transaction objects containing fields such as:

```text
Transaction ID
Transaction type
Status
Gross amount
Platform fee
Net merchant amount
Authorization reference
Idempotency key
Timestamp
Customer name
```

---

# Fee Engine

Zippy isolates financial calculations in a dedicated deterministic `FeeEngine`.

This keeps monetary calculations separate from UI code.

The prototype currently implements:

```text
Merchant fee: 2.5%

Net Merchant Amount
    =
Gross Amount - Merchant Fee
```

For example:

```text
Gross payment:    R100.00
Prototype fee:      R2.50
Net amount:        R97.50
```

Amounts are normalised to two decimal places.

Invalid values such as negative or zero transaction amounts are rejected.

---

# Bill Splitting

Zippy includes a dedicated social bill-splitting flow.

Users can:

- enter a total bill
- choose friends
- divide the bill equally
- define custom portions
- review each person's share
- dispatch simulated payment requests
- track settlement progress

---

## Equal Splits

The application can divide a bill automatically between the host and selected participants.

```text
Bill total
    │
    ▼
Number of people
    │
    ▼
Equal base portion
    │
    ▼
Participant amount
```

---

## Custom Splits

Users can also specify custom amounts for individual participants.

The application validates that:

- participant values are greater than zero
- the number of custom amounts matches the number of participants
- custom allocations do not exceed the total bill

The interface also provides a **Reset to Equal** option.

---

# Split Convenience Fee

The prototype currently models a flat:

```text
R2.50
```

convenience fee for participant settlement.

The calculation is handled deterministically:

```text
Amount Debited
    =
Bill Share + Convenience Fee
```

---

# Settlement Tracking

Each participant has a settlement state.

```text
pending
paid
declined
```

The bill-split model can calculate the proportion of participants that have settled.

Example:

```text
3 participants
1 paid

Settlement progress = 33%
```

The UI updates the participant state and overall settlement percentage during prototype flows.

---

# Merchant Dashboard

Zippy includes a merchant-facing dashboard.

The dashboard can display:

- merchant identity
- active till number
- QR/till presentation
- gross transaction value
- net merchant amount
- prototype platform fees
- transaction count
- payment history
- active merchant selection

The dashboard uses transaction records generated by the prototype payment service.

---

# Merchant Analytics

A dedicated statistics model calculates:

```text
Total Gross Value
Total Net Amount
Total Fees
Transaction Count
```

These values are derived from stored transaction records rather than being hard-coded into the dashboard.

---

# Local Persistence

Zippy uses `SharedPreferences` to persist prototype application state across reloads and restarts.

Persisted information currently includes:

```text
Active merchant till
Custom merchants
Merchant transactions
Bill splits
Last active role
Customer name
```

The persistence layer is isolated inside:

```text
zippy_storage_service.dart
```

This keeps storage implementation separate from the application's screens.

---

# Domain Models

The project includes dedicated Dart models for important payment concepts.

## VendorModel

Represents merchant information.

## TransactionModel

Represents merchant or settlement transaction records.

## BillSplitModel

Represents a shared bill and its participants.

## SplitParticipant

Represents an individual participant and settlement state.

This keeps business-domain objects separate from interface code.

---

# Appwrite Architecture

The repository contains an Appwrite integration layer intended to support future cloud-backed operation.

Configured services include:

```text
Account
Databases
Functions
Realtime
```

The planned collections include:

```text
users
vendors
transactions
splits
```

Function identifiers include:

```text
process_merchant_payment
initiate_payshap_split
```

The Flutter application currently defaults to:

```dart
offlineFallback = true;
```

so local development and demonstration can run without production cloud credentials.

---

# Serverless Function Prototypes

The repository contains Appwrite Function prototypes for payment-related backend operations.

## Merchant Payment Function

```text
process_merchant_payment
```

The function currently:

- validates payment input
- calculates the prototype merchant fee
- calculates the net merchant amount
- generates an authorization-style reference
- creates an idempotency key
- returns structured settlement data

---

## Split Settlement Function

```text
initiate_payshap_split
```

The function currently:

- validates participant settlement data
- applies the prototype convenience fee
- calculates the total simulated debit
- generates a PayShap-style authorization reference
- returns structured settlement information

---

## Important Integration Status

The names **PayShap** and **Stitch** are used in the prototype architecture to model how future South African payment-rail integration could work.

The repository does **not currently execute real PayShap or Stitch transactions**.

Authorization references are generated by the prototype logic and settlement responses are simulated.

Production payment processing would require:

- approved payment-provider accounts
- production API credentials
- secure backend infrastructure
- webhook verification
- payment reconciliation
- regulatory and compliance review
- production identity and merchant verification

---

# QR Experience

Merchant profiles can expose a visual QR/till experience.

The current merchant dashboard allows users to:

- display the four-digit till
- copy the till code
- open a QR-style merchant modal

The current implementation focuses on UX prototyping rather than production payment QR interoperability.

---

# Testing

Zippy contains automated tests across multiple parts of the application.

Test coverage includes:

```text
Fee calculations
Domain models
Storage persistence
Merchant registration
Merchant transactions
Bill splitting
Widget behavior
Payment flow
Custom split validation
Settlement state
Merchant lookup
Rapid-tap protection
Responsive touch targets
```

The tests use Flutter's testing framework.

Run them with:

```bash
flutter test
```

---

# Example Tested Flow

The widget suite exercises flows such as:

```text
Launch Zippy
    ↓
Select merchant
    ↓
Enter amount
    ↓
Confirm prototype payment
    ↓
Display receipt
    ↓
Choose "Split this bill"
    ↓
Select participants
    ↓
Dispatch split
    ↓
Settle participant
    ↓
Update progress
```

This provides regression coverage across several connected application screens.

---

# CI/CD

The repository contains a GitHub Actions workflow.

On changes to the main branch, the workflow:

```text
Checks out code
      ↓
Installs Flutter
      ↓
Installs dependencies
      ↓
Runs automated tests
      ↓
Builds Flutter Web
      ↓
Copies brand / marketing assets
      ↓
Uploads deployment artifact
      ↓
Deploys to GitHub Pages
```

This means tests run before the web application is deployed.

---

# Web Deployment

The workflow builds the Flutter application using:

```bash
flutter build web --release --base-href "/zippy/"
```

The generated web build is prepared for GitHub Pages.

---

# Repository Structure

```text
zippy/
│
├── .github/
│   └── workflows/
│       └── deploy.yml
│
├── appwrite_functions/
│   ├── initiate_payshap_split/
│   └── process_merchant_payment/
│
├── appwrite_schema/
│   └── collections.json
│
├── zippy_app/
│   │
│   ├── lib/
│   │   ├── core/
│   │   │   ├── appwrite_config.dart
│   │   │   ├── fee_engine.dart
│   │   │   └── zippy_theme.dart
│   │   │
│   │   ├── models/
│   │   │   ├── bill_split_model.dart
│   │   │   ├── transaction_model.dart
│   │   │   └── vendor_model.dart
│   │   │
│   │   ├── screens/
│   │   │   ├── merchant_dashboard_screen.dart
│   │   │   ├── pay_merchant_screen.dart
│   │   │   └── split_fare_screen.dart
│   │   │
│   │   ├── services/
│   │   │   ├── zippy_payment_service.dart
│   │   │   └── zippy_storage_service.dart
│   │   │
│   │   └── widgets/
│   │
│   ├── test/
│   │
│   ├── android/
│   ├── ios/
│   ├── web/
│   ├── windows/
│   ├── macos/
│   └── linux/
│
├── zippy_logo.svg
├── zippy_logo.png
├── zippy_app_icon.png
└── README.md
```

---

# Running Locally

## 1. Clone the repository

```bash
git clone https://github.com/reamogetswemolefe0190-cmd/zippy.git
cd zippy/zippy_app
```

---

## 2. Install Flutter dependencies

```bash
flutter pub get
```

---

## 3. Check your environment

```bash
flutter doctor
```

---

## 4. Run the test suite

```bash
flutter test
```

---

## 5. Run the application

### Web

```bash
flutter run -d chrome
```

### Android

```bash
flutter run -d android
```

Or select another available Flutter device:

```bash
flutter devices
flutter run -d <device-id>
```

---

# Building for Web

```bash
flutter build web --release
```

---

# Design Philosophy

Zippy is built around a few product principles.

## Reduce Payment Friction

A payment flow should make it immediately clear:

```text
Who am I paying?
How much am I paying?
What happens next?
```

## Keep Financial Calculations Deterministic

Fees and split values are calculated in Dart rather than inferred by an AI model or buried inside interface code.

## Mobile-First Interaction

Large touch targets, tactile interactions and simple ZAR-based inputs are used throughout the interface.

## Separate Domain Logic from UI

Payment calculations, persistence and models live outside the screen widgets.

## Prototype Real Workflows Before Real Money

The project focuses on testing product architecture and user flows before connecting production financial infrastructure.

---

# Prototype Limitations

Zippy is currently an experimental fintech application.

The repository does **not** currently provide:

- real bank settlement
- live PayShap Request-to-Pay
- live Stitch transactions
- real merchant verification
- real payment custody
- production KYC
- production fraud detection
- regulated payment processing
- production-grade reconciliation
- guaranteed offline payment settlement

Several payment identifiers and settlement results are generated locally for demonstration and testing.

---

# What This Project Demonstrates

From a software-engineering perspective, Zippy demonstrates experience with:

```text
Flutter
Dart
Cross-platform development
Fintech UX
Domain modelling
Deterministic financial calculations
Local persistence
Appwrite architecture
Serverless functions
QR-oriented UX
Stateful application flows
Automated testing
Widget testing
CI/CD
GitHub Actions
Responsive mobile design
```

---

# Future Development

Potential next stages include:

- production Appwrite persistence
- authenticated user accounts
- real-time transaction updates
- secure webhook architecture
- sandbox payment-provider integration
- real QR generation and scanning
- merchant onboarding verification
- stronger error and retry handling
- transaction reconciliation
- accessibility improvements
- expanded test coverage
- analytics and observability

Any real-money integration would require appropriate provider approval, security review and regulatory compliance.

---

# About the Developer

## Reamogetswe Molefe

I am a Mechanical Engineering student at the **University of Johannesburg** who independently builds software across AI, SaaS, fintech and full-stack product development.

Zippy was built as an exploration of mobile fintech product engineering and how everyday payment experiences can be simplified for the South African market.

Other projects include:

- **Kohort** — Python multi-model AI market-research engine
- **CreatorCashFlow** — Node.js/Express SaaS platform for creator operations
- **Yieldly** — Next.js/TypeScript digital stokvel prototype
- **SplitFare** — React Native bill-splitting app with receipt OCR

GitHub:

https://github.com/reamogetswemolefe0190-cmd

---

# Disclaimer

Zippy is a software prototype.

It is not a bank, payment service provider or financial institution, and the current repository does not process real financial transactions.

Payment-provider names and payment-rail concepts are used to model potential future integrations.

---

<p align="center">
  <strong>Zippy</strong><br>
  Exploring simpler everyday payments for South Africa.
</p>
