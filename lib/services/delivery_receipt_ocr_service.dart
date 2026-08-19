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
  /// Strict boilerplate & header/footer filter to prevent non-inventory text from being parsed
  static bool _isBoilerplateOrHeaderLine(String line) {
    final l = line.toLowerCase().trim();
    if (l.isEmpty) return true;

    // Restaurant & Document Headers
    if (l.contains('yang chow') || l.contains('restaurant') || l.contains('pagsanjan')) return true;
    if (l.contains('purchase order') || l.contains('delivery receipt') || l.contains('sales invoice') || l.contains('billing invoice')) return true;
    if (l.contains('procurement') || l.contains('delivery location') || l.contains('inventory &') || l.contains('branch')) return true;
    if (l.contains('item description') || l.contains('category /') || l.contains('current stock') || l.contains('order qty') || l.contains('qty & unit')) return true;
    if (l.contains('po #') || l.contains('po:') || l.contains('po-') || l.contains('dr #') || l.contains('dr:') || l.contains('date:')) return true;

    // Footers, Signatures & Remarks
    if (l.contains('prepared') || l.contains('verified by') || l.contains('acknowledged by')) return true;
    if (l.contains('signature') || l.contains('printed name') || l.contains('received by') || l.contains('delivered by')) return true;
    if (l.contains('target delivery') || l.contains('please acknowledge') || l.contains('thank you') || l.contains('authorized by')) return true;
    if (l.contains('combined suppliers') || l.contains('combined restaurant') || l.contains('delivery address')) return true;
    // Standalone Supplier / Category phrases (NOT food items)
    if (l == 'fresh produce' || l == 'public market' || l == 'poultry & meat supplier' || l == 'metro wholesale' || l == 'beverage distributor' || l == 'packaging & supplies' || l == 'seafood & fish dealer') return true;
    if (l == 'fresh' || l == 'market' || l == 'produce' || l == 'supplier' || l == 'groceries' || l == 'vendor' || l == 'dealer' || l == 'distributor') return true;

    return false;
  }

  /// Parse OCR text into items and detected supplier
  static Map<String, dynamic> _parseDeliveryItems(String text) {
    final Map<String, Map<String, dynamic>> dedupedItems = {};
    String? detectedSupplier;

    final normalizedText = text
        .replaceAll('\t', '  ')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');

    final lines = normalizedText.split('\n');

    // Pass 1: Extract Supplier / Vendor from header (same line or next line)
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final headerPattern = RegExp(r'(?:SUPPLIER\s*(?:/\s*VENDOR)?|VENDOR)\s*:', caseSensitive: false);
      if (headerPattern.hasMatch(line)) {
        final supplierMatch = RegExp(r'(?:SUPPLIER\s*(?:/\s*VENDOR)?|VENDOR)\s*:\s*(.+)$', caseSensitive: false).firstMatch(line);
        String rawSup = supplierMatch?.group(1)?.trim() ?? '';
        
        // If empty on same line, inspect the next line!
        if (rawSup.isEmpty && i + 1 < lines.length) {
          rawSup = lines[i + 1].trim();
        }

        rawSup = rawSup
            .replaceAll(RegExp(r'\b(PREPARED BY|DELIVERY LOCATION|TARGET DELIVERY|PO #|DATE).*$', caseSensitive: false), '')
            .replaceAll(RegExp(r'[:#*_-]+$'), '')
            .trim();
        if (rawSup.isNotEmpty && rawSup.length >= 2 && !_isBoilerplateOrHeaderLine(rawSup)) {
          detectedSupplier = rawSup;
          break;
        }
      }
    }

    // Pass 2: Parse table rows & items
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // Skip Supplier header line
      if (RegExp(r'SUPPLIER\s*(?:/\s*VENDOR)?\s*:', caseSensitive: false).hasMatch(line)) continue;

      // Skip document boilerplate, headers, footers & signatures
      if (_isBoilerplateOrHeaderLine(line)) continue;

      // Skip lines that are just scribbles/symbols (e.g. @@@, ###, ---, ***)
      final letterCount = RegExp(r'[a-zA-Z]').allMatches(line).length;
      final digitCount = RegExp(r'[0-9]').allMatches(line).length;
      if (letterCount == 0 && digitCount == 0) continue;

      final parsed = _parseLine(line, detectedSupplier: detectedSupplier);
      if (parsed != null) {
        final nameKey = (parsed['name'] ?? '').toString().toLowerCase().trim();
        if (nameKey.isNotEmpty && !_isBoilerplateOrHeaderLine(nameKey)) {
          // If already encountered, keep the one with higher/actual quantity
          if (dedupedItems.containsKey(nameKey)) {
            final existingQty = dedupedItems[nameKey]!['quantity'] as int? ?? 0;
            final newQty = parsed['quantity'] as int? ?? 0;
            if (newQty > existingQty) {
              dedupedItems[nameKey] = parsed;
            }
          } else {
            dedupedItems[nameKey] = parsed;
          }
        }
      }
    }

    return {
      'items': dedupedItems.values.toList(),
      'supplier': detectedSupplier,
    };
  }

  /// Parse a single line to extract quantity, unit, and item name cleanly
  static Map<String, dynamic>? _parseLine(String line, {String? detectedSupplier}) {
    String cleaned = line
        .replaceAll('|', ' ')
        .replaceAll(RegExp(r'[*_#]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleaned.isEmpty || _isBoilerplateOrHeaderLine(cleaned)) return null;

    // Strip detected supplier if embedded in the table row
    if (detectedSupplier != null && detectedSupplier.trim().isNotEmpty) {
      final supPattern = RegExp(r'\b' + RegExp.escape(detectedSupplier.trim()) + r'\b', caseSensitive: false);
      cleaned = cleaned.replaceAll(supPattern, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    // Pattern 0: PO Table Row with (optional index) Item + (optional Supplier/Category) + CurrentStock + OrderQty + Unit
    // e.g. "TEST1 TESTLORD 0 20 kilo" or "1 MAKARONI Poultry & Meat 0 10 pcs" or "Patatim 0 10 pcs"
    final poTableRowMatch = RegExp(
      r"^(?:\d+[\.\)]?\s+)?([\w\s/&'\-]+?)\s+(?:(?:[a-zA-Z\s/&'\-]+?\s+)?(?:\d+(?:\.\d+)?\s+))(\d+(?:\.\d+)?)\s*([a-zA-Z]*)$",
      caseSensitive: false,
    ).firstMatch(cleaned);
    if (poTableRowMatch != null) {
      final rawName = poTableRowMatch.group(1)?.trim() ?? '';
      final rawQty = double.tryParse(poTableRowMatch.group(2) ?? '') ?? 1.0;
      final rawUnit = poTableRowMatch.group(3)?.trim() ?? '';

      final cleanedName = _cleanItemName(rawName);
      if (cleanedName.length >= 2 && !_isBoilerplateOrHeaderLine(cleanedName)) {
        return {
          'name': cleanedName,
          'quantity': rawQty.toInt() > 0 ? rawQty.toInt() : 1,
          'unit': _resolveUnit(rawUnit) ?? 'Pcs',
        };
      }
    }

    // Pattern 1: Table row with row index: e.g. "1 Patatim Poultry & Meat Supplier 0 10" or "1 Patatim 900" or "1. Patatim -> 10 pcs"
    final tableRowMatch = RegExp(r"^\d+[\.\)]?\s+([\w\s/&'\-]+?)\s+(?:(?:poultry|meat|produce|market|wholesale|groceries|distributor|dealer|supplier|general|roasting|seafood|fresh|fruits|vegetables|beverage|condiments)\b.*?\s+)?(?:\d+\s+)?(\d+(?:\.\d+)?)\s*([a-zA-Z]*)$", caseSensitive: false).firstMatch(cleaned);
    if (tableRowMatch != null) {
      final rawName = tableRowMatch.group(1)?.trim() ?? '';
      final rawQty = double.tryParse(tableRowMatch.group(2) ?? '') ?? 1.0;
      final rawUnit = tableRowMatch.group(3)?.trim() ?? '';

      final cleanedName = _cleanItemName(rawName);
      if (cleanedName.length >= 2 && !_isBoilerplateOrHeaderLine(cleanedName)) {
        return {
          'name': cleanedName,
          'quantity': rawQty.toInt() > 0 ? rawQty.toInt() : 1,
          'unit': _resolveUnit(rawUnit) ?? 'Pcs',
        };
      }
    }

    // Pattern 2: Arrow / Dash pattern: e.g. "Patatim -> 10 pcs" or "Patatim - 10 kg" or "1. Patatim ➔ 10 pcs"
    final arrowMatch = RegExp(r"^(.+?)\s*(?:->|➔|=>|-|:)\s*(\d+(?:\.\d+)?)\s*([a-zA-Z]*)(?:\s*\(.*\))?$", caseSensitive: false).firstMatch(cleaned);
    if (arrowMatch != null) {
      String rawName = arrowMatch.group(1)?.trim() ?? '';
      rawName = rawName.replaceFirst(RegExp(r'^\d+[\.\)]?\s*'), '');

      final rawQty = double.tryParse(arrowMatch.group(2) ?? '') ?? 1.0;
      final rawUnit = arrowMatch.group(3)?.trim() ?? '';

      final cleanedName = _cleanItemName(rawName);
      if (cleanedName.length >= 2 && !_isBoilerplateOrHeaderLine(cleanedName)) {
        return {
          'name': cleanedName,
          'quantity': rawQty.toInt() > 0 ? rawQty.toInt() : 1,
          'unit': _resolveUnit(rawUnit) ?? 'Pcs',
        };
      }
    }

    // Pattern 3: Trailing Quantity Format: e.g. "Patatim 10 pcs" or "TEST1 20 kilo" or "Yangchow with Rice 5 order"
    final trailingQtyMatch = RegExp(r"^([\w\s/&'\-]+?)\s+(\d+(?:\.\d+)?)\s*([a-zA-Z]*)$").firstMatch(cleaned);
    if (trailingQtyMatch != null) {
      final rawName = trailingQtyMatch.group(1)?.trim() ?? '';
      final rawQty = double.tryParse(trailingQtyMatch.group(2) ?? '') ?? 1.0;
      final rawUnit = trailingQtyMatch.group(3)?.trim() ?? '';

      final cleanedName = _cleanItemName(rawName);
      if (cleanedName.length >= 2 && !_isBoilerplateOrHeaderLine(cleanedName)) {
        return {
          'name': cleanedName,
          'quantity': rawQty.toInt() > 0 ? rawQty.toInt() : 1,
          'unit': _resolveUnit(rawUnit) ?? 'Pcs',
        };
      }
    }

    // Pattern 4: Leading Quantity Format: e.g. "10 pcs Patatim" or "20 kilo Chicken"
    cleaned = _normalizeLeadingQuantity(cleaned);
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

    // Extract unit
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

    // Clean up item name
    itemName = _cleanItemName(itemName);

    // Skip scribbles, single letters, or pure number lines
    if (itemName.isEmpty || itemName.length < 2 || _isBoilerplateOrHeaderLine(itemName)) return null;
    if (RegExp(r'^\d+$').hasMatch(itemName)) return null;

    final letters = RegExp(r'[a-zA-Z]').allMatches(itemName).length;
    if (letters < 2) return null;

    return {
      'quantity': quantity,
      'unit': detectedUnit ?? 'Pcs',
      'name': itemName,
    };
  }

  static String _cleanItemName(String name) {
    return name
        .replaceAll(RegExp(r'^\d+[\.\)]?\s*'), '') // Strip row numbers like "1." or "2)"
        .replaceAll(RegExp(r'\b(poultry|meat supplier|fresh produce|public market|metro wholesale|distributor|dealer|supplier|groceries|condiments|beverage|produce|prepared by|delivery location|unlisted)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+\d+(?:\.\d+)?\s*(?:kilo|kg|g|gram|pcs|pc|pack|can|bot|order|box|roll)?$', caseSensitive: false), '') // strip trailing numbers/stock
        .replaceAll(RegExp(r'^[^\w]+'), '') // strip leading non-alphanumeric
        .replaceAll(RegExp(r'[^\w]+$'), '') // strip trailing non-alphanumeric
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String? _resolveUnit(String raw) {
    final clean = raw.toLowerCase().replaceAll(RegExp(r'[^a-z/]'), '');
    return _unitMap[clean];
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

    final normA = a.replaceAll(RegExp(r'\s+'), '');
    final normB = b.replaceAll(RegExp(r'\s+'), '');
    if (normA == normB) return 0.99;

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
