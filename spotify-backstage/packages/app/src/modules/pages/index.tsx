import homePlugin from '@backstage/plugin-home/alpha';

/**
 * The LDP home page replaces plugin-home's widget grid by overriding the
 * plugin's own `page:home` loader rather than adding a competing page, so its
 * routeRef stays mounted for everything that links home.
 *
 * `path: '/'` is required: upstream mounts at "/home" and params merge on
 * override, so omitting it would leave "/" unmounted. The page renders its
 * own hero, so it wants no plugin header either.
 */
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
