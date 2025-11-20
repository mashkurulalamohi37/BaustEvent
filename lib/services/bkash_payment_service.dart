import 'package:flutter/material.dart';
import 'package:flutter_bkash/flutter_bkash.dart';

class BKashPaymentService {
  // TODO: Replace with your actual bKash credentials
  // Get these from bKash Merchant Integration Portal: https://pgw-integration.bkash.com/
  static const String _appKey = 'YOUR_BKASH_APP_KEY';
  static const String _appSecret = 'YOUR_BKASH_APP_SECRET';
  static const String _username = 'YOUR_BKASH_USERNAME';
  static const String _password = 'YOUR_BKASH_PASSWORD';
  
  // Set to false for production
  static const bool _isSandbox = true;

  static FlutterBkash? _flutterBkash;

  /// Get or initialize FlutterBkash instance
  static FlutterBkash _getBkashInstance() {
    _flutterBkash ??= _isSandbox
        ? FlutterBkash() // Sandbox mode - no credentials needed
        : FlutterBkash(); // For production, credentials should be set via environment or config
    return _flutterBkash!;
  }

  /// Process payment with bKash
  static Future<Map<String, dynamic>> processPayment({
    required BuildContext context,
    required String transactionId,
    required double amount,
    required String eventId,
    required String eventTitle,
    required String customerName,
    required String customerPhone,
  }) async {
    try {
      final flutterBkash = _getBkashInstance();

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        // Process payment using flutter_bkash package
        final result = await flutterBkash.pay(
          context: context,
          amount: amount,
          merchantInvoiceNumber: transactionId,
        );

        // Close loading dialog
        if (context.mounted) {
          Navigator.of(context).pop();
        }

        // Check payment result
        // The result is a BkashPaymentResponse object
        // Check available properties - the package may use different field names
        final trxId = result.trxId;
        if (trxId != null && trxId.isNotEmpty) {
          return {
            'success': true,
            'transactionId': trxId,
            'amount': amount.toString(),
            'paymentID': result.paymentId ?? '',
            'message': 'Payment successful',
          };
        } else {
          return {
            'success': false,
            'message': 'Payment was cancelled or failed',
          };
        }
      } on BkashFailure catch (e) {
        // Close loading dialog if still open
        if (context.mounted) {
          Navigator.of(context).pop();
        }

        return {
          'success': false,
          'message': e.toString(),
        };
      } catch (e) {
        // Close loading dialog if still open
        if (context.mounted) {
          Navigator.of(context).pop();
        }

        return {
          'success': false,
          'message': 'Error: ${e.toString()}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error initializing payment: ${e.toString()}',
      };
    }
  }
}
