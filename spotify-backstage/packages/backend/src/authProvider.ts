import { createBackendModule } from '@backstage/backend-plugin-api';
import {
  authProvidersExtensionPoint,
  createOAuthProviderFactory,
} from '@backstage/plugin-auth-node';
import { oidcAuthenticator } from '@backstage/plugin-auth-backend-module-oidc-provider';
import { DEFAULT_NAMESPACE } from '@backstage/catalog-model';

/**
 * The platform OIDC provider (Authelia over LLDAP). Signs the user in as
 * user:default/<preferred_username> and resolves their ownership from the
 * catalog, so the token carries the LDAP groups (group:default/...) the
 * permission policy checks. Accounts the LDAP import skips, such as admin,
 * fall back to a bare user identity with no group memberships.
 */
export const oidcAuthProviderModule = createBackendModule({
  // Must be "auth": the plugin this module extends.
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
