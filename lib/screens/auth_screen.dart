import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_theme.dart';
import '../core/localization.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();
  final _resetEmailCtl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();
  bool _isSignUp = false;
  bool _forgotPassword = false;
  bool _busy = false;
  String? _error;
  String? _info;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final auth = Supabase.instance.client.auth;
    try {
      if (_isSignUp) {
        await auth.signUp(
            email: _emailCtl.text.trim(), password: _passCtl.text);
        if (mounted) {
          setState(() =>
              _info = L10n.of(context).t('signUpCheckEmailOrDone'));
        }
      } else {
        await auth.signInWithPassword(
            email: _emailCtl.text.trim(), password: _passCtl.text);
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitReset() async {
    if (!_resetFormKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      // Redirects back to wherever this app is hosted, regardless of
      // domain — the app itself detects the recovery session on load.
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _resetEmailCtl.text.trim(),
        redirectTo: Uri.base.toString(),
      );
      if (mounted) {
        setState(() => _info = L10n.of(context).t('resetLinkSent'));
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context).t;
    if (_forgotPassword) return _buildForgotPassword(context, t);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.business_center_outlined,
                        size: 56, color: AppColors.primary),
                    const SizedBox(height: 12),
                    Text(t('appTitle'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                        _isSignUp
                            ? t('createAccountSubtitle')
                            : t('signInSubtitle'),
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: Theme.of(context).hintColor)),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _emailCtl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                          labelText: t('email'),
                          prefixIcon: const Icon(Icons.email_outlined)),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? t('invalidEmail')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passCtl,
                      obscureText: true,
                      decoration: InputDecoration(
                          labelText: t('password'),
                          prefixIcon: const Icon(Icons.lock_outline)),
                      validator: (v) => (v == null || v.length < 6)
                          ? t('passwordTooShort')
                          : null,
                    ),
                    if (!_isSignUp) ...[
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                    _forgotPassword = true;
                                    _error = null;
                                    _info = null;
                                    _resetEmailCtl.text = _emailCtl.text;
                                  }),
                          child: Text(t('forgotPassword')),
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: const TextStyle(color: AppColors.bad)),
                    ],
                    if (_info != null) ...[
                      const SizedBox(height: 12),
                      Text(_info!,
                          style: const TextStyle(color: AppColors.good)),
                    ],
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(_isSignUp ? t('createAccount') : t('signIn')),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _isSignUp = !_isSignUp;
                                _error = null;
                                _info = null;
                              }),
                      child: Text(_isSignUp
                          ? t('haveAccountSignIn')
                          : t('noAccountSignUp')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForgotPassword(BuildContext context, String Function(String) t) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _resetFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.lock_reset_outlined,
                        size: 56, color: AppColors.primary),
                    const SizedBox(height: 12),
                    Text(t('forgotPassword'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(t('forgotPasswordSubtitle'),
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: Theme.of(context).hintColor)),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _resetEmailCtl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                          labelText: t('email'),
                          prefixIcon: const Icon(Icons.email_outlined)),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? t('invalidEmail')
                          : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: const TextStyle(color: AppColors.bad)),
                    ],
                    if (_info != null) ...[
                      const SizedBox(height: 12),
                      Text(_info!,
                          style: const TextStyle(color: AppColors.good)),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _submitReset,
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(t('sendResetLink')),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _forgotPassword = false;
                                _error = null;
                                _info = null;
                              }),
                      child: Text(t('backToSignIn')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
