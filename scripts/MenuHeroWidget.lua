-- ============================================================================
-- MenuHeroWidget - 主菜单英雄动画区域 NanoVG 渲染控件
-- ============================================================================

local UI = require("urhox-libs/UI")
local Battle = require "Battle"
local G = require "GameState"

local MenuHeroWidget = UI.Widget:Extend("MenuHeroWidget")

function MenuHeroWidget:Init(props)
    UI.Widget.Init(self, props)
end

--- HSV → RGB 转换 (h:0-360, s:0-1, v:0-1 → r,g,b:0-255)
local function HSVtoRGB(h, s, v)
    local c = v * s
    local x = c * (1 - math.abs((h / 60) % 2 - 1))
    local m = v - c
    local r, g, b
    if     h < 60  then r, g, b = c, x, 0
    elseif h < 120 then r, g, b = x, c, 0
    elseif h < 180 then r, g, b = 0, c, x
    elseif h < 240 then r, g, b = 0, x, c
    elseif h < 300 then r, g, b = x, 0, c
    else                r, g, b = c, 0, x
    end
    return (r + m) * 255, (g + m) * 255, (b + m) * 255
end

--- 章节配色和图标
local CHAPTER_THEMES = {
    [1] = {
        icon = "🌊",
        glowColor = {40, 120, 220},
        gradTop = {15, 25, 55, 245},
        gradBot = {20, 35, 70, 245},
        accentColor = {80, 160, 255},
        borderColor = {40, 120, 220, 140},
        bgImage = "image/chapter_ocean_20260427113947.png",
        isoImage = "image/chapter1_palace_v3_20260514034819.png",
    },
    [2] = {
        icon = "🔥",
        glowColor = {220, 100, 40},
        gradTop = {50, 25, 15, 245},
        gradBot = {60, 30, 20, 245},
        accentColor = {255, 140, 60},
        borderColor = {220, 100, 40, 140},
        bgImage = "image/chapter_fire_clean_20260506092404.png",
        isoImage = "image/chapter2_flame_mountains_20260514041029.png",
    },
    [3] = {
        icon = "🪸",
        glowColor = {120, 220, 180},
        gradTop = {15, 40, 35, 245},
        gradBot = {20, 50, 45, 245},
        accentColor = {140, 255, 200},
        borderColor = {120, 220, 180, 140},
        bgImage = "image/chapter_coral_20260506091317.png",
        isoImage = "image/chapter3_coral_simple_v3_20260523130954.png",
    },
    [4] = {
        icon = "🌀",
        glowColor = {140, 80, 220},
        gradTop = {18, 10, 38, 245},
        gradBot = {28, 15, 52, 245},
        accentColor = {180, 120, 255},
        borderColor = {140, 80, 220, 140},
        bgImage = "image/chapter3_coral_maze_20260514041032.png",
        isoImage = "image/edited_chapter4_abyss_v1_fixed_20260523140509.png",
    },
}

--- NanoVG 图片句柄缓存
local chapterBgHandles = {}

--- 绘制章节卡片
--- 等距图片句柄缓存
local isoImageHandles = {}

