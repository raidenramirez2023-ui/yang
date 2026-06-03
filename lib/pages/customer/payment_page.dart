import 'package:flutter/material.dart';


import 'package:url_launcher/url_launcher.dart';


import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/services/paymongo_service.dart';
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
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.darkGrey, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Payment',
          style: TextStyle(
            color: AppTheme.darkGrey,
            fontWeight: FontWeight.w700,
            fontSize: 20,
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

      padding: const EdgeInsets.all(28),

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
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.shade200, width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: Colors.red.shade600,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Colors.red.shade600,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
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
            height: 56,
            child: ElevatedButton(
              onPressed: _selectedPaymentMethod != null ? _processPayment : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 6,
                shadowColor: AppTheme.primaryColor.withOpacity(0.4),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Pay PHP ${widget.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
            ),
          ),

          

          const SizedBox(height: 16),

          

          // Cancel Button

          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.mediumGrey,
                side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 17,
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
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.12),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.2),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 3.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Processing Payment',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.darkGrey,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Please wait while we process your payment...',
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
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
            // Let the user know they were redirected
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Redirecting to secure payment...')),
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

  // ── Payment Link (QRPH, Card, Bank Transfer) ────────────────────────────────
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
              const SnackBar(content: Text('Redirecting to PayMongo...')),
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
                  width: MediaQuery.of(context).size.width * 0.88,
                  height: MediaQuery.of(context).size.width * 0.88,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 32,
                        offset: const Offset(0, 12),
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
                          padding: const EdgeInsets.all(24),
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
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          child: Column(
                            children: [
                              Text(
                                'Amount: PHP ${widget.amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.darkGrey,
                                  letterSpacing: -0.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Reference: YANG${DateTime.now().millisecondsSinceEpoch}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
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
                top: 60,
                right: 24,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withOpacity(0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
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

