import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class ShareAppScreen extends StatelessWidget {
  static const String appUrl = 'https://walkie-7a9dc.web.app';
  
  const ShareAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share App'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // App Icon/Logo
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1976D2).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.share,
                size: 48,
                color: Color(0xFF1976D2),
              ),
            ),
            const SizedBox(height: 24),
            
            // Title
            const Text(
              'Share with iOS Users',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            
            // Subtitle
            Text(
              'Help your friends install the app on their iPhone or iPad',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // QR Code Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // QR Code
                  QrImageView(
                    data: appUrl,
                    version: QrVersions.auto,
                    size: 220,
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                  const SizedBox(height: 16),
                  
                  // URL Text
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            appUrl,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _copyToClipboard(context),
                          child: Icon(
                            Icons.copy,
                            size: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Installation Instructions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.blue[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.grey[700]! : Colors.blue[200]!,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.apple,
                        color: isDark ? Colors.white : Colors.blue[900],
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'iOS Installation Guide',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.blue[900],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  _buildInstructionStep(
                    number: '1',
                    text: 'Scan the QR code or open the link in Safari',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  
                  _buildInstructionStep(
                    number: '2',
                    text: 'Tap the Share button (square with arrow)',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  
                  _buildInstructionStep(
                    number: '3',
                    text: 'Scroll down and tap "Add to Home Screen"',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  
                  _buildInstructionStep(
                    number: '4',
                    text: 'Tap "Add" to install the app',
                    isDark: isDark,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: isDark ? Colors.blue[300] : Colors.blue[700],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Must use Safari browser for installation',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.blue[300] : Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copyToClipboard(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF1976D2)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.copy, size: 20),
                    label: const Text('Copy Link'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _shareLink(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.share, size: 20),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep({
    required String number,
    required String text,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isDark ? Colors.blue[700] : Colors.blue[600],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.grey[300] : Colors.grey[800],
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(const ClipboardData(text: appUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied to clipboard'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareLink(BuildContext context) {
    Share.share(
      'Install our app on your iPhone/iPad:\n\n'
      '1. Open this link in Safari: $appUrl\n'
      '2. Tap the Share button\n'
      '3. Select "Add to Home Screen"\n'
      '4. Tap "Add" to install\n\n'
      'Enjoy the app!',
      subject: 'Install Our App',
    );
  }
}
