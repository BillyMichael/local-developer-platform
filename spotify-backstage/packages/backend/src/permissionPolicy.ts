import { createBackendModule } from '@backstage/backend-plugin-api';
import {
  PolicyDecision,
  AuthorizeResult,
  isResourcePermission,
} from '@backstage/plugin-permission-common';
import {
  PermissionPolicy,
  PolicyQuery,
  PolicyQueryUser,
} from '@backstage/plugin-permission-node';
import { policyExtensionPoint } from '@backstage/plugin-permission-node/alpha';
import { catalogEntityDeletePermission } from '@backstage/plugin-catalog-common/alpha';

export class PlatformPermissionPolicy implements PermissionPolicy {
  async handle(
    request: PolicyQuery,
    user?: PolicyQueryUser,
  ): Promise<PolicyDecision> {
    if (!user) {
      return { result: AuthorizeResult.DENY };
    }

    if (
      isResourcePermission(request.permission, 'catalog-entity') &&
      request.permission.name === catalogEntityDeletePermission.name
    ) {
      const isMaintainer = user.info.ownershipEntityRefs?.includes(
        'group:default/platform_maintainers',
      );
      return {
        result: isMaintainer ? AuthorizeResult.ALLOW : AuthorizeResult.DENY,
      };
    }

    return { result: AuthorizeResult.ALLOW };
  }
}

export const platformPermissionModule = createBackendModule({
  pluginId: 'permission',
  moduleId: 'platform-policy',
  register(reg) {
    reg.registerInit({
      deps: { policy: policyExtensionPoint },
      async init({ policy }) {
        policy.setPolicy(new PlatformPermissionPolicy());
      },
    });
  },
});
