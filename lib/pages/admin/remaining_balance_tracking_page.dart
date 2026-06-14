import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:intl/intl.dart';
import 'package:yang_chow/services/notification_service.dart';

class RemainingBalanceTrackingPage extends StatefulWidget {
  final bool isFullscreen;
  const RemainingBalanceTrackingPage({super.key, this.isFullscreen = false});

  @override
  State<RemainingBalanceTrackingPage> createState() => _RemainingBalanceTrackingPageState();
}

class _RemainingBalanceTrackingPageState extends State<RemainingBalanceTrackingPage> {
  List<Map<String, dynamic>> _reservationsWithBalance = [];
  bool _isLoading = true;
  int _currentPage = 0;
  final int _rowsPerPage = 10;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
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

      // Send notification to customer
      try {
        await NotificationService.sendNotification(
          recipientEmail: customerEmail,
          actorName: 'Admin',
          actionType: 'paid', // Show payment icon
          reservationId: id,
          eventType: '$eventType — Remaining Balance Cleared',
        );
      } catch (e) {
        debugPrint('Warning: remaining balance notification failed: $e');
      }

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
      padding: const EdgeInsets.only(left: 20, right: 20, top: 0, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCards(),
          const SizedBox(height: 14),
          _buildSearchBar(),
          const SizedBox(height: 12),
          Expanded(child: _buildDataTable()),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildSummaryCards(),
        const SizedBox(height: 16),
        _buildSearchBar(),
        ResponsiveUtils.verticalSpace(context, mobile: 16, tablet: 20, desktop: 24),
        Expanded(
          child: _buildCardList(),
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    double totalOutstanding = 0;
    double totalCollected = 0;
    
    for (var item in _reservationsWithBalance) {
      totalOutstanding += _calculateRemainingBalance(item);
      totalCollected += (item['deposit_amount'] as num?)?.toDouble() ?? 0.0;
    }
    
    final totalAccounts = _reservationsWithBalance.length;

    final cards = [
      _buildMetricCard(
        title: 'Outstanding Balance',
        value: '₱${totalOutstanding.toStringAsFixed(2)}',
        subtitle: 'Sisingilin pa',
        icon: Icons.account_balance_wallet_outlined,
        color: Colors.red,
      ),
      _buildMetricCard(
        title: 'Total Collected',
        value: '₱${totalCollected.toStringAsFixed(2)}',
        subtitle: 'Naibayad na deposit',
        icon: Icons.check_circle_outline,
        color: Colors.green,
      ),
      _buildMetricCard(
        title: 'Pending Accounts',
        value: '$totalAccounts',
        subtitle: 'May natitirang bayad',
        icon: Icons.people_outline,
        color: Colors.blue,
      ),
    ];

    if (isMobile) {
      return Column(
        children: cards.map((card) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: card,
        )).toList(),
      );
    }

    return Row(
      children: cards.map((card) => Expanded(
        child: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: card,
        ),
      )).toList()..last = Expanded(child: cards.last),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: color.withOpacity(0.15), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.mediumGrey,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppTheme.darkGrey,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppTheme.mediumGrey.withOpacity(0.8),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildSearchBar() {
    final isMobile = ResponsiveUtils.isMobile(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: isMobile ? 12 : 6),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
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
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search by customer name, order ID, email, or event type...',
          hintStyle: const TextStyle(
            color: AppTheme.mediumGrey,
            fontSize: 13,
          ),
          prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.mediumGrey),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: AppTheme.mediumGrey),
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
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: const Color(0xFFF8F9FA),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double tableWidth = constraints.maxWidth;
                  // Horizontal margin is 16 on each side (total 32).
                  // Column spacing is 12. For 8 columns, there are 7 gaps (total 84).
                  final double availableWidth = (tableWidth - 32 - 84).clamp(0.0, double.infinity);
                  
                  // Proportional widths for desktop columns
                  final double customerWidth = availableWidth * 0.18;
                  final double orderIdWidth = availableWidth * 0.10;
                  final double reservationDateWidth = availableWidth * 0.11;
                  final double eventDateWidth = availableWidth * 0.11;
                  final double totalWidth = availableWidth * 0.11;
                  final double paidWidth = availableWidth * 0.11;
                  final double remainingWidth = availableWidth * 0.12;
                  final double actionsWidth = availableWidth * 0.16;

