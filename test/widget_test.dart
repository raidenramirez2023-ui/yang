import 'package:flutter/material.dart';

/// Type-safe MenuItem model with image support
class MenuItem {
  final String name;
  final double price;
  final String category;
  final String imagePath; // Image asset path
  final Color color;

  MenuItem({
    required this.name,
    required this.price,
    required this.category,
    required this.imagePath,
    required this.color,
  });
}

/// Cart item with quantity
class CartItem {
  final MenuItem item;
  int quantity;

  CartItem(this.item, this.quantity);
}

/// Shared POS Widget - Can be used by both Admin and Staff
class SharedPOSWidget extends StatefulWidget {
  final String userRole; // 'Admin' or 'Staff'
  
  const SharedPOSWidget({
    super.key,
    required this.userRole,
  });

  @override
  State<SharedPOSWidget> createState() => _SharedPOSWidgetState();
}

class _SharedPOSWidgetState extends State<SharedPOSWidget> {
  String selectedCategory = 'Main Dish';
  String discountType = 'None';
  String paymentMethod = 'Cash';
  final TextEditingController customerNameController = TextEditingController();
  
  /// Menu organized by category with actual food images
  final Map<String, List<MenuItem>> menu = {
    "Appetizers": [
      MenuItem(
        name: "Pansit",
        price: 60,
        category: "Appetizers",
        imagePath: "assets/images/food 5.jpg",
        color: Colors.orange,
      ),
      MenuItem(
        name: "Lumpia",
        price: 50,
        category: "Appetizers",
        imagePath: "assets/images/food.jpg",
        color: Colors.brown,
      ),
      MenuItem(
        name: "Fried Wonton",
        price: 55,
        category: "Appetizers",
        imagePath: "assets/images/food1.jpg",
        color: Colors.amber,
      ),
    ],
    "Main Dish": [
      MenuItem(
        name: "Fried Rice",
        price: 120,
        category: "Main Dish",
        imagePath: "assets/images/food3.jpg",
        color: Colors.amber,
      ),
      MenuItem(
        name: "Sweet & Sour Pork",
        price: 180,
        category: "Main Dish",
        imagePath: "assets/images/food4.jpg",
        color: Colors.red,
      ),
      MenuItem(
        name: "Chopsuey",
        price: 150,
        category: "Main Dish",
        imagePath: "assets/images/chopsuey.jpg",
        color: Colors.green,
      ),
      MenuItem(
        name: "Yang Chow",
        price: 200,
        category: "Main Dish",
        imagePath: "assets/images/yang_chow.jpg",
        color: Colors.orange,
      ),
      MenuItem(
        name: "Beef Broccoli",
        price: 220,
        category: "Main Dish",
        imagePath: "assets/images/beef_broccoli.jpg",
        color: Colors.green,
      ),
    ],
    "Drinks": [
      MenuItem(
        name: "Softdrinks",
        price: 40,
        category: "Drinks",
        imagePath: "assets/images/softdrinks.jpg",
        color: Colors.blue,
      ),
      MenuItem(
        name: "Iced Tea",
        price: 45,
        category: "Drinks",
        imagePath: "assets/images/iced_tea.jpg",
        color: Colors.brown,
      ),
      MenuItem(
        name: "Fresh Lemonade",
        price: 55,
        category: "Drinks",
        imagePath: "assets/images/lemonade.jpg",
        color: Colors.yellow,
      ),
    ],
    "Desserts": [
      MenuItem(
        name: "Halo-Halo",
        price: 85,
        category: "Desserts",
        imagePath: "assets/images/halo_halo.jpg",
        color: Colors.purple,
      ),
      MenuItem(
        name: "Mango Sago",
        price: 75,
        category: "Desserts",
        imagePath: "assets/images/mango_sago.jpg",
        color: Colors.yellow,
      ),
      MenuItem(
        name: "Leche Flan",
        price: 70,
        category: "Desserts",
        imagePath: "assets/images/leche_flan.jpg",
        color: Colors.orange,
      ),
    ],
  };

  /// Cart: List of CartItems
  List<CartItem> cart = [];

  void addToCart(MenuItem item) {
    setState(() {
      final existingIndex = cart.indexWhere((cartItem) => cartItem.item.name == item.name);
      if (existingIndex != -1) {
        cart[existingIndex].quantity++;
      } else {
        cart.add(CartItem(item, 1));
      }
    });
    
    _showSnackBar('${item.name} added to cart', Colors.green.shade700);
  }

