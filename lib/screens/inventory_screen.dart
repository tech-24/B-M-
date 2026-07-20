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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _db.getInventory(widget.project.id!);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _addOrEdit({InventoryItem? existing}) async {
    final t = L10n.of(context).t;
    final nameCtl = TextEditingController(text: existing?.name ?? '');
    final catCtl = TextEditingController(text: existing?.category ?? '');
    final unitCtl = TextEditingController(text: existing?.unit ?? '');
    final qtyCtl = TextEditingController(
        text: existing == null ? '' : fmtNum(existing.purchaseQuantity));
    final priceCtl = TextEditingController(
        text: existing == null ? '' : fmtNum(existing.purchasePrice));
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
                  decoration: InputDecoration(labelText: t('unitType'))),
              const SizedBox(height: 12),
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
    final item = InventoryItem(
      id: existing?.id,
      projectId: widget.project.id!,
      name: nameCtl.text.trim(),
      category: catCtl.text.trim(),
      unit: unitCtl.text.trim(),
      purchaseQuantity: parseNum(qtyCtl.text.replaceAll(',', '')),
      purchasePrice: parseNum(priceCtl.text.replaceAll(',', '')),
      usedQuantity: existing?.usedQuantity ?? 0,
    );
    if (existing == null) {
      await _db.insertInventoryItem(item);
    } else {
      await _db.updateInventoryItem(item);
    }
    _load();
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

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context).t;
    return Scaffold(
      appBar: AppBar(title: Text(t('inventory'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? EmptyState(
                  icon: Icons.inventory_2_outlined,
                  message: t('noInventory'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _itemCard(_items[i]),
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
                  if (v == 'delete') {
                    _db.deleteInventoryItem(item.id!).then((_) => _load());
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text(t('edit'))),
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
              child: OutlinedButton.icon(
                onPressed: () => _recordUsage(item),
                icon: const Icon(Icons.remove_circle_outline, size: 18),
                label: Text(t('recordUsage')),
              ),
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
