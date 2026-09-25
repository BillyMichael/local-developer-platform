// Node built-ins are fine in a test; the rule guards the browser bundle.
// eslint-disable-next-line no-restricted-imports
import { readFileSync } from 'fs';
// eslint-disable-next-line no-restricted-imports
import { resolve } from 'path';
import { BRAND } from './tokens';
import { ldpDarkTheme, ldpLightTheme } from './themes';

const css = readFileSync(resolve(__dirname, '../global.css'), 'utf8');

// Values of --bui-* declared in the block ruled by `selector` alone, skipping
// selector lists such as `:root, [light], [dark] {`.
const block = (selector: string) => {
  let start = -1;
  do {
    start = css.indexOf(`${selector} {`, start + 1);
  } while (start > 0 && css.slice(0, start).trimEnd().endsWith(','));
  const body = css.slice(start, css.indexOf('}', start));
  return Object.fromEntries(
    [...body.matchAll(/(--bui-[\w-]+):\s*([^;]+);/g)].map(m => [m[1], m[2]]),
  );
};

describe('theme', () => {
  it('builds both modes', () => {
    expect((ldpLightTheme.getTheme('v4') as any).palette.type).toBe('light');
    expect((ldpDarkTheme.getTheme('v5') as any).palette.mode).toBe('dark');
  });

  it('keeps the BUI variables in step with BRAND', () => {
    const light = block("[data-theme-mode='light']");
    const dark = block("[data-theme-mode='dark']");
    const header = block("[class*='bui-PluginHeader__']");

    // Deprecated names, but BUI 0.18's primary Button still reads them.
    /* eslint-disable @backstage/no-deprecated-bui-tokens */
    expect(css).toContain(`--bui-bg-solid: ${BRAND.amber};`);
    expect(css).toContain(`--bui-fg-solid: ${BRAND.navyDeep};`);
    /* eslint-enable @backstage/no-deprecated-bui-tokens */
    expect(light['--bui-bg-app']).toBe(BRAND.mist);
    expect(light['--bui-card-surface']).toBe(BRAND.white);
    expect(dark['--bui-bg-app']).toBe(BRAND.navyDeep);
    expect(dark['--bui-card-surface']).toBe(BRAND.darkSurface);
    expect(dark['--bui-border-1']).toBe(BRAND.darkSurfaceBorder);
    expect(header['--bui-plugin-header-background-color']).toBe(BRAND.navyDeep);
  });
});
