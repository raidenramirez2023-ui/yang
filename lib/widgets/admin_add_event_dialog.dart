import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/pages/customer/menu_selection_page.dart';
import 'package:yang_chow/services/menu_reservation_service.dart';
import 'package:yang_chow/services/menu_service.dart';
import 'package:yang_chow/services/reservation_service.dart';
import 'package:yang_chow/utils/app_constants.dart';
import 'package:yang_chow/utils/responsive_utils.dart';

class AdminAddEventDialog extends StatefulWidget {
  final VoidCallback onEventCreated;

  const AdminAddEventDialog({
    super.key,
    required this.onEventCreated,
  });

  static Future<void> show(BuildContext context, {required VoidCallback onEventCreated}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AdminAddEventDialog(onEventCreated: onEventCreated),
    );
  }

  @override
  State<AdminAddEventDialog> createState() => _AdminAddEventDialogState();
}

class _AdminAddEventDialogState extends State<AdminAddEventDialog> {
  final _formKey = GlobalKey<FormState>();
  final ReservationService _reservationService = ReservationService();
  final MenuReservationService _menuReservationService = MenuReservationService();

  // Guest/Customer Selection
  bool _isRegisteredCustomer = false;
  List<Map<String, dynamic>> _registeredCustomers = [];
  bool _isLoadingCustomers = false;
  Map<String, dynamic>? _selectedCustomer;

  // Controllers for Customer Info
  final TextEditingController _customerSearchController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController = TextEditingController();
  final TextEditingController _customerEmailController = TextEditingController();

  // Event Fields
  String? _selectedEventType;
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _guestsController = TextEditingController();
  final TextEditingController _specialRequestsController = TextEditingController();

  // Duration
  String? _selectedBaseDuration = '2 hours';
  bool _addExtraTime = false;
  String? _selectedExtraTime;
  double _totalDurationHours = 2.0;

  // Menu Selection
  final Map<String, int> _selectedMenuItems = {};
  bool _isMenuExpanded = false;

  // Payment Option
  String _paymentOption = 'half'; // 'half' (50% Deposit) or 'full' (Pay in Full)
  String _paymentMethod = 'cash'; // 'cash', 'gcash', 'paymongo'
  String _initialStatus = 'confirmed'; // 'confirmed' or 'pending'

  bool _isSubmitting = false;

  // Design Tokens
  static const _darkBg = Color(0xFF0F172A);
  static const _emerald = Color(0xFF14332E);
  static const _gold = Color(0xFFD9A441);
  static const _slate = Color(0xFF64748B);
  static const _slateLight = Color(0xFFE2E8F0);

  final List<String> _baseDurations = [
    '2 hours',
    '3 hours',
  ];

  final List<String> _extraTimeOptions = [
    '30 minutes',
    '1 hour',
    '1 hour and 30 minutes',
  ];

  @override
  void initState() {
    super.initState();
    _loadRegisteredCustomers();
    _updateTotalDuration();
  }

  @override
  void dispose() {
    _customerSearchController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerEmailController.dispose();
    _dateController.dispose();
    _startTimeController.dispose();
    _guestsController.dispose();
    _specialRequestsController.dispose();
    super.dispose();
  }

