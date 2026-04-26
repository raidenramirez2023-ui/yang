import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yang_chow/models/menu_item.dart';
import 'package:yang_chow/services/menu_service.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';

class AllProductsPage extends StatefulWidget {
  const AllProductsPage({super.key});

  @override
  State<AllProductsPage> createState() => _AllProductsPageState();
}

class _AllProductsPageState extends State<AllProductsPage> {
  final TextEditingController _searchController = TextEditingController();
  final NumberFormat _fmt = NumberFormat('#,##0.00', 'en_US');
  String _selectedFilter = 'All';
  
  late Map<String, List<MenuItem>> _menuData;
  List<MenuItem> _allProducts = [];
  List<MenuItem> _filteredProducts = [];
  String _searchQuery = '';
  late List<String> _filters;

  @override
  void initState() {
    super.initState();
    _filters = ['All', ...MenuService.categories];
    _loadMenuData();
    _searchController.addListener(_onSearchChanged);
  }

  void _loadMenuData() {
    _menuData = MenuService.getMenu();
    _allProducts = [];
    _menuData.forEach((category, items) {
      _allProducts.addAll(items);
    });
    _filteredProducts = _allProducts;
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _applyFilters();
    });
  }

  void _applyFilters() {
    setState(() {
      _filteredProducts = _allProducts.where((item) {
        final matchesSearch = item.name.toLowerCase().contains(_searchQuery) ||
            item.category.toLowerCase().contains(_searchQuery);
        
        if (_selectedFilter == 'All') return matchesSearch;
        
        // Simple logic for other filters based on categories or metadata if available
        // For now, we'll just match the filter string to category for demo
        final matchesFilter = item.category.toLowerCase().contains(_selectedFilter.toLowerCase());
        
        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFilterChips(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  setState(() {
                    _loadMenuData();
                    _applyFilters();
                  });
                },
                color: AppTheme.primaryColor,
                child: _buildProductsContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          // Close button as shown in reference
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded, size: 20, color: Colors.black87),
            ),
          ),
          const SizedBox(width: 12),
          // Search Bar
          Expanded(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: AppTheme.lightGrey,
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search for products...',
                  hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () => _searchController.clear(),
                          child: Icon(Icons.cancel_rounded, color: Colors.grey.shade400, size: 20),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
          },
        ),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _filters.length + 1, // +1 for the settings/filter icon
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Icon(Icons.tune_rounded, size: 18, color: Colors.black87),
                ),
              );
            }
            
            final filter = _filters[index - 1];
            final isSelected = _selectedFilter == filter;
            
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: ChoiceChip(
                label: Text(filter),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedFilter = filter;
                    _applyFilters();
                  });
                },
                selectedColor: AppTheme.primaryColor,
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 13,
                ),
                shape: StadiumBorder(
                  side: BorderSide(
                    color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200,
                    width: 1.5,
                  ),
                ),
                elevation: isSelected ? 4 : 0,
                shadowColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                pressElevation: 0,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProductsContent() {
    if (_filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No products found matching "$_searchQuery"',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: ResponsiveUtils.isDesktop(context) ? 5 : (ResponsiveUtils.isTablet(context) ? 4 : 3),
          childAspectRatio: ResponsiveUtils.isDesktop(context) ? 0.75 : (ResponsiveUtils.isTablet(context) ? 0.7 : 0.65),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _filteredProducts.length,
        itemBuilder: (context, index) {
          return _buildProductCard(_filteredProducts[index]);
        },
      ),
    );
  }

  Widget _buildProductCard(MenuItem item) {
    bool isHovered = false;
    return StatefulBuilder(
      builder: (context, setCardState) {
        return MouseRegion(
          onEnter: (_) => setCardState(() => isHovered = true),
          onExit: (_) => setCardState(() => isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            transform: isHovered ? Matrix4.translationValues(0, -4, 0) : Matrix4.identity(),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: isHovered 
                    ? AppTheme.primaryColor.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.05),
                  blurRadius: isHovered ? 25 : 10,
                  offset: isHovered ? const Offset(0, 10) : const Offset(0, 4),
                ),
              ],
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
                        // Glassmorphic Price Badge
                        Positioned(
                          top: 12,
                          right: 12,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  '₱${_fmt.format(item.price)}',
                                  style: const TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
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
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                            color: AppTheme.darkGrey,
                            height: 1.2,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.lightGrey,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.category.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 6.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.mediumGrey,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 10,
                              color: isHovered ? AppTheme.primaryColor : AppTheme.mediumGrey.withValues(alpha: 0.4),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildImageWidget(MenuItem item) {
    final imagePath = item.customImagePath ?? item.fallbackImagePath;
    return Image.asset(
      imagePath,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey.shade100,
          child: const Icon(Icons.image_not_supported_rounded, color: Colors.grey),
        );
      },
    );
  }
}
