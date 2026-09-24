import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_constants.dart';

/// Service to manage application settings fetched from the database
class AppSettingsService {
  static final AppSettingsService _instance = AppSettingsService._internal();
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Cached settings to avoid repeated database calls
  static Map<String, dynamic> _cachedSettings = {};

  AppSettingsService._internal();

  factory AppSettingsService() {
    return _instance;
  }

  /// Initialize and load all app settings from database
  Future<void> initializeSettings() async {
    try {
      final response = await _supabase.from('app_settings').select();

      if (response.isNotEmpty) {
        _cachedSettings = {};
        for (var setting in response) {
          final key = setting['setting_key'] as String;
          final value = setting['setting_value'] as String;
          final type = setting['setting_type'] as String?;

          // Parse value based on type
          _cachedSettings[key] = _parseSettingValue(value, type);
        }
      }
    } catch (e) {
      debugPrint('Error loading app settings: $e');
      // Fall back to defaults
      _loadDefaults();
    }
  }

  /// Parse setting value based on its type
  static dynamic _parseSettingValue(String value, String? type) {
    switch (type) {
      case 'number':
        return int.tryParse(value) ?? double.tryParse(value) ?? value;
      case 'boolean':
        return value.toLowerCase() == 'true' || value == '1';
      case 'json':
        try {
          return jsonDecode(value);
        } catch (e) {
          debugPrint('Error decoding JSON setting: $e');
          return value;
        }
      case 'string':
      default:
        return value;
    }
  }

  /// Load default settings (fallback when database unavailable)
  static void _loadDefaults() {
    _cachedSettings = {
      'min_guest_count': AppConstants.defaultMinGuestCount,
      'max_guest_count': AppConstants.defaultMaxGuestCount,
      'operating_hours_start': AppConstants.defaultOperatingHoursStart,
      'operating_hours_end': AppConstants.defaultOperatingHoursEnd,
      'base_durations': AppConstants.defaultBaseDurations,
      'extra_time_options': AppConstants.defaultExtraTimeOptions,
      'min_reservation_days_ahead': AppConstants.defaultMinReservationDaysAhead,
      'max_reservation_days_ahead': AppConstants.defaultMaxReservationDaysAhead,
      'refund_policy_days': AppConstants.defaultRefundPolicyDays,
      'refund_percentage_within_window':
          AppConstants.defaultRefundPercentageWithinWindow,
      'enable_special_requests': AppConstants.defaultEnableSpecialRequests,
      'enable_email_notifications':
          AppConstants.defaultEnableEmailNotifications,
    };
  }

  /// Get a setting value by key with type-safe return
  T? getSetting<T>(String key, {T? defaultValue}) {
    try {
      final value = _cachedSettings[key];
      if (value == null) {
        return defaultValue;
      }
      return value as T?;
    } catch (e) {
      debugPrint('Error getting setting $key: $e');
      return defaultValue;
    }
  }

  /// Get all cached settings
  Map<String, dynamic> getAllSettings() => Map.from(_cachedSettings);

  /// Update a setting in the database
  Future<void> updateSetting(String key, dynamic value) async {
    try {
      await _supabase
          .from('app_settings')
          .update({'setting_value': value.toString()})
          .eq('setting_key', key);

      // Update cache
      _cachedSettings[key] = value;
    } catch (e) {
      debugPrint('Error updating setting $key: $e');
      throw Exception('Failed to update setting: $e');
    }
  }

  /// Refresh settings from database
  Future<void> refreshSettings() async {
    await initializeSettings();
  }

  // ==================== Convenience Getters ====================

  int getMinGuestCount() {
    final val = getSetting<int>('min_guest_count') ?? AppConstants.defaultMinGuestCount;
    return val < 30 ? 30 : val;
  }

  int getMaxGuestCount() =>
      getSetting<int>('max_guest_count') ?? AppConstants.defaultMaxGuestCount;

  int getOperatingHoursStart() =>
      getSetting<int>('operating_hours_start') ??
      AppConstants.defaultOperatingHoursStart;

  int getOperatingHoursEnd() =>
      getSetting<int>('operating_hours_end') ??
      AppConstants.defaultOperatingHoursEnd;

  List<String> getBaseDurations() {
    final setting = getSetting<dynamic>('base_durations');
    if (setting is List) {
      return List<String>.from(setting);
    }
    return AppConstants.defaultBaseDurations;
  }

  List<String> getExtraTimeOptions() {
    final setting = getSetting<dynamic>('extra_time_options');
    if (setting is List) {
      return List<String>.from(setting);
    }
    return AppConstants.defaultExtraTimeOptions;
  }

  int getMinReservationDaysAhead() =>
      getSetting<int>('min_reservation_days_ahead') ??
      AppConstants.defaultMinReservationDaysAhead;

