import { useCallback, useEffect, useState } from 'react';
import {
  Button,
  CircularProgress,
  makeStyles,
  Typography,
} from '@material-ui/core';
import { UserIdentity } from '@backstage/core-components';
import { SignInPageProps, useApi } from '@backstage/core-plugin-api';
import { oidcAuthApiRef } from '../../modules/apis/oidcAuthApiRef';
import { LdpLogo, LdpName } from '../../brand/Logo';
import { BRAND, STATUS, overlineStyles, tracesStyles } from '../../theme';

const useStyles = makeStyles(theme => ({
  root: {
    minHeight: '100vh',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    padding: theme.spacing(3),
    backgroundColor: BRAND.navyDeep,
    position: 'relative',
    overflow: 'hidden',
    ...tracesStyles,
  },
  card: {
    position: 'relative',
    zIndex: 2,
    width: '100%',
    maxWidth: 440,
    textAlign: 'center',
    padding: theme.spacing(6, 4),
    borderRadius: BRAND.radius,
    background: BRAND.darkSurface,
    border: `1px solid ${BRAND.darkSurfaceBorder}`,
  },
  logo: {
    display: 'flex',
    justifyContent: 'center',
    marginBottom: theme.spacing(4),
  },
  overline: {
    ...overlineStyles,
    color: BRAND.amber,
    marginBottom: theme.spacing(1),
  },
  title: {
    color: BRAND.white,
    fontWeight: 300,
    marginBottom: theme.spacing(1),
  },
  subtitle: {
    color: 'rgba(255, 255, 255, 0.7)',
    marginBottom: theme.spacing(4),
  },
  button: { padding: theme.spacing(1.25, 5) },
  error: { color: STATUS.errorTextDark, marginTop: theme.spacing(2) },
  hint: {
    color: 'rgba(255, 255, 255, 0.5)',
    marginTop: theme.spacing(3),
    fontSize: 12.5,
  },
  spinner: { color: BRAND.white },
}));

/**
 * Sign-in over the platform's OIDC provider. Tries a silent session first,
 * then offers the popup.
 */
export const LdpSignInPage = ({ onSignInSuccess }: SignInPageProps) => {
  const classes = useStyles();
  const authApi = useApi(oidcAuthApiRef);
  const [checkingSession, setCheckingSession] = useState(true);
  const [signingIn, setSigningIn] = useState(false);
  const [error, setError] = useState<string>();

  const signIn = useCallback(
    async (interactive: boolean) => {
      const response = await authApi.getBackstageIdentity(
        interactive ? { instantPopup: true } : { optional: true },
      );
      if (!response) {
        if (interactive) throw new Error('No identity was returned');
        return false;
      }
      const profile = await authApi.getProfile();
      onSignInSuccess(
        UserIdentity.create({ identity: response.identity, authApi, profile }),
      );
      return true;
    },
    [authApi, onSignInSuccess],
  );

  useEffect(() => {
    let live = true;
    signIn(false)
      .catch(() => false)
      .then(done => {
        if (live && !done) setCheckingSession(false);
      });
    return () => {
      live = false;
    };
  }, [signIn]);

  const handleSignIn = async () => {
    setSigningIn(true);
    setError(undefined);
    try {
      await signIn(true);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
      setSigningIn(false);
    }
  };

  return (
    <div className={classes.root}>
      {checkingSession ? (
        <CircularProgress className={classes.spinner} />
      ) : (
        <div className={classes.card}>
          <div className={classes.logo}>
            <LdpLogo size={48} />
          </div>
          <Typography className={classes.overline}>
            Local Developer Platform
          </Typography>
          <Typography variant="h4" component="h1" className={classes.title}>
            Welcome to <LdpName />
          </Typography>
          <Typography variant="body1" className={classes.subtitle}>
            Find every service, ship on the golden path and read the docs that
            live next to the code.
          </Typography>
          <Button
            variant="contained"
            color="primary"
            className={classes.button}
            onClick={handleSignIn}
            disabled={signingIn}
          >
            {signingIn ? 'Signing in…' : 'Continue with SSO'}
          </Button>
          {error && (
            <Typography role="alert" variant="body2" className={classes.error}>
              {error}
            </Typography>
          )}
          <Typography className={classes.hint}>
            Sign-in opens a popup from the platform's identity provider. Allow
            popups for this site if nothing appears.
          </Typography>
        </div>
      )}
    </div>
  );
};
