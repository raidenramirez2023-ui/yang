import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:intl/intl.dart';

class RemainingBalanceTrackingPage extends StatefulWidget {
  final bool isFullscreen;
  const RemainingBalanceTrackingPage({super.key, this.isFullscreen = false});

  @override
  State<RemainingBalanceTrackingPage> createState() => _RemainingBalanceTrackingPageState();
}

class _RemainingBalanceTrackingPageState extends State<RemainingBalanceTrackingPage> {
  List<Map<String, dynamic>> _reservationsWithBalance = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // Only reservations
  int _currentPage = 0;
  final int _rowsPerPage = 10;
  String _searchQuery = '';
  
  final ScrollController _horizontalScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load reservations with deposit_paid status
      final reservationsResponse = await Supabase.instance.client
          .from('reservations')
          .select('*')
          .eq('payment_status', 'deposit_paid')
          .neq('is_archived', true)
          .order('created_at', ascending: false);

      setState(() {
        _reservationsWithBalance = List<Map<String, dynamic>>.from(reservationsResponse);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading balance data: $e');
      setState(() => _isLoading = false);
      _showSnackBar('Error loading data: $e', Colors.red);
    }
  }

  Future<void> _markAsFullyPaid({
    required String id,
    required String table,
    required String customerEmail,
    required String customerName,
    required String eventType,
  }) async {
    try {
      // First, get the current data to retrieve total_price
      final currentData = await Supabase.instance.client
          .from('reservations')
          .select('total_price')
          .eq('id', id)
          .single();

      final totalPrice = (currentData['total_price'] as num?)?.toDouble() ?? 0.0;

      final updates = <String, dynamic>{
        'payment_status': 'fully_paid',
        'remaining_balance': 0,
        'payment_amount': totalPrice,
        'status': 'confirmed',
        'updated_at': DateTime.now().toIso8601String(),
      };

      await Supabase.instance.client
          .from('reservations')
          .update(updates)
          .eq('id', id);

      _showSnackBar('Marked as fully paid', Colors.green);
      _loadData(); // Refresh the list
    } catch (e) {
      debugPrint('Error marking as fully paid: $e');
      _showSnackBar('Error updating payment: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.green ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredData {
    if (_searchQuery.isEmpty) {
      return _reservationsWithBalance;
    }
    
    final query = _searchQuery.toLowerCase();
    return _reservationsWithBalance.where((item) {
      final customerName = (item['customer_name'] as String?)?.toLowerCase() ?? '';
      final orderId = item['id'].toString().toLowerCase();
      final customerEmail = (item['customer_email'] as String?)?.toLowerCase() ?? '';
      final eventType = (item['event_type'] as String?)?.toLowerCase() ?? '';
      
      return customerName.contains(query) ||
             orderId.contains(query) ||
             customerEmail.contains(query) ||
             eventType.contains(query);
    }).toList();
  }

  double _calculateRemainingBalance(Map<String, dynamic> item) {
    final totalPrice = (item['total_price'] as num?)?.toDouble() ?? 0.0;
    final depositAmount = (item['deposit_amount'] as num?)?.toDouble() ?? 0.0;
    final remainingBalance = (item['remaining_balance'] as num?)?.toDouble();
    
    // Use stored remaining_balance if available, otherwise calculate
    if (remainingBalance != null) return remainingBalance;
    return totalPrice - depositAmount;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);

    return Padding(
      padding: isDesktop 
          ? EdgeInsets.zero 
          : ResponsiveUtils.getResponsivePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          if (!widget.isFullscreen)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 20 : 0,
                vertical: isDesktop ? 16 : 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Accounts with Remaining Balance',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getResponsiveFontSize(
                          context,
                          mobile: 20,
                          tablet: 24,
                          desktop: 28,
                        ),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (!isDesktop) ResponsiveUtils.verticalSpace(context, mobile: 16, tablet: 20, desktop: 24),
          Expanded(
            child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBar(),
          const SizedBox(height: 16),
          _buildFilterSegmentControl(),
          const SizedBox(height: 20),
          Expanded(child: _buildDataTable()),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildSearchBar(),
        ResponsiveUtils.verticalSpace(context, mobile: 16, tablet: 20, desktop: 24),
        _buildFilterSegmentControl(),
        ResponsiveUtils.verticalSpace(context, mobile: 16, tablet: 20, desktop: 24),
        Expanded(
          child: _buildCardList(),
        ),
      ],
    );
  }

