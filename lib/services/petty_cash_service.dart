import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/petty_cash_model.dart';

class PettyCashService {
  static final PettyCashService _instance = PettyCashService._internal();
  factory PettyCashService() => _instance;
  PettyCashService._internal();

  final _supabase = Supabase.instance.client;

  // Get the petty cash fund
  Future<PettyCashFund?> getPettyCashFund() async {
    try {
      final response = await _supabase
          .from('petty_cash_fund')
          .select()
          .eq('fund_name', 'Main Petty Cash')
          .maybeSingle();

      if (response == null) return null;
      return PettyCashFund.fromJson(response);
    } catch (e) {
      debugPrint('Error getting petty cash fund: $e');
      return null;
    }
  }

  // Initialize petty cash fund with initial balance
  Future<bool> initializePettyCashFund(double initialBalance) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      // Check if fund already exists
      final existingFund = await getPettyCashFund();
      if (existingFund != null) {
        // Update existing fund
        await _supabase
            .from('petty_cash_fund')
            .update({
              'current_balance': initialBalance,
              'initial_balance': initialBalance,
              'last_replenished_at': DateTime.now().toUtc().toIso8601String(),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', existingFund.id!);
      } else {
        // Create new fund
        await _supabase.from('petty_cash_fund').insert({
          'fund_name': 'Main Petty Cash',
          'current_balance': initialBalance,
          'initial_balance': initialBalance,
          'last_replenished_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
      return true;
    } catch (e) {
      debugPrint('Error initializing petty cash fund: $e');
      return false;
    }
  }

  // Directly set/override petty cash fund amount and ceiling
  Future<bool> setPettyCashFundAmount({
    required double targetBalance,
    double? targetCeiling,
    double? lowBalanceThreshold,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final existingFund = await getPettyCashFund();
      final now = DateTime.now().toUtc().toIso8601String();
      final ceiling = targetCeiling ?? targetBalance;

      final updateData = <String, dynamic>{
        'current_balance': targetBalance,
        'initial_balance': ceiling,
        'last_replenished_at': now,
        'updated_at': now,
      };

      if (lowBalanceThreshold != null && lowBalanceThreshold > 0) {
        updateData['low_balance_threshold'] = lowBalanceThreshold;
      }

      if (existingFund != null) {
        await _supabase
            .from('petty_cash_fund')
            .update(updateData)
            .eq('id', existingFund.id!);
      } else {
        await _supabase.from('petty_cash_fund').insert({
          'fund_name': 'Main Petty Cash',
          'current_balance': targetBalance,
          'initial_balance': ceiling,
          'last_replenished_at': now,
          if (lowBalanceThreshold != null) 'low_balance_threshold': lowBalanceThreshold,
        });
      }
      return true;
    } catch (e) {
      debugPrint('Error setting petty cash fund amount: $e');
      return false;
    }
  }

  // Replenish petty cash fund
  Future<bool> replenishPettyCashFund(double amount) async {
    try {
      final fund = await getPettyCashFund();
      if (fund == null) return false;

      final newBalance = fund.currentBalance + amount;
      final newInitial = (fund.initialBalance <= 0 || fund.initialBalance < newBalance)
          ? newBalance
          : (fund.initialBalance + amount);

      await _supabase
          .from('petty_cash_fund')
          .update({
            'current_balance': newBalance,
            'initial_balance': newInitial,
            'last_replenished_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', fund.id!);

      return true;
    } catch (e) {
      debugPrint('Error replenishing petty cash fund: $e');
      return false;
    }
  }

  // Create a new expense
  Future<bool> createExpense(PettyCashExpense expense) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        debugPrint('User not authenticated');
        return false;
      }

      // Check if fund exists (balance check not needed since deduction happens on approval)
      final fund = await getPettyCashFund();
      if (fund == null) {
        debugPrint('Petty cash fund not initialized');
        return false;
      }

      debugPrint('Creating expense: ${expense.description}, Amount: ${expense.amount}');

      // Create the expense (balance will be deducted on approval)
      debugPrint('Inserting expense...');
      await _supabase.from('petty_cash_expenses').insert(expense.toJson());
      debugPrint('Expense inserted successfully');

      // Note: Items will ONLY enter stock_transactions when approved by Admin!
      return true;
    } catch (e) {
      debugPrint('Error creating expense: $e');
      return false;
    }
  }

  // Get all expenses
  Future<List<PettyCashExpense>> getExpenses({
    String? status,
    String? category,
    String? purchasedBy,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _supabase.from('petty_cash_expenses').select();

      if (status != null) {
        query = query.eq('status', status);
      }
      if (category != null) {
        query = query.eq('category', category);
      }
      if (purchasedBy != null) {
        query = query.eq('purchased_by', purchasedBy);
      }
      if (startDate != null) {
        query = query.gte('expense_date', startDate.toUtc().toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('expense_date', endDate.toUtc().toIso8601String());
      }

      final response = await query.order('expense_date', ascending: false);
      return response.map((e) => PettyCashExpense.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error getting expenses: $e');
      return [];
    }
  }

  // Get expenses for current user
  Future<List<PettyCashExpense>> getMyExpenses() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      return await getExpenses(purchasedBy: user.email);
    } catch (e) {
      debugPrint('Error getting my expenses: $e');
      return [];
    }
  }

  // Approve an expense
  Future<bool> approveExpense(String expenseId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      // Get expense details to deduct the amount
      final expense = await _supabase
          .from('petty_cash_expenses')
          .select()
          .eq('id', expenseId)
          .maybeSingle();

      if (expense == null) return false;

      final notes = (expense['notes'] ?? '').toString().toUpperCase();
      final desc = (expense['description'] ?? '').toString().toUpperCase();
      final isAbono = notes.contains('ABONO') || desc.contains('ABONO');

      // Deduct the amount from petty cash fund ONLY if it is NOT an Abono expense
      // (For Abono expenses, cash is only deducted when actually reimbursed to staff)
      if (!isAbono) {
        final fund = await getPettyCashFund();
        if (fund == null) {
          debugPrint('Petty cash fund not initialized');
          return false;
        }

        if (fund.currentBalance < (expense['amount'] as num)) {
          debugPrint('Insufficient petty cash fund balance to approve this expense');
          return false;
        }

        final newBalance = fund.currentBalance - (expense['amount'] as num);
        await _supabase
            .from('petty_cash_fund')
            .update({
              'current_balance': newBalance,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', fund.id!);
      }

      // Update expense status
      await _supabase
          .from('petty_cash_expenses')
          .update({
            'status': 'approved',
            'approved_by': user.email,
            'approved_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', expenseId);

      // Update category budget
      await updateCategorySpent(expense['category'], expense['amount']);

      // Ensure item is in stock_transactions ONLY UPON ADMIN APPROVAL!
      final approvedExpense = Map<String, dynamic>.from(expense);
      approvedExpense['status'] = 'approved';
      await _addExpenseToStockTransactionsIfApplicable(approvedExpense, user.email ?? 'admin');

      return true;
    } catch (e) {
      debugPrint('Error approving expense: $e');
      return false;
    }
  }

  // Reject an expense
  Future<bool> rejectExpense(String expenseId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      // Update expense status (no refund needed since balance wasn't deducted on creation)
      await _supabase
          .from('petty_cash_expenses')
          .update({
            'status': 'rejected',
            'approved_by': user.email,
            'approved_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', expenseId);

      return true;
    } catch (e) {
      debugPrint('Error rejecting expense: $e');
      return false;
    }
  }

  // Mark expense as reimbursed
  Future<bool> markAsReimbursed(String expenseId) async {
    try {
      final user = _supabase.auth.currentUser;
      final expenseRes = await _supabase
          .from('petty_cash_expenses')
          .select()
          .eq('id', expenseId)
          .maybeSingle();

      if (expenseRes == null) return false;

      // Prevent duplicate reimbursement processing
      if (expenseRes['status'] == 'reimbursed') {
        return true;
      }

      final notes = (expenseRes['notes'] ?? '').toString().toUpperCase();
      final desc = (expenseRes['description'] ?? '').toString().toUpperCase();
      final isAbono = notes.contains('ABONO') || desc.contains('ABONO');

      // If this was an Abono expense, now is the time to deduct from the petty cash fund as cash is handed to staff
      if (isAbono) {
        final fund = await getPettyCashFund();
        if (fund != null) {
          final newBalance = fund.currentBalance - (expenseRes['amount'] as num);
          await _supabase
              .from('petty_cash_fund')
              .update({
                'current_balance': newBalance,
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('id', fund.id!);
        }
      }

      await _supabase
          .from('petty_cash_expenses')
          .update({
            'status': 'reimbursed',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', expenseId);

      await _addExpenseToStockTransactionsIfApplicable(expenseRes, user?.email ?? 'admin');

      return true;
    } catch (e) {
      debugPrint('Error marking expense as reimbursed: $e');
      return false;
    }
  }

  Future<void> _addExpenseToStockTransactionsIfApplicable(Map<String, dynamic> expense, String userEmail) async {
    try {
      final status = (expense['status'] ?? '').toString().toLowerCase().trim();
      // CRITICAL: Must be approved by Admin first!
      if (status != 'approved' && status != 'reimbursed') {
        debugPrint('Skipping stock transaction: expense status is "$status", must be "approved" by admin');
        return;
      }

      final category = (expense['category'] ?? '').toString().toLowerCase().trim();
      // Only inventory_purchase expenses should create stock transactions / enter petty cash inventory tab
      if (category != 'inventory_purchase') {
        debugPrint('Skipping stock transaction: category is "$category", only "inventory_purchase" is allowed');
        return;
      }

      final supplier = (expense['supplier'] as String?)?.trim().isNotEmpty == true
          ? (expense['supplier'] as String).trim()
          : 'Market';
      final processedBy = (expense['purchased_by'] as String?)?.trim().isNotEmpty == true
          ? (expense['purchased_by'] as String).trim()
          : (userEmail.isNotEmpty ? userEmail : 'pagsanjaninv@gmail.com');

      // 1. Multi-items format from "Link Inventory Items"
      dynamic rawItems = expense['inventory_items'];
      if (rawItems is String && rawItems.trim().isNotEmpty) {
        try {
          rawItems = jsonDecode(rawItems);
        } catch (_) {}
      }

      bool itemsAdded = false;
      if (rawItems != null && rawItems is List && rawItems.isNotEmpty) {
        for (var item in rawItems) {
          final name = (item['item_name'] ?? item['name'] ?? '').toString().trim();
          final qty = (item['quantity'] as num?)?.toInt() ?? 1;
          final unit = (item['unit'] as String?) ?? 'pcs';
          if (name.isNotEmpty) {
            await addInventoryToStockTransactions(name, qty, unit, supplier, processedBy);
            itemsAdded = true;
          }
        }
      }

      // 2. Single item field format (fallback)
      if (!itemsAdded) {
        if (expense['inventory_item_name'] != null && expense['inventory_item_name'].toString().trim().isNotEmpty) {
          final name = expense['inventory_item_name'].toString().trim();
          final qty = (expense['quantity_purchased'] as num?)?.toInt() ?? 1;
          final unit = (expense['unit'] as String?) ?? 'pcs';
          await addInventoryToStockTransactions(name, qty, unit, supplier, processedBy);
        }
        // 3. Item from description (fallback)
        else if (expense['description'] != null && expense['description'].toString().trim().isNotEmpty) {
          final desc = expense['description'].toString().trim();
          await addInventoryToStockTransactions(desc, 1, 'pcs', supplier, processedBy);
        }
      }
    } catch (e) {
      debugPrint('Error in _addExpenseToStockTransactionsIfApplicable: $e');
    }
  }

  Future<void> syncMissingPettyCashToStockTransactions() async {
    try {
      // 1. Fetch all approved/reimbursed inventory_purchase expenses
      final inventoryExpenses = await _supabase
          .from('petty_cash_expenses')
          .select()
          .eq('category', 'inventory_purchase')
          .inFilter('status', ['approved', 'reimbursed']);

      // 2. Fetch all existing incoming stock transactions
      final existingTx = await _supabase
          .from('stock_transactions')
          .select('id, item_name, purpose')
          .eq('transaction_type', 'incoming');

      final Set<String> existingStockItemNames = {};
      for (var tx in existingTx) {
        final name = (tx['item_name'] ?? '').toString().toLowerCase().trim();
        final purpose = (tx['purpose'] ?? '').toString();
        if (purpose == 'Petty Cash Purchase' ||
            purpose == 'Petty Cash Purchase (Transferred)' ||
            purpose == 'Transferred to Storage') {
          if (name.isNotEmpty) existingStockItemNames.add(name);
        }
      }

      // 3. For any approved inventory_purchase expense whose items are missing from stock_transactions, insert them!
      for (var exp in inventoryExpenses) {
        final supplier = (exp['supplier'] as String?)?.trim().isNotEmpty == true
            ? (exp['supplier'] as String).trim()
            : 'Market';
        final processedBy = (exp['purchased_by'] as String?)?.trim().isNotEmpty == true
            ? (exp['purchased_by'] as String).trim()
            : 'pagsanjaninv@gmail.com';

        dynamic rawItems = exp['inventory_items'];
        if (rawItems is String && rawItems.trim().isNotEmpty) {
          try {
            rawItems = jsonDecode(rawItems);
          } catch (_) {}
        }

        bool itemsProcessed = false;
        if (rawItems != null && rawItems is List && rawItems.isNotEmpty) {
          for (var item in rawItems) {
            final name = (item['item_name'] ?? item['name'] ?? '').toString().trim();
            final qty = (item['quantity'] as num?)?.toInt() ?? 1;
            final unit = (item['unit'] as String?) ?? 'pcs';
            if (name.isNotEmpty && !existingStockItemNames.contains(name.toLowerCase())) {
              await addInventoryToStockTransactions(name, qty, unit, supplier, processedBy);
              existingStockItemNames.add(name.toLowerCase());
            }
            itemsProcessed = true;
          }
        }

        if (!itemsProcessed) {
          final singleName = (exp['inventory_item_name'] ?? '').toString().trim();
          if (singleName.isNotEmpty && !existingStockItemNames.contains(singleName.toLowerCase())) {
            final qty = (exp['quantity_purchased'] as num?)?.toInt() ?? 1;
            final unit = (exp['unit'] as String?) ?? 'pcs';
            await addInventoryToStockTransactions(singleName, qty, unit, supplier, processedBy);
            existingStockItemNames.add(singleName.toLowerCase());
          }
        }
      }
    } catch (e) {
      debugPrint('Error syncing missing petty cash to stock transactions: $e');
    }
  }

  // Update expense
  Future<bool> updateExpense(PettyCashExpense expense) async {
    try {
      if (expense.id == null) return false;

      await _supabase
          .from('petty_cash_expenses')
          .update(expense.toJson())
          .eq('id', expense.id!);

      return true;
    } catch (e) {
      debugPrint('Error updating expense: $e');
      return false;
    }
  }

  // Delete expense
  Future<bool> deleteExpense(String expenseId) async {
    try {
      // Get expense details to refund the amount
      final expense = await _supabase
          .from('petty_cash_expenses')
          .select()
          .eq('id', expenseId)
          .maybeSingle();

      if (expense == null) return false;

      // Only refund to petty cash fund if this expense actually deducted money:
      // - Standard expense (not abono) deducted when approved or reimbursed
      // - Abono expense deducted only when reimbursed
      final status = (expense['status'] ?? '').toString().toLowerCase();
      final notes = (expense['notes'] ?? '').toString().toUpperCase();
      final desc = (expense['description'] ?? '').toString().toUpperCase();
      final isAbono = notes.contains('ABONO') || desc.contains('ABONO');

      final wasDeducted = (!isAbono && (status == 'approved' || status == 'reimbursed')) ||
                          (isAbono && status == 'reimbursed');

      if (wasDeducted) {
        final fund = await getPettyCashFund();
        if (fund != null) {
          final newBalance = fund.currentBalance + (expense['amount'] as num);
          await _supabase
              .from('petty_cash_fund')
              .update({
                'current_balance': newBalance,
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('id', fund.id!);
        }
      }

      // Delete the expense
      await _supabase.from('petty_cash_expenses').delete().eq('id', expenseId);

      return true;
    } catch (e) {
      debugPrint('Error deleting expense: $e');
      return false;
    }
  }

  // Archive or unarchive an expense
  Future<bool> archiveExpense(String expenseId, {bool archive = true}) async {
    try {
      final res = await _supabase
          .from('petty_cash_expenses')
          .select('notes')
          .eq('id', expenseId)
          .maybeSingle();

      String currentNotes = (res?['notes'] ?? '').toString();
      String newNotes;
      if (archive) {
        if (!currentNotes.contains('[ARCHIVED]')) {
          newNotes = '$currentNotes [ARCHIVED]'.trim();
        } else {
          newNotes = currentNotes;
        }
      } else {
        newNotes = currentNotes.replaceAll('[ARCHIVED]', '').trim();
      }

      final updateData = <String, dynamic>{
        'notes': newNotes.isEmpty ? null : newNotes,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      try {
        await _supabase
            .from('petty_cash_expenses')
            .update({...updateData, 'is_archived': archive})
            .eq('id', expenseId);
      } catch (_) {
        await _supabase
            .from('petty_cash_expenses')
            .update(updateData)
            .eq('id', expenseId);
      }
      return true;
    } catch (e) {
      debugPrint('Error archiving expense: $e');
      return false;
    }
  }

  // Get expense statistics
  Future<Map<String, dynamic>> getExpenseStatistics() async {
    try {
      final expenses = await getExpenses();
      
      double totalExpenses = 0;
      double pendingAmount = 0;
      double approvedAmount = 0;
      double reimbursedAmount = 0;
      
      Map<String, double> expensesByCategory = {
        'inventory_purchase': 0,
        'supplies': 0,
        'transportation': 0,
        'other': 0,
      };

      for (var expense in expenses) {
        totalExpenses += expense.amount;
        
        switch (expense.status) {
          case 'pending':
            pendingAmount += expense.amount;
            break;
          case 'approved':
            approvedAmount += expense.amount;
            break;
          case 'reimbursed':
            reimbursedAmount += expense.amount;
            break;
        }

        expensesByCategory[expense.category] = 
            (expensesByCategory[expense.category] ?? 0) + expense.amount;
      }

      final fund = await getPettyCashFund();

      return {
        'total_expenses': totalExpenses,
        'pending_amount': pendingAmount,
        'approved_amount': approvedAmount,
        'reimbursed_amount': reimbursedAmount,
        'expenses_by_category': expensesByCategory,
        'current_balance': fund?.currentBalance ?? 0.0,
        'initial_balance': fund?.initialBalance ?? 0.0,
      };
    } catch (e) {
      debugPrint('Error getting expense statistics: $e');
      return {};
    }
  }

  // Stream for real-time expense updates
  Stream<List<PettyCashExpense>> streamExpenses({
    String? status,
    String? category,
  }) {
    return _supabase
        .from('petty_cash_expenses')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) {
          var expenses = data.map((e) => PettyCashExpense.fromJson(e)).toList();
          
          // Filter in memory after stream returns
          if (status != null) {
            expenses = expenses.where((e) => e.status == status).toList();
          }
          if (category != null) {
            expenses = expenses.where((e) => e.category == category).toList();
          }
          
          return expenses;
        });
  }

  // Stream for real-time fund updates
  Stream<PettyCashFund?> streamPettyCashFund() {
    return _supabase
        .from('petty_cash_fund')
        .stream(primaryKey: ['id'])
        .map((data) {
          final mainFund = data.where((f) => f['fund_name'] == 'Main Petty Cash').toList();
          return mainFund.isEmpty ? null : PettyCashFund.fromJson(mainFund.first);
        });
  }

  // Update low balance threshold
  Future<bool> updateLowBalanceThreshold(double threshold) async {
    try {
      final fund = await getPettyCashFund();
      if (fund == null) return false;

      await _supabase
          .from('petty_cash_fund')
          .update({
            'low_balance_threshold': threshold,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', fund.id!);
      return true;
    } catch (e) {
      debugPrint('Error updating low balance threshold: $e');
      return false;
    }
  }

  // Create cash reconciliation
  Future<bool> createReconciliation({
    required double systemBalance,
    required double actualCashCount,
    String? notes,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final fund = await getPettyCashFund();
      if (fund == null) return false;

      await _supabase.from('petty_cash_reconciliation').insert({
        'fund_id': fund.id,
        'reconciled_by': user.email,
        'system_balance': systemBalance,
        'actual_cash_count': actualCashCount,
        if (notes != null) 'notes': notes,
        'reconciled_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Error creating reconciliation: $e');
      return false;
    }
  }

  // Get reconciliation history
  Future<List<PettyCashReconciliation>> getReconciliationHistory() async {
    try {
      final response = await _supabase
          .from('petty_cash_reconciliation')
          .select()
          .order('reconciled_at', ascending: false);

      return response.map((e) => PettyCashReconciliation.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error getting reconciliation history: $e');
      return [];
    }
  }

  // Get or create category budget
  Future<PettyCashCategoryBudget?> getCategoryBudget(String category) async {
    try {
      final catKey = category.toLowerCase().trim();
      final response = await _supabase
          .from('petty_cash_category_budgets')
          .select()
          .ilike('category', catKey)
          .order('period_start', ascending: false)
          .limit(1);

      if (response.isNotEmpty) {
        return PettyCashCategoryBudget.fromJson(response.first);
      }

      final now = DateTime.now();
      final periodStart = DateTime(now.year, now.month, 1);
      final periodEnd = DateTime(now.year, now.month + 1, 1).subtract(const Duration(seconds: 1));

      // Create new budget if none exists
      final insertData = {
        'category': catKey,
        'percentage': 0.0,
        'current_spent': 0.0,
        'period_start': periodStart.toUtc().toIso8601String(),
        'period_end': periodEnd.toUtc().toIso8601String(),
      };

      final inserted = await _supabase
          .from('petty_cash_category_budgets')
          .insert(insertData)
          .select()
          .maybeSingle();

      if (inserted != null) {
        return PettyCashCategoryBudget.fromJson(inserted);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting category budget: $e');
      return null;
    }
  }

  // Update category budget percentage
  Future<bool> updateCategoryBudgetPercentage(String category, double percentage) async {
    try {
      final catKey = category.toLowerCase().trim();
      final now = DateTime.now();

      // Check if any record exists for this category
      final existing = await _supabase
          .from('petty_cash_category_budgets')
          .select()
          .ilike('category', catKey)
          .order('period_start', ascending: false)
          .limit(1);

      if (existing.isNotEmpty) {
        final id = existing.first['id'];
        await _supabase
            .from('petty_cash_category_budgets')
            .update({
              'percentage': percentage,
              'updated_at': now.toUtc().toIso8601String(),
            })
            .eq('id', id);
        return true;
      }

      // If no row exists, insert one
      final periodStart = DateTime(now.year, now.month, 1);
      final periodEnd = DateTime(now.year, now.month + 1, 1).subtract(const Duration(seconds: 1));
      await _supabase.from('petty_cash_category_budgets').insert({
        'category': catKey,
        'percentage': percentage,
        'current_spent': 0.0,
        'period_start': periodStart.toUtc().toIso8601String(),
        'period_end': periodEnd.toUtc().toIso8601String(),
        'created_at': now.toUtc().toIso8601String(),
        'updated_at': now.toUtc().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Error updating category budget percentage: $e');
      // Fallback attempt directly by category ilike match
      try {
        await _supabase
            .from('petty_cash_category_budgets')
            .update({
              'percentage': percentage,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .ilike('category', category.toLowerCase().trim());
        return true;
      } catch (fallbackError) {
        debugPrint('Fallback budget update failed: $fallbackError');
        return false;
      }
    }
  }

  // Reset category spent amount to zero or recalculate
  Future<bool> resetCategorySpent(String category) async {
    try {
      await _supabase
          .from('petty_cash_category_budgets')
          .update({
            'current_spent': 0.0,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .ilike('category', category.toLowerCase().trim());
      return true;
    } catch (e) {
      debugPrint('Error resetting category spent: $e');
      return false;
    }
  }

  // Reset all category spent amounts to zero
  Future<bool> resetAllCategorySpent() async {
    try {
      await _supabase
          .from('petty_cash_category_budgets')
          .update({
            'current_spent': 0.0,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .neq('category', '');
      return true;
    } catch (e) {
      debugPrint('Error resetting all category spent: $e');
      return false;
    }
  }

  // Update category spent amount (called when expense is approved)
  Future<bool> updateCategorySpent(String category, double amount) async {
    try {
      final budget = await getCategoryBudget(category);
      if (budget == null) return false;

      await _supabase
          .from('petty_cash_category_budgets')
          .update({
            'current_spent': budget.currentSpent + amount,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', budget.id!);
      return true;
    } catch (e) {
      debugPrint('Error updating category spent: $e');
      return false;
    }
  }

  // Add inventory items to stock_transactions when purchased via petty cash
  // Items will appear in Incoming / Petty Cash tab for staff to process before adding to Storage Room
  Future<bool> addInventoryToStockTransactions(
    String itemName,
    int quantity,
    String unit,
    String supplier,
    String processedBy,
  ) async {
    try {
      final transactionData = {
        'item_name': itemName,
        'transaction_type': 'incoming',
        'quantity': quantity,
        'supplier': supplier,
        'processed_by': processedBy.isNotEmpty ? processedBy : 'pagsanjaninv@gmail.com',
        'purpose': 'Petty Cash Purchase',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (unit.isNotEmpty) {
        transactionData['unit'] = unit;
      }

      await _supabase.from('stock_transactions').insert(transactionData);
      debugPrint('Successfully added $itemName ($quantity $unit) to stock_transactions upon Admin Approval');
      return true;
    } catch (e) {
      debugPrint('Error adding inventory to stock_transactions: $e');
      return false;
    }
  }

  // Get all category budgets (deduplicated by category, scoped to current fund replenishment cycle)
  Future<List<PettyCashCategoryBudget>> getAllCategoryBudgets() async {
    try {
      final response = await _supabase
          .from('petty_cash_category_budgets')
          .select()
          .order('period_start', ascending: false);

      final list = response.map((e) => PettyCashCategoryBudget.fromJson(e)).toList();

      // Deduplicate: keep the latest record for each unique category
      final Map<String, PettyCashCategoryBudget> uniqueBudgets = {};
      for (final b in list) {
        final key = b.category.toLowerCase().trim();
        if (!uniqueBudgets.containsKey(key)) {
          uniqueBudgets[key] = b;
        }
      }

      // Compute actual current cycle spending from petty_cash_expenses
      // (Only count expenses approved in the current active fund cycle)
      final fund = await getPettyCashFund();
      final cycleStart = fund?.lastReplenishedAt;
      final monthlySpent = <String, double>{};

      if (cycleStart != null) {
        try {
          final expenses = await getExpenses(
            startDate: cycleStart,
          );
          for (final exp in expenses) {
            if (exp.status == 'approved' || exp.status == 'reimbursed') {
              final cat = exp.category.toLowerCase().trim();
              monthlySpent[cat] = (monthlySpent[cat] ?? 0.0) + exp.amount;
            }
          }
        } catch (e) {
          debugPrint('Could not compute cycle spent: $e');
        }
      }

      // Ensure standard default categories exist in list
      const defaultCategories = [
        'inventory_purchase',
        'kitchen_supplies',
        'transportation',
        'supplies',
        'other'
      ];
      final now = DateTime.now();
      final periodStart = DateTime(now.year, now.month, 1);
      final periodEnd = DateTime(now.year, now.month + 1, 1).subtract(const Duration(seconds: 1));

      for (final cat in defaultCategories) {
        final actualSpent = monthlySpent[cat] ?? 0.0;
        if (!uniqueBudgets.containsKey(cat)) {
          uniqueBudgets[cat] = PettyCashCategoryBudget(
            category: cat,
            percentage: 0.0,
            currentSpent: actualSpent,
            periodStart: periodStart,
            periodEnd: periodEnd,
            createdAt: now,
            updatedAt: now,
          );
        } else {
          final existing = uniqueBudgets[cat]!;
          // Use actual cycle spent so historical test data does not contaminate current fund balance
          uniqueBudgets[cat] = PettyCashCategoryBudget(
            id: existing.id,
            category: existing.category,
            percentage: existing.percentage,
            currentSpent: actualSpent,
            periodStart: existing.periodStart,
            periodEnd: existing.periodEnd,
            createdAt: existing.createdAt,
            updatedAt: existing.updatedAt,
          );
        }
      }

      uniqueBudgets.remove('maintenance');
      uniqueBudgets.remove('utilities');

      final sortedList = uniqueBudgets.values.toList();
      sortedList.sort((a, b) => a.category.compareTo(b.category));
      return sortedList;
    } catch (e) {
      debugPrint('Error getting all category budgets: $e');
      return [];
    }
  }

  // Get spending report by category for a date range
  Future<Map<String, dynamic>> getSpendingReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      final response = await _supabase
          .from('petty_cash_expenses')
          .select()
          .gte('expense_date', start.toUtc().toIso8601String())
          .lte('expense_date', end.toUtc().toIso8601String());

      final expenses = response
          .map((e) => PettyCashExpense.fromJson(e))
          .where((e) => e.status == 'approved' || e.status == 'reimbursed')
          .toList();

      // Calculate spending by category
      final spendingByCategory = <String, double>{};
      final spendingByDate = <String, double>{};
      double totalSpent = 0;

      for (final expense in expenses) {
        final cat = expense.category.toLowerCase().trim();
        if (cat == 'maintenance' || cat == 'utilities') continue;

        spendingByCategory[expense.category] = 
            (spendingByCategory[expense.category] ?? 0) + expense.amount;
        
        final dateKey = '${expense.expenseDate.year}-${expense.expenseDate.month}-${expense.expenseDate.day}';
        spendingByDate[dateKey] = (spendingByDate[dateKey] ?? 0) + expense.amount;
        
        totalSpent += expense.amount;
      }

      // Get top spending category
      String topCategory = '';
      double topAmount = 0;
      spendingByCategory.forEach((category, amount) {
        if (amount > topAmount) {
          topCategory = category;
          topAmount = amount;
        }
      });

      return {
        'total_spent': totalSpent,
        'expense_count': expenses.length,
        'spending_by_category': spendingByCategory,
        'spending_by_date': spendingByDate,
        'top_category': topCategory,
        'top_category_amount': topAmount,
        'average_expense': expenses.isNotEmpty ? totalSpent / expenses.length : 0,
        'start_date': start.toUtc().toIso8601String(),
        'end_date': end.toUtc().toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error getting spending report: $e');
      return {};
    }
  }
}
