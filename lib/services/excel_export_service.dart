// Main export service that delegates to platform-specific implementations
export 'excel_export_service_stub.dart'
    if (dart.library.io) 'excel_export_service_mobile.dart'
    if (dart.library.html) 'excel_export_service_web.dart';
