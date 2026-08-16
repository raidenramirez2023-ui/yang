class PettyCashFund {
  final String? id;
  final String fundName;
  final double currentBalance;
  final double initialBalance;
  final DateTime? lastReplenishedAt;
  final double lowBalanceThreshold;
  final DateTime createdAt;
  final DateTime updatedAt;

  PettyCashFund({
    this.id,
    required this.fundName,
    required this.currentBalance,
    required this.initialBalance,
    this.lastReplenishedAt,
    this.lowBalanceThreshold = 2000.0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PettyCashFund.fromJson(Map<String, dynamic> json) {
    return PettyCashFund(
      id: json['id'] as String?,
      fundName: json['fund_name'] as String? ?? 'Main Petty Cash',
      currentBalance: (json['current_balance'] as num?)?.toDouble() ?? 0.0,
      initialBalance: (json['initial_balance'] as num?)?.toDouble() ?? 0.0,
      lastReplenishedAt: json['last_replenished_at'] != null
          ? DateTime.parse(json['last_replenished_at'] as String).toLocal()
          : null,
      lowBalanceThreshold: (json['low_balance_threshold'] as num?)?.toDouble() ?? 2000.0,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fund_name': fundName,
      'current_balance': currentBalance,
      'initial_balance': initialBalance,
      if (lastReplenishedAt != null)
        'last_replenished_at': lastReplenishedAt!.toUtc().toIso8601String(),
      'low_balance_threshold': lowBalanceThreshold,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  bool get isLowBalance => currentBalance <= lowBalanceThreshold;
  double get balancePercentage => initialBalance > 0 ? (currentBalance / initialBalance) * 100 : 0;
}

class InventoryExpenseItem {
  final String itemId;
  final String itemName;
  final int quantity;
  final String? unit;

  InventoryExpenseItem({
    required this.itemId,
    required this.itemName,
    required this.quantity,
    this.unit,
  });

  factory InventoryExpenseItem.fromJson(Map<String, dynamic> json) {
    return InventoryExpenseItem(
      itemId: json['item_id'] as String,
      itemName: json['item_name'] as String,
      quantity: json['quantity'] as int,
      unit: json['unit'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'item_name': itemName,
      'quantity': quantity,
      if (unit != null) 'unit': unit,
    };
  }
}

class PettyCashExpense {
  final String? id;
  final DateTime expenseDate;
  final String description;
  final double amount;
  final String category;
  final String purchasedBy;
  final String? inventoryItemId;
  final String? inventoryItemName;
  final int? quantityPurchased;
  final String? unit;
  final List<InventoryExpenseItem>? inventoryItems;
  final String? supplier;
  final String? receiptImageUrl;
  final String? receiptNumber;
  final String status;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  PettyCashExpense({
    this.id,
    required this.expenseDate,
    required this.description,
    required this.amount,
    required this.category,
    required this.purchasedBy,
    this.inventoryItemId,
    this.inventoryItemName,
    this.quantityPurchased,
    this.unit,
    this.inventoryItems,
    this.supplier,
    this.receiptImageUrl,
    this.receiptNumber,
    required this.status,
    this.approvedBy,
    this.approvedAt,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PettyCashExpense.fromJson(Map<String, dynamic> json) {
    // Handle inventory_items array for new multi-item support
    List<InventoryExpenseItem>? inventoryItemsList;
    if (json['inventory_items'] != null && json['inventory_items'] is List) {
      inventoryItemsList = (json['inventory_items'] as List)
          .map((item) => InventoryExpenseItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return PettyCashExpense(
      id: json['id'] as String?,
      expenseDate: DateTime.parse(json['expense_date'] as String).toLocal(),
      description: json['description'] as String,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] as String,
      purchasedBy: json['purchased_by'] as String,
      inventoryItemId: json['inventory_item_id'] as String?,
      inventoryItemName: json['inventory_item_name'] as String?,
      quantityPurchased: json['quantity_purchased'] as int?,
      unit: json['unit'] as String?,
      inventoryItems: inventoryItemsList,
      supplier: json['supplier'] as String?,
      receiptImageUrl: json['receipt_image_url'] as String?,
      receiptNumber: json['receipt_number'] as String?,
      status: json['status'] as String? ?? 'pending',
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'] as String).toLocal()
          : null,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'expense_date': expenseDate.toUtc().toIso8601String(),
      'description': description,
      'amount': amount,
      'category': category,
      'purchased_by': purchasedBy,
      if (inventoryItemId != null) 'inventory_item_id': inventoryItemId,
      if (inventoryItemName != null) 'inventory_item_name': inventoryItemName,
      if (quantityPurchased != null) 'quantity_purchased': quantityPurchased,
      if (unit != null) 'unit': unit,
      if (inventoryItems != null && inventoryItems!.isNotEmpty)
        'inventory_items': inventoryItems!.map((item) => item.toJson()).toList(),
      if (supplier != null) 'supplier': supplier,
      if (receiptImageUrl != null) 'receipt_image_url': receiptImageUrl,
      if (receiptNumber != null) 'receipt_number': receiptNumber,
      'status': status,
      if (approvedBy != null) 'approved_by': approvedBy,
      if (approvedAt != null) 'approved_at': approvedAt!.toUtc().toIso8601String(),
      if (notes != null) 'notes': notes,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  static const List<String> categories = [
    'inventory_purchase',
    'supplies',
    'transportation',
    'other',
  ];

  static const List<String> statuses = [
    'pending',
    'approved',
    'rejected',
    'reimbursed',
  ];

  String get categoryDisplay {
    switch (category) {
      case 'inventory_purchase':
        return 'Inventory Purchase';
      case 'supplies':
        return 'Supplies';
      case 'transportation':
        return 'Transportation';
      case 'other':
        return 'Other';
      default:
        return category;
    }
  }

  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'reimbursed':
        return 'Reimbursed';
      default:
        return status;
    }
  }

  bool get isMultiItemExpense => inventoryItems != null && inventoryItems!.isNotEmpty;
}

class PettyCashReconciliation {
  final String? id;
  final String? fundId;
  final String reconciledBy;
  final double systemBalance;
  final double actualCashCount;
  final double discrepancy;
  final String? notes;
  final DateTime reconciledAt;
  final DateTime createdAt;

  PettyCashReconciliation({
    this.id,
    this.fundId,
    required this.reconciledBy,
    required this.systemBalance,
    required this.actualCashCount,
    required this.discrepancy,
    this.notes,
    required this.reconciledAt,
    required this.createdAt,
  });

  factory PettyCashReconciliation.fromJson(Map<String, dynamic> json) {
    return PettyCashReconciliation(
      id: json['id'] as String?,
      fundId: json['fund_id'] as String?,
      reconciledBy: json['reconciled_by'] as String,
      systemBalance: (json['system_balance'] as num?)?.toDouble() ?? 0.0,
      actualCashCount: (json['actual_cash_count'] as num?)?.toDouble() ?? 0.0,
      discrepancy: (json['discrepancy'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String?,
      reconciledAt: DateTime.parse(json['reconciled_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (fundId != null) 'fund_id': fundId,
      'reconciled_by': reconciledBy,
      'system_balance': systemBalance,
      'actual_cash_count': actualCashCount,
      if (notes != null) 'notes': notes,
      'reconciled_at': reconciledAt.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  bool get hasDiscrepancy => discrepancy.abs() > 0.01;
  bool get isShortage => discrepancy < -0.01;
  bool get isSurplus => discrepancy > 0.01;
}

class PettyCashCategoryBudget {
  final String? id;
  final String category;
  final double percentage; // Percentage of total balance allocated to this category
  final double currentSpent;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime createdAt;
  final DateTime updatedAt;

  PettyCashCategoryBudget({
    this.id,
    required this.category,
    required this.percentage,
    required this.currentSpent,
    required this.periodStart,
    required this.periodEnd,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PettyCashCategoryBudget.fromJson(Map<String, dynamic> json) {
    return PettyCashCategoryBudget(
      id: json['id'] as String?,
      category: json['category'] as String,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      currentSpent: (json['current_spent'] as num?)?.toDouble() ?? 0.0,
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: DateTime.parse(json['period_end'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'category': category,
      'percentage': percentage,
      'current_spent': currentSpent,
      'period_start': periodStart.toUtc().toIso8601String(),
      'period_end': periodEnd.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  // Calculate allocated amount based on current balance
  double getAllocatedAmount(double currentBalance) {
    return currentBalance * (percentage / 100);
  }

  double remainingAllocation(double currentBalance) {
    return getAllocatedAmount(currentBalance) - currentSpent;
  }

  double spentPercentageOfAllocation(double currentBalance) {
    final allocated = getAllocatedAmount(currentBalance);
    return allocated > 0 ? (currentSpent / allocated) * 100 : 0;
  }

  bool isNearLimit(double currentBalance) => spentPercentageOfAllocation(currentBalance) >= 80 && spentPercentageOfAllocation(currentBalance) < 100;
}
