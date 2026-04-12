import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'order_list_panel.dart';
import 'payment_panel.dart';
import '../services/recipe_service.dart';

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
  MenuItem({
    required this.name,
    required this.price,
    required this.category,
    required this.fallbackImagePath,
    required this.color,
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
  final String? note;
  final String paymentMethod;
  final String transactionId;
  final DateTime transactionDate;
  final double paidAmount;
  final double changeDue;
  final int? tableNumber;
  final int? guestCount;
  final String? serverName;
  final String? orderType; // WALK-IN, DINE IN
  final int terminalNumber;
  final String? cashierName;

  ReceiptTemplate({
    super.key,
    required this.cart,
    required this.totalAmount,
    this.customerName,
    this.note,
    this.paymentMethod = 'CASH',
    this.transactionId = '97413347',
    this.paidAmount = 0.0,
    this.changeDue = 0.0,
    DateTime? transactionDate,
    this.tableNumber,
    this.guestCount,
    this.serverName,
    this.orderType = 'WALK-IN',
    this.terminalNumber = 1,
    this.cashierName,
  }) : transactionDate = transactionDate ?? DateTime.now();

  String get _formattedDate {
    return '${transactionDate.month.toString().padLeft(2, '0')}/${transactionDate.day.toString().padLeft(2, '0')}/${transactionDate.year}';
  }

  String get _formattedTime24 {
    return '${transactionDate.hour.toString().padLeft(2, '0')}:${transactionDate.minute.toString().padLeft(2, '0')}:${transactionDate.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = cart.fold(
      0.0,
      (sum, item) => sum + (item.item.price * item.quantity),
    );
    final fmt = NumberFormat('#,##0.00', 'en_US');

    return Container(
      width: 283,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(0),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ===== HEADER SECTION =====
            const Text(
              'CEAZAR GABRIEL\'S RES',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
            ),
            const Text(
              'TAURANT',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
            ),
            const Text(
              'YANG CHOW',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
            ),
            const Text(
              'Owned & optd by:',
              style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
              textAlign: TextAlign.center,
            ),
            const Text(
              'Ceazar Gabriel R.  Areza',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
            ),
            const Text(
              'Areza Town Center Mall brgy. Bi\u00f1an',
              style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
              textAlign: TextAlign.center,
            ),
            const Text(
              'Pagsanjan Laguna',
              style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // ===== ORDER INFO SECTION =====
            // Row 1: Table # | No. of Guest
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Table #: ${tableNumber?.toString() ?? '32'}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  'No. of Guest:  ${guestCount?.toString() ?? '2'}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            // Row 2: Term. No. right-aligned
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Term. No.  $terminalNumber',
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ],
            ),
            const SizedBox(height: 2),

            // Row 3: WALK-IN left-aligned
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                orderType ?? 'WALK-IN',
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),

            // Row 4: Cahr | Server
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Cashr: ${cashierName ?? 'JANE'}',
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                Flexible(
                  child: Text(
                    'Server: ${serverName ?? 'bara 3'}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            _dashDivider(),
            const SizedBox(height: 3),

            Row(
              children: [
                const SizedBox(
                  width: 50,
                  child: Text(
                    'Qty',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      'Description(s)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  width: 110,
                  child: Text(
                    'Price',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            _dashDivider(),
            const SizedBox(height: 3),

            // ===== CATEGORY LABEL =====
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'DINE IN',
                style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),

            // Items (indented qty)
            ...cart.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 50,
                      child: Text(
                        '  ${item.quantity.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          item.item.name.toUpperCase(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 110,
                      child: Text(
                        fmt.format(item.item.price * item.quantity),
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 3),

            // ===== ITEM COUNT WITH DASHES =====
            Text(
              '----------------------------${cart.length} Item(s)-----------------------------',
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.clip,
            ),

            const SizedBox(height: 6),

            // ===== SUBTOTAL & TOTAL SECTION =====
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '  Sub Total',
                  style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
                Text(
                  fmt.format(subtotal),
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ],
            ),
            _dashDivider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  fmt.format(totalAmount),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ===== PAYMENT SECTION =====
            const Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  'Tendered:',
                  style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '  ${paymentMethod.toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  fmt.format(paidAmount),
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Change:',
                  style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
                Text(
                  fmt.format(changeDue),
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 3),
            _dashDivider(),
            const SizedBox(height: 24),

            // ===== TIMESTAMP =====
            Text(
              '                $_formattedDate $_formattedTime24',
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.left,
            ),

            const SizedBox(height: 20),

            // ===== NAME & ADDRESS =====
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Name: _________________________________________',
                style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 6),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Address: ______________________________________',
                style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 6),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '         ______________________________________',
                style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 12),
            
            // ===== OFFICIAL RECEIPT TEXT =====
            const Align(
              alignment: Alignment.center,
              child: Text(
                'This serves as an official receipt.',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  
  Widget _dashDivider() {
    return const Text(
      '------------------------------------------------',
      style: TextStyle(
        fontSize: 12,
        fontFamily: 'monospace',
        letterSpacing: 0,
      ),
      maxLines: 1,
      overflow: TextOverflow.clip,
      textAlign: TextAlign.center,
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
    'Drinks',
  ];

  final Map<String, List<String>> categoryImages = {
    'Yangchow Family Bundles': [
      'assets/images/YC1.png',
      'assets/images/YC2.png',
      'assets/images/YC3.jpg',
      'assets/images/YC4.jpg',
      'assets/images/Overloadmeals.png',
    ],
    'Vegetables': [
      'assets/images/VBLwOS.jpg',
      'assets/images/BFOyster.png',
      'assets/images/TPOyster.png',
      'assets/images/SPSF.jpg',
      'assets/images/VBSCwBF.jpg',
      'assets/images/Lohanchay.png',
      'assets/images/ChopsueyGuisado.jpg',
      'assets/images/VCKwG.jpg',
    ],
    'Special Noodles': [
      'assets/images/YCSNoodles.png',
      'assets/images/YCFriedRice.jpg',
      'assets/images/PancitCLM.jpg',
    ],
    'Soup': [
      'assets/images/CCSoup.jpg',
      'assets/images/HSSoup.jpg',
      'assets/images/HototaySoup.jpg',
      'assets/images/MBwEWSoup.png',
      'assets/images/NSoupQE.png',
      'assets/images/SSSoup.jpg',
      'assets/images/CMCSoup.jpg',
    ],
    'Seafood': [
      'assets/images/SPS.jpg',
      'assets/images/BFwSquid.jpg',
      'assets/images/BFShrimp.jpg',
      'assets/images/SFFwOS.jpg',
      'assets/images/FFilletSA.jpg',
      'assets/images/SSFF.jpg',
      'assets/images/FFwTS.jpg',
      'assets/images/FFwBF.jpg',
      'assets/images/FFwSC.jpg',
      'assets/images/HSSalad.jpg',
      'assets/images/CamaronRebusado.jpg',
      'assets/images/SwSE.jpg',
    ],
    'Roast and Soy Specialties': [
      'assets/images/LechonMacau.jpg',
      'assets/images/RPAsado.jpg',
      'assets/images/RoastChicken.jpg',
      'assets/images/CC3.png',
      'assets/images/CC5.png',
      'assets/images/SoyedTaufo.png',
    ],
    'Pork': [
      'assets/images/SSP.jpg',
      'assets/images/SOkSauce.jpg',
      'assets/images/LumpiangShanghai.jpg',
      'assets/images/PatatimCuapao.jpg',
      'assets/images/SAwT.png',
      'assets/images/MPwL.jpg',
      'assets/images/SwSP.jpg',
      'assets/images/KwLM.jpg',
    ],
    'Noodles': [
      'assets/images/PancitCanton.jpg',
      'assets/images/SeafoodCanton.jpg',
      'assets/images/SBHofan.jpg',
      'assets/images/BihonGuisado.jpg',
      'assets/images/BirthdayNoodles.png',
      'assets/images/CNoodleMM.jpg',
      'assets/images/CNMS.png',
      'assets/images/BCMG.jpg',
      'assets/images/PancitCLM.jpg',
    ],
    'Mami or Noodles': [
      'assets/images/RPAN.png',
      'assets/images/BBNoodles.png',
      'assets/images/WantonNoodles.jpg',
      'assets/images/BBWantonN.jpg',
      'assets/images/WantonSoup.png',
      'assets/images/FishballNoodles.png',
      'assets/images/SquidballNoodles.png',
      'assets/images/LobsterballNoodles.png',
    ],
    'Hot Pot Specialties': [
      'assets/images/MPEHotPot.png',
      'assets/images/FFTHotPot.jpg',
      'assets/images/LKHotPot.png',
      'assets/images/STHotPot.jpg',
      'assets/images/BBRHotPot.jpg',
      'assets/images/RPAwTHotPot.png',
    ],
    'Fried Rice or Rice': [
      'assets/images/YCFriedRice.jpg',
      'assets/images/BeefFriedRice.png',
      'assets/images/CSFFriedRice.jpg',
      'assets/images/GarlicFriedRice.jpg',
      'assets/images/PineappleFriedRice.jpg',
      'assets/images/SteamedRiceP.jpg',
      'assets/images/SteamedRiceC.jpg',
    ],
    'Dimsum': [
      'assets/images/SwS.jpg',
      'assets/images/QESiomai.png',
      'assets/images/WantonDumplings.jpg',
      'assets/images/SFDumpling.png',
      'assets/images/AsadoSiopao.png',
      'assets/images/BBSiopao.jpg',
      'assets/images/TausiSpareribs.jpg'
      'assets/images/CuapaoMantau.jpg',
      'assets/images/ChickenFeet.jpg',
      'assets/images/Hakaw.png',
      'assets/images/SpinachDumpling.jpg',
      'assets/images/SpecialSiopao.png',
    ],
    'Congee': [
      'assets/images/PCEC.png',
      'assets/images/PLCongee.jpg',
      'assets/images/SeafoodCongee.png',
      'assets/images/SFCongee.jpg',
      'assets/images/BBCongee.jpg',
      'assets/images/SCC.png',
      'assets/images/CenturyEgg.jpg',
      'assets/images/FreshEgg.jpg',
    ],
    'Chicken': [
      'assets/images/ButteredChicken.jpg',
      'assets/images/YCFChicken.jpg',
      'assets/images/SSChicken.jpg',
      'assets/images/FCwSEY.jpg',
      'assets/images/LemonChicken.jpg',
      'assets/images/SCwCNQE.jpg',
    ],
    'Beef': [
      'assets/images/BeefBLK.jpg',
      'assets/images/BeefBF.jpg',
      'assets/images/BAmpalaya.jpg',
      'assets/images/BSCS.jpg',
      'assets/images/BeefBP.png',
      'assets/images/BeefGP.png',
      'assets/images/BSE.jpeg',
      'assets/images/SBM.jpg',
    ],
    'Appetizer': [
      'assets/images/JellyFCE.jpg',
      'assets/images/JellyFish.jpg',
      'assets/images/Calamares.jpg',
    ],
    'Drinks': [
      'assets/images/NatureSpring.jpg',
      'assets/images/Lipton.jpg',
      'assets/images/7UPCan.jpg',
      'assets/images/PepsiRegBottle.jpg',
      'assets/images/PepsiMaxCan.jpg',
      'assets/images/MirindaCan.jpg',
      'assets/images/MountainDCan.jpg',
      'assets/images/MugRBCan.jpg',
      'assets/images/SanMigLBot.jpg',
      'assets/images/7UPliter.jpg',
      'assets/images/Mirindaliter.jpg',
      'assets/images/MountainDliter.jpg',
      'assets/images/PepsiRegliter.jpg',
      'assets/images/PepsiMaxliter.jpg',
    ],
    'default': ['assets/images/YCFriedRice.jpg'],
  };

  final Map<String, int> _categoryImageIndex = {};
  late Map<String, List<MenuItem>> menu;
  List<CartItem> cart = [];
  final TextEditingController _mobileCustomerNameController =
      TextEditingController();
  VoidCallback? _clearOrderInputs;

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
      _item(
        'YangChow 1',
        1880.80,
        'Yangchow Family Bundles',
        Colors.orange,
        customImagePath: 'assets/images/YC1.png',
      ),
      _item(
        'YangChow 2',
        1880.80,
        'Yangchow Family Bundles',
        Colors.deepOrange,
        customImagePath: 'assets/images/YC2.png',
      ),
      _item(
        'YangChow 3',
        3588.80,
        'Yangchow Family Bundles',
        Colors.deepOrange,
        customImagePath: 'assets/images/YC3.jpg',
      ),
      _item(
        'YangChow 4',
        4588.80,
        'Yangchow Family Bundles',
        Colors.deepOrange,
        customImagePath: 'assets/images/YC4.jpg',
      ),
      _item(
        'Overload Meal',
        298.80,
        'Yangchow Family Bundles',
        Colors.deepOrange,
        customImagePath: 'assets/images/Overloadmeals.png',
      ),
    ]);

    // ── Vegetables ───────────────────────────────────────────────────────────
    menu['Vegetables']!.addAll([
      _item(
        'Broccoli Leaves with Oyster Sauce',
        278.80,
        'Vegetables',
        Colors.blue,
        customImagePath: 'assets/images/VBLwOS.jpg',
      ),
      _item(
        'Broccoli Flower with Oyster Sauce',
        368.80,
        'Vegetables',
        Colors.orange,
        customImagePath: 'assets/images/BFOyster.png',
      ),
      _item(
        'Taiwan Pechay with Oyster Sauce',
        288.80,
        'Vegetables',
        Colors.green,
        customImagePath: 'assets/images/TPOyster.png',
      ),
      _item(
        'Spinach/Polanchay Stir Fried',
        298.80,
        'Vegetables',
        Colors.green,
        customImagePath: 'assets/images/SPSF.jpg',
      ),
      _item(
        'Braised Sea Cucumber with Broccoli Flower',
        328.80,
        'Vegetables',
        Colors.green,
        customImagePath: 'assets/images/VBSCwBF.jpg',
      ),
      _item(
        'Lohanchay',
        298.80,
        'Vegetables',
        Colors.green,
        customImagePath: 'assets/images/Lohanchay.png',
      ),
      _item(
        'Chopsuey Guisado',
        338.80,
        'Vegetables',
        Colors.green,
        customImagePath: 'assets/images/ChopsueyGuisado.jpg',
      ),
      _item(
        'Chinese Kangkong with Garlic',
        238.80,
        'Vegetables',
        Colors.green,
        customImagePath: 'assets/images/VCKwG.jpg',
      ),
    ]);

    // ── Special Noodles ──────────────────────────────────────────────────────
    menu['Special Noodles']!.addAll([
      _item(
        'YC Special Noodles',
        298.80,
        'Special Noodles',
        Colors.amber,
        customImagePath: 'assets/images/YCSNoodles.png',
      ),
    ]);

    // ── Soup ─────────────────────────────────────────────────────────────────
    menu['Soup']!.addAll([
      _item(
        'Chicken Corn Soup',
        308.80,
        'Soup',
        Colors.yellow,
        customImagePath: 'assets/images/CCSoup.jpg',
      ),
      _item(
        'Hot & Sour Soup',
        338.80,
        'Soup',
        Colors.red,
        customImagePath: 'assets/images/HSSoup.jpg',
      ),
      _item(
        'Hototay Soup',
        338.80,
        'Soup',
        Colors.purple,
        customImagePath: 'assets/images/HototaySoup.jpg',
      ),
      _item(
        'Minced Beef with Egg White Soup',
        308.80,
        'Soup',
        Colors.purple,
        customImagePath: 'assets/images/MBwEWSoup.png',
      ),
      _item(
        'Nido Soup with Quail Egg',
        328.80,
        'Soup',
        Colors.brown,
        customImagePath: 'assets/images/NSoupQE.png',
      ),
      _item(
        'Spinach Seafood Soup',
        338.80,
        'Soup',
        Colors.purple,
        customImagePath: 'assets/images/SSSoup.jpg',
      ),
      _item(
        'Crab Meat Corn Soup',
        338.80,
        'Soup',
        Colors.yellow,
        customImagePath: 'assets/images/CMCSoup.jpg',
      ),
    ]);

    // ── Seafood ──────────────────────────────────────────────────────────────
    menu['Seafood']!.addAll([
      _item(
        'Salt & Pepper Squid',
        373.80,
        'Seafood',
        Colors.purple,
        customImagePath: 'assets/images/SPS.jpg',
      ),
      _item(
        'Broccoli Flower with Squid',
        373.80,
        'Seafood',
        Colors.purple,
        customImagePath: 'assets/images/BFwSquid.jpg',
      ),
      _item(
        'Broccoli Flower with Shrimp',
        373.80,
        'Seafood',
        Colors.lightBlue,
        customImagePath: 'assets/images/BFShrimp.jpg',
      ),
      _item(
        'Steamed Fish Fillet with Oyster Sauce',
        423.80,
        'Seafood',
        Colors.lightBlue,
        customImagePath: 'assets/images/SFFwOS.jpg',
      ),
      _item(
        'Fish Fillet with Salt & Pepper',
        413.80,
        'Seafood',
        Colors.cyan,
        customImagePath: 'assets/images/FFilletSA.jpg',
      ),
      _item(
        'Sweet and Sour Fish Fillet',
        403.80,
        'Seafood',
        Colors.cyan,
        customImagePath: 'assets/images/SSFF.jpg',
      ),
      _item(
        'Fish Fillet with Tausi Sauce',
        413.80,
        'Seafood',
        Colors.cyan,
        customImagePath: 'assets/images/FFwTS.jpg',
      ),
      _item(
        'Fish Fillet with Broccoli Flower',
        373.80,
        'Seafood',
        Colors.cyan,
        customImagePath: 'assets/images/FFwBF.jpg',
      ),
      _item(
        'Fish Fillet with Sweet Corn',
        393.80,
        'Seafood',
        Colors.cyan,
        customImagePath: 'assets/images/FFwSC.jpg',
      ),
      _item(
        'Hot Shrimp Salad',
        533.80,
        'Seafood',
        Colors.lightGreen,
        customImagePath: 'assets/images/HSSalad.jpg',
      ),
      _item(
        'Camaron Rebusado',
        433.80,
        'Seafood',
        Colors.lightGreen,
        customImagePath: 'assets/images/CamaronRebusado.jpg',
      ),
      _item(
        'Shrimp with Scramble Egg',
        353.80,
        'Seafood',
        Colors.cyan,
        customImagePath: 'assets/images/SwSE.jpg',
      ),
    ]);

    // ── Roast and Soy Specialties ────────────────────────────────────────────
    menu['Roast and Soy Specialties']!.addAll([
      _item(
        'Lechon Macau',
        675.80,
        'Roast and Soy Specialties',
        Colors.brown,
        customImagePath: 'assets/images/LechonMacau.jpg',
      ),
      _item(
        'Roast Pork Asado',
        675.80,
        'Roast and Soy Specialties',
        Colors.pink,
        customImagePath: 'assets/images/RPAsado.jpg',
      ),
      _item(
        'Roast Chicken',
        698.80,
        'Roast and Soy Specialties',
        Colors.amber,
        customImagePath: 'assets/images/RoastChicken.jpg',
      ),
      _item(
        'Cold Cuts 3 Kinds (Asado, Lechon Macau, Roast Chicken)',
        408.80,
        'Roast and Soy Specialties',
        Colors.amber,
        customImagePath: 'assets/images/CC3.png',
      ),
      _item(
        'Cold Cut 5 Kinds (Asado, Lechon Macau, Roast Chicken, Seaweeds, Century Egg)',
        588.80,
        'Roast and Soy Specialties',
        Colors.amber,
        customImagePath: 'assets/images/CC5.png',
      ),
      _item(
        'Soyed Taufo',
        268.80,
        'Roast and Soy Specialties',
        Colors.amber,
        customImagePath: 'assets/images/SoyedTaufo.png',
      )
    ]);

    // ── Pork ─────────────────────────────────────────────────────────────────
    menu['Pork']!.addAll([
      _item(
        'Sweet and Sour Pork',
        393.80,
        'Pork',
        Colors.red,
        customImagePath: 'assets/images/SSP.jpg',
      ),
      _item(
        'Spareribs with OK Sauce',
        423.80,
        'Pork',
        Colors.black87,
        customImagePath: 'assets/images/SOkSauce.jpg',
      ),
      _item(
        'Lumpiang Shanghai',
        333.80,
        'Pork',
        Colors.green,
        customImagePath: 'assets/images/LumpiangShanghai.jpg',
      ),
      _item(
        'Patatim with Cuapao',
        843.80,
        'Pork',
        Colors.brown,
        customImagePath: 'assets/images/PatatimCuapao.jpg',
      ),
      _item(
        'Spareribs Ampalaya with Tausi',
        413.80,
        'Pork',
        Colors.black87,
        customImagePath: 'assets/images/SAwT.png',
      ),
      _item(
        'Spareribs with Salt and Pepper',
        423.80,
        'Pork',
        Colors.red,
        customImagePath: 'assets/images/SwSP.jpg',
      ),
      _item(
        'Minced Pork with Lettuce',
        413.80,
        'Pork',
        Colors.orange,
        customImagePath: 'assets/images/MPwL.jpg',
      ),
      _item(
        'Kangkong with Lechon Macau',
        413.80,
        'Pork',
        Colors.red,
        customImagePath: 'assets/images/KwLM.jpg',
      ),
    ]);

    // ── Noodles ──────────────────────────────────────────────────────────────
    menu['Noodles']!.addAll([
      _item(
        'Pancit Canton',
        398.80,
        'Noodles',
        Colors.orange,
        customImagePath: 'assets/images/PancitCLM.jpg',
      ),
      _item(
        'Seafood Canton',
        388.80,
        'Noodles',
        Colors.purple,
        customImagePath: 'assets/images/SeafoodCanton.jpg',
      ),
      _item(
        'Sliced Beef Hofan',
        298.80,
        'Noodles',
        Colors.green,
        customImagePath: 'assets/images/SBHofan.jpg',
      ),
      _item(
        'Bihon Guisado',
        358.80,
        'Noodles',
        Colors.yellow,
        customImagePath: 'assets/images/BihonGuisado.jpg',
      ),
      _item(
        'Birthday Noodles',
        378.80,
        'Noodles',
        Colors.pink,
        customImagePath: 'assets/images/BirthdayNoodles.png',
      ),
      _item(
        'Crispy Noodle Mixed Meat',
        458.80,
        'Noodles',
        Colors.yellow,
        customImagePath: 'assets/images/CNoodleMM.jpg',
      ),
      _item(
        'Crispy Noodle Mixed Seafood',
        458.80,
        'Noodles',
        Colors.yellow,
        customImagePath: 'assets/images/CNMS.png',
      ),
      _item(
        'Bihon and Canton Mixed Guisado',
        458.80,
        'Noodles',
        Colors.red,
        customImagePath: 'assets/images/BCMG.jpg',
      ),
      _item(
        'Pancit Canton with Lechon Macau',
        458.80,
        'Noodles',
        Colors.red,
        customImagePath: 'assets/images/PancitCLM.jpg',
      ),
    ]);

    // ── Mami or Noodles ──────────────────────────────────────────────────────
    menu['Mami or Noodles']!.addAll([
      _item(
        'Roast Pork Asado Noodles',
        238.80,
        'Mami or Noodles',
        Colors.brown,
        customImagePath: 'assets/images/RPAN.png',
      ),
      _item(
        'Beef Brisket Noodles',
        338.80,
        'Mami or Noodles',
        Colors.red,
        customImagePath: 'assets/images/BBNoodles.png',
      ),
      _item(
        'Wanton Noodles',
        338.80,
        'Mami or Noodles',
        Colors.brown,
        customImagePath: 'assets/images/WantonNoodles.jpg',
      ),
      _item(
        'Beef Brisket & Wonton Noodles',
        278.80,
        'Mami or Noodles',
        Colors.purple,
        customImagePath: 'assets/images/BBWantonN.jpg',
      ),
      _item(
        'Wanton Soup (6pcs)',
        268.80,
        'Mami or Noodles',
        Colors.orange,
        customImagePath: 'assets/images/WantonSoup.png',
      ),
      _item(
        'Fishball Noodles',
        248.80,
        'Mami or Noodles',
        Colors.blue,
        customImagePath: 'assets/images/FishballNoodles.png',
      ),
      _item(
        'Squidball Noodles',
        248.80,
        'Mami or Noodles',
        Colors.blue,
        customImagePath: 'assets/images/SquidballNoodles.png',
      ),
      _item(
        'Lobsterball Noodles',
        278.80,
        'Mami or Noodles',
        Colors.blue,
        customImagePath: 'assets/images/LobsterballNoodles.png',
      ),
    ]);

    // ── Hot Pot Specialties ──────────────────────────────────────────────────
    menu['Hot Pot Specialties']!.addAll([
      _item(
        'Minced Pork with Eggplant in Hot Pot',
        343.80,
        'Hot Pot Specialties',
        Colors.purple,
        customImagePath: 'assets/images/MPEHotPot.png',
      ),
      _item(
        'Fish Fillet with Taufo in Hot Pot',
        403.80,
        'Hot Pot Specialties',
        Colors.green,
        customImagePath: 'assets/images/FFTHotPot.jpg',
      ),
      _item(
        'Lechon Kawali in Hot Pot',
        413.80,
        'Hot Pot Specialties',
        Colors.orange,
        customImagePath: 'assets/images/LKHotPot.png',
      ),
      _item(
        'Seafood Taufo in Hot Pot',
        403.80,
        'Hot Pot Specialties',
        Colors.deepOrange,
        customImagePath: 'assets/images/STHotPot.jpg',
      ),
      _item(
        'Beef Brisket with Raddish in Hot Pot',
        403.80,
        'Hot Pot Specialties',
        Colors.red,
        customImagePath: 'assets/images/BBRHotPot.jpg',
      ),
      _item(
        'Roast Pork Asado with Taufo in Hot Pot',
        413.80,
        'Hot Pot Specialties',
        Colors.purple,
        customImagePath: 'assets/images/RPAwTHotPot.png',
      ),
    ]);

    // ── Fried Rice or Rice ───────────────────────────────────────────────────
    menu['Fried Rice or Rice']!.addAll([
      _item(
        'Yang Chow Fried Rice',
        338.80,
        'Fried Rice or Rice',
        Colors.red,
        customImagePath: 'assets/images/YCFriedRice.jpg',
      ),
      _item(
        'Beef Fried Rice',
        338.80,
        'Fried Rice or Rice',
        Colors.orange,
        customImagePath: 'assets/images/BeefFriedRice.png',
      ),
      _item(
        'Chicken with Salted Fish (Fried Rice)',
        338.80,
        'Fried Rice or Rice',
        Colors.white70,
        customImagePath: 'assets/images/CSFFriedRice.jpg',
      ),
      _item(
        'Garlic Fried Rice',
        235.80,
        'Fried Rice or Rice',
        Colors.deepOrange,
        customImagePath: 'assets/images/GarlicFriedRice.jpg',
      ),
      _item(
        'Pineapple Fried Rice',
        388.80,
        'Fried Rice or Rice',
        Colors.yellow,
        customImagePath: 'assets/images/PineappleFriedRice.jpg',
      ),
      _item(
        'Steamed Rice (Platter)',
        225.80,
        'Fried Rice or Rice',
        Colors.yellow,
        customImagePath: 'assets/images/SteamedRiceP.jpg',
      ),
      _item(
        'Steamed Rice (1 Cup)', 
        68.80,
        'Fried Rice or Rice',
        Colors.yellow,
        customImagePath: 'assets/images/SteamedRiceC.jpg',
      ),
    ]);

    // ── Dimsum ───────────────────────────────────────────────────────────────
    menu['Dimsum']!.addAll([
      _item(
        'Siomai with Shrimp',
        143.80,
        'Dimsum',
        Colors.orange,
        customImagePath: 'assets/images/SwS.jpg',
      ),
      _item(
        'Quail Egg Siomai',
        143.80,
        'Dimsum',
        Colors.orange,
        customImagePath: 'assets/images/QESiomai.png',
      ),
      _item(
        'Wanton Dumplings',
        143.80,
        'Dimsum',
        Colors.orange,
        customImagePath: 'assets/images/WantonDumplings.jpg',
      ),
      _item(
        'Shark\'s Fin Dumpling',
        143.80,
        'Dimsum',
        Colors.orange,
        customImagePath: 'assets/images/SFDumpling.png',
      ),
      _item(
        'Asado Siopao',
        143.80,
        'Dimsum',
        Colors.purple,
        customImagePath: 'assets/images/AsadoSiopao.png',
      ),
      _item(
        'Bola-Bola Siopao',
        143.80,
        'Dimsum',
        Colors.lightBlue,
        customImagePath: 'assets/images/BBSiopao.jpg',
      ),
      _item(
        'Tausi Spareribs',
        138.80,
        'Dimsum',
        Colors.orange,
        customImagePath: 'assets/images/TausiSpareribs.jpg',
      ),
      _item(
        'Cuapao / Mantau',
        98.80,
        'Dimsum',
        Colors.amber,
        customImagePath: 'assets/images/CuapaoMantau.jpg',
      ),
      _item(
        'Chicken Feet',
        143.80,
        'Dimsum',
        Colors.red,
        customImagePath: 'assets/images/ChickenFeet.jpg',
      ),
      _item(
        'Hakaw',
        165.80,
        'Dimsum',
        Colors.orange,
        customImagePath: 'assets/images/Hakaw.png',
      ),
      _item(
        'Spinach Dumpling',
        165.80,
        'Dimsum',
        Colors.brown,
        customImagePath: 'assets/images/SpinachDumpling.jpg',
      ),
      _item(
        'Special Siopao',
        165.80,
        'Dimsum',
        Colors.purple,
        customImagePath: 'assets/images/SpecialSiopao.png',
      ),
    ]);

    // ── Congee ───────────────────────────────────────────────────────────────
    menu['Congee']!.addAll([
      _item(
        'Pork Century Egg Congee',
        205.80,
        'Congee',
        Colors.grey,
        customImagePath: 'assets/images/PCEC.png',
      ),
      _item(
        'Pork Liver Congee',
        205.80,
        'Congee',
        Colors.grey,
        customImagePath: 'assets/images/PLCongee.jpg',
      ),
      _item(
        'Seafood Congee',
        235.80,
        'Congee',
        Colors.grey,
        customImagePath: 'assets/images/SeafoodCongee.png',
      ),
      _item(
        'Sliced Fish Congee',
        225.80,
        'Congee',
        Colors.grey,
        customImagePath: 'assets/images/SFCongee.jpg',
      ),
      _item(
        'Beef Balls Congee',
        235.80,
        'Congee',
        Colors.deepOrange,
        customImagePath: 'assets/images/BBCongee.jpg',
      ),
      _item(
        'Sliced Chicken Congee',
        204.80,
        'Congee',
        Colors.deepOrange,
        customImagePath: 'assets/images/SCC.png',
      ),
      _item(
        'Century Egg',
        78.80,
        'Congee',
        Colors.grey,
        customImagePath: 'assets/images/CenturyEgg.jpg',
      ),
      _item(
        'Fresh Egg',
        48.80,
        'Congee',
        Colors.yellow,
        customImagePath: 'assets/images/FreshEgg.jpg',
      ),
    ]);

    // ── Chicken ──────────────────────────────────────────────────────────────
    menu['Chicken']!.addAll([
      _item(
        'Buttered Chicken',
        358.80,
        'Chicken',
        Colors.amber,
        customImagePath: 'assets/images/ButteredChicken.jpg',
      ),
      _item(
        'Yang Chow Fried Chicken',
        678.80,
        'Chicken',
        Colors.orange,
        customImagePath: 'assets/images/YCFChicken.jpg',
      ),
      _item(
        'Sweet and Sour Chicken',
        378.80,
        'Chicken',
        Colors.orange,
        customImagePath: 'assets/images/SSChicken.jpg',
      ),
      _item(
        'Fried Chicken with Salted Egg Yolk',
        378.80,
        'Chicken',
        Colors.orange,
        customImagePath: 'assets/images/FCwSEY.jpg',
      ),
      _item(
        'Lemon Chicken',
        378.80,
        'Chicken',
        Colors.yellow,
        customImagePath: 'assets/images/LemonChicken.jpg',
      ),
      _item(
        'Sliced Chicken with Cashew Nuts and Quail Egg',
        398.80,
        'Chicken',
        Colors.brown,
        customImagePath: 'assets/images/SCwCNQE.jpg',
      ),
    ]);

    // ── Beef ─────────────────────────────────────────────────────────────────
    menu['Beef']!.addAll([
      _item(
        'Beef with Broccoli Leaves (Kaylan)',
        420.80,
        'Beef',
        Colors.brown,
        customImagePath: 'assets/images/BeefBLK.jpg',
      ),
      _item(
        'Beef with Broccoli Flower',
        420.80,
        'Beef',
        Colors.red,
        customImagePath: 'assets/images/BeefBF.jpg',
      ),
      _item(
        'Beef with Ampalaya',
        438.80,
        'Beef',
        Colors.brown,
        customImagePath: 'assets/images/BAmpalaya.jpg',
      ),
      _item(
        'Beef Steak Chinese Style',
        438.80,
        'Beef',
        Colors.red,
        customImagePath: 'assets/images/BSCS.jpg',
      ),
      _item(
        'Beef with Black Pepper',
        438.80,
        'Beef',
        Colors.green,
        customImagePath: 'assets/images/BeefBP.png',
      ),
      _item(
        'Beef with Green Pepper',
        438.80,
        'Beef',
        Colors.green,
        customImagePath: 'assets/images/BeefGP.png',
      ),
      _item(
        'Beef with Scramble Egg',
        338.80,
        'Beef',
        Colors.red,
        customImagePath: 'assets/images/BSE.jpeg',
      ),
      _item(
        'Slice Beef Mango',
        438.80,
        'Beef',
        Colors.green,
        customImagePath: 'assets/images/SBM.jpg',
      ),
    ]);

    // ── Appetizer ────────────────────────────────────────────────────────────
    menu['Appetizer']!.addAll([
      _item(
        'Jelly Fish with Century Egg',
        278.80,
        'Appetizer',
        Colors.orange,
        customImagePath: 'assets/images/JellyFCE.jpg',
      ),
      _item(
        'Jelly Fish',
        198.80,
        'Appetizer',
        Colors.pink,
        customImagePath: 'assets/images/JellyFish.jpg',
      ),
      _item(
        'Calamares',
        298.80,
        'Appetizer',
        Colors.deepOrange,
        customImagePath: 'assets/images/Calamares.jpg',
      ),
    ]);

    // ── Drinks ────────────────────────────────────────────────────────────
    menu['Drinks']!.addAll([
      _item(
        'Natures Spring 350ML',
        20.80,
        'Drinks',
        Colors.orange,
        customImagePath: 'assets/images/NatureSpring.jpg',
      ),
      _item(
        'Lipton Iced Tea Lemon Can',
        78.80,
        'Drinks',
        Colors.pink,
        customImagePath: 'assets/images/Lipton.jpg',
      ),
      _item(
        '7UP Can',
        78.80,
        'Drinks',
        Colors.deepOrange,
        customImagePath: 'assets/images/7UPCan.jpg',
      ),
      _item(
        'Pepsi Regular Bottle',
        78.80,
        'Drinks',
        Colors.orange,
        customImagePath: 'assets/images/PepsiRegBottle.jpg',
      ),
      _item(
        'Pepsi Max Can',
        78.80,
        'Drinks',
        Colors.pink,
        customImagePath: 'assets/images/PepsiMaxCan.jpg',
      ),
      _item(
        'Mirinda Can',
        78.80,
        'Drinks',
        Colors.pink,
        customImagePath: 'assets/images/MirindaCan.jpg',
      ),
      _item(
        'Mountain Dew Can',
        78.80,
        'Drinks',
        Colors.deepOrange,
        customImagePath: 'assets/images/MountainDCan.jpg',
      ),
      _item(
        'Mug Root Beer Can',
        78.80,
        'Drinks',
        Colors.orange,
        customImagePath: 'assets/images/MugRBCan.jpg',
      ),
      _item(
        'San Mig Light Bottle',
        78.80,
        'Drinks',
        Colors.deepOrange,
        customImagePath: 'assets/images/SanMigLBot.jpg',
      ),
      _item(
        '7UP 1.5 Liter',
        108.80,
        'Drinks',
        Colors.orange,
        customImagePath: 'assets/images/7UPliter.jpg',
      ),
      _item(
        'Mirinda 1.5 Liter',
        108.80,
        'Drinks',
        Colors.pink,
        customImagePath: 'assets/images/Mirindaliter.jpg',
      ),
      _item(
        'Mountain Dew 1.5 Liter',
        108.80,
        'Drinks',
        Colors.deepOrange,
        customImagePath: 'assets/images/MountainDliter.jpg',
      ),
      _item(
        'Pepsi Regular 1.5 Liter',
        108.80,
        'Drinks',
        Colors.orange,
        customImagePath: 'assets/images/PepsiRegliter.jpg',
      ),
      _item(
        'Pepsi Max 1.5 Liter',
        108.80,
        'Drinks',
        Colors.pink,
        customImagePath: 'assets/images/PepsiMaxliter.jpg',
      ),
    ]);
  }

  MenuItem _item(
    String name,
    double price,
    String category,
    Color color, {
    String? customImagePath,
  }) {
    return MenuItem(
      name: name,
      price: price,
      category: category,
      fallbackImagePath: customImagePath ?? _nextImage(category),
      color: color,
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
        final existing = cart.removeAt(index);
        existing.quantity++;
        cart.insert(0, existing);
      } else {
        cart.insert(0, CartItem(item, 1));
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

  Future<void> _showIngredientsDialog(MenuItem item) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        item.customImagePath ?? item.fallbackImagePath,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, _, _) => Container(
                          width: 60,
                          height: 60,
                          color: const Color(0xFFF5F6FA),
                          child: const Icon(Icons.fastfood, color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            '₱${item.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Recipe Ingredients Section
                const Text(
                  'Recipe Ingredients & Stock Status',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Ingredients List
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: RecipeService().getIngredientsWithInventoryStatus(item.name),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      
                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Error loading ingredients: ${snapshot.error}'),
                        );
                      }
                      
                      final ingredients = snapshot.data ?? [];
                      
                      if (ingredients.isEmpty) {
                        return const Center(
                          child: Text(
                            'No recipe found for this item',
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }
                      
                      return ListView.builder(
                        itemCount: ingredients.length,
                        itemBuilder: (context, index) {
                          final ingredient = ingredients[index];
                          final inventoryQuantity = ingredient['inventory_quantity'] as int;
                          final stockStatus = ingredient['stock_status']?.toString() ?? 'UNKNOWN';
                          final isAvailable = ingredient['is_available'] as bool;
                          final stockColor = _getStockStatusColor(stockStatus);
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F6FA),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isAvailable ? const Color(0xFFE5E7EB) : Colors.red.withValues(alpha: 0.3),
                                width: isAvailable ? 1 : 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ingredient['name']?.toString() ?? 'Unknown',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: isAvailable ? const Color(0xFF1E293B) : Colors.red,
                                        ),
                                      ),
                                      if ((ingredient['category'] != null))
                                        Text(
                                          ingredient['category']?.toString() ?? 'No category',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Stock: $inventoryQuantity ${ingredient['inventory_unit']?.toString() ?? 'pcs'}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isAvailable ? const Color(0xFF1E293B) : Colors.red,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: stockColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          stockStatus,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: stockColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Close Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStockStatusColor(String status) {
    switch (status) {
      case 'OUT OF STOCK':
        return Colors.red;
      case 'INSUFFICIENT':
        return Colors.orange;
      case 'LOW STOCK':
        return Colors.blue;
      case 'AVAILABLE':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _generateReceipt({
    String customerName = '',
    String note = '',
    String paymentMethod = 'CASH',
    double paidAmount = 0.0,
    double changeDue = 0.0,
    int guestCount = 1,
    String tableNumber = '',
    String cashierName = '',
    String serverName = '',
  }) async {
    if (cart.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cart is empty!')));
      return;
    }

    // Snapshot the cart and total NOW — before the OrderListPanel
    // has a chance to clear the cart after calling this callback.
    final cartSnapshot = cart.map((c) => CartItem(c.item, c.quantity)).toList();
    final snapshotTotal = cartSnapshot.fold(
      0.0,
      (sum, c) => sum + (c.item.price * c.quantity),
    );

    // Determine the next transaction ID (001, 002, ...)
    // Only count clean sequential IDs (<= 9999). Legacy large IDs are ignored.
    String transactionId = '001';
    try {
      final supabase = Supabase.instance.client;
      final res = await supabase
          .from('orders')
          .select('transaction_id')
          .order('created_at', ascending: false)
          .limit(200);

      int maxId = 0;
      for (final row in res) {
        final raw = row['transaction_id']?.toString() ?? '';
        final parsed = int.tryParse(raw);
        // Only accept clean sequential IDs (4 digits or fewer)
        if (parsed != null && parsed <= 9999 && parsed > maxId) maxId = parsed;
      }
      transactionId = (maxId + 1).toString().padLeft(3, '0');
    } catch (e) {
      transactionId = '001';
    }

    if (!mounted) return;

    // Persist to Supabase (fire-and-forget, errors shown via snackbar)
    _saveOrderToDatabase(
      cartSnapshot: cartSnapshot,
      total: snapshotTotal,
      customerName: customerName,
      note: note,
      transactionId: transactionId,
      paymentMethod: paymentMethod,
      amountPaid: paidAmount,
      changeDue: changeDue,
      guestCount: guestCount,
      tableNumber: tableNumber,
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
            note: note.isNotEmpty ? note : null,
            paymentMethod: paymentMethod,
            transactionId: transactionId,
            transactionDate: DateTime.now(),
            paidAmount: paidAmount,
            changeDue: changeDue,
            tableNumber: tableNumber.isNotEmpty ? int.tryParse(tableNumber) : null,
            guestCount: guestCount,
            serverName: serverName.isNotEmpty ? serverName : 'JANE',
            orderType: 'WALK-IN',
            terminalNumber: 1,
            cashierName: cashierName.isNotEmpty ? cashierName : 'JANE',
          ),
        ),
      ),
    );
  }

  Future<void> _saveOrderToDatabase({
    required List<CartItem> cartSnapshot,
    required double total,
    required String customerName,
    required String note,
    required String transactionId,
    required String paymentMethod,
    required double amountPaid,
    required double changeDue,
    required int guestCount,
    required String tableNumber,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      final staffEmail = supabase.auth.currentUser?.email ?? 'staff';

      // Insert the order header and get back the generated ID
      final orderRes = await supabase
          .from('orders')
          .insert({
            'transaction_id': transactionId,
            'customer_name': customerName.isNotEmpty ? customerName : 'Guest',
            'note': note,
            'kitchen_status': 'Pending',
            'total_amount': total,
            'payment_method': paymentMethod,
            'amount_paid': amountPaid,
            'change_due': changeDue,
            'item_count': cartSnapshot.fold(0, (s, c) => s + c.quantity),
            'staff_email': staffEmail,
            'table_number': tableNumber.isNotEmpty ? tableNumber : null,
            'number_of_guests': guestCount,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();

      final orderId = orderRes['id'].toString();

      // Insert each line item
      final itemRows = cartSnapshot
          .map(
            (c) => {
              'order_id': orderId,
              'item_name': c.item.name,
              'quantity': c.quantity,
              'unit_price': c.item.price,
              'subtotal': c.item.price * c.quantity,
            },
          )
          .toList();

      await supabase.from('order_items').insert(itemRows);

      // Trigger automatic inventory deduction for each item ordered
      // We run these sequentially to avoid race conditions on the same ingredient stock
      for (final cartItem in cartSnapshot) {
        await RecipeService().deductIngredientsFromInventory(
          cartItem.item.name,
          cartItem.quantity,
        );
      }
    } catch (e) {
      debugPrint('Supabase Error: $e');
      // Non-blocking: show a warning but don't block the receipt
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Could not save order: $e'),
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
                                        'P${NumberFormat('#,##0.00', 'en_US').format(item.item.price)}',
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
                          'P${NumberFormat('#,##0.00', 'en_US').format(totalAmount)}',
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
                        onPressed: cart.isNotEmpty
                            ? () async {
                                // Close the bottom sheet first, then show
                                // the receipt dialog using the parent context.
                                Navigator.pop(context);
                                await _generateReceipt();
                                _mobileCustomerNameController.clear();
                              }
                            : null,
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
                child: Text(
                  'P',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Order Menu',
              style: TextStyle(
                color: Color(0xFF1A1A2E),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          if (cart.isNotEmpty)
            Stack(
              alignment: Alignment.topRight,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.receipt_long,
                    color: Color.fromARGB(255, 255, 0, 0),
                  ),
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
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${cart.fold(0, (s, e) => s + e.quantity)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          // ── Instructions Bar ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.blue.withValues(alpha: 0.1),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue, size: 16),
                const SizedBox(width: 8),
                const Text(
                  '💡 Long-press any food item to view ingredients and inventory status',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    // Add a way to dismiss this instruction
                  },
                  child: const Icon(
                    Icons.close,
                    color: Colors.blue,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
          // ── Body Row ─────────────────────────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Left: Category Sidebar ──────────────────────────────
                    _buildCategorySidebar(),
                    // ── Center: Food Grid ──────────────────────────────────────
                    Expanded(
                      flex: 13,
                      child: _buildMenuGrid(
                        crossAxisCount: 5,
                        childAspectRatio: 0.82,
                      ),
                    ),
                    // ── Far Right: Order Panel ─────────────────────────────────
                    OrderListPanel(
                      cart: cart,
                      onQuantityIncreased: _increaseQuantity,
                      onQuantityDecreased: _decreaseQuantity,
                      onRemoveItem: _removeItem,
                      onProceedPayment: (name, note, totalAmount, guestCount, tableNumber) {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => Dialog(
                            backgroundColor: Colors.transparent,
                            insetPadding: const EdgeInsets.all(20),
                            child: Container(
                              width: 700,
                              height: 700,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: PaymentPanel(
                                cart: cart,
                                customerName: name,
                                note: note,
                                overrideTotalAmount: totalAmount,
                                onBack: () => Navigator.pop(context),
                                onComplete:
                                    (name, note, method, paid, change, cashierName, serverName) async {
                                      Navigator.pop(
                                        context,
                                      ); // Close payment dialog
                                      await _generateReceipt(
                                        customerName: name,
                                        note: note,
                                        paymentMethod: method,
                                        paidAmount: paid,
                                        changeDue: change,
                                        guestCount: guestCount,
                                        tableNumber: tableNumber,
                                        cashierName: cashierName,
                                        serverName: serverName,
                                      );
                                      setState(() => cart.clear());
                                      _mobileCustomerNameController.clear();
                                      _clearOrderInputs?.call();
                                    },
                              ),
                            ),
                          ),
                        );
                      },
                      onClearCart: () {
                        setState(() => cart.clear());
                      },
                      onClearInputs: (clearFunction) {
                        _clearOrderInputs = clearFunction;
                      },
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
          color: selected ? const Color(0xFFEEEdFD) : Colors.transparent,
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
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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
          prefixIcon: Icon(Icons.search, color: Color(0xFF9CA3AF), size: 18),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4F46E5) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF4F46E5) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          categories[index],
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF374151),
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuGrid({
    required int crossAxisCount,
    required double childAspectRatio,
  }) {
    final cat = categories[_selectedCategoryIndex];
    final allItems = menu[cat]!;
    final items = _searchQuery.isEmpty
        ? allItems
        : allItems
              .where((m) => m.name.toLowerCase().contains(_searchQuery))
              .toList();

    if (items.isEmpty) {
      return const Center(
        child: Text(
          'No items found',
          style: TextStyle(color: Color(0xFF9CA3AF)),
        ),
      );
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
      onLongPress: () => _showIngredientsDialog(item),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: inCart
              ? Border.all(
                  color: const Color.fromARGB(255, 255, 0, 0),
                  width: 2,
                )
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

              // ── Ingredients indicator (top-left) ─────────────────────────
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.info_outline,
                    color: Colors.white,
                    size: 14,
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
