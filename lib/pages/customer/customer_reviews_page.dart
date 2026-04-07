import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';
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

      // Filter to only completed reservations (past events)
      final now = DateTime.now();
      final pastReservations = reservations.where((r) {
        try {
          final eventDate = DateTime.parse(r['event_date'] as String);
          return eventDate.isBefore(now) && r['status'] != 'cancelled';
        } catch (e) {
          return false;
        }
      }).toList();

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

      await _reservationService.addReview(
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
      appBar: AppBar(
        title: const Text('Leave a Review'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select a Past Reservation',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  if (_pastReservations.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'No past reservations to review. Visit us and come back!',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _pastReservations.length,
                      itemBuilder: (context, index) {
                        final reservation = _pastReservations[index];
                        final isSelected =
                            _selectedReservation?['id'] == reservation['id'];

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedReservation = reservation;
                            });
                            _loadExistingReview(reservation['id']);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              color: isSelected
                                  ? AppTheme.primaryColor.withValues(alpha: 0.05)
                                  : Colors.white,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  reservation['event_type'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Date: ${reservation['event_date']} at ${reservation['start_time']}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Guests: ${reservation['number_of_guests']}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                  if (_selectedReservation != null &&
                      _selectedReservation!.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 32),
                    const Text(
                      'Your Rating',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildRatingCategory(
                      title: 'Overall Experience',
                      rating: _overallRating,
                      onRatingChanged: (rating) {
                        setState(() => _overallRating = rating);
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildRatingCategory(
                      title: 'Food Quality',
                      rating: _foodQuality,
                      onRatingChanged: (rating) {
                        setState(() => _foodQuality = rating);
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildRatingCategory(
                      title: 'Service Quality',
                      rating: _serviceQuality,
                      onRatingChanged: (rating) {
                        setState(() => _serviceQuality = rating);
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildRatingCategory(
                      title: 'Ambiance & Atmosphere',
                      rating: _ambiance,
                      onRatingChanged: (rating) {
                        setState(() => _ambiance = rating);
                      },
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Your Review (Optional)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _reviewTextController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Share your experience...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitReview,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Submit Review',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    if (_existingReview != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade300),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'You have already reviewed this reservation. Your changes will update the existing review.',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 12,
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
        Text(title),
        const SizedBox(height: 8),
        Row(
          children: [
            for (int i = 1; i <= 5; i++)
              GestureDetector(
                onTap: () => onRatingChanged(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    i <= rating ? Icons.star : Icons.star_outline,
                    color: i <= rating ? Colors.amber : Colors.grey.shade400,
                    size: 32,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _reviewTextController.dispose();
    super.dispose();
  }
}
