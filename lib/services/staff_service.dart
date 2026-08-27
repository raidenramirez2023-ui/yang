import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StaffService {
  static const String storageKey = 'yang_chow_staff_directory_v2';
  static const String supabaseSettingKey = 'staff_directory_list';

  // Realistic portrait photos of restaurant staff
  static final List<Map<String, dynamic>> defaultStaff = [
    {
      'title': 'Restaurant Manager',
      'name': 'Tony Stark',
      'full_name': 'Tony Stark',
      'role': 'Manager',
      'dept': 'Management',
      'level': 4,  // L4 = Executive (top)
      'colorHex': 0xFF14332E,
      'image': 'https://images.unsplash.com/photo-1560250097-0b93528c311a?w=400&auto=format&fit=crop&q=80',
      'id': 'EMP001',
      'status': 'active',
      'phone': '+63 912 345 6789',
      'date_hired': '2024-01-15T00:00:00.000',
    },
    {
      'title': 'Operations Supervisor',
      'name': 'Steve Rogers',
      'full_name': 'Steve Rogers',
      'role': 'Supervisor',
      'dept': 'Management',
      'level': 3,  // L3 = Senior Manager
      'colorHex': 0xFF0284C7,
      'image': 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=400&auto=format&fit=crop&q=80',
      'id': 'EMP002',
      'status': 'active',
      'phone': '+63 917 234 5678',
      'date_hired': '2024-02-01T00:00:00.000',
    },
    {
      'title': 'Head Chef',
      'name': 'Gordon Ramsay',
      'full_name': 'Gordon Ramsay',
      'role': 'Cook',
      'dept': 'Kitchen',
      'level': 2,  // L2 = Staff
      'colorHex': 0xFFD97706,
      'image': 'https://images.unsplash.com/photo-1577219491135-ce391730fb2c?w=400&auto=format&fit=crop&q=80',
      'id': 'EMP003',
      'status': 'active',
      'phone': '+63 922 111 2222',
      'date_hired': '2024-03-10T00:00:00.000',
    },
    {
      'title': 'Sous Chef',
      'name': 'Jamie Oliver',
      'full_name': 'Jamie Oliver',
      'role': 'Cook',
      'dept': 'Kitchen',
      'level': 2,  // L2 = Staff
      'colorHex': 0xFFD97706,
      'image': 'https://images.unsplash.com/photo-1583394838336-acd977736f90?w=400&auto=format&fit=crop&q=80',
      'id': 'EMP004',
      'status': 'active',
      'phone': '+63 933 456 7890',
      'date_hired': '2024-03-15T00:00:00.000',
    },
    {
      'title': 'Cashier',
      'name': 'Maria Santos',
      'full_name': 'Maria Santos',
      'role': 'Cashier & Food Server',
      'dept': 'Operations',
      'level': 2,  // L2 = Staff
      'colorHex': 0xFF7C3AED,
      'image': 'https://images.unsplash.com/photo-1580489944761-15a19d654956?w=400&auto=format&fit=crop&q=80',
      'id': 'EMP005',
      'status': 'active',
      'phone': '+63 961 890 1234',
      'date_hired': '2024-04-01T00:00:00.000',
    },
    {
      'title': 'Food Server',
      'name': 'Ana Reyes',
      'full_name': 'Ana Reyes',
      'role': 'Cashier & Food Server',
      'dept': 'Service',
      'level': 2,  // L2 = Staff
      'colorHex': 0xFF0891B2,
      'image': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&auto=format&fit=crop&q=80',
      'id': 'EMP006',
      'status': 'active',
      'phone': '+63 972 901 2345',
      'date_hired': '2024-05-20T00:00:00.000',
    },
    {
      'title': 'Waitstaff',
      'name': 'Sanji Vinsmoke',
      'full_name': 'Sanji Vinsmoke',
      'role': 'Dine-in Food Server',
      'dept': 'Service',
      'level': 2,  // L2 = Staff
      'colorHex': 0xFF0891B2,
      'image': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&auto=format&fit=crop&q=80',
      'id': 'EMP007',
      'status': 'active',
      'phone': '+63 983 012 3456',
      'date_hired': '2024-06-10T00:00:00.000',
    },
    {
      'title': 'Waitstaff',
      'name': 'Clark Kent',
      'full_name': 'Clark Kent',
      'role': 'Dine-in Food Server',
      'dept': 'Service',
      'level': 2,  // L2 = Staff
      'colorHex': 0xFF0891B2,
      'image': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&auto=format&fit=crop&q=80',
      'id': 'EMP008',
      'status': 'active',
      'phone': '+63 905 234 5678',
      'date_hired': '2024-06-15T00:00:00.000',
    },
  ];

  /// Load all staff from Supabase DB or persistent storage fallback
  static Future<List<Map<String, dynamic>>> loadStaffList() async {
    // 1. Try loading from Supabase DB `staff` table first
    try {
      final supabase = Supabase.instance.client;
      final List<dynamic> dbRows = await supabase
          .from('staff')
          .select()
          .order('employee_id', ascending: true);

      if (dbRows.isNotEmpty) {
        final list = dbRows.map((row) {
          final role = (row['role'] ?? '').toString();
          final title = (row['title'] ?? '').toString();
          final dept = _inferDepartment(role, title);
          final levelRaw = row['level'];
          final int level = levelRaw is int ? levelRaw : int.tryParse(levelRaw?.toString() ?? '2') ?? 2;
          final status = (row['status'] ?? 'Active').toString().toLowerCase();

          return {
            'id': (row['employee_id'] ?? row['id'] ?? '').toString(),
            'db_uuid': row['id']?.toString(),
            'employee_id': (row['employee_id'] ?? '').toString(),
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
            'image': (row['image'] ?? '').toString(),
            'colorHex': _getDeptColorHex(dept),
            'date_hired': (row['created_at'] ?? '').toString().isNotEmpty 
                ? row['created_at'].toString() 
                : DateTime.now().toIso8601String(),
          };
        }).toList();

        // Cache to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(storageKey, jsonEncode(list));
        debugPrint('[StaffService] Successfully loaded ${list.length} staff records from Supabase "staff" table');
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
        };

        // Try insert/update into `staff` table
        try {
          final existing = await supabase
              .from('staff')
              .select('id')
              .eq('employee_id', empId)
              .maybeSingle();

          if (existing != null && existing['id'] != null) {
            await supabase.from('staff').update(row).eq('id', existing['id']);
            debugPrint('[StaffService] Updated staff "$staffName" ($empId) in Supabase `staff` table');
          } else {
            await supabase.from('staff').insert(row);
            debugPrint('[StaffService] Inserted new staff "$staffName" ($empId) in Supabase `staff` table');
          }
          dbSuccess = true;
        } catch (tableErr) {
          debugPrint('[StaffService] Single row sync note: $tableErr');
          try {
            await supabase.from('staff').upsert(row);
            dbSuccess = true;
          } catch (_) {}
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
}
