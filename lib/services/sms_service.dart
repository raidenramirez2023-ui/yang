import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to handle SMS OTP Verification and Transactional SMS Notifications via PhilSMS API v3.
/// Credentials (API Token & Sender ID) are securely loaded from the database ('app_settings').
class SmsService {
  static final SmsService _instance = SmsService._internal();
  static final SupabaseClient _supabase = Supabase.instance.client;
  static final Random _random = Random();

  // PhilSMS API Endpoint (per Developers page: https://dashboard.philsms.com/api/v3/)
  static const String _apiEndpoint = 'https://dashboard.philsms.com/api/v3/sms/send';

  // In-memory cache for credentials
  String? _cachedApiToken;
  String? _cachedSenderId;
  bool? _cachedEnabled;
  DateTime? _lastConfigFetch;

  SmsService._internal();

  factory SmsService() => _instance;

  /// Fetch PhilSMS configuration securely from database ('app_settings')
  Future<void> _loadConfig({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _lastConfigFetch != null &&
        now.difference(_lastConfigFetch!).inMinutes < 10 &&
        _cachedApiToken != null) {
      return;
    }

    try {
      final rows = await _supabase
          .from('app_settings')
          .select('setting_key, setting_value')
          .inFilter('setting_key', [
        'philsms_api_token',
        'philsms_sender_id',
        'philsms_enabled',
      ]);

      for (var row in rows) {
        final key = row['setting_key'] as String;
        final val = row['setting_value']?.toString().trim() ?? '';
        if (key == 'philsms_api_token') {
          var token = val.trim();
          if (token.toLowerCase().startsWith('bearer ')) {
            token = token.substring(7).trim();
          }
          token = token
              .replaceAll('"', '')
              .replaceAll("'", '')
              .replaceAll('{', '')
              .replaceAll('}', '')
              .trim();
          _cachedApiToken = token;
        }
        if (key == 'philsms_sender_id') _cachedSenderId = val;
        if (key == 'philsms_enabled') _cachedEnabled = val.toLowerCase() == 'true';
      }

      _cachedSenderId ??= 'PhilSMS';
      _cachedEnabled ??= true;
      _lastConfigFetch = now;
      final tokenPreview = (_cachedApiToken != null && _cachedApiToken!.length > 8)
          ? '${_cachedApiToken!.substring(0, 4)}...${_cachedApiToken!.substring(_cachedApiToken!.length - 4)}'
          : 'empty';
      debugPrint('[SmsService] Config loaded. Enabled: $_cachedEnabled, Sender: $_cachedSenderId, Token preview: $tokenPreview');
    } catch (e) {
      debugPrint('[SmsService] Failed to load config from app_settings: $e');
      _cachedSenderId ??= 'PhilSMS';
      _cachedEnabled ??= true;
    }
  }

  /// Normalize any PH phone number into standard international format: '639XXXXXXXXX'
  String? formatPhoneNumber(String? rawPhone) {
    if (rawPhone == null) return null;
    final digits = rawPhone.replaceAll(RegExp(r'\D'), '');

    if (digits.startsWith('09') && digits.length == 11) {
      return '63${digits.substring(1)}';
    } else if (digits.startsWith('9') && digits.length == 10) {
      return '63$digits';
    } else if (digits.startsWith('639') && digits.length == 12) {
      return digits;
    } else if (digits.startsWith('6309') && digits.length == 13) {
      return '63${digits.substring(3)}';
    }

    return digits.isNotEmpty ? digits : null;
  }

