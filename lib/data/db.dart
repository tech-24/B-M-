import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

/// Cloud-backed repository (Supabase/Postgres). Every row is scoped to the
/// signed-in user by the database's Row Level Security policies (see
/// supabase_schema.sql) — a user only ever sees their own data, even
/// though everyone shares the same database.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  SupabaseClient get _c => Supabase.instance.client;

  // ---------------- Projects ----------------

  Future<List<Project>> getProjects() async {
    final rows = await _c.from('projects').select().order('created_at', ascending: false);
    return (rows as List).map((r) => Project.fromMap(r)).toList();
  }

  Future<int> insertProject(Project pr) async {
    final row = await _c
        .from('projects')
        .insert({'name': pr.name, 'description': pr.description})
        .select()
        .single();
    return row['id'] as int;
  }

  Future<void> updateProject(Project pr) async {
    await _c
        .from('projects')
        .update({'name': pr.name, 'description': pr.description})
        .eq('id', pr.id as Object);
  }

  Future<void> deleteProject(int id) async =>
      _c.from('projects').delete().eq('id', id);

  // ---------------- Cost items ----------------

  Future<List<CostItem>> getCostItems(int projectId) async {
    final rows = await _c
        .from('cost_items')
        .select()
        .eq('project_id', projectId)
        .order('name');
    return (rows as List).map((r) => CostItem.fromMap(r)).toList();
  }

  Future<int> insertCostItem(CostItem i) async {
    final row = await _c
        .from('cost_items')
        .insert({'project_id': i.projectId, 'name': i.name})
        .select()
        .single();
    return row['id'] as int;
  }

  Future<void> updateCostItem(CostItem i) async =>
      _c.from('cost_items').update({'name': i.name}).eq('id', i.id as Object);

  Future<void> deleteCostItem(int id) async =>
      _c.from('cost_items').delete().eq('id', id);

  // ---------------- Cost history (per item, per month) ----------------

  Future<List<CostEntry>> getCostEntries(int projectId, int itemId) async {
    final rows = await _c
        .from('cost_history')
        .select()
        .eq('project_id', projectId)
        .eq('item_id', itemId)
        .order('month', ascending: false);
    return (rows as List).map((r) => CostEntry.fromMap(r)).toList();
  }

  Future<void> upsertCostEntry(CostEntry e) async {
    await _c.from('cost_history').upsert(
      {
        'project_id': e.projectId,
        'item_id': e.itemId,
        'month': e.month,
        'cost': e.cost,
      },
      onConflict: 'project_id,item_id,month',
    );
  }

  Future<void> deleteCostEntry(int id) async =>
      _c.from('cost_history').delete().eq('id', id);

  Future<double> costForItemMonth(
      int projectId, int itemId, String month) async {
    final exact = await _c
        .from('cost_history')
        .select('cost')
        .eq('project_id', projectId)
        .eq('item_id', itemId)
        .eq('month', month);
    if ((exact as List).isNotEmpty) {
      return (exact.first['cost'] as num).toDouble();
    }
    final prev = await _c
        .from('cost_history')
        .select('cost')
        .eq('project_id', projectId)
        .eq('item_id', itemId)
        .lt('month', month)
        .order('month', ascending: false)
        .limit(1);
    if ((prev as List).isNotEmpty) {
      return (prev.first['cost'] as num).toDouble();
    }
    return 0;
  }

  Future<CostEntry?> latestCostEntry(int projectId, int itemId) async {
    final rows = await _c
        .from('cost_history')
        .select()
        .eq('project_id', projectId)
        .eq('item_id', itemId)
        .order('month', ascending: false)
        .limit(1);
    final list = rows as List;
    return list.isEmpty ? null : CostEntry.fromMap(list.first);
  }

  // ---------------- Cost usage (per item, per day) ----------------

  Future<List<CostUsage>> getCostUsage(int projectId,
      {String? date, String? month}) async {
    var q = _c.from('cost_usage').select().eq('project_id', projectId);
    if (date != null) {
      q = q.eq('date', date);
    } else if (month != null) {
      q = q.like('date', '$month%');
    }
    final rows = await q;
    return (rows as List).map((r) => CostUsage.fromMap(r)).toList();
  }

  Future<void> upsertCostUsage(CostUsage u) async {
    await _c.from('cost_usage').upsert(
      {
        'project_id': u.projectId,
        'item_id': u.itemId,
        'date': u.date,
        'quantity': u.quantity,
      },
      onConflict: 'project_id,item_id,date',
    );
  }

  Future<void> deleteCostUsage(int id) async =>
      _c.from('cost_usage').delete().eq('id', id);

  /// Total product cost for each day in [month] (quantity * that item's
  /// unit cost for the month), summed across all items used that day.
  Future<Map<String, double>> productCostByDateForMonth(
      int projectId, String month) async {
    final usage = await getCostUsage(projectId, month: month);
    final costCache = <int, double>{};
    final result = <String, double>{};
    for (final u in usage) {
      var cost = costCache[u.itemId];
      if (cost == null) {
        cost = await costForItemMonth(projectId, u.itemId, month);
        costCache[u.itemId] = cost;
      }
      result[u.date] = (result[u.date] ?? 0) + u.quantity * cost;
    }
    return result;
  }

  // ---------------- Daily records ----------------

  Future<List<DailyRecord>> getDailyRecords(int projectId,
      {String? month, int? limit}) async {
    var q = _c.from('daily_records').select().eq('project_id', projectId);
    if (month != null) q = q.like('date', '$month%');
    var ordered = q.order('date', ascending: false);
    if (limit != null) ordered = ordered.limit(limit);
    final rows = await ordered;
    return (rows as List).map((r) => DailyRecord.fromMap(r)).toList();
  }

  Future<DailyRecord?> getRecordByDate(int projectId, String date) async {
    final rows = await _c
        .from('daily_records')
        .select()
        .eq('project_id', projectId)
        .eq('date', date);
    final list = rows as List;
    return list.isEmpty ? null : DailyRecord.fromMap(list.first);
  }

  Future<void> upsertDailyRecord(DailyRecord r) async {
    await _c.from('daily_records').upsert(
      {
        'project_id': r.projectId,
        'date': r.date,
        'sales_amount': r.salesAmount,
      },
      onConflict: 'project_id,date',
    );
  }

  Future<void> deleteDailyRecord(int id) async =>
      _c.from('daily_records').delete().eq('id', id);

  // ---------------- Daily expenses ----------------

  Future<List<DailyExpense>> getDailyExpenses(int projectId,
      {String? date, String? month}) async {
    var q = _c.from('daily_expenses').select().eq('project_id', projectId);
    if (date != null) {
      q = q.eq('date', date);
    } else if (month != null) {
      q = q.like('date', '$month%');
    }
    final rows = await q.order('date', ascending: false);
    return (rows as List).map((r) => DailyExpense.fromMap(r)).toList();
  }

  Future<int> insertDailyExpense(DailyExpense e) async {
    final row = await _c
        .from('daily_expenses')
        .insert({
          'project_id': e.projectId,
          'date': e.date,
          'category': e.category,
          'amount': e.amount,
          'notes': e.notes,
        })
        .select()
        .single();
    return row['id'] as int;
  }

  Future<void> updateDailyExpense(DailyExpense e) async {
    await _c.from('daily_expenses').update({
      'date': e.date,
      'category': e.category,
      'amount': e.amount,
      'notes': e.notes,
    }).eq('id', e.id as Object);
  }

  Future<void> deleteDailyExpense(int id) async =>
      _c.from('daily_expenses').delete().eq('id', id);

  // ---------------- Inventory ----------------

  Future<List<InventoryItem>> getInventory(int projectId) async {
    final rows = await _c
        .from('inventory_items')
        .select()
        .eq('project_id', projectId)
        .order('name');
    return (rows as List).map((r) => InventoryItem.fromMap(r)).toList();
  }

  Future<int> insertInventoryItem(InventoryItem i) async {
    final row = await _c
        .from('inventory_items')
        .insert({
          'project_id': i.projectId,
          'name': i.name,
          'category': i.category,
          'unit': i.unit,
          'purchase_quantity': i.purchaseQuantity,
          'purchase_price': i.purchasePrice,
          'used_quantity': i.usedQuantity,
        })
        .select()
        .single();
    return row['id'] as int;
  }

  Future<void> updateInventoryItem(InventoryItem i) async {
    await _c.from('inventory_items').update({
      'name': i.name,
      'category': i.category,
      'unit': i.unit,
      'purchase_quantity': i.purchaseQuantity,
      'purchase_price': i.purchasePrice,
      'used_quantity': i.usedQuantity,
    }).eq('id', i.id as Object);
  }

  Future<void> deleteInventoryItem(int id) async =>
      _c.from('inventory_items').delete().eq('id', id);

  /// Records a usage entry and increases the item's used_quantity
  /// atomically (via a Postgres function — see supabase_schema.sql).
  Future<void> addInventoryUsage(InventoryUsage u) async {
    await _c.rpc('add_inventory_usage', params: {
      'p_item_id': u.itemId,
      'p_project_id': u.projectId,
      'p_date': u.date,
      'p_quantity': u.quantity,
    });
  }

  /// Consumption cost for a month = sum(usage.qty * item unit cost).
  Future<double> inventoryConsumptionForMonth(
      int projectId, String month) async {
    final usage = await _c
        .from('inventory_usage')
        .select('item_id, quantity')
        .eq('project_id', projectId)
        .like('date', '$month%');
    final items = await _c
        .from('inventory_items')
        .select('id, purchase_price, purchase_quantity')
        .eq('project_id', projectId);
    final unitCost = <int, double>{};
    for (final it in (items as List)) {
      final qty = (it['purchase_quantity'] as num).toDouble();
      final price = (it['purchase_price'] as num).toDouble();
      unitCost[it['id'] as int] = qty <= 0 ? 0 : price / qty;
    }
    double total = 0;
    for (final u in (usage as List)) {
      final cost = unitCost[u['item_id'] as int] ?? 0;
      total += (u['quantity'] as num).toDouble() * cost;
    }
    return total;
  }

  // ---------------- Fixed expenses ----------------

  Future<List<FixedExpense>> getFixedExpenses(int projectId) async {
    final rows = await _c
        .from('fixed_expenses')
        .select()
        .eq('project_id', projectId)
        .order('name');
    return (rows as List).map((r) => FixedExpense.fromMap(r)).toList();
  }

  Future<int> insertFixedExpense(FixedExpense e) async {
    final row = await _c
        .from('fixed_expenses')
        .insert({
          'project_id': e.projectId,
          'name': e.name,
          'monthly_amount': e.monthlyAmount,
          'start_month': e.startMonth,
          'notes': e.notes,
        })
        .select()
        .single();
    return row['id'] as int;
  }

  Future<void> updateFixedExpense(FixedExpense e) async {
    await _c.from('fixed_expenses').update({
      'name': e.name,
      'monthly_amount': e.monthlyAmount,
      'start_month': e.startMonth,
      'notes': e.notes,
    }).eq('id', e.id as Object);
  }

  Future<void> deleteFixedExpense(int id) async =>
      _c.from('fixed_expenses').delete().eq('id', id);

  Future<double> fixedExpensesForMonth(int projectId, String month) async {
    final rows = await _c
        .from('fixed_expenses')
        .select('monthly_amount')
        .eq('project_id', projectId)
        .lte('start_month', month);
    return (rows as List).fold<double>(
        0.0, (s, r) => s + (r['monthly_amount'] as num).toDouble());
  }

  // ---------------- Reports ----------------

  /// Product cost for a month = sum over all cost items of
  /// (quantity consumed that month * that item's unit cost for the month).
  Future<double> productCostForMonth(int projectId, String month) async {
    final byDate = await productCostByDateForMonth(projectId, month);
    return byDate.values.fold<double>(0.0, (s, v) => s + v);
  }

  Future<double> salesForMonth(int projectId, String month) async {
    final rows = await _c
        .from('daily_records')
        .select('sales_amount')
        .eq('project_id', projectId)
        .like('date', '$month%');
    return (rows as List).fold<double>(
        0.0, (s, r) => s + (r['sales_amount'] as num).toDouble());
  }

  Future<double> dailyExpensesForMonth(int projectId, String month) async {
    final rows = await _c
        .from('daily_expenses')
        .select('amount')
        .eq('project_id', projectId)
        .like('date', '$month%');
    return (rows as List)
        .fold<double>(0.0, (s, r) => s + (r['amount'] as num).toDouble());
  }

  Future<double> dailyExpensesForDate(int projectId, String date) async {
    final rows = await _c
        .from('daily_expenses')
        .select('amount')
        .eq('project_id', projectId)
        .eq('date', date);
    return (rows as List)
        .fold<double>(0.0, (s, r) => s + (r['amount'] as num).toDouble());
  }

  Future<MonthlyReport> monthlyReport(int projectId, String month) async {
    return MonthlyReport(
      month: month,
      totalSales: await salesForMonth(projectId, month),
      productCost: await productCostForMonth(projectId, month),
      dailyExpenses: await dailyExpensesForMonth(projectId, month),
      inventoryConsumption:
          await inventoryConsumptionForMonth(projectId, month),
      fixedExpenses: await fixedExpensesForMonth(projectId, month),
    );
  }

  /// Reports for the 12 months of [year] (e.g. 2026).
  Future<List<MonthlyReport>> yearlyReports(int projectId, int year) async {
    final out = <MonthlyReport>[];
    for (var m = 1; m <= 12; m++) {
      final month = '$year-${m.toString().padLeft(2, '0')}';
      out.add(await monthlyReport(projectId, month));
    }
    return out;
  }
}
