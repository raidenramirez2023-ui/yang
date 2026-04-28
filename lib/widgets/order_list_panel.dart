import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/menu_item.dart';

class OrderListPanel extends StatefulWidget {
  final List<CartItem> cart;
  final Function(CartItem) onQuantityIncreased;
  final Function(CartItem) onQuantityDecreased;
  final Function(CartItem) onRemoveItem;
  final void Function(String name, String note, double totalAmount, int guestCount, String tableNumber, double discountAmount, String discountLabel, String discountName, String discountAddress)
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
  String _discountLabel = 'None';
  String _discountCustomerName = '';
  String _discountCustomerAddress = '';
  
  // Map to manage TextEditingController for each cart item
  final Map<String, TextEditingController> _quantityControllers = {};

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
    // Dispose all quantity controllers
    for (final controller in _quantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // Get or create controller for a specific item
  TextEditingController _getQuantityController(CartItem item) {
    final key = item.item.name;
    if (!_quantityControllers.containsKey(key)) {
      _quantityControllers[key] = TextEditingController(text: '${item.quantity}');
    }
    return _quantityControllers[key]!;
  }

  // Update controller text when quantity changes
  void _updateQuantityController(CartItem item) {
    final key = item.item.name;
    final controller = _quantityControllers[key];
    if (controller != null && controller.text != '${item.quantity}') {
      controller.text = '${item.quantity}';
    }
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
    // Clean up controllers for items that are no longer in cart
    final currentItems = widget.cart.map((item) => item.item.name).toSet();
    _quantityControllers.removeWhere((key, controller) {
      if (!currentItems.contains(key)) {
        controller.dispose();
        return true;
      }
      return false;
    });

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
                    ...widget.cart.map((item) {
                      // Update controller text before building
                      _updateQuantityController(item);
                      return _buildCartItem(item);
                    }),
                  const SizedBox(height: 4),
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
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                          width: 40,
                          height: 26,
                          child: TextField(
                            controller: _getQuantityController(item),
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                            ),
                            onSubmitted: (value) {
                              final newQuantity = int.tryParse(value) ?? 1;
                              if (newQuantity > 0 && newQuantity != item.quantity) {
                                // Calculate the difference and update accordingly
                                final currentQuantity = item.quantity;
                                if (newQuantity > currentQuantity) {
                                  // Increase by the difference
                                  for (int i = 0; i < (newQuantity - currentQuantity); i++) {
                                    widget.onQuantityIncreased(item);
                                  }
                                } else if (newQuantity < currentQuantity) {
                                  // Decrease by the difference
                                  for (int i = 0; i < (currentQuantity - newQuantity); i++) {
                                    widget.onQuantityDecreased(item);
                                  }
                                }
                              } else if (newQuantity <= 0) {
                                // Reset to 1 if invalid quantity
                                _getQuantityController(item).text = '${item.quantity}';
                              }
                            },
                            onChanged: (value) {
                              // Optional: Real-time validation or feedback
                              final enteredValue = int.tryParse(value);
                              if (enteredValue != null && enteredValue < 0) {
                                _getQuantityController(item).text = '0';
                              }
                            },
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
    double maxSingleItemPrice = 0.0;
    if (widget.cart.isNotEmpty) {
      maxSingleItemPrice = widget.cart.map((e) => e.item.price).reduce((a, b) => a > b ? a : b);
    }
    final discountAmount = _isDiscountEnabled ? (maxSingleItemPrice * 0.20) : 0.0;
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
          // Clickable Discount row
          GestureDetector(
            onTap: _showDiscountModal,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              color: Colors.transparent, // Ensures the whole area is clickable
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          _isDiscountEnabled ? Icons.check_box : Icons.check_box_outline_blank,
                          color: _isDiscountEnabled ? _indigo : _grey,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isDiscountEnabled ? 'Discount (20% - $_discountLabel)' : 'Apply Discount (20%)',
                          style: TextStyle(
                            fontSize: 13,
                            color: _isDiscountEnabled ? _textDark : _grey,
                            fontWeight: _isDiscountEnabled ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '-₱${_fmt.format(discountAmount)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: _isDiscountEnabled ? _indigo : _grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
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
                      double maxSingleItemPrice = 0.0;
                      if (widget.cart.isNotEmpty) {
                        maxSingleItemPrice = widget.cart.map((e) => e.item.price).reduce((a, b) => a > b ? a : b);
                      }
                      final discountAmount = _isDiscountEnabled ? (maxSingleItemPrice * 0.20) : 0.0;
                      final total = subtotal - discountAmount;
                      final guestCount = int.tryParse(_guestCountController.text.trim()) ?? 1;
                      final tableNumber = _tableNumberController.text.trim();
                      widget.onProceedPayment(
                        '',
                        _noteController.text.trim(),
                        total,
                        guestCount,
                        tableNumber,
                        discountAmount,
                        _discountLabel,
                        _discountCustomerName,
                        _discountCustomerAddress,
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

  void _showDiscountModal() {
    final TextEditingController nameController = TextEditingController(text: _discountCustomerName);
    final TextEditingController addressController = TextEditingController(text: _discountCustomerAddress);
    final TextEditingController otherController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: EdgeInsets.zero,
        title: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Apply Discount', style: TextStyle(fontWeight: FontWeight.bold, color: _textDark, fontSize: 18)),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: _grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: StatefulBuilder(
          builder: (context, setModalState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Customer Details (Optional):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _grey)),
                  ),
                  const SizedBox(height: 4),
                  _buildModalField(nameController, 'Customer Name', Icons.person_outlined),
                  const SizedBox(height: 4),
                  _buildModalField(addressController, 'Address', Icons.location_on_outlined),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Divider(color: _border),
                  ),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Select Type:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _grey)),
                  ),
                  const SizedBox(height: 4),
                  _buildDiscountItem(
                    'Senior Citizen', 
                    Icons.elderly, 
                    nameController, 
                    addressController,
                    setModalState,
                  ),
                  _buildDiscountItem(
                    'PWD', 
                    Icons.accessible, 
                    nameController, 
                    addressController,
                    setModalState,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Divider(color: _border),
                  ),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Other:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _grey)),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: otherController,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Enter valid ID...',
                      hintStyle: const TextStyle(fontSize: 13, color: _grey),
                      filled: true,
                      fillColor: _bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _indigo),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton(
                      onPressed: () {
                        if (otherController.text.trim().isNotEmpty) {
                          _applyDiscount(
                            otherController.text.trim(),
                            nameController.text.trim(),
                            addressController.text.trim(),
                          );
                          setModalState(() {}); // Refresh modal UI
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _indigo,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Apply Custom', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          if (_isDiscountEnabled)
            TextButton(
              onPressed: () {
                setState(() {
                  _isDiscountEnabled = false;
                  _discountLabel = 'None';
                  _discountCustomerName = '';
                  _discountCustomerAddress = '';
                });
                Navigator.pop(context);
              },
              child: const Text('Remove Discount', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          TextButton(
            onPressed: () {
              // Clicking OK saves the name/address if a discount was already selected
              if (_isDiscountEnabled) {
                _applyDiscount(_discountLabel, nameController.text.trim(), addressController.text.trim());
              }
              Navigator.pop(context);
            },
            child: const Text('OK', style: TextStyle(color: _grey, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountItem(String label, IconData icon, TextEditingController nameCtrl, TextEditingController addrCtrl, StateSetter setModalState) {
    final isSelected = _isDiscountEnabled && _discountLabel == label;
    return GestureDetector(
      onTap: () {
        _applyDiscount(label, nameCtrl.text.trim(), addrCtrl.text.trim());
        setModalState(() {}); // Refresh modal UI
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _indigo.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? _indigo : _border),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? _indigo : _grey, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? _indigo : _textDark,
                  fontSize: 14,
                ),
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle, color: _indigo, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildModalField(TextEditingController ctrl, String hint, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: _grey),
        prefixIcon: Icon(icon, size: 18, color: _grey),
        filled: true,
        fillColor: _bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _indigo),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  void _applyDiscount(String label, String name, String address) {
    setState(() {
      _isDiscountEnabled = true;
      _discountLabel = label;
      _discountCustomerName = name;
      _discountCustomerAddress = address;
    });
  }
}
