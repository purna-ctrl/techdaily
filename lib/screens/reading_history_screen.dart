import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/date_utils.dart';
import '../models/reading_history_item.dart';
import '../repositories/article_repository.dart';
import '../repositories/auth_repository.dart';
import '../services/reading_history_service.dart';
import '../widgets/source_badge.dart';
import 'article_screen.dart';

class ReadingHistoryScreen extends StatefulWidget {
  final ArticleRepository repository;
  final AuthRepository? authRepository;
  final ReadingHistoryService? historyService;

  const ReadingHistoryScreen({
    super.key,
    required this.repository,
    this.authRepository,
    this.historyService,
  });

  @override
  State<ReadingHistoryScreen> createState() => _ReadingHistoryScreenState();
}

class _ReadingHistoryScreenState extends State<ReadingHistoryScreen> {
  late final ReadingHistoryService _historyService;
  List<ReadingHistoryItem> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _historyService = widget.historyService ?? ReadingHistoryService();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final items = await _historyService.getHistory();
    if (mounted) {
      setState(() {
        _history = items;
        _isLoading = false;
      });
    }
  }

  Future<void> _removeItem(String articleId) async {
    await _historyService.removeItem(articleId);
    _loadHistory();
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Reading History?'),
        content: const Text('This will delete your local device reading history. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('CLEAR ALL'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _historyService.clearHistory();
      _loadHistory();
    }
  }

  void _openArticle(ReadingHistoryItem item) async {
    final article = await widget.repository.getArticleById(item.articleId);
    if (article != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ArticleScreen(
            article: article,
            repository: widget.repository,
            authRepository: widget.authRepository,
          ),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Story is no longer available in the current wire cache.')),
      );
    }
  }

  Map<String, List<ReadingHistoryItem>> _groupHistory() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    final groups = <String, List<ReadingHistoryItem>>{
      'TODAY': [],
      'YESTERDAY': [],
      'EARLIER THIS WEEK': [],
      'OLDER': [],
    };

    for (final item in _history) {
      final itemDate = DateTime(item.readAt.year, item.readAt.month, item.readAt.day);
      if (itemDate.isAtSameMomentAs(today) || itemDate.isAfter(today)) {
        groups['TODAY']!.add(item);
      } else if (itemDate.isAtSameMomentAs(yesterday)) {
        groups['YESTERDAY']!.add(item);
      } else if (itemDate.isAfter(weekAgo)) {
        groups['EARLIER THIS WEEK']!.add(item);
      } else {
        groups['OLDER']!.add(item);
      }
    }

    // Remove empty groups
    groups.removeWhere((k, v) => v.isEmpty);
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'READING HISTORY',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              'Stored privately on your device',
              style: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: 'Clear All History',
              onPressed: _confirmClearAll,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 56,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Reading History Yet',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Articles you open will be saved locally on this device for easy access.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: AppConstants.maxContentWidth),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: _buildGroupedList(theme, isDark),
                    ),
                  ),
                ),
    );
  }

  List<Widget> _buildGroupedList(ThemeData theme, bool isDark) {
    final grouped = _groupHistory();
    final widgets = <Widget>[];

    for (final entry in grouped.entries) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 8),
          child: Text(
            entry.key,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
              color: isDark ? AppTheme.cyberCyan : theme.colorScheme.primary,
            ),
          ),
        ),
      );

      for (final item in entry.value) {
        final catAccent = AppTheme.getCategoryAccent(item.category, isDark: isDark);
        widgets.add(
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E26) : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDark ? const Color(0xFF2A2A33) : const Color(0xFFE3DFD5),
                width: 0.8,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              onTap: () => _openArticle(item),
              title: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: catAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        item.category.toUpperCase(),
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: catAccent),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SourceBadge(sourceName: item.sourceName, fontSize: 9),
                    const SizedBox(width: 6),
                    Text(
                      '•  ${AppDateUtils.formatRelativeTime(item.readAt)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close_rounded, size: 16),
                tooltip: 'Remove',
                onPressed: () => _removeItem(item.articleId),
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }
}
