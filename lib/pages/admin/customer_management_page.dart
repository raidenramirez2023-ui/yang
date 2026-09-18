import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:yang_chow/pages/admin/admin_reviews_page.dart';
import 'package:yang_chow/services/reservation_service.dart';

class CustomerManagementPage extends StatefulWidget {
  const CustomerManagementPage({super.key});

  @override
  State<CustomerManagementPage> createState() => _CustomerManagementPageState();
}

class _CustomerManagementPageState extends State<CustomerManagementPage> {
  final _supabase = Supabase.instance.client;
  final _reservationService = ReservationService();
  final _searchController = TextEditingController();

  int _selectedTab = 0; // 0 = Customer Registry, 1 = Customer Reviews
  List<Map<String, dynamic>> _allCustomers = [];
  Map<String, Map<String, int>> _customerReservationStats = {};
  bool _isLoading = true;
  String _searchQuery = '';
  String _sortBy = 'newest'; // newest, oldest, name_asc, name_desc
  String _selectedRestrictionFilter = 'all'; // all, active, warning, restricted, high_risk
  int _customerCurrentPage = 1;
  static const int _customersPerPage = 15;

  // Color palette
  static const _darkBg = Color(0xFF0F172A);
  static const _emerald = Color(0xFF14332E);
  static const _gold = Color(0xFFD9A441);
  static const _goldLight = Color(0xFFE6C374);
  static const _slate = Color(0xFF64748B);
  static const _slateLight = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('users')
          .select('*')
          .eq('role', 'customer')
          .order('created_at', ascending: false);

      final resResponse = await _supabase
          .from('reservations')
          .select('customer_email, status, price_quotation_sent, payment_status, quotation_expires_at');

      final stats = <String, Map<String, int>>{};
      for (final r in resResponse) {
        final email = (r['customer_email'] ?? '').toString().trim().toLowerCase();
        if (email.isEmpty) continue;
        final status = (r['status'] ?? '').toString().toLowerCase();
        final paymentStatus = (r['payment_status'] ?? 'unpaid').toString().toLowerCase();
        final priceQuotationSent = r['price_quotation_sent'] == true;

        stats.putIfAbsent(email, () => {
          'total': 0,
          'no_show': 0,
          'completed': 0,
          'cancelled': 0,
          'confirmed': 0,
          'expired': 0,
          'unpaid_quotations': 0,
          'active': 0,
        });
        stats[email]!['total'] = (stats[email]!['total'] ?? 0) + 1;
        if (stats[email]!.containsKey(status)) {
          stats[email]![status] = (stats[email]![status] ?? 0) + 1;
        }
        if (status == 'pending' || status == 'confirmed') {
          stats[email]!['active'] = (stats[email]!['active'] ?? 0) + 1;
        }
        if (priceQuotationSent && paymentStatus == 'unpaid' && status == 'pending') {
          stats[email]!['unpaid_quotations'] = (stats[email]!['unpaid_quotations'] ?? 0) + 1;
        }
      }

