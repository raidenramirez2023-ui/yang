import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const url = 'https://tvzbsvqaikjkxrqykrhw.supabase.co/rest/v1/rpc/exec_sql';
  const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR2emJzdnFhaWtqa3hycXlrcmh3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE5MTIwNzQsImV4cCI6MjA4NzQ4ODA3NH0.5cE-OTWEgLTP2vgteqk6-8bfw-ZGahdc8dBJOaUtzrQ';

  final headers = {
    'apikey': anonKey,
    'Authorization': 'Bearer $anonKey',
    'Content-Type': 'application/json',
  };

  try {
    print('Sending migration requests to Supabase...');
    
    // 1. Add is_archived column
    final res1 = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode({
        'sql': 'ALTER TABLE public.reservations ADD COLUMN IF NOT EXISTS is_archived BOOLEAN DEFAULT false;'
      }),
    );
    print('is_archived response: status=${res1.statusCode}, body=${res1.body}');

    // 2. Add uploaded_id_url column
    final res2 = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode({
        'sql': 'ALTER TABLE public.reservations ADD COLUMN IF NOT EXISTS uploaded_id_url TEXT;'
      }),
    );
    print('uploaded_id_url response: status=${res2.statusCode}, body=${res2.body}');

    // 3. Reload schema cache
    final res3 = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode({
        'sql': "NOTIFY pgrst, 'reload schema';"
      }),
    );
    print('Reload cache response: status=${res3.statusCode}, body=${res3.body}');

    print('Done!');
  } catch (e) {
    print('Error: $e');
  }
}
