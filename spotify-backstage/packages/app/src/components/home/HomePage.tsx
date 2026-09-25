import { Grid, makeStyles, Typography } from '@material-ui/core';
import { Content, Link, Page } from '@backstage/core-components';
import { HomePageSearchBar } from '@backstage/plugin-search';
import { SearchContextProvider } from '@backstage/plugin-search-react';
import AddCircleOutlineIcon from '@material-ui/icons/AddCircleOutline';
import ArrowForwardIcon from '@material-ui/icons/ArrowForward';
import CategoryOutlinedIcon from '@material-ui/icons/CategoryOutlined';
import CloudUploadOutlinedIcon from '@material-ui/icons/CloudUploadOutlined';
import DeviceHubOutlinedIcon from '@material-ui/icons/DeviceHubOutlined';
import LibraryBooksOutlinedIcon from '@material-ui/icons/LibraryBooksOutlined';
import { LdpName } from '../../brand/Logo';
import { PLATFORM_TOOLS } from '../../platformTools';
import {
  amberAlpha,
  BRAND,
  flatCardHoverStyles,
  flatCardStyles,
  iconChipStyles,
  overlineStyles,
  tracesStyles,
} from '../../theme';

const useStyles = makeStyles(theme => ({
  '@keyframes fadeInUp': {
    '0%': { opacity: 0, transform: 'translateY(16px)' },
    '100%': { opacity: 1, transform: 'translateY(0)' },
  },
  hero: {
    backgroundColor: BRAND.navyDeep,
    padding: theme.spacing(10, 3),
    position: 'relative',
    overflow: 'hidden',
    borderBottom: `1px solid ${amberAlpha(0.35)}`,
    ...tracesStyles,
  },
  heroInner: {
    position: 'relative',
    zIndex: 2,
    maxWidth: 1200,
    margin: '0 auto',
  },
  heroOverline: {
    ...overlineStyles,
    color: BRAND.amber,
    marginBottom: theme.spacing(2),
  },
  heroHeading: {
    fontSize: '3.25rem',
    fontWeight: 300,
    letterSpacing: '-0.01em',
    color: BRAND.white,
    marginBottom: theme.spacing(2),
    [theme.breakpoints.down('sm')]: { fontSize: '2.5rem' },
  },
  heroSubtitle: {
    fontSize: '1.125rem',
    color: 'rgba(255, 255, 255, 0.68)',
    maxWidth: 560,
    marginBottom: theme.spacing(4),
  },
  searchBar: {
    maxWidth: 640,
    display: 'flex',
    backgroundColor: 'rgba(255, 255, 255, 0.05)',
    border: '1px solid rgba(255, 255, 255, 0.15)',
    borderRadius: BRAND.radius,
    padding: 8,
    transition: 'border-color 0.2s ease, box-shadow 0.2s ease',
    '& input': { color: BRAND.white },
    '& input::placeholder': { color: 'rgba(255, 255, 255, 0.5)' },
    '& svg': { color: 'rgba(255, 255, 255, 0.5)' },
    '&:hover': { borderColor: 'rgba(255, 255, 255, 0.3)' },
    '&:focus-within': {
      borderColor: BRAND.amber,
      boxShadow: `0 0 0 3px ${amberAlpha(0.25)}`,
    },
  },
  searchBarOutline: { borderStyle: 'none' },
  quickLinks: {
    display: 'flex',
    flexWrap: 'wrap',
    gap: theme.spacing(1.5),
    marginTop: theme.spacing(3),
  },
  quickLink: {
    padding: '6px 16px',
    border: '1px solid rgba(255, 255, 255, 0.16)',
    color: 'rgba(255, 255, 255, 0.85)',
    fontSize: '0.875rem',
    fontWeight: 600,
    '&:hover': {
      borderColor: 'rgba(255, 255, 255, 0.5)',
      backgroundColor: 'rgba(255, 255, 255, 0.08)',
      color: BRAND.white,
      textDecoration: 'none',
    },
  },
  enter: { opacity: 0, animation: '$fadeInUp 0.5s ease forwards' },

  content: {
    padding: theme.spacing(7, 3),
    backgroundColor: theme.palette.background.default,
  },
  contentInner: { maxWidth: 1200, margin: '0 auto' },
  section: { '& + &': { marginTop: theme.spacing(8) } },
  sectionOverline: {
    ...overlineStyles,
    color: theme.palette.type === 'light' ? BRAND.amberText : BRAND.amber,
    marginBottom: theme.spacing(0.5),
  },
  sectionTitle: { fontWeight: 700, marginBottom: theme.spacing(1) },
  sectionSubtext: {
    color: theme.palette.text.secondary,
    marginBottom: theme.spacing(3),
    maxWidth: 640,
  },

  toolCard: {
    ...flatCardStyles(theme),
    display: 'flex',
    flexDirection: 'column',
    height: '100%',
    padding: theme.spacing(3),
    '&:hover': { ...flatCardHoverStyles(theme), textDecoration: 'none' },
  },
  iconChip: { ...iconChipStyles(theme), marginBottom: theme.spacing(2) },
  toolTitle: { fontWeight: 700, color: theme.palette.text.primary },
  toolProduct: {
    ...overlineStyles,
    fontSize: 11,
    color: theme.palette.text.secondary,
    margin: theme.spacing(0.5, 0, 1),
  },
  toolDescription: {
    color: theme.palette.text.secondary,
    fontSize: '0.875rem',
    lineHeight: 1.5,
  },

  rowCard: {
    ...flatCardStyles(theme),
    display: 'flex',
    alignItems: 'center',
    gap: theme.spacing(2),
    padding: theme.spacing(2),
    '&:hover': {
      ...flatCardHoverStyles(theme),
      textDecoration: 'none',
      '& $rowArrow': {
        color: theme.palette.text.primary,
        transform: 'translateX(3px)',
      },
    },
  },
  rowIcon: { ...iconChipStyles(theme, 28), flexShrink: 0 },
  rowText: { display: 'flex', flexDirection: 'column', minWidth: 0 },
  rowTitle: { fontWeight: 700, color: theme.palette.text.primary },
  rowDescription: {
    fontSize: '0.8rem',
    color: theme.palette.text.secondary,
  },
  rowArrow: {
    marginLeft: 'auto',
    fontSize: 18,
    color: theme.palette.text.secondary,
    transition: 'color 0.2s ease, transform 0.2s ease',
  },

  '@media (prefers-reduced-motion: reduce)': {
    enter: { opacity: 1, animation: 'none' },
  },
}));

