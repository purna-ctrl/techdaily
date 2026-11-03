import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/story.dart';

/// "Scam or Not?" — a daily 3-message mini-game. Each message looks like a
/// real SMS / WhatsApp text. Scam messages are built from recent scam stories
/// (their warning signs become the explanation) or from hand-written Indian
/// examples; safe messages are real-looking genuine alerts.
class ScamMessage {
  final String id;
  final String channel; // 'SMS' | 'WhatsApp'
  final String sender;
  final String body;
  final bool isScam;
  final String verdict;
  final List<String> signs;
  final String? storySlug;
  final String? storyHeadline;

  const ScamMessage({
    required this.id,
    required this.channel,
    required this.sender,
    required this.body,
    required this.isScam,
    required this.verdict,
    required this.signs,
    this.storySlug,
    this.storyHeadline,
  });
}

/// Hand-written examples of common Indian scams (fallback + variety).
const List<ScamMessage> kFallbackScams = [
  ScamMessage(
    id: 'f-electricity',
    channel: 'SMS',
    sender: '+91 89xxx 41207',
    body: 'Dear Consumer, your electricity power will be disconnected tonight at 9.30 PM because your previous month bill was not updated. Please immediately contact our electricity officer 98xxx xx310. Thank you.',
    isScam: true,
    verdict: 'Scam. Power companies never threaten same-night cuts from a mobile number.',
    signs: ['Sent from a personal mobile number', 'Threat of a cut “tonight”', 'Asks you to call an “officer” instead of the official helpline'],
  ),
  ScamMessage(
    id: 'f-kyc',
    channel: 'SMS',
    sender: 'VM-SBlNB',
    body: 'Dear customer your SBI YONO account will be blocked today. Please update your PAN/KYC immediately click here http://sbi-kyc-update.in/verify',
    isScam: true,
    verdict: 'Scam. Banks don’t block accounts over SMS links, and the sender is a look-alike ID.',
    signs: ['Look-alike sender name (SBlNB with an “l”)', 'Link to a non-bank website', '“Blocked today” pressure'],
  ),
  ScamMessage(
    id: 'f-parcel',
    channel: 'SMS',
    sender: 'IndiaPost',
    body: 'IndiaPost: Your package is stuck at the warehouse due to an incomplete address. Pay ₹25 customs fee within 24 hrs to redeliver: https://indiapost-redelivery.top',
    isScam: true,
    verdict: 'Scam. A tiny “fee” link is how they steal card and UPI details.',
    signs: ['Parcel you may not have ordered', 'Small fee to “release” it', 'Strange web address (.top)'],
  ),
  ScamMessage(
    id: 'f-job',
    channel: 'WhatsApp',
    sender: '+44 7700 900123',
    body: 'Hi! I am Priya from an HR agency. Part-time job: like YouTube videos and earn ₹3,000–₹8,000 per day from home. Interested? Reply YES and I will add you to our Telegram task group 😊',
    isScam: true,
    verdict: 'Scam. “Like videos and earn” tasks end with you paying to “unlock” bigger tasks.',
    signs: ['Unknown foreign number', 'Huge pay for easy work', 'Moves you to a Telegram group'],
  ),
  ScamMessage(
    id: 'f-collect',
    channel: 'WhatsApp',
    sender: 'Rahul (OLX buyer)',
    body: 'Sir I am sending ₹12,500 for your sofa. I have sent a request on PhonePe, please accept and enter your UPI PIN to receive the money. Army person, urgent transfer 🙏',
    isScam: true,
    verdict: 'Scam. You NEVER enter your UPI PIN to receive money — a “collect request” takes money out.',
    signs: ['Asks you to enter UPI PIN to “receive”', 'Urgency and a sympathy story', 'Buyer pays without seeing the item'],
  ),
  ScamMessage(
    id: 'f-arrest',
    channel: 'WhatsApp',
    sender: 'Mumbai Cyber Police',
    body: 'This is CBI officer. A parcel in your name with illegal drugs is seized. You are under DIGITAL ARREST. Join video call now and do not tell family. Non-cooperation will lead to arrest warrant.',
    isScam: true,
    verdict: 'Scam. There is no such thing as a “digital arrest”. Police never ask you to stay on a video call or pay.',
    signs: ['“Digital arrest” threat', 'Told to keep it secret from family', 'Video call demand from “police”'],
  ),
  ScamMessage(
    id: 'f-lottery',
    channel: 'WhatsApp',
    sender: 'KBC Lucky Draw',
    body: 'Congratulations!! Your number has won ₹25,00,000 in the KBC Jio lucky draw. To claim, pay ₹8,500 processing fee and send your bank details to Rana Pratap Singh +92 3xx xxxxxxx.',
    isScam: true,
    verdict: 'Scam. You can’t win a draw you never entered, and real prizes never need a fee.',
    signs: ['Prize you never entered', 'Fee to release winnings', 'Foreign (+92) number'],
  ),
  ScamMessage(
    id: 'f-loan',
    channel: 'SMS',
    sender: 'AD-QKLOAN',
    body: 'Pre-approved instant loan ₹50,000 in 5 mins! No CIBIL check. Download app now: bit.ly/quickcash-loan-apk and allow contacts access to get money.',
    isScam: true,
    verdict: 'Scam. Illegal loan apps grab your contacts and photos to harass and blackmail you.',
    signs: ['“No CIBIL check” instant money', 'App download from a short link', 'Asks for contacts access'],
  ),
  ScamMessage(
    id: 'f-refund',
    channel: 'SMS',
    sender: 'JM-ITDEPT',
    body: 'Income Tax Dept: You are eligible for a tax refund of ₹15,490. Verify your bank account to receive it: https://incometax-refund-gov.co/claim',
    isScam: true,
    verdict: 'Scam. Refunds go straight to your linked bank account; the real site is incometax.gov.in.',
    signs: ['Refund you didn’t expect', 'Link is not a .gov.in site', 'Asks you to “verify” bank details'],
  ),
  ScamMessage(
    id: 'f-wedding-apk',
    channel: 'WhatsApp',
    sender: '+91 70xxx 22518',
    body: 'Hello ji 🙏 you are invited to my daughter’s wedding. Please open the invitation card: Wedding_Invitation.apk',
    isScam: true,
    verdict: 'Scam. An invitation is a picture or PDF, never an .apk app — that file can take over your phone.',
    signs: ['Unknown number', 'Invitation sent as an .apk file', 'Friendly message to lower your guard'],
  ),
];

