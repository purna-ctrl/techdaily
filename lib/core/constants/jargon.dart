/// Tap-to-explain jargon: ~40 tech words in simple words (Indian context).
/// Keys are the display term; [JargonEntry.patterns] are matched as whole
/// words, case-insensitively (acronyms are matched case-sensitively so "it"
/// never matches "IT").
class JargonEntry {
  final String term;
  final String meaning;
  final String? example;
  final List<String> patterns;
  final bool caseSensitive;
  const JargonEntry(this.term, this.meaning, {this.example, this.patterns = const [], this.caseSensitive = false});

  List<String> get allPatterns => [term, ...patterns];
}

const List<JargonEntry> kJargon = [
  JargonEntry('UPI', 'Unified Payments Interface: India’s system for sending money instantly from your phone using a UPI ID or QR code.',
      example: 'Paying a shopkeeper by scanning a QR code with GPay or PhonePe.', caseSensitive: true),
  JargonEntry('UPI PIN', 'The secret 4–6 digit number that approves a UPI payment. You only ever need it to SEND money, never to receive.',
      caseSensitive: true),
  JargonEntry('OTP', 'One-Time Password: a short code sent by SMS or app to confirm it is really you. Never share it with anyone, even “bank staff”.',
      caseSensitive: true),
  JargonEntry('KYC', 'Know Your Customer: the ID check (Aadhaar, PAN) banks and apps must do. Real KYC never happens through a link in an SMS.',
      caseSensitive: true),
  JargonEntry('phishing', 'A fake message, email or website that pretends to be a real company to trick you into giving passwords, OTPs or money.',
      patterns: ['phish', 'phishing attack']),
  JargonEntry('smishing', 'Phishing by SMS: a text with a fake link, like a “parcel on hold” or “electricity cut tonight” message.'),
  JargonEntry('vishing', 'Phishing by phone call: someone pretends to be from your bank, police or a courier to scare you into paying.'),
  JargonEntry('malware', 'Harmful software that spies on you, steals data or locks your phone. Often hides inside fake apps or APK files.',
      patterns: ['malicious software']),
  JargonEntry('ransomware', 'Malware that locks your files and demands money to unlock them.'),
  JargonEntry('spyware', 'Hidden software that secretly watches what you do on your phone or computer.'),
  JargonEntry('APK', 'An Android app file. Installing APKs sent on WhatsApp or SMS is a common way scammers take over phones.',
      caseSensitive: true, patterns: ['APK file', 'APK files']),
  JargonEntry('VPN', 'Virtual Private Network: an app that hides your internet traffic inside a protected tunnel, often used on public Wi-Fi.',
      caseSensitive: true),
  JargonEntry('encryption', 'Scrambling data so only the right person can read it. “End-to-end encrypted” chats can’t be read even by the app maker.',
      patterns: ['encrypted', 'end-to-end encryption', 'end-to-end encrypted']),
  JargonEntry('two-step verification', 'An extra lock on your account: after the password you also need a code from your phone.',
      patterns: ['two-factor authentication', '2FA', 'two-factor', 'multi-factor authentication', 'MFA']),
  JargonEntry('password manager', 'An app that creates and remembers strong, different passwords for each of your accounts.'),
  JargonEntry('data breach', 'When a company’s customer data (names, numbers, passwords) gets stolen or leaked.', patterns: ['breach', 'breached']),
  JargonEntry('zero-day', 'A security hole that attackers use before the company has a fix. Install updates as soon as they arrive.',
      patterns: ['zero day', '0-day']),
  JargonEntry('patch', 'A software update that fixes a bug or security hole.', patterns: ['security patch', 'patched']),
  JargonEntry('deepfake', 'A fake video or voice made with AI that looks and sounds like a real person.', patterns: ['deepfakes']),
  JargonEntry('digital arrest', 'A scam where fake “police” or “CBI” keep you on a video call and demand money. Real police never arrest anyone online.'),
  JargonEntry('SIM swap', 'A fraud where crooks get a new SIM for your number so they receive your OTPs.', patterns: ['SIM-swap']),
  JargonEntry('AI', 'Artificial Intelligence: computer programs that learn from lots of examples to write, talk, see or decide.',
      caseSensitive: true, patterns: ['artificial intelligence']),
  JargonEntry('LLM', 'Large Language Model: the type of AI behind chatbots like ChatGPT and Gemini. It predicts words to write answers.',
      caseSensitive: true, patterns: ['LLMs', 'large language model', 'large language models']),
  JargonEntry('chatbot', 'An app you can chat with in plain language, like ChatGPT, Gemini or a bank’s help assistant.', patterns: ['chatbots']),
  JargonEntry('AI agent', 'An AI that doesn’t just answer but can take actions for you, like booking, shopping or filling forms.',
      patterns: ['AI agents', 'agentic']),
  JargonEntry('generative AI', 'AI that creates new text, images, music or video from a short description.', patterns: ['GenAI', 'gen AI']),
  JargonEntry('algorithm', 'A set of step-by-step rules a computer follows, e.g. to decide which posts you see.', patterns: ['algorithms']),
  JargonEntry('cloud', 'Computers in big data centres that store your files and run apps over the internet, instead of on your phone.',
      patterns: ['cloud computing', 'cloud storage']),
  JargonEntry('data centre', 'A huge building full of computers that run websites, apps and AI.', patterns: ['data center', 'data centres', 'data centers']),
  JargonEntry('chip', 'A tiny slice of silicon with billions of switches: the “brain” inside phones, cars and computers.',
      patterns: ['chips', 'semiconductor', 'semiconductors', 'microchip']),
  JargonEntry('GPU', 'Graphics Processing Unit: a chip great at doing many calculations at once, used for games and training AI.',
      caseSensitive: true, patterns: ['GPUs']),
  JargonEntry('processor', 'The main chip that runs your phone or laptop. Faster processors make apps open quicker.', patterns: ['CPU', 'SoC', 'chipset']),
  JargonEntry('5G', 'The fifth generation of mobile networks: much faster internet on your phone than 4G.', caseSensitive: true),
  JargonEntry('broadband', 'Fast, always-on home or office internet, through fibre, cable or wireless.', patterns: ['fibre', 'fiber']),
  JargonEntry('satellite internet', 'Internet beamed from satellites in space, useful where cables and towers don’t reach.', patterns: ['satcom']),
  JargonEntry('IPO', 'Initial Public Offering: when a company first sells its shares on the stock market so anyone can buy them.',
      caseSensitive: true),
  JargonEntry('funding round', 'When a startup raises money from investors in exchange for a share of the company.',
      patterns: ['Series A', 'Series B', 'Series C', 'seed round', 'funding']),
  JargonEntry('valuation', 'What investors think a whole company is worth.'),
  JargonEntry('unicorn', 'A startup valued at over \$1 billion (about ₹8,500 crore).', patterns: ['unicorns']),
  JargonEntry('fintech', 'Finance + technology: apps for payments, loans, insurance and investing.'),
  JargonEntry('RBI', 'Reserve Bank of India: India’s central bank, which makes the rules for banks, UPI and digital lending.', caseSensitive: true),
  JargonEntry('cookies', 'Small files websites save in your browser to remember you and track what you do online.'),
  JargonEntry('DPDP Act', 'India’s Digital Personal Data Protection law: rules for how companies collect and use your personal data.',
      patterns: ['DPDP', 'data protection law']),
  JargonEntry('open source', 'Software whose code is public, so anyone can check, use or improve it.', patterns: ['open-source']),
  JargonEntry('crypto', 'Digital money like Bitcoin that is not issued by a government. Prices swing wildly and scams are common.',
      patterns: ['cryptocurrency', 'cryptocurrencies', 'bitcoin']),
];

