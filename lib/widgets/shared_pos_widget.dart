import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'order_list_panel.dart';
import 'payment_panel.dart';
import '../services/recipe_service.dart';
import '../models/menu_item.dart';
import '../services/menu_service.dart';

/// =====================
/// MODELS
/// =====================

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
  final double discountAmount;
  final String discountLabel;
  final String? discountName;
  final String? discountAddress;

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
    this.discountAmount = 0.0,
    this.discountLabel = 'None',
    this.discountName,
    this.discountAddress,
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
            if (discountAmount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '  Discount (20% - $discountLabel)',
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                    ),
                    Text(
                      '-${fmt.format(discountAmount)}',
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ],
                ),
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
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Name: ${discountName?.isNotEmpty == true ? discountName : "________________________________________"}',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Address: ${discountAddress?.isNotEmpty == true ? discountAddress : "___________________________________"}',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
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


  late Map<String, List<MenuItem>> menu;
  List<CartItem> cart = [];
  final TextEditingController _mobileCustomerNameController =
      TextEditingController();
  VoidCallback? _clearOrderInputs;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: MenuService.categories.length, vsync: this);
    menu = MenuService.getMenu();
    _fetchInventory();
  }

  Future<void> _fetchInventory() async {
    if (_isFetchingInventory) return;
    if (mounted) setState(() => _isFetchingInventory = true);
    try {
      final supabase = Supabase.instance.client;
      final data = await supabase.from('kitchen_inventory').select('name, quantity');
      if (data != null) {
        final Map<String, num> newCache = {};
        for (var item in data) {
          final name = item['name']?.toString().toLowerCase() ?? '';
          newCache[name] = (item['quantity'] as num?) ?? 0;
        }
        if (mounted) {
          setState(() {
            _inventoryCache.clear();
            _inventoryCache.addAll(newCache);
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching inventory for POS: $e');
    } finally {
      if (mounted) setState(() => _isFetchingInventory = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _mobileCustomerNameController.dispose();
    _searchController.dispose();
    super.dispose();
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

  bool _isStockAvailable(String itemName, int requestedQuantity) {
    if (widget.userRole != 'Staff') return true;
    
    final recipeData = RecipeService.recipeDatabase[itemName];
    if (recipeData == null) return true;

    final List ingredients = recipeData['ingredients'];
    for (final ing in ingredients) {
      final String ingName = ing['name'].toString().toLowerCase();
      
      num? stock;
      if (_inventoryCache.containsKey(ingName)) {
        stock = _inventoryCache[ingName];
      } else {
        for (final entry in _inventoryCache.entries) {
          if (entry.key.contains(ingName) || ingName.contains(entry.key)) {
            stock = entry.value;
            break;
          }
        }
      }

      if (stock != null) {
        final maxAllowed = stock - 1;
        if (requestedQuantity > maxAllowed) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Max limit due to stock! Only ${maxAllowed.toInt()} available for $itemName.'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 1),
            ),
          );
          return false;
        }
      }
    }
    return true;
  }

  void addToCart(MenuItem item) {
    final index = cart.indexWhere((e) => e.item.name == item.name);
    
    if (index >= 0) {
      if (!_isStockAvailable(item.name, cart[index].quantity + 1)) return;
      setState(() {
        final existing = cart.removeAt(index);
        existing.quantity++;
        cart.insert(0, existing);
      });
    } else {
      if (!_isStockAvailable(item.name, 1)) return;
      setState(() {
        cart.insert(0, CartItem(item, 1));
      });
    }
  }

  void _increaseQuantity(CartItem item) {
    if (!_isStockAvailable(item.item.name, item.quantity + 1)) return;
    setState(() {
      item.quantity++;
    });
  }

  double get totalAmount =>
      cart.fold(0.0, (sum, c) => sum + (c.item.price * c.quantity));

  final Map<String, num> _inventoryCache = {};
  bool _isFetchingInventory = false;

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
    double discountAmount = 0.0,
    String discountLabel = 'None',
    String discountName = '',
    String discountAddress = '',
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
    final subtotal = cartSnapshot.fold(
      0.0,
      (sum, c) => sum + (c.item.price * c.quantity),
    );
    final finalTotal = subtotal - discountAmount;

    // Validation for Staff: Stock-based quantity limit (Max = Stock - 1)
    if (widget.userRole == 'Staff') {
      final inventoryError = await RecipeService().checkInventoryAvailability(cartSnapshot);
      if (inventoryError != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(inventoryError),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

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
      total: finalTotal,
      customerName: customerName,
      note: note,
      transactionId: transactionId,
      paymentMethod: paymentMethod,
      amountPaid: paidAmount,
      changeDue: changeDue,
      guestCount: guestCount,
      tableNumber: tableNumber,
      discountAmount: discountAmount,
      discountLabel: discountLabel,
      discountName: discountName,
      discountAddress: discountAddress,
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
            totalAmount: finalTotal,
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
            discountAmount: discountAmount,
            discountLabel: discountLabel,
            discountName: discountName,
            discountAddress: discountAddress,
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
    double discountAmount = 0.0,
    String discountLabel = 'None',
    String discountName = '',
    String discountAddress = '',
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
            'discount_amount': discountAmount,
            'discount_label': discountLabel,
            'discount_name': discountName,
            'discount_address': discountAddress,
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
      
      // Refresh inventory cache after deduction
      _fetchInventory();
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
                                // Validation for Staff: Stock-based quantity limit (Max = Stock - 1)
                                if (widget.userRole == 'Staff') {
                                  final inventoryError = await RecipeService().checkInventoryAvailability(cart);
                                  if (inventoryError != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(inventoryError),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }
                                }

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
              itemCount: MenuService.categories.length,
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
                      onProceedPayment: (name, note, totalAmount, guestCount, tableNumber, discountAmount, discountLabel, discountName, discountAddress) async {
                        // Validation for Staff: Stock-based quantity limit (Max = Stock - 1)
                        if (widget.userRole == 'Staff') {
                          final inventoryError = await RecipeService().checkInventoryAvailability(cart);
                          if (inventoryError != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(inventoryError),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                        }

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
                                        discountAmount: discountAmount,
                                        discountLabel: discountLabel,
                                        discountName: discountName,
                                        discountAddress: discountAddress,
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
              itemCount: MenuService.categories.length,
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
              const SizedBox(width: 11),
            Expanded(
              child: Text(
                MenuService.categories[index],
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
          MenuService.categories[index],
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
    final cat = MenuService.categories[_selectedCategoryIndex];
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
