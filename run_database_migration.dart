import 'package:supabase_flutter/supabase_flutter.dart';

// Temporary script to run database migration
// Run this once in your app, then remove it
Future<void> runDatabaseMigration() async {
  final supabase = Supabase.instance.client;
  
  try {
    // Add expiration_date column
    await supabase.rpc('exec_sql', params: {
      'sql': '''
        ALTER TABLE public.announcements 
        ADD COLUMN IF NOT EXISTS expiration_date TIMESTAMP WITH TIME ZONE;
        
        UPDATE public.announcements 
        SET expiration_date = created_at + INTERVAL '7 days' 
        WHERE expiration_date IS NULL;

        ALTER TABLE public.reservations 
        ADD COLUMN IF NOT EXISTS is_archived BOOLEAN DEFAULT false;
      '''
    });
    
    print('Database migration completed successfully!');
  } catch (e) {
    print('Migration error: $e');
  }
}
