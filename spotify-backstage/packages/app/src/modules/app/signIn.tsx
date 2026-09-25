import { SignInPageBlueprint } from '@backstage/plugin-app-react';

// Unnamed, so it takes the id of plugin-app's own guest sign-in page
// (`sign-in-page:app`) and replaces it; a named one would compete with it
// for the singleton input and the app would fail to bootstrap.
export const signInPage = SignInPageBlueprint.make({
  params: {
    loader: () =>
      import('../../components/signin/LdpSignInPage').then(
        m => m.LdpSignInPage,
      ),
  },
});
