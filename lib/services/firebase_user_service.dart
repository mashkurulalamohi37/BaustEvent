import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import '../models/user.dart';

class FirebaseUserService {
  static final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
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

  // Get current user (Firebase Auth only)
  static User? getCurrentUser() {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      return User(
        id: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        name: firebaseUser.displayName ?? '',
        universityId: '',
        type: UserType.participant,
        createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
        lastLoginAt: firebaseUser.metadata.lastSignInTime,
      );
    }
    return null;
  }

  // Get current user with details (Firebase Auth only)
  static Future<User?> getCurrentUserWithDetails() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;
    // Try to read profile from Firestore; fallback to auth fields
    try {
      final doc = await _usersCol.doc(firebaseUser.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        return User(
          id: firebaseUser.uid,
          email: (data['email'] as String?) ?? firebaseUser.email ?? '',
          name: (data['name'] as String?) ?? firebaseUser.displayName ?? '',
          universityId: (data['universityId'] as String?) ?? '',
          type: _parseUserTypeAny((data['type'] ?? 'participant')),
          profileImageUrl: data['profileImageUrl'] as String?,
          createdAt: _parseDateAny(data['createdAt']) ??
              (firebaseUser.metadata.creationTime ?? DateTime.now()),
          lastLoginAt: _parseDateAny(data['lastLoginAt']) ??
              firebaseUser.metadata.lastSignInTime,
        );
      }
    } catch (_) {}

    return User(
      id: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      name: firebaseUser.displayName ?? '',
      universityId: '',
      type: UserType.participant,
      createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
      lastLoginAt: firebaseUser.metadata.lastSignInTime,
    );
  }

  // Sign in with email and password
  static Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Return basic user info from Firebase Auth only
        final firebaseUser = credential.user!;
        final user = User(
          id: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          name: firebaseUser.displayName ?? '',
          universityId: '',
          type: UserType.participant,
          createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
          lastLoginAt: firebaseUser.metadata.lastSignInTime,
        );
        // Update lastLoginAt in Firestore
        try {
          await _usersCol.doc(user.id).set({
            'email': user.email,
            'name': user.name,
            'universityId': user.universityId,
            'type': user.type.name,
            'profileImageUrl': user.profileImageUrl,
            'createdAt': user.createdAt.toIso8601String(),
            'lastLoginAt': DateTime.now().toIso8601String(),
          }, SetOptions(merge: true));
        } catch (_) {}
        return user;
      }
      return null;
    } catch (e) {
      print('Error signing in: $e');
      // Return a more specific error message
      if (e.toString().contains('user-not-found')) {
        throw Exception('No account found with this email address');
      } else if (e.toString().contains('wrong-password')) {
        throw Exception('Incorrect password');
      } else if (e.toString().contains('invalid-email')) {
        throw Exception('Invalid email address');
      } else if (e.toString().contains('user-disabled')) {
        throw Exception('This account has been disabled');
      } else {
        throw Exception('Sign in failed: ${e.toString()}');
      }
    }
  }

  // Create user with email and password
  static Future<User?> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String universityId,
    required UserType type,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Update display name
        await credential.user!.updateDisplayName(name);

        // Create user object from Firebase Auth data
        final user = User(
          id: credential.user!.uid,
          email: email,
          name: name,
          universityId: universityId,
          type: type,
          createdAt: DateTime.now(),
        );

        // Create profile in Firestore
        await _usersCol.doc(user.id).set({
          'email': user.email,
          'name': user.name,
          'universityId': user.universityId,
          'type': user.type.name,
          'profileImageUrl': user.profileImageUrl,
          'createdAt': user.createdAt.toIso8601String(),
          'lastLoginAt': user.lastLoginAt?.toIso8601String(),
        });

        return user;
      }
      return null;
    } catch (e) {
      print('Error creating user: $e');
      // Return a more specific error message
      if (e.toString().contains('email-already-in-use')) {
        throw Exception('An account already exists with this email address');
      } else if (e.toString().contains('invalid-email')) {
        throw Exception('Invalid email address');
      } else if (e.toString().contains('weak-password')) {
        throw Exception('Password is too weak. Please choose a stronger password');
      } else {
        throw Exception('Account creation failed: ${e.toString()}');
      }
    }
  }

  // Sign out
  static Future<void> signOut() async {
    await _auth.signOut();
  }

  // Delete user
  static Future<void> deleteUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _usersCol.doc(user.uid).delete();
      } catch (_) {}
      await user.delete();
    }
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

  // Auth state changes as domain User
  static Stream<User?> get authStateChanges {
    return _auth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;
      return await getCurrentUserWithDetails();
    });
  }

  // Ensure current Firebase Auth user has a Firestore profile document
  static Future<void> ensureCurrentUserDocument() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return;
    final ref = _usersCol.doc(firebaseUser.uid);
    final doc = await ref.get();
    if (!doc.exists) {
      final now = DateTime.now();
      await ref.set({
        'email': firebaseUser.email ?? '',
        'name': firebaseUser.displayName ?? '',
        'universityId': '',
        'type': 'participant',
        'profileImageUrl': null,
        'createdAt': (firebaseUser.metadata.creationTime ?? now).toIso8601String(),
        'lastLoginAt': (firebaseUser.metadata.lastSignInTime ?? now).toIso8601String(),
      });
    }
  }
}