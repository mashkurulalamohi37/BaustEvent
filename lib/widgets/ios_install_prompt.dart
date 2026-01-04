import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html show window;

/// A widget that shows installation instructions for iOS users
/// when the app is accessed via web browser (not installed as PWA)
class IOSInstallPrompt extends StatefulWidget {
  const IOSInstallPrompt({super.key});

  @override
  State<IOSInstallPrompt> createState() => _IOSInstallPromptState();
}

class _IOSInstallPromptState extends State<IOSInstallPrompt> {
  bool _isVisible = false;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    _checkIfShouldShow();
  }

  void _checkIfShouldShow() {
    if (!kIsWeb) {
      // Not running on web, don't show
      return;
    }

    try {
      // Check if running as standalone PWA
      final isStandalone = html.window.matchMedia('(display-mode: standalone)').matches;
      
      // Check if on iOS
      final userAgent = html.window.navigator.userAgent;
      final isIOS = userAgent.contains('iPhone') || 
                    userAgent.contains('iPad') || 
                    userAgent.contains('iPod');

      // Show only if on iOS and NOT installed
      if (isIOS && !isStandalone) {
        // Check if user has dismissed before
        final dismissed = html.window.localStorage['ios-install-dismissed'];
        if (dismissed != 'true') {
          // Show after a delay
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _isVisible = true;
              });
            }
          });
        }
      }
    } catch (e) {
      // Silently fail if web APIs not available
      print('Error checking install status: $e');
    }
  }

  void _dismiss() {
    try {
      html.window.localStorage['ios-install-dismissed'] = 'true';
    } catch (e) {
      print('Error saving dismiss state: $e');
    }
    
    setState(() {
      _isDismissed = true;
      _isVisible = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible || _isDismissed) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Material(
        elevation: 8,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColor.withBlue(255),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.install_mobile,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Install EventBridge',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            RichText(
                              text: const TextSpan(
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                                children: [
                                  TextSpan(text: 'Tap '),
                                  TextSpan(
                                    text: 'Share ',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(text: '⬆️ then '),
                                  TextSpan(
                                    text: 'Add to Home Screen',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(text: ' for the best experience!'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Close button
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: _dismiss,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Dismiss button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _dismiss,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Got it, thanks!',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper widget to wrap your app and show install prompt
class PWAWrapper extends StatelessWidget {
  final Widget child;
  final bool showInstallPrompt;

  const PWAWrapper({
    super.key,
    required this.child,
    this.showInstallPrompt = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (showInstallPrompt && kIsWeb)
          const IOSInstallPrompt(),
      ],
    );
  }
}
