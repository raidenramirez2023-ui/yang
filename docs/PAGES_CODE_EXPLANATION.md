# Pages Code Explanation

---

## 📄 PAGES DIRECTORY CODE BREAKDOWN

---

## 👨‍💼 **ADMIN_MAIN_PAGE.DART**

### **CLASS STRUCTURE**
```dart
class AdminMainPage extends StatefulWidget {
  const AdminMainPage({super.key});

  @override
  State<AdminMainPage> createState() => _AdminMainPageState();
}

class _AdminMainPageState extends State<AdminMainPage> {
  int _selectedIndex = 0;

  // Pages for admin
  final List<Widget> _pages = [
    const InventoryPage(),
    const SalesReportPage(),
    const UserManagementPage(),
    const SettingsPage(),
  ];

  final List<String> _pageTitles = [
    'Inventory',
    'Sales Reports',
    'User Management',
    'Settings',
  ];

  final List<IconData> _pageIcons = [
    Icons.inventory_2,
    Icons.analytics,
    Icons.people,
    Icons.settings,
  ];
```

**Purpose:** Main admin dashboard with navigation.

**Key Components:**
- **`_selectedIndex`** - Current active tab (0-3)
- **`_pages`** - Widget instances for each admin feature
- **`_pageTitles`** - Display titles for AppBar
- **`_pageIcons`** - Icons for navigation

**Navigation Mapping:**
```
Index 0: Inventory     → Icons.inventory_2
Index 1: Sales Reports → Icons.analytics  
Index 2: User Mgmt     → Icons.people
Index 3: Settings      → Icons.settings
```

---

## 🔐 **LOGIN_PAGE.DART**

### **AUTHENTICATION STATE**
```dart
class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String selectedRole = 'Admin'; // default role
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _showLoginPage = false;

  late AnimationController _animationController;
  late Animation<double> _logoAnimation;
```

**Variables Explained:**
- **`emailController`** - Captures email input
- **`passwordController`** - Captures password input
- **`_auth`** - Firebase authentication service
- **`_firestore`** - Firebase database service
- **`selectedRole`** - User's chosen role (Admin/Staff)
- **`_isPasswordVisible`** - Toggle password visibility
- **`_isLoading`** - Loading state during login
- **`_showLoginPage`** - Controls login form visibility
- **`_animationController`** - Controls logo animation
- **`_logoAnimation`** - Logo size animation values

### **LOGIN HANDLER**
```dart
Future<void> handleLogin() async {
  String email = emailController.text.trim();
  String password = passwordController.text.trim();

  // Input validation
  if (email.isEmpty || password.isEmpty) {
    _showSnackBar("Please enter email and password", Colors.red.shade700, Icons.error_outline);
    return;
  }

  // Email format validation
  if (!email.contains('@')) {
    _showSnackBar("Please enter a valid email address", Colors.orange.shade700, Icons.warning_amber);
    return;
  }

  setState(() => _isLoading = true);

  try {
    // 🔐 Step 1: Authenticate with Firebase Auth
    await _auth.signInWithEmailAndPassword(email: email, password: password);

    // 📋 Step 2: Get user role from Firestore
    QuerySnapshot userDoc = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (userDoc.docs.isEmpty) {
      _showSnackBar("User not found in database", Colors.red.shade700, Icons.error_outline);
      await _auth.signOut();
      setState(() => _isLoading = false);
      return;
    }

    // Get the user's role from Firestore
    String userRole = userDoc.docs.first.get('role');

    // ✅ Step 3: Verify role matches selection
    if (userRole != selectedRole) {
      _showSnackBar("Invalid role. You are registered as $userRole", Colors.red.shade700, Icons.error_outline);
      await _auth.signOut();
      setState(() => _isLoading = false);
      return;
    }

    // 🎉 Step 4: Navigate based on verified role
    _showSnackBar("Login successful as $userRole", Colors.green.shade700, Icons.check_circle_outline);

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        final roleData = roles[userRole];
        if (roleData != null) {
          Navigator.pushReplacementNamed(context, roleData['route']!);
        }
      }
    });

  } on FirebaseAuthException catch (e) {
    // Error handling for different Firebase auth errors
  } catch (e) {
    // General error handling
  } finally {
    setState(() => _isLoading = false);
  }
}
```

**Login Process Steps:**
1. **Input Validation** - Check empty fields and email format
2. **Firebase Auth** - Authenticate email/password
3. **Role Verification** - Check user role in Firestore
4. **Navigation** - Redirect to appropriate dashboard
5. **Error Handling** - Handle authentication errors

