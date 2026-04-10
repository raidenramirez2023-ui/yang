import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:yang_chow/utils/app_theme.dart';


class AdminCustomerApprovalPage extends StatefulWidget {
  const AdminCustomerApprovalPage({super.key});

  @override
  State<AdminCustomerApprovalPage> createState() => _AdminCustomerApprovalPageState();
}

class _AdminCustomerApprovalPageState extends State<AdminCustomerApprovalPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _pendingCustomers = [];
  List<Map<String, dynamic>> _approvedCustomers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    
    try {
      // Load pending customers (exclude rejected customers)
      final pendingResponse = await _supabase
          .from('users')
          .select('*')
          .eq('role', 'customer')
          .eq('is_approved', false)
          .filter('rejection_reason', 'is', null)
          .order('created_at', ascending: false);
      
      // Load approved customers
      final approvedResponse = await _supabase
          .from('users')
          .select('*')
          .eq('role', 'customer')
          .eq('is_approved', true)
          .order('approved_at', ascending: false);

      if (mounted) {
        setState(() {
          // Filter out invalid customers from pending list
          _pendingCustomers = List<Map<String, dynamic>>.from(pendingResponse).where((customer) =>
            customer['created_at'] != null && customer['created_at'].toString().isNotEmpty &&
            customer['firstname'] != null && customer['firstname'].toString().trim().isNotEmpty &&
            customer['lastname'] != null && customer['lastname'].toString().trim().isNotEmpty &&
            customer['email'] != null && customer['email'].toString().trim().isNotEmpty
          ).toList();
          
          _approvedCustomers = List<Map<String, dynamic>>.from(approvedResponse);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading customers: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Error loading customers: $e', Colors.red);
      }
    }
  }

  Future<void> _approveCustomer(String customerId, String customerEmail) async {
    try {
      await _supabase
          .from('users')
          .update({
            'is_approved': true,
            'approved_by': 'admn.pagsanjan@gmail.com',
            'approved_at': DateTime.now().toIso8601String(),
          })
          .eq('id', customerId);

      // Send notification to customer (if notifications table exists)
      await _supabase
          .from('notifications')
          .insert({
            'recipient_email': customerEmail,
            'title': 'Account Approved',
            'message': 'Your account has been approved! You can now login to your account.',
            'event_type': 'account_approved',
            'created_at': DateTime.now().toIso8601String(),
          }).onError((error, stackTrace) {
        debugPrint('Error sending notification: $error');
      });

      _showSnackBar('Customer approved successfully', Colors.green);
      _loadCustomers(); // Refresh the list
    } catch (e) {
      debugPrint('Error approving customer: $e');
      _showSnackBar('Error approving customer', Colors.red);
    }
  }

  Future<void> _rejectCustomer(String customerId, String customerEmail, String reason) async {
    try {
      await _supabase
          .from('users')
          .update({
            'is_approved': false,
            'rejection_reason': reason,
            'approved_by': 'admn.pagsanjan@gmail.com',
            'approved_at': DateTime.now().toIso8601String(),
          })
          .eq('id', customerId);

      // Send notification to customer
      await _supabase
          .from('notifications')
          .insert({
            'recipient_email': customerEmail,
            'title': 'Account Rejected',
            'message': 'Your registration was rejected. Reason: $reason',
            'event_type': 'account_rejected',
            'created_at': DateTime.now().toIso8601String(),
          }).onError((error, stackTrace) {
        debugPrint('Error sending notification: $error');
      });

      _showSnackBar('Customer rejected', Colors.orange);
      
      // Remove the rejected customer from pending list immediately
      setState(() {
        _pendingCustomers.removeWhere((customer) => customer['id'] == customerId);
      });
      
      // Optional: Refresh the list to ensure consistency
      _loadCustomers();
    } catch (e) {
      debugPrint('Error rejecting customer: $e');
      _showSnackBar('Error rejecting customer', Colors.red);
    }
  }

  void _showRejectDialog(Map<String, dynamic> customer) {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reject Customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to reject ${customer['firstname']} ${customer['lastname']}?'),
            SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Rejection Reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.isNotEmpty) {
                Navigator.pop(context);
                _rejectCustomer(customer['id'], customer['email'], reasonController.text);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<Map<String, dynamic>> _filterCustomers(List<Map<String, dynamic>> customers) {
    // First filter out invalid customers
    var validCustomers = customers.where((customer) =>
      customer['created_at'] != null && customer['created_at'].toString().isNotEmpty &&
      customer['firstname'] != null && customer['firstname'].toString().trim().isNotEmpty &&
      customer['lastname'] != null && customer['lastname'].toString().trim().isNotEmpty &&
      customer['email'] != null && customer['email'].toString().trim().isNotEmpty
    ).toList();
    
    // Then apply search filter if needed
    if (_searchQuery.isEmpty) return validCustomers;
    
    return validCustomers.where((customer) {
      final name = '${customer['firstname']} ${customer['lastname']}'.toLowerCase();
      final email = customer['email'].toString().toLowerCase();
      final phone = customer['phone'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      
      return name.contains(query) || email.contains(query) || phone.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {

    final filteredPending = _filterCustomers(_pendingCustomers);
    final filteredApproved = _filterCustomers(_approvedCustomers);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        title: Text('Customer Approvals'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadCustomers,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: EdgeInsets.all(16),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search customers...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                ),
                
                // Tabs
                Expanded(
                  child: DefaultTabController(
                    length: 2,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TabBar(
                          labelColor: AppTheme.primaryColor,
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: AppTheme.primaryColor,
                          tabs: [
                            Tab(
                              text: 'Pending (${filteredPending.length})',
                              icon: Icon(Icons.pending_actions),
                            ),
                            Tab(
                              text: 'Approved (${filteredApproved.length})',
                              icon: Icon(Icons.check_circle),
                            ),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildCustomerList(filteredPending, true),
                              _buildCustomerList(filteredApproved, false),
                            ],
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

  Widget _buildCustomerList(List<Map<String, dynamic>> customers, bool isPending) {
    if (customers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPending ? Icons.pending_actions : Icons.check_circle,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              isPending ? 'No pending customers' : 'No approved customers',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: customers.length,
      itemBuilder: (context, index) {
        final customer = customers[index];
        return _buildCustomerCard(customer, isPending);
      },
    );
  }

  Widget _buildCustomerCard(Map<String, dynamic> customer, bool isPending) {
    // Add null safety checks - more flexible validation
    if (customer['created_at'] == null || customer['created_at'].toString().isEmpty ||
        customer['firstname'] == null || customer['firstname'].toString().trim().isEmpty ||
        customer['lastname'] == null || customer['lastname'].toString().trim().isEmpty ||
        customer['email'] == null || customer['email'].toString().trim().isEmpty) {
      return SizedBox.shrink();
    }
    
    String formattedDate;
    try {
      final createdAt = DateTime.parse(customer['created_at']);
      final localTime = createdAt.toLocal(); // Convert to local timezone
      formattedDate = DateFormat('MMM dd, yyyy - hh:mm a').format(localTime);
    } catch (e) {
      formattedDate = 'Unknown date';
      debugPrint('Error parsing date: ${customer['created_at']}');
    }

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor,
                  child: Text(
                    '${customer['firstname'].toString()[0]}${customer['lastname'].toString()[0]}'.toUpperCase(),
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${customer['firstname']} ${customer['lastname']}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        customer['email'],
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                if (isPending)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Pending',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.phone, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                Text(customer['phone'] ?? 'Not provided'),
                SizedBox(width: 20),
                Icon(Icons.access_time, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                Text(formattedDate),
              ],
            ),
            if (!isPending && customer['approved_at'] != null) ...[
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: Colors.green),
                  SizedBox(width: 4),
                  Text(
                    'Approved by ${customer['approved_by'] ?? 'admin'}',
                    style: TextStyle(color: Colors.green, fontSize: 12),
                  ),
                ],
              ),
            ],
            if (isPending) ...[
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveCustomer(customer['id'], customer['email']),
                      icon: Icon(Icons.check),
                      label: Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showRejectDialog(customer),
                      icon: Icon(Icons.close),
                      label: Text('Reject'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
