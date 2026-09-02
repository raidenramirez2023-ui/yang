import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yang_chow/services/paymongo_service.dart';
import 'package:yang_chow/services/receipt_pdf_service.dart';
import 'package:yang_chow/services/reservation_service.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:yang_chow/widgets/customer/customer_ui_components.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Modern Customer Transactions & Invoices Ledger Page (Full-Width Maximized)
// ══════════════════════════════════════════════════════════════════════════════

class TransactionsPage extends StatefulWidget {
  final List<dynamic> initialTransactions;

  const TransactionsPage({super.key, required this.initialTransactions});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  late List<dynamic> _transactions;
  bool _isLoading = false;
  Timer? _pollingTimer;
  final _fmt = NumberFormat('#,##0.00', 'en_PH');
  String _selectedFilter = 'all'; // 'all', 'paid', 'unpaid', 'cancelled'

  @override
  void initState() {
    super.initState();
    _transactions = List.from(widget.initialTransactions);
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshTransactions() async {
    setState(() => _isLoading = true);
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      final results = await Future.wait([
        Supabase.instance.client
            .from('reservations')
            .select('*')
            .eq('customer_email', currentUser.email!)
            .order('created_at', ascending: false),
        Supabase.instance.client
            .from('advance_orders')
            .select('*')
            .eq('customer_email', currentUser.email!)
            .order('created_at', ascending: false),
      ]);

      final reservations = List<Map<String, dynamic>>.from(results[0]).map((r) {
        return {...r, '_db_table': 'reservations'};
      }).toList();

      final advanceOrders = List<Map<String, dynamic>>.from(results[1]).where((o) {
        final ps = o['payment_status']?.toString() ?? '';
        return ps == 'paid' || ps == 'fully_paid';
      }).map((o) {
        return {
          ...o,
          'event_type': 'Advance Order (${o['order_type']})',
          'event_date': o['order_date'],
          'start_time': o['order_time'],
          'duration_hours': 0,
          '_db_table': 'advance_orders',
        };
      }).toList();

      final combined = [...reservations, ...advanceOrders];
      combined.sort((a, b) {
        final aTime = DateTime.parse(a['created_at'] ?? DateTime.now().toUtc().toIso8601String());
        final bTime = DateTime.parse(b['created_at'] ?? DateTime.now().toUtc().toIso8601String());
        return bTime.compareTo(aTime);
      });

      if (mounted) {
        setState(() {
          _transactions = combined;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error refreshing transactions: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to refresh transactions'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  List<dynamic> get _filteredTransactions {
    if (_selectedFilter == 'paid') {
      return _transactions.where((t) {
        final ps = t['payment_status']?.toString().toLowerCase() ?? '';
        return ps == 'paid' || ps == 'fully_paid';
      }).toList();
    } else if (_selectedFilter == 'unpaid') {
      return _transactions.where((t) {
        final ps = t['payment_status']?.toString().toLowerCase() ?? '';
        final status = t['status']?.toString().toLowerCase() ?? '';
        return (ps == 'unpaid' || ps == 'deposit_paid' || ps == 'pending') && status != 'cancelled';
      }).toList();
    } else if (_selectedFilter == 'cancelled') {
      return _transactions.where((t) {
        final status = t['status']?.toString().toLowerCase() ?? '';
        return status == 'cancelled';
      }).toList();
    }
    return _transactions;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final displayedList = _filteredTransactions;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.navColor,
        elevation: 0,
        leading: AnimatedTapScale(
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        ),
        title: Text(
          'Transactions & Invoices',
          style: GoogleFonts.lora(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _refreshTransactions,
            icon: _isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh Transactions',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshTransactions,
        color: AppTheme.forestGreen,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 24,
            vertical: isMobile ? 18 : 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Summary Row ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Billing & Transaction Records',
                          style: GoogleFonts.inter(
                            fontSize: isMobile ? 20 : 24,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.darkGrey,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Official receipts, payment statuses, and reservation statements.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.mediumGrey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ── Filter Chips ──
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All (${_transactions.length})', 'all'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Paid / Settled', 'paid'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Pending / Due', 'unpaid'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Cancelled', 'cancelled'),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Loading & Empty State ──
              if (_isLoading && _transactions.isEmpty)
                Column(
                  children: List.generate(3, (index) => const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: AppShimmer(width: double.infinity, height: 120, borderRadius: 20),
                  )),
                )
              else if (displayedList.isEmpty)
                EmptyStateCard(
                  icon: Icons.receipt_long_rounded,
                  title: 'No transactions found',
                  description: _selectedFilter == 'all'
                      ? 'Your reservation orders and payment invoices will appear here.'
                      : 'No transactions matching "$_selectedFilter" filter.',
                )
              else
                // ── Table View on Desktop/Tablet vs Card View on Mobile ──
                isMobile
                    ? _buildMobileTransactionsList(displayedList)
                    : _buildDesktopTransactionsTable(displayedList),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String key) {
    final isSelected = _selectedFilter == key;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF14332E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF14332E) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF14332E).withValues(alpha: 0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 🖥️ FULL-WIDTH MAXIMIZED DESKTOP/TABLET DATA TABLE VIEW
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildDesktopTransactionsTable(List<dynamic> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = math.max(constraints.maxWidth, 980.0);

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: const BoxDecoration(
                      color: Color(0xFF14332E),
                    ),
                    child: Row(
                      children: [
                        _buildTableHeaderCell('REF #', flex: 2),
                        _buildTableHeaderCell('EVENT / ORDER', flex: 5),
                        _buildTableHeaderCell('DATE & TIME', flex: 4),
                        _buildTableHeaderCell('GUESTS', flex: 2),
                        _buildTableHeaderCell('PAYMENT', flex: 3),
                        _buildTableHeaderCell('STATUS', flex: 3),
                        _buildTableHeaderCell('ACTION', flex: 2, alignment: Alignment.centerRight),
                      ],
                    ),
                  ),

                  // Table Rows
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final tx = Map<String, dynamic>.from(items[index]);
                      return _buildTableRow(context, tx, index);
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

  Widget _buildTableHeaderCell(String title, {required int flex, Alignment alignment = Alignment.centerLeft}) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: alignment,
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Colors.white.withValues(alpha: 0.85),
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  Widget _buildTableRow(BuildContext context, Map<String, dynamic> tx, int index) {
    final rawId = tx['id']?.toString() ?? '';
    final ref = rawId.length >= 8 ? rawId.substring(0, 8).toUpperCase() : rawId.toUpperCase();
    final eventType = tx['event_type']?.toString() ?? 'Dining Reservation';
    final eventDate = tx['event_date']?.toString() ?? 'N/A';
    final startTime = tx['start_time']?.toString() ?? '';
    final guests = tx['number_of_guests'] != null ? '${tx['number_of_guests']} guests' : '—';
    final status = tx['status']?.toString() ?? 'pending';
    final paymentStatus = tx['payment_status']?.toString() ?? 'unpaid';
    final isAdvanceOrder = tx['_db_table'] == 'advance_orders';

    return Material(
      color: index % 2 == 0 ? Colors.white : const Color(0xFFFAFAFA),
      child: InkWell(
        onTap: () => _showTransactionDetailModal(context, tx),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              // Ref #
              Expanded(
                flex: 2,
                child: Text(
                  '#$ref',
                  style: GoogleFonts.robotoMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),

              // Event / Order
              Expanded(
                flex: 5,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: isAdvanceOrder
                            ? const Color(0xFF0EA5E9).withValues(alpha: 0.1)
                            : AppTheme.forestGreen.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isAdvanceOrder ? Icons.fastfood_rounded : Icons.event_seat_rounded,
                        size: 15,
                        color: isAdvanceOrder ? const Color(0xFF0284C7) : AppTheme.forestGreen,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        eventType,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkGrey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Date & Time
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      eventDate,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkGrey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (startTime.isNotEmpty)
                      Text(
                        startTime,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.mediumGrey,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),

              // Guests
              Expanded(
                flex: 2,
                child: Text(
                  guests,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF475569),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Payment Status
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildPaymentBadge(paymentStatus, isAdvanceOrder: isAdvanceOrder),
                ),
              ),

              // Status
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildStatusChip(status),
                ),
              ),

              // Action
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => _showTransactionDetailModal(context, tx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      foregroundColor: const Color(0xFF1E293B),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, size: 15),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 📱 MOBILE COMPACT LEDGER CARDS (WRAP PROTECTED - ZERO OVERFLOW)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildMobileTransactionsList(List<dynamic> items) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final tx = Map<String, dynamic>.from(items[index]);
        final rawId = tx['id']?.toString() ?? '';
        final ref = rawId.length >= 8 ? rawId.substring(0, 8).toUpperCase() : rawId.toUpperCase();
        final eventType = tx['event_type']?.toString() ?? 'Dining Reservation';
        final eventDate = tx['event_date']?.toString() ?? 'N/A';
        final startTime = tx['start_time']?.toString() ?? '';
        final status = tx['status']?.toString() ?? 'pending';
        final paymentStatus = tx['payment_status']?.toString() ?? 'unpaid';
        final isAdvanceOrder = tx['_db_table'] == 'advance_orders';

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showTransactionDetailModal(context, tx),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row: Icon + Title + Ref #
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isAdvanceOrder
                                ? const Color(0xFF0EA5E9).withValues(alpha: 0.1)
                                : AppTheme.forestGreen.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isAdvanceOrder ? Icons.fastfood_rounded : Icons.event_seat_rounded,
                            size: 16,
                            color: isAdvanceOrder ? const Color(0xFF0284C7) : AppTheme.forestGreen,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                eventType,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.darkGrey,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '#$ref • $eventDate${startTime.isNotEmpty ? " • $startTime" : ""}',
                                style: GoogleFonts.inter(
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

                    const SizedBox(height: 12),
                    const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 10),

                    // Bottom Row: Badges & View CTA with Wrap for zero overflow
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _buildPaymentBadge(paymentStatus, isAdvanceOrder: isAdvanceOrder),
                              _buildStatusChip(status),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Details',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.forestGreen,
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.forestGreen),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 🧾 TRANSACTION DETAILS & RECEIPT MODAL
  // ══════════════════════════════════════════════════════════════════════════
  void _showTransactionDetailModal(BuildContext context, Map<String, dynamic> tx) {
    final rawId = tx['id']?.toString() ?? '';
    final ref = rawId.length >= 8 ? rawId.substring(0, 8).toUpperCase() : rawId.toUpperCase();
    final eventType = tx['event_type']?.toString() ?? 'Reservation';
    final eventDate = tx['event_date']?.toString() ?? 'N/A';
    final startTime = tx['start_time']?.toString() ?? 'N/A';
    final guests = tx['number_of_guests']?.toString();
    final duration = tx['duration_hours']?.toString();
    final status = tx['status']?.toString() ?? 'pending';
    final paymentStatus = tx['payment_status']?.toString() ?? 'unpaid';
    final receiptUrl = tx['receipt_url']?.toString();
    final isAdvanceOrder = tx['_db_table'] == 'advance_orders';

    final totalPrice = (tx['total_price'] as num?)?.toDouble() ?? 0.0;
    final depositAmount = (tx['deposit_amount'] as num?)?.toDouble() ?? 0.0;
    final remaining = (tx['remaining_balance'] as num?)?.toDouble() ?? (totalPrice - depositAmount);

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Modal Header ──
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF14332E), Color(0xFF1A453E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: Icon(
                            isAdvanceOrder ? Icons.fastfood_rounded : Icons.receipt_long_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                eventType,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Invoice Ref #$ref',
                                style: GoogleFonts.robotoMono(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                          onPressed: () => Navigator.pop(dialogContext),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: 18,
                        ),
                      ],
                    ),
                  ),

                  // ── Modal Content Details ──
                  Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status & Payment Summary
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('PAYMENT STATUS', style: _modalLabelStyle),
                                const SizedBox(height: 4),
                                _buildPaymentBadge(paymentStatus, isAdvanceOrder: isAdvanceOrder),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('BOOKING STATUS', style: _modalLabelStyle),
                                const SizedBox(height: 4),
                                _buildStatusChip(status),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),
                        const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 16),

                        // Booking Schedule & Details
                        _buildModalInfoRow(Icons.calendar_today_rounded, 'Date', eventDate),
                        const SizedBox(height: 10),
                        _buildModalInfoRow(Icons.access_time_rounded, 'Time', startTime),
                        if (guests != null) ...[
                          const SizedBox(height: 10),
                          _buildModalInfoRow(Icons.people_alt_rounded, 'Party Size', '$guests guests'),
                        ],
                        if (!isAdvanceOrder && duration != null) ...[
                          const SizedBox(height: 10),
                          _buildModalInfoRow(Icons.timer_rounded, 'Duration', '$duration hours'),
                        ],

                        const SizedBox(height: 18),
                        const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 16),

                        // Pricing Breakdown
                        Text('FINANCIAL BREAKDOWN', style: _modalLabelStyle),
                        const SizedBox(height: 12),
                        if (totalPrice > 0)
                          _buildPriceLine('Total Amount', '₱${_fmt.format(totalPrice)}'),
                        if (depositAmount > 0) ...[
                          const SizedBox(height: 6),
                          _buildPriceLine('Deposit Paid', '- ₱${_fmt.format(depositAmount)}', isGreen: true),
                        ],
                        if (remaining > 0 && paymentStatus == 'deposit_paid') ...[
                          const SizedBox(height: 6),
                          _buildPriceLine('Remaining Balance Due', '₱${_fmt.format(remaining)}', isBold: true, isRed: true),
                        ],

                        // Actions: Pay Remaining Balance or Download PDF Receipt
                        if (tx['_db_table'] == 'reservations' && paymentStatus == 'deposit_paid' && remaining > 0) ...[
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                _payRemainingBalance(
                                  reservationId: rawId,
                                  remaining: remaining,
                                  eventType: eventType,
                                );
                              },
                              icon: const Icon(Icons.payment_rounded, size: 16),
                              label: Text('Pay ₱${_fmt.format(remaining)} via GCash'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0EA5E9),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ],

                        // ── Official Yang Chow Electronic PDF Receipt (Direct Download) ──
                        if (status != 'cancelled' && (paymentStatus == 'paid' || paymentStatus == 'fully_paid' || paymentStatus == 'deposit_paid')) ...[
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                try {
                                  await ReceiptPdfService.downloadReceiptPdf(
                                    tx,
                                    isPaymentReceipt: paymentStatus == 'fully_paid' || paymentStatus == 'paid',
                                  );
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to download PDF receipt: $e'),
                                        backgroundColor: AppTheme.errorRed,
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Color(0xFF14332E)),
                              label: Text(
                                'Download Official Receipt (PDF)',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF14332E),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(color: Color(0xFF14332E), width: 1.2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ],

                        // ── External PayMongo Gateway Record (if available) ──
                        if (receiptUrl != null && receiptUrl.isNotEmpty && (receiptUrl.contains('pm.link') || receiptUrl.contains('paymongo'))) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              onPressed: () async {
                                final uri = Uri.parse(receiptUrl);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              },
                              icon: const Icon(Icons.open_in_new_rounded, size: 14, color: Color(0xFF0284C7)),
                              label: Text(
                                'View PayMongo Transaction Record',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0284C7),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
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

  TextStyle get _modalLabelStyle => GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF94A3B8),
        letterSpacing: 0.9,
      );

