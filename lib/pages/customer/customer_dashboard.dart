import 'dart:async';

import 'dart:ui';



import 'package:flutter/material.dart';



import 'package:flutter/services.dart';



import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:image_picker/image_picker.dart';



import 'package:google_sign_in/google_sign_in.dart';

import 'package:google_fonts/google_fonts.dart';

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';



import 'package:yang_chow/utils/app_theme.dart';



import 'package:yang_chow/utils/app_constants.dart';

import 'package:yang_chow/utils/responsive_utils.dart';

import 'package:yang_chow/pages/customer/edit_profile_page.dart';

import 'package:yang_chow/widgets/customer_chat_modal.dart';

import 'package:yang_chow/pages/customer/customer_reviews_page.dart';

import 'package:yang_chow/pages/customer/menu_selection_page.dart';

import 'package:yang_chow/pages/customer/customer_order_list.dart';



import 'package:yang_chow/pages/customer/transactions_page.dart';

import 'package:yang_chow/pages/customer/paymongo_payment_page.dart';

import 'package:yang_chow/services/paymongo_service.dart';



import 'package:yang_chow/services/notification_service.dart';



import 'package:yang_chow/services/app_settings_service.dart';



import 'package:yang_chow/services/reservation_service.dart';

import 'package:yang_chow/services/refund_service.dart';

import 'package:yang_chow/services/reschedule_service.dart';





import 'package:yang_chow/services/menu_service.dart';



import 'package:yang_chow/services/menu_reservation_service.dart';

import 'package:yang_chow/models/menu_item.dart';



import 'package:intl/intl.dart';




import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:yang_chow/widgets/customer/customer_ui_components.dart';



class CustomerDashboardPage extends StatefulWidget {

  const CustomerDashboardPage({super.key});



  @override

  State<CustomerDashboardPage> createState() => _CustomerDashboardPageState();

}



class _CustomerDashboardPageState extends State<CustomerDashboardPage> with TickerProviderStateMixin {



  final NumberFormat _fmt = NumberFormat('#,##0.00', 'en_US');



  int _selectedIndex = 0;



  bool _isLoading = false;



  // Sidebar toggle for desktop & tablet

  bool _isSidebarOpen = true; // desktop starts open; tablet starts closed handled in _buildTabletLayout

  late AnimationController _sidebarAnimController;

  late Animation<Offset> _sidebarSlideAnim;



