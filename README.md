# 🎵 Sangeet - Music Streaming App

A modern, feature-rich music streaming application built with Flutter, offering seamless audio playback, personalized playlists, and an intuitive user experience.

## ✨ Features

- 🎵 **Audio Playback** - Stream music with background playback support
- 🔐 **Authentication** - Email and Google Sign-In integration
- 📱 **Notification Controls** - Control playback from notifications
- 🎨 **Beautiful UI** - Modern, responsive design with custom themes
- 💾 **Offline Support** - Secure local storage for user preferences
- 🔒 **Biometric Auth** - Fingerprint/Face unlock support
- 📊 **Insights** - Track your listening habits and statistics
- 🔍 **Search** - Discover music, artists, and albums
- ❤️ **Favorites** - Save and organize your favorite tracks
- 📚 **Playlists** - Create and manage custom playlists

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (3.38.7 or later)
- Android Studio / VS Code
- Android SDK (for Android builds)
- Xcode (for iOS builds, macOS only)

### Installation

1. Clone the repository:
   ```bash
   git clone <your-repo-url>
   cd sangeet
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Set up Firebase:
   - Add your `google-services.json` to `android/app/`
   - Add your `GoogleService-Info.plist` to `ios/Runner/`

4. Run the app:
   ```bash
   flutter run
   ```

## 📱 Deployment

For detailed deployment instructions, see:
- **[DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)** - Complete deployment guide
- **[QUICK_FIX_GUIDE.md](QUICK_FIX_GUIDE.md)** - Step-by-step setup instructions
- **[DEPLOYMENT_ANALYSIS_SUMMARY.md](DEPLOYMENT_ANALYSIS_SUMMARY.md)** - Current status and action plan

## 🏗️ Architecture

- **State Management:** Provider
- **Backend:** Firebase (Auth, Firestore)
- **Audio Service:** just_audio with audio_service
- **Storage:** flutter_secure_storage
- **Network:** HTTP with network security configuration

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📞 Support

For issues and questions, please create an issue in the repository.

---

Built with ❤️ using Flutter
