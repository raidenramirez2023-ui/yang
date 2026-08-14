import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/menu_item.dart';
import '../services/paymongo_service.dart';

class PaymentPanel extends StatefulWidget {
  final List<CartItem> cart;
  final VoidCallback onBack;
  final void Function(
    String customerName,
    String note,
    String paymentMethod,
    double paidAmount,
    double changeDue,
    String cashierName,
    String serverName,
  )
  onComplete;
  final String customerName;
  final String note;
  final double? overrideTotalAmount; // Optional total with discount included

  const PaymentPanel({
    super.key,
    required this.cart,
    required this.onBack,
    required this.onComplete,
    this.customerName = '',
    this.note = '',
    this.overrideTotalAmount,
  });

  @override
  State<PaymentPanel> createState() => _PaymentPanelState();
}

class _PaymentPanelState extends State<PaymentPanel>
    with SingleTickerProviderStateMixin {
  final NumberFormat _fmt = NumberFormat('#,##0.00', 'en_US');

  late AnimationController _ctrl;
  late Animation<Offset> _slide;

  String _method = 'Cash';
  String _entered = '';
  // ignore: unused_field
  bool _isPayMongoProcessing = false;
  Timer? _pollingTimer;
  // ignore: unused_field
  String? _currentLinkId;
  String _selectedCashier = 'Spongebob Squarepants';
  String _selectedServer = 'Sanji';

  static const _border = Color(0xFFE2E8F0);
  static const _labelGrey = Color(0xFF94A3B8);
  static const _textDark = Color(0xFF1E293B);
  static const _indigo = Color(0xFF4F46E5);
  static const _green = Color(0xFF10B981);

  // Get users from user management based on roles
  List<String> get _cashierNames {
    // Static list based on your user management data
    return [
      'Spongebob Squarepants', // Cashier & Food Server
      'Squidward Tentacles',  // Cashier & Food Server
    ];
  }

  List<String> get _serverNames {
    // Static list based on your user management data
    return [
      'Sanji',        // Dine-in Food Server
      'Peter Parker', // Dine-in Food Server
      'Clark Kent',   // Dine-in Food Server
      'Spongebob Squarepants', // Also serves as food server
      'Squidward Tentacles',   // Also serves as food server
    ];
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slide = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  double get _total =>
      widget.overrideTotalAmount ??
      widget.cart.fold(0.0, (s, i) => s + i.item.price * i.quantity);

  double get _paid => double.tryParse(_entered) ?? 0.0;
  double get _change => _paid - _total;
  bool get _canComplete => _paid >= _total && _total > 0;

  String get _displayPaid {
    if (_entered.isEmpty) return '0.00';
    final v = double.tryParse(_entered);
    if (v == null) return _entered;
    if (_entered.endsWith('.')) return '${_fmt.format(v)}.';
    return _fmt.format(v);
  }

  Future<void> _printReceipt() async {

    
    final receiptData = await _generateReceiptPDF();
    
    // Print or download the PDF
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => receiptData,
      name: 'receipt_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );

    // Complete the transaction after printing
    _ctrl.reverse().then((_) {
      widget.onComplete(
        widget.customerName,
        widget.note,
        _method,
        _paid,
        _change,
        _selectedCashier,
        _selectedServer,
      );
    });
  }

  Future<Uint8List> _generateReceiptPDF() async {
    final pdf = pw.Document();
    
    // Use built-in Courier monospace font for consistent character-width alignment
    final monoFont = pw.Font.courier();
    final monoBoldFont = pw.Font.courierBold();
    
    // Base styles matching the digital receipt's monospace look
    final baseStyle = pw.TextStyle(fontSize: 10, font: monoFont);
    final boldStyle = pw.TextStyle(fontSize: 10, font: monoBoldFont);
    final headerStyle = pw.TextStyle(fontSize: 12, font: monoBoldFont);
    final subHeaderStyle = pw.TextStyle(fontSize: 11, font: monoBoldFont);
    final totalStyle = pw.TextStyle(fontSize: 11, font: monoBoldFont);

    
    // Dash divider matching the digital receipt
    pw.Widget dashDivider() {
      return pw.Text(
        '------------------------------------------------',
        style: baseStyle,
        textAlign: pw.TextAlign.center,
        maxLines: 1,
      );
    }
    
    // Receipt-sized page: 80mm width, auto height
    final receiptFormat = PdfPageFormat.roll80.copyWith(
      marginTop: 10,
      marginBottom: 10,
      marginLeft: 10,
      marginRight: 10,
    );
    
    pdf.addPage(
      pw.Page(
        pageFormat: receiptFormat,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // ===== HEADER SECTION =====
              pw.Text("CEAZAR GABRIEL'S RES", style: headerStyle,
                textAlign: pw.TextAlign.center),
              pw.Text('TAURANT', style: headerStyle,
                textAlign: pw.TextAlign.center),
              pw.Text('YANG CHOW', style: subHeaderStyle,
                textAlign: pw.TextAlign.center),
              pw.Text('Owned & optd by:', style: baseStyle,
                textAlign: pw.TextAlign.center),
              pw.Text('Ceazar Gabriel R.  Areza', style: baseStyle,
                textAlign: pw.TextAlign.center),
              pw.Text('Areza Town Center Mall brgy. Bi\u00f1an', style: baseStyle,
                textAlign: pw.TextAlign.center),
              pw.Text('Pagsanjan Laguna', style: baseStyle,
                textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 12),
              
              // ===== ORDER INFO SECTION =====
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Table #: 32', style: baseStyle),
                  pw.Text('No. of Guest:  ${widget.cart.isNotEmpty ? "1" : "2"}', style: baseStyle),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text('Term. No.  1', style: baseStyle),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text('WALK-IN', style: baseStyle),
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Flexible(
                    child: pw.Text(
                      'Cashr: ${_selectedCashier.length > 15 ? "${_selectedCashier.substring(0, 15)}..." : _selectedCashier}',
                      style: baseStyle,
                      maxLines: 1,
                    ),
                  ),
                  pw.Flexible(
                    child: pw.Text('Server: $_selectedServer',
                      style: baseStyle,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              dashDivider(),
              pw.SizedBox(height: 3),
              
              // ===== ITEMS HEADER =====
              pw.Row(
                children: [
                  pw.SizedBox(
                    width: 40,
                    child: pw.Text('Qty', style: boldStyle),
                  ),
                  pw.Expanded(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                      child: pw.Text('Description(s)', style: boldStyle),
                    ),
                  ),
                  pw.SizedBox(
                    width: 50,
                    child: pw.Text('Price', style: boldStyle,
                      textAlign: pw.TextAlign.right),
                  ),
                ],
              ),
              dashDivider(),
              pw.SizedBox(height: 3),
              
              // ===== CATEGORY LABEL =====
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text('DINE IN', style: baseStyle),
              ),
              
              // ===== ITEMS =====
              ...widget.cart.map((item) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 1),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(
                      width: 40,
                      child: pw.Text('  ${item.quantity.toStringAsFixed(2)}', 
                        style: baseStyle),
                    ),
                    pw.Expanded(
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                        child: pw.Text(item.item.name.toUpperCase(), 
                          style: baseStyle,
                          maxLines: 2),
                      ),
                    ),
                    pw.SizedBox(
                      width: 50,
                      child: pw.Text(_fmt.format(item.item.price * item.quantity), 
                        style: baseStyle,
                        textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
              )),
              
              pw.SizedBox(height: 3),
              
              // ===== ITEM COUNT WITH DASHES =====
              pw.Text(
                '----------${widget.cart.length} Item(s)-----------',
                style: baseStyle,
                textAlign: pw.TextAlign.center,
                maxLines: 1,
              ),
              pw.SizedBox(height: 6),
              
              // ===== SUBTOTAL & TOTAL =====
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('  Sub Total', style: baseStyle),
                  pw.Text(_fmt.format(widget.cart.fold(0.0, (s, i) => s + i.item.price * i.quantity)), 
                    style: baseStyle),
                ],
              ),
              dashDivider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL', style: totalStyle),
                  pw.Text(_fmt.format(_total), style: totalStyle),
                ],
              ),
              pw.SizedBox(height: 12),
              
              // ===== PAYMENT SECTION =====
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text('Tendered:', style: baseStyle),
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('  ${_method.toUpperCase()}', style: baseStyle),
                  pw.Text(_fmt.format(_paid), style: baseStyle),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Change:', style: baseStyle),
                  pw.Text(_fmt.format(_change), style: baseStyle),
                ],
              ),
              pw.SizedBox(height: 3),
              dashDivider(),
              pw.SizedBox(height: 16),
              
              // ===== TIMESTAMP =====
              pw.Text(
                '${DateTime.now().month.toString().padLeft(2, '0')}/'
                '${DateTime.now().day.toString().padLeft(2, '0')}/'
                '${DateTime.now().year} '
                '${DateTime.now().hour.toString().padLeft(2, '0')}:'
                '${DateTime.now().minute.toString().padLeft(2, '0')}:'
                '${DateTime.now().second.toString().padLeft(2, '0')}',
                style: baseStyle,
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 14),
              
              // ===== NAME & ADDRESS =====
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text('Name: ____________________________________', style: baseStyle),
              ),
              pw.SizedBox(height: 4),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text('Address: _________________________________', style: baseStyle),
              ),
              pw.SizedBox(height: 10),
              
              // ===== OFFICIAL RECEIPT TEXT =====
              pw.Align(
                alignment: pw.Alignment.center,
                child: pw.Text('This serves as an official receipt.',
                  style: boldStyle),
              ),
            ],
          );
        },
      ),
    );
    
    return pdf.save();
  }

  void _tap(String key) {
    setState(() {
      if (key == 'DEL') {
        if (_entered.isNotEmpty) {
          _entered = _entered.substring(0, _entered.length - 1);
        }
      } else if (key == '.') {
        if (!_entered.contains('.')) {
          _entered = _entered.isEmpty ? '0.' : '$_entered.';
        }
      } else {
        if (_entered.length < 9) _entered += key;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.backspace) {
          _tap('DEL');
          return KeyEventResult.handled;
        } else if (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) {
          if (_canComplete) {
            _ctrl.reverse().then((_) {
              widget.onComplete(
                widget.customerName,
                widget.note,
                _method,
                _paid,
                _change,
                _selectedCashier,
                _selectedServer,
              );
            });
          }
          return KeyEventResult.handled;
        } else if (key == LogicalKeyboardKey.escape) {
          widget.onBack();
          return KeyEventResult.handled;
        } else if (key == LogicalKeyboardKey.period ||
            key == LogicalKeyboardKey.numpadDecimal) {
          _tap('.');
          return KeyEventResult.handled;
        }

        // Handle numbers 0-9 and Numpad 0-9
        final char = event.character;
        if (char != null && RegExp(r'^[0-9]$').hasMatch(char)) {
          _tap(char);
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: SlideTransition(
        position: _slide,
        child: Material(
          color: Colors.white,
          child: Row(
            children: [
              _buildSidebar(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Column(
                    children: [
                      _buildTopSummary(),
                      const SizedBox(height: 24),
                      _buildInputBox(),
                      const SizedBox(height: 24),
                      Expanded(child: _buildNumpad()),
                      const SizedBox(height: 24),
                      _buildActions(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 80,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: _border)),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 8),
            IconButton(
              onPressed: widget.onBack,
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _labelGrey,
                size: 20,
              ),
            ),
            const SizedBox(height: 6),
            // Logo Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _indigo,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.point_of_sale,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(height: 24),
            _sidebarItem('Cash', Icons.payments_outlined, 'CASH'),
            _sidebarItem('E-wallet', Icons.qr_code_2, 'E-WALLET'),
            _sidebarCashierButton(),
            _sidebarServerButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sidebarServerButton() {
    return GestureDetector(
      onTap: () => _showServerSelection(),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 10),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.green,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.room_service_outlined,
              color: Colors.green,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              'Server',
              style: TextStyle(
                color: Colors.green,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sidebarCashierButton() {
    return GestureDetector(
      onTap: () => _showCashierSelection(),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 10),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _indigo,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.person_outline,
              color: _indigo,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              'Cashier',
              style: TextStyle(
                color: _indigo,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sidebarItem(String value, IconData icon, String label) {
    bool isSelected = _method == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _method = value;
          if (value == 'E-wallet') {
            _entered = _total.toStringAsFixed(2);
          } else if (value == 'Cash') {
            _entered = '';
          }
        });
        if (value == 'E-wallet') {
          _startPayMongoPayment();
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 10),
        width: double.infinity,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? _indigo : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _indigo.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? _indigo : _labelGrey, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? _indigo : _labelGrey,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── PayMongo Payment Flow ──────────────────────────────────────────

  Future<void> _startPayMongoPayment() async {
    setState(() {
      _entered = _total.toStringAsFixed(2);
      _isPayMongoProcessing = true;
    });

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            CircularProgressIndicator(color: _indigo),
            const SizedBox(width: 16),
            const Text('Creating payment link...'),
          ],
        ),
      ),
    );

    try {
      // Create PayMongo payment link with the order total
      final response = await PayMongoService.createPaymentLink(
        amount: _total,
        description: 'POS Dine-In Order',
        metadata: {
          'source': 'pos',
          'cashier': _selectedCashier,
          'server': _selectedServer,
        },
      );

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      if (response['success'] == true && response['checkoutUrl'] != null) {
        final checkoutUrl = response['checkoutUrl'];
        final linkId = response['linkId'];
        _currentLinkId = linkId;

        // Open PayMongo checkout page in a new browser tab
        final uri = Uri.parse(checkoutUrl);
        await launchUrl(uri, mode: LaunchMode.externalApplication);

        // Show "Waiting for payment" dialog and start polling
        if (mounted) {
          _showWaitingForPaymentDialog();
          _startPollingForPayment(linkId);
        }
      } else {
        throw Exception('Failed to create payment link');
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.of(context).pop();
      setState(() => _isPayMongoProcessing = false);

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 24),
                const SizedBox(width: 8),
                const Text('Payment Error'),
              ],
            ),
            content: Text('Failed to create payment link:\n$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showWaitingForPaymentDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(28),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _indigo.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.qr_code_2, size: 48, color: _indigo),
            ),
            const SizedBox(height: 20),
            const Text(
              'Waiting for Payment...',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: _indigo.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '₱${_fmt.format(_total)}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: _indigo,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: _indigo,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'The PayMongo checkout page has been opened\nin a new browser tab.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              'Customer should scan the QR code to pay.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textDark,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _pollingTimer?.cancel();
              setState(() => _isPayMongoProcessing = false);
              Navigator.pop(dialogContext);
            },
            child: const Text(
              'Cancel Payment',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _startPollingForPayment(String linkId) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final result = await PayMongoService.retrievePaymentLink(linkId);
        if (result['isPaid'] == true) {
          timer.cancel();
          setState(() => _isPayMongoProcessing = false);

          // Close the "Waiting for payment" dialog
          if (mounted) Navigator.of(context).pop();

          // Show payment received confirmation dialog
          if (mounted) _showPaymentReceivedDialog();
        }
      } catch (e) {
        debugPrint('PayMongo polling error: $e');
        // Don't cancel on error — keep trying
      }
    });
  }

  void _showPaymentReceivedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(28),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(Icons.check_circle, size: 48, color: _green),
            ),
            const SizedBox(height: 20),
            const Text(
              'Payment Received!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _green,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _paymentInfoRow('Amount', '₱${_fmt.format(_total)}'),
                  const SizedBox(height: 8),
                  _paymentInfoRow('Method', 'PayMongo (E-Wallet)'),
                  const SizedBox(height: 8),
                  _paymentInfoRow('Change', '₱0.00'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _printReceipt();
              },
              icon: const Icon(Icons.print, size: 20),
              label: const Text(
                'Print Receipt',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _indigo,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: _textDark,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  
  void _showServerSelection() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.room_service_outlined,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Select Server',
                      style: TextStyle(
                        color: _textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close,
                        color: _labelGrey,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                for (String name in _serverNames)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedServer = name;
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedServer == name
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: _selectedServer == name
                              ? Border.all(color: Colors.green, width: 1.5)
                              : Border.all(color: _border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.room_service_outlined,
                              color: _selectedServer == name ? Colors.green : _labelGrey,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                name,
                                style: TextStyle(
                                  color: _selectedServer == name ? Colors.green : _textDark,
                                  fontSize: 13,
                                  fontWeight: _selectedServer == name
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                            if (_selectedServer == name)
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 16,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCashierSelection() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      color: _indigo,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Select Cashier',
                      style: TextStyle(
                        color: _textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close,
                        color: _labelGrey,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                for (String name in _cashierNames)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedCashier = name;
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedCashier == name
                              ? _indigo.withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: _selectedCashier == name
                              ? Border.all(color: _indigo, width: 1.5)
                              : Border.all(color: _border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.person,
                              color: _selectedCashier == name ? _indigo : _labelGrey,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                name,
                                style: TextStyle(
                                  color: _selectedCashier == name ? _indigo : _textDark,
                                  fontSize: 13,
                                  fontWeight: _selectedCashier == name
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                            if (_selectedCashier == name)
                              const Icon(
                                Icons.check_circle,
                                color: _indigo,
                                size: 16,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopSummary() {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          _summaryItem('TOTAL AMOUNT', '₱${_fmt.format(_total)}', _textDark),
          _vDivider(),
          _summaryItem('AMOUNT PAID', '₱$_displayPaid', _indigo),
          _vDivider(),
          _summaryItem(
            'CHANGE DUE (SUKLI)',
            '₱${_change < 0 ? '0.00' : _fmt.format(_change)}',
            _green,
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _labelGrey,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(width: 1, height: 40, color: _border);

  Widget _buildInputBox() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 90,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _indigo.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            '₱$_displayPaid',
            style: const TextStyle(
              color: _textDark,
              fontSize: 42,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            ),
          ),
        ),
        Positioned(
          top: -10,
          left: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            color: Colors.white,
            child: const Text(
              'INPUT AMOUNT',
              style: TextStyle(
                color: _indigo,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNumpad() {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['.', '0', 'DEL'],
    ];

    return Column(
      children: keys.map((row) {
        return Expanded(
          child: Row(
            children: row.map((key) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: _numpadKey(key),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _numpadKey(String key) {
    final isDel = key == 'DEL';
    return GestureDetector(
      onTap: () => _tap(key),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDel ? Colors.red.withValues(alpha: 0.1) : _border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: isDel
              ? const Icon(
                  Icons.backspace_outlined,
                  color: Colors.redAccent,
                  size: 24,
                )
              : Text(
                  key,
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: SizedBox(
            height: 60,
            child: ElevatedButton(
              onPressed: () => setState(() => _entered = ''),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF1F5F9),
                foregroundColor: _textDark,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'CLEAR',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 60,
            child: ElevatedButton(
              onPressed: _canComplete ? _printReceipt : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _indigo,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _indigo.withValues(alpha: 0.3),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Print Receipt',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(width: 10),
                  Icon(Icons.print, size: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
