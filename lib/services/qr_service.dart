import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';

class QRService {
  static const _uuid = Uuid();
  
  // Generate QR code data for event registration
  static String generateEventQRData(String eventId, String userId) {
    final qrData = {
      'type': 'event_registration',
      'eventId': eventId,
      'userId': userId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'id': _uuid.v4(),
    };
    return jsonEncode(qrData);
  }
  
  // Generate QR code data for event check-in
  static String generateCheckInQRData(String eventId, String userId) {
    final qrData = {
      'type': 'event_checkin',
      'eventId': eventId,
      'userId': userId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'id': _uuid.v4(),
    };
    return jsonEncode(qrData);
  }
  
  // Parse QR code data
  static Map<String, dynamic>? parseQRData(String qrData) {
    try {
      return jsonDecode(qrData) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }
  
  // Validate QR code data
  static bool isValidQRData(Map<String, dynamic>? qrData) {
    if (qrData == null) return false;
    
    final requiredFields = ['type', 'eventId', 'userId', 'timestamp', 'id'];
    return requiredFields.every((field) => qrData.containsKey(field));
  }
  
  // Check if QR code is for event registration
  static bool isEventRegistrationQR(Map<String, dynamic>? qrData) {
    return qrData?['type'] == 'event_registration';
  }
  
  // Check if QR code is for event check-in
  static bool isEventCheckInQR(Map<String, dynamic>? qrData) {
    return qrData?['type'] == 'event_checkin';
  }
  
  // Generate QR code widget
  static QrImageView generateQRCodeWidget(String data, {double size = 200}) {
    return QrImageView(
      data: data,
      version: QrVersions.auto,
      size: size,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
    );
  }

  // Build QR scanner widget
  static Widget buildQRScannerWidget({
    required Function(String) onCodeScanned,
    required VoidCallback onScannerReady,
  }) {
    // Check if mobile_scanner is supported on this platform
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.macOS) {
      // For macOS and web, show a text input as fallback
      return _buildTextInputScanner(onCodeScanned);
    }
    
    return MobileScanner(
      onDetect: (capture) {
        final List<Barcode> barcodes = capture.barcodes;
        for (final barcode in barcodes) {
          if (barcode.rawValue != null) {
            onCodeScanned(barcode.rawValue!);
            break;
          }
        }
      },
    );
  }

  // Fallback text input for platforms without camera support
  static Widget _buildTextInputScanner(Function(String) onCodeScanned) {
    final controller = TextEditingController();
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.qr_code_scanner, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Enter QR Code Data',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'QR Code Data',
              border: OutlineInputBorder(),
              hintText: 'Paste QR code data here',
            ),
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                onCodeScanned(value);
              }
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                onCodeScanned(controller.text);
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  // Validate QR code data
  static bool isValidEventQRCode(String qrData) {
    try {
      final data = jsonDecode(qrData);
      return data['type'] == 'event_registration' && 
             data['eventId'] != null && 
             data['userId'] != null;
    } catch (e) {
      return false;
    }
  }

  // Extract event ID from QR code
  static String? extractEventIdFromQR(String qrData) {
    try {
      final data = jsonDecode(qrData);
      if (data['type'] == 'event_registration') {
        return data['eventId'];
      }
    } catch (e) {
      // Invalid QR code
    }
    return null;
  }

  // Extract user ID from QR code
  static String? extractUserIdFromQR(String qrData) {
    try {
      final data = jsonDecode(qrData);
      if (data['type'] == 'event_registration') {
        return data['userId'];
      }
    } catch (e) {
      // Invalid QR code
    }
    return null;
  }
}
