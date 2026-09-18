/// Conditional export: picks the web implementation on Flutter web,
/// falls back to the stub (no-op) on all other platforms.
export 'url_helper_stub.dart'
    if (dart.library.html) 'url_helper_web.dart';
