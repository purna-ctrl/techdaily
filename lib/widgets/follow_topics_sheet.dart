import 'package:flutter/material.dart';
import '../core/constants/categories.dart';
import '../core/theme/app_theme.dart';
import '../models/user_preferences.dart';
import '../services/offline_cache_service.dart';

class FollowTopicsSheet extends StatefulWidget {
  final UserPreferences preferences;
  final OfflineCacheService cacheService;
  final ValueChanged<UserPreferences> onUpdated;

  const FollowTopicsSheet({
    super.key,
    required this.preferences,
    required this.cacheService,
    required this.onUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required UserPreferences preferences,
    required OfflineCacheService cacheService,
    required ValueChanged<UserPreferences> onUpdated,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FollowTopicsSheet(
        preferences: preferences,
        cacheService: cacheService,
        onUpdated: onUpdated,
      ),
    );
  }

  @override
  State<FollowTopicsSheet> createState() => _FollowTopicsSheetState();
}

class _FollowTopicsSheetState extends State<FollowTopicsSheet> {
  late Set<String> _selectedTopics;

  @override
  void initState() {
    super.initState();
    _selectedTopics = Set<String>.from(widget.preferences.selectedCategories);
  }

  void _toggleTopic(String categoryName) {
    setState(() {
      if (_selectedTopics.contains(categoryName)) {
        _selectedTopics.remove(categoryName);
      } else {
        _selectedTopics.add(categoryName);
      }
    });
  }

  Future<void> _saveAndClose() async {
    final updated = widget.preferences.copyWith(
      selectedCategories: _selectedTopics.toList(),
      updatedAt: DateTime.now(),
    );
    await widget.cacheService.cachePreferences(updated);
    widget.onUpdated(updated);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF15151B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A33) : const Color(0xFFE3DFD5),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FOLLOW TOPICS',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                          color: isDark ? AppTheme.cyberCyan : theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Select sectors to personalize your daily wire feed',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_selectedTopics.length == AppCategories.all.length) {
                        _selectedTopics.clear();
                      } else {
                        _selectedTopics = AppCategories.all.map((c) => c.name).toSet();
                      }
                    });
                  },
                  child: Text(
                    _selectedTopics.length == AppCategories.all.length ? 'DESELECT ALL' : 'SELECT ALL',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),

          Divider(
            height: 1,
            thickness: 0.8,
            color: isDark ? const Color(0xFF1E2433) : const Color(0xFFE3DFD5),
          ),

          // Topics grid / list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: AppCategories.all.length,
              separatorBuilder: (context, index) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final category = AppCategories.all[index];
                final isSelected = _selectedTopics.contains(category.name);
                final catAccent = AppTheme.getCategoryAccent(category.name, isDark: isDark);

                return InkWell(
                  onTap: () => _toggleTopic(category.name),
                  borderRadius: BorderRadius.circular(6),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? catAccent.withValues(alpha: isDark ? 0.15 : 0.08)
                          : (isDark ? const Color(0xFF1E1E26) : const Color(0xFFF7F5F0)),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected
                            ? catAccent.withValues(alpha: 0.6)
                            : (isDark ? const Color(0xFF2A2A33) : const Color(0xFFE3DFD5)),
                        width: isSelected ? 1.2 : 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: catAccent.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(category.icon, size: 16, color: catAccent),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category.name,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                category.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          size: 20,
                          color: isSelected
                              ? catAccent
                              : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Save button footer
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _saveAndClose,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: Text(
                'APPLY TOPIC PREFERENCES (${_selectedTopics.length} SELECTED)',
                style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
