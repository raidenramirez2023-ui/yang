import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Unified Email Service for Customer Registration and Password Reset
/// Uses SendGrid SMTP for actual email sending
class UnifiedEmailService {
  static final UnifiedEmailService _instance =
      UnifiedEmailService._internal();
  static final SupabaseClient _supabase = Supabase.instance.client;

  UnifiedEmailService._internal();

  factory UnifiedEmailService() {
    return _instance;
  }

  /// Send welcome email after customer registration
  Future<bool> sendCustomerWelcomeEmail({
    required String customerEmail,
    required String customerName,
  }) async {
    try {
      // Log email intent
      await _supabase.from('email_logs').insert({
        'recipient_email': customerEmail,
        'subject': 'Welcome to Yang Chow Restaurant!',
        'email_type': 'customer_welcome',
        'status': 'sent',
      });

      // Send actual email via SendGrid SMTP
      final response = await _supabase.functions.invoke('send-email', body: {
        'to': customerEmail,
        'subject': 'Welcome to Yang Chow Restaurant!',
        'htmlBody': _buildCustomerWelcomeBody(customerName: customerName),
        'from': 'noreply@yangchowrestaurant.com',
      });

      debugPrint('Welcome email sent to: $customerEmail');
      debugPrint('Response: $response');
      
      return true;
    } catch (e) {
      debugPrint('Error sending welcome email: $e');
      return false;
    }
  }

  /// Send password reset email with 8-digit code
  Future<bool> sendPasswordResetCode({
    required String customerEmail,
    required String customerName,
    required String resetCode,
  }) async {
    try {
      // Log email intent
      await _supabase.from('email_logs').insert({
        'recipient_email': customerEmail,
        'subject': 'Password Reset Code - Yang Chow Restaurant',
        'email_type': 'password_reset',
        'status': 'sent',
      });

      // Send actual email via SendGrid SMTP
      final response = await _supabase.functions.invoke('send-email', body: {
        'to': customerEmail,
        'subject': 'Password Reset Code - Yang Chow Restaurant',
        'htmlBody': _buildPasswordResetBody(
          customerName: customerName,
          resetCode: resetCode,
        ),
        'from': 'noreply@yangchowrestaurant.com',
      });

      debugPrint('Password reset email sent to: $customerEmail');
      debugPrint('Reset code: $resetCode');
      debugPrint('Response: $response');
      
      return true;
    } catch (e) {
      debugPrint('Error sending password reset email: $e');
      return false;
    }
  }

  /// Send account approval notification
  Future<bool> sendAccountApprovedEmail({
    required String customerEmail,
    required String customerName,
  }) async {
    try {
      await _supabase.from('email_logs').insert({
        'recipient_email': customerEmail,
        'subject': 'Account Approved - Yang Chow Restaurant',
        'email_type': 'account_approved',
        'status': 'sent',
      });

      await _supabase.functions.invoke('send-email', body: {
        'to': customerEmail,
        'subject': 'Account Approved - Yang Chow Restaurant',
        'htmlBody': _buildAccountApprovedBody(customerName: customerName),
        'from': 'noreply@yangchowrestaurant.com',
      });

      debugPrint('Account approved email sent to: $customerEmail');
      return true;
    } catch (e) {
      debugPrint('Error sending approval email: $e');
      return false;
    }
  }

  /// Build customer welcome email body
  String _buildCustomerWelcomeBody({
    required String customerName,
  }) {
    return '''
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
  <div style="background-color: #f8f9fa; padding: 30px; border-radius: 10px; text-align: center;">
    <h1 style="color: #E81E0D; margin-bottom: 20px;">Welcome to Yang Chow Restaurant!</h1>
    <div style="background-color: #E81E0D; color: white; width: 60px; height: 60px; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 20px;">
      <span style="font-size: 24px;">🍽</span>
    </div>
    <h2 style="color: #333; margin-bottom: 15px;">Hello $customerName!</h2>
    <p style="color: #666; font-size: 16px; line-height: 1.5; margin-bottom: 20px;">
      Thank you for creating an account at Yang Chow Restaurant! We're excited to have you join our community.
    </p>
    <div style="background-color: #fff; padding: 20px; border-radius: 8px; margin: 20px 0;">
      <h3 style="color: #E81E0D; margin-top: 0;">What's Next?</h3>
      <ul style="text-align: left; color: #666; line-height: 1.6;">
        <li>Your account is currently pending admin approval</li>
        <li>You'll receive an email once your account is approved</li>
        <li>After approval, you can make reservations and order online</li>
        <li>Download our mobile app for easy ordering</li>
      </ul>
    </div>
    <div style="background-color: #e9ecef; padding: 15px; border-radius: 8px; margin: 20px 0;">
      <p style="margin: 0; color: #495057;">
        <strong>Account Status:</strong> <span style="color: #ffc107;">⏳ Pending Approval</span>
      </p>
    </div>
  </div>
  <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #dee2e6;">
    <p style="color: #6c757d; font-size: 14px; margin: 0;">
      Questions? Contact us at <a href="mailto:support@yangchowrestaurant.com" style="color: #E81E0D;">support@yangchowrestaurant.com</a>
    </p>
    <p style="color: #6c757d; font-size: 12px; margin: 10px 0 0 0;">
      This is an automated message. Please do not reply to this email.
    </p>
  </div>
</div>
    ''';
  }

