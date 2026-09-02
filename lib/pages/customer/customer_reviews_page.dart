import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:yang_chow/services/reservation_service.dart';
import 'package:yang_chow/pages/customer/customer_dashboard.dart';

/// Page for customers to leave reviews and ratings for completed reservations
class CustomerReviewsPage extends StatefulWidget {
  final String? reservationId;

  const CustomerReviewsPage({super.key, this.reservationId});

  @override
  State<CustomerReviewsPage> createState() => _CustomerReviewsPageState();
}

class _CustomerReviewsPageState extends State<CustomerReviewsPage> {
  final ReservationService _reservationService = ReservationService();

  List<Map<String, dynamic>> _pastReservations = [];
  Map<String, dynamic>? _selectedReservation;
  Map<String, dynamic>? _existingReview;

  int _overallRating = 0;
  int _foodQuality = 0;
  int _serviceQuality = 0;
  int _ambiance = 0;
  int _turnaroundTime = 0;
  int _responsivenessRate = 0;
  final TextEditingController _reviewTextController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;

  // Brand Palette matching Yang Chow aesthetic
  static const Color _forestGreen = Color(0xFF14332E);
  static const Color _darkForest = Color(0xFF0F221E);
  static const Color _deepBurgundy = Color(0xFF1E0B0B);
  static const Color _primaryGold = Color(0xFFC9922E);
  static const Color _warmGold = Color(0xFFD9A441);

  @override
  void initState() {
    super.initState();
    _loadPastReservations();
  }

