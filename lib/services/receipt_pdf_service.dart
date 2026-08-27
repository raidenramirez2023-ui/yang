import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReceiptPdfService {
  static final NumberFormat _currencyFmt = NumberFormat.currency(
    locale: 'en_PH',
    symbol: 'PHP ',
    decimalDigits: 2,
  );

  static final DateFormat _dateTimeFmt = DateFormat('MMM dd, yyyy • hh:mm a');

  /// Generates the PDF document for a given reservation.
  /// Set [isPaymentReceipt] = true to generate an official Payment Receipt
  /// (used after admin cash settlement) instead of a Booking Pass.
  static Future<Uint8List> generateReservationVoucherPdf(
    Map<String, dynamic> reservation, {
    bool isPaymentReceipt = false,
  }) async {
    final pdf = pw.Document();

    final resId = (reservation['id'] ?? 'N/A').toString();
    final shortId = resId.length > 8 ? resId.substring(0, 8).toUpperCase() : resId.toUpperCase();
    final isAdvanceOrder = reservation['_db_table'] == 'advance_orders' || reservation['_is_advance_order'] == true;
    final customerName = (reservation['customer_name'] ?? 'Guest').toString();
    final customerEmail = (reservation['customer_email'] ?? '').toString();
    final customerPhone = (reservation['customer_phone'] ?? reservation['phone'] ?? 'N/A').toString();
    final eventType = (reservation['event_type'] ?? (isAdvanceOrder ? 'Advance Order (${reservation['order_type'] ?? 'Takeout'})' : 'Dining Reservation')).toString();
    final eventDateStr = (reservation['event_date'] ?? reservation['order_date'] ?? '').toString();
    final startTime = (reservation['start_time'] ?? reservation['order_time'] ?? reservation['pickup_time'] ?? 'N/A').toString();
    final durationHours = reservation['duration_hours']?.toString() ?? (isAdvanceOrder ? 'Pickup' : '2');
    final guestsCount = (reservation['guests_count'] ?? reservation['guest_count'] ?? (isAdvanceOrder ? '1' : 'N/A')).toString();
    final transactedBy = (reservation['transacted_by'] != null && reservation['transacted_by'].toString().isNotEmpty)
        ? reservation['transacted_by'].toString()
        : 'Pending Admin Processing';
    final paymentStatus = (reservation['payment_status'] ?? 'Pending').toString().toUpperCase();
    final status = (reservation['status'] ?? 'Confirmed').toString().toUpperCase();
    
    // Financials
    final rawTotal = reservation['total_price'] ?? reservation['total_amount'] ?? reservation['price'] ?? 0;
    final totalAmount = double.tryParse(rawTotal.toString()) ?? 0.0;
    final rawDeposit = reservation['downpayment_amount'] ?? reservation['deposit_amount'] ?? (totalAmount * 0.5);
    final depositAmount = double.tryParse(rawDeposit.toString()) ?? 0.0;
    // If this is a payment receipt, remaining balance is always 0 (fully settled)
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
          menuItems.add({'name': item, 'qty': 1, 'price': 0});
        }
      }
    } else if (rawMenu is Map) {
      rawMenu.forEach((key, value) {
        menuItems.add({
          'name': key.toString(),
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
                      final name = item['name'] ?? item['title'] ?? 'Dish Item';
                      final qty = item['qty'] ?? item['quantity'] ?? 1;
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(name.toString(), style: const pw.TextStyle(fontSize: 8)),
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
                                      '✓',
                                      style: pw.TextStyle(
                                        color: PdfColors.white,
                                        fontSize: 28,
                                        fontWeight: pw.FontWeight.bold,
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
                                  'Cash received & recorded\nby Yang Chow staff.',
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
    final label = isPaymentReceipt ? 'Receipt' : 'Voucher';

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
}
