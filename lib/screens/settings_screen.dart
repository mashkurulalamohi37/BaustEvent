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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20.0),
              children: [
                // Notifications Section
                _buildSectionCard(
                  title: 'Notifications',
                  icon: Icons.notifications_outlined,
                  iconColor: Colors.orange,
                  children: [
                    _buildSwitchTile(
                      title: 'Enable Notifications',
                      subtitle: 'Receive notifications about events',
                      value: _notificationsEnabled,
                      icon: Icons.notifications_outlined,
                      iconColor: Colors.orange,
                      onChanged: (value) {
                        setState(() => _notificationsEnabled = value);
                        _saveSetting('notifications_enabled', value);
                      },
                    ),
                    if (_notificationsEnabled) ...[
                      _buildDivider(),
                      _buildSwitchTile(
                        title: 'Email Notifications',
                        subtitle: 'Receive notifications via email',
                        value: _emailNotifications,
                        icon: Icons.email_outlined,
                        iconColor: Colors.blue,
                        onChanged: (value) {
                          setState(() => _emailNotifications = value);
                          _saveSetting('email_notifications', value);
                        },
                      ),
                      _buildDivider(),
                      _buildSwitchTile(
                        title: 'Push Notifications',
                        subtitle: 'Receive push notifications on your device',
                        value: _pushNotifications,
                        icon: Icons.phone_android_outlined,
                        iconColor: Colors.green,
                        onChanged: (value) {
                          setState(() => _pushNotifications = value);
                          _saveSetting('push_notifications', value);
                        },
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                
                // Appearance Section
                _buildSectionCard(
                  title: 'Appearance',
                  icon: Icons.palette_outlined,
                  iconColor: Colors.purple,
                  children: [
                    _buildSwitchTile(
                      title: 'Dark Mode',
                      subtitle: 'Use dark theme',
                      value: _darkMode,
                      icon: Icons.dark_mode_outlined,
                      iconColor: Colors.purple,
                      onChanged: (value) async {
                        setState(() => _darkMode = value);
                        await _saveSetting('dark_mode', value);
                        await _themeService.setTheme(value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Account Section
                _buildSectionCard(
                  title: 'Account',
                  icon: Icons.person_outline,
                  iconColor: Colors.blue,
                  children: [
                    _buildListTile(
                      title: 'Change Password',
                      subtitle: 'Update your account password',
                      icon: Icons.lock_outline,
                      iconColor: Colors.blue,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ChangePasswordScreen(),
                          ),
                        );
                      },
                    ),
                    _buildDivider(),
                    _buildListTile(
                      title: 'Delete Account',
                      subtitle: 'Permanently delete your account',
                      icon: Icons.delete_outline,
                      iconColor: Colors.red,
                      onTap: () => _showDeleteAccountDialog(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // About Section
                _buildSectionCard(
                  title: 'About',
                  icon: Icons.info_outline,
                  iconColor: Colors.grey,
                  children: [
                    _buildListTile(
                      title: 'App Version',
                      subtitle: '1.0.0',
                      icon: Icons.info_outline,
                      iconColor: Colors.grey,
                      onTap: null,
                    ),
                    _buildDivider(),
                    _buildListTile(
                      title: 'Terms of Service',
                      subtitle: 'Read our terms and conditions',
                      icon: Icons.description_outlined,
                      iconColor: Colors.grey,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TermsOfServiceScreen(),
                          ),
                        );
                      },
                    ),
                    _buildDivider(),
                    _buildListTile(
                      title: 'Privacy Policy',
                      subtitle: 'Learn how we protect your data',
                      icon: Icons.privacy_tip_outlined,
                      iconColor: Colors.grey,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PrivacyPolicyScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? iconColor.withOpacity(0.2) 
                        : iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    required Color iconColor,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark 
                    ? iconColor.withOpacity(0.2) 
                    : iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF1976D2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark 
                    ? iconColor.withOpacity(0.2) 
                    : iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: isDark ? Colors.grey[500] : Colors.grey[400],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      thickness: 1,
      indent: 60,
      endIndent: 20,
      color: isDark ? Colors.grey[700] : Colors.grey[300],
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

