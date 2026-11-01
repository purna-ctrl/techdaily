import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../repositories/auth_repository.dart';
import '../widgets/story_widgets.dart';
import 'legal_screen.dart';

/// Password rule checks shown live while registering.
class PasswordRules {
  static const int minLength = 8;

  static bool hasLength(String p) => p.length >= minLength;
  static bool hasLetter(String p) => RegExp(r'[A-Za-z]').hasMatch(p);
  static bool hasNumber(String p) => RegExp(r'\d').hasMatch(p);

  static bool isValid(String p) => hasLength(p) && hasLetter(p) && hasNumber(p);
}

/// Sign in / Create account. Text fields use long-lived controllers and
/// focus nodes owned by this State (never recreated in build), so typing
/// works reliably on web.
class AuthScreen extends StatefulWidget {
  final AuthRepository authRepository;
  final bool initialIsSignUp;

  const AuthScreen({
    super.key,
    required this.authRepository,
    this.initialIsSignUp = false,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  late bool _isSignUp;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _nameFocus = FocusNode();

  late final TapGestureRecognizer _termsTap = TapGestureRecognizer()
    ..onTap = () => _openLegal(LegalDoc.terms);
  late final TapGestureRecognizer _privacyTap = TapGestureRecognizer()
    ..onTap = () => _openLegal(LegalDoc.privacy);

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.initialIsSignUp;
    _passwordController.addListener(() {
      if (_isSignUp && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _nameFocus.dispose();
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  void _setMode(bool signUp) {
    setState(() {
      _isSignUp = signUp;
      _errorMessage = null;
    });
  }

  String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      if (_isSignUp) {
        await widget.authRepository.signUp(
          _emailController.text,
          _passwordController.text,
          displayName: _nameController.text,
        );
      } else {
        await widget.authRepository.signIn(_emailController.text, _passwordController.text);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _clean(e);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _google() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });
    try {
      await widget.authRepository.signInWithGoogle();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _clean(e);
          _isGoogleLoading = false;
        });
      }
    }
  }

  void _openLegal(LegalDoc doc) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => LegalScreen(doc: doc)));
  }

  void _showForgotPasswordDialog() {
    final resetController = TextEditingController(text: _emailController.text.trim());
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('We’ll email you a link to set a new password.'),
            const SizedBox(height: 16),
            TextField(
              controller: resetController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final email = resetController.text.trim();
              if (email.isEmpty) return;
              Navigator.of(ctx).pop();
              try {
                await widget.authRepository.sendPasswordResetEmail(email);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Reset link sent to $email')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_clean(e))),
                  );
                }
              }
            },
            child: const Text('Send link'),
          ),
        ],
      ),
    ).whenComplete(resetController.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = _isLoading || _isGoogleLoading;

    return Scaffold(
      appBar: AppBar(title: Text(_isSignUp ? 'Create account' : 'Sign in')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(alignment: Alignment.centerLeft, child: TechDailyWordmark(size: 24)),
                      const SizedBox(height: 18),
                      Text(
                        _isSignUp ? 'Create your account' : 'Welcome back',
                        style: AppTheme.display(28, color: theme.colorScheme.onSurface),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isSignUp
                            ? 'Save stories across devices and get the daily brief.'
                            : 'Sign in to sync your saved stories.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 22),
                      SegmentedButton<bool>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: false, label: Text('Sign in')),
                          ButtonSegment(value: true, label: Text('Create account')),
                        ],
                        selected: {_isSignUp},
                        onSelectionChanged: busy ? null : (s) => _setMode(s.first),
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: busy ? null : _google,
                        icon: _isGoogleLoading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const _GoogleG(),
                        label: const Text('Continue with Google'),
                      ),
                      const SizedBox(height: 16),
                      Row(children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('or use email', style: theme.textTheme.bodySmall),
                        ),
                        const Expanded(child: Divider()),
                      ]),
                      const SizedBox(height: 16),
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.live.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.live.withValues(alpha: 0.4)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.error_outline_rounded, color: AppTheme.live, size: 20),
                            const SizedBox(width: 10),
                            Expanded(child: Text(_errorMessage!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface))),
                          ]),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_isSignUp) ...[
                        TextFormField(
                          key: const ValueKey('auth-name'),
                          controller: _nameController,
                          focusNode: _nameFocus,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          validator: (v) => _isSignUp && (v == null || v.trim().isEmpty)
                              ? 'Please enter your name.'
                              : null,
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextFormField(
                        key: const ValueKey('auth-email'),
                        controller: _emailController,
                        focusNode: _emailFocus,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.email, AutofillHints.username],
                        onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'you@example.com',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          if (value.isEmpty) return 'Please enter your email.';
                          if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                            return 'Please enter a valid email address.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const ValueKey('auth-password'),
                        controller: _passwordController,
                        focusNode: _passwordFocus,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: [_isSignUp ? AutofillHints.newPassword : AutofillHints.password],
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                            icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (v) {
                          final value = v ?? '';
                          if (value.isEmpty) return 'Please enter your password.';
                          if (_isSignUp && !PasswordRules.isValid(value)) {
                            return 'Password doesn’t meet the rules below.';
                          }
                          return null;
                        },
                      ),
                      if (_isSignUp) ...[
                        const SizedBox(height: 10),
                        _RuleLine(ok: PasswordRules.hasLength(_passwordController.text), text: 'At least ${PasswordRules.minLength} characters'),
                        _RuleLine(ok: PasswordRules.hasLetter(_passwordController.text), text: 'At least one letter'),
                        _RuleLine(ok: PasswordRules.hasNumber(_passwordController.text), text: 'At least one number'),
                        const SizedBox(height: 16),
                      ] else
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: busy ? null : _showForgotPasswordDialog,
                            child: const Text('Forgot password?'),
                          ),
                        ),
                      const SizedBox(height: 4),
                      FilledButton(
                        onPressed: busy ? null : _submit,
                        child: _isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(_isSignUp ? 'Create account' : 'Sign in'),
                      ),
                      const SizedBox(height: 18),
                      Text.rich(
                        TextSpan(
                          style: theme.textTheme.bodySmall,
                          children: [
                            TextSpan(text: _isSignUp ? 'By creating an account you agree to our ' : 'By continuing you agree to our '),
                            TextSpan(
                              text: 'Terms',
                              style: TextStyle(color: AppTheme.accentOf(context), fontWeight: FontWeight.w600),
                              recognizer: _termsTap,
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(color: AppTheme.accentOf(context), fontWeight: FontWeight.w600),
                              recognizer: _privacyTap,
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RuleLine extends StatelessWidget {
  final bool ok;
  final String text;
  const _RuleLine({required this.ok, required this.text});

  @override
  Widget build(BuildContext context) {
    final color = ok ? const Color(0xFF16A34A) : AppTheme.mutedOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 16, color: color),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(fontSize: 13, color: color)),
      ]),
    );
  }
}

/// Simple multi-colour "G" mark drawn with text (no external asset).
class _GoogleG extends StatelessWidget {
  const _GoogleG();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFDADCE0)),
      ),
      child: const Text(
        'G',
        style: TextStyle(
          fontFamily: AppTheme.bodyFont,
          fontWeight: FontWeight.w800,
          fontSize: 13,
          height: 1,
          color: Color(0xFF4285F4),
        ),
      ),
    );
  }
}
