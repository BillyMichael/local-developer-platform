import {
  ApiRef,
  BackstageIdentityApi,
  OpenIdConnectApi,
  ProfileInfoApi,
  SessionApi,
  createApiRef,
} from '@backstage/core-plugin-api';

/** Matches the `oidc` provider in the backend and auth.providers config. */
export const oidcAuthApiRef: ApiRef<
  OpenIdConnectApi & ProfileInfoApi & BackstageIdentityApi & SessionApi
> = createApiRef({
  id: 'auth.oidc',
});
