<div align="center">

# 💊 Dozara — Medication Reminder App

**A smart, secure, and AI-powered cross-platform medication tracking application built with Flutter.**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Backend-3ECF8E?logo=supabase)](https://supabase.com)
[![Firebase](https://img.shields.io/badge/Firebase-FCM-FFCA28?logo=firebase)](https://firebase.google.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-lightgrey)](https://flutter.dev)

</div>

---

## 📖 Overview

**Dozara** is a full-featured medication management app designed to help users and their families maintain consistent medication schedules. It combines intelligent reminders, AI-assisted medicine scanning, biometric security, and detailed adherence analytics — all working seamlessly offline with optional cloud sync.

> Built as a personal project to demonstrate real-world Flutter development skills: state management, local persistence, cloud integration, AI/ML, and secure data handling.

---

## ✨ Features

### 💊 Medication Management
- Add medications with name, dosage, form (pill, syrup, injection, drop, cream, inhaler)
- Flexible scheduling: **daily**, **specific weekdays**, or **custom intervals**
- Multiple custom reminder times per medication
- "Take with food" flag and personal notes
- Treatment duration tracking with automatic expiry detection

### 🔔 Smart Notifications
- Local push notifications via `flutter_local_notifications`
- Firebase Cloud Messaging (FCM) for remote/family notifications
- Notification center with full history log
- Home screen widget for at-a-glance daily doses

### 📦 Stock Tracking
- Real-time stock count tracking
- Configurable low-stock warnings
- Empty-stock alerts to prompt refills

### 📊 Adherence Analytics
- **30-day adherence statistics** with visual charts (`fl_chart`)
- Dose history log per medication
- Completion rate tracking across all active medicines

### 🤖 AI Assistant
- Conversational AI assistant powered by **Gemini API** (via Supabase Edge Functions)
- **OCR-based medicine scanning** using **Google ML Kit** — scan a medicine box to auto-fill details
- **Speech-to-Text** and **Text-to-Speech** support for hands-free interaction

### 👨‍👩‍👧 Multi-Profile Support
- Manage medication schedules for the whole family
- Separate profiles with independent medication lists and notification streams
- Family notification service for caregiver alerts

### 📄 PDF Reports
- Generate detailed medication adherence reports
- Export and share reports with healthcare providers

### 🔒 Security & Privacy
- App-level **PIN protection** and **biometric authentication** (fingerprint/face)
- All data encrypted locally with **Hive AES encryption**
- Encryption keys stored securely via `flutter_secure_storage`
- No personal health data leaves the device without user consent

---

## 🏗️ Architecture

```
lib/
├── cubit/              # BLoC/Cubit state management
├── models/             # Hive data models (Medicine, Profile, DoseLog)
├── screens/            # 11 full-featured app screens
│   ├── home_screen.dart
│   ├── add_medicine_screen.dart
│   ├── medicine_detail_screen.dart
│   ├── ai_assistant_screen.dart
│   ├── stats_screen.dart
│   ├── history_screen.dart
│   ├── family_profiles_screen.dart
│   ├── notification_center_screen.dart
│   ├── settings_screen.dart
│   └── onboarding_screen.dart
├── services/           # Business logic layer
│   ├── ai_service.dart           # Gemini API integration
│   ├── hive_service.dart         # Local database operations
│   ├── notification_service.dart # Local notification scheduling
│   ├── ocr_service.dart          # Google ML Kit OCR
│   ├── pdf_service.dart          # Report generation
│   ├── voice_reminder_service.dart # TTS reminders
│   └── widget_service.dart       # Home screen widget
├── theme/              # Design system & theming
├── utils/              # Helper utilities
└── widgets/            # Reusable UI components
```

**State Management:** BLoC / Cubit pattern  
**Data Flow:** Unidirectional, event-driven architecture

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| **Framework** | Flutter 3.x / Dart 3.x |
| **State Management** | flutter_bloc (BLoC / Cubit) |
| **Local Database** | Hive + Hive Flutter (AES encrypted) |
| **Backend** | Supabase (Auth + Edge Functions) |
| **AI / ML** | Gemini API, Google ML Kit (OCR) |
| **Push Notifications** | flutter_local_notifications + Firebase FCM |
| **Security** | flutter_secure_storage, local_auth (biometrics) |
| **Charts** | fl_chart |
| **PDF** | pdf + printing |
| **Voice** | speech_to_text + flutter_tts |
| **Home Widget** | home_widget |
| **Animations** | flutter_animate + Lottie |
| **Fonts** | Google Fonts |
| **CI/CD** | Codemagic |

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK `>=3.0.0 <4.0.0`
- Dart SDK `>=3.0.0`
- Android Studio / Xcode (for device deployment)
- A [Supabase](https://supabase.com) project
- A [Firebase](https://console.firebase.google.com) project (for FCM)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/dozara.git
   cd dozara
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure environment variables**

   Create a `.env` file in the project root:
   ```env
   SUPABASE_URL=https://your-project-ref.supabase.co
   SUPABASE_ANON_KEY=your_supabase_anon_key
   ```

   > ⚠️ The Gemini API key is **not** stored in the app. It lives as a Supabase secret and is accessed exclusively through `supabase/functions/gemini-proxy` for security.

4. **Deploy Supabase Edge Functions** *(optional — required for AI features)*
   ```bash
   supabase functions deploy gemini-proxy
   ```

5. **Run the app**
   ```bash
   flutter run
   ```

### Build

```bash
# Android APK
flutter build apk --release

# Android App Bundle (Play Store)
flutter build appbundle --release

# iOS
flutter build ios --release
```

---

## 🧪 Testing

```bash
# Run all tests
flutter test

# Static analysis
flutter analyze
```

---

## 🔐 Security Notes

- All medication data is stored **on-device only**, encrypted with AES via Hive.
- The AES encryption key and PIN hash are stored in the OS secure keychain via `flutter_secure_storage`.
- Biometric authentication and PIN lock can be enabled optionally by the user.
- Cloud sync (Supabase) is opt-in and uses row-level security (RLS) policies.
- The Gemini API is called through a Supabase proxy — the API key is never exposed to the client.

---

## 📱 Screens

| Screen | Description |
|--------|-------------|
| **Onboarding** | First-launch walkthrough with profile setup |
| **Home** | Daily medication checklist with progress indicator |
| **Add Medicine** | Rich form with schedule builder and dose calculator |
| **Medicine Detail** | Full medication info, stock management, dose history |
| **AI Assistant** | Chat, OCR scan, and voice interaction with Gemini |
| **Statistics** | 30-day adherence charts and compliance tracking |
| **History** | Chronological dose log with filtering |
| **Family Profiles** | Multi-user profile management |
| **Notification Center** | Full notification history and management |
| **Settings** | Security, theme, language, and account settings |

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome!  
Feel free to open an [issue](https://github.com/YOUR_USERNAME/dozara/issues) or submit a pull request.

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

<div align="center">

Made with ❤️ using Flutter

</div>
