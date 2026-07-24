/// Data models for Business Manager.
/// All monetary values are stored as double (SAR).
library models;

class Project {
  final int? id;
  final String name;
  final String description;
  final String? logoUrl;
  final String createdAt; // ISO date

  Project({
    this.id,
    required this.name,
    this.description = '',
    this.logoUrl,
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'logo_url': logoUrl,
        'created_at': createdAt,
      };

  factory Project.fromMap(Map<String, dynamic> m) => Project(
        id: m['id'] as int?,
        name: m['name'] as String,
        description: (m['description'] ?? '') as String,
        logoUrl: m['logo_url'] as String?,
        createdAt: m['created_at'] as String?,
      );

  Project copyWith({String? name, String? description, String? logoUrl}) =>
      Project(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        logoUrl: logoUrl ?? this.logoUrl,
        createdAt: createdAt,
      );

  /// Explicitly clears the logo (copyWith can't distinguish "unset" from
  /// "keep current value" since both look like null).
  Project withoutLogo() => Project(
        id: id,
        name: name,
        description: description,
        logoUrl: null,
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
  final bool archived;
  /// If set, this product is linked to an inventory item: selling it
  /// auto-deducts stock and its price comes from the inventory price.
  final int? linkedInventoryItemId;
  /// How much of the linked inventory item (in pieces) one unit sold
  /// consumes. Only meaningful when [linkedInventoryItemId] is set.
  final double? consumptionPerUnit;

  CostItem({
    this.id,
    required this.projectId,
    required this.name,
    this.archived = false,
    this.linkedInventoryItemId,
    this.consumptionPerUnit,
  });

  bool get isLinked => linkedInventoryItemId != null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_id': projectId,
        'name': name,
        'archived': archived,
        'linked_inventory_item_id': linkedInventoryItemId,
        'consumption_per_unit': consumptionPerUnit,
      };

  factory CostItem.fromMap(Map<String, dynamic> m) => CostItem(
        id: m['id'] as int?,
        projectId: m['project_id'] as int,
        name: m['name'] as String,
        archived: (m['archived'] ?? false) as bool,
        linkedInventoryItemId: m['linked_inventory_item_id'] as int?,
        consumptionPerUnit: (m['consumption_per_unit'] as num?)?.toDouble(),
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
  /// Null only when the item was permanently deleted after this sale was
  /// recorded — see [itemNameSnapshot] for its name in that case.
  final int? itemId;
  final String date; // yyyy-MM-dd
  final double quantity;
  /// Locked-in per-unit cost, set for items linked to inventory (derived
  /// from that item's price at time of sale) AND for any row whose item
  /// was later permanently deleted (frozen at deletion time). Null only
  /// for unlinked, never-deleted items (their cost comes from monthly
  /// CostEntry, looked up live).
  final double? unitCost;
  /// The item's name, frozen at the moment it was permanently deleted.
  /// Null unless that has happened — normally look up the name via itemId.
  final String? itemNameSnapshot;

  CostUsage({
    this.id,
    required this.projectId,
    required this.itemId,
    required this.date,
    required this.quantity,
    this.unitCost,
    this.itemNameSnapshot,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_id': projectId,
        'item_id': itemId,
        'date': date,
        'quantity': quantity,
        'unit_cost': unitCost,
        'item_name_snapshot': itemNameSnapshot,
      };

  factory CostUsage.fromMap(Map<String, dynamic> m) => CostUsage(
        id: m['id'] as int?,
        projectId: m['project_id'] as int,
        itemId: m['item_id'] as int?,
        date: m['date'] as String,
        quantity: (m['quantity'] as num).toDouble(),
        unitCost: (m['unit_cost'] as num?)?.toDouble(),
        itemNameSnapshot: m['item_name_snapshot'] as String?,
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
  final bool archived;
  /// One of 'piece', 'carton', 'kg', 'other'. Purely informational —
  /// purchaseQuantity/purchasePrice are always stored as totals in pieces
  /// (or kg), the UI just helps convert carton-style entry into that.
  final String unitType;
  /// For 'carton'/'other'-with-subunits: how many pieces are in one unit
  /// of purchaseQuantity. Null when not applicable (piece/kg/other-plain).
  final double? unitsPerContainer;

  InventoryItem({
    this.id,
    required this.projectId,
    required this.name,
    this.category = '',
    this.unit = '',
    required this.purchaseQuantity,
    required this.purchasePrice,
    this.usedQuantity = 0,
    this.archived = false,
    this.unitType = 'piece',
    this.unitsPerContainer,
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
        'archived': archived,
        'unit_type': unitType,
        'units_per_container': unitsPerContainer,
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
        archived: (m['archived'] ?? false) as bool,
        unitType: (m['unit_type'] ?? 'piece') as String,
        unitsPerContainer: (m['units_per_container'] as num?)?.toDouble(),
      );
}

class InventoryUsage {
  final int? id;
  final int projectId;
  /// Null only when the item was permanently deleted after this usage was
  /// recorded — see [itemNameSnapshot] for its name in that case.
  final int? itemId;
  final String date; // yyyy-MM-dd
  final double quantity;
  /// Unit cost locked in at the moment this usage was recorded (so a later
  /// price change on the item never rewrites the cost of past days). Null
  /// only for rows recorded before this field existed.
  final double? unitCost;
  /// The item's name, frozen at the moment it was permanently deleted.
  final String? itemNameSnapshot;

  InventoryUsage({
    this.id,
    required this.projectId,
    required this.itemId,
    required this.date,
    required this.quantity,
    this.unitCost,
    this.itemNameSnapshot,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_id': projectId,
        'item_id': itemId,
        'date': date,
        'quantity': quantity,
        'unit_cost': unitCost,
        'item_name_snapshot': itemNameSnapshot,
      };

  factory InventoryUsage.fromMap(Map<String, dynamic> m) => InventoryUsage(
        id: m['id'] as int?,
        projectId: m['project_id'] as int,
        itemId: m['item_id'] as int?,
        date: m['date'] as String,
        quantity: (m['quantity'] as num).toDouble(),
        unitCost: (m['unit_cost'] as num?)?.toDouble(),
        itemNameSnapshot: m['item_name_snapshot'] as String?,
      );
}

class FixedExpense {
  final int? id;
  final int projectId;
  final String name;
  final double monthlyAmount;
  final String startMonth; // yyyy-MM (applies from this month onward)
  /// yyyy-MM, inclusive last month this expense applies to. Null = still
  /// ongoing. Ending an expense (instead of deleting it) keeps every past
  /// month's report exactly as it was.
  final String? endMonth;
  final String notes;

  FixedExpense({
    this.id,
    required this.projectId,
    required this.name,
    required this.monthlyAmount,
    required this.startMonth,
    this.endMonth,
    this.notes = '',
  });

  bool get isEnded => endMonth != null;

  FixedExpense copyWith({String? endMonth, bool clearEndMonth = false}) =>
      FixedExpense(
        id: id,
        projectId: projectId,
        name: name,
        monthlyAmount: monthlyAmount,
        startMonth: startMonth,
        endMonth: clearEndMonth ? null : (endMonth ?? this.endMonth),
        notes: notes,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_id': projectId,
        'name': name,
        'monthly_amount': monthlyAmount,
        'start_month': startMonth,
        'end_month': endMonth,
        'notes': notes,
      };

  factory FixedExpense.fromMap(Map<String, dynamic> m) => FixedExpense(
        id: m['id'] as int?,
        projectId: m['project_id'] as int,
        name: m['name'] as String,
        monthlyAmount: (m['monthly_amount'] as num).toDouble(),
        startMonth: (m['start_month'] ?? '') as String,
        endMonth: m['end_month'] as String?,
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

/// One row in the printed report's inventory breakdown: how much of an
/// item was consumed (and its cost) during the report period, plus how
/// much is left right now (at print time).
class InventoryBreakdownRow {
  final String name;
  final String unit;
  final double consumedQty;
  final double cost;
  final double remainingNow;

  InventoryBreakdownRow({
    required this.name,
    required this.unit,
    required this.consumedQty,
    required this.cost,
    required this.remainingNow,
  });
}

/// Aggregated report for an arbitrary custom date range (used by the
/// printable summary feature: month / 3 / 6 / 9 months / year / custom).
class PeriodReport {
  final String startDate; // yyyy-MM-dd
  final String endDate; // yyyy-MM-dd
  final double totalSales;
  final double productCost;
  final double dailyExpenses;
  final double inventoryConsumption;
  final double fixedExpenses;

  PeriodReport({
    required this.startDate,
    required this.endDate,
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