  final ReservationService _reservationService = ReservationService();
  final RescheduleService _rescheduleService = RescheduleService();



  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? '58922100698-ajm1bssqvgoo9k0qs15hd3g7nhrqabm4.apps.googleusercontent.com' // Web Client ID
        : '58922100698-jmttb6okfltmpcco2f2rrh8rmppappk6.apps.googleusercontent.com', // iOS Client ID
    serverClientId: kIsWeb
        ? null
        : '58922100698-ajm1bssqvgoo9k0qs15hd3g7nhrqabm4.apps.googleusercontent.com', // Web Client ID - required for idToken on Android
  );



  List<Map<String, dynamic>> customerReservations = [];
  String _activityFilter = 'all'; // 'all', 'in_progress', 'confirmed'

  bool _isEligibleForReview = false;

  Map<String, dynamic>? _customerReview;



  Stream<List<Map<String, dynamic>>>? _notificationsStream;



  String? _lastToastNotificationId;
  StreamSubscription<List<Map<String, dynamic>>>? _customerNotifsSubscription;

  // ── Featured Dishes (Realtime) ──
  StreamSubscription<List<Map<String, dynamic>>>? _featuredOrdersSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _rescheduleRequestsSubscription;
  List<Map<String, dynamic>> _featuredDishes = [];
  bool _featuredLoading = true;



  // Pre-order cart: persists across navigation until customer explicitly clears it

  Map<String, int> _preOrderCart = {};



  Future<void> _loadCartFromPrefs() async {

    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (userId == null) return;

    

    final prefs = await SharedPreferences.getInstance();

    final cartStr = prefs.getString('cart_preorder_$userId');

    if (cartStr != null) {

      try {

        final Map<String, dynamic> decoded = jsonDecode(cartStr);

        final Map<String, int> loadedCart = {};

        for (var entry in decoded.entries) {

          loadedCart[entry.key] = entry.value as int;

        }

        if (mounted) {

          setState(() {

            _preOrderCart = loadedCart;

          });

        }

      } catch (e) {

        debugPrint('Error decoding cart: $e');

      }

    }

  }



  Future<void> _saveCartToPrefs() async {

    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (userId == null) return;

    

    final prefs = await SharedPreferences.getInstance();

    final cartStr = jsonEncode(_preOrderCart);

    await prefs.setString('cart_preorder_$userId', cartStr);

  }



  // ignore: unused_element
  void _handleCartUpdated() {

    setState(() {}); // trigger rebuild so badge updates

    _saveCartToPrefs();

  }



  // Menu selection state (only set when customer confirms inside MenuSelectionPage)

  Map<String, int> _selectedMenuItems = {};



  final Map<String, num> _inventoryCache = {};

  final Map<String, List<Map<String, dynamic>>> _recipeCache = {};

  bool _isFetchingInventory = false;

  final Map<String, GlobalKey> _categoryKeys = {};

  String _selectedCategory = '';

  

  ScrollController? _scrollController;

  final Map<String, GlobalKey> _chipKeys = {};

  bool _isScrollingToCategory = false;



  final MenuReservationService _menuReservationService =

      MenuReservationService();



  // Services



  late AppSettingsService _appSettings;



  // Configuration values (will be loaded from app_settings)



  int _minGuestCount = AppConstants.defaultMinGuestCount;



  // ignore: unused_field
  int _maxGuestCount = AppConstants.defaultMaxGuestCount;



  int _operatingHoursStart = AppConstants.defaultOperatingHoursStart;



  int _operatingHoursEnd = AppConstants.defaultOperatingHoursEnd;



  late List<String> _baseDurations;



  late List<String> _extraTimeOptions;



  bool _enableSpecialRequests = AppConstants.defaultEnableSpecialRequests;



  // Form controllers



  final TextEditingController _eventController = TextEditingController();

  final TextEditingController _dateController = TextEditingController();

  final TextEditingController _startTimeController = TextEditingController();



  final TextEditingController _durationController = TextEditingController();



  final TextEditingController _guestsController = TextEditingController();



  final TextEditingController _specialRequestsController =

      TextEditingController();



  // Carousel state

  late PageController _heroPageController;

  Timer? _heroTimer;

  int _currentHeroPage = 0;



  // New state variables for form improvements



  String? _selectedEventType;



  String? _selectedBaseDuration;



  bool _addExtraTime = false;



  String? _selectedExtraTime;



  final List<String> _eventTypes = AppConstants.eventTypes;

  String _reservationType = 'Event Place';

  String _advanceOrderType = 'Dine In';



  // Payment option: 'half' for deposit, 'full' for full payment

  String _paymentOption = 'half';



  // ID Upload for verification
  // ignore: unused_field
  XFile? _selectedIdImage;

  bool _isUploadingId = false;

  String? _uploadedIdUrl;



  @override

  void initState() {

    super.initState();

    _scrollController = ScrollController()..addListener(_onMenuScroll);

    _loadCartFromPrefs();



    _appSettings = AppSettingsService();



    _loadConfigurationSettings();

    _loadCustomerReservations();

    _loadReviewEligibility();

    

    _fetchInventory();

    

    if (MenuService.categories.isNotEmpty) {

      _selectedCategory = MenuService.categories.first;

    }



    // Fetch latest menu items from Supabase database to populate dashboard dishes and carousel images

    MenuService.fetchMenu().then((_) {

      if (mounted) {

        setState(() {});

      }

    });    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null && currentUser.email != null) {
      _notificationsStream =
          NotificationService.getCustomerAdminNotificationsStream(
            currentUser.email!,
          );
      _customerNotifsSubscription = _notificationsStream!.listen((notifs) {
        if (!mounted) return;
        final unreadNotifs =
            notifs.where((n) => n['is_read'] == false).toList();
        if (unreadNotifs.isNotEmpty) {
          final latestId = unreadNotifs.first['id']?.toString();
          if (_lastToastNotificationId != null &&
              _lastToastNotificationId != latestId) {
            _showNotificationToast(unreadNotifs.first);
          }
          _lastToastNotificationId = latestId;
        }
      });
    }

    



    _heroPageController = PageController(initialPage: 0);

    _startHeroTimer();



    // Sidebar animation controller (desktop & tablet hamburger menu)

    _sidebarAnimController = AnimationController(

      vsync: this,

      duration: const Duration(milliseconds: 280),

    );

    _sidebarSlideAnim = Tween<Offset>(

      begin: const Offset(-1.0, 0.0),

      end: Offset.zero,

    ).animate(CurvedAnimation(

      parent: _sidebarAnimController,

      curve: Curves.easeInOutCubic,

    ));

    // Desktop starts with sidebar open — advance icon to "open" state

    _sidebarAnimController.forward();

    // ── Featured Dishes realtime stream ──
    _listenToFeaturedDishes();

    // ── Reschedule Requests realtime listener ──
    final currentEmail = Supabase.instance.client.auth.currentUser?.email;
    if (currentEmail != null && currentEmail.isNotEmpty) {
      _rescheduleRequestsSubscription = _rescheduleService
          .customerRescheduleRequestsStream(currentEmail)
          .listen((_) {
        if (mounted) {
          _loadCustomerReservations();
        }
      });
    }
  }



  void _startHeroTimer() {

    _heroTimer?.cancel();

    _heroTimer = Timer.periodic(const Duration(seconds: 5), (timer) {

      if (_heroPageController.hasClients) {

        final Map<String, List<MenuItem>> allMenu = MenuService.getMenu();

        final List<MenuItem> items = _getTopSellingItems(allMenu);

        

        if (_currentHeroPage < items.length - 1) {

          _currentHeroPage++;

        } else {

          _currentHeroPage = 0;

        }

        

        _heroPageController.animateToPage(

          _currentHeroPage,

          duration: const Duration(milliseconds: 800),

          curve: Curves.easeInOutCubic,

        );

      }

    });

  }



  Future<void> _loadReviewEligibility() async {

    final currentUser = Supabase.instance.client.auth.currentUser;

    if (currentUser == null) return;



    try {

      final isEligible = await _reservationService.isEligibleForReview(currentUser.email!);

      Map<String, dynamic>? review;

      if (isEligible) {

        review = await _reservationService.getCustomerReview(currentUser.email!);

      }



      if (mounted) {

        setState(() {

          _isEligibleForReview = isEligible;

          _customerReview = review;

        });

      }

    } catch (e) {

      debugPrint('Error loading review eligibility: $e');

    }

  }



  /// Load configuration settings from app_settings table



  void _loadConfigurationSettings() {

    _minGuestCount = _appSettings.getMinGuestCount();



    _maxGuestCount = _appSettings.getMaxGuestCount();



    _operatingHoursStart = _appSettings.getOperatingHoursStart();



    _operatingHoursEnd = _appSettings.getOperatingHoursEnd();



    _baseDurations = _appSettings.getBaseDurations();



    _extraTimeOptions = _appSettings.getExtraTimeOptions();



    _enableSpecialRequests = _appSettings.isSpecialRequestsEnabled();

  }



  Future<void> _loadCustomerReservations() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null || currentUser.email == null) return;

      final email = currentUser.email!;
      final lowerEmail = email.toLowerCase();

      // Fetch from reservations, advance_orders, and reschedule_requests in parallel
      final results = await Future.wait([
        Supabase.instance.client
            .from('reservations')
            .select('*')
            .eq('customer_email', email)
            .order('created_at', ascending: false),
        Supabase.instance.client
            .from('advance_orders')
            .select('*')
            .eq('customer_email', email)
            .order('created_at', ascending: false),
        Supabase.instance.client
            .from('reschedule_requests')
            .select('*')
            .or('customer_email.eq.$email,customer_email.eq.$lowerEmail')
            .order('created_at', ascending: false),
      ]);

      // Build map of latest reschedule request status by reservation_id
      final Map<String, String> latestRescheduleStatusMap = {};
      final rescheduleRequestsList = List<Map<String, dynamic>>.from(results[2]);
      for (final req in rescheduleRequestsList) {
        final resId = req['reservation_id']?.toString();
        final reqStatus = req['status']?.toString().toLowerCase();
        if (resId != null && !latestRescheduleStatusMap.containsKey(resId)) {
          if (reqStatus == 'pending') {
            latestRescheduleStatusMap[resId] = 'pending_approval';
          } else if (reqStatus == 'rejected') {
            latestRescheduleStatusMap[resId] = 'reschedule_rejected';
          } else if (reqStatus == 'approved') {
            latestRescheduleStatusMap[resId] = 'rescheduled';
          }
        }
      }

      final reservations = List<Map<String, dynamic>>.from(results[0]).map((r) {
        final resId = r['id']?.toString();
        final mappedStatus = latestRescheduleStatusMap[resId];
        return {
          ...r,
          if (mappedStatus != null) 'reschedule_status': mappedStatus,
          '_db_table': 'reservations',
        };
      }).toList();

      final advanceOrders = List<Map<String, dynamic>>.from(results[1]).map((o) {
        return {
          ...o,
          'event_type': 'Advance Order (${o['order_type']})',
          'event_date': o['order_date'],
          'start_time': o['order_time'],
          'duration_hours': 0,
          '_db_table': 'advance_orders',
        };
      }).toList();

      final combined = [...reservations, ...advanceOrders];

      // Sort combined results by created_at descending
      combined.sort((a, b) {
        final aTime = DateTime.parse(a['created_at'] ?? DateTime.now().toUtc().toIso8601String());
        final bTime = DateTime.parse(b['created_at'] ?? DateTime.now().toUtc().toIso8601String());
        return bTime.compareTo(aTime);
      });

      if (mounted) {
        setState(() {
          customerReservations = combined;
        });
      }
    } catch (e) {
      debugPrint('Error loading customer records: $e');
    }
  }



  @override
  void dispose() {
    _rescheduleRequestsSubscription?.cancel();
    _scrollController?.removeListener(_onMenuScroll);
    _scrollController?.dispose();
    _heroPageController.dispose();
    _heroTimer?.cancel();
    _sidebarAnimController.dispose();
    _eventController.dispose();
    _dateController.dispose();
    _startTimeController.dispose();

    _durationController.dispose();

    _guestsController.dispose();

    _specialRequestsController.dispose();

    _featuredOrdersSubscription?.cancel();
    _rescheduleRequestsSubscription?.cancel();
    _customerNotifsSubscription?.cancel();

    super.dispose();

  }



  void _onMenuScroll() {

    if (_isScrollingToCategory) return;

    

    for (var i = MenuService.categories.length - 1; i >= 0; i--) {

      final category = MenuService.categories[i];

      final key = _categoryKeys[category];

      if (key?.currentContext != null) {

        final box = key!.currentContext!.findRenderObject() as RenderBox?;

        if (box != null) {

          final position = box.localToGlobal(Offset.zero).dy;

          // Offset 200 handles standard tablet/desktop scroll offset for sticky header + nav

          if (position <= 200.0) {

            if (_selectedCategory != category) {

              setState(() => _selectedCategory = category);

              

              final chipKey = _chipKeys[category];

              if (chipKey?.currentContext != null) {

                Scrollable.ensureVisible(

                  chipKey!.currentContext!,

                  alignment: 0.5,

                  duration: const Duration(milliseconds: 300),

                  curve: Curves.easeInOutCubic,

                );

              }

            }

            break;

          }

        }

      }

    }

  }



  GlobalKey _getChipKey(String category) {

    if (!_chipKeys.containsKey(category)) {

      _chipKeys[category] = GlobalKey();

    }

    return _chipKeys[category]!;

  }



  Future<void> _handleRefresh() async {

    await Future.wait([

      _loadCustomerReservations(),

      _loadReviewEligibility(),

      MenuService.fetchMenu(),

    ]);

    _loadConfigurationSettings();

    if (mounted) setState(() {});

  }



  String _getUserDisplayName() {

    final metadata = Supabase.instance.client.auth.currentUser?.userMetadata;



    if (metadata != null) {

      if (metadata['firstname'] != null && metadata['lastname'] != null) {

        return '${metadata['firstname']} ${metadata['lastname']}';

      }



      final fullName = metadata['full_name']?.replaceAll('User', '');



      if (fullName != null && fullName.isNotEmpty) return fullName;



      final name = metadata['name']?.replaceAll('User', '');



      if (name != null && name.isNotEmpty) return name;

    }



    return 'User';

  }



  void _navigateToMenuSelection() async {

    final guestCount = int.tryParse(_guestsController.text.trim()) ?? 1;



    // Seed MenuSelectionPage with the pre-order cart so items are pre-populated.

    // _preOrderCart is NOT overwritten on return — it persists until customer deletes items.

    await Navigator.push(

      context,



      MaterialPageRoute(

        builder: (context) => MenuSelectionPage(

          reservationType: _reservationType,



          guestCount: guestCount,



          initialSelection: Map<String, int>.from(_preOrderCart)

            ..addAll(_selectedMenuItems),



          onMenuSelected: (selectedItems) {

            setState(() {

              _selectedMenuItems = selectedItems;

              // Redirect the user to the Reservation tab so they can set the event details

              _selectedIndex = 1;

            });

          },

        ),

      ),

    );

  }



  @override

  Widget build(BuildContext context) {

    final isDesktop = ResponsiveUtils.isDesktop(context);

    final isTablet  = ResponsiveUtils.isTablet(context);



    return AnnotatedRegion<SystemUiOverlayStyle>(

      value: SystemUiOverlayStyle(

        statusBarColor: Colors.transparent,

        systemNavigationBarColor: (isDesktop || isTablet) ? Colors.white : AppTheme.navColor,

        systemNavigationBarIconBrightness: (isDesktop || isTablet) ? Brightness.dark : Brightness.light,

      ),

      child: Scaffold(

        backgroundColor: (isDesktop || isTablet) ? AppTheme.backgroundColor : AppTheme.navColor,



        appBar: (isDesktop || isTablet)

            ? null

            : _buildDashboardAppBar(_getAppBarTitle()),



        body: Stack(

          children: [

            isDesktop

                ? _buildDesktopLayout()

                : isTablet

                    ? _buildTabletLayout()

                    : _buildMobileLayout(),

            const CustomerChatModal(),

          ],

        ),

      ),

    );

  }



  String _getAppBarTitle() {

    switch (_selectedIndex) {

      case 0:

        return 'Home';

      case 1:

        return 'Reservation';

      case 2:

        return 'Transaction';

      case 3:

        return 'Activity';

      case 4:

        return 'Profile';

      default:

        return 'Home';

    }

  }



  PreferredSizeWidget _buildDashboardAppBar(String title) {

    return AppBar(

      backgroundColor: AppTheme.navColor,

      elevation: 0,

      scrolledUnderElevation: 0,

      shadowColor: Colors.transparent,

      automaticallyImplyLeading: false,

      leading: IconButton(

        icon: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 24),

        onPressed: () => setState(() => _selectedIndex = 4),

        tooltip: 'Account',

      ),

      centerTitle: true,

      title: Text(

        title,

        style: GoogleFonts.lora(

          color: Colors.white,

          fontWeight: FontWeight.w700,

          fontSize: 20,

          letterSpacing: -0.3,

        ),

      ),

      actions: [

        _buildCartIcon(),

        _buildNotificationIcon(),

        const SizedBox(width: 8),

      ],

    );

  }



  Widget _buildNotificationIcon() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _notificationsStream,
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? [];
        final unreadCount =
            notifications.where((n) => n['is_read'] == false).length;
        final hasUnread = unreadCount > 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(
                hasUnread
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                color: hasUnread ? AppTheme.warmGold : Colors.white,
                size: 24,
              ),
              onPressed: () {
                _showNotificationsDialog(notifications);
              },
              tooltip: hasUnread
                  ? '$unreadCount unread notification${unreadCount > 1 ? 's' : ''}'
                  : 'Notifications',
            ),
            if (hasUnread)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  constraints:
                      const BoxConstraints(minWidth: 18, minHeight: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444), // Vibrant Red
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.6),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showNotificationToast(Map<String, dynamic> n) {
    if (!mounted) return;
    final title = _getNotificationTitle(n);
    final subtitle = _getNotificationSubtitle(n);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.warmGold.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_active_rounded,
                color: AppTheme.warmGold,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: const Color(0xFF94A3B8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                final currentUser = Supabase.instance.client.auth.currentUser;
                if (currentUser?.email != null) {
                  NotificationService.getCustomerAdminNotificationsStream(
                    currentUser!.email!,
                  ).first.then((notifs) {
                    if (mounted) _showNotificationsDialog(notifs);
                  });
                }
              },
              child: Text(
                'VIEW',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: AppTheme.warmGold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }



  void _showNotificationsDialog(List<Map<String, dynamic>> notifications) {

    if (notifications.isNotEmpty) {

      final unreadIds = notifications

          .where((n) => !n['is_read'])

          .map((n) => n['id'].toString())

          .toList();



      if (unreadIds.isNotEmpty) {

        NotificationService.markVisibleAsRead(unreadIds);

      }

    }



    showDialog(

      context: context,

      builder: (context) => AlertDialog(

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),

        title: Row(

          children: [

            Container(

              padding: const EdgeInsets.all(10),

              decoration: BoxDecoration(

                color: AppTheme.primaryColor.withValues(alpha: 0.12),

                borderRadius: BorderRadius.circular(12),

              ),

              child: const Icon(Icons.notifications_rounded, color: AppTheme.primaryColor, size: 24),

            ),

            const SizedBox(width: 14),

            const Text(

              'Notifications',

              style: TextStyle(

                fontWeight: FontWeight.w700,

                fontSize: 18,

                letterSpacing: -0.3,

              ),

            ),

          ],

        ),



        content: SizedBox(

          width: double.maxFinite,



          child: notifications.isEmpty

              ? Column(

                  mainAxisSize: MainAxisSize.min,

                  children: [

                    const Divider(height: 1),

                    const SizedBox(height: 24),

                    Container(

                      width: 100,

                      height: 100,

                      decoration: BoxDecoration(

                        color: AppTheme.lightGrey,

                        shape: BoxShape.circle,

                      ),

                      child: Icon(

                        Icons.notifications_off_outlined,

                        size: 48,

                        color: AppTheme.mediumGrey,

                      ),

                    ),

                    const SizedBox(height: 20),

                    const Text(

                      'No notifications',

                      style: TextStyle(

                        fontWeight: FontWeight.w700,

                        fontSize: 18,

                        letterSpacing: -0.3,

                      ),

                    ),

                    const SizedBox(height: 8),

                    Text(

                      'We\'ll let you know when there\'s activity on your reservations.',

                      textAlign: TextAlign.center,

                      style: TextStyle(

                        color: AppTheme.mediumGrey,

                        fontSize: 14,

                        fontWeight: FontWeight.w500,

                      ),

                    ),

                    const SizedBox(height: 20),

                  ],

                )

              : ListView.separated(

                  shrinkWrap: true,



                  itemCount: notifications.length,



                  separatorBuilder: (context, index) => const Divider(),



                  itemBuilder: (context, index) {

                    final n = notifications[index];



                    final date = DateTime.parse(n['created_at']).toLocal();



                    final timeStr = DateFormat('MMM d, h:mm a').format(date);



                    IconData icon;



                    Color color;



                    switch (n['action_type']) {

                      case 'created':

                        icon = Icons.add_circle_outline;

                        color = AppTheme.infoBlue;

                        break;

                      case 'approved':

                      case 'completed':

                        icon = Icons.check_circle_outline;

                        color = AppTheme.successGreen;

                        break;

                      case 'cancelled':

                      case 'rejected':

                      case 'deleted':

                        icon = Icons.highlight_off;

                        color = AppTheme.errorRed;

                        break;

                      case 'updated':

                        icon = Icons.update;

                        color = AppTheme.warningOrange;

                        break;

                      case 'paid':

                      case 'deposit_paid':

                      case 'fully_paid':

                      case 'balance_cleared':

                        icon = Icons.payment;

                        color = AppTheme.successGreen;

                        break;

                      case 'reschedule_approved':

                        icon = Icons.event_available_rounded;

                        color = AppTheme.successGreen;

                        break;

                      case 'reschedule_rejected':

                        icon = Icons.event_busy_rounded;

                        color = AppTheme.errorRed;

                        break;

                      case 'refund_approved':

                      case 'refund_processed':

                        icon = Icons.currency_exchange_rounded;

                        color = AppTheme.infoBlue;

                        break;

                      case 'refund_rejected':

                        icon = Icons.highlight_off;

                        color = AppTheme.errorRed;

                        break;

                      default:

                        icon = Icons.notifications_none;

                        color = AppTheme.mediumGrey;

                    }



                    return ListTile(

                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

                      leading: CircleAvatar(

                        backgroundColor: color.withValues(alpha: 0.12),

                        radius: 22,

                        child: Icon(icon, color: color, size: 22),

                      ),

                      title: Text(

                        _getNotificationTitle(n),

                        style: const TextStyle(

                          fontWeight: FontWeight.w700,

                          fontSize: 14,

                          letterSpacing: -0.2,

                        ),

                      ),

                      subtitle: Column(

                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [

                          const SizedBox(height: 4),

                          Text(

                            _getNotificationSubtitle(n),

                            style: const TextStyle(

                              fontSize: 13,

                              fontWeight: FontWeight.w500,

                            ),

                          ),

                          const SizedBox(height: 4),

                          Text(

                            timeStr,

                            style: TextStyle(

                              fontSize: 11,

                              color: AppTheme.mediumGrey,

                              fontWeight: FontWeight.w400,

                            ),

                          ),

                        ],

                      ),

                    );

                  },

                ),

        ),



        actions: [

          TextButton(

            onPressed: () => Navigator.pop(context),

            child: const Text(

              'Close',

              style: TextStyle(

                fontWeight: FontWeight.w600,

                fontSize: 15,

              ),

            ),

          ),

        ],

      ),

    );

  }



  /// Generate role-specific and context-aware notification subtitle



  String _getNotificationSubtitle(Map<String, dynamic> n) {

    final isForAdmin = n['is_for_admin'] ?? false;



    final eventType = n['event_type'];



    final eventDate = n['event_date'];



    final customerEmail = n['customer_email'];



    final guestCount = n['guest_count'];



    final startTime = n['start_time'];



    // For admin notifications - show customer and reservation details



    if (isForAdmin) {

      String details = "";



      if (customerEmail != null) {

        details += "Customer: $customerEmail";

      }



      if (eventType != null) {

        details += details.isEmpty ? eventType : " • $eventType";

      }



      if (eventDate != null) {

        details += details.isEmpty ? "Date: $eventDate" : " • $eventDate";

      }



      if (guestCount != null) {

        details += " • $guestCount guests";

      }



      return details.isEmpty ? "Reservation activity" : details;

    }



    // For customer notifications - show event and time info



    if (eventType != null && eventDate != null) {

      String details = "$eventType on $eventDate";



      if (startTime != null) {

        details += " at $startTime";

      }



      if (guestCount != null) {

        details += " • $guestCount guests";

      }



      return details;

    }



    return eventType ?? "Activity on your reservation";

  }



  String _getNotificationTitle(Map<String, dynamic> n) {

    final isForAdmin = n['is_for_admin'] ?? false;



    final actorName = n['actor_name'] ?? 'User';



    final actionType = n['action_type'];



    // For admin notifications - include who took the action



    if (isForAdmin) {

      switch (actionType) {

        case 'created':

          return 'New Reservation from $actorName';



        case 'approved':

          return 'Reservation Approved by $actorName';



        case 'cancelled':

          return 'Reservation Cancelled by $actorName';



        case 'deleted':

          return 'Reservation Deleted by $actorName';



        case 'rejected':

          return 'Reservation Rejected by $actorName';



        case 'updated':

          return 'Reservation Updated by $actorName';



        case 'paid':

          return 'Payment Confirmed from $actorName';



        default:

          return 'Activity from $actorName';

      }

    }



    // For customer notifications - focus on the action



    switch (actionType) {

      case 'created':

        return 'Reservation Received';



      case 'approved':

        return 'Your Reservation is Approved';



      case 'cancelled':

        return 'Reservation Cancelled';



      case 'deleted':

        return 'Reservation Deleted';



      case 'rejected':

        return 'Reservation Could Not Be Approved';



      case 'updated':

        return 'Reservation Updated';



      case 'paid':

        return 'Payment Confirmed';



      case 'deposit_paid':

        return 'Deposit Payment Confirmed';



      case 'fully_paid':

        return 'Full Payment Confirmed';



      case 'balance_cleared':

        return 'Remaining Balance Paid';



      case 'reschedule_approved':

        return 'Reschedule Request Approved';



      case 'reschedule_rejected':

        return 'Reschedule Request Declined';



      case 'refund_approved':

        return 'Refund Request Approved';



      case 'refund_processed':

        return 'Refund Processed';



      case 'refund_rejected':

        return 'Refund Request Rejected';



      case 'completed':

        return 'Reservation Completed';



      default:

        return 'Notification';

    }

  }



  // =========================



  // SHARED SIDEBAR COLUMN (used by desktop & tablet)



  // =========================



  Widget _buildDesktopSidebarColumn({bool closeable = false}) {

    final navItems = [

      {'icon': Icons.home_rounded, 'label': 'Home', 'subtitle': 'Dashboard'},

      {'icon': Icons.event_available_rounded, 'label': 'Reservations', 'subtitle': 'Book an event'},

      {'icon': Icons.monetization_on_rounded, 'label': 'Transaction', 'subtitle': 'Payment history'},

      {'icon': Icons.assignment_rounded, 'label': 'Activity', 'subtitle': 'Track orders'},

    ];



    return Container(

      width: 280,

      decoration: const BoxDecoration(

        color: AppTheme.forestGreen, // #16302A

        border: Border(

          right: BorderSide(color: AppTheme.sidebarDivider, width: 1), // #2B4941

        ),

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          // Logo & Brand Section

          Container(

            padding: const EdgeInsets.fromLTRB(20, 20, 16, 18),

            decoration: const BoxDecoration(

              border: Border(

                bottom: BorderSide(color: AppTheme.sidebarDivider, width: 1),

              ),

            ),

            child: Row(

              children: [

                if (closeable)

                  GestureDetector(

                    onTap: () {

                      _sidebarAnimController.reverse();

                      setState(() => _isSidebarOpen = false);

                    },

                    child: Container(

                      width: 32,

                      height: 32,

                      margin: const EdgeInsets.only(right: 10),

                      decoration: BoxDecoration(

                        color: AppTheme.sidebarDivider.withValues(alpha: 0.5),

                        shape: BoxShape.circle,

                      ),

                      child: const Icon(Icons.close_rounded, color: AppTheme.sidebarInactiveText, size: 18),

                    ),

                  ),



                // Logo with subtle gold accent ring

                Container(

                  padding: const EdgeInsets.all(2),

                  decoration: const BoxDecoration(

                    color: AppTheme.warmGold,

                    shape: BoxShape.circle,

                  ),

                  child: Container(

                    padding: const EdgeInsets.all(2),

                    decoration: const BoxDecoration(

                      color: AppTheme.forestGreen,

                      shape: BoxShape.circle,

                    ),

                    child: ClipOval(

                      child: Image.asset(

                        'assets/images/ycplogo.png',

                        width: 36,

                        height: 36,

                        fit: BoxFit.contain,

                      ),

                    ),

                  ),

                ),

                const SizedBox(width: 12),



                // Brand Title & Subtitle

                Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  mainAxisSize: MainAxisSize.min,

                  children: [

                    Text(

                      'Yang Chow',

                      style: GoogleFonts.lora(

                        color: AppTheme.priceBadgeText, // #F5F1E6

                        fontSize: 18,

                        fontWeight: FontWeight.w800,

                        letterSpacing: 0.3,

                      ),

                    ),

                    Text(

                      'Customer Portal',

                      style: GoogleFonts.inter(

                        color: AppTheme.sidebarSubtitle, // #8FA89E

                        fontSize: 11,

                        fontWeight: FontWeight.w600,

                        letterSpacing: 0.5,

                      ),

                    ),

                  ],

                ),

              ],

            ),

          ),



          const SizedBox(height: 12),



          // Section Label

          Padding(

            padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),

            child: Text(

              'NAVIGATION',

              style: GoogleFonts.inter(

                fontSize: 10,

                fontWeight: FontWeight.w800,

                color: AppTheme.sidebarSubtitle,

                letterSpacing: 1.5,

              ),

            ),

          ),



          // Navigation Items (Rules: 3px gold left border + 10-15% gold opacity background)

          ...List.generate(navItems.length, (index) {

            final item = navItems[index];

            final isSelected = _selectedIndex == index;



            return Padding(

              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),

              child: GestureDetector(

                onTap: () {

                  HapticFeedback.selectionClick();

                  setState(() {

                    _selectedIndex = index;

                    if (closeable) {

                      _isSidebarOpen = false;

                      _sidebarAnimController.reverse();

                    }

                  });

                },

                child: AnimatedContainer(

                  duration: const Duration(milliseconds: 250),

                  curve: Curves.easeOutCubic,

                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),

                  decoration: BoxDecoration(

                    // Rule: 10-15% gold opacity fill when active, transparent when inactive

                    color: isSelected

                        ? AppTheme.warmGold.withValues(alpha: 0.13)

                        : Colors.transparent,

                    borderRadius: const BorderRadius.only(

                      topRight: Radius.circular(12),

                      bottomRight: Radius.circular(12),

                      topLeft: Radius.circular(4),

                      bottomLeft: Radius.circular(4),

                    ),

                    // Rule: 3px gold left-border accent

                    border: Border(

                      left: BorderSide(

                        color: isSelected ? AppTheme.warmGold : Colors.transparent,

                        width: 3,

                      ),

                    ),

                  ),

                  child: Row(

                    children: [

                      Icon(

                        item['icon'] as IconData,

                        size: 20,

                        color: isSelected

                            ? AppTheme.warmGold

                            : AppTheme.sidebarInactiveIcon, // #9DB5AB

                      ),

                      const SizedBox(width: 14),



                      // Label & Subtitle

                      Expanded(

                        child: Column(

                          crossAxisAlignment: CrossAxisAlignment.start,

                          mainAxisSize: MainAxisSize.min,

                          children: [

                            Text(

                              item['label'] as String,

                              style: GoogleFonts.inter(

                                fontSize: 14,

                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,

                                color: isSelected

                                    ? AppTheme.warmGold

                                    : AppTheme.sidebarInactiveText, // #DDE5E0

                              ),

                            ),

                            Text(

                              item['subtitle'] as String,

                              style: GoogleFonts.inter(

                                fontSize: 11,

                                fontWeight: FontWeight.w500,

                                color: isSelected

                                    ? AppTheme.warmGold.withValues(alpha: 0.8)

                                    : AppTheme.sidebarSubtitle, // #8FA89E

                              ),

                            ),

                          ],

                        ),

                      ),



                      if (isSelected)

                        const Icon(

                          Icons.chevron_right_rounded,

                          size: 16,

                          color: AppTheme.warmGold,

                        ),

                    ],

                  ),

                ),

              ),

            );

          }),



          const Spacer(),



          // Divider

          const Divider(height: 1, color: AppTheme.sidebarDivider),



          // User Profile Summary Tile

          GestureDetector(

            onTap: () => setState(() => _selectedIndex = 4),

            child: Container(

              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),

              child: Row(

                children: [

                  Container(

                    width: 38,

                    height: 38,

                    decoration: BoxDecoration(

                      color: AppTheme.warmGold,

                      shape: BoxShape.circle,

                    ),

                    child: Center(

                      child: Text(

                        _getUserDisplayName().isNotEmpty

                            ? _getUserDisplayName()[0].toUpperCase()

                            : 'Y',

                        style: GoogleFonts.inter(

                          fontSize: 16,

                          fontWeight: FontWeight.bold,

                          color: AppTheme.darkBrownText,

                        ),

                      ),

                    ),

                  ),

                  const SizedBox(width: 12),

                  Expanded(

                    child: Column(

                      crossAxisAlignment: CrossAxisAlignment.start,

                      mainAxisSize: MainAxisSize.min,

                      children: [

                        Text(

                          _getUserDisplayName(),

                          maxLines: 1,

                          overflow: TextOverflow.ellipsis,

                          style: GoogleFonts.inter(

                            fontSize: 13,

                            fontWeight: FontWeight.w700,

                            color: AppTheme.sidebarInactiveText,

                          ),

                        ),

                        Text(

                          Supabase.instance.client.auth.currentUser?.email ?? '',

                          maxLines: 1,

                          overflow: TextOverflow.ellipsis,

                          style: GoogleFonts.inter(

                            fontSize: 11,

                            color: AppTheme.sidebarSubtitle,

                          ),

                        ),

                      ],

                    ),

                  ),

                  const Icon(

                    Icons.chevron_right_rounded,

                    color: AppTheme.sidebarInactiveIcon,

                    size: 18,

                  ),

                ],

              ),

            ),

          ),

          const SizedBox(height: 8),

        ],

      ),

    );

  }



  // =========================



  // TABLET LAYOUT (HAMBURGER SLIDE-IN SIDEBAR)



  // =========================



  Widget _buildTabletLayout() {

    return Stack(

      children: [

        // Main layout column

        Column(

          children: [

            // Header bar

            Container(

              color: AppTheme.navColor,

              child: SafeArea(

                bottom: false,

                child: Padding(

                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

                  child: Row(

                    children: [

                      // Hamburger button

                      IconButton(

                        icon: AnimatedIcon(

                          icon: AnimatedIcons.menu_close,

                          progress: _sidebarAnimController,

                          color: Colors.white,

                        ),

                        onPressed: () {

                          setState(() => _isSidebarOpen = !_isSidebarOpen);

                          if (_isSidebarOpen) {

                            _sidebarAnimController.forward();

                          } else {

                            _sidebarAnimController.reverse();

                          }

                        },

                        tooltip: 'Menu',

                      ),

                      const SizedBox(width: 4),

                      // Centered title

                      Expanded(

                        child: Text(

                          _getAppBarTitle(),

                          textAlign: TextAlign.center,

                          style: GoogleFonts.lora(

                            color: Colors.white,

                            fontSize: 20,

                            fontWeight: FontWeight.w800,

                          ),

                        ),

                      ),

                      // Action icons

                      _buildCartIcon(),

                      _buildNotificationIcon(),

                      IconButton(

                        icon: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 24),

                        onPressed: () => setState(() => _selectedIndex = 4),

                        tooltip: 'Account',

                      ),

                      const SizedBox(width: 4),

                    ],

                  ),

                ),

              ),

            ),



            // Content area

            Expanded(

              child: Container(

                color: AppTheme.backgroundColor,

                child: Padding(

                  padding: ResponsiveUtils.getResponsivePadding(context),

                  child: Align(

                    alignment: Alignment.topCenter,

                    child: ConstrainedBox(

                      constraints: BoxConstraints(

                        maxWidth: ResponsiveUtils.getMaxContentWidth(),

                      ),

                      child: _buildContent(),

                    ),

                  ),

                ),

              ),

            ),

          ],

        ),



        // Dim backdrop

        if (_isSidebarOpen)

          GestureDetector(

            onTap: () {

              _sidebarAnimController.reverse();

              setState(() => _isSidebarOpen = false);

            },

            child: AnimatedOpacity(

              opacity: _isSidebarOpen ? 1.0 : 0.0,

              duration: const Duration(milliseconds: 280),

              child: Container(

                color: Colors.black.withValues(alpha: 0.45),

              ),

            ),

          ),



        // Slide-in sidebar panel

        SlideTransition(

          position: _sidebarSlideAnim,

          child: Align(

            alignment: Alignment.centerLeft,

            child: _buildDesktopSidebarColumn(closeable: true),

          ),

        ),

      ],

    );

  }



  // =========================



  // DESKTOP LAYOUT (DARK SIDEBAR)



  // =========================



  Widget _buildDesktopLayout() {

    return Row(

      children: [

        // Collapsible sidebar — width animates between 280 and 0

        AnimatedContainer(

          duration: const Duration(milliseconds: 280),

          curve: Curves.easeInOutCubic,

          width: _isSidebarOpen ? 280 : 0,

          child: ClipRect(

            child: OverflowBox(

              alignment: Alignment.centerLeft,

              maxWidth: 280,

              child: _buildDesktopSidebarColumn(),

            ),

          ),

        ),



        // Main Content

        Expanded(

          child: Container(

            color: AppTheme.backgroundColor,

            child: Column(

              children: [

                // Header

                Container(

                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),

                  color: AppTheme.navColor,

                  child: Row(

                    children: [

                      // Hamburger toggle

                      IconButton(

                        icon: AnimatedIcon(

                          icon: AnimatedIcons.menu_close,

                          progress: _sidebarAnimController,

                          color: Colors.white,

                        ),

                        onPressed: () {

                          setState(() => _isSidebarOpen = !_isSidebarOpen);

                          if (_isSidebarOpen) {

                            _sidebarAnimController.forward();

                          } else {

                            _sidebarAnimController.reverse();

                          }

                        },

                        tooltip: 'Toggle menu',

                      ),

                      const SizedBox(width: 4),

                      // Centered title

                      Expanded(

                        child: Text(

                          _getAppBarTitle(),

                          textAlign: TextAlign.center,

                          style: GoogleFonts.lora(

                            fontSize: 24,

                            fontWeight: FontWeight.w800,

                            color: Colors.white,

                          ),

                        ),

                      ),

                      // Action icons

                      _buildCartIcon(),

                      _buildNotificationIcon(),

                      const SizedBox(width: 4),

                      IconButton(

                        onPressed: () => setState(() => _selectedIndex = 4),

                        icon: const Icon(

                          Icons.person_outline_rounded,

                          color: Colors.white,

                        ),

                        tooltip: 'Account',

                      ),

                      const SizedBox(width: 8),

                    ],

                  ),

                ),



                // Content Area

                Expanded(

                  child: Padding(

                    padding: ResponsiveUtils.getResponsivePadding(context),

                    child: Align(

                      alignment: Alignment.topCenter,

                      child: ConstrainedBox(

                        constraints: BoxConstraints(

                          maxWidth: ResponsiveUtils.getMaxContentWidth(),

                        ),

                        child: _buildContent(),

                      ),

                    ),

                  ),

                ),

              ],

            ),

          ),

        ),

      ],

    );

  }



  // MOBILE LAYOUT (BOTTOM NAV)



  // =========================



  Widget _buildMobileLayout() {

    return Column(

      children: [

        // Main Content

        Expanded(

          child: RefreshIndicator(

              onRefresh: _handleRefresh,

              color: AppTheme.primaryColor,

              child: Padding(

                padding: EdgeInsets.zero,

                child: _buildContent(),

              ),

            ),

        ),



        // Modern Animated Mobile Navigation at Bottom (#16302A Forest Green & #E8B84B Warm Gold)
        if (MediaQuery.of(context).viewInsets.bottom == 0)
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              decoration: const BoxDecoration(

              color: AppTheme.forestGreen, // #16302A

              border: Border(top: BorderSide(color: AppTheme.sidebarDivider, width: 1)), // #2B4941

            ),

            child: Row(

              mainAxisAlignment: MainAxisAlignment.spaceAround,

              children: [

                _buildMobileNavItem(0, Icons.home_rounded, 'Home'),

                _buildMobileNavItem(1, Icons.event_available_rounded, 'Reserve'),

                _buildMobileNavItem(2, Icons.monetization_on_rounded, 'Price'),

                _buildMobileNavItem(3, Icons.assignment_rounded, 'Activity'),

              ],

            ),

          ),

        ),

      ],

    );

  }



  Widget _buildMobileNavItem(int index, IconData icon, String label) {

    final isSelected = _selectedIndex == index;



    return GestureDetector(

      onTap: () {

        HapticFeedback.selectionClick();

        setState(() {

          _selectedIndex = index;

        });

      },

      behavior: HitTestBehavior.opaque,

      child: AnimatedContainer(

        duration: const Duration(milliseconds: 280),

        curve: Curves.easeOutCubic,

        padding: EdgeInsets.symmetric(

          horizontal: isSelected ? 18 : 12,

          vertical: 7,

        ),

        decoration: BoxDecoration(

          color: isSelected ? AppTheme.warmGold : Colors.transparent, // #E8B84B warm gold when active

          borderRadius: BorderRadius.circular(26),

          boxShadow: isSelected

              ? [

                  BoxShadow(

                    color: AppTheme.warmGold.withValues(alpha: 0.35),

                    blurRadius: 10,

                    offset: const Offset(0, 4),

                  ),

                ]

              : null,

        ),

        child: Row(

          mainAxisSize: MainAxisSize.min,

          children: [

            AnimatedScale(

              scale: isSelected ? 1.1 : 1.0,

              duration: const Duration(milliseconds: 250),

              child: Icon(

                icon,

                color: isSelected ? AppTheme.darkBrownText : AppTheme.sidebarInactiveIcon, // #412402 on gold / #9DB5AB inactive

                size: 22,

              ),

            ),

            if (isSelected) ...[

              const SizedBox(width: 7),

              Text(

                label,

                style: GoogleFonts.inter(

                  color: AppTheme.darkBrownText, // #412402 Dark brown text

                  fontWeight: FontWeight.w900,

                  fontSize: 13,

                  letterSpacing: 0.1,

                ),

              ),

            ],

          ],

        ),

      ),

    );

  }





  Widget _buildContent() {

    return Container(

      color: AppTheme.backgroundColor,

      padding: const EdgeInsets.only(top: 8), // Reduced from 12

      child: AnimatedSwitcher(

        duration: const Duration(milliseconds: 300),

        switchInCurve: Curves.easeOutCubic,

        switchOutCurve: Curves.easeInCubic,

        transitionBuilder: (Widget child, Animation<double> animation) {

          return FadeTransition(

            opacity: animation,

            child: SlideTransition(

              position: Tween<Offset>(

                begin: const Offset(0.02, 0),

                end: Offset.zero,

              ).animate(animation),

              child: child,

            ),

          );

        },

        child: KeyedSubtree(

          key: ValueKey<int>(_selectedIndex),

          child: _getSectionWidget(),

        ),

      ),

    );

  }



  Widget _getSectionWidget() {

    switch (_selectedIndex) {

      case 0:

        return _buildHomeSection();

      case 1:

        return _buildReservationsSection();

      case 2:

        return _buildQuotationsSection();

      case 3:

        return _buildActivitySection();

      case 4:

        return _buildProfileSection();

      default:

        return _buildHomeSection();

    }

  }



  Widget _buildSubSelectionButton(String label, IconData icon) {
    final isSelected = _advanceOrderType == label;

    return AnimatedTapScale(
      onTap: () => setState(() => _advanceOrderType = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.goldGradient : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? Colors.transparent : AppTheme.cardBorder,
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.warmGold.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppTheme.darkBrownText : AppTheme.forestGreen,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: isSelected ? AppTheme.darkBrownText : AppTheme.darkGrey,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }



  List<MenuItem> _getTopSellingItems(Map<String, List<MenuItem>> allMenu) {

    final List<MenuItem> flattenedItems = [];

    for (var list in allMenu.values) {

      flattenedItems.addAll(list);

    }

    

    final List<String> topSellingNames = [

      'YangChow 1',

      'YangChow 3',

      'Buttered Chicken',

      'Lechon Macau',

      'Pancit Canton',

      'Yang Chow Fried Rice',

      'Siomai with Shrimp',

      'Sweet and Sour Pork',

      'Broccoli Leaves with Oyster Sauce',

    ];

    

    final List<MenuItem> items = [];

    for (var name in topSellingNames) {

      final found = flattenedItems.where((item) => item.name.trim().toLowerCase() == name.trim().toLowerCase()).toList();

      if (found.isNotEmpty) {

        items.add(found.first);

      }

    }

    

    // Fallback: If no or few items match the curated list, dynamically fill it up with other menu items from database

    if (items.length < 5 && flattenedItems.isNotEmpty) {

      for (final item in flattenedItems) {

        if (!items.any((existing) => existing.id == item.id || existing.name == item.name)) {

          items.add(item);

        }

        if (items.length >= 9) break;

      }

    }

    return items;
  }

  Widget _buildHeroCarousel() {
    final Map<String, List<MenuItem>> allMenu = MenuService.getMenu();
    final List<MenuItem> items = _getTopSellingItems(allMenu);

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: ResponsiveUtils.isDesktop(context) ? 380 : 230,
          child: PageView.builder(
            controller: _heroPageController,
            onPageChanged: (index) => setState(() => _currentHeroPage = index),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return AnimatedBuilder(
                animation: _heroPageController,
                builder: (context, child) {
                  double value = 1.0;
                  if (_heroPageController.position.haveDimensions) {
                    value = _heroPageController.page! - index;
                    value = (1 - (value.abs() * 0.25)).clamp(0.0, 1.0);
                  }
                  return Center(
                    child: SizedBox(
                      height: Curves.easeOutCubic.transform(value) * (ResponsiveUtils.isDesktop(context) ? 380 : 230),
                      width: double.infinity,
                      child: child,
                    ),
                  );
                },
                child: GestureDetector(
                  onTap: () => _showMenuItemDetailsDialog(item),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _buildImageWidget(item),
                          // Multi-stop Rich Gradient Scrim
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.2),
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.5),
                                  Colors.black.withValues(alpha: 0.92),
                                ],
                                stops: const [0.0, 0.3, 0.65, 1.0],
                              ),
                            ),
                          ),
                          // Top Badge
                          Positioned(
                            top: 14,
                            left: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                gradient: AppTheme.goldGradient,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.stars_rounded, size: 14, color: AppTheme.darkBrownText),
                                  const SizedBox(width: 4),
                                  Text(
                                    "CHEF'S SPECIAL",
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.darkBrownText,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Bottom Ad Info Content
                          Positioned(
                            left: 20,
                            bottom: 18,
                            right: 20,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (item.category.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          margin: const EdgeInsets.only(bottom: 6),
                                          decoration: BoxDecoration(
                                            color: AppTheme.warmGold.withValues(alpha: 0.25),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppTheme.warmGold.withValues(alpha: 0.5)),
                                          ),
                                          child: Text(
                                            item.category.toUpperCase(),
                                            style: GoogleFonts.inter(
                                              color: AppTheme.primaryLight,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ),
                                      Text(
                                        item.name,
                                        style: GoogleFonts.lora(
                                          color: Colors.white,
                                          fontSize: ResponsiveUtils.isDesktop(context) ? 28 : 20,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      if (item.description != null && item.description!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          item.description!,
                                          style: GoogleFonts.inter(
                                            color: Colors.white.withValues(alpha: 0.88),
                                            fontSize: ResponsiveUtils.isDesktop(context) ? 14 : 12,
                                            fontWeight: FontWeight.w400,
                                            height: 1.25,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.goldGradient,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.warmGold.withValues(alpha: 0.4),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '₱${_fmt.format(item.price)}',
                                    style: GoogleFonts.inter(
                                      color: AppTheme.darkBrownText,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(items.length, (index) {
            final isActive = _currentHeroPage == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 6,
              width: isActive ? 28 : 6,
              decoration: BoxDecoration(
                gradient: isActive ? AppTheme.goldGradient : null,
                color: isActive ? null : Colors.grey.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(4),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppTheme.goldenAmber.withValues(alpha: 0.5),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildHomeSection() {
    final Map<String, List<MenuItem>> allMenu = MenuService.getMenu();
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : (hour < 18 ? 'Good afternoon' : 'Good evening');
    final formattedDate = DateFormat('EEEE, MMMM d').format(DateTime.now());

    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Realistic Luxury Welcome Banner ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF0C241F),
                        Color(0xFF13362F),
                        Color(0xFF1B453D),
                      ],
                      stops: [0.0, 0.6, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppTheme.warmGold.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0A1C18).withValues(alpha: 0.45),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: AppTheme.warmGold.withValues(alpha: 0.08),
                        blurRadius: 35,
                        spreadRadius: -2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(23),
                    child: Stack(
                      children: [
                        // Decorative Gold Bokeh Glow (Top Right)
                        Positioned(
                          right: -40,
                          top: -40,
                          child: Container(
                            width: 170,
                            height: 170,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppTheme.warmGold.withValues(alpha: 0.22),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Decorative Forest Bokeh Glow (Bottom Left)
                        Positioned(
                          left: -30,
                          bottom: -30,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  const Color(0xFF285E53).withValues(alpha: 0.4),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Ambient Restaurant Watermark Silhouette (Right side for realism)
                        Positioned(
                          right: 15,
                          bottom: -15,
                          child: IgnorePointer(
                            child: Icon(
                              Icons.restaurant_rounded,
                              size: 130,
                              color: AppTheme.warmGold.withValues(alpha: 0.04),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Row: Date Pill & VIP Patron Chip
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.calendar_today_rounded, size: 12, color: AppTheme.warmGold),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              formattedDate,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                color: Colors.white.withValues(alpha: 0.9),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.goldGradient,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.warmGold.withValues(alpha: 0.35),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.verified_rounded, size: 13, color: AppTheme.darkBrownText),
                                        const SizedBox(width: 4),
                                        Text(
                                          'VALUED CUSTOMER',
                                          style: GoogleFonts.inter(
                                            color: AppTheme.darkBrownText,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // User Info & Status Row
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Hero(
                                    tag: 'user_avatar',
                                    child: Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            AppTheme.warmGold,
                                            AppTheme.warmGold.withValues(alpha: 0.4),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppTheme.warmGold.withValues(alpha: 0.3),
                                            blurRadius: 10,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      padding: const EdgeInsets.all(2.5),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF13362F),
                                          shape: BoxShape.circle,
                                          image: Supabase.instance.client.auth.currentUser?.userMetadata?['avatar_url'] != null
                                              ? DecorationImage(
                                                  image: NetworkImage(Supabase.instance.client.auth.currentUser!.userMetadata!['avatar_url']),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                        child: Supabase.instance.client.auth.currentUser?.userMetadata?['avatar_url'] == null
                                            ? const Center(
                                                child: Icon(Icons.person_rounded, color: AppTheme.warmGold, size: 30),
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$greeting,',
                                          style: GoogleFonts.inter(
                                            color: Colors.white.withValues(alpha: 0.75),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _getUserDisplayName(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.lora(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Row(
                                          children: [
                                            Container(
                                              width: 7,
                                              height: 7,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF4ADEAA),
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Color(0xFF4ADEAA),
                                                    blurRadius: 6,
                                                    spreadRadius: 1,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                'Authentic Chinese Culinary Experience',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.inter(
                                                  color: Colors.white.withValues(alpha: 0.65),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              // Hero Advertising Carousel
              _buildHeroCarousel(),
              const SizedBox(height: 18),
              // Featured Dishes (Realtime from POS orders today)
              _buildFeaturedDishesSection(),
              const SizedBox(height: 8),
              // Complete Menu Title
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 24,
                      decoration: BoxDecoration(
                        gradient: AppTheme.goldGradient,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Complete Menu',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.darkGrey,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.forestGreen.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${allMenu.values.fold(0, (acc, list) => acc + list.length)} items',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.forestGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyCategoryNavBarDelegate(
            child: Container(
              color: AppTheme.backgroundColor,
              padding: const EdgeInsets.only(top: 8),
              child: _buildCategoryNavBar(),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...MenuService.categories.map((category) {
                final items = allMenu[category] ?? [];
                if (items.isEmpty) return const SizedBox.shrink();
                return _buildMenuCategoryBlock(category, items);
              }),
              if (_isEligibleForReview) ...[
                const SizedBox(height: 16),
                _buildFeedbackSection(),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }







  Widget _buildFeedbackSection() {

    final hasReview = _customerReview != null;

    final rating = hasReview ? (_customerReview!['rating'] as num?)?.toDouble() ?? 0.0 : 0.0;



    return Container(

      padding: const EdgeInsets.all(24),

      decoration: AppTheme.cardDecoration(),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Row(

            children: [

              Container(

                padding: const EdgeInsets.all(12),

                decoration: BoxDecoration(

                  color: AppTheme.primaryColor.withValues(alpha: 0.1),

                  shape: BoxShape.circle,

                ),

                child: const Icon(Icons.stars_rounded, color: AppTheme.primaryColor, size: 28),

              ),

              const SizedBox(width: 16),

              Expanded(

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Text(

                      hasReview ? 'YOUR FEEDBACK' : 'LEAVE A REVIEW',

                      style: const TextStyle(

                        fontSize: 14,

                        fontWeight: FontWeight.w700,

                        letterSpacing: 1.5,

                        color: AppTheme.primaryColor,

                      ),

                    ),

                    const SizedBox(height: 4),

                    Text(

                      hasReview 

                        ? 'Thank you for sharing your experience!'

                        : 'How was your recent event with us?',

                      style: TextStyle(

                        fontSize: 13,

                        color: AppTheme.mediumGrey.withValues(alpha: 0.8),

                        fontWeight: FontWeight.w500,

                      ),

                    ),

                  ],

                ),

              ),

            ],

          ),

          const SizedBox(height: 24),

          if (hasReview) ...[

            Container(

              padding: const EdgeInsets.all(16),

              decoration: BoxDecoration(

                color: AppTheme.backgroundColor,

                borderRadius: BorderRadius.circular(12),

              ),

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  Row(

                    children: [

                      ...List.generate(5, (index) => Icon(

                        index < rating.floor() ? Icons.star_rounded : Icons.star_outline_rounded,

                        color: Colors.amber,

                        size: 20,

                      )),

                      const SizedBox(width: 8),

                      Text(

                        rating.toStringAsFixed(1),

                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),

                      ),

                    ],

                  ),

                  if (_customerReview!['review_text'] != null && _customerReview!['review_text'].toString().isNotEmpty) ...[

                    const SizedBox(height: 8),

                    Text(

                      '"${_customerReview!['review_text']}"',

                      style: TextStyle(

                        fontStyle: FontStyle.italic,

                        color: AppTheme.darkGrey.withValues(alpha: 0.7),

                        fontSize: 13,

                      ),

                    ),

                  ],

                ],

              ),

            ),

            const SizedBox(height: 20),

          ],

          SizedBox(

            width: double.infinity,

            child: ElevatedButton(

              onPressed: () async {

                await Navigator.push(

                  context,

                  MaterialPageRoute(builder: (context) => const CustomerReviewsPage()),

                );

                _loadReviewEligibility(); // Refresh after returning

              },

              style: ElevatedButton.styleFrom(

                backgroundColor: hasReview ? Colors.white : AppTheme.primaryColor,

                foregroundColor: hasReview ? AppTheme.primaryColor : Colors.white,

                side: hasReview ? const BorderSide(color: AppTheme.primaryColor) : null,

                elevation: hasReview ? 0 : 4,

                padding: const EdgeInsets.symmetric(vertical: 16),

                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

              ),

              child: Text(

                hasReview ? 'UPDATE YOUR REVIEW' : 'WRITE A REVIEW',

                style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),

              ),

            ),

          ),

        ],

      ),

    );

  }













  // ignore: unused_element
  Future<bool> _checkCapacity(DateTime selectedDateTime) async {

    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDateTime);

    final timeStr = _startTimeController.text.trim();

    

    try {

      final response = await Supabase.instance.client

          .from('advance_orders')

          .select('id, selected_menu_items')

          .eq('order_date', dateStr)

          .eq('order_time', timeStr)

          .filter('payment_status', 'in', '("paid", "fully_paid")');

          

      final orders = response as List;

      if (orders.length >= 10) return false; // 10 orders per hour limit

      

      int largeOrders = 0;

      for (var order in orders) {

        final items = order['selected_menu_items'] as Map<String, dynamic>? ?? {};

        int count = 0;

        items.values.forEach((qty) => count += (qty as num).toInt());

        if (count > 10) largeOrders++;

      }

      return largeOrders < 3; // 3 large orders per hour limit

    } catch (e) {

      debugPrint('Error checking capacity: $e');

      return true; // Fallback to allow if error

    }

  }



  // ignore: unused_element
  Future<String?> _validateInventoryStock() async {

    if (_selectedMenuItems.isEmpty) return null;

    try {

      final response = await Supabase.instance.client

          .from('inventory')

          .select('name, quantity');

          

      final inventory = { for (var item in response as List) item['name'].toString() : (item['quantity'] as num?)?.toInt() ?? 0 };

      

      for (var entry in _selectedMenuItems.entries) {

        final itemName = entry.key;

        final requestedQty = entry.value;

        

        if (inventory.containsKey(itemName)) {

          if (inventory[itemName]! < requestedQty) {

            return 'Sorry, we only have ${inventory[itemName]} $itemName in stock.';

          }

        }

      }

      return null;

    } catch (e) {
      debugPrint('Error validating inventory: $e');
      return null;
    }
  }

  Widget _buildReservationsSection() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section header ──────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 4,
                  height: 26,
                  decoration: BoxDecoration(
                    gradient: AppTheme.goldGradient,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _reservationType == 'Event Place' ? 'Book Event Venue' : 'Advance Food Order',
                        style: GoogleFonts.lora(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.darkGrey,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        _reservationType == 'Event Place'
                            ? 'Curate your exclusive banquet or gathering at Yang Chow'
                            : 'Pre-order dishes for dine-in or fast take-out without waiting',
                        style: GoogleFonts.inter(fontSize: 13, color: AppTheme.mediumGrey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Reservation Type Segmented Mode Switcher
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cardBorder, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedTapScale(
                      onTap: () => setState(() => _reservationType = 'Event Place'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: _reservationType == 'Event Place' ? AppTheme.goldGradient : null,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _reservationType == 'Event Place'
                              ? [
                                  BoxShadow(
                                    color: AppTheme.warmGold.withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.celebration_rounded,
                              size: 18,
                              color: _reservationType == 'Event Place' ? AppTheme.darkBrownText : AppTheme.mediumGrey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Event Place',
                              style: GoogleFonts.inter(
                                color: _reservationType == 'Event Place' ? AppTheme.darkBrownText : AppTheme.darkGrey,
                                fontWeight: _reservationType == 'Event Place' ? FontWeight.w800 : FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: AnimatedTapScale(
                      onTap: () => setState(() => _reservationType = 'Advance Order'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: _reservationType == 'Advance Order' ? AppTheme.goldGradient : null,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _reservationType == 'Advance Order'
                              ? [
                                  BoxShadow(
                                    color: AppTheme.warmGold.withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.takeout_dining_rounded,
                              size: 18,
                              color: _reservationType == 'Advance Order' ? AppTheme.darkBrownText : AppTheme.mediumGrey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Advance Order',
                              style: GoogleFonts.inter(
                                color: _reservationType == 'Advance Order' ? AppTheme.darkBrownText : AppTheme.darkGrey,
                                fontWeight: _reservationType == 'Advance Order' ? FontWeight.w800 : FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Sub-selection for Advance Order (Dine In / Pick Up)
            if (_reservationType == 'Advance Order') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSubSelectionButton('Dine In', Icons.restaurant_rounded),
                  const SizedBox(width: 14),
                  _buildSubSelectionButton('Pick Up', Icons.shopping_bag_rounded),
                ],
              ),
              const SizedBox(height: 16),
            ],
            // Form Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.cardBorder, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Form(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_reservationType == 'Event Place') ...[
                        // Event Type
                        _buildFormLabel('EVENT TYPE'),
                        const SizedBox(height: 8),
                        _buildStyledDropdown<String>(
                          value: _selectedEventType,
                          hint: 'Select event type',
                          icon: Icons.celebration_rounded,
                          items: _eventTypes,
                          onChanged: (val) {
                            setState(() {
                              _selectedEventType = val;
                              _eventController.text = val ?? '';
                            });
                          },
                        ),
                        const SizedBox(height: 20),
                      ],
                      // Date
                      _buildFormLabel(_reservationType == 'Event Place' ? 'DATE' : (_advanceOrderType == 'Dine In' ? 'DINING DATE' : 'PICKUP DATE')),
                      const SizedBox(height: 8),
                      _buildStyledTextField(
                        controller: _dateController,
                        hint: 'Select a date',
                        icon: Icons.calendar_month_rounded,
                        readOnly: true,
                        onTap: () async {
                          final minDate = _reservationType == 'Advance Order'
                              ? DateTime.now()
                              : DateTime.now().add(const Duration(days: 4));

                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: minDate,
                            firstDate: minDate,
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );

                          if (pickedDate != null) {
                            setState(() {
                              _dateController.text =
                                  DateFormat('MMMM d, yyyy').format(pickedDate);
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                      // Start Time
                      _buildFormLabel(_reservationType == 'Event Place' ? 'START TIME' : (_advanceOrderType == 'Dine In' ? 'DINING TIME' : 'PICKUP TIME')),
                      const SizedBox(height: 8),
                      _buildStyledTextField(
                        controller: _startTimeController,
                        hint: '-- : --',
                        icon: Icons.access_time_filled_rounded,
                        readOnly: true,
                        onTap: () async {
                          final startHour = _reservationType == 'Advance Order' ? 10 : _operatingHoursStart;
                          final endHour = _reservationType == 'Advance Order' ? 19 : _operatingHoursEnd;

                          final TimeOfDay? pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(hour: startHour, minute: 0),
                          );

                          if (pickedTime != null) {
                            // Validate against operating hours
                            if (pickedTime.hour < startHour ||
                                pickedTime.hour > endHour ||
                                (pickedTime.hour == endHour && pickedTime.minute > 0)) {
                              _showSnackBar(
                                'Please select a time between ${startHour.toString().padLeft(2, '0')}:00 and ${endHour.toString().padLeft(2, '0')}:00',
                                Colors.red,
                              );
                              return;
                            }

                            // Validate 40-minutes-ahead rule for same-day Advance Orders (Dine In & Pick Up)
                            if (_reservationType == 'Advance Order') {
                              final selectedDateStr = _dateController.text.trim();
                              if (selectedDateStr.isNotEmpty) {
                                try {
                                  final now = DateTime.now();
                                  final selectedDate = DateFormat('MMMM d, yyyy').parse(selectedDateStr);
                                  final isToday = selectedDate.year == now.year &&
                                      selectedDate.month == now.month &&
                                      selectedDate.day == now.day;

                                  if (isToday) {
                                    final selectedDateTime = DateTime(
                                      now.year,
                                      now.month,
                                      now.day,
                                      pickedTime.hour,
                                      pickedTime.minute,
                                    );
                                    final timeDifference = selectedDateTime.difference(now);

                                    if (timeDifference.inMinutes < 40) {
                                      final earliestTime = now.add(const Duration(minutes: 40));
                                      final earliestFormatted = '${earliestTime.hour.toString().padLeft(2, '0')}:${earliestTime.minute.toString().padLeft(2, '0')}';
                                      _showSnackBar(
                                        'For same-day orders, please select a time at least 40 minutes from now (earliest: $earliestFormatted)',
                                        Colors.red,
                                      );
                                      return;
                                    }
                                  }
                                } catch (e) {
                                  debugPrint('Error validating lead time: $e');
                                }
                              }
                            }

                            setState(() {
                              _startTimeController.text = pickedTime.format(context);
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                      if (_reservationType == 'Event Place') ...[
                        // Duration
                        _buildFormLabel('DURATION'),
                        const SizedBox(height: 8),
                        _buildStyledDropdown<String>(
                          value: _selectedBaseDuration,
                          hint: 'Select duration',
                          icon: Icons.timer_rounded,
                          items: _baseDurations,
                          onChanged: (val) {
                            setState(() {
                              _selectedBaseDuration = val;
                              _updateDurationText();
                            });
                          },
                        ),
                        const SizedBox(height: 20),
                      ],
                      // Number of Guests
                      if (_reservationType == 'Event Place' || (_reservationType == 'Advance Order' && _advanceOrderType == 'Dine In')) ...[
                        _buildFormLabel('GUESTS'),
                        const SizedBox(height: 8),
                        _buildStyledTextField(
                          controller: _guestsController,
                          hint: 'Enter number of guests',
                          icon: Icons.people_alt_rounded,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          helperText: _reservationType == 'Event Place'
                              ? '$_minGuestCount–100 guests allowed'
                              : '1–20 guests allowed',
                        ),
                        const SizedBox(height: 20),
                      ],
                      // Menu Selection (Digital Dining Check Style)
                      _buildFormLabel('MENU SELECTION'),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.cardBorder,
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.receipt_long_rounded, size: 18, color: AppTheme.forestGreen),
                                    const SizedBox(width: 8),
                                    Text(
                                      _selectedMenuItems.isEmpty
                                          ? 'No dishes selected yet'
                                          : '${_selectedMenuItems.values.fold(0, (sum, qty) => sum + qty)} items in pre-order',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: _selectedMenuItems.isEmpty
                                            ? AppTheme.mediumGrey
                                            : AppTheme.darkGrey,
                                        fontWeight: _selectedMenuItems.isEmpty
                                            ? FontWeight.normal
                                            : FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_selectedMenuItems.isNotEmpty)
                                  TextButton(
                                    onPressed: () => setState(() {
                                      _selectedMenuItems.clear();
                                      _preOrderCart.clear();
                                    }),
                                    child: Text(
                                      'Clear All',
                                      style: GoogleFonts.inter(
                                        color: AppTheme.errorRed,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (_selectedMenuItems.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.cardBorder),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ..._selectedMenuItems.entries.map(
                                      (entry) => Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.warmGold.withValues(alpha: 0.2),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      '${entry.value}x',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold,
                                                        color: AppTheme.darkBrownText,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      entry.key,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                        color: AppTheme.darkGrey,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              '₱${NumberFormat('#,##0.00').format(_menuReservationService.calculateMenuTotalPrice({entry.key: entry.value}))}',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: AppTheme.forestGreen,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const Divider(height: 18),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Menu Subtotal:',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.darkGrey,
                                          ),
                                        ),
                                        Text(
                                          '₱${NumberFormat('#,##0.00').format(_menuReservationService.calculateMenuTotalPrice(_selectedMenuItems))}',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.forestGreen,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _reservationType == 'Advance Order'
                                              ? 'Full Payment Required:'
                                              : (_paymentOption == 'full' ? 'Full Payment Required:' : '50% Deposit Required:'),
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: AppTheme.mediumGrey,
                                          ),
                                        ),
                                        Text(
                                          '₱${NumberFormat("#,##0.00").format(_paymentOption == 'full' && _reservationType == 'Event Place' ? _menuReservationService.calculateMenuTotalPrice(_selectedMenuItems) : _menuReservationService.calculateMenuDepositAmount(_menuReservationService.calculateMenuTotalPrice(_selectedMenuItems), reservationType: _reservationType))}',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.darkBrownText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: AnimatedTapScale(
                                onTap: _navigateToMenuSelection,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.goldGradient,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.warmGold.withValues(alpha: 0.35),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.restaurant_menu_rounded, color: AppTheme.darkBrownText, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        _selectedMenuItems.isEmpty
                                            ? 'Select Dishes from Menu'
                                            : 'Modify Dish Selection',
                                        style: GoogleFonts.inter(
                                          color: AppTheme.darkBrownText,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Extra Time Toggle

                              if (_reservationType == 'Event Place') 

                                Container(

                                  padding: const EdgeInsets.all(16),



                                  decoration: BoxDecoration(

                                    color: Colors.grey.shade50,



                                    borderRadius: BorderRadius.circular(16),



                                    border: Border.all(

                                      color: Colors.grey.shade100,

                                    ),

                                  ),



                                child: Column(

                                  children: [

                                    Row(

                                      children: [

                                        Container(

                                          padding: const EdgeInsets.all(8),



                                          decoration: BoxDecoration(

                                            color: Colors.white,



                                            shape: BoxShape.circle,



                                            boxShadow: [

                                              BoxShadow(

                                                color: Colors.black.withValues(

                                                  alpha: 0.05,

                                                ),



                                                blurRadius: 4,

                                              ),

                                            ],

                                          ),



                                          child: const Icon(

                                            Icons.history_toggle_off_rounded,



                                            color: AppTheme.primaryColor,



                                            size: 20,

                                          ),

                                        ),



                                        const SizedBox(width: 12),



                                        const Expanded(

                                          child: Column(

                                            crossAxisAlignment:

                                                CrossAxisAlignment.start,



                                            children: [

                                              Text(

                                                'Extra Time',



                                                style: TextStyle(

                                                  fontWeight: FontWeight.bold,



                                                  fontSize: 14,



                                                  color: AppTheme.darkGrey,

                                                ),

                                              ),



                                              Text(

                                                'Allow flexibility for the event end',



                                                style: TextStyle(

                                                  fontSize: 11,



                                                  color: AppTheme.mediumGrey,

                                                ),

                                              ),

                                            ],

                                          ),

                                        ),



                                        Switch(

                                          value: _addExtraTime,



                                          activeThumbColor:

                                              AppTheme.primaryColor,



                                          onChanged: (val) {

                                            setState(() {

                                              _addExtraTime = val;



                                              if (!_addExtraTime) {

                                                _selectedExtraTime = null;

                                              }



                                              _updateDurationText();

                                            });

                                          },

                                        ),

                                      ],

                                    ),



                                    if (_addExtraTime) ...[

                                      const SizedBox(height: 16),



                                      _buildStyledDropdown<String>(

                                        value: _selectedExtraTime,



                                        hint: 'Select extra time',



                                        icon: Icons.add_alarm_rounded,



                                        items: _extraTimeOptions,



                                        onChanged: (val) {

                                          setState(() {

                                            _selectedExtraTime = val;



                                            _updateDurationText();

                                          });

                                        },

                                      ),

                                    ],

                                  ],

                                ),

                              ),



                              const SizedBox(height: 24), // Reduced from 32



                              // Payment Option Selection

                              if (_reservationType == 'Event Place')

                                Container(

                                  decoration: BoxDecoration(

                                    color: Colors.grey.shade50,

                                    borderRadius: BorderRadius.circular(16),

                                    border: Border.all(

                                      color: Colors.grey.shade100,

                                    ),

                                  ),

                                  child: ClipRRect(

                                    borderRadius: BorderRadius.circular(16),

                                    child: Material(

                                      color: Colors.grey.shade50,

                                      child: Padding(

                                        padding: const EdgeInsets.all(16),

                                        child: Column(

                                          crossAxisAlignment: CrossAxisAlignment.start,

                                          children: [

                                            Row(

                                              children: [

                                                Container(

                                                  padding: const EdgeInsets.all(8),

                                                  decoration: BoxDecoration(

                                                    color: Colors.white,

                                                    shape: BoxShape.circle,

                                                    boxShadow: [

                                                      BoxShadow(

                                                        color: Colors.black.withValues(

                                                          alpha: 0.05,

                                                        ),

                                                        blurRadius: 4,

                                                      ),

                                                    ],

                                                  ),

                                                  child: const Icon(

                                                    Icons.payment_rounded,

                                                    color: AppTheme.primaryColor,

                                                    size: 20,

                                                  ),

                                                ),

                                                const SizedBox(width: 12),

                                                const Expanded(

                                                  child: Column(

                                                    crossAxisAlignment: CrossAxisAlignment.start,

                                                    children: [

                                                      Text(

                                                        'Payment Option',

                                                        style: TextStyle(

                                                          fontWeight: FontWeight.bold,

                                                          fontSize: 14,

                                                          color: AppTheme.darkGrey,

                                                        ),

                                                      ),

                                                      Text(

                                                        'Choose how you want to pay for your reservation',

                                                        style: TextStyle(

                                                          fontSize: 11,

                                                          color: AppTheme.mediumGrey,

                                                        ),

                                                      ),

                                                    ],

                                                  ),

                                                ),

                                              ],

                                            ),

                                            const SizedBox(height: 16),

                                            // Radio buttons for payment options

                                            Column(

                                              children: [

                                                RadioListTile<String>(

                                                  title: const Text(

                                                    'Pay Half (Deposit)',

                                                    style: TextStyle(

                                                      fontSize: 14,

                                                      fontWeight: FontWeight.w600,

                                                    ),

                                                  ),

                                                  subtitle: const Text(

                                                    'Pay 50% now as deposit, remaining balance due on event day',

                                                    style: TextStyle(fontSize: 12),

                                                  ),

                                                  // ignore: deprecated_member_use
                                                  value: 'half',
                                                  // ignore: deprecated_member_use
                                                  groupValue: _paymentOption,
                                                  // ignore: deprecated_member_use
                                                  onChanged: (value) {

                                                    setState(() {

                                                      _paymentOption = value!;

                                                    });

                                                  },

                                                  activeColor: AppTheme.primaryColor,

                                                  contentPadding: EdgeInsets.zero,

                                                  visualDensity: VisualDensity.compact,

                                                ),

                                                RadioListTile<String>(

                                                  title: const Text(

                                                    'Pay in Full',

                                                    style: TextStyle(

                                                      fontSize: 14,

                                                      fontWeight: FontWeight.w600,

                                                    ),

                                                  ),

                                                  subtitle: const Text(

                                                    'Pay the total amount upfront',

                                                    style: TextStyle(fontSize: 12),

                                                  ),

                                                  // ignore: deprecated_member_use
                                                  value: 'full',
                                                  // ignore: deprecated_member_use
                                                  groupValue: _paymentOption,
                                                  // ignore: deprecated_member_use
                                                  onChanged: (value) {

                                                    setState(() {

                                                      _paymentOption = value!;

                                                    });

                                                  },

                                                  activeColor: AppTheme.primaryColor,

                                                  contentPadding: EdgeInsets.zero,

                                                  visualDensity: VisualDensity.compact,

                                                ),

                                              ],

                                            ),

                                          ],

                                        ),

                                      ),

                                    ),

                                  ),

                                ),



                              const SizedBox(height: 24),



                              // Special Requests Field (if enabled)

                              if (_enableSpecialRequests) ...[

                                _buildFormLabel(_reservationType == 'Event Place' ? 'SPECIAL REQUESTS' : 'PREPARATION NOTES'),



                                const SizedBox(height: 8),



                                Container(

                                  padding: const EdgeInsets.all(16),



                                  decoration: BoxDecoration(

                                    color: Colors.grey.shade50,



                                    borderRadius: BorderRadius.circular(16),



                                    border: Border.all(

                                      color: Colors.grey.shade100,

                                    ),

                                  ),



                                  child: Column(

                                    crossAxisAlignment:

                                        CrossAxisAlignment.start,



                                    children: [

                                      TextFormField(

                                        controller: _specialRequestsController,



                                        maxLines: 3,



                                        decoration: InputDecoration(

                                          hintText:

                                              _reservationType == 'Event Place'

                                               ? 'Enter any special requests (dietary restrictions, accessibility needs, celebration requirements, etc.)'

                                               : 'Enter any preparation notes (no spice, utensils needed, allergy warnings, etc.)'

,



                                          hintStyle: TextStyle(

                                            color: Colors.grey.shade400,



                                            fontSize: 13,

                                          ),



                                          filled: true,



                                          fillColor: Colors.white,



                                          contentPadding: const EdgeInsets.all(

                                            12,

                                          ),



                                          border: OutlineInputBorder(

                                            borderRadius: BorderRadius.circular(

                                              8,

                                            ),



                                            borderSide: BorderSide(

                                              color: Colors.grey.shade300,

                                            ),

                                          ),



                                          enabledBorder: OutlineInputBorder(

                                            borderRadius: BorderRadius.circular(

                                              8,

                                            ),



                                            borderSide: BorderSide(

                                              color: Colors.grey.shade300,

                                            ),

                                          ),



                                          focusedBorder: OutlineInputBorder(

                                            borderRadius: BorderRadius.circular(

                                              8,

                                            ),



                                            borderSide: const BorderSide(

                                              color: AppTheme.primaryColor,



                                              width: 1.5,

                                            ),

                                          ),

                                        ),

                                      ),



                                      const SizedBox(height: 8),



                                      Text(

                                        _reservationType == 'Event Place'

                                            ? 'Examples: Vegetarian guests | Wheelchair access needed | Birthday surprise setup | High chair for baby'

                                            : 'Examples: No spicy food | Separate sauces | Extra napkins | Allergy to peanuts',

                                        style: TextStyle(

                                          fontSize: 11,

                                          color: Colors.grey.shade500,

                                        ),

                                      ),

                                    ],

                                  ),

                                ),



                                if (_reservationType == 'Event Place') ...[

                                  const SizedBox(height: 24),

                                  _buildFormLabel('VALID ID FOR IN-PERSON VERIFICATION'),

                                  const SizedBox(height: 8),

                                  Container(

                                    padding: const EdgeInsets.all(16),

                                    decoration: BoxDecoration(

                                      color: Colors.grey.shade50,

                                      borderRadius: BorderRadius.circular(16),

                                      border: Border.all(

                                        color: Colors.grey.shade100,

                                      ),

                                    ),

                                    child: Column(

                                      crossAxisAlignment: CrossAxisAlignment.start,

                                      children: [

                                        Text(

                                          'Please upload a valid government-issued ID or school ID. This will be used by staff to verify your reservation when you arrive in person.',

                                          style: TextStyle(

                                            fontSize: 12,

                                            color: Colors.grey.shade600,

                                          ),

                                        ),

                                        const SizedBox(height: 16),

                                        if (_isUploadingId)

                                          const Center(

                                            child: Padding(

                                              padding: EdgeInsets.symmetric(vertical: 12.0),

                                              child: Column(

                                                children: [

                                                  CircularProgressIndicator(color: AppTheme.primaryColor),

                                                  SizedBox(height: 8),

                                                  Text('Uploading ID, please wait...', style: TextStyle(fontSize: 12)),

                                                ],

                                              ),

                                            ),

                                          )

                                        else if (_uploadedIdUrl != null)

                                          Row(

                                            children: [

                                              ClipRRect(

                                                borderRadius: BorderRadius.circular(8),

                                                child: Container(

                                                  width: 80,

                                                  height: 80,

                                                  color: Colors.grey.shade200,

                                                  child: Image.network(

                                                    _uploadedIdUrl!,

                                                    fit: BoxFit.cover,

                                                    errorBuilder: (context, error, stackTrace) =>

                                                        const Icon(Icons.broken_image, color: Colors.grey),

                                                  ),

                                                ),

                                              ),

                                              const SizedBox(width: 16),

                                              Expanded(

                                                child: Column(

                                                  crossAxisAlignment: CrossAxisAlignment.start,

                                                  children: [

                                                    const Text(

                                                      'ID Uploaded Successfully',

                                                      style: TextStyle(

                                                        fontWeight: FontWeight.bold,

                                                        color: Colors.green,

                                                        fontSize: 14,

                                                      ),

                                                    ),

                                                    const SizedBox(height: 4),

                                                    TextButton.icon(

                                                      onPressed: _pickAndUploadIdImage,

                                                      icon: const Icon(Icons.cached, size: 16),

                                                      label: const Text('Change ID'),

                                                      style: TextButton.styleFrom(

                                                        foregroundColor: AppTheme.primaryColor,

                                                        padding: EdgeInsets.zero,

                                                      ),

                                                    ),

                                                  ],

                                                ),

                                              ),

                                            ],

                                          )

                                        else

                                          InkWell(

                                            onTap: _pickAndUploadIdImage,

                                            borderRadius: BorderRadius.circular(12),

                                            child: Container(

                                              width: double.infinity,

                                              padding: const EdgeInsets.symmetric(vertical: 24),

                                              decoration: BoxDecoration(

                                                border: Border.all(

                                                  color: Colors.grey.shade300,

                                                  style: BorderStyle.solid,

                                                ),

                                                borderRadius: BorderRadius.circular(12),

                                                color: Colors.white,

                                              ),

                                              child: Column(

                                                children: [

                                                  Icon(

                                                    Icons.add_photo_alternate_outlined,

                                                    size: 36,

                                                    color: Colors.grey.shade400,

                                                  ),

                                                  const SizedBox(height: 8),

                                                  Text(

                                                    'Click to upload Valid ID',

                                                    style: TextStyle(

                                                      fontSize: 14,

                                                      fontWeight: FontWeight.w500,

                                                      color: Colors.grey.shade600,

                                                    ),

                                                  ),

                                                  const SizedBox(height: 4),

                                                  Text(

                                                    'Formats: JPG, PNG',

                                                    style: TextStyle(

                                                      fontSize: 11,

                                                      color: Colors.grey.shade400,

                                                    ),

                                                  ),

                                                ],

                                              ),

                                            ),

                                          ),

                                      ],

                                    ),

                                  ),

                                ],



                                const SizedBox(height: 24), // Reduced from 32

                              ],



                              // Submit Button

                              SizedBox(

                                width: double.infinity,



                                height: 56,



                                child: ElevatedButton(

                                  onPressed: _isLoading

                                      ? null

                                      : _showConfirmationDialog,



                                  style: ElevatedButton.styleFrom(

                                    backgroundColor: AppTheme.primaryColor,



                                    foregroundColor: Colors.white,



                                    elevation: 2,



                                    shadowColor: AppTheme.primaryColor

                                        .withValues(alpha: 0.3),



                                    shape: RoundedRectangleBorder(

                                      borderRadius: BorderRadius.circular(14),

                                    ),

                                  ),



                                  child: _isLoading

                                      ? const SizedBox(

                                          height: 24,



                                          width: 24,



                                          child: CircularProgressIndicator(

                                            strokeWidth: 2,



                                            valueColor:

                                                AlwaysStoppedAnimation<Color>(

                                                  Colors.white,

                                                ),

                                          ),

                                        )

                                      : Row(

                                          mainAxisAlignment:

                                              MainAxisAlignment.center,



                                          children: [

                                            Text(

                                              _reservationType == 'Event Place' ? 'Confirm Reservation' : 'Confirm Advance Order',



                                              style: const TextStyle(

                                                fontSize: 16,



                                                fontWeight: FontWeight.bold,



                                                letterSpacing: 0.5,

                                              ),

                                            ),



                                            const SizedBox(width: 8),



                                            const Icon(

                                              Icons.arrow_forward_rounded,



                                              size: 20,

                                            ),

                                          ],

                                        ),

                                ),

                              ),

                            ],

                          ),

                        ),

                      ),

            ),



            const SizedBox(height: 24), // Reduced from 32

          ],

        ),

      ),

    );

  }



  // ── Reservation Form Helpers ──────────────────────────────────────





  Widget _buildFormLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AppTheme.mediumGrey,
        letterSpacing: 1.2,
      ),
    );
  }



  Widget _buildStyledTextField({

    required TextEditingController controller,

    required String hint,

    required IconData icon,

    bool readOnly = false,

    VoidCallback? onTap,

    TextInputType? keyboardType,

    List<TextInputFormatter>? inputFormatters,

    String? helperText,

  }) {

    return TextFormField(

      controller: controller,

      readOnly: readOnly,

      onTap: onTap,

      keyboardType: keyboardType,

      inputFormatters: inputFormatters,

      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),

      decoration: InputDecoration(

        hintText: hint,

        helperText: helperText,

        helperStyle: const TextStyle(fontSize: 11, color: AppTheme.mediumGrey),

        prefixIcon: Icon(icon, color: AppTheme.primaryColor.withValues(alpha: 0.7), size: 22),

      ),

    );

  }



  Widget _buildStyledDropdown<T>({

    required T? value,

    required String hint,

    required IconData icon,

    required List<String> items,

    required void Function(String?) onChanged,

  }) {

    return DropdownButtonFormField<String>(

      initialValue: value as String?,

      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.darkGrey),

      decoration: InputDecoration(

        hintText: hint,

        prefixIcon: Icon(icon, color: AppTheme.primaryColor.withValues(alpha: 0.7), size: 22),

        suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.mediumGrey),

      ),

      icon: const SizedBox.shrink(),

      items: items

          .map((item) => DropdownMenuItem(

                value: item,

                child: Text(item),

              ))

          .toList(),

      onChanged: onChanged,

    );

  }



  Widget _buildProfileSection() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final name = _getUserDisplayName();
    final email = currentUser?.email ?? 'Not provided';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'C';

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: ResponsiveUtils.getResponsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Realistic VIP Patron Card Header
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF14332E), Color(0xFF1B3D37)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF14332E).withValues(alpha: 0.28),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Hero(
                        tag: 'profile_avatar_large',
                        child: Container(
                          width: 74,
                          height: 74,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.warmGold, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.warmGold.withValues(alpha: 0.35),
                                blurRadius: 10,
                              ),
                            ],
                            image: currentUser?.userMetadata?['avatar_url'] != null
                                ? DecorationImage(
                                    image: NetworkImage(currentUser!.userMetadata!['avatar_url']),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: currentUser?.userMetadata?['avatar_url'] == null
                              ? Center(
                                  child: Text(
                                    initial,
                                    style: GoogleFonts.lora(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.warmGold,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                gradient: AppTheme.goldGradient,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.stars_rounded, size: 13, color: AppTheme.darkBrownText),
                                  const SizedBox(width: 4),
                                  Text(
                                    'VIP PATRON',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.darkBrownText,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              name,
                              style: GoogleFonts.lora(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              email,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.75),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (currentUser?.userMetadata?['avatar_url'] == null) ...[
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: InkWell(
                        onTap: () async {
                          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfilePage()));
                          if (mounted) setState(() {});
                        },
                        child: Text(
                          'Update profile details or avatar →',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.warmGold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            // Member Stats Row
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.cardBorder, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildProfileStat('${customerReservations.length}', 'Total Bookings', Icons.event_seat_rounded),
                  _buildProfileDivider(),
                  _buildProfileStat(
                    DateFormat('MMM yyyy').format(DateTime.parse(currentUser?.createdAt ?? DateTime.now().toUtc().toIso8601String())),
                    'Member Since',
                    Icons.verified_user_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'ACCOUNT & PREFERENCES',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppTheme.mediumGrey,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            // Menu Cards
            _buildAccountMenuCard(
              icon: Icons.person_outline_rounded,
              title: 'Edit Profile',
              subtitle: 'Update your contact information and display name',
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfilePage()));
                if (mounted) setState(() {});
              },
            ),
            if (currentUser?.appMetadata['provider'] == 'email')
              _buildAccountMenuCard(
                icon: Icons.lock_outline_rounded,
                title: 'Change Password',
                subtitle: 'Update your account security and authentication',
                onTap: _showChangePasswordDialog,
              ),
            _buildAccountMenuCard(
              icon: Icons.history_rounded,
              title: 'Transaction History',
              subtitle: 'View receipts, payments, and past event orders',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => TransactionsPage(initialTransactions: customerReservations),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildAccountMenuCard(
              icon: Icons.logout_rounded,
              title: 'Log Out',
              subtitle: 'Securely sign out of your Yang Chow account',
              isDestructive: true,
              onTap: _showLogoutDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileStat(String value, String label, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.forestGreen.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: AppTheme.forestGreen),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.darkGrey,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppTheme.mediumGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfileDivider() {
    return Container(
      height: 36,
      width: 1,
      color: AppTheme.cardBorder,
    );
  }



  void _showChangePasswordDialog() {

    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    final TextEditingController newPasswordController = TextEditingController();

    final TextEditingController confirmPasswordController = TextEditingController();

    bool isPasswordVisible = false;

    bool isConfirmVisible = false;

    bool isUpdating = false;



    showDialog(

      context: context,

      barrierDismissible: !isUpdating,

      builder: (context) => StatefulBuilder(

        builder: (context, setDialogState) {

          return AlertDialog(

            titlePadding: EdgeInsets.zero,

            contentPadding: EdgeInsets.zero,

            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

            title: Container(

              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),

              decoration: BoxDecoration(

                color: AppTheme.primaryColor,

                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),

              ),

              child: Row(

                children: [

                  const Icon(Icons.lock_rounded, color: Colors.white, size: 24),

                  const SizedBox(width: 12),

                  const Text(

                    'Change Password',

                    style: TextStyle(

                      color: Colors.white,

                      fontSize: 18,

                      fontWeight: FontWeight.bold,

                    ),

                  ),

                ],

              ),

            ),

            content: SingleChildScrollView(

              child: Padding(

                padding: const EdgeInsets.all(24),

                child: Form(

                  key: formKey,

                  child: Column(

                    mainAxisSize: MainAxisSize.min,

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      const Text(

                        'New Password',

                        style: TextStyle(

                          fontWeight: FontWeight.bold,

                          fontSize: 14,

                          color: AppTheme.darkGrey,

                        ),

                      ),

                      const SizedBox(height: 8),

                      TextFormField(

                        controller: newPasswordController,

                        obscureText: !isPasswordVisible,

                        enabled: !isUpdating,

                        decoration: InputDecoration(

                          hintText: 'Enter new password',

                          prefixIcon: const Icon(Icons.lock_outline_rounded),

                          suffixIcon: IconButton(

                            icon: Icon(

                              isPasswordVisible ? Icons.visibility_off : Icons.visibility,

                              size: 20,

                            ),

                            onPressed: () => setDialogState(() => isPasswordVisible = !isPasswordVisible),

                          ),

                        ),

                        validator: (value) {

                          if (value == null || value.isEmpty) return 'Please enter a password';

                          if (value.length < 8) return 'Minimum 8 characters required';

                          if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Must contain an uppercase letter';

                          if (!RegExp(r'[a-z]').hasMatch(value)) return 'Must contain a lowercase letter';

                          if (!RegExp(r'[0-9]').hasMatch(value)) return 'Must contain a number';

                          if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(value)) return 'Must contain a special character';

                          return null;

                        },

                      ),

                      const SizedBox(height: 20),

                      const Text(

                        'Confirm New Password',

                        style: TextStyle(

                          fontWeight: FontWeight.bold,

                          fontSize: 14,

                          color: AppTheme.darkGrey,

                        ),

                      ),

                      const SizedBox(height: 8),

                      TextFormField(

                        controller: confirmPasswordController,

                        obscureText: !isConfirmVisible,

                        enabled: !isUpdating,

                        decoration: InputDecoration(

                          hintText: 'Re-enter new password',

                          prefixIcon: const Icon(Icons.verified_user_outlined),

                          suffixIcon: IconButton(

                            icon: Icon(

                              isConfirmVisible ? Icons.visibility_off : Icons.visibility,

                              size: 20,

                            ),

                            onPressed: () => setDialogState(() => isConfirmVisible = !isConfirmVisible),

                          ),

                        ),

                        validator: (value) {

                          if (value != newPasswordController.text) return 'Passwords do not match';

                          return null;

                        },

                      ),

                      if (isUpdating) ...[

                        const SizedBox(height: 24),

                        const Center(

                          child: CircularProgressIndicator(color: AppTheme.primaryColor),

                        ),

                      ],

                    ],

                  ),

                ),

              ),

            ),

            actions: [

              TextButton(

                onPressed: isUpdating ? null : () => Navigator.pop(context),

                child: Text(

                  'Cancel',

                  style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold),

                ),

              ),

              ElevatedButton(

                onPressed: isUpdating ? null : () async {

                  if (formKey.currentState!.validate()) {

                    setDialogState(() => isUpdating = true);

                    try {

                      await Supabase.instance.client.auth.updateUser(

                        UserAttributes(password: newPasswordController.text.trim()),

                      );

                      

                      if (context.mounted) {

                        Navigator.pop(context); // Close dialog

                        ScaffoldMessenger.of(context).showSnackBar(

                          const SnackBar(

                            content: Text('Password updated successfully!'),

                            backgroundColor: AppTheme.successGreen,

                            behavior: SnackBarBehavior.floating,

                          ),

                        );

                      }

                    } catch (e) {

                      setDialogState(() => isUpdating = false);

                      if (context.mounted) {

                        ScaffoldMessenger.of(context).showSnackBar(

                          SnackBar(

                            content: Text('Error updating password: $e'),

                            backgroundColor: AppTheme.errorRed,

                            behavior: SnackBarBehavior.floating,

                          ),

                        );

                      }

                    }

                  }

                },

                style: ElevatedButton.styleFrom(

                  backgroundColor: AppTheme.primaryColor,

                  foregroundColor: Colors.white,

                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),

                ),

                child: const Text('Update Password'),

              ),

            ],

          );

        },

      ),

    );

  }





  Future<void> _fetchInventory() async {

    if (_isFetchingInventory) return;

    if (mounted) setState(() => _isFetchingInventory = true);

    try {

      final supabase = Supabase.instance.client;

      // Fetch inventory

      final data = await supabase.from('kitchen_inventory').select('name, quantity');

      final Map<String, num> newCache = {};

      for (var item in data) {

        final name = item['name']?.toString().toLowerCase() ?? '';

        newCache[name] = (item['quantity'] as num?) ?? 0;

      }

      if (mounted) {

        setState(() {

          _inventoryCache.clear();

          _inventoryCache.addAll(newCache);

        });

      }




      // Fetch recipe ingredients

      final recipeData = await supabase.from('recipe_ingredients').select();

      final Map<String, List<Map<String, dynamic>>> newRecipeCache = {};

      for (var row in recipeData) {

        final menuItemName = row['menu_item_name'] as String;

        if (!newRecipeCache.containsKey(menuItemName)) {

          newRecipeCache[menuItemName] = [];

        }

        newRecipeCache[menuItemName]!.add(row);

      }

      if (mounted) {

        setState(() {

          _recipeCache.clear();

          _recipeCache.addAll(newRecipeCache);

        });

      }


    } catch (e) {

      debugPrint('Error fetching inventory or recipes for Menu Selection: $e');

    } finally {

      if (mounted) setState(() => _isFetchingInventory = false);

    }

  }







  GlobalKey _getCategoryKey(String category) {

    if (!_categoryKeys.containsKey(category)) {

      _categoryKeys[category] = GlobalKey();

    }

    return _categoryKeys[category]!;

  }







  Widget _buildCategoryNavBar() {

    return Container(
      height: 52,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: MenuService.categories.length,
        itemBuilder: (context, index) {
          final category = MenuService.categories[index];
          final isActive = _selectedCategory == category;
          final catIcon = CategoryIconHelper.getIcon(category);

          return GestureDetector(
            key: _getChipKey(category),
            onTap: () async {
              setState(() => _selectedCategory = category);
              final key = _getCategoryKey(category);
              if (key.currentContext != null) {
                _isScrollingToCategory = true;
                await Scrollable.ensureVisible(
                  key.currentContext!,
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOutCubic,
                );
                _isScrollingToCategory = false;
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: isActive ? AppTheme.goldGradient : null,
                color: isActive ? null : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isActive ? Colors.transparent : AppTheme.cardBorder,
                  width: 1.2,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppTheme.warmGold.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    catIcon,
                    size: 16,
                    color: isActive ? AppTheme.darkBrownText : AppTheme.forestGreen,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    category,
                    style: GoogleFonts.inter(
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 13,
                      color: isActive ? AppTheme.darkBrownText : AppTheme.darkGrey,
                      letterSpacing: isActive ? 0.1 : 0,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuCategoryBlock(String category, List<MenuItem> items) {
    final catIcon = CategoryIconHelper.getIcon(category);

    return Column(
      key: _getCategoryKey(category),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.forestGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(catIcon, size: 18, color: AppTheme.forestGreen),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkGrey,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${items.length})',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.mediumGrey,
                ),
              ),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: ResponsiveUtils.isDesktop(context) ? 5 : (ResponsiveUtils.isTablet(context) ? 4 : 2),
            childAspectRatio: ResponsiveUtils.isDesktop(context) ? 0.75 : (ResponsiveUtils.isTablet(context) ? 0.7 : 0.72),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _buildProductCard(item);
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  FEATURED DISHES — Realtime from POS orders today
  // ══════════════════════════════════════════════════════════════════════

  void _listenToFeaturedDishes() {
    _featuredOrdersSubscription = Supabase.instance.client
        .from('orders')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .listen((rows) async {
          if (!mounted) return;

          final now = DateTime.now();
          final startOfToday = DateTime(now.year, now.month, now.day);

          // Filter: today only, exclude cancelled/refunded
          final todayOrders = rows.where((o) {
            final createdAtStr = o['created_at']?.toString() ?? '';
            if (createdAtStr.isEmpty) return false;
            final dt = DateTime.tryParse(createdAtStr)?.toLocal();
            if (dt == null) return false;
            final isToday = dt.isAfter(startOfToday.subtract(const Duration(seconds: 1)));

            final status = o['status']?.toString().toLowerCase() ?? '';
            final refundStatus = o['refund_status']?.toString() ?? 'none';
            final isCancelled = status == 'cancelled' ||
                status == 'refunded' ||
                refundStatus == 'full_refund';
            return isToday && !isCancelled;
          }).toList();

          if (todayOrders.isEmpty) {
            _populateFallbackFeaturedDishes();
            return;
          }

          try {
            final orderIds =
                todayOrders.map((o) => o['id'].toString()).toList();
            final items = await Supabase.instance.client
                .from('order_items')
                .select('item_name, quantity, order_id')
                .inFilter('order_id', orderIds);

            // Map order_id → created_at for recency sorting
            final orderTimeMap = <String, String>{};
            for (final o in todayOrders) {
              orderTimeMap[o['id'].toString()] =
                  o['created_at']?.toString() ?? '';
            }

            // Group by item_name
            final Map<String, Map<String, dynamic>> grouped = {};
            for (final item in items) {
              final name = item['item_name']?.toString() ?? '';
              if (name.isEmpty) continue;
              final qty = (item['quantity'] as num?)?.toInt() ?? 1;
              final orderId = item['order_id']?.toString() ?? '';
              final orderTime = orderTimeMap[orderId] ?? '';

              if (!grouped.containsKey(name)) {
                grouped[name] = {
                  'name': name,
                  'count': 0,
                  'lastOrderAt': orderTime,
                  'isFallback': false,
                };
              }
              grouped[name]!['count'] =
                  (grouped[name]!['count'] as int) + qty;
              if (orderTime.compareTo(
                      grouped[name]!['lastOrderAt'] as String) >
                  0) {
                grouped[name]!['lastOrderAt'] = orderTime;
              }
            }

            if (grouped.isEmpty) {
              _populateFallbackFeaturedDishes();
              return;
            }

            // Match with MenuService for image/metadata
            final allMenu = MenuService.getMenu();
            final allItems = <MenuItem>[];
            for (var list in allMenu.values) {
              allItems.addAll(list);
            }

            for (final entry in grouped.values) {
              final match = allItems
                  .where((m) =>
                      m.name.trim().toLowerCase() ==
                      (entry['name'] as String).trim().toLowerCase())
                  .toList();
              if (match.isNotEmpty) {
                entry['menuItem'] = match.first;
              }
            }

            // Sort by most recent, take top 10
            final sorted = grouped.values.toList()
              ..sort((a, b) => (b['lastOrderAt'] as String)
                  .compareTo(a['lastOrderAt'] as String));

            final top10 = sorted.take(10).toList();

            if (mounted) {
              setState(() {
                _featuredDishes = top10;
                _featuredLoading = false;
              });
            }
          } catch (e) {
            debugPrint('Error fetching featured dishes: $e');
            _populateFallbackFeaturedDishes();
          }
        });
  }

  void _populateFallbackFeaturedDishes() {
    final allMenu = MenuService.getMenu();
    final items = _getTopSellingItems(allMenu);
    final fallbackList = items.take(10).map((item) => {
          'name': item.name,
          'count': 0,
          'isFallback': true,
          'menuItem': item,
          'lastOrderAt': '',
        }).toList();

    if (mounted) {
      setState(() {
        _featuredDishes = fallbackList;
        _featuredLoading = false;
      });
    }
  }

  Widget _buildFeaturedDishesSection() {
    // Hide entire section when empty and not loading
    if (!_featuredLoading && _featuredDishes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.warmGold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Featured Dishes',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.darkGrey,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Horizontal scrollable cards (Mouse drag + Touch enabled)
        SizedBox(
          height: 270,
          child: _featuredLoading
              ? _buildFeaturedShimmer()
              : ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                      PointerDeviceKind.stylus,
                    },
                  ),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _featuredDishes.length,
                    itemBuilder: (context, index) {
                      return _buildFeaturedDishCard(_featuredDishes[index]);
                    },
                  ),
                ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFeaturedDishCard(Map<String, dynamic> dish) {
    final name = dish['name'] as String;
    final count = dish['count'] as int;
    final menuItem = dish['menuItem'] as MenuItem?;
    final imageUrl = menuItem != null
        ? MenuService.resolveImageUrl(
            menuItem.customImagePath ?? menuItem.fallbackImagePath)
        : '';

    return AnimatedTapScale(
      onTap: menuItem != null
          ? () => _showMenuItemDetailsDialog(menuItem)
          : null,
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.cardBorder, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(19)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl.isNotEmpty)
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: AppTheme.lightGrey,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          color: AppTheme.lightGrey,
                          child: const Center(
                            child: Icon(Icons.fastfood,
                                color: Colors.grey, size: 40),
                          ),
                        ),
                      )
                    else
                      Container(
                        color: AppTheme.lightGrey,
                        width: double.infinity,
                        height: double.infinity,
                        child: const Center(
                          child: Icon(Icons.fastfood,
                              color: Colors.grey, size: 40),
                        ),
                      ),
                    // Gradient shadow overlay on bottom of image for realism
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 45,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.45),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Count badge (Top-Left)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.priceBadgeBg,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          dish['isFallback'] == true || count == 0
                              ? '🔥 POPULAR'
                              : '${count}x today',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.priceBadgeText,
                          ),
                        ),
                      ),
                    ),
                    // Price Badge (Top-Right)
                    if (menuItem != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.priceBadgeBg,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '₱${_fmt.format(menuItem.price)}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.priceBadgeText,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Info section
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.darkGrey,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (menuItem != null && menuItem.category.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.categoryTagText.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        menuItem.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.categoryTagText,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedShimmer() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          width: 220,
          margin: const EdgeInsets.only(right: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Column(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.lightGrey.withValues(alpha: 0.5),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(19)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppTheme.lightGrey.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductCard(MenuItem item) {
    return AnimatedTapScale(
      onTap: () => _showMenuItemDetailsDialog(item),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.cardBorder, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            Expanded(
              flex: 4,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildImageWidget(item),
                    // Gradient scrim at bottom of image
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 30,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.35),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Price Badge: Deep forest green with gold/white text
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.forestGreen,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '₱${_fmt.format(item.price)}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.priceBadgeText,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Info Section
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.darkGrey,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.categoryTagText.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              color: AppTheme.categoryTagText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.add_circle_outline_rounded,
                        size: 16,
                        color: AppTheme.forestGreen.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildImageWidget(MenuItem item) {

    final resolvedUrl = MenuService.resolveImageUrl(item.customImagePath ?? item.fallbackImagePath);

    if (resolvedUrl.isNotEmpty) {

      return Image.network(

        resolvedUrl,

        fit: BoxFit.cover,

        width: double.infinity,

        height: double.infinity,

        loadingBuilder: (context, child, loadingProgress) {

          if (loadingProgress == null) return child;

          return Container(

            color: AppTheme.lightGrey,

            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),

          );

        },

        errorBuilder: (context, error, stackTrace) => Container(

          color: AppTheme.lightGrey,

          child: const Icon(Icons.fastfood, color: Colors.grey, size: 40),

        ),

      );

    }

    return Container(

      color: AppTheme.lightGrey,

      child: const Icon(Icons.fastfood, color: Colors.grey, size: 40),

    );

  }





  Future<void> _proceedToPayment(

    Map<String, dynamic> reservation,

    double paymentAmount, {

    double? totalPrice,

  }) async {

    // Show loading indicator

    showDialog(

      context: context,

      barrierDismissible: false,

      builder: (context) => const Center(child: CircularProgressIndicator()),

    );



    try {

      // Create automated PayMongo payment link

      final response = await PayMongoService.createPaymentLink(

        amount: paymentAmount,

        description: 'Payment for ${reservation['event_type'] ?? 'Reservation'}',

        metadata: {

          'reservationId': reservation['id'],

          'customerEmail': reservation['customer_email'],

          'table': reservation['_db_table'] ?? 'reservations',

        },

      );



      // Close loading indicator

      if (mounted) Navigator.of(context).pop();



      if (response['success'] == true && response['checkoutUrl'] != null) {

        if (!mounted) return;



        // Navigate to the automated payment confirmation page

        await Navigator.of(context).push(

          MaterialPageRoute(

            builder: (context) => PayMongoPaymentPage(

              paymentUrl: response['checkoutUrl'],

              paymentLinkId: response['data']?['data']?['id'],

              reservationId: reservation['id'],

              paymentAmount: paymentAmount,

              table: reservation['_db_table'] ?? 'reservations',

              totalPrice: totalPrice,

              onPaymentSuccess: () {

                if (mounted) {

                  setState(() {

                    _selectedMenuItems.clear();

                    _preOrderCart.clear();

                  });

                }

                _updateReservationPaymentStatus(

                  reservation['id'],

                  paymentAmount,

                  reservation['_db_table'] ?? 'reservations',

                  totalPrice: totalPrice,

                );

              },

            ),

          ),

        );

      } else {

        throw response['error'] ?? 'Failed to generate payment link';

      }

    } catch (e) {

      // Close loading indicator if it's still open

      if (mounted) Navigator.of(context).pop();

      _showErrorDialog('Could not start payment: $e');

    }

  }



  void _showErrorDialog(String message) {

    showDialog(

      context: context,



      builder: (context) => AlertDialog(

        title: const Text('Error'),



        content: Text(message),



        actions: [

          TextButton(

            onPressed: () => Navigator.pop(context),



            child: const Text('OK'),

          ),

        ],

      ),

    );

  }



  void _showSuccessDialog(String message) {

    showDialog(

      context: context,



      builder: (context) => AlertDialog(

        title: Row(

          children: [

            Icon(Icons.check_circle, color: Colors.green, size: 24),



            const SizedBox(width: 12),



            const Text('Success'),

          ],

        ),



        content: Text(message),



        actions: [

          TextButton(

            onPressed: () => Navigator.pop(context),



            child: const Text('OK'),

          ),

        ],

      ),

    );

  }



  Future<void> _updateReservationPaymentStatus(

    String reservationId,

    double paymentAmount,

    String table, {

    double? totalPrice,

  }) async {

    try {

      // Determine payment status based on amount and table type

      String paymentStatus;

      if (table == 'advance_orders') {

        paymentStatus = 'paid';

      } else if (totalPrice != null && paymentAmount >= totalPrice) {

        // Full payment for event place reservation

        paymentStatus = 'fully_paid';

      } else {

        // Deposit payment for event place reservation

        paymentStatus = 'deposit_paid';

      }



      await _reservationService.updatePaymentStatus(

        id: reservationId,

        paymentStatus: paymentStatus,

        table: table,

        paymentAmount: paymentAmount,

      );



      _loadCustomerReservations();

    } catch (e) {

      debugPrint('Error: $e');

    }

  }



  Future<void> _pickAndUploadIdImage() async {

    try {

      final picker = ImagePicker();

      final pickedFile = await picker.pickImage(

        source: ImageSource.gallery,

        imageQuality: 70,

      );



      if (pickedFile != null) {

        setState(() {

          _isUploadingId = true;

        });



        final fileName = 'id_${DateTime.now().millisecondsSinceEpoch}.${pickedFile.path.split('.').last}';

        final filePath = 'verification_ids/$fileName';

        final fileBytes = await pickedFile.readAsBytes();



        await Supabase.instance.client.storage

            .from('avatars')

            .uploadBinary(filePath, fileBytes);



        final imageUrl = Supabase.instance.client.storage

            .from('avatars')

            .getPublicUrl(filePath);



        setState(() {

          _selectedIdImage = pickedFile;

          _uploadedIdUrl = imageUrl;

          _isUploadingId = false;

        });

      }

    } catch (e) {

      setState(() {

        _isUploadingId = false;

      });

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(

            content: Text('Failed to upload ID: $e'),

            backgroundColor: Colors.red,

          ),

        );

      }

    }

  }



  Future<void> _createReservationWithoutPayment(

    dynamic currentUser,



    String eventType,



    String eventDate,



    String startTime,



    double durationHours,



    int numberOfGuests,



    String specialRequests,

  ) async {

    try {

      // Check if menu items are selected for menu-based pricing



      if (_selectedMenuItems.isNotEmpty) {

        final totalMenuPrice = _menuReservationService.calculateMenuTotalPrice(

          _selectedMenuItems,

        );



        // Calculate payment amount based on selected payment option

        final paymentAmount = _paymentOption == 'full'

            ? totalMenuPrice

            : _menuReservationService.calculateMenuDepositAmount(totalMenuPrice);



        await _reservationService.createMenuBasedReservation(

          customerEmail: currentUser.email ?? '',



          customerName: currentUser.userMetadata?['full_name'] ?? 'Customer',



          eventType: eventType,



          eventDate: eventDate,



          startTime: startTime,



          durationHours: durationHours,



          numberOfGuests: numberOfGuests,



          specialRequests: specialRequests,



          customerPhone: null,



          customerAddress: null,



          selectedMenuItems: _selectedMenuItems,



          totalMenuPrice: totalMenuPrice,



          depositAmount: paymentAmount,



          uploadedIdUrl: _uploadedIdUrl,



          paymentOption: _paymentOption,

        );

      } else {

        // Use traditional reservation without menu-based pricing



        await _reservationService.createReservation(

          customerEmail: currentUser.email ?? '',



          customerName: currentUser.userMetadata?['full_name'] ?? 'Customer',



          eventType: eventType,



          eventDate: eventDate,



          startTime: startTime,



          durationHours: durationHours,



          numberOfGuests: numberOfGuests,



          specialRequests: specialRequests,



          customerPhone: null,



          customerAddress: null,



          uploadedIdUrl: _uploadedIdUrl,



          paymentOption: _paymentOption,

        );

      }



      if (!mounted) return;



      // Clear menu and ID selection after successful reservation



      setState(() {
        for (final key in _selectedMenuItems.keys) {
          _preOrderCart.remove(key);
        }
        _selectedMenuItems.clear();

        _selectedIdImage = null;

        _uploadedIdUrl = null;

      });

      _saveCartToPrefs();



      _loadCustomerReservations();



      setState(() => _selectedIndex = 0);



      // Show success message with pricing details



      if (_selectedMenuItems.isNotEmpty) {

        final totalMenuPrice = _menuReservationService.calculateMenuTotalPrice(

          _selectedMenuItems,

        );



        // Calculate payment amount based on selected payment option

        final paymentAmount = _paymentOption == 'full' && _reservationType == 'Event Place'

            ? totalMenuPrice

            : _menuReservationService.calculateMenuDepositAmount(totalMenuPrice, reservationType: _reservationType);



        final paymentTypeText = _reservationType == 'Advance Order'

            ? 'Full Payment Required'

            : (_paymentOption == 'full' ? 'Full Payment Required' : '50% Deposit Required');



        _showSuccessDialog(

          'Reservation created successfully!\n\n'

          'Total Menu Price: PHP ${NumberFormat('#,##0.00').format(totalMenuPrice)}\n'

          '$paymentTypeText: PHP ${NumberFormat('#,##0.00').format(paymentAmount)}\n\n'

          'You will receive a price transaction shortly and can proceed with payment.',

        );

      } else {

        _showSuccessDialog(

          'Reservation created successfully! You will receive a price transaction shortly.',

        );

      }

    } catch (e) {

      _showErrorDialog('Failed to create reservation: $e');

    } finally {

      if (mounted) setState(() => _isLoading = false);

    }

  }



  String _getPaymentStatusText(String status, bool isQuoted, {bool isAdvanceOrder = false, bool isPayInFull = false}) {

    if (!isQuoted) return 'AWAITING TRANSACTION';



    switch (status) {

      case 'deposit_paid':

        return (isAdvanceOrder || isPayInFull) ? 'FULL PAID' : 'DEPOSIT PAID';



      case 'paid':

      case 'fully_paid':

        return 'PAID';



      case 'unpaid':

        return (isAdvanceOrder || isPayInFull) ? 'PAYMENT DUE' : 'DEPOSIT DUE';



      case 'refunded':

        return 'REFUNDED';



      default:

        return status.toUpperCase();

    }

  }



  void _showPaymentDialog(Map<String, dynamic> reservation) {

    final pricingInfo = _reservationService.getReservationPricing(reservation);



    final depositAmount = pricingInfo['depositAmount'] as double;

    final totalPrice = pricingInfo['totalPrice'] as double;



    final isPayInFull = reservation['_db_table'] == 'advance_orders' ||

        reservation['payment_option'] == 'full' ||

        (totalPrice > 0 && depositAmount >= totalPrice);



    // Only show payment option selection if not forced Pay in Full

    final isEventPlace = reservation['_db_table'] != 'advance_orders' && !isPayInFull;



    // Declare payment option outside builder to maintain state

    String paymentOption = isPayInFull ? 'full' : 'half';



    showDialog(

      context: context,



      builder: (context) => StatefulBuilder(

        builder: (context, setDialogState) {

          return AlertDialog(

            title: Row(

              children: [

                const Icon(Icons.payment, color: Colors.green),

                const SizedBox(width: 8),

                Text(isEventPlace ? 'Make Payment' : (isPayInFull ? 'Pay Full Amount' : 'Pay Deposit')),

              ],

            ),



            content: Column(

              mainAxisSize: MainAxisSize.min,

              crossAxisAlignment: CrossAxisAlignment.start,



              children: [

                Text(

                  isEventPlace

                      ? 'Choose your payment option below.'

                      : 'Complete your payment by paying the full amount.',

                  style: TextStyle(color: Colors.grey.shade600),

                ),



                const SizedBox(height: 16),



                // Payment option selection (only for event place)

                if (isEventPlace) ...[

                  Container(

                    decoration: BoxDecoration(

                      color: Colors.grey.shade50,

                      borderRadius: BorderRadius.circular(8),

                      border: Border.all(color: Colors.grey.shade200),

                    ),

                    child: ClipRRect(

                      borderRadius: BorderRadius.circular(8),

                      child: Material(

                        color: Colors.grey.shade50,

                        child: Column(

                          children: [

                            RadioListTile<String>(

                              title: const Text(

                                'Pay Half (Deposit)',

                                style: TextStyle(

                                  fontSize: 14,

                                  fontWeight: FontWeight.w600,

                                ),

                              ),

                              subtitle: Text(

                                'PHP ${depositAmount.toStringAsFixed(2)} - 50% deposit',

                                style: const TextStyle(fontSize: 12),

                              ),

                              // ignore: deprecated_member_use
                              value: 'half',
                              // ignore: deprecated_member_use
                              groupValue: paymentOption,
                              // ignore: deprecated_member_use
                              onChanged: (value) {

                                setDialogState(() {

                                  paymentOption = value!;

                                });

                              },

                              activeColor: AppTheme.primaryColor,

                              contentPadding: EdgeInsets.zero,

                              visualDensity: VisualDensity.compact,

                            ),

                            RadioListTile<String>(

                              title: const Text(

                                'Pay in Full',

                                style: TextStyle(

                                  fontSize: 14,

                                  fontWeight: FontWeight.w600,

                                ),

                              ),

                              subtitle: Text(

                                'PHP ${totalPrice.toStringAsFixed(2)} - Full amount',

                                style: const TextStyle(fontSize: 12),

                              ),

                              // ignore: deprecated_member_use
                              value: 'full',
                              // ignore: deprecated_member_use
                              groupValue: paymentOption,
                              // ignore: deprecated_member_use
                              onChanged: (value) {

                                setDialogState(() {

                                  paymentOption = value!;

                                });

                              },

                              activeColor: AppTheme.primaryColor,

                              contentPadding: EdgeInsets.zero,

                              visualDensity: VisualDensity.compact,

                            ),

                          ],

                        ),

                      ),

                    ),

                  ),

                  const SizedBox(height: 16),

                ],



                // Amount display

                Container(

                  padding: const EdgeInsets.all(16),



                  decoration: BoxDecoration(

                    color: Colors.green.withValues(alpha: 0.05),



                    borderRadius: BorderRadius.circular(8),



                    border: Border.all(color: Colors.green.withValues(alpha: 0.2)),

                  ),



                  child: Row(

                    mainAxisAlignment: MainAxisAlignment.spaceBetween,



                    children: [

                      Text(

                        isEventPlace

                            ? (paymentOption == 'full' ? 'Full Amount:' : 'Deposit Amount:')

                            : 'Total Amount:',



                        style: const TextStyle(fontWeight: FontWeight.bold),

                      ),



                      Text(

                        'PHP ${(paymentOption == 'full' && isEventPlace ? totalPrice : depositAmount).toStringAsFixed(2)}',



                        style: const TextStyle(

                          fontWeight: FontWeight.bold,



                          color: Colors.green,



                          fontSize: 18,

                        ),

                      ),

                    ],

                  ),

                ),



                const SizedBox(height: 16),



                const SizedBox(height: 12),



                SizedBox(

                  width: double.infinity,



                  child: ElevatedButton.icon(

                    onPressed: () {

                      Navigator.pop(context);



                      final paymentAmount = paymentOption == 'full' && isEventPlace

                          ? totalPrice

                          : depositAmount;



                      _proceedToPayment(

                        reservation,

                        paymentAmount,

                        totalPrice: isEventPlace ? totalPrice : null,

                      );

                    },



                    icon: const Icon(Icons.payment_rounded),



                    label: Text(

                      isEventPlace

                          ? (paymentOption == 'full' ? 'Pay Full Amount' : 'Pay Deposit')

                          : 'Pay with PayMongo',

                    ),



                    style: ElevatedButton.styleFrom(

                      backgroundColor: AppTheme.primaryColor,



                      foregroundColor: Colors.white,



                      padding: const EdgeInsets.symmetric(vertical: 12),

                    ),

                  ),

                ),

              ],

            ),



            actions: [

              TextButton(

                onPressed: () => Navigator.pop(context),



                child: const Text('Cancel'),

              ),

            ],

          );

        },

      ),

    );

  }



  String _formatLocalDateTime(dynamic dateTime) {

    if (dateTime == null) return 'N/A';



    try {

      final dt = dateTime is String

          ? DateTime.parse(dateTime).toLocal()

          : (dateTime as DateTime).toLocal();



      return "${dt.month}/${dt.day}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";

    } catch (e) {

      return dateTime.toString();

    }

  }



  Widget _buildAccountMenuCard({

    required IconData icon,



    required String title,



    required String subtitle,



    required VoidCallback onTap,



    bool isDestructive = false,

  }) {

    return Container(

      margin: const EdgeInsets.only(bottom: 16),



      decoration: BoxDecoration(

        color: Colors.white,



        borderRadius: BorderRadius.circular(16),



        boxShadow: [

          BoxShadow(

            color: Colors.black.withValues(alpha: 0.04),



            blurRadius: 10,



            offset: const Offset(0, 4),

          ),

        ],

      ),



      child: Material(

        color: Colors.transparent,



        child: InkWell(

          onTap: onTap,



          borderRadius: BorderRadius.circular(16),



          child: Padding(

            padding: const EdgeInsets.all(16),



            child: Row(

              children: [

                Container(

                  padding: const EdgeInsets.all(12),



                  decoration: BoxDecoration(

                    color: isDestructive

                        ? Colors.red.shade50

                        : AppTheme.primaryColor.withValues(alpha: 0.07),



                    shape: BoxShape.circle,

                  ),



                  child: Icon(

                    icon,



                    color: isDestructive

                        ? Colors.red.shade600

                        : AppTheme.primaryColor,



                    size: 24,

                  ),

                ),



                const SizedBox(width: 16),



                Expanded(

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,



                    children: [

                      Text(

                        title,



                        style: TextStyle(

                          fontSize: 16,



                          fontWeight: FontWeight.bold,



                          color: isDestructive

                              ? Colors.red.shade600

                              : AppTheme.darkGrey,

                        ),

                      ),



                      const SizedBox(height: 2),



                      Text(

                        subtitle,



                        style: TextStyle(

                          fontSize: 13,



                          color: Colors.grey.shade600,

                        ),

                      ),

                    ],

                  ),

                ),



                Icon(

                  Icons.arrow_forward_ios_rounded,



                  size: 16,



                  color: Colors.grey.shade400,

                ),

              ],

            ),

          ),

        ),

      ),

    );

  }



  Widget _buildActivitySection() {
    final activeBookings = customerReservations.where((r) {
      final status = r['status']?.toString().toLowerCase() ?? '';
      return status != 'cancelled' && status != 'done' && status != 'completed';
    }).toList();

    final confirmedBookings = customerReservations.where((r) => r['status'] == 'confirmed').toList();

    // Filter displayed list according to selected filter
    List<Map<String, dynamic>> displayedReservations;
    if (_activityFilter == 'in_progress') {
      displayedReservations = activeBookings;
    } else if (_activityFilter == 'confirmed') {
      displayedReservations = confirmedBookings;
    } else {
      displayedReservations = customerReservations;
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Executive Live Order & Activity Overview Card ────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF0C241F),
                    Color(0xFF14332E),
                    Color(0xFF1B453D),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppTheme.warmGold.withValues(alpha: 0.35),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0A1C18).withValues(alpha: 0.45),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: AppTheme.warmGold.withValues(alpha: 0.08),
                    blurRadius: 30,
                    spreadRadius: -2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                              ),
                              child: const Icon(
                                Icons.timeline_rounded,
                                color: Color(0xFFD9A441),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ORDER & ACTIVITY TRACKER',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFFD9A441),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Live Status & Schedule',
                                    style: GoogleFonts.inter(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Tappable TOTAL Pill
                      AnimatedTapScale(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _activityFilter = 'all';
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _activityFilter == 'all'
                                ? const Color(0xFF34C759).withValues(alpha: 0.25)
                                : const Color(0xFF34C759).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _activityFilter == 'all'
                                  ? const Color(0xFF86EFAC)
                                  : const Color(0xFF34C759).withValues(alpha: 0.35),
                              width: _activityFilter == 'all' ? 1.4 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const LivePulseDot(color: Color(0xFF34C759), size: 6),
                              const SizedBox(width: 5),
                              Text(
                                '${customerReservations.length} TOTAL',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF86EFAC),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Sub-metrics Bar (Clickable Filter Capsules)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      children: [
                        // ── Active Pipeline Filter ──
                        Expanded(
                          child: AnimatedTapScale(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _activityFilter = _activityFilter == 'in_progress' ? 'all' : 'in_progress';
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: _activityFilter == 'in_progress'
                                    ? const Color(0xFFFF9500).withValues(alpha: 0.22)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _activityFilter == 'in_progress'
                                      ? const Color(0xFFFF9500).withValues(alpha: 0.55)
                                      : Colors.transparent,
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.pending_actions_rounded,
                                    color: _activityFilter == 'in_progress' ? const Color(0xFFFFB84D) : const Color(0xFFFF9500),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Active Pipeline',
                                          style: GoogleFonts.inter(
                                            color: _activityFilter == 'in_progress' ? Colors.white : const Color(0xFF94A3B8),
                                            fontSize: 10,
                                            fontWeight: _activityFilter == 'in_progress' ? FontWeight.w700 : FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          '${activeBookings.length} In Progress',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            color: _activityFilter == 'in_progress' ? const Color(0xFFFFD599) : Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 28,
                          color: Colors.white.withValues(alpha: 0.12),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        // ── Confirmed Filter ──
                        Expanded(
                          child: AnimatedTapScale(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _activityFilter = _activityFilter == 'confirmed' ? 'all' : 'confirmed';
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: _activityFilter == 'confirmed'
                                    ? const Color(0xFF34C759).withValues(alpha: 0.22)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _activityFilter == 'confirmed'
                                      ? const Color(0xFF34C759).withValues(alpha: 0.55)
                                      : Colors.transparent,
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.verified_rounded,
                                    color: _activityFilter == 'confirmed' ? const Color(0xFF86EFAC) : const Color(0xFF34C759),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Confirmed',
                                          style: GoogleFonts.inter(
                                            color: _activityFilter == 'confirmed' ? Colors.white : const Color(0xFF94A3B8),
                                            fontSize: 10,
                                            fontWeight: _activityFilter == 'confirmed' ? FontWeight.w700 : FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          '${confirmedBookings.length} Approved',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            color: _activityFilter == 'confirmed' ? const Color(0xFFBAF7D0) : const Color(0xFF86EFAC),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Section Title Row & Active Filter Tag ─────────────────────────
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9A441),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _activityFilter == 'in_progress'
                      ? 'In Progress Orders'
                      : (_activityFilter == 'confirmed' ? 'Confirmed Bookings' : 'Active & Recent Bookings'),
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                // ── Track Reschedules Button ──
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _rescheduleService.customerRescheduleRequestsStream(
                    Supabase.instance.client.auth.currentUser?.email ?? '',
                  ),
                  builder: (context, snapshot) {
                    final requests = snapshot.data ?? [];
                    if (requests.isEmpty) return const SizedBox.shrink();
                    final pendingCount = requests.where((r) => r['status'] == 'pending').length;

                    return AnimatedTapScale(
                      onTap: () => _showRescheduleTrackerModal(),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF007AFF).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.edit_calendar_rounded, size: 14, color: Color(0xFF007AFF)),
                            const SizedBox(width: 5),
                            Text(
                              'Track Reschedules',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF007AFF),
                              ),
                            ),
                            if (pendingCount > 0) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF007AFF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$pendingCount',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
                if (_activityFilter != 'all')
                  AnimatedTapScale(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _activityFilter = 'all');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14332E).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF14332E).withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Show All',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF14332E),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.close_rounded, size: 12, color: Color(0xFF14332E)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Empty State or Reservation List ─────────────────────────────
            if (displayedReservations.isEmpty)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 16),
                padding: const EdgeInsets.all(32),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF14332E), Color(0xFF1E4A42)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF14332E).withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.assignment_rounded,
                        size: 38,
                        color: Color(0xFFD9A441),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _activityFilter == 'all'
                          ? 'No Reservation Activity'
                          : (_activityFilter == 'in_progress'
                              ? 'No In-Progress Bookings'
                              : 'No Confirmed Bookings'),
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _activityFilter == 'all'
                          ? 'Your active orders and reservation history will appear here once booked.'
                          : 'No records match this filter. Tap "Show All" to view everything.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                    if (_activityFilter != 'all') ...[
                      const SizedBox(height: 14),
                      TextButton.icon(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() => _activityFilter = 'all');
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Show All Records'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF14332E),
                          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayedReservations.length,
                itemBuilder: (context, index) {
                  final reservation = displayedReservations[index];
                  final isAdvanceOrder = reservation['_db_table'] == 'advance_orders';
                  final isPaid = reservation['payment_status'] == 'paid' || reservation['payment_status'] == 'fully_paid';
                  final status = reservation['status'] as String? ?? 'pending';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Card Header (Petty Cash Style) ─────────────────
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF14332E),
                                  Color(0xFF1E4A42),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                                  ),
                                  child: Icon(
                                    isAdvanceOrder ? Icons.takeout_dining_rounded : Icons.deck_rounded,
                                    size: 18,
                                    color: const Color(0xFFD9A441),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        reservation['event_type'] ?? (isAdvanceOrder ? 'Advance Order' : 'Reservation'),
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (reservation['created_at'] != null)
                                        Text(
                                          'Booked ${_formatLocalDateTime(reservation['created_at'])}',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: Colors.white.withValues(alpha: 0.75),
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                _buildStatusChip(status),
                                if (isAdvanceOrder && status == 'confirmed' && !isPaid) ...[
                                  const SizedBox(width: 6),
                                  AnimatedTapScale(
                                    onTap: () => _showPaymentDialog(reservation),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        gradient: AppTheme.goldGradient,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppTheme.warmGold.withValues(alpha: 0.35),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.payment_rounded, color: AppTheme.darkBrownText, size: 13),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Pay',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
                                              color: AppTheme.darkBrownText,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                                if (isPaid) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF34C759).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF34C759).withValues(alpha: 0.45)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.verified_rounded, color: Color(0xFF86EFAC), size: 12),
                                        const SizedBox(width: 4),
                                        Text(
                                          'PAID',
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFF86EFAC),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (reservation['reschedule_status'] == 'pending_approval') ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD97706).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.45)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.pending_actions_rounded, color: Color(0xFFFBBF24), size: 12),
                                        const SizedBox(width: 4),
                                        Text(
                                          'RESCHEDULE PENDING',
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFFFBBF24),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else if (reservation['reschedule_status'] == 'reschedule_rejected' ||
                                    reservation['reschedule_status'] == 'rejected' ||
                                    reservation['reschedule_status'] == 'declined') ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDC2626).withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.45)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 12),
                                        const SizedBox(width: 4),
                                        Text(
                                          'DECLINED',
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFFEF4444),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else if (reservation['reschedule_status'] == 'rescheduled' ||
                                    reservation['reschedule_status'] == 'approved') ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF15803D).withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF15803D).withValues(alpha: 0.45)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.event_available_rounded, color: Color(0xFF86EFAC), size: 12),
                                        const SizedBox(width: 4),
                                        Text(
                                          'RESCHEDULED',
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFF86EFAC),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if ((status == 'confirmed' || status == 'pending') &&
                                    !(isAdvanceOrder && isPaid)) ...[
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert_rounded, color: Colors.white70, size: 20),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    onSelected: (String value) {
                                      if (value == 'cancel') {
                                        _showCancellationDialog(reservation);
                                      } else if (value == 'reschedule') {
                                        if (reservation['reschedule_status'] == 'pending_approval') {
                                          _showSnackBar('A reschedule request is already pending approval.', Colors.orange);
                                        } else {
                                          _showRescheduleDialog(reservation);
                                        }
                                      }
                                    },
                                    itemBuilder: (BuildContext context) => [
                                      PopupMenuItem<String>(
                                        value: 'reschedule',
                                        child: Row(
                                          children: [
                                            const Icon(Icons.edit_calendar_rounded, color: Color(0xFF007AFF), size: 16),
                                            const SizedBox(width: 10),
                                            Text(
                                              reservation['reschedule_status'] == 'pending_approval'
                                                  ? 'Reschedule Pending'
                                                  : (reservation['reschedule_status'] == 'reschedule_rejected' ||
                                                          reservation['reschedule_status'] == 'rejected' ||
                                                          reservation['reschedule_status'] == 'declined'
                                                      ? 'Reschedule (Declined)'
                                                      : 'Reschedule'),
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: reservation['reschedule_status'] == 'pending_approval'
                                                    ? Colors.orange
                                                    : null,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'cancel',
                                        child: Row(
                                          children: [
                                            const Icon(Icons.close_rounded, color: Color(0xFFDC2626), size: 16),
                                            const SizedBox(width: 10),
                                            Text(
                                              'Cancel Booking',
                                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFFDC2626)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // ── Card Body & Details ─────────────────────────────
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Event parameters grid
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    children: [
                                      _buildActivityDetailRow(
                                        Icons.calendar_today_rounded,
                                        'Date',
                                        reservation['event_date'] ?? reservation['order_date'] ?? 'N/A',
                                      ),
                                      const SizedBox(height: 8),
                                      _buildActivityDetailRow(
                                        Icons.access_time_rounded,
                                        'Time',
                                        reservation['start_time'] ?? reservation['pickup_time'] ?? 'N/A',
                                      ),
                                      if (reservation['number_of_guests'] != null) ...[
                                        const SizedBox(height: 8),
                                        _buildActivityDetailRow(
                                          Icons.people_alt_rounded,
                                          'Guests',
                                          '${reservation['number_of_guests']} Guests',
                                        ),
                                      ],
                                      if (reservation['_db_table'] == 'reservations' && reservation['duration_hours'] != null) ...[
                                        const SizedBox(height: 8),
                                        _buildActivityDetailRow(
                                          Icons.timer_rounded,
                                          'Duration',
                                          '${reservation['duration_hours']} Hours',
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                // Ordered menu items
                                if (reservation['selected_menu_items'] != null &&
                                    (reservation['selected_menu_items'] as Map).isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  _buildActivityOrderItems(reservation),
                                ],

                                // In-Card Reschedule Status Tracker Banner
                                if (reservation['_db_table'] == 'reservations') ...[
                                  _buildInCardRescheduleStatus(reservation),
                                ],

                                // Real-time order progress stepper for paid advance orders
                                if (isAdvanceOrder && isPaid) ...[
                                  const SizedBox(height: 14),
                                  _buildProgressStepper(status),
                                ],
                              ],
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

  Widget _buildActivityOrderItems(Map<String, dynamic> reservation) {
    final items = reservation['selected_menu_items'] as Map<String, dynamic>? ?? {};
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.restaurant_menu_rounded, size: 14, color: Color(0xFF14332E)),
              const SizedBox(width: 6),
              Text(
                'ORDERED ITEMS',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF64748B),
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14332E).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${entry.value}x',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF14332E),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.key,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProgressStepper(String status) {
    final steps = ['Paid', 'Preparing', 'Ready'];
    int currentStep = 0;

    final s = status.toLowerCase();
    if (s == 'preparing' || s == 'cooking') {
      currentStep = 1;
    } else if (s == 'ready' || s == 'done' || s == 'completed') {
      currentStep = 2;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF14332E).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF14332E).withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.stream_rounded, size: 14, color: Color(0xFF14332E)),
                  const SizedBox(width: 6),
                  Text(
                    'LIVE ORDER TIMELINE',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF14332E),
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              if (currentStep == 1)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const LivePulseDot(color: Color(0xFFFF9500), size: 7),
                    const SizedBox(width: 5),
                    Text(
                      'Kitchen Cooking',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(steps.length, (index) {
              final isCompleted = index < currentStep;
              final isCurrent = index == currentStep;
              final isActive = index <= currentStep;

              return Expanded(
                child: Row(
                  children: [
                    Column(
                      children: [
                        Container(
                          width: isCurrent ? 32 : 26,
                          height: isCurrent ? 32 : 26,
                          decoration: BoxDecoration(
                            gradient: isCurrent
                                ? AppTheme.goldGradient
                                : (isCompleted ? const LinearGradient(colors: [Color(0xFF14332E), Color(0xFF1E4A42)]) : null),
                            color: (!isCurrent && !isCompleted) ? const Color(0xFFE2E8F0) : null,
                            shape: BoxShape.circle,
                            boxShadow: isCurrent
                                ? [
                                    BoxShadow(
                                      color: AppTheme.warmGold.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: isCompleted
                                ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                                : Icon(
                                    isCurrent
                                        ? (index == 0
                                            ? Icons.receipt_long_rounded
                                            : (index == 1 ? Icons.soup_kitchen_rounded : Icons.takeout_dining_rounded))
                                        : Icons.radio_button_unchecked_rounded,
                                    size: isCurrent ? 16 : 12,
                                    color: (isActive || isCompleted)
                                        ? (isCurrent ? AppTheme.darkBrownText : Colors.white)
                                        : const Color(0xFF94A3B8),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          steps[index],
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: isCurrent ? FontWeight.w800 : (isCompleted ? FontWeight.w600 : FontWeight.w500),
                            color: isCurrent
                                ? const Color(0xFFB45309)
                                : (isCompleted ? const Color(0xFF0F172A) : const Color(0xFF94A3B8)),
                          ),
                        ),
                      ],
                    ),
                    if (index < steps.length - 1)
                      Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.only(bottom: 18),
                          decoration: BoxDecoration(
                            gradient: index < currentStep
                                ? const LinearGradient(colors: [Color(0xFF14332E), Color(0xFF1E4A42)])
                                : null,
                            color: index >= currentStep ? const Color(0xFFE2E8F0) : null,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityDetailRow(IconData icon, String label, String? value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF14332E)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
        Expanded(
          child: Text(
            value ?? 'N/A',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;
    String label = status.toUpperCase();
    bool showPulse = false;

    switch (status.toLowerCase()) {
      case 'pending':
        color = const Color(0xFFFF9500);
        icon = Icons.pending_rounded;
        showPulse = true;
        break;
      case 'confirmed':
        color = const Color(0xFF34C759);
        icon = Icons.check_circle_rounded;
        break;
      case 'preparing':
      case 'cooking':
        color = const Color(0xFF007AFF);
        icon = Icons.soup_kitchen_rounded;
        label = 'PREPARING';
        showPulse = true;
        break;
      case 'ready':
        color = const Color(0xFF34C759);
        icon = Icons.restaurant_rounded;
        label = 'READY';
        showPulse = true;
        break;
      case 'done':
      case 'completed':
        color = const Color(0xFF64748B);
        icon = Icons.check_circle_rounded;
        label = 'COMPLETED';
        break;
      case 'cancelled':
        color = const Color(0xFFDC2626);
        icon = Icons.cancel_rounded;
        break;
      default:
        color = const Color(0xFF64748B);
        icon = Icons.help_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showPulse) ...[
            LivePulseDot(color: color, size: 6),
            const SizedBox(width: 5),
          ] else ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }



  /// Show dialog to cancel a confirmed reservation with refund info



  void _showCancellationDialog(Map<String, dynamic> reservation) {

    final eventDate = reservation['event_date'] ?? reservation['order_date'] ?? '';



    final eventType = reservation['event_type'] ?? 'Reservation';



    final double paymentAmount = (reservation['payment_amount'] as num?)?.toDouble() ??
        (reservation['deposit_amount'] as num?)?.toDouble() ??
        (reservation['amount_paid'] as num?)?.toDouble() ??
        (reservation['total_price'] as num?)?.toDouble() ??
        (reservation['total_amount'] as num?)?.toDouble() ??
        0.0;



    final refundAmount = RefundService().calculateRefundAmount(

      eventDate: eventDate,

      paymentAmount: paymentAmount,

    );



    void cancelReservation() async {

      if (!mounted) return;



      Navigator.pop(context);



      setState(() => _isLoading = true);



      try {

        final currentUser = Supabase.instance.client.auth.currentUser;



        if (currentUser == null) throw Exception('User not authenticated');



        // Show reason selection dialog



        String? selectedReason;



        await showDialog(

          context: context,



          builder: (context) => AlertDialog(

            title: const Text('Cancellation Reason'),



            content: Column(

              mainAxisSize: MainAxisSize.min,



              children: [

                const Text('Please select a reason for cancellation:'),



                const SizedBox(height: 16),



                ...AppConstants.cancellationReasons.map(

                  (reason) => ListTile(

                    title: Text(reason),



                    onTap: () {

                      selectedReason = reason;



                      Navigator.pop(context);

                    },

                  ),

                ),

              ],

            ),

          ),

        );



        if (selectedReason == null) {

          setState(() => _isLoading = false);



          return;

        }



        // Cancel the record in the appropriate table

        if (reservation['_db_table'] == 'advance_orders') {

          await _reservationService.cancelAdvanceOrder(

            orderId: reservation['id'],



            customerEmail: currentUser.email!,



            customerName: currentUser.userMetadata?['name'] ?? 'Customer',



            orderType: reservation['order_type'] ?? 'Pick Up',



            orderDate: reservation['order_date'] ?? eventDate,



            cancellationReason: selectedReason!,

          );

        } else {

          await _reservationService.cancelReservation(

            reservationId: reservation['id'],



            customerEmail: currentUser.email!,



            customerName: currentUser.userMetadata?['name'] ?? 'Customer',



            eventType: eventType,



            eventDate: eventDate,



            cancellationReason: selectedReason!,



            isAdminCancel: false,

          );

        }



        // Send in-app notification to customer



        await NotificationService.sendNotification(

          recipientEmail: currentUser.email,



          actorName: 'System',



          actionType: 'cancelled',



          reservationId: reservation['id'],



          eventType: eventType,



          eventDate: eventDate,

        );



        // Send in-app notification to admins



        await NotificationService.sendNotification(

          isForAdmin: true,



          actorName: currentUser.userMetadata?['name'] ?? 'Customer',



          actionType: 'cancelled',



          reservationId: reservation['id'],



          eventType: eventType,



          eventDate: eventDate,



          customerEmail: currentUser.email,

        );



        _showSnackBar(

          'Reservation cancelled successfully. Refund: ₱${refundAmount.toStringAsFixed(2)}',



          Colors.green,

        );



        _loadCustomerReservations();

      } catch (e) {

        _showSnackBar('Error cancelling reservation: $e', Colors.red);

      } finally {

        if (mounted) {

          setState(() => _isLoading = false);

        }

      }

    }



    showDialog(

      context: context,



      barrierDismissible: false,



      builder: (context) => AlertDialog(

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),



        title: const Row(

          children: [

            Icon(Icons.cancel_outlined, color: Colors.red),



            SizedBox(width: 12),



            Text('Cancel Reservation'),

          ],

        ),



        content: Column(

          mainAxisSize: MainAxisSize.min,



          crossAxisAlignment: CrossAxisAlignment.start,



          children: [

            Text('Event: $eventType on $eventDate'),



            const SizedBox(height: 12),



            Container(

              padding: const EdgeInsets.all(12),



              decoration: BoxDecoration(

                color: Colors.blue.withValues(alpha: 0.1),



                borderRadius: BorderRadius.circular(8),

              ),



              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,



                children: [

                  const Text(

                    'Refund Information:',



                    style: TextStyle(fontWeight: FontWeight.bold),

                  ),



                  const SizedBox(height: 8),
                  Text('Expected Refund: ₱${refundAmount.toStringAsFixed(2)}'),
                  const SizedBox(height: 4),
                  Text(
                    refundAmount > 0
                        ? 'Refund will be processed within 5-7 business days'
                        : (paymentAmount > 0
                            ? 'No refund (cancellation past policy window)'
                            : 'No payment made for this booking (Unpaid)'),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],

              ),

            ),

          ],

        ),



        actions: [

          TextButton(

            onPressed: () => Navigator.pop(context),



            child: const Text('Keep Reservation'),

          ),



          ElevatedButton(

            style: ElevatedButton.styleFrom(

              backgroundColor: Colors.red,



              foregroundColor: Colors.white,

            ),



            onPressed: cancelReservation,



            child: const Text('Cancel Reservation'),

          ),

        ],

      ),

    );

  }



  /// Show dialog to reschedule a reservation (Pending Admin Approval)
  void _showRescheduleDialog(Map<String, dynamic> reservation) {
    final currentDate = reservation['event_date']?.toString() ?? '';
    final currentTime = reservation['start_time']?.toString() ?? '';
    final currentDuration = reservation['duration_hours'];
    final currentGuests = reservation['number_of_guests'];
    final reasonController = TextEditingController();

    String? newDate;
    String? newTime;
    DateTime? rawPickedDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_calendar_rounded, color: Color(0xFF007AFF), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reschedule Request',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 17),
                    ),
                    Text(
                      'Requires Admin Approval',
                      style: GoogleFonts.plusJakartaSans(color: const Color(0xFFD97706), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Current Schedule Card ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CURRENT SCHEDULE',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$currentDate at $currentTime',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '${currentDuration ?? 2}h duration • ${currentGuests ?? 1} guests',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── New Date Picker ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select New Date:',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    Text(
                      reservation['_db_table'] == 'advance_orders'
                          ? 'Same-day available'
                          : 'Min. ${_appSettings.getMinReservationDaysAhead()} days ahead',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final isAdvance = reservation['_db_table'] == 'advance_orders';
                    final minDate = isAdvance
                        ? DateTime.now()
                        : DateTime.now().add(
                            Duration(days: _appSettings.getMinReservationDaysAhead()),
                          );
                    final maxDate = DateTime.now().add(
                      const Duration(days: 365),
                    );
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: minDate,
                      firstDate: minDate,
                      lastDate: maxDate,
                    );
                    if (picked != null) {
                      setDialogState(() {
                        rawPickedDate = picked;
                        newDate = DateFormat('MMMM d, yyyy').format(picked);
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: newDate != null ? const Color(0xFF007AFF) : const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 18, color: newDate != null ? const Color(0xFF007AFF) : const Color(0xFF64748B)),
                        const SizedBox(width: 10),
                        Text(
                          newDate ?? 'Choose a new date',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: newDate != null ? FontWeight.w700 : FontWeight.w500,
                            color: newDate != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── New Time Picker ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select New Time:',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    Text(
                      'Open: ${(reservation['_db_table'] == 'advance_orders' ? 10 : _operatingHoursStart).toString().padLeft(2, '0')}:00 - ${(reservation['_db_table'] == 'advance_orders' ? 19 : _operatingHoursEnd).toString().padLeft(2, '0')}:00',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final isAdvance = reservation['_db_table'] == 'advance_orders';
                    final startHour = isAdvance ? 10 : _operatingHoursStart;
                    final endHour = isAdvance ? 19 : _operatingHoursEnd;

                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: startHour,
                        minute: 0,
                      ),
                    );
                    if (picked != null) {
                      // Validate against operating hours
                      if (picked.hour < startHour ||
                          picked.hour > endHour ||
                          (picked.hour == endHour && picked.minute > 0)) {
                        _showSnackBar(
                          'Please select a time between ${startHour.toString().padLeft(2, '0')}:00 and ${endHour.toString().padLeft(2, '0')}:00',
                          Colors.red,
                        );
                        return;
                      }

                      // Validate 40-minutes-ahead rule for same-day Advance Orders
                      if (isAdvance && rawPickedDate != null) {
                        final now = DateTime.now();
                        final isToday = rawPickedDate!.year == now.year &&
                            rawPickedDate!.month == now.month &&
                            rawPickedDate!.day == now.day;
                        if (isToday) {
                          final selectedDateTime = DateTime(
                            now.year,
                            now.month,
                            now.day,
                            picked.hour,
                            picked.minute,
                          );
                          final timeDifference = selectedDateTime.difference(now);
                          if (timeDifference.inMinutes < 40) {
                            final earliestTime = now.add(const Duration(minutes: 40));
                            final earliestFormatted =
                                '${earliestTime.hour.toString().padLeft(2, '0')}:${earliestTime.minute.toString().padLeft(2, '0')}';
                            _showSnackBar(
                              'For same-day orders, please select a time at least 40 minutes from now (earliest: $earliestFormatted)',
                              Colors.red,
                            );
                            return;
                          }
                        }
                      }

                      setDialogState(() {
                        newTime = picked.format(context);
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: newTime != null ? const Color(0xFF007AFF) : const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 18, color: newTime != null ? const Color(0xFF007AFF) : const Color(0xFF64748B)),
                        const SizedBox(width: 10),
                        Text(
                          newTime ?? 'Choose a new time',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: newTime != null ? FontWeight.w700 : FontWeight.w500,
                            color: newTime != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Reason Input ──
                Text(
                  'Reason for Rescheduling:',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonController,
                  maxLines: 2,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'e.g., Unexpected schedule conflict, family event...',
                    hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Policy Notice ──
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your original schedule remains active until this request is approved by the admin.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: const Color(0xFF92400E),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton.icon(
              onPressed: (newDate != null && newTime != null)
                  ? () async {
                      Navigator.pop(context);
                      setState(() => _isLoading = true);

                      try {
                        final formattedDate = rawPickedDate != null
                            ? "${rawPickedDate!.year}-${rawPickedDate!.month.toString().padLeft(2, '0')}-${rawPickedDate!.day.toString().padLeft(2, '0')}"
                            : _formatDateForStorage(newDate!);

                        // ── Check for time slot conflict (same as event booking flow) ──
                        final double durationHours = currentDuration is num
                            ? currentDuration.toDouble()
                            : 2.0;

                        final bool isOverlapping =
                            await _reservationService.isTimeSlotOverlapping(
                          eventDate: formattedDate,
                          startTime: newTime!,
                          durationHours: durationHours,
                          excludeReservationId: reservation['id'].toString(),
                        );

                        if (isOverlapping) {
                          if (mounted) setState(() => _isLoading = false);
                          _showSnackBar(
                            'This time slot is already booked. Please choose a different time or date.',
                            Colors.orange,
                          );
                          return;
                        }

                        final result = await _rescheduleService.requestReschedule(
                          reservationId: reservation['id'].toString(),
                          customerId: reservation['customer_id']?.toString(),
                          customerName: reservation['customer_name']?.toString() ?? 'Customer',
                          customerEmail: reservation['customer_email']?.toString() ?? '',
                          customerPhone: reservation['customer_phone']?.toString(),
                          oldDate: currentDate,
                          oldTime: currentTime,
                          oldDuration: currentDuration is int ? currentDuration : (currentDuration as num?)?.toInt(),
                          oldGuests: currentGuests is int ? currentGuests : (currentGuests as num?)?.toInt(),
                          newDate: formattedDate,
                          newTime: newTime!,
                          reason: reasonController.text.trim().isNotEmpty
                              ? reasonController.text.trim()
                              : 'Customer requested reschedule',
                        );

                        if (result['success'] == true) {
                          _showSnackBar(
                            'Reschedule request submitted for admin approval!',
                            Colors.green,
                          );
                          _loadCustomerReservations();
                        } else {
                          _showSnackBar(
                            result['error']?.toString() ?? 'Failed to submit request',
                            Colors.red,
                          );
                        }
                      } catch (e) {
                        _showSnackBar('Error requesting reschedule: $e', Colors.red);
                      } finally {
                        if (mounted) setState(() => _isLoading = false);
                      }
                    }
                  : null,
              icon: const Icon(Icons.send_rounded, size: 16),
              label: Text(
                'Submit Request',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }



  // ══════════════════════════════════════════════════════════
  //  RESCHEDULE TRACKER & IN-CARD STATUS
  // ══════════════════════════════════════════════════════════

  Widget _buildInCardRescheduleStatus(Map<String, dynamic> reservation) {
    final status = reservation['reschedule_status']?.toString();
    if (status == null || status.isEmpty || status == 'none') return const SizedBox.shrink();

    Color bgColor;
    Color borderColor;
    Color iconColor;
    IconData icon;
    String title;
    String description;

    if (status == 'pending_approval') {
      bgColor = const Color(0xFFFEF3C7);
      borderColor = const Color(0xFFF59E0B);
      iconColor = const Color(0xFFD97706);
      icon = Icons.hourglass_top_rounded;
      title = 'Reschedule Request Pending Admin Approval';
      description = 'You requested a schedule change. We will notify you once admin confirms or updates it.';
    } else if (status == 'rescheduled') {
      bgColor = const Color(0xFFDCFCE7);
      borderColor = const Color(0xFF22C55E);
      iconColor = const Color(0xFF15803D);
      icon = Icons.check_circle_rounded;
      title = 'Reschedule Request Approved!';
      description = 'Your new schedule has been confirmed by Admin and is now active.';
    } else if (status == 'reschedule_rejected') {
      bgColor = const Color(0xFFFEE2E2);
      borderColor = const Color(0xFFEF4444);
      iconColor = const Color(0xFFDC2626);
      icon = Icons.cancel_rounded;
      title = 'Reschedule Request Not Approved';
      description = 'Admin was unable to accommodate the requested time. Your original schedule remains active.';
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF475569),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: () => _showRescheduleTrackerModal(highlightReservationId: reservation['id']?.toString()),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View Tracker & Details',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: iconColor,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 12, color: iconColor),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRescheduleTrackerModal({String? highlightReservationId}) {
    final userEmail = Supabase.instance.client.auth.currentUser?.email ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Top drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Modal Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.edit_calendar_rounded, color: Color(0xFF007AFF), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reschedule Tracker',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Real-time review updates on your requested schedule changes',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Realtime Stream of Reschedule Requests
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _rescheduleService.customerRescheduleRequestsStream(userEmail),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF007AFF)),
                      );
                    }

                    final requests = snapshot.data ?? [];

                    if (requests.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.event_busy_rounded, size: 40, color: Color(0xFF94A3B8)),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No Reschedule Requests',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'When you request to change a booking date or time, you can monitor its real-time review progress here.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: requests.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final req = requests[index];
                        final isHighlighted = highlightReservationId != null &&
                            req['reservation_id']?.toString() == highlightReservationId;
                        return _buildRescheduleTrackerCard(req, isHighlighted);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRescheduleTrackerCard(Map<String, dynamic> req, bool isHighlighted) {
    final status = (req['status'] ?? 'pending').toString().toLowerCase();
    final oldDate = req['old_date']?.toString() ?? '';
    final oldTime = req['old_time']?.toString() ?? '';
    final newDate = req['new_date']?.toString() ?? '';
    final newTime = req['new_time']?.toString() ?? '';
    final reason = req['reason']?.toString() ?? 'Reschedule requested';
    final adminNotes = req['admin_notes']?.toString();
    final createdAt = req['created_at']?.toString();

    Color cardBorderColor;
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (status == 'approved') {
      cardBorderColor = const Color(0xFF22C55E);
      statusColor = const Color(0xFF15803D);
      statusLabel = 'APPROVED';
      statusIcon = Icons.check_circle_rounded;
    } else if (status == 'rejected') {
      cardBorderColor = const Color(0xFFEF4444);
      statusColor = const Color(0xFFDC2626);
      statusLabel = 'DECLINED';
      statusIcon = Icons.cancel_rounded;
    } else if (status == 'cancelled') {
      cardBorderColor = const Color(0xFF94A3B8);
      statusColor = const Color(0xFF64748B);
      statusLabel = 'CANCELLED';
      statusIcon = Icons.block_rounded;
    } else {
      cardBorderColor = const Color(0xFF007AFF);
      statusColor = const Color(0xFFD97706);
      statusLabel = 'PENDING APPROVAL';
      statusIcon = Icons.hourglass_top_rounded;
    }

    String requestedAtStr = '';
    if (createdAt != null) {
      try {
        final parsed = DateTime.parse(createdAt).toLocal();
        requestedAtStr = DateFormat('MMM dd, yyyy • h:mm a').format(parsed);
      } catch (_) {
        requestedAtStr = createdAt;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted ? const Color(0xFF007AFF) : cardBorderColor.withValues(alpha: 0.4),
          width: isHighlighted ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isHighlighted ? const Color(0xFF007AFF) : const Color(0xFF0F172A)).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row: Status chip & timestamp ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 13, color: statusColor),
                    const SizedBox(width: 5),
                    Text(
                      statusLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (requestedAtStr.isNotEmpty)
                Text(
                  requestedAtStr,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // ── 3-Step Live Progress Stepper ──
          _buildTrackerStepper(status),
          const SizedBox(height: 14),

          // ── Comparison Banner ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PREVIOUS SCHEDULE',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$oldDate\n$oldTime',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF334155),
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF007AFF), size: 14),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'REQUESTED SCHEDULE',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF007AFF),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$newDate\n$newTime',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF007AFF),
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Reason ──
          Text(
            'Your Reason: $reason',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: const Color(0xFF475569),
            ),
          ),

          // ── Admin Notes (if any) ──
          if (adminNotes != null && adminNotes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: status == 'approved' ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Admin Remark: $adminNotes',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: status == 'approved' ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                ),
              ),
            ),
          ],

          // ── Cancel Button if Pending ──
          if (status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '⏳ Admin will review this shortly.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: const Color(0xFFD97706),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _confirmCancelReschedule(req),
                  icon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFFDC2626)),
                  label: Text(
                    'Cancel Request',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrackerStepper(String status) {
    int currentStep = 1; // 0 = submitted, 1 = under review, 2 = resolved
    if (status == 'approved' || status == 'rejected' || status == 'cancelled') {
      currentStep = 2;
    }

    final isDeclined = status == 'rejected' || status == 'cancelled';

    return Row(
      children: [
        _buildStepIndicator(
          stepNumber: 1,
          title: 'Submitted',
          isActive: true,
          isCompleted: true,
          icon: Icons.send_rounded,
        ),
        Expanded(
          child: Container(
            height: 2,
            color: currentStep >= 1 ? const Color(0xFF007AFF) : const Color(0xFFE2E8F0),
          ),
        ),
        _buildStepIndicator(
          stepNumber: 2,
          title: 'Under Review',
          isActive: currentStep >= 1,
          isCompleted: currentStep >= 2,
          icon: Icons.rate_review_rounded,
        ),
        Expanded(
          child: Container(
            height: 2,
            color: currentStep >= 2
                ? (isDeclined ? const Color(0xFFDC2626) : const Color(0xFF15803D))
                : const Color(0xFFE2E8F0),
          ),
        ),
        _buildStepIndicator(
          stepNumber: 3,
          title: isDeclined ? 'Declined' : (status == 'approved' ? 'Approved' : 'Decision'),
          isActive: currentStep == 2,
          isCompleted: currentStep == 2,
          isError: isDeclined,
          icon: isDeclined
              ? Icons.cancel_rounded
              : (status == 'approved' ? Icons.check_circle_rounded : Icons.pending_actions_rounded),
        ),
      ],
    );
  }

  Widget _buildStepIndicator({
    required int stepNumber,
    required String title,
    required bool isActive,
    required bool isCompleted,
    bool isError = false,
    required IconData icon,
  }) {
    Color color;
    if (isError) {
      color = const Color(0xFFDC2626);
    } else if (isCompleted) {
      color = const Color(0xFF15803D);
    } else if (isActive) {
      color = const Color(0xFF007AFF);
    } else {
      color = const Color(0xFF94A3B8);
    }

    return Column(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  void _confirmCancelReschedule(Map<String, dynamic> req) {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Cancel Reschedule Request?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: Text(
          'Are you sure you want to cancel this reschedule request? Your booking will remain on the original date and time.',
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: Text('Keep Request', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dCtx);
              final success = await _rescheduleService.cancelRescheduleRequest(
                requestId: req['id'].toString(),
                reservationId: req['reservation_id'].toString(),
              );
              if (success) {
                _showSnackBar('Reschedule request cancelled.', Colors.blue);
                _loadCustomerReservations();
              } else {
                _showSnackBar('Failed to cancel request.', Colors.red);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Cancel Request', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  /// Helper to format date for storage



  String _formatDateForStorage(String dateStr) {

    final parts = dateStr.split('/');



    return "${parts[2]}-${parts[0].padLeft(2, '0')}-${parts[1].padLeft(2, '0')}";

  }



  void _showSnackBar(String message, Color color) {

    if (!mounted) return;



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

      ),

    );

  }



  /// Check if customer already has a reservation for the given date





  void _showConfirmationDialog() {

    String date = _dateController.text.trim();

    String startTime = _startTimeController.text.trim();

    String guests = _guestsController.text.trim();



    // Check if required fields are filled

    bool hasRequiredFields = true;



    if (_reservationType == 'Event Place') {

      if (_selectedEventType == null) hasRequiredFields = false;

      if (date.isEmpty) hasRequiredFields = false;

      if (startTime.isEmpty) hasRequiredFields = false;

      if (_selectedBaseDuration == null) hasRequiredFields = false;

      if (guests.isEmpty) hasRequiredFields = false;

      if (_selectedMenuItems.isEmpty) hasRequiredFields = false;

    } else {

      if (date.isEmpty) hasRequiredFields = false;

      if (startTime.isEmpty) hasRequiredFields = false;

      if (_advanceOrderType == 'Dine In' && guests.isEmpty) hasRequiredFields = false;

      if (_selectedMenuItems.isEmpty) hasRequiredFields = false;

    }



    if (!hasRequiredFields) {

      _showSnackBar('Please fill in all required fields', Colors.red);

      return;

    }



    final String title = _reservationType == 'Event Place'

        ? 'Are you sure you want to Confirm Reservation?'

        : 'Are you sure you want to Confirm Advance Order?';



    showDialog(

      context: context,

      builder: (context) => AlertDialog(

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

        title: Row(

          children: [

            Icon(

              Icons.info_outline,

              color: AppTheme.primaryColor,

              size: 28,

            ),

            SizedBox(width: 12),

            Expanded(

              child: Text(

                title,

                style: TextStyle(

                  fontSize: 18,

                  fontWeight: FontWeight.bold,

                  color: Colors.black87,

                ),

              ),

            ),

          ],

        ),

        actions: [

          Container(

            margin: EdgeInsets.only(right: 8),

            child: TextButton(

              onPressed: () => Navigator.of(context).pop(),

              style: TextButton.styleFrom(

                foregroundColor: Colors.grey.shade700,

                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),

                shape: RoundedRectangleBorder(

                  borderRadius: BorderRadius.circular(8),

                  side: BorderSide(color: Colors.grey.shade300),

                ),

              ),

              child: const Text('No', style: TextStyle(fontWeight: FontWeight.w600)),

            ),

          ),

          Container(

            margin: EdgeInsets.only(right: 8),

            child: ElevatedButton(

              onPressed: () {

                Navigator.of(context).pop();

                _submitReservation();

              },

              style: ElevatedButton.styleFrom(

                backgroundColor: AppTheme.primaryColor,

                foregroundColor: Colors.white,

                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),

                shape: RoundedRectangleBorder(

                  borderRadius: BorderRadius.circular(8),

                ),

              ),

              child: const Text('Yes', style: TextStyle(fontWeight: FontWeight.w600)),

            ),

          ),

        ],

      ),

    );

  }



  void _submitReservation() async {

    String date = _dateController.text.trim();



    String startTime = _startTimeController.text.trim();



    String guests = _guestsController.text.trim();



    // Validation

    if (_reservationType == 'Event Place' && _selectedEventType == null) {

      _showSnackBar('Please select an event type', Colors.red);



      return;

    }



    if (date.isEmpty) {

      _showSnackBar('Please select a date', Colors.red);



      return;

    }



    if (startTime.isEmpty) {

      _showSnackBar('Please select a start time', Colors.red);



      return;

    }



    // Safety-net: Validate 40-minutes-ahead rule for same-day Advance Orders
    if (_reservationType == 'Advance Order') {
      try {
        final now = DateTime.now();
        final selectedDate = DateFormat('MMMM d, yyyy').parse(date);
        final isToday = selectedDate.year == now.year &&
            selectedDate.month == now.month &&
            selectedDate.day == now.day;

        if (isToday && startTime.isNotEmpty) {
          // Parse time from format like "7:49 PM"
          final timeParts = startTime.replaceAll(RegExp(r'[^\d:APMapm ]'), '').trim().split(RegExp(r'[\s:]+'));
          if (timeParts.length >= 2) {
            int hour = int.tryParse(timeParts[0]) ?? 0;
            int minute = int.tryParse(timeParts[1]) ?? 0;
            final isPM = startTime.toUpperCase().contains('PM');
            final isAM = startTime.toUpperCase().contains('AM');

            if (isPM && hour != 12) hour += 12;
            if (isAM && hour == 12) hour = 0;

            final selectedDateTime = DateTime(now.year, now.month, now.day, hour, minute);
            final timeDifference = selectedDateTime.difference(now);

            if (timeDifference.inMinutes < 40) {
              final earliestTime = now.add(const Duration(minutes: 40));
              final earliestFormatted = '${earliestTime.hour.toString().padLeft(2, '0')}:${earliestTime.minute.toString().padLeft(2, '0')}';
              _showSnackBar(
                'For same-day orders, please select a time at least 40 minutes from now (earliest: $earliestFormatted)',
                Colors.red,
              );
              return;
            }
          }
        }
      } catch (e) {
        debugPrint('Error validating lead time in submit: $e');
      }
    }



    if (_reservationType == 'Event Place' && _selectedBaseDuration == null) {

      _showSnackBar('Please select a base duration', Colors.red);



      return;

    }



    // Guest Validation

    bool needsGuests = _reservationType == 'Event Place' ||

        (_reservationType == 'Advance Order' && _advanceOrderType == 'Dine In');



    if (needsGuests && guests.isEmpty) {

      _showSnackBar('Please enter the number of guests', Colors.red);



      return;

    }



    int guestCount = needsGuests ? (int.tryParse(guests) ?? 0) : 0;



    if (needsGuests) {

      int min = _reservationType == 'Event Place' ? _minGuestCount : 1;

      int max = _reservationType == 'Event Place' ? 100 : 20;



      if (guestCount < min || guestCount > max) {

        _showSnackBar(

          'Number of guests must be between $min and $max',

          Colors.red,

        );



        return;

      }

    }



    double totalDuration = _reservationType == 'Event Place' 

        ? (double.tryParse(_durationController.text) ?? 0.0)

        : 0.0;



    if (_reservationType == 'Event Place' && totalDuration == 0) {

      _showSnackBar('Invalid duration selected', Colors.red);



      return;

    }



    // Validate menu selection if items are selected



    if (_selectedMenuItems.isNotEmpty) {

      final validation = _menuReservationService.validateMenuSelection(

        _selectedMenuItems,

      );



      if (validation != null) {

        _showSnackBar(validation, Colors.red);



        return;

      }



    }



    String formattedDate;

    try {

      final parsedDate = DateFormat('MMMM d, yyyy').parse(date);

      formattedDate = DateFormat('yyyy-MM-dd').format(parsedDate);

    } catch (e) {

      _showSnackBar('Invalid date format', Colors.red);

      return;

    }



    // Capacity Check

    if (_reservationType == 'Advance Order') {

      try {

        final parsedDate = DateFormat('MMMM d, yyyy').parse(date);

        // We need a full DateTime to check capacity

        // Parsing the startTime text to get hour/minute

        final timeFmt = DateFormat.jm(); // e.g. "10:00 AM"

        final parsedTime = timeFmt.parse(startTime);

        final selectedDateTime = DateTime(

          parsedDate.year,

          parsedDate.month,

          parsedDate.day,

          parsedTime.hour,

          parsedTime.minute,

        );



        setState(() => _isLoading = true);

        final hasCapacity = await _checkCapacity(selectedDateTime);

        setState(() => _isLoading = false);



        if (!hasCapacity) {

          _showSnackBar(

            'Sorry, this time slot is fully booked. Please choose another time.',

            Colors.orange,

          );

          return;

        }

      } catch (e) {

        debugPrint('Error in capacity check: $e');

      }

    }



    // Inventory Check

    if (_reservationType == 'Advance Order') {

      setState(() => _isLoading = true);

      final inventoryError = await _validateInventoryStock();

      setState(() => _isLoading = false);

      if (inventoryError != null) {

        _showSnackBar(inventoryError, Colors.red);

        return;

      }

    }



    // Check for time slot overlap

    setState(() => _isLoading = true);

    bool isOverlapping = await _reservationService.isTimeSlotOverlapping(

      eventDate: formattedDate,

      startTime: startTime,

      durationHours: totalDuration,

    );

    setState(() => _isLoading = false);



    if (isOverlapping) {

      _showSnackBar(

        'This time slot is already booked. Please choose a different time or date.',

        Colors.orange,

      );



      return;

    }



    // Get current user info



    final currentUser = Supabase.instance.client.auth.currentUser;



    if (!mounted) return;



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

      String formattedDate;

      try {

        final parsedDate = DateFormat('MMMM d, yyyy').parse(date);

        formattedDate = DateFormat('yyyy-MM-dd').format(parsedDate);

      } catch (e) {

        throw Exception('Invalid date format');

      }



      // Create record in the appropriate table

      if (_reservationType == 'Advance Order') {

        final totalMenuPrice = _menuReservationService.calculateMenuTotalPrice(

          _selectedMenuItems,

        );



        // Create the advance order

        final response = await _reservationService.createAdvanceOrder(

          customerEmail: currentUser.email ?? '',

          customerName: currentUser.userMetadata?['name'] ?? 

                        currentUser.userMetadata?['full_name'] ?? 

                        'Customer',

          orderType: _advanceOrderType,

          orderDate: formattedDate,

          orderTime: startTime,

          numberOfGuests: _advanceOrderType == 'Dine In' ? guestCount : null,

          selectedMenuItems: _selectedMenuItems,

          totalPrice: totalMenuPrice,

          preparationNotes: _specialRequestsController.text.trim(),

        );



        final String orderId = response['id'].toString();



        if (!mounted) return;



        setState(() {

          _isLoading = false;

        });



        // Show loading indicator

        showDialog(

          context: context,

          barrierDismissible: false,

          builder: (context) => const Center(child: CircularProgressIndicator()),

        );



        try {

          // Create automated PayMongo payment link

          final response = await PayMongoService.createPaymentLink(

            amount: totalMenuPrice,

            description: 'Advance Order Payment',

            metadata: {

              'reservationId': orderId,

              'table': 'advance_orders',

            },

          );



          // Close loading indicator

          if (mounted) Navigator.of(context).pop();



          if (response['success'] == true && response['checkoutUrl'] != null) {

            if (!mounted) return;



            // Navigate immediately to payment confirmation page

            Navigator.of(context, rootNavigator: true).push(

              MaterialPageRoute(

                builder: (context) => PayMongoPaymentPage(

                  paymentUrl: response['checkoutUrl'],

                  paymentLinkId: response['data']?['data']?['id'],

                  reservationId: orderId,

                  paymentAmount: totalMenuPrice,

                  table: 'advance_orders',

                  onPaymentSuccess: () {

                    if (mounted) {

                      setState(() {
                        for (final key in _selectedMenuItems.keys) {
                          _preOrderCart.remove(key);
                        }
                        _selectedMenuItems.clear();

                        _selectedIndex = 0; // Go to home/activity

                      });
                      _saveCartToPrefs();

                      _loadCustomerReservations();

                      _showSuccessDialog(

                        'Advance Order Successfully Paid!\n\n'

                        'Total Price: PHP ${NumberFormat('#,##0.00').format(totalMenuPrice)}\n\n'

                        'Your payment is being reviewed by Admin.',

                      );

                    }

                  },

                ),

              ),

            );

          } else {

            throw response['error'] ?? 'Failed to generate payment link';

          }

        } catch (e) {

          if (mounted) Navigator.of(context).pop();

          _showErrorDialog('Could not start payment: $e');

        }

      } else {

        String finalEventType = _selectedEventType!;



        await _createReservationWithoutPayment(

          currentUser,



          finalEventType,



          formattedDate,



          startTime,



          totalDuration,



          guestCount,



          _specialRequestsController.text.trim(),

        );

      }

    } catch (e) {

      if (!mounted) return;



      setState(() => _isLoading = false);



      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(

          content: Row(

            children: [

              const Icon(Icons.error_outline, color: Colors.white),



              const SizedBox(width: 12),



              Expanded(child: Text('Error: ${e.toString()}')),

            ],

          ),



          backgroundColor: Colors.red,



          behavior: SnackBarBehavior.floating,

        ),

      );

    }

  }



  Widget _buildQuotationsSection() {
    final quotations = customerReservations.where((reservation) {
      return reservation['price_quotation_sent'] == true &&
          reservation['admin_set_price'] == true &&
          reservation['total_price'] != null &&
          reservation['total_price'] > 0;
    }).toList();

    if (quotations.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF14332E), Color(0xFF1E4A42)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF14332E).withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  size: 38,
                  color: Color(0xFFD9A441),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'No Price Transactions Yet',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Official price quotations and payment statements from admin will appear here.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final double totalTransactionsValue = quotations.fold<double>(
      0.0,
      (sum, q) => sum + ((q['total_price'] ?? 0.0) as num).toDouble(),
    );

    final double totalPaidValue = quotations.fold<double>(
      0.0,
      (sum, q) {
        final status = q['payment_status']?.toString().toLowerCase() ?? '';
        final isFullyPaid = status == 'paid' || status == 'fully_paid';
        final isDepositPaid = status == 'deposit_paid';
        if (isFullyPaid) {
          return sum + ((q['total_price'] ?? 0.0) as num).toDouble();
        } else if (isDepositPaid) {
          return sum + ((q['deposit_amount'] ?? 0.0) as num).toDouble();
        }
        return sum;
      },
    );

    final int pendingActionCount = quotations.where((q) => _reservationService.needsDepositPayment(q)).length;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Executive Treasury / Transaction Overview Card (Petty Cash Style) ────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF0C241F),
                    Color(0xFF14332E),
                    Color(0xFF1B453D),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppTheme.warmGold.withValues(alpha: 0.35),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0A1C18).withValues(alpha: 0.45),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: AppTheme.warmGold.withValues(alpha: 0.08),
                    blurRadius: 30,
                    spreadRadius: -2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Title + Status Pill
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet_rounded,
                                color: Color(0xFFD9A441),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PAYMENT STATEMENT',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFFD9A441),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Financial Ledger & Quotes',
                                    style: GoogleFonts.inter(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF34C759).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF34C759).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF34C759),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${quotations.length} RECORDS',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF86EFAC),
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Big Currency Display
                  Text(
                    'TOTAL TRANSACTIONS VALUE',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF94A3B8),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '₱',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFD9A441),
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _fmt.format(totalTransactionsValue),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Sub-metrics Bar (Petty Cash Style)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF34C759),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Settled / Paid',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF94A3B8),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      '₱${_fmt.format(totalPaidValue)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 24,
                          color: Colors.white.withValues(alpha: 0.12),
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                pendingActionCount > 0 ? Icons.pending_actions_rounded : Icons.verified_rounded,
                                color: pendingActionCount > 0 ? const Color(0xFFFF9500) : const Color(0xFF34C759),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Action Required',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF94A3B8),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      pendingActionCount > 0 ? '$pendingActionCount Pending' : 'All Clear',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        color: pendingActionCount > 0 ? const Color(0xFFFFB84D) : const Color(0xFF86EFAC),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // ── Section Title ────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9A441),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Transaction Records',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            ...quotations.map((reservation) => _buildQuotationCard(reservation)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuotationCard(Map<String, dynamic> reservation) {
    final totalPrice = (reservation['total_price'] ?? 0.0) as double;
    final depositAmount = (reservation['deposit_amount'] ?? 0.0) as double;
    final paymentStatus = reservation['payment_status'] as String? ?? 'unpaid';

    final isPayInFull = reservation['_db_table'] == 'advance_orders' ||
        reservation['payment_option'] == 'full' ||
        (totalPrice > 0 && depositAmount >= totalPrice);

    final needsDepositPayment = _reservationService.needsDepositPayment(
      reservation,
    );

    final isUnpaidOrDue = paymentStatus == 'unpaid' || paymentStatus == 'pending' || needsDepositPayment;
    final isDepositPaid = paymentStatus == 'deposit_paid';
    final isFullyPaid = paymentStatus == 'paid' || paymentStatus == 'fully_paid';

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUnpaidOrDue
              ? const Color(0xFFD9A441).withValues(alpha: 0.5)
              : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Voucher Receipt Header (Petty Cash Style) ───────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF14332E),
                    Color(0xFF1E4A42),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Color(0xFFD9A441),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Price Transaction',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          reservation['event_type'] ?? (reservation['_db_table'] == 'advance_orders' ? 'Advance Order' : 'Reservation'),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Status Badge Pill (Petty Cash Style)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: isFullyPaid
                          ? const Color(0xFF34C759).withValues(alpha: 0.2)
                          : isDepositPaid
                              ? const Color(0xFF007AFF).withValues(alpha: 0.2)
                              : const Color(0xFFD9A441).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isFullyPaid
                            ? const Color(0xFF34C759).withValues(alpha: 0.45)
                            : isDepositPaid
                                ? const Color(0xFF007AFF).withValues(alpha: 0.45)
                                : const Color(0xFFD9A441).withValues(alpha: 0.6),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isFullyPaid
                                ? const Color(0xFF34C759)
                                : isDepositPaid
                                    ? const Color(0xFF38BDF8)
                                    : const Color(0xFFD9A441),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _getPaymentStatusText(
                            paymentStatus,
                            true,
                            isAdvanceOrder: reservation['_db_table'] == 'advance_orders',
                            isPayInFull: isPayInFull,
                          ),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: isFullyPaid
                                ? const Color(0xFF86EFAC)
                                : isDepositPaid
                                    ? const Color(0xFFBAE6FD)
                                    : const Color(0xFFFDE68A),
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Event Details Grid ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        _buildQuotationDetailRow(
                          'Date',
                          reservation['event_date'] ?? reservation['order_date'] ?? 'N/A',
                          Icons.calendar_today_rounded,
                        ),
                        const SizedBox(height: 6),
                        _buildQuotationDetailRow(
                          'Time',
                          '${reservation['start_time'] ?? reservation['pickup_time'] ?? 'N/A'} ${reservation['duration_hours'] != null ? '(${reservation['duration_hours']}h)' : ''}',
                          Icons.access_time_rounded,
                        ),
                        if (reservation['number_of_guests'] != null) ...[
                          const SizedBox(height: 6),
                          _buildQuotationDetailRow(
                            'Guests',
                            '${reservation['number_of_guests']} people',
                            Icons.people_alt_rounded,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ── Itemized Menu Items ──────────────────────────────────────────
                  if (reservation['selected_menu_items'] != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.restaurant_menu_rounded,
                                color: Color(0xFF14332E),
                                size: 15,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Menu Items',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ..._buildMenuItemsList(
                            reservation['selected_menu_items'],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // ── Financial Statement Box (Petty Cash Style) ───────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14332E).withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF14332E).withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.payments_rounded,
                              color: Color(0xFF14332E),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Pricing Breakdown',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF14332E),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildPricingRow('Total Price', totalPrice, const Color(0xFF0F172A)),
                        if (!isPayInFull) ...[
                          const SizedBox(height: 5),
                          _buildPricingRow(
                            'Deposit (50%)',
                            depositAmount,
                            const Color(0xFF14332E),
                          ),
                          const SizedBox(height: 5),
                          _buildPricingRow(
                            'Remaining Balance',
                            totalPrice - depositAmount,
                            const Color(0xFF64748B),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Actions & Status Pill Callouts ──────────────────────────────
                  if (needsDepositPayment)
                    AnimatedTapScale(
                      onTap: () => _showPaymentDialog(reservation),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: AppTheme.goldGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.warmGold.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.payment_rounded, color: AppTheme.darkBrownText, size: 17),
                            const SizedBox(width: 8),
                            Text(
                              isPayInFull
                                  ? 'Pay Full Amount (₱${_fmt.format(depositAmount)})'
                                  : 'Pay Deposit (₱${_fmt.format(depositAmount)})',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.darkBrownText,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (paymentStatus == 'deposit_paid')
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF007AFF).withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.pending_actions_rounded, color: Color(0xFF007AFF), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              reservation['_db_table'] == 'advance_orders'
                                  ? 'Full payment received! Awaiting admin verification.'
                                  : 'Deposit paid! Awaiting admin verification.',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF007AFF),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (reservation['status'] == 'pending_admin_approval')
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9500).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFF9500).withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.hourglass_top_rounded, color: Color(0xFFFF9500), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Payment submitted! Awaiting admin approval.',
                              style: GoogleFonts.inter(
                                color: const Color(0xFFD97706),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (reservation['status'] == 'confirmed')
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF34C759).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF34C759).withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF34C759), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Reservation & payment confirmed!',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF16A34A),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuotationDetailRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: AppTheme.forestGreen),
        const SizedBox(width: 8),
        Flexible(
          flex: 2,
          child: Text(
            '$label: ',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.mediumGrey,
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkGrey,
            ),
          ),
        ),
      ],
    );
  }

  double? _getMenuItemPrice(String menuName) {
    final menu = MenuService.getMenu();
    for (var category in menu.values) {
      for (var item in category) {
        if (item.name == menuName) {
          return item.price;
        }
      }
    }
    return null;
  }

  List<Widget> _buildMenuItemsList(Map<String, dynamic> selectedMenuItems) {
    if (selectedMenuItems.isEmpty) {
      return [
        Text(
          'No menu items selected',
          style: GoogleFonts.inter(color: AppTheme.mediumGrey, fontStyle: FontStyle.italic, fontSize: 12),
        ),
      ];
    }

    final menuItems = <Widget>[];
    final items = selectedMenuItems;

    items.forEach((menuName, quantity) {
      final qty = quantity is int
          ? quantity
          : int.tryParse(quantity.toString()) ?? 0;
      if (qty > 0) {
        final price = _getMenuItemPrice(menuName);
        final totalPrice = price != null ? price * qty : 0.0;

        menuItems.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.warmGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${qty}x',
                          style: GoogleFonts.inter(
                            color: AppTheme.darkBrownText,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          menuName,
                          style: GoogleFonts.inter(
                            color: AppTheme.darkGrey,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (price != null)
                  Text(
                    '₱${_fmt.format(totalPrice)}',
                    style: GoogleFonts.inter(
                      color: AppTheme.darkGrey,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        );
      }
    });

    return menuItems;
  }

  Widget _buildPricingRow(String label, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkGrey.withValues(alpha: 0.75),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'PHP ${_fmt.format(amount)}',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }



  void _updateDurationText() {

    if (_selectedBaseDuration == null) {

      _durationController.text = '';



      return;

    }



    double total = double.parse(_selectedBaseDuration!.split(' ')[0]);



    if (_addExtraTime && _selectedExtraTime != null) {

      if (_selectedExtraTime == '30 minutes') {

        total += 0.5;

      } else {

        total += double.parse(_selectedExtraTime!.split(' ')[0]);

      }

    }



    _durationController.text = total.toString();

  }



  void _showLogoutDialog() {

    showDialog(

      context: context,



      barrierDismissible: false,



      builder: (dialogContext) => AlertDialog(

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),



        title: const Row(

          children: [

            Icon(Icons.logout, color: AppTheme.primaryColor),



            SizedBox(width: 12),



            Text('Logout'),

          ],

        ),



        content: const Text(

          'Are you sure you want to logout?',



          style: TextStyle(fontSize: 16),

        ),



        actions: [

          TextButton(

            onPressed: () => Navigator.pop(dialogContext),



            child: const Text('Cancel'),

          ),



          ElevatedButton(

            style: ElevatedButton.styleFrom(

              backgroundColor: AppTheme.primaryColor,



              foregroundColor: Colors.white,

            ),



            onPressed: () async {

              Navigator.pop(dialogContext);



              // Sign out from Supabase



              await Supabase.instance.client.auth.signOut();



              // Also sign out from Google to allow account switching



              try {

                await _googleSignIn.signOut();

              } catch (e) {

                debugPrint('Error signing out from Google: $e');

              }



              if (mounted) {

                Navigator.of(context).pushNamedAndRemoveUntil(

                  '/login',



                  (route) => false,

                );

              }

            },



            child: const Text('Logout'),

          ),

        ],

      ),

    );

  }



  // ── Cart helpers (UI lives in customer_order_list.dart) ────────────────────



  Widget _buildCartIcon() {

    return buildCartIcon(

      selectedMenuItems: _preOrderCart,

      onPressed: _showOrderListModal,

    );

  }



  void _proceedDirectlyToReservation(
    Map<String, int> selectedSubset,
    String reservationType,
    String advanceOrderType,
    String date,
    String time,
  ) {
    setState(() {
      _selectedMenuItems = Map<String, int>.from(selectedSubset);
      _reservationType = reservationType;
      _advanceOrderType = advanceOrderType;
      _dateController.text = date;
      _startTimeController.text = time;
      _selectedIndex = 1; // switch to Reservation tab
    });
  }

  void _showOrderListModal() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerOrderListPage(
          selectedMenuItems: _preOrderCart,
          onProceed: _proceedDirectlyToReservation,
          onCartUpdated: _handleCartUpdated,
        ),
      ),
    );
  }



  void _showMenuItemDetailsDialog(MenuItem item) {

    showMenuItemSheet(

      context: context,

      item: item,

      selectedMenuItems: _preOrderCart,

      onAdded: () => setState(() {}),

      onCartUpdated: _handleCartUpdated,

    );

  }

}



class _StickyCategoryNavBarDelegate extends SliverPersistentHeaderDelegate {

  final Widget child;



  _StickyCategoryNavBarDelegate({required this.child});



  @override

  double get minExtent => 66.0;



  @override

  double get maxExtent => 66.0;



  @override

  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {

    return child;

  }



  @override

  bool shouldRebuild(covariant _StickyCategoryNavBarDelegate oldDelegate) {

    return oldDelegate.child != child;

  }

}


