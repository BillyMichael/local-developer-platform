import { createBackend } from '@backstage/backend-defaults';
import { oidcAuthProviderModule } from './authProvider';
import { platformPermissionModule } from './permissionPolicy';

const backend = createBackend();

backend.add(import('@backstage/plugin-app-backend'));
backend.add(import('@backstage/plugin-proxy-backend'));

// auth — OIDC only; there is deliberately no guest provider
backend.add(import('@backstage/plugin-auth-backend'));
backend.add(oidcAuthProviderModule);

// scaffolder — publishes to Gitea or GitHub
backend.add(import('@backstage/plugin-scaffolder-backend'));
backend.add(import('@backstage/plugin-scaffolder-backend-module-gitea'));
backend.add(import('@backstage/plugin-scaffolder-backend-module-github'));
backend.add(
  import('@backstage/plugin-scaffolder-backend-module-notifications'),
);

// techdocs
backend.add(import('@backstage/plugin-techdocs-backend'));

// catalog
backend.add(import('@backstage/plugin-catalog-backend'));
backend.add(
  import('@backstage/plugin-catalog-backend-module-scaffolder-entity-model'),
);
backend.add(import('@backstage/plugin-catalog-backend-module-logs'));
backend.add(import('@backstage/plugin-catalog-backend-module-github'));
// Gitea discovery: registers repos from catalog.providers.gitea
backend.add(import('@backstage/plugin-catalog-backend-module-gitea'));
// LLDAP users and groups from catalog.providers.ldapOrg
backend.add(import('@backstage/plugin-catalog-backend-module-ldap'));

// permission
backend.add(import('@backstage/plugin-permission-backend'));
backend.add(platformPermissionModule);

// search, on the Postgres engine
backend.add(import('@backstage/plugin-search-backend'));
backend.add(import('@backstage/plugin-search-backend-module-pg'));
backend.add(import('@backstage/plugin-search-backend-module-catalog'));
backend.add(import('@backstage/plugin-search-backend-module-techdocs'));

// kubernetes
backend.add(import('@backstage/plugin-kubernetes-backend'));

// README tab: serves the README.md beside each entity's catalog-info.yaml,
// read through the Gitea/GitHub integrations
backend.add(import('@axis-backstage/plugin-readme-backend'));

// user settings, notifications and signals
backend.add(import('@backstage/plugin-user-settings-backend'));
backend.add(import('@backstage/plugin-notifications-backend'));
backend.add(import('@backstage/plugin-signals-backend'));

backend.start();
