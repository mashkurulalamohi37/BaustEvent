import 'package:flutter/material.dart';
import '../models/user.dart';

/// A reusable widget that displays a user's profile picture from Google
/// or falls back to an initial circle with the user's first letter.
class ProfileAvatar extends StatelessWidget {
  final User user;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;

  const ProfileAvatar({
    super.key,
    required this.user,
    this.radius = 20,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasProfileImage = user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty;
    
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? const Color(0xFF1976D2),
      backgroundImage: hasProfileImage 
          ? NetworkImage(user.profileImageUrl!) 
          : null,
      onBackgroundImageError: hasProfileImage 
          ? (exception, stackTrace) {
              // Silently handle image load errors and fall back to initial
              debugPrint('Failed to load profile image for ${user.name}: $exception');
            }
          : null,
      child: hasProfileImage
          ? null // Show image, no child
          : Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
              style: TextStyle(
                color: textColor ?? Colors.white,
                fontSize: radius * 0.7, // Scale font size with radius
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
}

/// A variant that accepts a participant map (used in item_distribution_screen)
class ProfileAvatarFromMap extends StatelessWidget {
  final Map<String, dynamic> participant;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;

  const ProfileAvatarFromMap({
    super.key,
    required this.participant,
    this.radius = 20,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final profileImageUrl = participant['profileImageUrl'] as String?;
    final name = participant['name'] as String? ?? '?';
    final hasProfileImage = profileImageUrl != null && profileImageUrl.isNotEmpty;
    
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? const Color(0xFF1976D2),
      backgroundImage: hasProfileImage 
          ? NetworkImage(profileImageUrl) 
          : null,
      onBackgroundImageError: hasProfileImage 
          ? (exception, stackTrace) {
              debugPrint('Failed to load profile image for $name: $exception');
            }
          : null,
      child: hasProfileImage
          ? null
          : Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                color: textColor ?? Colors.white,
                fontSize: radius * 0.7,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
}
