import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:techdaily/services/v2/sample_stories.dart';
import 'package:techdaily/services/v2/story_translator.dart';

class _FakeApi implements TranslationApi {
  final List<Map<String, TrFields>> batches = [];
  @override
  Future<Map<String, TrFields>> translate(String lang, Map<String, TrFields> items) async {
    batches.add(items);
    return {
      for (final e in items.entries)
        e.key: {for (final f in e.value.entries) f.key: f.value is List ? [for (final x in f.value as List) '$lang:$x'] : '$lang:${f.value}'},
    };
  }
}

void main() {
  final stories = sampleStoryFeed().stories;

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('cards are translated in batches, cached, and reused (no second call)', () async {
    final api = _FakeApi();
    final t = StoryTranslator(api: api, cache: TranslationCache(), batchSize: 3, debounce: const Duration(milliseconds: 1));
    t.setLanguage('te');
    for (final s in stories.take(5)) {
      expect(t.card(s).headline, s.headline); // English while pending
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(api.batches.length, 2); // 5 cards, batch size 3
    expect(api.batches.first.length, 3);
    final s0 = t.card(stories.first);
    expect(s0.headline, 'te:${stories.first.headline}');
    expect(s0.original.headline, stories.first.headline);
    for (final s in stories.take(5)) {
      t.card(s);
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(api.batches.length, 2);
    t.setLanguage('en');
    expect(t.card(stories.first).headline, stories.first.headline);
  });

  test('full story translation keeps lists, scam fields and the original for saving', () async {
    final api = _FakeApi();
    final t = StoryTranslator(api: api, cache: TranslationCache(), debounce: Duration.zero);
    t.setLanguage('hi');
    final scam = stories.firstWhere((s) => s.isScam);
    expect(t.fullStatus(scam), TrStatus.pending);
    t.full(scam);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final tr = t.full(scam);
    expect(t.fullStatus(scam), TrStatus.done);
    expect(tr.headline, startsWith('hi:'));
    expect(tr.scam!.warningSigns.length, scam.scam!.warningSigns.length);
    expect(tr.scam!.warningSigns.first, startsWith('hi:'));
    expect(tr.display.whatToDo.every((x) => x.startsWith('hi:')), isTrue);
    expect(tr.original, same(scam));
    expect(t.card(scam).headline, startsWith('hi:')); // cards reuse the full translation
  });

  test('failures leave English and mark the story as "Showing English"', () async {
    final client = MockClient((req) async => http.Response('busy', 502));
    final t = StoryTranslator(api: WorkerTranslationApi(client: client, endpoint: 'https://w.example'), cache: TranslationCache(), debounce: Duration.zero);
    t.setLanguage('te');
    final s = stories.first;
    t.full(s);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(t.fullStatus(s), TrStatus.failed);
    expect(t.full(s).headline, s.headline);
    expect(t.hasRecentFailure, isTrue);
    t.retry(s);
    expect(t.fullStatus(s), TrStatus.pending);
  });

  test('Worker API sends {lang, items:[{id, fields}]} and parses the reply', () async {
    late Map<String, dynamic> body;
    final client = MockClient((req) async {
      expect(req.url.path, '/translate');
      body = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response.bytes(utf8.encode(jsonEncode({'lang': 'te', 'items': [{'id': 'k1', 'fields': {'headline': 'తెలుగు', 'whatToDo': ['ఒకటి']}}]})), 200);
    });
    final out = await WorkerTranslationApi(client: client, endpoint: 'https://w.example').translate('te', {
      'k1': {'headline': 'English', 'whatToDo': ['one']},
    });
    expect(body['lang'], 'te');
    expect((body['items'] as List).first['id'], 'k1');
    expect(out['k1']!['headline'], 'తెలుగు');
    expect(out['k1']!['whatToDo'], ['ఒకటి']);
  });

  test('cache is size-capped in memory and on disk, and survives a reload', () async {
    final c = TranslationCache(maxEntries: 3, maxBytes: 120);
    for (var i = 0; i < 5; i++) {
      c.put('k$i', {'headline': 'x' * 30});
    }
    expect(c.length, 3);
    expect(c.debugEntries.keys, ['k2', 'k3', 'k4']);
    c.get('k2'); // touch -> most recent
    await c.save();
    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString(TranslationCache.prefsKey)!) as Map;
    expect(saved.length, lessThan(3)); // byte cap keeps only the newest that fit
    expect(saved.keys, contains('k2'));
    final again = TranslationCache();
    await again.load();
    expect(again.get('k2'), isNotNull);
    c.dispose();
  });

  test('content hash changes when the story text changes', () {
    expect(contentHash('a'), isNot(contentHash('b')));
    expect(contentHash('same'), contentHash('same'));
    unawaited(Future<void>.value());
  });
}
