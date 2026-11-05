import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';

/// "Is this a scam?" — the verdict for one pasted SMS / WhatsApp / email.
enum ScamLevel { scam, suspicious, safe }

ScamLevel scamLevelFrom(String? v) => switch (v) {
      'scam' => ScamLevel.scam,
      'safe' => ScamLevel.safe,
      _ => ScamLevel.suspicious,
    };

class ScamVerdict {
  final ScamLevel level;
  final String summary;
  final List<String> reasons;
  final List<String> actions;

  /// True when the on-device rules produced it (Worker unreachable).
  final bool offline;

  /// Language the text is in ('en' when a translation was not available).
  final String lang;

  const ScamVerdict({
    required this.level,
    required this.summary,
    required this.reasons,
    required this.actions,
    this.offline = false,
    this.lang = 'en',
  });

  factory ScamVerdict.fromJson(Map<String, dynamic> m) {
    List<String> list(dynamic v) => v is List ? v.whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty).take(4).toList() : const [];
    final summary = (m['summary'] ?? '').toString().trim();
    final reasons = list(m['reasons']);
    if (summary.isEmpty || reasons.isEmpty) throw const FormatException('incomplete verdict');
    return ScamVerdict(
      level: scamLevelFrom(m['verdict']?.toString()),
      summary: summary,
      reasons: reasons,
      actions: list(m['actions']),
      lang: (m['lang'] ?? 'en').toString(),
    );
  }
}

/// Longest message the checker sends (the Worker cuts at the same length).
const int kScamMaxChars = 2000;

/// Calls the Worker's `POST /scam`; falls back to [LocalScamScorer] when it
/// is unreachable, slow or busy. The message is never stored.
class ScamCheckService {
  final http.Client? client;
  final String endpoint;
  final Duration timeout;
  final LocalScamScorer scorer;

  ScamCheckService({this.client, String? endpoint, this.timeout = const Duration(seconds: 45), this.scorer = const LocalScamScorer()})
      : endpoint = endpoint ?? kAskEndpoint;

  Future<ScamVerdict> check(String text, {String sender = '', String lang = 'en'}) async {
    final body = text.trim();
    final local = scorer.score(body, sender: sender);
    if (endpoint.isEmpty) return local.toVerdict(lang);
    final c = client ?? http.Client();
    try {
      final res = await c
          .post(
            Uri.parse('${endpoint.replaceAll(RegExp(r'/+(ask)?$'), '')}/scam'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'text': body.length > kScamMaxChars ? body.substring(0, kScamMaxChars) : body,
              if (sender.trim().isNotEmpty) 'sender': sender.trim(),
              'lang': lang,
            }),
          )
          .timeout(timeout);
      if (res.statusCode != 200) return local.toVerdict(lang);
      final ai = ScamVerdict.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
      // Safety net: never show "Looks safe" when the on-device rules see strong red flags.
      if (ai.level == ScamLevel.safe && local.level == ScamLevel.scam) {
        return ScamVerdict(level: ScamLevel.suspicious, summary: ai.summary, reasons: [...local.reasons.take(2), ...ai.reasons].take(4).toList(), actions: ai.actions, lang: ai.lang);
      }
      return ai;
    } catch (_) {
      return local.toVerdict(lang);
    } finally {
      if (client == null) c.close();
    }
  }
}

/// One red flag found by the on-device rules.
class ScamSignal {
  final String id;
  final int weight;
  const ScamSignal(this.id, this.weight);
}

class LocalScamResult {
  final int score;
  final List<ScamSignal> signals;
  const LocalScamResult(this.score, this.signals);

  ScamLevel get level => score >= 6 ? ScamLevel.scam : (score >= 3 ? ScamLevel.suspicious : ScamLevel.safe);

  List<String> reasonsIn(String lang) => [for (final s in signals.take(4)) _reasonText(s.id, lang)];
  List<String> get reasons => reasonsIn('en');

  ScamVerdict toVerdict(String lang) {
    final l = lang == 'te' || lang == 'hi' ? lang : 'en';
    final level = this.level;
    final reasons = signals.isEmpty ? [_reasonText('none', l)] : reasonsIn(l);
    final actions = [
      for (final a in level == ScamLevel.safe ? const ['verify', 'noOtp'] : const ['noClick', 'noOtp', 'chakshu', 'lost']) _actionText(a, l),
    ];
    return ScamVerdict(level: level, summary: _summaryText(level, l), reasons: reasons, actions: actions, offline: true, lang: l);
  }
}

