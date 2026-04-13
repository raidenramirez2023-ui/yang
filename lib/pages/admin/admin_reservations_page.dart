import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:intl/intl.dart';
import 'package:yang_chow/services/notification_service.dart';
import 'package:yang_chow/services/reservation_service.dart';
import 'package:yang_chow/widgets/price_quotation_dialog.dart';

class AdminReservationsPage extends StatefulWidget {
  const AdminReservationsPage({super.key});

  @override
  State<AdminReservationsPage> createState() => _AdminReservationsPageState();
}

class _AdminReservationsPageState extends State<AdminReservationsPage> {
  List<Map<String, dynamic>> reservations = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, pending, confirmed, completed, cancelled
  
  // Services
  final ReservationService _reservationService = ReservationService();

  @override
  void initState() {
    super.initState();
    _loadReservations();
  }

  Future<void> _loadReservations() async {
    setState(() => _isLoading = true);
    
    try {
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
            'updated_at': now.toIso8601String()
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
    try {
      await Supabase.instance.client
          .from('reservations')
          .update({'is_archived': true, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', reservationId);

      _showSnackBar('Reservation archived successfully', Colors.green);
      _loadReservations();
    } catch (e) {
      _showSnackBar('Error archiving reservation: $e', Colors.red);
    }
  }

  Future<void> _restoreReservation(String reservationId) async {
    try {
      await Supabase.instance.client
          .from('reservations')
          .update({'is_archived': false, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', reservationId);

      _showSnackBar('Reservation restored', Colors.green);
      _loadReservations();
    } catch (e) {
      _showSnackBar('Error restoring reservation: $e', Colors.red);
    }
  }

  Future<void> _hardDeleteReservation(String reservationId) async {
    try {
      await Supabase.instance.client
          .from('reservations')
          .delete()
          .eq('id', reservationId);

      _showSnackBar('Reservation permanently deleted', Colors.green);
      _loadReservations();
    } catch (e) {
      _showSnackBar('Error deleting reservation: $e', Colors.red);
    }
  }

  Future<void> _updateReservationStatus(String reservationId, String newStatus, [Map<String, dynamic>? reservation]) async {
    try {
      await Supabase.instance.client
          .from('reservations')
          .update({'status': newStatus, 'updated_at': DateTime.now().toIso8601String()})
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
    if (_selectedFilter == 'archived') {
      return reservations.where((r) => r['is_archived'] == true).toList();
    }
    final unarchived = reservations.where((r) => r['is_archived'] != true);
    if (_selectedFilter == 'all') return unarchived.toList();
    return unarchived.where((r) => r['status'] == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);

    return Padding(
      padding: ResponsiveUtils.getResponsivePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with refresh button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Event Reservations',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveFontSize(
                      context,
                      mobile: 20,
                      tablet: 24,
                      desktop: 28,
                    ),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
          ResponsiveUtils.verticalSpace(context, mobile: 16, tablet: 20, desktop: 24),
          Expanded(
            child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      children: [
        _buildKpiSummary(),
        ResponsiveUtils.verticalSpace(context, mobile: 16, tablet: 20, desktop: 24),
        _buildFilterSegmentControl(),
        ResponsiveUtils.verticalSpace(context, mobile: 20, tablet: 24, desktop: 28),
        Expanded(child: _buildReservationsTable()),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildKpiSummary(),
        ResponsiveUtils.verticalSpace(context, mobile: 16, tablet: 20, desktop: 24),
        _buildFilterSegmentControl(),
        ResponsiveUtils.verticalSpace(context, mobile: 16, tablet: 20, desktop: 24),
        Expanded(
          child: _buildReservationsList(),
        ),
      ],
    );
  }

  Widget _buildKpiSummary() {
    if (_isLoading) return const SizedBox.shrink();

    final isMobile = ResponsiveUtils.isMobile(context);
    final unarchived = reservations.where((r) => r['is_archived'] != true);
    final total = unarchived.length;
    final pending = unarchived.where((r) => r['status'] == 'pending').length;
    final confirmed = unarchived.where((r) => r['status'] == 'confirmed').length;
    final completed = unarchived.where((r) => r['status'] == 'completed').length;

    final cards = [
      _buildKpiCard('Total Events', total.toString(), Icons.event, AppTheme.infoBlue),
      _buildKpiCard('Pending', pending.toString(), Icons.pending_actions, Colors.orange),
      _buildKpiCard('Confirmed', confirmed.toString(), Icons.check_circle_outline, AppTheme.successGreen),
      _buildKpiCard('Completed', completed.toString(), Icons.done_all, Colors.grey),
    ];

    if (isMobile) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: AppTheme.sm),
              Expanded(child: cards[1]),
            ],
          ),
          const SizedBox(height: AppTheme.sm),
          Row(
            children: [
              Expanded(child: cards[2]),
              const SizedBox(width: AppTheme.sm),
              Expanded(child: cards[3]),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: cards[0]),
        const SizedBox(width: AppTheme.md),
        Expanded(child: cards[1]),
        const SizedBox(width: AppTheme.md),
        Expanded(child: cards[2]),
        const SizedBox(width: AppTheme.md),
        Expanded(child: cards[3]),
      ],
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(icon, color: color, size: ResponsiveUtils.isMobile(context) ? 20 : 24),
          ),
          const SizedBox(width: AppTheme.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppTheme.mediumGrey,
                  fontSize: ResponsiveUtils.isMobile(context) ? 12 : 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppTheme.xs),
              Text(
                value,
                style: TextStyle(
                  color: AppTheme.darkGrey,
                  fontSize: ResponsiveUtils.isMobile(context) ? 18 : 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSegmentControl() {
    final isMobile = ResponsiveUtils.isMobile(context);
    final filters = [
      {'value': 'all', 'label': 'All Events'},
      {'value': 'pending', 'label': 'Pending'},
      {'value': 'confirmed', 'label': 'Confirmed'},
      {'value': 'completed', 'label': 'Completed'},
      {'value': 'cancelled', 'label': 'Cancelled'},
      {'value': 'archived', 'label': 'Archived'},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.sm),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isMobile
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: filters.map((f) => _buildSegmentButton(f['value']!, f['label']!)).toList(),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: filters.map((f) => Expanded(child: _buildSegmentButton(f['value']!, f['label']!))).toList(),
            ),
    );
  }

  Widget _buildSegmentButton(String value, String label) {
    final isSelected = _selectedFilter == value;
    final isMobile = ResponsiveUtils.isMobile(context);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          vertical: AppTheme.md,
          horizontal: isMobile ? AppTheme.lg : 0,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.white : AppTheme.mediumGrey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: isMobile ? 13 : 14,
          ),
        ),
      ),
    );
  }

  Widget _buildReservationsTable() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredReservations.isEmpty) {
      return _buildEmptyState();
    }

    final isMobile = ResponsiveUtils.isMobile(context);
    
    return Card(
      elevation: isMobile ? 1 : 2,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Scrollbar(
            thumbVisibility: !isMobile,
            trackVisibility: !isMobile,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: constraints.maxWidth,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: DataTable(
              columnSpacing: isMobile ? 8 : 24,
              horizontalMargin: isMobile ? 8 : 16,
              headingRowHeight: isMobile ? 48 : 56,
              dataRowMinHeight: isMobile ? 40 : 48,
              dataRowMaxHeight: isMobile ? 60 : 72,
              columns: [
                DataColumn(
                  label: Text(
                    'Customer',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        mobile: 12,
                        tablet: 13,
                        desktop: 14,
                      ),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!isMobile) DataColumn(
                  label: Text(
                    'Event',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        mobile: 12,
                        tablet: 13,
                        desktop: 14,
                      ),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Date',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        mobile: 12,
                        tablet: 13,
                        desktop: 14,
                      ),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Time',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        mobile: 12,
                        tablet: 13,
                        desktop: 14,
                      ),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!isMobile) DataColumn(
                  label: Text(
                    'Guests',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        mobile: 12,
                        tablet: 13,
                        desktop: 14,
                      ),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Status',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        mobile: 12,
                        tablet: 13,
                        desktop: 14,
                      ),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Actions',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        mobile: 12,
                        tablet: 13,
                        desktop: 14,
                      ),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              rows: _filteredReservations.map((reservation) {
                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        isMobile
                            ? (reservation['customer_name']?.toString().split(' ')[0] ?? '')
                            : '${reservation['customer_name']}\n${reservation['customer_email']}',
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                            context,
                            mobile: 11,
                            tablet: 12,
                            desktop: 13,
                          ),
                        ),
                      ),
                    ),
                    if (!isMobile) DataCell(
                      Text(
                        reservation['event_type'],
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                            context,
                            mobile: 11,
                            tablet: 12,
                            desktop: 13,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        reservation['event_date'],
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                            context,
                            mobile: 11,
                            tablet: 12,
                            desktop: 13,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        reservation['start_time'],
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                            context,
                            mobile: 11,
                            tablet: 12,
                            desktop: 13,
                          ),
                        ),
                      ),
                    ),
                    if (!isMobile) DataCell(
                      Text(
                        '${reservation['number_of_guests']}',
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                            context,
                            mobile: 11,
                            tablet: 12,
                            desktop: 13,
                          ),
                        ),
                      ),
                    ),
                    DataCell(_buildStatusChip(reservation['status'])),
                    DataCell(_buildActionButtons(reservation)),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
      );
     },
    ),
    );
  }

  Widget _buildReservationsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredReservations.isEmpty) {
      return _buildEmptyState();
    }

    final isMobile = ResponsiveUtils.isMobile(context);
    
    return ListView.builder(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      itemCount: _filteredReservations.length,
      itemBuilder: (context, index) {
        final reservation = _filteredReservations[index];
        return Card(
          elevation: isMobile ? 2 : 4,
          margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            child: Row(
              children: [
                // Ticket Stub (Left Side Date/Time)
                Container(
                  width: 90,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.05),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppTheme.radiusLg),
                      bottomLeft: Radius.circular(AppTheme.radiusLg),
                    ),
                    border: Border(right: BorderSide(color: Colors.grey.withValues(alpha: 0.3), style: BorderStyle.solid)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 8.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          reservation['event_date'].split('-').last, // Just the Day
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        Text(
                          reservation['start_time'].substring(0, 5), // Just HH:mm
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 12, tablet: 13, desktop: 14),
                            fontWeight: FontWeight.w600,
                            color: AppTheme.mediumGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Main Ticket Body
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                reservation['event_type'],
                                style: TextStyle(
                                  fontSize: ResponsiveUtils.getResponsiveFontSize(
                                    context,
                                    mobile: 16,
                                    tablet: 18,
                                    desktop: 20,
                                  ),
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.darkGrey,
                                ),
                              ),
                            ),
                            _buildStatusChip(reservation['status']),
                          ],
                        ),
                        ResponsiveUtils.verticalSpace(context, mobile: 6, tablet: 8, desktop: 10),
                        
                        // Customer & Guest Info
                        Row(
                          children: [
                            Icon(Icons.person, size: 16, color: AppTheme.mediumGrey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                reservation['customer_name'],
                                style: TextStyle(
                                  fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 13, tablet: 14, desktop: 15),
                                  color: AppTheme.darkGrey,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.group, size: 16, color: AppTheme.mediumGrey),
                            const SizedBox(width: 4),
                            Text(
                              '${reservation['number_of_guests']} pax',
                              style: TextStyle(
                                fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 13, tablet: 14, desktop: 15),
                                color: AppTheme.mediumGrey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        
                        ResponsiveUtils.verticalSpace(context, mobile: 12, tablet: 14, desktop: 16),
                        
                        // Divider
                        Divider(height: 1, color: Colors.grey.withValues(alpha: 0.2)),
                        
                        ResponsiveUtils.verticalSpace(context, mobile: 8, tablet: 10, desktop: 12),
                        
                        // Actions
                        Align(
                          alignment: Alignment.centerRight,
                          child: _buildActionButtons(reservation),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
        padding: const EdgeInsets.all(AppTheme.xl),
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.lg),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_available_rounded, 
                size: ResponsiveUtils.getResponsiveIconSize(context, mobile: 48, tablet: 56, desktop: 64), 
                color: AppTheme.primaryColor,
              ),
            ),
            ResponsiveUtils.verticalSpace(context, mobile: 24, tablet: 28, desktop: 32),
            Text(
              'No Events Found',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 20,
                  tablet: 22,
                  desktop: 24,
                ),
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGrey,
              ),
            ),
            ResponsiveUtils.verticalSpace(context, mobile: 8, tablet: 10, desktop: 12),
            Text(
              'There are no reservations matching the currently selected filter.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 14,
                  tablet: 15,
                  desktop: 16,
                ),
                color: AppTheme.mediumGrey,
                height: 1.5,
              ),
            ),
            ResponsiveUtils.verticalSpace(context, mobile: 24, tablet: 28, desktop: 32),
            if (_selectedFilter != 'all')
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedFilter = 'all';
                  });
                },
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear Filters'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.darkGrey,
                  foregroundColor: AppTheme.white,
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.xl, vertical: AppTheme.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  ),
                ),
              ),
          ],
        ),
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

  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;
    
    switch (status) {
      case 'pending':
        color = Colors.orange;
        icon = Icons.pending;
        break;
      case 'confirmed':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'completed':
        color = Colors.grey;
        icon = Icons.done_all;
        break;
      case 'cancelled':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_outline;
    }

    final isMobile = ResponsiveUtils.isMobile(context);

    return Chip(
      label: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: ResponsiveUtils.getResponsiveFontSize(
            context,
            mobile: 10,
            tablet: 11,
            desktop: 12,
          ),
        ),
      ),
      backgroundColor: color.withValues(alpha: 0.1),
      avatar: Icon(
        icon, 
        size: ResponsiveUtils.getResponsiveIconSize(context, mobile: 12, tablet: 14, desktop: 16), 
        color: color,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 6 : 8,
        vertical: isMobile ? 2 : 4,
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> reservation) {
    String status = reservation['status'];
    String reservationId = reservation['id'];
    bool isArchived = reservation['is_archived'] == true;
    final needsPricing = _reservationService.needsPricing(reservation);
    final priceQuotationSent = reservation['price_quotation_sent'] == true;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isArchived) ...[
          if (status == 'pending') ...[
            // Pricing button - show if pricing is needed
            if (needsPricing)
              IconButton(
                onPressed: () => _showPriceQuotationDialog(reservation),
                icon: Icon(
                  Icons.monetization_on, 
                  color: Colors.purple,
                  size: ResponsiveUtils.getResponsiveIconSize(context, mobile: 18, tablet: 20, desktop: 24),
                ),
                tooltip: 'Set Price & Send Quotation',
                iconSize: ResponsiveUtils.getResponsiveIconSize(context, mobile: 18, tablet: 20, desktop: 24),
              ),
            // Confirm button - only show if pricing is done
            if (priceQuotationSent)
              IconButton(
                onPressed: () => _showConfirmReservationDialog(reservation),
                icon: Icon(
                  Icons.check, 
                  color: Colors.green,
                  size: ResponsiveUtils.getResponsiveIconSize(context, mobile: 18, tablet: 20, desktop: 24),
                ),
                tooltip: 'Confirm',
                iconSize: ResponsiveUtils.getResponsiveIconSize(context, mobile: 18, tablet: 20, desktop: 24),
              ),
            IconButton(
              onPressed: () => _updateReservationStatus(reservationId, 'cancelled', reservation),
              icon: Icon(
                Icons.close, 
                color: Colors.red,
                size: ResponsiveUtils.getResponsiveIconSize(context, mobile: 18, tablet: 20, desktop: 24),
              ),
              tooltip: 'Cancel',
              iconSize: ResponsiveUtils.getResponsiveIconSize(context, mobile: 18, tablet: 20, desktop: 24),
            ),
          ],
          if (status == 'confirmed') ...[
            IconButton(
              onPressed: () => _updateReservationStatus(reservationId, 'cancelled', reservation),
              icon: Icon(
                Icons.cancel, 
                color: Colors.red,
                size: ResponsiveUtils.getResponsiveIconSize(context, mobile: 18, tablet: 20, desktop: 24),
              ),
              tooltip: 'Cancel',
              iconSize: ResponsiveUtils.getResponsiveIconSize(context, mobile: 18, tablet: 20, desktop: 24),
            ),
          ],
        ],
        IconButton(
          onPressed: () => _showViewReservationDialog(reservation),
          icon: Icon(
            Icons.visibility,
            color: AppTheme.infoBlue,
            size: ResponsiveUtils.getResponsiveIconSize(context, mobile: 18, tablet: 20, desktop: 24),
          ),
          tooltip: 'View Details',
        ),
        if (!isArchived && status == 'completed') ...[
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveUtils.getResponsiveFontSize(context, mobile: 8, tablet: 10, desktop: 12),
              vertical: ResponsiveUtils.getResponsiveFontSize(context, mobile: 4, tablet: 6, desktop: 8),
            ),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'COMPLETED',
              style: TextStyle(
                color: Colors.grey,
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 8, tablet: 9, desktop: 10),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        if (isArchived)
          IconButton(
            onPressed: () => _restoreReservation(reservationId),
            icon: Icon(
              Icons.restore, 
              color: AppTheme.successGreen,
              size: ResponsiveUtils.getResponsiveIconSize(context, mobile: 18, tablet: 20, desktop: 24),
            ),
            tooltip: 'Restore',
            iconSize: ResponsiveUtils.getResponsiveIconSize(context, mobile: 18, tablet: 20, desktop: 24),
          ),
        IconButton(
          onPressed: () => _showDeleteConfirmationDialog(reservationId, reservation['event_type'], isArchived: isArchived),
          icon: Icon(
            isArchived ? Icons.delete_forever : Icons.archive, 
            color: Colors.red,
            size: ResponsiveUtils.getResponsiveIconSize(context, mobile: 18, tablet: 20, desktop: 24),
          ),
          tooltip: isArchived ? 'Delete Permanently' : 'Archive',
          iconSize: ResponsiveUtils.getResponsiveIconSize(context, mobile: 18, tablet: 20, desktop: 24),
        ),
      ],
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
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            const Text('Reservation Details'),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SingleChildScrollView(
          child: SizedBox(
            width: isMobile ? double.maxFinite : 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.lightGrey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      buildDetailRow('Customer Name', reservation['customer_name'] ?? 'N/A', icon: Icons.person),
                      buildDetailRow('Email', reservation['customer_email'] ?? 'N/A', icon: Icons.email),
                      buildDetailRow('Phone', reservation['customer_phone'] ?? 'N/A', icon: Icons.phone),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),
                buildDetailRow('Event Type', reservation['event_type'] ?? 'N/A', icon: Icons.event),
                buildDetailRow('Event Date', reservation['event_date'] ?? 'N/A', icon: Icons.calendar_today),
                buildDetailRow('Start Time', reservation['start_time'] ?? 'N/A', icon: Icons.access_time),
                buildDetailRow('Guests', '${reservation['number_of_guests'] ?? '0'}', icon: Icons.people),
                buildDetailRow('Table Number', reservation['table_number']?.toString() ?? 'Unassigned', icon: Icons.table_restaurant),
                const SizedBox(height: 16),
                buildDetailRow('Status', status?.toString().toUpperCase() ?? 'UNKNOWN', icon: Icons.info),
                
                // Pricing information
                if (reservation['total_price'] != null && reservation['total_price'] > 0) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  buildDetailRow('Total Price', 'PHP ${(reservation['total_price'] as double).toStringAsFixed(2)}', icon: Icons.monetization_on),
                  buildDetailRow('Deposit Required', 'PHP ${(reservation['deposit_amount'] as double).toStringAsFixed(2)}', icon: Icons.account_balance_wallet),
                  buildDetailRow('Payment Status', (reservation['payment_status'] as String? ?? 'unpaid').toUpperCase(), icon: Icons.payment),
                  buildDetailRow('Quotation Sent', reservation['price_quotation_sent'] == true ? 'Yes' : 'No', icon: Icons.email),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (isPending && needsPricing)
            ElevatedButton.icon(
              icon: const Icon(Icons.monetization_on, size: 18),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context);
                _showPriceQuotationDialog(reservation);
              },
              label: const Text('Set Price'),
            ),
          if (isPending && priceQuotationSent)
            ElevatedButton.icon(
              icon: const Icon(Icons.check, size: 18),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context);
                _updateReservationStatus(reservation['id'], 'confirmed', reservation);
              },
              label: const Text('Accept Reservation'),
            ),
        ],
      ),
    );
  }
}
