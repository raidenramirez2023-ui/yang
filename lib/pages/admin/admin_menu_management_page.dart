import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'dart:io' show File;
import '../../models/menu_item.dart';
import '../../services/menu_service.dart';
import '../../services/recipe_seeder.dart';
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
  String _searchQuery = '';
  String _selectedCategoryFilter = 'All';
  bool _isLoading = true;
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

    int crossAxisCount = 1;
    if (isDesktop) {
      crossAxisCount = 4;
    } else if (isTablet) {
      crossAxisCount = 2;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Action Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MENU MANAGEMENT',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.mediumGrey,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pamahalaan ang Item sa Menu ng POS',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkGrey,
                          ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => RecipeSeeder.seedRecipesToDatabase(context),
                      icon: const Icon(Icons.upload_file, color: AppTheme.primaryColor),
                      tooltip: 'Upload Hardcoded Recipes to Database',
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _showAddEditDialog(null),
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Add Menu Item'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Search and Category Filter
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: AppTheme.cardDecoration(),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'Search menu items by name or description...',
                        prefixIcon: const Icon(Icons.search),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: AppTheme.cardDecoration(),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCategoryFilter,
                        isExpanded: true,
                        icon: const Icon(Icons.filter_list),
                        items: ['All', ..._categories].map((String cat) {
                          return DropdownMenuItem<String>(
                            value: cat,
                            child: Text(cat, style: const TextStyle(fontWeight: FontWeight.w500)),
                          );
                        }).toList(),
                        onChanged: (String? newVal) {
                          if (newVal != null) {
                            setState(() => _selectedCategoryFilter = newVal);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Content Area
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                      ),
                    )
                  : filteredItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.restaurant_menu, size: 64, color: AppTheme.mediumGrey),
                              const SizedBox(height: 16),
                              Text(
                                'No menu items found',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      color: AppTheme.mediumGrey,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                    _selectedCategoryFilter = 'All';
                                  });
                                },
                                child: const Text('Reset Filters'),
                              )
                            ],
                          ),
                        )
                      : GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.85,
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

  Widget _buildMenuItemCard(MenuItem item) {
    return Container(
      decoration: AppTheme.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Header
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.network(
                    MenuService.resolveImageUrl(item.customImagePath ?? item.fallbackImagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.restaurant, size: 40, color: AppTheme.mediumGrey),
                      );
                    },
                  ),
                ),
                // Category Tag
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: item.color.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.category,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // Price Tag
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '₱${item.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Info Section
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkGrey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18, color: AppTheme.infoBlue),
                          onPressed: () => _showAddEditDialog(item),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 18, color: AppTheme.errorRed),
                          onPressed: () => _showDeleteConfirmation(item),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.description ?? 'No description provided.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.mediumGrey,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
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
        if (ingResponse != null && (ingResponse as List).isNotEmpty) {
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
      if (invResponse != null && (invResponse as List).isNotEmpty) {
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
            Future<void> handleImageUpload() async {
              try {
                final result = await FilePicker.platform.pickFiles(type: FileType.image);
                if (result != null) {
                  setDialogState(() => isSaving = true);
                  final fileBytes = result.files.single.bytes;
                  final filename = result.files.single.name;
                  
                  if (kIsWeb) {
                    if (fileBytes != null) {
                      await Supabase.instance.client.storage
                          .from('restaurant-assets')
                          .uploadBinary(filename, fileBytes);
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
                          .uploadBinary(filename, bytes);
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

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                isEdit ? 'Edit Menu Item' : 'Add New Menu Item',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: 550,
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
                                value: showCustomCategory ? null : selectedCategory,
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
                            final bool isSelected = selectedColor.value == c.value;
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
                                      ? [BoxShadow(color: c.withOpacity(0.5), blurRadius: 6, spreadRadius: 1)]
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
                                    value: ing['category'] as String,
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
                                  (!isEdit || existingCheck['id'] != item!.id);

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
                              } else {
                                await MenuService.createMenuItem(newItem);
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
