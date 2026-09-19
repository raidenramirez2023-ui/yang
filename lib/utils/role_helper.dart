import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RoleHelper {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Check if current user is admin (or developer testing superuser)
  static Future<bool> isAdmin() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    // Fast path: developer email has full admin test access
    if (user.email?.toLowerCase() == 'yangchowit@gmail.com') return true;

    try {
      final response = await _supabase
          .from('users')
          .select('role')
          .eq('email', user.email!)
          .maybeSingle();

      final role = response?['role']?.toString().toLowerCase() ?? 'staff';
      return role == 'admin' || role == 'developer';
    } catch (e) {
      debugPrint('Error checking admin role: $e');
      return false;
    }
  }

  // Get current user role
  static Future<String> getCurrentUserRole() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 'staff';

    if (user.email?.toLowerCase() == 'yangchowit@gmail.com') return 'developer';

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
    
    // Developer, pagsanjaninv@gmail.com and inventory staff have full inventory control
    if (role == 'developer' || userEmail == 'yangchowit@gmail.com' || userEmail == 'pagsanjaninv@gmail.com' || role == 'inventory staff') {
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
    
    // Developer, pagsanjaninv@gmail.com and inventory staff can manage inventory
    return role == 'developer' || userEmail == 'yangchowit@gmail.com' || userEmail == 'pagsanjaninv@gmail.com' || role == 'inventory staff';
  }

  // Check if current user is developer
  static Future<bool> isDeveloper() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    if (user.email?.toLowerCase() == 'yangchowit@gmail.com') return true;

    try {
      final response = await _supabase
          .from('users')
          .select('role')
          .eq('email', user.email!)
          .maybeSingle();

      final role = response?['role']?.toString().toLowerCase() ?? '';
      return role == 'developer';
    } catch (e) {
      debugPrint('Error checking developer role: $e');
      return false;
    }
  }

  // Get dashboard route for current user
  static Future<String> getDashboardRoute() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return '/';

    final userEmail = user.email?.toLowerCase() ?? '';
    final role = await getCurrentUserRole();
    
    // pagsanjaninv@gmail.com and inventory staff get special dashboard
    if (userEmail == 'pagsanjaninv@gmail.com' || role == 'inventory staff' || role == 'pagsanjaninv') {
      return '/inventory/dashboard';
    }
    
    switch (role) {
      case 'developer':
        return '/developer/dashboard';
      case 'admin':
        return '/admin/dashboard';
      case 'chef':
        return '/chef/dashboard';
      case 'staff':
        return '/staff/dashboard';
      default:
        return '/customer/dashboard';
    }
  }
}

