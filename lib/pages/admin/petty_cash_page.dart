import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/models/petty_cash_model.dart';
import 'package:yang_chow/services/petty_cash_service.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';

class PettyCashPage extends StatefulWidget {
  const PettyCashPage({super.key});

  @override
  State<PettyCashPage> createState() => _PettyCashPageState();
}

class _PettyCashPageState extends State<PettyCashPage> {
  final PettyCashService _pettyCashService = PettyCashService();
  String _selectedStatus = 'All';
  String _selectedCategory = 'All';
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final res = await Supabase.instance.client
        .from('users')
        .select('role')
        .eq('email', user.email!)
        .maybeSingle();

    if (!mounted) return;
    final role = (res?['role'] ?? '').toString().toLowerCase();
    final userEmail = user.email?.toLowerCase() ?? '';

    if (userEmail == 'pagsanjaninv@gmail.com' || role == 'admin') {
      setState(() => _isAdmin = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.adminMainBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(ResponsiveUtils.isMobile(context) ? 8 : 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFundBalanceCard(),
                    const SizedBox(height: 12),
                    _buildStatisticsCards(),
                    const SizedBox(height: 12),
                    _buildFilterSection(),
                    const SizedBox(height: 12),
                    _buildExpensesList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isMobile = ResponsiveUtils.isMobile(context);
    return Container(
      margin: EdgeInsets.all(isMobile ? 12 : 16),
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.adminChatButton, AppTheme.adminFeaturedMetricCard],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.adminChatButton.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.adminChatButton.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: AppTheme.white,
              size: 28,
            ),
          ),
          SizedBox(width: isMobile ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Petty Cash Management',
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Track inventory purchase expenses',
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 13,
                    color: AppTheme.mediumGrey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (_isAdmin)
            Container(
              decoration: BoxDecoration(
                color: AppTheme.adminChatButton.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.add_rounded, color: AppTheme.white),
                onPressed: _showReplenishDialog,
                tooltip: 'Replenish Fund',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFundBalanceCard() {
    return StreamBuilder<PettyCashFund?>(
      stream: _pettyCashService.streamPettyCashFund(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final fund = snapshot.data;
        if (fund == null) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
AppTheme.adminPricingBackground,
AppTheme.adminCardBackground,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.warningOrange.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: AppTheme.warningOrange,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Fund Not Initialized',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkGrey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Initialize to start tracking',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.mediumGrey,
                  ),
                ),
                if (_isAdmin) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _showInitializeDialog,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Initialize Fund'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.adminChatButton,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        final isMobile = ResponsiveUtils.isMobile(context);
        return Container(
          padding: EdgeInsets.all(isMobile ? 20 : 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.adminChatButton.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: AppTheme.adminChatButton,
                      size: 28,
                    ),
                  ),
                  if (fund.isLowBalance)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.warningOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.warningOrange.withValues(alpha: 0.3)),
                      ),
                      child: const Text(
                        'Low Balance',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.warningOrange,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Current Balance',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.mediumGrey,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '₱${fund.currentBalance.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: isMobile ? 28 : 36,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.adminChatButton,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildInfoChip('Initial', '₱${fund.initialBalance.toStringAsFixed(0)}'),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    'Last Replenished',
                    fund.lastReplenishedAt != null ? _formatDate(fund.lastReplenishedAt!) : 'Never',
                  ),
                ],
              ),
              if (_isAdmin) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildModernButton(
                        icon: Icons.sync_rounded,
                        label: 'Reconcile',
                        color: AppTheme.adminChatButton,
                        onPressed: _showReconciliationDialog,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildModernButton(
                        icon: Icons.history_rounded,
                        label: 'History',
                        color: AppTheme.adminChatButton,
                        onPressed: _showReconciliationHistoryDialog,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.mediumGrey,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.darkGrey,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

  // Professional color palette
  static const Color _primaryColor = Color(0xFFE0A020); // Admin Primary Accent (Gold)
  static const Color _successColor = Color(0xFF2E7D32); // Forest Green
  static const Color _warningColor = Color(0xFFFFC107); // Gold Yellow
  // ignore: unused_field
  static const Color _errorColor = Color(0xFFB21B21); // Ruby Red
  static const Color _infoColor = Color(0xFFA0121A); // Crimson Red
  // ignore: unused_field
  static const Color _secondaryColor = Color(0xFF780A10); // Dark Crimson

  Widget _buildStatisticsCards() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _pettyCashService.getExpenseStatistics(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox();
        }

        final stats = snapshot.data!;
        final totalExpenses = stats['total_expenses'] as double? ?? 0.0;
        final pendingAmount = stats['pending_amount'] as double? ?? 0.0;
        final approvedAmount = stats['approved_amount'] as double? ?? 0.0;
        final reimbursedAmount = stats['reimbursed_amount'] as double? ?? 0.0;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildModernStatCard('Total', totalExpenses, _primaryColor, Icons.receipt_long_rounded),
              const SizedBox(width: 12),
              _buildModernStatCard('Pending', pendingAmount, _warningColor, Icons.pending_rounded),
              const SizedBox(width: 12),
              _buildModernStatCard('Approved', approvedAmount, _successColor, Icons.check_circle_rounded),
              const SizedBox(width: 12),
              _buildModernStatCard('Reimbursed', reimbursedAmount, _infoColor, Icons.payments_rounded),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModernStatCard(String label, double value, Color color, IconData icon) {
    final isMobile = ResponsiveUtils.isMobile(context);
    return Container(
      width: isMobile ? 110 : 130,
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            '₱${value.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.darkGrey,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: isMobile ? 11 : 12,
              color: AppTheme.mediumGrey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    final isMobile = ResponsiveUtils.isMobile(context);
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedStatus == 'All' ? null : _selectedStatus,
                      isExpanded: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.mediumGrey, size: 20),
                      items: ['pending', 'approved', 'rejected', 'reimbursed']
                          .map((status) => DropdownMenuItem(
                                value: status,
                                child: Text(status.capitalize()),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() => _selectedStatus = value ?? 'All');
                      },
                      hint: const Text(
                        'Status',
                        style: TextStyle(color: AppTheme.mediumGrey, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      style: const TextStyle(color: AppTheme.darkGrey, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCategory == 'All' ? null : _selectedCategory,
                      isExpanded: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.mediumGrey, size: 20),
                      items: PettyCashExpense.categories
                          .map((category) => DropdownMenuItem(
                                value: category,
                                child: Text(category.split('_').map((word) => 
                                  word.capitalize()).join(' ')),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() => _selectedCategory = value ?? 'All');
                      },
                      hint: const Text(
                        'Category',
                        style: TextStyle(color: AppTheme.mediumGrey, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      style: const TextStyle(color: AppTheme.darkGrey, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_isAdmin) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildModernButton(
                    icon: Icons.bar_chart_rounded,
                    label: 'Spending Report',
                    color: AppTheme.adminChatButton,
                    onPressed: _showSpendingReportDialog,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildModernButton(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Budgets',
                    color: AppTheme.adminChatButton,
                    onPressed: _showBudgetManagementDialog,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExpensesList() {
    return StreamBuilder<List<PettyCashExpense>>(
      stream: _pettyCashService.streamExpenses(
        status: _selectedStatus == 'All' ? null : _selectedStatus,
        category: _selectedCategory == 'All' ? null : _selectedCategory,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final expenses = snapshot.data!;

        if (expenses.isEmpty) {
          return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.lightGrey.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.receipt_long_rounded,
                      size: 48,
                      color: AppTheme.mediumGrey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No expenses found',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.mediumGrey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try adjusting your filters',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.mediumGrey,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: expenses.map((expense) => _buildExpenseCard(expense)).toList(),
        );
      },
    );
  }

  Widget _buildExpenseCard(PettyCashExpense expense) {
    final isMobile = ResponsiveUtils.isMobile(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isMobile ? 16 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildModernStatusChip(expense.status),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  expense.description,
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkGrey,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '₱${expense.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.adminChatButton,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.person_rounded, size: 14, color: AppTheme.mediumGrey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  expense.purchasedBy,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.mediumGrey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.mediumGrey),
              const SizedBox(width: 4),
              Text(
                _formatDate(expense.expenseDate),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.mediumGrey,
                ),
              ),
            ],
          ),
          if (expense.isMultiItemExpense) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: expense.inventoryItems!.map((item) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.adminChatButton.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${item.itemName} x${item.quantity}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.adminChatButton,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ] else if (expense.inventoryItemName != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.inventory_2_rounded, size: 14, color: AppTheme.mediumGrey),
                const SizedBox(width: 4),
                Text(
                  expense.inventoryItemName!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.mediumGrey,
                  ),
                ),
                if (expense.quantityPurchased != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    'x${expense.quantityPurchased}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.mediumGrey,
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (expense.receiptImageUrl != null) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => Dialog(
                    backgroundColor: Colors.transparent,
                    child: Stack(
                      children: [
                        Image.network(
                          expense.receiptImageUrl!,
                          fit: BoxFit.contain,
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: Row(
                children: [
                  Icon(Icons.receipt_long_rounded, size: 14, color: AppTheme.primaryColor),
                  const SizedBox(width: 4),
                  const Text(
                    'View Receipt',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.adminChatButton,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_isAdmin && expense.status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _approveExpense(expense.id!),
                    child: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _rejectExpense(expense.id!),
                    child: const Text('Reject'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.errorRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (_isAdmin && expense.status == 'approved') ...[
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _markAsReimbursed(expense.id!),
              child: const Text('Mark as Reimbursed'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModernStatusChip(String status) {
    Color color;
    IconData iconData;
    
    switch (status) {
      case 'pending':
        color = AppTheme.warningOrange;
        iconData = Icons.pending_rounded;
        break;
      case 'approved':
        color = AppTheme.successGreen;
        iconData = Icons.check_circle_rounded;
        break;
      case 'rejected':
        color = AppTheme.errorRed;
        iconData = Icons.cancel_rounded;
        break;
      case 'reimbursed':
        color = AppTheme.primaryColor;
        iconData = Icons.payments_rounded;
        break;
      default:
        color = AppTheme.mediumGrey;
        iconData = Icons.help_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            iconData,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            status.capitalize(),
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  void _showInitializeDialog() {
    final amountCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Initialize Petty Cash Fund'),
        content: TextField(
          controller: amountCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Initial Amount (₱)',
            prefixText: '₱',
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text);
              if (amount != null && amount > 0) {
                final success = await _pettyCashService.initializePettyCashFund(amount);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'Fund initialized successfully' : 'Failed to initialize fund'),
                      backgroundColor: success ? AppTheme.successGreen : AppTheme.errorRed,
                    ),
                  );
                }
              }
            },
            child: const Text('Initialize'),
          ),
        ],
      ),
    );
  }

  void _showReplenishDialog() {
    final amountCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replenish Petty Cash Fund'),
        content: TextField(
          controller: amountCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Amount to Add (₱)',
            prefixText: '₱',
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text);
              if (amount != null && amount > 0) {
                final success = await _pettyCashService.replenishPettyCashFund(amount);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'Fund replenished successfully' : 'Failed to replenish fund'),
                      backgroundColor: success ? AppTheme.successGreen : AppTheme.errorRed,
                    ),
                  );
                }
              }
            },
            child: const Text('Replenish'),
          ),
        ],
      ),
    );
  }

  Future<void> _approveExpense(String expenseId) async {
    // Get expense details to check if it's inventory purchase
    final expenses = await _pettyCashService.getExpenses();
    final expense = expenses.firstWhere((e) => e.id == expenseId);
    
    final success = await _pettyCashService.approveExpense(expenseId);
    if (mounted) {
      String message;
      if (success) {
        if (expense.category == 'inventory_purchase' && 
            expense.inventoryItemName != null && 
            expense.quantityPurchased != null) {
          message = 'Expense approved! ${expense.quantityPurchased} ${expense.unit ?? 'pcs'} of ${expense.inventoryItemName} added to Incoming tab for processing';
        } else {
          message = 'Expense approved';
        }
      } else {
        message = 'Failed to approve expense';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success ? AppTheme.successGreen : AppTheme.errorRed,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _rejectExpense(String expenseId) async {
    final success = await _pettyCashService.rejectExpense(expenseId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Expense rejected' : 'Failed to reject expense'),
          backgroundColor: success ? AppTheme.successGreen : AppTheme.errorRed,
        ),
      );
    }
  }

  Future<void> _markAsReimbursed(String expenseId) async {
    final success = await _pettyCashService.markAsReimbursed(expenseId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Expense marked as reimbursed' : 'Failed to mark as reimbursed'),
          backgroundColor: success ? AppTheme.successGreen : AppTheme.errorRed,
        ),
      );
    }
  }

  void _showReconciliationDialog() async {
    final fund = await _pettyCashService.getPettyCashFund();
    if (fund == null) return;

    final systemBalanceCtrl = TextEditingController(text: fund.currentBalance.toStringAsFixed(2));
    final actualCashCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.balance, color: AppTheme.infoBlue, size: 26),
                  SizedBox(width: 8),
                  Text(
                    'Cash Reconciliation',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkGrey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: systemBalanceCtrl,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'System Balance',
                  prefixText: '₱',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: actualCashCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Actual Cash Count',
                  prefixText: '₱',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesCtrl,
                decoration: InputDecoration(
                  labelText: 'Notes (Optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final systemBalance = double.tryParse(systemBalanceCtrl.text);
                      final actualCash = double.tryParse(actualCashCtrl.text);
                      
                      if (systemBalance == null || actualCash == null || actualCash < 0) {
                        return;
                      }

                      final success = await _pettyCashService.createReconciliation(
                        systemBalance: systemBalance,
                        actualCashCount: actualCash,
                        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                      );
                      
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success 
                                  ? 'Reconciliation recorded successfully' 
                                  : 'Failed to record reconciliation'
                            ),
                            backgroundColor: success ? AppTheme.successGreen : AppTheme.errorRed,
                          ),
                        );
                      }
                    },
                    child: const Text('Record'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReconciliationHistoryDialog() async {
    final history = await _pettyCashService.getReconciliationHistory();
    
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.history, color: AppTheme.primaryColor, size: 26),
                  SizedBox(width: 8),
                  Text(
                    'Reconciliation History',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkGrey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: history.isEmpty
                    ? const Center(
                        child: Text(
                          'No reconciliation history yet',
                          style: TextStyle(color: AppTheme.mediumGrey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: history.length,
                        itemBuilder: (context, index) {
                          final rec = history[index];
                          final hasDiscrepancy = rec.hasDiscrepancy;
                          final isShortage = rec.isShortage;
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatDate(rec.reconciledAt),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.mediumGrey,
                                        ),
                                      ),
                                      if (hasDiscrepancy)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isShortage
                                                ? AppTheme.errorRed.withValues(alpha: 0.1)
                                                : AppTheme.successGreen.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: isShortage ? AppTheme.errorRed : AppTheme.successGreen,
                                            ),
                                          ),
                                          child: Text(
                                            isShortage ? 'Shortage' : 'Excess',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: isShortage ? AppTheme.errorRed : AppTheme.successGreen,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'System Balance:',
                                        style: TextStyle(fontSize: 12, color: AppTheme.mediumGrey),
                                      ),
                                      Text(
                                        '₱${rec.systemBalance.toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Actual Cash:',
                                        style: TextStyle(fontSize: 12, color: AppTheme.mediumGrey),
                                      ),
                                      Text(
                                        '₱${rec.actualCashCount.toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                  if (hasDiscrepancy) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Discrepancy:',
                                          style: TextStyle(fontSize: 12, color: AppTheme.mediumGrey),
                                        ),
                                        Text(
                                          '${rec.discrepancy > 0 ? '+' : ''}₱${rec.discrepancy.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isShortage ? AppTheme.errorRed : AppTheme.successGreen,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Text(
                                    'Reconciled by: ${rec.reconciledBy}',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.mediumGrey),
                                  ),
                                  if (rec.notes != null && rec.notes!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Notes: ${rec.notes}',
                                      style: const TextStyle(fontSize: 11, color: AppTheme.mediumGrey),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  void _showSpendingReportDialog() async {
    final report = await _pettyCashService.getSpendingReport();
    final budgets = await _pettyCashService.getAllCategoryBudgets();
    final fund = await _pettyCashService.getPettyCashFund();
    
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.analytics, color: AppTheme.primaryColor, size: 26),
                  SizedBox(width: 8),
                  Text(
                    'Spending Report (Last 30 Days)',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkGrey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildReportRow('Current Balance', '₱${fund?.currentBalance.toStringAsFixed(2) ?? '0.00'}'),
                      _buildReportRow('Total Spent', '₱${(report['total_spent'] as double? ?? 0).toStringAsFixed(2)}'),
                      _buildReportRow('Number of Expenses', '${report['expense_count'] ?? 0}'),
                      _buildReportRow('Average Expense', '₱${(report['average_expense'] as double? ?? 0).toStringAsFixed(2)}'),
                      _buildReportRow('Top Category', '${(report['top_category'] as String? ?? 'N/A').capitalize()}'),
                      _buildReportRow('Top Category Amount', '₱${(report['top_category_amount'] as double? ?? 0).toStringAsFixed(2)}'),
                      const SizedBox(height: 16),
                      const Text(
                        'Category Allocation vs Spent:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.darkGrey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._buildAllocationVsSpentRows(budgets, fund?.currentBalance ?? 0),
                      const SizedBox(height: 16),
                      const Text(
                        'Spending by Category:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.darkGrey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._buildSpendingByCategoryRows(report['spending_by_category'] as Map<String, dynamic>? ?? {}),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.mediumGrey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkGrey,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSpendingByCategoryRows(Map<String, dynamic> spendingByCategory) {
    return spendingByCategory.entries.map((entry) {
      return _buildReportRow(
        entry.key.capitalize(),
        '₱${(entry.value as double).toStringAsFixed(2)}',
      );
    }).toList();
  }

  List<Widget> _buildAllocationVsSpentRows(List<PettyCashCategoryBudget> budgets, double currentBalance) {
    return budgets.map((budget) {
      final allocated = budget.getAllocatedAmount(currentBalance);
      final spent = budget.currentSpent;
      final remaining = allocated - spent;
      
      return _buildReportRow(
        '${budget.category.capitalize()} (${budget.percentage.toStringAsFixed(0)}%)',
        '₱${spent.toStringAsFixed(2)} / ₱${allocated.toStringAsFixed(2)} (₱${remaining.toStringAsFixed(2)} remaining)',
      );
    }).toList();
  }

  void _showBudgetManagementDialog() async {
    final budgets = await _pettyCashService.getAllCategoryBudgets();
    final fund = await _pettyCashService.getPettyCashFund();
    
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet, color: AppTheme.infoBlue, size: 26),
                  SizedBox(width: 8),
                  Text(
                    'Category Allocations',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkGrey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Current Balance: ₱${fund?.currentBalance.toStringAsFixed(2) ?? '0.00'}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.mediumGrey,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: budgets.length,
                  itemBuilder: (context, index) {
                    final budget = budgets[index];
                    final allocatedAmount = budget.getAllocatedAmount(fund?.currentBalance ?? 0);
                    final spentPercentage = budget.spentPercentageOfAllocation(fund?.currentBalance ?? 0);
                    final isNearLimit = budget.isNearLimit(fund?.currentBalance ?? 0);
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  budget.category.capitalize(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                if (isNearLimit)
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    color: AppTheme.warningOrange,
                                    size: 16,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${budget.percentage.toStringAsFixed(0)}% of balance (₱${allocatedAmount.toStringAsFixed(2)})',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.mediumGrey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: spentPercentage / 100,
                              backgroundColor: AppTheme.lightGrey,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isNearLimit
                                    ? AppTheme.warningOrange
                                    : AppTheme.successGreen,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Spent: ₱${budget.currentSpent.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.mediumGrey,
                                  ),
                                ),
                                Text(
                                  '${spentPercentage.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isNearLimit
                                        ? AppTheme.warningOrange
                                        : AppTheme.successGreen,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => _showEditBudgetDialog(budget),
                              icon: const Icon(Icons.edit, size: 14),
                              label: const Text('Edit Allocation'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(32),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditBudgetDialog(PettyCashCategoryBudget budget) {
    final percentageCtrl = TextEditingController(text: budget.percentage.toStringAsFixed(1));

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit ${budget.category.capitalize()} Allocation',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkGrey,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: percentageCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Percentage of Balance (%)',
                  suffixText: '%',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Note: Total allocations should equal 100%',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.mediumGrey,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final percentage = double.tryParse(percentageCtrl.text);
                      if (percentage != null && percentage >= 0 && percentage <= 100) {
                        final success = await _pettyCashService.updateCategoryBudgetPercentage(
                          budget.category,
                          percentage,
                        );
                        if (mounted) {
                          Navigator.pop(context);
                          Navigator.pop(context); // Close budget management dialog
                          _showBudgetManagementDialog(); // Reopen to show updated values
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success ? 'Budget updated successfully' : 'Failed to update budget',
                              ),
                              backgroundColor: success ? AppTheme.successGreen : AppTheme.errorRed,
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return split(' ').map((word) => 
      word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}'
    ).join(' ');
  }
}
