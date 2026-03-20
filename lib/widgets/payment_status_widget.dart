import 'package:flutter/material.dart';

class PaymentStatusWidget extends StatelessWidget {
  final String paymentStatus;
  final String? paymentMethod;
  final double? amount;
  final String? transactionId;
  final DateTime? paymentDate;

  const PaymentStatusWidget({
    super.key,
    required this.paymentStatus,
    this.paymentMethod,
    this.amount,
    this.transactionId,
    this.paymentDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getBorderColor(),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getIconColor().withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getStatusIcon(),
                  color: _getIconColor(),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Status',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _getFormattedStatus(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _getTextColor(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Payment Details
          if (amount != null || paymentMethod != null) ...[
            const SizedBox(height: 16),
            Container(
              height: 1,
              color: Colors.grey.shade200,
            ),
            const SizedBox(height: 16),
            
            if (amount != null) ...[
              _buildDetailRow(
                'Amount',
                '₱${amount!.toStringAsFixed(2)}',
                Icons.attach_money,
              ),
              const SizedBox(height: 8),
            ],
            
            if (paymentMethod != null) ...[
              _buildDetailRow(
                'Payment Method',
                _getFormattedPaymentMethod(),
                Icons.payment,
              ),
              const SizedBox(height: 8),
            ],
            
            if (transactionId != null) ...[
              _buildDetailRow(
                'Transaction ID',
                transactionId!,
                Icons.receipt_long,
              ),
              const SizedBox(height: 8),
            ],
            
            if (paymentDate != null) ...[
              _buildDetailRow(
                'Payment Date',
                _formatDate(paymentDate!),
                Icons.calendar_today,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E1E1E),
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Color _getBackgroundColor() {
    switch (paymentStatus.toLowerCase()) {
      case 'paid':
      case 'completed':
      case 'success':
        return Colors.green.shade50;
      case 'pending':
      case 'processing':
        return Colors.orange.shade50;
      case 'failed':
      case 'cancelled':
      case 'refunded':
        return Colors.red.shade50;
      default:
        return Colors.grey.shade50;
    }
  }

  Color _getBorderColor() {
    switch (paymentStatus.toLowerCase()) {
      case 'paid':
      case 'completed':
      case 'success':
        return Colors.green.shade200;
      case 'pending':
      case 'processing':
        return Colors.orange.shade200;
      case 'failed':
      case 'cancelled':
      case 'refunded':
        return Colors.red.shade200;
      default:
        return Colors.grey.shade200;
    }
  }

  Color _getIconColor() {
    switch (paymentStatus.toLowerCase()) {
      case 'paid':
      case 'completed':
      case 'success':
        return Colors.green;
      case 'pending':
      case 'processing':
        return Colors.orange;
      case 'failed':
      case 'cancelled':
      case 'refunded':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getTextColor() {
    switch (paymentStatus.toLowerCase()) {
      case 'paid':
      case 'completed':
      case 'success':
        return Colors.green;
      case 'pending':
      case 'processing':
        return Colors.orange;
      case 'failed':
      case 'cancelled':
      case 'refunded':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (paymentStatus.toLowerCase()) {
      case 'paid':
      case 'completed':
      case 'success':
        return Icons.check_circle;
      case 'pending':
      case 'processing':
        return Icons.pending;
      case 'failed':
      case 'cancelled':
        return Icons.cancel;
      case 'refunded':
        return Icons.refresh;
      default:
        return Icons.help;
    }
  }

  String _getFormattedStatus() {
    switch (paymentStatus.toLowerCase()) {
      case 'paid':
      case 'completed':
      case 'success':
        return 'Payment Successful';
      case 'pending':
        return 'Payment Pending';
      case 'processing':
        return 'Processing Payment';
      case 'failed':
        return 'Payment Failed';
      case 'cancelled':
        return 'Payment Cancelled';
      case 'refunded':
        return 'Payment Refunded';
      default:
        return 'Unknown Status';
    }
  }

  String _getFormattedPaymentMethod() {
    if (paymentMethod == null) return 'Unknown';
    
    switch (paymentMethod!.toLowerCase()) {
      case 'gcash':
        return 'GCash';
      case 'paymaya':
        return 'Maya';
      case 'card':
        return 'Credit/Debit Card';
      case 'bank_transfer':
        return 'Bank Transfer';
      default:
        return paymentMethod!;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
