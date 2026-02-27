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
      print('Current user: ${currentUser?.email}');
      print('Current user metadata: ${currentUser?.userMetadata}');
      
      final response = await Supabase.instance.client
          .from('reservations')
          .select('*')
          .order('created_at', ascending: false);

      print('Reservations loaded: ${response.length}');
      print('Response: $response');

      setState(() {
        reservations = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading reservations: $e');
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Reservations Management'),
        backgroundColor: AppTheme.primaryRed,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            onPressed: _loadReservations,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          _buildFilterSection(),
          const SizedBox(height: 20),
          Expanded(child: _buildReservationsTable()),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildFilterSection(),
        const SizedBox(height: 16),
        Expanded(
          child: _buildReservationsList(),
        ),
      ],
    );
  }

  Widget _buildFilterSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter by Status',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'All'),
                  const SizedBox(width: 8),
                  _buildFilterChip('pending', 'Pending'),
                  const SizedBox(width: 8),
                  _buildFilterChip('confirmed', 'Confirmed'),
                  const SizedBox(width: 8),
                  _buildFilterChip('cancelled', 'Cancelled'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      backgroundColor: Colors.grey.shade200,
      selectedColor: AppTheme.primaryRed.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryRed : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildReservationsTable() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredReservations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No reservations found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No reservations match the selected filter',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Card(
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Customer')),
            DataColumn(label: Text('Event')),
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Time')),
            DataColumn(label: Text('Guests')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: _filteredReservations.map((reservation) {
            return DataRow(
              cells: [
                DataCell(Text('${reservation['customer_name']}\n${reservation['customer_email']}')),
                DataCell(Text(reservation['event_type'])),
                DataCell(Text(reservation['event_date'])),
                DataCell(Text(reservation['start_time'])),
                DataCell(Text('${reservation['number_of_guests']}')),
                DataCell(_buildStatusChip(reservation['status'])),
                DataCell(_buildActionButtons(reservation)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildReservationsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredReservations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No reservations found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredReservations.length,
      itemBuilder: (context, index) {
        final reservation = _filteredReservations[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        reservation['event_type'],
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _buildStatusChip(reservation['status']),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Customer: ${reservation['customer_name']}'),
                Text('Email: ${reservation['customer_email']}'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('${reservation['event_date']} at ${reservation['start_time']}'),
                    const SizedBox(width: 16),
                    Icon(Icons.people, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('${reservation['number_of_guests']} guests'),
                  ],
                ),
                const SizedBox(height: 12),
                _buildActionButtons(reservation),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showConfirmReservationDialog(String reservationId, String eventType) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 12),
            const Text('Confirm Reservation'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to confirm the "$eventType" reservation?',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text(
              'This will notify the customer that their reservation has been confirmed.',
              style: TextStyle(
                color: Colors.green,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _updateReservationStatus(reservationId, 'confirmed');
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(String reservationId, String eventType) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 12),
            const Text('Delete Reservation'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete the "$eventType" reservation?',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text(
              'This action cannot be undone and will permanently remove the reservation.',
              style: TextStyle(
                color: Colors.red,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _deleteReservation(reservationId);
            },
            child: const Text('Delete'),
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

    return Chip(
      label: Text(status.toUpperCase()),
      backgroundColor: color.withOpacity(0.1),
      labelStyle: TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      avatar: Icon(icon, size: 16, color: color),
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
            icon: const Icon(Icons.check, color: Colors.green),
            tooltip: 'Confirm',
          ),
          IconButton(
            onPressed: () => _updateReservationStatus(reservationId, 'cancelled'),
            icon: const Icon(Icons.close, color: Colors.red),
            tooltip: 'Cancel',
          ),
        ],
        if (status == 'confirmed') ...[
          IconButton(
            onPressed: () => _updateReservationStatus(reservationId, 'cancelled'),
            icon: const Icon(Icons.cancel, color: Colors.red),
            tooltip: 'Cancel',
          ),
        ],
        IconButton(
          onPressed: () => _showDeleteConfirmationDialog(reservationId, reservation['event_type']),
          icon: const Icon(Icons.delete, color: Colors.red),
          tooltip: 'Delete',
        ),
      ],
    );
  }
}
