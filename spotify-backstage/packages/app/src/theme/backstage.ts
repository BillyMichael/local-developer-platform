/* eslint-disable @typescript-eslint/no-explicit-any */
import { brand, monoFontFamily, radius, type ModeTokens } from './tokens';

/**
 * Overrides for Backstage's own components (`Backstage*` class names from
 * @backstage/core-components and plugins): page header, tabs, cards, tables,
 * and the sidebar rail.
 */
export function createBackstageComponents(t: ModeTokens): Record<string, any> {
  const { n } = t;
  const isDark = t.mode === 'dark';
  const border = `1px solid ${n.border}`;
  const pickerBox = {
    root: {
      backgroundColor: n.paper,
      border,
      borderRadius: radius.lg,
      boxShadow: 'none',
      margin: '8px 0 16px',
    },
    title: {
      margin: '12px 0 4px 12px',
      fontSize: 11,
      fontWeight: 600,
      letterSpacing: '0.08em',
      color: n.textSecondary,
    },
    menuItem: { minHeight: 40, borderRadius: radius.md },
    groupWrapper: { margin: '4px 8px 12px' },
  };

  return {
    /* Layout                                                             */
    BackstagePage: {
      styleOverrides: { root: { backgroundColor: n.bg } },
    },
    // Flat, quiet page header: the page theme paints it in the paper colour,
    // the brand shows in the type label and the accent tab indicator.
    BackstageHeader: {
      styleOverrides: {
        header: {
          padding: '28px 32px 22px',
          boxShadow: 'none',
          borderBottom: border,
        },
        title: {
          fontSize: 28,
          fontWeight: 700,
          letterSpacing: '-0.02em',
          lineHeight: 1.2,
        },
        subtitle: {
          opacity: 0.72,
          fontSize: 14,
          fontWeight: 400,
          marginTop: 6,
        },
        type: {
          color: t.header.type,
          opacity: 1,
          fontSize: 11,
          fontWeight: 700,
          letterSpacing: '0.10em',
          marginBottom: 8,
        },
        breadcrumb: { fontSize: 13, '& a': { color: t.link } },
      },
    },
    BackstageHeaderLabel: {
      styleOverrides: {
        root: { textAlign: 'left', marginLeft: 24 },
        label: {
          fontSize: 11,
          fontWeight: 600,
          letterSpacing: '0.08em',
          textTransform: 'uppercase',
          color: n.textSecondary,
          opacity: 1,
        },
        value: {
          fontSize: 14,
          fontWeight: 500,
          color: n.textPrimary,
          marginTop: 2,
        },
      },
    },
    BackstageHeaderTabs: {
      styleOverrides: {
        tabsWrapper: {
          paddingLeft: 24,
          paddingRight: 24,
          backgroundColor: 'transparent',
          borderBottom: border,
        },
        defaultTab: {
          textTransform: 'none',
          fontSize: 14,
          fontWeight: 500,
          letterSpacing: 0,
          lineHeight: 1.3,
          padding: '14px 16px',
          minHeight: 48,
          color: n.textSecondary,
        },
        selected: { color: n.textPrimary, fontWeight: 600 },
        tabRoot: {
          '&:hover': { backgroundColor: 'transparent', color: n.textPrimary },
        },
      },
    },
    BackstageContent: {
      styleOverrides: {
        root: {
          paddingTop: 28,
          paddingBottom: 40,
          '@media (min-width: 600px)': { paddingLeft: 32, paddingRight: 32 },
        },
      },
    },
    BackstageContentHeader: {
      styleOverrides: {
        title: { fontSize: 20, fontWeight: 600, letterSpacing: '-0.01em' },
      },
    },
    BackstageInfoCard: {
      styleOverrides: {
        header: { padding: '18px 20px 10px' },
        headerTitle: {
          fontSize: 16,
          fontWeight: 600,
          letterSpacing: '-0.01em',
          lineHeight: 1.35,
        },
        headerSubheader: {
          paddingTop: 2,
          fontSize: 13,
          color: n.textSecondary,
        },
      },
    },
    BackstageItemCardHeader: {
      styleOverrides: {
        root: {
          padding: '20px 20px 22px',
          backgroundPosition: 'center',
          backgroundSize: 'cover',
          '& h3': {
            fontSize: 11,
            fontWeight: 600,
            letterSpacing: '0.08em',
            textTransform: 'uppercase',
            opacity: 0.8,
            marginBottom: 6,
          },
          '& h4': { fontSize: 18, fontWeight: 600, letterSpacing: '-0.01em' },
        },
      },
    },
    BackstageItemCardGrid: {
      styleOverrides: { root: { gridGap: 20 } },
    },
    BackstageTableToolbar: {
      styleOverrides: {
        root: { padding: '18px 16px 14px 20px' },
        title: {
          '& > h6': { fontWeight: 600, fontSize: 16, letterSpacing: '-0.01em' },
        },
      },
    },
    BackstageTableHeader: {
      styleOverrides: { header: { borderBottom: border } },
    },
    BackstageSelectInputBase: {
      styleOverrides: {
        input: {
          borderRadius: radius.md,
          backgroundColor: n.paper,
          border,
          fontSize: 14,
          padding: '10px 32px 10px 12px',
          '&:focus': {
            borderRadius: radius.md,
            borderColor: brand.amber,
            boxShadow: t.focusRing,
          },
        },
      },
    },
    BackstageStatus: {
      styleOverrides: { status: { fontWeight: 500 } },
    },
    BackstageWarningPanel: {
      styleOverrides: {
        panel: { borderRadius: radius.md, boxShadow: 'none' },
      },
    },
    BackstageMarkdownContent: {
      styleOverrides: {
        markdown: {
          fontSize: 14,
          lineHeight: 1.6,
          '& code': {
            fontFamily: monoFontFamily,
            fontSize: '0.9em',
            padding: '1px 5px',
            borderRadius: 4,
            backgroundColor: isDark ? '#1f2f4d' : '#eef2f6',
          },
          '& a': { color: t.link, fontWeight: 500 },
          '& h2': { fontSize: 20, fontWeight: 600, marginTop: 8 },
          '& h3': { fontSize: 16, fontWeight: 600 },
        },
      },
    },

    /* Plugin components with themeable class names                       */
    // Owned / Starred / All filter box on catalog, APIs, docs and scaffolder.
    CatalogReactUserListPicker: { styleOverrides: pickerBox },
    ScaffolderReactOwnerListPicker: { styleOverrides: pickerBox },
    BackstageHighlightedSearchResultText: {
      styleOverrides: {
        highlight: {
          backgroundColor: isDark
            ? 'rgba(245, 179, 53, 0.30)'
            : 'rgba(245, 179, 53, 0.35)',
          color: 'inherit',
          borderRadius: 2,
          padding: '0 1px',
        },
      },
    },
    // Stock illustrations are off-brand; let the copy stand on our surfaces.
    BackstageEmptyStateImage: {
      styleOverrides: { generalImg: { display: 'none' } },
    },
    BackstageEmptyState: {
      styleOverrides: {
        root: { backgroundColor: n.paper, borderRadius: radius.lg, border },
      },
    },
    BackstageErrorPageMicDrop: {
      styleOverrides: { micDrop: { display: 'none' } },
    },
    BackstageErrorPage: {
      styleOverrides: {
        container: { paddingTop: 48 },
        title: { fontSize: 32, fontWeight: 700, letterSpacing: '-0.02em' },
        subtitle: {
          fontSize: 12,
          fontWeight: 600,
          letterSpacing: '0.08em',
          color: t.header.type,
        },
      },
    },
    BackstageIconLinkVertical: {
      styleOverrides: {
        label: {
          textTransform: 'none',
          letterSpacing: 0,
          fontSize: 12.5,
          fontWeight: 500,
        },
      },
    },

    /* Sidebar rail                                                       */
    BackstageSidebar: {
      styleOverrides: {
        drawer: {
          background: `linear-gradient(180deg, ${t.nav.background} 0%, ${t.nav.backgroundEnd} 100%)`,
          borderRight: `1px solid ${t.nav.divider}`,
        },
      },
    },
    // Stock items become rounded pills: 12px inset either side, so a closed
    // rail (72px) holds a 48px pill with the icon centred in it.
    BackstageSidebarItem: {
      styleOverrides: {
        root: {
          height: 40,
          margin: '2px 12px',
          borderRadius: 10,
          fontSize: 14,
          transition: 'background-color 120ms ease, color 120ms ease',
          '&:focus-visible': {
            outline: `2px solid ${brand.amber}`,
            outlineOffset: -2,
          },
        },
        closed: { width: 48, justifyContent: 'center' },
        open: { '@media (min-width: 600px)': { width: 200 } },
        highlightable: {
          '&:hover': {
            background: t.nav.hover,
            color: t.nav.selectedColor,
          },
        },
        highlighted: { background: t.nav.hover },
        label: { fontWeight: 500, fontSize: 14, width: 'auto' },
        iconContainer: {
          width: 48,
          marginRight: -4,
          '& svg': { width: 20, height: 20, fontSize: 20 },
        },
        secondaryAction: { marginRight: 4 },
        selected: {
          '&$root': {
            background: t.nav.selectedBackground,
            color: t.nav.selectedColor,
            '& $label': { fontWeight: 600 },
          },
          '&$closed': { width: 48 },
          '& $closedItemIcon': { paddingRight: 0 },
          '& $iconContainer': { marginLeft: -3 },
        },
      },
    },
    BackstageSidebarDivider: {
      styleOverrides: {
        root: {
          width: 'calc(100% - 32px)',
          margin: '8px 16px',
          background: t.nav.divider,
        },
      },
    },

    /* Sign in                                                            */
    BackstageSignInPage: {
      styleOverrides: {
        container: { padding: 32 },
        item: { maxWidth: 420 },
      },
    },
  };
}
