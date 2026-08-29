import 'dart:html' as html;

/// Web implementation of UrlSyncHelper using dart:html
void updateUrlImpl(String path) {
  try {
    final currentPath = html.window.location.pathname ?? '';
    if (currentPath != path) {
      html.window.history.pushState(null, '', path);
    }
  } catch (_) {}
}

void Function() listenPopStateImpl(void Function(String path) onPopState) {
  try {
    final subscription = html.window.onPopState.listen((event) {
      final currentPath = html.window.location.pathname ?? '';
      onPopState(currentPath);
    });
    return () => subscription.cancel();
  } catch (_) {
    return () {};
  }
}

String getCurrentPathImpl() {
  try {
    return html.window.location.pathname ?? '';
  } catch (_) {
    return '';
  }
}
