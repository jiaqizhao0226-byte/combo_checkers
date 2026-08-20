# Combo Checkers 重制进度

更新时间：2026-08-20

## 当前状态

- 原版 Lua 游戏代码保留在 `scripts/`，用作玩法与回合规则基准。
- Three.js / 微信小游戏重制版本位于 `prototype-threejs/`。
- 第一章基础关卡、六边棋盘、角色移动、敌人回合、连击、技能选择、镜头和主要 UI 已进入可运行原型阶段。
- 企鹅模型在 `prototype-threejs/hero-review/` 单独验收。
- 第一章小怪在 `prototype-threejs/model-review/` 单独验收；铁甲龟已完成第一轮精修，其余小怪仍需按同一质量标准继续精修。
- 棋盘已纠正为与原版一致的尖顶六边形紧密排列。

## 已知重要差异

- `prototype-threejs/src/main.js` 的早期网页入口包含像素化渲染管线。
- 当前微信小游戏入口 `prototype-threejs/game.js` 仍为全分辨率直接 3D 渲染，尚未接回参考游戏所需的轻度像素化效果。
- 模型验收页也使用平滑 3D 渲染，下一步应增加“原始 3D / 最终像素效果”切换。

## 建议下一步

1. 为微信小游戏实现轻量、可控的低分辨率世界渲染，并保持 UI 清晰。
2. 在模型验收页加入同参数像素预览，统一模型验收口径。
3. 验收铁甲龟后，逐只精修第一章其他小怪。
4. 继续对照原版 Lua 代码完善第一章玩法和演出。

## 本地验证

```bash
node --test prototype-threejs/tests/*.test.mjs
python3 -m http.server 8000 --bind 127.0.0.1
```

浏览器访问 `http://127.0.0.1:8000/prototype-threejs/`，模型验收页为
`http://127.0.0.1:8000/prototype-threejs/model-review/`。
