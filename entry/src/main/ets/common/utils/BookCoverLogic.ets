import { fileUri } from '@kit.CoreFileKit';
import { LocalBookAccessLogic } from './LocalBookAccess';

// customCoverUrl 取该值表示用户选择了“文字封面”，即使书内有封面也不使用
export const TEXT_COVER: string = 'text-cover://';

// 文字封面底色：低饱和、与各主题色都协调的一组颜色
const TEXT_COVER_PALETTE: string[][] = [
  ['#3f8f6e', '#2a6a50'],
  ['#4a6b94', '#334d70'],
  ['#9a6a45', '#74492c'],
  ['#7b5a93', '#5a3f70'],
  ['#b0634a', '#874433'],
  ['#3f8592', '#2b626d'],
  ['#6f7f45', '#50602d'],
  ['#8a5468', '#673a4c'],
];

export class BookCoverLogic {
  /** 按优先级返回可显示的封面图片地址：用户自定义 > 书内提取；返回空串表示使用文字封面 */
  static imageSourceOf(customCoverUrl?: string, coverUrl?: string): string {
    if (customCoverUrl === TEXT_COVER) {
      return '';
    }
    for (const source of [customCoverUrl, coverUrl]) {
      if (source && LocalBookAccessLogic.selectLocalCover(source, '') !== '') {
        return BookCoverLogic.toImageUri(source);
      }
    }
    return '';
  }

  /** 私有目录中的绝对路径需转为沙箱 URI 才能被 Image 加载 */
  static toImageUri(source: string): string {
    return source.startsWith('/') ? fileUri.getUriFromPath(source) : source;
  }

  /** 与 selectLocalCover 相同的校验，但返回可直接交给 Image 的地址（用于分组/书单封面） */
  static displaySource(source: ResourceStr | undefined, fallback: ResourceStr): ResourceStr {
    const selected = LocalBookAccessLogic.selectLocalCover(source, fallback);
    return typeof selected === 'string' && selected !== fallback ? BookCoverLogic.toImageUri(selected) : selected;
  }

  /** 由书名稳定地分配一组渐变色，同一本书每次颜色一致 */
  static paletteOf(name: string): string[] {
    let hash = 0;
    for (let i = 0; i < name.length; i++) {
      hash = (hash * 31 + name.charCodeAt(i)) | 0;
    }
    return TEXT_COVER_PALETTE[Math.abs(hash) % TEXT_COVER_PALETTE.length];
  }

  /** 文字封面上显示的书名：去掉扩展名和首尾空白 */
  static displayTitleOf(name: string): string {
    const title = (name ?? '').trim().replace(/\.(txt|epub|mobi|azw3?)$/i, '').trim();
    return title.length > 0 ? title : '未命名';
  }
}
