import homePlugin from '@backstage/plugin-home/alpha';

// Override page:home (not a new page) so its routeRef stays mounted. path '/' is
// required: params merge on override and upstream mounts at /home.
export const homePluginWithLdpHome = homePlugin.withOverrides({
  extensions: [
    homePlugin.getExtension('page:home').override({
      params: {
        path: '/',
        noHeader: true,
        loader: () =>
          import('../../components/home/HomePage').then(m => <m.HomePage />),
      },
    }),
  ],
});
