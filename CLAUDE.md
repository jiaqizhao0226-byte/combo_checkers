# 棋妙英雄 — 项目核心记忆

> AI 自维护，每次 POST 自动更新。详细规则见 memory-system skill。

## 当前状态
- 版本: 1.0.94
- 进度: 项目源码与 GitHub `origin/master` 保持同步，仓库已补充私有记忆和本地截图忽略规则
- 上次交付: 仓库同步维护；排除 `.agent/memory-runtime/`、`screenshots/`、`.cli/` 与 `logs/` 临时状态

## 用户画像摘要
- 使用简体中文，倾向直接下达任务并由助手完成 Git 操作

## 预测下一步
- likely_next_task: 验证 v1.0.94 真机竖屏显示，或准备后续测试/正式发布
- 相关文件: `scripts/main.lua`、`scripts/MenuSystem.lua`、`.project/project.json`

## 恢复指令（新会话必执行）
1. 读本文件，获取项目状态和避雷清单
2. 读 `docs/memory-index.md`，恢复项目上下文
3. 读 `docs/persona.md`，加载用户画像和偏好
4. 自测：项目是什么？上次做了什么？下一步？不够清楚就多读文件
5. 如有 likely_next_task，预加载相关文件
6. 详细规则见 memory-system skill

## 避雷清单
- 发布前关闭 `scripts/main.lua` 的 TestPanel 模块引用和 `KEY_T` 快捷入口，并确认 `G.godMode` 未开启
- 每次发布版本必须先提交并推送 GitHub，再调用正式发布工具
- 运行时 `.cli/`、`logs/` 与本地 `screenshots/` 不应作为普通功能更新提交
- POST 是记忆存活唯一入口，每次交付后必须执行并判定 3 步 POST