  Widget _buildFilterSegmentControl() {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    final counts = {
      'all': _reservationsWithBalance.length,
    };

    final filters = [
      {'value': 'all', 'label': 'All Reservations'},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.sm),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isMobile
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: filters.map((f) => _buildSegmentButton(
                  f['value'] as String, 
                  f['label'] as String,
                  count: counts[f['value']] ?? 0,
                )).toList(),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: filters.map((f) => Expanded(
                child: _buildSegmentButton(
                  f['value'] as String, 
                  f['label'] as String,
                  count: counts[f['value']] ?? 0,
                ),
              )).toList(),
            ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
            _currentPage = 0;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search by customer name, order ID, email, or event type...',
          hintStyle: TextStyle(
            color: AppTheme.mediumGrey,
            fontSize: 14,
          ),
          prefixIcon: const Icon(Icons.search, color: AppTheme.mediumGrey),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppTheme.mediumGrey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _currentPage = 0;
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: const Color(0xFFF8F9FA),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildSegmentButton(String value, String label, {int count = 0}) {
    final isSelected = _selectedFilter == value;
    final isMobile = ResponsiveUtils.isMobile(context);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = value;
          _currentPage = 0;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          vertical: AppTheme.md,
          horizontal: isMobile ? AppTheme.lg : AppTheme.md,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.white : AppTheme.mediumGrey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: isMobile ? 13 : 14,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withOpacity(0.25) : AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    color: isSelected ? AppTheme.white : AppTheme.primaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
        ),
      );
    }

    final filtered = _filteredData;
    if (filtered.isEmpty) {
      return _buildEmptyState();
    }

    final isMobile = ResponsiveUtils.isMobile(context);
    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage < filtered.length) 
        ? startIndex + _rowsPerPage 
        : filtered.length;
    final paginatedData = filtered.sublist(startIndex, endIndex);
    
    return Container(
      constraints: const BoxConstraints(minHeight: double.infinity),
      child: Card(
        elevation: isMobile ? 1 : 2,
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: _horizontalScrollController,
                  child: DataTable(
                  columnSpacing: 30,
                  horizontalMargin: 16,
                  headingRowHeight: 48,
                  dataRowMinHeight: 48,
                  dataRowMaxHeight: 56,
                  headingRowColor: WidgetStateProperty.all(AppTheme.primaryColor.withOpacity(0.04)),
                  headingTextStyle: const TextStyle(
                    color: AppTheme.darkGrey,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
                  columns: [
                    DataColumn(label: _buildColumnHeader('Customer', Icons.person_outline)),
                    DataColumn(label: _buildColumnHeader('Order ID', Icons.tag)),
                    DataColumn(label: _buildColumnHeader('Reservation Date', Icons.calendar_today)),
                    DataColumn(label: _buildColumnHeader('Event Date', Icons.event)),
                    DataColumn(label: _buildColumnHeader('Total', Icons.attach_money)),
                    DataColumn(label: _buildColumnHeader('Paid', Icons.payment)),
                    DataColumn(label: _buildColumnHeader('Remaining', Icons.account_balance_wallet)),
                    DataColumn(label: _buildColumnHeader('Actions', Icons.settings)),
                  ],
                  rows: paginatedData.map((item) {
                    final remainingBalance = _calculateRemainingBalance(item);
                    final totalPrice = (item['total_price'] as num?)?.toDouble() ?? 0.0;
                    final depositAmount = (item['deposit_amount'] as num?)?.toDouble() ?? 0.0;
                    
                    return DataRow(
                      cells: [
                        DataCell(
                          SizedBox(
                            width: 220,
                            child: Text(
                              item['customer_name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 120,
                            child: Text(
                              item['id'].toString().substring(0, 8),
                              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 100,
                            child: Text(
                              _formatDate(item['created_at']?.toString() ?? ''),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 100,
                            child: Text(
                              _formatDate(item['event_date']?.toString() ?? ''),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 120,
                            child: Text(
                              '₱${totalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 120,
                            child: Text(
                              '₱${depositAmount.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 12, color: Colors.green),
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 140,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '₱${remainingBalance.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 200,
                            child: ElevatedButton.icon(
                              onPressed: () => _showMarkPaidDialog(item, true),
                              icon: const Icon(Icons.check_circle, size: 16),
                              label: const Text('Mark Paid', style: TextStyle(fontSize: 11)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                minimumSize: const Size(160, 32),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          if (filtered.length > _rowsPerPage)
            _buildPaginationControls(filtered.length),
        ],
      ),
      ),
    );
  }

  Widget _buildCardList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
        ),
      );
    }

    final filtered = _filteredData;
    if (filtered.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        final remainingBalance = _calculateRemainingBalance(item);
        final totalPrice = (item['total_price'] as num?)?.toDouble() ?? 0.0;
        final depositAmount = (item['deposit_amount'] as num?)?.toDouble() ?? 0.0;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item['customer_name'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Event Reservation',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInfoRow('Order ID', item['id'].toString().substring(0, 8)),
                _buildInfoRow('Reservation Date', _formatDate(item['created_at']?.toString() ?? '')),
                _buildInfoRow('Event Date', _formatDate(item['event_date']?.toString() ?? '')),
                _buildInfoRow('Total Amount', '₱${totalPrice.toStringAsFixed(2)}'),
                _buildInfoRow('Amount Paid (Deposit)', '₱${depositAmount.toStringAsFixed(2)}', color: Colors.green),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Remaining Balance',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₱${remainingBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showMarkPaidDialog(item, true),
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: const Text('Mark as Fully Paid'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.mediumGrey,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: color ?? AppTheme.darkGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationControls(int totalItems) {
    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage < totalItems) 
        ? startIndex + _rowsPerPage 
        : totalItems;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '${startIndex + 1}-$endIndex of $totalItems',
            style: const TextStyle(fontSize: 13, color: AppTheme.darkGrey, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 0 
                ? () => setState(() => _currentPage--) 
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: endIndex < totalItems 
                ? () => setState(() => _currentPage++) 
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: AppTheme.mediumGrey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No accounts with remaining balance',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.mediumGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All accounts have been fully paid',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.mediumGrey.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnHeader(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.darkGrey),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  void _showMarkPaidDialog(Map<String, dynamic> item, bool isReservation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Fully Paid'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${item['customer_name'] ?? 'Unknown'}'),
            const SizedBox(height: 8),
            Text('Event Type: ${item['event_type'] ?? 'N/A'}'),
            const SizedBox(height: 8),
            Text('Total: ₱${((item['total_price'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            Text('Paid: ₱${((item['deposit_amount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            Text(
              'Remaining: ₱${_calculateRemainingBalance(item).toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const SizedBox(height: 16),
            const Text('Are you sure you want to mark this as fully paid?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _markAsFullyPaid(
                id: item['id'],
                table: 'reservations',
                customerEmail: item['customer_email'] ?? '',
                customerName: item['customer_name'] ?? '',
                eventType: item['event_type'],
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
