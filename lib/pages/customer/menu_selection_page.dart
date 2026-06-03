import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/menu_item.dart';
import '../../services/menu_reservation_service.dart';
import '../../services/menu_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/responsive_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/recipe_service.dart';

class MenuSelectionPage extends StatefulWidget {
  final String reservationType;
  final int guestCount;
  final Function(Map<String, int>) onMenuSelected;
  final Map<String, int>? initialSelection;

  const MenuSelectionPage({
    super.key,
    required this.reservationType,
    required this.guestCount,
    required this.onMenuSelected,
    this.initialSelection,
  });

  @override
  State<MenuSelectionPage> createState() => _MenuSelectionPageState();
}

class _MenuSelectionPageState extends State<MenuSelectionPage> with SingleTickerProviderStateMixin {
  late Map<String, List<MenuItem>> menu;
  final Map<String, int> selectedItems = {};
  final MenuReservationService _menuService = MenuReservationService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final NumberFormat _fmt = NumberFormat('#,##0.00', 'en_US');
  
  String _selectedCategory = 'All';
  String _searchQuery = '';
  double _totalPrice = 0.0;
  double _depositAmount = 0.0;

  final Map<String, num> _inventoryCache = {};
  final Map<String, List<Map<String, dynamic>>> _recipeCache = {};
  bool _isFetchingInventory = false;

  @override
  void initState() {
    super.initState();
    menu = MenuService.getMenu();
    
    // Initialize with any provided selection
    if (widget.initialSelection != null) {
      selectedItems.addAll(widget.initialSelection!);
    }
    
    _updatePricing();
    _fetchInventory();
  }

