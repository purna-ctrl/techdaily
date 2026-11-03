/**
 * TechDaily v3 design tokens shared by the static pages (and mirrored in the Flutter app:
 * lib/core/constants/story_categories.dart). Every category has a vivid colour, a lighter tint for
 * coloured text on dark surfaces (>= 6:1 on the tinted card surface) and a 24x24 stroke icon.
 * Solid chips use the colour as background with ink #0B0B0F text (>= 4.6:1 for every colour).
 */
export interface CategoryStyle {
  color: string;
  tint: string;
  /** SVG path data for a 24x24, stroke-width 2 icon. */
  icon: string;
}

export const CATEGORY_STYLE: Record<string, CategoryStyle> = {
  'top-stories': {
    color: '#FF5A1F',
    tint: '#FF8255',
    icon: 'M12 3c1 3.5 5 5.5 5 10a5 5 0 0 1-10 0c0-2.5 1.5-4 2.5-5 .3 1.6 1 2.6 2 3 0-3 .5-5.5.5-8z',
  },
  'scams-security': { color: '#FF3B4E', tint: '#FF7683', icon: 'M12 3l8 3v6c0 4.5-3.4 8.2-8 9-4.6-.8-8-4.5-8-9V6l8-3z M12 8v5 M12 16.5v.01' },
  ai: { color: '#8B5CF6', tint: '#B090F9', icon: 'M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z M19 15l.8 2.2L22 18l-2.2.8L19 21l-.8-2.2L16 18l2.2-.8z' },
  'phones-gadgets': { color: '#3B82F6', tint: '#72A5F9', icon: 'M8 2h8a2 2 0 0 1 2 2v16a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2z M11 18h2' },
  'chips-hardware': {
    color: '#22C55E',
    tint: '#4ADE80',
    icon: 'M7 7h10v10H7z M10 10h4v4h-4z M9 3v4 M15 3v4 M9 17v4 M15 17v4 M3 9h4 M3 15h4 M17 9h4 M17 15h4',
  },
  'startups-india': { color: '#FF9933', tint: '#FFB061', icon: 'M3 17l6-6 4 4 8-8 M15 7h6v6' },
  innovations: { color: '#06B6D4', tint: '#22D3EE', icon: 'M9 3h6 M10 3v6l-5.5 9.5A1.7 1.7 0 0 0 6 21h12a1.7 1.7 0 0 0 1.5-2.5L14 9V3 M7 15h10' },
  'money-fintech': { color: '#EAB308', tint: '#FACC15', icon: 'M7 4h11 M7 8.5h11 M7 4h3.5a4.5 4.5 0 0 1 0 9H7l7.5 7.5' },
  privacy: { color: '#14B8A6', tint: '#2DD4BF', icon: 'M6 11h12v10H6z M8 11V7a4 4 0 0 1 8 0v4 M12 15v2' },
  telecom: {
    color: '#E879F9',
    tint: '#F0ABFC',
    icon: 'M12 11v10 M9 21h6 M12 11v.01 M8.5 7.5a5 5 0 0 0 0 7 M15.5 7.5a5 5 0 0 1 0 7 M5.6 4.6a9 9 0 0 0 0 12.8 M18.4 4.6a9 9 0 0 1 0 12.8',
  },
  'digital-india': {
    color: '#10B981',
    tint: '#6EE7B7',
    icon: 'M12 11v3a8 8 0 0 1-1.5 4.5 M8 11a4 4 0 0 1 8 0v1.5a12 12 0 0 1-1 4.5 M5 10a7 7 0 0 1 14 0v2 M8.5 14.5a10 10 0 0 1-2 4',
  },
  'ev-mobility': { color: '#A3E635', tint: '#D9F99D', icon: 'M13 2L5 14h6l-1 8 8-12h-6z' },
  space: {
    color: '#38BDF8',
    tint: '#7DD3FC',
    icon: 'M12 2c3 2.5 4.5 6 4.5 10l-2 4h-5l-2-4C7.5 8 9 4.5 12 2z M12 9.5v.01 M9.5 16l-2.5 3 M14.5 16l2.5 3 M12 17v4',
  },
  'apps-gaming': {
    color: '#F472B6',
    tint: '#F9A8D4',
    icon: 'M6 8h12a4 4 0 0 1 4 4v1a4 4 0 0 1-7 2.6L14 15h-4l-1 .6A4 4 0 0 1 2 13v-1a4 4 0 0 1 4-4z M7 10.5v3 M5.5 12h3 M16 11h.01 M18 13h.01',
  },
  'health-tech': { color: '#FB7185', tint: '#FDA4AF', icon: 'M19.5 13.5L12 21l-7.5-7.5A4.8 4.8 0 0 1 12 6.5a4.8 4.8 0 0 1 7.5 7z M3 12h4l2-3 3 6 2-3h7' },
  'jobs-skills': { color: '#818CF8', tint: '#A5B4FC', icon: 'M4 7h16v13H4z M9 7V4h6v3 M4 12h16 M12 11v2' },
};

export function catStyle(id: string): CategoryStyle {
  return CATEGORY_STYLE[id] ?? CATEGORY_STYLE.innovations;
}

/** Inline SVG icon (decorative). */
export function iconSvg(path: string, size = 16, extra = ''): string {
  return `<svg class="ic" width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false"${extra}><path d="${path}"/></svg>`;
}

export const UI_ICONS = {
  news: 'M4 5h13v14H6a2 2 0 0 1-2-2z M17 9h3v8a2 2 0 0 1-2 2 M8 9h5 M8 13h5',
  person: 'M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8z M4 21a8 8 0 0 1 16 0',
  check: 'M5 12.5l4.5 4.5L19 7.5',
  bulb: 'M9 18h6 M10 21h4 M12 3a6 6 0 0 0-3.5 10.9c.6.5 1 1.2 1 2.1h5c0-.9.4-1.6 1-2.1A6 6 0 0 0 12 3z',
  alert: 'M12 3l10 18H2z M12 10v4 M12 17.5v.01',
  hook: 'M12 3v9a4 4 0 1 1-4-4',
  phone: 'M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2z',
  link: 'M10 14a5 5 0 0 0 7 0l3-3a5 5 0 0 0-7-7l-1 1 M14 10a5 5 0 0 0-7 0l-3 3a5 5 0 0 0 7 7l1-1',
  share: 'M12 3v12 M7 8l5-5 5 5 M5 14v5a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-5',
  shield: 'M12 3l8 3v6c0 4.5-3.4 8.2-8 9-4.6-.8-8-4.5-8-9V6l8-3z M9 12l2 2 4-4',
  arrow: 'M5 12h14 M13 6l6 6-6 6',
  spark: 'M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z M19 16l.8 2.2L22 19l-2.2.8L19 22l-.8-2.2L16 19l2.2-.8z',
  tag: 'M3 12V4h8l10 10-8 8z M7.5 8.5v.01',
  ask: 'M4 5h16v11H9l-5 4z M9.5 9a2.5 2.5 0 1 1 3.5 2.3c-.6.3-1 .8-1 1.4 M12 14.5v.01',
  next: 'M5 12h11 M12 7l5 5-5 5 M20 5v14',
  info: 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18z M12 11v5 M12 7.5v.01',
  whatsapp:
    'M3.5 20.5l1.3-4.6A8.5 8.5 0 1 1 8.2 19.3z M9 8.5c0 3.5 3 6.5 6.5 6.5l1-1.5-2-1-1 1c-1.2-.5-2.5-1.8-3-3l1-1-1-2z',
};
