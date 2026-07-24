import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/localization.dart';
import '../data/db.dart';
import '../models/models.dart';
import '../widgets/common.dart';

/// A screen kept deliberately separate from the day-to-day daily
/// expenses: lets the owner log one-time foundational costs (a car,
/// equipment...) and see, at a glance, whether the project's accumulated
/// profit since day one has covered that initial investment yet.
class ProjectOverviewScreen extends StatefulWidget {
  final Project project;
  const ProjectOverviewScreen({super.key, required this.project});

  @override
  State<ProjectOverviewScreen> createState() => _ProjectOverviewScreenState();
}

class _ProjectOverviewScreenState extends State<ProjectOverviewScreen> {
  final _db = AppDatabase.instance;
  List<InitialInvestment> _items = [];
  PeriodReport? _allTime;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pid = widget.project.id!;
    final startDate = widget.project.createdAt.substring(0, 10);
    final results = await Future.wait([
      _db.getInitialInvestments(pid),
      _db.rangeReport(pid, startDate, todayStr()),
    ]);
    if (!mounted) return;
    setState(() {
      _items = results[0] as List<InitialInvestment>;
      _allTime = results[1] as PeriodReport;
      _loading = false;
    });
  }

  double get _totalSetup => _items.fold<double>(0.0, (s, i) => s + i.amount);
  double get _totalOperating =>
      _allTime == null ? 0 : _allTime!.totalCosts + _allTime!.totalExpenses;
  double get _totalEarned => _allTime?.totalSales ?? 0;
  double get _totalSpent => _totalSetup + _totalOperating;
  double get _net => _totalEarned - _totalSpent;

  Future<void> _addOrEdit({InitialInvestment? existing}) async {
    final t = L10n.of(context).t;
    final nameCtl = TextEditingController(text: existing?.name ?? '');
    final amountCtl = TextEditingController(
        text: existing == null ? '' : fmtNum(existing.amount));
    final notesCtl = TextEditingController(text: existing?.notes ?? '');
    var date = existing?.date ?? todayStr();
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(existing == null
              ? t('addInitialInvestment')
              : t('edit')),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                    controller: nameCtl,
                    decoration:
                        InputDecoration(labelText: t('investmentName')),
                    validator: (v) => validateRequired(ctx, v)),
                const SizedBox(height: 12),
                TextFormField(
                    controller: amountCtl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: t('amount'), suffixText: t('sar')),
                    validator: (v) => validateNumber(ctx, v)),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: Text(dateLabel(context, date)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.parse(date),
                      firstDate: DateTime(2015),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDlg(() => date =
                          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
                    }
                  },
                ),
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
    final item = InitialInvestment(
      id: existing?.id,
      projectId: widget.project.id!,
      name: nameCtl.text.trim(),
      amount: parseNum(amountCtl.text.replaceAll(',', '')),
      date: date,
      notes: notesCtl.text.trim(),
    );
    if (existing == null) {
      await _db.insertInitialInvestment(item);
    } else {
      await _db.updateInitialInvestment(item);
    }
    _load();
  }

  Future<void> _delete(InitialInvestment item) async {
    final t = L10n.of(context).t;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('delete')),
        content: Text(t('deleteProjectConfirm')),
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
    if (ok == true) {
      await _db.deleteInitialInvestment(item.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context).t;
    final net = _net;

    return Scaffold(
      appBar: AppBar(title: Text(t('projectOverview'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(),
        icon: const Icon(Icons.add),
        label: Text(t('addInitialInvestment')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: (net >= 0 ? AppColors.good : AppColors.bad)
                        .withOpacity(.08),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t('netAllTime'),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                      color: Theme.of(context).hintColor)),
                          const SizedBox(height: 6),
                          Text(fmtMoney(context, net),
                              style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: net >= 0
                                      ? AppColors.good
                                      : AppColors.bad)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount:
                        MediaQuery.of(context).size.width > 700 ? 4 : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.6,
                    children: [
                      StatCard(
                          label: t('totalEarned'),
                          value: fmtMoney(context, _totalEarned),
                          icon: Icons.payments_outlined,
                          color: AppColors.good),
                      StatCard(
                          label: t('totalSpent'),
                          value: fmtMoney(context, _totalSpent),
                          icon: Icons.receipt_long_outlined,
                          color: AppColors.bad),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Column(children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                              Icons.directions_car_filled_outlined),
                          title: Text(t('setupExpenses')),
                          trailing: Text(fmtMoney(context, _totalSetup),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.settings_outlined),
                          title: Text(t('operatingExpenses')),
                          trailing: Text(fmtMoney(context, _totalOperating),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ]),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                        '${t('sinceProjectStart')}: '
                        '${dateLabel(context, widget.project.createdAt.substring(0, 10))}',
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).hintColor)),
                  ),
                  const SizedBox(height: 16),
                  Text(t('initialInvestments'),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  if (_items.isEmpty)
                    EmptyState(
                        icon: Icons.directions_car_filled_outlined,
                        message: t('noInitialInvestments'))
                  else
                    ..._items.map((i) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(
                                Icons.directions_car_filled_outlined),
                            title: Text(i.name),
                            subtitle: Text(dateLabel(context, i.date)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(fmtMoney(context, i.amount),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                PopupMenuButton<String>(
                                  onSelected: (v) {
                                    if (v == 'edit') {
                                      _addOrEdit(existing: i);
                                    }
                                    if (v == 'delete') _delete(i);
                                  },
                                  itemBuilder: (_) => [
                                    PopupMenuItem(
                                        value: 'edit',
                                        child: Text(t('edit'))),
                                    PopupMenuItem(
                                        value: 'delete',
                                        child: Text(t('delete'))),
                                  ],
                                ),
                              ],
                            ),
                            onTap: () => _addOrEdit(existing: i),
                          ),
                        )),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
