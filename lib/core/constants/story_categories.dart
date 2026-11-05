import 'package:flutter/material.dart';

import '../../l10n/app_language.dart' show tr;

/// TechDaily categories, in tab order after "Top Stories" (a ranked mix,
/// never stored). Ids match the backend (`functions/src/stories/categories.ts`)
/// and the static pages at `/c/<id>/` (same colours: `render/theme.ts`).
///
/// Every category has a vivid [color] used everywhere (chips, rings, rails,
/// gradients, glows) and a lighter [tint] for coloured text on dark surfaces
/// (>= 6:1). Solid chips put ink #0B0B0F text on [color] (>= 4.6:1).
class StoryCategory {
  final String id;

  /// English name (ids, URLs and the backend use this); [label] is in the
  /// reader's language.
  final String enLabel;
  final IconData icon;
  final Color color;
  final Color tint;

  const StoryCategory(this.id, this.enLabel, this.icon, this.color, this.tint);

  /// Name in the app language (English / Telugu / Hindi).
  String get label => tr(enLabel);

  /// Short label for tight places (rings, chips on small cards).
  String get shortLabel => tr(_shortEn);

  String get _shortEn => switch (id) {
        'scams-security' => 'Scams',
        'phones-gadgets' => 'Phones',
        'chips-hardware' => 'Chips',
        'startups-india' => 'Startups',
        'money-fintech' => 'Money',
        'telecom' => 'Telecom',
        'ev-mobility' => 'EVs',
        'space' => 'Space',
        'apps-gaming' => 'Apps',
        'health-tech' => 'Health',
        'jobs-skills' => 'Jobs',
        'top-stories' => 'Top',
        _ => enLabel,
      };
}

const StoryCategory kTopStories = StoryCategory(
    'top-stories', 'Top Stories', Icons.local_fire_department_rounded, Color(0xFFFF5A1F), Color(0xFFFF8255));

const List<StoryCategory> kStoryCategories = [
  StoryCategory('scams-security', 'Scams & Security', Icons.gpp_maybe_rounded, Color(0xFFFF3B4E), Color(0xFFFF7683)),
  StoryCategory('ai', 'AI', Icons.auto_awesome_rounded, Color(0xFF8B5CF6), Color(0xFFB090F9)),
  StoryCategory('phones-gadgets', 'Phones & Gadgets', Icons.smartphone_rounded, Color(0xFF3B82F6), Color(0xFF72A5F9)),
  StoryCategory('chips-hardware', 'Chips & Hardware', Icons.memory_rounded, Color(0xFF22C55E), Color(0xFF4ADE80)),
  StoryCategory('startups-india', 'Startups & India', Icons.rocket_launch_rounded, Color(0xFFFF9933), Color(0xFFFFB061)),
  StoryCategory('innovations', 'Innovations', Icons.science_rounded, Color(0xFF06B6D4), Color(0xFF22D3EE)),
  StoryCategory('money-fintech', 'Money & Fintech', Icons.currency_rupee_rounded, Color(0xFFEAB308), Color(0xFFFACC15)),
  StoryCategory('privacy', 'Privacy', Icons.lock_rounded, Color(0xFF14B8A6), Color(0xFF2DD4BF)),
  StoryCategory('telecom', 'Telecom & Internet', Icons.cell_tower_rounded, Color(0xFFE879F9), Color(0xFFF0ABFC)),
  StoryCategory('digital-india', 'Digital India', Icons.fingerprint_rounded, Color(0xFF10B981), Color(0xFF6EE7B7)),
  StoryCategory('ev-mobility', 'EVs & Mobility', Icons.electric_bolt_rounded, Color(0xFFA3E635), Color(0xFFD9F99D)),
  StoryCategory('space', 'Space Tech', Icons.satellite_alt_rounded, Color(0xFF38BDF8), Color(0xFF7DD3FC)),
  StoryCategory('apps-gaming', 'Apps & Gaming', Icons.sports_esports_rounded, Color(0xFFF472B6), Color(0xFFF9A8D4)),
  StoryCategory('health-tech', 'Health Tech', Icons.monitor_heart_rounded, Color(0xFFFB7185), Color(0xFFFDA4AF)),
  StoryCategory('jobs-skills', 'Tech Jobs & Skills', Icons.work_rounded, Color(0xFF818CF8), Color(0xFFA5B4FC)),
];

StoryCategory storyCategoryById(String id) {
  if (id == kTopStories.id) return kTopStories;
  return kStoryCategories.firstWhere((c) => c.id == id, orElse: () => kStoryCategories[5]);
}

bool isStoryCategoryId(String id) => kStoryCategories.any((c) => c.id == id);
