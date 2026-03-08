import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';

class AdminReservationsPage extends StatefulWidget {
  const AdminReservationsPage({super.key});

  @override
  State<AdminReservationsPage> createState() => _AdminReservationsPageState();
}

class _AdminReservationsPageState extends State<AdminReservationsPage> {
  List<Map<String, dynamic>> reservations = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, pending, confirmed, cancelled

  @override
  void initState() {
    super.initState();
    _loadReservations();
  }

  Future<void> _loadReservations() async {
    setState(() => _isLoading = true);
    
    try {
      // Debug: Check current user
      final currentUser = Supabase.instance.client.auth.currentUser;
      debugPrint('Current user: ${currentUser?.email}');
      debugPrint('Current user metadata: ${currentUser?.userMetadata}');
      
      final response = await Supabase.instance.client
          .from('reservations')
          .select('*')
          .order('created_at', ascending: false);

      debugPrint('Reservations loaded: ${response.length}');
      debugPrint('Response: $response');

      setState(() {
        reservations = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading reservations: $e');
      setState(() => _isLoading = false);
      _showSnackBar('Error loading reservations: $e', Colors.red);
    }
  }

  Future<void> _deleteReservation(String reservationId) async {
  try {
    await Supabase.instance.client
        .from('reservations')
        .delete()
        .eq('id', reservationId);

    _showSnackBar('Reservation deleted successfully', Colors.green);
    _loadReservations(); // Refresh the list
  } catch (e) {
    _showSnackBar('Error deleting reservation: $e', Colors.red);
  }
}

  Future<void> _updateReservationStatus(String reservationId, String newStatus) async {
    try {
      await Supabase.instance.client
          .from('reservations')
          .update({'status': newStatus, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', reservationId);

      _showSnackBar('Reservation status updated to $newStatus', Colors.green);
      _loadReservations(); // Refresh the list
    } catch (e) {
      _showSnackBar('Error updating reservation: $e', Colors.red);
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

  List<Map<String, dynamic>> get _filteredReservations {
    if (_selectedFilter == 'all') return reservations;
    return reservations.where((r) => r['status'] == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);

    return Padding(
      padding: ResponsiveUtils.getResponsivePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with refresh button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Reservations Management',
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
              IconButton(
                onPressed: _loadReservations,
                icon: Icon(
                  Icons.refresh,
                  size: ResponsiveUtils.getResponsiveIconSize(context),
                ),
                tooltip: 'Refresh',
              ),
            ],
          ),
          ResponsiveUtils.verticalSpace(context, mobile: 16, tablet: 20, desktop: 24),
          Expanded(
            child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      children: [
        _buildFilterSection(),
        ResponsiveUtils.verticalSpace(context, mobile: 20, tablet: 24, desktop: 28),
        Expanded(child: _buildReservationsTable()),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildFilterSection(),
        ResponsiveUtils.verticalSpace(context, mobile: 16, tablet: 20, desktop: 24),
        Expanded(
          child: _buildReservationsList(),
        ),
      ],
    );
  }

  Widget _buildFilterSection() {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    return Card(
      elevation: isMobile ? 1 : 2,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter by Status',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 16,
                  tablet: 18,
                  desktop: 20,
                ),
                fontWeight: FontWeight.w600,
              ),
            ),
            ResponsiveUtils.verticalSpace(context, mobile: 8, tablet: 10, desktop: 12),
            if (isMobile)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('all', 'All'),
                    ResponsiveUtils.horizontalSpace(context, mobile: 8, tablet: 8, desktop: 8),
                    _buildFilterChip('pending', 'Pending'),
                    ResponsiveUtils.horizontalSpace(context, mobile: 8, tablet: 8, desktop: 8),
                    _buildFilterChip('confirmed', 'Confirmed'),
                    ResponsiveUtils.horizontalSpace(context, mobile: 8, tablet: 8, desktop: 8),
                    _buildFilterChip('cancelled', 'Cancelled'),
                  ],
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildFilterChip('all', 'All'),
                  _buildFilterChip('pending', 'Pending'),
                  _buildFilterChip('confirmed', 'Confirmed'),
                  _buildFilterChip('cancelled', 'Cancelled'),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    final isMobile = ResponsiveUtils.isMobile(context);
    
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: ResponsiveUtils.getResponsiveFontSize(
            context,
            mobile: 12,
            tablet: 13,
            desktop: 14,
          ),
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      backgroundColor: Colors.grey.shade200,
      selectedColor: AppTheme.primaryRed.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryRed : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: ResponsiveUtils.getResponsiveFontSize(
          context,
          mobile: 12,
          tablet: 13,
          desktop: 14,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 12,
        vertical: isMobile ? 4 : 6,
      ),
    );
  }

  Widget _buildReservationsTable() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredReservations.isEmpty) {
      return _buildEmptyState();
    }

