import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StaffService {
  static const String storageKey = 'yang_chow_staff_directory_v2';

  // Realistic portrait photos of restaurant staff
  static final List<Map<String, dynamic>> defaultStaff = [
    {
      'title': 'Restaurant Manager',
      'name': 'Tony Stark',
      'role': 'Supervisor',
      'dept': 'Management',
      'level': 0,
      'colorHex': 0xFF14332E,
      'image': 'https://images.unsplash.com/photo-1560250097-0b93528c311a?w=400&auto=format&fit=crop&q=80',
      'id': 'EMP001',
      'status': 'active',
      'phone': '+63 912 345 6789',
    },
    {
      'title': 'Operations Supervisor',
      'name': 'Steve Rogers',
      'role': 'Supervisor',
      'dept': 'Management',
      'level': 1,
      'colorHex': 0xFF0284C7,
      'image': 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=400&auto=format&fit=crop&q=80',
      'id': 'EMP002',
      'status': 'active',
      'phone': '+63 917 234 5678',
    },
    {
      'title': 'Head Chef',
      'name': 'Gordon Ramsay',
      'role': 'Cook',
      'dept': 'Kitchen',
      'level': 2,
      'colorHex': 0xFFD97706,
      'image': 'https://images.unsplash.com/photo-1577219491135-ce391730fb2c?w=400&auto=format&fit=crop&q=80',
      'id': 'EMP003',
      'status': 'active',
      'phone': '+63 922 111 2222',
    },
    {
      'title': 'Sous Chef',
      'name': 'Jamie Oliver',
      'role': 'Cook',
      'dept': 'Kitchen',
      'level': 2,
      'colorHex': 0xFFD97706,
      'image': 'https://images.unsplash.com/photo-1583394838336-acd977736f90?w=400&auto=format&fit=crop&q=80',
      'id': 'EMP004',
      'status': 'active',
      'phone': '+63 933 456 7890',
    },
    {
      'title': 'Cashier',
      'name': 'Maria Santos',
      'role': 'Cashier & Food Server',
      'dept': 'Operations',
      'level': 2,
      'colorHex': 0xFF7C3AED,
      'image': 'https://images.unsplash.com/photo-1580489944761-15a19d654956?w=400&auto=format&fit=crop&q=80',
      'id': 'EMP005',
      'status': 'active',
      'phone': '+63 961 890 1234',
    },
    {
      'title': 'Food Server',
      'name': 'Ana Reyes',
      'role': 'Cashier & Food Server',
      'dept': 'Service',
      'level': 2,
      'colorHex': 0xFF0891B2,
      'image': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&auto=format&fit=crop&q=80',
      'id': 'EMP006',
      'status': 'active',
      'phone': '+63 972 901 2345',
    },
    {
      'title': 'Waitstaff',
      'name': 'Sanji Vinsmoke',
      'role': 'Dine-in Food Server',
      'dept': 'Service',
      'level': 2,
      'colorHex': 0xFF0891B2,
      'image': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&auto=format&fit=crop&q=80',
      'id': 'EMP007',
      'status': 'active',
      'phone': '+63 983 012 3456',
    },
    {
      'title': 'Waitstaff',
      'name': 'Clark Kent',
      'role': 'Dine-in Food Server',
      'dept': 'Service',
      'level': 2,
      'colorHex': 0xFF0891B2,
      'image': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&auto=format&fit=crop&q=80',
      'id': 'EMP008',
      'status': 'active',
      'phone': '+63 905 234 5678',
    },
  ];

  /// Load all staff from persistent storage
  static Future<List<Map<String, dynamic>>> loadStaffList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(storageKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw);
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      debugPrint('Error loading staff list: $e');
    }
    return List<Map<String, dynamic>>.from(defaultStaff);
  }

  /// Save all staff to persistent storage
  static Future<bool> saveStaffList(List<Map<String, dynamic>> staffList) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(staffList);
      final bool success = await prefs.setString(storageKey, encoded);
      debugPrint('[StaffService] Saved ${staffList.length} staff members to persistent storage (success: $success)');
      return success;
    } catch (e) {
      debugPrint('[StaffService] Error saving staff list: $e');
      return false;
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
