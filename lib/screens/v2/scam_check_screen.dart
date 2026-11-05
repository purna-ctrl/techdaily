import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_language.dart';
import '../../services/v2/scam_check.dart';
import '../../widgets/v2/story_parts.dart' show openExternal;
import '../../widgets/v3/ui.dart';

/// Official reporting page for fraud calls / SMS / WhatsApp (DoT Sanchar Saathi → Chakshu).
const String kChakshuUrl = 'https://sancharsaathi.gov.in/sfc/';

/// Verdict colours, matching "Scam or Not?" (red / amber / green).
Color scamLevelColor(ScamLevel l) => switch (l) {
      ScamLevel.scam => TD.red,
      ScamLevel.suspicious => const Color(0xFFFFB020),
      ScamLevel.safe => const Color(0xFF22C55E),
    };

Color _tint(ScamLevel l) => switch (l) {
      ScamLevel.scam => TD.redTint,
      ScamLevel.suspicious => const Color(0xFFFFCB66),
      ScamLevel.safe => const Color(0xFF4ADE80),
    };

String scamLevelLabel(ScamLevel l) => switch (l) {
      ScamLevel.scam => tr('Scam'),
      ScamLevel.suspicious => tr('Suspicious'),
      ScamLevel.safe => tr('Looks safe'),
    };

/// "Is this a scam?" — paste an SMS / WhatsApp / email, get Scam / Suspicious /
/// Looks safe with the red flags and what to do. AI via the Worker; a rule-based
/// quick check on the device when it can't be reached.
class ScamCheckScreen extends StatefulWidget {
  final ScamCheckService? service;
  final String? initialText;
  const ScamCheckScreen({super.key, this.service, this.initialText});

  static Future<void> open(BuildContext context) => Navigator.of(context).pushNamed('/app/scam-check');

  @override
  State<ScamCheckScreen> createState() => _ScamCheckScreenState();
}

class _ScamCheckScreenState extends State<ScamCheckScreen> {
  late final TextEditingController _text = TextEditingController(text: widget.initialText ?? '');
  final TextEditingController _sender = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final GlobalKey _resultKey = GlobalKey();
  late final ScamCheckService _service = widget.service ?? ScamCheckService();
  ScamVerdict? _result;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    _sender.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final text = _text.text.trim();
    if (text.length < 4) {
      setState(() => _error = tr('Paste a message first.'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    final v = await _service.check(text, sender: _sender.text, lang: appLanguage.value.code);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = v;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _resultKey.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic, alignment: 0.05);
    });
  }

  Future<void> _paste() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final t = data?.text?.trim();
      if (t != null && t.isNotEmpty) {
        _text.text = t.length > kScamMaxChars ? t.substring(0, kScamMaxChars) : t;
        setState(() => _error = null);
      }
    } catch (_) {}
  }

  void _example(int i) {
    final (sender, text) = kScamExamples[i];
    setState(() {
      _sender.text = sender;
      _text.text = text;
      _result = null;
      _error = null;
    });
  }

  void _reset() {
    setState(() {
      _text.clear();
      _sender.clear();
      _result = null;
      _error = null;
    });
    _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final field = InputDecoration(
      filled: true,
      fillColor: const Color(0xFF1B1B23),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: TD.glassBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: TD.glassBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFB090F9), width: 1.4)),
      hintStyle: const TextStyle(color: Color(0xFF8E8A83)),
    );
    return Scaffold(
      backgroundColor: TD.bg,
      appBar: AppBar(
        backgroundColor: TD.bg,
        title: Text(tr('Is this a scam?'), style: AppTheme.display(20, color: TD.ink)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(controller: _scroll, padding: const EdgeInsets.fromLTRB(12, 4, 12, 40), children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(TD.rLg),
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1B1530), Color(0xFF121218), Color(0xFF0F1D1A)]),
                border: Border.all(color: TD.glassBorder),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(11)),
                    child: const Icon(Icons.policy_rounded, color: Color(0xFFB090F9), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(tr('Got a strange SMS, WhatsApp or email? Paste it and check.'), style: const TextStyle(color: TD.ink, fontSize: 14.5, height: 1.4))),
                ]),
                const SizedBox(height: 14),
                Semantics(
                  label: tr('Paste the message'),
                  child: TextField(
                    key: const ValueKey('scam-text'),
                    controller: _text,
                    minLines: 5,
                    maxLines: 10,
                    maxLength: kScamMaxChars,
                    style: const TextStyle(color: TD.ink, fontSize: 15, height: 1.45),
                    decoration: field.copyWith(hintText: tr('Paste the SMS, WhatsApp or email text here'), counterStyle: const TextStyle(color: TD.muted, fontSize: 11)),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  key: const ValueKey('scam-sender'),
                  controller: _sender,
                  maxLength: 80,
                  style: const TextStyle(color: TD.ink, fontSize: 14.5),
                  decoration: field.copyWith(
                    labelText: tr('Sender (optional)'),
                    labelStyle: const TextStyle(color: TD.muted),
                    hintText: tr('e.g. VM-SBIINB, +91 98xxxxxx21, offers@…'),
                    counterText: '',
                    isDense: true,
                    prefixIcon: const Icon(Icons.person_outline_rounded, color: TD.muted, size: 20),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: TD.focus, fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 12),
                Row(children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: TD.ink, shape: const StadiumBorder(), minimumSize: const Size(0, 48), side: const BorderSide(color: TD.glassBorder)),
                    onPressed: _busy ? null : _paste,
                    icon: const Icon(Icons.content_paste_rounded, size: 18),
                    label: Text(tr('Paste')),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('scam-check'),
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB090F9), foregroundColor: TD.bg, shape: const StadiumBorder(), minimumSize: const Size(0, 50)),
                      onPressed: _busy ? null : _check,
                      icon: _busy
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: TD.bg))
                          : const Icon(Icons.shield_rounded),
                      label: Text(_busy ? tr('Checking…') : tr('Check'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Text(tr('Try an example'), style: AppTheme.kicker(size: 11.5, color: TD.muted)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  for (var i = 0; i < kScamExamples.length; i++)
                    ActionChip(
                      key: ValueKey('scam-example-$i'),
                      backgroundColor: const Color(0x14FFFFFF),
                      side: const BorderSide(color: TD.glassBorder),
                      shape: const StadiumBorder(),
                      avatar: Icon(const [Icons.account_balance_rounded, Icons.local_shipping_rounded, Icons.bolt_rounded][i], size: 16, color: TD.ink),
                      label: Text(const ['SBI KYC', 'Amazon', 'Electricity'][i], style: const TextStyle(color: TD.ink)),
                      onPressed: _busy ? null : () => _example(i),
                    ),
                ]),
                const SizedBox(height: 12),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.lock_outline_rounded, size: 15, color: TD.muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(tr('We don’t save your message. It is sent once to our AI checker and then forgotten.'),
                        style: const TextStyle(color: TD.muted, fontSize: 12.5, height: 1.4)),
                  ),
                ]),
              ]),
            ),
            if (_result != null) ...[
              const SizedBox(height: 16),
              ScamResultCard(key: _resultKey, verdict: _result!, onAgain: _reset),
            ],
          ]),
        ),
      ),
    );
  }
}

