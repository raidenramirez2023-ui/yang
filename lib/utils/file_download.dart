/// Conditional export: picks the web implementation on Flutter Web,
/// falls back to the stub (no-op / clipboard fallback) on all other platforms.
export 'file_download_stub.dart'
    if (dart.library.html) 'file_download_web.dart';
