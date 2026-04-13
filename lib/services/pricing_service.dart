import 'package:flutter/foundation.dart';

/// Service to handle reservation pricing calculations
class PricingService {
  static final PricingService _instance = PricingService._internal();
  
  // Base pricing rates (can be moved to app settings later)
  static const double _baseRatePerHour = 500.0; // Base rate per hour
  static const double _ratePerGuest = 100.0; // Additional rate per guest
  static const double _depositPercentage = 50.0; // 50% deposit requirement
  
  // Duration pricing multipliers
  static const Map<int, double> _durationMultipliers = {
    2: 1.0,   // 2 hours - base rate
    3: 1.2,   // 3 hours - 20% premium
    4: 1.4,   // 4 hours - 40% premium
    5: 1.6,   // 5 hours - 60% premium
    6: 1.8,   // 6 hours - 80% premium
  };
  
  // Guest count pricing tiers
  static const Map<int, double> _guestMultipliers = {
    1: 1.0,    // 1-10 guests - base rate
    10: 1.0,   // 1-10 guests - base rate
    11: 1.1,   // 11-20 guests - 10% premium
    20: 1.1,   // 11-20 guests - 10% premium
    21: 1.2,   // 21-30 guests - 20% premium
    30: 1.2,   // 21-30 guests - 20% premium
    31: 1.3,   // 31-50 guests - 30% premium
    50: 1.3,   // 31-50 guests - 30% premium
    51: 1.5,   // 51+ guests - 50% premium
  };

  PricingService._internal();

  factory PricingService() {
    return _instance;
  }

  /// Calculate total price based on duration and guest count
  double calculateTotalPrice({
    required int durationHours,
    required int numberOfGuests,
    double? customBaseRate,
  }) {
    try {
      final baseRate = customBaseRate ?? _baseRatePerHour;
      
      // Get duration multiplier
      final durationMultiplier = _getDurationMultiplier(durationHours);
      
      // Get guest multiplier
      final guestMultiplier = _getGuestMultiplier(numberOfGuests);
      
      // Calculate base price (duration × base rate × duration multiplier)
      final basePrice = durationHours * baseRate * durationMultiplier;
      
      // Calculate guest premium (guest count × guest rate × guest multiplier)
      final guestPremium = numberOfGuests * _ratePerGuest * guestMultiplier;
      
      // Total price is base price + guest premium
      final totalPrice = basePrice + guestPremium;
      
      debugPrint('Pricing calculation:');
      debugPrint('Duration: ${durationHours}h × ${baseRate} × ${durationMultiplier.toStringAsFixed(2)} = ${basePrice.toStringAsFixed(2)}');
      debugPrint('Guests: ${numberOfGuests} × ${_ratePerGuest} × ${guestMultiplier.toStringAsFixed(2)} = ${guestPremium.toStringAsFixed(2)}');
      debugPrint('Total: ${totalPrice.toStringAsFixed(2)}');
      
      return totalPrice;
    } catch (e) {
      debugPrint('Error calculating price: $e');
      return 0.0;
    }
  }

  /// Calculate deposit amount (50% of total price)
  double calculateDepositAmount(double totalPrice) {
    return totalPrice * (_depositPercentage / 100);
  }

  /// Get duration multiplier based on hours
  double _getDurationMultiplier(int durationHours) {
    // Find the appropriate multiplier for the duration
    final keys = _durationMultipliers.keys.toList()..sort();
    
    for (int i = keys.length - 1; i >= 0; i--) {
      if (durationHours >= keys[i]) {
        return _durationMultipliers[keys[i]] ?? 1.0;
      }
    }
    
    return 1.0; // Default multiplier
  }

  /// Get guest multiplier based on number of guests
  double _getGuestMultiplier(int numberOfGuests) {
    // Find the appropriate multiplier for the guest count
    final keys = _guestMultipliers.keys.toList()..sort();
    
    for (int i = keys.length - 1; i >= 0; i--) {
      if (numberOfGuests >= keys[i]) {
        return _guestMultipliers[keys[i]] ?? 1.0;
      }
    }
    
    return 1.0; // Default multiplier
  }

  /// Get pricing breakdown for display
  Map<String, dynamic> getPricingBreakdown({
    required int durationHours,
    required int numberOfGuests,
    double? customBaseRate,
  }) {
    final baseRate = customBaseRate ?? _baseRatePerHour;
    final durationMultiplier = _getDurationMultiplier(durationHours);
    final guestMultiplier = _getGuestMultiplier(numberOfGuests);
    
    final basePrice = durationHours * baseRate * durationMultiplier;
    final guestPremium = numberOfGuests * _ratePerGuest * guestMultiplier;
    final totalPrice = basePrice + guestPremium;
    final depositAmount = calculateDepositAmount(totalPrice);
    
    return {
      'baseRate': baseRate,
      'durationHours': durationHours,
      'durationMultiplier': durationMultiplier,
      'basePrice': basePrice,
      'numberOfGuests': numberOfGuests,
      'guestMultiplier': guestMultiplier,
      'guestPremium': guestPremium,
      'totalPrice': totalPrice,
      'depositAmount': depositAmount,
      'depositPercentage': _depositPercentage,
      'remainingBalance': totalPrice - depositAmount,
    };
  }

  /// Validate pricing parameters
  String? validatePricingParams({
    required int durationHours,
    required int numberOfGuests,
    double? customBaseRate,
  }) {
    if (durationHours < 1 || durationHours > 12) {
      return 'Duration must be between 1 and 12 hours';
    }
    
    if (numberOfGuests < 1 || numberOfGuests > 200) {
      return 'Number of guests must be between 1 and 200';
    }
    
    if (customBaseRate != null && customBaseRate <= 0) {
      return 'Base rate must be greater than 0';
    }
    
    return null; // No validation errors
  }

  /// Get suggested price ranges for different durations
  Map<String, List<double>> getSuggestedPriceRanges(int numberOfGuests) {
    final ranges = <String, List<double>>{};
    
    for (int duration in [2, 3, 4, 5, 6]) {
      final minPrice = calculateTotalPrice(
        durationHours: duration,
        numberOfGuests: numberOfGuests,
        customBaseRate: _baseRatePerHour * 0.8, // 20% discount
      );
      
      final maxPrice = calculateTotalPrice(
        durationHours: duration,
        numberOfGuests: numberOfGuests,
        customBaseRate: _baseRatePerHour * 1.3, // 30% premium
      );
      
      ranges['${duration}h'] = [minPrice, maxPrice];
    }
    
    return ranges;
  }

  /// Format price for display
  String formatPrice(double price) {
    return 'PHP ${price.toStringAsFixed(2)}';
  }

  /// Check if price is within reasonable range
  bool isPriceReasonable({
    required int durationHours,
    required int numberOfGuests,
    required double price,
  }) {
    final suggestedPrice = calculateTotalPrice(
      durationHours: durationHours,
      numberOfGuests: numberOfGuests,
    );
    
    // Allow 50% variance from suggested price
    final minReasonable = suggestedPrice * 0.5;
    final maxReasonable = suggestedPrice * 1.5;
    
    return price >= minReasonable && price <= maxReasonable;
  }
}
