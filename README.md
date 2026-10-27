NeuroPause 🧠

Your Personal Digital Wellbeing Companion

NeuroPause is a Flutter-based digital wellbeing application designed to help users build healthier digital habits, manage distractions, and take mindful breaks throughout the day.

🌟 Features

- Notification Pause: Helps users manage notification interruptions and take control of their attention.
- Mindful Break: Encourages users to pause, breathe, and reset during busy days.
- Mood Check-In: Allows users to reflect on and record how they feel.
- Daily Mood Summary: Provides a space to review daily mood check-ins.
- Daily Wellbeing Tip: Offers practical suggestions for healthier digital habits.
- Wellbeing Dashboard: Brings wellbeing tools and shortcuts together in one interface.

🎯 Problem Statement

Frequent notifications and continuous screen engagement can interrupt concentration and make it difficult to maintain healthy digital habits. NeuroPause aims to encourage mindful technology use by making short breaks and personal wellbeing reflections accessible through a simple application.

🛠️ Technology Stack

- Framework: Flutter
- Programming Language: Dart
- Platform: Android
- Build System: Gradle
- Version Control: Git
- Repository Hosting: GitHub

🏗️ Project Structure

neuropause/
├── android/       # Android platform configuration
├── lib/           # Flutter application source code
├── test/          # Automated tests
├── web/           # Web platform files
├── windows/       # Windows platform files
├── pubspec.yaml   # Dependencies and project configuration
├── pubspec.lock   # Resolved dependency versions
├── analysis_options.yaml
├── .gitignore
├── README.md
└── LICENSE        # MIT License

🚀 Getting Started

Prerequisites

Install the following tools:

- Flutter SDK
- Dart SDK (included with Flutter)
- Android Studio or another supported development environment
- Git

Installation

1. Clone the repository:
   
   git clone https://github.com/Aryan-alt33/neuropause.git

2. Navigate to the project directory:
   
   cd neuropause

3. Install dependencies:
   
   flutter pub get

4. Check the project:
   
   flutter analyze
flutter test

5. Connect an Android device with USB debugging enabled, or start an Android emulator.

6. Run the application:
   
   flutter run

📱 Android APK

An Android APK is available for testing and installation.

To build a new APK from the source code, run:

flutter build apk --release

The generated APK is normally located at:

build/app/outputs/flutter-apk/app-release.apk

Transfer the APK to your Android device and install it. Only install APKs from sources you trust.

APK download: Add a link here if you publish the APK through GitHub Releases or another accessible download location.

🧪 Testing and Code Quality

The project has been checked using Flutter's analysis and test commands.

- "flutter analyze" — no issues found in the reported analysis run.
- "flutter test" — all tests passed in the reported test run.
- Manual testing — the Notification Pause and Mindful Break features have been reported to work correctly.

These results describe the checks performed during development. Additional device and platform testing may be required when making future changes.

📊 Sample Data

The "test/sample_data.json" file contains sample data for testing and demonstrating NeuroPause's wellbeing features. The data is fictional and does not contain real users' private information.


🔐 Permissions and Privacy

Notification-related functionality may require Android notification access or other platform permissions, depending on the implementation. Review the Android source code and permission configuration for the exact requirements.

Document any collection, storage, sharing, or processing of user data here before public release. Do not claim that data is stored locally or never shared unless the implementation confirms it.

🗺️ Future Improvements

Potential improvements include:

- More detailed wellbeing insights
- Customizable mindful-break reminders
- Enhanced mood history and visualizations
- Additional automated tests
- Accessibility and usability improvements

📄 License

This project is licensed under the MIT License. See the "LICENSE" (LICENSE) file for details.

👨‍💻 Repository

GitHub: https://github.com/Aryan-alt33/neuropause

---

NeuroPause: Make space for your mind.
