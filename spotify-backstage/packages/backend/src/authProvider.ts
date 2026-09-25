import { createBackendModule } from '@backstage/backend-plugin-api';
import {
  authProvidersExtensionPoint,
  createOAuthProviderFactory,
} from '@backstage/plugin-auth-node';
import { oidcAuthenticator } from '@backstage/plugin-auth-backend-module-oidc-provider';
import {
  DEFAULT_NAMESPACE,
  stringifyEntityRef,
} from '@backstage/catalog-model';

/**
 * The platform OIDC provider (Authelia over LLDAP). Signs the user in as
 * user:default/<preferred_username>, matching the User entities the LDAP
 * provider imports.
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
              const userRef = stringifyEntityRef({
                kind: 'User',
                name: (userinfo?.preferred_username ??
                  userinfo?.name) as string,
                namespace: DEFAULT_NAMESPACE,
              });
              return ctx.issueToken({
                claims: { sub: userRef, ent: [userRef] },
              });
            },
          }),
        });
      },
    });
  },
});
