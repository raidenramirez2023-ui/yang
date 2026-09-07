import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_options.dart';

/// Centralized Image Storage Service for Polyglot Database Architecture.
///
/// Images, receipts, and media files are stored in Google Firebase Cloud Storage,
/// while structured relational data, prices, orders, and references remain in Supabase PostgreSQL.
class ImageStorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads a menu item image to Firebase Storage (`menu_items/`).
  /// Returns the public download URL, or null if the upload failed.
  static Future<String?> uploadMenuImage({
    required Uint8List bytes,
    required String fileName,
    String? contentType,
  }) async {
    try {
      final sanitizedName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final ref = _storage.ref().child('menu_items/$sanitizedName');
      
      final metadata = SettableMetadata(
        contentType: contentType ?? _guessContentType(sanitizedName),
      );

      final uploadTask = await ref.putData(bytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      debugPrint('✅ Menu image uploaded to Firebase: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('❌ Failed to upload menu image to Firebase: $e');
      return null;
    }
  }

  /// Uploads a user/customer/staff avatar to Firebase Storage (`avatars/`).
  /// Returns the public download URL, or null on failure.
  static Future<String?> uploadAvatar({
    required Uint8List bytes,
    required String userId,
    String extension = 'jpg',
  }) async {
    try {
      final fileName = 'avatar_${userId}_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final ref = _storage.ref().child('avatars/$fileName');
      
      final metadata = SettableMetadata(
        contentType: _guessContentType(fileName),
      );

      final uploadTask = await ref.putData(bytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      debugPrint('✅ Avatar uploaded to Firebase: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('❌ Failed to upload avatar to Firebase: $e');
      return null;
    }
  }

  /// Uploads a chat image attachment to Firebase Storage (`chat_images/`).
  static Future<String?> uploadChatImage({
    required Uint8List bytes,
    required String customerEmail,
    required String fileName,
  }) async {
    try {
      final sanitizedEmail = customerEmail.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final sanitizedName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final path = 'chat_images/$sanitizedEmail/$sanitizedName';
      final ref = _storage.ref().child(path);

      final metadata = SettableMetadata(
        contentType: _guessContentType(fileName),
      );

      final uploadTask = await ref.putData(bytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      debugPrint('✅ Chat image uploaded to Firebase: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('❌ Failed to upload chat image to Firebase: $e');
      return null;
    }
  }

  /// Uploads a payment receipt / voucher / PDF to Firebase Storage (`receipts/`).
  static Future<String?> uploadReceipt({
    required Uint8List bytes,
    required String fileName,
    String contentType = 'application/pdf',
  }) async {
    try {
      final sanitizedName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final ref = _storage.ref().child('receipts/$sanitizedName');

      final metadata = SettableMetadata(contentType: contentType);
      final uploadTask = await ref.putData(bytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      debugPrint('✅ Receipt uploaded to Firebase: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('❌ Failed to upload receipt to Firebase: $e');
      return null;
    }
  }

  /// In-app migration method to copy Supabase images to Firebase Cloud Storage.
  /// Can be triggered directly from the Admin UI (Backup/Restore or Menu Management).
  static Future<Map<String, dynamic>> syncAndMigrateMenuImages({
    void Function(String message)? onProgress,
  }) async {
    int total = 0;
    int migrated = 0;
    int skipped = 0;
    int failed = 0;

    try {
      final supabase = Supabase.instance.client;
      onProgress?.call('Fetching menu items from database...');
      
      final menuItemsResponse = await supabase
          .from('menu_items')
          .select('id, name, customimagepath, fallbackimagepath');

      final menuItems = List<Map<String, dynamic>>.from(menuItemsResponse);
      total = menuItems.length;

      for (int i = 0; i < menuItems.length; i++) {
        final item = menuItems[i];
        final itemId = item['id'];
        final itemName = item['name'] ?? 'Item';
        final customPath = item['customimagepath'] as String?;
        final fallbackPath = item['fallbackimagepath'] as String?;

        String target = '';
        if (customPath != null && customPath.trim().isNotEmpty) {
          target = customPath.trim();
        } else if (fallbackPath != null && fallbackPath.trim().isNotEmpty) {
          target = fallbackPath.trim().split('/').last;
        }

        // Already a full Firebase or external URL
        if (target.isEmpty || target.startsWith('http://') || target.startsWith('https://')) {
          skipped++;
          continue;
        }

        // Extract pure filename
        String cleanTarget = target;
        if (cleanTarget.contains('/')) {
          cleanTarget = cleanTarget.split('/').last;
        }

        onProgress?.call('Migrating [$i/${menuItems.length}]: $itemName ($cleanTarget)...');

        Uint8List? imageBytes;

        // 1. Try downloading directly via Supabase Storage API (bypasses browser CORS)
        try {
          imageBytes = await supabase.storage
              .from('restaurant-assets')
              .download(cleanTarget);
        } catch (e1) {
          debugPrint('Storage API download failed for $cleanTarget: $e1');
        }

        // 2. Fallback to HTTP GET if Storage API returned empty
        if (imageBytes == null || imageBytes.isEmpty) {
          try {
            final supabaseUrl = '${SupabaseOptions.supabaseUrl}/storage/v1/object/public/restaurant-assets/$cleanTarget';
            final res = await http.get(Uri.parse(supabaseUrl));
            if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
              imageBytes = res.bodyBytes;
            }
          } catch (e2) {
            debugPrint('HTTP download failed for $cleanTarget: $e2');
          }
        }

        if (imageBytes != null && imageBytes.isNotEmpty) {
          try {
            final downloadUrl = await uploadMenuImage(
              bytes: imageBytes,
              fileName: cleanTarget,
            );

            if (downloadUrl != null) {
              await supabase.from('menu_items').update({
                'customimagepath': downloadUrl,
              }).eq('id', itemId);
              migrated++;
            } else {
              failed++;
            }
          } catch (uploadErr) {
            debugPrint('Upload error for $cleanTarget: $uploadErr');
            failed++;
          }
        } else {
          debugPrint('No image bytes found for $cleanTarget');
          failed++;
        }
      }
    } catch (e) {
      debugPrint('Error in syncAndMigrateMenuImages: $e');
    }

    return {
      'total': total,
      'migrated': migrated,
      'skipped': skipped,
      'failed': failed,
    };
  }

  static String _guessContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.svg')) return 'image/svg+xml';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return 'image/jpeg';
  }
}
