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
      final response = await http.post(
        Uri.parse(_apiUrl),
        body: {
          'apikey': _apiKey,
          'url': imageUrl,
          'language': 'eng',
          'isOverlayRequired': 'false',
          'isTable': 'true',
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

    final amounts = amountRegex.allMatches(text).map((m) => m.group(1)).toList();
    final refs = refRegex
        .allMatches(text)
        .map((m) => m.group(1))
        .where((r) => r != null && r.toLowerCase() != 'number' && r.toLowerCase() != 'reference')
        .toList();

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
      'isSuccess': true,
    };
  }
}
