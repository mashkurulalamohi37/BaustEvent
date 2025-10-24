import 'package:firebase_auth/firebase_auth.dart' as auth;
import '../models/user.dart';

class FirebaseUserService {
  static final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;

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

        // User is created in Firebase Auth - no additional Firestore operations needed
        print('User created successfully in Firebase Auth');

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
      await user.delete();
    }
  }

  // Get all users (returns empty list since no Firestore)
  static Future<List<User>> getAllUsers() async {
    return [];
  }

  // Create user (returns false since no Firestore)
  static Future<bool> createUser(User user) async {
    print('User creation not available without Firestore');
    return false;
  }

  // Update user (returns false since no Firestore)
  static Future<bool> updateUser(User user) async {
    print('User update not available without Firestore');
    return false;
  }
}