import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Official Yang Chow PDF Receipt & Booking Voucher Service (Full Unicode)
// ══════════════════════════════════════════════════════════════════════════════

class ReceiptPdfService {
  static final NumberFormat _currencyFmt = NumberFormat.currency(
    locale: 'en_PH',
    symbol: 'PHP ',
    decimalDigits: 2,
  );

  static final DateFormat _dateTimeFmt = DateFormat('MMM dd, yyyy - hh:mm a');

  static String _clean(dynamic val) {
    if (val == null) return '';
    return val
        .toString()
        .replaceAll('•', '-')
        .replaceAll('✓', '')
        .replaceAll('√', '')
        .replaceAll('₱', 'PHP ')
        .trim();
  }

  /// Generates the PDF document for a given reservation with full Unicode font support.
  static Future<Uint8List> generateReservationVoucherPdf(
    Map<String, dynamic> reservation, {
    bool isPaymentReceipt = false,
  }) async {
    // Load Unicode-compatible Roboto fonts to eliminate font warning errors
    pw.ThemeData? theme;
    try {
      final fontRegular = await PdfGoogleFonts.robotoRegular();
      final fontBold = await PdfGoogleFonts.robotoBold();
      theme = pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
      );
    } catch (_) {
      // Graceful fallback to default if offline
    }

    final pdf = pw.Document(theme: theme);

    final resId = _clean(reservation['id'] ?? 'N/A');
    final shortId = resId.length > 8 ? resId.substring(0, 8).toUpperCase() : resId.toUpperCase();
    final isAdvanceOrder = reservation['_db_table'] == 'advance_orders' || reservation['_is_advance_order'] == true;
    final customerName = _clean(reservation['customer_name'] ?? 'Guest');
    final customerEmail = _clean(reservation['customer_email'] ?? '');
    final customerPhone = _clean(reservation['customer_phone'] ?? reservation['phone'] ?? 'N/A');
    final eventType = _clean(reservation['event_type'] ?? (isAdvanceOrder ? 'Advance Order (${reservation['order_type'] ?? 'Takeout'})' : 'Dining Reservation'));
    final eventDateStr = _clean(reservation['event_date'] ?? reservation['order_date'] ?? '');
    final startTime = _clean(reservation['start_time'] ?? reservation['order_time'] ?? reservation['pickup_time'] ?? 'N/A');
    final durationHours = _clean(reservation['duration_hours'] ?? (isAdvanceOrder ? 'Pickup' : '2'));
    final guestsCount = _clean(reservation['guests_count'] ?? reservation['guest_count'] ?? (isAdvanceOrder ? '1' : 'N/A'));
    final transactedBy = (reservation['transacted_by'] != null && reservation['transacted_by'].toString().isNotEmpty)
        ? _clean(reservation['transacted_by'])
        : 'Pending Admin Processing';
    final paymentStatus = _clean(reservation['payment_status'] ?? 'Pending').toUpperCase();
    final status = _clean(reservation['status'] ?? 'Confirmed').toUpperCase();
    
    // Financials
    final rawTotal = reservation['total_price'] ?? reservation['total_amount'] ?? reservation['price'] ?? 0;
    final totalAmount = double.tryParse(rawTotal.toString()) ?? 0.0;
    final rawDeposit = reservation['downpayment_amount'] ?? reservation['deposit_amount'] ?? (totalAmount * 0.5);
    final depositAmount = double.tryParse(rawDeposit.toString()) ?? 0.0;
    final remainingBalance = isPaymentReceipt ? 0.0 : (totalAmount > depositAmount ? (totalAmount - depositAmount) : 0.0);
    final cashSettledAmount = isPaymentReceipt ? (totalAmount - depositAmount).clamp(0.0, double.infinity) : 0.0;

