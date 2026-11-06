import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import '../../models/story.dart';

/// Translated story text: field name -> `String` or `List<String>`.
typedef TrFields = Map<String, Object>;

/// Network side of translation: the Worker's `POST /translate`.
abstract class TranslationApi {
  /// Returns translated fields by item id (items it could not translate are left out).
  Future<Map<String, TrFields>> translate(String lang, Map<String, TrFields> items);
}

class WorkerTranslationApi implements TranslationApi {
  final http.Client? client;
  final String endpoint;
  final Duration timeout;
  WorkerTranslationApi({this.client, String? endpoint, this.timeout = const Duration(seconds: 90)}) : endpoint = endpoint ?? kAskEndpoint;

  @override
  Future<Map<String, TrFields>> translate(String lang, Map<String, TrFields> items) async {
    if (endpoint.isEmpty) throw StateError('no endpoint');
    final c = client ?? http.Client();
    try {
      final res = await c
          .post(
            Uri.parse('${endpoint.replaceAll(RegExp(r'/+(ask)?$'), '')}/translate'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'lang': lang,
              'items': [for (final e in items.entries) {'id': e.key, 'fields': e.value}],
            }),
          )
          .timeout(timeout);
      if (res.statusCode != 200) throw http.ClientException('translate ${res.statusCode}');
      final m = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final out = <String, TrFields>{};
      for (final it in (m['items'] as List? ?? const [])) {
        if (it is! Map) continue;
        final f = _fields(it['fields']);
        if (f != null) out['${it['id']}'] = f;
      }
      return out;
    } finally {
      if (client == null) c.close();
    }
  }
}

TrFields? _fields(dynamic v) {
  if (v is! Map) return null;
  final out = <String, Object>{};
  v.forEach((k, x) {
    if (x is String) out['$k'] = x;
    if (x is List) out['$k'] = x.map((e) => '$e').toList();
  });
  return out.isEmpty ? null : out;
}

/// Small stable hash (FNV-1a, 32-bit) so an edited story is translated again.
String contentHash(String s) {
  var h = 0x811c9dc5;
  for (final c in utf8.encode(s)) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h.toRadixString(16).padLeft(8, '0');
}

/// Translation cache: memory (LRU) + SharedPreferences (localStorage on web)
/// with a size cap so it never grows without bound.
class TranslationCache {
  static const prefsKey = 'techdaily_tr_cache_v1';
  final int maxEntries;
  final int maxBytes;
  final LinkedHashMap<String, TrFields> _mem = LinkedHashMap();
  Timer? _saveTimer;
  bool _loaded = false;

  TranslationCache({this.maxEntries = 400, this.maxBytes = 900000});

  int get length => _mem.length;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefsKey);
      if (raw == null) return;
      final m = jsonDecode(raw);
      if (m is! Map) return;
      for (final e in m.entries) {
        final f = _fields(e.value);
        if (f != null && !_mem.containsKey(e.key)) _mem['${e.key}'] = f;
      }
      _trim();
    } catch (_) {}
  }

  TrFields? get(String key) {
    final v = _mem.remove(key);
    if (v != null) _mem[key] = v; // most recently used last
    return v;
  }

  void put(String key, TrFields fields) {
    _mem.remove(key);
    _mem[key] = fields;
    _trim();
    _saveTimer?.cancel();
    // Batches arrive in bursts; write the (up to ~900 KB) cache once they settle.
    _saveTimer = Timer(const Duration(seconds: 3), save);
  }

  void _trim() {
    while (_mem.length > maxEntries) {
      _mem.remove(_mem.keys.first);
    }
  }

  /// Writes the newest entries that fit in [maxBytes].
  Future<void> save() async {
    _saveTimer?.cancel();
    try {
      final entries = _mem.entries.toList().reversed; // newest first
      final kept = <String, TrFields>{};
      var size = 2;
      for (final e in entries) {
        final n = jsonEncode(e.value).length + e.key.length + 6;
        if (size + n > maxBytes) break;
        size += n;
        kept[e.key] = e.value;
      }
      final ordered = Map.fromEntries(kept.entries.toList().reversed);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, jsonEncode(ordered));
    } catch (_) {}
  }

  @visibleForTesting
  Map<String, TrFields> get debugEntries => Map.of(_mem);

  void dispose() => _saveTimer?.cancel();
}

enum TrStatus { english, pending, done, failed }

/// Translates story text into Telugu / Hindi through the Worker, in batches:
/// cards ask for their headline + one-liner as they are built (only the ones
/// on screen), and the story page asks for the whole story. Results are cached
/// on the device; failures show English.
class StoryTranslator extends ChangeNotifier {
  final TranslationApi api;
  final TranslationCache cache;
  final int batchSize;
  final Duration debounce;
  String _lang = 'en';

  StoryTranslator({TranslationApi? api, TranslationCache? cache, this.batchSize = 10, this.debounce = const Duration(milliseconds: 350)})
      : api = api ?? WorkerTranslationApi(),
        cache = cache ?? TranslationCache();

  String get lang => _lang;

  final Map<String, TrFields> _queued = {}; // key -> source fields (cards)
  final Set<String> _inFlight = {};
  final Map<String, DateTime> _failedAt = {};
  Timer? _timer;
  int _failures = 0;

  /// Recent failures (drives the "Showing English" note on home).
  bool get hasRecentFailure => _failedAt.values.any((t) => DateTime.now().difference(t) < const Duration(minutes: 2));

  Future<void> init() => cache.load();

  void setLanguage(String lang) {
    if (lang == _lang) return;
    _lang = lang;
    _queued.clear();
    _failedAt.clear();
    notifyListeners();
  }

