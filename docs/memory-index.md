# 项目记忆索引

项目：棋妙英雄 Combo Checkers
当前版本：1.0.94
简述：融合跳棋连跳与 Roguelite 成长的竖屏策略战斗游戏
最后巩固：2026-07-29

## 项目概况
- 技术栈：UrhoX + Lua 5.4 + `urhox-libs/UI`
- 运行模式：单机（`.project/settings.json` 中 `multiplayer.enabled=false`）
- 主入口：`scripts/main.lua`
- 发布分支：`master`，远端 `origin/master`

## 关键文件
| 文件 | 用途 |
|------|------|
| `scripts/main.lua` | 游戏启动、UI 初始化和模块回调注册 |
| `scripts/MenuSystem.lua` | 主菜单与顶部安全区布局 |
| `.project/project.json` | 项目版本及 TapTap 发布配置 |
| `.project/settings.json` | 构建和运行模式配置 |

## 有效决策
- D-001：竖屏 UI 统一使用 `UI.Scale.DESIGN_SHORT_SIDE(480)`，高度随设备比例延展（v1.0.94）
- D-002：菜单顶部容器同时应用 top/left/right/bottom 安全区（v1.0.94）

## 活跃系统契约
| 契约 | 文件 | 状态 |
|------|------|------|
| UI 设计短边为 480 | `scripts/main.lua` | 生效 |
| 正式发布前关闭 TestPanel | `CLAUDE.md`、`scripts/main.lua` | 发布前检查 |
| 发布前先同步 GitHub | `CLAUDE.md` | 生效 |

## 避雷清单
- TodoWrite 必须前置创建并包含 DEV + POST-1/2/3；POST 条目禁止直接删除。
- 发布前检查 TestPanel 引用、`KEY_T` 快捷入口与 `G.godMode`。
- `.cli/`、`logs/` 是运行时/诊断状态；本地 `screenshots/` 是验证截图，不随普通功能提交。

## 最近变更
- v1.0.94：竖屏 UI 改为 480 设计短边缩放，菜单补齐底部安全区；更新视频缓存并删除两个未引用旧视频；提交 `73629a0` 已推送 GitHub。

## 下一步
1. 在目标手机比例与 DPR 下验证菜单、HUD 和弹窗布局。
2. 若准备正式发布，先执行项目发布前测试代码检查。
