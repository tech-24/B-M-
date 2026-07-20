import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_theme.dart';
import '../core/localization.dart';
import '../data/db.dart';
import '../models/models.dart';
import '../widgets/common.dart';

class ReportsScreen extends StatefulWidget {
  final Project project;
  const ReportsScreen({super.key, required this.project});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _db = AppDatabase.instance;
  String _month = currentMonthStr();
  MonthlyReport? _report;
  List<MonthlyReport> _year = [];
  bool _loading = true;

  int get _yearNum => int.parse(_month.substring(0, 4));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pid = widget.project.id!;
    final report = await _db.monthlyReport(pid, _month);
    final year = await _db.yearlyReports(pid, _yearNum);
    if (!mounted) return;
    setState(() {
      _report = report;
      _year = year;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context).t;
    final r = _report;
    return Scaffold(
      appBar: AppBar(title: Text(t('reports'))),
      body: _loading || r == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: MonthPicker(
                          month: _month,
                          onChanged: (m) {
                            setState(() => _month = m);
                            _load();
                          }),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _profitHero(context, r),
                  const SizedBox(height: 16),
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
                          label: t('totalRevenue'),
                          value: fmtMoney(context, r.totalSales),
                          icon: Icons.payments_outlined,
                          color: AppColors.primary),
                      StatCard(
                          label: t('totalCosts'),
                          value: fmtMoney(context, r.totalCosts),
                          icon: Icons.price_change_outlined,
                          color: AppColors.accent),
                      StatCard(
                          label: t('totalExpenses'),
                          value: fmtMoney(context, r.totalExpenses),
                          icon: Icons.receipt_long_outlined,
                          color: AppColors.bad),
                      StatCard(
                          label: t('profitPercent'),
                          value: '${r.profitPercent.toStringAsFixed(1)}%',
                          icon: Icons.percent,
                          color:
                              r.netProfit >= 0 ? AppColors.good : AppColors.bad),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle(context, t('monthlyReport'),
                      Icons.receipt_long_outlined),
                  const SizedBox(height: 10),
                  _breakdownCard(context, r),
                  const SizedBox(height: 28),
                  _sectionTitle(context, '${t('yearlyOverview')} — $_yearNum',
                      Icons.calendar_view_month_outlined),
                  const SizedBox(height: 12),
                  _chartCard(
                      title: t('sales'),
                      icon: Icons.trending_up,
                      color: AppColors.primary,
                      values: _year.map((m) => m.totalSales).toList()),
                  const SizedBox(height: 12),
                  _chartCard(
                      title: t('expenses'),
                      icon: Icons.trending_down,
                      color: AppColors.bad,
                      values: _year
                          .map((m) => m.totalExpenses + m.totalCosts)
                          .toList()),
                  const SizedBox(height: 12),
                  _chartCard(
                      title: t('profit'),
                      icon: Icons.show_chart,
                      color: AppColors.good,
                      values: _year.map((m) => m.netProfit).toList()),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title, IconData icon) {
    return Row(children: [
      Icon(icon, size: 20, color: AppColors.primary),
      const SizedBox(width: 8),
      Text(title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700)),
    ]);
  }

  Widget _profitHero(BuildContext context, MonthlyReport r) {
    final t = L10n.of(context).t;
    final good = r.netProfit >= 0;
    final color = good ? AppColors.good : AppColors.bad;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(.16),
            color.withOpacity(.05),
          ],
        ),
        border: Border.all(color: color.withOpacity(.25)),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(.18),
            shape: BoxShape.circle,
          ),
          child: Icon(good ? Icons.trending_up : Icons.trending_down,
              color: color, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t('netProfit'),
                  style: TextStyle(
                      color: Theme.of(context).hintColor, fontSize: 13)),
              const SizedBox(height: 4),
              Text(fmtMoney(context, r.netProfit),
                  style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(.15),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text('${r.profitPercent.toStringAsFixed(1)}%',
              style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  Widget _breakdownCard(BuildContext context, MonthlyReport r) {
    final t = L10n.of(context).t;
    final items = [
      (t('productCost'), r.productCost, AppColors.accent),
      (t('inventoryConsumption'), r.inventoryConsumption, AppColors.primary),
      (t('dailyExpenses'), r.dailyExpenses, AppColors.bad),
      (t('fixedExpenses'), r.fixedExpenses,
          AppColors.bad.withOpacity(.65)),
    ];
    final maxVal =
        items.fold<double>(0, (m, e) => e.$2 > m ? e.$2 : m).clamp(1, double.infinity);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t('totalRevenue'),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(fmtMoney(context, r.totalSales),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1),
          ),
          for (final item in items) ...[
            _breakdownRow(context, item.$1, item.$2, item.$3, maxVal),
            const SizedBox(height: 14),
          ],
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t('netProfit'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16)),
              Text(fmtMoney(context, r.netProfit),
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: r.netProfit >= 0
                          ? AppColors.good
                          : AppColors.bad)),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _breakdownRow(
      BuildContext context, String label, double value, Color color, double maxVal) {
    final ratio = (value / maxVal).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: Theme.of(context).hintColor)),
            ]),
            Text('- ${fmtMoney(context, value)}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio == 0 ? 0 : ratio,
            minHeight: 6,
            backgroundColor: color.withOpacity(.12),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }

  Widget _chartCard(
      {required String title,
      required IconData icon,
      required Color color,
      required List<double> values}) {
    final maxAbs = values.fold<double>(
        0, (m, v) => v.abs() > m ? v.abs() : m);
    final lang = L10n.of(context).locale.languageCode;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: maxAbs == 0
                  ? Center(
                      child: Text(L10n.of(context).t('noData'),
                          style: TextStyle(
                              color: Theme.of(context).hintColor)))
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: maxAbs / 3,
                          getDrawingHorizontalLine: (v) => FlLine(
                              color: Theme.of(context)
                                  .dividerColor
                                  .withOpacity(.4),
                              strokeWidth: 1),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (v, meta) {
                                final m = v.toInt() + 1;
                                final label = DateFormat.MMM(lang).format(
                                    DateTime(_yearNum, m));
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(label,
                                      style: TextStyle(
                                          fontSize: 9,
                                          color: Theme.of(context)
                                              .hintColor)),
                                );
                              },
                            ),
                          ),
                        ),
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (group, gi, rod, ri) =>
                                BarTooltipItem(
                              fmtNum(rod.toY),
                              const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        barGroups: [
                          for (var i = 0; i < values.length; i++)
                            BarChartGroupData(x: i, barRods: [
                              BarChartRodData(
                                toY: values[i],
                                color: values[i] >= 0
                                    ? color
                                    : AppColors.bad,
                                width: 14,
                                borderRadius: BorderRadius.circular(4),
                                backDrawRodData: BackgroundBarChartRodData(
                                  show: true,
                                  toY: maxAbs,
                                  color: color.withOpacity(.06),
                                ),
                              ),
                            ]),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