  void _loadPastReservations() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not authenticated')),
          );
        }
        return;
      }

      final reservations = await _reservationService.getCustomerReservations(
        currentUser.email!,
      );

      // Allow all reservations (pending, confirmed, ready, completed, cancelled, etc.) to be rated and reviewed
      final pastReservations = reservations;

      if (mounted) {
        setState(() {
          _pastReservations = pastReservations;
          _isLoading = false;

          // Auto-select event: if a specific reservation was passed, select it; otherwise default to the latest
          if (pastReservations.isNotEmpty) {
            if (widget.reservationId != null) {
              _selectedReservation = pastReservations.firstWhere(
                (r) => r['id']?.toString() == widget.reservationId,
                orElse: () => pastReservations.first,
              );
            } else {
              _selectedReservation = pastReservations.first;
            }

            if (_selectedReservation != null &&
                _selectedReservation!.isNotEmpty) {
              _loadExistingReview(_selectedReservation!['id']);
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading reservations: $e')),
        );
      }
    }
  }

  void _loadExistingReview(String reservationId) async {
    try {
      final review = await _reservationService.getReservationReview(
        reservationId,
      );
      if (mounted) {
        setState(() {
          _existingReview = review;
          if (review != null) {
            _overallRating = review['rating'] ?? 0;
            _foodQuality = review['food_quality'] ?? 0;
            _serviceQuality = review['service_quality'] ?? 0;
            _ambiance = review['ambiance'] ?? 0;
            _turnaroundTime = review['turnaround_time'] ?? review['tat_rating'] ?? 0;
            _responsivenessRate = review['responsiveness_rate'] ?? review['responsiveness'] ?? 0;
            _reviewTextController.text = review['review_text'] ?? '';
          } else {
            _resetForm();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading review: $e')));
      }
    }
  }

  void _resetForm() {
    _overallRating = 0;
    _foodQuality = 0;
    _serviceQuality = 0;
    _ambiance = 0;
    _turnaroundTime = 0;
    _responsivenessRate = 0;
    _reviewTextController.clear();
    _existingReview = null;
  }

  Future<void> _handleSubmitPressed() async {
    if (_selectedReservation == null || _selectedReservation!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a reservation')),
      );
      return;
    }

    if (_overallRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide an overall rating')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogCtx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _primaryGold.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _forestGreen.withValues(alpha: 0.08),
                    border: Border.all(color: _primaryGold.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(
                    Icons.rate_review_rounded,
                    color: _primaryGold,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Are you sure you want to submit this Review?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF330505),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your valuable feedback helps us maintain culinary excellence and improve guest experiences.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogCtx, false),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300, width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Not Yet',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogCtx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _forestGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          'Yes',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFFFFAEB),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      await _submitReview();
    }
  }

  Future<void> _submitReview() async {
    setState(() => _isSubmitting = true);

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      await _reservationService.upsertReview(
        reservationId: _selectedReservation!['id'],
        customerEmail: currentUser.email!,
        overallRating: _overallRating,
        foodQuality: _foodQuality,
        serviceQuality: _serviceQuality,
        ambiance: _ambiance,
        turnaroundTime: _turnaroundTime,
        responsivenessRate: _responsivenessRate,
        reviewText: _reviewTextController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your review!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const CustomerDashboardPage(initialIndex: 0),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error submitting review: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final isTablet = ResponsiveUtils.isTablet(context);

    return Scaffold(
      backgroundColor: _deepBurgundy,
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildHeaderBar(context),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: _warmGold,
                            strokeWidth: 3,
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async => _loadPastReservations(),
                          color: _warmGold,
                          backgroundColor: _darkForest,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: isDesktop ? 48 : (isTablet ? 28 : 16),
                              vertical: 20,
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: isDesktop ? 1100 : (isTablet ? 780 : 540),
                                ),
                                child: _pastReservations.isEmpty
                                    ? _buildEmptyState()
                                    : (isDesktop
                                        ? _buildDesktopLayout()
                                        : _buildMobileOrTabletLayout()),
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Realistic Restaurant Atmosphere Background
  Widget _buildBackground() {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/YangChow.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: const Color(0xFF220505)),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF280505).withValues(alpha: 0.93),
                    const Color(0xFF6E0D0D).withValues(alpha: 0.88),
                    const Color(0xFF8C1414).withValues(alpha: 0.84),
                    const Color(0xFF1E0303).withValues(alpha: 0.95),
                  ],
                ),
              ),
            ),
          ),
          // Ambient gold glow top-right
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _primaryGold.withValues(alpha: 0.28),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Ambient rich red glow bottom-left
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFBA1717).withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Center-right crimson lighting
          Positioned(
            top: 300,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF8C1414).withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Top App Bar matching Brand Identity
  Widget _buildHeaderBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        border: Border(
          bottom: BorderSide(
            color: _warmGold.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              shape: BoxShape.circle,
              border: Border.all(color: _warmGold.withValues(alpha: 0.4)),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Color(0xFFFFE8B2),
                size: 18,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'GUEST FEEDBACK',
                  style: GoogleFonts.cinzel(
                    color: _warmGold,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'Yang Chow Dining Experience',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFFFFAEB).withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 44), // balance back button width
        ],
      ),
    );
  }

  // Desktop Side-by-Side 2-Column Layout (Eliminates Dead Space)
  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Selected Booking & Dining Highlights Card
        Expanded(
          flex: 5,
          child: Column(
            children: [
              _buildCompactEventSelector(),
              const SizedBox(height: 18),
              _buildDiningHighlightsCard(),
            ],
          ),
        ),
        const SizedBox(width: 24),
        // Right Column: Experience Rating & Comments Card
        Expanded(
          flex: 7,
          child: _buildMainFormCard(),
        ),
      ],
    );
  }

  // Mobile / Tablet Stacked Layout
  Widget _buildMobileOrTabletLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCompactEventSelector(),
        const SizedBox(height: 16),
        _buildMainFormCard(),
      ],
    );
  }

  // Left Showcase Card for Desktop
  Widget _buildDiningHighlightsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _primaryGold.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _forestGreen.withValues(alpha: 0.08),
                  border: Border.all(color: _primaryGold.withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.rate_review_rounded, color: _primaryGold, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Review Matters',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF330505),
                      ),
                    ),
                    Text(
                      'Helps us maintain authentic quality',
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 14),
          _buildPerkItem(Icons.restaurant_menu_rounded, 'Authentic Chinese Culinary Standards', 'Food taste, aroma, freshness & portion satisfaction.'),
          const SizedBox(height: 12),
          _buildPerkItem(Icons.room_service_rounded, 'Attentive Table & Staff Service', 'Warm hospitality, speed, and order accuracy.'),
          const SizedBox(height: 12),
          _buildPerkItem(Icons.timer_rounded, 'Turnaround Time (TAT)', 'Prompt preparation, serving speed, and minimal waiting time.'),
          const SizedBox(height: 12),
          _buildPerkItem(Icons.support_agent_rounded, 'Responsiveness Rate', 'Helpful communication, quick assistance, and guest attentiveness.'),
          const SizedBox(height: 12),
          _buildPerkItem(Icons.deck_rounded, 'Atmosphere & Cleanliness', 'Cozy oriental interior, lighting, and comfortable seating.'),
        ],
      ),
    );
  }

  Widget _buildPerkItem(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: _forestGreen),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Main Review Card
  Widget _buildMainFormCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _primaryGold.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
          BoxShadow(
            color: _primaryGold.withValues(alpha: 0.15),
            blurRadius: 20,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Accent Stripe
            Container(
              height: 5,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryGold, _warmGold, _forestGreen],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Category Ratings Header
                  _buildCardSectionTitle(
                    'RATE YOUR EXPERIENCE',
                    'Tap the stars to score each category',
                    Icons.stars_rounded,
                  ),
                  const SizedBox(height: 16),

                  // Overall Rating
                  _buildInteractiveRatingCard(
                    title: 'OVERALL RATING',
                    subtitle: 'Overall dining satisfaction',
                    icon: Icons.star_rounded,
                    rating: _overallRating,
                    onRatingChanged: (val) => setState(() => _overallRating = val),
                    isPrimary: true,
                  ),
                  const SizedBox(height: 12),

                  // Food Quality
                  _buildInteractiveRatingCard(
                    title: 'FOOD QUALITY',
                    subtitle: 'Taste, temperature & presentation',
                    icon: Icons.restaurant_rounded,
                    rating: _foodQuality,
                    onRatingChanged: (val) => setState(() => _foodQuality = val),
                  ),
                  const SizedBox(height: 12),

                  // Service Quality
                  _buildInteractiveRatingCard(
                    title: 'SERVICE QUALITY',
                    subtitle: 'Staff attentiveness & friendliness',
                    icon: Icons.room_service_rounded,
                    rating: _serviceQuality,
                    onRatingChanged: (val) => setState(() => _serviceQuality = val),
                  ),
                  const SizedBox(height: 12),

                  // Turnaround Time (TAT)
                  _buildInteractiveRatingCard(
                    title: 'TURNAROUND TIME (TAT)',
                    subtitle: 'Order preparation speed & waiting time',
                    icon: Icons.timer_rounded,
                    rating: _turnaroundTime,
                    onRatingChanged: (val) => setState(() => _turnaroundTime = val),
                  ),
                  const SizedBox(height: 12),

                  // Responsiveness Rate
                  _buildInteractiveRatingCard(
                    title: 'RESPONSIVENESS RATE',
                    subtitle: 'Staff attentiveness & prompt communication',
                    icon: Icons.support_agent_rounded,
                    rating: _responsivenessRate,
                    onRatingChanged: (val) => setState(() => _responsivenessRate = val),
                  ),
                  const SizedBox(height: 12),

                  // Ambiance
                  _buildInteractiveRatingCard(
                    title: 'AMBIANCE',
                    subtitle: 'Atmosphere, music & cleanliness',
                    icon: Icons.deck_rounded,
                    rating: _ambiance,
                    onRatingChanged: (val) => setState(() => _ambiance = val),
                  ),
                  const SizedBox(height: 22),

                  // Additional Comments Section
                  _buildCardSectionTitle(
                    'YOUR FEEDBACK & COMMENTS',
                    'Share specific details, favorite dishes, or suggestions',
                    Icons.edit_note_rounded,
                  ),
                  const SizedBox(height: 12),

                  // Quick Suggestion Chips
                  _buildQuickReviewChips(),
                  const SizedBox(height: 10),

                  // Comment Text Field
                  TextField(
                    controller: _reviewTextController,
                    maxLines: 4,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. The Yang Chow Fried Rice and Dimsum were authentic and delicious! The staff were very accommodating...',
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.grey.shade400,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFFCFAF7),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(color: _primaryGold, width: 1.8),
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Submit Button matching Signature Red-Gold Theme
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: const LinearGradient(
                        colors: [
                          _forestGreen,
                          Color(0xFFBA1717),
                          _darkForest,
                        ],
                      ),
                      border: Border.all(
                        color: _warmGold.withValues(alpha: 0.55),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _forestGreen.withValues(alpha: 0.4),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isSubmitting ? null : _handleSubmitPressed,
                        borderRadius: BorderRadius.circular(10),
                        child: Center(
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.send_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _existingReview != null
                                          ? 'UPDATE GUEST REVIEW'
                                          : 'SUBMIT GUEST REVIEW',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.2,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),

                  if (_existingReview != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Submitting will update your previous review for this booking.',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF1E40AF),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardSectionTitle(String title, String subtitle, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: _forestGreen, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: const Color(0xFF330505),
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Quick Review Tags that add to the text controller
  Widget _buildQuickReviewChips() {
    final tags = [
      'Authentic Flavors! 🍲',
      'Fast & Courteous Service 🌟',
      'Generous Portions 🥢',
      'Cozy Ambiance ✨',
      'Will Visit Again! 👍',
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: tags.map((tag) {
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            final current = _reviewTextController.text.trim();
            if (current.isEmpty) {
              _reviewTextController.text = tag;
            } else if (!current.contains(tag)) {
              _reviewTextController.text = '$current $tag';
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFCFAF7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _primaryGold.withValues(alpha: 0.3)),
            ),
            child: Text(
              tag,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF330505),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // Interactive Modern Rating Bar Card
  Widget _buildInteractiveRatingCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required int rating,
    required Function(int) onRatingChanged,
    bool isPrimary = false,
  }) {
    final ratingLabels = [
      'Tap to rate',
      'Poor',
      'Fair',
      'Good',
      'Very Good',
      'Exceptional! ⭐',
    ];

    final scoreText = ratingLabels[rating.clamp(0, 5)];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isPrimary ? const Color(0xFFFFFBEB) : const Color(0xFFFCFAF7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPrimary
              ? _primaryGold.withValues(alpha: 0.5)
              : Colors.grey.shade200,
          width: isPrimary ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isPrimary ? _primaryGold : _forestGreen,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: rating > 0
                      ? Colors.amber.withValues(alpha: 0.15)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  rating > 0 ? '$rating ★  $scoreText' : 'Not rated',
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: rating > 0 ? const Color(0xFFB45309) : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 1; i <= 5; i++)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onRatingChanged(i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: AnimatedScale(
                          scale: i <= rating ? 1.08 : 0.95,
                          duration: const Duration(milliseconds: 150),
                          child: Icon(
                            i <= rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: i <= rating
                                ? const Color(0xFFF59E0B)
                                : Colors.grey.shade300,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Compact Booking Event Selector
  Widget _buildCompactEventSelector() {
    if (_selectedReservation == null) return const SizedBox.shrink();

    final eventType = _selectedReservation!['event_type'] ?? 'Dining Reservation';
    final date = _selectedReservation!['event_date'] ?? '';
    final time = _selectedReservation!['start_time'] ?? '';
    final guests = _selectedReservation!['guest_count']?.toString() ?? '1';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _primaryGold.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Gold Emblem Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      _warmGold.withValues(alpha: 0.2),
                      _primaryGold.withValues(alpha: 0.08),
                    ],
                  ),
                  border: Border.all(color: _warmGold.withValues(alpha: 0.5)),
                ),
                child: const Icon(
                  Icons.restaurant_rounded,
                  color: _primaryGold,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              // Booking Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            eventType,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        if (_existingReview != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              'Reviewed',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (date.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text(
                                date,
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        if (time.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.access_time_rounded, size: 12, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text(
                                time,
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline_rounded, size: 12, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(
                              '$guests pax',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Empty State when user has no bookings
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _primaryGold.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _primaryGold.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: _primaryGold.withValues(alpha: 0.4)),
            ),
            child: const Icon(
              Icons.rate_review_rounded,
              size: 54,
              color: _primaryGold,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Dining Bookings Found',
            style: GoogleFonts.playfairDisplay(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: const Color(0xFF330505),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Book an event or table reservation to share your dining experience and help us serve you better.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.grey.shade600,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: Text(
              'Back to Dashboard',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _forestGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _reviewTextController.dispose();
    super.dispose();
  }
}
