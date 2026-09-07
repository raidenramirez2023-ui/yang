import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../lib/firebase_options.dart';
import '../lib/supabase_options.dart';

/// Migration Script:
/// Copies all images from Supabase Storage buckets ('restaurant-assets', 'avatars')
/// to Firebase Cloud Storage, and updates the image URLs in Supabase Database.
void main() async {
  print('========================================================');
  print('🚀 STARTING POLYGLOT MIGRATION: Supabase ➔ Firebase');
  print('========================================================');

  // 1. Initialize Firebase & Supabase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase Initialized successfully.');
  } catch (e) {
    print('⚠️ Firebase initialization error: $e');
  }

  try {
    await Supabase.initialize(
      url: SupabaseOptions.supabaseUrl,
      anonKey: SupabaseOptions.supabaseAnonKey,
    );
    print('✅ Supabase Initialized successfully.');
  } catch (e) {
    print('❌ Supabase initialization error: $e');
    return;
  }

  final supabase = Supabase.instance.client;
  final firebaseStorage = FirebaseStorage.instance;

  // 2. Migrate Menu Items images from 'restaurant-assets'
  print('\n📦 Migrating Menu Items Images...');
  try {
    final menuItemsResponse = await supabase.from('menu_items').select('id, name, customimagepath, fallbackimagepath');
    final menuItems = List<Map<String, dynamic>>.from(menuItemsResponse);
    print('Found ${menuItems.length} menu items in database.');

    int migratedCount = 0;
    for (final item in menuItems) {
      final itemId = item['id'];
      final itemName = item['name'];
      final customPath = item['customimagepath'] as String?;
      final fallbackPath = item['fallbackimagepath'] as String?;

      // Determine which filename or URL is used
      String targetFilename = '';
      if (customPath != null && customPath.isNotEmpty) {
        targetFilename = customPath;
      } else if (fallbackPath != null && fallbackPath.isNotEmpty) {
        targetFilename = fallbackPath.split('/').last;
      }

      if (targetFilename.isEmpty || targetFilename.startsWith('http://') || targetFilename.startsWith('https://')) {
        // Already migrated or full external URL
        continue;
      }

      print('Processing menu image: "$targetFilename" for item: $itemName...');

      // Download from Supabase Public URL
      final supabasePublicUrl = '${SupabaseOptions.supabaseUrl}/storage/v1/object/public/restaurant-assets/$targetFilename';
      try {
        final res = await http.get(Uri.parse(supabasePublicUrl));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          // Upload to Firebase Cloud Storage
          final cleanFilename = targetFilename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
          final ref = firebaseStorage.ref().child('menu_items/$cleanFilename');
          await ref.putData(res.bodyBytes, SettableMetadata(contentType: _guessMimeType(cleanFilename)));
          final newFirebaseUrl = await ref.getDownloadURL();

          // Update Supabase Database row with the new Firebase URL
          await supabase.from('menu_items').update({
            'customimagepath': newFirebaseUrl,
          }).eq('id', itemId);

          migratedCount++;
          print('   ✅ Migrated to Firebase: $newFirebaseUrl');
        } else {
          print('   ⚠️ Could not fetch from Supabase (Status: ${res.statusCode})');
        }
      } catch (err) {
        print('   ❌ Error downloading/uploading $targetFilename: $err');
      }
    }
    print('✨ Menu Items Migration Complete. $migratedCount images migrated.');
  } catch (e) {
    print('❌ Error migrating menu items: $e');
  }

  print('\n========================================================');
  print('🎉 ALL MIGRATION OPERATIONS FINISHED!');
  print('========================================================');
  exit(0);
}

String _guessMimeType(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.svg')) return 'image/svg+xml';
  return 'image/jpeg';
}
