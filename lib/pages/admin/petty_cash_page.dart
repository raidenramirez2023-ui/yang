import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/models/petty_cash_model.dart';
import 'package:yang_chow/services/petty_cash_service.dart';
import 'package:yang_chow/services/audit_log_service.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';

class PettyCashPage extends StatefulWidget {
  const PettyCashPage({super.key});

  @override
  State<PettyCashPage> createState() => _PettyCashPageState();
}

class _PettyCashPageState extends State<PettyCashPage> {
  final PettyCashService _pettyCashService = PettyCashService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedStatus = 'All';
  String _selectedCategory = 'All';
  String _selectedSort = 'newest'; // 'newest', 'oldest', 'highest', 'lowest'
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final res = await Supabase.instance.client
        .from('users')
        .select('role')
        .eq('email', user.email!)
        .maybeSingle();

    if (!mounted) return;
    final role = (res?['role'] ?? '').toString().toLowerCase();
    final userEmail = user.email?.toLowerCase() ?? '';

    if (userEmail == 'pagsanjaninv@gmail.com' || role == 'admin') {
      setState(() => _isAdmin = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          color: AppTheme.warmGold,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 24,
              vertical: isMobile ? 12 : 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Section
                _buildHeader(isMobile),
                const SizedBox(height: 16),

                // Executive Treasury Smart Fund Card & Analytics Grid
                _buildFundOverviewSection(isMobile),
                const SizedBox(height: 20),

                // Expense Management Section (Filters, Search & List)
                _buildExpensesSection(isMobile),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER SECTION
  // ---------------------------------------------------------------------------
  Widget _buildHeader(bool isMobile) {
    final now = DateTime.now();
    final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(now);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14 : 20,
        vertical: isMobile ? 14 : 18,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF14332E), Color(0xFF1E4A42)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF14332E).withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.account_balance_rounded,
                  color: Color(0xFFD9A441),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Petty Cash Treasury',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: isMobile ? 16 : 20,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                            letterSpacing: -0.4,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD9A441).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFFD9A441).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            'Admin Control',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF9E6D10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formattedDate,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: isMobile ? 11 : 12,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isAdmin && !isMobile)
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _showSpendingReportDialog,
                      icon: const Icon(Icons.analytics_rounded, size: 16),
                      label: const Text('Reports'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF14332E),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _showBudgetManagementDialog,
                      icon: const Icon(Icons.pie_chart_rounded, size: 16),
                      label: const Text('Budgets'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF14332E),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _showReplenishDialog,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Replenish Fund'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF14332E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (_isAdmin && isMobile) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showSpendingReportDialog,
                    icon: const Icon(Icons.analytics_rounded, size: 14),
                    label: const Text('Reports'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF14332E),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      textStyle: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showBudgetManagementDialog,
                    icon: const Icon(Icons.pie_chart_rounded, size: 14),
                    label: const Text('Budgets'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF14332E),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      textStyle: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showReplenishDialog,
                    icon: const Icon(Icons.add_rounded, size: 15),
                    label: const Text('Replenish'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF14332E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                      textStyle: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FUND OVERVIEW & EXECUTIVE SMART CARD
  // ---------------------------------------------------------------------------
  Widget _buildFundOverviewSection(bool isMobile) {
    return StreamBuilder<PettyCashFund?>(
      stream: _pettyCashService.streamPettyCashFund(),
      builder: (context, fundSnapshot) {
        return StreamBuilder<List<PettyCashExpense>>(
          stream: _pettyCashService.streamExpenses(),
          builder: (context, expenseSnapshot) {
            final fund = fundSnapshot.data;
            final expenses = expenseSnapshot.data ?? [];

            // Calculate metric stats across all staff expenses
            final totalExpenses = expenses.fold<double>(
              0.0,
              (sum, item) => sum + item.amount,
            );
            final pendingExpenses = expenses.where((e) => e.status == 'pending').toList();
            final pendingTotal = pendingExpenses.fold<double>(
              0.0,
              (sum, item) => sum + item.amount,
            );
            final approvedExpenses = expenses.where((e) => e.status == 'approved' || e.status == 'reimbursed').toList();
            final approvedTotal = approvedExpenses.fold<double>(
              0.0,
              (sum, item) => sum + item.amount,
            );

            return Column(
              children: [
                // Executive Treasury Smart Fund Card
                _buildExecutiveSmartCard(fund, totalExpenses, pendingExpenses.length, isMobile),
                const SizedBox(height: 14),

                // 4-Card Analytics Grid
                _buildAnalyticsGrid(
                  fund: fund,
                  totalExpenses: totalExpenses,
                  expenseCount: expenses.length,
                  pendingTotal: pendingTotal,
                  pendingCount: pendingExpenses.length,
                  approvedTotal: approvedTotal,
                  approvedCount: approvedExpenses.length,
                  isMobile: isMobile,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildExecutiveSmartCard(
    PettyCashFund? fund,
    double totalSpent,
    int pendingCount,
    bool isMobile,
  ) {
    final balance = fund?.currentBalance ?? 0.0;
    final initial = fund?.initialBalance ?? 0.0;
    final totalAllocated = (initial > 0 && initial >= balance) ? initial : (balance + totalSpent);
    final percentRemaining = totalAllocated > 0 ? ((balance / totalAllocated) * 100).clamp(0.0, 100.0) : 100.0;
    final isLow = fund?.isLowBalance ?? false;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 18 : 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF0D2823), Color(0xFF143B34), Color(0xFF1B4E44)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF14332E).withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFD9A441).withValues(alpha: 0.35), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Title, Status Badge, and Reconcile Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFD9A441).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD9A441).withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFE6C374), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'PETTY CASH TREASURY',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFE6C374),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isLow
                          ? const Color(0xFFDC2626).withValues(alpha: 0.25)
                          : const Color(0xFF10B981).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isLow
                            ? const Color(0xFFFF6B6B).withValues(alpha: 0.5)
                            : const Color(0xFF34D399).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isLow ? const Color(0xFFFF6B6B) : const Color(0xFF34D399),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isLow ? 'LOW BALANCE' : 'ACTIVE FUND',
                          style: GoogleFonts.plusJakartaSans(
                            color: isLow ? const Color(0xFFFFAAAA) : const Color(0xFFA7F3D0),
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isAdmin && !isMobile) ...[
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _showReconciliationDialog,
                      icon: const Icon(Icons.sync_rounded, size: 13, color: Color(0xFFE2E8F0)),
                      label: Text(
                        'Reconcile',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFE2E8F0),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Label
          Text(
            'AVAILABLE BALANCE',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF94A3B8),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),

          // Available Balance Big Typography
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '₱',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFD9A441),
                  fontSize: isMobile ? 24 : 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                NumberFormat('#,##0.00').format(balance),
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: isMobile ? 34 : 40,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Fund Utilization Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Fund Remaining: ${percentRemaining.toStringAsFixed(1)}%',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Cap: ₱${NumberFormat('#,##0').format(totalAllocated)}',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 6,
                  color: Colors.white.withValues(alpha: 0.1),
                  child: LinearProgressIndicator(
                    value: percentRemaining / 100,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      percentRemaining > 40
                          ? const Color(0xFF34D399)
                          : percentRemaining > 15
                              ? const Color(0xFFFFB020)
                              : const Color(0xFFFF6B6B),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sub Stats Row — dark glass panel (Total Spent & Pending Review)
          isMobile
              ? Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.receipt_long_rounded, size: 16, color: Color(0xFFE6C374)),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Total Spent',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: const Color(0xFF94A3B8),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      '₱${NumberFormat('#,##0.00').format(totalSpent)}',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 24, color: Colors.white.withValues(alpha: 0.15)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.pending_actions_rounded, size: 16, color: Color(0xFFFFB020)),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Pending',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: const Color(0xFF94A3B8),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      '$pendingCount ${pendingCount == 1 ? 'item' : 'items'}',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: const Color(0xFFFFD166),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isAdmin) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _showReconciliationDialog,
                        icon: const Icon(Icons.sync_rounded, size: 14, color: Color(0xFFE2E8F0)),
                        label: Text(
                          'Reconcile Petty Cash',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFE2E8F0),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 38),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                      ),
                    ],
                  ],
                )
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.receipt_long_rounded, color: Color(0xFFE6C374), size: 16),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Spent This Period',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFF94A3B8),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '₱${NumberFormat('#,##0.00').format(totalSpent)}',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 26, color: Colors.white.withValues(alpha: 0.15)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.pending_actions_rounded, color: Color(0xFFFFB020), size: 16),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pending Approvals',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFF94A3B8),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '$pendingCount ${pendingCount == 1 ? 'item' : 'items'}',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFFFFD166),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
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
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4-GRID ANALYTICS METRICS TILES
  // ---------------------------------------------------------------------------
  Widget _buildAnalyticsGrid({
    required PettyCashFund? fund,
    required double totalExpenses,
    required int expenseCount,
    required double pendingTotal,
    required int pendingCount,
    required double approvedTotal,
    required int approvedCount,
    required bool isMobile,
  }) {
    final balance = fund?.currentBalance ?? 0.0;

    final cards = [
      _buildMetricTile(
        title: 'Available Fund',
        value: '₱${NumberFormat('#,##0.00').format(balance)}',
        subtitle: fund?.isLowBalance == true ? '⚠️ Refill Recommended' : '🟢 Ready for Operations',
        icon: Icons.account_balance_wallet_rounded,
        iconColor: const Color(0xFF14332E),
        bgTint: const Color(0xFFE6F4EA),
      ),
      _buildMetricTile(
        title: 'All Logged Expenses',
        value: '₱${NumberFormat('#,##0.00').format(totalExpenses)}',
        subtitle: '$expenseCount total entries submitted',
        icon: Icons.receipt_long_rounded,
        iconColor: const Color(0xFF475569),
        bgTint: const Color(0xFFF1F5F9),
      ),
      _buildMetricTile(
        title: 'Pending Approvals',
        value: '₱${NumberFormat('#,##0.00').format(pendingTotal)}',
        subtitle: '$pendingCount pending review',
        icon: Icons.hourglass_top_rounded,
        iconColor: const Color(0xFFB45309),
        bgTint: const Color(0xFFFEF3C7),
      ),
      _buildMetricTile(
        title: 'Approved / Settled',
        value: '₱${NumberFormat('#,##0.00').format(approvedTotal)}',
        subtitle: '$approvedCount approved transactions',
        icon: Icons.verified_rounded,
        iconColor: const Color(0xFF15803D),
        bgTint: const Color(0xFFDCFCE7),
      ),
    ];

    if (isMobile) {
      return SizedBox(
        height: 116,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          children: cards
              .map((c) => Container(
                    width: 205,
                    margin: const EdgeInsets.only(right: 10),
                    child: c,
                  ))
              .toList(),
        ),
      );
    }

    return Row(
      children: cards
          .map((card) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: card,
                ),
              ))
          .toList(),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgTint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgTint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 15),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF0F172A),
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF94A3B8),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EXPENSES SECTION (SEARCH & FILTER TOOLBAR & LIST)
  // ---------------------------------------------------------------------------
  Widget _buildExpensesSection(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Expense Verification & Audits',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.4,
                  ),
                ),
                Text(
                  'Review receipts, approve purchase logs, and reconcile cash',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Live Search Input Box
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: 'Search by description, requester email, supplier, receipt #, or inventory item...',
              hintStyle: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: const Color(0xFF94A3B8),
              ),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Status Filter Chips Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildFilterPill('All', Icons.apps_rounded),
              _buildFilterPill('Pending', Icons.pending_rounded),
              _buildFilterPill('Approved', Icons.check_circle_rounded),
              _buildFilterPill('Reimbursed', Icons.payments_rounded),
              _buildFilterPill('Rejected', Icons.cancel_rounded),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Expenses Stream List
        StreamBuilder<List<PettyCashExpense>>(
          stream: _pettyCashService.streamExpenses(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return Container(
                padding: const EdgeInsets.all(40),
                alignment: Alignment.center,
                child: const CircularProgressIndicator(color: AppTheme.warmGold),
              );
            }

            final expenses = snapshot.data ?? [];

            // Apply Status Filter
            var filtered = expenses.where((e) {
              if (_selectedStatus == 'All') return true;
              return e.status.toLowerCase() == _selectedStatus.toLowerCase();
            }).toList();

            // Apply Category Filter
            if (_selectedCategory != 'All') {
              filtered = filtered.where((e) => e.category == _selectedCategory).toList();
            }

            // Apply Search Query Filter
            if (_searchQuery.isNotEmpty) {
              filtered = filtered.where((e) {
                final desc = e.description.toLowerCase();
                final user = e.purchasedBy.toLowerCase();
                final supp = (e.supplier ?? '').toLowerCase();
                final rcpt = (e.receiptNumber ?? '').toLowerCase();
                final cat = e.categoryDisplay.toLowerCase();
                final items = (e.inventoryItems ?? []).map((i) => i.itemName.toLowerCase()).join(' ');
                final legacyItem = (e.inventoryItemName ?? '').toLowerCase();

                return desc.contains(_searchQuery) ||
                    user.contains(_searchQuery) ||
                    supp.contains(_searchQuery) ||
                    rcpt.contains(_searchQuery) ||
                    cat.contains(_searchQuery) ||
                    items.contains(_searchQuery) ||
                    legacyItem.contains(_searchQuery);
              }).toList();
            }

            // Sort
            if (_selectedSort == 'newest') {
              filtered.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
            } else if (_selectedSort == 'oldest') {
              filtered.sort((a, b) => a.expenseDate.compareTo(b.expenseDate));
            } else if (_selectedSort == 'highest') {
              filtered.sort((a, b) => b.amount.compareTo(a.amount));
            } else if (_selectedSort == 'lowest') {
              filtered.sort((a, b) => a.amount.compareTo(b.amount));
            }

            if (filtered.isEmpty) {
              return _buildEmptyState(expenses.isEmpty);
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _buildExpenseCard(filtered[index], isMobile),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFilterPill(String status, IconData icon) {
    final isSelected = _selectedStatus.toLowerCase() == status.toLowerCase();

    Color selectedBg;
    Color selectedBorder;
    Color selectedTextColor;
    Color selectedIconColor;

    switch (status.toLowerCase()) {
      case 'pending':
        selectedBg = const Color(0xFFFEF3C7);
        selectedBorder = const Color(0xFFFDE68A);
        selectedTextColor = const Color(0xFF92400E);
        selectedIconColor = const Color(0xFFB45309);
        break;
      case 'approved':
        selectedBg = const Color(0xFFDCFCE7);
        selectedBorder = const Color(0xFF86EFAC);
        selectedTextColor = const Color(0xFF166534);
        selectedIconColor = const Color(0xFF15803D);
        break;
      case 'reimbursed':
        selectedBg = const Color(0xFFE0F2FE);
        selectedBorder = const Color(0xFFBAE6FD);
        selectedTextColor = const Color(0xFF0369A1);
        selectedIconColor = const Color(0xFF0284C7);
        break;
      case 'rejected':
        selectedBg = const Color(0xFFFEE2E2);
        selectedBorder = const Color(0xFFFECACA);
        selectedTextColor = const Color(0xFF991B1B);
        selectedIconColor = const Color(0xFFDC2626);
        break;
      case 'all':
      default:
        selectedBg = const Color(0xFF14332E);
        selectedBorder = const Color(0xFF14332E);
        selectedTextColor = Colors.white;
        selectedIconColor = const Color(0xFFD9A441);
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedStatus = status),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? selectedBg : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? selectedBorder : const Color(0xFFE2E8F0),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: selectedBg == const Color(0xFF14332E)
                          ? const Color(0xFF14332E).withValues(alpha: 0.15)
                          : selectedBorder.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? selectedIconColor : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                status,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? selectedTextColor : const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EXPENSE CARD (CLEAN, SOPHISTICATED FOR ADMIN)
  // ---------------------------------------------------------------------------
  Widget _buildExpenseCard(PettyCashExpense expense, bool isMobile) {
    Color statusBgColor;
    Color statusTextColor;
    Color statusIndicatorColor;
    IconData statusIcon;
    String statusLabel;

    switch (expense.status.toLowerCase()) {
      case 'approved':
        statusBgColor = const Color(0xFFDCFCE7);
        statusTextColor = const Color(0xFF166534);
        statusIndicatorColor = const Color(0xFF15803D);
        statusIcon = Icons.check_circle_rounded;
        statusLabel = 'Approved';
        break;
      case 'rejected':
        statusBgColor = const Color(0xFFFEE2E2);
        statusTextColor = const Color(0xFF991B1B);
        statusIndicatorColor = const Color(0xFFDC2626);
        statusIcon = Icons.cancel_rounded;
        statusLabel = 'Rejected';
        break;
      case 'reimbursed':
        statusBgColor = const Color(0xFFE0F2FE);
        statusTextColor = const Color(0xFF0369A1);
        statusIndicatorColor = const Color(0xFF0284C7);
        statusIcon = Icons.payments_rounded;
        statusLabel = 'Reimbursed';
        break;
      case 'pending':
      default:
        statusBgColor = const Color(0xFFFEF3C7);
        statusTextColor = const Color(0xFF92400E);
        statusIndicatorColor = const Color(0xFFD97706);
        statusIcon = Icons.hourglass_top_rounded;
        statusLabel = 'Pending Review';
        break;
    }

    final categoryIcon = _getCategoryIcon(expense.category);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Accent Status Color Bar
              Container(
                width: 4,
                color: statusIndicatorColor,
              ),

              // Main Card Details
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 14 : 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Category Badge + Amount Tag
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Icon(categoryIcon, color: const Color(0xFF14332E), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        expense.categoryDisplay.toUpperCase(),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF475569),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: statusBgColor,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(statusIcon, color: statusTextColor, size: 11),
                                          const SizedBox(width: 4),
                                          Text(
                                            statusLabel,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: statusTextColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  expense.description,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: isMobile ? 15 : 16,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF14332E),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '₱${NumberFormat('#,##0.00').format(expense.amount)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: isMobile ? 14 : 16,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFE6C374),
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Multi-item inventory pills
                      if (expense.isMultiItemExpense && expense.inventoryItems != null) ...[
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: expense.inventoryItems!.map((item) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.inventory_2_rounded,
                                    size: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    item.itemName,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF334155),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF14332E).withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '×${item.quantity}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF14332E),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),
                      ] else if (expense.inventoryItemName != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.inventory_2_rounded, size: 12, color: Color(0xFF64748B)),
                              const SizedBox(width: 5),
                              Text(
                                '${expense.inventoryItemName!} ×${expense.quantityPurchased ?? 1}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Metadata Tags Row: Staff Requester, Date, Supplier, Receipt #
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person_rounded, size: 13, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 4),
                              Text(
                                expense.purchasedBy,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('MMM d, yyyy').format(expense.expenseDate),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          if (expense.supplier != null && expense.supplier!.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.storefront_rounded, size: 13, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 4),
                                Text(
                                  expense.supplier!,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          if (expense.receiptNumber != null && expense.receiptNumber!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '#${expense.receiptNumber}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                            ),
                          if (expense.receiptImageUrl != null)
                            InkWell(
                              onTap: () => _showReceiptLightbox(expense.receiptImageUrl!),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.image_rounded, size: 12, color: Color(0xFF475569)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'View Receipt',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF475569),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),

                      // Notes preview if available
                      if (expense.notes != null && expense.notes!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            'Note: ${expense.notes!}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],

                      // Admin Verification Actions
                      if (_isAdmin && expense.status == 'pending') ...[
                        const SizedBox(height: 14),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 12),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _rejectExpense(expense.id!),
                              icon: const Icon(Icons.close_rounded, size: 16),
                              label: const Text('Reject'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFDC2626),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                side: const BorderSide(color: Color(0xFFFCA5A5)),
                                textStyle: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _approveExpense(expense.id!),
                              icon: const Icon(Icons.check_rounded, size: 16),
                              label: const Text('Approve & Deduct'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF14332E),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                                textStyle: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      if (_isAdmin && expense.status == 'approved') ...[
                        const SizedBox(height: 14),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 12),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _markAsReimbursed(expense.id!),
                              icon: const Icon(Icons.payments_rounded, size: 16),
                              label: const Text('Mark as Reimbursed'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF14332E),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                                textStyle: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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

  // ---------------------------------------------------------------------------
  // EMPTY STATE
  // ---------------------------------------------------------------------------
  Widget _buildEmptyState(bool isCompletelyEmpty) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFD9A441).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              size: 48,
              color: Color(0xFFD9A441),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isCompletelyEmpty ? 'No Expenses Logged Yet' : 'No Matching Expenses Found',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isCompletelyEmpty
                ? 'Branch staff have not submitted any petty cash purchase entries yet.'
                : 'Try adjusting your search query or status filter.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: const Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RECEIPT LIGHTBOX DIALOG
  // ---------------------------------------------------------------------------
  void _showReceiptLightbox(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 700, maxHeight: 800),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 30,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(color: AppTheme.warmGold),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.broken_image_rounded, size: 48, color: Colors.white60),
                          const SizedBox(height: 12),
                          Text(
                            'Unable to load receipt image',
                            style: GoogleFonts.plusJakartaSans(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 14,
              right: 14,
              child: CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.65),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // REPLENISH FUND DIALOG
  // ---------------------------------------------------------------------------
  void _showReplenishDialog() {
    final amountCtrl = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14332E).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.add_card_rounded,
                        color: Color(0xFF14332E),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Replenish Petty Cash Fund',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Deposit additional funds into the branch cashbox',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: isSaving ? null : () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 16),

                // Quick Preset Pills
                Text(
                  'Quick Deposit Amounts',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [5000.0, 10000.0, 20000.0, 50000.0].map((preset) {
                    return InkWell(
                      onTap: () {
                        setDialogState(() {
                          amountCtrl.text = preset.toStringAsFixed(0);
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Text(
                          '+₱${NumberFormat('#,##0').format(preset)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF14332E),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Amount Input
                Text(
                  'Amount to Deposit (₱) *',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF14332E),
                  ),
                  decoration: InputDecoration(
                    prefixText: '₱ ',
                    prefixStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFD9A441),
                    ),
                    hintText: '0.00',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF14332E), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: isSaving ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final amount = double.tryParse(amountCtrl.text.trim());
                              if (amount == null || amount <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Please enter a valid amount', style: GoogleFonts.plusJakartaSans()),
                                    backgroundColor: const Color(0xFFDC2626),
                                  ),
                                );
                                return;
                              }

                              setDialogState(() => isSaving = true);
                              final success = await _pettyCashService.replenishPettyCashFund(amount);

                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      success
                                          ? 'Fund replenished by ₱${NumberFormat('#,##0.00').format(amount)} successfully'
                                          : 'Failed to replenish fund',
                                      style: GoogleFonts.plusJakartaSans(),
                                    ),
                                    backgroundColor: success ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF14332E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              'Confirm Deposit',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CASH RECONCILIATION DIALOG (REAL-TIME DISCREPANCY CALCULATION)
  // ---------------------------------------------------------------------------
  void _showReconciliationDialog() async {
    final fund = await _pettyCashService.getPettyCashFund();
    if (fund == null) return;

    final systemBalance = fund.currentBalance;
    final actualCashCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    double? discrepancy;
    bool isSaving = false;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14332E).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.balance_rounded,
                        color: Color(0xFF14332E),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cash Reconciliation Audit',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Compare physical cash count against ledger balance',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: isSaving ? null : () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 16),

                // System Balance Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Expected System Balance:',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF475569),
                        ),
                      ),
                      Text(
                        '₱${NumberFormat('#,##0.00').format(systemBalance)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF14332E),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Physical Count Input
                Text(
                  'Physical Cash Count (₱) *',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: actualCashCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (val) {
                    final entered = double.tryParse(val.trim());
                    setDialogState(() {
                      discrepancy = entered != null ? (entered - systemBalance) : null;
                    });
                  },
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF14332E),
                  ),
                  decoration: InputDecoration(
                    prefixText: '₱ ',
                    prefixStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFD9A441),
                    ),
                    hintText: '0.00',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF14332E), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                ),

                // Realtime Discrepancy Indicator
                if (discrepancy != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: discrepancy == 0
                          ? const Color(0xFFDCFCE7)
                          : (discrepancy! < 0 ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: discrepancy == 0
                            ? const Color(0xFF86EFAC)
                            : (discrepancy! < 0 ? const Color(0xFFFCA5A5) : const Color(0xFFFDE68A)),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              discrepancy == 0
                                  ? Icons.check_circle_rounded
                                  : (discrepancy! < 0 ? Icons.error_rounded : Icons.info_rounded),
                              size: 16,
                              color: discrepancy == 0
                                  ? const Color(0xFF15803D)
                                  : (discrepancy! < 0 ? const Color(0xFFDC2626) : const Color(0xFFD97706)),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              discrepancy == 0
                                  ? 'Cashbox is Balanced'
                                  : (discrepancy! < 0 ? 'Cash Shortage (Kulang)' : 'Cash Excess (Sobra)'),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: discrepancy == 0
                                    ? const Color(0xFF15803D)
                                    : (discrepancy! < 0 ? const Color(0xFFDC2626) : const Color(0xFFD97706)),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${discrepancy! > 0 ? '+' : ''}₱${NumberFormat('#,##0.00').format(discrepancy)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: discrepancy == 0
                                ? const Color(0xFF15803D)
                                : (discrepancy! < 0 ? const Color(0xFFDC2626) : const Color(0xFFD97706)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                // Audit Notes
                Text(
                  'Audit Remarks (Optional)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: notesCtrl,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13),
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Explanation for any discrepancy, physical count details...',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF14332E), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: isSaving ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final enteredCash = double.tryParse(actualCashCtrl.text.trim());
                              if (enteredCash == null || enteredCash < 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Please enter a valid cash count', style: GoogleFonts.plusJakartaSans()),
                                    backgroundColor: const Color(0xFFDC2626),
                                  ),
                                );
                                return;
                              }

                              setDialogState(() => isSaving = true);
                              final success = await _pettyCashService.createReconciliation(
                                systemBalance: systemBalance,
                                actualCashCount: enteredCash,
                                notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                              );

                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      success
                                          ? 'Cash reconciliation record saved successfully'
                                          : 'Failed to record reconciliation',
                                      style: GoogleFonts.plusJakartaSans(),
                                    ),
                                    backgroundColor: success ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF14332E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              'Save Audit Record',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SPENDING REPORT DIALOG
  // ---------------------------------------------------------------------------
  void _showSpendingReportDialog() async {
    final report = await _pettyCashService.getSpendingReport();
    final budgets = await _pettyCashService.getAllCategoryBudgets();
    final fund = await _pettyCashService.getPettyCashFund();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 650),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14332E).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.analytics_rounded,
                      color: Color(0xFF14332E),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Spending Analytics Report',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Last 30 days purchase distribution & metrics',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 16),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Key KPI Tiles
                      Row(
                        children: [
                          Expanded(
                            child: _buildReportKpi(
                              'Total Spent',
                              '₱${NumberFormat('#,##0.00').format(report['total_spent'] ?? 0.0)}',
                              Icons.payments_rounded,
                              const Color(0xFF14332E),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildReportKpi(
                              'Avg. Expense',
                              '₱${NumberFormat('#,##0.00').format(report['average_expense'] ?? 0.0)}',
                              Icons.query_stats_rounded,
                              const Color(0xFF14332E),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Category Allocations vs Actual Spend',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...budgets.map((b) {
                        final allocated = b.getAllocatedAmount(fund?.currentBalance ?? 0);
                        final spent = b.currentSpent;
                        final percent = allocated > 0 ? (spent / allocated).clamp(0.0, 1.0) : 0.0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    b.category.split('_').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}').join(' '),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF334155),
                                    ),
                                  ),
                                  Text(
                                    '₱${NumberFormat('#,##0').format(spent)} / ₱${NumberFormat('#,##0').format(allocated)}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF14332E),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: percent,
                                  minHeight: 5,
                                  backgroundColor: const Color(0xFFE2E8F0),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    percent > 0.85 ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14332E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportKpi(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(fontSize: 10, color: const Color(0xFF64748B)),
                ),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
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

  // ---------------------------------------------------------------------------
  // BUDGET MANAGEMENT DIALOG
  // ---------------------------------------------------------------------------
  void _showBudgetManagementDialog() async {
    final budgets = await _pettyCashService.getAllCategoryBudgets();
    final fund = await _pettyCashService.getPettyCashFund();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14332E).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.pie_chart_rounded,
                      color: Color(0xFF14332E),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Category Budget Allocation',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Balance: ₱${NumberFormat('#,##0.00').format(fund?.currentBalance ?? 0)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 16),

              Expanded(
                child: ListView.separated(
                  itemCount: budgets.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final budget = budgets[index];
                    final allocated = budget.getAllocatedAmount(fund?.currentBalance ?? 0);
                    final isNearLimit = budget.isNearLimit(fund?.currentBalance ?? 0);

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      budget.category.split('_').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}').join(' '),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF14332E).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${budget.percentage.toStringAsFixed(0)}%',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF14332E),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Cap: ₱${NumberFormat('#,##0.00').format(allocated)} • Spent: ₱${NumberFormat('#,##0.00').format(budget.currentSpent)}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: isNearLimit ? const Color(0xFFD97706) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF14332E)),
                            onPressed: () => _showEditBudgetDialog(budget),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14332E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditBudgetDialog(PettyCashCategoryBudget budget) {
    final percentageCtrl = TextEditingController(text: budget.percentage.toStringAsFixed(1));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Edit ${budget.category.replaceAll('_', ' ').toUpperCase()} Allocation',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: TextField(
          controller: percentageCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Percentage of Balance (%)',
            suffixText: '%',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              final pct = double.tryParse(percentageCtrl.text.trim());
              if (pct != null && pct >= 0 && pct <= 100) {
                final success = await _pettyCashService.updateCategoryBudgetPercentage(budget.category, pct);
                if (mounted) {
                  Navigator.pop(context); // close edit dialog
                  Navigator.pop(context); // close parent budget dialog
                  _showBudgetManagementDialog(); // reopen with refreshed data
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'Budget allocation updated' : 'Failed to update budget', style: GoogleFonts.plusJakartaSans()),
                      backgroundColor: success ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF14332E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // APPROVAL & REJECTION HANDLERS
  // ---------------------------------------------------------------------------
  Future<void> _approveExpense(String expenseId) async {
    final expenses = await _pettyCashService.getExpenses();
    final expense = expenses.firstWhere((e) => e.id == expenseId);

    final success = await _pettyCashService.approveExpense(expenseId);
    if (success) {
      AuditLogService.logActivity(
        action: 'APPROVE',
        module: 'Petty Cash',
        description: 'Approved petty cash expense of ₱${expense.amount.toStringAsFixed(2)} for "${expense.description}" by ${expense.purchasedBy}',
        entityId: expenseId,
        metadata: {
          'expense_id': expenseId,
          'amount': expense.amount,
          'category': expense.category,
          'purchased_by': expense.purchasedBy,
        },
      );
    }
    if (mounted) {
      String message;
      if (success) {
        if (expense.category == 'inventory_purchase' &&
            expense.inventoryItemName != null &&
            expense.quantityPurchased != null) {
          message = 'Expense approved! ${expense.quantityPurchased} ${expense.unit ?? 'pcs'} of ${expense.inventoryItemName} added to Incoming inventory tab';
        } else {
          message = 'Expense approved and deducted from Petty Cash Fund';
        }
      } else {
        message = 'Failed to approve expense';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: GoogleFonts.plusJakartaSans()),
          backgroundColor: success ? const Color(0xFF15803D) : const Color(0xFFDC2626),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _rejectExpense(String expenseId) async {
    final expenses = await _pettyCashService.getExpenses();
    final expense = expenses.where((e) => e.id == expenseId).firstOrNull;

    final success = await _pettyCashService.rejectExpense(expenseId);
    if (success) {
      AuditLogService.logActivity(
        action: 'REJECT',
        module: 'Petty Cash',
        description: 'Rejected petty cash expense of ₱${expense?.amount.toStringAsFixed(2) ?? '0.00'} for "${expense?.description ?? 'Expense'}"',
        entityId: expenseId,
        metadata: {
          'expense_id': expenseId,
          'amount': expense?.amount,
          'category': expense?.category,
        },
      );
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Expense rejected' : 'Failed to reject expense', style: GoogleFonts.plusJakartaSans()),
          backgroundColor: success ? const Color(0xFF15803D) : const Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _markAsReimbursed(String expenseId) async {
    final success = await _pettyCashService.markAsReimbursed(expenseId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Expense marked as reimbursed' : 'Failed to mark as reimbursed', style: GoogleFonts.plusJakartaSans()),
          backgroundColor: success ? const Color(0xFF15803D) : const Color(0xFFDC2626),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // HELPER ICONS & COLORS
  // ---------------------------------------------------------------------------
  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'inventory_purchase':
        return Icons.inventory_2_rounded;
      case 'kitchen_supplies':
        return Icons.soup_kitchen_rounded;
      case 'maintenance':
        return Icons.handyman_rounded;
      case 'transportation':
        return Icons.local_shipping_rounded;
      case 'utilities':
        return Icons.bolt_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }
}