/// The verdict card (red / amber / green).
class ScamResultCard extends StatelessWidget {
  final ScamVerdict verdict;
  final VoidCallback? onAgain;
  const ScamResultCard({super.key, required this.verdict, this.onAgain});

  @override
  Widget build(BuildContext context) {
    final color = scamLevelColor(verdict.level);
    final tint = _tint(verdict.level);
    final icon = switch (verdict.level) {
      ScamLevel.scam => Icons.gpp_bad_rounded,
      ScamLevel.suspicious => Icons.report_problem_rounded,
      ScamLevel.safe => Icons.verified_user_rounded,
    };
    final risky = verdict.level != ScamLevel.safe;
    final english = verdict.lang == 'en' && appLanguage.value != AppLang.en;
    Widget heading(String t) => Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Semantics(header: true, child: Text(t.toUpperCase(), style: AppTheme.kicker(size: 11.5, color: tint))),
        );
    Widget bullet(String t, IconData i, Color c) => Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 2), child: Icon(i, size: 16, color: c)),
            const SizedBox(width: 8),
            Expanded(child: Text(t, style: const TextStyle(fontSize: 14.5, height: 1.45, color: TD.ink))),
          ]),
        );
    return Semantics(
      container: true,
      liveRegion: true,
      label: scamLevelLabel(verdict.level),
      child: Container(
        key: const ValueKey('scam-result'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(TD.rLg),
          color: color.withValues(alpha: 0.09),
          border: Border.all(color: color.withValues(alpha: 0.7), width: 1.4),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.22), blurRadius: 24, spreadRadius: -6)],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 18, color: TD.bg),
                const SizedBox(width: 6),
                Text(scamLevelLabel(verdict.level), key: const ValueKey('scam-verdict'), style: AppTheme.display(16, color: TD.bg)),
              ]),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                verdict.offline ? tr('Quick check (offline)') : tr('Checked by AI'),
                textAlign: TextAlign.end,
                style: AppTheme.kicker(size: 11, color: verdict.offline ? TD.focus : TD.muted),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Text(verdict.summary, style: AppTheme.display(18, color: TD.ink, height: 1.3)),
          if (verdict.offline) ...[
            const SizedBox(height: 6),
            Text(tr('Couldn’t reach the AI checker, so this is a quick check on your phone.'), style: const TextStyle(fontSize: 12.5, color: TD.muted, height: 1.4)),
          ],
          if (english) ...[
            const SizedBox(height: 6),
            Text(tr('Translation not available right now — showing English.'), style: const TextStyle(fontSize: 12.5, color: TD.focus)),
          ],
          heading(tr('Why')),
          for (final r in verdict.reasons) bullet(r, risky ? Icons.warning_rounded : Icons.check_rounded, risky ? TD.focus : const Color(0xFF4ADE80)),
          if (verdict.actions.isNotEmpty) ...[
            heading(tr('What to do now')),
            for (var i = 0; i < verdict.actions.length; i++) bullet(verdict.actions[i], Icons.task_alt_rounded, tint),
          ],
          if (risky) ...[
            const SizedBox(height: 14),
            Text(tr('Lost money or shared an OTP? Call 1930 now.'), style: const TextStyle(fontWeight: FontWeight.w700, color: TD.ink, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: TD.red, foregroundColor: TD.bg, shape: const StadiumBorder(), minimumSize: const Size(0, 42)),
                onPressed: () => openExternal(context, 'tel:1930'),
                icon: const Icon(Icons.call_rounded, size: 18),
                label: const Text('1930'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: TD.ink, shape: const StadiumBorder(), minimumSize: const Size(0, 42), side: const BorderSide(color: TD.glassBorder)),
                onPressed: () => openExternal(context, kChakshuUrl),
                icon: const Icon(Icons.flag_rounded, size: 18),
                label: Text(tr('Report on Chakshu')),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: TD.ink, shape: const StadiumBorder(), minimumSize: const Size(0, 42), side: const BorderSide(color: TD.glassBorder)),
                onPressed: () => openExternal(context, 'https://cybercrime.gov.in'),
                icon: const Icon(Icons.local_police_rounded, size: 18),
                label: const Text('cybercrime.gov.in'),
              ),
            ]),
          ],
          const SizedBox(height: 14),
          Row(children: [
            const Icon(Icons.info_outline_rounded, size: 15, color: TD.muted),
            const SizedBox(width: 6),
            Expanded(child: Text(tr('This is a guide, not a guarantee.'), key: const ValueKey('scam-disclaimer'), style: const TextStyle(fontSize: 12.5, color: TD.muted))),
          ]),
          if (onAgain != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(onPressed: onAgain, icon: const Icon(Icons.refresh_rounded, size: 18), label: Text(tr('Check another message'))),
            ),
        ]),
      ),
    );
  }
}

