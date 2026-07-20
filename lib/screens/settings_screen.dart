import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_theme.dart';
import '../core/localization.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context).t;
    final settings = context.watch<AppSettings>();
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text(t('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(t('language')),
                trailing: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'ar', label: Text('العربية')),
                    ButtonSegment(value: 'en', label: Text('English')),
                  ],
                  selected: {settings.locale.languageCode},
                  onSelectionChanged: (s) =>
                      settings.setLocale(Locale(s.first)),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.brightness_6_outlined),
                title: Text(t('theme')),
                trailing: SegmentedButton<ThemeMode>(
                  segments: [
                    ButtonSegment(
                        value: ThemeMode.light,
                        icon: const Icon(Icons.light_mode, size: 18)),
                    ButtonSegment(
                        value: ThemeMode.dark,
                        icon: const Icon(Icons.dark_mode, size: 18)),
                    ButtonSegment(
                        value: ThemeMode.system,
                        icon: const Icon(Icons.settings_suggest, size: 18)),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (s) =>
                      settings.setThemeMode(s.first),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: Text(t('account')),
                subtitle: Text(user?.email ?? ''),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.bad),
                title: Text(t('signOut'),
                    style: const TextStyle(color: AppColors.bad)),
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(t('signOut')),
                      content: Text(t('signOutConfirm')),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(t('cancel'))),
                        FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(t('signOut'))),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await Supabase.instance.client.auth.signOut();
                  }
                },
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(t('about')),
              subtitle: Text(t('aboutBody')),
            ),
          ),
        ],
      ),
    );
  }
}
