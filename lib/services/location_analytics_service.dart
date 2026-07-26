import 'package:supabase_flutter/supabase_flutter.dart';

class LocationAnalyticsService {
  final _supabase = Supabase.instance.client;

  /// Get customer location analytics aggregated by city/municipality
  /// Returns a list of locations with order count and total revenue
  Future<List<Map<String, dynamic>>> getLocationAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final response = await _supabase
          .from('orders')
          .select('customer_address, discount_address, total_amount, created_at')
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> orders = List<Map<String, dynamic>>.from(response);

      // Filter by date range if provided
      List<Map<String, dynamic>> filteredOrders = orders;
      if (startDate != null) {
        filteredOrders = filteredOrders.where((order) {
          final date = DateTime.tryParse(order['created_at'] ?? '');
          return date != null && date.isAfter(startDate);
        }).toList();
      }
      if (endDate != null) {
        filteredOrders = filteredOrders.where((order) {
          final date = DateTime.tryParse(order['created_at'] ?? '');
          return date != null && date.isBefore(endDate);
        }).toList();
      }

      // Aggregate by location
      Map<String, Map<String, dynamic>> locationData = {};

      for (var order in filteredOrders) {
        // Use discount_address if available (for orders with discount), otherwise use customer_address
        final discountAddress = (order['discount_address'] as String?)?.trim();
        final customerAddress = (order['customer_address'] as String?)?.trim();
        final location = (discountAddress?.isNotEmpty == true ? discountAddress : customerAddress) ?? 'Unknown';
        
        // Skip if location is still empty or unknown
        if (location.isEmpty || location == 'Unknown') continue;
        
        final amount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;

        if (!locationData.containsKey(location)) {
          locationData[location] = {
            'location': location,
            'order_count': 0,
            'total_revenue': 0.0,
          };
        }

        locationData[location]!['order_count'] = locationData[location]!['order_count'] + 1;
        locationData[location]!['total_revenue'] = locationData[location]!['total_revenue'] + amount;
      }

      // Convert to list and sort by order count (descending)
      final List<Map<String, dynamic>> result = locationData.values.toList()
        ..sort((a, b) => (b['order_count'] as int).compareTo(a['order_count'] as int));

      return result;
    } catch (e) {
      print('Error fetching location analytics: $e');
      return [];
    }
  }

  /// Get top N locations by order count
  Future<List<Map<String, dynamic>>> getTopLocationsByOrderCount({
    int limit = 10,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final allLocations = await getLocationAnalytics(
      startDate: startDate,
      endDate: endDate,
    );

    // Sort by order count (descending)
    allLocations.sort((a, b) => (b['order_count'] as int).compareTo(a['order_count'] as int));
    return allLocations.take(limit).toList();
  }

  /// Get top N locations by revenue
  Future<List<Map<String, dynamic>>> getTopLocationsByRevenue({
    int limit = 10,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final allLocations = await getLocationAnalytics(
      startDate: startDate,
      endDate: endDate,
    );

    // Sort by total revenue (descending)
    allLocations.sort((a, b) => (b['total_revenue'] as double).compareTo(a['total_revenue'] as double));
    return allLocations.take(limit).toList();
  }

  /// Get location trend data over time (monthly breakdown)
  Future<Map<String, List<Map<String, dynamic>>>> getLocationTrend({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final response = await _supabase
          .from('orders')
          .select('customer_address, discount_address, total_amount, created_at')
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> orders = List<Map<String, dynamic>>.from(response);

      // Filter by date range if provided
      List<Map<String, dynamic>> filteredOrders = orders;
      if (startDate != null) {
        filteredOrders = filteredOrders.where((order) {
          final date = DateTime.tryParse(order['created_at'] ?? '');
          return date != null && date.isAfter(startDate);
        }).toList();
      }
      if (endDate != null) {
        filteredOrders = filteredOrders.where((order) {
          final date = DateTime.tryParse(order['created_at'] ?? '');
          return date != null && date.isBefore(endDate);
        }).toList();
      }

      // Aggregate by location and month
      Map<String, Map<String, Map<String, dynamic>>> trendData = {};

      for (var order in filteredOrders) {
        // Use discount_address if available (for orders with discount), otherwise use customer_address
        final discountAddress = (order['discount_address'] as String?)?.trim();
        final customerAddress = (order['customer_address'] as String?)?.trim();
        final location = (discountAddress?.isNotEmpty == true ? discountAddress : customerAddress) ?? 'Unknown';
        
        // Skip if location is still empty or unknown
        if (location.isEmpty || location == 'Unknown') continue;
        
        final date = DateTime.tryParse(order['created_at'] ?? '');
        if (date == null) continue;

        final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';

        if (!trendData.containsKey(location)) {
          trendData[location] = {};
        }

        if (!trendData[location]!.containsKey(monthKey)) {
          trendData[location]![monthKey] = {
            'month': monthKey,
            'order_count': 0,
            'total_revenue': 0.0,
          };
        }

        trendData[location]![monthKey]!['order_count'] = trendData[location]![monthKey]!['order_count'] + 1;
        trendData[location]![monthKey]!['total_revenue'] = trendData[location]![monthKey]!['total_revenue'] + ((order['total_amount'] as num?)?.toDouble() ?? 0.0);
      }

      // Convert to more usable format
      Map<String, List<Map<String, dynamic>>> result = {};
      trendData.forEach((location, monthData) {
        result[location] = monthData.values.toList()
          ..sort((a, b) => (a['month'] as String).compareTo(b['month'] as String));
      });

      return result;
    } catch (e) {
      print('Error fetching location trend: $e');
      return {};
    }
  }
}
