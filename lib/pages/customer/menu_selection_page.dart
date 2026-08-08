import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/menu_item.dart';
import '../../services/menu_reservation_service.dart';
import '../../services/menu_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/responsive_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/widgets/customer/customer_ui_components.dart';

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

      // Fetch recipe ingredients
      final recipeData = await supabase.from('recipe_ingredients').select();
      final Map<String, List<Map<String, dynamic>>> newRecipeCache = {};
      for (var row in recipeData) {
        final menuItemName = row['menu_item_name'] as String;
        if (!newRecipeCache.containsKey(menuItemName)) {
          newRecipeCache[menuItemName] = [];
        }
        newRecipeCache[menuItemName]!.add(row);
      }
      if (mounted) {
        setState(() {
          _recipeCache.clear();
          _recipeCache.addAll(newRecipeCache);
        });
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
        final double ingredientQtyPerUnit = ing['quantity']?.toDouble() ?? 1.0;
        final double requiredQty = ingredientQtyPerUnit * requestedQuantity;
        
        if (requiredQty > stock) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No stock available for $itemName. Need ${requiredQty.round()} ${ing['unit']} of ${ing['name']} but only ${stock.toInt()} available.'),
              backgroundColor: AppTheme.errorRed,
              duration: const Duration(seconds: 2),
            ),
          );
          return false;
        }
        
        if (stock <= 0) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No stock available for $itemName. No ${ing['name']} available.'),
              backgroundColor: AppTheme.errorRed,
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
            
            // Pricing Summary Bar
            if (selectedItems.isNotEmpty)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.goldenAmber, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.goldenAmber.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total: ₱${_fmt.format(_totalPrice)}',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.darkGrey),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Deposit Required: ₱${_fmt.format(_depositAmount)}',
                          style: GoogleFonts.inter(color: AppTheme.primaryColor, fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: AppTheme.goldGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${selectedItems.values.fold(0, (sum, qty) => sum + qty)} items selected',
                        style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12),
                      ),
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
        color: AppTheme.navColor,
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
                child: AnimatedTapScale(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ),
              Text(
                'Select Menu Items',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Search Bar Row
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: GoogleFonts.inter(color: AppTheme.darkGrey, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search delicious dishes...',
                hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded, color: AppTheme.primaryColor, size: 22),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Filter and Category Chips Row
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildCategoryChip('All'),
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
    return AnimatedTapScale(
      onTap: () => setState(() => _selectedCategory = category),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.goldGradient : null,
          color: !isSelected ? Colors.white.withValues(alpha: 0.12) : null,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          category,
          style: GoogleFonts.inter(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
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
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.mediumGrey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '₱${_fmt.format(_depositAmount)}',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primaryColor,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          AnimatedTapScale(
            onTap: () {
              final validation = _menuService.validateMenuSelection(selectedItems);
              if (validation != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(validation),
                    backgroundColor: AppTheme.errorRed,
                  ),
                );
                return;
              }
              
              widget.onMenuSelected(selectedItems);
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                'Confirm Selection',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid(List<MenuItem> items) {
    if (items.isEmpty) {
      return const EmptyStateCard(
        icon: Icons.search_off_rounded,
        title: 'No dishes found',
        description: 'Try adjusting your search query or select another category.',
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: ResponsiveUtils.isDesktop(context) ? 4 : (ResponsiveUtils.isTablet(context) ? 3 : 2),
        childAspectRatio: 0.74,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
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
      decoration: AppTheme.foodCardDecoration().copyWith(
        border: quantity > 0 
            ? Border.all(color: AppTheme.goldenAmber, width: 2)
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: AppTheme.goldGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '$quantity',
                          style: GoogleFonts.inter(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '₱${_fmt.format(item.price)}',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
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
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: AppTheme.darkGrey,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AnimatedTapScale(
                        onTap: () => _removeFromSelection(item),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: quantity > 0 ? AppTheme.primaryColor.withValues(alpha: 0.12) : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.remove,
                            size: 16,
                            color: quantity > 0 ? AppTheme.primaryColor : Colors.grey,
                          ),
                        ),
                      ),
                      Text(
                        '$quantity',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: AppTheme.darkGrey,
                        ),
                      ),
                      AnimatedTapScale(
                        onTap: () => _addToSelection(item),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: AppTheme.goldGradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.add,
                            size: 16,
                            color: Colors.black,
                          ),
                        ),
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
          return const AppShimmer(width: double.infinity, height: double.infinity, borderRadius: 0);
        },
        errorBuilder: (context, error, stackTrace) => Container(
          color: AppTheme.lightGrey,
          child: const Icon(Icons.restaurant, color: Colors.grey, size: 36),
        ),
      );
    }
    return Container(
      color: AppTheme.lightGrey,
      child: const Icon(Icons.restaurant, color: Colors.grey, size: 36),
    );
  }
}
