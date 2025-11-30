import 'package:flutter/material.dart';
import '../services/theme_service.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService.instance ?? ThemeService();
    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) {
        final isDark = themeService.isDarkMode;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Terms of Service'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Terms of Service',
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
              '1. Acceptance of Terms',
              'By accessing and using the BAUST Event mobile application (the "Service"), you accept and '
              'agree to be bound by the terms and provision of this agreement. If you do not agree to '
              'abide by the above, please do not use this service.',
              isDark,
            ),
            
            _buildSection(
              context,
              '2. Use License',
              'Permission is granted to temporarily download one copy of the materials on BAUST Event\'s '
              'mobile application for personal, non-commercial transitory viewing only. This is the grant '
              'of a license, not a transfer of title, and under this license you may not:',
              isDark,
            ),
            
            _buildBulletList([
              'Modify or copy the materials',
              'Use the materials for any commercial purpose or for any public display',
              'Attempt to reverse engineer any software contained in the application',
              'Remove any copyright or other proprietary notations from the materials',
            ], isDark),
            
            _buildSection(
              context,
              '3. User Accounts',
              'To access certain features of the Service, you must register for an account. You agree to:',
              isDark,
            ),
            
            _buildBulletList([
              'Provide accurate, current, and complete information during registration',
              'Maintain and promptly update your account information',
              'Maintain the security of your password and identification',
              'Accept all responsibility for all activities that occur under your account',
              'Notify us immediately of any unauthorized use of your account',
            ], isDark),
            
            _buildSection(
              context,
              '4. User Conduct',
              'You agree not to use the Service to:',
              isDark,
            ),
            
            _buildBulletList([
              'Violate any applicable laws or regulations',
              'Infringe upon the rights of others',
              'Transmit any harmful, offensive, or inappropriate content',
              'Impersonate any person or entity',
              'Interfere with or disrupt the Service or servers',
              'Collect or store personal data about other users without their consent',
            ], isDark),
            
            _buildSection(
              context,
              '5. Event Creation and Participation',
              'When creating or participating in events through the Service:',
              isDark,
            ),
            
            _buildBulletList([
              'Organizers are responsible for the accuracy of event information',
              'Organizers must comply with all applicable laws and regulations',
              'Participants must provide accurate registration information',
              'Payment transactions are subject to the terms of the payment provider',
              'We are not responsible for disputes between organizers and participants',
            ], isDark),
            
            _buildSection(
              context,
              '6. Intellectual Property',
              'The Service and its original content, features, and functionality are and will remain the '
              'exclusive property of BAUST Event and its licensors. The Service is protected by copyright, '
              'trademark, and other laws.',
              isDark,
            ),
            
            _buildSection(
              context,
              '7. Payment Terms',
              'If you make payments through the Service:',
              isDark,
            ),
            
            _buildBulletList([
              'All payments are processed by third-party payment providers',
              'We are not responsible for payment processing errors',
              'Refunds are subject to the event organizer\'s refund policy',
              'You agree to provide accurate payment information',
            ], isDark),
            
            _buildSection(
              context,
              '8. Disclaimer',
              'The materials on BAUST Event\'s mobile application are provided on an \'as is\' basis. '
              'BAUST Event makes no warranties, expressed or implied, and hereby disclaims and negates '
              'all other warranties including, without limitation, implied warranties or conditions of '
              'merchantability, fitness for a particular purpose, or non-infringement of intellectual '
              'property or other violation of rights.',
              isDark,
            ),
            
            _buildSection(
              context,
              '9. Limitations',
              'In no event shall BAUST Event or its suppliers be liable for any damages (including, '
              'without limitation, damages for loss of data or profit, or due to business interruption) '
              'arising out of the use or inability to use the materials on BAUST Event\'s mobile '
              'application, even if BAUST Event or a BAUST Event authorized representative has been '
              'notified orally or in writing of the possibility of such damage.',
              isDark,
            ),
            
            _buildSection(
              context,
              '10. Accuracy of Materials',
              'The materials appearing on BAUST Event\'s mobile application could include technical, '
              'typographical, or photographic errors. BAUST Event does not warrant that any of the '
              'materials on its mobile application are accurate, complete, or current.',
              isDark,
            ),
            
            _buildSection(
              context,
              '11. Modifications',
              'BAUST Event may revise these terms of service for its mobile application at any time '
              'without notice. By using this Service you are agreeing to be bound by the then current '
              'version of these terms of service.',
              isDark,
            ),
            
            _buildSection(
              context,
              '12. Termination',
              'We may terminate or suspend your account and bar access to the Service immediately, '
              'without prior notice or liability, under our sole discretion, for any reason whatsoever '
              'and without limitation, including but not limited to a breach of the Terms.',
              isDark,
            ),
            
            _buildSection(
              context,
              '13. Governing Law',
              'These terms and conditions are governed by and construed in accordance with the laws of '
              'Bangladesh and you irrevocably submit to the exclusive jurisdiction of the courts in that '
              'location.',
              isDark,
            ),
            
            _buildSection(
              context,
              '14. Contact Information',
              'If you have any questions about these Terms of Service, please contact us:',
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

