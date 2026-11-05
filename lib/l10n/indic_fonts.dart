import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Telugu and Devanagari glyphs for the web (CanvasKit draws text itself and
/// only knows the fonts it is given). Bundled Noto Sans (SIL OFL) files are
/// loaded on demand — only when Telugu / Hindi text is about to be shown — so
/// English readers never download them. Android has these scripts built in,
/// but loading them there is harmless and keeps the look identical.
const String kTeluguFont = 'NotoSansTelugu';
const String kDevanagariFont = 'NotoSansDevanagari';

/// Added after the brand fonts in every text style.
const List<String> kIndicFallback = [kTeluguFont, kDevanagariFont];

Future<void>? _loading;

/// Loads both scripts once (regular + bold). Safe to call many times.
Future<void> ensureIndicFonts() => _loading ??= _load();

Future<void> _load() async {
  if (_isTest) return;
  Future<void> family(String name, List<String> files) async {
    try {
      final loader = FontLoader(name);
      for (final f in files) {
        loader.addFont(rootBundle.load('assets/fonts/noto/$f'));
      }
      await loader.load();
    } catch (e) {
      debugPrint('Indic font $name not loaded: $e');
    }
  }

  await Future.wait([
    family(kTeluguFont, const ['NotoSansTelugu-Regular.ttf', 'NotoSansTelugu-Bold.ttf']),
    family(kDevanagariFont, const ['NotoSansDevanagari-Regular.ttf', 'NotoSansDevanagari-Bold.ttf']),
  ]);
}

bool get _isTest {
  try {
    return const bool.fromEnvironment('FLUTTER_TEST') || ServicesBinding.instance.runtimeType.toString().contains('Test');
  } catch (_) {
    return false;
  }
}
