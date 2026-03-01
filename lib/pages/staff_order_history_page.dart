import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StaffOrderHistoryPage extends StatefulWidget {
  const StaffOrderHistoryPage({super.key});

  @override
  State<StaffOrderHistoryPage> createState() => _StaffOrderHistoryPageState();
}

class _StaffOrderHistoryPageState extends State<StaffOrderHistoryPage> {
  // ── Design tokens ──────────────────────────────────────────────────────────
  static const _red = Color(0xFFDC2626);
  static const _bg = Color(0xFFF5F6FA);
  static const _border = Color(0xFFE5E7EB);
  static const _grey = Color(0xFF6B7280);
  static const _textDark = Color(0xFF1A1A2E);

  final _supabase = Supabase.instance.client;
  final _fmt = NumberFormat('#,##0.00', 'en_US');

  String _searchQuery = '';
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Today', 'This Week'];

  // ── Fetch orders with items joined ─────────────────────────────────────────
  Stream<List<Map<String, dynamic>>> _ordersStream() {
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  Future<List<Map<String, dynamic>>> _fetchItems(String orderId) async {
    final res = await _supabase
        .from('order_items')
        .select()
        .eq('order_id', orderId)
        .order('id');
    return List<Map<String, dynamic>>.from(res);
  }

  // ── Filter helpers ─────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> orders) {
    final now = DateTime.now();
    return orders.where((o) {
      // Date filter
      final createdAt = DateTime.tryParse(o['created_at']?.toString() ?? '');
      if (createdAt == null) return false;

      if (_selectedFilter == 'Today') {
        if (createdAt.year != now.year ||
            createdAt.month != now.month ||
            createdAt.day != now.day) return false;
      } else if (_selectedFilter == 'This Week') {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        if (createdAt.isBefore(start)) return false;
      }

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final customer = (o['customer_name'] ?? '').toString().toLowerCase();
        final transactionId = (o['transaction_id'] ?? '').toString().toLowerCase();
        final q = _searchQuery.toLowerCase();
        
        // Use startsWith for transaction ID to match user request
        final idMatch = transactionId.startsWith(q);
        final nameMatch = customer.contains(q);
        
        if (!idMatch && !nameMatch) return false;
      }
      return true;
    }).toList();
  }

  // ── Widgets ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Order History',
          style: TextStyle(
            color: _textDark,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterChips(),
          Expanded(child: _buildOrderList()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        style: const TextStyle(fontSize: 13, color: _textDark),
        decoration: InputDecoration(
          hintText: 'Search by customer or order #…',
          hintStyle: const TextStyle(color: _grey, fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: _grey, size: 18),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: _grey, size: 18),
                  onPressed: () => setState(() => _searchQuery = ''),
                )
              : null,
          filled: true,
          fillColor: _bg,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _red, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: _filters.map((f) {
          final selected = _selectedFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f,
                  style: TextStyle(
                    fontSize: 12,
                    color: selected ? Colors.white : _grey,
                    fontWeight: FontWeight.w500,
                  )),
              selected: selected,
              selectedColor: _red,
              backgroundColor: _bg,
              side: BorderSide(color: selected ? _red : _border),
              onSelected: (_) => setState(() => _selectedFilter = f),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOrderList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _ordersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _red));
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}',
                style: const TextStyle(color: _red)),
          );
        }

        final all = snapshot.data ?? [];
        final filtered = _applyFilters(all);

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_outlined,
                    size: 64, color: _grey.withOpacity(0.4)),
                const SizedBox(height: 16),
                const Text(
                  'No orders found',
                  style: TextStyle(
                    color: _grey,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Completed orders will appear here.',
                  style: TextStyle(color: _grey, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (context, index) =>
              _OrderCard(order: filtered[index], fmt: _fmt),
        );
      },
    );
  }
}

// ── Single order card ───────────────────────────────────────────────────────
class _OrderCard extends StatefulWidget {
  final Map<String, dynamic> order;
  final NumberFormat fmt;

  const _OrderCard({required this.order, required this.fmt});

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  static const _red = Color(0xFFDC2626);
  static const _bg = Color(0xFFF5F6FA);
  static const _border = Color(0xFFE5E7EB);
  static const _grey = Color(0xFF6B7280);
  static const _textDark = Color(0xFF1A1A2E);

  bool _expanded = false;
  List<Map<String, dynamic>>? _items;
  bool _loadingItems = false;

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
    // Format: MM/dd/yyyy    h:mm a (matching ReceiptTemplate in shared_pos_widget.dart)
    final date = DateFormat('MM/dd/yyyy').format(dt);
    final time = DateFormat('h:mm a').format(dt);
    return '$date    $time';
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final total = (o['total_amount'] as num?)?.toDouble() ?? 0.0;
    final customer = (o['customer_name'] ?? 'Guest').toString();
    final transactionId = (o['transaction_id'] ?? '').toString();
    final shortId = transactionId.length >= 3 ? transactionId.substring(0, 3) : transactionId;
    final ts = _formatTs(o['created_at']?.toString());
    final itemCount = (o['item_count'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header row ────────────────────────────────────────────────────
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() => _expanded = !_expanded);
              if (_expanded) _loadItems();
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  // Order icon
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_long,
                        color: _red, size: 20),
                  ),
                  const SizedBox(width: 12),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '#$shortId',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _textDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              customer,
                              style: const TextStyle(
                                  fontSize: 13, color: _grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(ts,
                            style: const TextStyle(
                                fontSize: 11, color: _grey)),
                        if (itemCount > 0)
                          Text('$itemCount item${itemCount != 1 ? 's' : ''}',
                              style: const TextStyle(
                                  fontSize: 11, color: _grey)),
                      ],
                    ),
                  ),
                  // Total
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₱ ${widget.fmt.format(total)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: Colors.green.shade200),
                        ),
                        child: Text('Paid',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: _grey,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded items ────────────────────────────────────────────────
          if (_expanded)
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _border)),
              ),
              child: _loadingItems
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                          child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: _red, strokeWidth: 2),
                      )),
                    )
                  : _items == null || _items!.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No item details found.',
                              style:
                                  TextStyle(color: _grey, fontSize: 13)),
                        )
                      : Padding(
                          padding:
                              const EdgeInsets.fromLTRB(16, 12, 16, 14),
                          child: Column(
                            children: [
                              // Column headers
                              Row(
                                children: const [
                                  Expanded(
                                    flex: 5,
                                    child: Text('Item',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: _grey)),
                                  ),
                                  SizedBox(
                                    width: 36,
                                    child: Text('Qty',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: _grey)),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text('Price',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: _grey)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Divider(
                                  color: _border, height: 1),
                              const SizedBox(height: 8),
                              ..._items!.map((it) {
                                final name = it['item_name'] ?? '—';
                                final qty =
                                    (it['quantity'] as num?)?.toInt() ??
                                        1;
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
                                        child: Text(name,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                color: _textDark),
                                            maxLines: 2,
                                            overflow:
                                                TextOverflow.ellipsis),
                                      ),
                                      SizedBox(
                                        width: 36,
                                        child: Text('×$qty',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                color: _grey)),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                            '₱ ${widget.fmt.format(sub)}',
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                color: _textDark,
                                                fontWeight:
                                                    FontWeight.w500)),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              const Divider(color: _border, height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: _textDark)),
                                  Text(
                                      '₱ ${widget.fmt.format(total)}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: _textDark)),
                                ],
                              ),
                            ],
                          ),
                        ),
            ),
        ],
      ),
    );
  }
}
