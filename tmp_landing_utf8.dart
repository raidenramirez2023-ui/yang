import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _heroKey = GlobalKey();
  final GlobalKey _aboutKey = GlobalKey();
  final GlobalKey _servicesKey = GlobalKey();
  final GlobalKey _updatesKey = GlobalKey();
  final GlobalKey _hoursKey = GlobalKey();
  final GlobalKey _contactKey = GlobalKey();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isCheckingSession = true;
  int? _selectedMonth; // null means "Show All" or "Latest"
  bool _showScrollToTop = false;
  
  // Real-time announcements stream
  Stream<List<Map<String, dynamic>>> _announcementsStream = const Stream.empty();

  @override
  void initState() {
    super.initState();
    
    // Initialize real-time announcements stream first
    _announcementsStream = Supabase.instance.client
        .from('announcements')
        .stream(primaryKey: ['id'])
        .eq('is_active', true)
        .order('created_at', ascending: false);
    
    // Add scroll listener
    _scrollController.addListener(_scrollListener);
    
    _checkAndRedirectUser();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.offset >= MediaQuery.of(context).size.height * 0.5) {
      if (!_showScrollToTop) {
        setState(() {
          _showScrollToTop = true;
        });
      }
    } else {
      if (_showScrollToTop) {
        setState(() {
          _showScrollToTop = false;
        });
      }
    }
  }

  Future<void> _checkAndRedirectUser() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null && session.user.email != null) {
      final email = session.user.email!;
      final userResponse = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('email', email)
          .maybeSingle();

      if (mounted) {
        final navigator = Navigator.of(context);
        if (userResponse == null) {
          // It's a brand new Google user, insert them and go to customer dashboard
          await Supabase.instance.client.from('users').insert({
            'email': email,
            'role': 'customer',
          });
          navigator.pushReplacementNamed('/customer-dashboard');
          return;
        } else {
          String userRole = userResponse['role']?.toString().toLowerCase() ?? 'customer';
          _redirectByUserRole(email, userRole);
          return;
        }
      }
    }
    
    // If no session found or error, show landing page
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
    } else if (email.toLowerCase() == 'chefycp@gmail.com' || email.toLowerCase() == 'chefycp.gmail.com') {
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
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildScrollToTopButton() {
    return Positioned(
      bottom: 30,
      right: 30,
      child: AnimatedOpacity(
        opacity: _showScrollToTop ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: _showScrollToTop
            ? Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(28),
                    onTap: _scrollToTop,
                    child: const Icon(
                      Icons.keyboard_arrow_up_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingSession) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5DC),
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5F5DC),
      drawer: _buildMobileDrawer(),
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              children: [
                _buildHeroSection(context),
                _buildAboutUsSection(context),
                _buildUpdatesSection(context),
                _buildServicesSection(context),
                _buildHoursAndLocationSection(context),
                _buildContactSection(context),
                _buildSimpleFooter(context),
              ],
            ),
          ),
          _buildTopNavigationBar(context),
          _buildScrollToTopButton(),
        ],
      ),
    );
  }

  Widget _buildTopNavigationBar(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            decoration: BoxDecoration(
              color: Color(0xFF3E2723).withValues(alpha: 0.7),
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: MaxWidthContainer(
                child: Row(
                  children: [
                    // Brand Identity
                    Expanded(
                      child: InkWell(
                        key: const Key('brand_identity'),
                        onTap: () => _scrollToSection(_heroKey),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Color(0xFF3E2723).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Image.asset(
                                'assets/images/logo.jpg',
                                height: 32,
                                errorBuilder: (context, error, stackTrace) => 
                                    const Icon(Icons.restaurant_rounded, color: Color(0xFF3E2723), size: 20),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Flexible(
                              child: const Text(
                                'YANG CHOW',
                                style: TextStyle(
                                  color: Color(0xFF3E2723),
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 4,
                                  fontSize: 18,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    if (!isMobile) ...[
                      const SizedBox(width: 20),
                      _navButton('HOME', const Key('nav_home'), () => _scrollToSection(_heroKey)),
                      _navButton('ABOUT', const Key('nav_about'), () => _scrollToSection(_aboutKey)),
                      _navButton('UPDATES', const Key('nav_updates'), () => _scrollToSection(_updatesKey)),
                      _navButton('SERVICES', const Key('nav_services'), () => _scrollToSection(_servicesKey)),
                      _navButton('CONTACT', const Key('nav_contact'), () => _scrollToSection(_contactKey)),
                      const SizedBox(width: 20),
                    ],
                    
                    // Action Button
                    ElevatedButton(
                      key: const Key('nav_login_btn'),
                      onPressed: () => Navigator.pushNamed(context, '/login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: Text(
                        isMobile ? 'LOGIN' : 'SIGN IN',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1),
                      ),
                    ),
                    
                    if (isMobile) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        key: const Key('nav_menu_btn'),
                        icon: const Icon(Icons.menu_rounded, color: Colors.black),
                        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFFF5F5DC),
      child: Column(
        children: [
          Container(
            height: 200,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor,
                  Color(0xFF8B0000), // Darker red for depth
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFF3E2723).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset(
                      'assets/images/logo.jpg',
                      height: 50,
                      errorBuilder: (context, error, stackTrace) => 
                          const Icon(Icons.restaurant, color: Color(0xFF3E2723), size: 30),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'YANG CHOW',
                    style: TextStyle(
                      color: Color(0xFF3E2723),
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              children: [
                _drawerItem('HOME', Icons.home_rounded, const Key('drawer_home'), () => _scrollToSection(_heroKey)),
                _drawerItem('ABOUT', Icons.info_outline_rounded, const Key('drawer_about'), () => _scrollToSection(_aboutKey)),
                _drawerItem('UPDATES', Icons.notifications_none_rounded, const Key('drawer_updates'), () => _scrollToSection(_updatesKey)),
                _drawerItem('SERVICES', Icons.restaurant_menu_rounded, const Key('drawer_services'), () => _scrollToSection(_servicesKey)),
                _drawerItem('HOURS', Icons.schedule_rounded, const Key('drawer_hours'), () => _scrollToSection(_hoursKey)),
                _drawerItem('CONTACT', Icons.alternate_email_rounded, const Key('drawer_contact'), () => _scrollToSection(_contactKey)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              ' 2024 YANG CHOW',
              style: TextStyle(
                color: Color(0xFF3E2723).withValues(alpha: 0.3),
                fontSize: 10,
                letterSpacing: 1.2,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(String title, IconData icon, Key key, VoidCallback onTap) {
    return ListTile(
      key: key,
      contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
      leading: Icon(icon, color: AppTheme.primaryColor, size: 24),
      title: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF3E2723),
          fontWeight: FontWeight.w700,
          fontSize: 15,
          letterSpacing: 1,
        ),
      ),
      onTap: () {
        Navigator.pop(context); // Close drawer
        onTap();
      },
    );
  }

  Widget _navButton(String label, Key key, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _HoverableNavButton(
        label: label,
        key: key,
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    return SizedBox(
      key: _heroKey,
      height: MediaQuery.of(context).size.height,
      width: double.infinity,
      child: Stack(
        children: [
          // Background with subtle scaling effect
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/YC1.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          // Layered Gradients for Depth
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.5),
                    Colors.black.withValues(alpha: 0.9),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          // Content
          Center(
            child: MaxWidthContainer(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    // Elegant Subtitle with line decoration
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(width: isMobile ? 20 : 40, height: 1, color: AppTheme.primaryColor),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'SINCE 2024',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4,
                              fontSize: isMobile ? 10 : 12,
                            ),
                          ),
                        ),
                        Container(width: isMobile ? 20 : 40, height: 1, color: AppTheme.primaryColor),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Main Title with shadow for depth
                    Text(
                      'YANG CHOW',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getResponsiveFontSize(
                          context,
                          mobile: 48,
                          tablet: 84,
                          desktop: 110,
                        ),
                        fontWeight: FontWeight.w900,
                        color: AppTheme.white,
                        letterSpacing: isMobile ? 6 : 12,
                        height: 0.9,
                        shadows: [
                          Shadow(
                            color: Color(0xFF3E2723).withValues(alpha: 0.5),
                            offset: const Offset(0, 10),
                            blurRadius: 30,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'AUTHENTIC CHINESE CUISINE',
                      style: TextStyle(
                        color: AppTheme.white,
                        fontWeight: FontWeight.w300,
                        letterSpacing: isMobile ? 4 : 8,
                        fontSize: isMobile ? 14 : 18,
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Description
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: Text(
                        'Where tradition meets modern perfection. Discover a menu crafted with passion, featuring the finest ingredients and time-honored recipes that define the heart of Pagsanjan dining.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.white,
                          fontSize: isMobile ? 16 : 20,
                          height: 1.6,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                    const SizedBox(height: 64),
                    // Dynamic CTA Buttons
                    Wrap(
                      spacing: 24,
                      runSpacing: 20,
                      alignment: WrapAlignment.center,
                      children: [
                        _heroCTA(
                          'GET STARTED', 
                          () => Navigator.pushNamed(context, '/login'),
                          isPrimary: true,
                          isMobile: isMobile,
                        ),
                        _heroCTA(
                          'DISCOVER STORY', 
                          () => _scrollToSection(_aboutKey),
                          isPrimary: false,
                          isMobile: isMobile,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Scroll Indicator
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  'SCROLL TO EXPLORE',
                  style: TextStyle(
                    color: Color(0xFF3E2723).withValues(alpha: 0.3),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: 1,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppTheme.primaryColor,
                        AppTheme.primaryColor.withValues(alpha: 0),
                      ],
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

  Widget _heroCTA(String label, VoidCallback onTap, {required bool isPrimary, required bool isMobile}) {
    return Container(
      width: isMobile ? double.infinity : 220,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: isPrimary ? [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ] : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: ElevatedButton(
        key: Key('hero_cta_${label.replaceAll(' ', '_').toLowerCase()}'),
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? AppTheme.primaryColor : Colors.white,
          foregroundColor: isPrimary ? Colors.white : const Color(0xFF3E2723),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isPrimary ? BorderSide.none : BorderSide(color: AppTheme.primaryColor, width: 2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            fontSize: 14,
            color: isPrimary ? Colors.white : const Color(0xFF3E2723),
          ),
        ),
      ),
    );
  }

  
  Widget _buildAboutUsSection(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    return Container(
      key: _aboutKey,
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 80 : 120,
        horizontal: 24,
      ),
      color: const Color(0xFFF5F5DC), // Deep beige heritage background
      child: MaxWidthContainer(
        child: Column(
          children: [
            _sectionHeader(
              'OUR HERITAGE',
              'A Legacy of Taste in the Heart of Pagsanjan',
              isDark: true,
            ),
            const SizedBox(height: 80),
            Flex(
              direction: isMobile ? Axis.vertical : Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Image with decorative elements
                Expanded(
                  flex: isMobile ? 0 : 5,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        height: isMobile ? 300 : 500,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          image: const DecorationImage(
                            image: AssetImage('assets/images/YC2.png'),
                            fit: BoxFit.cover,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF3E2723).withValues(alpha: 0.3),
                              blurRadius: 40,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                      ),
                      if (!isMobile)
                        Positioned(
                          top: -20,
                          left: -20,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3), width: 2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(width: isMobile ? 0 : 80, height: isMobile ? 48 : 0),
                // Narrative Content
                Expanded(
                  flex: isMobile ? 0 : 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'THE STORY OF YANG CHOW',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Crafting Culinary Excellence Since Day One',
                        style: TextStyle(
                          color: Color(0xFF3E2723),
                          fontSize: isMobile ? 28 : 42,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Yang Chow Pagsanjan was born from a simple vision: to bring authentic, high-quality Chinese cuisine to our local community. What started as a passion for traditional flavors has grown into a beloved dining destination, where every detailΓÇöfrom the selection of our secret spices to the warmth of our serviceΓÇöis handled with utmost care.',
                        style: TextStyle(
                          color: Color(0xFF3E2723).withValues(alpha: 0.7),
                          fontSize: 18,
                          height: 1.8,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const SizedBox(height: 48),
                      // Heritage Stats
                      Row(
                        children: [
                          _aboutStat('100%', 'FRESHNESS'),
                          const SizedBox(width: 40),
                          _aboutStat('24/7', 'DEDICATION'),
                          const SizedBox(width: 40),
                          _aboutStat('ELITE', 'SERVICE'),
                        ],
                      ),
                      const SizedBox(height: 56),
                      TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.arrow_right_alt_rounded, color: AppTheme.primaryColor),
                        label: const Text(
                          'READ OUR FULL JOURNEY',
                          style: TextStyle(
                            color: Color(0xFF3E2723),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                            fontSize: 18,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 0),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _aboutStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF3E2723),
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: AppTheme.primaryColor,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }



  Widget _buildServicesSection(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    return Container(
      key: _servicesKey,
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 80 : 120,
        horizontal: 24,
      ),
      color: const Color(0xFFF5F5DC), // Light beige background for high contrast
      child: MaxWidthContainer(
        child: Column(
          children: [
            _sectionHeader(
              'ELITE SERVICES',
              'Tailored Dining Experiences for Every Occasion',
              isDark: true,
            ),
            const SizedBox(height: 80),
            Wrap(
              spacing: 32,
              runSpacing: 32,
              alignment: WrapAlignment.center,
              children: [
                _serviceCard(
                  Icons.restaurant_menu_rounded,
                  'PREMIUM DINE-IN',
                  'Experience authentic Chinese ambiance with our signature hospitality and freshly prepared delicacies.',
                  isMobile: isMobile,
                ),
                _serviceCard(
                  Icons.auto_awesome_rounded,
                  'EXQUISITE CATERING',
                  'Elevate your special events with a curated menu that brings the heart of Yang Chow to your venue.',
                  isMobile: isMobile,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _serviceCard(IconData icon, String title, String desc, {required bool isMobile}) {
    return Container(
      width: isMobile ? double.infinity : 450,
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05), width: 1),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF3E2723).withValues(alpha: 0.5),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 32),
          ),
          const SizedBox(height: 32),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            desc,
            style: TextStyle(
              color: AppTheme.white.withValues(alpha: 0.8),
              fontSize: 16,
              height: 1.6,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Text(
                'AVAILABLE NOW',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpdatesSection(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    return Container(
      key: _updatesKey,
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 80 : 120,
        horizontal: 24,
      ),
      color: const Color(0xFFF5F5DC), // Consistent light beige background
      child: MaxWidthContainer(
        child: Column(
          children: [
            _sectionHeader(
              'LATEST UPDATES',
              'News, Events, and Announcements',
              isDark: true,
            ),
            const SizedBox(height: 48),
            _buildMonthFilterBar(context),
            const SizedBox(height: 64),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _announcementsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading announcements: ${snapshot.error}', 
                        style: const TextStyle(color: Color(0xFF3E2723), fontSize: 16)),
                  );
                }

                final allAnnouncements = snapshot.data ?? [];

                // Filter out expired announcements
                final now = DateTime.now();
                final activeAnnouncements = allAnnouncements.where((announcement) {
                  final expirationDate = announcement['expiration_date'];
                  if (expirationDate == null) return true; // No expiration date means always active

                  try {
                    final expiry = DateTime.parse(expirationDate);
                    return expiry.isAfter(now); // Only show if not expired
                  } catch (e) {
                    return true; // If parsing fails, keep it active
                  }
                }).toList();

                // Apply month filter if selected
                final filteredAnnouncements = _selectedMonth != null
                    ? activeAnnouncements.where((announcement) {
                        final createdAt = DateTime.parse(announcement['created_at']);
                        return createdAt.month == _selectedMonth && createdAt.year == now.year;
                      }).toList()
                    : activeAnnouncements.take(12).toList(); // Show latest 12

                final updates = filteredAnnouncements;

                if (updates.isEmpty) {
                  return const Center(
                    child: Text('No announcements yet. Check back soon!', 
                        style: TextStyle(color: Color(0xFF3E2723), fontSize: 16)),
                  );
                }

                return Wrap(
                  spacing: 40,
                  runSpacing: 40,
                  alignment: WrapAlignment.center,
                  children: updates.map((update) => _announcementCard(update, isMobile)).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthFilterBar(BuildContext context) {
    final months = [
      'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
      'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: Color(0xFF3E2723).withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: _selectedMonth,
          dropdownColor: const Color(0xFFF5F5DC),
          icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primaryColor),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text(
                'LATEST / ALL',
                style: TextStyle(
                  color: Color(0xFF3E2723),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
            ...List.generate(months.length, (index) {
              return DropdownMenuItem<int?>(
                value: index + 1,
                child: Text(
                  months[index],
                  style: const TextStyle(
                    color: Color(0xFF3E2723),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              );
            }),
          ],
          onChanged: (value) {
            setState(() {
              _selectedMonth = value;
            });
          },
        ),
      ),
    );
  }

  Widget _announcementCard(Map<String, dynamic> update, bool isMobile) {
    final createdAt = DateTime.parse(update['created_at'].toString());
    final formattedDate = DateFormat('MMM dd, yyyy').format(createdAt);
    
    return Container(
      width: isMobile ? double.infinity : 550,
      decoration: BoxDecoration(
        color: const Color(0xFF161616), // Dark card for dark mode
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05), width: 1),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF3E2723).withValues(alpha: 0.3),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card Header with Date & Status
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1A1A1A), Color(0xFF0F0F0F)],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'ACTIVE',
                      style: TextStyle(color: AppTheme.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    formattedDate.toUpperCase(),
                    style: TextStyle(
                      color: AppTheme.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    update['title'].toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 28,
                      color: AppTheme.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    update['content'].toString(),
                    style: TextStyle(
                      color: AppTheme.white.withValues(alpha: 0.8), // White text for content
                      fontSize: 17,
                      height: 1.7,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 48),
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 12,
                        backgroundColor: AppTheme.primaryColor,
                        child: Icon(Icons.person_rounded, size: 14, color: Colors.black),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'MANAGEMENT TEAM',
                        style: TextStyle(
                          fontWeight: FontWeight.w900, 
                          fontSize: 11, 
                          letterSpacing: 1.5, 
                          color: AppTheme.primaryColor, // Red for better accent
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.arrow_right_alt_rounded, color: AppTheme.primaryColor.withValues(alpha: 0.5)),
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

  Widget _buildHoursAndLocationSection(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    return Container(
      key: _hoursKey,
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 80 : 120,
        horizontal: 24,
      ),
      color: const Color(0xFFF5F5DC),
      child: MaxWidthContainer(
        child: Column(
          children: [
            _sectionHeader(
              'OPERATIONS',
              'Join Us at Our Premier Location',
              isDark: true,
            ),
            const SizedBox(height: 80),
            Flex(
              direction: isMobile ? Axis.vertical : Axis.horizontal,
              children: [
                // Hours Card
                Expanded(
                  flex: isMobile ? 0 : 1,
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161616),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3), width: 1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.access_time_filled_rounded, color: AppTheme.primaryColor, size: 40),
                        const SizedBox(height: 32),
                        const Text(
                          'OPENING HOURS',
                          style: TextStyle(
                            color: AppTheme.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _hourTile('DAILY SERVICE', '10:00 AM - 8:00 PM'),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: isMobile ? 0 : 32, height: isMobile ? 32 : 0),
                // Location Card
                Expanded(
                  flex: isMobile ? 0 : 1,
                  child: Container(
                    padding: const EdgeInsets.all(60),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161616),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.location_on_rounded, color: AppTheme.primaryColor, size: 40),
                        const SizedBox(height: 32),
                        const Text(
                          'RESTAURANT LOCATION',
                          style: TextStyle(
                            color: AppTheme.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          '@ CLA TOWN CENTER MALL',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ground floor near mall entrance',
                          style: TextStyle(
                            color: AppTheme.white.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _hourTile(String day, String time) {
    return Column(
      children: [
        Text(
          time,
          style: const TextStyle(
            color: AppTheme.white,
            fontSize: 48,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day,
          style: const TextStyle(
            color: AppTheme.mediumGrey,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildContactSection(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    return Container(
      key: _contactKey,
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 80 : 120,
        horizontal: 24,
      ),
      color: const Color(0xFFF5F5DC), // Unified deep beige background
      child: MaxWidthContainer(
        child: Column(
          children: [
            _sectionHeader(
              'GET IN TOUCH',
              'We are Here to Attend to Your Every Need',
              isDark: true,
            ),
            const SizedBox(height: 80),
            Wrap(
              spacing: 32,
              runSpacing: 32,
              alignment: WrapAlignment.center,
              children: [
                _contactInfo(
                  Icons.phone_rounded, 
                  'RESERVATIONS', 
                  'TEL# 501-9179',
                  desc: 'Call us to book your table in advance.',
                ),
                _contactInfo(
                  Icons.phone_android_rounded, 
                  'MOBILE INQUIRY', 
                  '+63 975-041-9671',
                  desc: 'Direct line for quick coordination.',
                ),
                _contactInfo(
                  Icons.language_rounded, 
                  'FOLLOW US', 
                  '@yangchowpagsanjan',
                  desc: 'Stay updated with our latest offers.',
                  onTap: () => _launchURL('https://www.facebook.com/share/1CMrFYRReb'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactInfo(IconData icon, String label, String value, {required String desc, VoidCallback? onTap}) {
    return Container(
      width: 350,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 32),
          ),
          const SizedBox(height: 32),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              fontSize: 12,
              color: AppTheme.white,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: onTap,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: AppTheme.white,
                decoration: onTap != null ? TextDecoration.underline : null,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.white.withValues(alpha: 0.8),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      color: const Color(0xFF3E2723).withValues(alpha: 0.9),
      child: Center(
        child: Text(
          'Yang Chow Restaurant All Rights Reserved @ 2026',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, String subtitle, {bool isDark = false}) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF8B7355), // Beige color for text
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF8B7355), // Beige color for text
            fontSize: 42,
            fontWeight: FontWeight.w900,
            height: 1.1,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 32),
        Container(
          width: 40,
          height: 1,
          color: Color(0xFF8B7355).withValues(alpha: 0.5), // Beige underline
        ),
      ],
    );
  }
}

class MaxWidthContainer extends StatelessWidget {
  final Widget child;
  const MaxWidthContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: child,
      ),
    );
  }
}

class _HoverableNavButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;

  const _HoverableNavButton({
    required this.label,
    required Key key,
    required this.onPressed,
  });

  @override
  State<_HoverableNavButton> createState() => _HoverableNavButtonState();
}

class _HoverableNavButtonState extends State<_HoverableNavButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: _isHovered ? Colors.red : Colors.transparent, 
            width: 2
          ),
          borderRadius: BorderRadius.circular(4),
          color: _isHovered ? Colors.red.withValues(alpha: 0.1) : Colors.transparent,
        ),
        child: InkWell(
          key: widget.key,
          onTap: widget.onPressed,
          hoverColor: Colors.transparent,
          child: Text(
            widget.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}
