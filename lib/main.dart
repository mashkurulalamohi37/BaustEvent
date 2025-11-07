import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/welcome_screen.dart';
import 'screens/organizer_dashboard.dart';
import 'screens/participant_dashboard.dart';
import 'screens/admin_dashboard.dart';
import 'services/firebase_user_service.dart';
import 'services/firebase_notification_service.dart';
import 'models/user.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1976D2),
              Color(0xFF42A5F5),
            ],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              SizedBox(height: 24),
              Text(
                'Initializing EventBridge...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Show loading screen immediately
  runApp(const MaterialApp(
    home: LoadingScreen(),
    debugShowCheckedModeBanner: false,
  ));
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp();
    print('Firebase initialized');
    
    // Initialize notifications (non-blocking - don't wait if it fails)
    FirebaseNotificationService.initialize().catchError((e) {
      print('Notification initialization failed (non-critical): $e');
    });
  } catch (e) {
    print('Firebase initialization failed: $e');
  }
  
  // After initialization, show the main app
  runApp(const EventBridgeApp());
}

class EventBridgeApp extends StatefulWidget {
  const EventBridgeApp({super.key});

  @override
  State<EventBridgeApp> createState() => _EventBridgeAppState();
}

class _EventBridgeAppState extends State<EventBridgeApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EventBridge',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    try {
      // Check if user is already logged in
      final user = await FirebaseUserService.getCurrentUserWithDetails();
      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error checking auth state: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingScreen();
    }

    // If user is logged in, go to their dashboard
    if (_currentUser != null) {
      if (_currentUser!.isAdmin) {
        return AdminDashboard(userId: _currentUser!.id);
      } else if (_currentUser!.type == UserType.organizer) {
        return OrganizerDashboard(userId: _currentUser!.id);
      } else {
        return ParticipantDashboard(userId: _currentUser!.id);
      }
    }

    // Otherwise, show welcome screen
    return const WelcomeScreen();
  }
}
