import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:techdaily/core/constants/trusted_sources.dart';
import 'package:techdaily/models/article.dart';
import 'package:techdaily/models/category.dart';

void main() {
  group('Article Model Tests', () {
    test('toMap and fromMap serialize and deserialize correctly', () {
      final now = DateTime.now();
      final article = Article(
        id: 'test-1',
        title: 'Quantum Processor Sets Coherence Record',
        summary: 'A new milestone in superconducting qubits.',
        simpleExplanation: 'Scientists kept quantum info alive twice as long.',
        category: 'Science',
        sourceName: 'Reuters',
        sourceUrl: 'https://example.com/reuters-article',
        imageUrl: 'https://example.com/image.jpg',
        publishedAt: now,
        keyPoints: const ['Key point 1', 'Key point 2'],
        isBreaking: true,
        whatHappened: 'Coherence exceeded 2 milliseconds.',
        whyItMatters: 'Enables practical error correction.',
        aiProcessed: true,
        aiModel: 'gemini-2.5-flash',
        aiPromptVersion: 'v1',
        aiProcessedAt: now,
      );

      final map = article.toMap();
      final restored = Article.fromMap(map);

      expect(restored.id, 'test-1');
      expect(restored.title, 'Quantum Processor Sets Coherence Record');
      expect(restored.summary, 'A new milestone in superconducting qubits.');
      expect(restored.simpleExplanation, 'Scientists kept quantum info alive twice as long.');
      expect(restored.category, 'Science');
      expect(restored.sourceName, 'Reuters');
      expect(restored.sourceUrl, 'https://example.com/reuters-article');
      expect(restored.imageUrl, 'https://example.com/image.jpg');
      expect(restored.isBreaking, true);
      expect(restored.keyPoints.length, 2);
      expect(restored.whatHappened, 'Coherence exceeded 2 milliseconds.');
      expect(restored.whyItMatters, 'Enables practical error correction.');
      expect(restored.aiProcessed, true);
      expect(restored.aiModel, 'gemini-2.5-flash');
      expect(restored.aiPromptVersion, 'v1');
      expect(restored.aiProcessedAt, isNotNull);
    });

    test('copyWith creates updated instance', () {
      final article = Article(
        id: '1',
        title: 'Original Title',
        summary: 'Summary',
        simpleExplanation: 'Simple',
        category: 'Software',
        sourceName: 'BBC',
        sourceUrl: 'https://example.com',
        publishedAt: DateTime(2026, 9, 16),
        keyPoints: const [],
      );

      final updated = article.copyWith(title: 'Updated Title', isBreaking: true);
      expect(updated.title, 'Updated Title');
      expect(updated.isBreaking, true);
      expect(updated.id, '1');
    });
  });

  group('Category Model & Trusted Sources Tests', () {
    test('Category toMap and fromMap work', () {
      const category = Category(
        id: 'hardware',
        name: 'Hardware',
        description: 'Chips and systems',
        icon: Icons.memory,
      );
      final map = category.toMap();
      expect(map['id'], 'hardware');
      expect(map['name'], 'Hardware');
    });

    test('TrustedSourcesConfig recognizes verified sources', () {
      expect(TrustedSourcesConfig.isTrusted('Reuters'), isTrue);
      expect(TrustedSourcesConfig.isTrusted('Google Official Blog'), isTrue);
      expect(TrustedSourcesConfig.isTrusted('Random Unverified Blog'), isFalse);
    });
  });
}
