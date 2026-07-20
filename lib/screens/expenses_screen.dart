import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_theme.dart';
import '../core/localization.dart';
import '../data/db.dart';
import '../models/models.dart';
import '../widgets/common.dart';

/// Two tabs: variable daily expenses + fixed monthly expenses.
class ExpensesScreen extends StatefulWidget {
  final Project project;
  const ExpensesScreen({super.key, required this.project});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  final _db = AppDatabase.instance;

  String _month = currentMonthStr();
  List<DailyExpense> _daily = [];
  List<FixedExpense> _fixed = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pid = widget.project.id!;
    final daily = await _db.getDailyExpenses(pid, month: _month);
    final fixed = await _db.getFixedExpenses(pid);
    if (!mounted) return;
    setState(() {
      _daily = daily;
      _fixed = fixed;
      _loading = false;
    });
  }

  // ---------- Daily expense dialog ----------
  Future<void> _editDaily({DailyExpense? existing}) async {
    final t = L10n.of(context).t;
    var date = existing?.date ?? todayStr();
    final catCtl = TextEditingController(text: existing?.category ?? '');
    final amountCtl = TextEditingController(
        text: existing == null ? '' : fmtNum(existing.amount));
    final notesCtl = TextEditingController(text: existing?.notes ?? '');
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(existing == null ? t('addExpense') : t('edit')),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(dateLabel(ctx, date)),
                  onPressed: () async {
                    final d = DateFormat('yyyy-MM-dd').parse(date);
                    final picked = await showDatePicker(
                        context: ctx,
                        initialDate: d,
                        firstDate: DateTime(d.year - 5),
                        lastDate: DateTime(d.year + 1));
                    if (picked != null) {
                      setDlg(() =>
                          date = DateFormat('yyyy-MM-dd').format(picked));
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                    controller: catCtl,
                    decoration: InputDecoration(labelText: t('category')),
                    validator: (v) => validateRequired(ctx, v)),
                const SizedBox(height: 12),
                TextFormField(
                    controller: amountCtl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: t('amount'), suffixText: t('sar')),
                    validator: (v) => validateNumber(ctx, v)),
                const SizedBox(height: 12),
                TextFormField(
                    controller: notesCtl,
                    decoration: InputDecoration(labelText: t('notes'))),
              ]),
            ),
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

    if (ok != true) return;
    final e = DailyExpense(
      id: existing?.id,
      projectId: widget.project.id!,
      date: date,
      category: catCtl.text.trim(),
      amount: parseNum(amountCtl.text.replaceAll(',', '')),
      notes: notesCtl.text.trim(),
    );
    if (existing == null) {
      await _db.insertDailyExpense(e);
    } else {
      await _db.updateDailyExpense(e);
    }
    _load();
  }

  // ---------- Fixed expense dialog ----------
  Future<void> _editFixed({FixedExpense? existing}) async {
    final t = L10n.of(context).t;
    final nameCtl = TextEditingController(text: existing?.name ?? '');
    final amountCtl = TextEditingController(
        text: existing == null ? '' : fmtNum(existing.monthlyAmount));
    final notesCtl = TextEditingController(text: existing?.notes ?? '');
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? t('addExpense') : t('edit')),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
                controller: nameCtl,
                decoration: InputDecoration(labelText: t('expenseName')),
                validator: (v) => validateRequired(ctx, v)),
            const SizedBox(height: 12),
            TextFormField(
                controller: amountCtl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: t('monthlyAmount'), suffixText: t('sar')),
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
              child: Text(t('save'))),
        ],
      ),
    );

    if (ok != true) return;
    final e = FixedExpense(
      id: existing?.id,
      projectId: widget.project.id!,
      name: nameCtl.text.trim(),
      monthlyAmount: parseNum(amountCtl.text.replaceAll(',', '')),
      startMonth: existing?.startMonth ?? currentMonthStr(),
      notes: notesCtl.text.trim(),
    );
    if (existing == null) {
      await _db.insertFixedExpense(e);
    } else {
      await _db.updateFixedExpense(e);
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context).t;
    return Scaffold(
      appBar: AppBar(
        title: Text(t('expenses')),
        bottom: TabBar(controller: _tab, tabs: [
          Tab(text: t('daily')),
          Tab(text: t('fixed')),
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tab,
              children: [_dailyTab(), _fixedTab()],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            _tab.index == 0 ? _editDaily() : _editFixed(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _dailyTab() {
    final t = L10n.of(context).t;
    final total = _daily.fold(0.0, (s, e) => s + e.amount);
    // Group by date for a per-day breakdown.
    final byDate = <String, List<DailyExpense>>{};
    for (final e in _daily) {
      byDate.putIfAbsent(e.date, () => []).add(e);
    }
    final dates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: MonthPicker(
            month: _month,
            onChanged: (m) {
              setState(() => _month = m);
              _load();
            }),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Card(
          color: AppColors.primary.withOpacity(.08),
          child: ListTile(
            title: Text(t('total')),
            trailing: Text(fmtMoney(context, total),
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ),
      ),
      Expanded(
        child: _daily.isEmpty
            ? EmptyState(
                icon: Icons.receipt_long_outlined, message: t('noExpenses'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final d in dates) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6, top: 6),
                      child: Text(dateLabel(context, d),
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        children: byDate[d]!
                            .map((e) => ListTile(
                                  dense: true,
                                  title: Text(e.category),
                                  subtitle: e.notes.isEmpty
                                      ? null
                                      : Text(e.notes),
                                  trailing: Text(fmtMoney(context, e.amount),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  onTap: () => _editDaily(existing: e),
                                  onLongPress: () async {
                                    await _db.deleteDailyExpense(e.id!);
                                    _load();
                                  },
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    ]);
  }

  Widget _fixedTab() {
    final t = L10n.of(context).t;
    final total = _fixed.fold(0.0, (s, e) => s + e.monthlyAmount);
    return _fixed.isEmpty
        ? EmptyState(icon: Icons.home_work_outlined, message: t('noExpenses'))
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: AppColors.primary.withOpacity(.08),
                child: ListTile(
                  title: Text('${t('total')} / ${t('month')}'),
                  trailing: Text(fmtMoney(context, total),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 8),
              ..._fixed.map((e) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.home_work_outlined),
                      title: Text(e.name),
                      subtitle: e.notes.isEmpty ? null : Text(e.notes),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(fmtMoney(context, e.monthlyAmount),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                        IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () async {
                              await _db.deleteFixedExpense(e.id!);
                              _load();
                            }),
                      ]),
                      onTap: () => _editFixed(existing: e),
                    ),
                  )),
            ],
          );
  }
}
