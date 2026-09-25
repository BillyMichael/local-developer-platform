import { AuthorizeResult } from '@backstage/plugin-permission-common';
import { PolicyQueryUser } from '@backstage/plugin-permission-node';
import {
  catalogEntityDeletePermission,
  catalogEntityReadPermission,
} from '@backstage/plugin-catalog-common/alpha';
import { PlatformPermissionPolicy } from './permissionPolicy';

const userWith = (...ownershipEntityRefs: string[]) =>
  ({
    identity: {
      type: 'user',
      userEntityRef: ownershipEntityRefs[0],
      ownershipEntityRefs,
    },
    info: { userEntityRef: ownershipEntityRefs[0], ownershipEntityRefs },
    credentials: {} as any,
    token: 'token',
  } as unknown as PolicyQueryUser);

describe('PlatformPermissionPolicy', () => {
  const policy = new PlatformPermissionPolicy();
  const del = { permission: catalogEntityDeletePermission };
  const read = { permission: catalogEntityReadPermission };

  it('denies unauthenticated requests', async () => {
    expect((await policy.handle(read)).result).toBe(AuthorizeResult.DENY);
  });

  it('allows signed-in users everything but entity deletion', async () => {
    const user = userWith('user:default/dev', 'group:default/developers');
    expect((await policy.handle(read, user)).result).toBe(
      AuthorizeResult.ALLOW,
    );
    expect((await policy.handle(del, user)).result).toBe(AuthorizeResult.DENY);
  });

  it('lets platform_maintainers delete entities', async () => {
    const user = userWith(
      'user:default/admin',
      'group:default/platform_maintainers',
    );
    expect((await policy.handle(del, user)).result).toBe(AuthorizeResult.ALLOW);
  });
});