--- 绘制等距插画风格的章节卡片（无边框，与背景融合）
local function DrawChapterCardIso(nvg, chapter, cardX, cardY, cardW, cardH, isUnlocked, isCleared, progress, total)
    local theme = CHAPTER_THEMES[chapter] or CHAPTER_THEMES[1]
    local chapterName = Battle.CHAPTER_NAMES[chapter] or ("第" .. chapter .. "章")
    local ccx = cardX + cardW / 2
    local gc = theme.glowColor

    -- === 加载等距插画 ===
    local isoKey = chapter
    if not isoImageHandles[isoKey] then
        isoImageHandles[isoKey] = nvgCreateImage(nvg, theme.isoImage, 0)
    end
    local isoHandle = isoImageHandles[isoKey]

    -- 图片区域：上半部分留给插画，底部留给进度信息
    local imgSize = cardW * 1.45
    local imgX = ccx - imgSize / 2
    local imgCenterY = cardY + cardH * 0.38  -- 插画中心在卡片上方
    local imgY = imgCenterY - imgSize / 2

    -- 用 isoImage 直接铺满整个卡片（cover 模式，无边框）
    -- 图片是正方形，卡片是竖屏矩形，取 max 保证完全覆盖
    if isoHandle and isoHandle >= 0 then
        local coverSize = math.max(cardW, cardH) * 1.25
        local coverX = cardX + (cardW - coverSize) / 2
        local coverY = cardY + (cardH - coverSize) * 0.35  -- 偏上，让建筑主体居中偏上
        local imgPat = nvgImagePattern(nvg, coverX, coverY, coverSize, coverSize, 0, isoHandle, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, coverX, coverY, coverSize, coverSize)  -- 完整显示，不裁切
        nvgFillPaint(nvg, imgPat)
        nvgFill(nvg)
    end

    -- === 粒子光效 ===
    if chapter == 1 then
        -- ── 第一章：深海气泡 ──
        for i = 1, 14 do
            local seed = i * 137.508
            local rndSpeed = ((seed * 9.17) % 71) / 71   -- 0~1 连续随机速度
            local rndPhase = ((seed * 5.83) % 89) / 89   -- 0~1 随机相位
            local rndSize  = ((seed * 11.41) % 67) / 67  -- 0~1 随机大小
            local lifeT = ((G.time * (0.04 + rndSpeed * 0.05) + rndPhase * 6.28) % 1.0)
            local bx = cardX + cardW * (0.05 + (((seed * 7.31) % 90) / 100))
            local by = cardY + cardH * (1.05 - lifeT * 1.15)
            bx = bx + math.sin(G.time * 0.8 + seed) * 10

            local bubbleR = 3 + rndSize * 9  -- 半径 3~12
            local fadeA = math.sin(lifeT * math.pi) * 0.9
            local alpha = math.floor(fadeA * 180)  -- 更亮
            if alpha > 2 then
                -- 气泡外圈（更粗更亮）
                nvgBeginPath(nvg)
                nvgCircle(nvg, bx, by, bubbleR)
                nvgStrokeColor(nvg, nvgRGBA(160, 215, 255, alpha))
                nvgStrokeWidth(nvg, 1.8)
                nvgStroke(nvg)
                -- 气泡内部半透明填充
                nvgBeginPath(nvg)
                nvgCircle(nvg, bx, by, bubbleR)
                nvgFillColor(nvg, nvgRGBA(140, 200, 255, math.floor(alpha * 0.15)))
                nvgFill(nvg)
                -- 气泡高光点
                nvgBeginPath(nvg)
                nvgCircle(nvg, bx - bubbleR * 0.28, by - bubbleR * 0.28, bubbleR * 0.3)
                nvgFillColor(nvg, nvgRGBA(220, 240, 255, math.floor(alpha * 0.9)))
                nvgFill(nvg)
                -- 荧光晕（所有气泡都有）
                nvgBeginPath(nvg)
                nvgCircle(nvg, bx, by, bubbleR * 2.5)
                local glow = nvgRadialGradient(nvg, bx, by, bubbleR * 0.5, bubbleR * 2.5,
                    nvgRGBA(80, 170, 255, math.floor(alpha * 0.3)),
                    nvgRGBA(80, 170, 255, 0))
                nvgFillPaint(nvg, glow)
                nvgFill(nvg)
            end
        end

    elseif chapter == 2 then
        -- ── 第二章：燃烧火星 ──
        for i = 1, 22 do
            local seed = i * 97.37
            -- 用 seed 派生多个伪随机值，避免规律排列
            local rndSpeed = ((seed * 13.17) % 73) / 73   -- 0~1 连续随机速度因子
            local rndPhase = ((seed * 7.91) % 97) / 97    -- 0~1 随机相位偏移
            local rndYOff  = ((seed * 11.03) % 83) / 83   -- 0~1 随机 Y 起始偏移
            local lifeT = ((G.time * (0.06 + rndSpeed * 0.06) + rndPhase * 6.28) % 1.0)
            local spawnX = cardX + cardW * (0.08 + (((seed * 3.71) % 84) / 100))
            local fx = spawnX + math.sin(G.time * 1.2 + seed) * 12
                      + math.sin(G.time * 0.5 + seed * 0.5) * 6
            local fy = cardY + cardH * (0.95 - lifeT * 1.0)
            fy = fy + rndYOff * cardH * 0.08  -- 每个粒子额外 Y 偏移打破水平对齐
            local cr = 255
            local cg = math.floor(220 - lifeT * 180)
            local cb = math.floor(60 - lifeT * 50)
            local rndSize = ((seed * 5.53) % 67) / 67
            local sparkR = (2.0 + rndSize * 5.0) * (1.0 - lifeT * 0.6)
            local fadeA = math.sin(lifeT * math.pi) * 0.85
            local alpha = math.floor(fadeA * 200)
            if alpha > 3 then
                nvgBeginPath(nvg)
                nvgCircle(nvg, fx, fy, sparkR)
                nvgFillColor(nvg, nvgRGBA(cr, cg, cb, alpha))
                nvgFill(nvg)
                nvgBeginPath(nvg)
                nvgCircle(nvg, fx, fy, sparkR * 3.0)
                local fireGlow = nvgRadialGradient(nvg, fx, fy, sparkR * 0.3, sparkR * 3.0,
                    nvgRGBA(cr, math.floor(cg * 0.7), 0, math.floor(alpha * 0.3)),
                    nvgRGBA(cr, 0, 0, 0))
                nvgFillPaint(nvg, fireGlow)
                nvgFill(nvg)
            end
        end


    elseif chapter == 3 then
        -- ── 第三章：白色十字闪烁星光 ──
        -- 纯白/淡金十字星芒，呼吸闪烁，更大更明显
        for i = 1, 20 do
            local seed = i * 211.13
            local rndFreq = ((seed * 7.63) % 79) / 79   -- 0~1 连续随机闪烁频率
            local rndSize = ((seed * 13.07) % 83) / 83 -- 0~1 随机大小
            local blinkPhase = G.time * (0.8 + rndFreq * 1.8) + seed
            local blinkVal = (math.sin(blinkPhase) * 0.5 + 0.5)
            blinkVal = blinkVal * blinkVal * blinkVal  -- 三次方，亮的更短促闪耀
            -- 分散在卡片各处
            local sx = cardX + cardW * (0.06 + (((seed * 5.17) % 88) / 100))
            local sy = cardY + cardH * (0.06 + (((seed * 3.29) % 88) / 100))
            sx = sx + math.sin(G.time * 0.4 + seed * 0.3) * 3
            sy = sy + math.cos(G.time * 0.3 + seed * 0.7) * 3
            -- 淡金白色（不用彩虹色）
            local warmth = ((seed * 17) % 100) / 100  -- 0~1 随机暖度
            local sr = 255
            local sg = math.floor(235 + warmth * 20)  -- 235~255
            local sb = math.floor(200 + warmth * 40)   -- 200~240
            local alpha = math.floor(blinkVal * 240)   -- 更亮
            local starR = 2.5 + rndSize * 7.5  -- 2.5~10
            if alpha > 8 then
                -- 核心亮点
                nvgBeginPath(nvg)
                nvgCircle(nvg, sx, sy, starR * 0.6)
                nvgFillColor(nvg, nvgRGBA(255, 255, 255, alpha))
                nvgFill(nvg)
                -- 十字星芒（更长更亮）
                local crossLen = starR * 3.5 * blinkVal
                local crossA = math.floor(alpha * 0.7)
                nvgStrokeWidth(nvg, 1.5)
                nvgStrokeColor(nvg, nvgRGBA(sr, sg, sb, crossA))
                nvgBeginPath(nvg)
                nvgMoveTo(nvg, sx - crossLen, sy)
                nvgLineTo(nvg, sx + crossLen, sy)
                nvgStroke(nvg)
                nvgBeginPath(nvg)
                nvgMoveTo(nvg, sx, sy - crossLen)
                nvgLineTo(nvg, sx, sy + crossLen)
                nvgStroke(nvg)
                -- 柔和白色光晕
                nvgBeginPath(nvg)
                nvgCircle(nvg, sx, sy, starR * 4.5)
                local sparkGlow = nvgRadialGradient(nvg, sx, sy, starR * 0.3, starR * 4.5,
                    nvgRGBA(sr, sg, sb, math.floor(alpha * 0.2)),
                    nvgRGBA(sr, sg, sb, 0))
                nvgFillPaint(nvg, sparkGlow)
                nvgFill(nvg)
            end
        end

    elseif chapter == 4 then
        -- ── 第四章：迷幻深渊粒子 ──
        -- 1. 漂浮紫蓝幽灵光点（慢速螺旋上升）
        for i = 1, 18 do
            local seed = i * 173.91
            local rndR   = ((seed * 6.17)  % 77) / 77   -- 0~1 随机轨道半径
            local rndSpd = ((seed * 9.43)  % 83) / 83   -- 0~1 随机速度
            local rndSz  = ((seed * 11.73) % 71) / 71   -- 0~1 随机大小
            local rndHue = ((seed * 3.71)  % 97) / 97   -- 0~1 色相偏移（紫→青）

            -- 螺旋轨迹：绕卡片中心缓慢旋转+上升
            local angle  = G.time * (0.4 + rndSpd * 0.6) + seed
            local orbitR = cardW * (0.08 + rndR * 0.40)
            local cx2    = ccx + math.cos(angle) * orbitR
            -- 上升：用 time 推动 Y，超出顶部后循环回底部
            local riseT  = ((G.time * (0.03 + rndSpd * 0.04) + seed * 0.07) % 1.0)
            local cy2    = cardY + cardH * (1.05 - riseT * 1.2)
            cy2 = cy2 + math.sin(angle * 1.3 + seed) * cardH * 0.04

            -- 颜色：紫(140,80,255)→青蓝(60,160,255) 根据 rndHue 插值
            local cr = math.floor(140 - rndHue * 80)
            local cg = math.floor(80  + rndHue * 80)
            local cb = 255
            local fadeA = math.sin(riseT * math.pi) * 0.85
            local alpha = math.floor(fadeA * 200)
            local pR = 3 + rndSz * 7  -- 半径 3~10

            if alpha > 6 then
                -- 核心亮点
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx2, cy2, pR * 0.55)
                nvgFillColor(nvg, nvgRGBA(cr + 60, cg + 60, cb, alpha))
                nvgFill(nvg)
                -- 外层柔光晕
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx2, cy2, pR * 3.2)
                local pGlow = nvgRadialGradient(nvg, cx2, cy2, pR * 0.4, pR * 3.2,
                    nvgRGBA(cr, cg, cb, math.floor(alpha * 0.45)),
                    nvgRGBA(cr, cg, cb, 0))
                nvgFillPaint(nvg, pGlow)
                nvgFill(nvg)
            end
        end

        -- 2. 闪烁六芒星光（传送门能量感）
        for i = 1, 8 do
            local seed = i * 317.53
            local blinkPhase = G.time * (1.1 + ((seed * 5.3) % 71) / 71 * 1.4) + seed
            local blinkVal = math.max(0, math.sin(blinkPhase))
            blinkVal = blinkVal * blinkVal  -- 平方，闪烁更锐
            local sx = cardX + cardW * (0.10 + (((seed * 7.11) % 80) / 100))
            local sy = cardY + cardH * (0.10 + (((seed * 4.37) % 80) / 100))
            local alpha = math.floor(blinkVal * 210)
            local starR = 3 + ((seed * 13.1) % 61) / 61 * 6  -- 3~9
            local hue   = ((seed * 2.91) % 97) / 97
            local cr = math.floor(160 - hue * 100)
            local cg = math.floor(60  + hue * 120)
            if alpha > 10 then
                -- 中心核
                nvgBeginPath(nvg)
                nvgCircle(nvg, sx, sy, starR * 0.5)
                nvgFillColor(nvg, nvgRGBA(cr + 80, cg + 50, 255, alpha))
                nvgFill(nvg)
                -- 六芒星芒（3对十字，每对旋转60°）
                nvgStrokeWidth(nvg, 1.2)
                local crossLen = starR * 2.8 * blinkVal
                for k = 0, 2 do
                    local rot = math.rad(k * 60)
                    local ax = math.cos(rot) * crossLen
                    local ay = math.sin(rot) * crossLen
                    nvgStrokeColor(nvg, nvgRGBA(cr + 40, cg + 40, 255, math.floor(alpha * 0.75)))
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, sx - ax, sy - ay)
                    nvgLineTo(nvg, sx + ax, sy + ay)
                    nvgStroke(nvg)
                end
                -- 光晕
                nvgBeginPath(nvg)
                nvgCircle(nvg, sx, sy, starR * 4)
                local sGlow = nvgRadialGradient(nvg, sx, sy, starR * 0.3, starR * 4,
                    nvgRGBA(cr, cg, 255, math.floor(alpha * 0.22)),
                    nvgRGBA(cr, cg, 255, 0))
                nvgFillPaint(nvg, sGlow)
                nvgFill(nvg)
            end
        end

        -- 3. 传送门漩涡残影（围绕卡片中心的淡紫色弧线）
        local portalCX = ccx
        local portalCY = cardY + cardH * 0.42
        for i = 1, 3 do
            local arcPhase = G.time * (0.6 + i * 0.2) + i * 2.1
            local arcR = cardW * (0.18 + i * 0.07)
            local arcStart = arcPhase
            local arcEnd   = arcPhase + math.pi * (0.55 + i * 0.12)
            local arcAlpha = math.floor(28 + math.sin(arcPhase * 0.9) * 14)
            nvgBeginPath(nvg)
            nvgArc(nvg, portalCX, portalCY, arcR, arcStart, arcEnd, NVG_CW)
            nvgStrokeColor(nvg, nvgRGBA(160, 80, 255, arcAlpha))
            nvgStrokeWidth(nvg, 1.5 + i * 0.5)
            nvgStroke(nvg)
        end
    end

