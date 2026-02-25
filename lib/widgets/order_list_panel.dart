import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'shared_pos_widget.dart';

class OrderListPanel extends StatefulWidget {
  final List<CartItem> cart;
  final Function(CartItem) onQuantityIncreased;
  final Function(CartItem) onQuantityDecreased;
  final Function(CartItem) onRemoveItem;
  final Function(String customerName) onPrintReceipt;
  final bool isMobile;

  const OrderListPanel({
    super.key,
    required this.cart,
    required this.onQuantityIncreased,
    required this.onQuantityDecreased,
    required this.onRemoveItem,
    required this.onPrintReceipt,
    this.isMobile = false,
  });

  @override
  State<OrderListPanel> createState() => _OrderListPanelState();
}

class _OrderListPanelState extends State<OrderListPanel> {
  final TextEditingController _customerNameController = TextEditingController();
  
  // Direct initialization of currency formatter
  final NumberFormat currencyFormatter = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    super.dispose();
  }

  double get totalAmount {
    return widget.cart.fold(
        0.0, (sum, item) => sum + (item.item.price * item.quantity));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.isMobile ? double.infinity : 350,
      color: Colors.grey[50],
      child: Column(
        children: [
          // ORDER LIST Header
          Container(
            color: Colors.grey[50],
            padding: EdgeInsets.symmetric(
              vertical: widget.isMobile ? 8.0 : 16.0,
              horizontal: 16.0,
            ),
            child: Center(
              child: Text(
                'ORDER LIST',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: widget.isMobile ? 14 : 18,
                ),
              ),
            ),
          ),

          // Order Items
          Expanded(
            child: widget.cart.isEmpty
                ? Center(
                    child: Text(
                      'No items in order',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: widget.isMobile ? 12 : 14,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(widget.isMobile ? 4 : 8),
                    itemCount: widget.cart.length,
                    itemBuilder: (context, index) {
                      final reversedCart = widget.cart.reversed.toList();
                      final item = reversedCart[index];
                      return Card(
                        margin: EdgeInsets.only(
                          bottom: widget.isMobile ? 2 : 8,
                          left: widget.isMobile ? 2 : 0,
                          right: widget.isMobile ? 2 : 0,
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(widget.isMobile ? 6 : 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Row for Product Name and Price
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Product Name (Left side)
                                  Expanded(
                                    child: Text(
                                      item.item.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: widget.isMobile ? 12 : 16,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  
                                  // Price with NumberFormat (Right side)
                                  Text(
                                    currencyFormatter.format(item.item.price),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: widget.isMobile ? 12 : 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              
                              SizedBox(height: widget.isMobile ? 8 : 12),
                              
                              // Row for Quantity Controls
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Total Price with NumberFormat (Left side)
                                  Text(
                                    'Total: ${currencyFormatter.format(item.item.price * item.quantity)}',
                                    style: TextStyle(
                                      fontSize: widget.isMobile ? 11 : 14,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  
                                  // Quantity Controls (Right side)
                                  Row(
                                    children: [
                                      // Decrease button
                                      GestureDetector(
                                        onTap: () => widget.onQuantityDecreased(item),
                                        child: Container(
                                          width: widget.isMobile ? 24 : 28,
                                          height: widget.isMobile ? 24 : 28,
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Icon(
                                              Icons.remove,
                                              color: Colors.white,
                                              size: widget.isMobile ? 16 : 18,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Quantity
                                      SizedBox(
                                        width: widget.isMobile ? 30 : 35,
                                        child: Center(
                                          child: Text(
                                            '${item.quantity}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: widget.isMobile ? 14 : 16,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Increase button
                                      GestureDetector(
                                        onTap: () => widget.onQuantityIncreased(item),
                                        child: Container(
                                          width: widget.isMobile ? 24 : 28,
                                          height: widget.isMobile ? 24 : 28,
                                          decoration: const BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Icon(
                                              Icons.add,
                                              color: Colors.white,
                                              size: widget.isMobile ? 16 : 18,
                                            ),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(width: 8),

                                      // Delete button
                                      GestureDetector(
                                        onTap: () => widget.onRemoveItem(item),
                                        child: Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                          size: widget.isMobile ? 18 : 22,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Customer Name and Total (desktop only)
          if (!widget.isMobile)
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Customer Name
                  TextField(
                    controller: _customerNameController,
                    decoration: const InputDecoration(
                      labelText: 'Customer Name',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Total with NumberFormat
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TOTAL:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        currencyFormatter.format(totalAmount),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Buttons Row
                  Row(
                    children: [
                      // Cancel Order Button
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: widget.cart.isNotEmpty
                                ? () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Cancel Order'),
                                        content: const Text('Are you sure you want to cancel this order? All items will be removed.'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('No'),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () {
                                              Navigator.pop(context);
                                              for (var item in widget.cart.toList()) {
                                                widget.onRemoveItem(item);
                                              }
                                            },
                                            child: const Text('Yes'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                : null,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'CANCEL ORDER',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // Print Receipt Button - UPDATED
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: widget.cart.isNotEmpty
                                ? () {
                                    // Print the receipt with the customer name
                                    widget.onPrintReceipt(
                                      _customerNameController.text.trim(),
                                    );
                                    
                                    // Clear the cart
                                    for (var item in widget.cart.toList()) {
                                      widget.onRemoveItem(item);
                                    }
                                    
                                    // Show success message
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            const Icon(Icons.check_circle, color: Colors.white),
                                            const SizedBox(width: 8),
                                            const Text('Order completed and cart cleared'),
                                          ],
                                        ),
                                        backgroundColor: Colors.green,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'PRINT RECEIPT',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}