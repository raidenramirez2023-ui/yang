import 'package:flutter/material.dart';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:url_launcher/url_launcher.dart';

import 'package:yang_chow/services/paymongo_service.dart';

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

  String? _currentLinkId;

  bool _isVerifying = false;



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: Colors.white,

      appBar: AppBar(

        title: const Text('Payment'),

        backgroundColor: AppTheme.primaryColor,

        foregroundColor: Colors.white,

        elevation: 0,

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

                      'Pay ${PayMongoService.formatAmount(widget.amount)}',

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

            color: AppTheme.primaryColor.withValues(alpha: 0.1),

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

            color: Color(0xFF1E1E1E),

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

  // ── E-Wallet (GCash / Maya) ─────────────────────────────────────────────────
  Future<void> _processEWalletPayment(String type) async {
    try {
      final returnUrl = kIsWeb
          ? '${Uri.base.origin}/#/customer-dashboard?status=success'
          : 'yangchow://payment/success';

      // 1. Create Payment Intent
      final intentResult = await PayMongoService.createPaymentIntent(
        amount: widget.amount,
        description: widget.description,
        currency: 'PHP',
        metadata: {
          // PayMongo requires all metadata values to be flat strings
          if (widget.metadata != null)
            ...widget.metadata!.map((k, v) => MapEntry(k, v?.toString() ?? '')),
          'payment_method': type,
          'reference_number': PayMongoService.generateReferenceNumber(),
        },
      );

      if (intentResult['success'] != true) {
        setState(() {
          _errorMessage = intentResult['error']?.toString() ?? 'Failed to create payment intent';
          _isProcessing = false;
        });
        return;
      }

      final paymentIntentId = intentResult['paymentIntentId'] as String;
      final clientKey = intentResult['clientKey'] as String;

      // 2. Create Payment Method
      final methodResult = await PayMongoService.createPaymentMethod(
        type: type,
        details: {},
      );

      if (methodResult['success'] != true) {
        setState(() {
          _errorMessage = methodResult['error']?.toString() ?? 'Failed to create payment method';
          _isProcessing = false;
        });
        return;
      }

      final paymentMethodId = methodResult['paymentMethodId'] as String;

      // 3. Attach Payment Method → gets redirect URL
      final attachResult = await PayMongoService.attachPaymentMethod(
        paymentIntentId: paymentIntentId,
        paymentMethodId: paymentMethodId,
        clientKey: clientKey,
        returnUrl: returnUrl,
      );

      if (attachResult['success'] != true) {
        setState(() {
          _errorMessage = attachResult['error']?.toString() ?? 'Failed to attach payment method';
          _isProcessing = false;
        });
        return;
      }

      final status = attachResult['data']['attributes']['status'];

      if (status == 'awaiting_next_action') {
        // 4. Redirect user to GCash / Maya
        final redirectUrl = attachResult['data']['attributes']
            ['next_action']?['redirect']?['url'] as String?;

        if (redirectUrl != null) {
          _currentLinkId = paymentIntentId; // reuse for verification
          await _launchPaymentUrl(redirectUrl);
        } else {
          setState(() {
            _errorMessage = 'Could not get ${type == 'gcash' ? 'GCash' : 'Maya'} redirect URL.';
            _isProcessing = false;
          });
        }
      } else if (status == 'succeeded') {
        _onPaymentSuccess();
      } else {
        setState(() {
          _errorMessage = 'Unexpected payment status: $status';
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Payment failed: ${e.toString()}';
        _isProcessing = false;
      });
    }
  }

  // ── Payment Link (QRPh, Card, Bank Transfer) ────────────────────────────────
  Future<void> _processPaymentLink() async {
    try {
      String? successUrl;
      String? cancelUrl;

      if (kIsWeb) {
        final currentUrl = Uri.base.origin;
        successUrl = '$currentUrl/#/customer-dashboard?status=success';
        cancelUrl = '$currentUrl/#/customer-dashboard?status=cancelled';
      }

      final result = await PayMongoService.createPaymentLink(
        amount: widget.amount,
        description: widget.description,
        returnUrl: successUrl,
        cancelUrl: cancelUrl,
        metadata: {
          // PayMongo requires all metadata values to be flat strings
          if (widget.metadata != null)
            ...widget.metadata!.map((k, v) => MapEntry(k, v?.toString() ?? '')),
          'payment_method': _selectedPaymentMethod!['type'],
          'reference_number': PayMongoService.generateReferenceNumber(),
        },
      );

      if (result['success'] == true) {
        _currentLinkId = result['data']['data']['id'] as String;
        if (kIsWeb) {
          await _launchPaymentUrl(result['checkoutUrl'] as String);
        } else {
          await _openPaymentWebView(result['checkoutUrl'] as String);
        }
      } else {
        setState(() {
          _errorMessage = result['error']?.toString() ?? 'Failed to create payment link';
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Payment processing failed: ${e.toString()}';
        _isProcessing = false;
      });
    }
  }



  Future<void> _launchPaymentUrl(String url) async {

    try {

      final uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {

        await launchUrl(

          uri,

          mode: LaunchMode.externalApplication,

        );

        

        // Show dialog for web payment completion

        _showWebPaymentDialog();

      } else {

        setState(() {

          _errorMessage = 'Could not launch payment URL';

          _isProcessing = false;

        });

      }

    } catch (e) {

      setState(() {

        _errorMessage = 'Error launching payment: ${e.toString()}';

        _isProcessing = false;

      });

    }

  }



  void _showWebPaymentDialog() {

    showDialog(

      context: context,

      barrierDismissible: false,

      builder: (context) => StatefulBuilder(

        builder: (context, setDialogState) => AlertDialog(

          title: const Text('Payment in Progress'),

          content: Column(

            mainAxisSize: MainAxisSize.min,

            children: [

              if (_isVerifying)

                const CircularProgressIndicator()

              else

                const Icon(Icons.launch, size: 48, color: AppTheme.primaryColor),

              const SizedBox(height: 16),

              Text(

                _isVerifying 

                  ? 'Verifying your payment...' 

                  : 'Payment page opened in new tab.\nComplete the payment and return here.',

                textAlign: TextAlign.center,

              ),

              const SizedBox(height: 16),

              const Text(

                'After payment completion, click "Verify Payment" below.',

                textAlign: TextAlign.center,

                style: TextStyle(fontSize: 12, color: Colors.grey),

              ),

            ],

          ),

          actions: [

            TextButton(

              onPressed: () {

                Navigator.of(context).pop();

                setState(() {

                  _isProcessing = false;

                });

              },

              child: const Text('Cancel'),

            ),

            ElevatedButton(

              onPressed: _isVerifying ? null : () async {

                setDialogState(() => _isVerifying = true);

                final success = await _verifyPayment();

                setDialogState(() => _isVerifying = false);

                

                if (success) {
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                } else {
                  // Show mini error or just keep dialog open
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Payment not yet detected. Please complete payment first.',
                      ),
                    ),
                  );
                }

              },

              style: ElevatedButton.styleFrom(

                backgroundColor: AppTheme.primaryColor,

                foregroundColor: Colors.white,

              ),

              child: const Text('Verify Payment'),

            ),

          ],

        ),

      ),

    );

  }



  Future<bool> _verifyPayment() async {

    if (_currentLinkId == null) return false;



    try {

      final result = await PayMongoService.retrievePaymentLink(_currentLinkId!);

      if (result['success'] == true && result['isPaid'] == true) {

        _onPaymentSuccess();

        return true;

      }

    } catch (e) {

      debugPrint('Error verifying payment: $e');

    }

    return false;

  }



  void _onPaymentSuccess() {

    widget.onPaymentComplete?.call(true, {

      'status': 'success',

      'amount': widget.amount,

      'payment_method': _selectedPaymentMethod!['type'],

      'link_id': _currentLinkId,

    });

    

    if (mounted) {

      if (Navigator.of(context).canPop()) {

        Navigator.of(context).pop(true);

      }

    }

  }



  Future<void> _openPaymentWebView(String checkoutUrl) async {



    await Navigator.of(context).push(

      MaterialPageRoute(

        builder: (context) => PaymentWebView(

          checkoutUrl: checkoutUrl,

          onSuccess: () {

            Navigator.of(context).pop(); // Close WebView

            Navigator.of(context).pop(true); // Close Payment Page

            widget.onPaymentComplete?.call(true, {

              'status': 'success',

              'amount': widget.amount,

              'payment_method': _selectedPaymentMethod!['type'],

            });

          },

          onCancel: () {

            Navigator.of(context).pop(); // Close WebView

            setState(() {

              _isProcessing = false;

            });

          },

          onError: (error) {

            Navigator.of(context).pop(); // Close WebView

            setState(() {

              _errorMessage = error;

              _isProcessing = false;

            });

          },

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