end

local function DrawChapterCard(nvg, chapter, cardX, cardY, cardW, cardH, isUnlocked, isCleared, progress, total)
    -- 如果有等距插画，走新的无框渲染路径
    local theme = CHAPTER_THEMES[chapter] or CHAPTER_THEMES[1]
    if theme.isoImage then
        DrawChapterCardIso(nvg, chapter, cardX, cardY, cardW, cardH, isUnlocked, isCleared, progress, total)
        return
    end

    local r = 18
    local ccx = cardX + cardW / 2
    local ccy = cardY + cardH / 2
    local chapterName = Battle.CHAPTER_NAMES[chapter] or ("第" .. chapter .. "章")

    -- ========== 立体投影（多层阴影，增强深度感） ==========
    if isUnlocked then
        -- 远距离柔和大阴影
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, cardX - 6, cardY + 4, cardW + 12, cardH + 12, r + 8)
        nvgFillColor(nvg, nvgRGBA(0, 0, 0, 40))
        nvgFill(nvg)
        -- 近距离清晰小阴影
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, cardX - 2, cardY + 2, cardW + 4, cardH + 4, r + 2)
        nvgFillColor(nvg, nvgRGBA(0, 0, 0, 55))
        nvgFill(nvg)
    end

    -- ========== 卡片外发光（脉动） ==========
    if isUnlocked then
        local gc = theme.glowColor
        local glowAlpha = math.floor(30 + math.sin(G.time * 2.0) * 18)
        -- 外层大光晕
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, cardX - 8, cardY - 8, cardW + 16, cardH + 16, r + 8)
        local outerGlow = nvgRadialGradient(nvg, cardX + cardW/2, cardY + cardH/2,
            cardW * 0.3, cardW * 0.7,
            nvgRGBA(gc[1], gc[2], gc[3], glowAlpha),
            nvgRGBA(gc[1], gc[2], gc[3], 0))
        nvgFillPaint(nvg, outerGlow)
        nvgFill(nvg)
        -- 紧贴边缘的光圈
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, cardX - 3, cardY - 3, cardW + 6, cardH + 6, r + 3)
        nvgFillColor(nvg, nvgRGBA(gc[1], gc[2], gc[3], math.floor(glowAlpha * 0.5)))
        nvgFill(nvg)
    end

    -- ========== 卡片底色（渐变 + 微妙纹理感） ==========
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, cardX, cardY, cardW, cardH, r)
    if isUnlocked then
        local gt = theme.gradTop
        local gb = theme.gradBot
        local bgPaint = nvgLinearGradient(nvg, cardX, cardY, cardX, cardY + cardH,
            nvgRGBA(gt[1], gt[2], gt[3], gt[4]), nvgRGBA(gb[1], gb[2], gb[3], gb[4]))
        nvgFillPaint(nvg, bgPaint)
    else
        nvgFillColor(nvg, nvgRGBA(30, 30, 40, 235))
    end
    nvgFill(nvg)

    -- ========== 背景图片层（章节氛围图） ==========
    if isUnlocked and theme.bgImage then
        local bgKey = chapter
        if not chapterBgHandles[bgKey] then
            chapterBgHandles[bgKey] = nvgCreateImage(nvg, theme.bgImage, 0)
        end
        local bgHandle = chapterBgHandles[bgKey]
        if bgHandle and bgHandle >= 0 then
            nvgSave(nvg)
            nvgIntersectScissor(nvg, cardX, cardY, cardW, cardH)
            -- 图片覆盖整个卡片区域，半透明融合
            local imgPat = nvgImagePattern(nvg, cardX, cardY, cardW, cardH, 0, bgHandle, 0.35)
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, cardX, cardY, cardW, cardH, r)
            nvgFillPaint(nvg, imgPat)
            nvgFill(nvg)
            -- 底部渐变遮罩（让文字区域更清晰）
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, cardX, cardY + cardH * 0.5, cardW, cardH * 0.5, 0)
            local maskPaint = nvgLinearGradient(nvg, cardX, cardY + cardH * 0.5, cardX, cardY + cardH,
                nvgRGBA(0, 0, 0, 0), nvgRGBA(0, 0, 0, 140))
            nvgFillPaint(nvg, maskPaint)
            nvgFill(nvg)
            nvgRestore(nvg)
        end
    end

    -- ========== 玻璃高光（顶部弧形高光条） ==========
    if isUnlocked then
        nvgSave(nvg)
        nvgIntersectScissor(nvg, cardX, cardY, cardW, cardH * 0.45)
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, cardX, cardY, cardW, cardH * 0.45, r)
        local glassPaint = nvgLinearGradient(nvg, cardX, cardY, cardX, cardY + cardH * 0.45,
            nvgRGBA(255, 255, 255, 18), nvgRGBA(255, 255, 255, 0))
        nvgFillPaint(nvg, glassPaint)
        nvgFill(nvg)
        nvgRestore(nvg)
    end

    -- ========== 内部径向光（中心微亮） ==========
    if isUnlocked then
        local gc = theme.glowColor
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, cardX, cardY, cardW, cardH, r)
        local innerGlow = nvgRadialGradient(nvg, ccx, ccy - cardH * 0.1,
            cardW * 0.05, cardW * 0.55,
            nvgRGBA(gc[1], gc[2], gc[3], 20),
            nvgRGBA(0, 0, 0, 0))
        nvgFillPaint(nvg, innerGlow)
        nvgFill(nvg)
    end

    -- ========== 顶部装饰条（渐变 + 呼吸） ==========
    if isUnlocked then
        local ac = theme.accentColor
        local barAlpha = math.floor(180 + math.sin(G.time * 3.0) * 40)
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, cardX + 2, cardY, cardW - 4, 3, 2)
        if isCleared then
            local barPaint = nvgLinearGradient(nvg, cardX, cardY, cardX + cardW, cardY,
                nvgRGBA(40, 180, 100, barAlpha), nvgRGBA(100, 240, 150, barAlpha))
            nvgFillPaint(nvg, barPaint)
        else
            local barPaint = nvgLinearGradient(nvg, cardX, cardY, cardX + cardW, cardY,
                nvgRGBA(ac[1], ac[2], ac[3], barAlpha), nvgRGBA(math.min(255, ac[1] + 40), math.min(255, ac[2] + 30), ac[3], barAlpha))
            nvgFillPaint(nvg, barPaint)
        end
        nvgFill(nvg)
    end

    -- ========== 边框（双层描边，增加立体感） ==========
    -- 内层亮边（模拟光泽）
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, cardX + 0.5, cardY + 0.5, cardW - 1, cardH - 1, r - 0.5)
    nvgStrokeWidth(nvg, 0.8)
    if isUnlocked then
        nvgStrokeColor(nvg, nvgRGBA(255, 255, 255, 15))
    else
        nvgStrokeColor(nvg, nvgRGBA(255, 255, 255, 5))
    end
    nvgStroke(nvg)
    -- 外层主边框
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, cardX, cardY, cardW, cardH, r)
    nvgStrokeWidth(nvg, 1.5)
    if isUnlocked then
        local bc = theme.borderColor
        if isCleared then
            nvgStrokeColor(nvg, nvgRGBA(80, 200, 120, 130))
        else
            nvgStrokeColor(nvg, nvgRGBA(bc[1], bc[2], bc[3], bc[4]))
        end
    else
        nvgStrokeColor(nvg, nvgRGBA(50, 50, 65, 100))
    end
    nvgStroke(nvg)

    if not isUnlocked then
        -- 锁定状态
        nvgFontSize(nvg, 66)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(70, 70, 90, 160))
        nvgText(nvg, ccx, ccy - 24, "🔒")

        nvgFontSize(nvg, 22)
        nvgFillColor(nvg, nvgRGBA(120, 120, 150, 180))
        nvgText(nvg, ccx, ccy + 24, chapterName)

        nvgFontSize(nvg, 17)
        nvgFillColor(nvg, nvgRGBA(90, 90, 110, 160))
        nvgText(nvg, ccx, ccy + 50, "通关上一章解锁")
        return
    end

    -- 大图标 + 呼吸
    local iconY = ccy - 6
    local bobY = math.sin(G.time * 1.8) * 5

    local haloAlpha = math.floor(25 + math.sin(G.time * 2.5) * 15)
    local haloR = 40 + math.sin(G.time * 1.5) * 5
    local gc = theme.glowColor
    nvgBeginPath(nvg)
    local haloPaint = nvgRadialGradient(nvg, ccx, iconY, 8, haloR,
        nvgRGBA(gc[1], gc[2], gc[3], haloAlpha), nvgRGBA(gc[1], gc[2], gc[3], 0))
    nvgRect(nvg, ccx - haloR, iconY - haloR, haloR * 2, haloR * 2)
    nvgFillPaint(nvg, haloPaint)
    nvgFill(nvg)

    nvgFontSize(nvg, 74)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
    nvgText(nvg, ccx, iconY + bobY, theme.icon)

    -- 椭圆阴影
    nvgBeginPath(nvg)
    nvgEllipse(nvg, ccx, iconY + 48, 34, 9)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 30))
    nvgFill(nvg)

    -- 进度条（立体感增强）
    local barW = cardW * 0.65
    local barH = 12
    local barX = ccx - barW / 2
    local barY = cardY + cardH - 54

    -- 进度条凹槽（内阴影效果）
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, barX - 1, barY - 1, barW + 2, barH + 2, 6)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 80))
    nvgFill(nvg)
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, barX, barY, barW, barH, 5)
    nvgFillColor(nvg, nvgRGBA(15, 15, 28, 220))
    nvgFill(nvg)

    if progress > 0 then
        local fillW = barW * (progress / total)
        local ac = theme.accentColor
        local r1, g1, b1
        if isCleared then
            r1, g1, b1 = 60, 200, 110
        else
            r1, g1, b1 = ac[1], ac[2], ac[3]
        end
        -- 填充渐变
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, barX, barY, fillW, barH, 5)
        local fillPaint = nvgLinearGradient(nvg, barX, barY, barX, barY + barH,
            nvgRGBA(math.min(255, r1 + 30), math.min(255, g1 + 30), math.min(255, b1 + 30), 240),
            nvgRGBA(r1, g1, b1, 220))
        nvgFillPaint(nvg, fillPaint)
        nvgFill(nvg)
        -- 顶部高光线
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, barX + 1, barY + 1, fillW - 2, barH * 0.4, 3)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 35))
        nvgFill(nvg)
    end

    -- 状态标签
    local tagText, tagBgR, tagBgG, tagBgB, tagFontR, tagFontG, tagFontB
    if isCleared then
        tagText = "✅ 已通关"
        tagBgR, tagBgG, tagBgB = 30, 80, 50
        tagFontR, tagFontG, tagFontB = 100, 230, 140
    else
        tagText = string.format("⭐ %d/%d", progress, total)
        tagBgR, tagBgG, tagBgB = 80, 60, 20
        tagFontR, tagFontG, tagFontB = 255, 220, 90
    end

    local tagW = 110
    local tagH = 28
    local tagX = ccx - tagW / 2
    local tagY = cardY + cardH - 38
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, tagX, tagY, tagW, tagH, 12)
    nvgFillColor(nvg, nvgRGBA(tagBgR, tagBgG, tagBgB, 180))
    nvgFill(nvg)

    nvgFontSize(nvg, 18)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(tagFontR, tagFontG, tagFontB, 255))
    nvgText(nvg, ccx, tagY + tagH / 2, tagText)