    final isMobile = ResponsiveUtils.isMobile(context);
    
    return Card(
      elevation: isMobile ? 1 : 2,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width - (isMobile ? 32 : 64),
          ),
          child: DataTable(
            columnSpacing: isMobile ? 8 : 24,
            horizontalMargin: isMobile ? 8 : 16,
            headingRowHeight: isMobile ? 48 : 56,
            dataRowMinHeight: isMobile ? 40 : 48,
            dataRowMaxHeight: isMobile ? 60 : 72,
            columns: [
              DataColumn(
                label: Text(
                  'Customer',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveFontSize(
                      context,
                      mobile: 12,
                      tablet: 13,
                      desktop: 14,
                    ),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!isMobile) DataColumn(
                label: Text(
                  'Event',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveFontSize(
                      context,
                      mobile: 12,
                      tablet: 13,
                      desktop: 14,
                    ),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Date',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveFontSize(
                      context,
                      mobile: 12,
                      tablet: 13,
                      desktop: 14,
                    ),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Time',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveFontSize(
                      context,
                      mobile: 12,
                      tablet: 13,
                      desktop: 14,
                    ),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!isMobile) DataColumn(
                label: Text(
                  'Guests',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveFontSize(
                      context,
                      mobile: 12,
                      tablet: 13,
                      desktop: 14,
                    ),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Status',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveFontSize(
                      context,
                      mobile: 12,
                      tablet: 13,
                      desktop: 14,
                    ),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Actions',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveFontSize(
                      context,
                      mobile: 12,
                      tablet: 13,
                      desktop: 14,
                    ),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            rows: _filteredReservations.map((reservation) {
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      isMobile
                          ? (reservation['customer_name']?.toString().split(' ')[0] ?? '')
                          : '${reservation['customer_name']}\n${reservation['customer_email']}',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getResponsiveFontSize(
                          context,
                          mobile: 11,
                          tablet: 12,
                          desktop: 13,
                        ),
                      ),
                    ),
                  ),
                  if (!isMobile) DataCell(
                    Text(
                      reservation['event_type'],
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getResponsiveFontSize(
                          context,
                          mobile: 11,
                          tablet: 12,
                          desktop: 13,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      reservation['event_date'],
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getResponsiveFontSize(
                          context,
                          mobile: 11,
                          tablet: 12,
                          desktop: 13,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      reservation['start_time'],
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getResponsiveFontSize(
                          context,
                          mobile: 11,
                          tablet: 12,
                          desktop: 13,
                        ),
                      ),
                    ),
                  ),
                  if (!isMobile) DataCell(
                    Text(
                      '${reservation['number_of_guests']}',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getResponsiveFontSize(
                          context,
                          mobile: 11,
                          tablet: 12,
                          desktop: 13,
                        ),
                      ),
                    ),
                  ),
                  DataCell(_buildStatusChip(reservation['status'])),
                  DataCell(_buildActionButtons(reservation)),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildReservationsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredReservations.isEmpty) {
      return _buildEmptyState();
    }

    final isMobile = ResponsiveUtils.isMobile(context);
    