/// Genuine-looking alerts (the right answer is “Safe”).
const List<ScamMessage> kSafeMessages = [
  ScamMessage(
    id: 's-otp',
    channel: 'SMS',
    sender: 'AX-HDFCBK',
    body: '123456 is your OTP for a transaction of INR 499.00 at AMAZON on HDFC Bank card xx4421. Valid for 5 mins. Do not share this OTP with anyone. -HDFC Bank',
    isScam: false,
    verdict: 'Safe — IF you are making this ₹499 purchase yourself right now. It tells you not to share the OTP and asks you to do nothing.',
    signs: ['Official sender ID', 'Matches a payment you started', 'Says “Do not share”'],
  ),
  ScamMessage(
    id: 's-debit',
    channel: 'SMS',
    sender: 'VM-ICICIT',
    body: 'Rs 250.00 debited from A/c XX7710 on 01-Nov to VPA chaiwala@okaxis (UPI Ref 4302xxxx). Not you? Call 18002662 to block UPI. -ICICI Bank',
    isScam: false,
    verdict: 'Safe. A normal debit alert: no link, and the helpline is the bank’s official number.',
    signs: ['No link to click', 'Official toll-free number', 'Details match your payment'],
  ),
  ScamMessage(
    id: 's-delivery',
    channel: 'SMS',
    sender: 'JD-AMAZON',
    body: 'Delivered: Your package with boAt Airdopes was delivered to your front door. Track and rate at amazon.in/your-orders',
    isScam: false,
    verdict: 'Safe. It asks for nothing and points to the official site you already use.',
    signs: ['Matches something you ordered', 'Official amazon.in address', 'No payment or urgency'],
  ),
  ScamMessage(
    id: 's-aadhaar',
    channel: 'SMS',
    sender: 'AD-UIDAI',
    body: '458211 is the OTP to update your mobile number in Aadhaar. Valid for 10 minutes. Do not share it with anyone. -UIDAI',
    isScam: false,
    verdict: 'Safe — only if YOU just started an Aadhaar update. If you didn’t, ignore it and share the code with nobody.',
    signs: ['Official UIDAI sender', 'You started the request', 'Warns not to share'],
  ),
  ScamMessage(
    id: 's-bill',
    channel: 'SMS',
    sender: 'VK-BESCOM',
    body: 'Dear Consumer, bill of Rs 1,184 for A/c 70xxxx for Oct-26 is generated. Due date 15-Nov-26. Pay via BESCOM Mitra app or bescom.karnataka.gov.in',
    isScam: false,
    verdict: 'Safe. A normal bill reminder: official sender, a due date weeks away, and the official website.',
    signs: ['Official sender ID', 'Real due date, no threat', 'Official .gov.in site'],
  ),
];

