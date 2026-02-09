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
    'assets/images/food5.jpg',
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

  void _buildMenu() {
    menu["Main Dish"]!.addAll([
      _item("Yang Chow Rice", 180, Colors.orange, isPopular: true),
      _item("Sweet & Sour Pork", 220, Colors.red),
      _item("Beef Broccoli", 250, Colors.green),
    ]);

    menu["Appetizers"]!.addAll([
      _item("Siomai", 60, Colors.orange),
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
      body: Row(
        children: [ 
          /// MENU
          Expanded(
            flex: 7,
            child: Column(
              children: [
                _buildCategoryBar(),
                Expanded(child: _buildMenuGrid(items, isDesktop)),
              ],
            ),
          ),

          /// CART (Desktop)
          if (isDesktop) SizedBox(width: 380, child: _buildCart()),
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
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isDesktop ? 4 : 2,
        childAspectRatio: isDesktop ? 0.75 : 0.72,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
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
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.yellow.shade700,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'POPULAR',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
            if (quantity > 0)
              Positioned(
                top: 8,
                right: 8,
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.red.shade600,
                  child: Text('$quantity', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white, fontSize: isDesktop ? 18 : 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₱${item.price.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('ADD', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  final name = c.item.name.length > 20 ? c.item.name.substring(0, 17) + '...' : c.item.name;
                  final qty = c.quantity.toString().padLeft(2);
                  final price = (c.item.price * c.quantity).toStringAsFixed(2).padLeft(6);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text('$name x$qty')), Text('₱$price')]),
                  );
                }).toList(),

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

  @override
  void dispose() {
    customerNameController.dispose();
    super.dispose();
  }
}
