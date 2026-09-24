import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final ScrollController _tableHorizontalScrollController = ScrollController();
  final ScrollController _tableVerticalScrollController = ScrollController();

  String _searchQuery = '';
  String _selectedCategory = 'All';
  String? _selectedStatusFilter; // null means 'All Active', or 'pending', 'approved', 'reimbursed', 'rejected', 'archived'
  bool _isBannerCollapsed = false;
  bool _isTableView = false; // Toggle between Manage Inventory Cards and Table view
  String _selectedSort = 'newest'; // 'newest', 'oldest', 'highest', 'lowest'
  int _currentPage = 1;
  int _rowsPerPage = 25;
  bool _isChipsExpanded = false;

  static const List<String> categories = [
    'All',
    'Inventory Purchase',
    'Supplies',
    'Transportation',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tableHorizontalScrollController.dispose();
    _tableVerticalScrollController.dispose();
    super.dispose();
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase().trim()) {
      case 'all':
        return Icons.grid_view_rounded;
      case 'inventory purchase':
      case 'inventory_purchase':
        return Icons.inventory_2_rounded;
      case 'supplies':
      case 'kitchen_supplies':
        return Icons.soup_kitchen_rounded;
      case 'transportation':
        return Icons.local_shipping_rounded;
      case 'maintenance':
        return Icons.handyman_rounded;
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

  Color _getStatusColor(String status, {bool isAbono = false}) {
    final s = status.toLowerCase().trim();
    if (isAbono && s == 'approved') {
      return const Color(0xFFD97706); // Amber - For Reimbursement
    }
    switch (s) {
      case 'approved':
        return const Color(0xFF10B981); // Emerald
      case 'rejected':
        return const Color(0xFFEF4444); // Red
      case 'reimbursed':
        return const Color(0xFF0D9488); // Teal
      case 'pending':
      default:
        return const Color(0xFFF59E0B); // Amber
    }
  }

  IconData _getStatusIcon(String status, {bool isAbono = false}) {
    final s = status.toLowerCase().trim();
    if (isAbono && s == 'approved') {
      return Icons.hourglass_top_rounded;
    }
    switch (s) {
      case 'approved':
        return Icons.verified_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      case 'reimbursed':
        return Icons.payments_rounded;
      case 'pending':
      default:
        return Icons.warning_amber_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // ══════════════════════════════════════════════════════════════════════════
            // 1. TOP: REAL-TIME PETTY CASH TREASURY MONITOR BANNER (COLLAPSIBLE)
            // Matching Manage Inventory's Live Monitor Banner
            // ══════════════════════════════════════════════════════════════════════════
            _buildTreasuryMonitorBanner(isMobile),

            // ══════════════════════════════════════════════════════════════════════════
            // 2. SEARCH AND CATEGORY FILTER CARD
            // Matching Manage Inventory's Search & Horizontal Category Pills Bar
            // ══════════════════════════════════════════════════════════════════════════
            _buildSearchAndFilterCard(isMobile),

            if (_selectedStatusFilter != null || _selectedCategory != 'All' || _searchQuery.isNotEmpty)
              _buildActiveFilterStrip(isMobile),

            const SizedBox(height: 4),

            // ══════════════════════════════════════════════════════════════════════════
            // 3. EXPENSES STREAM VIEW (INVENTORY-STYLE CARDS GRID OR TABLE)
            // ══════════════════════════════════════════════════════════════════════════
            Expanded(
              child: StreamBuilder<List<PettyCashExpense>>(
                stream: _pettyCashService.streamExpenses(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF14332E),
                      ),
                    );
                  }

                  if (snapshot.hasError && !snapshot.hasData) {
                    return Center(
                      child: Text(
                        'Error loading expenses: ${snapshot.error}',
                        style: const TextStyle(color: AppTheme.errorRed),
                      ),
                    );
                  }

                  final user = Supabase.instance.client.auth.currentUser;
                  final allExpenses = snapshot.data ?? [];
                  final myExpenses = allExpenses.where((e) => e.purchasedBy == user?.email).toList();

                  // Filter by Search Query
                  var filtered = myExpenses.where((e) {
                    if (_searchQuery.isEmpty) return true;
                    final q = _searchQuery.toLowerCase();
                    final desc = e.description.toLowerCase();
                    final supp = (e.supplier ?? '').toLowerCase();
                    final rcpt = (e.receiptNumber ?? '').toLowerCase();
                    final cat = e.categoryDisplay.toLowerCase();
                    final items = (e.inventoryItems ?? []).map((i) => i.itemName.toLowerCase()).join(' ');
                    final legacyItem = (e.inventoryItemName ?? '').toLowerCase();

                    return desc.contains(q) ||
                        supp.contains(q) ||
                        rcpt.contains(q) ||
                        cat.contains(q) ||
                        items.contains(q) ||
                        legacyItem.contains(q);
                  }).toList();

                  // Filter by Category
                  if (_selectedCategory != 'All') {
                    filtered = filtered.where((e) {
                      final catDisplay = e.categoryDisplay.toLowerCase();
                      final sel = _selectedCategory.toLowerCase();
                      return catDisplay == sel ||
                          e.category.toLowerCase() == sel ||
                          e.category.toLowerCase() == sel.replaceAll(' ', '_');
                    }).toList();
                  }

                  // Filter by Status (from stat card selection)
                  if (_selectedStatusFilter != null) {
                    if (_selectedStatusFilter == 'archived' || _selectedStatusFilter == 'archive') {
                      filtered = filtered.where((e) => e.isArchived).toList();
                    } else {
                      filtered = filtered.where((e) {
                        return !e.isArchived && e.status.toLowerCase() == _selectedStatusFilter!.toLowerCase();
                      }).toList();
                    }
                  } else {
                    // Default active ledger view: show all active unarchived records
                    filtered = filtered.where((e) => !e.isArchived).toList();
                  }

                  // Sort: Ensure newly requested petty cash appears first
                  filtered.sort((a, b) {
                    if (_selectedSort == 'newest') {
                      // Primary: Submission time (createdAt) descending
                      // Guarantees newly requested petty cash ("now nag request") is ALWAYS at the top!
                      final createdComp = b.createdAt.compareTo(a.createdAt);
                      if (createdComp != 0) return createdComp;
                      // Secondary: expenseDate
                      return b.expenseDate.compareTo(a.expenseDate);
                    } else if (_selectedSort == 'newest_date') {
                      final expComp = b.expenseDate.compareTo(a.expenseDate);
                      if (expComp != 0) return expComp;
                      return b.createdAt.compareTo(a.createdAt);
                    } else if (_selectedSort == 'oldest') {
                      final createdComp = a.createdAt.compareTo(b.createdAt);
                      if (createdComp != 0) return createdComp;
                      return a.expenseDate.compareTo(b.expenseDate);
                    } else if (_selectedSort == 'highest') {
                      final amountComp = b.amount.compareTo(a.amount);
                      if (amountComp != 0) return amountComp;
                      return b.createdAt.compareTo(a.createdAt);
                    } else if (_selectedSort == 'lowest') {
                      final amountComp = a.amount.compareTo(b.amount);
                      if (amountComp != 0) return amountComp;
                      return b.createdAt.compareTo(a.createdAt);
                    }
                    return 0;
                  });

                  if (filtered.isEmpty) {
                    return _buildEmptyState(myExpenses.isEmpty);
                  }

                  if (_isTableView && !isMobile) {
                    return _buildTableView(filtered);
                  }

                  return _buildCardsGridView(filtered);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ── 1. COLLAPSIBLE REAL-TIME TREASURY MONITOR BANNER ──────────────────────
  // Identical gradient, typography, gold accents, and collapsible cards
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildTreasuryMonitorBanner(bool isMobile) {
    return GestureDetector(
      onTap: () => setState(() => _isBannerCollapsed = !_isBannerCollapsed),
      child: Container(
        margin: EdgeInsets.all(
          isMobile ? 12 : 16,
        ),
        padding: EdgeInsets.all(
          isMobile ? 12 : 16,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F2C27),
              Color(0xFF14332E),
              Color(0xFF1D4A41),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF28564D),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F2C27).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Banner Header (acts as collapse toggle)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6C374).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Color(0xFFE6C374),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live Petty Cash Treasury Monitor',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Real-time automated treasury balance, claims & disbursement overview',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFB0C8C3),
                          height: 1.15,
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                if (_selectedStatusFilter != null && !_isBannerCollapsed) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _selectedStatusFilter = null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.filter_alt_off_rounded, size: 14, color: Color(0xFFE6C374)),
                          SizedBox(width: 4),
                          Text(
                            'Reset Filter',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFFE6C374),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                // Collapse / expand chevron
                AnimatedRotation(
                  turns: _isBannerCollapsed ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 220),
                  child: const Icon(
                    Icons.expand_less_rounded,
                    color: Color(0xFFE6C374),
                    size: 22,
                  ),
                ),
              ],
            ),

            // Collapsible stats section
            AnimatedCrossFade(
              firstChild: Column(
                children: [
                  const SizedBox(height: 12),
                  StreamBuilder<PettyCashFund?>(
                    stream: _pettyCashService.streamPettyCashFund(),
                    builder: (context, fundSnap) {
                      return StreamBuilder<List<PettyCashExpense>>(
                        stream: _pettyCashService.streamExpenses(),
                        builder: (context, expSnap) {
                          final fund = fundSnap.data;
                          final allExpenses = expSnap.data ?? [];
                          final user = Supabase.instance.client.auth.currentUser;
                          final myExpenses = allExpenses.where((e) => e.purchasedBy == user?.email).toList();

                          final balance = fund?.currentBalance ?? 0.0;
                          final activeExpenses = myExpenses.where((e) => !e.isArchived).toList();
                          final archivedExpenses = myExpenses.where((e) => e.isArchived).toList();

                          final pendingExpenses = activeExpenses.where((e) => e.status == 'pending').toList();
                          final approvedExpenses = activeExpenses.where((e) => e.status == 'approved').toList();
                          final reimbursedExpenses = activeExpenses.where((e) => e.status == 'reimbursed').toList();
                          final rejectedExpenses = activeExpenses.where((e) => e.status == 'rejected').toList();

                          final pendingCount = pendingExpenses.length;
                          final approvedCount = approvedExpenses.length;
                          final reimbursedCount = reimbursedExpenses.length;
                          final rejectedCount = rejectedExpenses.length;
                          final archivedCount = archivedExpenses.length;

                          if (isMobile) {
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    _buildRealisticStatCard(
                                      label: 'AVAILABLE FUND',
                                      count: '₱${NumberFormat('#,##0').format(balance)}',
                                      statusKey: null,
                                      accentColor: const Color(0xFF10B981),
                                      icon: Icons.account_balance_wallet_rounded,
                                      subtitle: fund?.isLowBalance == true ? 'Refill required' : 'Ready for cash',
                                      isCurrency: true,
                                    ),
                                    const SizedBox(width: 8),
                                    _buildRealisticStatCard(
                                      label: 'PENDING CLAIMS',
                                      count: pendingCount.toString(),
                                      statusKey: 'pending',
                                      accentColor: const Color(0xFFF59E0B),
                                      icon: Icons.warning_amber_rounded,
                                      subtitle: 'Awaiting review',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _buildRealisticStatCard(
                                      label: 'APPROVED',
                                      count: approvedCount.toString(),
                                      statusKey: 'approved',
                                      accentColor: const Color(0xFF3B82F6),
                                      icon: Icons.check_circle_rounded,
                                      subtitle: 'Verified claims',
                                    ),
                                    const SizedBox(width: 8),
                                    _buildRealisticStatCard(
                                      label: 'REIMBURSED',
                                      count: reimbursedCount.toString(),
                                      statusKey: 'reimbursed',
                                      accentColor: const Color(0xFF0D9488),
                                      icon: Icons.verified_rounded,
                                      subtitle: 'Settled payout',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _buildRealisticStatCard(
                                      label: 'REJECTED',
                                      count: rejectedCount.toString(),
                                      statusKey: 'rejected',
                                      accentColor: const Color(0xFFEF4444),
                                      icon: Icons.cancel_outlined,
                                      subtitle: 'Declined claims',
                                    ),
                                    const SizedBox(width: 8),
                                    _buildRealisticStatCard(
                                      label: 'ARCHIVED',
                                      count: archivedCount.toString(),
                                      statusKey: 'archived',
                                      accentColor: const Color(0xFF64748B),
                                      icon: Icons.archive_outlined,
                                      subtitle: 'Archived records',
                                    ),
                                  ],
                                ),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              _buildRealisticStatCard(
                                label: 'AVAILABLE FUND',
                                count: '₱${NumberFormat('#,##0.00').format(balance)}',
                                statusKey: null,
                                accentColor: const Color(0xFF10B981),
                                icon: Icons.account_balance_wallet_rounded,
                                subtitle: fund?.isLowBalance == true ? '⚠️ Refill required' : '🟢 Ready for cash',
                                isCurrency: true,
                              ),
                              const SizedBox(width: 8),
                              _buildRealisticStatCard(
                                label: 'PENDING REVIEW',
                                count: pendingCount.toString(),
                                statusKey: 'pending',
                                accentColor: const Color(0xFFF59E0B),
                                icon: Icons.warning_amber_rounded,
                                subtitle: 'Waiting approval',
                              ),
                              const SizedBox(width: 8),
                              _buildRealisticStatCard(
                                label: 'APPROVED CLAIMS',
                                count: approvedCount.toString(),
                                statusKey: 'approved',
                                accentColor: const Color(0xFF3B82F6),
                                icon: Icons.check_circle_rounded,
                                subtitle: 'Ready for release',
                              ),
                              const SizedBox(width: 8),
                              _buildRealisticStatCard(
                                label: 'REIMBURSED',
                                count: reimbursedCount.toString(),
                                statusKey: 'reimbursed',
                                accentColor: const Color(0xFF0D9488),
                                icon: Icons.verified_rounded,
                                subtitle: 'Settled records',
                              ),
                              const SizedBox(width: 8),
                              _buildRealisticStatCard(
                                label: 'REJECTED CLAIMS',
                                count: rejectedCount.toString(),
                                statusKey: 'rejected',
                                accentColor: const Color(0xFFEF4444),
                                icon: Icons.cancel_outlined,
                                subtitle: 'Declined claims',
                              ),
                              const SizedBox(width: 8),
                              _buildRealisticStatCard(
                                label: 'ARCHIVED',
                                count: archivedCount.toString(),
                                statusKey: 'archived',
                                accentColor: const Color(0xFF64748B),
                                icon: Icons.archive_outlined,
                                subtitle: 'Archived records',
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
              secondChild: const SizedBox.shrink(),
              crossFadeState: _isBannerCollapsed
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 220),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealisticStatCard({
    required String label,
    required String count,
    required String? statusKey,
    required Color accentColor,
    required IconData icon,
    required String subtitle,
    bool isCurrency = false,
  }) {
    final isSelected = statusKey != null && _selectedStatusFilter == statusKey;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: statusKey == null
              ? null
              : () {
                  setState(() {
                    if (_selectedStatusFilter == statusKey) {
                      _selectedStatusFilter = null;
                    } else {
                      _selectedStatusFilter = statusKey;
                      if (statusKey == 'pending') {
                        _selectedSort = 'newest';
                      }
                    }
                  });
                },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveUtils.isMobile(context) ? 8 : 10,
              vertical: ResponsiveUtils.isMobile(context) ? 6 : 8,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isSelected
                    ? [
                        accentColor.withValues(alpha: 0.28),
                        accentColor.withValues(alpha: 0.12),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.08),
                        Colors.white.withValues(alpha: 0.03),
                      ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? accentColor
                    : Colors.white.withValues(alpha: 0.12),
                width: isSelected ? 1.8 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(ResponsiveUtils.isMobile(context) ? 6 : 8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: isSelected ? 0.25 : 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Icon(icon, color: accentColor, size: ResponsiveUtils.isMobile(context) ? 14 : 18),
                ),
                SizedBox(width: ResponsiveUtils.isMobile(context) ? 8 : 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              count,
                              style: TextStyle(
                                fontSize: isCurrency
                                    ? (ResponsiveUtils.isMobile(context) ? 12 : 14)
                                    : (ResponsiveUtils.isMobile(context) ? 15 : 18),
                                fontWeight: FontWeight.w900,
                                color: isCurrency ? const Color(0xFFE6C374) : Colors.white,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: accentColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'ACTIVE',
                                style: TextStyle(
                                  fontSize: ResponsiveUtils.isMobile(context) ? 7 : 8,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: ResponsiveUtils.isMobile(context) ? 9.5 : 10,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : const Color(0xFFC7D6D3),
                          letterSpacing: 0.2,
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
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ── 2. SEARCH AND CATEGORY FILTER CARD ────────────────────────────────────
  // Identical container styling, search bar, and horizontal category pills
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSearchAndFilterCard(bool isMobile) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Row + Actions
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: 'Search expenses by description, supplier, item, or receipt #...',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF14332E),
                      size: 20,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: Color(0xFF94A3B8), size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                ),
              ),

              // View Toggle Button (Cards vs Table) & Actions Menu
              const SizedBox(width: 8),
              if (!isMobile) ...[
                // View Mode Toggle Button
                InkWell(
                  onTap: () => setState(() => _isTableView = !_isTableView),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _isTableView ? const Color(0xFF14332E) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isTableView ? Icons.grid_view_rounded : Icons.table_chart_rounded,
                          size: 16,
                          color: _isTableView ? const Color(0xFFE6C374) : const Color(0xFF475569),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isTableView ? 'Card View' : 'Table View',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _isTableView ? const Color(0xFFE6C374) : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Actions dropdown menu (matching Manage Inventory Actions button)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'newest' || value == 'newest_date' || value == 'oldest' || value == 'highest' || value == 'lowest') {
                    setState(() => _selectedSort = value);
                  } else if (value == 'add') {
                    _showAddExpenseDialog();
                  } else if (value == 'filter_rejected') {
                    setState(() {
                      _selectedStatusFilter = 'rejected';
                      _currentPage = 1;
                    });
                  } else if (value == 'filter_archive') {
                    setState(() {
                      _selectedStatusFilter = 'archived';
                      _currentPage = 1;
                    });
                  } else if (value == 'reset') {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                      _selectedCategory = 'All';
                      _selectedStatusFilter = null;
                      _selectedSort = 'newest';
                    });
                  }
                },
                offset: const Offset(0, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: Colors.white,
                elevation: 8,
                itemBuilder: (context) => [
                  const PopupMenuItem<String>(
                    value: 'add',
                    child: Row(children: [
                      Icon(Icons.add_rounded, size: 16, color: Color(0xFF14332E)),
                      SizedBox(width: 10),
                      Text('Record New Expense', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                    ]),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem<String>(
                    value: 'filter_rejected',
                    child: Row(children: [
                      Icon(Icons.cancel_outlined, size: 16, color: Color(0xFFEF4444)),
                      SizedBox(width: 10),
                      Text('Filter: Rejected Claims', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
                    ]),
                  ),
                  const PopupMenuItem<String>(
                    value: 'filter_archive',
                    child: Row(children: [
                      Icon(Icons.archive_outlined, size: 16, color: Color(0xFF64748B)),
                      SizedBox(width: 10),
                      Text('Filter: Archived Records', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                    ]),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem<String>(
                    value: 'newest',
                    child: Row(children: [
                      Icon(Icons.schedule_rounded, size: 16, color: Color(0xFF14332E)),
                      SizedBox(width: 10),
                      Text('Sort: Newest Request First', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  const PopupMenuItem<String>(
                    value: 'newest_date',
                    child: Row(children: [
                      Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF64748B)),
                      SizedBox(width: 10),
                      Text('Sort: Expense Date', style: TextStyle(fontSize: 13)),
                    ]),
                  ),
                  const PopupMenuItem<String>(
                    value: 'highest',
                    child: Row(children: [
                      Icon(Icons.trending_up_rounded, size: 16, color: Color(0xFF64748B)),
                      SizedBox(width: 10),
                      Text('Sort: Amount (High to Low)', style: TextStyle(fontSize: 13)),
                    ]),
                  ),
                  const PopupMenuItem<String>(
                    value: 'lowest',
                    child: Row(children: [
                      Icon(Icons.trending_down_rounded, size: 16, color: Color(0xFF64748B)),
                      SizedBox(width: 10),
                      Text('Sort: Amount (Low to High)', style: TextStyle(fontSize: 13)),
                    ]),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem<String>(
                    value: 'reset',
                    child: Row(children: [
                      Icon(Icons.filter_alt_off_rounded, size: 16, color: Color(0xFFDC2626)),
                      SizedBox(width: 10),
                      Text('Reset All Filters', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                    ]),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14332E),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded, size: 16, color: Color(0xFFE6C374)),
                      SizedBox(width: 6),
                      Text('Actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFE6C374))),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down_rounded, size: 18, color: Color(0xFFE6C374)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Horizontal Category Pills (1:1 with Manage Inventory)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: categories.map((category) {
                final isSelected = _selectedCategory == category;
                final catColor = _getCategoryColor(category);
                final catIcon = _getCategoryIcon(category);

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedCategory = category;
                        _currentPage = 1;
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF14332E)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF14332E)
                              : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF14332E).withValues(alpha: 0.25),
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
                            catIcon,
                            size: 14,
                            color: isSelected
                                ? const Color(0xFFE6C374)
                                : catColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            category,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilterStrip(bool isMobile) {
    final isPending = _selectedStatusFilter == 'pending';
    final isRejected = _selectedStatusFilter == 'rejected';
    final isArchive = _selectedStatusFilter == 'archive';
    final statusLabel = _selectedStatusFilter != null
        ? (_selectedStatusFilter == 'pending'
            ? 'Pending Review'
            : _selectedStatusFilter == 'approved'
                ? 'Approved Claims'
                : _selectedStatusFilter == 'rejected'
                    ? 'Rejected Claims'
                    : _selectedStatusFilter == 'archive'
                        ? 'Archived Records (>30 Days)'
                        : 'Reimbursed / Settled')
        : null;

    final bgColor = isPending
        ? const Color(0xFFFEF3C7)
        : isRejected
            ? const Color(0xFFFEE2E2)
            : const Color(0xFFF1F5F9);
    final borderColor = isPending
        ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
        : isRejected
            ? const Color(0xFFEF4444).withValues(alpha: 0.5)
            : const Color(0xFFCBD5E1);
    final iconColor = isPending
        ? const Color(0xFFB45309)
        : isRejected
            ? const Color(0xFFDC2626)
            : const Color(0xFF475569);
    final textColor = isPending
        ? const Color(0xFF92400E)
        : isRejected
            ? const Color(0xFF991B1B)
            : const Color(0xFF334155);
    final iconData = isPending
        ? Icons.pending_actions_rounded
        : isRejected
            ? Icons.cancel_outlined
            : isArchive
                ? Icons.archive_outlined
                : Icons.filter_alt_rounded;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: 4,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(
            iconData,
            size: 15,
            color: iconColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isPending
                  ? 'Showing Pending Review Claims (Ordered by newest requests first)'
                  : isRejected
                      ? 'Showing Rejected Claims (Review admin notes & reasons below)'
                      : isArchive
                          ? 'Showing Archived Records (Restore or inspect past records)'
                          : 'Active Filter: ${[if (statusLabel != null) statusLabel, if (_selectedCategory != 'All') _selectedCategory, if (_searchQuery.isNotEmpty) '"$_searchQuery"'].join(' • ')}',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: () {
              setState(() {
                _selectedStatusFilter = null;
                _selectedCategory = 'All';
                _searchQuery = '';
                _searchController.clear();
                _selectedSort = 'newest';
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.close_rounded, size: 12, color: Color(0xFF64748B)),
                  SizedBox(width: 3),
                  Text(
                    'Reset',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ── 3. CARDS GRID VIEW (MATCHING MANAGE INVENTORY ITEM CARDS 1:1) ─────────
  // Includes 38px Dark Enterprise Green Header, Status Badge, Identity,
  // Hero Gold Amount Badge, and Location/Action Footer Bar
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildCardsGridView(List<PettyCashExpense> filteredExpenses) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 3;
        if (constraints.maxWidth < 640) {
          crossAxisCount = 1;
        } else if (constraints.maxWidth < 1050) {
          crossAxisCount = 2;
        } else if (constraints.maxWidth < 1500) {
          crossAxisCount = 3;
        } else {
          crossAxisCount = 4;
        }

        const double spacing = 16.0;
        final double horizontalPadding = ResponsiveUtils.isMobile(context) ? 24.0 : 32.0;
        final double availableWidth = constraints.maxWidth - horizontalPadding;
        final double totalSpacing = spacing * (crossAxisCount - 1);
        final double cardWidth = (availableWidth - totalSpacing) / crossAxisCount;
        final double targetHeight = crossAxisCount == 1 ? 200.0 : 208.0;
        final double childAspectRatio = cardWidth / targetHeight;

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveUtils.isMobile(context) ? 12 : 16,
            vertical: 10,
          ),
          child: GridView.builder(
            physics: const BouncingScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              childAspectRatio: childAspectRatio,
            ),
            itemCount: filteredExpenses.length,
            itemBuilder: (context, index) {
              return _buildManageInventoryStyleCard(filteredExpenses[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildManageInventoryStyleCard(PettyCashExpense expense) {
    final status = expense.status.toLowerCase();
    final statusColor = _getStatusColor(status, isAbono: expense.isAbono);
    final statusIcon = _getStatusIcon(status, isAbono: expense.isAbono);
    final category = expense.categoryDisplay;
    final categoryColor = _getCategoryColor(category);
    final categoryIcon = _getCategoryIcon(category);
    final supplier = expense.supplier;
    final receiptNum = expense.receiptNumber;
    final isPending = status == 'pending';
    final now = DateTime.now();
    final isToday = expense.createdAt.year == now.year &&
        expense.createdAt.month == now.month &&
        expense.createdAt.day == now.day;
    final isRecent = isToday || now.difference(expense.createdAt).inHours < 24;

    // Header Background: Dark Enterprise Green, exactly matching Manage Inventory
    const Color headerBg = Color(0xFF14332E);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: () => _showExpenseDetailsModal(expense),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── KDS DOCKET HEADER BAR (38px high, Dark Enterprise Green) ──
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: const BoxDecoration(
                  color: headerBg,
                ),
                child: Row(
                  children: [
                    // Category Badge with icon (flexible and truncates gracefully)
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
                                style: TextStyle(
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
                    const SizedBox(width: 4),
                    const Spacer(),
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
                      const SizedBox(width: 4),
                    ],
                    // Freshness / New Request Badge
                    if (isPending && isRecent) ...[
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
                      const SizedBox(width: 4),
                    ],
                    // Status Badge with icon
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: statusColor.withValues(alpha: 0.55), width: 0.9),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            statusIcon,
                            size: 9,
                            color: statusColor,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            expense.statusDisplay.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Action dropdown menu
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 14,
                      iconSize: 16,
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        size: 16,
                        color: Colors.white70,
                      ),
                      onSelected: (value) {
                        if (value == 'inspect') {
                          _showExpenseDetailsModal(expense);
                        } else if (value == 'edit') {
                          _editExpense(expense);
                        } else if (value == 'archive') {
                          _toggleArchiveExpense(expense);
                        } else if (value == 'delete') {
                          _deleteExpense(expense.id!);
                        } else if (value == 'receipt' && expense.receiptImageUrl != null) {
                          _showReceiptLightbox(expense.receiptImageUrl!);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'inspect',
                          child: Row(
                            children: [
                              Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF14332E)),
                              SizedBox(width: 8),
                              Text('Inspect Claim', style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                        if (expense.receiptImageUrl != null)
                          const PopupMenuItem(
                            value: 'receipt',
                            child: Row(
                              children: [
                                Icon(Icons.receipt_rounded, size: 16, color: Color(0xFF0D9488)),
                                SizedBox(width: 8),
                                Text('View Receipt', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        if (expense.isArchived)
                          const PopupMenuItem(
                            value: 'archive',
                            child: Row(
                              children: [
                                Icon(Icons.unarchive_rounded, size: 16, color: Color(0xFF14332E)),
                                SizedBox(width: 8),
                                Text('Restore from Archive', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          )
                        else if (status == 'approved' || status == 'reimbursed')
                          const PopupMenuItem(
                            value: 'archive',
                            child: Row(
                              children: [
                                Icon(Icons.archive_outlined, size: 16, color: Color(0xFF64748B)),
                                SizedBox(width: 8),
                                Text('Move to Archive', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        if (isPending) ...[
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_rounded, size: 16, color: Color(0xFF14332E)),
                                SizedBox(width: 8),
                                Text('Edit Claim', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.errorRed),
                                SizedBox(width: 8),
                                Text('Delete Claim', style: TextStyle(fontSize: 13, color: AppTheme.errorRed)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // ── COMFORTABLE BODY (SPACIOUS, GENEROUS BREATHING ROOM) ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Row 1: Item Identity + Hero Amount Badge (Matching Manage Inventory KDS Badge)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7.5),
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: categoryColor.withValues(alpha: 0.3)),
                            ),
                            child: Icon(categoryIcon, size: 17, color: categoryColor),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  expense.description,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13.5,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    if (supplier != null && supplier.isNotEmpty) ...[
                                      Flexible(
                                        child: Text(
                                          'Vendor: $supplier',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      const Text('•', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                                      const SizedBox(width: 5),
                                    ],
                                    Flexible(
                                      child: Text(
                                        isToday
                                            ? 'Today, ${DateFormat('h:mm a').format(expense.createdAt)}'
                                            : DateFormat('MMM d, yyyy').format(expense.createdAt),
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: isToday ? const Color(0xFF0D9488) : const Color(0xFF64748B),
                                          fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
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

                          // Hero Amount Badge (Dark green box with gold figure)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF14332E),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF14332E).withValues(alpha: 0.2),
                                  blurRadius: 5,
                                  offset: const Offset(0, 1.5),
                                ),
                              ],
                            ),
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  const TextSpan(
                                    text: '₱ ',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFE6C374),
                                    ),
                                  ),
                                  TextSpan(
                                    text: NumberFormat('#,##0.00').format(expense.amount),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFFE6C374),
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Row 2: Linked Items Pill / Details Snippet
                      if (expense.isMultiItemExpense && expense.inventoryItems != null && expense.inventoryItems!.isNotEmpty) ...[
                        Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          children: expense.inventoryItems!.take(3).map((item) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.inventory_2_rounded, size: 10, color: Color(0xFF64748B)),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${item.itemName} ×${item.quantity}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ] else if (expense.inventoryItemName != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.inventory_2_rounded, size: 11, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(
                                '${expense.inventoryItemName!} ×${expense.quantityPurchased ?? 1}',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Text(
                          expense.notes?.isNotEmpty == true
                              ? 'Note: ${expense.notes!}'
                              : 'Disbursed by ${expense.purchasedBy.split('@').first}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      // Row 3: Footer Bar Container (Location / Receipt Info with Quick Edit)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              receiptNum?.isNotEmpty == true ? Icons.receipt_outlined : Icons.calendar_today_outlined,
                              size: 12,
                              color: const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                expense.isNonOr
                                    ? '🏷️ Non-OR #${expense.receiptNumber ?? 'FARE'} • Date: ${DateFormat('MMM d').format(expense.expenseDate)}'
                                    : (receiptNum?.isNotEmpty == true
                                        ? 'Receipt #$receiptNum • Date: ${DateFormat('MMM d, yyyy').format(expense.expenseDate)}'
                                        : 'Expense Date: ${DateFormat('EEE, MMM d, yyyy').format(expense.expenseDate)}'),
                                style: TextStyle(
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
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.photo_rounded, size: 10, color: Color(0xFF0D9488)),
                                      SizedBox(width: 3),
                                      Text(
                                        'PHOTO',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0D9488),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (isPending) ...[
                              InkWell(
                                onTap: () => _editExpense(expense),
                                borderRadius: BorderRadius.circular(5),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF14332E).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.edit_rounded, size: 10, color: Color(0xFF14332E)),
                                      SizedBox(width: 3),
                                      Text(
                                        'EDIT',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF14332E),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ] else if (expense.isArchived) ...[
                              InkWell(
                                onTap: () => _toggleArchiveExpense(expense),
                                borderRadius: BorderRadius.circular(5),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF14332E).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: const Color(0xFF14332E).withValues(alpha: 0.2)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.unarchive_rounded, size: 10, color: Color(0xFF14332E)),
                                      SizedBox(width: 3),
                                      Text(
                                        'RESTORE',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF14332E),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ] else if (status == 'approved' || status == 'reimbursed') ...[
                              InkWell(
                                onTap: () => _toggleArchiveExpense(expense),
                                borderRadius: BorderRadius.circular(5),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF64748B).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.archive_outlined, size: 10, color: Color(0xFF475569)),
                                      SizedBox(width: 3),
                                      Text(
                                        'ARCHIVE',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF475569),
                                        ),
                                      ),
                                    ],
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ══════════════════════════════════════════════════════════════════════════
  // ── TABLE VIEW (ENTERPRISE FINANCIAL LEDGER DATA GRID) ────────────────────
  // Crystal clear column headers, structured row data, formatted empty states,
  // zebra hovering, and dedicated pagination footer bar.
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildTableView(List<PettyCashExpense> expenses) {
    if (expenses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(
                  Icons.table_chart_outlined,
                  size: 36,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'No Expense Records Listed',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Try adjusting your search criteria, category pill, or active status filter.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    final totalItems = expenses.length;
    final totalPages = (totalItems / _rowsPerPage).ceil().clamp(1, 999999);
    if (_currentPage > totalPages && totalPages > 0) _currentPage = totalPages;
    if (_currentPage < 1) _currentPage = 1;

    final startIndex = (_currentPage - 1) * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage < totalItems) ? startIndex + _rowsPerPage : totalItems;
    final paginated = expenses.sublist(
      startIndex < totalItems ? startIndex : 0,
      endIndex <= totalItems ? endIndex : totalItems,
    );
    final totalSum = expenses.fold<double>(0.0, (s, e) => s + e.amount);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── 1. TABLE SUMMARY TOP BAR ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$totalItems Record${totalItems == 1 ? '' : 's'} Listed',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        'Page $_currentPage of $totalPages',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14332E),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF14332E).withValues(alpha: 0.18),
                        blurRadius: 5,
                        offset: const Offset(0, 1.5),
                      ),
                    ],
                  ),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: 'Total: ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFB0C8C3),
                          ),
                        ),
                        TextSpan(
                          text: '₱${NumberFormat('#,##0.00').format(totalSum)}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFE6C374),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── 2. SCROLLABLE LEDGER WITH COLUMN HEADERS ──
          Expanded(
            child: Scrollbar(
              controller: _tableHorizontalScrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _tableHorizontalScrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: SizedBox(
                  width: 1260,
                  child: Column(
                    children: [
                      // ── STICKY COLUMN HEADERS ROW ──
                      Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1.1),
                          ),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(
                              width: 140,
                              child: Text(
                                'EXPENSE DATE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF334155),
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 150,
                              child: Text(
                                'CATEGORY',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF334155),
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 260,
                              child: Text(
                                'PARTICULARS / ITEM',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF334155),
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 160,
                              child: Text(
                                'MERCHANT / STORE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF334155),
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 140,
                              child: Text(
                                'OR / RECEIPT #',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF334155),
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 130,
                              child: Text(
                                'AMOUNT',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF334155),
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 140,
                              child: Text(
                                'STATUS',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF334155),
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 90,
                              child: Text(
                                'ACTIONS',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF334155),
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── LEDGER DATA ROWS ──
                      Expanded(
                        child: ListView.separated(
                          controller: _tableVerticalScrollController,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 70),
                          itemCount: paginated.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, index) {
                            final item = paginated[index];
                            final status = item.status.toLowerCase().trim();
                            final statusColor = _getStatusColor(status, isAbono: item.isAbono);
                            final statusIcon = _getStatusIcon(status, isAbono: item.isAbono);
                            final categoryColor = _getCategoryColor(item.categoryDisplay);
                            final categoryIcon = _getCategoryIcon(item.categoryDisplay);
                            final now = DateTime.now();
                            final isItemToday = item.createdAt.year == now.year &&
                                item.createdAt.month == now.month &&
                                item.createdAt.day == now.day;
                            final isItemRecent = isItemToday || now.difference(item.createdAt).inHours < 24;

                            // Status title and styling
                            String statusTitle;
                            Color statusBg;
                            Color statusText;
                            switch (status) {
                              case 'reimbursed':
                                statusTitle = item.isAbono ? 'REIMBURSED TO STAFF' : 'REIMBURSED';
                                statusBg = const Color(0xFFF0FDFA);
                                statusText = const Color(0xFF0F766E);
                                break;
                              case 'approved':
                                statusTitle = item.isAbono ? 'WAITING CASH' : 'APPROVED';
                                statusBg = const Color(0xFFECFDF5);
                                statusText = const Color(0xFF047857);
                                break;
                              case 'rejected':
                                statusTitle = 'REJECTED';
                                statusBg = const Color(0xFFFEF2F2);
                                statusText = const Color(0xFFB91C1C);
                                break;
                              case 'pending':
                              default:
                                statusTitle = 'PENDING REVIEW';
                                statusBg = const Color(0xFFFFFBEB);
                                statusText = const Color(0xFFB45309);
                                break;
                            }

                            final hasSupplier = item.supplier != null && item.supplier!.trim().isNotEmpty;
                            final hasReceipt = item.receiptNumber != null && item.receiptNumber!.trim().isNotEmpty;

                            return Material(
                              color: index % 2 == 0 ? Colors.white : const Color(0xFFFAFBFD),
                              child: InkWell(
                                onTap: () => _showExpenseDetailsModal(item),
                                hoverColor: const Color(0xFFF1F5F9),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  child: Row(
                                    children: [
                                      // 1. Expense Date
                                      SizedBox(
                                        width: 140,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  DateFormat('MMM d, yyyy').format(item.expenseDate),
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                                                ),
                                                if (status == 'pending' && isItemRecent) ...[
                                                  const SizedBox(width: 4),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFE6C374).withValues(alpha: 0.25),
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: const Color(0xFFE6C374), width: 0.8),
                                                    ),
                                                    child: const Text(
                                                      'NEW',
                                                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFFB45309)),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.schedule_rounded,
                                                  size: 11,
                                                  color: isItemToday ? const Color(0xFF0D9488) : const Color(0xFF94A3B8),
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  isItemToday
                                                      ? 'Req: Today, ${DateFormat('h:mm a').format(item.createdAt)}'
                                                      : 'Req: ${DateFormat('MMM d, h:mm a').format(item.createdAt)}',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: isItemToday ? const Color(0xFF0D9488) : const Color(0xFF94A3B8),
                                                    fontWeight: isItemToday ? FontWeight.w700 : FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      // 2. Category
                                      SizedBox(
                                        width: 150,
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                                              decoration: BoxDecoration(
                                                color: categoryColor.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: categoryColor.withValues(alpha: 0.25), width: 0.8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(categoryIcon, size: 11.5, color: categoryColor),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    item.categoryDisplay,
                                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: categoryColor),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // 3. Particulars / Description
                                      SizedBox(
                                        width: 260,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              item.description,
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                            if (item.isMultiItemExpense && item.inventoryItems != null && item.inventoryItems!.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                '📦 ${item.inventoryItems!.length} item(s): ${item.inventoryItems!.first.itemName}',
                                                style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ] else if (item.inventoryItemName != null) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                'Item: ${item.inventoryItemName!} ×${item.quantityPurchased ?? 1}',
                                                style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ] else if (item.notes?.isNotEmpty == true) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                'Note: ${item.notes!}',
                                                style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),

                                      // 4. Merchant / Store
                                      SizedBox(
                                        width: 160,
                                        child: hasSupplier
                                            ? Row(
                                                children: [
                                                  const Icon(Icons.storefront_outlined, size: 13, color: Color(0xFF64748B)),
                                                  const SizedBox(width: 5),
                                                  Expanded(
                                                    child: Text(
                                                      item.supplier!,
                                                      style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w600),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : const Row(
                                                children: [
                                                  Icon(Icons.storefront_outlined, size: 12, color: Color(0xFFCBD5E1)),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Direct Purchase',
                                                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                                                  ),
                                                ],
                                              ),
                                      ),

                                      // 5. OR / Receipt #
                                      SizedBox(
                                        width: 140,
                                        child: hasReceipt
                                            ? Row(
                                                children: [
                                                  Flexible(
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFF1F5F9),
                                                        borderRadius: BorderRadius.circular(4),
                                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                                      ),
                                                      child: Text(
                                                        item.isNonOr ? '🏷️ Non-OR #${item.receiptNumber}' : '#${item.receiptNumber}',
                                                        style: TextStyle(
                                                          fontSize: 10.5,
                                                          color: item.isNonOr ? const Color(0xFF0F766E) : const Color(0xFF334155),
                                                          fontWeight: FontWeight.w700,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ),
                                                  if (item.receiptImageUrl != null) ...[
                                                    const SizedBox(width: 4),
                                                    InkWell(
                                                      onTap: () => _showReceiptLightbox(item.receiptImageUrl!),
                                                      child: const Icon(Icons.photo_library_outlined, size: 13, color: Color(0xFF0D9488)),
                                                    ),
                                                  ],
                                                ],
                                              )
                                            : const Text(
                                                'No Receipt #',
                                                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                                              ),
                                      ),

                                      // 6. Amount
                                      SizedBox(
                                        width: 130,
                                        child: Text(
                                          '₱${NumberFormat('#,##0.00').format(item.amount)}',
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF0F172A),
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                      ),

                                      // 7. Status
                                      SizedBox(
                                        width: 140,
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: statusBg,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: statusColor.withValues(alpha: 0.35), width: 0.9),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(statusIcon, size: 10.5, color: statusText),
                                                const SizedBox(width: 3.5),
                                                Flexible(
                                                  child: Text(
                                                    statusTitle,
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w800,
                                                      color: statusText,
                                                      letterSpacing: 0.2,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),

                                      // 8. Actions
                                      SizedBox(
                                        width: 100,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            // Inspect Details
                                            IconButton(
                                              icon: const Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF14332E)),
                                              tooltip: 'Inspect Claim',
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              onPressed: () => _showExpenseDetailsModal(item),
                                            ),
                                            const SizedBox(width: 8),
                                            // Edit if pending
                                            if (status == 'pending') ...[
                                              IconButton(
                                                icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF14332E)),
                                                tooltip: 'Edit Claim',
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onPressed: () => _editExpense(item),
                                              ),
                                            ] else if (item.isArchived) ...[
                                              IconButton(
                                                icon: const Icon(Icons.unarchive_rounded, size: 16, color: Color(0xFF14332E)),
                                                tooltip: 'Restore from Archive',
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onPressed: () => _toggleArchiveExpense(item),
                                              ),
                                            ] else if (status == 'approved' || status == 'reimbursed') ...[
                                              IconButton(
                                                icon: const Icon(Icons.archive_outlined, size: 16, color: Color(0xFF64748B)),
                                                tooltip: 'Archive Record',
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onPressed: () => _toggleArchiveExpense(item),
                                              ),
                                            ] else ...[
                                              const Icon(Icons.lock_outline_rounded, size: 15, color: Color(0xFFCBD5E1)),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── 3. ENTERPRISE PAGINATION & FOOTER TOOLBAR ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                // Record count status
                Text(
                  'Showing ${startIndex + 1}–$endIndex of $totalItems expenses',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const Spacer(),
                // Rows per page selector
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Rows: ', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    ...[15, 25, 50].map((size) {
                      final isSelected = _rowsPerPage == size;
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _rowsPerPage = size;
                              _currentPage = 1;
                            });
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF14332E) : Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: isSelected ? const Color(0xFF14332E) : const Color(0xFFCBD5E1)),
                            ),
                            child: Text(
                              size.toString(),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.white : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(width: 14),
                // Pagination controls: Prev / Next
                InkWell(
                  onTap: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _currentPage > 1 ? Colors.white : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chevron_left_rounded,
                          size: 16,
                          color: _currentPage > 1 ? const Color(0xFF14332E) : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'Prev',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _currentPage > 1 ? const Color(0xFF14332E) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    '$_currentPage / $totalPages',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _currentPage < totalPages ? Colors.white : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Next',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _currentPage < totalPages ? const Color(0xFF14332E) : const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: _currentPage < totalPages ? const Color(0xFF14332E) : const Color(0xFF94A3B8),
                        ),
                      ],
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

  // ══════════════════════════════════════════════════════════════════════════
  // ── 4. EXPENSE DETAILS INSPECTION MODAL ───────────────────────────────────
  // ══════════════════════════════════════════════════════════════════════════
  void _showExpenseDetailsModal(PettyCashExpense expense) {
    final statusColor = _getStatusColor(expense.status);
    final categoryColor = _getCategoryColor(expense.categoryDisplay);
    final categoryIcon = _getCategoryIcon(expense.categoryDisplay);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: Colors.white,
        child: Container(
          constraints: BoxConstraints(maxWidth: 540, maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFF14332E),
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFE6C374), size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Expense Record Inspection',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        expense.status.toUpperCase(),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),

              // Content (Scrollable to prevent bottom overflow on shorter viewports)
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description & Hero Amount
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                expense.description,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('EEEE, MMMM d, yyyy').format(expense.expenseDate),
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14332E),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '₱${NumberFormat('#,##0.00').format(expense.amount)}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFFE6C374)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 14),

                    // Detail items
                    _detailItem('Category', expense.categoryDisplay, categoryIcon, categoryColor),
                    _detailItem('Recorded By', expense.purchasedBy, Icons.person_rounded, const Color(0xFF64748B)),
                    _detailItem(
                      'Payment Source',
                      expense.isAbono ? '🙋‍♂️ Staff Out-of-Pocket (Reimbursement)' : '🏢 Petty Cash Fund',
                      expense.isAbono ? Icons.account_balance_wallet_rounded : Icons.payments_rounded,
                      expense.isAbono ? const Color(0xFFD97706) : const Color(0xFF14332E),
                    ),
                    if (expense.supplier != null && expense.supplier!.isNotEmpty)
                      _detailItem('Supplier / Store', expense.supplier!, Icons.storefront_rounded, const Color(0xFF64748B)),
                    if (expense.receiptNumber != null && expense.receiptNumber!.isNotEmpty)
                      _detailItem(
                        expense.isNonOr ? 'Voucher Ref (Non-OR)' : 'Receipt / SI No.',
                        '#${expense.receiptNumber}',
                        expense.isNonOr ? Icons.confirmation_number_rounded : Icons.receipt_rounded,
                        expense.isNonOr ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                      ),
                    if (expense.isNonOr)
                      _detailItem(
                        'Receipt Type',
                        '🏷️ Non-OR (No Official Receipt / Voucher)',
                        Icons.receipt_long_rounded,
                        const Color(0xFF0284C7),
                      ),

                    // Linked Inventory Items
                    if ((expense.inventoryItems != null && expense.inventoryItems!.isNotEmpty) || expense.inventoryItemName != null) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'LINKED INVENTORY ITEMS',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 6),
                      if (expense.inventoryItems != null && expense.inventoryItems!.isNotEmpty) ...[
                        ...expense.inventoryItems!.map((it) => Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(it.itemName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                  Text('×${it.quantity}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF14332E))),
                                ],
                              ),
                            )),
                      ] else if (expense.inventoryItemName != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(expense.inventoryItemName!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                              Text('×${expense.quantityPurchased ?? 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF14332E))),
                            ],
                          ),
                        ),
                      ],
                    ],

                    // Notes (strip internal tags if present)
                    () {
                      final displayNotes = (expense.notes ?? '')
                          .replaceAll('[ABONO]', '')
                          .replaceAll('[NON-OR]', '')
                          .trim();
                      if (displayNotes.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              'Note: $displayNotes',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                            ),
                          ),
                        ],
                      );
                    }(),

                    // Receipt button
                    if (expense.receiptImageUrl != null) ...[
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: () => _showReceiptLightbox(expense.receiptImageUrl!),
                        icon: const Icon(Icons.photo_library_rounded, size: 16),
                        label: const Text('View Attached Receipt Proof'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF14332E),
                          side: const BorderSide(color: Color(0xFF14332E)),
                          minimumSize: const Size(double.infinity, 40),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

              // Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(18), bottomRight: Radius.circular(18)),
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (expense.status.toLowerCase() == 'pending') ...[
                      OutlinedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _editExpense(expense);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF14332E),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Edit Entry'),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (expense.isArchived) ...[
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _toggleArchiveExpense(expense);
                        },
                        icon: const Icon(Icons.unarchive_rounded, size: 16, color: Color(0xFF14332E)),
                        label: const Text('Restore from Archive'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF14332E),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ] else if (expense.status.toLowerCase() == 'approved' || expense.status.toLowerCase() == 'reimbursed') ...[
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _toggleArchiveExpense(expense);
                        },
                        icon: const Icon(Icons.archive_outlined, size: 16, color: Color(0xFF64748B)),
                        label: const Text('Move to Archive'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF475569),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF14332E),
                        foregroundColor: const Color(0xFFE6C374),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 1,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
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

  Widget _detailItem(String label, String value, IconData icon, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ── 5. ADD / EDIT EXPENSE MODAL ───────────────────────────────────────────
  // Matching Manage Inventory's Modal Layout & Input Styling 1:1
  // ══════════════════════════════════════════════════════════════════════════
  void _showAddExpenseDialog() {
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final supplierCtrl = TextEditingController();
    final receiptNumCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    bool isStaffAbono = false;
    bool isNoReceipt = false;

    String selectedCategory = 'inventory_purchase';
    List<Map<String, dynamic>> inventoryItems = [];
    List<Map<String, dynamic>> selectedInventoryItems = [];
    final itemSearchCtrl = TextEditingController();
    String itemSearchQuery = '';
    dynamic receiptImage;
    String? receiptImageUrl;
    bool isSaving = false;
    _isChipsExpanded = false;

    PettyCashFund? currentFund;
    StateSetter? addDialogSetter;
    _pettyCashService.getPettyCashFund().then((fund) {
      currentFund = fund;
      addDialogSetter?.call(() {});
    });

    _loadInventoryItems().then((items) {
      inventoryItems = items;
      addDialogSetter?.call(() {});
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          addDialogSetter = setDialogState;
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            elevation: 16,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Modal Header (matching Manage Inventory modal header)
                  Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: const BoxDecoration(
                      color: Color(0xFF14332E),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.add_circle_outline_rounded,
                          color: Color(0xFFE6C374),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Record Petty Cash Expense',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                          onPressed: isSaving ? null : () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  // Modal Form Fields
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Payment Source Selector (Kaha vs Abono ni Staff)
                          _buildPaymentSourceSelector(
                            isStaffAbono: isStaffAbono,
                            onChanged: (val) => setDialogState(() => isStaffAbono = val),
                          ),
                          const SizedBox(height: 12),

                          // 2. Description Input (Required)
                          _modalInput(
                            descCtrl,
                            'Purpose / Description *',
                            Icons.description_rounded,
                            hint: 'e.g., Emergency cooking oil & garlic / Transit fare',
                          ),
                          const SizedBox(height: 12),

                          // 3. Amount Input (Required)
                          _modalInput(
                            amountCtrl,
                            'Disbursement Amount (₱) *',
                            Icons.payments_rounded,
                            isNumber: true,
                            hint: '0.00',
                            onChanged: (_) => setDialogState(() {}),
                          ),
                          // Available balance / limit indicator
                          if (!isStaffAbono && currentFund != null) ...[
                            const SizedBox(height: 6),
                            Builder(builder: (ctx) {
                              final currentAmt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                              final available = currentFund?.currentBalance ?? 0.0;
                              final isOver = currentAmt > available && currentAmt > 0;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isOver ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isOver ? const Color(0xFFFCA5A5) : const Color(0xFFA7F3D0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isOver ? Icons.warning_amber_rounded : Icons.account_balance_wallet_rounded,
                                      size: 14,
                                      color: isOver ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        isOver
                                            ? 'Exceeds Petty Cash Fund! Available: ₱${NumberFormat('#,##0.00').format(available)} (Short by ₱${NumberFormat('#,##0.00').format(currentAmt - available)})'
                                            : 'Available in Petty Cash: ₱${NumberFormat('#,##0.00').format(available)}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: isOver ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ] else if (isStaffAbono) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFD97706)),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Staff Out-of-Pocket: Fund will not be deducted now; reimbursable upon approval.',
                                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFFB45309)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),

                          // 4. Category Dropdown
                          DropdownButtonFormField<String>(
                            initialValue: selectedCategory,
                            decoration: _modalInputDecoration('Expense Category', Icons.category_rounded),
                            items: PettyCashExpense.categories.map((c) {
                              return DropdownMenuItem(
                                value: c,
                                child: Text(
                                  c.split('_').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}').join(' '),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => selectedCategory = val);
                                if (val == 'inventory_purchase' && inventoryItems.isEmpty) {
                                  _loadInventoryItems().then((items) {
                                    setDialogState(() => inventoryItems = items);
                                  });
                                }
                              }
                            },
                          ),
                          const SizedBox(height: 12),

                          // 5. Inventory items selector box (only if inventory_purchase)
                          if (selectedCategory == 'inventory_purchase') ...[
                            _buildInventorySelectorBox(
                              context: context,
                              inventoryItems: inventoryItems,
                              selectedInventoryItems: selectedInventoryItems,
                              itemSearchCtrl: itemSearchCtrl,
                              itemSearchQuery: itemSearchQuery,
                              setDialogState: setDialogState,
                              onSearchChanged: (val) => setDialogState(() => itemSearchQuery = val),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Supplier & Receipt No. Row
                          Row(
                            children: [
                              Expanded(
                                child: _modalInput(
                                  supplierCtrl,
                                  'Supplier / Vendor',
                                  Icons.storefront_rounded,
                                  hint: isNoReceipt ? 'e.g., Tricycle Driver / Market' : 'e.g., Public Market',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _modalInput(
                                  receiptNumCtrl,
                                  isNoReceipt ? 'Voucher Ref (Non-OR)' : 'Receipt / SI No.',
                                  isNoReceipt ? Icons.confirmation_number_rounded : Icons.receipt_rounded,
                                  hint: isNoReceipt ? 'e.g., NON-OR-0923' : 'e.g., OR-10492',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Non-OR Toggle
                          _buildNonOrToggle(
                            isNoReceipt: isNoReceipt,
                            onChanged: (val) {
                              setDialogState(() {
                                isNoReceipt = val;
                                if (val) {
                                  if (receiptNumCtrl.text.trim().isEmpty) {
                                    receiptNumCtrl.text = 'NON-OR-${DateFormat('MMdd-HHmm').format(DateTime.now())}';
                                  }
                                } else {
                                  if (receiptNumCtrl.text.startsWith('NON-OR-')) {
                                    receiptNumCtrl.text = '';
                                  }
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 12),

                          // Receipt Photo dropzone
                          _buildReceiptUploadBox(
                            receiptImage: receiptImage,
                            onPickCamera: () async {
                              final picker = ImagePicker();
                              final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
                              if (file != null) setDialogState(() => receiptImage = file);
                            },
                            onPickGallery: () async {
                              final picker = ImagePicker();
                              final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                              if (file != null) setDialogState(() => receiptImage = file);
                            },
                            onRemoveImage: () => setDialogState(() => receiptImage = null),
                          ),
                          const SizedBox(height: 12),

                          // Additional Notes
                          _modalInput(
                            notesCtrl,
                            'Additional Remarks',
                            Icons.note_rounded,
                            hint: 'Optional notes for review...',
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Modal Action Footer (Cancel / Create Item style)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                      border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isSaving ? null : () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            foregroundColor: const Color(0xFF64748B),
                          ),
                          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF14332E),
                            foregroundColor: const Color(0xFFE6C374),
                            elevation: 2,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (descCtrl.text.trim().isEmpty) {
                                    _showErrorSnackBar(context, 'Please enter an expense description');
                                    return;
                                  }
                                  final amount = double.tryParse(amountCtrl.text.trim());
                                  if (amount == null || amount <= 0) {
                                    _showErrorSnackBar(context, 'Please enter a valid amount greater than 0');
                                    return;
                                  }
                                  if (!isStaffAbono) {
                                    final fund = currentFund ?? await _pettyCashService.getPettyCashFund();
                                    final available = fund?.currentBalance ?? 0.0;
                                    if (amount > available) {
                                      _showErrorSnackBar(
                                        context,
                                        'Insufficient Petty Cash Fund (Available: ₱${NumberFormat('#,##0.00').format(available)}). Please switch to "Staff Out-of-Pocket" if using personal funds or replenish the fund.',
                                      );
                                      return;
                                    }
                                  }
                                  if (selectedCategory == 'inventory_purchase' &&
                                      selectedInventoryItems.isEmpty) {
                                    _showErrorSnackBar(context, 'Please select at least one inventory item');
                                    return;
                                  }

                                  setDialogState(() => isSaving = true);

                                  final user = Supabase.instance.client.auth.currentUser;
                                  if (user == null) {
                                    setDialogState(() => isSaving = false);
                                    return;
                                  }

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
                                      debugPrint('Error uploading receipt: $e');
                                    }
                                  }

                                  List<InventoryExpenseItem>? inventoryExpenseItems;
                                  String? legacyId;
                                  String? legacyName;
                                  int? legacyQty;

                                  if (selectedInventoryItems.isNotEmpty) {
                                    inventoryExpenseItems = selectedInventoryItems.map((it) {
                                      return InventoryExpenseItem(
                                        itemId: it['id']?.toString() ?? '',
                                        itemName: it['name']?.toString() ?? 'Unknown',
                                        quantity: it['quantity'] as int? ?? 1,
                                      );
                                    }).toList();
                                    legacyId = selectedInventoryItems[0]['id']?.toString();
                                    legacyName = selectedInventoryItems[0]['name']?.toString();
                                    legacyQty = selectedInventoryItems[0]['quantity'] as int?;
                                  }

                                  final noteTags = <String>[];
                                  if (isStaffAbono) noteTags.add('[ABONO]');
                                  if (isNoReceipt) noteTags.add('[NON-OR]');
                                  final userNotes = notesCtrl.text.trim();
                                  final combinedNotes = [
                                    if (noteTags.isNotEmpty) noteTags.join(' '),
                                    if (userNotes.isNotEmpty) userNotes,
                                  ].join(' ').trim();

                                  final finalReceiptNo = receiptNumCtrl.text.trim().isNotEmpty
                                      ? receiptNumCtrl.text.trim()
                                      : (isNoReceipt ? 'NON-OR-${DateFormat('MMdd-HHmm').format(DateTime.now())}' : null);

                                  final newExpense = PettyCashExpense(
                                    expenseDate: DateTime.now(),
                                    description: descCtrl.text.trim(),
                                    amount: amount,
                                    category: selectedCategory,
                                    purchasedBy: user.email!,
                                    inventoryItemId: legacyId,
                                    inventoryItemName: legacyName,
                                    quantityPurchased: legacyQty,
                                    inventoryItems: inventoryExpenseItems,
                                    supplier: supplierCtrl.text.trim().isEmpty ? null : supplierCtrl.text.trim(),
                                    receiptImageUrl: receiptImageUrl,
                                    receiptNumber: finalReceiptNo,
                                    status: 'pending',
                                    notes: combinedNotes.isEmpty ? null : combinedNotes,
                                    createdAt: DateTime.now(),
                                    updatedAt: DateTime.now(),
                                  );

                                  final success = await _pettyCashService.createExpense(newExpense);
                                  if (context.mounted) {
                                    Navigator.pop(ctx);
                                    if (success) {
                                      setState(() {
                                        _selectedSort = 'newest';
                                        _selectedStatusFilter = 'pending';
                                        _searchQuery = '';
                                        _searchController.clear();
                                        _selectedCategory = 'All';
                                      });
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            Icon(
                                              success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                success
                                                    ? 'Expense request submitted! Placed at the top of Pending Review.'
                                                    : 'Failed to record expense',
                                                style: const TextStyle(fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                          ],
                                        ),
                                        backgroundColor: success ? const Color(0xFF10B981) : AppTheme.errorRed,
                                        duration: const Duration(seconds: 4),
                                      ),
                                    );
                                  }
                                },
                          child: isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(color: Color(0xFFE6C374), strokeWidth: 2),
                                )
                              : const Text('Record Expense', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _editExpense(PettyCashExpense expense) {
    bool isStaffAbono = expense.isAbono;
    bool isNoReceipt = expense.isNonOr;

    final descCtrl = TextEditingController(text: expense.description);
    final amountCtrl = TextEditingController(text: expense.amount.toStringAsFixed(2));
    final supplierCtrl = TextEditingController(text: expense.supplier ?? '');
    final receiptNumCtrl = TextEditingController(text: expense.receiptNumber ?? '');
    final rawNotes = (expense.notes ?? '')
        .replaceAll('[ABONO]', '')
        .replaceAll('[NON-OR]', '')
        .trim();
    final notesCtrl = TextEditingController(text: rawNotes);

    String selectedCategory = expense.category;
    List<Map<String, dynamic>> inventoryItems = [];
    List<Map<String, dynamic>> selectedInventoryItems = [];
    final itemSearchCtrl = TextEditingController();
    String itemSearchQuery = '';
    bool isSaving = false;
    _isChipsExpanded = false;

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

    PettyCashFund? currentFund;
    StateSetter? editDialogSetter;
    _pettyCashService.getPettyCashFund().then((fund) {
      currentFund = fund;
      editDialogSetter?.call(() {});
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          editDialogSetter = setDialogState;
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            elevation: 16,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: const BoxDecoration(
                      color: Color(0xFF14332E),
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.edit_rounded, color: Color(0xFFE6C374), size: 20),
                        const SizedBox(width: 10),
                        const Text('Edit Expense Entry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                          onPressed: isSaving ? null : () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  // Fields
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          // 1. Payment Source Selector (Kaha vs Abono ni Staff)
                          _buildPaymentSourceSelector(
                            isStaffAbono: isStaffAbono,
                            onChanged: (val) => setDialogState(() => isStaffAbono = val),
                          ),
                          const SizedBox(height: 12),

                          // 2. Purpose / Description Input (Required)
                          _modalInput(
                            descCtrl,
                            'Purpose / Description *',
                            Icons.description_rounded,
                            hint: 'e.g., Emergency cooking oil & garlic / Transit fare',
                          ),
                          const SizedBox(height: 12),

                          // 3. Amount Input (Required)
                          _modalInput(
                            amountCtrl,
                            'Disbursement Amount (₱) *',
                            Icons.payments_rounded,
                            isNumber: true,
                            onChanged: (_) => setDialogState(() {}),
                          ),
                          // Available balance / limit indicator
                          if (!isStaffAbono && currentFund != null) ...[
                            const SizedBox(height: 6),
                            Builder(builder: (ctx) {
                              final currentAmt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                              final available = currentFund?.currentBalance ?? 0.0;
                              final isOver = currentAmt > available && currentAmt > 0;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isOver ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isOver ? const Color(0xFFFCA5A5) : const Color(0xFFA7F3D0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isOver ? Icons.warning_amber_rounded : Icons.account_balance_wallet_rounded,
                                      size: 14,
                                      color: isOver ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        isOver
                                            ? 'Exceeds Petty Cash Fund! Available: ₱${NumberFormat('#,##0.00').format(available)} (Short by ₱${NumberFormat('#,##0.00').format(currentAmt - available)})'
                                            : 'Available in Petty Cash: ₱${NumberFormat('#,##0.00').format(available)}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: isOver ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ] else if (isStaffAbono) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFD97706)),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Staff Out-of-Pocket: Fund will not be deducted now; reimbursable upon approval.',
                                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFFB45309)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),

                          // 4. Category Dropdown
                          DropdownButtonFormField<String>(
                            initialValue: selectedCategory,
                            decoration: _modalInputDecoration('Expense Category', Icons.category_rounded),
                            items: PettyCashExpense.categories.map((c) {
                              return DropdownMenuItem(
                                value: c,
                                child: Text(c.split('_').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}').join(' '), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => selectedCategory = val);
                                if (val == 'inventory_purchase' && inventoryItems.isEmpty) {
                                  _loadInventoryItems().then((items) => setDialogState(() => inventoryItems = items));
                                }
                              }
                            },
                          ),
                          const SizedBox(height: 12),

                          // 5. Inventory items selector box (only if inventory_purchase)
                          if (selectedCategory == 'inventory_purchase') ...[
                            _buildInventorySelectorBox(
                              context: context,
                              inventoryItems: inventoryItems,
                              selectedInventoryItems: selectedInventoryItems,
                              itemSearchCtrl: itemSearchCtrl,
                              itemSearchQuery: itemSearchQuery,
                              setDialogState: setDialogState,
                              onSearchChanged: (val) => setDialogState(() => itemSearchQuery = val),
                            ),
                            const SizedBox(height: 12),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: _modalInput(
                                  supplierCtrl,
                                  'Supplier / Vendor',
                                  Icons.storefront_rounded,
                                  hint: isNoReceipt ? 'e.g., Tricycle Driver / Market' : 'e.g., Public Market',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _modalInput(
                                  receiptNumCtrl,
                                  isNoReceipt ? 'Voucher Ref (Non-OR)' : 'Receipt / SI No.',
                                  isNoReceipt ? Icons.confirmation_number_rounded : Icons.receipt_rounded,
                                  hint: isNoReceipt ? 'e.g., NON-OR-0923' : 'e.g., OR-10492',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildNonOrToggle(
                            isNoReceipt: isNoReceipt,
                            onChanged: (val) {
                              setDialogState(() {
                                isNoReceipt = val;
                                if (val) {
                                  if (receiptNumCtrl.text.trim().isEmpty) {
                                    receiptNumCtrl.text = 'NON-OR-${DateFormat('MMdd-HHmm').format(DateTime.now())}';
                                  }
                                } else {
                                  if (receiptNumCtrl.text.startsWith('NON-OR-')) {
                                    receiptNumCtrl.text = '';
                                  }
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          _modalInput(notesCtrl, 'Additional Remarks', Icons.note_rounded, maxLines: 2),
                        ],
                      ),
                    ),
                  ),

                  // Footer
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                      border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isSaving ? null : () => Navigator.pop(ctx),
                          child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF14332E),
                            foregroundColor: const Color(0xFFE6C374),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final amount = double.tryParse(amountCtrl.text.trim());
                                  if (descCtrl.text.trim().isEmpty || amount == null || amount <= 0) {
                                    _showErrorSnackBar(context, 'Please fill required fields properly');
                                    return;
                                  }
                                  if (!isStaffAbono) {
                                    final fund = currentFund ?? await _pettyCashService.getPettyCashFund();
                                    final available = fund?.currentBalance ?? 0.0;
                                    if (amount > available) {
                                      _showErrorSnackBar(
                                        context,
                                        'Insufficient Petty Cash Fund (Available: ₱${NumberFormat('#,##0.00').format(available)}). Please switch to "Staff Out-of-Pocket" if using personal funds or replenish the fund.',
                                      );
                                      return;
                                    }
                                  }

                                  setDialogState(() => isSaving = true);

                                  List<InventoryExpenseItem>? inventoryExpenseItems;
                                  String? legacyId;
                                  String? legacyName;
                                  int? legacyQty;

                                  if (selectedInventoryItems.isNotEmpty) {
                                    inventoryExpenseItems = selectedInventoryItems.map((it) {
                                      return InventoryExpenseItem(
                                        itemId: it['id']?.toString() ?? '',
                                        itemName: it['name']?.toString() ?? 'Unknown',
                                        quantity: it['quantity'] as int? ?? 1,
                                      );
                                    }).toList();
                                    legacyId = selectedInventoryItems[0]['id']?.toString();
                                    legacyName = selectedInventoryItems[0]['name']?.toString();
                                    legacyQty = selectedInventoryItems[0]['quantity'] as int?;
                                  }

                                  final noteTags = <String>[];
                                  if (isStaffAbono) noteTags.add('[ABONO]');
                                  if (isNoReceipt) noteTags.add('[NON-OR]');
                                  final userNotes = notesCtrl.text.trim();
                                  final combinedNotes = [
                                    if (noteTags.isNotEmpty) noteTags.join(' '),
                                    if (userNotes.isNotEmpty) userNotes,
                                  ].join(' ').trim();

                                  final finalReceiptNo = receiptNumCtrl.text.trim().isNotEmpty
                                      ? receiptNumCtrl.text.trim()
                                      : (isNoReceipt ? 'NON-OR-${DateFormat('MMdd-HHmm').format(DateTime.now())}' : null);

                                  final updatedExpense = PettyCashExpense(
                                    id: expense.id,
                                    expenseDate: expense.expenseDate,
                                    description: descCtrl.text.trim(),
                                    amount: amount,
                                    category: selectedCategory,
                                    purchasedBy: expense.purchasedBy,
                                    inventoryItemId: legacyId,
                                    inventoryItemName: legacyName,
                                    quantityPurchased: legacyQty,
                                    inventoryItems: inventoryExpenseItems,
                                    supplier: supplierCtrl.text.trim().isEmpty ? null : supplierCtrl.text.trim(),
                                    receiptNumber: finalReceiptNo,
                                    receiptImageUrl: expense.receiptImageUrl,
                                    status: expense.status,
                                    approvedBy: expense.approvedBy,
                                    approvedAt: expense.approvedAt,
                                    notes: combinedNotes.isEmpty ? null : combinedNotes,
                                    createdAt: expense.createdAt,
                                    updatedAt: DateTime.now(),
                                  );

                                  final success = await _pettyCashService.updateExpense(updatedExpense);
                                  if (context.mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(success ? 'Expense updated successfully' : 'Failed to update expense'),
                                        backgroundColor: success ? const Color(0xFF10B981) : AppTheme.errorRed,
                                      ),
                                    );
                                  }
                                },
                          child: isSaving
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Color(0xFFE6C374), strokeWidth: 2))
                              : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ── MODAL HELPER WIDGETS (IDENTICAL TO INVENTORY PAGE) ────────────────────
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildPaymentSourceSelector({
    required bool isStaffAbono,
    required ValueChanged<bool> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PAYMENT SOURCE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => onChanged(false),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: !isStaffAbono ? const Color(0xFF14332E) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: !isStaffAbono ? const Color(0xFF14332E) : const Color(0xFFCBD5E1),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.payments_rounded,
                        size: 16,
                        color: !isStaffAbono ? const Color(0xFFE6C374) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Petty Cash Fund',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: !isStaffAbono ? Colors.white : const Color(0xFF334155),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: () => onChanged(true),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: isStaffAbono ? const Color(0xFFD97706) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isStaffAbono ? const Color(0xFFD97706) : const Color(0xFFCBD5E1),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 16,
                        color: isStaffAbono ? Colors.white : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Staff Out-of-Pocket',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isStaffAbono ? Colors.white : const Color(0xFF334155),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNonOrToggle({
    required bool isNoReceipt,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!isNoReceipt),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isNoReceipt ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isNoReceipt ? const Color(0xFF16A34A).withValues(alpha: 0.5) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: isNoReceipt,
                onChanged: (val) => onChanged(val ?? false),
                activeColor: const Color(0xFF14332E),
                checkColor: const Color(0xFFE6C374),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No Official Receipt / Non-OR',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    'For transit fare (tricycle/jeep), parking, porterage, or local vendors',
                    style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modalInput(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isNumber = false,
    String? hint,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      maxLines: maxLines,
      style: TextStyle(
        fontSize: isNumber ? 15 : 13,
        fontWeight: isNumber ? FontWeight.w800 : FontWeight.w500,
        color: const Color(0xFF0F172A),
      ),
      decoration: _modalInputDecoration(label, icon, hint: hint),
      inputFormatters: isNumber
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))]
          : null,
    );
  }

  InputDecoration _modalInputDecoration(String label, IconData icon, {String? hint}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
      prefixIcon: Icon(icon, color: const Color(0xFF14332E), size: 18),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
    );
  }

  void _openInventoryPickerDialog(
    BuildContext context, {
    required List<Map<String, dynamic>> inventoryItems,
    required List<Map<String, dynamic>> selectedInventoryItems,
    required StateSetter setParentState,
  }) {
    String pickerSearch = '';
    final searchCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (pickerCtx) => StatefulBuilder(
        builder: (context, setPickerState) {
          final query = pickerSearch.toLowerCase().trim();
          final filtered = inventoryItems.where((item) {
            final name = (item['name'] ?? '').toString().toLowerCase();
            return name.contains(query);
          }).toList();

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: Colors.white,
            elevation: 16,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 460, maxHeight: 520),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: const BoxDecoration(
                      color: Color(0xFF14332E),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.inventory_2_rounded, color: Color(0xFFE6C374), size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Select Inventory Items',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                          onPressed: () => Navigator.pop(pickerCtx),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),

                  // Search bar
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        controller: searchCtrl,
                        onChanged: (val) => setPickerState(() => pickerSearch = val),
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search inventory items...',
                          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                          suffixIcon: pickerSearch.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                                  onPressed: () {
                                    searchCtrl.clear();
                                    setPickerState(() => pickerSearch = '');
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 9),
                        ),
                      ),
                    ),
                  ),
                  // Sub-header with item count and small Select All button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${filtered.length} ${filtered.length == 1 ? 'item' : 'items'} available',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                        if (filtered.isNotEmpty)
                          Builder(builder: (ctx) {
                            final allSelected = filtered.every((it) => selectedInventoryItems.any((s) => s['id'].toString() == it['id'].toString()));
                            return InkWell(
                              onTap: () {
                                setPickerState(() {
                                  if (allSelected) {
                                    for (var it in filtered) {
                                      final idStr = it['id'].toString();
                                      selectedInventoryItems.removeWhere((s) => s['id'].toString() == idStr);
                                    }
                                  } else {
                                    for (var it in filtered) {
                                      final idStr = it['id'].toString();
                                      final exists = selectedInventoryItems.any((s) => s['id'].toString() == idStr);
                                      if (!exists) {
                                        selectedInventoryItems.add({
                                          'id': it['id'],
                                          'name': it['name'],
                                          'quantity': 1,
                                        });
                                      }
                                    }
                                  }
                                });
                                setParentState(() {});
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: allSelected ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: allSelected ? const Color(0xFFA7F3D0) : const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      allSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                      size: 13,
                                      color: allSelected ? const Color(0xFF059669) : const Color(0xFF475569),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      allSelected ? 'Deselect All' : 'Select All',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: allSelected ? const Color(0xFF059669) : const Color(0xFF475569),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),

                  // List of items
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              inventoryItems.isEmpty ? 'Loading inventory items...' : 'No inventory items found',
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            itemBuilder: (context, idx) {
                              final item = filtered[idx];
                              final idStr = item['id'].toString();
                              final selIndex = selectedInventoryItems.indexWhere((s) => s['id'].toString() == idStr);
                              final isSel = selIndex != -1;
                              final qty = isSel ? (selectedInventoryItems[selIndex]['quantity'] as int? ?? 1) : 0;

                              return InkWell(
                                onTap: () {
                                  setPickerState(() {
                                    if (isSel) {
                                      selectedInventoryItems.removeAt(selIndex);
                                    } else {
                                      selectedInventoryItems.add({
                                        'id': item['id'],
                                        'name': item['name'],
                                        'quantity': 1,
                                      });
                                    }
                                  });
                                  setParentState(() {});
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSel ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                        color: isSel ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          item['name'] ?? '',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                            color: isSel ? const Color(0xFF047857) : const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                      if (isSel)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '$qty linked',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  // Footer
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${selectedInventoryItems.length} items linked',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(pickerCtx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF14332E),
                            foregroundColor: const Color(0xFFE6C374),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInventorySelectorBox({
    required BuildContext context,
    required List<Map<String, dynamic>> inventoryItems,
    required List<Map<String, dynamic>> selectedInventoryItems,
    required TextEditingController itemSearchCtrl,
    required String itemSearchQuery,
    required StateSetter setDialogState,
    required ValueChanged<String> onSearchChanged,
  }) {
    final query = itemSearchQuery.toLowerCase().trim();
    final hasQuery = query.isNotEmpty;
    final filtered = hasQuery
        ? inventoryItems.where((item) {
            final name = (item['name'] ?? '').toString().toLowerCase();
            return name.contains(query);
          }).take(5).toList()
        : <Map<String, dynamic>>[];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with count and Browse button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.inventory_2_rounded, size: 16, color: Color(0xFF14332E)),
                  const SizedBox(width: 6),
                  const Text(
                    'Link Inventory Items',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF0F172A)),
                  ),
                  if (selectedInventoryItems.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14332E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${selectedInventoryItems.length}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10, color: Color(0xFFE6C374)),
                      ),
                    ),
                  ],
                ],
              ),
              Row(
                children: [
                  if (selectedInventoryItems.isNotEmpty) ...[
                    InkWell(
                      onTap: () {
                        setDialogState(() {
                          selectedInventoryItems.clear();
                        });
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.clear_all_rounded, size: 12, color: Color(0xFFDC2626)),
                            SizedBox(width: 3),
                            Text(
                              'Clear All',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  InkWell(
                    onTap: () {
                      _openInventoryPickerDialog(
                        context,
                        inventoryItems: inventoryItems,
                        selectedInventoryItems: selectedInventoryItems,
                        setParentState: setDialogState,
                      );
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14332E),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.list_alt_rounded, size: 13, color: Color(0xFFE6C374)),
                          SizedBox(width: 4),
                          Text(
                            'Browse All',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFFE6C374)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Linked Items as Compact Chips (Tag Input style)
          if (selectedInventoryItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            Builder(builder: (ctx) {
              final totalCount = selectedInventoryItems.length;
              final showAll = _isChipsExpanded || totalCount <= 4;
              final visibleItems = showAll ? selectedInventoryItems : selectedInventoryItems.take(4).toList();
              final hiddenCount = totalCount - 4;

              Widget buildChip(Map<String, dynamic> sel) {
                final q = sel['quantity'] as int? ?? 1;
                return Container(
                  padding: const EdgeInsets.fromLTRB(8, 4, 6, 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF059669)),
                      const SizedBox(width: 5),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 130),
                        child: Text(
                          sel['name'] ?? '',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF047857)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Compact Qty Stepper
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () {
                                setDialogState(() {
                                  if (q > 1) {
                                    sel['quantity'] = q - 1;
                                  } else {
                                    selectedInventoryItems.removeWhere((i) => i['id'] == sel['id']);
                                  }
                                });
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(2),
                                child: Icon(Icons.remove, size: 11, color: Color(0xFF047857)),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                '$q',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF047857)),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                setDialogState(() {
                                  sel['quantity'] = q + 1;
                                });
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(2),
                                child: Icon(Icons.add, size: 11, color: Color(0xFF047857)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Remove icon
                      InkWell(
                        onTap: () {
                          setDialogState(() {
                            selectedInventoryItems.removeWhere((i) => i['id'] == sel['id']);
                          });
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(Icons.close_rounded, size: 13, color: Color(0xFFDC2626)),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Container(
                constraints: _isChipsExpanded ? const BoxConstraints(maxHeight: 110) : null,
                child: SingleChildScrollView(
                  physics: _isChipsExpanded ? const ClampingScrollPhysics() : const NeverScrollableScrollPhysics(),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...visibleItems.map(buildChip),
                      if (totalCount > 4)
                        InkWell(
                          onTap: () {
                            setDialogState(() {
                              _isChipsExpanded = !_isChipsExpanded;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isChipsExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                  size: 14,
                                  color: const Color(0xFF334155),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isChipsExpanded ? 'Show less' : '+$hiddenCount more items',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],

          const SizedBox(height: 8),

          // Autocomplete / Typeahead Search Input
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
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Type to quickly add item (e.g. Rice, Onion)...',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF64748B)),
                prefixIconConstraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                suffixIcon: hasQuery
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 15, color: Color(0xFF94A3B8)),
                        onPressed: () {
                          itemSearchCtrl.clear();
                          onSearchChanged('');
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                isDense: true,
              ),
            ),
          ),

          // Floating/Collapsible Suggestion Dropdown (Only appears when typing!)
          if (hasQuery) ...[
            const SizedBox(height: 4),
            Container(
              constraints: const BoxConstraints(maxHeight: 140),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: Text('No matching items found', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (filtered.length > 1) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            color: const Color(0xFFF8FAFC),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${filtered.length} matches',
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                ),
                                InkWell(
                                  onTap: () {
                                    setDialogState(() {
                                      for (var it in filtered) {
                                        final idStr = it['id'].toString();
                                        if (!selectedInventoryItems.any((s) => s['id'].toString() == idStr)) {
                                          selectedInventoryItems.add({
                                            'id': it['id'],
                                            'name': it['name'],
                                            'quantity': 1,
                                          });
                                        }
                                      }
                                      itemSearchCtrl.clear();
                                      onSearchChanged('');
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(4),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.done_all_rounded, size: 12, color: Color(0xFF0284C7)),
                                        SizedBox(width: 3),
                                        Text(
                                          'Select All',
                                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF0284C7)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        ],
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            itemBuilder: (context, index) {
                        final it = filtered[index];
                        final idStr = it['id'].toString();
                        final isAlready = selectedInventoryItems.any((s) => s['id'].toString() == idStr);

                        return InkWell(
                          onTap: () {
                            setDialogState(() {
                              if (!isAlready) {
                                selectedInventoryItems.add({
                                  'id': it['id'],
                                  'name': it['name'],
                                  'quantity': 1,
                                });
                              }
                              itemSearchCtrl.clear();
                              onSearchChanged('');
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Row(
                              children: [
                                Icon(
                                  isAlready ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                                  size: 15,
                                  color: isAlready ? const Color(0xFF059669) : const Color(0xFF0284C7),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    it['name'] ?? '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isAlready ? FontWeight.w700 : FontWeight.w500,
                                      color: isAlready ? const Color(0xFF047857) : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                Text(
                                  isAlready ? 'Already Added' : '+ Add',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isAlready ? const Color(0xFF059669) : const Color(0xFF0284C7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReceiptUploadBox({
    required dynamic receiptImage,
    required VoidCallback onPickCamera,
    required VoidCallback onPickGallery,
    required VoidCallback onRemoveImage,
  }) {
    if (receiptImage != null) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF10B981)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: const Color(0xFFE2E8F0),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: kIsWeb
                    ? Image.network((receiptImage as XFile).path, fit: BoxFit.cover)
                    : Image.file(receiptImage as File, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Receipt Photo Attached', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                  Text('Ready to upload upon saving', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Color(0xFFDC2626), size: 18),
              onPressed: onRemoveImage,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onPickCamera,
              icon: const Icon(Icons.camera_alt_rounded, size: 15),
              label: const Text('Camera'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF14332E),
                padding: const EdgeInsets.symmetric(vertical: 8),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onPickGallery,
              icon: const Icon(Icons.photo_library_rounded, size: 15),
              label: const Text('Gallery'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF14332E),
                padding: const EdgeInsets.symmetric(vertical: 8),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ── 6. RECEIPT LIGHTBOX DIALOG ────────────────────────────────────────────
  // ══════════════════════════════════════════════════════════════════════════
  void _showReceiptLightbox(String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 700, maxHeight: 800),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 10)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(child: CircularProgressIndicator(color: Color(0xFFE6C374)));
                    },
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_rounded, size: 48, color: Colors.white54),
                          SizedBox(height: 10),
                          Text('Unable to load receipt image', style: TextStyle(color: Colors.white70)),
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
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ── 7. DELETE CONFIRMATION ALERT (MATCHING INVENTORY DELETE DIALOG) ──────
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _deleteExpense(String expenseId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.errorRed),
            SizedBox(width: 8),
            Text(
              'Delete Claim Entry',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this pending expense entry?',
          style: TextStyle(color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _pettyCashService.deleteExpense(expenseId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Expense claim deleted' : 'Failed to delete expense'),
            backgroundColor: success ? const Color(0xFF10B981) : AppTheme.errorRed,
          ),
        );
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ── ARCHIVE / RESTORE ACTION DIALOG ──────────────────────────────────────
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _toggleArchiveExpense(PettyCashExpense expense) async {
    final willArchive = !expense.isArchived;
    final actionText = willArchive ? 'ilagay sa Archive' : 'ibalik mula sa Archive';
    final actionTitle = willArchive ? 'Archive Expense Record' : 'Restore Expense Record';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(
              willArchive ? Icons.archive_outlined : Icons.unarchive_rounded,
              color: const Color(0xFF14332E),
            ),
            const SizedBox(width: 8),
            Text(
              actionTitle,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          willArchive
              ? 'Nais mo bang $actionText ang "${expense.description}"?\n\nIlilipat ito sa Archived Records para manatiling malinis ang active list. Pwede mo itong buksan o i-restore anumang oras.'
              : 'Nais mo bang $actionText ang "${expense.description}"?\n\nIbabalik ito sa active list.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF14332E),
              foregroundColor: const Color(0xFFE6C374),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(willArchive ? 'Archive' : 'Restore', style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _pettyCashService.archiveExpense(expense.id!, archive: willArchive);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? (willArchive ? '✅ Inilagay sa Archive ang record' : '✅ Naibalik sa active list ang record')
                : 'Failed to update archive status'),
            backgroundColor: success ? const Color(0xFF10B981) : AppTheme.errorRed,
          ),
        );
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ── 8. EMPTY STATE (MATCHING INVENTORY EMPTY STATE) ───────────────────────
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildEmptyState(bool isCompletelyEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isCompletelyEmpty ? 'No petty cash expenses found' : 'No matching expenses found',
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF475569),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Try adjusting your search query or filters',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ── 9. HELPER METHODS ─────────────────────────────────────────────────────
  // ══════════════════════════════════════════════════════════════════════════
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
        content: Text(message),
        backgroundColor: AppTheme.errorRed,
      ),
    );
  }
}
