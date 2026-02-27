import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';

class CustomerDashboardPage extends StatefulWidget {
  const CustomerDashboardPage({super.key});

  @override
  State<CustomerDashboardPage> createState() => _CustomerDashboardPageState();
}

class _CustomerDashboardPageState extends State<CustomerDashboardPage> {
  int _selectedIndex = 0;
  bool _isLoading = false;
  List<Map<String, dynamic>> customerReservations = [];
  Timer? _refreshTimer;
  Map<String, String> _lastKnownStatuses = {};
  
  // Reservation form controllers
  final TextEditingController _eventController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _guestsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCustomerReservations();
    
    // Set up automatic refresh every 10 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _loadCustomerReservations();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _eventController.dispose();
    _dateController.dispose();
    _startTimeController.dispose();
    _durationController.dispose();
    _guestsController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomerReservations() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser?.email == null) return;

      final response = await Supabase.instance.client
          .from('reservations')
          .select('*')
          .eq('customer_email', currentUser!.email!)
          .order('created_at', ascending: false);

      // Check for status changes
      for (var reservation in response) {
        String reservationId = reservation['id'].toString();
        String newStatus = reservation['status'];
        
        if (_lastKnownStatuses.containsKey(reservationId)) {
          String oldStatus = _lastKnownStatuses[reservationId]!;
          if (oldStatus != newStatus) {
            _showStatusChangeNotification(reservation['event_type'], oldStatus, newStatus);
          }
        }
        _lastKnownStatuses[reservationId] = newStatus;
      }

      setState(() {
        customerReservations = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error loading customer reservations: $e');
    }
  }

  Future<void> _deleteReservation(String reservationId) async {
  try {
    await Supabase.instance.client
        .from('reservations')
        .delete()
        .eq('id', reservationId);

    _showSnackBar('Reservation deleted successfully', Colors.green);
    _loadCustomerReservations(); // Refresh the list
  } catch (e) {
    _showSnackBar('Error deleting reservation: $e', Colors.red);
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

  void _showStatusChangeNotification(String eventType, String oldStatus, String newStatus) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              newStatus == 'confirmed' ? Icons.check_circle : 
              newStatus == 'cancelled' ? Icons.cancel : 
              Icons.info,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Your "$eventType" reservation is now $newStatus',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: newStatus == 'confirmed' ? Colors.green : 
                           newStatus == 'cancelled' ? Colors.red : 
                           Colors.blue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Customer Dashboard'),
        backgroundColor: AppTheme.primaryRed,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            onPressed: _loadCustomerReservations,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Reservations',
          ),
        ],
      ),
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Navigation Rail
        NavigationRail(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (int index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          labelType: NavigationRailLabelType.all,
          destinations: const [
            NavigationRailDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: Text('Home'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.event_available_outlined),
              selectedIcon: Icon(Icons.event_available),
              label: Text('Reservations'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: Text('Profile'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: Text('History'),
            ),
          ],
        ),
        // Main Content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: _buildContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Mobile Navigation
        Container(
          color: AppTheme.primaryRed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedIndex = 0;
                  });
                },
                icon: const Icon(Icons.home, color: Colors.white),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedIndex = 1;
                  });
                },
                icon: const Icon(Icons.event_available, color: Colors.white),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedIndex = 2;
                  });
                },
                icon: const Icon(Icons.person, color: Colors.white),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedIndex = 3;
                  });
                },
                icon: const Icon(Icons.history, color: Colors.white),
              ),
            ],
          ),
        ),
        // Main Content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeSection();
      case 1:
        return _buildReservationsSection();
      case 2:
        return _buildProfileSection();
      case 3:
        return _buildHistorySection();
      default:
        return _buildHomeSection();
    }
  }

  Widget _buildHomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome, Customer!',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: AppTheme.primaryRed,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Navigate to reservations
                          setState(() {
                            _selectedIndex = 1;
                          });
                        },
                        icon: const Icon(Icons.event_available),
                        label: const Text('Make Reservation'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // Navigate to profile
                          setState(() {
                            _selectedIndex = 2;
                          });
                        },
                        icon: const Icon(Icons.person),
                        label: const Text('My Profile'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recent Reservations',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                customerReservations.isEmpty
                    ? const Text(
                        'No recent reservations found. Start making reservations to see your reservation history here!',
                        style: TextStyle(color: Colors.grey),
                      )
                    : Column(
                        children: customerReservations.take(3).map((reservation) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          reservation['event_type'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          '${reservation['event_date']} at ${reservation['start_time']}',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      _buildStatusChip(reservation['status']),
                                      const SizedBox(width: 8),
                                      if (reservation['status'] == 'pending')
                                        IconButton(
                                          onPressed: () {
                                            _showDeleteConfirmationDialog(reservation['id'], reservation['event_type']);
                                          },
                                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                          tooltip: 'Delete Reservation',
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                if (customerReservations.length > 3)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedIndex = 3; // Go to history
                      });
                    },
                    child: const Text('View All Reservations'),
                  ),
              ],
            ),
          ),
        ),
      ],
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
        fontSize: 10,
      ),
      avatar: Icon(icon, size: 14, color: color),
    );
  }

  Widget _buildReservationsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Event Reservations',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.primaryRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              
              // Reservation Form
              Form(
                child: Column(
                  children: [
                    // Event Name
                    Text(
                      'Event Type',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _eventController,
                      decoration: InputDecoration(
                        hintText: 'e.g., Birthday Party, Wedding, Meeting',
                        prefixIcon: const Icon(Icons.event),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Date
                    Text(
                      'Date',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _dateController,
                      readOnly: true,
                      decoration: InputDecoration(
                        hintText: 'Select date',
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                      ),
                      onTap: () async {
                        DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (pickedDate != null) {
                          setState(() {
                            _dateController.text = "${pickedDate.month}/${pickedDate.day}/${pickedDate.year}";
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Start Time
                    Text(
                      'Start Time',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _startTimeController,
                      readOnly: true,
                      decoration: InputDecoration(
                        hintText: 'Select time',
                        prefixIcon: const Icon(Icons.access_time),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                      ),
                      onTap: () async {
                        TimeOfDay? pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (pickedTime != null) {
                          setState(() {
                            _startTimeController.text = pickedTime.format(context);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Duration
                    Text(
                      'Duration (hours)',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _durationController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'e.g., 2, 3, 4',
                        prefixIcon: const Icon(Icons.hourglass_empty),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Number of Guests
                    Text(
                      'Number of Guests',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _guestsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'e.g., 10, 25, 50',
                        prefixIcon: const Icon(Icons.people),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitReservation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Submit Reservation'),
                      ),
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

  Widget _buildProfileSection() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Profile',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.email),
              title: Text('Email'),
              subtitle: Text('customer@example.com'),
            ),
            ListTile(
              leading: Icon(Icons.phone),
              title: Text('Phone'),
              subtitle: Text('Not provided'),
            ),
            ListTile(
              leading: Icon(Icons.calendar_today),
              title: Text('Member Since'),
              subtitle: Text('Today'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersSection() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Orders',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No orders yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Place your first order to get started!',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reservation History',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            customerReservations.isEmpty
                ? Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.history_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No reservation history',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Make your first reservation to see your history here!',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: customerReservations.length,
                    itemBuilder: (context, index) {
                      final reservation = customerReservations[index];
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
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      _buildStatusChip(reservation['status']),
                                      const SizedBox(width: 8),
                                      if (reservation['status'] == 'pending')
                                        IconButton(
                                          onPressed: () {
                                            _showDeleteConfirmationDialog(reservation['id'], reservation['event_type']);
                                          },
                                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                          tooltip: 'Delete Reservation',
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('Date: ${reservation['event_date']}'),
                              Text('Time: ${reservation['start_time']}'),
                              Text('Duration: ${reservation['duration_hours']} hours'),
                              Text('Guests: ${reservation['number_of_guests']}'),
                              const SizedBox(height: 8),
                              Text(
                                'Booked on: ${DateTime.parse(reservation['created_at']).toString().substring(0, 19)}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
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
              'Are you sure you want to delete your "$eventType" reservation?',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text(
              'This action cannot be undone.',
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

  void _submitReservation() async {
    String event = _eventController.text.trim();
    String date = _dateController.text.trim();
    String startTime = _startTimeController.text.trim();
    String duration = _durationController.text.trim();
    String guests = _guestsController.text.trim();

    // Validation
    if (event.isEmpty || date.isEmpty || startTime.isEmpty || duration.isEmpty || guests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('Please fill in all fields'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    // Get current user info
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('User not authenticated'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Parse date string to proper format
      List<String> dateParts = date.split('/');
      if (dateParts.length != 3) {
        throw Exception('Invalid date format');
      }
      String formattedDate = "${dateParts[2]}-${dateParts[0].padLeft(2, '0')}-${dateParts[1].padLeft(2, '0')}";

      // Save reservation to database
      await Supabase.instance.client.from('reservations').insert({
        'customer_email': currentUser.email,
        'customer_name': currentUser.userMetadata?['name'] ?? 'Customer',
        'event_type': event,
        'event_date': formattedDate,
        'start_time': startTime,
        'duration_hours': int.parse(duration.replaceAll(RegExp(r'[^0-9]'), '')),
        'number_of_guests': int.parse(guests.replaceAll(RegExp(r'[^0-9]'), '')),
        'status': 'pending',
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Reservation submitted for $event on $date at $startTime')),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ),
      );

      // Clear form
      _eventController.clear();
      _dateController.clear();
      _startTimeController.clear();
      _durationController.clear();
      _guestsController.clear();

      // Refresh reservations list
      _loadCustomerReservations();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Error submitting reservation: $e')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
