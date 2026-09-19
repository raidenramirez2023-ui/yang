import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'audit_log_service.dart';

/// IT Access Request System
/// 
/// Allows Admin to formally request elevated IT support access from the Developer.
/// Developer receives the request, accepts or declines, and if accepted,
/// gains temporarily elevated access with an auto-expiry timer.
class ItAccessService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static const String _developerEmail = 'yangchowit@gmail.com';
  static const String _tableName = 'it_access_requests';

  // ─── Admin: Send a request ───────────────────────────────────────────────

  /// Admin calls this to send an IT support access request to the developer.
  static Future<Map<String, dynamic>?> sendAccessRequest({
    required String adminEmail,
    required String adminName,
    required String issueDescription,
    required String accessScope,
    required int durationHours,
    bool autoPurgeTestData = true,
  }) async {
    try {
      final response = await _supabase.from(_tableName).insert({
        'requested_by_email': adminEmail,
        'requested_by_name': adminName,
        'developer_email': _developerEmail,
        'issue_description': issueDescription,
        'access_scope': accessScope,
        'duration_hours': durationHours,
        'status': 'pending',
        'requested_at': DateTime.now().toUtc().toIso8601String(),
        'admin_notes': autoPurgeTestData ? 'AUTO_PURGE:true' : 'AUTO_PURGE:false',
      }).select().single();

      await AuditLogService.logActivity(
        action: 'IT_ACCESS_REQUESTED',
        module: 'IT Access Control',
        description: 'Admin requested IT support access: "$issueDescription" (Scope: $accessScope, Duration: ${durationHours}h, Auto-purge: $autoPurgeTestData)',
        customUserEmail: adminEmail,
        customUserRole: 'ADMIN',
        metadata: {
          'access_scope': accessScope,
          'duration_hours': durationHours,
          'developer_email': _developerEmail,
          'auto_purge_test_data': autoPurgeTestData,
        },
      );

      // Send email notification to IT Developer
      try {
        await _supabase.functions.invoke(
          'send-account-alert-email',
          body: {
            'type': 'it_support_request',
            'recipientEmail': _developerEmail,
            'adminName': adminName,
            'adminEmail': adminEmail,
            'issueDescription': issueDescription,
            'accessScope': accessScope,
            'durationHours': durationHours,
          },
        );
        debugPrint('[ItAccessService] Email notification sent to $_developerEmail');
      } catch (emailError) {
        // Non-blocking: don't fail the request if email fails
        debugPrint('[ItAccessService] Email notification failed (non-blocking): $emailError');
      }

      return response;
    } catch (e) {
      debugPrint('[ItAccessService] Error sending access request: $e');
      return null;
    }
  }

  /// Check whether an IT Access Request has auto-purge enabled.
  static bool shouldAutoPurge(Map<String, dynamic> request) {
    final notes = (request['admin_notes'] ?? '').toString();
    if (notes.contains('AUTO_PURGE:false')) return false;
    return true; // Default to true for safety
  }

  /// Mark an active session as completed / resolved.
  static Future<bool> completeSession(
    String requestId, {
    String? notes,
    String? adminEmail,
    String? adminName,
    String? issueDescription,
    String? accessScope,
    int? durationHours,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await _supabase.from(_tableName).update({
        'status': 'resolved',
        'resolved_at': now,
        'developer_notes': notes ?? 'Session completed by developer',
      }).eq('id', requestId);

      await AuditLogService.logActivity(
        action: 'IT_ACCESS_RESOLVED',
        module: 'IT Access Control',
        description: 'IT support access session completed and resolved.',
        customUserEmail: _developerEmail,
        customUserRole: 'DEVELOPER',
        metadata: {'request_id': requestId},
      );

      // Send email notification to Admin that session is completed
      if (adminEmail != null && adminEmail.isNotEmpty) {
        try {
          await _supabase.functions.invoke(
            'send-account-alert-email',
            body: {
              'type': 'it_session_completed',
              'recipientEmail': adminEmail,
              'adminName': adminName ?? 'Administrator',
              'issueDescription': issueDescription ?? '',
              'accessScope': accessScope ?? 'General Access',
              'durationHours': durationHours ?? 2,
              'reason': notes ?? 'Session completed by developer',
            },
          );
          debugPrint('[ItAccessService] Session completed email sent to $adminEmail');
        } catch (emailError) {
          debugPrint('[ItAccessService] Session completed email failed (non-blocking): $emailError');
        }
      }

      return true;
    } catch (e) {
      debugPrint('[ItAccessService] Error completing session: $e');
      return false;
    }
  }

  // ─── Admin: Revoke a request ─────────────────────────────────────────────

  static Future<bool> revokeRequest(String requestId, String adminEmail) async {
    try {
      await _supabase.from(_tableName).update({
        'status': 'revoked',
        'resolved_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', requestId);

      await AuditLogService.logActivity(
        action: 'IT_ACCESS_REVOKED',
        module: 'IT Access Control',
        description: 'Admin revoked IT support access request.',
        customUserEmail: adminEmail,
        customUserRole: 'ADMIN',
      );
      return true;
    } catch (e) {
      debugPrint('[ItAccessService] Error revoking request: $e');
      return false;
    }
  }

  // ─── Admin: Get their sent requests ──────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getAdminRequests(String adminEmail) async {
    try {
      final res = await _supabase
          .from(_tableName)
          .select()
          .eq('requested_by_email', adminEmail)
          .order('requested_at', ascending: false)
          .limit(10);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('[ItAccessService] Error fetching admin requests: $e');
      return [];
    }
  }

  // ─── Developer: Get pending requests ─────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getPendingRequests() async {
    try {
      final res = await _supabase
          .from(_tableName)
          .select()
          .eq('developer_email', _developerEmail)
          .eq('status', 'pending')
          .order('requested_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('[ItAccessService] Error fetching pending requests: $e');
      return [];
    }
  }

  // ─── Developer: Accept a request ─────────────────────────────────────────

  static Future<bool> acceptRequest(String requestId, int durationHours) async {
    try {
      final now = DateTime.now().toUtc();
      final expiresAt = now.add(Duration(hours: durationHours));

      await _supabase.from(_tableName).update({
        'status': 'accepted',
        'accepted_at': now.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
      }).eq('id', requestId);

      await AuditLogService.logActivity(
        action: 'IT_ACCESS_ACCEPTED',
        module: 'IT Access Control',
        description: 'Developer accepted IT support access request. Access granted for ${durationHours}h until ${expiresAt.toLocal()}.',
        customUserEmail: _developerEmail,
        customUserRole: 'DEVELOPER',
        metadata: {
          'request_id': requestId,
          'expires_at': expiresAt.toIso8601String(),
        },
      );
      return true;
    } catch (e) {
      debugPrint('[ItAccessService] Error accepting request: $e');
      return false;
    }
  }

  // ─── Developer: Decline a request ────────────────────────────────────────

  static Future<bool> declineRequest(String requestId, {String? reason}) async {
    try {
      await _supabase.from(_tableName).update({
        'status': 'declined',
        'resolved_at': DateTime.now().toUtc().toIso8601String(),
        'developer_notes': reason ?? '',
      }).eq('id', requestId);

      await AuditLogService.logActivity(
        action: 'IT_ACCESS_DECLINED',
        module: 'IT Access Control',
        description: 'Developer declined IT support access request.',
        customUserEmail: _developerEmail,
        customUserRole: 'DEVELOPER',
      );
      return true;
    } catch (e) {
      debugPrint('[ItAccessService] Error declining request: $e');
      return false;
    }
  }

  // ─── Developer: Check if elevated access is currently active ─────────────

  /// Returns the active accepted request if the developer has elevated access.
  /// Returns null if no active access.
  static Future<Map<String, dynamic>?> getActiveRequest() async {
    try {
      // First, expire any past-due requests in the DB
      await _expireOldRequests();

      final res = await _supabase
          .from(_tableName)
          .select()
          .eq('developer_email', _developerEmail)
          .eq('status', 'accepted')
          .order('accepted_at', ascending: false)
          .limit(1);

      if (res.isNotEmpty) {
        final req = Map<String, dynamic>.from(res.first);
        final expiresAt = DateTime.tryParse(req['expires_at'] ?? '');
        if (expiresAt != null && expiresAt.isAfter(DateTime.now().toUtc())) {
          return req;
        }
      }
      return null;
    } catch (e) {
      debugPrint('[ItAccessService] Error checking active request: $e');
      return null;
    }
  }

  /// Quick synchronous check using cached data — call getActiveRequest() first to populate.
  static Future<bool> hasElevatedAccess() async {
    final req = await getActiveRequest();
    return req != null;
  }

  // ─── Internal: Expire old accepted requests ───────────────────────────────

  static Future<void> _expireOldRequests() async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await _supabase
          .from(_tableName)
          .update({
            'status': 'expired',
            'resolved_at': now,
          })
          .eq('status', 'accepted')
          .lt('expires_at', now);
    } catch (_) {}
  }

  // ─── Utility: Get remaining time string ──────────────────────────────────

  static String getRemainingTimeString(Map<String, dynamic> request) {
    final expiresAt = DateTime.tryParse(request['expires_at'] ?? '');
    if (expiresAt == null) return 'Unknown';
    final remaining = expiresAt.toLocal().difference(DateTime.now());
    if (remaining.isNegative) return 'Expired';
    final h = remaining.inHours;
    final m = remaining.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m remaining';
    return '${m}m remaining';
  }
}
