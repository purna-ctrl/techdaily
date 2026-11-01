import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';
import '../models/article.dart';
import '../services/article_ai_assistant_service.dart';

/// "Ask AI about this story" — calls the backend and falls back to grounded
/// on-device answers when the backend is unreachable.
class AskAiSection extends StatefulWidget {
  final Article article;
  final ArticleAiAssistantService? assistantService;

  const AskAiSection({
    super.key,
    required this.article,
    this.assistantService,
  });

  @override
  State<AskAiSection> createState() => _AskAiSectionState();
}

class _AiMessage {
  final String text;
  final bool isUser;
  final bool isFallback;

  const _AiMessage({required this.text, required this.isUser, this.isFallback = false});
}

class _AskAiSectionState extends State<AskAiSection> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final ArticleAiAssistantService _assistantService;
  final List<_AiMessage> _messages = [];
  bool _isThinking = false;

  static const List<String> _prompts = [
    'Explain this simply',
    'Why is this important?',
    'What could happen next?',
    'What does this mean for users?',
  ];

  @override
  void initState() {
    super.initState();
    _assistantService = widget.assistantService ?? ArticleAiAssistantService();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleAsk(String question) async {
    final q = question.trim();
    if (q.isEmpty || _isThinking) return;
    _inputController.clear();
    setState(() {
      _messages.add(_AiMessage(text: q, isUser: true));
      _isThinking = true;
    });

    final answer = await _assistantService.ask(widget.article, q);
    if (!mounted) return;
    setState(() {
      _isThinking = false;
      _messages.add(_AiMessage(
        text: answer.text,
        isUser: false,
        isFallback: answer.source == AiAnswerSource.localFallback,
      ));
    });
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Answer copied'), duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppTheme.accentOf(context);
    final muted = AppTheme.mutedOf(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.auto_awesome_rounded, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ask AI', style: AppTheme.display(18, color: theme.colorScheme.onSurface)),
                    Text('Answers stick to what this story says.',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _prompts
                .map((p) => ActionChip(
                      label: Text(p),
                      onPressed: _isThinking ? null : () => _handleAsk(p),
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                    ))
                .toList(),
          ),
          if (_messages.isNotEmpty) ...[
            const SizedBox(height: 16),
            ..._messages.map((m) => _buildBubble(context, m)),
          ],
          if (_isThinking)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                  ),
                  const SizedBox(width: 10),
                  Text('Thinking…', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          const SizedBox(height: 14),
          TextField(
            controller: _inputController,
            focusNode: _focusNode,
            textInputAction: TextInputAction.send,
            onSubmitted: _handleAsk,
            onTapOutside: (_) => _focusNode.unfocus(),
            maxLength: 500,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            decoration: InputDecoration(
              hintText: 'Ask anything about this story',
              prefixIcon: Icon(Icons.chat_bubble_outline_rounded, color: muted),
              suffixIcon: IconButton(
                tooltip: 'Ask',
                icon: Icon(Icons.arrow_upward_rounded, color: accent),
                onPressed: () => _handleAsk(_inputController.text),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(BuildContext context, _AiMessage m) {
    final theme = Theme.of(context);
    final isDark = AppTheme.isDark(context);
    final bg = m.isUser
        ? (isDark ? AppTheme.paper : AppTheme.ink)
        : AppTheme.surfaceAltOf(context);
    final fg = m.isUser ? (isDark ? AppTheme.ink : AppTheme.paper) : theme.colorScheme.onSurface;
    return Align(
      alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: const BoxConstraints(maxWidth: 560),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(m.isUser ? 16 : 4),
            bottomRight: Radius.circular(m.isUser ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              m.text,
              style: TextStyle(fontSize: 14.5, height: 1.5, color: fg),
            ),
            if (!m.isUser)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    m.isFallback ? 'From the article' : 'AI answer',
                    style: theme.textTheme.labelSmall,
                  ),
                  IconButton(
                    tooltip: 'Copy',
                    visualDensity: VisualDensity.compact,
                    iconSize: 16,
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: () => _copy(m.text),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