    // Menu Items
    final dynamic rawMenu = reservation['selected_menu_items'] ?? reservation['menu_items'] ?? [];
    List<Map<String, dynamic>> menuItems = [];
    if (rawMenu is List) {
      for (final item in rawMenu) {
        if (item is Map) {
          menuItems.add(Map<String, dynamic>.from(item));
        } else if (item is String) {
          menuItems.add({'name': _clean(item), 'qty': 1, 'price': 0});
        }
      }
    } else if (rawMenu is Map) {
      rawMenu.forEach((key, value) {
        menuItems.add({
          'name': _clean(key),
          'qty': int.tryParse(value.toString()) ?? 1,
          'price': 0,
        });
      });
    }

    // Secure QR Payload
    final qrPayload = 'YANGCHOW:RES:$resId:$customerEmail';

    // Build the page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header with Brand & Receipt Badge
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('16302A'), // Deep Forest Green
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'YANG CHOW RESTAURANT',
                          style: pw.TextStyle(
                            color: PdfColor.fromHex('D4AF37'), // Warm Gold
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Authentic Chinese Culinary Experience',
                          style: const pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: pw.BoxDecoration(
                        color: isPaymentReceipt
                            ? PdfColor.fromHex('15803D')   // Green for receipt
                            : PdfColor.fromHex('D4AF37'),  // Gold for booking pass
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Text(
                        isPaymentReceipt ? 'OFFICIAL PAYMENT RECEIPT' : 'OFFICIAL BOOKING PASS',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 18),

              // Reference & Issue Date Row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        isPaymentReceipt ? 'RECEIPT NUMBER' : 'BOOKING REFERENCE',
                        style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 8),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '#${isPaymentReceipt ? 'RCPT' : (isAdvanceOrder ? 'ORD' : 'RES')}-$shortId',
                        style: pw.TextStyle(
                          color: PdfColor.fromHex('16302A'),
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'ISSUED ON',
                        style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 8),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        _dateTimeFmt.format(DateTime.now()),
                        style: const pw.TextStyle(
                          color: PdfColors.black,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 14),
              pw.Divider(color: PdfColors.grey300, thickness: 1),
              pw.SizedBox(height: 10),

              // Two Column Info Section (Guest Details & Event Details)
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left: Customer Details
                  pw.Expanded(
                    flex: 5,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('F9FAFB'),
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: PdfColors.grey200),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'GUEST INFORMATION',
                            style: pw.TextStyle(
                              color: PdfColor.fromHex('16302A'),
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 6),
                          _buildPdfInfoRow('Name:', customerName),
                          _buildPdfInfoRow('Email:', customerEmail),
                          _buildPdfInfoRow('Phone:', customerPhone),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  // Right: Reservation Details
                  pw.Expanded(
                    flex: 5,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('F9FAFB'),
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: PdfColors.grey200),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'EVENT RESERVATION DETAILS',
                            style: pw.TextStyle(
                              color: PdfColor.fromHex('16302A'),
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 6),
                          _buildPdfInfoRow('Event:', eventType),
                          _buildPdfInfoRow('Date:', eventDateStr.isNotEmpty ? eventDateStr : 'TBD'),
                          _buildPdfInfoRow('Time Window:', '$startTime ($durationHours hrs)'),
                          _buildPdfInfoRow('Guests (Pax):', '$guestsCount Pax'),
                          _buildPdfInfoRow('Transacted By:', transactedBy),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 14),

