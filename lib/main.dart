import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'screens/welcome_screen.dart';
import 'screens/organizer_dashboard.dart';
import 'screens/participant_dashboard.dart';
import 'screens/admin_dashboard.dart';
import 'services/firebase_user_service.dart';
import 'services/firebase_notification_service.dart';
import 'services/theme_service.dart';
import 'models/user.dart';

// NavigatorObserver to dismiss keyboard on route changes
class KeyboardDismissingObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _dismissKeyboard();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _dismissKeyboard();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _dismissKeyboard();
  }

  void _dismissKeyboard() {
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    const Color(0xFF0D47A1),
                    const Color(0xFF1565C0),
                  ]
                : [
                    const Color(0xFF1976D2),
                    const Color(0xFF42A5F5),
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
  
  // Initialize Firebase - critical for app functionality
  bool firebaseInitialized = false;
  try {
    // Check if Firebase is already initialized (especially important for web hot reload)
    if (Firebase.apps.isEmpty) {
      print('Initializing Firebase...');
      // Initialize Firebase with platform-specific options
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      firebaseInitialized = true;
      print('Firebase initialized successfully');
    } else {
      firebaseInitialized = true;
      print('Firebase already initialized (${Firebase.apps.length} app(s))');
    }
    
    // Initialize notifications (non-blocking - don't wait if it fails)
    // Skip on web as notifications work differently
    if (!kIsWeb && firebaseInitialized) {
      FirebaseNotificationService.initialize().catchError((e) {
        print('Notification initialization failed (non-critical): $e');
      });
    }
  } catch (e, stackTrace) {
    print('Firebase initialization failed: $e');
    print('Error type: ${e.runtimeType}');
    print('Stack trace: $stackTrace');
    // On web, this might be a configuration issue
    if (kIsWeb) {
      print('⚠️ Web Firebase initialization error. Make sure Firebase is configured for web.');
      print('For web, you may need to add Firebase configuration to web/index.html');
    }
    firebaseInitialized = false;
    // Don't continue if Firebase fails - it's critical
    // The app will show errors when trying to use Firebase services
  }
  
  // Store initialization status for later checks
  if (!firebaseInitialized) {
    print('⚠️ WARNING: Firebase initialization failed. Some features may not work.');
  }
  
  // Run the app after initialization
  runApp(const EventBridgeApp());
}

class EventBridgeApp extends StatefulWidget {
  const EventBridgeApp({super.key});

  @override
  State<EventBridgeApp> createState() => _EventBridgeAppState();
}

class _EventBridgeAppState extends State<EventBridgeApp> {
  late final ThemeService _themeService;

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService(); // Uses singleton pattern
  }

  @override
  void dispose() {
    // Don't dispose singleton - it's shared
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _themeService,
      builder: (context, child) {
        final isDark = _themeService.isDarkMode;
        return MaterialApp(
          key: ValueKey('theme_$isDark'), // Force rebuild on theme change
          title: 'EventBridge',
          theme: ThemeService.lightTheme,
          darkTheme: ThemeService.darkTheme,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          home: const AuthWrapper(),
          debugShowCheckedModeBanner: false,
          navigatorObservers: [KeyboardDismissingObserver()],
        );
      },
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
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkAuthState() async {
    try {
      // Check if user is already logged in with timeout to prevent hanging
      final user = await FirebaseUserService.getCurrentUserWithDetails()
          .timeout(
            const Duration(seconds: 5), // Reduced timeout
            onTimeout: () {
              print('Auth check timed out - proceeding without user');
              return null;
            },
          );
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
          _currentUser = null; // Ensure we proceed to welcome screen
        });
      }
    }
    
    // Safety fallback - if still loading after 6 seconds, force proceed
    _timeoutTimer?.cancel(); // Cancel any existing timer
    _timeoutTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && _isLoading) {
        print('Force proceeding after timeout');
        setState(() {
          _isLoading = false;
          _currentUser = null;
        });
      }
    });
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
