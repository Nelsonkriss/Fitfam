# FitFarm - Your Modern Workout Planner

FitFarm is a comprehensive Flutter-based mobile application designed to help you create, track, and analyze your workout routines. Whether you're a beginner or an experienced fitness enthusiast, FitFarm provides the tools you need to achieve your fitness goals with a modern, user-friendly interface.

## ✨ Key Features

*   **Routine Creation & Management:**
    *   Easily create custom workout routines tailored to your needs.
    *   Organize routines by main targeted body parts.
    *   Define parts within routines (e.g., Warmup, Bench Press Section) with specific set types (Regular, Superset, Dropset, etc.).
    *   Add detailed exercises with sets, reps, weight, and workout type (Weight Training or Cardio).
*   **AI-Powered Routine Generation:**
    *   Leverage AI to generate workout routines based on your textual descriptions and goals.
*   **Workout Session Tracking:**
    *   Step-by-step guidance through your routines during a workout.
    *   Track actual reps and weight for each set.
    *   The app remembers the last weight used for an exercise in a routine, making progressive overload easier.
*   **Progress Visualization:**
    *   View statistics on your workout history, including total workouts completed and days active.
    *   Track your workout volume and max weight progression for exercises over time with intuitive charts.
    *   Visualize workout focus with a donut chart showing distribution by body part.
*   **Scheduling & Reminders:**
    *   Schedule routines for specific days of the week.
    *   Receive notifications to remind you of your scheduled workouts.
*   **Cloud Sync & Backup:**
    *   Securely back up your routines to the cloud using Firebase.
    *   Restore your data across multiple devices.
    *   Sign in with Google or Apple.
*   **Modern & Customizable UI:**
    *   Clean, intuitive user interface.
    *   Supports **Dark Mode**, Light Mode, and System Default theme preferences.
*   **Sharing (Basic):**
    *   Share routines with others (currently via QR code data).

## 🚀 Getting Started (For Developers)

This project is built with Flutter.

1.  **Prerequisites:**
    *   Flutter SDK: Make sure you have the Flutter SDK installed. See [Flutter documentation](https://flutter.dev/docs/get-started/install).
    *   Firebase Account: For cloud sync features, you'll need a Firebase project.
    *   OpenRouter API Key: For AI routine generation, an API key for OpenRouter (or a compatible service) is required.

2.  **Setup:**
    *   Clone the repository:
        ```bash
        git clone <repository-url>
        cd FitFarm 
        ```
    *   Install dependencies:
        ```bash
        flutter pub get
        ```
    *   **Firebase Setup:**
        *   Follow the FlutterFire CLI instructions to add your Firebase project configuration files (e.g., `google-services.json` for Android, `GoogleService-Info.plist` for iOS). See [FlutterFire Overview](https://firebase.flutter.dev/docs/overview).
    *   **API Key for AI Features:**
        *   Create a `.env` file in the root of the project.
        *   Add your OpenRouter API key to the `.env` file:
            ```env
            OPENROUTER_API_KEY=your_openrouter_api_key_here
            ```
        *   Ensure `flutter_dotenv` is correctly configured in `pubspec.yaml` and loaded in `main.dart`.

3.  **Run the App:**
    *   Connect a device or start an emulator.
    *   Run the app:
        ```bash
        flutter run
        ```

## 🛠 Tech Stack

*   **Framework:** Flutter
*   **Language:** Dart
*   **Database:** SQLite (via `sqflite`) for local storage.
*   **Backend & Sync:** Firebase (Authentication, Firestore for cloud backup).
*   **AI Integration:** OpenRouter API (or compatible LLM provider).
*   **State Management:**
    *   Provider (for dependency injection and `ThemeProvider`).
    *   RxDart with BLoC pattern (`RoutinesBloc`).
    *   `flutter_bloc` (`WorkoutSessionBloc`).
*   **Charting:** `fl_chart`, `percent_indicator`.
*   **Notifications:** `flutter_local_notifications`.
*   **Other Key Packages:** `shared_preferences`, `flutter_dotenv`, `connectivity_plus`, `url_launcher`, `package_info_plus`, `share_plus`.

## 🖼 Screenshots (Placeholder)

*(Add screenshots of the app here to showcase its features and UI)*

*   *Home Page (Light/Dark)*
*   *Routine Detail (Light/Dark)*
*   *Workout Session (Light/Dark)*
*   *Statistics & Charts (Light/Dark)*
*   *AI Coach Page (Light/Dark)*
*   *Settings Page (Light/Dark)*

## 🤝 Contributing (Optional)

*(If you plan to make this open source, add contribution guidelines here.)*

## 📄 License (Optional)

*(Specify the license for your project, e.g., MIT, Apache 2.0.)*

---

Built with ❤️ and Flutter.
