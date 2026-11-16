import { describe, expect, it } from '@ohos/hypium';
import { ReaderPreferences, ReaderSurfaceSetting, ReaderViewportLogic } from '../../../main/ets/componets/Reader/ReaderViewportLogic';

function preferences(): ReaderPreferences {
  return {
    fontName: '系统字体', fontPath: '', fontSize: 18, fontColor: '#000000', fontWeight: 400,
    lineHeight: 1.9, nightMode: false, themeColor: '#FFFFFF', themeBgImg: '', flipMode: '0'
  };
}

function pixels(value: number): number { return value * 2; }

export default function readerViewportLogicTest() {
  describe('ReaderViewportLogicTest', () => {
    it('oldSavedGeometryCannotOverrideMeasuredSurface', 0, () => {
      const saved: ReaderSurfaceSetting = {
        fontName: '系统字体', fontPath: '', fontSize: 24, fontColor: '#FFFFFF', fontWeight: 500,
        lineHeight: 2, nightMode: true, themeColor: '#202224', themeBgImg: '', flipMode: '1',
        viewPortWidth: 1080, viewPortHeight: 2400, scaledDensity: 3
      };
      const restored = ReaderViewportLogic.preferences(saved, preferences());
      const viewport = new ReaderViewportLogic();
      viewport.begin(1);
      expect(viewport.measure(1, 800, 600)).assertTrue();
      const config = viewport.configuration(1, restored, pixels, 2);
      expect(config !== undefined).assertTrue();
      if (!config) return;
      expect(config.viewPortWidth).assertEqual(1600);
      expect(config.viewPortHeight).assertEqual(1200);
      expect(config.scaledDensity).assertEqual(2);
      expect(config.fontSize).assertEqual(24);
      expect(config.nightMode).assertTrue();
    });

    it('initializationResizeKeepsLatestPendingGeometry', 0, () => {
      const viewport = new ReaderViewportLogic();
      viewport.begin(2);
      expect(viewport.configuration(2, preferences(), pixels, 2) === undefined).assertTrue();
      viewport.measure(2, 800, 600);
      viewport.applied();
      expect(viewport.pending()).assertFalse();
      viewport.measure(2, 500, 600);
      expect(viewport.pending()).assertTrue();
      const config = viewport.configuration(2, preferences(), pixels, 2);
      expect(config?.viewPortWidth).assertEqual(1000);
      viewport.applied();
      expect(viewport.pending()).assertFalse();
      viewport.changed();
      expect(viewport.pending()).assertTrue();
    });

    it('unchangedMeasurementDoesNotTriggerAnotherReflow', 0, () => {
      const viewport = new ReaderViewportLogic();
      viewport.begin(5);
      viewport.measure(5, 800, 600);
      viewport.applied();
      expect(viewport.measure(5, 800, 600)).assertTrue();
      expect(viewport.pending()).assertFalse();
    });

    it('staleOrDisposedRuntimeCannotUpdateGeometry', 0, () => {
      const viewport = new ReaderViewportLogic();
      viewport.begin(1);
      viewport.measure(1, 800, 600);
      viewport.begin(2);
      expect(viewport.measure(1, 400, 600)).assertFalse();
      expect(viewport.configuration(1, preferences(), pixels, 2) === undefined).assertTrue();
      expect(viewport.configuration(2, preferences(), pixels, 2) === undefined).assertTrue();
      viewport.measure(2, 600, 500);
      viewport.dispose();
      expect(viewport.measure(2, 800, 600)).assertFalse();
      expect(viewport.configuration(2, preferences(), pixels, 2) === undefined).assertTrue();
    });

    it('rejectsZeroNegativeAndInvalidMeasurements', 0, () => {
      const viewport = new ReaderViewportLogic();
      viewport.begin(3);
      expect(viewport.measure(3, 0, 600)).assertFalse();
      expect(viewport.measure(3, 800, -1)).assertFalse();
      expect(viewport.measure(3, Number.NaN, 600)).assertFalse();
      expect(viewport.measure(3, 800, Number.POSITIVE_INFINITY)).assertFalse();
      expect(viewport.measure(3, 800, 600)).assertTrue();
      expect(viewport.configuration(3, preferences(), (): number => 0, 2) === undefined).assertTrue();
    });

    it('fallbackDensityUsesCurrentUiConversion', 0, () => {
      const viewport = new ReaderViewportLogic();
      viewport.begin(4);
      viewport.measure(4, 400.25, 600.25);
      const config = viewport.configuration(4, preferences(), pixels, 0);
      expect(config?.scaledDensity).assertEqual(2);
      expect(config?.viewPortWidth).assertEqual(801);
      expect(config?.viewPortHeight).assertEqual(1201);
    });
  });
}
