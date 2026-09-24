import 'dart:async';
import 'dart:ui' show PointerDeviceKind;
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
  final ScrollController _tableHorizontalScrollController = ScrollController();

  String _searchQuery = '';
  String _selectedStatus = 'All';
  String _selectedCategory = 'All';
  String _selectedSort = 'newest'; // 'newest', 'oldest', 'highest', 'lowest'
  String _desktopViewMode = 'table'; // 'table' or 'grid'
  bool _isAdmin = false;
  int _currentPage = 0;
  final int _rowsPerPage = 15;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tableHorizontalScrollController.dispose();
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

    if (role == 'admin' || role == 'inventory') {
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
              horizontal: isMobile ? 12 : 20,
              vertical: isMobile ? 10 : 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Section
                _buildHeader(isMobile),
                const SizedBox(height: 12),

                // Executive Treasury Smart Fund Card & Analytics Grid
                _buildFundOverviewSection(isMobile),
                const SizedBox(height: 14),

                // Expense Management Section (Filters, Search & List)
                _buildExpensesSection(isMobile),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER SECTION (ENTERPRISE APP BAR & ACTION CLUSTER)
  // ---------------------------------------------------------------------------
  Widget _buildHeader(bool isMobile) {
    final now = DateTime.now();
    final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(now);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14 : 20,
        vertical: isMobile ? 12 : 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
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
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.account_balance_rounded,
                  color: Color(0xFFD9A441),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'TREASURY & FINANCE',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14332E).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF14332E).withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            'ADMIN AUDIT',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF14332E),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Petty Cash Treasury',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: isMobile ? 17 : 22,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 1),
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
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FUND OVERVIEW & ENTERPRISE TREASURY COMMAND CENTER
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
            // Settled Disbursed: Kaha (Approved/Reimbursed) + Abono (Reimbursed only)
            final settledExpenses = expenses.where((e) {
              if (e.isAbono) {
                return e.status == 'reimbursed';
              } else {
                return e.status == 'approved' || e.status == 'reimbursed';
              }
            }).toList();
            final settledTotal = settledExpenses.fold<double>(
              0.0,
              (sum, item) => sum + item.amount,
            );
            final unreimbursedAbono = expenses.where((e) => e.isAbono && e.status == 'approved').toList();
            final unreimbursedAbonoTotal = unreimbursedAbono.fold<double>(
              0.0,
              (sum, item) => sum + item.amount,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildVaultReserveCard(fund, totalExpenses, isMobile),
                const SizedBox(height: 12),
                _buildOperationalMetricsGrid(
                  totalExpenses: totalExpenses,
                  expenseCount: expenses.length,
                  pendingTotal: pendingTotal,
                  pendingCount: pendingExpenses.length,
                  approvedTotal: settledTotal,
                  approvedCount: settledExpenses.length,
                  unreimbursedAbonoTotal: unreimbursedAbonoTotal,
                  unreimbursedAbonoCount: unreimbursedAbono.length,
                  isMobile: isMobile,
                ),

                // Pending Staff Reimbursements Alert Banner
                if (unreimbursedAbono.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildAbonoAlertBanner(unreimbursedAbonoTotal, unreimbursedAbono.length, isMobile),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildVaultReserveCard(
    PettyCashFund? fund,
    double totalSpent,
    bool isMobile,
  ) {
    final balance = fund?.currentBalance ?? 0.0;
    final initial = fund?.initialBalance ?? 0.0;
    final totalAllocated = (initial > 0 && initial >= balance) ? initial : (balance + totalSpent);
    final percentRemaining = totalAllocated > 0 ? ((balance / totalAllocated) * 100).clamp(0.0, 100.0) : 100.0;
    final isLow = fund?.isLowBalance ?? false;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 22,
        vertical: isMobile ? 16 : 20,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF0A1F1B), Color(0xFF102A24), Color(0xFF173830)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF2E5E52),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Row: Badges & Live Status Telemetry
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9A441).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: const Color(0xFFD9A441).withValues(alpha: 0.45)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.savings_rounded, color: Color(0xFFF3C77C), size: 13),
                        const SizedBox(width: 6),
                        Text(
                          'BRANCH LIQUIDITY VAULT',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFF3C77C),
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isMobile) ...[
                    const SizedBox(width: 8),
                    Text(
                      '•   MAIN CASHBOX',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF64748B),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: isLow
                      ? const Color(0xFFDC2626).withValues(alpha: 0.22)
                      : const Color(0xFF10B981).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: isLow
                        ? const Color(0xFFFF6B6B).withValues(alpha: 0.6)
                        : const Color(0xFF34D399).withValues(alpha: 0.45),
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
                    const SizedBox(width: 5),
                    Text(
                      isLow ? 'LOW RESERVE' : 'ACTIVE POOL',
                      style: GoogleFonts.plusJakartaSans(
                        color: isLow ? const Color(0xFFFFAAAA) : const Color(0xFFA7F3D0),
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Main Hero Content
          if (!isMobile)
            // Desktop/Tablet: Split 2-Column Layout
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Left Column: Available Balance & Progress Bar
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL AVAILABLE CASH',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF94A3B8),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '₱',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFD9A441),
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            NumberFormat('#,##0.00').format(balance),
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildFundProgressBar(percentRemaining, totalAllocated),
                    ],
                  ),
                ),
                const SizedBox(width: 24),

                // Right Column: Telemetry KPI Cards + Action Buttons
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Fund Ceiling Telemetry
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'FUND CEILING',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF94A3B8),
                                letterSpacing: 0.6,
                              ),
                            ),
                            Text(
                              '₱${NumberFormat('#,##0').format(totalAllocated)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFF3C77C),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Enterprise Action Buttons
                      if (_isAdmin)
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: InkWell(
                                onTap: _showReplenishDialog,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 9),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFE5B555), Color(0xFFD9A441)],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFD9A441).withValues(alpha: 0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.add_circle_outline_rounded, size: 14, color: Color(0xFF0F2621)),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Deposit Fund',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF0F2621),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: PopupMenuButton<String>(
                                tooltip: 'Manage Vault Options',
                                offset: const Offset(0, 42),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                color: Colors.white,
                                elevation: 8,
                                onSelected: (val) {
                                  if (val == 'set_amount') _showSetFundAmountDialog(fund);
                                  if (val == 'reconcile') _showReconciliationDialog();
                                  if (val == 'budgets') _showBudgetManagementDialog();
                                },
                                itemBuilder: (context) => _buildTreasuryMenuItems(),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 9),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.tune_rounded, size: 13, color: Colors.white),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Manage',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.white70),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            )
          else
            // Mobile: Clean Stacked Layout
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL AVAILABLE CASH',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF94A3B8),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '₱',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFD9A441),
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      NumberFormat('#,##0.00').format(balance),
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildFundProgressBar(percentRemaining, totalAllocated),
                const SizedBox(height: 14),

                if (_isAdmin)
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: InkWell(
                          onTap: _showReplenishDialog,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD9A441),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_circle_outline_rounded, size: 14, color: Color(0xFF0F2621)),
                                const SizedBox(width: 5),
                                Text(
                                  'Deposit Fund',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F2621),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: PopupMenuButton<String>(
                          tooltip: 'Manage Vault Options',
                          offset: const Offset(0, 42),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          color: Colors.white,
                          elevation: 8,
                          onSelected: (val) {
                            if (val == 'set_amount') _showSetFundAmountDialog(fund);
                            if (val == 'reconcile') _showReconciliationDialog();
                            if (val == 'budgets') _showBudgetManagementDialog();
                          },
                          itemBuilder: (context) => _buildTreasuryMenuItems(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.tune_rounded, size: 13, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  'Manage',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.white70),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TREASURY ACTIONS DROPDOWN MENU BUILDERS
  // ---------------------------------------------------------------------------
  List<PopupMenuEntry<String>> _buildTreasuryMenuItems() {
    return [
      _buildTreasuryActionMenuItem(
        value: 'set_amount',
        icon: Icons.tune_rounded,
        iconColor: const Color(0xFFD9A441),
        title: 'Set Fund Amount',
        subtitle: 'Directly set balance & ceiling',
      ),
      _buildTreasuryActionMenuItem(
        value: 'reconcile',
        icon: Icons.sync_rounded,
        iconColor: const Color(0xFF0284C7),
        title: 'Reconcile Audit',
        subtitle: 'Audit physical vs system balance',
      ),
      const PopupMenuDivider(height: 1),
      _buildTreasuryActionMenuItem(
        value: 'budgets',
        icon: Icons.pie_chart_rounded,
        iconColor: const Color(0xFF7C3AED),
        title: 'Category Budgets',
        subtitle: 'Manage monthly category caps',
      ),
    ];
  }

  PopupMenuItem<String> _buildTreasuryActionMenuItem({
    required String value,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFundProgressBar(double percentRemaining, double totalAllocated) {
    final safePercent = (percentRemaining.isNaN || percentRemaining.isInfinite)
        ? 100.0
        : percentRemaining.clamp(0.0, 100.0);
    final safeTotal = (totalAllocated.isNaN || totalAllocated.isInfinite) ? 0.0 : totalAllocated;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Reserve Remaining: ${safePercent.toStringAsFixed(1)}%',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFCBD5E1),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Fund Ceiling: ₱${NumberFormat('#,##0').format(safeTotal)}',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF94A3B8),
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
            color: Colors.white.withValues(alpha: 0.12),
            child: LinearProgressIndicator(
              value: (safePercent / 100).clamp(0.0, 1.0),
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                safePercent > 40
                    ? const Color(0xFF34D399)
                    : safePercent > 15
                        ? const Color(0xFFFFB020)
                        : const Color(0xFFFF6B6B),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // OPERATIONAL KPI METRICS & STAFF ABONO BANNER
  // ---------------------------------------------------------------------------
  Widget _buildOperationalMetricsGrid({
    required double totalExpenses,
    required int expenseCount,
    required double pendingTotal,
    required int pendingCount,
    required double approvedTotal,
    required int approvedCount,
    required double unreimbursedAbonoTotal,
    required int unreimbursedAbonoCount,
    required bool isMobile,
  }) {
    final tileOutflow = _buildMetricTile(
      title: 'CYCLE OUTFLOW',
      value: '₱${NumberFormat('#,##0.00').format(totalExpenses)}',
      subtitle: '$expenseCount recorded purchases',
      icon: Icons.receipt_long_rounded,
      accentColor: const Color(0xFF2563EB),
      count: expenseCount,
      isSelected: _selectedStatus == 'All',
      onTap: () {
        setState(() {
          _selectedStatus = 'All';
          _currentPage = 0;
        });
      },
    );

    final tilePending = _buildMetricTile(
      title: 'APPROVAL QUEUE',
      value: '₱${NumberFormat('#,##0.00').format(pendingTotal)}',
      subtitle: '$pendingCount claims awaiting review',
      icon: Icons.hourglass_top_rounded,
      accentColor: const Color(0xFFD97706),
      count: pendingCount,
      isSelected: _selectedStatus == 'Pending',
      onTap: () {
        setState(() {
          _selectedStatus = 'Pending';
          _currentPage = 0;
        });
      },
    );

    final tileAbono = _buildMetricTile(
      title: 'STAFF ABONO CLAIMS',
      value: '₱${NumberFormat('#,##0.00').format(unreimbursedAbonoTotal)}',
      subtitle: '$unreimbursedAbonoCount claims to reimburse',
      icon: Icons.account_balance_wallet_rounded,
      accentColor: const Color(0xFF7C3AED),
      count: unreimbursedAbonoCount,
      isSelected: _selectedStatus == 'Abono',
      onTap: () {
        setState(() {
          _selectedStatus = 'Abono';
          _currentPage = 0;
        });
      },
    );

    final tileSettled = _buildMetricTile(
      title: 'SETTLED DISBURSED',
      value: '₱${NumberFormat('#,##0.00').format(approvedTotal)}',
      subtitle: '$approvedCount finalized records',
      icon: Icons.verified_rounded,
      accentColor: const Color(0xFF059669),
      count: approvedCount,
      isSelected: _selectedStatus == 'Settled',
      onTap: () {
        setState(() {
          _selectedStatus = 'Settled';
          _currentPage = 0;
        });
      },
    );

    if (isMobile) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: tileOutflow),
              const SizedBox(width: 6),
              Expanded(child: tilePending),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: tileAbono),
              const SizedBox(width: 6),
              Expanded(child: tileSettled),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: tileOutflow),
        const SizedBox(width: 8),
        Expanded(child: tilePending),
        const SizedBox(width: 8),
        Expanded(child: tileAbono),
        const SizedBox(width: 8),
        Expanded(child: tileSettled),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required int count,
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    final hasActiveAlert = count > 0 && (title.contains('QUEUE') || title.contains('ABONO'));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? accentColor
                  : (hasActiveAlert
                      ? accentColor.withValues(alpha: 0.4)
                      : const Color(0xFFE2E8F0)),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? accentColor.withValues(alpha: 0.1)
                    : const Color(0xFF0F172A).withValues(alpha: 0.025),
                blurRadius: isSelected ? 8 : 4,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Row: Category Title + Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 3,
                          height: 9,
                          decoration: BoxDecoration(
                            color: accentColor,
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF64748B),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(icon, color: accentColor, size: 12),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Main Monetary Value
              Text(
                value.isEmpty ? '₱0.00' : value,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF0F172A),
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),

              // Bottom Row: Subtitle + Count Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF94A3B8),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (count > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$count',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAbonoAlertBanner(double unreimbursedAbonoTotal, int claimCount, bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: isMobile ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PENDING STAFF REIMBURSEMENTS (ABONO)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF92400E),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'May ₱${NumberFormat('#,##0.00').format(unreimbursedAbonoTotal)} ($claimCount claims) na babayaran pa sa staff mula sa kaha.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: isMobile ? 11.5 : 12.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF78350F),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _selectedStatus = 'Abono';
                _currentPage = 0;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
              textStyle: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
            child: const Text('View Claims'),
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Expense Audit & Verification Records',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: isMobile ? 17 : 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Review receipts, approve purchase logs, and audit staff claims',
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

        // Enterprise Search & Control Toolbar Container
        Container(
          padding: const EdgeInsets.all(14),
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
            children: [
              // Row 1: Search Field + Category Dropdown + Sort Dropdown + View Toggle
              if (!isMobile)
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: _buildSearchTextField(),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: _buildCategoryDropdown(),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: _buildSortDropdown(),
                    ),
                    const SizedBox(width: 10),
                    _buildViewModeToggle(),
                  ],
                )
              else ...[
                _buildSearchTextField(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildCategoryDropdown()),
                    const SizedBox(width: 8),
                    Expanded(child: _buildSortDropdown()),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 12),

              // Row 2: Status Pills Filter Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildFilterPill('All', Icons.apps_rounded),
                    _buildFilterPill('Pending', Icons.hourglass_top_rounded),
                    _buildFilterPill('Approved', Icons.check_circle_rounded),
                    _buildFilterPill('Settled', Icons.verified_rounded),
                    _buildFilterPill('Abono', Icons.account_balance_wallet_rounded),
                    _buildFilterPill('Reimbursed', Icons.payments_rounded),
                    _buildFilterPill('Rejected', Icons.cancel_rounded),
                    _buildFilterPill('Archived', Icons.archive_rounded),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Expenses Stream List / Table
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
              if (_selectedStatus == 'All') {
                return !e.isArchived;
              }
              if (_selectedStatus.toLowerCase() == 'archived' || _selectedStatus.toLowerCase() == 'archive') {
                return e.isArchived;
              }
              if (e.isArchived) return false;
              if (_selectedStatus.toLowerCase() == 'abono') return e.isAbono;
              if (_selectedStatus.toLowerCase() == 'settled') {
                return e.isAbono
                    ? (e.status == 'reimbursed')
                    : (e.status == 'approved' || e.status == 'reimbursed');
              }
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

            final totalItems = filtered.length;
            final totalPages = (totalItems / _rowsPerPage).ceil();
            if (_currentPage >= totalPages && totalPages > 0) {
              _currentPage = totalPages - 1;
            }
            final startIndex = _currentPage * _rowsPerPage;
            final endIndex = (startIndex + _rowsPerPage < totalItems) ? startIndex + _rowsPerPage : totalItems;
            final paginatedExpenses = filtered.sublist(startIndex, endIndex);

            final totalFilteredAmount = filtered.fold<double>(0.0, (sum, e) => sum + e.amount);

            if (isMobile) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: paginatedExpenses.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _buildExpenseCard(paginatedExpenses[index], isMobile),
                  ),
                  if (totalItems > _rowsPerPage)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _buildTablePaginationControls(
                        currentPage: _currentPage,
                        totalItems: totalItems,
                        itemLabel: 'expenses',
                        onPageChanged: (newPage) => setState(() => _currentPage = newPage),
                      ),
                    ),
                ],
              );
            }

            if (_desktopViewMode == 'grid') {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final int crossAxisCount = constraints.maxWidth > 1400
                          ? 3
                          : (constraints.maxWidth > 850 ? 2 : 1);
                      if (crossAxisCount == 1) {
                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: paginatedExpenses.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) => _buildExpenseCard(paginatedExpenses[index], false),
                        );
                      }
                      const double spacing = 14.0;
                      final double cardWidth = (constraints.maxWidth - (spacing * (crossAxisCount - 1))) / crossAxisCount;
                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: paginatedExpenses.map((expense) {
                          return SizedBox(
                            width: cardWidth,
                            child: _buildExpenseCard(expense, false),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTableFooterBar(
                    currentPage: _currentPage,
                    totalItems: totalItems,
                    totalAmount: totalFilteredAmount,
                    onPageChanged: (newPage) => setState(() => _currentPage = newPage),
                  ),
                ],
              );
            }

            return _buildExpensesTable(paginatedExpenses, totalItems, totalFilteredAmount);
          },
        ),
      ],
    );
  }

  Widget _buildSearchTextField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() {
          _searchQuery = val.trim().toLowerCase();
          _currentPage = 0;
        }),
        style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: 'Search description, requester, supplier, receipt #, or inventory...',
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            color: const Color(0xFF94A3B8),
          ),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 19),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF94A3B8)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _currentPage = 0;
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    final categories = <String, String>{
      'All': 'All Categories',
      'inventory_purchase': 'Inventory Purchase',
      'kitchen_supplies': 'Kitchen Supplies',
      'transportation': 'Transportation',
      'other': 'Other Supplies',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: categories.containsKey(_selectedCategory) ? _selectedCategory : 'All',
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
          style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
          items: categories.entries.map((entry) {
            return DropdownMenuItem<String>(
              value: entry.key,
              child: Text(entry.value, maxLines: 1, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedCategory = val;
                _currentPage = 0;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildSortDropdown() {
    final sortOptions = <String, String>{
      'newest': 'Newest First',
      'oldest': 'Oldest First',
      'highest': 'Highest Amount',
      'lowest': 'Lowest Amount',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: sortOptions.containsKey(_selectedSort) ? _selectedSort : 'newest',
          isExpanded: true,
          icon: const Icon(Icons.sort_rounded, size: 18, color: Color(0xFF64748B)),
          style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
          items: sortOptions.entries.map((entry) {
            return DropdownMenuItem<String>(
              value: entry.key,
              child: Text(entry.value, maxLines: 1, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedSort = val;
                _currentPage = 0;
              });
            }
          },
        ),
      ),
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
      case 'settled':
        selectedBg = const Color(0xFFDCFCE7);
        selectedBorder = const Color(0xFF86EFAC);
        selectedTextColor = const Color(0xFF166534);
        selectedIconColor = const Color(0xFF15803D);
        break;
      case 'abono':
        selectedBg = const Color(0xFFFEF3C7);
        selectedBorder = const Color(0xFFF59E0B);
        selectedTextColor = const Color(0xFF92400E);
        selectedIconColor = const Color(0xFFD97706);
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
      case 'archived':
      case 'archive (>30d)':
      case 'archive':
        selectedBg = const Color(0xFFF1F5F9);
        selectedBorder = const Color(0xFFCBD5E1);
        selectedTextColor = const Color(0xFF334155);
        selectedIconColor = const Color(0xFF475569);
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
        onTap: () => setState(() {
          _selectedStatus = status;
          _currentPage = 0;
        }),
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

  Widget _buildViewModeToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: 'Audit Table View',
            child: InkWell(
              onTap: () => setState(() => _desktopViewMode = 'table'),
              borderRadius: BorderRadius.circular(7),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: _desktopViewMode == 'table' ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: _desktopViewMode == 'table'
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.table_rows_rounded,
                      size: 15,
                      color: _desktopViewMode == 'table' ? const Color(0xFF14332E) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Table',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: _desktopViewMode == 'table' ? FontWeight.w700 : FontWeight.w500,
                        color: _desktopViewMode == 'table' ? const Color(0xFF14332E) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Tooltip(
            message: 'Cards Grid View',
            child: InkWell(
              onTap: () => setState(() => _desktopViewMode = 'grid'),
              borderRadius: BorderRadius.circular(7),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: _desktopViewMode == 'grid' ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: _desktopViewMode == 'grid'
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.grid_view_rounded,
                      size: 15,
                      color: _desktopViewMode == 'grid' ? const Color(0xFF14332E) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Cards',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: _desktopViewMode == 'grid' ? FontWeight.w700 : FontWeight.w500,
                        color: _desktopViewMode == 'grid' ? const Color(0xFF14332E) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DESKTOP TABLE IMPLEMENTATION (ENTERPRISE AUDIT GRID)
  // ---------------------------------------------------------------------------
  Widget _tableHeader(String label, {TextAlign align = TextAlign.left}) {
    return Text(
      label,
      textAlign: align,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF64748B),
        letterSpacing: 0.5,
      ),
    );
  }

  String _formatRequesterName(String emailOrName) {
    if (emailOrName.contains('@')) {
      final prefix = emailOrName.split('@').first;
      if (prefix.toLowerCase() == 'pagsanjaninv' || prefix.toLowerCase() == 'admin') {
        return 'Admin';
      }
      return prefix;
    }
    return emailOrName;
  }

  Widget _buildTablePaginationControls({
    required int currentPage,
    required int totalItems,
    required String itemLabel,
    required ValueChanged<int> onPageChanged,
  }) {
    final startIndex = currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage < totalItems)
        ? startIndex + _rowsPerPage
        : totalItems;
    final totalPages = (totalItems / _rowsPerPage).ceil().clamp(1, 999999);
    final TextEditingController pageInputController = TextEditingController(text: '${currentPage + 1}');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${startIndex + 1}–$endIndex of $totalItems $itemLabel',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: currentPage > 0 ? () => onPageChanged(currentPage - 1) : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: currentPage > 0 ? const Color(0xFF14332E) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.chevron_left_rounded,
                    size: 18,
                    color: currentPage > 0 ? Colors.white : const Color(0xFFCBD5E1),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Page',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF475569),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 48,
                height: 32,
                child: TextField(
                  controller: pageInputController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFF14332E), width: 1.5),
                    ),
                  ),
                  onSubmitted: (value) {
                    final enteredPage = int.tryParse(value);
                    if (enteredPage != null && enteredPage >= 1 && enteredPage <= totalPages) {
                      onPageChanged(enteredPage - 1);
                    } else {
                      pageInputController.text = '${currentPage + 1}';
                    }
                  },
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'of $totalPages',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF475569),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: endIndex < totalItems ? () => onPageChanged(currentPage + 1) : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: endIndex < totalItems ? const Color(0xFF14332E) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: endIndex < totalItems ? Colors.white : const Color(0xFFCBD5E1),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableFooterBar({
    required int currentPage,
    required int totalItems,
    required double totalAmount,
    required ValueChanged<int> onPageChanged,
  }) {
    final startIndex = currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage < totalItems)
        ? startIndex + _rowsPerPage
        : totalItems;
    final totalPages = (totalItems / _rowsPerPage).ceil().clamp(1, 999999);
    final isMultiPage = totalItems > _rowsPerPage;
    final TextEditingController pageInputController = TextEditingController(text: '${currentPage + 1}');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFB),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFF14332E).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  size: 14,
                  color: Color(0xFF14332E),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isMultiPage
                    ? 'Showing ${startIndex + 1}–$endIndex of $totalItems expenses'
                    : 'Showing $totalItems ${totalItems == 1 ? 'expense record' : 'expense records'}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: const Color(0xFF475569),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 14,
                width: 1,
                color: const Color(0xFFCBD5E1),
              ),
              const SizedBox(width: 12),
              Text(
                'Total: ',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '₱${NumberFormat('#,##0.00').format(totalAmount)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF14332E),
                ),
              ),
            ],
          ),
          if (isMultiPage)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: currentPage > 0 ? () => onPageChanged(currentPage - 1) : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: currentPage > 0 ? const Color(0xFF14332E) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      size: 18,
                      color: currentPage > 0 ? Colors.white : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Page',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 48,
                  height: 32,
                  child: TextField(
                    controller: pageInputController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: Color(0xFF14332E), width: 1.5),
                      ),
                    ),
                    onSubmitted: (value) {
                      final enteredPage = int.tryParse(value);
                      if (enteredPage != null && enteredPage >= 1 && enteredPage <= totalPages) {
                        onPageChanged(enteredPage - 1);
                      } else {
                        pageInputController.text = '${currentPage + 1}';
                      }
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'of $totalPages',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: endIndex < totalItems ? () => onPageChanged(currentPage + 1) : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: endIndex < totalItems ? const Color(0xFF14332E) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: endIndex < totalItems ? Colors.white : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'All records displayed',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildExpensesTable(List<PettyCashExpense> paginatedExpenses, int totalFilteredCount, double totalFilteredAmount) {
    final isSingleItem = paginatedExpenses.length == 1;

    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final needsScroll = constraints.maxWidth < 850;
              final tableContent = SizedBox(
                width: needsScroll ? 850.0 : constraints.maxWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Table Header Row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
                      ),
                      child: Row(
                        children: [
                          SizedBox(width: 95, child: _tableHeader('DATE & TIME')),
                          const SizedBox(width: 8),
                          SizedBox(width: 85, child: _tableHeader('REF #')),
                          const SizedBox(width: 8),
                          SizedBox(width: 120, child: _tableHeader('CATEGORY')),
                          const SizedBox(width: 8),
                          Expanded(flex: 4, child: _tableHeader('DESCRIPTION & ITEMS')),
                          const SizedBox(width: 8),
                          SizedBox(width: 125, child: _tableHeader('REQUESTER')),
                          const SizedBox(width: 8),
                          SizedBox(width: 90, child: _tableHeader('AMOUNT', align: TextAlign.right)),
                          const SizedBox(width: 8),
                          SizedBox(width: 65, child: _tableHeader('PROOF', align: TextAlign.center)),
                          const SizedBox(width: 8),
                          SizedBox(width: 105, child: _tableHeader('STATUS', align: TextAlign.center)),
                          const SizedBox(width: 8),
                          SizedBox(width: 50, child: _tableHeader('ACTION', align: TextAlign.center)),
                        ],
                      ),
                    ),
                    // Table Rows
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: paginatedExpenses.length,
                      separatorBuilder: (_, __) => const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFF1F5F9),
                      ),
                      itemBuilder: (context, index) {
                        final expense = paginatedExpenses[index];
                        final isEven = index % 2 == 0;
                        return _buildExpenseTableRow(expense, isEven, isSingleItem: isSingleItem);
                      },
                    ),
                  ],
                ),
              );

              if (needsScroll) {
                return ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                      PointerDeviceKind.stylus,
                    },
                  ),
                  child: Scrollbar(
                    controller: _tableHorizontalScrollController,
                    thumbVisibility: false,
                    trackVisibility: false,
                    child: SingleChildScrollView(
                      controller: _tableHorizontalScrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: tableContent,
                    ),
                  ),
                );
              }

              return tableContent;
            },
          ),
          _buildTableFooterBar(
            currentPage: _currentPage,
            totalItems: totalFilteredCount,
            totalAmount: totalFilteredAmount,
            onPageChanged: (newPage) => setState(() => _currentPage = newPage),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseTableRow(PettyCashExpense expense, bool isEven, {bool isSingleItem = false}) {
    Color statusBgColor;
    Color statusBorderColor;
    Color statusTextColor;
    IconData statusIcon;
    String statusLabel;

    switch (expense.status.toLowerCase()) {
      case 'approved':
        if (expense.isAbono) {
          statusBgColor = const Color(0xFFFEF3C7);
          statusBorderColor = const Color(0xFFFDE68A);
          statusTextColor = const Color(0xFFB45309);
          statusIcon = Icons.hourglass_top_rounded;
          statusLabel = 'To Reimburse';
        } else {
          statusBgColor = const Color(0xFFDCFCE7);
          statusBorderColor = const Color(0xFF86EFAC);
          statusTextColor = const Color(0xFF166534);
          statusIcon = Icons.check_circle_rounded;
          statusLabel = 'Approved';
        }
        break;
      case 'rejected':
        statusBgColor = const Color(0xFFFEE2E2);
        statusBorderColor = const Color(0xFFFECACA);
        statusTextColor = const Color(0xFF991B1B);
        statusIcon = Icons.cancel_rounded;
        statusLabel = 'Rejected';
        break;
      case 'reimbursed':
        statusBgColor = const Color(0xFFE0F2FE);
        statusBorderColor = const Color(0xFFBAE6FD);
        statusTextColor = const Color(0xFF0369A1);
        statusIcon = Icons.payments_rounded;
        statusLabel = expense.isAbono ? 'Reimbursed' : 'Settled';
        break;
      case 'pending':
      default:
        statusBgColor = const Color(0xFFFEF3C7);
        statusBorderColor = const Color(0xFFFDE68A);
        statusTextColor = const Color(0xFF92400E);
        statusIcon = Icons.hourglass_top_rounded;
        statusLabel = expense.isAbono ? 'Pending (Abono)' : 'Pending';
        break;
    }

    final hasReceipt = expense.receiptImageUrl != null && expense.receiptImageUrl!.isNotEmpty;

    // Build items subtitle preview
    String itemsSubtitle = '';
    if (expense.isMultiItemExpense && expense.inventoryItems != null && expense.inventoryItems!.isNotEmpty) {
      itemsSubtitle = expense.inventoryItems!.map((i) => '${i.itemName} ×${i.quantity}').join(', ');
    } else if (expense.inventoryItemName != null) {
      itemsSubtitle = '${expense.inventoryItemName!} ×${expense.quantityPurchased ?? 1}';
    } else if (expense.supplier != null && expense.supplier!.isNotEmpty) {
      itemsSubtitle = 'Supplier: ${expense.supplier!}';
    } else if (expense.notes != null && expense.notes!.isNotEmpty) {
      itemsSubtitle = expense.notes!.replaceAll('[ABONO]', '').replaceAll('[NON-OR]', '').trim();
    }

    return Material(
      color: isEven ? Colors.white : const Color(0xFFFAFAFB),
      child: InkWell(
        onTap: () => _showExpenseDetailsModal(expense),
        hoverColor: const Color(0xFFF1F5F9),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: isSingleItem ? 18 : 13),
          decoration: BoxDecoration(
            border: isSingleItem
                ? const Border(left: BorderSide(color: Color(0xFF14332E), width: 3.5))
                : null,
          ),
          child: Row(
            children: [
              // 1. DATE & TIME
              SizedBox(
                width: 95,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('MMM dd, yyyy').format(expense.expenseDate),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time_rounded, size: 10.5, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 3),
                        Text(
                          DateFormat('h:mm a').format(expense.expenseDate),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // 2. REF #
              SizedBox(
                width: 85,
                child: (expense.receiptNumber != null && expense.receiptNumber!.isNotEmpty)
                    ? Tooltip(
                        message: 'Ref #${expense.receiptNumber}\nClick to copy',
                        child: InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: expense.receiptNumber!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Copied Ref #${expense.receiptNumber} to clipboard'),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: const Color(0xFF14332E),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    '#${expense.receiptNumber}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF334155),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 3),
                                const Icon(Icons.copy_rounded, size: 10, color: Color(0xFF94A3B8)),
                              ],
                            ),
                          ),
                        ),
                      )
                    : Text(
                        '—',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: const Color(0xFFCBD5E1),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              const SizedBox(width: 8),

              // 3. CATEGORY
              SizedBox(
                width: 120,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14332E).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF14332E).withValues(alpha: 0.12)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getCategoryIcon(expense.category), size: 12, color: const Color(0xFF14332E)),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            expense.categoryDisplay.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF14332E),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 4. DESCRIPTION & ITEMS
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          if (expense.isAbono) ...[
                            Container(
                              margin: const EdgeInsets.only(right: 5),
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFF59E0B)),
                              ),
                              child: Text(
                                'ABONO',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFB45309),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                          if (expense.isNonOr) ...[
                            Container(
                              margin: const EdgeInsets.only(right: 5),
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFF38BDF8)),
                              ),
                              child: Text(
                                'NON-OR',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0369A1),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                          Expanded(
                            child: Text(
                              expense.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (itemsSubtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          itemsSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 5. REQUESTER
              SizedBox(
                width: 125,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: const Color(0xFF14332E).withValues(alpha: 0.08),
                      child: const Icon(Icons.person_rounded, size: 13, color: Color(0xFF14332E)),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Tooltip(
                        message: '${_formatRequesterName(expense.purchasedBy)}\n${expense.purchasedBy}',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _formatRequesterName(expense.purchasedBy),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              expense.purchasedBy,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // 6. AMOUNT
              SizedBox(
                width: 90,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '₱${NumberFormat('#,##0.00').format(expense.amount)}',
                      textAlign: TextAlign.right,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      expense.isAbono ? 'Staff Abono' : 'Vault Cash',
                      textAlign: TextAlign.right,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: expense.isAbono ? const Color(0xFFD97706) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // 7. PROOF
              SizedBox(
                width: 65,
                child: Center(
                  child: hasReceipt
                      ? Tooltip(
                          message: 'View Receipt Proof',
                          child: InkWell(
                            onTap: () => _showReceiptLightbox(expense.receiptImageUrl!),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.image_rounded, size: 12, color: Color(0xFF14332E)),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Proof',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF14332E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : Text(
                          'No Proof',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: const Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 8),

              // 8. STATUS
              SizedBox(
                width: 105,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusBorderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusTextColor, size: 11),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            statusLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: statusTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 9. ACTIONS (3-Dots Menu)
              SizedBox(
                width: 50,
                child: Center(
                  child: _buildExpenseActionMenu(expense),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3-DOTS ACTION POPUP MENU FOR EXPENSE ROWS
  // ---------------------------------------------------------------------------
  Widget _buildExpenseActionMenu(PettyCashExpense expense) {
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      shadowColor: Colors.black26,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      offset: const Offset(0, 32),
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: const Icon(Icons.more_vert_rounded, size: 16, color: Color(0xFF475569)),
      ),
      onSelected: (action) {
        switch (action) {
          case 'details':
            _showExpenseDetailsModal(expense);
            break;
          case 'receipt':
            if (expense.receiptImageUrl != null && expense.receiptImageUrl!.isNotEmpty) {
              _showReceiptLightbox(expense.receiptImageUrl!);
            }
            break;
          case 'copy_ref':
            if (expense.receiptNumber != null && expense.receiptNumber!.isNotEmpty) {
              Clipboard.setData(ClipboardData(text: expense.receiptNumber!));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied Ref #${expense.receiptNumber} to clipboard'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            break;
          case 'approve':
            if (expense.id != null) _approveExpense(expense.id!);
            break;
          case 'reject':
            if (expense.id != null) _rejectExpense(expense.id!);
            break;
          case 'reimburse':
            if (expense.id != null) _markAsReimbursed(expense.id!);
            break;
          case 'restore':
          case 'archive':
            _toggleArchiveExpense(expense);
            break;
        }
      },
      itemBuilder: (context) {
        final List<PopupMenuEntry<String>> items = [];

        // 1. Primary contextual action (if pending or approved)
        if (_isAdmin && expense.status == 'pending') {
          items.add(_buildExpensePopupMenuItem(
            value: 'approve',
            icon: Icons.check_circle_rounded,
            color: const Color(0xFF15803D),
            label: 'Approve & Deduct Fund',
          ));
          items.add(_buildExpensePopupMenuItem(
            value: 'reject',
            icon: Icons.cancel_rounded,
            color: const Color(0xFFDC2626),
            label: 'Reject Expense',
            isDestructive: true,
          ));
          items.add(const PopupMenuDivider(height: 8));
        } else if (_isAdmin && expense.status == 'approved') {
          items.add(_buildExpensePopupMenuItem(
            value: 'reimburse',
            icon: Icons.payments_rounded,
            color: expense.isAbono ? const Color(0xFFD97706) : const Color(0xFF14332E),
            label: expense.isAbono ? 'Pay Staff Reimbursement' : 'Mark as Reimbursed',
          ));
          items.add(const PopupMenuDivider(height: 8));
        }

        // 2. View details
        items.add(_buildExpensePopupMenuItem(
          value: 'details',
          icon: Icons.visibility_rounded,
          color: const Color(0xFF0284C7),
          label: 'View Full Audit Details',
        ));

        // 3. Receipt if present
        if (expense.receiptImageUrl != null && expense.receiptImageUrl!.isNotEmpty) {
          items.add(_buildExpensePopupMenuItem(
            value: 'receipt',
            icon: Icons.receipt_long_rounded,
            color: const Color(0xFF0D9488),
            label: 'View Receipt Proof',
          ));
        }

        // 4. Copy reference # if present
        if (expense.receiptNumber != null && expense.receiptNumber!.isNotEmpty) {
          items.add(_buildExpensePopupMenuItem(
            value: 'copy_ref',
            icon: Icons.copy_rounded,
            color: const Color(0xFF64748B),
            label: 'Copy Ref #${expense.receiptNumber}',
          ));
        }

        // 5. Archive / Restore
        if (expense.isArchived) {
          items.add(const PopupMenuDivider(height: 8));
          items.add(_buildExpensePopupMenuItem(
            value: 'restore',
            icon: Icons.unarchive_rounded,
            color: const Color(0xFF15803D),
            label: 'Restore from Archive',
          ));
        } else if (expense.status == 'approved' || expense.status == 'reimbursed') {
          items.add(const PopupMenuDivider(height: 8));
          items.add(_buildExpensePopupMenuItem(
            value: 'archive',
            icon: Icons.archive_outlined,
            color: const Color(0xFF64748B),
            label: 'Archive Expense',
          ));
        }

        return items;
      },
    );
  }

  PopupMenuItem<String> _buildExpensePopupMenuItem({
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
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FULL EXPENSE AUDIT DETAILS MODAL
  // ---------------------------------------------------------------------------
  void _showExpenseDetailsModal(PettyCashExpense expense) {
    Color statusBgColor;
    Color statusBorderColor;
    Color statusTextColor;
    IconData statusIcon;
    String statusLabel;

    switch (expense.status.toLowerCase()) {
      case 'approved':
        if (expense.isAbono) {
          statusBgColor = const Color(0xFFFEF3C7);
          statusBorderColor = const Color(0xFFFDE68A);
          statusTextColor = const Color(0xFFB45309);
          statusIcon = Icons.hourglass_top_rounded;
          statusLabel = 'For Reimbursement';
        } else {
          statusBgColor = const Color(0xFFDCFCE7);
          statusBorderColor = const Color(0xFF86EFAC);
          statusTextColor = const Color(0xFF166534);
          statusIcon = Icons.check_circle_rounded;
          statusLabel = 'Approved (Kaha)';
        }
        break;
      case 'rejected':
        statusBgColor = const Color(0xFFFEE2E2);
        statusBorderColor = const Color(0xFFFECACA);
        statusTextColor = const Color(0xFF991B1B);
        statusIcon = Icons.cancel_rounded;
        statusLabel = 'Rejected';
        break;
      case 'reimbursed':
        statusBgColor = const Color(0xFFE0F2FE);
        statusBorderColor = const Color(0xFFBAE6FD);
        statusTextColor = const Color(0xFF0369A1);
        statusIcon = Icons.payments_rounded;
        statusLabel = expense.isAbono ? 'Reimbursed to Staff' : 'Reimbursed';
        break;
      case 'pending':
      default:
        statusBgColor = const Color(0xFFFEF3C7);
        statusBorderColor = const Color(0xFFFDE68A);
        statusTextColor = const Color(0xFF92400E);
        statusIcon = Icons.hourglass_top_rounded;
        statusLabel = expense.isAbono ? 'Pending Review (Abono)' : 'Pending Review';
        break;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Modal Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14332E).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
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
                          'Expense Audit Details',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Full transaction audit trail and verification records',
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

              // Content Body
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Amount & Status Header Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TOTAL AMOUNT',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF64748B),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '₱${NumberFormat('#,##0.00').format(expense.amount)}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF14332E),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: statusBgColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: statusBorderColor),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(statusIcon, color: statusTextColor, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    statusLabel,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: statusTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Key Information Table
                      _buildDetailRow('Description', expense.description, isBold: true),
                      _buildDetailRow('Category', expense.categoryDisplay),
                      _buildDetailRow(
                        'Payment Source',
                        expense.isAbono ? '🙋‍♂️ Staff Out-of-Pocket (Abono ni Staff)' : '🏢 Petty Cash Advance (Kaha)',
                        isBold: expense.isAbono,
                      ),
                      _buildDetailRow('Date Filed', DateFormat('MMMM dd, yyyy · h:mm a').format(expense.expenseDate)),
                      _buildDetailRow('Purchased By', expense.purchasedBy),
                      if (expense.supplier != null && expense.supplier!.isNotEmpty)
                        _buildDetailRow('Supplier / Vendor', expense.supplier!),
                      if (expense.receiptNumber != null && expense.receiptNumber!.isNotEmpty)
                        _buildDetailRow(
                          expense.isNonOr ? 'Voucher Ref (Non-OR)' : 'Receipt / Invoice #',
                          '#${expense.receiptNumber}',
                        ),
                      if (expense.isNonOr)
                        _buildDetailRow('Receipt Type', '🏷️ Non-OR (Walang Opisyal na Resibo / Fare Voucher)'),
                      if (expense.approvedBy != null && expense.approvedBy!.isNotEmpty)
                        _buildDetailRow('Approved By', expense.approvedBy!),
                      if (expense.approvedAt != null)
                        _buildDetailRow('Approved At', DateFormat('MMM dd, yyyy · h:mm a').format(expense.approvedAt!)),

                      // Multi-item Breakdown
                      if (expense.isMultiItemExpense && expense.inventoryItems != null && expense.inventoryItems!.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          'Purchased Items Breakdown',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: expense.inventoryItems!.map((item) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: const BoxDecoration(
                                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      item.itemName,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF334155),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF14332E).withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Qty: ${item.quantity} ${item.unit ?? ''}'.trim(),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
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
                        ),
                      ],

                      // Notes Section
                      () {
                        final displayNotes = (expense.notes ?? '').replaceAll('[ABONO]', '').replaceAll('[NON-OR]', '').trim();
                        if (displayNotes.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 14),
                            Text(
                              'Notes / Justification',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Text(
                                displayNotes,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        );
                      }(),

                      // Receipt Attachment Proof
                      if (expense.receiptImageUrl != null && expense.receiptImageUrl!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Attached Receipt Proof',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _showReceiptLightbox(expense.receiptImageUrl!),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 160,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    expense.receiptImageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Center(
                                      child: Icon(Icons.broken_image_rounded, size: 36, color: Colors.grey),
                                    ),
                                  ),
                                  Container(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.65),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.fullscreen_rounded, size: 16, color: Colors.white),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Click to Enlarge Proof',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
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

              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 16),

              // Bottom Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    child: Text('Close', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                  ),
                  if (_isAdmin && expense.status == 'pending') ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _rejectExpense(expense.id!);
                      },
                      icon: const Icon(Icons.close_rounded, size: 15),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        textStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _approveExpense(expense.id!);
                      },
                      icon: const Icon(Icons.check_rounded, size: 15),
                      label: Text(expense.isAbono ? 'Approve (For Reimbursement)' : 'Approve & Deduct'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF14332E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                        textStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                  if (_isAdmin && expense.status == 'approved') ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _markAsReimbursed(expense.id!);
                      },
                      icon: const Icon(Icons.payments_rounded, size: 15),
                      label: Text(expense.isAbono ? 'Pay Reimbursement to Staff' : 'Mark as Reimbursed'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: expense.isAbono ? const Color(0xFFD97706) : const Color(0xFF14332E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                        textStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                  if (expense.isArchived) ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _toggleArchiveExpense(expense);
                      },
                      icon: const Icon(Icons.unarchive_rounded, size: 15),
                      label: const Text('Restore from Archive'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF14332E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                        textStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ] else if (expense.status == 'approved' || expense.status == 'reimbursed') ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _toggleArchiveExpense(expense);
                      },
                      icon: const Icon(Icons.archive_outlined, size: 15),
                      label: const Text('Move to Archive'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF475569),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        textStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: const Color(0xFF0F172A),
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EXPENSE CARD (KDS DOCKET STYLE - INVENTORY & ADMIN HARMONIZED)
  // ---------------------------------------------------------------------------
  Widget _buildExpenseCard(PettyCashExpense expense, bool isMobile) {
    Color statusIndicatorColor;
    IconData statusIcon;
    String statusLabel;

    switch (expense.status.toLowerCase()) {
      case 'approved':
        if (expense.isAbono) {
          statusIndicatorColor = const Color(0xFFD97706);
          statusIcon = Icons.hourglass_top_rounded;
          statusLabel = 'For Reimbursement';
        } else {
          statusIndicatorColor = const Color(0xFF15803D);
          statusIcon = Icons.check_circle_rounded;
          statusLabel = 'Approved';
        }
        break;
      case 'rejected':
        statusIndicatorColor = const Color(0xFFDC2626);
        statusIcon = Icons.cancel_rounded;
        statusLabel = 'Rejected';
        break;
      case 'reimbursed':
        statusIndicatorColor = const Color(0xFF0284C7);
        statusIcon = Icons.payments_rounded;
        statusLabel = expense.isAbono ? 'Reimbursed to Staff' : 'Reimbursed';
        break;
      case 'pending':
      default:
        statusIndicatorColor = const Color(0xFFD97706);
        statusIcon = Icons.hourglass_top_rounded;
        statusLabel = expense.isAbono ? 'Pending (Abono)' : 'Pending Review';
        break;
    }

    final category = expense.categoryDisplay;
    final categoryIcon = _getCategoryIcon(expense.category);
    final categoryColor = _getCategoryColor(expense.category);

    final now = DateTime.now();
    final isToday = expense.createdAt.year == now.year &&
        expense.createdAt.month == now.month &&
        expense.createdAt.day == now.day;
    final isRecent = isToday || now.difference(expense.createdAt).inHours < 24;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusIndicatorColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: () => _showExpenseDetailsModal(expense),
          borderRadius: BorderRadius.circular(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 1. KDS DOCKET HEADER BAR (38px high, Enterprise Dark Green 0xFF14332E) ──
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF14332E),
                ),
                child: Row(
                  children: [
                    // Category Badge with icon
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: categoryColor.withValues(alpha: 0.55), width: 0.9),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(categoryIcon, size: 10, color: categoryColor),
                            const SizedBox(width: 3.5),
                            Flexible(
                              child: Text(
                                category.toUpperCase(),
                                style: GoogleFonts.plusJakartaSans(
                                  color: categoryColor,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),

                    // Abono Badge (Pera ni staff)
                    if (expense.isAbono) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706).withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: const Color(0xFFF59E0B), width: 0.9),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_pin_rounded, size: 9, color: Color(0xFFFDE68A)),
                            SizedBox(width: 2.5),
                            Text(
                              'ABONO',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFFDE68A),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],

                    // Freshness / New Request Badge
                    if (expense.status == 'pending' && isRecent) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6C374).withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: const Color(0xFFE6C374), width: 0.9),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt_rounded, size: 9, color: Color(0xFFE6C374)),
                            SizedBox(width: 2),
                            Text(
                              'NEW',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFE6C374),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                    // Multi-item Count Badge in Header
                    if (expense.isMultiItemExpense &&
                        expense.inventoryItems != null &&
                        expense.inventoryItems!.length > 1) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.white24, width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.inventory_2_rounded, size: 8.5, color: Colors.white70),
                            const SizedBox(width: 3),
                            Text(
                              '${expense.inventoryItems!.length} ITEMS',
                              style: const TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],

                    const Spacer(),

                    // Status Badge with icon
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: statusIndicatorColor.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: statusIndicatorColor.withValues(alpha: 0.55), width: 0.9),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 9, color: statusIndicatorColor),
                          const SizedBox(width: 3),
                          Text(
                            statusLabel.toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Action dropdown menu (3 dots)
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 14,
                      iconSize: 16,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 8,
                      shadowColor: Colors.black26,
                      color: Colors.white,
                      surfaceTintColor: Colors.white,
                      offset: const Offset(0, 30),
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        size: 16,
                        color: Colors.white70,
                      ),
                      onSelected: (action) {
                        switch (action) {
                          case 'details':
                            _showExpenseDetailsModal(expense);
                            break;
                          case 'receipt':
                            if (expense.receiptImageUrl != null && expense.receiptImageUrl!.isNotEmpty) {
                              _showReceiptLightbox(expense.receiptImageUrl!);
                            }
                            break;
                          case 'copy_ref':
                            if (expense.receiptNumber != null && expense.receiptNumber!.isNotEmpty) {
                              Clipboard.setData(ClipboardData(text: expense.receiptNumber!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Copied Ref #${expense.receiptNumber} to clipboard'),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                            break;
                          case 'approve':
                            if (expense.id != null) _approveExpense(expense.id!);
                            break;
                          case 'reject':
                            if (expense.id != null) _rejectExpense(expense.id!);
                            break;
                          case 'reimburse':
                            if (expense.id != null) _markAsReimbursed(expense.id!);
                            break;
                          case 'restore':
                          case 'archive':
                            _toggleArchiveExpense(expense);
                            break;
                        }
                      },
                      itemBuilder: (context) {
                        final List<PopupMenuEntry<String>> items = [];

                        items.add(_buildExpensePopupMenuItem(
                          value: 'details',
                          icon: Icons.visibility_rounded,
                          color: const Color(0xFF0284C7),
                          label: 'View Full Audit Details',
                        ));

                        if (expense.receiptImageUrl != null && expense.receiptImageUrl!.isNotEmpty) {
                          items.add(_buildExpensePopupMenuItem(
                            value: 'receipt',
                            icon: Icons.receipt_long_rounded,
                            color: const Color(0xFF0D9488),
                            label: 'View Receipt Proof',
                          ));
                        }

                        if (expense.receiptNumber != null && expense.receiptNumber!.isNotEmpty) {
                          items.add(_buildExpensePopupMenuItem(
                            value: 'copy_ref',
                            icon: Icons.copy_rounded,
                            color: const Color(0xFF64748B),
                            label: 'Copy Ref #${expense.receiptNumber}',
                          ));
                        }

                        if (_isAdmin && expense.status == 'pending') {
                          items.add(const PopupMenuDivider(height: 8));
                          items.add(_buildExpensePopupMenuItem(
                            value: 'approve',
                            icon: Icons.check_circle_rounded,
                            color: const Color(0xFF15803D),
                            label: 'Approve & Deduct Fund',
                          ));
                          items.add(_buildExpensePopupMenuItem(
                            value: 'reject',
                            icon: Icons.cancel_rounded,
                            color: const Color(0xFFDC2626),
                            label: 'Reject Expense',
                            isDestructive: true,
                          ));
                        } else if (_isAdmin && expense.status == 'approved') {
                          items.add(const PopupMenuDivider(height: 8));
                          items.add(_buildExpensePopupMenuItem(
                            value: 'reimburse',
                            icon: Icons.payments_rounded,
                            color: expense.isAbono ? const Color(0xFFD97706) : const Color(0xFF14332E),
                            label: expense.isAbono ? 'Pay Staff Reimbursement' : 'Mark as Reimbursed',
                          ));
                        }

                        if (expense.isArchived) {
                          items.add(const PopupMenuDivider(height: 8));
                          items.add(_buildExpensePopupMenuItem(
                            value: 'restore',
                            icon: Icons.unarchive_rounded,
                            color: const Color(0xFF15803D),
                            label: 'Restore from Archive',
                          ));
                        } else if (expense.status == 'approved' || expense.status == 'reimbursed') {
                          items.add(const PopupMenuDivider(height: 8));
                          items.add(_buildExpensePopupMenuItem(
                            value: 'archive',
                            icon: Icons.archive_outlined,
                            color: const Color(0xFF64748B),
                            label: 'Archive Expense',
                          ));
                        }

                        return items;
                      },
                    ),
                  ],
                ),
              ),

              // ── 2. CARD BODY (Roomy, Clean, Preserves 100% of Admin Data) ──
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Category Icon Container + Title + Requester Subtitle + Hero Gold Amount Box
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: categoryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: categoryColor.withValues(alpha: 0.28)),
                          ),
                          child: Icon(categoryIcon, size: 18, color: categoryColor),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                expense.description,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  fontSize: isMobile ? 14 : 14.5,
                                  color: const Color(0xFF0F172A),
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.person_rounded, size: 11, color: Color(0xFF94A3B8)),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      expense.purchasedBy,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        color: const Color(0xFF64748B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (expense.supplier != null && expense.supplier!.isNotEmpty) ...[
                                    const SizedBox(width: 4),
                                    const Text('•', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        expense.supplier!,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          color: const Color(0xFF64748B),
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Hero Amount Box (Dark Enterprise Green with Gold Text)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14332E),
                            borderRadius: BorderRadius.circular(9),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF14332E).withValues(alpha: 0.18),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '₱ ',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFE6C374),
                                  ),
                                ),
                                TextSpan(
                                  text: NumberFormat('#,##0.00').format(expense.amount),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFFE6C374),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Multi-item inventory pills (Clean & capped presentation)
                    if (expense.isMultiItemExpense && expense.inventoryItems != null && expense.inventoryItems!.isNotEmpty) ...[
                      Builder(
                        builder: (context) {
                          final items = expense.inventoryItems!;
                          final maxVisible = items.length > 3 ? 2 : 3;
                          final visibleItems = items.take(maxVisible).toList();
                          final remainingCount = items.length - visibleItems.length;

                          return Wrap(
                            spacing: 5,
                            runSpacing: 5,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              ...visibleItems.map((item) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.inventory_2_rounded, size: 10.5, color: Color(0xFF64748B)),
                                      const SizedBox(width: 4),
                                      ConstrainedBox(
                                        constraints: BoxConstraints(maxWidth: isMobile ? 120 : 150),
                                        child: Text(
                                          item.itemName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF334155),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF14332E).withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '×${item.quantity}',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF14332E),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              if (remainingCount > 0)
                                Tooltip(
                                  message: 'Click to view all ${items.length} items',
                                  child: InkWell(
                                    onTap: () => _showExpenseDetailsModal(expense),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF14332E).withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFF14332E).withValues(alpha: 0.2)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.add_circle_outline_rounded, size: 11, color: Color(0xFF14332E)),
                                          const SizedBox(width: 3.5),
                                          Text(
                                            '+$remainingCount more items',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFF14332E),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                    ] else if (expense.inventoryItemName != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.inventory_2_rounded, size: 11, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: isMobile ? 180 : 250),
                              child: Text(
                                '${expense.inventoryItemName!} ×${expense.quantityPurchased ?? 1}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Notes preview if available
                    if (expense.notes != null && expense.notes!.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          'Note: ${expense.notes!}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontStyle: FontStyle.italic,
                            color: const Color(0xFF64748B),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Row 3: Structured Footer Bar with Receipt info, Date, Photo, and Admin Quick Actions
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            expense.receiptNumber?.isNotEmpty == true
                                ? Icons.receipt_outlined
                                : Icons.calendar_today_outlined,
                            size: 12,
                            color: const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              expense.isNonOr
                                  ? '🏷️ Non-OR #${expense.receiptNumber ?? 'FARE'} • ${DateFormat('MMM d, yyyy').format(expense.expenseDate)}'
                                  : (expense.receiptNumber?.isNotEmpty == true
                                      ? 'Receipt #${expense.receiptNumber} • ${DateFormat('MMM d, yyyy').format(expense.expenseDate)}'
                                      : 'Date: ${DateFormat('EEE, MMM d, yyyy').format(expense.expenseDate)}'),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                color: expense.isNonOr ? const Color(0xFF0D9488) : const Color(0xFF475569),
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (expense.receiptImageUrl != null) ...[
                            InkWell(
                              onTap: () => _showReceiptLightbox(expense.receiptImageUrl!),
                              borderRadius: BorderRadius.circular(5),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.photo_rounded, size: 10, color: Color(0xFF0D9488)),
                                    const SizedBox(width: 3),
                                    Text(
                                      'PHOTO',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF0D9488),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],

                          // Direct Admin verification action buttons
                          if (_isAdmin && expense.status == 'pending') ...[
                            InkWell(
                              onTap: () => _rejectExpense(expense.id!),
                              borderRadius: BorderRadius.circular(5),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(color: const Color(0xFFFECACA)),
                                ),
                                child: Text(
                                  'REJECT',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            InkWell(
                              onTap: () => _approveExpense(expense.id!),
                              borderRadius: BorderRadius.circular(5),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF14332E),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  'APPROVE',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ] else if (_isAdmin && expense.status == 'approved') ...[
                            InkWell(
                              onTap: () => _markAsReimbursed(expense.id!),
                              borderRadius: BorderRadius.circular(5),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: expense.isAbono ? const Color(0xFFD97706) : const Color(0xFF14332E),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  expense.isAbono ? 'PAY STAFF' : 'REIMBURSE',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ] else if (expense.isArchived) ...[
                            InkWell(
                              onTap: () => _toggleArchiveExpense(expense),
                              borderRadius: BorderRadius.circular(5),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF14332E).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  'RESTORE',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF14332E),
                                  ),
                                ),
                              ),
                            ),
                          ] else if (expense.status == 'approved' || expense.status == 'reimbursed') ...[
                            InkWell(
                              onTap: () => _toggleArchiveExpense(expense),
                              borderRadius: BorderRadius.circular(5),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF64748B).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  'ARCHIVE',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
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
  // SET PETTY CASH FUND AMOUNT DIALOG
  // ---------------------------------------------------------------------------
  void _showSetFundAmountDialog([PettyCashFund? initialFund]) async {
    final currentFund = initialFund ?? await _pettyCashService.getPettyCashFund();
    if (!mounted) return;

    final balanceCtrl = TextEditingController(
      text: (currentFund?.currentBalance != null && currentFund!.currentBalance > 0)
          ? currentFund.currentBalance.toStringAsFixed(2)
          : '',
    );
    final ceilingCtrl = TextEditingController(
      text: (currentFund?.initialBalance != null && currentFund!.initialBalance > 0)
          ? currentFund.initialBalance.toStringAsFixed(2)
          : '',
    );
    final thresholdCtrl = TextEditingController(
      text: (currentFund?.lowBalanceThreshold != null && currentFund!.lowBalanceThreshold > 0)
          ? currentFund.lowBalanceThreshold.toStringAsFixed(0)
          : '2000',
    );

    bool syncCeiling = true;
    bool isSaving = false;

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD9A441).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFD9A441).withValues(alpha: 0.3)),
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          color: Color(0xFFB47F18),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Set Petty Cash Amount',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Directly set or calibrate the branch cashbox balance',
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
                        onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 16),

                  // Current Status Info Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Balance',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₱${NumberFormat('#,##0.00').format(currentFund?.currentBalance ?? 0.0)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF14332E),
                              ),
                            ),
                          ],
                        ),
                        Container(width: 1, height: 28, color: const Color(0xFFCBD5E1)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Fund Ceiling',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₱${NumberFormat('#,##0.00').format(currentFund?.initialBalance ?? 0.0)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFD9A441),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quick Preset Pills
                  Text(
                    'Quick Presets',
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
                    children: [5000.0, 10000.0, 15000.0, 20000.0, 50000.0, 100000.0].map((preset) {
                      return InkWell(
                        onTap: () {
                          setDialogState(() {
                            balanceCtrl.text = preset.toStringAsFixed(0);
                            if (syncCeiling) {
                              ceilingCtrl.text = preset.toStringAsFixed(0);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Text(
                            '₱${NumberFormat('#,##0').format(preset)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF14332E),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // New Amount Input
                  Text(
                    'Target Fund Balance (₱) *',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: balanceCtrl,
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
                    onChanged: (val) {
                      if (syncCeiling) {
                        setDialogState(() {
                          ceilingCtrl.text = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Sync ceiling checkbox
                  CheckboxListTile(
                    value: syncCeiling,
                    onChanged: (val) {
                      setDialogState(() {
                        syncCeiling = val ?? true;
                        if (syncCeiling) {
                          ceilingCtrl.text = balanceCtrl.text;
                        }
                      });
                    },
                    title: Text(
                      'Also set as Fund Ceiling (Maximum capacity)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF334155),
                      ),
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: const Color(0xFF14332E),
                  ),

                  if (!syncCeiling) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Custom Fund Ceiling (₱)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: ceilingCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        prefixText: '₱ ',
                        hintText: '0.00',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                    ),
                  ],

                  const SizedBox(height: 8),
                  Text(
                    'Low Reserve Alert Limit (₱)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: thresholdCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      prefixText: '₱ ',
                      hintText: '2000',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                        onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
                                final targetBalance = double.tryParse(balanceCtrl.text.trim());
                                if (targetBalance == null || targetBalance < 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Please enter a valid amount', style: GoogleFonts.plusJakartaSans()),
                                      backgroundColor: const Color(0xFFDC2626),
                                    ),
                                  );
                                  return;
                                }

                                final targetCeiling = syncCeiling
                                    ? targetBalance
                                    : (double.tryParse(ceilingCtrl.text.trim()) ?? targetBalance);
                                final lowThreshold = double.tryParse(thresholdCtrl.text.trim()) ?? 2000.0;

                                setDialogState(() => isSaving = true);
                                final success = await _pettyCashService.setPettyCashFundAmount(
                                  targetBalance: targetBalance,
                                  targetCeiling: targetCeiling,
                                  lowBalanceThreshold: lowThreshold,
                                );

                                if (dialogCtx.mounted) {
                                  Navigator.pop(dialogCtx);
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        success
                                            ? 'Petty cash fund successfully updated to ₱${NumberFormat('#,##0.00').format(targetBalance)}'
                                            : 'Failed to update fund balance',
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
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFFD9A441)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Update Fund',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
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
                      Expanded(
                        child: Text(
                          'Expected System Balance:',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
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
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isSaving ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF475569),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
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
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Save Audit Record',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
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
  // SPENDING REPORT DIALOG (DEDUPLICATED, ACCURATE & ENTERPRISE UI)
  // ---------------------------------------------------------------------------
  // ignore: unused_element
  void _showSpendingReportDialog() async {
    final report = await _pettyCashService.getSpendingReport();
    final budgets = await _pettyCashService.getAllCategoryBudgets();
    final fund = await _pettyCashService.getPettyCashFund();

    if (!mounted) return;

    final rawSpendingByCategory = (report['spending_by_category'] as Map<String, dynamic>?) ?? {};
    final spendingByCategory = <String, dynamic>{};
    rawSpendingByCategory.forEach((k, v) {
      final key = k.toLowerCase().trim();
      if (key != 'utilities' && key != 'maintenance') {
        spendingByCategory[k] = v;
      }
    });

    final totalSpent = spendingByCategory.values.fold<double>(
      0.0,
      (sum, val) => sum + ((val as num?)?.toDouble() ?? 0.0),
    );
    final expenseCount = (report['expense_count'] as num?)?.toInt() ?? 0;
    final avgExpense = expenseCount > 0 ? totalSpent / expenseCount : 0.0;
    
    final budgetMap = <String, PettyCashCategoryBudget>{};
    for (final b in budgets) {
      final cat = b.category.toLowerCase().trim();
      if (cat != 'utilities' && cat != 'maintenance') {
        budgetMap[cat] = b;
      }
    }

    final allCatKeys = <String>{
      ...budgetMap.keys,
      ...spendingByCategory.keys.map((k) => k.toLowerCase().trim()),
    }.where((k) => k.isNotEmpty && k != 'utilities' && k != 'maintenance').toList();

    allCatKeys.sort((a, b) {
      final spentA = (spendingByCategory[a] as num?)?.toDouble() ?? 0.0;
      final spentB = (spendingByCategory[b] as num?)?.toDouble() ?? 0.0;
      if (spentB != spentA) return spentB.compareTo(spentA);
      return a.compareTo(b);
    });

    String topCategory = '';
    double topAmount = 0.0;
    if (allCatKeys.isNotEmpty) {
      final firstSpent = (spendingByCategory[allCatKeys.first] as num?)?.toDouble() ?? 0.0;
      if (firstSpent > 0) {
        topCategory = allCatKeys.first;
        topAmount = firstSpent;
      }
    }

    final effectiveBalance = (fund?.currentBalance ?? 0.0) > 0
        ? fund!.currentBalance
        : ((fund?.initialBalance ?? 0.0) > 0 ? fund!.initialBalance : totalSpent);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
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
                    ),
                    child: const Icon(
                      Icons.analytics_rounded,
                      color: Color(0xFFD9A441),
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
                          'Trailing 30-day verified outflow vs category caps',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
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
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Key KPI Tiles Row (3 High-impact metrics)
                      Row(
                        children: [
                          Expanded(
                            child: _buildReportKpi(
                              '30-Day Outflow',
                              '₱${NumberFormat('#,##0.00').format(totalSpent)}',
                              '$expenseCount records',
                              Icons.payments_rounded,
                              const Color(0xFF14332E),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildReportKpi(
                              'Avg. Expense',
                              '₱${NumberFormat('#,##0.00').format(avgExpense)}',
                              'per claim',
                              Icons.query_stats_rounded,
                              const Color(0xFF14332E),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildReportKpi(
                              'Top Category',
                              topCategory.isNotEmpty ? _formatCategoryName(topCategory) : 'None',
                              topAmount > 0 ? '₱${NumberFormat('#,##0').format(topAmount)}' : '—',
                              Icons.trending_up_rounded,
                              const Color(0xFF14332E),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      Text(
                        'Category Allocations vs Actual Spend',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Live comparison of actual disbursements against allocated budget caps',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 12),

                      ...allCatKeys.map((catKey) {
                        final actualSpent = (spendingByCategory[catKey] as num?)?.toDouble() ?? 0.0;
                        final budget = budgetMap[catKey];
                        final allocated = budget != null ? budget.getAllocatedAmount(effectiveBalance) : 0.0;
                        final hasCap = allocated > 0;
                        final isOverBudget = hasCap && actualSpent > allocated;
                        final isWarning = hasCap && (actualSpent / allocated) >= 0.75 && !isOverBudget;
                        final rawProgress = hasCap
                            ? (actualSpent / allocated)
                            : (totalSpent > 0 ? (actualSpent / totalSpent) : 0.0);
                        final progressVal = (rawProgress.isNaN || rawProgress.isInfinite)
                            ? 0.0
                            : rawProgress.clamp(0.0, 1.0);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isOverBudget ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isOverBudget ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isOverBudget
                                          ? const Color(0xFFDC2626).withValues(alpha: 0.1)
                                          : const Color(0xFF14332E).withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      _getCategoryIcon(catKey),
                                      size: 16,
                                      color: isOverBudget ? const Color(0xFFDC2626) : const Color(0xFF14332E),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                _formatCategoryName(catKey),
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(0xFF0F172A),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (budget != null && budget.percentage > 0) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF14332E).withValues(alpha: 0.08),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '${budget.percentage.toStringAsFixed(0)}% cap',
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: const Color(0xFF14332E),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        if (hasCap)
                                          Text(
                                            isOverBudget
                                                ? '⚠️ Over limit by ₱${NumberFormat('#,##0.00').format(actualSpent - allocated)}'
                                                : '✓ ₱${NumberFormat('#,##0.00').format(allocated - actualSpent)} buffer remaining',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: isOverBudget
                                                  ? const Color(0xFFDC2626)
                                                  : const Color(0xFF15803D),
                                            ),
                                          )
                                        else
                                          Text(
                                            '${((actualSpent / (totalSpent > 0 ? totalSpent : 1)) * 100).toStringAsFixed(1)}% of total 30-day spend',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFF64748B),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₱${NumberFormat('#,##0.00').format(actualSpent)}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                          color: isOverBudget ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      Text(
                                        hasCap
                                            ? 'Cap: ₱${NumberFormat('#,##0').format(allocated)}'
                                            : 'Uncapped',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  height: 6,
                                  color: const Color(0xFFE2E8F0),
                                  child: LinearProgressIndicator(
                                    value: progressVal,
                                    backgroundColor: const Color(0xFFE2E8F0),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isOverBudget
                                          ? const Color(0xFFDC2626)
                                          : (isWarning ? const Color(0xFFF59E0B) : const Color(0xFF15803D)),
                                    ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: Text(
                    'Close',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportKpi(String label, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label.isEmpty ? ' ' : label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, color: const Color(0xFF14332E), size: 14),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? '₱0.00' : value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle.isEmpty ? ' ' : subtitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF94A3B8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatCategoryName(String key) {
    if (key.trim().isEmpty) return 'General';
    switch (key.toLowerCase().trim()) {
      case 'inventory_purchase':
        return 'Inventory Purchase';
      case 'kitchen_supplies':
        return 'Kitchen Supplies';
      case 'maintenance':
        return 'Maintenance';
      case 'transportation':
        return 'Transportation';
      case 'utilities':
        return 'Utilities';
      case 'supplies':
        return 'Supplies';
      case 'other':
        return 'Other Supplies';
      default:
        final words = key.split('_').where((w) => w.trim().isNotEmpty).toList();
        if (words.isEmpty) return 'General';
        return words.map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
    }
  }

  // ---------------------------------------------------------------------------
  // BUDGET MANAGEMENT DIALOG (FULLY FUNCTIONAL & INTERACTIVE)
  // ---------------------------------------------------------------------------
  void _showBudgetManagementDialog() async {
    List<PettyCashCategoryBudget> budgets = [];
    PettyCashFund? fund;
    bool isLoading = true;

    Future<void> reloadData() async {
      final allBudgets = await _pettyCashService.getAllCategoryBudgets();
      budgets = allBudgets.where((b) {
        final cat = b.category.toLowerCase().trim();
        return cat != 'utilities' && cat != 'maintenance';
      }).toList();
      fund = await _pettyCashService.getPettyCashFund();
      isLoading = false;
    }

    await reloadData();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) {
          final fundBase = (fund?.currentBalance != null && fund!.currentBalance > 0)
              ? fund!.currentBalance
              : (fund?.initialBalance ?? 0.0);

          final totalAllocatedPct = budgets.fold<double>(0.0, (sum, b) => sum + b.percentage);
          final totalCapAmount = fundBase * (totalAllocatedPct / 100);

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              padding: const EdgeInsets.all(22),
              constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Dialog Header
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
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Balance: ₱${NumberFormat('#,##0.00').format(fundBase)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Reset All Spent Counters to ₱0.00',
                        icon: const Icon(Icons.restart_alt_rounded, color: Color(0xFF64748B), size: 20),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: dialogCtx,
                            builder: (c) => AlertDialog(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: Text(
                                'Reset All Spent Counters?',
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16),
                              ),
                              content: Text(
                                'This will reset the spent trackers for all categories back to ₱0.00 for the current balance.',
                                style: GoogleFonts.plusJakartaSans(fontSize: 13),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFDC2626),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                  ),
                                  child: const Text('Reset to ₱0.00'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            setModalState(() => isLoading = true);
                            await _pettyCashService.resetAllCategorySpent();
                            await reloadData();
                            setModalState(() {});
                            if (dialogCtx.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('All category spent counters reset to ₱0.00', style: GoogleFonts.plusJakartaSans()),
                                  backgroundColor: const Color(0xFF15803D),
                                ),
                              );
                            }
                          }
                        },
                      ),
                      IconButton(
                        tooltip: 'Refresh / Sync',
                        icon: const Icon(Icons.sync_rounded, color: Color(0xFF64748B), size: 20),
                        onPressed: () async {
                          setModalState(() => isLoading = true);
                          await reloadData();
                          setModalState(() {});
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(dialogCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Total Fund Allocation Meter Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Total Allocated:',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF475569),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${totalAllocatedPct.toStringAsFixed(1)}% (₱${NumberFormat('#,##0.00').format(totalCapAmount)})',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: totalAllocatedPct > 100
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFF14332E),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              totalAllocatedPct > 100
                                  ? 'Exceeds 100% Fund'
                                  : '${(100 - totalAllocatedPct).toStringAsFixed(1)}% unallocated',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: totalAllocatedPct > 100
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF15803D),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (totalAllocatedPct / 100).clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              totalAllocatedPct > 100
                                  ? const Color(0xFFDC2626)
                                  : (totalAllocatedPct == 100
                                      ? const Color(0xFFD97706)
                                      : const Color(0xFF15803D)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Category Cards List
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.separated(
                            itemCount: budgets.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 9),
                            itemBuilder: (context, index) {
                              final budget = budgets[index];
                              final allocated = fundBase * (budget.percentage / 100);
                              final currentSpent = budget.currentSpent;
                              final isOverBudget = allocated > 0 && currentSpent > allocated;
                              final isNearLimit = allocated > 0 &&
                                  !isOverBudget &&
                                  (currentSpent / allocated) >= 0.8;
                              final progress = allocated > 0
                                  ? (currentSpent / allocated).clamp(0.0, 1.0)
                                  : 0.0;

                              return InkWell(
                                onTap: () => _showEditBudgetDialog(
                                  budget: budget,
                                  fundBase: fundBase,
                                  onSaved: () async {
                                    await reloadData();
                                    setModalState(() {});
                                  },
                                ),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isOverBudget
                                          ? const Color(0xFFFCA5A5)
                                          : (isNearLimit ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0)),
                                      width: isOverBudget || isNearLimit ? 1.5 : 1,
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
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: _getCategoryColor(budget.category).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              _getCategoryIcon(budget.category),
                                              size: 16,
                                              color: _getCategoryColor(budget.category),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    _formatCategoryName(budget.category),
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w700,
                                                      color: const Color(0xFF0F172A),
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
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
                                                if (isOverBudget) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      'OVER BUDGET',
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.w800,
                                                        color: const Color(0xFFDC2626),
                                                      ),
                                                    ),
                                                  ),
                                                ] else if (isNearLimit) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFD97706).withValues(alpha: 0.12),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      'NEAR CAP',
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.w800,
                                                        color: const Color(0xFFD97706),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Edit Budget Cap',
                                            icon: const Icon(Icons.edit_outlined, size: 17, color: Color(0xFF14332E)),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () => _showEditBudgetDialog(
                                              budget: budget,
                                              fundBase: fundBase,
                                              onSaved: () async {
                                                await reloadData();
                                                setModalState(() {});
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Cap: ₱${NumberFormat('#,##0.00').format(allocated)} • Spent: ₱${NumberFormat('#,##0.00').format(currentSpent)}',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: isOverBudget
                                                  ? const Color(0xFFDC2626)
                                                  : (isNearLimit
                                                      ? const Color(0xFFD97706)
                                                      : const Color(0xFF64748B)),
                                            ),
                                          ),
                                          if (allocated > 0)
                                            Text(
                                              '${(currentSpent / allocated * 100).toStringAsFixed(0)}% spent',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: isOverBudget
                                                    ? const Color(0xFFDC2626)
                                                    : (isNearLimit ? const Color(0xFFD97706) : const Color(0xFF64748B)),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(3),
                                        child: LinearProgressIndicator(
                                          value: progress,
                                          minHeight: 4,
                                          backgroundColor: const Color(0xFFF1F5F9),
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            isOverBudget
                                                ? const Color(0xFFDC2626)
                                                : (isNearLimit
                                                    ? const Color(0xFFD97706)
                                                    : (allocated == 0
                                                        ? const Color(0xFFCBD5E1)
                                                        : const Color(0xFF15803D))),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 14),

                  // Dialog Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF14332E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: Text(
                          'Close',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }


  void _showEditBudgetDialog({
    required PettyCashCategoryBudget budget,
    required double fundBase,
    required VoidCallback onSaved,
  }) {
    final double initialAmount = fundBase * (budget.percentage / 100);
    final percentageCtrl = TextEditingController(text: budget.percentage.toStringAsFixed(1));
    final amountCtrl = TextEditingController(text: initialAmount.toStringAsFixed(2));

    bool isUpdatingFromPct = false;
    bool isUpdatingFromAmount = false;
    bool isSaving = false;

    percentageCtrl.addListener(() {
      if (isUpdatingFromAmount) return;
      isUpdatingFromPct = true;
      final pct = double.tryParse(percentageCtrl.text.trim()) ?? 0.0;
      final calculatedAmount = fundBase * (pct / 100);
      amountCtrl.text = calculatedAmount.toStringAsFixed(2);
      isUpdatingFromPct = false;
    });

    amountCtrl.addListener(() {
      if (isUpdatingFromPct) return;
      isUpdatingFromAmount = true;
      final amt = double.tryParse(amountCtrl.text.trim().replaceAll(',', '')) ?? 0.0;
      final calculatedPct = fundBase > 0 ? (amt / fundBase) * 100 : 0.0;
      percentageCtrl.text = calculatedPct.toStringAsFixed(1);
      isUpdatingFromAmount = false;
    });

    showDialog(
      context: context,
      builder: (editCtx) => StatefulBuilder(
        builder: (editCtx, setEditState) {
          final catName = _formatCategoryName(budget.category);
          final currentPct = double.tryParse(percentageCtrl.text.trim()) ?? 0.0;
          final currentCap = fundBase * (currentPct / 100);

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(budget.category).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getCategoryIcon(budget.category),
                    size: 20,
                    color: _getCategoryColor(budget.category),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit $catName Cap',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Petty Cash Balance: ₱${NumberFormat('#,##0.00').format(fundBase)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 6),

                  // Cap Amount Field (Pesos)
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Allocated Cap Amount (₱)',
                      labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
                      prefixText: '₱ ',
                      prefixStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF14332E), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Percentage of Balance Field
                  TextField(
                    controller: percentageCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Percentage of Balance (%)',
                      labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
                      suffixText: '%',
                      suffixStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF14332E), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Quick Percentage Preset Chips
                  Text(
                    'Quick Presets:',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [0.0, 10.0, 15.0, 20.0, 25.0, 30.0, 50.0].map((preset) {
                      final isSelected = (currentPct - preset).abs() < 0.2;
                      return InkWell(
                        onTap: () {
                          percentageCtrl.text = preset.toStringAsFixed(1);
                          setEditState(() {});
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF14332E)
                                : const Color(0xFF14332E).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            preset == 0.0 ? 'None (0%)' : '${preset.toStringAsFixed(0)}%',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : const Color(0xFF14332E),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Summary Card
                  Container(
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
                              'Calculated Cap:',
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF64748B)),
                            ),
                            Text(
                              '₱${NumberFormat('#,##0.00').format(currentCap)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF14332E),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Current Spent:',
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF64748B)),
                            ),
                            Text(
                              '₱${NumberFormat('#,##0.00').format(budget.currentSpent)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: budget.currentSpent > currentCap && currentCap > 0
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        if (budget.currentSpent > 0) ...[
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () async {
                              final confirm = await showDialog<bool>(
                                context: editCtx,
                                builder: (c) => AlertDialog(
                                  title: const Text('Reset Spent Amount?'),
                                  content: Text(
                                    'This will reset the spent counter for $catName back to ₱0.00.',
                                    style: GoogleFonts.plusJakartaSans(),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(c, true),
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                                      child: const Text('Reset to ₱0'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                await _pettyCashService.resetCategorySpent(budget.category);
                                onSaved();
                                if (editCtx.mounted) Navigator.pop(editCtx);
                              }
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.restart_alt_rounded, size: 14, color: Color(0xFF0284C7)),
                                const SizedBox(width: 4),
                                Text(
                                  'Reset spent tracker to ₱0.00',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0284C7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(editCtx),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final pct = double.tryParse(percentageCtrl.text.trim());
                        if (pct != null && pct >= 0 && pct <= 100) {
                          setEditState(() => isSaving = true);
                          final success = await _pettyCashService.updateCategoryBudgetPercentage(budget.category, pct);
                          if (editCtx.mounted) {
                            Navigator.pop(editCtx);
                            onSaved();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  success ? '$catName budget cap updated!' : 'Failed to update budget',
                                  style: GoogleFonts.plusJakartaSans(),
                                ),
                                backgroundColor: success ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                              ),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Please enter a valid percentage between 0 and 100.', style: GoogleFonts.plusJakartaSans()),
                              backgroundColor: const Color(0xFFDC2626),
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF14332E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Save Allocation',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // APPROVAL & REJECTION HANDLERS
  // ---------------------------------------------------------------------------
  Future<void> _approveExpense(String expenseId) async {
    final expenses = await _pettyCashService.getExpenses();
    final expense = expenses.firstWhere((e) => e.id == expenseId);

    // If it's a Kaha expense (not Abono), check if fund is sufficient before approving
    if (!expense.isAbono) {
      final fund = await _pettyCashService.getPettyCashFund();
      final available = fund?.currentBalance ?? 0.0;
      if (expense.amount > available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Insufficient Petty Cash Fund! Available: ₱${NumberFormat('#,##0.00').format(available)}, but expense requires ₱${NumberFormat('#,##0.00').format(expense.amount)}. Please replenish the Petty Cash fund first.',
                style: GoogleFonts.plusJakartaSans(),
              ),
              backgroundColor: const Color(0xFFDC2626),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }
    }

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
        if (expense.isAbono) {
          message = 'Expense approved! Ready for reimbursement (Fund NOT deducted until reimbursed to staff).';
        } else if (expense.category == 'inventory_purchase' &&
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
    final expenses = await _pettyCashService.getExpenses();
    final expense = expenses.where((e) => e.id == expenseId).firstOrNull;

    final success = await _pettyCashService.markAsReimbursed(expenseId);
    if (mounted) {
      final msg = success
          ? ((expense?.isAbono ?? false)
              ? 'Reimbursed to staff and deducted from Petty Cash Fund'
              : 'Expense marked as reimbursed')
          : 'Failed to mark as reimbursed';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: GoogleFonts.plusJakartaSans()),
          backgroundColor: success ? const Color(0xFF15803D) : const Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _toggleArchiveExpense(PettyCashExpense expense) async {
    final willArchive = !expense.isArchived;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              willArchive ? Icons.archive_rounded : Icons.unarchive_rounded,
              color: willArchive ? const Color(0xFF475569) : const Color(0xFF15803D),
            ),
            const SizedBox(width: 8),
            Text(
              willArchive ? 'Ilagay sa Archive?' : 'Ibalik mula sa Archive?',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          willArchive
              ? 'Maitatago ang expense na ito sa Archive tab para malinis ang listahan nang hindi ito nabubura.'
              : 'Ibabalik ang expense na ito sa aktibong listahan.',
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Kanselahin', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: willArchive ? const Color(0xFF475569) : const Color(0xFF14332E),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(willArchive ? 'Ilagay sa Archive' : 'Ibalik'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await _pettyCashService.archiveExpense(expense.id!, archive: willArchive);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? (willArchive ? 'Nailagay na sa Archive ang expense' : 'Naibalik na mula sa Archive ang expense')
              : 'Hindi nagtagumpay ang pag-archive',
          style: GoogleFonts.plusJakartaSans(),
        ),
        backgroundColor: success ? const Color(0xFF15803D) : const Color(0xFFDC2626),
      ),
    );
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

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase().trim()) {
      case 'inventory purchase':
      case 'inventory_purchase':
        return const Color(0xFF0D9488); // Teal Green
      case 'supplies':
      case 'kitchen_supplies':
        return const Color(0xFF16A34A); // Emerald Green
      case 'transportation':
        return const Color(0xFF0284C7); // Sky Blue
      case 'maintenance':
        return const Color(0xFF4F46E5); // Indigo
      case 'utilities':
        return const Color(0xFF9333EA); // Purple
      case 'other':
        return const Color(0xFFD97706); // Golden Amber
      default:
        return const Color(0xFF14332E);
    }
  }
}
