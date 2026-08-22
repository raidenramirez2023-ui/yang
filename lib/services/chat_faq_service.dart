class FaqCategory {
  final String id;
  final String name;
  final String icon;

  const FaqCategory({
    required this.id,
    required this.name,
    required this.icon,
  });
}

class FaqItem {
  final String id;
  final String categoryId;
  final String question;
  final String shortChip;
  final String answer;
  final List<String> keywords;
  final String? actionType; // 'view_reservations', 'view_reschedules', 'view_refunds', 'talk_to_staff', 'view_menu'

  const FaqItem({
    required this.id,
    required this.categoryId,
    required this.question,
    required this.shortChip,
    required this.answer,
    required this.keywords,
    this.actionType,
  });
}

class ChatFaqService {
  static final ChatFaqService _instance = ChatFaqService._internal();
  factory ChatFaqService() => _instance;
  ChatFaqService._internal();

  static const List<FaqCategory> categories = [
    FaqCategory(id: 'all', name: 'All Topics', icon: '✨'),
    FaqCategory(id: 'booking', name: 'Booking Flow', icon: '📅'),
    FaqCategory(id: 'payment', name: 'GCash & Payment', icon: '💳'),
    FaqCategory(id: 'reschedule', name: 'Rescheduling', icon: '🔄'),
    FaqCategory(id: 'refund', name: 'Refunds & Cancellation', icon: '💸'),
    FaqCategory(id: 'support', name: 'Customer Support', icon: '💬'),
  ];

  static const List<FaqItem> faqList = [
    FaqItem(
      id: 'faq_booking_process',
      categoryId: 'booking',
      question: 'How does the reservation and pre-ordering process work?',
      shortChip: '📅 How to book a reservation',
      keywords: [
        'how to book', 'booking process', 'pre-order dishes', 'reservation process',
        'how to reserve', 'steps to book', 'paano mag book', 'paano mag-book',
        'paano mag reserve', 'booking flow'
      ],
      answer:
          '📅 **How to Book a Reservation in Yang Chow:**\n\n'
          '1. **Select Date, Time & Table:** On the Dashboard, choose your preferred event date, time slot, table setup, and number of guests (pax).\n'
          '2. **Pre-order Dishes (Menu):** Browse the menu and click *"Add to Order List"* to include your desired dishes in the cart.\n'
          '3. **Review & Checkout:** Verify your order breakdown, total cost, and required deposit downpayment.\n'
          '4. **Payment Verification:** Settle payment via GCash QR (upload receipt & ref no.) or PayMongo. You will receive an email confirmation and live tracking status.',
      actionType: 'book_flow',
    ),
    FaqItem(
      id: 'faq_gcash_payment',
      categoryId: 'payment',
      question: 'How do I pay using GCash QR or PayMongo?',
      shortChip: '💳 How to pay via GCash',
      keywords: [
        'how to pay', 'gcash qr', 'pay via gcash', 'paymongo', 'payment method',
        'upload payment receipt', 'reference number gcash', 'paano magbayad', 'paano mag bayad'
      ],
      answer:
          '💳 **Payment Process in Yang Chow:**\n\n'
          '1. **GCash QR:**\n'
          '   • Scan the official restaurant QR code displayed on the payment page.\n'
          '   • Enter the Reference Number from your GCash transaction.\n'
          '   • Upload a screenshot of your payment receipt/proof for admin verification.\n\n'
          '2. **PayMongo Gateway:**\n'
          '   • Select Debit/Credit Card or E-Wallet for direct online checkout.\n\n'
          '3. **Downpayment & Balance:**\n'
          '   • The verified deposit is deducted from your total bill, and the remaining balance can be viewed in your Order History.',
      actionType: 'payment_guide',
    ),
    FaqItem(
      id: 'faq_check_status_balance',
      categoryId: 'booking',
      question: 'Where can I view my reservation status and remaining balance?',
      shortChip: '📊 Check status & balance',
      keywords: [
        'check balance', 'remaining balance', 'reservation status', 'view status',
        'track balance', 'where to view balance', 'saan makikita balance', 'magkano balance'
      ],
      answer:
          '📊 **Tracking Status & Remaining Balance:**\n\n'
          '• **Order History:** Open *My Orders / Reservations* on your Dashboard to view current status (*Pending ➔ Confirmed ➔ Preparing ➔ Completed*).\n'
          '• **Live Balance:** View the exact downpayment paid and the remaining balance due at the restaurant.\n'
          '• **Real-time Updates:** Your status automatically updates once verified by the cashier or admin.',
      actionType: 'track_balance',
    ),
    FaqItem(
      id: 'faq_reschedule_process',
      categoryId: 'reschedule',
      question: 'How do I request to reschedule my reservation date or time?',
      shortChip: '🔄 How to reschedule',
      keywords: [
        'how to reschedule', 'reschedule request', 'change reservation date',
        'move schedule', 'rebook date', 'change time', 'paano mag reschedule', 'paano mag lipat'
      ],
      answer:
          '🔄 **How to Reschedule a Reservation:**\n\n'
          '1. **Go to Order Details:** Select your active booking from your reservations list.\n'
          '2. **Click *"Request Reschedule"*:** Choose your new preferred date, time, updated guest count, and state the reason.\n'
          '3. **Admin Review:** Your request is submitted to the Admin Dashboard with a **Pending** status.\n'
          '4. **Automatic Update:** Once approved, your reservation record automatically updates, and you will receive an email notification.',
      actionType: 'reschedule_portal',
    ),
    FaqItem(
      id: 'faq_refund_policy_exact',
      categoryId: 'refund',
      question: 'What is the cancellation and refund policy?',
      shortChip: '💸 Refund & Cancellation policy',
      keywords: [
        'cancellation policy', 'refund policy', 'how to cancel', 'refund percentage',
        'deposit refund', 'cancellation and refund', 'magkano refund', 'paano mag cancel'
      ],
      answer:
          '💸 **Cancellation & Refund Policy:**\n\n'
          '• **4+ Days Before the Event:** **100% Full Refund** of the deposit paid.\n'
          '• **0 to 3 Days Before the Event (Including Event Day):** **50% Partial Refund** to cover prepared and purchased ingredients.\n'
          '• **Past Event Date:** **0% (Non-refundable)**.\n\n'
          '📌 **How Refunds are Processed:**\n'
          '• Submit a cancellation request from your order details page.\n'
          '• The Admin reviews the ticket and returns the refund amount to your GCash or original payment method along with proof of transaction.',
      actionType: 'refund_tickets',
    ),
    FaqItem(
      id: 'faq_chat_support_staff',
      categoryId: 'support',
      question: 'How can I contact live staff and attach photos in chat?',
      shortChip: '💬 Chat support & photo upload',
      keywords: [
        'chat support', 'contact staff', 'talk to human', 'talk to live agent',
        'attach photo', 'send screenshot', 'kausap na staff', 'paano mag attach'
      ],
      answer:
          '💬 **Live Chat & Concierge Support:**\n\n'
          '• **Send Messages:** Type directly into the chat box for inquiries, special requests, or custom assistance.\n'
          '• **Attach Photos/Screenshots:** Click the camera/gallery icon to the left of the input bar to send payment receipts or photos.\n'
          '• **Real-time Notifications:** You will receive live alerts in the chat whenever a staff member responds.',
      actionType: 'chat_staff_photo',
    ),
  ];

