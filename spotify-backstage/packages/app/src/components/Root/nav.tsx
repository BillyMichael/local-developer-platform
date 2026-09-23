import { parseEntityRef } from '@backstage/catalog-model';
import { Link, useSidebarOpenState } from '@backstage/core-components';
import {
  identityApiRef,
  ProfileInfo,
  useApi,
} from '@backstage/core-plugin-api';
import { SearchModal, useSearchModal } from '@backstage/plugin-search';
import { makeStyles, Tooltip } from '@material-ui/core';
import SearchIcon from '@material-ui/icons/Search';
import { ReactNode, useEffect, useState } from 'react';
import { brand } from '../../theme/tokens';
import { LdpLogo, LdpMark } from './Logo';

const cx = (...names: Array<string | false | null | undefined>) =>
  names.filter(Boolean).join(' ');

/* Brand block                                                            */
const useBrandStyles = makeStyles(theme => ({
  root: {
    display: 'flex',
    alignItems: 'center',
    height: 72,
    width: '100%',
    padding: '0 22px',
    boxSizing: 'border-box',
    color: brand.white,
    '&:focus-visible': {
      outline: `2px solid ${theme.palette.navigation.indicator}`,
      outlineOffset: -6,
      borderRadius: 12,
    },
  },
  closed: { justifyContent: 'center', padding: 0 },
}));

export const BrandBlock = () => {
  const classes = useBrandStyles();
  const { isOpen } = useSidebarOpenState();
  return (
    <Link
      to="/"
      underline="none"
      aria-label="Local Developer Platform — home"
      className={cx(classes.root, !isOpen && classes.closed)}
    >
      {isOpen ? <LdpLogo size={30} /> : <LdpMark size={30} />}
    </Link>
  );
};

/* Section                                                                */
const useSectionStyles = makeStyles({
  label: {
    padding: '18px 24px 6px',
    fontSize: 10.5,
    fontWeight: 700,
    letterSpacing: '0.12em',
    textTransform: 'uppercase',
    color: 'rgba(255,255,255,0.42)',
    whiteSpace: 'nowrap',
  },
  rule: {
    height: 1,
    margin: '12px 20px',
    background: 'rgba(255,255,255,0.10)',
  },
});

/** A labelled group of nav items. Shows a hairline instead when collapsed. */
export const NavSection = ({
  label,
  children,
}: {
  label: string;
  children: ReactNode;
}) => {
  const classes = useSectionStyles();
  const { isOpen } = useSidebarOpenState();
  return (
    <div role="group" aria-label={label}>
      {isOpen ? (
        <div className={classes.label}>{label}</div>
      ) : (
        <div className={classes.rule} aria-hidden="true" />
      )}
      {children}
    </div>
  );
};

/* Search                                                                 */
const useSearchStyles = makeStyles(theme => ({
  button: {
    display: 'flex',
    alignItems: 'center',
    gap: 10,
    height: 38,
    margin: '2px 12px 10px',
    padding: '0 12px',
    width: 'calc(100% - 24px)',
    boxSizing: 'border-box',
    borderRadius: 10,
    border: '1px solid rgba(255,255,255,0.12)',
    background: 'rgba(255,255,255,0.07)',
    color: 'rgba(255,255,255,0.72)',
    font: 'inherit',
    fontSize: 14,
    cursor: 'pointer',
    textAlign: 'left',
    transition: 'background-color 120ms ease, border-color 120ms ease',
    '&:hover': {
      background: 'rgba(255,255,255,0.11)',
      borderColor: 'rgba(255,255,255,0.18)',
      color: brand.white,
    },
    '&:focus-visible': {
      outline: `2px solid ${theme.palette.navigation.indicator}`,
      outlineOffset: -1,
    },
    '& svg': { width: 20, height: 20, flexShrink: 0 },
  },
  closed: {
    width: 48,
    justifyContent: 'center',
    padding: 0,
    border: 'none',
    background: 'transparent',
    '&:hover': { background: 'rgba(255,255,255,0.08)' },
  },
  placeholder: {
    flex: 1,
    overflow: 'hidden',
    textOverflow: 'ellipsis',
    whiteSpace: 'nowrap',
  },
  kbd: {
    fontFamily: 'inherit',
    fontSize: 11,
    fontWeight: 600,
    letterSpacing: '0.04em',
    color: 'rgba(255,255,255,0.55)',
    border: '1px solid rgba(255,255,255,0.16)',
    borderRadius: 5,
    padding: '2px 5px',
    lineHeight: 1,
  },
}));

const isMac =
  typeof navigator !== 'undefined' &&
  /Mac|iPhone|iPad/.test(navigator.platform);