  Future<void> _loadRegisteredCustomers() async {
    setState(() => _isLoadingCustomers = true);
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('*')
          .eq('role', 'customer');

      List<Map<String, dynamic>> customers = List<Map<String, dynamic>>.from(response);

      // Fallback: if no users in users table with role='customer', also grab unique past reservation clients
      if (customers.isEmpty) {
        final pastRes = await Supabase.instance.client
            .from('reservations')
            .select('customer_name, customer_email, customer_phone')
            .order('created_at', ascending: false)
            .limit(100);

        final seen = <String>{};
        for (final r in pastRes) {
          final email = (r['customer_email'] ?? '').toString().trim();
          if (email.isNotEmpty && !seen.contains(email)) {
            seen.add(email);
            customers.add({
              'id': email,
              'firstname': r['customer_name'] ?? '',
              'lastname': '',
              'email': email,
              'phone': r['customer_phone'] ?? '',
            });
          }
        }
      }

      // Sort alphabetically
      customers.sort((a, b) {
        final nameA = _getCustomerDisplayName(a).toLowerCase();
        final nameB = _getCustomerDisplayName(b).toLowerCase();
        return nameA.compareTo(nameB);
      });

      if (mounted) {
        setState(() {
          _registeredCustomers = customers;
          _isLoadingCustomers = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading registered customers: $e');
      if (mounted) setState(() => _isLoadingCustomers = false);
    }
  }

  String _getCustomerDisplayName(Map<String, dynamic> c) {
    final first = (c['firstname'] ?? '').toString().trim();
    final last = (c['lastname'] ?? '').toString().trim();
    final full = '$first $last'.trim();
    if (full.isNotEmpty) return full;
    if (c['name'] != null && c['name'].toString().trim().isNotEmpty) {
      return c['name'].toString().trim();
    }
    if (c['customer_name'] != null && c['customer_name'].toString().trim().isNotEmpty) {
      return c['customer_name'].toString().trim();
    }
    return (c['email'] ?? 'Customer').toString();
  }

  void _updateTotalDuration() {
    double base = _selectedBaseDuration == '3 hours' ? 3.0 : 2.0;

    double extra = 0.0;
    if (_addExtraTime && _selectedExtraTime != null) {
      if (_selectedExtraTime == '30 minutes') {
        extra = 0.5;
      } else if (_selectedExtraTime == '1 hour') {
        extra = 1.0;
      } else if (_selectedExtraTime == '1 hour and 30 minutes') {
        extra = 1.5;
      }
    }

    setState(() {
      _totalDurationHours = base + extra;
    });
  }

  void _onCustomerSelected(Map<String, dynamic>? customer) {
    setState(() {
      _selectedCustomer = customer;
      if (customer != null) {
        final name = _getCustomerDisplayName(customer);
        final email = (customer['email'] ?? '').toString();
        final phone = (customer['phone'] ?? customer['phone_number'] ?? customer['customer_phone'] ?? '').toString();
        _customerSearchController.text = email.isNotEmpty ? '$name ($email)' : name;
        _customerNameController.text = name;
        _customerEmailController.text = email;
        _customerPhoneController.text = phone;
      } else {
        _customerSearchController.clear();
        _customerNameController.clear();
        _customerEmailController.clear();
        _customerPhoneController.clear();
      }
    });
  }

  Future<void> _pickDate() async {
    // 4 days lead time requirement matching Customer side Event Reservation
    final minDate = DateTime.now().add(const Duration(days: 4));
    final fullyBooked = await _reservationService.getFullyBookedEventDates();

    DateTime initialDate = minDate;
    while (fullyBooked.contains(DateFormat('yyyy-MM-dd').format(initialDate))) {
      initialDate = initialDate.add(const Duration(days: 1));
    }

    if (!mounted) return;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: minDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      selectableDayPredicate: (DateTime day) {
        final dStr = DateFormat('yyyy-MM-dd').format(day);
        return !fullyBooked.contains(dStr);
      },
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _emerald,
              onPrimary: Colors.white,
              onSurface: _darkBg,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _dateController.text = DateFormat('MMMM d, yyyy').format(pickedDate);
      });

      // Check slot overlap if start time was already selected
      if (_startTimeController.text.isNotEmpty) {
        final dateStr = DateFormat('yyyy-MM-dd').format(pickedDate);
        final overlap = await _reservationService.isTimeSlotOverlapping(
          eventDate: dateStr,
          startTime: _startTimeController.text.trim(),
          durationHours: _totalDurationHours,
        );
        if (overlap && mounted) {
          _showToast(
            'The selected time (${_startTimeController.text}) on ${DateFormat('MMMM d').format(pickedDate)} is already booked. Please pick another time.',
            isError: true,
          );
          setState(() => _startTimeController.clear());
        }
      }
    }
  }

  Future<void> _pickTime() async {
    const startHour = 10;
    const endHour = 19;

    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _emerald,
              onPrimary: Colors.white,
              onSurface: _darkBg,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    // Check operating hours: 10:00 AM to 7:00 PM (19:00)
    if (picked.hour < startHour ||
        picked.hour > endHour ||
        (picked.hour == endHour && picked.minute > 0)) {
      _showToast(
        'Please select a time between ${startHour.toString().padLeft(2, '0')}:00 and ${endHour.toString().padLeft(2, '0')}:00',
        isError: true,
      );
      return;
    }

    final period = picked.period == DayPeriod.am ? 'AM' : 'PM';
    final hourOfPeriod = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
    final minuteStr = picked.minute.toString().padLeft(2, '0');
    final formattedTime = '$hourOfPeriod:$minuteStr $period';

    if (_dateController.text.isNotEmpty) {
      try {
        final parsedDate = DateFormat('MMMM d, yyyy').parse(_dateController.text.trim());
        final dateStr = DateFormat('yyyy-MM-dd').format(parsedDate);
        final overlap = await _reservationService.isTimeSlotOverlapping(
          eventDate: dateStr,
          startTime: formattedTime,
          durationHours: _totalDurationHours,
        );
        if (overlap && mounted) {
          _showToast(
            'This time slot ($formattedTime) is already booked on this date. Please choose a different time.',
            isError: true,
          );
          return;
        }
      } catch (e) {
        debugPrint('Error validating time overlap: $e');
      }
    }

    setState(() {
      _startTimeController.text = formattedTime;
    });
  }

  void _navigateToMenuSelection() {
    final guestCount = int.tryParse(_guestsController.text.trim()) ?? 10;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MenuSelectionPage(
          reservationType: 'Event Place',
          guestCount: guestCount,
          initialSelection: _selectedMenuItems,
          onMenuSelected: (selection) {
            setState(() {
              _selectedMenuItems.clear();
              _selectedMenuItems.addAll(selection);
              if (selection.isNotEmpty) {
                _isMenuExpanded = true;
              }
            });
          },
        ),
      ),
    );
  }

  void _showAlertModal({
    required String title,
    required String message,
    bool isError = true,
  }) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isError ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isError ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                    width: 2,
                  ),
                ),
                child: Icon(
                  isError ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                  color: isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _darkBg,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _slate,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isError ? const Color(0xFFDC2626) : _emerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: Text(
                    'Got it',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showToast(String message, {bool isError = false}) {
    _showAlertModal(
      title: isError ? 'Attention Required' : 'Success',
      message: message,
      isError: isError,
    );
  }

  Future<void> _submitReservation() async {
    if (!_formKey.currentState!.validate()) {
      _showToast('Please fill in all required fields marked with *', isError: true);
      return;
    }

    // 1. Guest / Customer Name check
    final customerName = _customerNameController.text.trim();
    if (customerName.isEmpty) {
      _showToast('Guest / Customer Name is required', isError: true);
      return;
    }

    // 2. Contact Number check (Required & 11 digits)
    final customerPhone = _customerPhoneController.text.trim();
    if (customerPhone.isEmpty) {
      _showToast('Contact Number is required', isError: true);
      return;
    }
    if (customerPhone.length != 11) {
      _showToast('Contact number must be exactly 11 digits (e.g. 09123456789)', isError: true);
      return;
    }

    // 3. Event Type check
    if (_selectedEventType == null || _selectedEventType!.isEmpty) {
      _showToast('Please select an Event Type', isError: true);
      return;
    }

    // 4. Date check
    if (_dateController.text.trim().isEmpty) {
      _showToast('Please select an Event Date', isError: true);
      return;
    }

    // 5. Start Time check
    if (_startTimeController.text.trim().isEmpty) {
      _showToast('Please select a Start Time', isError: true);
      return;
    }

    // 6. Duration check
    if (_selectedBaseDuration == null || _selectedBaseDuration!.isEmpty) {
      _showToast('Please select a Duration', isError: true);
      return;
    }

    // 7. Guests check
    if (_guestsController.text.trim().isEmpty) {
      _showToast('Number of Guests is required (Allowed: 10 to 100)', isError: true);
      return;
    }
    final guestCount = int.tryParse(_guestsController.text.trim());
    if (guestCount == null || guestCount < 10 || guestCount > 100) {
      _showToast('Number of guests must be between 10 and 100', isError: true);
      return;
    }

    // 8. Menu Selection check (Strictly required!)
    if (_selectedMenuItems.isEmpty) {
      _showToast('Menu Selection is required! Please select at least 1 menu dish.', isError: true);
      return;
    }

    final currentUser = Supabase.instance.client.auth.currentUser;
    final adminEmail = currentUser?.email ?? 'admin@yangchow.com';

    String customerEmail = _customerEmailController.text.trim();
    if (customerEmail.isEmpty) {
      // Walk-in guest without account is marked as N/A
      customerEmail = 'N/A';
    }

    setState(() => _isSubmitting = true);

    try {
      final parsedDate = DateFormat('MMMM d, yyyy').parse(_dateController.text.trim());
      final formattedDate = DateFormat('yyyy-MM-dd').format(parsedDate);

      // Verify time overlap one final time before creating
      final isOverlapping = await _reservationService.isTimeSlotOverlapping(
        eventDate: formattedDate,
        startTime: _startTimeController.text.trim(),
        durationHours: _totalDurationHours,
      );

      if (isOverlapping) {
        setState(() => _isSubmitting = false);
        _showToast('This time slot was just booked by another reservation. Please choose a different time.', isError: true);
        return;
      }

      final menuSubtotal = _menuReservationService.calculateMenuTotalPrice(_selectedMenuItems);
      final depositAmount = _paymentOption == 'full'
          ? menuSubtotal
          : _menuReservationService.calculateMenuDepositAmount(menuSubtotal, reservationType: 'Event Place');

      if (_selectedMenuItems.isNotEmpty) {
        await _reservationService.createMenuBasedReservation(
          customerEmail: customerEmail,
          customerName: customerName,
          eventType: _selectedEventType!,
          eventDate: formattedDate,
          startTime: _startTimeController.text.trim(),
          durationHours: _totalDurationHours,
          numberOfGuests: guestCount,
          specialRequests: _specialRequestsController.text.trim().isEmpty ? null : _specialRequestsController.text.trim(),
          customerPhone: customerPhone.isNotEmpty ? customerPhone : null,
          customerAddress: null,
          selectedMenuItems: _selectedMenuItems,
          totalMenuPrice: menuSubtotal,
          depositAmount: depositAmount,
          paymentOption: _paymentOption,
          paymentMethod: _paymentMethod,
          transactedBy: adminEmail,
          status: _initialStatus,
          paymentStatus: _paymentOption == 'full' ? 'paid' : 'deposit_paid',
        );
      } else {
        await _reservationService.createReservation(
          customerEmail: customerEmail,
          customerName: customerName,
          eventType: _selectedEventType!,
          eventDate: formattedDate,
          startTime: _startTimeController.text.trim(),
          durationHours: _totalDurationHours,
          numberOfGuests: guestCount,
          specialRequests: _specialRequestsController.text.trim().isEmpty ? null : _specialRequestsController.text.trim(),
          customerPhone: customerPhone.isNotEmpty ? customerPhone : null,
          customerAddress: null,
          paymentOption: _paymentOption,
          paymentMethod: _paymentMethod,
          transactedBy: adminEmail,
          status: _initialStatus,
          paymentStatus: 'unpaid',
        );
      }

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      Navigator.of(context).pop();

      _showToast('Event reservation created successfully for $customerName!');
      widget.onEventCreated();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showToast('Error creating reservation: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final isMobile = screenWidth < 600;
    final dialogWidth = isDesktop ? 680.0 : screenWidth * (isMobile ? 0.96 : 0.92);
    final menuItemsCount = _selectedMenuItems.values.fold(0, (sum, qty) => sum + qty);
    final menuSubtotal = _menuReservationService.calculateMenuTotalPrice(_selectedMenuItems);
    final halfDepositRequired = _menuReservationService.calculateMenuDepositAmount(menuSubtotal, reservationType: 'Event Place');
    final totalPayableNow = _paymentOption == 'full' ? menuSubtotal : halfDepositRequired;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16, vertical: isMobile ? 12 : 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth, maxHeight: MediaQuery.of(context).size.height * 0.92),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _darkBg.withValues(alpha: 0.25),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Modal Header ──
              _buildDialogHeader(),

              // ── Scrollable Form Body ──
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 24, vertical: 16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Walk-in Guest / Registered Customer Selection
                        _buildSectionHeader(
                          icon: Icons.person_search_rounded,
                          title: 'GUEST / CUSTOMER DETAILS',
                          subtitle: 'Book for a walk-in guest or select an existing customer account',
                          isRequired: true,
                        ),
                        const SizedBox(height: 10),
                        _buildCustomerTypeToggle(),
                        const SizedBox(height: 12),
                        if (_isRegisteredCustomer) ...[
                          _buildRegisteredCustomerDropdown(),
                          const SizedBox(height: 12),
                        ],
                        _buildCustomerInputFields(),
                        const SizedBox(height: 22),

                        // 2. Event Type
                        _buildSectionHeader(
                          icon: Icons.celebration_rounded,
                          title: 'EVENT TYPE',
                          subtitle: 'Select the occasion for this private hall booking',
                          isRequired: true,
                        ),
                        const SizedBox(height: 8),
                        _buildEventTypeDropdown(),
                        const SizedBox(height: 22),

                        // 3. Schedule: Date & Time
                        _buildSectionHeader(
                          icon: Icons.calendar_today_rounded,
                          title: 'DATE & TIME',
                          subtitle: 'Select reservation schedule (Operating Hours: 10 AM – 7 PM)',
                          isRequired: true,
                        ),
                        const SizedBox(height: 8),
                        _buildDateTimeRow(),
                        const SizedBox(height: 22),

                        // 4. Duration
                        _buildSectionHeader(
                          icon: Icons.timer_rounded,
                          title: 'DURATION',
                          subtitle: 'Base hall reservation hours and optional extra time extension',
                          isRequired: true,
                        ),
                        const SizedBox(height: 8),
                        _buildDurationSelector(),
                        const SizedBox(height: 22),

                        // 5. Number of Guests
                        _buildSectionHeader(
                          icon: Icons.groups_rounded,
                          title: 'NUMBER OF GUESTS',
                          subtitle: 'Minimum 10 to maximum 100 attendees',
                          isRequired: true,
                        ),
                        const SizedBox(height: 8),
                        _buildGuestsField(),
                        const SizedBox(height: 22),

                        // 6. Menu Selection
                        _buildSectionHeader(
                          icon: Icons.restaurant_menu_rounded,
                          title: 'MENU SELECTION',
                          subtitle: 'Pick catering banquet dishes from the digital menu',
                          isRequired: true,
                        ),
                        const SizedBox(height: 8),
                        _buildMenuSelectionBox(menuItemsCount, menuSubtotal, halfDepositRequired),
                        const SizedBox(height: 22),

                        // 7. Payment Option & Settlement
                        _buildSectionHeader(
                          icon: Icons.payments_rounded,
                          title: 'PAYMENT OPTION',
                          subtitle: 'Choose payment terms and payment method for this booking',
                        ),
                        const SizedBox(height: 8),
                        _buildPaymentOptionSelector(halfDepositRequired, menuSubtotal),
                        const SizedBox(height: 22),

                        // 8. Special Requests (Optional)
                        _buildSectionHeader(
                          icon: Icons.edit_note_rounded,
                          title: 'SPECIAL REQUESTS (OPTIONAL)',
                          subtitle: 'Setup arrangements, dietary preferences, or specific notes',
                        ),
                        const SizedBox(height: 8),
                        _buildSpecialRequestsField(),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Bottom Action Footer ──
              _buildDialogFooter(totalPayableNow),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_emerald, Color(0xFF1E4A42)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: const Icon(Icons.add_business_rounded, color: _gold, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Event Reservation',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Create an event booking directly for walk-in or registered guests',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFFD9A441),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    bool isRequired = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: _gold),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _darkBg,
                      letterSpacing: 0.8,
                    ),
                  ),
                  if (isRequired) ...[
                    const SizedBox(width: 4),
                    const Text(
                      '*',
                      style: TextStyle(
                        color: Color(0xFFDC2626),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: _slate,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerTypeToggle() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 420;
        final toggleButtons = [
          InkWell(
            onTap: () {
              setState(() {
                _isRegisteredCustomer = false;
                _onCustomerSelected(null);
              });
            },
            borderRadius: BorderRadius.circular(9),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: BoxDecoration(
                color: !_isRegisteredCustomer ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                boxShadow: !_isRegisteredCustomer
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_add_alt_1_rounded,
                    size: 15,
                    color: !_isRegisteredCustomer ? _emerald : _slate,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      isNarrow ? 'Walk-in Guest' : 'Walk-in Guest (No Account)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: !_isRegisteredCustomer ? FontWeight.w800 : FontWeight.w600,
                        color: !_isRegisteredCustomer ? _emerald : _slate,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: () {
              setState(() {
                _isRegisteredCustomer = true;
              });
            },
            borderRadius: BorderRadius.circular(9),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: BoxDecoration(
                color: _isRegisteredCustomer ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                boxShadow: _isRegisteredCustomer
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.verified_user_rounded,
                    size: 15,
                    color: _isRegisteredCustomer ? _emerald : _slate,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Registered Customer',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: _isRegisteredCustomer ? FontWeight.w800 : FontWeight.w600,
                        color: _isRegisteredCustomer ? _emerald : _slate,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ];

        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _slateLight),
          ),
          child: Row(
            children: [
              Expanded(child: toggleButtons[0]),
              const SizedBox(width: 4),
              Expanded(child: toggleButtons[1]),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRegisteredCustomerDropdown() {
    if (_isLoadingCustomers) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _slateLight),
        ),
        child: const Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: _emerald),
          ),
        ),
      );
    }
    if (_registeredCustomers.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _slateLight),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, size: 18, color: _slate),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No customer accounts found. You can type guest details below.',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _slate, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton.icon(
              onPressed: _loadRegisteredCustomers,
              icon: const Icon(Icons.refresh_rounded, size: 14, color: _emerald),
              label: Text('Retry', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _emerald, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }

    return RawAutocomplete<Map<String, dynamic>>(
      textEditingController: _customerSearchController,
      focusNode: FocusNode(),
      displayStringForOption: (Map<String, dynamic> c) {
        final name = _getCustomerDisplayName(c);
        final email = (c['email'] ?? '').toString();
        return email.isNotEmpty ? '$name ($email)' : name;
      },
      optionsBuilder: (TextEditingValue textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) {
          return _registeredCustomers;
        }
        return _registeredCustomers.where((c) {
          final name = _getCustomerDisplayName(c).toLowerCase();
          final email = (c['email'] ?? '').toString().toLowerCase();
          final phone = (c['phone'] ?? c['phone_number'] ?? c['customer_phone'] ?? '').toString().toLowerCase();
          return name.contains(query) || email.contains(query) || phone.contains(query);
        });
      },
      onSelected: (Map<String, dynamic> selection) {
        _onCustomerSelected(selection);
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _darkBg, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            labelText: 'Search & Select Registered Customer',
            labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: _slate),
            hintText: 'Type customer name, email, or phone...',
            hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: _slate.withValues(alpha: 0.6)),
            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _emerald),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16, color: _slate),
                    tooltip: 'Clear selection',
                    onPressed: () {
                      controller.clear();
                      _onCustomerSelected(null);
                    },
                  )
                : const Icon(Icons.arrow_drop_down_rounded, size: 22, color: _slate),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _slateLight)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _slateLight)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _emerald, width: 1.5)),
          ),
          onChanged: (val) {
            if (_selectedCustomer != null && val.trim().isEmpty) {
              _onCustomerSelected(null);
            }
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            shadowColor: _darkBg.withValues(alpha: 0.18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 630),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  final c = options.elementAt(index);
                  final name = _getCustomerDisplayName(c);
                  final email = (c['email'] ?? '').toString();
                  final phone = (c['phone'] ?? c['phone_number'] ?? c['customer_phone'] ?? '').toString();

                  return InkWell(
                    onTap: () => onSelected(c),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: _emerald.withValues(alpha: 0.1),
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'C',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: _emerald),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: _darkBg),
                                ),
                                if (email.isNotEmpty || phone.isNotEmpty)
                                  Text(
                                    [if (email.isNotEmpty) email, if (phone.isNotEmpty) phone].join(' • '),
                                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _slate),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: _slate),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomerInputFields() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 450;
        final nameField = TextFormField(
          controller: _customerNameController,
          readOnly: _isRegisteredCustomer && _selectedCustomer != null,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _darkBg, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            labelText: 'Guest / Customer Name *',
            labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: _slate),
            hintText: 'e.g. Juan Dela Cruz',
            hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: _slate.withValues(alpha: 0.6)),
            prefixIcon: const Icon(Icons.badge_rounded, size: 18, color: _slate),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _slateLight)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _slateLight)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _emerald, width: 1.5)),
          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Name is required';
            }
            return null;
          },
        );

        final phoneField = TextFormField(
          controller: _customerPhoneController,
          readOnly: _isRegisteredCustomer && _selectedCustomer != null,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _darkBg, fontWeight: FontWeight.w600),
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
          decoration: InputDecoration(
            labelText: 'Contact Number (11 digits) *',
            labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: _slate),
            hintText: '09xxxxxxxxx',
            hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: _slate.withValues(alpha: 0.6)),
            prefixIcon: const Icon(Icons.phone_rounded, size: 18, color: _slate),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _slateLight)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _slateLight)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _emerald, width: 1.5)),
          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Phone is required';
            }
            if (val.trim().length != 11) {
              return 'Must be 11 digits';
            }
            return null;
          },
        );

        if (isNarrow) {
          return Column(
            children: [
              nameField,
              const SizedBox(height: 10),
              phoneField,
            ],
          );
        }

        return Row(
          children: [
            Expanded(flex: 3, child: nameField),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: phoneField),
          ],
        );
      },
    );
  }

  Widget _buildEventTypeDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedEventType,
      decoration: InputDecoration(
        hintText: 'Select event type...',
        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: _slate),
        prefixIcon: const Icon(Icons.local_activity_rounded, size: 18, color: _emerald),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _slateLight)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _slateLight)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _emerald, width: 1.5)),
      ),
      items: AppConstants.eventTypes.map((type) {
        return DropdownMenuItem<String>(
          value: type,
          child: Text(type, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _darkBg, fontWeight: FontWeight.w600)),
        );
      }).toList(),
      validator: (val) {
        if (val == null || val.isEmpty) {
          return 'Please select an event type';
        }
        return null;
      },
      onChanged: (val) => setState(() => _selectedEventType = val),
    );
  }

  Widget _buildDateTimeRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;

        final dateButton = InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _dateController.text.isNotEmpty ? _emerald : _slateLight,
                width: _dateController.text.isNotEmpty ? 1.4 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 18,
                  color: _dateController.text.isNotEmpty ? _emerald : _slate,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Event Date', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: _slate, fontWeight: FontWeight.w700)),
                      Text(
                        _dateController.text.isNotEmpty ? _dateController.text : 'Select Date',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          color: _dateController.text.isNotEmpty ? _darkBg : _slate,
                          fontWeight: _dateController.text.isNotEmpty ? FontWeight.w700 : FontWeight.w500,
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
        );

        final timeButton = InkWell(
          onTap: _pickTime,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _startTimeController.text.isNotEmpty ? _emerald : _slateLight,
                width: _startTimeController.text.isNotEmpty ? 1.4 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.access_time_filled_rounded,
                  size: 18,
                  color: _startTimeController.text.isNotEmpty ? _emerald : _slate,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Start Time', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: _slate, fontWeight: FontWeight.w700)),
                      Text(
                        _startTimeController.text.isNotEmpty ? _startTimeController.text : 'Select Time',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          color: _startTimeController.text.isNotEmpty ? _darkBg : _slate,
                          fontWeight: _startTimeController.text.isNotEmpty ? FontWeight.w700 : FontWeight.w500,
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
        );

        if (isNarrow) {
          return Column(
            children: [
              dateButton,
              const SizedBox(height: 10),
              timeButton,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: dateButton),
            const SizedBox(width: 10),
            Expanded(child: timeButton),
          ],
        );
      },
    );
  }

  Widget _buildDurationSelector() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _slateLight),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedBaseDuration,
                  decoration: InputDecoration(
                    labelText: 'Base Duration',
                    labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: _slate),
                    prefixIcon: const Icon(Icons.timelapse_rounded, size: 18, color: _emerald),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slateLight)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slateLight)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _emerald, width: 1.5)),
                  ),
                  items: _baseDurations.map((d) {
                    return DropdownMenuItem<String>(
                      value: d,
                      child: Text(d, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _darkBg, fontWeight: FontWeight.w600)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedBaseDuration = val;
                      _updateTotalDuration();
                    });
                  },
                ),
              ),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _emerald.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Total: ${_totalDurationHours % 1 == 0 ? _totalDurationHours.toInt().toString() : _totalDurationHours.toStringAsFixed(1)} hrs',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: _emerald),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.history_toggle_off_rounded, size: 16, color: _emerald),
                  const SizedBox(width: 6),
                  Text(
                    'Add Extra Hours Extension',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: _darkBg),
                  ),
                ],
              ),
              Switch(
                value: _addExtraTime,
                activeTrackColor: _emerald,
                activeThumbColor: _gold,
                onChanged: (val) {
                  setState(() {
                    _addExtraTime = val;
                    if (!_addExtraTime) _selectedExtraTime = null;
                    _updateTotalDuration();
                  });
                },
              ),
            ],
          ),
          if (_addExtraTime) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedExtraTime,
              decoration: InputDecoration(
                labelText: 'Extra Hours',
                labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: _slate),
                prefixIcon: const Icon(Icons.add_alarm_rounded, size: 18, color: _emerald),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slateLight)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slateLight)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _emerald, width: 1.5)),
              ),
              hint: Text('Select extra duration...', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _slate)),
              items: _extraTimeOptions.map((d) {
                return DropdownMenuItem<String>(
                  value: d,
                  child: Text(d, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _darkBg, fontWeight: FontWeight.w600)),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedExtraTime = val;
                  _updateTotalDuration();
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGuestsField() {
    return TextFormField(
      controller: _guestsController,
      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: _darkBg, fontWeight: FontWeight.w700),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
        TextInputFormatter.withFunction((oldValue, newValue) {
          if (newValue.text.isEmpty) return newValue;
          final int? val = int.tryParse(newValue.text);
          if (val == null) return oldValue;
          if (val > 100) {
            return const TextEditingValue(
              text: '100',
              selection: TextSelection.collapsed(offset: 3),
            );
          }
          return newValue;
        }),
      ],
      decoration: InputDecoration(
        hintText: 'e.g. 30',
        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: _slate.withValues(alpha: 0.6)),
        prefixIcon: const Icon(Icons.people_alt_rounded, size: 18, color: _emerald),
        suffixText: 'Guests (Allowed: 10–100)',
        suffixStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: _slate, fontWeight: FontWeight.w600),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _slateLight)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _slateLight)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _emerald, width: 1.5)),
      ),
      validator: (val) {
        if (val == null || val.trim().isEmpty) return 'Please enter guest count';
        final count = int.tryParse(val.trim());
        if (count == null || count < 10 || count > 100) return 'Guests must be between 10 and 100';
        return null;
      },
    );
  }

  Widget _buildMenuSelectionBox(int menuItemsCount, double menuSubtotal, double depositRequired) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _slateLight),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _emerald.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.dinner_dining_rounded, size: 18, color: _emerald),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedMenuItems.isEmpty ? 'No dishes selected yet' : '$menuItemsCount dishes chosen',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _darkBg,
                        ),
                      ),
                      Text(
                        _selectedMenuItems.isEmpty
                            ? 'Tap button below to select catering dishes'
                            : 'Subtotal: ₱${NumberFormat('#,##0.00').format(menuSubtotal)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: _selectedMenuItems.isEmpty ? _slate : const Color(0xFF15803D),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (_selectedMenuItems.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => setState(() => _isMenuExpanded = !_isMenuExpanded),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _emerald.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _emerald.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Text(
                              _isMenuExpanded ? 'Hide' : 'View Dishes',
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _emerald, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _isMenuExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: _emerald,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _selectedMenuItems.clear();
                        _isMenuExpanded = false;
                      }),
                      icon: const Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFDC2626)),
                      label: Text('Clear', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFFDC2626), fontWeight: FontWeight.w700)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // ── Collapsible Dropdown for Chosen Dishes ──
          if (_selectedMenuItems.isNotEmpty && _isMenuExpanded) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _slateLight),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('SELECTED DISHES & QUANTITY', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: _slate)),
                        Text('${_selectedMenuItems.length} distinct item(s)', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: _emerald)),
                      ],
                    ),
                  ),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _selectedMenuItems.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final entry = _selectedMenuItems.entries.elementAt(index);
                      final itemName = entry.key;
                      final quantity = entry.value;

                      // Find item price
                      double itemPrice = 0.0;
                      final menu = MenuService.getMenu();
                      for (final cat in menu.values) {
                        try {
                          final found = cat.firstWhere((m) => m.name == itemName);
                          itemPrice = found.price;
                          break;
                        } catch (_) {}
                      }
                      final itemTotal = itemPrice * quantity;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        child: Row(
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: _emerald.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${index + 1}',
                                style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: _emerald),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    itemName,
                                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: _darkBg),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (itemPrice > 0)
                                    Text(
                                      '₱${NumberFormat('#,##0.00').format(itemPrice)} each',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 10, color: _slate, fontWeight: FontWeight.w500),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _slateLight),
                              ),
                              child: Text(
                                'x$quantity',
                                style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: _darkBg),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 75,
                              child: Text(
                                '₱${NumberFormat('#,##0.00').format(itemTotal)}',
                                textAlign: TextAlign.right,
                                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: _darkBg),
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
          ],

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _navigateToMenuSelection,
              icon: const Icon(Icons.menu_book_rounded, size: 16),
              label: Text(
                _selectedMenuItems.isEmpty ? 'Open Menu Selection' : 'Modify Menu Selection (${_selectedMenuItems.length} items)',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _emerald,
                foregroundColor: _gold,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          if (_selectedMenuItems.isEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFDC2626)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '* Required: At least 1 menu dish must be chosen to proceed',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFFDC2626), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentOptionSelector(double halfDepositRequired, double menuSubtotal) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 450;

        final halfCard = InkWell(
          onTap: () => setState(() => _paymentOption = 'half'),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _paymentOption == 'half' ? _emerald.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _paymentOption == 'half' ? _emerald : _slateLight,
                width: _paymentOption == 'half' ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _paymentOption == 'half' ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  size: 16,
                  color: _paymentOption == 'half' ? _emerald : _slate,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '50% Downpayment',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _darkBg,
                        ),
                      ),
                      Text(
                        '₱${NumberFormat('#,##0.00').format(halfDepositRequired)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

        final fullCard = InkWell(
          onTap: () => setState(() => _paymentOption = 'full'),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _paymentOption == 'full' ? _emerald.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _paymentOption == 'full' ? _emerald : _slateLight,
                width: _paymentOption == 'full' ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _paymentOption == 'full' ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  size: 16,
                  color: _paymentOption == 'full' ? _emerald : _slate,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pay in Full (100%)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _darkBg,
                        ),
                      ),
                      Text(
                        '₱${NumberFormat('#,##0.00').format(menuSubtotal)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

        final methodDropdown = DropdownButtonFormField<String>(
          value: _paymentMethod,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Payment Method',
            labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: _slate),
            prefixIcon: const Icon(Icons.point_of_sale_rounded, size: 18, color: _emerald),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slateLight)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slateLight)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _emerald, width: 1.5)),
          ),
          items: const [
            DropdownMenuItem(value: 'cash', child: Text('Cash on Site', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 'gcash', child: Text('GCash QR', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 'paymongo', child: Text('PayMongo / Online', overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (val) => setState(() => _paymentMethod = val ?? 'cash'),
        );

        final statusDropdown = DropdownButtonFormField<String>(
          value: _initialStatus,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Initial Status',
            labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: _slate),
            prefixIcon: const Icon(Icons.task_alt_rounded, size: 18, color: _emerald),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slateLight)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slateLight)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _emerald, width: 1.5)),
          ),
          items: const [
            DropdownMenuItem(value: 'confirmed', child: Text('Confirmed', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 'pending', child: Text('Pending Approval', overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (val) => setState(() => _initialStatus = val ?? 'confirmed'),
        );

        return Column(
          children: [
            if (isNarrow) ...[
              halfCard,
              const SizedBox(height: 8),
              fullCard,
            ] else ...[
              Row(
                children: [
                  Expanded(child: halfCard),
                  const SizedBox(width: 10),
                  Expanded(child: fullCard),
                ],
              ),
            ],
            const SizedBox(height: 10),
            if (isNarrow) ...[
              methodDropdown,
              const SizedBox(height: 10),
              statusDropdown,
            ] else ...[
              Row(
                children: [
                  Expanded(child: methodDropdown),
                  const SizedBox(width: 10),
                  Expanded(child: statusDropdown),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSpecialRequestsField() {
    return TextFormField(
      controller: _specialRequestsController,
      maxLines: 2,
      style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _darkBg),
      decoration: InputDecoration(
        hintText: 'e.g. VIP tables setup, specific beverage preferences, stage area needed...',
        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: _slate.withValues(alpha: 0.6)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.all(12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _slateLight)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _slateLight)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _emerald, width: 1.5)),
      ),
    );
  }

  Widget _buildDialogFooter(double totalPayableNow) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 480;

        final payableInfo = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Total Payable:',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _slate, fontWeight: FontWeight.w600),
            ),
            Text(
              '₱${NumberFormat('#,##0.00').format(totalPayableNow)}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF15803D),
              ),
            ),
          ],
        );

        final actionButtons = Row(
          mainAxisSize: isNarrow ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Expanded(
              flex: isNarrow ? 1 : 0,
              child: OutlinedButton(
                onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  side: const BorderSide(color: _slateLight),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Cancel', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: _slate)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: isNarrow ? 2 : 0,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitReservation,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_rounded, size: 16),
                label: Text(
                  _isSubmitting ? 'Creating...' : (isNarrow ? 'Create Event' : 'Create Event Reservation'),
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _emerald,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: isNarrow ? 12 : 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
              ),
            ),
          ],
        );

        return Container(
          padding: EdgeInsets.symmetric(horizontal: isNarrow ? 16 : 24, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
            border: Border(top: BorderSide(color: _slateLight)),
          ),
          child: isNarrow
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        payableInfo,
                      ],
                    ),
                    const SizedBox(height: 10),
                    actionButtons,
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    payableInfo,
                    actionButtons,
                  ],
                ),
        );
      },
    );
  }
}
