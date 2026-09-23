import type { AppTheme } from '@backstage/core-plugin-api';
import {
  createUnifiedTheme,
  defaultComponentThemes,
  genPageTheme,
  UnifiedThemeProvider,
  type BackstageTypography,
  type PageTheme,
  type UnifiedTheme,
  type UnifiedThemeOptions,
} from '@backstage/theme';
import CssBaseline from '@material-ui/core/CssBaseline';
import DarkIcon from '@material-ui/icons/Brightness2';
import LightIcon from '@material-ui/icons/WbSunny';
import { PropsWithChildren } from 'react';
import { createBackstageComponents } from './backstage';
import { createMuiComponents } from './mui';
import {
  brand,
  dark,
  fontFamily,
  light,
  radius,
  type ModeTokens,
} from './tokens';

function createPalette(t: ModeTokens): UnifiedThemeOptions['palette'] {
  const { n, status } = t;
  const isDark = t.mode === 'dark';
  return {
    mode: t.mode,
    type: t.mode,
    background: { default: n.bg, paper: n.paper },
    primary: t.primary,
    secondary: t.secondary,
    text: {
      primary: n.textPrimary,
      secondary: n.textSecondary,
      disabled: n.textDisabled,
    },
    divider: n.border,
    action: {
      hover: t.hoverOverlay,
      selected: t.selectedOverlay,
      focus: t.selectedOverlay,
      disabledBackground: isDark
        ? 'rgba(255,255,255,0.08)'
        : 'rgba(20,33,58,0.08)',
    },
    error: { main: status.error },
    warning: { main: status.warning },
    success: { main: status.ok },
    info: { main: status.running },
    status,
    border: n.border,
    textContrast: n.textPrimary,
    textSubtle: n.textSecondary,
    textVerySubtle: n.textVerySubtle,
    highlight: isDark ? 'rgba(245, 179, 53, 0.18)' : brand.cream,
    errorBackground: isDark ? 'rgba(249, 112, 102, 0.14)' : '#fef3f2',
    warningBackground: isDark ? 'rgba(253, 176, 34, 0.16)' : '#fff6e5',
    infoBackground: isDark ? 'rgba(143, 179, 255, 0.14)' : '#edf2fd',
    errorText: isDark ? '#fda29b' : '#b42318',
    infoText: isDark ? brand.sky : brand.navy,
    warningText: isDark ? '#fec84b' : '#7a2e0e',
    link: t.link,
    linkHover: t.linkHover,
    gold: brand.amber,
    navigation: {
      background: t.nav.background,
      indicator: brand.amber,
      color: t.nav.color,
      selectedColor: t.nav.selectedColor,
      navItem: { hoverBackground: t.nav.hover },
      submenu: { background: t.nav.submenu },
    },
    pinSidebarButton: {
      icon: isDark ? brand.white : brand.navy,
      background: isDark ? '#1f2f4d' : brand.cream,
    },
    tabbar: { indicator: brand.amber },
    banner: {
      info: brand.blue,
      error: status.error,
      warning: status.warning,
      text: brand.white,
      link: brand.white,
      closeButtonColor: brand.white,
    },
    bursts: {
      fontColor: brand.white,
      slackChannelText: '#ddd',
      backgroundColor: { default: brand.navy },
      gradient: {
        linear: `linear-gradient(-137deg, ${brand.blue} 0%, ${brand.navy} 100%)`,
      },
    },
  };
}

/**
 * Page headers are flat and quiet — no gradient waves. Every entity kind
 * shares the same surface so the portal reads as one product; the brand shows
 * in the type label, the accent tab line and the template-card gradient.
 */
function createPageThemes(t: ModeTokens): Record<string, PageTheme> {
  const flat = genPageTheme({
    colors: [t.header.background, t.header.background],
    shape: 'none',
    options: { fontColor: t.header.fontColor },
  });
  const card = genPageTheme({
    colors: [brand.navy, brand.blue],
    shape: 'none',
    options: { fontColor: brand.white },
  });
  return {
    home: flat,
    documentation: flat,
    tool: flat,
    service: flat,
    website: flat,
    library: flat,
    other: flat,
    app: flat,
    apis: flat,
    card,
  };
}

const typography: BackstageTypography = {
  htmlFontSize: 16,
  fontFamily,
  h1: { fontSize: 32, fontWeight: 700, marginBottom: 8 },
  h2: { fontSize: 26, fontWeight: 700, marginBottom: 8 },
  h3: { fontSize: 22, fontWeight: 600, marginBottom: 6 },
  h4: { fontSize: 18, fontWeight: 600, marginBottom: 6 },
  h5: { fontSize: 16, fontWeight: 600, marginBottom: 4 },
  h6: { fontSize: 14, fontWeight: 600, marginBottom: 2 },
};

/** Build the unified (MUI v4 + v5) theme for one mode. */
export function createLdpTheme(t: ModeTokens): UnifiedTheme {
  const theme = createUnifiedTheme({
    palette: createPalette(t),
    defaultPageTheme: 'home',
    pageTheme: createPageThemes(t),
    fontFamily,
    htmlFontSize: 16,
    typography,
    components: {
      ...defaultComponentThemes,
      ...createMuiComponents(t, defaultComponentThemes),
      ...createBackstageComponents(t),
    },
  });

  // createUnifiedTheme doesn't expose `shape`; round corners globally so
  // components reading theme.shape.borderRadius pick up the same radius.
  for (const version of ['v4', 'v5'] as const) {
    const mui = theme.getTheme(version) as
      | { shape?: { borderRadius: number } }
      | undefined;
    if (mui?.shape) {
      mui.shape.borderRadius = radius.md;
    }
  }

  return theme;
}

export const ldpLightTheme = createLdpTheme(light);
export const ldpDarkTheme = createLdpTheme(dark);

// The legacy app never mounts MUI's CssBaseline, and it is the only thing that
// emits the MuiCssBaseline overrides (body defaults, scrollbars, BUI vars).
const provider =
  (theme: UnifiedTheme) =>
  ({ children }: PropsWithChildren<{}>) =>
    (
      <UnifiedThemeProvider theme={theme}>
        <CssBaseline />
        {children}
      </UnifiedThemeProvider>
    );

export const ldpThemes: AppTheme[] = [
  {
    id: 'light',
    title: 'Light',
    variant: 'light',
    icon: <LightIcon />,
    Provider: provider(ldpLightTheme),
  },
  {
    id: 'dark',
    title: 'Dark',
    variant: 'dark',
    icon: <DarkIcon />,
    Provider: provider(ldpDarkTheme),
  },
];
