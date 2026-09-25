import { createApp } from '@backstage/frontend-defaults';
import catalogPlugin from '@backstage/plugin-catalog/alpha';
import catalogGraphPlugin from '@backstage/plugin-catalog-graph/alpha';
import catalogImportPlugin from '@backstage/plugin-catalog-import/alpha';
import apiDocsPlugin from '@backstage/plugin-api-docs/alpha';
import scaffolderPlugin from '@backstage/plugin-scaffolder/alpha';
import techdocsPlugin from '@backstage/plugin-techdocs/alpha';
import searchPlugin from '@backstage/plugin-search/alpha';
import orgPlugin from '@backstage/plugin-org/alpha';
import userSettingsPlugin from '@backstage/plugin-user-settings/alpha';
import notificationsPlugin from '@backstage/plugin-notifications/alpha';
import signalsPlugin from '@backstage/plugin-signals/alpha';
import kubernetesPlugin from '@backstage/plugin-kubernetes/alpha';
import appVisualizerPlugin from '@backstage/plugin-app-visualizer';
import appModuleUserSettings from '@backstage/plugin-app-module-user-settings';
import readmePlugin from '@axis-backstage/plugin-readme/alpha';
import { apisModule } from './modules/apis';
import { appModule } from './modules/app';
import { homePluginWithLdpHome } from './modules/pages';
import { techdocsModule } from './modules/techdocs';

/**
 * Features are listed explicitly rather than discovered (`app.packages`), so
 * adding a plugin to package.json does nothing until it is added here. Each
 * plugin supplies its own pages, entity cards and tabs; app-config.yaml's
 * `app.extensions` scopes the ones whose defaults are too broad.
 */
export default createApp({
  features: [
    catalogPlugin,
    catalogGraphPlugin,
    catalogImportPlugin,
    apiDocsPlugin,
    scaffolderPlugin,
    techdocsPlugin,
    searchPlugin,
    orgPlugin,
    userSettingsPlugin,
    notificationsPlugin,
    signalsPlugin,
    kubernetesPlugin,
    readmePlugin,
    homePluginWithLdpHome,
    appVisualizerPlugin,
    appModuleUserSettings,
    apisModule,
    appModule,
    techdocsModule,
  ],
});
