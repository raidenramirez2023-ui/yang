import 'package:web/web.dart' as web;

/// Updates the browser address bar URL using the History API.
/// This does NOT trigger a Flutter navigation — no page rebuild, no AuthGuard reload.
void pushUrlState(String path) {
  web.window.history.pushState(null, path, path);
}

/// Opens a URL in a new browser tab.
void openUrlInNewTab(String url) {
  web.window.open(url, '_blank');
}