end

function MenuHeroWidget:Render(nvg)
    self:RenderFullBackground(nvg)
    local l = self:GetAbsoluteLayout()
    if l.w <= 0 or l.h <= 0 then return end
    nvgFontFace(nvg, UI.Theme.FontFace("sans", "normal"))

    local cx = l.x + l.w / 2

    -- 章节信息
    local ch = G.selectedChapter
    local chapterFirst = (ch - 1) * Battle.LEVELS_PER_CHAPTER + 1
    local chapterLast = ch * Battle.LEVELS_PER_CHAPTER
    -- 第1章始终解锁；其他章节需通关上一章 Boss（highestLevel > 上一章末尾关卡）
    local isUnlocked = (ch == 1) or ((G.playerData.highestLevel or 1) > (ch - 1) * Battle.LEVELS_PER_CHAPTER)
    local isCleared = G.highestLevel > chapterLast
    local chapterName = Battle.CHAPTER_NAMES[ch] or ("第" .. ch .. "章")

    -- 章内进度
    local progress = 0
    if isUnlocked then
        progress = math.max(0, math.min(G.highestLevel - chapterFirst + 1, Battle.LEVELS_PER_CHAPTER))
        if isCleared then progress = Battle.LEVELS_PER_CHAPTER end
    end

    -- === 章节主题 ===
    local theme = CHAPTER_THEMES[ch] or CHAPTER_THEMES[1]
    local gc = theme.glowColor

    -- === 1. 深色底色（章节主题色染色）===
    local baseR = math.floor(8 + gc[1] * 0.08)
    local baseG = math.floor(6 + gc[2] * 0.06)
    local baseB = math.floor(22 + gc[3] * 0.06)
    nvgBeginPath(nvg)
    nvgRect(nvg, l.x, l.y, l.w, l.h)
    nvgFillColor(nvg, nvgRGBA(baseR, baseG, baseB, 255))
    nvgFill(nvg)

    -- === 2. 中间亮、上下暗的主渐变（三段式暗角效果）===
    -- 中间亮区颜色：章节主题色明显染色
    local midR = math.floor(18 + gc[1] * 0.30)
    local midG = math.floor(16 + gc[2] * 0.25)
    local midB = math.floor(40 + gc[3] * 0.25)
    -- 上半: 从深色过渡到中间亮区
    local midY = l.y + l.h * 0.42
    local topPaint = nvgLinearGradient(nvg, cx, l.y, cx, midY,
        nvgRGBA(math.floor(6 + gc[1] * 0.05), math.floor(4 + gc[2] * 0.04), math.floor(18 + gc[3] * 0.04), 255),
        nvgRGBA(midR, midG, midB, 255))
    nvgBeginPath(nvg)
    nvgRect(nvg, l.x, l.y, l.w, midY - l.y)
    nvgFillPaint(nvg, topPaint)
    nvgFill(nvg)

    -- 下半: 从中间亮区过渡到底部深色
    local botPaint = nvgLinearGradient(nvg, cx, midY, cx, l.y + l.h,
        nvgRGBA(midR, midG, midB, 255),
        nvgRGBA(math.floor(10 + gc[1] * 0.06), math.floor(8 + gc[2] * 0.05), math.floor(28 + gc[3] * 0.05), 255))
    nvgBeginPath(nvg)
    nvgRect(nvg, l.x, midY, l.w, l.y + l.h - midY)
    nvgFillPaint(nvg, botPaint)
    nvgFill(nvg)

    -- === 3. 中央大范围径向光晕（呼吸感） ===
    local breathA = math.floor(55 + math.sin(G.time * 0.6) * 18)
    local centerPaint = nvgRadialGradient(nvg, cx, midY, l.w * 0.05, l.w * 0.75,
        nvgRGBA(gc[1], gc[2], gc[3], breathA),
        nvgRGBA(gc[1], gc[2], gc[3], 0))
    nvgBeginPath(nvg)
    nvgRect(nvg, l.x, l.y, l.w, l.h)
    nvgFillPaint(nvg, centerPaint)
    nvgFill(nvg)

    -- === 4. 流光溢彩光带（3条斜向漂移的半透明光带） ===
    for i = 1, 3 do
        local speed = 0.15 + i * 0.08
        local phase = (G.time * speed + i * 2.1) % 3.0
        -- 光带从左上滑向右下，循环
        local t = phase / 3.0  -- 0~1
        local bandX = l.x - l.w * 0.3 + t * l.w * 1.6
        local bandY1 = l.y + l.h * (0.15 + i * 0.15)
        local bandY2 = bandY1 + l.h * 0.35
        local bandW = l.w * (0.12 + i * 0.04)
        -- 淡入淡出
        local fadeIn = math.min(t * 4, 1.0)
        local fadeOut = math.min((1.0 - t) * 4, 1.0)
        local bandA = math.floor(fadeIn * fadeOut * (14 + i * 6))
        -- 用章节色画斜向光带
        local r = math.min(255, gc[1] + 60)
        local g = math.min(255, gc[2] + 60)
        local b = math.min(255, gc[3] + 60)
        nvgSave(nvg)
        nvgTranslate(nvg, bandX, bandY1)
        nvgRotate(nvg, math.rad(-25 + i * 5))
        local bandPaint = nvgLinearGradient(nvg, 0, 0, bandW, 0,
            nvgRGBA(r, g, b, 0),
            nvgRGBA(r, g, b, bandA))
        nvgBeginPath(nvg)
        nvgRect(nvg, 0, 0, bandW, bandY2 - bandY1)
        nvgFillPaint(nvg, bandPaint)
        nvgFill(nvg)
        -- 对称淡出
        local bandPaint2 = nvgLinearGradient(nvg, bandW, 0, bandW * 2, 0,
            nvgRGBA(r, g, b, bandA),
            nvgRGBA(r, g, b, 0))
        nvgBeginPath(nvg)
        nvgRect(nvg, bandW, 0, bandW, bandY2 - bandY1)
        nvgFillPaint(nvg, bandPaint2)
        nvgFill(nvg)
        nvgRestore(nvg)
    end

    -- === 5. 边缘柔和暗角（上下加深） ===
    -- 顶部暗角
    local topVig = nvgLinearGradient(nvg, cx, l.y, cx, l.y + l.h * 0.2,
        nvgRGBA(4, 2, 12, 180), nvgRGBA(4, 2, 12, 0))
    nvgBeginPath(nvg)
    nvgRect(nvg, l.x, l.y, l.w, l.h * 0.2)
    nvgFillPaint(nvg, topVig)
    nvgFill(nvg)

    -- 底部暗角 + 雾气
    local botVig = nvgLinearGradient(nvg, cx, l.y + l.h - l.h * 0.18, cx, l.y + l.h,
        nvgRGBA(10, 8, 28, 0), nvgRGBA(16, 14, 36, 240))
    nvgBeginPath(nvg)
    nvgRect(nvg, l.x, l.y + l.h - l.h * 0.18, l.w, l.h * 0.18)
    nvgFillPaint(nvg, botVig)
    nvgFill(nvg)

    -- === 6. 装饰星星（多层：远景小星+近景大星）===
    for i = 1, 30 do
        local sx = l.x + ((i * 97 + 31) % math.floor(l.w))
        local sy = l.y + ((i * 53 + 17) % math.floor(l.h * 0.55))
        local twinkle = math.sin(G.time * (1.2 + i * 0.15) + i * 1.3) * 0.5 + 0.5
        local a, sr
        if i <= 5 then
            sr = 1.0 + twinkle * 1.5
            a = math.floor(80 + twinkle * 120)
            local rayLen = sr * 3.5
            local rayA = math.floor(a * 0.3)
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, sx - rayLen, sy)
            nvgLineTo(nvg, sx + rayLen, sy)
            nvgStrokeColor(nvg, nvgRGBA(255, 255, 230, rayA))
            nvgStrokeWidth(nvg, 0.8)
            nvgStroke(nvg)
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, sx, sy - rayLen)
            nvgLineTo(nvg, sx, sy + rayLen)
            nvgStrokeColor(nvg, nvgRGBA(255, 255, 230, rayA))
            nvgStrokeWidth(nvg, 0.8)
            nvgStroke(nvg)
        else
            sr = 0.3 + twinkle * 0.8
            a = math.floor(15 + twinkle * 70)
        end
        nvgBeginPath(nvg)
        nvgCircle(nvg, sx, sy, sr)
        nvgFillColor(nvg, nvgRGBA(255, 255, 230, a))
        nvgFill(nvg)
    end

    -- === 7. 偶尔的流星 ===
    local meteorCycle = 4.0
    local meteorPhase = (G.time % meteorCycle) / meteorCycle
    if meteorPhase < 0.15 then
        local mp = meteorPhase / 0.15
        local msx = l.x + l.w * 0.8 - mp * l.w * 0.5
        local msy = l.y + l.h * 0.05 + mp * l.h * 0.3
        local tailLen = 30 + mp * 20
        local mAlpha = math.floor((mp < 0.5 and mp * 2 or (1.0 - mp) * 2) * 200)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, msx, msy)
        nvgLineTo(nvg, msx + tailLen * 0.7, msy - tailLen * 0.4)
        nvgStrokeColor(nvg, nvgRGBA(255, 255, 255, mAlpha))
        nvgStrokeWidth(nvg, 1.5)
        nvgStroke(nvg)
        nvgBeginPath(nvg)
        nvgCircle(nvg, msx, msy, 1.5)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, mAlpha))
        nvgFill(nvg)
    end

    -- === 8. 深海光影波纹（等距插画模式增强） ===
    if theme.isoImage then
        -- 水面焦散光纹（从下方透上来的波光粼粼效果）
        for i = 1, 4 do
            local waveSpeed = 0.3 + i * 0.12
            local wavePhase = G.time * waveSpeed + i * 1.5
            local waveY = l.y + l.h * (0.5 + math.sin(wavePhase * 0.4) * 0.12)
            local waveX = l.x + l.w * (0.2 + (i - 1) * 0.2) + math.sin(wavePhase) * l.w * 0.08
            local waveW = l.w * (0.25 + math.sin(wavePhase * 0.7) * 0.08)
            local waveH = l.h * 0.08
            local waveA = math.floor(12 + math.sin(wavePhase * 1.3) * 8)
            nvgSave(nvg)
            nvgTranslate(nvg, waveX, waveY)
            nvgRotate(nvg, math.rad(-8 + math.sin(wavePhase * 0.5) * 5))
            nvgBeginPath(nvg)
            nvgEllipse(nvg, 0, 0, waveW, waveH)
            local wavePaint = nvgRadialGradient(nvg, 0, 0, waveW * 0.1, waveW,
                nvgRGBA(gc[1] + 40, gc[2] + 40, math.min(255, gc[3] + 80), waveA),
                nvgRGBA(gc[1], gc[2], gc[3], 0))
            nvgFillPaint(nvg, wavePaint)
            nvgFill(nvg)
            nvgRestore(nvg)
        end

        -- 深海光柱（从上方照下来的柔和光柱）
        for i = 1, 2 do
            local beamX = cx + (i == 1 and -l.w * 0.18 or l.w * 0.22)
            local beamA = math.floor(10 + math.sin(G.time * 0.5 + i * 2.0) * 6)
            local beamW = l.w * 0.12
            nvgSave(nvg)
            nvgTranslate(nvg, beamX, l.y)
            nvgRotate(nvg, math.rad(i == 1 and 8 or -5))
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, -beamW * 0.3, 0)
            nvgLineTo(nvg, beamW * 0.3, 0)
            nvgLineTo(nvg, beamW * 0.8, l.h * 0.7)
            nvgLineTo(nvg, -beamW * 0.8, l.h * 0.7)
            nvgClosePath(nvg)
            local beamPaint = nvgLinearGradient(nvg, 0, 0, 0, l.h * 0.7,
                nvgRGBA(gc[1] + 60, gc[2] + 60, math.min(255, gc[3] + 100), beamA),
                nvgRGBA(gc[1], gc[2], gc[3], 0))
            nvgFillPaint(nvg, beamPaint)
            nvgFill(nvg)
            nvgRestore(nvg)
        end
    end

    -- === 布局计算 ===
    -- 按容器高度比例计算布局，适配不同屏幕
    local titleY = l.y + l.h * 0.06
    local cardTopY = titleY + l.h * 0.08
    local cardBottomMargin = l.h * 0.22  -- 留给宝箱+圆点的空间
    local availH = l.h - (cardTopY - l.y) - cardBottomMargin
    local maxCardSide = math.min(l.w * 0.62, availH * 0.72)
    local cardSide = math.min(maxCardSide, availH)
    cardSide = math.max(cardSide, 140)
    local cardW = cardSide
    local cardH = cardSide
    local cardX = cx - cardW / 2
    local cardY = cardTopY + (availH - cardSide) / 2

    -- === 1. 章节名标题（"1. 深渊海沟" 格式）===
    local titleFontSize = math.max(28, math.min(42, l.h * 0.06))
    local ac = theme.accentColor
    local displayTitle = ch .. ". " .. chapterName

    nvgFontSize(nvg, titleFontSize)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    if isUnlocked then
        nvgFillColor(nvg, nvgRGBA(ac[1], ac[2], ac[3], 255))
    else
        nvgFillColor(nvg, nvgRGBA(120, 120, 140, 200))
    end
    nvgText(nvg, cx, titleY, displayTitle)

    -- === 2. 章节卡片 ===
    DrawChapterCard(nvg, ch, cardX, cardY, cardW, cardH,
        isUnlocked, isCleared, progress, Battle.LEVELS_PER_CHAPTER)

    -- （左右箭头已由 UI 按钮替代，不再用 NanoVG 绘制）

    -- === 3. 宝箱区域（精致图标）===
    local chestGap = l.h * 0.06  -- 卡片与宝箱间距按比例（加大间距）
    local chestY = cardY + cardH + chestGap + 32
    local chestIconSize = math.max(48, l.h * 0.08)
    -- 加载宝箱图片（只加载一次）
    if not self._chestImgHandle then
        self._chestImgHandle = nvgCreateImage(nvg, "image/chest_flat_icon.png", 0)
    end
    local chestHandle = self._chestImgHandle
    if isCleared then
        -- 已领取：宝箱灰掉（低透明度显示）
        if chestHandle and chestHandle >= 0 then
            local pat = nvgImagePattern(nvg, cx - chestIconSize / 2, chestY - chestIconSize / 2, chestIconSize, chestIconSize, 0, chestHandle, 0.25)
            nvgBeginPath(nvg)
            nvgRect(nvg, cx - chestIconSize / 2, chestY - chestIconSize / 2, chestIconSize, chestIconSize)
            nvgFillPaint(nvg, pat)
            nvgFill(nvg)
        end
    else
        -- 未领取：金色呼吸光效 + 正常宝箱
        local chestGlow = math.floor(35 + math.sin(G.time * 2.5) * 25)
        nvgBeginPath(nvg)
        local chestPaint = nvgRadialGradient(nvg, cx, chestY, 12, 52,
            nvgRGBA(255, 200, 60, chestGlow), nvgRGBA(255, 200, 60, 0))
        nvgRect(nvg, cx - 52, chestY - 52, 104, 104)
        nvgFillPaint(nvg, chestPaint)
        nvgFill(nvg)
        if chestHandle and chestHandle >= 0 then
            local pat = nvgImagePattern(nvg, cx - chestIconSize / 2, chestY - chestIconSize / 2, chestIconSize, chestIconSize, 0, chestHandle, 1.0)
            nvgBeginPath(nvg)
            nvgRect(nvg, cx - chestIconSize / 2, chestY - chestIconSize / 2, chestIconSize, chestIconSize)
            nvgFillPaint(nvg, pat)
            nvgFill(nvg)
        end
    end
    -- 状态文字
    nvgFontSize(nvg, 20)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    if isCleared then
        nvgFillColor(nvg, nvgRGBA(120, 180, 120, 160))
        nvgText(nvg, cx, chestY + chestIconSize * 0.5 + 8, "已领取")
    else
        local txtGlow = math.floor(200 + math.sin(G.time * 2.0) * 55)
        nvgFillColor(nvg, nvgRGBA(255, 220, 100, txtGlow))
        nvgText(nvg, cx, chestY + chestIconSize * 0.5 + 8, "通关奖励")
    end

    -- === 4. 底部圆点指示器（4章）===
    local dotR = 5
    local dotGap = 24
    local totalChapters = 4
    local dotsW = (totalChapters - 1) * dotGap
    local dotStartX = cx - dotsW / 2
    local dotY = l.y + l.h - l.h * 0.02 - 6

    for i = 1, totalChapters do
        local dx = dotStartX + (i - 1) * dotGap
        local iUnlocked = true
        local iCleared = G.highestLevel > i * Battle.LEVELS_PER_CHAPTER
        nvgBeginPath(nvg)
        if i == ch then
            nvgCircle(nvg, dx, dotY, dotR + 1.5)
            nvgFillColor(nvg, nvgRGBA(255, 220, 80, 255))
        elseif iCleared then
            nvgCircle(nvg, dx, dotY, dotR)
            nvgFillColor(nvg, nvgRGBA(100, 160, 255, 200))
        elseif iUnlocked then
            nvgCircle(nvg, dx, dotY, dotR)
            nvgFillColor(nvg, nvgRGBA(100, 160, 255, 200))
        else
            nvgCircle(nvg, dx, dotY, dotR - 1)
            nvgFillColor(nvg, nvgRGBA(60, 60, 80, 150))
        end
        nvgFill(nvg)
    end
end

return MenuHeroWidget
