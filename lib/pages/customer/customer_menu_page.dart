import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/menu_item.dart';
import '../../services/menu_service.dart';
import '../../utils/responsive_utils.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/widgets/customer/customer_ui_components.dart';

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
        title: Text(
          'Products & Pricing',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: Colors.white,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        backgroundColor: AppTheme.navColor,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppTheme.navColor,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppTheme.darkBrownText,
              unselectedLabelColor: AppTheme.sidebarInactiveText,
              indicator: BoxDecoration(
                color: AppTheme.warmGold,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.warmGold.withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              padding: EdgeInsets.zero,
              labelPadding: const EdgeInsets.symmetric(horizontal: 16),
              labelStyle: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 0.2,
              ),
              unselectedLabelStyle: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
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
      return const EmptyStateCard(
        icon: Icons.no_meals_outlined,
        title: 'No items available',
        description: 'There are currently no items listed in this category.',
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: ResponsiveUtils.isDesktop(context) ? 4 : (ResponsiveUtils.isTablet(context) ? 3 : 2),
        childAspectRatio: ResponsiveUtils.isDesktop(context) ? 0.80 : 0.76,
        crossAxisSpacing: ResponsiveUtils.isDesktop(context) ? 24 : 16,
        mainAxisSpacing: ResponsiveUtils.isDesktop(context) ? 24 : 16,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return AnimatedTapScale(
          child: _buildProductCard(item),
        );
      },
    );
  }

  Widget _buildProductCard(MenuItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorder, width: 1), // Light warm gray border #E5E0D2
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
              child: Stack(
                children: [
                  _buildImageWidget(item),
                  // Price Badge: #16302A Deep forest green bg with #F5F1E6 text
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.priceBadgeBg, // #16302A Deep forest green
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '₱${_fmt.format(item.price)}',
                        style: GoogleFonts.inter(
                          color: AppTheme.priceBadgeText, // #F5F1E6 Off-white
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppTheme.darkGrey, // #2C2C2A Near-black warm gray
                      letterSpacing: -0.2,
                      height: 1.25,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Category Tag: Rust/coral #993C1D
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.categoryTagText.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.category,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppTheme.categoryTagText, // #993C1D Rust/coral
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: AppTheme.warmGold,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 11,
                          color: AppTheme.darkBrownText,
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
          child: const Icon(Icons.restaurant, color: AppTheme.mediumGrey, size: 36),
        ),
      );
    }
    return Container(
      color: AppTheme.lightGrey,
      child: const Icon(Icons.restaurant, color: AppTheme.mediumGrey, size: 36),
    );
  }
}