  /// What a feed card shows: the headline and its one-liner (whatItMeans).
  static TrFields cardFields(Story story) => _cardFields(story.original);

  static TrFields _cardFields(Story s) => {
        'headline': s.headline,
        if (!s.isFallback && s.whatItMeans.trim().isNotEmpty) 'whatItMeans': s.whatItMeans.trim(),
      };

  static TrFields fullFields(Story story) {
    final s = story.original;
    final d = s.display;
    final f = <String, Object>{'headline': s.headline};
    void str(String k, String v) {
      if (v.trim().isNotEmpty) f[k] = v.trim();
    }

    void list(String k, List<String> v) {
      final l = v.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (l.isNotEmpty) f[k] = l;
    }

    str('tldr', d.tldr);
    str('whatHappened', d.whatHappened);
    str('affectsWho', d.affectsWho);
    list('whatToDo', d.whatToDo);
    str('goodToKnow', d.goodToKnow);
    str('whatItMeans', d.whatItMeans);
    list('keyLabels', s.keyNumbers.map((k) => k.label).toList());
    list('faqQ', s.faq.map((x) => x.q).toList());
    list('faqA', s.faq.map((x) => x.a).toList());
    if (s.scam != null) {
      str('scamHow', s.scam!.howItWorks);
      list('scamSigns', s.scam!.warningSigns);
      list('scamIfTargeted', s.scam!.ifTargeted);
    }
    return f;
  }


  // Content hashes per story object: cards are built on every scroll, and
  // hashing the whole story text each time showed up in frame times.
  static final Expando<String> _fullHash = Expando('trFullHash');
  static final Expando<String> _cardHash = Expando('trCardHash');

  String _fullKey(Story s) => '$_lang|${s.id}|full|${_fullHash[s] ??= contentHash(jsonEncode(fullFields(s)))}';
  String _cardKey(Story s) => '$_lang|${s.id}|card|${_cardHash[s] ??= contentHash(jsonEncode(cardFields(s)))}';

  TrStatus _status(String key) {
    if (cache.get(key) != null) return TrStatus.done;
    final failed = _failedAt[key];
    if (failed != null && DateTime.now().difference(failed) < const Duration(minutes: 2)) return TrStatus.failed;
    return TrStatus.pending;
  }

  /// The story with its card text translated (or the original while pending).
  Story card(Story story) {
    final s = story.original;
    if (_lang == 'en') return s;
    final fullHit = cache.get(_fullKey(s));
    if (fullHit != null) return _translated(s, fullHit);
    final key = _cardKey(s);
    final hit = cache.get(key);
    if (hit != null) return _translated(s, hit);
    if (_status(key) == TrStatus.pending && !_inFlight.contains(key) && !_queued.containsKey(key)) {
      _queued[key] = cardFields(s);
      _timer ??= Timer(debounce, _flush);
    }
    return s;
  }

  TrStatus cardStatus(Story story) {
    final s = story.original;
    if (_lang == 'en') return TrStatus.english;
    if (cache.get(_fullKey(s)) != null) return TrStatus.done;
    return _status(_cardKey(s));
  }

  /// The whole story translated (requests it once; the original while pending).
  Story full(Story story) {
    final s = story.original;
    if (_lang == 'en') return s;
    final key = _fullKey(s);
    final hit = cache.get(key);
    if (hit != null) return _translated(s, hit);
    if (_status(key) == TrStatus.pending && !_inFlight.contains(key)) unawaited(_send({key: fullFields(s)}));
    final c = cache.get(_cardKey(s));
    return c != null ? _translated(s, c) : s;
  }

  TrStatus fullStatus(Story story) => _lang == 'en' ? TrStatus.english : _status(_fullKey(story.original));

  // The same translated Story object is handed back while its fields are
  // unchanged, so widgets below can skip work (and image keys stay stable).
  final Map<String, (TrFields, Story)> _shown = {};
  Story _translated(Story s, TrFields f) {
    final k = '$_lang|${s.id}';
    final prev = _shown[k];
    if (prev != null && identical(prev.$1, f) && identical(prev.$2.original, s)) return prev.$2;
    final t = s.withTranslation(f);
    if (_shown.length > 600) _shown.clear();
    _shown[k] = (f, t);
    return t;
  }

  /// Forget a failure so the next build asks again (the "Try again" link).
  void retry(Story s) {
    _failedAt.removeWhere((k, _) => k.contains('|${s.id}|'));
    notifyListeners();
  }

  void _flush() {
    _timer = null;
    if (_queued.isEmpty) return;
    final keys = _queued.keys.toList();
    for (var i = 0; i < keys.length; i += batchSize) {
      final chunk = keys.sublist(i, i + batchSize > keys.length ? keys.length : i + batchSize);
      unawaited(_send({for (final k in chunk) k: _queued[k]!}));
    }
    _queued.clear();
  }

  Future<void> _send(Map<String, TrFields> byKey) async {
    final lang = _lang;
    _inFlight.addAll(byKey.keys);
    // The Worker's item id is the cache key (lang|story|kind|hash), unique per batch.
    try {
      final out = await api.translate(lang, byKey);
      for (final k in byKey.keys) {
        final f = out[k];
        if (f != null) {
          cache.put(k, f);
        } else {
          _failedAt[k] = DateTime.now();
        }
      }
      _failures = 0;
    } catch (_) {
      _failures++;
      for (final k in byKey.keys) {
        _failedAt[k] = DateTime.now();
      }
    } finally {
      _inFlight.removeAll(byKey.keys);
      if (lang == _lang) notifyListeners();
    }
  }

  @visibleForTesting
  int get debugFailures => _failures;

  @override
  void dispose() {
    _timer?.cancel();
    cache.dispose();
    super.dispose();
  }
}
