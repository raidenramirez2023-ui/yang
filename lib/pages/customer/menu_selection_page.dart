import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/menu_item.dart';
import '../../services/menu_reservation_service.dart';
import '../../services/menu_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/responsive_utils.dart';

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

  @override
  void initState() {
    super.initState();
    menu = MenuService.getMenu();
    
    // Initialize with any provided selection
    if (widget.initialSelection != null) {
      selectedItems.addAll(widget.initialSelection!);
    }
    
    _updatePricing();
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
    setState(() {
      selectedItems[item.name] = (selectedItems[item.name] ?? 0) + 1;
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
                  border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.1)),
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
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    style: const TextStyle(color: AppTheme.darkGrey),
                    decoration: InputDecoration(
                      hintText: 'Search for products...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
                    color: Colors.white.withValues(alpha: 0.2),
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
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check, size: 16, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
            ],
            Text(
              category,
              style: TextStyle(
                color: isSelected ? AppTheme.primaryColor : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
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
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, -5),
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
                    fontSize: 12,
                    color: AppTheme.mediumGrey,
                  ),
                ),
                Text(
                  'PHP ${_fmt.format(_depositAmount)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Confirm Selection'),
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
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: ResponsiveUtils.isDesktop(context) ? 4 : (ResponsiveUtils.isTablet(context) ? 3 : 2),
        childAspectRatio: 0.72,
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  _buildImageWidget(item),
                  if (quantity > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$quantity',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
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
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'PHP ${_fmt.format(item.price)}',
                        style: const TextStyle(
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: AppTheme.darkGrey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.category,
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppTheme.mediumGrey,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => _removeFromSelection(item),
                        icon: const Icon(Icons.remove_circle_outline, size: 18),
                        color: quantity > 0 ? AppTheme.primaryColor : AppTheme.lightGrey,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      Text(
                        '$quantity',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _addToSelection(item),
                        icon: const Icon(Icons.add_circle_outline, size: 18),
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
    final imagePath = item.customImagePath ?? item.fallbackImagePath;
    return Image.asset(
      imagePath,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) => Container(
        color: AppTheme.lightGrey,
        child: const Icon(Icons.fastfood, color: Colors.grey, size: 40),
      ),
    );
  }
}