/** Command-palette style search trigger + the search modal (⌘K / Ctrl+K). */
export const NavSearch = () => {
  const classes = useSearchStyles();
  const { isOpen } = useSidebarOpenState();
  const { state, toggleModal } = useSearchModal();

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        toggleModal();
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [toggleModal]);

  const button = (
    <button
      type="button"
      onClick={toggleModal}
      aria-label="Search"
      className={cx(classes.button, !isOpen && classes.closed)}
    >
      <SearchIcon />
      {isOpen && (
        <>
          <span className={classes.placeholder}>Search…</span>
          <kbd className={classes.kbd}>{isMac ? '⌘K' : 'Ctrl K'}</kbd>
        </>
      )}
    </button>
  );

  return (
    <>
      {isOpen ? (
        button
      ) : (
        <Tooltip title="Search (⌘K)" placement="right" enterDelay={300}>
          {button}
        </Tooltip>
      )}
      <SearchModal {...state} toggleModal={toggleModal} />
    </>
  );
};

/* User footer                                                            */
const useUserStyles = makeStyles({
  root: {
    display: 'flex',
    alignItems: 'center',
    gap: 12,
    margin: '8px 12px 12px',
    padding: '10px 12px',
    borderRadius: 12,
    border: '1px solid rgba(255,255,255,0.10)',
    background: 'rgba(255,255,255,0.05)',
    color: brand.white,
    transition: 'background-color 120ms ease',
    '&:hover': { background: 'rgba(255,255,255,0.09)' },
    '&:focus-visible': {
      outline: `2px solid ${brand.amber}`,
      outlineOffset: -2,
    },
  },
  closed: {
    width: 48,
    padding: 0,
    justifyContent: 'center',
    border: 'none',
    background: 'transparent',
  },
  avatar: {
    width: 32,
    height: 32,
    borderRadius: '50%',
    flexShrink: 0,
    display: 'inline-flex',
    alignItems: 'center',
    justifyContent: 'center',
    fontSize: 13,
    fontWeight: 700,
    color: brand.navyDeep,
    background: `linear-gradient(135deg, ${brand.amberLight} 0%, ${brand.amber} 100%)`,
    backgroundSize: 'cover',
    backgroundPosition: 'center',
  },
  text: {
    display: 'flex',
    flexDirection: 'column',
    minWidth: 0,
    lineHeight: 1.2,
  },
  name: {
    fontSize: 13,
    fontWeight: 600,
    whiteSpace: 'nowrap',
    overflow: 'hidden',
    textOverflow: 'ellipsis',
  },
  meta: {
    fontSize: 11.5,
    color: 'rgba(255,255,255,0.58)',
    whiteSpace: 'nowrap',
    overflow: 'hidden',
    textOverflow: 'ellipsis',
    marginTop: 2,
  },
});

const capitalise = (s?: string) =>
  s ? s.charAt(0).toUpperCase() + s.slice(1) : undefined;

function initials(name?: string, email?: string) {
  const source = name?.trim() || email?.split('@')[0] || '?';
  return source
    .split(/[\s._-]+/)
    .filter(Boolean)
    .slice(0, 2)
    .map(p => p[0]?.toUpperCase() ?? '')
    .join('');
}

/** Signed-in user card at the foot of the rail; links to settings. */
export const UserFooter = () => {
  const classes = useUserStyles();
  const { isOpen } = useSidebarOpenState();
  const identityApi = useApi(identityApiRef);
  const [user, setUser] = useState<{ profile: ProfileInfo; ref: string }>();

  useEffect(() => {
    let live = true;
    Promise.all([
      identityApi.getProfileInfo(),
      identityApi.getBackstageIdentity(),
    ]).then(([profile, identity]) => {
      if (live) setUser({ profile, ref: identity.userEntityRef });
    });
    return () => {
      live = false;
    };
  }, [identityApi]);

  const profile = user?.profile;
  const userName = user?.ref ? parseEntityRef(user.ref).name : undefined;
  const displayName =
    profile?.displayName ?? capitalise(userName) ?? 'Signed in';
  const meta = profile?.email ?? user?.ref ?? 'View settings';

  const card = (
    <Link
      to="/settings"
      underline="none"
      aria-label={`${displayName} — settings`}
      className={cx(classes.root, !isOpen && classes.closed)}
    >
      <span
        className={classes.avatar}
        style={
          profile?.picture
            ? { backgroundImage: `url(${profile.picture})` }
            : undefined
        }
        aria-hidden="true"
      >
        {!profile?.picture && initials(displayName, profile?.email)}
      </span>
      {isOpen && (
        <span className={classes.text}>
          <span className={classes.name}>{displayName}</span>
          <span className={classes.meta}>{meta}</span>
        </span>
      )}
    </Link>
  );

  return isOpen ? (
    card
  ) : (
    <Tooltip title={displayName} placement="right" enterDelay={300}>
      {card}
    </Tooltip>
  );
};
