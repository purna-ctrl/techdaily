import '../../models/story.dart';

/// Offline demo / test stories (`--dart-define=TECHDAILY_DATA_SOURCE=local`).
/// Clearly fictional examples; never shown in production builds.
StoryFeed sampleStoryFeed({DateTime? now}) {
  final n = now ?? DateTime.now();
  DateTime ago(int h) => n.subtract(Duration(hours: h));
  StorySource src(String name, String url, String title, int h) =>
      StorySource(name: name, url: url, title: title, publishedAt: ago(h));

  final stories = <Story>[
    Story(
      id: 'demo-scam-1',
      slug: 'fake-parcel-texts-trick-upi-users-demo01',
      headline: 'Fake parcel texts are tricking UPI users',
      category: 'scams-security',
      publishedAt: ago(1),
      updatedAt: ago(1),
      sources: [
        src('Example News', 'https://example.com/news/parcel-scam', 'Courier SMS scam targets UPI users', 1),
        src('Example Daily', 'https://example.org/tech/parcel-sms', 'Police warn of fake courier SMS', 2),
      ],
      whatHappened: 'Crooks are sending SMS messages about a “stuck parcel” and asking for a small fee through a link.',
      affectsWho: 'Anyone who gets SMS messages and pays with UPI apps.',
      whatToDo: ['Ignore texts about parcels you did not order.', 'Never enter your UPI PIN to receive anything.'],
      whatItMeans: 'A tiny fee request can empty your account, so check before you pay.',
      scam: const ScamInfo(
        howItWorks: 'You get a text saying a parcel is held. The link opens a fake payment page. When you pay, they capture your UPI PIN.',
        warningSigns: ['A parcel you never ordered', 'A link asking for a small fee', 'Pressure to pay today'],
        ifTargeted: ['Call your bank and block UPI.', 'Call 1930 or report at cybercrime.gov.in.'],
      ),
      confidence: 'high',
      region: 'IN',
      aiModel: 'demo',
    ),
    Story(
      id: 'demo-ai-1',
      slug: 'chatbot-adds-hindi-voice-mode-demo02',
      headline: 'A popular AI chatbot now talks in Hindi',
      category: 'ai',
      publishedAt: ago(3),
      updatedAt: ago(3),
      sources: [src('Example Tech', 'https://example.com/ai/hindi-voice', 'Chatbot adds Hindi voice mode', 3)],
      whatHappened: 'The chatbot’s voice mode can now understand and answer in Hindi.',
      affectsWho: 'People who use AI chatbots on their phones.',
      whatToDo: ['Update the app to try it.', 'Avoid sharing private details with chatbots.'],
      whatItMeans: 'You can ask questions out loud in Hindi instead of typing in English.',
      region: 'IN',
      aiModel: 'demo',
    ),
    Story(
      id: 'demo-phone-1',
      slug: 'new-budget-phone-launches-demo03',
      headline: 'A new budget 5G phone launches in India',
      category: 'phones-gadgets',
      publishedAt: ago(5),
      updatedAt: ago(5),
      sources: [src('Example Gadgets', 'https://example.com/phones/budget-5g', 'Budget 5G phone launched in India', 5)],
      whatHappened: 'A phone maker launched a low-cost 5G phone with a big battery.',
      affectsWho: 'People looking for an affordable phone.',
      whatToDo: ['Wait for reviews before buying.', 'Compare prices across stores.'],
      whatItMeans: 'Cheaper 5G phones mean more choice under a small budget.',
      confidence: 'low',
      developing: true,
      region: 'IN',
      aiModel: 'techdaily-fallback-v2',
    ),
    Story(
      id: 'demo-money-1',
      slug: 'upi-sets-monthly-record-demo04',
      headline: 'UPI sets a new monthly record',
      category: 'money-fintech',
      publishedAt: ago(7),
      updatedAt: ago(7),
      sources: [src('Example Money', 'https://example.com/money/upi-record', 'UPI hits record transactions', 7)],
      whatHappened: 'More UPI payments were made last month than in any month before.',
      affectsWho: 'Everyone who pays with UPI apps.',
      whatToDo: ['Nothing to do — keep using UPI as usual.'],
      whatItMeans: 'UPI keeps growing, so more shops will accept it.',
      region: 'IN',
      aiModel: 'demo',
    ),
    Story(
      id: 'demo-chip-1',
      slug: 'new-laptop-chip-promises-longer-battery-demo05',
      headline: 'A new laptop chip promises longer battery life',
      category: 'chips-hardware',
      publishedAt: ago(9),
      updatedAt: ago(9),
      sources: [src('Example Hardware', 'https://example.com/chips/laptop-chip', 'New laptop chip announced', 9)],
      whatHappened: 'A chip maker announced a laptop processor that uses less power.',
      affectsWho: 'People planning to buy a laptop next year.',
      whatToDo: ['Nothing to do right now.'],
      whatItMeans: 'Future laptops may last longer on one charge.',
      aiModel: 'demo',
    ),
    Story(
      id: 'demo-privacy-1',
      slug: 'app-permissions-check-demo06',
      headline: 'Many apps ask for more phone permissions than they need',
      category: 'privacy',
      publishedAt: ago(12),
      updatedAt: ago(12),
      sources: [src('Example Privacy', 'https://example.com/privacy/permissions', 'Study on app permissions', 12)],
      whatHappened: 'A study found many popular apps ask for location and contacts without needing them.',
      affectsWho: 'Android and iPhone users.',
      whatToDo: ['Open Settings and review app permissions.', 'Turn off location for apps that don’t need it.'],
      whatItMeans: 'You can share less personal data with a few taps.',
      aiModel: 'demo',
    ),
  ];
  return StoryFeed(
    stories: stories,
    today: [for (final s in stories.take(5)) TodayItem.fromStory(s)],
    generatedAt: n,
  );
}