  int getMaxReservationDaysAhead() =>
      getSetting<int>('max_reservation_days_ahead') ??
      AppConstants.defaultMaxReservationDaysAhead;

  int getRefundPolicyDays() =>
      getSetting<int>('refund_policy_days') ??
      AppConstants.defaultRefundPolicyDays;

  int getRefundPercentageWithinWindow() =>
      getSetting<int>('refund_percentage_within_window') ??
      AppConstants.defaultRefundPercentageWithinWindow;

  bool isSpecialRequestsEnabled() =>
      getSetting<bool>('enable_special_requests') ??
      AppConstants.defaultEnableSpecialRequests;

  bool isEmailNotificationsEnabled() =>
      getSetting<bool>('enable_email_notifications') ??
      AppConstants.defaultEnableEmailNotifications;

  String? getSmtpFromEmail() => getSetting<String>('smtp_from_email');

  String getOcrApiKey() => getSetting<String>('ocr_api_key') ?? 'K82798202388957';

  String getInventoryImportPasscode() =>
      getSetting<String>('inventory_import_passcode', defaultValue: 'PAGSANJAN2026') ?? 'PAGSANJAN2026';

  bool isStaffDelegationEnabled() =>
      getSetting<bool>('staff_delegation_mode', defaultValue: false) ?? false;

