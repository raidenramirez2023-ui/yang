import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/menu_item.dart';

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
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(10),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Header - matching visual layout
              pw.Text('CEAZAR GABRIEL\'S RESTAURANT', 
                style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
              pw.Text('YANG CHOW', 
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.Text('Owned & optd by:', style: pw.TextStyle(fontSize: 12)),
              pw.Text('Ceazar Gabriel R.  Areza', style: pw.TextStyle(fontSize: 12)),
              pw.Text('Areza Town Center Mall brgy. Biñan', style: pw.TextStyle(fontSize: 12)),
              pw.Text('Pagsanjan Laguna', style: pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 16),
              
              // Order info - matching visual layout
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Table #: 32', style: pw.TextStyle(fontSize: 12)),
                  pw.Text('No. of Guest:  ${widget.cart.isNotEmpty ? "1" : "2"}', style: pw.TextStyle(fontSize: 12)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text('Term. No.  1', style: pw.TextStyle(fontSize: 12)),
                ],
              ),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text('WALK-IN', style: pw.TextStyle(fontSize: 12)),
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Cashr: ${_selectedCashier.length > 15 ? "${_selectedCashier.substring(0, 15)}..." : _selectedCashier}', style: pw.TextStyle(fontSize: 12)),
                  pw.Text('Server: $_selectedServer', style: pw.TextStyle(fontSize: 12)),
                ],
              ),
              pw.Divider(),
              pw.SizedBox(height: 3),
              
              // Items header - matching visual layout
              pw.Row(
                children: [
                  pw.SizedBox(
                    width: 50,
                    child: pw.Text('Qty', 
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Expanded(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6),
                      child: pw.Text('Description(s)', 
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    ),
                  ),
                  pw.SizedBox(
                    width: 110,
                    child: pw.Text('Price', 
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.right),
                  ),
                ],
              ),
              pw.Divider(),
              pw.SizedBox(height: 3),
              
              // Category
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text('DINE IN', style: pw.TextStyle(fontSize: 12)),
              ),
              
              // Items - matching visual layout with proper quantity formatting
              ...widget.cart.map((item) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 1),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(
                      width: 50,
                      child: pw.Text('  ${item.quantity.toStringAsFixed(2)}', 
                        style: pw.TextStyle(fontSize: 12)),
                    ),
                    pw.Expanded(
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6),
                        child: pw.Text(item.item.name.toUpperCase(), 
                          style: pw.TextStyle(fontSize: 12)),
                      ),
                    ),
                    pw.SizedBox(
                      width: 110,
                      child: pw.Text(_fmt.format(item.item.price * item.quantity), 
                        style: pw.TextStyle(fontSize: 12),
                        textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
              )),
              
              pw.SizedBox(height: 3),
              pw.Text('----------------------------${widget.cart.length} Item(s)-----------------------------',
                style: pw.TextStyle(fontSize: 12), textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 6),
              
              // Totals - matching visual layout
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('  Sub Total', style: pw.TextStyle(fontSize: 12)),
                  pw.Text(_fmt.format(widget.cart.fold(0.0, (s, i) => s + i.item.price * i.quantity)), 
                    style: pw.TextStyle(fontSize: 12)),
                ],
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL', 
                    style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  pw.Text(_fmt.format(_total), 
                    style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 16),
              
              // Payment - matching visual layout
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text('Tendered:', style: pw.TextStyle(fontSize: 12)),
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('  ${_method.toUpperCase()}', 
                    style: pw.TextStyle(fontSize: 12)),
                  pw.Text(_fmt.format(_paid), style: pw.TextStyle(fontSize: 12)),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Change:', style: pw.TextStyle(fontSize: 12)),
                  pw.Text(_fmt.format(_change), style: pw.TextStyle(fontSize: 12)),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Divider(),
              pw.SizedBox(height: 24),
              
              // Timestamp - matching visual layout
              pw.Text('${DateTime.now().month.toString().padLeft(2, '0')}/'
                      '${DateTime.now().day.toString().padLeft(2, '0')}/'
                      '${DateTime.now().year} '
                      '${DateTime.now().hour.toString().padLeft(2, '0')}:'
                      '${DateTime.now().minute.toString().padLeft(2, '0')}:'
                      '${DateTime.now().second.toString().padLeft(2, '0')}',
                style: pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 20),
              
              // Name and Address
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text('Name: _________________________________________', 
                  style: pw.TextStyle(fontSize: 12)),
              ),
              pw.SizedBox(height: 6),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text('Address: ______________________________________', 
                  style: pw.TextStyle(fontSize: 12)),
              ),
              pw.SizedBox(height: 6),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text('         ______________________________________', 
                  style: pw.TextStyle(fontSize: 12)),
              ),
              pw.SizedBox(height: 12),
              
              // Official receipt text
              pw.Align(
                alignment: pw.Alignment.center,
                child: pw.Text('This serves as an official receipt.',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
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
            _sidebarItem('GCash', Icons.account_balance_wallet_outlined, 'GCASH'),
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
        setState(() => _method = value);
        if (value == 'GCash') {
          _showGcashQR();
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

  void _showGcashQR() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 550,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: SingleChildScrollView(
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'GCash Payment',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _textDark,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.grey,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // QR Code Image
                SizedBox(
                  width: 500,
                  height: 500,
                  child: Image.asset(
                    'assets/images/newgcash.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Instructions
                const Text(
                  'Scan the QR code using your GCash app',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'to complete the payment',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Close Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _indigo,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Done',
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
            ),
          ),
        );
      },
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
