import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_theme.dart';
import '../core/localization.dart';

String fmtMoney(BuildContext context, double v) {
  final n = NumberFormat('#,##0.##');
  return '${n.format(v)} ${L10n.of(context).t('sar')}';
}

String fmtNum(double v) => NumberFormat('#,##0.##').format(v);

String todayStr() => DateFormat('yyyy-MM-dd').format(DateTime.now());
String currentMonthStr() => DateFormat('yyyy-MM').format(DateTime.now());

String monthLabel(BuildContext context, String month) {
  final d = DateFormat('yyyy-MM').parse(month);
  return DateFormat.yMMMM(L10n.of(context).locale.languageCode).format(d);
}

String dateLabel(BuildContext context, String date) {
  final d = DateFormat('yyyy-MM-dd').parse(date);
  return DateFormat.yMMMMEEEEd(L10n.of(context).locale.languageCode).format(d);
}

/// Small labelled statistic card used on dashboards.
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 18, color: c),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(context).hintColor)),
              ),
            ]),
            const SizedBox(height: 8),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

/// Month navigation bar (previous / label / next).
class MonthPicker extends StatelessWidget {
  final String month; // yyyy-MM
  final ValueChanged<String> onChanged;

  const MonthPicker({super.key, required this.month, required this.onChanged});

  void _shift(int delta) {
    final d = DateFormat('yyyy-MM').parse(month);
    final next = DateTime(d.year, d.month + delta);
    onChanged(DateFormat('yyyy-MM').format(next));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
            onPressed: () => _shift(-1),
            icon: const Icon(Icons.chevron_left)),
        Text(monthLabel(context, month),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        IconButton(
            onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
      ],
    );
  }
}

/// Simple empty-state placeholder.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const EmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Theme.of(context).hintColor),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).hintColor)),
          ],
        ),
      ),
    );
  }
}

/// Reusable numeric field validator helpers.
String? validateRequired(BuildContext context, String? v) =>
    (v == null || v.trim().isEmpty) ? L10n.of(context).t('required') : null;

String? validateNumber(BuildContext context, String? v,
    {bool required = true}) {
  if (v == null || v.trim().isEmpty) {
    return required ? L10n.of(context).t('required') : null;
  }
  return double.tryParse(v.trim()) == null
      ? L10n.of(context).t('invalidNumber')
      : null;
}

double parseNum(String? v) => double.tryParse((v ?? '').trim()) ?? 0;