  Future<void> _fetchInventory() async {
    if (_isFetchingInventory) return;
    if (mounted) setState(() => _isFetchingInventory = true);
    try {
      final supabase = Supabase.instance.client;
      // Fetch inventory
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

      // Fetch recipe ingredients
      final recipeData = await supabase.from('recipe_ingredients').select();
      if (recipeData != null) {
        final Map<String, List<Map<String, dynamic>>> newRecipeCache = {};
        for (var row in recipeData) {
          final menuItemName = row['menu_item_name'] as String;
          if (!newRecipeCache.containsKey(menuItemName)) {
            newRecipeCache[menuItemName] = [];
          }
          newRecipeCache[menuItemName]!.add(row as Map<String, dynamic>);
        }
        if (mounted) {
          setState(() {
            _recipeCache.clear();
            _recipeCache.addAll(newRecipeCache);
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching inventory or recipes for Menu Selection: $e');
    } finally {
      if (mounted) setState(() => _isFetchingInventory = false);
    }
  }

  bool _isStockAvailable(String itemName, int requestedQuantity) {
    final recipeIngredients = _recipeCache[itemName];
    if (recipeIngredients == null || recipeIngredients.isEmpty) return true;

    for (final ing in recipeIngredients) {
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
        // Calculate required ingredient quantity based on recipe and order quantity
        final double ingredientQtyPerUnit = ing['quantity']?.toDouble() ?? 1.0;
        final double requiredQty = ingredientQtyPerUnit * requestedQuantity;
        
        // Check if required quantity exceeds current stock
        if (requiredQty > stock) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No stock available for $itemName. Need ${requiredQty.round()} ${ing['unit']} of ${ing['name']} but only ${stock.toInt()} available.'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
          return false;
        }
        
        // Check if stock is zero - no stock available
        if (stock <= 0) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No stock available for $itemName. No ${ing['name']} available.'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
          return false;
        }
      }
    }
    return true;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _updatePricing() {
    setState(() {
      _totalPrice = _menuService.calculateMenuTotalPrice(selectedItems);
      _depositAmount = _menuService.calculateMenuDepositAmount(_totalPrice, reservationType: widget.reservationType);
    });
  }

  void _addToSelection(MenuItem item) {
    int currentQty = selectedItems[item.name] ?? 0;
    if (!_isStockAvailable(item.name, currentQty + 1)) return;
    
    setState(() {
      selectedItems[item.name] = currentQty + 1;
    });
    _updatePricing();
  }

  void _removeFromSelection(MenuItem item) {
    setState(() {
      if (selectedItems[item.name] != null) {
        if (selectedItems[item.name]! > 1) {
          selectedItems[item.name] = selectedItems[item.name]! - 1;
        } else {
          selectedItems.remove(item.name);
        }
      }
    });
    _updatePricing();
  }

  void _clearSelection() {
    setState(() {
      selectedItems.clear();
    });
    _updatePricing();
  }

  List<MenuItem> _getFilteredItems() {
    final List<MenuItem> allItems = [];
    if (_selectedCategory == 'All') {
      for (var items in menu.values) {
        allItems.addAll(items);
      }
    } else {
      allItems.addAll(menu[_selectedCategory] ?? []);
    }

    if (_searchQuery.isEmpty) {
      return allItems;
    }

    return allItems.where((item) => 
      item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      item.category.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _getFilteredItems();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeaderSection(),
            
            // Pricing Summary Card (Subtle version)
            if (selectedItems.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total: PHP ${_fmt.format(_totalPrice)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          'Deposit: PHP ${_fmt.format(_depositAmount)}',
                          style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                    Text(
                      '${selectedItems.values.fold(0, (sum, qty) => sum + qty)} items',
                      style: const TextStyle(color: AppTheme.mediumGrey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            
            // Menu Items Grid
            Expanded(
              child: _buildCategoryGrid(filteredItems),
            ),
            
            // Bottom Action Bar
            if (selectedItems.isNotEmpty)
              _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Navigation Row
          Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                ),
              ),
              Text(
                'Select Menu Items',
                style: GoogleFonts.lora(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Search Bar Row
          Row(
            children: [
              // Red Bordered Search Bar (Now with white background for contrast)
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    style: const TextStyle(color: AppTheme.darkGrey),
                    decoration: InputDecoration(
                      hintText: 'Search for products...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14, fontWeight: FontWeight.w400),
                      prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 22),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Filter and Category Chips Row
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // Filter Icon Button
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
                ),
                // "All" Category
                _buildCategoryChip('All'),
                // Other Categories
                ...MenuService.categories.map((cat) => _buildCategoryChip(cat)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String category) {
    final bool isSelected = _selectedCategory == category;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = category),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check, size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
            ],
            Text(
              category,
              style: TextStyle(
                color: isSelected ? AppTheme.primaryColor : Colors.white,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.reservationType == 'Advance Order' 
                      ? 'Total Amount' 
                      : 'Deposit Required',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.mediumGrey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'PHP ${_fmt.format(_depositAmount)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryColor,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final validation = _menuService.validateMenuSelection(selectedItems);
              if (validation != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(validation)),
                );
                return;
              }
              
              widget.onMenuSelected(selectedItems);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 6,
              shadowColor: AppTheme.primaryColor.withOpacity(0.4),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Confirm Selection',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid(List<MenuItem> items) {
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'No items found.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: ResponsiveUtils.isDesktop(context) ? 4 : (ResponsiveUtils.isTablet(context) ? 3 : 2),
        childAspectRatio: 0.75,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final quantity = selectedItems[item.name] ?? 0;
        return _buildMenuItemCard(item, quantity);
      },
    );
  }

  Widget _buildMenuItemCard(MenuItem item, int quantity) {
    return Container(
      decoration: AppTheme.cardDecoration().copyWith(
        border: quantity > 0 
            ? Border.all(color: AppTheme.primaryColor, width: 2)
            : Border.all(color: Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Section
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Stack(
                children: [
                  _buildImageWidget(item),
                  if (quantity > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '$quantity',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'PHP ${_fmt.format(item.price)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Content Section
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppTheme.darkGrey,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.category,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.mediumGrey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => _removeFromSelection(item),
                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                        color: quantity > 0 ? AppTheme.primaryColor : AppTheme.lightGrey,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      Text(
                        '$quantity',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: -0.3,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _addToSelection(item),
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        color: AppTheme.primaryColor,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageWidget(MenuItem item) {
    final resolvedUrl = MenuService.resolveImageUrl(item.customImagePath ?? item.fallbackImagePath);
    if (resolvedUrl.isNotEmpty) {
      return Image.network(
        resolvedUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: AppTheme.lightGrey,
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        },
        errorBuilder: (context, error, stackTrace) => Container(
          color: AppTheme.lightGrey,
          child: const Icon(Icons.fastfood, color: Colors.grey, size: 40),
        ),
      );
    }
    return Container(
      color: AppTheme.lightGrey,
      child: const Icon(Icons.fastfood, color: Colors.grey, size: 40),
    );
  }
}

