import {
  createUnifiedTheme,
  palettes,
  type BackstageTypography,
} from '@backstage/theme';
import {
  amberAlpha,
  BRAND,
  fontFamily,
  hexAlpha,
  monoFontFamily,
  STATUS,
} from './tokens';

type Mode = 'light' | 'dark';

// Not genPageTheme: its wave shapes paint a swoosh whatever the colours.
const flatPageTheme = {
  colors: [BRAND.navyDeep, BRAND.navyDeep],
  shape: 'none',
  backgroundImage: `linear-gradient(90deg, ${BRAND.navyDeep}, ${BRAND.navyDeep})`,
  fontColor: BRAND.white,
};

const pageTheme = Object.fromEntries(
  [
    'home',
    'documentation',
    'tool',
    'service',
    'website',
    'library',
    'other',
    'app',
    'apis',
  ].map(id => [id, flatPageTheme]),
);

const typography: BackstageTypography = {
  htmlFontSize: 16,
  fontFamily,
  h1: { fontSize: 40, fontWeight: 300, marginBottom: 16 },
  h2: { fontSize: 32, fontWeight: 300, marginBottom: 12 },
  h3: { fontSize: 26, fontWeight: 700, marginBottom: 8 },
  h4: { fontSize: 22, fontWeight: 700, marginBottom: 8 },
  h5: { fontSize: 18, fontWeight: 700, marginBottom: 6 },
  h6: { fontSize: 16, fontWeight: 700, marginBottom: 4 },
};

const components = (mode: Mode) => {
  const light = mode === 'light';
  const rule = light ? BRAND.mist : BRAND.darkSurfaceBorder;
  const fg = light ? BRAND.navy : BRAND.white;
  const hover = light ? 'rgba(27,45,79,0.06)' : 'rgba(255,255,255,0.08)';

  return {
    MuiCard: {
      styleOverrides: {
        root: {
          borderRadius: BRAND.radius,
          boxShadow: 'none',
          border: `1px solid ${rule}`,
          transition:
            'border-color 0.2s ease, box-shadow 0.3s ease, transform 0.2s ease',
        },
      },
    },
    // Root-only overrides lose to MUI's `rounded` / `elevationN` defaults.
    MuiPaper: {
      styleOverrides: {
        root: { borderRadius: BRAND.radius, boxShadow: 'none' },
        rounded: { borderRadius: BRAND.radius },
        elevation1: { boxShadow: 'none' },
        elevation2: { boxShadow: 'none' },
        elevation3: { boxShadow: 'none' },
        elevation4: { boxShadow: 'none' },
      },
    },
    MuiButton: {
      styleOverrides: {
        root: { borderRadius: BRAND.radius, textTransform: 'none' as const },
        containedPrimary: {
          backgroundColor: BRAND.amber,
          color: BRAND.navyDeep,
          fontWeight: 700,
          '&:hover': { backgroundColor: BRAND.amberHover },
          '&:active': { backgroundColor: BRAND.amberActive },
        },
        textPrimary: {
          fontWeight: 600,
          color: fg,
          '&:hover': { backgroundColor: hover },
        },
        outlinedPrimary: {
          fontWeight: 600,
          color: fg,
          borderColor: light ? BRAND.steel : BRAND.darkSurfaceBorder,
          '&:hover': { borderColor: fg, backgroundColor: hover },
        },
      },
    },
    // MUI v4 uses Mui-focusVisible, and its outline: 0 beats global.css's :focus-visible.
    MuiButtonBase: {
      styleOverrides: {
        root: {
          '&.Mui-focusVisible': {
            outline: `2px solid ${BRAND.amber}`,
            outlineOffset: 2,
          },
        },
      },
    },
    MuiChip: {
      styleOverrides: { root: { borderRadius: BRAND.radius, fontWeight: 500 } },
    },
    MuiOutlinedInput: {
      styleOverrides: { root: { borderRadius: BRAND.radius } },
    },
    MuiTableRow: {
      styleOverrides: { root: { '&:hover': { backgroundColor: hover } } },
    },
    MuiTab: {
      styleOverrides: {
        root: {
          textTransform: 'none' as const,
          fontWeight: 600,
          minWidth: 100,
        },
      },
    },
    MuiTypography: {
      styleOverrides: {
        h1: { letterSpacing: '-0.01em' },
        h2: { letterSpacing: '-0.005em' },
      },
    },
    MuiAlert: {
      styleOverrides: {
        root: { borderRadius: BRAND.radius, alignItems: 'center' },
        standardError: {
          backgroundColor: hexAlpha(STATUS.error, light ? 0.1 : 0.2),
          color: light ? STATUS.error : STATUS.errorTextDark,
          '& .MuiAlert-icon': {
            color: light ? STATUS.error : STATUS.errorTextDark,
          },
        },
        standardWarning: {
          backgroundColor: amberAlpha(light ? 0.18 : 0.2),
          color: light ? '#7a4f00' : BRAND.amberHover,
          '& .MuiAlert-icon': { color: light ? '#7a4f00' : BRAND.amber },
        },
        standardInfo: {
          backgroundColor: hexAlpha(BRAND.blue, light ? 0.12 : 0.24),
          color: light ? BRAND.navy : BRAND.sky,
          '& .MuiAlert-icon': { color: light ? BRAND.blue : BRAND.sky },
        },
      },
    } as any,
    // Classic <Header>, still rendered by some plugin pages.
    BackstageHeader: {
      styleOverrides: {
        header: {
          backgroundColor: BRAND.navyDeep,
          boxShadow: 'none',
          borderBottom: `1px solid ${amberAlpha(0.35)}`,
        },
        title: { fontWeight: 700, color: BRAND.white },
        subtitle: { color: 'rgba(255, 255, 255, 0.7)' },
      },
    },
    // HeaderTabs sets its own uppercase transform on a local class.
    BackstageHeaderTabs: {
      styleOverrides: {
        defaultTab: { textTransform: 'none' as const, fontWeight: 600 },
      },
    } as any,
    BackstageMarkdownContent: {
      styleOverrides: {
        markdown: {
          '& code': { fontFamily: monoFontFamily, fontSize: '0.9em' },
        },
      },
    } as any,
    CatalogReactUserListPicker: {
      styleOverrides: {
        root: { backgroundColor: 'transparent', padding: '8px 0' },
        title: { margin: '8px 12px 4px 12px' },
        groupWrapper: { margin: '4px 8px 8px 8px' },
      },
    },
  };
};

