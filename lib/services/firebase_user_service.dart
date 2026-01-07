import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/user.dart';
import '../firebase_options.dart';
import '../utils/data_cache.dart';

class FirebaseUserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  static CollectionReference<Map<String, dynamic>> get _usersCol =>
      _firestore.collection('users');

  // Local parsing helpers (cannot use private helpers from user.dart)
  static UserType _parseUserTypeAny(dynamic raw) {
    if (raw is UserType) return raw;
    if (raw is String) {
      final lower = raw.toLowerCase();
      for (final v in UserType.values) {
        if (v.name.toLowerCase() == lower) return v;
      }
      if (lower == 'org' || lower == 'admin' || lower == 'organiser') {
        return UserType.organizer;
      }
      return UserType.participant;
    }
    if (raw is int) {
      if (raw >= 0 && raw < UserType.values.length) {
        return UserType.values[raw];
      }
    }
    return UserType.participant;
  }

  static DateTime? _parseDateAny(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    try {
      final toDate = raw.toDate();
      if (toDate is DateTime) return toDate;
    } catch (_) {}
    return null;
  }

  // Get current user from Firebase Auth
  static User? getCurrentUser() {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;
    // Note: This returns null because we need to fetch from Firestore
    // Use getCurrentUserWithDetails() instead
    return null;
  }

  // Get current user with details from Firestore
  static Future<User?> getCurrentUserWithDetails() async {
    try {
      // Check if Firebase is initialized
      if (Firebase.apps.isEmpty) {
        print('Firebase not initialized, attempting to initialize...');
        await Firebase.initializeApp();
      }
      
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) return null;
      
      return await getUserById(firebaseUser.uid);
    } catch (e) {
      print('Error in getCurrentUserWithDetails: $e');
      // If Firebase is not initialized, return null
      if (e.toString().contains('No Firebase App') || 
          e.toString().contains('no-app')) {
        print('Firebase not initialized. Please restart the app.');
        return null;
      }
      rethrow;
    }
  }

  // Get user by ID from Firestore (with caching)
  static Future<User?> getUserById(String userId) async {
    try {
      // Check cache first
      final cache = DataCache();
      final cachedUser = cache.getUser(userId);
      if (cachedUser != null) {
        return cachedUser;
      }
      
      // Ensure Firebase is initialized
      if (Firebase.apps.isEmpty) {
        print('Firebase not initialized in getUserById, initializing now...');
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      
      final doc = await _usersCol.doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        if (data == null) {
          return null;
        }
        final user = User(
          id: doc.id,
          email: (data['email'] as String?) ?? '',
          name: (data['name'] as String?) ?? '',
          universityId: (data['universityId'] as String?) ?? '',
          type: _parseUserTypeAny(data['type'] ?? 'participant'),
          profileImageUrl: data['profileImageUrl'] as String?,
          createdAt: _parseDateAny(data['createdAt']) ?? DateTime.now(),
          lastLoginAt: _parseDateAny(data['lastLoginAt']),
        );
        
        // Cache the user
        cache.cacheUser(user);
        return user;
      }
      return null;
    } catch (e) {
      print('Error getting user by ID: $e');
      return null;
    }
  }

  // Sign in with email and password using Firebase Authentication
  // Handles migration of old Firestore-only accounts to Firebase Auth
  static Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      // Ensure Firebase is initialized before attempting sign-in
      if (Firebase.apps.isEmpty) {
        print('Firebase not initialized during sign-in, initializing now...');
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        print('Firebase initialized during sign-in');
      }
      
      // Authenticate with Firebase Auth (validates password)
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      
      if (credential.user == null) {
        return null;
      }
      
      // Get user profile from Firestore
      final userId = credential.user?.uid;
      if (userId == null) {
        return null;
      }
      final userDoc = await _usersCol.doc(userId).get();
      
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data == null) {
          return null;
        }
        // Update last login time
        await _usersCol.doc(userId).update({
          'lastLoginAt': DateTime.now().toIso8601String(),
        });
        
        return User(
          id: userId,
          email: (data['email'] as String?) ?? email,
          name: (data['name'] as String?) ?? '',
          universityId: (data['universityId'] as String?) ?? '',
          type: _parseUserTypeAny(data['type'] ?? 'participant'),
          profileImageUrl: data['profileImageUrl'] as String?,
          createdAt: _parseDateAny(data['createdAt']) ?? DateTime.now(),
          lastLoginAt: DateTime.now(),
        );
      }
      
      return null;
    } on firebase_auth.FirebaseAuthException catch (e) {
      print('Firebase Auth error: ${e.code} - ${e.message}');
      print('Full error details: $e');
      
      // Handle authentication errors with more specific messages
      if (e.code == 'user-not-found') {
        throw Exception('No account found with this email. Please sign up first.');
      } else if (e.code == 'wrong-password') {
        throw Exception('Invalid password. Please try again.');
      } else if (e.code == 'invalid-email') {
        throw Exception('Invalid email address.');
      } else if (e.code == 'user-disabled') {
        throw Exception('This account has been disabled.');
      } else if (e.code == 'too-many-requests') {
        throw Exception('Too many failed attempts. Please try again later.');
      } else if (e.code == 'network-request-failed') {
        throw Exception('Network error. Please check your internet connection and try again.');
      } else if (e.code == 'operation-not-allowed') {
        throw Exception('Email/password sign-in is not enabled. Please contact support.');
      } else {
        // Show the actual error code for debugging
        throw Exception('Sign-in failed: ${e.code}. ${e.message ?? "Please try again."}');
      }
    } catch (e) {
      // Re-throw migration exception as-is
      if (e.toString().contains('ACCOUNT_MIGRATION_NEEDED')) {
        rethrow;
      }
      print('Error signing in: $e');
      print('Error type: ${e.runtimeType}');
      // Provide more detailed error message
      final errorString = e.toString();
      
      // Check for Firebase initialization errors
      if (errorString.contains('No Firebase App') || 
          errorString.contains('no-app') ||
          errorString.contains('Firebase.initializeApp')) {
        // Try to initialize Firebase
        try {
          if (Firebase.apps.isEmpty) {
            print('Attempting to initialize Firebase after error...');
            await Firebase.initializeApp();
            print('Firebase initialized successfully');
            throw Exception('Firebase was not initialized. Please try signing in again.');
          }
        } catch (initError) {
          print('Failed to initialize Firebase: $initError');
          throw Exception('Firebase initialization failed. Please restart the app and try again.');
        }
      }
      
      if (errorString.contains('network') || errorString.contains('Network')) {
        throw Exception('Network error. Please check your internet connection.');
      } else if (errorString.contains('permission') || errorString.contains('Permission')) {
        throw Exception('Permission denied. Please check your Firestore security rules.');
      } else {
        throw Exception('Error signing in: ${e.toString().replaceFirst('Exception: ', '')}');
      }
    }
  }

  static Future<User?> signInWithGoogle({bool isLoginMode = false}) async {
    try {
      final googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null; // User canceled

      final googleAuth = await googleUser.authentication;
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await firebase_auth.FirebaseAuth.instance.signInWithCredential(credential);
      final fbUser = userCredential.user;
      if (fbUser == null) return null;

      // Check if user document exists
      final userDoc = await _usersCol.doc(fbUser.uid).get();
      
      User? appUser;
      
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null) {
          appUser = User(
              id: userDoc.id,
              email: data['email'] ?? fbUser.email ?? '',
              name: data['name'] ?? fbUser.displayName ?? '',
              universityId: data['universityId'] ?? '',
              type: _parseUserTypeAny(data['type']),
              profileImageUrl: data['profileImageUrl'] ?? fbUser.photoURL,
              createdAt: _parseDateAny(data['createdAt']) ?? DateTime.now(),
              lastLoginAt: DateTime.now(),
          );
          // Update last login
          await _usersCol.doc(appUser.id).update({
             'lastLoginAt': DateTime.now().toIso8601String(),
          });
        }
      } else {
        if (isLoginMode) {
          // If trying to login but no account exists, prevent access
          await googleSignIn.signOut();
          await _auth.signOut();
          throw Exception('No account found. Please sign up first.');
        }

        // Create new user
        appUser = User(
            id: fbUser.uid,
            email: fbUser.email ?? '',
            name: fbUser.displayName ?? 'Google User',
            universityId: '', 
            type: UserType.participant,
            profileImageUrl: fbUser.photoURL,
            createdAt: DateTime.now(),
            lastLoginAt: DateTime.now(),
        );
        
        await _usersCol.doc(appUser.id).set({
          'email': appUser.email,
          'name': appUser.name,
          'universityId': appUser.universityId,
          'type': 'participant',
          'profileImageUrl': appUser.profileImageUrl,
          'createdAt': appUser.createdAt.toIso8601String(),
          'lastLoginAt': appUser.lastLoginAt?.toIso8601String(),
        });
      }
      
      // Cache user
      if (appUser != null) {
         DataCache().cacheUser(appUser);
      }
      return appUser;
      
    } catch (e) {
      print('Google Sign In Error: $e');
      throw Exception('Google Sign-In failed: $e');
    }
  }

  // Check if email already exists (case-insensitive)
  static Future<bool> emailExists(String email) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      print('Checking if email exists in Firestore: $normalizedEmail');
      
      // Try exact match first (for new accounts stored in lowercase)
      var querySnapshot = await _usersCol.where('email', isEqualTo: normalizedEmail).limit(1).get();
      
      if (querySnapshot.docs.isNotEmpty) {
        print('Found email in Firestore (exact match)');
        return true;
      }
      
      // If not found, get all users and check case-insensitively (for old accounts)
      // This handles old accounts that might have mixed-case emails
      final allUsers = await _usersCol.get();
      for (var doc in allUsers.docs) {
        final data = doc.data();
        final storedEmail = (data['email'] as String? ?? '').trim().toLowerCase();
        if (storedEmail == normalizedEmail) {
          print('Found email in Firestore (case-insensitive match): ${data['email']}');
          return true;
        }
      }
      
      print('Email not found in Firestore');
      return false;
    } catch (e) {
      print('Error checking if email exists: $e');
      return false;
    }
  }

  // Create user with email and password using Firebase Authentication
  // NOTE: If user wants to be organizer, creates a request instead of direct organizer account
  static Future<User?> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String universityId,
    required UserType type,
  }) async {
    try {
      // Ensure Firebase is initialized before attempting sign-up
      if (Firebase.apps.isEmpty) {
        print('Firebase not initialized during sign-up, initializing now...');
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        print('Firebase initialized during sign-up');
      }
      
      print('Attempting to create user with email: $email');
      
      // Create user in Firebase Authentication
      // This will automatically reject duplicate emails and throw FirebaseAuthException
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      
      if (credential.user == null) {
        throw Exception('Failed to create user account.');
      }
      
      
      final userId = credential.user?.uid;
      if (userId == null) {
        throw Exception('Failed to get user ID from credential.');
      }

      print('Creating user document with ID: $userId');
      
      // If user wants to be organizer, create as participant first and create organizer request
      final actualType = type == UserType.organizer ? UserType.participant : type;
      
      final user = User(
        id: userId,
        email: email.toLowerCase().trim(), // Normalize email to lowercase
        name: name,
        universityId: universityId,
        type: actualType, // Create as participant if organizer requested
        createdAt: DateTime.now(),
      );

      // Create profile in Firestore
      final userData = {
        'id': user.id,
        'email': user.email.toLowerCase().trim(), // Store email in lowercase for consistency
        'name': user.name,
        'universityId': user.universityId,
        'type': user.type.name,
        'profileImageUrl': user.profileImageUrl,
        'createdAt': user.createdAt.toIso8601String(),
        'lastLoginAt': user.lastLoginAt?.toIso8601String(),
      };
      
      print('Writing to Firestore: $userData');
      await _usersCol.doc(user.id).set(userData);
      print('User document written successfully');

      // If organizer was requested, create an organizer request
      // Wait a bit to ensure user document is fully committed
      if (type == UserType.organizer) {
        print('Creating organizer request for user: $userId');
        try {
          // Small delay to ensure user document is fully committed
          await Future.delayed(const Duration(milliseconds: 500));
          await createOrganizerRequest(userId, email.toLowerCase().trim(), name, universityId);
          print('Organizer request created successfully');
        } catch (e, stackTrace) {
          print('=== CRITICAL ERROR: Failed to create organizer request ===');
          print('Error: $e');
          print('Error type: ${e.runtimeType}');
          print('Stack trace: $stackTrace');
          print('User ID: $userId');
          print('Email: $email');
          print('Name: $name');
          print('University ID: $universityId');
          print('==========================================================');
          // Don't fail user creation, but log extensively
          // The user account is created, but the organizer request failed
          // This will be visible in logs and can be debugged
        }
      }

      print('User created successfully with ID: ${user.id}');
      return user;
    } on firebase_auth.FirebaseAuthException catch (e) {
      print('Firebase Auth error: ${e.code} - ${e.message}');
      // Re-throw with user-friendly message
      if (e.code == 'email-already-in-use') {
        throw Exception('An account with this email already exists. Please sign in instead.');
      } else if (e.code == 'invalid-email') {
        throw Exception('Invalid email address.');
      } else if (e.code == 'weak-password') {
        throw Exception('Password is too weak. Please use a stronger password.');
      } else {
        throw Exception('Failed to create account: ${e.message}');
      }
    } catch (e, stackTrace) {
      print('=== ERROR CREATING USER ===');
      print('Error: $e');
      print('Error type: ${e.runtimeType}');
      print('Stack trace: $stackTrace');
      print('==========================');
      
      // Re-throw with detailed error message
      throw Exception('Error creating user: ${e.toString()}');
    }
  }

  // Sign out
  static Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (e) {
      print('Error signing out from Google: $e');
    }
    await _auth.signOut();
  }

  // Send password reset email
  static Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(
        email: email.trim().toLowerCase(),
      );
    } on firebase_auth.FirebaseAuthException catch (e) {
      print('Password reset error: ${e.code} - ${e.message}');
      // Re-throw with user-friendly message
      if (e.code == 'user-not-found') {
        throw Exception('No account found with this email address.');
      } else if (e.code == 'invalid-email') {
        throw Exception('Invalid email address.');
      } else {
        throw Exception('Failed to send password reset email: ${e.message}');
      }
    } catch (e) {
      print('Error sending password reset email: $e');
      throw Exception('Error sending password reset email. Please try again.');
    }
  }

  // Change password (requires reauthentication)
  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in.');
      }

      if (user.email == null) {
        throw Exception('User email is not available.');
      }

      // Reauthenticate user with current password
      final credential = firebase_auth.EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(newPassword);

      print('Password changed successfully');
    } on firebase_auth.FirebaseAuthException catch (e) {
      print('Password change error: ${e.code} - ${e.message}');
      // Re-throw with user-friendly message
      if (e.code == 'wrong-password') {
        throw Exception('Current password is incorrect. Please try again.');
      } else if (e.code == 'weak-password') {
        throw Exception('New password is too weak. Please use a stronger password.');
      } else if (e.code == 'requires-recent-login') {
        throw Exception('Please sign out and sign in again before changing your password.');
      } else if (e.code == 'user-mismatch') {
        throw Exception('Authentication error. Please try again.');
      } else {
        throw Exception('Failed to change password: ${e.message ?? e.code}');
      }
    } catch (e) {
      print('Error changing password: $e');
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('Error changing password. Please try again.');
    }
  }

  // Delete user from Firebase Authentication
  // Note: This only works for the currently authenticated user
  // To delete other users, you need Firebase Admin SDK (backend/Cloud Function)
  static Future<bool> deleteAuthUser(String userId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('No user is currently authenticated');
        return false;
      }
      
      // Only allow deleting if it's the current user
      if (currentUser.uid != userId) {
        print('Cannot delete other users from client SDK. User ID mismatch: ${currentUser.uid} != $userId');
        return false;
      }
      
      // Delete the authenticated user
      await currentUser.delete();
      print('Firebase Auth user deleted successfully: $userId');
      return true;
    } catch (e) {
      print('Error deleting Firebase Auth user: $e');
      return false;
    }
  }

  // Firestore-backed operations
  // Get all users with pagination support (for better performance with 500+ users)
  static Future<List<User>> getAllUsers({int? limit, DocumentSnapshot? startAfter}) async {
    try {
      // Check cache if loading first page without pagination
      if (limit == null && startAfter == null) {
        final cache = DataCache();
        final cachedUsers = cache.getAllUsers();
        if (cachedUsers != null) {
          return cachedUsers;
        }
      }
      
      Query<Map<String, dynamic>> query = _usersCol;
      
      // Apply pagination if provided
      if (limit != null) {
        query = query.limit(limit);
      }
      
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }
      
      final snap = await query.get();
      final users = snap.docs.map((d) {
        final data = d.data();
        return User(
          id: d.id,
          email: (data['email'] as String?) ?? '',
          name: (data['name'] as String?) ?? '',
          universityId: (data['universityId'] as String?) ?? '',
          type: _parseUserTypeAny(data['type'] ?? 'participant'),
          profileImageUrl: data['profileImageUrl'] as String?,
          createdAt: _parseDateAny(data['createdAt']) ?? DateTime.now(),
          lastLoginAt: _parseDateAny(data['lastLoginAt']),
        );
      }).toList();
      
      // Cache users if loading first page
      if (limit == null && startAfter == null) {
        final cache = DataCache();
        cache.cacheAllUsers(users);
      } else {
        // Cache individual users
        final cache = DataCache();
        cache.cacheUsers(users);
      }
      
      return users;
    } catch (e) {
      print('Error getting users: $e');
      return [];
    }
  }
  
  // Get all users (backward compatibility - loads in chunks for performance)
  static Future<List<User>> getAllUsersFull() async {
    // Check cache first
    final cache = DataCache();
    final cachedUsers = cache.getAllUsers();
    if (cachedUsers != null) {
      return cachedUsers;
    }
    
    final List<User> allUsers = [];
    const chunkSize = 500; // Load in chunks of 500
    DocumentSnapshot? lastDoc;
    
    while (true) {
      Query<Map<String, dynamic>> query = _usersCol.limit(chunkSize);
      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }
      
      final snap = await query.get();
      if (snap.docs.isEmpty) break;
      
      final users = snap.docs.map((d) {
        final data = d.data();
        return User(
          id: d.id,
          email: (data['email'] as String?) ?? '',
          name: (data['name'] as String?) ?? '',
          universityId: (data['universityId'] as String?) ?? '',
          type: _parseUserTypeAny(data['type'] ?? 'participant'),
          profileImageUrl: data['profileImageUrl'] as String?,
          createdAt: _parseDateAny(data['createdAt']) ?? DateTime.now(),
          lastLoginAt: _parseDateAny(data['lastLoginAt']),
        );
      }).toList();
      
      allUsers.addAll(users);
      
      if (snap.docs.length < chunkSize) break; // Last chunk
      
      lastDoc = snap.docs.last;
    }
    
    // Cache all users
    cache.cacheAllUsers(allUsers);
    
    return allUsers;
  }

  // Get users by IDs in batches (Firestore limit is 10 per whereIn query)
  // Optimized for 500+ users with parallel batch loading and caching
  static Future<List<User>> getUsersByIds(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    
    final cache = DataCache();
    final List<User> users = [];
    final List<String> uncachedIds = [];
    
    // Check cache first
    for (var userId in userIds) {
      final cachedUser = cache.getUser(userId);
      if (cachedUser != null) {
        users.add(cachedUser);
      } else {
        uncachedIds.add(userId);
      }
    }
    
    // If all users are cached, return immediately
    if (uncachedIds.isEmpty) {
      return users;
    }
    
    const batchSize = 10; // Firestore whereIn limit
    
    // For large lists (100+), process batches in parallel for better performance
    if (uncachedIds.length > 100) {
      // Process batches in parallel (up to 5 concurrent batches)
      final batches = <List<String>>[];
      for (int i = 0; i < uncachedIds.length; i += batchSize) {
        batches.add(uncachedIds.skip(i).take(batchSize).toList());
      }
      
      // Process up to 5 batches in parallel
      const maxConcurrent = 5;
      for (int i = 0; i < batches.length; i += maxConcurrent) {
        final batchGroup = batches.skip(i).take(maxConcurrent).toList();
        final results = await Future.wait(
          batchGroup.map((batch) => _loadUserBatch(batch)),
        );
        
        for (var batchUsers in results) {
          users.addAll(batchUsers);
          // Cache the loaded users
          cache.cacheUsers(batchUsers);
        }
      }
    } else {
      // For smaller lists, process sequentially
      for (int i = 0; i < uncachedIds.length; i += batchSize) {
        final batch = uncachedIds.skip(i).take(batchSize).toList();
        final batchUsers = await _loadUserBatch(batch);
        users.addAll(batchUsers);
        // Cache the loaded users
        cache.cacheUsers(batchUsers);
      }
    }
    
    return users;
  }
  
  // Helper method to load a single batch of users
  static Future<List<User>> _loadUserBatch(List<String> batch) async {
    try {
      final snap = await _usersCol.where(FieldPath.documentId, whereIn: batch).get();
      return snap.docs.map((doc) {
        final data = doc.data();
        return User(
          id: doc.id,
          email: (data['email'] as String?) ?? '',
          name: (data['name'] as String?) ?? '',
          universityId: (data['universityId'] as String?) ?? '',
          type: _parseUserTypeAny(data['type'] ?? 'participant'),
          profileImageUrl: data['profileImageUrl'] as String?,
          createdAt: _parseDateAny(data['createdAt']) ?? DateTime.now(),
          lastLoginAt: _parseDateAny(data['lastLoginAt']),
        );
      }).toList();
    } catch (e) {
      print('Error loading user batch: $e');
      return []; // Return empty list on error, continue with other batches
    }
  }

  // Create user profile in Firestore
  static Future<bool> createUser(User user) async {
    try {
      await _usersCol.doc(user.id).set({
        'email': user.email,
        'name': user.name,
        'universityId': user.universityId,
        'type': user.type.name,
        'profileImageUrl': user.profileImageUrl,
        'createdAt': user.createdAt.toIso8601String(),
        'lastLoginAt': user.lastLoginAt?.toIso8601String(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Update user profile in Firestore
  static Future<bool> updateUser(User user) async {
    try {
      await _usersCol.doc(user.id).update({
        'email': user.email,
        'name': user.name,
        'universityId': user.universityId,
        'type': user.type.name,
        'profileImageUrl': user.profileImageUrl,
        'lastLoginAt': user.lastLoginAt?.toIso8601String(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Auth state changes
  static Stream<User?> get authStateChanges {
    return _auth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;
      return await getUserById(firebaseUser.uid);
    });
  }

  // Ensure current Firebase Auth user has a Firestore profile document (Authentication removed - no-op)
  static Future<void> ensureCurrentUserDocument() async {
    // Authentication removed - nothing to ensure
  }
  
  // Organizer Request Management
  static CollectionReference<Map<String, dynamic>> get _organizerRequestsCol =>
      _firestore.collection('organizer_requests');
  
  // Create organizer request
  static Future<void> createOrganizerRequest(
    String userId,
    String email,
    String name,
    String universityId,
  ) async {
    try {
      print('=== CREATING ORGANIZER REQUEST ===');
      print('UserId: $userId');
      print('Email: $email');
      print('Name: $name');
      print('Current authenticated user: ${_auth.currentUser?.uid}');
      
      // On web, currentUser might not be immediately available after sign up
      // Retry a few times with delays to ensure auth state is ready
      firebase_auth.User? currentUser = _auth.currentUser;
      int retryCount = 0;
      const maxRetries = 5;
      
      while (currentUser == null && retryCount < maxRetries) {
        print('Auth user not ready, waiting... (attempt ${retryCount + 1}/$maxRetries)');
        await Future.delayed(Duration(milliseconds: 200 * (retryCount + 1)));
        currentUser = _auth.currentUser;
        retryCount++;
      }
      
      // Verify user is authenticated
      if (currentUser == null) {
        print('WARNING: User is not authenticated after $maxRetries retries. Creating request without auth check.');
        // On web, this might happen but we can still create the request
        // using the provided userId since we just created the account
      } else if (currentUser.uid != userId) {
        throw Exception('User ID mismatch. Authenticated: ${currentUser.uid}, Provided: $userId');
      }
      
      final requestData = {
        'userId': userId,
        'email': email.toLowerCase().trim(),
        'name': name,
        'universityId': universityId,
        'status': 'pending', // pending, approved, rejected
        'requestedAt': DateTime.now().toIso8601String(),
        'reviewedAt': null,
        'reviewedBy': null,
      };
      
      print('Request data: $requestData');
      final docRef = await _organizerRequestsCol.add(requestData);
      print('Organizer request created successfully with ID: ${docRef.id}');
      
      // Verify the document was actually created
      final verifyDoc = await docRef.get();
      final docExists = verifyDoc.exists ?? false;
      if (!docExists) {
        throw Exception('Request document was not created. Document ID: ${docRef.id}');
      }
      
      print('Verified: Request document exists in Firestore');
      print('===================================');
    } catch (e, stackTrace) {
      print('=== ERROR CREATING ORGANIZER REQUEST ===');
      print('Error: $e');
      print('Error type: ${e.runtimeType}');
      print('Stack trace: $stackTrace');
      print('UserId: $userId');
      print('Email: $email');
      print('Current authenticated user: ${_auth.currentUser?.uid}');
      print('========================================');
      rethrow;
    }
  }
  
  // Check if a user has a pending organizer request
  static Future<bool> hasPendingOrganizerRequest(String userId) async {
    try {
      final snapshot = await _organizerRequestsCol
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking pending organizer request: $e');
      return false;
    }
  }
  
  // Get all pending organizer requests
  static Future<List<Map<String, dynamic>>> getPendingOrganizerRequests() async {
    try {
      // Try with orderBy first (requires index)
      try {
        final snapshot = await _organizerRequestsCol
            .where('status', isEqualTo: 'pending')
            .orderBy('requestedAt', descending: true)
            .get();
        
        return snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            ...data,
          };
        }).toList();
      } catch (e) {
        // If index doesn't exist, fetch without orderBy and sort manually
        print('Index not found, fetching without orderBy: $e');
        final snapshot = await _organizerRequestsCol
            .where('status', isEqualTo: 'pending')
            .get();
        
        final requests = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            ...data,
          };
        }).toList();
        
        // Sort manually by requestedAt
        requests.sort((a, b) {
          final aTime = a['requestedAt'] as String? ?? '';
          final bTime = b['requestedAt'] as String? ?? '';
          return bTime.compareTo(aTime); // Descending
        });
        
        return requests;
      }
    } catch (e) {
      print('Error getting pending organizer requests: $e');
      return [];
    }
  }
  
  // Stream of pending organizer requests
  static Stream<List<Map<String, dynamic>>> getPendingOrganizerRequestsStream() {
    // Try with orderBy first, but catch errors and fallback
    return _organizerRequestsCol
        .where('status', isEqualTo: 'pending')
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      print('Organizer requests stream: Got ${snapshot.docs.length} documents');
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    }).handleError((error) {
      print('Error in organizer requests stream (with orderBy): $error');
      print('Falling back to stream without orderBy');
      // Return empty list on error, the admin dashboard will use the non-stream method
      return <Map<String, dynamic>>[];
    });
  }
  
  // Alternative stream without orderBy (for when index doesn't exist)
  static Stream<List<Map<String, dynamic>>> getPendingOrganizerRequestsStreamFallback() {
    return _organizerRequestsCol
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      print('Organizer requests stream (fallback): Got ${snapshot.docs.length} documents');
      final requests = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
      
      // Sort manually
      requests.sort((a, b) {
        final aTime = a['requestedAt'] as String? ?? '';
        final bTime = b['requestedAt'] as String? ?? '';
        return bTime.compareTo(aTime);
      });
      
      return requests;
    });
  }
  
  // Approve organizer request
  static Future<bool> approveOrganizerRequest(String requestId, String adminUserId) async {
    try {
      final requestDoc = await _organizerRequestsCol.doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Request not found');
      }
      
      final requestData = requestDoc.data()!;
      final userId = requestData['userId'] as String;
      
      // Update user type to organizer
      await _usersCol.doc(userId).update({
        'type': 'organizer',
      });
      
      // Update request status
      await _organizerRequestsCol.doc(requestId).update({
        'status': 'approved',
        'reviewedAt': DateTime.now().toIso8601String(),
        'reviewedBy': adminUserId,
      });
      
      print('Organizer request approved for user: $userId');
      return true;
    } catch (e) {
      print('Error approving organizer request: $e');
      return false;
    }
  }
  
  // Reject organizer request
  static Future<bool> rejectOrganizerRequest(String requestId, String adminUserId) async {
    try {
      final requestDoc = await _organizerRequestsCol.doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Request not found');
      }
      
      // Update request status
      await _organizerRequestsCol.doc(requestId).update({
        'status': 'rejected',
        'reviewedAt': DateTime.now().toIso8601String(),
        'reviewedBy': adminUserId,
      });
      
      print('Organizer request rejected: $requestId');
      return true;
    } catch (e) {
      print('Error rejecting organizer request: $e');
      return false;
    }
  }
}