/// Rule-based scorer used when the AI checker can't be reached. Each rule adds
/// a weight; 6+ is a scam, 3-5 suspicious, below 3 looks safe. It only reads
/// the text on the device.
class LocalScamScorer {
  const LocalScamScorer();

  static final RegExp _url = RegExp(r'''((?:https?://|www\.)[^\s<>"']+|\b[a-z0-9][a-z0-9-]{1,40}\.(?:com|in|co|xyz|top|info|online|site|live|click|link|ly|me|net|org|shop|app|cc|tk|ml|ga|cf|gq|buzz|icu|vip|rest|cyou|sbs|io|gl)(?:/[^\s]*)?)''', caseSensitive: false);
  static const _shorteners = ['bit.ly', 'tinyurl', 'goo.gl', 't.ly', 'cutt.ly', 'is.gd', 'rb.gy', 'shorturl', 'tiny.cc', 'ow.ly', 'rebrand.ly', 'v.gd', 's.id', 'wa.link', 'shorte.st'];
  static const _oddTlds = ['.xyz', '.top', '.info', '.online', '.site', '.live', '.click', '.link', '.cc', '.tk', '.ml', '.ga', '.cf', '.gq', '.buzz', '.icu', '.vip', '.rest', '.cyou', '.sbs', '.shop', '.co/', '.co '];
  static const _brands = [
    'sbi', 'hdfc', 'icici', 'axis', 'kotak', 'pnb', 'canara', 'bank of baroda', 'yes bank', 'paytm', 'phonepe', 'gpay', 'google pay', 'bhim', 'npci',
    'rbi', 'income tax', 'uidai', 'aadhaar', 'epfo', 'trai', 'dot', 'india post', 'indiapost', 'customs', 'fedex', 'dhl', 'bluedart', 'blue dart',
    'electricity', 'bescom', 'tneb', 'msedcl', 'apspdcl', 'tsspdcl', 'airtel', 'jio', 'vodafone', ' vi ', 'bsnl', 'police', 'cbi', 'cyber cell', 'amazon', 'flipkart',
  ];

  static bool _any(String t, List<String> words) => words.any(t.contains);

