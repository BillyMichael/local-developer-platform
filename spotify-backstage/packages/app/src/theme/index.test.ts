import { createLdpTheme } from './index';
import { dark, light } from './tokens';

describe('createLdpTheme', () => {
  it.each([
    ['light', light],
    ['dark', dark],
  ])('builds a v4 and v5 theme for %s mode', (_name, mode) => {
    // Throws if any component override is undefined or a default style
    // function is invoked with a bad theme (both only surface at runtime).
    const theme = createLdpTheme(mode);
    const v4 = theme.getTheme('v4') as any;
    const v5 = theme.getTheme('v5') as any;

    expect(v4.palette.type).toBe(mode.mode);
    expect(v5.palette.mode).toBe(mode.mode);
    expect(v4.shape.borderRadius).toBe(8);
    expect(v5.shape.borderRadius).toBe(8);
  });

  it('exposes overrides for the components plugins use', () => {
    const v4 = createLdpTheme(light).getTheme('v4') as any;
    for (const key of [
      'MuiCard',
      'MuiButton',
      'MuiChip',
      'BackstageHeader',
      'BackstageSidebarItem',
    ]) {
      expect(v4.overrides[key]).toBeDefined();
    }
    expect(v4.props.MuiTextField).toEqual({ variant: 'outlined' });
  });

  it('emits @backstage/ui variables from the same tokens', () => {
    const v4 = createLdpTheme(dark).getTheme('v4') as any;
    const globals = v4.overrides.MuiCssBaseline['@global'];
    const sel = "body[data-theme-mode='dark']";
    expect(globals[sel]['--bui-accent-bg']).toBe(dark.primary.main);
    expect(globals[sel]['--bui-bg-app']).toBe(dark.n.bg);
  });
});