  /// Build password reset email body
  String _buildPasswordResetBody({
    required String customerName,
    required String resetCode,
  }) {
    return '''
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
  <div style="background-color: #f8f9fa; padding: 30px; border-radius: 10px; text-align: center;">
    <h1 style="color: #E81E0D; margin-bottom: 20px;">Password Reset</h1>
    <div style="background-color: #E81E0D; color: white; width: 60px; height: 60px; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 20px;">
      <span style="font-size: 24px;">🔐</span>
    </div>
    <h2 style="color: #333; margin-bottom: 15px;">Hello $customerName!</h2>
    <p style="color: #666; font-size: 16px; line-height: 1.5; margin-bottom: 20px;">
      You have requested to reset your password for your account at Yang Chow Restaurant.
    </p>
    <div style="background-color: #fff; padding: 30px; border-radius: 8px; margin: 20px 0; border: 2px solid #E81E0D;">
      <h3 style="color: #E81E0D; margin-top: 0;">Your 8-Digit Verification Code:</h3>
      <div style="background-color: #f8f9fa; padding: 20px; border-radius: 6px; margin: 20px 0;">
        <span style="font-size: 32px; font-weight: bold; letter-spacing: 6px; color: #E81E0D; text-align: center; display: block;">$resetCode</span>
      </div>
      <p style="color: #666; margin: 15px 0 0 0;">
        <strong>⏰ This code will expire in 10 minutes</strong>
      </p>
    </div>
    <div style="background-color: #e9ecef; padding: 15px; border-radius: 8px; margin: 20px 0;">
      <h4 style="color: #495057; margin-top: 0;">How to Use:</h4>
      <ol style="text-align: left; color: #666; line-height: 1.6;">
        <li>Open Yang Chow Restaurant app</li>
        <li>Enter this 8-digit code in the verification field</li>
        <li>Set your new password</li>
        <li>Login with your new password</li>
      </ol>
    </div>
    <div style="background-color: #d1ecf1; border: 1px solid #bee5eb; padding: 12px; border-radius: 6px; margin: 20px 0;">
      <p style="margin: 0; color: #0c5460;">
        <strong>🔒 Security Notice:</strong> If you did not request this password reset, please ignore this email or contact our support team immediately.
      </p>
    </div>
  </div>
  <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #dee2e6;">
    <p style="color: #6c757d; font-size: 14px; margin: 0;">
      Need help? Contact us at <a href="mailto:support@yangchowrestaurant.com" style="color: #E81E0D;">support@yangchowrestaurant.com</a>
    </p>
    <p style="color: #6c757d; font-size: 12px; margin: 10px 0 0 0;">
      This is an automated message. Please do not reply to this email.
    </p>
  </div>
</div>
    ''';
  }

  /// Build account approved email body
  String _buildAccountApprovedBody({
    required String customerName,
  }) {
    return '''
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
  <div style="background-color: #f8f9fa; padding: 30px; border-radius: 10px; text-align: center;">
    <h1 style="color: #28a745; margin-bottom: 20px;">Account Approved! 🎉</h1>
    <div style="background-color: #28a745; color: white; width: 60px; height: 60px; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 20px;">
      <span style="font-size: 24px;">✓</span>
    </div>
    <h2 style="color: #333; margin-bottom: 15px;">Hello $customerName!</h2>
    <p style="color: #666; font-size: 16px; line-height: 1.5; margin-bottom: 20px;">
      Great news! Your account has been approved and is now active.
    </p>
    <div style="background-color: #fff; padding: 20px; border-radius: 8px; margin: 20px 0;">
      <h3 style="color: #28a745; margin-top: 0;">What You Can Do Now:</h3>
      <ul style="text-align: left; color: #666; line-height: 1.6;">
        <li>🍽 Make reservations for events</li>
        <li>📱 Order online for pickup/delivery</li>
        <li>🎉 Access exclusive customer features</li>
        <li>⭐ Earn rewards points</li>
      </ul>
    </div>
    <div style="background-color: #d4edda; border: 1px solid #c3e6cb; padding: 15px; border-radius: 6px; margin: 20px 0;">
      <p style="margin: 0; color: #155724;">
        <strong>Account Status:</strong> <span style="color: #28a745;">✅ Active & Approved</span>
      </p>
    </div>
    <div style="text-align: center; margin: 30px 0;">
      <a href="https://yangchowrestaurant.com/login" style="background-color: #E81E0D; color: white; padding: 15px 30px; text-decoration: none; border-radius: 6px; display: inline-block; font-weight: bold;">
        Login to Your Account
      </a>
    </div>
  </div>
  <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #dee2e6;">
    <p style="color: #6c757d; font-size: 14px; margin: 0;">
      Questions? Contact us at <a href="mailto:support@yangchowrestaurant.com" style="color: #E81E0D;">support@yangchowrestaurant.com</a>
    </p>
    <p style="color: #6c757d; font-size: 12px; margin: 10px 0 0 0;">
      This is an automated message. Please do not reply to this email.
    </p>
  </div>
</div>
    ''';
  }
}
