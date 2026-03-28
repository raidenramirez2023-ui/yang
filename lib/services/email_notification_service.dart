import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_constants.dart';

/// Service to manage email notifications for customers
/// This service logs notification intents and can be connected to an email service
class EmailNotificationService {
  static final EmailNotificationService _instance =
      EmailNotificationService._internal();
  static final SupabaseClient _supabase = Supabase.instance.client;

  EmailNotificationService._internal();

  factory EmailNotificationService() {
    return _instance;
  }

  /// Send a reservation confirmation email (when reservation is created)
  Future<bool> sendReservationConfirmation({
    required String customerEmail,
    required String customerName,
    required String eventType,
    required String eventDate,
    required String startTime,
    required double duration,
    required int guests,
  }) async {
    return _logEmailNotification(
      recipientEmail: customerEmail,
      subject: 'Reservation Confirmation - Yang Chow Restaurant',
      emailType: AppConstants.emailTypeConfirmation,
      body: _buildReservationConfirmationBody(
        customerName: customerName,
        eventType: eventType,
        eventDate: eventDate,
        startTime: startTime,
        duration: duration,
        guests: guests,
      ),
    );
  }

  /// Send reservation approval notification
  Future<bool> sendReservationApproved({
    required String customerEmail,
    required String customerName,
    required String eventType,
    required String eventDate,
    required String startTime,
  }) async {
    return _logEmailNotification(
      recipientEmail: customerEmail,
      subject: 'Your Reservation is Confirmed! - Yang Chow Restaurant',
      emailType: AppConstants.emailTypeApproved,
      body: _buildReservationApprovedBody(
        customerName: customerName,
        eventType: eventType,
        eventDate: eventDate,
        startTime: startTime,
      ),
    );
  }

  /// Send reservation rejection notification
  Future<bool> sendReservationRejected({
    required String customerEmail,
    required String customerName,
    required String eventType,
    required String eventDate,
    String? reason,
  }) async {
    return _logEmailNotification(
      recipientEmail: customerEmail,
      subject: 'Reservation Status Update - Yang Chow Restaurant',
      emailType: AppConstants.emailTypeRejected,
      body: _buildReservationRejectedBody(
        customerName: customerName,
        eventType: eventType,
        eventDate: eventDate,
        reason: reason,
      ),
    );
  }

  /// Send cancellation notification
  Future<bool> sendReservationCancelled({
    required String customerEmail,
    required String customerName,
    required String eventType,
    required String eventDate,
    required double? refundAmount,
  }) async {
    return _logEmailNotification(
      recipientEmail: customerEmail,
      subject: 'Reservation Cancelled - Yang Chow Restaurant',
      emailType: AppConstants.emailTypeCancelled,
      body: _buildReservationCancelledBody(
        customerName: customerName,
        eventType: eventType,
        eventDate: eventDate,
        refundAmount: refundAmount,
      ),
    );
  }

  /// Send reservation reminder (24 hours before event)
  Future<bool> sendReservationReminder({
    required String customerEmail,
    required String customerName,
    required String eventType,
    required String eventDate,
    required String startTime,
    required int guests,
  }) async {
    return _logEmailNotification(
      recipientEmail: customerEmail,
      subject: 'Reminder: Your Reservation Tomorrow - Yang Chow Restaurant',
      emailType: AppConstants.emailTypeReminder,
      body: _buildReservationReminderBody(
        customerName: customerName,
        eventType: eventType,
        eventDate: eventDate,
        startTime: startTime,
        guests: guests,
      ),
    );
  }

  /// Send review request (after reservation date passes)
  Future<bool> sendReviewRequest({
    required String customerEmail,
    required String customerName,
    required String eventType,
    required String eventDate,
  }) async {
    return _logEmailNotification(
      recipientEmail: customerEmail,
      subject: 'We\'d Love Your Feedback! - Yang Chow Restaurant',
      emailType: AppConstants.emailTypeReviewRequest,
      body: _buildReviewRequestBody(
        customerName: customerName,
        eventType: eventType,
        eventDate: eventDate,
      ),
    );
  }

  /// Send refund processed notification
  Future<bool> sendRefundProcessed({
    required String customerEmail,
    required String customerName,
    required double refundAmount,
    required String eventType,
    required String eventDate,
  }) async {
    return _logEmailNotification(
      recipientEmail: customerEmail,
      subject: 'Refund Processed - Yang Chow Restaurant',
      emailType: AppConstants.emailTypeRefundProcessed,
      body: _buildRefundProcessedBody(
        customerName: customerName,
        refundAmount: refundAmount,
        eventType: eventType,
        eventDate: eventDate,
      ),
    );
  }

  /// Internal method to log email notification intent
  Future<bool> _logEmailNotification({
    required String recipientEmail,
    required String subject,
    required String emailType,
    required String body,
  }) async {
    try {
      await _supabase.from('email_logs').insert({
        'recipient_email': recipientEmail,
        'subject': subject,
        'email_type': emailType,
        'status': 'sent', // Will be updated if actual sending fails
      });

      debugPrint('Email logged: $emailType to $recipientEmail');

      // TODO: Integrate with actual email service (SendGrid, AWS SES, Mailgun, etc.)
      // For now, just log the intent
      _printEmailPreview(recipientEmail, subject, body);

      return true;
    } catch (e) {
      debugPrint('Error logging email notification: $e');
      return false;
    }
  }

