import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/menu_item.dart';
import '../../services/menu_reservation_service.dart';
import '../../services/menu_service.dart';

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
        title: Text(
          'Select Menu Items (${widget.guestCount} guests)',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.red,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.red,
          indicatorWeight: 3,
          tabs: MenuService.categories.map((cat) => Tab(text: cat)).toList(),
        ),
        actions: [
          if (selectedItems.isNotEmpty)
            IconButton(
              onPressed: _clearSelection,
              icon: const Icon(Icons.clear_all, color: Colors.red),
              tooltip: 'Clear Selection',
            ),
        ],
      ),
      body: Column(
        children: [
          // Pricing Summary Card
          if (selectedItems.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
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
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        '${selectedItems.values.fold(0, (sum, qty) => sum + qty)} items',
                        style: TextStyle(
                          color: Colors.grey.shade600,
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
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        'PHP ${_fmt.format(_totalPrice)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
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
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        'PHP ${_fmt.format(_depositAmount)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
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
                          color: Color(0xFF64748B),
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
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
                          'Deposit Required',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          'PHP ${_fmt.format(_depositAmount)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
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
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: quantity > 0 
            ? Border.all(color: Colors.red, width: 2)
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
                          color: Colors.red,
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
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.category,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => _removeFromSelection(item),
                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                        color: quantity > 0 ? Colors.red : Colors.grey.shade400,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      Text(
                        '$quantity',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _addToSelection(item),
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        color: Colors.red,
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
        color: const Color(0xFFF1F5F9),
        child: const Icon(Icons.fastfood, color: Colors.grey, size: 40),
      ),
    );
  }
}
