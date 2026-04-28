import 'package:flutter/material.dart';


import 'package:url_launcher/url_launcher.dart';


import 'package:yang_chow/utils/app_theme.dart';

import 'package:yang_chow/widgets/payment_method_selector.dart';



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

      backgroundColor: Colors.white,

      appBar: AppBar(
        title: const Text('Payment'),
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

          // Payment Method Selection

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

          

          const SizedBox(height: 32),

          

          // Error Message

          if (_errorMessage != null) ...[

            Container(

              padding: const EdgeInsets.all(16),

              decoration: BoxDecoration(

                color: Colors.red.shade50,

                borderRadius: BorderRadius.circular(8),

                border: Border.all(color: Colors.red.shade200),

              ),

              child: Row(

                children: [

                  Icon(

                    Icons.error_outline,

                    color: Colors.red.shade600,

                    size: 20,

                  ),

                  const SizedBox(width: 8),

                  Expanded(

                    child: Text(

                      _errorMessage!,

                      style: TextStyle(

                        color: Colors.red.shade600,

                        fontSize: 14,

                      ),

                    ),

                  ),

                ],

              ),

            ),

            const SizedBox(height: 16),

          ],

          

          // Pay Button

          SizedBox(

            width: double.infinity,

            height: 48,

            child: ElevatedButton(

              onPressed: _selectedPaymentMethod != null ? _processPayment : null,

              style: ElevatedButton.styleFrom(

                backgroundColor: AppTheme.primaryColor,

                foregroundColor: Colors.white,

                disabledBackgroundColor: Colors.grey.shade300,

                shape: RoundedRectangleBorder(

                  borderRadius: BorderRadius.circular(8),

                ),

                elevation: 0,

              ),

              child: _isProcessing

                  ? const SizedBox(

                      height: 20,

                      width: 20,

                      child: CircularProgressIndicator(

                        strokeWidth: 2,

                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),

                      ),

                    )

                  : Text(

                      'Pay PHP ${widget.amount.toStringAsFixed(2)}',

                      style: const TextStyle(

                        fontSize: 16,

                        fontWeight: FontWeight.w600,

                      ),

                    ),

            ),

          ),

          

          const SizedBox(height: 16),

          

          // Cancel Button

          SizedBox(

            width: double.infinity,

            height: 48,

            child: OutlinedButton(

              onPressed: () => Navigator.of(context).pop(),

              style: OutlinedButton.styleFrom(

                foregroundColor: Colors.grey.shade600,

                side: BorderSide(color: Colors.grey.shade300),

                shape: RoundedRectangleBorder(

                  borderRadius: BorderRadius.circular(8),

                ),

              ),

              child: const Text(

                'Cancel',

                style: TextStyle(

                  fontSize: 16,

                  fontWeight: FontWeight.w600,

                ),

              ),

            ),

          ),

        ],

      ),

    );

  }



  Widget _buildProcessingView() {

    return Column(

      mainAxisAlignment: MainAxisAlignment.center,

      children: [

        Container(

          width: 80,

          height: 80,

          decoration: BoxDecoration(

            color: AppTheme.primaryColor.withOpacity(0.1),

            shape: BoxShape.circle,

          ),

          child: const Center(

            child: CircularProgressIndicator(

              strokeWidth: 3,

              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),

            ),

          ),

        ),

        const SizedBox(height: 24),

        const Text(

          'Processing Payment',

          style: TextStyle(

            fontSize: 20,

            fontWeight: FontWeight.bold,

            color: AppTheme.darkGrey,

          ),

        ),

        const SizedBox(height: 8),

        Text(

          'Please wait while we process your payment...',

          style: TextStyle(

            fontSize: 14,

            color: Colors.grey.shade600,

          ),

          textAlign: TextAlign.center,

        ),

      ],

    );

  }



  Future<void> _processPayment() async {
    if (_selectedPaymentMethod == null) return;
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final methodType = _selectedPaymentMethod!['type'] as String;

    // GCash and Maya use the direct Payment Intent flow
    if (methodType == 'gcash' || methodType == 'paymaya') {
      await _processEWalletPayment(methodType);
    } else {
      // QRPH, Card, and Bank Transfer use Payment Link flow
      await _processPaymentLink();
    }
  }

  // ── E-Wallet (GCash) ─────────────────────────────────────────────────
  Future<void> _processEWalletPayment(String type) async {
    try {
      setState(() {
        _isProcessing = false;
      });
      
      _showQRPaymentDialog();
    } catch (e) {
      setState(() {
        _errorMessage = 'Payment failed: ${e.toString()}';
        _isProcessing = false;
      });
    }
  }

  // ── Payment Link (QRPH, Card, Bank Transfer) ────────────────────────────────
  Future<void> _processPaymentLink() async {
    try {
      setState(() {
        _isProcessing = false;
      });
      
      _showQRPaymentDialog();
    } catch (e) {
      setState(() {
        _errorMessage = 'Payment processing failed: ${e.toString()}';
        _isProcessing = false;
      });
    }
  }



  


  


  
  void _showQRPaymentDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          child: Stack(
            children: [
              // Full screen QR code
              Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  height: MediaQuery.of(context).size.width * 0.85,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // QR Code takes most of the space
                      Expanded(
                        flex: 3,
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Image.asset(
                            'assets/images/newgcash.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      // Amount and info at bottom
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          child: Column(
                            children: [
                              Text(
                                'Amount: PHP ${widget.amount.toStringAsFixed(2)}',
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Reference: YANG${DateTime.now().millisecondsSinceEpoch}',
                                style: TextStyle(fontSize: 14, color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Close button
              Positioned(
                top: 50,
                right: 20,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: Colors.white, size: 30),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withOpacity(0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

      appBar: AppBar(

        title: const Text('Payment'),

        backgroundColor: AppTheme.primaryColor,

        foregroundColor: Colors.white,

      ),

      body: Center(

        child: Padding(

          padding: const EdgeInsets.all(32.0),

          child: Column(

            mainAxisAlignment: MainAxisAlignment.center,

            children: [

              if (_isLoading) ...[

                const CircularProgressIndicator(

                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),

                ),

                const SizedBox(height: 24),

                const Text(

                  'Opening payment page...',

                  style: TextStyle(

                    color: Colors.white,

                    fontSize: 18,

                    fontWeight: FontWeight.w500,

                  ),

                ),

              ] else ...[

                const Icon(

                  Icons.launch_rounded,

                  size: 64,

                  color: Colors.white,

                ),

                const SizedBox(height: 24),

                const Text(

                  'Payment page opened in your browser',

                  textAlign: TextAlign.center,

                  style: TextStyle(

                    color: Colors.white,

                    fontSize: 18,

                    fontWeight: FontWeight.w500,

                  ),

                ),

                const SizedBox(height: 16),

                const Text(

                  'Complete your payment in the browser window',

                  textAlign: TextAlign.center,

                  style: TextStyle(

                    color: Colors.white70,

                    fontSize: 14,

                  ),

                ),

                const SizedBox(height: 32),

                ElevatedButton(

                  onPressed: _launchPaymentUrl,

                  style: ElevatedButton.styleFrom(

                    backgroundColor: Colors.white,

                    foregroundColor: AppTheme.primaryColor,

                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),

                  ),

                  child: const Text('Reopen Payment Page'),

                ),

              ],

            ],

          ),

        ),

      ),

      backgroundColor: AppTheme.primaryColor,

    );

  }

}