---

## 🍽️ **STAFF_DASHBOARD.DART**

### **SIMPLE STAFF INTERFACE**
```dart
class StaffDashboardPage extends StatelessWidget {
  const StaffDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 50,
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
          // Staff badge and logout button
        ],
      ),
      body: const SharedPOSWidget(userRole: 'Staff'),
    );
  }
}
```

**Staff Dashboard Features:**
- **Stateless** - No internal state needed
- **White AppBar** - Different from admin (red)
- **POS Integration** - Uses SharedPOSWidget
- **Staff Badge** - Shows "Staff" role
- **Logout** - Confirmation dialog

---

## 📧 **FORGOT_PASSWORD_PAGE.DART**

### **PASSWORD RESET FUNCTIONALITY**
```dart
class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _emailSent = false;

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _emailSent = true;
        });
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An error occurred';
      
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No account found with this email address';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many requests. Try again later';
          break;
        default:
          errorMessage = e.message ?? 'Failed to send reset email';
      }

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // General error handling
    }
  }
}
```

**Password Reset Process:**
1. **Form Validation** - Check email format
2. **Firebase Call** - Send reset email
3. **State Update** - Show success message
4. **Error Handling** - Specific error messages

**Error Cases:**
- **user-not-found** - Email not registered
- **invalid-email** - Bad email format
- **too-many-requests** - Rate limiting
- **Default** - Generic error fallback

---

## 📦 **INVENTORY_MANAGEMENT.DART**

### **INVENTORY DATA STRUCTURES**
```dart
class _InventoryPageState extends State<InventoryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isAdmin = false;
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> categories = [
    'All',
    'Perishable Ingredients',
    'Non-perishable Ingredients', 
    'Beverages',
  ];
```

**Inventory Variables:**
- **`_firestore`** - Database connection
- **`_auth`** - Authentication service
- **`_isAdmin`** - Permission check
- **`_isLoading`** - Loading state
- **`_searchQuery`** - Search filter
- **`_selectedCategory`** - Category filter
- **`categories`** - Available categories

### **ADD/EDIT ITEM DIALOG**
```dart
void _addOrEditItem({Map<String, dynamic>? item, String? docId}) {
  if (!_isAdmin) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only Admin users can add/edit inventory items'),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return;
  }

  final nameController = TextEditingController(text: item?['name']);
  final categoryController = TextEditingController(text: item?['category']);
  final quantityController = TextEditingController(text: item?['quantity']?.toString());
  final unitController = TextEditingController(text: item?['unit']);

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
      title: Text(item == null ? 'Add Inventory Item' : 'Edit Inventory Item'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogTextField(label: 'Item Name', controller: nameController, icon: Icons.inventory_2),
            const SizedBox(height: AppTheme.lg),
            _buildDialogTextField(label: 'Category', controller: categoryController, icon: Icons.category, readOnly: true),
            // Category selection chips
            Container(
              padding: const EdgeInsets.all(AppTheme.md),
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Available Categories:', style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryRed,
                  )),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: categories.where((cat) => cat != 'All').map((category) {
                      return ActionChip(
                        label: Text(category, style: const TextStyle(fontSize: 11)),
                        onPressed: () => categoryController.text = category,
                        backgroundColor: AppTheme.primaryRed.withValues(alpha: 0.1),
                        side: BorderSide(color: AppTheme.primaryRed.withValues(alpha: 0.3)),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.lg),
            _buildDialogTextField(label: 'Quantity', controller: quantityController, icon: Icons.numbers, keyboardType: TextInputType.number),
            const SizedBox(height: AppTheme.lg),
            _buildDialogTextField(label: 'Unit (kg, pcs, etc.)', controller: unitController, icon: Icons.straighten),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            // Save logic with validation
            final newItem = {
              'name': nameController.text.trim(),
              'category': categoryController.text.trim(),
              'quantity': int.tryParse(quantityController.text) ?? 0,
              'unit': unitController.text.trim(),
              'createdBy': user.email,
              'createdAt': FieldValue.serverTimestamp(),
            };

            try {
              if (item == null) {
                await _firestore.collection('inventory').add(newItem);
              } else {
                await _firestore.collection('inventory').doc(docId).update(newItem);
              }
              
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(item == null ? 'Item added successfully!' : 'Item updated successfully!'),
                    backgroundColor: AppTheme.successGreen,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } catch (e) {
              // Error handling
            }
          },
          child: Text(item == null ? 'Add' : 'Update'),
        ),
      ],
    ),
  );
}
```

