import 'package:flutter/material.dart';
import 'participant_dashboard.dart';
import 'organizer_dashboard.dart';
import 'admin_dashboard.dart';
import 'forgot_password_screen.dart';
import '../models/user.dart';
import '../services/firebase_user_service.dart';
import '../utils/email_validator.dart';

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
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _universityIdController = TextEditingController();
  UserType _selectedType = UserType.participant;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
                  validator: (value) {
                    if (value == null) {
                      return 'Please select an account type';
                    }
                    return null;
                  },
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
                validator: (value) => EmailValidator.validateEmail(value),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
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
              if (!isLogin) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
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
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 24),
              if (isLogin) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _showForgotPasswordDialog,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: Color(0xFF1976D2),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey[300], thickness: 1.5)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('OR', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500)),
                  ),
                  Expanded(child: Divider(color: Colors.grey[300], thickness: 1.5)),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _handleGoogleSignIn,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: Colors.grey[300]!),
                    backgroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.g_mobiledata, size: 32, color: Colors.blue),
                  label: const Text(
                    'Continue with Google',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isLogin ? 'Don\'t have an account? ' : 'Already have an account? ',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 15,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        isLogin = !isLogin;
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      isLogin ? 'Sign Up' : 'Sign In',
                      style: const TextStyle(
                        color: Color(0xFF1976D2),
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
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

    // Additional async email validation (domain existence check) - only for signup
    if (!isLogin) {
      final emailValidation = await EmailValidator.validateEmailWithDomainCheck(
        _emailController.text.trim(),
      );
      if (emailValidation != null) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(emailValidation),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }
    }

    if (isLogin) {
      // Login - validate credentials
      try {
        final user = await FirebaseUserService.signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
        
        if (user == null) {
          // User not found - show error
          if (!mounted) {
            setState(() => _isLoading = false);
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid email or password. Please check your credentials and try again.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
          setState(() => _isLoading = false);
          return;
        }
        
        // User found - proceed to dashboard
        if (!mounted) {
          setState(() => _isLoading = false);
          return;
        }
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) {
                if (user.isAdmin) {
                  return AdminDashboard(userId: user.id);
                } else if (user.type == UserType.organizer) {
                  return OrganizerDashboard(userId: user.id);
                } else {
                  return ParticipantDashboard(userId: user.id);
                }
              },
            ),
          );
      } catch (e) {
        if (!mounted) {
          setState(() => _isLoading = false);
          return;
        }
        
        String errorMessage = e.toString().replaceFirst('Exception: ', '');
        
        // Log the full error for debugging
        print('Login error details: $e');
        print('Error message: $errorMessage');
        
        // Provide user-friendly error messages
        if (errorMessage.contains('PERMISSION_DENIED') || 
            errorMessage.contains('permission-denied')) {
          errorMessage = 'Permission denied. Please check your Firestore security rules.';
        } else if (errorMessage.contains('UNAVAILABLE') || 
                   errorMessage.contains('unavailable')) {
          errorMessage = 'Unable to connect. Please check your internet connection.';
        } else if (errorMessage.contains('network') || 
                   errorMessage.contains('Network')) {
          errorMessage = 'Network error. Please check your internet connection and try again.';
        } else if (errorMessage.contains('No account found') ||
                   errorMessage.contains('user-not-found')) {
          errorMessage = 'No account found with this email. Please sign up first.';
        } else if (errorMessage.contains('Invalid password') ||
                   errorMessage.contains('wrong-password')) {
          errorMessage = 'Invalid password. Please try again.';
        } else if (errorMessage.contains('Invalid email or password')) {
          errorMessage = 'Invalid email or password. Please check your credentials.';
        } else if (errorMessage.contains('operation-not-allowed')) {
          errorMessage = 'Email/password sign-in is not enabled. Please contact support.';
        } else if (errorMessage.contains('Sign-in failed')) {
          // Keep the detailed error message from Firebase
          errorMessage = errorMessage;
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        setState(() => _isLoading = false);
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
        
        // If user signed up as organizer, show a message about pending approval
        if (_selectedType == UserType.organizer) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Your organizer request has been submitted and is pending admin approval. You will be notified once approved.',
                style: TextStyle(fontSize: 14),
              ),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 5),
            ),
          );
        }
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) {
              if (user.isAdmin) {
                return AdminDashboard(userId: user.id);
              } else if (user.type == UserType.organizer) {
                return OrganizerDashboard(userId: user.id);
              } else {
                return ParticipantDashboard(userId: user.id);
              }
            },
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
                   errorMessage.contains('already exists') ||
                   errorMessage.contains('An account with this email already exists') ||
                   errorMessage.toLowerCase().contains('email-already-in-use')) {
          errorMessage = 'An account with this email already exists. Please sign in instead.';
        } else if (errorMessage.contains('weak-password') ||
                   errorMessage.contains('Password is too weak')) {
          errorMessage = 'Password is too weak. Please use a stronger password (at least 6 characters).';
        } else if (errorMessage.contains('invalid-email') ||
                   errorMessage.contains('Invalid email address')) {
          errorMessage = 'Invalid email address. Please enter a valid email.';
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

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      final user = await FirebaseUserService.signInWithGoogle();
      
      if (user != null && mounted) {
           Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) {
                if (user.isAdmin) {
                  return AdminDashboard(userId: user.id);
                } else if (user.type == UserType.organizer) {
                  return OrganizerDashboard(userId: user.id);
                } else {
                  return ParticipantDashboard(userId: user.id);
                }
              },
            ),
          );
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showForgotPasswordDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ForgotPasswordScreen(),
      ),
    );
  }

}

