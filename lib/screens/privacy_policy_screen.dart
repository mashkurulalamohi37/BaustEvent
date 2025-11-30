import 'package:flutter/material.dart';
import '../services/theme_service.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService.instance ?? ThemeService();
    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) {
        final isDark = themeService.isDarkMode;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Privacy Policy'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Privacy Policy',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1976D2),
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Last updated: November 30, 2025',
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
            const SizedBox(height: 24),
            
            _buildSection(
              context,
              '1. Introduction',
              'BAUST Event ("we", "our", or "us") operates the BAUST Event mobile application (the "Service"). '
              'This page informs you of our policies regarding the collection, use, and disclosure of personal '
              'data when you use our Service.',
              isDark,
            ),
            
            _buildSection(
              context,
              '2. Information We Collect',
              'We collect the following types of information:',
              isDark,
            ),
            
            _buildSubSection(
              context,
              '2.1 Personal Information',
              [
                'Account Information: Email address, name, university ID',
                'Profile Data: Profile pictures, user type (organizer/participant)',
                'Event Data: Events you create or participate in, registration information',
              ],
              isDark,
            ),
            
            _buildSubSection(
              context,
              '2.2 Device Information',
              [
                'Camera access (for QR code scanning)',
                'Image storage access (for uploading event and profile images)',
                'Device identifiers and technical information',
              ],
              isDark,
            ),
            
            _buildSubSection(
              context,
              '2.3 Usage Data',
              [
                'Event participation history',
                'App usage patterns',
                'Last login timestamps',
              ],
              isDark,
            ),
            
            _buildSection(
              context,
              '3. How We Use Your Information',
              'We use the collected information for:',
              isDark,
            ),
            
            _buildBulletList([
              'Providing and maintaining the Service',
              'User authentication and account management',
              'Event creation, management, and participation',
              'QR code generation and scanning for event check-ins',
              'Real-time event updates and notifications',
              'Managing participant registrations',
            ], isDark),
            
            _buildSection(
              context,
              '4. Data Storage and Security',
              'Your data is stored securely using Google Firebase services:',
              isDark,
            ),
            
            _buildBulletList([
              'Firebase Authentication: Handles user authentication',
              'Cloud Firestore: Stores user profiles, events, and participation data',
              'Firebase Storage: Stores event images and profile pictures',
            ], isDark),
            
            const SizedBox(height: 12),
            Text(
              'We implement appropriate security measures to protect your personal information. However, '
              'no method of transmission over the Internet or electronic storage is 100% secure.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                    color: isDark ? Colors.white : null,
                  ),
            ),
            
            _buildSection(
              context,
              '5. Third-Party Services',
              'We use the following third-party services:',
              isDark,
            ),
            
            _buildBulletList([
              'Google Firebase: For authentication, database, and storage services',
              'These services have their own privacy policies governing data collection and use',
            ], isDark),
            
            _buildSection(
              context,
              '6. Permissions',
              'The app requires the following permissions:',
              isDark,
            ),
            
            _buildBulletList([
              'Camera: For scanning QR codes to check into events',
              'Storage/Photos: For uploading event images and profile pictures',
            ], isDark),
            
            _buildSection(
              context,
              '7. Data Sharing',
              'We do not sell, trade, or rent your personal information to third parties. Your information '
              'may be shared with:',
              isDark,
            ),
            
            _buildBulletList([
              'Event organizers (for events you participate in)',
              'Other participants (limited profile information in event contexts)',
              'Service providers who assist in operating the app (Firebase)',
            ], isDark),
            
            _buildSection(
              context,
              '8. Your Rights',
              'You have the right to:',
              isDark,
            ),
            
            _buildBulletList([
              'Access your personal data',
              'Update or correct your information',
              'Delete your account and data',
              'Request information about data we hold',
            ], isDark),
            
            const SizedBox(height: 12),
            Text(
              'To exercise these rights, please contact us at the email address provided below.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                    color: isDark ? Colors.white : null,
                  ),
            ),
            
            _buildSection(
              context,
              '9. Data Retention',
              'We retain your personal information for as long as your account is active or as needed to '
              'provide services. You may request deletion of your account and data at any time.',
              isDark,
            ),
            

            
            _buildSection(
              context,
              '11. Changes to This Privacy Policy',
              'We may update our Privacy Policy from time to time. We will notify you of any changes by '
              'posting the new Privacy Policy on this page and updating the "Last updated" date.',
              isDark,
            ),
            
            _buildSection(
              context,
              '12. Contact Us',
              'If you have any questions about this Privacy Policy, please contact us:',
              isDark,
            ),
            
            const SizedBox(height: 8),
            _buildContactInfo(isDark),
            const SizedBox(height: 32),
          ],
        ),
      ),
        );
      },
    );
  }

  Widget _buildSection(BuildContext context, String title, String content, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[300] : Colors.grey[800],
              ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.6,
                color: isDark ? Colors.white : null,
              ),
        ),
      ],
    );
  }

  Widget _buildSubSection(BuildContext context, String title, List<String> items, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : null,
              ),
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.6,
                            color: isDark ? Colors.white : null,
                          ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildBulletList(List<String> items, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) => Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      height: 1.6,
                      color: isDark ? Colors.white : null,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
    );
  }

  Widget _buildContactInfo(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.blue.shade700 : Colors.blue[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.email,
                color: isDark ? Colors.blue.shade300 : Colors.blue[700],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Email:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.blue.shade300 : Colors.blue[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text(
              'mashkurulalam7@gmail.com',
              style: TextStyle(
                color: isDark ? Colors.blue.shade300 : Colors.blue[900],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.school,
                color: isDark ? Colors.blue.shade300 : Colors.blue[700],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Institution:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.blue.shade300 : Colors.blue[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text(
              'Bangladesh Army University of Science & Technology (BAUST)\nOhi-CSE17B',
              style: TextStyle(
                color: isDark ? Colors.blue.shade300 : Colors.blue[900],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

