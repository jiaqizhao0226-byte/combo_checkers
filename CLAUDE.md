# 项目备忘录

## 发布前检查清单

### 测试代码检查（必须！）

正式发布前（调用 `publish_to_taptap` 或 `generate_test_qrcode`），**必须确认测试代码已关闭**：

1. **TestPanel 入口**：`scripts/main.lua` 中 `HandleKeyDown` 的 `KEY_T` 快捷键触发 `TestPanel.Show()` —— 发布时需注释掉或删除该段
2. **TestPanel 模块引用**：`scripts/main.lua` 顶部的 `local TestPanel = require "TestPanel"` —— 发布时需注释掉
3. **无敌模式**：确认 `G.godMode` 为 nil/false（TestPanel 中可开启无敌模式）

**发布前务必执行以下操作**：
```lua
-- main.lua 中注释掉以下两处：
-- local TestPanel = require "TestPanel"   -- ← 注释掉
-- if key == KEY_T then TestPanel.Show() return end  -- ← 注释掉
```

如果用户要求发布但测试代码仍然开启，**必须主动提醒用户**并询问是否关闭测试代码后再发布。

### Git 同步提交（必须！）

**每次发布版本时，必须同步提交到 GitHub**：

1. 发布前将所有变更 `git add` 并 `git commit`（commit message 包含版本号和变更摘要）
2. 执行 `git push` 推送到远程仓库
3. 如果 push 失败，必须提醒用户处理后再继续发布

**执行顺序**：
```
关闭测试代码 → git add + commit + push → 调用发布工具
```

如果用户要求发布但代码尚未提交到 GitHub，**必须主动执行 git commit 和 push**，确保远程仓库与发布版本一致。
