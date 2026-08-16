import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:intl/intl.dart';
import 'package:yang_chow/services/notification_service.dart';
import 'package:yang_chow/services/reservation_service.dart';
import 'package:yang_chow/widgets/price_quotation_dialog.dart';

class AdminReservationsPage extends StatefulWidget {
  final bool isFullscreen;
  const AdminReservationsPage({super.key, this.isFullscreen = false});

  @override
  State<AdminReservationsPage> createState() => _AdminReservationsPageState();
}

class _AdminReservationsPageState extends State<AdminReservationsPage> {
  List<Map<String, dynamic>> reservations = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, pending, confirmed, completed, cancelled
  int _currentPage = 0;
  final int _rowsPerPage = 10;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  
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
      // Ensure schema is updated (adds uploaded_id_url if missing)
      await _ensureSchemaSynchronized(silent: true);

      // Debug: Check current user
      final currentUser = Supabase.instance.client.auth.currentUser;
      debugPrint('Current user: ${currentUser?.email}');
      debugPrint('Current user metadata: ${currentUser?.userMetadata}');
      
      final response = await Supabase.instance.client
          .from('reservations')
          .select('*')
          .order('created_at', ascending: false);

      debugPrint('Reservations loaded: ${response.length}');
      debugPrint('Response: $response');

      // Check for expired reservations and update them
      await _updateExpiredReservations(response);

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
      // 1. Ensure column exists
      await Supabase.instance.client.rpc('exec_sql', params: {
        'sql': "ALTER TABLE public.reservations ADD COLUMN IF NOT EXISTS is_archived BOOLEAN DEFAULT false;"
      });
      await Supabase.instance.client.rpc('exec_sql', params: {
        'sql': "ALTER TABLE public.reservations ADD COLUMN IF NOT EXISTS uploaded_id_url TEXT;"
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

      _showSnackBar('Reservation permanently deleted', Colors.green);
    } catch (e) {
      _loadReservations(); // Revert on error
      _showSnackBar('Error deleting reservation: $e', Colors.red);
    }
  }

