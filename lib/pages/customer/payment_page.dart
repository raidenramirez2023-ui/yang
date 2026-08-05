import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/services/paymongo_service.dart';
import 'package:yang_chow/widgets/payment_method_selector.dart';
import 'package:yang_chow/widgets/customer/customer_ui_components.dart';

class PaymentPage extends StatefulWidget {
  final double amount;
  final String description;
  final Map<String, dynamic>? metadata;
  final Function(bool success, Map<String, dynamic>? result)? onPaymentComplete;

  const PaymentPage({
    super.key,
    required this.amount,
    required this.description,
    this.metadata,
    this.onPaymentComplete,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  Map<String, dynamic>? _selectedPaymentMethod;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.navColor,
        elevation: 0,
        leading: AnimatedTapScale(
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        ),
        title: Text(
          'Checkout Payment',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: _isProcessing
          ? _buildProcessingView()
          : _buildPaymentForm(),
    );
  }

  Widget _buildPaymentForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total Amount Header Card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL PAYABLE',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Colors.white70,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.description,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: AppTheme.goldGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '₱${widget.amount.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Payment Method Selection Header
          Text(
            'Select Payment Method',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkGrey,
            ),
          ),
          const SizedBox(height: 12),

          // Payment Method Selector Component
          PaymentMethodSelector(
            amount: widget.amount,
            selectedMethodId: _selectedPaymentMethod?['id'],
            onMethodSelected: (method) {
              setState(() {
                _selectedPaymentMethod = method;
                _errorMessage = null;
              });
            },
          ),

          const SizedBox(height: 24),

          // Error Message Display
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.errorRed.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppTheme.errorRed, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.inter(
                        color: AppTheme.errorRed,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Pay Primary CTA Button
          AnimatedTapScale(
            onTap: _selectedPaymentMethod != null ? _processPayment : null,
            child: Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                gradient: _selectedPaymentMethod != null ? AppTheme.primaryGradient : null,
                color: _selectedPaymentMethod == null ? Colors.grey.shade300 : null,
                borderRadius: BorderRadius.circular(16),
                boxShadow: _selectedPaymentMethod != null
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: _isProcessing
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Pay ₱${widget.amount.toStringAsFixed(2)} Now',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Cancel Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel Order',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.mediumGrey,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Processing Payment...',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGrey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please wait while we redirect you to secure checkout.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.mediumGrey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processPayment() async {
    if (_selectedPaymentMethod == null) return;
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final methodType = _selectedPaymentMethod!['type'] as String;

    if (methodType == 'gcash' || methodType == 'paymaya') {
      await _processEWalletPayment(methodType);
    } else {
      await _processPaymentLink();
    }
  }

  Future<void> _processEWalletPayment(String type) async {
    try {
      final response = await PayMongoService.createPaymentLink(
        amount: widget.amount,
        description: widget.description,
        metadata: {
          ...?widget.metadata,
          'reservation_id': widget.metadata?['reservationId'] ?? 'unknown',
          'payment_type': type,
        },
      );

      if (response['success'] == true && response['checkoutUrl'] != null) {
        final uri = Uri.parse(response['checkoutUrl']);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          
          if (mounted) {
            setState(() {
              _isProcessing = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Redirecting to secure payment...', style: GoogleFonts.inter()),
                backgroundColor: AppTheme.successGreen,
              ),
            );
          }
        } else {
          throw 'Could not launch payment URL';
        }
      } else {
        throw response['error'] ?? 'Failed to create payment link';
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Payment failed: ${e.toString()}';
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _processPaymentLink() async {
    try {
      final response = await PayMongoService.createPaymentLink(
        amount: widget.amount,
        description: widget.description,
        metadata: {
          ...?widget.metadata,
          'reservation_id': widget.metadata?['reservationId'] ?? 'unknown',
        },
      );

      if (response['success'] == true && response['checkoutUrl'] != null) {
        final uri = Uri.parse(response['checkoutUrl']);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          
          if (mounted) {
            setState(() {
              _isProcessing = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Redirecting to PayMongo...', style: GoogleFonts.inter()),
                backgroundColor: AppTheme.successGreen,
              ),
            );
          }
        } else {
          throw 'Could not launch payment URL';
        }
      } else {
        throw response['error'] ?? 'Failed to create payment link';
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Payment processing failed: ${e.toString()}';
          _isProcessing = false;
        });
      }
    }
  }
}

class PaymentWebView extends StatefulWidget {
  final String checkoutUrl;
  final VoidCallback onSuccess;
  final VoidCallback onCancel;
  final Function(String error) onError;

  const PaymentWebView({
    super.key,
    required this.checkoutUrl,
    required this.onSuccess,
    required this.onCancel,
    required this.onError,
  });

  @override
  State<PaymentWebView> createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _launchPaymentUrl();
  }

  Future<void> _launchPaymentUrl() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final uri = Uri.parse(widget.checkoutUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        widget.onError('Could not launch payment URL');
      }
    } catch (e) {
      widget.onError('Error launching payment: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Payment', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppTheme.navColor,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading) ...[
                const CircularProgressIndicator(color: AppTheme.primaryColor),
                const SizedBox(height: 24),
                Text('Opening payment page...', style: GoogleFonts.inter(fontSize: 16, color: AppTheme.darkGrey)),
              ] else ...[
                const Icon(Icons.launch_rounded, size: 56, color: AppTheme.primaryColor),
                const SizedBox(height: 20),
                Text('Payment page opened in browser', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkGrey)),
                const SizedBox(height: 8),
                Text('Complete your payment in the browser window.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: AppTheme.mediumGrey)),
                const SizedBox(height: 24),
                AnimatedTapScale(
                  onTap: _launchPaymentUrl,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text('Reopen Payment Page', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
