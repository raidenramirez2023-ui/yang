import 'package:flutter/material.dart';

/// =====================
/// MODELS
/// =====================
class MenuItem {
  String name;
  double price;
  final String category;
  final String imagePath;
  final Color color;
  final bool isPopular; // Best Seller / Popular badge

  MenuItem({
    required this.name,
    required this.price,
    required this.category,
    required this.imagePath,
    required this.color,
    this.isPopular = false,
  });
}

class CartItem {
  final MenuItem item;
  int quantity;
  CartItem(this.item, this.quantity);
}

/// =====================
/// SHARED POS WIDGET
/// =====================
class SharedPOSWidget extends StatefulWidget {
  final String userRole; // Admin / Staff
  const SharedPOSWidget({super.key, required this.userRole});

  @override
  State<SharedPOSWidget> createState() => _SharedPOSWidgetState();
}

class _SharedPOSWidgetState extends State<SharedPOSWidget> {
  String selectedCategory = 'Main Dish';
  final TextEditingController customerNameController = TextEditingController();

  final List<String> foodImages = [
    'assets/images/food.jpg',
    'assets/images/food1.jpg',
    'assets/images/food3.jpg',
    'assets/images/food4.jpg',
    'assets/images/food 5.jpg',
    'assets/images/siomaii.jpg',
  ];

  int _imageIndex = 0;
  String _nextImage() {
    final img = foodImages[_imageIndex];
    _imageIndex = (_imageIndex + 1) % foodImages.length;
    return img;
  }

  final Map<String, List<MenuItem>> menu = {
    "Main Dish": [],
    "Appetizers": [],
    "Drinks": [],
    "Desserts": [],
  };

  List<CartItem> cart = [];

  @override
  void initState() {
    super.initState();
    _buildMenu();
  }

  @override
  void dispose() {
    customerNameController.dispose();
    super.dispose();
  }

  void _buildMenu() {
    menu["Main Dish"]!.addAll([
      _item("Yang Chow Rice", 180, Colors.orange, isPopular: true),
      _item("Sweet & Sour Pork", 220, Colors.red),
      _item("Beef Broccoli", 250, Colors.green),
    ]);

    menu["Appetizers"]!.addAll([
      MenuItem(
        name: "Siomai",
        price: 60,
        category: "Appetizers",
        imagePath: "assets/images/siomaii.jpg",
        color: Colors.orange,
        isPopular: false,
      ),
      _item("Lumpia", 50, Colors.brown, isPopular: true),
    ]);

    menu["Drinks"]!.addAll([
      _item("Iced Tea", 45, Colors.blue),
      _item("Softdrinks", 40, Colors.indigo),
    ]);

    menu["Desserts"]!.addAll([
      _item("Halo-Halo", 90, Colors.purple, isPopular: true),
      _item("Leche Flan", 70, Colors.amber),
    ]);
  }

  MenuItem _item(String name, double price, Color color, {bool isPopular = false}) {
    return MenuItem(
      name: name,
      price: price,
      category: selectedCategory,
      imagePath: _nextImage(),
      color: color,
      isPopular: isPopular,
    );
  }

  void addToCart(MenuItem item) {
    setState(() {
      final index = cart.indexWhere((e) => e.item.name == item.name);
      if (index >= 0) {
        cart[index].quantity++;
      } else {
        cart.add(CartItem(item, 1));
      }
    });
  }

  double total() => cart.fold(0, (sum, e) => sum + e.item.price * e.quantity);

  int getCartQuantity(MenuItem item) {
    final index = cart.indexWhere((e) => e.item.name == item.name);
    return index >= 0 ? cart[index].quantity : 0;
  }

