import 'article.dart';

class WeeklyRecap {
  final DateTime startDate;
  final DateTime endDate;
  final String title;
  final List<Article> topStories;
  final Map<String, List<Article>> sectorBreakdown;
  final List<String> majorMilestones;
  final List<String> whatToWatchNextWeek;

  WeeklyRecap({
    required this.startDate,
    required this.endDate,
    required this.title,
    required this.topStories,
    required this.sectorBreakdown,
    required this.majorMilestones,
    required this.whatToWatchNextWeek,
  });
}
