import { createFrontendModule } from '@backstage/frontend-plugin-api';
import { AddonBlueprint } from '@backstage/plugin-techdocs-react/alpha';
import { ReportIssue } from '@backstage/plugin-techdocs-module-addons-contrib';
import { Mermaid } from 'backstage-plugin-techdocs-addon-mermaid';
import { BRAND, fontFamily } from '../../theme';

const reportIssue = AddonBlueprint.make({
  name: 'report-issue',
  params: { name: 'ReportIssue', location: 'Content', component: ReportIssue },
});

// Not the package's own module: it passes no theme, leaving mermaid's default palette.
const themeVariables = (dark: boolean) => ({
  fontFamily,
  primaryColor: dark ? BRAND.darkSurface : BRAND.white,
  primaryTextColor: dark ? BRAND.darkText : BRAND.ink,
  primaryBorderColor: dark ? BRAND.sky : BRAND.navy,
  lineColor: dark ? BRAND.darkTextSecondary : BRAND.slate,
  secondaryColor: dark ? BRAND.navy : BRAND.mist,
  tertiaryColor: dark ? BRAND.navyDeep : BRAND.white,
});

const ThemedMermaid = () => (
  <Mermaid
    lightConfig={{ theme: 'base', themeVariables: themeVariables(false) }}
    darkConfig={{ theme: 'base', themeVariables: themeVariables(true) }}
  />
);

const mermaid = AddonBlueprint.make({
  name: 'mermaid',
  params: { name: 'Mermaid', location: 'Content', component: ThemedMermaid },
});

export const techdocsModule = createFrontendModule({
  pluginId: 'techdocs',
  extensions: [reportIssue, mermaid],
});