  Future<void> _updateReservationStatus(String reservationId, String newStatus, [Map<String, dynamic>? reservation]) async {
    // Optimistic local update — instant visual feedback
    setState(() {
      final idx = reservations.indexWhere((r) => r['id'] == reservationId);
      if (idx != -1) {
        reservations[idx] = {...reservations[idx], 'status': newStatus};
      }
    });

    try {
      await Supabase.instance.client
          .from('reservations')
          .update({'status': newStatus, 'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', reservationId);

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.green ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredReservations {
    List<Map<String, dynamic>> base;
    if (_selectedFilter == 'archived') {
      base = reservations.where((r) => r['is_archived'] == true).toList();
    } else {
      final unarchived = reservations.where((r) => r['is_archived'] != true);
      base = _selectedFilter == 'all'
          ? unarchived.toList()
          : unarchived.where((r) => r['status'] == _selectedFilter).toList();
    }
    if (_searchQuery.isEmpty) return base;
    final q = _searchQuery.toLowerCase();
    return base.where((r) {
      final name  = (r['customer_name']  ?? '').toString().toLowerCase();
      final email = (r['customer_email'] ?? '').toString().toLowerCase();
      final event = (r['event_type']     ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q) || event.contains(q);
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
    return Padding(
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
  }



  Widget _buildDesktopLayout() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageHeader(),
          const SizedBox(height: 14),
          _buildStatsBar(),
          const SizedBox(height: 10),
          _buildSearchBar(),
          const SizedBox(height: 10),
          Expanded(child: _buildReservationsTable()),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildPageHeader(),
        const SizedBox(height: 10),
        _buildStatsBar(),
        const SizedBox(height: 8),
        _buildSearchBar(),
        const SizedBox(height: 8),
        Expanded(child: _buildReservationsList()),
      ],
    );
  }

  Widget _buildSearchBar() {
    return SizedBox(
      height: 38,
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() {
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
                Text(
                  'Event Reservations',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _darkBg,
                    letterSpacing: -0.4,
                  ),
                ),
                Text(
                  'Manage, approve and track all reservation bookings',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: _slate,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadReservations,
            icon: const Icon(Icons.refresh_rounded, color: _slate, size: 20),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    final unarchived = reservations.where((r) => r['is_archived'] != true);
    final pending   = unarchived.where((r) => r['status'] == 'pending').length;
    final confirmed = unarchived.where((r) => r['status'] == 'confirmed').length;
    final completed = unarchived.where((r) => r['status'] == 'completed').length;
    final cancelled = unarchived.where((r) => r['status'] == 'cancelled').length;
    final archived  = reservations.where((r) => r['is_archived'] == true).length;

    return Row(
      children: [
        Expanded(
          child: _statTile(
            'Total',
            unarchived.length,
            Icons.calendar_month_rounded,
            const Color(0xFFDCFCE7),
            const Color(0xFF15803D),
            'all',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statTile(
            'Pending',
            pending,
            Icons.hourglass_top_rounded,
            const Color(0xFFFEF3C7),
            const Color(0xFFD97706),
            'pending',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statTile(
            'Confirmed',
            confirmed,
            Icons.check_circle_rounded,
            const Color(0xFFDCFCE7),
            const Color(0xFF15803D),
            'confirmed',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statTile(
            'Completed',
            completed,
            Icons.done_all_rounded,
            const Color(0xFFE0F2FE),
            const Color(0xFF0284C7),
            'completed',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statTile(
            'Cancelled',
            cancelled,
            Icons.cancel_rounded,
            const Color(0xFFFEE2E2),
            const Color(0xFFDC2626),
            'cancelled',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statTile(
            'Archived',
            archived,
            Icons.inventory_2_rounded,
            const Color(0xFFF1F5F9),
            const Color(0xFF475569),
            'archived',
          ),
        ),
      ],
    );
  }

  Widget _statTile(String label, int value, IconData icon, Color bg, Color iconColor, String filterKey) {
    final bool isSelected = _selectedFilter == filterKey;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedFilter = filterKey;
          _currentPage = 0;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? iconColor : const Color(0xFFE2E8F0),
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: iconColor.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
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
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isSelected ? iconColor : bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: isSelected ? Colors.white : iconColor, size: 15),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value.toString(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? iconColor : _darkBg,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9.5,
                        color: isSelected ? iconColor : _slate,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
                SizedBox(width: 170, child: _tableHeader('ACTIONS')),
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
    final remaining = (totalPrice - depositAmount).clamp(0.0, double.infinity);
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
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        r['customer_email'] ?? r['customer_phone'] ?? 'No contact info',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: _slate,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                if (totalPrice > 0) ...[
                  Text(
                    '₱${totalPrice.toStringAsFixed(2)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: _emerald,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    depositAmount > 0
                        ? 'Paid: ₱${depositAmount.toStringAsFixed(0)} (Rem: ₱${remaining.toStringAsFixed(0)})'
                        : 'No Deposit Paid Yet',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: depositAmount > 0 ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
            width: 170,
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
                                    Text(
                                      reservation['customer_email'] ?? '',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        color: _slate,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
                            ],
                          ),
                          const SizedBox(height: 10),
                          Divider(height: 1, thickness: 1, color: _slateLight.withValues(alpha: 0.8)),
                          const SizedBox(height: 10),
                          // Footer — price + actions
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (totalPrice != null && (totalPrice as num) > 0)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '\u20b1${totalPrice.toStringAsFixed(0)}',
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
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Text(
                                  'Price Pending',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
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
    switch (status) {
      case 'pending':   color = const Color(0xFFD97706); icon = Icons.hourglass_top_rounded; break;
      case 'confirmed': color = const Color(0xFF15803D); icon = Icons.check_circle_rounded;  break;
      case 'completed': color = const Color(0xFF0284C7); icon = Icons.done_all_rounded;       break;
      case 'cancelled': color = const Color(0xFFDC2626); icon = Icons.cancel_rounded;         break;
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
              status.toUpperCase(),
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
    String status = reservation['status'] ?? 'pending';
    String reservationId = reservation['id'];
    bool isArchived = reservation['is_archived'] == true;
    final needsPricing = _reservationService.needsPricing(reservation);
    final priceQuotationSent = reservation['price_quotation_sent'] == true;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isArchived) ...[
            if (status == 'pending') ...[
              if (needsPricing || status == 'pending')
                _buildCompactActionButton(
                  icon: Icons.monetization_on_outlined,
                  color: Colors.purple,
                  tooltip: 'Price',
                  onPressed: () => _showPriceQuotationDialog(reservation),
                ),
              if (priceQuotationSent)
                _buildCompactActionButton(
                  icon: Icons.check_circle_outline,
                  color: AppTheme.successGreen,
                  tooltip: 'Confirm',
                  onPressed: () => _showConfirmReservationDialog(reservation),
                ),
              _buildCompactActionButton(
                icon: Icons.close_rounded,
                color: Colors.red,
                tooltip: 'Cancel',
                onPressed: () => _updateReservationStatus(reservationId, 'cancelled', reservation),
              ),
            ],
            if (status == 'confirmed') ...[
              _buildCompactActionButton(
                icon: Icons.cancel_outlined,
                color: Colors.red,
                tooltip: 'Cancel',
                onPressed: () => _updateReservationStatus(reservationId, 'cancelled', reservation),
              ),
            ],
          ],
          _buildCompactActionButton(
            icon: Icons.visibility_outlined,
            color: AppTheme.infoBlue,
            tooltip: 'View',
            onPressed: () => _showViewReservationDialog(reservation),
          ),
          if (isArchived)
            _buildCompactActionButton(
              icon: Icons.restore_rounded,
              color: AppTheme.successGreen,
              tooltip: 'Restore',
              onPressed: () => _restoreReservation(reservationId),
            ),
          if (isArchived || status == 'cancelled' || status == 'completed')
            _buildCompactActionButton(
              icon: isArchived ? Icons.delete_outline_rounded : Icons.archive_outlined,
              color: isArchived ? Colors.red : Colors.orange,
              tooltip: isArchived ? 'Delete' : 'Archive',
              onPressed: () => _showDeleteConfirmationDialog(reservationId, reservation['event_type'], isArchived: isArchived),
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

  void _showViewReservationDialog(Map<String, dynamic> reservation) {
    final status = reservation['status'];
    final isPending = status == 'pending';
    final isMobile = ResponsiveUtils.isMobile(context);
    final needsPricing = _reservationService.needsPricing(reservation);
    final priceQuotationSent = reservation['price_quotation_sent'] == true;

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
                            buildDetailRow('Email', reservation['customer_email'] ?? 'N/A', icon: Icons.email_rounded),
                            buildDetailRow('Phone', reservation['customer_phone'] ?? 'N/A', icon: Icons.phone_rounded),
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
                              buildDetailRow('Deposit',        '₱${(reservation['deposit_amount'] as num? ?? 0).toStringAsFixed(2)}', icon: Icons.account_balance_wallet_rounded),
                              buildDetailRow('Payment Status', _getPaymentStatusText(reservation['payment_status'] as String? ?? 'unpaid'), icon: Icons.payment_rounded),
                              buildDetailRow('Quote Sent',     reservation['price_quotation_sent'] == true ? 'Yes' : 'No', icon: Icons.send_rounded),
                            ],
                          ),
                        ),
                      ],

                      // Uploaded ID
                      if (reservation['uploaded_id_url'] != null &&
                          reservation['uploaded_id_url'].toString().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _modalSectionTitle('VERIFICATION ID'),
                        const SizedBox(height: 10),
                        InkWell(
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
                                            reservation['uploaded_id_url'].toString(),
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
                            height: 150,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _slateLight),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    reservation['uploaded_id_url'].toString(),
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => const Center(
                                      child: Icon(Icons.broken_image_rounded, size: 40, color: Color(0xFF94A3B8)),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 8, right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.zoom_in_rounded, size: 12, color: Colors.white),
                                          const SizedBox(width: 4),
                                          Text('Tap to enlarge',
                                              style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.white)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
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
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: _slateLight),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Close', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: _slate)),
                      ),
                    ),
                    if (isPending && needsPricing) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.monetization_on_rounded, size: 16),
                          label: Text('Set Price', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
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
                          label: Text('Accept', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
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
