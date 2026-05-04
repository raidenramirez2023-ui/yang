import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';

class CustomerManagementPage extends StatefulWidget {
  const CustomerManagementPage({super.key});

  @override
  State<CustomerManagementPage> createState() => _CustomerManagementPageState();
}

class _CustomerManagementPageState extends State<CustomerManagementPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _allCustomers = [];
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
      final response = await _supabase
          .from('users')
          .select('*')
          .eq('role', 'customer')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _allCustomers = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading customers: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredCustomers {
    return _allCustomers.where((customer) {
      final name = '${customer['firstname'] ?? ''} ${customer['lastname'] ?? ''}'.toLowerCase();
      final email = (customer['email'] ?? '').toString().toLowerCase();
      final phone = (customer['phone'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      
      return name.contains(query) || email.contains(query) || phone.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCustomers;
    final totalCustomers = _allCustomers.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(totalCustomers),
            const SizedBox(height: 32),
            _buildSearchBar(),
            const SizedBox(height: 24),
            _buildListHeader(),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? _buildEmptyState()
                      : _buildCustomerList(filtered),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int total) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CUSTOMER LIST',
              style: TextStyle(
                color: AppTheme.primaryColor.withOpacity(0.8),
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'User Directory',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: AppTheme.darkGrey,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.people_outline, color: AppTheme.primaryColor),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    total.toString(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkGrey,
                    ),
                  ),
                  const Text(
                    'Total Customers',
                    style: TextStyle(fontSize: 10, color: AppTheme.mediumGrey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search customers...',
          hintStyle: const TextStyle(color: AppTheme.mediumGrey),
          prefixIcon: const Icon(Icons.search, color: AppTheme.primaryColor),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildListHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('NAME', style: _headerStyle)),
          Expanded(flex: 3, child: Text('EMAIL ADDRESS', style: _headerStyle)),
          Expanded(flex: 2, child: Text('PHONE NUMBER', style: _headerStyle)),
          Expanded(flex: 2, child: Text('DATE REGISTERED', style: _headerStyle)),
          SizedBox(width: 48), // Space for action button
        ],
      ),
    );
  }

  static const TextStyle _headerStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    color: AppTheme.mediumGrey,
    letterSpacing: 1,
  );

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_outlined, size: 80, color: AppTheme.lightGrey),
          const SizedBox(height: 16),
          const Text(
            'No customers found matching your search.',
            style: TextStyle(color: AppTheme.mediumGrey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerList(List<Map<String, dynamic>> customers) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 40),
      itemCount: customers.length,
      itemBuilder: (context, index) {
        final customer = customers[index];
        return _buildCustomerRow(customer);
      },
    );
  }

  Widget _buildCustomerRow(Map<String, dynamic> customer) {
    final String firstName = customer['firstname'] ?? 'N/A';
    final String lastName = customer['lastname'] ?? '';
    final String email = customer['email'] ?? 'N/A';
    final String phone = customer['phone'] ?? 'N/A';

    String formattedDate = 'N/A';
    if (customer['created_at'] != null) {
      try {
        final date = DateTime.parse(customer['created_at']).toLocal();
        formattedDate = DateFormat('MMM dd, yyyy').format(date);
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lightGrey.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  child: Text(
                    firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$firstName $lastName',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkGrey,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              email,
              style: const TextStyle(color: AppTheme.mediumGrey, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              phone,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.darkGrey,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              formattedDate,
              style: const TextStyle(color: AppTheme.mediumGrey, fontSize: 13),
            ),
          ),
          IconButton(
            onPressed: () => _showCustomerDetails(customer),
            icon: const Icon(Icons.info_outline, color: AppTheme.mediumGrey, size: 20),
            tooltip: 'View Details',
          ),
        ],
      ),
    );
  }

  void _showCustomerDetails(Map<String, dynamic> customer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.person, color: AppTheme.primaryColor),
            const SizedBox(width: 12),
            const Text('Customer Details'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailItem('FIRST NAME', customer['firstname']),
            _detailItem('LAST NAME', customer['lastname']),
            _detailItem('PHONE NUMBER', customer['phone']),
            _detailItem('EMAIL ADDRESS', customer['email']),
            _detailItem('DATE REGISTERED', _formatDate(customer['created_at'])),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('MMMM dd, yyyy - hh:mm a').format(date);
    } catch (_) {
      return 'N/A';
    }
  }

  Widget _detailItem(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppTheme.mediumGrey,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value?.toString() ?? 'N/A',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkGrey,
            ),
          ),
        ],
      ),
    );
  }
}
