import { createBackendModule } from '@backstage/backend-plugin-api';
import {
  authProvidersExtensionPoint,
  createOAuthProviderFactory,
} from '@backstage/plugin-auth-node';
import { oidcAuthenticator } from '@backstage/plugin-auth-backend-module-oidc-provider';
import { DEFAULT_NAMESPACE } from '@backstage/catalog-model';

export const oidcAuthProviderModule = createBackendModule({
  pluginId: 'auth',
  moduleId: 'oidc-auth-provider',
  register(reg) {
    reg.registerInit({
      deps: { providers: authProvidersExtensionPoint },
      async init({ providers }) {
        providers.registerProvider({
          // Must match auth.providers.oidc in app-config.
          providerId: 'oidc',
          factory: createOAuthProviderFactory({
            authenticator: oidcAuthenticator,
            // Accounts the LDAP import skips (e.g. admin) fall back to a bare identity with no groups.
            async signInResolver(info, ctx) {
              const userinfo = info?.result.fullProfile.userinfo;
              const name = (userinfo?.preferred_username ??
                userinfo?.name) as string;
              const entityRef = {
                kind: 'User',
                namespace: DEFAULT_NAMESPACE,
                name,
              };
              return ctx.signInWithCatalogUser(
                { entityRef },
                { dangerousEntityRefFallback: { entityRef } },
              );
            },
          }),
        });
      },
    });
  },
});
