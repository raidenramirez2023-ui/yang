import 'package:flutter/material.dart';
import 'package:yang_chow/services/paymongo_service.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/widgets/payment_logo_placeholder.dart';

class PaymentMethodSelector extends StatefulWidget {
  final double amount;
  final Function(Map<String, dynamic>) onMethodSelected;
  final String? selectedMethodId;

  const PaymentMethodSelector({
    super.key,
    required this.amount,
    required this.onMethodSelected,
    this.selectedMethodId,
  });

  @override
  State<PaymentMethodSelector> createState() => _PaymentMethodSelectorState();
}

class _PaymentMethodSelectorState extends State<PaymentMethodSelector> {
  String? _selectedMethodId;

  @override
  void initState() {
    super.initState();
    _selectedMethodId = widget.selectedMethodId;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Payment Method',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E1E1E),
          ),
        ),
        const SizedBox(height: 16),
        
        // Amount Display
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Amount:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E1E1E),
                ),
              ),
              Text(
                PayMongoService.formatAmount(widget.amount),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Payment Methods
        FutureBuilder<Map<String, dynamic>>(
          future: PayMongoService.getAvailablePaymentMethods(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              // Fallback to default methods if API fails or returns error
              final defaultMethods = [
                {'id': 'gcash', 'type': 'gcash', 'name': 'GCash', 'description': 'Pay via GCash e-wallet'},
                {'id': 'paymaya', 'type': 'paymaya', 'name': 'Maya', 'description': 'Pay via Maya e-wallet'},
                {'id': 'card', 'type': 'card', 'name': 'Credit/Debit Card', 'description': 'Visa, Mastercard'},
              ];
              return Column(
                children: defaultMethods.map((method) => _buildPaymentMethodCard(method)).toList(),
              );
            }

            final data = snapshot.data!['data'] as List? ?? [];
            final methods = data.map((m) {
              final attributes = m['attributes'];
              return {
                'id': m['id'],
                'type': attributes['type'],
                'name': attributes['name'] ?? attributes['type'].toString().toUpperCase(),
                'description': attributes['description'] ?? 'Pay using ${attributes['type']}',
              };
            }).toList();

            if (methods.isEmpty) {
              return const Center(child: Text('No payment methods available'));
            }

            return Column(
              children: methods.map((method) => _buildPaymentMethodCard(method)).toList(),
            );
          },
        ),
        
        const SizedBox(height: 16),
        
        // Security Note
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(
                Icons.security,
                color: Colors.grey.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your payment information is secure and encrypted',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodCard(Map<String, dynamic> method) {
    final isSelected = _selectedMethodId == method['id'];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.1) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedMethodId = method['id'];
            });
            widget.onMethodSelected(method);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Payment Method Icon
                SizedBox(
                  width: 48,
                  height: 48,
                  child: PaymentLogoPlaceholder(
                    paymentType: method['type'],
                    size: 48,
                    color: isSelected ? Colors.white : null,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Payment Method Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        method['name'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? AppTheme.primaryColor : const Color(0xFF1E1E1E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        method['description'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Selection Indicator
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryColor : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