  /// Send an outbound SMS message via PhilSMS API v3
  Future<Map<String, dynamic>> sendSms({
    required String recipient,
    required String message,
  }) async {
    final formattedRecipient = formatPhoneNumber(recipient);
    if (formattedRecipient == null || formattedRecipient.length != 12) {
      return {
        'success': false,
        'message': 'Invalid Philippine phone number format ($recipient). Must be 09XXXXXXXXX.',
      };
    }

    await _loadConfig();

    if (_cachedEnabled == false) {
      debugPrint('[SmsService] SMS is disabled in app_settings.');
      return {
        'success': false,
        'message': 'SMS notifications are currently disabled.',
      };
    }

    if (_cachedApiToken == null ||
        _cachedApiToken!.isEmpty ||
        _cachedApiToken == 'YOUR_PHIL_SMS_API_TOKEN_HERE') {
      debugPrint('[SmsService] Missing or placeholder PhilSMS API Token in app_settings.');
      return {
        'success': false,
        'message': 'PhilSMS API Token not yet configured in database.',
      };
    }

    try {
      final cleanMessage = message
          .replaceAll('•', '-')
          .replaceAll('—', '-')
          .replaceAll('–', '-')
          .replaceAll('“', '"')
          .replaceAll('”', '"')
          .replaceAll('’', "'")
          .replaceAll('‘', "'");

      final payload = {
        'recipient': formattedRecipient,
        'sender_id': _cachedSenderId ?? 'PhilSMS',
        'type': 'plain',
        'message': cleanMessage,
      };

      debugPrint('[SmsService] Sending SMS to $formattedRecipient (length: ${cleanMessage.length})...');

      final response = await http.post(
        Uri.parse(_apiEndpoint),
        headers: {
          'Authorization': 'Bearer $_cachedApiToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );

      debugPrint('[SmsService] Response code: ${response.statusCode}, body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          final status = decoded['status']?.toString().toLowerCase();
          if (status == 'error' || status == 'failed') {
            return {
              'success': false,
              'message': decoded['message'] ?? 'PhilSMS error: ${response.body}',
              'data': decoded,
            };
          }
        }
        return {
          'success': true,
          'message': 'SMS sent successfully.',
          'data': decoded,
        };
      } else {
        return {
          'success': false,
          'message': 'PhilSMS error (${response.statusCode}): ${response.body}',
        };
      }
    } catch (e) {
      debugPrint('[SmsService] Exception sending SMS: $e');
      return {
        'success': false,
        'message': 'Failed to send SMS: $e',
      };
    }
  }

  // ===========================================================================
  // OTP PHONE VERIFICATION
  // ===========================================================================

  /// Generate a random 6-digit numeric OTP code
  String _generateOtpCode() {
    return (_random.nextInt(900000) + 100000).toString();
  }

  /// Send an OTP code to a customer's phone number
  Future<Map<String, dynamic>> sendOtp(String rawPhone) async {
    final phone = formatPhoneNumber(rawPhone);
    if (phone == null || phone.length != 12) {
      return {
        'success': false,
        'message': 'Please enter a valid 11-digit mobile number starting with 09.',
      };
    }

    final otpCode = _generateOtpCode();
    final createdAt = DateTime.now().toUtc();
    final expiresAt = createdAt.add(const Duration(minutes: 10));

    try {
      // 1. Insert verification token into phone_verifications table
      await _supabase.from('phone_verifications').insert({
        'phone': phone,
        'verification_code': otpCode,
        'created_at': createdAt.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'is_used': false,
        'attempts': 0,
      });

      // 2. Dispatch SMS via PhilSMS
      final smsBody =
          'Yang Chow: Your 6-digit verification code is $otpCode. Valid for 10 minutes. Please do not share this code with anyone.';

      final smsResult = await sendSms(
        recipient: phone,
        message: smsBody,
      );

      if (smsResult['success'] == true) {
        return {
          'success': true,
          'message': 'Verification code sent to $rawPhone',
          'otp': kDebugMode ? otpCode : null,
        };
      } else {
        // Return clear error if SMS sending fails
        return {
          'success': false,
          'message': smsResult['message'] ?? 'Failed to send SMS.',
          'otp': kDebugMode ? otpCode : null, // useful for offline debugging
        };
      }
    } catch (e) {
      debugPrint('[SmsService] Error creating OTP record: $e');
      return {
        'success': false,
        'message': 'Failed to initialize verification: $e',
      };
    }
  }

  /// Verify the OTP code entered by the user
  Future<Map<String, dynamic>> verifyOtp({
    required String rawPhone,
    required String otpCode,
    String? userId,
  }) async {
    final phone = formatPhoneNumber(rawPhone);
    if (phone == null) {
      return {'success': false, 'message': 'Invalid phone number.'};
    }

    final trimmedOtp = otpCode.trim();
    if (trimmedOtp.length != 6) {
      return {'success': false, 'message': 'Please enter a valid 6-digit code.'};
    }

    try {
      // Find latest unexpired, unused verification code for this phone
      final record = await _supabase
          .from('phone_verifications')
          .select()
          .eq('phone', phone)
          .eq('verification_code', trimmedOtp)
          .eq('is_used', false)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (record == null) {
        return {
          'success': false,
          'message': 'Incorrect verification code. Please check and try again.',
        };
      }

      final expiresAt = DateTime.parse(record['expires_at'] as String);
      if (DateTime.now().toUtc().isAfter(expiresAt)) {
        return {
          'success': false,
          'message': 'This code has already expired. Please request a new one.',
        };
      }

      // Mark code as used
      await _supabase
          .from('phone_verifications')
          .update({'is_used': true})
          .eq('id', record['id']);

      // Mark user as phone verified in database
      final currentUserId = userId ?? _supabase.auth.currentUser?.id;
      if (currentUserId != null) {
        // Update users table
        await _supabase.from('users').update({
          'is_phone_verified': true,
          'phone': rawPhone.trim(),
        }).eq('id', currentUserId);

        // Also update Auth user metadata for consistency
        try {
          await _supabase.auth.updateUser(
            UserAttributes(data: {
              'is_phone_verified': true,
              'phone': rawPhone.trim(),
            }),
          );
        } catch (authErr) {
          debugPrint('[SmsService] Metadata update warning: $authErr');
        }
      }

      return {
        'success': true,
        'message': 'Mobile number successfully verified!',
      };
    } catch (e) {
      debugPrint('[SmsService] Exception during OTP verification: $e');
      return {
        'success': false,
        'message': 'Verification failed: $e',
      };
    }
  }

  /// Check if the currently logged-in user has verified their phone number
  Future<bool> isCurrentUserPhoneVerified() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    // Check user metadata first for fast response
    final metaVerified = user.userMetadata?['is_phone_verified'];
    if (metaVerified == true) return true;

    try {
      final data = await _supabase
          .from('users')
          .select('is_phone_verified')
          .eq('id', user.id)
          .maybeSingle();

      return data?['is_phone_verified'] == true;
    } catch (e) {
      debugPrint('[SmsService] Error checking phone verification status: $e');
      return false;
    }
  }

