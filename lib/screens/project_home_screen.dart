import 'package:flutter/material.dart';

import '../core/localization.dart';
import '../models/models.dart';
import 'dashboard_screen.dart';
import 'daily_records_screen.dart';
import 'inventory_screen.dart';
import 'expenses_screen.dart';
import 'reports_screen.dart';

/// Project shell: bottom navigation between the 5 main sections.
class ProjectHomeScreen extends StatefulWidget {
  final Project project;
  const ProjectHomeScreen({super.key, required this.project});

  @override
  State<ProjectHomeScreen> createState() => _ProjectHomeScreenState();
}

class _ProjectHomeScreenState extends State<ProjectHomeScreen> {
  int _index = 0;

  void goTo(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context).t;
    final pages = [
      DashboardScreen(project: widget.project, onNavigate: goTo),
      DailyRecordsScreen(project: widget.project),
      InventoryScreen(project: widget.project),
      ExpensesScreen(project: widget.project),
      ReportsScreen(project: widget.project),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: goTo,
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.dashboard_outlined),
              selectedIcon: const Icon(Icons.dashboard),
              label: t('dashboard')),
          NavigationDestination(
              icon: const Icon(Icons.calendar_month_outlined),
              selectedIcon: const Icon(Icons.calendar_month),
              label: t('dailyRecords')),
          NavigationDestination(
              icon: const Icon(Icons.inventory_2_outlined),
              selectedIcon: const Icon(Icons.inventory_2),
              label: t('inventory')),
          NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(Icons.receipt_long),
              label: t('expenses')),
          NavigationDestination(
              icon: const Icon(Icons.insights_outlined),
              selectedIcon: const Icon(Icons.insights),
              label: t('reports')),
        ],
      ),
    );
  }
}
