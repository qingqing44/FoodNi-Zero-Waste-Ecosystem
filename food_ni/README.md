# FoodNi 🥦📱

FoodNi is an intelligent, AI-powered food inventory and tracking application built with Flutter and Firebase. It helps users reduce food waste by effortlessly scanning food items, predicting their freshness, tracking expiration dates, and discovering recipes.

## ✨ Key Features

- **📸 AI Food Scanning:** Take a photo of any grocery item. FoodNi uses **Firebase AI Logic (Gemini Flash)** to automatically identify the food, assess its freshness, and estimate how many days it has left before spoiling.
- **📦 Smart Inventory:** Manage your kitchen digitally. See at a glance what needs to be consumed soon with automatic color-coding and sorting.
- **🍳 Recipe Inspiration:** Not sure what to cook? Generate recipes based on the ingredients you already have in your inventory.
- **🌐 Social Hub:** Share your zero-waste journey, post recipes, and connect with other users in the community.
- **🔒 Secure Authentication:** Seamless sign-in using Firebase Authentication (Google Sign-In).

---

## 🛠️ Prerequisites

Before you start, ensure you have the following installed on your machine:

1. **[Flutter SDK](https://docs.flutter.dev/get-started/install)** (Ensure you have a recent version installed)
2. **[Android Studio](https://developer.android.com/studio)** or **[VS Code](https://code.visualstudio.com/)** (with the Flutter/Dart extensions)
3. An active **Android Emulator** or a physical device connected with USB Debugging enabled.

---

## 🚀 Getting Started

Follow these steps to run the FoodNi app locally on your machine:

### 1. Clone the Repository
Open your terminal and clone this repository:
```bash
git clone https://github.com/Weilamm/MAP.git
cd MAP/food_ni
```

### 2. Install Dependencies
Run the following command to download and install all required Flutter packages:
```bash
flutter pub get
```

### 3. Firebase Configuration
FoodNi relies on Firebase for Authentication, Firestore, and AI Logic. 
Ensure you have the `google-services.json` file placed in the correct Android directory:
- `android/app/google-services.json`

*(Note: If you are setting this up as a brand new project, you will need to register the app in your own Firebase Console, download the `google-services.json`, enable Firestore, and enable Firebase AI Logic in your Firebase project).*

### 4. Run the App
Make sure your emulator is running or your physical device is connected, then execute:
```bash
flutter run
```

---

## 📖 Using the App (User Manual)

1. **Sign In**: Launch the app and sign in using your Google account.
2. **Scan Food**: 
   - Tap the central floating action button (QR/Camera icon) in the bottom navigation bar.
   - Snap a picture of your food (or upload one from the gallery).
   - Wait a few seconds for the Gemini AI to analyze the item.
   - Review the AI's predictions (Name, Category, Freshness Score). Tap **"Confirm & Save"**.
3. **Manage Inventory**: 
   - Navigate to the **Inventory** tab to see all your saved items.
   - Items are sorted with the most recently scanned at the top.
4. **Update Profile**: 
   - Go to the **Profile** tab to upload a profile picture and customize your bio. Profile images are saved securely to your local device.

---

## 🏗️ Tech Stack
- **Framework:** Flutter (Dart)
- **Backend:** Firebase (Firestore Database, Authentication)
- **AI / Machine Learning:** Firebase AI SDK (`firebase_ai`) powered by Google's Gemini models.
- **Local Storage:** `path_provider` for secure local image caching.

---
*Developed for the Mobile Application Development (MAP) module.*
