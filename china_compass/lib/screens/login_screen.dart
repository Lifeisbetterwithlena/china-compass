import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../state/app_state.dart';
import '../widgets/layout.dart';

/// Passwordless login: step 1 asks for the email, step 2 for the 6-digit code.
/// Pops with `true` when the user is signed in.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.reason});

  /// Optional line explaining why sign-in is needed (e.g. to save a step).
  final String? reason;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static const _resendSeconds = 30;

  // Supabase lets the project choose the code length (6 to 10 digits).
  static const _minCode = 6;
  static const _maxCode = 10;

  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  String? _sentTo;
  String? _demoCode;
  String? _errorKey;
  bool _busy = false;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_cooldown <= 1) t.cancel();
      if (mounted) setState(() => _cooldown--);
    });
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (!_emailPattern.hasMatch(email)) {
      setState(() => _errorKey = 'emailInvalid');
      return;
    }
    setState(() {
      _busy = true;
      _errorKey = null;
    });
    try {
      final demo = await AppScope.of(context).auth.sendCode(email);
      setState(() {
        _sentTo = email;
        _demoCode = demo;
        _codeCtrl.clear();
      });
      _startCooldown();
    } on AuthFailure catch (e) {
      setState(() => _errorKey = e.messageKey);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final code = _codeCtrl.text.trim();
    if (code.length < _minCode || _busy) return;
    final state = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _errorKey = null;
    });
    try {
      await state.auth.verify(_sentTo!, code);
      messenger.showSnackBar(SnackBar(content: Text(state.t('signedInAs', {'email': _sentTo!}))));
      navigator.pop(true);
    } on AuthFailure catch (e) {
      setState(() => _errorKey = e.messageKey);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final codeStep = _sentTo != null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context, false)),
      ),
      body: SafeArea(
        child: CenteredListView(
          maxWidth: 480,
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(16)),
                child: Icon(codeStep ? Icons.mark_email_read_outlined : Icons.mail_outline_rounded, color: scheme.primary),
              ),
            ),
            const SizedBox(height: 20),
            Text(state.t(codeStep ? 'codeTitle' : 'signInTitle'), style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              codeStep ? state.t('codeText', {'email': _sentTo!}) : (widget.reason ?? state.t('signInText')),
              style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
            ),
            if (!codeStep && widget.reason != null) ...[
              const SizedBox(height: 4),
              Text(state.t('signInText'), style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
            ],
            const SizedBox(height: 28),
            if (!codeStep) ...[
              AutofillGroup(
                child: TextField(
                  controller: _emailCtrl,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(labelText: state.t('emailLabel')),
                  onSubmitted: (_) => _sendCode(),
                ),
              ),
              _error(state),
              const SizedBox(height: 20),
              FilledButton(onPressed: _busy ? null : _sendCode, child: _label(state.t('sendCode'))),
            ] else ...[
              if (_demoCode != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    Icon(Icons.science_outlined, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Expanded(child: Text(state.t('demoBanner', {'code': _demoCode!}))),
                  ]),
                ),
              TextField(
                controller: _codeCtrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(_maxCode)],
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 8),
                decoration: InputDecoration(labelText: state.t('codeLabel')),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _verify(),
              ),
              _error(state),
              const SizedBox(height: 20),
              FilledButton(onPressed: _busy ? null : _verify, child: _label(state.t('verify'))),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _cooldown > 0 || _busy ? null : _sendCode,
                child: Text(_cooldown > 0 ? state.t('resendIn', {'s': _cooldown}) : state.t('resend')),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _sentTo = null;
                          _demoCode = null;
                          _errorKey = null;
                        }),
                child: Text(state.t('changeEmail')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => _busy
      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
      : Text(text);

  Widget _error(AppState state) => _errorKey == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(state.t(_errorKey!), style: TextStyle(color: Theme.of(context).colorScheme.error)),
        );
}
