import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:yang_chow/services/paymongo_service.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/widgets/payment_method_selector.dart';

// Conditional import for WebView
import 'package:webview_flutter/webview_flutter.dart' if (dart.library.io) 'package:webview_flutter/webview_flutter.dart';

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

    try {
      // Create payment link
      final result = await PayMongoService.createPaymentLink(
        amount: widget.amount,
        description: widget.description,
        returnUrl: 'yangchow://payment/success',
        cancelUrl: 'yangchow://payment/cancel',
        metadata: {
          ...?widget.metadata,
          'payment_method': _selectedPaymentMethod!['type'],
          'reference_number': PayMongoService.generateReferenceNumber(),
        },
      );

      if (result['success']) {
        if (kIsWeb) {
          // For web, launch URL in new tab
          await _launchPaymentUrl(result['checkoutUrl']);
        } else {
          // For mobile/desktop, use WebView
          await _openPaymentWebView(result['checkoutUrl']);
        }
      } else {
        setState(() {
          _errorMessage = result['error'];
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
      builder: (context) => AlertDialog(
        title: const Text('Payment in Progress'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text(
              'Payment page opened in new tab.\nComplete the payment and return here.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'After payment completion, click "Payment Completed" below.',
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
            onPressed: () {
              Navigator.of(context).pop();
              _simulatePaymentSuccess();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Payment Completed'),
          ),
        ],
      ),
    );
  }

  void _simulatePaymentSuccess() {
    // For web testing, simulate successful payment
    widget.onPaymentComplete?.call(true, {
      'status': 'success',
      'amount': widget.amount,
      'payment_method': _selectedPaymentMethod!['type'],
    });
    Navigator.of(context).pop(true);
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
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    
    // Only initialize WebView if not on web
    if (!kIsWeb) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {
              // Update loading bar
            },
            onPageStarted: (String url) {
              setState(() {
                _isLoading = true;
              });
            },
            onPageFinished: (String url) {
              setState(() {
                _isLoading = false;
              });
            },
            onWebResourceError: (WebResourceError error) {
              widget.onError('WebView error: ${error.description}');
            },
          ),
        )
        ..loadRequest(Uri.parse(widget.checkoutUrl));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // For web, show a message instead of WebView
      return Scaffold(
        appBar: AppBar(
          title: const Text('Payment'),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.open_in_browser,
                size: 64,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                'Payment opened in new tab',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Please complete the payment in your browser and return to this app.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Payment'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onCancel,
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