  /// Email body builders
  String _buildReservationConfirmationBody({
    required String customerName,
    required String eventType,
    required String eventDate,
    required String startTime,
    required double duration,
    required int guests,
  }) {
    return '''
Dear $customerName,

Thank you for your reservation at Yang Chow Restaurant!

We have received your reservation request and it is currently pending approval.

EVENT DETAILS:
Event Type: $eventType
Date: $eventDate
Start Time: $startTime
Duration: ${duration.toStringAsFixed(1)} hours
Number of Guests: $guests

Our team will review your request and send you a confirmation within 24 hours.

If you have any questions or need to modify your reservation, please don't hesitate to contact us.

Best regards,
Yang Chow Restaurant Management Team
    ''';
  }

  String _buildReservationApprovedBody({
    required String customerName,
    required String eventType,
    required String eventDate,
    required String startTime,
  }) {
    return '''
Dear $customerName,

Great news! Your reservation has been approved and confirmed!

EVENT DETAILS:
Event Type: $eventType
Date: $eventDate
Start Time: $startTime

We are looking forward to hosting your event. Our team will ensure everything is perfect for your special occasion.

Please arrive 10-15 minutes early. If you have any special requests or dietary requirements, please let us know as soon as possible.

Best regards,
Yang Chow Restaurant Management Team
    ''';
  }

  String _buildReservationRejectedBody({
    required String customerName,
    required String eventType,
    required String eventDate,
    String? reason,
  }) {
    String reasonText =
        reason ??
        'We regret to inform you that we cannot accommodate your reservation at this time.';

    return '''
Dear $customerName,

Thank you for your interest in reserving a table at Yang Chow Restaurant for your $eventType on $eventDate.

Unfortunately, we are unable to approve your reservation. $reasonText

We appreciate your understanding and hope to serve you in the future. Please feel free to contact us to discuss alternative dates or arrangements.

Best regards,
Yang Chow Restaurant Management Team
    ''';
  }

  String _buildReservationCancelledBody({
    required String customerName,
    required String eventType,
    required String eventDate,
    double? refundAmount,
  }) {
    String refundText = '';
    if (refundAmount != null && refundAmount > 0) {
      refundText =
          '\n\nYour refund of ₱${refundAmount.toStringAsFixed(2)} will be processed within 5-7 business days.';
    }

    return '''
Dear $customerName,

Your reservation has been cancelled as requested.

EVENT DETAILS:
Event Type: $eventType
Date: $eventDate$refundText

We understand that things change and appreciate your notification. We hope to welcome you again in the future.

If you have any questions, please don't hesitate to contact us.

Best regards,
Yang Chow Restaurant Management Team
    ''';
  }

  String _buildReservationReminderBody({
    required String customerName,
    required String eventType,
    required String eventDate,
    required String startTime,
    required int guests,
  }) {
    return '''
Dear $customerName,

This is a friendly reminder that your reservation is coming up tomorrow!

EVENT DETAILS:
Event Type: $eventType
Date: $eventDate
Start Time: $startTime
Number of Guests: $guests

Please arrive 10-15 minutes early. If you need to make any changes or have special requests, please contact us as soon as possible.

We look forward to seeing you!

Best regards,
Yang Chow Restaurant Management Team
    ''';
  }

  String _buildReviewRequestBody({
    required String customerName,
    required String eventType,
    required String eventDate,
  }) {
    return '''
Dear $customerName,

Thank you for choosing Yang Chow Restaurant for your $eventType!

We hope you had a wonderful experience with us. Your feedback is incredibly important to us and helps us continue to improve our service.

We would love to hear about your experience. Please take a moment to leave a review on our app or website.

Thank you for your continued support!

Best regards,
Yang Chow Restaurant Management Team
    ''';
  }

  String _buildRefundProcessedBody({
    required String customerName,
    required double refundAmount,
    required String eventType,
    required String eventDate,
  }) {
    return '''
Dear $customerName,

We are writing to confirm that your refund has been processed.

REFUND DETAILS:
Amount: ₱${refundAmount.toStringAsFixed(2)}
Original Event: $eventType on $eventDate

The refund has been credited back to your original payment method. Depending on your bank, it may take 5-7 business days to appear in your account.

Thank you for your understanding.

Best regards,
Yang Chow Restaurant Management Team
    ''';
  }

  /// Print email preview for debugging (remove in production)
  void _printEmailPreview(String recipient, String subject, String body) {
    debugPrint('''
═══════════════════════════════════════════════
EMAIL PREVIEW (Not Actually Sent Yet)
═══════════════════════════════════════════════
To: $recipient
Subject: $subject

$body
═══════════════════════════════════════════════
''');
  }

  /// Get email logs for a specific customer
  Future<List<Map<String, dynamic>>> getCustomerEmailLogs(
    String customerEmail,
  ) async {
    try {
      final response = await _supabase
          .from('email_logs')
          .select()
          .eq('recipient_email', customerEmail)
          .order('sent_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching email logs: $e');
      return [];
    }
  }

  /// Get all failed emails (for retry logic)
  Future<List<Map<String, dynamic>>> getFailedEmails() async {
    try {
      final response = await _supabase
          .from('email_logs')
          .select()
          .eq('status', 'failed')
          .order('sent_at', ascending: true)
          .limit(10);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching failed emails: $e');
      return [];
    }
  }

  /// Update email status (for retry tracking)
  Future<void> updateEmailStatus(
    String emailLogId,
    String status, {
    String? error,
  }) async {
    try {
      await _supabase
          .from('email_logs')
          .update({'status': status, ...error != null ? {'error_message': error} : {}})
          .eq('id', emailLogId);
    } catch (e) {
      debugPrint('Error updating email status: $e');
    }
  }
}
