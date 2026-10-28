import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_api.dart';
import '../services/local_auth_api.dart';
import '../theme/app_theme.dart';
import 'main_screen.dart';

enum _AuthStep { phone, profile, login, code }

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key, this.authApi});
  final AuthApi? authApi;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();
  final _phone = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _code = TextEditingController();
  _AuthStep _step = _AuthStep.phone;
  _AuthStep _codeOrigin = _AuthStep.profile;
  AuthChallenge? _challenge;
  bool _busy = false;
  bool _hidePassword = true;
  String? _error;
  int _resendSeconds = 0;
  Timer? _timer;

  AuthApi get _auth => widget.authApi ?? AuthApi.instance;

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    for (final controller in [
      _phone,
      _firstName,
      _lastName,
      _email,
      _password,
      _confirmation,
      _code,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _go(_AuthStep step) {
    FocusScope.of(context).unfocus();
    setState(() {
      _step = step;
      _error = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _back() {
    if (_busy) return;
    if (_step == _AuthStep.code) {
      _timer?.cancel();
      _go(_codeOrigin);
    } else {
      _go(_AuthStep.phone);
    }
  }

  void _received(AuthChallenge challenge) {
    _challenge = challenge;
    _code.clear();
    _resendSeconds = challenge.resendAfter;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _continue() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (_step == _AuthStep.phone) {
      _go(_AuthStep.profile);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_step == _AuthStep.code) {
        final profile = await _auth.verify(_challenge!.id, _code.text);
        if (!mounted) return;
        _password.clear();
        _confirmation.clear();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => MainScreen(
              userName: profile.name,
              phone: profile.phone,
              authApi: _auth,
            ),
          ),
          (_) => false,
        );
      } else {
        final origin = _step;
        final challenge = _step == _AuthStep.login
            ? await _auth.login(
                email: _email.text.trim(),
                password: _password.text,
              )
            : await _auth.register(
                phone: _phone.text.trim(),
                name: [
                  _firstName.text.trim(),
                  _lastName.text.trim(),
                ].where((s) => s.isNotEmpty).join(' '),
                email: _email.text.trim(),
                password: _password.text,
              );
        if (!mounted) return;
        _codeOrigin = origin;
        _password.clear();
        _confirmation.clear();
        _received(challenge);
        _go(_AuthStep.code);
      }
    } on AuthException catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } on MissingPluginException {
      if (mounted) {
        setState(
          () => _error =
              'Local storage is not ready. Stop the app and run it again (not Hot Reload).',
        );
      }
    } on PlatformException catch (failure) {
      if (mounted) {
        setState(
          () => _error = failure.code == 'channel-error'
              ? 'Local storage is not ready. Stop the app and run it again (not Hot Reload).'
              : 'Local storage is unavailable. Please restart the app.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Authentication failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_busy || _resendSeconds > 0) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final challenge = await _auth.resend();
      if (mounted) setState(() => _received(challenge));
    } on AuthException catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not resend the code. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _emailField() => TextFormField(
    controller: _email,
    keyboardType: TextInputType.emailAddress,
    autofillHints: const [AutofillHints.email],
    textInputAction: TextInputAction.next,
    autocorrect: false,
    maxLength: 254,
    decoration: const InputDecoration(
      labelText: 'Email',
      prefixIcon: Icon(Icons.mail_outline),
    ),
    validator: (value) =>
        RegExp(
          r'^[^\s@]+@[^\s@.]+(?:\.[^\s@.]+)+$',
        ).hasMatch(value?.trim() ?? '')
        ? null
        : 'Enter a valid email address',
  );

  Widget _passwordField() => TextFormField(
    controller: _password,
    obscureText: _hidePassword,
    enableSuggestions: false,
    autocorrect: false,
    autofillHints: [
      _step == _AuthStep.login
          ? AutofillHints.password
          : AutofillHints.newPassword,
    ],
    textInputAction: _step == _AuthStep.login
        ? TextInputAction.done
        : TextInputAction.next,
    maxLength: 128,
    decoration: InputDecoration(
      labelText: 'Password',
      helperText: _step == _AuthStep.profile
          ? 'Use at least 12 characters'
          : null,
      prefixIcon: const Icon(Icons.lock_outline),
      suffixIcon: IconButton(
        tooltip: _hidePassword ? 'Show password' : 'Hide password',
        onPressed: () => setState(() => _hidePassword = !_hidePassword),
        icon: Icon(
          _hidePassword
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
        ),
      ),
    ),
    validator: (value) {
      if (value == null || value.isEmpty) return 'Enter your password';
      if (_step == _AuthStep.profile && value.length < 12) {
        return 'Use at least 12 characters';
      }
      return null;
    },
    onFieldSubmitted: _step == _AuthStep.login ? (_) => _continue() : null,
  );

  List<Widget> _fields() => switch (_step) {
    _AuthStep.phone => [
      TextFormField(
        controller: _phone,
        keyboardType: TextInputType.phone,
        autofillHints: const [AutofillHints.telephoneNumber],
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[+0-9 ()-]')),
        ],
        decoration: const InputDecoration(
          labelText: 'Phone number',
          hintText: '+380 99 123 45 67',
          helperText: 'Include your country code, for example +380',
          helperMaxLines: 2,
          prefixIcon: Icon(Icons.phone_outlined),
        ),
        validator: (value) =>
            RegExp(
              r'^\+[1-9][0-9]{6,14}$',
            ).hasMatch((value ?? '').replaceAll(RegExp(r'[ ()-]'), ''))
            ? null
            : 'Enter a valid number with a + country code',
        onFieldSubmitted: (_) => _continue(),
      ),
    ],
    _AuthStep.profile => [
      TextFormField(
        controller: _firstName,
        maxLength: 64,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.givenName],
        decoration: const InputDecoration(labelText: 'First name'),
        validator: (value) => value == null || value.trim().isEmpty
            ? 'Please enter your first name'
            : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _lastName,
        maxLength: 64,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.familyName],
        decoration: const InputDecoration(labelText: 'Last name (optional)'),
      ),
      const SizedBox(height: 16),
      _emailField(),
      const SizedBox(height: 16),
      _passwordField(),
      const SizedBox(height: 16),
      TextFormField(
        controller: _confirmation,
        obscureText: true,
        maxLength: 128,
        enableSuggestions: false,
        autocorrect: false,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(labelText: 'Confirm password'),
        validator: (value) =>
            value == _password.text ? null : 'Passwords do not match',
        onFieldSubmitted: (_) => _continue(),
      ),
    ],
    _AuthStep.login => [
      _emailField(),
      const SizedBox(height: 16),
      _passwordField(),
    ],
    _AuthStep.code => [
      TextFormField(
        controller: _code,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 28, letterSpacing: 8),
        autofillHints: const [AutofillHints.oneTimeCode],
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        decoration: const InputDecoration(
          labelText: 'Email code',
          hintText: '000000',
        ),
        validator: (value) =>
            value?.length == 6 ? null : 'Enter the 6-digit code',
        onFieldSubmitted: (_) => _continue(),
      ),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final title = switch (_step) {
      _AuthStep.phone => 'Your phone number',
      _AuthStep.profile => 'Create your account',
      _AuthStep.login => 'Welcome back',
      _AuthStep.code => 'Check your email',
    };
    return PopScope(
      canPop: _step == _AuthStep.phone && !_busy,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: colors.surface,
          foregroundColor: colors.onSurface,
          leading: _step == _AuthStep.phone
              ? null
              : IconButton(
                  tooltip: _step == _AuthStep.profile
                      ? 'Edit phone number'
                      : 'Back',
                  onPressed: _busy ? null : _back,
                  icon: const Icon(Icons.arrow_back),
                ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 36),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor: colors.primary,
                      child: Icon(
                        _step == _AuthStep.code
                            ? Icons.mark_email_read_outlined
                            : _step == _AuthStep.login
                            ? Icons.lock_outline
                            : Icons.send_rounded,
                        size: 48,
                        color: colors.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    switch (_step) {
                      _AuthStep.phone =>
                        'Enter your phone number in international format to create your account.',
                      _AuthStep.profile =>
                        'Choose a password and an email address for two-step verification.',
                      _AuthStep.login =>
                        'Enter your email and password. We will then send you a verification code.',
                      _AuthStep.code =>
                        kDebugMode && _auth is LocalAuthApi
                            ? 'Enter 123456 to confirm ${_challenge!.email} on this device.'
                            : 'We sent a 6-digit code to ${_challenge!.email}. It expires in 5 minutes.',
                    },
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Form(
                    key: _form,
                    child: AutofillGroup(
                      child: AbsorbPointer(
                        absorbing: _busy,
                        child: Column(
                          key: ValueKey(_step),
                          children: _fields(),
                        ),
                      ),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                    ),
                  const SizedBox(height: 28),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: _busy ? null : _continue,
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _step == _AuthStep.code
                                ? 'Verify and sign in'
                                : _step == _AuthStep.profile ||
                                      _step == _AuthStep.login
                                ? 'Send email code'
                                : 'Continue',
                          ),
                  ),
                  const SizedBox(height: 12),
                  if (_step == _AuthStep.phone)
                    TextButton(
                      onPressed: _busy ? null : () => _go(_AuthStep.login),
                      child: const Text('Already have an account? Sign in'),
                    ),
                  if (kDebugMode && _auth is LocalAuthApi) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Local test account · Verification code: 123456',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (_step == _AuthStep.code)
                    TextButton(
                      onPressed: _busy || _resendSeconds > 0 ? null : _resend,
                      child: Text(
                        _resendSeconds > 0
                            ? 'Resend code in ${_resendSeconds}s'
                            : 'Resend code',
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    kDebugMode && _auth is LocalAuthApi
                        ? 'Use test data only. Your profile is saved on this device. No email is sent.'
                        : 'Your phone number is not verified by SMS. Never share your password or email code.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
