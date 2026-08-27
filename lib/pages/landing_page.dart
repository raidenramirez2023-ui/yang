import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:yang_chow/utils/app_constants.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/services/menu_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yang_chow/services/reservation_service.dart';
import 'package:yang_chow/services/app_settings_service.dart';
import 'package:intl/intl.dart';
import 'package:yang_chow/models/menu_item.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

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
  final PageController _announcementPageController = PageController();
  int _currentAnnouncementIndex = 0;
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

    _checkAndRedirectUser();
    _loadDynamicData();
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
    _announcementPageController.dispose();
    _animController.dispose();
    _mapSearchController.dispose();
    _startPointController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  // --- Map Methods ---
  bool _isMyLocationActive = false;

  Future<void> _toggleMyLocation() async {
    if (_isMyLocationActive) {
      // TURN OFF: Hide user marker, clear route line, reset start field & recenter
      setState(() {
        _isMyLocationActive = false;
        _userLocation = null;
        _routePoints = [];
        if (_startPointController.text == 'Your location') {
          _startPointController.clear();
        }
      });
      _recenterRestaurant();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('My Location turned off. Route line cleared.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      // TURN ON: Request GPS, show blue pin, calculate route line & zoom
      await _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable location services on your device.')),
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
              const SnackBar(content: Text('Location permissions are denied.')),
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Detecting GPS location...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      final userLoc = LatLng(position.latitude, position.longitude);

      setState(() {
        _isMyLocationActive = true;
        _userLocation = userLoc;
        _startPointController.text = 'Your location';
        _destinationController.text = 'Yang Chow';
      });

      // Awtomatikong i-plot ang ruta mula sa lokasyon ng user papuntang Yang Chow
      await _calculateRouteBetween(userLoc, _restaurantLocation, showSnackbar: true);
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not detect location: $e')),
        );
      }
    }
  }

  Future<void> _calculateRouteBetween(
    LatLng start,
    LatLng dest, {
    bool showSnackbar = false,
  }) async {
    setState(() => _isRouting = true);
    _startLatLng = start;
    _destinationLatLng = dest;

    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};'
        '${dest.longitude},${dest.latitude}'
        '?overview=full&geometries=geojson',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List?;

        if (routes != null && routes.isNotEmpty) {
          final List coordinates = routes[0]['geometry']['coordinates'];

          setState(() {
            _routePoints = coordinates
                .map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()))
                .toList();
            _isRouting = false;
          });

          if (_routePoints.isNotEmpty) {
            final bounds = LatLngBounds.fromPoints([
              start,
              dest,
              ..._routePoints,
            ]);
            _mapController.fitCamera(
              CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
            );
          }

          if (showSnackbar && mounted) {
            final double distanceKm =
                (routes[0]['distance'] as num) / 1000.0;
            final int durationMin =
                ((routes[0]['duration'] as num) / 60.0).round();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Route to Yang Chow: ${distanceKm.toStringAsFixed(1)} km (~$durationMin mins drive)',
                ),
                backgroundColor: forestGreen,
              ),
            );
          }
          return;
        }
      }

      // Fallback direct path
      setState(() {
        _routePoints = [start, dest];
        _isRouting = false;
      });

      final bounds = LatLngBounds.fromPoints([start, dest]);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
      );
    } catch (e) {
      debugPrint('Error calculating route: $e');
      setState(() {
        _routePoints = [start, dest];
        _isRouting = false;
      });
      final bounds = LatLngBounds.fromPoints([start, dest]);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
      );
    }
  }

  Future<LatLng?> _geocodeAddress(String rawAddress) async {
    final address = rawAddress.trim();
    if (address.isEmpty) return null;
    final lower = address.toLowerCase();

    if (lower == 'your location' ||
        lower == 'my location' ||
        lower == 'current location' ||
        lower == 'my position') {
      if (_userLocation != null) return _userLocation;
      await _getCurrentLocation();
      return _userLocation;
    }
    if (lower.contains('yang chow') || lower.contains('cla town center')) {
      return _restaurantLocation;
    }

    try {
      // 1. Search nationwide across all cities & provinces in the Philippines
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(address)}&format=json&limit=1&countrycodes=ph',
      );
      final response = await http
          .get(url, headers: {'User-Agent': 'YangChowApp/1.0'})
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          return LatLng(
            double.parse(data[0]['lat']),
            double.parse(data[0]['lon']),
          );
        }
      }

      // 2. Global fallback search if not found in PH
      final globalUrl = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(address)}&format=json&limit=1',
      );
      final globalResp = await http
          .get(globalUrl, headers: {'User-Agent': 'YangChowApp/1.0'})
          .timeout(const Duration(seconds: 6));

      if (globalResp.statusCode == 200) {
        final List globalData = json.decode(globalResp.body);
        if (globalData.isNotEmpty) {
          return LatLng(
            double.parse(globalData[0]['lat']),
            double.parse(globalData[0]['lon']),
          );
        }
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
    }
    return null;
  }

  Future<void> _getRoute() async {
    final startText = _startPointController.text.trim();
    final destText = _destinationController.text.trim();

    if (startText.isEmpty || destText.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Please enter starting point and destination.')),
        );
      }
      return;
    }

    setState(() => _isRouting = true);
    final start = await _geocodeAddress(startText);
    final dest = await _geocodeAddress(destText);

    if (start == null) {
      setState(() => _isRouting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Could not locate "$startText". Try adding more details (e.g. "$startText, Laguna").')),
        );
      }
      return;
    }
    if (dest == null) {
      setState(() => _isRouting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not locate "$destText".')),
        );
      }
      return;
    }

    await _calculateRouteBetween(start, dest, showSnackbar: true);
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

  Future<void> _openYangChowFacebookPage() async {
    const String pageUrl = 'https://www.facebook.com/yangchow.pagsanjan.2013';
    final Uri fbAppUri = Uri.parse('fb://facewebmodal/f?href=$pageUrl');
    final Uri webUri = Uri.parse(pageUrl);

    try {
      if (await canLaunchUrl(fbAppUri)) {
        final bool launchedInApp = await launchUrl(
          fbAppUri,
          mode: LaunchMode.externalApplication,
        );
        if (launchedInApp) return;
      }
      await launchUrl(
        webUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('Error launching Facebook Page: $e');
      try {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  Future<void> _openYangChowFacebookMessenger() async {
    const String username = 'yangchow.pagsanjan.2013';
    final Uri messengerAppUri =
        Uri.parse('fb-messenger://user-thread/$username');
    final Uri webUri = Uri.parse('https://m.me/$username');
    final Uri fallbackPageUri =
        Uri.parse('https://www.facebook.com/$username');

    try {
      if (await canLaunchUrl(messengerAppUri)) {
        final bool launchedInApp = await launchUrl(
          messengerAppUri,
          mode: LaunchMode.externalApplication,
        );
        if (launchedInApp) return;
      }
      final bool launchedWeb = await launchUrl(
        webUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launchedWeb) {
        await launchUrl(fallbackPageUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching Messenger: $e');
      try {
        await launchUrl(fallbackPageUri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  Future<void> _searchPlace(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    try {
      final LatLng? target = await _geocodeAddress(trimmed);
      if (target != null) {
        _mapController.move(target, 15.5);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No results found for "$trimmed". Try adding town or city name.'),
            ),
          );
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
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOutCubic,
    );
  }

  void _startReviewsAutoScroll() {
    _reviewsAutoScrollTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_reviewsScrollController.hasClients &&
          _reviewsScrollController.positions.isNotEmpty &&
          _reviewsScrollController.position.hasContentDimensions &&
          _reviews.isNotEmpty) {
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

          // Floating Facebook Messenger Chat Widget
          _buildFloatingChatButton(),

          // Glassmorphic Dynamic Navigation Bar (Deep Emerald & Muted Gold)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top: _isNavbarVisible ? 0 : -110,
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
        horizontal: isDesktop ? 48 : 16,
        vertical: isDesktop ? 14 : 10,
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
                      width: isDesktop ? 42 : 36,
                      height: isDesktop ? 42 : 36,
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
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
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
                                fontSize: isDesktop ? 20 : 17,
                                letterSpacing: 1.1,
                              ),
                            ),
                            Text(
                              'CHOW',
                              style: GoogleFonts.playfairDisplay(
                                color: warmGold,
                                fontWeight: FontWeight.w900,
                                fontSize: isDesktop ? 20 : 17,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'PAGSANJAN • YCPRMS',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.sidebarSubtitle,
                            fontSize: isDesktop ? 10 : 8.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Desktop Navigation Links
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

              // Mobile Dual-Action Pill Capsule (Distinct Sign In Button + Menu Badge)
              if (!isDesktop)
                Container(
                  padding: const EdgeInsets.all(3.5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.32),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: warmGold.withValues(alpha: 0.5),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. Distinct "Sign In" Filled Gold Button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pushNamed(context, '/login'),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: AppTheme.goldGradient,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryGold.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 1.5),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.person_rounded,
                                  size: 14,
                                  color: AppTheme.darkBrownText,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Sign In',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.darkBrownText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 4),

                      // 2. Distinct "Menu" Frosted Icon Button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showMobileNavigationSideDrawer(context),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 29,
                            height: 29,
                            decoration: BoxDecoration(
                              color: warmGold.withValues(alpha: 0.16),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: warmGold.withValues(alpha: 0.5),
                                width: 1,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.menu_rounded,
                                size: 16,
                                color: warmGold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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
                        blurRadius: 8,
                        offset: const Offset(0, 3),
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
                        horizontal: 22,
                        vertical: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.lock_outline_rounded,
                          size: 15,
                          color: AppTheme.darkBrownText,
                        ),
                        const SizedBox(width: 5),
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


  Widget _buildScrollToTopButton() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      bottom: _showScrollToTop ? 92 : -80,
      right: 24,
      child: FloatingActionButton.small(
        heroTag: 'landingScrollTopBtn',
        onPressed: _scrollToTop,
        backgroundColor: primaryGold,
        foregroundColor: AppTheme.darkBrownText,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.arrow_upward_rounded, size: 20),
      ),
    );
  }

  Widget _buildFloatingChatButton() {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Positioned(
      bottom: 24,
      right: 24,
      child: Tooltip(
        message: 'Yang Chow Facebook & Chat Options',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showFacebookOptionsModal(context),
            borderRadius: BorderRadius.circular(30),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 14 : 18,
                vertical: 11,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF0084FF), // Messenger
                    Color(0xFF1877F2), // Facebook
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: warmGold.withValues(alpha: 0.9),
                  width: 1.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1877F2).withValues(alpha: 0.5),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dual mini badge
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3.5),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.facebook_rounded,
                          color: Color(0xFF1877F2),
                          size: 16,
                        ),
                      ),
                      Positioned(
                        right: -4,
                        bottom: -2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Color(0xFF0084FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chat_bubble_rounded,
                            color: Colors.white,
                            size: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isMobile ? 'Facebook / Chat' : 'Facebook & Chat',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // COMPACT RIGHT-SIDE SLIDING DRAWER MOBILE NAVIGATION
  // ---------------------------------------------------------------------------

  void _showMobileNavigationSideDrawer(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final menuWidth = (screenWidth * 0.76).clamp(230.0, 275.0);

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (dialogCtx) {
        return Stack(
          children: [
            Positioned(
              top: 56,
              right: 12,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: menuWidth,
                  constraints: BoxConstraints(
                    maxHeight: screenHeight - 80,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF8B0000),
                        Color(0xFF680006),
                        Color(0xFF4A0000),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: warmGold.withValues(alpha: 0.7),
                      width: 1.3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 22,
                        offset: const Offset(0, 7),
                      ),
                      BoxShadow(
                        color: warmGold.withValues(alpha: 0.15),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(15),
                            ),
                            border: Border(
                              bottom: BorderSide(
                                color: warmGold.withValues(alpha: 0.25),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 26,
                                height: 26,
                                padding: const EdgeInsets.all(2.5),
                                decoration: BoxDecoration(
                                  color: forestGreen,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: warmGold, width: 1.1),
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/images/ycplogo.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.restaurant_rounded,
                                      color: warmGold,
                                      size: 13,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'NAVIGATION',
                                  style: GoogleFonts.cinzel(
                                    color: warmGold,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () => Navigator.pop(dialogCtx),
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.all(3.5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.white70,
                                    size: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Navigation Items (Wrapped closely)
                        Padding(
                          padding: const EdgeInsets.all(7.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildSideDrawerNavItem(
                                icon: Icons.home_rounded,
                                title: 'Home',
                                onTap: () {
                                  Navigator.pop(dialogCtx);
                                  _scrollToTop();
                                },
                              ),
                              _buildSideDrawerNavItem(
                                icon: Icons.restaurant_menu_rounded,
                                title: 'Food Menu',
                                onTap: () {
                                  Navigator.pop(dialogCtx);
                                  _scrollToSection(_menuKey);
                                },
                              ),
                              _buildSideDrawerNavItem(
                                icon: Icons.campaign_rounded,
                                title: 'Announcements',
                                onTap: () {
                                  Navigator.pop(dialogCtx);
                                  _scrollToSection(_updatesKey);
                                },
                              ),
                              _buildSideDrawerNavItem(
                                icon: Icons.room_service_rounded,
                                title: 'Services & Events',
                                onTap: () {
                                  Navigator.pop(dialogCtx);
                                  _scrollToSection(_servicesKey);
                                },
                              ),
                              _buildSideDrawerNavItem(
                                icon: Icons.star_rate_rounded,
                                title: 'Customer Reviews',
                                onTap: () {
                                  Navigator.pop(dialogCtx);
                                  _scrollToSection(_reviewsKey);
                                },
                              ),
                              _buildSideDrawerNavItem(
                                icon: Icons.location_on_rounded,
                                title: 'Location & Route',
                                onTap: () {
                                  Navigator.pop(dialogCtx);
                                  _scrollToSection(_mapKey);
                                },
                              ),
                              _buildSideDrawerNavItem(
                                icon: Icons.info_outline_rounded,
                                title: 'About Us',
                                onTap: () {
                                  Navigator.pop(dialogCtx);
                                  _scrollToSection(_aboutKey);
                                },
                              ),
                              _buildSideDrawerNavItem(
                                icon: Icons.phone_in_talk_rounded,
                                title: 'Contact Us',
                                onTap: () {
                                  Navigator.pop(dialogCtx);
                                  _scrollToSection(_contactKey);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
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

  Widget _buildSideDrawerNavItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 3.5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          hoverColor: warmGold.withValues(alpha: 0.12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: warmGold.withValues(alpha: 0.15),
                width: 0.9,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: warmGold.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: warmGold.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Icon(icon, color: warmGold, size: 15),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: warmGold.withValues(alpha: 0.5),
                  size: 15,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFacebookOptionsModal(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogCtx) {
        final isMobile = ResponsiveUtils.isMobile(context);

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 24,
            vertical: 24,
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 430),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: warmGold.withValues(alpha: 0.65),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: warmGold.withValues(alpha: 0.15),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Modal Header with Yang Chow Logo & Online Badge
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
                  decoration: BoxDecoration(
                    color: forestGreen.withValues(alpha: 0.95),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(22)),
                    border: Border(
                      bottom: BorderSide(
                        color: warmGold.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: warmGold, width: 1.5),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            AppConstants.logoPath,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.restaurant,
                              color: warmGold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Yang Chow Pagsanjan',
                              style: GoogleFonts.playfairDisplay(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Official Facebook Channels',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: warmGold,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white70, size: 20),
                        onPressed: () => Navigator.pop(dialogCtx),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                ),

                // Modal Body - Options
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Where would you like to go?',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFCBD5E1),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Option 1: Direct Messenger Chat
                      _buildSocialOptionTile(
                        icon: Icons.chat_bubble_rounded,
                        iconGradient: const [
                          Color(0xFF0084FF),
                          Color(0xFF00C6FF),
                        ],
                        title: 'Chat on Messenger',
                        subtitle:
                            'Send a direct message, inquire or ask assistance',
                        badgeText: 'Instant Chat',
                        badgeColor: const Color(0xFF0084FF),
                        onTap: () {
                          Navigator.pop(dialogCtx);
                          _openYangChowFacebookMessenger();
                        },
                      ),

                      const SizedBox(height: 12),

                      // Option 2: Full Facebook Page Profile
                      _buildSocialOptionTile(
                        icon: Icons.facebook_rounded,
                        iconGradient: const [
                          Color(0xFF1877F2),
                          Color(0xFF0C63D4),
                        ],
                        title: 'Visit Facebook Page',
                        subtitle:
                            'Browse posts, food photos, promos & customer reviews',
                        badgeText: 'Profile & Feed',
                        badgeColor: const Color(0xFF1877F2),
                        onTap: () {
                          Navigator.pop(dialogCtx);
                          _openYangChowFacebookPage();
                        },
                      ),
                    ],
                  ),
                ),

                // Modal Footer note
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(22)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.storefront_rounded,
                          size: 14, color: warmGold),
                      const SizedBox(width: 6),
                      Text(
                        'CLA Town Center Mall, Pagsanjan • 10 AM - 8 PM',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF94A3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSocialOptionTile({
    required IconData icon,
    required List<Color> iconGradient,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: warmGold.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: iconGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: iconGradient.first.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: badgeColor.withValues(alpha: 0.6)),
                          ),
                          child: Text(
                            badgeText,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF94A3B8),
                        fontSize: 11.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: warmGold,
                size: 14,
              ),
            ],
          ),
        ),
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
                    const SizedBox(height: 24),
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
    // Dynamic operating status based on real AppSettingsService / AppConstants
    final now = DateTime.now();
    final startHour = AppSettingsService().getSetting<int>(
            'operating_hours_start',
            defaultValue: AppConstants.defaultOperatingHoursStart) ??
        10;
    final endHour = AppSettingsService().getSetting<int>(
            'operating_hours_end',
            defaultValue: AppConstants.defaultOperatingHoursEnd) ??
        20;
    final isOpen = now.hour >= startHour && now.hour < endHour;
    final startHourStr =
        startHour > 12 ? '${startHour - 12}PM' : '${startHour}AM';
    final endHourStr = endHour > 12 ? '${endHour - 12}PM' : '${endHour}AM';
    final operatingStatusText = isOpen
        ? 'Open Now • $startHourStr - $endHourStr'
        : 'Closed • Opens $startHourStr';

    // Dynamic ratings from database
    final ratingValStr =
        _averageRating > 0 ? _averageRating.toStringAsFixed(1) : '5.0';
    final reviewsValStr = _totalReviewCount > 0
        ? '$_totalReviewCount Reviews'
        : 'Verified Reviews';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: warmGold.withValues(alpha: 0.5), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: warmGold.withValues(alpha: 0.08),
            blurRadius: 12,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Showcase Photo with Perfect Framing of Cellphone & Tablet
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 10.5,
                  child: Image.asset(
                    'assets/images/Yang.jpg',
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, 0.4),
                    errorBuilder: (_, __, ___) => Container(
                      color: forestGreen,
                      child: const Center(
                        child: Icon(Icons.restaurant_rounded,
                            size: 50, color: warmGold),
                      ),
                    ),
                  ),
                ),
                // Soft Top Shade for Badges
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 50,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.4),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // Top Tag: Live Operating Status
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isOpen
                            ? const Color(0xFF10B981).withValues(alpha: 0.7)
                            : Colors.orangeAccent.withValues(alpha: 0.7),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isOpen
                                ? const Color(0xFF10B981)
                                : Colors.orangeAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          operatingStatusText,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Top Right: Live DB Ratings
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: warmGold.withValues(alpha: 0.65)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded,
                            color: warmGold, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          '$ratingValStr ★ ($reviewsValStr)',
                          style: GoogleFonts.plusJakartaSans(
                            color: warmGold,
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

            // 2. Compact YCPRMS System Features
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B0000).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: const Color(0xFF8B0000).withValues(alpha: 0.2)),
                        ),
                        child: const Icon(Icons.phonelink_setup_rounded,
                            color: Color(0xFF8B0000), size: 14),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'YCPRMS SYSTEM FEATURES',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF8B0000),
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Compact 4-Grid
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFFE2E8F0), width: 1),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildTicketDetail(
                                icon: Icons.celebration_rounded,
                                label: 'EVENT RESERVATION',
                                value: 'Date, Time & Capacity',
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 26,
                              color: const Color(0xFFCBD5E1),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 10),
                                child: _buildTicketDetail(
                                  icon: Icons.restaurant_menu_rounded,
                                  label: 'FOOD PRE-ORDERING',
                                  value: 'Dishes Ready on Arrival',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Divider(color: Color(0xFFE2E8F0), height: 1),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTicketDetail(
                                icon: Icons.payment_rounded,
                                label: 'DOWNPAYMENT',
                                value: 'GCash QR & PayMongo',
                                valueColor: const Color(0xFF16A34A),
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 26,
                              color: const Color(0xFFCBD5E1),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 10),
                                child: _buildTicketDetail(
                                  icon: Icons.track_changes_rounded,
                                  label: 'STATUS TRACKING',
                                  value: 'Real-time Live Tracker',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Action Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        final user = Supabase.instance.client.auth.currentUser;
                        if (user != null) {
                          Navigator.pushNamed(context, '/customer_dashboard');
                        } else {
                          Navigator.pushNamed(context, '/login');
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 14),
                        decoration: BoxDecoration(
                          gradient: AppTheme.goldGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: primaryGold.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.celebration_rounded,
                              color: AppTheme.darkBrownText,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Book Event & Pre-order Food',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.darkBrownText,
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: AppTheme.darkBrownText,
                              size: 14,
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
    );
  }

  Widget _buildTicketDetail({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF8B0000), size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF64748B),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: valueColor ?? const Color(0xFF0F172A),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAboutTextBlock() {
    final isMobile = ResponsiveUtils.isMobile(context);

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Smart Online Booking & Authentic Dining',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: darkGreyText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Yang Chow Pagsanjan integrates authentic culinary mastery with the YCPRMS digital platform for fast event bookings and pre-orders.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppTheme.mediumGrey,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),

          // Horizontal Swipeable Cards on Mobile (Saves huge vertical space while showing all 3 features!)
          SizedBox(
            height: 135,
            child: ListView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              children: [
                _buildMobileFeatureCard(
                  Icons.celebration_rounded,
                  'Event Reservations',
                  'Instant booking for birthdays and family gatherings with real-time scheduling.',
                ),
                const SizedBox(width: 10),
                _buildMobileFeatureCard(
                  Icons.restaurant_menu_rounded,
                  'Food Pre-Ordering',
                  'Select favorite dishes beforehand so they are freshly served upon your arrival.',
                ),
                const SizedBox(width: 10),
                _buildMobileFeatureCard(
                  Icons.track_changes_rounded,
                  'Real-time Tracking',
                  'Live customer dashboard tracking for booking status, downpayments, and receipts.',
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Smart Online Booking & Authentic Dining',
          style: GoogleFonts.playfairDisplay(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: darkGreyText,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Yang Chow Pagsanjan integrates authentic culinary mastery with the YCPRMS digital platform. Experience fast online event bookings, advance meal pre-orders, and real-time reservation management.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            color: AppTheme.mediumGrey,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 28),

        _buildAboutFeature(
          Icons.celebration_rounded,
          'Instant Event & Table Reservations',
          'Seamless booking for birthdays, family gatherings, and special occasions with real-time schedule selection.',
        ),
        const SizedBox(height: 18),
        _buildAboutFeature(
          Icons.restaurant_menu_rounded,
          'Advance Food Pre-Ordering',
          'Select your favorite dishes beforehand so they are freshly prepared and served upon your arrival.',
        ),
        const SizedBox(height: 18),
        _buildAboutFeature(
          Icons.track_changes_rounded,
          'Secure Downpayments & Live Tracking',
          'Convenient GCash QR and PayMongo transactions with real-time customer dashboard status and history tracking.',
        ),
      ],
    );
  }

  Widget _buildMobileFeatureCard(IconData icon, String title, String desc) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: warmGold.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: forestGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: forestGreen, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color: darkGreyText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: AppTheme.mediumGrey,
              height: 1.35,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
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
                  color: AppTheme.mediumGrey,
                  fontSize: 13.5,
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
                          height: isMobile ? 270 : 330,
                          child: ListView.builder(
                            controller: _menuScrollController,
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            itemCount: displayedItems.length,
                            itemBuilder: (context, index) {
                              return Container(
                                width: isMobile ? 195 : 260,
                                margin: EdgeInsets.only(right: isMobile ? 12 : 18),
                                child: _buildMenuCard(context, displayedItems[index],
                                    isMobile: isMobile),
                              );
                            },
                          ),
                        ),

                        // Left Scroll Arrow
                        Positioned(
                          left: isMobile ? 4 : -20,
                          child: _MenuScrollArrow(
                            direction: _MenuArrowDirection.left,
                            isMobile: isMobile,
                            onTap: () => _scrollCarousel(-300),
                          ),
                        ),

                        // Right Scroll Arrow
                        Positioned(
                          right: isMobile ? 4 : -20,
                          child: _MenuScrollArrow(
                            direction: _MenuArrowDirection.right,
                            isMobile: isMobile,
                            onTap: () => _scrollCarousel(300),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Swipe Hint Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.swipe_rounded,
                          color: forestGreen.withValues(alpha: 0.6),
                          size: isMobile ? 16 : 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isMobile
                              ? 'Swipe to explore more dishes'
                              : 'Swipe or use navigation arrows to explore dishes',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.mediumGrey,
                            fontSize: isMobile ? 12 : 13,
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
    final isMobile = ResponsiveUtils.isMobile(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: TextField(
        onChanged: (val) => setState(() => _menuSearchQuery = val),
        style: GoogleFonts.plusJakartaSans(fontSize: isMobile ? 13 : 14),
        decoration: InputDecoration(
          hintText: 'Search dishes, dimsum, fried rice...',
          prefixIcon: Icon(Icons.search_rounded,
              color: forestGreen, size: isMobile ? 18 : 22),
          suffixIcon: _menuSearchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () => setState(() => _menuSearchQuery = ''),
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 20, vertical: isMobile ? 12 : 16),
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
    final isMobile = ResponsiveUtils.isMobile(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _menuCategories.map((cat) {
          bool isSelected = _menuSelectedCategory == cat;
          return Padding(
            padding: EdgeInsets.only(right: isMobile ? 8 : 10),
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
                fontSize: isMobile ? 12 : 13,
              ),
              padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 16, vertical: isMobile ? 6 : 10),
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

  Widget _buildMenuCard(BuildContext context, MenuItem item,
      {bool isMobile = false}) {
    final imageUrl =
        MenuService.resolveImageUrl(item.customImagePath ?? item.fallbackImagePath);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dish Image with Tag
            Expanded(
              flex: isMobile ? 5 : 5,
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
                    top: isMobile ? 8 : 12,
                    left: isMobile ? 8 : 12,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 8 : 10,
                          vertical: isMobile ? 3 : 4),
                      decoration: BoxDecoration(
                        color: forestGreen.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        item.category,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: isMobile ? 9.5 : 11,
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
              flex: isMobile ? 4 : 4,
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 10 : 14),
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
                            fontSize: isMobile ? 13.5 : 15,
                            color: darkGreyText,
                          ),
                        ),
                        SizedBox(height: isMobile ? 2 : 4),
                        Text(
                          item.description ??
                              'Authentic Yang Chow recipe prepared fresh daily.',
                          maxLines: isMobile ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: isMobile ? 10.5 : 12,
                            color: AppTheme.mediumGrey,
                            height: 1.25,
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
                            fontSize: isMobile ? 13.5 : 16,
                          ),
                        ),
                        InkWell(
                          onTap: () =>
                              _showMenuItemDetailsDialog(context, item),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 7 : 10,
                                vertical: isMobile ? 4 : 6),
                            decoration: BoxDecoration(
                              color: forestGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'Details',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: forestGreen,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isMobile ? 10.5 : 12,
                                  ),
                                ),
                                SizedBox(width: isMobile ? 2 : 4),
                                Icon(Icons.chevron_right_rounded,
                                    color: forestGreen,
                                    size: isMobile ? 13 : 16),
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
              else if (isMobile)
                _buildMobileAnnouncementsCarousel(_announcements)
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

  Widget _buildMobileAnnouncementsCarousel(List<Map<String, dynamic>> items) {
    return Column(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SizedBox(
            height: 290,
            child: PageView.builder(
              controller: _announcementPageController,
              itemCount: items.length,
              onPageChanged: (index) {
                setState(() {
                  _currentAnnouncementIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _buildUpdateCard(items[index]),
                );
              },
            ),
          ),
        ),
        if (items.length > 1) ...[
          const SizedBox(height: 12),
          // Dot Indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(items.length, (dotIndex) {
              final isSelected = _currentAnnouncementIndex == dotIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isSelected ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isSelected ? forestGreen : forestGreen.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showAnnouncementDetailsDialog(context, item),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEAE5D8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Compact Image on top for mobile
                      SizedBox(
                        height: 120,
                        width: double.infinity,
                        child: imageWidget,
                      ),
                      Expanded(
                        child: _buildUpdateCardBody(
                            title, content, createdAt, day, monthYear, isMobile: true),
                      ),
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
                                title, content, createdAt, day, monthYear, isMobile: false),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  void _showAnnouncementDetailsDialog(
      BuildContext context, Map<String, dynamic> item) {
    final title = item['title'] ?? 'Announcement';
    final content = item['content'] ?? '';
    final createdAt = item['created_at'] != null
        ? DateFormat('MMMM dd, yyyy')
            .format(DateTime.parse(item['created_at'].toString()))
        : 'Recent';

    final rawImage = (item['image_url'] ?? '').toString().trim();
    final hasImage = rawImage.isNotEmpty;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 560),
            padding: const EdgeInsets.all(22),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Bar: Date + Tag + Close Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: warmGold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded,
                                    size: 13, color: primaryGold),
                                const SizedBox(width: 5),
                                Text(
                                  createdAt,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: primaryGold,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: forestGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Special Update',
                              style: GoogleFonts.plusJakartaSans(
                                color: forestGreen,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 22),
                        onPressed: () => Navigator.pop(context),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Full High-Res Flyer / Image
                  if (hasImage)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          rawImage,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _announcementImageFallback(),
                        ),
                      ),
                    )
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 140,
                        width: double.infinity,
                        child: _announcementImageFallback(),
                      ),
                    ),

                  const SizedBox(height: 18),

                  // Full Title
                  Text(
                    title,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: darkGreyText,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Golden Accent Line
                  Container(
                    height: 3,
                    width: 48,
                    decoration: BoxDecoration(
                      color: warmGold,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Full Content Story
                  Text(
                    content,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: AppTheme.mediumGrey,
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: forestGreen,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.store_rounded,
                                color: warmGold, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Yang Chow Pagsanjan',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: forestGreen,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          final user =
                              Supabase.instance.client.auth.currentUser;
                          if (user != null) {
                            Navigator.pushNamed(
                                context, '/customer_dashboard');
                          } else {
                            Navigator.pushNamed(context, '/login');
                          }
                        },
                        icon: const Icon(Icons.celebration_rounded, size: 16),
                        label: const Text('Book Now'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: forestGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
              child: Icon(Icons.campaign_rounded, color: warmGold, size: 36),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateCardBody(String title, String content, String createdAt,
      String day, String monthYear, {bool isMobile = false}) {
    return Padding(
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Date badge & Tag
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 7 : 10, vertical: isMobile ? 2 : 4),
                    decoration: BoxDecoration(
                      color: warmGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: isMobile ? 10 : 12, color: primaryGold),
                        const SizedBox(width: 4),
                        Text(
                          createdAt,
                          style: GoogleFonts.plusJakartaSans(
                            color: primaryGold,
                            fontSize: isMobile ? 9.5 : 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 7 : 10, vertical: isMobile ? 2 : 4),
                    decoration: BoxDecoration(
                      color: forestGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.campaign_rounded,
                            size: isMobile ? 10 : 12, color: forestGreen),
                        const SizedBox(width: 4),
                        Text(
                          'Announcement',
                          style: GoogleFonts.plusJakartaSans(
                            color: forestGreen,
                            fontSize: isMobile ? 9.5 : 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: isMobile ? 8 : 14),

              // Title
              Text(
                title,
                maxLines: isMobile ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.playfairDisplay(
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 15 : 20,
                  color: darkGreyText,
                  height: 1.2,
                ),
              ),
              SizedBox(height: isMobile ? 6 : 12),

              // Divider
              Container(
                height: 2,
                width: isMobile ? 32 : 48,
                decoration: BoxDecoration(
                  color: warmGold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: isMobile ? 6 : 12),

              // Content
              Text(
                content,
                maxLines: isMobile ? 2 : 4,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isMobile ? 11.5 : 14,
                  color: AppTheme.mediumGrey,
                  height: 1.35,
                ),
              ),
            ],
          ),

          // Footer row
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 5 : 8),
                decoration: BoxDecoration(
                  color: forestGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.store_rounded,
                    color: warmGold, size: isMobile ? 12 : 16),
              ),
              const SizedBox(width: 8),
              Text(
                'Yang Chow Pagsanjan',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 11.5 : 13,
                  color: forestGreen,
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
                height: isMobile ? 190 : 250,
                child: ListView.builder(
                  controller: _reviewsScrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: displayReviews.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: EdgeInsets.only(
                          right: isMobile ? 12 : 20,
                          top: isMobile ? 4 : 8,
                          bottom: isMobile ? 4 : 8),
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
    final isMobile = ResponsiveUtils.isMobile(context);

    if (isMobile) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: forestGreen,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: warmGold.withValues(alpha: 0.4), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: forestGreen.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _averageRating > 0 ? _averageRating.toStringAsFixed(1) : '4.9',
                  style: GoogleFonts.playfairDisplay(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 28,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: List.generate(5, (index) {
                        return const Icon(
                          Icons.star_rounded,
                          color: warmGold,
                          size: 16,
                        );
                      }),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Based on ${_totalReviewCount > 0 ? _totalReviewCount : '150+'} verified reviews',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _trustPill(Icons.verified_rounded, '98% Recommended', isMobile: true),
                const SizedBox(width: 8),
                _trustPill(Icons.thumb_up_alt_rounded, 'Top Choice', isMobile: true),
              ],
            ),
          ],
        ),
      );
    }

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

  Widget _trustPill(IconData icon, String text, {bool isMobile = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 12, vertical: isMobile ? 3 : 6),
      decoration: BoxDecoration(
        color: activeEmerald.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: warmGold.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: warmGold, size: isMobile ? 12 : 14),
          SizedBox(width: isMobile ? 4 : 6),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: isMobile ? 10.5 : 12,
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

  // ---------------------------------------------------------------------------
  // INTERACTIVE LOCATION MAP SECTION (REALISTIC & RESPONSIVE)
  // ---------------------------------------------------------------------------

  bool _showRestaurantInfoCard = true;

  void _zoomInMap() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, (currentZoom + 1).clamp(3.0, 19.0));
  }

  void _zoomOutMap() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, (currentZoom - 1).clamp(3.0, 19.0));
  }

  void _recenterRestaurant() {
    _mapController.move(_restaurantLocation, 16.5);
    setState(() => _showRestaurantInfoCard = true);
  }

  Future<void> _openExternalGoogleMaps() async {
    final Uri googleMapsUri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=14.2651,121.4395&query_place_id=Yang+Chow+Pagsanjan');
    try {
      await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error launching Google Maps: $e');
    }
  }

  Future<void> _openExternalWaze() async {
    final Uri wazeUri =
        Uri.parse('https://waze.com/ul?ll=14.2651,121.4395&navigate=yes');
    try {
      await launchUrl(wazeUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error launching Waze: $e');
    }
  }

  Widget _buildMapSection(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 50 : 90,
        horizontal: isMobile ? 16 : 48,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            children: [
              // Badge Pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: forestGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: forestGreen.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_rounded,
                        color: forestGreen, size: 15),
                    const SizedBox(width: 6),
                    Text(
                      'FIND US IN PAGSANJAN',
                      style: GoogleFonts.plusJakartaSans(
                        color: forestGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
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
                  fontSize: isMobile ? 13.5 : 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),

              // Map Container Card with Multi-Layer Support
              Container(
                height: isMobile ? 440 : 540,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: warmGold.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(23),
                  child: Stack(
                    children: [
                      // FlutterMap Layer
                      FlutterMap(
                        mapController: _mapController,
                        options: const MapOptions(
                          initialCenter: _restaurantLocation,
                          initialZoom: 16.0,
                          minZoom: 5.0,
                          maxZoom: 18.5,
                        ),
                        children: [
                          // Base Tiles (CartoDB Voyager for realistic streets or Esri World Imagery)
                          TileLayer(
                            urlTemplate: _isSatelliteMode
                                ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                                : 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
                            userAgentPackageName: 'com.yangchow.app',
                            tileProvider: CancellableNetworkTileProvider(),
                          ),
                          // Satellite Labels Overlay (Hybrid View)
                          if (_isSatelliteMode)
                            TileLayer(
                              urlTemplate:
                                  'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
                              userAgentPackageName: 'com.yangchow.app',
                              tileProvider: CancellableNetworkTileProvider(),
                            ),
                          // Routing Polyline Layer
                          if (_routePoints.isNotEmpty)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: _routePoints,
                                  strokeWidth: 5.0,
                                  color: const Color(0xFF0284C7),
                                  borderColor: Colors.white,
                                  borderStrokeWidth: 2.0,
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: [
                              // Realistic Yang Chow Restaurant Pin
                              Marker(
                                point: _restaurantLocation,
                                width: 70,
                                height: 75,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _showRestaurantInfoCard =
                                          !_showRestaurantInfoCard;
                                    });
                                  },
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Pin Head with Logo & Pulsing Glow
                                      Container(
                                        width: 48,
                                        height: 48,
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: forestGreen,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: warmGold,
                                            width: 2.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: forestGreen
                                                  .withValues(alpha: 0.6),
                                              blurRadius: 16,
                                              spreadRadius: 3,
                                            ),
                                            BoxShadow(
                                              color: warmGold
                                                  .withValues(alpha: 0.4),
                                              blurRadius: 8,
                                            ),
                                          ],
                                        ),
                                        child: ClipOval(
                                          child: Image.asset(
                                            AppConstants.logoPath,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(
                                              Icons.restaurant_rounded,
                                              color: warmGold,
                                              size: 24,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Pin Pointer Stem
                                      Container(
                                        width: 3,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: warmGold,
                                          borderRadius:
                                              BorderRadius.circular(2),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Colors.black45,
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        width: 8,
                                        height: 3,
                                        decoration: BoxDecoration(
                                          color: Colors.black26,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // User Location Marker
                              if (_userLocation != null)
                                Marker(
                                  point: _userLocation!,
                                  width: 44,
                                  height: 44,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0284C7),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2.5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF0284C7)
                                              .withValues(alpha: 0.5),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.person_pin_circle_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),

                      // Top Search / Direction Control Panel
                      Positioned(
                        top: 14,
                        left: 14,
                        right: 14,
                        child: _showDirectionsPanel
                            ? _buildDirectionsPanel()
                            : _buildSimpleSearchBar(),
                      ),

                      // Floating Interactive Info Callout Card
                      if (_showRestaurantInfoCard && !_showDirectionsPanel)
                        Positioned(
                          bottom: 14,
                          left: 14,
                          right: isMobile ? 80 : null,
                          child: _buildRestaurantCalloutCard(isMobile),
                        ),

                      // Right-Side Map Quick Controls (Satellite, Recenter, GPS, Zoom)
                      Positioned(
                        bottom: 14,
                        right: 14,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Satellite / Street Toggle
                            _buildMapControlBtn(
                              icon: _isSatelliteMode
                                  ? Icons.map_rounded
                                  : Icons.satellite_alt_rounded,
                              tooltip: _isSatelliteMode
                                  ? 'Street View'
                                  : 'Satellite Hybrid View',
                              isActive: _isSatelliteMode,
                              onTap: () => setState(
                                  () => _isSatelliteMode = !_isSatelliteMode),
                            ),
                            const SizedBox(height: 8),

                            // Recenter on Yang Chow
                            _buildMapControlBtn(
                              icon: Icons.storefront_rounded,
                              tooltip: 'Recenter on Yang Chow',
                              iconColor: primaryGold,
                              onTap: _recenterRestaurant,
                            ),
                            const SizedBox(height: 8),

                            // GPS Current Location (Toggle ON / OFF)
                            _buildMapControlBtn(
                              icon: _isMyLocationActive
                                  ? Icons.my_location_rounded
                                  : Icons.location_searching_rounded,
                              tooltip: _isMyLocationActive
                                  ? 'Turn Off My Location & Route'
                                  : 'Turn On My Location & Route',
                              isActive: _isMyLocationActive,
                              iconColor: _isMyLocationActive
                                  ? Colors.white
                                  : const Color(0xFF0284C7),
                              onTap: _toggleMyLocation,
                            ),
                            const SizedBox(height: 8),

                            // Zoom In
                            _buildMapControlBtn(
                              icon: Icons.add_rounded,
                              tooltip: 'Zoom In',
                              onTap: _zoomInMap,
                            ),
                            const SizedBox(height: 6),

                            // Zoom Out
                            _buildMapControlBtn(
                              icon: Icons.remove_rounded,
                              tooltip: 'Zoom Out',
                              onTap: _zoomOutMap,
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

  Widget _buildMapControlBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? iconColor,
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            debugPrint('Map control button tapped: $tooltip');
            onTap();
          },
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isActive ? forestGreen : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive
                    ? warmGold
                    : Colors.black.withValues(alpha: 0.15),
                width: isActive ? 1.8 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                icon,
                color: isActive ? Colors.white : (iconColor ?? darkGreyText),
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRestaurantCalloutCard(bool isMobile) {
    return Container(
      constraints: BoxConstraints(maxWidth: isMobile ? 320 : 380),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: warmGold.withValues(alpha: 0.6),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: warmGold, width: 1.5),
                ),
                child: ClipOval(
                  child: Image.asset(
                    AppConstants.logoPath,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.restaurant,
                      color: warmGold,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Yang Chow Pagsanjan',
                      style: GoogleFonts.playfairDisplay(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: warmGold, size: 14),
                        const SizedBox(width: 3),
                        Text(
                          '4.9 (150+ reviews)',
                          style: GoogleFonts.plusJakartaSans(
                            color: warmGold,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Colors.white38,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Open Now',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF10B981),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white60, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () =>
                    setState(() => _showRestaurantInfoCard = false),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'CLA Town Center Mall, Ground Floor, Pagsanjan, Laguna',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFCBD5E1),
              fontSize: 11.5,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Google Maps Button
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _openExternalGoogleMaps,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A73E8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.map_rounded,
                              color: Colors.white, size: 14),
                          const SizedBox(width: 5),
                          Text(
                            'Google Maps',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Waze Button
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _openExternalWaze,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00B2FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.navigation_rounded,
                              color: Colors.white, size: 14),
                          const SizedBox(width: 5),
                          Text(
                            'Waze',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5,
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
        ],
      ),
    );
  }

  Widget _buildSimpleSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: warmGold.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: forestGreen, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _mapSearchController,
              onSubmitted: _searchPlace,
              style: GoogleFonts.plusJakartaSans(fontSize: 13.5),
              decoration: const InputDecoration(
                hintText: 'Search place (e.g., Pagsanjan Church, Laguna)...',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (_mapSearchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.grey),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                _mapSearchController.clear();
                setState(() {});
              },
            ),
          const SizedBox(width: 6),
          Container(
            decoration: BoxDecoration(
              color: forestGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: const Icon(Icons.directions_rounded, color: warmGold, size: 20),
              tooltip: 'Get Directions',
              onPressed: () => setState(() => _showDirectionsPanel = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionsPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: warmGold.withValues(alpha: 0.6), width: 1.3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
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
              Row(
                children: [
                  const Icon(Icons.directions_rounded, color: warmGold, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Route & Navigation',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.swap_vert_rounded,
                        color: warmGold, size: 20),
                    onPressed: _swapRoutingPoints,
                    tooltip: 'Swap start & destination',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white70, size: 20),
                    onPressed: () =>
                        setState(() => _showDirectionsPanel = false),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildRoutingTextField(
            controller: _startPointController,
            hint: 'Starting Point (e.g. Your location)',
            icon: Icons.my_location_rounded,
            onIconTap: () async {
              _startPointController.text = 'Your location';
              if (_userLocation == null) {
                await _getCurrentLocation();
              } else {
                setState(() {});
              }
            },
          ),
          const SizedBox(height: 6),
          // Quick "Use My Current Location" Toggle Chip
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: _toggleMyLocation,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _isMyLocationActive
                      ? forestGreen.withValues(alpha: 0.3)
                      : const Color(0xFF0284C7).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isMyLocationActive
                        ? warmGold
                        : const Color(0xFF0284C7).withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isMyLocationActive
                          ? Icons.check_circle_rounded
                          : Icons.my_location_rounded,
                      color: _isMyLocationActive
                          ? warmGold
                          : const Color(0xFF38BDF8),
                      size: 12,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _isMyLocationActive
                          ? 'GPS Location Active (Tap to Turn Off)'
                          : 'Use Exact GPS Location (Turn ON)',
                      style: GoogleFonts.plusJakartaSans(
                        color: _isMyLocationActive
                            ? warmGold
                            : const Color(0xFF38BDF8),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: warmGold.withValues(alpha: 0.6)),
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
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.alt_route_rounded,
                                color: warmGold, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Calculate Route',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
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
    VoidCallback? onIconTap,
  }) {
    return TextField(
      controller: controller,
      style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: onIconTap != null
            ? IconButton(
                icon: Icon(icon, size: 18, color: const Color(0xFF38BDF8)),
                tooltip: 'Set to Current Location',
                onPressed: onIconTap,
              )
            : Icon(icon, size: 18, color: warmGold),
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
        filled: true,
        fillColor: const Color(0xFF0F172A),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: warmGold.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: warmGold, width: 1.5),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CONTACT & FOOTER SECTION
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // CONTACT & FOOTER SECTION
  // ---------------------------------------------------------------------------

  void _scrollToMapSection() {
    _scrollToSection(_mapKey);
    _recenterRestaurant();
  }

  Future<void> _openGmailDirectly(String emailAddress) async {
    const String subject = 'Inquiry regarding Yang Chow Pagsanjan';
    
    // 1. Direct Gmail Web URL (Opens Gmail composer in new tab directly)
    final Uri gmailWebUri = Uri.parse(
      'https://mail.google.com/mail/?view=cm&fs=1&to=$emailAddress&su=${Uri.encodeComponent(subject)}',
    );

    // 2. Direct Gmail App Scheme (For mobile devices with Gmail App installed)
    final Uri gmailAppUri = Uri.parse(
      'googlegmail:///co?to=$emailAddress&subject=${Uri.encodeComponent(subject)}',
    );

    // 3. Standard mailto Uri
    final Uri mailtoUri = Uri(
      scheme: 'mailto',
      path: emailAddress,
      query: 'subject=${Uri.encodeComponent(subject)}',
    );

    try {
      if (await canLaunchUrl(gmailAppUri)) {
        final bool launched = await launchUrl(
          gmailAppUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return;
      }
      
      final bool launchedWeb = await launchUrl(
        gmailWebUri,
        mode: LaunchMode.externalApplication,
      );
      if (launchedWeb) return;

      await launchUrl(
        mailtoUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('Error launching Gmail: $e');
      try {
        await launchUrl(gmailWebUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        Clipboard.setData(ClipboardData(text: emailAddress));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Copied email: $emailAddress'),
              backgroundColor: forestGreen,
            ),
          );
        }
      }
    }
  }

  Widget _buildContactFooterSection(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF800000),
            Color(0xFF6A0000),
          ],
        ),
      ),
      padding: EdgeInsets.only(
        top: isMobile ? 32 : 44,
        bottom: 24,
        left: isMobile ? 16 : 40,
        right: isMobile ? 16 : 40,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            children: [
              // Sleek, Realistic, Compact Contact Information Bar (Matching Landing Page Red & Gold Theme)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 900;
                  final itemWidth = isWide
                      ? (constraints.maxWidth - 36) / 4
                      : (constraints.maxWidth < 560
                          ? double.infinity
                          : (constraints.maxWidth - 12) / 2);

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      // 1. Our Location (Interactive map view)
                      SizedBox(
                        width: itemWidth,
                        child: _buildCompactContactItem(
                          icon: Icons.location_on_rounded,
                          title: 'Our Location',
                          value: 'CLA Town Center Mall\nPagsanjan, Laguna 4008',
                          tooltip: 'Click to View on Map',
                          onTap: _scrollToMapSection,
                        ),
                      ),

                      // 2. Opening Hours (Display)
                      SizedBox(
                        width: itemWidth,
                        child: _buildCompactContactItem(
                          icon: Icons.access_time_rounded,
                          title: 'Opening Hours',
                          value: 'Monday – Sunday\n10:00 AM – 08:00 PM',
                          tooltip: 'Open Daily (Dine-in & Takeout)',
                          onTap: null,
                        ),
                      ),

                      // 3. Call Us (Pure Display Only)
                      SizedBox(
                        width: itemWidth,
                        child: _buildCompactContactItem(
                          icon: Icons.phone_in_talk_rounded,
                          title: 'Call Us',
                          value: 'TEL# 501-9179\nCP# 0975-041-9671',
                          tooltip: 'Yang Chow Contact Lines',
                          onTap: null,
                        ),
                      ),

                      // 4. Email Us (Directly Opens Gmail)
                      SizedBox(
                        width: itemWidth,
                        child: _buildCompactContactItem(
                          icon: Icons.email_rounded,
                          title: 'Email Us',
                          value: 'admn.pagsanjan@gmail.com',
                          tooltip: 'Open Directly in Gmail',
                          onTap: () => _openGmailDirectly('admn.pagsanjan@gmail.com'),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 28),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 18),

              // Footer Bottom Copyright & Social Icons (Centered & Responsive)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.facebook_rounded,
                              color: warmGold, size: 22),
                          tooltip: 'Yang Chow Facebook Page',
                          onPressed: _openYangChowFacebookPage,
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_rounded,
                              color: warmGold, size: 20),
                          tooltip: 'Message on Messenger',
                          onPressed: _openYangChowFacebookMessenger,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '© ${DateTime.now().year} Yang Chow Pagsanjan (YCPRMS). All rights reserved.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: isMobile ? 11.5 : 12.5,
                        letterSpacing: 0.2,
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

  Widget _buildCompactContactItem({
    required IconData icon,
    required String title,
    required String value,
    required String tooltip,
    VoidCallback? onTap,
  }) {
    final bool isClickable = onTap != null;

    final cardContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF900C14).withValues(alpha: 0.95),
            const Color(0xFF6B0007).withValues(alpha: 0.98),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: warmGold.withValues(alpha: isClickable ? 0.5 : 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 3D Metallic Badge with Yang Chow Red & Gold
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                colors: [
                  Color(0xFFAA0000),
                  Color(0xFF550000),
                ],
                center: Alignment(-0.2, -0.2),
                radius: 0.9,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: warmGold,
                width: 1.3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Icon(icon, color: warmGold, size: 19),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    if (isClickable) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.open_in_new_rounded,
                        color: warmGold,
                        size: 11,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFF1F5F9),
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (!isClickable) {
      return cardContent;
    }

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          hoverColor: warmGold.withValues(alpha: 0.15),
          child: cardContent,
        ),
      ),
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
  final PageController _servicesPageController = PageController();
  int _currentServiceIndex = 0;
  late List<_ServiceData> _items;
  int? _draggedIndex;

  @override
  void dispose() {
    _servicesPageController.dispose();
    super.dispose();
  }

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
        infoLabel: 'Walk-In Welcome  •  Open Daily',
      ),
      _ServiceData(
        number: '02',
        icon: Icons.celebration_rounded,
        title: 'Private Events',
        description:
            'Planning a birthday, reunion, or corporate event? We offer tailored catering packages and exclusive private dining spaces.',
        tag: 'Catering & Packages',
        showButton: true,
        buttonLabel: 'Book an Event',
      ),
      _ServiceData(
        number: '03',
        icon: Icons.takeout_dining_rounded,
        title: 'Takeout or Pickup',
        description:
            'Prefer dining at home? Order your favorites physically to takehome or advance order by online to freshly prepared and ready for pickup.',
        tag: 'Freshly Prepared',
        showButton: true,
        buttonLabel: 'Order Now',
      ),
      _ServiceData(
        number: '04',
        icon: Icons.event_seat_rounded,
        title: 'Reservation System',
        description:
            'Skip the wait and reserve a table in advance through our quick and easy online booking system. Available 7 days a week.',
        tag: 'Skip The Wait',
        showButton: true,
        buttonLabel: 'Reserve a Table',
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
          showButton: _items[i].showButton,
          buttonLabel: _items[i].buttonLabel,
          infoLabel: _items[i].infoLabel,
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
              // Drag hint (Only on Desktop / Tablet)
              if (!widget.isMobile)
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
              SizedBox(height: widget.isMobile ? 24 : 36),

              // Draggable cards on Desktop/Tablet or Carousel on Mobile
              LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth > 900;
                  final isTablet = constraints.maxWidth > 580;

                  if (isDesktop || isTablet) {
                    return _buildDesktopDraggableRow(isDesktop, constraints);
                  } else {
                    return _buildMobileServicesCarousel();
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

  Widget _buildMobileServicesCarousel() {
    return Column(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SizedBox(
            height: 240,
            child: PageView.builder(
              controller: _servicesPageController,
              itemCount: _items.length,
              onPageChanged: (index) {
                setState(() {
                  _currentServiceIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _LandingServiceCard(
                    item: _items[index],
                    showDragHandle: false,
                    isMobile: true,
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Dot Indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_items.length, (dotIndex) {
            final isSelected = _currentServiceIndex == dotIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isSelected ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isSelected
                    ? _LandingPageState.forestGreen
                    : _LandingPageState.forestGreen.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _ServiceData {
  final String number;
  final IconData icon;
  final String title;
  final String description;
  final String tag;
  final bool showButton;
  final String buttonLabel;
  final String infoLabel;

  _ServiceData({
    required this.number,
    required this.icon,
    required this.title,
    required this.description,
    required this.tag,
    this.showButton = false,
    this.buttonLabel = 'Get Started',
    this.infoLabel = '',
  });
}

class _LandingServiceCard extends StatefulWidget {
  final _ServiceData item;
  final bool isDragging;
  final bool isDropTarget;
  final bool showDragHandle;
  final bool isMobile;

  const _LandingServiceCard({
    required this.item,
    this.isDragging = false,
    this.isDropTarget = false,
    this.showDragHandle = false,
    this.isMobile = false,
  });

  @override
  State<_LandingServiceCard> createState() => _LandingServiceCardState();
}

class _LandingServiceCardState extends State<_LandingServiceCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isActive = _isHovered || widget.isDragging || widget.isDropTarget;
    final isMobile = widget.isMobile;

    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        transform:
            Matrix4.translationValues(0.0, isActive && !widget.isDragging ? -6.0 : 0.0, 0.0),
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        decoration: BoxDecoration(
          color: widget.isDropTarget
              ? _LandingPageState.warmGold.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
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
            // ── Top content block ──
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row (Icon + Step Number + optional drag handle)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: EdgeInsets.all(isMobile ? 8 : 12),
                      decoration: BoxDecoration(
                        color: isActive
                            ? _LandingPageState.forestGreen
                            : _LandingPageState.forestGreen
                                .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        widget.item.icon,
                        color: isActive
                            ? _LandingPageState.warmGold
                            : _LandingPageState.forestGreen,
                        size: isMobile ? 20 : 26,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          widget.item.number,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: isMobile ? 22 : 28,
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
                SizedBox(height: isMobile ? 12 : 20),

                // Title
                Text(
                  widget.item.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 15 : 17,
                    color: _LandingPageState.darkGreyText,
                  ),
                ),
                SizedBox(height: isMobile ? 6 : 10),

                // Description — uniform 4 lines on desktop for equal card heights
                Text(
                  widget.item.description,
                  maxLines: isMobile ? 3 : 4,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: isMobile ? 12 : 13.5,
                    color: const Color(0xFF64748B),
                    height: 1.45,
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 10 : 16),

            // ── Footer: Tag Pill row ──
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 8 : 10, vertical: isMobile ? 3 : 5),
                  decoration: BoxDecoration(
                    color: isActive
                        ? _LandingPageState.warmGold.withValues(alpha: 0.2)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: isMobile ? 11 : 13,
                        color: isActive
                            ? _LandingPageState.forestGreen
                            : const Color(0xFF10B981),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        widget.item.tag,
                        style: GoogleFonts.plusJakartaSans(
                          color: isActive
                              ? _LandingPageState.darkForest
                              : const Color(0xFF475569),
                          fontWeight: FontWeight.w700,
                          fontSize: isMobile ? 10 : 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── Bottom strip: CTA button OR info badge (same height, all cards align) ──
            SizedBox(height: isMobile ? 10 : 14),
            SizedBox(
              width: double.infinity,
              child: widget.item.showButton
                  // ── Clickable gradient button for bookable services ──
                  ? AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      decoration: BoxDecoration(
                        gradient: isActive
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFF990000),
                                  Color(0xFFBB1111),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : LinearGradient(
                                colors: [
                                  _LandingPageState.forestGreen
                                      .withValues(alpha: 0.85),
                                  _LandingPageState.forestGreen,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: _LandingPageState.forestGreen
                                .withValues(alpha: isActive ? 0.35 : 0.15),
                            blurRadius: isActive ? 12 : 6,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => Navigator.pushNamed(context, '/login'),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: isMobile ? 9 : 11,
                              horizontal: 12,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  widget.item.buttonLabel,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: isMobile ? 12 : 13,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 15,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  // ── Non-clickable info strip for Dine-In (same height as button) ──
                  : AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: EdgeInsets.symmetric(
                        vertical: isMobile ? 9 : 11,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? _LandingPageState.warmGold.withValues(alpha: 0.10)
                            : const Color(0xFFF8F4EE),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isActive
                              ? _LandingPageState.warmGold.withValues(alpha: 0.55)
                              : _LandingPageState.warmGold.withValues(alpha: 0.28),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.storefront_rounded,
                            size: isMobile ? 12 : 14,
                            color: isActive
                                ? _LandingPageState.primaryGold
                                : _LandingPageState.primaryGold
                                    .withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.item.infoLabel,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              color: isActive
                                  ? _LandingPageState.darkGreyText
                                  : const Color(0xFF92816A),
                              fontWeight: FontWeight.w600,
                              fontSize: isMobile ? 11 : 12,
                              letterSpacing: 0.2,
                            ),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// MENU SCROLL ARROW
// ─────────────────────────────────────────────────────────────────────────────

enum _MenuArrowDirection { left, right }

class _MenuScrollArrow extends StatefulWidget {
  final _MenuArrowDirection direction;
  final bool isMobile;
  final VoidCallback onTap;

  const _MenuScrollArrow({
    required this.direction,
    required this.isMobile,
    required this.onTap,
  });

  @override
  State<_MenuScrollArrow> createState() => _MenuScrollArrowState();
}

class _MenuScrollArrowState extends State<_MenuScrollArrow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _bounceAnim = Tween<double>(begin: 0.0, end: 6.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLeft = widget.direction == _MenuArrowDirection.left;

    // ── Desktop: original white circle ──
    if (!widget.isMobile) {
      return Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 6,
        child: InkWell(
          onTap: widget.onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              isLeft
                  ? Icons.arrow_back_ios_new_rounded
                  : Icons.arrow_forward_ios_rounded,
              color: _LandingPageState.forestGreen,
              size: 20,
            ),
          ),
        ),
      );
    }

    // ── Mobile: bouncing frosted pill arrow ──
    return AnimatedBuilder(
      animation: _bounceAnim,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(isLeft ? -_bounceAnim.value : _bounceAnim.value, 0),
          child: child,
        );
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: _LandingPageState.forestGreen.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: _LandingPageState.forestGreen.withValues(alpha: 0.30),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            isLeft
                ? Icons.chevron_left_rounded
                : Icons.chevron_right_rounded,
            color: _LandingPageState.warmGold,
            size: 22,
          ),
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
    final isMobile = ResponsiveUtils.isMobile(context);
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
        width: isMobile ? 260 : 350,
        transform: Matrix4.translationValues(0.0, _isHovered ? -6.0 : 0.0, 0.0),
        padding: EdgeInsets.all(isMobile ? 12 : 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
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
                  children: [
                    CircleAvatar(
                      radius: isMobile ? 15 : 20,
                      backgroundColor: _LandingPageState.forestGreen,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'C',
                        style: GoogleFonts.plusJakartaSans(
                          color: _LandingPageState.warmGold,
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 12 : 16,
                        ),
                      ),
                    ),
                    SizedBox(width: isMobile ? 8 : 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: _LandingPageState.darkGreyText,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isMobile ? 12 : 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.verified_rounded,
                                color: const Color(0xFF10B981),
                                size: isMobile ? 11 : 13,
                              ),
                            ],
                          ),
                          Text(
                            date,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF94A3B8),
                              fontSize: isMobile ? 9.5 : 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (i) {
                        return Icon(
                          i < rating.round()
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: _LandingPageState.warmGold,
                          size: isMobile ? 11 : 15,
                        );
                      }),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 8 : 14),

                // Review Text
                Text(
                  '"$comment"',
                  maxLines: isMobile ? 2 : 4,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF334155),
                    fontSize: isMobile ? 11.5 : 13.5,
                    height: 1.4,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),

            // Footer Dish Pill
            Container(
              margin: EdgeInsets.only(top: isMobile ? 8 : 14),
              padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 8 : 10, vertical: isMobile ? 3 : 5),
              decoration: BoxDecoration(
                color: _isHovered
                    ? _LandingPageState.warmGold.withValues(alpha: 0.18)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.restaurant_menu_rounded,
                    size: isMobile ? 11 : 13,
                    color: _LandingPageState.primaryGold,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      dish,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: isMobile ? 10 : 11.5,
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
          height: MediaQuery.of(context).size.height * 0.85,
          color: _cream,
          child: Column(
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
              Expanded(
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
              crossAxisAlignment: CrossAxisAlignment.start,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: _darkText,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded,
                              color: Color(0xFF10B981), size: 13),
                        ],
                      ),
                      Text(
                        date,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF94A3B8),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
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
            Stack(
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
                  maxLines: 4,
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

