import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/menu_item.dart';
import '../../services/menu_reservation_service.dart';
import '../../services/menu_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/responsive_utils.dart';

class MenuSelectionPage extends StatefulWidget {
  final int guestCount;
  final Function(Map<String, int>) onMenuSelected;
  final Map<String, int>? initialSelection;

  const MenuSelectionPage({
    super.key,
    required this.guestCount,
    required this.onMenuSelected,
    this.initialSelection,
  });

  @override
  State<MenuSelectionPage> createState() => _MenuSelectionPageState();
}

class _MenuSelectionPageState extends State<MenuSelectionPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Map<String, List<MenuItem>> menu;
  final Map<String, int> selectedItems = {};
  final MenuReservationService _menuService = MenuReservationService();
  final ScrollController _scrollController = ScrollController();
  final NumberFormat _fmt = NumberFormat('#,##0.00', 'en_US');
  
  double _totalPrice = 0.0;
  double _depositAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: MenuService.categories.length, vsync: this);
    menu = MenuService.getMenu();
    
    // Initialize with any provided selection
    if (widget.initialSelection != null) {
      selectedItems.addAll(widget.initialSelection!);
    }
    
    _updatePricing();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _updatePricing() {
    setState(() {
      _totalPrice = _menuService.calculateMenuTotalPrice(selectedItems);
      _depositAmount = _menuService.calculateMenuDepositAmount(_totalPrice);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.darkGrey),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Select Menu Items',
          style: const TextStyle(
            color: AppTheme.darkGrey,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.mediumGrey,
          indicatorColor: AppTheme.primaryColor,
          indicatorWeight: 3,
          tabs: MenuService.categories.map((cat) => Tab(text: cat)).toList(),
        ),
        actions: [
          if (selectedItems.isNotEmpty)
            IconButton(
              onPressed: _clearSelection,
              icon: const Icon(Icons.clear_all, color: AppTheme.primaryColor),
              tooltip: 'Clear Selection',
            ),
        ],
      ),
      body: Column(
        children: [
          // Pricing Summary Card
            Container(
              margin: ResponsiveUtils.getResponsiveMargin(context),
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.cardDecoration().copyWith(
                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.1), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Selected Items',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.darkGrey,
                        ),
                      ),
                      Text(
                        '${selectedItems.values.fold(0, (sum, qty) => sum + qty)} items',
                        style: const TextStyle(
                          color: AppTheme.mediumGrey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Menu Price:',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.mediumGrey,
                        ),
                      ),
                      Text(
                        'PHP ${_fmt.format(_totalPrice)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkGrey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '50% Deposit Required:',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.mediumGrey,
                        ),
                      ),
                      Text(
                        'PHP ${_fmt.format(_depositAmount)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Cost per Guest:',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.mediumGrey,
                        ),
                      ),
                      Text(
                        'PHP ${_fmt.format(_menuService.calculateCostPerGuest(_totalPrice, widget.guestCount))}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          
          // Menu Categories
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: MenuService.categories.map((cat) {
                final items = menu[cat] ?? [];
                return _buildCategoryGrid(items);
              }).toList(),
            ),
          ),
          
          // Bottom Action Bar
          if (selectedItems.isNotEmpty)
            Container(
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
                        const Text(
                          'Deposit Required',
                          style: TextStyle(
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
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid(List<MenuItem> items) {
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'No items available in this category.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return GridView.builder(
      padding: ResponsiveUtils.getResponsivePadding(context),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: ResponsiveUtils.isDesktop(context) ? 4 : (ResponsiveUtils.isTablet(context) ? 3 : 2),
        childAspectRatio: ResponsiveUtils.isDesktop(context) ? 0.8 : 0.72,
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
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
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
                    const SizedBox(height: 6),
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
        color: const Color(0xFFF1F5F9),
        child: const Icon(Icons.fastfood, color: Colors.grey, size: 40),
      ),
    );
  }
}