  void removeFromCart(int index) {
    setState(() {
      if (cart[index].quantity > 1) {
        cart[index].quantity--;
      } else {
        cart.removeAt(index);
      }
    });
  }

  void clearCart() {
    setState(() {
      cart.clear();
      customerNameController.clear();
      discountType = 'None';
      paymentMethod = 'Cash';
    });
  }

  double getSubtotal() {
    return cart.fold(0, (sum, item) => sum + (item.item.price * item.quantity));
  }

  double getDiscount() {
    if (discountType == 'Senior / PWD') {
      return getSubtotal() * 0.20; // 20% discount
    }
    return 0;
  }

  double getTax() {
    return (getSubtotal() - getDiscount()) * 0.12; // 12% tax
  }

  double getTotal() {
    return getSubtotal() - getDiscount() + getTax();
  }

  void processPayment() {
    if (cart.isEmpty) {
      _showSnackBar('Cart is empty!', Colors.red.shade700);
      return;
    }

    // Generate order number
    final orderNumber = 'ORD-${DateTime.now().millisecondsSinceEpoch % 10000}';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600, size: 32),
            const SizedBox(width: 12),
            const Text('Payment Successful!'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildReceiptRow('Order Number:', orderNumber, bold: true),
              const Divider(height: 20),
              _buildReceiptRow('Customer:', customerNameController.text.isEmpty 
                ? 'Walk-in' 
                : customerNameController.text),
              _buildReceiptRow('Processed by:', widget.userRole),
              _buildReceiptRow('Payment Method:', paymentMethod),
              const Divider(height: 20),
              const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...cart.map((item) => Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 4),
                child: _buildReceiptRow(
                  '${item.item.name} x${item.quantity}',
                  '₱${(item.item.price * item.quantity).toStringAsFixed(2)}',
                ),
              )),
              const Divider(height: 20),
              _buildReceiptRow('Subtotal:', '₱${getSubtotal().toStringAsFixed(2)}'),
              if (discountType != 'None')
                _buildReceiptRow('Discount ($discountType):', '-₱${getDiscount().toStringAsFixed(2)}', 
                  color: Colors.green),
              _buildReceiptRow('Tax (12%):', '₱${getTax().toStringAsFixed(2)}'),
              const Divider(height: 20),
              _buildReceiptRow('TOTAL:', '₱${getTotal().toStringAsFixed(2)}', 
                bold: true, size: 18),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              clearCart();
            },
            child: const Text('New Order'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade600,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _showSnackBar('Receipt printed successfully', Colors.green.shade700);
              clearCart();
            },
            icon: const Icon(Icons.print),
            label: const Text('Print Receipt'),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {
    bool bold = false, 
    double size = 14,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: size,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: color ?? Colors.grey.shade700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: size,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: color ?? Colors.grey.shade900,
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1200;
    final isTablet = size.width > 800 && size.width <= 1200;

    final currentMenuItems = menu[selectedCategory] ?? [];

    return isDesktop || isTablet
        ? _buildDesktopLayout(currentMenuItems)
        : _buildMobileLayout(currentMenuItems);
  }

  Widget _buildDesktopLayout(List<MenuItem> currentMenuItems) {
    return Row(
      children: [
        // LEFT SIDE – MENU
        Expanded(
          flex: 2,
          child: _buildMenuSection(currentMenuItems),
        ),
        // RIGHT SIDE – CART
        Container(
          width: 400,
          color: Colors.white,
          child: _buildCartSection(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(List<MenuItem> currentMenuItems) {
    return Column(
      children: [
        Expanded(
          child: _buildMenuSection(currentMenuItems),
        ),
        _buildCartSummaryBar(),
      ],
    );
  }

  Widget _buildMenuSection(List<MenuItem> currentMenuItems) {
    return Column(
      children: [
        // Category buttons
        Container(
          height: 70,
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: menu.keys.length,
            itemBuilder: (context, index) {
              final category = menu.keys.elementAt(index);
              final isSelected = selectedCategory == category;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: isSelected,
                  label: Text(
                    category,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                  backgroundColor: Colors.grey.shade200,
                  selectedColor: Colors.red.shade600,
                  onSelected: (selected) {
                    setState(() {
                      selectedCategory = category;
                    });
                  },
                ),
              );
            },
          ),
        ),
        // Menu items grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 4 : 
                            MediaQuery.of(context).size.width > 800 ? 3 : 2,
              childAspectRatio: 0.85,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: currentMenuItems.length,
            itemBuilder: (context, index) {
              return _buildMenuCard(currentMenuItems[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMenuCard(MenuItem item) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => addToCart(item),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Food Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Container(
                height: 100,
                width: double.infinity,
                color: item.color.withOpacity(0.1),
                child: Stack(
                  children: [
                    // Background placeholder
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            item.color.withOpacity(0.3),
                            item.color.withOpacity(0.1),
                          ],
                        ),
                      ),
                    ),
                    // Actual image (replace with your own images)
                    Center(
                      child: Image.asset(
                        item.imagePath,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          // Fallback icon if image not found
                          return Icon(
                            Icons.fastfood,
                            size: 50,
                            color: item.color,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Food Details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₱${item.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () => addToCart(item),
                    child: const Text('Add to Order'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartSection() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade600,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.shopping_cart, color: Colors.white),
              const SizedBox(width: 12),
              const Text(
                'Order List',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (cart.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Clear Cart?'),
                        content: const Text('Are you sure you want to clear all items?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            onPressed: () {
                              clearCart();
                              Navigator.pop(context);
                            },
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        // Customer name
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: customerNameController,
            decoration: InputDecoration(
              labelText: 'Customer Name (Optional)',
              hintText: 'Enter customer name',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
        ),
        // Cart items
        Expanded(
          child: cart.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Cart is empty',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: cart.length,
                  itemBuilder: (context, index) {
                    final cartItem = cart[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: cartItem.item.color.withOpacity(0.2),
                          backgroundImage: AssetImage(cartItem.item.imagePath),
                          child: Image.asset(
                            cartItem.item.imagePath,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.fastfood,
                              color: cartItem.item.color,
                            ),
                          ),
                        ),
                        title: Text(
                          cartItem.item.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text('₱${cartItem.item.price.toStringAsFixed(2)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              color: Colors.red,
                              onPressed: () => removeFromCart(index),
                            ),
                            Container(
                              width: 30,
                              alignment: Alignment.center,
                              child: Text(
                                '${cartItem.quantity}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              color: Colors.green,
                              onPressed: () => addToCart(cartItem.item),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        // Total and payment section
        if (cart.isNotEmpty) _buildPaymentSection(),
      ],
    );
  }

  Widget _buildPaymentSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Discount dropdown
          DropdownButtonFormField<String>(
            value: discountType,
            decoration: InputDecoration(
              labelText: 'Discount',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            items: ['None', 'Senior / PWD'].map((discount) {
              return DropdownMenuItem(
                value: discount,
                child: Text(discount),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                discountType = value!;
              });
            },
          ),
          const SizedBox(height: 12),
          // Payment method dropdown
          DropdownButtonFormField<String>(
            value: paymentMethod,
            decoration: InputDecoration(
              labelText: 'Payment Method',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            items: ['Cash', 'Card', 'GCash'].map((method) {
              return DropdownMenuItem(
                value: method,
                child: Text(method),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                paymentMethod = value!;
              });
            },
          ),
          const SizedBox(height: 16),
          // Price breakdown
          _buildTotalRow('Subtotal', getSubtotal()),
          if (discountType != 'None')
            _buildTotalRow('Discount (20%)', -getDiscount(), color: Colors.green),
          _buildTotalRow('Tax (12%)', getTax()),
          const Divider(height: 20, thickness: 2),
          _buildTotalRow('TOTAL', getTotal(), isTotal: true),
          const SizedBox(height: 20),
          // Print receipt button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: processPayment,
              icon: const Icon(Icons.print),
              label: const Text(
                'Print Receipt',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {
    bool isTotal = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 15,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: color ?? (isTotal ? Colors.grey.shade900 : Colors.grey.shade700),
            ),
          ),
          Text(
            '₱${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 20 : 16,
              fontWeight: FontWeight.bold,
              color: color ?? (isTotal ? Colors.red.shade700 : Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartSummaryBar() {
    return Container(
      height: 80,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${cart.length} Items',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  '₱${getTotal().toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => Container(
                  height: MediaQuery.of(context).size.height * 0.8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: _buildCartSection(),
                ),
              );
            },
            icon: const Icon(Icons.shopping_cart),
            label: const Text('View Cart'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    customerNameController.dispose();
    super.dispose();
  }
}