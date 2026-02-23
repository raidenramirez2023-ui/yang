import 'package:flutter/material.dart';
import 'order_list_panel.dart';

/// =====================
/// MODELS
/// =====================
class MenuItem {
  String name;
  double price;
  final String category;
  String? customImagePath;
  final String fallbackImagePath;
  final Color color;
  bool isPopular;

  MenuItem({
    required this.name,
    required this.price,
    required this.category,
    required this.fallbackImagePath,
    required this.color,
    this.isPopular = false,
    this.customImagePath,
  });
}

class CartItem {
  final MenuItem item;
  int quantity;
  CartItem(this.item, this.quantity);

  String get name => item.name;
  double get price => item.price;
}

/// =====================
/// SHARED POS WIDGET
/// =====================
class SharedPOSWidget extends StatefulWidget {
  final String userRole;
  const SharedPOSWidget({super.key, required this.userRole});

  @override
  State<SharedPOSWidget> createState() => _SharedPOSWidgetState();
}

class _SharedPOSWidgetState extends State<SharedPOSWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Removed unused ImagePicker _picker

  final List<String> categories = [
    'Yangchow Family Bundles',
    'Vegetables',
    'Special Noodles',
    'Soup',
    'Seafood',
    'Roast and Soy Specialties',
    'Pork',
    'Noodles',
    'Mami or Noodles',
    'Hot Pot Specialties',
    'Fried Rice or Rice',
    'Dimsum',
    'Congee',
    'Chicken',
    'Beef',
    'Appetizer',
  ];

  final Map<String, List<String>> categoryImages = {
    'Yangchow Family Bundles': [
      'assets/YC1.png',
      'assets/YC2.png',
      'assets/YC3.jpg',
      'assets/YC4.jpg',
      'assets/Overloadmeals.png',
      'assets/MPEHotPot.png',
    ],
    'Vegetables': [
      'assets/HSSalad.jpg',
      'assets/Lohanchay.png',
      'assets/BihonGuisado.jpg',
      'assets/FreshEgg.jpg',
    ],
    'Special Noodles': [
      'assets/YCFriedRice.png',
      'assets/PancitCLM.jpg',
      'assets/BBNoodles.png',
      'assets/BBWantonN.jpg',
      'assets/SBHofan.jpg',
    ],
    'Soup': [
      'assets/CNoodleMM.jpg',
      'assets/WantonNoodles.jpg',
      'assets/HSSoup.jpg',
      'assets/SSSoup.jpg',
      'assets/NSoupQE.png',
    ],
    'Seafood': [
      'assets/BFShrimp.jpg',
      'assets/FFilletSA.jpg',
      'assets/BFOyster.png',
      'assets/TPOyster.png',
      'assets/JellyFish.jpg',
      'assets/CenturyEgg.jpg',
    ],
    'Roast and Soy Specialties': [
      'assets/LechonMacau.jpg',
      'assets/YCFChicken.jpg',
      'assets/LemonChicken.jpg',
      'assets/ButteredChicken.jpg',
      'assets/ChickenFeet.jpg',
    ],
    'Pork': [
      'assets/PatatimCuapao.jpg',
      'assets/RPAsado.jpg',
      'assets/CuapaoMantau.jpg',
      'assets/AsadoSiopao.png',
    ],
    'Noodles': [
      'assets/BBNoodles.png',
      'assets/BBWantonN.jpg',
      'assets/SBHofan.jpg',
      'assets/BihonGuisado.jpg',
    ],
    'Mami or Noodles': [
      'assets/BeefBLK.jpg',
      'assets/CNoodleMM.jpg',
      'assets/WantonNoodles.jpg',
    ],
    'Hot Pot Specialties': [
      'assets/STHotPot.jpg',
      'assets/FFTHotPot.jpg',
      'assets/BBRHotPot.jpg',
      'assets/MPEHotPot.png',
    ],
    'Fried Rice or Rice': [
      'assets/BeefFriedRice.png',
      'assets/CSFFriedRice.jpg',
      'assets/YCFriedRice.png',
    ],
    'Dimsum': [
      'assets/LumpiangShanghai.jpg',
      'assets/BBSiopao.jpg',
      'assets/AsadoSiopao.png',
      'assets/CuapaoMantau.jpg',
    ],
    'Congee': [
      'assets/PLCongee.jpg',
      'assets/BBCongee.jpg',
      'assets/CenturyEgg.jpg',
      'assets/JellyFCE.jpg',
    ],
    'Chicken': [
      'assets/LemonChicken.jpg',
      'assets/YCFChicken.jpg',
      'assets/ButteredChicken.jpg',
      'assets/ChickenFeet.jpg',
    ],
    'Beef': [
      'assets/BeefGP.png',
      'assets/BeefBF.jpg',
      'assets/BeefBLK.jpg',
      'assets/BeefFriedRice.png',
    ],
    'Appetizer': [
      'assets/LumpiangShanghai.jpg',
      'assets/Calamares.jpg',
      'assets/JellyFish.jpg',
      'assets/CenturyEgg.jpg',
      'assets/FreshEgg.jpg',
      'assets/SOkSauce.jpg',
    ],
    'default': ['assets/YCFriedRice.png'],
  };

  final Map<String, int> _categoryImageIndex = {};
  late Map<String, List<MenuItem>> menu;
  List<CartItem> cart = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: categories.length, vsync: this);
    menu = {for (var cat in categories) cat: []};
    _buildMenu();
  }

  String _nextImage(String category) {
    final images = categoryImages[category] ?? categoryImages['default']!;
    final index = _categoryImageIndex[category] ?? 0;
    final img = images[index];
    _categoryImageIndex[category] = (index + 1) % images.length;
    return img;
  }

  void _buildMenu() {
    menu['Yangchow Family Bundles']!.addAll([
      _item(
        'Family Bundle A',
        1880.80,
        'Yangchow Family Bundles',
        Colors.orange,
        isPopular: true,
      ),
      _item(
        'Family Bundle B',
        1880.80,
        'Yangchow Family Bundles',
        Colors.deepOrange,
      ),
      _item(
        'Family Bundle C',
        3588.80,
        'Yangchow Family Bundles',
        Colors.deepOrange,
      ),
      _item(
        'Family Bundle D',
        4588.80,
        'Yangchow Family Bundles',
        Colors.deepOrange,
      ),
      _item(
        'Overload Meal',
        298.80,
        'Yangchow Family Bundles',
        Colors.deepOrange,
      ),
    ]);
    menu['Vegetables']!.addAll([
      _item('Chopsuey', 160, 'Vegetables', Colors.green, 
        customImagePath: 'assets/Chopsuey.png', isPopular: true),
      _item('Kangkong Garlic', 140, 'Vegetables', Colors.lightGreen,
        customImagePath: 'assets/KangkongGarlic.png'),
    ]);
    menu['Special Noodles']!.addAll([
      _item(
        'Yang Chow Fried Noodles',
        220,
        'Special Noodles',
        Colors.amber,
        customImagePath: 'assets/YCFriedRice.png', isPopular: true),
      _item('Pancit Canton', 200, 'Special Noodles', Colors.orange,
        customImagePath: 'assets/PancitCLM.jpg'),
    ]);
    menu['Soup']!.addAll([
      _item('Corn Soup', 120, 'Soup', Colors.yellow,
        customImagePath: 'assets/CNoodleMM.jpg'),
      _item('Wonton Soup', 130, 'Soup', Colors.orange, 
        customImagePath: 'assets/WantonNoodles.png', isPopular: true),
    ]);
    menu['Seafood']!.addAll([
      _item('Garlic Shrimp', 300, 'Seafood', Colors.lightBlue,
        customImagePath: 'assets/BFShrimp.jpg'),
      _item('Steamed Fish', 320, 'Seafood', Colors.cyan,
        customImagePath: 'assets/FFilletSA.jpg'),
    ]);
    menu['Roast and Soy Specialties']!.addAll([
      _item(
        'Roast Duck',
        350,
        'Roast and Soy Specialties',
        Colors.brown,
        customImagePath: 'assets/LechonMacau.jpg', isPopular: true),
      _item('Soy Chicken', 280, 'Roast and Soy Specialties', Colors.amber,
        customImagePath: 'assets/YCFChicken.jpg'),
    ]);
    menu['Pork']!.addAll([
      _item('Sweet & Sour Pork', 220, 'Pork', Colors.red, 
        customImagePath: 'assets/ButteredChicken.jpg', isPopular: true),
      _item('Pork Asado', 200, 'Pork', Colors.brown,
        customImagePath: 'assets/PatatimCuapao.jpg'),
    ]);
    menu['Noodles']!.addAll([
      _item('Lo Mein', 180, 'Noodles', Colors.orange,
        customImagePath: 'assets/BBNoodles.png'),
      _item('Sotanghon', 150, 'Noodles', Colors.lime,
        customImagePath: 'assets/BBWantonN.jpg'),
    ]);
    menu['Mami or Noodles']!.addAll([
      _item('Beef Mami', 120, 'Mami or Noodles', Colors.brown, 
        customImagePath: 'assets/BeefBLK.jpg', isPopular: true),
      _item('Chicken Mami', 110, 'Mami or Noodles', Colors.amber,
        customImagePath: 'assets/CNoodleMM.jpg'),
    ]);
    menu['Hot Pot Specialties']!.addAll([
      _item(
        'Seafood Hot Pot',
        450,
        'Hot Pot Specialties',
        Colors.deepOrange,
        customImagePath: 'assets/STHotPot.jpg', isPopular: true),
      _item('Vegetable Hot Pot', 350, 'Hot Pot Specialties', Colors.green,
        customImagePath: 'assets/FFTHotPot.jpg'),
    ]);
    menu['Fried Rice or Rice']!.addAll([
      _item(
        'Yang Chow Fried Rice',
        180,
        'Fried Rice or Rice',
        Colors.orange,
        customImagePath: 'assets/BeefFriedRice.png', isPopular: true),
      _item('Plain Rice', 30, 'Fried Rice or Rice', Colors.white70,
        customImagePath: 'assets/CSFFriedRice.jpg'),
    ]);
    menu['Dimsum']!.addAll([
      _item('Siomai', 60, 'Dimsum', Colors.orange, 
        customImagePath: 'assets/LumpiangShanghai.jpg', isPopular: true),
      _item('Hakaw', 70, 'Dimsum', Colors.lightBlue,
        customImagePath: 'assets/BBSiopao.jpg'),
    ]);
    menu['Congee']!.addAll([
      _item('Beef Congee', 100, 'Congee', Colors.brown, 
        customImagePath: 'assets/PLCongee.jpg', isPopular: true),
      _item('Plain Lugaw', 60, 'Congee', Colors.grey,
        customImagePath: 'assets/CenturyEgg.jpg'),
    ]);
    menu['Chicken']!.addAll([
      _item('Chicken Adobo', 200, 'Chicken', Colors.brown, 
        customImagePath: 'assets/LemonChicken.jpg', isPopular: true),
      _item('Kung Pao Chicken', 230, 'Chicken', Colors.red,
        customImagePath: 'assets/CuapaoMantau.jpg'),
    ]);
    menu['Beef']!.addAll([
      _item('Beef Broccoli', 250, 'Beef', Colors.green, 
        customImagePath: 'assets/BeefGP.png', isPopular: true),
      _item('Beef Steak', 280, 'Beef', Colors.red,
        customImagePath: 'assets/BeefBF.jpg'),
    ]);
    menu['Appetizer']!.addAll([
      _item('Lumpia Shanghai', 80, 'Appetizer', Colors.brown, 
        customImagePath: 'assets/LumpiangShanghai.jpg', isPopular: true),
      _item('Fried Tofu', 60, 'Appetizer', Colors.amber,
        customImagePath: 'assets/Calamares.jpg'),
    ]);
  }

  MenuItem _item(
    String name,
    double price,
    String category,
    Color color, {
    bool isPopular = false,
    String? customImagePath,
  }) {
    return MenuItem(
      name: name,
      price: price,
      category: category,
      fallbackImagePath: customImagePath ?? _nextImage(category),
      color: color,
      isPopular: isPopular,
      customImagePath: customImagePath,
    );
  }

  // Fixed: replaced Container whitespace with SizedBox (sized_box_for_whitespace lint)
  Widget _buildImageWidget(MenuItem item) {
    if (item.customImagePath != null) {
      return Image.asset(
        item.customImagePath!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => const SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: ColoredBox(
            color: Color(0xFFE0E0E0),
            child: Icon(Icons.broken_image, color: Colors.grey),
          ),
        ),
      );
    }
    return Image.asset(
      item.fallbackImagePath,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) => const SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: ColoredBox(
          color: Color(0xFFE0E0E0),
          child: Icon(Icons.image, color: Colors.grey),
        ),
      ),
    );
  }

  void addToCart(MenuItem item) {
    final index = cart.indexWhere((e) => e.item.name == item.name);
    setState(() {
      if (index >= 0) {
        cart[index].quantity++;
      } else {
        cart.add(CartItem(item, 1));
      }
    });
  }

  double get totalAmount =>
      cart.fold(0.0, (sum, c) => sum + (c.item.price * c.quantity));

  void _increaseQuantity(CartItem cartItem) =>
      setState(() => cartItem.quantity++);

  void _decreaseQuantity(CartItem cartItem) {
    setState(() {
      if (cartItem.quantity > 1) {
        cartItem.quantity--;
      } else {
        cart.remove(cartItem);
      }
    });
  }

  void _removeItem(CartItem cartItem) => setState(() => cart.remove(cartItem));

  void _generateReceipt() {
    if (cart.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cart is empty!')));
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Receipt'),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close, color: Colors.red, size: 24),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Yang Chow Restaurant',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text('=================='),
              const SizedBox(height: 8),
              ...cart.map(
                (c) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text('${c.item.name} x${c.quantity}')),
                      Text(
                        'P${(c.item.price * c.quantity).toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'P${totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showOrderList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                color: Colors.red,
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ORDER LIST',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: cart.isEmpty
                    ? const Center(
                        child: Text(
                          'No items in order',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(8),
                        itemCount: cart.length,
                        itemBuilder: (context, index) {
                          final item = cart[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.item.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'P${item.item.price.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          GestureDetector(
                                            onTap: () =>
                                                _decreaseQuantity(item),
                                            child: Container(
                                              width: 24,
                                              height: 24,
                                              decoration: const BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.remove,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Container(
                                            width: 30,
                                            alignment: Alignment.center,
                                            child: Text(
                                              '${item.quantity}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () =>
                                                _increaseQuantity(item),
                                            child: Container(
                                              width: 24,
                                              height: 24,
                                              decoration: const BoxDecoration(
                                                color: Colors.green,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.add,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Edit (TODO: implement)
                                          const Icon(
                                            Icons.edit,
                                            color: Colors.blue,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          GestureDetector(
                                            onTap: () => _removeItem(item),
                                            child: const Icon(
                                              Icons.delete,
                                              color: Colors.red,
                                              size: 20,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border(top: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const TextField(
                      decoration: InputDecoration(
                        labelText: 'Customer Name',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TOTAL:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'P${totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 36,
                      child: ElevatedButton(
                        onPressed: cart.isNotEmpty ? _generateReceipt : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text(
                          'PRINT RECEIPT',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      appBar: AppBar(
        title: isMobile
            ? null
            : const Text('POS MENU', style: TextStyle(fontSize: 16)),
        backgroundColor: Colors.red,
        automaticallyImplyLeading: false,
        toolbarHeight: 50,
        actions: [
          if (isMobile && cart.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.receipt, size: 20),
              onPressed: _showOrderList,
              padding: const EdgeInsets.all(8),
            ),
          if (isMobile && cart.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.print, size: 20),
              onPressed: _generateReceipt,
              padding: const EdgeInsets.all(8),
            ),
          if (!isMobile && cart.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.shopping_cart,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${cart.fold(0, (sum, item) => sum + item.quantity)}',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 768) {
            return Column(
              children: [
                Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabs: categories.map((c) => Tab(text: c)).toList(),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: categories.map((cat) {
                      final items = menu[cat]!;
                      return GridView.builder(
                        padding: const EdgeInsets.all(4),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.7,
                              crossAxisSpacing: 6,
                              mainAxisSpacing: 6,
                            ),
                        itemCount: items.length,
                        itemBuilder: (_, i) => _foodCard(items[i]),
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Container(
                      color: Colors.white,
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabs: categories.map((c) => Tab(text: c)).toList(),
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: categories.map((cat) {
                          final items = menu[cat]!;
                          return LayoutBuilder(
                            builder: (context, constraints) {
                              int crossAxisCount;
                              double childAspectRatio;
                              if (constraints.maxWidth > 1200) {
                                crossAxisCount = 4;
                                childAspectRatio = 0.8;
                              } else if (constraints.maxWidth > 800) {
                                crossAxisCount = 3;
                                childAspectRatio = 0.75;
                              } else if (constraints.maxWidth > 600) {
                                crossAxisCount = 2;
                                childAspectRatio = 0.7;
                              } else {
                                crossAxisCount = 1;
                                childAspectRatio = 1.2;
                              }
                              return GridView.builder(
                                padding: const EdgeInsets.all(12),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount,
                                      childAspectRatio: childAspectRatio,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                    ),
                                itemCount: items.length,
                                itemBuilder: (_, i) => _foodCard(items[i]),
                              );
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              OrderListPanel(
                cart: cart,
                onQuantityIncreased: _increaseQuantity,
                onQuantityDecreased: _decreaseQuantity,
                onRemoveItem: _removeItem,
                onPrintReceipt: _generateReceipt,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _foodCard(MenuItem item) {
    final cartItem = cart.firstWhere(
      (ci) => ci.item.name == item.name,
      orElse: () => CartItem(item, 0),
    );
    final quantity = cartItem.quantity;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: _buildImageWidget(item),
                ),
                if (item.isPopular)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'POPULAR',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 7,
                        ),
                      ),
                    ),
                  ),
                if (quantity > 0)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$quantity',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'P${item.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 24,
                    child: ElevatedButton(
                      onPressed: () => addToCart(item),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Text(
                        'ADD',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ),
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
