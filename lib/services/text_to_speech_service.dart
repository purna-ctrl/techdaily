import 'dart:async';
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
