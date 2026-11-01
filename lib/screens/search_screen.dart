import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/constants/categories.dart';
import '../core/theme/app_theme.dart';
import '../models/article.dart';
import '../repositories/article_repository.dart';
import '../repositories/auth_repository.dart';
import '../services/search_service.dart';
import '../widgets/story_widgets.dart';
import 'article_screen.dart';

/// Search with live filtering. The controller and focus node live in State
/// (never recreated during build) and the field has no gesture/semantics
/// wrappers, so it accepts typing on web and mobile.
class SearchScreen extends StatefulWidget {
  final ArticleRepository repository;
  final AuthRepository? authRepository;
  final ISearchService? searchService;

  const SearchScreen({
    super.key,
    required this.repository,
    this.authRepository,
    this.searchService,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final ISearchService _searchService;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode(debugLabel: 'search-field');
  Timer? _debounce;
  int _requestId = 0;

  List<Article> _results = [];
  bool _hasSearched = false;
  bool _isLoading = false;
  bool _failed = false;
  String _category = '';
  String _source = '';
  String _period = 'all';

  static const List<String> _sources = [
    'AWS',
    'Google',
    'GitHub',
    'Apple',
    'Microsoft',
    'NVIDIA',
    'NASA',
    'CISA',
  ];

  static const Map<String, String> _periods = {
    'all': 'Any time',
    '24h': '24 hours',
    '7d': '7 days',
    '30d': '30 days',
  };

  @override
  void initState() {
    super.initState();
    _searchService = widget.searchService ?? ArticleSearchService(widget.repository);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {}); // update clear button immediately
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _run);
  }

  bool get _hasQuery =>
      _controller.text.trim().isNotEmpty || _category.isNotEmpty || _source.isNotEmpty || _period != 'all';

  Future<void> _run() async {
    final id = ++_requestId;
    if (!_hasQuery) {
      setState(() {
        _results = [];
        _hasSearched = false;
        _isLoading = false;
        _failed = false;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _failed = false;
    });

    try {
      var results = await _searchService.search(SearchParams(
        keywords: _controller.text.trim(),
        category: _category.isEmpty ? null : _category,
        source: _source.isEmpty ? null : _source,
        limit: 60,
      ));
      // Period-only filter: search service needs a keyword/category/source.
      if (results.isEmpty && _controller.text.trim().isEmpty && _category.isEmpty && _source.isEmpty) {
        results = await widget.repository.getArticles();
      }
      if (_period != 'all') {
        final window = switch (_period) {
          '24h' => const Duration(hours: 24),
          '7d' => const Duration(days: 7),
          _ => const Duration(days: 30),
        };
        final now = DateTime.now();
        results = results.where((a) => now.difference(a.publishedAt) <= window).toList();
      }
      if (!mounted || id != _requestId) return;
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Search failed: $e');
      if (!mounted || id != _requestId) return;
      setState(() {
        _results = [];
        _isLoading = false;
        _failed = true;
      });
    }
  }

  void _clearAll() {
    _controller.clear();
    setState(() {
      _category = '';
      _source = '';
      _period = 'all';
    });
    _run();
  }

  void _open(Article a) {
    if (AppScope.maybeOf(context) != null) {
      openArticle(context, a);
    } else {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ArticleScreen(article: a, repository: widget.repository, authRepository: widget.authRepository),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 12, 8),
                  child: Row(children: [
                    Text('Search', style: AppTheme.display(28, color: theme.colorScheme.onSurface)),
                    const Spacer(),
                    if (_hasSearched)
                      TextButton(onPressed: _clearAll, child: const Text('Clear')),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    key: const ValueKey('search-field'),
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: _onChanged,
                    onSubmitted: (_) => _run(),
                    onTapOutside: (_) => _focusNode.unfocus(),
                    textInputAction: TextInputAction.search,
                    keyboardType: TextInputType.text,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      hintText: 'Search stories, topics or sources',
                      prefixIcon: Icon(Icons.search_rounded, color: muted),
                      suffixIcon: _controller.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _controller.clear();
                                _onChanged('');
                              },
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    children: [
                      _MenuChip(
                        label: _periods[_period]!,
                        icon: Icons.schedule_rounded,
                        active: _period != 'all',
                        items: _periods,
                        onSelected: (v) {
                          setState(() => _period = v);
                          _run();
                        },
                      ),
                      const SizedBox(width: 8),
                      _MenuChip(
                        label: _source.isEmpty ? 'Any source' : _source,
                        icon: Icons.verified_outlined,
                        active: _source.isNotEmpty,
                        items: {'': 'Any source', for (final s in _sources) s: s},
                        onSelected: (v) {
                          setState(() => _source = v);
                          _run();
                        },
                      ),
                      const SizedBox(width: 8),
                      ...AppCategories.all.map((c) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(c.name),
                              showCheckmark: false,
                              selected: _category == c.name,
                              onSelected: (_) {
                                setState(() => _category = _category == c.name ? '' : c.name);
                                _run();
                              },
                            ),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(child: _buildResults(theme)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResults(ThemeData theme) {
    if (_isLoading && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_hasSearched) {
      return const FriendlyState(
        icon: Icons.travel_explore_rounded,
        title: 'Find any story',
        message: 'Type a topic like “AI”, “chips” or “Apple”, or pick a category.',
      );
    }
    if (_failed) {
      return FriendlyState(
        icon: Icons.wifi_off_rounded,
        title: 'Search isn’t available',
        message: 'Check your connection and try again.',
        actionLabel: 'Try again',
        onAction: _run,
      );
    }
    if (_results.isEmpty) {
      return const FriendlyState(
        icon: Icons.search_off_rounded,
        title: 'No matches',
        message: 'Try a shorter word or clear the filters.',
      );
    }
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _results.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${_results.length} ${_results.length == 1 ? 'story' : 'stories'} found',
              style: AppTheme.numeric(13, color: AppTheme.mutedOf(context)),
            ),
          );
        }
        final a = _results[i - 1];
        return CompactStoryTile(article: a, onTap: () => _open(a));
      },
    );
  }
}

class _MenuChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Map<String, String> items;
  final ValueChanged<String> onSelected;

  const _MenuChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: label,
      onSelected: onSelected,
      itemBuilder: (_) => items.entries
          .map((e) => PopupMenuItem<String>(value: e.key, child: Text(e.value)))
          .toList(),
      child: Chip(
        avatar: Icon(icon, size: 16, color: active ? AppTheme.accentOf(context) : null),
        label: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label),
          const Icon(Icons.arrow_drop_down_rounded, size: 18),
        ]),
        side: BorderSide(color: active ? AppTheme.accentOf(context) : AppTheme.borderOf(context)),
      ),
    );
  }
}
