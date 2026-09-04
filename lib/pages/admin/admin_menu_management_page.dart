import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'dart:io' show File;
import '../../models/menu_item.dart';
import '../../services/menu_service.dart';
import '../../services/recipe_seeder.dart';
import '../../services/audit_log_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/responsive_utils.dart';
import '../../utils/app_constants.dart';

class AdminMenuManagementPage extends StatefulWidget {
  const AdminMenuManagementPage({super.key});

  @override
  State<AdminMenuManagementPage> createState() => _AdminMenuManagementPageState();
}

class _AdminMenuManagementPageState extends State<AdminMenuManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _categoryScrollController = ScrollController();
  String _searchQuery = '';
  String _selectedCategoryFilter = 'All';
  bool _isLoading = true;
  bool _canScrollLeft = false;
  bool _canScrollRight = true;
  Map<String, List<MenuItem>> _menu = {};
  List<String> _categories = [];

  // Preset colors for menu item badges
  final List<Color> _presetColors = [
    Colors.red,
    Colors.orange,
    Colors.deepOrange,
    Colors.amber,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.lightBlue,
    Colors.purple,
    Colors.pink,
    Colors.brown,
    Colors.grey,
  ];

  @override
  void initState() {
    super.initState();
    _loadMenuData();
    _categoryScrollController.addListener(_updateScrollArrows);
  }

  void _updateScrollArrows() {
    final sc = _categoryScrollController;
    if (!sc.hasClients) return;
    setState(() {
      _canScrollLeft = sc.offset > 4;
      _canScrollRight = sc.offset < sc.position.maxScrollExtent - 4;
    });
  }

  void _scrollCategoryLeft() {
    _categoryScrollController.animateTo(
      (_categoryScrollController.offset - 200).clamp(0.0, double.infinity),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _scrollCategoryRight() {
    final max = _categoryScrollController.position.maxScrollExtent;
    _categoryScrollController.animateTo(
      (_categoryScrollController.offset + 200).clamp(0.0, max),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _loadMenuData() async {
    setState(() => _isLoading = true);
    try {
      final menuData = await MenuService.fetchMenu();
      if (mounted) {
        setState(() {
          _menu = menuData;
          _categories = MenuService.categories;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load menu: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<MenuItem> _getFilteredItems() {
    final List<MenuItem> allItems = [];
    _menu.forEach((category, items) {
      if (_selectedCategoryFilter == 'All' || category == _selectedCategoryFilter) {
        allItems.addAll(items);
      }
    });

    if (_searchQuery.isEmpty) return allItems;

    return allItems.where((item) {
      final name = item.name.toLowerCase();
      final desc = (item.description ?? '').toLowerCase();
      final cat = item.category.toLowerCase();
      return name.contains(_searchQuery) || desc.contains(_searchQuery) || cat.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _getFilteredItems();
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final isTablet = ResponsiveUtils.isTablet(context);
    
    // KPI computations
    final allItemsList = _menu.values.expand((list) => list).toList();
    final totalItems = allItemsList.length;
    final totalCategories = _categories.length;
    final avgPrice = totalItems > 0 
        ? allItemsList.fold<double>(0.0, (sum, i) => sum + i.price) / totalItems 
        : 0.0;

    final isMobile = ResponsiveUtils.isMobile(context);

    int crossAxisCount = 2;
    double childAspectRatio = 0.70;
    if (isDesktop) {
      crossAxisCount = 4;
      childAspectRatio = 0.80;
    } else if (isTablet) {
      crossAxisCount = 3;
      childAspectRatio = 0.75;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 12,
          vertical: isMobile ? 8 : 12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Enterprise Header ─────────────────────────────────────────────
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 14 : 20,
                vertical: isMobile ? 14 : 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF14332E), Color(0xFF1E4A42)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF14332E).withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.restaurant_menu_rounded, color: Color(0xFFD9A441), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Text(
                                  'Menu & Recipe Management',
                                  style: TextStyle(
                                    fontSize: isMobile ? 16 : 18,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFF86EFAC)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.cloud_done_rounded, size: 11, color: Color(0xFF15803D)),
                                      SizedBox(width: 4),
                                      Text(
                                        'POS Synced',
                                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isMobile
                                  ? 'Configure food catalog, pricing & recipes'
                                  : 'Configure food catalog, pricing tiers, ingredient recipes, and kitchen availability',
                              style: TextStyle(
                                fontSize: isMobile ? 11 : 12,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isMobile) ...[
                        IconButton(
                          onPressed: () => RecipeSeeder.seedRecipesToDatabase(context),
                          icon: const Icon(Icons.upload_file_rounded, color: Color(0xFFC9922E)),
                          tooltip: 'Upload Hardcoded Recipes to Database',
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _showAddEditDialog(null),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add Menu Item', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF14332E),
                            foregroundColor: const Color(0xFFD9A441),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFFD9A441), width: 1),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (isMobile) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => RecipeSeeder.seedRecipesToDatabase(context),
                          icon: const Icon(Icons.upload_file_rounded, size: 14),
                          label: const Text('Sync Recipes'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFC9922E),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showAddEditDialog(null),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Add Menu Item'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF14332E),
                              foregroundColor: const Color(0xFFD9A441),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: const BorderSide(color: Color(0xFFD9A441), width: 1),
                              ),
                              textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── KPI Quick Strip (Responsive Carousel on Mobile) ───────────────
            if (isMobile)
              SizedBox(
                height: 64,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    Container(
                      width: 175,
                      margin: const EdgeInsets.only(right: 8),
                      child: _buildMenuKpiCard(
                        title: 'Total Items',
                        value: '$totalItems',
                        subtitle: 'In catalog',
                        icon: Icons.inventory_2_rounded,
                        color: const Color(0xFF0284C7),
                        bg: const Color(0xFFE0F2FE),
                      ),
                    ),
                    Container(
                      width: 175,
                      margin: const EdgeInsets.only(right: 8),
                      child: _buildMenuKpiCard(
                        title: 'Active Categories',
                        value: '$totalCategories',
                        subtitle: 'Menu sections',
                        icon: Icons.category_rounded,
                        color: const Color(0xFF7E22CE),
                        bg: const Color(0xFFF3E8FF),
                      ),
                    ),
                    Container(
                      width: 175,
                      margin: const EdgeInsets.only(right: 8),
                      child: _buildMenuKpiCard(
                        title: 'Average Price',
                        value: '₱${avgPrice.toStringAsFixed(2)}',
                        subtitle: 'Per serving',
                        icon: Icons.monetization_on_rounded,
                        color: const Color(0xFF15803D),
                        bg: const Color(0xFFDCFCE7),
                      ),
                    ),
                    Container(
                      width: 175,
                      margin: const EdgeInsets.only(right: 8),
                      child: _buildMenuKpiCard(
                        title: 'Search Match',
                        value: '${filteredItems.length}',
                        subtitle: _searchQuery.isEmpty ? 'Showing all' : 'Filtered results',
                        icon: Icons.filter_alt_rounded,
                        color: const Color(0xFFD97706),
                        bg: const Color(0xFFFEF3C7),
                      ),
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _buildMenuKpiCard(
                      title: 'Total Menu Items',
                      value: '$totalItems',
                      subtitle: 'Configured in catalog',
                      icon: Icons.inventory_2_rounded,
                      color: const Color(0xFF0284C7),
                      bg: const Color(0xFFE0F2FE),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMenuKpiCard(
                      title: 'Active Categories',
                      value: '$totalCategories',
                      subtitle: 'Menu sections',
                      icon: Icons.category_rounded,
                      color: const Color(0xFF7E22CE),
                      bg: const Color(0xFFF3E8FF),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMenuKpiCard(
                      title: 'Average Price',
                      value: '₱${avgPrice.toStringAsFixed(2)}',
                      subtitle: 'Per serving',
                      icon: Icons.monetization_on_rounded,
                      color: const Color(0xFF15803D),
                      bg: const Color(0xFFDCFCE7),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMenuKpiCard(
                      title: 'Search Match',
                      value: '${filteredItems.length}',
                      subtitle: _searchQuery.isEmpty ? 'Showing all' : 'Filtered results',
                      icon: Icons.filter_alt_rounded,
                      color: const Color(0xFFD97706),
                      bg: const Color(0xFFFEF3C7),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),

            // ── Search & Filter Controls ─────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Search menu items by name, ingredients, or description...',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF64748B)),
                                onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); },
                              )
                            : null,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        '${filteredItems.length} items',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                      ),

                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Category Pills Bar ───────────────────────────────────────────
            Stack(
              alignment: Alignment.center,
              children: [
                // Scrollable pills
                SingleChildScrollView(
                  controller: _categoryScrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    children: [
                      _buildCategoryPill('All', allItemsList.length, Icons.grid_view_rounded),
                      ..._categories.map((cat) => _buildCategoryPill(
                        cat,
                        _menu[cat]?.length ?? 0,
                        _getCategoryIcon(cat),
                      )),
                    ],
                  ),
                ),

                // ← Left arrow
                Positioned(
                  left: 0,
                  child: AnimatedOpacity(
                    opacity: _canScrollLeft ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: !_canScrollLeft,
                      child: _buildScrollArrow(
                        icon: Icons.chevron_left_rounded,
                        onTap: _scrollCategoryLeft,
                      ),
                    ),
                  ),
                ),

                // → Right arrow
                Positioned(
                  right: 0,
                  child: AnimatedOpacity(
                    opacity: _canScrollRight ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: !_canScrollRight,
                      child: _buildScrollArrow(
                        icon: Icons.chevron_right_rounded,
                        onTap: _scrollCategoryRight,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Main Content Grid ────────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC9922E)),
                      ),
                    )
                  : filteredItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.no_meals_rounded, size: 48, color: Color(0xFF94A3B8)),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No matching dishes found',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Check your search spelling or reset the category filter',
                                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                    _selectedCategoryFilter = 'All';
                                  });
                                },
                                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                                label: const Text('Reset All Filters'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF14332E),
                                  foregroundColor: Colors.white,
                                ),
                              )
                            ],
                          ),
                        )
                      : GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: childAspectRatio,
                          ),
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            return _buildMenuItemCard(item);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String cat) {
    final lower = cat.toLowerCase();
    if (lower.contains('rice')) return Icons.rice_bowl_rounded;
    if (lower.contains('noodle') || lower.contains('soup')) return Icons.ramen_dining_rounded;
    if (lower.contains('dimsum') || lower.contains('appetizer')) return Icons.tapas_rounded;
    if (lower.contains('drink') || lower.contains('beverage')) return Icons.local_drink_rounded;
    if (lower.contains('dessert') || lower.contains('sweet')) return Icons.icecream_rounded;
    if (lower.contains('pork') || lower.contains('beef') || lower.contains('chicken') || lower.contains('main')) return Icons.outdoor_grill_rounded;
    return Icons.restaurant_rounded;
  }

  Widget _buildCategoryPill(String label, int? count, IconData icon) {
    final isSelected = _selectedCategoryFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() { _selectedCategoryFilter = label; }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF14332E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? const Color(0xFF14332E) : const Color(0xFFE2E8F0),
            ),
            boxShadow: isSelected ? [
              BoxShadow(
                color: const Color(0xFF14332E).withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ] : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? const Color(0xFFD9A441) : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFD9A441).withValues(alpha: 0.3)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? const Color(0xFFD9A441) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Small arrow button used on the category pills bar.
  Widget _buildScrollArrow({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF14332E)),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _categoryScrollController.dispose();
    super.dispose();
  }

  Widget _buildMenuItemCard(MenuItem item) {
    return _HoverMenuCard(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image Header ─────────────────────────────────────────────
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.network(
                      MenuService.resolveImageUrl(item.customImagePath ?? item.fallbackImagePath),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: const Color(0xFFF1F5F9),
                          child: const Center(
                            child: Icon(Icons.restaurant_rounded, size: 40, color: Color(0xFF94A3B8)),
                          ),
                        );
                      },
                    ),
                  ),
                  // Bottom gradient overlay for readability
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.65),
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Category Tag (top-left)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14332E).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFD9A441).withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getCategoryIcon(item.category), size: 10, color: const Color(0xFFD9A441)),
                          const SizedBox(width: 4),
                          Text(
                            item.category.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFFD9A441),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Action buttons (top-right)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      children: [
                        _buildCardActionBtn(
                          icon: Icons.edit_rounded,
                          color: const Color(0xFF0284C7),
                          onTap: () => _showAddEditDialog(item),
                          tooltip: 'Edit Recipe & Details',
                        ),
                        const SizedBox(width: 4),
                        _buildCardActionBtn(
                          icon: Icons.delete_outline_rounded,
                          color: const Color(0xFFDC2626),
                          onTap: () => _showDeleteConfirmation(item),
                          tooltip: 'Delete Item',
                        ),
                      ],
                    ),
                  ),
                  // Price badge (bottom-right)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD9A441), Color(0xFFC9922E)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '₱${item.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── Info Section ─────────────────────────────────────────────
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.description ?? 'Standard restaurant serving with house special seasoning.',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    // Realistic Footer Pills (Kitchen Status + Recipe Linked)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, size: 5, color: Color(0xFF15803D)),
                              SizedBox(width: 4),
                              Text(
                                'In Kitchen',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.restaurant_rounded, size: 9, color: Color(0xFF64748B)),
                              SizedBox(width: 4),
                              Text(
                                'Recipe Active',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
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
      ),
    );
  }

  Widget _buildCardActionBtn({required IconData icon, required Color color, required VoidCallback onTap, required String tooltip}) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }

  // GALLERY DIALOG FOR SELECTING IMAGE
  Future<String?> _showImageGalleryDialog() async {
    setState(() => _isLoading = true);
    List<String> filenames = [];
    try {
      final list = await Supabase.instance.client.storage.from('restaurant-assets').list();
      filenames = list.map((obj) => obj.name).toList();
    } catch (e) {
      debugPrint('Error listing bucket files: $e');
    } finally {
      setState(() => _isLoading = false);
    }

    if (filenames.isEmpty) {
      filenames = [
        'YC1.png',
        'YC2.png',
        'YC3.jpg',
        'YC4.jpg',
        'Overloadmeals.png',
        'YCFriedRice.jpg',
      ];
    }

    return showDialog<String>(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 600,
            height: 500,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Select Menu Image', style: Theme.of(context).textTheme.headlineSmall),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: filenames.length,
                    itemBuilder: (context, index) {
                      final name = filenames[index];
                      final url = AppConstants.imageUrl(name);
                      return InkWell(
                        onTap: () => Navigator.pop(context, name),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              Expanded(
                                child: Image.network(
                                  url,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (context, e, s) => Container(
                                    color: Colors.grey.shade100,
                                    child: const Icon(Icons.image, color: Colors.grey),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Text(
                                  name,
                                  style: const TextStyle(fontSize: 10),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // DIALOG FOR CREATING / UPDATING MENU ITEM
  void _showAddEditDialog(MenuItem? item) async {
    final isEdit = item != null;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: item?.name ?? '');
    final priceController = TextEditingController(text: item?.price.toString() ?? '');
    final descController = TextEditingController(text: item?.description ?? '');
    final customCategoryController = TextEditingController();

    String selectedCategory = isEdit ? item.category : _categories.isNotEmpty ? _categories.first : 'Appetizer';
    Color selectedColor = isEdit ? item.color : Colors.orange;
    String selectedImagePath = isEdit ? (item.customImagePath ?? item.fallbackImagePath.split('/').last) : 'YCFriedRice.jpg';
    bool showCustomCategory = false;
    bool isSaving = false;

    // Recipe ingredients state
    const List<String> unitOptions = ['kilo', 'pcs', 'gram', 'ml', 'bot', 'pack', 'can', 'order', 'serving'];
    const List<String> ingCategoryOptions = ['Groceries', 'Vegetables', 'Fresh', 'Sauces', 'Roasting', 'Davids', 'Pre-mix'];
    int nextIngUid = 0;
    List<Map<String, dynamic>> ingredients = [];

    // Fetch existing ingredients for edit mode
    if (isEdit) {
      try {
        final ingResponse = await Supabase.instance.client
            .from('recipe_ingredients')
            .select()
            .eq('menu_item_name', item.name);
        if ((ingResponse as List).isNotEmpty) {
          for (final row in ingResponse) {
            final unitVal = (row['unit'] as String?) ?? 'pcs';
            final catVal = (row['category'] as String?) ?? 'Groceries';
            ingredients.add(<String, dynamic>{
              '_uid': nextIngUid++,
              'name': (row['name'] as String?) ?? '',
              'quantity': (row['quantity'] as num?)?.toDouble() ?? 1.0,
              'unit': unitOptions.contains(unitVal) ? unitVal : 'pcs',
              'category': ingCategoryOptions.contains(catVal) ? catVal : 'Groceries',
            });
          }
        }
      } catch (e) {
        debugPrint('Error fetching recipe ingredients: $e');
      }
    }

    // Fetch kitchen inventory for autocomplete
    List<Map<String, dynamic>> kitchenInventory = [];
    try {
      final invResponse = await Supabase.instance.client
          .from('kitchen_inventory')
          .select('name, category, unit');
      if ((invResponse as List).isNotEmpty) {
        kitchenInventory = List<Map<String, dynamic>>.from(invResponse);
      }
    } catch (e) {
      debugPrint('Error fetching kitchen inventory: $e');
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Helper to get MIME type from file extension
            String _getMimeType(String filename) {
              final ext = filename.split('.').last.toLowerCase();
              switch (ext) {
                case 'jpg':
                case 'jpeg':
                case 'jfif':
                  return 'image/jpeg';
                case 'png':
                  return 'image/png';
                case 'webp':
                  return 'image/webp';
                case 'svg':
                  return 'image/svg+xml';
                default:
                  return 'image/jpeg';
              }
            }

            Future<void> handleImageUpload() async {
              try {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'svg', 'jfif'],
                );
                if (result != null) {
                  setDialogState(() => isSaving = true);
                  final fileBytes = result.files.single.bytes;
                  final filename = result.files.single.name;
                  final mimeType = _getMimeType(filename);
                  
                  if (kIsWeb) {
                    if (fileBytes != null) {
                      await Supabase.instance.client.storage
                          .from('restaurant-assets')
                          .uploadBinary(filename, fileBytes,
                              fileOptions: FileOptions(contentType: mimeType));
                      setDialogState(() {
                        selectedImagePath = filename;
                      });
                    }
                  } else {
                    final path = result.files.single.path;
                    if (path != null) {
                      final bytes = await File(path).readAsBytes();
                      await Supabase.instance.client.storage
                          .from('restaurant-assets')
                          .uploadBinary(filename, bytes,
                              fileOptions: FileOptions(contentType: mimeType));
                      setDialogState(() {
                        selectedImagePath = filename;
                      });
                    }
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Image uploaded successfully!'), backgroundColor: AppTheme.successGreen),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppTheme.errorRed),
                );
              } finally {
                setDialogState(() => isSaving = false);
              }
            }

            Future<void> chooseFromGallery() async {
              final chosen = await _showImageGalleryDialog();
              if (chosen != null) {
                setDialogState(() {
                  selectedImagePath = chosen;
                });
              }
            }

            final isDialogMobile = MediaQuery.of(context).size.width < 500;
            return AlertDialog(
              insetPadding: EdgeInsets.symmetric(
                horizontal: isDialogMobile ? 12 : 24,
                vertical: 20,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                isEdit ? 'Edit Menu Item' : 'Add New Menu Item',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: isDialogMobile ? double.maxFinite : 550,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Name
                        TextFormField(
                          controller: nameController,
                          maxLength: 50,
                          decoration: const InputDecoration(
                            labelText: 'Item Name',
                            prefixIcon: Icon(Icons.restaurant_menu),
                            counterText: '',
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Please enter a name';
                            if (val.trim().length > 50) return 'Item name must be 50 characters or less';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Price and Category Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: priceController,
                                decoration: const InputDecoration(labelText: 'Price (₱)', prefixIcon: Icon(Icons.payments_outlined)),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                                ],
                                validator: (val) {
                                  if (val == null || val.isEmpty) return 'Please enter a price';
                                  final double? p = double.tryParse(val);
                                  if (p == null || p < 0) return 'Invalid price';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: showCustomCategory ? null : selectedCategory,
                                isExpanded: true,
                                decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category)),
                                selectedItemBuilder: (context) {
                                  final allItems = [..._categories, 'NEW_CATEGORY'];
                                  return allItems.map((cat) => Text(
                                    cat == 'NEW_CATEGORY' ? '+ New Category' : cat,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  )).toList();
                                },
                                items: [
                                  ..._categories.map((String cat) {
                                    return DropdownMenuItem<String>(value: cat, child: Text(cat));
                                  }),
                                  const DropdownMenuItem<String>(
                                    value: 'NEW_CATEGORY',
                                    child: Text('+ Create New Category', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                                  )
                                ],
                                onChanged: (val) {
                                  if (val == 'NEW_CATEGORY') {
                                    setDialogState(() {
                                      showCustomCategory = true;
                                    });
                                  } else if (val != null) {
                                    setDialogState(() {
                                      selectedCategory = val;
                                      showCustomCategory = false;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        if (showCustomCategory) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: customCategoryController,
                            decoration: InputDecoration(
                              labelText: 'New Category Name',
                              prefixIcon: const Icon(Icons.create_new_folder),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.cancel, color: Colors.grey),
                                onPressed: () {
                                  setDialogState(() {
                                    showCustomCategory = false;
                                  });
                                },
                              ),
                            ),
                            validator: (val) {
                              if (showCustomCategory && (val == null || val.trim().isEmpty)) {
                                return 'Please enter new category name';
                              }
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Description
                        TextFormField(
                          controller: descController,
                          maxLines: 2,
                          decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true, prefixIcon: Icon(Icons.description)),
                        ),
                        const SizedBox(height: 20),

                        // Image Picker/Selection
                        const Text('Menu Item Image', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.network(
                                AppConstants.imageUrl(selectedImagePath),
                                fit: BoxFit.cover,
                                errorBuilder: (context, e, s) => const Icon(Icons.restaurant, color: Colors.grey),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedImagePath,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: isSaving ? null : chooseFromGallery,
                                        icon: const Icon(Icons.photo_library, size: 14),
                                        label: const Text('Choose File', style: TextStyle(fontSize: 12)),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        onPressed: isSaving ? null : handleImageUpload,
                                        icon: const Icon(Icons.upload, size: 14),
                                        label: const Text('Upload Image', style: TextStyle(fontSize: 12)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.darkGrey,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Color Preset Picker
                        const Text('Color Badge', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _presetColors.map((Color c) {
                            final bool isSelected = selectedColor.toARGB32() == c.toARGB32();
                            return InkWell(
                              onTap: () => setDialogState(() => selectedColor = c),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? Colors.black : Colors.transparent,
                                    width: 2,
                                  ),
                                  boxShadow: isSelected
                                      ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 6, spreadRadius: 1)]
                                      : null,
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),

                        // Recipe Ingredients Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Recipe Ingredients', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            TextButton.icon(
                              onPressed: () {
                                setDialogState(() {
                                  ingredients.add(<String, dynamic>{
                                    '_uid': nextIngUid++,
                                    'name': '',
                                    'quantity': 1.0,
                                    'unit': 'pcs',
                                    'category': 'Groceries',
                                  });
                                });
                              },
                              icon: const Icon(Icons.add_circle_outline, size: 16),
                              label: const Text('Add Ingredient', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (ingredients.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: const Center(
                              child: Text(
                                'No ingredients added yet. Click "Add Ingredient" to start.',
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ),
                          ),
                        ...ingredients.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final ing = entry.value;
                          return Padding(
                            key: ValueKey(ing['_uid']),
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                // Category First
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: ing['category'] as String,
                                    isDense: true,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Category',
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                                      border: OutlineInputBorder(),
                                    ),
                                    style: const TextStyle(fontSize: 11, color: Colors.black87),
                                    items: ingCategoryOptions
                                        .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 11))))
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setDialogState(() {
                                          ing['category'] = val;
                                          ing['name'] = ''; // Reset name on category change
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 4),

                                // Name (Autocomplete)
                                Expanded(
                                  flex: 3,
                                  child: Autocomplete<String>(
                                    key: ValueKey('${ing['_uid']}_${ing['category']}'),
                                    initialValue: TextEditingValue(text: ing['name'] as String),
                                    optionsBuilder: (TextEditingValue textEditingValue) {
                                      final categoryItems = kitchenInventory
                                          .where((item) => item['category'] == ing['category'])
                                          .map((item) => item['name'].toString())
                                          .toSet()
                                          .toList();
                                      
                                      if (textEditingValue.text.isEmpty) {
                                        return categoryItems;
                                      }
                                      return categoryItems.where((option) =>
                                          option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                                    },
                                    onSelected: (String selection) {
                                      final selectedItem = kitchenInventory.firstWhere(
                                        (item) => item['name'] == selection && item['category'] == ing['category'],
                                        orElse: () => <String, dynamic>{'unit': 'pcs'},
                                      );
                                      
                                      setDialogState(() {
                                        ing['name'] = selection;
                                        ing['quantity'] = 1.0;
                                        final unitVal = selectedItem['unit'] as String? ?? 'pcs';
                                        ing['unit'] = unitOptions.contains(unitVal) ? unitVal : 'pcs';
                                      });
                                    },
                                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                      return TextFormField(
                                        controller: controller,
                                        focusNode: focusNode,
                                        decoration: InputDecoration(
                                          labelText: 'Ingredient Name',
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                          border: const OutlineInputBorder(),
                                        ),
                                        style: const TextStyle(fontSize: 12),
                                        onChanged: (val) => ing['name'] = val,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 4),
                                
                                // Quantity
                                SizedBox(
                                  width: 55,
                                  child: TextFormField(
                                    key: ValueKey('qty_${ing['_uid']}_${ing['name']}'),
                                    initialValue: ing['quantity'].toString(),
                                    enabled: false,
                                    readOnly: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Qty',
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                                      border: OutlineInputBorder(),
                                    ),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                
                                // Unit
                                SizedBox(
                                  width: 75,
                                  child: TextFormField(
                                    key: ValueKey('unit_${ing['_uid']}_${ing['unit']}'),
                                    initialValue: ing['unit'] as String,
                                    enabled: false,
                                    readOnly: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Unit',
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                                      border: OutlineInputBorder(),
                                    ),
                                    style: const TextStyle(fontSize: 11, color: Colors.black87),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 18),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.only(left: 4),
                                  onPressed: () => setDialogState(() => ingredients.removeAt(idx)),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            // Show confirmation dialog before saving
                            final bool? confirmSave = await showDialog<bool>(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('Confirmation'),
                                  content: Text(isEdit 
                                      ? 'Are you done editing this menu item?' 
                                      : 'Are you done adding this menu item?'),
                                  actions: <Widget>[
                                    TextButton(
                                      child: const Text('No'),
                                      onPressed: () => Navigator.of(context).pop(false),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryColor,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Yes'),
                                      onPressed: () => Navigator.of(context).pop(true),
                                    ),
                                  ],
                                );
                              },
                            );

                            if (confirmSave != true) {
                              return; // User clicked "No" or dismissed the dialog
                            }

                            setDialogState(() => isSaving = true);
                            try {
                              final String finalCategory = showCustomCategory
                                  ? customCategoryController.text.trim()
                                  : selectedCategory;
                              final double finalPrice = double.parse(priceController.text.trim());
                              final String trimmedName = nameController.text.trim();

                              // Check for duplicate name in database (skip if editing same item)
                              final existingCheck = await Supabase.instance.client
                                  .from('menu_items')
                                  .select('id, name')
                                  .ilike('name', trimmedName)
                                  .maybeSingle();

                              final isDuplicate = existingCheck != null &&
                                  (!isEdit || existingCheck['id'] != item.id);

                              if (isDuplicate) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('"$trimmedName" already exists in the menu. Please use a different name.'),
                                    backgroundColor: AppTheme.errorRed,
                                  ),
                                );
                                setDialogState(() => isSaving = false);
                                return;
                              }

                              final newItem = MenuItem(
                                id: item?.id,
                                name: trimmedName,
                                price: finalPrice,
                                category: finalCategory,
                                fallbackImagePath: AppConstants.imageUrl(selectedImagePath),
                                customImagePath: selectedImagePath,
                                color: selectedColor,
                                description: descController.text.trim().isNotEmpty
                                    ? descController.text.trim()
                                    : null,
                              );

                              if (isEdit) {
                                await MenuService.updateMenuItem(newItem);
                                AuditLogService.logActivity(
                                  action: 'UPDATE',
                                  module: 'Menu',
                                  description: 'Updated menu item "${newItem.name}" (Price: ₱${newItem.price.toStringAsFixed(2)}, Category: ${newItem.category})',
                                  entityId: newItem.id,
                                  metadata: {
                                    'item_name': newItem.name,
                                    'price': newItem.price,
                                    'category': newItem.category,
                                  },
                                );
                              } else {
                                await MenuService.createMenuItem(newItem);
                                AuditLogService.logActivity(
                                  action: 'CREATE',
                                  module: 'Menu',
                                  description: 'Created new menu item "${newItem.name}" (Price: ₱${newItem.price.toStringAsFixed(2)}, Category: ${newItem.category})',
                                  entityId: newItem.id,
                                  metadata: {
                                    'item_name': newItem.name,
                                    'price': newItem.price,
                                    'category': newItem.category,
                                  },
                                );
                              }

                              // Sync recipe ingredients to database
                              final String menuName = trimmedName;
                              // Delete old ingredients (use old name for edit in case name changed)
                              if (isEdit) {
                                await Supabase.instance.client
                                    .from('recipe_ingredients')
                                    .delete()
                                    .eq('menu_item_name', item.name);
                              }
                              // Insert current ingredients
                              for (final ing in ingredients) {
                                final ingName = (ing['name'] as String).trim();
                                if (ingName.isNotEmpty) {
                                  await Supabase.instance.client
                                      .from('recipe_ingredients')
                                      .insert({
                                    'menu_item_name': menuName,
                                    'name': ingName,
                                    'quantity': ing['quantity'],
                                    'unit': ing['unit'],
                                    'category': ing['category'],
                                  });
                                }
                              }

                              Navigator.pop(context);
                              _loadMenuData();

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isEdit ? 'Menu item updated successfully!' : 'Menu item created successfully!'),
                                  backgroundColor: AppTheme.successGreen,
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Operation failed: $e'),
                                  backgroundColor: AppTheme.errorRed,
                                ),
                              );
                            } finally {
                              // It's possible the dialog was closed, but mounted check isn't strictly needed for setDialogState if we handle carefully, 
                              // though it's safe to just wrap. Let's do it directly.
                              setDialogState(() => isSaving = false);
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // DIALOG FOR DELETING AN ITEM
  void _showDeleteConfirmation(MenuItem item) {
    if (item.id == null) return;
    bool isDeleting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Delete Menu Item', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Text('Are you sure you want to permanently delete "${item.name}"? This action cannot be undone.'),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setDialogState(() => isDeleting = true);
                          try {
                            await MenuService.deleteMenuItem(item);
                            AuditLogService.logActivity(
                              action: 'DELETE',
                              module: 'Menu',
                              description: 'Deleted menu item "${item.name}" (ID: ${item.id})',
                              entityId: item.id,
                              metadata: {
                                'item_name': item.name,
                                'category': item.category,
                                'price': item.price,
                              },
                            );
                            Navigator.pop(context);
                            _loadMenuData();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Menu item deleted successfully!'),
                                backgroundColor: AppTheme.successGreen,
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to delete item: $e'),
                                backgroundColor: AppTheme.errorRed,
                              ),
                            );
                          } finally {
                            setDialogState(() => isDeleting = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorRed,
                    foregroundColor: Colors.white,
                  ),
                  child: isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                        )
                      : const Text('Delete'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _HoverMenuCard extends StatefulWidget {
  final Widget child;
  const _HoverMenuCard({required this.child});

  @override
  State<_HoverMenuCard> createState() => _HoverMenuCardState();
}

class _HoverMenuCardState extends State<_HoverMenuCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0.0, _isHovered ? -4.0 : 0.0, 0.0),
        child: widget.child,
      ),
    );
  }
}

