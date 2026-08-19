import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/services/staff_service.dart';
import 'package:yang_chow/services/audit_log_service.dart';
import 'package:yang_chow/utils/responsive_utils.dart';

class SpoilageWastagePage extends StatefulWidget {
  final bool embedded;
  const SpoilageWastagePage({super.key, this.embedded = false});

  @override
  State<SpoilageWastagePage> createState() => _SpoilageWastagePageState();
}

class _SpoilageWastagePageState extends State<SpoilageWastagePage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  static const String _storageKey = 'yang_chow_spoilage_wastage_logs_v4';

  List<Map<String, dynamic>> _inventoryItems = [];
  List<Map<String, dynamic>> _staffList = [];
  List<Map<String, dynamic>> _wastageLogs = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedReasonFilter = 'All';
  String _selectedTimeFilter = 'This Month'; // 'This Week', 'This Month', 'All Time'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch real active inventory items from Supabase
      final invRes = await _supabase
          .from('inventory')
          .select()
          .order('name');
      _inventoryItems = List<Map<String, dynamic>>.from(invRes);

      // 2. Fetch real active staff from StaffService / User Management
      _staffList = await StaffService.loadStaffList();

      // 3. Fetch real wastage transactions from Supabase stock_transactions table
      List<Map<String, dynamic>> dbWastageLogs = [];
      try {
        final stockTxRes = await _supabase
            .from('stock_transactions')
            .select()
            .eq('transaction_type', 'outgoing')
            .ilike('purpose', 'Wastage%')
            .order('created_at', ascending: false);

        for (var tx in stockTxRes) {
          final purpose = tx['purpose']?.toString() ?? 'Wastage';
          String reason = 'Spoilage / Rotten';
          if (purpose.contains(':')) {
            reason = purpose.split(':').last.trim();
          }

          dbWastageLogs.add({
            'id': tx['id']?.toString() ?? 'TX-${DateTime.now().millisecondsSinceEpoch}',
            'item_name': tx['item_name'] ?? 'Unknown Item',
            'category': _getCategoryForItem(tx['item_name']?.toString()),
            'quantity': (tx['quantity'] as num?)?.toDouble() ?? 1.0,
            'unit': tx['unit'] ?? 'units',
            'cost_per_unit': (tx['unit_cost'] as num?)?.toDouble() ?? 0.0,
            'total_cost': (tx['total_cost'] as num?)?.toDouble() ?? 0.0,
            'reason': reason,
            'logged_by': tx['requested_by'] ?? tx['processed_by'] ?? 'Staff',
            'notes': tx['notes'] ?? '',
            'created_at': tx['created_at'] ?? DateTime.now().toIso8601String(),
          });
        }
      } catch (e) {
        debugPrint('Note fetching stock_transactions for wastage: $e');
      }

      // 4. Merge with local persistent storage using fingerprint deduplication
      final prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_storageKey);
      List<Map<String, dynamic>> localLogs = [];
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw);
        localLogs = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }

      // Deduplicate using unique fingerprint: (item_name + quantity + created_at)
      final Map<String, Map<String, dynamic>> uniqueMap = {};

      String getFingerprint(Map<String, dynamic> item) {
        final name = (item['item_name'] ?? '').toString().toLowerCase().trim();
        final qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
        final rawDate = item['created_at']?.toString() ?? '';
        final dateKey = rawDate.length >= 16 ? rawDate.substring(0, 16) : rawDate;
        return '${name}_${qty}_$dateKey';
      }

      // DB entries take highest priority
      for (var l in dbWastageLogs) {
        final fp = getFingerprint(l);
        uniqueMap[fp] = l;
      }

      // Local entries only if not already matched
      for (var l in localLogs) {
        final fp = getFingerprint(l);
        if (!uniqueMap.containsKey(fp)) {
          uniqueMap[fp] = l;
        }
      }

      _wastageLogs = uniqueMap.values.toList()
        ..sort((a, b) {
          final dtA = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dtB = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          return dtB.compareTo(dtA);
        });

      await prefs.setString(_storageKey, jsonEncode(_wastageLogs));
    } catch (e) {
      debugPrint('Error loading spoilage logs: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getCategoryForItem(String? itemName) {
    if (itemName == null) return 'General';
    final match = _inventoryItems.firstWhere(
      (item) => item['name']?.toString().toLowerCase() == itemName.toLowerCase(),
      orElse: () => {},
    );
    return match['category']?.toString() ?? 'General';
  }

  Future<void> _saveWastageLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_wastageLogs));
    } catch (e) {
      debugPrint('Error saving wastage logs: $e');
    }
  }

  List<Map<String, dynamic>> get _filteredLogs {
    final now = DateTime.now();
    return _wastageLogs.where((log) {
      final name = (log['item_name'] ?? '').toString().toLowerCase();
      final reason = (log['reason'] ?? '').toString();
      final loggedBy = (log['logged_by'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();

      final matchesSearch = q.isEmpty || name.contains(q) || loggedBy.contains(q) || reason.toLowerCase().contains(q);
      final matchesReason = _selectedReasonFilter == 'All' || reason.toLowerCase().contains(_selectedReasonFilter.toLowerCase());

      bool matchesTime = true;
      if (_selectedTimeFilter != 'All Time') {
        final createdAtStr = log['created_at']?.toString();
        if (createdAtStr != null) {
          final dt = DateTime.tryParse(createdAtStr);
          if (dt != null) {
            if (_selectedTimeFilter == 'This Week') {
              matchesTime = now.difference(dt).inDays <= 7;
            } else if (_selectedTimeFilter == 'This Month') {
              matchesTime = dt.year == now.year && dt.month == now.month;
            }
          }
        }
      }

      return matchesSearch && matchesReason && matchesTime;
    }).toList();
  }

  double get _totalQuantityWasted {
    return _filteredLogs.fold(0.0, (sum, item) {
      final qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
      return sum + qty;
    });
  }

  String get _mostCommonReason {
    if (_filteredLogs.isEmpty) return 'None';
    final Map<String, int> counts = {};
    for (var l in _filteredLogs) {
      final r = (l['reason'] ?? 'Spoilage').toString();
      counts[r] = (counts[r] ?? 0) + 1;
    }
    var top = counts.entries.first;
    for (var e in counts.entries) {
      if (e.value > top.value) top = e;
    }
    return top.key;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final filtered = _filteredLogs;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF14332E)))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFF14332E),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(isMobile ? 14 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header Banner ──────────────────────────────────
                    _buildHeaderBanner(isMobile),
                    const SizedBox(height: 16),

                    // ── Analytics Summary Cards ─────────────────────────
                    _buildStatsRow(isMobile),
                    const SizedBox(height: 20),

                    // ── Search & Filter Controls ───────────────────────
                    _buildSearchAndFilters(isMobile),
                    const SizedBox(height: 16),

                    // ── Logs Section Header ────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Spoilage & Wastage History',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: isMobile ? 17 : 19,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              '${filtered.length} recorded waste log${filtered.length == 1 ? '' : 's'}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: _showLogWastageModal,
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 16, color: Colors.white),
                          label: Text(
                            isMobile ? 'Log Waste' : 'Log Spoilage / Waste',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 12 : 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── List of Wastage Cards ──────────────────────────
                    if (filtered.isEmpty)
                      _buildEmptyState()
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) => _buildWastageCard(filtered[i], isMobile),
                      ),

                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Header Banner ──────────────────────────────────────────────────────────
  Widget _buildHeaderBanner(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
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
                colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 26),
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
                        'Kitchen Spoilage & Wastage Tracker',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: isMobile ? 16 : 19,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        'AUDIT LOG',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Record spoiled, expired, or prep-damaged ingredients to automatically sync stock and track kitchen wastage.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
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

  // ── Stats Summary Row ──────────────────────────────────────────────────────
  Widget _buildStatsRow(bool isMobile) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            label: 'Total Quantity Lost',
            value: '${_totalQuantityWasted.toStringAsFixed(qtyDecimals(_totalQuantityWasted))} units',
            icon: Icons.inventory_2_outlined,
            bgTint: const Color(0xFFFEF2F2),
            iconColor: const Color(0xFFDC2626),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            label: 'Wastage Incidents',
            value: '${_filteredLogs.length} events',
            icon: Icons.event_busy_rounded,
            bgTint: const Color(0xFFFFFBEB),
            iconColor: const Color(0xFFD97706),
          ),
        ),
        if (!isMobile) ...[
          const SizedBox(width: 10),
          Expanded(
            child: _statCard(
              label: 'Top Wastage Reason',
              value: _mostCommonReason,
              icon: Icons.pie_chart_outline_rounded,
              bgTint: const Color(0xFFF1F5F9),
              iconColor: const Color(0xFF475569),
            ),
          ),
        ],
      ],
    );
  }

  int qtyDecimals(double val) => val.truncateToDouble() == val ? 0 : 1;

  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
    required Color bgTint,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgTint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
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

  // ── Search & Filter Row ────────────────────────────────────────────────────
  Widget _buildSearchAndFilters(bool isMobile) {
    final reasons = ['All', 'Spoilage', 'Expired', 'Prep Spill', 'Storage Failure'];

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
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search by item name, reason, or staff...',
                    hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Time filter dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedTimeFilter,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                  items: ['This Week', 'This Month', 'All Time'].map((t) => DropdownMenuItem(value: t, child: Text(t, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600)))).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedTimeFilter = v);
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Reason filter pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: reasons.map((r) {
              final isSel = _selectedReasonFilter == r;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => setState(() => _selectedReasonFilter = r),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSel ? const Color(0xFFDC2626) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSel ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      r,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
                        color: isSel ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Wastage Card ───────────────────────────────────────────────────────────
  Widget _buildWastageCard(Map<String, dynamic> log, bool isMobile) {
    final name = (log['item_name'] ?? 'Unnamed Item').toString();
    final category = (log['category'] ?? 'General').toString();
    final qty = (log['quantity'] as num?)?.toDouble() ?? 0.0;
    final unit = (log['unit'] ?? 'units').toString();
    final reason = (log['reason'] ?? 'Spoilage').toString();
    final loggedBy = (log['logged_by'] ?? 'Staff').toString();
    final notes = (log['notes'] ?? '').toString();
    final createdAt = log['created_at']?.toString();

    String formattedDate = '';
    if (createdAt != null) {
      final dt = DateTime.tryParse(createdAt);
      if (dt != null) formattedDate = DateFormat('MMM d, hh:mm a').format(dt.toLocal());
    }

    Color reasonColor = const Color(0xFFDC2626);
    IconData reasonIcon = Icons.delete_outline_rounded;
    if (reason.contains('Expired')) {
      reasonColor = const Color(0xFFD97706);
      reasonIcon = Icons.timer_off_outlined;
    } else if (reason.contains('Prep')) {
      reasonColor = const Color(0xFF0284C7);
      reasonIcon = Icons.soup_kitchen_outlined;
    } else if (reason.contains('Storage')) {
      reasonColor = const Color(0xFF7C3AED);
      reasonIcon = Icons.ac_unit_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Left Accent Strip
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: reasonColor,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: reasonColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(reasonIcon, size: 18, color: reasonColor),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    category,
                                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                                  ),
                                  if (formattedDate.isNotEmpty) ...[
                                    Text(' • $formattedDate', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF94A3B8))),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Text(
                            '-${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 2)} $unit',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: reasonColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: reasonColor.withValues(alpha: 0.2)),
                              ),
                              child: Text(
                                reason,
                                style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: reasonColor),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'By: $loggedBy',
                                style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () => _confirmDeleteLog(log),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(Icons.delete_outline_rounded, size: 16, color: Colors.grey[400]),
                          ),
                        ),
                      ],
                    ),
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          'Note: $notes',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF64748B), fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Confirm Delete Wastage Log ─────────────────────────────────────────────
  void _confirmDeleteLog(Map<String, dynamic> log) {
    final itemName = log['item_name'] ?? 'Item';
    final qty = (log['quantity'] as num?)?.toDouble() ?? 0.0;
    final unit = log['unit'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Spoilage Log',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: Text(
          'Are you sure you want to delete this wastage log for $itemName ($qty $unit)?',
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() {
                _wastageLogs.removeWhere((l) => l['id'] == log['id']);
              });
              await _saveWastageLogs();

              final currentAuthEmail = _supabase.auth.currentUser?.email ?? 'pagsanjaninv@gmail.com';
              final currentAuthName = currentAuthEmail.split('@').first;

              AuditLogService.logActivity(
                action: 'DELETE',
                module: 'Spoilage',
                description: 'Deleted kitchen wastage log for "$itemName" ($qty $unit) - Originally logged by ${log['logged_by'] ?? 'Staff'}',
                entityId: log['id']?.toString(),
                customUserName: currentAuthName,
                customUserEmail: currentAuthEmail,
                customUserRole: 'STAFF',
                metadata: {
                  'item_name': itemName,
                  'quantity': qty,
                  'unit': unit,
                  'reason': log['reason'],
                  'logged_by': log['logged_by'],
                },
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Deleted wastage log for $itemName.'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty State ────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_outlined, size: 48, color: Color(0xFF10B981)),
            ),
            const SizedBox(height: 14),
            Text(
              'No Spoilage / Wastage Recorded',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No wasted items recorded for this filter. All inventory items are clean.',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showLogWastageModal,
              icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
              label: Text('Log Spoilage Incident', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Log Wastage Modal (Pure Quantity & Unit Focus with Real-time Stock Deduction) ──
  void _showLogWastageModal() {
    Map<String, dynamic>? selectedItem = _inventoryItems.isNotEmpty ? _inventoryItems.first : null;
    final qtyController = TextEditingController();
    final notesController = TextEditingController();
    final itemSearchCtrl = TextEditingController();
    String itemSearchQuery = '';

    // Dynamically pick staff from actual staff directory
    String selectedStaffName = _staffList.isNotEmpty
        ? (_staffList.first['name'] ?? 'Staff')
        : (_supabase.auth.currentUser?.email ?? 'Kitchen Staff');

    String selectedReason = 'Spoilage / Rotten';
    final List<String> reasonOptions = [
      'Spoilage / Rotten',
      'Expired Shelf Life',
      'Prep Spill / Damaged',
      'Chiller / Storage Failure',
      'Packaging / Handling Damage',
      'Other Wastage',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final double availableQty = (selectedItem?['quantity'] as num?)?.toDouble() ?? 0.0;
          final String unit = (selectedItem?['unit'] ?? 'units').toString();
          final String itemName = (selectedItem?['name'] ?? 'Item').toString();

          final double currentQty = double.tryParse(qtyController.text.trim()) ?? 0.0;
          final double remainingQty = (availableQty - currentQty).clamp(0.0, double.infinity);

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Modal Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 22),
                            const SizedBox(width: 10),
                            Text(
                              'Log Spoilage / Wastage',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
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
                  ),

                  // Modal Form
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Select Ingredient with Mini Search Bar
                          _modalInputLabel('Select Ingredient from Inventory *'),
                          if (_inventoryItems.isEmpty)
                            Text('No inventory items found.', style: GoogleFonts.plusJakartaSans(color: const Color(0xFFDC2626)))
                          else ...[
                            // Mini Search Bar
                            Container(
                              height: 38,
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: TextField(
                                controller: itemSearchCtrl,
                                onChanged: (val) => setDialogState(() => itemSearchQuery = val),
                                style: GoogleFonts.plusJakartaSans(fontSize: 12),
                                decoration: InputDecoration(
                                  hintText: 'Search ingredient (e.g. Wonton, Corn, Rice)...',
                                  hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                                  prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF64748B)),
                                  suffixIcon: itemSearchQuery.isNotEmpty
                                      ? InkWell(
                                          onTap: () {
                                            itemSearchCtrl.clear();
                                            setDialogState(() => itemSearchQuery = '');
                                          },
                                          child: const Icon(Icons.clear_rounded, size: 14, color: Color(0xFF94A3B8)),
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 9),
                                ),
                              ),
                            ),

                            // Filtered Selectable Ingredients List
                            Container(
                              constraints: const BoxConstraints(maxHeight: 160),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Builder(
                                builder: (context) {
                                  final q = itemSearchQuery.toLowerCase().trim();
                                  final matches = _inventoryItems.where((i) {
                                    final n = (i['name'] ?? '').toString().toLowerCase();
                                    final c = (i['category'] ?? '').toString().toLowerCase();
                                    return q.isEmpty || n.contains(q) || c.contains(q);
                                  }).toList();

                                  if (matches.isEmpty) {
                                    return Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Center(
                                        child: Text(
                                          'No items found matching "$itemSearchQuery"',
                                          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                                        ),
                                      ),
                                    );
                                  }

                                  return ListView.separated(
                                    shrinkWrap: true,
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    itemCount: matches.length,
                                    separatorBuilder: (ctx, i) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                    itemBuilder: (ctx, i) {
                                      final item = matches[i];
                                      final isSelected = selectedItem != null && (selectedItem!['id'] == item['id'] || selectedItem!['name'] == item['name']);
                                      final curQty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
                                      final itemUnit = (item['unit'] ?? '').toString();

                                      return InkWell(
                                        onTap: () {
                                          setDialogState(() {
                                            selectedItem = item;
                                          });
                                        },
                                        child: Container(
                                          color: isSelected ? const Color(0xFFFEF2F2) : Colors.transparent,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          child: Row(
                                            children: [
                                              Icon(
                                                isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                                size: 16,
                                                color: isSelected ? const Color(0xFFDC2626) : const Color(0xFFCBD5E1),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  item['name'] ?? '',
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 12.5,
                                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                                    color: isSelected ? const Color(0xFFDC2626) : const Color(0xFF1E293B),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '${curQty.toStringAsFixed(curQty.truncateToDouble() == curQty ? 0 : 2)} $itemUnit',
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: const Color(0xFF475569),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),

                          // 2. Quantity Wasted Input
                          _modalInputLabel('Quantity Wasted ($unit) *'),
                          TextField(
                            controller: qtyController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (v) => setDialogState(() {}),
                            decoration: _modalInputDecoration('e.g. 2', Icons.numbers_rounded),
                          ),
                          const SizedBox(height: 8),

                          // Live Stock Deduction Preview Banner
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: currentQty > 0
                                  ? const Color(0xFFFEF2F2)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: currentQty > 0
                                    ? const Color(0xFFFCA5A5)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 16,
                                  color: currentQty > 0
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    currentQty > 0
                                        ? 'Deducts $currentQty $unit of $itemName • Remaining: ${remainingQty.toStringAsFixed(remainingQty.truncateToDouble() == remainingQty ? 0 : 2)} $unit'
                                        : 'Current available stock: ${availableQty.toStringAsFixed(availableQty.truncateToDouble() == availableQty ? 0 : 2)} $unit',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      fontWeight: currentQty > 0 ? FontWeight.w700 : FontWeight.w500,
                                      color: currentQty > 0 ? const Color(0xFFDC2626) : const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 3. Spoilage Reason
                          _modalInputLabel('Reason for Wastage *'),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedReason,
                                isExpanded: true,
                                items: reasonOptions.map((r) => DropdownMenuItem(value: r, child: Text(r, style: GoogleFonts.plusJakartaSans(fontSize: 13)))).toList(),
                                onChanged: (val) {
                                  if (val != null) setDialogState(() => selectedReason = val);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 4. Logged By (From Staff Directory)
                          _modalInputLabel('Logged By (Staff / Cook on Duty)'),
                          if (_staffList.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _staffList.any((s) => s['name'] == selectedStaffName)
                                      ? selectedStaffName
                                      : _staffList.first['name']?.toString(),
                                  isExpanded: true,
                                  items: _staffList.map((s) {
                                    final sName = (s['name'] ?? 'Staff').toString();
                                    final sRole = (s['role'] ?? s['title'] ?? '').toString();
                                    return DropdownMenuItem<String>(
                                      value: sName,
                                      child: Text(
                                        '$sName ${sRole.isNotEmpty ? "($sRole)" : ""}',
                                        style: GoogleFonts.plusJakartaSans(fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setDialogState(() => selectedStaffName = val);
                                  },
                                ),
                              ),
                            )
                          else
                            TextFormField(
                              initialValue: selectedStaffName,
                              onChanged: (v) => selectedStaffName = v,
                              decoration: _modalInputDecoration('Staff name', Icons.person_outline_rounded),
                            ),
                          const SizedBox(height: 14),

                          // 5. Notes / Cause
                          _modalInputLabel('Notes / Root Cause (Optional)'),
                          TextField(
                            controller: notesController,
                            maxLines: 2,
                            decoration: _modalInputDecoration('e.g. Broken packaging, expired batch, or chiller issue', Icons.notes_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Modal Actions
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () async {
                              final qtyText = qtyController.text.trim();
                              final notes = notesController.text.trim();

                              final qty = double.tryParse(qtyText);
                              if (qty == null || qty <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter a valid quantity wasted.')),
                                );
                                return;
                              }

                              if (selectedItem == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please select an ingredient.')),
                                );
                                return;
                              }

                              if (qty > availableQty && availableQty > 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Cannot waste more than available stock ($availableQty $unit).')),
                                );
                                return;
                              }

                              final itemDbName = selectedItem!['name']?.toString() ?? 'Item';
                              final category = selectedItem!['category']?.toString() ?? 'General';
                              final itemId = selectedItem!['id'];

                              // 1. Deduct quantity from Supabase inventory table
                              try {
                                final currentInvQty = (selectedItem!['quantity'] as num?)?.toDouble() ?? 0.0;
                                final newQty = (currentInvQty - qty).clamp(0.0, double.infinity);

                                if (itemId != null) {
                                  await _supabase
                                      .from('inventory')
                                      .update({'quantity': newQty})
                                      .eq('id', itemId);
                                }
                              } catch (e) {
                                debugPrint('Note: error updating inventory quantity: $e');
                              }

                              // 2. Record in stock_transactions table
                              String? insertedTxId;
                              try {
                                final txRes = await _supabase.from('stock_transactions').insert({
                                  'item_name': itemDbName,
                                  'transaction_type': 'outgoing',
                                  'quantity': qty.round() > 0 ? qty.round() : 1,
                                  'unit': unit,
                                  'purpose': 'Wastage: $selectedReason',
                                  'requested_by': selectedStaffName,
                                  'processed_by': selectedStaffName,
                                }).select('id').single();
                                insertedTxId = txRes['id']?.toString();
                              } catch (e) {
                                debugPrint('Note: error inserting to stock_transactions: $e');
                              }

                              // 3. Add to wastage log records
                              final newLog = {
                                'id': insertedTxId ?? 'WST-${DateTime.now().millisecondsSinceEpoch.toString()}',
                                'item_name': itemDbName,
                                'category': category,
                                'quantity': qty,
                                'unit': unit,
                                'cost_per_unit': 0.0,
                                'total_cost': 0.0,
                                'reason': selectedReason,
                                'logged_by': selectedStaffName,
                                'notes': notes,
                                'created_at': DateTime.now().toIso8601String(),
                              };

                              setState(() {
                                _wastageLogs.insert(0, newLog);
                              });
                              await _saveWastageLogs();
                              _loadData();

                              final currentAuthEmail = _supabase.auth.currentUser?.email ?? 'pagsanjaninv@gmail.com';
                              final currentAuthName = currentAuthEmail.split('@').first;

                              await AuditLogService.logActivity(
                                action: 'CREATE',
                                module: 'Spoilage',
                                description: 'Logged kitchen wastage: ${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 2)} $unit of "$itemDbName" (Reason: $selectedReason) - Cook/Staff on duty: $selectedStaffName',
                                entityId: insertedTxId,
                                customUserName: currentAuthName,
                                customUserEmail: currentAuthEmail,
                                customUserRole: 'STAFF',
                                metadata: {
                                  'item_name': itemDbName,
                                  'quantity': qty,
                                  'unit': unit,
                                  'reason': selectedReason,
                                  'staff_on_duty': selectedStaffName,
                                  'auth_user_email': currentAuthEmail,
                                  'notes': notes,
                                },
                              );

                              Navigator.pop(ctx);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Deducted $qty $unit of $itemDbName from inventory ($selectedReason)'),
                                    backgroundColor: const Color(0xFFDC2626),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              'Confirm & Deduct Stock',
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white),
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

  Widget _modalInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
      ),
    );
  }

  InputDecoration _modalInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF94A3B8)),
      prefixIcon: Icon(icon, size: 16, color: const Color(0xFF64748B)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5)),
    );
  }
}
