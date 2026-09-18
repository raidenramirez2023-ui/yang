import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/responsive_utils.dart';

class AccountDeletionRequestsPage extends StatefulWidget {
  const AccountDeletionRequestsPage({super.key});

  @override
  State<AccountDeletionRequestsPage> createState() =>
      _AccountDeletionRequestsPageState();
}

class _AccountDeletionRequestsPageState
    extends State<AccountDeletionRequestsPage> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _allRequests = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedStatusFilter = 'all'; // all, pending_review, cancelled_by_user, approved, rejected

  // Pagination
  int _currentPage = 1;
  static const int _itemsPerPage = 10;

  // Colors
  static const _emerald = Color(0xFF14332E);
  static const _slate = Color(0xFF64748B);
  static const _slateLight = Color(0xFFE2E8F0);
  static const _darkBg = Color(0xFF0F172A);

  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadRequests();
    _subscribeToDeletionRequests();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeToDeletionRequests() {
    _realtimeChannel = _supabase
        .channel('admin_account_deletion_requests_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'account_deletion_requests',
          callback: (_) {
            if (mounted) {
              _loadRequests();
            }
          },
        )
        .subscribe();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('account_deletion_requests')
          .select('*')
          .order('requested_at', ascending: false);

      if (mounted) {
        setState(() {
          _allRequests = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading deletion requests: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredRequests {
    return _allRequests.where((req) {
      final email = (req['email'] ?? '').toString().toLowerCase();
      final reason = (req['reason'] ?? '').toString().toLowerCase();
      final notes = (req['notes'] ?? '').toString().toLowerCase();
      final adminNotes = (req['admin_notes'] ?? '').toString().toLowerCase();
      final processedBy = (req['processed_by'] ?? '').toString().toLowerCase();
      final status = (req['status'] ?? 'pending_review').toString().toLowerCase();

      final matchesSearch = _searchQuery.isEmpty ||
          email.contains(_searchQuery.toLowerCase()) ||
          reason.contains(_searchQuery.toLowerCase()) ||
          notes.contains(_searchQuery.toLowerCase()) ||
          adminNotes.contains(_searchQuery.toLowerCase()) ||
          processedBy.contains(_searchQuery.toLowerCase());

      final matchesStatus = _selectedStatusFilter == 'all' ||
          status == _selectedStatusFilter.toLowerCase();

      return matchesSearch && matchesStatus;
    }).toList();
  }

  // ── Action: View Details Modal ─────────────────────────────────────────────
  void _showDetailsModal(Map<String, dynamic> request) {
    final email = request['email'] ?? 'Unknown Email';
    final reason = request['reason'] ?? 'No reason provided';
    final notes = request['notes'] as String?;
    final status = (request['status'] ?? 'pending_review').toString();
    final requestedAt = request['requested_at'] != null
        ? DateFormat('MMMM dd, yyyy • hh:mm:ss a').format(DateTime.parse(request['requested_at']).toLocal())
        : 'Unknown Date';
    final graceExpiresStr = request['grace_period_expires_at']?.toString();
    DateTime? graceExpires;
    if (graceExpiresStr != null && graceExpiresStr.isNotEmpty) {
      graceExpires = DateTime.tryParse(graceExpiresStr)?.toLocal();
    } else if (request['requested_at'] != null) {
      final reqDate = DateTime.tryParse(request['requested_at'])?.toLocal();
      if (reqDate != null) graceExpires = reqDate.add(const Duration(days: 14));
    }
    final processedBy = request['processed_by'] as String?;
    final processedAt = request['processed_at'] != null
        ? DateFormat('MMMM dd, yyyy • hh:mm:ss a').format(DateTime.parse(request['processed_at']).toLocal())
        : null;
    final adminNotes = request['admin_notes'] as String?;
    final isPending = status == 'pending_review';

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
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.info_outline_rounded, color: _emerald, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Deletion Request Details',
                style: GoogleFonts.lora(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            _buildStatusBadge(status),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Registered Email', email, isPrimary: true),
                const SizedBox(height: 12),
                _buildDetailRow('Primary Reason', reason),
                const SizedBox(height: 12),
                _buildDetailRow('Customer Notes / Feedback', (notes != null && notes.isNotEmpty) ? notes : 'None provided'),
                const SizedBox(height: 12),
                _buildDetailRow('Date Requested', requestedAt),
                if (graceExpires != null) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    '14-Day Grace Period Expiration',
                    '${DateFormat('MMMM dd, yyyy • hh:mm a').format(graceExpires)} (${graceExpires.difference(DateTime.now()).inDays.clamp(0, 14)} day(s) left)',
                  ),
                ],
                if (!isPending) ...[
                  const Divider(height: 28, color: _slateLight),
                  _buildDetailRow('Processed / Action By', processedBy ?? 'Admin'),
                  const SizedBox(height: 12),
                  _buildDetailRow('Processed At', processedAt ?? 'N/A'),
                  if (adminNotes != null && adminNotes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildDetailRow('Remarks / Notes', adminNotes),
                  ],
                ],
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        actions: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF475569),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                ),
                child: Text('Close', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              if (isPending) ...[
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showRejectDialog(request);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD97706),
                    side: const BorderSide(color: Color(0xFFFDE68A), width: 1.5),
                    backgroundColor: const Color(0xFFFFFBEB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  ),
                  child: Text('Reject', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showApproveDialog(request);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  ),
                  child: Text('Approve & Delete', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isPrimary = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: _slate,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: isPrimary ? 14 : 13,
            fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w500,
            color: _darkBg,
          ),
        ),
      ],
    );
  }

  // ── Action: Reject Request ─────────────────────────────────────────────────
  void _showRejectDialog(Map<String, dynamic> request) {
    final reasonCtrl = TextEditingController();
    bool isRejecting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
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
                child: const Icon(Icons.cancel_outlined, color: Color(0xFFD97706), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Reject Deletion Request',
                  style: GoogleFonts.lora(fontSize: 18, fontWeight: FontWeight.w700),
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
                  'Customer: ${request['email'] ?? 'Unknown'}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13.5, color: const Color(0xFF1E293B)),
                ),
                const SizedBox(height: 12),
                Text(
                  'Reason for Rejection (will be recorded in logs):',
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 3,
                  style: GoogleFonts.inter(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'e.g. Active booking reservations or unresolved balances exist...',
                    hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _slateLight),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          actions: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: isRejecting ? null : () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isRejecting
                      ? null
                      : () async {
                          setDialogState(() => isRejecting = true);
                          try {
                            final reqId = request['id'];
                            final adminEmail = _supabase.auth.currentUser?.email ?? 'Admin';

                            await _supabase.from('account_deletion_requests').update({
                              'status': 'rejected',
                              'admin_notes': reasonCtrl.text.trim(),
                              'processed_by': adminEmail,
                              'processed_at': DateTime.now().toIso8601String(),
                            }).eq('id', reqId);

                        // Audit Log
                        try {
                          await _supabase.from('audit_logs').insert({
                            'action': 'ACCOUNT_DELETION_REJECTED',
                            'performed_by': adminEmail,
                            'target': request['email'],
                            'details': 'Account deletion rejected. Reason: ${reasonCtrl.text.trim()}',
                            'created_at': DateTime.now().toIso8601String(),
                          });
                        } catch (_) {}

                        if (ctx.mounted) Navigator.pop(ctx);
                        _loadRequests();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Request marked as Rejected.'),
                              backgroundColor: Color(0xFFD97706),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isRejecting = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: isRejecting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Confirm Rejection'),
            ),
          ],
        ),
      ],
    ),
  ),
);
  }

  // ── Action: Confirm & Anonymize Deletion ────────────────────────────────────
  void _showApproveDialog(Map<String, dynamic> request) {
    final confirmController = TextEditingController();
    bool isProcessing = false;

    final requestedAtDate = request['requested_at'] != null ? DateTime.tryParse(request['requested_at'])?.toLocal() : null;
    final graceExpiresDate = request['grace_period_expires_at'] != null
        ? DateTime.tryParse(request['grace_period_expires_at'])?.toLocal()
        : (requestedAtDate != null ? requestedAtDate.add(const Duration(days: 14)) : null);
    final daysLeft = graceExpiresDate != null ? graceExpiresDate.difference(DateTime.now()).inDays : null;
    final isGracePeriodActive = daysLeft != null && daysLeft > 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
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
                child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFE11D48), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Confirm Account Deletion',
                  style: GoogleFonts.lora(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF9F1239)),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isGracePeriodActive) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.access_time_rounded, color: Color(0xFFD97706), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Notice: 14-day customer grace period is currently active ($daysLeft day(s) remaining until ${DateFormat('MMM dd, yyyy').format(graceExpiresDate!)}).',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF92400E), height: 1.4, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFECDD3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFE11D48), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Warning: This action will permanently anonymize personal details for ${request['email']}. Historical transactions are retained as anonymized records for compliance.',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF9F1239), height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Type "DELETE" below to confirm execution:',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmController,
                  style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, letterSpacing: 1),
                  decoration: InputDecoration(
                    hintText: 'DELETE',
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8), letterSpacing: 0),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _slateLight),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE11D48), width: 1.5),
                    ),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          actions: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: isProcessing ? null : () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: (isProcessing || confirmController.text.trim() != 'DELETE')
                      ? null
                      : () async {
                          setDialogState(() => isProcessing = true);
                          try {
                            final reqId = request['id'];
                            final targetEmail = request['email'];
                            final adminEmail = _supabase.auth.currentUser?.email ?? 'Admin';

                        // 1. Anonymize user records if present in users table
                        try {
                          await _supabase.from('users').update({
                            'firstname': 'Deleted',
                            'lastname': 'Customer',
                            'phone': null,
                            'is_active': false,
                            'restriction_status': 'deleted',
                          }).eq('email', targetEmail);
                        } catch (e) {
                          debugPrint('Note anonymizing users table: $e');
                        }

                        // 2. Mark deletion request as approved
                        await _supabase.from('account_deletion_requests').update({
                          'status': 'approved',
                          'admin_notes': 'Account anonymized and deleted upon verified customer request.',
                          'processed_by': adminEmail,
                          'processed_at': DateTime.now().toIso8601String(),
                        }).eq('id', reqId);

                        // 3. Audit Log
                        try {
                          await _supabase.from('audit_logs').insert({
                            'action': 'ACCOUNT_DELETED_PERMANENTLY',
                            'performed_by': adminEmail,
                            'target': targetEmail,
                            'details': 'Account deletion executed and personal data anonymized in compliance with RA 10173.',
                            'created_at': DateTime.now().toIso8601String(),
                          });
                        } catch (_) {}

                        if (ctx.mounted) Navigator.pop(ctx);
                        _loadRequests();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Account successfully anonymized & marked as Deleted.'),
                              backgroundColor: Color(0xFF059669),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isProcessing = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE11D48),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: isProcessing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Execute Deletion'),
            ),
          ],
        ),
      ],
    ),
  ),
);
}

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final isMobile = ResponsiveUtils.isMobile(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _emerald))
          : RefreshIndicator(
              onRefresh: _loadRequests,
              color: _emerald,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(isDesktop ? 24 : (isMobile ? 12 : 16)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 16),
                          _buildQuickStats(isDesktop, isMobile),
                          const SizedBox(height: 16),
                          _buildFilterBar(isDesktop, isMobile),
                          const SizedBox(height: 16),
                          _buildTableContainer(isDesktop, isMobile),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    final pendingCount = _allRequests.where((r) => (r['status'] ?? 'pending_review') == 'pending_review').length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                children: [
                  Text(
                    'Account Deletion Requests',
                    style: GoogleFonts.lora(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  if (pendingCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFECDD3)),
                      ),
                      child: Text(
                        '$pendingCount Pending (14d Grace)',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFE11D48),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Manage and review customer account deletion requests under Data Privacy (RA 10173)',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: _slate,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: _slate),
          tooltip: 'Refresh list',
          onPressed: _loadRequests,
        ),
      ],
    );
  }

  // ── Quick Stats Metric Cards ───────────────────────────────────────────────
  // ── Quick Stats Metric Cards ───────────────────────────────────────────────
  Widget _buildQuickStats(bool isDesktop, bool isMobile) {
    final pendingCount = _allRequests.where((r) => (r['status'] ?? 'pending_review') == 'pending_review').length;
    final cancelledCount = _allRequests.where((r) => r['status'] == 'cancelled_by_user').length;
    final approvedCount = _allRequests.where((r) => r['status'] == 'approved').length;
    final rejectedCount = _allRequests.where((r) => r['status'] == 'rejected').length;

    final stats = [
      _buildStatCard(
        label: 'Grace Period (Pending)',
        value: '$pendingCount',
        icon: Icons.hourglass_top_rounded,
        color: const Color(0xFFE11D48),
        bgTint: const Color(0xFFFFF1F2),
      ),
      _buildStatCard(
        label: 'Cancelled by User',
        value: '$cancelledCount',
        icon: Icons.undo_rounded,
        color: const Color(0xFF2563EB),
        bgTint: const Color(0xFFEFF6FF),
      ),
      _buildStatCard(
        label: 'Approved / Deleted',
        value: '$approvedCount',
        icon: Icons.check_circle_outline_rounded,
        color: const Color(0xFF059669),
        bgTint: const Color(0xFFECFDF5),
      ),
      _buildStatCard(
        label: 'Rejected Requests',
        value: '$rejectedCount',
        icon: Icons.cancel_outlined,
        color: const Color(0xFFD97706),
        bgTint: const Color(0xFFFFFBEB),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 820) {
          return SizedBox(
            height: 74,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: stats
                  .map((card) => Container(
                        width: 170,
                        margin: const EdgeInsets.only(right: 8),
                        child: card,
                      ))
                  .toList(),
            ),
          );
        } else {
          return Row(
            children: stats
                .map((card) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: card,
                      ),
                    ))
                .toList(),
          );
        }
      },
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgTint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _slateLight),
        boxShadow: [
          BoxShadow(
            color: _darkBg.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgTint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _darkBg,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
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
    );
  }

  // ── Filter Bar ─────────────────────────────────────────────────────────────
  Widget _buildFilterBar(bool isDesktop, bool isMobile) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 820;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _slateLight),
          ),
          child: !isCompact
              ? Row(
                  children: [
                    Expanded(child: _buildSearchBar()),
                    const SizedBox(width: 12),
                    _buildFilterChips(),
                  ],
                )
              : Column(
                  children: [
                    _buildSearchBar(),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: _buildFilterChips(),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      onChanged: (val) => setState(() {
        _searchQuery = val;
        _currentPage = 1;
      }),
      style: GoogleFonts.inter(fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Search by customer email, reason, or notes...',
        hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
        prefixIcon: const Icon(Icons.search_rounded, color: _slate, size: 18),
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _slateLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _slateLight),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildChip('all', 'All'),
        const SizedBox(width: 6),
        _buildChip('pending_review', 'Grace Period Active'),
        const SizedBox(width: 6),
        _buildChip('cancelled_by_user', 'Cancelled by User'),
        const SizedBox(width: 6),
        _buildChip('approved', 'Approved'),
        const SizedBox(width: 6),
        _buildChip('rejected', 'Rejected'),
      ],
    );
  }

  Widget _buildChip(String key, String label) {
    final isSelected = _selectedStatusFilter == key;
    Color activeColor = _emerald;
    if (key == 'pending_review') activeColor = const Color(0xFFE11D48);
    if (key == 'cancelled_by_user') activeColor = const Color(0xFF2563EB);
    if (key == 'approved') activeColor = const Color(0xFF059669);
    if (key == 'rejected') activeColor = const Color(0xFFD97706);

    return InkWell(
      onTap: () => setState(() {
        _selectedStatusFilter = key;
        _currentPage = 1;
      }),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? activeColor : _slateLight,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : _slate,
          ),
        ),
      ),
    );
  }

  // ── Main Table Container ───────────────────────────────────────────────────
  Widget _buildTableContainer(bool isDesktop, bool isMobile) {
    final filtered = _filteredRequests;
    if (filtered.isEmpty) {
      return _buildEmptyState();
    }

    final totalItems = filtered.length;
    final totalPages = (totalItems / _itemsPerPage).ceil();
    if (_currentPage > totalPages) _currentPage = totalPages;
    if (_currentPage < 1) _currentPage = 1;

    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage < totalItems) ? startIndex + _itemsPerPage : totalItems;
    final paginatedList = filtered.sublist(startIndex, endIndex);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompactView = constraints.maxWidth < 900;

        if (isCompactView) {
          // Compact / Mobile / Resized Window View: Standalone Elevated Cards List with Pagination Footer
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...paginatedList.map((req) => _buildMobileCardRow(req)),
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _slateLight),
                  boxShadow: [
                    BoxShadow(
                      color: _darkBg.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _buildPaginationFooter(
                  totalItems: totalItems,
                  startIndex: startIndex + 1,
                  endIndex: endIndex,
                  currentPage: _currentPage,
                  totalPages: totalPages,
                ),
              ),
            ],
          );
        }

        // Expanded Desktop / Wide Window View: Full Width Proportional Data Table with Scroll Safety
        final tableWidth = constraints.maxWidth > 1180 ? constraints.maxWidth : 1180.0;
        return Container(
          width: double.infinity,
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
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    children: [
                      _buildTableHeaderRow(),
                      const Divider(height: 1, color: _slateLight),
                      ...paginatedList.map((req) => _buildTableRow(req)),
                    ],
                  ),
                ),
              ),
              _buildPaginationFooter(
                totalItems: totalItems,
                startIndex: startIndex + 1,
                endIndex: endIndex,
                currentPage: _currentPage,
                totalPages: totalPages,
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Desktop Table Header Row (Proportional 100% width) ─────────────────────
  Widget _buildTableHeaderRow() {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(flex: 23, child: _buildHeaderCell('CUSTOMER / EMAIL')),
          Expanded(flex: 18, child: _buildHeaderCell('PRIMARY REASON')),
          Expanded(flex: 14, child: _buildHeaderCell('NOTES / FEEDBACK')),
          Expanded(flex: 17, child: _buildHeaderCell('DATE & 14D GRACE')),
          Expanded(flex: 16, child: _buildHeaderCell('STATUS')),
          Expanded(flex: 22, child: _buildHeaderCell('ACTIONS', alignment: Alignment.centerRight)),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String title, {Alignment alignment = Alignment.centerLeft}) {
    return Align(
      alignment: alignment,
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: const Color(0xFF64748B),
        ),
      ),
    );
  }

  // ── Desktop Table Row (Proportional 100% width) ────────────────────────────
  Widget _buildTableRow(Map<String, dynamic> req) {
    final email = req['email'] ?? 'Unknown Email';
    final reason = req['reason'] ?? 'No reason provided';
    final notes = req['notes'] as String?;
    final status = (req['status'] ?? 'pending_review').toString();
    final requestedAtDate = req['requested_at'] != null ? DateTime.tryParse(req['requested_at'])?.toLocal() : null;
    final requestedAt = requestedAtDate != null
        ? DateFormat('MMM dd, yyyy • hh:mm a').format(requestedAtDate)
        : 'N/A';
    final isPending = status == 'pending_review';

    final graceExpiresDate = req['grace_period_expires_at'] != null
        ? DateTime.tryParse(req['grace_period_expires_at'])?.toLocal()
        : (requestedAtDate != null ? requestedAtDate.add(const Duration(days: 14)) : null);
    final daysLeft = graceExpiresDate != null ? graceExpiresDate.difference(DateTime.now()).inDays : null;

    return InkWell(
      onTap: () => _showDetailsModal(req),
      hoverColor: const Color(0xFFF8FAFC),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Customer Email
            Expanded(
              flex: 23,
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isPending ? const Color(0xFFFFF1F2) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isPending ? Icons.person_remove_rounded : (status == 'cancelled_by_user' ? Icons.undo_rounded : Icons.person_rounded),
                      size: 18,
                      color: isPending ? const Color(0xFFE11D48) : (status == 'cancelled_by_user' ? const Color(0xFF2563EB) : _slate),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          email,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _darkBg,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Verified Customer',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            color: _slate,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 2. Reason
            Expanded(
              flex: 18,
              child: Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Text(
                  reason,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF334155),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // 3. Notes / Feedback
            Expanded(
              flex: 14,
              child: Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Text(
                  (notes != null && notes.isNotEmpty) ? notes : '—',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: (notes != null && notes.isNotEmpty) ? _darkBg : _slate,
                    fontStyle: (notes != null && notes.isNotEmpty) ? FontStyle.italic : FontStyle.normal,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // 4. Date Requested & Grace Countdown
            Expanded(
              flex: 17,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    requestedAt,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF334155),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (isPending && daysLeft != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: daysLeft > 0 ? const Color(0xFFFFFBEB) : const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: daysLeft > 0 ? const Color(0xFFFDE68A) : const Color(0xFFFECDD3)),
                      ),
                      child: Text(
                        daysLeft > 0 ? '⏳ $daysLeft day(s) grace left' : '⚠️ Grace period ended',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: daysLeft > 0 ? const Color(0xFFB45309) : const Color(0xFFE11D48),
                        ),
                      ),
                    ),
                  ] else if (status == 'cancelled_by_user') ...[
                    Text(
                      'Cancelled during grace period',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        color: const Color(0xFF2563EB),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // 5. Status
            Expanded(
              flex: 16,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: _buildStatusBadge(status),
                ),
              ),
            ),

            // 6. Actions
            Expanded(
              flex: 22,
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: isPending
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton(
                              onPressed: () => _showRejectDialog(req),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFD97706),
                                side: const BorderSide(color: Color(0xFFFDE68A)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text('Reject', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: 6),
                            ElevatedButton(
                              onPressed: () => _showApproveDialog(req),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE11D48),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text('Approve', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        )
                      : OutlinedButton.icon(
                          onPressed: () => _showDetailsModal(req),
                          icon: const Icon(Icons.visibility_outlined, size: 13),
                          label: const Text('View'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _slate,
                            side: const BorderSide(color: _slateLight),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Mobile Card Item (Standalone Elevated Card) ────────────────────────────
  Widget _buildMobileCardRow(Map<String, dynamic> req) {
    final email = req['email'] ?? 'Unknown Email';
    final reason = req['reason'] ?? 'No reason provided';
    final notes = req['notes'] as String?;
    final status = (req['status'] ?? 'pending_review').toString();
    final requestedAt = req['requested_at'] != null
        ? DateFormat('MMM dd, yyyy • hh:mm a').format(DateTime.parse(req['requested_at']).toLocal())
        : 'N/A';
    final isPending = status == 'pending_review';

    final requestedAtDate = req['requested_at'] != null ? DateTime.tryParse(req['requested_at'])?.toLocal() : null;
    final graceExpiresDate = req['grace_period_expires_at'] != null
        ? DateTime.tryParse(req['grace_period_expires_at'])?.toLocal()
        : (requestedAtDate != null ? requestedAtDate.add(const Duration(days: 14)) : null);
    final daysLeft = graceExpiresDate != null ? graceExpiresDate.difference(DateTime.now()).inDays : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPending ? const Color(0xFFFECDD3) : _slateLight,
          width: isPending ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isPending
                ? const Color(0xFFE11D48).withValues(alpha: 0.04)
                : _darkBg.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showDetailsModal(req),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top: Avatar + Email/Date + Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isPending
                            ? const Color(0xFFFFF1F2)
                            : (status == 'cancelled_by_user'
                                ? const Color(0xFFE0F2FE)
                                : (status == 'approved' ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9))),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isPending
                            ? Icons.person_remove_rounded
                            : (status == 'cancelled_by_user'
                                ? Icons.undo_rounded
                                : (status == 'approved' ? Icons.check_circle_outline_rounded : Icons.person_rounded)),
                        size: 19,
                        color: isPending
                            ? const Color(0xFFE11D48)
                            : (status == 'cancelled_by_user'
                                ? const Color(0xFF0284C7)
                                : (status == 'approved' ? const Color(0xFF059669) : _slate)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            email,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _darkBg,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 11, color: _slate),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  requestedAt,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: _slate,
                                    fontWeight: FontWeight.w500,
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
                    const SizedBox(width: 8),
                    _buildStatusBadge(status),
                  ],
                ),
                const SizedBox(height: 10),

                // 14-Day Grace Countdown Banner on Mobile
                if (isPending && daysLeft != null) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: daysLeft > 0 ? const Color(0xFFFFFBEB) : const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: daysLeft > 0 ? const Color(0xFFFDE68A) : const Color(0xFFFECDD3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 13,
                          color: daysLeft > 0 ? const Color(0xFFB45309) : const Color(0xFFE11D48),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            daysLeft > 0
                                ? '14-Day Grace: $daysLeft day(s) remaining (${DateFormat('MMM dd').format(graceExpiresDate!)})'
                                : '⚠️ 14-Day Grace Period Ended (Ready for Approval)',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: daysLeft > 0 ? const Color(0xFFB45309) : const Color(0xFFE11D48),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Reason Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(Icons.help_outline_rounded, size: 13, color: _slate),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF334155)),
                            children: [
                              TextSpan(
                                text: 'Reason: ',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
                              ),
                              TextSpan(
                                text: reason,
                                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Notes / Feedback
                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Feedback: "$notes"',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF475569),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],

                // Action Buttons
                const SizedBox(height: 10),
                if (isPending) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showRejectDialog(req),
                          icon: const Icon(Icons.close_rounded, size: 13),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFD97706),
                            side: const BorderSide(color: Color(0xFFFDE68A)),
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            textStyle: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showApproveDialog(req),
                          icon: const Icon(Icons.delete_forever_rounded, size: 13),
                          label: const Text('Approve & Delete'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE11D48),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            textStyle: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showDetailsModal(req),
                      icon: const Icon(Icons.visibility_outlined, size: 13),
                      label: const Text('View Full Details'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF475569),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        textStyle: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Status Pill Badge ──────────────────────────────────────────────────────
  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'approved':
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF059669);
        label = 'Approved';
        icon = Icons.check_circle_rounded;
        break;
      case 'cancelled_by_user':
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF2563EB);
        label = 'Cancelled by User';
        icon = Icons.undo_rounded;
        break;
      case 'rejected':
        bg = const Color(0xFFFFFBEB);
        fg = const Color(0xFFD97706);
        label = 'Rejected';
        icon = Icons.cancel_rounded;
        break;
      default:
        bg = const Color(0xFFFFF1F2);
        fg = const Color(0xFFE11D48);
        label = 'Grace Period';
        icon = Icons.access_time_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Pagination Footer ──────────────────────────────────────────────────────
  Widget _buildPaginationFooter({
    required int totalItems,
    required int startIndex,
    required int endIndex,
    required int currentPage,
    required int totalPages,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: const Color(0xFFF8FAFC),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $startIndex–$endIndex of $totalItems requests',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _slate,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                onPressed: currentPage > 1
                    ? () => setState(() => _currentPage = currentPage - 1)
                    : null,
                color: _emerald,
                disabledColor: const Color(0xFFCBD5E1),
              ),
              Text(
                'Page $currentPage of $totalPages',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _darkBg,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                onPressed: currentPage < totalPages
                    ? () => setState(() => _currentPage = currentPage + 1)
                    : null,
                color: _emerald,
                disabledColor: const Color(0xFFCBD5E1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Empty State ────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _slateLight),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.inbox_outlined, size: 36, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 14),
          Text(
            'No Deletion Requests Found',
            style: GoogleFonts.lora(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
          ),
          const SizedBox(height: 4),
          Text(
            'There are no requests matching your search or status filter.',
            style: GoogleFonts.inter(fontSize: 12.5, color: _slate),
          ),
        ],
      ),
    );
  }
}
