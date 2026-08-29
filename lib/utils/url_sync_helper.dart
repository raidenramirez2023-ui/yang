import 'url_sync_helper_stub.dart'
    if (dart.library.html) 'url_sync_helper_web.dart' as impl;

/// Helper utility for syncing browser URL and handling browser back/forward buttons
class UrlSyncHelper {
  /// Updates the browser address bar URL without reloading the page or resetting state
  static void updateUrl(String path) {
    impl.updateUrlImpl(path);
  }

  /// Listens to browser back/forward popstate events
  static void Function() listenPopState(void Function(String path) onPopState) {
    return impl.listenPopStateImpl(onPopState);
  }

  /// Gets the current browser pathname
  static String getCurrentPath() {
    return impl.getCurrentPathImpl();
  }
}
