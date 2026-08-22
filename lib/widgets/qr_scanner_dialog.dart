import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/audit_log_service.dart';
import '../utils/app_theme.dart';

typedef ReservationVerifiedCallback = void Function(Map<String, dynamic> reservation);

class QrScannerDialog extends StatefulWidget {
  final ReservationVerifiedCallback? onCheckInSuccess;

  const QrScannerDialog({super.key, this.onCheckInSuccess});

  static Future<void> show(BuildContext context, {ReservationVerifiedCallback? onCheckInSuccess}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => QrScannerDialog(onCheckInSuccess: onCheckInSuccess),
    );
  }

  @override
  State<QrScannerDialog> createState() => _QrScannerDialogState();
}

class _QrScannerDialogState extends State<QrScannerDialog> with SingleTickerProviderStateMixin {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  final TextEditingController _manualInputController = TextEditingController();

  bool _isProcessing = false;
  bool _isManualMode = false;
  Map<String, dynamic>? _verifiedReservation;
  String? _errorMessage;

  @override
  void dispose() {
    _scannerController.dispose();
    _manualInputController.dispose();
    super.dispose();
  }

  void _handleBarcodeDetect(BarcodeCapture capture) {
    if (_isProcessing || _verifiedReservation != null) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.isNotEmpty) {
        _processScannedCode(rawValue);
        break;
      }
    }
  }

  Future<void> _processScannedCode(String code) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      String reservationId = code.trim();

      // Check if it follows format 'YANGCHOW:RES:<reservation_id>:<customer_email>'
      if (reservationId.startsWith('YANGCHOW:RES:')) {
        final parts = reservationId.split(':');
        if (parts.length >= 3) {
          reservationId = parts[2];
        }
      }

      Map<String, dynamic>? res;
      String cleanSearch = reservationId.toLowerCase().replaceAll('#', '').trim();
      
      // Strip common displayed reference prefixes like ORD-, RES-, etc.
      if (cleanSearch.startsWith('ord-')) {
        cleanSearch = cleanSearch.substring(4).trim();
      } else if (cleanSearch.startsWith('res-')) {
        cleanSearch = cleanSearch.substring(4).trim();
      } else if (cleanSearch.startsWith('ord:')) {
        cleanSearch = cleanSearch.substring(4).trim();
      } else if (cleanSearch.startsWith('res:')) {
        cleanSearch = cleanSearch.substring(4).trim();
      } else if (cleanSearch.startsWith('ord_')) {
        cleanSearch = cleanSearch.substring(4).trim();
      } else if (cleanSearch.startsWith('res_')) {
        cleanSearch = cleanSearch.substring(4).trim();
      }

      final isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(cleanSearch);

      if (isUuid) {
        res = await Supabase.instance.client
            .from('reservations')
            .select('*')
            .eq('id', cleanSearch)
            .maybeSingle();
      } else {
        // Query recent reservations and match by prefix or email
        final list = await Supabase.instance.client
            .from('reservations')
            .select('*')
            .order('created_at', ascending: false)
            .limit(200);

        for (final r in list) {
          final idStr = (r['id'] ?? '').toString().toLowerCase();
          final emailStr = (r['customer_email'] ?? '').toString().toLowerCase();
          final nameStr = (r['customer_name'] ?? '').toString().toLowerCase();
          if (idStr.startsWith(cleanSearch) || idStr.contains(cleanSearch) || emailStr.contains(cleanSearch) || nameStr.contains(cleanSearch)) {
            res = Map<String, dynamic>.from(r);
            break;
          }
        }
      }

      if (res == null) {
        // Try advance_orders table if not in reservations
        Map<String, dynamic>? orderRes;
        if (isUuid) {
          orderRes = await Supabase.instance.client
              .from('advance_orders')
              .select('*')
              .eq('id', cleanSearch)
              .maybeSingle();
        } else {
          final orderList = await Supabase.instance.client
              .from('advance_orders')
              .select('*')
              .order('created_at', ascending: false)
              .limit(200);

          for (final o in orderList) {
            final idStr = (o['id'] ?? '').toString().toLowerCase();
            final emailStr = (o['customer_email'] ?? '').toString().toLowerCase();
            final nameStr = (o['customer_name'] ?? '').toString().toLowerCase();
            if (idStr.startsWith(cleanSearch) || idStr.contains(cleanSearch) || emailStr.contains(cleanSearch) || nameStr.contains(cleanSearch)) {
              orderRes = Map<String, dynamic>.from(o);
              break;
            }
          }
        }

        if (orderRes != null) {
          final orderData = orderRes;
          if (mounted) {
            setState(() {
              _verifiedReservation = {
                ...orderData,
                'event_type': 'Advance Order (${orderData['order_type'] ?? 'Order'})',
                'event_date': orderData['order_date'],
                'start_time': orderData['order_time'],
                '_is_advance_order': true,
              };
              _isProcessing = false;
            });
          }
          return;
        }

        if (mounted) {
          setState(() {
            _errorMessage = 'No reservation found for code: "$reservationId"';
            _isProcessing = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _verifiedReservation = res;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Scan error: $e';
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _performCheckIn() async {
    if (_verifiedReservation == null) return;

    setState(() => _isProcessing = true);

    try {
      final resId = _verifiedReservation!['id'].toString();
      final customerName = _verifiedReservation!['customer_name'] ?? 'Guest';
      final isAdvanceOrder = _verifiedReservation!['_is_advance_order'] == true;

      if (isAdvanceOrder) {
        // Mark Advance Order as completed
        await Supabase.instance.client.from('advance_orders').update({
          'status': 'completed',
        }).eq('id', resId);

        try {
          await AuditLogService.logActivity(
            action: 'RELEASE_ORDER',
            module: 'ADVANCE_ORDERS',
            description: 'Staff released & served Advance Order for $customerName via QR Code Scan.',
            entityId: resId,
            metadata: {
              'customer_name': customerName,
              'release_time': DateTime.now().toIso8601String(),
            },
          );
        } catch (_) {}
      } else {
        // Update reservation status if not already completed
        final currentStatus = (_verifiedReservation!['status'] ?? '').toString().toLowerCase();
        if (currentStatus != 'completed') {
          await Supabase.instance.client.from('reservations').update({
            'status': 'confirmed',
            'special_requests': '${_verifiedReservation!['special_requests'] ?? ''} [Checked In at ${DateTime.now().toIso8601String()}]'.trim(),
          }).eq('id', resId);
        }

        try {
          await AuditLogService.logActivity(
            action: 'CHECK_IN',
            module: 'RESERVATIONS',
            description: 'Staff verified reservation for customer $customerName via QR Code Scan.',
            entityId: resId,
            metadata: {
              'customer_name': customerName,
              'check_in_time': DateTime.now().toIso8601String(),
            },
          );
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF15803D),
            content: Row(
              children: [
                const Icon(Icons.verified_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isAdvanceOrder
                        ? 'Order released and served to $customerName!'
                        : 'Verified booking for $customerName!',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        );

        final verifiedData = _verifiedReservation!;
        Navigator.pop(context);
        widget.onCheckInSuccess?.call(verifiedData);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Check-in failed: $e';
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 480,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dialog Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                color: const Color(0xFF16302A), // Forest Green
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.warmGold, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Guest Pass Verification',
                            style: GoogleFonts.lora(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Scan customer QR voucher to check-in',
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Mode Switcher Tab
              Container(
                padding: const EdgeInsets.all(8),
                color: const Color(0xFFF3F4F6),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _isManualMode = false;
                            _errorMessage = null;
                            _verifiedReservation = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: !_isManualMode ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: !_isManualMode
                                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt_rounded, size: 16, color: !_isManualMode ? const Color(0xFF16302A) : Colors.grey),
                              const SizedBox(width: 6),
                              Text(
                                'Camera Scanner',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: !_isManualMode ? FontWeight.w700 : FontWeight.w500,
                                  color: !_isManualMode ? const Color(0xFF16302A) : Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _isManualMode = true;
                            _errorMessage = null;
                            _verifiedReservation = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _isManualMode ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: _isManualMode
                                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.keyboard_rounded, size: 16, color: _isManualMode ? const Color(0xFF16302A) : Colors.grey),
                              const SizedBox(width: 6),
                              Text(
                                'Manual Reference',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: _isManualMode ? FontWeight.w700 : FontWeight.w500,
                                  color: _isManualMode ? const Color(0xFF16302A) : Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _verifiedReservation != null
                      ? _buildVerifiedDetailsCard()
                      : (_isManualMode ? _buildManualInputSection() : _buildCameraScannerSection()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraScannerSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 240,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.warmGold.withValues(alpha: 0.4), width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _handleBarcodeDetect,
                ),
                // Scanning overlay frame
                Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.warmGold, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                if (_isProcessing)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: CircularProgressIndicator(color: AppTheme.warmGold),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.inter(color: Colors.red[900], fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildManualInputSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _manualInputController,
          decoration: InputDecoration(
            hintText: 'Enter Booking Reference # or ID',
            hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
            prefixIcon: const Icon(Icons.tag_rounded, color: Color(0xFF16302A)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
          ),
          onSubmitted: (val) => _processScannedCode(val),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : () => _processScannedCode(_manualInputController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16302A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isProcessing
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('Verify Booking', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(_errorMessage!, style: GoogleFonts.inter(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ],
    );
  }

  Widget _buildVerifiedDetailsCard() {
    final res = _verifiedReservation!;
    final isAdvanceOrder = res['_is_advance_order'] == true || res['_db_table'] == 'advance_orders';
    final resId = (res['id'] ?? '').toString();
    final shortId = resId.length > 8 ? resId.substring(0, 8).toUpperCase() : resId.toUpperCase();
    final name = (res['customer_name'] ?? 'Guest').toString();
    final email = (res['customer_email'] ?? '').toString();
    final phone = (res['customer_phone'] ?? res['phone'] ?? '').toString();
    final orderType = (res['order_type'] ?? (isAdvanceOrder ? 'Takeout' : 'Dining Reservation')).toString();
    final eventType = (res['event_type'] ?? (isAdvanceOrder ? 'Advance Order ($orderType)' : 'Reservation')).toString();
    final date = (res['event_date'] ?? res['order_date'] ?? 'N/A').toString();
    final time = (res['start_time'] ?? res['order_time'] ?? res['pickup_time'] ?? 'N/A').toString();
    final pax = res['number_of_guests'] ?? res['guests_count'] ?? res['guest_count'];
    final totalPrice = res['total_price'] ?? res['total_amount'] ?? res['price'];
    final paymentStatus = (res['payment_status'] ?? 'unpaid').toString().toUpperCase();
    final status = (res['status'] ?? 'confirmed').toString().toUpperCase();
    final isCompleted = status == 'COMPLETED' || status == 'DONE' || status == 'SERVED';

    // Parse ordered menu items from database
    final dynamic rawItems = res['selected_menu_items'] ?? res['items'] ?? res['order_items'];
    final List<Map<String, dynamic>> itemsList = [];
    if (rawItems is Map) {
      rawItems.forEach((k, v) {
        itemsList.add({'name': k.toString(), 'qty': v.toString()});
      });
    } else if (rawItems is List) {
      for (final it in rawItems) {
        if (it is Map) {
          itemsList.add({
            'name': (it['name'] ?? it['item_name'] ?? it['dish_name'] ?? '').toString(),
            'qty': (it['quantity'] ?? it['qty'] ?? 1).toString(),
          });
        } else if (it is String) {
          itemsList.add({'name': it, 'qty': '1'});
        }
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Verified Success Header
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isCompleted ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isCompleted ? const Color(0xFFBFDBFE) : const Color(0xFFBBF7D0)),
          ),
          child: Row(
            children: [
              Icon(
                isCompleted ? Icons.task_alt_rounded : Icons.check_circle_rounded,
                color: isCompleted ? const Color(0xFF2563EB) : const Color(0xFF16A34A),
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAdvanceOrder
                          ? (isCompleted ? 'Advance Order (Already Served)' : 'Verified Advance Order ($orderType)')
                          : (isCompleted ? 'Reservation (Already Checked-In)' : 'Verified Reservation Match'),
                      style: GoogleFonts.inter(
                        color: isCompleted ? const Color(0xFF1E40AF) : const Color(0xFF166534),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'Ref: #${isAdvanceOrder ? 'ORD' : 'RES'}-$shortId',
                      style: GoogleFonts.inter(
                        color: isCompleted ? const Color(0xFF3B82F6) : const Color(0xFF15803D),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Guest & Booking Particulars
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              _buildDetailRow('Guest Name:', name, isBold: true),
              if (phone.isNotEmpty) ...[
                const Divider(height: 10),
                _buildDetailRow('Contact Phone:', phone),
              ] else if (email.isNotEmpty) ...[
                const Divider(height: 10),
                _buildDetailRow('Email:', email),
              ],
              const Divider(height: 10),
              _buildDetailRow(isAdvanceOrder ? 'Order Type:' : 'Event Type:', isAdvanceOrder ? '$orderType (Advance Order)' : eventType),
              const Divider(height: 10),
              _buildDetailRow(isAdvanceOrder ? 'Pickup / Dine Time:' : 'Event Schedule:', '$date • $time'),
              if (!isAdvanceOrder && pax != null) ...[
                const Divider(height: 10),
                _buildDetailRow('Party Size (Pax):', '$pax Guests'),
              ],
              if (totalPrice != null) ...[
                const Divider(height: 10),
                _buildDetailRow('Total Amount:', '₱$totalPrice ($paymentStatus)', isAccent: paymentStatus == 'PAID' || paymentStatus == 'FULLY_PAID'),
              ],
              const Divider(height: 10),
              _buildDetailRow('Status:', status, isAccent: !isCompleted),
            ],
          ),
        ),

        // Itemized Menu / Order Dishes List from Database
        if (itemsList.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.restaurant_menu_rounded, size: 14, color: Color(0xFF14332E)),
                    const SizedBox(width: 6),
                    Text(
                      'ORDERED DISHES & ITEMS',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF14332E),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...itemsList.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14332E).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${item['qty']}x',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF14332E),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item['name'],
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],

        if (_errorMessage != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Text(
              _errorMessage!,
              style: GoogleFonts.inter(color: const Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
        const SizedBox(height: 14),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _verifiedReservation = null;
                    _errorMessage = null;
                  });
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Scan Another', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.grey[800])),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                icon: _isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(
                        isAdvanceOrder
                            ? (isCompleted ? Icons.done_all_rounded : Icons.check_circle_outline_rounded)
                            : Icons.verified_user_rounded,
                        size: 16,
                      ),
                label: Text(
                  _isProcessing
                      ? 'Processing...'
                      : (isAdvanceOrder
                          ? (isCompleted ? 'Order Already Served' : 'Release & Serve Order')
                          : 'Verify Booking'),
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: (isAdvanceOrder && isCompleted)
                      ? const Color(0xFF64748B)
                      : const Color(0xFF15803D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: (_isProcessing || (isAdvanceOrder && isCompleted)) ? null : _performCheckIn,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, bool isAccent = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[700])),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isBold || isAccent ? FontWeight.w800 : FontWeight.w600,
            color: isAccent ? const Color(0xFF16A34A) : Colors.black87,
          ),
        ),
      ],
    );
  }
}
