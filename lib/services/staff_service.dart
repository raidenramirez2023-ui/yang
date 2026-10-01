import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_options.dart';

class StaffService {
  static const String storageKey = 'yang_chow_staff_directory_v2';
  static const String supabaseSettingKey = 'staff_directory_list';

  // Default fallback staff list (kept empty for clean production initialization)
  static final List<Map<String, dynamic>> defaultStaff = [];

  /// Load all staff from Supabase DB or persistent storage fallback
  static Future<List<Map<String, dynamic>>> loadStaffList() async {
    // 0. Pre-load local cached staff to preserve images and emails if DB table lacks those columns
    final Map<String, String> cachedImages = {};
    final Map<String, String> cachedEmails = {};
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(storageKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw);
        for (final item in decoded) {
          final id = (item['id'] ?? item['employee_id'] ?? '').toString().trim().toUpperCase();
          final img = (item['image'] ?? '').toString().trim();
          final em = (item['email'] ?? '').toString().trim().toLowerCase();
          if (id.isNotEmpty && img.isNotEmpty) {
            cachedImages[id] = img;
          }
          if (id.isNotEmpty && em.isNotEmpty) {
            cachedEmails[id] = em;
          }
        }
      }
    } catch (_) {}

    // 1. Try loading from Supabase DB `staff` table first
    try {
      final supabase = Supabase.instance.client;
      final List<dynamic> dbRows = await supabase
          .from('staff')
          .select()
          .order('employee_id', ascending: true);

      if (dbRows.isNotEmpty) {
        // Pre-fetch auth users from `public.users` to link work emails by name, phone, or employee_id
        final Map<String, String> nameToEmail = {};
        final Map<String, String> phoneToEmail = {};
        try {
          final List<dynamic> userRows = await supabase
              .from('users')
              .select('email, firstname, lastname, phone');
          for (final u in userRows) {
            final email = (u['email'] ?? '').toString().trim().toLowerCase();
            if (email.isEmpty) continue;
            final fn = (u['firstname'] ?? '').toString().trim().toLowerCase();
            final ln = (u['lastname'] ?? '').toString().trim().toLowerCase();
            final fullName = ln.isNotEmpty ? '$fn $ln' : fn;
            if (fullName.isNotEmpty) nameToEmail[fullName] = email;
            if (fn.isNotEmpty) nameToEmail[fn] = email;
            final ph = (u['phone'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '');
            if (ph.isNotEmpty && ph.length >= 10) {
              phoneToEmail[ph.substring(ph.length - 10)] = email;
            }
          }
        } catch (userErr) {
          debugPrint('[StaffService] Note loading public.users for email linking: $userErr');
        }

        final list = dbRows.map((row) {
          final empId = (row['employee_id'] ?? row['id'] ?? '').toString().trim();
          final role = (row['role'] ?? '').toString();
          final title = (row['title'] ?? '').toString();
          final dept = _inferDepartment(role, title);
          final levelRaw = row['level'];
          final int level = levelRaw is int ? levelRaw : int.tryParse(levelRaw?.toString() ?? '2') ?? 2;
          final status = (row['status'] ?? 'Active').toString().toLowerCase();

          // If DB table has 'image' column, trust DB value directly.
          // IMPORTANT: Do NOT resurrect deleted photo if DB has the column and value is null or empty.
          // Only fallback to cache if DB table has no 'image' column in schema at all.
          String staffImage;
          if (row.containsKey('image')) {
            staffImage = (row['image'] ?? '').toString().trim();
          } else if (cachedImages.containsKey(empId.toUpperCase())) {
            staffImage = cachedImages[empId.toUpperCase()]!;
          } else {
            staffImage = '';
          }

          // Resolve work email: check row first, then local cache, then match with public.users
          final nameClean = (row['name'] ?? '').toString().trim().toLowerCase();
          final phoneDigits = (row['phone'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '');
          final phoneKey = phoneDigits.length >= 10 ? phoneDigits.substring(phoneDigits.length - 10) : '';

          String resolvedEmail = (row['email'] ?? '').toString().trim().toLowerCase();
          if (resolvedEmail.isEmpty && cachedEmails.containsKey(empId.toUpperCase())) {
            resolvedEmail = cachedEmails[empId.toUpperCase()]!;
          }
          if (resolvedEmail.isEmpty && nameToEmail.containsKey(nameClean)) {
            resolvedEmail = nameToEmail[nameClean]!;
          }
          if (resolvedEmail.isEmpty && phoneKey.isNotEmpty && phoneToEmail.containsKey(phoneKey)) {
            resolvedEmail = phoneToEmail[phoneKey]!;
          }

          return {
            'id': empId,
            'db_uuid': row['id']?.toString(),
            'employee_id': empId,
            'name': (row['name'] ?? '').toString(),
            'full_name': (row['name'] ?? '').toString(),
            'title': title,
            'role': role,
            'dept': dept,
            'level': level,
            'status': status == 'inactive'
                ? 'inactive'
                : (status.contains('leave')
                    ? 'on-leave'
                    : (status.contains('archive') ? 'archived' : 'active')),
            'phone': (row['phone'] ?? '').toString().isNotEmpty ? row['phone'].toString() : '+63 900 000 0000',
            'image': staffImage,
            'email': resolvedEmail,
            'colorHex': _getDeptColorHex(dept),
            'date_hired': (row['created_at'] ?? '').toString().isNotEmpty 
                ? row['created_at'].toString() 
                : DateTime.now().toIso8601String(),
          };
        }).toList();

        // Cache to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(storageKey, jsonEncode(list));
        debugPrint('[StaffService] Successfully loaded ${list.length} staff records from Supabase "staff" table (emails linked)');
        return list;
      }
    } catch (e) {
      debugPrint('[StaffService] Supabase "staff" table load note (trying app_settings/cache): $e');
    }

    // 2. Try loading from Supabase app_settings fallback
    try {
      final supabase = Supabase.instance.client;
      final res = await supabase
          .from('app_settings')
          .select('setting_value')
          .eq('setting_key', supabaseSettingKey)
          .maybeSingle();

      if (res != null && res['setting_value'] != null) {
        final raw = res['setting_value'].toString();
        if (raw.isNotEmpty) {
          final List<dynamic> decoded = jsonDecode(raw);
          final list = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
          if (list.isNotEmpty) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(storageKey, jsonEncode(list));
            return list;
          }
        }
      }
    } catch (e) {
      debugPrint('[StaffService] Supabase app_settings fallback error: $e');
    }

    // 3. Fallback to local SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(storageKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw);
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      debugPrint('[StaffService] Error loading local staff list: $e');
    }
    return List<Map<String, dynamic>>.from(defaultStaff);
  }

  /// Helper to infer department from role & title
  static String _inferDepartment(String role, String title) {
    final r = role.toLowerCase();
    final t = title.toLowerCase();
    if (r.contains('manager') || r.contains('supervisor') || r.contains('admin') || t.contains('manager')) {
      return 'Management';
    } else if (r.contains('cook') || r.contains('chef') || r.contains('cutter') || t.contains('cook') || t.contains('chef') || t.contains('prep')) {
      return 'Kitchen';
    } else if (r.contains('server') || r.contains('wait') || t.contains('server') || t.contains('wait')) {
      return 'Service';
    } else if (r.contains('dish') || r.contains('utility') || r.contains('cashier') || t.contains('utility') || t.contains('cashier')) {
      return 'Operations';
    }
    return 'Operations';
  }

  static int _getDeptColorHex(String dept) {
    switch (dept) {
      case 'Management':
        return 0xFF0284C7;
      case 'Kitchen':
        return 0xFFD97706;
      case 'Service':
        return 0xFF0891B2;
      case 'Operations':
        return 0xFF7C3AED;
      default:
        return 0xFF14332E;
    }
  }

  /// Save all staff to persistent storage AND sync with Supabase database
  static Future<bool> saveStaffList(List<Map<String, dynamic>> staffList) async {
    bool localSuccess = false;
    bool dbSuccess = false;

    // 1. Always save to SharedPreferences (offline support)
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(staffList);
      localSuccess = await prefs.setString(storageKey, encoded);
      debugPrint('[StaffService] Saved ${staffList.length} staff to SharedPreferences (success: $localSuccess)');
    } catch (e) {
      debugPrint('[StaffService] Local storage save error: $e');
    }

    // 2. Sync to Supabase `staff` table
    try {
      final supabase = Supabase.instance.client;
      for (final s in staffList) {
        final empId = (s['id'] ?? s['employee_id'] ?? '').toString().trim();
        final staffName = (s['name'] ?? '').toString().trim();
        if (empId.isEmpty || staffName.isEmpty) continue;

        String statusStr = 'Active';
        final rawStatus = (s['status'] ?? 'active').toString().toLowerCase();
        if (rawStatus == 'inactive') {
          statusStr = 'Inactive';
        } else if (rawStatus == 'on-leave') {
          statusStr = 'On Leave';
        } else if (rawStatus == 'archived') {
          statusStr = 'Archived';
        }

        final row = {
          'employee_id': empId,
          'name': staffName,
          'title': (s['title'] ?? '').toString().trim(),
          'role': (s['role'] ?? '').toString().trim(),
          'level': s['level'] is int ? s['level'] : int.tryParse(s['level']?.toString() ?? '2') ?? 2,
          'status': statusStr,
          'image': (s['image'] ?? '').toString().trim(),
          'phone': (s['phone'] ?? '').toString().trim(),
          'dept': (s['dept'] ?? '').toString().trim(),
        };

        final coreRow = {
          'employee_id': empId,
          'name': staffName,
          'title': (s['title'] ?? '').toString().trim(),
          'role': (s['role'] ?? '').toString().trim(),
          'level': s['level'] is int ? s['level'] : int.tryParse(s['level']?.toString() ?? '2') ?? 2,
          'status': statusStr,
          'image': (s['image'] ?? '').toString().trim(),
          'phone': (s['phone'] ?? '').toString().trim(),
          'dept': (s['dept'] ?? '').toString().trim(),
        };

        // Try insert/update into `staff` table
        try {
          final existing = await supabase
              .from('staff')
              .select('id')
              .eq('employee_id', empId)
              .maybeSingle();

          if (existing != null && existing['id'] != null) {
            try {
              await supabase.from('staff').update(row).eq('id', existing['id']);
            } catch (colErr) {
              // If DB table does not have extended columns (image, phone, dept), update using core columns
              debugPrint('[StaffService] Updating with core columns fallback: $colErr');
              await supabase.from('staff').update(coreRow).eq('id', existing['id']);
            }
            debugPrint('[StaffService] Updated staff "$staffName" ($empId) in Supabase `staff` table');
          } else {
            try {
              await supabase.from('staff').insert(row);
            } catch (colErr) {
              debugPrint('[StaffService] Inserting with core columns fallback: $colErr');
              await supabase.from('staff').insert(coreRow);
            }
            debugPrint('[StaffService] Inserted new staff "$staffName" ($empId) in Supabase `staff` table');
          }
          dbSuccess = true;
        } catch (tableErr) {
          debugPrint('[StaffService] Single row sync error: $tableErr');
        }
      }
      debugPrint('[StaffService] Synced staff records to Supabase `staff` table (success: $dbSuccess)');
    } catch (e) {
      debugPrint('[StaffService] Supabase `staff` table sync error: $e');
    }

    // 3. Also backup to app_settings
    try {
      final supabase = Supabase.instance.client;
      final encoded = jsonEncode(staffList);
      await supabase.from('app_settings').upsert({
        'setting_key': supabaseSettingKey,
        'setting_value': encoded,
        'setting_type': 'json',
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'setting_key');
      dbSuccess = true;
    } catch (e) {
      debugPrint('[StaffService] Supabase app_settings sync note: $e');
    }

    return localSuccess || dbSuccess;
  }

  /// Archive a staff member in Supabase `staff` table
  static Future<void> archiveStaffMember(String employeeId) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('staff').update({'status': 'Archived'}).eq('employee_id', employeeId);
      debugPrint('[StaffService] Archived staff $employeeId in Supabase `staff` table');
    } catch (e) {
      debugPrint('[StaffService] Archive in Supabase error: $e');
    }
  }

  /// Restore an archived staff member back to Active
  static Future<void> restoreStaffMember(String employeeId) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('staff').update({'status': 'Active'}).eq('employee_id', employeeId);
      debugPrint('[StaffService] Restored staff $employeeId to Active in Supabase `staff` table');
    } catch (e) {
      debugPrint('[StaffService] Restore in Supabase error: $e');
    }
  }

  /// Delete a staff member from Supabase `staff` table
  static Future<void> deleteStaffMember(String employeeId) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('staff').delete().eq('employee_id', employeeId);
      debugPrint('[StaffService] Deleted staff $employeeId from Supabase `staff` table');
    } catch (e) {
      debugPrint('[StaffService] Delete from Supabase error: $e');
    }
  }

  /// Get active cashier names from User Management
  static Future<List<String>> getActiveCashierNames() async {
    final staff = await loadStaffList();
    final cashiers = staff
        .where((s) => (s['status'] ?? 'active') == 'active')
        .where((s) {
          final role = (s['role'] ?? '').toString().toLowerCase();
          final title = (s['title'] ?? '').toString().toLowerCase();
          final dept = (s['dept'] ?? '').toString().toLowerCase();
          return role.contains('cashier') ||
              role.contains('manager') ||
              role.contains('supervisor') ||
              role.contains('admin') ||
              title.contains('cashier') ||
              dept.contains('management') ||
              dept.contains('operations');
        })
        .map((s) => s['name'].toString())
        .toList();

    if (cashiers.isEmpty) {
      return staff
          .where((s) => (s['status'] ?? 'active') == 'active')
          .map((s) => s['name'].toString())
          .toList();
    }
    return cashiers;
  }

  /// Get active server names from User Management
  static Future<List<String>> getActiveServerNames() async {
    final staff = await loadStaffList();
    final servers = staff
        .where((s) => (s['status'] ?? 'active') == 'active')
        .where((s) {
          final role = (s['role'] ?? '').toString().toLowerCase();
          final title = (s['title'] ?? '').toString().toLowerCase();
          final dept = (s['dept'] ?? '').toString().toLowerCase();
          return role.contains('server') ||
              role.contains('waitstaff') ||
              role.contains('dining') ||
              title.contains('server') ||
              title.contains('waitstaff') ||
              dept.contains('service');
        })
        .map((s) => s['name'].toString())
        .toList();

    if (servers.isEmpty) {
      return staff
          .where((s) => (s['status'] ?? 'active') == 'active')
          .map((s) => s['name'].toString())
          .toList();
    }
    return servers;
  }

  /// Maps a staff position/role title into a system login role recognized by StaffLoginPage.
  ///
  /// SYSTEM ROLE → PORTAL MAPPING (single source of truth):
  ///   'admin'          → /admin/dashboard      (Admin Portal - full access)
  ///   'chef'           → /chef/dashboard       (Kitchen Portal)
  ///   'cashier'        → /staff/dashboard      (Staff POS Portal)
  ///   'waitstaff'      → /staff/dashboard      (Staff POS Portal)
  ///   'staff'          → /staff/dashboard      (Staff POS Portal)
  ///   'inventory staff'→ /inventory/dashboard  (Inventory Portal)
  ///   'developer'      → /developer/dashboard  (Developer Console - bypass all)
  ///
  /// ⚠️  If you add a new system role here, also update:
  ///     1. staff_login_page.dart  → _navigateAfterLogin() redirect logic
  ///     2. main.dart              → AuthGuard allowedRoles for that portal's routes
  static String mapStaffRoleToSystemRole(String roleTitle) {
    final r = roleTitle.toLowerCase().trim();
    // Only the literal 'Admin' staff role title gets full admin portal access.
    // Manager / Supervisor / Owner are directory-level titles → staff portal.
    if (r == 'admin') {
      return 'admin';
    } else if (r.contains('chef') || r.contains('cook') || r.contains('cutter') || r.contains('prep')) {
      return 'chef';
    } else if (r.contains('cashier')) {
      return 'cashier';
    } else if (r.contains('inventory') || r.contains('warehouse') || r.contains('stock') || r.contains('pagsanjan')) {
      return 'inventory staff';
    } else if (r.contains('server') || r.contains('wait') || r.contains('dine')) {
      return 'waitstaff';
    }
    // manager, supervisor, owner, dishwasher, cleaner, custom roles → staff portal
    return 'staff';
  }

  /// Provision a Supabase Auth user and `users` table entry using the service role client.
  /// This runs completely in isolation and DOES NOT disrupt the active admin session!
  static Future<Map<String, dynamic>> createStaffAuthAccount({
    required String email,
    required String password,
    required String fullName,
    required String role,
    required String phone,
    required String employeeId,
  }) async {
    try {
      // Use an isolated client with no session persistence so it does NOT
      // trigger auth state change events on the main singleton client.
      final adminClient = SupabaseClient(
        SupabaseOptions.supabaseUrl,
        SupabaseOptions.supabaseServiceRoleKey,
        authOptions: const AuthClientOptions(
          autoRefreshToken: false,
        ),
      );

      final trimmedEmail = email.trim().toLowerCase();
      final nameParts = fullName.trim().split(' ');
      final firstName = nameParts.first;
      final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
      final systemRole = mapStaffRoleToSystemRole(role);

      debugPrint('[StaffService] Provisioning auth user for $trimmedEmail with role: $systemRole');

      // 1. Create in Supabase Auth via Admin API
      final userResponse = await adminClient.auth.admin.createUser(
        AdminUserAttributes(
          email: trimmedEmail,
          password: password,
          emailConfirm: true,
          userMetadata: {
            'firstname': firstName,
            'lastname': lastName,
            'role': systemRole,
            'phone': phone,
            'employee_id': employeeId,
          },
        ),
      );

      final authUser = userResponse.user;
      final userId = authUser?.id;

      // 2. Insert or update in `public.users` table
      if (userId != null) {
        await adminClient.from('users').upsert({
          'id': userId,
          'email': trimmedEmail,
          'firstname': firstName,
          'lastname': lastName,
          'phone': phone,
          'role': systemRole,
          'is_approved': true,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'email');
        debugPrint('[StaffService] Created user in `users` table for $trimmedEmail');
      }

      adminClient.dispose();

      return {
        'success': true,
        'userId': userId,
        'systemRole': systemRole,
      };
    } catch (e) {
      debugPrint('[StaffService] createStaffAuthAccount error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Deactivate a staff account in `users` table when archived
  static Future<void> deactivateStaffAuthAccount(String email) async {
    if (email.trim().isEmpty) return;
    SupabaseClient? adminClient;
    try {
      adminClient = SupabaseClient(
        SupabaseOptions.supabaseUrl,
        SupabaseOptions.supabaseServiceRoleKey,
        authOptions: const AuthClientOptions(
          autoRefreshToken: false,
        ),
      );
      await adminClient.from('users').update({
        'is_approved': false,
        'role': 'inactive_staff',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).ilike('email', email.trim());
      debugPrint('[StaffService] Deactivated staff auth record for $email');
    } catch (e) {
      debugPrint('[StaffService] Error deactivating staff auth account: $e');
    } finally {
      adminClient?.dispose();
    }
  }

  /// Reactivate a staff account in `users` table when restored
  static Future<void> reactivateStaffAuthAccount(String email, String role) async {
    if (email.trim().isEmpty) return;
    SupabaseClient? adminClient;
    try {
      adminClient = SupabaseClient(
        SupabaseOptions.supabaseUrl,
        SupabaseOptions.supabaseServiceRoleKey,
        authOptions: const AuthClientOptions(
          autoRefreshToken: false,
        ),
      );
      final systemRole = mapStaffRoleToSystemRole(role);
      await adminClient.from('users').update({
        'is_approved': true,
        'role': systemRole,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).ilike('email', email.trim());
      debugPrint('[StaffService] Reactivated staff auth record for $email as $systemRole');
    } catch (e) {
      debugPrint('[StaffService] Error reactivating staff auth account: $e');
    } finally {
      adminClient?.dispose();
    }
  }

  /// Synchronize staff profile changes (name, phone, role, email) to `public.users` table and Supabase Auth.
  static Future<bool> syncStaffUserAccount({
    required String currentEmail,
    String? previousEmail,
    required String fullName,
    required String phone,
    required String role,
    required String employeeId,
  }) async {
    final cleanCurrentEmail = currentEmail.trim().toLowerCase();
    final cleanPreviousEmail = (previousEmail ?? '').trim().toLowerCase();
    final targetEmail = cleanCurrentEmail.isNotEmpty ? cleanCurrentEmail : cleanPreviousEmail;
    if (targetEmail.isEmpty) return false;

    SupabaseClient? adminClient;
    try {
      adminClient = SupabaseClient(
        SupabaseOptions.supabaseUrl,
        SupabaseOptions.supabaseServiceRoleKey,
        authOptions: const AuthClientOptions(
          autoRefreshToken: false,
        ),
      );

      final nameParts = fullName.trim().split(' ');
      final firstName = nameParts.first;
      final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
      final systemRole = mapStaffRoleToSystemRole(role);

      // 1. Check if user exists in `public.users` by current or previous email
      Map<String, dynamic>? existingUser;
      if (cleanPreviousEmail.isNotEmpty) {
        existingUser = await adminClient
            .from('users')
            .select('id, email')
            .ilike('email', cleanPreviousEmail)
            .maybeSingle();
      }
      if (existingUser == null && cleanCurrentEmail.isNotEmpty) {
        existingUser = await adminClient
            .from('users')
            .select('id, email')
            .ilike('email', cleanCurrentEmail)
            .maybeSingle();
      }

      if (existingUser != null) {
        final userId = existingUser['id']?.toString();
        final Map<String, dynamic> updateFields = {
          'firstname': firstName,
          'lastname': lastName,
          'phone': phone,
          'role': systemRole,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        };

        if (cleanCurrentEmail.isNotEmpty && cleanCurrentEmail != existingUser['email']?.toString().toLowerCase()) {
          updateFields['email'] = cleanCurrentEmail;
        }

        if (userId != null && userId.isNotEmpty) {
          await adminClient
              .from('users')
              .update(updateFields)
              .eq('id', userId);

          // Also update Auth user metadata & email if user ID is present
          try {
            final adminUserAttrs = AdminUserAttributes(
              email: cleanCurrentEmail.isNotEmpty ? cleanCurrentEmail : null,
              userMetadata: {
                'firstname': firstName,
                'lastname': lastName,
                'phone': phone,
                'role': systemRole,
                'employee_id': employeeId,
              },
            );
            await adminClient.auth.admin.updateUserById(userId, attributes: adminUserAttrs);
          } catch (authErr) {
            debugPrint('[StaffService] Note updating Auth admin metadata: $authErr');
          }
        }

        debugPrint('[StaffService] Successfully synced staff user record for $targetEmail ($systemRole)');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[StaffService] Error syncing staff user account: $e');
      return false;
    } finally {
      adminClient?.dispose();
    }
  }

  /// Reset a staff member's password in Supabase Auth via Admin Client
  static Future<Map<String, dynamic>> resetStaffPassword({
    required String email,
    required String newPassword,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) {
      return {'success': false, 'error': 'Staff email is required for password reset.'};
    }

    SupabaseClient? adminClient;
    try {
      adminClient = SupabaseClient(
        SupabaseOptions.supabaseUrl,
        SupabaseOptions.supabaseServiceRoleKey,
        authOptions: const AuthClientOptions(
          autoRefreshToken: false,
        ),
      );

      // Find user ID from `users` table
      final userRow = await adminClient
          .from('users')
          .select('id')
          .ilike('email', cleanEmail)
          .maybeSingle();

      if (userRow == null || userRow['id'] == null) {
        return {
          'success': false,
          'error': 'No authentication account found for $cleanEmail. You can provision one by editing the staff profile.',
        };
      }

      final userId = userRow['id'].toString();
      await adminClient.auth.admin.updateUserById(
        userId,
        attributes: AdminUserAttributes(password: newPassword),
      );

      debugPrint('[StaffService] Reset password successfully for staff $cleanEmail');
      return {'success': true};
    } catch (e) {
      debugPrint('[StaffService] resetStaffPassword error: $e');
      return {'success': false, 'error': e.toString()};
    } finally {
      adminClient?.dispose();
    }
  }

  static const String supabaseCustomDeptsKey = 'staff_custom_departments';
  static const String supabaseCustomRolesKey = 'staff_custom_roles';
  static const String prefsCustomDeptsKey = 'yang_custom_departments';
  static const String prefsCustomRolesKey = 'yang_custom_roles';

  /// Load custom departments from Supabase app_settings with local storage fallback
  static Future<List<String>> loadCustomDepartments() async {
    final List<String> result = [];
    // 1. Try loading from Supabase app_settings
    try {
      final supabase = Supabase.instance.client;
      final res = await supabase
          .from('app_settings')
          .select('setting_value')
          .eq('setting_key', supabaseCustomDeptsKey)
          .maybeSingle();

      if (res != null && res['setting_value'] != null) {
        final raw = res['setting_value'].toString();
        if (raw.isNotEmpty) {
          final List<dynamic> decoded = jsonDecode(raw);
          for (final item in decoded) {
            final str = item.toString().trim();
            if (str.isNotEmpty && !result.contains(str)) {
              result.add(str);
            }
          }
          debugPrint('[StaffService] Loaded ${result.length} custom departments from Supabase app_settings');
        }
      }
    } catch (e) {
      debugPrint('[StaffService] Supabase loadCustomDepartments note: $e');
    }

    // 2. Fallback / merge with local SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final local = prefs.getStringList(prefsCustomDeptsKey) ?? [];
      for (final d in local) {
        final str = d.trim();
        if (str.isNotEmpty && !result.contains(str)) {
          result.add(str);
        }
      }
      if (result.isNotEmpty) {
        await prefs.setStringList(prefsCustomDeptsKey, result);
      }
    } catch (e) {
      debugPrint('[StaffService] Local loadCustomDepartments error: $e');
    }

    return result;
  }

  /// Save custom departments to local SharedPreferences and Supabase app_settings
  static Future<void> saveCustomDepartments(List<String> customDepts) async {
    final cleanList = customDepts.map((d) => d.trim()).where((d) => d.isNotEmpty).toSet().toList();
    // 1. Save locally
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(prefsCustomDeptsKey, cleanList);
    } catch (e) {
      debugPrint('[StaffService] Local saveCustomDepartments error: $e');
    }

    // 2. Sync to Supabase app_settings
    try {
      final supabase = Supabase.instance.client;
      final encoded = jsonEncode(cleanList);
      await supabase.from('app_settings').upsert({
        'setting_key': supabaseCustomDeptsKey,
        'setting_value': encoded,
        'setting_type': 'json',
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'setting_key');
      debugPrint('[StaffService] Synced ${cleanList.length} custom departments to Supabase app_settings');
    } catch (e) {
      debugPrint('[StaffService] Supabase saveCustomDepartments error: $e');
    }
  }

  /// Load custom roles from Supabase app_settings with local storage fallback
  static Future<List<String>> loadCustomRoles() async {
    final List<String> result = [];
    // 1. Try loading from Supabase app_settings
    try {
      final supabase = Supabase.instance.client;
      final res = await supabase
          .from('app_settings')
          .select('setting_value')
          .eq('setting_key', supabaseCustomRolesKey)
          .maybeSingle();

      if (res != null && res['setting_value'] != null) {
        final raw = res['setting_value'].toString();
        if (raw.isNotEmpty) {
          final List<dynamic> decoded = jsonDecode(raw);
          for (final item in decoded) {
            final str = item.toString().trim();
            if (str.isNotEmpty && !result.contains(str)) {
              result.add(str);
            }
          }
          debugPrint('[StaffService] Loaded ${result.length} custom roles from Supabase app_settings');
        }
      }
    } catch (e) {
      debugPrint('[StaffService] Supabase loadCustomRoles note: $e');
    }

    // 2. Fallback / merge with local SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final local = prefs.getStringList(prefsCustomRolesKey) ?? [];
      for (final r in local) {
        final str = r.trim();
        if (str.isNotEmpty && !result.contains(str)) {
          result.add(str);
        }
      }
      if (result.isNotEmpty) {
        await prefs.setStringList(prefsCustomRolesKey, result);
      }
    } catch (e) {
      debugPrint('[StaffService] Local loadCustomRoles error: $e');
    }

    return result;
  }

  /// Save custom roles to local SharedPreferences and Supabase app_settings
  static Future<void> saveCustomRoles(List<String> customRoles) async {
    final cleanList = customRoles.map((r) => r.trim()).where((r) => r.isNotEmpty).toSet().toList();
    // 1. Save locally
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(prefsCustomRolesKey, cleanList);
    } catch (e) {
      debugPrint('[StaffService] Local saveCustomRoles error: $e');
    }

    // 2. Sync to Supabase app_settings
    try {
      final supabase = Supabase.instance.client;
      final encoded = jsonEncode(cleanList);
      await supabase.from('app_settings').upsert({
        'setting_key': supabaseCustomRolesKey,
        'setting_value': encoded,
        'setting_type': 'json',
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'setting_key');
      debugPrint('[StaffService] Synced ${cleanList.length} custom roles to Supabase app_settings');
    } catch (e) {
      debugPrint('[StaffService] Supabase saveCustomRoles error: $e');
    }
  }
}
