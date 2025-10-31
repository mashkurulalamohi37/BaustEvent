import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class FirebaseStorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static const String _eventImagesPath = 'event_images';
  static const String _profileImagesPath = 'profile_images';

  // Upload event image
  static Future<String?> uploadEventImage(String eventId, XFile imageFile) async {
    try {
      print('Starting image upload for event: $eventId');
      final ref = _storage
          .ref()
          .child('$_eventImagesPath/$eventId.jpg');
      
      print('Uploading file: ${imageFile.path}');
      final uploadTask = ref.putFile(File(imageFile.path));
      final snapshot = await uploadTask.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Image upload timeout');
        },
      );
      print('Upload complete, getting download URL...');
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('Download URL: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Error uploading event image: $e');
      // Don't fail event creation if image upload fails
      return null;
    }
  }

  // Upload profile image
  static Future<String?> uploadProfileImage(String userId, XFile imageFile) async {
    try {
      final ref = _storage
          .ref()
          .child('$_profileImagesPath/$userId.jpg');
      
      final uploadTask = ref.putFile(File(imageFile.path));
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      print('Error uploading profile image: $e');
      return null;
    }
  }

  // Delete event image
  static Future<bool> deleteEventImage(String eventId) async {
    try {
      final ref = _storage.ref().child('$_eventImagesPath/$eventId.jpg');
      await ref.delete();
      return true;
    } catch (e) {
      print('Error deleting event image: $e');
      return false;
    }
  }

  // Delete profile image
  static Future<bool> deleteProfileImage(String userId) async {
    try {
      final ref = _storage.ref().child('$_profileImagesPath/$userId.jpg');
      await ref.delete();
      return true;
    } catch (e) {
      print('Error deleting profile image: $e');
      return false;
    }
  }

  // Pick image from gallery
  static Future<XFile?> pickImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      return await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
    } catch (e) {
      print('Error picking image from gallery: $e');
      return null;
    }
  }

  // Pick image from camera
  static Future<XFile?> pickImageFromCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      return await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
    } catch (e) {
      print('Error picking image from camera: $e');
      return null;
    }
  }

  // Show image source selection dialog
  static Future<XFile?> showImageSourceDialog() async {
    // This would typically be called from a UI context
    // For now, we'll just return gallery picker
    return await pickImageFromGallery();
  }
}
