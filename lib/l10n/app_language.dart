import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'strings.dart';

/// The reader's app language: English, Telugu or Hindi.
enum AppLang {
  en('en', 'English', 'English', 'en-IN'),
  te('te', 'తెలుగు', 'Telugu', 'te-IN'),
  hi('hi', 'हिन्दी', 'Hindi', 'hi-IN');

  final String code;

  /// The language's own name (shown in the picker).
  final String nativeName;
  final String englishName;

  /// BCP-47 tag for the device voice (text-to-speech).
  final String ttsLocale;
  const AppLang(this.code, this.nativeName, this.englishName, this.ttsLocale);

  static AppLang fromCode(String? code) => AppLang.values.firstWhere((l) => l.code == code, orElse: () => AppLang.en);
}

/// Saved app language (SharedPreferences: localStorage on web). One instance
/// for the whole app ([appLanguage]) so plain getters like a category's label
/// can read it without a BuildContext.
class AppLanguage extends ValueNotifier<AppLang> {
  static const prefsKey = 'techdaily_lang';
  static const askedKey = 'techdaily_lang_asked';

  AppLanguage([super.value = AppLang.en]);

  bool _loaded = false;
  bool _asked = true;
  bool get loaded => _loaded;

  /// False until the reader has picked a language once (drives the one-time
  /// "Read in తెలుగు / हिन्दी?" prompt on home).
  bool get asked => _asked;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      value = AppLang.fromCode(prefs.getString(prefsKey));
      _asked = prefs.getBool(askedKey) ?? prefs.getString(prefsKey) != null;
    } catch (_) {
      _asked = true;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> set(AppLang lang) async {
    _asked = true;
    if (value == lang) {
      notifyListeners();
    } else {
      value = lang;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, lang.code);
      await prefs.setBool(askedKey, true);
    } catch (_) {}
  }

  /// Hides the first-launch prompt without changing the language.
  Future<void> dismissPrompt() async {
    _asked = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(askedKey, true);
    } catch (_) {}
  }

  @visibleForTesting
  void resetForTest() {
    value = AppLang.en;
    _asked = true;
    _loaded = false;
  }
}

/// The app-wide language.
final AppLanguage appLanguage = AppLanguage();

/// UI string in the current language. Keys are the English text; anything not
/// in the table stays English. `{n}`-style placeholders are filled from [args].
String tr(String english, [Map<String, Object> args = const {}]) {
  var s = translateUi(english, appLanguage.value.code);
  args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  return s;
}

/// Rebuilds every widget after a language change (keeps navigation and state),
/// so text read through [tr] in const widgets and plain getters updates too.
void rebuildAllForLanguage() {
  final root = WidgetsBinding.instance.rootElement;
  if (root == null) return;
  void mark(Element e) {
    e.markNeedsBuild();
    e.visitChildren(mark);
  }

  mark(root);
}
