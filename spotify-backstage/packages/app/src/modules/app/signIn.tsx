import { SignInPageBlueprint } from '@backstage/plugin-app-react';

// Unnamed, so it replaces `sign-in-page:app`; a named one fails bootstrap.
export const signInPage = SignInPageBlueprint.make({
  params: {
    loader: () =>
      import('../../components/signin/LdpSignInPage').then(
        m => m.LdpSignInPage,
      ),
  },
});
