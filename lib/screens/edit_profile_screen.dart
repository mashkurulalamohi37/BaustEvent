import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/firebase_user_service.dart';
import '../services/firebase_storage_service.dart';
import '../models/user.dart';

class EditProfileScreen extends StatefulWidget {
  final String? userId;
  
  const EditProfileScreen({super.key, this.userId});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _universityIdController = TextEditingController();
  String? _imagePathOrUrl;
  XFile? _selectedImage;
  User? _currentUser;
  bool _isSaving = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() => _isLoading = true);
    
    try {
      User? user;
      
      // If userId is provided, fetch user details
      if (widget.userId != null) {
        user = await FirebaseUserService.getUserById(widget.userId!);
      } else {
        user = await FirebaseUserService.getCurrentUserWithDetails();
      }
      
      setState(() {
        _currentUser = user;
        _nameController.text = user?.name ?? '';
        _universityIdController.text = user?.universityId ?? '';
        _imagePathOrUrl = user?.profileImageUrl;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _universityIdController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Image Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (picked != null) {
        setState(() {
          _selectedImage = picked;
          _imagePathOrUrl = picked.path;
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      User? userToUpdate = _currentUser;
      
      // If no user exists, use userId from widget or create new one
      if (userToUpdate == null) {
        String userId;
        if (widget.userId != null) {
          userId = widget.userId!;
          // Try to fetch the user first
          userToUpdate = await FirebaseUserService.getUserById(userId);
        } else {
          userId = 'guest_${DateTime.now().millisecondsSinceEpoch}';
        }
        
        // Create user if it doesn't exist
        if (userToUpdate == null) {
          final newUser = User(
            id: widget.userId ?? userId,
            email: 'guest@eventbridge.com',
            name: _nameController.text.trim(),
            universityId: _universityIdController.text.trim(),
            type: UserType.participant,
            createdAt: DateTime.now(),
          );
          await FirebaseUserService.createUser(newUser);
          userToUpdate = newUser;
        }
      }
      
      String? imageUrl = userToUpdate.profileImageUrl;
      
      // Upload new image if selected
      if (_selectedImage != null) {
        imageUrl = await FirebaseStorageService.uploadProfileImage(userToUpdate.id, _selectedImage!);
      }
      
      final updated = userToUpdate.copyWith(
        name: _nameController.text.trim(),
        universityId: _universityIdController.text.trim(),
        profileImageUrl: imageUrl,
      );
      final ok = await FirebaseUserService.updateUser(updated);
      if (ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update profile'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: Text(
              'Save',
              style: TextStyle(
                color: _isSaving ? Colors.grey : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: const Color(0xFF1976D2),
                          backgroundImage: _buildImageProvider(),
                          child: _imagePathOrUrl == null
                              ? const Icon(Icons.person, size: 50, color: Colors.white)
                              : null,
                        ),
                        if (_selectedImage != null)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, color: Colors.white, size: 16),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Please enter your name'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _universityIdController,
                          decoration: const InputDecoration(
                            labelText: 'University ID',
                            prefixIcon: Icon(Icons.badge),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Please enter your university ID'
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  ImageProvider? _buildImageProvider() {
    if (_imagePathOrUrl == null) return null;
    
    // If it's a local file path (newly selected image)
    if (_selectedImage != null && _imagePathOrUrl == _selectedImage!.path) {
      return FileImage(File(_imagePathOrUrl!));
    }
    
    // If it's a network URL
    if (_imagePathOrUrl!.startsWith('http://') || _imagePathOrUrl!.startsWith('https://')) {
      return NetworkImage(_imagePathOrUrl!);
    }
    
    // Otherwise try as asset
    return AssetImage(_imagePathOrUrl!);
  }
}
