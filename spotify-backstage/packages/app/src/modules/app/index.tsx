import { createFrontendModule } from '@backstage/frontend-plugin-api';
import { AppRootElementBlueprint } from '@backstage/frontend-plugin-api';
import { SignalsDisplay } from '@backstage/plugin-signals';
import { darkTheme, lightTheme } from './themes';
import { signInPage } from './signIn';
import { nav } from './nav';

// The signals plugin's alpha entry registers only its API; the display that
// holds the connection open is mounted here. plugin-app already supplies the
// alert display and OAuth request dialog.
const signalsDisplay = AppRootElementBlueprint.make({
  name: 'signals-display',
  params: { element: <SignalsDisplay /> },
});

// pluginId 'app': the theme, sign-in and nav blueprints are restricted to it.
export const appModule = createFrontendModule({
  pluginId: 'app',
  extensions: [lightTheme, darkTheme, signInPage, nav, signalsDisplay],
});
