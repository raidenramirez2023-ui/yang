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

  // Replenish petty cash fund
  Future<bool> replenishPettyCashFund(double amount) async {
    try {
      final fund = await getPettyCashFund();
      if (fund == null) return false;

      final newBalance = fund.currentBalance + amount;

      await _supabase
          .from('petty_cash_fund')
          .update({
            'current_balance': newBalance,
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
          .single();

      if (expense == null) return false;

      // Deduct the amount from petty cash fund
      final fund = await getPettyCashFund();
      if (fund == null) {
        debugPrint('Petty cash fund not initialized');
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

      // If inventory purchase, add to stock_transactions
      debugPrint('Checking if inventory purchase: category=${expense['category']}');

      if (expense['category'] == 'inventory_purchase') {
        // Handle new multi-item format
        if (expense['inventory_items'] != null && expense['inventory_items'] is List) {
          final inventoryItems = expense['inventory_items'] as List;
          debugPrint('Processing ${inventoryItems.length} inventory items...');

          for (var item in inventoryItems) {
            final itemName = item['item_name'] as String?;
            final quantity = item['quantity'] as int?;
            if (itemName != null && quantity != null) {
              debugPrint('Adding $itemName x$quantity to stock transactions...');
              final success = await addInventoryToStockTransactions(
                itemName,
                quantity,
                'pcs',
                expense['supplier'] as String? ?? 'Unknown',
                user.email ?? 'admin',
              );
              debugPrint('Stock transaction result for $itemName: $success');
            }
          }
        }
        // Handle legacy single item format
        else if (expense['inventory_item_name'] != null &&
            expense['quantity_purchased'] != null) {
          debugPrint('Adding to stock transactions (legacy format)...');
          final success = await addInventoryToStockTransactions(
            expense['inventory_item_name'] as String,
            expense['quantity_purchased'] as int,
            expense['unit'] as String? ?? 'pcs',
            expense['supplier'] as String? ?? 'Unknown',
            user.email ?? 'admin',
          );
          debugPrint('Stock transaction result: $success');
        } else {
          debugPrint('Skipping stock transaction - missing required fields');
        }
      }

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
      await _supabase
          .from('petty_cash_expenses')
          .update({
            'status': 'reimbursed',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', expenseId);

      return true;
    } catch (e) {
      debugPrint('Error marking expense as reimbursed: $e');
      return false;
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
          .single();

      if (expense == null) return false;

      // Only refund if expense was not already reimbursed
      if (expense['status'] != 'reimbursed') {
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
        .order('expense_date', ascending: false)
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
      final now = DateTime.now();
      final periodStart = DateTime(now.year, now.month, 1);
      final periodEnd = DateTime(now.year, now.month + 1, 1).subtract(const Duration(seconds: 1));

      final response = await _supabase
          .from('petty_cash_category_budgets')
          .select()
          .eq('category', category)
          .gte('period_start', periodStart.toUtc().toIso8601String())
          .lte('period_end', periodEnd.toUtc().toIso8601String())
          .maybeSingle();

      if (response != null) {
        return PettyCashCategoryBudget.fromJson(response);
      }

      // Create new budget if none exists with default 0% allocation
      await _supabase.from('petty_cash_category_budgets').insert({
        'category': category,
        'percentage': 0.0,
        'current_spent': 0.0,
        'period_start': periodStart.toUtc().toIso8601String(),
        'period_end': periodEnd.toUtc().toIso8601String(),
      });

      final newResponse = await _supabase
          .from('petty_cash_category_budgets')
          .select()
          .eq('category', category)
          .gte('period_start', periodStart.toUtc().toIso8601String())
          .lte('period_end', periodEnd.toUtc().toIso8601String())
          .single();

      return PettyCashCategoryBudget.fromJson(newResponse);
    } catch (e) {
      debugPrint('Error getting category budget: $e');
      return null;
    }
  }

  // Update category budget percentage
  Future<bool> updateCategoryBudgetPercentage(String category, double percentage) async {
    try {
      final budget = await getCategoryBudget(category);
      if (budget == null) return false;

      await _supabase
          .from('petty_cash_category_budgets')
          .update({
            'percentage': percentage,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', budget.id!);
      return true;
    } catch (e) {
      debugPrint('Error updating category budget percentage: $e');
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
  // Items will appear in Incoming tab for staff to process before adding to Storage Room
  Future<bool> addInventoryToStockTransactions(
    String itemName,
    int quantity,
    String unit,
    String supplier,
    String processedBy,
  ) async {
    try {
      // Only add to stock_transactions for tracking (not directly to inventory table)
      // Staff will process from Incoming tab to add to Storage Room
      final transactionData = {
        'item_name': itemName,
        'transaction_type': 'incoming',
        'quantity': quantity,
        'supplier': supplier,
        'processed_by': processedBy,
        'purpose': 'Petty Cash Purchase',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };
      
      // Only add unit if it's not empty
      if (unit.isNotEmpty) {
        transactionData['unit'] = unit;
      }
      
      await _supabase.from('stock_transactions').insert(transactionData);
      debugPrint('Successfully added $itemName ($quantity $unit) to stock_transactions (Incoming tab)');
      return true;
    } catch (e) {
      debugPrint('Error adding inventory to stock_transactions: $e');
      return false;
    }
  }

  // Get all category budgets
  Future<List<PettyCashCategoryBudget>> getAllCategoryBudgets() async {
    try {
      final response = await _supabase
          .from('petty_cash_category_budgets')
          .select()
          .order('category');

      return response.map((e) => PettyCashCategoryBudget.fromJson(e)).toList();
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
