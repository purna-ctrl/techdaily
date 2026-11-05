/// Central runtime configuration for TechDaily.
///
/// Keep every deploy-dependent URL / key in this one file.
library;

/// Public site origin used to build shareable deep links (`/article/<id>`).
const String kSiteUrl = 'https://techdaily-prod.web.app';

/// "Ask AI about this article" backend.
/// Contract: POST JSON `{articleId, question}` → `{answer}`.
///
/// NOTE: placeholder URL — it may need updating after the Cloud Function is
/// deployed (check the URL printed by `firebase deploy --only functions`).
/// If the call fails for any reason the app falls back to the on-device,
/// article-grounded answers in `ArticleAiAssistantService.answerQuestion`.
const String kAskArticleEndpoint =
    'https://us-central1-techdaily-prod.cloudfunctions.net/askArticle';

/// Timeout for the Ask AI request before falling back to local answers.
const Duration kAskArticleTimeout = Duration(seconds: 12);

/// Web push (FCM) VAPID public key.
/// Firebase console → Project settings → Cloud Messaging → Web Push
/// certificates → "Key pair". Leave empty until generated; web push token
/// registration is skipped while it is empty (Android is unaffected).
const String kWebPushVapidKey = String.fromEnvironment(
  'TECHDAILY_VAPID_KEY',
  defaultValue: '',
);

/// FCM topics used for Android push. Web clients cannot subscribe to topics
/// from the browser; their tokens are stored in `users/{uid}.fcmTokens` so the
/// backend can subscribe/send to them server-side.
const String kTopicBreaking = 'breaking';
const String kTopicDailyBrief = 'daily-brief';

/// Build-time switch to run the app on bundled sample data instead of
/// Firestore (used for local screenshots / offline demos):
/// `flutter build web --dart-define=TECHDAILY_DATA_SOURCE=local`.
const String kDataSource = String.fromEnvironment(
  'TECHDAILY_DATA_SOURCE',
  defaultValue: 'firestore',
);

/// "Ask your own question" backend for stories (ASK_ENDPOINT). Empty by
/// default: answers then come from the story itself on the device (its FAQ,
/// the jargon dictionary and its sections). Set it to the deployed Cloudflare
/// Worker (`workers/ask/`) URL, here or at build time with
/// `--dart-define=ASK_ENDPOINT=https://techdaily-ask.<you>.workers.dev/ask`.
/// Contract: POST JSON `{slug, question, story}` -> `{answer}`.
const String kAskEndpoint = String.fromEnvironment('ASK_ENDPOINT', defaultValue: 'https://techdaily-ask.purnabannu1488.workers.dev');

/// Longest question the ask box accepts (the Worker enforces the same).
const int kAskMaxChars = 300;

/// Web image pass-through (Cloudflare Worker `workers/img/`): adds CORS so the
/// web app can draw publisher photos inside its canvas instead of as `<img>`
/// platform views, which made scrolling lag. Empty = direct `<img>` elements.
const String kImageProxy = String.fromEnvironment('IMAGE_PROXY', defaultValue: 'https://techdaily-img.purnabannu1488.workers.dev/');

/// The URL the web app loads for a publisher image.
String webImageUrl(String url) =>
    kImageProxy.isEmpty ? url : '$kImageProxy?u=${Uri.encodeComponent(url)}';
