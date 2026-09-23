import { Sidebar } from '@backstage/core-components';
import { identityApiRef } from '@backstage/core-plugin-api';
import {
  mockApis,
  renderInTestApp,
  TestApiProvider,
} from '@backstage/test-utils';
import { screen } from '@testing-library/react';
import { BrandBlock, NavSearch, NavSection, UserFooter } from './nav';

describe('nav', () => {
  it('renders the rail pieces and resolves the signed-in user', async () => {
    await renderInTestApp(
      <TestApiProvider
        apis={[
          [
            identityApiRef,
            mockApis.identity({
              userEntityRef: 'user:default/billy',
              displayName: 'Billy M',
              email: 'billy@example.com',
            }),
          ],
        ]}
      >
        <Sidebar disableExpandOnHover>
          <BrandBlock />
          <NavSearch />
          <NavSection label="Platform">
            <span>item</span>
          </NavSection>
          <UserFooter />
        </Sidebar>
      </TestApiProvider>,
    );

    expect(screen.getByRole('link', { name: /home/i })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Search' })).toBeInTheDocument();
    expect(screen.getByRole('group', { name: 'Platform' })).toBeInTheDocument();
    expect(
      await screen.findByRole('link', { name: /Billy M/ }),
    ).toHaveAttribute('href', '/settings');
  });
});
