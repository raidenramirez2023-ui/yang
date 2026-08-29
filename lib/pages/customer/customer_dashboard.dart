import 'dart:async';

import 'dart:ui';



import 'package:flutter/material.dart';



import 'package:flutter/services.dart';



import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:image_picker/image_picker.dart';



import 'package:google_sign_in/google_sign_in.dart';

import 'package:google_fonts/google_fonts.dart';

import 'package:qr_flutter/qr_flutter.dart';

import 'package:yang_chow/services/receipt_pdf_service.dart';

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';



import 'package:yang_chow/utils/app_theme.dart';



import 'package:yang_chow/utils/app_constants.dart';

import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yang_chow/services/paymongo_service.dart';
import 'package:yang_chow/pages/customer/edit_profile_page.dart';

import 'package:yang_chow/widgets/customer_chat_modal.dart';

import 'package:yang_chow/pages/customer/customer_reviews_page.dart';

import 'package:yang_chow/pages/customer/menu_selection_page.dart';

import 'package:yang_chow/pages/customer/customer_order_list.dart';



import 'package:yang_chow/pages/customer/transactions_page.dart';

import 'package:yang_chow/pages/customer/paymongo_payment_page.dart';

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
import 'package:yang_chow/utils/url_sync_helper.dart';

class CustomerDashboardPage extends StatefulWidget {
  final int initialIndex;

  const CustomerDashboardPage({super.key, this.initialIndex = 0});

  @override
  State<CustomerDashboardPage> createState() => _CustomerDashboardPageState();
}

class _CustomerDashboardPageState extends State<CustomerDashboardPage> with TickerProviderStateMixin {
  final NumberFormat _fmt = NumberFormat('#,##0.00', 'en_US');

  late int _selectedIndex;
  void Function()? _cancelPopState;

  static const List<String> _tabUrls = [
    '/customer/dashboard',
    '/customer/reservations',
    '/customer/transactions',
    '/customer/activity',
    '/customer/order-list',
    '/customer/profile',
  ];

  void _syncUrl() {
    if (_selectedIndex >= 0 && _selectedIndex < _tabUrls.length) {
      UrlSyncHelper.updateUrl(_tabUrls[_selectedIndex]);
    }
  }

  void _onSelectTab(int index) {
    setState(() => _selectedIndex = index);
    _syncUrl();
  }

  bool _isLoading = false;

  // Sidebar toggle for desktop & tablet
  bool _isSidebarOpen = true; // desktop starts open; tablet starts closed handled in _buildTabletLayout

  late AnimationController _sidebarAnimController;

  late Animation<Offset> _sidebarSlideAnim;



