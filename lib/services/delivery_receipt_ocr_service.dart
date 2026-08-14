import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:yang_chow/services/app_settings_service.dart';

class DeliveryReceiptOcrService {
  static String get _apiKey => AppSettingsService().getOcrApiKey();
  static const String _apiUrl = 'https://api.ocr.space/parse/image';

  /// Standard unit mappings including common OCR misreads / abbreviations
  static const Map<String, String> _unitMap = {
    'gram': 'Gram',
    'grams': 'Gram',
    'gm': 'Gram',
    'g': 'Gram',
    'ml': 'Ml',
    'mL': 'Ml',
    'ML': 'Ml',
    'milliliter': 'Ml',
    'milliliters': 'Ml',
    'kilo': 'Kilo',
    'kilos': 'Kilo',
    'kg': 'Kilo',
    'kgs': 'Kilo',
    'kilograms': 'Kilo',
    '/ilo': 'Kilo',
    'ilo': 'Kilo',
    'klo': 'Kilo',
    'bot': 'Bot',
    'bottle': 'Bot',
    'bottles': 'Bot',
    'btl': 'Bot',
    'pack': 'Pack',
    'packs': 'Pack',
    'pck': 'Pack',
    'pcs': 'Pcs',
    'pc': 'Pcs',
    'piece': 'Pcs',
    'pieces': 'Pcs',
    'can': 'Can',
    'cans': 'Can',
    'box': 'Box',
    'boxes': 'Box',
    'bx': 'Box',
    'sack': 'Sack',
    'sacks': 'Sack',
    'bag': 'Bag',
    'bags': 'Bag',
    'liter': 'Liter',
    'liters': 'Liter',
    'l': 'Liter',
    'gallon': 'Gallon',
    'gallons': 'Gallon',
    'gal': 'Gallon',
  };

  /// Header/label words to skip
  static final RegExp _headerRegex = RegExp(
    r'(quantity|unit|item\s*name|total|date|receipt|invoice|delivery|no\.|#)',
    caseSensitive: false,
  );

