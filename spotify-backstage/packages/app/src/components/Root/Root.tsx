import { PropsWithChildren } from 'react';
import { makeStyles } from '@material-ui/core';
import CategoryIcon from '@material-ui/icons/Category';
import ExtensionIcon from '@material-ui/icons/Extension';
import LibraryBooks from '@material-ui/icons/LibraryBooks';
import AccountTreeIcon from '@material-ui/icons/AccountTree';
import CreateComponentIcon from '@material-ui/icons/AddCircleOutline';
import GroupIcon from '@material-ui/icons/People';
import MenuIcon from '@material-ui/icons/Menu';
import SearchIcon from '@material-ui/icons/Search';
import { UserSettingsSignInAvatar } from '@backstage/plugin-user-settings';
import {
  Sidebar,
  SidebarGroup,
  SidebarItem,
  SidebarPage,
  SidebarScrollWrapper,
  SidebarSpace,
} from '@backstage/core-components';
import { MyGroupsSidebarItem } from '@backstage/plugin-org';
import { NotificationsSidebarItem } from '@backstage/plugin-notifications';
import { BrandBlock, NavSearch, NavSection, UserFooter } from './nav';

const useStyles = makeStyles({
  bottom: {
    width: '100%',
    paddingTop: 8,
    borderTop: '1px solid rgba(255,255,255,0.08)',
  },
});

export const Root = ({ children }: PropsWithChildren<{}>) => {
  const classes = useStyles();
  return (
    <SidebarPage>
      <Sidebar>
        <BrandBlock />
        <SidebarGroup label="Search" icon={<SearchIcon />} to="/search">
          <NavSearch />
        </SidebarGroup>
        <SidebarGroup label="Menu" icon={<MenuIcon />}>
          <SidebarScrollWrapper>
            <NavSection label="Platform">
              <SidebarItem icon={CategoryIcon} to="catalog" text="Catalog" />
              <SidebarItem icon={ExtensionIcon} to="api-docs" text="APIs" />
              <SidebarItem icon={LibraryBooks} to="docs" text="Docs" />
              <SidebarItem
                icon={AccountTreeIcon}
                to="catalog-graph"
                text="Graph"
              />
              <MyGroupsSidebarItem
                singularTitle="My Group"
                pluralTitle="My Groups"
                icon={GroupIcon}
              />
            </NavSection>
            <NavSection label="Build">
              <SidebarItem
                icon={CreateComponentIcon}
                to="create"
                text="Create"
              />
            </NavSection>
          </SidebarScrollWrapper>
        </SidebarGroup>
        <SidebarSpace />
        <div className={classes.bottom}>
          <NotificationsSidebarItem />
          <SidebarGroup
            label="Settings"
            icon={<UserSettingsSignInAvatar />}
            to="/settings"
          >
            <UserFooter />
          </SidebarGroup>
        </div>
      </Sidebar>
      {children}
    </SidebarPage>
  );
};
