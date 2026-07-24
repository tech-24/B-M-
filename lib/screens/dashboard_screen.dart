import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/localization.dart';
import '../data/db.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import 'daily_records_screen.dart';
import 'project_overview_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Project project;
  final ValueChanged<int> onNavigate;
  const DashboardScreen(
      {super.key, required this.project, required this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _db = AppDatabase.instance;
  MonthlyReport? _report;
  int _inventoryCount = 0;
  int _lowStockCount = 0;
  List<DailyRecord> _recent = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final month = currentMonthStr();
    final pid = widget.project.id!;
    final report = await _db.monthlyReport(pid, month);
    final inv = await _db.getInventory(pid);
    final recent = await _db.getDailyRecords(pid, limit: 5);
    if (!mounted) return;
    setState(() {
      _report = report;
      _inventoryCount = inv.length;
      _lowStockCount = inv
          .where((i) =>
              i.purchaseQuantity > 0 && i.remaining / i.purchaseQuantity <= .15)
          .length;
      _recent = recent;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context).t;
    final r = _report;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.project.name),
        actions: [
          IconButton(
            tooltip: t('projectOverview'),
            icon: const Icon(Icons.assessment_outlined),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        ProjectOverviewScreen(project: widget.project))),
          ),
        ],
      ),
      body: _loading || r == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(monthLabel(context, currentMonthStr()),
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(color: Theme.of(context).hintColor)),
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
                          label: t('revenue'),
                          value: fmtMoney(context, r.totalSales),
                          icon: Icons.payments_outlined),
                      StatCard(
                          label: t('totalExpenses'),
                          value: fmtMoney(
                              context, r.totalExpenses + r.totalCosts),
                          icon: Icons.receipt_long_outlined,
                          color: AppColors.bad),
                      StatCard(
                          label: t('netProfit'),
                          value: fmtMoney(context, r.netProfit),
                          icon: Icons.trending_up,
                          color:
                              r.netProfit >= 0 ? AppColors.good : AppColors.bad),
                      StatCard(
                          label: t('productCost'),
                          value: fmtMoney(context, r.productCost),
                          icon: Icons.price_change_outlined,
                          color: AppColors.accent),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.inventory_2_outlined,
                          color: AppColors.primary),
                      title: Text(t('inventoryStatus')),
                      subtitle: Text('$_inventoryCount ${t('items')}'
                          '${_lowStockCount > 0 ? ' — $_lowStockCount ${t('lowStock')}' : ''}'),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () => widget.onNavigate(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(t('quickActions'),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.today, size: 18),
                        label: Text(t('addDailyRecord')),
                        onPressed: () async {
                          await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => DayDetailScreen(
                                      project: widget.project,
                                      date: todayStr())));
                          _load();
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.receipt, size: 18),
                        label: Text(t('addExpense')),
                        onPressed: () => widget.onNavigate(3),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.add_box_outlined, size: 18),
                        label: Text(t('addInventoryItem')),
                        onPressed: () => widget.onNavigate(2),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.insights, size: 18),
                        label: Text(t('viewReports')),
                        onPressed: () => widget.onNavigate(4),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(t('recentRecords'),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  if (_recent.isEmpty)
                    EmptyState(
                        icon: Icons.event_note_outlined,
                        message: t('noRecords'))
                  else
                    ..._recent.map((rec) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.event_note_outlined),
                            title: Text(dateLabel(context, rec.date)),
                            subtitle: Text(
                                '${t('sales')}: ${fmtMoney(context, rec.salesAmount)}'),
                            trailing: const Icon(Icons.chevron_left),
                            onTap: () async {
                              await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => DayDetailScreen(
                                          project: widget.project,
                                          date: rec.date)));
                              _load();
                            },
                          ),
                        )),
                ],
              ),
            ),
    );
  }
}
