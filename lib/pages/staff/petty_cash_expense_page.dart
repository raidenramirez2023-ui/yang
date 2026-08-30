import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/models/petty_cash_model.dart';
import 'package:yang_chow/services/petty_cash_service.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';

class PettyCashExpensePage extends StatefulWidget {
  const PettyCashExpensePage({super.key});

  @override
  State<PettyCashExpensePage> createState() => _PettyCashExpensePageState();
}

class _PettyCashExpensePageState extends State<PettyCashExpensePage> {
  final PettyCashService _pettyCashService = PettyCashService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedStatusFilter = 'All';
  String _selectedCategoryFilter = 'All';
  String _selectedSort = 'newest'; // 'newest', 'oldest', 'highest', 'lowest'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);

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

                // Financial Executive Card & Fund Overview
                _buildFundOverviewSection(isMobile, isTablet),
                const SizedBox(height: 20),

                // Expenses Section with Filter Toolbar & List
                _buildExpensesSection(isMobile),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFFD9A441), Color(0xFFB88220)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD9A441).withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _showAddExpenseDialog,
          backgroundColor: Colors.transparent,
          elevation: 0,
          highlightElevation: 0,
          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
          label: Text(
            'Record Expense',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: 0.2,
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
        horizontal: isMobile ? 16 : 20,
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF14332E), Color(0xFF1E4A42)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF14332E).withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Color(0xFFD9A441),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Petty Cash Management',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: isMobile ? 17 : 20,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD9A441).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFD9A441).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'Pagsanjan Branch',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
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
          if (!isMobile)
            ElevatedButton.icon(
              onPressed: _showAddExpenseDialog,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Expense'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF14332E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FUND OVERVIEW & EXECUTIVE CARD
  // ---------------------------------------------------------------------------
  Widget _buildFundOverviewSection(bool isMobile, bool isTablet) {
    return StreamBuilder<PettyCashFund?>(
      stream: _pettyCashService.streamPettyCashFund(),
      builder: (context, fundSnapshot) {
        return StreamBuilder<List<PettyCashExpense>>(
          stream: _pettyCashService.streamExpenses(),
          builder: (context, expenseSnapshot) {
            final fund = fundSnapshot.data;
            final expenses = expenseSnapshot.data ?? [];
            final user = Supabase.instance.client.auth.currentUser;
            final myExpenses = expenses.where((e) => e.purchasedBy == user?.email).toList();

            // Calculate metric stats
            final totalMyExpenses = myExpenses.fold<double>(
              0.0,
              (sum, item) => sum + item.amount,
            );
            final pendingExpenses = myExpenses.where((e) => e.status == 'pending').toList();
            final pendingTotal = pendingExpenses.fold<double>(
              0.0,
              (sum, item) => sum + item.amount,
            );
            final approvedExpenses = myExpenses.where((e) => e.status == 'approved' || e.status == 'reimbursed').toList();
            final approvedTotal = approvedExpenses.fold<double>(
              0.0,
              (sum, item) => sum + item.amount,
            );

            return _buildAnalyticsGrid(
              fund: fund,
              totalExpenses: totalMyExpenses,
              expenseCount: myExpenses.length,
              pendingTotal: pendingTotal,
              pendingCount: pendingExpenses.length,
              approvedTotal: approvedTotal,
              approvedCount: approvedExpenses.length,
              isMobile: isMobile,
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // ANALYTICS 4-GRID TILES
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
        subtitle: fund?.isLowBalance == true ? '⚠️ Refill Recommended' : '🟢 Ready for Purchases',
        icon: Icons.account_balance_wallet_rounded,
        accentColor: const Color(0xFF14332E),
        iconColor: const Color(0xFF34C759),
        bgTint: const Color(0xFFE8F5E9),
      ),
      _buildMetricTile(
        title: 'My Filed Expenses',
        value: '₱${NumberFormat('#,##0.00').format(totalExpenses)}',
        subtitle: '$expenseCount total entries recorded',
        icon: Icons.bar_chart_rounded,
        accentColor: const Color(0xFF0F172A),
        iconColor: const Color(0xFF0284C7),
        bgTint: const Color(0xFFE0F2FE),
      ),
      _buildMetricTile(
        title: 'Pending Approvals',
        value: '₱${NumberFormat('#,##0.00').format(pendingTotal)}',
        subtitle: '$pendingCount pending review',
        icon: Icons.hourglass_top_rounded,
        accentColor: const Color(0xFFD97706),
        iconColor: const Color(0xFFD97706),
        bgTint: const Color(0xFFFEF3C7),
      ),
      _buildMetricTile(
        title: 'Approved / Settled',
        value: '₱${NumberFormat('#,##0.00').format(approvedTotal)}',
        subtitle: '$approvedCount approved transactions',
        icon: Icons.verified_rounded,
        accentColor: const Color(0xFF15803D),
        iconColor: const Color(0xFF15803D),
        bgTint: const Color(0xFFDCFCE7),
      ),
    ];

    if (isMobile) {
      return SizedBox(
        height: 118,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          clipBehavior: Clip.none,
          children: cards
              .map((card) => Container(
                    width: 215,
                    margin: const EdgeInsets.only(right: 10),
                    child: card,
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
    required Color accentColor,
    required Color iconColor,
    required Color bgTint,
  }) {
    return Container(
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
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: bgTint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF0F172A),
              fontSize: 16,
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
  // EXPENSES SECTION & FILTER TOOLBAR
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
                  'Expense Records',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.4,
                  ),
                ),
                Text(
                  'Review and track your purchase reimbursements',
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
              hintText: 'Search by description, inventory item, supplier, or receipt #...',
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
              _buildFilterPill('All', Icons.apps_rounded, const Color(0xFF14332E)),
              _buildFilterPill('Pending', Icons.pending_rounded, const Color(0xFFD97706)),
              _buildFilterPill('Approved', Icons.check_circle_rounded, const Color(0xFF15803D)),
              _buildFilterPill('Reimbursed', Icons.payments_rounded, const Color(0xFF0284C7)),
              _buildFilterPill('Rejected', Icons.cancel_rounded, const Color(0xFFDC2626)),
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

            final user = Supabase.instance.client.auth.currentUser;
            final allExpenses = snapshot.data ?? [];
            final myExpenses = allExpenses.where((e) => e.purchasedBy == user?.email).toList();

            // Apply Status Filter
            var filtered = myExpenses.where((e) {
              if (_selectedStatusFilter == 'All') return true;
              return e.status.toLowerCase() == _selectedStatusFilter.toLowerCase();
            }).toList();

            // Apply Category Filter
            if (_selectedCategoryFilter != 'All') {
              filtered = filtered.where((e) => e.category == _selectedCategoryFilter).toList();
            }

            // Apply Search Query Filter
            if (_searchQuery.isNotEmpty) {
              filtered = filtered.where((e) {
                final desc = e.description.toLowerCase();
                final supp = (e.supplier ?? '').toLowerCase();
                final rcpt = (e.receiptNumber ?? '').toLowerCase();
                final cat = e.categoryDisplay.toLowerCase();
                final items = (e.inventoryItems ?? []).map((i) => i.itemName.toLowerCase()).join(' ');
                final legacyItem = (e.inventoryItemName ?? '').toLowerCase();

                return desc.contains(_searchQuery) ||
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
              return _buildEmptyState(myExpenses.isEmpty);
            }

            return _buildExpensesTable(filtered, isMobile);
          },
        ),
      ],
    );
  }

  Widget _buildFilterPill(String status, IconData icon, Color color) {
    final isSelected = _selectedStatusFilter.toLowerCase() == status.toLowerCase();

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedStatusFilter = status),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFE2E8F0),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
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
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                status,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EXPENSE TABLE (MODERN, RESPONSIVE, DATA-RICH)
  // ---------------------------------------------------------------------------
  Widget _buildExpensesTable(List<PettyCashExpense> expenses, bool isMobile) {
    final totalFilteredAmount = expenses.fold<double>(0.0, (sum, item) => sum + item.amount);

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
          // Table Top Bar: Count & Total Summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.table_chart_rounded, size: 18, color: Color(0xFF14332E)),
                    const SizedBox(width: 8),
                    Text(
                      '${expenses.length} Record${expenses.length == 1 ? '' : 's'} Found',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14332E).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Total: ',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF475569),
                        ),
                      ),
                      Text(
                        '₱${NumberFormat('#,##0.00').format(totalFilteredAmount)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF14332E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Horizontally Scrollable Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 960),
              child: DataTable(
                columnSpacing: 18,
                horizontalMargin: 18,
                headingRowHeight: 46,
                dataRowMinHeight: 64,
                dataRowMaxHeight: 110,
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                headingTextStyle: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF475569),
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
                columns: const [
                  DataColumn(label: Text('DATE')),
                  DataColumn(label: Text('CATEGORY')),
                  DataColumn(label: Text('DESCRIPTION & ITEMS')),
                  DataColumn(label: Text('SUPPLIER')),
                  DataColumn(label: Text('RECEIPT #')),
                  DataColumn(label: Text('AMOUNT')),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: Text('RECEIPT')),
                  DataColumn(label: Text('ACTIONS')),
                ],
                rows: expenses.map((expense) {
                  final rowIndex = expenses.indexOf(expense);
                  final isEven = rowIndex.isEven;

                  Color statusColor;
                  IconData statusIcon;
                  String statusLabel;

                  switch (expense.status.toLowerCase()) {
                    case 'approved':
                      statusColor = const Color(0xFF15803D);
                      statusIcon = Icons.check_circle_rounded;
                      statusLabel = 'Approved';
                      break;
                    case 'rejected':
                      statusColor = const Color(0xFFDC2626);
                      statusIcon = Icons.cancel_rounded;
                      statusLabel = 'Rejected';
                      break;
                    case 'reimbursed':
                      statusColor = const Color(0xFF0284C7);
                      statusIcon = Icons.payments_rounded;
                      statusLabel = 'Reimbursed';
                      break;
                    case 'pending':
                    default:
                      statusColor = const Color(0xFFD97706);
                      statusIcon = Icons.hourglass_top_rounded;
                      statusLabel = 'Pending';
                      break;
                  }

                  final categoryIcon = _getCategoryIcon(expense.category);
                  final categoryColor = _getCategoryColor(expense.category);

                  return DataRow(
                    color: WidgetStateProperty.resolveWith<Color?>((states) {
                      if (states.contains(WidgetState.hovered)) {
                        return const Color(0xFFF8FAFC);
                      }
                      return isEven ? Colors.white : const Color(0xFFFBFDFB);
                    }),
                    cells: [
                      // Date Cell
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 6),
                            Text(
                              DateFormat('MMM d, yyyy').format(expense.expenseDate),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Category Cell
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: categoryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: categoryColor.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(categoryIcon, size: 13, color: categoryColor),
                              const SizedBox(width: 5),
                              Text(
                                expense.categoryDisplay,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: categoryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Description & Items Cell
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 280),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  expense.description,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (expense.isMultiItemExpense && expense.inventoryItems != null && expense.inventoryItems!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 4,
                                    runSpacing: 2,
                                    children: expense.inventoryItems!.take(3).map((item) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Text(
                                          '${item.itemName} ×${item.quantity}',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF475569),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ] else if (expense.inventoryItemName != null) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Text(
                                      '${expense.inventoryItemName!} ×${expense.quantityPurchased ?? 1}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                ],
                                if (expense.notes != null && expense.notes!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Note: ${expense.notes!}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontStyle: FontStyle.italic,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Supplier Cell
                      DataCell(
                        expense.supplier != null && expense.supplier!.isNotEmpty
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.storefront_rounded, size: 14, color: Color(0xFF94A3B8)),
                                  const SizedBox(width: 4),
                                  Text(
                                    expense.supplier!,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: const Color(0xFF475569),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                '—',
                                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFFCBD5E1)),
                              ),
                      ),

                      // Receipt # Cell
                      DataCell(
                        expense.receiptNumber != null && expense.receiptNumber!.isNotEmpty
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Text(
                                  '#${expense.receiptNumber}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF475569),
                                  ),
                                ),
                              )
                            : Text(
                                '—',
                                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFFCBD5E1)),
                              ),
                      ),

                      // Amount Cell
                      DataCell(
                        Text(
                          '₱${NumberFormat('#,##0.00').format(expense.amount)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF14332E),
                          ),
                        ),
                      ),

                      // Status Cell
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, color: statusColor, size: 12),
                              const SizedBox(width: 5),
                              Text(
                                statusLabel,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Receipt Lightbox Action Cell
                      DataCell(
                        expense.receiptImageUrl != null
                            ? OutlinedButton.icon(
                                onPressed: () => _showReceiptLightbox(expense.receiptImageUrl!),
                                icon: const Icon(Icons.photo_library_rounded, size: 13),
                                label: const Text('View'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF14332E),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  side: BorderSide(color: const Color(0xFF14332E).withValues(alpha: 0.3)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  textStyle: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            : Text(
                                '—',
                                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFFCBD5E1)),
                              ),
                      ),

                      // Actions (Edit / Delete) Cell
                      DataCell(
                        expense.status.toLowerCase() == 'pending'
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF1E293B)),
                                    tooltip: 'Edit Expense',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                    onPressed: () => _editExpense(expense),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                                    tooltip: 'Delete Expense',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                    onPressed: () => _deleteExpense(expense.id!),
                                  ),
                                ],
                              )
                            : Tooltip(
                                message: 'Only pending expenses can be edited or deleted',
                                child: Icon(
                                  Icons.lock_outline_rounded,
                                  size: 15,
                                  color: const Color(0xFF94A3B8).withValues(alpha: 0.6),
                                ),
                              ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
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
            isCompletelyEmpty ? 'No Expenses Recorded Yet' : 'No Matching Expenses Found',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isCompletelyEmpty
                ? 'Tap the Record Expense button below to log your first branch purchase.'
                : 'Try adjusting your search query or status filter.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: const Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _showAddExpenseDialog,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Record New Expense'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF14332E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
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
  // ADD EXPENSE DIALOG (REALISTIC MODAL)
  // ---------------------------------------------------------------------------
  void _showAddExpenseDialog() {
    final descriptionCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final supplierCtrl = TextEditingController();
    final receiptNumberCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    String? selectedCategory = 'inventory_purchase';
    List<Map<String, dynamic>> inventoryItems = [];
    List<Map<String, dynamic>> selectedInventoryItems = [];
    final itemSearchCtrl = TextEditingController();
    String itemSearchQuery = '';
    dynamic receiptImage;
    String? receiptImageUrl;
    Set<String> tempSelectedIds = {};
    bool isSaving = false;

    // Load initial inventory items
    _loadInventoryItems().then((items) {
      inventoryItems = items;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isMobile = ResponsiveUtils.isMobile(context);

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              padding: EdgeInsets.all(isMobile ? 18 : 24),
              constraints: BoxConstraints(
                maxWidth: isMobile ? double.infinity : 560,
                maxHeight: MediaQuery.of(context).size.height * 0.88,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 30,
                    offset: Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
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
                          Icons.add_circle_outline_rounded,
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
                              'Record New Expense',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Pagsanjan Branch Petty Cash Entry',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: isSaving ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 16),

                  // Form Fields (Scrollable)
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category Selector
                          Text(
                            'Expense Category',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: selectedCategory,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.category_rounded, size: 20),
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
                            items: PettyCashExpense.categories
                                .map((category) => DropdownMenuItem(
                                      value: category,
                                      child: Text(
                                        category
                                            .split('_')
                                            .map((word) => word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}')
                                            .join(' '),
                                        style: GoogleFonts.plusJakartaSans(fontSize: 13),
                                      ),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setDialogState(() => selectedCategory = value);
                              if (value == 'inventory_purchase' && inventoryItems.isEmpty) {
                                _loadInventoryItems().then((items) {
                                  setDialogState(() => inventoryItems = items);
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 14),

                          // Inventory Item Selection Section (Only for inventory_purchase)
                          if (selectedCategory == 'inventory_purchase') ...[
                            _buildInventorySelectorBox(
                              inventoryItems: inventoryItems,
                              selectedInventoryItems: selectedInventoryItems,
                              tempSelectedIds: tempSelectedIds,
                              itemSearchCtrl: itemSearchCtrl,
                              itemSearchQuery: itemSearchQuery,
                              setDialogState: setDialogState,
                              onSearchChanged: (val) => setDialogState(() => itemSearchQuery = val),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Description
                          Text(
                            'Description *',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: descriptionCtrl,
                            style: GoogleFonts.plusJakartaSans(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'e.g., Emergency garlic & onion purchase',
                              prefixIcon: const Icon(Icons.description_rounded, size: 20),
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
                            maxLength: 200,
                          ),
                          const SizedBox(height: 10),

                          // Amount Field
                          Text(
                            'Total Amount (₱) *',
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
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF14332E),
                            ),
                            decoration: InputDecoration(
                              prefixText: '₱ ',
                              prefixStyle: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFD9A441),
                              ),
                              prefixIcon: const Icon(Icons.payments_rounded, size: 20),
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
                          const SizedBox(height: 14),

                          // Supplier & Receipt Number (Row in wide screen, Column in mobile)
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Supplier / Store',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF334155),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: supplierCtrl,
                                      style: GoogleFonts.plusJakartaSans(fontSize: 13),
                                      decoration: InputDecoration(
                                        hintText: 'e.g., Pagsanjan Public Market',
                                        prefixIcon: const Icon(Icons.storefront_rounded, size: 18),
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
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Receipt # / SI No.',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF334155),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: receiptNumberCtrl,
                                      style: GoogleFonts.plusJakartaSans(fontSize: 13),
                                      decoration: InputDecoration(
                                        hintText: 'e.g., OR-89421',
                                        prefixIcon: const Icon(Icons.receipt_rounded, size: 18),
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
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Receipt Photo Upload Dropzone
                          Text(
                            'Receipt Photo Attachment',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 6),
                          _buildReceiptUploadBox(
                            receiptImage: receiptImage,
                            onPickCamera: () async {
                              final picker = ImagePicker();
                              final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
                              if (file != null) {
                                setDialogState(() => receiptImage = file);
                              }
                            },
                            onPickGallery: () async {
                              final picker = ImagePicker();
                              final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                              if (file != null) {
                                setDialogState(() => receiptImage = file);
                              }
                            },
                            onRemoveImage: () => setDialogState(() => receiptImage = null),
                          ),
                          const SizedBox(height: 14),

                          // Notes
                          Text(
                            'Additional Notes',
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
                              hintText: 'Any special remarks or reason for emergency purchase...',
                              prefixIcon: const Icon(Icons.note_rounded, size: 18),
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
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 16),

                  // Bottom Action Buttons
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
                                if (descriptionCtrl.text.trim().isEmpty) {
                                  _showErrorSnackBar(context, 'Please enter an expense description');
                                  return;
                                }
                                if (amountCtrl.text.trim().isEmpty) {
                                  _showErrorSnackBar(context, 'Please enter the expense amount');
                                  return;
                                }
                                final amount = double.tryParse(amountCtrl.text.trim());
                                if (amount == null || amount <= 0) {
                                  _showErrorSnackBar(context, 'Please enter a valid amount greater than 0');
                                  return;
                                }
                                if (selectedCategory == 'inventory_purchase' &&
                                    selectedInventoryItems.isEmpty &&
                                    tempSelectedIds.isEmpty) {
                                  _showErrorSnackBar(context, 'Please select at least one inventory item');
                                  return;
                                }

                                setDialogState(() => isSaving = true);

                                // Add temp selected items
                                if (tempSelectedIds.isNotEmpty) {
                                  for (var id in tempSelectedIds) {
                                    final item = inventoryItems.firstWhere(
                                      (i) => i['id'].toString() == id,
                                      orElse: () => {'id': id, 'name': 'Item'},
                                    );
                                    selectedInventoryItems.add({
                                      'id': item['id'],
                                      'name': item['name'],
                                      'quantity': 1,
                                    });
                                  }
                                  tempSelectedIds.clear();
                                }

                                final user = Supabase.instance.client.auth.currentUser;
                                if (user == null) {
                                  setDialogState(() => isSaving = false);
                                  return;
                                }

                                // Upload receipt image if provided
                                if (receiptImage != null) {
                                  try {
                                    final fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
                                    final fileBytes = kIsWeb
                                        ? await (receiptImage as XFile).readAsBytes()
                                        : await (receiptImage as File).readAsBytes();

                                    await Supabase.instance.client.storage
                                        .from('petty_cash_receipts')
                                        .uploadBinary(fileName, fileBytes);

                                    receiptImageUrl = Supabase.instance.client.storage
                                        .from('petty_cash_receipts')
                                        .getPublicUrl(fileName);
                                  } catch (e) {
                                    debugPrint('Error uploading receipt image: $e');
                                  }
                                }

                                // Build inventory items list
                                List<InventoryExpenseItem>? inventoryExpenseItems;
                                String? legacyInventoryItemId;
                                String? legacyInventoryItemName;
                                int? legacyQuantityPurchased;

                                if (selectedInventoryItems.isNotEmpty) {
                                  inventoryExpenseItems = selectedInventoryItems.map((item) {
                                    return InventoryExpenseItem(
                                      itemId: item['id']?.toString() ?? '',
                                      itemName: item['name']?.toString() ?? 'Unknown',
                                      quantity: item['quantity'] as int? ?? 1,
                                    );
                                  }).toList();

                                  legacyInventoryItemId = selectedInventoryItems[0]['id']?.toString();
                                  legacyInventoryItemName = selectedInventoryItems[0]['name']?.toString();
                                  legacyQuantityPurchased = selectedInventoryItems[0]['quantity'] as int?;
                                }

                                final expense = PettyCashExpense(
                                  expenseDate: DateTime.now(),
                                  description: descriptionCtrl.text.trim(),
                                  amount: amount,
                                  category: selectedCategory!,
                                  purchasedBy: user.email!,
                                  inventoryItemId: legacyInventoryItemId,
                                  inventoryItemName: legacyInventoryItemName,
                                  quantityPurchased: legacyQuantityPurchased,
                                  inventoryItems: inventoryExpenseItems,
                                  supplier: supplierCtrl.text.trim().isEmpty ? null : supplierCtrl.text.trim(),
                                  receiptImageUrl: receiptImageUrl,
                                  receiptNumber: receiptNumberCtrl.text.trim().isEmpty ? null : receiptNumberCtrl.text.trim(),
                                  status: 'pending',
                                  notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                                  createdAt: DateTime.now(),
                                  updatedAt: DateTime.now(),
                                );

                                final success = await _pettyCashService.createExpense(expense);
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        success
                                            ? 'Expense recorded successfully and submitted for approval'
                                            : 'Failed to record expense',
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
                                'Save Expense',
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
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // INVENTORY MULTI-SELECT WIDGET
  // ---------------------------------------------------------------------------
  Widget _buildInventorySelectorBox({
    required List<Map<String, dynamic>> inventoryItems,
    required List<Map<String, dynamic>> selectedInventoryItems,
    required Set<String> tempSelectedIds,
    required TextEditingController itemSearchCtrl,
    required String itemSearchQuery,
    required StateSetter setDialogState,
    required ValueChanged<String> onSearchChanged,
  }) {
    final filtered = inventoryItems.where((item) {
      final name = (item['name'] ?? '').toString().toLowerCase();
      return name.contains(itemSearchQuery.toLowerCase().trim());
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + Search Input
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.inventory_2_rounded, size: 18, color: Color(0xFF14332E)),
                        const SizedBox(width: 6),
                        Text(
                          'Select Inventory Items',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    if (selectedInventoryItems.isNotEmpty || tempSelectedIds.isNotEmpty)
                      Text(
                        '${selectedInventoryItems.length + tempSelectedIds.length} selected',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: const Color(0xFF14332E),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: TextField(
                    controller: itemSearchCtrl,
                    onChanged: onSearchChanged,
                    style: GoogleFonts.plusJakartaSans(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Search items (e.g. Rice, Wonton, Oil)...',
                      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                      prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      suffixIcon: itemSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF94A3B8)),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: () {
                                itemSearchCtrl.clear();
                                setDialogState(() => itemSearchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Scrollable Inventory Checklist
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(Icons.search_off_rounded, color: Color(0xFF94A3B8), size: 24),
                  const SizedBox(height: 4),
                  Text(
                    inventoryItems.isEmpty ? 'Loading inventory items...' : 'No matching items found',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            )
          else
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  final itemIdStr = item['id'].toString();
                  final isTempSelected = tempSelectedIds.contains(itemIdStr);
                  final isAlreadyInList = selectedInventoryItems.any((sel) => sel['id'].toString() == itemIdStr);

                  return InkWell(
                    onTap: isAlreadyInList
                        ? null
                        : () {
                            setDialogState(() {
                              if (isTempSelected) {
                                tempSelectedIds.remove(itemIdStr);
                              } else {
                                tempSelectedIds.add(itemIdStr);
                              }
                            });
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isTempSelected
                            ? const Color(0xFF14332E).withValues(alpha: 0.08)
                            : isAlreadyInList
                                ? const Color(0xFFF1F5F9)
                                : Colors.transparent,
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: isAlreadyInList || isTempSelected,
                            activeColor: const Color(0xFF14332E),
                            onChanged: isAlreadyInList
                                ? null
                                : (val) {
                                    setDialogState(() {
                                      if (val == true) {
                                        tempSelectedIds.add(itemIdStr);
                                      } else {
                                        tempSelectedIds.remove(itemIdStr);
                                      }
                                    });
                                  },
                          ),
                          Expanded(
                            child: Text(
                              item['name'] ?? '',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: (isTempSelected || isAlreadyInList) ? FontWeight.w700 : FontWeight.w500,
                                color: isAlreadyInList ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (isAlreadyInList)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF15803D).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Added',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF15803D),
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

          // Add Selected Button if items are checked
          if (tempSelectedIds.isNotEmpty) ...[
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.all(10),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setDialogState(() {
                      for (var id in tempSelectedIds) {
                        final item = inventoryItems.firstWhere(
                          (i) => i['id'].toString() == id,
                          orElse: () => {'id': id, 'name': 'Item'},
                        );
                        selectedInventoryItems.add({
                          'id': item['id'],
                          'name': item['name'],
                          'quantity': 1,
                        });
                      }
                      tempSelectedIds.clear();
                    });
                  },
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text('Add ${tempSelectedIds.length} Selected Item${tempSelectedIds.length > 1 ? 's' : ''}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14332E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ],

          // Selected Items Chip List with Quantity Adjusters
          if (selectedInventoryItems.isNotEmpty) ...[
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Items (${selectedInventoryItems.length}):',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...selectedInventoryItems.map((selItem) {
                    final q = selItem['quantity'] as int? ?? 1;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              selItem['name'] ?? '',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          // Quantity Counter
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                InkWell(
                                  onTap: () {
                                    setDialogState(() {
                                      if (q > 1) {
                                        selItem['quantity'] = q - 1;
                                      }
                                    });
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.remove, size: 14),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: Text(
                                    '$q',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    setDialogState(() {
                                      selItem['quantity'] = q + 1;
                                    });
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.add, size: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                            onPressed: () {
                              setDialogState(() {
                                selectedInventoryItems.removeWhere((i) => i['id'] == selItem['id']);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RECEIPT ATTACHMENT BOX
  // ---------------------------------------------------------------------------
  Widget _buildReceiptUploadBox({
    required dynamic receiptImage,
    required VoidCallback onPickCamera,
    required VoidCallback onPickGallery,
    required VoidCallback onRemoveImage,
  }) {
    if (receiptImage != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF34C759)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFFE2E8F0),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: kIsWeb
                    ? Image.network((receiptImage as XFile).path, fit: BoxFit.cover)
                    : Image.file(receiptImage as File, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Receipt attached',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF15803D),
                    ),
                  ),
                  Text(
                    'Ready to upload upon saving',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Color(0xFFDC2626)),
              onPressed: onRemoveImage,
              tooltip: 'Remove',
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onPickCamera,
              icon: const Icon(Icons.camera_alt_rounded, size: 16),
              label: const Text('Take Photo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF14332E),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                textStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onPickGallery,
              icon: const Icon(Icons.photo_library_rounded, size: 16),
              label: const Text('Gallery'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF14332E),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                textStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EDIT EXPENSE DIALOG
  // ---------------------------------------------------------------------------
  void _editExpense(PettyCashExpense expense) {
    final descriptionCtrl = TextEditingController(text: expense.description);
    final amountCtrl = TextEditingController(text: expense.amount.toStringAsFixed(2));
    final supplierCtrl = TextEditingController(text: expense.supplier ?? '');
    final receiptNumberCtrl = TextEditingController(text: expense.receiptNumber ?? '');
    final notesCtrl = TextEditingController(text: expense.notes ?? '');

    String? selectedCategory = expense.category;
    List<Map<String, dynamic>> inventoryItems = [];
    List<Map<String, dynamic>> selectedInventoryItems = [];
    final itemSearchCtrl = TextEditingController();
    String itemSearchQuery = '';
    Set<String> tempSelectedIds = {};
    bool isSaving = false;

    // Load inventory items
    if (expense.category == 'inventory_purchase') {
      _loadInventoryItems().then((items) {
        inventoryItems = items;
        if (expense.inventoryItems != null && expense.inventoryItems!.isNotEmpty) {
          selectedInventoryItems = expense.inventoryItems!.map((item) {
            return {
              'id': item.itemId,
              'name': item.itemName,
              'quantity': item.quantity,
            };
          }).toList();
        } else if (expense.inventoryItemId != null) {
          selectedInventoryItems = [
            {
              'id': expense.inventoryItemId!,
              'name': expense.inventoryItemName ?? 'Unknown',
              'quantity': expense.quantityPurchased ?? 1,
            }
          ];
        }
      });
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isMobile = ResponsiveUtils.isMobile(context);

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              padding: EdgeInsets.all(isMobile ? 18 : 24),
              constraints: BoxConstraints(
                maxWidth: isMobile ? double.infinity : 560,
                maxHeight: MediaQuery.of(context).size.height * 0.88,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 30,
                    offset: Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
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
                          Icons.edit_outlined,
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
                              'Edit Expense Entry',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Update purchase details before approval',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: isSaving ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 16),

                  // Form Fields (Scrollable)
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Inventory items selector if inventory_purchase
                          if (selectedCategory == 'inventory_purchase') ...[
                            _buildInventorySelectorBox(
                              inventoryItems: inventoryItems,
                              selectedInventoryItems: selectedInventoryItems,
                              tempSelectedIds: tempSelectedIds,
                              itemSearchCtrl: itemSearchCtrl,
                              itemSearchQuery: itemSearchQuery,
                              setDialogState: setDialogState,
                              onSearchChanged: (val) => setDialogState(() => itemSearchQuery = val),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Description
                          Text(
                            'Description *',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: descriptionCtrl,
                            style: GoogleFonts.plusJakartaSans(fontSize: 13),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.description_rounded, size: 20),
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
                            maxLength: 200,
                          ),
                          const SizedBox(height: 10),

                          // Amount
                          Text(
                            'Total Amount (₱) *',
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
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF14332E),
                            ),
                            decoration: InputDecoration(
                              prefixText: '₱ ',
                              prefixStyle: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFD9A441),
                              ),
                              prefixIcon: const Icon(Icons.payments_rounded, size: 20),
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
                          const SizedBox(height: 14),

                          // Supplier & Receipt
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Supplier / Store',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF334155),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: supplierCtrl,
                                      style: GoogleFonts.plusJakartaSans(fontSize: 13),
                                      decoration: InputDecoration(
                                        prefixIcon: const Icon(Icons.storefront_rounded, size: 18),
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
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Receipt # / SI No.',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF334155),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: receiptNumberCtrl,
                                      style: GoogleFonts.plusJakartaSans(fontSize: 13),
                                      decoration: InputDecoration(
                                        prefixIcon: const Icon(Icons.receipt_rounded, size: 18),
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
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Notes
                          Text(
                            'Additional Notes',
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
                              prefixIcon: const Icon(Icons.note_rounded, size: 18),
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
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 16),

                  // Bottom Action Buttons
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
                                if (descriptionCtrl.text.trim().isEmpty) {
                                  _showErrorSnackBar(context, 'Please enter a description');
                                  return;
                                }
                                final amount = double.tryParse(amountCtrl.text.trim());
                                if (amount == null || amount <= 0) {
                                  _showErrorSnackBar(context, 'Please enter a valid amount');
                                  return;
                                }

                                setDialogState(() => isSaving = true);

                                // Add temp selected items
                                if (tempSelectedIds.isNotEmpty) {
                                  for (var id in tempSelectedIds) {
                                    final item = inventoryItems.firstWhere(
                                      (i) => i['id'].toString() == id,
                                      orElse: () => {'id': id, 'name': 'Item'},
                                    );
                                    selectedInventoryItems.add({
                                      'id': item['id'],
                                      'name': item['name'],
                                      'quantity': 1,
                                    });
                                  }
                                  tempSelectedIds.clear();
                                }

                                List<InventoryExpenseItem>? inventoryExpenseItems;
                                String? legacyInventoryItemId;
                                String? legacyInventoryItemName;
                                int? legacyQuantityPurchased;

                                if (selectedInventoryItems.isNotEmpty) {
                                  inventoryExpenseItems = selectedInventoryItems.map((item) {
                                    return InventoryExpenseItem(
                                      itemId: item['id']?.toString() ?? '',
                                      itemName: item['name']?.toString() ?? 'Unknown',
                                      quantity: item['quantity'] as int? ?? 1,
                                    );
                                  }).toList();

                                  legacyInventoryItemId = selectedInventoryItems[0]['id']?.toString();
                                  legacyInventoryItemName = selectedInventoryItems[0]['name']?.toString();
                                  legacyQuantityPurchased = selectedInventoryItems[0]['quantity'] as int?;
                                }

                                final updatedExpense = PettyCashExpense(
                                  id: expense.id,
                                  expenseDate: expense.expenseDate,
                                  description: descriptionCtrl.text.trim(),
                                  amount: amount,
                                  category: selectedCategory,
                                  purchasedBy: expense.purchasedBy,
                                  inventoryItemId: legacyInventoryItemId,
                                  inventoryItemName: legacyInventoryItemName,
                                  quantityPurchased: legacyQuantityPurchased,
                                  inventoryItems: inventoryExpenseItems,
                                  supplier: supplierCtrl.text.trim().isEmpty ? null : supplierCtrl.text.trim(),
                                  receiptNumber: receiptNumberCtrl.text.trim().isEmpty ? null : receiptNumberCtrl.text.trim(),
                                  receiptImageUrl: expense.receiptImageUrl,
                                  status: expense.status,
                                  approvedBy: expense.approvedBy,
                                  approvedAt: expense.approvedAt,
                                  notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                                  createdAt: expense.createdAt,
                                  updatedAt: DateTime.now(),
                                );

                                final success = await _pettyCashService.updateExpense(updatedExpense);
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        success ? 'Expense updated successfully' : 'Failed to update expense',
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
                                'Update Expense',
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
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DELETE CONFIRMATION
  // ---------------------------------------------------------------------------
  Future<void> _deleteExpense(String expenseId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Delete Expense Entry',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Are you sure you want to delete this pending expense? This action cannot be undone.',
          style: GoogleFonts.plusJakartaSans(color: const Color(0xFF475569), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _pettyCashService.deleteExpense(expenseId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Expense deleted successfully' : 'Failed to delete expense',
              style: GoogleFonts.plusJakartaSans(),
            ),
            backgroundColor: success ? const Color(0xFF15803D) : const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // HELPER METHODS
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> _loadInventoryItems() async {
    try {
      final response = await Supabase.instance.client
          .from('inventory')
          .select('id, name')
          .order('name');
      return response;
    } catch (e) {
      debugPrint('Error loading inventory items: $e');
      return [];
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.plusJakartaSans()),
        backgroundColor: const Color(0xFFDC2626),
      ),
    );
  }

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
    switch (category.toLowerCase()) {
      case 'inventory_purchase':
        return const Color(0xFFD97706); // Warm Amber
      case 'kitchen_supplies':
        return const Color(0xFF15803D); // Emerald Green
      case 'maintenance':
        return const Color(0xFF4F46E5); // Indigo
      case 'transportation':
        return const Color(0xFF0284C7); // Sky Blue
      case 'utilities':
        return const Color(0xFF7C3AED); // Purple
      default:
        return const Color(0xFF475569); // Slate Gray
    }
  }
}
