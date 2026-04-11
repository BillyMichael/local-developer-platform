import {
  createBackendModule,
  coreServices,
} from '@backstage/backend-plugin-api';
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

class PlatformPermissionPolicy implements PermissionPolicy {
  async handle(
    request: PolicyQuery,
    user?: PolicyQueryUser,
  ): Promise<PolicyDecision> {
    // Deny all unauthenticated requests
    if (!user) {
      return { result: AuthorizeResult.DENY };
    }

    // Restrict catalog entity deletion to platform_maintainers
    if (
      isResourcePermission(request.permission, 'catalog-entity') &&
      request.permission.name === catalogEntityDeletePermission.name
    ) {
      const groups =
        user.info.ownershipEntityRefs?.filter(ref =>
          ref.startsWith('group:default/'),
        ) ?? [];
      const isMaintainer = groups.some(
        ref => ref === 'group:default/platform_maintainers',
      );
      return {
        result: isMaintainer
          ? AuthorizeResult.ALLOW
          : AuthorizeResult.DENY,
      };
    }

    // Allow all other actions for authenticated users
    return { result: AuthorizeResult.ALLOW };
  }
}

export const platformPermissionModule = createBackendModule({
  pluginId: 'permission',
  moduleId: 'platform-policy',
  register(reg) {
    reg.registerInit({
      deps: {
        policy: policyExtensionPoint,
        logger: coreServices.logger,
      },
      async init({ policy, logger }) {
        logger.info('Using platform permission policy');
        policy.setPolicy(new PlatformPermissionPolicy());
      },
    });
  },
});
