import 'package:flutter/material.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final List<Map<String, dynamic>> _inventoryItems = [
    {
      'name': 'Chicken Breast',
      'category': 'Meat',
      'quantity': 25,
      'unit': 'kg',
    },
    {
      'name': 'Pork Belly',
      'category': 'Meat',
      'quantity': 12,
      'unit': 'kg',
    },
    {
      'name': 'Cabbage',
      'category': 'Vegetables',
      'quantity': 8,
      'unit': 'kg',
    },
    {
      'name': 'Soy Sauce',
      'category': 'Condiments',
      'quantity': 5,
      'unit': 'bottles',
    },
    {
      'name': 'Cooking Oil',
      'category': 'Condiments',
      'quantity': 2,
      'unit': 'gallons',
    },
    {
      'name': 'Soft Drinks',
      'category': 'Beverages',
      'quantity': 30,
      'unit': 'pcs',
    },
  ];

  void _addOrEditItem({Map<String, dynamic>? item, int? index}) {
    final nameController = TextEditingController(text: item?['name']);
    final categoryController = TextEditingController(text: item?['category']);
    final quantityController =
        TextEditingController(text: item?['quantity']?.toString());
    final unitController = TextEditingController(text: item?['unit']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item == null ? 'Add Inventory Item' : 'Edit Inventory Item'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Item Name'),
              ),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
              ),
              TextField(
                controller: unitController,
                decoration: const InputDecoration(labelText: 'Unit (kg, pcs, etc.)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              final newItem = {
                'name': nameController.text,
                'category': categoryController.text,
                'quantity': int.tryParse(quantityController.text) ?? 0,
                'unit': unitController.text,
              };

              setState(() {
                if (item == null) {
                  _inventoryItems.add(newItem);
                } else {
                  _inventoryItems[index!] = newItem;
                }
              });

              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteItem(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() {
                _inventoryItems.removeAt(index);
              });
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Color _stockColor(int qty) {
    if (qty == 0) return Colors.red;
    if (qty <= 5) return Colors.orange;
    return Colors.green;
  }

  String _stockLabel(int qty) {
    if (qty == 0) return 'Out of Stock';
    if (qty <= 5) return 'Low Stock';
    return 'In Stock';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red,
        onPressed: () => _addOrEditItem(),
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Inventory Management',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _inventoryItems.length,
                itemBuilder: (context, index) {
                  final item = _inventoryItems[index];
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _stockColor(item['quantity']),
                        child: const Icon(Icons.inventory, color: Colors.white),
                      ),
                      title: Text(item['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        '${item['category']} • ${item['quantity']} ${item['unit']} • ${_stockLabel(item['quantity'])}',
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () =>
                                _addOrEditItem(item: item, index: index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteItem(index),
                          ),
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
  }
}
