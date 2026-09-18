import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/services/receipt_pdf_service.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:intl/intl.dart';
import 'package:yang_chow/services/notification_service.dart';
import 'package:yang_chow/services/reservation_service.dart';
import 'package:yang_chow/services/audit_log_service.dart';
import 'package:yang_chow/services/email_notification_service.dart';
import 'package:yang_chow/widgets/price_quotation_dialog.dart';
import 'package:yang_chow/widgets/qr_scanner_dialog.dart';
import 'package:yang_chow/widgets/admin_add_event_dialog.dart';
import 'package:yang_chow/services/app_settings_service.dart';
import 'package:yang_chow/utils/global_messenger.dart';

class AdminReservationsPage extends StatefulWidget {
  final bool isFullscreen;
  final bool isMaintenanceActive;
  const AdminReservationsPage({
    super.key,
    this.isFullscreen = false,
    this.isMaintenanceActive = false,
  });

  @override
  State<AdminReservationsPage> createState() => _AdminReservationsPageState();
}

class _AdminReservationsPageState extends State<AdminReservationsPage> {
  bool _localMaintenanceActive = false;
  bool get _isMaintenance =>
      widget.isMaintenanceActive || _localMaintenanceActive || AppSettingsService().isMaintenanceModeEnabled();

  void _showMaintenanceActionBlockedSnackbar([String actionName = 'This action']) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.lock_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '⚠️ $actionName is locked while system maintenance is active. Only QR scanning is allowed.',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFB45309),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  List<Map<String, dynamic>> reservations = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, pending, quotation_sent, awaiting_payment, confirmed, completed, cancelled, no_show, expired, restricted_customers, archived
  int _currentPage = 0;
  final int _rowsPerPage = 10;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String? _scannedReservationId;
  Map<String, dynamic>? _scannedReservationMeta;
  bool _headerCollapsed = false;
  bool _showMoreFilters = false;
  Map<String, Map<String, dynamic>> _customerRestrictionMap = {};
  Set<String> _restrictedCustomerEmails = {};
  
  // Services
  final ReservationService _reservationService = ReservationService();
  
  // Controllers
  final ScrollController _horizontalScrollController = ScrollController();

  // Realtime subscription
  RealtimeChannel? _realtimeChannel;

  String _getPaymentStatusText(String paymentStatus) {
    switch (paymentStatus.toLowerCase()) {
      case 'fully_paid':
        return 'FULL PAID';
      case 'deposit_paid':
        return 'DEPOSIT PAID';
      case 'paid':
        return 'PAID';
      case 'unpaid':
        return 'UNPAID';
      case 'pending_verification':
        return 'PENDING VERIFICATION';
      default:
        return paymentStatus.toUpperCase();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadReservations();
    _subscribeToReservations();
  }

  void _subscribeToReservations() {
    _realtimeChannel = Supabase.instance.client
        .channel('reservations_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'reservations',
          callback: (payload) {
            // Instantly re-fetch the full list on any change
            _loadReservations();
          },
        )
        .subscribe();
  }

  Future<void> _loadReservations() async {
    setState(() => _isLoading = true);
    
    try {
      // Ensure schema is updated (adds uploaded_id_url, quotation_expires_at if missing)
      await _ensureSchemaSynchronized(silent: true);

      // Check for expired quotations and automatically release slots
      await _reservationService.checkAndExpireQuotations();

      // Check maintenance status dynamically
      try {
        final mRes = await Supabase.instance.client
            .from('app_settings')
            .select('setting_value')
            .eq('setting_key', 'maintenance_mode_enabled')
            .maybeSingle();
        if (mRes != null) {
          final isM = mRes['setting_value']?.toString().toLowerCase() == 'true';
          if (mounted && isM != _localMaintenanceActive) {
            setState(() => _localMaintenanceActive = isM);
          }
        }
      } catch (_) {}

      // Debug: Check current user
      final currentUser = Supabase.instance.client.auth.currentUser;
      debugPrint('Current user: ${currentUser?.email}');
      debugPrint('Current user metadata: ${currentUser?.userMetadata}');
      
      final response = await Supabase.instance.client
          .from('reservations')
          .select('*')
          .order('created_at', ascending: false);

      debugPrint('Reservations loaded: ${response.length}');

      // Check for expired confirmed events and mark completed
      await _updateExpiredReservations(response);

      // Load customer account restriction statuses
      try {
        final usersResponse = await Supabase.instance.client
            .from('users')
            .select('email, restriction_status, warning_count, restriction_reason, restriction_start, restriction_end, restricted_by');
        
        final map = <String, Map<String, dynamic>>{};
        final emails = <String>{};
        final now = DateTime.now();

        for (final u in usersResponse) {
          final email = (u['email'] ?? '').toString().toLowerCase().trim();
          if (email.isNotEmpty) {
            map[email] = Map<String, dynamic>.from(u);
            final status = (u['restriction_status'] ?? 'active').toString().toLowerCase();
            final restrictionEndStr = u['restriction_end']?.toString();
            DateTime? restrictionEnd;
            if (restrictionEndStr != null && restrictionEndStr.isNotEmpty) {
              restrictionEnd = DateTime.tryParse(restrictionEndStr)?.toLocal();
            }

            final isRestricted = (status == 'temporarily_restricted' || status == 'blocked' || status == 'suspended') &&
                (restrictionEnd == null || now.isBefore(restrictionEnd));
            final hasWarning = (u['warning_count'] as num? ?? 0) > 0 || status == 'warning';

            if (isRestricted || hasWarning) {
              emails.add(email);
            }
          }
        }
        _customerRestrictionMap = map;
        _restrictedCustomerEmails = emails;
      } catch (e) {
        debugPrint('Error loading customer restrictions: $e');
      }

      setState(() {
        reservations = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading reservations: $e');
      
      // If we hit a schema error, try to sync and reload once
      if (e.toString().contains('PGRST204') || e.toString().contains('is_archived')) {
        debugPrint('Detected schema mismatch. Attempting auto-sync...');
        await _ensureSchemaSynchronized(silent: true);
        // Retry load once after sync
        try {
          final retryResponse = await Supabase.instance.client
              .from('reservations')
              .select('*')
              .order('created_at', ascending: false);
          setState(() {
            reservations = List<Map<String, dynamic>>.from(retryResponse);
            _isLoading = false;
          });
          return;
        } catch (_) {}
      }

      setState(() => _isLoading = false);
      _showSnackBar('Error loading reservations: $e', Colors.red);
    }
  }

  Future<void> _ensureSchemaSynchronized({bool silent = false}) async {
    try {
      // 1. Ensure columns exist
      await Supabase.instance.client.rpc('exec_sql', params: {
        'sql': "ALTER TABLE public.reservations ADD COLUMN IF NOT EXISTS is_archived BOOLEAN DEFAULT false;"
      });
      await Supabase.instance.client.rpc('exec_sql', params: {
        'sql': "ALTER TABLE public.reservations ADD COLUMN IF NOT EXISTS uploaded_id_url TEXT;"
      });
      await Supabase.instance.client.rpc('exec_sql', params: {
        'sql': "ALTER TABLE public.reservations ADD COLUMN IF NOT EXISTS transacted_by TEXT;"
      });
      await Supabase.instance.client.rpc('exec_sql', params: {
        'sql': "ALTER TABLE public.reservations ADD COLUMN IF NOT EXISTS quotation_expires_at TIMESTAMPTZ;"
      });
      await Supabase.instance.client.rpc('exec_sql', params: {
        'sql': "ALTER TABLE public.reservations DROP CONSTRAINT IF EXISTS reservations_status_check;"
      });
      await Supabase.instance.client.rpc('exec_sql', params: {
        'sql': "ALTER TABLE public.users ADD COLUMN IF NOT EXISTS restriction_status VARCHAR(50) DEFAULT 'active';"
      });
      await Supabase.instance.client.rpc('exec_sql', params: {
        'sql': "ALTER TABLE public.users ADD COLUMN IF NOT EXISTS warning_count INTEGER DEFAULT 0;"
      });
      await Supabase.instance.client.rpc('exec_sql', params: {
        'sql': "ALTER TABLE public.users ADD COLUMN IF NOT EXISTS restriction_reason TEXT;"
      });
      await Supabase.instance.client.rpc('exec_sql', params: {
        'sql': "ALTER TABLE public.users ADD COLUMN IF NOT EXISTS restriction_start TIMESTAMPTZ;"
      });
      await Supabase.instance.client.rpc('exec_sql', params: {
        'sql': "ALTER TABLE public.users ADD COLUMN IF NOT EXISTS restriction_end TIMESTAMPTZ;"
      });
      await Supabase.instance.client.rpc('exec_sql', params: {
        'sql': "ALTER TABLE public.users ADD COLUMN IF NOT EXISTS restricted_by TEXT;"
      });
      
      // 2. Notify PostgREST to reload schema cache
      await Supabase.instance.client.rpc('exec_sql', params: {
        'sql': "NOTIFY pgrst, 'reload schema';"
      });

      if (!silent) _showSnackBar('Database schema synchronized successfully', Colors.green);
    } catch (e) {
      debugPrint('Manual sync error: $e');
      if (!silent) {
        _showSnackBar('Sync failed. Please ensure you have the "exec_sql" RPC function defined in Supabase.', Colors.orange);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _realtimeChannel?.unsubscribe();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _updateExpiredReservations(List<Map<String, dynamic>> reservations) async {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    
    for (final reservation in reservations) {
      // Target confirmed reservations that are not archived
      final currentStatus = (reservation['status'] ?? '').toString().toLowerCase();
      final isArchived = reservation['is_archived'] == true;
      
      if (currentStatus != 'confirmed' || isArchived) continue;
      
      try {
        final eventDate = reservation['event_date']?.toString() ?? '';
        final startTime = reservation['start_time']?.toString() ?? '';
        
        if (eventDate.isEmpty || startTime.isEmpty) continue;

        // --- RULE 1: If the date is strictly before today, it's finished ---
        if (eventDate.compareTo(todayStr) < 0) {
          await _markAsCompleted(reservation, now);
          continue;
        }

        // --- RULE 2: If the date is today, check the specific time + duration ---
        if (eventDate == todayStr) {
          DateTime? eventDateTime;
          try {
            if (startTime.toUpperCase().contains('AM') || startTime.toUpperCase().contains('PM')) {
              DateTime parsedTime;
              try {
                parsedTime = DateFormat.jm().parse(startTime.trim());
              } catch (e) {
                String fixedTime = startTime.toUpperCase().replaceAll('AM', ' AM').replaceAll('PM', ' PM').trim().replaceAll('  ', ' ');
                parsedTime = DateFormat.jm().parse(fixedTime);
              }
              final parsedDate = DateTime.parse(eventDate);
              eventDateTime = DateTime(parsedDate.year, parsedDate.month, parsedDate.day, parsedTime.hour, parsedTime.minute);
            } else {
              String timeStr = startTime;
              if (timeStr.length == 8 && timeStr.contains(':')) timeStr = timeStr.substring(0, 5);
              eventDateTime = DateTime.parse('${eventDate}T$timeStr');
            }
          } catch (e) {
            debugPrint('Expiration parsing error for ${reservation['id']}: $e');
          }

          if (eventDateTime != null) {
            final durationValue = reservation['duration_hours'];
            int durationHours = (durationValue is int) ? durationValue : (int.tryParse(durationValue?.toString() ?? '4') ?? 4);
            final expiresAt = eventDateTime.add(Duration(hours: durationHours));
            
            if (now.isAfter(expiresAt)) {
              await _markAsCompleted(reservation, now);
            }
          }
        }
      } catch (e) {
        debugPrint('Error checking reservation expiration: $e');
      }
    }
  }

  Future<void> _markAsCompleted(Map<String, dynamic> reservation, DateTime now) async {
    try {
      await Supabase.instance.client
          .from('reservations')
          .update({
            'status': 'completed',
            'updated_at': now.toUtc().toIso8601String()
          })
          .eq('id', reservation['id']);
      
      // Update local state immediately
      reservation['status'] = 'completed';
      debugPrint('Reservation ${reservation['id']} auto-completed.');
    } catch (e) {
      debugPrint('Failed to mark reservation as completed in DB: $e');
      // If DB update fails (schema issue), we still mark it locally so the UI looks correct for this session
      reservation['status'] = 'completed';
    }
  }

  Future<void> _archiveReservation(String reservationId) async {
    // Optimistic update
    setState(() {
      final idx = reservations.indexWhere((r) => r['id'] == reservationId);
      if (idx != -1) reservations[idx] = {...reservations[idx], 'is_archived': true};
    });
    try {
      await Supabase.instance.client
          .from('reservations')
          .update({'is_archived': true, 'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', reservationId);

      _showSnackBar('Reservation archived successfully', Colors.green);
    } catch (e) {
      _loadReservations(); // Revert on error
      _showSnackBar('Error archiving reservation: $e', Colors.red);
    }
  }

  Future<void> _restoreReservation(String reservationId) async {
    // Optimistic update
    setState(() {
      final idx = reservations.indexWhere((r) => r['id'] == reservationId);
      if (idx != -1) reservations[idx] = {...reservations[idx], 'is_archived': false};
    });
    try {
      await Supabase.instance.client
          .from('reservations')
          .update({'is_archived': false, 'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', reservationId);

      _showSnackBar('Reservation restored', Colors.green);
    } catch (e) {
      _loadReservations(); // Revert on error
      _showSnackBar('Error restoring reservation: $e', Colors.red);
    }
  }

  Future<void> _hardDeleteReservation(String reservationId) async {
    // Optimistic update — remove from local list immediately
    setState(() {
      reservations.removeWhere((r) => r['id'] == reservationId);
    });
    try {
      await Supabase.instance.client
          .from('reservations')
          .delete()
          .eq('id', reservationId);

      AuditLogService.logActivity(
        action: 'DELETE',
        module: 'Reservations',
        description: 'Permanently deleted reservation #$reservationId',
        entityId: reservationId,
        metadata: {'operation': 'hard_delete'},
      );

      _showSnackBar('Reservation permanently deleted', Colors.green);
    } catch (e) {
      _loadReservations(); // Revert on error
      _showSnackBar('Error deleting reservation: $e', Colors.red);
    }
  }

  Future<void> _updateReservationStatus(String reservationId, String newStatus, [Map<String, dynamic>? reservation]) async {
    setState(() {
      final idx = reservations.indexWhere((r) => r['id'] == reservationId);
      if (idx != -1) {
        final currentUser = Supabase.instance.client.auth.currentUser;
        final adminIdentifier = currentUser?.email ?? 'unknown_admin';
        final updatedItem = {
          ...reservations[idx],
          'status': newStatus,
          'transacted_by': adminIdentifier,
        };
        if (newStatus == 'confirmed') {
          final paymentOption = (reservations[idx]['payment_option'] ?? 'deposit').toString().toLowerCase();
          final totalPrice = (reservations[idx]['total_price'] as num?)?.toDouble() ?? 0.0;
          final depositAmount = (reservations[idx]['deposit_amount'] as num?)?.toDouble() ?? (totalPrice * 0.5);
          final isFull = paymentOption == 'full' || paymentOption == '100';
          updatedItem['payment_status'] = isFull ? 'fully_paid' : 'deposit_paid';
          updatedItem['remaining_balance'] = isFull ? 0.0 : ((totalPrice > depositAmount) ? (totalPrice - depositAmount) : 0.0);
        }
        reservations[idx] = updatedItem;
      }
    });

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      final adminIdentifier = currentUser?.email ?? 'unknown_admin';

      final Map<String, dynamic> updateData = {
        'status': newStatus,
        'transacted_by': adminIdentifier,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (newStatus == 'confirmed') {
        final currentPaymentStatus = (reservation?['payment_status'] ?? '').toString().toLowerCase();
        final paymentMethod = (reservation?['payment_method'] ?? 'paymongo').toString().toLowerCase();
        final paymentOption = (reservation?['payment_option'] ?? 'deposit').toString().toLowerCase();
        final totalPrice = (reservation?['total_price'] as num?)?.toDouble() ?? 0.0;
        final depositAmount = (reservation?['deposit_amount'] as num?)?.toDouble() ?? (totalPrice * 0.5);

        if (paymentMethod == 'cash' || currentPaymentStatus == 'unpaid' || currentPaymentStatus == 'pending' || currentPaymentStatus.isEmpty) {
          final isFull = paymentOption == 'full' || paymentOption == '100';
          if (isFull) {
            updateData['payment_status'] = 'fully_paid';
            updateData['remaining_balance'] = 0.0;
            updateData['payment_amount'] = totalPrice;
          } else {
            updateData['payment_status'] = 'deposit_paid';
            updateData['remaining_balance'] = (totalPrice > depositAmount) ? (totalPrice - depositAmount) : 0.0;
            updateData['payment_amount'] = depositAmount;
          }
        }
      }

      await Supabase.instance.client
          .from('reservations')
          .update(updateData)
          .eq('id', reservationId);

      // Log reservation status change
      AuditLogService.logActivity(
        action: newStatus == 'confirmed'
            ? 'APPROVE'
            : (newStatus == 'no_show'
                ? 'NO_SHOW'
                : (newStatus == 'cancelled' ? 'REJECT' : 'STATUS_CHANGE')),
        module: 'Reservations',
        description: 'Updated reservation #$reservationId status to "${newStatus.toUpperCase()}" for ${reservation?['customer_name'] ?? 'Customer'}',
        entityId: reservationId,
        metadata: {
          'status': newStatus,
          'customer_name': reservation?['customer_name'],
          'event_type': reservation?['event_type'],
          'event_date': reservation?['event_date'],
        },
      );

      // Generate Auto Announcement on Confirm
      if (newStatus == 'confirmed' && reservation != null) {
        final eventDate = reservation['event_date'];
        final startTime = reservation['start_time'];
        
        DateTime eventDateTime;
        try {
          // Attempt to parse date and time combined
          // Handles cases like "HH:mm" or "h:mm a"
          if (startTime.toUpperCase().contains('AM') || startTime.toUpperCase().contains('PM')) {
            // Localized format from TimePicker (e.g. "11:43 AM" or "11:43AM")
            DateTime parsedTime;
            try {
              parsedTime = DateFormat.jm().parse(startTime.trim());
            } catch (e) {
              // Try adding a space if missing
              String fixedTime = startTime.toUpperCase().replaceAll('AM', ' AM').replaceAll('PM', ' PM').trim().replaceAll('  ', ' ');
              parsedTime = DateFormat.jm().parse(fixedTime);
            }
            final parsedDate = DateTime.parse(eventDate);
            eventDateTime = DateTime(
              parsedDate.year,
              parsedDate.month,
              parsedDate.day,
              parsedTime.hour,
              parsedTime.minute,
            );
          } else {
            // ISO-ish format (e.g. "11:43" or "11:43:00")
            String timeStr = startTime;
            if (timeStr.length == 5) timeStr = '$timeStr:00';
            eventDateTime = DateTime.parse('${eventDate}T$timeStr');
          }
        } catch (e) {
          debugPrint('Parsing error: $e');
          try {
            eventDateTime = DateTime.parse(eventDate);
          } catch(e) {
            eventDateTime = DateTime.now();
          }
        }
        
        // Get duration (it might be String or int depending on how it's stored)
        final durationValue = reservation['duration_hours'];
        int durationHours = 4; // Default to 4 hours
        if (durationValue != null) {
          if (durationValue is int) {
            durationHours = durationValue;
          } else if (durationValue is String) {
            durationHours = int.tryParse(durationValue) ?? 4;
          }
        }
        
        final expiresAt = eventDateTime.add(Duration(hours: durationHours));

        // Format the time for display
        String displayTime;
        if (startTime.toUpperCase().contains('AM') || startTime.toUpperCase().contains('PM')) {
          displayTime = startTime; // Already in 12-hour format
        } else {
          // Convert 24-hour format to 12-hour format
          if (startTime.length == 8 && startTime.contains(':')) {
            // Format: "18:35:00" -> convert to "6:35 PM"
            final hour = int.parse(startTime.substring(0, 2));
            final minute = startTime.substring(3, 5);
            final period = hour >= 12 ? 'PM' : 'AM';
            final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
            displayTime = '$displayHour:$minute $period';
          } else {
            displayTime = startTime; // Fallback to original
          }
        }

        await Supabase.instance.client.from('announcements').insert({
          'title': 'Confirmed Reservation: ${reservation['event_type']}',
          'content': 'We are excited to host ${reservation['customer_name']} and ${reservation['number_of_guests']} guests for a ${reservation['event_type']} on $eventDate at $displayTime.',
          'is_active': true,
          'expires_at': expiresAt.toUtc().toIso8601String(),
        });
      }

      // Send notification to customer
      if (reservation != null) {
        String actionVerb = 'updated';
        if (newStatus == 'confirmed') actionVerb = 'approved';
        if (newStatus == 'cancelled') actionVerb = 'cancelled';
        if (newStatus == 'completed') actionVerb = 'completed';

        await NotificationService.sendNotification(
          recipientEmail: reservation['customer_email'],
          actorName: 'Admin',
          actionType: actionVerb,
          reservationId: reservationId,
          eventType: reservation['event_type'],
          eventDate: reservation['event_date'],
        );
      }

      _showSnackBar('Reservation status updated to $newStatus', Colors.green);
      _loadReservations(); // Refresh the list
    } catch (e) {
      _showSnackBar('Error updating reservation: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    final isGreen = color == Colors.green ||
        color == const Color(0xFF15803D) ||
        color == const Color(0xFF10B981);
    final isRed = color == Colors.red ||
        color == const Color(0xFFDC2626) ||
        color == const Color(0xFFEF4444);
    final isOrange = color == Colors.orange ||
        color == const Color(0xFFF59E0B);

    if (isGreen) {
      GlobalMessenger.showSuccess(message);
    } else if (isRed) {
      GlobalMessenger.showError(message);
    } else if (isOrange) {
      GlobalMessenger.showWarning(message);
    } else {
      GlobalMessenger.showSuccess(message);
    }
  }

  List<Map<String, dynamic>> get _filteredReservations {
    // If an exact reservation was scanned, filter strictly to that event
    if (_scannedReservationId != null) {
      final match = reservations.where((r) => r['id']?.toString() == _scannedReservationId).toList();
      if (match.isNotEmpty) return match;
    }

    List<Map<String, dynamic>> base;
    if (_selectedFilter == 'archived') {
      base = reservations.where((r) => r['is_archived'] == true).toList();
    } else {
      final unarchived = reservations.where((r) => r['is_archived'] != true);
      if (_selectedFilter == 'all') {
        base = unarchived.toList();
      } else if (_selectedFilter == 'quotation_sent') {
        base = unarchived.where((r) => r['price_quotation_sent'] == true && r['status'] == 'pending').toList();
      } else if (_selectedFilter == 'awaiting_payment') {
        base = unarchived.where((r) =>
            r['price_quotation_sent'] == true &&
            (r['payment_status'] ?? '').toString().toLowerCase() == 'unpaid' &&
            r['status'] == 'pending').toList();
      } else if (_selectedFilter == 'expired') {
        base = unarchived.where((r) => (r['status'] ?? '').toString().toLowerCase() == 'expired').toList();
      } else if (_selectedFilter == 'restricted_customers') {
        base = unarchived.where((r) {
          final em = (r['customer_email'] ?? '').toString().toLowerCase().trim();
          return _restrictedCustomerEmails.contains(em);
        }).toList();
      } else {
        base = unarchived.where((r) => r['status'] == _selectedFilter).toList();
      }
    }
    if (_searchQuery.isEmpty) return base;
    final q = _searchQuery.toLowerCase();
    return base.where((r) {
      final id    = (r['id']              ?? '').toString().toLowerCase();
      final name  = (r['customer_name']  ?? '').toString().toLowerCase();
      final email = (r['customer_email'] ?? '').toString().toLowerCase();
      final event = (r['event_type']     ?? '').toString().toLowerCase();
      return id.contains(q) || name.contains(q) || email.contains(q) || event.contains(q);
    }).toList();
  }

  // ── Design tokens ──────────────────────────────────────────────────────────
  static const _darkBg    = Color(0xFF0F172A);
  static const _emerald   = Color(0xFF14332E);
  static const _gold      = Color(0xFFD9A441);
  static const _slate     = Color(0xFF64748B);
  static const _slateLight = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final content = Padding(
      padding: isDesktop
          ? EdgeInsets.zero
          : const EdgeInsets.only(top: 8.0, left: 12.0, right: 12.0, bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
          ),
        ],
      ),
    );

    if (widget.isFullscreen) {
      return Scaffold(
        backgroundColor: AppTheme.adminMainBackground,
        body: SafeArea(child: content),
      );
    }
    return content;
  }



  Widget _buildDesktopLayout() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageHeader(),
          AnimatedCrossFade(
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),
                _buildStatsBar(),
                const SizedBox(height: 10),
              ],
            ),
            secondChild: const SizedBox(height: 10, width: double.infinity),
            crossFadeState: _headerCollapsed
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 280),
            sizeCurve: Curves.easeInOut,
          ),
          _buildSearchBar(),
          const SizedBox(height: 8),
          _buildActiveSearchFilterNotice(),
          const SizedBox(height: 2),
          Expanded(child: _buildReservationsTable()),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildPageHeader(),
        AnimatedCrossFade(
          firstChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              _buildStatsBar(),
              const SizedBox(height: 8),
            ],
          ),
          secondChild: const SizedBox(height: 8, width: double.infinity),
          crossFadeState: _headerCollapsed
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 280),
          sizeCurve: Curves.easeInOut,
        ),
        _buildSearchBar(),
        const SizedBox(height: 6),
        _buildActiveSearchFilterNotice(),
        const SizedBox(height: 2),
        Expanded(child: _buildReservationsList()),
      ],
    );
  }

  Widget _buildActiveSearchFilterNotice() {
    if (_scannedReservationId != null && _scannedReservationMeta != null) {
      final name = _scannedReservationMeta!['customer_name'] ?? 'Guest';
      final event = _scannedReservationMeta!['event_type'] ?? 'Event';
      final date = _scannedReservationMeta!['event_date'] ?? '';
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF15803D)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Showing verified scanned booking: "$name" • $event${date.isNotEmpty ? ' ($date)' : ''}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF166534),
                ),
              ),
            ),
            InkWell(
              onTap: () => setState(() {
                _scannedReservationId = null;
                _scannedReservationMeta = null;
                _currentPage = 0;
              }),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.close_rounded, size: 14, color: Color(0xFF15803D)),
                  const SizedBox(width: 4),
                  Text(
                    'Show All',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF15803D),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_searchQuery.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 16, color: Color(0xFF15803D)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Showing search result for: "$_searchQuery"',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF166534),
              ),
            ),
          ),
          InkWell(
            onTap: () => setState(() {
              _searchQuery = '';
              _searchController.clear();
              _currentPage = 0;
            }),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.close_rounded, size: 14, color: Color(0xFF15803D)),
                const SizedBox(width: 4),
                Text(
                  'Show All',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF15803D),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return SizedBox(
      height: 38,
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() {
          _scannedReservationId = null;
          _scannedReservationMeta = null;
          _searchQuery = v.trim();
          _currentPage = 0;
        }),
        style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: 'Search by name, email, or event type…',
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: const Color(0xFF94A3B8),
          ),
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () => setState(() {
                    _searchQuery = '';
                    _searchController.clear();
                    _currentPage = 0;
                  }),
                  child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF14332E), width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildPageHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _slateLight),
        boxShadow: [
          BoxShadow(
            color: _darkBg.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF14332E), Color(0xFF1E4A42)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: _emerald.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.event_available_rounded, color: _gold, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Event Reservations',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _darkBg,
                        letterSpacing: -0.4,
                      ),
                      maxLines: 2,
                    ),
                    if (_isMaintenance) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFF59E0B)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.qr_code_scanner_rounded, size: 11, color: Color(0xFFB45309)),
                            const SizedBox(width: 4),
                            Text(
                              'SCAN ONLY (MAINTENANCE)',
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF92400E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'Manage, approve and track all reservation bookings',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: _slate,
                    fontWeight: FontWeight.w500,
                    height: 1.15,
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            icon: Icon(_isMaintenance ? Icons.lock_outline_rounded : Icons.add_rounded, size: 18),
            label: ResponsiveUtils.isMobile(context) 
                ? const SizedBox.shrink() 
                : Text('Add Event', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isMaintenance ? const Color(0xFFCBD5E1) : const Color(0xFF14332E),
              foregroundColor: _isMaintenance ? const Color(0xFF64748B) : AppTheme.warmGold,
              padding: EdgeInsets.symmetric(horizontal: ResponsiveUtils.isMobile(context) ? 10 : 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (_isMaintenance) {
                _showMaintenanceActionBlockedSnackbar('Adding new events');
                return;
              }
              AdminAddEventDialog.show(
                context,
                onEventCreated: () {
                  _loadReservations();
                },
              );
            },
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
            label: ResponsiveUtils.isMobile(context) 
                ? const SizedBox.shrink() 
                : Text('Scan Pass', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isMaintenance ? const Color(0xFF0F766E) : const Color(0xFF14332E),
              foregroundColor: _isMaintenance ? Colors.white : AppTheme.warmGold,
              padding: EdgeInsets.symmetric(horizontal: ResponsiveUtils.isMobile(context) ? 10 : 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => QrScannerDialog.show(
              context,
              onCheckInSuccess: (scanned) {
                _loadReservations();
                final resId = scanned['id']?.toString();
                setState(() {
                  _scannedReservationId = resId;
                  _scannedReservationMeta = scanned;
                  _selectedFilter = 'all';
                  _searchQuery = '';
                  _searchController.clear();
                  _currentPage = 0;
                });
              },
            ),
          ),

          AnimatedRotation(
            turns: _headerCollapsed ? 0.5 : 0.0,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            child: IconButton(
              onPressed: () => setState(() => _headerCollapsed = !_headerCollapsed),
              icon: const Icon(Icons.keyboard_arrow_up_rounded, color: _slate, size: 22),
              tooltip: _headerCollapsed ? 'Show Stats' : 'Hide Stats',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    final unarchived = reservations.where((r) => r['is_archived'] != true);
    final pending     = unarchived.where((r) => r['status'] == 'pending').length;
    final quoteSent   = unarchived.where((r) => r['price_quotation_sent'] == true && r['status'] == 'pending').length;
    final awaitingPay = unarchived.where((r) =>
        r['price_quotation_sent'] == true &&
        (r['payment_status'] ?? '').toString().toLowerCase() == 'unpaid' &&
        r['status'] == 'pending').length;
    final expired     = unarchived.where((r) => (r['status'] ?? '').toString().toLowerCase() == 'expired').length;
    final confirmed   = unarchived.where((r) => r['status'] == 'confirmed').length;
    final completed   = unarchived.where((r) => r['status'] == 'completed').length;
    final cancelled   = unarchived.where((r) => r['status'] == 'cancelled').length;
    final noShow      = unarchived.where((r) => r['status'] == 'no_show').length;
    final restricted  = unarchived.where((r) {
      final em = (r['customer_email'] ?? '').toString().toLowerCase().trim();
      return _restrictedCustomerEmails.contains(em);
    }).length;
    final archived    = reservations.where((r) => r['is_archived'] == true).length;

    final isMobile = ResponsiveUtils.isMobile(context);

    if (isMobile) {
      return SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          children: [
            _statTile('Total', unarchived.length, Icons.calendar_month_rounded, const Color(0xFFDCFCE7), const Color(0xFF15803D), 'all', width: 110),
            const SizedBox(width: 8),
            _statTile('Pending', pending, Icons.hourglass_top_rounded, const Color(0xFFFEF3C7), const Color(0xFFD97706), 'pending', width: 114),
            const SizedBox(width: 8),
            _statTile('Quote Sent', quoteSent, Icons.send_rounded, const Color(0xFFEFF6FF), const Color(0xFF2563EB), 'quotation_sent', width: 124),
            const SizedBox(width: 8),
            _statTile('Awaiting Pay', awaitingPay, Icons.pending_actions_rounded, const Color(0xFFFFFBEB), const Color(0xFFB45309), 'awaiting_payment', width: 130),
            const SizedBox(width: 8),
            _statTile('Confirmed', confirmed, Icons.check_circle_rounded, const Color(0xFFDCFCE7), const Color(0xFF15803D), 'confirmed', width: 122),
            const SizedBox(width: 8),
            _statTile('Completed', completed, Icons.done_all_rounded, const Color(0xFFE0F2FE), const Color(0xFF0284C7), 'completed', width: 122),
            const SizedBox(width: 8),
            _statTile('Expired', expired, Icons.timer_off_rounded, const Color(0xFFF3E8FF), const Color(0xFF9333EA), 'expired', width: 114),
            const SizedBox(width: 8),
            _statTile('Cancelled', cancelled, Icons.cancel_rounded, const Color(0xFFFEE2E2), const Color(0xFFDC2626), 'cancelled', width: 118),
            const SizedBox(width: 8),
            _statTile('No-Show', noShow, Icons.person_off_rounded, const Color(0xFFFFEDD5), const Color(0xFFEA580C), 'no_show', width: 118),
            const SizedBox(width: 8),
            _statTile('Restricted', restricted, Icons.lock_outline_rounded, const Color(0xFFFEF2F2), const Color(0xFFB91C1C), 'restricted_customers', width: 126),
            const SizedBox(width: 8),
            _statTile('Archived', archived, Icons.inventory_2_rounded, const Color(0xFFF1F5F9), const Color(0xFF475569), 'archived', width: 114),
          ],
        ),
      );
    }

    final bool hasActiveSecondary = ['expired', 'cancelled', 'no_show', 'restricted_customers', 'archived'].contains(_selectedFilter);
    final bool isRow2Expanded = _showMoreFilters || hasActiveSecondary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Row 1: Active Booking Flow (6 tiles) + Collapsible Toggle
        Row(
          children: [
            Expanded(child: _statTile('Total', unarchived.length, Icons.calendar_month_rounded, const Color(0xFFDCFCE7), const Color(0xFF15803D), 'all')),
            const SizedBox(width: 8),
            Expanded(child: _statTile('Pending', pending, Icons.hourglass_top_rounded, const Color(0xFFFEF3C7), const Color(0xFFD97706), 'pending')),
            const SizedBox(width: 8),
            Expanded(child: _statTile('Quote Sent', quoteSent, Icons.send_rounded, const Color(0xFFEFF6FF), const Color(0xFF2563EB), 'quotation_sent')),
            const SizedBox(width: 8),
            Expanded(child: _statTile('Awaiting Pay', awaitingPay, Icons.pending_actions_rounded, const Color(0xFFFFFBEB), const Color(0xFFB45309), 'awaiting_payment')),
            const SizedBox(width: 8),
            Expanded(child: _statTile('Confirmed', confirmed, Icons.check_circle_rounded, const Color(0xFFDCFCE7), const Color(0xFF15803D), 'confirmed')),
            const SizedBox(width: 8),
            Expanded(child: _statTile('Completed', completed, Icons.done_all_rounded, const Color(0xFFE0F2FE), const Color(0xFF0284C7), 'completed')),
            const SizedBox(width: 8),
            _buildMoreToggleButton(isRow2Expanded, hasActiveSecondary),
          ],
        ),

        // Row 2: Collapsible Outcomes, Exceptions & Archive (5 tiles)
        AnimatedCrossFade(
          firstChild: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(child: _statTile('Expired', expired, Icons.timer_off_rounded, const Color(0xFFF3E8FF), const Color(0xFF9333EA), 'expired')),
                const SizedBox(width: 8),
                Expanded(child: _statTile('Cancelled', cancelled, Icons.cancel_rounded, const Color(0xFFFEE2E2), const Color(0xFFDC2626), 'cancelled')),
                const SizedBox(width: 8),
                Expanded(child: _statTile('No-Show', noShow, Icons.person_off_rounded, const Color(0xFFFFEDD5), const Color(0xFFEA580C), 'no_show')),
                const SizedBox(width: 8),
                Expanded(child: _statTile('Restricted', restricted, Icons.lock_outline_rounded, const Color(0xFFFEF2F2), const Color(0xFFB91C1C), 'restricted_customers')),
                const SizedBox(width: 8),
                Expanded(child: _statTile('Archived', archived, Icons.inventory_2_rounded, const Color(0xFFF1F5F9), const Color(0xFF475569), 'archived')),
              ],
            ),
          ),
          secondChild: const SizedBox.shrink(),
          crossFadeState: isRow2Expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 240),
          sizeCurve: Curves.easeInOut,
        ),
      ],
    );
  }

  Widget _buildMoreToggleButton(bool isExpanded, bool hasActiveSecondary) {
    return InkWell(
      onTap: () {
        setState(() {
          if (isExpanded && hasActiveSecondary) {
            _selectedFilter = 'all';
            _currentPage = 0;
            _showMoreFilters = false;
          } else {
            _showMoreFilters = !isExpanded;
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: hasActiveSecondary
              ? AppTheme.warmGold.withValues(alpha: 0.12)
              : (isExpanded ? const Color(0xFFF1F5F9) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasActiveSecondary
                ? AppTheme.warmGold
                : (isExpanded ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0)),
            width: hasActiveSecondary ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: hasActiveSecondary
                    ? AppTheme.warmGold.withValues(alpha: 0.22)
                    : (isExpanded ? const Color(0xFFE2E8F0) : const Color(0xFFF8FAFC)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isExpanded ? Icons.expand_less_rounded : Icons.tune_rounded,
                size: 15,
                color: hasActiveSecondary ? const Color(0xFFB45309) : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isExpanded ? 'Less' : '+5 More',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: hasActiveSecondary ? const Color(0xFFB45309) : const Color(0xFF1E293B),
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (hasActiveSecondary) ...[
                      const SizedBox(width: 4),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Color(0xFFB45309),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  isExpanded ? 'Hide row' : 'Statuses',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9.5,
                    color: hasActiveSecondary ? const Color(0xFFB45309) : const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile(String label, int value, IconData icon, Color bg, Color iconColor, String filterKey, {double? width}) {
    final bool isSelected = _selectedFilter == filterKey;

    Widget content = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: width,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? iconColor.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? iconColor : const Color(0xFFE2E8F0),
          width: isSelected ? 1.8 : 1.0,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: iconColor.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        mainAxisSize: width != null ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isSelected ? iconColor : bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: isSelected ? Colors.white : iconColor, size: 15),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value.toString(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? iconColor : _darkBg,
                    letterSpacing: -0.3,
                    height: 1.1,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    color: isSelected ? iconColor : const Color(0xFF64748B),
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedFilter = filterKey;
          _currentPage = 0;
          if (['expired', 'cancelled', 'no_show', 'restricted_customers', 'archived'].contains(filterKey)) {
            _showMoreFilters = true;
          }
        }),
        child: content,
      ),
    );
  }

  Widget _buildReservationsTable() {
    if (_isLoading) return _buildLoadingState();
    final filtered = _filteredReservations;
    if (filtered.isEmpty) return _buildEmptyState();

    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage < filtered.length)
        ? startIndex + _rowsPerPage
        : filtered.length;
    final paginatedReservations = filtered.sublist(startIndex, endIndex);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _slateLight),
        boxShadow: [
          BoxShadow(
            color: _darkBg.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(bottom: BorderSide(color: _slateLight, width: 1.5)),
            ),
            child: Row(
              children: [
                Expanded(flex: 3, child: _tableHeader('CUSTOMER')),
                Expanded(flex: 2, child: _tableHeader('EVENT')),
                Expanded(flex: 2, child: _tableHeader('SCHEDULE')),
                Expanded(flex: 2, child: _tableHeader('PRICING')),
                SizedBox(width: 110, child: _tableHeader('STATUS')),
                SizedBox(width: 85, child: _tableHeader('ACTIONS')),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: paginatedReservations.length,
              separatorBuilder: (_, __) => Divider(
                height: 1, thickness: 1, color: _slateLight.withValues(alpha: 0.8),
              ),
              itemBuilder: (context, index) {
                final r = paginatedReservations[index];
                return _buildTableRow(r);
              },
            ),
          ),
          if (filtered.length > _rowsPerPage)
            _buildPaginationControls(filtered.length),
        ],
      ),
    );
  }

  Widget _tableHeader(String label) {
    return Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF475569),
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildTableRow(Map<String, dynamic> r) {
    final status = (r['status'] ?? 'pending').toString().toLowerCase();
    final totalPrice = (r['total_price'] as num?)?.toDouble() ?? 0.0;
    final depositAmount = (r['deposit_amount'] as num?)?.toDouble() ?? 0.0;
    final eventType = (r['event_type'] ?? 'Banquet Event').toString();
    final guestCount = r['number_of_guests'] ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
      ),
      child: Row(
        children: [
          // Customer Details
          Expanded(
            flex: 3,
            child: Row(
              children: [
                _miniAvatar(r['customer_name'] ?? '?'),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              r['customer_name'] ?? 'N/A',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: _darkBg,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (r['id_proof_url'] != null && r['id_proof_url'].toString().isNotEmpty) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF0284C7)),
                          ],
                          Builder(
                            builder: (context) {
                              final email = (r['customer_email'] ?? '').toString().toLowerCase().trim();
                              final custInfo = _customerRestrictionMap[email];
                              final status = (custInfo?['restriction_status'] ?? 'active').toString().toLowerCase();
                              final isRestricted = status == 'temporarily_restricted' || status == 'blocked' || status == 'suspended';
                              final warningCount = (custInfo?['warning_count'] as num?)?.toInt() ?? 0;

                              if (isRestricted) {
                                return Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFFECACA)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.lock_rounded, size: 9, color: Color(0xFFDC2626)),
                                      const SizedBox(width: 2),
                                      Text(
                                        status == 'blocked' ? 'BLOCKED' : (status == 'suspended' ? 'SUSPENDED' : 'RESTRICTED'),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFFDC2626),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              } else if (warningCount > 0 || status == 'warning') {
                                return Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFFBEB),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFFDE68A)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.warning_amber_rounded, size: 9, color: Color(0xFFD97706)),
                                      const SizedBox(width: 2),
                                      Text(
                                        'WARN ($warningCount)',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFFD97706),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Builder(
                        builder: (context) {
                          final email = (r['customer_email'] ?? '').toString().trim();
                          final displayEmail = (email.isEmpty || email.toLowerCase() == 'n/a' || email.startsWith('walkin_'))
                              ? 'N/A'
                              : email;
                          return Text(
                            displayEmail,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: _slate,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.admin_panel_settings_outlined, size: 12, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              r['transacted_by'] != null && r['transacted_by'].toString().isNotEmpty
                                  ? 'Admin: ${r['transacted_by']}'
                                  : 'Admin: Pending',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: r['transacted_by'] != null && r['transacted_by'].toString().isNotEmpty
                                    ? const Color(0xFF166534)
                                    : const Color(0xFF94A3B8),
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Event Type & Pax
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getEventIcon(eventType), size: 14, color: const Color(0xFFC9922E)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        eventType,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _darkBg,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$guestCount Expected Guests',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: _slate,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Schedule
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _formatReadableDate(r['event_date']?.toString() ?? ''),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _darkBg,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      _formatReadableTime(r['start_time']?.toString() ?? ''),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: _slate,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Financials
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (status == 'expired') ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFF87171)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_off_outlined, size: 11, color: Color(0xFFDC2626)),
                        const SizedBox(width: 4),
                        Text(
                          'Slot Released (Expired)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (totalPrice > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '₱${totalPrice.toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _slate,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ] else if (totalPrice > 0) ...[
                  Row(
                    children: [
                      Text(
                        '₱${totalPrice.toStringAsFixed(2)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: _emerald,
                        ),
                      ),
                      if (r['quotation_expires_at'] != null && status == 'pending') ...[
                        const SizedBox(width: 6),
                        _buildQuotationCountdownChip(r['quotation_expires_at']),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Builder(
                    builder: (context) {
                      final paymentStatus = (r['payment_status'] ?? 'unpaid').toString().toLowerCase();
                      final isFullyPaid = paymentStatus == 'fully_paid' || paymentStatus == 'paid';
                      final num? dbRemNum = r['remaining_balance'] as num?;
                      final double effectiveRem = isFullyPaid
                          ? 0.0
                          : (dbRemNum != null ? dbRemNum.toDouble() : (totalPrice - depositAmount).clamp(0.0, double.infinity));
                      final double effectivePaid = isFullyPaid
                          ? totalPrice
                          : (depositAmount > 0 ? depositAmount : 0.0);

                      if (isFullyPaid || effectiveRem <= 0) {
                        return Text(
                          'Paid: ₱${effectivePaid.toStringAsFixed(0)} (Rem: ₱0)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: const Color(0xFF15803D),
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      }

                      return Text(
                        depositAmount > 0
                            ? 'Paid: ₱${depositAmount.toStringAsFixed(0)} (Rem: ₱${effectiveRem.toStringAsFixed(0)})'
                            : 'No Deposit Paid Yet',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: depositAmount > 0 ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ] else
                  Text(
                    'Quotation Pending',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: const Color(0xFF94A3B8),
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          // Status
          SizedBox(
            width: 110,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildCompactStatusChip(status),
            ),
          ),
          // Actions
          SizedBox(
            width: 85,
            child: _buildCompactActionButtons(r),
          ),
        ],
      ),
    );
  }

  IconData _getEventIcon(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('wed')) return Icons.favorite_rounded;
    if (lower.contains('birth')) return Icons.cake_rounded;
    if (lower.contains('corp') || lower.contains('business')) return Icons.business_center_rounded;
    if (lower.contains('debut')) return Icons.star_rounded;
    return Icons.celebration_rounded;
  }

  Widget _miniAvatar(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final colors = [
      const Color(0xFF14332E), const Color(0xFF0284C7),
      const Color(0xFF7C3AED), const Color(0xFFD97706),
    ];
    final c = colors[name.codeUnits.fold(0, (a, b) => a + b) % colors.length];
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: c.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _gold.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(_gold),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading Reservations...',
            style: GoogleFonts.plusJakartaSans(
              color: _slate,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationControls(int totalItems) {
    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage < totalItems)
        ? startIndex + _rowsPerPage
        : totalItems;
    final totalPages = (totalItems / _rowsPerPage).ceil();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _slateLight)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${startIndex + 1}–$endIndex of $totalItems reservations',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: _slate,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              _pageBtn(
                icon: Icons.chevron_left_rounded,
                enabled: _currentPage > 0,
                onTap: () => setState(() => _currentPage--),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Page ${_currentPage + 1} of $totalPages',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _darkBg,
                  ),
                ),
              ),
              _pageBtn(
                icon: Icons.chevron_right_rounded,
                enabled: endIndex < totalItems,
                onTap: () => setState(() => _currentPage++),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pageBtn({required IconData icon, required bool enabled, required VoidCallback onTap}) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: enabled ? _emerald : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? Colors.white : const Color(0xFFCBD5E1),
        ),
      ),
    );
  }

  String _formatReadableDate(String dateString) {
    if (dateString.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  String _formatReadableTime(String timeString) {
    if (timeString.isEmpty) return 'N/A';
    try {
      if (!timeString.toUpperCase().contains('M')) {
        String formatted = timeString;
        if (formatted.length >= 5) formatted = formatted.substring(0, 5); 
        final parts = formatted.split(':');
        if (parts.length == 2) {
          final dt = DateTime(2020, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
          return DateFormat('h:mm a').format(dt);
        }
      }
    } catch (e) {}
    return timeString;
  }

  Widget _buildReservationsList() {
    if (_isLoading) return _buildLoadingState();
    if (_filteredReservations.isEmpty) return _buildEmptyState();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _filteredReservations.length,
      itemBuilder: (context, index) {
        final reservation = _filteredReservations[index];
        return _buildMobileCard(reservation, index);
      },
    );
  }

  Widget _buildMobileCard(Map<String, dynamic> reservation, int index) {
    final status = (reservation['status'] ?? 'pending').toString().toLowerCase();
    final totalPrice = reservation['total_price'];
    final paymentStatus = (reservation['payment_status'] ?? 'unpaid').toString();

    Color statusColor;
    switch (status) {
      case 'pending':   statusColor = const Color(0xFFD97706); break;
      case 'confirmed': statusColor = const Color(0xFF15803D); break;
      case 'completed': statusColor = const Color(0xFF0284C7); break;
      case 'cancelled': statusColor = const Color(0xFFDC2626); break;
      default:          statusColor = _slate;
    }

    return TweenAnimationBuilder<double>(
      key: ValueKey(reservation['id']),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 350 + (index * 80).clamp(0, 500)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, 24 * (1 - value)),
        child: Opacity(opacity: value, child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _HoverAnimatedCard(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _slateLight),
              boxShadow: [
                BoxShadow(
                  color: _darkBg.withValues(alpha: 0.025),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // Status accent bar
                  Container(
                    width: 5,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top row — event type + status chip
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  reservation['event_type'] ?? 'Unknown Event',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: _darkBg,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildCompactStatusChip(status),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Customer row
                          Row(
                            children: [
                              _miniAvatar(reservation['customer_name'] ?? '?'),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      reservation['customer_name'] ?? 'N/A',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: _darkBg,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Builder(
                                      builder: (context) {
                                        final email = (reservation['customer_email'] ?? '').toString().trim();
                                        final displayEmail = (email.isEmpty || email.toLowerCase() == 'n/a' || email.startsWith('walkin_'))
                                            ? 'N/A'
                                            : email;
                                        return Text(
                                          displayEmail,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            color: _slate,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Info chips
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _infoChip(Icons.calendar_today_rounded,
                                  _formatReadableDate(reservation['event_date']?.toString() ?? '')),
                              _infoChip(Icons.access_time_rounded,
                                  _formatReadableTime(reservation['start_time']?.toString() ?? '')),
                              _infoChip(Icons.people_rounded,
                                  '${reservation['number_of_guests'] ?? 0} guests'),
                              _infoChip(
                                Icons.admin_panel_settings_outlined,
                                reservation['transacted_by'] != null && reservation['transacted_by'].toString().isNotEmpty
                                    ? 'Admin: ${reservation['transacted_by']}'
                                    : 'Admin: Pending',
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Divider(height: 1, thickness: 1, color: _slateLight.withValues(alpha: 0.8)),
                          const SizedBox(height: 10),
                          // Footer — price + actions
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: (totalPrice != null && (totalPrice as num) > 0)
                                    ? Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '₱${totalPrice.toStringAsFixed(0)}',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w900,
                                              color: _emerald,
                                            ),
                                          ),
                                          Text(
                                            _getPaymentStatusText(paymentStatus),
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 10,
                                              color: _slate,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      )
                                    : Text(
                                        'Price Pending',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                          color: const Color(0xFF94A3B8),
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 8),
                              _buildCompactActionButtons(reservation),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: _slate),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _darkBg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.event_available_rounded, size: 52, color: _gold),
            ),
            const SizedBox(height: 18),
            Text(
              'No Reservations Found',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _darkBg,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'There are no reservations matching the selected filter.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: _slate,
                height: 1.5,
              ),
            ),
            if (_selectedFilter != 'all') ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => setState(() => _selectedFilter = 'all'),
                icon: const Icon(Icons.clear_all_rounded, size: 18),
                label: Text('Clear Filter', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _emerald,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showConfirmReservationDialog(Map<String, dynamic> reservation) {
    String reservationId = reservation['id'];
    String eventType = reservation['event_type'];
    final isMobile = ResponsiveUtils.isMobile(context);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: EdgeInsets.all(isMobile ? 16 : 24),
        title: Row(
          children: [
            Icon(
              Icons.check_circle, 
              color: Colors.green,
              size: ResponsiveUtils.getResponsiveIconSize(context),
            ),
            SizedBox(width: isMobile ? 8 : 12),
            Expanded(
              child: Text(
                'Confirm Reservation',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getResponsiveFontSize(
                    context,
                    mobile: 16,
                    tablet: 18,
                    desktop: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to confirm "$eventType" reservation?',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 14,
                  tablet: 16,
                  desktop: 16,
                ),
              ),
            ),
            ResponsiveUtils.verticalSpace(context, mobile: 8, tablet: 10, desktop: 12),
            Text(
              'This will notify the customer that their reservation has been confirmed.',
              style: TextStyle(
                color: Colors.green,
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 12,
                  tablet: 13,
                  desktop: 14,
                ),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 14,
                  tablet: 15,
                  desktop: 16,
                ),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 24,
                vertical: isMobile ? 8 : 12,
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              _updateReservationStatus(reservationId, 'confirmed', reservation);
            },
            child: Text(
              'Confirm',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 14,
                  tablet: 15,
                  desktop: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(String reservationId, String eventType, {bool isArchived = false}) {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: EdgeInsets.all(isMobile ? 16 : 24),
        title: Row(
          children: [
            Icon(
              isArchived ? Icons.delete_forever : Icons.archive, 
              color: isArchived ? Colors.red : Colors.orange,
              size: ResponsiveUtils.getResponsiveIconSize(context),
            ),
            SizedBox(width: isMobile ? 8 : 12),
            Expanded(
              child: Text(
                isArchived ? 'Permanent Delete' : 'Archive Reservation',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getResponsiveFontSize(
                    context,
                    mobile: 16,
                    tablet: 18,
                    desktop: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isArchived 
                ? 'Are you sure you want to permanently delete "$eventType"?' 
                : 'Move "$eventType" reservation to archive?',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 14,
                  tablet: 16,
                  desktop: 16,
                ),
              ),
            ),
            ResponsiveUtils.verticalSpace(context, mobile: 8, tablet: 10, desktop: 12),
            Text(
              isArchived 
                ? 'This action CANNOT be undone. All data will be lost.' 
                : 'It will be removed from your active list but can be recovered from the Archive section.',
              style: TextStyle(
                color: isArchived ? Colors.red : AppTheme.mediumGrey,
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 12,
                  tablet: 13,
                  desktop: 14,
                ),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 14,
                  tablet: 15,
                  desktop: 16,
                ),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isArchived ? Colors.red : AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 24,
                vertical: isMobile ? 8 : 12,
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              if (isArchived) {
                _hardDeleteReservation(reservationId);
              } else {
                _archiveReservation(reservationId);
              }
            },
            child: Text(
              isArchived ? 'Delete Permanently' : 'Archive',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 14,
                  tablet: 15,
                  desktop: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildCompactStatusChip(String status) {
    Color color;
    IconData icon;
    String label = status.toUpperCase();
    switch (status) {
      case 'pending':   color = const Color(0xFFD97706); icon = Icons.hourglass_top_rounded; break;
      case 'confirmed': color = const Color(0xFF15803D); icon = Icons.check_circle_rounded;  break;
      case 'completed': color = const Color(0xFF0284C7); icon = Icons.done_all_rounded;       break;
      case 'cancelled': color = const Color(0xFFDC2626); icon = Icons.cancel_rounded;         break;
      case 'no_show':   color = const Color(0xFFEA580C); icon = Icons.person_off_rounded; label = 'NO-SHOW'; break;
      case 'expired':   color = const Color(0xFF9333EA); icon = Icons.timer_off_rounded; label = 'EXPIRED'; break;
      default:          color = _slate;                  icon = Icons.help_outline_rounded;
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 9,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactActionButtons(Map<String, dynamic> reservation) {
    final String status = (reservation['status'] ?? 'pending').toString().toLowerCase();
    final String reservationId = reservation['id'];
    final bool isArchived = reservation['is_archived'] == true;
    final bool priceQuotationSent = reservation['price_quotation_sent'] == true;
    final bool reminderSent = reservation['reminder_sent'] == true;

    // 1. Primary contextual quick action
    Widget primaryAction;
    if (_isMaintenance) {
      primaryAction = _buildCompactActionButton(
        icon: Icons.visibility_rounded,
        color: const Color(0xFF0284C7),
        tooltip: 'View Details (Read-only during maintenance)',
        onPressed: () => _showViewReservationDialog(reservation),
      );
    } else if (isArchived) {
      primaryAction = _buildCompactActionButton(
        icon: Icons.restore_rounded,
        color: const Color(0xFF15803D),
        tooltip: 'Restore Reservation',
        onPressed: () => _restoreReservation(reservationId),
      );
    } else if (status == 'pending') {
      if (priceQuotationSent) {
        primaryAction = _buildCompactActionButton(
          icon: Icons.check_circle_rounded,
          color: const Color(0xFF15803D),
          tooltip: 'Confirm Reservation',
          onPressed: () => _showConfirmReservationDialog(reservation),
        );
      } else {
        primaryAction = _buildCompactActionButton(
          icon: Icons.request_quote_rounded,
          color: const Color(0xFF7C3AED),
          tooltip: 'Send Price Quotation',
          onPressed: () => _showPriceQuotationDialog(reservation),
        );
      }
    } else if (status == 'no_show') {
      primaryAction = _buildCompactActionButton(
        icon: Icons.restore_page_rounded,
        color: const Color(0xFF15803D),
        tooltip: 'Mark Arrived / Revert',
        onPressed: () => _showRevertNoShowConfirmationDialog(reservationId, reservation),
      );
    } else {
      // confirmed, completed, cancelled, expired, etc.
      primaryAction = _buildCompactActionButton(
        icon: Icons.visibility_rounded,
        color: const Color(0xFF0284C7),
        tooltip: 'View Details',
        onPressed: () => _showViewReservationDialog(reservation),
      );
    }

    // 2. 3-Dots PopupMenu for all secondary and management actions
    Widget moreActionsMenu = PopupMenuButton<String>(
      tooltip: 'More Actions',
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      shadowColor: Colors.black26,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      offset: const Offset(0, 36),
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: const Icon(Icons.more_horiz_rounded, size: 15, color: Color(0xFF475569)),
      ),
      onSelected: (action) {
        if (_isMaintenance && action != 'view') {
          _showMaintenanceActionBlockedSnackbar('Modifying or confirming reservations');
          return;
        }
        switch (action) {
          case 'view':
            _showViewReservationDialog(reservation);
            break;
          case 'price':
            _showPriceQuotationDialog(reservation);
            break;
          case 'confirm':
            _showConfirmReservationDialog(reservation);
            break;
          case 'reminder':
            _sendReminderEmail(reservation);
            break;
          case 'reliability':
            _showCustomerReliabilityDialog(reservation);
            break;
          case 'no_show':
            _showMarkNoShowConfirmationDialog(reservationId, reservation);
            break;
          case 'revert_no_show':
            _showRevertNoShowConfirmationDialog(reservationId, reservation);
            break;
          case 'restore':
            _restoreReservation(reservationId);
            break;
          case 'cancel':
            _updateReservationStatus(reservationId, 'cancelled', reservation);
            break;
          case 'archive':
            _showDeleteConfirmationDialog(reservationId, reservation['event_type'], isArchived: isArchived);
            break;
        }
      },
      itemBuilder: (context) {
        final List<PopupMenuEntry<String>> items = [];

        // View Full Details
        items.add(_buildPopupMenuItem(
          value: 'view',
          icon: Icons.visibility_outlined,
          color: const Color(0xFF0284C7),
          label: 'View Full Details',
        ));

        // Price quotation
        if (!isArchived && status == 'pending') {
          items.add(_buildPopupMenuItem(
            value: 'price',
            icon: Icons.request_quote_outlined,
            color: const Color(0xFF7C3AED),
            label: priceQuotationSent ? 'Update Quotation' : 'Send Price Quotation',
          ));
        }

        // Confirm
        if (!isArchived && status == 'pending' && priceQuotationSent) {
          items.add(_buildPopupMenuItem(
            value: 'confirm',
            icon: Icons.check_circle_outline_rounded,
            color: const Color(0xFF15803D),
            label: 'Confirm Reservation',
          ));
        }

        // Send / Resend Reminder
        if (!isArchived && (status == 'pending' || status == 'confirmed' || status == 'approved')) {
          items.add(_buildPopupMenuItem(
            value: 'reminder',
            icon: reminderSent ? Icons.mark_email_read_outlined : Icons.email_outlined,
            color: reminderSent ? const Color(0xFF059669) : const Color(0xFF7C3AED),
            label: reminderSent ? 'Resend Reminder' : 'Send Reminder Email',
          ));
        }

        // Customer Reliability & Shield
        items.add(_buildPopupMenuItem(
          value: 'reliability',
          icon: Icons.shield_outlined,
          color: const Color(0xFFD97706),
          label: 'Customer Reliability & Shield',
        ));

        // Mark as No-Show
        if (!isArchived && status == 'confirmed') {
          items.add(_buildPopupMenuItem(
            value: 'no_show',
            icon: Icons.person_off_outlined,
            color: const Color(0xFFEA580C),
            label: 'Mark as No-Show',
          ));
        }

        // Revert No-Show
        if (!isArchived && status == 'no_show') {
          items.add(_buildPopupMenuItem(
            value: 'revert_no_show',
            icon: Icons.restore_page_outlined,
            color: const Color(0xFF15803D),
            label: 'Mark Arrived / Revert',
          ));
        }

        // Restore
        if (isArchived) {
          items.add(_buildPopupMenuItem(
            value: 'restore',
            icon: Icons.restore_rounded,
            color: const Color(0xFF15803D),
            label: 'Restore Reservation',
          ));
        }

        // Cancel Reservation (Destructive)
        if (!isArchived && (status == 'pending' || status == 'confirmed')) {
          items.add(const PopupMenuDivider(height: 8));
          items.add(_buildPopupMenuItem(
            value: 'cancel',
            icon: Icons.cancel_outlined,
            color: const Color(0xFFDC2626),
            label: 'Cancel Reservation',
            isDestructive: true,
          ));
        }

        // Archive / Delete
        if (isArchived || status == 'cancelled' || status == 'completed' || status == 'no_show' || status == 'expired') {
          if (!items.any((it) => it is PopupMenuDivider)) {
            items.add(const PopupMenuDivider(height: 8));
          }
          items.add(_buildPopupMenuItem(
            value: 'archive',
            icon: isArchived ? Icons.delete_forever_outlined : Icons.archive_outlined,
            color: isArchived ? const Color(0xFFDC2626) : const Color(0xFF64748B),
            label: isArchived ? 'Delete Permanently' : 'Archive Reservation',
            isDestructive: isArchived,
          ));
        }

        return items;
      },
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        primaryAction,
        moreActionsMenu,
      ],
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem({
    required String value,
    required IconData icon,
    required Color color,
    required String label,
    bool isDestructive = false,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 38,
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: isDestructive ? FontWeight.w700 : FontWeight.w600,
                color: isDestructive ? const Color(0xFFDC2626) : const Color(0xFF1E293B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Send or resend a reminder email for a reservation
  Future<void> _sendReminderEmail(Map<String, dynamic> reservation) async {
    final reservationId = reservation['id'] as String;
    final customerName = reservation['customer_name'] ?? 'Customer';
    final eventType = reservation['event_type'] ?? 'Reservation';
    final reminderAlreadySent = reservation['reminder_sent'] == true;
    final emailService = EmailNotificationService();
    final isMobile = ResponsiveUtils.isMobile(context);

    // Show confirmation dialog
    final shouldSend = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              reminderAlreadySent ? Icons.mark_email_read_outlined : Icons.email_outlined,
              color: reminderAlreadySent ? const Color(0xFF059669) : const Color(0xFF7C3AED),
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                reminderAlreadySent ? 'Resend Reminder' : 'Send Reminder',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: isMobile ? 16 : 18,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reminderAlreadySent
                  ? 'Resend a reminder email to $customerName about their "$eventType"?'
                  : 'Send a reminder email to $customerName about their "$eventType"?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE9E5FF)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFF7C3AED), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The customer will receive an email reminder about their reservation at their registered email address.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF5B21B6),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: Text(
              reminderAlreadySent ? 'Resend' : 'Send',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (shouldSend != true) return;

    // Reset flag if resending
    if (reminderAlreadySent) {
      await emailService.resetReminderFlag(reservationId: reservationId);
    }

    // Determine if this is an advance order or event reservation
    final isAdvanceOrder = (eventType).toString().toLowerCase().contains('advance order');
    
    bool success;
    if (isAdvanceOrder) {
      success = await emailService.sendAdvanceOrderReminderEmail(advanceOrderId: reservationId);
    } else {
      success = await emailService.sendEventReminderEmail(reservationId: reservationId);
    }

    if (!mounted) return;

    if (success) {
      _showSnackBar('✅ Reminder email sent to $customerName successfully!', const Color(0xFF059669));
      _loadReservations(); // Refresh to update reminder_sent status
    } else {
      _showSnackBar('❌ Failed to send reminder email. Please try again.', Colors.red);
    }
  }

  void _showMarkNoShowConfirmationDialog(String reservationId, Map<String, dynamic> reservation) {
    final customerName = reservation['customer_name'] ?? 'Customer';
    final eventType = reservation['event_type'] ?? 'Reservation';
    final isMobile = ResponsiveUtils.isMobile(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.person_off_rounded, color: Color(0xFFEA580C), size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Mark as No-Show',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: isMobile ? 16 : 18,
                  color: _darkBg,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Did $customerName fail to show up for "$eventType"?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _darkBg,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFEDD5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFFEA580C), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will flag the reservation as "No-Show" and update the customer\'s reliability record for future bookings.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF9A3412),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: _slate,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA580C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () {
              Navigator.pop(context);
              _updateReservationStatus(reservationId, 'no_show', reservation);
            },
            child: Text(
              'Confirm No-Show',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRevertNoShowConfirmationDialog(String reservationId, Map<String, dynamic> reservation) {
    final customerName = reservation['customer_name'] ?? 'Customer';
    final eventType = reservation['event_type'] ?? 'Reservation';
    final isMobile = ResponsiveUtils.isMobile(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF15803D), size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Customer Arrived / Revert',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: isMobile ? 16 : 18,
                  color: _darkBg,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Did $customerName arrive for "$eventType" or was marked as No-Show by mistake?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _darkBg,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.verified_user_rounded, color: Color(0xFF15803D), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will restore the booking to "Confirmed" and remove the No-Show penalty from the customer\'s profile.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF166534),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: _slate,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF15803D),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () {
              Navigator.pop(context);
              _updateReservationStatus(reservationId, 'confirmed', reservation);
            },
            child: Text(
              'Mark as Arrived (Revert)',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 4.0),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          hoverColor: color.withValues(alpha: 0.1),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
        ),
      ),
    );
  }

  void _showPriceQuotationDialog(Map<String, dynamic> reservation) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PriceQuotationDialog(reservation: reservation),
    ).then((result) {
      if (result == true) {
        _loadReservations(); // Refresh the list after sending quotation
      }
    });
  }

  Widget _buildQuotationCountdownChip(dynamic expiresAtRaw) {
    if (expiresAtRaw == null) return const SizedBox.shrink();
    DateTime? expiresAt = DateTime.tryParse(expiresAtRaw.toString())?.toLocal();
    if (expiresAt == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final difference = expiresAt.difference(now);
    final isExpired = difference.isNegative;

    final String text;
    final Color textColor;
    final Color bgColor;
    final Color borderColor;

    if (isExpired) {
      text = 'Expired';
      textColor = const Color(0xFFDC2626);
      bgColor = const Color(0xFFFEE2E2);
      borderColor = const Color(0xFFFCA5A5);
    } else {
      final hours = difference.inHours;
      final minutes = difference.inMinutes % 60;
      if (hours >= 24) {
        final days = (hours / 24).floor();
        text = '${days}d ${hours % 24}h left';
      } else if (hours > 0) {
        text = '${hours}h ${minutes}m left';
      } else {
        text = '${minutes}m left';
      }
      textColor = const Color(0xFFB45309);
      bgColor = const Color(0xFFFEF3C7);
      borderColor = const Color(0xFFFDE68A);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: 10, color: textColor),
          const SizedBox(width: 3),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomerReliabilityDialog(Map<String, dynamic> reservation) {
    final customerName = reservation['customer_name']?.toString() ?? 'Customer';
    final customerEmail = reservation['customer_email']?.toString() ?? '';
    final userId = reservation['user_id']?.toString();
    final isMobile = ResponsiveUtils.isMobile(context);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return FutureBuilder<Map<String, dynamic>>(
          future: _reservationService.getCustomerReliabilityInfo(
            userId: userId,
            email: customerEmail,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                content: const SizedBox(
                  height: 150,
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              );
            }

            final data = snapshot.data ?? {};
            final restrictionStatus = (data['restriction_status'] ?? 'active').toString().toLowerCase();
            final isRestricted = data['is_restricted'] == true;
            final warningCount = data['warning_count'] as int? ?? 0;
            final restrictionReason = data['restriction_reason']?.toString() ?? '';
            final restrictionEnd = data['restriction_end'] as DateTime?;
            final restrictedBy = data['restricted_by']?.toString();

            final total = data['total'] ?? 0;
            final completed = data['completed'] ?? 0;
            final confirmed = data['confirmed'] ?? 0;
            final active = data['active'] ?? 0;
            final cancelled = data['cancelled'] ?? 0;
            final expired = data['expired'] ?? 0;
            final unpaidQuotes = data['unpaid_quotations'] ?? 0;
            final noShows = data['no_shows'] ?? 0;

            final totalClosed = completed + confirmed + cancelled + expired + noShows;
            final reliabilityRate = totalClosed > 0
                ? (((completed + confirmed) / totalClosed) * 100).clamp(0, 100).toStringAsFixed(1)
                : '100.0';

            final isHighRisk = noShows > 0 || expired >= 2 || cancelled >= 3 || isRestricted;

            Color statusBadgeColor = const Color(0xFF15803D);
            String statusBadgeLabel = 'GOOD STANDING';
            IconData statusBadgeIcon = Icons.verified_user_rounded;

            if (isRestricted) {
              statusBadgeColor = const Color(0xFFDC2626);
              statusBadgeLabel = restrictionStatus == 'blocked' || restrictionStatus == 'suspended'
                  ? 'ACCOUNT BLOCKED'
                  : 'TEMPORARILY RESTRICTED';
              statusBadgeIcon = Icons.lock_rounded;
            } else if (warningCount > 0 || restrictionStatus == 'warning') {
              statusBadgeColor = const Color(0xFFD97706);
              statusBadgeLabel = 'WARNING ISSUED ($warningCount)';
              statusBadgeIcon = Icons.warning_amber_rounded;
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shield_outlined, color: Color(0xFF0F172A), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Customer Reliability & Controls',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: isMobile ? 16 : 18,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '$customerName • $customerEmail',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _slate,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusBadgeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusBadgeColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusBadgeIcon, size: 12, color: statusBadgeColor),
                        const SizedBox(width: 5),
                        Text(
                          statusBadgeLabel,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: statusBadgeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Alert banner if restricted or high risk
                      if (isRestricted) ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.lock_clock_rounded, color: Color(0xFFDC2626), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      restrictionEnd != null
                                          ? 'Restricted until ${DateFormat('MMM dd, yyyy - hh:mm a').format(restrictionEnd)}'
                                          : 'Permanently Blocked / Indefinite Restriction',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF991B1B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (restrictionReason.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Reason: $restrictionReason${restrictedBy != null ? ' (by $restrictedBy)' : ''}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: const Color(0xFFB91C1C),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ] else if (isHighRisk) ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'High Cancellation / Abandonment Pattern. Customer has previous cancellations, expired quotations, or warnings.',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF92400E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Grid of Reliability Metrics
                      Text(
                        'Booking Reliability Breakdown',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildMetricTile('Total Bookings', '$total', Icons.calendar_today_rounded, const Color(0xFF0F172A)),
                          _buildMetricTile('Completed', '$completed', Icons.done_all_rounded, const Color(0xFF15803D)),
                          _buildMetricTile('Confirmed', '$confirmed', Icons.check_circle_rounded, const Color(0xFF0284C7)),
                          _buildMetricTile('Active/Pending', '$active', Icons.hourglass_top_rounded, const Color(0xFF0891B2)),
                          _buildMetricTile('Cancelled', '$cancelled', Icons.cancel_rounded, const Color(0xFFDC2626)),
                          _buildMetricTile('Expired Quotes', '$expired', Icons.timer_off_rounded, const Color(0xFF9333EA)),
                          _buildMetricTile('Unpaid Quotes', '$unpaidQuotes', Icons.receipt_long_rounded, const Color(0xFFD97706)),
                          _buildMetricTile('No-Shows', '$noShows', Icons.person_off_rounded, const Color(0xFFEA580C)),
                          _buildMetricTile('Reliability Rate', '$reliabilityRate%', Icons.speed_rounded, const Color(0xFF059669)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Audit & History link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              _showCustomerRestrictionsHistoryDialog(customerName, userId, customerEmail);
                            },
                            icon: const Icon(Icons.history_rounded, size: 16),
                            label: Text(
                              'View Restriction Audit History',
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                // Issue Warning button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD97706),
                    side: const BorderSide(color: Color(0xFFFDE68A)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.warning_amber_rounded, size: 16),
                  label: Text('Issue Warning', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _showIssueWarningDialog(customerName, userId, customerEmail, () {
                      _loadReservations();
                    });
                  },
                ),
                // Restrict or Unrestrict button
                if (isRestricted || warningCount > 0) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF15803D),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.lock_open_rounded, size: 16),
                    label: Text(
                      isRestricted ? 'Lift Restriction' : 'Clear Warning',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                    ),
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      _showUnrestrictDialog(customerName, userId, customerEmail, () {
                        _loadReservations();
                      });
                    },
                  ),
                ],
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.lock_outline_rounded, size: 16),
                  label: Text('Restrict Account', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _showRestrictAccountDialog(customerName, userId, customerEmail, () {
                      _loadReservations();
                    });
                  },
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('Close', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: _slate)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMetricTile(String title, String value, IconData icon, Color color) {
    return Container(
      width: 126,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showIssueWarningDialog(String customerName, String? userId, String? email, VoidCallback onUpdated) {
    final reasonController = TextEditingController(text: 'Customer has unresponsive quotations or repeated unconfirmed bookings.');
    bool sendEmail = true;

    final quickReasons = [
      'Unresponsive to price quotation',
      'Repeated booking cancellations',
      'No-show for scheduled event date',
      'Submitting speculative/spam bookings',
    ];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Issue Warning to $customerName',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This warning will be recorded on the customer account. Further non-compliance can trigger temporary booking restrictions.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: _slate,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Quick Reasons:',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _slate,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: quickReasons.map((r) {
                    return ActionChip(
                      label: Text(r, style: GoogleFonts.plusJakartaSans(fontSize: 11)),
                      backgroundColor: const Color(0xFFF1F5F9),
                      onPressed: () {
                        setDialogState(() {
                          reasonController.text = r;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Reason for Warning',
                    labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    'Send email notification to customer',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  value: sendEmail,
                  activeColor: const Color(0xFFD97706),
                  onChanged: (val) => setDialogState(() => sendEmail = val ?? true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: _slate, fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  _showSnackBar('Please enter a reason for the warning.', Colors.red);
                  return;
                }
                Navigator.pop(dialogContext);

                final currentAdmin = Supabase.instance.client.auth.currentUser;
                final adminName = (currentAdmin?.userMetadata?['full_name'] as String?) ??
                    (currentAdmin?.email != null ? currentAdmin!.email!.split('@').first : 'Admin');

                final success = await _reservationService.issueCustomerWarning(
                  userId: userId,
                  email: email,
                  customerName: customerName,
                  reason: reason,
                  adminName: adminName,
                  sendEmail: sendEmail,
                );

                if (success) {
                  _showSnackBar('Warning successfully issued to $customerName.', Colors.green);
                  onUpdated();
                } else {
                  _showSnackBar('Failed to issue warning. Check database logs.', Colors.red);
                }
              },
              child: Text('Issue Warning', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  void _showRestrictAccountDialog(String customerName, String? userId, String? email, VoidCallback onUpdated) {
    String restrictionType = 'temporarily_restricted';
    dynamic selectedDuration = '24_hours';
    String selectedDurationLabel = '24 Hours';
    final reasonController = TextEditingController(text: 'Multiple expired quotations or unverified repeated bookings.');
    bool sendEmail = true;

    final quickReasons = [
      'Repeated unconfirmed bookings',
      'No-show on scheduled event date',
      'Unresponsive to price quotations',
      'Abusive behavior towards staff',
      'Spam reservation attempts',
    ];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.lock_outline_rounded, color: Color(0xFFDC2626), size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Restrict Account: $customerName',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Restricting this account will prevent them from creating new event bookings or reservations.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _slate),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Restriction Type:',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: restrictionType,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'temporarily_restricted', child: Text('Temporarily Restricted')),
                      DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                      DropdownMenuItem(value: 'blocked', child: Text('Permanently Blocked')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => restrictionType = val);
                    },
                  ),
                  if (restrictionType != 'blocked') ...[
                    const SizedBox(height: 12),
                    Text(
                      'Duration:',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: _slate),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedDurationLabel,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: const [
                        DropdownMenuItem(value: '24 Hours', child: Text('24 Hours')),
                        DropdownMenuItem(value: '3 Days', child: Text('3 Days')),
                        DropdownMenuItem(value: '7 Days', child: Text('7 Days (1 Week)')),
                        DropdownMenuItem(value: '14 Days', child: Text('14 Days (2 Weeks)')),
                        DropdownMenuItem(value: '30 Days', child: Text('30 Days (1 Month)')),
                        DropdownMenuItem(value: 'Indefinite', child: Text('Indefinite (Until manually lifted)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedDurationLabel = val;
                            if (val == '24 Hours') selectedDuration = '24_hours';
                            else if (val == '3 Days') selectedDuration = '3_days';
                            else if (val == '7 Days') selectedDuration = '7_days';
                            else if (val == '14 Days') selectedDuration = '14_days';
                            else if (val == '30 Days') selectedDuration = '30_days';
                            else selectedDuration = null;
                          });
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'Quick Reasons:',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: _slate),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: quickReasons.map((r) {
                      return ActionChip(
                        label: Text(r, style: GoogleFonts.plusJakartaSans(fontSize: 11)),
                        backgroundColor: const Color(0xFFF1F5F9),
                        onPressed: () => setDialogState(() => reasonController.text = r),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    style: GoogleFonts.plusJakartaSans(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Reason for Restriction',
                      labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      'Send email notification to customer',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    value: sendEmail,
                    activeColor: const Color(0xFFDC2626),
                    onChanged: (val) => setDialogState(() => sendEmail = val ?? true),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: _slate, fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  _showSnackBar('Please enter a reason for the restriction.', Colors.red);
                  return;
                }
                Navigator.pop(dialogContext);

                final currentAdmin = Supabase.instance.client.auth.currentUser;
                final adminName = (currentAdmin?.userMetadata?['full_name'] as String?) ??
                    (currentAdmin?.email != null ? currentAdmin!.email!.split('@').first : 'Admin');

                final success = await _reservationService.restrictCustomerAccount(
                  userId: userId,
                  email: email,
                  customerName: customerName,
                  restrictionType: restrictionType,
                  duration: restrictionType == 'blocked' || selectedDurationLabel == 'Indefinite'
                      ? null
                      : selectedDuration,
                  reason: reason,
                  adminName: adminName,
                  sendEmail: sendEmail,
                );

                if (success) {
                  _showSnackBar('Customer account restricted successfully.', Colors.green);
                  onUpdated();
                } else {
                  _showSnackBar('Failed to restrict account. Check database logs.', Colors.red);
                }
              },
              child: Text('Apply Restriction', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  void _showUnrestrictDialog(String customerName, String? userId, String? email, VoidCallback onUpdated) {
    final noteController = TextEditingController(text: 'Admin approved account clearance.');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.lock_open_rounded, color: Color(0xFF15803D), size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Lift Restrictions / Clear Warnings for $customerName',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will reset warnings to 0, lift any active restrictions, and return the customer account to good standing.',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _slate),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: noteController,
                style: GoogleFonts.plusJakartaSans(fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Clearance Note / Remarks',
                  labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: _slate, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF15803D),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);

              final currentAdmin = Supabase.instance.client.auth.currentUser;
              final adminName = (currentAdmin?.userMetadata?['full_name'] as String?) ??
                  (currentAdmin?.email != null ? currentAdmin!.email!.split('@').first : 'Admin');

              final success = await _reservationService.unrestrictCustomerAccount(
                userId: userId,
                email: email,
                customerName: customerName,
                reason: noteController.text.trim(),
                adminName: adminName,
              );

              if (success) {
                _showSnackBar('Restrictions lifted and warnings cleared for $customerName.', Colors.green);
                onUpdated();
              } else {
                _showSnackBar('Failed to lift restrictions. Check database logs.', Colors.red);
              }
            },
            child: Text('Confirm & Lift', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showCustomerRestrictionsHistoryDialog(String customerName, String? userId, String? email) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.history_rounded, color: Color(0xFF0F172A), size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Restriction History: $customerName',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          height: 380,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _reservationService.getCustomerRestrictionsHistory(userId: userId, email: email),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final history = snapshot.data ?? [];
              if (history.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_outlined, size: 48, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 8),
                      Text(
                        'No restriction or warning events recorded.',
                        style: GoogleFonts.plusJakartaSans(color: _slate, fontSize: 13),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                itemCount: history.length,
                separatorBuilder: (_, __) => const Divider(height: 16),
                itemBuilder: (context, i) {
                  final item = history[i];
                  final action = (item['action'] ?? '').toString();
                  final reason = item['reason'] ?? 'No reason provided';
                  final admin = item['admin_name'] ?? 'Admin';
                  final createdAtStr = item['created_at']?.toString();
                  DateTime? createdAt = createdAtStr != null ? DateTime.tryParse(createdAtStr)?.toLocal() : null;

                  Color actionColor = const Color(0xFF0F172A);
                  IconData actionIcon = Icons.info_outline;

                  if (action.contains('WARNING')) {
                    actionColor = const Color(0xFFD97706);
                    actionIcon = Icons.warning_amber_rounded;
                  } else if (action.contains('RESTRICT') || action.contains('BLOCK')) {
                    actionColor = const Color(0xFFDC2626);
                    actionIcon = Icons.lock_outline_rounded;
                  } else if (action.contains('UNRESTRICT') || action.contains('LIFT')) {
                    actionColor = const Color(0xFF15803D);
                    actionIcon = Icons.lock_open_rounded;
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: actionColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(actionIcon, size: 16, color: actionColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  action,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: actionColor,
                                  ),
                                ),
                                if (createdAt != null)
                                  Text(
                                    DateFormat('MMM dd, yyyy hh:mm a').format(createdAt),
                                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _slate),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              reason,
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF334155)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'By: $admin',
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _slate, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Close', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: _slate)),
          ),
        ],
      ),
    );
  }

  Future<String?> _resolveCustomerUploadedId(String email, String? directIdUrl) async {
    if (directIdUrl != null && directIdUrl.isNotEmpty && directIdUrl != 'null') {
      return directIdUrl;
    }
    final trimmedEmail = email.trim().toLowerCase();
    if (trimmedEmail.isEmpty) return null;

    // Check local loaded list first
    for (final r in reservations) {
      if ((r['customer_email'] ?? '').toString().trim().toLowerCase() == trimmedEmail) {
        final id = r['uploaded_id_url']?.toString();
        if (id != null && id.isNotEmpty && id != 'null') {
          return id;
        }
      }
    }

    try {
      final res = await Supabase.instance.client
          .from('reservations')
          .select('uploaded_id_url')
          .or('customer_email.eq.$email,customer_email.eq.$trimmedEmail')
          .not('uploaded_id_url', 'is', null)
          .order('created_at', ascending: false)
          .limit(1);
      if (res.isNotEmpty && res[0]['uploaded_id_url'] != null) {
        final url = res[0]['uploaded_id_url'].toString();
        if (url.isNotEmpty && url != 'null') return url;
      }
    } catch (_) {}
    return null;
  }

  void _showViewReservationDialog(Map<String, dynamic> reservation) {
    final status = reservation['status'];
    final isPending = status == 'pending';
    final isMobile = ResponsiveUtils.isMobile(context);
    final needsPricing = _reservationService.needsPricing(reservation);
    final priceQuotationSent = reservation['price_quotation_sent'] == true;

    final customerEmail = (reservation['customer_email'] ?? '').toString().trim().toLowerCase();
    final customerHistory = reservations.where((r) => (r['customer_email'] ?? '').toString().trim().toLowerCase() == customerEmail).toList();
    final noShowCount = customerHistory.where((r) => (r['status'] ?? '').toString().toLowerCase() == 'no_show').length;
    final completedCount = customerHistory.where((r) => (r['status'] ?? '').toString().toLowerCase() == 'completed').length;

    Widget buildDetailRow(String label, String value, {IconData? icon}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
            ],
            SizedBox(
              width: 120,
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(color: AppTheme.darkGrey),
              ),
            ),
          ],
        ),
      );
    }


    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Container(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 540),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Modal banner header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_emerald, const Color(0xFF1E4A42)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(22),
                    topRight: Radius.circular(22),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'RESERVATION DETAILS',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _gold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 18),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      reservation['event_type'] ?? 'Unknown Event',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildCompactStatusChip((status ?? 'pending').toString().toLowerCase()),
                        const SizedBox(width: 8),
                        Text(
                          _formatReadableDate(reservation['event_date']?.toString() ?? ''),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('•', style: TextStyle(color: Colors.white38)),
                        const SizedBox(width: 6),
                        Text(
                          _formatReadableTime(reservation['start_time']?.toString() ?? ''),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Customer section
                      _modalSectionTitle('CUSTOMER INFORMATION'),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _slateLight),
                        ),
                        child: Column(
                          children: [
                            buildDetailRow('Name',  reservation['customer_name']  ?? 'N/A', icon: Icons.person_rounded),
                            buildDetailRow(
                              'Email',
                              (reservation['customer_email'] == null ||
                                      reservation['customer_email'].toString().trim().isEmpty ||
                                      reservation['customer_email'].toString().trim().toLowerCase() == 'n/a' ||
                                      reservation['customer_email'].toString().startsWith('walkin_'))
                                  ? 'N/A'
                                  : reservation['customer_email'].toString(),
                              icon: Icons.email_rounded,
                            ),
                            buildDetailRow('Phone', reservation['customer_phone'] ?? 'N/A', icon: Icons.phone_rounded),
                          ],
                        ),
                      ),

                      // Customer Reliability Banner
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: noShowCount >= 2
                              ? const Color(0xFFFEF2F2)
                              : (noShowCount == 1 ? const Color(0xFFFFFBEB) : const Color(0xFFF0FDF4)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: noShowCount >= 2
                                ? const Color(0xFFFECACA)
                                : (noShowCount == 1 ? const Color(0xFFFDE68A) : const Color(0xFFBBF7D0)),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              noShowCount >= 2
                                  ? Icons.warning_amber_rounded
                                  : (noShowCount == 1 ? Icons.info_outline_rounded : Icons.verified_user_rounded),
                              color: noShowCount >= 2
                                  ? const Color(0xFFDC2626)
                                  : (noShowCount == 1 ? const Color(0xFFD97706) : const Color(0xFF16A34A)),
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    noShowCount >= 2
                                        ? 'HIGH-RISK CUSTOMER (NO-SHOW ALERT)'
                                        : (noShowCount == 1 ? 'CUSTOMER CAUTION' : 'RELIABLE CUSTOMER'),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: noShowCount >= 2
                                          ? const Color(0xFFB91C1C)
                                          : (noShowCount == 1 ? const Color(0xFFB45309) : const Color(0xFF15803D)),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    noShowCount >= 2
                                        ? 'This customer has $noShowCount missed booking(s) (No-Show). Strict 100% full advance payment is advised before approval.'
                                        : (noShowCount == 1
                                            ? 'This customer missed 1 past booking (No-Show). Verify downpayment before confirming.'
                                            : 'Good standing with $completedCount completed event(s) and 0 no-shows.'),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      color: noShowCount >= 2
                                          ? const Color(0xFF991B1B)
                                          : (noShowCount == 1 ? const Color(0xFF92400E) : const Color(0xFF166534)),
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Event section
                      _modalSectionTitle('EVENT DETAILS'),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _slateLight),
                        ),
                        child: Column(
                          children: [
                            buildDetailRow('Event Type',   reservation['event_type']    ?? 'N/A', icon: Icons.celebration_rounded),
                            buildDetailRow('Date',         reservation['event_date']    ?? 'N/A', icon: Icons.calendar_today_rounded),
                            buildDetailRow('Start Time',   reservation['start_time']   ?? 'N/A', icon: Icons.access_time_rounded),
                            buildDetailRow('Guests',       '${reservation['number_of_guests'] ?? 0}', icon: Icons.people_rounded),
                            buildDetailRow('Table',        reservation['table_number']?.toString() ?? 'Unassigned', icon: Icons.table_restaurant_rounded),
                            buildDetailRow('Handled By',   reservation['transacted_by'] ?? 'Pending (Not yet handled)', icon: Icons.admin_panel_settings_rounded),
                            buildDetailRow('Status',       (status ?? 'N/A').toUpperCase(), icon: Icons.info_rounded),
                          ],
                        ),
                      ),

                      // Pricing section
                      if (reservation['total_price'] != null && (reservation['total_price'] as num) > 0) ...[
                        const SizedBox(height: 16),
                        _modalSectionTitle('PRICING & PAYMENT'),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _slateLight),
                          ),
                          child: Column(
                            children: [
                              buildDetailRow('Total Price',    '₱${(reservation['total_price'] as num).toStringAsFixed(2)}', icon: Icons.monetization_on_rounded),
                              buildDetailRow('Deposit (50%)',  '₱${(reservation['deposit_amount'] as num? ?? 0).toStringAsFixed(2)}', icon: Icons.account_balance_wallet_rounded),
                              Builder(
                                builder: (context) {
                                  final num totalPriceNum = (reservation['total_price'] as num?) ?? 0;
                                  final num depositNum = (reservation['deposit_amount'] as num?) ?? 0;
                                  final paymentStatus = (reservation['payment_status'] ?? 'unpaid').toString().toLowerCase();
                                  final isFullyPaid = paymentStatus == 'fully_paid' || paymentStatus == 'paid';
                                  final num? rawDbRem = reservation['remaining_balance'] as num?;
                                  final double remaining = isFullyPaid
                                      ? 0.0
                                      : (rawDbRem != null ? rawDbRem.toDouble() : (totalPriceNum - depositNum).clamp(0.0, double.infinity).toDouble());

                                  return buildDetailRow(
                                    'Remaining Balance',
                                    '₱${remaining.toStringAsFixed(2)}',
                                    icon: Icons.account_balance_wallet_outlined,
                                  );
                                },
                              ),
                              buildDetailRow('Payment Status', _getPaymentStatusText(reservation['payment_status'] as String? ?? 'unpaid'), icon: Icons.payment_rounded),
                              if (reservation['payment_option'] != null)
                                buildDetailRow('Payment Option', reservation['payment_option'] == 'full' ? 'Pay in Full (100%)' : '50% Downpayment', icon: Icons.pie_chart_outline_rounded),
                              if (reservation['payment_method'] != null)
                                buildDetailRow(
                                  'Payment Method',
                                  reservation['payment_method'] == 'cash'
                                      ? 'Cash on site'
                                      : (reservation['payment_method'] == 'gcash' ? 'Via GCash QR code' : 'Via PayMongo'),
                                  icon: reservation['payment_method'] == 'cash'
                                      ? Icons.payments_rounded
                                      : (reservation['payment_method'] == 'gcash' ? Icons.qr_code_scanner_rounded : Icons.credit_card_rounded),
                                ),
                              buildDetailRow('Quote Sent',     reservation['price_quotation_sent'] == true ? 'Yes' : 'No', icon: Icons.send_rounded),
                              if (reservation['price_quotation_sent'] == true &&
                                  (reservation['payment_status'] == null ||
                                      reservation['payment_status'] == 'unpaid' ||
                                      reservation['payment_status'] == 'pending')) ...[
                                Builder(
                                  builder: (context) {
                                    final isCash = reservation['payment_method'] == 'cash';
                                    final isAdvanceOrder = reservation['_db_table'] == 'advance_orders' || reservation['reservation_type'] == 'advance_order';
                                    final sentAtRaw = isCash
                                        ? (reservation['created_at'] ?? reservation['price_quotation_sent_at'])
                                        : (reservation['price_quotation_sent_at'] ?? reservation['created_at']);
                                    DateTime? sentAt;
                                    if (sentAtRaw != null) {
                                      sentAt = DateTime.tryParse(sentAtRaw.toString());
                                    }
                                    String graceText = 'Pending';
                                    if (sentAt != null) {
                                      final Duration graceDuration = isCash
                                          ? (isAdvanceOrder ? const Duration(hours: 24) : const Duration(days: 3))
                                          : const Duration(hours: 24);
                                      final expiry = sentAt.add(graceDuration);
                                      final now = DateTime.now();
                                      if (now.isAfter(expiry)) {
                                        graceText = isCash ? 'Expired (> 3 days)' : 'Expired (> 3 mins)';
                                      } else {
                                        final rem = expiry.difference(now);
                                        final days = rem.inDays;
                                        final hours = rem.inHours % 24;
                                        final mins = rem.inMinutes % 60;
                                        final secs = rem.inSeconds % 60;
                                        final timeStr = days > 0
                                            ? '${days}d ${hours}h'
                                            : (hours > 0 ? '${hours}h ${mins}m' : (mins > 0 ? '${mins}m ${secs}s' : '${secs}s'));
                                        graceText = 'Active ($timeStr left)';
                                      }
                                    }
                                    return buildDetailRow('Grace Period', graceText, icon: Icons.timer_outlined);
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],

                      // Uploaded ID
                      const SizedBox(height: 16),
                      _modalSectionTitle('VERIFICATION ID'),
                      const SizedBox(height: 10),
                      FutureBuilder<String?>(
                        future: _resolveCustomerUploadedId(
                          reservation['customer_email']?.toString() ?? '',
                          reservation['uploaded_id_url']?.toString(),
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Container(
                              height: 90,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _slateLight),
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: _emerald),
                                ),
                              ),
                            );
                          }

                          final idUrl = snapshot.data;
                          if (idUrl != null && idUrl.isNotEmpty && idUrl != 'null') {
                            return InkWell(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => Dialog(
                                    backgroundColor: Colors.transparent,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            color: _darkBg,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          constraints: const BoxConstraints(maxWidth: 700, maxHeight: 800),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(20),
                                            child: InteractiveViewer(
                                              minScale: 0.5,
                                              maxScale: 4.0,
                                              child: Image.network(
                                                idUrl,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 12, right: 12,
                                          child: CircleAvatar(
                                            backgroundColor: Colors.black.withValues(alpha: 0.6),
                                            child: IconButton(
                                              icon: const Icon(Icons.close_rounded, color: Colors.white),
                                              onPressed: () => Navigator.pop(ctx),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                height: 160,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.6), width: 1.5),
                                  color: const Color(0xFFF8FAFC),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.network(
                                        idUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) => const Center(
                                          child: Icon(Icons.broken_image_rounded, size: 40, color: Color(0xFF94A3B8)),
                                        ),
                                      ),
                                      Positioned(
                                        top: 8, left: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF065F46).withValues(alpha: 0.9),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.verified_user_rounded, size: 12, color: Colors.white),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Customer Valid ID',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 8, right: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.65),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.zoom_in_rounded, size: 12, color: Colors.white),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Tap to enlarge',
                                                style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.white),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.badge_outlined, color: Color(0xFFDC2626), size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'No Valid ID recorded for this reservation.',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: const Color(0xFFDC2626),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Actions footer
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                        label: FittedBox(fit: BoxFit.scaleDown, child: Text('Print Pass', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700))),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16302A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: () => ReceiptPdfService.printOrShareVoucher(reservation),
                      ),
                    ),
                    if (!_isMaintenance) ...[
                      if (status == 'confirmed') ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.person_off_rounded, size: 16),
                            label: FittedBox(fit: BoxFit.scaleDown, child: Text('Mark No-Show', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700))),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEA580C),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              _showMarkNoShowConfirmationDialog(reservation['id'], reservation);
                            },
                          ),
                        ),
                      ],
                      if (status == 'no_show') ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.restore_page_rounded, size: 16),
                            label: FittedBox(fit: BoxFit.scaleDown, child: Text('Mark Arrived', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700))),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF15803D),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              _showRevertNoShowConfirmationDialog(reservation['id'], reservation);
                            },
                          ),
                        ),
                      ],
                      if (isPending && needsPricing) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.monetization_on_rounded, size: 16),
                            label: FittedBox(fit: BoxFit.scaleDown, child: Text('Set Price', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700))),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C3AED),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              _showPriceQuotationDialog(reservation);
                            },
                          ),
                        ),
                      ],
                      if (isPending && priceQuotationSent) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check_rounded, size: 16),
                            label: FittedBox(fit: BoxFit.scaleDown, child: Text('Accept', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700))),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF15803D),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              _updateReservationStatus(reservation['id'], 'confirmed', reservation);
                            },
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

  }

  Widget _modalSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: _slate,
        letterSpacing: 1,
      ),
    );
  }
}

class _HoverAnimatedCard extends StatefulWidget {
  final Widget child;

  const _HoverAnimatedCard({required this.child});

  @override
  State<_HoverAnimatedCard> createState() => _HoverAnimatedCardState();
}

class _HoverAnimatedCardState extends State<_HoverAnimatedCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        // ignore: deprecated_member_use
        transform: Matrix4.identity()
          // ignore: deprecated_member_use
          ..scale(_isHovered ? 1.01 : 1.0)
          // ignore: deprecated_member_use
          ..translate(0.0, _isHovered ? -4.0 : 0.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (_isHovered)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 12),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}
