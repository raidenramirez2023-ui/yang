import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StaffOrderHistoryPage extends StatefulWidget {
  const StaffOrderHistoryPage({super.key});

  @override
  State<StaffOrderHistoryPage> createState() => _StaffOrderHistoryPageState();
}

class _StaffOrderHistoryPageState extends State<StaffOrderHistoryPage> {
  // ── Design tokens (Dynamic) ────────────────────────────────────────────────
  Color get _red => const Color(0xFFDC2626);
  Color get _bg => Theme.of(context).scaffoldBackgroundColor;
  Color get _cardBg => Theme.of(context).cardColor;
  Color get _border => Theme.of(context).dividerColor;
  Color get _grey => Theme.of(context).hintColor;
  Color get _textDark => Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF1A1A2E);

  final _supabase = Supabase.instance.client;
  final _fmt = NumberFormat('#,##0.00', 'en_US');

  String _searchQuery = '';
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Today', 'This Week'];
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Fetch orders with items joined ─────────────────────────────────────────
  Future<List<Map<String, dynamic>>> _fetchOrders() async {
    final res = await _supabase
        .from('orders')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
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
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        surfaceTintColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0.5,
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
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
      color: _cardBg,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        style: TextStyle(fontSize: 13, color: _textDark),
        decoration: InputDecoration(
          hintText: 'Search by customer or order #…',
          hintStyle: TextStyle(color: _grey, fontSize: 13),
          prefixIcon: Icon(Icons.search, color: _grey, size: 18),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: _grey, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: _bg,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: _red, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      color: _cardBg,
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
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchOrders(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
              child: CircularProgressIndicator(color: _red));
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: _red, size: 48),
                  const SizedBox(height: 16),
                  Text('Fetch Error: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _red)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
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
                Text(
                  'No orders found',
                  style: TextStyle(
                    color: _grey,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
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
  Color get _red => const Color(0xFFDC2626);
  Color get _bg => Theme.of(context).scaffoldBackgroundColor;
  Color get _cardBg => Theme.of(context).cardColor;
  Color get _border => Theme.of(context).dividerColor;
  Color get _grey => Theme.of(context).hintColor;
  Color get _textDark => Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF1A1A2E);

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

    // EXACT MATCH with ReceiptTemplate in shared_pos_widget.dart
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final year = dt.year;
    final formattedDate = '$month/$day/$year';

    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final formattedTime = '$displayHour:$minute$period';

    return '$formattedDate    $formattedTime';
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final total = (o['total_amount'] as num?)?.toDouble() ?? 0.0;
    final customer = (o['customer_name'] ?? 'Guest').toString();
    final transactionId = (o['transaction_id'] ?? '').toString();
    final shortId =
        transactionId.length >= 3 ? transactionId.substring(0, 3) : transactionId;
    final ts = _formatTs(o['created_at']?.toString());
    final itemCount = (o['item_count'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardBg,
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
          // ── Header row (Matching ReceiptTemplate Style) ───────────────────
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() => _expanded = !_expanded);
              if (_expanded) _loadItems();
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                children: [
                  // Row 1: Order Number & Total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text('ORDER: ',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: _textDark)),
                          Text('#$shortId',
                              style: TextStyle(
                                  fontSize: 13, color: _textDark)),
                        ],
                      ),
                      Text(
                        '₱ ${widget.fmt.format(total)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Row 2: Host & Date/Time
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('HOST: $customer',
                          style: TextStyle(fontSize: 11, color: _grey)),
                      Text(ts,
                          style: TextStyle(fontSize: 11, color: _grey)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (itemCount > 0)
                        Text('$itemCount item${itemCount != 1 ? 's' : ''}',
                            style: TextStyle(fontSize: 11, color: _grey))
                      else
                        const SizedBox.shrink(),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        color: _grey,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded items ────────────────────────────────────────────────
          if (_expanded)
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: _border)),
              ),
              child: _loadingItems
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                          child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: _red, strokeWidth: 2),
                      )),
                    )
                  : _items == null || _items!.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16),
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
                                children: [
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
                              Divider(
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
                                            style: TextStyle(
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
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: _grey)),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                            '₱ ${widget.fmt.format(sub)}',
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: _textDark,
                                                fontWeight:
                                                    FontWeight.w500)),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              Divider(color: _border, height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Total',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: _textDark)),
                                  Text(
                                      '₱ ${widget.fmt.format(total)}',
                                      style: TextStyle(
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
