import { brand, fontFamily, monoFontFamily, type ModeTokens } from './tokens';

/**
 * `@backstage/ui` (BUI) design tokens, emitted through MuiCssBaseline. BUI
 * components are styled with CSS custom properties rather than MUI, so the
 * same brand tokens are mapped onto its `--bui-*` variables here.
 * UnifiedThemeProvider stamps `data-theme-mode` on <body>; the element +
 * attribute selector out-specifies BUI's own `[data-theme-mode]` rules.
 */
export function createBuiGlobals(t: ModeTokens): Record<string, any> {
  const { n, status } = t;
  const isDark = t.mode === 'dark';
  const sel = `body[data-theme-mode='${t.mode}']`;
  const info = isDark ? brand.sky : brand.blue;

  const subdued = (hex: string, a: number) =>
    `${hex}${Math.round(a * 255)
      .toString(16)
      .padStart(2, '0')}`;

  return {
    [sel]: {
      '--bui-font-regular': fontFamily,
      '--bui-font-monospace': monoFontFamily,
      '--bui-font-weight-bold': 600,
      '--bui-radius-2': '0.5rem',
      '--bui-radius-3': '0.5rem',
      '--bui-radius-4': '0.75rem',
      '--bui-ring': brand.amber,

      '--bui-gray-1': isDark ? n.bg : n.paperMuted,
      '--bui-gray-2': isDark ? n.paper : n.bg,
      '--bui-gray-3': isDark ? n.paperMuted : n.border,
      '--bui-gray-4': isDark ? n.border : n.borderStrong,
      '--bui-gray-5': isDark ? n.borderStrong : n.textDisabled,
      '--bui-gray-6': isDark ? n.textDisabled : n.textSecondary,
      '--bui-gray-7': isDark ? '#8d9bb3' : '#44516a',
      '--bui-gray-8': isDark ? n.textSecondary : '#2f3d58',
      '--bui-gray-9': isDark ? '#c8d1e0' : '#1f2c46',
      '--bui-gray-10': isDark ? '#e1e7f0' : n.textPrimary,
      '--bui-gray-11': isDark ? n.textPrimary : '#0b1629',

      '--bui-bg-app': n.bg,
      '--bui-bg-neutral-1': n.paper,
      '--bui-bg-neutral-2': n.paperMuted,
      '--bui-bg-neutral-3': n.paper,
      '--bui-bg-neutral-4': n.paperMuted,

      '--bui-fg-primary': n.textPrimary,
      '--bui-fg-secondary': n.textSecondary,
      '--bui-fg-disabled': n.textDisabled,
      '--bui-fg-positive': status.ok,
      '--bui-fg-negative': status.error,
      '--bui-fg-warning': status.warning,
      '--bui-fg-announcement': t.link,

      '--bui-border-1': n.border,
      '--bui-border-2': n.borderStrong,

      '--bui-accent-bg': t.primary.main,
      '--bui-accent-bg-hover': t.primary.dark,
      '--bui-accent-bg-disabled': isDark ? '#5c4a25' : '#9fa9bf',
      '--bui-accent-fg': t.primary.contrastText,
      '--bui-accent-fg-disabled': isDark ? '#8a7a55' : n.border,

      '--bui-announcement-bg': info,
      '--bui-announcement-bg-hover': isDark ? '#a9c4ff' : brand.navyLight,
      '--bui-announcement-bg-disabled': info,
      '--bui-announcement-bg-subdued': subdued(info, isDark ? 0.16 : 0.12),
      '--bui-announcement-bg-subdued-hover': subdued(info, isDark ? 0.24 : 0.2),
      '--bui-announcement-bg-subdued-disabled': subdued(info, 0.1),
      '--bui-announcement-border': info,
      '--bui-announcement-fg': isDark ? brand.navyDeep : brand.white,
      '--bui-announcement-fg-disabled': isDark ? '#5b6d8f' : '#c7d6f5',
      '--bui-announcement-fg-subdued': isDark ? brand.sky : brand.navy,
      '--bui-announcement-fg-subdued-disabled': isDark ? '#4f5f80' : '#7f93b8',

      '--bui-warning-bg': status.warning,
      '--bui-warning-bg-hover': isDark ? '#fec84b' : '#fdb022',
      '--bui-warning-bg-subdued': isDark
        ? subdued(status.warning, 0.16)
        : '#fff6e5',
      '--bui-warning-bg-subdued-hover': isDark
        ? subdued(status.warning, 0.24)
        : '#ffeccc',
      '--bui-warning-border': status.warning,
      '--bui-warning-fg': '#1a1a1a',
      '--bui-warning-fg-subdued': isDark ? '#fec84b' : '#7a2e0e',

      '--bui-negative-bg': status.error,
      '--bui-negative-bg-hover': isDark ? '#fda29b' : '#f04438',
      '--bui-negative-bg-subdued': isDark
        ? subdued(status.error, 0.14)
        : '#fef3f2',
      '--bui-negative-bg-subdued-hover': isDark
        ? subdued(status.error, 0.22)
        : '#fee4e2',
      '--bui-negative-border': isDark ? status.error : '#f04438',
      '--bui-negative-fg': isDark ? '#1a0505' : brand.white,
      '--bui-negative-fg-subdued': isDark ? '#fda29b' : '#b42318',

      '--bui-positive-bg': status.ok,
      '--bui-positive-bg-hover': isDark ? '#6ce9a6' : '#32d583',
      '--bui-positive-bg-subdued': isDark
        ? subdued(status.ok, 0.14)
        : '#ecfdf3',
      '--bui-positive-bg-subdued-hover': isDark
        ? subdued(status.ok, 0.22)
        : '#d1fadf',
      '--bui-positive-border': status.ok,
      '--bui-positive-fg': '#052e16',
      '--bui-positive-fg-subdued': isDark ? '#6ce9a6' : '#027a48',

      // Deprecated in BUI's token set, but primary Button/ButtonLink still
      // read them; without these the primary BUI button is Backstage blue.
      '--bui-bg-solid': t.primary.main,
      '--bui-bg-solid-hover': t.primary.dark,
      '--bui-bg-solid-pressed': isDark ? brand.amberDark : brand.navyDeep,
      '--bui-bg-solid-disabled': isDark ? '#5c4a25' : '#9fa9bf',
      '--bui-fg-solid': t.primary.contrastText,
      '--bui-fg-solid-disabled': isDark ? '#8a7a55' : n.border,
      '--bui-scrollbar': isDark
        ? 'rgba(255,255,255,0.06)'
        : 'rgba(20,33,58,0.08)',
      '--bui-scrollbar-thumb': isDark ? n.borderStrong : n.textVerySubtle,
    },
    // BUI tables: match the MUI table header treatment so both read as one.
    [`${sel} .bui-TableHead`]: {
      fontSize: 12,
      fontWeight: 600,
      letterSpacing: '0.06em',
      textTransform: 'uppercase',
      color: 'var(--bui-fg-secondary)',
    },
  };
}