/// Builds a realistic scam text from a scam story by spotting its trick.
ScamMessage? scamMessageFromStory(Story s) {
  final scam = s.scam;
  if (scam == null || scam.warningSigns.isEmpty) return null;
  final hay = [s.headline, scam.howItWorks, ...scam.warningSigns].join(' ').toLowerCase();
  bool has(List<String> w) => w.any(hay.contains);
  String? body;
  var channel = 'SMS';
  var sender = '+91 9xxxx x' '${(s.id.hashCode.abs() % 9000 + 1000)}';
  if (has(['parcel', 'courier', 'customs', 'fedex', 'india post', 'delivery'])) {
    body = 'Your parcel is on hold at our hub due to an address problem. Pay a ₹49 redelivery fee in 12 hours or it will be returned: https://track-redeliver.in/pay';
    sender = 'DelhiveryCare';
  } else if (has(['kyc', 'pan card', 'pan update', 'account will be blocked', 'account blocked', 'netbanking'])) {
    body = 'Dear customer, your bank account will be blocked today. Update your PAN/KYC now: http://kyc-update-bank.in/verify';
    sender = 'VM-BANKKYC';
  } else if (has(['electricity', 'power bill', 'power cut', 'disconnect'])) {
    body = 'Dear Consumer, your electricity connection will be cut tonight at 9.30 PM as last bill is not updated. Call officer 98xxx xx310 immediately.';
  } else if (has(['digital arrest', 'cbi', 'narcotics', 'police', 'customs officer', 'arrest'])) {
    channel = 'WhatsApp';
    sender = 'Cyber Crime Branch';
    body = 'A parcel in your name has illegal items. You are under digital arrest. Stay on this video call and do not inform anyone, or a warrant will be issued.';
  } else if (has(['job', 'part-time', 'part time', 'task', 'work from home', 'like videos', 'review'])) {
    channel = 'WhatsApp';
    sender = '+1 (415) 555-0142';
    body = 'Hi! Simple part-time job: rate hotels and like videos, earn ₹5,000 a day from home. Reply YES to join our task group 😊';
  } else if (has(['collect request', 'upi pin', 'qr code', 'receive money', 'scan'])) {
    channel = 'WhatsApp';
    sender = 'Buyer (OLX)';
    body = 'Sir I sent the payment request on UPI. Please accept and enter your PIN to receive ₹8,000 for the item. Urgent 🙏';
  } else if (has(['loan', 'instant credit', 'loan app'])) {
    sender = 'AD-LOANNW';
    body = 'Instant loan ₹50,000 approved! No documents. Install our app from bit.ly/quick-loan-app and allow contacts to get money in 5 mins.';
  } else if (has(['apk', 'malware', 'fake app', 'install', 'android app', 'remote access', 'screen sharing'])) {
    channel = 'WhatsApp';
    body = 'Your bank app needs an urgent security update. Install the new version from this file: BankUpdate.apk';
  } else if (has(['investment', 'trading', 'stock tips', 'ipo', 'crypto', 'returns'])) {
    channel = 'WhatsApp';
    sender = 'VIP Stock Club';
    body = 'Join our VIP stock group: guaranteed 30% weekly returns on IPO allotments. Only 5 seats left today. Pay ₹10,000 to start 📈';
  } else if (has(['otp', 'sim', 'password', 'verification code'])) {
    sender = '+91 70xxx 19022';
    body = 'Hello, I am calling from your bank. Your card will be blocked. Please tell me the OTP you just received to stop the block.';
  } else if (has(['refund', 'tax', 'cashback', 'reward points'])) {
    sender = 'VK-REWARD';
    body = 'Your reward points worth ₹7,450 expire today! Redeem now: https://redeem-points-now.in and enter your card details.';
  } else if (has(['lottery', 'prize', 'winner', 'lucky draw'])) {
    channel = 'WhatsApp';
    sender = 'KBC Lucky Draw';
    body = 'Congratulations! You won ₹25 lakh in the lucky draw. Pay ₹8,500 processing fee to claim your prize.';
  }
  if (body == null) return null;
  return ScamMessage(
    id: 'story-${s.id}',
    channel: channel,
    sender: sender,
    body: body,
    isScam: true,
    verdict: 'Scam. This trick is in the news right now.',
    signs: scam.warningSigns.take(3).toList(),
    storySlug: s.slug,
    storyHeadline: s.headline,
  );
}

