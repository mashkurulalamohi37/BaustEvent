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
    // mobile_scanner supports web, iOS, Android, and macOS
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
