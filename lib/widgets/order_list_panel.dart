import 'package:flutter/material.dart';
import 'shared_pos_widget.dart';

class OrderListPanel extends StatefulWidget {
  final List<CartItem> cart;
  final Function(CartItem) onQuantityIncreased;
  final Function(CartItem) onQuantityDecreased;
  final Function(CartItem) onRemoveItem;
  final Function() onPrintReceipt;
  final bool isMobile;

  const OrderListPanel({
    Key? key,
    required this.cart,
    required this.onQuantityIncreased,
    required this.onQuantityDecreased,
    required this.onRemoveItem,
    required this.onPrintReceipt,
    this.isMobile = false,
  }) : super(key: key);

  @override
  State<OrderListPanel> createState() => _OrderListPanelState();
}

class _OrderListPanelState extends State<OrderListPanel> {
  final TextEditingController _customerNameController = TextEditingController();

  double get totalAmount {
    return widget.cart.fold(0.0, (sum, item) => sum + (item.item.price * item.quantity));
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
            color: Colors.red,
            padding: EdgeInsets.symmetric(
              vertical: widget.isMobile ? 8.0 : 16.0,
              horizontal: 16.0,
            ),
            child: Center(
              child: Text(
                'ORDER LIST',
                style: TextStyle(
                  color: Colors.white,
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
                      final item = widget.cart[index];
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
                              Text(
                                item.item.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: widget.isMobile ? 12 : 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: widget.isMobile ? 4 : 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '₱${item.item.price.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: widget.isMobile ? 10 : 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      // Decrease button
                                      GestureDetector(
                                        onTap: () => widget.onQuantityDecreased(item),
                                        child: Container(
                                          width: widget.isMobile ? 20 : 24,
                                          height: widget.isMobile ? 20 : 24,
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Icon(
                                              Icons.remove,
                                              color: Colors.white,
                                              size: widget.isMobile ? 14 : 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                      
                                      // Quantity
                                      Container(
                                        width: widget.isMobile ? 25 : 30,
                                        alignment: Alignment.center,
                                        child: Text(
                                          '${item.quantity}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: widget.isMobile ? 14 : 16,
                                          ),
                                        ),
                                      ),
                                      
                                      // Increase button
                                      GestureDetector(
                                        onTap: () => widget.onQuantityIncreased(item),
                                        child: Container(
                                          width: widget.isMobile ? 20 : 24,
                                          height: widget.isMobile ? 20 : 24,
                                          decoration: const BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Icon(
                                              Icons.add,
                                              color: Colors.white,
                                              size: widget.isMobile ? 14 : 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                      
                                      SizedBox(width: widget.isMobile ? 4 : 8),
                                      
                                      // Edit button
                                      GestureDetector(
                                        onTap: () {
                                          // TODO: Implement edit functionality
                                        },
                                        child: Icon(
                                          Icons.edit,
                                          color: Colors.blue,
                                          size: widget.isMobile ? 16 : 20,
                                        ),
                                      ),
                                      
                                      SizedBox(width: widget.isMobile ? 4 : 8),
                                      
                                      // Delete button
                                      GestureDetector(
                                        onTap: () => widget.onRemoveItem(item),
                                        child: Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                          size: widget.isMobile ? 16 : 20,
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
          
          // Customer Name and Total (only show if not mobile)
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
                  
                  // Total
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
                        '₱${totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Print Receipt Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: widget.cart.isNotEmpty ? widget.onPrintReceipt : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'PRINT RECEIPT',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
