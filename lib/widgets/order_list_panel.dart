import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'shared_pos_widget.dart';

class OrderListPanel extends StatefulWidget {
  final List<CartItem> cart;
  final Function(CartItem) onQuantityIncreased;
  final Function(CartItem) onQuantityDecreased;
  final Function(CartItem) onRemoveItem;
  final VoidCallback onProceedPayment;
  final VoidCallback onClearCart;
  final bool isMobile;

  const OrderListPanel({
    super.key,
    required this.cart,
    required this.onQuantityIncreased,
    required this.onQuantityDecreased,
    required this.onRemoveItem,
    required this.onProceedPayment,
    required this.onClearCart,
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

  static const _indigo = Color(0xFF4F46E5);
  static const _bg = Color(0xFFF5F6FA);
  static const _border = Color(0xFFE5E7EB);
  static const _grey = Color(0xFF6B7280);
  static const _textDark = Color(0xFF1E293B);

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
      width: widget.isMobile ? double.infinity : 360,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: _border)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 14),
                  _buildCustomerRow(),
                  const SizedBox(height: 10),
                  _buildNoteField(),
                  const SizedBox(height: 20),
                  _buildItemsHeader(),
                  const SizedBox(height: 12),
                  if (widget.cart.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text('No items in order',
                            style: TextStyle(color: _grey, fontSize: 13)),
                      ),
                    )
                  else
                    ...widget.cart.map(_buildCartItem),
                  const SizedBox(height: 20),
                  const Divider(color: _border, height: 1),
                  const SizedBox(height: 16),
                  _buildTotals(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      alignment: Alignment.centerLeft,
      child: const Text(
        'Order Details',
        style: TextStyle(
          color: _textDark,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildCustomerRow() {
    return TextField(
      controller: _customerNameController,
      style: const TextStyle(fontSize: 13, color: _textDark),
      decoration: InputDecoration(
        hintText: "Customer's name",
        hintStyle: const TextStyle(color: _grey, fontSize: 13),
        filled: true,
        fillColor: _bg,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
          borderSide: const BorderSide(color: _indigo, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildNoteField() {
    return TextField(
      controller: _noteController,
      style: const TextStyle(fontSize: 13, color: _textDark),
      decoration: InputDecoration(
        hintText: 'Add note here...',
        hintStyle: const TextStyle(color: _grey, fontSize: 13),
        filled: true,
        fillColor: _bg,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
          borderSide: const BorderSide(color: _indigo, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildItemsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Items',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15, color: _textDark)),
        GestureDetector(
          onTap: widget.cart.isNotEmpty ? widget.onClearCart : null,
          child: Text(
            'Clear All',
            style: TextStyle(
                color: widget.cart.isNotEmpty ? Colors.red : _grey,
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildCartItem(CartItem item) {
    final imagePath =
        item.item.customImagePath ?? item.item.fallbackImagePath;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              imagePath,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (context, _, __) => Container(
                width: 50,
                height: 50,
                color: _bg,
                child: const Icon(Icons.fastfood, color: _grey, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.item.name,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _textDark),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '₱${_fmt.format(item.item.price * item.quantity)}',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _textDark),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _qtyBtn(Icons.remove, () => widget.onQuantityDecreased(item)),
                        SizedBox(
                          width: 32,
                          child: Center(
                            child: Text('${item.quantity}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                        ),
                        _qtyBtn(Icons.add, () => widget.onQuantityIncreased(item)),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => widget.onRemoveItem(item),
                      child: const Icon(Icons.delete_outline,
                          size: 20, color: Colors.redAccent),
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

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: _textDark),
      ),
    );
  }

  Widget _buildTotals() {
    final subtotal = _subtotal;
    return Column(
      children: [
        _totalLine('Subtotal', '₱${_fmt.format(subtotal)}'),
        const SizedBox(height: 8),
        _totalLine('Tax (0%)', '₱0.00'),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: _textDark)),
            Text('₱${_fmt.format(subtotal)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: _indigo)),
          ],
        ),
      ],
    );
  }

  Widget _totalLine(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: _grey, fontSize: 14)),
        Text(value,
            style: const TextStyle(
                color: _textDark, fontWeight: FontWeight.w600, fontSize: 14)),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _secondaryBtn('Hold Order')),
              const SizedBox(width: 12),
              Expanded(child: _secondaryBtn('Discount')),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: widget.cart.isNotEmpty ? widget.onProceedPayment : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Proceed Payment',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _secondaryBtn(String label) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(label,
            style: const TextStyle(
                color: _textDark, fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }
}