  // ===========================================================================
  // TRANSACTIONAL SMS NOTIFICATIONS
  // ===========================================================================

  /// Send SMS when a reservation is confirmed/approved
  Future<bool> sendReservationConfirmedSms({
    required String phone,
    required String customerName,
    required String reservationCode,
    required String eventDate,
    required String startTime,
  }) async {
    final body =
        'Hi $customerName! Your reservation ($reservationCode) for $eventDate at $startTime is CONFIRMED at Yang Chow. We look forward to hosting you!';
    final res = await sendSms(recipient: phone, message: body);
    return res['success'] == true;
  }

  /// Send SMS when reservation status is updated
  Future<bool> sendReservationStatusSms({
    required String phone,
    required String customerName,
    required String reservationCode,
    required String status,
    String? reason,
  }) async {
    String body;
    if (status.toLowerCase() == 'declined' || status.toLowerCase() == 'rejected') {
      body =
          'Hi $customerName, your reservation ($reservationCode) was not approved.${reason != null && reason.isNotEmpty ? " Reason: $reason." : ""} Please contact us for questions.';
    } else {
      body =
          'Hi $customerName, your reservation ($reservationCode) status has been updated to: ${status.toUpperCase()}. Thank you! - Yang Chow';
    }

    final res = await sendSms(recipient: phone, message: body);
    return res['success'] == true;
  }

  /// Send Payment Reminder ("Need to Pay") SMS
  Future<bool> sendPaymentReminderSms({
    required String phone,
    required String customerName,
    required String reservationCode,
    required double amount,
    String? deadline,
  }) async {
    final body =
        'Hi $customerName, reminder to settle your balance of PHP ${amount.toStringAsFixed(2)} for reservation $reservationCode${deadline != null ? " by $deadline" : ""}. Disregard if paid. - Yang Chow';
    final res = await sendSms(recipient: phone, message: body);
    return res['success'] == true;
  }

  /// Send Advance Order status update SMS
  Future<bool> sendAdvanceOrderStatusSms({
    required String phone,
    required String customerName,
    required String orderId,
    required String status,
  }) async {
    final body =
        'Hi $customerName, your advance order ($orderId) is now ${status.toUpperCase()}. Thank you for choosing Yang Chow!';
    final res = await sendSms(recipient: phone, message: body);
    return res['success'] == true;
  }
}
