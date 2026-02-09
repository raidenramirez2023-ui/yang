import 'package:flutter/material.dart';

class InventoryItem {
  final String name;
  final int stock;
  final String category;
  final double price;
  final String unit;
  final IconData icon;

  InventoryItem({
    required this.name,
    required this.stock,
    required this.category,
    required this.price,
    required this.unit,
    required this.icon,
  });
}

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final TextEditingController searchController = TextEditingController();
  String selectedCategory = 'All';
  String sortBy = 'Name';
  
  final List<InventoryItem> inventoryItems = [
    InventoryItem(
      name: "Sweet & Sour Pork",
      stock: 50,
      category: "Main Dish",
      price: 180.00,
      unit: "servings",
      icon: Icons.set_meal,
    ),
    InventoryItem(
      name: "Yang Chow Fried Rice",
      stock: 30,
      category: "Main Dish", 
      price: 120.00,
      unit: "servings",
      icon: Icons.rice_bowl,
    ),
    InventoryItem(
      name: "Chopsuey",
      stock: 25,
      category: "Main Dish",
      price: 150.00,
      unit: "servings", 
      icon: Icons.lunch_dining,
    ),
    InventoryItem(
      name: "Siomai",
      stock: 100,
      category: "Appetizers",
      price: 60.00,
      unit: "pieces",
      icon: Icons.fastfood,
    ),
    InventoryItem(
      name: "Lumpia",
      stock: 80,
      category: "Appetizers",
      price: 50.00,
      unit: "pieces",
      icon: Icons.restaurant,
    ),
    InventoryItem(
      name: "Softdrinks",
      stock: 200,
      category: "Drinks",
      price: 40.00,
      unit: "bottles",
      icon: Icons.local_drink,
    ),
    InventoryItem(
      name: "Iced Tea",
      stock: 150,
      category: "Drinks",
      price: 45.00,
      unit: "glasses",
      icon: Icons.local_cafe,
    ),
    InventoryItem(
      name: "Halo-Halo",
      stock: 40,
      category: "Desserts",
      price: 85.00,
      unit: "servings",
      icon: Icons.icecream,
    ),
  ];

  List<String> get categories {
    return ['All', ...inventoryItems.map((item) => item.category).toSet().toList()];
  }

  List<InventoryItem> get filteredItems {
    var items = inventoryItems.where((item) {
      final matchesSearch = item.name.toLowerCase().contains(searchController.text.toLowerCase());
      final matchesCategory = selectedCategory == 'All' || item.category == selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    // Sort items
    switch (sortBy) {
      case 'Name':
        items.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'Stock (Low to High)':
        items.sort((a, b) => a.stock.compareTo(b.stock));
        break;
      case 'Stock (High to Low)':
        items.sort((a, b) => b.stock.compareTo(a.stock));
        break;
      case 'Price (Low to High)':
        items.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'Price (High to Low)':
        items.sort((a, b) => b.price.compareTo(a.price));
        break;
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1200;
    final isTablet = size.width > 800 && size.width <= 1200;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.red.shade600,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.inventory_2, color: Colors.white),
            const SizedBox(width: 12),
            const Text(
              'Inventory Management',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          if (isDesktop || isTablet)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${filteredItems.length} items',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            color: Colors.white,
            padding: EdgeInsets.all(isDesktop ? 24 : 16),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: searchController,
                  onChanged: (value) => setState(() {}),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    hintText: 'Search inventory items...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Filters Row
                Row(
                  children: [
                    // Category Filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedCategory,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        items: categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedCategory = value!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Sort Dropdown
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: sortBy,
                        decoration: InputDecoration(
                          labelText: 'Sort by',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        items: [
                          'Name',
                          'Stock (Low to High)',
                          'Stock (High to Low)',
                          'Price (Low to High)',
                          'Price (High to Low)',
                        ].map((sort) {
                          return DropdownMenuItem(
                            value: sort,
                            child: Text(sort),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            sortBy = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Inventory Grid
          Expanded(
            child: filteredItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No items found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your search or filters',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: EdgeInsets.all(isDesktop ? 24 : 16),
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isDesktop ? 4 : isTablet ? 3 : 2,
                        childAspectRatio: isDesktop ? 0.8 : isTablet ? 0.75 : 0.7,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        return _buildInventoryCard(filteredItems[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red.shade600,
        onPressed: () {
          _showAddItemDialog();
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildInventoryCard(InventoryItem item) {
    final isLowStock = item.stock < 30;
    final isOutOfStock = item.stock == 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showEditItemDialog(item),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon and Category
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(item.category).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      item.icon,
                      color: _getCategoryColor(item.category),
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOutOfStock 
                          ? Colors.red.shade100 
                          : isLowStock 
                              ? Colors.orange.shade100 
                              : Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isOutOfStock 
                          ? 'Out of Stock'
                          : isLowStock 
                              ? 'Low Stock'
                              : 'In Stock',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isOutOfStock 
                            ? Colors.red.shade700
                            : isLowStock 
                                ? Colors.orange.shade700
                                : Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Item Name
              Text(
                item.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              
              // Category
              Text(
                item.category,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const Spacer(),
              
              // Stock
              Row(
                children: [
                  Icon(
                    Icons.inventory,
                    size: 16,
                    color: isOutOfStock || isLowStock ? Colors.red.shade600 : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${item.stock} ${item.unit}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isOutOfStock || isLowStock ? Colors.red.shade600 : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Price
              Text(
                '₱${item.price.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Main Dish':
        return Colors.red;
      case 'Appetizers':
        return Colors.orange;
      case 'Drinks':
        return Colors.blue;
      case 'Desserts':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  void _showAddItemDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Item'),
        content: const Text('Add new inventory item functionality coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showEditItemDialog(InventoryItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Category: ${item.category}'),
            const SizedBox(height: 8),
            Text('Current Stock: ${item.stock} ${item.unit}'),
            const SizedBox(height: 8),
            Text('Price: ₱${item.price.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            const Text('Edit functionality coming soon!'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Edit ${item.name} functionality coming soon!'),
                  backgroundColor: Colors.orange.shade700,
                ),
              );
            },
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}
