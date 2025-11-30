import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // FAQ Section
          _buildSectionHeader(context, 'Frequently Asked Questions'),
          _buildFAQItem(
            context,
            'How do I register for an event?',
            'Browse events on the home screen, tap on an event you\'re interested in, and click the "Register" button. Fill in the required information and submit.',
          ),
          _buildFAQItem(
            context,
            'How do I check in at an event?',
            'Show your QR code to the event organizer at the check-in desk. You can find your QR code in the "My Events" section.',
          ),
          _buildFAQItem(
            context,
            'Can I cancel my registration?',
            'Yes, you can cancel your registration from the event details page before the registration deadline.',
          ),
          _buildFAQItem(
            context,
            'How do I become an organizer?',
            'Request organizer access from your profile. Your request will be reviewed by administrators.',
          ),
          _buildFAQItem(
            context,
            'What payment methods are accepted?',
            'Events may accept bKash, Nagad, or hand cash payments. Check the event details for available payment options.',
          ),
          const SizedBox(height: 24),
          
          // Contact Section
          _buildSectionHeader(context, 'Contact Us'),
          _buildContactCard(
            context: context,
            icon: Icons.email,
            title: 'Email Support',
            subtitle: 'Get help via email',
            onTap: () => _launchEmail(context),
          ),
          _buildContactCard(
            context: context,
            icon: Icons.phone,
            title: 'Phone Support',
            subtitle: 'Call us for immediate assistance',
            onTap: () => _launchPhone(context),
          ),
          const SizedBox(height: 24),
          
          // Report Issue
          _buildSectionHeader(context, 'Report an Issue'),
          Builder(
            builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                child: ListTile(
                  leading: Icon(Icons.bug_report, color: isDark ? Colors.white : Colors.black),
                  title: Text(
                    'Report a Bug',
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  ),
                  subtitle: Text(
                    'Help us improve by reporting issues',
                    style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700]),
                  ),
                  trailing: Icon(Icons.chevron_right, color: isDark ? Colors.white : Colors.black),
                  onTap: () => _showReportBugDialog(context),
                ),
              );
            },
          ),
          Builder(
            builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                child: ListTile(
                  leading: Icon(Icons.feedback, color: isDark ? Colors.white : Colors.black),
                  title: Text(
                    'Send Feedback',
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  ),
                  subtitle: Text(
                    'Share your thoughts and suggestions',
                    style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700]),
                  ),
                  trailing: Icon(Icons.chevron_right, color: isDark ? Colors.white : Colors.black),
                  onTap: () => _showFeedbackDialog(context),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.grey[300] : Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildFAQItem(BuildContext context, String question, String answer) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: ExpansionTile(
        title: Text(
          question,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        iconColor: isDark ? Colors.white : Colors.black,
        collapsedIconColor: isDark ? Colors.white : Colors.black,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              answer,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF1976D2)),
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: isDark ? Colors.white : Colors.black,
        ),
        onTap: onTap,
      ),
    );
  }

  Future<void> _launchEmail(BuildContext context, {String? customSubject, String? customBody}) async {
    final email = 'mashkurulalam7@gmail.com';
    final subject = customSubject ?? 'EventBridge Support Request';
    final body = customBody ?? 'Hello,\n\nI need help with:\n\n';
    
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Email: $email'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch email: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launchPhone(BuildContext context) async {
    final phone = '+8801609024005';
    final uri = Uri(scheme: 'tel', path: phone);
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Phone: $phone'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch phone: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showReportBugDialog(BuildContext context) {
    _launchEmail(
      context,
      customSubject: 'EventBridge Bug Report',
      customBody: 'Hello,\n\nI encountered the following bug:\n\n',
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    _launchEmail(
      context,
      customSubject: 'EventBridge Feedback',
      customBody: 'Hello,\n\nI would like to share the following feedback:\n\n',
    );
  }
}

