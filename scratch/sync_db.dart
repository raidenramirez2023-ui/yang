import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/supabase_options.dart';

void main() async {
  print('Initializing Supabase client...');
  final supabase = SupabaseClient(
    SupabaseOptions.supabaseUrl,
    SupabaseOptions.supabaseAnonKey,
  );

  try {
    print('Running exec_sql RPC for is_archived...');
    await supabase.rpc('exec_sql', params: {
      'sql': "ALTER TABLE public.reservations ADD COLUMN IF NOT EXISTS is_archived BOOLEAN DEFAULT false;"
    });

    print('Running exec_sql RPC for uploaded_id_url...');
    await supabase.rpc('exec_sql', params: {
      'sql': "ALTER TABLE public.reservations ADD COLUMN IF NOT EXISTS uploaded_id_url TEXT;"
    });

    print('Reloading PostgREST schema cache...');
    await supabase.rpc('exec_sql', params: {
      'sql': "NOTIFY pgrst, 'reload schema';"
    });

    print('✅ Database schema synchronized successfully!');
  } catch (e) {
    print('❌ Error running database migration: $e');
  }
}
