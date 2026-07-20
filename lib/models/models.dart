/// Data models for Business Manager.
/// All monetary values are stored as double (SAR).
library models;

class Project {
  final int? id;
  final String name;
  final String description;
  final String createdAt; // ISO date

  Project({this.id, required this.name, this.description = '', String? createdAt})
      : createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'created_at': createdAt,
      };

  factory Project.fromMap(Map<String, dynamic> m) => Project(
        id: m['id'] as int?,
        name: m['name'] as String,
        description: (m['description'] ?? '') as String,
        createdAt: m['created_at'] as String?,
      );

  Project copyWith({String? name, String? description}) => Project(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        createdAt: createdAt,
      );
}

class DailyRecord {
  final int? id;
  final int projectId;
  final String date; // yyyy-MM-dd
  final double salesAmount;

  DailyRecord({
    this.id,
    required this.projectId,
    required this.date,
    this.salesAmount = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_id': projectId,
        'date': date,
        'sales_amount': salesAmount,
      };

  factory DailyRecord.fromMap(Map<String, dynamic> m) => DailyRecord(
        id: m['id'] as int?,
        projectId: m['project_id'] as int,
        date: m['date'] as String,
        salesAmount: (m['sales_amount'] as num?)?.toDouble() ?? 0,
      );
}

/// A named item that has a per-unit cost, e.g. "Vanilla ice cream" or
/// "Gasoline (per liter)". Costs are set per month via [CostEntry] and
/// daily consumption is tracked per item via [CostUsage].
class CostItem {
  final int? id;
  final int projectId;
  final String name;

  CostItem({this.id, required this.projectId, required this.name});

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_id': projectId,
        'name': name,
      };

  factory CostItem.fromMap(Map<String, dynamic> m) => CostItem(
        id: m['id'] as int?,
        projectId: m['project_id'] as int,
        name: m['name'] as String,
      );
}

/// Monthly unit cost for a specific [CostItem].
class CostEntry {
  final int? id;
  final int projectId;
  final int itemId;
  final String month; // yyyy-MM
  final double cost; // cost per unit for that item in that month

  CostEntry({
    this.id,
    required this.projectId,
    required this.itemId,
    required this.month,
    required this.cost,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_id': projectId,
        'item_id': itemId,
        'month': month,
        'cost': cost,
      };

  factory CostEntry.fromMap(Map<String, dynamic> m) => CostEntry(
        id: m['id'] as int?,
        projectId: m['project_id'] as int,
        itemId: m['item_id'] as int,
        month: m['month'] as String,
        cost: (m['cost'] as num).toDouble(),
      );
}

/// Quantity of a [CostItem] consumed on a specific day.
class CostUsage {
  final int? id;
  final int projectId;
  final int itemId;
  final String date; // yyyy-MM-dd
  final double quantity;

  CostUsage({
    this.id,
    required this.projectId,
    required this.itemId,
    required this.date,
    required this.quantity,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_id': projectId,
        'item_id': itemId,
        'date': date,
        'quantity': quantity,
      };

  factory CostUsage.fromMap(Map<String, dynamic> m) => CostUsage(
        id: m['id'] as int?,
        projectId: m['project_id'] as int,
        itemId: m['item_id'] as int,
        date: m['date'] as String,
        quantity: (m['quantity'] as num).toDouble(),
      );
}

class DailyExpense {
  final int? id;
  final int projectId;
  final String date; // yyyy-MM-dd
  final String category;
  final double amount;
  final String notes;

  DailyExpense({
    this.id,
    required this.projectId,
    required this.date,
    required this.category,
    required this.amount,
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_id': projectId,
        'date': date,
        'category': category,
        'amount': amount,
        'notes': notes,
      };

  factory DailyExpense.fromMap(Map<String, dynamic> m) => DailyExpense(
        id: m['id'] as int?,
        projectId: m['project_id'] as int,
        date: m['date'] as String,
        category: m['category'] as String,
        amount: (m['amount'] as num).toDouble(),
        notes: (m['notes'] ?? '') as String,
      );
}

class InventoryItem {
  final int? id;
  final int projectId;
  final String name;
  final String category;
  final String unit; // piece, box, carton...
  final double purchaseQuantity;
  final double purchasePrice; // total price of the purchased quantity
  final double usedQuantity;

