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
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                MonthPicker(
                    month: _month,
                    onChanged: (m) {
                      setState(() => _month = m);
                      _load();
                    }),
                const SizedBox(height: 8),
                Text(t('monthlyReport'),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      _row(t('totalRevenue'),
                          fmtMoney(context, r.totalSales)),
                      _row(t('productCost'),
                          '- ${fmtMoney(context, r.productCost)}'),
                      _row(t('dailyExpenses'),
                          '- ${fmtMoney(context, r.dailyExpenses)}'),
                      _row(t('inventoryConsumption'),
                          '- ${fmtMoney(context, r.inventoryConsumption)}'),
                      _row(t('fixedExpenses'),
                          '- ${fmtMoney(context, r.fixedExpenses)}'),
                      const Divider(height: 24),
                      _row(t('netProfit'), fmtMoney(context, r.netProfit),
                          bold: true,
                          color: r.netProfit >= 0
                              ? AppColors.good
                              : AppColors.bad),
                      _row(t('profitPercent'),
                          '${r.profitPercent.toStringAsFixed(1)}%',
                          bold: true),
                    ]),
                  ),
                ),
                const SizedBox(height: 24),
                Text('${t('yearlyOverview')} — $_yearNum',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                _chartCard(
                    title: t('sales'),
                    color: AppColors.primary,
                    values: _year.map((m) => m.totalSales).toList()),
                const SizedBox(height: 12),
                _chartCard(
                    title: t('expenses'),
                    color: AppColors.bad,
                    values: _year
                        .map((m) => m.totalExpenses + m.totalCosts)
                        .toList()),
                const SizedBox(height: 12),
                _chartCard(
                    title: t('profit'),
                    color: AppColors.good,
                    values: _year.map((m) => m.netProfit).toList()),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _row(String k, String v, {bool bold = false, Color? color}) {
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

  Widget _chartCard(
      {required String title,
      required Color color,
      required List<double> values}) {
    final maxAbs = values.fold<double>(
        0, (m, v) => v.abs() > m ? v.abs() : m);
    final lang = L10n.of(context).locale.languageCode;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
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
                        gridData: const FlGridData(show: false),
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
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(label,
                                      style:
                                          const TextStyle(fontSize: 9)),
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
                                width: 12,
                                borderRadius: BorderRadius.circular(3),
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