      if (mounted) {
        setState(() {
          _allCustomers = List<Map<String, dynamic>>.from(response);
          _customerReservationStats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading customers: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _allCustomers.where((c) {
      final name =
          '${c['firstname'] ?? ''} ${c['lastname'] ?? ''}'.toLowerCase();
      final email = (c['email'] ?? '').toString().toLowerCase();
      final phone = (c['phone'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();

      final matchesQuery = q.isEmpty ||
          name.contains(q) ||
          email.contains(q) ||
          phone.contains(q);
      if (!matchesQuery) return false;

      if (_selectedRestrictionFilter == 'all') return true;

      final restrictionStatus = (c['restriction_status'] ?? 'active').toString().toLowerCase();
      final warningCount = (c['warning_count'] as num? ?? 0).toInt();
      final restrictionEndStr = c['restriction_end']?.toString();
      DateTime? restrictionEnd;
      if (restrictionEndStr != null && restrictionEndStr.isNotEmpty) {
        restrictionEnd = DateTime.tryParse(restrictionEndStr)?.toLocal();
      }
      final now = DateTime.now();
      final isRestricted = (restrictionStatus == 'temporarily_restricted' ||
              restrictionStatus == 'blocked' ||
              restrictionStatus == 'suspended') &&
          (restrictionEnd == null || now.isBefore(restrictionEnd));

      final stat = _customerReservationStats[email] ?? {};
      final noShows = stat['no_show'] ?? 0;
      final expired = stat['expired'] ?? 0;
      final cancelled = stat['cancelled'] ?? 0;
      final isHighRisk = noShows > 0 || expired >= 2 || cancelled >= 3;

      switch (_selectedRestrictionFilter) {
        case 'active':
          return !isRestricted && warningCount == 0 && !isHighRisk;
        case 'warning':
          return warningCount > 0 && !isRestricted;
        case 'restricted':
          return isRestricted;
        case 'high_risk':
          return isHighRisk || isRestricted || warningCount > 0;
        default:
          return true;
      }
    }).toList();

    switch (_sortBy) {
      case 'oldest':
        list.sort((a, b) => (a['created_at'] ?? '').compareTo(b['created_at'] ?? ''));
        break;
      case 'name_asc':
        list.sort((a, b) =>
            '${a['firstname']} ${a['lastname']}'.compareTo('${b['firstname']} ${b['lastname']}'));
        break;
      case 'name_desc':
        list.sort((a, b) =>
            '${b['firstname']} ${b['lastname']}'.compareTo('${a['firstname']} ${a['lastname']}'));
        break;
      case 'newest':
      default:
        list.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 14 : 24,
          vertical: isMobile ? 8 : 14,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Module Header ───────────────────────────────────────────
            _buildMainPageHeader(isMobile),
            const SizedBox(height: 10),

            // ── Clickable Tab Switcher (Below the Header) ───────────────────
            _buildModuleTabSelector(isMobile),
            const SizedBox(height: 10),

            // ── Tab Content ─────────────────────────────────────────────────
            Expanded(
              child: _selectedTab == 0
                  ? _buildCustomerRegistryView(isMobile)
                  : const AdminReviewsPage(hideHeader: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainPageHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 20,
        vertical: isMobile ? 14 : 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _slateLight),
        boxShadow: [
          BoxShadow(
            color: _darkBg.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF14332E), Color(0xFF1E4A42)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: _emerald.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              _selectedTab == 0 ? Icons.people_alt_rounded : Icons.rate_review_rounded,
              color: _gold,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedTab == 0 ? 'Customer Registry' : 'Customer Reviews & Feedback',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: isMobile ? 17 : 19,
                    fontWeight: FontWeight.w800,
                    color: _darkBg,
                    letterSpacing: -0.4,
                  ),
                ),
                Text(
                  _selectedTab == 0
                      ? 'View and manage registered customer accounts'
                      : 'Monitor good & critical reviews directly synced with landing page',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: _slate,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildModuleTabSelector(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _slateLight),
        boxShadow: [
          BoxShadow(
            color: _darkBg.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _moduleTabButton(
              index: 0,
              icon: Icons.people_alt_rounded,
              label: 'Customer Registry',
              badgeText: _allCustomers.isNotEmpty ? '${_allCustomers.length}' : null,
              isMobile: isMobile,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _moduleTabButton(
              index: 1,
              icon: Icons.rate_review_rounded,
              label: 'Guest Reviews & Feedback',
              badgeText: null,
              isMobile: isMobile,
            ),
          ),
        ],
      ),
    );
  }

  Widget _moduleTabButton({
    required int index,
    required IconData icon,
    required String label,
    required String? badgeText,
    required bool isMobile,
  }) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          vertical: isMobile ? 9 : 11,
          horizontal: isMobile ? 8 : 14,
        ),
        decoration: BoxDecoration(
          color: isSelected ? _emerald : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _emerald.withValues(alpha: 0.25),
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
              icon,
              size: isMobile ? 16 : 18,
              color: isSelected ? _gold : _slate,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isMobile ? 12 : 13.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : _darkBg,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (badgeText != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _gold.withValues(alpha: 0.25)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? _gold : _slate,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerRegistryView(bool isMobile) {
    final filtered = _filtered;

    // Pagination calculations (15 items per page)
    final totalItems = filtered.length;
    final totalPages = totalItems > 0 ? (totalItems / _customersPerPage).ceil() : 1;
    if (_customerCurrentPage > totalPages) {
      _customerCurrentPage = totalPages;
    }
    if (_customerCurrentPage < 1) {
      _customerCurrentPage = 1;
    }

    final startIndex = (_customerCurrentPage - 1) * _customersPerPage;
    final endIndex = (startIndex + _customersPerPage < totalItems)
        ? startIndex + _customersPerPage
        : totalItems;

    final paginatedCustomers = totalItems > 0
        ? filtered.sublist(startIndex, endIndex)
        : <Map<String, dynamic>>[];

    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _customerCurrentPage = 1);
        await _loadCustomers();
      },
      color: _gold,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchAndFilter(isMobile),
                const SizedBox(height: 12),
                _buildQuickStats(isMobile),
                const SizedBox(height: 14),
              ],
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: _gold),
              ),
            )
          else if (filtered.isEmpty)
            SliverFillRemaining(child: _buildEmptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == paginatedCustomers.length) {
                      return _buildCustomerPagination(
                        totalItems: totalItems,
                        currentPage: _customerCurrentPage,
                        totalPages: totalPages,
                        onPageChanged: (newPage) {
                          setState(() => _customerCurrentPage = newPage);
                        },
                      );
                    }
                    return _buildCustomerCard(paginatedCustomers[index], isMobile);
                  },
                  childCount: paginatedCustomers.length + (totalItems > 0 ? 1 : 0),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCustomerPagination({
    required int totalItems,
    required int currentPage,
    required int totalPages,
    required ValueChanged<int> onPageChanged,
  }) {
    if (totalItems == 0) return const SizedBox.shrink();

    final startItem = ((currentPage - 1) * _customersPerPage) + 1;
    final endItem = (currentPage * _customersPerPage < totalItems)
        ? currentPage * _customersPerPage
        : totalItems;

    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _slateLight),
        boxShadow: [
          BoxShadow(
            color: _darkBg.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Showing $startItem–$endItem of $totalItems registered customers',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _slate,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _emerald.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Page $currentPage of $totalPages',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _emerald,
                  ),
                ),
              ),
            ],
          ),
          if (totalPages > 1) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Prev Button
                  InkWell(
                    onTap: currentPage > 1
                        ? () => onPageChanged(currentPage - 1)
                        : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: currentPage > 1 ? _emerald : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: currentPage > 1 ? _emerald : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chevron_left_rounded,
                            size: 16,
                            color: currentPage > 1 ? Colors.white : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Prev',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: currentPage > 1 ? Colors.white : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Page Number Buttons with smart ellipsis window
                  ...List.generate(totalPages, (index) {
                    final pageNum = index + 1;
                    if (totalPages > 5) {
                      if (pageNum != 1 &&
                          pageNum != totalPages &&
                          (pageNum < currentPage - 1 || pageNum > currentPage + 1)) {
                        if (pageNum == currentPage - 2 || pageNum == currentPage + 2) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              '…',
                              style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }
                    }

                    final isSelected = pageNum == currentPage;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: InkWell(
                        onTap: () {
                          if (!isSelected) {
                            onPageChanged(pageNum);
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? _gold : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? _gold : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: _gold.withValues(alpha: 0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            '$pageNum',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                              color: isSelected ? _emerald : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(width: 8),

                  // Next Button
                  InkWell(
                    onTap: currentPage < totalPages
                        ? () => onPageChanged(currentPage + 1)
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: currentPage < totalPages ? _emerald : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: currentPage < totalPages ? _emerald : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Next',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: currentPage < totalPages ? Colors.white : const Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: currentPage < totalPages ? Colors.white : const Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // SEARCH & FILTER
  // -------------------------------------------------------------------------
  Widget _buildSearchAndFilter(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _slateLight),
                  boxShadow: [
                    BoxShadow(
                      color: _darkBg.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() {
                    _searchQuery = v.trim();
                    _customerCurrentPage = 1;
                  }),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: _darkBg,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search by name, email or phone...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: const Color(0xFF94A3B8),
                    ),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: _slate, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded,
                                size: 18, color: Color(0xFF94A3B8)),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _customerCurrentPage = 1;
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _slateLight),
              ),
              child: PopupMenuButton<String>(
                onSelected: (v) => setState(() {
                  _sortBy = v;
                  _customerCurrentPage = 1;
                }),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                tooltip: 'Sort',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.sort_rounded, color: _slate, size: 18),
                      if (!isMobile) ...[
                        const SizedBox(width: 6),
                        Text(
                          'Sort',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _slate,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                itemBuilder: (context) => [
                  _popupItem('newest', 'Newest First', Icons.arrow_downward_rounded),
                  _popupItem('oldest', 'Oldest First', Icons.arrow_upward_rounded),
                  _popupItem('name_asc', 'Name A–Z', Icons.sort_by_alpha_rounded),
                  _popupItem('name_desc', 'Name Z–A', Icons.sort_by_alpha_rounded),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildRestrictionFilterChip('all', 'All Accounts', Icons.people_outline_rounded),
              const SizedBox(width: 6),
              _buildRestrictionFilterChip('active', 'Good Standing', Icons.verified_user_outlined),
              const SizedBox(width: 6),
              _buildRestrictionFilterChip('warning', 'Warnings', Icons.warning_amber_rounded),
              const SizedBox(width: 6),
              _buildRestrictionFilterChip('restricted', 'Restricted / Blocked', Icons.lock_outline_rounded),
              const SizedBox(width: 6),
              _buildRestrictionFilterChip('high_risk', 'High-Risk Patterns', Icons.gpp_maybe_outlined),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRestrictionFilterChip(String key, String label, IconData icon) {
    final isSelected = _selectedRestrictionFilter == key;
    Color activeColor = _emerald;
    if (key == 'warning') activeColor = const Color(0xFFD97706);
    if (key == 'restricted') activeColor = const Color(0xFFDC2626);
    if (key == 'high_risk') activeColor = const Color(0xFFEA580C);

    return InkWell(
      onTap: () => setState(() {
        _selectedRestrictionFilter = key;
        _customerCurrentPage = 1;
      }),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : _slateLight,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: isSelected ? Colors.white : _slate),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : _slate,
              ),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _popupItem(String value, String label, IconData icon) {
    final isSelected = _sortBy == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon,
              size: 16,
              color: isSelected ? _emerald : _slate),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? _emerald : _darkBg,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            const Icon(Icons.check_rounded, size: 16, color: _emerald),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // QUICK STATS (Responsive Carousel on Mobile)
  // -------------------------------------------------------------------------
  Widget _buildQuickStats(bool isMobile) {
    final now = DateTime.now();
    final thisMonth = _allCustomers.where((c) {
      if (c['created_at'] == null) return false;
      try {
        final d = DateTime.parse(c['created_at']).toLocal();
        return d.year == now.year && d.month == now.month;
      } catch (_) {
        return false;
      }
    }).length;

    if (isMobile) {
      return SizedBox(
        height: 66,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          children: [
            Container(
              width: 160,
              margin: const EdgeInsets.only(right: 8),
              child: _buildStatTile(
                label: 'Total Customers',
                value: _allCustomers.length.toString(),
                icon: Icons.people_alt_rounded,
                color: const Color(0xFF14332E),
                bgTint: const Color(0xFFDCFCE7),
                iconColor: const Color(0xFF15803D),
              ),
            ),
            Container(
              width: 160,
              margin: const EdgeInsets.only(right: 8),
              child: _buildStatTile(
                label: 'Joined This Month',
                value: thisMonth.toString(),
                icon: Icons.person_add_rounded,
                color: const Color(0xFF0284C7),
                bgTint: const Color(0xFFE0F2FE),
                iconColor: const Color(0xFF0284C7),
              ),
            ),
            Container(
              width: 160,
              margin: const EdgeInsets.only(right: 8),
              child: _buildStatTile(
                label: 'Search Results',
                value: _filtered.length.toString(),
                icon: Icons.filter_list_rounded,
                color: const Color(0xFFD97706),
                bgTint: const Color(0xFFFEF3C7),
                iconColor: const Color(0xFFD97706),
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: _buildStatTile(
            label: 'Total Customers',
            value: _allCustomers.length.toString(),
            icon: Icons.people_alt_rounded,
            color: const Color(0xFF14332E),
            bgTint: const Color(0xFFDCFCE7),
            iconColor: const Color(0xFF15803D),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatTile(
            label: 'Joined This Month',
            value: thisMonth.toString(),
            icon: Icons.person_add_rounded,
            color: const Color(0xFF0284C7),
            bgTint: const Color(0xFFE0F2FE),
            iconColor: const Color(0xFF0284C7),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatTile(
            label: 'Search Results',
            value: _filtered.length.toString(),
            icon: Icons.filter_list_rounded,
            color: const Color(0xFFD97706),
            bgTint: const Color(0xFFFEF3C7),
            iconColor: const Color(0xFFD97706),
          ),
        ),
      ],
    );
  }

  Widget _buildStatTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgTint,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _slateLight),
        boxShadow: [
          BoxShadow(
            color: _darkBg.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgTint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _darkBg,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    color: _slate,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // CUSTOMER CARD
  // -------------------------------------------------------------------------
  Widget _buildCustomerCard(Map<String, dynamic> customer, bool isMobile) {
    final firstName = (customer['firstname'] ?? '').toString();
    final lastName = (customer['lastname'] ?? '').toString();
    final fullName = '$firstName $lastName'.trim();
    final email = (customer['email'] ?? 'N/A').toString();
    final phone = (customer['phone'] ?? 'N/A').toString();

    String formattedDate = 'N/A';
    DateTime? regDate;
    if (customer['created_at'] != null) {
      try {
        regDate = DateTime.parse(customer['created_at']).toLocal();
        formattedDate = DateFormat('MMM dd, yyyy').format(regDate);
      } catch (_) {}
    }

    // Generate avatar color from name
    final colors = [
      const Color(0xFF14332E),
      const Color(0xFF0284C7),
      const Color(0xFF7C3AED),
      const Color(0xFFD97706),
      const Color(0xFFDC2626),
      const Color(0xFF0891B2),
    ];
    final colorIndex =
        (firstName.isNotEmpty ? firstName.codeUnitAt(0) : 65) % colors.length;
    final avatarColor = colors[colorIndex];
    final initials = (firstName.isNotEmpty ? firstName[0] : '?').toUpperCase() +
        (lastName.isNotEmpty ? lastName[0] : '').toUpperCase();

    // "New" badge — joined within last 7 days
    final isNew = regDate != null &&
        DateTime.now().difference(regDate).inDays <= 7;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _slateLight),
        boxShadow: [
          BoxShadow(
            color: _darkBg.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Left accent bar
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: avatarColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 14 : 18,
                  vertical: isMobile ? 14 : 16,
                ),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: isMobile ? 44 : 50,
                      height: isMobile ? 44 : 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            avatarColor,
                            avatarColor.withValues(alpha: 0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: avatarColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: isMobile ? 15 : 17,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  fullName.isNotEmpty ? fullName : 'N/A',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: isMobile ? 14 : 15,
                                    fontWeight: FontWeight.w800,
                                    color: _darkBg,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isNew) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF15803D)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: const Color(0xFF15803D)
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    'NEW',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF15803D),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                              // Reliability & Restriction badge
                              () {
                                final restrictionStatus = (customer['restriction_status'] ?? 'active').toString().toLowerCase();
                                final warningCount = (customer['warning_count'] as num? ?? 0).toInt();
                                final restrictionEndStr = customer['restriction_end']?.toString();
                                DateTime? restrictionEnd;
                                if (restrictionEndStr != null && restrictionEndStr.isNotEmpty) {
                                  restrictionEnd = DateTime.tryParse(restrictionEndStr)?.toLocal();
                                }
                                final now = DateTime.now();
                                final isRestricted = (restrictionStatus == 'temporarily_restricted' ||
                                        restrictionStatus == 'blocked' ||
                                        restrictionStatus == 'suspended') &&
                                    (restrictionEnd == null || now.isBefore(restrictionEnd));

                                if (isRestricted) {
                                  final label = restrictionStatus == 'blocked' || restrictionStatus == 'suspended'
                                      ? 'BLOCKED'
                                      : 'RESTRICTED';
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(color: const Color(0xFFFECACA)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.lock_rounded, size: 10, color: Color(0xFFDC2626)),
                                          const SizedBox(width: 2),
                                          Text(
                                            label,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFFDC2626),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                if (warningCount > 0 || restrictionStatus == 'warning') {
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFFBEB),
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(color: const Color(0xFFFDE68A)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.warning_amber_rounded, size: 10, color: Color(0xFFD97706)),
                                          const SizedBox(width: 2),
                                          Text(
                                            'WARN ($warningCount)',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFFD97706),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                final stat = _customerReservationStats[email.toLowerCase()] ?? {'total': 0, 'no_show': 0, 'completed': 0, 'cancelled': 0, 'expired': 0};
                                final noShows = stat['no_show'] ?? 0;
                                final completed = stat['completed'] ?? 0;
                                final expired = stat['expired'] ?? 0;
                                final cancelled = stat['cancelled'] ?? 0;

                                if (noShows >= 2 || expired >= 2 || cancelled >= 3) {
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(color: const Color(0xFFFECACA)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.warning_amber_rounded, size: 10, color: Color(0xFFDC2626)),
                                          const SizedBox(width: 2),
                                          Text(
                                            noShows >= 2 ? '$noShows NO-SHOWS' : 'HIGH-RISK',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFFDC2626),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                } else if (noShows == 1) {
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFFBEB),
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(color: const Color(0xFFFDE68A)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.info_outline_rounded, size: 10, color: Color(0xFFD97706)),
                                          const SizedBox(width: 2),
                                          Text(
                                            '1 NO-SHOW',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFFD97706),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                } else if (completed > 0) {
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0FDF4),
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(color: const Color(0xFFBBF7D0)),
                                      ),
                                      child: Text(
                                        'RELIABLE',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF16A34A),
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              }(),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(Icons.email_rounded,
                                  size: 12, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  email,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: _slate,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (!isMobile) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.phone_rounded,
                                    size: 12, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 4),
                                Text(
                                  phone,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: _slate,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Right side — date & action
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today_rounded,
                                size: 12, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 4),
                            Text(
                              formattedDate,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: _slate,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _showCustomerDetails(customer),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _emerald.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _emerald.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.person_search_rounded,
                                    size: 14, color: _emerald),
                                const SizedBox(width: 4),
                                Text(
                                  'View',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _emerald,
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
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // EMPTY STATE
  // -------------------------------------------------------------------------
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_search_rounded,
                size: 52, color: _gold),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? 'No Customers Registered Yet'
                : 'No Results Found',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _darkBg,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isEmpty
                ? 'Registered customers will appear here.'
                : 'Try adjusting your search or clearing the filter.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: _slate,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // CUSTOMER DETAILS MODAL
  // -------------------------------------------------------------------------
  void _showCustomerDetails(Map<String, dynamic> customer) {
    String? uploadedIdUrl;
    bool isLoadingId = true;

    _supabase
        .from('reservations')
        .select('uploaded_id_url')
        .eq('customer_email', customer['email'] ?? '')
        .not('uploaded_id_url', 'is', null)
        .order('created_at', ascending: false)
        .limit(1)
        .then((response) {
      if (response.isNotEmpty && response[0]['uploaded_id_url'] != null) {
        uploadedIdUrl = response[0]['uploaded_id_url'].toString();
      }
    }).catchError((e) {
      debugPrint('Error fetching uploaded ID: $e');
    });

    final firstName = (customer['firstname'] ?? '').toString();
    final lastName = (customer['lastname'] ?? '').toString();
    final colors = [
      const Color(0xFF14332E),
      const Color(0xFF0284C7),
      const Color(0xFF7C3AED),
      const Color(0xFFD97706),
      const Color(0xFFDC2626),
      const Color(0xFF0891B2),
    ];
    final colorIndex =
        (firstName.isNotEmpty ? firstName.codeUnitAt(0) : 65) % colors.length;
    final avatarColor = colors[colorIndex];
    final initials = (firstName.isNotEmpty ? firstName[0] : '?').toUpperCase() +
        (lastName.isNotEmpty ? lastName[0] : '').toUpperCase();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (isLoadingId) {
            Future.delayed(const Duration(milliseconds: 700), () {
              if (context.mounted) {
                setDialogState(() => isLoadingId = false);
              }
            });
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 440,
                maxHeight: MediaQuery.of(context).size.height * 0.86,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Modal Header Banner
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 18, 16, 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_emerald, const Color(0xFF1E4A42)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'CUSTOMER PROFILE',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: _goldLight,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded,
                                      color: Colors.white70, size: 20),
                                  onPressed: () => Navigator.pop(context),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: avatarColor,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  initials,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${customer['firstname'] ?? ''} ${customer['lastname'] ?? ''}'
                                  .trim(),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: _gold.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: _gold.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                'CUSTOMER ACCOUNT',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: _goldLight,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Details Body (Scrollable inside Flexible)
                      Flexible(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _modalDetailRow(Icons.email_rounded, 'Email',
                                  customer['email']?.toString() ?? 'N/A'),
                              _modalDetailRow(Icons.phone_rounded, 'Phone',
                                  customer['phone']?.toString() ?? 'N/A'),
                              _modalDetailRow(Icons.calendar_today_rounded,
                                  'Registered',
                                  _formatDate(customer['created_at'])),
                              const SizedBox(height: 14),

                              // Customer Reliability & Restriction Controls Banner
                              () {
                                final custEmail = (customer['email'] ?? '').toString().trim().toLowerCase();
                                final userId = customer['id']?.toString();
                                final custName = '${customer['firstname'] ?? ''} ${customer['lastname'] ?? ''}'.trim();
                                final stat = _customerReservationStats[custEmail] ?? {
                                  'total': 0,
                                  'completed': 0,
                                  'confirmed': 0,
                                  'active': 0,
                                  'cancelled': 0,
                                  'expired': 0,
                                  'no_show': 0,
                                  'unpaid_quotations': 0,
                                };
                                final totalBookings = stat['total'] ?? 0;
                                final completed = stat['completed'] ?? 0;
                                final confirmed = stat['confirmed'] ?? 0;
                                final active = stat['active'] ?? 0;
                                final cancelled = stat['cancelled'] ?? 0;
                                final expired = stat['expired'] ?? 0;
                                final noShows = stat['no_show'] ?? 0;

                                final restrictionStatus = (customer['restriction_status'] ?? 'active').toString().toLowerCase();
                                final warningCount = (customer['warning_count'] as num? ?? 0).toInt();
                                final restrictionEndStr = customer['restriction_end']?.toString();
                                final restrictionReason = customer['restriction_reason']?.toString() ?? '';
                                final restrictedBy = customer['restricted_by']?.toString();

                                DateTime? restrictionEnd;
                                if (restrictionEndStr != null && restrictionEndStr.isNotEmpty) {
                                  restrictionEnd = DateTime.tryParse(restrictionEndStr)?.toLocal();
                                }
                                final now = DateTime.now();
                                final isRestricted = (restrictionStatus == 'temporarily_restricted' ||
                                        restrictionStatus == 'blocked' ||
                                        restrictionStatus == 'suspended') &&
                                    (restrictionEnd == null || now.isBefore(restrictionEnd));

                                Color bannerColor = const Color(0xFFF0FDF4);
                                Color bannerBorder = const Color(0xFFBBF7D0);
                                Color bannerText = const Color(0xFF166534);
                                IconData bannerIcon = Icons.verified_user_rounded;
                                String bannerTitle = 'ACCOUNT IN GOOD STANDING';

                                if (isRestricted) {
                                  bannerColor = const Color(0xFFFEF2F2);
                                  bannerBorder = const Color(0xFFFECACA);
                                  bannerText = const Color(0xFF991B1B);
                                  bannerIcon = Icons.lock_rounded;
                                  bannerTitle = restrictionEnd != null
                                      ? 'TEMPORARILY RESTRICTED UNTIL ${DateFormat('MMM dd, yyyy').format(restrictionEnd)}'
                                      : 'ACCOUNT BLOCKED / INDEFINITE RESTRICTION';
                                } else if (warningCount > 0 || restrictionStatus == 'warning') {
                                  bannerColor = const Color(0xFFFFFBEB);
                                  bannerBorder = const Color(0xFFFDE68A);
                                  bannerText = const Color(0xFF92400E);
                                  bannerIcon = Icons.warning_amber_rounded;
                                  bannerTitle = 'WARNING RECORDED ($warningCount WARNINGS)';
                                }

                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: bannerColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: bannerBorder),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(bannerIcon, size: 16, color: bannerText),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              bannerTitle,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: bannerText,
                                                letterSpacing: 0.8,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (restrictionReason.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Reason: $restrictionReason${restrictedBy != null ? ' (by $restrictedBy)' : ''}',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: bannerText,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 10),
                                      // Stats row 1
                                      Row(
                                        children: [
                                          Expanded(child: _statMiniBox('Total', '$totalBookings', _slate)),
                                          const SizedBox(width: 6),
                                          Expanded(child: _statMiniBox('Completed', '$completed', const Color(0xFF15803D))),
                                          const SizedBox(width: 6),
                                          Expanded(child: _statMiniBox('Confirmed', '$confirmed', const Color(0xFF0284C7))),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      // Stats row 2
                                      Row(
                                        children: [
                                          Expanded(child: _statMiniBox('Active', '$active', const Color(0xFF0891B2))),
                                          const SizedBox(width: 6),
                                          Expanded(child: _statMiniBox('Cancelled/Exp', '${cancelled + expired}', const Color(0xFFDC2626))),
                                          const SizedBox(width: 6),
                                          Expanded(child: _statMiniBox('No-Shows', '$noShows', noShows > 0 ? const Color(0xFFDC2626) : _slate)),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      // Action buttons row
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(vertical: 8),
                                                foregroundColor: const Color(0xFFD97706),
                                                side: const BorderSide(color: Color(0xFFFDE68A)),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              icon: const Icon(Icons.warning_amber_rounded, size: 14),
                                              label: Text('Warn', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700)),
                                              onPressed: () {
                                                Navigator.pop(context);
                                                _showIssueWarningDialog(custName, userId, custEmail);
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          if (isRestricted || warningCount > 0) ...[
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                                  backgroundColor: const Color(0xFF15803D),
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                ),
                                                icon: const Icon(Icons.lock_open_rounded, size: 14),
                                                label: Text('Lift', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700)),
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                  _showUnrestrictDialog(custName, userId, custEmail);
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                          ],
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(vertical: 8),
                                                backgroundColor: const Color(0xFFDC2626),
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              icon: const Icon(Icons.lock_outline_rounded, size: 14),
                                              label: Text('Restrict', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700)),
                                              onPressed: () {
                                                Navigator.pop(context);
                                                _showRestrictAccountDialog(custName, userId, custEmail);
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Center(
                                        child: TextButton.icon(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _showCustomerRestrictionsHistoryDialog(custName, userId, custEmail);
                                          },
                                          icon: const Icon(Icons.history_rounded, size: 14),
                                          label: Text(
                                            'View Restriction History',
                                            style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }(),

                              const SizedBox(height: 14),
                              const Divider(color: Color(0xFFE2E8F0), height: 1),
                              const SizedBox(height: 14),

                              // Verification ID
                              Text(
                                'GOVERNMENT-ISSUED ID',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: _slate,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 10),

                              if (isLoadingId)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16.0),
                                    child: CircularProgressIndicator(color: _gold),
                                  ),
                                )
                              else if (uploadedIdUrl != null &&
                                  uploadedIdUrl!.isNotEmpty)
                                Column(
                                  children: [
                                    InkWell(
                                      onTap: () => _showIdLightbox(uploadedIdUrl!),
                                      borderRadius: BorderRadius.circular(14),
                                      child: Container(
                                        height: 160,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                              color: const Color(0xFFE2E8F0)),
                                          boxShadow: [
                                            BoxShadow(
                                              color: _darkBg.withValues(alpha: 0.04),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(14),
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              Image.network(
                                                uploadedIdUrl!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (c, e, s) =>
                                                    const Center(
                                                  child: Icon(
                                                      Icons.broken_image_rounded,
                                                      size: 40,
                                                      color: Color(0xFF94A3B8)),
                                                ),
                                              ),
                                              Positioned(
                                                bottom: 8,
                                                right: 8,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withValues(alpha: 0.55),
                                                    borderRadius:
                                                        BorderRadius.circular(6),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                          Icons
                                                              .zoom_in_rounded,
                                                          size: 12,
                                                          color: Colors.white),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Tap to enlarge',
                                                        style:
                                                            GoogleFonts.plusJakartaSans(
                                                          fontSize: 10,
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.w600,
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
                                    ),
                                  ],
                                )
                              else
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.no_photography_outlined,
                                          color: Color(0xFF94A3B8), size: 28),
                                      const SizedBox(width: 12),
                                      Text(
                                        'No ID uploaded yet',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: const Color(0xFF94A3B8),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _emerald,
                                    foregroundColor: Colors.white,
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    'Close',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
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
            ),
          );
        },
      ),
    );
  }

  Widget _modalDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: _slate),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _darkBg,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showIdLightbox(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              constraints:
                  const BoxConstraints(maxWidth: 700, maxHeight: 800),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black54,
                      blurRadius: 30,
                      offset: Offset(0, 10)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (c, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(color: _gold),
                      );
                    },
                    errorBuilder: (c, e, s) => const Center(
                      child: Icon(Icons.broken_image_rounded,
                          size: 48, color: Colors.white60),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 14,
              right: 14,
              child: CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.65),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statMiniBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: _slate,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('MMMM dd, yyyy • h:mm a').format(date);
    } catch (_) {
      return 'N/A';
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showIssueWarningDialog(String customerName, String? userId, String? email) {
    final reasonController = TextEditingController(text: 'Customer has unresponsive quotations or repeated unconfirmed bookings.');
    bool sendEmail = true;

    final quickReasons = [
      'Unresponsive to price quotation',
      'Repeated booking cancellations',
      'No-show for scheduled event date',
      'Submitting speculative/spam bookings',
    ];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Issue Warning to $customerName',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This warning will be recorded on the customer account. Further non-compliance will trigger temporary booking restrictions.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _slate),
                ),
                const SizedBox(height: 14),
                Text(
                  'Quick Reasons:',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: _slate),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: quickReasons.map((r) {
                    return ActionChip(
                      label: Text(r, style: GoogleFonts.plusJakartaSans(fontSize: 11)),
                      backgroundColor: const Color(0xFFF1F5F9),
                      onPressed: () => setDialogState(() => reasonController.text = r),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Reason for Warning',
                    labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    'Send email notification to customer',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  value: sendEmail,
                  activeColor: const Color(0xFFD97706),
                  onChanged: (val) => setDialogState(() => sendEmail = val ?? true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: _slate, fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  _showSnackBar('Please enter a reason for the warning.', Colors.red);
                  return;
                }
                Navigator.pop(dialogContext);

                final currentAdmin = _supabase.auth.currentUser;
                final adminName = (currentAdmin?.userMetadata?['full_name'] as String?) ??
                    (currentAdmin?.email != null ? currentAdmin!.email!.split('@').first : 'Admin');

                final success = await _reservationService.issueCustomerWarning(
                  userId: userId,
                  email: email,
                  customerName: customerName,
                  reason: reason,
                  adminName: adminName,
                  sendEmail: sendEmail,
                );

                if (success) {
                  _showSnackBar('Warning successfully issued to $customerName.', Colors.green);
                  _loadCustomers();
                } else {
                  _showSnackBar('Failed to issue warning. Check database logs.', Colors.red);
                }
              },
              child: Text('Issue Warning', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  void _showRestrictAccountDialog(String customerName, String? userId, String? email) {
    String restrictionType = 'temporarily_restricted'; // temporarily_restricted, blocked
    Duration selectedDuration = const Duration(days: 7);
    String selectedDurationLabel = '7 Days';
    final reasonController = TextEditingController(text: 'Multiple expired quotations or unverified repeated bookings.');
    bool sendEmail = true;

    final durationOptions = [
      {'label': '24 Hours', 'duration': const Duration(hours: 24)},
      {'label': '3 Days', 'duration': const Duration(days: 3)},
      {'label': '7 Days', 'duration': const Duration(days: 7)},
      {'label': '14 Days', 'duration': const Duration(days: 14)},
      {'label': '30 Days', 'duration': const Duration(days: 30)},
      {'label': 'Indefinite', 'duration': null},
    ];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.lock_outline_rounded, color: Color(0xFFDC2626), size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Restrict Account: $customerName',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Restricting this account will prevent them from creating new event bookings or reservations.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _slate),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Restriction Type:',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Text('Temporary Suspension', style: GoogleFonts.plusJakartaSans(fontSize: 12)),
                          selected: restrictionType == 'temporarily_restricted',
                          onSelected: (val) {
                            if (val) setDialogState(() => restrictionType = 'temporarily_restricted');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: Text('Permanent / Blocked', style: GoogleFonts.plusJakartaSans(fontSize: 12)),
                          selected: restrictionType == 'blocked',
                          selectedColor: const Color(0xFFFEE2E2),
                          onSelected: (val) {
                            if (val) setDialogState(() => restrictionType = 'blocked');
                          },
                        ),
                      ),
                    ],
                  ),
                  if (restrictionType == 'temporarily_restricted') ...[
                    const SizedBox(height: 14),
                    Text(
                      'Restriction Duration:',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: durationOptions.map((opt) {
                        final isSelected = selectedDurationLabel == opt['label'];
                        return ChoiceChip(
                          label: Text(opt['label'] as String, style: GoogleFonts.plusJakartaSans(fontSize: 11)),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) {
                              setDialogState(() {
                                selectedDurationLabel = opt['label'] as String;
                                selectedDuration = (opt['duration'] as Duration?) ?? const Duration(days: 365);
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    style: GoogleFonts.plusJakartaSans(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Reason for Restriction',
                      labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      'Send notification email to customer',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    value: sendEmail,
                    activeColor: const Color(0xFFDC2626),
                    onChanged: (val) => setDialogState(() => sendEmail = val ?? true),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: _slate, fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  _showSnackBar('Please enter a reason for the restriction.', Colors.red);
                  return;
                }
                Navigator.pop(dialogContext);

                final currentAdmin = _supabase.auth.currentUser;
                final adminName = (currentAdmin?.userMetadata?['full_name'] as String?) ??
                    (currentAdmin?.email != null ? currentAdmin!.email!.split('@').first : 'Admin');

                final success = await _reservationService.restrictCustomerAccount(
                  userId: userId,
                  email: email,
                  customerName: customerName,
                  restrictionType: restrictionType,
                  duration: restrictionType == 'blocked' || selectedDurationLabel == 'Indefinite'
                      ? null
                      : selectedDuration,
                  reason: reason,
                  adminName: adminName,
                  sendEmail: sendEmail,
                );

                if (success) {
                  _showSnackBar('Customer account restricted successfully.', Colors.green);
                  _loadCustomers();
                } else {
                  _showSnackBar('Failed to restrict account. Check database logs.', Colors.red);
                }
              },
              child: Text('Apply Restriction', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  void _showUnrestrictDialog(String customerName, String? userId, String? email) {
    final noteController = TextEditingController(text: 'Admin approved account clearance.');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.lock_open_rounded, color: Color(0xFF15803D), size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Lift Restrictions for $customerName',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will restore full booking privileges and reset active restriction flags for this customer.',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _slate),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: noteController,
                style: GoogleFonts.plusJakartaSans(fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Clearance Note / Remarks',
                  labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: _slate, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF15803D),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);

              final currentAdmin = _supabase.auth.currentUser;
              final adminName = (currentAdmin?.userMetadata?['full_name'] as String?) ??
                  (currentAdmin?.email != null ? currentAdmin!.email!.split('@').first : 'Admin');

              final success = await _reservationService.unrestrictCustomerAccount(
                userId: userId,
                email: email,
                customerName: customerName,
                reason: noteController.text.trim(),
                adminName: adminName,
              );

              if (success) {
                _showSnackBar('Restrictions lifted and warnings cleared for $customerName.', Colors.green);
                _loadCustomers();
              } else {
                _showSnackBar('Failed to lift restrictions. Check database logs.', Colors.red);
              }
            },
            child: Text('Confirm & Lift', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showCustomerRestrictionsHistoryDialog(String customerName, String? userId, String? email) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.history_rounded, color: Color(0xFF0F172A), size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Restriction History: $customerName',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          height: 380,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _reservationService.getCustomerRestrictionsHistory(userId: userId, email: email),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final history = snapshot.data ?? [];
              if (history.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_outlined, size: 48, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 8),
                      Text(
                        'No restriction or warning events recorded.',
                        style: GoogleFonts.plusJakartaSans(color: _slate, fontSize: 13),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                itemCount: history.length,
                separatorBuilder: (_, __) => const Divider(height: 16),
                itemBuilder: (context, i) {
                  final item = history[i];
                  final action = (item['action'] ?? '').toString();
                  final reason = item['reason'] ?? 'No reason provided';
                  final admin = item['admin_name'] ?? 'Admin';
                  final createdAtStr = item['created_at']?.toString();
                  DateTime? createdAt = createdAtStr != null ? DateTime.tryParse(createdAtStr)?.toLocal() : null;

                  Color actionColor = const Color(0xFF0F172A);
                  IconData actionIcon = Icons.info_outline;

                  if (action.contains('WARNING')) {
                    actionColor = const Color(0xFFD97706);
                    actionIcon = Icons.warning_amber_rounded;
                  } else if (action.contains('RESTRICT') || action.contains('BLOCK')) {
                    actionColor = const Color(0xFFDC2626);
                    actionIcon = Icons.lock_outline_rounded;
                  } else if (action.contains('UNRESTRICT') || action.contains('LIFT')) {
                    actionColor = const Color(0xFF15803D);
                    actionIcon = Icons.lock_open_rounded;
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: actionColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(actionIcon, size: 16, color: actionColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  action,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: actionColor,
                                  ),
                                ),
                                if (createdAt != null)
                                  Text(
                                    DateFormat('MMM dd, yyyy hh:mm a').format(createdAt),
                                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _slate),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              reason,
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF334155)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'By: $admin',
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _slate, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Close', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: _slate)),
          ),
        ],
      ),
    );
  }
}