  /// =====================
  /// UI
  /// =====================
  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final items = menu[selectedCategory]!;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          // Category Tabs
          _buildCategoryBar(),
          // Main Content
          Expanded(
            child: isDesktop ? _buildDesktopLayout(items) : _buildMobileLayout(items),
          ),
        ],
      ),
      floatingActionButton: !isDesktop && cart.isNotEmpty
          ? FloatingActionButton.extended(
              backgroundColor: Colors.red.shade600,
              onPressed: _showCartSheet,
              icon: const Icon(Icons.shopping_cart),
              label: Text('₱${total().toStringAsFixed(2)}'),
            )
          : null,
    );
  }

  Widget _buildDesktopLayout(List<MenuItem> items) {
    return Row(
      children: [
        /// MENU
        Expanded(
          flex: 7,
          child: Column(
            children: [
              Expanded(child: _buildMenuGrid(items, true)),
            ],
          ),
        ),

        /// CART (Desktop)
        SizedBox(width: 380, child: _buildCart()),
      ],
    );
  }

  Widget _buildMobileLayout(List<MenuItem> items) {
    return Column(
      children: [
        Expanded(child: _buildMenuGrid(items, false)),
      ],
    );
  }

  /// =====================
  /// CATEGORY BAR
  /// =====================
  Widget _buildCategoryBar() {
    return Container(
      height: 70,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: menu.keys.map((cat) {
          final active = selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ChoiceChip(
              selected: active,
              label: Text(cat),
              selectedColor: Colors.red.shade600,
              labelStyle: TextStyle(
                color: active ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
              onSelected: (_) {
                setState(() => selectedCategory = cat);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  /// =====================
  /// MENU GRID
  /// =====================
  Widget _buildMenuGrid(List<MenuItem> items, bool isDesktop) {
    final screenWidth = MediaQuery.of(context).size.width;
    late int crossAxisCount;
    late double childAspectRatio;

    if (isDesktop) {
      crossAxisCount = 4;
      childAspectRatio = 0.75;
    } else if (screenWidth > 600) {
      crossAxisCount = 3;
      childAspectRatio = 0.7;
    } else {
      crossAxisCount = 2;
      childAspectRatio = 0.65;
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _foodCard(items[i], isDesktop),
    );
  }

  /// =====================
  /// FOOD CARD WITH POPULAR BADGE & QUANTITY
  /// =====================
  Widget _foodCard(MenuItem item, bool isDesktop) {
    final quantity = getCartQuantity(item);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return GestureDetector(
      onTap: () => addToCart(item),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(item.imagePath, fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                  ),
                ),
              ),
            ),
            if (item.isPopular)
              Positioned(
                top: isMobile ? 6 : 8,
                left: isMobile ? 6 : 8,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 6 : 8,
                    vertical: isMobile ? 2 : 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.yellow.shade700,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'POPULAR',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 10 : 12,
                    ),
                  ),
                ),
              ),
            if (quantity > 0)
              Positioned(
                top: isMobile ? 6 : 8,
                right: isMobile ? 6 : 8,
                child: CircleAvatar(
                  radius: isMobile ? 12 : 14,
                  backgroundColor: Colors.red.shade600,
                  child: Text(
                    '$quantity',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 10 : 12,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: isMobile ? 12 : 16,
              right: isMobile ? 12 : 16,
              bottom: isMobile ? 12 : 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 14 : (isDesktop ? 18 : 16),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: isMobile ? 4 : 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₱${item.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 14 : 16,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 10 : 14,
                          vertical: isMobile ? 4 : 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'ADD',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: isMobile ? 12 : 13,
                          ),
                        ),
                      )
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// =====================
  /// CART
  /// =====================
  Widget _buildCart() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.red.shade600,
            child: const Text('ORDER LIST', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: cart.isEmpty
                ? const Center(child: Text('Cart is empty'))
                : ListView.builder(
                    itemCount: cart.length,
                    itemBuilder: (_, i) {
                      final c = cart[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: c.item.color,
                            backgroundImage: AssetImage(c.item.imagePath),
                          ),
                          title: Text(c.item.name),
                          subtitle: Text('₱${c.item.price.toStringAsFixed(2)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () => _decrementItem(c)),
                              Text('${c.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.green), onPressed: () => _incrementItem(c)),
                              IconButton(icon: const Icon(Icons.edit, color: Colors.orange), onPressed: () => _editCartItem(c)),
                              IconButton(icon: const Icon(Icons.delete_forever, color: Colors.grey), onPressed: () => _deleteCartItem(c)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: customerNameController,
                  decoration: const InputDecoration(labelText: 'Customer Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Text('TOTAL: ₱${total().toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, minimumSize: const Size(double.infinity, 50)),
                  onPressed: _printReceipt,
                  icon: const Icon(Icons.print),
                  label: const Text('PRINT RECEIPT'),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  void _showCartSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SizedBox(height: MediaQuery.of(context).size.height * 0.85, child: _buildCart()),
    );
  }

  /// =====================
  /// CART ITEM FUNCTIONS
  /// =====================
  void _incrementItem(CartItem c) => setState(() => c.quantity++);
  void _decrementItem(CartItem c) {
    setState(() {
      if (c.quantity > 1) {
        c.quantity--;
      } else {
        cart.remove(c);
      }
    });
  }

  void _deleteCartItem(CartItem c) => setState(() => cart.remove(c));

  void _editCartItem(CartItem c) {
    final nameController = TextEditingController(text: c.item.name);
    final priceController = TextEditingController(text: c.item.price.toString());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Item Name')),
            TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                c.item.name = nameController.text.trim();
                c.item.price = double.tryParse(priceController.text) ?? c.item.price;
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// =====================
  /// PRINT RECEIPT (DIALOG)
  /// =====================
  void _printReceipt() {
    final customerName = customerNameController.text.trim().isEmpty ? 'Guest' : customerNameController.text.trim();
    final date = DateTime.now();
    final dateStr = "${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year} ${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}";

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('🧾 Receipt', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('YANG CHOW RESTAURANT', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                const Text('Areza Mall Pagsanjan Laguna', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                Text('Date: $dateStr', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                const Divider(thickness: 1),
                Text('Customer: $customerName', style: const TextStyle(fontWeight: FontWeight.bold)),
                const Divider(thickness: 1),

                ...cart.map((c) {
                  final name = c.item.name.length > 20 ? '${c.item.name.substring(0, 17)}...' : c.item.name;
                  final qty = c.quantity.toString().padLeft(2);
                  final price = (c.item.price * c.quantity).toStringAsFixed(2).padLeft(6);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text('$name x$qty')), Text('₱$price')]),
                  );
                }),

                const Divider(thickness: 1),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('₱${total().toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
                const Divider(thickness: 1),
                const SizedBox(height: 6),
                const Text('Thank you for dining with us!', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                const Text('Please come again!', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }
}