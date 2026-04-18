import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:yang_chow/services/reservation_service.dart';

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
  final TextEditingController _reviewTextController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;

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

      // Filter to only COMPLETED reservations as per requirement
      final pastReservations = reservations.where((r) => r['status'] == 'completed').toList();

      if (mounted) {
        setState(() {
          _pastReservations = pastReservations;
          _isLoading = false;

          // If a specific reservation was passed, select it
          if (widget.reservationId != null) {
            _selectedReservation = pastReservations.firstWhere(
              (r) => r['id'] == widget.reservationId,
              orElse: () => {},
            );
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
    _reviewTextController.clear();
    _existingReview = null;
  }

  void _submitReview() async {
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
        reviewText: _reviewTextController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your review!'),
            backgroundColor: Colors.green,
          ),
        );
        _resetForm();
        _loadPastReservations();
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
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'GUEST FEEDBACK',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.darkGrey,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: ResponsiveUtils.getMaxContentWidth()),
                  child: Padding(
                    padding: ResponsiveUtils.getResponsivePadding(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                          title: 'SELECT RESERVATION',
                          subtitle: 'You can review any of your completed events',
                        ),
                        const SizedBox(height: 24),

                  if (_pastReservations.isEmpty)
                    _buildEmptyState()
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _pastReservations.length,
                      itemBuilder: (context, index) {
                        final reservation = _pastReservations[index];
                        final isSelected =
                            _selectedReservation?['id'] == reservation['id'];

                        return _buildReservationCard(reservation, isSelected);
                      },
                    ),

                  if (_selectedReservation != null &&
                      _selectedReservation!.isNotEmpty) ...[
                    const SizedBox(height: 40),
                    _buildSectionHeader(
                      title: 'YOUR EXPERIENCE',
                      subtitle: 'How was the food, service, and ambiance?',
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: AppTheme.cardDecoration(),
                      child: Column(
                        children: [
                          _buildRatingCategory(
                            title: 'OVERALL RATING',
                            rating: _overallRating,
                            onRatingChanged: (rating) {
                              setState(() => _overallRating = rating);
                            },
                          ),
                          const Divider(height: 40),
                          _buildRatingCategory(
                            title: 'FOOD QUALITY',
                            rating: _foodQuality,
                            onRatingChanged: (rating) {
                              setState(() => _foodQuality = rating);
                            },
                          ),
                          const Divider(height: 40),
                          _buildRatingCategory(
                            title: 'SERVICE QUALITY',
                            rating: _serviceQuality,
                            onRatingChanged: (rating) {
                              setState(() => _serviceQuality = rating);
                            },
                          ),
                          const Divider(height: 40),
                          _buildRatingCategory(
                            title: 'AMBIANCE',
                            rating: _ambiance,
                            onRatingChanged: (rating) {
                              setState(() => _ambiance = rating);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildSectionHeader(
                      title: 'ADDITIONAL COMMENTS',
                      subtitle: 'Optional feedback to help us improve',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _reviewTextController,
                      maxLines: 5,
                      style: const TextStyle(fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Share your experience...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(20),
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitReview,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                          shadowColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                        ),
                        child: _isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                _existingReview != null ? 'UPDATE REVIEW' : 'SUBMIT REVIEW',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                      ),
                    ),
                    if (_existingReview != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.infoBlue.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.infoBlue.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, color: AppTheme.infoBlue, size: 20),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'You have an existing review. Your changes will update the previous entry to keep our landing page focused on your latest experience.',
                                  style: TextStyle(
                                    color: AppTheme.infoBlue,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRatingCategory({
    required String title,
    required int rating,
    required Function(int) onRatingChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 1),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 1; i <= 5; i++)
              GestureDetector(
                onTap: () => onRatingChanged(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: i <= rating ? Colors.amber : AppTheme.lightGrey,
                    size: 40,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.mediumGrey.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildReservationCard(Map<String, dynamic> reservation, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() => _selectedReservation = reservation);
        _loadExistingReview(reservation['id']);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.1) : AppTheme.lightGrey.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_available_rounded,
                color: isSelected ? AppTheme.primaryColor : AppTheme.mediumGrey,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reservation['event_type'],
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppTheme.darkGrey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${reservation['event_date']} • ${reservation['start_time']}',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.mediumGrey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.lightGrey.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Icon(Icons.rate_review_outlined, size: 64, color: AppTheme.mediumGrey.withValues(alpha: 0.3)),
          const SizedBox(height: 24),
          const Text(
            'NO COMPLETED EVENTS',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete a reservation to unlock feedback options.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.mediumGrey, fontSize: 13),
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
