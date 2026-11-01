import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../models/article.dart';
import '../models/weekly_recap.dart';
import '../repositories/article_repository.dart';
import '../repositories/auth_repository.dart';
import '../services/weekly_recap_service.dart';
import '../widgets/article_card.dart';
import '../widgets/section_header.dart';
import 'article_screen.dart';

class WeeklyRecapScreen extends StatefulWidget {
  final ArticleRepository repository;
  final AuthRepository? authRepository;
  final WeeklyRecapService? recapService;

  const WeeklyRecapScreen({
    super.key,
    required this.repository,
    this.authRepository,
    this.recapService,
  });

  @override
  State<WeeklyRecapScreen> createState() => _WeeklyRecapScreenState();
}

class _WeeklyRecapScreenState extends State<WeeklyRecapScreen> {
  late final WeeklyRecapService _recapService;
  WeeklyRecap? _recap;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _recapService = widget.recapService ?? WeeklyRecapService();
    _generateRecap();
  }

  Future<void> _generateRecap() async {
    setState(() => _isLoading = true);
    final all = await widget.repository.getArticles();
    final recap = _recapService.generateWeeklyRecap(all);
    if (mounted) {
      setState(() {
        _recap = recap;
        _isLoading = false;
      });
    }
  }

  void _navigateToArticle(Article article) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArticleScreen(
          article: article,
          repository: widget.repository,
          authRepository: widget.authRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUserId = widget.authRepository?.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WEEKLY TECH RECAP',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              '7-Day Executive Intelligence Synthesis',
              style: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Synthesis',
            onPressed: _generateRecap,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _recap == null || _recap!.topStories.isEmpty
              ? const Center(child: Text('No articles available for 7-day recap.'))
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: AppConstants.maxContentWidth),
                    child: ValueListenableBuilder<Set<String>>(
                      valueListenable: widget.repository.savedArticleIdsNotifier,
                      builder: (context, savedIds, _) {
                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            // Date Banner
                            _buildDateBanner(_recap!, theme, isDark),
                            const SizedBox(height: 16),

                            // Major Milestones Section
                            _buildMilestonesCard(_recap!, theme, isDark),
                            const SizedBox(height: 20),

                            // Top Stories of the Week
                            const SectionHeader(
                              title: 'TOP STORIES THIS WEEK',
                              subtitle: 'Highest-impact dispatches across official technology channels.',
                              icon: Icons.star_rounded,
                            ),
                            const SizedBox(height: 8),
                            ..._recap!.topStories.map(
                              (article) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ArticleCard(
                                  article: article,
                                  isSaved: savedIds.contains(article.id),
                                  variant: ArticleCardVariant.standard,
                                  onTap: () => _navigateToArticle(article),
                                  onToggleSave: () => widget.repository
                                      .toggleSaveArticle(currentUserId, article.id),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // What to Watch Next Week
                            _buildWhatToWatchCard(_recap!, theme, isDark),
                            const SizedBox(height: 24),
                          ],
                        );
                      },
                    ),
                  ),
                ),
    );
  }

  Widget _buildDateBanner(WeeklyRecap recap, ThemeData theme, bool isDark) {
    final dateFormat = DateFormat('MMMM d');
    final rangeStr = '${dateFormat.format(recap.startDate)} – ${dateFormat.format(recap.endDate)}, ${recap.endDate.year}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF15151B) : const Color(0xFFEFECE4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? AppTheme.cyberCyan.withValues(alpha: 0.35)
              : theme.colorScheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: 16,
                color: isDark ? AppTheme.cyberCyan : theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'EXECUTIVE 7-DAY EDITION',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                  color: isDark ? AppTheme.cyberCyan : theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            rangeStr,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Synthesized strictly from primary wires and peer-reviewed technology sources.',
            style: TextStyle(
              fontSize: 11.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestonesCard(WeeklyRecap recap, ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E26) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A33) : const Color(0xFFE3DFD5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.flag_rounded,
                size: 18,
                color: isDark ? AppTheme.cyberCyan : theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'KEY MILESTONES THIS WEEK',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                  color: isDark ? AppTheme.cyberCyan : theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...recap.majorMilestones.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '•  ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.cyberCyan : theme.colorScheme.primary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      m,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhatToWatchCard(WeeklyRecap recap, ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101524) : const Color(0xFFF7F5F0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A33) : const Color(0xFFD6D1C4),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.visibility_rounded,
                size: 18,
                color: isDark ? AppTheme.cyberCyan : theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'WHAT TO WATCH NEXT WEEK',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                  color: isDark ? AppTheme.cyberCyan : theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...recap.whatToWatchNextWeek.map(
            (w) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.arrow_right_rounded,
                    size: 18,
                    color: isDark ? AppTheme.cyberCyan : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      w,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
