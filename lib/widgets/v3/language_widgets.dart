import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/stories_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_language.dart';
import '../../l10n/indic_fonts.dart';
import '../../models/story.dart';
import '../../services/text_to_speech_service.dart';
import '../../services/v2/story_translator.dart';
import 'story_cards.dart' show oneLiner;
import 'ui.dart';

/// Small language chip in the home header (EN / తె / हि). Shows an orange dot
/// until the reader has chosen a language once (first-launch hint).
class LanguageChip extends StatelessWidget {
  const LanguageChip({super.key});

  static String short(AppLang l) => switch (l) { AppLang.te => 'తె', AppLang.hi => 'हि', _ => 'EN' };

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLang>(
      valueListenable: appLanguage,
      builder: (context, lang, _) => ListenableBuilder(
        listenable: appLanguage,
        builder: (context, _) {
          final hint = appLanguage.loaded && !appLanguage.asked;
          return Tooltip(
            message: tr('Language'),
            child: InkWell(
              key: const ValueKey('language-chip'),
              customBorder: const StadiumBorder(),
              onTap: () => showLanguageSheet(context),
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0x14FFFFFF),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: hint ? const Color(0xFFFF8255) : TD.glassBorder),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.translate_rounded, size: 16, color: TD.ink),
                  const SizedBox(width: 5),
                  Text(short(lang), style: AppTheme.kicker(size: 12.5, color: TD.ink).copyWith(letterSpacing: 0)),
                  if (hint) ...[
                    const SizedBox(width: 5),
                    Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFFFF8255), shape: BoxShape.circle)),
                  ],
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Bottom sheet: English / తెలుగు / हिन्दी.
Future<void> showLanguageSheet(BuildContext context) {
  unawaited(ensureIndicFonts());
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: TD.surface,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('Read TechDaily in your language'), style: AppTheme.display(19, color: TD.ink)),
          const SizedBox(height: 6),
          Text(tr('Menus are translated here; stories are translated by AI when you open them.'), style: const TextStyle(color: TD.muted, fontSize: 13.5, height: 1.4)),
          const SizedBox(height: 10),
          const LanguageOptions(popOnPick: true),
        ]),
      ),
    ),
  ).whenComplete(() {
    if (!appLanguage.asked) unawaited(appLanguage.dismissPrompt());
  });
}

/// The three language options (used by the sheet and Settings).
class LanguageOptions extends StatelessWidget {
  final bool popOnPick;
  const LanguageOptions({super.key, this.popOnPick = false});

  @override
  Widget build(BuildContext context) {
    unawaited(ensureIndicFonts());
    return ValueListenableBuilder<AppLang>(
      valueListenable: appLanguage,
      builder: (context, current, _) => RadioGroup<AppLang>(
        groupValue: current,
        onChanged: (l) {
          if (l == null) return;
          unawaited(appLanguage.set(l));
          if (popOnPick) Navigator.of(context).maybePop();
        },
        child: Column(children: [
          for (final l in AppLang.values)
            RadioListTile<AppLang>(
              key: ValueKey('lang-${l.code}'),
              value: l,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: Text(l.nativeName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              subtitle: l == AppLang.en ? null : Text(l.englishName),
            ),
        ]),
      ),
    );
  }
}

/// "Translating…" / "Showing English" pill for translated screens.
class TranslationNote extends StatelessWidget {
  final TrStatus status;
  final VoidCallback? onRetry;
  const TranslationNote({super.key, required this.status, this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (status == TrStatus.english) return const SizedBox.shrink();
    final (icon, text, color) = switch (status) {
      TrStatus.pending => (Icons.translate_rounded, tr('Translating…'), TD.muted),
      TrStatus.failed => (Icons.info_outline_rounded, tr('Showing English'), TD.focus),
      _ => (Icons.auto_awesome_rounded, tr('Translated by AI'), TD.muted),
    };
    return Semantics(
      liveRegion: true,
      child: InkWell(
        key: ValueKey('tr-note-${status.name}'),
        onTap: status == TrStatus.failed ? onRetry : null,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: const Color(0x14FFFFFF), borderRadius: BorderRadius.circular(999), border: Border.all(color: TD.glassBorder)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (status == TrStatus.pending)
              const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.6, color: TD.muted))
            else
              Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            if (status == TrStatus.failed && onRetry != null) ...[
              const SizedBox(width: 6),
              const Icon(Icons.refresh_rounded, size: 14, color: TD.focus),
            ],
          ]),
        ),
      ),
    );
  }
}

/// The spoken "Today in 5" brief: headline + one line for each story.
String briefScript(List<Story> stories, {required String intro}) {
  final b = StringBuffer('$intro.\n');
  for (var i = 0; i < stories.length; i++) {
    final s = stories[i];
    final line = oneLiner(s) ?? '';
    b.writeln('${i + 1}. ${s.headline}. $line');
  }
  return b.toString();
}

/// "Listen" for the daily brief: reads Today in 5 aloud with the device's own
/// voice (Android TTS / the browser's Web Speech API) in the app language;
/// without a voice for that language it reads the English brief and says so.
class BriefListenButton extends StatefulWidget {
  final List<Story> stories;
  const BriefListenButton({super.key, required this.stories});

  @override
  State<BriefListenButton> createState() => _BriefListenButtonState();
}

class _BriefListenButtonState extends State<BriefListenButton> {
  FlutterTtsService? _tts;
  bool _starting = false;

  FlutterTtsService get tts => _tts ??= (FlutterTtsService()..addListener(_changed));

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tts?.removeListener(_changed);
    _tts?.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    if (_starting) return;
    setState(() => _starting = true);
    final scope = StoriesScope.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final lang = appLanguage.value;
    try {
      final hasVoice = await tts.useLanguage(lang.ttsLocale);
      final english = lang == AppLang.en || !hasVoice;
      final stories = english ? widget.stories : [for (final s in widget.stories) scope.translations.card(s)];
      final intro = english ? 'TechDaily. Today in ${stories.length}' : 'TechDaily. ${tr('Today in {n}', {'n': stories.length})}';
      if (lang != AppLang.en && !hasVoice) {
        messenger?.showSnackBar(SnackBar(content: Text(tr('Voice for this language isn’t on this device — reading in English.'))));
      }
      await tts.speak(briefScript(stories, intro: intro));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playing = _tts?.state == TtsPlaybackState.playing;
    return TextButton.icon(
      key: const ValueKey('brief-listen'),
      style: TextButton.styleFrom(
        foregroundColor: TD.ink,
        backgroundColor: const Color(0x14FFFFFF),
        minimumSize: const Size(0, 30),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        shape: const StadiumBorder(side: BorderSide(color: TD.glassBorder)),
      ),
      onPressed: playing ? () => tts.stop() : _play,
      icon: _starting
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.6))
          : Icon(playing ? Icons.stop_circle_rounded : Icons.headphones_rounded, size: 17),
      label: Text(playing ? tr('Stop') : tr('Listen'), semanticsLabel: playing ? tr('Stop listening') : tr('Listen to today’s brief')),
    );
  }
}
