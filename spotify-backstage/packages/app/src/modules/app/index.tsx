import { createFrontendModule } from '@backstage/frontend-plugin-api';
import { AppRootElementBlueprint } from '@backstage/frontend-plugin-api';
import { SignalsDisplay } from '@backstage/plugin-signals';
import { darkTheme, lightTheme } from './themes';
import { signInPage } from './signIn';
import { nav } from './nav';

// The signals alpha plugin registers only its API; this holds the connection open.
const signalsDisplay = AppRootElementBlueprint.make({
  name: 'signals-display',
  params: { element: <SignalsDisplay /> },
});

// Theme, sign-in and nav blueprints are restricted to pluginId 'app'.
export const appModule = createFrontendModule({
  pluginId: 'app',
  extensions: [lightTheme, darkTheme, signInPage, nav, signalsDisplay],
});
