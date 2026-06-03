import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/menu_item.dart';
import '../../services/menu_service.dart';
import '../../utils/responsive_utils.dart';
import 'package:yang_chow/utils/app_theme.dart';

class CustomerMenuPage extends StatefulWidget {
  const CustomerMenuPage({super.key});

  @override
  State<CustomerMenuPage> createState() => _CustomerMenuPageState();
}

class _CustomerMenuPageState extends State<CustomerMenuPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Map<String, List<MenuItem>> menu;
  final ScrollController _scrollController = ScrollController();
  final NumberFormat _fmt = NumberFormat('#,##0.00', 'en_US');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: MenuService.categories.length, vsync: this);
    menu = MenuService.getMenu();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Products & Pricing',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppTheme.darkGrey,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: AppTheme.mediumGrey,
              indicatorColor: AppTheme.primaryColor,
              indicatorWeight: 2.5,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                letterSpacing: 0.2,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              indicatorSize: TabBarIndicatorSize.label,
              tabs: MenuService.categories.map((cat) => Tab(text: cat)).toList(),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: MenuService.categories.map((cat) {
          final items = menu[cat] ?? [];
          return _buildCategoryGrid(items);
        }).toList(),
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
      padding: const EdgeInsets.all(20),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: ResponsiveUtils.isDesktop(context) ? 4 : (ResponsiveUtils.isTablet(context) ? 3 : 2),
        childAspectRatio: ResponsiveUtils.isDesktop(context) ? 0.82 : 0.78,
        crossAxisSpacing: ResponsiveUtils.isDesktop(context) ? 28 : 20,
        mainAxisSpacing: ResponsiveUtils.isDesktop(context) ? 28 : 20,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildProductCard(item);
      },
    );
  }

  Widget _buildProductCard(MenuItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
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
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '₱${_fmt.format(item.price)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
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
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppTheme.darkGrey,
                      letterSpacing: -0.2,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.category,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.mediumGrey,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
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