  LocalScamResult score(String text, {String sender = ''}) {
    final t = ' ${text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ')} ';
    final s = sender.toLowerCase().trim();
    final signals = <ScamSignal>[];
    void add(String id, int w) => signals.add(ScamSignal(id, w));

    final urls = _url.allMatches(text).map((m) => m.group(0)!.toLowerCase()).toList();
    final hasLink = urls.isNotEmpty;
    final shortLink = urls.any((u) => _shorteners.any(u.contains));
    final oddLink = urls.any((u) => _oddTlds.any((d) => '$u '.contains(d)) || RegExp(r'https?://\d{1,3}(\.\d{1,3}){3}').hasMatch(u));
    final brandInLink = urls.any((u) => RegExp(r'(sbi|hdfc|icici|axis|kotak|paytm|phonepe|amazon|flipkart|kyc|aadhaar|uidai|incometax|epfo|indiapost|electric|bill|refund|reward)').hasMatch(u) &&
        !RegExp(r'(onlinesbi\.sbi|sbi\.co\.in|hdfcbank\.com|icicibank\.com|axisbank\.com|kotak\.com|paytm\.com|phonepe\.com|amazon\.in|amazon\.com|flipkart\.com|uidai\.gov\.in|incometax\.gov\.in|epfindia\.gov\.in|indiapost\.gov\.in|\.gov\.in|\.nic\.in)').hasMatch(u));

    final asksSecret = RegExp(r'\b(share|send|tell|give|enter|provide|forward)\b[^.]{0,40}\b(otp|pin|cvv|password|mpin|upi pin)\b').hasMatch(t) ||
        RegExp(r'\b(otp|cvv|mpin|upi pin)\b[^.]{0,30}\b(share|send|tell|give|enter|provide|call|whatsapp)\b').hasMatch(t);
    final otpNormal = RegExp(r'(do not|don.?t|never) share').hasMatch(t) && RegExp(r'\botp\b').hasMatch(t) && !hasLink;
    final kyc = _any(t, ['kyc', 'pan card', 'update pan', 'pan update', 'pan link', 'link pan', 'aadhaar update', 'update aadhaar', 'aadhar update', 're-kyc', 'ekyc', 'e-kyc', 'verify your account', 'account verification']);
    final threat = _any(t, ['blocked', 'block today', 'will be block', 'suspended', 'deactivat', 'disconnect', 'will be closed', 'freeze', 'frozen', 'legal action', 'arrest', 'fir ', 'penalty', 'expire today', 'expires today', 'last warning']);
    final urgent = _any(t, ['urgent', 'immediately', 'today', 'within 24', 'in 24 hours', 'within 2 hours', 'tonight', 'act now', 'last chance', 'final notice', 'asap']);
    final prize = _any(t, ['lottery', 'you have won', 'you won', 'winner', 'prize', 'lucky draw', 'jackpot', 'gift card', 'cashback of', 'reward points', 'claim your', 'kbc', 'congratulations']);
    final refund = _any(t, ['refund', 'tax refund', 'income tax refund', 'it refund']) && (hasLink || _any(t, ['claim', 'click', 'verify', 'account details']));
    final power = _any(t, ['electricity', 'power will be', 'power supply', 'light bill', 'bijli', 'bill not updated', 'previous month bill']) && threat;
    final parcel = _any(t, ['parcel', 'package', 'courier', 'shipment', 'customs', 'india post', 'indiapost', 'fedex', 'dhl']) &&
        _any(t, ['held', 'on hold', 'stuck', 'seized', 'incomplete address', 'address is incomplete', 'pay ', 'customs duty', 'redeliver', 'could not be delivered', 'illegal', 'drugs']);
    final job = _any(t, ['part time', 'part-time', 'work from home', 'daily income', 'earn rs', 'earn ₹', 'earn upto', 'earn up to', 'per day', 'like videos', 'youtube like', 'simple task', 'prepaid task', 'telegram task', 'hr from', 'salary of']) &&
        _any(t, ['earn', 'income', 'salary', '₹', 'rs', 'task', 'telegram', 'whatsapp']);
    final upiCollect = _any(t, ['collect request', 'approve the request', 'accept the request', 'enter your upi pin to receive', 'enter pin to receive', 'to receive money', 'scan to receive', 'scan qr to receive']);
    final apk = RegExp(r'\.apk\b').hasMatch(t) || _any(t, ['install this app', 'download the app from this link', 'anydesk', 'teamviewer', 'quick support', 'rustdesk', 'screen share', 'screen-share']);
    final brand = _any(t, _brands) || _any(' $s ', _brands);
    final personalSender = RegExp(r'^\+?\d[\d\s-]{8,}$').hasMatch(s) || s.contains('@gmail') || s.contains('@yahoo') || s.contains('@outlook');
    final investment = _any(t, ['guaranteed return', 'double your money', 'stock tips', 'ipo allotment', 'trading group', 'crypto profit', 'daily profit']);
    final impersonateKin = _any(t, ['hi mum', 'hi dad', 'this is my new number', 'new number, save', 'send money urgently']);

    if (asksSecret && !otpNormal) add('secret', 5);
    if (kyc) add('kyc', 3);
    if (threat) add('threat', 3);
    if (shortLink) add('shortLink', 3);
    if (oddLink) add('oddLink', 3);
    if (brandInLink) add('lookalike', 3);
    if (prize) add('prize', 3);
    if (refund) add('refund', 3);
    if (power) add('power', 4);
    if (parcel) add('parcel', 3);
    if (job) add('job', 4);
    if (upiCollect) add('upiCollect', 5);
    if (apk) add('apk', 5);
    if (investment) add('investment', 3);
    if (impersonateKin) add('family', 3);
    if (urgent && signals.isNotEmpty && !threat) add('urgent', 2);
    if (hasLink && !shortLink && !oddLink && !brandInLink && signals.isNotEmpty) add('link', 1);
    if (brand && personalSender && signals.isNotEmpty) add('sender', 2);

    signals.sort((a, b) => b.weight.compareTo(a.weight));
    final score = signals.fold<int>(0, (n, x) => n + x.weight);
    return LocalScamResult(score, signals);
  }
}

String _pick(Map<String, List<String>> m, String id, String lang) {
  final v = m[id] ?? m['none']!;
  return v[lang == 'te' ? 1 : (lang == 'hi' ? 2 : 0)];
}

String _reasonText(String id, String lang) => _pick(_reasonTexts, id, lang);
String _actionText(String id, String lang) => _pick(_actionTexts, id, lang);

String _summaryText(ScamLevel level, String lang) => _pick({
      'scam': [
        'This message shows clear signs of a fraud.',
        'ఈ మెసేజ్‌లో మోసానికి స్పష్టమైన సంకేతాలు ఉన్నాయి.',
        'इस मैसेज में धोखाधड़ी के साफ़ संकेत हैं।',
      ],
      'suspicious': [
        'Some things in this message look risky — check before you act.',
        'ఈ మెసేజ్‌లో కొన్ని విషయాలు ప్రమాదకరంగా ఉన్నాయి — ఏదైనా చేసే ముందు చెక్ చేయండి.',
        'इस मैसेज की कुछ बातें खतरनाक लगती हैं — कुछ करने से पहले जांच लें।',
      ],
      'none': [
        'We didn’t find common scam signs, but stay careful.',
        'సాధారణ స్కామ్ సంకేతాలు కనిపించలేదు, అయినా జాగ్రత్తగా ఉండండి.',
        'आम स्कैम संकेत नहीं मिले, फिर भी सावधान रहें।',
      ],
    }, level == ScamLevel.safe ? 'none' : level.name, lang);