  /// Parse a delivery receipt file (image or PDF) and extract items.
  static Future<Map<String, dynamic>> parseDeliveryReceipt({
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    try {
      final ext = fileName.split('.').last.toLowerCase();
      String mimeType;
      String fileType;

      switch (ext) {
        case 'pdf':
          mimeType = 'application/pdf';
          fileType = 'PDF';
          break;
        case 'jpg':
        case 'jpeg':
        case 'jfif':
          mimeType = 'image/jpeg';
          fileType = 'JPG';
          break;
        case 'png':
          mimeType = 'image/png';
          fileType = 'PNG';
          break;
        default:
          mimeType = 'image/png';
          fileType = 'PNG';
      }

      final base64String = base64Encode(fileBytes);
      final base64WithPrefix = 'data:$mimeType;base64,$base64String';

      final response = await http.post(
        Uri.parse(_apiUrl),
        body: {
          'apikey': _apiKey,
          'base64Image': base64WithPrefix,
          'language': 'eng',
          'isOverlayRequired': 'false',
          'isTable': 'true',
          'filetype': fileType,
          'OCREngine': '2', // Engine 2 is better for handwriting & receipts
          'detectOrientation': 'true', // Auto-rotate if image is sideways
          'scale': 'true', // Auto-upscale low-resolution / small images
        },
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['OCRExitCode'] == 1 || data['OCRExitCode'] == 2) {
          final String fullText = data['ParsedResults']?[0]?['ParsedText'] ?? '';
          
          if (fullText.trim().isEmpty) {
            return {
              'success': false,
              'error': 'No text could be read from the uploaded file. Please ensure the receipt is clear and readable.',
            };
          }

          debugPrint('OCR Full Text:\n$fullText');
          final parsedResult = _parseDeliveryItems(fullText);

          if (parsedResult['items'].isEmpty) {
            return {
              'success': false,
              'error': 'Could not identify any items from the receipt. Raw text detected:\n$fullText',
            };
          }

          return {
            'success': true,
            'items': parsedResult['items'],
            'supplier': parsedResult['supplier'],
            'rawText': fullText,
          };
        } else {
          final errorMsg = data['ErrorMessage'] ?? 
              (data['ParsedResults']?[0]?['ErrorMessage']) ?? 
              'OCR processing failed';
          return {'success': false, 'error': errorMsg.toString()};
        }
      }
      return {'success': false, 'error': 'Server Error: ${response.statusCode}'};
    } catch (e) {
      debugPrint('Delivery Receipt OCR Error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Parse OCR text into items and detected supplier
  static Map<String, dynamic> _parseDeliveryItems(String text) {
    final List<Map<String, dynamic>> items = [];
    String? detectedSupplier;
    
    final normalizedText = text
        .replaceAll('\t', '  ')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');

    final lines = normalizedText.split('\n');

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // Check for Supplier line
      final supplierMatch = RegExp(r'SUPPLIER\s*:\s*(.+)$', caseSensitive: false).firstMatch(line);
      if (supplierMatch != null) {
        detectedSupplier = supplierMatch.group(1)?.trim();
        continue;
      }

      // Skip header lines (unless it starts with a number or digit-like token)
      if (_headerRegex.hasMatch(line) && !RegExp(r'^[0-9/|!lLiI]').hasMatch(line)) continue;

      // Skip lines that are just scribbles/symbols (e.g. @@@, ###, ---, ***)
      final letterCount = RegExp(r'[a-zA-Z]').allMatches(line).length;
      final digitCount = RegExp(r'[0-9]').allMatches(line).length;
      if (letterCount == 0 && digitCount == 0) continue;

      final parsed = _parseLine(line);
      if (parsed != null) {
        items.add(parsed);
      }
    }

    return {
      'items': items,
      'supplier': detectedSupplier,
    };
  }

  /// Parse a single line to extract quantity, unit, and item name
  static Map<String, dynamic>? _parseLine(String line) {
    String cleaned = line
        .replaceAll('|', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // 1. Normalize handwritten numbers at start of line
    // e.g. "/00" -> "100", "l00" -> "100", "I00" -> "100", "|00" -> "100", "10O" -> "100"
    cleaned = _normalizeLeadingQuantity(cleaned);

    // 2. Extract quantity (digits at the start)
    int quantity = 1;
    String remaining = cleaned;

    final qtyMatch = RegExp(r'^(\d+)\s*(.*)$').firstMatch(cleaned);
    if (qtyMatch != null) {
      final parsedQty = int.tryParse(qtyMatch.group(1) ?? '');
      if (parsedQty != null && parsedQty > 0) {
        quantity = parsedQty;
        remaining = qtyMatch.group(2)?.trim() ?? '';
      }
    }

    if (remaining.isEmpty) return null;

    // 3. Extract unit (first token after quantity or inline unit)
    String? detectedUnit;
    String itemName = remaining;

    final tokens = remaining.split(' ');
    if (tokens.isNotEmpty) {
      final firstTokenClean = tokens[0].toLowerCase().replaceAll(RegExp(r'[^a-z/]'), '');
      if (_unitMap.containsKey(firstTokenClean)) {
        detectedUnit = _unitMap[firstTokenClean];
        itemName = tokens.sublist(1).join(' ').trim();
      }
    }

    // If unit was not at the start, check if any known unit keyword is in the text
    if (detectedUnit == null) {
      for (final entry in _unitMap.entries) {
        final pattern = RegExp(r'\b' + RegExp.escape(entry.key) + r'\b', caseSensitive: false);
        if (pattern.hasMatch(itemName)) {
          detectedUnit = entry.value;
          itemName = itemName.replaceFirst(pattern, '').trim();
          break;
        }
      }
    }

    // 4. Clean up item name
    itemName = itemName
        .replaceAll(RegExp(r'^[^\w]+'), '') // strip leading non-alphanumeric
        .replaceAll(RegExp(r'[^\w]+$'), '') // strip trailing non-alphanumeric
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Skip scribbles, single letters, or pure number lines
    if (itemName.isEmpty || itemName.length < 2) return null;
    if (RegExp(r'^\d+$').hasMatch(itemName)) return null;

    // Skip if it only contains gibberish symbols
    final letters = RegExp(r'[a-zA-Z]').allMatches(itemName).length;
    if (letters < 2) return null;

    return {
      'quantity': quantity,
      'unit': detectedUnit ?? 'Pcs',
      'name': itemName,
    };
  }

  /// Converts handwritten OCR number misreadings (e.g. /00, l00, I00, 10O) into clean digits
  static String _normalizeLeadingQuantity(String text) {
    final match = RegExp(r'^([/|!lLiIoO0-9]{1,6})\s+(.+)$').firstMatch(text);
    if (match != null) {
      final token = match.group(1)!;
      final rest = match.group(2)!;

      // Convert characters that look like 1 or 0
      final converted = token
          .replaceAll(RegExp(r'[/|!lLiI]'), '1')
          .replaceAll(RegExp(r'[oO]'), '0');

      if (RegExp(r'^\d+$').hasMatch(converted)) {
        final val = int.tryParse(converted);
        if (val != null && val > 0 && val <= 99999) {
          return '$converted $rest';
        }
      }
    }
    return text;
  }

  /// Calculates similarity between two strings (0.0 to 1.0)
  static double calculateSimilarity(String s1, String s2) {
    final a = s1.toLowerCase().trim();
    final b = s2.toLowerCase().trim();

    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    // Substring match gives high score
    if (a.contains(b) || b.contains(a)) {
      final shorter = a.length < b.length ? a.length : b.length;
      final longer = a.length > b.length ? a.length : b.length;
      return (shorter / longer) * 0.95;
    }

    // Token-based Jaccard similarity
    final wordsA = a.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toSet();
    final wordsB = b.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toSet();
    final intersection = wordsA.intersection(wordsB).length;
    final union = wordsA.union(wordsB).length;
    final jaccard = union > 0 ? (intersection / union) : 0.0;

    // Levenshtein distance
    final lev = _levenshteinDistance(a, b);
    final maxLen = a.length > b.length ? a.length : b.length;
    final levScore = maxLen > 0 ? (1.0 - (lev / maxLen)) : 0.0;

    return (jaccard * 0.4) + (levScore * 0.6);
  }

  static int _levenshteinDistance(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        int cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = [
          v1[j] + 1,
          v0[j + 1] + 1,
          v0[j] + cost,
        ].reduce((min, val) => val < min ? val : min);
      }
      for (int j = 0; j <= t.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[t.length];
  }
}
