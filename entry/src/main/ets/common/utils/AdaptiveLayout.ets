export class AdaptiveLayout {
  static breakpoint(width: number): string {
    if (width < 320) return 'xs';
    if (width < 600) return 'sm';
    if (width < 840) return 'md';
    return 'lg';
  }

  static usesNavigationRail(width: number): boolean {
    return width >= 600;
  }

  static shelfColumns(width: number): number {
    if (width <= 0) return 3;
    return Math.max(1, Math.min(10, Math.floor((width + 12) / 112)));
  }

  static contentWidth(width: number, maximum: number = 840): number {
    return Math.max(0, Math.min(width, maximum));
  }

  static panelWidth(width: number): number {
    return AdaptiveLayout.contentWidth(width, 560);
  }

  static readerWidth(width: number): number {
    return AdaptiveLayout.contentWidth(width, 800);
  }
}
