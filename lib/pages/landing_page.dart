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
        if (userResponse == null) {
          // It's a brand new Google user, insert them and go to customer dashboard
          await Supabase.instance.client.from('users').insert({
            'email': email,
            'role': 'customer',
          });
          Navigator.pushReplacementNamed(context, '/customer-dashboard');
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
    } else if (userRole == 'admin') {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else if (userRole == 'inventory staff') {
      Navigator.pushReplacementNamed(context, '/pagsanjaninv-dashboard');
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
      backgroundColor: AppTheme.backgroundColor,
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              Image.asset(
                'assets/images/logo.jpg',
                height: 32,
                errorBuilder: (context, error, stackTrace) => 
                    const Icon(Icons.restaurant, color: AppTheme.white, size: 24),
              ),
              const SizedBox(width: 12),
              if (!isMobile)
                const Text(
                  'YANG CHOW',
                  style: TextStyle(
                    color: AppTheme.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontSize: 16,
                  ),
                ),
              const Spacer(),
              if (!isMobile) ...[
                _navButton('HOME', () => _scrollToSection(_heroKey)),
                _navButton('ABOUT', () => _scrollToSection(_aboutKey)),
                _navButton('UPDATES', () => _scrollToSection(_updatesKey)),
                _navButton('SERVICES', () => _scrollToSection(_servicesKey)),
                _navButton('HOURS', () => _scrollToSection(_hoursKey)),
                _navButton('CONTACT', () => _scrollToSection(_contactKey)),
                const SizedBox(width: 12),
              ],
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryRed,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: Size.zero,
                ),
                child: Text(
                  isMobile ? 'LOGIN' : 'SIGN IN',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navButton(String label, VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    return Container(
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
                  Colors.black.withOpacity(0.4),
                  Colors.black.withOpacity(0.8),
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
                  const SizedBox(height: 60),
                  Text(
                    'YANG CHOW',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        mobile: 48,
                        tablet: 72,
                        desktop: 96,
                      ),
                      fontWeight: FontWeight.w900,
                      color: AppTheme.white,
                      letterSpacing: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.white, width: 2),
                    ),
                    child: const Text(
                      'THE BEST CUISINE FOR YOU',
                      style: TextStyle(
                        color: AppTheme.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                        fontSize: 14,
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
                        color: AppTheme.white.withOpacity(0.9),
                        fontSize: 18,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.pushNamed(context, '/login'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryRed,
                          foregroundColor: AppTheme.white,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        child: const Text('GET STARTED', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      OutlinedButton(
                        onPressed: () => _scrollToSection(_aboutKey),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.white,
                          side: const BorderSide(color: AppTheme.white, width: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        child: const Text('DISCOVER MORE', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Icon(Icons.keyboard_arrow_down, color: AppTheme.white.withOpacity(0.5), size: 40),
          ),
        ],
      ),
    );
  }

  
  Widget _buildAboutUsSection(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    return Container(
      key: _aboutKey,
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 20),
      child: MaxWidthContainer(
        child: Column(
          children: [
            _sectionHeader('ABOUT YANG CHOW', 'Our Culinary Journey'),
            const SizedBox(height: 60),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (!isMobile)
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/YC2.png',
                        fit: BoxFit.cover,
                        height: 400,
                      ),
                    ),
                  ),
                if (!isMobile) const SizedBox(width: 60),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'A Heritage of Freshness and Flavor',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Founded in the heart of Pagsanjan, Yang Chow has been serving authentic Chinese-Filipino cuisine for over a decade. Our mission is simple: to provide high-quality, delicious meals that bring families and friends together.',
                        style: TextStyle(fontSize: 16, color: AppTheme.mediumGrey, height: 1.8),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'We pride ourselves on using only the freshest ingredients sourced daily from local markets. Our signature Yang Chow Fried Rice and Dimsum are prepared by master chefs following traditional recipes passed down through generations.',
                        style: TextStyle(fontSize: 16, color: AppTheme.mediumGrey, height: 1.8),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryRed,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        ),
                        child: const Text('OUR FULL STORY'),
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
    final List<Map<String, dynamic>> services = [
      {'icon': Icons.restaurant, 'title': 'Dine-In', 'desc': 'Experience our cozy and authentic restaurant ambiance.'},
      {'icon': Icons.event_seat, 'title': 'Catering & Events', 'desc': 'Let us cater your special occasions and gatherings.'},
    ];

    return Container(
      key: _servicesKey,
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 20),
      color: AppTheme.backgroundColor,
      child: MaxWidthContainer(
        child: Column(
          children: [
            _sectionHeader('OUR SERVICES', 'What We Offer'),
            const SizedBox(height: 60),
            Wrap(
              spacing: 30,
              runSpacing: 30,
              alignment: WrapAlignment.center,
              children: services.map((service) {
                return Container(
                  width: 300,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryRed.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Icon(service['icon'] as IconData, size: 48, color: AppTheme.primaryRed),
                      const SizedBox(height: 24),
                      Text(
                        service['title'] as String,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppTheme.darkGrey),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        service['desc'] as String,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.mediumGrey, fontSize: 14, height: 1.5),
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
    return Container(
      key: _updatesKey,
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 20),
      color: AppTheme.backgroundColor,
      child: MaxWidthContainer(
        child: Column(
          children: [
            _sectionHeader('LATEST UPDATES', 'News & Announcements'),
            const SizedBox(height: 60),
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
                  return Center(
                    child: Text('Error loading updates.', style: const TextStyle(color: AppTheme.mediumGrey)),
                  );
                }

                final updates = snapshot.data ?? [];

                if (updates.isEmpty) {
                  return const Center(
                    child: Text('No announcements yet. Check back soon!', style: TextStyle(color: AppTheme.mediumGrey)),
                  );
                }

                return Wrap(
                  spacing: 30,
                  runSpacing: 30,
                  alignment: WrapAlignment.center,
                  children: updates.map((update) {
                    final createdAt = DateTime.parse(update['created_at'].toString());
                    final formattedDate = DateFormat('MMMM d, yyyy').format(createdAt);
                    
                    return Container(
                      width: 450,
                      decoration: BoxDecoration(
                        color: AppTheme.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppTheme.primaryRed, Color(0xFFE53935)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.campaign, color: AppTheme.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    formattedDate.toUpperCase(),
                                    style: const TextStyle(
                                      color: AppTheme.white, 
                                      fontWeight: FontWeight.bold, 
                                      fontSize: 12,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    update['title'].toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold, 
                                      fontSize: 22, 
                                      color: AppTheme.darkGrey,
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    update['content'].toString(),
                                    style: const TextStyle(
                                      color: AppTheme.mediumGrey, 
                                      fontSize: 16, 
                                      height: 1.6,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () {},
                                      icon: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.primaryRed),
                                      label: const Text(
                                        'READ MORE',
                                        style: TextStyle(
                                          color: AppTheme.primaryRed,
                                          fontWeight: FontWeight.bold,
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
    return Container(
      key: _hoursKey,
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 20),
      color: AppTheme.darkGrey,
      child: MaxWidthContainer(
        child: Column(
          children: [
            _sectionHeader('OPENING HOURS', 'Visit us during these times', isDark: true),
            const SizedBox(height: 60),
            Center(
              child: _hourTile('MONDAY - SUNDAY', '10:00 AM - 8:00 PM'),
            ),
            const SizedBox(height: 60),
            const Icon(Icons.location_on, color: AppTheme.primaryRed, size: 40),
            const SizedBox(height: 16),
            const Text(
              '@ CLA TOWN CENTER MALL, Ground floor near at mall entrance',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.white, fontSize: 18, fontWeight: FontWeight.w500),
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
    return Container(
      key: _contactKey,
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 20),
      child: MaxWidthContainer(
        child: Column(
          children: [
            _sectionHeader('CONTACT US', 'Get in touch with us'),
            const SizedBox(height: 60),
            Wrap(
              spacing: 40,
              runSpacing: 40,
              alignment: WrapAlignment.center,
              children: [
                _contactInfo(Icons.phone, 'CONTACT', 'TEL# 501-9179'),
                _contactInfo(Icons.phone_android, 'MOBILE', '+63 975-041-9671'),
                _contactInfo(
                  Icons.language, 
                  'SOCIAL', 
                  '@yangchowpagsanjan',
                  onTap: () => _launchURL('https://www.facebook.com/share/1CMrFYRReb'),
                ),
              ],
            ),
            const SizedBox(height: 60),
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
                color: AppTheme.primaryRed.withOpacity(0.1),
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
    return Container(
      padding: const EdgeInsets.all(40),
      color: Colors.black,
      child: Column(
        children: [
          const Text('YANG CHOW RESTAURANT', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 4)),
          const SizedBox(height: 24),
          const Divider(color: Colors.white24),
          const SizedBox(height: 24),
          Text(
            '© 2024 Yang Chow Restaurant Management System. All rights reserved.',
            style: TextStyle(color: AppTheme.white.withOpacity(0.5), fontSize: 12),
          ),
          const SizedBox(height: 12),
          Text(
            'Designed with love in Pagsanjan, Laguna.',
            style: TextStyle(color: AppTheme.white.withOpacity(0.3), fontSize: 10),
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
