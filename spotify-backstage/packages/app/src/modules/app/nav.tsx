import { makeStyles } from '@material-ui/core';
import {
  Link,
  Sidebar,
  sidebarConfig,
  SidebarDivider,
  SidebarGroup,
  SidebarItem,
  SidebarScrollWrapper,
  SidebarSpace,
  SidebarSubmenu,
  SidebarSubmenuItem,
  useSidebarOpenState,
} from '@backstage/core-components';
import {
  NavContentBlueprint,
  type NavContentComponentProps,
} from '@backstage/plugin-app-react';
import { MyGroupsSidebarItem } from '@backstage/plugin-org';
import { NotificationsSidebarItem } from '@backstage/plugin-notifications';
import { SidebarSearchModal } from '@backstage/plugin-search';
import { UserSettingsSignInAvatar } from '@backstage/plugin-user-settings';
import AccountTreeIcon from '@material-ui/icons/AccountTree';
import CategoryIcon from '@material-ui/icons/Category';
import CreateComponentIcon from '@material-ui/icons/AddCircleOutline';
import ExtensionIcon from '@material-ui/icons/Extension';
import GroupIcon from '@material-ui/icons/People';
import HomeIcon from '@material-ui/icons/Home';
import LaunchIcon from '@material-ui/icons/Launch';
import LibraryBooks from '@material-ui/icons/LibraryBooks';
import MenuIcon from '@material-ui/icons/Menu';
import SearchIcon from '@material-ui/icons/Search';
import { LdpLogo, LdpMark } from '../../brand/Logo';
import { PLATFORM_TOOLS } from '../../platformTools';

const useLogoStyles = makeStyles({
  root: {
    width: sidebarConfig.drawerWidthClosed,
    height: 3 * sidebarConfig.logoHeight,
    display: 'flex',
    alignItems: 'center',
    marginBottom: -14,
  },
  link: { marginLeft: 22, display: 'flex', alignItems: 'center' },
});

const SidebarLogo = () => {
  const classes = useLogoStyles();
  const { isOpen } = useSidebarOpenState();
  return (
    <div className={classes.root}>
      <Link to="/" underline="none" className={classes.link} aria-label="Home">
        {isOpen ? <LdpLogo size={36} /> : <LdpMark size={36} />}
      </Link>
    </div>
  );
};

const LdpNav = ({ navItems }: NavContentComponentProps) => {
  // The menu is curated by hand, so discovered items are only taken where
  // this sidebar places them; anything else a plugin registers gets no entry
  // until it is added here.
  const nav = navItems.withComponent(({ title, icon, href }) => (
    <SidebarItem icon={() => icon} to={href} text={title} />
  ));
  // NotificationsSidebarItem below is the manual equivalent with the badge.
  nav.take('page:notifications');

  return (
    <Sidebar>
      <SidebarLogo />
      <SidebarGroup label="Search" icon={<SearchIcon />} to="/search">
        <SidebarSearchModal />
      </SidebarGroup>
      <SidebarDivider />
      <SidebarGroup label="Menu" icon={<MenuIcon />}>
        <SidebarItem icon={HomeIcon} to="/" text="Home" />
        <SidebarItem icon={CategoryIcon} to="catalog" text="Catalog" />
        <SidebarItem icon={ExtensionIcon} to="api-docs" text="APIs" />
        <SidebarItem icon={LibraryBooks} to="docs" text="Docs" />
        <SidebarItem icon={AccountTreeIcon} to="catalog-graph" text="Graph" />
        <MyGroupsSidebarItem
          singularTitle="My Group"
          pluralTitle="My Groups"
          icon={GroupIcon}
        />
        <SidebarItem icon={CreateComponentIcon} to="create" text="Create" />
        <SidebarDivider />
        <SidebarScrollWrapper>
          <SidebarItem icon={LaunchIcon} text="Platform Tools">
            <SidebarSubmenu title="Platform Tools">
              {PLATFORM_TOOLS.map(tool => (
                <SidebarSubmenuItem
                  key={tool.href}
                  title={`${tool.title} · ${tool.product}`}
                  to={tool.href}
                  icon={tool.icon}
                />
              ))}
            </SidebarSubmenu>
          </SidebarItem>
        </SidebarScrollWrapper>
      </SidebarGroup>
      <SidebarSpace />
      <SidebarDivider />
      <NotificationsSidebarItem />
      <SidebarDivider />
      <SidebarGroup
        label="Settings"
        icon={<UserSettingsSignInAvatar />}
        to="/settings"
      >
        {nav.take('page:app-visualizer')}
        {nav.take('page:user-settings')}
      </SidebarGroup>
    </Sidebar>
  );
};

// Unnamed, so it takes plugin-app's own `nav-content:app` id and replaces
// the default sidebar instead of competing with it for the singleton input.
export const nav = NavContentBlueprint.make({
  params: { component: props => <LdpNav {...props} /> },
});