  /// Get quick suggestion chips for the chat input bar
  List<String> getQuickChips() {
    return faqList.map((faq) => faq.shortChip).toList();
  }

  /// Match a user query or selected chip against the FAQ knowledge base
  FaqItem? findFaqMatch(String text) {
    if (text.trim().isEmpty) return null;

    final clean = text.toLowerCase().trim();

    // Do not match custom inquiries intended directly for human staff or specific ticket IDs
    if (clean.contains('hi support') ||
        clean.contains('inquire about my') ||
        clean.contains('specific inquiry not listed') ||
        clean.contains('reservation #') ||
        clean.contains('request #') ||
        clean.contains('ticket #')) {
      return null;
    }

    final normalized = clean
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // 1. Direct short chip or question exact match
    for (final faq in faqList) {
      final faqQ = faq.question
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final faqChip = faq.shortChip
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      if (clean == faq.shortChip.toLowerCase().trim() ||
          clean == faq.question.toLowerCase().trim() ||
          normalized == faqQ ||
          normalized == faqChip) {
        return faq;
      }
    }

    // 2. Multi-word phrase matching with strict scoring
    FaqItem? bestMatch;
    int highestScore = 0;

    for (final faq in faqList) {
      int score = 0;
      for (final kw in faq.keywords) {
        final cleanKw = kw.toLowerCase().trim();
        if (clean.contains(cleanKw) || normalized.contains(cleanKw)) {
          score += cleanKw.contains(' ') ? 4 : 2;
        }
      }

      if (score > highestScore && score >= 4) {
        highestScore = score;
        bestMatch = faq;
      }
    }

    return bestMatch;
  }
}
