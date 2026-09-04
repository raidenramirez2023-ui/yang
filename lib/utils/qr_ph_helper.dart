import 'dart:convert';

/// Helper utility for generating Philippine National Standard (QR Ph / EMVCo)
/// Dynamic QR codes with pre-filled transaction amounts.
class QrPhHelper {
  // YangChow QR Ph Base Data extracted from assets/images/newgcash.png (InstaPay / P2P QR Pay)
  static const String _merchantInfo =
      '27830012com.p2pqrpay0111GXCHPHM2XXX02089996440303152170200000006560417DWQM4TK3JDO0J6AGX';
  static const String _mcc = '52046016';
  static const String _currency = '5303608'; // 608 = Philippine Peso (PHP ISO 4217)
  static const String _country = '5802PH';
  static const String _merchantName = '5908YangChow';
  static const String _city = '6010Pagsawitan';
  static const String _postalCode = '61041234';

  /// Generates a valid dynamic QR Ph (EMVCo) string with the exact transaction amount embedded.
  /// When scanned using GCash, Maya, or any QR Ph bank app, the amount is automatically pre-filled!
  static String generateDynamicQrPh({required double amount}) {
    // If amount is 0 or less, fall back to static QR (010211) without Tag 54
    if (amount <= 0) {
      return generateStaticQrPh();
    }

    final amountStr = amount.toStringAsFixed(2);
    final lenStr = amountStr.length.toString().padLeft(2, '0');
    // Tag 54: Transaction Amount
    final amountTag = '54$lenStr$amountStr';

    // Tag 01: 12 = Dynamic QR Code
    final payloadWithoutCrc =
        '000201010212$_merchantInfo$_mcc$_currency$amountTag$_country$_merchantName$_city$_postalCode'
        '6304';

    final crc = _crc16Ccitt(utf8.encode(payloadWithoutCrc));
    final crcHex = crc.toRadixString(16).toUpperCase().padLeft(4, '0');

    return '$payloadWithoutCrc$crcHex';
  }

  /// Returns the original static QR Ph string (where customer manually enters the amount).
  static String generateStaticQrPh() {
    return '00020101021127830012com.p2pqrpay0111GXCHPHM2XXX02089996440303152170200000006560417DWQM4TK3JDO0J6AGX5204601653036085802PH5908YangChow6010Pagsawitan6104123463047221';
  }

  /// Computes CRC-16/CCITT-FALSE (Polynomial: 0x1021, Initial: 0xFFFF)
  /// as required by the EMVCo QR Code Specification.
  static int _crc16Ccitt(List<int> bytes) {
    int crc = 0xFFFF;
    for (final byte in bytes) {
      crc ^= (byte << 8);
      for (int i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    return crc;
  }
}
