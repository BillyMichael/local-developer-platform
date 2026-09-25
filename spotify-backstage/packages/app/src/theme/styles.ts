import type { Theme } from '@material-ui/core/styles';
import { BRAND, monoFontFamily } from './tokens';

const isLight = (theme: Theme) => theme.palette.type === 'light';

/* Flat card: a border at rest, a lift only on hover. */
export const flatCardHoverStyles = (theme: Theme) =>
  ({
    borderColor: isLight(theme) ? BRAND.slate : BRAND.darkTextSecondary,
    transform: 'translateY(-2px)',
    boxShadow: isLight(theme)
      ? '0 8px 24px rgba(20, 33, 58, 0.10)'
      : '0 8px 24px rgba(0, 0, 0, 0.40)',
  } as const);

export const flatCardStyles = (theme: Theme) =>
  ({
    borderRadius: BRAND.radius,
    backgroundColor: theme.palette.background.paper,
    border: `1px solid ${
      isLight(theme) ? BRAND.mist : BRAND.darkSurfaceBorder
    }`,
    transition:
      'border-color 0.2s ease, box-shadow 0.3s ease, transform 0.2s ease',
    '&:hover': flatCardHoverStyles(theme),
  } as const);

/* Bare monochrome glyph for decorative card icons — never the accent. */
export const iconChipStyles = (theme: Theme, size = 32) =>
  ({
    display: 'flex',
    alignItems: 'center',
    '& svg': {
      fontSize: size,
      color: isLight(theme) ? BRAND.navy : BRAND.white,
    },
  } as const);

/* Small uppercase mono eyebrow above headings. */
export const overlineStyles = {
  fontFamily: monoFontFamily,
  fontSize: 12,
  fontWeight: 500,
  letterSpacing: '0.12em',
  textTransform: 'uppercase' as const,
};

/*
 * Circuit traces for the hero and sign-in backdrop: orthogonal paths with
 * 16px corners entering from the right edge in navy tints, exactly one in
 * amber, masked out before they reach the copy. Spread into a positioned,
 * overflow-hidden container on a navy surface.
 */
export const tracesStyles = {
  '&::after': {
    content: '""',
    position: 'absolute' as const,
    inset: 0,
    backgroundImage: `url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='1080' height='360' viewBox='0 0 1080 360'%3E%3Cg fill='none' stroke-width='1.5'%3E%3Cpath stroke='%23304672' d='M1080 44 L940 44 Q924 44 924 60 L924 160 Q924 176 908 176 L840 176 Q824 176 824 192 L824 360'/%3E%3Cpath stroke='%232a3f68' d='M1080 78 L974 78 Q958 78 958 94 L958 194 Q958 210 942 210 L874 210 Q858 210 858 226 L858 360'/%3E%3Cpath stroke='%2324375d' d='M1080 112 L1008 112 Q992 112 992 128 L992 228 Q992 244 976 244 L908 244 Q892 244 892 260 L892 360'/%3E%3Cpath stroke='%23F5B335' stroke-opacity='0.8' d='M1080 10 L906 10 Q890 10 890 26 L890 126 Q890 142 874 142 L806 142 Q790 142 790 158 L790 360'/%3E%3Cpath stroke='%231f3052' d='M1080 146 L1042 146 Q1026 146 1026 162 L1026 262 Q1026 278 1010 278 L942 278 Q926 278 926 294 L926 360'/%3E%3C/g%3E%3C/svg%3E")`,
    backgroundRepeat: 'no-repeat',
    backgroundPosition: 'right bottom',
    pointerEvents: 'none' as const,
    maskImage:
      'linear-gradient(to left, rgba(0,0,0,1) 0%, rgba(0,0,0,1) 25%, rgba(0,0,0,0) 60%)',
    WebkitMaskImage:
      'linear-gradient(to left, rgba(0,0,0,1) 0%, rgba(0,0,0,1) 25%, rgba(0,0,0,0) 60%)',
  },
  '@media (max-width: 960px)': {
    '&::after': { display: 'none' },
  },
} as const;
