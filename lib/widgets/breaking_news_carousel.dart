import 'package:flutter/material.dart';
import '../models/article.dart';
import 'breaking_news_card.dart';

class BreakingNewsCarousel extends StatefulWidget {
  final List<Article> articles;
  final Set<String> savedIds;
  final void Function(Article) onArticleTap;
  final void Function(Article) onToggleSave;

  const BreakingNewsCarousel({
    super.key,
    required this.articles,
    required this.savedIds,
    required this.onArticleTap,
    required this.onToggleSave,
  });

  @override
  State<BreakingNewsCarousel> createState() => _BreakingNewsCarouselState();
}

class _BreakingNewsCarouselState extends State<BreakingNewsCarousel> {
  int _currentIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.articles.isEmpty) return const SizedBox.shrink();

    // Single article: render directly
    if (widget.articles.length == 1) {
      final article = widget.articles.first;
      return BreakingNewsCard(
        article: article,
        isSaved: widget.savedIds.contains(article.id),
        onTap: () => widget.onArticleTap(article),
        onToggleSave: () => widget.onToggleSave(article),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentRed = isDark ? const Color(0xFFFF334B) : const Color(0xFFDC2626);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Multi-breaking story indicator bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accentRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  '${_currentIndex + 1} OF ${widget.articles.length} CRITICAL UPDATES',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: accentRed,
                  ),
                ),
              ),
              const Spacer(),
              // Page indicator dots
              Row(
                children: List.generate(widget.articles.length, (index) {
                  final isSelected = index == _currentIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    width: isSelected ? 16 : 6,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accentRed
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.2)
                              : Colors.black.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        // Swipable Carousel
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.articles.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              final article = widget.articles[index];
              return BreakingNewsCard(
                article: article,
                isSaved: widget.savedIds.contains(article.id),
                onTap: () => widget.onArticleTap(article),
                onToggleSave: () => widget.onToggleSave(article),
              );
            },
          ),
        ),
      ],
    );
  }
}
