# EventBridge - Flutter App Structure

## Project Overview
EventBridge is a Flutter-based cross-platform mobile app for university event management. It allows students to discover, register, and attend events digitally, while organizers can manage participants efficiently.

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── event.dart           # Event model and enums
│   └── user.dart            # User model and enums
├── screens/                 # UI screens
│   ├── welcome_screen.dart  # Welcome/landing screen
│   ├── auth_screen.dart     # Authentication screen
│   ├── participant_dashboard.dart  # Student dashboard
│   └── organizer_dashboard.dart    # Organizer dashboard
└── widgets/                 # Reusable UI components
    ├── event_card.dart      # Event display card
    ├── category_card.dart   # Category selection card
    └── custom_text_field.dart # Custom text input field
```

## Features

### For Participants (Students):
- User Authentication with university ID
- Event Discovery & Registration
- Personal Dashboard with registered events
- Event Search functionality
- QR Code generation for event check-in

### For Event Organizers:
- Event Creation & Management
- Participant Management with QR code scanning
- Organizer Dashboard with analytics
- Event status tracking

## Key Components

### Screens
- **WelcomeScreen**: Landing page with app introduction
- **AuthScreen**: Login/signup with form validation
- **ParticipantDashboard**: Student interface with bottom navigation
- **OrganizerDashboard**: Organizer interface with event management

### Widgets
- **EventCard**: Reusable event display component
- **CategoryCard**: Category selection component
- **CustomTextField**: Styled text input field

### Models
- **Event**: Event data structure with status and category enums
- **User**: User data structure with type differentiation

## Design Principles
- Clean and modern Material Design 3
- Consistent color scheme (Blue primary)
- Responsive layout for different screen sizes
- Intuitive navigation patterns
- Reusable component architecture

## Next Steps
- Integrate Firebase for backend services
- Add QR code scanning functionality
- Implement push notifications
- Add data persistence
- Create event creation forms
- Add search and filtering capabilities
