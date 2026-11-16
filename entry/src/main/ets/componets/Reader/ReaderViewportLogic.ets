// Platform-independent reader preferences and per-mounted-surface geometry.
export interface ReaderPreferences {
  fontName: string;
  fontPath: string;
  fontSize: number;
  fontColor: string;
  fontWeight: number;
  lineHeight: number;
  nightMode: boolean;
  themeColor: string;
  themeBgImg: string;
  flipMode: string;
}

export interface ReaderSurfaceSetting extends ReaderPreferences {
  viewPortWidth: number;
  viewPortHeight: number;
  scaledDensity: number;
}

export class ReaderViewportLogic {
  private runtimeId: number = -1;
  private widthVp: number = 0;
  private heightVp: number = 0;
  private revision: number = 0;
  private appliedRevision: number = -1;

  begin(runtimeId: number): void {
    this.runtimeId = runtimeId;
    this.widthVp = 0;
    this.heightVp = 0;
    this.changed();
    this.appliedRevision = -1;
  }

  dispose(): void {
    this.runtimeId = -1;
    this.widthVp = 0;
    this.heightVp = 0;
  }

  measure(runtimeId: number, widthVp: number, heightVp: number): boolean {
    if (runtimeId !== this.runtimeId || runtimeId < 0 || !Number.isFinite(widthVp) ||
      !Number.isFinite(heightVp) || widthVp <= 0 || heightVp <= 0) return false;
    if (widthVp === this.widthVp && heightVp === this.heightVp) return true;
    this.widthVp = widthVp;
    this.heightVp = heightVp;
    this.changed();
    return true;
  }

  changed(): void { this.revision++; }
  pending(): boolean { return this.revision !== this.appliedRevision; }
  applied(): void { this.appliedRevision = this.revision; }

  configuration(runtimeId: number, preferences: ReaderPreferences,
    vp2px: (value: number) => number, scaledDensity: number): ReaderSurfaceSetting | undefined {
    if (runtimeId !== this.runtimeId || runtimeId < 0 || this.widthVp <= 0 || this.heightVp <= 0) return undefined;
    const width = Math.round(vp2px(this.widthVp));
    const height = Math.round(vp2px(this.heightVp));
    if (!Number.isFinite(width) || !Number.isFinite(height) || width <= 0 || height <= 0) return undefined;
    const density = scaledDensity > 0 && Number.isFinite(scaledDensity) ? scaledDensity : vp2px(1);
    if (!Number.isFinite(density) || density <= 0) return undefined;
    // Explicit construction prevents old preference geometry from being restored or spread back in.
    return {
      fontName: preferences.fontName,
      fontPath: preferences.fontPath,
      fontSize: preferences.fontSize,
      fontColor: preferences.fontColor,
      fontWeight: preferences.fontWeight,
      lineHeight: preferences.lineHeight,
      nightMode: preferences.nightMode,
      themeColor: preferences.themeColor,
      themeBgImg: preferences.themeBgImg,
      flipMode: preferences.flipMode,
      viewPortWidth: width,
      viewPortHeight: height,
      scaledDensity: density
    };
  }

  static preferences(saved: ReaderPreferences, defaults: ReaderPreferences): ReaderPreferences {
    return {
      fontName: saved.fontName ?? defaults.fontName,
      fontPath: saved.fontPath ?? defaults.fontPath,
      fontSize: saved.fontSize ?? defaults.fontSize,
      fontColor: saved.fontColor ?? defaults.fontColor,
      fontWeight: saved.fontWeight ?? defaults.fontWeight,
      lineHeight: saved.lineHeight ?? defaults.lineHeight,
      nightMode: saved.nightMode ?? defaults.nightMode,
      themeColor: saved.themeColor ?? defaults.themeColor,
      themeBgImg: saved.themeBgImg ?? defaults.themeBgImg,
      flipMode: saved.flipMode ?? defaults.flipMode
    };
  }
}
