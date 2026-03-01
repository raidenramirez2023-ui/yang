import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'shared_pos_widget.dart';

class OrderListPanel extends StatefulWidget {
  final List<CartItem> cart;
  final Function(CartItem) onQuantityIncreased;
  final Function(CartItem) onQuantityDecreased;
  final Function(CartItem) onRemoveItem;
  final Function(String customerName) onPrintReceipt;
  final bool isMobile;

  const OrderListPanel({
    super.key,
    required this.cart,
    required this.onQuantityIncreased,
    required this.onQuantityDecreased,
    required this.onRemoveItem,
    required this.onPrintReceipt,
    this.isMobile = false,
  });

  @override
  State<OrderListPanel> createState() => _OrderListPanelState();
}

class _OrderListPanelState extends State<OrderListPanel> {
  final TextEditingController _customerNameController =
      TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  final NumberFormat _fmt = NumberFormat('#,##0.00', 'en_US');

  // ── Design tokens (Dynamic) ────────────────────────────────────────────────
  Color get _indigo => Theme.of(context).brightness == Brightness.light ? const Color.fromARGB(255, 0, 0, 0) : Colors.white;
  Color get _bg => Theme.of(context).scaffoldBackgroundColor;
  Color get _cardBg => Theme.of(context).colorScheme.surface;
  Color get _border => Theme.of(context).dividerColor;
  Color get _grey => Theme.of(context).hintColor;
  Color get _textDark => Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF1A1A2E);

  @override
  void dispose() {
    _customerNameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double get _subtotal => widget.cart.fold(
      0.0, (sum, item) => sum + (item.item.price * item.quantity));

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.isMobile ? double.infinity : 310,
      color: _cardBg,
      child: Column(
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          _buildHeader(),
          // ── Scrollable body ────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 14),
                  // Customer name row
                  _buildCustomerRow(),
                  const SizedBox(height: 10),
                  // Note field
                  _buildNoteField(),
                  const SizedBox(height: 16),
                  // Items header
                  _buildItemsHeader(),
                  const SizedBox(height: 8),
                  // Cart items
                  if (widget.cart.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('No items added yet',
                            style: TextStyle(
                                color: _grey, fontSize: 13)),
                      ),
                    )
                  else
                    ...widget.cart.reversed.map(_buildCartItem),
                  const SizedBox(height: 16),
                  // Divider
                  Divider(color: _border, height: 1),
                  const SizedBox(height: 12),
                  // Totals
                  _buildTotals(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          // ── Footer buttons ─────────────────────────────────────────────────
          _buildFooter(),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Order Details',
            style: TextStyle(
              color: _textDark,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // ── Customer name row ──────────────────────────────────────────────────────
  Widget _buildCustomerRow() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 40,
            child: TextField(
              controller: _customerNameController,
              style:
                  TextStyle(fontSize: 13, color: _textDark),
              decoration: InputDecoration(
                hintText: "Customer's name",
                hintStyle:
                    TextStyle(color: _grey, fontSize: 13),
                filled: true,
                fillColor: _bg,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: _border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: _border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: _indigo, width: 1.5),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Note field ─────────────────────────────────────────────────────────────
  Widget _buildNoteField() {
    return SizedBox(
      height: 36,
      child: TextField(
        controller: _noteController,
        style: TextStyle(fontSize: 13, color: _textDark),
        decoration: InputDecoration(
          hintText: 'Note',
          hintStyle: TextStyle(color: _grey, fontSize: 13),
          filled: true,
          fillColor: _bg,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: _indigo, width: 1.5),
          ),
        ),
      ),
    );
  }

  // ── Items header ───────────────────────────────────────────────────────────
  Widget _buildItemsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Items',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: _textDark)),
        GestureDetector(
          onTap: widget.cart.isNotEmpty
              ? () {
                  for (var item in widget.cart.toList()) {
                    widget.onRemoveItem(item);
                  }
                }
              : null,
          child: Text(
            'Clear',
            style: TextStyle(
                color: widget.cart.isNotEmpty
                    ? _indigo
                    : _grey,
                fontSize: 13,
                fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  // ── Single cart item ───────────────────────────────────────────────────────
  Widget _buildCartItem(CartItem item) {
    final imagePath =
        item.item.customImagePath ?? item.item.fallbackImagePath;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset(
              imagePath,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 48,
                height: 48,
                  color: _bg,
                  child:
                      Icon(Icons.fastfood, color: _grey, size: 20),
                ),
            ),
          ),
          const SizedBox(width: 10),
          // Name + price + qty controls
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.item.name,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _textDark),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => widget.onRemoveItem(item),
                      child: Icon(Icons.close,
                          size: 14, color: _grey),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Price
                Text(
                  'P${_fmt.format(item.item.price)}',
                  style: TextStyle(
                    color: _indigo,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 6),
                // Qty controls + Edit
                Row(
                  children: [
                    // Decrease
                    _qtyButton(
                      icon: Icons.remove,
                      onTap: () => widget.onQuantityDecreased(item),
                    ),
                    SizedBox(
                      width: 28,
                      child: Center(
                        child: Text(
                          '${item.quantity}',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _textDark),
                        ),
                      ),
                    ),
                    // Increase
                    _qtyButton(
                      icon: Icons.add,
                      onTap: () => widget.onQuantityIncreased(item),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyButton(
      {required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(4),
          color: _cardBg,
        ),
        child: Icon(icon, size: 14, color: _textDark),
      ),
    );
  }

  // ── Totals ─────────────────────────────────────────────────────────────────
  Widget _buildTotals() {
    final subtotal = _subtotal;
    const discount = 0.0;
    const vat = 0.0;
    final total = subtotal - discount + vat;

    return Column(
      children: [
        _totalRow('Sub Total', '\$ ${_fmt.format(subtotal)}',
            valueColor: _textDark),
        const SizedBox(height: 6),
        _totalRow('Discount', '- \$ ${_fmt.format(discount)}',
            valueColor: const Color(0xFFEF4444)),
        const SizedBox(height: 6),
        _totalRow('VAT (0%)', '\$ ${_fmt.format(vat)}',
            valueColor: _textDark),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _textDark)),
            Text('\$ ${_fmt.format(total)}',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _textDark)),
          ],
        ),
      ],
    );
  }

  Widget _totalRow(String label, String value,
      {required Color valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(fontSize: 13, color: _grey)),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: valueColor)),
      ],
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Hold + Discount row
          Row(
            children: [
              Expanded(
                child: _outlineBtn(
                  label: 'Hold',
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _outlineBtn(
                  label: 'Discount',
                  onTap: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Proceed Payment
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: widget.cart.isNotEmpty
                  ? () {
                      widget.onPrintReceipt(
                          _customerNameController.text.trim());
                      for (var item in widget.cart.toList()) {
                        widget.onRemoveItem(item);
                      }
                      _customerNameController.clear();
                      _noteController.clear();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(Icons.check_circle,
                                  color: Colors.white),
                              SizedBox(width: 8),
                              Text('Order completed!'),
                            ],
                          ),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 255, 0, 0),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFB8B8D0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text('Proceed Payment',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _outlineBtn(
      {required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _border, width: 1.5),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  color: _textDark,
                  fontWeight: FontWeight.w500,
                  fontSize: 14)),
        ),
      ),
    );
  }
}