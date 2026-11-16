# 鸿蒙平板模拟器截图

## 环境与验证边界

- 模拟器：Harmony24 Tablet，HarmonyOS 7.0.0 / API 26。
- 屏幕：2880 × 1920，密度 2.0，约 1440 × 960vp。
- 截图时间：2026-11-15 至 2026-11-16。
- 模拟器镜像缺少 ReaderKit HSP，因此使用独立工程副本中的 ReaderKit 桩版构建验证界面；正式源码保持真实 ReaderKit 导入。
- 这些截图用于导航、书架、隐私入口、主题、导入页的布局验证，不代表真实阅读排版、翻页或进度连续性已验证。
- 截图编号保留采集时的编号；重复截图已去除，因此编号不连续。

## 截图索引

| 编号 | 场景 | 截图 |
|---|---|---|
| 01 | 横屏侧边导航与隐私引导卡片 | [查看](screenshots/01_tablet_shelf_rail_onboarding.jpeg) |
| 03 | 隐私书架锁定状态 | [查看](screenshots/03_tablet_privacy_locked.jpeg) |
| 04 | 我的页面居中限宽 | [查看](screenshots/04_tablet_mycenter_bounded.jpeg) |
| 05 | 居中的 PIN 验证页面 | [查看](screenshots/05_tablet_pin_page_centered.jpeg) |
| 06 | 首次设置隐私密码入口 | [查看](screenshots/06_tablet_privacy_setup_entry.jpeg) |
| 07 | PIN 设置页面 | [查看](screenshots/07_tablet_pin_setup_page.jpeg) |
| 08 | 解锁后的隐私书架，列表限宽修复前 | [查看](screenshots/08_tablet_privacy_unlocked.jpeg) |
| 09 | 早期切换操作的过程截图，实际仍为修复前列表状态 | [查看](screenshots/09_tablet_privacy_grid_mode.jpeg) |
| 10 | 离开应用后自动上锁 | [查看](screenshots/10_tablet_privacy_relocked.jpeg) |
| 11 | 主题页面自适应四列网格 | [查看](screenshots/11_tablet_theme_grid.jpeg) |
| 12 | 书架动作下拉菜单 | [查看](screenshots/12_tablet_shelf_action_menu.jpeg) |
| 13 | 本地导入页面居中限宽 | [查看](screenshots/13_tablet_local_import.jpeg) |
| 14 | 修复后的隐私列表，最大 840vp、水平居中 | [查看](screenshots/14_tablet_privacy_list_bounded_fixed.jpeg) |
| 15 | 宫格模式保留完整内容宽度 | [查看](screenshots/15_tablet_privacy_grid_full_width_regression.jpeg) |

## 列表限宽修复回归

普通书架和隐私书架的列表均复用 `AdaptiveLayout.contentWidth`，最大宽度 840vp；宫格模式不受此限宽影响。宽度测量取自外层全宽容器，避免窗口放大后卡在之前的列表宽度。

- 隐私列表实测范围：`[681,434][2361,1832]`，宽 1680px，即 840vp；中心 x=1521px，与内容区中心一致。
- 宫格实测宽约 2639px，即完整可用宽度约 1320vp，包含像素取整差异。
- 宫格切回列表后恢复居中的 840vp 宽度。
- 普通书架当时为空，已采用相同容器修复并通过编译，但未验证其非空列表截图。
- rail 与底部导航切换、横竖屏和分屏变化、真实 ReaderKit 阅读行为仍需补充对应运行场景验证。
