import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:yang_chow/utils/app_constants.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/services/menu_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yang_chow/services/reservation_service.dart';
import 'package:intl/intl.dart';
import 'package:yang_chow/models/menu_item.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _menuScrollController = ScrollController();
  final ScrollController _reviewsScrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // --- Section Keys ---
  final GlobalKey _homeKey = GlobalKey();
  final GlobalKey _aboutKey = GlobalKey();
  final GlobalKey _menuKey = GlobalKey();
  final GlobalKey _updatesKey = GlobalKey();
  final GlobalKey _servicesKey = GlobalKey();
  final GlobalKey _reviewsKey = GlobalKey();
  final GlobalKey _mapKey = GlobalKey();
  final GlobalKey _contactKey = GlobalKey();

  bool _isCheckingSession = true;
  bool _showScrollToTop = false;
  bool _isNavbarVisible = true;
  double _lastScrollOffset = 0.0;
  Timer? _reviewsAutoScrollTimer;
  Timer? _heroCarouselTimer;
  int _currentHeroIndex = 0;
  RealtimeChannel? _announcementsChannel;
  StreamSubscription<List<Map<String, dynamic>>>? _featuredOrdersSubscription;

  // --- Dynamic Data State ---
  final ReservationService _reservationService = ReservationService();
  double _averageRating = 0.0;
  int _totalReviewCount = 0;
  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _reviews = [];
  List<MenuItem> _featuredMenuItems = [];

  // --- Food Menu State ---
  String _menuSearchQuery = '';
  String _menuSelectedCategory = 'All';
  Map<String, List<MenuItem>> _menuData = {};
  List<String> _menuCategories = [];
  bool _isLoadingData = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // --- Mobile Menu State ---
  bool _isMobileMenuOpen = false;
  late AnimationController _menuController;
  late Animation<double> _menuFadeAnimation;
  late Animation<Offset> _menuSlideAnimation;

  // --- Map State ---
  final MapController _mapController = MapController();
  final TextEditingController _mapSearchController = TextEditingController();
  final TextEditingController _startPointController =
      TextEditingController(text: 'Your location');
  final TextEditingController _destinationController =
      TextEditingController(text: 'Yang Chow');

  LatLng? _userLocation;
  LatLng? _startLatLng;
  LatLng? _destinationLatLng = _restaurantLocation;
  List<LatLng> _routePoints = [];
  bool _isRouting = false;
  bool _showDirectionsPanel = false;
  bool _isSatelliteMode = false;

  static const LatLng _restaurantLocation = LatLng(14.265, 121.439);

  // ─── Landing Page Standard Red Palette ──────────────────────────────
  static const Color forestGreen  = Color(0xFF990000); // dark red (navbar, overlays)
  static const Color activeEmerald = Color(0xFFAA0000); // medium red (cards, sections)
  static const Color warmGold     = Color(0xFFFFD166); // warm gold accent
  static const Color primaryGold  = Color(0xFFC9922E); // amber gold
  static const Color darkForest   = Color(0xFF770000); // darkest red
  static const Color creamBg      = Color(0xFFF7F3EA); // original cream (content sections)
  static const Color darkGreyText = Color(0xFF1E293B); // dark text on cream sections

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));

    _animController.forward();

    // Initialize Mobile Menu Animation
    _menuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _menuFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _menuController, curve: Curves.easeIn),
    );

    _menuSlideAnimation = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _menuController, curve: Curves.easeOutCubic));

    _checkAndRedirectUser();
    _loadDynamicData();
    _getCurrentLocation();
    _startReviewsAutoScroll();
    _startHeroCarouselTimer();
    _subscribeToAnnouncements();
    _subscribeToFeaturedDishes();
  }

  void _subscribeToAnnouncements() {
    _announcementsChannel = Supabase.instance.client
        .channel('public:announcements')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'announcements',
          callback: (payload) {
            // Re-fetch announcements whenever any change happens in the DB
            if (mounted) _fetchAnnouncements();
          },
        )
        .subscribe();
  }

  void _subscribeToFeaturedDishes() {
    _featuredOrdersSubscription?.cancel();
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
            final allMenu = await MenuService.fetchMenu();
            final allItems = <MenuItem>[];
            for (var list in allMenu.values) {
              allItems.addAll(list);
            }

            final List<MenuItem> featuredList = [];
            final sorted = grouped.values.toList()
              ..sort((a, b) => (b['lastOrderAt'] as String)
                  .compareTo(a['lastOrderAt'] as String));

            final top10 = sorted.take(10).toList();

            for (final entry in top10) {
              final match = allItems
                  .where((m) =>
                      m.name.trim().toLowerCase() ==
                      (entry['name'] as String).trim().toLowerCase())
                  .toList();
              if (match.isNotEmpty) {
                featuredList.add(match.first);
              }
            }

            if (mounted && featuredList.isNotEmpty) {
              setState(() {
                _featuredMenuItems = featuredList;
              });
            }
          } catch (e) {
            debugPrint('Error fetching featured dishes: $e');
            _populateFallbackFeaturedDishes();
          }
        });
  }

  Future<void> _populateFallbackFeaturedDishes() async {
    final allMenu = await MenuService.fetchMenu();
    final items = _getTopSellingItems(allMenu);
    if (mounted) {
      setState(() {
        _featuredMenuItems = items;
      });
    }
  }

  Future<void> _fetchAnnouncements() async {
    try {
      final response = await Supabase.instance.client
          .from('announcements')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(3);
      if (mounted) {
        setState(() {
          _announcements = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint('Error refreshing announcements: $e');
    }
  }

  void _startHeroCarouselTimer() {
    _heroCarouselTimer?.cancel();
    _heroCarouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_featuredMenuItems.isNotEmpty && mounted) {
        setState(() {
          _currentHeroIndex =
              (_currentHeroIndex + 1) % _featuredMenuItems.length;
        });
      }
    });
  }

  Future<void> _loadDynamicData() async {
    try {
      setState(() => _isLoadingData = true);

      // 1. Fetch Stats from Services
      final ratingsData = await _reservationService.getAverageRatings();

      // 2. Fetch Announcements from Supabase
      final announcementsResponse = await Supabase.instance.client
          .from('announcements')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(3);

      // 3. Fetch Latest Reviews and Total Count/Average
      final reviewsResponse = await _reservationService.getAllReviews(limit: 6);

      List<Map<String, dynamic>> enrichedReviews = [];
      try {
        if (reviewsResponse.isNotEmpty) {
          final emails = reviewsResponse
              .map((r) => r['customer_email']?.toString())
              .where((e) => e != null && e.isNotEmpty)
              .cast<String>()
              .toSet()
              .toList();

          if (emails.isNotEmpty) {
            final usersResponse = await Supabase.instance.client
                .from('users')
                .select('email, firstname, lastname, avatar_url')
                .inFilter('email', emails);

            final userMap = {for (var u in usersResponse) u['email']: u};

            enrichedReviews = reviewsResponse.map((r) {
              final email = r['customer_email'];
              final user = userMap[email];
              final newReview = Map<String, dynamic>.from(r);
              if (user != null) {
                final fname = user['firstname'] ?? '';
                final lname = user['lastname'] ?? '';
                final fullName = '$fname $lname'.trim();
                newReview['name'] = fullName.isNotEmpty ? fullName : 'Customer';
                newReview['avatar_url'] = user['avatar_url'];
              }
              return newReview;
            }).toList();
          } else {
            enrichedReviews = List<Map<String, dynamic>>.from(reviewsResponse);
          }
        }
      } catch (e) {
        debugPrint('Error enriching reviews with profiles: $e');
        enrichedReviews = List<Map<String, dynamic>>.from(reviewsResponse);
      }

      final allRatingsResponse = await Supabase.instance.client
          .from('reviews')
          .select('rating');

      final ratingsList = List<Map<String, dynamic>>.from(allRatingsResponse);
      double calculatedAverage = 0.0;

      if (ratingsList.isNotEmpty) {
        double sum = 0;
        for (var r in ratingsList) {
          sum += (r['rating'] as num?)?.toDouble() ?? 0.0;
        }
        calculatedAverage = sum / ratingsList.length;
      }

      final totalReviews = ratingsList.length;

      // 4. Fetch live menu from Supabase
      final allMenu = await MenuService.fetchMenu();
      final allMenuItems = <MenuItem>[];
      for (var list in allMenu.values) {
        allMenuItems.addAll(list);
      }

      // Featured items are handled exclusively by _subscribeToFeaturedDishes() via realtime stream.

      if (mounted) {
        setState(() {
          _averageRating =
              calculatedAverage > 0 ? calculatedAverage : (ratingsData['overall'] ?? 0.0);
          _totalReviewCount = totalReviews;
          try {
            _announcements = List<Map<String, dynamic>>.from(announcementsResponse);
          } catch (e) {
            debugPrint('Error parsing announcements: $e');
            _announcements = [];
          }
          _reviews = enrichedReviews;
          _menuData = allMenu;
          _menuCategories = ['All', ...MenuService.categories];
          _isLoadingData = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading dynamic landing page data: $e');
      if (mounted) {
        setState(() {
          _isLoadingData = false;
          if (_announcements.isEmpty) _announcements = [];
        });
      }
    }
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
      final found = flattenedItems
          .where((item) =>
              item.name.trim().toLowerCase() == name.trim().toLowerCase())
          .toList();
      if (found.isNotEmpty) {
        items.add(found.first);
      }
    }

    if (items.length < 5 && flattenedItems.isNotEmpty) {
      for (final item in flattenedItems) {
        if (!items.any((existing) =>
            existing.id == item.id || existing.name == item.name)) {
          items.add(item);
        }
        if (items.length >= 9) break;
      }
    }

    return items;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _menuScrollController.dispose();
    _reviewsScrollController.dispose();
    _reviewsAutoScrollTimer?.cancel();
    _heroCarouselTimer?.cancel();
    _announcementsChannel?.unsubscribe();
    _featuredOrdersSubscription?.cancel();
    _animController.dispose();
    _menuController.dispose();
    _mapSearchController.dispose();
    _startPointController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  // --- Map Methods ---
  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled.')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions are denied')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Location permissions are permanently denied.')),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
      });

      _mapController.move(_userLocation!, 15.0);
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  Future<LatLng?> _geocodeAddress(String address) async {
    if (address == 'Your location') {
      if (_userLocation == null) await _getCurrentLocation();
      return _userLocation;
    }
    if (address == 'Yang Chow') return _restaurantLocation;

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$address&format=json&limit=1',
      );
      final response =
          await http.get(url, headers: {'User-Agent': 'YangChowApp/1.0'});
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          return LatLng(
              double.parse(data[0]['lat']), double.parse(data[0]['lon']));
        }
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
    }
    return null;
  }

  Future<void> _getRoute() async {
    setState(() => _isRouting = true);
    try {
      _startLatLng = await _geocodeAddress(_startPointController.text);
      _destinationLatLng = await _geocodeAddress(_destinationController.text);

      if (_startLatLng == null || _destinationLatLng == null) {
        throw Exception('Could not find start or destination location.');
      }

      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${_startLatLng!.longitude},${_startLatLng!.latitude};'
        '${_destinationLatLng!.longitude},${_destinationLatLng!.latitude}'
        '?overview=full&geometries=geojson',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List coordinates = data['routes'][0]['geometry']['coordinates'];

        setState(() {
          _routePoints = coordinates
              .map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()))
              .toList();
          _isRouting = false;
        });

        if (_routePoints.isNotEmpty) {
          final bounds = LatLngBounds.fromPoints([
            _startLatLng!,
            _destinationLatLng!,
            ..._routePoints,
          ]);
          _mapController.fitCamera(
              CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));
        }
      } else {
        throw Exception('Failed to load route');
      }
    } catch (e) {
      debugPrint('Error getting route: $e');
      setState(() => _isRouting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  void _swapRoutingPoints() {
    final tempText = _startPointController.text;
    _startPointController.text = _destinationController.text;
    _destinationController.text = tempText;

    final tempLatLng = _startLatLng;
    _startLatLng = _destinationLatLng;
    _destinationLatLng = tempLatLng;

    if (_routePoints.isNotEmpty) _getRoute();
  }

  Future<void> _searchPlace(String query) async {
    if (query.isEmpty) return;

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'YangChowApp/1.0',
      });

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          final target = LatLng(lat, lon);
          _mapController.move(target, 15.0);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('No results found for that location.')),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error searching place: $e');
    }
  }

  void _scrollListener() {
    if (_scrollController.offset >= MediaQuery.of(context).size.height * 0.5) {
      if (!_showScrollToTop) setState(() => _showScrollToTop = true);
    } else {
      if (_showScrollToTop) setState(() => _showScrollToTop = false);
    }

    setState(() {
      _lastScrollOffset = _scrollController.offset;
    });
  }

  Future<void> _checkAndRedirectUser() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null && session.user.email != null) {
        final email = session.user.email!;
        try {
          final userResponse = await Supabase.instance.client
              .from('users')
              .select('role')
              .eq('email', email)
              .maybeSingle()
              .timeout(const Duration(seconds: 10));

          if (mounted) {
            final navigator = Navigator.of(context);
            if (userResponse == null) {
              try {
                await Supabase.instance.client.from('users').insert({
                  'email': email,
                  'role': 'customer',
                }).timeout(const Duration(seconds: 5));
              } catch (e) {
                debugPrint('Error inserting new user: $e');
              }
              navigator.pushReplacementNamed('/customer-dashboard');
              return;
            } else {
              String userRole =
                  userResponse['role']?.toString().toLowerCase() ?? 'customer';
              _redirectByUserRole(email, userRole);
              return;
            }
          }
        } on TimeoutException {
          debugPrint('Timeout checking user session');
        } catch (e) {
          debugPrint('Error checking user session: $e');
        }
      }
    } catch (e) {
      debugPrint('Error in _checkAndRedirectUser: $e');
    }

    if (mounted) {
      setState(() {
        _isCheckingSession = false;
      });
    }
  }

  void _redirectByUserRole(String email, String userRole) {
    if (!mounted) return;
    if (email.toLowerCase() == 'pagsanjaninv@gmail.com') {
      Navigator.pushReplacementNamed(context, '/pagsanjaninv-dashboard');
    } else if (email.toLowerCase() == 'chefycp@gmail.com' ||
        email.toLowerCase() == 'chefycp.gmail.com') {
      Navigator.pushReplacementNamed(context, '/chef-dashboard');
    } else if (userRole == 'admin') {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else if (userRole == 'inventory staff') {
      Navigator.pushReplacementNamed(context, '/pagsanjaninv-dashboard');
    } else if (userRole == 'chef') {
      Navigator.pushReplacementNamed(context, '/chef-dashboard');
    } else if (userRole == 'customer') {
      Navigator.pushReplacementNamed(context, '/customer-dashboard');
    } else {
      Navigator.pushReplacementNamed(context, '/staff-dashboard');
    }
  }

  void _scrollToSection(GlobalKey key) {
    if (_isMobileMenuOpen) _toggleMobileMenu();
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _scrollToTop() {
    if (_isMobileMenuOpen) _toggleMobileMenu();
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOutCubic,
    );
  }

  void _toggleMobileMenu() {
    setState(() {
      _isMobileMenuOpen = !_isMobileMenuOpen;
      if (_isMobileMenuOpen) {
        _menuController.forward();
      } else {
        _menuController.reverse();
      }
    });
  }

  void _startReviewsAutoScroll() {
    _reviewsAutoScrollTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_reviewsScrollController.hasClients && _reviews.isNotEmpty) {
        double maxExtent = _reviewsScrollController.position.maxScrollExtent;
        double currentOffset = _reviewsScrollController.offset;
        double targetOffset = currentOffset + 320;

        if (targetOffset >= maxExtent + 50) {
          _reviewsScrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
          );
        } else {
          _reviewsScrollController.animateTo(
            targetOffset,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingSession) {
      return Scaffold(
        backgroundColor: forestGreen,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 74,
                height: 74,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: forestGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: warmGold, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: warmGold.withValues(alpha: 0.3),
                      blurRadius: 25,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: Image.asset(
                  AppConstants.logoPath,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.restaurant,
                    color: warmGold,
                    size: 34,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  color: warmGold,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'YCPRMS • Yang Chow Pagsanjan',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.sidebarSubtitle,
                  fontSize: 14,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFCC0000),
      body: Stack(
        children: [
          // Main Scrollable Body Content
          SingleChildScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                if (_isLoadingData)
                  const LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(primaryGold),
                  ),

                // Hero / Landing Banner
                KeyedSubtree(key: _homeKey, child: _buildHeroSection(context)),

                // About Section
                KeyedSubtree(key: _aboutKey, child: _buildAboutSection(context)),

                // Interactive Food Menu Section
                KeyedSubtree(key: _menuKey, child: _buildMenuSection(context)),

                // Updates & Announcements
                KeyedSubtree(key: _updatesKey, child: _buildUpdatesSection(context)),

                // Restaurant Services
                KeyedSubtree(
                    key: _servicesKey, child: _buildServicesSection(context)),

                // Customer Reviews & Feedback
                KeyedSubtree(key: _reviewsKey, child: _buildReviewsSection(context)),

                // Interactive Location Map & Navigation
                KeyedSubtree(key: _mapKey, child: _buildMapSection(context)),

                // Contact & Footer Section
                KeyedSubtree(
                    key: _contactKey,
                    child: _buildContactFooterSection(context)),
              ],
            ),
          ),

          // Scroll To Top Floating Action Button
          _buildScrollToTopButton(),

          // Custom Half-Screen Mobile Menu Drawer Overlay
          if (_isMobileMenuOpen || _menuController.status == AnimationStatus.reverse)
            _buildMobileMenuOverlay(context),

          // Glassmorphic Dynamic Navigation Bar (Deep Emerald & Muted Gold)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top: (_isNavbarVisible && !_isMobileMenuOpen) ? 0 : -110,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: _lastScrollOffset > 50
                    ? forestGreen.withValues(alpha: 0.96)
                    : Colors.transparent,
                boxShadow: [
                  if (_lastScrollOffset > 50)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                ],
                border: Border(
                  bottom: BorderSide(
                    color: _lastScrollOffset > 50
                        ? warmGold.withValues(alpha: 0.3)
                        : Colors.transparent,
                    width: 1,
                  ),
                ),
              ),
              child: _buildTopNavigationBar(context),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // NAVIGATION BAR
  // ---------------------------------------------------------------------------

  Widget _buildTopNavigationBar(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 48 : 20,
        vertical: 14,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo & Brand Name
              InkWell(
                onTap: _scrollToTop,
                borderRadius: BorderRadius.circular(10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: AppTheme.goldGradient,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: primaryGold.withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          )
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            AppConstants.logoPath,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.restaurant_menu_rounded,
                              color: forestGreen,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              'YANG ',
                              style: GoogleFonts.playfairDisplay(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                                letterSpacing: 1.1,
                              ),
                            ),
                            Text(
                              'CHOW',
                              style: GoogleFonts.playfairDisplay(
                                color: warmGold,
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'PAGSANJAN • YCPRMS',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.sidebarSubtitle,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Desktop nav links
              if (isDesktop)
                Row(
                  children: [
                    _navLink('Home', () => _scrollToTop()),
                    _navLink('About', () => _scrollToSection(_aboutKey)),
                    _navLink('Menu', () => _scrollToSection(_menuKey)),
                    _navLink('Updates', () => _scrollToSection(_updatesKey)),
                    _navLink('Services', () => _scrollToSection(_servicesKey)),
                    _navLink('Reviews', () => _scrollToSection(_reviewsKey)),
                    _navLink('Map', () => _scrollToSection(_mapKey)),
                    _navLink('Contact', () => _scrollToSection(_contactKey)),
                  ],
                ),

              // Mobile Burger Menu Toggle / Desktop Login Button
              if (!isDesktop)
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: warmGold.withValues(alpha: 0.45),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: _toggleMobileMenu,
                    icon: AnimatedIcon(
                      icon: AnimatedIcons.menu_close,
                      progress: _menuController,
                      color: warmGold,
                      size: 23,
                    ),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.goldGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: primaryGold.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: AppTheme.darkBrownText,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline_rounded, size: 16, color: AppTheme.darkBrownText),
                        const SizedBox(width: 6),
                        Text(
                          'Sign In',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.darkBrownText,
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
  }

  Widget _navLink(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white70,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildMobileMenuOverlay(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallPhone = screenWidth < 360;
    final drawerWidth = (screenWidth * 0.82).clamp(280.0, 340.0);

    return IgnorePointer(
      ignoring: !_isMobileMenuOpen,
      child: FadeTransition(
        opacity: _menuFadeAnimation,
        child: Stack(
          children: [
            // Darkened Scrim / Backdrop with gentle blur feel
            GestureDetector(
              onTap: _toggleMobileMenu,
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),

            // Floating Mobile Drawer with warm rich red tone
            Align(
              alignment: Alignment.centerRight,
              child: SlideTransition(
                position: _menuSlideAnimation,
                child: Container(
                  width: drawerWidth,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF7A0606),
                        forestGreen,
                        darkForest,
                        Color(0xFF5A0303),
                      ],
                    ),
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(24),
                    ),
                    border: Border(
                      left: BorderSide(
                        color: warmGold.withValues(alpha: 0.45),
                        width: 1.5,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 28,
                        offset: const Offset(-6, 0),
                      ),
                      BoxShadow(
                        color: primaryGold.withValues(alpha: 0.15),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Brand Header
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallPhone ? 16 : 20,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.18),
                            border: Border(
                              bottom: BorderSide(
                                color: warmGold.withValues(alpha: 0.25),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Yang Chow Crest
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withValues(alpha: 0.25),
                                  border: Border.all(
                                    color: warmGold.withValues(alpha: 0.5),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: warmGold.withValues(alpha: 0.2),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: Image.asset(
                                  'assets/images/ycplogo.png',
                                  height: 38,
                                  width: 38,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Titles
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'YANG CHOW',
                                      style: GoogleFonts.cinzel(
                                        color: warmGold,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'AUTHENTIC DINING',
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFFFFE8B2),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Frosted Close Button
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.1),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    width: 1,
                                  ),
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  onPressed: _toggleMobileMenu,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Section Label
                        Padding(
                          padding: const EdgeInsets.only(left: 22, top: 14, bottom: 6),
                          child: Text(
                            'NAVIGATION',
                            style: GoogleFonts.poppins(
                              color: warmGold.withValues(alpha: 0.8),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),

                        // Navigation Links
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 4,
                              ),
                              child: Column(
                                children: [
                                  _mobileMenuItem(
                                    Icons.home_rounded,
                                    'Home',
                                    _scrollToTop,
                                  ),
                                  _mobileMenuItem(
                                    Icons.info_outline_rounded,
                                    'About Us',
                                    () => _scrollToSection(_aboutKey),
                                  ),
                                  _mobileMenuItem(
                                    Icons.restaurant_menu_rounded,
                                    'Food Menu',
                                    () => _scrollToSection(_menuKey),
                                  ),
                                  _mobileMenuItem(
                                    Icons.campaign_rounded,
                                    'Announcements',
                                    () => _scrollToSection(_updatesKey),
                                  ),
                                  _mobileMenuItem(
                                    Icons.room_service_rounded,
                                    'Services & Events',
                                    () => _scrollToSection(_servicesKey),
                                  ),
                                  _mobileMenuItem(
                                    Icons.star_rate_rounded,
                                    'Customer Reviews',
                                    () => _scrollToSection(_reviewsKey),
                                  ),
                                  _mobileMenuItem(
                                    Icons.map_rounded,
                                    'Location & Route',
                                    () => _scrollToSection(_mapKey),
                                  ),
                                  _mobileMenuItem(
                                    Icons.phone_in_talk_rounded,
                                    'Contact Us',
                                    () => _scrollToSection(_contactKey),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Bottom Action Container
                        Container(
                          padding: EdgeInsets.all(isSmallPhone ? 14 : 16),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.22),
                            border: Border(
                              top: BorderSide(
                                color: warmGold.withValues(alpha: 0.25),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Container(
                            width: double.infinity,
                            height: 46,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  forestGreen,
                                  Color(0xFFBA1717),
                                  darkForest,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: warmGold.withValues(alpha: 0.65),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  _toggleMobileMenu();
                                  Navigator.pushNamed(context, '/login');
                                },
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.person_rounded,
                                        size: 17,
                                        color: warmGold,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Customer Sign In / Join',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFFFFFAEB),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
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
          ],
        ),
      ),
    );
  }

  Widget _mobileMenuItem(IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: warmGold.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Icon pill
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: warmGold.withValues(alpha: 0.12),
                    border: Border.all(
                      color: warmGold.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(icon, color: warmGold, size: 16),
                ),
                const SizedBox(width: 12),

                // Title
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFFFFAEB),
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),

                // Arrow indicator
                Icon(
                  Icons.chevron_right_rounded,
                  color: warmGold.withValues(alpha: 0.5),
                  size: 19,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScrollToTopButton() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      bottom: _showScrollToTop ? 28 : -80,
      right: 28,
      child: FloatingActionButton(
        onPressed: _scrollToTop,
        backgroundColor: primaryGold,
        foregroundColor: AppTheme.darkBrownText,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.arrow_upward_rounded),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HERO SECTION
  // ---------------------------------------------------------------------------

  Widget _buildHeroSection(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: darkForest,
        image: DecorationImage(
          image: AssetImage('assets/images/bg.png'),
          fit: BoxFit.cover,
          opacity: 0.12,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              darkForest.withValues(alpha: 0.75),
              forestGreen.withValues(alpha: 0.95),
              darkForest,
            ],
          ),
        ),
        padding: EdgeInsets.only(
          top: isMobile ? 110 : 150,
          bottom: isMobile ? 60 : 90,
          left: isMobile ? 20 : 48,
          right: isMobile ? 20 : 48,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: isMobile || isTablet
                    ? _buildHeroMobileContent()
                    : _buildHeroDesktopContent(isTablet),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroDesktopContent(bool isTablet) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left Column: Headline & Action
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge Tag
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: activeEmerald.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: warmGold.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stars_rounded,
                            color: warmGold, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Authentic Asian Cuisine • Pagsanjan, Laguna',
                          style: GoogleFonts.plusJakartaSans(
                            color: warmGold,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Main Headline
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 54,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                        color: Colors.white,
                      ),
                      children: [
                        const TextSpan(text: 'Experience the '),
                        TextSpan(
                          text: 'Authentic Taste ',
                          style: TextStyle(
                            color: warmGold,
                            shadows: [
                              Shadow(
                                color: warmGold.withValues(alpha: 0.3),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                        ),
                        const TextSpan(text: 'of Yang Chow Pagsanjan'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Description
                  Text(
                    'Savor hand-crafted Dimsum, signature Yang Chow Fried Rice, rich savory dishes, and seamless online table reservations with our integrated Restaurant Management System (YCPRMS).',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.sidebarSubtitle,
                      fontSize: 16,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Action Buttons
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: AppTheme.goldGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: primaryGold.withValues(alpha: 0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            )
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () => _scrollToSection(_menuKey),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: AppTheme.darkBrownText,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Explore Menu',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.darkBrownText,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Icon(Icons.arrow_forward_rounded,
                                  size: 20, color: AppTheme.darkBrownText),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 48),

            // Right Column: Showcase Card Grid
            Expanded(
              flex: 5,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 420,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        colors: [
                          activeEmerald.withValues(alpha: 0.5),
                          Colors.transparent
                        ],
                      ),
                      border: Border.all(
                        color: warmGold.withValues(alpha: 0.25),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: _buildHeroShowcaseImage(),
                    ),
                  ),

                  // Floating Specialty Badge
                  Positioned(
                    top: -20,
                    right: -20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: activeEmerald,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: warmGold.withValues(alpha: 0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: forestGreen.withValues(alpha: 0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.outdoor_grill_rounded,
                              color: warmGold, size: 24),
                          const SizedBox(width: 10),
                          Text(
                            'Freshly Cooked Daily',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
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
        ),
      ],
    );
  }

  Widget _buildHeroShowcaseImage() {
    final featuredItem = _featuredMenuItems.isNotEmpty
        ? _featuredMenuItems[_currentHeroIndex % _featuredMenuItems.length]
        : null;

    final imageUrl = featuredItem != null
        ? MenuService.resolveImageUrl(
            featuredItem.customImagePath ?? featuredItem.fallbackImagePath)
        : null;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Animated Cross-Fade Image Switcher
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 700),
          switchInCurve: Curves.easeIn,
          switchOutCurve: Curves.easeOut,
          child: Container(
            key: ValueKey<int>(
                _featuredMenuItems.isNotEmpty ? _currentHeroIndex : -1),
            width: double.infinity,
            height: double.infinity,
            child: imageUrl != null && imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (_, __, ___) => Image.asset(
                      'assets/images/YangChow.jpg',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) => Container(
                        color: activeEmerald,
                        child: const Icon(Icons.restaurant,
                            color: warmGold, size: 80),
                      ),
                    ),
                  )
                : Image.asset(
                    'assets/images/YangChow.jpg',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (_, __, ___) => Container(
                      color: activeEmerald,
                      child: const Icon(Icons.restaurant,
                          color: warmGold, size: 80),
                    ),
                  ),
          ),
        ),

        // Live Dynamic Dish Tag Overlay & Carousel Indicators
        if (featuredItem != null)
          Positioned(
            bottom: 12,
            left: 12,
            // Removed right: 12 to prevent stretching
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: forestGreen.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: warmGold.withValues(alpha: 0.4)),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.auto_awesome_rounded,
                                  color: warmGold, size: 13),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'FEATURED SPECIAL (${(_currentHeroIndex % _featuredMenuItems.length) + 1}/${_featuredMenuItems.length})',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: warmGold,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.1,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            featuredItem.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: activeEmerald,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: warmGold.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        '₱${featuredItem.price.toStringAsFixed(2)}',
                        style: GoogleFonts.plusJakartaSans(
                          color: warmGold,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeroMobileContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: activeEmerald.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: warmGold.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.stars_rounded, color: warmGold, size: 16),
              const SizedBox(width: 6),
              Text(
                'Authentic Asian • Pagsanjan, Laguna',
                style: GoogleFonts.plusJakartaSans(
                  color: warmGold,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Text(
          'Authentic Yang Chow Dining',
          style: GoogleFonts.playfairDisplay(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),

        Text(
          'Savor hand-crafted Dimsum, signature Yang Chow Fried Rice, rich savory dishes, and online table reservations.',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.sidebarSubtitle,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: Container(
            decoration: BoxDecoration(
              gradient: AppTheme.goldGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              onPressed: () => _scrollToSection(_menuKey),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: AppTheme.darkBrownText,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Explore Menu',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppTheme.darkBrownText,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 28),

        // Auto-Rotating Hero Showcase Card for Mobile Phones
        Container(
          height: 260,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                activeEmerald.withValues(alpha: 0.5),
                Colors.transparent
              ],
            ),
            border: Border.all(
              color: warmGold.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: _buildHeroShowcaseImage(),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ABOUT SECTION
  // ---------------------------------------------------------------------------

  Widget _buildAboutSection(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 60 : 100,
        horizontal: isMobile ? 20 : 48,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            children: [
              // Section Header Tag
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: forestGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: forestGreen.withValues(alpha: 0.2)),
                ),
                child: Text(
                  'OUR HERITAGE & PASSION',
                  style: GoogleFonts.plusJakartaSans(
                    color: forestGreen,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Text(
                'Welcome to Yang Chow Pagsanjan',
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                  fontSize: isMobile ? 28 : 40,
                  fontWeight: FontWeight.bold,
                  color: darkGreyText,
                ),
              ),
              const SizedBox(height: 16),

              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Text(
                  'Bringing authentic Asian flavors, traditional culinary mastery, and modern dining experiences right to the heart of Pagsanjan, Laguna.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    color: AppTheme.mediumGrey,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 50),

              if (isMobile)
                Column(
                  children: [
                    _buildAboutImageGrid(),
                    const SizedBox(height: 40),
                    _buildAboutTextBlock(),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 5, child: _buildAboutImageGrid()),
                    const SizedBox(width: 60),
                    Expanded(flex: 6, child: _buildAboutTextBlock()),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAboutImageGrid() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Image.asset(
              'assets/images/Yang.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppTheme.lightGrey,
                child: const Icon(Icons.restaurant, size: 60, color: Colors.grey),
              ),
            ),
          ),
        ),

        // Small Overlay Card
        Positioned(
          bottom: -20,
          right: -10,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: forestGreen,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: warmGold.withValues(alpha: 0.3)),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 15,
                  offset: Offset(0, 5),
                )
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: activeEmerald,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_rounded,
                      color: warmGold, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '100% Quality Guaranteed',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'Fresh Ingredients Daily',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.sidebarSubtitle,
                        fontSize: 11,
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAboutTextBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Crafted with Tradition, Served with Hospitality',
          style: GoogleFonts.playfairDisplay(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: darkGreyText,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'At Yang Chow Pagsanjan, we take immense pride in crafting authentic Asian delights using time-honored recipes, premium fresh ingredients, and passionate culinary artistry.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            color: AppTheme.mediumGrey,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 28),

        _buildAboutFeature(
          Icons.restaurant_rounded,
          'Authentic Recipes',
          'Prepared by skilled chefs maintaining authentic Cantonese and Asian flavors.',
        ),
        const SizedBox(height: 18),
        _buildAboutFeature(
          Icons.eco_rounded,
          'Fresh & Quality Ingredients',
          'We source premium meats, seafood, and vegetables daily for optimal taste.',
        ),
        const SizedBox(height: 18),
        _buildAboutFeature(
          Icons.phonelink_ring_rounded,
          'Modern YCPRMS Reservation & POS',
          'Enjoy seamless online reservations and advance ordering.',
        ),
      ],
    );
  }

  Widget _buildAboutFeature(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: forestGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: forestGreen, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: darkGreyText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppTheme.mediumGrey,
                  height: 1.4,
                ),
              ),
            ],
          ),
        )
      ],
    );
  }



  // ---------------------------------------------------------------------------
  // INTERACTIVE FOOD MENU SECTION
  // ---------------------------------------------------------------------------

  Widget _buildMenuSection(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    // Filter items based on category & search query
    List<MenuItem> displayedItems = [];
    if (_menuSelectedCategory == 'All') {
      _menuData.forEach((_, items) => displayedItems.addAll(items));
    } else {
      displayedItems = _menuData[_menuSelectedCategory] ?? [];
    }

    if (_menuSearchQuery.isNotEmpty) {
      displayedItems = displayedItems
          .where((item) =>
              item.name.toLowerCase().contains(_menuSearchQuery.toLowerCase()) ||
              (item.description != null &&
                  item.description!
                      .toLowerCase()
                      .contains(_menuSearchQuery.toLowerCase())))
          .toList();
    }

    return Container(
      width: double.infinity,
      color: creamBg,
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 60 : 100,
        horizontal: isMobile ? 16 : 48,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            children: [
              // Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: forestGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'DELICIOUS SELECTIONS',
                  style: GoogleFonts.plusJakartaSans(
                    color: forestGreen,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Text(
                'Explore Our Culinary Menu',
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                  fontSize: isMobile ? 28 : 40,
                  fontWeight: FontWeight.bold,
                  color: darkGreyText,
                ),
              ),
              const SizedBox(height: 24),

              // Search & Category Filters Bar
              _buildMenuSearch(context),
              const SizedBox(height: 20),
              _buildMenuCategories(context),
              const SizedBox(height: 36),

              // Menu Items Horizontal Scrollable Carousel
              if (displayedItems.isEmpty)
                Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.search_off_rounded,
                          size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(
                        'No dishes found matching your search',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: AppTheme.mediumGrey,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          height: 330,
                          child: ListView.builder(
                            controller: _menuScrollController,
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            itemCount: displayedItems.length,
                            itemBuilder: (context, index) {
                              return Container(
                                width: 260,
                                margin: const EdgeInsets.only(right: 18),
                                child: _buildMenuCard(context, displayedItems[index]),
                              );
                            },
                          ),
                        ),

                        // Left Scroll Arrow (Desktop / Laptop)
                        if (!isMobile)
                          Positioned(
                            left: -20,
                            child: Material(
                              color: Colors.white,
                              shape: const CircleBorder(),
                              elevation: 6,
                              child: InkWell(
                                onTap: () => _scrollCarousel(-300),
                                customBorder: const CircleBorder(),
                                child: const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Icon(Icons.arrow_back_ios_new_rounded,
                                      color: forestGreen, size: 20),
                                ),
                              ),
                            ),
                          ),

                        // Right Scroll Arrow (Desktop / Laptop)
                        if (!isMobile)
                          Positioned(
                            right: -20,
                            child: Material(
                              color: Colors.white,
                              shape: const CircleBorder(),
                              elevation: 6,
                              child: InkWell(
                                onTap: () => _scrollCarousel(300),
                                customBorder: const CircleBorder(),
                                child: const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Icon(Icons.arrow_forward_ios_rounded,
                                      color: forestGreen, size: 20),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Swipe/Scroll Indicator Hint
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.swipe_left_rounded,
                            color: forestGreen, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Swipe or use navigation arrows to explore dishes',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.mediumGrey,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _scrollCarousel(double offset) {
    if (_menuScrollController.hasClients) {
      final target = _menuScrollController.offset + offset;
      _menuScrollController.animateTo(
        target.clamp(0.0, _menuScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildMenuSearch(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: TextField(
        onChanged: (val) => setState(() => _menuSearchQuery = val),
        style: GoogleFonts.plusJakartaSans(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search dishes, dimsum, fried rice...',
          prefixIcon: const Icon(Icons.search_rounded, color: forestGreen),
          suffixIcon: _menuSearchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () => setState(() => _menuSearchQuery = ''),
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: AppTheme.cardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: forestGreen, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCategories(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _menuCategories.map((cat) {
          bool isSelected = _menuSelectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ChoiceChip(
              label: Text(cat),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _menuSelectedCategory = cat);
                }
              },
              selectedColor: forestGreen,
              backgroundColor: Colors.white,
              labelStyle: GoogleFonts.plusJakartaSans(
                color: isSelected ? Colors.white : darkGreyText,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 13,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: isSelected ? forestGreen : AppTheme.cardBorder,
                ),
              ),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, MenuItem item) {
    final imageUrl =
        MenuService.resolveImageUrl(item.customImagePath ?? item.fallbackImagePath);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dish Image with Tag
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppTheme.lightGrey,
                          child: const Icon(Icons.restaurant,
                              size: 40, color: Colors.grey),
                        );
                      },
                    ),
                  ),

                  // Category Badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: forestGreen.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        item.category,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Details
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: darkGreyText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.description ??
                              'Authentic Yang Chow recipe prepared fresh daily.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppTheme.mediumGrey,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),

                    // Price & Action Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₱${item.price.toStringAsFixed(2)}',
                          style: GoogleFonts.plusJakartaSans(
                            color: forestGreen,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        InkWell(
                          onTap: () =>
                              _showMenuItemDetailsDialog(context, item),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: forestGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'Details',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: forestGreen,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right_rounded,
                                    color: forestGreen, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMenuItemDetailsDialog(BuildContext context, MenuItem item) {
    final imageUrl =
        MenuService.resolveImageUrl(item.customImagePath ?? item.fallbackImagePath);
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 580),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: darkGreyText,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: AppTheme.lightGrey,
                            child: const Icon(Icons.restaurant,
                                size: 64, color: Colors.grey),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: forestGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          item.category,
                          style: GoogleFonts.plusJakartaSans(
                            color: forestGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.lightGrey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '₱${item.price.toStringAsFixed(2)}',
                          style: GoogleFonts.plusJakartaSans(
                            color: forestGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Description',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: darkGreyText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.description ??
                        'Authentic Yang Chow recipe, prepared with fresh ingredients and our secret blend of spices.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: AppTheme.mediumGrey,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Recipe & Ingredients Info',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: darkGreyText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<List<dynamic>>(
                    future: Supabase.instance.client
                        .from('recipe_ingredients')
                        .select()
                        .eq('menu_item_name', item.name),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: forestGreen,
                            ),
                          ),
                        );
                      }
                      if (snapshot.hasError ||
                          snapshot.data == null ||
                          snapshot.data!.isEmpty) {
                        return Text(
                          'No specific ingredient list available for public view.',
                          style: GoogleFonts.plusJakartaSans(
                              color: Colors.grey.shade500, fontSize: 13),
                        );
                      }
                      final ingredientsList = snapshot.data!;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ingredientsList.map<Widget>((ing) {
                          final name = ing['name'] ?? '';
                          return Chip(
                            label: Text(
                              name,
                              style: GoogleFonts.plusJakartaSans(fontSize: 12),
                            ),
                            backgroundColor: creamBg,
                            side: const BorderSide(color: warmGold),
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // UPDATES & ANNOUNCEMENTS SECTION
  // ---------------------------------------------------------------------------

  Widget _buildUpdatesSection(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Container(
      width: double.infinity,
      color: const Color(0xFFF9F6F0),
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 60 : 100,
        horizontal: isMobile ? 20 : 48,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            children: [
              // Section Header (Centered)
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: forestGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'LATEST ANNOUNCEMENTS',
                      style: GoogleFonts.plusJakartaSans(
                        color: forestGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'News & Special Promo Updates',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: isMobile ? 26 : 38,
                      fontWeight: FontWeight.bold,
                      color: darkGreyText,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),

              if (_announcements.isEmpty)
                _buildUpdateCard({
                  'title': 'Grand Opening & Special Dimsum Family Meals',
                  'content':
                      'Visit Yang Chow Pagsanjan at CLA Town Center Mall for daily authentic Asian dining specials & family bundles! Enjoy our signature Dimsum platter deals and more.',
                  'created_at': DateTime.now().toIso8601String(),
                })
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _announcements.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 24),
                  itemBuilder: (context, index) {
                    return _buildUpdateCard(_announcements[index]);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateCard(Map<String, dynamic> item) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    final title = item['title'] ?? 'Announcement';
    final content = item['content'] ?? '';
    final createdAt = item['created_at'] != null
        ? DateFormat('MMM dd, yyyy')
            .format(DateTime.parse(item['created_at'].toString()))
        : 'Recent';
    final day = item['created_at'] != null
        ? DateFormat('dd').format(DateTime.parse(item['created_at'].toString()))
        : '—';
    final monthYear = item['created_at'] != null
        ? DateFormat('MMM yyyy')
            .format(DateTime.parse(item['created_at'].toString()))
        : '';

    // Use image_url directly — announcement images are always plain external URLs.
    // Skip resolveImageUrl to avoid Unsplash/Supabase path conversion breaking direct links.
    final rawImage = (item['image_url'] ?? '').toString().trim();
    final hasImage = rawImage.isNotEmpty;

    Widget imageWidget = hasImage
        ? Image.network(
            rawImage,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: const Color(0xFFF0EDE6),
                child: const Center(
                  child: CircularProgressIndicator(
                      color: forestGreen, strokeWidth: 2),
                ),
              );
            },
            errorBuilder: (_, __, ___) => _announcementImageFallback(),
          )
        : _announcementImageFallback();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEAE5D8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image on top for mobile
                  SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: imageWidget,
                  ),
                  _buildUpdateCardBody(
                      title, content, createdAt, day, monthYear),
                ],
              )
            : SizedBox(
                height: 260,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left: Image column (fixed width, fills height)
                    SizedBox(
                      width: 280,
                      child: imageWidget,
                    ),

                    // Right: Content column
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: _buildUpdateCardBody(
                            title, content, createdAt, day, monthYear),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _announcementImageFallback() {
    return Container(
      color: activeEmerald,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/YangChow.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          Container(
            color: forestGreen.withValues(alpha: 0.55),
            child: const Center(
              child: Icon(Icons.campaign_rounded, color: warmGold, size: 48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateCardBody(String title, String content, String createdAt,
      String day, String monthYear) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: warmGold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            size: 12, color: primaryGold),
                        const SizedBox(width: 5),
                        Text(
                          createdAt,
                          style: GoogleFonts.plusJakartaSans(
                            color: primaryGold,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: forestGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.campaign_rounded,
                            size: 12, color: forestGreen),
                        const SizedBox(width: 5),
                        Text(
                          'Announcement',
                          style: GoogleFonts.plusJakartaSans(
                            color: forestGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Title
              Text(
                title,
                style: GoogleFonts.playfairDisplay(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: darkGreyText,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),

              // Divider
              Container(
                height: 2,
                width: 48,
                decoration: BoxDecoration(
                  color: warmGold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),

              // Content
              Text(
                content,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: AppTheme.mediumGrey,
                  height: 1.6,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Footer row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: forestGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.store_rounded,
                    color: warmGold, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                'Yang Chow Pagsanjan',
                style: GoogleFonts.plusJakartaSans(
                  color: forestGreen,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SERVICES SECTION
  // ---------------------------------------------------------------------------

  Widget _buildServicesSection(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return _DraggableServicesSection(isMobile: isMobile);
  }

  // ---------------------------------------------------------------------------
  // CUSTOMER REVIEWS SECTION
  // ---------------------------------------------------------------------------

  Widget _buildReviewsSection(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    final defaultReviews = [
      {
        'name': 'Maria Santos',
        'rating': 5.0,
        'comment':
            'The Yang Chow Fried Rice and Dimsum are top-tier! Generous portions, fast service, and super fresh. Will definitely order again!',
        'date': '2 days ago',
        'dish': 'Yang Chow Fried Rice & Hakao',
      },
      {
        'name': 'John Robert Tan',
        'rating': 5.0,
        'comment':
            'Best Lechon Macau in Laguna! Crisp skin and very tender meat. Online table reservation saved us from waiting in long queues.',
        'date': '3 days ago',
        'dish': 'Lechon Macau & Cold Cut Platter',
      },
      {
        'name': 'Liza Ramos',
        'rating': 5.0,
        'comment':
            'Hosted my mom\'s 60th birthday here. Staff was very attentive, food came out hot and quick. Family bundles are worth every peso!',
        'date': '5 days ago',
        'dish': 'Chinese Family Feast Bundle',
      },
      {
        'name': 'Kevin Dela Cruz',
        'rating': 5.0,
        'comment':
            'Super easy advance pick-up ordering! Picked up my dinner right on time after work. Hot, fresh, and delicious as always.',
        'date': '1 week ago',
        'dish': 'Dimsum Platter & Sweet & Sour Pork',
      },
      {
        'name': 'Dr. Arlene Mercado',
        'rating': 5.0,
        'comment':
            'Authentic Cantonese flavors right in Pagsanjan! Highly recommend the Steamed Siomai and Beef Broccoli. The place is always clean.',
        'date': '1 week ago',
        'dish': 'Steamed Siomai & Beef Broccoli',
      },
      {
        'name': 'Mark Anthony Cruz',
        'rating': 5.0,
        'comment':
            'Great ambiance and excellent service. Table booking was seamless through the web app. Will bring our relatives next time!',
        'date': '2 weeks ago',
        'dish': 'Chow Mien & Sweet & Sour Pork',
      },
      {
        'name': 'Carla Dizon',
        'rating': 5.0,
        'comment':
            'Office lunch was perfect! Ordered advance para naka ready na pagdating namin. Ang sarap ng Dimsum at Congee combination!',
        'date': '2 weeks ago',
        'dish': 'Dimsum Set & Chicken Congee',
      },
      {
        'name': 'Rodel Pascual',
        'rating': 5.0,
        'comment':
            'Anniversary dinner here was unforgettable. Dalawa kaming nag-dine at sobrang worth it sa presyo. Magbabalik kami!',
        'date': '3 weeks ago',
        'dish': 'Peking Duck & Yang Chow Fried Rice',
      },
    ];

    final displayReviews = _reviews.isNotEmpty ? _reviews : defaultReviews;

    return Container(
      width: double.infinity,
      color: creamBg,
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 60 : 100,
        horizontal: isMobile ? 16 : 48,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            children: [
              // Badge Tag
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: warmGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: warmGold.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, color: primaryGold, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'VERIFIED GUEST FEEDBACK',
                      style: GoogleFonts.plusJakartaSans(
                        color: darkGreyText,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              Text(
                'What Our Guests Say',
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                  fontSize: isMobile ? 32 : 44,
                  fontWeight: FontWeight.bold,
                  color: darkGreyText,
                ),
              ),
              const SizedBox(height: 10),

              Text(
                'Real dining experiences and reviews from our valued customers.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isMobile ? 14 : 15,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 36),

              _buildOverallRating(),
              const SizedBox(height: 48),

              // Auto-scrolling Review Carousel
              SizedBox(
                height: 250,
                child: ListView.builder(
                  controller: _reviewsScrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: displayReviews.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 20, top: 8, bottom: 8),
                      child: _LandingReviewCard(review: displayReviews[index]),
                    );
                  },
                ),
              ),

              const SizedBox(height: 32),

              // View All Verified Reviews Button
              OutlinedButton.icon(
                onPressed: () => _showAllReviewsDialog(context, displayReviews),
                icon: const Icon(Icons.rate_review_rounded, color: darkGreyText, size: 18),
                label: Text(
                  'View All Verified Reviews (${_totalReviewCount > 0 ? _totalReviewCount : '150+'})',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: darkGreyText,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  side: BorderSide(color: warmGold.withValues(alpha: 0.8), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  backgroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverallRating() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      decoration: BoxDecoration(
        color: forestGreen,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: warmGold.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: forestGreen.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 16,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _averageRating > 0 ? _averageRating.toStringAsFixed(1) : '4.9',
                style: GoogleFonts.playfairDisplay(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 40,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: List.generate(5, (index) {
                      return const Icon(
                        Icons.star_rounded,
                        color: warmGold,
                        size: 22,
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Based on ${_totalReviewCount > 0 ? _totalReviewCount : '150+'} verified guest reviews',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white70,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            height: 36,
            width: 1,
            color: Colors.white24,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _trustPill(Icons.verified_rounded, '98% Recommended'),
              const SizedBox(width: 12),
              _trustPill(Icons.thumb_up_alt_rounded, 'Top Dining Choice'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _trustPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: activeEmerald.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: warmGold.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: warmGold, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showAllReviewsDialog(
      BuildContext context, List<Map<String, dynamic>> reviews) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => _AllReviewsDialog(
        reviews: reviews,
        averageRating: _averageRating > 0 ? _averageRating : 4.9,
        totalCount: _totalReviewCount > 0 ? _totalReviewCount : 150,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // INTERACTIVE LOCATION MAP SECTION
  // ---------------------------------------------------------------------------

  Widget _buildMapSection(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 60 : 100,
        horizontal: isMobile ? 16 : 48,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: forestGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'FIND US IN PAGSANJAN',
                  style: GoogleFonts.plusJakartaSans(
                    color: forestGreen,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Text(
                'Visit Yang Chow Restaurant',
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                  fontSize: isMobile ? 28 : 40,
                  fontWeight: FontWeight.bold,
                  color: darkGreyText,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'CLA Town Center Mall, Pagsanjan, Laguna, Philippines 4008',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.mediumGrey,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 36),

              // Map Container with Overlays
              Container(
                height: 480,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      // FlutterMap Layer
                      FlutterMap(
                        mapController: _mapController,
                        options: const MapOptions(
                          initialCenter: _restaurantLocation,
                          initialZoom: 15.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: _isSatelliteMode
                                ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                                : 'https://tile.openstreetmap.org/{z}/{y}/{x}.png',
                            userAgentPackageName: 'com.yangchow.app',
                          ),
                          if (_routePoints.isNotEmpty)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: _routePoints,
                                  strokeWidth: 4.5,
                                  color: forestGreen,
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: [
                              // Yang Chow Marker
                              Marker(
                                point: _restaurantLocation,
                                width: 50,
                                height: 50,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: forestGreen,
                                    shape: BoxShape.circle,
                                    boxShadow: const [
                                      BoxShadow(
                                          color: Colors.black38,
                                          blurRadius: 10)
                                    ],
                                    border: Border.all(
                                        color: warmGold, width: 2),
                                  ),
                                  child: const Icon(
                                    Icons.restaurant_rounded,
                                    color: warmGold,
                                    size: 26,
                                  ),
                                ),
                              ),

                              // User Location Marker
                              if (_userLocation != null)
                                Marker(
                                  point: _userLocation!,
                                  width: 40,
                                  height: 40,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: primaryGold,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(
                                      Icons.person_pin_circle_rounded,
                                      color: AppTheme.darkBrownText,
                                      size: 22,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),

                      // Overlay Controls Panel
                      Positioned(
                        top: 16,
                        left: 16,
                        right: 16,
                        child: Row(
                          children: [
                            Expanded(
                              child: _showDirectionsPanel
                                  ? _buildDirectionsPanel()
                                  : _buildSimpleSearchBar(),
                            ),
                          ],
                        ),
                      ),

                      // Floating Map Action Buttons
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: Column(
                          children: [
                            FloatingActionButton.small(
                              heroTag: 'sat_btn',
                              onPressed: () => setState(
                                  () => _isSatelliteMode = !_isSatelliteMode),
                              backgroundColor: Colors.white,
                              foregroundColor: darkGreyText,
                              child: Icon(_isSatelliteMode
                                  ? Icons.map_rounded
                                  : Icons.satellite_alt_rounded),
                            ),
                            const SizedBox(height: 8),
                            FloatingActionButton.small(
                              heroTag: 'loc_btn',
                              onPressed: _getCurrentLocation,
                              backgroundColor: Colors.white,
                              foregroundColor: forestGreen,
                              child: const Icon(Icons.my_location_rounded),
                            ),
                          ],
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
  }

  Widget _buildSimpleSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: forestGreen),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _mapSearchController,
              onSubmitted: _searchPlace,
              style: GoogleFonts.plusJakartaSans(fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search location on map...',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.directions_rounded, color: forestGreen),
            onPressed: () => setState(() => _showDirectionsPanel = true),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionsPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 15)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Get Directions',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.swap_vert_rounded, color: forestGreen),
                    onPressed: _swapRoutingPoints,
                    tooltip: 'Swap start & destination',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => setState(() => _showDirectionsPanel = false),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildRoutingTextField(
            controller: _startPointController,
            hint: 'Starting Point (Your location)',
            icon: Icons.my_location_rounded,
          ),
          const SizedBox(height: 8),
          _buildRoutingTextField(
            controller: _destinationController,
            hint: 'Destination (Yang Chow)',
            icon: Icons.location_on_rounded,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isRouting ? null : _getRoute,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: forestGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isRouting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text('Find Route',
                          style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildRoutingTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: GoogleFonts.plusJakartaSans(fontSize: 13),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 18, color: forestGreen),
        hintText: hint,
        filled: true,
        fillColor: AppTheme.lightGrey,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CONTACT & FOOTER SECTION
  // ---------------------------------------------------------------------------

  Widget _buildContactFooterSection(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Container(
      width: double.infinity,
      color: darkForest,
      padding: EdgeInsets.only(
        top: isMobile ? 60 : 80,
        bottom: 30,
        left: isMobile ? 20 : 48,
        right: isMobile ? 20 : 48,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            children: [
              // Contact Blocks Row
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 800) {
                    return Column(
                      children: [
                        _buildContactItem(
                          Icons.location_on_rounded,
                          'Our Location',
                          'CLA Town Center Mall\nPagsanjan, Laguna, Philippines 4008',
                        ),
                        const SizedBox(height: 24),
                        _buildContactItem(
                          Icons.schedule_rounded,
                          'Opening Hours',
                          'Monday - Sunday\n10:00 AM - 08:00 PM',
                        ),
                        const SizedBox(height: 24),
                        _buildContactItem(
                          Icons.phone_rounded,
                          'Call Us',
                          'TEL# 501-9179\nCP# 0975-041-9671',
                        ),
                        const SizedBox(height: 24),
                        _buildContactItem(
                          Icons.email_rounded,
                          'Email Us',
                          'admn.pagsanjan@gmail.com',
                        ),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildContactItem(
                          Icons.location_on_rounded,
                          'Our Location',
                          'CLA Town Center Mall\nPagsanjan, Laguna, Philippines 4008',
                        ),
                      ),
                      Expanded(
                        child: _buildContactItem(
                          Icons.schedule_rounded,
                          'Opening Hours',
                          'Monday - Sunday\n10:00 AM - 08:00 PM',
                        ),
                      ),
                      Expanded(
                        child: _buildContactItem(
                          Icons.phone_rounded,
                          'Call Us',
                          'TEL# 501-9179\nCP# 0975-041-9671',
                        ),
                      ),
                      Expanded(
                        child: _buildContactItem(
                          Icons.email_rounded,
                          'Email Us',
                          'admn.pagsanjan@gmail.com',
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 60),
              const Divider(color: Colors.white12),
              const SizedBox(height: 30),

              // Footer Bottom Info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '© ${DateTime.now().year} Yang Chow Pagsanjan (YCPRMS). All rights reserved.',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.sidebarSubtitle,
                      fontSize: 12,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.facebook_rounded,
                            color: Colors.white60, size: 20),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(Icons.language_rounded,
                            color: Colors.white60, size: 20),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: activeEmerald,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: warmGold.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: warmGold, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.sidebarSubtitle,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DRAGGABLE SERVICES SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _DraggableServicesSection extends StatefulWidget {
  final bool isMobile;
  const _DraggableServicesSection({required this.isMobile});

  @override
  State<_DraggableServicesSection> createState() =>
      _DraggableServicesSectionState();
}

class _DraggableServicesSectionState
    extends State<_DraggableServicesSection> {
  late List<_ServiceData> _items;
  int? _draggedIndex;

  @override
  void initState() {
    super.initState();
    _items = [
      _ServiceData(
        number: '01',
        icon: Icons.restaurant_rounded,
        title: 'Dine-In Experience',
        description:
            'Enjoy a premium dining atmosphere with attentive service, elegant table settings, and an extensive menu crafted for every occasion.',
        tag: 'Attentive Service',
      ),
      _ServiceData(
        number: '02',
        icon: Icons.celebration_rounded,
        title: 'Private Events',
        description:
            'Planning a birthday, reunion, or corporate event? We offer tailored catering packages and exclusive private dining spaces.',
        tag: 'Catering & Packages',
      ),
      _ServiceData(
        number: '03',
        icon: Icons.takeout_dining_rounded,
        title: 'Takeout or Pickup',
        description:
            'Prefer dining at home? Order your favorites physically to takehome or advance order by online to freshly prepared and ready for pickup.',
        tag: 'Freshly Prepared',
      ),
      _ServiceData(
        number: '04',
        icon: Icons.event_seat_rounded,
        title: 'Reservation System',
        description:
            'Skip the wait reserve a table in advance through our quick and easy online booking system. Available 7 days a week.',
        tag: 'Skip The Wait',
      ),
    ];
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
      for (int i = 0; i < _items.length; i++) {
        _items[i] = _ServiceData(
          number: '0${i + 1}',
          icon: _items[i].icon,
          title: _items[i].title,
          description: _items[i].description,
          tag: _items[i].tag,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _LandingPageState.creamBg,
      padding: EdgeInsets.symmetric(
        vertical: widget.isMobile ? 60 : 100,
        horizontal: widget.isMobile ? 20 : 48,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            children: [
              // Badge Pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color:
                      _LandingPageState.warmGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _LandingPageState.warmGold
                          .withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded,
                        color: _LandingPageState.primaryGold, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'EXCELLENCE IN SERVICE',
                      style: GoogleFonts.plusJakartaSans(
                        color: _LandingPageState.darkGreyText,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              Text(
                'Services We Offer',
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                  fontSize: widget.isMobile ? 32 : 44,
                  fontWeight: FontWeight.bold,
                  color: _LandingPageState.darkGreyText,
                ),
              ),
              const SizedBox(height: 10),

              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Text(
                  'Experience authentic Asian dining with our end-to-end digital ordering, online table reservations, and premium event catering solutions.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: widget.isMobile ? 14 : 15,
                    color: const Color(0xFF64748B),
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Drag hint
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.drag_indicator_rounded,
                      size: 14,
                      color: _LandingPageState.warmGold
                          .withValues(alpha: 0.7)),
                  const SizedBox(width: 5),
                  Text(
                    'Drag cards to reorder',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: const Color(0xFF94A3B8),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),

              // Draggable cards
              LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth > 900;
                  final isTablet = constraints.maxWidth > 580;

                  if (isDesktop || isTablet) {
                    return _buildDesktopDraggableRow(isDesktop, constraints);
                  } else {
                    return _buildMobileReorderableList();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopDraggableRow(
      bool isDesktop, BoxConstraints constraints) {
    const spacing = 16.0;
    final colCount = isDesktop ? 4 : 2;
    final cardWidth =
        (constraints.maxWidth - spacing * (colCount - 1)) / colCount;

    if (!isDesktop) {
      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                  width: cardWidth,
                  child: _buildDraggableTile(0, cardWidth)),
              const SizedBox(width: spacing),
              SizedBox(
                  width: cardWidth,
                  child: _buildDraggableTile(1, cardWidth)),
            ],
          ),
          const SizedBox(height: spacing),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                  width: cardWidth,
                  child: _buildDraggableTile(2, cardWidth)),
              const SizedBox(width: spacing),
              SizedBox(
                  width: cardWidth,
                  child: _buildDraggableTile(3, cardWidth)),
            ],
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(_items.length, (i) {
        return Expanded(
          child: Padding(
            padding:
                EdgeInsets.only(right: i < _items.length - 1 ? spacing : 0),
            child: _buildDraggableTile(i, null),
          ),
        );
      }),
    );
  }

  Widget _buildDraggableTile(int index, double? fixedWidth) {
    final item = _items[index];
    final isDragging = _draggedIndex == index;

    return Draggable<int>(
      data: index,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.85,
          child: SizedBox(
            width: fixedWidth ?? 260,
            child: _LandingServiceCard(item: item, isDragging: true),
          ),
        ),
      ),
      childWhenDragging: AnimatedOpacity(
        opacity: 0.25,
        duration: const Duration(milliseconds: 200),
        child: _LandingServiceCard(item: item),
      ),
      onDragStarted: () => setState(() => _draggedIndex = index),
      onDragEnd: (_) => setState(() => _draggedIndex = null),
      child: DragTarget<int>(
        onWillAcceptWithDetails: (details) => details.data != index,
        onAcceptWithDetails: (details) => _reorder(details.data, index),
        builder: (context, candidateData, rejectedData) {
          final isTarget = candidateData.isNotEmpty;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: isTarget
                  ? Border.all(
                      color: _LandingPageState.warmGold,
                      width: 2.5,
                    )
                  : null,
            ),
            child: _LandingServiceCard(
              item: item,
              isDragging: isDragging,
              isDropTarget: isTarget,
            ),
          );
        },
      ),
    );
  }

  Widget _buildMobileReorderableList() {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      // ignore: deprecated_member_use
      onReorder: _reorder,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (ctx, child) => Material(
            elevation: 12,
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            child: child,
          ),
          child: child,
        );
      },
      itemBuilder: (context, index) {
        return Padding(
          key: ValueKey(_items[index].title),
          padding: const EdgeInsets.only(bottom: 14),
          child:
              _LandingServiceCard(item: _items[index], showDragHandle: true),
        );
      },
    );
  }
}

class _ServiceData {
  final String number;
  final IconData icon;
  final String title;
  final String description;
  final String tag;

  _ServiceData({
    required this.number,
    required this.icon,
    required this.title,
    required this.description,
    required this.tag,
  });
}

class _LandingServiceCard extends StatefulWidget {
  final _ServiceData item;
  final bool isDragging;
  final bool isDropTarget;
  final bool showDragHandle;

  const _LandingServiceCard({
    required this.item,
    this.isDragging = false,
    this.isDropTarget = false,
    this.showDragHandle = false,
  });

  @override
  State<_LandingServiceCard> createState() => _LandingServiceCardState();
}

class _LandingServiceCardState extends State<_LandingServiceCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isActive = _isHovered || widget.isDragging || widget.isDropTarget;

    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        transform:
            Matrix4.translationValues(0.0, isActive && !widget.isDragging ? -6.0 : 0.0, 0.0),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: widget.isDropTarget
              ? _LandingPageState.warmGold.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isActive
                ? _LandingPageState.warmGold.withValues(alpha: 0.8)
                : _LandingPageState.warmGold.withValues(alpha: 0.25),
            width: isActive ? 2.0 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isActive
                  ? _LandingPageState.warmGold.withValues(alpha: 0.18)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: isActive ? 24 : 14,
              offset: Offset(0, isActive ? 12 : 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row (Icon + Step Number + optional drag handle)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isActive
                            ? _LandingPageState.forestGreen
                            : _LandingPageState.forestGreen
                                .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        widget.item.icon,
                        color: isActive
                            ? _LandingPageState.warmGold
                            : _LandingPageState.forestGreen,
                        size: 26,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          widget.item.number,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: isActive
                                ? _LandingPageState.primaryGold
                                : Colors.grey.shade300,
                          ),
                        ),
                        if (widget.showDragHandle) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.drag_indicator_rounded,
                            color: _LandingPageState.warmGold
                                .withValues(alpha: 0.5),
                            size: 20,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  widget.item.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: _LandingPageState.darkGreyText,
                  ),
                ),
                const SizedBox(height: 10),

                // Description
                Text(
                  widget.item.description,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    color: const Color(0xFF64748B),
                    height: 1.55,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Footer row: Tag Pill + subtle drag hint
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isActive
                        ? _LandingPageState.warmGold.withValues(alpha: 0.2)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 13,
                        color: isActive
                            ? _LandingPageState.primaryGold
                            : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        widget.item.tag,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isActive
                              ? _LandingPageState.forestGreen
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Drag grip dots
                if (!widget.showDragHandle)
                  Icon(
                    Icons.drag_indicator_rounded,
                    size: 16,
                    color: _LandingPageState.warmGold.withValues(
                        alpha: _isHovered ? 0.6 : 0.2),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LandingReviewCard extends StatefulWidget {
  final Map<String, dynamic> review;

  const _LandingReviewCard({required this.review});

  @override
  State<_LandingReviewCard> createState() => _LandingReviewCardState();
}

class _LandingReviewCardState extends State<_LandingReviewCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final name = widget.review['name'] ?? 'Verified Customer';
    final comment =
        widget.review['comment'] ?? widget.review['review_text'] ?? 'Great food!';
    final rating = (widget.review['rating'] as num?)?.toDouble() ?? 5.0;
    final date = widget.review['date'] ?? 'Verified Guest';
    final dish = widget.review['dish'] ?? 'Signature Dish';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        width: 350,
        transform: Matrix4.translationValues(0.0, _isHovered ? -6.0 : 0.0, 0.0),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: _isHovered
                ? _LandingPageState.warmGold.withValues(alpha: 0.8)
                : _LandingPageState.warmGold.withValues(alpha: 0.25),
            width: _isHovered ? 2.0 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? _LandingPageState.warmGold.withValues(alpha: 0.18)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: _isHovered ? 22 : 12,
              offset: Offset(0, _isHovered ? 10 : 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row (Avatar + Name/Verified + Stars)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: _LandingPageState.forestGreen,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'C',
                            style: GoogleFonts.plusJakartaSans(
                              color: _LandingPageState.warmGold,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  name,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: _LandingPageState.darkGreyText,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.verified_rounded,
                                  color: Color(0xFF10B981),
                                  size: 14,
                                ),
                              ],
                            ),
                            Text(
                              date,
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF94A3B8),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: List.generate(5, (i) {
                        return Icon(
                          i < rating.round()
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: _LandingPageState.warmGold,
                          size: 15,
                        );
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Review Text
                Stack(
                  children: [
                    Positioned(
                      top: -10,
                      right: 0,
                      child: Icon(
                        Icons.format_quote_rounded,
                        color: _LandingPageState.warmGold.withValues(alpha: 0.15),
                        size: 40,
                      ),
                    ),
                    Text(
                      '"$comment"',
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF334155),
                        fontSize: 13.5,
                        height: 1.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Footer Dish Pill
            Container(
              margin: const EdgeInsets.only(top: 14),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _isHovered
                    ? _LandingPageState.warmGold.withValues(alpha: 0.18)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.restaurant_menu_rounded,
                    size: 13,
                    color: _LandingPageState.primaryGold,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      dish,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _LandingPageState.forestGreen,
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
}

// ─────────────────────────────────────────────────────────────────────────────
// ALL REVIEWS MODAL DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _AllReviewsDialog extends StatefulWidget {
  final List<Map<String, dynamic>> reviews;
  final double averageRating;
  final int totalCount;

  const _AllReviewsDialog({
    required this.reviews,
    required this.averageRating,
    required this.totalCount,
  });

  @override
  State<_AllReviewsDialog> createState() => _AllReviewsDialogState();
}

class _AllReviewsDialogState extends State<_AllReviewsDialog> {
  final TextEditingController _searchController = TextEditingController();
  int _filterStars = 0; // 0 = All
  String _searchQuery = '';

  static const _cream = Color(0xFFF7F3EA);
  static const _darkRed = Color(0xFF990000);
  static const _gold = Color(0xFFFFD166);
  static const _darkText = Color(0xFF1E293B);
  static const _subText = Color(0xFF64748B);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    return widget.reviews.where((r) {
      final name = (r['name'] ?? '').toString().toLowerCase();
      final comment =
          ((r['comment'] ?? r['review_text'] ?? '')).toString().toLowerCase();
      final rating = (r['rating'] as num?)?.toDouble() ?? 5.0;
      final matchSearch = _searchQuery.isEmpty ||
          name.contains(_searchQuery.toLowerCase()) ||
          comment.contains(_searchQuery.toLowerCase());
      final matchStars =
          _filterStars == 0 || rating.round() == _filterStars;
      return matchSearch && matchStars;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 700;
    final filtered = _filtered;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 40,
        vertical: isMobile ? 20 : 40,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: isMobile ? double.infinity : 820,
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.88),
          color: _cream,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(24, 22, 16, 22),
                decoration: const BoxDecoration(
                  color: _darkRed,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Guest Reviews',
                            style: GoogleFonts.playfairDisplay(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              ...List.generate(
                                  5,
                                  (i) => Icon(
                                        Icons.star_rounded,
                                        color: _gold,
                                        size: 16,
                                      )),
                              const SizedBox(width: 8),
                              Text(
                                '${widget.averageRating.toStringAsFixed(1)}  ·  ${widget.totalCount}+ verified reviews',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white70,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white70, size: 24),
                    ),
                  ],
                ),
              ),

              // ── Search + Star Filter ─────────────────────────────────
              Container(
                color: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  children: [
                    // Search bar
                    TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'Search by name or review...',
                        hintStyle: GoogleFonts.plusJakartaSans(
                            color: _subText, fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: _subText, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded,
                                    color: _subText, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Star filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _starChip(0, 'All'),
                          _starChip(5, '★★★★★'),
                          _starChip(4, '★★★★'),
                          _starChip(3, '★★★'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Results label ────────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Text(
                      '${filtered.length} review${filtered.length != 1 ? 's' : ''} found',
                      style: GoogleFonts.plusJakartaSans(
                        color: _subText,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Review Grid / List ───────────────────────────────────
              Flexible(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.rate_review_outlined,
                                  size: 48,
                                  color: _subText.withValues(alpha: 0.4)),
                              const SizedBox(height: 12),
                              Text(
                                'No reviews match your filter.',
                                style: GoogleFonts.plusJakartaSans(
                                    color: _subText),
                              ),
                            ],
                          ),
                        ),
                      )
                    : isMobile
                        ? ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) =>
                                _ReviewListTile(review: filtered[i]),
                          )
                        : GridView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: 1.55,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) =>
                                _ReviewListTile(review: filtered[i]),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _starChip(int stars, String label) {
    final selected = _filterStars == stars;
    return GestureDetector(
      onTap: () => setState(() => _filterStars = stars),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _darkRed : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? _darkRed
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: selected ? Colors.white : _darkText,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INDIVIDUAL REVIEW LIST TILE (used inside the dialog)
// ─────────────────────────────────────────────────────────────────────────────

class _ReviewListTile extends StatefulWidget {
  final Map<String, dynamic> review;
  const _ReviewListTile({required this.review});

  @override
  State<_ReviewListTile> createState() => _ReviewListTileState();
}

class _ReviewListTileState extends State<_ReviewListTile> {
  bool _isHovered = false;

  static const _darkRed = Color(0xFF990000);
  static const _gold = Color(0xFFFFD166);
  static const _darkText = Color(0xFF1E293B);
  static const _primaryGold = Color(0xFFC9922E);

  @override
  Widget build(BuildContext context) {
    final name = widget.review['name'] ?? 'Verified Customer';
    final comment =
        widget.review['comment'] ?? widget.review['review_text'] ?? '';
    final rating = (widget.review['rating'] as num?)?.toDouble() ?? 5.0;
    final date = widget.review['date'] ?? 'Verified Guest';
    final dish = widget.review['dish'] ?? '';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _isHovered
                ? _gold.withValues(alpha: 0.9)
                : const Color(0xFFE8E0D0),
            width: _isHovered ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? _gold.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: _isHovered ? 18 : 8,
              offset: Offset(0, _isHovered ? 6 : 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name + date + stars row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: _darkRed,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'C',
                        style: GoogleFonts.plusJakartaSans(
                          color: _gold,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.plusJakartaSans(
                                color: _darkText,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.verified_rounded,
                                color: Color(0xFF10B981), size: 13),
                          ],
                        ),
                        Text(
                          date,
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF94A3B8),
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: List.generate(5, (i) {
                    return Icon(
                      i < rating.round()
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: _gold,
                      size: 13,
                    );
                  }),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Comment
            Expanded(
              child: Stack(
                children: [
                  Positioned(
                    top: -8,
                    right: 0,
                    child: Icon(
                      Icons.format_quote_rounded,
                      color: _gold.withValues(alpha: 0.12),
                      size: 32,
                    ),
                  ),
                  Text(
                    '"$comment"',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF475569),
                      fontSize: 12.5,
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

            // Dish pill
            if (dish.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _isHovered
                      ? _gold.withValues(alpha: 0.15)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.restaurant_menu_rounded,
                        size: 11, color: _primaryGold),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        dish,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _darkRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

