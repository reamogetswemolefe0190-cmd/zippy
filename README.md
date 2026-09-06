# Zippy — High-Velocity South African Payments & Bill Splitting

<div align="center">
  <img src="./zippy_logo.png" width="160" height="160" alt="Zippy Logo" />
  <br />
  <strong>Fast, low-friction payments and bill splitting tailored for the South African payment landscape.</strong>
  <br /><br />
  
  [![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
  [![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
  [![Appwrite](https://img.shields.io/badge/BaaS-Appwrite-FD366E?logo=appwrite&logoColor=white)](https://appwrite.io)
  [![License: MIT](https://img.shields.io/badge/License-MIT-emerald.svg)](LICENSE)
  [![Coverage](https://img.shields.io/badge/Tests-54%20Passing-16C784.svg)](test)
  [![Lint: 0 Errors](https://img.shields.io/badge/dart%20analyze-0%20warnings-16C784.svg)](zippy_app)
</div>

---

## ⚡ Overview

**Zippy** solves two of the most painful friction points in South African daily commerce:
1. **Merchant Payments (Spaza / Tuck Shop / Cafe / Market)**: Pay any merchant in 4 seconds using their simple 4-digit Till Number (`#4523`) or QR code. Replaces expensive R800+ card POS terminals and 3.5% transaction cuts with a **1.5% micro-fee** and instant bank settlement via **PayShap** and **Capitec Pay**.
2. **Peer-to-Peer Bill Splitting**: Split group dinners, braai expenses, and taxi fares in 1 tap without awkward math, napkin calculations, or delayed bank transfers.

---

## 🚀 Key Features

### 🏪 Merchant Hub & Till System
- **R0 Hardware Cost**: Turn any smartphone into a verified merchant payment terminal in 60 seconds.
- **4-Digit Till Code**: Instant vendor lookup with verified merchant badge and bank details.
- **Countertop POS Stand**: Built-in generator for printable acrylic tent cards and laser/thermal ink-friendly display cards (`marketing_kit.html`).
- **Real-Time Income Analytics**: Track daily turnover, average transaction size, and incoming payments.

### 👥 1-Tap Bill Splitting
- **Dynamic Split Engine**: Enter bill total (e.g. `R640.00`) and select friends to compute portions automatically.
- **Live Settlement Tracking**: Track who has paid and who is pending in real time.
- **Zero Financial Jargon**: Clean, tactile ZAR numpad with haptic micro-interactions.

### 🇿🇦 Built for South African Realities
- **Interbank Rails**: Native integration with **PayShap** and **Capitec Pay** (direct account-to-account push).
- **Reverse-Billed / Low-Data Friendly**: Designed to function seamlessly even when customers have zero mobile data.
- **Offline Fallback Architecture**: Resilient against load-shedding network drops.

---

## 📁 Repository Structure

```
├── zippy_app/                 # Flutter application (Web, iOS, Android, Desktop)
│   ├── lib/
│   │   ├── core/              # Theme, Fee Engine, Appwrite BaaS config
│   │   ├── models/            # BillSplit, Transaction, Vendor data models
│   │   ├── screens/           # Pay Merchant, Split Fare, Merchant Dashboard
│   │   ├── services/          # PaymentService, StorageService (persistence)
│   │   └── widgets/           # ZippyLogo, ZarNumpad, TactileScale animations
│   ├── test/                  # 54 Automated unit, widget, and service tests
│   └── web/                   # Web shell, favicon, marketing kit, download portal
├── appwrite_schema/           # Database collections (vendors, transactions, splits)
├── appwrite_functions/        # Serverless backend functions
├── .github/workflows/         # CI/CD: Automated build, test, and GitHub Pages deploy
├── zippy_logo.png             # Official Brand Logo (Variant 02: Bilateral Split)
├── zippy_app_icon.png         # Official App Icon Squircle
├── zippy_logo.svg             # Vector Logo
└── README.md
```

---

## 🛠️ Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.24+ recommended)
- [Dart SDK](https://dart.dev/get-dart)
- Chrome / Edge (for web preview)

### Local Development

1. **Clone the repository:**
   ```bash
   git clone https://github.com/<your-username>/zippy.git
   cd zippy/zippy_app
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run tests & static analysis:**
   ```bash
   flutter test
   dart analyze --fatal-infos
   ```

4. **Launch the application:**
   ```bash
   flutter run -d chrome
   ```

---

## 🌐 Marketing & Brand Assets

The repository includes a ready-to-deploy growth suite:
- **Marketing Hub & Countertop Stand Generator**: `zippy_app/web/marketing_kit.html`
- **Brand Asset Download Portal**: `zippy_app/web/logo_download.html`
- **Official Brand Logos**: High-resolution vector SVGs and PNGs located in the repository root.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

Developed with ❤️ for the South African payment ecosystem.
