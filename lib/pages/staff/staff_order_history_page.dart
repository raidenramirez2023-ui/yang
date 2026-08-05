import 'package:flutter/material.dart';
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
  static const _red = Color(0xFFDC2626);
  static const _bg = Color(0xFFF5F6FA);
  static const _border = Color(0xFFE5E7EB);
  static const _grey = Color(0xFF6B7280);
  static const _textDark = Color(0xFF1A1A2E);

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
            createdAt.day != now.day) { return false; }
      } else if (_selectedFilter == 'This Week') {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        if (createdAt.isBefore(start)) return false;
      }

      if (_searchQuery.isNotEmpty) {
        // Exact match on the order number (transaction_id or padded db id)
        final tid = (o['transaction_id'] ?? '').toString();
        final dbid = (o['id'] ?? '').toString();
        final orderId = tid.isNotEmpty
            ? tid
            : (int.tryParse(dbid) != null ? dbid.padLeft(3, '0') : dbid);
        if (!orderId.contains(_searchQuery.trim())) return false;
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
        controller: _searchController,
        keyboardType: TextInputType.number,
        onChanged: (v) => setState(() => _searchQuery = v.trim()),
        style: const TextStyle(fontSize: 13, color: _textDark),
        decoration: InputDecoration(
          hintText: 'Search by order number…',
          hintStyle: const TextStyle(color: _grey, fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: _grey, size: 18),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: _grey, size: 18),
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
    return DateFormat('MMM d, yyyy  h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final total = (o['total_amount'] as num?)?.toDouble() ?? 0.0;
    final tid = o['transaction_id']?.toString();
    final dbid = o['id']?.toString() ?? '';
    final orderId = tid ?? (int.tryParse(dbid) != null ? dbid.padLeft(3, '0') : dbid);
    final shortId = orderId;
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
                    child: const Icon(Icons.receipt_long, color: _red, size: 20),
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
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(ts,
                            style: const TextStyle(fontSize: 11, color: _grey)),
                        if (itemCount > 0)
                          Text('$itemCount item${itemCount != 1 ? 's' : ''}',
                              style: const TextStyle(fontSize: 11, color: _grey)),
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
                          color: (o['refund_status'] == 'full_refund')
                              ? Colors.red.shade50
                              : (o['refund_status'] == 'partial_refund')
                                  ? Colors.orange.shade50
                                  : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: (o['refund_status'] == 'full_refund')
                                ? Colors.red.shade200
                                : (o['refund_status'] == 'partial_refund')
                                    ? Colors.orange.shade200
                                    : Colors.green.shade200,
                          ),
                        ),
                        child: Text(
                          (o['refund_status'] == 'full_refund')
                              ? 'Refunded'
                              : (o['refund_status'] == 'partial_refund')
                                  ? 'Partially Refunded'
                                  : 'Paid',
                          style: TextStyle(
                            fontSize: 10,
                            color: (o['refund_status'] == 'full_refund')
                                ? Colors.red.shade700
                                : (o['refund_status'] == 'partial_refund')
                                    ? Colors.orange.shade700
                                    : Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
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
                        ),
                      ),
                    )
                  : _items == null || _items!.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No item details found.',
                              style: TextStyle(color: _grey, fontSize: 13)),
                        )
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                          child: Column(
                            children: [
                              // Column headers
                              const Row(
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
                              const Divider(color: _border, height: 1),
                              const SizedBox(height: 8),
                              ..._items!.map((it) {
                                final name = it['item_name'] ?? '—';
                                final qty =
                                    (it['quantity'] as num?)?.toInt() ?? 1;
                                final price =
                                    (it['unit_price'] as num?)?.toDouble() ?? 0.0;
                                final sub = price * qty;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 5,
                                        child: Text(name,
                                            style: const TextStyle(
                                                fontSize: 13, color: _textDark),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                      SizedBox(
                                        width: 36,
                                        child: Text('×$qty',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                fontSize: 13, color: _grey)),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                            '₱ ${widget.fmt.format(sub)}',
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                color: _textDark,
                                                fontWeight: FontWeight.w500)),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              if (o['note'] != null && o['note'].toString().isNotEmpty) ...[
                                const Divider(color: _border, height: 24),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Note: ',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: _grey)),
                                    Expanded(
                                      child: Text(o['note'].toString(),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: _textDark,
                                              fontStyle: FontStyle.italic)),
                                    ),
                                  ],
                                ),
                              ],
                              const Divider(color: _border, height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Subtotal',
                                      style: TextStyle(
                                          fontSize: 13, color: _grey)),
                                  Text(
                                      '₱ ${widget.fmt.format(total)}',
                                      style: const TextStyle(
                                          fontSize: 13, color: _textDark)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                      'Paid with ${o['payment_method'] ?? 'Cash'}',
                                      style: const TextStyle(
                                          fontSize: 13, color: _grey)),
                                  Text(
                                      '₱ ${widget.fmt.format((o['amount_paid'] as num?)?.toDouble() ?? total)}',
                                      style: const TextStyle(
                                          fontSize: 13, color: _textDark)),
                                ],
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Change Due',
                                      style: TextStyle(
                                          fontSize: 13, color: _grey)),
                                  Text(
                                      '₱ ${widget.fmt.format((o['change_due'] as num?)?.toDouble() ?? 0.0)}',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.green,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                              const Divider(color: _border, height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total Amount',
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

                              // ── Refund Action Button (Same-Day POS Orders) ─────
                              if (o['refund_status'] != 'full_refund') ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _showPosRefundDialog(context),
                                    icon: const Icon(Icons.assignment_return_rounded, size: 16, color: _red),
                                    label: const Text(
                                      'Process Cash Refund',
                                      style: TextStyle(color: _red, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: _red),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
            ),
        ],
      ),
    );
  }

  void _showPosRefundDialog(BuildContext context) {
    final passcodeCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    bool isLoading = false;
    String? errorMsg;

    final o = widget.order;
    final orderId = o['id'].toString();
    final transactionId = o['transaction_id']?.toString() ?? orderId;
    final totalAmount = (o['total_amount'] as num?)?.toDouble() ?? 0.0;

    List<Map<String, dynamic>> localItems = List<Map<String, dynamic>>.from(_items ?? []);
    bool fetchingItems = _items == null;
    Set<int> selectedIndices = {};

    if (!fetchingItems) {
      selectedIndices = Set.from(List.generate(localItems.length, (i) => i));
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          // Fetch items if not already cached in state
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
                  selectedIndices = Set.from(List.generate(localItems.length, (i) => i));
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

          // Calculate current refund total based on selected items
          final currentRefundTotal = selectedIndices.fold<double>(0.0, (sum, i) {
            if (i < localItems.length) {
              final it = localItems[i];
              final qty = (it['quantity'] as num?)?.toInt() ?? 1;
              final price = (it['unit_price'] as num?)?.toDouble() ?? 0.0;
              return sum + (price * qty);
            }
            return sum;
          });

          final allSelected = localItems.isNotEmpty && selectedIndices.length == localItems.length;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.assignment_return_rounded, color: _red),
                SizedBox(width: 8),
                Text('Process POS Cash Refund', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order #${widget.order['transaction_id'] ?? widget.order['id']}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 12),

                    // ── Items Selection List ──
                    const Text('Select Items to Refund:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _textDark)),
                    const SizedBox(height: 6),
                    if (fetchingItems)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: CircularProgressIndicator(color: _red, strokeWidth: 2),
                        ),
                      )
                    else if (localItems.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Text('No order items found.', style: TextStyle(color: _grey, fontSize: 12)),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: _border),
                          borderRadius: BorderRadius.circular(8),
                          color: const Color(0xFFF9FAFB),
                        ),
                        child: Column(
                          children: [
                            // Select All Header
                            InkWell(
                              onTap: () {
                                setDlgState(() {
                                  if (allSelected) {
                                    selectedIndices.clear();
                                  } else {
                                    selectedIndices = Set.from(List.generate(localItems.length, (i) => i));
                                  }
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: allSelected,
                                      activeColor: _red,
                                      onChanged: (val) {
                                        setDlgState(() {
                                          if (val == true) {
                                            selectedIndices = Set.from(List.generate(localItems.length, (i) => i));
                                          } else {
                                            selectedIndices.clear();
                                          }
                                        });
                                      },
                                    ),
                                    const Text('Select All Items',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textDark)),
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
                              final qty = (it['quantity'] as num?)?.toInt() ?? 1;
                              final price = (it['unit_price'] as num?)?.toDouble() ?? 0.0;
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
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        value: isChecked,
                                        activeColor: _red,
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
                                        child: Text('$name ×$qty',
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: isChecked ? FontWeight.w600 : FontWeight.normal,
                                                color: _textDark)),
                                      ),
                                      Text('₱ ${widget.fmt.format(itemSubtotal)}',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                                              color: isChecked ? _red : _grey)),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Refund Amount:',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        Text('₱ ${widget.fmt.format(currentRefundTotal)}',
                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: reasonCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Refund Reason',
                        hintText: 'e.g. Item unavailable, customer cancelled',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passcodeCtrl,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Admin Passcode',
                        hintText: 'Enter 4-digit passcode',
                        border: const OutlineInputBorder(),
                        errorText: errorMsg,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _red,
                  foregroundColor: Colors.white,
                ),
                onPressed: (isLoading || selectedIndices.isEmpty)
                    ? null
                    : () async {
                        final passcode = passcodeCtrl.text.trim();
                        final reason = reasonCtrl.text.trim();
                        if (passcode.isEmpty) {
                          setDlgState(() => errorMsg = 'Please enter Admin passcode');
                          return;
                        }
                        setDlgState(() {
                          isLoading = true;
                          errorMsg = null;
                        });

                        final isValidPasscode = await RefundService().verifyAdminPasscode(passcode);
                        if (!isValidPasscode) {
                          setDlgState(() {
                            isLoading = false;
                            errorMsg = 'Invalid passcode. Default is 1234.';
                          });
                          return;
                        }

                        final selectedItems = selectedIndices.map((i) => localItems[i]).toList();

                        final result = await RefundService().processImmediatePOSRefund(
                          orderId: orderId,
                          transactionId: transactionId,
                          customerName: o['customer_name'] ?? 'Walk-in Customer',
                          refundedItems: selectedItems,
                          refundAmount: currentRefundTotal,
                          originalAmount: totalAmount,
                          reason: reason.isEmpty ? 'POS Item Refund' : reason,
                          staffEmail: Supabase.instance.client.auth.currentUser?.email ?? 'staff@yangchow.com',
                        );

                        if (ctx.mounted) Navigator.pop(ctx);

                        if (result['success'] == true || result['id'] != null) {
                          if (mounted) {
                            final isFullRefund = currentRefundTotal >= totalAmount;
                            setState(() {
                              widget.order['refund_status'] = isFullRefund ? 'full_refund' : 'partial_refund';
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('POS refund processed successfully! (₱${widget.fmt.format(currentRefundTotal)})'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(result['error']?.toString() ?? 'Failed to process refund.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(selectedIndices.length == localItems.length
                        ? 'Confirm Refund (Full)'
                        : 'Confirm Refund (${selectedIndices.length} Item${selectedIndices.length > 1 ? 's' : ''})'),
              ),
            ],
          );
        },
      ),
    );
  }
}