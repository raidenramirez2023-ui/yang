/// Conditional export: picks the web implementation on Flutter web,
/// falls back to the native SystemSound stub on all other platforms.
export 'sound_helper_stub.dart'
    if (dart.library.html) 'sound_helper_web.dart';
