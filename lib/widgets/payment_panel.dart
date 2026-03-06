import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'shared_pos_widget.dart';

class PaymentPanel extends StatefulWidget {
  final List<CartItem> cart;
  final VoidCallback onBack;
  final void Function(String customerName, String paymentMethod, double paidAmount, double changeDue) onComplete;
  final String customerName;

  const PaymentPanel({
    super.key,
    required this.cart,
    required this.onBack,
    required this.onComplete,
    this.customerName = '',
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

  static const _border = Color(0xFFE2E8F0);
  static const _labelGrey = Color(0xFF94A3B8);
  static const _textDark = Color(0xFF1E293B);
  static const _indigo = Color(0xFF4F46E5);
  static const _green = Color(0xFF10B981);

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
        if (_entered.length < 10) _entered += key;
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
        } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
          if (_canComplete) {
            _ctrl.reverse().then((_) {
              widget.onComplete(widget.customerName, _method, _paid, _change);
            });
          }
          return KeyEventResult.handled;
        } else if (key == LogicalKeyboardKey.escape) {
          widget.onBack();
          return KeyEventResult.handled;
        } else if (key == LogicalKeyboardKey.period || key == LogicalKeyboardKey.numpadDecimal) {
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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
      child: Column(
        children: [
          const SizedBox(height: 8),
          IconButton(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _labelGrey, size: 20),
          ),
          const SizedBox(height: 8),
          // Logo Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _indigo,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.point_of_sale, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 32),
          _sidebarItem('Cash', Icons.payments_outlined, 'CASH'),
          _sidebarItem('GCash', Icons.account_balance_wallet_outlined, 'GCASH'),
          _sidebarItem('Card', Icons.credit_card_outlined, 'CARD'),
          _sidebarItem('QR', Icons.qr_code_2_outlined, 'QR'),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.only(bottom: 20, left: 16),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Icon(Icons.dark_mode_outlined, color: _labelGrey, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(String value, IconData icon, String label) {
    bool isSelected = _method == value;
    return GestureDetector(
      onTap: () => setState(() => _method = value),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 10),
        width: double.infinity,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? _indigo : Colors.transparent, width: 1.5),
          boxShadow: isSelected ? [
            BoxShadow(
              color: _indigo.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ] : null,
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
            border: Border.all(color: _indigo.withValues(alpha: 0.3), width: 1.5),
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
          border: Border.all(color: isDel ? Colors.red.withValues(alpha: 0.1) : _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Center(
          child: isDel
              ? const Icon(Icons.backspace_outlined, color: Colors.redAccent, size: 24)
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('CLEAR', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 60,
            child: ElevatedButton(
              onPressed: _canComplete
                  ? () {
                      _ctrl.reverse().then((_) {
                        widget.onComplete(widget.customerName, _method, _paid, _change);
                      });
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _indigo,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _indigo.withValues(alpha: 0.3),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Complete Transaction',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(width: 10),
                  Icon(Icons.check_circle_outline, size: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