const Map<String, List<String>> _reasonTexts = {
  'secret': ['Asks you to share or enter an OTP, PIN, CVV or password.', 'OTP, PIN, CVV లేదా పాస్‌వర్డ్ చెప్పమని / ఎంటర్ చేయమని అడుగుతోంది.', 'OTP, PIN, CVV या पासवर्ड बताने / डालने को कहता है।'],
  'kyc': ['Asks for a KYC / PAN / Aadhaar “update” — banks don’t do this by SMS link.', 'KYC / PAN / Aadhaar “అప్‌డేట్” అడుగుతోంది — బ్యాంకులు SMS లింక్‌తో ఇలా అడగవు.', 'KYC / PAN / Aadhaar “अपडेट” मांगता है — बैंक SMS लिंक से ऐसा नहीं करते।'],
  'threat': ['Threatens that your account, SIM or service will be blocked or cut.', 'మీ అకౌంట్, SIM లేదా సర్వీస్ బ్లాక్ / కట్ అవుతుందని భయపెడుతోంది.', 'अकाउंट, SIM या सर्विस बंद होने की धमकी देता है।'],
  'shortLink': ['Uses a short link that hides where it really goes.', 'అసలు ఎక్కడికి వెళ్తుందో దాచే షార్ట్ లింక్ ఉంది.', 'छोटा लिंक है जो छिपाता है कि यह असल में कहां ले जाता है।'],
  'oddLink': ['Has a link with an unusual web address, not an official site.', 'అధికారిక సైట్ కాని వింత వెబ్ అడ్రస్ లింక్ ఉంది.', 'अजीब वेब पते वाला लिंक है, कोई सरकारी / आधिकारिक साइट नहीं।'],
  'lookalike': ['The link imitates a bank, company or government name.', 'లింక్ బ్యాంక్, కంపెనీ లేదా ప్రభుత్వ పేరును నకలు చేస్తోంది.', 'लिंक किसी बैंक, कंपनी या सरकारी नाम की नकल करता है।'],
  'prize': ['Promises a prize, lottery or reward you didn’t enter for.', 'మీరు పాల్గొనని బహుమతి, లాటరీ లేదా రివార్డ్ ఇస్తామంటోంది.', 'ऐसे इनाम, लॉटरी या रिवॉर्ड का वादा करता है जिसमें आपने हिस्सा नहीं लिया।'],
  'refund': ['Offers a refund you must “claim” through a link.', 'లింక్ ద్వారా “క్లెయిమ్” చేయాల్సిన రిఫండ్ అంటోంది.', 'लिंक से “क्लेम” करने वाला रिफंड बताता है।'],
  'power': ['Says your electricity will be cut tonight — a common scam.', 'ఈ రాత్రి కరెంట్ కట్ అవుతుందని చెబుతోంది — ఇది సాధారణ స్కామ్.', 'आज रात बिजली कटने की बात करता है — यह आम स्कैम है।'],
  'parcel': ['Says a parcel is stuck and asks you to pay or act.', 'పార్సెల్ ఆగిపోయిందని, డబ్బు కట్టమని లేదా ఏదో చేయమని అడుగుతోంది.', 'पार्सल अटकने की बात कहकर पैसे या कुछ करने को कहता है।'],
  'job': ['Offers easy money for tasks or part-time work.', 'చిన్న పనులు / పార్ట్ టైమ్ పనికి సులువుగా డబ్బు అంటోంది.', 'छोटे काम / पार्ट-टाइम के लिए आसान कमाई का लालच देता है।'],
  'upiCollect': ['Asks you to approve a UPI request or enter your PIN to “receive” money — a PIN only sends money.', 'డబ్బు “రావడానికి” UPI రిక్వెస్ట్ ఓకే చేయమని / PIN ఎంటర్ చేయమని అడుగుతోంది — PIN డబ్బు పంపడానికి మాత్రమే.', 'पैसे “पाने” के लिए UPI रिक्वेस्ट मानने या PIN डालने को कहता है — PIN सिर्फ़ पैसे भेजने के लिए होता है।'],
  'apk': ['Asks you to install an app file (APK) or a screen-sharing app.', 'APK ఫైల్ లేదా స్క్రీన్ షేరింగ్ యాప్ ఇన్‌స్టాల్ చేయమంటోంది.', 'APK फ़ाइल या स्क्रीन-शेयरिंग ऐप इंस्टॉल करने को कहता है।'],
  'investment': ['Promises guaranteed or very high returns.', 'గ్యారంటీ లేదా చాలా ఎక్కువ లాభం అంటోంది.', 'पक्का या बहुत ज़्यादा मुनाफ़ा बताता है।'],
  'family': ['Pretends to be family or a friend with a new number asking for money.', 'కొత్త నంబర్‌తో కుటుంబ సభ్యుడు / స్నేహితుడిలా నటించి డబ్బు అడుగుతోంది.', 'नए नंबर से परिवार / दोस्त बनकर पैसे मांगता है।'],
  'urgent': ['Rushes you to act fast so you don’t stop and check.', 'మీరు ఆలోచించకుండా తొందరగా చేయమని ఒత్తిడి చేస్తోంది.', 'जल्दी करने का दबाव डालता है ताकि आप रुककर जांच न करें।'],
  'link': ['Has a link — open the official app instead of the link.', 'లింక్ ఉంది — లింక్ బదులు అధికారిక యాప్ తెరవండి.', 'लिंक है — लिंक की जगह आधिकारिक ऐप खोलें।'],
  'sender': ['Claims to be a bank or company but comes from a personal number or email.', 'బ్యాంక్ / కంపెనీ అని చెప్పుకుంటూ వ్యక్తిగత నంబర్ / ఈమెయిల్ నుంచి వచ్చింది.', 'बैंक / कंपनी होने का दावा, पर निजी नंबर या ईमेल से आया है।'],
  'none': ['No common scam signs found (no link, no OTP/PIN request, no threats).', 'సాధారణ స్కామ్ సంకేతాలు లేవు (లింక్, OTP/PIN అడగడం, బెదిరింపులు లేవు).', 'आम स्कैम संकेत नहीं मिले (कोई लिंक, OTP/PIN मांग या धमकी नहीं)।'],
};

