import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/services/refund_service.dart';

class StaffOrderHistoryPage extends StatefulWidget {
  const StaffOrderHistoryPage({super.key});

  @override
  State<StaffOrderHistoryPage> createState() => _StaffOrderHistoryPageState();
}

class _StaffOrderHistoryPageState extends State<StaffOrderHistoryPage> {
  // ── Design tokens ──────────────────────────────────────────────────────────
  static const _primaryDark = Color(0xFF0C241F);
  static const _accentGold = Color(0xFFD9A441);
  static const _red = Color(0xFFDC2626);
  static const _bg = Color(0xFFF8FAFC);
  static const _border = Color(0xFFE2E8F0);
  static const _grey = Color(0xFF64748B);
  static const _textDark = Color(0xFF0F172A);

  final _supabase = Supabase.instance.client;
  final _fmt = NumberFormat('#,##0.00', 'en_US');

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Today', 'This Week'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Fetch orders ───────────────────────────────────────────────────────────
  Stream<List<Map<String, dynamic>>> _ordersStream() {
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  // ── Filter helpers ─────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> orders) {
    final now = DateTime.now();
    return orders.where((o) {
      final createdAt = DateTime.tryParse(o['created_at']?.toString() ?? '');
      if (createdAt == null) return false;

      if (_selectedFilter == 'Today') {
        if (createdAt.year != now.year ||
            createdAt.month != now.month ||
            createdAt.day != now.day) {
          return false;
        }
      } else if (_selectedFilter == 'This Week') {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final start =
            DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        if (createdAt.isBefore(start)) return false;
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final tid = (o['transaction_id'] ?? '').toString().toLowerCase();
        final dbid = (o['id'] ?? '').toString();
        final orderId = tid.isNotEmpty
            ? tid
            : (int.tryParse(dbid) != null ? dbid.padLeft(3, '0') : dbid);
        final customerName = (o['customer_name'] ?? '').toString().toLowerCase();
        if (!orderId.contains(q) && !customerName.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  String _formatTs(String? raw) {
    if (raw == null) return '—';
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return raw;
    return DateFormat('MMM d, yyyy • h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _border, height: 1),
        ),
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
                  ),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: _textDark, size: 18),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Order History',
                      style: GoogleFonts.inter(
                        color: _textDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'POS transactions & cash refund records',
                      style: GoogleFonts.inter(
                        color: _grey,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _primaryDark.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: _primaryDark.withValues(alpha: 0.15)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.point_of_sale_rounded,
                        size: 13, color: _primaryDark),
                    const SizedBox(width: 5),
                    Text(
                      'POS Register',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _ordersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _primaryDark),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading orders: ${snapshot.error}',
                style: GoogleFonts.inter(color: _red, fontSize: 13),
              ),
            );
          }

          final allOrders = snapshot.data ?? [];
          final filtered = _applyFilters(allOrders);

          // Calculate summary metrics for currently visible orders
          double totalRevenue = 0.0;
          int refundedCount = 0;

          for (final o in filtered) {
            final isFull = o['refund_status'] == 'full_refund';
            if (!isFull) {
              final amt = (o['total_amount'] as num?)?.toDouble() ?? 0.0;
              totalRevenue += amt;
            }
            if (o['refund_status'] == 'full_refund' ||
                o['refund_status'] == 'partial_refund') {
              refundedCount++;
            }
          }

          return Column(
            children: [
              // Top filter controls
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  children: [
                    _buildSearchBar(),
                    const SizedBox(height: 10),
                    _buildFilterChips(filtered.length),
                  ],
                ),
              ),

              // Summary metric banner
              if (filtered.isNotEmpty)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetricItem(
                        icon: Icons.receipt_long_rounded,
                        label: 'Total Orders',
                        value: '${filtered.length}',
                        color: _textDark,
                      ),
                      Container(width: 1, height: 28, color: _border),
                      _buildMetricItem(
                        icon: Icons.payments_rounded,
                        label: 'Net Sales',
                        value: '₱ ${_fmt.format(totalRevenue)}',
                        color: const Color(0xFF166534),
                      ),
                      Container(width: 1, height: 28, color: _border),
                      _buildMetricItem(
                        icon: Icons.assignment_return_rounded,
                        label: 'Refunds',
                        value: '$refundedCount',
                        color: refundedCount > 0 ? _red : _grey,
                      ),
                    ],
                  ),
                ),

              // Table Content
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmptyState()
                    : _buildOrdersTable(filtered),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: _grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: TextField(
        controller: _searchController,
        keyboardType: TextInputType.text,
        onChanged: (v) => setState(() => _searchQuery = v.trim()),
        style: GoogleFonts.inter(fontSize: 13, color: _textDark),
        decoration: InputDecoration(
          hintText: 'Search by order #, transaction ID, or customer name...',
          hintStyle: GoogleFonts.inter(color: _grey, fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, color: _grey, size: 19),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, color: _grey, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: false,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildFilterChips(int count) {
    return Row(
      children: _filters.map((f) {
        final selected = _selectedFilter == f;
        IconData filterIcon;
        if (f == 'All') {
          filterIcon = Icons.list_alt_rounded;
        } else if (f == 'Today') {
          filterIcon = Icons.today_rounded;
        } else {
          filterIcon = Icons.date_range_rounded;
        }

        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => setState(() => _selectedFilter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? _primaryDark : _bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? _primaryDark : _border,
                  width: selected ? 1.5 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: _primaryDark.withValues(alpha: 0.18),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    filterIcon,
                    size: 14,
                    color: selected ? _accentGold : _grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    f,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? Colors.white : _grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
              border: Border.all(color: _border),
            ),
            child: const Icon(Icons.receipt_long_outlined,
                size: 48, color: _grey),
          ),
          const SizedBox(height: 16),
          Text(
            'No orders found',
            style: GoogleFonts.inter(
              color: _textDark,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try searching with a different order number'
                : 'Completed POS transactions will appear here.',
            style: GoogleFonts.inter(color: _grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── Table Builder ──────────────────────────────────────────────────────────
  Widget _buildOrdersTable(List<Map<String, dynamic>> orders) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const minTableWidth = 920.0;
            final isConstrained = constraints.maxWidth < minTableWidth;

            final tableWidget = Column(
              children: [
                // Table Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(bottom: BorderSide(color: _border)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 120,
                        child: _tableHeaderLabel('ORDER #'),
                      ),
                      SizedBox(
                        width: 170,
                        child: _tableHeaderLabel('DATE & TIME'),
                      ),
                      Expanded(
                        flex: 3,
                        child: _tableHeaderLabel('CUSTOMER'),
                      ),
                      SizedBox(
                        width: 90,
                        child: _tableHeaderLabel('ITEMS'),
                      ),
                      SizedBox(
                        width: 130,
                        child: _tableHeaderLabel('TOTAL AMOUNT', align: TextAlign.right),
                      ),
                      SizedBox(
                        width: 140,
                        child: Center(child: _tableHeaderLabel('STATUS')),
                      ),
                      SizedBox(
                        width: 190,
                        child: Center(child: _tableHeaderLabel('ACTIONS')),
                      ),
                    ],
                  ),
                ),

                // Table Rows
                Expanded(
                  child: ListView.separated(
                    itemCount: orders.length,
                    separatorBuilder: (context, index) => const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFF1F5F9),
                    ),
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return _OrderTableRow(
                        key: ValueKey(order['id']),
                        order: order,
                        fmt: _fmt,
                        formatTs: _formatTs,
                        onViewDetails: () => _showOrderDetailsDialog(context, order),
                        onRefund: () => _showPosRefundDialog(context, order),
                      );
                    },
                  ),
                ),
              ],
            );

            if (isConstrained) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: minTableWidth,
                  child: tableWidget,
                ),
              );
            }

            return tableWidget;
          },
        ),
      ),
    );
  }

  Widget _tableHeaderLabel(String label, {TextAlign align = TextAlign.left}) {
    return Text(
      label,
      textAlign: align,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF64748B),
        letterSpacing: 0.6,
      ),
    );
  }

  // ── Order Details Dialog (Digital Receipt Modal) ───────────────────────────
  void _showOrderDetailsDialog(
      BuildContext context, Map<String, dynamic> order) {
    final tid = order['transaction_id']?.toString();
    final dbid = order['id']?.toString() ?? '';
    final orderId =
        tid ?? (int.tryParse(dbid) != null ? dbid.padLeft(3, '0') : dbid);
    final rawName = order['customer_name']?.toString().trim();
    final customerName = (rawName != null &&
            rawName.isNotEmpty &&
            rawName.toLowerCase() != 'guest' &&
            rawName.toLowerCase() != 'walk-in customer' &&
            rawName.toLowerCase() != 'walk-in')
        ? rawName
        : 'Walk-in Customer';
    final isFullRefund = order['refund_status'] == 'full_refund';
    final isPartialRefund = order['refund_status'] == 'partial_refund';
    final total = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
    final paid = (order['amount_paid'] as num?)?.toDouble() ?? total;
    final change = (order['change_due'] as num?)?.toDouble() ?? 0.0;
    final ts = _formatTs(order['created_at']?.toString());
    final cashier = order['cashier_name'] ?? order['processed_by'] ?? 'Cashier Staff';

    showDialog(
      context: context,
      builder: (ctx) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchOrderItems(order['id'].toString()),
          builder: (context, snapshot) {
            final items = snapshot.data ?? [];
            final loading =
                snapshot.connectionState == ConnectionState.waiting;

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              contentPadding: EdgeInsets.zero,
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8FAFC),
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(18)),
                          border: Border(bottom: BorderSide(color: _border)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isFullRefund
                                    ? Colors.red.shade50
                                    : _primaryDark.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isFullRefund
                                      ? Colors.red.shade100
                                      : _primaryDark.withValues(alpha: 0.12),
                                ),
                              ),
                              child: Icon(
                                isFullRefund
                                    ? Icons.receipt_rounded
                                    : Icons.point_of_sale_rounded,
                                color: isFullRefund ? _red : _primaryDark,
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
                                        '#$orderId',
                                        style: GoogleFonts.inter(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                          color: _textDark,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildStatusBadge(
                                          isFullRefund, isPartialRefund),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    ts,
                                    style: GoogleFonts.inter(
                                        fontSize: 12, color: _grey),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: _grey, size: 20),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ),

                      // Meta details info
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildMetaColumn(
                                  'CUSTOMER', customerName, Icons.person_outline),
                              _buildMetaColumn('ORDER TYPE',
                                  order['order_type'] ?? 'POS', Icons.storefront_outlined),
                              _buildMetaColumn('PROCESSED BY',
                                  cashier.toString(), Icons.badge_outlined),
                            ],
                          ),
                        ),
                      ),

                      // Item list
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ORDER ITEMS',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: _grey,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (loading)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: _primaryDark,
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            else if (items.isEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: Text(
                                  'No items recorded for this order.',
                                  style: GoogleFonts.inter(
                                      color: _grey, fontSize: 13),
                                ),
                              )
                            else
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: _border),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  children: [
                                    ...items.map((it) {
                                      final name = it['item_name'] ?? 'Item';
                                      final qty =
                                          (it['quantity'] as num?)?.toInt() ??
                                              1;
                                      final price =
                                          (it['unit_price'] as num?)
                                                  ?.toDouble() ??
                                              0.0;
                                      final sub = price * qty;

                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 10),
                                        decoration: const BoxDecoration(
                                          border: Border(
                                            bottom:
                                                BorderSide(color: Color(0xFFF1F5F9)),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name,
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: _textDark,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '×$qty',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                      const Color(0xFF475569),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            SizedBox(
                                              width: 80,
                                              child: Text(
                                                '₱ ${_fmt.format(sub)}',
                                                textAlign: TextAlign.right,
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: _textDark,
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
                          ],
                        ),
                      ),

                      // Notes if any
                      if (order['note'] != null &&
                          order['note'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEFCE8),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xFFFEF08A)),
                            ),
                            child: Text(
                              'Note: ${order['note']}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF854D0E),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ),

                      // Totals breakdown
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _border),
                          ),
                          child: Column(
                            children: [
                              _buildReceiptRow('Total Amount',
                                  '₱ ${_fmt.format(total)}',
                                  isBold: true, isLarge: true),
                              const SizedBox(height: 8),
                              _buildReceiptRow('Amount Paid (Cash)',
                                  '₱ ${_fmt.format(paid)}'),
                              if (change > 0) ...[
                                const SizedBox(height: 6),
                                _buildReceiptRow('Change Given',
                                    '₱ ${_fmt.format(change)}',
                                    color: const Color(0xFF166534)),
                              ],
                            ],
                          ),
                        ),
                      ),

                      // Footer Actions
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(
                                'Close',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _grey,
                                ),
                              ),
                            ),
                            if (!isFullRefund) ...[
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                icon: const Icon(
                                    Icons.assignment_return_rounded,
                                    size: 15,
                                    color: Colors.white),
                                label: Text(
                                  'Process Refund',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _red,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _showPosRefundDialog(context, order);
                                },
                              ),
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
        );
      },
    );
  }

  Widget _buildMetaColumn(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: _grey,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: _primaryDark),
            const SizedBox(width: 4),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _textDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReceiptRow(String label, String value,
      {bool isBold = false, bool isLarge = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: isLarge ? 14 : 12,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: isLarge ? _textDark : _grey,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: isLarge ? 16 : 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: color ?? _textDark,
          ),
        ),
      ],
    );
  }

  // ── Helper to load items for dialogs ──────────────────────────────────────
  Future<List<Map<String, dynamic>>> _fetchOrderItems(String orderId) async {
    try {
      final res = await _supabase
          .from('order_items')
          .select()
          .eq('order_id', orderId)
          .order('id');

      List<Map<String, dynamic>> itemsList =
          List<Map<String, dynamic>>.from(res);

      if (itemsList.isEmpty) {
        final refundRes = await _supabase
            .from('refunds')
            .select('refunded_items')
            .eq('source_table', 'orders')
            .eq('source_id', orderId)
            .maybeSingle();

        if (refundRes != null && refundRes['refunded_items'] != null) {
          final raw = refundRes['refunded_items'];
          if (raw is List) {
            itemsList = List<Map<String, dynamic>>.from(raw);
          }
        }
      }
      return itemsList;
    } catch (_) {
      return [];
    }
  }

  // ── POS Refund Dialog ──────────────────────────────────────────────────────
  void _showPosRefundDialog(BuildContext context, Map<String, dynamic> order) {
    final passcodeCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final currentUser = _supabase.auth.currentUser;
    String initialCashierName =
        currentUser?.userMetadata?['full_name']?.toString() ??
            currentUser?.userMetadata?['name']?.toString() ??
            currentUser?.email?.split('@').first ??
            'Cashier Staff';
    final cashierCtrl = TextEditingController(text: initialCashierName);
    bool isLoading = false;
    String? errorMsg;
    bool obscurePasscode = true;

    final orderId = order['id'].toString();
    final transactionId = order['transaction_id']?.toString() ?? orderId;
    final totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;

    List<Map<String, dynamic>> localItems = [];
    bool fetchingItems = true;
    Set<int> selectedIndices = {};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          if (fetchingItems) {
            _fetchOrderItems(orderId).then((loaded) {
              if (ctx.mounted) {
                setDlgState(() {
                  localItems = loaded;
                  fetchingItems = false;
                  selectedIndices =
                      Set.from(List.generate(localItems.length, (i) => i));
                });
              }
            }).catchError((_) {
              if (ctx.mounted) {
                setDlgState(() {
                  fetchingItems = false;
                });
              }
            });
          }

          final currentRefundTotal =
              selectedIndices.fold<double>(0.0, (sum, i) {
            if (i < localItems.length) {
              final it = localItems[i];
              final qty = (it['quantity'] as num?)?.toInt() ?? 1;
              final price = (it['unit_price'] as num?)?.toDouble() ?? 0.0;
              return sum + (price * qty);
            }
            return sum;
          });

          final allSelected = localItems.isNotEmpty &&
              selectedIndices.length == localItems.length;

          return AlertDialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: const Icon(Icons.assignment_return_rounded,
                      color: _red, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Process POS Cash Refund',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _textDark,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Order #$transactionId',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SELECT ITEMS TO REFUND',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        color: _grey,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (fetchingItems)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: CircularProgressIndicator(
                              color: _red, strokeWidth: 2),
                        ),
                      )
                    else if (localItems.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'No order items found.',
                          style: GoogleFonts.inter(color: _grey, fontSize: 12),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: _border),
                          borderRadius: BorderRadius.circular(12),
                          color: const Color(0xFFF8FAFC),
                        ),
                        child: Column(
                          children: [
                            // Select All Header
                            InkWell(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12)),
                              onTap: () {
                                setDlgState(() {
                                  if (allSelected) {
                                    selectedIndices.clear();
                                  } else {
                                    selectedIndices = Set.from(List.generate(
                                        localItems.length, (i) => i));
                                  }
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: allSelected,
                                      activeColor: _red,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(4)),
                                      onChanged: (val) {
                                        setDlgState(() {
                                          if (val == true) {
                                            selectedIndices = Set.from(
                                                List.generate(
                                                    localItems.length,
                                                    (i) => i));
                                          } else {
                                            selectedIndices.clear();
                                          }
                                        });
                                      },
                                    ),
                                    Text(
                                      'Select All Items',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: _textDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Divider(height: 1, color: _border),
                            // Item List
                            ...localItems.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final it = entry.value;
                              final name = it['item_name'] ?? 'Item';
                              final qty =
                                  (it['quantity'] as num?)?.toInt() ?? 1;
                              final price =
                                  (it['unit_price'] as num?)?.toDouble() ??
                                      0.0;
                              final itemSubtotal = price * qty;
                              final isChecked = selectedIndices.contains(idx);

                              return InkWell(
                                onTap: () {
                                  setDlgState(() {
                                    if (isChecked) {
                                      selectedIndices.remove(idx);
                                    } else {
                                      selectedIndices.add(idx);
                                    }
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        value: isChecked,
                                        activeColor: _red,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(4)),
                                        onChanged: (val) {
                                          setDlgState(() {
                                            if (val == true) {
                                              selectedIndices.add(idx);
                                            } else {
                                              selectedIndices.remove(idx);
                                            }
                                          });
                                        },
                                      ),
                                      Expanded(
                                        child: Text(
                                          '$name ×$qty',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: isChecked
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: _textDark,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '₱ ${_fmt.format(itemSubtotal)}',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: isChecked
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          color: isChecked ? _red : _grey,
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
                    const SizedBox(height: 14),

                    // Refund Summary Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Refund Amount:',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF166534),
                            ),
                          ),
                          Text(
                            '₱ ${_fmt.format(currentRefundTotal)}',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF166534),
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Cashier / Processed By Field
                    Text(
                      'CASHIER / PROCESSED BY',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        color: _grey,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: cashierCtrl,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: _textDark,
                          fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Cashier name',
                        prefixIcon: const Icon(Icons.person_outline,
                            size: 18, color: _grey),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Reason Field
                    Text(
                      'REFUND REASON',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        color: _grey,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: reasonCtrl,
                      style:
                          GoogleFonts.inter(fontSize: 13, color: _textDark),
                      decoration: InputDecoration(
                        hintText: 'e.g. Customer cancelled, wrong item',
                        hintStyle:
                            GoogleFonts.inter(fontSize: 12, color: _grey),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Passcode Field
                    Text(
                      'ADMIN PASSCODE',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        color: _grey,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: passcodeCtrl,
                      obscureText: obscurePasscode,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: _textDark,
                          letterSpacing: 2),
                      decoration: InputDecoration(
                        hintText: 'Enter 4-digit passcode',
                        hintStyle: GoogleFonts.inter(
                            fontSize: 12, color: _grey, letterSpacing: 0),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePasscode
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            size: 18,
                            color: _grey,
                          ),
                          onPressed: () {
                            setDlgState(() {
                              obscurePasscode = !obscurePasscode;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _border),
                        ),
                        errorText: errorMsg,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _grey,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _red,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: (isLoading || selectedIndices.isEmpty)
                    ? null
                    : () async {
                        final passcode = passcodeCtrl.text.trim();
                        final reason = reasonCtrl.text.trim();
                        final cashier = cashierCtrl.text.trim();
                        if (passcode.isEmpty) {
                          setDlgState(() =>
                              errorMsg = 'Please enter Admin passcode');
                          return;
                        }
                        setDlgState(() {
                          isLoading = true;
                          errorMsg = null;
                        });

                        final isValidPasscode = await RefundService()
                            .verifyAdminPasscode(passcode);
                        if (!isValidPasscode) {
                          setDlgState(() {
                            isLoading = false;
                            errorMsg =
                                'Invalid passcode. Default is 1234.';
                          });
                          return;
                        }

                        final selectedItems = selectedIndices
                            .map((i) => localItems[i])
                            .toList();

                        final result = await RefundService()
                            .processImmediatePOSRefund(
                          orderId: orderId,
                          transactionId: transactionId,
                          customerName:
                              order['customer_name'] ?? 'Walk-in Customer',
                          refundedItems: selectedItems,
                          refundAmount: currentRefundTotal,
                          originalAmount: totalAmount,
                          reason:
                              reason.isEmpty ? 'POS Item Refund' : reason,
                          staffEmail: Supabase
                                  .instance.client.auth.currentUser?.email ??
                              'staffycp@gmail.com',
                          staffName:
                              cashier.isNotEmpty ? cashier : null,
                        );

                        if (ctx.mounted) Navigator.pop(ctx);

                        if (result['success'] == true ||
                            result['id'] != null) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded,
                                        color: Colors.white, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'POS cash refund processed successfully! (₱${_fmt.format(currentRefundTotal)})',
                                        style: GoogleFonts.inter(fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: const Color(0xFF166534),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  result['error']?.toString() ??
                                      'Failed to process refund.',
                                  style: GoogleFonts.inter(fontSize: 13),
                                ),
                                backgroundColor: _red,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          }
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        selectedIndices.length == localItems.length
                            ? 'Confirm Full Refund (₱${_fmt.format(currentRefundTotal)})'
                            : 'Confirm Refund (${selectedIndices.length} items • ₱${_fmt.format(currentRefundTotal)})',
                        style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  static Widget _buildStatusBadge(bool isFullRefund, bool isPartialRefund) {
    Color bg;
    Color borderCol;
    Color textColor;
    String label;
    IconData icon;

    if (isFullRefund) {
      bg = const Color(0xFFFEF2F2);
      borderCol = const Color(0xFFFCA5A5);
      textColor = const Color(0xFF991B1B);
      label = 'Refunded';
      icon = Icons.assignment_return_rounded;
    } else if (isPartialRefund) {
      bg = const Color(0xFFFFFBEB);
      borderCol = const Color(0xFFFDE68A);
      textColor = const Color(0xFF92400E);
      label = 'Partially Refunded';
      icon = Icons.sync_rounded;
    } else {
      bg = const Color(0xFFF0FDF4);
      borderCol = const Color(0xFF86EFAC);
      textColor = const Color(0xFF166534);
      label = 'Paid';
      icon = Icons.check_circle_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Single Order Table Row ───────────────────────────────────────────────────
class _OrderTableRow extends StatefulWidget {
  final Map<String, dynamic> order;
  final NumberFormat fmt;
  final String Function(String?) formatTs;
  final VoidCallback onViewDetails;
  final VoidCallback onRefund;

  const _OrderTableRow({
    super.key,
    required this.order,
    required this.fmt,
    required this.formatTs,
    required this.onViewDetails,
    required this.onRefund,
  });

  @override
  State<_OrderTableRow> createState() => _OrderTableRowState();
}

class _OrderTableRowState extends State<_OrderTableRow> {
  bool _isHovered = false;
  static const _textDark = Color(0xFF0F172A);
  static const _grey = Color(0xFF64748B);
  static const _primaryDark = Color(0xFF0C241F);
  static const _red = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final tid = o['transaction_id']?.toString();
    final dbid = o['id']?.toString() ?? '';
    final orderId =
        tid ?? (int.tryParse(dbid) != null ? dbid.padLeft(3, '0') : dbid);

    final rawName = o['customer_name']?.toString().trim();
    final customerName = (rawName != null &&
            rawName.isNotEmpty &&
            rawName.toLowerCase() != 'guest' &&
            rawName.toLowerCase() != 'walk-in customer' &&
            rawName.toLowerCase() != 'walk-in')
        ? rawName
        : 'Walk-in';

    final total = (o['total_amount'] as num?)?.toDouble() ?? 0.0;
    final itemCount = (o['item_count'] as num?)?.toInt() ?? 0;
    final refundStatus = o['refund_status']?.toString();
    final isFullRefund = refundStatus == 'full_refund';
    final isPartialRefund = refundStatus == 'partial_refund';
    final ts = widget.formatTs(o['created_at']?.toString());

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onViewDetails,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: _isHovered
              ? const Color(0xFFF1F5F9).withValues(alpha: 0.6)
              : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // ORDER # & Type
              SizedBox(
                width: 120,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isFullRefund
                            ? Colors.red.shade50
                            : _primaryDark.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isFullRefund
                            ? Icons.receipt_rounded
                            : Icons.point_of_sale_rounded,
                        size: 14,
                        color: isFullRefund ? _red : _primaryDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '#$orderId',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: _textDark,
                            ),
                          ),
                          Text(
                            o['order_type'] ?? 'POS',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // DATE & TIME
              SizedBox(
                width: 170,
                child: Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 13, color: _grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        ts,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _textDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // CUSTOMER
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Center(
                        child: Text(
                          customerName.isNotEmpty
                              ? customerName[0].toUpperCase()
                              : 'W',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _textDark,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        customerName,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // ITEMS
              SizedBox(
                width: 90,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$itemCount item${itemCount != 1 ? 's' : ''}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ),
              ),

              // TOTAL AMOUNT
              SizedBox(
                width: 130,
                child: Text(
                  '₱ ${widget.fmt.format(total)}',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isFullRefund ? _grey : _textDark,
                  ),
                ),
              ),

              // STATUS BADGE
              SizedBox(
                width: 140,
                child: Center(
                  child: _StaffOrderHistoryPageState._buildStatusBadge(
                      isFullRefund, isPartialRefund),
                ),
              ),

              // ACTIONS
              SizedBox(
                width: 190,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // View details button
                    OutlinedButton.icon(
                      icon: const Icon(Icons.receipt_long_rounded,
                          size: 13, color: _primaryDark),
                      label: Text(
                        'Details',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _primaryDark,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: widget.onViewDetails,
                    ),
                    const SizedBox(width: 8),

                    // Refund button
                    if (!isFullRefund)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _red,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: widget.onRefund,
                        child: Text(
                          'Refund',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 55),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}