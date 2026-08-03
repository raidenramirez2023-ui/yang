import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/models/petty_cash_model.dart';
import 'package:yang_chow/services/petty_cash_service.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';

class PettyCashExpensePage extends StatefulWidget {
  const PettyCashExpensePage({super.key});

  @override
  State<PettyCashExpensePage> createState() => _PettyCashExpensePageState();
}

class _PettyCashExpensePageState extends State<PettyCashExpensePage> {
  final PettyCashService _pettyCashService = PettyCashService();
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(ResponsiveUtils.isMobile(context) ? 12 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFundBalanceCard(),
                    const SizedBox(height: 16),
                    _buildMyExpensesList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.primaryColor, AppTheme.primaryDark],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _showAddExpenseDialog,
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add_rounded, color: AppTheme.white, size: 28),
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
          colors: [AppTheme.primaryColor, AppTheme.primaryDark],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
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
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
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
                  'Petty Cash Expenses',
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Record your inventory purchases',
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 13,
                    color: Colors.white.withOpacity(0.9),
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

  Widget _buildFundBalanceCard() {
    final isMobile = ResponsiveUtils.isMobile(context);
    return StreamBuilder<PettyCashFund?>(
      stream: _pettyCashService.streamPettyCashFund(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final fund = snapshot.data;
        if (fund == null) {
          return Container(
            padding: EdgeInsets.all(isMobile ? 24 : 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.infoBlue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: AppTheme.infoBlue,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Petty Cash Fund Not Available',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkGrey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please contact your administrator to initialize the petty cash fund.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.mediumGrey,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Container(
          padding: EdgeInsets.all(isMobile ? 20 : 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppTheme.successGreen,
                  size: isMobile ? 28 : 32,
                ),
              ),
              SizedBox(width: isMobile ? 14 : 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Balance',
                      style: TextStyle(
                        fontSize: isMobile ? 13 : 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.mediumGrey,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '₱${fund.currentBalance.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: isMobile ? 26 : 32,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.successGreen,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMyExpensesList() {
    final isMobile = ResponsiveUtils.isMobile(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'My Expenses',
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.darkGrey,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<PettyCashExpense>>(
          stream: _pettyCashService.streamExpenses(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final user = Supabase.instance.client.auth.currentUser;
            final allExpenses = snapshot.data!;
            final myExpenses = allExpenses
                .where((expense) => expense.purchasedBy == user?.email)
                .toList();

            if (myExpenses.isEmpty) {
              return Container(
                padding: EdgeInsets.all(isMobile ? 40 : 48),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[200]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.lightGrey.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.receipt_long_rounded,
                        size: isMobile ? 56 : 64,
                        color: AppTheme.mediumGrey,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No expenses recorded yet',
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkGrey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the + button to add your first expense',
                      style: TextStyle(
                        fontSize: isMobile ? 13 : 14,
                        color: AppTheme.mediumGrey,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: myExpenses.map((expense) => _buildExpenseCard(expense)).toList(),
            );
          },
        ),
      ],
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
            color: Colors.black.withOpacity(0.03),
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
              _buildStatusChip(expense.status),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  expense.description,
                  style: TextStyle(
                    fontSize: isMobile ? 15 : 16,
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
                  fontSize: isMobile ? 17 : 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryColor,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: AppTheme.mediumGrey),
              const SizedBox(width: 4),
              Text(
                _formatDate(expense.expenseDate),
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.mediumGrey,
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.category, size: 16, color: AppTheme.mediumGrey),
              const SizedBox(width: 4),
              Text(
                expense.categoryDisplay,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.mediumGrey,
                ),
              ),
            ],
          ),
          if (expense.isMultiItemExpense) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.inventory_2, size: 16, color: AppTheme.mediumGrey),
                const SizedBox(width: 4),
                const Text(
                  'Items: ',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.mediumGrey,
                  ),
                ),
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: expense.inventoryItems!.map((item) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${item.itemName} x${item.quantity}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ] else if (expense.inventoryItemName != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.inventory_2, size: 16, color: AppTheme.mediumGrey),
                const SizedBox(width: 4),
                Text(
                  expense.inventoryItemName!,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.mediumGrey,
                  ),
                ),
                if (expense.quantityPurchased != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    'x${expense.quantityPurchased}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.mediumGrey,
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (expense.supplier != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.business, size: 16, color: AppTheme.mediumGrey),
                const SizedBox(width: 4),
                Text(
                  expense.supplier!,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.mediumGrey,
                  ),
                ),
              ],
            ),
          ],
          if (expense.receiptImageUrl != null) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                // Show full screen image
                showDialog(
                  context: context,
                  builder: (context) => Dialog(
                    child: Stack(
                      children: [
                        Image.network(
                          expense.receiptImageUrl!,
                          fit: BoxFit.contain,
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: Row(
                children: [
                  Icon(Icons.receipt_long, size: 16, color: AppTheme.primaryColor),
                  const SizedBox(width: 4),
                  Text(
                    'View Receipt',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.primaryColor,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (expense.notes != null && expense.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.note, size: 16, color: AppTheme.mediumGrey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    expense.notes!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.mediumGrey,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (expense.status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _editExpense(expense),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteExpense(expense.id!),
                    icon: const Icon(Icons.delete, size: 16),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorRed,
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

  Widget _buildStatusChip(String status) {
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
        color = AppTheme.infoBlue;
        iconData = Icons.payments_rounded;
        break;
      default:
        color = AppTheme.mediumGrey;
        iconData = Icons.help_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
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
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddExpenseDialog() {
    final descriptionCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final supplierCtrl = TextEditingController();
    final receiptNumberCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    String? selectedCategory;
    List<Map<String, dynamic>> inventoryItems = [];
    List<Map<String, dynamic>> selectedInventoryItems = []; // For multi-select
    dynamic receiptImage; // Use dynamic to support both File (mobile) and XFile (web)
    String? receiptImageUrl;
    Set<String> _tempSelectedIds = {}; // For multi-select in dropdown

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isMobile = ResponsiveUtils.isMobile(context);
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              padding: EdgeInsets.all(isMobile ? 20 : 24),
              constraints: BoxConstraints(
                maxWidth: ResponsiveUtils.isMobile(context)
                    ? double.infinity
                    : 540,
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.add_circle_outline,
                          color: AppTheme.primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Add Expense',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.darkGrey,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category Dropdown
                          DropdownButtonFormField<String>(
                            initialValue: selectedCategory,
                            decoration: InputDecoration(
                              labelText: 'Category',
                              prefixIcon: const Icon(Icons.category_rounded),
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                            items: PettyCashExpense.categories
                                .map((category) => DropdownMenuItem(
                                      value: category,
                                      child: Text(category.split('_').map((word) =>
                                        word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}').join(' ')),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setDialogState(() => selectedCategory = value);

                              // Load inventory items if inventory_purchase is selected
                              if (value == 'inventory_purchase') {
                                _loadInventoryItems().then((items) {
                                  setDialogState(() => inventoryItems = items);
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),

                          // Inventory Item Multi-Select (only for inventory_purchase)
                          if (selectedCategory == 'inventory_purchase') ...[
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.inventory_2_rounded, color: AppTheme.primaryColor),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Select Inventory Items',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.darkGrey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 1, thickness: 1),
                                  Container(
                                    constraints: const BoxConstraints(maxHeight: 200),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: inventoryItems.length,
                                      itemBuilder: (context, index) {
                                        final item = inventoryItems[index];
                                        final isSelected = _tempSelectedIds.contains(item['id'].toString());
                                        final alreadyInList = selectedInventoryItems.any((selected) =>
                                            selected['id'].toString() == item['id'].toString());

                                        return InkWell(
                                          onTap: alreadyInList
                                              ? null
                                              : () {
                                                  setDialogState(() {
                                                    if (isSelected) {
                                                      _tempSelectedIds.remove(item['id'].toString());
                                                    } else {
                                                      _tempSelectedIds.add(item['id'].toString());
                                                    }
                                                  });
                                                },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? AppTheme.primaryColor.withOpacity(0.1)
                                                  : Colors.transparent,
                                            ),
                                            child: Row(
                                              children: [
                                                Checkbox(
                                                  value: isSelected,
                                                  onChanged: alreadyInList
                                                      ? null
                                                      : (value) {
                                                          setDialogState(() {
                                                            if (value == true) {
                                                              _tempSelectedIds.add(item['id'].toString());
                                                            } else {
                                                              _tempSelectedIds.remove(item['id'].toString());
                                                            }
                                                          });
                                                        },
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    item['name'],
                                                    style: TextStyle(
                                                      color: alreadyInList
                                                          ? Colors.grey
                                                          : Colors.black,
                                                      decoration: alreadyInList
                                                          ? TextDecoration.lineThrough
                                                          : null,
                                                    ),
                                                  ),
                                                ),
                                                if (alreadyInList)
                                                  const Icon(
                                                    Icons.check_circle,
                                                    color: AppTheme.successGreen,
                                                    size: 16,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  if (_tempSelectedIds.isNotEmpty) ...[
                                    const Divider(height: 1),
                                    Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          setDialogState(() {
                                            for (var id in _tempSelectedIds) {
                                              final item = inventoryItems.firstWhere(
                                                (i) => i['id'].toString() == id,
                                              );
                                              selectedInventoryItems.add({
                                                'id': item['id'],
                                                'name': item['name'],
                                                'quantity': 1,
                                              });
                                            }
                                            _tempSelectedIds.clear();
                                          });
                                        },
                                        icon: const Icon(Icons.add),
                                        label: Text('Add ${_tempSelectedIds.length} Selected Item${_tempSelectedIds.length > 1 ? 's' : ''}'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.primaryColor,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Selected Items List
                            if (selectedInventoryItems.isNotEmpty) ...[
                              const Text(
                                'Selected Items:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                constraints: const BoxConstraints(maxHeight: 200),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: selectedInventoryItems.length,
                                  itemBuilder: (context, index) {
                                    final item = selectedInventoryItems[index];
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item['name'],
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            SizedBox(
                                              width: 60,
                                              child: TextField(
                                                keyboardType: TextInputType.number,
                                                decoration: const InputDecoration(
                                                  labelText: 'Qty',
                                                  isDense: true,
                                                  contentPadding: EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 8,
                                                  ),
                                                ),
                                                controller: TextEditingController(
                                                  text: item['quantity'].toString(),
                                                )..selection = TextSelection.fromPosition(
                                                    TextPosition(offset: item['quantity'].toString().length)),
                                                onChanged: (value) {
                                                  setDialogState(() {
                                                    selectedInventoryItems[index]['quantity'] =
                                                        int.tryParse(value) ?? 1;
                                                  });
                                                },
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.digitsOnly,
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: const Icon(Icons.remove_circle_outline),
                                              color: AppTheme.errorRed,
                                              onPressed: () {
                                                setDialogState(() {
                                                  selectedInventoryItems.removeAt(index);
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ],

                          // Description
                          TextField(
                            controller: descriptionCtrl,
                            decoration: InputDecoration(
                              labelText: 'Description',
                              prefixIcon: const Icon(Icons.description_rounded),
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                            maxLength: 200,
                          ),
                          const SizedBox(height: 16),

                          // Amount
                          TextField(
                            controller: amountCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Amount (₱)',
                              prefixText: '₱',
                              prefixIcon: const Icon(Icons.payments_rounded),
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Supplier
                          TextField(
                            controller: supplierCtrl,
                            decoration: InputDecoration(
                              labelText: 'Supplier (Optional)',
                              prefixIcon: const Icon(Icons.business_rounded),
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Receipt Image Upload
                          Container(
                            width: double.infinity,
                            height: 180,
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              border: Border.all(
                                color: receiptImage != null
                                    ? AppTheme.primaryColor
                                    : Colors.grey[300]!,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: receiptImage != null
                                ? Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: kIsWeb
                                            ? Image.network(
                                                receiptImage is XFile ? receiptImage.path : receiptImage.toString(),
                                                width: double.infinity,
                                                height: double.infinity,
                                                fit: BoxFit.cover,
                                              )
                                            : Image.file(
                                                receiptImage as File,
                                                width: double.infinity,
                                                height: double.infinity,
                                                fit: BoxFit.cover,
                                              ),
                                      ),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: IconButton(
                                          icon: const Icon(Icons.close),
                                          color: Colors.white,
                                          onPressed: () {
                                            setDialogState(() {
                                              receiptImage = null;
                                              receiptImageUrl = null;
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  )
                                : SingleChildScrollView(
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.receipt_long,
                                            size: 40,
                                            color: AppTheme.mediumGrey,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Upload Receipt Image',
                                            style: TextStyle(
                                              color: AppTheme.mediumGrey,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          ElevatedButton.icon(
                                            onPressed: () async {
                                              final picker = ImagePicker();
                                              final pickedFile = await picker.pickImage(
                                                source: ImageSource.camera,
                                                imageQuality: 80,
                                              );
                                              if (pickedFile != null) {
                                                setDialogState(() {
                                                  receiptImage = pickedFile;
                                                });
                                              }
                                            },
                                            icon: const Icon(Icons.camera_alt, size: 16),
                                            label: const Text('Take Photo', style: TextStyle(fontSize: 12)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.primaryColor,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          TextButton.icon(
                                            onPressed: () async {
                                              final picker = ImagePicker();
                                              final pickedFile = await picker.pickImage(
                                                source: ImageSource.gallery,
                                                imageQuality: 80,
                                              );
                                              if (pickedFile != null) {
                                                setDialogState(() {
                                                  receiptImage = pickedFile;
                                                });
                                              }
                                            },
                                            icon: const Icon(Icons.photo_library, size: 16),
                                            label: const Text('Choose from Gallery', style: TextStyle(fontSize: 12)),
                                            style: TextButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 16),

                          // Receipt Number
                          TextField(
                            controller: receiptNumberCtrl,
                            decoration: InputDecoration(
                              labelText: 'Receipt Number (Optional)',
                              prefixIcon: const Icon(Icons.receipt_long_rounded),
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Notes
                          TextField(
                            controller: notesCtrl,
                            decoration: InputDecoration(
                              labelText: 'Notes (Optional)',
                              prefixIcon: const Icon(Icons.note_rounded),
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                            maxLines: 3,
                            maxLength: 500,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          if (descriptionCtrl.text.isEmpty ||
                              amountCtrl.text.isEmpty ||
                              selectedCategory == null) {
                            return;
                          }

                          // Validate inventory purchase requires at least one item
                          if (selectedCategory == 'inventory_purchase' &&
                              selectedInventoryItems.isEmpty &&
                              _tempSelectedIds.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please select at least one inventory item'),
                                backgroundColor: AppTheme.errorRed,
                              ),
                            );
                            return;
                          }

                          // Add any temp selected items before saving
                          if (_tempSelectedIds.isNotEmpty) {
                            for (var id in _tempSelectedIds) {
                              final item = inventoryItems.firstWhere(
                                (i) => i['id'].toString() == id,
                              );
                              selectedInventoryItems.add({
                                'id': item['id'],
                                'name': item['name'],
                                'quantity': 1,
                              });
                            }
                            _tempSelectedIds.clear();
                          }

                          final amount = double.tryParse(amountCtrl.text);
                          if (amount == null || amount <= 0) {
                            return;
                          }

                          final user = Supabase.instance.client.auth.currentUser;
                          if (user == null) return;

                          // Upload receipt image if provided
                          if (receiptImage != null) {
                            try {
                              final fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
                              final fileBytes = kIsWeb
                                  ? await (receiptImage as XFile).readAsBytes()
                                  : await (receiptImage as File).readAsBytes();

                              await Supabase.instance.client.storage
                                  .from('petty_cash_receipts')
                                  .uploadBinary(fileName, fileBytes);

                              receiptImageUrl = Supabase.instance.client.storage
                                  .from('petty_cash_receipts')
                                  .getPublicUrl(fileName);
                            } catch (e) {
                              debugPrint('Error uploading receipt: $e');
                              // Continue without image if upload fails
                            }
                          }

                          // Convert selected inventory items to InventoryExpenseItem list
                          List<InventoryExpenseItem>? inventoryExpenseItems;
                          String? legacyInventoryItemId;
                          String? legacyInventoryItemName;
                          int? legacyQuantityPurchased;

                          if (selectedInventoryItems.isNotEmpty) {
                            inventoryExpenseItems = selectedInventoryItems.map((item) {
                              return InventoryExpenseItem(
                                itemId: item['id']?.toString() ?? '',
                                itemName: item['name']?.toString() ?? 'Unknown',
                                quantity: item['quantity'] as int? ?? 1,
                              );
                            }).toList();

                            // Always populate legacy fields with first item (for backward compatibility)
                            legacyInventoryItemId = selectedInventoryItems[0]['id']?.toString();
                            legacyInventoryItemName = selectedInventoryItems[0]['name']?.toString();
                            legacyQuantityPurchased = selectedInventoryItems[0]['quantity'] as int?;
                          }

                          final expense = PettyCashExpense(
                            expenseDate: DateTime.now(),
                            description: descriptionCtrl.text.trim(),
                            amount: amount,
                            category: selectedCategory!,
                            purchasedBy: user.email!,
                            inventoryItemId: legacyInventoryItemId,
                            inventoryItemName: legacyInventoryItemName,
                            quantityPurchased: legacyQuantityPurchased,
                            inventoryItems: inventoryExpenseItems,
                            supplier: supplierCtrl.text.trim().isEmpty
                                ? null
                                : supplierCtrl.text.trim(),
                            receiptImageUrl: receiptImageUrl,
                            receiptNumber: receiptNumberCtrl.text.trim().isEmpty
                                ? null
                                : receiptNumberCtrl.text.trim(),
                            status: 'pending',
                            notes: notesCtrl.text.trim().isEmpty
                                ? null
                                : notesCtrl.text.trim(),
                            createdAt: DateTime.now(),
                            updatedAt: DateTime.now(),
                          );

                          final success = await _pettyCashService.createExpense(expense);
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  success
                                      ? 'Expense recorded successfully'
                                      : 'Failed to record expense. Check available balance.',
                                ),
                                backgroundColor: success
                                    ? AppTheme.successGreen
                                    : AppTheme.errorRed,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadInventoryItems() async {
    try {
      final response = await Supabase.instance.client
          .from('inventory')
          .select('id, name')
          .order('name');
      return response;
    } catch (e) {
      return [];
    }
  }

  void _editExpense(PettyCashExpense expense) {
    final descriptionCtrl = TextEditingController(text: expense.description);
    final amountCtrl = TextEditingController(text: expense.amount.toString());
    final supplierCtrl = TextEditingController(text: expense.supplier ?? '');
    final receiptNumberCtrl = TextEditingController(text: expense.receiptNumber ?? '');
    final notesCtrl = TextEditingController(text: expense.notes ?? '');

    String? selectedCategory = expense.category;
    List<Map<String, dynamic>> inventoryItems = [];
    List<Map<String, dynamic>> selectedInventoryItems = [];
    Set<String> _tempSelectedIds = {}; // For multi-select in dropdown

    // Load inventory items if needed
    if (expense.category == 'inventory_purchase') {
      _loadInventoryItems().then((items) {
        setState(() {
          inventoryItems = items;
          // Initialize selected items from existing expense
          if (expense.inventoryItems != null && expense.inventoryItems!.isNotEmpty) {
            selectedInventoryItems = expense.inventoryItems!.map((item) {
              return {
                'id': item.itemId,
                'name': item.itemName,
                'quantity': item.quantity,
              };
            }).toList();
          } else if (expense.inventoryItemId != null) {
            // Legacy single item support
            selectedInventoryItems = [{
              'id': expense.inventoryItemId!,
              'name': expense.inventoryItemName ?? 'Unknown',
              'quantity': expense.quantityPurchased ?? 1,
            }];
          }
        });
      });
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isMobile = ResponsiveUtils.isMobile(context);
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              padding: EdgeInsets.all(isMobile ? 20 : 24),
              constraints: BoxConstraints(
                maxWidth: ResponsiveUtils.isMobile(context)
                    ? double.infinity
                    : 540,
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.edit_outlined,
                          color: AppTheme.primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Edit Expense',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.darkGrey,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category Dropdown (read-only for editing)
                          DropdownButtonFormField<String>(
                            initialValue: selectedCategory,
                            decoration: InputDecoration(
                              labelText: 'Category',
                              prefixIcon: const Icon(Icons.category_rounded),
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                            items: PettyCashExpense.categories
                                .map((category) => DropdownMenuItem(
                                      value: category,
                                      child: Text(category.split('_').map((word) =>
                                        word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}').join(' ')),
                                    ))
                                .toList(),
                            onChanged: null, // Cannot change category on edit
                          ),
                          const SizedBox(height: 16),

                          // Inventory Item Multi-Select (only for inventory_purchase)
                          if (selectedCategory == 'inventory_purchase') ...[
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.inventory_2_rounded, color: AppTheme.primaryColor),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Select Inventory Items',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.darkGrey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 1, thickness: 1),
                                  Container(
                                    constraints: const BoxConstraints(maxHeight: 200),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: inventoryItems.length,
                                      itemBuilder: (context, index) {
                                        final item = inventoryItems[index];
                                        final isSelected = _tempSelectedIds.contains(item['id'].toString());
                                        final alreadyInList = selectedInventoryItems.any((selected) =>
                                            selected['id'].toString() == item['id'].toString());

                                        return InkWell(
                                          onTap: alreadyInList
                                              ? null
                                              : () {
                                                  setDialogState(() {
                                                    if (isSelected) {
                                                      _tempSelectedIds.remove(item['id'].toString());
                                                    } else {
                                                      _tempSelectedIds.add(item['id'].toString());
                                                    }
                                                  });
                                                },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? AppTheme.primaryColor.withOpacity(0.1)
                                                  : Colors.transparent,
                                            ),
                                            child: Row(
                                              children: [
                                                Checkbox(
                                                  value: isSelected,
                                                  onChanged: alreadyInList
                                                      ? null
                                                      : (value) {
                                                          setDialogState(() {
                                                            if (value == true) {
                                                              _tempSelectedIds.add(item['id'].toString());
                                                            } else {
                                                              _tempSelectedIds.remove(item['id'].toString());
                                                            }
                                                          });
                                                        },
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    item['name'],
                                                    style: TextStyle(
                                                      color: alreadyInList
                                                          ? Colors.grey
                                                          : Colors.black,
                                                      decoration: alreadyInList
                                                          ? TextDecoration.lineThrough
                                                          : null,
                                                    ),
                                                  ),
                                                ),
                                                if (alreadyInList)
                                                  const Icon(
                                                    Icons.check_circle,
                                                    color: AppTheme.successGreen,
                                                    size: 16,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  if (_tempSelectedIds.isNotEmpty) ...[
                                    const Divider(height: 1),
                                    Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          setDialogState(() {
                                            for (var id in _tempSelectedIds) {
                                              final item = inventoryItems.firstWhere(
                                                (i) => i['id'].toString() == id,
                                              );
                                              selectedInventoryItems.add({
                                                'id': item['id'],
                                                'name': item['name'],
                                                'quantity': 1,
                                              });
                                            }
                                            _tempSelectedIds.clear();
                                          });
                                        },
                                        icon: const Icon(Icons.add),
                                        label: Text('Add ${_tempSelectedIds.length} Selected Item${_tempSelectedIds.length > 1 ? 's' : ''}'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.primaryColor,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Selected Items List
                            if (selectedInventoryItems.isNotEmpty) ...[
                              const Text(
                                'Selected Items:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                constraints: const BoxConstraints(maxHeight: 200),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: selectedInventoryItems.length,
                                  itemBuilder: (context, index) {
                                    final item = selectedInventoryItems[index];
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item['name'],
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            SizedBox(
                                              width: 60,
                                              child: TextField(
                                                keyboardType: TextInputType.number,
                                                decoration: const InputDecoration(
                                                  labelText: 'Qty',
                                                  isDense: true,
                                                  contentPadding: EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 8,
                                                  ),
                                                ),
                                                controller: TextEditingController(
                                                  text: item['quantity'].toString(),
                                                )..selection = TextSelection.fromPosition(
                                                    TextPosition(offset: item['quantity'].toString().length)),
                                                onChanged: (value) {
                                                  setDialogState(() {
                                                    selectedInventoryItems[index]['quantity'] =
                                                        int.tryParse(value) ?? 1;
                                                  });
                                                },
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.digitsOnly,
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: const Icon(Icons.remove_circle_outline),
                                              color: AppTheme.errorRed,
                                              onPressed: () {
                                                setDialogState(() {
                                                  selectedInventoryItems.removeAt(index);
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ],

                          // Description
                          TextField(
                            controller: descriptionCtrl,
                            decoration: InputDecoration(
                              labelText: 'Description',
                              prefixIcon: const Icon(Icons.description_rounded),
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                            maxLength: 200,
                          ),
                          const SizedBox(height: 16),

                          // Amount
                          TextField(
                            controller: amountCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Amount (₱)',
                              prefixText: '₱',
                              prefixIcon: const Icon(Icons.payments_rounded),
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Supplier
                          TextField(
                            controller: supplierCtrl,
                            decoration: InputDecoration(
                              labelText: 'Supplier (Optional)',
                              prefixIcon: const Icon(Icons.business_rounded),
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Receipt Number
                          TextField(
                            controller: receiptNumberCtrl,
                            decoration: InputDecoration(
                              labelText: 'Receipt Number (Optional)',
                              prefixIcon: const Icon(Icons.receipt_long_rounded),
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Notes
                          TextField(
                            controller: notesCtrl,
                            decoration: InputDecoration(
                              labelText: 'Notes (Optional)',
                              prefixIcon: const Icon(Icons.note_rounded),
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                            maxLines: 3,
                            maxLength: 500,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          if (descriptionCtrl.text.isEmpty ||
                              amountCtrl.text.isEmpty) {
                            return;
                          }

                          // Validate inventory purchase requires at least one item
                          if (selectedCategory == 'inventory_purchase' &&
                              selectedInventoryItems.isEmpty &&
                              _tempSelectedIds.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please select at least one inventory item'),
                                backgroundColor: AppTheme.errorRed,
                              ),
                            );
                            return;
                          }

                          // Add any temp selected items before saving
                          if (_tempSelectedIds.isNotEmpty) {
                            for (var id in _tempSelectedIds) {
                              final item = inventoryItems.firstWhere(
                                (i) => i['id'].toString() == id,
                              );
                              selectedInventoryItems.add({
                                'id': item['id'],
                                'name': item['name'],
                                'quantity': 1,
                              });
                            }
                            _tempSelectedIds.clear();
                          }

                          final amount = double.tryParse(amountCtrl.text);
                          if (amount == null || amount <= 0) {
                            return;
                          }

                          // Convert selected inventory items to InventoryExpenseItem list
                          List<InventoryExpenseItem>? inventoryExpenseItems;
                          String? legacyInventoryItemId;
                          String? legacyInventoryItemName;
                          int? legacyQuantityPurchased;

                          if (selectedInventoryItems.isNotEmpty) {
                            inventoryExpenseItems = selectedInventoryItems.map((item) {
                              return InventoryExpenseItem(
                                itemId: item['id']?.toString() ?? '',
                                itemName: item['name']?.toString() ?? 'Unknown',
                                quantity: item['quantity'] as int? ?? 1,
                              );
                            }).toList();

                            // Always populate legacy fields with first item (for backward compatibility)
                            legacyInventoryItemId = selectedInventoryItems[0]['id']?.toString();
                            legacyInventoryItemName = selectedInventoryItems[0]['name']?.toString();
                            legacyQuantityPurchased = selectedInventoryItems[0]['quantity'] as int?;
                          }

                          final updatedExpense = PettyCashExpense(
                            id: expense.id,
                            expenseDate: expense.expenseDate,
                            description: descriptionCtrl.text.trim(),
                            amount: amount,
                            category: selectedCategory,
                            purchasedBy: expense.purchasedBy,
                            inventoryItemId: legacyInventoryItemId,
                            inventoryItemName: legacyInventoryItemName,
                            quantityPurchased: legacyQuantityPurchased,
                            inventoryItems: inventoryExpenseItems,
                            supplier: supplierCtrl.text.trim().isEmpty
                                ? null
                                : supplierCtrl.text.trim(),
                            receiptNumber: receiptNumberCtrl.text.trim().isEmpty
                                ? null
                                : receiptNumberCtrl.text.trim(),
                            status: expense.status,
                            approvedBy: expense.approvedBy,
                            approvedAt: expense.approvedAt,
                            notes: notesCtrl.text.trim().isEmpty
                                ? null
                                : notesCtrl.text.trim(),
                            createdAt: expense.createdAt,
                            updatedAt: DateTime.now(),
                          );

                          final success = await _pettyCashService.updateExpense(updatedExpense);
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  success
                                      ? 'Expense updated successfully'
                                      : 'Failed to update expense',
                                ),
                                backgroundColor: success
                                    ? AppTheme.successGreen
                                    : AppTheme.errorRed,
                              ),
                            );
                          }
                        },
                        child: const Text('Update'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteExpense(String expenseId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _pettyCashService.deleteExpense(expenseId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Expense deleted successfully'
                  : 'Failed to delete expense',
            ),
            backgroundColor: success
                ? AppTheme.successGreen
                : AppTheme.errorRed,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}

extension StringExtension on String {
  String capitalize() {
    return split(' ').map((word) => 
      word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}'
    ).join(' ');
  }
}
