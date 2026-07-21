import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../core/app_theme.dart';
import '../core/localization.dart';
import '../core/report_pdf.dart';
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

  // ---------------- Printable period summary ----------------

  String _shiftDate(String dateStr, {int months = 0, int days = 0}) {
    var d = DateFormat('yyyy-MM-dd').parse(dateStr);
    if (months != 0) d = DateTime(d.year, d.month - months, d.day);
    if (days != 0) d = d.add(Duration(days: days));
    return DateFormat('yyyy-MM-dd').format(d);
  }

  Future<void> _openPrintSheet() async {
    final t = L10n.of(context).t;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t('selectPeriod'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              for (final opt in const [
                ['1m', 'oneMonth'],
                ['3m', 'threeMonths'],
                ['6m', 'sixMonths'],
                ['9m', 'nineMonths'],
                ['1y', 'oneYear'],
              ])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: Text(t(opt[1])),
                  onTap: () => Navigator.pop(ctx, opt[0]),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.date_range_outlined),
                title: Text(t('customRange')),
                onTap: () => Navigator.pop(ctx, 'custom'),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;

    String start;
    String end = todayStr();
    switch (choice) {
      case '1m':
        start = _shiftDate(end, months: 1);
        break;
      case '3m':
        start = _shiftDate(end, months: 3);
        break;
      case '6m':
        start = _shiftDate(end, months: 6);
        break;
      case '9m':
        start = _shiftDate(end, months: 9);
        break;
      case '1y':
        start = _shiftDate(end, months: 12);
        break;
      case 'custom':
        final now = DateTime.now();
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(now.year - 5),
          lastDate: now,
          initialDateRange: DateTimeRange(
              start: now.subtract(const Duration(days: 30)), end: now),
          helpText: t('chooseDateRange'),
        );
        if (picked == null || !mounted) return;
        start = DateFormat('yyyy-MM-dd').format(picked.start);
        end = DateFormat('yyyy-MM-dd').format(picked.end);
        break;
      default:
        return;
    }
    await _generateAndPrint(start, end);
  }

  Future<void> _generateAndPrint(String start, String end) async {
    final t = L10n.of(context).t;
    final lang = L10n.of(context).locale.languageCode;
    final isAr = L10n.of(context).isAr;
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 16),
          Expanded(child: Text(t('preparingReport'))),
        ]),
      ),
    );

    Uint8List? bytes;
    try {
      final report = await _db.rangeReport(widget.project.id!, start, end);

      Uint8List? logoBytes;
      final logoUrl = widget.project.logoUrl;
      if (logoUrl != null && logoUrl.isNotEmpty) {
        try {
          final resp = await http.get(Uri.parse(logoUrl));
          if (resp.statusCode == 200) logoBytes = resp.bodyBytes;
        } catch (_) {
          // Logo fetch failing shouldn't block the report itself.
        }
      }

      final df = DateFormat.yMMMd(lang);
      final periodLabel =
          '${df.format(DateFormat('yyyy-MM-dd').parse(start))} — ${df.format(DateFormat('yyyy-MM-dd').parse(end))}';
      final generatedOn =
          '${t('generatedOn')}: ${DateFormat.yMMMd(lang).add_jm().format(DateTime.now())}';

      bytes = await buildPeriodReportPdf(
        projectName: widget.project.name,
        periodLabel: periodLabel,
        generatedOnLabel: generatedOn,
        report: report,
        isArabic: isAr,
        money: (v) => fmtNum(v) + ' ${t('sar')}',
        labels: {
          'netProfit': t('netProfit'),
          'breakdown': t('monthlyReport'),
          'totalRevenue': t('totalRevenue'),
          'productCost': t('productCost'),
          'inventoryConsumption': t('inventoryConsumption'),
          'dailyExpenses': t('dailyExpenses'),
          'fixedExpenses': t('fixedExpenses'),
        },
        logoBytes: logoBytes,
      );
    } catch (e) {
      // Close the "preparing" dialog exactly once, then stop — do NOT fall
      // through to printing, and never pop again below.
      if (mounted) Navigator.pop(context);
      messenger.showSnackBar(SnackBar(
          content: Text('${t('preparingReport')}: $e'),
          duration: const Duration(seconds: 6)));
      return;
    }

    // PDF built successfully — close the "preparing" dialog once.
    if (mounted) Navigator.pop(context);

    // Printing is a separate step: if the print/save dialog itself fails
    // (e.g. blocked by the browser), just show an error — never touch
    // Navigator again here, so the report screen is never accidentally
    // closed.
    try {
      await Printing.sharePdf(
        bytes: bytes!,
        filename: '${widget.project.name}_${start}_$end.pdf',
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('$e'), duration: const Duration(seconds: 6)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context).t;
    final r = _report;
    return Scaffold(
      appBar: AppBar(title: Text(t('reports')), actions: [
        IconButton(
          tooltip: t('printSummary'),
          icon: const Icon(Icons.print_outlined),
          onPressed: _loading ? null : _openPrintSheet,
        ),
      ]),
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
    final rawMax = items.fold<double>(0, (m, e) => e.$2 > m ? e.$2 : m);
    final maxVal = rawMax < 1 ? 1.0 : rawMax;

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
    final ratioRaw = maxVal == 0 ? 0.0 : value / maxVal;
    final double ratio = ratioRaw < 0 ? 0.0 : (ratioRaw > 1 ? 1.0 : ratioRaw);
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
            value: ratio,
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
