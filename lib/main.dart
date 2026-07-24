import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_theme.dart';
import 'core/localization.dart';
import 'core/supabase_config.dart';
import 'screens/auth_screen.dart';
import 'screens/projects_screen.dart';
import 'screens/reset_password_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = AppSettings();
  await settings.load();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  runApp(
    ChangeNotifierProvider.value(
      value: settings,
      child: const BusinessDashboardApp(),
    ),
  );
}

class BusinessDashboardApp extends StatelessWidget {
  const BusinessDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return MaterialApp(
      title: 'Business Manager — Dashboard',
      debugShowCheckedModeBanner: false,
      locale: settings.locale,
      supportedLocales: L10n.supported,
      localizationsDelegates: const [
        L10nDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: settings.themeMode,
      home: const AuthGate(),
    );
  }
}

/// Shows the sign-in screen when signed out, and the dashboard itself once
/// signed in — reacts live to sign-in/sign-out events. Also detects the
/// special "password recovery" session created when the user clicks the
/// reset link from their email, and shows a dedicated screen to set a new
/// password before letting them into the app.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _recovering = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.data?.event == AuthChangeEvent.passwordRecovery) {
          _recovering = true;
        }
        if (_recovering) {
          return ResetPasswordScreen(
              onDone: () => setState(() => _recovering = false));
        }
        final session = Supabase.instance.client.auth.currentSession;
        return session == null ? const AuthScreen() : const ProjectsScreen();
      },
    );
  }
}
