import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to handle email verification for customer registration
/// Uses SendGrid SMTP via Supabase Edge Function
class EmailVerificationService {
  static final EmailVerificationService _instance =
      EmailVerificationService._internal();
  static final SupabaseClient _supabase = Supabase.instance.client;
  static final Random _random = Random();

  EmailVerificationService._internal();

  factory EmailVerificationService() {
    return _instance;
  }

  /// Generate a 6-digit OTP code
  String _generateOtpCode() {
    return (_random.nextInt(900000) + 100000).toString();
  }

  /// Send verification email with 6-digit OTP code
  /// Returns the 6-digit code if successful
  Future<String?> sendVerificationEmail({
    required String email,
    required String appName,
  }) async {
    try {
      // Generate a 6-digit OTP code
      final otpCode = _generateOtpCode();
      
      // Calculate expiration time (10 minutes from now)
      final createdAt = DateTime.now().toUtc();
      final expiresAt = createdAt.add(const Duration(minutes: 10));

      // Insert verification record into database
      await _supabase.from('email_verifications').insert({
        'id': _generateOtpCode(), // Use another code as ID
        'email': email.toLowerCase(),
        'verification_code': otpCode,
        'created_at': createdAt.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'is_used': false,
        'verified': false,
      });

      debugPrint('Verification record created for: $email');
      debugPrint('OTP Code: $otpCode');

      // Try to call Supabase Edge Function to send email via SendGrid
      try {
        final response = await _supabase.functions.invoke(
          'send-verification-email',
          body: {
            'email': email,
            'otpCode': otpCode,
            'appName': appName,
          },
        );
        debugPrint('Email sent response: $response');
      } catch (e) {
        // Edge Function might not be deployed yet - log but continue
        debugPrint('Edge Function not deployed or failed: $e');
        debugPrint('OTP Code generated for testing: $otpCode');
      }

      return otpCode;
    } catch (e) {
      debugPrint('Error sending verification email: $e');
      return null;
    }
  }

  /// Verify email using the 6-digit OTP code
  /// Returns true if verification is successful
  Future<bool> verifyEmail(String otpCode) async {
    try {
      // Find the verification record
      final response = await _supabase
          .from('email_verifications')
          .select()
          .eq('verification_code', otpCode)
          .single();

      if (response.isEmpty) {
        debugPrint('Invalid verification token');
        return false;
      }

      final verification = response as Map<String, dynamic>;
      final isUsed = verification['is_used'] as bool? ?? false;
      final expiresAt = DateTime.parse(verification['expires_at'] as String);
      final now = DateTime.now().toUtc();

      // Check if already used
      if (isUsed) {
        debugPrint('Verification token already used');
        return false;
      }

      // Check if expired
      if (now.isAfter(expiresAt)) {
        debugPrint('Verification token expired');
        return false;
      }

      // Mark as verified
      await _supabase
          .from('email_verifications')
          .update({
            'is_used': true,
            'verified': true,
            'verified_at': now.toIso8601String(),
          })
          .eq('verification_code', otpCode);

      debugPrint('Email verified successfully for: ${verification['email']}');
      return true;
    } catch (e) {
      debugPrint('Error verifying email: $e');
      return false;
    }
  }

  /// Check if an email is already verified
  Future<bool> isEmailVerified(String email) async {
    try {
      final response = await _supabase
          .from('email_verifications')
          .select()
          .eq('email', email.toLowerCase())
          .eq('verified', true)
          .eq('is_used', true)
          .order('verified_at', ascending: false)
          .limit(1);

      if (response.isEmpty) {
        return false;
      }

      // Check if the verification is still valid (not expired)
      final verification = response.first as Map<String, dynamic>;
      final expiresAt = DateTime.parse(verification['expires_at'] as String);
      final now = DateTime.now().toUtc();

      return !now.isAfter(expiresAt);
    } catch (e) {
      debugPrint('Error checking email verification status: $e');
      return false;
    }
  }

  /// Get the email associated with an OTP code
  Future<String?> getEmailByCode(String otpCode) async {
    try {
      final response = await _supabase
          .from('email_verifications')
          .select('email')
          .eq('verification_code', otpCode)
          .single();

      if (response.isEmpty) {
        return null;
      }

      return response['email'] as String?;
    } catch (e) {
      debugPrint('Error getting email by code: $e');
      return null;
    }
  }

  /// Clean up expired verification records (optional maintenance)
  Future<void> cleanupExpiredVerifications() async {
    try {
      final now = DateTime.now().toUtc();
      
      await _supabase
          .from('email_verifications')
          .delete()
          .lt('expires_at', now.toIso8601String());

      debugPrint('Expired verification records cleaned up');
    } catch (e) {
      debugPrint('Error cleaning up expired verifications: $e');
    }
  }
}
