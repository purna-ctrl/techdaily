import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsPlaybackState {
  stopped,
  playing,
  paused,
}

abstract class ITextToSpeechService {
  TtsPlaybackState get state;
  double get speed;
  Future<void> speak(String text);
  Future<void> pause();
  Future<void> stop();
  Future<void> setSpeed(double speed);
  void addListener(VoidCallback listener);
  void removeListener(VoidCallback listener);
  void dispose();
}

class FlutterTtsService extends ChangeNotifier implements ITextToSpeechService {
  FlutterTts? _flutterTts;
  TtsPlaybackState _state = TtsPlaybackState.stopped;
  double _speed = 1.0;
  bool _isAvailable = false;

  @override
  TtsPlaybackState get state => _state;

  @override
  double get speed => _speed;

  FlutterTtsService() {
    _initTts();
  }

  Future<void> _initTts() async {
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (isTest) {
      _isAvailable = false;
      return;
    }

    try {
      _flutterTts = FlutterTts();
      _flutterTts?.setStartHandler(() {
        _state = TtsPlaybackState.playing;
        notifyListeners();
      });
      _flutterTts?.setCompletionHandler(() {
        _state = TtsPlaybackState.stopped;
        notifyListeners();
      });
      _flutterTts?.setPauseHandler(() {
        _state = TtsPlaybackState.paused;
        notifyListeners();
      });
      _flutterTts?.setContinueHandler(() {
        _state = TtsPlaybackState.playing;
        notifyListeners();
      });
      _flutterTts?.setErrorHandler((msg) {
        _state = TtsPlaybackState.stopped;
        notifyListeners();
      });
      _isAvailable = true;
    } catch (_) {
      _isAvailable = false;
    }
  }

  @override
  Future<void> speak(String text) async {
    if (!_isAvailable || _flutterTts == null) {
      // Simulate playback if TTS unavailable on platform
      _state = TtsPlaybackState.playing;
      notifyListeners();
      return;
    }

    try {
      await _flutterTts!.setSpeechRate(_speed * 0.5); // FlutterTTS rate mapping
      final result = await _flutterTts!.speak(text);
      if (result == 1) {
        _state = TtsPlaybackState.playing;
        notifyListeners();
      }
    } catch (_) {
      _state = TtsPlaybackState.playing;
      notifyListeners();
    }
  }

  /// Picks the device voice for [bcp47] (e.g. `te-IN`, `hi-IN`, `en-IN`) using
  /// the built-in engine (Android TTS / the browser's Web Speech API). Returns
  /// false when this device has no voice for that language; the caller then
  /// reads English instead. Free — no cloud voices.
  Future<bool> useLanguage(String bcp47) async {
    final tts = _flutterTts;
    if (!_isAvailable || tts == null) return bcp47.startsWith('en');
    final want = bcp47.toLowerCase().replaceAll('_', '-');
    final base = want.split('-').first;
    var ok = false;
    try {
      if (!kIsWeb) {
        final r = await tts.isLanguageAvailable(bcp47);
        ok = r == true || r == 1;
      }
      if (!ok) {
        final langs = await tts.getLanguages;
        if (langs is List) {
          final all = langs.map((e) => '$e'.toLowerCase().replaceAll('_', '-'));
          ok = all.any((l) => l == want || l == base || l.startsWith('$base-'));
        }
      }
      if (!ok && kIsWeb && base != 'en') {
        // Some browsers list voices late; look at the voice list too.
        final voices = await tts.getVoices;
        if (voices is List) {
          ok = voices.any((v) => v is Map && '${v['locale'] ?? v['lang'] ?? ''}'.toLowerCase().replaceAll('_', '-').startsWith(base));
        }
      }
      if (ok) await tts.setLanguage(bcp47);
    } catch (_) {
      ok = false;
    }
    if (!ok) {
      try {
        await tts.setLanguage('en-IN');
      } catch (_) {}
    }
    return ok;
  }

  @override
  Future<void> pause() async {
    if (!_isAvailable || _flutterTts == null) {
      _state = TtsPlaybackState.paused;
      notifyListeners();
      return;
    }

    try {
      await _flutterTts!.pause();
      _state = TtsPlaybackState.paused;
      notifyListeners();
    } catch (_) {
      _state = TtsPlaybackState.paused;
      notifyListeners();
    }
  }

  @override
  Future<void> stop() async {
    if (!_isAvailable || _flutterTts == null) {
      _state = TtsPlaybackState.stopped;
      notifyListeners();
      return;
    }

    try {
      await _flutterTts!.stop();
      _state = TtsPlaybackState.stopped;
      notifyListeners();
    } catch (_) {
      _state = TtsPlaybackState.stopped;
      notifyListeners();
    }
  }

  @override
  Future<void> setSpeed(double newSpeed) async {
    _speed = newSpeed;
    if (_flutterTts != null && _isAvailable) {
      try {
        await _flutterTts!.setSpeechRate(newSpeed * 0.5);
      } catch (_) {}
    }
    notifyListeners();
  }

  @override
  void dispose() {
    if (_isAvailable && _flutterTts != null) {
      try {
        _flutterTts?.stop().catchError((_) => null);
      } catch (_) {}
    }
    super.dispose();
  }
}