              // Menu Selection Table (if any)
              if (menuItems.isNotEmpty) ...[
                pw.Text(
                  'RESERVED MENU & PACKAGES',
                  style: pw.TextStyle(
                    color: PdfColor.fromHex('16302A'),
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.8),
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColor.fromHex('F3F4F6')),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Item / Package', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Qty', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    ...menuItems.map((item) {
                      final name = _clean(item['name'] ?? item['title'] ?? 'Dish Item');
                      final qty = item['qty'] ?? item['quantity'] ?? 1;
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(name, style: const pw.TextStyle(fontSize: 8)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(qty.toString(), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8)),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 14),
              ],

              // Payment Summary and QR Verification Box Row
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Payment Summary
                  pw.Expanded(
                    flex: 6,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: PdfColors.grey300),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'PAYMENT & BILLING SUMMARY',
                            style: pw.TextStyle(
                              color: PdfColor.fromHex('16302A'),
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          _buildPdfBillingRow('Total Amount:', _currencyFmt.format(totalAmount), isBold: true),
                          _buildPdfBillingRow('Deposit Paid:', _currencyFmt.format(depositAmount)),
                          if (isPaymentReceipt) ...[
                            _buildPdfBillingRow('Cash Settled:', _currencyFmt.format(cashSettledAmount), isAccent: true),
                            pw.Divider(color: PdfColors.grey200),
                            _buildPdfBillingRow('Remaining Balance:', 'PHP 0.00  (FULLY SETTLED)', isBold: true, isAccent: true),
                          ] else ...[
                            _buildPdfBillingRow('Remaining Balance:', _currencyFmt.format(remainingBalance)),
                            pw.Divider(color: PdfColors.grey200),
                          ],
                          _buildPdfBillingRow('Payment Status:', isPaymentReceipt ? 'FULLY PAID' : paymentStatus, isAccent: true),
                          _buildPdfBillingRow('Booking Status:', status),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 14),
                  // QR Verification Card OR Payment Confirmed Seal
                  pw.Expanded(
                    flex: 4,
                    child: isPaymentReceipt
                        // ── Payment Receipt: green confirmed seal ──
                        ? pw.Container(
                            padding: const pw.EdgeInsets.all(12),
                            decoration: pw.BoxDecoration(
                              color: PdfColor.fromHex('F0FDF4'),
                              borderRadius: pw.BorderRadius.circular(8),
                              border: pw.Border.all(color: PdfColor.fromHex('86EFAC'), width: 1.5),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.center,
                              mainAxisAlignment: pw.MainAxisAlignment.center,
                              children: [
                                pw.Container(
                                  width: 48,
                                  height: 48,
                                  decoration: pw.BoxDecoration(
                                    color: PdfColor.fromHex('15803D'),
                                    shape: pw.BoxShape.circle,
                                  ),
                                  child: pw.Center(
                                    child: pw.Text(
                                      'PAID',
                                      style: pw.TextStyle(
                                        color: PdfColors.white,
                                        fontSize: 12,
                                        fontWeight: pw.FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                                pw.SizedBox(height: 8),
                                pw.Text(
                                  'PAYMENT',
                                  style: pw.TextStyle(
                                    color: PdfColor.fromHex('15803D'),
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                pw.Text(
                                  'CONFIRMED',
                                  style: pw.TextStyle(
                                    color: PdfColor.fromHex('15803D'),
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                pw.SizedBox(height: 6),
                                pw.Text(
                                  'Payment received & recorded\nby Yang Chow system.',
                                  textAlign: pw.TextAlign.center,
                                  style: const pw.TextStyle(
                                    color: PdfColors.grey700,
                                    fontSize: 6.5,
                                  ),
                                ),
                              ],
                            ),
                          )
                        // ── Booking Pass: entry QR ──
                        : pw.Container(
                            padding: const pw.EdgeInsets.all(12),
                            decoration: pw.BoxDecoration(
                              color: PdfColor.fromHex('F9FAFB'),
                              borderRadius: pw.BorderRadius.circular(8),
                              border: pw.Border.all(color: PdfColor.fromHex('D4AF37'), width: 1.2),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.center,
                              children: [
                                pw.Text(
                                  'ENTRY VERIFICATION QR',
                                  style: pw.TextStyle(
                                    color: PdfColor.fromHex('16302A'),
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.SizedBox(height: 6),
                                pw.Container(
                                  height: 85,
                                  width: 85,
                                  padding: const pw.EdgeInsets.all(4),
                                  color: PdfColors.white,
                                  child: pw.BarcodeWidget(
                                    barcode: pw.Barcode.qrCode(),
                                    data: qrPayload,
                                    drawText: false,
                                  ),
                                ),
                                pw.SizedBox(height: 4),
                                pw.Text(
                                  'Present to staff upon arrival for 1-click check-in.',
                                  textAlign: pw.TextAlign.center,
                                  style: const pw.TextStyle(
                                    color: PdfColors.grey700,
                                    fontSize: 6.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),

              pw.Spacer(),

              // Footer Note & Terms
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('F3F4F6'),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Thank you for dining at Yang Chow. For inquiries, call: (02) 8123-4567',
                      style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 7),
                    ),
                    pw.Text(
                      'Automated E-Receipt System',
                      style: pw.TextStyle(color: PdfColor.fromHex('16302A'), fontSize: 7, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Trigger PDF download directly to device/downloads without opening printer dialog
  static Future<void> downloadReceiptPdf(
    Map<String, dynamic> reservation, {
    bool isPaymentReceipt = false,
  }) async {
    final pdfBytes = await generateReservationVoucherPdf(
      reservation,
      isPaymentReceipt: isPaymentReceipt,
    );
    final resId = (reservation['id'] ?? 'booking').toString();
    final shortId = resId.length > 8 ? resId.substring(0, 8).toUpperCase() : resId.toUpperCase();
    final isAdvanceOrder = reservation['_db_table'] == 'advance_orders' || reservation['_is_advance_order'] == true;
    final label = isPaymentReceipt ? 'Receipt' : (isAdvanceOrder ? 'ClaimSlip' : 'BookingSlip');

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'YangChow_${label}_$shortId.pdf',
    );
  }

  /// Trigger PDF preview or printing directly
  static Future<void> printOrShareVoucher(
    Map<String, dynamic> reservation, {
    bool isPaymentReceipt = false,
  }) async {
    final pdfBytes = await generateReservationVoucherPdf(
      reservation,
      isPaymentReceipt: isPaymentReceipt,
    );
    final resId = (reservation['id'] ?? 'booking').toString();
    final shortId = resId.length > 8 ? resId.substring(0, 8) : resId;
    final isAdvanceOrder = reservation['_db_table'] == 'advance_orders' || reservation['_is_advance_order'] == true;
    final label = isPaymentReceipt ? 'Receipt' : (isAdvanceOrder ? 'ClaimSlip' : 'BookingSlip');

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'YangChow_${label}_$shortId.pdf',
    );
  }

  static pw.Widget _buildPdfInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 75,
            child: pw.Text(
              label,
              style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 8),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                color: PdfColors.black,
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfBillingRow(
    String label,
    String value, {
    bool isBold = false,
    bool isAccent = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              color: isAccent ? PdfColor.fromHex('16302A') : PdfColors.grey700,
              fontSize: 8,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              color: isAccent ? PdfColor.fromHex('15803D') : PdfColors.black,
              fontSize: 8.5,
              fontWeight: isBold || isAccent ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  /// Generates a standardized 57mm thermal POS receipt PDF document (supports official Reprint mode)
  static Future<Uint8List> generatePosReceiptPdf({
    required String transactionId,
    required DateTime transactionDate,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    double paidAmount = 0.0,
    double changeDue = 0.0,
    String paymentMethod = 'CASH',
    String? customerName,
    String? customerAddress,
    String? note,
    String? tableNumber,
    int? guestCount,
    String? serverName,
    String? cashierName,
    double discountAmount = 0.0,
    String discountLabel = 'None',
    String? discountName,
    String? discountAddress,
    String diningOption = 'Dine-in',
    bool isReprint = false,
    String? reprintedBy,
    DateTime? reprintDate,
    String? reprintReason,
  }) async {
    final pdf = pw.Document();
    final monoFont = pw.Font.courier();
    final monoBoldFont = pw.Font.courierBold();

    final baseStyle = pw.TextStyle(fontSize: 9.5, font: monoFont);
    final boldStyle = pw.TextStyle(fontSize: 9.5, font: monoBoldFont);
    final headerStyle = pw.TextStyle(fontSize: 12, font: monoBoldFont);
    final subHeaderStyle = pw.TextStyle(fontSize: 11, font: monoBoldFont);
    final totalStyle = pw.TextStyle(fontSize: 11.5, font: monoBoldFont);
    final alertStyle = pw.TextStyle(fontSize: 9, font: monoBoldFont);

    pw.Widget dashDivider() {
      return pw.Text(
        '------------------------------------------------',
        style: baseStyle,
        textAlign: pw.TextAlign.center,
        maxLines: 1,
      );
    }

    pw.Widget starDivider() {
      return pw.Text(
        '************************************************',
        style: baseStyle,
        textAlign: pw.TextAlign.center,
        maxLines: 1,
      );
    }

    final fmt = NumberFormat('#,##0.00', 'en_US');
    final formattedDate = DateFormat('MM/dd/yyyy').format(transactionDate);
    final formattedTime = DateFormat('HH:mm:ss').format(transactionDate);
    final subtotal = items.fold<double>(0.0, (sum, it) {
      final price = (it['unit_price'] as num?)?.toDouble() ?? 0.0;
      final qty = (it['quantity'] as num?)?.toInt() ?? 1;
      return sum + (price * qty);
    });

    // Parse split payments if applicable (e.g. "SPLIT (CASH: 5,000.00, GCASH: 8,712.00)")
    final isSplitPayment = paymentMethod.trim().toUpperCase().startsWith('SPLIT') && paymentMethod.contains('(');
    final splitItems = <Map<String, String>>[];
    if (isSplitPayment) {
      final inner = paymentMethod
          .replaceFirst(RegExp(r'^SPLIT\s*\(?', caseSensitive: false), '')
          .replaceAll(RegExp(r'\)+$'), '')
          .trim();
      final regex = RegExp(
        r'(?:^|,\s*)([A-Za-z0-9_\-\s]+?):\s*(?:₱|PHP\s*)?([0-9,]+(?:\.[0-9]+)?)(?:\s*\[Ref:\s*([^\]]+)\])?',
        caseSensitive: false,
      );
      for (final match in regex.allMatches(inner)) {
        final m = match.group(1)?.trim().toUpperCase() ?? '';
        final a = match.group(2)?.trim() ?? '';
        final r = match.group(3)?.trim();
        if (m.isNotEmpty && a.isNotEmpty) {
          splitItems.add({
            'method': m,
            'amount': a,
            if (r != null && r.isNotEmpty) 'ref': r,
          });
        }
      }
    }

    final receiptFormat = PdfPageFormat.roll57.copyWith(
      marginTop: 8,
      marginBottom: 8,
      marginLeft: 8,
      marginRight: 8,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: receiptFormat,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // ===== REPRINT WATERMARK / BANNER =====
              if (isReprint) ...[
                starDivider(),
                pw.Text('*** REPRINT COPY ***', style: pw.TextStyle(fontSize: 11, font: monoBoldFont)),
                pw.Text('NOT AN OFFICIAL RECEIPT', style: alertStyle),
                starDivider(),
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Reprinted:', style: baseStyle),
                    pw.Text(
                      DateFormat('MMM dd, yyyy hh:mm a').format(reprintDate ?? DateTime.now()),
                      style: baseStyle,
                    ),
                  ],
                ),
                if (reprintedBy != null && reprintedBy.isNotEmpty)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('By:', style: baseStyle),
                      pw.Text(reprintedBy, style: baseStyle),
                    ],
                  ),
                if (reprintReason != null && reprintReason.isNotEmpty)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Reason:', style: baseStyle),
                      pw.Text(reprintReason, style: baseStyle),
                    ],
                  ),
                dashDivider(),
                pw.SizedBox(height: 4),
              ],

              // ===== STORE HEADER =====
              pw.Text("CEAZAR GABRIEL'S", style: headerStyle, textAlign: pw.TextAlign.center),
              pw.Text('RESTAURANT', style: headerStyle, textAlign: pw.TextAlign.center),
              pw.Text('YANG CHOW', style: subHeaderStyle, textAlign: pw.TextAlign.center),
              pw.Text('Owned & optd by:', style: baseStyle, textAlign: pw.TextAlign.center),
              pw.Text('Ceazar Gabriel R.  Areza', style: baseStyle, textAlign: pw.TextAlign.center),
              pw.Text('Areza Town Center Mall brgy. Biñan', style: baseStyle, textAlign: pw.TextAlign.center),
              pw.Text('Pagsanjan Laguna', style: baseStyle, textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 8),

              // ===== ORDER METADATA =====
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Table #: ${tableNumber != null && tableNumber.isNotEmpty ? tableNumber : "N/A"}', style: baseStyle),
                  pw.Text('No. of Guest: ${guestCount ?? 2}', style: baseStyle),
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
                    child: pw.Text('Cashr: ${cashierName ?? "JANE"}', style: baseStyle, maxLines: 1),
                  ),
                  pw.Flexible(
                    child: pw.Text('Server: ${serverName ?? "JANE"}', style: baseStyle, maxLines: 1),
                  ),
                ],
              ),
              dashDivider(),
              pw.SizedBox(height: 2),

              // ===== ITEMS TABLE HEADER =====
              pw.Row(
                children: [
                  pw.SizedBox(width: 32, child: pw.Text('Qty', style: boldStyle)),
                  pw.Expanded(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                      child: pw.Text('Description(s)', style: boldStyle),
                    ),
                  ),
                  pw.SizedBox(width: 48, child: pw.Text('Price', style: boldStyle, textAlign: pw.TextAlign.right)),
                ],
              ),
              dashDivider(),
              pw.SizedBox(height: 2),

              // ===== DINING CATEGORY =====
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  diningOption.toLowerCase().contains('take') ? 'TAKE HOME' : 'DINE IN',
                  style: baseStyle,
                ),
              ),

              // ===== LINE ITEMS =====
              ...items.map((it) {
                final qty = (it['quantity'] as num?)?.toDouble() ?? 1.0;
                final price = (it['unit_price'] as num?)?.toDouble() ?? 0.0;
                final name = (it['item_name'] ?? it['name'] ?? 'Item').toString().toUpperCase();
                final lineTotal = price * qty;

                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(
                        width: 32,
                        child: pw.Text(' ${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 2)}', style: baseStyle),
                      ),
                      pw.Expanded(
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                          child: pw.Text(name, style: baseStyle, maxLines: 2),
                        ),
                      ),
                      pw.SizedBox(
                        width: 48,
                        child: pw.Text(fmt.format(lineTotal), style: baseStyle, textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                );
              }),

              pw.SizedBox(height: 4),
              pw.Text(
                '----------${items.length} Item(s)-----------',
                style: baseStyle,
                textAlign: pw.TextAlign.center,
                maxLines: 1,
              ),
              pw.SizedBox(height: 4),

              // ===== SUBTOTAL & TOTAL =====
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('  Sub Total', style: baseStyle),
                  pw.Text(fmt.format(subtotal > 0 ? subtotal : totalAmount), style: baseStyle),
                ],
              ),
              if (discountAmount > 0) ...[
                pw.SizedBox(height: 1),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('  Discount ($discountLabel)', style: pw.TextStyle(fontSize: 8.5, font: monoFont)),
                    pw.Text('-${fmt.format(discountAmount)}', style: pw.TextStyle(fontSize: 8.5, font: monoFont)),
                  ],
                ),
              ],
              dashDivider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL', style: totalStyle),
                  pw.Text(fmt.format(totalAmount), style: totalStyle),
                ],
              ),
              pw.SizedBox(height: 8),

