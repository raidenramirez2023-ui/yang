import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/responsive_utils.dart';

class CustomerManagementPage extends StatefulWidget {
  const CustomerManagementPage({super.key});

  @override
  State<CustomerManagementPage> createState() => _CustomerManagementPageState();
}

class _CustomerManagementPageState extends State<CustomerManagementPage> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _allCustomers = [];
  Map<String, Map<String, int>> _customerReservationStats = {};
  bool _isLoading = true;
  String _searchQuery = '';
  String _sortBy = 'newest'; // newest, oldest, name_asc, name_desc

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
          .select('customer_email, status');

      final stats = <String, Map<String, int>>{};
      for (final r in resResponse) {
        final email = (r['customer_email'] ?? '').toString().trim().toLowerCase();
        if (email.isEmpty) continue;
        final status = (r['status'] ?? '').toString().toLowerCase();

        stats.putIfAbsent(email, () => {'total': 0, 'no_show': 0, 'completed': 0, 'cancelled': 0, 'confirmed': 0});
        stats[email]!['total'] = (stats[email]!['total'] ?? 0) + 1;
        if (stats[email]!.containsKey(status)) {
          stats[email]![status] = (stats[email]![status] ?? 0) + 1;
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
      return q.isEmpty ||
          name.contains(q) ||
          email.contains(q) ||
          phone.contains(q);
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
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _loadCustomers,
        color: _gold,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 14 : 24,
                  vertical: isMobile ? 14 : 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(isMobile, filtered.length),
                    const SizedBox(height: 16),
                    _buildSearchAndFilter(isMobile),
                    const SizedBox(height: 16),
                    _buildQuickStats(isMobile),
                    const SizedBox(height: 20),
                  ],
                ),
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
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 14 : 24,
                ).copyWith(bottom: 60),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _buildCustomerCard(filtered[index], isMobile),
                    childCount: filtered.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // HEADER
  // -------------------------------------------------------------------------
  Widget _buildHeader(bool isMobile, int count) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 20,
        vertical: isMobile ? 14 : 18,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _slateLight),
        boxShadow: [
          BoxShadow(
            color: _darkBg.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF14332E), Color(0xFF1E4A42)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _emerald.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.people_alt_rounded, color: _gold, size: 24),
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
                        'Customer Registry',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: isMobile ? 17 : 20,
                          fontWeight: FontWeight.w800,
                          color: _darkBg,
                          letterSpacing: -0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _gold.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '$count members',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF9E6D10),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'View and manage registered customer accounts',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: _slate,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadCustomers,
            icon: const Icon(Icons.refresh_rounded, color: _slate, size: 20),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // SEARCH & FILTER
  // -------------------------------------------------------------------------
  Widget _buildSearchAndFilter(bool isMobile) {
    return Row(
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
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
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
                          setState(() => _searchQuery = '');
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
            onSelected: (v) => setState(() => _sortBy = v),
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
                              // Reliability badge
                              () {
                                final stat = _customerReservationStats[email.toLowerCase()] ?? {'total': 0, 'no_show': 0, 'completed': 0};
                                final noShows = stat['no_show'] ?? 0;
                                final completed = stat['completed'] ?? 0;

                                if (noShows >= 2) {
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
                                            '$noShows NO-SHOWS',
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
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22)),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Modal Header Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_emerald, const Color(0xFF1E4A42)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(22),
                        topRight: Radius.circular(22),
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
                                  color: Colors.white60, size: 20),
                              onPressed: () => Navigator.pop(context),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: avatarColor,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              initials,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${customer['firstname'] ?? ''} ${customer['lastname'] ?? ''}'
                              .trim(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _gold.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: _gold.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            'CUSTOMER ACCOUNT',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _goldLight,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Details Body
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _modalDetailRow(Icons.email_rounded, 'Email',
                            customer['email']?.toString() ?? 'N/A'),
                        _modalDetailRow(Icons.phone_rounded, 'Phone',
                            customer['phone']?.toString() ?? 'N/A'),
                        _modalDetailRow(Icons.calendar_today_rounded,
                            'Registered',
                            _formatDate(customer['created_at'])),
                        const SizedBox(height: 14),

                        // Customer Reliability Stats Banner
                        () {
                          final custEmail = (customer['email'] ?? '').toString().trim().toLowerCase();
                          final stat = _customerReservationStats[custEmail] ?? {'total': 0, 'no_show': 0, 'completed': 0, 'cancelled': 0};
                          final totalBookings = stat['total'] ?? 0;
                          final completed = stat['completed'] ?? 0;
                          final noShows = stat['no_show'] ?? 0;

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: noShows >= 2
                                  ? const Color(0xFFFEF2F2)
                                  : (noShows == 1 ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: noShows >= 2
                                    ? const Color(0xFFFECACA)
                                    : (noShows == 1 ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0)),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      noShows >= 2
                                          ? Icons.warning_amber_rounded
                                          : (noShows == 1 ? Icons.info_outline_rounded : Icons.history_rounded),
                                      size: 16,
                                      color: noShows >= 2
                                          ? const Color(0xFFDC2626)
                                          : (noShows == 1 ? const Color(0xFFD97706) : _slate),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'BOOKING & RELIABILITY HISTORY',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: noShows >= 2
                                            ? const Color(0xFFDC2626)
                                            : (noShows == 1 ? const Color(0xFFD97706) : _slate),
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _statMiniBox('Total Bookings', '$totalBookings', _slate),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _statMiniBox('Completed', '$completed', const Color(0xFF15803D)),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _statMiniBox('No-Shows', '$noShows', noShows > 0 ? const Color(0xFFDC2626) : _slate),
                                    ),
                                  ],
                                ),
                                if (noShows >= 2) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    '⚠️ High-Risk: Requires 100% full advance payment before confirming future events.',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFFB91C1C),
                                    ),
                                  ),
                                ],
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
                ],
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
}

