import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main() async {
  print('--- Loading .env file ---');
  final env = loadEnv('.env');
  
  final supabaseUrl = env['SUPABASE_URL'];
  final serviceRoleKey = env['SUPABASE_SERVICE_ROLE_KEY'];
  
  if (supabaseUrl == null || serviceRoleKey == null) {
    print('ERROR: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY not found in .env');
    exit(1);
  }
  
  print('Supabase URL: $supabaseUrl');
  print('Service Role Key found: ${serviceRoleKey.substring(0, 10)}...');
  
  final bucketName = 'restaurant-assets';
  
  // 1. Create the bucket (or ensure it exists)
  await ensureBucketExists(supabaseUrl, serviceRoleKey, bucketName);
  
  // 2. Scan assets/images/
  final imagesDir = Directory('assets/images');
  if (!imagesDir.existsSync()) {
    print('ERROR: assets/images directory not found');
    exit(1);
  }
  
  final files = imagesDir
      .listSync()
      .whereType<File>()
      .where((file) {
        final ext = file.path.split('.').last.toLowerCase();
        return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg'].contains(ext);
      })
      .toList();
      
  print('Found ${files.length} images to upload.');
  
  int successCount = 0;
  int failCount = 0;
  
  for (int i = 0; i < files.length; i++) {
    final file = files[i];
    final fileName = file.path.split(Platform.pathSeparator).last;
    final mimeType = getMimeType(fileName);
    final progress = '[${i + 1}/${files.length}]';
    
    print('$progress Uploading $fileName ($mimeType)...');
    
    try {
      final bytes = await file.readAsBytes();
      final uploadUrl = Uri.parse('$supabaseUrl/storage/v1/object/$bucketName/$fileName');
      
      final response = await http.post(
        uploadUrl,
        headers: {
          'Authorization': 'Bearer $serviceRoleKey',
          'apikey': serviceRoleKey,
          'Content-Type': mimeType,
          'x-upsert': 'true',
        },
        body: bytes,
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        successCount++;
        final publicUrl = '$supabaseUrl/storage/v1/object/public/$bucketName/$fileName';
        print('  => SUCCESS. Public URL: $publicUrl');
      } else {
        failCount++;
        print('  => FAILED with status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      failCount++;
      print('  => ERROR: $e');
    }
  }
  
  print('\n--- Upload Summary ---');
  print('Total attempted: ${files.length}');
  print('Successfully uploaded: $successCount');
  print('Failed: $failCount');
}

Map<String, String> loadEnv(String path) {
  final file = File(path);
  if (!file.existsSync()) return {};
  final env = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final index = trimmed.indexOf('=');
    if (index == -1) continue;
    final key = trimmed.substring(0, index).trim();
    final value = trimmed.substring(index + 1).trim();
    var cleanValue = value;
    if ((cleanValue.startsWith("'") && cleanValue.endsWith("'")) ||
        (cleanValue.startsWith('"') && cleanValue.endsWith('"'))) {
      cleanValue = cleanValue.substring(1, cleanValue.length - 1);
    }
    env[key] = cleanValue;
  }
  return env;
}

String getMimeType(String fileName) {
  final ext = fileName.split('.').last.toLowerCase();
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'svg':
      return 'image/svg+xml';
    default:
      return 'application/octet-stream';
  }
}

Future<void> ensureBucketExists(String supabaseUrl, String serviceRoleKey, String bucketName) async {
  print('Checking if bucket "$bucketName" exists or creating it...');
  final url = Uri.parse('$supabaseUrl/storage/v1/bucket');
  
  try {
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $serviceRoleKey',
        'apikey': serviceRoleKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'id': bucketName,
        'name': bucketName,
        'public': true,
        'file_size_limit': 52428800, // 50MB
        'allowed_mime_types': ['image/*'],
      }),
    );
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      print('Bucket "$bucketName" successfully created.');
    } else {
      final body = response.body;
      if (body.contains('already exists') || response.statusCode == 400 || response.statusCode == 409) {
        print('Bucket "$bucketName" already exists or configuration check finished.');
      } else {
        print('Warning creating bucket: Status ${response.statusCode}, Body: $body');
      }
    }
  } catch (e) {
    print('Error ensuring bucket exists: $e');
  }
}
