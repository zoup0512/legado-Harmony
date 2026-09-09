## 实施目标
实现一个可运行的第一版“隐私文件夹”：本地书籍可从“我的”进入隐私区域；隐私区域进入前需系统认证；隐私书籍与普通书架隔离；应用退后台/锁屏时锁定；可导入、查看、阅读、移出和删除。由于当前 `@kit.ReaderKit` 的实际入口是 `bookParser.getDefaultHandler(path)`，首版继续使用应用沙箱内路径，不在本次改动中实现自定义内存解析器或完整正文加密，并在界面中明确保护边界。

## 代码改动计划
1. **新增隐私状态与存储服务**
   - 新增 `entry/src/main/ets/privacy/PrivacyFolderService.ets`。
   - 以现有 `Books`/`BooksDao` 为基础，用专用 `bookGroup` 常量隔离隐私书籍；所有隐私查询集中在服务内，不让普通书架页面自行拼接条件。
   - 新增独立私密目录（随机/不透明文件名）和元数据文件，记录私密书籍 ID、原始路径映射、显示信息及迁移状态；使用应用沙箱文件 API，避免把原文件名作为私密文件名。
   - 提供 `list`, `importLocalBook`, `moveIn`, `moveOut`, `delete`, `clear`, `isPrivateBook` 等方法，并为复制/数据库写入失败保留源文件、清理半成品。
   - 第一版禁止联网书籍、普通备份/WebDAV 和分享流程带入隐私区域。

2. **新增认证与会话服务**
   - 新增 `entry/src/main/ets/privacy/PrivacySessionService.ets`。
   - 用 `@ohos.userIAM.userAuth` 的 `getUserAuthInstance`/认证回调实现系统认证；不保存认证 token、不自建明文 PIN。
   - 内存维护 `locked/unlocked/authenticating` 状态，提供 `unlock`, `lock`, `requireUnlock`。
   - 对 API/设备认证能力不可用、取消、失败统一保持锁定并返回可展示错误；不做无认证降级。
   - 认证服务与存储服务解耦，后续可接入 HUKS/CryptoFramework；当前先完成可靠门禁，避免在未确认 API16/真机能力前伪造加密安全。

3. **新增隐私文件夹页面**
   - 新增 `entry/src/main/ets/pages/view/myCenter/PrivacyFolder.ets`。
   - 未解锁时只显示锁定说明和“解锁”按钮，不加载书名/封面/数量。
   - 解锁后通过服务加载私密书籍列表；支持搜索、点击阅读、移出、删除、立即锁定。
   - 复用现有书架卡片/对话框样式，优先完成可用交互；导入入口调用系统文件选择器并直接写入隐私目录。
   - 进入阅读页前二次检查会话；从隐私阅读返回后不泄露到普通书架。

4. **接入“我的”页面和路由**
   - 在 `MyCenter.ets` 增加“隐私文件夹”入口及点击分支。
   - 在 `main_pages.json` 注册新页面路由。
   - 在页面入口处只显示静态名称，不显示私密数量或最近书名。

5. **接入普通书架/本地导入**
   - 在 `IndexShelf.ets` 的本地导入流程增加存储目标选择：普通书架或隐私文件夹；隐私目标先认证，再走专用服务，不先写普通记录。
   - 为本地书籍增加“移入隐私文件夹”动作（沿用现有长按/管理入口；若当前入口无完整动作，则先在隐私页实现导入和移出，避免扩大无关 UI 改造）。
   - 修正隐私书籍查询与普通查询的隔离，避免 SQL `AND/OR` 优先级造成绕过；隐私服务只按专用组查询，普通书架显式排除专用组。

6. **适配阅读进度与隐私键名**
   - 修改 `ReaderPage3.ets`：私密书籍使用不透明 ID 生成 `BookCurrentData`/`ReaderSetting` 键，不使用明文书名；进入和 `pageShow` 回调都校验会话。
   - 在离开阅读页、锁定或删除时清理私密阅读缓存；将进度同步到 BooksDao，避免只保存在 Preferences。
   - 保持 ReaderKit 使用私密沙箱路径，并在 `aboutToDisappear` 释放 handler。

7. **生命周期和窗口保护**
   - 修改 `EntryAbility.ets`：`onBackground` 调用隐私会话锁定并清理内存；`onForeground` 不自动恢复解锁状态。
   - 对目标 API 可用时再尝试窗口隐私模式；由于工程 compatible SDK 为 API16，而相关窗口 API 在 SDK 声明中从 API20 起，本次先采用编译兼容的应用层锁定/遮罩，不强行升级 SDK 或添加未经验证的 API 调用。

8. **文案与限制说明**
   - 在首次进入和设置页说明：只保护应用内副本；系统目录/云盘原文件不会自动删除；本首版不承诺外部文件管理器不可见。
   - 增加销毁隐私文件夹的二次确认，清除私密记录和副本，不声称物理闪存绝对擦除。

## 验证计划
- 先运行现有工程静态检查/构建：`./hvigorw assembleHap`。
- 增加隐私服务的本地单元测试（状态迁移、重复导入、失败回滚、锁定后拒绝访问）；若当前测试框架无法直接覆盖 entry，则至少执行 TypeScript/ArkTS 编译检查。
- 手工验证：首次进入认证、认证失败/取消、后台锁定、普通书架不显示私密条目、导入/阅读/移出/删除、进程重启后重新认证。
- 最终明确报告：已实现的门禁和隔离、未实现的正文级加密，以及 ReaderKit/API16 限制。

## 不在本次范围
- 自定义 `BookParserHandler` 或完全无明文落地的 ReaderKit 数据源。
- HUKS/CryptoFramework 正文加密，除非目标 SDK 的确切 API 和设备行为在实现阶段验证通过。
- 云同步、跨设备恢复、嵌套目录、联网书籍隐私缓存、独立应用 PIN。