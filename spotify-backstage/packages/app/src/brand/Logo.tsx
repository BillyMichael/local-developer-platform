import { makeStyles } from '@material-ui/core';
import { BRAND, fontFamily } from '../theme';

/** The LDP mark — same SVG as docs/assets/logo.svg (isometric cube + node). */
export const LdpMark = ({
  size = 28,
  className,
}: {
  size?: number;
  className?: string;
}) => (
  <svg
    width={size}
    height={size}
    viewBox="43 37 428 428"
    xmlns="http://www.w3.org/2000/svg"
    aria-hidden="true"
    focusable="false"
    className={className}
    style={{ display: 'block', flexShrink: 0 }}
  >
    <path
      d="M256.0 76.0 L394.6 156.0 L256.0 236.0 L117.4 156.0Z"
      fill={BRAND.amber}
      stroke={BRAND.amber}
      strokeWidth="18"
      strokeLinejoin="round"
    />
    <path
      d="M100.1 186.0 L238.7 266.0 L238.7 426.0 L100.1 346.0Z"
      fill={BRAND.sky}
      stroke={BRAND.sky}
      strokeWidth="18"
      strokeLinejoin="round"
    />
    <path
      d="M273.3 266.0 L411.9 186.0 L411.9 269.2 L350.9 304.4 L350.9 381.2 L273.3 426.0Z"
      fill={BRAND.blue}
      stroke={BRAND.blue}
      strokeWidth="18"
      strokeLinejoin="round"
    />
    <line
      x1="328.7"
      y1="291.6"
      x2="414.7"
      y2="341.2"
      stroke={BRAND.amber}
      strokeWidth="16"
      strokeLinecap="round"
    />
    <circle cx="328.7" cy="291.6" r="28" fill={BRAND.white} />
    <circle cx="414.7" cy="341.2" r="24" fill={BRAND.amber} />
  </svg>
);

const useStyles = makeStyles({
  root: {
    display: 'inline-flex',
    alignItems: 'center',
    columnGap: 12,
    whiteSpace: 'nowrap',
    color: BRAND.white,
  },
  text: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'flex-start',
    gap: 4,
  },
  wordmark: {
    fontFamily,
    fontWeight: 700,
    letterSpacing: '0.14em',
    lineHeight: 1,
  },
  byline: {
    fontSize: 10,
    fontWeight: 400,
    letterSpacing: '0.02em',
    color: 'rgba(255, 255, 255, 0.6)',
  },
});

/** Mark + "LDP" wordmark + byline, for navy surfaces. */
export const LdpLogo = ({
  size = 40,
  byline = 'Local Developer Platform',
}: {
  size?: number;
  byline?: string;
}) => {
  const classes = useStyles();
  return (
    <span className={classes.root}>
      <LdpMark size={size} />
      <span className={classes.text}>
        <span className={classes.wordmark} style={{ fontSize: size * 0.6 }}>
          LDP
        </span>
        {byline && <span className={classes.byline}>{byline}</span>}
      </span>
    </span>
  );
};

/** "LDP" set bold inside a light display heading. */
export const LdpName = () => (
  <span style={{ fontWeight: 700, letterSpacing: '0.04em' }}>LDP</span>
);