                  return SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SizedBox(
                      width: tableWidth,
                      child: DataTable(
                        columnSpacing: 12,
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
                          int rowIndex = paginatedData.indexOf(item);
                          final remainingBalance = _calculateRemainingBalance(item);
                          final totalPrice = (item['total_price'] as num?)?.toDouble() ?? 0.0;
                          final depositAmount = (item['deposit_amount'] as num?)?.toDouble() ?? 0.0;
                          
                          return DataRow(
                            color: WidgetStateProperty.resolveWith<Color?>((states) {
                              if (states.contains(WidgetState.hovered)) {
                                return AppTheme.primaryColor.withOpacity(0.04);
                              }
                              if (rowIndex.isEven) {
                                return Colors.grey.withOpacity(0.018);
                              }
                              return null;
                            }),
                            cells: [
                              DataCell(
                                SizedBox(
                                  width: customerWidth,
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
                                  width: orderIdWidth,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(color: Colors.grey.withOpacity(0.15)),
                                    ),
                                    child: Text(
                                      '#${item['id'].toString().substring(0, 8)}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontFamily: 'monospace',
                                        color: AppTheme.darkGrey.withOpacity(0.7),
                                        letterSpacing: 0.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: reservationDateWidth,
                                  child: Text(
                                    _formatDate(item['created_at']?.toString() ?? ''),
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: eventDateWidth,
                                  child: Text(
                                    _formatDate(item['event_date']?.toString() ?? ''),
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: totalWidth,
                                  child: Text(
                                    '₱${totalPrice.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: paidWidth,
                                  child: Text(
                                    '₱${depositAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 12, color: Colors.green),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: remainingWidth,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.red.withOpacity(0.25)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.warning_amber_rounded,
                                          size: 12,
                                          color: Colors.red,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            '₱${remainingBalance.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: actionsWidth,
                                  child: Tooltip(
                                    message: 'Mark this account as fully paid',
                                    child: ElevatedButton.icon(
                                      onPressed: () => _showMarkPaidDialog(item, true),
                                      icon: const Icon(Icons.check_circle_outline, size: 14),
                                      label: const Text('Mark Paid', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryColor,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shadowColor: Colors.transparent,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        minimumSize: const Size(100, 32),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
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
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: Colors.grey.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // Accent left border
                  Container(
                    width: 4,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppTheme.primaryColor, Color(0xFFFF6B6B)],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['customer_name'] ?? 'Unknown',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.darkGrey,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    // Order ID chip
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.grey.withOpacity(0.15)),
                                      ),
                                      child: Text(
                                        '#${item['id'].toString().substring(0, 8)}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontFamily: 'monospace',
                                          color: AppTheme.mediumGrey.withOpacity(0.8),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Event type badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                                ),
                                child: Text(
                                  item['event_type']?.toString() ?? 'Reservation',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          // Divider
                          Divider(color: Colors.grey.withOpacity(0.1), height: 1),
                          const SizedBox(height: 12),
                          // Info rows
                          _buildInfoRow(
                            'Reservation Date',
                            _formatDate(item['created_at']?.toString() ?? ''),
                            icon: Icons.calendar_today_outlined,
                          ),
                          _buildInfoRow(
                            'Event Date',
                            _formatDate(item['event_date']?.toString() ?? ''),
                            icon: Icons.event_outlined,
                          ),
                          _buildInfoRow(
                            'Total Amount',
                            '₱${totalPrice.toStringAsFixed(2)}',
                            icon: Icons.attach_money,
                          ),
                          _buildInfoRow(
                            'Deposit Paid',
                            '₱${depositAmount.toStringAsFixed(2)}',
                            icon: Icons.check_circle_outline,
                            color: Colors.green,
                          ),
                          const SizedBox(height: 8),
                          // Remaining balance highlight
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.withOpacity(0.2)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Remaining Balance',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.darkGrey,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '₱${remainingBalance.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 15,
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
                              icon: const Icon(Icons.check_circle_outline, size: 18),
                              label: const Text('Mark as Fully Paid', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? color, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: AppTheme.mediumGrey),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.mediumGrey,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
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
    final totalPages = (totalItems / _rowsPerPage).ceil();
    final currentPageDisplay = _currentPage + 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.02),
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.12))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '${startIndex + 1}–$endIndex of $totalItems',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.mediumGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '· Page $currentPageDisplay of $totalPages',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.mediumGrey.withOpacity(0.6),
            ),
          ),
          const SizedBox(width: 16),
          _buildPaginationButton(
            icon: Icons.chevron_left,
            onTap: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
          ),
          const SizedBox(width: 4),
          _buildPaginationButton(
            icon: Icons.chevron_right,
            onTap: endIndex < totalItems ? () => setState(() => _currentPage++) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationButton({required IconData icon, VoidCallback? onTap}) {
    final bool enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled ? AppTheme.white : Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? Colors.grey.withOpacity(0.25) : Colors.grey.withOpacity(0.1),
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? AppTheme.primaryColor : AppTheme.mediumGrey.withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              size: 56,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'All Accounts Cleared!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkGrey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No outstanding balances at this time.\nAll accounts have been fully settled.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.mediumGrey,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnHeader(String label, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppTheme.darkGrey),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
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