const navigation = {
  background: BRAND.navyDeep,
  indicator: BRAND.amber,
  color: 'rgba(255, 255, 255, 0.72)',
  selectedColor: BRAND.white,
  navItem: { hoverBackground: 'rgba(255, 255, 255, 0.08)' },
  submenu: { background: BRAND.navy },
};

export const ldpLightTheme = createUnifiedTheme({
  palette: {
    ...palettes.light,
    // Bright amber fails AA for small text on white.
    primary: { main: BRAND.amberText },
    secondary: { main: BRAND.blue },
    link: BRAND.navy,
    linkHover: BRAND.blue,
    action: { selected: amberAlpha(0.14) } as any,
    background: { default: BRAND.mist, paper: BRAND.white },
    // Plugins build their rules from `divider`; unset it's translucent black.
    divider: BRAND.mist,
    text: { primary: BRAND.ink, secondary: BRAND.slate } as any,
    errorBackground: STATUS.error,
    warningBackground: STATUS.warning,
    infoBackground: BRAND.blue,
    navigation,
  },
  defaultPageTheme: 'home',
  fontFamily,
  typography,
  pageTheme,
  components: components('light'),
});

export const ldpDarkTheme = createUnifiedTheme({
  palette: {
    ...palettes.dark,
    primary: { main: BRAND.amber },
    secondary: { main: BRAND.sky },
    link: BRAND.sky,
    linkHover: BRAND.white,
    action: { selected: amberAlpha(0.18) } as any,
    background: { default: BRAND.navyDeep, paper: BRAND.darkSurface },
    divider: BRAND.darkSurfaceBorder,
    text: {
      primary: BRAND.darkText,
      secondary: BRAND.darkTextSecondary,
    } as any,
    errorBackground: hexAlpha(STATUS.error, 0.35),
    warningBackground: amberAlpha(0.35),
    infoBackground: hexAlpha(BRAND.blue, 0.45),
    navigation,
  },
  defaultPageTheme: 'home',
  fontFamily,
  typography,
  pageTheme,
  components: components('dark'),
});
