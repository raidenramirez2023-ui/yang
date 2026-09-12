import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yang_chow/services/paymongo_service.dart';
import 'package:yang_chow/services/receipt_pdf_service.dart';
import 'package:yang_chow/services/reservation_service.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:yang_chow/widgets/customer/customer_ui_components.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Modern Customer Transactions & Invoices Ledger Page (Full-Width Maximized)
// ══════════════════════════════════════════════════════════════════════════════

class TransactionsPage extends StatefulWidget {
  final List<dynamic> initialTransactions;

  const TransactionsPage({super.key, required this.initialTransactions});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  late List<dynamic> _transactions;
  bool _isLoading = false;
  Timer? _pollingTimer;
  final _fmt = NumberFormat('#,##0.00', 'en_PH');
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', 'paid', 'unpaid', 'cancelled'
  int _currentPage = 1;
  static const int _itemsPerPage = 15;

  @override
  void initState() {
    super.initState();
    _transactions = List.from(widget.initialTransactions);
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  int get _paidCount => _transactions.where((t) {
        final ps = t['payment_status']?.toString().toLowerCase() ?? '';
        return ps == 'paid' || ps == 'fully_paid';
      }).length;

  int get _unpaidCount => _transactions.where((t) {
        final ps = t['payment_status']?.toString().toLowerCase() ?? '';
        final status = t['status']?.toString().toLowerCase() ?? '';
        return (ps == 'unpaid' || ps == 'deposit_paid' || ps == 'pending') && status != 'cancelled';
      }).length;

  int get _cancelledCount => _transactions.where((t) {
        final status = t['status']?.toString().toLowerCase() ?? '';
        return status == 'cancelled';
      }).length;

  Future<void> _refreshTransactions() async {
    setState(() => _isLoading = true);
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      final results = await Future.wait([
        Supabase.instance.client
            .from('reservations')
            .select('*')
            .eq('customer_email', currentUser.email!)
            .order('created_at', ascending: false),
        Supabase.instance.client
            .from('advance_orders')
            .select('*')
            .eq('customer_email', currentUser.email!)
            .order('created_at', ascending: false),
      ]);

      final reservations = List<Map<String, dynamic>>.from(results[0]).map((r) {
        return {...r, '_db_table': 'reservations'};
      }).toList();

      final advanceOrders = List<Map<String, dynamic>>.from(results[1]).where((o) {
        final ps = o['payment_status']?.toString() ?? '';
        return ps == 'paid' || ps == 'fully_paid';
      }).map((o) {
        return {
          ...o,
          'event_type': 'Advance Order (${o['order_type']})',
          'event_date': o['order_date'],
          'start_time': o['order_time'],
          'duration_hours': 0,
          '_db_table': 'advance_orders',
        };
      }).toList();

      final combined = [...reservations, ...advanceOrders];
      combined.sort((a, b) {
        final aTime = DateTime.parse(a['created_at'] ?? DateTime.now().toUtc().toIso8601String());
        final bTime = DateTime.parse(b['created_at'] ?? DateTime.now().toUtc().toIso8601String());
        return bTime.compareTo(aTime);
      });

      if (mounted) {
        setState(() {
          _transactions = combined;
          _isLoading = false;
          _currentPage = 1;
        });
      }
    } catch (e) {
      debugPrint('Error refreshing transactions: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to refresh transactions'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  List<dynamic> get _filteredTransactions {
    List<dynamic> list;
    if (_selectedFilter == 'paid') {
      list = _transactions.where((t) {
        final ps = t['payment_status']?.toString().toLowerCase() ?? '';
        return ps == 'paid' || ps == 'fully_paid';
      }).toList();
    } else if (_selectedFilter == 'unpaid') {
      list = _transactions.where((t) {
        final ps = t['payment_status']?.toString().toLowerCase() ?? '';
        final status = t['status']?.toString().toLowerCase() ?? '';
        return (ps == 'unpaid' || ps == 'deposit_paid' || ps == 'pending') && status != 'cancelled';
      }).toList();
    } else if (_selectedFilter == 'cancelled') {
      list = _transactions.where((t) {
        final status = t['status']?.toString().toLowerCase() ?? '';
        return status == 'cancelled';
      }).toList();
    } else {
      list = _transactions;
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((t) {
        final id = (t['id']?.toString() ?? '').toLowerCase();
        final eventType = (t['event_type']?.toString() ?? '').toLowerCase();
        final eventDate = (t['event_date']?.toString() ?? '').toLowerCase();
        final status = (t['status']?.toString() ?? '').toLowerCase();
        final paymentStatus = (t['payment_status']?.toString() ?? '').toLowerCase();
        return id.contains(q) ||
            eventType.contains(q) ||
            eventDate.contains(q) ||
            status.contains(q) ||
            paymentStatus.contains(q);
      }).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final displayedList = _filteredTransactions;

    // Pagination calculations (15 items per page)
    final totalItems = displayedList.length;
    final totalPages = totalItems > 0 ? (totalItems / _itemsPerPage).ceil() : 1;
    if (_currentPage > totalPages) {
      _currentPage = totalPages;
    }
    if (_currentPage < 1) {
      _currentPage = 1;
    }

    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage < totalItems)
        ? startIndex + _itemsPerPage
        : totalItems;

    final paginatedList = totalItems > 0
        ? displayedList.sublist(startIndex, endIndex)
        : <dynamic>[];

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.navColor,
        elevation: 0,
        leading: AnimatedTapScale(
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        ),
        title: Text(
          'Transactions & Invoices',
          style: GoogleFonts.lora(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _refreshTransactions,
            icon: _isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh Transactions',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshTransactions,
        color: AppTheme.forestGreen,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 24,
            vertical: isMobile ? 18 : 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Summary Row ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Billing & Transaction Records',
                          style: GoogleFonts.inter(
                            fontSize: isMobile ? 20 : 24,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.darkGrey,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Official receipts, payment statuses, and reservation statements.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.mediumGrey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Quick Summary Metrics Strip ──
              _buildSummaryMetrics(isMobile),

              const SizedBox(height: 16),

              // ── Search Bar ──
              _buildSearchBar(),

              const SizedBox(height: 14),

              // ── Filter Chips ──
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildFilterChip('All', 'all', count: _transactions.length, icon: Icons.grid_view_rounded),
                    const SizedBox(width: 8),
                    _buildFilterChip('Paid / Settled', 'paid', count: _paidCount, icon: Icons.check_circle_rounded),
                    const SizedBox(width: 8),
                    _buildFilterChip('Pending / Due', 'unpaid', count: _unpaidCount, icon: Icons.pending_actions_rounded),
                    const SizedBox(width: 8),
                    _buildFilterChip('Cancelled', 'cancelled', count: _cancelledCount, icon: Icons.cancel_outlined),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Loading & Empty State ──
              if (_isLoading && _transactions.isEmpty)
                Column(
                  children: List.generate(3, (index) => const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: AppShimmer(width: double.infinity, height: 120, borderRadius: 20),
                  )),
                )
              else if (displayedList.isEmpty)
                EmptyStateCard(
                  icon: Icons.receipt_long_rounded,
                  title: _searchQuery.isNotEmpty ? 'No matching records' : 'No transactions found',
                  description: _searchQuery.isNotEmpty
                      ? 'No transactions matching "$_searchQuery". Try clearing your search.'
                      : (_selectedFilter == 'all'
                          ? 'Your reservation orders and payment invoices will appear here.'
                          : 'No transactions matching "$_selectedFilter" filter.'),
                )
              else ...[
                // ── Table View on Desktop/Tablet vs Card View on Mobile ──
                isMobile
                    ? _buildMobileTransactionsList(paginatedList)
                    : _buildDesktopTransactionsTable(paginatedList),

                const SizedBox(height: 16),

                _buildPagination(
                  totalItems: totalItems,
                  currentPage: _currentPage,
                  totalPages: totalPages,
                  onPageChanged: (newPage) {
                    setState(() {
                      _currentPage = newPage;
                    });
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryMetrics(bool isMobile) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            title: 'Total Records',
            value: '${_transactions.length}',
            icon: Icons.receipt_long_rounded,
            color: const Color(0xFF14332E),
            bgTint: const Color(0xFF14332E).withValues(alpha: 0.08),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricCard(
            title: 'Paid / Settled',
            value: '$_paidCount',
            icon: Icons.check_circle_rounded,
            color: const Color(0xFF16A34A),
            bgTint: const Color(0xFF16A34A).withValues(alpha: 0.09),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricCard(
            title: 'Pending / Due',
            value: '$_unpaidCount',
            icon: Icons.pending_actions_rounded,
            color: const Color(0xFFD97706),
            bgTint: const Color(0xFFD97706).withValues(alpha: 0.09),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgTint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: bgTint,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 15, color: color),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.darkGrey,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
            _currentPage = 1;
          });
        },
        style: GoogleFonts.inter(fontSize: 13, color: AppTheme.darkGrey),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search by reference #, event, date, or status...',
          hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _currentPage = 1;
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String key, {int? count, IconData? icon}) {
    final isSelected = _selectedFilter == key;
    return InkWell(
      onTap: () => setState(() {
        _selectedFilter = key;
        _currentPage = 1;
      }),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF14332E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF14332E) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF14332E).withValues(alpha: 0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: isSelected ? const Color(0xFFD9A441) : const Color(0xFF64748B),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFD9A441) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? const Color(0xFF14332E) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPagination({
    required int totalItems,
    required int currentPage,
    required int totalPages,
    required ValueChanged<int> onPageChanged,
  }) {
    if (totalItems == 0) return const SizedBox.shrink();

    final startItem = ((currentPage - 1) * _itemsPerPage) + 1;
    final endItem = (currentPage * _itemsPerPage < totalItems)
        ? currentPage * _itemsPerPage
        : totalItems;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing $startItem–$endItem of $totalItems entries',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF14332E).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Page $currentPage of $totalPages',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF14332E),
                  ),
                ),
              ),
            ],
          ),
          if (totalPages > 1) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Previous Button
                AnimatedTapScale(
                  onTap: currentPage > 1
                      ? () {
                          onPageChanged(currentPage - 1);
                        }
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: currentPage > 1 ? const Color(0xFF14332E) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: currentPage > 1 ? const Color(0xFF14332E) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chevron_left_rounded,
                          size: 16,
                          color: currentPage > 1 ? Colors.white : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Prev',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: currentPage > 1 ? Colors.white : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Page Number Buttons (smart windowing)
                ...List.generate(totalPages, (index) {
                  final pageNum = index + 1;
                  if (totalPages > 5) {
                    if (pageNum != 1 &&
                        pageNum != totalPages &&
                        (pageNum < currentPage - 1 || pageNum > currentPage + 1)) {
                      if (pageNum == currentPage - 2 || pageNum == currentPage + 2) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            '…',
                            style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    }
                  }

                  final isSelected = pageNum == currentPage;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: AnimatedTapScale(
                      onTap: () {
                        if (!isSelected) {
                          onPageChanged(pageNum);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFD9A441) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: isSelected ? const Color(0xFFD9A441) : const Color(0xFFE2E8F0),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFD9A441).withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          '$pageNum',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                            color: isSelected ? const Color(0xFF14332E) : const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                  );
                }),

                const SizedBox(width: 8),

                // Next Button
                AnimatedTapScale(
                  onTap: currentPage < totalPages
                      ? () {
                          onPageChanged(currentPage + 1);
                        }
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: currentPage < totalPages ? const Color(0xFF14332E) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: currentPage < totalPages ? const Color(0xFF14332E) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Next',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: currentPage < totalPages ? Colors.white : const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: currentPage < totalPages ? Colors.white : const Color(0xFF94A3B8),
                        ),
                      ],
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

  // ══════════════════════════════════════════════════════════════════════════
  // 🖥️ FULL-WIDTH MAXIMIZED DESKTOP/TABLET DATA TABLE VIEW
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildDesktopTransactionsTable(List<dynamic> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = math.max(constraints.maxWidth, 980.0);

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: const BoxDecoration(
                      color: Color(0xFF14332E),
                    ),
                    child: Row(
                      children: [
                        _buildTableHeaderCell('REF #', flex: 2),
                        _buildTableHeaderCell('EVENT / ORDER', flex: 4),
                        _buildTableHeaderCell('DATE & TIME', flex: 3),
                        _buildTableHeaderCell('AMOUNT', flex: 3),
                        _buildTableHeaderCell('PAYMENT', flex: 3),
                        _buildTableHeaderCell('STATUS', flex: 2),
                        _buildTableHeaderCell('ACTION', flex: 2, alignment: Alignment.centerRight),
                      ],
                    ),
                  ),

                  // Table Rows
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final tx = Map<String, dynamic>.from(items[index]);
                      return _buildTableRow(context, tx, index);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTableHeaderCell(String title, {required int flex, Alignment alignment = Alignment.centerLeft}) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: alignment,
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Colors.white.withValues(alpha: 0.85),
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  Widget _buildTableRow(BuildContext context, Map<String, dynamic> tx, int index) {
    final rawId = tx['id']?.toString() ?? '';
    final ref = rawId.length >= 8 ? rawId.substring(0, 8).toUpperCase() : rawId.toUpperCase();
    final eventType = tx['event_type']?.toString() ?? 'Dining Reservation';
    final eventDate = tx['event_date']?.toString() ?? 'N/A';
    final startTime = tx['start_time']?.toString() ?? '';
    final status = tx['status']?.toString() ?? 'pending';
    final paymentStatus = tx['payment_status']?.toString() ?? 'unpaid';
    final isAdvanceOrder = tx['_db_table'] == 'advance_orders';
    final totalPrice = (tx['total_price'] as num?)?.toDouble() ?? 0.0;
    final depositAmount = (tx['deposit_amount'] as num?)?.toDouble() ?? 0.0;
    final remaining = (tx['remaining_balance'] as num?)?.toDouble() ?? (totalPrice - depositAmount);

    return Material(
      color: index % 2 == 0 ? Colors.white : const Color(0xFFFAFAFA),
      child: InkWell(
        onTap: () => _showTransactionDetailModal(context, tx),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              // Ref #
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    '#$ref',
                    style: GoogleFonts.robotoMono(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ),
              ),

              // Event / Order
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: isAdvanceOrder
                            ? const Color(0xFF0EA5E9).withValues(alpha: 0.1)
                            : AppTheme.forestGreen.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isAdvanceOrder ? Icons.fastfood_rounded : Icons.event_seat_rounded,
                        size: 15,
                        color: isAdvanceOrder ? const Color(0xFF0284C7) : AppTheme.forestGreen,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        eventType,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkGrey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Date & Time
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      eventDate,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkGrey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (startTime.isNotEmpty)
                      Text(
                        startTime,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.mediumGrey,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),

              // Amount
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      totalPrice > 0 ? '₱${_fmt.format(totalPrice)}' : '—',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.darkGrey,
                      ),
                    ),
                    if (paymentStatus == 'deposit_paid' && remaining > 0)
                      Text(
                        '₱${_fmt.format(remaining)} due',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                  ],
                ),
              ),

              // Payment Status
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildPaymentBadge(paymentStatus, isAdvanceOrder: isAdvanceOrder),
                ),
              ),

              // Status
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildStatusChip(status),
                ),
              ),

              // Action
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => _showTransactionDetailModal(context, tx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      foregroundColor: const Color(0xFF1E293B),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, size: 15),
                      ],
                    ),
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
  // 📱 MOBILE COMPACT LEDGER CARDS (WRAP PROTECTED - ZERO OVERFLOW)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildMobileTransactionsList(List<dynamic> items) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final tx = Map<String, dynamic>.from(items[index]);
        final rawId = tx['id']?.toString() ?? '';
        final ref = rawId.length >= 8 ? rawId.substring(0, 8).toUpperCase() : rawId.toUpperCase();
        final eventType = tx['event_type']?.toString() ?? 'Dining Reservation';
        final eventDate = tx['event_date']?.toString() ?? 'N/A';
        final startTime = tx['start_time']?.toString() ?? '';
        final status = tx['status']?.toString() ?? 'pending';
        final paymentStatus = tx['payment_status']?.toString() ?? 'unpaid';
        final isAdvanceOrder = tx['_db_table'] == 'advance_orders';
        final totalPrice = (tx['total_price'] as num?)?.toDouble() ?? 0.0;
        final depositAmount = (tx['deposit_amount'] as num?)?.toDouble() ?? 0.0;
        final remaining = (tx['remaining_balance'] as num?)?.toDouble() ?? (totalPrice - depositAmount);

        IconData itemIcon = Icons.event_seat_rounded;
        Color iconColor = AppTheme.forestGreen;
        Color iconBg = const Color(0xFF14332E).withValues(alpha: 0.08);

        final lowerType = eventType.toLowerCase();
        if (isAdvanceOrder) {
          itemIcon = Icons.restaurant_rounded;
          iconColor = const Color(0xFF0284C7);
          iconBg = const Color(0xFF0EA5E9).withValues(alpha: 0.12);
        } else if (lowerType.contains('wedding')) {
          itemIcon = Icons.favorite_rounded;
          iconColor = const Color(0xFFBE185D);
          iconBg = const Color(0xFFFCE7F3);
        } else if (lowerType.contains('birthday')) {
          itemIcon = Icons.cake_rounded;
          iconColor = const Color(0xFFD97706);
          iconBg = const Color(0xFFFEF3C7);
        } else if (lowerType.contains('party') || lowerType.contains('celebration')) {
          itemIcon = Icons.celebration_rounded;
          iconColor = const Color(0xFF8B5CF6);
          iconBg = const Color(0xFFEDE9FE);
        }

        Color accentColor;
        if (status.toLowerCase() == 'cancelled') {
          accentColor = const Color(0xFFEF4444);
        } else if (paymentStatus == 'paid' || paymentStatus == 'fully_paid') {
          accentColor = const Color(0xFF10B981);
        } else if (paymentStatus == 'deposit_paid') {
          accentColor = const Color(0xFF0284C7);
        } else {
          accentColor = const Color(0xFFF59E0B);
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Left status accent indicator strip
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 4.5,
                child: Container(color: accentColor),
              ),

              // Main card content
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showTransactionDetailModal(context, tx),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Row: Category Icon + Title/Ref + Total Price
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: iconBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(itemIcon, size: 18, color: iconColor),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    eventType,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.darkGrey,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '#$ref',
                                          style: GoogleFonts.robotoMono(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF475569),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '$eventDate${startTime.isNotEmpty ? " • $startTime" : ""}',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: const Color(0xFF64748B),
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
                            // Total Price Column
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (totalPrice > 0)
                                  Text(
                                    '₱${_fmt.format(totalPrice)}',
                                    style: GoogleFonts.inter(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.darkGrey,
                                    ),
                                  )
                                else
                                  Text(
                                    '—',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                if (paymentStatus == 'deposit_paid' && remaining > 0)
                                  Text(
                                    '₱${_fmt.format(remaining)} due',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFDC2626),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),
                        const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 10),

                        // Bottom Row: Badges & Details CTA
                        Row(
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _buildPaymentBadge(paymentStatus, isAdvanceOrder: isAdvanceOrder),
                                  if (_shouldShowStatusChip(paymentStatus, status))
                                    _buildStatusChip(status),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF14332E).withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF14332E).withValues(alpha: 0.1),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Details',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF14332E),
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 15,
                                    color: Color(0xFF14332E),
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
            ],
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 🧾 TRANSACTION DETAILS & RECEIPT MODAL
  // ══════════════════════════════════════════════════════════════════════════
  void _showTransactionDetailModal(BuildContext context, Map<String, dynamic> tx) {
    final rawId = tx['id']?.toString() ?? '';
    final ref = rawId.length >= 8 ? rawId.substring(0, 8).toUpperCase() : rawId.toUpperCase();
    final eventType = tx['event_type']?.toString() ?? 'Reservation';
    final eventDate = tx['event_date']?.toString() ?? 'N/A';
    final startTime = tx['start_time']?.toString() ?? 'N/A';
    final guests = tx['number_of_guests']?.toString();
    final duration = tx['duration_hours']?.toString();
    final status = tx['status']?.toString() ?? 'pending';
    final paymentStatus = tx['payment_status']?.toString() ?? 'unpaid';
    final receiptUrl = tx['receipt_url']?.toString();
    final isAdvanceOrder = tx['_db_table'] == 'advance_orders';

    final totalPrice = (tx['total_price'] as num?)?.toDouble() ?? 0.0;
    final depositAmount = (tx['deposit_amount'] as num?)?.toDouble() ?? 0.0;
    final remaining = (tx['remaining_balance'] as num?)?.toDouble() ?? (totalPrice - depositAmount);

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Modal Header ──
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF14332E), Color(0xFF1A453E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: Icon(
                            isAdvanceOrder ? Icons.fastfood_rounded : Icons.receipt_long_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                eventType,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Invoice Ref #$ref',
                                style: GoogleFonts.robotoMono(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                          onPressed: () => Navigator.pop(dialogContext),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: 18,
                        ),
                      ],
                    ),
                  ),

                  // ── Modal Content Details ──
                  Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status & Payment Summary
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('PAYMENT STATUS', style: _modalLabelStyle),
                                const SizedBox(height: 4),
                                _buildPaymentBadge(paymentStatus, isAdvanceOrder: isAdvanceOrder),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('BOOKING STATUS', style: _modalLabelStyle),
                                const SizedBox(height: 4),
                                _buildStatusChip(status),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),
                        const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 16),

                        // Booking Schedule & Details
                        _buildModalInfoRow(Icons.calendar_today_rounded, 'Date', eventDate),
                        const SizedBox(height: 10),
                        _buildModalInfoRow(Icons.access_time_rounded, 'Time', startTime),
                        if (guests != null) ...[
                          const SizedBox(height: 10),
                          _buildModalInfoRow(Icons.people_alt_rounded, 'Party Size', '$guests guests'),
                        ],
                        if (!isAdvanceOrder && duration != null) ...[
                          const SizedBox(height: 10),
                          _buildModalInfoRow(Icons.timer_rounded, 'Duration', '$duration hours'),
                        ],

                        const SizedBox(height: 18),
                        const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 16),

                        // Pricing Breakdown
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('FINANCIAL BREAKDOWN', style: _modalLabelStyle),
                              const SizedBox(height: 10),
                              if (totalPrice > 0)
                                _buildPriceLine('Total Invoiced', '₱${_fmt.format(totalPrice)}', isBold: true),
                              if (depositAmount > 0) ...[
                                const SizedBox(height: 6),
                                _buildPriceLine('Deposit Settled', '- ₱${_fmt.format(depositAmount)}', isGreen: true),
                              ],
                              if (remaining > 0 && paymentStatus == 'deposit_paid') ...[
                                const SizedBox(height: 6),
                                const Divider(height: 12, thickness: 1, color: Color(0xFFE2E8F0)),
                                _buildPriceLine('Remaining Balance Due', '₱${_fmt.format(remaining)}', isBold: true, isRed: true),
                              ],
                            ],
                          ),
                        ),

                        // Actions: Pay Remaining Balance or Download PDF Receipt
                        if (tx['_db_table'] == 'reservations' && paymentStatus == 'deposit_paid' && remaining > 0) ...[
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                _payRemainingBalance(
                                  reservationId: rawId,
                                  remaining: remaining,
                                  eventType: eventType,
                                );
                              },
                              icon: const Icon(Icons.payment_rounded, size: 16),
                              label: Text('Pay ₱${_fmt.format(remaining)} via GCash'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0EA5E9),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ],

                        // ── Official Yang Chow Electronic PDF Receipt (Direct Download) ──
                        if (status != 'cancelled' && (paymentStatus == 'paid' || paymentStatus == 'fully_paid' || paymentStatus == 'deposit_paid')) ...[
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                try {
                                  await ReceiptPdfService.downloadReceiptPdf(
                                    tx,
                                    isPaymentReceipt: paymentStatus == 'fully_paid' || paymentStatus == 'paid',
                                  );
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to download PDF receipt: $e'),
                                        backgroundColor: AppTheme.errorRed,
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Color(0xFF14332E)),
                              label: Text(
                                'Download Official Receipt (PDF)',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF14332E),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(color: Color(0xFF14332E), width: 1.2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ],

                        // ── External PayMongo Gateway Record (if available) ──
                        if (receiptUrl != null && receiptUrl.isNotEmpty && (receiptUrl.contains('pm.link') || receiptUrl.contains('paymongo'))) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              onPressed: () async {
                                final uri = Uri.parse(receiptUrl);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              },
                              icon: const Icon(Icons.open_in_new_rounded, size: 14, color: Color(0xFF0284C7)),
                              label: Text(
                                'View PayMongo Transaction Record',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0284C7),
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
          ),
        ),
      ),
    );
  }

  TextStyle get _modalLabelStyle => GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF94A3B8),
        letterSpacing: 0.9,
      );

  Widget _buildModalInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 10),
        Text(label, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(value, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.darkGrey, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildPriceLine(String label, String amount, {bool isGreen = false, bool isRed = false, bool isBold = false}) {
    Color color = AppTheme.darkGrey;
    if (isGreen) color = const Color(0xFF16A34A);
    if (isRed) color = const Color(0xFFDC2626);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: isBold ? AppTheme.darkGrey : const Color(0xFF64748B),
          ),
        ),
        Text(
          amount,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 🏷️ BADGES & STATUS CHIPS (ZERO-OVERFLOW GUARANTEE)
  // ══════════════════════════════════════════════════════════════════════════
  bool _shouldShowStatusChip(String paymentStatus, String status) {
    final ps = paymentStatus.toLowerCase().trim();
    final s = status.toLowerCase().trim();
    // Prevent redundant badges (e.g. UNPAID and UNPAID, or PAID and PAID)
    if (ps == s) return false;
    if ((ps == 'unpaid' || ps == 'pending') && (s == 'unpaid' || s == 'pending')) return false;
    if ((ps == 'paid' || ps == 'fully_paid') && (s == 'paid' || s == 'fully_paid')) return false;
    return true;
  }

  Widget _buildPaymentBadge(String paymentStatus, {bool isAdvanceOrder = false}) {
    final isPaid = paymentStatus == 'paid' || paymentStatus == 'fully_paid';
    final isDepositPaid = paymentStatus == 'deposit_paid';
    final isPendingVerification = paymentStatus == 'pending_verification';
    final color = isPaid
        ? const Color(0xFF16A34A)
        : isDepositPaid
            ? const Color(0xFF0284C7)
            : isPendingVerification
                ? const Color(0xFF8B5CF6)
                : const Color(0xFFD97706);
    final bgColor = isPaid
        ? const Color(0xFFF0FDF4)
        : isDepositPaid
            ? const Color(0xFFF0F9FF)
            : isPendingVerification
                ? const Color(0xFFF5F3FF)
                : const Color(0xFFFFFBEB);
    final label = isPaid
        ? 'PAID'
        : isDepositPaid
            ? (isAdvanceOrder ? 'FULL PAID' : 'DEPOSIT PAID')
            : isPendingVerification
                ? 'VERIFYING'
                : paymentStatus.toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.5, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPaid
                ? Icons.check_circle_rounded
                : isDepositPaid
                    ? Icons.savings_rounded
                    : isPendingVerification
                        ? Icons.sync_rounded
                        : Icons.pending_rounded,
            size: 11.5,
            color: color,
          ),
          const SizedBox(width: 4.5),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    Color bgColor;
    IconData icon;
    String displayLabel = status.toUpperCase();

    switch (status.toLowerCase()) {
      case 'pending':
        color = const Color(0xFFD97706);
        bgColor = const Color(0xFFFFFBEB);
        icon = Icons.hourglass_top_rounded;
        displayLabel = 'PENDING';
        break;
      case 'confirmed':
        color = const Color(0xFF16A34A);
        bgColor = const Color(0xFFF0FDF4);
        icon = Icons.check_circle_rounded;
        displayLabel = 'CONFIRMED';
        break;
      case 'paid':
      case 'fully_paid':
        color = const Color(0xFF16A34A);
        bgColor = const Color(0xFFF0FDF4);
        icon = Icons.verified_rounded;
        displayLabel = 'SETTLED';
        break;
      case 'cancelled':
        color = const Color(0xFFDC2626);
        bgColor = const Color(0xFFFEF2F2);
        icon = Icons.cancel_rounded;
        displayLabel = 'CANCELLED';
        break;
      case 'no_show':
        color = const Color(0xFFEA580C);
        bgColor = const Color(0xFFFFF7ED);
        icon = Icons.person_off_rounded;
        displayLabel = 'NO SHOW';
        break;
      case 'unpaid':
        color = const Color(0xFFF59E0B);
        bgColor = const Color(0xFFFFFBEB);
        icon = Icons.schedule_rounded;
        displayLabel = 'AWAITING PAYMENT';
        break;
      default:
        color = const Color(0xFF64748B);
        bgColor = const Color(0xFFF8FAFC);
        icon = Icons.info_outline_rounded;
        displayLabel = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.5, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11.5, color: color),
          const SizedBox(width: 4.5),
          Flexible(
            child: Text(
              displayLabel,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 💳 PAYMONGO REMAINING BALANCE INTEGRATION
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _payRemainingBalance({
    required String reservationId,
    required double remaining,
    required String eventType,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            const CircularProgressIndicator(color: Color(0xFF0EA5E9)),
            const SizedBox(width: 16),
            const Expanded(child: Text('Creating payment link...')),
          ],
        ),
      ),
    );

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      final customerName = currentUser?.userMetadata?['name'] ?? currentUser?.email?.split('@')[0] ?? 'Customer';

      final response = await PayMongoService.createPaymentLink(
        amount: remaining,
        description: 'Remaining Balance — $eventType',
        metadata: {
          'source': 'remaining_balance_self_service',
          'reservation_id': reservationId,
          'customer_name': customerName,
        },
      );

      if (mounted) Navigator.of(context).pop();

      if (response['success'] == true && response['checkoutUrl'] != null) {
        final checkoutUrl = response['checkoutUrl'] as String;
        final linkId = response['linkId'] as String?;

        try {
          await Supabase.instance.client.from('reservations').update({
            'balance_link_id': linkId,
            'balance_link_url': checkoutUrl,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', reservationId);
        } catch (e) {
          debugPrint('Warning: could not save balance link to DB: $e');
        }

        await launchUrl(Uri.parse(checkoutUrl), mode: LaunchMode.externalApplication);

        if (mounted) {
          _showWaitingForPaymentDialog(
            remaining: remaining,
            onCancel: () {
              _pollingTimer?.cancel();
            },
          );
          if (linkId != null) {
            _startPolling(
              linkId: linkId,
              reservationId: reservationId,
              remaining: remaining,
            );
          }
        }
      } else {
        throw Exception('No checkout URL returned');
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  void _showWaitingForPaymentDialog({
    required double remaining,
    required VoidCallback onCancel,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(28),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.qr_code_2, size: 48, color: Color(0xFF0EA5E9)),
            ),
            const SizedBox(height: 20),
            Text(
              'Waiting for Payment...',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGrey,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Text(
                '₱${_fmt.format(remaining)}',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFDC2626),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(color: Color(0xFF0EA5E9), strokeWidth: 3),
            ),
            const SizedBox(height: 16),
            Text(
              'Complete payment in the GCash/PayMongo page that just opened.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.mediumGrey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              onCancel();
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _startPolling({
    required String linkId,
    required String reservationId,
    required double remaining,
  }) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final result = await PayMongoService.retrievePaymentLink(linkId);
        if (result['isPaid'] == true) {
          timer.cancel();
          if (mounted) Navigator.of(context).pop();

          final svc = ReservationService();
          await svc.updatePaymentStatus(
            id: reservationId,
            paymentStatus: 'pending_verification',
            table: 'reservations',
            paymentAmount: remaining,
            paymentReference: 'PayMongo-Balance',
          );

          await _refreshTransactions();

          if (mounted) _showPaymentSuccessDialog(remaining);
        }
      } catch (e) {
        debugPrint('Polling error: $e');
      }
    });
  }

  void _showPaymentSuccessDialog(double amount) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(28),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, size: 48, color: AppTheme.successGreen),
            ),
            const SizedBox(height: 20),
            Text(
              'Payment Received!',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGrey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '₱${_fmt.format(amount)} remaining balance successfully paid.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.mediumGrey),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Your reservation is now fully paid ✅',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.successGreen,
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.forestGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
