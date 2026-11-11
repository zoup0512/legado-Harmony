import PrivacyFolderView from './PrivacyFolderView';

/**
 * 独立的隐私文件夹页面（带返回按钮）。内容与首页“隐私”Tab 共用 PrivacyFolderView。
 */
@Entry
@Component
export default struct PrivacyFolder {
  @State visible: boolean = true;

  onPageShow(): void {
    this.visible = true;
  }

  onPageHide(): void {
    this.visible = false;
  }

  build() {
    Column() {
      // enterSeq = 1：进入页面时尝试一次指纹/人脸自动解锁
      PrivacyFolderView({ visible: this.visible, enterSeq: 1, embedded: false })
    }
    .width('100%')
    .height('100%')
  }
}
