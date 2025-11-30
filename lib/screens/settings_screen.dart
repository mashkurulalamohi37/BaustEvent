import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/theme_service.dart';
import 'change_password_screen.dart';
import 'terms_of_service_screen.dart';
import 'privacy_policy_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _darkMode = false;
  bool _isLoading = false;
  late final ThemeService _themeService;

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService(); // Get singleton instance
    _themeService.addListener(_onThemeChanged);
    _loadSettings();
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {
        _darkMode = _themeService.isDarkMode;
      });
    }
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        _emailNotifications = prefs.getBool('email_notifications') ?? true;
        _pushNotifications = prefs.getBool('push_notifications') ?? true;
        _darkMode = ThemeService().isDarkMode;
      });
    } catch (e) {
      print('Error loading settings: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSetting(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e) {
      print('Error saving setting: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Notifications Section
                _buildSectionHeader('Notifications'),
                SwitchListTile(
                  title: const Text('Enable Notifications'),
                  subtitle: const Text('Receive notifications about events'),
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    setState(() => _notificationsEnabled = value);
                    _saveSetting('notifications_enabled', value);
                  },
                  secondary: const Icon(Icons.notifications),
                ),
                if (_notificationsEnabled) ...[
                  SwitchListTile(
                    title: const Text('Email Notifications'),
                    subtitle: const Text('Receive notifications via email'),
                    value: _emailNotifications,
                    onChanged: (value) {
                      setState(() => _emailNotifications = value);
                      _saveSetting('email_notifications', value);
                    },
                    secondary: const Icon(Icons.email),
                  ),
                  SwitchListTile(
                    title: const Text('Push Notifications'),
                    subtitle: const Text('Receive push notifications on your device'),
                    value: _pushNotifications,
                    onChanged: (value) {
                      setState(() => _pushNotifications = value);
                      _saveSetting('push_notifications', value);
                    },
                    secondary: const Icon(Icons.phone_android),
                  ),
                ],
                const SizedBox(height: 24),
                
                // Appearance Section
                _buildSectionHeader('Appearance'),
                SwitchListTile(
                  title: const Text('Dark Mode'),
                  subtitle: const Text('Use dark theme'),
                  value: _darkMode,
                  onChanged: (value) async {
                    setState(() => _darkMode = value);
                    await _saveSetting('dark_mode', value);
                    await _themeService.setTheme(value);
                  },
                  secondary: const Icon(Icons.dark_mode),
                ),
                const SizedBox(height: 24),
                
                // Account Section
                _buildSectionHeader('Account'),
                ListTile(
                  leading: const Icon(Icons.lock),
                  title: const Text('Change Password'),
                  subtitle: const Text('Update your account password'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChangePasswordScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Delete Account'),
                  subtitle: const Text('Permanently delete your account'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showDeleteAccountDialog(),
                ),
                const SizedBox(height: 24),
                
                // About Section
                _buildSectionHeader('About'),
                ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('App Version'),
                  subtitle: const Text('1.0.0'),
                ),
                ListTile(
                  leading: const Icon(Icons.description),
                  title: const Text('Terms of Service'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TermsOfServiceScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PrivacyPolicyScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Account deletion feature coming soon. Please contact support.'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