const Map<String, List<String>> _actionTexts = {
  'noClick': ['Don’t click the link or reply.', 'లింక్ క్లిక్ చేయకండి, రిప్లై ఇవ్వకండి.', 'लिंक पर क्लिक न करें, जवाब न दें।'],
  'noOtp': ['Never share your OTP, PIN or CVV with anyone.', 'మీ OTP, PIN, CVV ఎవరికీ చెప్పకండి.', 'अपना OTP, PIN या CVV किसी को न बताएं।'],
  'chakshu': ['Report it on Chakshu at sancharsaathi.gov.in.', 'sancharsaathi.gov.in లో చక్షు ద్వారా రిపోర్ట్ చేయండి.', 'sancharsaathi.gov.in पर चक्षु में रिपोर्ट करें।'],
  'lost': ['Lost money or shared an OTP? Call 1930 or report at cybercrime.gov.in, and call your bank.', 'డబ్బు పోయినా / OTP చెప్పినా: 1930కి కాల్ చేయండి లేదా cybercrime.gov.in లో రిపోర్ట్ చేయండి, బ్యాంక్‌కి కాల్ చేయండి.', 'पैसे गए या OTP बताया? 1930 पर कॉल करें या cybercrime.gov.in पर रिपोर्ट करें, और बैंक को फ़ोन करें।'],
  'verify': ['If unsure, check in the official app or call the number on your card or bill.', 'అనుమానం ఉంటే అధికారిక యాప్‌లో చూడండి లేదా మీ కార్డ్ / బిల్ మీద ఉన్న నంబర్‌కి కాల్ చేయండి.', 'शक हो तो आधिकारिक ऐप में देखें या कार्ड / बिल पर लिखे नंबर पर कॉल करें।'],
  'none': ['Stay careful.', 'జాగ్రత్తగా ఉండండి.', 'सावधान रहें।'],
};

/// Sample messages for "Try an example".
const List<(String sender, String text)> kScamExamples = [
  ('+91 98765 43xxx', 'Dear customer your SBI account will be blocked today, update PAN at http://sbi-kyc.co/x'),
  ('AX-AMAZON', 'Delivered: Your Amazon package was delivered to your doorstep. Track your orders in the Amazon app.'),
  ('+91 70xxx xxx12', 'Dear consumer your electricity power will be disconnected tonight at 9.30 pm because your previous month bill was not updated. Please call our electricity officer 98xxxxxx10'),
];
