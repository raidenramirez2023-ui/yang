/// Stub implementation for non-web platforms (Android, iOS, Desktop)
void updateUrlImpl(String path) {
  // No-op on mobile/desktop platforms
}

void Function() listenPopStateImpl(void Function(String path) onPopState) {
  // No-op on mobile/desktop platforms
  return () {};
}

String getCurrentPathImpl() {
  return '';
}