/// Finds jargon in [text]: each entry at most once, in reading order.
/// Returns (start, end, entry) ranges that never overlap.
List<(int, int, JargonEntry)> findJargon(String text, {int max = 6}) {
  // Story text is re-laid out on rebuilds; scanning ~100 terms each time is wasted work.
  final key = '$max|$text';
  final cached = _jargonMemo[key];
  if (cached != null) return cached;
  final found = _findJargon(text, max);
  if (_jargonMemo.length > 300) _jargonMemo.clear();
  return _jargonMemo[key] = found;
}

final Map<String, List<(int, int, JargonEntry)>> _jargonMemo = {};

List<(int, int, JargonEntry)> _findJargon(String text, int max) {
  final hits = <(int, int, JargonEntry)>[];
  final lower = text.toLowerCase();
  for (final e in kJargon) {
    (int, int)? best;
    for (final p in e.allPatterns) {
      final hay = e.caseSensitive ? text : lower;
      final needle = e.caseSensitive ? p : p.toLowerCase();
      var from = 0;
      while (true) {
        final i = hay.indexOf(needle, from);
        if (i < 0) break;
        final end = i + needle.length;
        final before = i == 0 ? ' ' : hay[i - 1];
        final after = end >= hay.length ? ' ' : hay[end];
        if (!_isWordChar(before) && !_isWordChar(after)) {
          if (best == null || i < best.$1 || (i == best.$1 && end > best.$2)) best = (i, end);
          break;
        }
        from = i + 1;
      }
    }
    if (best != null) hits.add((best.$1, best.$2, e));
  }
  hits.sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : (b.$2 - b.$1).compareTo(a.$2 - a.$1));
  final out = <(int, int, JargonEntry)>[];
  var lastEnd = -1;
  for (final h in hits) {
    if (h.$1 < lastEnd) continue;
    out.add(h);
    lastEnd = h.$2;
    if (out.length >= max) break;
  }
  return out;
}

// Char-code test (was a new RegExp per character checked: slow on web).
bool _isWordChar(String c) {
  if (c.isEmpty) return false;
  final u = c.codeUnitAt(0);
  return (u >= 48 && u <= 57) || (u >= 65 && u <= 90) || (u >= 97 && u <= 122);
}

/// Distinct jargon entries across several texts (for the "Jargon in this story" chips).
List<JargonEntry> jargonIn(Iterable<String> texts, {int max = 8}) {
  final seen = <String>{};
  final out = <JargonEntry>[];
  for (final t in texts) {
    for (final h in findJargon(t, max: 20)) {
      if (seen.add(h.$3.term)) out.add(h.$3);
      if (out.length >= max) return out;
    }
  }
  return out;
}
