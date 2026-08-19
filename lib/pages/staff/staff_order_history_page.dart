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

  // ── Fetch orders with items joined ─────────────────────────────────────────
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
            final amt = (o['total_amount'] as num?)?.toDouble() ?? 0.0;
            totalRevenue += amt;
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
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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

              // Orders List
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) => _OrderCard(
                          order: filtered[index],
                          fmt: _fmt,
                        ),
                      ),
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
}

// ── Single Order Card (Realistic Digital Receipt) ─────────────────────────────
class _OrderCard extends StatefulWidget {
  final Map<String, dynamic> order;
  final NumberFormat fmt;

  const _OrderCard({required this.order, required this.fmt});

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  static const _primaryDark = Color(0xFF0C241F);
  static const _red = Color(0xFFDC2626);
  static const _border = Color(0xFFE2E8F0);
  static const _grey = Color(0xFF64748B);
  static const _textDark = Color(0xFF0F172A);

  List<Map<String, dynamic>>? _items;
  bool _loadingItems = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    if (_items != null) return;
    setState(() => _loadingItems = true);
    try {
      final res = await Supabase.instance.client
          .from('order_items')
          .select()
          .eq('order_id', widget.order['id'].toString())
          .order('id');
      if (mounted) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(res);
          _loadingItems = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingItems = false);
    }
  }

  String _formatTs(String? raw) {
    if (raw == null) return '—';
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return raw;
    return DateFormat('MMM d, yyyy • h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final total = (o['total_amount'] as num?)?.toDouble() ?? 0.0;
    final tid = o['transaction_id']?.toString();
    final dbid = o['id']?.toString() ?? '';
    final orderId =
        tid ?? (int.tryParse(dbid) != null ? dbid.padLeft(3, '0') : dbid);
    final shortId = orderId;
    final ts = _formatTs(o['created_at']?.toString());
    final itemCount = (o['item_count'] as num?)?.toInt() ?? 0;
    final refundStatus = o['refund_status']?.toString();
    final isFullRefund = refundStatus == 'full_refund';
    final isPartialRefund = refundStatus == 'partial_refund';
    final rawName = o['customer_name']?.toString().trim();
    final customerName = (rawName != null &&
            rawName.isNotEmpty &&
            rawName.toLowerCase() != 'guest' &&
            rawName.toLowerCase() != 'walk-in customer' &&
            rawName.toLowerCase() != 'walk-in')
        ? rawName
        : (rawName != null && rawName.isNotEmpty && rawName != 'Guest' ? rawName : null);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Row ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                // Receipt Icon Container
                Container(
                  width: 42,
                  height: 42,
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
                  child: Center(
                    child: Icon(
                      isFullRefund
                          ? Icons.receipt_rounded
                          : Icons.point_of_sale_rounded,
                      color: isFullRefund ? _red : _primaryDark,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Order Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '#$shortId',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: _textDark,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (customerName != null) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '• $customerName',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _primaryDark,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              o['order_type'] ?? 'POS',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded,
                              size: 12, color: _grey),
                          const SizedBox(width: 4),
                          Text(
                            ts,
                            style: GoogleFonts.inter(
                                fontSize: 11, color: _grey),
                          ),
                          if (itemCount > 0) ...[
                            const SizedBox(width: 8),
                            Text('•',
                                style: GoogleFonts.inter(
                                    fontSize: 11, color: _grey)),
                            const SizedBox(width: 8),
                            Text(
                              '$itemCount item${itemCount != 1 ? 's' : ''}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: _grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Total & Status Badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₱ ${widget.fmt.format(total)}',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isFullRefund ? _grey : _textDark,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildStatusBadge(isFullRefund, isPartialRefund),
                  ],
                ),
              ],
            ),
          ),

          // ── Visible Itemized Breakdown Section ───────────────────────────
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFFBFBFB),
              border: Border(
                top: BorderSide(color: _border),
                bottom: BorderSide(color: _border),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: _loadingItems
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: _primaryDark,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  )
                : _items == null || _items!.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No item details available.',
                          style: GoogleFonts.inter(color: _grey, fontSize: 12),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Column Headers
                          Row(
                            children: [
                              Expanded(
                                flex: 5,
                                child: Text(
                                  'ITEM',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: _grey,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 36,
                                child: Text(
                                  'QTY',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: _grey,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'PRICE',
                                  textAlign: TextAlign.right,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: _grey,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Scrollable Items List
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 140),
                            child: Scrollbar(
                              thumbVisibility: (_items?.length ?? 0) > 3,
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: Column(
                                  children: [
                                    ..._items!.map((it) {
                                      final name = it['item_name'] ?? '—';
                                      final qty =
                                          (it['quantity'] as num?)?.toInt() ?? 1;
                                      final price =
                                          (it['unit_price'] as num?)
                                                  ?.toDouble() ??
                                              0.0;
                                      final sub = price * qty;

                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 6),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 5,
                                              child: Text(
                                                name,
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: _textDark,
                                                ),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 36,
                                              child: Center(
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 5,
                                                          vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFFF1F5F9),
                                                    borderRadius:
                                                        BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    '×$qty',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: const Color(
                                                          0xFF475569),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                '₱ ${widget.fmt.format(sub)}',
                                                textAlign: TextAlign.right,
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
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
                            ),
                          ),

                          // Note if any
                          if (o['note'] != null &&
                              o['note'].toString().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEFCE8),
                                borderRadius: BorderRadius.circular(6),
                                border:
                                    Border.all(color: const Color(0xFFFEF08A)),
                              ),
                              child: Text(
                                'Note: ${o['note']}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xFF854D0E),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
          ),

          // ── Payment Summary & Action Footer ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Payment breakdown
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.payments_outlined,
                              size: 13, color: _grey),
                          const SizedBox(width: 4),
                          Text(
                            'Paid: ₱ ${widget.fmt.format((o['amount_paid'] as num?)?.toDouble() ?? total)}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: _grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if ((o['change_due'] as num?) != null &&
                              (o['change_due'] as num) > 0) ...[
                            const SizedBox(width: 8),
                            Text('•',
                                style: GoogleFonts.inter(
                                    fontSize: 11, color: _grey)),
                            const SizedBox(width: 8),
                            Text(
                              'Change: ₱ ${widget.fmt.format((o['change_due'] as num).toDouble())}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF166534),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Refund button
                if (!isFullRefund)
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _showPosRefundDialog(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _red,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: _red.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.assignment_return_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Process Refund',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.1,
                            ),
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

  Widget _buildStatusBadge(bool isFullRefund, bool isPartialRefund) {
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

  void _showPosRefundDialog(BuildContext context) {
    final passcodeCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final currentUser = Supabase.instance.client.auth.currentUser;
    String initialCashierName = currentUser?.userMetadata?['full_name']?.toString() ??
        currentUser?.userMetadata?['name']?.toString() ??
        currentUser?.email?.split('@').first ??
        'Cashier Staff';
    final cashierCtrl = TextEditingController(text: initialCashierName);
    bool isLoading = false;
    String? errorMsg;
    bool obscurePasscode = true;

    final o = widget.order;
    final orderId = o['id'].toString();
    final transactionId = o['transaction_id']?.toString() ?? orderId;
    final totalAmount = (o['total_amount'] as num?)?.toDouble() ?? 0.0;

    List<Map<String, dynamic>> localItems =
        List<Map<String, dynamic>>.from(_items ?? []);
    bool fetchingItems = _items == null;
    Set<int> selectedIndices = {};

    if (!fetchingItems) {
      selectedIndices = Set.from(List.generate(localItems.length, (i) => i));
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          if (fetchingItems) {
            Supabase.instance.client
                .from('order_items')
                .select()
                .eq('order_id', orderId)
                .order('id')
                .then((res) {
              if (ctx.mounted) {
                setDlgState(() {
                  localItems = List<Map<String, dynamic>>.from(res);
                  _items = localItems;
                  fetchingItems = false;
                  selectedIndices =
                      Set.from(List.generate(localItems.length, (i) => i));
                });
              }
            }).catchError((err) {
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
                                    selectedIndices = Set.from(
                                        List.generate(
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
                                        '₱ ${widget.fmt.format(itemSubtotal)}',
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
                            '₱ ${widget.fmt.format(currentRefundTotal)}',
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
                      style: GoogleFonts.inter(fontSize: 13, color: _textDark, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Cashier name',
                        prefixIcon: const Icon(Icons.person_outline, size: 18, color: _grey),
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
                      style: GoogleFonts.inter(fontSize: 13, color: _textDark),
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
                            errorMsg = 'Invalid passcode. Default is 1234.';
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
                              o['customer_name'] ?? 'Walk-in Customer',
                          refundedItems: selectedItems,
                          refundAmount: currentRefundTotal,
                          originalAmount: totalAmount,
                          reason: reason.isEmpty ? 'POS Item Refund' : reason,
                          staffEmail: Supabase
                                  .instance.client.auth.currentUser?.email ??
                              'cashier.pos@yangchow.com',
                          staffName: cashier.isNotEmpty ? cashier : null,
                        );

                        if (ctx.mounted) Navigator.pop(ctx);

                        if (result['success'] == true ||
                            result['id'] != null) {
                          if (mounted) {
                            final isFullRefund =
                                currentRefundTotal >= totalAmount;
                            setState(() {
                              widget.order['refund_status'] = isFullRefund
                                  ? 'full_refund'
                                  : 'partial_refund';
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded,
                                        color: Colors.white, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'POS cash refund processed successfully! (₱${widget.fmt.format(currentRefundTotal)})',
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
                            ? 'Confirm Full Refund (₱${widget.fmt.format(currentRefundTotal)})'
                            : 'Confirm Refund (${selectedIndices.length} items • ₱${widget.fmt.format(currentRefundTotal)})',
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
}