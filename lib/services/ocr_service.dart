import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:yang_chow/services/app_settings_service.dart';

class OcrService {
  static String get _apiKey => AppSettingsService().getOcrApiKey();
  static const String _apiUrl = 'https://api.ocr.space/parse/image';

  /// Extracts text from an image URL and attempts to find currency amounts and reference numbers
  static Future<Map<String, dynamic>> analyzeReceipt(String imageUrl) async {
    try {
      // Detect file type from URL
      String fileType = 'PNG'; // Default
      final uri = Uri.tryParse(imageUrl);
      if (uri != null && uri.path.contains('.')) {
        final extension = uri.path.split('.').last.toLowerCase();
        final typeMap = {
          'png': 'PNG',
          'jpg': 'JPG',
          'jpeg': 'JPG',
          'pdf': 'PDF',
          'gif': 'GIF',
          'bmp': 'BMP',
          'webp': 'PNG',
        };
        fileType = typeMap[extension] ?? 'PNG';
      }

      final response = await http.post(
        Uri.parse(_apiUrl),
        body: {
          'apikey': _apiKey,
          'url': imageUrl,
          'language': 'eng',
          'isOverlayRequired': 'false',
          'isTable': 'true',
          'filetype': fileType,
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['OCRExitCode'] == 1) {
          final String fullText = data['ParsedResults'][0]['ParsedText'];
          return _parseReceiptData(fullText);
        } else {
          return {'success': false, 'error': data['ErrorMessage'] ?? 'OCR Failed'};
        }
      }
      return {'success': false, 'error': 'Server Error: ${response.statusCode}'};
    } catch (e) {
      debugPrint('OCR Error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Map<String, dynamic> _parseReceiptData(String text) {
    // Regex for Philippine Pesos (e.g., P 278.80, PHP 278.80, 278.80)
    final amountRegex = RegExp(r'(?:P|PHP|₱)?\s?(\d{1,3}(?:,\d{3})*(?:\.\d{2}))');
    
    // Improved regex for PayMongo/GCash typical reference numbers
    // e.g., Ref: 2mK1j9r, Reference Number: 123456789, Payment ID: pay_...
    // This avoids matching "erence" from the word "Reference"
    final refRegex = RegExp(
      r'(?:Ref\w*|ID|Number|Link)\s+(?:No\.)?\s*:?\s*([a-zA-Z0-9_-]{5,50})',
      caseSensitive: false,
    );

    // Regex for PayMongo Payment ID (e.g., pay_hTPQJomoquN66wNxbfbjxhiJ)
    final paymentIdRegex = RegExp(
      r'(pay_[a-zA-Z0-9]{10,50})',
      caseSensitive: false,
    );

    // Check for "QRPh Payment Received!" confirmation text
    // Flexible matching: handles OCR variations like extra spaces, line breaks, case differences
    final qrphReceivedRegex = RegExp(
      r'QR\s*Ph\s+Payment\s+Received',
      caseSensitive: false,
    );

    // ── GCash-specific detections ──────────────────────────────────────────

    // "Sent via GCash" confirmation text
    // Flexible: handles OCR quirks like extra spaces, casing, line-break splits
    final sentViaGcashRegex = RegExp(
      r'Sent\s+via\s+GCash',
      caseSensitive: false,
    );

    // GCash Ref No. pattern — digits possibly separated by spaces
    // e.g., "Ref No. 2044 696 768752" or "Ref No. 2044696768752"
    final gcashRefRegex = RegExp(
      r'Ref\.?\s*(?:No\.?)?\s*:?\s*([\d\s]{8,30})',
      caseSensitive: false,
    );

    // Transaction date detection — e.g., "Sep 04, 2026", "September 4, 2026",
    // "09/04/2026", "2026-09-04", etc.
    final dateRegex = RegExp(
      r'(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+\d{1,2},?\s+\d{4}',
      caseSensitive: false,
    );
    // Also support numeric date formats: MM/DD/YYYY, DD/MM/YYYY, YYYY-MM-DD
    final numericDateRegex = RegExp(
      r'\b(\d{1,2}[/\-]\d{1,2}[/\-]\d{2,4}|\d{4}[/\-]\d{1,2}[/\-]\d{1,2})\b',
    );

    // ── Common detections ──────────────────────────────────────────────────

    final amounts = amountRegex.allMatches(text).map((m) => m.group(1)).toList();
    final refs = refRegex
        .allMatches(text)
        .map((m) => m.group(1))
        .where((r) => r != null && r.toLowerCase() != 'number' && r.toLowerCase() != 'reference')
        .toList();

    // Detect Payment ID (pay_xxx format) — PayMongo specific
    final paymentIdMatches = paymentIdRegex.allMatches(text).map((m) => m.group(1)).toList();
    final String? detectedPaymentId = paymentIdMatches.isNotEmpty ? paymentIdMatches.first : null;

    // Detect "QRPh Payment Received!" text — PayMongo specific
    final bool hasQrphReceived = qrphReceivedRegex.hasMatch(text);

    // Detect "Sent via GCash" text — GCash specific
    final bool hasSentViaGcash = sentViaGcashRegex.hasMatch(text);

    // Detect GCash Ref No. (digits with spaces)
    final gcashRefMatches = gcashRefRegex.allMatches(text).map((m) => m.group(1)?.trim()).toList();
    final String? detectedGcashRef = gcashRefMatches.isNotEmpty ? gcashRefMatches.first : null;

    // Detect transaction date
    String? detectedDate;
    bool dateIsValid = false;
    final dateMatches = dateRegex.allMatches(text);
    if (dateMatches.isNotEmpty) {
      detectedDate = dateMatches.first.group(0);
      dateIsValid = _isDateWithinRange(detectedDate!, 7);
    } else {
      final numDateMatches = numericDateRegex.allMatches(text);
      if (numDateMatches.isNotEmpty) {
        detectedDate = numDateMatches.first.group(0);
        dateIsValid = _isDateWithinRange(detectedDate!, 7);
      }
    }

    // In a receipt, the largest amount found is usually the Total Paid
    double? maxAmount;
    if (amounts.isNotEmpty) {
      for (var a in amounts) {
        final val = double.tryParse(a!.replaceAll(',', ''));
        if (val != null) {
          if (maxAmount == null || val > maxAmount) maxAmount = val;
        }
      }
    }

    return {
      'success': true,
      'fullText': text,
      'detectedAmount': maxAmount,
      'detectedRefs': refs,
      // PayMongo-specific
      'detectedPaymentId': detectedPaymentId,
      'hasQrphReceived': hasQrphReceived,
      // GCash-specific
      'hasSentViaGcash': hasSentViaGcash,
      'detectedGcashRef': detectedGcashRef,
      'detectedDate': detectedDate,
      'dateIsValid': dateIsValid,
      'isSuccess': true,
    };
  }

  /// Checks if a detected date string falls within ±[days] from today.
  /// Supports formats like "Sep 04, 2026", "September 4, 2026".
  static bool _isDateWithinRange(String dateStr, int days) {
    try {
      // Month name mapping
      const months = {
        'jan': 1, 'january': 1,
        'feb': 2, 'february': 2,
        'mar': 3, 'march': 3,
        'apr': 4, 'april': 4,
        'may': 5,
        'jun': 6, 'june': 6,
        'jul': 7, 'july': 7,
        'aug': 8, 'august': 8,
        'sep': 9, 'september': 9,
        'oct': 10, 'october': 10,
        'nov': 11, 'november': 11,
        'dec': 12, 'december': 12,
      };

      // Try parsing "Month DD, YYYY" format
      final namedDateRegex = RegExp(
        r'(\w+)\s+(\d{1,2}),?\s+(\d{4})',
        caseSensitive: false,
      );
      final match = namedDateRegex.firstMatch(dateStr);
      if (match != null) {
        final monthStr = match.group(1)!.toLowerCase();
        final day = int.parse(match.group(2)!);
        final year = int.parse(match.group(3)!);
        final month = months[monthStr];
        if (month != null) {
          final parsed = DateTime(year, month, day);
          final now = DateTime.now();
          final diff = now.difference(parsed).inDays.abs();
          return diff <= days;
        }
      }

      // Try parsing numeric formats: MM/DD/YYYY or YYYY-MM-DD
      final parts = dateStr.split(RegExp(r'[/\-]'));
      if (parts.length == 3) {
        int year, month, day;
        if (parts[0].length == 4) {
          // YYYY-MM-DD
          year = int.parse(parts[0]);
          month = int.parse(parts[1]);
          day = int.parse(parts[2]);
        } else {
          // MM/DD/YYYY
          month = int.parse(parts[0]);
          day = int.parse(parts[1]);
          year = int.parse(parts[2]);
          if (year < 100) year += 2000;
        }
        final parsed = DateTime(year, month, day);
        final now = DateTime.now();
        final diff = now.difference(parsed).inDays.abs();
        return diff <= days;
      }
    } catch (e) {
      debugPrint('Date parse error: $e');
    }
    return false;
  }
}
