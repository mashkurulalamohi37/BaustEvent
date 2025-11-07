import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User show FirebaseAuthException, FirebaseAuth;
import '../models/user.dart';

class FirebaseUserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
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
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;
    
    return await getUserById(firebaseUser.uid);
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

  // Sign in with email and password using Firebase Authentication
  // Handles migration of old Firestore-only accounts to Firebase Auth
  static Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      // Authenticate with Firebase Auth (validates password)
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      
      if (credential.user == null) {
        return null;
      }
      
      // Get user profile from Firestore
      final userId = credential.user!.uid;
      final userDoc = await _usersCol.doc(userId).get();
      
      if (userDoc.exists) {
        final data = userDoc.data()!;
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
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth error: ${e.code} - ${e.message}');
      
      // Handle authentication errors
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
      } else {
        throw Exception('Invalid email or password. Please check your credentials.');
      }
    } catch (e) {
      // Re-throw migration exception as-is
      if (e.toString().contains('ACCOUNT_MIGRATION_NEEDED')) {
        rethrow;
      }
      print('Error signing in: $e');
      throw Exception('Error signing in. Please try again.');
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
      
      final userId = credential.user!.uid;

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
    } on FirebaseAuthException catch (e) {
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
    await _auth.signOut();
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
      
      // Verify user is authenticated
      if (_auth.currentUser == null) {
        throw Exception('User is not authenticated. Cannot create organizer request.');
      }
      
      if (_auth.currentUser!.uid != userId) {
        throw Exception('User ID mismatch. Authenticated: ${_auth.currentUser!.uid}, Provided: $userId');
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
      if (!verifyDoc.exists) {
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