import 'package:flutter/material.dart';

import '../../l10n/app_language.dart' show tr;

/// Per-category question sets for the story page. Mirrors
/// `functions/src/stories/questions.ts` (a backend test checks the labels
/// match). Stored keys never change (whatHappened / affectsWho / whatToDo /
/// whatItMeans); only the question shown above each one does.
enum ListStyle { steps, bullets, fact }

class StoryQuestion {
  /// English question (matches the backend's questions.ts).
  final String enLabel;
  final IconData icon;
  const StoryQuestion(this.enLabel, this.icon);

  /// The question in the app language.
  String get label => tr(enLabel);
}

class StoryQuestionSet {
  final StoryQuestion whatHappened;
  final StoryQuestion affectsWho;
  final StoryQuestion whatToDo;
  final ListStyle todoStyle;
  final StoryQuestion whatItMeans;
  const StoryQuestionSet(this.whatHappened, this.affectsWho, this.whatToDo, this.todoStyle, this.whatItMeans);
}

const String kGoodToKnowLabel = 'Good to know';
const String kTldrLabel = 'In one line';
const String kKeyNumbersLabel = 'Key numbers';
const String kFallbackPill = 'Simplified summary · updating soon';
const String kAskLabel = 'Ask about this';

const _what = Icons.newspaper_rounded;
const _who = Icons.person_search_rounded;
const _steps = Icons.task_alt_rounded;
const _why = Icons.lightbulb_rounded;
const _next = Icons.rocket_launch_rounded;
const _price = Icons.sell_rounded;
const _fact = Icons.auto_awesome_rounded;
const _shield = Icons.shield_rounded;

const StoryQuestionSet kGeneralQuestions = StoryQuestionSet(
  StoryQuestion('What happened?', _what),
  StoryQuestion('Who does this affect?', _who),
  StoryQuestion('What can you do?', _steps),
  ListStyle.steps,
  StoryQuestion('Why it matters', _why),
);

const StoryQuestionSet kScamQuestions = StoryQuestionSet(
  StoryQuestion('What’s the trick?', Icons.phishing_rounded),
  StoryQuestion('Am I at risk?', _who),
  StoryQuestion('Stay safe', _shield),
  ListStyle.steps,
  StoryQuestion('Why it matters', _why),
);

const Map<String, StoryQuestionSet> kQuestionSets = {
  'scams-security': StoryQuestionSet(StoryQuestion('What happened?', _what), StoryQuestion('Am I at risk?', _who),
      StoryQuestion('Protect yourself', _shield), ListStyle.steps, StoryQuestion('Why it matters', _why)),
  'ai': StoryQuestionSet(StoryQuestion('What happened?', _what), StoryQuestion('How does it affect you?', _who),
      StoryQuestion('Try it / stay safe', _steps), ListStyle.steps, StoryQuestion('Why it matters', _why)),
  'phones-gadgets': StoryQuestionSet(StoryQuestion('What’s new?', _what), StoryQuestion('Should I care / upgrade?', _who),
      StoryQuestion('Price & availability in India', _price), ListStyle.bullets, StoryQuestion('Bottom line', _why)),
  'chips-hardware': StoryQuestionSet(StoryQuestion('What’s new?', _what), StoryQuestion('Will I notice?', _who),
      StoryQuestion('Good to know', Icons.info_rounded), ListStyle.bullets, StoryQuestion('Bigger picture', _why)),
  'startups-india': StoryQuestionSet(StoryQuestion('What happened?', _what), StoryQuestion('Who’s affected?', _who),
      StoryQuestion('If you use it', _steps), ListStyle.steps, StoryQuestion('Why it matters', _why)),
  'innovations': StoryQuestionSet(StoryQuestion('What’s the breakthrough?', _what), StoryQuestion('When could I see it?', _who),
      StoryQuestion('Cool fact', _fact), ListStyle.fact, StoryQuestion('What’s next', _next)),
  'money-fintech': StoryQuestionSet(StoryQuestion('What changed?', _what), StoryQuestion('Does it affect my money?', _who),
      StoryQuestion('What to do', _steps), ListStyle.steps, StoryQuestion('Bottom line', _why)),
  'privacy': StoryQuestionSet(StoryQuestion('What happened?', _what), StoryQuestion('Is my data at risk?', _who),
      StoryQuestion('Protect your privacy', _shield), ListStyle.steps, StoryQuestion('Why it matters', _why)),
  'telecom': StoryQuestionSet(StoryQuestion('What changed?', _what), StoryQuestion('Does it hit my plan?', _who),
      StoryQuestion('What to do', _steps), ListStyle.steps, StoryQuestion('Bottom line', _why)),
  'digital-india': StoryQuestionSet(StoryQuestion('What changed?', _what), StoryQuestion('Who needs to act?', _who),
      StoryQuestion('How to do it', _steps), ListStyle.steps, StoryQuestion('Why it matters', _why)),
  'ev-mobility': StoryQuestionSet(StoryQuestion('What’s new?', _what), StoryQuestion('Who should care?', _who),
      StoryQuestion('Price, range & availability', _price), ListStyle.bullets, StoryQuestion('Bottom line', _why)),
  'space': StoryQuestionSet(StoryQuestion('What happened?', _what), StoryQuestion('Why should I care?', _who),
      StoryQuestion('Cool fact', _fact), ListStyle.fact, StoryQuestion('What’s next', _next)),
  'apps-gaming': StoryQuestionSet(StoryQuestion('What’s new?', _what), StoryQuestion('Who gets it?', _who),
      StoryQuestion('How to get it', _steps), ListStyle.steps, StoryQuestion('Bottom line', _why)),
  'health-tech': StoryQuestionSet(StoryQuestion('What happened?', _what), StoryQuestion('Who can use it?', _who),
      StoryQuestion('Use it safely', _steps), ListStyle.steps, StoryQuestion('Why it matters', _why)),
  'jobs-skills': StoryQuestionSet(StoryQuestion('What happened?', _what), StoryQuestion('Does it affect my job?', _who),
      StoryQuestion('What you can do', _steps), ListStyle.steps, StoryQuestion('Bottom line', _why)),
};

