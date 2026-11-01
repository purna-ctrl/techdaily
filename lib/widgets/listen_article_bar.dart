import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/article.dart';
import '../services/text_to_speech_service.dart';

class ListenArticleBar extends StatefulWidget {
  final Article article;
  final ITextToSpeechService? ttsService;

  const ListenArticleBar({
    super.key,
    required this.article,
    this.ttsService,
  });

  @override
  State<ListenArticleBar> createState() => _ListenArticleBarState();
}

class _ListenArticleBarState extends State<ListenArticleBar> {
  late final ITextToSpeechService _tts;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _tts = widget.ttsService ?? FlutterTtsService();
    _tts.addListener(_onTtsChange);
  }

  void _onTtsChange() {
    if (!_isDisposed && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _tts.removeListener(_onTtsChange);
    _tts.stop();
    if (widget.ttsService == null) {
      _tts.dispose();
    }
    super.dispose();
  }

  String _buildNarrationText() {
    final buffer = StringBuffer();
    buffer.write(widget.article.title);
    buffer.write('. ');
    buffer.write(widget.article.summary);
    buffer.write('. ');
    if (widget.article.simpleExplanation.isNotEmpty) {
      buffer.write('In simple words: ');
      buffer.write(widget.article.simpleExplanation);
      buffer.write('. ');
    }
    if (widget.article.keyPoints.isNotEmpty) {
      buffer.write('Key takeaways: ');
      buffer.write(widget.article.keyPoints.join('. '));
    }
    return buffer.toString();
  }

  void _togglePlayPause() {
    if (_tts.state == TtsPlaybackState.playing) {
      _tts.pause();
    } else {
      _tts.speak(_buildNarrationText());
    }
  }

  void _stop() {
    _tts.stop();
  }

  void _cycleSpeed() {
    final speeds = [1.0, 1.25, 1.5, 2.0];
    final nextIndex = (speeds.indexOf(_tts.speed) + 1) % speeds.length;
    _tts.setSpeed(speeds[nextIndex]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isPlaying = _tts.state == TtsPlaybackState.playing;
    final isPaused = _tts.state == TtsPlaybackState.paused;
    final isActive = isPlaying || isPaused;

    final accent = AppTheme.accentOf(context);
    final bg = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final speedLabel = '${_tts.speed.toString().replaceAll(RegExp(r'\.0$'), '')}×';

    return Material(
      color: bg,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.borderOf(context))),
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(48, 48),
                ),
                icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                onPressed: _togglePlayPause,
                tooltip: isPlaying ? 'Pause' : 'Listen to this story',
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isActive ? (isPlaying ? 'Playing' : 'Paused') : 'Listen to this story',
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      '${widget.article.readingTimeMinutes} min  ·  device voice',
                      style: AppTheme.numeric(12, weight: FontWeight.w500, color: AppTheme.mutedOf(context)),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _cycleSpeed,
                child: Text(speedLabel, style: AppTheme.numeric(14, color: accent)),
              ),
              if (isActive)
                IconButton(
                  icon: const Icon(Icons.stop_rounded),
                  tooltip: 'Stop',
                  onPressed: _stop,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
