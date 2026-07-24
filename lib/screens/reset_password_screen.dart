import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_theme.dart';
import '../core/localization.dart';

/// Shown when the user arrives via the "reset password" link from their
/// email (a temporary recovery session). Lets them set a new password,
/// then hands control back to [onDone] so the app returns to its normal
/// signed-in flow.
class ResetPasswordScreen extends StatefulWidget {
  final VoidCallback onDone;
  const ResetPasswordScreen({super.key, required this.onDone});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passCtl = TextEditingController();
  final _confirmCtl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(password: _passCtl.text));
      if (mounted) widget.onDone();
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
                    Icon(Icons.lock_reset_outlined,
                        size: 56, color: AppColors.primary),
                    const SizedBox(height: 12),
                    Text(t('setNewPassword'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(t('setNewPasswordSubtitle'),
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: Theme.of(context).hintColor)),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _passCtl,
                      obscureText: true,
                      decoration: InputDecoration(
                          labelText: t('newPassword'),
                          prefixIcon: const Icon(Icons.lock_outline)),
                      validator: (v) => (v == null || v.length < 6)
                          ? t('passwordTooShort')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmCtl,
                      obscureText: true,
                      decoration: InputDecoration(
                          labelText: t('confirmPassword'),
                          prefixIcon: const Icon(Icons.lock_outline)),
                      validator: (v) => (v != _passCtl.text)
                          ? t('passwordsDoNotMatch')
                          : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: const TextStyle(color: AppColors.bad)),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(t('saveNewPassword')),
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
