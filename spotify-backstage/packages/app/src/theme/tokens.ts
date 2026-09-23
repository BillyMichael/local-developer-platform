/**
 * Local Developer Platform brand tokens.
 *
 * Same palette as the docs site (docs/stylesheets/home.css): ink navy as the
 * anchor, amber phosphor as the signature accent, the two logo blues as
 * supporting tints. Neutrals are derived to keep WCAG AA contrast for text.
 */
export const brand = {
  navy: '#1b2d4f',
  navyLight: '#2d4270',
  navyDark: '#12213b',
  navyDeep: '#0b1629',
  amber: '#f5b335',
  amberLight: '#f9c95f',
  amberDark: '#d99a1f',
  /** Accessible amber for text/links on white (AA) — the docs light accent. */
  amberText: '#9a6400',
  /** Logo blues. */
  sky: '#8fb3ff',
  blue: '#4f6fb8',
  /** Tints. */
  cream: '#fdf4e0',
  amberTint: 'rgba(245, 179, 53, 0.14)',
  white: '#ffffff',
} as const;

export const neutralsLight = {
  bg: '#f5f7fa',
  paper: '#ffffff',
  paperMuted: '#f8fafc',
  border: '#e3e8ee',
  borderStrong: '#cbd4de',
  textPrimary: '#14213a',
  textSecondary: '#5b6779',
  textDisabled: '#98a2b3',
  textVerySubtle: '#c9d2db',
} as const;

export const neutralsDark = {
  bg: '#0d1626',
  paper: '#142038',
  paperMuted: '#1a2a47',
  border: '#263756',
  borderStrong: '#354a70',
  textPrimary: '#eef2f8',
  textSecondary: '#a6b3c8',
  textDisabled: '#6b7a94',
  textVerySubtle: '#3a4c6b',
} as const;

export const statusLight = {
  ok: '#12b76a',
  warning: '#f79009',
  error: '#d92d20',
  running: '#4f6fb8',
  pending: '#eab308',
  aborted: '#667085',
} as const;

export const statusDark = {
  ok: '#32d583',
  warning: '#fdb022',
  error: '#f97066',
  running: '#8fb3ff',
  pending: '#fac515',
  aborted: '#98a2b3',
} as const;

/** Same faces as the docs site; loaded from Google Fonts in index.html. */
export const fontFamily =
  '"IBM Plex Sans", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif';

export const monoFontFamily =
  '"JetBrains Mono", ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", monospace';

export const radius = {
  sm: 6,
  md: 8,
  lg: 12,
  xl: 16,
  pill: 999,
} as const;

export const shadow = {
  light: {
    xs: '0 1px 2px rgba(20, 33, 58, 0.05)',
    sm: '0 1px 3px rgba(20, 33, 58, 0.08), 0 1px 2px rgba(20, 33, 58, 0.04)',
    md: '0 4px 12px rgba(20, 33, 58, 0.08), 0 1px 3px rgba(20, 33, 58, 0.05)',
    lg: '0 12px 32px rgba(20, 33, 58, 0.14), 0 2px 6px rgba(20, 33, 58, 0.06)',
    ring: '0 0 0 3px rgba(245, 179, 53, 0.35)',
  },
  dark: {
    xs: '0 1px 2px rgba(0, 0, 0, 0.3)',
    sm: '0 1px 3px rgba(0, 0, 0, 0.4), 0 1px 2px rgba(0, 0, 0, 0.3)',
    md: '0 4px 12px rgba(0, 0, 0, 0.45), 0 1px 3px rgba(0, 0, 0, 0.3)',
    lg: '0 12px 32px rgba(0, 0, 0, 0.55), 0 2px 6px rgba(0, 0, 0, 0.35)',
    ring: '0 0 0 3px rgba(245, 179, 53, 0.4)',
  },
} as const;

/** Shared hover behaviour for clickable cards. */
export const interactive = {
  transition:
    'transform 120ms ease, box-shadow 120ms ease, border-color 120ms ease',
  transform: 'translateY(-2px)',
} as const;

export type Mode = 'light' | 'dark';

export interface ModeTokens {
  mode: Mode;
  n: typeof neutralsLight | typeof neutralsDark;
  status: typeof statusLight | typeof statusDark;
  shadows: typeof shadow.light | typeof shadow.dark;
  /** Primary actions (buttons, selected tabs). */
  primary: { main: string; light: string; dark: string; contrastText: string };
  /** Accent — amber in both modes. */
  secondary: {
    main: string;
    light: string;
    dark: string;
    contrastText: string;
  };
  link: string;
  linkHover: string;
  nav: {
    background: string;
    backgroundEnd: string;
    color: string;
    selectedColor: string;
    hover: string;
    selectedBackground: string;
    submenu: string;
    divider: string;
  };
  header: { background: string; fontColor: string; type: string };
  focusRing: string;
  hoverOverlay: string;
  selectedOverlay: string;
  chipBg: string;
}

export const light: ModeTokens = {
  mode: 'light',
  n: neutralsLight,
  status: statusLight,
  shadows: shadow.light,
  primary: {
    main: brand.navy,
    light: brand.navyLight,
    dark: brand.navyDark,
    contrastText: brand.white,
  },
  secondary: {
    main: brand.amber,
    light: brand.amberLight,
    dark: brand.amberDark,
    contrastText: brand.navyDeep,
  },
  link: brand.amberText,
  linkHover: brand.navy,
  nav: {
    background: brand.navy,
    backgroundEnd: brand.navyDark,
    color: 'rgba(255, 255, 255, 0.74)',
    selectedColor: brand.white,
    hover: 'rgba(255, 255, 255, 0.08)',
    selectedBackground: 'rgba(245, 179, 53, 0.18)',
    submenu: brand.navyDark,
    divider: 'rgba(255, 255, 255, 0.10)',
  },
  header: {
    background: neutralsLight.paper,
    fontColor: neutralsLight.textPrimary,
    type: brand.amberText,
  },
  focusRing: shadow.light.ring,
  hoverOverlay: 'rgba(27, 45, 79, 0.05)',
  selectedOverlay: 'rgba(245, 179, 53, 0.16)',
  chipBg: '#eef2f6',
};

export const dark: ModeTokens = {
  mode: 'dark',
  n: neutralsDark,
  status: statusDark,
  shadows: shadow.dark,
  primary: {
    main: brand.amber,
    light: brand.amberLight,
    dark: brand.amberDark,
    contrastText: brand.navyDeep,
  },
  secondary: {
    main: brand.amberLight,
    light: '#fbd98a',
    dark: brand.amber,
    contrastText: brand.navyDeep,
  },
  link: brand.amber,
  linkHover: brand.amberLight,
  nav: {
    background: brand.navyDeep,
    backgroundEnd: '#060d1a',
    color: 'rgba(255, 255, 255, 0.68)',
    selectedColor: brand.white,
    hover: 'rgba(255, 255, 255, 0.06)',
    selectedBackground: 'rgba(245, 179, 53, 0.20)',
    submenu: neutralsDark.paper,
    divider: 'rgba(255, 255, 255, 0.08)',
  },
  header: {
    background: neutralsDark.paper,
    fontColor: neutralsDark.textPrimary,
    type: brand.amber,
  },
  focusRing: shadow.dark.ring,
  hoverOverlay: 'rgba(255, 255, 255, 0.06)',
  selectedOverlay: 'rgba(245, 179, 53, 0.16)',
  chipBg: '#1f2f4d',
};
