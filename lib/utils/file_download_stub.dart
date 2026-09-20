/// Stub for non-web platforms.
/// On desktop/mobile, file download via browser is not applicable.
/// Returns false so the caller can fallback to clipboard.
bool downloadTextFile(String content, String filename) {
  return false; // Not supported on this platform
}