String istDateKey(DateTime now) {
  final t = now.toUtc().add(const Duration(hours: 5, minutes: 30));
  return '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}

/// Today's 3 messages: a scam from the news (when there is one), a safe
/// message and a classic scam, in a date-seeded order.
List<ScamMessage> dailyScamRound(List<Story> stories, DateTime now, {int count = 3}) {
  final key = istDateKey(now);
  final seed = key.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) & 0x7fffffff);
  final rnd = math.Random(seed);
  final fromNews = <ScamMessage>[];
  for (final s in stories.where((s) => s.scam != null)) {
    final m = scamMessageFromStory(s);
    if (m != null && !fromNews.any((x) => x.body == m.body)) fromNews.add(m);
    if (fromNews.length >= 4) break;
  }
  final classics = [...kFallbackScams]..shuffle(rnd);
  final safes = [...kSafeMessages]..shuffle(rnd);
  final picked = <ScamMessage>[
    if (fromNews.isNotEmpty) fromNews[rnd.nextInt(math.min(2, fromNews.length))] else classics.removeLast(),
    safes.first,
    classics.first,
  ];
  if (count > 3) picked.addAll(classics.skip(1).take(count - 3));
  picked.shuffle(rnd);
  return picked.take(count).toList();
}

/// Answers, score and day streak (stored on the device).
class ScamGameController extends ChangeNotifier {
  static const _kState = 'scamgame.v1';
  final DateTime Function() clock;
  ScamGameController({DateTime Function()? clock}) : clock = clock ?? DateTime.now;

  String _day = '';
  final Map<String, bool> _answers = {}; // message id -> answered "scam"?
  int streak = 0;
  int best = 0;
  int correctTotal = 0;
  String _lastCompleted = '';
  bool loaded = false;

  Map<String, bool> get answers => Map.unmodifiable(_answers);

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kState);
      if (raw != null) {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        _day = (m['day'] ?? '') as String;
        streak = (m['streak'] ?? 0) as int;
        best = (m['best'] ?? 0) as int;
        correctTotal = (m['correct'] ?? 0) as int;
        _lastCompleted = (m['last'] ?? '') as String;
        final a = m['answers'];
        if (a is Map) _answers.addAll(a.map((k, v) => MapEntry(k.toString(), v == true)));
      }
    } catch (_) {}
    final today = istDateKey(clock());
    if (_day != today) {
      _day = today;
      _answers.clear();
    }
    // A missed day breaks the streak.
    if (_lastCompleted.isNotEmpty && _lastCompleted != today && _lastCompleted != istDateKey(clock().subtract(const Duration(days: 1)))) {
      streak = 0;
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
          _kState, jsonEncode({'day': _day, 'streak': streak, 'best': best, 'correct': correctTotal, 'last': _lastCompleted, 'answers': _answers}));
    } catch (_) {}
  }

  bool? answerFor(ScamMessage m) => _answers[m.id];

  bool isDone(List<ScamMessage> round) => round.every((m) => _answers.containsKey(m.id));

  int score(List<ScamMessage> round) => round.where((m) => _answers[m.id] == m.isScam).length;

  /// Records an answer; returns true when it was right.
  Future<bool> answer(ScamMessage m, {required bool saysScam, required List<ScamMessage> round}) async {
    if (_answers.containsKey(m.id)) return _answers[m.id] == m.isScam;
    _answers[m.id] = saysScam;
    final right = saysScam == m.isScam;
    if (right) correctTotal++;
    final today = istDateKey(clock());
    if (isDone(round) && _lastCompleted != today) {
      streak = _lastCompleted == istDateKey(clock().subtract(const Duration(days: 1))) ? streak + 1 : 1;
      best = math.max(best, streak);
      _lastCompleted = today;
    }
    notifyListeners();
    await _save();
    return right;
  }
}
