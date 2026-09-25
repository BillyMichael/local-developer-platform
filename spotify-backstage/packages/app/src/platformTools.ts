import type { IconComponent } from '@backstage/core-plugin-api';
import CodeIcon from '@material-ui/icons/Code';
import SyncIcon from '@material-ui/icons/Sync';
import TrendingUpIcon from '@material-ui/icons/TrendingUp';
import AndroidIcon from '@material-ui/icons/Android';
import VpnKeyIcon from '@material-ui/icons/VpnKey';

/**
 * The platform UIs a user can open from the portal, in the order they meet
 * them: code, delivery, promotion, agents, identity. Shared by the sidebar's
 * Platform Tools submenu and the home page so the two never drift.
 */
export const PLATFORM_TOOLS: {
  title: string;
  product: string;
  description: string;
  href: string;
  icon: IconComponent;
}[] = [
  {
    title: 'Source',
    product: 'Gitea',
    description: 'Git hosting, CI and the package registry',
    href: 'https://vcs-127-0-0-1.nip.io',
    icon: CodeIcon,
  },
  {
    title: 'Delivery',
    product: 'Argo CD',
    description: 'GitOps sync for every app on the cluster',
    href: 'https://cd-127-0-0-1.nip.io',
    icon: SyncIcon,
  },
  {
    title: 'Releases',
    product: 'Kargo',
    description: 'Promote freight between stages',
    href: 'https://kargo-127-0-0-1.nip.io',
    icon: TrendingUpIcon,
  },
  {
    title: 'Agents',
    product: 'kagent',
    description: 'AI agents running on the cluster',
    href: 'https://agents-127-0-0-1.nip.io',
    icon: AndroidIcon,
  },
  {
    title: 'Identity',
    product: 'Authelia',
    description: 'Single sign-on for the platform',
    href: 'https://auth-127-0-0-1.nip.io',
    icon: VpnKeyIcon,
  },
];
