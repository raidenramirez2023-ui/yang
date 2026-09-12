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
        childAspectRatio: ResponsiveUtils.isDesktop(context) ? 0.78 : (ResponsiveUtils.isTablet(context) ? 0.72 : 0.68),
        crossAxisSpacing: ResponsiveUtils.isDesktop(context) ? 24 : 14,
        mainAxisSpacing: ResponsiveUtils.isDesktop(context) ? 24 : 14,
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDE8DE), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: const Color(0xFF16302A).withValues(alpha: 0.02),
            blurRadius: 3,
            offset: const Offset(0, 1),
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildImageWidget(item),
                  // Bottom gradient scrim
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 36,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.38),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Price Badge: Frosted dark forest green with gold border & gold text
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8.5, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C241F).withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.warmGold.withValues(alpha: 0.4),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '₱${_fmt.format(item.price)}',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFFFD56B),
                          fontSize: 11.5,
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
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: const Color(0xFF1E293B),
                      letterSpacing: -0.2,
                      height: 1.25,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16302A).withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.restaurant_menu_rounded,
                                size: 10,
                                color: AppTheme.forestGreen.withValues(alpha: 0.8),
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  item.category,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 9.5,
                                    color: const Color(0xFF16302A),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppTheme.forestGreen,
                              Color(0xFF0F2B23),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.forestGreen.withValues(alpha: 0.28),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          size: 16,
                          color: Colors.white,
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
