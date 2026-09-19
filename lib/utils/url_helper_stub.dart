/// Stub implementation for non-web platforms.
/// URL history manipulation is a no-op outside of web.
void pushUrlState(String path) {
  // No-op on non-web platforms
}

/// Stub: opening external URLs is a no-op on non-web platforms.
void openUrlInNewTab(String url) {
  // No-op on non-web platforms
}
