import 'package:excel/excel.dart';

class ExcelExportService {
  /// Stub implementation - should never be called
  static Future<void> exportExcel({
    required Excel excel,
    required String fileName,
    String? shareText,
  }) async {
    throw UnsupportedError('Excel export not supported on this platform');
  }
}
