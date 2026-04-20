import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TableService {
  static final TableService _instance = TableService._internal();
  final SupabaseClient _supabase = Supabase.instance.client;

  TableService._internal();

  factory TableService() {
    return _instance;
  }

  /// Fetch all tables from the database
  Future<List<Map<String, dynamic>>> getTables() async {
    try {
      final response = await _supabase
          .from('restaurant_tables')
          .select()
          .order('table_number', ascending: true);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching tables: $e');
      return [];
    }
  }

  /// Get available tables for a specific date and time slot
  /// Logic: Find all reservations for that date, check for overlaps in time, 
  /// and exclude tables that are already assigned or held.
  Future<List<Map<String, dynamic>>> getAvailableTables({
    required String date,
    required String startTime,
    required int durationHours,
    required int guests,
  }) async {
    try {
      // 1. Fetch all tables that can accommodate the guest count
      final tablesResponse = await _supabase
          .from('restaurant_tables')
          .select()
          .gte('capacity', guests);
      
      final List<Map<String, dynamic>> suitableTables = List<Map<String, dynamic>>.from(tablesResponse);

      // 2. Fetch reservations for that specific date
      final reservationsResponse = await _supabase
          .from('reservations')
          .select('table_id, start_time, duration_hours')
          .eq('event_date', date)
          .not('table_id', 'is', null)
          .filter('status', 'in', '("pending", "confirmed", "payment_pending")');

      final List<Map<String, dynamic>> dayReservations = List<Map<String, dynamic>>.from(reservationsResponse);

      // 3. Fetch active holds
      final holdsResponse = await _supabase
          .from('table_holds')
          .select('table_id')
          .gt('expires_at', DateTime.now().toUtc().toIso8601String());
      
      final List<String> heldTableIds = List<Map<String, dynamic>>.from(holdsResponse)
          .map((h) => h['table_id']?.toString() ?? '')
          .toList();

      // 4. Filter for availability (Time Overlap Check)
      final availableTables = suitableTables.where((table) {
        final tableId = table['id'];
        
        // Check if table is currently held
        if (heldTableIds.contains(tableId)) return false;

        // Check for time overlaps with existing reservations
        for (final res in dayReservations) {
          if (res['table_id'] == tableId) {
            if (_isTimeOverlapping(startTime, durationHours, res['start_time'], res['duration_hours'])) {
              return false; // Time conflict
            }
          }
        }
        
        return true;
      }).toList();

      return availableTables;
    } catch (e) {
      debugPrint('Error getting available tables: $e');
      return [];
    }
  }

  /// Helper to check if two time slots overlap
  bool _isTimeOverlapping(String start1, int dur1, String start2, int dur2) {
    try {
      final t1 = _parseTime(start1);
      final e1 = t1.add(Duration(hours: dur1));
      
      final t2 = _parseTime(start2);
      final e2 = t2.add(Duration(hours: dur2));

      // Standard overlap check: (StartA < EndB) and (EndA > StartB)
      return t1.isBefore(e2) && e1.isAfter(t2);
    } catch (e) {
      return true; // Default to conflict on parse error for safety
    }
  }

  DateTime _parseTime(String timeStr) {
    // Assume timeStr is in format "HH:mm"
    final parts = timeStr.split(':');
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
  }

  /// Create a temporary hold on a table
  Future<bool> holdTable(String tableId, String customerEmail) async {
    try {
      final expiresAt = DateTime.now().toUtc().add(const Duration(minutes: 5));
      
      await _supabase.from('table_holds').insert({
        'table_id': tableId,
        'customer_email': customerEmail,
        'expires_at': expiresAt.toIso8601String(),
      });
      
      return true;
    } catch (e) {
      debugPrint('Error holding table: $e');
      return false;
    }
  }

  /// Update table location or capacity (Admin)
  Future<bool> updateTableInfo(String tableId, Map<String, dynamic> updates) async {
    try {
      await _supabase
          .from('restaurant_tables')
          .update(updates)
          .eq('id', tableId);
      return true;
    } catch (e) {
      debugPrint('Error updating table: $e');
      return false;
    }
  }
}