**Add/Edit Features:**
- **Admin Check** - Only admins can add/edit
- **Form Fields** - Name, category, quantity, unit
- **Category Chips** - Visual category selection
- **Validation** - Required field checking
- **Firebase Save** - Add new or update existing
- **Success/Error Feedback** - User notifications

---

## 📊 **SALES_REPORT_PAGE.DART**

### **SALES DATA STRUCTURES**
```dart
class _SalesReportPageState extends State<SalesReportPage> {
  String selectedPeriod = 'Today';
  String selectedChart = 'Revenue';

  final List<Map<String, dynamic>> salesData = [
    {'date': 'Mon', 'revenue': 4500, 'orders': 45},
    {'date': 'Tue', 'revenue': 5200, 'orders': 52},
    {'date': 'Wed', 'revenue': 3800, 'orders': 38},
    {'date': 'Thu', 'revenue': 6100, 'orders': 61},
    {'date': 'Fri', 'revenue': 7200, 'orders': 72},
    {'date': 'Sat', 'revenue': 8500, 'orders': 85},
    {'date': 'Sun', 'revenue': 6800, 'orders': 68},
  ];

  final List<Map<String, dynamic>> topProducts = [
    {'name': 'Yang Chow', 'sales': 156, 'revenue': 31200},
    {'name': 'Sweet & Sour Pork', 'sales': 98, 'revenue': 17640},
    {'name': 'Fried Rice', 'sales': 87, 'revenue': 10440},
    {'name': 'Beef Broccoli', 'sales': 76, 'revenue': 16720},
    {'name': 'Chopsuey', 'sales': 65, 'revenue': 9750},
  ];

  final List<Map<String, dynamic>> hourlyData = [
    {'hour': '8AM', 'revenue': 800},
    {'hour': '10AM', 'revenue': 1200},
    {'hour': '12PM', 'revenue': 2800},
    {'hour': '2PM', 'revenue': 2400},
    {'hour': '4PM', 'revenue': 1800},
    {'hour': '6PM', 'revenue': 3200},
    {'hour': '8PM', 'revenue': 2100},
    {'hour': '10PM', 'revenue': 900},
  ];
```

**Data Organization:**
- **`salesData`** - Weekly sales with revenue and orders
- **`topProducts`** - Best-selling products with sales count
- **`hourlyData`** - Revenue by time of day
- **`selectedPeriod`** - Time period filter
- **`selectedChart`** - Chart type selector

### **RESPONSIVE DEVICE DETECTION**
```dart
@override
Widget build(BuildContext context) {
  final size = MediaQuery.of(context).size;
  final isMobile = size.width < 600;
  final isTablet = size.width >= 600 && size.width < 1024;
  final isDesktop = size.width >= 1024;

  return Scaffold(
    backgroundColor: Colors.grey.shade50,
    body: SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isDesktop ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// HEADER (fixed for mobile)
            isMobile ? _mobileHeader() : _desktopHeader(),

            const SizedBox(height: 24),

            /// SUMMARY
            _buildSummaryCards(isDesktop, isTablet),

            const SizedBox(height: 24),

            /// CHART SWITCHER
            SizedBox(
              width: double.infinity,
              child: Wrap(
                children: [
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: ['Revenue', 'Orders', 'Products'].map((type) {
                        final isSelected = selectedChart == type;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => selectedChart = type),
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.red.shade600 : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  type,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.grey.shade600,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            
            // Chart display based on selection
            _buildChart(selectedChart),
          ],
        ),
      ),
    ),
  );
}
```

**Responsive Features:**
- **Device Detection** - Mobile (<600px), Tablet (600-1024px), Desktop (>1024px)
- **Adaptive Padding** - 24px desktop, 16px mobile
- **Conditional Headers** - Different layouts per device
- **Chart Switcher** - Toggle between Revenue, Orders, Products

---

## ⚙️ **SETTINGS_PAGE.DART**

