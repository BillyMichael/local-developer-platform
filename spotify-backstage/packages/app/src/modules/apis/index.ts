import {
  ApiBlueprint,
  createFrontendModule,
} from '@backstage/frontend-plugin-api';
import {
  configApiRef,
  discoveryApiRef,
  oauthRequestApiRef,
} from '@backstage/core-plugin-api';
import { OAuth2 } from '@backstage/core-app-api';
import { oidcAuthApiRef } from './oidcAuthApiRef';

const oidcAuthApi = ApiBlueprint.make({
  name: 'oidc-auth',
  params: defineParams =>
    defineParams({
      api: oidcAuthApiRef,
      deps: {
        discoveryApi: discoveryApiRef,
        oauthRequestApi: oauthRequestApiRef,
        configApi: configApiRef,
      },
      factory: ({ discoveryApi, oauthRequestApi, configApi }) =>
        OAuth2.create({
          discoveryApi,
          oauthRequestApi,
          provider: { id: 'oidc', title: 'Platform SSO', icon: () => null },
          environment: configApi.getOptionalString('auth.environment'),
          defaultScopes: ['openid', 'profile', 'email'],
          popupOptions: { size: { width: 1000, height: 1000 } },
        }),
    }),
});

// plugin-app already provides the SCM integrations and SCM auth APIs.
export const apisModule = createFrontendModule({
  pluginId: 'app',
  extensions: [oidcAuthApi],
});
