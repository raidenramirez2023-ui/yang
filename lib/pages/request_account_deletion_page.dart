import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/services/notification_service.dart';

class RequestAccountDeletionPage extends StatefulWidget {
  const RequestAccountDeletionPage({super.key});

  @override
  State<RequestAccountDeletionPage> createState() =>
      _RequestAccountDeletionPageState();
}

class _RequestAccountDeletionPageState
    extends State<RequestAccountDeletionPage> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedReason = 'I no longer use this service';
  final List<String> _reasons = [
    'I no longer use this service',
    'I have privacy concerns regarding my data',
    'I created a duplicate or new account',
    'Difficulties using the application / service',
    'Unsatisfied with customer service or food quality',
    'Other personal reasons',
  ];

  bool _agreeToTerms = false;
  bool _confirmNoActiveBookings = false;
  bool _isCheckingBookings = false;
  bool _isSubmitting = false;
  bool _submittedSuccess = false;
  bool _cancelledSuccess = false;
  bool _isLoadingExisting = true;
  Map<String, dynamic>? _existingPendingRequest;

  @override
  void initState() {
    super.initState();
    // If currently authenticated, pre-fill user email
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? '';
    }
    _checkExistingRequest();
  }

  Future<void> _checkExistingRequest() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final emailToCheck = user?.email ?? _emailController.text.trim();
      if (emailToCheck.isEmpty && user == null) {
        if (mounted) setState(() => _isLoadingExisting = false);
        return;
      }

      dynamic response;
      if (emailToCheck.isNotEmpty) {
        response = await Supabase.instance.client
            .from('account_deletion_requests')
            .select('*')
            .ilike('email', emailToCheck)
            .eq('status', 'pending_review')
            .order('requested_at', ascending: false)
            .limit(1);
      }

      if ((response == null || (response as List).isEmpty) && user != null && user.id.isNotEmpty) {
        response = await Supabase.instance.client
            .from('account_deletion_requests')
            .select('*')
            .eq('user_id', user.id)
            .eq('status', 'pending_review')
            .order('requested_at', ascending: false)
            .limit(1);
      }

      if (mounted) {
        setState(() {
          if (response != null && (response as List).isNotEmpty) {
            _existingPendingRequest = response.first as Map<String, dynamic>;
          } else {
            _existingPendingRequest = null;
          }
          _isLoadingExisting = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking existing deletion request: $e');
      if (mounted) setState(() => _isLoadingExisting = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitDeletionRequest() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_confirmNoActiveBookings) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please confirm you have no active bookings.'),
          backgroundColor: Color(0xFFE11D48),
        ),
      );
      return;
    }

    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please review and agree to the Account Deletion Terms & Conditions.'),
          backgroundColor: Color(0xFFE11D48),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      final userId = user?.id;
      final email = _emailController.text.trim();
      final notes = _notesController.text.trim();

      // Check if user has active reservations in database using customer_email
      if (email.isNotEmpty) {
        try {
          final activeReservations = await Supabase.instance.client
              .from('reservations')
              .select('id, status')
              .eq('customer_email', email)
              .inFilter('status', [
            'pending',
            'confirmed',
            'approved',
            'preparing',
            'in_progress',
            'for delivery',
            'out for delivery',
          ]);

          if ((activeReservations as List).isNotEmpty) {
            setState(() => _isSubmitting = false);
            if (mounted) {
              _showActiveBookingErrorDialog(activeReservations.length);
            }
            return;
          }
        } catch (e) {
          debugPrint('Check active reservations: $e');
        }
      }

      // 1. Insert into account_deletion_requests table
      final now = DateTime.now();
      final graceExpiresAt = now.add(const Duration(days: 14));

      try {
        final Map<String, dynamic> payload = {
          'email': email,
          'reason': _selectedReason,
          'notes': notes,
          'status': 'pending_review',
          'requested_at': now.toIso8601String(),
          'grace_period_expires_at': graceExpiresAt.toIso8601String(),
        };
        if (userId != null) {
          payload['user_id'] = userId;
        }

        await Supabase.instance.client
            .from('account_deletion_requests')
            .insert(payload);
      } catch (e) {
        debugPrint('Note on inserting account_deletion_requests: $e');
      }

      // 2. Send in-app notification to Admin
      try {
        await NotificationService.sendNotification(
          isForAdmin: true,
          actorName: email.split('@')[0],
          actionType: 'account_deletion_requested',
          reservationId: 'account_deletion',
          customerEmail: email,
        );
      } catch (_) {}

      // 3. If logged in, update metadata tag
      if (user != null) {
        try {
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(
              data: {
                ...?user.userMetadata,
                'deletion_requested': true,
                'deletion_requested_at': now.toIso8601String(),
                'grace_period_expires_at': graceExpiresAt.toIso8601String(),
                'deletion_reason': _selectedReason,
              },
            ),
          );
        } catch (_) {}
      }

      setState(() {
        _isSubmitting = false;
        _submittedSuccess = true;
      });
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting request: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _handleNoActiveBookingsToggle(bool? val) async {
    if (val != true) {
      setState(() => _confirmNoActiveBookings = false);
      return;
    }

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _formKey.currentState?.validate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your registered email address first to check active bookings.'),
          backgroundColor: Color(0xFFE11D48),
        ),
      );
      return;
    }

    setState(() => _isCheckingBookings = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      final userId = user?.id;

      // 1. Query reservations by email
      final response = await Supabase.instance.client
          .from('reservations')
          .select('id, status')
          .ilike('customer_email', email)
          .inFilter('status', [
        'pending',
        'confirmed',
        'approved',
        'preparing',
        'in_progress',
        'for delivery',
        'out for delivery',
      ]);

      final List activeList = List.from(response);

      // 2. Also query by user_id if present and activeList is empty
      if (activeList.isEmpty && userId != null && userId.isNotEmpty) {
        try {
          final userRes = await Supabase.instance.client
              .from('reservations')
              .select('id, status')
              .eq('user_id', userId)
              .inFilter('status', [
            'pending',
            'confirmed',
            'approved',
            'preparing',
            'in_progress',
            'for delivery',
            'out for delivery',
          ]);
          activeList.addAll(userRes);
        } catch (_) {}
      }

      if (mounted) {
        setState(() => _isCheckingBookings = false);
        if (activeList.isNotEmpty) {
          setState(() => _confirmNoActiveBookings = false);
          _showActiveBookingErrorDialog(activeList.length);
        } else {
          setState(() => _confirmNoActiveBookings = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Verified: No active or pending bookings found.'),
              backgroundColor: Color(0xFF059669),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking active bookings on toggle: $e');
      if (mounted) {
        setState(() {
          _isCheckingBookings = false;
          _confirmNoActiveBookings = true;
        });
      }
    }
  }

  void _showActiveBookingErrorDialog(int count) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFD97706), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Active Bookings Found',
                style: GoogleFonts.lora(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'You currently have $count active or pending booking reservation(s). Your account cannot be deleted while you have pending orders or scheduled events. Please settle or cancel them first.',
          style: GoogleFonts.inter(
            fontSize: 13.5,
            color: const Color(0xFF475569),
            height: 1.4,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.forestGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  Future<void> _showTermsDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.gavel_rounded, color: Color(0xFFE11D48), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Terms & Conditions',
                style: GoogleFonts.lora(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTermItem(
                  '1. Irreversible Process',
                  'Once your request is approved and executed, your account access, profile information, loyalty badges, saved preferences, and unspent perks will be permanently erased.',
                ),
                _buildTermItem(
                  '2. Financial & Legal Audit Data Retention',
                  'In compliance with Philippine Tax Laws (BIR) and the Data Privacy Act (RA 10173), YangChow Pagsanjan will retain transaction logs, billing receipts, and completed catering invoices for accounting audit purposes. These records will be detached and anonymized from your personal identifiable profile.',
                ),
                _buildTermItem(
                  '3. Ongoing Bookings & Unsettled Balances',
                  'Requests for accounts with active reservations, pending caterings, or unsettled balances will be put on hold or rejected until all transactions are fully concluded.',
                ),
                _buildTermItem(
                  '4. 14-Day Grace Period Window',
                  'Deletion requests undergo a 14-day grace period. You may cancel your deletion request anytime within this 14-day window directly from your Customer Profile to keep your account active.',
                ),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Confirm',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _agreeToTerms = true);
    } else {
      setState(() => _agreeToTerms = false);
    }
  }

  Widget _buildTermItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: const Color(0xFF64748B),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(
        backgroundColor: AppTheme.navColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/');
            }
          },
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'YangChow Pagsanjan',
              style: GoogleFonts.lora(
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: AppTheme.warmGold,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: _isLoadingExisting
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: AppTheme.forestGreen),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: _cancelledSuccess
                      ? _buildCancelledSuccessView()
                      : _submittedSuccess
                          ? _buildSuccessView()
                          : _existingPendingRequest != null
                              ? _buildExistingPendingRequestView()
                              : _buildFormView(),
                ),
              ),
            ),
    );
  }

  Widget _buildCancelledSuccessView() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFA7F3D0), width: 2),
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: Color(0xFF059669),
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Deletion Request Cancelled',
            textAlign: TextAlign.center,
            style: GoogleFonts.lora(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Your account deletion request has been successfully cancelled. Your account remains active and all your data and reservation history are preserved!',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushReplacementNamed(context, '/customer-dashboard');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                'Back to Customer Portal',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingPendingRequestView() {
    final req = _existingPendingRequest!;
    final email = req['email']?.toString() ?? _emailController.text.trim();
    final reason = req['reason']?.toString() ?? 'I no longer use this service';
    final notes = req['notes']?.toString() ?? '';
    final requestedAtStr = req['requested_at']?.toString();
    final graceExpiresStr = req['grace_period_expires_at']?.toString();

    DateTime? reqDate;
    if (requestedAtStr != null && requestedAtStr.isNotEmpty) {
      reqDate = DateTime.tryParse(requestedAtStr)?.toLocal();
    }

    DateTime? graceExpires;
    if (graceExpiresStr != null && graceExpiresStr.isNotEmpty) {
      graceExpires = DateTime.tryParse(graceExpiresStr)?.toLocal();
    } else if (reqDate != null) {
      graceExpires = reqDate.add(const Duration(days: 14));
    }

    final now = DateTime.now();
    int daysLeft = 14;
    String formattedExpiry = '14 days';
    if (graceExpires != null) {
      daysLeft = graceExpires.difference(now).inDays;
      if (daysLeft < 0) daysLeft = 0;
      formattedExpiry = DateFormat('MMMM dd, yyyy').format(graceExpires);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFF1F2), Color(0xFFFFE4E6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(bottom: BorderSide(color: Color(0xFFFECDD3))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.hourglass_top_rounded, color: Color(0xFFE11D48), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account Deletion Request Active',
                        style: GoogleFonts.lora(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF9F1239),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '14-Day Grace Period • $daysLeft day(s) left (until $formattedExpiry)',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFE11D48),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You currently have a pending account deletion request.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF334155),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'During the 14-day grace period, your account and reservation history remain completely safe. If you would like to keep your account, you can cancel this request at any time below.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),

                // Details Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _buildDetailItem(Icons.email_outlined, 'Registered Email', email),
                      const Divider(height: 16, color: Color(0xFFE2E8F0)),
                      _buildDetailItem(Icons.help_outline_rounded, 'Primary Reason', reason),
                      if (notes.isNotEmpty) ...[
                        const Divider(height: 16, color: Color(0xFFE2E8F0)),
                        _buildDetailItem(Icons.chat_bubble_outline_rounded, 'Customer Notes', notes),
                      ],
                      const Divider(height: 16, color: Color(0xFFE2E8F0)),
                      _buildDetailItem(
                        Icons.calendar_today_rounded,
                        'Date Requested',
                        reqDate != null ? DateFormat('MMMM dd, yyyy • hh:mm a').format(reqDate) : 'Recently',
                      ),
                      const Divider(height: 16, color: Color(0xFFE2E8F0)),
                      _buildDetailItem(
                        Icons.timer_outlined,
                        'Grace Expiry',
                        graceExpires != null ? DateFormat('MMMM dd, yyyy • hh:mm a').format(graceExpires) : '14 Days from request',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Action Buttons
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _confirmAndCancelDeletionRequest,
                    icon: _isSubmitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.undo_rounded, size: 18),
                    label: Text(_isSubmitting ? 'Cancelling Deletion Request...' : 'Cancel Deletion Request (Keep My Account)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        Navigator.pushReplacementNamed(context, '/customer-dashboard');
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF475569),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Back to Customer Portal',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 10),
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmAndCancelDeletionRequest() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.verified_user_outlined, color: Color(0xFF059669), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Keep Your Account?',
                style: GoogleFonts.lora(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
        content: Text(
          'Cancelling your deletion request will restore your account to normal active status. All your personal data and booking history will remain secure.',
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569), height: 1.4),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Never Mind'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Confirm & Keep Account'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSubmitting = true);

    try {
      final req = _existingPendingRequest;
      final reqId = req?['id'];
      final user = Supabase.instance.client.auth.currentUser;
      final userEmail = (user?.email ?? req?['email']?.toString() ?? _emailController.text.trim()).trim();

      final updatePayload = {
        'status': 'cancelled_by_user',
        'processed_by': userEmail.isNotEmpty ? userEmail : 'Customer',
        'processed_at': DateTime.now().toIso8601String(),
        'admin_notes': 'Customer cancelled account deletion during 14-day grace period.',
      };

      if (reqId != null) {
        await Supabase.instance.client
            .from('account_deletion_requests')
            .update(updatePayload)
            .eq('id', reqId);
      }
      if (userEmail.isNotEmpty) {
        await Supabase.instance.client
            .from('account_deletion_requests')
            .update(updatePayload)
            .ilike('email', userEmail)
            .eq('status', 'pending_review');
      }
      if (user != null && user.id.isNotEmpty) {
        await Supabase.instance.client
            .from('account_deletion_requests')
            .update(updatePayload)
            .eq('user_id', user.id)
            .eq('status', 'pending_review');
      }

      if (user != null) {
        try {
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(
              data: {
                ...?user.userMetadata,
                'deletion_requested': false,
                'deletion_cancelled_at': DateTime.now().toIso8601String(),
              },
            ),
          );
        } catch (_) {}
      }

      try {
        await NotificationService.sendNotification(
          isForAdmin: true,
          actorName: userEmail.isNotEmpty ? userEmail.split('@')[0] : 'Customer',
          actionType: 'account_deletion_cancelled',
          reservationId: 'account_deletion',
          customerEmail: userEmail,
        );
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _existingPendingRequest = null;
          _cancelledSuccess = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cancelling deletion request: $e'), backgroundColor: const Color(0xFFE11D48)),
        );
      }
    }
  }

  Widget _buildSuccessView() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFA7F3D0), width: 2),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF059669),
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Request Submitted Successfully',
            textAlign: TextAlign.center,
            style: GoogleFonts.lora(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'We have received your account deletion request for ${_emailController.text.trim()}. Our administrative team will review your account status within 14 business days.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 18, color: Color(0xFF475569)),
                    const SizedBox(width: 8),
                    Text(
                      'What happens next?',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• 14-Day Grace Period: Your account enters a 14-day grace period. You can cancel this request at any time from your Customer Profile to keep your account.\n• If not cancelled within 14 days and no active bookings exist, your personal account data will be permanently anonymized.\n• A confirmation notification will be sent to your registered email address.',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: const Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushReplacementNamed(context, '/');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.forestGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                'Return to Home',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormView() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF1F2),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE4E6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.person_remove_rounded,
                    color: Color(0xFFE11D48),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Request Account Deletion',
                        style: GoogleFonts.lora(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF9F1239),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Submit a formal request to remove your YangChow account',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: const Color(0xFFBE123C),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Notice Box
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: Color(0xFFD97706), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Please note: Deleting your account will remove your personal profile data, saved preferences, and customer access. Completed booking history is preserved as anonymized logs for accounting and regulatory compliance.',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: const Color(0xFF92400E),
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Email
                  _buildInputLabel('Registered Email Address', isRequired: true),
                  TextFormField(
                    controller: _emailController,
                    enabled: !_isSubmitting,
                    keyboardType: TextInputType.emailAddress,
                    style: GoogleFonts.inter(
                        fontSize: 14, color: AppTheme.darkGrey),
                    decoration: _inputDecoration(
                      hint: 'name@example.com',
                      icon: Icons.mail_outline_rounded,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(v.trim())) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  // Reason Dropdown
                  _buildInputLabel('Primary Reason for Deletion',
                      isRequired: true),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedReason,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded,
                            color: Color(0xFF64748B)),
                        items: _reasons.map((r) {
                          return DropdownMenuItem(
                            value: r,
                            child: Text(
                              r,
                              style: GoogleFonts.inter(
                                  fontSize: 13.5, color: AppTheme.darkGrey),
                            ),
                          );
                        }).toList(),
                        onChanged: _isSubmitting
                            ? null
                            : (val) {
                                if (val != null) {
                                  setState(() => _selectedReason = val);
                                }
                              },
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Additional Details
                  _buildInputLabel('Additional Feedback or Notes (Optional)'),
                  TextFormField(
                    controller: _notesController,
                    enabled: !_isSubmitting,
                    maxLines: 3,
                    style: GoogleFonts.inter(
                        fontSize: 13.5, color: AppTheme.darkGrey),
                    decoration: InputDecoration(
                      hintText:
                          'Let us know how we can improve our service...',
                      hintStyle: GoogleFonts.inter(
                          fontSize: 13, color: const Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: Color(0xFFE11D48), width: 1.4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Confirmation Checkboxes
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        CheckboxListTile(
                          value: _confirmNoActiveBookings,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: const Color(0xFFE11D48),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'I confirm that I have no active, pending, or scheduled booking reservations with YangChow Pagsanjan.',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    color: const Color(0xFF334155),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (_isCheckingBookings)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFFE11D48),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          onChanged: (_isSubmitting || _isCheckingBookings)
                              ? null
                              : (val) => _handleNoActiveBookingsToggle(val),
                        ),
                        const Divider(height: 18, color: Color(0xFFE2E8F0)),
                        CheckboxListTile(
                          value: _agreeToTerms,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: const Color(0xFFE11D48),
                          title: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'I understand and agree to the ',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                              Text(
                                'Account Deletion Terms & Conditions',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  color: const Color(0xFFE11D48),
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              Text(
                                '.',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                          onChanged: _isSubmitting
                              ? null
                              : (val) {
                                  if (val == true) {
                                    _showTermsDialog();
                                  } else {
                                    setState(() => _agreeToTerms = false);
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitDeletionRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE11D48),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Submit Deletion Request',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String label, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF334155),
            ),
          ),
          if (isRequired)
            const Text(' *',
                style: TextStyle(
                    color: Color(0xFFE11D48),
                    fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
      prefixIcon: Icon(icon, size: 19, color: const Color(0xFF64748B)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            const BorderSide(color: Color(0xFFE11D48), width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            const BorderSide(color: Color(0xFFDC2626), width: 1.2),
      ),
    );
  }
}
