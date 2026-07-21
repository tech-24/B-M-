import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/app_theme.dart';
import '../core/localization.dart';
import '../data/db.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import 'project_home_screen.dart';
import 'settings_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final _db = AppDatabase.instance;
  List<Project> _projects = [];
  final Map<int, MonthlyReport> _summaries = {};
  final Map<int, DailyRecord?> _lastRecord = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final projects = await _db.getProjects();
    final month = currentMonthStr();
    _summaries.clear();
    _lastRecord.clear();
    await Future.wait(projects.map((p) async {
      final results = await Future.wait([
        _db.monthlyReport(p.id!, month),
        _db.getDailyRecords(p.id!, limit: 1),
      ]);
      _summaries[p.id!] = results[0] as MonthlyReport;
      final recent = results[1] as List<DailyRecord>;
      _lastRecord[p.id!] = recent.isEmpty ? null : recent.first;
    }));
    if (!mounted) return;
    setState(() {
      _projects = projects;
      _loading = false;
    });
  }

  Future<void> _editProject({Project? existing}) async {
    final t = L10n.of(context).t;
    final nameCtl = TextEditingController(text: existing?.name ?? '');
    final descCtl = TextEditingController(text: existing?.description ?? '');
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? t('addProject') : t('editProject')),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtl,
                decoration: InputDecoration(labelText: t('projectName')),
                validator: (v) => validateRequired(ctx, v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descCtl,
                decoration: InputDecoration(labelText: t('description')),
              ),
            ],
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
            child: Text(t('save')),
          ),
        ],
      ),
    );

    if (saved != true) return;
    if (existing == null) {
      await _db.insertProject(
          Project(name: nameCtl.text.trim(), description: descCtl.text.trim()));
    } else {
      await _db.updateProject(existing.copyWith(
          name: nameCtl.text.trim(), description: descCtl.text.trim()));
    }
    _load();
  }

  Future<void> _changeLogo(Project p) async {
    final t = L10n.of(context).t;
    final messenger = ScaffoldMessenger.of(context);
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 90,
    );
    if (picked == null) return;

    final Uint8List bytes = await picked.readAsBytes();
    final ext = picked.name.contains('.')
        ? picked.name.split('.').last.toLowerCase()
        : 'png';

    try {
      await _db.uploadProjectLogo(p.id!, bytes, ext);
      messenger.showSnackBar(SnackBar(content: Text(t('logoUpdated'))));
      _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(t('logoUploadFailed'))));
    }
  }

  Future<void> _removeLogo(Project p) async {
    await _db.removeProjectLogo(p.id!);
    _load();
  }

  Future<void> _deleteProject(Project p) async {
    final t = L10n.of(context).t;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('deleteProject')),
        content: Text(t('deleteProjectConfirm')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t('cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.bad),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('delete')),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _db.deleteProject(p.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context).t;
    return Scaffold(
      appBar: AppBar(
        title: Text(t('appTitle')),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _projects.isEmpty
              ? EmptyState(
                  icon: Icons.storefront_outlined, message: t('noProjects'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _projects.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _projectCard(_projects[i]),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editProject(),
        icon: const Icon(Icons.add),
        label: Text(t('addProject')),
      ),
    );
  }

  Widget _projectCard(Project p) {
    final t = L10n.of(context).t;
    final s = _summaries[p.id!];
    final last = _lastRecord[p.id!];
    final profit = s?.netProfit ?? 0;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ProjectHomeScreen(project: p)),
          );
          _load();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(.12),
                    backgroundImage: (p.logoUrl != null && p.logoUrl!.isNotEmpty)
                        ? NetworkImage(p.logoUrl!)
                        : null,
                    child: (p.logoUrl == null || p.logoUrl!.isEmpty)
                        ? const Icon(Icons.storefront, color: AppColors.primary)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        if (p.description.isNotEmpty)
                          Text(p.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') _editProject(existing: p);
                      if (v == 'logo') _changeLogo(p);
                      if (v == 'removeLogo') _removeLogo(p);
                      if (v == 'delete') _deleteProject(p);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'edit', child: Text(t('edit'))),
                      PopupMenuItem(
                          value: 'logo',
                          child: Text((p.logoUrl == null || p.logoUrl!.isEmpty)
                              ? t('addLogo')
                              : t('changeLogo'))),
                      if (p.logoUrl != null && p.logoUrl!.isNotEmpty)
                        PopupMenuItem(
                            value: 'removeLogo', child: Text(t('removeLogo'))),
                      PopupMenuItem(value: 'delete', child: Text(t('delete'))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _miniStat(t('monthSales'),
                        fmtMoney(context, s?.totalSales ?? 0), null),
                  ),
                  Expanded(
                    child: _miniStat(t('monthProfit'),
                        fmtMoney(context, profit),
                        profit >= 0 ? AppColors.good : AppColors.bad),
                  ),
                ],
              ),
              if (last != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.history,
                      size: 14, color: Theme.of(context).hintColor),
                  const SizedBox(width: 4),
                  Text(
                    '${dateLabel(context, last.date)} — ${fmtMoney(context, last.salesAmount)}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(context).hintColor),
                  ),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, Color? color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).hintColor)),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}
