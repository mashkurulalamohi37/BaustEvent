import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
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
      final firebaseAuth = firebase_auth.FirebaseAuth.instance;
      
      // Wait for the first auth state change event to ensure Firebase Auth has restored the session
      // This is important because on app restart, Firebase Auth needs time to restore from local storage
      try {
        // Wait for auth state to be ready (first event from stream)
        // Use timeout to fallback to direct check if stream doesn't fire quickly
        firebase_auth.User? firebaseUser;
        try {
          firebaseUser = await firebaseAuth.authStateChanges()
              .timeout(const Duration(seconds: 3))
              .first;
        } catch (e) {
          // If stream times out or doesn't fire, check currentUser directly
          // This handles cases where session is already restored
          print('Auth state stream timeout, checking currentUser directly: $e');
          firebaseUser = firebaseAuth.currentUser;
        }
        
        if (!mounted) return;
        
        if (firebaseUser == null) {
          // No Firebase Auth user - user is logged out
          setState(() {
            _currentUser = null;
            _isLoading = false;
          });
          return;
        }
        
        // User exists in Firebase Auth - get full details from Firestore
        try {
          final user = await FirebaseUserService.getCurrentUserWithDetails()
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  print('Auth check timed out - but user is authenticated, keeping session');
                  // Return a basic user object to maintain session
                  return User(
                    id: firebaseUser!.uid,
                    email: firebaseUser.email ?? '',
                    name: 'Loading...',
                    universityId: '',
                    type: UserType.participant,
                    createdAt: DateTime.now(),
                  );
                },
              );
          
          if (mounted) {
            setState(() {
              _currentUser = user;
              _isLoading = false;
            });
          }
        } catch (e) {
          print('Error fetching user details, but user is authenticated: $e');
          // User is authenticated in Firebase Auth, but couldn't fetch details
          // Keep them logged in with basic info
          if (mounted) {
            setState(() {
              _currentUser = User(
                id: firebaseUser!.uid,
                email: firebaseUser.email ?? '',
                name: 'Loading...',
                universityId: '',
                type: UserType.participant,
                createdAt: DateTime.now(),
              );
              _isLoading = false;
            });
          }
        }
      } catch (e) {
        print('Error waiting for auth state: $e');
        // Fallback to direct check
        _fallbackAuthCheck();
      }
    } catch (e) {
      print('Error setting up auth state check: $e');
      _fallbackAuthCheck();
    }
  }
  
  void _fallbackAuthCheck() {
    try {
      final firebaseAuth = firebase_auth.FirebaseAuth.instance;
      final firebaseUser = firebaseAuth.currentUser;
      
      if (mounted) {
        if (firebaseUser != null) {
          // User is authenticated - keep them logged in
          setState(() {
            _currentUser = User(
              id: firebaseUser.uid,
              email: firebaseUser.email ?? '',
              name: 'Loading...',
              universityId: '',
              type: UserType.participant,
              createdAt: DateTime.now(),
            );
            _isLoading = false;
          });
          
          // Try to get full user details in background
          FirebaseUserService.getCurrentUserWithDetails().then((user) {
            if (mounted && user != null) {
              setState(() {
                _currentUser = user;
              });
            }
          }).catchError((e) {
            print('Error fetching user details in background: $e');
          });
        } else {
          // No user in Firebase Auth
          setState(() {
            _isLoading = false;
            _currentUser = null;
          });
        }
      }
    } catch (e) {
      print('Error in fallback auth check: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentUser = null;
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
