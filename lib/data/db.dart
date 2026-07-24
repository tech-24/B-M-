import 'dart:typed_data';

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
    await _c.from('projects').update({
      'name': pr.name,
      'description': pr.description,
      'logo_url': pr.logoUrl,
    }).eq('id', pr.id as Object);
  }

  Future<void> deleteProject(int id) async =>
      _c.from('projects').delete().eq('id', id);

  // ---------------- Project logo ----------------

  /// Uploads [bytes] as the project's logo to Supabase Storage (bucket
  /// `project-logos`, path `{user_id}/{project_id}.{ext}`), saves the public
  /// URL on the project row, and returns that URL.
  Future<String> uploadProjectLogo(
      int projectId, Uint8List bytes, String fileExt) async {
    final uid = _c.auth.currentUser!.id;
    final path = '$uid/$projectId.$fileExt';
    await _c.storage.from('project-logos').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: 'image/${fileExt == 'jpg' ? 'jpeg' : fileExt}',
          ),
        );
    // Cache-bust so the new logo shows immediately even with the same path.
    final url =
        '${_c.storage.from('project-logos').getPublicUrl(path)}?t=${DateTime.now().millisecondsSinceEpoch}';
    await _c.from('projects').update({'logo_url': url}).eq('id', projectId);
    return url;
  }

  Future<void> removeProjectLogo(int projectId) async {
    await _c.from('projects').update({'logo_url': null}).eq('id', projectId);
  }

  // ---------------- Cost items ----------------

  Future<List<CostItem>> getCostItems(int projectId,
      {bool includeArchived = false}) async {
    var q = _c.from('cost_items').select().eq('project_id', projectId);
    if (!includeArchived) q = q.eq('archived', false);
    final rows = await q.order('name');
    return (rows as List).map((r) => CostItem.fromMap(r)).toList();
  }

  Future<int> insertCostItem(CostItem i) async {
    final row = await _c
        .from('cost_items')
        .insert({
          'project_id': i.projectId,
          'name': i.name,
          'linked_inventory_item_id': i.linkedInventoryItemId,
          'consumption_per_unit': i.consumptionPerUnit,
        })
        .select()
        .single();
    return row['id'] as int;
  }

  Future<void> updateCostItem(CostItem i) async => _c
      .from('cost_items')
      .update({'name': i.name}).eq('id', i.id as Object);

  /// Updates only the inventory link (used_quantity conversion ratio),
  /// leaving name/archived untouched.
  Future<void> updateCostItemLink(
      int itemId, int? linkedInventoryItemId, double? consumptionPerUnit) async {
    await _c.from('cost_items').update({
      'linked_inventory_item_id': linkedInventoryItemId,
      'consumption_per_unit': consumptionPerUnit,
    }).eq('id', itemId);
  }

  Future<void> unlinkCostItem(int itemId) async =>
      updateCostItemLink(itemId, null, null);

  /// Permanently deletes a cost item — safe even if it has sale history:
  /// every past sale's cost gets frozen first (see
  /// permanently_delete_cost_item in supabase_schema.sql), so old reports
  /// never change. Only use this from the "archived items" list.
  Future<void> permanentlyDeleteCostItem(int itemId) async =>
      _c.rpc('permanently_delete_cost_item', params: {'p_item_id': itemId});

  Future<void> archiveCostItem(int id) async =>
      _c.from('cost_items').update({'archived': true}).eq('id', id);

  Future<void> unarchiveCostItem(int id) async =>
      _c.from('cost_items').update({'archived': false}).eq('id', id);

  /// Deletes the item outright ONLY if it has no cost history/usage at all
  /// (so nothing is lost). If it has ever been used, archives it instead —
  /// keeping it out of new-entry pickers while leaving every past report
  /// untouched. Returns true if it was archived (not fully deleted).
  Future<bool> smartDeleteCostItem(int projectId, int itemId) async {
    final usage = await _c
        .from('cost_usage')
        .select('id')
        .eq('project_id', projectId)
        .eq('item_id', itemId)
        .limit(1);
    final history = await _c
        .from('cost_history')
        .select('id')
        .eq('project_id', projectId)
        .eq('item_id', itemId)
        .limit(1);
    final hasHistory =
        (usage as List).isNotEmpty || (history as List).isNotEmpty;
    if (hasHistory) {
      await archiveCostItem(itemId);
      return true;
    } else {
      await _c.from('cost_items').delete().eq('id', itemId);
      return false;
    }
  }

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

  /// Upserts a sale for [u.projectId]/[u.itemId]/[u.date]. If that cost
  /// item is linked to an inventory item, this ALSO derives its cost from
  /// the inventory item's current price and keeps inventory stock in sync
  /// (see upsert_linked_cost_usage in supabase_schema.sql).
  Future<void> upsertCostUsage(CostUsage u) async {
    await _c.rpc('upsert_linked_cost_usage', params: {
      'p_project_id': u.projectId,
      'p_item_id': u.itemId,
      'p_date': u.date,
      'p_quantity': u.quantity,
    });
  }

  /// Deletes a sale row and reverses its linked inventory deduction, if any.
  Future<void> deleteCostUsage(int id) async =>
      _c.rpc('delete_linked_cost_usage', params: {'p_cost_usage_id': id});

  /// Total product cost for each day in [month]: for items linked to
  /// inventory, uses the cost LOCKED IN at time of sale (unit_cost);
  /// otherwise falls back to that item's manually-set monthly cost.
  Future<Map<String, double>> productCostByDateForMonth(
      int projectId, String month) async {
    final usage = await getCostUsage(projectId, month: month);
    final costCache = <int, double>{};
    final result = <String, double>{};
    for (final u in usage) {
      double cost;
      if (u.unitCost != null) {
        cost = u.unitCost!;
      } else {
        // unitCost is only null for a row whose item still exists (never
        // permanently deleted), so itemId is guaranteed non-null here.
        final itemId = u.itemId!;
        cost = costCache[itemId] ??
            (costCache[itemId] =
                await costForItemMonth(projectId, itemId, month));
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

  /// Deletes EVERYTHING recorded for one day: the sales record, all cost
  /// item usage, all daily expenses, AND all inventory usage (returning the
  /// consumed quantity back to stock). Irreversible.
  Future<void> deleteDay(int projectId, String date) async {
    await _c
        .from('cost_usage')
        .delete()
        .eq('project_id', projectId)
        .eq('date', date);
    await _c.rpc('delete_inventory_usage_for_date', params: {
      'p_project_id': projectId,
      'p_date': date,
    });
    await _c
        .from('daily_expenses')
        .delete()
        .eq('project_id', projectId)
        .eq('date', date);
    await _c
        .from('daily_records')
        .delete()
        .eq('project_id', projectId)
        .eq('date', date);
  }

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

  Future<List<InventoryItem>> getInventory(int projectId,
      {bool includeArchived = false}) async {
    var q = _c.from('inventory_items').select().eq('project_id', projectId);
    if (!includeArchived) q = q.eq('archived', false);
    final rows = await q.order('name');
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
          'unit_type': i.unitType,
          'units_per_container': i.unitsPerContainer,
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
      'unit_type': i.unitType,
      'units_per_container': i.unitsPerContainer,
    }).eq('id', i.id as Object);
  }

  Future<void> archiveInventoryItem(int id) async =>
      _c.from('inventory_items').update({'archived': true}).eq('id', id);

  /// Permanently deletes an inventory item — safe even if it has usage
  /// history: every past usage row's cost gets frozen first (see
  /// permanently_delete_inventory_item in supabase_schema.sql), so old
  /// reports never change. If linked to a cost item, that link is cleared
  /// automatically. Only use this from the "archived items" list.
  Future<void> permanentlyDeleteInventoryItem(int itemId) async => _c.rpc(
      'permanently_delete_inventory_item', params: {'p_item_id': itemId});

  /// Adds a new purchase batch on top of the item's existing totals
  /// (never overwrites them) — see restock_inventory_item in
  /// supabase_schema.sql. Past recorded usage keeps its own locked-in
  /// price; only future usage prices at the resulting blended average.
  Future<void> restockInventoryItem(
      int itemId, double addedQuantity, double addedPrice) async {
    await _c.rpc('restock_inventory_item', params: {
      'p_item_id': itemId,
      'p_added_quantity': addedQuantity,
      'p_added_price': addedPrice,
    });
  }

  Future<void> unarchiveInventoryItem(int id) async =>
      _c.from('inventory_items').update({'archived': false}).eq('id', id);

  /// Same idea as [smartDeleteCostItem]: only hard-deletes an inventory
  /// item if it was never actually used AND isn't currently linked to a
  /// "cost of products used" item; otherwise archives it so past
  /// consumption/reports (and the link itself) stay intact. Returns true
  /// if archived.
  Future<bool> smartDeleteInventoryItem(int projectId, int itemId) async {
    final usage = await _c
        .from('inventory_usage')
        .select('id')
        .eq('project_id', projectId)
        .eq('item_id', itemId)
        .limit(1);
    final linkedCostItems = await _c
        .from('cost_items')
        .select('id')
        .eq('project_id', projectId)
        .eq('linked_inventory_item_id', itemId)
        .limit(1);
    final hasHistory =
        (usage as List).isNotEmpty || (linkedCostItems as List).isNotEmpty;
    if (hasHistory) {
      await archiveInventoryItem(itemId);
      return true;
    } else {
      await _c.from('inventory_items').delete().eq('id', itemId);
      return false;
    }
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

  /// Convenience wrapper for the "Used up completely" button: records a
  /// usage entry equal to whatever is currently remaining, zeroing stock.
  Future<void> markInventoryFullyUsed(InventoryItem item, String date) async {
    if (item.remaining <= 0) return;
    await addInventoryUsage(InventoryUsage(
      projectId: item.projectId,
      itemId: item.id!,
      date: date,
      quantity: item.remaining,
    ));
  }

  /// Falls back to items' CURRENT price only for legacy usage rows recorded
  /// before unit_cost was tracked (unit_cost is null on those rows).
  Future<Map<int, double>> _currentInventoryUnitCosts(int projectId) async {
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
    return unitCost;
  }

  /// Consumption cost for a month = sum(usage.qty * the unit cost that was
  /// LOCKED IN when that usage was recorded) — so changing an item's price
  /// today never rewrites the cost of a day you already logged.
  Future<double> inventoryConsumptionForMonth(
      int projectId, String month) async {
    final usage = await _c
        .from('inventory_usage')
        .select('item_id, quantity, unit_cost')
        .eq('project_id', projectId)
        .like('date', '$month%');

    Map<int, double>? legacyCosts; // fetched only if needed
    double total = 0;
    for (final u in (usage as List)) {
      final locked = u['unit_cost'];
      double cost;
      if (locked != null) {
        cost = (locked as num).toDouble();
      } else {
        legacyCosts ??= await _currentInventoryUnitCosts(projectId);
        cost = legacyCosts[u['item_id'] as int] ?? 0;
      }
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
          'end_month': e.endMonth,
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
      'end_month': e.endMonth,
      'notes': e.notes,
    }).eq('id', e.id as Object);
  }

  Future<void> deleteFixedExpense(int id) async =>
      _c.from('fixed_expenses').delete().eq('id', id);

  /// A fixed expense applies to [month] if it had already started
  /// (start_month <= month) and hasn't ended yet (end_month is null or is
  /// on/after month). Ending an expense (instead of deleting it) is what
  /// keeps every past month's report exactly as it was. Also includes any
  /// frozen historical amounts left behind by permanently-deleted expenses
  /// (see permanently_delete_fixed_expense) for that exact month.
  Future<double> fixedExpensesForMonth(int projectId, String month) async {
    final live = await _c
        .from('fixed_expenses')
        .select('monthly_amount')
        .eq('project_id', projectId)
        .lte('start_month', month)
        .or('end_month.is.null,end_month.gte.$month');
    final liveTotal = (live as List).fold<double>(
        0.0, (s, r) => s + (r['monthly_amount'] as num).toDouble());

    final historical = await _c
        .from('fixed_expense_history')
        .select('amount')
        .eq('project_id', projectId)
        .eq('month', month);
    final historicalTotal = (historical as List)
        .fold<double>(0.0, (s, r) => s + (r['amount'] as num).toDouble());

    return liveTotal + historicalTotal;
  }

  /// Permanently deletes a fixed expense — safe even if it already applied
  /// to past months: those months' amounts get frozen into
  /// fixed_expense_history first (see supabase_schema.sql), so old reports
  /// never change. Only use this from the "ended expenses" list.
  Future<void> permanentlyDeleteFixedExpense(int expenseId) async => _c.rpc(
      'permanently_delete_fixed_expense', params: {'p_expense_id': expenseId});

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
    final results = await Future.wait([
      salesForMonth(projectId, month),
      productCostForMonth(projectId, month),
      dailyExpensesForMonth(projectId, month),
      inventoryConsumptionForMonth(projectId, month),
      fixedExpensesForMonth(projectId, month),
    ]);
    return MonthlyReport(
      month: month,
      totalSales: results[0],
      productCost: results[1],
      dailyExpenses: results[2],
      inventoryConsumption: results[3],
      fixedExpenses: results[4],
    );
  }

  /// Reports for the 12 months of [year] (e.g. 2026). All 12 months are
  /// fetched in parallel instead of one-by-one to keep this fast.
  Future<List<MonthlyReport>> yearlyReports(int projectId, int year) async {
    final months = [
      for (var m = 1; m <= 12; m++) '$year-${m.toString().padLeft(2, '0')}'
    ];
    return Future.wait(
        months.map((month) => monthlyReport(projectId, month)));
  }

  // ---------------- Custom date-range report (printable summary) ----------------

  List<String> _monthsBetween(String startDate, String endDate) {
    final start = DateTime.parse(startDate);
    final end = DateTime.parse(endDate);
    final months = <String>[];
    var cursor = DateTime(start.year, start.month);
    final last = DateTime(end.year, end.month);
    while (!cursor.isAfter(last)) {
      months.add(
          '${cursor.year}-${cursor.month.toString().padLeft(2, '0')}');
      cursor = DateTime(cursor.year, cursor.month + 1);
    }
    return months;
  }

  Future<double> salesForRange(
      int projectId, String startDate, String endDate) async {
    final rows = await _c
        .from('daily_records')
        .select('sales_amount')
        .eq('project_id', projectId)
        .gte('date', startDate)
        .lte('date', endDate);
    return (rows as List).fold<double>(
        0.0, (s, r) => s + (r['sales_amount'] as num).toDouble());
  }

  Future<double> dailyExpensesForRange(
      int projectId, String startDate, String endDate) async {
    final rows = await _c
        .from('daily_expenses')
        .select('amount')
        .eq('project_id', projectId)
        .gte('date', startDate)
        .lte('date', endDate);
    return (rows as List)
        .fold<double>(0.0, (s, r) => s + (r['amount'] as num).toDouble());
  }

  Future<double> inventoryConsumptionForRange(
      int projectId, String startDate, String endDate) async {
    final usage = await _c
        .from('inventory_usage')
        .select('item_id, quantity, unit_cost')
        .eq('project_id', projectId)
        .gte('date', startDate)
        .lte('date', endDate);

    Map<int, double>? legacyCosts;
    double total = 0;
    for (final u in (usage as List)) {
      final locked = u['unit_cost'];
      double cost;
      if (locked != null) {
        cost = (locked as num).toDouble();
      } else {
        legacyCosts ??= await _currentInventoryUnitCosts(projectId);
        cost = legacyCosts[u['item_id'] as int] ?? 0;
      }
      total += (u['quantity'] as num).toDouble() * cost;
    }
    return total;
  }

  /// Product (operating-cost item) cost across a date range: for items
  /// linked to inventory, uses each sale's LOCKED-IN cost; otherwise falls
  /// back to that item's monthly cost for the month the sale falls in.
  Future<double> productCostForRange(
      int projectId, String startDate, String endDate) async {
    final rows = await _c
        .from('cost_usage')
        .select('item_id, date, quantity, unit_cost')
        .eq('project_id', projectId)
        .gte('date', startDate)
        .lte('date', endDate);
    final costCache = <String, double>{}; // '$itemId-$month' -> cost
    double total = 0;
    for (final u in (rows as List)) {
      final locked = u['unit_cost'];
      double cost;
      if (locked != null) {
        cost = (locked as num).toDouble();
      } else {
        final itemId = u['item_id'] as int;
        final date = u['date'] as String;
        final month = date.substring(0, 7);
        final key = '$itemId-$month';
        cost = costCache[key] ??
            (costCache[key] = await costForItemMonth(projectId, itemId, month));
      }
      total += (u['quantity'] as num).toDouble() * cost;
    }
    return total;
  }

  /// Fixed expenses across a range = sum of each month's applicable fixed
  /// expenses for every month the range touches (fetched in parallel).
  Future<double> fixedExpensesForRange(
      int projectId, String startDate, String endDate) async {
    final totals = await Future.wait(_monthsBetween(startDate, endDate)
        .map((month) => fixedExpensesForMonth(projectId, month)));
    return totals.fold<double>(0.0, (s, v) => s + v);
  }

  /// Per-item inventory breakdown for the printed report: quantity
  /// consumed + its cost during [startDate]..[endDate], plus how much is
  /// left right now. Archived items are included if they were consumed
  /// during the period (so old reports stay complete). Permanently-deleted
  /// items (item_id null) are grouped by their frozen name snapshot
  /// instead, with no "remaining" figure since the item no longer exists.
  Future<List<InventoryBreakdownRow>> inventoryBreakdownForRange(
      int projectId, String startDate, String endDate) async {
    final usage = await _c
        .from('inventory_usage')
        .select('item_id, quantity, unit_cost, item_name_snapshot')
        .eq('project_id', projectId)
        .gte('date', startDate)
        .lte('date', endDate);

    // Group by item_id when it still exists, otherwise by the frozen name
    // (String key works for both: 'id:3' or 'deleted:اسم الصنف').
    final consumedQty = <String, double>{};
    final consumedCost = <String, double>{};
    final deletedNames = <String, String>{}; // key -> snapshot name
    Map<int, double>? legacyCosts;
    for (final u in (usage as List)) {
      final itemId = u['item_id'] as int?;
      final snapshotName = u['item_name_snapshot'] as String?;
      final key = itemId != null ? 'id:$itemId' : 'deleted:${snapshotName ?? '—'}';
      if (itemId == null) deletedNames[key] = snapshotName ?? '—';

      final qty = (u['quantity'] as num).toDouble();
      final locked = u['unit_cost'];
      double cost;
      if (locked != null) {
        cost = (locked as num).toDouble();
      } else {
        // Only reachable when itemId is non-null (permanently-deleted rows
        // always have unit_cost frozen already).
        legacyCosts ??= await _currentInventoryUnitCosts(projectId);
        cost = legacyCosts[itemId!] ?? 0;
      }
      consumedQty[key] = (consumedQty[key] ?? 0) + qty;
      consumedCost[key] = (consumedCost[key] ?? 0) + qty * cost;
    }

    if (consumedQty.isEmpty) return [];

    final liveIds = consumedQty.keys
        .where((k) => k.startsWith('id:'))
        .map((k) => int.parse(k.substring(3)))
        .toList();

    final rows = <InventoryBreakdownRow>[];

    if (liveIds.isNotEmpty) {
      final items = await _c
          .from('inventory_items')
          .select('id, name, unit, purchase_quantity, used_quantity')
          .eq('project_id', projectId)
          .inFilter('id', liveIds);
      for (final it in (items as List)) {
        final id = it['id'] as int;
        final key = 'id:$id';
        final purchaseQty = (it['purchase_quantity'] as num).toDouble();
        final usedQty = (it['used_quantity'] as num).toDouble();
        final remaining = (purchaseQty - usedQty).clamp(0, double.infinity);
        rows.add(InventoryBreakdownRow(
          name: it['name'] as String,
          unit: (it['unit'] ?? '') as String,
          consumedQty: consumedQty[key] ?? 0,
          cost: consumedCost[key] ?? 0,
          remainingNow: remaining.toDouble(),
        ));
      }
    }

    for (final entry in deletedNames.entries) {
      rows.add(InventoryBreakdownRow(
        name: entry.value,
        unit: '',
        consumedQty: consumedQty[entry.key] ?? 0,
        cost: consumedCost[entry.key] ?? 0,
        remainingNow: 0,
      ));
    }

    rows.sort((a, b) => b.cost.compareTo(a.cost));
    return rows;
  }

  Future<PeriodReport> rangeReport(
      int projectId, String startDate, String endDate) async {
    final results = await Future.wait([
      salesForRange(projectId, startDate, endDate),
      productCostForRange(projectId, startDate, endDate),
      dailyExpensesForRange(projectId, startDate, endDate),
      inventoryConsumptionForRange(projectId, startDate, endDate),
      fixedExpensesForRange(projectId, startDate, endDate),
    ]);
    return PeriodReport(
      startDate: startDate,
      endDate: endDate,
      totalSales: results[0],
      productCost: results[1],
      dailyExpenses: results[2],
      inventoryConsumption: results[3],
      fixedExpenses: results[4],
    );
  }
}
