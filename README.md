# 🥦 MAP: FoodNi Zero-Waste Ecosystem

Welcome to the **MAP (Mobile Application Development)** repository. This project hosts **FoodNi**, a comprehensive, AI-powered solution designed to minimize food waste and optimize kitchen management. The workspace contains two primary Flutter applications:

1. **`food_ni`**: The consumer-facing mobile application powered by Gemini AI.
2. **`foodni_admin`**: The administrative web/desktop/mobile dashboard for monitoring platform analytics and managing users.

---

## 📂 Repository Structure

```text
MAP/
├── food_ni/           # 📱 Main Flutter Consumer App
│   ├── android/       # Android-specific configuration
│   ├── ios/           # iOS-specific configuration
│   ├── lib/           # Flutter application source code
│   └── functions/     # Firebase Cloud Functions (backend logic)
│
├── foodni_admin/      # 🖥️ Flutter Admin Dashboard
│   ├── lib/           # Flutter Admin source code
│   │   ├── features/  # Feature-first structure (auth, dashboard, users, settings)
│   │   └── core/      # Core services (authentication, dashboard services)
│   └── web/           # Web-specific configurations for web deployment
│
└── README.md          # 📖 Root Documentation (This file)
```

---

## 📱 1. FoodNi Client App (`food_ni`)

**FoodNi** is an intelligent, AI-powered food inventory and tracking application. It helps users reduce food waste by scanning food items, predicting freshness, tracking expiration dates, and finding recipe inspiration.

### ✨ Key Features
- **📸 AI Food Scanning:** Snap or upload images of groceries. Uses **Firebase AI Logic (Gemini Flash)** to identify the food, assess freshness, and estimate days until expiry.
- **📦 Smart Inventory:** Color-coded digital kitchen dashboard with real-time expiration sorting.
- **🍳 Recipe Inspiration:** Generate recipes on-demand using the ingredients you already have in stock.
- **🌐 Social Hub:** Share recipes, post zero-waste progress, and connect with other users.
- **🔒 Secure Authentication:** Seamless sign-in powered by Firebase Authentication (Google Sign-In).

### 🛠️ Tech Stack & SDKs
- **Framework:** Flutter (Dart `^3.11.5`)
- **Backend:** Cloud Firestore, Firebase Authentication
- **AI SDK:** `firebase_ai` (Google Gemini integration)
- **Local Storage:** Caching images via `path_provider` and `flutter_image_compress`

---

## 🖥️ 2. FoodNi Admin Dashboard (`foodni_admin`)

**FoodNi Admin** is a centralized admin dashboard tailored for system administrators to manage and inspect the ecosystem.

### ✨ Key Features
- **📊 System Overview Dashboard:** Live statistics showing Total Users, Food Items, Total Recipes, and AI API usage.
- **👥 User Management:** Search, view, and manage user profile details and status.
- **⚙️ Profile & Settings:** Manage admin account details and configure application rules.

### 🛠️ Tech Stack & SDKs
- **Framework:** Flutter (Dart `^3.11.1`)
- **Backend:** Firebase Auth, Cloud Firestore

---

## 🚀 Setup & Installation

### 📋 Prerequisites
- **Flutter SDK** (Dart Version `3.11.x` recommended)
- **Android SDK / Android Studio** (or VS Code with Dart & Flutter extensions)
- **Firebase Project Setup**:
  - You will need a registered Firebase project.
  - Download and place the `google-services.json` file inside `food_ni/android/app/google-services.json` (and `foodni_admin` equivalents if configured for Android).
  - Enable Firestore and Firebase Authentication (specifically Google Sign-In) in your Firebase Console.

### 💻 Running the Client App (`food_ni`)
1. Navigate into the client directory:
   ```bash
   cd food_ni
   ```
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Run the application:
   ```bash
   flutter run
   ```
   *(Note: Windows users can utilize the helper script `run.ps1` to automatically reset the ADB server and run the application).*

### 💻 Running the Admin App (`foodni_admin`)
1. Navigate into the admin directory:
   ```bash
   cd foodni_admin
   ```
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Run the application (supports Web, Desktop, or Emulator):
   ```bash
   flutter run -d chrome
   ```

---
*Developed as part of the Mobile Application Development (MAP) module.*