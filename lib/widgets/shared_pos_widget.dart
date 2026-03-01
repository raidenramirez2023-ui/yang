import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import 'dart:core';
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
/// RECEIPT TEMPLATE
/// =====================
class ReceiptTemplate extends StatelessWidget {
  final List<CartItem> cart;
  final double totalAmount;
  final String? customerName;
  final String paymentMethod;
  final String transactionId;
  final DateTime transactionDate;

  ReceiptTemplate({
    super.key,
    required this.cart,
    required this.totalAmount,
    this.customerName,
    this.paymentMethod = 'VISA',
    this.transactionId = '97413347',
    DateTime? transactionDate,
  }) : transactionDate = transactionDate ?? DateTime.now();

  String get _formattedDate {
    return '${transactionDate.month.toString().padLeft(2, '0')}/${transactionDate.day.toString().padLeft(2, '0')}/${transactionDate.year}';
  }

  String get _formattedTime {
    final hour = transactionDate.hour;
    final minute = transactionDate.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute$period';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300, // Standard receipt width
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - Restaurant Info
          const Center(
            child: Column(
              children: [
                Text(
                  'YANG CHOW',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'RESTAURANT',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Order Number
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ORDER:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('#${transactionId.substring(0, 3)}'),
            ],
          ),
          
          // Host and Date/Time - Matching the image style
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('HOST: ${customerName ?? 'BOB'}'),
              Text('$_formattedDate    $_formattedTime'),
            ],
          ),
          
          const Divider(thickness: 1, height: 24),
          
          // Column Headers
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Text('QTY', style: _headerStyle),
              ),
              Expanded(
                flex: 5,
                child: Text('ITEM', style: _headerStyle),
              ),
              Expanded(
                flex: 3,
                child: Text('PRICE', style: _headerStyle, textAlign: TextAlign.right),
              ),
            ],
          ),
          
          const Divider(thickness: 1, height: 8),
          
          // Cart Items
          ...cart.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text('${item.quantity}'),
                ),
                Expanded(
                  flex: 5,
                  child: Text(
                    item.item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'P${NumberFormat('#,##0.00', 'en_US').format(item.item.price * item.quantity)}',  
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          )),
          
          const Divider(thickness: 1, height: 16),
          
          // Separator line
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: const Text('---', style: TextStyle(letterSpacing: 4)),
          ),
          
          // Payment Info - VISA SALE
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('VISA', style: TextStyle(fontWeight: FontWeight.bold)),
              const Text('SALE', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Totals
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('SUBTOTAL'),
              Text('P ${NumberFormat('#,##0.00', 'en_US').format(totalAmount)}'),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TAX'),
              const Text('P 0.00'),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('P ${NumberFormat('#,##0.00', 'en_US').format(totalAmount)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          
          const Divider(thickness: 1, height: 16),
          
          // Transaction Details
          _buildTransactionRow('TRANSACTION TYPE:', 'SALE'),
          _buildTransactionRow('AUTHORIZATION:', 'APPROVED'),
          _buildTransactionRow('PAYMENT CODE:', transactionId),
          _buildTransactionRow('PAYMENT ID:', '132427422'),
          _buildTransactionRow('CARD READER:', 'SWIPED/CHIP'),
          
          const SizedBox(height: 16),
          
          // Tip and Total lines
          Row(
            children: [
              const Expanded(
                flex: 2,
                child: Text('TIP:', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              Expanded(
                flex: 3,
                child: Container(
                  height: 20,
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey[400]!)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                flex: 2,
                child: Text('TOTAL:', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              Expanded(
                flex: 3,
                child: Container(
                  height: 20,
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey[400]!)),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Signature line
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  height: 20,
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey[400]!)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text('X', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Footer
          const Center(
            child: Column(
              children: [
                Text('CUSTOMER COPY',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                SizedBox(height: 4),
                Text('THANKS FOR VISITING',
                    style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextStyle get _headerStyle => const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 12,
      );

  Widget _buildTransactionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11)),
          Text(value, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
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
      'assets/images/YC1.png',
      'assets/images/YC2.png',
      'assets/images/YC3.jpg',
      'assets/images/YC4.jpg',
      'assets/images/Overloadmeals.png',
      'assets/images/MPEHotPot.png',
      'assets/images/yc.jpg',
    ],
    'Vegetables': [
      'assets/images/HSSalad.jpg',
      'assets/images/Lohanchay.png',
      'assets/images/BihonGuisado.jpg',
      'assets/images/FreshEgg.jpg',
      'assets/images/CenturyEgg.jpg',
      'assets/images/JellyFCE.jpg',
    ],
    'Special Noodles': [
      'assets/images/YCFriedRice.jpg',
      'assets/images/PancitCLM.jpg',
      'assets/images/BBNoodles.png',
      'assets/images/BBWantonN.jpg',
      'assets/images/SBHofan.jpg',
      'assets/images/WantonNoodles.jpg',
      'assets/images/BeefFriedRice.png',
    ],
    'Soup': [
      'assets/images/CNoodleMM.jpg',
      'assets/images/WantonNoodles.jpg',
      'assets/images/HSSoup.jpg',
      'assets/images/SSSoup.jpg',
      'assets/images/NSoupQE.png',
      'assets/images/PLCongee.jpg',
      'assets/images/BBCongee.jpg',
    ],
    'Seafood': [
      'assets/images/BFShrimp.jpg',
      'assets/images/FFilletSA.jpg',
      'assets/images/BFOyster.png',
      'assets/images/TPOyster.png',
      'assets/images/JellyFish.jpg',
      'assets/images/CenturyEgg.jpg',
      'assets/images/Calamares.jpg',
    ],
    'Roast and Soy Specialties': [
      'assets/images/LechonMacau.jpg',
      'assets/images/YCFChicken.jpg',
      'assets/images/LemonChicken.jpg',
      'assets/images/ButteredChicken.jpg',
      'assets/images/ChickenFeet.jpg',
      'assets/images/RPAsado.jpg',
    ],
    'Pork': [
      'assets/images/PatatimCuapao.jpg',
      'assets/images/RPAsado.jpg',
      'assets/images/CuapaoMantau.jpg',
      'assets/images/AsadoSiopao.png',
      'assets/images/BBSiopao.jpg',
      'assets/images/LumpiangShanghai.jpg',
    ],
    'Noodles': [
      'assets/images/BBNoodles.png',
      'assets/images/BBWantonN.jpg',
      'assets/images/SBHofan.jpg',
      'assets/images/BihonGuisado.jpg',
      'assets/images/PancitCLM.jpg',
      'assets/images/WantonNoodles.jpg',
    ],
    'Mami or Noodles': [
      'assets/images/BeefBLK.jpg',
      'assets/images/CNoodleMM.jpg',
      'assets/images/WantonNoodles.jpg',
      'assets/images/BBNoodles.png',
      'assets/images/BBWantonN.jpg',
    ],
    'Hot Pot Specialties': [
      'assets/images/STHotPot.jpg',
      'assets/images/FFTHotPot.jpg',
      'assets/images/BBRHotPot.jpg',
      'assets/images/MPEHotPot.png',
      'assets/images/TPOyster.png',
      'assets/images/BFOyster.png',
    ],
    'Fried Rice or Rice': [
      'assets/images/BeefFriedRice.png',
      'assets/images/CSFFriedRice.jpg',
      'assets/images/YCFriedRice.jpg',
      'assets/images/Overloadmeals.png',
    ],
    'Dimsum': [
      'assets/images/LumpiangShanghai.jpg',
      'assets/images/BBSiopao.jpg',
      'assets/images/AsadoSiopao.png',
      'assets/images/CuapaoMantau.jpg',
      'assets/images/PatatimCuapao.jpg',
    ],
    'Congee': [
      'assets/images/PLCongee.jpg',
      'assets/images/BBCongee.jpg',
      'assets/images/CenturyEgg.jpg',
      'assets/images/JellyFCE.jpg',
      'assets/images/CNoodleMM.jpg',
    ],
    'Chicken': [
      'assets/images/LemonChicken.jpg',
      'assets/images/YCFChicken.jpg',
      'assets/images/ButteredChicken.jpg',
      'assets/images/ChickenFeet.jpg',
      'assets/images/BeefBLK.jpg',
    ],
    'Beef': [
      'assets/images/BeefGP.png',
      'assets/images/BeefBF.jpg',
      'assets/images/BeefBLK.jpg',
      'assets/images/BeefFriedRice.png',
      'assets/images/RPAsado.jpg',
      'assets/images/PatatimCuapao.jpg',
    ],
    'Appetizer': [
      'assets/images/LumpiangShanghai.jpg',
      'assets/images/Calamares.jpg',
      'assets/images/JellyFish.jpg',
      'assets/images/CenturyEgg.jpg',
      'assets/images/FreshEgg.jpg',
      'assets/images/SOkSauce.jpg',
      'assets/images/JellyFCE.jpg',
      'assets/images/ChickenFeet.jpg',
    ],
    'default': ['assets/images/YCFriedRice.jpg'],
  };

  final Map<String, int> _categoryImageIndex = {};
  late Map<String, List<MenuItem>> menu;
  List<CartItem> cart = [];
  final TextEditingController _mobileCustomerNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: categories.length, vsync: this);
    menu = {for (var cat in categories) cat: []};
    _buildMenu();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _mobileCustomerNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _nextImage(String category) {
    final images = categoryImages[category] ?? categoryImages['default']!;
    final index = _categoryImageIndex[category] ?? 0;
    final img = images[index];
    _categoryImageIndex[category] = (index + 1) % images.length;
    return img;
  }

  void _buildMenu() {
    // ── Yangchow Family Bundles ──────────────────────────────────────────────
    menu['Yangchow Family Bundles']!.addAll([
      _item('Family Bundle A', 1880.80, 'Yangchow Family Bundles', Colors.orange,
          customImagePath: 'assets/images/YC1.png', isPopular: true),
      _item('Family Bundle B', 1880.80, 'Yangchow Family Bundles', Colors.deepOrange,
          customImagePath: 'assets/images/YC2.png'),
      _item('Family Bundle C', 3588.80, 'Yangchow Family Bundles', Colors.deepOrange,
          customImagePath: 'assets/images/YC3.jpg'),
      _item('Family Bundle D', 4588.80, 'Yangchow Family Bundles', Colors.deepOrange,
          customImagePath: 'assets/images/YC4.jpg'),
      _item('Overload Meal', 298.80, 'Yangchow Family Bundles', Colors.deepOrange,
          customImagePath: 'assets/images/Overloadmeals.png'),
    ]);

    // ── Vegetables ───────────────────────────────────────────────────────────
    menu['Vegetables']!.addAll([
      _item('Chopsuey', 160, 'Vegetables', Colors.green,
          customImagePath: 'assets/images/Lohanchay.png', isPopular: true),
      _item('Hot Salad', 140, 'Vegetables', Colors.lightGreen,
          customImagePath: 'assets/images/HSSalad.jpg'),
      _item('Bihon Guisado', 150, 'Vegetables', Colors.green,
          customImagePath: 'assets/images/BihonGuisado.jpg'),
      _item('Fresh Egg', 80, 'Vegetables', Colors.yellow,
          customImagePath: 'assets/images/FreshEgg.jpg'),
      _item('Century Egg', 90, 'Vegetables', Colors.brown,
          customImagePath: 'assets/images/CenturyEgg.jpg'),
      _item('Jelly Fish Century Egg', 120, 'Vegetables', Colors.orange,
          customImagePath: 'assets/images/JellyFCE.jpg'),
    ]);

    // ── Special Noodles ──────────────────────────────────────────────────────
    menu['Special Noodles']!.addAll([
      _item('Yang Chow Fried Noodles', 220, 'Special Noodles', Colors.amber,
          customImagePath: 'assets/images/YCFriedRice.jpg', isPopular: true),
      _item('Pancit Canton', 200, 'Special Noodles', Colors.orange,
          customImagePath: 'assets/images/PancitCLM.jpg'),
      _item('Big Bowl Noodles', 180, 'Special Noodles', Colors.red,
          customImagePath: 'assets/images/BBNoodles.png'),
      _item('Big Bowl Wonton Noodles', 190, 'Special Noodles', Colors.purple,
          customImagePath: 'assets/images/BBWantonN.jpg'),
      _item('Sotanghon Bihon', 170, 'Special Noodles', Colors.lime,
          customImagePath: 'assets/images/SBHofan.jpg'),
      _item('Wanton Noodles', 160, 'Special Noodles', Colors.brown,
          customImagePath: 'assets/images/WantonNoodles.jpg'),
      _item('Beef Fried Rice Noodles', 210, 'Special Noodles', Colors.deepOrange,
          customImagePath: 'assets/images/BeefFriedRice.png'),
    ]);

    // ── Soup ─────────────────────────────────────────────────────────────────
    menu['Soup']!.addAll([
      _item('Corn Soup', 120, 'Soup', Colors.yellow,
          customImagePath: 'assets/images/CNoodleMM.jpg'),
      _item('Wonton Soup', 130, 'Soup', Colors.orange,
          customImagePath: 'assets/images/WantonNoodles.jpg', isPopular: true),
      _item('Hot Sour Soup', 110, 'Soup', Colors.red,
          customImagePath: 'assets/images/HSSoup.jpg'),
      _item('Special Soup', 125, 'Soup', Colors.purple,
          customImagePath: 'assets/images/SSSoup.jpg'),
      _item('Noodle Soup', 140, 'Soup', Colors.brown,
          customImagePath: 'assets/images/NSoupQE.png'),
      _item('Plain Congee', 90, 'Soup', Colors.grey,
          customImagePath: 'assets/images/PLCongee.jpg'),
      _item('Beef Congee', 100, 'Soup', Colors.deepOrange,
          customImagePath: 'assets/images/BBCongee.jpg'),
    ]);

    // ── Seafood ──────────────────────────────────────────────────────────────
    menu['Seafood']!.addAll([
      _item('Garlic Shrimp', 300, 'Seafood', Colors.lightBlue,
          customImagePath: 'assets/images/BFShrimp.jpg'),
      _item('Steamed Fish', 320, 'Seafood', Colors.cyan,
          customImagePath: 'assets/images/FFilletSA.jpg'),
      _item('Big Fried Oyster', 350, 'Seafood', Colors.orange,
          customImagePath: 'assets/images/BFOyster.png'),
      _item('Tiger Prawns Oyster', 380, 'Seafood', Colors.red,
          customImagePath: 'assets/images/TPOyster.png'),
      _item('Jelly Fish', 280, 'Seafood', Colors.pink,
          customImagePath: 'assets/images/JellyFish.jpg'),
      _item('Century Egg', 150, 'Seafood', Colors.brown,
          customImagePath: 'assets/images/CenturyEgg.jpg'),
      _item('Calamares', 260, 'Seafood', Colors.deepOrange,
          customImagePath: 'assets/images/Calamares.jpg'),
    ]);

    // ── Roast and Soy Specialties ────────────────────────────────────────────
    menu['Roast and Soy Specialties']!.addAll([
      _item('Roast Duck', 350, 'Roast and Soy Specialties', Colors.brown,
          customImagePath: 'assets/images/LechonMacau.jpg', isPopular: true),
      _item('Soy Chicken', 280, 'Roast and Soy Specialties', Colors.amber,
          customImagePath: 'assets/images/YCFChicken.jpg'),
      _item('Lemon Chicken', 260, 'Roast and Soy Specialties', Colors.yellow,
          customImagePath: 'assets/images/LemonChicken.jpg'),
      _item('Buttered Chicken', 240, 'Roast and Soy Specialties', Colors.orange,
          customImagePath: 'assets/images/ButteredChicken.jpg'),
      _item('Chicken Feet', 180, 'Roast and Soy Specialties', Colors.red,
          customImagePath: 'assets/images/ChickenFeet.jpg'),
      _item('Red Pork Asado', 220, 'Roast and Soy Specialties', Colors.pink,
          customImagePath: 'assets/images/RPAsado.jpg'),
    ]);

    // ── Pork ─────────────────────────────────────────────────────────────────
    menu['Pork']!.addAll([
      _item('Sweet & Sour Pork', 220, 'Pork', Colors.red,
          customImagePath: 'assets/images/ButteredChicken.jpg', isPopular: true),
      _item('Pork Asado', 200, 'Pork', Colors.brown,
          customImagePath: 'assets/images/PatatimCuapao.jpg'),
      _item('Red Pork Asado', 210, 'Pork', Colors.pink,
          customImagePath: 'assets/images/RPAsado.jpg'),
      _item('Cuapao Mantau', 180, 'Pork', Colors.orange,
          customImagePath: 'assets/images/CuapaoMantau.jpg'),
      _item('Asado Siopao', 160, 'Pork', Colors.amber,
          customImagePath: 'assets/images/AsadoSiopao.png'),
      _item('Big Bowl Siopao', 140, 'Pork', Colors.purple,
          customImagePath: 'assets/images/BBSiopao.jpg'),
      _item('Lumpiang Shanghai', 120, 'Pork', Colors.green,
          customImagePath: 'assets/images/LumpiangShanghai.jpg'),
    ]);

    // ── Noodles ──────────────────────────────────────────────────────────────
    menu['Noodles']!.addAll([
      _item('Lo Mein', 180, 'Noodles', Colors.orange,
          customImagePath: 'assets/images/BBNoodles.png'),
      _item('Sotanghon', 150, 'Noodles', Colors.lime,
          customImagePath: 'assets/images/BBWantonN.jpg'),
      _item('Sotanghon Bihon', 170, 'Noodles', Colors.green,
          customImagePath: 'assets/images/SBHofan.jpg'),
      _item('Bihon Guisado', 160, 'Noodles', Colors.yellow,
          customImagePath: 'assets/images/BihonGuisado.jpg'),
      _item('Pancit Canton', 190, 'Noodles', Colors.red,
          customImagePath: 'assets/images/PancitCLM.jpg'),
      _item('Wanton Noodles', 175, 'Noodles', Colors.purple,
          customImagePath: 'assets/images/WantonNoodles.jpg'),
    ]);

    // ── Mami or Noodles ──────────────────────────────────────────────────────
    menu['Mami or Noodles']!.addAll([
      _item('Beef Mami', 120, 'Mami or Noodles', Colors.brown,
          customImagePath: 'assets/images/BeefBLK.jpg', isPopular: true),
      _item('Chicken Mami', 110, 'Mami or Noodles', Colors.amber,
          customImagePath: 'assets/images/CNoodleMM.jpg'),
      _item('Wanton Noodles', 130, 'Mami or Noodles', Colors.orange,
          customImagePath: 'assets/images/WantonNoodles.jpg'),
      _item('Big Bowl Noodles', 125, 'Mami or Noodles', Colors.red,
          customImagePath: 'assets/images/BBNoodles.png'),
      _item('Big Bowl Wonton Noodles', 135, 'Mami or Noodles', Colors.purple,
          customImagePath: 'assets/images/BBWantonN.jpg'),
    ]);

    // ── Hot Pot Specialties ──────────────────────────────────────────────────
    menu['Hot Pot Specialties']!.addAll([
      _item('Seafood Hot Pot', 450, 'Hot Pot Specialties', Colors.deepOrange,
          customImagePath: 'assets/images/STHotPot.jpg', isPopular: true),
      _item('Vegetable Hot Pot', 350, 'Hot Pot Specialties', Colors.green,
          customImagePath: 'assets/images/FFTHotPot.jpg'),
      _item('Big Bowl Hot Pot', 380, 'Hot Pot Specialties', Colors.red,
          customImagePath: 'assets/images/BBRHotPot.jpg'),
      _item('MPE Hot Pot', 420, 'Hot Pot Specialties', Colors.purple,
          customImagePath: 'assets/images/MPEHotPot.png'),
      _item('Tiger Prawns Oyster', 480, 'Hot Pot Specialties', Colors.orange,
          customImagePath: 'assets/images/TPOyster.png'),
      _item('Big Fried Oyster', 460, 'Hot Pot Specialties', Colors.pink,
          customImagePath: 'assets/images/BFOyster.png'),
    ]);

    // ── Fried Rice or Rice ───────────────────────────────────────────────────
    menu['Fried Rice or Rice']!.addAll([
      _item('Yang Chow Fried Rice', 180, 'Fried Rice or Rice', Colors.orange,
          customImagePath: 'assets/images/BeefFriedRice.png', isPopular: true),
      _item('Plain Rice', 30, 'Fried Rice or Rice', Colors.white70,
          customImagePath: 'assets/images/CSFFriedRice.jpg'),
      _item('Chinese Style Fried Rice', 190, 'Fried Rice or Rice', Colors.red,
          customImagePath: 'assets/images/YCFriedRice.jpg'),
      _item('Overload Meal Rice', 250, 'Fried Rice or Rice', Colors.deepOrange,
          customImagePath: 'assets/images/Overloadmeals.png'),
    ]);

    // ── Dimsum ───────────────────────────────────────────────────────────────
    menu['Dimsum']!.addAll([
      _item('Siomai', 60, 'Dimsum', Colors.orange,
          customImagePath: 'assets/images/LumpiangShanghai.jpg', isPopular: true),
      _item('Hakaw', 70, 'Dimsum', Colors.lightBlue,
          customImagePath: 'assets/images/BBSiopao.jpg'),
      _item('Asado Siopao', 65, 'Dimsum', Colors.purple,
          customImagePath: 'assets/images/AsadoSiopao.png'),
      _item('Cuapao Mantau', 55, 'Dimsum', Colors.amber,
          customImagePath: 'assets/images/CuapaoMantau.jpg'),
      _item('Patatim Cuapao', 75, 'Dimsum', Colors.brown,
          customImagePath: 'assets/images/PatatimCuapao.jpg'),
    ]);

    // ── Congee ───────────────────────────────────────────────────────────────
    menu['Congee']!.addAll([
      _item('Beef Congee', 100, 'Congee', Colors.brown,
          customImagePath: 'assets/images/PLCongee.jpg', isPopular: true),
      _item('Plain Lugaw', 60, 'Congee', Colors.grey,
          customImagePath: 'assets/images/CenturyEgg.jpg'),
      _item('Beef Congee', 95, 'Congee', Colors.deepOrange,
          customImagePath: 'assets/images/BBCongee.jpg'),
      _item('Century Egg Congee', 85, 'Congee', Colors.yellow,
          customImagePath: 'assets/images/CenturyEgg.jpg'),
      _item('Jelly Fish Century Egg', 90, 'Congee', Colors.orange,
          customImagePath: 'assets/images/JellyFCE.jpg'),
      _item('Corn Noodle Congee', 110, 'Congee', Colors.amber,
          customImagePath: 'assets/images/CNoodleMM.jpg'),
    ]);

    // ── Chicken ──────────────────────────────────────────────────────────────
    menu['Chicken']!.addAll([
      _item('Chicken Adobo', 200, 'Chicken', Colors.brown,
          customImagePath: 'assets/images/LemonChicken.jpg', isPopular: true),
      _item('Kung Pao Chicken', 230, 'Chicken', Colors.red,
          customImagePath: 'assets/images/CuapaoMantau.jpg'),
      _item('Lemon Chicken', 210, 'Chicken', Colors.yellow,
          customImagePath: 'assets/images/LemonChicken.jpg'),
      _item('Yang Chow Fried Chicken', 190, 'Chicken', Colors.orange,
          customImagePath: 'assets/images/YCFChicken.jpg'),
      _item('Buttered Chicken', 180, 'Chicken', Colors.amber,
          customImagePath: 'assets/images/ButteredChicken.jpg'),
      _item('Chicken Feet', 150, 'Chicken', Colors.red,
          customImagePath: 'assets/images/ChickenFeet.jpg'),
    ]);

    // ── Beef ─────────────────────────────────────────────────────────────────
    menu['Beef']!.addAll([
      _item('Beef Broccoli', 250, 'Beef', Colors.green,
          customImagePath: 'assets/images/BeefGP.png', isPopular: true),
      _item('Beef Steak', 280, 'Beef', Colors.red,
          customImagePath: 'assets/images/BeefBF.jpg'),
      _item('Beef Black Pepper', 260, 'Beef', Colors.brown,
          customImagePath: 'assets/images/BeefBLK.jpg'),
      _item('Beef Fried Rice', 220, 'Beef', Colors.orange,
          customImagePath: 'assets/images/BeefFriedRice.png'),
      _item('Red Pork Asado', 240, 'Beef', Colors.pink,
          customImagePath: 'assets/images/RPAsado.jpg'),
      _item('Patatim Cuapao', 230, 'Beef', Colors.purple,
          customImagePath: 'assets/images/PatatimCuapao.jpg'),
    ]);

    // ── Appetizer ────────────────────────────────────────────────────────────
    menu['Appetizer']!.addAll([
      _item('Lumpia Shanghai', 80, 'Appetizer', Colors.brown,
          customImagePath: 'assets/images/LumpiangShanghai.jpg', isPopular: true),
      _item('Calamares', 90, 'Appetizer', Colors.deepOrange,
          customImagePath: 'assets/images/Calamares.jpg'),
      _item('Jelly Fish', 120, 'Appetizer', Colors.pink,
          customImagePath: 'assets/images/JellyFish.jpg'),
      _item('Century Egg', 70, 'Appetizer', Colors.brown,
          customImagePath: 'assets/images/CenturyEgg.jpg'),
      _item('Fresh Egg', 50, 'Appetizer', Colors.yellow,
          customImagePath: 'assets/images/FreshEgg.jpg'),
      _item('Soy Sauce', 30, 'Appetizer', Colors.black87,
          customImagePath: 'assets/images/SOkSauce.jpg'),
      _item('Jelly Fish Century Egg', 100, 'Appetizer', Colors.orange,
          customImagePath: 'assets/images/JellyFCE.jpg'),
      _item('Chicken Feet', 110, 'Appetizer', Colors.red,
          customImagePath: 'assets/images/ChickenFeet.jpg'),
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

  Widget _buildImageWidget(MenuItem item) {
    final imagePath = item.customImagePath ?? item.fallbackImagePath;
    return Image.asset(
      imagePath,
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

  void _generateReceipt([String customerName = '']) {
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Cart is empty!')));
      return;
    }

    // Snapshot the cart and total NOW — before the OrderListPanel
    // has a chance to clear the cart after calling this callback.
    final cartSnapshot = cart.map((c) => CartItem(c.item, c.quantity)).toList();
    final snapshotTotal = cartSnapshot.fold(
        0.0, (sum, c) => sum + (c.item.price * c.quantity));

    // Generate a random transaction ID
    final transactionId = '${DateTime.now().millisecond}${Random().nextInt(1000)}'.padRight(8, '0').substring(0, 8);

    // Persist to Supabase (fire-and-forget, errors shown via snackbar)
    _saveOrderToDatabase(
      cartSnapshot: cartSnapshot,
      total: snapshotTotal,
      customerName: customerName,
      transactionId: transactionId,
    );

    // Use the widget's own context (Scaffold context) so the dialog
    // displays above any modal bottom sheet that may be open.
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: ReceiptTemplate(
            cart: cartSnapshot,
            totalAmount: snapshotTotal,
            customerName: customerName.isNotEmpty ? customerName : null,
            paymentMethod: 'VISA',
            transactionId: transactionId,
            transactionDate: DateTime.now(),
          ),
        ),
      ),
    );
  }

  Future<void> _saveOrderToDatabase({
    required List<CartItem> cartSnapshot,
    required double total,
    required String customerName,
    required String transactionId,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      final staffEmail =
          supabase.auth.currentUser?.email ?? 'staff';

      // Insert the order header and get back the generated ID
      final orderRes = await supabase
          .from('orders')
          .insert({
            'transaction_id': transactionId,
            'customer_name':
                customerName.isNotEmpty ? customerName : 'Guest',
            'total_amount': total,
            'item_count': cartSnapshot.fold(0, (s, c) => s + c.quantity),
            'staff_email': staffEmail,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();

      final orderId = orderRes['id'].toString();

      // Insert each line item
      final itemRows = cartSnapshot
          .map((c) => {
                'order_id': orderId,
                'item_name': c.item.name,
                'quantity': c.quantity,
                'unit_price': c.item.price,
                'subtotal': c.item.price * c.quantity,
              })
          .toList();

      await supabase.from('order_items').insert(itemRows);
    } catch (e) {
      // Non-blocking: show a warning but don't block the receipt
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Could not save order to database: $e'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 24),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: cart.isEmpty
                    ? const Center(
                        child: Text('No items in order',
                            style: TextStyle(color: Colors.grey)))
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
                                        fontSize: 16),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'P${NumberFormat('#,##0.00', 'en_US').format(item.item.price)}',
                                        style: const TextStyle(
                                            fontSize: 14, color: Colors.grey),
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
                                                child: Icon(Icons.remove,
                                                    color: Colors.white,
                                                    size: 16),
                                              ),
                                            ),
                                          ),
                                          Container(
                                            width: 30,
                                            alignment: Alignment.center,
                                            child: Text('${item.quantity}',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16)),
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
                                                child: Icon(Icons.add,
                                                    color: Colors.white,
                                                    size: 16),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.edit,
                                              color: Colors.blue, size: 20),
                                          const SizedBox(width: 8),
                                          GestureDetector(
                                            onTap: () => _removeItem(item),
                                            child: const Icon(Icons.delete,
                                                color: Colors.red, size: 20),
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
                  border:
                      Border(top: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _mobileCustomerNameController,
                      decoration: const InputDecoration(
                        labelText: 'Customer Name',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('P${NumberFormat('#,##0.00', 'en_US').format(totalAmount)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.red)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 36,
                      child: ElevatedButton(
                        onPressed: cart.isNotEmpty
                            ? () {
                                // Close the bottom sheet first, then show
                                // the receipt dialog using the parent context.
                                Navigator.pop(context);
                                _generateReceipt(
                                  _mobileCustomerNameController.text.trim(),
                                );
                                _mobileCustomerNameController.clear();
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text('PRINT RECEIPT',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
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

  // ── Search Controller ─────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedCategoryIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (isMobile) {
      return _buildMobileLayout();
    }
    return _buildDesktopLayout();
  }

  // ── Mobile Layout ─────────────────────────────────────────────────────────
  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 56,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 255, 0, 0),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('P',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
            ),
            const SizedBox(width: 8),
            const Text('Order Menu',
                style: TextStyle(
                    color: Color(0xFF1A1A2E),
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
          ],
        ),
        actions: [
          if (cart.isNotEmpty)
            Stack(
              alignment: Alignment.topRight,
              children: [
                IconButton(
                  icon: const Icon(Icons.receipt_long,
                      color: Color.fromARGB(255, 255, 0, 0)),
                  onPressed: _showOrderList,
                ),
                if (cart.isNotEmpty)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                      child: Center(
                        child: Text(
                          '${cart.fold(0, (s, e) => s + e.quantity)}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: _buildSearchBar(),
          ),
          // Category chips
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: categories.length,
              itemBuilder: (_, i) => _buildCategoryChip(i),
            ),
          ),
          const SizedBox(height: 4),
          // Grid
          Expanded(
            child: _buildMenuGrid(crossAxisCount: 2, childAspectRatio: 0.72),
          ),
        ],
      ),
    );
  }

  // ── Desktop Layout ────────────────────────────────────────────────────────
  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Column(
        children: [
          // ── Top Header Bar ───────────────────────────────────────────────
          Container(
            height: 56,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // Logo + Title
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: Color.fromARGB(255, 255, 0, 0),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('P',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 10),
                const Text('Order Menu',
                    style: TextStyle(
                        color: Color(0xFF1A1A2E),
                        fontWeight: FontWeight.bold,
                        fontSize: 20)),
                const Spacer(),
                // Search bar
                SizedBox(width: 280, child: _buildSearchBar()),
                const SizedBox(width: 12),
                // Settings icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.tune_rounded,
                      size: 18, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          // ── Body Row ─────────────────────────────────────────────────────
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Center: Food Grid ──────────────────────────────────────
                Expanded(
                  flex: 13,
                  child: _buildMenuGrid(
                      crossAxisCount: 4, childAspectRatio: 0.82),
                ),
                // ── Right of grid: Category Sidebar ───────────────────────
                _buildCategorySidebar(),
                // ── Far Right: Order Panel ─────────────────────────────────
                OrderListPanel(
                  cart: cart,
                  onQuantityIncreased: _increaseQuantity,
                  onQuantityDecreased: _decreaseQuantity,
                  onRemoveItem: _removeItem,
                  onPrintReceipt: (customerName) =>
                      _generateReceipt(customerName),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Vertical category sidebar (desktop) ───────────────────────────────────
  Widget _buildCategorySidebar() {
    return Container(
      width: 150,
      color: Colors.white,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 14, 12, 8),
            child: Text(
              'Categories',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9CA3AF),
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: categories.length,
              itemBuilder: (_, i) => _buildSidebarItem(i),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index) {
    final selected = _selectedCategoryIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategoryIndex = index;
          _searchQuery = '';
          _searchController.clear();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFEEEdFD)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            if (selected)
              Container(
                width: 3,
                height: 16,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 255, 0, 0),
                  borderRadius: BorderRadius.circular(2),
                ),
              )
            else
              const SizedBox(width: 11), // same space as bar + margin
            Expanded(
              child: Text(
                categories[index],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? const Color.fromARGB(255, 255, 0, 0)
                      : const Color(0xFF374151),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared widgets ────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1F5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
        style: const TextStyle(fontSize: 13),
        decoration: const InputDecoration(
          hintText: 'Search',
          hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
          prefixIcon:
              Icon(Icons.search, color: Color(0xFF9CA3AF), size: 18),
          border: InputBorder.none,
          contentPadding:
              EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildCategoryChip(int index) {
    final selected = _selectedCategoryIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategoryIndex = index;
          _searchQuery = '';
          _searchController.clear();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4F46E5) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF4F46E5)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          categories[index],
          style: TextStyle(
            color:
                selected ? Colors.white : const Color(0xFF374151),
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuGrid(
      {required int crossAxisCount, required double childAspectRatio}) {
    final cat = categories[_selectedCategoryIndex];
    final allItems = menu[cat]!;
    final items = _searchQuery.isEmpty
        ? allItems
        : allItems
            .where((m) => m.name.toLowerCase().contains(_searchQuery))
            .toList();

    if (items.isEmpty) {
      return const Center(
          child: Text('No items found',
              style: TextStyle(color: Color(0xFF9CA3AF))));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _foodCard(items[i]),
    );
  }

  Widget _foodCard(MenuItem item) {
    final cartItem = cart.firstWhere(
      (ci) => ci.item.name == item.name,
      orElse: () => CartItem(item, 0),
    );
    final quantity = cartItem.quantity;
    final inCart = quantity > 0;

    return GestureDetector(
      onTap: () => addToCart(item),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: inCart
              ? Border.all(color: const Color.fromARGB(255, 255, 0, 0), width: 2)
              : Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Full-bleed image ────────────────────────────────────────
              _buildImageWidget(item),

              // ── Bottom gradient + text overlay ──────────────────────────
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Color(0xEE000000),
                        Color(0x99000000),
                        Colors.transparent,
                      ],
                      stops: [0.0, 0.6, 1.0],
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(8, 22, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 4),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            'P${NumberFormat('#,##0.00', 'en_US').format(item.price)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Popular badge (top-left) ────────────────────────────────
              if (item.isPopular)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Popular',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 8,
                      ),
                    ),
                  ),
                ),

              // ── Quantity badge (top-right) ──────────────────────────────
              if (inCart)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Color.fromARGB(255, 255, 0, 0),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$quantity',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}