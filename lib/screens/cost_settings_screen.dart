import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_theme.dart';
import '../core/localization.dart';
import '../data/db.dart';
import '../models/models.dart';
import '../widgets/common.dart';

/// List of cost items (e.g. "Vanilla ice cream", "Gasoline"). Each item is
/// opened to manage its own monthly unit-cost history.
///
/// This is a plain content widget (no Scaffold/AppBar/FAB) so it can be
/// embedded as a tab inside ExpensesScreen. [addItemKey] lets the parent
/// trigger "add item" from its own shared FloatingActionButton.
class CostItemsTab extends StatefulWidget {
  final Project project;
  const CostItemsTab({super.key, required this.project});

  @override
  State<CostItemsTab> createState() => CostItemsTabState();
}

class CostItemsTabState extends State<CostItemsTab> {
  final _db = AppDatabase.instance;
  List<CostItem> _items = [];
  List<CostItem> _archived = [];
  Map<int, CostEntry?> _latest = {};
  Map<int, InventoryItem> _inventoryById = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pid = widget.project.id!;
    final all = await _db.getCostItems(pid, includeArchived: true);
    final active = all.where((i) => !i.archived).toList();
    final archived = all.where((i) => i.archived).toList();
    final latest = <int, CostEntry?>{};
    for (final it in all) {
      if (!it.isLinked) latest[it.id!] = await _db.latestCostEntry(pid, it.id!);
    }
    final inventory =
        await _db.getInventory(pid, includeArchived: true);
    if (!mounted) return;
    setState(() {
      _items = active;
      _archived = archived;
      _latest = latest;
      _inventoryById = {for (final i in inventory) i.id!: i};
      _loading = false;
    });
  }

  /// Public so the parent screen's shared FAB can trigger "add item".
  Future<void> addItem() => _addOrEditItem();

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
    final messenger = ScaffoldMessenger.of(context);
    final hasHistory = _latest[item.id] != null ||
        await _itemHasAnyHistory(item.id!);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('deleteCostItem')),
        content: Text(hasHistory
            ? t('itemArchivedNotice')
            : t('confirmDeleteNoHistory')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t('cancel'))),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.bad),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(hasHistory ? t('archived') : t('delete'))),
        ],
      ),
    );
    if (ok == true) {
      final archived =
          await _db.smartDeleteCostItem(widget.project.id!, item.id!);
      messenger.showSnackBar(SnackBar(
          content: Text(archived ? t('itemArchivedNotice') : t('delete'))));
      _load();
    }
  }

  Future<bool> _itemHasAnyHistory(int itemId) async {
    // latestCostEntry already covers cost_history; also check usage.
    final usage =
        await _db.getCostUsage(widget.project.id!).then((all) => all
            .where((u) => u.itemId == itemId)
            .isNotEmpty);
    return usage;
  }

  Future<void> _restoreItem(CostItem item) async {
    await _db.unarchiveCostItem(item.id!);
    _load();
  }

  Future<void> _deletePermanently(CostItem item) async {
    final t = L10n.of(context).t;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('deletePermanently')),
        content: Text(t('deletePermanentlyWarning')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t('cancel'))),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.bad),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t('deletePermanently'))),
        ],
      ),
    );
    if (ok == true) {
      await _db.permanentlyDeleteCostItem(item.id!);
      messenger.showSnackBar(SnackBar(content: Text(t('deletedForever'))));
      _load();
    }
  }

  Future<void> _unlink(CostItem item) async {
    final t = L10n.of(context).t;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('unlinkFromInventory')),
        content: Text(t('unlinkConfirm')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t('unlinkFromInventory'))),
        ],
      ),
    );
    if (ok == true) {
      await _db.unlinkCostItem(item.id!);
      _load();
    }
  }

  Future<void> _editConsumptionRatio(CostItem item) async {
    final t = L10n.of(context).t;
    final messenger = ScaffoldMessenger.of(context);
    final ratioCtl =
        TextEditingController(text: fmtNum(item.consumptionPerUnit ?? 1));
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('editConsumptionRatio')),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ratioCtl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: t('consumptionPerUnit')),
            validator: (v) => validateNumber(ctx, v),
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
    if (ok == true) {
      await _db.updateCostItemLink(item.id!, item.linkedInventoryItemId,
          parseNum(ratioCtl.text.replaceAll(',', '')));
      messenger.showSnackBar(SnackBar(content: Text(t('ratioUpdated'))));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context).t;
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text(t('costItemsHint'),
                style: TextStyle(color: Theme.of(context).hintColor)),
          ),
        ),
        const SizedBox(height: 16),
        if (_items.isEmpty && _archived.isEmpty)
          EmptyState(
              icon: Icons.price_change_outlined, message: t('noCostItems'))
        else
          ..._items.map((it) {
            final latest = _latest[it.id];
            final linkedInv =
                it.isLinked ? _inventoryById[it.linkedInventoryItemId] : null;
            final autoPrice = linkedInv == null
                ? null
                : linkedInv.unitCost * (it.consumptionPerUnit ?? 1);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(it.isLinked
                    ? Icons.link
                    : Icons.local_drink_outlined),
                title: Text(it.name),
                subtitle: Text(it.isLinked
                    ? '${t('priceAutoFromInventory')}'
                        '${autoPrice != null ? ' — ${fmtMoney(context, autoPrice)}' : ''}'
                    : (latest == null
                        ? t('noCostSet')
                        : '${t('currentCost')}: ${fmtMoney(context, latest.cost)} '
                            '(${monthLabel(context, latest.month)})')),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') _addOrEditItem(existing: it);
                    if (v == 'editRatio') _editConsumptionRatio(it);
                    if (v == 'unlink') _unlink(it);
                    if (v == 'delete') _deleteItem(it);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Text(t('edit'))),
                    if (it.isLinked)
                      PopupMenuItem(
                          value: 'editRatio',
                          child: Text(t('editConsumptionRatio'))),
                    if (it.isLinked)
                      PopupMenuItem(
                          value: 'unlink',
                          child: Text(t('unlinkFromInventory'))),
                    PopupMenuItem(value: 'delete', child: Text(t('delete'))),
                  ],
                ),
                onTap: it.isLinked
                    ? null
                    : () async {
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
        if (_archived.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(t('archivedItems'),
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ..._archived.map((it) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: Theme.of(context).disabledColor.withOpacity(.06),
                child: ListTile(
                  leading: Icon(Icons.archive_outlined,
                      color: Theme.of(context).hintColor),
                  title: Text(it.name,
                      style: TextStyle(color: Theme.of(context).hintColor)),
                  subtitle: Text(t('archived')),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      tooltip: t('deletePermanently'),
                      icon: Icon(Icons.delete_forever_outlined,
                          color: AppColors.bad),
                      onPressed: () => _deletePermanently(it),
                    ),
                    TextButton(
                      onPressed: () => _restoreItem(it),
                      child: Text(t('restore')),
                    ),
                  ]),
                ),
              )),
        ],
      ],
    );
  }
}

/// Standalone page wrapper around [CostItemsTab] (with its own AppBar and
/// "add" FAB) — used when linking here directly rather than through the
/// Expenses tab (e.g. from the "no items yet" prompt in Daily Records).
class CostItemsPage extends StatelessWidget {
  final Project project;
  const CostItemsPage({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context).t;
    final key = GlobalKey<CostItemsTabState>();
    return Scaffold(
      appBar: AppBar(title: Text(t('operatingCost'))),
      body: CostItemsTab(key: key, project: project),
      floatingActionButton: FloatingActionButton(
        onPressed: () => key.currentState?.addItem(),
        child: const Icon(Icons.add),
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
