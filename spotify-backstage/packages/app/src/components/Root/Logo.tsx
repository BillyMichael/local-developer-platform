import { makeStyles } from '@material-ui/core';
import { fontFamily } from '../../theme/tokens';

/** The LDP mark — same SVG as docs/assets/logo.svg (isometric cube + node). */
export const LdpMark = ({ size = 28 }: { size?: number }) => (
  <svg
    width={size}
    height={size}
    viewBox="43 37 428 428"
    xmlns="http://www.w3.org/2000/svg"
    aria-hidden="true"
    focusable="false"
    style={{ display: 'block', flexShrink: 0 }}
  >
    <path
      d="M256.0 76.0 L394.6 156.0 L256.0 236.0 L117.4 156.0Z"
      fill="#f5b335"
      stroke="#f5b335"
      strokeWidth="18"
      strokeLinejoin="round"
    />
    <path
      d="M100.1 186.0 L238.7 266.0 L238.7 426.0 L100.1 346.0Z"
      fill="#8fb3ff"
      stroke="#8fb3ff"
      strokeWidth="18"
      strokeLinejoin="round"
    />
    <path
      d="M273.3 266.0 L411.9 186.0 L411.9 269.2 L350.9 304.4 L350.9 381.2 L273.3 426.0Z"
      fill="#4f6fb8"
      stroke="#4f6fb8"
      strokeWidth="18"
      strokeLinejoin="round"
    />
    <line
      x1="328.7"
      y1="291.6"
      x2="414.7"
      y2="341.2"
      stroke="#f5b335"
      strokeWidth="16"
      strokeLinecap="round"
    />
    <circle cx="328.7" cy="291.6" r="28" fill="#ffffff" />
    <circle cx="414.7" cy="341.2" r="24" fill="#f5b335" />
  </svg>
);

const useStyles = makeStyles({
  root: {
    display: 'inline-flex',
    alignItems: 'center',
    gap: 12,
    whiteSpace: 'nowrap',
    lineHeight: 1.15,
    color: 'inherit',
  },
  text: { display: 'flex', flexDirection: 'column', minWidth: 0 },
  wordmark: {
    fontFamily,
    fontWeight: 700,
    fontSize: 15,
    letterSpacing: '0.14em',
    textTransform: 'uppercase',
  },
  tagline: {
    fontSize: 11,
    fontWeight: 500,
    opacity: 0.62,
    marginTop: 3,
    whiteSpace: 'nowrap',
  },
});

/** Mark + "LDP" wordmark. Used in the nav rail and on the sign-in page. */
export const LdpLogo = ({
  size = 30,
  tagline = 'Local Developer Platform',
}: {
  size?: number;
  tagline?: string;
}) => {
  const classes = useStyles();
  return (
    <span className={classes.root}>
      <LdpMark size={size} />
      <span className={classes.text}>
        <span className={classes.wordmark}>LDP</span>
        {tagline && <span className={classes.tagline}>{tagline}</span>}
      </span>
    </span>
  );
};