const QUICK_LINKS = [
  { title: 'Browse catalog', href: '/catalog' },
  { title: 'Start from a template', href: '/create' },
  { title: 'Read the docs', href: '/docs' },
  { title: 'Explore APIs', href: '/api-docs' },
];

const TOOLKIT = [
  {
    icon: AddCircleOutlineIcon,
    title: 'Create',
    description: 'Launch a service from a golden-path template',
    href: '/create',
  },
  {
    icon: CloudUploadOutlinedIcon,
    title: 'Register',
    description: 'Add an existing repository to the catalog',
    href: '/catalog-import',
  },
  {
    icon: CategoryOutlinedIcon,
    title: 'Catalog',
    description: 'Every component, system and team',
    href: '/catalog',
  },
  {
    icon: DeviceHubOutlinedIcon,
    title: 'APIs',
    description: 'Browse the APIs services provide',
    href: '/api-docs',
  },
  {
    icon: LibraryBooksOutlinedIcon,
    title: 'Docs',
    description: 'TechDocs published from each repository',
    href: '/docs',
  },
];

const delay = (i: number, step = 0.06) => ({ animationDelay: `${i * step}s` });

export const HomePage = () => {
  const classes = useStyles();

  return (
    <SearchContextProvider>
      <Page themeId="home">
        <Content noPadding>
          <div className={classes.hero}>
            <div className={classes.heroInner}>
              <Typography
                className={`${classes.heroOverline} ${classes.enter}`}
              >
                Local Developer Platform
              </Typography>
              <Typography
                variant="h2"
                component="h1"
                className={`${classes.heroHeading} ${classes.enter}`}
                style={delay(1, 0.08)}
              >
                Welcome to <LdpName />
              </Typography>
              <Typography
                className={`${classes.heroSubtitle} ${classes.enter}`}
                style={delay(2, 0.08)}
              >
                Your platform, end to end on one laptop. Find every service,
                ship on the golden path and read the docs that live next to the
                code.
              </Typography>
              <div className={classes.enter} style={delay(3, 0.08)}>
                <HomePageSearchBar
                  classes={{ root: classes.searchBar }}
                  InputProps={{
                    classes: { notchedOutline: classes.searchBarOutline },
                  }}
                  placeholder="Search services, docs, APIs…"
                  clearButton={false}
                />
              </div>
              <div
                className={`${classes.quickLinks} ${classes.enter}`}
                style={delay(4, 0.08)}
              >
                {QUICK_LINKS.map(link => (
                  <Link
                    key={link.href}
                    to={link.href}
                    className={classes.quickLink}
                  >
                    {link.title}
                  </Link>
                ))}
              </div>
            </div>
          </div>

          <div className={classes.content}>
            <div className={classes.contentInner}>
              <section className={classes.section}>
                <Typography className={classes.sectionOverline}>
                  On the cluster
                </Typography>
                <Typography variant="h4" className={classes.sectionTitle}>
                  Platform tools
                </Typography>
                <Typography className={classes.sectionSubtext}>
                  The platform's own UIs, all signed in through the same
                  identity provider.
                </Typography>
                <Grid container spacing={3}>
                  {PLATFORM_TOOLS.map((tool, i) => (
                    <Grid item xs={12} sm={6} md={4} lg key={tool.href}>
                      <Link
                        to={tool.href}
                        className={`${classes.toolCard} ${classes.enter}`}
                        style={delay(i)}
                      >
                        <div className={classes.iconChip}>
                          <tool.icon />
                        </div>
                        <Typography className={classes.toolTitle}>
                          {tool.title}
                        </Typography>
                        <Typography className={classes.toolProduct}>
                          {tool.product}
                        </Typography>
                        <Typography className={classes.toolDescription}>
                          {tool.description}
                        </Typography>
                      </Link>
                    </Grid>
                  ))}
                </Grid>
              </section>

              <section className={classes.section}>
                <Typography className={classes.sectionOverline}>
                  Toolkit
                </Typography>
                <Typography variant="h4" className={classes.sectionTitle}>
                  Developer toolkit
                </Typography>
                <Typography className={classes.sectionSubtext}>
                  Quick access to the portal features you use every day.
                </Typography>
                <Grid container spacing={3}>
                  {TOOLKIT.map((item, i) => (
                    <Grid item xs={12} sm={6} md={4} key={item.title}>
                      <Link
                        to={item.href}
                        className={`${classes.rowCard} ${classes.enter}`}
                        style={delay(i)}
                      >
                        <div className={classes.rowIcon}>
                          <item.icon />
                        </div>
                        <div className={classes.rowText}>
                          <Typography className={classes.rowTitle}>
                            {item.title}
                          </Typography>
                          <Typography className={classes.rowDescription}>
                            {item.description}
                          </Typography>
                        </div>
                        <ArrowForwardIcon className={classes.rowArrow} />
                      </Link>
                    </Grid>
                  ))}
                </Grid>
              </section>
            </div>
          </div>
        </Content>
      </Page>
    </SearchContextProvider>
  );
};