    return ListView.builder(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      itemCount: _filteredReservations.length,
      itemBuilder: (context, index) {
        final reservation = _filteredReservations[index];
        return Card(
          elevation: isMobile ? 1 : 2,
          margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
          child: InkWell(
            onTap: () {
              // Optional: Add tap handler for mobile to show details
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          reservation['event_type'],
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getResponsiveFontSize(
                              context,
                              mobile: 16,
                              tablet: 18,
                              desktop: 20,
                            ),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _buildStatusChip(reservation['status']),
                    ],
                  ),
                  ResponsiveUtils.verticalSpace(context, mobile: 6, tablet: 8, desktop: 10),
                  _buildCustomerInfo(reservation),
                  if (!isMobile) 
                    ResponsiveUtils.verticalSpace(context, mobile: 4, tablet: 6, desktop: 8),
                  _buildDateTimeGuestsInfo(reservation),
                  ResponsiveUtils.verticalSpace(context, mobile: 8, tablet: 10, desktop: 12),
                  _buildActionButtons(reservation),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomerInfo(Map<String, dynamic> reservation) {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Customer: ${reservation['customer_name']}',
          style: TextStyle(
            fontSize: ResponsiveUtils.getResponsiveFontSize(
              context,
              mobile: 14,
              tablet: 15,
              desktop: 16,
            ),
          ),
        ),
        if (!isMobile) 
          ResponsiveUtils.verticalSpace(context, mobile: 2, tablet: 3, desktop: 4),
        if (!isMobile) 
          Text(
            'Email: ${reservation['customer_email']}',
            style: TextStyle(
              fontSize: ResponsiveUtils.getResponsiveFontSize(
                context,
                mobile: 12,
                tablet: 13,
                desktop: 14,
              ),
              color: Colors.grey.shade600,
            ),
          ),
      ],
    );
  }

