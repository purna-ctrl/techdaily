import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/fonts.dart';
import 'package:techdaily/screens/v2/scam_check_screen.dart';
import 'package:techdaily/services/v2/scam_check.dart';

void main() {
  const scorer = LocalScamScorer();

  group('LocalScamScorer (offline quick check)', () {
    ScamLevel level(String text, {String sender = ''}) => scorer.score(text, sender: sender).level;
    Set<String> ids(String text, {String sender = ''}) => scorer.score(text, sender: sender).signals.map((s) => s.id).toSet();

    test('fake bank KYC / PAN with a look-alike link is a scam', () {
      const sms = 'Dear customer your SBI account will be blocked today, update PAN at http://sbi-kyc.co/x';
      expect(level(sms), ScamLevel.scam);
      expect(ids(sms), containsAll(['kyc', 'threat', 'lookalike']));
    });

    test('ordinary delivery update looks safe', () {
      expect(level('Delivered: Your Amazon package was delivered to your doorstep. Track your orders in the Amazon app.', sender: 'AX-AMAZON'), ScamLevel.safe);
      expect(level('Your OTP for login is 482913. Do not share it with anyone. -HDFC Bank'), ScamLevel.safe);
      expect(level('Rs 499 debited from a/c XX1234 on 05-11 for Jio recharge. Not you? Call 18002586161'), ScamLevel.safe);
    });

    test('electricity disconnection, parcel/customs, task jobs and prizes are flagged', () {
      expect(level('Dear consumer your electricity power will be disconnected tonight at 9.30 pm because your previous month bill was not updated. Call 98xxxxxx10'), ScamLevel.scam);
      expect(level('India Post: your parcel is on hold due to incomplete address. Update within 24 hours at https://indiapost-track.top/in'), ScamLevel.scam);
      expect(level('Part time job! Earn ₹3000 per day by liking YouTube videos. Simple task, join Telegram now'), isNot(ScamLevel.safe));
      expect(level('Congratulations! You have won ₹25,00,000 in KBC lucky draw. Claim your prize now'), isNot(ScamLevel.safe));
    });

    test('OTP requests, UPI collect "to receive money", APKs and short links', () {
      expect(ids('Please share the OTP you just received to complete your refund'), contains('secret'));
      expect(level('To receive ₹5000 cashback, approve the request and enter your UPI PIN to receive money'), ScamLevel.scam);
      expect(level('Your reward points expire today. Install this app: http://bit.ly/sbi-reward.apk'), ScamLevel.scam);
      expect(ids('Check this http://bit.ly/3xYz now'), contains('shortLink'));
    });

    test('offline verdict text in Telugu / Hindi', () {
      final v = scorer.score('Your SBI account will be blocked today, update KYC at http://sbi-kyc.xyz').toVerdict('te');
      expect(v.offline, isTrue);
      expect(v.lang, 'te');
      expect(v.summary, contains('మోసా'));
      expect(v.actions.any((a) => a.contains('1930')), isTrue);
      final h = scorer.score('Your SBI account will be blocked today, update KYC at http://sbi-kyc.xyz').toVerdict('hi');
      expect(h.summary, contains('धोखाधड़ी'));
    });
  });

  group('ScamCheckService', () {
    test('uses the Worker verdict and sends lang + capped text', () async {
      late Map<String, dynamic> sent;
      final client = MockClient((req) async {
        expect(req.url.path, '/scam');
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response.bytes(utf8.encode(jsonEncode({'verdict': 'scam', 'summary': 'నకిలీ బ్యాంక్ మెసేజ్', 'reasons': ['a', 'b'], 'actions': ['c'], 'lang': 'te'})), 200);
      });
      final v = await ScamCheckService(client: client, endpoint: 'https://w.example').check('x' * 3000, sender: 'VM-SBI', lang: 'te');
      expect(v.level, ScamLevel.scam);
      expect(v.offline, isFalse);
      expect(v.summary, 'నకిలీ బ్యాంక్ మెసేజ్');
      expect((sent['text'] as String).length, kScamMaxChars);
      expect(sent['lang'], 'te');
      expect(sent['sender'], 'VM-SBI');
    });

    test('falls back to the on-device check when the Worker fails', () async {
      final client = MockClient((req) async => http.Response('{"error":"busy"}', 502));
      final v = await ScamCheckService(client: client, endpoint: 'https://w.example').check('Your SBI account will be blocked today, update PAN at http://sbi-kyc.co/x');
      expect(v.offline, isTrue);
      expect(v.level, ScamLevel.scam);
    });

    test('never says "safe" when the on-device rules see strong red flags', () async {
      final client = MockClient((req) async => http.Response(jsonEncode({'verdict': 'safe', 'summary': 'ok', 'reasons': ['fine'], 'actions': []}), 200));
      final v = await ScamCheckService(client: client, endpoint: 'https://w.example').check('Share the OTP now or your SBI account will be blocked today http://sbi-kyc.co/x');
      expect(v.level, ScamLevel.suspicious);
    });
  });

  group('Scam checker screen', () {
    setUpAll(loadAppFonts);

    testWidgets('check shows the verdict, reasons, report buttons and the disclaimer', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final client = MockClient((req) async => http.Response('nope', 500)); // offline path
      await tester.pumpWidget(MaterialApp(home: ScamCheckScreen(service: ScamCheckService(client: client, endpoint: 'https://w.example'))));
      await tester.tap(find.byKey(const ValueKey('scam-check')));
      await tester.pump();
      expect(find.text('Paste a message first.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('scam-example-0')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('scam-check')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('scam-result')), findsOneWidget);
      expect(find.text('Scam'), findsWidgets);
      expect(find.text('Quick check (offline)'), findsOneWidget);
      await tester.scrollUntilVisible(find.byKey(const ValueKey('scam-disclaimer')), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('This is a guide, not a guarantee.'), findsOneWidget);
      expect(find.text('Report on Chakshu'), findsOneWidget);
      expect(find.text('1930'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
