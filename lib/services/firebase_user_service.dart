import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';

class FirebaseUserService {
  // Authentication removed - all auth methods return null or no-op
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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

  // Get current user (Authentication removed - returns null)
  static User? getCurrentUser() {
    // Authentication removed - no current user
    return null;
  }

  // Get current user with details (Authentication removed - returns null)
  static Future<User?> getCurrentUserWithDetails() async {
    // Authentication removed - no current user
    return null;
  }

  // Get user by ID from Firestore
  static Future<User?> getUserById(String userId) async {
    try {
      final doc = await _usersCol.doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
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
      }
      return null;
    } catch (e) {
      print('Error getting user by ID: $e');
      return null;
    }
  }

  // Sign in with email and password (Authentication removed - finds user by email in Firestore)
  static Future<User?> signInWithEmailAndPassword(String email, String password) async {
    // Authentication removed - find user by email in Firestore
    try {
      final querySnapshot = await _usersCol.where('email', isEqualTo: email).limit(1).get();
      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        return User(
          id: doc.id,
          email: (data['email'] as String?) ?? email,
          name: (data['name'] as String?) ?? '',
          universityId: (data['universityId'] as String?) ?? '',
          type: _parseUserTypeAny(data['type'] ?? 'participant'),
          profileImageUrl: data['profileImageUrl'] as String?,
          createdAt: _parseDateAny(data['createdAt']) ?? DateTime.now(),
          lastLoginAt: _parseDateAny(data['lastLoginAt']),
        );
      }
      return null;
    } catch (e) {
      print('Error finding user: $e');
      return null;
    }
  }

  // Create user with email and password (Authentication removed - creates Firestore user only)
  static Future<User?> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String universityId,
    required UserType type,
  }) async {
    // Authentication removed - just create a user document in Firestore
    try {
      print('Attempting to create user with email: $email');
      
      // Check if user already exists
      final existingUser = await signInWithEmailAndPassword(email, password);
      if (existingUser != null) {
        print('User with email $email already exists');
        return existingUser; // Return existing user instead of failing
      }

      // Generate a unique ID from email (use timestamp if email-based ID exists)
      String userId = email.split('@').first.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (userId.isEmpty) {
        // If email parsing results in empty ID, use timestamp
        userId = 'user_${DateTime.now().millisecondsSinceEpoch}';
      }
      
      // Check if document with this ID already exists
      final docCheck = await _usersCol.doc(userId).get();
      if (docCheck.exists) {
        // Add timestamp to make it unique
        userId = '${userId}_${DateTime.now().millisecondsSinceEpoch}';
      }
      
      print('Creating user document with ID: $userId');
      
      final user = User(
        id: userId,
        email: email,
        name: name,
        universityId: universityId,
        type: type,
        createdAt: DateTime.now(),
      );

      // Create profile in Firestore
      final userData = {
        'email': user.email,
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

      print('User created successfully with ID: ${user.id}');
      return user;
    } catch (e, stackTrace) {
      print('=== ERROR CREATING USER ===');
      print('Error: $e');
      print('Error type: ${e.runtimeType}');
      print('Stack trace: $stackTrace');
      print('==========================');
      
      // Re-throw with detailed error message
      throw Exception('Firestore error: ${e.toString()}');
    }
  }

  // Sign out (Authentication removed - no-op)
  static Future<void> signOut() async {
    // Authentication removed - nothing to sign out
  }

  // Delete user (Authentication removed - only deletes from Firestore)
  static Future<void> deleteUser() async {
    // Authentication removed - user deletion from Firestore can be done via deleteUserDocument
  }

  // Firestore-backed operations
  static Future<List<User>> getAllUsers() async {
    final snap = await _usersCol.get();
    return snap.docs.map((d) {
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

  // Auth state changes (Authentication removed - returns empty stream)
  static Stream<User?> get authStateChanges {
    // Authentication removed - return empty stream
    return Stream.value(null);
  }

  // Ensure current Firebase Auth user has a Firestore profile document (Authentication removed - no-op)
  static Future<void> ensureCurrentUserDocument() async {
    // Authentication removed - nothing to ensure
  }
}