  Widget _buildDateTimeGuestsInfo(Map<String, dynamic> reservation) {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    return Row(
      children: [
        Icon(
          Icons.calendar_today, 
          size: ResponsiveUtils.getResponsiveIconSize(context, mobile: 14, tablet: 16, desktop: 18), 
          color: Colors.grey,
        ),
        ResponsiveUtils.horizontalSpace(context, mobile: 4, tablet: 6, desktop: 8),
        Expanded(
          child: Text(
            '${reservation['event_date']} at ${reservation['start_time']}',
            style: TextStyle(
              fontSize: ResponsiveUtils.getResponsiveFontSize(
                context,
                mobile: 12,
                tablet: 13,
                desktop: 14,
              ),
            ),
          ),
        ),
        if (!isMobile) ...[
          ResponsiveUtils.horizontalSpace(context, mobile: 16, tablet: 20, desktop: 24),
          Icon(
            Icons.people, 
            size: ResponsiveUtils.getResponsiveIconSize(context, mobile: 14, tablet: 16, desktop: 18), 
            color: Colors.grey,
          ),
          ResponsiveUtils.horizontalSpace(context, mobile: 4, tablet: 6, desktop: 8),
          Text(
            '${reservation['number_of_guests']} guests',
            style: TextStyle(
              fontSize: ResponsiveUtils.getResponsiveFontSize(
                context,
                mobile: 12,
                tablet: 13,
                desktop: 14,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_available, 
            size: ResponsiveUtils.getResponsiveIconSize(context, mobile: 48, tablet: 56, desktop: 64), 
            color: Colors.grey.shade400,
          ),
          ResponsiveUtils.verticalSpace(context, mobile: 16, tablet: 20, desktop: 24),
          Text(
            'No reservations found',
            style: TextStyle(
              fontSize: ResponsiveUtils.getResponsiveFontSize(
                context,
                mobile: 18,
                tablet: 20,
                desktop: 22,
              ),
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          ResponsiveUtils.verticalSpace(context, mobile: 8, tablet: 10, desktop: 12),
          Text(
            'No reservations match the selected filter',
            style: TextStyle(
              fontSize: ResponsiveUtils.getResponsiveFontSize(
                context,
                mobile: 14,
                tablet: 15,
                desktop: 16,
              ),
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  void _showConfirmReservationDialog(String reservationId, String eventType) {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: EdgeInsets.all(isMobile ? 16 : 24),
        title: Row(
          children: [
            Icon(
              Icons.check_circle, 
              color: Colors.green,
              size: ResponsiveUtils.getResponsiveIconSize(context),
            ),
            SizedBox(width: isMobile ? 8 : 12),
            Expanded(
              child: Text(
                'Confirm Reservation',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getResponsiveFontSize(
                    context,
                    mobile: 16,
                    tablet: 18,
                    desktop: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to confirm "$eventType" reservation?',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 14,
                  tablet: 16,
                  desktop: 16,
                ),
              ),
            ),
            ResponsiveUtils.verticalSpace(context, mobile: 8, tablet: 10, desktop: 12),
            Text(
              'This will notify the customer that their reservation has been confirmed.',
              style: TextStyle(
                color: Colors.green,
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 12,
                  tablet: 13,
                  desktop: 14,
                ),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 14,
                  tablet: 15,
                  desktop: 16,
                ),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 24,
                vertical: isMobile ? 8 : 12,
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              _updateReservationStatus(reservationId, 'confirmed');
            },
            child: Text(
              'Confirm',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 14,
                  tablet: 15,
                  desktop: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(String reservationId, String eventType) {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: EdgeInsets.all(isMobile ? 16 : 24),
        title: Row(
          children: [
            Icon(
              Icons.warning, 
              color: Colors.orange,
              size: ResponsiveUtils.getResponsiveIconSize(context),
            ),
            SizedBox(width: isMobile ? 8 : 12),
            Expanded(
              child: Text(
                'Delete Reservation',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getResponsiveFontSize(
                    context,
                    mobile: 16,
                    tablet: 18,
                    desktop: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "$eventType" reservation?',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 14,
                  tablet: 16,
                  desktop: 16,
                ),
              ),
            ),
            ResponsiveUtils.verticalSpace(context, mobile: 8, tablet: 10, desktop: 12),
            Text(
              'This action cannot be undone and will permanently remove the reservation.',
              style: TextStyle(
                color: Colors.red,
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 12,
                  tablet: 13,
                  desktop: 14,
                ),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 14,
                  tablet: 15,
                  desktop: 16,
                ),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 24,
                vertical: isMobile ? 8 : 12,
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              _deleteReservation(reservationId);
            },
            child: Text(
              'Delete',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 14,
                  tablet: 15,
                  desktop: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;
    
    switch (status) {
      case 'pending':
        color = Colors.orange;
        icon = Icons.pending;
        break;
      case 'confirmed':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'cancelled':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
    }

    final isMobile = ResponsiveUtils.isMobile(context);

    return Chip(
      label: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: ResponsiveUtils.getResponsiveFontSize(
            context,
            mobile: 10,
            tablet: 11,
            desktop: 12,
          ),
        ),
      ),
      backgroundColor: color.withValues(alpha: 0.1),
      avatar: Icon(
        icon, 
        size: ResponsiveUtils.getResponsiveIconSize(context, mobile: 12, tablet: 14, desktop: 16), 
        color: color,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 6 : 8,
        vertical: isMobile ? 2 : 4,
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> reservation) {
    String status = reservation['status'];
    String reservationId = reservation['id'];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (status == 'pending') ...[
          IconButton(
            onPressed: () => _showConfirmReservationDialog(reservationId, reservation['event_type']),
            icon: Icon(
              Icons.check, 
              color: Colors.green,
              size: ResponsiveUtils.getResponsiveIconSize(context, mobile: 18, tablet: 20, desktop: 24),
            ),
            tooltip: 'Confirm',
            iconSize: ResponsiveUtils.getResponsiveIconSize(context, mobile: 18, tablet: 20, desktop: 24),
          ),
          IconButton(
            onPressed: () => _updateReservationStatus(reservationId, 'cancelled'),
            icon: Icon(
              Icons.close, 
              color: Colors.red,
              size: ResponsiveUtils.getResponsiveIconSize(context, mobile: 18, tablet: 20, desktop: 24),
            ),
            tooltip: 'Cancel',
            iconSize: ResponsiveUtils.getResponsiveIconSize(context, mobile: 18, tablet: 20, desktop: 24),
          ),
        ],
        if (status == 'confirmed') ...[
          IconButton(
            onPressed: () => _updateReservationStatus(reservationId, 'cancelled'),
            icon: Icon(
              Icons.cancel, 
              color: Colors.red,
              size: ResponsiveUtils.getResponsiveIconSize(context, mobile: 18, tablet: 20, desktop: 24),
            ),
            tooltip: 'Cancel',
            iconSize: ResponsiveUtils.getResponsiveIconSize(context, mobile: 18, tablet: 20, desktop: 24),
          ),
        ],
        IconButton(
          onPressed: () => _showDeleteConfirmationDialog(reservationId, reservation['event_type']),
          icon: Icon(
            Icons.delete, 
            color: Colors.red,
            size: ResponsiveUtils.getResponsiveIconSize(context, mobile: 18, tablet: 20, desktop: 24),
          ),
          tooltip: 'Delete',
          iconSize: ResponsiveUtils.getResponsiveIconSize(context, mobile: 18, tablet: 20, desktop: 24),
        ),
      ],
    );
  }
}