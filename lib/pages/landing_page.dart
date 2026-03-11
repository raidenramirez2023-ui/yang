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

  @override
  void initState() {
    super.initState();
    _checkAndRedirectUser();
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
        backgroundColor: AppTheme.backgroundColor,
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryRed),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.backgroundColor,
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
                _buildFooter(context),
              ],
            ),
          ),
          _buildTopNavigationBar(context),
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          color: Colors.transparent, // Transparent as requested
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              // Show menu icon on mobile
              if (isMobile)
                IconButton(
                  icon: const Icon(Icons.menu, color: AppTheme.white),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
              if (isMobile) const SizedBox(width: 8),

              // Left: Logo and Brand Name
              Image.asset(
                'assets/images/logo.jpg',
                height: 40,
                errorBuilder: (context, error, stackTrace) => 
                    const Icon(Icons.restaurant, color: AppTheme.white, size: 24),
              ),
              if (!isMobile) ...[
                const SizedBox(width: 16),
                const Text(
                  'YANG CHOW',
                  style: TextStyle(
                    color: AppTheme.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    fontSize: 20,
                  ),
                ),
              ],
              
              const Spacer(), // First Spacer
              
              // Center: Navigation Buttons (only on desktop)
              if (!isMobile) ...[
                _navButton('HOME', () => _scrollToSection(_heroKey)),
                _navButton('ABOUT', () => _scrollToSection(_aboutKey)),
                _navButton('UPDATES', () => _scrollToSection(_updatesKey)),
                _navButton('SERVICES', () => _scrollToSection(_servicesKey)),
                _navButton('HOURS', () => _scrollToSection(_hoursKey)),
                _navButton('CONTACT', () => _scrollToSection(_contactKey)),
              ],
              
              const Spacer(), // Second Spacer to push everything to edges
              
              // Right: Login Button
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryRed,
                  foregroundColor: AppTheme.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  minimumSize: Size.zero,
                  shape: const StadiumBorder(),
                  elevation: 0,
                ),
                child: Text(
                  isMobile ? 'LOGIN' : 'SIGN IN',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF121212),
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
                  AppTheme.primaryRed,
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
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset(
                      'assets/images/logo.jpg',
                      height: 50,
                      errorBuilder: (context, error, stackTrace) => 
                          const Icon(Icons.restaurant, color: AppTheme.white, size: 30),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'YANG CHOW',
                    style: TextStyle(
                      color: AppTheme.white,
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
                _drawerItem('HOME', Icons.home_rounded, () => _scrollToSection(_heroKey)),
                _drawerItem('ABOUT', Icons.info_outline_rounded, () => _scrollToSection(_aboutKey)),
                _drawerItem('UPDATES', Icons.notifications_none_rounded, () => _scrollToSection(_updatesKey)),
                _drawerItem('SERVICES', Icons.restaurant_menu_rounded, () => _scrollToSection(_servicesKey)),
                _drawerItem('HOURS', Icons.schedule_rounded, () => _scrollToSection(_hoursKey)),
                _drawerItem('CONTACT', Icons.alternate_email_rounded, () => _scrollToSection(_contactKey)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              '© 2024 YANG CHOW RESTAURANT',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
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

  Widget _drawerItem(String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
      leading: Icon(icon, color: AppTheme.primaryRed, size: 24),
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.white,
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

  Widget _navButton(String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: AppTheme.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
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
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/YC1.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.4),
                  Colors.black.withValues(alpha: 0.8),
                ],
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 80),
                  Text(
                    'YANG CHOW',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        mobile: 40, // Slightly smaller on mobile for better fit
                        tablet: 72,
                        desktop: 96,
                      ),
                      fontWeight: FontWeight.w900,
                      color: AppTheme.white,
                      letterSpacing: isMobile ? 6 : 12, // Reduced spacing on mobile
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.white.withValues(alpha: 0.8), width: 1.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      'THE BEST CUISINE FOR YOU',
                      style: TextStyle(
                        color: AppTheme.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                        letterSpacing: isMobile ? 2 : 4,
                        fontSize: isMobile ? 12 : 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: Text(
                      'Experience the true essence of traditional Chinese flavors combined with modern culinary excellence. Every dish is a masterpiece crafted for your satisfaction.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.white.withValues(alpha: 0.95),
                        fontSize: isMobile ? 16 : 18,
                        height: 1.6,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: isMobile ? double.infinity : null,
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: [
                        SizedBox(
                          width: isMobile ? double.infinity : null,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pushNamed(context, '/login'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryRed,
                              foregroundColor: AppTheme.white,
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 22),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 4,
                              shadowColor: Colors.black.withValues(alpha: 0.5),
                            ),
                            child: const Text(
                              'GET STARTED', 
                              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2)
                            ),
                          ),
                        ),
                        SizedBox(
                          width: isMobile ? double.infinity : null,
                          child: OutlinedButton(
                            onPressed: () => _scrollToSection(_aboutKey),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.white,
                              side: const BorderSide(color: AppTheme.white, width: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 22),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text(
                              'DISCOVER MORE', 
                              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2)
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
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Icon(Icons.keyboard_arrow_down, color: AppTheme.white.withValues(alpha: 0.5), size: 40),
          ),
        ],
      ),
    );
  }

  
  Widget _buildAboutUsSection(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    return Container(
      key: _aboutKey,
      padding: EdgeInsets.symmetric(vertical: isMobile ? 60 : 100, horizontal: 24),
      child: MaxWidthContainer(
        child: Column(
          children: [
            _sectionHeader('ABOUT YANG CHOW', 'Our Culinary Journey'),
            const SizedBox(height: 64),
            Flex(
              direction: isMobile ? Axis.vertical : Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: isMobile ? 0 : 1,
                  child: Container(
                    padding: isMobile ? const EdgeInsets.only(bottom: 40) : EdgeInsets.zero,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/images/YC2.png',
                        fit: BoxFit.cover,
                        height: isMobile ? 300 : 450,
                        width: double.infinity,
                      ),
                    ),
                  ),
                ),
                if (!isMobile) const SizedBox(width: 80),
                Expanded(
                  flex: isMobile ? 0 : 1,
                  child: Column(
                    crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                    children: [
                      Text(
                        'A Heritage of Freshness and Flavor',
                        textAlign: isMobile ? TextAlign.center : TextAlign.start,
                        style: TextStyle(
                          fontSize: isMobile ? 24 : 32, 
                          fontWeight: FontWeight.w800, 
                          color: AppTheme.darkGrey,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Founded in the heart of Pagsanjan, Yang Chow has been serving authentic Chinese-Filipino cuisine for over a decade. Our mission is simple: to provide high-quality, delicious meals that bring families and friends together.',
                        textAlign: isMobile ? TextAlign.center : TextAlign.start,
                        style: TextStyle(
                          fontSize: 16, 
                          color: Colors.black87, 
                          height: 1.8,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'We pride ourselves on using only the freshest ingredients sourced daily from local markets. Our signature Yang Chow Fried Rice and Dimsum are prepared by master chefs following traditional recipes.',
                        textAlign: isMobile ? TextAlign.center : TextAlign.start,
                        style: TextStyle(
                          fontSize: 16, 
                          color: Colors.black87, 
                          height: 1.8,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: isMobile ? double.infinity : null,
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryRed,
                            foregroundColor: AppTheme.white,
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                          ),
                          child: const Text(
                            'OUR FULL STORY',
                            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
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



  Widget _buildServicesSection(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final List<Map<String, dynamic>> services = [
      {'icon': Icons.restaurant_rounded, 'title': 'Dine-In', 'desc': 'Experience our cozy and authentic restaurant ambiance with premium service.'},
      {'icon': Icons.event_available_rounded, 'title': 'Catering & Events', 'desc': 'Let us cater your special occasions and gatherings with our signature dishes.'},
    ];

    return Container(
      key: _servicesKey,
      padding: EdgeInsets.symmetric(vertical: isMobile ? 60 : 100, horizontal: 24),
      color: AppTheme.backgroundColor,
      child: MaxWidthContainer(
        child: Column(
          children: [
            _sectionHeader('OUR SERVICES', 'What We Offer'),
            const SizedBox(height: 64),
            Wrap(
              spacing: 32,
              runSpacing: 32,
              alignment: WrapAlignment.center,
              children: services.map((service) {
                return Container(
                  width: isMobile ? double.infinity : 350,
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryRed.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(service['icon'] as IconData, size: 40, color: AppTheme.primaryRed),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        service['title'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 24, color: AppTheme.darkGrey),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        service['desc'] as String,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.mediumGrey, fontSize: 16, height: 1.6, fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdatesSection(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    return Container(
      key: _updatesKey,
      padding: EdgeInsets.symmetric(vertical: isMobile ? 60 : 100, horizontal: 24),
      color: AppTheme.backgroundColor,
      child: MaxWidthContainer(
        child: Column(
          children: [
            _sectionHeader('LATEST UPDATES', 'News & Announcements'),
            const SizedBox(height: 64),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: Supabase.instance.client
                  .from('announcements')
                  .select()
                  .eq('is_active', true)
                  .order('created_at', ascending: false)
                  .limit(4)
                  .then((value) => List<Map<String, dynamic>>.from(value)),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed));
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Error loading updates.', style: TextStyle(color: AppTheme.mediumGrey)),
                  );
                }

                final updates = snapshot.data ?? [];

                if (updates.isEmpty) {
                  return const Center(
                    child: Text('No announcements yet. Check back soon!', style: TextStyle(color: AppTheme.mediumGrey, fontSize: 16)),
                  );
                }

                return Wrap(
                  spacing: 32,
                  runSpacing: 32,
                  alignment: WrapAlignment.center,
                  children: updates.map((update) {
                    final createdAt = DateTime.parse(update['created_at'].toString());
                    final formattedDate = DateFormat('MMMM d, yyyy').format(createdAt);
                    
                    return Container(
                      width: isMobile ? double.infinity : 500,
                      decoration: BoxDecoration(
                        color: AppTheme.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppTheme.primaryRed, Color(0xFFC62828)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.campaign_rounded, color: AppTheme.white, size: 22),
                                  const SizedBox(width: 12),
                                  Text(
                                    formattedDate.toUpperCase(),
                                    style: const TextStyle(
                                      color: AppTheme.white, 
                                      fontWeight: FontWeight.w900, 
                                      fontSize: 12,
                                      letterSpacing: 2.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    update['title'].toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800, 
                                      fontSize: 24, 
                                      color: AppTheme.darkGrey,
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    update['content'].toString(),
                                    style: TextStyle(
                                      color: Colors.black87.withValues(alpha: 0.7), 
                                      fontSize: 16, 
                                      height: 1.7,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () {},
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppTheme.primaryRed,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'READ MORE',
                                            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
                                          ),
                                          SizedBox(width: 8),
                                          Icon(Icons.arrow_forward_rounded, size: 18),
                                        ],
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
                  }).toList(),
                );
              },
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
      padding: EdgeInsets.symmetric(vertical: isMobile ? 60 : 100, horizontal: 24),
      color: const Color(0xFF1A1A1A), // Darker grey for better contrast
      child: MaxWidthContainer(
        child: Column(
          children: [
            _sectionHeader('OPENING HOURS', 'Visit us during these times', isDark: true),
            const SizedBox(height: 64),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.3), width: 2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: _hourTile('MONDAY - SUNDAY', '10:00 AM - 8:00 PM'),
            ),
            const SizedBox(height: 64),
            const Icon(Icons.location_on_rounded, color: AppTheme.primaryRed, size: 48),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Text(
                '@ CLA TOWN CENTER MALL\nGround floor near at mall entrance',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.white, 
                  fontSize: isMobile ? 18 : 22, 
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hourTile(String day, String time) {
    return Column(
      children: [
        Text(day, style: const TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 2)),
        const SizedBox(height: 12),
        Text(time, style: const TextStyle(color: AppTheme.white, fontSize: 24, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildContactSection(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    return Container(
      key: _contactKey,
      padding: EdgeInsets.symmetric(vertical: isMobile ? 60 : 100, horizontal: 24),
      child: MaxWidthContainer(
        child: Column(
          children: [
            _sectionHeader('CONTACT US', 'Get in touch with us'),
            const SizedBox(height: 64),
            Wrap(
              spacing: 48,
              runSpacing: 48,
              alignment: WrapAlignment.center,
              children: [
                _contactInfo(Icons.phone_rounded, 'CONTACT', 'TEL# 501-9179'),
                _contactInfo(Icons.phone_android_rounded, 'MOBILE', '+63 975-041-9671'),
                _contactInfo(
                  Icons.language_rounded, 
                  'SOCIAL', 
                  '@yangchowpagsanjan',
                  onTap: () => _launchURL('https://www.facebook.com/share/1CMrFYRReb'),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _contactInfo(IconData icon, String label, String value, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.primaryRed, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                fontSize: 12,
                color: AppTheme.mediumGrey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: onTap != null ? AppTheme.primaryRed : AppTheme.darkGrey,
                decoration: onTap != null ? TextDecoration.underline : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    return Container(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 60 : 80, horizontal: 40),
      color: Colors.black,
      child: Column(
        children: [
          Text(
            'YANG CHOW RESTAURANT', 
            style: TextStyle(
              color: AppTheme.white, 
              fontWeight: FontWeight.w900, 
              fontSize: 20, 
              letterSpacing: isMobile ? 4 : 8
            )
          ),
          const SizedBox(height: 32),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: const Divider(color: Colors.white12, thickness: 1),
          ),
          const SizedBox(height: 32),
          Text(
            '© 2024 Yang Chow Restaurant Management System. All rights reserved.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.white.withValues(alpha: 0.5), 
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Designed with excellence for the heart of Pagsanjan, Laguna.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.white.withValues(alpha: 0.3), 
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, String subtitle, {bool isDark = false}) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppTheme.primaryRed,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: TextStyle(
            color: isDark ? AppTheme.white : AppTheme.darkGrey,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: 80,
          height: 4,
          color: AppTheme.primaryRed,
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
