/**
 * Local Developer Platform brand tokens.
 *
 * Same palette as the docs site (docs/stylesheets/home.css): ink navy as the
 * anchor, amber phosphor as the one accent, the two logo blues as supporting
 * tints. The layout language follows Agora — square corners, flat surfaces,
 * borders over shadows, and the accent reserved for the one thing that
 * matters on a view.
 *
 * BUI (`@backstage/ui`) reads none of this; its `--bui-*` variables in
 * global.css carry the same values and tokens.test.ts keeps the two in step.
 */
export const BRAND = {
  /** The chrome: sidebar, page header bar, hero and sign-in backdrop. */
  navy: '#1b2d4f',
  navyDeep: '#0b1629',
  navyLight: '#2d4270',
  /** The one accent. Text on it is navyDeep — white on amber fails AA. */
  amber: '#f5b335',
  amberHover: '#f9c95f',
  amberActive: '#d99a1f',
  /** Amber dark enough for small text and links on white (AA). */
  amberText: '#9a6400',
  /** Logo blues. */
  sky: '#8fb3ff',
  blue: '#4f6fb8',

  white: '#ffffff',
  /** Light mode: page and rules share one cool grey; cards are white. */
  mist: '#e3e8ee',
  steel: '#cbd4de',
  slate: '#5b6779',
  ink: '#14213a',
  /** Dark mode: navy page, a raised navy surface, a lighter navy rule. */
  darkSurface: '#12213b',
  darkSurfaceBorder: '#263756',
  darkText: '#eef2f8',
  darkTextSecondary: '#a6b3c8',

  /** Square-cornered, as Agora. */
  radius: 0,
} as const;

export const STATUS = {
  ok: '#12b76a',
  warning: '#f79009',
  error: '#d92d20',
  errorTextDark: '#fda29b',
  info: BRAND.blue,
} as const;

export const hexAlpha = (hex: string, opacity: number) => {
  const n = parseInt(hex.replace('#', ''), 16);
  return `rgba(${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255}, ${opacity})`;
};

export const amberAlpha = (opacity: number) => hexAlpha(BRAND.amber, opacity);

/** Same faces as the docs site; loaded from Google Fonts in index.html. */
export const fontFamily =
  '"IBM Plex Sans", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif';

export const monoFontFamily =
  '"JetBrains Mono", ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", monospace';
