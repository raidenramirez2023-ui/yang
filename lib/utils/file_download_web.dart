// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:convert';
import 'dart:typed_data';

/// Triggers a real browser file download on Flutter Web.
/// Returns true to indicate success.
bool downloadTextFile(String content, String filename) {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8;');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  Future.delayed(const Duration(seconds: 15), () {
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  });
  return true;
}

/// Triggers a real browser binary file download on Flutter Web (for Excel, PDF, images, etc.).
/// Returns true to indicate success.
bool downloadBinaryFile(List<int> bytes, String filename, [String mimeType = 'application/octet-stream']) {
  final u8 = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  final blob = html.Blob([u8], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  Future.delayed(const Duration(seconds: 15), () {
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  });
  return true;
}

