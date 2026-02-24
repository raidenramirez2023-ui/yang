import 'package:supabase_flutter/supabase_flutter.dart';

class RoleHelper {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Check if current user is admin
  static Future<bool> isAdmin() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
      final response = await _supabase
          .from('users')
          .select('role')
          .eq('email', user.email!)
          .maybeSingle();

      final role = response?['role']?.toString().toLowerCase() ?? 'staff';
      return role == 'admin';
    } catch (e) {
      print('Error checking admin role: $e');
      return false;
    }
  }

  // Get current user role
  static Future<String> getCurrentUserRole() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 'staff';

    try {
      final response = await _supabase
          .from('users')
          .select('role')
          .eq('email', user.email!)
          .maybeSingle();

      return response?['role']?.toString().toLowerCase() ?? 'staff';
    } catch (e) {
      print('Error getting user role: $e');
      return 'staff';
    }
  }

  // Check if user can access admin features
  static Future<bool> canAccessAdminFeatures() async {
    return await isAdmin();
  }

  // Check if user can access staff features
  static Future<bool> canAccessStaffFeatures() async {
    final user = _supabase.auth.currentUser;
    return user != null;
  }
}
