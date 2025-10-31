import 'package:flutter/material.dart';
import 'participant_dashboard.dart';
import 'organizer_dashboard.dart';
import '../models/user.dart';
import '../services/firebase_user_service.dart';

class AuthScreen extends StatefulWidget {
  final bool initialIsLogin;
  const AuthScreen({super.key, this.initialIsLogin = true});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late bool isLogin;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _universityIdController = TextEditingController();
  UserType _selectedType = UserType.participant;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _universityIdController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    isLogin = widget.initialIsLogin;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EventBridge'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Text(
                isLogin ? 'Welcome Back!' : 'Create Account',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1976D2),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isLogin
                    ? 'Sign in to continue to EventBridge'
                    : 'Join EventBridge to discover amazing events',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              if (!isLogin) ...[
                // Role picker
                DropdownButtonFormField<UserType>(
                  value: _selectedType,
                  decoration: InputDecoration(
                    labelText: 'Account Type',
                    prefixIcon: const Icon(Icons.account_circle),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: UserType.participant, child: Text('Participant')),
                    DropdownMenuItem(value: UserType.organizer, child: Text('Organizer')),
                  ],
                  onChanged: (v) => setState(() => _selectedType = v ?? UserType.participant),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your full name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _universityIdController,
                  decoration: InputDecoration(
                    labelText: 'University ID',
                    prefixIcon: const Icon(Icons.badge),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your university ID';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          isLogin ? 'Sign In' : 'Sign Up',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isLogin ? 'Don\'t have an account? ' : 'Already have an account? ',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        isLogin = !isLogin;
                      });
                    },
                    child: Text(
                      isLogin ? 'Sign Up' : 'Sign In',
                      style: const TextStyle(
                        color: Color(0xFF1976D2),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    if (isLogin) {
      // Since authentication is removed, we'll create a user or find existing one
      try {
        final user = await FirebaseUserService.signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
        
        if (user == null) {
          // Create user if doesn't exist (since no auth)
          final newUser = await FirebaseUserService.createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
            name: _emailController.text.split('@')[0],
            universityId: 'USER${DateTime.now().millisecondsSinceEpoch}',
            type: UserType.participant,
          );
          
          if (newUser == null || !mounted) return;
          
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => newUser.type == UserType.organizer
                  ? OrganizerDashboard(userId: newUser.id)
                  : ParticipantDashboard(userId: newUser.id),
            ),
          );
        } else {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => user.type == UserType.organizer
                  ? OrganizerDashboard(userId: user.id)
                  : ParticipantDashboard(userId: user.id),
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      // Create user with Firebase (creates in Firestore)
      try {
        final created = await FirebaseUserService.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          name: _nameController.text.trim(),
          universityId: _universityIdController.text.trim(),
          type: _selectedType,
        );
        
        if (created == null) {
          throw Exception('Failed to create user. Please try again.');
        }
        
        // Use the created user directly
        final user = created;

        if (!mounted) {
          setState(() => _isLoading = false);
          return;
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => user.type == UserType.organizer
                ? OrganizerDashboard(userId: user.id)
                : ParticipantDashboard(userId: user.id),
          ),
        );
      } catch (e) {
        if (!mounted) {
          setState(() => _isLoading = false);
          return;
        }
        String errorMessage = e.toString().replaceFirst('Exception: ', '');
        
        // Provide more user-friendly error messages
        if (errorMessage.contains('PERMISSION_DENIED') || 
            errorMessage.contains('permission-denied') || 
            errorMessage.contains('permission denied')) {
          errorMessage = 'Permission denied. Please check your Firestore security rules in Firebase Console.';
        } else if (errorMessage.contains('UNAVAILABLE') || 
                   errorMessage.contains('unavailable')) {
          errorMessage = 'Firestore is unavailable. Please check your internet connection and try again.';
        } else if (errorMessage.contains('NOT_FOUND') || 
                   errorMessage.contains('not-found')) {
          errorMessage = 'Database not found. Please ensure Firestore is enabled in Firebase Console.';
        } else if (errorMessage.contains('already-exists') || 
                   errorMessage.contains('already exists')) {
          errorMessage = 'An account with this email already exists. Please sign in instead.';
        } else if (errorMessage.contains('unimplemented') || 
                   errorMessage.contains('not available')) {
          errorMessage = 'Firestore is not properly configured. Please check your Firebase setup.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        setState(() => _isLoading = false);
      }
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}

