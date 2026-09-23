/* eslint-disable @typescript-eslint/no-explicit-any */
import { createBuiGlobals } from './bui';
import {
  brand,
  interactive,
  monoFontFamily,
  radius,
  statusLight,
  type ModeTokens,
} from './tokens';

/**
 * Material UI component overrides. These reach every MUI v4/v5 component in
 * the app — including plugins — through theme context.
 *
 * `defaults` is Backstage's `defaultComponentThemes`; a few entries extend it
 * rather than replace it.
 */
export function createMuiComponents(
  t: ModeTokens,
  defaults: any,
): Record<string, any> {
  const { n, shadows } = t;
  const isDark = t.mode === 'dark';
  const border = `1px solid ${n.border}`;
  const accent = t.secondary.main;
  const accentTint = isDark ? 'rgba(245, 179, 53, 0.22)' : brand.cream;
  const accentText = isDark ? brand.amberLight : brand.navy;
  const inverseBg = isDark ? '#eef2f8' : brand.navyDeep;
  const inverseFg = isDark ? brand.navyDeep : brand.white;

  return {
    /* Global                                                             */
    MuiCssBaseline: {
      styleOverrides: (theme: any) => {
        // Backstage's baseline sets `a { color: inherit }`, which beats
        // @backstage/ui's layered rules on <a>-based components. Keep the
        // reset for plain anchors only.
        const { a: _anchor, ...base } =
          defaults.MuiCssBaseline.styleOverrides(theme);
        return {
          ...base,
          'a:where(:not([class*="bui-"]))': {
            color: 'inherit',
            textDecoration: 'none',
          },
          html: {
            ...base.html,
            WebkitFontSmoothing: 'antialiased',
            MozOsxFontSmoothing: 'grayscale',
            textRendering: 'optimizeLegibility',
          },
          body: {
            ...base.body,
            backgroundColor: n.bg,
            color: n.textPrimary,
            fontSize: '0.875rem',
            lineHeight: 1.5,
            '&::-webkit-scrollbar, & *::-webkit-scrollbar': {
              backgroundColor: 'transparent',
              width: 10,
              height: 10,
            },
            '&::-webkit-scrollbar-thumb, & *::-webkit-scrollbar-thumb': {
              borderRadius: 8,
              backgroundColor: n.textVerySubtle,
              border: `2px solid ${n.bg}`,
            },
            '&::-webkit-scrollbar-thumb:hover, & *::-webkit-scrollbar-thumb:hover':
              {
                backgroundColor: n.textDisabled,
              },
          },
          code: { fontFamily: monoFontFamily },
          pre: { fontFamily: monoFontFamily },
          mark: {
            backgroundColor: isDark
              ? 'rgba(245, 179, 53, 0.30)'
              : 'rgba(245, 179, 53, 0.35)',
            color: 'inherit',
            borderRadius: 2,
            padding: '0 1px',
          },
          '::selection': {
            backgroundColor: 'rgba(245, 179, 53, 0.35)',
          },
          ':focus-visible': {
            outline: `2px solid ${brand.amber}`,
            outlineOffset: 2,
          },
          ...createBuiGlobals(t),
        };
      },
    },

    /* Default props — reshape raw MUI usage in plugins without touching   */
    /* their code: outlined inputs, flat buttons, arrowed tooltips.        */
    MuiTextField: {
      defaultProps: { variant: 'outlined' },
    },
    MuiLink: {
      defaultProps: { underline: 'hover' },
      styleOverrides: {
        root: {
          color: t.link,
          fontWeight: 500,
          '&:hover': { color: t.linkHover },
        },
        underlineHover: {
          textDecoration: 'none',
          '&:hover': { textDecoration: 'underline' },
        },
      },
    },
    MuiCheckbox: {
      defaultProps: { color: 'primary' },
      styleOverrides: {
        root: {
          color: n.borderStrong,
          '&$checked, &.Mui-checked': { color: t.primary.main },
        },
      },
    },
    MuiRadio: {
      defaultProps: { color: 'primary' },
      styleOverrides: {
        root: {
          color: n.borderStrong,
          '&$checked, &.Mui-checked': { color: t.primary.main },
        },
      },
    },

    /* Surfaces                                                           */
    MuiPaper: {
      styleOverrides: {
        root: { backgroundImage: 'none' },
        rounded: { borderRadius: radius.lg },
        outlined: { border },
        elevation1: { boxShadow: 'none', border },
        elevation2: { boxShadow: shadows.sm, border },
        elevation3: { boxShadow: shadows.md },
        elevation4: { boxShadow: shadows.md },
        elevation6: { boxShadow: shadows.md },
        elevation8: { boxShadow: shadows.lg, border },
        elevation16: { boxShadow: shadows.lg },
        elevation24: { boxShadow: shadows.lg },
      },
    },
    MuiCard: {
      styleOverrides: {
        root: {
          display: 'flex',
          flexDirection: 'column',
          borderRadius: radius.lg,
          border,
          boxShadow: 'none',
          backgroundImage: 'none',
          overflow: 'hidden',
          transition: interactive.transition,
          // Any card wrapping a CardActionArea (template cards, plugin cards)
          // lifts on hover. The lift lives on the Card because its
          // overflow:hidden would clip a shadow drawn by the action area.
          '&:has(.MuiCardActionArea-root, .v5-MuiCardActionArea-root):hover': {
            transform: interactive.transform,
            boxShadow: shadows.md,
            borderColor: accent,
          },
        },
      },
    },
    MuiCardActionArea: {
      defaultProps: { disableRipple: true },
      styleOverrides: {
        root: {
          '&:hover $focusHighlight, &:hover .MuiCardActionArea-focusHighlight, &:hover .v5-MuiCardActionArea-focusHighlight':
            { opacity: 0 },
        },
      },
    },
    MuiCardHeader: {
      styleOverrides: {
        root: { padding: '18px 20px 10px' },
        title: {
          fontSize: 16,
          fontWeight: 600,
          letterSpacing: '-0.01em',
          lineHeight: 1.35,
        },
        subheader: { fontSize: 13, color: n.textSecondary, marginTop: 2 },
        action: { marginTop: -4, marginRight: -4 },
      },
    },
    MuiCardContent: {
      styleOverrides: {
        root: {
          padding: '12px 20px 20px',
          '&:last-child': { paddingBottom: 20 },
        },
      },
    },
    MuiCardActions: {
      styleOverrides: { root: { padding: '8px 16px 16px' } },
    },
    MuiDivider: {
      styleOverrides: { root: { backgroundColor: n.border } },
    },
    MuiAccordion: {
      styleOverrides: {
        root: {
          boxShadow: 'none',
          border,
          borderRadius: radius.md,
          '&:before': { display: 'none' },
          '&$expanded, &.Mui-expanded': { margin: 0 },
        },
        rounded: {
          '&:first-child': {
            borderTopLeftRadius: radius.md,
            borderTopRightRadius: radius.md,
          },
          '&:last-child': {
            borderBottomLeftRadius: radius.md,
            borderBottomRightRadius: radius.md,
          },
        },
      },
    },
    MuiDialog: {
      styleOverrides: {
        paper: { borderRadius: radius.xl, boxShadow: shadows.lg, border },
      },
    },
    MuiDialogTitle: {
      styleOverrides: { root: { padding: '24px 24px 8px' } },
    },
    MuiDialogContent: {
      styleOverrides: { root: { padding: '8px 24px 16px' } },
    },
    MuiDialogActions: {
      styleOverrides: { root: { padding: '12px 24px 24px' } },
    },
    MuiBackdrop: {
      styleOverrides: {
        root: {
          backgroundColor: isDark
            ? 'rgba(3, 8, 18, 0.7)'
            : 'rgba(20, 33, 58, 0.45)',
          backdropFilter: 'blur(2px)',
        },
      },
    },
    MuiPopover: {
      styleOverrides: {
        paper: { borderRadius: radius.md, boxShadow: shadows.lg, border },
      },
    },
    MuiMenu: {
      styleOverrides: {
        paper: { borderRadius: radius.md, boxShadow: shadows.lg, border },
        list: { padding: 6 },
      },
    },
    MuiMenuItem: {
      styleOverrides: {
        root: {
          fontSize: 14,
          borderRadius: radius.sm,
          minHeight: 36,
          padding: '8px 10px',
          '&:hover': { backgroundColor: t.hoverOverlay },
          '&$selected, &.Mui-selected': {
            backgroundColor: t.selectedOverlay,
            '&:hover': { backgroundColor: t.selectedOverlay },
          },
        },
      },
    },
    MuiListItem: {
      styleOverrides: {
        button: {
          borderRadius: radius.sm,
          '&:hover': { backgroundColor: t.hoverOverlay },
        },
      },
    },
    MuiTooltip: {
      defaultProps: { arrow: true },
      styleOverrides: {
        tooltip: {
          backgroundColor: inverseBg,
          color: inverseFg,
          fontSize: 12,
          fontWeight: 500,
          borderRadius: radius.sm,
          padding: '6px 10px',
          boxShadow: shadows.md,
        },
        arrow: { color: inverseBg },
      },
    },
    MuiSnackbarContent: {
      styleOverrides: {
        root: {
          borderRadius: radius.md,
          backgroundColor: inverseBg,
          color: inverseFg,
        },
      },
    },
    MuiAlert: {
      styleOverrides: { root: { borderRadius: radius.md, fontSize: 14 } },
    },

    /* Controls                                                           */
    MuiTypography: {
      styleOverrides: {
        button: {
          textTransform: 'none',
          letterSpacing: 0,
          fontWeight: 600,
          fontSize: 13,
        },
      },
    },
    MuiButton: {
      defaultProps: { disableElevation: true },
      styleOverrides: {
        root: {
          textTransform: 'none',
          fontWeight: 600,
          fontSize: 14,
          lineHeight: '24px',
          letterSpacing: 0,
          borderRadius: radius.md,
          padding: '8px 16px',
          boxShadow: 'none',
          transition: 'background-color 120ms ease, border-color 120ms ease',
          '&:hover': { boxShadow: 'none' },
          '&:focus-visible': { boxShadow: t.focusRing },
        },
        contained: {
          boxShadow: 'none',
          '&:hover': { boxShadow: 'none' },
          '&:active': { boxShadow: 'none' },
          '&$disabled, &.Mui-disabled': {
            backgroundColor: isDark
              ? 'rgba(255,255,255,0.10)'
              : 'rgba(20,33,58,0.08)',
            color: n.textDisabled,
          },
        },
        containedPrimary: {
          backgroundColor: t.primary.main,
          color: t.primary.contrastText,
          '&:hover': { backgroundColor: t.primary.dark },
        },
        containedSecondary: {
          backgroundColor: t.secondary.main,
          color: t.secondary.contrastText,
          '&:hover': { backgroundColor: t.secondary.dark },
        },
        outlined: {
          borderColor: n.borderStrong,
          color: n.textPrimary,
          backgroundColor: n.paper,
          '&:hover': {
            backgroundColor: t.hoverOverlay,
            borderColor: n.borderStrong,
          },
        },
        outlinedPrimary: {
          borderColor: n.borderStrong,
          color: accentText,
          '&:hover': {
            borderColor: isDark ? brand.amber : brand.navy,
            backgroundColor: t.hoverOverlay,
          },
        },
        text: {
          padding: '8px 12px',
          color: t.link,
          '&:hover': { backgroundColor: t.hoverOverlay },
        },
        textPrimary: {
          color: accentText,
          '&:hover': { backgroundColor: t.hoverOverlay },
        },
        sizeSmall: {
          padding: '5px 12px',
          fontSize: 13,
          borderRadius: radius.sm,
        },
        sizeLarge: { padding: '11px 22px', fontSize: 15 },
      },
    },
    MuiIconButton: {
      styleOverrides: {
        root: {
          borderRadius: radius.md,
          color: n.textSecondary,
          '&:hover': { backgroundColor: t.hoverOverlay, color: n.textPrimary },
        },
      },
    },
    MuiButtonGroup: {
      styleOverrides: {
        root: { boxShadow: 'none' },
        contained: { boxShadow: 'none' },
      },
    },
    MuiToggleButton: {
      styleOverrides: {
        root: {
          textTransform: 'none',
          fontWeight: 500,
          border,
          color: n.textSecondary,
          '&$selected, &.Mui-selected': {
            backgroundColor: t.selectedOverlay,
            color: n.textPrimary,
          },
        },
      },
    },
    MuiChip: {
      styleOverrides: {
        root: {
          ...defaults.MuiChip.styleOverrides.root,
          borderRadius: radius.pill,
          height: 26,
          backgroundColor: t.chipBg,
          color: n.textPrimary,
          border: '1px solid transparent',
          fontWeight: 500,
          marginRight: 8,
          marginBottom: 8,
        },
        label: {
          paddingLeft: 10,
          paddingRight: 10,
          fontSize: 12.5,
          lineHeight: '20px',
          fontWeight: 500,
        },
        labelSmall: { fontSize: 11.5, paddingLeft: 8, paddingRight: 8 },
        sizeSmall: { height: 22 },
        outlined: {
          backgroundColor: 'transparent',
          borderColor: n.borderStrong,
        },
        colorPrimary: { backgroundColor: accentTint, color: accentText },
        colorSecondary: {
          backgroundColor: accentTint,
          color: isDark ? brand.amberLight : brand.amberText,
        },
        clickable: {
          '&:hover, &:focus': {
            backgroundColor: isDark ? '#263756' : '#e3e8ee',
          },
        },
        deleteIcon: {
          width: 18,
          height: 18,
          margin: '0 5px 0 -4px',
          color: 'inherit',
          opacity: 0.6,
          '&:hover': { opacity: 1, color: 'inherit' },
        },
        avatar: { marginLeft: 4 },
        icon: { marginLeft: 6, color: 'inherit' },
      },
    },
    MuiOutlinedInput: {
      styleOverrides: {
        root: {
          borderRadius: radius.md,
          backgroundColor: n.paper,
          fontSize: 14,
          transition: 'border-color 120ms ease',
          '&:hover $notchedOutline, &:hover .MuiOutlinedInput-notchedOutline, &:hover .v5-MuiOutlinedInput-notchedOutline':
            { borderColor: n.borderStrong },
          // A thicker accent border rather than a glow: the floating label
          // sits in the outline's notch and a ring bleeds through behind it.
          '&$focused $notchedOutline, &.Mui-focused .MuiOutlinedInput-notchedOutline, &.Mui-focused .v5-MuiOutlinedInput-notchedOutline':
            { borderColor: brand.amber, borderWidth: 2 },
        },
        notchedOutline: {
          borderColor: n.border,
          transition: 'border-color 120ms ease',
        },
        input: { padding: '11px 14px' },
        inputMarginDense: { paddingTop: 8, paddingBottom: 8 },
      },
    },
    MuiFilledInput: {
      styleOverrides: {
        root: {
          borderRadius: radius.md,
          backgroundColor: n.paperMuted,
          '&:hover': { backgroundColor: isDark ? '#1f2f4d' : '#eef2f6' },
          '&$focused, &.Mui-focused': {
            backgroundColor: n.paper,
            boxShadow: t.focusRing,
          },
        },
        underline: { '&:before, &:after': { display: 'none' } },
      },
    },
    MuiInputBase: {
      styleOverrides: {
        root: { fontSize: 14 },
        input: { '&::placeholder': { color: n.textDisabled, opacity: 1 } },
      },
    },
    MuiInputLabel: {
      styleOverrides: {
        root: { fontSize: 14 },
        outlined: {
          transform: 'translate(14px, 13px) scale(1)',
          '&$shrink, &.MuiInputLabel-shrink': {
            transform: 'translate(14px, -6px) scale(0.8)',
            padding: '0 4px',
            marginLeft: -4,
            backgroundColor: n.paper,
            borderRadius: 3,
          },
        },
      },
    },
    MuiFormLabel: {
      styleOverrides: {
        root: {
          color: n.textSecondary,
          fontWeight: 500,
          '&$focused, &.Mui-focused': { color: t.link },
        },
      },
    },
    MuiFormHelperText: {
      styleOverrides: { root: { fontSize: 12, marginTop: 6 } },
    },
    MuiSelect: {
      styleOverrides: {
        select: {
          '&:focus': {
            backgroundColor: 'transparent',
            borderRadius: radius.md,
          },
        },
        icon: { color: n.textSecondary },
      },
    },
    MuiSwitch: {
      ...defaults.MuiSwitch,
      styleOverrides: {
        colorPrimary: {
          '&$checked, &.Mui-checked': { color: brand.amber },
          '&$checked + $track, &.Mui-checked + .MuiSwitch-track': {
            backgroundColor: brand.amber,
          },
        },
      },
    },
    MuiSlider: {
      styleOverrides: { root: { color: brand.amber } },
    },
    MuiLinearProgress: {
      styleOverrides: {
        root: {
          borderRadius: radius.pill,
          height: 6,
          backgroundColor: isDark
            ? 'rgba(255,255,255,0.08)'
            : 'rgba(27, 45, 79, 0.10)',
        },
        bar: { borderRadius: radius.pill },
        barColorPrimary: { backgroundColor: brand.amber },
        colorPrimary: {
          backgroundColor: isDark
            ? 'rgba(255,255,255,0.08)'
            : 'rgba(27, 45, 79, 0.10)',
        },
      },
    },
    MuiCircularProgress: {
      styleOverrides: { colorPrimary: { color: brand.amber } },
    },
    MuiAvatar: {
      styleOverrides: {
        root: { fontWeight: 600, fontSize: 14 },
        colorDefault: { backgroundColor: accentTint, color: accentText },
      },
    },
    MuiBadge: {
      styleOverrides: {
        colorPrimary: { backgroundColor: brand.amber, color: brand.navyDeep },
      },
    },
    MuiBreadcrumbs: {
      styleOverrides: {
        root: { fontSize: 13 },
        separator: { color: n.textDisabled },
      },
    },
    MuiStepIcon: {
      styleOverrides: {
        root: {
          color: n.borderStrong,
          '&$active, &.Mui-active': { color: t.primary.main },
          '&$completed, &.Mui-completed': { color: statusLight.ok },
        },
      },
    },

    /* Tabs                                                               */
    MuiTabs: {
      styleOverrides: {
        root: { minHeight: 44 },
        indicator: {
          height: 3,
          borderRadius: '3px 3px 0 0',
          backgroundColor: brand.amber,
        },
      },
    },
    MuiTab: {
      styleOverrides: {
        root: {
          textTransform: 'none',
          fontWeight: 500,
          fontSize: 14,
          letterSpacing: 0,
          minHeight: 44,
          minWidth: 0,
          padding: '10px 16px',
          color: n.textSecondary,
          borderRadius: `${radius.sm}px ${radius.sm}px 0 0`,
          transition: 'color 120ms ease, background-color 120ms ease',
          '&:hover': { color: n.textPrimary, backgroundColor: t.hoverOverlay },
          '&$selected, &.Mui-selected': {
            color: n.textPrimary,
            fontWeight: 600,
          },
          '@media (min-width: 960px)': {
            minWidth: 0,
            fontSize: 14,
            fontWeight: 500,
          },
        },
        textColorPrimary: {
          color: n.textSecondary,
          '&$selected, &.Mui-selected': { color: n.textPrimary },
        },
        textColorInherit: { opacity: 1 },
      },
    },

    /* Tables                                                             */
    MuiTableRow: {
      styleOverrides: {
        root: {
          '&:nth-of-type(odd)': { backgroundColor: 'transparent' },
          '&:last-child td': { borderBottom: 0 },
        },
        hover: {
          '&:hover': {
            cursor: 'pointer',
            backgroundColor: `${t.hoverOverlay} !important`,
          },
        },
        head: { '&:nth-of-type(odd)': { backgroundColor: 'transparent' } },
      },
    },
    MuiTableCell: {
      styleOverrides: {
        root: {
          wordBreak: 'break-word',
          overflow: 'hidden',
          verticalAlign: 'middle',
          lineHeight: 1.4,
          fontSize: 14,
          margin: 0,
          padding: '14px 16px 14px 20px',
          borderBottom: border,
        },
        sizeSmall: { padding: '10px 16px 10px 20px' },
        head: {
          wordBreak: 'break-word',
          overflow: 'hidden',
          color: n.textSecondary,
          fontWeight: 600,
          fontSize: 12,
          lineHeight: 1.2,
          letterSpacing: '0.06em',
          textTransform: 'uppercase',
          backgroundColor: n.paperMuted,
          borderBottom: border,
        },
        footer: { borderBottom: 0 },
      },
    },
    MuiTableSortLabel: defaults.MuiTableSortLabel,
    MuiTablePagination: {
      styleOverrides: {
        root: { fontSize: 13, color: n.textSecondary },
        toolbar: { minHeight: 52 },
      },
    },
  };
}
