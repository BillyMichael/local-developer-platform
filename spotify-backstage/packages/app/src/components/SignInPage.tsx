import { UserIdentity } from '@backstage/core-components';
import { SignInPageProps, useApi } from '@backstage/core-plugin-api';
import {
  Button,
  CircularProgress,
  makeStyles,
  Typography,
} from '@material-ui/core';
import CheckRoundedIcon from '@material-ui/icons/CheckRounded';
import { useCallback, useEffect, useState } from 'react';
import { oidcAuthApiRef } from '../apis';
import { brand } from '../theme/tokens';
import { LdpLogo } from './Root/Logo';

const useStyles = makeStyles(theme => ({
  root: {
    minHeight: '100vh',
    display: 'grid',
    gridTemplateColumns: 'minmax(0, 5fr) minmax(0, 6fr)',
    [theme.breakpoints.down('sm')]: { gridTemplateColumns: '1fr' },
  },
  brand: {
    position: 'relative',
    overflow: 'hidden',
    padding: '48px 56px',
    display: 'flex',
    flexDirection: 'column',
    justifyContent: 'space-between',
    color: brand.white,
    background: `linear-gradient(160deg, ${brand.navy} 0%, ${brand.navyDark} 55%, ${brand.navyDeep} 100%)`,
    '&::before': {
      content: '""',
      position: 'absolute',
      right: -220,
      bottom: -260,
      width: 680,
      height: 680,
      borderRadius: '50%',
      background: `radial-gradient(closest-side, ${brand.amber}66, ${brand.amber}00 70%)`,
      pointerEvents: 'none',
    },
    [theme.breakpoints.down('sm')]: { padding: '32px 28px', minHeight: 320 },
  },
  brandTop: { position: 'relative' },
  brandBody: { position: 'relative', maxWidth: 520 },
  headline: {
    fontSize: 40,
    fontWeight: 700,
    letterSpacing: '-0.025em',
    lineHeight: 1.1,
    marginBottom: 18,
    [theme.breakpoints.down('sm')]: { fontSize: 30 },
  },
  lede: {
    fontSize: 16,
    lineHeight: 1.6,
    color: 'rgba(255,255,255,0.74)',
    marginBottom: 28,
  },
  points: {
    listStyle: 'none',
    margin: 0,
    padding: 0,
    display: 'grid',
    gap: 12,
  },
  point: {
    display: 'flex',
    alignItems: 'flex-start',
    gap: 12,
    fontSize: 14.5,
    lineHeight: 1.5,
    color: 'rgba(255,255,255,0.88)',
    '& svg': {
      width: 20,
      height: 20,
      padding: 2,
      borderRadius: '50%',
      background: `${brand.amber}40`,
      color: brand.amberLight,
      flexShrink: 0,
      marginTop: 1,
    },
  },
  brandFoot: {
    position: 'relative',
    fontSize: 12,
    color: 'rgba(255,255,255,0.5)',
  },
  form: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 40,
    backgroundColor: theme.palette.background.default,
  },
  card: {
    width: '100%',
    maxWidth: 420,
    padding: 36,
    borderRadius: 16,
    background: theme.palette.background.paper,
    border: `1px solid ${theme.palette.divider}`,
    boxShadow: '0 20px 48px rgba(20, 33, 58, 0.08)',
  },
  cardTitle: {
    fontSize: 24,
    fontWeight: 700,
    letterSpacing: '-0.02em',
    marginBottom: 6,
  },
  cardSub: {
    fontSize: 14,
    color: theme.palette.text.secondary,
    lineHeight: 1.55,
    marginBottom: 28,
  },
  primary: { height: 46, fontSize: 15, width: '100%' },
  error: {
    marginTop: 16,
    fontSize: 13,
    color: theme.palette.error.main,
    lineHeight: 1.5,
  },
  hint: {
    marginTop: 20,
    fontSize: 12.5,
    color: theme.palette.text.secondary,
    lineHeight: 1.5,
  },
}));

/**
 * Branded split-screen sign-in over the platform's OIDC provider. Mirrors the
 * stock SignInPage's `auto` flow: try a silent session first, then offer the
 * popup.
 */
export const LdpSignInPage = ({ onSignInSuccess }: SignInPageProps) => {
  const classes = useStyles();
  const authApi = useApi(oidcAuthApiRef);
  const [busy, setBusy] = useState(true);
  const [error, setError] = useState<string>();

  const signIn = useCallback(
    async (interactive: boolean) => {
      setBusy(true);
      setError(undefined);
      try {
        const response = await authApi.getBackstageIdentity(
          interactive ? { instantPopup: true } : { optional: true },
        );
        if (response) {
          const profile = await authApi.getProfile();
          onSignInSuccess(
            UserIdentity.create({
              identity: response.identity,
              authApi,
              profile,
            }),
          );
          return;
        }
      } catch (e) {
        if (interactive) setError((e as Error).message);
      }
      setBusy(false);
    },
    [authApi, onSignInSuccess],
  );

  useEffect(() => {
    signIn(false);
  }, [signIn]);

  return (
    <div className={classes.root}>
      <aside className={classes.brand}>
        <div className={classes.brandTop}>
          <LdpLogo size={34} tagline="" />
        </div>
        <div className={classes.brandBody}>
          <Typography component="h1" className={classes.headline}>
            Your local platform, end to end.
          </Typography>
          <Typography className={classes.lede}>
            One place to find every service, ship on the golden path and read
            the docs that live next to the code.
          </Typography>
          <ul className={classes.points}>
            <li className={classes.point}>
              <CheckRoundedIcon />
              <span>
                A single catalogue of every service, API, system and team
              </span>
            </li>
            <li className={classes.point}>
              <CheckRoundedIcon />
              <span>
                Templates that wire up Git, CI and GitOps delivery from day one
              </span>
            </li>
            <li className={classes.point}>
              <CheckRoundedIcon />
              <span>TechDocs published straight from each repository</span>
            </li>
          </ul>
        </div>
        <div className={classes.brandFoot}>
          Local Developer Platform · Sign in with the platform identity provider
        </div>
      </aside>

      <main className={classes.form}>
        <div className={classes.card}>
          <Typography component="h2" className={classes.cardTitle}>
            Sign in
          </Typography>
          <Typography className={classes.cardSub}>
            Use your platform account to access the developer portal.
          </Typography>
          <Button
            variant="contained"
            color="primary"
            className={classes.primary}
            disabled={busy}
            onClick={() => signIn(true)}
            startIcon={
              busy ? <CircularProgress size={18} color="inherit" /> : undefined
            }
          >
            {busy ? 'Signing in…' : 'Continue with SSO'}
          </Button>
          {error && (
            <Typography role="alert" className={classes.error}>
              {error}
            </Typography>
          )}
          <Typography className={classes.hint}>
            Sign-in opens a popup from the platform's identity provider. Allow
            popups for this site if nothing appears.
          </Typography>
        </div>
      </main>
    </div>
  );
};