              // ===== PAYMENT & CHANGE =====
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text('Tendered / Payments:', style: baseStyle),
              ),
              pw.SizedBox(height: 2),
              if (splitItems.isNotEmpty) ...[
                for (final item in splitItems) ...[
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('  ${item['method']}:', style: baseStyle),
                      pw.Text(item['amount']!, style: baseStyle),
                    ],
                  ),
                  if (item['ref'] != null && item['ref']!.isNotEmpty) ...[
                    pw.SizedBox(height: 1),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      children: [
                        pw.Text('Ref: ${item['ref']}', style: pw.TextStyle(fontSize: 8.5, font: monoFont)),
                      ],
                    ),
                  ],
                  pw.SizedBox(height: 1),
                ],
              ] else ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('  ${paymentMethod.toUpperCase()}', style: baseStyle),
                    pw.Text(fmt.format(paidAmount > 0 ? paidAmount : totalAmount), style: baseStyle),
                  ],
                ),
              ],
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Change:', style: baseStyle),
                  pw.Text(fmt.format(changeDue), style: baseStyle),
                ],
              ),
              dashDivider(),
              pw.SizedBox(height: 10),

              // ===== TIMESTAMP & TXN =====
              pw.Text('TXN: #$transactionId', style: boldStyle, textAlign: pw.TextAlign.center),
              pw.Text('$formattedDate $formattedTime', style: baseStyle, textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 10),

              // ===== CUSTOMER / DISCOUNT INFO =====
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'Name: ${(discountAmount > 0 && discountName != null && discountName.isNotEmpty ? discountName : customerName) ?? "________________________________"}',
                  style: baseStyle,
                  maxLines: 1,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'Address: ${(discountAmount > 0 && discountAddress != null && discountAddress.isNotEmpty ? discountAddress : customerAddress) ?? "_____________________________"}',
                  style: baseStyle,
                  maxLines: 1,
                ),
              ),
              pw.SizedBox(height: 8),

              // ===== FOOTER NOTICE =====
              if (isReprint) ...[
                pw.Text('*** DUPLICATE / REPRINT RECEIPT ***', style: alertStyle, textAlign: pw.TextAlign.center),
                pw.Text('Original TXN: $formattedDate $formattedTime', style: pw.TextStyle(fontSize: 8, font: monoFont), textAlign: pw.TextAlign.center),
              ] else ...[
                pw.Text('This serves as an official receipt.', style: boldStyle, textAlign: pw.TextAlign.center),
              ],
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Triggers standard printing dialog for POS Receipt
  static Future<void> printPosReceipt({
    required String transactionId,
    required DateTime transactionDate,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    double paidAmount = 0.0,
    double changeDue = 0.0,
    String paymentMethod = 'CASH',
    String? customerName,
    String? customerAddress,
    String? note,
    String? tableNumber,
    int? guestCount,
    String? serverName,
    String? cashierName,
    double discountAmount = 0.0,
    String discountLabel = 'None',
    String? discountName,
    String? discountAddress,
    String diningOption = 'Dine-in',
    bool isReprint = false,
    String? reprintedBy,
    DateTime? reprintDate,
    String? reprintReason,
  }) async {
    final pdfBytes = await generatePosReceiptPdf(
      transactionId: transactionId,
      transactionDate: transactionDate,
      items: items,
      totalAmount: totalAmount,
      paidAmount: paidAmount,
      changeDue: changeDue,
      paymentMethod: paymentMethod,
      customerName: customerName,
      customerAddress: customerAddress,
      note: note,
      tableNumber: tableNumber,
      guestCount: guestCount,
      serverName: serverName,
      cashierName: cashierName,
      discountAmount: discountAmount,
      discountLabel: discountLabel,
      discountName: discountName,
      discountAddress: discountAddress,
      diningOption: diningOption,
      isReprint: isReprint,
      reprintedBy: reprintedBy,
      reprintDate: reprintDate,
      reprintReason: reprintReason,
    );

    final prefix = isReprint ? 'REPRINT' : 'RECEIPT';
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'YangChow_${prefix}_$transactionId.pdf',
    );
  }
}