/// The question set for a story: scam stories get the scam set.
StoryQuestionSet questionsFor(String category, {bool isScam = false}) =>
    isScam ? kScamQuestions : (kQuestionSets[category] ?? kGeneralQuestions);

final RegExp _legacyAuto = RegExp(r'\s*This short version was written automatically[^.]*\.(?:[^.]*details\.)?', caseSensitive: false);
final RegExp _legacyFiller = RegExp(r'^(nothing (to do|urgent)|no one directly yet)', caseSensitive: false);
final RegExp _legacyReported = RegExp(r'^[^:]{2,80} reported: ');
final RegExp _legacyAffects = RegExp(r'^(People|Mainly tech|Customers|Mobile and)');

/// The text actually shown (same rules as `displayFields` in questions.ts):
/// strips the old "written automatically" sentence and old canned fallback
/// lines so stories not yet rewritten never show boilerplate.
class StoryDisplay {
  final String tldr;
  final String whatHappened;
  final String affectsWho;
  final List<String> whatToDo;
  final String goodToKnow;
  final String whatItMeans;
  const StoryDisplay({
    required this.tldr,
    required this.whatHappened,
    required this.affectsWho,
    required this.whatToDo,
    required this.goodToKnow,
    required this.whatItMeans,
  });

  factory StoryDisplay.of({
    required String aiModel,
    required String promptVersion,
    required String tldr,
    required String whatHappened,
    required String affectsWho,
    required List<String> whatToDo,
    required String goodToKnow,
    required String whatItMeans,
  }) {
    final fallback = aiModel.startsWith('techdaily-fallback');
    final legacy = fallback && promptVersion != 'stories-v3';
    var wh = whatHappened.replaceAll(_legacyAuto, '').trim();
    if (legacy && _legacyReported.hasMatch(wh)) wh = '';
    final todo = whatToDo.where((x) => !_legacyFiller.hasMatch(x) && !x.toLowerCase().contains('open the original report')).toList();
    final who = _legacyFiller.hasMatch(affectsWho) || (legacy && _legacyAffects.hasMatch(affectsWho)) ? '' : affectsWho.trim();
    return StoryDisplay(
      tldr: tldr.trim(),
      whatHappened: wh,
      affectsWho: who,
      whatToDo: legacy ? const [] : todo,
      goodToKnow: goodToKnow.trim(),
      whatItMeans: legacy ? '' : whatItMeans.trim(),
    );
  }
}
