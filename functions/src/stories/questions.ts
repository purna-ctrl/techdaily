/**
 * Per-category question sets for the story page. The stored keys never change
 * (whatHappened / affectsWho / whatToDo / whatItMeans) — only the question shown above each one and
 * what the writer is asked to put in it. Scam stories (story.scam set) use the SCAM set.
 *
 * Mirrored in the app: lib/core/constants/story_questions.dart (a test keeps the labels in sync).
 */
import { CATEGORY_IDS, CategoryId } from './categories';

export type SectionKey = 'whatHappened' | 'affectsWho' | 'whatToDo' | 'whatItMeans';

/** How the whatToDo list is shown: a tick checklist, plain bullets, or one highlighted fact. */
export type ListStyle = 'steps' | 'bullets' | 'fact';

export interface Question {
  label: string;
  /** What the writer must put under this question (used in the Gemini prompt). */
  ask: string;
}

export interface QuestionSet {
  whatHappened: Question;
  affectsWho: Question;
  whatToDo: Question & { style: ListStyle };
  whatItMeans: Question;
}

/** Shown instead of a fake "Nothing to do" checklist: whatToDo is empty, goodToKnow has a tip. */
export const GOOD_TO_KNOW_LABEL = 'Good to know';
export const TLDR_LABEL = 'In one line';
export const KEY_NUMBERS_LABEL = 'Key numbers';
export const FALLBACK_PILL = 'Simplified summary · updating soon';

const q = (label: string, ask: string): Question => ({ label, ask });
const list = (label: string, ask: string, style: ListStyle) => ({ label, ask, style });

export const GENERAL_QUESTIONS: QuestionSet = {
  whatHappened: q('What happened?', '1-2 sentences: who did what, when, with the main number.'),
  affectsWho: q('Who does this affect?', 'name the people affected (e.g. "Android users in India"), or say no one directly yet and why.'),
  whatToDo: list('What can you do?', '1-3 concrete steps starting with a verb.', 'steps'),
  whatItMeans: q('Why it matters', '1-2 sentences on why this matters to an ordinary reader.'),
};

export const SCAM_QUESTIONS: QuestionSet = {
  whatHappened: q('What’s the trick?', 'what the scammers do in this case, in 1-2 sentences.'),
  affectsWho: q('Am I at risk?', 'who is being targeted and how they are reached (SMS, WhatsApp, calls, apps).'),
  whatToDo: list('Stay safe', '1-3 protective steps specific to this scam.', 'steps'),
  whatItMeans: q('Why it matters', 'how much money or data is at stake, in 1 sentence.'),
};

