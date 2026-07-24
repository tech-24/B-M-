import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_theme.dart';
import '../core/localization.dart';
import '../data/db.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import 'cost_settings_screen.dart';

/// Month view: each day is a separate entry that opens its own page.
class DailyRecordsScreen extends StatefulWidget {
  final Project project;
  const DailyRecordsScreen({super.key, required this.project});

  @override
  State<DailyRecordsScreen> createState() => _DailyRecordsScreenState();
}

class _DailyRecordsScreenState extends State<DailyRecordsScreen> {
  final _db = AppDatabase.instance;
  String _month = currentMonthStr();
  List<DailyRecord> _records = [];
  Map<String, double> _costByDate = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pid = widget.project.id!;
    final recs = await _db.getDailyRecords(pid, month: _month);
    final costByDate = await _db.productCostByDateForMonth(pid, _month);
    if (!mounted) return;
    setState(() {
      _records = recs;
      _costByDate = costByDate;
      _loading = false;
    });
  }

  Future<void> _openDay(String date) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                DayDetailScreen(project: widget.project, date: date)));
    _load();
  }

  Future<void> _pickNewDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      _openDay(DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context).t;
    return Scaffold(
      appBar: AppBar(title: Text(t('dailyRecords'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child:
                      MonthPicker(month: _month, onChanged: (m) {
                    setState(() => _month = m);
                    _load();
                  }),
                ),
                Expanded(
                  child: _records.isEmpty
                      ? EmptyState(
                          icon: Icons.event_note_outlined,
                          message: t('noRecords'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _records.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final r = _records[i];
                            final cost = _costByDate[r.date] ?? 0;
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      AppColors.primary.withOpacity(.12),
                                  child: Text(r.date.substring(8),
                                      style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700)),
                                ),
                                title: Text(dateLabel(context, r.date)),
                                subtitle: Text(
                                    '${t('sales')}: ${fmtMoney(context, r.salesAmount)}  •  ${t('productCost')}: ${fmtMoney(context, cost)}'),
                                trailing: const Icon(Icons.chevron_left),
                                onTap: () => _openDay(r.date),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickNewDay,
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// A single day's page: sales, per-item usage (auto cost), expenses, result.
class DayDetailScreen extends StatefulWidget {
  final Project project;
  final String date; // yyyy-MM-dd
  const DayDetailScreen(
      {super.key, required this.project, required this.date});

  @override
  State<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends State<DayDetailScreen> {
  final _db = AppDatabase.instance;
  final _salesCtl = TextEditingController();
  List<CostItem> _items = [];
  List<CostUsage> _usage = [];
  Map<int, double> _itemCost = {};
  List<DailyExpense> _expenses = [];
  bool _loading = true;

  String get _month => widget.date.substring(0, 7);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pid = widget.project.id!;
    final rec = await _db.getRecordByDate(pid, widget.date);
    final items = await _db.getCostItems(pid);
    final usage = await _db.getCostUsage(pid, date: widget.date);
    final exps = await _db.getDailyExpenses(pid, date: widget.date);
    final costMap = <int, double>{};
    for (final it in items) {
      costMap[it.id!] = await _db.costForItemMonth(pid, it.id!, _month);
    }
    if (!mounted) return;
    setState(() {
      _salesCtl.text = rec == null || rec.salesAmount == 0
          ? ''
          : fmtNum(rec.salesAmount);
      _items = items;
      _usage = usage;
      _itemCost = costMap;
      _expenses = exps;
      _loading = false;
    });
  }

  double get _sales => parseNum(_salesCtl.text.replaceAll(',', ''));
  double get _productCost => _usage.fold<double>(
      0.0, (s, u) => s + u.quantity * (u.unitCost ?? (_itemCost[u.itemId] ?? 0)));
  double get _expTotal =>
      _expenses.fold<double>(0.0, (s, e) => s + e.amount);
  double get _dailyProfit => _sales - _productCost - _expTotal;

  Future<void> _save() async {
    await _db.upsertDailyRecord(DailyRecord(
      projectId: widget.project.id!,
      date: widget.date,
      salesAmount: _sales,
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.of(context).t('save'))));
  }

  Future<void> _addOrEditUsage({CostUsage? existing}) async {
    final t = L10n.of(context).t;
    if (_items.isEmpty) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(t('noItemsTitle')),
          content: Text(t('noItemsHint')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(t('cancel'))),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(t('operatingCost'))),
          ],
        ),
      );
      if (go == true && mounted) {
        await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => CostItemsPage(project: widget.project)));
        _load();
      }
      return;
    }

    // Items already used today (other than the one being edited) can't be
    // picked again — quantities for the same item on the same day merge
    // into a single row.
    final usedIds =
        _usage.where((u) => u.id != existing?.id).map((u) => u.itemId).toSet();
    final available = existing != null
        ? _items
        : _items.where((it) => !usedIds.contains(it.id)).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('allItemsUsed'))));
      return;
    }

    CostItem selected = existing != null
        ? _items.firstWhere((it) => it.id == existing.itemId)
        : available.first;
    final qtyCtl = TextEditingController(
        text: existing == null ? '' : fmtNum(existing.quantity));
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(existing == null ? t('addUsage') : t('editUsage')),
          content: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<CostItem>(
                value: selected,
                decoration: InputDecoration(labelText: t('selectItem')),
                items: available
                    .map((it) => DropdownMenuItem(
                        value: it, child: Text(it.name)))
                    .toList(),
                onChanged: existing != null
                    ? null
                    : (v) => setDlg(() => selected = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: qtyCtl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: t('usedQuantity')),
                validator: (v) => validateNumber(ctx, v),
                autofocus: true,
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(t('cancel'))),
            FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(ctx, true);
                  }
                },
                child: Text(t('save'))),
          ],
        ),
      ),
    );

    if (ok == true) {
      await _db.upsertCostUsage(CostUsage(
        id: existing?.id,
        projectId: widget.project.id!,
        itemId: selected.id!,
        date: widget.date,
        quantity: parseNum(qtyCtl.text.replaceAll(',', '')),
      ));
      _load();
    }
  }

  Future<void> _addExpense() async {
    final t = L10n.of(context).t;
    final catCtl = TextEditingController();
    final amountCtl = TextEditingController();
    final notesCtl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('addExpense')),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
                controller: catCtl,
                decoration: InputDecoration(labelText: t('category')),
                validator: (v) => validateRequired(ctx, v)),
            const SizedBox(height: 12),
            TextFormField(
                controller: amountCtl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: t('amount')),
                validator: (v) => validateNumber(ctx, v)),
            const SizedBox(height: 12),
            TextFormField(
                controller: notesCtl,
                decoration: InputDecoration(labelText: t('notes'))),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t('cancel'))),
          FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: Text(t('add'))),
        ],
      ),
    );
    if (ok == true) {
      await _db.insertDailyExpense(DailyExpense(
        projectId: widget.project.id!,
        date: widget.date,
        category: catCtl.text.trim(),
        amount: parseNum(amountCtl.text),
        notes: notesCtl.text.trim(),
      ));
      _load();
    }
  }

  Future<void> _deleteDay() async {
    final t = L10n.of(context).t;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('deleteDay')),
        content: Text(t('deleteDayConfirm')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t('cancel'))),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.bad),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t('delete'))),
        ],
      ),
    );
    if (ok != true) return;
    await _db.deleteDay(widget.project.id!, widget.date);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context).t;
    return Scaffold(
      appBar: AppBar(
        title: Text(dateLabel(context, widget.date)),
        actions: [
          IconButton(
            tooltip: t('deleteDay'),
            icon: const Icon(Icons.delete_outline),
            onPressed: _loading ? null : _deleteDay,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionTitle(t('sales'), Icons.payments_outlined),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: TextField(
                      controller: _salesCtl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: t('salesAmount'),
                          suffixText: t('sar')),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _sectionTitle(t('usage'), Icons.local_drink_outlined,
                    action: IconButton(
                        onPressed: () => _addOrEditUsage(),
                        icon: const Icon(Icons.add_circle_outline))),
                if (_usage.isEmpty)
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(t('noUsage'),
                              style: TextStyle(
                                  color: Theme.of(context).hintColor))))
                else
                  Card(
                    child: Column(children: [
                      ..._usage.map((u) {
                        final item = _items.firstWhere(
                            (it) => it.id == u.itemId,
                            orElse: () => CostItem(
                                projectId: widget.project.id!,
                                name: u.itemNameSnapshot ??
                                    L10n.of(context).t('deletedItemLabel')));
                        final cost =
                            u.quantity * (u.unitCost ?? (_itemCost[u.itemId] ?? 0));
                        final canEdit = u.itemId != null;
                        return ListTile(
                          dense: true,
                          title: Text(item.name),
                          subtitle: Text(
                              '${t('quantity')}: ${fmtNum(u.quantity)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(fmtMoney(context, cost),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              if (canEdit)
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 20),
                                  onPressed: () =>
                                      _addOrEditUsage(existing: u),
                                ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 20),
                                onPressed: () async {
                                  await _db.deleteCostUsage(u.id!);
                                  _load();
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                      const Divider(height: 1),
                      ListTile(
                        dense: true,
                        title: Text(t('productCost'),
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        trailing: Text(fmtMoney(context, _productCost),
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  ),
                const SizedBox(height: 16),
                _sectionTitle(t('dailyExpenses'), Icons.receipt_long_outlined,
                    action: IconButton(
                        onPressed: _addExpense,
                        icon: const Icon(Icons.add_circle_outline))),
                if (_expenses.isEmpty)
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(t('noExpenses'),
                              style: TextStyle(
                                  color: Theme.of(context).hintColor))))
                else
                  Card(
                    child: Column(children: [
                      ..._expenses.map((e) => ListTile(
                            dense: true,
                            title: Text(e.category),
                            subtitle:
                                e.notes.isEmpty ? null : Text(e.notes),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(fmtMoney(context, e.amount),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 20),
                                  onPressed: () async {
                                    await _db.deleteDailyExpense(e.id!);
                                    _load();
                                  },
                                ),
                              ],
                            ),
                          )),
                      const Divider(height: 1),
                      ListTile(
                        dense: true,
                        title: Text(t('total'),
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        trailing: Text(fmtMoney(context, _expTotal),
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  ),
                const SizedBox(height: 16),
                _sectionTitle(t('dailyResult'), Icons.calculate_outlined),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(children: [
                      _kv(t('sales'), fmtMoney(context, _sales)),
                      _kv(t('productCost'),
                          '- ${fmtMoney(context, _productCost)}'),
                      _kv(t('dailyExpenses'),
                          '- ${fmtMoney(context, _expTotal)}'),
                      const Divider(),
                      _kv(t('dailyProfit'), fmtMoney(context, _dailyProfit),
                          bold: true,
                          color: _dailyProfit >= 0
                              ? AppColors.good
                              : AppColors.bad),
                    ]),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(t('save'))),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _sectionTitle(String title, IconData icon, {Widget? action}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
            child: Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700))),
        if (action != null) action,
      ]),
    );
  }

  Widget _kv(String k, String v, {bool bold = false, Color? color}) {
    final style = TextStyle(
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400, color: color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(k, style: style), Text(v, style: style)],
      ),
    );
  }
}
