import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/date_utils.dart';
import '../models/daily_brief.dart';
import '../repositories/article_repository.dart';
import '../repositories/auth_repository.dart';
import '../services/daily_brief_service.dart';
import '../widgets/source_badge.dart';
import 'article_screen.dart';

class DailyBriefScreen extends StatefulWidget {
  final ArticleRepository repository;
  final AuthRepository? authRepository;
  final DailyBriefService? briefService;

  const DailyBriefScreen({
    super.key,
    required this.repository,
    this.authRepository,
    this.briefService,
  });

  @override
  State<DailyBriefScreen> createState() => _DailyBriefScreenState();
}

class _DailyBriefScreenState extends State<DailyBriefScreen> {
  late final DailyBriefService _briefService;
  DailyBrief? _brief;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _briefService = widget.briefService ?? DailyBriefService();
    _loadBrief();
  }

  Future<void> _loadBrief() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final articles = await widget.repository.getArticles();
      final brief = await _briefService.getTodayBrief(fallbackArticles: articles);
      if (mounted) {
        setState(() {
          _brief = brief;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openArticle(String articleId) async {
    final article = await widget.repository.getArticleById(articleId);
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
        const SnackBar(content: Text('Article details unavailable offline.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'EXECUTIVE DAILY BRIEF',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Brief',
            onPressed: _loadBrief,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppConstants.maxArticleWidth),
          child: _buildContent(theme, isDark),
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 52, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(
                'Briefing Unavailable',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadBrief,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('RETRY'),
              ),
            ],
          ),
        ),
      );
    }

    final brief = _brief;
    if (brief == null || brief.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.feed_outlined, size: 52, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              const Text(
                'No Briefing Compiled Yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'The daily executive brief will appear here once today\'s wire reports are indexed.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // Newspaper Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF15151B) : const Color(0xFFEFECE4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? AppTheme.cyberCyan.withValues(alpha: 0.4) : const Color(0xFFD6D1C4),
              width: 1,
            ),
            boxShadow: isDark
                ? [
                    BoxShadow(
                      color: AppTheme.cyberCyan.withValues(alpha: 0.1),
                      blurRadius: 18,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TODAY IN TECH',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                      color: isDark ? AppTheme.cyberCyan : theme.colorScheme.primary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.cyberCyan : theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'EDITION #${brief.items.length}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.black : theme.colorScheme.onPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                AppDateUtils.formatNewspaperDate(brief.date).toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                brief.subtitle,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 10 Numbered Briefing Items
        ...brief.items.map((item) => _buildBriefItemCard(theme, isDark, item)),

        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildBriefItemCard(ThemeData theme, bool isDark, DailyBriefItem item) {
    final accentColor = AppTheme.getCategoryAccent(item.category, isDark: isDark);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(
          color: isDark
              ? const Color(0xFF2A2A33)
              : theme.colorScheme.outline.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _openArticle(item.articleId),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: Rank, Category, and Source
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: isDark ? 0.15 : 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: accentColor.withValues(alpha: isDark ? 0.5 : 0.3),
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${item.rank < 10 ? '0' : ''}${item.rank}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: isDark ? 0.12 : 0.08),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: accentColor.withValues(alpha: isDark ? 0.35 : 0.25),
                        width: 0.7,
                      ),
                    ),
                    child: Text(
                      item.category.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: accentColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // 5. SOURCE
                  SourceBadge(sourceName: item.sourceName, fontSize: 10),
                ],
              ),
              const SizedBox(height: 10),

              // 1. HEADLINE
              Text(
                item.headline,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  height: 1.25,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),

              // 2. WHAT HAPPENED
              if (item.whatHappened.isNotEmpty) ...[
                Text(
                  item.whatHappened,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13.5,
                    height: 1.48,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // 3. WHY IT MATTERS
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF15151B) : const Color(0xFFEFECE4),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? AppTheme.neonBlue.withValues(alpha: 0.35) : const Color(0xFFD6D1C4),
                    width: 0.8,
                  ),
                ),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.88),
                    ),
                    children: [
                      TextSpan(
                        text: 'Why it matters: ',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppTheme.neonBlue
                              : const Color(0xFF1D4ED8),
                        ),
                      ),
                      TextSpan(text: item.whyItMatters),
                    ],
                  ),
                ),
              ),

              // 4. KEY POINTS
              if (item.keyPoints.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...item.keyPoints.take(3).map((pt) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 5, right: 8),
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: accentColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              pt,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.4,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],

              const SizedBox(height: 12),
              // Link to read full dispatch
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Read full dispatch',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppTheme.cyberCyan : theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 13,
                    color: isDark ? AppTheme.cyberCyan : theme.colorScheme.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