export const QUESTION_SETS: Record<CategoryId, QuestionSet> = {
  'scams-security': {
    whatHappened: q('What happened?', 'the bug, breach or attack in 1-2 sentences: which product, how many people.'),
    affectsWho: q('Am I at risk?', 'which users or devices are affected (versions, apps, banks).'),
    whatToDo: list('Protect yourself', '1-3 steps: update, change password, turn on 2-step verification, etc.', 'steps'),
    whatItMeans: q('Why it matters', 'what could go wrong for an ordinary user if they ignore it.'),
  },
  ai: {
    whatHappened: q('What happened?', 'the AI news in 1-2 sentences: which company or tool, what it does.'),
    affectsWho: q('How does it affect you?', 'who can use it or is affected (free or paid users, in India or not yet).'),
    whatToDo: list('Try it / stay safe', '1-3 steps: where to try it (app, price in ₹ if known) or how to stay safe.', 'steps'),
    whatItMeans: q('Why it matters', 'what this changes for everyday users.'),
  },
  'phones-gadgets': {
    whatHappened: q('What’s new?', 'the device or update and its 2-3 headline features.'),
    affectsWho: q('Should I care / upgrade?', 'who should consider it and who can skip it.'),
    whatToDo: list('Price & availability in India', '1-3 short facts: price in ₹, sale date, where to buy, or "India price not announced yet".', 'bullets'),
    whatItMeans: q('Bottom line', 'a one-sentence verdict for buyers.'),
  },
  'chips-hardware': {
    whatHappened: q('What’s new?', 'the chip or hardware news in 1-2 sentences.'),
    affectsWho: q('Will I notice?', 'whether phones, laptops or PCs people buy will change, and when.'),
    whatToDo: list('Good to know', '1-2 useful facts, e.g. which devices will use it or what happens to prices.', 'bullets'),
    whatItMeans: q('Bigger picture', 'what this means for device speed, prices or India’s chip plans.'),
  },
  'startups-india': {
    whatHappened: q('What happened?', 'the company news: who, what, how much (₹ / $) and when.'),
    affectsWho: q('Who’s affected?', 'customers, employees or sellers, and how.'),
    whatToDo: list('If you use it', '1-3 steps for customers or job seekers; empty if nothing to do.', 'steps'),
    whatItMeans: q('Why it matters', 'what it says about India’s tech industry or the services you use.'),
  },
  innovations: {
    whatHappened: q('What’s the breakthrough?', 'the invention or research in 1-2 plain sentences.'),
    affectsWho: q('When could I see it?', 'how far it is from real products, if the reports say so.'),
    whatToDo: list('Cool fact', 'ONE surprising, true detail from the reports.', 'fact'),
    whatItMeans: q('What’s next', 'the next step (tests, launch, approval) if reported.'),
  },
  'money-fintech': {
    whatHappened: q('What changed?', 'the rule, feature or fee change in 1-2 sentences with dates and ₹ amounts.'),
    affectsWho: q('Does it affect my money?', 'which users, banks or apps, and how their money is affected.'),
    whatToDo: list('What to do', '1-3 concrete steps (check app, update KYC, compare charges).', 'steps'),
    whatItMeans: q('Bottom line', 'a one-sentence takeaway for your wallet.'),
  },
  privacy: {
    whatHappened: q('What happened?', 'what data is collected, shared or exposed, and by whom.'),
    affectsWho: q('Is my data at risk?', 'which users and what kind of data.'),
    whatToDo: list('Protect your privacy', '1-3 settings or steps, naming the exact setting when reported.', 'steps'),
    whatItMeans: q('Why it matters', 'why this data matters for an ordinary person.'),
  },
  telecom: {
    whatHappened: q('What changed?', 'the plan, price, network or rule change with ₹ amounts and dates.'),
    affectsWho: q('Does it hit my plan?', 'which operator’s customers or which areas.'),
    whatToDo: list('What to do', '1-3 steps: check your plan, compare, recharge before a date.', 'steps'),
    whatItMeans: q('Bottom line', 'what it means for your phone bill or network.'),
  },
  'digital-india': {
    whatHappened: q('What changed?', 'the government service or rule change, with deadlines.'),
    affectsWho: q('Who needs to act?', 'who must do something, and by when.'),
    whatToDo: list('How to do it', '1-3 steps on the official app or portal (name it).', 'steps'),
    whatItMeans: q('Why it matters', 'how it changes using government services.'),
  },
  'ev-mobility': {
    whatHappened: q('What’s new?', 'the vehicle, charging or mobility news in 1-2 sentences.'),
    affectsWho: q('Who should care?', 'buyers, owners or riders who are affected.'),
    whatToDo: list('Price, range & availability', '1-3 facts: price in ₹, range in km, launch or delivery date.', 'bullets'),
    whatItMeans: q('Bottom line', 'a one-sentence takeaway for buyers or commuters.'),
  },
  space: {
    whatHappened: q('What happened?', 'the mission or space news in 1-2 sentences: who, what, when.'),
    affectsWho: q('Why should I care?', 'how it connects to daily life (maps, weather, internet, India’s space plans).'),
    whatToDo: list('Cool fact', 'ONE surprising, true detail from the reports.', 'fact'),
    whatItMeans: q('What’s next', 'the next launch, test or milestone if reported.'),
  },
  'apps-gaming': {
    whatHappened: q('What’s new?', 'the app, game or streaming change in 1-2 sentences.'),
    affectsWho: q('Who gets it?', 'which users, platforms (Android/iPhone) and whether India is included.'),
    whatToDo: list('How to get it', '1-3 steps: update, setting to turn on, price in ₹ if known.', 'steps'),
    whatItMeans: q('Bottom line', 'a one-sentence takeaway for users.'),
  },
  'health-tech': {
    whatHappened: q('What happened?', 'the health tech news in 1-2 sentences.'),
    affectsWho: q('Who can use it?', 'which patients, devices or users, and whether it is approved.'),
    whatToDo: list('Use it safely', '1-3 steps; remind to check with a doctor when relevant.', 'steps'),
    whatItMeans: q('Why it matters', 'what it changes for patients or health care.'),
  },
  'jobs-skills': {
    whatHappened: q('What happened?', 'the hiring, layoff or skills news with numbers.'),
    affectsWho: q('Does it affect my job?', 'which roles, companies or freshers are affected.'),
    whatToDo: list('What you can do', '1-3 concrete career steps.', 'steps'),
    whatItMeans: q('Bottom line', 'a one-sentence takeaway for people in or entering tech.'),
  },
};

