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
        'paano mag reserve', 'booking flow', 'pre order'
      ],
      answer:
          '📅 **How to Book a Reservation in Yang Chow:**\n\n'
          '1. **Step 1: Select Schedule & Table Setup**\n'
          '   • On the **Customer Dashboard**, go to the **Book a Table** section.\n'
          '   • Choose your event date, preferred time slot, table layout/table number, and number of guests (pax).\n\n'
          '2. **Step 2: Pre-order Dishes (Menu Selection)**\n'
          '   • Browse menu categories and select your desired dishes.\n'
          '   • Customize quantities and tap **"Add to Order List"** to include them in your booking.\n\n'
          '3. **Step 3: Review Order & Downpayment**\n'
          '   • Review your booking summary, ordered dishes, total bill, and the required deposit downpayment amount.\n\n'
          '4. **Step 4: Settle Payment (GCash QR / PayMongo)**\n'
          '   • Proceed to checkout and pay via **GCash QR** (enter Ref No. & upload receipt proof) or **PayMongo** (credit/debit card or e-wallet).\n'
          '   • Tap **Submit Payment**.\n\n'
          '5. **Step 5: Track Your Booking**\n'
          '   • Once submitted, track your live status (*Pending ➔ Confirmed*) under **"My Bookings"** on your Dashboard. You will also receive email notifications.',
      actionType: 'book_flow',
    ),
    FaqItem(
      id: 'faq_gcash_payment',
      categoryId: 'payment',
      question: 'How do I pay using GCash QR or PayMongo?',
      shortChip: '💳 How to pay via GCash',
      keywords: [
        'how to pay', 'gcash qr', 'pay via gcash', 'paymongo', 'payment method',
        'upload payment receipt', 'reference number gcash', 'paano magbayad', 'paano mag bayad',
        'online payment', 'gcash'
      ],
      answer:
          '💳 **Payment Process in Yang Chow:**\n\n'
          '1. **GCash QR Payment:**\n'
          '   • On the payment screen, select **GCash QR**.\n'
          '   • Scan or save the official restaurant GCash QR Code displayed on screen.\n'
          '   • Pay the required downpayment or total amount through your GCash App.\n'
          '   • Copy the **GCash Reference Number** and upload the **Screenshot / Receipt Proof**.\n'
          '   • Tap **Submit Payment** for admin/cashier verification.\n\n'
          '2. **PayMongo Gateway:**\n'
          '   • Select **PayMongo** for instant online payment using Debit/Credit Card or supported E-Wallets.\n'
          '   • Complete payment on PayMongo\'s secure checkout page. Confirmation is verified automatically in real-time.\n\n'
          '3. **Remaining Balance Settlement:**\n'
          '   • The verified downpayment is automatically credited.\n'
          '   • The remaining balance can be settled at the restaurant cashier during your visit or via online payment under **"My Bookings"**.',
      actionType: 'payment_guide',
    ),
    FaqItem(
      id: 'faq_check_status_balance',
      categoryId: 'booking',
      question: 'Where can I view my reservation status and remaining balance?',
      shortChip: '📊 Check status & balance',
      keywords: [
        'check balance', 'remaining balance', 'reservation status', 'view status',
        'track balance', 'where to view balance', 'saan makikita balance', 'magkano balance',
        'status and balance', 'my bookings', 'where can i view'
      ],
      answer:
          '📊 **Tracking Status & Remaining Balance in Yang Chow:**\n\n'
          '• **Dashboard - "My Bookings" Section:**\n'
          '  Scroll down on your **Customer Dashboard** to see all active reservations and advance orders.\n'
          '• **Transactions Page:**\n'
          '  Tap **"Transactions"** from the navigation drawer/bar to view your full booking and payment history.\n'
          '• **Live Status Badge:**\n'
          '  Each booking card displays its live status: `PENDING`, `CONFIRMED`, `PREPARING`, `COMPLETED`, or `CANCELLED`.\n'
          '• **Live Balance Breakdown:**\n'
          '  Each card displays the **Total Bill**, **Downpayment Paid**, and **Remaining Balance** (payable upon dining at the restaurant).',
      actionType: 'track_balance',
    ),
    FaqItem(
      id: 'faq_reschedule_process',
      categoryId: 'reschedule',
      question: 'How do I request to reschedule my reservation date or time?',
      shortChip: '🔄 How to reschedule',
      keywords: [
        'how to reschedule', 'reschedule request', 'change reservation date',
        'move schedule', 'rebook date', 'change time', 'paano mag reschedule', 'paano mag lipat',
        'request to reschedule'
      ],
      answer:
          '🔄 **How to Reschedule a Reservation in Yang Chow:**\n\n'
          '1. **Locate Your Booking:**\n'
          '   • Go to **"My Bookings"** on your **Customer Dashboard**.\n'
          '2. **Open Actions Menu (⋮):**\n'
          '   • On your active reservation card, tap the **Three-Dot Menu (⋮)** in the upper right.\n'
          '3. **Select "Reschedule":**\n'
          '   • Tap **"Reschedule"** to open the Reschedule Request dialog.\n'
          '4. **Choose New Date, Time & Provide Reason:**\n'
          '   • Select your new preferred date and available time slot.\n'
          '   • Enter the reason for rescheduling and tap **"Submit Reschedule"**.\n'
          '5. **Admin Approval:**\n'
          '   • Your booking status will show **"Reschedule Pending"** while under review.\n'
          '   • You will receive an in-app and email notification once the Admin approves or declines the new schedule.',
      actionType: 'reschedule_portal',
    ),
    FaqItem(
      id: 'faq_refund_policy_exact',
      categoryId: 'refund',
      question: 'What is the cancellation and refund policy?',
      shortChip: '💸 Refund & Cancellation policy',
      keywords: [
        'cancellation policy', 'refund policy', 'how to cancel', 'refund percentage',
        'deposit refund', 'cancellation and refund', 'magkano refund', 'paano mag cancel',
        'cancellation and refund policy'
      ],
      answer:
          '💸 **Cancellation & Refund Policy in Yang Chow:**\n\n'
          '• **Policy Calculation Schedule:**\n'
          '  - **4+ Days Before Event Date:** **100% Full Refund** of the deposit/payment made.\n'
          '  - **0 to 3 Days Before Event (Including Event Day):** **50% Partial Refund** (to cover reserved slots and prepared food ingredients).\n'
          '  - **After Event Date Has Passed:** **0% (Non-refundable)**.\n\n'
          '📌 **How to Cancel a Booking in the App:**\n'
          '1. Go to **"My Bookings"** on your **Customer Dashboard**.\n'
          '2. Tap the **Three-Dot Menu (⋮)** on your reservation card and select **"Cancel Booking"**.\n'
          '3. The system calculates and displays your **Expected Refund Amount** according to the policy.\n'
          '4. Select your cancellation reason and confirm.\n'
          '5. The Admin reviews and processes the refund to your GCash / PayMongo or original payment method within 5–7 business days.',
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
          '💬 **Live Chat & Concierge Support in Yang Chow:**\n\n'
          '• **Message Directly:** Type your questions, dietary preferences, or event inquiries into the chat bar below.\n'
          '• **Attach Photos / Payment Receipts:** Tap the **Camera / Gallery Icon** beside the input bar to attach receipts or event photos.\n'
          '• **Operating Hours:** 🕒 9:00 AM – 9:00 PM Daily.\n'
          '• **Instant Notifications:** You will receive live in-app notifications whenever staff replies to your conversation.',
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