  final ReservationService _reservationService = ReservationService();
  final RescheduleService _rescheduleService = RescheduleService();



  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // NOTE: Do NOT set clientId for Android — it's read automatically from google-services.json.
    // Setting a clientId (especially iOS) on Android causes DEVELOPER_ERROR (code 10).
    clientId: kIsWeb
        ? '58922100698-ajm1bssqvgoo9k0qs15hd3g7nhrqabm4.apps.googleusercontent.com' // Web Client ID only
        : null, // Android: must be null — handled by google-services.json
    serverClientId: kIsWeb
        ? null
        : '58922100698-ajm1bssqvgoo9k0qs15hd3g7nhrqabm4.apps.googleusercontent.com', // Web Client ID - required for idToken on Android
  );



  List<Map<String, dynamic>> customerReservations = [];
  String _activityFilter = 'all'; // 'all', 'in_progress', 'confirmed'

  bool _isEligibleForReview = false;

  Map<String, dynamic>? _customerReview;



  Stream<List<Map<String, dynamic>>>? _notificationsStream;
  StreamSubscription<List<Map<String, dynamic>>>? _customerNotifsSubscription;

  // ── Featured Dishes (Realtime) ──
  StreamSubscription<List<Map<String, dynamic>>>? _featuredOrdersSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _rescheduleRequestsSubscription;
  RealtimeChannel? _customerReservationsRealtimeChannel;
  List<Map<String, dynamic>> _featuredDishes = [];
  bool _featuredLoading = true;



  // ── Top Toast Notification Overlay ──
  OverlayEntry? _currentTopToastEntry;
  Timer? _topToastTimer;
  final Set<String> _shownToastCustomerNotificationIds = {};

  void _dismissTopToast() {
    _topToastTimer?.cancel();
    _topToastTimer = null;
    _currentTopToastEntry?.remove();
    _currentTopToastEntry = null;
  }

  void _showTopToast({
    required Widget content,
    Duration? duration,
  }) {
    if (!mounted) return;
    _dismissTopToast();

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _TopToastWidget(
        onDismiss: () {
          if (_currentTopToastEntry == entry) {
            _dismissTopToast();
          }
        },
        duration: duration,
        child: content,
      ),
    );

    _currentTopToastEntry = entry;
    overlay.insert(entry);

    if (duration != null) {
      _topToastTimer = Timer(duration, () {
        if (_currentTopToastEntry == entry) {
          _dismissTopToast();
        }
      });
    }
  }

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
  String? _savedAccountValidIdUrl;
  bool _hasSavedValidId = false;



  // --- Category Scroll State ---
  final ScrollController _categoryScrollController = ScrollController();
  bool _canScrollCategoryLeft = false;
  bool _canScrollCategoryRight = true;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _syncUrl();
    _cancelPopState = UrlSyncHelper.listenPopState((path) {
      final idx = _tabUrls.indexOf(path);
      if (idx != -1 && idx != _selectedIndex && mounted) {
        setState(() => _selectedIndex = idx);
      }
    });

    _scrollController = ScrollController()..addListener(_onMenuScroll);
    _categoryScrollController.addListener(_categoryScrollListener);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkCategoryScroll();
    });

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
          final latest = unreadNotifs.first;
          final id = latest['id']?.toString();
          if (id != null && !_shownToastCustomerNotificationIds.contains(id)) {
            _shownToastCustomerNotificationIds.add(id);
            _showNotificationToast(latest);
          }
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

      _customerReservationsRealtimeChannel = Supabase.instance.client
          .channel('customer_reservations_status_changes')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'reservations',
            callback: (_) {
              if (mounted) _loadCustomerReservations();
            },
          )
          .subscribe();
    }

    // Load customer reservations and reliability status immediately on startup
    _loadCustomerReservations();
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
            .or('customer_email.eq.$email,customer_email.eq.$lowerEmail')
            .order('created_at', ascending: false),
        Supabase.instance.client
            .from('advance_orders')
            .select('*')
            .or('customer_email.eq.$email,customer_email.eq.$lowerEmail')
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

      // Find the most recent Valid ID uploaded by this customer account
      String? savedIdUrl;
      for (final r in List<Map<String, dynamic>>.from(results[0])) {
        final idUrl = r['uploaded_id_url']?.toString();
        if (idUrl != null && idUrl.isNotEmpty && idUrl != 'null') {
          savedIdUrl = idUrl;
          break;
        }
      }

      if (mounted) {
        setState(() {
          customerReservations = combined;
          if (savedIdUrl != null && savedIdUrl.isNotEmpty) {
            _savedAccountValidIdUrl = savedIdUrl;
            _hasSavedValidId = true;
            _uploadedIdUrl ??= savedIdUrl;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading customer records: $e');
    }
  }



  void _categoryScrollListener() {
    _checkCategoryScroll();
  }

  void _checkCategoryScroll() {
    if (!_categoryScrollController.hasClients) return;
    final position = _categoryScrollController.position;
    final atLeft = position.pixels <= 0;
    final atRight = position.pixels >= position.maxScrollExtent;
    bool newCanScrollLeft = !atLeft;
    bool newCanScrollRight = !atRight;
    if (position.maxScrollExtent == 0) {
      newCanScrollLeft = false;
      newCanScrollRight = false;
    }
    if (_canScrollCategoryLeft != newCanScrollLeft || _canScrollCategoryRight != newCanScrollRight) {
      if (mounted) {
        setState(() {
          _canScrollCategoryLeft = newCanScrollLeft;
          _canScrollCategoryRight = newCanScrollRight;
        });
      }
    }
  }

  @override
  void dispose() {
    _cancelPopState?.call();
    _categoryScrollController.dispose();
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
    _customerReservationsRealtimeChannel?.unsubscribe();
    _dismissTopToast();

    super.dispose();

  }



  void _onMenuScroll() {

    if (_isScrollingToCategory) return;

    // Use a responsive threshold: mobile has a shorter header/nav so we need
    // a smaller value, otherwise the first category snaps active on any upward scroll.
    final isMobile = MediaQuery.of(context).size.width < 768;
    final threshold = isMobile ? 120.0 : 200.0;

    for (var i = MenuService.categories.length - 1; i >= 0; i--) {

      final category = MenuService.categories[i];

      final key = _categoryKeys[category];

      if (key?.currentContext != null) {

        final box = key!.currentContext!.findRenderObject() as RenderBox?;

        if (box != null) {

          final position = box.localToGlobal(Offset.zero).dy;

          if (position <= threshold) {

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

    void openBellDialog() {
      _dismissTopToast();
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser?.email != null) {
        NotificationService.getCustomerAdminNotificationsStream(
          currentUser!.email!,
        ).first.then((notifs) {
          if (mounted) _showNotificationsDialog(notifs);
        });
      }
    }

    // FIXED at top: will NEVER disappear until Customer clicks 'VIEW'
    _showTopToast(
      duration: null,
      content: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: openBellDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFD9A441),
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD9A441).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.75),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
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
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: const Color(0xFFCBD5E1),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    backgroundColor: AppTheme.warmGold,
                    foregroundColor: const Color(0xFF0F172A),
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 15, color: Color(0xFF0F172A)),
                  label: Text(
                    'VIEW',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w900,
                      fontSize: 11.5,
                      letterSpacing: 0.5,
                    ),
                  ),
                  onPressed: openBellDialog,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }



  void _showNotificationsDialog(List<Map<String, dynamic>> notifications) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser?.email != null) {
      NotificationService.markAllAsRead(currentUser!.email!);
    }

    if (notifications.isNotEmpty) {
      final unreadIds = notifications
          .where((n) => n['is_read'] == false)
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

                      case 'balance_payment_link':

                        icon = Icons.payment_rounded;

                        color = const Color(0xFF0EA5E9);

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



                    String? checkoutUrl;
                    if (n['event_type'] != null && n['event_type'].toString().contains('http')) {
                      final match = RegExp(r'https?://[^\s]+').firstMatch(n['event_type'].toString());
                      if (match != null) {
                        checkoutUrl = match.group(0);
                      }
                    }

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      onTap: checkoutUrl != null
                          ? () async {
                              final uri = Uri.parse(checkoutUrl!);
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          : null,
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
                      trailing: checkoutUrl != null
                          ? ElevatedButton.icon(
                              onPressed: () async {
                                final uri = Uri.parse(checkoutUrl!);
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              },
                              icon: const Icon(Icons.payment_rounded, size: 13),
                              label: const Text('Pay', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0EA5E9),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            )
                          : null,
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

      case 'balance_payment_link':

        return 'Remaining Balance Payment Link';



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

                Expanded(

                  child: Column(

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

                ),



                // Burger Menu button to collapse/hide sidebar

                Tooltip(

                  message: 'Hide menu',

                  child: Material(

                    color: Colors.transparent,

                    child: InkWell(

                      borderRadius: BorderRadius.circular(8),

                      hoverColor: Colors.white.withValues(alpha: 0.12),

                      onTap: () {

                        HapticFeedback.lightImpact();

                        _sidebarAnimController.reverse();

                        setState(() => _isSidebarOpen = false);

                      },

                      child: Container(

                        padding: const EdgeInsets.all(7),

                        decoration: BoxDecoration(

                          color: AppTheme.sidebarDivider.withValues(alpha: 0.45),

                          borderRadius: BorderRadius.circular(8),

                          border: Border.all(

                            color: AppTheme.sidebarDivider.withValues(alpha: 0.8),

                            width: 1,

                          ),

                        ),

                        child: const Icon(

                          Icons.menu_rounded,

                          color: Colors.white,

                          size: 20,

                        ),

                      ),

                    ),

                  ),

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

                  _onSelectTab(index);
                  if (closeable) {
                    setState(() {
                      _isSidebarOpen = false;
                      _sidebarAnimController.reverse();
                    });
                  }

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

                      Tooltip(

                        message: 'Menu',

                        child: Material(

                          color: Colors.transparent,

                          child: InkWell(

                            borderRadius: BorderRadius.circular(8),

                            hoverColor: Colors.white.withValues(alpha: 0.12),

                            onTap: () {

                              HapticFeedback.lightImpact();

                              setState(() => _isSidebarOpen = true);

                              _sidebarAnimController.forward();

                            },

                            child: Container(

                              padding: const EdgeInsets.all(7),

                              decoration: BoxDecoration(

                                color: Colors.white.withValues(alpha: 0.12),

                                borderRadius: BorderRadius.circular(8),

                                border: Border.all(

                                  color: Colors.white.withValues(alpha: 0.2),

                                  width: 1,

                                ),

                              ),

                              child: const Icon(

                                Icons.menu_rounded,

                                color: Colors.white,

                                size: 20,

                              ),

                            ),

                          ),

                        ),

                      ),

                      const SizedBox(width: 8),

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

                      // Burger Menu button to open/display sidebar

                      if (!_isSidebarOpen) ...[

                        Tooltip(

                          message: 'Show menu',

                          child: Material(

                            color: Colors.transparent,

                            child: InkWell(

                              borderRadius: BorderRadius.circular(8),

                              hoverColor: Colors.white.withValues(alpha: 0.12),

                              onTap: () {

                                HapticFeedback.lightImpact();

                                setState(() => _isSidebarOpen = true);

                                _sidebarAnimController.forward();

                              },

                              child: Container(

                                padding: const EdgeInsets.all(7),

                                decoration: BoxDecoration(

                                  color: Colors.white.withValues(alpha: 0.12),

                                  borderRadius: BorderRadius.circular(8),

                                  border: Border.all(

                                    color: Colors.white.withValues(alpha: 0.2),

                                    width: 1,

                                  ),

                                ),

                                child: const Icon(

                                  Icons.menu_rounded,

                                  color: Colors.white,

                                  size: 20,

                                ),

                              ),

                            ),

                          ),

                        ),

                        const SizedBox(width: 8),

                      ],

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

        _onSelectTab(index);

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
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.goldGradient : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? AppTheme.warmGold : AppTheme.cardBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.warmGold.withValues(alpha: 0.38),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.25) : AppTheme.backgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 16,
                color: isSelected ? AppTheme.darkBrownText : AppTheme.forestGreen,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: isSelected ? AppTheme.darkBrownText : AppTheme.darkGrey,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 13,
                letterSpacing: -0.1,
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

  Widget _buildCustomerReliabilityBadge() {
    final noShows = customerReservations.where((r) {
      final s = (r['status'] ?? '').toString().toLowerCase().replaceAll('-', '_');
      return s == 'no_show';
    }).length;
    final completed = customerReservations.where((r) {
      final s = (r['status'] ?? '').toString().toLowerCase();
      return s == 'completed';
    }).length;

    if (noShows >= 2) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFDC2626).withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 13, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              'HIGH-RISK ACCOUNT ($noShows NO-SHOWS)',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      );
    } else if (noShows == 1) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFEA580C),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEA580C).withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline_rounded, size: 13, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              '1 NO-SHOW RECORDED',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      );
    } else if (completed > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF15803D),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF15803D).withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_user_rounded, size: 13, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              'RELIABLE CUSTOMER',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
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
                                  Container(
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
                                  const SizedBox(width: 8),
                                  _buildCustomerReliabilityBadge(),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final horizontalPadding = isSmallScreen ? 12.0 : 16.0;
    final cardPadding = isSmallScreen ? 14.0 : 20.0;

    final hasDate = _dateController.text.trim().isNotEmpty;
    final hasTime = _startTimeController.text.trim().isNotEmpty;
    final menuItemsCount = _selectedMenuItems.values.fold(0, (sum, qty) => sum + qty);
    final menuSubtotal = _menuReservationService.calculateMenuTotalPrice(_selectedMenuItems);
    final depositRequired = _paymentOption == 'full' && _reservationType == 'Event Place'
        ? menuSubtotal
        : _menuReservationService.calculateMenuDepositAmount(menuSubtotal, reservationType: _reservationType);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Clean Header ───────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 4,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: AppTheme.goldGradient,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _reservationType == 'Event Place' ? 'Event Hall Reservation' : 'Advance Food Order',
                        style: GoogleFonts.lora(
                          fontSize: isSmallScreen ? 19 : 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.darkGrey,
                        ),
                      ),
                      Text(
                        _reservationType == 'Event Place'
                            ? 'Book private halls for gatherings and banquets'
                            : 'Order in advance for zero wait time',
                        style: GoogleFonts.inter(
                          fontSize: isSmallScreen ? 12 : 13,
                          color: AppTheme.mediumGrey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Mode Switcher ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedTapScale(
                      onTap: () => setState(() => _reservationType = 'Event Place'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          gradient: _reservationType == 'Event Place' ? AppTheme.goldGradient : null,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _reservationType == 'Event Place'
                              ? [
                                  BoxShadow(
                                    color: AppTheme.warmGold.withValues(alpha: 0.3),
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
                              size: 16,
                              color: _reservationType == 'Event Place' ? AppTheme.darkBrownText : AppTheme.mediumGrey,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Event Place',
                                style: GoogleFonts.inter(
                                  color: _reservationType == 'Event Place' ? AppTheme.darkBrownText : AppTheme.darkGrey,
                                  fontWeight: _reservationType == 'Event Place' ? FontWeight.w800 : FontWeight.w600,
                                  fontSize: isSmallScreen ? 12 : 13,
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
                  Expanded(
                    child: AnimatedTapScale(
                      onTap: () => setState(() => _reservationType = 'Advance Order'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          gradient: _reservationType == 'Advance Order' ? AppTheme.goldGradient : null,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _reservationType == 'Advance Order'
                              ? [
                                  BoxShadow(
                                    color: AppTheme.warmGold.withValues(alpha: 0.3),
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
                              Icons.restaurant_rounded,
                              size: 16,
                              color: _reservationType == 'Advance Order' ? AppTheme.darkBrownText : AppTheme.mediumGrey,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Advance Order',
                                style: GoogleFonts.inter(
                                  color: _reservationType == 'Advance Order' ? AppTheme.darkBrownText : AppTheme.darkGrey,
                                  fontWeight: _reservationType == 'Advance Order' ? FontWeight.w800 : FontWeight.w600,
                                  fontSize: isSmallScreen ? 12 : 13,
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
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Sub-selection for Advance Order (Dine In / Pick Up)
            if (_reservationType == 'Advance Order') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSubSelectionButton('Dine In', Icons.restaurant_rounded),
                  const SizedBox(width: 12),
                  _buildSubSelectionButton('Pick Up', Icons.shopping_bag_rounded),
                ],
              ),
              const SizedBox(height: 14),
            ],

            // ── Clean Form Card ────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppTheme.cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(cardPadding),
                child: Form(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeInOutCubic,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Event Type (Event Place Only)
                        if (_reservationType == 'Event Place') ...[
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
                          const SizedBox(height: 18),
                        ],

                        // Date & Time Adaptive Layout
                        _buildFormLabel('DATE & TIME'),
                        const SizedBox(height: 8),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final stackVertically = constraints.maxWidth < 310;

                            final dateTile = AnimatedTapScale(
                              onTap: () async {
                                final minDate = _reservationType == 'Advance Order'
                                    ? DateTime.now()
                                    : DateTime.now().add(const Duration(days: 4));

                                Set<String> fullyBookedDates = {};
                                if (_reservationType == 'Event Place') {
                                  fullyBookedDates = await _reservationService.getFullyBookedEventDates();
                                }

                                DateTime initialDate = minDate;
                                while (fullyBookedDates.contains(DateFormat('yyyy-MM-dd').format(initialDate))) {
                                  initialDate = initialDate.add(const Duration(days: 1));
                                }

                                DateTime? pickedDate = await showDatePicker(
                                  context: context,
                                  initialDate: initialDate,
                                  firstDate: minDate,
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                  selectableDayPredicate: (DateTime day) {
                                    if (_reservationType == 'Event Place') {
                                      final dateStr = DateFormat('yyyy-MM-dd').format(day);
                                      if (fullyBookedDates.contains(dateStr)) {
                                        return false;
                                      }
                                    }
                                    return true;
                                  },
                                );

                                if (pickedDate != null) {
                                  setState(() {
                                    _dateController.text = DateFormat('MMMM d, yyyy').format(pickedDate);
                                  });

                                  if (_reservationType == 'Event Place' && _startTimeController.text.isNotEmpty) {
                                    final duration = double.tryParse(_durationController.text) ?? 2.0;
                                    final dateStr = DateFormat('yyyy-MM-dd').format(pickedDate);
                                    final isOverlapping = await _reservationService.isTimeSlotOverlapping(
                                      eventDate: dateStr,
                                      startTime: _startTimeController.text.trim(),
                                      durationHours: duration,
                                    );
                                    if (isOverlapping && mounted) {
                                      _showSnackBar(
                                        'The selected time (${_startTimeController.text}) on ${DateFormat('MMMM d').format(pickedDate)} is already booked. Please pick another time.',
                                        Colors.orange,
                                      );
                                      setState(() {
                                        _startTimeController.clear();
                                      });
                                    }
                                  }
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: hasDate ? AppTheme.warmGold : AppTheme.cardBorder,
                                    width: hasDate ? 1.4 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_month_rounded,
                                      size: 18,
                                      color: hasDate ? AppTheme.primaryColor : AppTheme.mediumGrey,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Date',
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.mediumGrey,
                                            ),
                                          ),
                                          Text(
                                            hasDate ? _dateController.text : 'Select date',
                                            style: GoogleFonts.inter(
                                              fontSize: isSmallScreen ? 12 : 13,
                                              fontWeight: hasDate ? FontWeight.w700 : FontWeight.w500,
                                              color: hasDate ? AppTheme.darkGrey : AppTheme.mediumGrey,
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
                            );

                            final timeTile = AnimatedTapScale(
                              onTap: () async {
                                final startHour = _reservationType == 'Advance Order' ? 10 : _operatingHoursStart;
                                final endHour = _reservationType == 'Advance Order' ? 19 : _operatingHoursEnd;

                                final TimeOfDay? pickedTime = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay(hour: startHour, minute: 0),
                                );

                                if (pickedTime != null) {
                                  _handleTimeSelection(pickedTime, startHour, endHour);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: hasTime ? AppTheme.warmGold : AppTheme.cardBorder,
                                    width: hasTime ? 1.4 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.access_time_filled_rounded,
                                      size: 18,
                                      color: hasTime ? AppTheme.primaryColor : AppTheme.mediumGrey,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Time',
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.mediumGrey,
                                            ),
                                          ),
                                          Text(
                                            hasTime ? _startTimeController.text : '-- : --',
                                            style: GoogleFonts.inter(
                                              fontSize: isSmallScreen ? 12 : 13,
                                              fontWeight: hasTime ? FontWeight.w700 : FontWeight.w500,
                                              color: hasTime ? AppTheme.darkGrey : AppTheme.mediumGrey,
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
                            );

                            if (stackVertically) {
                              return Column(
                                children: [
                                  dateTile,
                                  const SizedBox(height: 10),
                                  timeTile,
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(child: dateTile),
                                const SizedBox(width: 10),
                                Expanded(child: timeTile),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 18),

                        // Duration (Event Place Only)
                        if (_reservationType == 'Event Place') ...[
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
                          const SizedBox(height: 18),
                        ],

                        // Guests Input
                        if (_reservationType == 'Event Place' ||
                            (_reservationType == 'Advance Order' && _advanceOrderType == 'Dine In')) ...[
                          _buildFormLabel('NUMBER OF GUESTS'),
                          const SizedBox(height: 8),
                          _buildStyledTextField(
                            controller: _guestsController,
                            hint: 'Enter guest count (max 100)',
                            icon: Icons.people_alt_rounded,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                              TextInputFormatter.withFunction((oldValue, newValue) {
                                if (newValue.text.isEmpty) return newValue;
                                final int? val = int.tryParse(newValue.text);
                                if (val == null) return oldValue;
                                final int maxGuests = _reservationType == 'Event Place' ? 100 : 20;
                                if (val > maxGuests) {
                                  return oldValue;
                                }
                                return newValue;
                              }),
                            ],
                            helperText: _reservationType == 'Event Place'
                                ? 'Allowed: $_minGuestCount–100 guests (Numbers only)'
                                : 'Allowed: 1–20 guests (Numbers only)',
                          ),
                          const SizedBox(height: 18),
                        ],

                        // Menu Selection Box
                        _buildFormLabel('MENU SELECTION'),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.cardBorder),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.receipt_long_rounded, size: 16, color: AppTheme.forestGreen),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _selectedMenuItems.isEmpty
                                                ? 'No dishes selected'
                                                : '$menuItemsCount dishes (₱${NumberFormat('#,##0.00').format(menuSubtotal)})',
                                            style: GoogleFonts.inter(
                                              fontSize: isSmallScreen ? 12 : 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.darkGrey,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_selectedMenuItems.isNotEmpty)
                                    GestureDetector(
                                      onTap: () => setState(() {
                                        _selectedMenuItems.clear();
                                        _preOrderCart.clear();
                                      }),
                                      child: Text(
                                        'Clear',
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
                                const SizedBox(height: 10),
                                const Divider(height: 1),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _reservationType == 'Advance Order'
                                          ? 'Total Amount:'
                                          : (_paymentOption == 'full' ? 'Total Amount:' : '50% Deposit:'),
                                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.mediumGrey),
                                    ),
                                    Text(
                                      '₱${NumberFormat("#,##0.00").format(depositRequired)}',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.forestGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: AnimatedTapScale(
                                  onTap: _navigateToMenuSelection,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.goldGradient,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.restaurant_menu_rounded, size: 16, color: AppTheme.darkBrownText),
                                        const SizedBox(width: 6),
                                        Text(
                                          _selectedMenuItems.isEmpty ? 'Select Dishes' : 'Modify Dishes',
                                          style: GoogleFonts.inter(
                                            color: AppTheme.darkBrownText,
                                            fontWeight: FontWeight.w800,
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
                        const SizedBox(height: 18),

                        // Extra Time (Event Place Only)
                        if (_reservationType == 'Event Place') ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.cardBorder),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.history_toggle_off_rounded, size: 18, color: AppTheme.primaryColor),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Extra Time Extension',
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w600,
                                            fontSize: isSmallScreen ? 12 : 13,
                                            color: AppTheme.darkGrey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Switch(
                                      value: _addExtraTime,
                                      activeThumbColor: AppTheme.primaryColor,
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
                                  const SizedBox(height: 8),
                                  _buildStyledDropdown<String>(
                                    value: _selectedExtraTime,
                                    hint: 'Select extra hours',
                                    icon: Icons.add_alarm_rounded,
                                    items: _extraTimeOptions,
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedExtraTime = val;
                                        _updateDurationText();
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 6),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],

                        // Payment Option Selection (Event Place Only)
                        if (_reservationType == 'Event Place') ...[
                          _buildFormLabel('PAYMENT OPTION'),
                          const SizedBox(height: 8),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final stackPayment = constraints.maxWidth < 290;

                              final halfTile = AnimatedTapScale(
                                onTap: () => setState(() => _paymentOption = 'half'),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _paymentOption == 'half'
                                        ? AppTheme.warmGold.withValues(alpha: 0.12)
                                        : const Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: _paymentOption == 'half' ? AppTheme.warmGold : AppTheme.cardBorder,
                                      width: _paymentOption == 'half' ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _paymentOption == 'half'
                                            ? Icons.check_circle_rounded
                                            : Icons.radio_button_unchecked_rounded,
                                        size: 18,
                                        color: _paymentOption == 'half' ? AppTheme.primaryColor : AppTheme.mediumGrey,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '50% Deposit',
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w700,
                                            fontSize: isSmallScreen ? 12 : 13,
                                            color: AppTheme.darkGrey,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );

                              final fullTile = AnimatedTapScale(
                                onTap: () => setState(() => _paymentOption = 'full'),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _paymentOption == 'full'
                                        ? AppTheme.warmGold.withValues(alpha: 0.12)
                                        : const Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: _paymentOption == 'full' ? AppTheme.warmGold : AppTheme.cardBorder,
                                      width: _paymentOption == 'full' ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _paymentOption == 'full'
                                            ? Icons.check_circle_rounded
                                            : Icons.radio_button_unchecked_rounded,
                                        size: 18,
                                        color: _paymentOption == 'full' ? AppTheme.primaryColor : AppTheme.mediumGrey,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Pay in Full',
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w700,
                                            fontSize: isSmallScreen ? 12 : 13,
                                            color: AppTheme.darkGrey,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );

                              if (stackPayment) {
                                return Column(
                                  children: [
                                    halfTile,
                                    const SizedBox(height: 8),
                                    fullTile,
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(child: halfTile),
                                  const SizedBox(width: 10),
                                  Expanded(child: fullTile),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 18),
                        ],

                        // Special Requests
                        if (_enableSpecialRequests) ...[
                          _buildFormLabel(_reservationType == 'Event Place' ? 'SPECIAL REQUESTS' : 'PREPARATION NOTES'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _specialRequestsController,
                            maxLines: 2,
                            style: GoogleFonts.inter(fontSize: 13.5, color: AppTheme.darkGrey),
                            decoration: InputDecoration(
                              hintText: _reservationType == 'Event Place'
                                  ? 'Dietary preferences, accessibility needs, setup requests...'
                                  : 'Preparation instructions (e.g. no spice, utensils needed)...',
                              hintStyle: GoogleFonts.inter(
                                color: AppTheme.mediumGrey.withValues(alpha: 0.6),
                                fontSize: 13,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF9FAFB),
                              contentPadding: const EdgeInsets.all(12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: AppTheme.cardBorder),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: AppTheme.cardBorder),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: AppTheme.warmGold, width: 1.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],

                        // Valid ID Upload (Event Place Only)
                        if (_reservationType == 'Event Place') ...[
                          Row(
                            children: [
                              _buildFormLabel(
                                _hasSavedValidId
                                    ? 'VALID ID (ON FILE)'
                                    : 'VALID ID (REQUIRED FOR CHECK-IN)',
                              ),
                              if (!_hasSavedValidId) ...[
                                const SizedBox(width: 4),
                                const Text(
                                  '*',
                                  style: TextStyle(
                                    color: AppTheme.errorRed,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.forestGreen.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppTheme.forestGreen.withValues(alpha: 0.3), width: 0.8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.verified_rounded, size: 12, color: AppTheme.forestGreen),
                                      const SizedBox(width: 4),
                                      Text(
                                        'VERIFIED RECORD',
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.forestGreen,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_isUploadingId)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 12.0),
                                child: CircularProgressIndicator(color: AppTheme.primaryColor),
                              ),
                            )
                          else if (_uploadedIdUrl != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppTheme.forestGreen.withValues(alpha: 0.6),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      _uploadedIdUrl!,
                                      width: 52,
                                      height: 52,
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, s) => Container(
                                        width: 52,
                                        height: 52,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.badge_rounded, color: AppTheme.forestGreen, size: 26),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.check_circle_rounded, color: AppTheme.forestGreen, size: 16),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                _hasSavedValidId && _uploadedIdUrl == _savedAccountValidIdUrl
                                                    ? 'Valid ID on File'
                                                    : 'Valid ID Attached',
                                                style: GoogleFonts.inter(
                                                  fontWeight: FontWeight.w700,
                                                  color: AppTheme.forestGreen,
                                                  fontSize: isSmallScreen ? 12 : 13,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _hasSavedValidId && _uploadedIdUrl == _savedAccountValidIdUrl
                                              ? 'Recorded from previous booking. No re-upload required.'
                                              : 'Ready for check-in verification.',
                                          style: GoogleFonts.inter(
                                            fontSize: isSmallScreen ? 10 : 11,
                                            color: AppTheme.mediumGrey,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _pickAndUploadIdImage,
                                    child: Text(
                                      'Change',
                                      style: GoogleFonts.inter(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            AnimatedTapScale(
                              onTap: _pickAndUploadIdImage,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppTheme.cardBorder),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.add_photo_alternate_rounded, size: 20, color: AppTheme.primaryColor),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Upload Valid ID (Required: JPG, PNG)',
                                      style: GoogleFonts.inter(
                                        fontSize: isSmallScreen ? 12 : 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.darkGrey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 22),
                        ],

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: AnimatedTapScale(
                            onTap: _isLoading ? () {} : _showConfirmationDialog,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: _isLoading
                                    ? null
                                    : const LinearGradient(
                                        colors: [AppTheme.primaryColor, Color(0xFF14332E)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                color: _isLoading ? Colors.grey.shade400 : null,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: _isLoading
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                              ),
                              child: Center(
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            _reservationType == 'Event Place'
                                                ? 'Confirm Reservation'
                                                : 'Confirm Order',
                                            style: GoogleFonts.inter(
                                              fontSize: isSmallScreen ? 14 : 15,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _handleTimeSelection(TimeOfDay pickedTime, int startHour, int endHour) async {
    if (pickedTime.hour < startHour ||
        pickedTime.hour > endHour ||
        (pickedTime.hour == endHour && pickedTime.minute > 0)) {
      _showSnackBar(
        'Please select a time between ${startHour.toString().padLeft(2, '0')}:00 and ${endHour.toString().padLeft(2, '0')}:00',
        Colors.red,
      );
      return;
    }

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
              final earliestFormatted =
                  '${earliestTime.hour.toString().padLeft(2, '0')}:${earliestTime.minute.toString().padLeft(2, '0')}';
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

    if (_reservationType == 'Event Place' && _dateController.text.isNotEmpty) {
      try {
        final parsedDate = DateFormat('MMMM d, yyyy').parse(_dateController.text.trim());
        final formattedDate = DateFormat('yyyy-MM-dd').format(parsedDate);
        final duration = double.tryParse(_durationController.text) ?? 2.0;
        final formattedTime = pickedTime.format(context);

        final isOverlapping = await _reservationService.isTimeSlotOverlapping(
          eventDate: formattedDate,
          startTime: formattedTime,
          durationHours: duration,
        );

        if (isOverlapping) {
          _showSnackBar(
            'This time slot ($formattedTime) is already booked on this date. Please choose a different time.',
            Colors.orange,
          );
          return;
        }
      } catch (e) {
        debugPrint('Error checking time slot overlap: $e');
      }
    }

    setState(() {
      _startTimeController.text = pickedTime.format(context);
    });
  }



  // ── Reservation Form Helpers ──────────────────────────────────────





  Widget _buildFormLabel(String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          margin: const EdgeInsets.only(right: 6),
          decoration: const BoxDecoration(
            color: AppTheme.warmGold,
            shape: BoxShape.circle,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppTheme.darkGrey,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }

  // ignore: unused_element
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
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.darkGrey,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppTheme.mediumGrey.withValues(alpha: 0.6),
        ),
        helperText: helperText,
        helperStyle: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppTheme.mediumGrey,
        ),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppTheme.warmGold.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.darkBrownText, size: 18),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.cardBorder, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.cardBorder, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.warmGold, width: 1.8),
        ),
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
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.darkGrey,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppTheme.mediumGrey.withValues(alpha: 0.6),
        ),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppTheme.warmGold.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.darkBrownText, size: 18),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        suffixIcon: const Padding(
          padding: EdgeInsets.only(right: 12),
          child: Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.mediumGrey, size: 22),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.cardBorder, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.cardBorder, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.warmGold, width: 1.8),
        ),
      ),
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(16),
      icon: const SizedBox.shrink(),
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(
                  item,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.darkGrey,
                  ),
                ),
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
                        _showSnackBar(
                          'Password updated successfully!',
                          AppTheme.successGreen,
                        );
                      }
                    } catch (e) {
                      setDialogState(() => isUpdating = false);
                      if (context.mounted) {
                        _showSnackBar(
                          'Error updating password: $e',
                          AppTheme.errorRed,
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
      child: Stack(
        children: [
          ListView.builder(
            controller: _categoryScrollController,
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
          if (_canScrollCategoryLeft)
            Positioned(
              left: 4,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, color: AppTheme.primaryColor, size: 20),
                    onPressed: () {
                      _categoryScrollController.animateTo(
                        (_categoryScrollController.offset - 200).clamp(0.0, _categoryScrollController.position.maxScrollExtent),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ),
              ),
            ),
          if (_canScrollCategoryRight)
            Positioned(
              right: 4,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, color: AppTheme.primaryColor, size: 20),
                    onPressed: () {
                      _categoryScrollController.animateTo(
                        (_categoryScrollController.offset + 200).clamp(0.0, _categoryScrollController.position.maxScrollExtent),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ),
              ),
            ),
        ],
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
          _savedAccountValidIdUrl = imageUrl;
          _hasSavedValidId = true;
          _isUploadingId = false;
        });

      }

    } catch (e) {

      setState(() {

        _isUploadingId = false;

      });

      if (mounted) {
        _showSnackBar('Failed to upload ID: $e', Colors.red);
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

        if (_uploadedIdUrl != null && _uploadedIdUrl!.isNotEmpty) {
          _savedAccountValidIdUrl = _uploadedIdUrl;
          _hasSavedValidId = true;
        }

        // Retain the saved ID URL on account so next booking does not need re-upload
        _uploadedIdUrl = _savedAccountValidIdUrl;
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



  String _getPaymentStatusText(
    String status,
    bool isQuoted, {
    bool isAdvanceOrder = false,
    bool isPayInFull = false,
    String? bookingStatus,
  }) {
    if (!isQuoted) return 'AWAITING TRANSACTION';

    final isConfirmed = bookingStatus == 'confirmed' || bookingStatus == 'completed';

    switch (status) {
      case 'deposit_paid':
        if (!isConfirmed) {
          return (isAdvanceOrder || isPayInFull) ? 'FULLY SETTLED' : 'DEPOSIT (WAITING APPROVAL)';
        }
        return (isAdvanceOrder || isPayInFull) ? 'FULLY SETTLED' : 'DEPOSIT PAID';

      case 'paid':
      case 'fully_paid':
        return 'FULLY SETTLED';

      case 'unpaid':
        return (isAdvanceOrder || isPayInFull) ? 'PAYMENT DUE' : 'DEPOSIT DUE';

      case 'refunded':
        return 'REFUNDED';

      default:
        return status.toUpperCase();
    }
  }



  void _showOfficialReceiptDialog(Map<String, dynamic> reservation) {
    final pricingInfo = _reservationService.getReservationPricing(reservation);
    final depositAmount = pricingInfo['depositAmount'] as double;
    final totalPrice = pricingInfo['totalPrice'] as double;
    final isAdvanceOrder = reservation['_db_table'] == 'advance_orders';
    final paymentStatus = (reservation['payment_status']?.toString() ?? 'pending').toLowerCase();
    final isPaid = paymentStatus == 'paid' || paymentStatus == 'fully_paid';
    final isDepositPaid = paymentStatus == 'deposit_paid';
    final remainingBalance = isAdvanceOrder
        ? (isPaid ? 0.0 : totalPrice)
        : (isPaid ? 0.0 : (isDepositPaid ? (totalPrice - depositAmount) : totalPrice));
    final orderedItems = reservation['selected_menu_items'] as Map<String, dynamic>? ?? {};
    final refId = reservation['id']?.toString() ?? 'N/A';
    final shortRef = refId.length > 8 ? refId.substring(0, 8).toUpperCase() : refId.toUpperCase();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header Banner ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0C241F), Color(0xFF14332E), Color(0xFF1E4A42)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.receipt_long_rounded, color: Color(0xFFD9A441), size: 20),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'YANG CHOW PAGSANJAN',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                Text(
                                  'Official Booking & Order Slip',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: const Color(0xFFD9A441),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'REF NO: #YC-$shortRef',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFD9A441),
                              letterSpacing: 1.0,
                            ),
                          ),
                          Text(
                            isPaid
                                ? 'PAID IN FULL'
                                : (isDepositPaid ? '50% DEPOSIT PAID' : 'PENDING PAYMENT'),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isPaid ? const Color(0xFF86EFAC) : const Color(0xFFFBBF24),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Scrollable Slip Details ──
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Event & Dining Parameters
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
                              Icons.deck_rounded,
                              'Type',
                              reservation['event_type'] ?? (isAdvanceOrder ? 'Advance Order' : 'Reservation'),
                            ),
                            const SizedBox(height: 6),
                            _buildActivityDetailRow(
                              Icons.calendar_today_rounded,
                              'Date',
                              reservation['event_date'] ?? reservation['order_date'] ?? 'N/A',
                            ),
                            const SizedBox(height: 6),
                            _buildActivityDetailRow(
                              Icons.access_time_rounded,
                              'Time',
                              reservation['start_time'] ?? reservation['pickup_time'] ?? 'N/A',
                            ),
                            if (reservation['number_of_guests'] != null) ...[
                              const SizedBox(height: 6),
                              _buildActivityDetailRow(
                                Icons.people_alt_rounded,
                                'Guests',
                                '${reservation['number_of_guests']} Pax',
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Ordered Items List
                      if (orderedItems.isNotEmpty) ...[
                        Text(
                          'ORDERED MENU ITEMS',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF64748B),
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: orderedItems.entries.map((e) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${e.value}x  ${e.key}',
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
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Financial Statement
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
                            Text(
                              'PAYMENT SUMMARY',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF14332E),
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildPricingRow('Total Bill Amount', totalPrice, const Color(0xFF0F172A)),
                            if (!isAdvanceOrder) ...[
                              const SizedBox(height: 4),
                              _buildPricingRow('50% Downpayment', depositAmount, const Color(0xFF14332E)),
                            ],
                            const Divider(height: 14, color: Color(0xFFCBD5E1)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Balance Due at Counter',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: remainingBalance > 0
                                            ? const Color(0xFFDC2626)
                                            : const Color(0xFF16A34A),
                                      ),
                                    ),
                                    Text(
                                      remainingBalance > 0 ? 'Payable upon arrival' : 'Fully Settled',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '₱${_fmt.format(remainingBalance)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: remainingBalance > 0
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFF16A34A),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Location & Note
                      Center(
                        child: Text(
                          'Present this slip to Yang Chow staff upon arrival.\nCLA Town Center Mall, Pagsanjan, Laguna',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: const Color(0xFF94A3B8),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Bottom Action ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF14332E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Close Slip',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Online Payment for Remaining Balance (GCash / PayMongo) ───────────────

  Future<void> _payRemainingBalanceOnline(Map<String, dynamic> reservation) async {
    final totalPrice = (reservation['total_price'] as num?)?.toDouble() ?? 0.0;
    final depositAmount = (reservation['deposit_amount'] as num?)?.toDouble() ?? 0.0;
    final remaining = (reservation['remaining_balance'] as num?)?.toDouble() ?? (totalPrice - depositAmount);
    final reservationId = reservation['id']?.toString() ?? '';
    final eventType = reservation['event_type']?.toString() ?? 'Reservation';

    if (remaining <= 0) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            const CircularProgressIndicator(color: Color(0xFF0EA5E9)),
            const SizedBox(width: 16),
            const Expanded(child: Text('Creating GCash/PayMongo payment link...')),
          ],
        ),
      ),
    );

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      final customerName = currentUser?.userMetadata?['name'] ?? currentUser?.email?.split('@')[0] ?? 'Customer';

      final response = await PayMongoService.createPaymentLink(
        amount: remaining,
        description: 'Remaining Balance — $eventType ($customerName)',
        metadata: {
          'source': 'remaining_balance_customer',
          'reservation_id': reservationId,
          'customer_name': customerName,
        },
      );

      if (mounted) Navigator.of(context).pop(); // close loading

      if (response['success'] == true && response['checkoutUrl'] != null) {
        final checkoutUrl = response['checkoutUrl'] as String;
        final linkId = response['linkId'] as String?;

        // Save link to reservation if columns exist
        try {
          await Supabase.instance.client.from('reservations').update({
            'balance_link_id': linkId,
            'balance_link_url': checkoutUrl,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', reservationId);
        } catch (e) {
          debugPrint('Note: balance link columns update skipped: $e');
        }

        // Open checkout URL in browser
        await launchUrl(Uri.parse(checkoutUrl), mode: LaunchMode.externalApplication);

        // Show waiting dialog with polling
        if (mounted) {
          _showRemainingPaymentWaitingDialog(
            remaining: remaining,
            linkId: linkId,
            reservationId: reservationId,
          );
        }
      } else {
        throw Exception('No checkout URL returned from PayMongo');
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment link error: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  void _showRemainingPaymentWaitingDialog({
    required double remaining,
    String? linkId,
    required String reservationId,
  }) {
    Timer? pollingTimer;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        if (linkId != null) {
          pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
            try {
              final result = await PayMongoService.retrievePaymentLink(linkId);
              if (result['isPaid'] == true) {
                timer.cancel();
                if (mounted) Navigator.of(dialogContext).pop();

                await _reservationService.updatePaymentStatus(
                  id: reservationId,
                  paymentStatus: 'fully_paid',
                  table: 'reservations',
                  paymentReference: 'PayMongo-Balance',
                );

                try {
                  await Supabase.instance.client.from('reservations').update({
                    'payment_status': 'fully_paid',
                    'payment_option': 'full',
                    'remaining_balance': 0,
                    'status': 'confirmed',
                    'updated_at': DateTime.now().toUtc().toIso8601String(),
                  }).eq('id', reservationId);
                } catch (e) {
                  debugPrint('Error updating remaining balance settlement: $e');
                }

                if (mounted) {
                  _loadCustomerReservations();
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      contentPadding: const EdgeInsets.all(24),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: AppTheme.successGreen.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_circle_rounded, size: 36, color: AppTheme.successGreen),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Payment Received!',
                            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '₱${_fmt.format(remaining)} remaining balance has been settled successfully.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.mediumGrey),
                          ),
                        ],
                      ),
                      actions: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.forestGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                  );
                }
              }
            } catch (e) {
              debugPrint('Polling error: $e');
            }
          });
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const Icon(Icons.qr_code_2, size: 36, color: Color(0xFF0EA5E9)),
              ),
              const SizedBox(height: 16),
              Text(
                'Waiting for Payment...',
                style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              Text(
                '₱${_fmt.format(remaining)}',
                style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFFDC2626)),
              ),
              const SizedBox(height: 16),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(color: Color(0xFF0EA5E9), strokeWidth: 3),
              ),
              const SizedBox(height: 12),
              Text(
                'Complete your payment in GCash / PayMongo checkout window.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.mediumGrey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                pollingTimer?.cancel();
                Navigator.pop(dialogContext);
              },
              child: const Text('Close', style: TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    );
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
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
                    Expanded(
                      child: Text(
                        _activityFilter == 'in_progress'
                            ? 'In Progress Orders'
                            : (_activityFilter == 'confirmed' ? 'Confirmed Bookings' : 'Active & Recent Bookings'),
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
                  // Show timeline once customer has submitted payment (not just when fully confirmed)
                  final isPaid = reservation['payment_status'] == 'paid' ||
                      reservation['payment_status'] == 'fully_paid' ||
                      reservation['payment_status'] == 'pending_verification' ||
                      reservation['status'] == 'awaiting_verification';
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
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
                                            maxLines: 2,
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
                                    const SizedBox(width: 8),
                                    _buildStatusChip(status),
                                    if ((status == 'confirmed' || status == 'pending') &&
                                        !(isAdvanceOrder && isPaid)) ...[
                                      const SizedBox(width: 2),
                                      SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: PopupMenuButton<String>(
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(Icons.more_vert_rounded, color: Colors.white70, size: 18),
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
                                      ),
                                    ],
                                  ],
                                 ),
                                 // ── Extra Badges Row (PAID / Pay button / E-Receipt / Review) ──
                                 const SizedBox(height: 8),
                                 Wrap(
                                   spacing: 6,
                                   runSpacing: 6,
                                   children: [
                                     if (isAdvanceOrder && status == 'confirmed' && !isPaid)
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
                                                 'Pay Now',
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
                                     if (isPaid)
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
                                     // E-Receipt Official Booking Slip Button
                                     AnimatedTapScale(
                                       onTap: () => _showOfficialReceiptDialog(reservation),
                                       child: Container(
                                         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                         decoration: BoxDecoration(
                                           color: const Color(0xFFD9A441).withValues(alpha: 0.16),
                                           borderRadius: BorderRadius.circular(8),
                                           border: Border.all(color: const Color(0xFFD9A441).withValues(alpha: 0.45)),
                                         ),
                                         child: Row(
                                           mainAxisSize: MainAxisSize.min,
                                           children: [
                                             const Icon(Icons.receipt_long_rounded, color: Color(0xFFD9A441), size: 12),
                                             const SizedBox(width: 4),
                                             Text(
                                               'E-Receipt',
                                               style: GoogleFonts.inter(
                                                 color: const Color(0xFFD9A441),
                                                 fontSize: 10,
                                                 fontWeight: FontWeight.w800,
                                               ),
                                             ),
                                           ],
                                         ),
                                       ),
                                     ),
                                     // Rate Dining Experience Button for Completed Orders/Reservations
                                     if (status == 'completed' ||
                                         status == 'done' ||
                                         reservation['kitchen_status']?.toString().toLowerCase() == 'done')
                                       AnimatedTapScale(
                                         onTap: () {
                                           Navigator.push(
                                             context,
                                             MaterialPageRoute(
                                               builder: (_) => CustomerReviewsPage(
                                                 reservationId: reservation['id']?.toString(),
                                               ),
                                             ),
                                           );
                                         },
                                         child: Container(
                                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                           decoration: BoxDecoration(
                                             color: const Color(0xFF007AFF).withValues(alpha: 0.15),
                                             borderRadius: BorderRadius.circular(8),
                                             border: Border.all(color: const Color(0xFF007AFF).withValues(alpha: 0.4)),
                                           ),
                                           child: Row(
                                             mainAxisSize: MainAxisSize.min,
                                             children: [
                                               const Icon(Icons.star_rounded, color: Color(0xFF38BDF8), size: 12),
                                               const SizedBox(width: 4),
                                               Text(
                                                 'Rate Dining',
                                                 style: GoogleFonts.inter(
                                                   color: const Color(0xFF38BDF8),
                                                   fontSize: 10,
                                                   fontWeight: FontWeight.w800,
                                                 ),
                                               ),
                                             ],
                                           ),
                                         ),
                                       ),
                                   ],
                                 ),
                                // ── Reschedule Status Badge Row ──
                                if (reservation['reschedule_status'] == 'pending_approval' ||
                                    reservation['reschedule_status'] == 'reschedule_rejected' ||
                                    reservation['reschedule_status'] == 'rejected' ||
                                    reservation['reschedule_status'] == 'declined' ||
                                    reservation['reschedule_status'] == 'rescheduled' ||
                                    reservation['reschedule_status'] == 'approved') ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      if (reservation['reschedule_status'] == 'pending_approval')
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
                                        )
                                      else if (reservation['reschedule_status'] == 'reschedule_rejected' ||
                                          reservation['reschedule_status'] == 'rejected' ||
                                          reservation['reschedule_status'] == 'declined')
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
                                        )
                                      else if (reservation['reschedule_status'] == 'rescheduled' ||
                                          reservation['reschedule_status'] == 'approved')
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

                                // Real-time order progress stepper backed by Supabase kitchen_status & order status
                                if ((isAdvanceOrder && isPaid) ||
                                    (!isAdvanceOrder &&
                                        status == 'confirmed' &&
                                        reservation['selected_menu_items'] != null &&
                                        (reservation['selected_menu_items'] as Map).isNotEmpty)) ...[
                                  const SizedBox(height: 14),
                                  _buildProgressStepper(
                                    isAdvanceOrder
                                        ? status
                                        : (reservation['kitchen_status']?.toString() ?? 'Pending'),
                                  ),
                                ],

                                // ── PDF & QR Pass Quick Action Buttons for Confirmed/Paid Bookings & Advance Orders ──
                                if (status == 'confirmed' || status == 'completed' || (isAdvanceOrder && isPaid)) ...[
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          icon: const Icon(Icons.qr_code_rounded, size: 16, color: AppTheme.forestGreen),
                                          label: Text(
                                            isAdvanceOrder ? 'Show Claim Pass' : 'Show QR Pass',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.forestGreen,
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: AppTheme.forestGreen, width: 1.2),
                                            padding: const EdgeInsets.symmetric(vertical: 11),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          onPressed: () => _showQrPassModal(reservation),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                                          label: Text(
                                            isAdvanceOrder ? 'PDF Claim Slip' : 'PDF Voucher',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.forestGreen,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 11),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          onPressed: () => ReceiptPdfService.printOrShareVoucher(reservation),
                                        ),
                                      ),
                                    ],
                                  ),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              // 1-Tap "Order Again" Reorder Quick Action
              AnimatedTapScale(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  int addedCount = 0;
                  for (final entry in items.entries) {
                    final qty = (entry.value is num)
                        ? (entry.value as num).toInt()
                        : (int.tryParse(entry.value.toString()) ?? 1);
                    _preOrderCart[entry.key] = (_preOrderCart[entry.key] ?? 0) + qty;
                    addedCount += qty;
                  }
                  _saveCartToPrefs();
                  setState(() {});
                  _showSnackBar(
                    'Added $addedCount item${addedCount > 1 ? 's' : ''} to your Cart! Tap the bag icon at the top to checkout.',
                    AppTheme.forestGreen,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14332E).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF14332E).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.replay_rounded, size: 12, color: Color(0xFF14332E)),
                      const SizedBox(width: 4),
                      Text(
                        'Order Again',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF14332E),
                        ),
                      ),
                    ],
                  ),
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
    final steps = ['Received', 'Confirmed', 'Cooking', 'Ready'];
    int currentStep = 0;

    final s = status.toLowerCase();
    // Step 0 (Received): pending or awaiting_verification (payment submitted, not yet kitchen-visible)
    if (s == 'awaiting_verification' || s == 'pending_verification') {
      currentStep = 0; // Received — payment submitted, awaiting admin
    } else if (s == 'confirmed' || s == 'paid' || s == 'approved' || s == 'pending') {
      // 'pending' here means admin approved → sent to kitchen queue (confirmed)
      currentStep = 1;
    } else if (s == 'preparing' || s == 'cooking' || s == 'in_progress') {
      currentStep = 2;
    } else if (s == 'ready' || s == 'done' || s == 'completed' || s == 'served') {
      currentStep = 3;
    }

    // Distinguish awaiting_verification (step 0) vs truly in-queue (step 0 after admin)
    final s2 = status.toLowerCase();
    String etaText = s2 == 'awaiting_verification' || s2 == 'pending_verification'
        ? '⏳ Payment submitted — awaiting admin verification'
        : '📝 Order placed in queue';
    if (currentStep == 1) {
      etaText = '✅ Admin approved — Order queued in kitchen';
    } else if (currentStep == 2) {
      etaText = '🔥 Sizzling in Wok Station • Est. 12–18 mins';
    } else if (currentStep == 3) {
      etaText = '🛎️ Freshly plated & ready for pickup/dining!';
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
              if (currentStep == 2)
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
                )
              else if (currentStep == 3)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const LivePulseDot(color: Color(0xFF16A34A), size: 7),
                    const SizedBox(width: 5),
                    Text(
                      'Ready to Serve',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),

          // ETA / Status Sub-banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              etaText,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: currentStep == 2
                    ? const Color(0xFFB45309)
                    : (currentStep == 3 ? const Color(0xFF15803D) : const Color(0xFF334155)),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 4-Stage Stepper Nodes
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
                                            : (index == 1
                                                ? Icons.thumb_up_rounded
                                                : (index == 2 ? Icons.soup_kitchen_rounded : Icons.takeout_dining_rounded)))
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

    final isGreen = color == Colors.green ||
        color == const Color(0xFF059669) ||
        color == const Color(0xFF10B981) ||
        color == const Color(0xFF34C759);
    final isRed = color == Colors.red ||
        color == const Color(0xFFDC2626) ||
        color == const Color(0xFFEF4444);
    final isOrange = color == Colors.orange ||
        color == const Color(0xFFD97706) ||
        color == const Color(0xFFF59E0B) ||
        color == const Color(0xFFFF9500);

    final IconData iconData = isGreen
        ? Icons.check_circle_rounded
        : (isRed
            ? Icons.error_rounded
            : (isOrange ? Icons.warning_amber_rounded : Icons.info_rounded));

    final Color bgColor = isGreen
        ? const Color(0xFF0F2E23)
        : (isRed
            ? const Color(0xFF3B1219)
            : (isOrange ? const Color(0xFF382305) : const Color(0xFF1E293B)));

    final Color borderColor = isGreen
        ? const Color(0xFF10B981)
        : (isRed
            ? const Color(0xFFEF4444)
            : (isOrange ? const Color(0xFFF59E0B) : const Color(0xFF3B82F6)));

    final Color iconColor = isGreen
        ? const Color(0xFF34D399)
        : (isRed
            ? const Color(0xFFF87171)
            : (isOrange ? const Color(0xFFFBBF24) : const Color(0xFF60A5FA)));

    _showTopToast(
      duration: const Duration(seconds: 4),
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor.withValues(alpha: 0.6), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.close_rounded,
              color: Colors.white.withValues(alpha: 0.4),
              size: 16,
            ),
          ],
        ),
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

      if (!hasRequiredFields) {
        _showSnackBar('Please fill in all required fields', Colors.red);
        return;
      }

      final int? guestCount = int.tryParse(guests);
      if (guestCount == null || guestCount < _minGuestCount || guestCount > 100) {
        _showSnackBar('Number of guests must be between $_minGuestCount and 100', Colors.red);
        return;
      }

      if (_isUploadingId) {
        _showSnackBar('Please wait for your Valid ID to finish uploading', Colors.orange);
        return;
      }

      if (_uploadedIdUrl == null || _uploadedIdUrl!.isEmpty) {
        _showSnackBar('Please upload a Valid ID before confirming your reservation', Colors.red);
        return;
      }
    } else {
      if (date.isEmpty) hasRequiredFields = false;
      if (startTime.isEmpty) hasRequiredFields = false;
      if (_advanceOrderType == 'Dine In' && guests.isEmpty) hasRequiredFields = false;
      if (_selectedMenuItems.isEmpty) hasRequiredFields = false;

      if (!hasRequiredFields) {
        _showSnackBar('Please fill in all required fields', Colors.red);
        return;
      }

      if (_advanceOrderType == 'Dine In') {
        final int? guestCount = int.tryParse(guests);
        if (guestCount == null || guestCount < 1 || guestCount > 20) {
          _showSnackBar('Number of guests must be between 1 and 20', Colors.red);
          return;
        }
      }
    }



    if (_reservationType == 'Event Place') {
      _showEventTermsAndConditionsDialog();
      return;
    }

    final String title = 'Are you sure you want to Confirm Advance Order?';

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
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
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
            margin: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: const Text('No', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _submitReservation();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

  void _showEventTermsAndConditionsDialog() {
    bool isAgreed = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header Banner ───────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF14332E), Color(0xFF1E4A42)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(22),
                      topRight: Radius.circular(22),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                        ),
                        child: const Icon(
                          Icons.gavel_rounded,
                          color: Color(0xFFD9A441),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TERMS & CONDITIONS',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Event Reservation & Payment Policy',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFFD9A441),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                // ── Scrollable Terms Content ────────────────────────────────
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section 1: Grace Period
                        _buildTermsSection(
                          icon: Icons.timer_outlined,
                          iconColor: const Color(0xFFD9A441),
                          title: '1. Quotation & 3-Minute Grace Period',
                          description:
                              'After submission, our Admin will evaluate your request and send an Official Quotation. You will have exactly 3 Minutes from receiving the quotation to settle the required initial downpayment (50%) to lock and guarantee your reserved date. Failure to pay within 3 minutes will automatically release the slot.',
                        ),
                        const SizedBox(height: 14),

                        // Section 2: Remaining Balance
                        _buildTermsSection(
                          icon: Icons.payments_outlined,
                          iconColor: const Color(0xFF0EA5E9),
                          title: '2. Remaining Balance Settlement Options',
                          description:
                              'You have two flexible payment options for the remaining balance:\n'
                              '• Online Payment: Pay anytime prior to the event date through the app.\n'
                              '• On-the-Day Payment: Pay on-site (Cash or GCash QR) upon arrival before the event begins.',
                        ),
                        const SizedBox(height: 14),

                        // Section 3: Non-Refundable Deposit
                        _buildTermsSection(
                          icon: Icons.verified_user_outlined,
                          iconColor: const Color(0xFF10B981),
                          title: '3. Reservation Confirmation & Non-Refund Policy',
                          description:
                              'The initial downpayment is strictly non-refundable once confirmed, as it reserves the venue and blocks all other booking requests for your scheduled slot.',
                        ),
                        const SizedBox(height: 18),

                        // ── Agreement Checkbox ──────────────────────────────
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isAgreed
                                ? const Color(0xFF14332E).withValues(alpha: 0.06)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isAgreed
                                  ? const Color(0xFF14332E)
                                  : const Color(0xFFCBD5E1),
                              width: 1.2,
                            ),
                          ),
                          child: InkWell(
                            onTap: () {
                              setDialogState(() {
                                isAgreed = !isAgreed;
                              });
                            },
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Checkbox(
                                  value: isAgreed,
                                  activeColor: const Color(0xFF14332E),
                                  checkColor: const Color(0xFFD9A441),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  onChanged: (val) {
                                    setDialogState(() {
                                      isAgreed = val ?? false;
                                    });
                                  },
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Text(
                                      'I have read, understood, and agree to the Terms and Conditions (including the 3-Minute Quotation Grace Period and Remaining Balance settlement policy).',
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        fontWeight: isAgreed ? FontWeight.w700 : FontWeight.w500,
                                        color: const Color(0xFF0F172A),
                                        height: 1.35,
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

                // ── Action Buttons ──────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(22),
                      bottomRight: Radius.circular(22),
                    ),
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: isAgreed
                              ? () {
                                  Navigator.pop(dialogContext);
                                  _submitReservation();
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF14332E),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFCBD5E1),
                            disabledForegroundColor: Colors.white70,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: isAgreed ? 2 : 0,
                          ),
                          child: Text(
                            'Agree & Submit Request',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
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
        ),
      ),
    );
  }

  Widget _buildTermsSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF475569),
                    height: 1.4,
                  ),
                ),
              ],
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

    if (_reservationType == 'Event Place') {
      if (_isUploadingId) {
        _showSnackBar('Please wait for your Valid ID to finish uploading', Colors.orange);
        return;
      }
      if (_uploadedIdUrl == null || _uploadedIdUrl!.isEmpty) {
        _showSnackBar('Please upload a Valid ID before completing your reservation', Colors.red);
        return;
      }
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
      _showSnackBar('User not authenticated', Colors.red);
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

      _showSnackBar('Error: ${e.toString()}', Colors.red);
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

  void _autoCancelExpiredQuotation(String id, String table) async {
    if (id.isEmpty) return;
    try {
      final tableName = table.isNotEmpty ? table : 'reservations';
      await Supabase.instance.client
          .from(tableName)
          .update({
            'status': 'cancelled',
            'special_requests': 'Auto-cancelled: 3-minute quotation payment grace period expired as per Terms & Conditions.',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id);
    } catch (e) {
      debugPrint('Error auto-cancelling expired quotation: $e');
    }
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
    final isFullyPaid = paymentStatus == 'paid' || paymentStatus == 'fully_paid' || (reservation['remaining_balance'] != null && (reservation['remaining_balance'] as num) <= 0 && paymentStatus != 'unpaid');

    final String resStatus = (reservation['status'] ?? 'pending').toString().toLowerCase();
    final bool isCancelled = resStatus == 'cancelled';
    final bool isConfirmed = resStatus == 'confirmed' || resStatus == 'completed';
    // Only deposit payments need admin approval notice; fully paid is automatically settled!
    final bool isAwaitingAdminApproval = isDepositPaid && !isConfirmed && !isFullyPaid;

    // Compute grace period
    final sentAtRaw = reservation['price_quotation_sent_at'] ?? reservation['created_at'];
    DateTime? sentAt;
    if (sentAtRaw != null) {
      sentAt = DateTime.tryParse(sentAtRaw.toString());
    }

    Duration? remainingGrace;
    bool isGraceExpired = false;
    if (sentAt != null) {
      final expiry = sentAt.add(const Duration(minutes: 3));
      final now = DateTime.now();
      if (now.isAfter(expiry)) {
        isGraceExpired = true;
      } else {
        remainingGrace = expiry.difference(now);
      }
    }

    // Strict Auto-cancel: if grace period expired and reservation was still unpaid
    final bool isAutoCancelledDueToGrace = isCancelled || (isGraceExpired && isUnpaidOrDue);

    if (isGraceExpired && isUnpaidOrDue && !isCancelled) {
      _autoCancelExpiredQuotation(
        reservation['id']?.toString() ?? '',
        reservation['_db_table']?.toString() ?? 'reservations',
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAutoCancelledDueToGrace
              ? const Color(0xFFDC2626).withValues(alpha: 0.4)
              : isUnpaidOrDue
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
              decoration: BoxDecoration(
                gradient: isAutoCancelledDueToGrace
                    ? const LinearGradient(
                        colors: [Color(0xFF450A0A), Color(0xFF7F1D1D)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [Color(0xFF14332E), Color(0xFF1E4A42)],
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
                      isAutoCancelledDueToGrace ? Icons.event_busy_rounded : Icons.receipt_long_rounded,
                      color: isAutoCancelledDueToGrace ? const Color(0xFFFCA5A5) : const Color(0xFFD9A441),
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
                      color: isAutoCancelledDueToGrace
                          ? const Color(0xFFDC2626).withValues(alpha: 0.25)
                          : isAwaitingAdminApproval
                              ? const Color(0xFFD97706).withValues(alpha: 0.25)
                              : isFullyPaid
                                  ? const Color(0xFF34C759).withValues(alpha: 0.2)
                                  : isDepositPaid
                                      ? const Color(0xFF007AFF).withValues(alpha: 0.2)
                                      : const Color(0xFFD9A441).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isAutoCancelledDueToGrace
                            ? const Color(0xFFDC2626).withValues(alpha: 0.6)
                            : isAwaitingAdminApproval
                                ? const Color(0xFFD97706).withValues(alpha: 0.6)
                                : isFullyPaid
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
                            color: isAutoCancelledDueToGrace
                                ? const Color(0xFFEF4444)
                                : isAwaitingAdminApproval
                                    ? const Color(0xFFF59E0B)
                                    : isFullyPaid
                                        ? const Color(0xFF34C759)
                                        : isDepositPaid
                                            ? const Color(0xFF38BDF8)
                                            : const Color(0xFFD9A441),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isAutoCancelledDueToGrace
                              ? 'CANCELLED (EXPIRED)'
                              : _getPaymentStatusText(
                                  paymentStatus,
                                  true,
                                  isAdvanceOrder: reservation['_db_table'] == 'advance_orders',
                                  isPayInFull: isPayInFull,
                                  bookingStatus: resStatus,
                                ),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: isAutoCancelledDueToGrace
                                ? const Color(0xFFFCA5A5)
                                : isAwaitingAdminApproval
                                    ? const Color(0xFFFDE68A)
                                    : isFullyPaid
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

                  // ── 24-Hour Grace Period Alert Banner (For Unpaid Quotations within Grace) ─────
                  if (needsDepositPayment && !isAutoCancelledDueToGrace && remainingGrace != null) ...[
                    Builder(
                      builder: (context) {
                        final grace = remainingGrace;
                        if (grace == null) return const SizedBox.shrink();
                        final hours = grace.inHours;
                        final mins = grace.inMinutes % 60;
                        final secs = grace.inSeconds % 60;
                        final timeStr = hours > 0
                            ? '${hours}h ${mins}m'
                            : mins > 0
                                ? '${mins}m ${secs}s'
                                : '${secs}s';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.timer_outlined, color: Color(0xFFD97706), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF92400E)),
                                    children: [
                                      const TextSpan(text: '3-Minute Grace Period: ', style: TextStyle(fontWeight: FontWeight.w800)),
                                      TextSpan(
                                        text: '$timeStr left to pay downpayment and secure your date.',
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],

                  // ── Remaining Balance Settlement Guidance (Deposit Paid) ────────
                  if (paymentStatus == 'deposit_paid' && reservation['_db_table'] != 'advance_orders' && (totalPrice - depositAmount) > 0) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Color(0xFF0284C7), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Remaining Balance Notice: You can pay online anytime before your event or pay on-site (Cash or GCash QR) on the event day itself.',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF0369A1),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Actions & Status Pill Callouts ──────────────────────────────
                  if (isAutoCancelledDueToGrace)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFCA5A5), width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'RESERVATION CANCELLED',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF991B1B),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'As agreed in the Terms and Conditions upon booking, this quotation was not settled within the 3-minute grace period and has been automatically cancelled. The date slot has been released.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF7F1D1D),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (isAwaitingAdminApproval)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.hourglass_bottom_rounded, size: 18, color: Color(0xFFB45309)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Payment submitted — Awaiting admin verification & approval. Official receipt will be confirmed shortly.',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF92400E),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (needsDepositPayment)
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
                  else if (paymentStatus == 'deposit_paid' && reservation['_db_table'] != 'advance_orders' && (totalPrice - depositAmount) > 0)
                    AnimatedTapScale(
                      onTap: () => _payRemainingBalanceOnline(reservation),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0EA5E9).withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.payment_rounded, color: Colors.white, size: 17),
                            const SizedBox(width: 8),
                            Text(
                              'Pay Remaining Balance (₱${_fmt.format(totalPrice - depositAmount)})',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (isFullyPaid && reservation['_db_table'] != 'advance_orders') ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF15803D)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Reservation fully settled — ₱0.00 remaining balance',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF15803D),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showOfficialReceiptDialog(reservation),
                        icon: const Icon(Icons.receipt_long_rounded, size: 16, color: Color(0xFF16302A)),
                        label: Text(
                          'View Official Receipt',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF16302A),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: const BorderSide(color: Color(0xFF16302A), width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQrPassModal(Map<String, dynamic> tx) {
    final resId = (tx['id'] ?? '').toString();
    final shortId = resId.length > 8 ? resId.substring(0, 8).toUpperCase() : resId.toUpperCase();
    final customerEmail = (tx['customer_email'] ?? Supabase.instance.client.auth.currentUser?.email ?? '').toString();
    final customerName = _getUserDisplayName();
    final isAdvanceOrder = tx['_db_table'] == 'advance_orders' || tx['_is_advance_order'] == true;
    final orderType = (tx['order_type'] ?? 'Takeout').toString();
    final eventType = isAdvanceOrder ? 'Advance Order ($orderType)' : (tx['event_type'] ?? 'Reservation').toString();
    final date = (tx['event_date'] ?? tx['order_date'] ?? 'N/A').toString();
    final time = (tx['start_time'] ?? tx['order_time'] ?? tx['pickup_time'] ?? 'N/A').toString();
    final qrPayload = 'YANGCHOW:RES:$resId:$customerEmail';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isAdvanceOrder ? 'Order Claim Pass' : 'Guest Entry Pass',
                    style: GoogleFonts.lora(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.forestGreen,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                isAdvanceOrder
                    ? 'Show this Claim QR code at the counter for pickup / dining'
                    : 'Show this QR code upon arrival at Yang Chow',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.mediumGrey),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.warmGold, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.warmGold.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    QrImageView(
                      data: qrPayload,
                      version: QrVersions.auto,
                      size: 180.0,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFF16302A),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF16302A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16302A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#${isAdvanceOrder ? 'ORD' : 'RES'}-$shortId',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: const Color(0xFFD9A441),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            customerName,
                            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.darkGrey),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF15803D).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF15803D).withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '#${isAdvanceOrder ? 'ORD' : 'RES'}-$shortId',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              color: const Color(0xFF15803D),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '$eventType • $date ($time)',
                        style: GoogleFonts.inter(fontSize: 11, color: AppTheme.mediumGrey),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: Text(
                    isAdvanceOrder ? 'Download Claim Slip (PDF)' : 'Download PDF Voucher',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.forestGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    ReceiptPdfService.printOrShareVoucher(tx);
                  },
                ),
              ),
            ],
          ),
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
              _dismissTopToast();
              _shownToastCustomerNotificationIds.clear();
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

      // Remove the proceeded items from the cart
      for (final key in selectedSubset.keys) {
        _preOrderCart.remove(key);
      }
      _saveCartToPrefs();
      _selectedIndex = 1; // switch to Reservation tab
    });
    _handleCartUpdated();
  }

  void _showOrderListModal() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerOrderListPage(
          selectedMenuItems: _preOrderCart,
          onProceed: _proceedDirectlyToReservation,
          onCartUpdated: _handleCartUpdated,
          onBrowseMenu: () => setState(() => _selectedIndex = 0),
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

/// Animated Top Toast Notification Banner
class _TopToastWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback onDismiss;
  final Duration? duration;

  const _TopToastWidget({
    required this.child,
    required this.onDismiss,
    this.duration,
  });

  @override
  State<_TopToastWidget> createState() => _TopToastWidgetState();
}

class _TopToastWidgetState extends State<_TopToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
      reverseDuration: const Duration(milliseconds: 240),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0.0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topPadding > 0 ? topPadding + 10 : 18,
      left: 16,
      right: 16,
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: SlideTransition(
              position: _slideAnim,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
