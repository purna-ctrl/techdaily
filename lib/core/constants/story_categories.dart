import 'package:flutter/material.dart';

/// TechDaily v2 categories, in tab order after "Top Stories" (a ranked mix,
/// never stored). Ids match the backend (`functions/src/stories/categories.ts`)
/// and the static pages at `/c/<id>/`.
class StoryCategory {
  final String id;
  final String label;
  final IconData icon;

  /// Used only for the generated category art and small accents.
  final Color color;

  const StoryCategory(this.id, this.label, this.icon, this.color);
}

const StoryCategory kTopStories =
    StoryCategory('top-stories', 'Top Stories', Icons.local_fire_department_rounded, Color(0xFFFF5A1F));

const List<StoryCategory> kStoryCategories = [
  StoryCategory('scams-security', 'Scams & Security', Icons.shield_rounded, Color(0xFFFF5A1F)),
  StoryCategory('ai', 'AI', Icons.auto_awesome_rounded, Color(0xFF8B6CFF)),
  StoryCategory('phones-gadgets', 'Phones & Gadgets', Icons.smartphone_rounded, Color(0xFF3B9BFF)),
  StoryCategory('chips-hardware', 'Chips & Hardware', Icons.memory_rounded, Color(0xFFF2A516)),
  StoryCategory('startups-india', 'Startups & India', Icons.trending_up_rounded, Color(0xFFEC4899)),
  StoryCategory('innovations', 'Innovations', Icons.science_rounded, Color(0xFF22C3A6)),
  StoryCategory('money-fintech', 'Money & Fintech', Icons.currency_rupee_rounded, Color(0xFF34C759)),
  StoryCategory('privacy', 'Privacy', Icons.visibility_off_rounded, Color(0xFF9AA4B2)),
];

StoryCategory storyCategoryById(String id) =>
    kStoryCategories.firstWhere((c) => c.id == id, orElse: () => kStoryCategories[5]);

bool isStoryCategoryId(String id) => kStoryCategories.any((c) => c.id == id);
