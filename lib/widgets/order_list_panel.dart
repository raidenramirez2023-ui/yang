import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'shared_pos_widget.dart';

class OrderListPanel extends StatefulWidget {
  final List<CartItem> cart;
  final Function(CartItem) onQuantityIncreased;
  final Function(CartItem) onQuantityDecreased;
  final Function(CartItem) onRemoveItem;
  final void Function(String name, String note, double totalAmount, int guestCount, String tableNumber)
  onProceedPayment;
  final VoidCallback onClearCart;
  final void Function(VoidCallback clearFunction) onClearInputs;
  final bool isMobile;

  const OrderListPanel({
    super.key,
    required this.cart,
    required this.onQuantityIncreased,
    required this.onQuantityDecreased,
    required this.onRemoveItem,
    required this.onProceedPayment,
    required this.onClearCart,
    required this.onClearInputs,
    this.isMobile = false,
  });

  @override
  State<OrderListPanel> createState() => _OrderListPanelState();
}

class _OrderListPanelState extends State<OrderListPanel> {
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _guestCountController = TextEditingController(text: '1');
  final TextEditingController _tableNumberController = TextEditingController();
  bool _isDiscountEnabled = false; // Discount state variable

  final NumberFormat _fmt = NumberFormat('#,##0.00', 'en_US');

  static const _indigo = Colors.red;
  static const _bg = Color(0xFFF5F6FA);
  static const _border = Color(0xFFE5E7EB);
  static const _grey = Color(0xFF6B7280);
  static const _textDark = Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    // Pass the clearInputs function to parent widget
    widget.onClearInputs(clearInputs);
  }

  @override
  void dispose() {
    _noteController.dispose();
    _guestCountController.dispose();
    _tableNumberController.dispose();
    super.dispose();
  }

  double get _subtotal => widget.cart.fold(
    0.0,
    (sum, item) => sum + (item.item.price * item.quantity),
  );

  void clearInputs() {
    _noteController.clear();
    _guestCountController.text = '1';
    _tableNumberController.clear();
  }

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
                  _buildTableAndGuestFields(),
                  const SizedBox(height: 10),
                  _buildNoteField(),
                  const SizedBox(height: 20),
                  _buildItemsHeader(),
                  const SizedBox(height: 12),
                  if (widget.cart.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'No items in order',
                          style: TextStyle(color: _grey, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ...widget.cart.map(_buildCartItem),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          _buildTotalsSection(),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 40,
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
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

  Widget _buildTableAndGuestFields() {
    return Row(
      children: [
        // Table Number Field
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Table No.:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _tableNumberController,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: _textDark, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'Table #',
                  hintStyle: const TextStyle(color: _grey, fontSize: 13),
                  filled: true,
                  fillColor: _bg,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
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
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Guest Count Field
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'No. of Guest:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _guestCountController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: _textDark, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'Guests',
                  hintStyle: const TextStyle(color: _grey, fontSize: 13),
                  filled: true,
                  fillColor: _bg,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
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
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableNumberField() {
    return Row(
      children: [
        const Text(
          'Table No.:',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _textDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _tableNumberController,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: _textDark, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: 'Enter table number',
              hintStyle: const TextStyle(color: _grey, fontSize: 13),
              filled: true,
              fillColor: _bg,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
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
          ),
        ),
      ],
    );
  }

  Widget _buildGuestCountField() {
    return Row(
      children: [
        const Text(
          'No. of Guest:',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _textDark,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 70,
          child: TextField(
            controller: _guestCountController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: _textDark, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              filled: true,
              fillColor: _bg,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 10,
              ),
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
          ),
        ),
      ],
    );
  }

  Widget _buildItemsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Items',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: _textDark,
          ),
        ),
        GestureDetector(
          onTap: widget.cart.isNotEmpty ? widget.onClearCart : null,
          child: Text(
            'Clear All',
            style: TextStyle(
              color: widget.cart.isNotEmpty ? Colors.red : _grey,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCartItem(CartItem item) {
    final imagePath = item.item.customImagePath ?? item.item.fallbackImagePath;
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
              errorBuilder: (context, _, _) => Container(
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
                          color: _textDark,
                        ),
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
                        color: _textDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _qtyBtn(
                          Icons.remove,
                          () => widget.onQuantityDecreased(item),
                        ),
                        SizedBox(
                          width: 32,
                          child: Center(
                            child: Text(
                              '${item.quantity}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        _qtyBtn(
                          Icons.add,
                          () => widget.onQuantityIncreased(item),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => widget.onRemoveItem(item),
                      child: const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: Colors.redAccent,
                      ),
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

  Widget _buildTotalsSection() {
    final subtotal = _subtotal;
    final discountAmount = _isDiscountEnabled ? (subtotal * 0.20) : 0.0;
    final total = subtotal - discountAmount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _totalLine('Subtotal', '₱${_fmt.format(subtotal)}'),
          const SizedBox(height: 8),
          // Discount row with checkbox
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: _isDiscountEnabled,
                        onChanged: (value) {
                          setState(() {
                            _isDiscountEnabled = value ?? false;
                          });
                        },
                        activeColor: _indigo,
                        checkColor: Colors.white,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Discount (20%)',
                      style: TextStyle(
                        color: _grey,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '₱${_fmt.format(discountAmount)}',
                style: TextStyle(
                  color: _grey,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: _textDark,
                ),
              ),
              Text(
                '₱${_fmt.format(total)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: _indigo,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _totalLine(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: _grey, fontSize: 14)),
        Text(
          value,
          style: const TextStyle(
            color: _textDark,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: widget.cart.isNotEmpty
                  ? () {
                      final subtotal = _subtotal;
                      final discountAmount = _isDiscountEnabled
                          ? (subtotal * 0.20)
                          : 0.0;
                      final total = subtotal - discountAmount;
                      final guestCount = int.tryParse(_guestCountController.text.trim()) ?? 1;
                      final tableNumber = _tableNumberController.text.trim();
                      widget.onProceedPayment(
                        '',
                        _noteController.text.trim(),
                        total,
                        guestCount,
                        tableNumber,
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Proceed Payment',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
