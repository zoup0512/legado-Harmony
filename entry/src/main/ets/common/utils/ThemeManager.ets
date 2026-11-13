import { ThemeColor, ThemeStorageKey } from "../constants/Theme";
import { ThemeItem } from "../model/Theme";

const DEFAULT_THEME: ThemeItem = {
  text: '黛蓝', mainColor: ThemeColor.INDIGO.mainColor, secondColor: ThemeColor.INDIGO.secondColor
}

export class ThemeManager {
  defaultTheme: ThemeItem = DEFAULT_THEME
  themeList: ThemeItem[] = [
    DEFAULT_THEME,
    {text: '主题2', mainColor: ThemeColor.RED.mainColor, secondColor: ThemeColor.RED.secondColor},
    {text: '主题3', mainColor: ThemeColor.GREEN.mainColor, secondColor: ThemeColor.GREEN.secondColor},
    {text: '主题4', mainColor: ThemeColor.YELLOW.mainColor, secondColor: ThemeColor.YELLOW.secondColor},
    {text: '主题5', mainColor: ThemeColor.BLUE.mainColor, secondColor: ThemeColor.BLUE.secondColor},
    {text: '主题6', mainColor: ThemeColor.ORANGE.mainColor, secondColor: ThemeColor.ORANGE.secondColor},
  ]

  init() {
    PersistentStorage.persistProp<ThemeItem>(ThemeStorageKey.THEME, this.defaultTheme)
    PersistentStorage.persistProp<string>(ThemeStorageKey.THEMELISTSTR, JSON.stringify(this.themeList))
    PersistentStorage.persistProp<number>(ThemeStorageKey.THEMEINDEX, 0) // 被选中主题的索引
    PersistentStorage.persistProp<boolean>(ThemeStorageKey.DEFAULT_MIGRATED, false)

    // 解析主题数组字符串 加载主题
    const str = AppStorage.get<string>(ThemeStorageKey.THEMELISTSTR)
    let themeList = JSON.parse(str as string) as ThemeItem[]
    if (!AppStorage.get<boolean>(ThemeStorageKey.DEFAULT_MIGRATED)) {
      themeList = this.migrateOrangeDefault(themeList)
      AppStorage.setOrCreate<boolean>(ThemeStorageKey.DEFAULT_MIGRATED, true)
    }
    AppStorage.setOrCreate<ThemeItem[]>(ThemeStorageKey.THEMELIST, themeList)
  }

  // 旧版本默认是橙色主题：补上黛蓝主题；仍在用旧默认橙色的用户切到黛蓝，自选其他主题的不动
  private migrateOrangeDefault(themeList: ThemeItem[]): ThemeItem[] {
    const sameColor = (a: string, b: string): boolean => (a ?? '').toLowerCase() === b.toLowerCase()
    let activeIndex = AppStorage.get<number>(ThemeStorageKey.THEMEINDEX) ?? 0
    if (!themeList.some((item: ThemeItem): boolean => sameColor(item.mainColor, this.defaultTheme.mainColor))) {
      themeList.unshift(this.defaultTheme)
      activeIndex++
      AppStorage.setOrCreate(ThemeStorageKey.THEMELISTSTR, JSON.stringify(themeList))
    }
    const current = AppStorage.get<ThemeItem>(ThemeStorageKey.THEME)
    if (!current || sameColor(current.mainColor, ThemeColor.ORANGE.mainColor)) {
      const index = themeList.findIndex((item: ThemeItem): boolean =>
        sameColor(item.mainColor, this.defaultTheme.mainColor))
      this.setTheme(themeList[index], index)
    } else {
      AppStorage.setOrCreate<number>(ThemeStorageKey.THEMEINDEX, activeIndex)
    }
    return themeList
  }

  setTheme(newTheme: ThemeItem, index: number) {
    AppStorage.setOrCreate<ThemeItem>(ThemeStorageKey.THEME, newTheme)
    AppStorage.setOrCreate<number>(ThemeStorageKey.THEMEINDEX, index)
  }

  addTheme(newTheme: ThemeItem) {
    const str = AppStorage.get<string>(ThemeStorageKey.THEMELISTSTR)
    const themeList = JSON.parse(str as string) as ThemeItem[]
    themeList.push(newTheme)
    AppStorage.setOrCreate(ThemeStorageKey.THEMELISTSTR, JSON.stringify(themeList))
    AppStorage.setOrCreate<ThemeItem[]>(ThemeStorageKey.THEMELIST, themeList)
  }

  deleteTheme(index: number) {
    const str = AppStorage.get<string>(ThemeStorageKey.THEMELISTSTR)
    let themeList = JSON.parse(str as string) as ThemeItem[]
    let activeIndex: number = AppStorage.get<number>(ThemeStorageKey.THEMEINDEX) as number
    if (activeIndex > index) {
        --activeIndex
    } else if (activeIndex == index) {
      activeIndex = 0
    }
    themeList = themeList.filter((item, i) => i != index)
    this.setTheme(themeList[activeIndex], activeIndex)
    AppStorage.setOrCreate(ThemeStorageKey.THEMELISTSTR, JSON.stringify(themeList))
    AppStorage.setOrCreate<ThemeItem[]>(ThemeStorageKey.THEMELIST, themeList)
  }
}

/**
 * 根据主题主色深浅返回状态栏文字颜色：深色主题用白字，浅色主题用黑字。
 * 按 WCAG 相对亮度比较与黑、白的对比度。
 */
export function statusBarContentColorFor(mainColor: string | undefined): string {
  let hex = (mainColor ?? '').replace('#', '')
  if (hex.length === 3) {
    hex = hex.split('').map((c: string): string => c + c).join('')
  }
  if (hex.length === 8) {
    hex = hex.substring(2)
  }
  if (hex.length !== 6) {
    return '#000000'
  }
  const channel = (start: number): number => {
    const v = parseInt(hex.substring(start, start + 2), 16) / 255
    return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
  }
  const luminance = 0.2126 * channel(0) + 0.7152 * channel(2) + 0.0722 * channel(4)
  const contrastWithWhite = 1.05 / (luminance + 0.05)
  const contrastWithBlack = (luminance + 0.05) / 0.05
  return contrastWithWhite > contrastWithBlack ? '#FFFFFF' : '#000000'
}

// 单例模式
export const themeManager = new ThemeManager()