### **SETTINGS STATE MANAGEMENT**
```dart
class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _restaurantNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _taxRateController = TextEditingController();

  String _currency = 'PHP';
  bool _darkMode = false;
  bool _notifications = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _restaurantNameController.text = prefs.getString('restaurant_name') ?? 'Yang Chow Restaurant';
      _addressController.text = prefs.getString('address') ?? 'Pagsanjan, Laguna';
      _phoneController.text = prefs.getString('phone') ?? '+63 2 123-4567';
      _emailController.text = prefs.getString('email') ?? 'info@yangchow.com';
      _taxRateController.text = prefs.getString('tax_rate') ?? '12.0';
      _currency = prefs.getString('currency') ?? 'PHP';
      _darkMode = prefs.getBool('dark_mode') ?? false;
      _notifications = prefs.getBool('notifications') ?? true;
    });
  }
```

**Settings Variables:**
- **Text Controllers** - For input fields
- **Currency** - PHP, USD, etc.
- **Dark Mode** - Theme preference
- **Notifications** - Push notification setting
- **Loading State** - During save operations

### **SAVE SETTINGS FUNCTION**
```dart
Future<void> _saveSettings() async {
  final prefs = await SharedPreferences.getInstance();
  setState(() => _isLoading = true);
  
  try {
    await prefs.setString('restaurant_name', _restaurantNameController.text);
    await prefs.setString('address', _addressController.text);
    await prefs.setString('phone', _phoneController.text);
    await prefs.setString('email', _emailController.text);
    await prefs.setString('tax_rate', _taxRateController.text);
    await prefs.setString('currency', _currency);
    await prefs.setBool('dark_mode', _darkMode);
    await prefs.setBool('notifications', _notifications);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Settings saved successfully!'),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving settings: $e'),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
        ),
      );
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

**Save Process:**
1. **Get SharedPreferences** - Local storage instance
2. **Save All Settings** - Store each preference
3. **Success Feedback** - Green snackbar
4. **Error Handling** - Red error snackbar
5. **Loading State** - Show/hide spinner

---

## 👥 **USER_MANAGEMENT_PAGE.DART**

### **STAFF ORGANIZATION DATA**
```dart
class UserManagementPage extends StatelessWidget {
  const UserManagementPage({super.key});

  // GROUPED STAFF DATA (ROLE : COUNT)
  final Map<String, int> staffByRole = const {
    'Cook': 2,
    'Dishwasher': 1,
    'Cutter': 2,
    'Cashier & Food Server': 2,
    'Dine-in Food Server': 3,
    'Supervisor': 2,
  };
```

**Staff Roles:**
- **Cook** - 2 staff members
- **Dishwasher** - 1 staff member
- **Cutter** - 2 staff members
- **Cashier & Food Server** - 2 staff members
- **Dine-in Food Server** - 3 staff members
- **Supervisor** - 2 staff members

### **ROLE SECTION COMPONENT**
```dart
class _RoleSection extends StatelessWidget {
  final String role;
  final int count;

  const _RoleSection({
    required this.role,
    required this.count,
  });

  IconData get _icon {
    switch (role) {
      case 'Cook':
        return Icons.restaurant;
      case 'Dishwasher':
        return Icons.cleaning_services;
      case 'Cutter':
        return Icons.content_cut;
      case 'Cashier & Food Server':
        return Icons.point_of_sale;
      case 'Dine-in Food Server':
        return Icons.room_service;
      case 'Supervisor':
        return Icons.supervisor_account;
      default:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SECTION HEADER
        Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.sm),
          child: Text(
            '$role ($count)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryRed,
            ),
          ),
        ),
        // Staff cards would go here
      ],
    );
  }
}
```

**Role Section Features:**
- **Icon Mapping** - Visual role identification
- **Staff Count** - Number of staff per role
- **Red Header** - Consistent with app theme
- **Expandable** - Individual staff member cards

---

## 🎯 **KEY PATTERNS ACROSS PAGES**

### **COMMON IMPORTS**
```dart
import 'package:flutter/material.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
```

### **RESPONSIVE DESIGN**
- **Device Detection** - Mobile/tablet/desktop
- **Adaptive Layouts** - Different UI per device
- **Responsive Padding** - Dynamic spacing

### **FIREBASE INTEGRATION**
- **Authentication** - User login/logout
- **Firestore** - Database operations
- **Error Handling** - Firebase exceptions

### **STATE MANAGEMENT**
- **StatefulWidget** - For dynamic content
- **setState()** - UI updates
- **Controllers** - Input field management

### **USER EXPERIENCE**
- **Loading States** - Spinners during operations
- **Error Messages** - Clear feedback
- **Success Notifications** - Green confirmations
- **Confirmation Dialogs** - Prevent accidents

---

*This covers all the major code patterns and functionality across the pages directory of the Yang Chow Restaurant Management System.*
