import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:excel/excel.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class ExcelExportService {
  /// Export Excel file for web - downloads directly
  static Future<void> exportExcel({
    required Excel excel,
    required String fileName,
    String? shareText,
  }) async {
    final fileBytes = excel.save();
    
    if (fileBytes == null) {
      throw Exception('Failed to generate Excel file');
    }

    // Web: Download file directly using dart:html
    _downloadFileWeb(fileBytes, fileName);
  }

  /// Download file on web
  static void _downloadFileWeb(List<int> bytes, String fileName) {
    // Create a Blob from the bytes
    final blob = html.Blob([bytes]);
    
    // Create a download link
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    
    // Clean up
    html.Url.revokeObjectUrl(url);
  }
}
