import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:yang_chow/services/reservation_service.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/app_constants.dart';
import 'package:yang_chow/widgets/customer/customer_ui_components.dart';

/// Enterprise Availability Preview Widget for Customer Booking / Reservation
///
/// Features:
/// - Luxury Hospitality Design System (Deep Emerald #14332E, Warm Gold #D9A441, Crisp Slate)
/// - Session-Based Grouping: Morning & Brunch, Afternoon Gathering, Evening & Dinner Banquet
/// - Responsive Adaptive Grid: Structured, elegant slot cards
/// - Clear distinction between Booked (muted, locked) and Available (emerald/gold selectable)
/// - Real-time validation pass-through to existing reservation logic
class AvailabilityPreviewWidget extends StatefulWidget {
  final String selectedDateText; // E.g. "September 26, 2026"
  final String? selectedStartTime; // E.g. "5:30 PM"
  final double durationHours;
  final int operatingHoursStart;
  final int operatingHoursEnd;
  final ValueChanged<String> onTimeSelected;
  final VoidCallback? onPickCustomTime;

  const AvailabilityPreviewWidget({
    super.key,
    required this.selectedDateText,
    this.selectedStartTime,
    this.durationHours = 2.0,
    this.operatingHoursStart = 10,
    this.operatingHoursEnd = 20,
    required this.onTimeSelected,
    this.onPickCustomTime,
  });

  @override
  State<AvailabilityPreviewWidget> createState() => _AvailabilityPreviewWidgetState();
}

class _AvailabilityPreviewWidgetState extends State<AvailabilityPreviewWidget> {
  final ReservationService _reservationService = ReservationService();

  bool _isLoading = false;
  List<Map<String, dynamic>> _bookings = [];
  String? _lastLoadedDate;

  // Filter: 'all', 'morning', 'afternoon', 'evening'
  String _selectedPeriodFilter = 'all';

  int get _effectiveStartHour => widget.operatingHoursStart > 0 ? widget.operatingHoursStart : 10;

  int get _effectiveEndHour {
    if (widget.operatingHoursEnd > 0 && widget.operatingHoursEnd <= 12) {
      return widget.operatingHoursEnd + 12;
    }
    if (widget.operatingHoursEnd < 18) {
      return AppConstants.defaultOperatingHoursEnd; // 20 (8:00 PM)
    }
    return widget.operatingHoursEnd;
  }

  @override
  void initState() {
    super.initState();
    if (widget.selectedDateText.trim().isNotEmpty) {
      _loadAvailability(widget.selectedDateText);
    }
  }

