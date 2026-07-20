import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_theme.dart';
import '../core/localization.dart';
import '../data/db.dart';
import '../models/models.dart';
import '../widgets/common.dart';

/// List of cost items (e.g. "Vanilla ice cream", "Gasoline"). Each item is
/// opened to manage its own monthly unit-cost history.
class CostSettingsScreen extends StatefulWidget {
  final Project project;
  const CostSettingsScreen({super.key, required this.project});

  @override
  State<CostSettingsScreen> createState() => _CostSettingsScreenState();
}

class _CostSettingsScreenState extends State<CostSettingsScreen> {
  final _db = AppDatabase.instance;
  List<CostItem> _items = [];
  Map<int, CostEntry?> _latest = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pid = widget.project.id!;
    final items = await _db.getCostItems(pid);
    final latest = <int, CostEntry?>{};
    for (final it in items) {
      latest[it.id!] = await _db.latestCostEntry(pid, it.id!);
    }
    if (!mounted) return;
    setState(() {
      _items = items;
      _latest = latest;
      _loading = false;
    });
  }

  Future<void> _addOrEditItem({CostItem? existing}) async {
    final t = L10n.of(context).t;
    final nameCtl = TextEditingController(text: existing?.name ?? '');
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? t('addCostItem') : t('edit')),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameCtl,
            decoration: InputDecoration(labelText: t('itemName')),
            validator: (v) => validateRequired(ctx, v),
            autofocus: true,
          ),
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

    if (existing == null) {
      await _db.insertCostItem(
          CostItem(projectId: widget.project.id!, name: nameCtl.text.trim()));
    } else {
      await _db.updateCostItem(CostItem(
          id: existing.id,
          projectId: widget.project.id!,
          name: nameCtl.text.trim()));
    }
    _load();
  }

  Future<void> _deleteItem(CostItem item) async {
    final t = L10n.of(context).t;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('deleteCostItem')),
        content: Text(t('deleteCostItemConfirm')),
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
      await _db.deleteCostItem(item.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context).t;
    return Scaffold(
      appBar: AppBar(title: Text(t('costSettings'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(t('costItemsHint'),
                        style:
                            TextStyle(color: Theme.of(context).hintColor)),
                  ),
                ),
                const SizedBox(height: 16),
                if (_items.isEmpty)
                  EmptyState(
                      icon: Icons.price_change_outlined,
                      message: t('noCostItems'))
                else
                  ..._items.map((it) {
                    final latest = _latest[it.id];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading:
                            const Icon(Icons.local_drink_outlined),
                        title: Text(it.name),
                        subtitle: Text(latest == null
                            ? t('noCostSet')
                            : '${t('currentCost')}: ${fmtMoney(context, latest.cost)} '
                                '(${monthLabel(context, latest.month)})'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') _addOrEditItem(existing: it);
                            if (v == 'delete') _deleteItem(it);
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                                value: 'edit', child: Text(t('edit'))),
                            PopupMenuItem(
                                value: 'delete', child: Text(t('delete'))),
                          ],
                        ),
                        onTap: () async {
                          await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => CostItemHistoryScreen(
                                      project: widget.project, item: it)));
                          _load();
                        },
                      ),
                    );
                  }),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEditItem(),
        icon: const Icon(Icons.add),
        label: Text(t('addCostItem')),
      ),
    );
  }
}

/// Monthly unit-cost history for a single [CostItem].
class CostItemHistoryScreen extends StatefulWidget {
  final Project project;
  final CostItem item;
  const CostItemHistoryScreen(
      {super.key, required this.project, required this.item});

  @override
  State<CostItemHistoryScreen> createState() => _CostItemHistoryScreenState();
}

class _CostItemHistoryScreenState extends State<CostItemHistoryScreen> {
  final _db = AppDatabase.instance;
  List<CostEntry> _costs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final costs =
        await _db.getCostEntries(widget.project.id!, widget.item.id!);
    if (!mounted) return;
    setState(() {
      _costs = costs;
      _loading = false;
    });
  }

  Future<void> _addOrEdit({CostEntry? existing}) async {
    final t = L10n.of(context).t;
    var month = existing?.month ?? currentMonthStr();
    final costCtl = TextEditingController(
        text: existing == null ? '' : fmtNum(existing.cost));
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(widget.item.name),
          content: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_month),
                label: Text(monthLabel(ctx, month)),
                onPressed: existing != null
                    ? null
                    : () async {
                        final d = DateFormat('yyyy-MM').parse(month);
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: d,
                          firstDate: DateTime(d.year - 5),
                          lastDate: DateTime(d.year + 1, 12),
                        );
                        if (picked != null) {
                          setDlg(() =>
                              month = DateFormat('yyyy-MM').format(picked));
                        }
                      },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: costCtl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: t('costPerUnit'), suffixText: t('sar')),
                validator: (v) => validateNumber(ctx, v),
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
      await _db.upsertCostEntry(CostEntry(
        projectId: widget.project.id!,
        itemId: widget.item.id!,
        month: month,
        cost: parseNum(costCtl.text.replaceAll(',', '')),
      ));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context).t;
    return Scaffold(
      appBar: AppBar(title: Text(widget.item.name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(t('itemCostHint'),
                        style:
                            TextStyle(color: Theme.of(context).hintColor)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(t('costHistory'),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (_costs.isEmpty)
                  EmptyState(
                      icon: Icons.price_change_outlined,
                      message: t('noData'))
                else
                  ..._costs.map((c) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.calendar_month_outlined),
                          title: Text(monthLabel(context, c.month)),
                          subtitle: Text(
                              '${t('costPerUnit')}: ${fmtMoney(context, c.cost)}'),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _addOrEdit(existing: c)),
                            IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  await _db.deleteCostEntry(c.id!);
                                  _load();
                                }),
                          ]),
                        ),
                      )),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEdit(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
