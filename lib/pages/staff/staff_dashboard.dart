import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/widgets/shared_pos_widget.dart';
import 'package:yang_chow/pages/staff/staff_order_history_page.dart';

class StaffDashboardPage extends StatefulWidget {
  const StaffDashboardPage({super.key});

  @override
  State<StaffDashboardPage> createState() => _StaffDashboardPageState();
}

class _StaffDashboardPageState extends State<StaffDashboardPage> {
  String _userName = 'Staff';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user?.email != null) {
        final userResponse = await Supabase.instance.client
            .from('users')
            .select('firstname, lastname')
            .eq('email', user!.email!)
            .maybeSingle();

        if (userResponse != null) {
          final firstName = userResponse['firstname']?.toString() ?? '';
          final lastName = userResponse['lastname']?.toString() ?? '';
          
          // Use email prefix if firstname is "Customer" or empty, or if both names are empty
          if (firstName.isNotEmpty && lastName.isNotEmpty && firstName != 'Customer') {
            setState(() {
              _userName = '$firstName $lastName';
            });
          } else if (firstName.isNotEmpty && firstName != 'Customer') {
            setState(() {
              _userName = firstName;
            });
          } else {
            setState(() {
              _userName = user.email!.split('@')[0];
            });
          }
        } else {
          setState(() {
            _userName = user.email!.split('@')[0];
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user info: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 50,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Icon(Icons.point_of_sale, color: Colors.red.shade600, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Staff POS System',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Current user info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                topLeft: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person, color: Colors.black54, size: 14),
                const SizedBox(width: 6),
                _isLoading
                    ? SizedBox(
                        width: 40,
                        height: 12,
                        child: LinearProgressIndicator(
                          backgroundColor: Colors.grey.shade300,
                          color: Colors.grey.shade600,
                        ),
                      )
                    : Text(
                        _userName,
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history, color: Colors.black54),
            tooltip: 'Order History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const StaffOrderHistoryPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.logout, color: Colors.black54),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        
                        // Logout sequence
                        await Supabase.instance.client.auth.signOut();

                        if (context.mounted) {
                          Navigator.pushReplacementNamed(context, '/staff-login');
                        }
                      },
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: const SharedPOSWidget(userRole: 'Staff'),
    );
  }
}