import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/localization.dart';
import '../data/db.dart';
import '../models/models.dart';
import '../widgets/common.dart';

class InventoryScreen extends StatefulWidget {
  final Project project;
  const InventoryScreen({super.key, required this.project});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _db = AppDatabase.instance;
  List<InventoryItem> _items = [];
  List<InventoryItem> _archived = [];
  Map<int, String> _linkedNames = {}; // inventoryItemId -> cost item name
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all =
        await _db.getInventory(widget.project.id!, includeArchived: true);
    final costItems =
        await _db.getCostItems(widget.project.id!, includeArchived: true);
    final linked = <int, String>{};
    for (final c in costItems) {
      if (c.linkedInventoryItemId != null) {
        linked[c.linkedInventoryItemId!] = c.name;
      }
    }
    if (!mounted) return;
    setState(() {
      _items = all.where((i) => !i.archived).toList();
      _archived = all.where((i) => i.archived).toList();
      _linkedNames = linked;
      _loading = false;
    });
  }

  Future<void> _addOrEdit({InventoryItem? existing}) async {
    final t = L10n.of(context).t;
    final nameCtl = TextEditingController(text: existing?.name ?? '');
    final catCtl = TextEditingController(text: existing?.category ?? '');
    final unitCtl = TextEditingController(text: existing?.unit ?? '');
    final formKey = GlobalKey<FormState>();

    String unitType = existing?.unitType ?? 'piece';
    bool otherHasSubUnits =
        unitType == 'other' && existing?.unitsPerContainer != null;

    bool containerMode() =>
        unitType == 'carton' || (unitType == 'other' && otherHasSubUnits);

    // Simple mode fields (piece / kg / other-without-subunits).
    final qtyCtl = TextEditingController(
        text: existing == null || containerMode()
            ? ''
            : fmtNum(existing.purchaseQuantity));
    final priceCtl = TextEditingController(
        text: existing == null || containerMode()
            ? ''
            : fmtNum(existing.purchasePrice));

    // Container mode fields (carton / other-with-subunits).
    final unitsPerContainerCtl = TextEditingController(
        text: existing?.unitsPerContainer == null
            ? ''
            : fmtNum(existing!.unitsPerContainer!));
    final upc = existing?.unitsPerContainer ?? 0;
    final containerCount =
        (existing != null && upc > 0) ? existing.purchaseQuantity / upc : 0.0;
    final containerCountCtl = TextEditingController(
        text: (existing != null && containerMode() && containerCount > 0)
            ? fmtNum(containerCount)
            : '');
    final pricePerContainerCtl = TextEditingController(
        text: (existing != null && containerMode() && containerCount > 0)
            ? fmtNum(existing.purchasePrice / containerCount)
            : '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(existing == null ? t('addInventoryItem') : t('edit')),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                    controller: nameCtl,
                    decoration: InputDecoration(labelText: t('itemName')),
                    validator: (v) => validateRequired(ctx, v)),
                const SizedBox(height: 12),
                TextFormField(
                    controller: catCtl,
                    decoration: InputDecoration(labelText: t('category'))),
                const SizedBox(height: 12),
                TextFormField(
                    controller: unitCtl,
                    decoration:
                        InputDecoration(labelText: t('unit'))),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: unitType,
                  decoration: InputDecoration(labelText: t('unitType')),
                  items: [
                    DropdownMenuItem(
                        value: 'piece', child: Text(t('unitPiece'))),
                    DropdownMenuItem(
                        value: 'carton', child: Text(t('unitCarton'))),
                    DropdownMenuItem(value: 'kg', child: Text(t('unitKg'))),
                    DropdownMenuItem(
                        value: 'other', child: Text(t('unitOther'))),
                  ],
                  onChanged: (v) => setDlg(() => unitType = v ?? 'piece'),
                ),
                if (unitType == 'other') ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(t('hasSubUnits')),
                    value: otherHasSubUnits,
                    onChanged: (v) => setDlg(() => otherHasSubUnits = v),
                  ),
                ],
                const SizedBox(height: 12),
                if (containerMode()) ...[
                  TextFormField(
                      controller: containerCountCtl,
                      keyboardType: TextInputType.number,
                      decoration:
                          InputDecoration(labelText: t('containerCount')),
                      validator: (v) => validateNumber(ctx, v)),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: unitsPerContainerCtl,
                      keyboardType: TextInputType.number,
                      decoration:
                          InputDecoration(labelText: t('unitsPerContainer')),
                      validator: (v) => validateNumber(ctx, v)),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: pricePerContainerCtl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: t('pricePerContainer'),
                          suffixText: t('sar')),
                      validator: (v) => validateNumber(ctx, v)),
                ] else ...[
                  TextFormField(
                      controller: qtyCtl,
                      keyboardType: TextInputType.number,
                      decoration:
                          InputDecoration(labelText: t('purchaseQuantity')),
                      validator: (v) => validateNumber(ctx, v)),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: priceCtl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: t('purchasePrice'),
                          suffixText: t('sar')),
                      validator: (v) => validateNumber(ctx, v)),
                ],
              ]),
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
      ),
    );

    if (ok != true) return;

    double totalQty;
    double totalPrice;
    double? unitsPerContainer;
    if (containerMode()) {
      final count = parseNum(containerCountCtl.text.replaceAll(',', ''));
      final perContainer =
          parseNum(unitsPerContainerCtl.text.replaceAll(',', ''));
      final pricePer = parseNum(pricePerContainerCtl.text.replaceAll(',', ''));
      totalQty = count * perContainer;
      totalPrice = count * pricePer;
      unitsPerContainer = perContainer;
    } else {
      totalQty = parseNum(qtyCtl.text.replaceAll(',', ''));
      totalPrice = parseNum(priceCtl.text.replaceAll(',', ''));
      unitsPerContainer = null;
    }

    final item = InventoryItem(
      id: existing?.id,
      projectId: widget.project.id!,
      name: nameCtl.text.trim(),
      category: catCtl.text.trim(),
      unit: unitCtl.text.trim(),
      purchaseQuantity: totalQty,
      purchasePrice: totalPrice,
      usedQuantity: existing?.usedQuantity ?? 0,
      unitType: unitType,
      unitsPerContainer: unitsPerContainer,
    );

    if (existing == null) {
      final newId = await _db.insertInventoryItem(item);
      _load();
      if (!mounted) return;
      await _offerLinkToProductCost(InventoryItem(
        id: newId,
        projectId: item.projectId,
        name: item.name,
        category: item.category,
        unit: item.unit,
        purchaseQuantity: item.purchaseQuantity,
        purchasePrice: item.purchasePrice,
        usedQuantity: item.usedQuantity,
        unitType: item.unitType,
        unitsPerContainer: item.unitsPerContainer,
      ));
    } else {
      await _db.updateInventoryItem(item);
      _load();
    }
  }

  /// After adding a brand-new inventory item, offers to also create a
  /// matching "cost of products used" item linked to it, so selling that
  /// product auto-deducts this stock going forward.
  Future<void> _offerLinkToProductCost(InventoryItem item) async {
    final t = L10n.of(context).t;
    final ratioCtl = TextEditingController(text: '1');
    final formKey = GlobalKey<FormState>();

    final linkAnswer = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('linkToProductCost')),
        content: Text(t('linkToProductCostHint')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t('linkToProductCost'))),
        ],
      ),
    );
    if (linkAnswer != true || !mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.name),
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
    if (ok != true) return;

    try {
      await _db.insertCostItem(CostItem(
        projectId: widget.project.id!,
        name: item.name,
        linkedInventoryItemId: item.id,
        consumptionPerUnit: parseNum(ratioCtl.text.replaceAll(',', '')),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(t('linkToProductCostFailed')),
          duration: const Duration(seconds: 6)));
    }
  }

  Future<void> _recordUsage(InventoryItem item) async {
    final t = L10n.of(context).t;
    final qtyCtl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${t('recordUsage')} — ${item.name}'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: qtyCtl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
                labelText: t('quantity'),
                helperText:
                    '${t('remaining')}: ${fmtNum(item.remaining)} ${item.unit}'),
            validator: (v) => validateNumber(ctx, v),
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
      await _db.addInventoryUsage(InventoryUsage(
        projectId: widget.project.id!,
        itemId: item.id!,
        date: todayStr(),
        quantity: parseNum(qtyCtl.text),
      ));
      _load();
    }
  }

  Future<void> _useAllRemaining(InventoryItem item) async {
    final t = L10n.of(context).t;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('useAllRemaining')),
        content: Text(
            '${t('useAllRemainingConfirm')}\n${t('remaining')}: ${fmtNum(item.remaining)} ${item.unit}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t('useAllRemaining'))),
        ],
      ),
    );
    if (ok == true) {
      await _db.markInventoryFullyUsed(item, todayStr());
      _load();
    }
  }

  Future<void> _restock(InventoryItem item) async {
    final t = L10n.of(context).t;
    final messenger = ScaffoldMessenger.of(context);
    final formKey = GlobalKey<FormState>();
    final isContainer =
        item.unitType == 'carton' || item.unitsPerContainer != null;

    // Container-mode batch (carton / other-with-subunits): ask how many
    // containers + price per container, using the item's EXISTING
    // pieces-per-container (not re-asked, it's a fixed property).
    final containerCountCtl = TextEditingController();
    final pricePerContainerCtl = TextEditingController();
    // Simple-mode batch (piece / kg / other-without-subunits).
    final qtyCtl = TextEditingController();
    final priceCtl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${t('restock')} — ${item.name}'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(t('restockHint'),
                  style: TextStyle(
                      fontSize: 12.5, color: Theme.of(context).hintColor)),
              const SizedBox(height: 14),
              if (isContainer) ...[
                TextFormField(
                    controller: containerCountCtl,
                    keyboardType: TextInputType.number,
                    decoration:
                        InputDecoration(labelText: t('containerCount')),
                    validator: (v) => validateNumber(ctx, v)),
                const SizedBox(height: 12),
                TextFormField(
                    controller: pricePerContainerCtl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: t('pricePerContainer'),
                        suffixText: t('sar')),
                    validator: (v) => validateNumber(ctx, v)),
              ] else ...[
                TextFormField(
                    controller: qtyCtl,
                    keyboardType: TextInputType.number,
                    decoration:
                        InputDecoration(labelText: t('purchaseQuantity')),
                    validator: (v) => validateNumber(ctx, v)),
                const SizedBox(height: 12),
                TextFormField(
                    controller: priceCtl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: t('purchasePrice'), suffixText: t('sar')),
                    validator: (v) => validateNumber(ctx, v)),
              ],
            ]),
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

    double addedQty;
    double addedPrice;
    if (isContainer) {
      final count = parseNum(containerCountCtl.text.replaceAll(',', ''));
      final perContainer =
          parseNum(pricePerContainerCtl.text.replaceAll(',', ''));
      addedQty = count * (item.unitsPerContainer ?? 1);
      addedPrice = count * perContainer;
    } else {
      addedQty = parseNum(qtyCtl.text.replaceAll(',', ''));
      addedPrice = parseNum(priceCtl.text.replaceAll(',', ''));
    }

    await _db.restockInventoryItem(item.id!, addedQty, addedPrice);
    messenger.showSnackBar(SnackBar(content: Text(t('restocked'))));
    _load();
  }

  Future<void> _deleteItem(InventoryItem item) async {
    final t = L10n.of(context).t;
    final hasHistory = item.usedQuantity > 0 || _linkedNames.containsKey(item.id);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('delete')),
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
      await _db.smartDeleteInventoryItem(widget.project.id!, item.id!);
      _load();
    }
  }

  Future<void> _restoreItem(InventoryItem item) async {
    await _db.unarchiveInventoryItem(item.id!);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context).t;
    return Scaffold(
      appBar: AppBar(title: Text(t('inventory'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_items.isEmpty && _archived.isEmpty)
              ? EmptyState(
                  icon: Icons.inventory_2_outlined,
                  message: t('noInventory'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final it in _items) ...[
                      _itemCard(it),
                      const SizedBox(height: 12),
                    ],
                    if (_archived.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(t('archivedItems'),
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      for (final it in _archived) ...[
                        Card(
                          color:
                              Theme.of(context).disabledColor.withOpacity(.06),
                          child: ListTile(
                            leading: Icon(Icons.archive_outlined,
                                color: Theme.of(context).hintColor),
                            title: Text(it.name,
                                style: TextStyle(
                                    color: Theme.of(context).hintColor)),
                            subtitle: Text(t('archived')),
                            trailing: TextButton(
                              onPressed: () => _restoreItem(it),
                              child: Text(t('restore')),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(),
        icon: const Icon(Icons.add),
        label: Text(t('addInventoryItem')),
      ),
    );
  }

  Widget _itemCard(InventoryItem item) {
    final t = L10n.of(context).t;
    final ratio = item.purchaseQuantity <= 0
        ? 0.0
        : (item.remaining / item.purchaseQuantity).clamp(0.0, 1.0);
    final low = ratio <= .15;
    final linkedName = _linkedNames[item.id];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    if (item.category.isNotEmpty)
                      Text(item.category,
                          style: Theme.of(context).textTheme.bodySmall),
                    if (linkedName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.link,
                              size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text('${t('linkedToInventory')}: $linkedName',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.primary)),
                        ]),
                      ),
                  ],
                ),
              ),
              if (low)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.bad.withOpacity(.12),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(t('lowStock'),
                      style: const TextStyle(
                          color: AppColors.bad,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') _addOrEdit(existing: item);
                  if (v == 'useAll') _useAllRemaining(item);
                  if (v == 'delete') _deleteItem(item);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text(t('edit'))),
                  if (item.remaining > 0)
                    PopupMenuItem(
                        value: 'useAll', child: Text(t('useAllRemaining'))),
                  PopupMenuItem(value: 'delete', child: Text(t('delete'))),
                ],
              ),
            ]),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                color: low ? AppColors.bad : AppColors.good,
                backgroundColor:
                    Theme.of(context).dividerColor.withOpacity(.3),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _stat(t('currentStock'),
                    '${fmtNum(item.purchaseQuantity)} ${item.unit}'),
                _stat(t('used'), fmtNum(item.usedQuantity)),
                _stat(t('remaining'), fmtNum(item.remaining)),
                _stat(t('consumedCost'),
                    fmtMoney(context, item.consumedCost)),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Wrap(spacing: 8, children: [
                OutlinedButton.icon(
                  onPressed: () => _restock(item),
                  icon: const Icon(Icons.add_box_outlined, size: 18),
                  label: Text(t('restock')),
                ),
                OutlinedButton.icon(
                  onPressed: () => _recordUsage(item),
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  label: Text(t('recordUsage')),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).hintColor)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
