import { describe, expect, it } from '@ohos/hypium';
import { AdaptiveLayout } from '../../../main/ets/common/utils/AdaptiveLayout';

export default function adaptiveLayoutTest() {
  describe('AdaptiveLayoutTest', () => {
    it('breakpointsUseWindowVpBoundaries', 0, () => {
      expect(AdaptiveLayout.breakpoint(319)).assertEqual('xs');
      expect(AdaptiveLayout.breakpoint(320)).assertEqual('sm');
      expect(AdaptiveLayout.breakpoint(599)).assertEqual('sm');
      expect(AdaptiveLayout.breakpoint(600)).assertEqual('md');
      expect(AdaptiveLayout.breakpoint(839)).assertEqual('md');
      expect(AdaptiveLayout.breakpoint(840)).assertEqual('lg');
    });

    it('splitWindowRestoresCompactNavigation', 0, () => {
      expect(AdaptiveLayout.usesNavigationRail(1280)).assertTrue();
      expect(AdaptiveLayout.usesNavigationRail(600)).assertTrue();
      expect(AdaptiveLayout.usesNavigationRail(599)).assertFalse();
      expect(AdaptiveLayout.usesNavigationRail(360)).assertFalse();
    });

    it('shelfColumnsFollowContentAreaRatherThanScreen', 0, () => {
      expect(AdaptiveLayout.shelfColumns(0)).assertEqual(3);
      expect(AdaptiveLayout.shelfColumns(100)).assertEqual(1);
      expect(AdaptiveLayout.shelfColumns(220)).assertEqual(2);
      expect(AdaptiveLayout.shelfColumns(336)).assertEqual(3);
      expect(AdaptiveLayout.shelfColumns(700)).assertEqual(6);
      expect(AdaptiveLayout.shelfColumns(1120)).assertEqual(10);
      expect(AdaptiveLayout.shelfColumns(2000)).assertEqual(10);
    });

    it('panelsNeverExceedAvailableWidth', 0, () => {
      expect(AdaptiveLayout.panelWidth(360)).assertEqual(360);
      expect(AdaptiveLayout.panelWidth(560)).assertEqual(560);
      expect(AdaptiveLayout.panelWidth(1280)).assertEqual(560);
      expect(AdaptiveLayout.panelWidth(-1)).assertEqual(0);
    });

    it('readerSurfaceHasReadableLineWidth', 0, () => {
      expect(AdaptiveLayout.readerWidth(360)).assertEqual(360);
      expect(AdaptiveLayout.readerWidth(799)).assertEqual(799);
      expect(AdaptiveLayout.readerWidth(800)).assertEqual(800);
      expect(AdaptiveLayout.readerWidth(1280)).assertEqual(800);
    });

    it('shelfListWidthFollowsAvailableAreaAcrossResize', 0, () => {
      expect(AdaptiveLayout.contentWidth(839)).assertEqual(839);
      expect(AdaptiveLayout.contentWidth(840)).assertEqual(840);
      expect(AdaptiveLayout.contentWidth(841)).assertEqual(840);
      expect(AdaptiveLayout.contentWidth(1320)).assertEqual(840);
      expect(AdaptiveLayout.contentWidth(320)).assertEqual(320);
      expect(AdaptiveLayout.contentWidth(1320)).assertEqual(840);
    });

    it('contentWidthSupportsNarrowAndWideWindows', 0, () => {
      expect(AdaptiveLayout.contentWidth(320)).assertEqual(320);
      expect(AdaptiveLayout.contentWidth(1200)).assertEqual(840);
      expect(AdaptiveLayout.contentWidth(1200, 960)).assertEqual(960);
    });
  });
}
