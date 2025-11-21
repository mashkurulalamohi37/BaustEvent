# EventBridge - Event Management App

A comprehensive Flutter application for managing events, built with Firebase integration and modern UI design.

## 🚀 Features

### Core Functionality
- **Event Management**: Create, edit, and manage events
- **User Authentication**: Secure login and registration system
- **Role-based Access**: Separate dashboards for organizers and participants
- **QR Code Integration**: Generate and scan QR codes for event check-ins
- **Real-time Updates**: Live event updates using Firebase
- **Cross-platform Support**: Runs on Android, iOS, Web, Windows, macOS, and Linux

### User Roles
- **Organizers**: Can create events, manage participants, and track attendance
- **Participants**: Can browse events, register, and check-in using QR codes

### Technical Features
- **Firebase Integration**: Authentication, Firestore, Storage, and Realtime Database
- **Material Design 3**: Modern UI with beautiful gradients and animations
- **Responsive Design**: Optimized for different screen sizes
- **Offline Support**: Basic offline functionality with local data caching

## 📱 Screenshots

*Add screenshots of your app here*

## 🛠️ Tech Stack

- **Framework**: Flutter 3.x
- **Backend**: Firebase
  - Authentication
  - Firestore Database
  - Cloud Storage
  - Realtime Database
  - Cloud Messaging
- **State Management**: Provider/Riverpod
- **UI**: Material Design 3
- **QR Code**: mobile_scanner package
- **Image Handling**: image_picker package

## 📋 Prerequisites

Before running this project, make sure you have:

- Flutter SDK (3.0 or higher)
- Dart SDK (3.0 or higher)
- Firebase project setup
- Android Studio / VS Code with Flutter extensions
- Git

## 🔧 Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/mashkurulalamohi37/BaustEvent.git
   cd BaustEvent
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**
   - Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/)
   - Enable Authentication, Firestore, Storage, and Realtime Database
   - Download `google-services.json` for Android and place it in `android/app/`
   - Download `GoogleService-Info.plist` for iOS and place it in `ios/Runner/`

4. **Configure Firebase**
   - Update Firebase configuration in your project
   - Set up authentication providers (Email/Password, Google, etc.)

5. **Run the app**
   ```bash
   flutter run
   ```

## 📁 Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── event.dart
│   └── user.dart
├── screens/                  # UI screens
│   ├── auth_screen.dart
│   ├── create_event_screen.dart
│   ├── edit_event_screen.dart
│   ├── edit_profile_screen.dart
│   ├── event_details_screen.dart
│   ├── login_screen.dart
│   ├── manage_participants_screen.dart
│   ├── organizer_dashboard.dart
│   ├── participant_dashboard.dart
│   ├── qr_code_screen.dart
│   └── welcome_screen.dart
├── services/                 # Business logic and API calls
│   ├── demo_data_service.dart
│   ├── event_service.dart
│   ├── firebase_demo_data_service.dart
│   ├── firebase_event_service.dart
│   ├── firebase_notification_service.dart
│   ├── firebase_realtime_service.dart
│   ├── firebase_storage_service.dart
│   ├── firebase_user_service.dart
│   ├── qr_service.dart
│   └── user_service.dart
└── widgets/                  # Reusable UI components
    ├── category_card.dart
    ├── custom_text_field.dart
    └── event_card.dart
```

## 🔐 Firebase Configuration

### Authentication
- Email/Password authentication
- User profile management
- Role-based access control

### Firestore Database
- Events collection
- Users collection
- Participants collection

### Cloud Storage
- Event images
- User profile pictures
- QR code images

### Realtime Database
- Live event updates
- Real-time participant tracking

## 🎨 UI/UX Features

- **Modern Design**: Material Design 3 with custom gradients
- **Responsive Layout**: Adapts to different screen sizes
- **Smooth Animations**: Fluid transitions and micro-interactions
- **Dark/Light Theme**: Support for both themes
- **Accessibility**: Screen reader support and high contrast options

## 📱 Platform Support

- ✅ Android
- ✅ iOS
- ✅ Web
- ✅ Windows
- ✅ macOS
- ✅ Linux

## 🚀 Getting Started

1. **First Time Setup**
   - Register as a new user
   - Complete your profile setup
   - Choose your role (Organizer/Participant)

2. **For Organizers**
   - Create your first event
   - Set event details, date, and location
   - Generate QR codes for check-ins
   - Manage participant registrations

3. **For Participants**
   - Browse available events
   - Register for events
   - Use QR codes for quick check-ins
   - View your event history

## 🔧 Development

### Running Tests
```bash
flutter test
```

### Building for Production
```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

### Code Analysis
```bash
flutter analyze
```

## 📝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 🐛 Known Issues

- Firebase initialization may take a few seconds on first launch
- QR code scanning requires camera permissions
- Offline mode has limited functionality

## 🔮 Future Enhancements

- [ ] Push notifications for event updates
- [ ] Social media integration
- [ ] Event analytics and reporting
- [ ] Multi-language support
- [ ] Advanced search and filtering
- [ ] Event templates
- [ ] Calendar integration
- [ ] Payment integration for paid events

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👥 Authors

- **Mashkurul Alam Mohi** - *Initial work* - [mashkurulalamohi37](https://github.com/mashkurulalamohi37)

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Firebase team for backend services
- Material Design team for UI guidelines
- Open source community for various packages

## 📞 Support

If you have any questions or need help, please:

1. Check the [Issues](https://github.com/mashkurulalamohi37/BaustEvent/issues) page
2. Create a new issue if your problem isn't already reported
3. Contact the maintainer

---

