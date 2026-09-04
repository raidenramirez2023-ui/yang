import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:intl/intl.dart';

class AdminReviewsPage extends StatefulWidget {
  final bool hideHeader;
  const AdminReviewsPage({super.key, this.hideHeader = false});

  @override
  State<AdminReviewsPage> createState() => _AdminReviewsPageState();
}

class _AdminReviewsPageState extends State<AdminReviewsPage> {
  // ── Design tokens (consistent with Admin Reservations Page) ────────────────
  static const _darkBg     = Color(0xFF0F172A);
  static const _emerald    = Color(0xFF14332E);
  static const _gold       = Color(0xFFD9A441);
  static const _slate      = Color(0xFF64748B);
  static const _slateLight = Color(0xFFE2E8F0);

  // ── State ──────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoading = true;
  bool _headerCollapsed = false;

  int _currentPage = 0;
  static const int _rowsPerPage = 15;

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // 0 = All, 5..1 = exact star rating, -2 = 3★ & below (Critical/Bad reviews)
  int _starFilter = 0;

  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadReviews();
    _subscribeToReviews();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeToReviews() {
    _realtimeChannel = Supabase.instance.client
        .channel('admin_reviews_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'reviews',
          callback: (_) => _loadReviews(),
        )
        .subscribe();
  }

  Future<void> _loadReviews() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final rawReviews = await Supabase.instance.client
          .from('reviews')
          .select()
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> reviews =
          List<Map<String, dynamic>>.from(rawReviews);