/** The question set for a story: scam stories get the scam set. */
export function questionsFor(category: string, isScam = false): QuestionSet {
  if (isScam) return SCAM_QUESTIONS;
  return (QUESTION_SETS as Record<string, QuestionSet>)[category] ?? GENERAL_QUESTIONS;
}

/** Compact table of every set for the Gemini system instruction. */
export function questionGuide(): string {
  const row = (name: string, s: QuestionSet) =>
    `- ${name}: whatHappened = "${s.whatHappened.label}" (${s.whatHappened.ask}); affectsWho = "${s.affectsWho.label}" (${s.affectsWho.ask}); whatToDo = "${s.whatToDo.label}" (${s.whatToDo.ask}); whatItMeans = "${s.whatItMeans.label}" (${s.whatItMeans.ask})`;
  return [...CATEGORY_IDS.map((c) => row(c, QUESTION_SETS[c])), row('scam stories (isScam true)', SCAM_QUESTIONS)].join('\n');
}

// ---------------------------------------------------------------------------------------------
// Display helpers shared by the static pages (the app mirrors them in Dart)
// ---------------------------------------------------------------------------------------------

/** Canned lines from the stories-v2 rule-based writer that must not be shown any more. */
const LEGACY_AUTO_RE = /\s*This short version was written automatically[^.]*\.(?:[^.]*details\.)?/i;
const LEGACY_FILLER_RE = /^(nothing (to do|urgent)|no one directly yet)/i;

export interface DisplayFields {
  tldr: string;
  whatHappened: string;
  affectsWho: string;
  whatToDo: string[];
  goodToKnow: string;
  whatItMeans: string;
}

/**
 * The text actually shown for a story: strips the old "written automatically" sentence and the
 * old canned fallback lines, so stories not yet rewritten for stories-v3 never show boilerplate.
 */
export function displayFields(s: {
  aiModel: string;
  tldr?: string;
  whatHappened: string;
  affectsWho: string;
  whatToDo: string[];
  goodToKnow?: string;
  whatItMeans: string;
  promptVersion?: string;
}): DisplayFields {
  const fallback = s.aiModel.startsWith('techdaily-fallback');
  const legacyFallback = fallback && s.promptVersion !== 'stories-v3';
  let whatHappened = (s.whatHappened || '').replace(LEGACY_AUTO_RE, '').trim();
  // Old fallback: "<Outlet> reported: <headline>." — a repeat of the headline, not an explanation.
  if (legacyFallback && /^[^:]{2,80} reported: /.test(whatHappened)) whatHappened = '';
  const whatToDo = (s.whatToDo || []).filter((x) => !LEGACY_FILLER_RE.test(x) && !/open the original report/i.test(x));
  return {
    tldr: (s.tldr || '').trim(),
    whatHappened,
    affectsWho: LEGACY_FILLER_RE.test(s.affectsWho || '') || (legacyFallback && /^(People|Mainly tech|Customers|Mobile and)/.test(s.affectsWho)) ? '' : (s.affectsWho || '').trim(),
    whatToDo: legacyFallback ? [] : whatToDo,
    goodToKnow: (s.goodToKnow || '').trim(),
    whatItMeans: legacyFallback ? '' : (s.whatItMeans || '').trim(),
  };
}
