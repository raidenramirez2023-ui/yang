import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConciergeLiveBotService {
  static final ConciergeLiveBotService _instance = ConciergeLiveBotService._internal();
  factory ConciergeLiveBotService() => _instance;
  ConciergeLiveBotService._internal();

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱',
    decimalDigits: 2,
  );

  /// Check if the incoming user text is an inquiry that can be fulfilled by live DB data
  bool isDatabaseInquiry(String text) {
    final clean = text.toLowerCase().trim();

    // Any inquiry regarding reservations, bookings, balances, reschedules, refunds, or staff
    if (clean.contains('refund') ||
        clean.contains('cancellation') ||
        clean.contains('cancel') ||
        clean.contains('reservation') ||
        clean.contains('booking') ||
        clean.contains('balance') ||
        clean.contains('reschedule') ||
        clean.contains('lipat') ||
        clean.contains('live staff') ||
        clean.contains('talk to human') ||
        clean.contains('specific inquiry')) {
      return true;
    }

    return false;
  }

  /// Generate a real-time, database-backed response for the logged-in customer
  Future<String?> generateDatabaseResponse(String customerEmail, String userText) async {
    final clean = userText.toLowerCase().trim();
    final email = customerEmail.trim();
    final lowerEmail = email.toLowerCase();

    // -------------------------------------------------------------------------
    // 0. LIVE STAFF CONNECTION / CUSTOM INQUIRY
    // -------------------------------------------------------------------------
    if (clean.contains('connect with a live staff') ||
        clean.contains('live staff member') ||
        clean.contains('talk to human') ||
        clean.contains('talk to live agent')) {
      return '💬 **Live Staff Connected:**\n\n'
          'We have alerted our restaurant support team for your account (**$email**)!\n\n'
          '• **Operating Hours:** 🕒 9:00 AM – 9:00 PM Daily\n'
          '• **Attach Photos:** You can tap the camera/photo icon below to upload payment receipts or event screenshots.\n\n'
          'A staff member will reply directly to your message shortly.';
    }

    if (clean.contains('specific inquiry not listed')) {
      return '💬 **Custom Inquiry Acknowledged:**\n\n'
          'We have received your custom inquiry and forwarded it directly to our live staff (**$email**).\n\n'
          'We will respond in this chat as soon as possible. Thank you for your patience!';
    }

    // -------------------------------------------------------------------------
    // 1. RESCHEDULE INQUIRY
    // -------------------------------------------------------------------------
    if (clean.contains('reschedule') || clean.contains('lipat ng petsa')) {
      try {
        final List<Map<String, dynamic>> reqs = [];

        // Check if message has a specific Reservation ID (e.g. #C4BE3776)
        String? targetResId;
        final resIdMatch = RegExp(r'#([a-zA-Z0-9_-]+)').firstMatch(userText);
        if (resIdMatch != null) {
          targetResId = resIdMatch.group(1);
        }

        try {
          final res = await Supabase.instance.client
              .from('reschedule_requests')
              .select('*')
              .eq('customer_email', email)
              .order('created_at', ascending: false)
              .limit(5);
          reqs.addAll(List<Map<String, dynamic>>.from(res));
        } catch (_) {}

        if (reqs.isEmpty && email != lowerEmail) {
          try {
            final res = await Supabase.instance.client
                .from('reschedule_requests')
                .select('*')
                .eq('customer_email', lowerEmail)
                .order('created_at', ascending: false)
                .limit(5);
            reqs.addAll(List<Map<String, dynamic>>.from(res));
          } catch (_) {}
        }

        // If targetResId was specified, query specifically by reservation_id or id if not yet in reqs
        if (targetResId != null && !reqs.any((r) => r['reservation_id']?.toString().toLowerCase().contains(targetResId!.toLowerCase()) == true)) {
          try {
            final res = await Supabase.instance.client
                .from('reschedule_requests')
                .select('*')
                .or('reservation_id.ilike.%$targetResId%,id.ilike.%$targetResId%')
                .limit(1);
            reqs.addAll(List<Map<String, dynamic>>.from(res));
          } catch (_) {}
        }

        if (reqs.isNotEmpty) {
          Map<String, dynamic> top = reqs.first;
          if (targetResId != null) {
            final match = reqs.firstWhere(
              (r) => r['reservation_id']?.toString().toLowerCase().contains(targetResId!.toLowerCase()) == true ||
                     r['id']?.toString().toLowerCase().contains(targetResId!.toLowerCase()) == true,
              orElse: () => reqs.first,
            );
            top = match;
          }

          final rawReqId = (top['id'] ?? '1').toString();
          final rawResId = (top['reservation_id'] ?? 'N/A').toString();
          final reqIdShort = rawReqId.length > 8 ? rawReqId.substring(0, 8).toUpperCase() : rawReqId;
          final resIdShort = rawResId.length > 8 ? rawResId.substring(0, 8).toUpperCase() : rawResId;
          final status = (top['status']?.toString() ?? 'Pending').toUpperCase();

          final oldDate = _formatDateTime(top['old_date'] ?? top['old_event_date'], top['old_time'] ?? top['old_event_time']);
          final newDate = _formatDateTime(top['new_date'] ?? top['new_event_date'], top['new_time'] ?? top['new_event_time']);
          final reason = top['reason']?.toString() ?? 'Date adjustment request';
          final statusEmoji = status.contains('APPROV') ? '🟢' : status.contains('REJECT') ? '🔴' : '🟡';
          final noteText = _getRescheduleNote(status);

          return '🔄 **Live Reschedule Request Status:**\n\n'
              '• **Request ID:** #REQ-$reqIdShort *(For Reservation #$resIdShort)*\n'
              '• **Status:** $statusEmoji **$status**\n'
              '• **Original Schedule:** $oldDate\n'
              '• **Requested New Schedule:** 📅 **$newDate**\n'
              '• **Reason Stated:** "$reason"\n\n'
              '$noteText';
        } else {
          // If no row in database, check if user message had embedded reschedule info
          if (userText.contains('Original:') && userText.contains('New:')) {
            return '🔄 **Reschedule Follow-Up Acknowledged:**\n\n'
                'We have logged your follow-up regarding your reschedule request.\n\n'
                '• **Account:** $email\n'
                '• **Details:** $userText\n\n'
                '💬 *Our support staff has been alerted and will confirm your schedule adjustment.*';
          }

          return '🔄 **Reschedule Status Update:**\n\n'
              'We checked your account (**$email**), and you currently have no pending reschedule requests.\n\n'
              'To request a date change, open your booking in your Dashboard and tap *"Request Reschedule"*.';
        }
      } catch (e) {
        debugPrint('Error fetching live reschedule for bot: $e');
      }
    }

    // -------------------------------------------------------------------------
    // 2. REFUND / CANCELLATION INQUIRY
    // -------------------------------------------------------------------------
    if (clean.contains('refund') || clean.contains('cancellation') || clean.contains('cancel') || clean.contains('ibalik')) {
      try {
        final List<Map<String, dynamic>> refunds = [];

        // Check if message has a specific Ticket / Cancellation ID (e.g. #C4BE3776)
        String? targetRefId;
        final refIdMatch = RegExp(r'#([a-zA-Z0-9_-]+)').firstMatch(userText);
        if (refIdMatch != null) {
          targetRefId = refIdMatch.group(1);
        }

        // 1. Query refunds table
        try {
          final res = await Supabase.instance.client
              .from('refunds')
              .select('*')
              .eq('customer_email', email)
              .order('created_at', ascending: false)
              .limit(5);
          refunds.addAll(List<Map<String, dynamic>>.from(res));
        } catch (_) {}

        if (refunds.isEmpty && email != lowerEmail) {
          try {
            final res = await Supabase.instance.client
                .from('refunds')
                .select('*')
                .eq('customer_email', lowerEmail)
                .order('created_at', ascending: false)
                .limit(5);
            refunds.addAll(List<Map<String, dynamic>>.from(res));
          } catch (_) {}
        }

        // 2. Query cancelled reservations
        try {
          final cancelledRes = await Supabase.instance.client
              .from('reservations')
              .select('*')
              .eq('customer_email', email)
              .eq('status', 'cancelled')
              .order('created_at', ascending: false)
              .limit(5);
          for (final c in cancelledRes) {
            refunds.add({
              'id': c['id'],
              'source_id': c['id'],
              'status': c['refund_status'] ?? c['status'] ?? 'COMPLETED',
              'refund_amount': c['refund_amount'] ?? 0,
              'reason': c['cancellation_reason'] ?? 'Cancelled Reservation (${c['event_type'] ?? 'Dining'})',
              'created_at': c['created_at'],
            });
          }
        } catch (_) {}

        // 3. If targetRefId specified, query reservations by targetRefId
        if (targetRefId != null && !refunds.any((r) => r['source_id']?.toString().toLowerCase().contains(targetRefId!.toLowerCase()) == true || r['id']?.toString().toLowerCase().contains(targetRefId!.toLowerCase()) == true)) {
          try {
            final res = await Supabase.instance.client
                .from('reservations')
                .select('*')
                .ilike('id', '%$targetRefId%')
                .limit(1);
            for (final c in res) {
              refunds.add({
                'id': c['id'],
                'source_id': c['id'],
                'status': c['refund_status'] ?? c['status'] ?? 'COMPLETED',
                'refund_amount': c['refund_amount'] ?? c['downpayment_amount'] ?? 0,
                'reason': c['cancellation_reason'] ?? 'Cancellation Request',
                'created_at': c['created_at'],
              });
            }
          } catch (_) {}
        }

        // If records found
        if (refunds.isNotEmpty) {
          Map<String, dynamic> top = refunds.first;
          if (targetRefId != null) {
            final match = refunds.firstWhere(
              (r) => (r['source_id']?.toString().toLowerCase().contains(targetRefId!.toLowerCase()) == true) ||
                     (r['id']?.toString().toLowerCase().contains(targetRefId!.toLowerCase()) == true) ||
                     (r['reservation_id']?.toString().toLowerCase().contains(targetRefId!.toLowerCase()) == true),
              orElse: () => refunds.first,
            );
            top = match;
          }

          final rawRefId = (top['source_id'] ?? top['id'] ?? '1').toString();
          final refIdShort = rawRefId.length > 8 ? rawRefId.substring(0, 8).toUpperCase() : rawRefId;
          final status = (top['status']?.toString() ?? 'COMPLETED').toUpperCase();
          final amount = _parseAmount(top['refund_amount'] ?? top['amount']);
          final reason = top['reason']?.toString() ?? top['cancellation_reason']?.toString() ?? 'Refund requested';
          final statusEmoji = status.contains('COMPLET') || status.contains('APPROV') ? '🟢' : status.contains('REJECT') ? '🔴' : '🟡';
          final noteText = _getRefundNote(status);

          return '💸 **Live Refund Request Status:**\n\n'
              '• **Cancellation Ref:** #${refIdShort.isEmpty ? 'N/A' : refIdShort}\n'
              '• **Status:** $statusEmoji **$status**\n'
              '• **Refund Amount:** **${_currencyFormat.format(amount)}**\n'
              '• **Reason:** "$reason"\n\n'
              '$noteText';
        }

        // Fallback: If message contains embedded refund ticket info
        if (userText.contains('Cancellation #') || userText.contains('Amount:')) {
          final amtMatch = RegExp(r'Amount:\s*(₱[0-9,.]+)').firstMatch(userText);
          final parsedAmt = amtMatch?.group(1) ?? '₱0.00';
          final stMatch = RegExp(r'Status:\s*([a-zA-Z]+)').firstMatch(userText);
          final parsedStatus = (stMatch?.group(1) ?? 'COMPLETED').toUpperCase();
          final noteText = _getRefundNote(parsedStatus);

          return '💸 **Live Refund Request Status:**\n\n'
              '• **Cancellation Ref:** #${targetRefId ?? 'RECORD'}\n'
              '• **Status:** 🟢 **$parsedStatus**\n'
              '• **Refund Amount:** **$parsedAmt**\n\n'
              '$noteText';
        }

        return '💸 **Cancellation & Refund Policy Guidelines:**\n\n'
            'Here is our official refund calculation policy:\n'
            '• **4+ Days Before Event Date:** **100% Full Refund** of the deposit paid.\n'
            '• **0 to 3 Days Before Event Date (Including Event Day):** **50% Partial Refund** (to cover prepared ingredients).\n'
            '• **Past Event Date:** **0% (Non-refundable)**.\n\n'
            '📌 **How to Submit a Cancellation Request:**\n'
            '1. Go to **My Orders / Reservations** on your Dashboard.\n'
            '2. Open your booking and click *"Request Cancellation / Refund"*.\n'
            '3. State the reason and submit. Our Admin will verify and process the return via GCash/original payment method.\n\n'
            '💬 *Our live support staff has also been notified and can assist you right away!*';
      } catch (e) {
        debugPrint('Error fetching live refund for bot: $e');
      }
    }

    // -------------------------------------------------------------------------
    // 3. RESERVATION & BALANCE INQUIRY
    // -------------------------------------------------------------------------
    try {
      final List<Map<String, dynamic>> allReservations = [];

      // Extract specific Reservation ID if mentioned in the message text (e.g. #05C84803)
      String? targetId;
      final idMatch = RegExp(r'#([a-zA-Z0-9_-]+)').firstMatch(userText);
      if (idMatch != null) {
        targetId = idMatch.group(1);
      }

      // Safe Query 1: reservations by customer_email
      try {
        final res = await Supabase.instance.client
            .from('reservations')
            .select('*')
            .eq('customer_email', email)
            .order('created_at', ascending: false)
            .limit(10);
        for (final r in res) {
          allReservations.add(Map<String, dynamic>.from(r));
        }
      } catch (e) {
        debugPrint('Error in reservation query 1: $e');
      }

      // Safe Query 2: reservations by lowercase email
      if (email != lowerEmail) {
        try {
          final res = await Supabase.instance.client
              .from('reservations')
              .select('*')
              .eq('customer_email', lowerEmail)
              .order('created_at', ascending: false)
              .limit(10);
          for (final r in res) {
            if (!allReservations.any((x) => x['id']?.toString() == r['id']?.toString())) {
              allReservations.add(Map<String, dynamic>.from(r));
            }
          }
        } catch (_) {}
      }

      // Safe Query 3: advance_orders
      try {
        final orders = await Supabase.instance.client
            .from('advance_orders')
            .select('*')
            .eq('customer_email', email)
            .order('created_at', ascending: false)
            .limit(10);
        for (final o in orders) {
          allReservations.add({
            ...o,
            'event_type': 'Advance Order (${o['order_type'] ?? 'Food'})',
            'event_date': o['order_date'] ?? o['created_at'],
            'start_time': o['order_time'] ?? '',
            'guests': o['pax'] ?? o['guests'] ?? 'N/A',
            'total_amount': o['total_amount'] ?? 0,
            'downpayment_amount': o['paid_amount'] ?? o['downpayment'] ?? o['total_amount'] ?? 0,
            'remaining_balance': o['remaining_balance'] ?? 0,
            'status': o['status'] ?? o['payment_status'] ?? 'Confirmed',
          });
        }
      } catch (_) {}

      // Safe Query 4: by specific targetId if not found yet
      if (targetId != null && !allReservations.any((r) => r['id']?.toString().toLowerCase().contains(targetId!.toLowerCase()) == true)) {
        try {
          final res = await Supabase.instance.client
              .from('reservations')
              .select('*')
              .ilike('id', '%$targetId%')
              .limit(1);
          for (final r in res) {
            allReservations.add(Map<String, dynamic>.from(r));
          }
        } catch (_) {}
      }

      // If records found in database
      if (allReservations.isNotEmpty) {
        // Find matching record by ID or take the latest
        Map<String, dynamic> top = allReservations.first;
        if (targetId != null) {
          final match = allReservations.firstWhere(
            (r) => r['id']?.toString().toLowerCase().contains(targetId!.toLowerCase()) == true,
            orElse: () => allReservations.first,
          );
          top = match;
        }

        final resId = top['id']?.toString() ?? '1';
        final eventType = top['event_type']?.toString() ?? 'Dining Reservation';
        final pax = top['guests']?.toString() ?? top['pax']?.toString() ?? 'N/A';
        final dateStr = _formatDateTime(top['event_date'] ?? top['reservation_date'], top['start_time'] ?? top['event_time']);
        final table = top['table_layout']?.toString() ?? top['table_number']?.toString() ?? 'Standard Table';
        final status = (top['status']?.toString() ?? 'Pending').toUpperCase();

        final total = _parseAmount(top['total_amount'] ?? top['total_price'] ?? top['grand_total']);
        final downpayment = _parseAmount(top['downpayment_amount'] ?? top['deposit_amount'] ?? top['paid_amount']);
        var remaining = _parseAmount(top['remaining_balance'] ?? top['balance']);

        if (remaining == 0 && total > 0 && downpayment > 0 && total > downpayment) {
          remaining = total - downpayment;
        }

        final isFullyPaid = remaining == 0 && (total > 0 || status.contains('COMPLETE'));
        final statusEmoji = status.contains('CONFIRM') || status.contains('COMPLETE')
            ? '🟢'
            : status.contains('PEND')
                ? '🟡'
                : status.contains('CANCEL')
                    ? '🔴'
                    : '🔵';
        final noteText = _getReservationNote(status, isFullyPaid, remaining);

        return '📅 **Live Reservation & Balance Tracker:**\n\n'
            '• **Booking Reference:** #${resId.length > 8 ? resId.substring(0, 8).toUpperCase() : resId}\n'
            '• **Event / Type:** $eventType ($pax Guests)\n'
            '• **Date & Schedule:** 🕒 **$dateStr**\n'
            '• **Table Setup:** $table\n'
            '• **Status:** $statusEmoji **$status**\n\n'
            '💰 **Payment Breakdown:**\n'
            '• Total Bill: ${_currencyFormat.format(total > 0 ? total : downpayment + remaining)}\n'
            '• Downpayment Paid: ${_currencyFormat.format(downpayment)}\n'
            '• **Remaining Balance:** **${isFullyPaid && remaining == 0 ? '₱0.00 (Fully Settled)' : _currencyFormat.format(remaining)}** ${!isFullyPaid && remaining > 0 ? '*(Payable at the restaurant)*' : '✅'}\n\n'
            '$noteText';
      }

      // If no database rows returned, check if userText has embedded parsed reservation info
      if (userText.contains('Reservation #') || userText.contains('Status:')) {
        return '📅 **Reservation Inquiry Acknowledged:**\n\n'
            'We have received your inquiry regarding your booking.\n\n'
            '• **Account:** $email\n'
            '• **Details:** $userText\n\n'
            '💬 *Our live support staff has been alerted and will assist you right away.*';
      }

      return '📅 **Reservation & Balance Update:**\n\n'
          'We checked your account (**$email**), and you currently have no active reservations on record.\n\n'
          'Would you like to book a table or pre-order dishes from our menu? You can easily start from the Dashboard.';
    } catch (e) {
      debugPrint('Error generating live reservation response: $e');
      return null;
    }
  }

  String _getRescheduleNote(String status) {
    final s = status.toUpperCase();
    if (s.contains('APPROV')) {
      return '📌 *Note: Great news! Your reschedule request has been APPROVED by the Admin, and your reservation date & time have been updated.*';
    } else if (s.contains('REJECT') || s.contains('DECLIN')) {
      return '📌 *Note: Your reschedule request was DECLINED. Your original event schedule remains active.*';
    } else if (s.contains('CANCEL')) {
      return '📌 *Note: This reschedule request was cancelled.*';
    } else {
      return '📌 *Note: Your reschedule request is currently PENDING review by the Admin team. We will notify you once approved.*';
    }
  }

  String _getRefundNote(String status) {
    final s = status.toUpperCase();
    if (s.contains('COMPLET') || s.contains('APPROV')) {
      return '📌 *Note: Great news! Your refund request has been APPROVED and processed. Funds are returned via your GCash/original payment method.*';
    } else if (s.contains('REJECT') || s.contains('DECLIN')) {
      return '📌 *Note: Your refund request was DECLINED based on the cancellation policy timeline.*';
    } else {
      return '📌 *Note: Your refund request is currently under review by our Admin team according to the refund policy.*';
    }
  }

  String _getReservationNote(String status, bool isFullyPaid, double remaining) {
    final s = status.toUpperCase();
    if (s.contains('COMPLET')) {
      return '📌 *Note: This reservation has been marked as COMPLETED. Thank you for dining with Yang Chow!*';
    } else if (s.contains('CANCEL')) {
      return '📌 *Note: This reservation record has been CANCELLED.*';
    } else if (s.contains('CONFIRM')) {
      if (isFullyPaid || remaining == 0) {
        return '📌 *Note: Your booking is CONFIRMED and FULLY PAID. We look forward to welcoming you!*';
      } else {
        return '📌 *Note: Your booking is CONFIRMED. The remaining balance will be settled at the restaurant during your event.*';
      }
    } else {
      return '📌 *Note: Your reservation is currently PENDING verification by our staff.*';
    }
  }

  double _parseAmount(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    final cleanStr = val.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleanStr) ?? 0.0;
  }

  String _formatDateTime(dynamic rawDate, dynamic rawTime) {
    if (rawDate == null || rawDate.toString().trim().isEmpty) return 'Date TBA';
    try {
      final str = rawDate.toString().trim();
      DateTime? dt;
      if (str.contains('T')) {
        dt = DateTime.tryParse(str)?.toLocal();
      } else if (str.contains(' ')) {
        dt = DateTime.tryParse(str.split(' ')[0]);
      } else {
        dt = DateTime.tryParse(str);
      }

      String dateFormatted = str;
      if (dt != null) {
        dateFormatted = DateFormat('MMM d, yyyy').format(dt);
      }

      if (rawTime != null && rawTime.toString().trim().isNotEmpty) {
        final formattedTime = _formatTime(rawTime.toString());
        return '$dateFormatted • $formattedTime';
      }
      return dateFormatted;
    } catch (_) {
      return '$rawDate ${rawTime ?? ''}'.trim();
    }
  }

  String _formatTime(String rawTime) {
    final t = rawTime.trim();
    if (t.isEmpty) return '';
    if (t.toLowerCase().contains('am') || t.toLowerCase().contains('pm')) {
      return t;
    }
    try {
      final parts = t.split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1]);
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
        return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
      }
    } catch (_) {}
    return t;
  }
}