      List<Map<String, dynamic>> enriched = reviews;
      try {
        final emails = reviews
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

          enriched = reviews.map((r) {
            final email = r['customer_email'];
            final user = userMap[email];
            final nr = Map<String, dynamic>.from(r);
            if (user != null) {
              final fn = '${user['firstname'] ?? ''} ${user['lastname'] ?? ''}'.trim();
              nr['_display_name'] = fn.isNotEmpty ? fn : 'Customer';
              nr['avatar_url'] = user['avatar_url'];
            }
            return nr;
          }).toList();
        }
      } catch (e) {
        debugPrint('[AdminReviews] Error enriching users: $e');
      }

      if (mounted) {
        setState(() {
          _reviews = enriched;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[AdminReviews] Error loading reviews: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _displayName(Map<String, dynamic> r) {
    final dn = r['_display_name']?.toString();
    if (dn != null && dn.isNotEmpty) return dn;
    final name = r['customer_name']?.toString() ?? r['name']?.toString();
    if (name != null && name.isNotEmpty) return name;
    final email = r['customer_email']?.toString() ?? '';
    return email.isNotEmpty ? email.split('@').first : 'Customer';
  }

  double _rating(Map<String, dynamic> r) =>
      (r['rating'] as num?)?.toDouble() ?? 0.0;

  String _comment(Map<String, dynamic> r) =>
      (r['comment'] ?? r['review_text'] ?? '').toString();

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    try {
      return DateFormat('MMM dd, yyyy').format(DateTime.parse(raw).toLocal());
    } catch (_) {
      return raw;
    }
  }

  // ── Filtered reviews ───────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _filtered {
    var base = _reviews.where((r) {
      if (_starFilter == 0) return true;
      if (_starFilter == -2) return _rating(r).round() <= 3;
      return _rating(r).round() == _starFilter;
    }).toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      base = base.where((r) {
        final name = _displayName(r).toLowerCase();
        final email = (r['customer_email'] ?? '').toString().toLowerCase();
        final comment = _comment(r).toLowerCase();
        final dish = (r['dish'] ?? '').toString().toLowerCase();
        return name.contains(q) ||
            email.contains(q) ||
            comment.contains(q) ||
            dish.contains(q);
      }).toList();
    }
    return base;
  }

  double get _averageRating {
    if (_reviews.isEmpty) return 0.0;
    final sum = _reviews.fold<double>(0.0, (acc, r) => acc + _rating(r));
    return sum / _reviews.length;
  }

  int _countByStars(int stars) =>
      _reviews.where((r) => _rating(r).round() == stars).length;

  int get _criticalReviewsCount =>
      _reviews.where((r) => _rating(r).round() <= 3).length;

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    return Padding(
      padding: isDesktop
          ? EdgeInsets.zero
          : const EdgeInsets.only(top: 8, left: 12, right: 12, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout()),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: widget.hideHeader ? 0 : 20,
        vertical: widget.hideHeader ? 0 : 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.hideHeader) ...[
            _buildPageHeader(),
            const SizedBox(height: 4),
          ],
          AnimatedCrossFade(
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!widget.hideHeader) const SizedBox(height: 10),
                _buildStatsBar(),
                const SizedBox(height: 10),
              ],
            ),
            secondChild: const SizedBox(height: 10, width: double.infinity),
            crossFadeState: _headerCollapsed
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 280),
            sizeCurve: Curves.easeInOut,
          ),
          _buildSearchBar(),
          const SizedBox(height: 8),
          _buildStarFilterChips(),
          const SizedBox(height: 6),
          if (_searchQuery.isNotEmpty) _buildSearchNotice(),
          Expanded(child: _buildReviewsTable()),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        if (!widget.hideHeader) ...[
          _buildPageHeader(),
          const SizedBox(height: 4),
        ],
        AnimatedCrossFade(
          firstChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.hideHeader) const SizedBox(height: 6),
              _buildStatsBar(),
              const SizedBox(height: 8),
            ],
          ),
          secondChild: const SizedBox(height: 8, width: double.infinity),
          crossFadeState: _headerCollapsed
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 280),
          sizeCurve: Curves.easeInOut,
        ),
        _buildSearchBar(),
        const SizedBox(height: 6),
        _buildStarFilterChips(),
        const SizedBox(height: 4),
        if (_searchQuery.isNotEmpty) _buildSearchNotice(),
        const SizedBox(height: 2),
        Expanded(child: _buildReviewsList()),
      ],
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildPageHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
            child: const Icon(Icons.rate_review_rounded, color: _gold, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customer Reviews & Feedback',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _darkBg,
                    letterSpacing: -0.4,
                  ),
                ),
                Text(
                  'Monitor good & critical reviews directly synced with landing page',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: _slate,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          AnimatedRotation(
            turns: _headerCollapsed ? 0.5 : 0.0,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            child: IconButton(
              onPressed: () => setState(() => _headerCollapsed = !_headerCollapsed),
              icon: const Icon(Icons.keyboard_arrow_up_rounded, color: _slate, size: 22),
              tooltip: _headerCollapsed ? 'Show Stats' : 'Hide Stats',
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats Bar ──────────────────────────────────────────────────────────────
  Widget _buildStatsBar() {
    final total = _reviews.length;
    final avg = _averageRating;
    final five = _countByStars(5);
    final four = _countByStars(4);
    final critical = _criticalReviewsCount;
    final isDesktop = ResponsiveUtils.isDesktop(context);

    if (!isDesktop) {
      return SizedBox(
        height: 54,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          children: [
            _statTile('Total Reviews', total, Icons.reviews_rounded,
                const Color(0xFFDCFCE7), const Color(0xFF15803D), 0, width: 110),
            const SizedBox(width: 8),
            _statTileText('Average Rating', avg > 0 ? '${avg.toStringAsFixed(1)} ★' : '—',
                Icons.star_rounded, const Color(0xFFFEF3C7), const Color(0xFFD97706), width: 115),
            const SizedBox(width: 8),
            _statTile('5-Star (Good)', five, Icons.star_rounded,
                const Color(0xFFDCFCE7), const Color(0xFF15803D), 5, width: 115),
            const SizedBox(width: 8),
            _statTile('4-Star (Good)', four, Icons.star_half_rounded,
                const Color(0xFFE0F2FE), const Color(0xFF0284C7), 4, width: 115),
            const SizedBox(width: 8),
            _statTile('Critical (≤ 3★)', critical, Icons.warning_amber_rounded,
                const Color(0xFFFEE2E2), const Color(0xFFDC2626), -2, width: 125),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: _statTile('Total Reviews', total, Icons.reviews_rounded,
              const Color(0xFFDCFCE7), const Color(0xFF15803D), 0),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statTileText('Average Rating', avg > 0 ? '${avg.toStringAsFixed(1)} ★' : '—',
              Icons.star_rounded, const Color(0xFFFEF3C7), const Color(0xFFD97706)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statTile('5-Star (Good)', five, Icons.star_rounded,
              const Color(0xFFDCFCE7), const Color(0xFF15803D), 5),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statTile('4-Star (Good)', four, Icons.star_half_rounded,
              const Color(0xFFE0F2FE), const Color(0xFF0284C7), 4),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statTile('Critical / Bad (≤ 3★)', critical, Icons.warning_amber_rounded,
              const Color(0xFFFEE2E2), const Color(0xFFDC2626), -2),
        ),
      ],
    );
  }

  Widget _statTile(String label, int value, IconData icon, Color bg, Color iconColor, int filterKey, {double? width}) {
    final bool isSelected = _starFilter == filterKey;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() {
          _starFilter = filterKey;
          _currentPage = 0;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? iconColor : _slateLight,
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: iconColor.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: _darkBg.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: width != null ? MainAxisSize.min : MainAxisSize.max,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isSelected ? iconColor : bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: isSelected ? Colors.white : iconColor, size: 14),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value.toString(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? iconColor : _darkBg,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9.5,
                        color: isSelected ? iconColor : _slate,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
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
      ),
    );
  }

  Widget _statTileText(String label, String value, IconData icon, Color bg, Color iconColor, {double? width}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _slateLight),
        boxShadow: [
          BoxShadow(
            color: _darkBg.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: width != null ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 14),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _darkBg,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9.5,
                    color: _slate,
                    fontWeight: FontWeight.w600,
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

  // ── Search Bar ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return SizedBox(
      height: 38,
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() {
          _searchQuery = v.trim();
          _currentPage = 0;
        }),
        style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: 'Search by customer name, email, dish, or review feedback…',
          hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () => setState(() {
                    _searchQuery = '';
                    _searchController.clear();
                    _currentPage = 0;
                  }),
                  child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF14332E), width: 1.5),
          ),
        ),
      ),
    );
  }

  // ── Star Filter Chips ──────────────────────────────────────────────────────
  Widget _buildStarFilterChips() {
    final options = [
      (0, 'All Reviews'),
      (5, '5 ★ (Excellent)'),
      (4, '4 ★ (Good)'),
      (3, '3 ★ (Average)'),
      (2, '2 ★ (Poor)'),
      (1, '1 ★ (Very Poor)'),
      (-2, '🚨 Critical (≤ 3★)'),
    ];
    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final (key, label) = options[i];
          final selected = _starFilter == key;
          Color activeBg = _emerald;
          if (key == -2 || key == 1 || key == 2) {
            activeBg = const Color(0xFFDC2626);
          } else if (key == 5 || key == 4) {
            activeBg = const Color(0xFF15803D);
          }

          return GestureDetector(
            onTap: () => setState(() {
              _starFilter = key;
              _currentPage = 0;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: selected ? activeBg : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? activeBg : _slateLight,
                  width: selected ? 1.5 : 1.0,
                ),
              ),
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : _slate,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchNotice() {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 16, color: Color(0xFF15803D)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Showing search results for: "$_searchQuery"',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF166534),
              ),
            ),
          ),
          InkWell(
            onTap: () => setState(() {
              _searchQuery = '';
              _searchController.clear();
              _currentPage = 0;
            }),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.close_rounded, size: 14, color: Color(0xFF15803D)),
                const SizedBox(width: 4),
                Text(
                  'Clear',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF15803D),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Desktop Table ──────────────────────────────────────────────────────────
  Widget _buildReviewsTable() {
    if (_isLoading) return _buildLoadingState();
    final filtered = _filtered;
    if (filtered.isEmpty) return _buildEmptyState();

    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage < filtered.length)
        ? startIndex + _rowsPerPage
        : filtered.length;
    final paginated = filtered.sublist(startIndex, endIndex);

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(bottom: BorderSide(color: _slateLight, width: 1.5)),
            ),
            child: Row(
              children: [
                SizedBox(width: 36, child: _th('#')),
                const SizedBox(width: 8),
                Expanded(flex: 3, child: _th('CUSTOMER')),
                Expanded(flex: 2, child: _th('RATING / SENTIMENT')),
                Expanded(flex: 4, child: _th('COMMENT & FEEDBACK')),
                Expanded(flex: 2, child: _th('DATE')),
                Expanded(flex: 2, child: _th('RESERVATION ID')),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: paginated.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                thickness: 1,
                color: _slateLight.withValues(alpha: 0.8),
              ),
              itemBuilder: (context, index) =>
                  _buildTableRow(paginated[index], startIndex + index + 1),
            ),
          ),
          if (filtered.length > _rowsPerPage)
            _buildPaginationControls(filtered.length),
        ],
      ),
    );
  }

  Widget _th(String label) => Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF475569),
          letterSpacing: 0.8,
        ),
      );

  Widget _buildTableRow(Map<String, dynamic> r, int rowNum) {
    final name = _displayName(r);
    final email = (r['customer_email'] ?? '').toString();
    final rating = _rating(r);
    final comment = _comment(r);
    final date = _formatDate(r['created_at']?.toString());
    final resId = (r['reservation_id'] ?? r['id'] ?? '—').toString();
    final shortId = resId.length > 14 ? '${resId.substring(0, 14)}…' : resId;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '$rowNum',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _slate,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Customer Details
          Expanded(
            flex: 3,
            child: Row(
              children: [
                _miniAvatar(name),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _darkBg,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email.isNotEmpty ? email : 'Verified Customer',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
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
          ),
          // Rating & Sentiment
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildRatingStars(rating),
                const SizedBox(height: 4),
                _buildSentimentChip(rating),
              ],
            ),
          ),
          // Comment
          Expanded(
            flex: 4,
            child: Text(
              comment.isNotEmpty ? comment : '—',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: comment.isNotEmpty ? _darkBg : _slate,
                fontWeight: FontWeight.w500,
                fontStyle: comment.isEmpty ? FontStyle.italic : FontStyle.normal,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Date
          Expanded(
            flex: 2,
            child: Text(
              date,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: _slate,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Reservation ID
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                shortId,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  color: _slate,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingStars(double rating) {
    final full = rating.floor();
    final hasHalf = (rating - full) >= 0.5;
    final empty = 5 - full - (hasHalf ? 1 : 0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < full; i++)
          const Icon(Icons.star_rounded, color: _gold, size: 15),
        if (hasHalf)
          const Icon(Icons.star_half_rounded, color: _gold, size: 15),
        for (int i = 0; i < empty; i++)
          Icon(Icons.star_border_rounded, color: _gold.withValues(alpha: 0.4), size: 15),
        const SizedBox(width: 5),
        Text(
          rating.toStringAsFixed(1),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: _darkBg,
          ),
        ),
      ],
    );
  }

  Widget _buildSentimentChip(double rating) {
    if (rating >= 4.5) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'Excellent',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF15803D),
          ),
        ),
      );
    } else if (rating >= 4.0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F2FE),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'Good',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0284C7),
          ),
        ),
      );
    } else if (rating >= 3.0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'Average',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFD97706),
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'Needs Attention',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFDC2626),
          ),
        ),
      );
    }
  }

  Widget _miniAvatar(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final colors = [
      const Color(0xFF14332E),
      const Color(0xFF0284C7),
      const Color(0xFF7C3AED),
      const Color(0xFFD97706),
    ];
    final c = colors[name.codeUnits.fold(0, (a, b) => a + b) % colors.length];
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: c.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ── Pagination ─────────────────────────────────────────────────────────────
  Widget _buildPaginationControls(int totalItems) {
    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage < totalItems)
        ? startIndex + _rowsPerPage
        : totalItems;
    final totalPages = (totalItems / _rowsPerPage).ceil();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border(top: BorderSide(color: _slateLight)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${startIndex + 1}–$endIndex of $totalItems reviews',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: _slate,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _emerald.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Page ${_currentPage + 1} of $totalPages',
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
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Prev Button
                InkWell(
                  onTap: _currentPage > 0
                      ? () => setState(() => _currentPage--)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _currentPage > 0 ? _emerald : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _currentPage > 0 ? _emerald : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chevron_left_rounded,
                          size: 16,
                          color: _currentPage > 0 ? Colors.white : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Prev',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: _currentPage > 0 ? Colors.white : const Color(0xFF94A3B8),
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
                  final currentPageNum = _currentPage + 1;
                  if (totalPages > 5) {
                    if (pageNum != 1 &&
                        pageNum != totalPages &&
                        (pageNum < currentPageNum - 1 || pageNum > currentPageNum + 1)) {
                      if (pageNum == currentPageNum - 2 || pageNum == currentPageNum + 2) {
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

                  final isSelected = pageNum == currentPageNum;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: InkWell(
                      onTap: () {
                        if (!isSelected) {
                          setState(() => _currentPage = pageNum - 1);
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
                  onTap: _currentPage < totalPages - 1
                      ? () => setState(() => _currentPage++)
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _currentPage < totalPages - 1 ? _emerald : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _currentPage < totalPages - 1 ? _emerald : const Color(0xFFE2E8F0),
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
                            color: _currentPage < totalPages - 1 ? Colors.white : const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: _currentPage < totalPages - 1 ? Colors.white : const Color(0xFF94A3B8),
                        ),
                      ],
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

  // ── Mobile Card List ───────────────────────────────────────────────────────
  Widget _buildReviewsList() {
    if (_isLoading) return _buildLoadingState();
    final filtered = _filtered;
    if (filtered.isEmpty) return _buildEmptyState();

    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage < filtered.length)
        ? startIndex + _rowsPerPage
        : filtered.length;
    final paginated = filtered.sublist(startIndex, endIndex);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: paginated.length + (filtered.length > _rowsPerPage ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == paginated.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            child: _buildPaginationControls(filtered.length),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildMobileCard(paginated[i], startIndex + i),
        );
      },
    );
  }

  Widget _buildMobileCard(Map<String, dynamic> r, int index) {
    final name = _displayName(r);
    final email = (r['customer_email'] ?? '').toString();
    final rating = _rating(r);
    final comment = _comment(r);
    final date = _formatDate(r['created_at']?.toString());

    Color barColor;
    if (rating >= 5) {
      barColor = const Color(0xFF15803D);
    } else if (rating >= 4) {
      barColor = const Color(0xFF0284C7);
    } else if (rating >= 3) {
      barColor = const Color(0xFFD97706);
    } else {
      barColor = const Color(0xFFDC2626);
    }

    return TweenAnimationBuilder<double>(
      key: ValueKey(r['id']),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 320 + (index * 60).clamp(0, 400)),
      curve: Curves.easeOutCubic,
      builder: (ctx, v, child) => Transform.translate(
        offset: Offset(0, 20 * (1 - v)),
        child: Opacity(opacity: v, child: child),
      ),
      child: Container(
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
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _miniAvatar(name),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: _darkBg,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  email.isNotEmpty ? email : 'Verified Customer',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: _slate,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _buildRatingStars(rating),
                              const SizedBox(height: 2),
                              _buildSentimentChip(rating),
                            ],
                          ),
                        ],
                      ),
                      if (comment.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          comment,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: _darkBg,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                              size: 12, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Text(
                            date,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: _slate,
                              fontWeight: FontWeight.w600,
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
      ),
    );
  }

  Widget _buildLoadingState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _gold.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(_gold),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Loading Reviews…',
              style: GoogleFonts.plusJakartaSans(
                color: _slate,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );

  Widget _buildEmptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                shape: BoxShape.circle,
                border: Border.all(color: _slateLight),
              ),
              child: Icon(Icons.rate_review_outlined,
                  size: 42, color: _slate.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 16),
            Text(
              'No reviews found',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _darkBg,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty || _starFilter != 0
                  ? 'Try adjusting your search or filter'
                  : 'Customer reviews will appear here once submitted',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: _slate,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
}
