import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PaymentLogoPlaceholder extends StatelessWidget {
  final String paymentType;
  final double size;
  final Color? color;

  const PaymentLogoPlaceholder({
    super.key,
    required this.paymentType,
    this.size = 32.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color iconColor = color ?? Colors.grey.shade600;

    switch (paymentType) {
      case 'gcash':
        icon = Icons.account_balance_wallet;
        iconColor = Colors.blue.shade600;
        break;
      case 'paymaya':
        icon = Icons.account_balance_wallet;
        iconColor = Colors.deepOrange.shade600;
        break;
      case 'card':
        icon = Icons.credit_card;
        iconColor = Colors.grey.shade700;
        break;
      case 'bank_transfer':
        icon = Icons.account_balance;
        iconColor = Colors.green.shade600;
        break;
      default:
        icon = Icons.payment;
        iconColor = Colors.grey.shade600;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        color: iconColor,
        size: size * 0.7,
      ),
    );
  }
}
