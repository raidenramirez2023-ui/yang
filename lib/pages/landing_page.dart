import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:yang_chow/services/menu_service.dart';
import 'package:yang_chow/services/reservation_service.dart';
import 'package:intl/intl.dart';
import 'package:yang_chow/models/menu_item.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // --- Section Keys ---
  final GlobalKey _homeKey = GlobalKey();
  final GlobalKey _aboutKey = GlobalKey();
  final GlobalKey _menuKey = GlobalKey();
  final GlobalKey _updatesKey = GlobalKey();
  final GlobalKey _servicesKey = GlobalKey();
  final GlobalKey _reviewsKey = GlobalKey();
  final GlobalKey _contactKey = GlobalKey();

  bool _isCheckingSession = true;
  bool _showScrollToTop = false;
  bool _isNavbarVisible = true;
  double _lastScrollOffset = 0.0;

  // --- Dynamic Data State ---
  final ReservationService _reservationService = ReservationService();
  double _averageRating = 0.0;
  int _totalReviewCount = 0;
  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _reviews = [];
  List<MenuItem> _featuredMenuItems = [];
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
  final TextEditingController _startPointController = TextEditingController(text: 'Your location');
  final TextEditingController _destinationController = TextEditingController(text: 'Yang Chow');
  LatLng? _userLocation;
  LatLng? _startLatLng;
  LatLng? _destinationLatLng = _restaurantLocation;
  List<LatLng> _routePoints = [];
  bool _isRouting = false;
  bool _showDirectionsPanel = false;
  bool _isSatelliteMode = false;
  static const LatLng _restaurantLocation = LatLng(14.265, 121.439);

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
      begin: const Offset(1, 0), // Start from right off-screen
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _menuController, curve: Curves.easeOutCubic));

    _checkAndRedirectUser();
    _loadDynamicData();
    _getCurrentLocation();
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
      
      // Calculate exact average from all reviews to ensure 100% accuracy
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

      // 4. Select Featured Menu Items (Dynamic)
      final allMenu = MenuService.getMenu();
      final featured = <MenuItem>[];
      // Pick one from each of these popular categories for variety
      final categoriesToPick = ['Dimsum', 'Noodles', 'Seafood', 'Chicken'];
      for (var cat in categoriesToPick) {
        if (allMenu.containsKey(cat) && allMenu[cat]!.isNotEmpty) {
          featured.add(allMenu[cat]!.first);
        }
      }

      if (mounted) {
        setState(() {
          _averageRating = calculatedAverage > 0 ? calculatedAverage : (ratingsData['overall'] ?? 0.0);
          _totalReviewCount = totalReviews;
          try {
            _announcements = List<Map<String, dynamic>>.from(announcementsResponse);
          } catch (e) {
            debugPrint('Error parsing announcements: $e');
            _announcements = [];
          }
          _reviews = reviewsResponse;
          _featuredMenuItems = featured;
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

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
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
            const SnackBar(content: Text('Location permissions are permanently denied.')),
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
      final response = await http.get(url, headers: {'User-Agent': 'YangChowApp/1.0'});
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          return LatLng(double.parse(data[0]['lat']), double.parse(data[0]['lon']));
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
      // Geocode start and destination if needed
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
          _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));
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
              const SnackBar(content: Text('No results found for that location.')),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error searching place: $e');
    }
  }

  void _scrollListener() {
    // Scroll to top button logic
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
        curve: Curves.easeInOut,
      );
    }
  }

  void _scrollToTop() {
    if (_isMobileMenuOpen) _toggleMobileMenu();
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
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

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isCheckingSession) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F5DC),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFC62828)),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Fixed Red Background Overlay (from login page)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/YangChow.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Stack(
                children: [
                  Container(
                    color: const Color(0xFFC62828).withValues(alpha: 0.9),
                  ),
                  CustomPaint(
                    painter: ChinesePatternPainter(
                      color: Colors.black.withValues(alpha: 0.05),
                    ),
                    size: Size.infinite,
                  ),
                ],
              ),
            ),
          ),
          // Main Scrollable Content
          SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                if (_isLoadingData)
                  const LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC62828)),
                  ),
                // Spacer to account for the fixed navigation bar
                const SizedBox(height: 80),
                _buildHeroSection(context), // HOME
                _buildAboutSection(context), // ABOUT
                _buildMenuSection(context), // MENU
                _buildUpdatesSection(context), // UPDATES
                _buildServicesSection(context), // SERVICES
                _buildReviewsSection(context), // REVIEWS
                _buildMapSection(context), // MAP
                _buildContactFooterSection(context), // CONTACT
              ],
            ),
          ),

          // Floating Action Button (Placed before overlay to be covered when menu opens)
          _buildScrollToTopButton(),

          // Custom Half-Screen Mobile Menu Overlay
          if (_isMobileMenuOpen || _menuController.status == AnimationStatus.reverse)
            _buildMobileMenuOverlay(context),

          // Responsive Navigation Bar with smooth slide animation
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.fastOutSlowIn,
            top: 0, // Always fixed at the top
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _lastScrollOffset > 50
                    ? const Color(0xFFC62828).withValues(alpha: 0.98)
                    : Colors.transparent,
                boxShadow: [
                  if (_lastScrollOffset > 50)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                ],
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
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      color: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Brand
              InkWell(
                onTap: _scrollToTop,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Yang',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                      ),
                    ),
                    Text(
                      'Chow',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                      ),
                    ),
                  ],
                ),
              ),

              // Desktop nav links
              if (isDesktop)
                Row(
                  children: [
                    _navLink('Home', () => _scrollToTop(), Colors.white),
                    _navLink('About', () => _scrollToSection(_aboutKey), Colors.white),
                    _navLink('Menu', () => _scrollToSection(_menuKey), Colors.white),
                    _navLink('Updates', () => _scrollToSection(_updatesKey), Colors.white),
                    _navLink('Services', () => _scrollToSection(_servicesKey), Colors.white),
                    _navLink('Reviews', () => _scrollToSection(_reviewsKey), Colors.white),
                    _navLink('Contact', () => _scrollToSection(_contactKey), Colors.white),
                  ],
                ),

              // Action
              if (!isDesktop)
                GestureDetector(
                  onTap: _toggleMobileMenu,
                  child: AnimatedIcon(
                    icon: AnimatedIcons.menu_close,
                    progress: _menuController,
                    color: Colors.white,
                    size: 28,
                  ),
                )
              else
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFC62828),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    elevation: 0,
                  ),
                  child: const Text('Login',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navLink(String label, VoidCallback onTap, [Color color = const Color(0xFF1E1E1E)]) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(foregroundColor: color),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildMobileMenuOverlay(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return IgnorePointer(
      ignoring: !_isMobileMenuOpen,
      child: FadeTransition(
        opacity: _menuFadeAnimation,
        child: Stack(
        children: [
          // Darkened Scrim / Backdrop (Tapping here closes the menu)
          GestureDetector(
            onTap: _toggleMobileMenu,
            child: Container(
              color: Colors.black.withValues(alpha: 0.5),
            ),
          ),
          
          // Half-Screen Menu Panel
          Align(
            alignment: Alignment.centerRight,
            child: SlideTransition(
              position: _menuSlideAnimation,
              child: Container(
                width: screenWidth * 0.5, // Half-screen width
                height: double.infinity, // Full-screen height
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F5DC),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      offset: Offset(-5, 0),
                    )
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      // Scrollable Links Tray
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 80), // Space for nav bar area
                                _mobileMenuItem('Home', _scrollToTop),
                                _mobileMenuItem('About', () => _scrollToSection(_aboutKey)),
                                _mobileMenuItem('Menu', () => _scrollToSection(_menuKey)),
                                _mobileMenuItem('Updates', () => _scrollToSection(_updatesKey)),
                                _mobileMenuItem('Services', () => _scrollToSection(_servicesKey)),
                                _mobileMenuItem('Reviews', () => _scrollToSection(_reviewsKey)),
                                _mobileMenuItem('Contact', () => _scrollToSection(_contactKey)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      // Fixed Bottom Button
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                        child: ElevatedButton(
                          onPressed: () {
                            _toggleMobileMenu();
                            Navigator.pushNamed(context, '/login');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC62828),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            minimumSize: const Size(double.infinity, 54),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: const Text('Login',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
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

  Widget _mobileMenuItem(String title, VoidCallback onTap) {
    bool isHovered = false;
    return StatefulBuilder(builder: (context, setState) {
      return MouseRegion(
        onEnter: (_) => setState(() => isHovered = true),
        onExit: (_) => setState(() => isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isHovered 
                ? const Color(0xFFC62828).withValues(alpha: 0.05) 
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            visualDensity: VisualDensity.compact,
            title: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 18,
                fontWeight: isHovered ? FontWeight.w700 : FontWeight.w600,
                color: isHovered ? const Color(0xFFC62828) : const Color(0xFF3E2723),
              ),
              child: Text(title),
            ),
            onTap: onTap,
          ),
        ),
      );
    });
  }

  Widget _buildScrollToTopButton() {
    return Positioned(
      bottom: 30,
      right: 30,
      child: AnimatedOpacity(
        opacity: _showScrollToTop ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: _showScrollToTop
            ? FloatingActionButton(
                backgroundColor: const Color(0xFFC62828),
                onPressed: _scrollToTop,
                elevation: 4,
                child: const Icon(Icons.keyboard_arrow_up_rounded,
                    color: Colors.white),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. HOME / HERO SECTION
  // ---------------------------------------------------------------------------

  Widget _buildHeroSection(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final isTablet = ResponsiveUtils.isTablet(context);

    return Container(
      key: _homeKey,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(60),
          bottomRight: Radius.circular(60),
        ),
      ),
      padding: EdgeInsets.only(
        top: isDesktop ? 40 : 30,
        bottom: 10,
        left: 24,
        right: 24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: (isDesktop || isTablet)
              ? _buildHeroDesktopContent(isTablet)
              : _buildHeroMobileContent(),
        ),
      ),
    );
  }

  Widget _buildHeroDesktopContent(bool isTablet) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: isTablet ? 1 : 5,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: isTablet ? 48 : 64,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                      children: const [
                        TextSpan(text: 'Authentic Flavors,\nTrue '),
                        TextSpan(
                            text: 'Heritage',
                            style: TextStyle(color: Colors.amber)), // Changed to amber for contrast on red
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Experience the heart of Chinese culinary tradition.\nFrom our handpicked ingredients to our master chefs,\nwe bring you an unforgettable dining journey.',
                    style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        height: 1.6),
                  ),
                  const SizedBox(height: 48),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFC62828),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 20),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      elevation: 8,
                      shadowColor:
                          Colors.black.withValues(alpha: 0.2),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Reserve now',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          flex: isTablet ? 1 : 6,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              width: isTablet ? 350 : 450,
              height: isTablet ? 350 : 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  )
                ],
                image: const DecorationImage(
                  image: AssetImage('assets/images/PancitCanton.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroMobileContent() {
    return Column(
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            style: TextStyle(
              fontSize: 42,
              height: 1.2,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
            children: [
              TextSpan(text: 'Authentic Flavors,\nTrue '),
              TextSpan(
                  text: 'Heritage',
                  style: TextStyle(color: Colors.amber)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Experience the heart of Chinese culinary tradition. From our handpicked ingredients to our master chefs, we bring you an unforgettable dining journey.',
          textAlign: TextAlign.center,
          style:
              TextStyle(fontSize: 14, color: Colors.white70, height: 1.5),
        ),
        const SizedBox(height: 48),
        Container(
          width: 300,
          height: 300,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, 15),
              )
            ],
            image: const DecorationImage(
              image: AssetImage('assets/images/PancitCanton.jpg'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 60),
        ElevatedButton(
          onPressed: () => Navigator.pushNamed(context, '/login'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFFC62828),
            padding:
                const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30)),
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.2),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Reserve now',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, size: 20),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 2. ABOUT SECTION
  // ---------------------------------------------------------------------------

  Widget _buildAboutSection(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final isTablet = ResponsiveUtils.isTablet(context);

    // Stats section removed as per user request

    return Container(
      key: _aboutKey,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
      color: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              // Section label
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'OUR STORY',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.2),
                  children: [
                    TextSpan(text: 'A Legacy of '),
                    TextSpan(
                        text: 'Authentic',
                        style: TextStyle(color: Colors.amber)),
                    TextSpan(text: '\nChinese Cuisine'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Yang Chow has been serving authentic Chinese cuisine rooted in generations of culinary tradition. '
                'Our chefs bring passion and expertise to every dish, using only the finest, freshest ingredients '
                'sourced daily. From our signature dim sum to our hearty noodle soups, every bite tells a story of culture, '
                'care, and craft.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white70,
                  height: 1.8,
                ),
              ),
              const SizedBox(height: 40),
              // Image + text block
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 5, child: _buildAboutImageGrid()),
                    const SizedBox(width: 60),
                    Expanded(flex: 5, child: _buildAboutTextBlock()),
                  ],
                )
              else if (isTablet)
                Column(children: [
                  _buildAboutImageGrid(),
                  const SizedBox(height: 48),
                  _buildAboutTextBlock(),
                ])
              else
                Column(children: [
                  _buildAboutImageGrid(),
                  const SizedBox(height: 40),
                  _buildAboutTextBlock(),
                ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAboutImageGrid() {
    return SizedBox(
      height: 360,
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/images/YangChow.jpg',
                fit: BoxFit.cover,
                height: 360,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/Yang.jpg',
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/Chow.jpg',
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutTextBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Why Dine with Us?',
          style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
        ),
        const SizedBox(height: 24),
        _buildAboutFeature(
          Icons.eco_rounded,
          'Fresh Ingredients Daily',
          'We source only the finest produce and seafood every morning to guarantee freshness in every dish.',
        ),
        const SizedBox(height: 20),
        _buildAboutFeature(
          Icons.emoji_events_rounded,
          'Award-Winning Chefs',
          'Our culinary team brings decades of experience, creativity, and passion to every plate we serve.',
        ),
        const SizedBox(height: 20),
        _buildAboutFeature(
          Icons.people_rounded,
          'Family-Friendly Atmosphere',
          'We\'re more than a restaurant we\'re a place where families gather, memories are made, and traditions live on.',
        ),
      ],
    );
  }

  Widget _buildAboutFeature(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.white)),
              const SizedBox(height: 4),
              Text(desc,
                  style: const TextStyle(
                      fontSize: 13, color: Colors.white70, height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 3. MENU SECTION
  // ---------------------------------------------------------------------------

  Widget _buildMenuSection(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final isTablet = ResponsiveUtils.isTablet(context);

    return Container(
      key: _menuKey,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
      color: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Center(
                child: RichText(
                  textAlign: TextAlign.center,
                  text: const TextSpan(
                    style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Colors.white),
                    children: [
                      TextSpan(text: 'Signature '),
                      TextSpan(
                          text: 'Menu',
                          style: TextStyle(color: Colors.amber)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Builder(builder: (context) {
                final menuCards = _featuredMenuItems.isNotEmpty 
                  ? _featuredMenuItems.map((item) => _buildMenuCard(
                      item.customImagePath ?? item.fallbackImagePath,
                      item.name,
                      item.category,
                      '₱${item.price.toStringAsFixed(0)}',
                      context,
                    )).toList()
                  : [
                      _buildMenuCard('assets/images/YCFChicken.jpg',
                          'Yang Chow Chicken', 'Crispy & golden fried', '₱280', context),
                      _buildMenuCard('assets/images/PancitCLM.jpg',
                          'Pancit Canton LM', 'Classic lo mein style', '₱220', context),
                      _buildMenuCard('assets/images/BeefFriedRice.png',
                          'Beef Fried Rice', 'Wok-tossed special', '₱260', context),
                      _buildMenuCard(
                          'assets/images/Hakaw.png', 'Hakaw Dimsum', 'Fresh shrimp parcels', '₱180', context),
                    ];
                if (isDesktop) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: menuCards
                        .map((c) => Expanded(
                              child: Padding(
                                  padding: EdgeInsets.only(
                                      right: menuCards.last == c ? 0 : 20),
                                  child: c),
                            ))
                        .toList(),
                  );
                } else if (isTablet) {
                  return Center(
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 24,
                      alignment: WrapAlignment.center,
                      children:
                          menuCards.map((c) => SizedBox(width: 320, child: c)).toList(),
                    ),
                  );
                } else {
                  final screenWidth = MediaQuery.of(context).size.width;
                  final cardWidth = (screenWidth - 48 - 16) / 2;
                  return Center(
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: menuCards
                          .map((c) => SizedBox(width: cardWidth, child: c))
                          .toList(),
                    ),
                  );
                }
              }),
              const SizedBox(height: 48),
              Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC62828),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    elevation: 4,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('View Full Menu',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 16),
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



  Widget _buildMenuCard(
      String imagePath, String title, String subtitle, String price, BuildContext context) {
    bool isHovered = false;
    final isMobile = ResponsiveUtils.isMobile(context);
    
    return StatefulBuilder(builder: (context, setState) {
      return MouseRegion(
        onEnter: (_) => setState(() => isHovered = true),
        onExit: (_) => setState(() => isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(0, isHovered ? -5 : 0, 0),
          padding: EdgeInsets.all(isMobile ? 12 : 20),
          decoration: BoxDecoration(
            color: isHovered ? Colors.white : const Color(0xFFF9F9F9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: isHovered
                    ? const Color(0xFFC62828).withValues(alpha: 0.3)
                    : Colors.transparent),
            boxShadow: isHovered
                ? [
                    BoxShadow(
                        color: Colors.orange.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10))
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                height: isMobile ? 80 : 120,
                width: isMobile ? 80 : 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: AssetImage(imagePath),
                    fit: BoxFit.cover,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
              ),
              SizedBox(height: isMobile ? 12 : 20),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 14 : 18,
                  color: const Color(0xFF1E1E1E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: isMobile ? 10 : 12,
                  color: const Color(0xFF757575),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: isMobile ? 8 : 16),
              Text(
                price,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 16 : 18,
                  color: const Color(0xFFC62828),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  // ---------------------------------------------------------------------------
  // 4. UPDATES SECTION
  // ---------------------------------------------------------------------------

  Widget _buildUpdatesSection(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final isTablet = ResponsiveUtils.isTablet(context);

    // If empty, we show a special placeholder card to "restore" the section
    final List<Widget> updates = _announcements.isEmpty 
      ? [
          _buildUpdateCard(
            null, // Use fallback assets/images/YCFriedRice.jpg
            'More Updates Coming Soon',
            DateFormat('MMMM yyyy').format(DateTime.now()),
            'We are constantly working on new promos and seasonal specialties. Check back soon for the latest news from Yang Chow!',
            'Stay Tuned',
            const Color(0xFFC62828),
          )
        ]
      : _announcements.map((a) {
          final index = _announcements.indexOf(a);
          final colors = [
            const Color(0xFFC62828), // New Arrival / Red
            const Color(0xFF2E7D32), // Promo / Green
            const Color(0xFF1565C0), // Seasonal / Blue
            const Color(0xFFE65100), // Event / Orange
            const Color(0xFF4527A0), // Special / Purple
          ];
          
          // Determine tag color based on tag text if possible, otherwise cycle
          Color tagColor = colors[index % colors.length];
          final tag = a['tag']?.toString() ?? 'Update';
          if (tag.toLowerCase().contains('promo')) tagColor = const Color(0xFF2E7D32);
          if (tag.toLowerCase().contains('arrival') || tag.toLowerCase().contains('new')) tagColor = const Color(0xFFC62828);
          if (tag.toLowerCase().contains('season')) tagColor = const Color(0xFF1565C0);

          // Date formatting
          String dateStr = 'Latest news';
          if (a['created_at'] != null) {
            try {
              final dt = DateTime.parse(a['created_at'].toString());
              dateStr = DateFormat('MMMM yyyy').format(dt);
            } catch (_) {}
          }

          return _buildUpdateCard(
            a['image_url']?.toString(), // Pass null if empty
            a['title'] ?? 'Announcement',
            dateStr,
            a['content'] ?? '',
            tag,
            tagColor,
          );
        }).toList();

    return Container(
      key: _updatesKey,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
      color: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'LATEST NEWS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.2),
                  children: [
                    TextSpan(text: 'What\'s '),
                    TextSpan(
                        text: 'New',
                        style: TextStyle(color: Colors.amber)),
                    TextSpan(text: ' at Yang Chow'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Stay up-to-date with our latest offerings, promos, and seasonal specials.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15, color: Colors.white70, height: 1.6),
              ),
              const SizedBox(height: 60),
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: updates
                      .map((u) => Expanded(
                              child: Padding(
                            padding: EdgeInsets.only(
                                right: updates.last == u ? 0 : 24),
                            child: u,
                          )))
                      .toList(),
                )
              else if (isTablet)
                Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  alignment: WrapAlignment.center,
                  children: updates
                      .map((u) => SizedBox(width: 340, child: u))
                      .toList(),
                )
              else
                Column(
                  children: [
                    for (int i = 0; i < updates.length; i++) ...[
                      updates[i],
                      if (i != updates.length - 1) const SizedBox(height: 24),
                    ]
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateCard(
    String? imagePath,
    String title,
    String date,
    String description,
    String tag,
    Color tagColor,
  ) {
    bool isHovered = false;
    return StatefulBuilder(builder: (context, setState) {
      return MouseRegion(
        onEnter: (_) => setState(() => isHovered = true),
        onExit: (_) => setState(() => isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(0, isHovered ? -6 : 0, 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isHovered ? 0.12 : 0.05),
                blurRadius: isHovered ? 24 : 12,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: imagePath != null && imagePath.startsWith('http')
                      ? Image.network(
                          imagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Image.asset('assets/images/YCFriedRice.jpg',
                                  fit: BoxFit.cover),
                        )
                      : Image.asset(
                          imagePath ?? 'assets/images/YCFriedRice.jpg',
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: tagColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(tag,
                              style: TextStyle(
                                  color: tagColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11)),
                        ),
                        Text(date,
                            style: const TextStyle(
                                color: Color(0xFF9E9E9E), fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(title,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E1E1E))),
                    const SizedBox(height: 8),
                    Text(description,
                        style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF555555),
                            height: 1.6)),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () {},
                      icon: const Text('Read More',
                          style: TextStyle(
                              color: Color(0xFFC62828),
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      label: const Icon(Icons.arrow_forward_rounded,
                          color: Color(0xFFC62828), size: 14),
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      );
    });
  }

  // ---------------------------------------------------------------------------
  // 5. SERVICES SECTION
  // ---------------------------------------------------------------------------

  Widget _buildServicesSection(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final isTablet = ResponsiveUtils.isTablet(context);

    final services = [
      _buildServiceCard(
        Icons.table_restaurant_rounded,
        'Dine-In Experience',
        'Enjoy a premium dining atmosphere with attentive service, elegant table settings, and an extensive menu crafted for every occasion.',
      ),
      _buildServiceCard(
        Icons.celebration_rounded,
        'Private Events',
        'Planning a birthday, reunion, or corporate event? We offer tailored catering packages and exclusive private dining spaces.',
      ),
      _buildServiceCard(
        Icons.shopping_bag_rounded,
        'Takeout or Pickup',
        'Prefer dining at home? Order your favorites physically to takehome or advance order by online to freshly prepared and ready for pickup.',
      ),
      _buildServiceCard(
        Icons.calendar_month_rounded,
        'Reservation System',
        'Skip the wait reserve a table in advance through our quick and easy online booking system. Available 7 days a week.',
      ),
      _buildServiceCard(
        Icons.groups_rounded,
        'Group Packages',
        'Feeding a crowd? Our group set menus are designed for maximum variety and value perfect for families, teams, and celebrations.',
      ),
    ];

    return Container(
      key: _servicesKey,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
      color: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'WHAT WE OFFER',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.2),
                  children: [
                    TextSpan(text: 'Elite Services for\n'),
                    TextSpan(
                        text: 'Every Occasion',
                        style: TextStyle(color: Colors.amber)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'From an intimate dinner for two to a grand celebration for hundreds, Yang Chow delivers excellence at every scale.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15, color: Colors.white, height: 1.6),
              ),
              const SizedBox(height: 60),
              if (isDesktop)
                _buildServicesGrid(services, columns: 3)
              else if (isTablet)
                _buildServicesGrid(services, columns: 2)
              else
                Column(
                  children: [
                    for (int i = 0; i < services.length; i++) ...[
                      services[i],
                      if (i != services.length - 1) const SizedBox(height: 20),
                    ]
                  ],
                ),
              const SizedBox(height: 60),
              // CTA banner
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFC62828), Color(0xFFE53935)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Ready to Experience Yang Chow?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Reserve your event space today or contact us to customize a special event package tailored to your needs.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.5),
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFC62828),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 36, vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        elevation: 0,
                      ),
                      child: const Text('Reserve Your Event Venue',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
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

  Widget _buildServicesGrid(List<Widget> items, {required int columns}) {
    final rows = <Widget>[];
    for (int i = 0; i < items.length; i += columns) {
      final rowItems = items.sublist(
          i, (i + columns) > items.length ? items.length : i + columns);
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rowItems
            .map((item) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: rowItems.last == item ? 0 : 20,
                      bottom: 20,
                    ),
                    child: item,
                  ),
                ))
            .toList(),
      ));
    }
    return Column(children: rows);
  }

  Widget _buildServiceCard(IconData icon, String title, String description) {
    bool isHovered = false;
    return StatefulBuilder(builder: (context, setState) {
      return MouseRegion(
        onEnter: (_) => setState(() => isHovered = true),
        onExit: (_) => setState(() => isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(0, isHovered ? -4 : 0, 0),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: isHovered ? const Color(0xFFFFF3F3) : const Color(0xFFF9F9F9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: isHovered
                    ? const Color(0xFFC62828).withValues(alpha: 0.3)
                    : Colors.transparent),
            boxShadow: isHovered
                ? [
                    BoxShadow(
                        color:
                            const Color(0xFFC62828).withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8))
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFC62828).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFFC62828), size: 28),
              ),
              const SizedBox(height: 20),
              Text(title,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E1E1E))),
              const SizedBox(height: 10),
              Text(description,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF555555), height: 1.6)),
            ],
          ),
        ),
      );
    });
  }

  // ---------------------------------------------------------------------------
  // 6. REVIEWS SECTION
  // ---------------------------------------------------------------------------

  Widget _buildReviewsSection(BuildContext context) {
    if (_totalReviewCount == 0) return const SizedBox.shrink();

    final isDesktop = ResponsiveUtils.isDesktop(context);
    final isTablet = ResponsiveUtils.isTablet(context);

    final reviews = _reviews.map((r) => _buildReviewCard(
            r['name'] ?? 'Anonymous',
            r['location'] ?? 'Philippines',
            r['review_text'] ?? '',
            (r['rating'] as num?)?.toInt() ?? 5,
          )).toList();

    return Container(
      key: _reviewsKey,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
      color: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'TESTIMONIALS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.2),
                  children: [
                    TextSpan(text: 'Our Customers '),
                    TextSpan(
                        text: 'Love',
                        style: TextStyle(color: Colors.amber)),
                    TextSpan(text: ' Yang Chow'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Real stories from real guests — here\'s what our community says about us.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15, color: Colors.white70, height: 1.6),
              ),
              const SizedBox(height: 20),
              // Overall rating summary
              _buildOverallRating(),
              const SizedBox(height: 60),
              if (isDesktop)
                _buildReviewsGrid(reviews, columns: 3)
              else if (isTablet)
                _buildReviewsGrid(reviews, columns: 2)
              else
                Column(
                  children: [
                    for (int i = 0; i < reviews.length; i++) ...[
                      reviews[i],
                      if (i != reviews.length - 1) const SizedBox(height: 20),
                    ]
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverallRating() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_averageRating.toStringAsFixed(1),
              style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E1E1E))),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: List.generate(
                  5,
                  (index) => Icon(
                    index < _averageRating.floor() 
                      ? Icons.star_rounded 
                      : (index < _averageRating ? Icons.star_half_rounded : Icons.star_outline_rounded),
                    color: Colors.amber, 
                    size: 22
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text('Based on $_totalReviewCount ${_totalReviewCount == 1 ? 'review' : 'reviews'}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF757575))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsGrid(List<Widget> items, {required int columns}) {
    final rows = <Widget>[];
    for (int i = 0; i < items.length; i += columns) {
      final rowItems = items.sublist(
          i, (i + columns) > items.length ? items.length : i + columns);
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rowItems
            .map((item) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: rowItems.last == item ? 0 : 20, bottom: 20),
                    child: item,
                  ),
                ))
            .toList(),
      ));
    }
    return Column(children: rows);
  }

  Widget _buildReviewCard(
      String name, String location, String review, int stars) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ...List.generate(
                  stars,
                  (_) => const Icon(Icons.star_rounded,
                      color: Colors.amber, size: 16)),
              ...List.generate(
                  5 - stars,
                  (_) => const Icon(Icons.star_outline_rounded,
                      color: Colors.amber, size: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Text(review,
              style: const TextStyle(
                  color: Color(0xFF555555), fontSize: 13, height: 1.6)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFFC62828).withValues(alpha: 0.15),
                    child: Text(
                      name.isNotEmpty ? name.substring(0, 1) : 'A',
                      style: const TextStyle(
                          color: Color(0xFFC62828),
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(location,
                          style: const TextStyle(
                              color: Color(0xFF757575), fontSize: 11)),
                    ],
                  ),
                ],
              ),
              Icon(Icons.format_quote_rounded,
                  color: const Color(0xFFC62828).withValues(alpha: 0.2),
                  size: 36),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 7. MAP SECTION
  // ---------------------------------------------------------------------------

  Widget _buildMapSection(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      color: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'FIND US',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.2),
                  children: [
                    TextSpan(text: 'Visit Our '),
                    TextSpan(
                        text: 'Location',
                        style: TextStyle(color: Colors.amber)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Container(
                  height: isDesktop ? 450 : 400,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      // --- Map Layer ---
                      FlutterMap(
                        mapController: _mapController,
                        options: const MapOptions(
                          initialCenter: _restaurantLocation,
                          initialZoom: 16.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: _isSatelliteMode 
                              ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                              : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.yangchow.app',
                          ),
                          // Route Polyline
                          if (_routePoints.isNotEmpty)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: _routePoints,
                                  color: const Color(0xFFC62828),
                                  strokeWidth: 4.0,
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: [
                              // Restaurant Marker (Always show unless routing somewhere else)
                              if (_destinationController.text == 'Yang Chow')
                                Marker(
                                  point: _restaurantLocation,
                                  width: 80,
                                  height: 80,
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.1),
                                              blurRadius: 4,
                                            )
                                          ],
                                        ),
                                        child: const Text(
                                          'Yang Chow',
                                          style: TextStyle(
                                            color: Color(0xFFC62828),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.location_on_rounded,
                                        color: Color(0xFFC62828),
                                        size: 40,
                                      ),
                                    ],
                                  ),
                                ),
                              // Start Marker
                              if (_startLatLng != null)
                                Marker(
                                  point: _startLatLng!,
                                  width: 40,
                                  height: 40,
                                  child: const Icon(Icons.radio_button_checked, color: Colors.blue, size: 24),
                                ),
                              // Destination Marker (If not Yang Chow)
                              if (_destinationLatLng != null && _destinationController.text != 'Yang Chow')
                                Marker(
                                  point: _destinationLatLng!,
                                  width: 40,
                                  height: 40,
                                  child: const Icon(Icons.location_on, color: Color(0xFFC62828), size: 30),
                                ),
                              // Real-time User Marker
                              if (_userLocation != null && _startLatLng == null)
                                Marker(
                                  point: _userLocation!,
                                  width: 40,
                                  height: 40,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.person_pin_circle_rounded,
                                        color: Colors.blue,
                                        size: 30,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),

                      // --- Search / Directions Panel Overlay ---
                      Positioned(
                        top: 16,
                        left: 16,
                        right: 16,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _showDirectionsPanel 
                            ? _buildDirectionsPanel() 
                            : _buildSimpleSearchBar(),
                        ),
                      ),

                      // --- Action Buttons (Bottom Right) ---
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildMapActionBtn(
                              icon: Icons.my_location,
                              onPressed: _getCurrentLocation,
                              tooltip: 'My Location',
                            ),
                            const SizedBox(height: 8),
                            _buildMapActionBtn(
                              icon: _showDirectionsPanel ? Icons.close : Icons.directions_rounded,
                              onPressed: () {
                                setState(() {
                                  _showDirectionsPanel = !_showDirectionsPanel;
                                  if (!_showDirectionsPanel) {
                                    _routePoints = [];
                                    _startLatLng = null;
                                  }
                                });
                              },
                              tooltip: _showDirectionsPanel ? 'Close Directions' : 'Get Directions',
                              color: _showDirectionsPanel ? Colors.white : const Color(0xFFC62828),
                              iconColor: _showDirectionsPanel ? const Color(0xFFC62828) : Colors.white,
                            ),
                            const SizedBox(height: 8),
                            _buildMapActionBtn(
                              icon: Icons.map_outlined,
                              onPressed: () async {
                                final url = 'https://www.google.com/maps/dir/?api=1&destination=${_restaurantLocation.latitude},${_restaurantLocation.longitude}';
                                if (await canLaunchUrl(Uri.parse(url))) {
                                  await launchUrl(Uri.parse(url));
                                }
                              },
                              tooltip: 'Open in Google Maps',
                            ),
                          ],
                        ),
                      ),

                      // --- Zoom Controls (Left Side) ---
                      Positioned(
                        bottom: 16,
                        left: 16,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildMapActionBtn(
                              icon: Icons.add,
                              onPressed: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1),
                              tooltip: 'Zoom In',
                            ),
                            const SizedBox(height: 8),
                            _buildMapActionBtn(
                              icon: Icons.remove,
                              onPressed: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1),
                              tooltip: 'Zoom Out',
                            ),
                            const SizedBox(height: 8),
                            _buildMapActionBtn(
                              icon: _isSatelliteMode ? Icons.layers : Icons.layers_outlined,
                              onPressed: () => setState(() => _isSatelliteMode = !_isSatelliteMode),
                              tooltip: 'Toggle Satellite View',
                              color: _isSatelliteMode ? const Color(0xFFC62828) : Colors.white,
                              iconColor: _isSatelliteMode ? Colors.white : const Color(0xFF333333),
                            ),
                          ],
                        ),
                      ),

                      // --- Routing Loading Overlay ---
                      if (_isRouting)
                        Container(
                          color: Colors.black.withValues(alpha: 0.3),
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: Colors.white),
                                SizedBox(height: 16),
                                Text(
                                  'Calculating Route...',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ],
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
    );
  }

  Widget _buildSimpleSearchBar() {
    return Container(
      key: const ValueKey('simple_search'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _mapSearchController,
        decoration: InputDecoration(
          hintText: 'Search location...',
          hintStyle: const TextStyle(fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: Color(0xFFC62828)),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => _mapSearchController.clear(),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
        onSubmitted: _searchPlace,
      ),
    );
  }

  Widget _buildDirectionsPanel() {
    return Container(
      key: const ValueKey('directions_panel'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                onPressed: () => setState(() => _showDirectionsPanel = false),
              ),
              const Expanded(
                child: Text(
                  'Your Route',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.swap_vert_rounded),
                onPressed: _swapRoutingPoints,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildRoutingTextField(
            controller: _startPointController,
            hint: 'Choose starting point...',
            icon: Icons.radio_button_checked,
            iconColor: Colors.blue,
          ),
          const SizedBox(height: 8),
          _buildRoutingTextField(
            controller: _destinationController,
            hint: 'Choose destination...',
            icon: Icons.location_on,
            iconColor: const Color(0xFFC62828),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _getRoute,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 45),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Get Directions', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutingTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: iconColor, size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          suffixIcon: controller.text == 'Your location' 
            ? null 
            : IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: () => controller.clear(),
              ),
        ),
      ),
    );
  }

  Widget _buildMapActionBtn({
    required IconData icon,
    required VoidCallback onPressed,
    String? tooltip,
    Color color = Colors.white,
    Color iconColor = const Color(0xFF333333),
  }) {
    return FloatingActionButton.small(
      heroTag: 'map_btn_${icon.codePoint}',
      onPressed: onPressed,
      backgroundColor: color,
      elevation: 4,
      tooltip: tooltip,
      child: Icon(icon, color: iconColor, size: 20),
    );
  }

  // ---------------------------------------------------------------------------
  // 8. CONTACT / FOOTER SECTION
  // ---------------------------------------------------------------------------

  Widget _buildContactFooterSection(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final isTablet = ResponsiveUtils.isTablet(context);

    return Container(
      key: _contactKey,
      color: Colors.transparent,
      child: Column(
        children: [
          // Contact info block
          Container(
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
            color: Colors.transparent,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'CONTACT US',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.2),
                        children: [
                          TextSpan(text: 'Get in '),
                          TextSpan(
                              text: 'Touch',
                              style: TextStyle(color: Colors.amber)),
                          TextSpan(text: ' With Us'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Have a question, a reservation request, or want to plan a private event? We\'d love to hear from you.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 15, color: Colors.white70, height: 1.6),
                    ),
                    const SizedBox(height: 60),
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: _buildContactInfoBlock()),
                          const SizedBox(width: 60),
                          Expanded(flex: 5, child: _buildContactForm()),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildContactInfoBlock(),
                          const SizedBox(height: 48),
                          _buildContactForm(),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Footer bottom strip
          Container(
            padding: const EdgeInsets.only(
                top: 10, bottom: 40, left: 24, right: 24),
            color: Colors.transparent,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  children: [
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(flex: 2, child: _buildFooterCol1()),
                          Expanded(child: _buildFooterQuickLinks()),
                          Expanded(child: _buildFooterCol2()),
                        ],
                      )
                    else if (isTablet)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(child: _buildFooterCol1()),
                          Expanded(child: _buildFooterQuickLinks()),
                          Expanded(child: _buildFooterCol2()),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFooterCol1(),
                          const SizedBox(height: 40),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(child: _buildFooterQuickLinks()),
                              Expanded(child: _buildFooterCol2()),
                            ],
                          ),
                        ],
                      ),
                    const SizedBox(height: 40),
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text(
                      '© 2026 Yang Chow Restaurant. All rights reserved.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfoBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildContactItem(
          Icons.location_on_rounded,
          'Our Location',
          'CLA Town Center Mall\nPagsanjan, Laguna, Philippines 4008',
        ),
        const SizedBox(height: 32),
        _buildContactItem(
          Icons.schedule_rounded,
          'Opening Hours',
          'Monday – Sunday: 10:00 AM – 08:00 PM',
        ),
        const SizedBox(height: 32),
        _buildContactItem(
          Icons.phone_rounded,
          'Call Us',
          'TEL# 501-9179\nCP# +63975-041-9671',
        ),
        const SizedBox(height: 32),
        _buildContactItem(
          Icons.email_rounded,
          'Email',
          'reservations@yangchow.ph\nsupport@yangchow.ph',
        ),
      ],
    );
  }

  Widget _buildContactItem(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.6)),
          ],
        ),
      ],
    );
  }

  Widget _buildContactForm() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Send us a Message',
              style: TextStyle(
                  color: Color(0xFF1E1E1E),
                  fontWeight: FontWeight.bold,
                  fontSize: 20)),
          const SizedBox(height: 24),
          _buildFormField('Your Name', Icons.person_outline_rounded),
          const SizedBox(height: 16),
          _buildFormField('Email Address', Icons.email_outlined),
          const SizedBox(height: 16),
          _buildFormField('Phone Number', Icons.phone_outlined),
          const SizedBox(height: 16),
          _buildFormField('Your Message', Icons.message_outlined, maxLines: 4),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC62828),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text('Send Message',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField(String hint, IconData icon, {int maxLines = 1}) {
    return TextField(
      maxLines: maxLines,
      style: const TextStyle(color: Color(0xFF1E1E1E), fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
        prefixIcon: maxLines == 1
            ? Icon(icon, color: Color(0xFF9E9E9E), size: 18)
            : null,
        filled: true,
        fillColor: const Color(0xFFF9F9F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFC62828)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildFooterCol1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'YangChow',
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white),
        ),
        const SizedBox(height: 12),
        const Text(
          'Authentic Chinese Cuisine that brings\nfamily and friends together for\nunforgettable dining moments.',
          style: TextStyle(
              color: Colors.white70, fontSize: 12, height: 1.6),
        ),
        const SizedBox(height: 20),
        const Row(
          children: [
            Icon(Icons.facebook, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Icon(Icons.camera_alt, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Icon(Icons.ondemand_video, color: Colors.white, size: 20),
          ],
        )
      ],
    );
  }

  Widget _buildFooterQuickLinks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('QUICK LINKS',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.white)),
        const SizedBox(height: 20),
        ...[
          ('Home', () => _scrollToTop()),
          ('About', () => _scrollToSection(_aboutKey)),
          ('Menu', () => _scrollToSection(_menuKey)),
          ('Updates', () => _scrollToSection(_updatesKey)),
          ('Services', () => _scrollToSection(_servicesKey)),
          ('Reviews', () => _scrollToSection(_reviewsKey)),
          ('Contact', () => _scrollToSection(_contactKey)),
        ].map((pair) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: pair.$2,
                child: Text(pair.$1,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12)),
              ),
            )),
      ],
    );
  }

  Widget _buildFooterCol2() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('COMPANY INFO',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        SizedBox(height: 20),
        _FooterLink(text: 'Profile'),
        SizedBox(height: 10),
        _FooterLink(text: 'Blog'),
        SizedBox(height: 10),
        _FooterLink(text: 'Careers'),
        SizedBox(height: 10),
        _FooterLink(text: 'Testimonials'),
        SizedBox(height: 10),
        _FooterLink(text: 'Location'),
        SizedBox(height: 10),
        _FooterLink(text: 'Privacy Policy'),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widget for footer links
// ---------------------------------------------------------------------------

class _FooterLink extends StatelessWidget {
  final String text;
  const _FooterLink({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(color: Colors.white70, fontSize: 12));
  }
}

// ---------------------------------------------------------------------------
// Custom Painter for Chinese Grid Pattern
// ---------------------------------------------------------------------------

class ChinesePatternPainter extends CustomPainter {
  final Color color;

  ChinesePatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const double tileSize = 40.0;
    const double padding = 8.0;
    const double innerSize = tileSize - (padding * 2);

    for (double x = 0; x < size.width; x += tileSize) {
      for (double y = 0; y < size.height; y += tileSize) {
        // Outer square
        canvas.drawRect(
          Rect.fromLTWH(x + 2, y + 2, tileSize - 4, tileSize - 4),
          paint,
        );

        // Inner square
        canvas.drawRect(
          Rect.fromLTWH(
              x + padding + 2, y + padding + 2, innerSize - 4, innerSize - 4),
          paint,
        );
        
        // Small center dot/square
        canvas.drawRect(
          Rect.fromLTWH(x + (tileSize / 2) - 1, y + (tileSize / 2) - 1, 2, 2),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
