import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ExcelExportService {
  /// Export Excel file for mobile - saves and shares
  static Future<void> exportExcel({
    required Excel excel,
    required String fileName,
    String? shareText,
  }) async {
    final fileBytes = excel.save();
    
    if (fileBytes == null) {
      throw Exception('Failed to generate Excel file');
    }

    // Mobile: Save and share file
    await _shareFileMobile(fileBytes, fileName, shareText ?? 'Exported data');
  }

  /// Save and share file on mobile
  static Future<void> _shareFileMobile(
    List<int> bytes,
    String fileName,
    String shareText,
  ) async {
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/$fileName';
    final file = File(path);
    
    await file.writeAsBytes(bytes);
    
    final xFile = XFile(path);
    await Share.shareXFiles(
      [xFile],
      text: shareText,
    );
  }
}