  Widget _buildModalInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 10),
        Text(label, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(value, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.darkGrey, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildPriceLine(String label, String amount, {bool isGreen = false, bool isRed = false, bool isBold = false}) {
    Color color = AppTheme.darkGrey;
    if (isGreen) color = const Color(0xFF16A34A);
    if (isRed) color = const Color(0xFFDC2626);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: isBold ? AppTheme.darkGrey : const Color(0xFF64748B),
          ),
        ),
        Text(
          amount,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 🏷️ BADGES & STATUS CHIPS (ZERO-OVERFLOW GUARANTEE)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildPaymentBadge(String paymentStatus, {bool isAdvanceOrder = false}) {
    final isPaid = paymentStatus == 'paid' || paymentStatus == 'fully_paid';
    final isDepositPaid = paymentStatus == 'deposit_paid';
    final color = isPaid
        ? const Color(0xFF16A34A)
        : isDepositPaid
            ? const Color(0xFF0284C7)
            : const Color(0xFFD97706);
    final bgColor = isPaid
        ? const Color(0xFFF0FDF4)
        : isDepositPaid
            ? const Color(0xFFF0F9FF)
            : const Color(0xFFFFFBEB);
    final label = isPaid
        ? 'PAID'
        : isDepositPaid
            ? (isAdvanceOrder ? 'FULL PAID' : 'DEPOSIT PAID')
            : paymentStatus.toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPaid ? Icons.check_circle_rounded : Icons.pending_rounded,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    Color bgColor;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'pending':
        color = const Color(0xFFD97706);
        bgColor = const Color(0xFFFFFBEB);
        icon = Icons.hourglass_top_rounded;
        break;
      case 'confirmed':
        color = const Color(0xFF16A34A);
        bgColor = const Color(0xFFF0FDF4);
        icon = Icons.check_circle_rounded;
        break;
      case 'paid':
      case 'fully_paid':
        color = const Color(0xFF16A34A);
        bgColor = const Color(0xFFF0FDF4);
        icon = Icons.verified_rounded;
        break;
      case 'cancelled':
        color = const Color(0xFFDC2626);
        bgColor = const Color(0xFFFEF2F2);
        icon = Icons.cancel_rounded;
        break;
      case 'no_show':
        color = const Color(0xFFEA580C);
        bgColor = const Color(0xFFFFF7ED);
        icon = Icons.person_off_rounded;
        break;
      default:
        color = const Color(0xFF64748B);
        bgColor = const Color(0xFFF8FAFC);
        icon = Icons.help_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              status.toUpperCase(),
              style: GoogleFonts.inter(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 💳 PAYMONGO REMAINING BALANCE INTEGRATION
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _payRemainingBalance({
    required String reservationId,
    required double remaining,
    required String eventType,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            const CircularProgressIndicator(color: Color(0xFF0EA5E9)),
            const SizedBox(width: 16),
            const Expanded(child: Text('Creating payment link...')),
          ],
        ),
      ),
    );

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      final customerName = currentUser?.userMetadata?['name'] ?? currentUser?.email?.split('@')[0] ?? 'Customer';

      final response = await PayMongoService.createPaymentLink(
        amount: remaining,
        description: 'Remaining Balance — $eventType',
        metadata: {
          'source': 'remaining_balance_self_service',
          'reservation_id': reservationId,
          'customer_name': customerName,
        },
      );

      if (mounted) Navigator.of(context).pop();

      if (response['success'] == true && response['checkoutUrl'] != null) {
        final checkoutUrl = response['checkoutUrl'] as String;
        final linkId = response['linkId'] as String?;

        try {
          await Supabase.instance.client.from('reservations').update({
            'balance_link_id': linkId,
            'balance_link_url': checkoutUrl,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', reservationId);
        } catch (e) {
          debugPrint('Warning: could not save balance link to DB: $e');
        }

        await launchUrl(Uri.parse(checkoutUrl), mode: LaunchMode.externalApplication);

        if (mounted) {
          _showWaitingForPaymentDialog(
            remaining: remaining,
            onCancel: () {
              _pollingTimer?.cancel();
            },
          );
          if (linkId != null) {
            _startPolling(
              linkId: linkId,
              reservationId: reservationId,
              remaining: remaining,
            );
          }
        }
      } else {
        throw Exception('No checkout URL returned');
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  void _showWaitingForPaymentDialog({
    required double remaining,
    required VoidCallback onCancel,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(28),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.qr_code_2, size: 48, color: Color(0xFF0EA5E9)),
            ),
            const SizedBox(height: 20),
            Text(
              'Waiting for Payment...',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGrey,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Text(
                '₱${_fmt.format(remaining)}',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFDC2626),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(color: Color(0xFF0EA5E9), strokeWidth: 3),
            ),
            const SizedBox(height: 16),
            Text(
              'Complete payment in the GCash/PayMongo page that just opened.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.mediumGrey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              onCancel();
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _startPolling({
    required String linkId,
    required String reservationId,
    required double remaining,
  }) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final result = await PayMongoService.retrievePaymentLink(linkId);
        if (result['isPaid'] == true) {
          timer.cancel();
          if (mounted) Navigator.of(context).pop();

          final svc = ReservationService();
          await svc.updatePaymentStatus(
            id: reservationId,
            paymentStatus: 'fully_paid',
            table: 'reservations',
            paymentAmount: null,
            paymentReference: 'PayMongo-Balance',
          );

          await _refreshTransactions();

          if (mounted) _showPaymentSuccessDialog(remaining);
        }
      } catch (e) {
        debugPrint('Polling error: $e');
      }
    });
  }

  void _showPaymentSuccessDialog(double amount) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(28),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, size: 48, color: AppTheme.successGreen),
            ),
            const SizedBox(height: 20),
            Text(
              'Payment Received!',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGrey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '₱${_fmt.format(amount)} remaining balance successfully paid.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.mediumGrey),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Your reservation is now fully paid ✅',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.successGreen,
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.forestGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