  InventoryItem({
    this.id,
    required this.projectId,
    required this.name,
    this.category = '',
    this.unit = '',
    required this.purchaseQuantity,
    required this.purchasePrice,
    this.usedQuantity = 0,
  });

  double get remaining => (purchaseQuantity - usedQuantity).clamp(0, double.infinity);
  double get unitCost => purchaseQuantity <= 0 ? 0 : purchasePrice / purchaseQuantity;
  double get consumedCost => usedQuantity * unitCost;

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_id': projectId,
        'name': name,
        'category': category,
        'unit': unit,
        'purchase_quantity': purchaseQuantity,
        'purchase_price': purchasePrice,
        'used_quantity': usedQuantity,
      };

  factory InventoryItem.fromMap(Map<String, dynamic> m) => InventoryItem(
        id: m['id'] as int?,
        projectId: m['project_id'] as int,
        name: m['name'] as String,
        category: (m['category'] ?? '') as String,
        unit: (m['unit'] ?? '') as String,
        purchaseQuantity: (m['purchase_quantity'] as num).toDouble(),
        purchasePrice: (m['purchase_price'] as num).toDouble(),
        usedQuantity: (m['used_quantity'] as num?)?.toDouble() ?? 0,
      );
}

class InventoryUsage {
  final int? id;
  final int projectId;
  final int itemId;
  final String date; // yyyy-MM-dd
  final double quantity;

  InventoryUsage({
    this.id,
    required this.projectId,
    required this.itemId,
    required this.date,
    required this.quantity,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_id': projectId,
        'item_id': itemId,
        'date': date,
        'quantity': quantity,
      };

  factory InventoryUsage.fromMap(Map<String, dynamic> m) => InventoryUsage(
        id: m['id'] as int?,
        projectId: m['project_id'] as int,
        itemId: m['item_id'] as int,
        date: m['date'] as String,
        quantity: (m['quantity'] as num).toDouble(),
      );
}

class FixedExpense {
  final int? id;
  final int projectId;
  final String name;
  final double monthlyAmount;
  final String startMonth; // yyyy-MM (applies from this month onward)
  final String notes;

  FixedExpense({
    this.id,
    required this.projectId,
    required this.name,
    required this.monthlyAmount,
    required this.startMonth,
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_id': projectId,
        'name': name,
        'monthly_amount': monthlyAmount,
        'start_month': startMonth,
        'notes': notes,
      };

  factory FixedExpense.fromMap(Map<String, dynamic> m) => FixedExpense(
        id: m['id'] as int?,
        projectId: m['project_id'] as int,
        name: m['name'] as String,
        monthlyAmount: (m['monthly_amount'] as num).toDouble(),
        startMonth: (m['start_month'] ?? '') as String,
        notes: (m['notes'] ?? '') as String,
      );
}

/// Aggregated monthly report values.
class MonthlyReport {
  final String month;
  final double totalSales;
  final double productCost;
  final double dailyExpenses;
  final double inventoryConsumption;
  final double fixedExpenses;

  MonthlyReport({
    required this.month,
    required this.totalSales,
    required this.productCost,
    required this.dailyExpenses,
    required this.inventoryConsumption,
    required this.fixedExpenses,
  });

  double get totalCosts => productCost + inventoryConsumption;
  double get totalExpenses => dailyExpenses + fixedExpenses;
  double get netProfit =>
      totalSales - productCost - dailyExpenses - inventoryConsumption - fixedExpenses;
  double get profitPercent => totalSales <= 0 ? 0 : (netProfit / totalSales) * 100;
}