/// Entry button used on the Scam Radar card, the Scams & Security tab and the
/// Scam or Not card.
class ScamCheckButton extends StatelessWidget {
  final bool filled;
  const ScamCheckButton({super.key, this.filled = true});

  @override
  Widget build(BuildContext context) {
    final label = Text(tr('Is this a scam?'), style: const TextStyle(fontWeight: FontWeight.w800));
    if (filled) {
      return FilledButton.icon(
        key: const ValueKey('open-scam-check'),
        style: FilledButton.styleFrom(backgroundColor: TD.ink, foregroundColor: TD.bg, shape: const StadiumBorder(), minimumSize: const Size(0, 42)),
        onPressed: () => unawaited(ScamCheckScreen.open(context)),
        icon: const Icon(Icons.policy_rounded, size: 18),
        label: label,
      );
    }
    return OutlinedButton.icon(
      key: const ValueKey('open-scam-check-outline'),
      style: OutlinedButton.styleFrom(foregroundColor: TD.ink, shape: const StadiumBorder(), minimumSize: const Size(0, 42), side: const BorderSide(color: Color(0xFFB090F9))),
      onPressed: () => unawaited(ScamCheckScreen.open(context)),
      icon: const Icon(Icons.policy_rounded, size: 18, color: Color(0xFFB090F9)),
      label: label,
    );
  }
}

/// Prominent "Is this a scam?" card (Scams & Security tab, and home when there
/// is no scam story on the radar).
class ScamCheckEntryCard extends StatelessWidget {
  const ScamCheckEntryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: const ValueKey('scam-check-card'),
          borderRadius: BorderRadius.circular(TD.rLg),
          onTap: () => unawaited(ScamCheckScreen.open(context)),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TD.rLg),
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2A0F14), Color(0xFF1B1530)]),
              border: Border.all(color: TD.red.withValues(alpha: 0.55)),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: TD.red.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.policy_rounded, color: TD.redTint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr('Is this a scam?'), style: AppTheme.display(19, color: TD.ink)),
                  const SizedBox(height: 3),
                  Text(tr('Got a strange SMS, WhatsApp or email? Paste it and check.'), style: const TextStyle(color: TD.muted, fontSize: 13.5, height: 1.35)),
                ]),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: TD.ink),
            ]),
          ),
        ),
      ),
    );
  }
}