  Future<void> setStaffDelegationEnabled(bool enabled) async {
    try {
      await _supabase.from('app_settings').upsert({
        'setting_key': 'staff_delegation_mode',
        'setting_value': enabled ? 'true' : 'false',
        'setting_type': 'boolean',
        'description': 'Enable staff POS to process and approve reservations, payment slips, and balances during Admin rest days',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'setting_key');
      _cachedSettings['staff_delegation_mode'] = enabled;
    } catch (e) {
      debugPrint('Error updating staff delegation mode: $e');
      _cachedSettings['staff_delegation_mode'] = enabled;
    }
  }

  Future<void> updateInventoryImportPasscode(String newPasscode) async {
    try {
      final existing = await _supabase
          .from('app_settings')
          .select()
          .eq('setting_key', 'inventory_import_passcode')
          .maybeSingle();

      if (existing == null) {
        await _supabase.from('app_settings').insert({
          'setting_key': 'inventory_import_passcode',
          'setting_value': newPasscode,
          'setting_type': 'string',
          'description': 'Authorization passcode for Admin inventory import override',
        });
      } else {
        await updateSetting('inventory_import_passcode', newPasscode);
      }
      _cachedSettings['inventory_import_passcode'] = newPasscode;
    } catch (e) {
      debugPrint('Error updating inventory import passcode: $e');
      _cachedSettings['inventory_import_passcode'] = newPasscode;
    }
  }

  // ==================== Maintenance Mode Settings ====================

  bool isMaintenanceModeEnabled() =>
      getSetting<bool>('maintenance_mode_enabled', defaultValue: false) ?? false;

  /// Always fetches the maintenance mode status LIVE from the database.
  /// This bypasses the in-memory cache so that changes made by a Developer
  /// on another device/browser are immediately reflected everywhere.
  /// Also updates the local cache as a side-effect.
  static Future<bool> checkMaintenanceModeFromDB() async {
    try {
      final result = await _supabase
          .from('app_settings')
          .select('setting_value')
          .eq('setting_key', 'maintenance_mode_enabled')
          .maybeSingle();
      final isActive =
          result != null && result['setting_value']?.toString().toLowerCase() == 'true';
      // Keep local cache in sync
      _cachedSettings['maintenance_mode_enabled'] = isActive;
      return isActive;
    } catch (e) {
      debugPrint('⚠️ checkMaintenanceModeFromDB: DB query failed, using cache: $e');
      // Fall back to stale cache only if DB is unreachable
      return _cachedSettings['maintenance_mode_enabled'] == true;
    }
  }

  String getMaintenanceReason() =>
      getSetting<String>('maintenance_reason', defaultValue: 'Scheduled System Maintenance') ??
      'Scheduled System Maintenance';

  String getMaintenanceMessage() =>
      getSetting<String>('maintenance_message',
          defaultValue: 'Yang Chow Pagsanjan is temporarily undergoing scheduled maintenance. Please check back shortly.') ??
      'Yang Chow Pagsanjan is temporarily undergoing scheduled maintenance. Please check back shortly.';

  String? getMaintenanceStartTime() =>
      getSetting<String>('maintenance_start_time');

  String? getMaintenanceEndTime() =>
      getSetting<String>('maintenance_end_time');

  String? getMaintenanceUpdatedBy() =>
      getSetting<String>('maintenance_updated_by');

  Future<void> setMaintenanceMode({
    required bool enabled,
    String? reason,
    String? message,
    DateTime? startTime,
    DateTime? endTime,
    String? updatedBy,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final startIso = startTime?.toUtc().toIso8601String() ?? '';
    final endIso = endTime?.toUtc().toIso8601String() ?? '';
    final cleanReason = reason ?? getMaintenanceReason();
    final cleanMessage = message ?? getMaintenanceMessage();

    final updates = [
      {
        'setting_key': 'maintenance_mode_enabled',
        'setting_value': enabled ? 'true' : 'false',
        'setting_type': 'boolean',
        'description': 'Flag indicating whether system technical maintenance mode is active',
        'updated_at': nowIso,
      },
      {
        'setting_key': 'maintenance_reason',
        'setting_value': cleanReason,
        'setting_type': 'string',
        'description': 'Reason for current or upcoming maintenance mode',
        'updated_at': nowIso,
      },
      {
        'setting_key': 'maintenance_message',
        'setting_value': cleanMessage,
        'setting_type': 'string',
        'description': 'User-facing notice message displayed during maintenance',
        'updated_at': nowIso,
      },
      {
        'setting_key': 'maintenance_start_time',
        'setting_value': startIso,
        'setting_type': 'string',
        'description': 'ISO timestamp of maintenance start window',
        'updated_at': nowIso,
      },
      {
        'setting_key': 'maintenance_end_time',
        'setting_value': endIso,
        'setting_type': 'string',
        'description': 'ISO timestamp of estimated maintenance end window',
        'updated_at': nowIso,
      },
    ];

    if (updatedBy != null && updatedBy.isNotEmpty) {
      updates.add({
        'setting_key': 'maintenance_updated_by',
        'setting_value': updatedBy,
        'setting_type': 'string',
        'description': 'Email of developer/IT admin who modified maintenance mode',
        'updated_at': nowIso,
      });
    }

    try {
      for (final item in updates) {
        await _supabase.from('app_settings').upsert(item, onConflict: 'setting_key');
        _cachedSettings[item['setting_key'] as String] = item['setting_key'] == 'maintenance_mode_enabled'
            ? enabled
            : item['setting_value'];
      }
    } catch (e) {
      debugPrint('Error saving maintenance mode settings: $e');
      // Update cache even if offline/db issue
      _cachedSettings['maintenance_mode_enabled'] = enabled;
      _cachedSettings['maintenance_reason'] = cleanReason;
      _cachedSettings['maintenance_message'] = cleanMessage;
      _cachedSettings['maintenance_start_time'] = startIso;
      _cachedSettings['maintenance_end_time'] = endIso;
      if (updatedBy != null) {
        _cachedSettings['maintenance_updated_by'] = updatedBy;
      }
    }
  }

  /// Purges test payment and order records created during maintenance mode.
  /// This ensures developer tests do not corrupt sales analytics or financial reports.
  Future<Map<String, int>> purgeMaintenanceTestData({
    DateTime? windowStartTime,
    String? operatorEmail,
  }) async {
    int deletedOrders = 0;
    int deletedReservations = 0;
    int deletedAdvanceOrders = 0;

    DateTime? effectiveStartTime = windowStartTime;
    if (effectiveStartTime == null) {
      final settingStart = getMaintenanceStartTime();
      if (settingStart != null && settingStart.trim().isNotEmpty) {
        effectiveStartTime = DateTime.tryParse(settingStart.trim());
      }
    }
    // Default to last 24 hours to capture any test orders placed recently
    effectiveStartTime ??= DateTime.now().subtract(const Duration(hours: 24));

    try {
      // 1. Find and delete test POS orders
      try {
        final ordersResponse = await _supabase
            .from('orders')
            .select('id, customer_name, staff_email, created_at');

        final List<String> orderIds = [];
        for (final o in (ordersResponse as List<dynamic>)) {
          final id = o['id']?.toString();
          if (id == null) continue;

          final cName = (o['customer_name'] ?? '').toString().toLowerCase();
          final sEmail = (o['staff_email'] ?? '').toString().toLowerCase();
          final cDateStr = (o['created_at'] ?? '').toString();
          final cDate = DateTime.tryParse(cDateStr);

          bool shouldDelete = false;
          if (cDate != null && cDate.isAfter(effectiveStartTime)) {
            shouldDelete = true;
          }
          if (operatorEmail != null && sEmail == operatorEmail.toLowerCase()) {
            shouldDelete = true;
          }
          if (sEmail.contains('yangchowit') ||
              sEmail.contains('test') ||
              sEmail.contains('dev') ||
              cName.contains('test') ||
              cName.contains('dev')) {
            shouldDelete = true;
          }

          if (shouldDelete) {
            orderIds.add(id);
          }
        }

        if (orderIds.isNotEmpty) {
          try {
            await _supabase.from('refunds').delete().inFilter('source_id', orderIds);
          } catch (_) {}
          try {
            await _supabase.from('order_items').delete().inFilter('order_id', orderIds);
          } catch (_) {}
          await _supabase.from('orders').delete().inFilter('id', orderIds);
          deletedOrders = orderIds.length;
        }
      } catch (e) {
        debugPrint('Error cleaning orders: $e');
      }

      // 2. Find and delete test reservations / events
      try {
        final resResponse = await _supabase
            .from('reservations')
            .select('id, customer_name, customer_email, created_at, event_date');

        final List<String> resIds = [];
        for (final r in (resResponse as List<dynamic>)) {
          final id = r['id']?.toString();
          if (id == null) continue;

          final cName = (r['customer_name'] ?? '').toString().toLowerCase();
          final cEmail = (r['customer_email'] ?? r['email'] ?? '').toString().toLowerCase();
          final cDateStr = (r['created_at'] ?? r['event_date'] ?? '').toString();
          final cDate = DateTime.tryParse(cDateStr);

          bool shouldDelete = false;
          if (cDate != null && cDate.isAfter(effectiveStartTime)) {
            shouldDelete = true;
          }
          if (operatorEmail != null && cEmail == operatorEmail.toLowerCase()) {
            shouldDelete = true;
          }
          if (cEmail.contains('yangchowit') ||
              cEmail.contains('test') ||
              cEmail.contains('dev') ||
              cName.contains('test') ||
              cName.contains('dev')) {
            shouldDelete = true;
          }

          if (shouldDelete) {
            resIds.add(id);
          }
        }

        if (resIds.isNotEmpty) {
          try {
            await _supabase.from('refunds').delete().inFilter('source_id', resIds);
          } catch (_) {}
          await _supabase.from('reservations').delete().inFilter('id', resIds);
          deletedReservations = resIds.length;
        }
      } catch (e) {
        debugPrint('Error cleaning reservations: $e');
      }

      // 3. Find and delete test advance orders
      try {
        final advResponse = await _supabase
            .from('advance_orders')
            .select('id, customer_name, customer_email, created_at, order_date');

        final List<String> advIds = [];
        for (final a in (advResponse as List<dynamic>)) {
          final id = a['id']?.toString();
          if (id == null) continue;

          final cName = (a['customer_name'] ?? '').toString().toLowerCase();
          final cEmail = (a['customer_email'] ?? a['email'] ?? '').toString().toLowerCase();
          final cDateStr = (a['created_at'] ?? a['order_date'] ?? '').toString();
          final cDate = DateTime.tryParse(cDateStr);

          bool shouldDelete = false;
          if (cDate != null && cDate.isAfter(effectiveStartTime)) {
            shouldDelete = true;
          }
          if (operatorEmail != null && cEmail == operatorEmail.toLowerCase()) {
            shouldDelete = true;
          }
          if (cEmail.contains('yangchowit') ||
              cEmail.contains('test') ||
              cEmail.contains('dev') ||
              cName.contains('test') ||
              cName.contains('dev')) {
            shouldDelete = true;
          }

          if (shouldDelete) {
            advIds.add(id);
          }
        }

        if (advIds.isNotEmpty) {
          try {
            await _supabase.from('refunds').delete().inFilter('source_id', advIds);
          } catch (_) {}
          await _supabase.from('advance_orders').delete().inFilter('id', advIds);
          deletedAdvanceOrders = advIds.length;
        }
      } catch (e) {
        debugPrint('Error cleaning advance orders: $e');
      }

      // 4. Find and delete test audit logs and framework crash logs created during this window
      try {
        await _supabase
            .from('audit_logs')
            .delete()
            .or('user_email.ilike.%yangchowit%,user_role.eq.DEVELOPER,action.eq.ERROR,action.eq.CRITICAL,module.ilike.%library%')
            .gte('created_at', effectiveStartTime.toUtc().toIso8601String());
      } catch (e) {
        debugPrint('Error cleaning test audit logs: $e');
      }

      // 5. Log audit activity
      try {
        await _supabase.from('audit_logs').insert({
          'action': 'PURGE_MAINTENANCE_TEST_DATA',
          'module': 'Maintenance',
          'description':
              'Purged $deletedOrders test orders, $deletedReservations test events/reservations, and $deletedAdvanceOrders test advance orders.',
          'user_email': operatorEmail ?? 'developer',
          'user_role': 'DEVELOPER',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (_) {}
    } catch (e) {
      debugPrint('Error purging maintenance test data: $e');
      rethrow;
    }

    return {
      'orders': deletedOrders,
      'reservations': deletedReservations,
      'advance_orders': deletedAdvanceOrders,
    };
  }
}