  @override
  void didUpdateWidget(covariant AvailabilityPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDateText != oldWidget.selectedDateText) {
      if (widget.selectedDateText.trim().isNotEmpty) {
        _loadAvailability(widget.selectedDateText);
      } else {
        setState(() {
          _bookings = [];
          _lastLoadedDate = null;
        });
      }
    }
  }

  Future<void> _loadAvailability(String dateText) async {
    final trimmed = dateText.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _isLoading = true;
      _lastLoadedDate = trimmed;
      _selectedPeriodFilter = 'all';
    });

    try {
      DateTime parsedDate;
      try {
        parsedDate = DateFormat('MMMM d, yyyy').parse(trimmed);
      } catch (_) {
        parsedDate = DateFormat('yyyy-MM-dd').parse(trimmed);
      }
      final dateStr = DateFormat('yyyy-MM-dd').format(parsedDate);

      final results = await _reservationService.getBookingsForDate(dateStr);

      if (mounted && _lastLoadedDate == trimmed) {
        setState(() {
          _bookings = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading date availability: $e');
      if (mounted) {
        setState(() {
          _bookings = [];
          _isLoading = false;
        });
      }
    }
  }

  DateTime _parseTime(String timeStr) {
    final cleanStr = timeStr.trim().replaceAll('\u202F', ' ').replaceAll('\u00A0', ' ');
    final match24 = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$').firstMatch(cleanStr);
    if (match24 != null) {
      final hour = int.tryParse(match24.group(1)!) ?? 0;
      final minute = int.tryParse(match24.group(2)!) ?? 0;
      return DateTime(2000, 1, 1, hour, minute);
    }
    final match12 = RegExp(r'^(\d{1,2}):(\d{2})(?:\s*(AM|PM))?$', caseSensitive: false).firstMatch(cleanStr);
    if (match12 != null) {
      int hour = int.tryParse(match12.group(1)!) ?? 0;
      final minute = int.tryParse(match12.group(2)!) ?? 0;
      final period = match12.group(3)?.toUpperCase();
      if (period == 'PM' && hour < 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      return DateTime(2000, 1, 1, hour, minute);
    }
    try {
      final timeFormat = DateFormat.jm();
      final parsed = timeFormat.parse(cleanStr);
      return DateTime(2000, 1, 1, parsed.hour, parsed.minute);
    } catch (_) {
      return DateTime(2000, 1, 1, _effectiveStartHour, 0);
    }
  }

  String _formatTime(DateTime dt) {
    return DateFormat.jm().format(dt);
  }

  List<_TimeRange> _getBookedRanges() {
    final list = <_TimeRange>[];
    for (final b in _bookings) {
      final startStr = b['start_time']?.toString() ?? '';
      final duration = (b['duration_hours'] as num?)?.toDouble() ?? 2.0;
      if (startStr.isEmpty || duration <= 0) continue;

      final start = _parseTime(startStr);
      final end = start.add(Duration(minutes: (duration * 60).toInt()));
      list.add(_TimeRange(
        start: start,
        end: end,
        isBooked: true,
        label: b['event_type']?.toString() ?? 'Private Event Reservation',
      ));
    }
    list.sort((a, b) => a.start.compareTo(b.start));
    return list;
  }

  List<_TimeRange> _getAvailableRanges(List<_TimeRange> bookedList) {
    // If the venue has reached the maximum of 2 event reservations for this day,
    // no more slots are available
    if (bookedList.length >= AppConstants.maxEventReservationsPerDay) {
      return [];
    }

    final available = <_TimeRange>[];
    final dayStart = DateTime(2000, 1, 1, _effectiveStartHour, 0);
    final dayEnd = DateTime(2000, 1, 1, _effectiveEndHour, 0);
    final intervalDuration = Duration(minutes: (AppConstants.defaultEventIntervalHours * 60).toInt());

    DateTime cursor = dayStart;

    for (final booked in bookedList) {
      // An event requires a 2-hour turnaround buffer before and after.
      // An earlier slot must finish at or before (booked.start - 2 hours).
      // A later slot can only start at or after (booked.end + 2 hours).
      final bufferedStart = booked.start.subtract(intervalDuration);
      final bufferedEnd = booked.end.add(intervalDuration);

      final effectiveBlockedStart = bufferedStart.isBefore(dayStart) ? dayStart : bufferedStart;
      final effectiveBlockedEnd = bufferedEnd.isAfter(dayEnd) ? dayEnd : bufferedEnd;

      if (effectiveBlockedStart.isAfter(cursor)) {
        available.add(_TimeRange(
          start: cursor,
          end: effectiveBlockedStart,
          isBooked: false,
          label: 'Available Window',
        ));
      }
      if (effectiveBlockedEnd.isAfter(cursor)) {
        cursor = effectiveBlockedEnd;
      }
    }

    if (cursor.isBefore(dayEnd)) {
      available.add(_TimeRange(
        start: cursor,
        end: dayEnd,
        isBooked: false,
        label: 'Available Window',
      ));
    }

    return available;
  }

  /// Groups available start times into structured Sessions
  List<_SessionGroup> _buildSessions(List<_TimeRange> availableRanges) {
    final morningSlots = <_SlotCardData>[];
    final afternoonSlots = <_SlotCardData>[];
    final eveningSlots = <_SlotCardData>[];

    final requiredDurationMinutes = (widget.durationHours * 60).toInt();

    for (final range in availableRanges) {
      DateTime cursor = range.start;
      while (cursor.add(Duration(minutes: requiredDurationMinutes)).isBefore(range.end) ||
          cursor.add(Duration(minutes: requiredDurationMinutes)).isAtSameMomentAs(range.end)) {
        final timeStr = _formatTime(cursor);
        final hour = cursor.hour;

        String sessionTag;
        if (hour < 12) {
          sessionTag = 'Brunch';
        } else if (hour < 16) {
          sessionTag = 'Lunch / Gathering';
        } else {
          sessionTag = 'Dinner Banquet';
        }

        final slot = _SlotCardData(
          timeString: timeStr,
          periodTag: sessionTag,
          hour: hour,
          time: cursor,
        );

        if (hour < 12) {
          morningSlots.add(slot);
        } else if (hour < 16) {
          afternoonSlots.add(slot);
        } else {
          eveningSlots.add(slot);
        }

        // Advance to next whole hour if cursor was on half-hour, otherwise advance by 1 hour
        if (cursor.minute != 0) {
          cursor = DateTime(cursor.year, cursor.month, cursor.day, cursor.hour + 1, 0);
        } else {
          cursor = cursor.add(const Duration(hours: 1));
        }
      }
    }

    final groups = <_SessionGroup>[];

    if (morningSlots.isNotEmpty) {
      groups.add(_SessionGroup(
        id: 'morning',
        title: 'Morning & Brunch',
        timeSubtitle: '10:00 AM – 12:00 PM',
        icon: Icons.wb_sunny_rounded,
        accentColor: const Color(0xFFD97706),
        slots: morningSlots,
      ));
    }

    if (afternoonSlots.isNotEmpty) {
      groups.add(_SessionGroup(
        id: 'afternoon',
        title: 'Afternoon Gathering',
        timeSubtitle: '12:00 PM – 4:00 PM',
        icon: Icons.wb_twilight_rounded,
        accentColor: const Color(0xFF0284C7),
        slots: afternoonSlots,
      ));
    }

    if (eveningSlots.isNotEmpty) {
      groups.add(_SessionGroup(
        id: 'evening',
        title: 'Evening & Dinner Banquet',
        timeSubtitle: '4:00 PM – 8:00 PM',
        icon: Icons.nights_stay_rounded,
        accentColor: const Color(0xFF7C3AED),
        slots: eveningSlots,
      ));
    }

    return groups;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedDateText.trim().isEmpty) {
      return _buildNoDatePrompt();
    }

    if (_isLoading) {
      return _buildLoadingState();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 400;

    final bookedRanges = _getBookedRanges();
    final availableRanges = _getAvailableRanges(bookedRanges);
    final sessions = _buildSessions(availableRanges);

    final hasBookings = bookedRanges.isNotEmpty;
    final isFullyBooked = availableRanges.isEmpty || (sessions.isEmpty && hasBookings);

    final totalOpenSlots = sessions.fold<int>(0, (sum, s) => sum + s.slots.length);

    // Auto-fallback to 'all' if selected filter has no slots in current sessions
    final activeFilter = (_selectedPeriodFilter != 'all' && sessions.any((s) => s.id == _selectedPeriodFilter))
        ? _selectedPeriodFilter
        : 'all';

    final filteredSessions = activeFilter == 'all'
        ? sessions
        : sessions.where((s) => s.id == activeFilter).toList();

    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFullyBooked
              ? const Color(0xFFEF4444).withValues(alpha: 0.45)
              : (hasBookings ? AppTheme.warmGold.withValues(alpha: 0.45) : const Color(0xFFE2E8F0)),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Integrated Executive Header (Date + Operating Hours + Status) ──
            _buildExecutiveHeader(hasBookings, isFullyBooked, bookedRanges.length, isCompact),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 10.0 : 14.0, vertical: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Reserved Hours Alert or All Open Guidance or Fully Booked Alert ──
                  if (isFullyBooked) ...[
                    _buildFullyBookedAlert(bookedRanges),
                    const SizedBox(height: 8),
                  ] else if (hasBookings) ...[
                    _buildReservedAlert(bookedRanges),
                    const SizedBox(height: 8),
                  ] else ...[
                    _buildAllOpenAlert(),
                    const SizedBox(height: 8),
                  ],

                  // ── Session Filter Chips (All, Morning, Afternoon, Evening) ──
                  if (!isFullyBooked && sessions.length > 1) ...[
                    _buildSessionPills(sessions, totalOpenSlots, isCompact, activeFilter),
                    const SizedBox(height: 10),
                  ],

                  // ── Slots Content (Clean 3-column chip grid) ──
                  if (isFullyBooked)
                    _buildFullyBookedNotice()
                  else if (filteredSessions.isEmpty)
                    _buildEmptyFilterNotice()
                  else
                    for (int i = 0; i < filteredSessions.length; i++) ...[
                      if (activeFilter == 'all' && sessions.length > 1)
                        _buildSessionSectionHeader(filteredSessions[i]),
                      _buildSlotsGrid(filteredSessions[i].slots),
                      if (i < filteredSessions.length - 1 && activeFilter == 'all')
                        const SizedBox(height: 8),
                    ],

                  const SizedBox(height: 10),

                  // ── Compact Confirmation Footer & Custom Time Button ──
                  _buildSelectedFeedbackFooter(isCompact, isFullyBooked),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Luxury Executive Header: Date, Operating Hours, Status in one cohesive banner
  Widget _buildExecutiveHeader(bool hasBookings, bool isFullyBooked, int bookingCount, bool isCompact) {
    Color statusBg;
    Color statusBorder;
    Color statusTextColor;
    String statusLabel;
    IconData statusIcon;

    if (isFullyBooked) {
      statusBg = const Color(0xFFFEE2E2);
      statusBorder = const Color(0xFFEF4444);
      statusTextColor = const Color(0xFFB91C1C);
      statusLabel = bookingCount >= AppConstants.maxEventReservationsPerDay
          ? 'Fully Booked (2/2 Events)'
          : 'Fully Booked';
      statusIcon = Icons.lock_rounded;
    } else if (hasBookings) {
      statusBg = const Color(0xFFDCFCE7);
      statusBorder = const Color(0xFF22C55E);
      statusTextColor = const Color(0xFF15803D);
      statusLabel = 'Open • $bookingCount of 2 Sched';
      statusIcon = Icons.event_available_rounded;
    } else {
      statusBg = const Color(0xFFDCFCE7);
      statusBorder = const Color(0xFF22C55E);
      statusTextColor = const Color(0xFF15803D);
      statusLabel = 'All Slots Open';
      statusIcon = Icons.verified_rounded;
    }

    final startStr = _formatTime(DateTime(2000, 1, 1, _effectiveStartHour, 0));
    final endStr = _formatTime(DateTime(2000, 1, 1, _effectiveEndHour, 0));

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 14, vertical: 10),
      decoration: const BoxDecoration(
        color: AppTheme.forestGreen,
        border: Border(
          bottom: BorderSide(color: AppTheme.sidebarDivider, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.warmGold.withValues(alpha: 0.4)),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  size: 15,
                  color: AppTheme.warmGold,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VENUE AVAILABILITY',
                      style: GoogleFonts.inter(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: AppTheme.warmGold,
                      ),
                    ),
                    Text(
                      widget.selectedDateText,
                      style: GoogleFonts.inter(
                        fontSize: isCompact ? 13 : 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusBorder.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 11, color: statusTextColor),
                      const SizedBox(width: 3.5),
                      Text(
                        statusLabel,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.storefront_rounded, size: 12, color: AppTheme.warmGold),
              const SizedBox(width: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Operating Hours: $startStr – $endStr',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isFullyBooked
                      ? 'All slots reserved on this date'
                      : (hasBookings
                          ? 'Open for more bookings'
                          : 'All day open for reservations'),
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: isFullyBooked ? const Color(0xFFFCA5A5) : AppTheme.warmGold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Reassuring alert: Customer clearly knows they can still book + displays scheduled count and times
  Widget _buildReservedAlert(List<_TimeRange> bookedRanges) {
    final count = bookedRanges.length;
    final summary = bookedRanges.map((b) => '${_formatTime(b.start)}–${_formatTime(b.end)}').join(', ');
    return InkWell(
      onTap: () => _showScheduleBreakdownBottomSheet(context, bookedRanges, false),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF86EFAC), width: 0.9),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFF16A34A),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, size: 10, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF166534),
                        height: 1.25,
                      ),
                      children: [
                        const TextSpan(
                          text: 'Still open for booking! ',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        TextSpan(
                          text: '$count booking${count > 1 ? 's' : ''} scheduled ($summary) • Tap for details',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF166534)),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                const Icon(
                  Icons.arrow_circle_down_rounded,
                  size: 13,
                  color: Color(0xFF15803D),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Select any open slot below:',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF15803D),
                      letterSpacing: -0.1,
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
    );
  }

  /// Clean guidance when all slots are open on selected date
  Widget _buildAllOpenAlert() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF86EFAC), width: 0.9),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              color: Color(0xFF16A34A),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 10, color: Colors.white),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'All slots open! Select any open slot below:',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF166534),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Informative alert when venue is completely fully booked (Tappable to view full details)
  Widget _buildFullyBookedAlert(List<_TimeRange> bookedRanges) {
    final count = bookedRanges.length;
    final summary = bookedRanges.map((b) => '${_formatTime(b.start)}–${_formatTime(b.end)}').join(', ');
    return InkWell(
      onTap: () => _showScheduleBreakdownBottomSheet(context, bookedRanges, true),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFCA5A5), width: 0.9),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Color(0xFFDC2626),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_rounded, size: 10, color: Colors.white),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF991B1B), height: 1.25),
                  children: [
                    const TextSpan(
                      text: 'Fully Booked! ',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    TextSpan(
                      text: '$count booking${count > 1 ? 's' : ''} scheduled ($summary) • Tap to view schedule',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFFDC2626)),
            ),
          ],
        ),
      ),
    );
  }

  /// Segmented Session Filter Chips
  Widget _buildSessionPills(List<_SessionGroup> sessions, int totalSlots, bool isCompact, String activeFilter) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildSessionFilterPill('all', 'All ($totalSlots)', Icons.dashboard_rounded, activeFilter),
          for (final s in sessions) ...[
            const SizedBox(width: 6),
            _buildSessionFilterPill(s.id, '${s.title.split(" ").first} (${s.slots.length})', s.icon, activeFilter),
          ],
        ],
      ),
    );
  }

  Widget _buildSessionFilterPill(String id, String label, IconData icon, String activeFilter) {
    final isSelected = activeFilter == id;

    return AnimatedTapScale(
      onTap: () => setState(() => _selectedPeriodFilter = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.forestGreen : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.warmGold : const Color(0xFFE2E8F0),
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 11.5,
              color: isSelected ? AppTheme.warmGold : AppTheme.mediumGrey,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.darkGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Clean, compact section subheader between sessions
  Widget _buildSessionSectionHeader(_SessionGroup session) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Row(
        children: [
          Icon(session.icon, size: 12, color: session.accentColor),
          const SizedBox(width: 5),
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    session.title.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: session.accentColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '• ${session.timeSubtitle}',
                  style: GoogleFonts.inter(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.mediumGrey,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${session.slots.length} open',
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF166534),
            ),
          ),
        ],
      ),
    );
  }

  /// Compact 3-Column Slot Chips Grid (Fits beautifully on mobile screens)
  Widget _buildSlotsGrid(List<_SlotCardData> slots) {
    // Robust time equality check across any format differences (e.g. 10:00 AM vs 10:00 vs 10:00 AM)
    bool isSlotSelected(String? userSelected, String slotTimeStr) {
      if (userSelected == null || userSelected.trim().isEmpty) return false;
      final cleanUser = userSelected.trim().replaceAll('\u202F', ' ').replaceAll('\u00A0', ' ').replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
      final cleanSlot = slotTimeStr.trim().replaceAll('\u202F', ' ').replaceAll('\u00A0', ' ').replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
      if (cleanUser == cleanSlot) return true;
      try {
        final tUser = _parseTime(cleanUser);
        final tSlot = _parseTime(cleanSlot);
        return tUser.hour == tSlot.hour && tUser.minute == tSlot.minute;
      } catch (_) {
        return false;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 480
            ? 3
            : (constraints.maxWidth < 720 ? 4 : 5);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: slots.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: constraints.maxWidth < 360 ? 1.85 : (constraints.maxWidth < 480 ? 2.05 : 2.35),
          ),
          itemBuilder: (context, index) {
            final slot = slots[index];
            final isSelected = isSlotSelected(widget.selectedStartTime, slot.timeString);

            return _buildEnterpriseSlotChip(slot, isSelected);
          },
        );
      },
    );
  }

  /// Enterprise Slot Chip with High-Contrast Selected State
  Widget _buildEnterpriseSlotChip(_SlotCardData slot, bool isSelected) {
    return AnimatedTapScale(
      onTap: () => widget.onTimeSelected(slot.timeString),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.forestGreen : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.warmGold : const Color(0xFFE2E8F0),
            width: isSelected ? 2.2 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.forestGreen.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                  BoxShadow(
                    color: AppTheme.warmGold.withValues(alpha: 0.4),
                    blurRadius: 4,
                    offset: const Offset(0, 0),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 13,
                        color: AppTheme.warmGold,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      slot.timeString,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                        color: isSelected ? Colors.white : AppTheme.darkGrey,
                        letterSpacing: isSelected ? 0.2 : 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Container(
                  padding: isSelected
                      ? const EdgeInsets.symmetric(horizontal: 5, vertical: 1)
                      : EdgeInsets.zero,
                  decoration: isSelected
                      ? BoxDecoration(
                          color: AppTheme.warmGold.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                        )
                      : null,
                  child: Text(
                    isSelected ? '✓ SELECTED' : slot.periodTag,
                    style: GoogleFonts.inter(
                      fontSize: 8.5,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                      letterSpacing: isSelected ? 0.5 : 0,
                      color: isSelected
                          ? AppTheme.warmGold
                          : AppTheme.mediumGrey,
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Compact Confirmation Footer
  Widget _buildSelectedFeedbackFooter(bool isCompact, bool isFullyBooked) {
    if (isFullyBooked) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_rounded, size: 14, color: Color(0xFFDC2626)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Schedule is full • Please select another date above',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF991B1B),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    final hasSelected = widget.selectedStartTime != null && widget.selectedStartTime!.trim().isNotEmpty;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 12, vertical: 7),
      decoration: BoxDecoration(
        color: hasSelected ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasSelected ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
          width: hasSelected ? 1.2 : 1.0,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  hasSelected ? Icons.check_circle_rounded : Icons.touch_app_rounded,
                  size: 14,
                  color: hasSelected ? const Color(0xFF16A34A) : AppTheme.primaryColor,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    hasSelected
                        ? 'Confirmed: ${widget.selectedStartTime} ✓'
                        : 'Tap any slot above to set time',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: hasSelected ? FontWeight.w800 : FontWeight.w600,
                      color: hasSelected ? const Color(0xFF166534) : AppTheme.darkGrey,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (widget.onPickCustomTime != null) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: widget.onPickCustomTime,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule_rounded, size: 12, color: AppTheme.primaryColor),
                    const SizedBox(width: 3),
                    Text(
                      'Custom Time',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFullyBookedNotice() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.event_busy_rounded, size: 24, color: Color(0xFFDC2626)),
            ),
            const SizedBox(height: 8),
            Text(
              'No Available Slots Remaining',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'All time slots for this date are fully reserved.\nPlease pick another date from the calendar above.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppTheme.mediumGrey,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Modern Modal Bottom Sheet to inspect complete booked schedule breakdown
  void _showScheduleBreakdownBottomSheet(
    BuildContext context,
    List<_TimeRange> bookedRanges,
    bool isFullyBooked,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final startStr = _formatTime(DateTime(2000, 1, 1, _effectiveStartHour, 0));
        final endStr = _formatTime(DateTime(2000, 1, 1, _effectiveEndHour, 0));

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.78,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 24,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Drag Handle ──
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 38,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              // ── Header ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isFullyBooked
                            ? const Color(0xFFFEE2E2)
                            : AppTheme.forestGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isFullyBooked ? Icons.event_busy_rounded : Icons.event_available_rounded,
                        size: 20,
                        color: isFullyBooked ? const Color(0xFFDC2626) : AppTheme.forestGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isFullyBooked ? 'Fully Booked Schedule' : 'Scheduled Bookings',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.selectedDateText,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.mediumGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // ── Operating Hours Strip ──
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.storefront_rounded, size: 14, color: AppTheme.primaryColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Operating Hours: $startStr – $endStr',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: isFullyBooked ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isFullyBooked ? 'Full' : '${bookedRanges.length} Sched',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isFullyBooked ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── List of Scheduled Bookings ──
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: bookedRanges.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final b = bookedRanges[index];
                    final startFormatted = _formatTime(b.start);
                    final endFormatted = _formatTime(b.end);
                    final durationMin = b.end.difference(b.start).inMinutes;
                    final durationHrs = durationMin / 60.0;
                    final durationLabel = durationHrs % 1 == 0
                        ? '${durationHrs.toInt()} hrs'
                        : '${durationHrs.toStringAsFixed(1)} hrs';

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isFullyBooked
                              ? const Color(0xFFFECACA)
                              : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: isFullyBooked
                                      ? const Color(0xFFFEF2F2)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.lock_clock_rounded,
                                  size: 16,
                                  color: isFullyBooked
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$startFormatted – $endFormatted',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Reserved Event Window',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  durationLabel,
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF334155),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFFDE68A), width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.hourglass_top_rounded, size: 11, color: Color(0xFFB45309)),
                                const SizedBox(width: 4),
                                Text(
                                  '+2-Hr Interval: ${endFormatted} – ${_formatTime(b.end.add(const Duration(hours: 2)))} (Preparation)',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF92400E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 10),

              // ── Action / Close Button ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.forestGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Close',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyFilterNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No open slots in this selected period.',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.darkGrey),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => setState(() => _selectedPeriodFilter = 'all'),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.forestGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Switch to All Sessions',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Placeholder when no date is picked yet
  Widget _buildNoDatePrompt() {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.warmGold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.event_available_rounded,
              size: 18,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Venue Availability Preview',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkGrey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Select a reservation date above to preview venue openings and session slots.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.mediumGrey,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Loading state
  Widget _buildLoadingState() {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'Checking schedule for ${widget.selectedDateText}...',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.mediumGrey,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeRange {
  final DateTime start;
  final DateTime end;
  final bool isBooked;
  final String label;

  _TimeRange({
    required this.start,
    required this.end,
    required this.isBooked,
    required this.label,
  });
}

class _SlotCardData {
  final String timeString;
  final String periodTag;
  final int hour;
  final DateTime time;

  _SlotCardData({
    required this.timeString,
    required this.periodTag,
    required this.hour,
    required this.time,
  });
}

class _SessionGroup {
  final String id;
  final String title;
  final String timeSubtitle;
  final IconData icon;
  final Color accentColor;
  final List<_SlotCardData> slots;

  _SessionGroup({
    required this.id,
    required this.title,
    required this.timeSubtitle,
    required this.icon,
    required this.accentColor,
    required this.slots,
  });
}
