import 'package:flutter/foundation.dart';
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
      debugPrint('Error checking admin role: $e');
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
      debugPrint('Error getting user role: $e');
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

  // Check if user has full admin permissions (not view-only)
  static Future<bool> hasFullAdminPermissions() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    final userEmail = user.email?.toLowerCase() ?? '';
    final role = await getCurrentUserRole();
    
    // pagsanjaninv@gmail.com and inventory staff have full inventory control
    if (userEmail == 'pagsanjaninv@gmail.com' || role == 'inventory staff') {
      return true;
    }

    // Other admins have view-only access
    return false;
  }

  // Check if user can manage inventory (add/edit/delete)
  static Future<bool> canManageInventory() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    final userEmail = user.email?.toLowerCase() ?? '';
    final role = await getCurrentUserRole();
    
    // pagsanjaninv@gmail.com and inventory staff can manage inventory
    return userEmail == 'pagsanjaninv@gmail.com' || role == 'inventory staff';
  }

  // Get dashboard route for current user
  static Future<String> getDashboardRoute() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return '/';

    final userEmail = user.email?.toLowerCase() ?? '';
    final role = await getCurrentUserRole();
    
    // pagsanjaninv@gmail.com and inventory staff get special dashboard
    if (userEmail == 'pagsanjaninv@gmail.com' || role == 'inventory staff') {
      return '/pagsanjaninv-dashboard';
    }
    
    switch (role) {
      case 'admin':
        return '/dashboard';
      case 'staff':
        return '/staff-dashboard';
      default:
        return '/customer-dashboard';
    }
  }
}
