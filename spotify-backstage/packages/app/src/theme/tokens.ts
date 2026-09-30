// Mirrored as --bui-* in global.css (BUI reads none of this); tokens.test.ts keeps them in step.
export const BRAND = {
  navy: '#1b2d4f',
  navyDeep: '#0b1629',
  // Text on it is navyDeep: white on amber fails AA.
  amber: '#f5b335',
  amberHover: '#f9c95f',
  amberActive: '#d99a1f',
  // Dark enough for small text on white (AA).
  amberText: '#9a6400',
  sky: '#8fb3ff',
  blue: '#4f6fb8',

  white: '#ffffff',
  mist: '#e3e8ee',
  steel: '#cbd4de',
  slate: '#5b6779',
  ink: '#14213a',
  darkSurface: '#12213b',
  darkSurfaceBorder: '#263756',
  darkText: '#eef2f8',
  darkTextSecondary: '#a6b3c8',

  radius: 0,
} as const;

export const STATUS = {
  warning: '#f79009',
  error: '#d92d20',
  errorTextDark: '#fda29b',
} as const;

export const hexAlpha = (hex: string, opacity: number) => {
  const n = parseInt(hex.replace('#', ''), 16);
  return `rgba(${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255}, ${opacity})`;
};

export const amberAlpha = (opacity: number) => hexAlpha(BRAND.amber, opacity);

// Loaded from Google Fonts in index.html.
export const fontFamily =
  '"IBM Plex Sans", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif';

export const monoFontFamily =
  '"JetBrains Mono", ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", monospace';
