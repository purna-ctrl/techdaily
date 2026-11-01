import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/story_categories.dart';
import '../../core/stories_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../models/story.dart';
import '../../widgets/story_widgets.dart' show FriendlyState;
import '../../widgets/v2/story_parts.dart';

class StorySearchScreen extends StatefulWidget {
  final String? initialQuery;
  const StorySearchScreen({super.key, this.initialQuery});

  @override
  State<StorySearchScreen> createState() => _StorySearchScreenState();
}

class _StorySearchScreenState extends State<StorySearchScreen> {
  late final TextEditingController _c = TextEditingController(text: widget.initialQuery ?? '');
  Timer? _debounce;
  List<Story>? _results;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    if ((widget.initialQuery ?? '').isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _run(_c.text));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _run(q));
    setState(() {});
  }

  Future<void> _run(String q) async {
    final seq = ++_seq;
    if (q.trim().isEmpty) {
      setState(() => _results = null);
      return;
    }
    final r = await StoriesScope.of(context).stories.search(q);
    if (!mounted || seq != _seq) return;
    setState(() => _results = r);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = _results;
    return Scaffold(
      appBar: AppBar(title: Text('Search', style: AppTheme.display(20, color: theme.colorScheme.onSurface))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: TextField(
                key: const ValueKey('search-field'),
                controller: _c,
                onChanged: _onChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: _run,
                decoration: InputDecoration(
                  hintText: 'Search stories — e.g. UPI scam, iPhone, AI',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _c.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _c.clear();
                            _onChanged('');
                          },
                        ),
                ),
              ),
            ),
            Expanded(
              child: results == null
                  ? ListView(padding: const EdgeInsets.all(12), children: [
                      Text('Find any story', style: AppTheme.display(18, color: theme.colorScheme.onSurface)),
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final q in const ['UPI', 'scam', 'iPhone', 'ChatGPT', 'RBI', 'privacy'])
                          ActionChip(
                            label: Text(q),
                            onPressed: () {
                              _c.text = q;
                              _run(q);
                            },
                          ),
                      ]),
                      const SizedBox(height: 18),
                      Text('Browse topics', style: AppTheme.display(16, color: theme.colorScheme.onSurface)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final c in kStoryCategories)
                          ActionChip(
                            avatar: Icon(c.icon, size: 16),
                            label: Text(c.label),
                            onPressed: () {
                              _c.text = c.label;
                              _run(c.label);
                            },
                          ),
                      ]),
                    ])
                  : results.isEmpty
                      ? const FriendlyState(
                          icon: Icons.search_off_rounded,
                          title: 'No stories found',
                          message: 'Try a shorter word, or a company or app name.',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
                          itemCount: results.length + 1,
                          itemBuilder: (context, i) => i == 0
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Text('${results.length} ${results.length == 1 ? 'story' : 'stories'} found',
                                      style: TextStyle(color: AppTheme.mutedOf(context))),
                                )
                              : StoryCard(story: results[i - 1]),
                        ),
            ),
          ]),
        ),
      ),
    );
  }
}
