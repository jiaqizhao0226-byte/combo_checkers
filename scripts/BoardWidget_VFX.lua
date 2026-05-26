-- ============================================================================
-- BoardWidget_VFX - 视觉特效渲染（从 BoardWidget.lua 拆分）
-- ctx 字段: nvg, hexSize, ox, oy, t
-- 全局依赖: G, HexGrid, Battle, IconAtlas
-- ============================================================================
---@diagnostic disable: redefined-local, undefined-global

local G        = require "GameState"
local HexGrid  = require "HexGrid"
local Battle   = require "Battle"
local IconAtlas = require "IconAtlas"

-- 敌人颜色辅助（复制自 BoardWidget，保持独立性）
local ENEMY_COLORS = {
    slime           = {120, 220, 80},
    skeleton        = {220, 210, 190},
    mushroom        = {160, 80, 200},
    jellyfish       = {100, 200, 255},
    iron_turtle     = {150, 170, 190},
    vortex_eel      = {80, 120, 255},
    hermit_crab     = {200, 140, 60},
    fire_sprite     = {255, 120, 30},
    lava_giant      = {255, 80, 0},
    shadow_ambusher = {120, 60, 180},
    smoke_master    = {150, 150, 180},
    shadow_knight   = {180, 30, 50},
    abyss_kraken    = {100, 20, 160},
    lava_lord       = {255, 100, 0},
    coral_snapper   = {255, 120, 160},
    sea_urchin      = {80, 60, 120},
    reef_starfish   = {100, 200, 140},
    coral_guardian  = {255, 130, 180},
    ghost_shark     = {100, 140, 200},
    archerfish      = {60, 180, 230},
    electric_ray    = {120, 160, 220},
    spine_anemone   = {200, 80, 150},
    coral_priest    = {255, 180, 120},
    fission_flame   = {255, 100, 30},
    flame_shard     = {255, 160, 60},
}
local function GetEnemyColor(enemyType)
    return ENEMY_COLORS[enemyType] or {180, 60, 60}
end

--- 判断一个格子是否需要渲染（视锥剔除，向外扩展避免边缘裁切）
local function IsCellOnScreen(cx, cy, margin, lx, ly, lw, lh)
    return cx >= lx - margin and cx <= lx + lw + margin
       and cy >= ly - margin and cy <= ly + lh + margin
end

local BoardWidget_VFX = {}

--- 渲染所有 VFX 特效
--- @param ctx table  {nvg, hexSize, ox, oy, t, l}
function BoardWidget_VFX.Render(ctx)
    local nvg     = ctx.nvg
    local hexSize = ctx.hexSize
    local ox      = ctx.ox
    local oy      = ctx.oy
    local t       = ctx.t
    local l       = ctx.l

    -- 7.9 绘制视觉特效 (VFX)
    for _, fx in ipairs(G.battle.vfx) do
        local progress = 1.0 - fx.timer / fx.maxTimer  -- 0→1

        if fx.type == "lightning" then
            -- 闪电: 从起点到终点的锯齿线，带分叉
            local x1, y1 = HexGrid.HexToPixel(fx.fromCol, fx.fromRow, hexSize, ox, oy)
            local x2, y2 = HexGrid.HexToPixel(fx.toCol, fx.toRow, hexSize, ox, oy)
            local alpha = math.floor(math.max(0, (1.0 - progress * 1.5)) * 255)
            if alpha > 0 then
                local segments = 8
                -- 主干闪电
                for pass = 1, 2 do
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, x1, y1)
                    for s = 1, segments - 1 do
                        local t = s / segments
                        local mx = x1 + (x2 - x1) * t
                        local my = y1 + (y2 - y1) * t
                        local perp = (math.random() - 0.5) * hexSize * 0.6
                        nvgLineTo(nvg, mx + perp * 0.3, my + perp)
                    end
                    nvgLineTo(nvg, x2, y2)
                    if pass == 1 then
                        -- 外层光晕（粗+半透明白）
                        nvgStrokeColor(nvg, nvgRGBA(200, 220, 255, math.floor(alpha * 0.4)))
                        nvgStrokeWidth(nvg, 6)
                    else
                        -- 内核（细+亮黄）
                        nvgStrokeColor(nvg, nvgRGBA(255, 255, 100, alpha))
                        nvgStrokeWidth(nvg, 2)
                    end
                    nvgStroke(nvg)
                end
                -- 终点闪光圆
                local flashR = hexSize * 0.4 * (1.0 - progress)
                nvgBeginPath(nvg)
                nvgCircle(nvg, x2, y2, flashR)
                nvgFillColor(nvg, nvgRGBA(255, 255, 200, math.floor(alpha * 0.6)))
                nvgFill(nvg)
            end

        elseif fx.type == "shockwave" then
            -- 冲击波: 从中心扩散的多层圆环 + 填充闪光
            local cx, cy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)
            local maxR = hexSize * 2.8
            local ringR = maxR * progress
            local fade = math.max(0, 1.0 - progress)
            local alpha = math.floor(fade * 255)
            if alpha > 0 then
                -- 中心闪光填充（前40%时间）
                if progress < 0.4 then
                    local flashP = progress / 0.4
                    local flashAlpha = math.floor((1.0 - flashP) * 180)
                    local flashR = hexSize * (0.8 + flashP * 1.2)
                    local flashPaint = nvgRadialGradient(nvg, cx, cy, 0, flashR,
                        nvgRGBA(255, 220, 80, flashAlpha), nvgRGBA(255, 140, 40, 0))
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, cx, cy, flashR)
                    nvgFillPaint(nvg, flashPaint)
                    nvgFill(nvg)
                end
                -- 外环（橙红色，粗线）
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, ringR)
                nvgStrokeColor(nvg, nvgRGBA(255, 120, 30, alpha))
                nvgStrokeWidth(nvg, 4.0 * fade)
                nvgStroke(nvg)
                -- 中环（黄色）
                local midR = maxR * progress * 0.7
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, midR)
                nvgStrokeColor(nvg, nvgRGBA(255, 220, 60, math.floor(alpha * 0.8)))
                nvgStrokeWidth(nvg, 3.0 * fade)
                nvgStroke(nvg)
                -- 内环（白色高光）
                local innerR = maxR * progress * 0.4
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, innerR)
                nvgStrokeColor(nvg, nvgRGBA(255, 255, 200, math.floor(alpha * 0.6)))
                nvgStrokeWidth(nvg, 2.0 * fade)
                nvgStroke(nvg)
                -- 碎片粒子（6颗向外飞散）
                for i = 1, 6 do
                    local angle = (i / 6) * math.pi * 2 + progress * 1.5
                    local dist = ringR * 0.8
                    local px = cx + math.cos(angle) * dist
                    local py = cy + math.sin(angle) * dist
                    local pSize = 3.0 * fade
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, px, py, pSize)
                    nvgFillColor(nvg, nvgRGBA(255, 180, 50, math.floor(alpha * 0.7)))
                    nvgFill(nvg)
                end
            end

        elseif fx.type == "quake_land" then
            -- 震地落: 范围六角格高亮 + 中心冲击 + 命中格伤害数字
            local cx, cy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)
            local fade = math.max(0, 1.0 - progress)
            local alpha = math.floor(fade * 255)
            local cells = fx.affectedCells or {}
            local hits = fx.hitCells or {}
            local dmg = fx.damage or 0
            local aoeRange = fx.range or 1

            if alpha > 0 then
                -- === 阶段1: 中心落地闪光（前30%）===
                if progress < 0.3 then
                    local flashP = progress / 0.3
                    local flashAlpha = math.floor((1.0 - flashP) * 220)
                    local flashR = hexSize * (0.5 + flashP * (aoeRange + 0.5))
                    local flashPaint = nvgRadialGradient(nvg, cx, cy, 0, flashR,
                        nvgRGBA(255, 200, 60, flashAlpha), nvgRGBA(255, 100, 20, 0))
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, cx, cy, flashR)
                    nvgFillPaint(nvg, flashPaint)
                    nvgFill(nvg)
                end

                -- === 阶段2: 范围内六角格高亮（橙色半透明填充+描边）===
                local cellAlpha = math.floor(fade * 120)
                if progress < 0.7 then
                    local cellFade = progress < 0.15 and (progress / 0.15) or (1.0 - (progress - 0.15) / 0.55)
                    cellAlpha = math.floor(cellFade * 140)
                end
                for _, c in ipairs(cells) do
                    local hx, hy = HexGrid.HexToPixel(c.col, c.row, hexSize, ox, oy)
                    HexGrid.DrawHex(nvg, hx, hy, hexSize * 0.88,
                        nvgRGBA(255, 140, 30, cellAlpha),
                        nvgRGBA(255, 180, 50, math.min(255, math.floor(cellAlpha * 1.5))))
                end

                -- === 阶段3: 命中格特殊强调（红色脉冲）===
                for _, h in ipairs(hits) do
                    local hx, hy = HexGrid.HexToPixel(h.col, h.row, hexSize, ox, oy)
                    local hitPulse = math.sin(progress * 12) * 0.3 + 0.7
                    local hitAlpha = math.floor(fade * 180 * hitPulse)
                    HexGrid.DrawHex(nvg, hx, hy, hexSize * 0.85,
                        nvgRGBA(255, 60, 20, hitAlpha), nil)
                end

                -- === 阶段4: 扩散冲击环 ===
                local maxR = hexSize * (1.2 + aoeRange * 1.5)
                local ringR = maxR * math.min(1.0, progress * 1.5)
                local ringAlpha = math.floor(fade * 200)
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, ringR)
                nvgStrokeColor(nvg, nvgRGBA(255, 160, 40, ringAlpha))
                nvgStrokeWidth(nvg, 3.5 * fade)
                nvgStroke(nvg)

                -- 内环
                local innerR = ringR * 0.6
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, innerR)
                nvgStrokeColor(nvg, nvgRGBA(255, 220, 80, math.floor(ringAlpha * 0.7)))
                nvgStrokeWidth(nvg, 2.5 * fade)
                nvgStroke(nvg)

                -- === 阶段5: 伤害数字在范围边缘显示（醒目）===
                if dmg > 0 and progress > 0.1 and progress < 0.65 then
                    local txtAlpha = math.floor(fade * 255)
                    local txtY = cy - hexSize * (aoeRange + 0.5) - progress * 15
                    nvgFontSize(nvg, hexSize * 0.55)
                    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    -- 描边
                    nvgFillColor(nvg, nvgRGBA(0, 0, 0, txtAlpha))
                    nvgText(nvg, cx + 1, txtY + 1, "AOE -" .. dmg)
                    -- 正文
                    nvgFillColor(nvg, nvgRGBA(255, 180, 40, txtAlpha))
                    nvgText(nvg, cx, txtY, "AOE -" .. dmg)
                end

                -- 碎片粒子
                for i = 1, 8 do
                    local angle = (i / 8) * math.pi * 2 + progress * 2
                    local dist = ringR * 0.75
                    local px = cx + math.cos(angle) * dist
                    local py = cy + math.sin(angle) * dist
                    local pSize = 2.5 * fade
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, px, py, pSize)
                    nvgFillColor(nvg, nvgRGBA(255, 200, 60, math.floor(alpha * 0.6)))
                    nvgFill(nvg)
                end
            end

        elseif fx.type == "hex_blast" then
            -- 六芒冲击: 六方向射线延伸到棋盘边缘 + 涌动波浪 + AOE 格子高亮
            local cx, cy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)
            local fade = math.max(0, 1.0 - progress * 0.7)
            local alpha = math.floor(fade * 255)
            local cells = fx.cells or {}
            local rayEndCells = fx.rayEndCells or {}
            local hexW = math.sqrt(3) * hexSize

            -- 计算每条射线的实际方向和长度（基于格子坐标）
            local rayDirs = {}
            for ri, rc in ipairs(rayEndCells) do
                local ex, ey = HexGrid.HexToPixel(rc.col, rc.row, hexSize, ox, oy)
                local dx, dy = ex - cx, ey - cy
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist > 1 then
                    rayDirs[ri] = { angle = math.atan(dy, dx), len = dist + hexSize * 0.5 }
                else
                    -- fallback: 等间距角度
                    rayDirs[ri] = { angle = ((ri - 1) / 6) * math.pi * 2, len = hexSize * 3 }
                end
            end
            -- fallback: 没有 rayEndCells 时用固定角度
            if #rayDirs == 0 then
                local boardTotalW = G.gridParams.totalW or (HexGrid.COLS + 0.5) * hexW
                local boardTotalH = G.gridParams.totalH or (HexGrid.ROWS - 1) * 1.5 * hexSize + 2.5 * hexSize
                local fallbackLen = math.sqrt(boardTotalW * boardTotalW + boardTotalH * boardTotalH) * 0.55
                for i = 1, 6 do
                    rayDirs[i] = { angle = ((i - 1) / 6) * math.pi * 2 - math.pi / 6, len = fallbackLen }
                end
            end
            local maxRayLen = 0
            for _, rd in ipairs(rayDirs) do
                if rd.len > maxRayLen then maxRayLen = rd.len end
            end

            if alpha > 0 then
                -- === 阶段1: 中心爆发闪光（前25%）===
                if progress < 0.25 then
                    local flashP = progress / 0.25
                    local flashAlpha = math.floor((1.0 - flashP) * 240)
                    local flashR = hexSize * (0.3 + flashP * 1.5)
                    local flashPaint = nvgRadialGradient(nvg, cx, cy, 0, flashR,
                        nvgRGBA(220, 140, 255, flashAlpha), nvgRGBA(180, 80, 255, 0))
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, cx, cy, flashR)
                    nvgFillPaint(nvg, flashPaint)
                    nvgFill(nvg)

                    -- 六芒星闪光标志
                    if flashP > 0.2 then
                        local starAlpha = math.floor((1.0 - flashP) * 200)
                        local starR = hexSize * 0.8 * flashP
                        nvgBeginPath(nvg)
                        for si = 0, 5 do
                            local a = (si / 6) * math.pi * 2 - math.pi / 2
                            local sr = (si % 2 == 0) and starR or (starR * 0.45)
                            local sx = cx + math.cos(a) * sr
                            local sy = cy + math.sin(a) * sr
                            if si == 0 then nvgMoveTo(nvg, sx, sy) else nvgLineTo(nvg, sx, sy) end
                        end
                        nvgClosePath(nvg)
                        nvgFillColor(nvg, nvgRGBA(255, 230, 255, starAlpha))
                        nvgFill(nvg)
                    end
                end

                -- === 阶段2: 六方向射线向棋盘边缘涌动（5%~70%）===
                local rayProgress = math.max(0, math.min(1.0, (progress - 0.05) / 0.65))
                if rayProgress > 0 then
                    -- 射线使用 ease-out 曲线，快速扩展
                    local easeRay = 1.0 - (1.0 - rayProgress) * (1.0 - rayProgress)
                    local rayFade = (progress < 0.65) and 1.0 or math.max(0, (1.0 - progress) / 0.35)
                    local rayAlpha = math.floor(rayFade * 230)

                    for i = 1, #rayDirs do
                        local rd = rayDirs[i]
                        local rayLen = rd.len * easeRay
                        local cosA = math.cos(rd.angle)
                        local sinA = math.sin(rd.angle)
                        local ex = cx + cosA * rayLen
                        local ey = cy + sinA * rayLen

                        -- 射线外辉光（最宽，柔和）
                        nvgBeginPath(nvg)
                        nvgMoveTo(nvg, cx, cy)
                        nvgLineTo(nvg, ex, ey)
                        nvgStrokeColor(nvg, nvgRGBA(140, 60, 220, math.floor(rayAlpha * 0.15)))
                        nvgStrokeWidth(nvg, 22.0 * rayFade)
                        nvgStroke(nvg)

                        -- 射线辉光（宽半透明）
                        nvgBeginPath(nvg)
                        nvgMoveTo(nvg, cx, cy)
                        nvgLineTo(nvg, ex, ey)
                        nvgStrokeColor(nvg, nvgRGBA(180, 100, 255, math.floor(rayAlpha * 0.3)))
                        nvgStrokeWidth(nvg, 12.0 * rayFade)
                        nvgStroke(nvg)

                        -- 射线主体（明亮核心）
                        nvgBeginPath(nvg)
                        nvgMoveTo(nvg, cx, cy)
                        nvgLineTo(nvg, ex, ey)
                        nvgStrokeColor(nvg, nvgRGBA(210, 150, 255, rayAlpha))
                        nvgStrokeWidth(nvg, 4.0 * rayFade)
                        nvgStroke(nvg)

                        -- 射线中心高亮线（白色细线）
                        nvgBeginPath(nvg)
                        nvgMoveTo(nvg, cx, cy)
                        nvgLineTo(nvg, ex, ey)
                        nvgStrokeColor(nvg, nvgRGBA(255, 240, 255, math.floor(rayAlpha * 0.6)))
                        nvgStrokeWidth(nvg, 1.5 * rayFade)
                        nvgStroke(nvg)

                        -- 射线前端涌动光球（能量波头）
                        if easeRay > 0.05 then
                            local headDist = rayLen
                            local headX = cx + cosA * headDist
                            local headY = cy + sinA * headDist
                            local headR = 6.0 * rayFade
                            local headAlpha = math.floor(rayAlpha * 0.9)
                            local headPaint = nvgRadialGradient(nvg, headX, headY, 0, headR * 2,
                                nvgRGBA(255, 220, 255, headAlpha), nvgRGBA(200, 130, 255, 0))
                            nvgBeginPath(nvg)
                            nvgCircle(nvg, headX, headY, headR * 2)
                            nvgFillPaint(nvg, headPaint)
                            nvgFill(nvg)
                            -- 光球核心
                            nvgBeginPath(nvg)
                            nvgCircle(nvg, headX, headY, headR * 0.5)
                            nvgFillColor(nvg, nvgRGBA(255, 255, 255, headAlpha))
                            nvgFill(nvg)
                        end
                    end
                end

                -- === 阶段3: 涌动波纹环（从中心向外扩散）===
                -- 多层波纹，产生脉冲涌动感
                for waveIdx = 0, 2 do
                    local waveDelay = waveIdx * 0.12
                    local waveP = math.max(0, math.min(1.0, (progress - 0.08 - waveDelay) / 0.55))
                    if waveP > 0 and waveP < 1.0 then
                        local easeWave = 1.0 - (1.0 - waveP) * (1.0 - waveP)
                        local waveR = maxRayLen * easeWave * 0.95
                        local waveFade = (1.0 - waveP) * (1.0 - waveIdx * 0.25)
                        local waveAlpha = math.floor(waveFade * 120)
                        if waveAlpha > 5 then
                            -- 六边形波纹（而非圆形）
                            nvgBeginPath(nvg)
                            for si = 0, 5 do
                                local a = (si / 6) * math.pi * 2 - math.pi / 6
                                local wx = cx + math.cos(a) * waveR
                                local wy = cy + math.sin(a) * waveR
                                if si == 0 then nvgMoveTo(nvg, wx, wy) else nvgLineTo(nvg, wx, wy) end
                            end
                            nvgClosePath(nvg)
                            nvgStrokeColor(nvg, nvgRGBA(200, 140, 255, waveAlpha))
                            nvgStrokeWidth(nvg, (3.0 - waveIdx * 0.8) * waveFade)
                            nvgStroke(nvg)
                        end
                    end
                end

                -- === 阶段4: AOE 格子高亮边界（逐格点亮，波浪传递感）===
                if #cells > 0 then
                    local cellFade = (progress < 0.7) and 1.0 or math.max(0, (1.0 - progress) / 0.3)
                    local cellAlpha = math.floor(cellFade * 200)

                    for ci, cell in ipairs(cells) do
                        local px, py = HexGrid.HexToPixel(cell.col, cell.row, hexSize, ox, oy)
                        -- 计算该格距中心的距离层级，实现逐格点亮
                        local distFromCenter = math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy))
                        local maxCellDist = hexW * 3.5
                        local normDist = math.min(1.0, distFromCenter / maxCellDist)
                        -- 每个格子有自己的激活时间，远的格子更晚亮
                        local cellActivateTime = 0.1 + normDist * 0.25
                        local cellP = math.max(0, (progress - cellActivateTime) / 0.3)
                        cellP = math.min(1.0, cellP)

                        if cellP > 0 then
                            -- 格子亮度脉冲（刚激活时最亮）
                            local cellPulse = (cellP < 0.4) and (cellP / 0.4) or 1.0
                            local brightBoost = (cellP < 0.3) and (1.0 + (1.0 - cellP / 0.3) * 0.8) or 1.0
                            local thisAlpha = math.floor(cellAlpha * cellPulse * cellFade)

                            -- 格子填充（半透明紫色，激活时闪亮）
                            local fillAlpha = math.floor(thisAlpha * 0.35 * brightBoost)
                            nvgBeginPath(nvg)
                            for v = 0, 5 do
                                local a = (v / 6) * math.pi * 2 - math.pi / 6
                                local vx = px + math.cos(a) * (hexSize * 0.9)
                                local vy = py + math.sin(a) * (hexSize * 0.9)
                                if v == 0 then nvgMoveTo(nvg, vx, vy) else nvgLineTo(nvg, vx, vy) end
                            end
                            nvgClosePath(nvg)
                            nvgFillColor(nvg, nvgRGBA(180, 100, 255, fillAlpha))
                            nvgFill(nvg)

                            -- 格子边界（明亮紫色边框，激活时闪白）
                            local borderR = math.floor(brightBoost > 1.2 and 240 or 220)
                            local borderG = math.floor(brightBoost > 1.2 and 200 or 160)
                            nvgBeginPath(nvg)
                            for v = 0, 5 do
                                local a = (v / 6) * math.pi * 2 - math.pi / 6
                                local vx = px + math.cos(a) * (hexSize * 0.9)
                                local vy = py + math.sin(a) * (hexSize * 0.9)
                                if v == 0 then nvgMoveTo(nvg, vx, vy) else nvgLineTo(nvg, vx, vy) end
                            end
                            nvgClosePath(nvg)
                            nvgStrokeColor(nvg, nvgRGBA(borderR, borderG, 255, thisAlpha))
                            nvgStrokeWidth(nvg, (brightBoost > 1.2 and 3.5 or 2.5) * cellFade)
                            nvgStroke(nvg)
                        end
                    end
                end

                -- === 阶段5: 能量粒子沿射线飞散到边缘 ===
                if progress > 0.08 and progress < 0.85 then
                    local particleP = (progress - 0.08) / 0.77
                    local pAlpha = math.floor((1.0 - particleP * 0.8) * 180)
                    for i = 1, #rayDirs do
                        local rd = rayDirs[i]
                        -- 每条射线5颗粒子，沿射线分布
                        for p = 1, 5 do
                            local pPhase = (particleP + (p - 1) * 0.18) % 1.0
                            local pDist = rd.len * pPhase * 0.9
                            local spread = (p % 3 - 1) * 0.06
                            local angle = rd.angle + spread
                            local ppx = cx + math.cos(angle) * pDist
                            local ppy = cy + math.sin(angle) * pDist
                            local pSize = (4.0 - p * 0.4) * (1.0 - pPhase * 0.6) * fade
                            if pSize > 0.5 then
                                nvgBeginPath(nvg)
                                nvgCircle(nvg, ppx, ppy, pSize)
                                nvgFillColor(nvg, nvgRGBA(230, 180, 255, math.floor(pAlpha * (1.0 - pPhase * 0.5))))
                                nvgFill(nvg)
                            end
                        end
                    end
                end

                -- === 阶段6: 中心总伤害数字（爽感反馈）===
                local fxHitCount = fx.hitCount or 0
                local fxTotalDmg = fx.totalDmg or 0
                if fxHitCount > 0 and progress > 0.25 and progress < 0.95 then
                    local dmgTextP = math.min(1.0, (progress - 0.25) / 0.15)
                    local dmgFade = (progress < 0.8) and 1.0 or math.max(0, (0.95 - progress) / 0.15)
                    local dmgAlpha = math.floor(dmgFade * 255)
                    -- 数字从小到大弹出
                    local dmgScale = 0.6 + dmgTextP * 0.4
                    if dmgTextP < 1.0 then
                        dmgScale = 0.6 + (1.0 - (1.0 - dmgTextP) * (1.0 - dmgTextP)) * 0.5
                    end
                    local dmgY = cy - hexSize * 1.2
                    local dmgText = string.format("-%d", fxTotalDmg)
                    -- 阴影
                    nvgFontSize(nvg, hexSize * 0.7 * dmgScale)
                    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(nvg, nvgRGBA(0, 0, 0, math.floor(dmgAlpha * 0.5)))
                    nvgText(nvg, cx + 2, dmgY + 2, dmgText)
                    -- 主数字（亮紫白色）
                    nvgFillColor(nvg, nvgRGBA(255, 200, 255, dmgAlpha))
                    nvgText(nvg, cx, dmgY, dmgText)
                    -- 命中数提示
                    local hitLabel = string.format("💫 %d 命中", fxHitCount)
                    nvgFontSize(nvg, hexSize * 0.3)
                    nvgFillColor(nvg, nvgRGBA(220, 180, 255, math.floor(dmgAlpha * 0.8)))
                    nvgText(nvg, cx, dmgY + hexSize * 0.45, hitLabel)
                end
            end

        elseif fx.type == "scarecrow_fade" then
            -- 稻草人消散/被击毁淡出特效
            local scx, scy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)
            local scR = hexSize * 0.45
            local fadeAlpha = math.max(0, 1.0 - progress * 1.2)
            local totalAbsorbed = fx.totalAbsorbed or 0
            local hitCount = fx.hitCount or 0
            local isDestroy = (fx.reason == "destroy")

            if fadeAlpha > 0 then
                -- 残影（稻草人图标渐隐上飘，无底色）
                local bodyAlpha = math.floor(fadeAlpha * 255)
                local floatY = scy - progress * hexSize * 0.6
                local swayFade = math.sin(progress * 8.0) * 0.1 * fadeAlpha
                nvgSave(nvg)
                nvgTranslate(nvg, scx, floatY)
                nvgRotate(nvg, swayFade)
                IconAtlas.DrawNVG(nvg, "board_scarecrow", 0, 0, scR * 2.2 * (1.0 + progress * 0.2), bodyAlpha / 255)
                nvgRestore(nvg)
            end

            -- 消散粒子（向外飘散的碎片）
            if progress > 0.1 and progress < 0.9 then
                local pP = (progress - 0.1) / 0.8
                local pAlpha = math.floor((1.0 - pP) * 200)
                for i = 1, 8 do
                    local angle = (i / 8) * math.pi * 2 + progress * 2.0
                    local dist = scR * (0.5 + pP * 2.5)
                    local px = scx + math.cos(angle) * dist
                    local py = scy + math.sin(angle) * dist - pP * hexSize * 0.3
                    local pSize = (3.5 - pP * 2.5)
                    if pSize > 0.5 then
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, px, py, pSize)
                        if isDestroy then
                            nvgFillColor(nvg, nvgRGBA(255, 140, 50, pAlpha))
                        else
                            nvgFillColor(nvg, nvgRGBA(200, 180, 80, pAlpha))
                        end
                        nvgFill(nvg)
                    end
                end
            end

            -- 承伤汇总文字（中后段显示）
            if progress > 0.2 and progress < 0.95 and totalAbsorbed > 0 then
                local textP = math.min(1.0, (progress - 0.2) / 0.3)
                local textFade = (progress < 0.75) and 1.0 or math.max(0, (0.95 - progress) / 0.2)
                local textAlpha = math.floor(textFade * 255)
                local textY = scy - hexSize * (0.8 + progress * 0.4)
                -- 背景条
                local labelText = string.format("共承受 %d 伤害", totalAbsorbed)
                nvgFontSize(nvg, hexSize * 0.3)
                nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                local bounds = {}
                nvgTextBounds(nvg, scx, textY, labelText, bounds)
                local tw = (bounds[3] or scx + 40) - (bounds[1] or scx - 40)
                local padX, padY = 8, 4
                nvgBeginPath(nvg)
                nvgRoundedRect(nvg, scx - tw / 2 - padX, textY - hexSize * 0.15 - padY,
                    tw + padX * 2, hexSize * 0.3 + padY * 2, 4)
                nvgFillColor(nvg, nvgRGBA(0, 0, 0, math.floor(textAlpha * 0.6)))
                nvgFill(nvg)
                -- 文字
                nvgFillColor(nvg, nvgRGBA(255, 220, 80, textAlpha))
                nvgText(nvg, scx, textY, labelText)
            end

        elseif fx.type == "heal" then
            -- 吸血治愈: 红色粒子从敌人位置流向英雄
            if not fx.fromCol or not fx.toCol then goto continue_fx end
            local x1, y1 = HexGrid.HexToPixel(fx.fromCol, fx.fromRow, hexSize, ox, oy)
            local x2, y2 = HexGrid.HexToPixel(fx.toCol, fx.toRow, hexSize, ox, oy)
            local alpha = math.floor(math.max(0, 1.0 - progress * 1.3) * 255)
            if alpha > 0 then
                -- 多个粒子沿路径分布
                for i = 1, 5 do
                    local t = (progress + (i - 1) * 0.15) % 1.0
                    local px = x1 + (x2 - x1) * t
                    local py = y1 + (y2 - y1) * t + math.sin(t * 12 + i) * 6
                    local pSize = (3 + math.sin(i * 2.1) * 2) * (1.0 - t * 0.5)
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, px, py, pSize)
                    nvgFillColor(nvg, nvgRGBA(220, 40, 40, math.floor(alpha * (1.0 - t * 0.6))))
                    nvgFill(nvg)
                end
                -- 英雄位置光环
                if progress > 0.3 then
                    local hAlpha = math.floor((progress - 0.3) / 0.7 * 100 * (1.0 - progress))
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, x2, y2, hexSize * 0.55)
                    nvgStrokeColor(nvg, nvgRGBA(200, 60, 60, math.max(0, hAlpha)))
                    nvgStrokeWidth(nvg, 2)
                    nvgStroke(nvg)
                end
            end

        elseif fx.type == "dawn_guard" then
            -- 黎明守护: 圣光复活特效（从天而降的光柱 + 十字光芒 + 光环扩散 + 粒子升腾）
            local cx, cy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)
            local t = fx.timer or 0

            -- 阶段划分: 0~0.3 光柱降临, 0.3~0.7 十字光芒+光环, 0.7~1.0 消散
            local phase1 = math.min(progress / 0.3, 1.0)         -- 光柱降临
            local phase2 = math.max(0, math.min((progress - 0.2) / 0.5, 1.0))  -- 光芒展开
            local fadeOut = math.max(0, (progress - 0.7) / 0.3)  -- 消散

            local masterAlpha = fadeOut < 1.0 and 1.0 - fadeOut * fadeOut or 0.0

            if masterAlpha > 0.01 then
                -- === 1. 全屏闪白（瞬间触发） ===
                if progress < 0.15 then
                    local flashA = math.floor((1.0 - progress / 0.15) * 80)
                    nvgBeginPath(nvg)
                    nvgRect(nvg, -9999, -9999, 99999, 99999)
                    nvgFillColor(nvg, nvgRGBA(255, 240, 200, flashA))
                    nvgFill(nvg)
                end

                -- === 2. 光柱（从天降下） ===
                local beamW = hexSize * 0.8 * phase1
                local beamH = hexSize * 5.0
                local beamTop = cy - beamH * phase1
                local beamAlpha = math.floor(masterAlpha * 180 * math.min(phase1 * 2, 1.0))
                -- 光柱主体（渐变：顶部窄底部宽）
                local beamPaint = nvgLinearGradient(nvg,
                    cx, beamTop, cx, cy + hexSize * 0.3,
                    nvgRGBA(255, 250, 220, math.floor(beamAlpha * 0.3)),
                    nvgRGBA(255, 220, 100, beamAlpha))
                nvgBeginPath(nvg)
                local topW = beamW * 0.3
                nvgMoveTo(nvg, cx - topW, beamTop)
                nvgLineTo(nvg, cx + topW, beamTop)
                nvgLineTo(nvg, cx + beamW, cy + hexSize * 0.3)
                nvgLineTo(nvg, cx - beamW, cy + hexSize * 0.3)
                nvgClosePath(nvg)
                nvgFillPaint(nvg, beamPaint)
                nvgFill(nvg)

                -- 光柱边缘发光线
                nvgBeginPath(nvg)
                nvgMoveTo(nvg, cx - topW, beamTop)
                nvgLineTo(nvg, cx - beamW, cy + hexSize * 0.3)
                nvgMoveTo(nvg, cx + topW, beamTop)
                nvgLineTo(nvg, cx + beamW, cy + hexSize * 0.3)
                nvgStrokeColor(nvg, nvgRGBA(255, 240, 180, math.floor(beamAlpha * 0.6)))
                nvgStrokeWidth(nvg, 1.5)
                nvgStroke(nvg)

                -- === 3. 十字光芒（从中心向四方展开） ===
                if phase2 > 0 then
                    local crossLen = hexSize * 2.5 * phase2
                    local crossW = hexSize * 0.12 * (1.0 - fadeOut * 0.5)
                    local crossAlpha = math.floor(masterAlpha * 200)
                    -- 水平光芒
                    local hPaint = nvgLinearGradient(nvg,
                        cx - crossLen, cy, cx + crossLen, cy,
                        nvgRGBA(255, 220, 100, 0),
                        nvgRGBA(255, 240, 180, crossAlpha))
                    nvgBeginPath(nvg)
                    nvgRect(nvg, cx - crossLen, cy - crossW, crossLen, crossW * 2)
                    nvgFillPaint(nvg, hPaint)
                    nvgFill(nvg)
                    local hPaint2 = nvgLinearGradient(nvg,
                        cx + crossLen, cy, cx - crossLen, cy,
                        nvgRGBA(255, 220, 100, 0),
                        nvgRGBA(255, 240, 180, crossAlpha))
                    nvgBeginPath(nvg)
                    nvgRect(nvg, cx, cy - crossW, crossLen, crossW * 2)
                    nvgFillPaint(nvg, hPaint2)
                    nvgFill(nvg)
                    -- 垂直光芒
                    local vPaint = nvgLinearGradient(nvg,
                        cx, cy - crossLen, cx, cy + crossLen,
                        nvgRGBA(255, 220, 100, 0),
                        nvgRGBA(255, 240, 180, crossAlpha))
                    nvgBeginPath(nvg)
                    nvgRect(nvg, cx - crossW, cy - crossLen, crossW * 2, crossLen)
                    nvgFillPaint(nvg, vPaint)
                    nvgFill(nvg)
                    local vPaint2 = nvgLinearGradient(nvg,
                        cx, cy + crossLen, cx, cy - crossLen,
                        nvgRGBA(255, 220, 100, 0),
                        nvgRGBA(255, 240, 180, crossAlpha))
                    nvgBeginPath(nvg)
                    nvgRect(nvg, cx - crossW, cy, crossW * 2, crossLen)
                    nvgFillPaint(nvg, vPaint2)
                    nvgFill(nvg)
                end

                -- === 4. 光环扩散（从脚下向外扩展的圆环） ===
                if phase2 > 0 then
                    for ring = 1, 3 do
                        local ringDelay = (ring - 1) * 0.15
                        local ringP = math.max(0, phase2 - ringDelay) / (1.0 - ringDelay)
                        if ringP > 0 and ringP < 1 then
                            local ringR = hexSize * (0.4 + ringP * 2.0)
                            local ringA = math.floor(masterAlpha * (1.0 - ringP) * 160)
                            nvgBeginPath(nvg)
                            nvgCircle(nvg, cx, cy, ringR)
                            nvgStrokeColor(nvg, nvgRGBA(255, 230, 130, ringA))
                            nvgStrokeWidth(nvg, 2.5 * (1.0 - ringP * 0.5))
                            nvgStroke(nvg)
                        end
                    end
                end

                -- === 5. 中心光球（脉动） ===
                local pulseR = hexSize * (0.35 + math.sin(t * 8) * 0.08) * math.min(phase1 * 3, 1.0)
                local glowPaint = nvgRadialGradient(nvg,
                    cx, cy, pulseR * 0.2, pulseR,
                    nvgRGBA(255, 255, 240, math.floor(masterAlpha * 220)),
                    nvgRGBA(255, 220, 80, 0))
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, pulseR)
                nvgFillPaint(nvg, glowPaint)
                nvgFill(nvg)

                -- === 6. 上升光粒子 ===
                for i = 1, 12 do
                    local seed = i * 137.5
                    local pPhase = (progress * 1.5 + seed / 360) % 1.0
                    local pAngle = seed * math.pi / 180
                    local pDist = hexSize * (0.2 + pPhase * 0.8)
                    local px = cx + math.cos(pAngle) * pDist * (0.5 + math.sin(seed) * 0.3)
                    local py = cy - pPhase * hexSize * 2.5
                    local pAlpha = math.floor(masterAlpha * (1.0 - pPhase) * 200)
                    local pSize = (2.5 + math.sin(seed * 0.7) * 1.5) * (1.0 - pPhase * 0.5)
                    if pAlpha > 5 then
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, px, py, pSize)
                        nvgFillColor(nvg, nvgRGBA(255, 240, 180, pAlpha))
                        nvgFill(nvg)
                    end
                end

                -- === 7. 六芒星阵（旋转） ===
                if phase2 > 0.2 then
                    local starAlpha = math.floor(masterAlpha * math.min((phase2 - 0.2) / 0.3, 1.0) * 140)
                    local starR = hexSize * 1.2
                    local starRot = t * 0.8
                    nvgSave(nvg)
                    nvgTranslate(nvg, cx, cy)
                    nvgRotate(nvg, starRot)
                    -- 绘制六芒星（两个交叉三角形）
                    for tri = 0, 1 do
                        local offset = tri * math.pi / 3
                        nvgBeginPath(nvg)
                        for v = 0, 2 do
                            local a = offset + v * (2 * math.pi / 3) - math.pi / 2
                            local sx = math.cos(a) * starR
                            local sy = math.sin(a) * starR
                            if v == 0 then nvgMoveTo(nvg, sx, sy)
                            else nvgLineTo(nvg, sx, sy) end
                        end
                        nvgClosePath(nvg)
                        nvgStrokeColor(nvg, nvgRGBA(255, 220, 100, starAlpha))
                        nvgStrokeWidth(nvg, 1.5)
                        nvgStroke(nvg)
                    end
                    nvgRestore(nvg)
                end

                -- === 8. 复活文字提示（中期显示） ===
                if progress > 0.25 and progress < 0.85 then
                    local textFade
                    if progress < 0.35 then
                        textFade = (progress - 0.25) / 0.10  -- 淡入
                    elseif progress > 0.70 then
                        textFade = 1.0 - (progress - 0.70) / 0.15  -- 淡出
                    else
                        textFade = 1.0
                    end
                    local textAlpha = math.floor(textFade * 255)
                    -- "黎明使者" 标题
                    nvgFontFace(nvg, "sans")
                    nvgFontSize(nvg, hexSize * 0.42)
                    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(nvg, nvgRGBA(255, 230, 130, textAlpha))
                    nvgText(nvg, cx, cy - hexSize * 1.6, "☀️ 黎明使者")
                    -- "恢复 XX HP" 副标题
                    nvgFontSize(nvg, hexSize * 0.32)
                    local hpText = string.format("恢复 %d HP", fx.reviveHp or 0)
                    nvgFillColor(nvg, nvgRGBA(130, 255, 170, textAlpha))
                    nvgText(nvg, cx, cy - hexSize * 1.2, hpText)
                end
            end

        elseif fx.type == "thorns" then
            -- 荆棘反弹: 英雄处放射尖刺 + 一条弹射线到敌人
            local hx, hy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)
            local ex, ey = HexGrid.HexToPixel(fx.targetCol, fx.targetRow, hexSize, ox, oy)
            local alpha = math.floor(math.max(0, 1.0 - progress * 1.5) * 220)
            if alpha > 0 then
                -- 英雄周围尖刺（8方向）
                local spikeLen = hexSize * 0.5 * (1.0 - progress * 0.5)
                for a = 0, 7 do
                    local angle = a * math.pi / 4
                    local sx = hx + math.cos(angle) * hexSize * 0.3
                    local sy = hy + math.sin(angle) * hexSize * 0.3
                    local tx = hx + math.cos(angle) * (hexSize * 0.3 + spikeLen)
                    local ty = hy + math.sin(angle) * (hexSize * 0.3 + spikeLen)
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, sx, sy)
                    nvgLineTo(nvg, tx, ty)
                    nvgStrokeColor(nvg, nvgRGBA(180, 120, 255, alpha))
                    nvgStrokeWidth(nvg, 2)
                    nvgStroke(nvg)
                end
                -- 反弹射线到敌人
                local lineT = math.min(1.0, progress * 3.0)
                local lx = hx + (ex - hx) * lineT
                local ly = hy + (ey - hy) * lineT
                nvgBeginPath(nvg)
                nvgMoveTo(nvg, hx, hy)
                nvgLineTo(nvg, lx, ly)
                nvgStrokeColor(nvg, nvgRGBA(200, 150, 255, alpha))
                nvgStrokeWidth(nvg, 2.5)
                nvgStroke(nvg)
                -- 击中闪光
                if lineT >= 0.95 then
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, ex, ey, hexSize * 0.35 * (1.0 - progress))
                    nvgFillColor(nvg, nvgRGBA(200, 150, 255, math.floor(alpha * 0.5)))
                    nvgFill(nvg)
                end
            end

        elseif fx.type == "stomp" then
            -- 重力践踏: 地面裂纹放射线 + 冲击环
            local cx, cy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)
            local alpha = math.floor(math.max(0, 1.0 - progress * 1.5) * 255)
            if alpha > 0 then
                -- 放射裂纹（6方向）
                for a = 0, 5 do
                    local angle = a * math.pi / 3 + 0.2
                    local len = hexSize * (0.8 + progress * 1.0)
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, cx, cy)
                    -- 中间拐点
                    local mx = cx + math.cos(angle) * len * 0.5 + (math.random() - 0.5) * 4
                    local my = cy + math.sin(angle) * len * 0.5 + (math.random() - 0.5) * 4
                    nvgLineTo(nvg, mx, my)
                    nvgLineTo(nvg, cx + math.cos(angle) * len, cy + math.sin(angle) * len)
                    nvgStrokeColor(nvg, nvgRGBA(200, 160, 60, alpha))
                    nvgStrokeWidth(nvg, 2.5 * (1.0 - progress))
                    nvgStroke(nvg)
                end
                -- 落点冲击环
                local ringR = hexSize * 0.6 * (1.0 + progress)
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, ringR)
                nvgStrokeColor(nvg, nvgRGBA(220, 180, 50, math.floor(alpha * 0.7)))
                nvgStrokeWidth(nvg, 2)
                nvgStroke(nvg)
            end

        elseif fx.type == "poison_puff" then
            -- 毒雾喷发: 绿色粒子向外扩散 + 中心雾团
            local cx, cy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)
            local alpha = math.floor(math.max(0, 1.0 - progress) * 220)
            if alpha > 0 then
                -- 外圈扩散粒子（两层，12个）
                for i = 1, 12 do
                    local angle = (i / 12) * math.pi * 2 + progress * 2.5
                    local dist = hexSize * (0.15 + progress * 0.9)
                    local px = cx + math.cos(angle) * dist
                    local py = cy + math.sin(angle) * dist * 0.7
                    local pSize = (5 + math.sin(i * 1.7) * 2) * (1.0 - progress * 0.5)
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, px, py, pSize)
                    nvgFillColor(nvg, nvgRGBA(70, 200, 70, alpha))
                    nvgFill(nvg)
                end
                -- 中心雾团（模糊扩散效果）
                local fogRadius = hexSize * (0.3 + progress * 0.3) * (1.0 - progress * 0.2)
                local fogAlpha = math.floor(alpha * 0.5)
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, fogRadius)
                nvgFillColor(nvg, nvgRGBA(50, 170, 50, fogAlpha))
                nvgFill(nvg)
                -- 更大的半透明外雾
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, fogRadius * 1.6)
                nvgFillColor(nvg, nvgRGBA(60, 180, 60, math.floor(fogAlpha * 0.3)))
                nvgFill(nvg)
            end

        elseif fx.type == "ranged_attack" then
            -- 远程投掷: 投射物从敌人飞向英雄（配色匹配敌人类型）
            local x1, y1 = HexGrid.HexToPixel(fx.fromCol, fx.fromRow, hexSize, ox, oy)
            local x2, y2 = HexGrid.HexToPixel(fx.toCol, fx.toRow, hexSize, ox, oy)
            local alpha = math.floor(math.max(0, 1.0 - progress * 1.2) * 255)
            local ec = GetEnemyColor(fx.enemyType)
            if alpha > 0 then
                -- 投射物位置
                local t = math.min(1.0, progress * 1.5)
                local px = x1 + (x2 - x1) * t
                local py = y1 + (y2 - y1) * t - math.sin(t * math.pi) * hexSize * 0.5  -- 抛物线
                -- 投射物（配色）
                local projSize = hexSize * 0.2 * (1.0 - t * 0.3)
                nvgBeginPath(nvg)
                nvgCircle(nvg, px, py, projSize)
                nvgFillColor(nvg, nvgRGBA(ec[1], ec[2], ec[3], alpha))
                nvgFill(nvg)
                -- 发光边缘
                nvgBeginPath(nvg)
                nvgCircle(nvg, px, py, projSize * 1.3)
                nvgStrokeColor(nvg, nvgRGBA(
                    math.min(255, ec[1] + 60),
                    math.min(255, ec[2] + 60),
                    math.min(255, ec[3] + 60), math.floor(alpha * 0.5)))
                nvgStrokeWidth(nvg, 1.5)
                nvgStroke(nvg)
                -- 拖尾粒子（配色渐暗）
                for i = 1, 4 do
                    local tt = math.max(0, t - i * 0.05)
                    local tx = x1 + (x2 - x1) * tt
                    local ty = y1 + (y2 - y1) * tt - math.sin(tt * math.pi) * hexSize * 0.5
                    local tAlpha = math.floor(alpha * (1.0 - i * 0.25))
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, tx, ty, projSize * (0.6 - i * 0.1))
                    nvgFillColor(nvg, nvgRGBA(ec[1], ec[2], ec[3], math.max(0, tAlpha)))
                    nvgFill(nvg)
                end
                -- 落点冲击（配色爆发）
                if t >= 0.9 then
                    local impactP = (t - 0.9) / 0.1
                    local impactAlpha = math.floor(impactP * 180 * (1.0 - progress))
                    local impactR = hexSize * 0.35 * impactP
                    local ip = nvgRadialGradient(nvg, x2, y2, 0, impactR,
                        nvgRGBA(255, 255, 255, math.floor(impactAlpha * 0.6)),
                        nvgRGBA(ec[1], ec[2], ec[3], 0))
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, x2, y2, impactR)
                    nvgFillPaint(nvg, ip)
                    nvgFill(nvg)
                end
            end

        elseif fx.type == "melee_slam" then
            -- 近战冲击波: 从攻击方向扩散的环形伤害波
            local cx, cy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)
            local ex, ey = HexGrid.HexToPixel(fx.fromCol, fx.fromRow, hexSize, ox, oy)
            local alpha = math.floor(math.max(0, 1.0 - progress) * 255)
            if alpha > 0 then
                -- 敌人颜色（根据类型配色表）
                local ec = GetEnemyColor(fx.enemyType)
                local cr, cg, cb = ec[1], ec[2], ec[3]

                -- 冲击方向（敌人→英雄）
                local dx = cx - ex
                local dy = cy - ey
                local len = math.sqrt(dx * dx + dy * dy)
                if len < 1 then len = 1 end
                local nx, ny = dx / len, dy / len

                -- 第一层: 快速扩散的冲击环
                local ring1R = hexSize * (0.3 + progress * 1.2)
                local ring1Alpha = math.floor(alpha * math.max(0, 1.0 - progress * 1.3))
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, ring1R)
                nvgStrokeColor(nvg, nvgRGBA(cr, cg, cb, ring1Alpha))
                nvgStrokeWidth(nvg, 3.0 * (1.0 - progress))
                nvgStroke(nvg)

                -- 第二层: 稍慢的内环
                local ring2R = hexSize * (0.2 + progress * 0.8)
                local ring2Alpha = math.floor(alpha * 0.6 * math.max(0, 1.0 - progress))
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, ring2R)
                nvgStrokeColor(nvg, nvgRGBA(255, 255, 255, ring2Alpha))
                nvgStrokeWidth(nvg, 2.0 * (1.0 - progress * 0.8))
                nvgStroke(nvg)

                -- 冲击线: 从敌人方向到英雄的速度线
                if progress < 0.4 then
                    local lineAlpha = math.floor((1.0 - progress / 0.4) * 200)
                    local lineLen = hexSize * 0.6
                    -- 3条速度线（扇形分布）
                    for i = -1, 1 do
                        local spread = i * 0.3
                        local lnx = nx * math.cos(spread) - ny * math.sin(spread)
                        local lny = nx * math.sin(spread) + ny * math.cos(spread)
                        local startDist = hexSize * 0.25 + progress * hexSize * 0.5
                        local sx = cx - lnx * startDist
                        local sy = cy - lny * startDist
                        local tx = sx - lnx * lineLen * (1.0 - progress * 2)
                        local ty = sy - lny * lineLen * (1.0 - progress * 2)
                        nvgBeginPath(nvg)
                        nvgMoveTo(nvg, sx, sy)
                        nvgLineTo(nvg, tx, ty)
                        nvgStrokeColor(nvg, nvgRGBA(cr, cg, cb, lineAlpha))
                        nvgStrokeWidth(nvg, 2)
                        nvgStroke(nvg)
                    end
                end

                -- 中心闪光
                if progress < 0.2 then
                    local flashAlpha = math.floor((1.0 - progress / 0.2) * 180)
                    local flashR = hexSize * 0.35 * (1.0 - progress / 0.2)
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, cx, cy, flashR)
                    nvgFillColor(nvg, nvgRGBA(255, 255, 220, flashAlpha))
                    nvgFill(nvg)
                end
            end

        elseif fx.type == "spike_place" then
            -- 地刺放置: 3根尖刺从地面刺出 + 小碎石
            local cx, cy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)
            local alpha = math.floor(math.max(0, 1.0 - progress * 1.2) * 255)
            if alpha > 0 then
                local rise = math.min(progress * 2.5, 1.0)
                -- 底部裂地痕迹
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, hexSize * 0.35 * rise)
                nvgFillColor(nvg, nvgRGBA(180, 70, 30, math.floor(alpha * 0.25 * (1 - progress))))
                nvgFill(nvg)
                -- 3根向上尖刺破土而出
                local spikeH = hexSize * 0.55 * rise
                local spikeW = hexSize * 0.15
                local offsets = {-0.25, 0, 0.25}
                local heights2 = {0.75, 1.0, 0.75}
                for i = 1, 3 do
                    local bx = cx + offsets[i] * hexSize
                    local by = cy + hexSize * 0.12
                    local h = spikeH * heights2[i]
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, bx, by - h)
                    nvgLineTo(nvg, bx - spikeW, by)
                    nvgLineTo(nvg, bx + spikeW, by)
                    nvgClosePath(nvg)
                    nvgFillColor(nvg, nvgRGBA(210, 70, 35, alpha))
                    nvgFill(nvg)
                    nvgStrokeColor(nvg, nvgRGBA(255, 130, 60, alpha))
                    nvgStrokeWidth(nvg, 1.5)
                    nvgStroke(nvg)
                end
                -- 4颗小碎石飞溅
                for i = 1, 4 do
                    local a = i * math.pi / 2 + progress * 2
                    local dist2 = hexSize * (0.12 + progress * 0.35)
                    local pyo = -hexSize * 0.1 * (1 - progress)
                    local r = (hexSize * 0.035) * (1 - progress)
                    if r > 0 then
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, cx + math.cos(a) * dist2, cy + math.sin(a) * dist2 + pyo, r)
                        nvgFillColor(nvg, nvgRGBA(160, 90, 45, alpha))
                        nvgFill(nvg)
                    end
                end
            end

        elseif fx.type == "spike_hit" then
            -- 地刺命中: 红色闪光 + 碎石飞溅
            local cx, cy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)
            local alpha = math.floor(math.max(0, 1.0 - progress) * 255)
            if alpha > 0 then
                -- 中心红色闪光
                local flashR = hexSize * 0.3 * (1 - progress * 0.4)
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, flashR)
                nvgFillColor(nvg, nvgRGBA(255, 100, 40, math.floor(alpha * 0.6)))
                nvgFill(nvg)
                -- 6颗飞溅碎片
                for i = 1, 6 do
                    local a = i * math.pi / 3 + progress * 2
                    local dist = hexSize * (0.1 + progress * 0.45)
                    local py_off = -hexSize * 0.15 * (1 - progress)
                    local pr = (hexSize * 0.04) * (1 - progress)
                    if pr > 0 then
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, cx + math.cos(a) * dist, cy + math.sin(a) * dist + py_off, pr)
                        nvgFillColor(nvg, nvgRGBA(220, 80, 30, alpha))
                        nvgFill(nvg)
                    end
                end
            end

        elseif fx.type == "split_shard" then
            -- 分裂弹: 大型光束弹飞向目标（超醒目版 v3）
            if fx.fromCol and fx.toCol then
                local sx, sy = HexGrid.HexToPixel(fx.fromCol, fx.fromRow, hexSize, ox, oy)
                local tx, ty = HexGrid.HexToPixel(fx.toCol, fx.toRow, hexSize, ox, oy)
                local arcH = hexSize * 0.7
                local px = sx + (tx - sx) * progress
                local py = sy + (ty - sy) * progress - math.sin(progress * math.pi) * arcH
                local alpha = math.floor(math.min(255, 255 * (1.0 - progress * 0.5)))
                local headR = hexSize * 0.28 * (1 - progress * 0.15)

                -- ① 起点→弹头 连接光束（宽线条）
                if progress > 0.05 and progress < 0.9 then
                    local beamA = math.floor(alpha * 0.35 * (1 - progress))
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, sx, sy)
                    -- 中间插值几个点形成弧线
                    for seg = 1, 8 do
                        local sp = progress * seg / 8
                        local bx = sx + (tx - sx) * sp
                        local by = sy + (ty - sy) * sp - math.sin(sp * math.pi) * arcH
                        nvgLineTo(nvg, bx, by)
                    end
                    nvgStrokeColor(nvg, nvgRGBA(80, 220, 255, beamA))
                    nvgStrokeWidth(nvg, hexSize * 0.06)
                    nvgStroke(nvg)
                end

                -- ② 外层大光晕（柔和辉光）
                nvgBeginPath(nvg)
                nvgCircle(nvg, px, py, headR * 3.5)
                nvgFillColor(nvg, nvgRGBA(60, 180, 255, math.floor(alpha * 0.18)))
                nvgFill(nvg)

                -- ③ 中层光晕
                nvgBeginPath(nvg)
                nvgCircle(nvg, px, py, headR * 2.0)
                nvgFillColor(nvg, nvgRGBA(80, 220, 255, math.floor(alpha * 0.35)))
                nvgFill(nvg)

                -- ④ 弹头核心（亮白青色，大号）
                nvgBeginPath(nvg)
                nvgCircle(nvg, px, py, headR)
                nvgFillColor(nvg, nvgRGBA(180, 240, 255, alpha))
                nvgFill(nvg)
                nvgStrokeColor(nvg, nvgRGBA(255, 255, 255, alpha))
                nvgStrokeWidth(nvg, 2.5)
                nvgStroke(nvg)

                -- ⑤ 弹头中心亮点
                nvgBeginPath(nvg)
                nvgCircle(nvg, px, py, headR * 0.4)
                nvgFillColor(nvg, nvgRGBA(255, 255, 255, alpha))
                nvgFill(nvg)

                -- ⑥ 粗拖尾（10段，颜色渐变青→蓝）
                for t = 1, 10 do
                    local tp = math.max(0, progress - t * 0.028)
                    local tpx = sx + (tx - sx) * tp
                    local tpy = sy + (ty - sy) * tp - math.sin(tp * math.pi) * arcH
                    local tr = headR * (0.9 - t * 0.07)
                    local ta = math.floor(alpha * (0.7 - t * 0.06))
                    local tg = math.max(0, 220 - t * 15)
                    if tr > 0 and ta > 0 then
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, tpx, tpy, tr)
                        nvgFillColor(nvg, nvgRGBA(60, tg, 255, ta))
                        nvgFill(nvg)
                    end
                end

                -- ⑦ 到达时大爆炸冲击波
                if progress > 0.75 then
                    local ep = (progress - 0.75) / 0.25
                    -- 内圈亮闪
                    local flashR = hexSize * 0.6 * ep
                    local flashA = math.floor(255 * (1 - ep))
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, tx, ty, flashR)
                    nvgFillColor(nvg, nvgRGBA(150, 240, 255, flashA))
                    nvgFill(nvg)
                    -- 外圈扩散环
                    local ringR = hexSize * (0.3 + 0.7 * ep)
                    local ringA = math.floor(200 * (1 - ep))
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, tx, ty, ringR)
                    nvgStrokeColor(nvg, nvgRGBA(100, 220, 255, ringA))
                    nvgStrokeWidth(nvg, hexSize * 0.05 * (1 - ep * 0.5))
                    nvgStroke(nvg)
                end
            end

        elseif fx.type == "shield_gain" then
            -- 护盾获得: 蓝色光环上升
            local cx, cy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)
            local alpha = math.floor(math.max(0, 1.0 - progress * 1.5) * 200)
            if alpha > 0 then
                local shieldR = hexSize * (0.3 + progress * 0.3)
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy - hexSize * 0.2 * progress, shieldR)
                nvgStrokeColor(nvg, nvgRGBA(60, 160, 220, alpha))
                nvgStrokeWidth(nvg, 2.5 * (1 - progress))
                nvgStroke(nvg)
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy - hexSize * 0.2 * progress, shieldR * 0.5)
                nvgFillColor(nvg, nvgRGBA(80, 180, 240, math.floor(alpha * 0.3)))
                nvgFill(nvg)
            end

        elseif fx.type == "frost_puff" then
            -- 霜冻喷发: 白色冰晶扩散（与霜冻格白色调一致）
            local cx, cy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)
            local alpha = math.floor(math.max(0, 1.0 - progress) * 200)
            if alpha > 0 then
                for i = 1, 8 do
                    local angle = (i / 8) * math.pi * 2 + progress * 1.5
                    local dist = hexSize * (0.15 + progress * 0.7)
                    local px = cx + math.cos(angle) * dist
                    local py = cy + math.sin(angle) * dist
                    local pSize = (3.5 + math.sin(i * 1.3) * 1.5) * (1.0 - progress * 0.5)
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, px, py - pSize)
                    nvgLineTo(nvg, px + pSize * 0.6, py)
                    nvgLineTo(nvg, px, py + pSize)
                    nvgLineTo(nvg, px - pSize * 0.6, py)
                    nvgClosePath(nvg)
                    nvgFillColor(nvg, nvgRGBA(210, 235, 255, alpha))
                    nvgFill(nvg)
                end
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, hexSize * 0.35 * (1.0 - progress * 0.4))
                nvgFillColor(nvg, nvgRGBA(230, 245, 255, math.floor(alpha * 0.35)))
                nvgFill(nvg)
            end

        elseif fx.type == "meteor" then
            -- ══════════════════════════════════════════════════
            -- 天罚陨石: 红色危险区域 → 天幕裂缝 → 陨石坠落+火焰粒子 → 冲击爆炸
            -- ══════════════════════════════════════════════════
            local cx, cy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)
            local bw = l
            local vw = bw.w or 400
            local vh = bw.h or 700
            local fade = progress < 0.7 and 1.0 or math.max(0, 1.0 - (progress - 0.7) / 0.3)
            local alpha = math.floor(fade * 255)
            local meteorRange = fx.range or 3

            if alpha > 0 then
                -- ═══ 红色危险区域标记（全程显示，脉冲闪烁）═══
                -- 用红色虚线圈标出受陨石影响的范围
                local dangerR = hexSize * (meteorRange + 0.5) * 1.15
                local dangerPulse = 0.6 + 0.4 * math.abs(math.sin(progress * math.pi * 4))
                local dangerFade = progress < 0.8 and 1.0 or math.max(0, (1.0 - progress) / 0.2)
                local dangerA = math.floor(dangerPulse * dangerFade * 180)
                if dangerA > 0 then
                    -- 外圈红色线 (粗)
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, cx, cy, dangerR)
                    nvgStrokeColor(nvg, nvgRGBA(255, 40, 20, dangerA))
                    nvgStrokeWidth(nvg, 3.0)
                    nvgStroke(nvg)
                    -- 内圈红色线 (细)
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, cx, cy, dangerR * 0.85)
                    nvgStrokeColor(nvg, nvgRGBA(255, 60, 30, math.floor(dangerA * 0.5)))
                    nvgStrokeWidth(nvg, 1.5)
                    nvgStroke(nvg)
                    -- 半透明红色填充危险区域
                    local dangerFill = nvgRadialGradient(nvg, cx, cy, dangerR * 0.3, dangerR,
                        nvgRGBA(200, 20, 0, math.floor(dangerA * 0.08)),
                        nvgRGBA(255, 40, 10, math.floor(dangerA * 0.15)))
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, cx, cy, dangerR)
                    nvgFillPaint(nvg, dangerFill)
                    nvgFill(nvg)
                end

                -- ═══ 阶段0: 全屏红色预警闪烁（前15%）═══
                if progress < 0.15 then
                    local warnP = progress / 0.15
                    local pulse = math.abs(math.sin(warnP * math.pi * 3))
                    local warnA = math.floor(pulse * 100)
                    nvgBeginPath(nvg)
                    nvgRect(nvg, 0, 0, vw, vh)
                    nvgFillColor(nvg, nvgRGBA(180, 20, 0, warnA))
                    nvgFill(nvg)
                    -- 顶部黑暗压迫感（从上方压下来，更深更广）
                    local darkH = vh * 0.45 * warnP
                    local darkPaint = nvgLinearGradient(nvg, 0, 0, 0, darkH,
                        nvgRGBA(10, 0, 0, math.floor(200 * warnP)),
                        nvgRGBA(10, 0, 0, 0))
                    nvgBeginPath(nvg)
                    nvgRect(nvg, 0, 0, vw, darkH)
                    nvgFillPaint(nvg, darkPaint)
                    nvgFill(nvg)
                end

                -- ═══ 阶段1: 天幕裂缝（5%~40%）═══
                if progress > 0.05 and progress < 0.5 then
                    local crackP = math.min(1.0, (progress - 0.05) / 0.25)
                    local crackFade = progress < 0.35 and 1.0 or math.max(0, (0.5 - progress) / 0.15)
                    local crackA = math.floor(crackFade * 220)
                    local cracks = {
                        {x0 = vw * 0.2,  x1 = cx - hexSize * 0.8, wobble = 0.7},
                        {x0 = vw * 0.45, x1 = cx - hexSize * 0.2, wobble = 0.3},
                        {x0 = vw * 0.55, x1 = cx + hexSize * 0.2, wobble = 1.1},
                        {x0 = vw * 0.8,  x1 = cx + hexSize * 0.8, wobble = 0.9},
                    }
                    for _, cr in ipairs(cracks) do
                        local endY = cy - hexSize * 1.5
                        local curLen = crackP
                        -- 裂缝外辉光（更宽更红）
                        nvgBeginPath(nvg)
                        nvgMoveTo(nvg, cr.x0, 0)
                        local segments = 6
                        for s = 1, segments do
                            local t = s / segments * curLen
                            local lx = cr.x0 + (cr.x1 - cr.x0) * t + math.sin(t * 8 + cr.wobble * 5) * 10
                            local ly = t * endY
                            nvgLineTo(nvg, lx, ly)
                        end
                        nvgStrokeColor(nvg, nvgRGBA(255, 40, 10, math.floor(crackA * 0.35)))
                        nvgStrokeWidth(nvg, 16)
                        nvgStroke(nvg)
                        -- 裂缝核心（亮橙白色）
                        nvgBeginPath(nvg)
                        nvgMoveTo(nvg, cr.x0, 0)
                        for s = 1, segments do
                            local t = s / segments * curLen
                            local lx = cr.x0 + (cr.x1 - cr.x0) * t + math.sin(t * 8 + cr.wobble * 5) * 10
                            local ly = t * endY
                            nvgLineTo(nvg, lx, ly)
                        end
                        nvgStrokeColor(nvg, nvgRGBA(255, 200, 120, crackA))
                        nvgStrokeWidth(nvg, 3.5)
                        nvgStroke(nvg)
                    end
                end

                -- ═══ 阶段2: 陨石群坠落（10%~65%）— 10颗陨石，更大更密集 ═══
                local meteorCount = 10
                for i = 1, meteorCount do
                    local delay = 0.08 + (i - 1) * 0.05
                    local fallDur = 0.28
                    local angle = (i / meteorCount) * math.pi * 2 + 0.8
                    local targetDist = hexSize * (0.5 + (i % 4) * 0.65)
                    local mp = math.max(0, math.min(1.0, (progress - delay) / fallDur))
                    if mp > 0 and mp < 1.0 then
                        local easeMp = mp * mp * mp -- 立方加速，更强冲击感
                        local tx = cx + math.cos(angle) * targetDist
                        local ty = cy + math.sin(angle) * targetDist
                        local startY = ty - hexSize * 8
                        local startX = tx + (tx - cx) * 0.5
                        local curX = startX + (tx - startX) * easeMp
                        local curY = startY + (ty - startY) * easeMp
                        local mSize = hexSize * (0.28 + i * 0.035)

                        -- 长拖尾（三层火焰渐变）
                        local tailLen = mSize * (6 + (1.0 - mp) * 4)
                        local dx = curX - tx
                        local dy = curY - ty
                        local dist = math.sqrt(dx * dx + dy * dy)
                        if dist > 0.1 then
                            local ndx = dx / dist
                            local ndy = dy / dist
                            local perpX = -ndy
                            local perpY = ndx
                            local tailX = curX + ndx * tailLen
                            local tailY = curY + ndy * tailLen
                            local halfW = mSize * 0.6
                            -- 外焰（宽、暗红）
                            nvgBeginPath(nvg)
                            nvgMoveTo(nvg, curX + perpX * halfW * 2.2, curY + perpY * halfW * 2.2)
                            nvgLineTo(nvg, tailX, tailY)
                            nvgLineTo(nvg, curX - perpX * halfW * 2.2, curY - perpY * halfW * 2.2)
                            nvgClosePath(nvg)
                            nvgFillColor(nvg, nvgRGBA(200, 30, 0, math.floor(alpha * 0.12)))
                            nvgFill(nvg)
                            -- 中焰（橙色）
                            nvgBeginPath(nvg)
                            nvgMoveTo(nvg, curX + perpX * halfW * 1.2, curY + perpY * halfW * 1.2)
                            nvgLineTo(nvg, tailX, tailY)
                            nvgLineTo(nvg, curX - perpX * halfW * 1.2, curY - perpY * halfW * 1.2)
                            nvgClosePath(nvg)
                            nvgFillColor(nvg, nvgRGBA(255, 140, 20, math.floor(alpha * 0.35)))
                            nvgFill(nvg)
                            -- 内焰核心（亮黄白）
                            nvgBeginPath(nvg)
                            nvgMoveTo(nvg, curX + perpX * halfW * 0.3, curY + perpY * halfW * 0.3)
                            nvgLineTo(nvg, tailX, tailY)
                            nvgLineTo(nvg, curX - perpX * halfW * 0.3, curY - perpY * halfW * 0.3)
                            nvgClosePath(nvg)
                            nvgFillColor(nvg, nvgRGBA(255, 230, 140, math.floor(alpha * 0.65)))
                            nvgFill(nvg)
                        end

                        -- 火焰粒子（沿陨石轨迹飞散）
                        local sparkCount = 5
                        for sp = 1, sparkCount do
                            local spT = mp - sp * 0.04
                            if spT > 0 and spT < 1.0 then
                                local spEase = spT * spT
                                local spX = startX + (tx - startX) * spEase
                                local spY = startY + (ty - startY) * spEase
                                -- 随机偏移
                                local spSeed = i * 31 + sp * 7
                                local spOffX = math.sin(spSeed * 1.7) * hexSize * 0.3
                                local spOffY = math.cos(spSeed * 2.3) * hexSize * 0.2
                                spX = spX + spOffX * (1.0 - spT)
                                spY = spY + spOffY * (1.0 - spT)
                                local spSize = mSize * 0.15 * (1.0 - spT)
                                local spA = math.floor((1.0 - spT) * alpha * 0.7)
                                if spSize > 0.3 and spA > 0 then
                                    nvgBeginPath(nvg)
                                    nvgCircle(nvg, spX, spY, spSize * 2.5)
                                    nvgFillColor(nvg, nvgRGBA(255, 100, 20, math.floor(spA * 0.3)))
                                    nvgFill(nvg)
                                    nvgBeginPath(nvg)
                                    nvgCircle(nvg, spX, spY, spSize)
                                    nvgFillColor(nvg, nvgRGBA(255, 220, 100, spA))
                                    nvgFill(nvg)
                                end
                            end
                        end

                        -- 陨石球体（更大辉光）
                        local glowR = mSize * 3.0
                        local glowPaint = nvgRadialGradient(nvg, curX, curY, mSize * 0.3, glowR,
                            nvgRGBA(255, 120, 20, math.floor(alpha * 0.5)),
                            nvgRGBA(255, 40, 0, 0))
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, curX, curY, glowR)
                        nvgFillPaint(nvg, glowPaint)
                        nvgFill(nvg)
                        -- 岩石核心
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, curX, curY, mSize)
                        nvgFillColor(nvg, nvgRGBA(220, 80, 10, alpha))
                        nvgFill(nvg)
                        -- 白热中心
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, curX, curY, mSize * 0.45)
                        nvgFillColor(nvg, nvgRGBA(255, 240, 200, alpha))
                        nvgFill(nvg)
                    end

                    -- ═══ 着陆冲击波（陨石落地后）+ 逐颗追加震动 ═══
                    local impactStart = delay + fallDur
                    if progress > impactStart and progress < impactStart + 0.35 then
                        local ip = (progress - impactStart) / 0.35
                        local impactAlpha = math.floor((1.0 - ip) * 240)
                        local tx2 = cx + math.cos(angle) * targetDist
                        local ty2 = cy + math.sin(angle) * targetDist

                        -- 每颗陨石着陆追加震动（刚着陆的一帧追加）
                        if ip < 0.08 and G.battle then
                            G.battle.screenShake = math.max(G.battle.screenShake or 0, 0.25 + i * 0.05)
                        end

                        -- 扩散冲击环（双层）
                        local ringR1 = hexSize * (0.3 + ip * 2.5)
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, tx2, ty2, ringR1)
                        nvgStrokeColor(nvg, nvgRGBA(255, 180, 40, impactAlpha))
                        nvgStrokeWidth(nvg, 5.0 * (1.0 - ip))
                        nvgStroke(nvg)
                        -- 内环
                        local ringR2 = hexSize * (0.2 + ip * 1.6)
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, tx2, ty2, ringR2)
                        nvgStrokeColor(nvg, nvgRGBA(255, 240, 180, math.floor(impactAlpha * 0.7)))
                        nvgStrokeWidth(nvg, 2.5 * (1.0 - ip))
                        nvgStroke(nvg)

                        -- 着陆点火焰辉光（更大）
                        local fireR2 = hexSize * 1.2 * (1.0 - ip * 0.3)
                        local firePaint2 = nvgRadialGradient(nvg, tx2, ty2, 0, fireR2,
                            nvgRGBA(255, 200, 80, math.floor(impactAlpha * 0.7)),
                            nvgRGBA(255, 60, 0, 0))
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, tx2, ty2, fireR2)
                        nvgFillPaint(nvg, firePaint2)
                        nvgFill(nvg)

                        -- 着陆火花粒子（向外飞散，更多更大）
                        local sparkN = 8
                        for si = 1, sparkN do
                            local sAngle = (si / sparkN) * math.pi * 2 + angle
                            local sDist = hexSize * ip * 2.0
                            local sx = tx2 + math.cos(sAngle) * sDist
                            local sy = ty2 + math.sin(sAngle) * sDist - ip * hexSize * 0.8
                            local sSize = hexSize * 0.08 * (1.0 - ip)
                            local sA = math.floor(impactAlpha * 0.7)
                            if sSize > 0.3 and sA > 0 then
                                nvgBeginPath(nvg)
                                nvgCircle(nvg, sx, sy, sSize * 2.5)
                                nvgFillColor(nvg, nvgRGBA(255, 120, 20, math.floor(sA * 0.3)))
                                nvgFill(nvg)
                                nvgBeginPath(nvg)
                                nvgCircle(nvg, sx, sy, sSize)
                                nvgFillColor(nvg, nvgRGBA(255, 220, 80, sA))
                                nvgFill(nvg)
                            end
                        end

                        -- 着陆点灼痕（持续到消失）
                        if ip > 0.2 then
                            local scorchA = math.floor(80 * (1.0 - ip))
                            local scorchR = hexSize * 0.6
                            nvgBeginPath(nvg)
                            nvgCircle(nvg, tx2, ty2, scorchR)
                            nvgFillPaint(nvg, nvgRadialGradient(nvg,
                                tx2, ty2, 0, scorchR,
                                nvgRGBA(40, 10, 0, scorchA),
                                nvgRGBA(80, 20, 0, 0)))
                            nvgFill(nvg)
                        end
                    end
                end

                -- ═══ 阶段3: 主冲击 — 全屏强闪 + 中心扩散冲击波 + 屏幕下坠（40%~60%）═══
                if progress > 0.40 and progress < 0.60 then
                    local flashP = (progress - 0.40) / 0.20
                    -- 主冲击瞬间大震动
                    if flashP < 0.1 and G.battle then
                        G.battle.screenShake = math.max(G.battle.screenShake or 0, 1.0)
                    end
                    -- 全屏强白闪（先亮后暗）
                    local flashA = math.floor((1.0 - flashP) * 240)
                    nvgBeginPath(nvg)
                    nvgRect(nvg, 0, 0, vw, vh)
                    nvgFillColor(nvg, nvgRGBA(255, 240, 200, flashA))
                    nvgFill(nvg)
                    -- 过曝核心（中心更亮）
                    if flashP < 0.4 then
                        local coreA = math.floor((1.0 - flashP / 0.4) * 200)
                        local coreR = hexSize * (2.0 + flashP * 6.0)
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, cx, cy, coreR)
                        nvgFillPaint(nvg, nvgRadialGradient(nvg,
                            cx, cy, 0, coreR,
                            nvgRGBA(255, 255, 240, coreA),
                            nvgRGBA(255, 220, 160, 0)))
                        nvgFill(nvg)
                    end
                end

                -- ═══ 阶段3.5: 中心扩散冲击波环（42%~75%）═══
                if progress > 0.42 and progress < 0.75 then
                    local waveP = (progress - 0.42) / 0.33
                    -- 3层冲击波环，间隔扩散
                    for ring = 1, 3 do
                        local ringDelay = (ring - 1) * 0.12
                        local rp = math.max(0, waveP - ringDelay)
                        if rp > 0 and rp < 1.0 then
                            local waveR = hexSize * (1.0 + rp * 8.0)
                            local waveA = math.floor((1.0 - rp) * (200 - ring * 40))
                            local waveW = (5.0 - ring * 1.0) * (1.0 - rp * 0.7)
                            if waveA > 0 and waveW > 0.5 then
                                -- 外辉光
                                nvgBeginPath(nvg)
                                nvgCircle(nvg, cx, cy, waveR)
                                nvgStrokeColor(nvg, nvgRGBA(255, 140, 30, math.floor(waveA * 0.4)))
                                nvgStrokeWidth(nvg, waveW * 3)
                                nvgStroke(nvg)
                                -- 亮芯环
                                nvgBeginPath(nvg)
                                nvgCircle(nvg, cx, cy, waveR)
                                nvgStrokeColor(nvg, nvgRGBA(255, 220, 120, waveA))
                                nvgStrokeWidth(nvg, waveW)
                                nvgStroke(nvg)
                            end
                        end
                    end
                end

                -- ═══ 阶段4: 中心火柱 + 地面灼烧（30%~90%）═══
                if progress > 0.30 then
                    local fireP = (progress - 0.30) / 0.70
                    for layer = 1, 3 do
                        local layerDelay = (layer - 1) * 0.08
                        local lp = math.max(0, fireP - layerDelay)
                        if lp > 0 then
                            local maxR = hexSize * (1.2 + layer * 0.9)
                            local r = maxR * (0.5 + lp * 0.5) * (1.0 - lp * 0.3)
                            local a = math.floor((1.0 - lp) * (160 - layer * 30))
                            local colors = {
                                {255, 240, 180}, -- 内层：白热
                                {255, 130, 20},  -- 中层：烈焰橙
                                {180, 30, 0},    -- 外层：暗红
                            }
                            local c = colors[layer]
                            local fp = nvgRadialGradient(nvg, cx, cy, 0, r,
                                nvgRGBA(c[1], c[2], c[3], a),
                                nvgRGBA(c[1], c[2], c[3], 0))
                            nvgBeginPath(nvg)
                            nvgCircle(nvg, cx, cy, r)
                            nvgFillPaint(nvg, fp)
                            nvgFill(nvg)
                        end
                    end
                end

                -- ═══ 阶段5: 四边灼烧暗角（15%~85%，冲击时加重）═══
                if progress > 0.15 and progress < 0.85 then
                    local edgeBase = math.sin((progress - 0.15) / 0.70 * math.pi)
                    -- 主冲击时暗角加重
                    local impactBoost = 0
                    if progress > 0.40 and progress < 0.60 then
                        impactBoost = (1.0 - math.abs(progress - 0.50) / 0.10) * 0.6
                    end
                    local edgeP = math.min(1.0, edgeBase + impactBoost)
                    local edgeA = math.floor(edgeP * 180)
                    local edgeW = math.min(vw * 0.28, 110) * edgeP
                    local ep1 = nvgLinearGradient(nvg, 0, 0, 0, edgeW,
                        nvgRGBA(255, 40, 0, edgeA), nvgRGBA(255, 40, 0, 0))
                    nvgBeginPath(nvg)
                    nvgRect(nvg, 0, 0, vw, edgeW)
                    nvgFillPaint(nvg, ep1)
                    nvgFill(nvg)
                    local ep2 = nvgLinearGradient(nvg, 0, vh, 0, vh - edgeW,
                        nvgRGBA(255, 40, 0, edgeA), nvgRGBA(255, 40, 0, 0))
                    nvgBeginPath(nvg)
                    nvgRect(nvg, 0, vh - edgeW, vw, edgeW)
                    nvgFillPaint(nvg, ep2)
                    nvgFill(nvg)
                    local ep3 = nvgLinearGradient(nvg, 0, 0, edgeW, 0,
                        nvgRGBA(255, 40, 0, edgeA), nvgRGBA(255, 40, 0, 0))
                    nvgBeginPath(nvg)
                    nvgRect(nvg, 0, 0, edgeW, vh)
                    nvgFillPaint(nvg, ep3)
                    nvgFill(nvg)
                    local ep4 = nvgLinearGradient(nvg, vw, 0, vw - edgeW, 0,
                        nvgRGBA(255, 40, 0, edgeA), nvgRGBA(255, 40, 0, 0))
                    nvgBeginPath(nvg)
                    nvgRect(nvg, vw - edgeW, 0, edgeW, vh)
                    nvgFillPaint(nvg, ep4)
                    nvgFill(nvg)
                end

                -- ═══ 阶段6: 火焰粒子飞散（35%~100%）— 数量加倍 ═══
                if progress > 0.35 then
                    local emberP = (progress - 0.35) / 0.65
                    local emberCount = 24
                    for i = 1, emberCount do
                        local seed = i * 137.508
                        local angle2 = seed % (math.pi * 2)
                        local speed = 0.4 + (i % 5) * 0.25
                        local dist2 = hexSize * speed * emberP * 4.0
                        local ex = cx + math.cos(angle2) * dist2
                        local ey = cy + math.sin(angle2) * dist2 - emberP * hexSize * (1.5 + i % 3)
                        local eSize = hexSize * 0.1 * (1.0 - emberP * 0.6)
                        local eAlpha = math.floor((1.0 - emberP) * 220)
                        if eAlpha > 0 and eSize > 0.5 then
                            -- 火焰辉光（更大更亮）
                            nvgBeginPath(nvg)
                            nvgCircle(nvg, ex, ey, eSize * 3.5)
                            nvgFillColor(nvg, nvgRGBA(255, 80, 10, math.floor(eAlpha * 0.15)))
                            nvgFill(nvg)
                            -- 火焰核心
                            nvgBeginPath(nvg)
                            nvgCircle(nvg, ex, ey, eSize)
                            -- 交替红/橙/黄
                            if i % 3 == 0 then
                                nvgFillColor(nvg, nvgRGBA(255, 200, 60, eAlpha))
                            elseif i % 3 == 1 then
                                nvgFillColor(nvg, nvgRGBA(255, 120, 20, eAlpha))
                            else
                                nvgFillColor(nvg, nvgRGBA(255, 60, 10, eAlpha))
                            end
                            nvgFill(nvg)
                        end
                    end
                end
            end

        elseif fx.type == "time_freeze" then
            -- 时间冻结: 蓝色脉冲波 + 冰晶扩散
            local cx, cy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)
            local alpha = math.floor(math.max(0, 1.0 - progress) * 200)
            if alpha > 0 then
                -- 扩散冻结环
                local maxR = hexSize * 5.0
                local ringR = maxR * math.min(1.0, progress * 1.5)
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, ringR)
                nvgStrokeColor(nvg, nvgRGBA(100, 200, 255, alpha))
                nvgStrokeWidth(nvg, 4.0 * (1.0 - progress))
                nvgStroke(nvg)
                -- 内环
                local innerR = ringR * 0.6
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, innerR)
                nvgStrokeColor(nvg, nvgRGBA(180, 230, 255, math.floor(alpha * 0.7)))
                nvgStrokeWidth(nvg, 2.5 * (1.0 - progress))
                nvgStroke(nvg)
                -- 中心闪光
                if progress < 0.3 then
                    local flashA = math.floor((1.0 - progress / 0.3) * 180)
                    local flashR = hexSize * 0.8 * (1.0 - progress / 0.3)
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, cx, cy, flashR)
                    nvgFillColor(nvg, nvgRGBA(200, 240, 255, flashA))
                    nvgFill(nvg)
                end
                -- 冰晶粒子
                for i = 1, 10 do
                    local angle = (i / 10) * math.pi * 2 + progress * 2.0
                    local dist = ringR * 0.5 + math.sin(i * 1.7) * hexSize * 0.5
                    local px = cx + math.cos(angle) * dist
                    local py = cy + math.sin(angle) * dist
                    local pSize = 4 * (1.0 - progress * 0.5)
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, px, py - pSize)
                    nvgLineTo(nvg, px + pSize * 0.6, py)
                    nvgLineTo(nvg, px, py + pSize)
                    nvgLineTo(nvg, px - pSize * 0.6, py)
                    nvgClosePath(nvg)
                    nvgFillColor(nvg, nvgRGBA(150, 220, 255, math.floor(alpha * 0.8)))
                    nvgFill(nvg)
                end
            end

        elseif fx.type == "convergence" then
            -- 万象归一: 多层光环收缩汇聚 + 星芒爆发
            local cx, cy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)
            local alpha = math.floor(math.max(0, 1.0 - progress * 0.7) * 255)
            if alpha > 0 then
                if progress < 0.5 then
                    -- 前半段: 光环从远处收缩到中心
                    local shrinkP = progress / 0.5
                    for ring = 1, 3 do
                        local ringR = hexSize * (4.0 - shrinkP * 3.5) * (1.0 + ring * 0.2)
                        local ringAlpha = math.floor(alpha * (0.5 + shrinkP * 0.5))
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, cx, cy, ringR)
                        local r = ring == 1 and 180 or (ring == 2 and 140 or 100)
                        local g = ring == 1 and 100 or (ring == 2 and 80 or 200)
                        local b = 255
                        nvgStrokeColor(nvg, nvgRGBA(r, g, b, ringAlpha))
                        nvgStrokeWidth(nvg, (4 - ring) * (1.0 - shrinkP * 0.5))
                        nvgStroke(nvg)
                    end
                    -- 汇聚粒子向中心飞
                    for i = 1, 12 do
                        local angle = (i / 12) * math.pi * 2
                        local dist = hexSize * 4.0 * (1.0 - shrinkP)
                        local px = cx + math.cos(angle) * dist
                        local py = cy + math.sin(angle) * dist
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, px, py, 3.0 * (1.0 - shrinkP * 0.5))
                        nvgFillColor(nvg, nvgRGBA(200, 150, 255, alpha))
                        nvgFill(nvg)
                    end
                else
                    -- 后半段: 中心爆发星芒
                    local burstP = (progress - 0.5) / 0.5
                    -- 中心高光
                    local coreR = hexSize * (0.5 + burstP * 2.0)
                    local coreAlpha = math.floor((1.0 - burstP) * 200)
                    local corePaint = nvgRadialGradient(nvg, cx, cy, 0, coreR,
                        nvgRGBA(255, 255, 255, coreAlpha), nvgRGBA(180, 120, 255, 0))
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, cx, cy, coreR)
                    nvgFillPaint(nvg, corePaint)
                    nvgFill(nvg)
                    -- 星芒射线
                    for i = 1, 8 do
                        local angle = (i / 8) * math.pi * 2 + burstP * 0.5
                        local rayLen = hexSize * (1.0 + burstP * 3.0)
                        nvgBeginPath(nvg)
                        nvgMoveTo(nvg, cx, cy)
                        nvgLineTo(nvg, cx + math.cos(angle) * rayLen, cy + math.sin(angle) * rayLen)
                        nvgStrokeColor(nvg, nvgRGBA(200, 150, 255, math.floor(coreAlpha * 0.6)))
                        nvgStrokeWidth(nvg, 2.5 * (1.0 - burstP))
                        nvgStroke(nvg)
                    end
                end
            end

        elseif fx.type == "dart_fly" then
            -- 飞镖投射: 从英雄缓慢飞向目标的旋转飞镖
            local x1, y1 = HexGrid.HexToPixel(fx.fromCol, fx.fromRow, hexSize, ox, oy)
            local x2, y2 = HexGrid.HexToPixel(fx.toCol, fx.toRow, hexSize, ox, oy)
            -- 前80%时间飞行，后20%时间淡出
            local t = math.min(1.0, progress / 0.8)
            -- 使用 ease-out 曲线让飞镖起步快、落点慢
            local easeT = 1.0 - (1.0 - t) * (1.0 - t)
            local fade = (progress < 0.85) and 1.0 or math.max(0, (1.0 - progress) / 0.15)
            local alpha = math.floor(fade * 255)
            if alpha > 0 then
                local px = x1 + (x2 - x1) * easeT
                local py = y1 + (y2 - y1) * easeT - math.sin(easeT * math.pi) * hexSize * 0.8
                -- 旋转飞镖图标（大而醒目）
                IconAtlas.DrawNVGRotated(nvg, "board_dagger", px, py, hexSize * 1.0, (G.time or 0) * 8.0, alpha / 255)
                -- 飞镖周围光晕
                nvgBeginPath(nvg)
                nvgCircle(nvg, px, py, hexSize * 0.45)
                nvgFillColor(nvg, nvgRGBA(255, 220, 80, math.floor(alpha * 0.3)))
                nvgFill(nvg)
                -- 拖尾光迹（更长的尾巴）
                for trail = 1, 6 do
                    local tt = math.max(0, easeT - trail * 0.035)
                    local tx = x1 + (x2 - x1) * tt
                    local ty = y1 + (y2 - y1) * tt - math.sin(tt * math.pi) * hexSize * 0.8
                    local ta = math.floor(alpha * (1.0 - trail * 0.15))
                    if ta > 0 then
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, tx, ty, hexSize * (0.1 - trail * 0.012))
                        nvgFillColor(nvg, nvgRGBA(255, 220, 80, ta))
                        nvgFill(nvg)
                    end
                end
            end

        elseif fx.type == "jump_impact" then
            -- 连跳过程中每跳落地冲击波（随combo递进，3连起触发）
            local ix, iy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)
            local fade = math.max(0, 1.0 - progress)
            local combo = fx.combo or 3
            -- 颜色随combo递进：3-4白金，5-6亮金，7+橙红
            local cr, cg, cb
            if combo >= 7 then
                cr, cg, cb = 255, 100, 50
            elseif combo >= 5 then
                cr, cg, cb = 255, 200, 60
            else
                cr, cg, cb = 255, 240, 180
            end
            local impAlpha = math.floor(fade * 220)
            if impAlpha > 0 then
                -- 中心闪光
                if progress < 0.3 then
                    local fp = progress / 0.3
                    local fr = hexSize * (0.6 + math.min(combo, 8) * 0.12) * fp
                    local fa = math.floor((1.0 - fp) * 200)
                    local flashPaint = nvgRadialGradient(nvg, ix, iy, 0, fr,
                        nvgRGBA(255, 255, 255, fa),
                        nvgRGBA(cr, cg, cb, 0))
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, ix, iy, fr)
                    nvgFillPaint(nvg, flashPaint)
                    nvgFill(nvg)
                end
                -- 扩散光环（1~2层，combo越高越多越大）
                local ringCount = combo >= 6 and 3 or (combo >= 4 and 2 or 1)
                for ring = 1, ringCount do
                    local delay = (ring - 1) * 0.08
                    local rp = math.max(0, progress - delay) / math.max(0.01, 1.0 - delay)
                    rp = math.min(1.0, rp)
                    local maxR = hexSize * (1.0 + math.min(combo, 8) * 0.2 + ring * 0.3)
                    local ringR = maxR * rp
                    local ringA = math.floor(impAlpha * (1.0 - rp) * 0.7)
                    if ringA > 2 then
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, ix, iy, ringR)
                        nvgStrokeColor(nvg, nvgRGBA(cr, cg, cb, ringA))
                        nvgStrokeWidth(nvg, (2.5 + combo * 0.3 - ring * 0.3) * (1.0 - rp))
                        nvgStroke(nvg)
                    end
                end
                -- 飞散小粒子（combo越高越多）
                local pCount = math.min(3 + combo * 2, 20)
                for i = 1, pCount do
                    local angle = (i / pCount) * math.pi * 2 + progress * 3.0
                    local dist = hexSize * (0.2 + progress * (1.0 + combo * 0.15))
                    local px = ix + math.cos(angle) * dist
                    local py = iy + math.sin(angle) * dist
                    local pFade = math.max(0, 1.0 - progress * 1.3)
                    local pSize = (2.0 + combo * 0.3) * pFade
                    if pSize > 0.3 then
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, px, py, pSize)
                        nvgFillColor(nvg, nvgRGBA(cr, cg, cb, math.floor(200 * pFade)))
                        nvgFill(nvg)
                    end
                end
            end

        elseif fx.type == "combo_burst" then
            -- 连击奖励爆发: 多层光环 + 粒子飞散 + 中心闪光 + 高连击屏幕闪
            local cx, cy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)
            local fade = math.max(0, 1.0 - progress)
            local alpha = math.floor(fade * 255)
            local c = fx.colors or { glow = {255, 200, 60}, flash = {255, 220, 80} }
            local tier = fx.threshold or 2
            local bw = l
            local vw = bw.w or 400
            local vh = bw.h or 700
            -- 6连击有专属陨石VFX，跳过通用combo_burst
            if tier == 6 then alpha = 0 end
            if alpha > 0 then
                -- ═══ 7连击专属：全屏白闪（前10%，极致冲击感） ═══
                if tier >= 7 and progress < 0.1 then
                    local whiteP = progress / 0.1
                    local whiteA = math.floor((1.0 - whiteP) * 200)
                    nvgBeginPath(nvg)
                    nvgRect(nvg, 0, 0, vw, vh)
                    nvgFillColor(nvg, nvgRGBA(255, 255, 255, whiteA))
                    nvgFill(nvg)
                end

                -- ═══ 6-7连击：全屏色调覆盖（氛围渲染） ═══
                if tier >= 6 and progress < 0.4 then
                    local tintP = math.sin(progress / 0.4 * math.pi)
                    local tintA = math.floor(tintP * (tier >= 7 and 40 or 25))
                    nvgBeginPath(nvg)
                    nvgRect(nvg, 0, 0, vw, vh)
                    nvgFillColor(nvg, nvgRGBA(c.glow[1], c.glow[2], c.glow[3], tintA))
                    nvgFill(nvg)
                end

                -- ═══ 高连击（>=5）: 全屏边缘光晕 ═══
                if tier >= 5 and progress < 0.6 then
                    local edgeP = math.sin(progress / 0.6 * math.pi)
                    -- 5连=80, 6连=120, 7连=160
                    local edgeMaxA = tier >= 7 and 160 or (tier >= 6 and 120 or 80)
                    local edgeA = math.floor(edgeP * edgeMaxA)
                    -- 边缘宽度：5连=60, 6连=90, 7连=120
                    local edgeMaxW = tier >= 7 and 120 or (tier >= 6 and 90 or 60)
                    local edgeW = math.min(vw * 0.25, edgeMaxW) * edgeP
                    -- 四边辉光条
                    local ep1 = nvgLinearGradient(nvg, 0, 0, 0, edgeW,
                        nvgRGBA(c.glow[1], c.glow[2], c.glow[3], edgeA),
                        nvgRGBA(c.glow[1], c.glow[2], c.glow[3], 0))
                    nvgBeginPath(nvg)
                    nvgRect(nvg, 0, 0, vw, edgeW)
                    nvgFillPaint(nvg, ep1)
                    nvgFill(nvg)
                    local ep2 = nvgLinearGradient(nvg, 0, vh, 0, vh - edgeW,
                        nvgRGBA(c.glow[1], c.glow[2], c.glow[3], edgeA),
                        nvgRGBA(c.glow[1], c.glow[2], c.glow[3], 0))
                    nvgBeginPath(nvg)
                    nvgRect(nvg, 0, vh - edgeW, vw, edgeW)
                    nvgFillPaint(nvg, ep2)
                    nvgFill(nvg)
                    local ep3 = nvgLinearGradient(nvg, 0, 0, edgeW, 0,
                        nvgRGBA(c.glow[1], c.glow[2], c.glow[3], edgeA),
                        nvgRGBA(c.glow[1], c.glow[2], c.glow[3], 0))
                    nvgBeginPath(nvg)
                    nvgRect(nvg, 0, 0, edgeW, vh)
                    nvgFillPaint(nvg, ep3)
                    nvgFill(nvg)
                    local ep4 = nvgLinearGradient(nvg, vw, 0, vw - edgeW, 0,
                        nvgRGBA(c.glow[1], c.glow[2], c.glow[3], edgeA),
                        nvgRGBA(c.glow[1], c.glow[2], c.glow[3], 0))
                    nvgBeginPath(nvg)
                    nvgRect(nvg, vw - edgeW, 0, edgeW, vh)
                    nvgFillPaint(nvg, ep4)
                    nvgFill(nvg)
                end

                -- ═══ 6-7连击：柔和放射光束（渐变光柱效果） ═══
                if tier >= 6 and progress < 0.7 then
                    local rayP = math.sin(progress / 0.7 * math.pi)
                    local rayCount = tier >= 7 and 12 or 8
                    local rayLen = math.min(vw, vh) * (tier >= 7 and 0.85 or 0.65)
                    local rayMaxA = tier >= 7 and 70 or 45
                    local rotSpeed = tier >= 7 and 0.6 or 0.4
                    -- 光束宽度随距离递减，用多层矩形模拟柔化光束
                    for i = 1, rayCount do
                        local baseAngle = (i / rayCount) * math.pi * 2
                        local angle = baseAngle + progress * rotSpeed
                        -- 每条光束用3层叠加模拟柔边（宽→窄，透明→不透明）
                        for layer = 3, 1, -1 do
                            local layerWidthMul = layer * 0.6  -- 外层更宽
                            local layerAlpha = math.floor(rayP * rayMaxA / layer)  -- 外层更透明
                            if layerAlpha < 2 then goto continueLayer end
                            local segCount = 6  -- 沿光束长度分段，制造渐变消散效果
                            for s = 0, segCount - 1 do
                                local t0 = s / segCount
                                local t1 = (s + 1) / segCount
                                local r0 = rayLen * 0.05 + rayLen * t0  -- 从中心稍偏移开始
                                local r1 = rayLen * 0.05 + rayLen * t1
                                -- 沿长度递减的alpha
                                local segAlpha = math.floor(layerAlpha * (1.0 - t0 * 0.85))
                                if segAlpha < 2 then goto continueSeg end
                                -- 光束宽度：近端宽，远端窄
                                local w0 = (8 + tier) * layerWidthMul * (1.0 - t0 * 0.6)
                                local w1 = (8 + tier) * layerWidthMul * (1.0 - t1 * 0.6)
                                -- 四个顶点构成梯形
                                local cos_a = math.cos(angle)
                                local sin_a = math.sin(angle)
                                local perpX = -sin_a
                                local perpY = cos_a
                                local x0 = cx + cos_a * r0
                                local y0 = cy + sin_a * r0
                                local x1 = cx + cos_a * r1
                                local y1 = cy + sin_a * r1
                                nvgBeginPath(nvg)
                                nvgMoveTo(nvg, x0 + perpX * w0, y0 + perpY * w0)
                                nvgLineTo(nvg, x1 + perpX * w1, y1 + perpY * w1)
                                nvgLineTo(nvg, x1 - perpX * w1, y1 - perpY * w1)
                                nvgLineTo(nvg, x0 - perpX * w0, y0 - perpY * w0)
                                nvgClosePath(nvg)
                                nvgFillColor(nvg, nvgRGBA(c.glow[1], c.glow[2], c.glow[3], segAlpha))
                                nvgFill(nvg)
                                ::continueSeg::
                            end
                            ::continueLayer::
                        end
                    end
                end

                -- ═══ 中心大闪光（高tier更大更亮更久） ═══
                local flashEnd = tier >= 6 and 0.45 or (tier >= 5 and 0.38 or 0.3)
                if progress < flashEnd then
                    local flashP = progress / flashEnd
                    -- 闪光半径：5连=3.5x, 6连=5x, 7连=7x hexSize
                    local flashMul = tier >= 7 and 7.0 or (tier >= 6 and 5.0 or (tier >= 5 and 3.5 or (1.5 + tier * 0.4)))
                    local flashR = hexSize * flashMul * flashP
                    local flashA = math.floor((1.0 - flashP) * 255)
                    local fp = nvgRadialGradient(nvg, cx, cy, 0, flashR,
                        nvgRGBA(255, 255, 255, flashA),
                        nvgRGBA(c.flash[1], c.flash[2], c.flash[3], 0))
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, cx, cy, flashR)
                    nvgFillPaint(nvg, fp)
                    nvgFill(nvg)
                    -- 5+连击：第二层彩色闪光
                    if tier >= 5 then
                        local flashR2 = flashR * 0.6
                        local flashA2 = math.floor((1.0 - flashP) * 180)
                        local fp2 = nvgRadialGradient(nvg, cx, cy, 0, flashR2,
                            nvgRGBA(c.flash[1], c.flash[2], c.flash[3], flashA2),
                            nvgRGBA(255, 255, 255, 0))
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, cx, cy, flashR2)
                        nvgFillPaint(nvg, fp2)
                        nvgFill(nvg)
                    end
                end

                -- ═══ 扩散光环（柔化宽光带 + 渐变描边） ═══
                local ringCount = tier >= 7 and 4 or (tier >= 6 and 3 or (tier >= 5 and 3 or math.min(tier, 3)))
                for ring = 1, ringCount do
                    local delay = (ring - 1) * (tier >= 6 and 0.08 or 0.10)
                    local ringP = math.max(0, progress - delay) / math.max(0.01, 1.0 - delay)
                    ringP = math.min(1.0, ringP)
                    local maxRMul = tier >= 7 and 8.0 or (tier >= 6 and 6.0 or (tier >= 5 and 4.5 or (2.0 + tier * 0.5)))
                    local maxR = hexSize * (maxRMul + ring * 1.2)
                    local ringR = maxR * ringP
                    local ringFade = (1.0 - ringP)
                    local ringA = math.floor(alpha * ringFade * 0.6)
                    if ringA > 0 and ringR > 1 then
                        -- 用径向渐变环代替纯色描边，产生柔和光晕
                        local bandW = tier >= 7 and 18 or (tier >= 6 and 14 or (tier >= 5 and 10 or 6))
                        bandW = bandW * ringFade
                        local innerR = math.max(0, ringR - bandW)
                        local outerR = ringR + bandW
                        -- 外发光：环外侧渐变消散
                        local rp = nvgRadialGradient(nvg, cx, cy, innerR, outerR,
                            nvgRGBA(c.glow[1], c.glow[2], c.glow[3], ringA),
                            nvgRGBA(c.glow[1], c.glow[2], c.glow[3], 0))
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, cx, cy, outerR)
                        nvgFillPaint(nvg, rp)
                        nvgFill(nvg)
                        -- 细描边线强调环的边缘
                        if innerR > 2 then
                            nvgBeginPath(nvg)
                            nvgCircle(nvg, cx, cy, ringR)
                            nvgStrokeColor(nvg, nvgRGBA(255, 255, 255, math.floor(ringA * 0.4)))
                            nvgStrokeWidth(nvg, 1.5 * ringFade)
                            nvgStroke(nvg)
                        end
                    end
                end

                -- ═══ 飞散粒子（带拖尾光点） ═══
                local particleCount = tier >= 7 and 20 or (tier >= 6 and 16 or (tier >= 5 and 12 or (4 + tier * 2)))
                for i = 1, particleCount do
                    local angle = (i / particleCount) * math.pi * 2 + progress * (1.0 + tier * 0.2)
                    local speed = 0.6 + (i % 3) * 0.2
                    local distMul = tier >= 7 and 8.0 or (tier >= 6 and 6.0 or (tier >= 5 and 4.5 or (2.0 + tier * 0.4)))
                    local dist = hexSize * (0.3 + progress * distMul) * speed
                    local px = cx + math.cos(angle) * dist
                    local py = cy + math.sin(angle) * dist
                    local pFade = math.max(0, 1.0 - progress * 1.1)
                    local pBaseSize = tier >= 7 and 5 or (tier >= 6 and 4 or (tier >= 5 and 3.5 or 2.5))
                    local pSize = pBaseSize * pFade
                    if pSize > 0.5 then
                        -- 外发光晕（大而透明）
                        local glowSize = pSize * 3
                        local glowAlpha = math.floor(60 * pFade)
                        local pp = nvgRadialGradient(nvg, px, py, 0, glowSize,
                            nvgRGBA(c.glow[1], c.glow[2], c.glow[3], glowAlpha),
                            nvgRGBA(c.glow[1], c.glow[2], c.glow[3], 0))
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, px, py, glowSize)
                        nvgFillPaint(nvg, pp)
                        nvgFill(nvg)
                        -- 内核亮点（小而亮）
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, px, py, pSize)
                        if i % 3 == 0 then
                            nvgFillColor(nvg, nvgRGBA(255, 255, 255, math.floor(220 * pFade)))
                        else
                            nvgFillColor(nvg, nvgRGBA(c.flash[1], c.flash[2], c.flash[3], math.floor(200 * pFade)))
                        end
                        nvgFill(nvg)
                    end
                end

                -- ═══ 5+连击：外圈旋转星芒 ═══
                if tier >= 5 then
                    local starCount = tier >= 7 and 8 or (tier >= 6 and 6 or 4)
                    local starDist = hexSize * (tier >= 7 and 3.5 or (tier >= 6 and 2.8 or 2.2))
                    local starRot = progress * (tier >= 7 and 4.0 or 2.5)
                    local starFade = math.max(0, 1.0 - progress * 1.3)
                    for i = 1, starCount do
                        local angle = (i / starCount) * math.pi * 2 + starRot
                        local sx = cx + math.cos(angle) * starDist * (0.5 + progress * 0.8)
                        local sy = cy + math.sin(angle) * starDist * (0.5 + progress * 0.8)
                        local sSize = (tier >= 7 and 5 or (tier >= 6 and 4 or 3)) * starFade
                        if sSize > 0.3 then
                            -- 四角星形：用两个旋转的菱形
                            nvgSave(nvg)
                            nvgTranslate(nvg, sx, sy)
                            nvgRotate(nvg, angle + progress * 6)
                            -- 纵向菱形
                            nvgBeginPath(nvg)
                            nvgMoveTo(nvg, 0, -sSize * 2)
                            nvgLineTo(nvg, sSize * 0.5, 0)
                            nvgLineTo(nvg, 0, sSize * 2)
                            nvgLineTo(nvg, -sSize * 0.5, 0)
                            nvgClosePath(nvg)
                            nvgFillColor(nvg, nvgRGBA(255, 255, 255, math.floor(200 * starFade)))
                            nvgFill(nvg)
                            -- 横向菱形
                            nvgBeginPath(nvg)
                            nvgMoveTo(nvg, -sSize * 2, 0)
                            nvgLineTo(nvg, 0, sSize * 0.5)
                            nvgLineTo(nvg, sSize * 2, 0)
                            nvgLineTo(nvg, 0, -sSize * 0.5)
                            nvgClosePath(nvg)
                            nvgFillColor(nvg, nvgRGBA(255, 255, 255, math.floor(160 * starFade)))
                            nvgFill(nvg)
                            nvgRestore(nvg)
                        end
                    end
                end

                -- ═══ 中心持续光晕（高连击更大更亮） ═══
                local glowMul = tier >= 7 and 1.5 or (tier >= 6 and 1.2 or (tier >= 5 and 0.9 or 0.6))
                local glowR = hexSize * (glowMul + math.sin(progress * 10) * 0.2) * fade
                local glowA = tier >= 6 and 140 or (tier >= 5 and 110 or 80)
                local glowPaint = nvgRadialGradient(nvg, cx, cy, 0, glowR,
                    nvgRGBA(c.glow[1], c.glow[2], c.glow[3], math.floor(glowA * fade)),
                    nvgRGBA(c.glow[1], c.glow[2], c.glow[3], 0))
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, glowR)
                nvgFillPaint(nvg, glowPaint)
                nvgFill(nvg)

                -- ═══ 7连击专属：脉冲冲击波 ═══
                if tier >= 7 and progress > 0.1 and progress < 0.6 then
                    local pulseP = (progress - 0.1) / 0.5
                    local pulseR = math.min(vw, vh) * 0.5 * pulseP
                    local pulseA = math.floor((1.0 - pulseP) * 100)
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, cx, cy, pulseR)
                    nvgStrokeColor(nvg, nvgRGBA(255, 255, 255, pulseA))
                    nvgStrokeWidth(nvg, 3.0 * (1.0 - pulseP))
                    nvgStroke(nvg)
                    -- 第二波（延迟）
                    if progress > 0.2 then
                        local pulse2P = (progress - 0.2) / 0.4
                        pulse2P = math.min(1.0, pulse2P)
                        local pulse2R = math.min(vw, vh) * 0.45 * pulse2P
                        local pulse2A = math.floor((1.0 - pulse2P) * 70)
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, cx, cy, pulse2R)
                        nvgStrokeColor(nvg, nvgRGBA(c.glow[1], c.glow[2], c.glow[3], pulse2A))
                        nvgStrokeWidth(nvg, 2.0 * (1.0 - pulse2P))
                        nvgStroke(nvg)
                    end
                end
            end

        elseif fx.type == "death_puff" then
            -- 死亡爆散: 配色匹配敌人类型，多层粒子 + 中心闪光 + 灵魂碎片上升
            local cx, cy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)
            local fade = math.max(0, 1.0 - progress)
            local alpha = math.floor(fade * 220)
            local ec = fx.enemyColor or {180, 60, 60}
            local isBoss = fx.isBoss or false
            if alpha > 0 then
                -- 中心白色闪光（前20%）
                if progress < 0.2 then
                    local flashP = progress / 0.2
                    local flashR = hexSize * (isBoss and 1.8 or 1.2) * flashP
                    local flashA = math.floor((1.0 - flashP) * 255)
                    local fp = nvgRadialGradient(nvg, cx, cy, 0, flashR,
                        nvgRGBA(255, 255, 255, flashA),
                        nvgRGBA(ec[1], ec[2], ec[3], 0))
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, cx, cy, flashR)
                    nvgFillPaint(nvg, fp)
                    nvgFill(nvg)
                end
                -- 扩散粒子环（配色）
                local particleCount = isBoss and 16 or 10
                for i = 1, particleCount do
                    local angle = (i / particleCount) * math.pi * 2 + progress * 2.5 + i * 0.7
                    local speed = 0.5 + (i % 3) * 0.25
                    local dist = hexSize * (0.15 + progress * 1.4) * speed
                    local px = cx + math.cos(angle) * dist
                    local py = cy + math.sin(angle) * dist - progress * hexSize * 0.3
                    local pFade = math.max(0, 1.0 - progress * 1.2)
                    local pSize = (isBoss and 5 or 3.5) * pFade * (1.0 + math.sin(i * 1.3) * 0.3)
                    if pSize > 0.3 then
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, px, py, pSize)
                        nvgFillColor(nvg, nvgRGBA(ec[1], ec[2], ec[3], math.floor(200 * pFade)))
                        nvgFill(nvg)
                    end
                end
                -- 上升灵魂碎片（白色+配色混合，向上飘散）
                for i = 1, (isBoss and 6 or 3) do
                    local angle = (i / 3) * math.pi * 2 + i * 1.1
                    local sway = math.sin(progress * 6 + i * 2) * hexSize * 0.15
                    local sx = cx + math.cos(angle) * hexSize * 0.2 + sway
                    local sy = cy - progress * hexSize * (0.8 + i * 0.3)
                    local sAlpha = math.floor(math.max(0, 1.0 - progress * 1.5) * 180)
                    local sSize = (isBoss and 3 or 2) * (1.0 - progress * 0.7)
                    if sAlpha > 0 and sSize > 0.3 then
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, sx, sy, sSize)
                        nvgFillColor(nvg, nvgRGBA(
                            math.min(255, ec[1] + 80),
                            math.min(255, ec[2] + 80),
                            math.min(255, ec[3] + 80), sAlpha))
                        nvgFill(nvg)
                    end
                end
                -- 扩散环
                local ringR = hexSize * (0.3 + progress * 1.5)
                local ringA = math.floor(fade * 120 * (1.0 - progress))
                if ringA > 2 then
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, cx, cy, ringR)
                    nvgStrokeColor(nvg, nvgRGBA(ec[1], ec[2], ec[3], ringA))
                    nvgStrokeWidth(nvg, (isBoss and 3 or 2) * (1.0 - progress))
                    nvgStroke(nvg)
                end
            end

        elseif fx.type == "boss_enrage" then
            -- Boss狂暴爆发: 暗红能量爆炸 + 多层冲击波 + 黑暗粒子旋涡
            local cx, cy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)
            local fade = math.max(0, 1.0 - progress)
            local alpha = math.floor(fade * 255)
            local bc = fx.bossColor or {255, 50, 50}
            if alpha > 0 then
                -- 暗色背景闪烁（前40%全屏暗化效果）
                if progress < 0.4 then
                    local darkP = math.sin(progress / 0.4 * math.pi)
                    local darkA = math.floor(darkP * 60)
                    nvgBeginPath(nvg)
                    nvgRect(nvg, cx - hexSize * 6, cy - hexSize * 6, hexSize * 12, hexSize * 12)
                    nvgFillColor(nvg, nvgRGBA(0, 0, 0, darkA))
                    nvgFill(nvg)
                end
                -- 中心能量爆发（深红渐变）
                if progress < 0.35 then
                    local burstP = progress / 0.35
                    local burstR = hexSize * 2.5 * burstP
                    local burstA = math.floor((1.0 - burstP) * 200)
                    local bp = nvgRadialGradient(nvg, cx, cy, 0, burstR,
                        nvgRGBA(bc[1], bc[2], bc[3], burstA),
                        nvgRGBA(bc[1] * 0.3, bc[2] * 0.3, bc[3] * 0.3, 0))
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, cx, cy, burstR)
                    nvgFillPaint(nvg, bp)
                    nvgFill(nvg)
                end
                -- 三层扩散冲击波
                for ring = 1, 3 do
                    local delay = (ring - 1) * 0.12
                    local ringP = math.max(0, progress - delay) / math.max(0.01, 1.0 - delay)
                    ringP = math.min(1.0, ringP)
                    local maxR = hexSize * (1.5 + ring * 1.0)
                    local ringR = maxR * ringP
                    local ringA = math.floor(alpha * (1.0 - ringP) * 0.7)
                    if ringA > 2 then
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, cx, cy, ringR)
                        nvgStrokeColor(nvg, nvgRGBA(bc[1], bc[2], bc[3], ringA))
                        nvgStrokeWidth(nvg, (5 - ring) * (1.0 - ringP * 0.7))
                        nvgStroke(nvg)
                    end
                end
                -- 旋转暗影粒子漩涡
                local vortexCount = 12
                for i = 1, vortexCount do
                    local baseAngle = (i / vortexCount) * math.pi * 2
                    local spin = progress * 8 + i * 0.5
                    local dist = hexSize * (0.4 + progress * 1.8) * (0.6 + (i % 3) * 0.2)
                    local px = cx + math.cos(baseAngle + spin) * dist
                    local py = cy + math.sin(baseAngle + spin) * dist
                    local pFade = math.max(0, 1.0 - progress * 1.1)
                    local pSize = 4 * pFade * (1.0 + math.sin(i * 1.7) * 0.4)
                    if pSize > 0.5 then
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, px, py, pSize)
                        -- 交替红/暗色粒子
                        if i % 2 == 0 then
                            nvgFillColor(nvg, nvgRGBA(bc[1], bc[2], bc[3], math.floor(180 * pFade)))
                        else
                            nvgFillColor(nvg, nvgRGBA(40, 0, 20, math.floor(200 * pFade)))
                        end
                        nvgFill(nvg)
                    end
                end
                -- 中心持续脉冲光晕
                local pulseR = hexSize * (0.5 + math.sin(progress * 12) * 0.2) * fade
                local pp = nvgRadialGradient(nvg, cx, cy, 0, pulseR,
                    nvgRGBA(bc[1], bc[2], bc[3], math.floor(100 * fade)),
                    nvgRGBA(bc[1], bc[2], bc[3], 0))
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, pulseR)
                nvgFillPaint(nvg, pp)
                nvgFill(nvg)
            end

        elseif fx.type == "altar_burn" then
            -- 祭坛灰飞烟灭特效（大范围 + 持续时间长）
            local cx, cy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)
            local fade = math.max(0, 1.0 - progress)

            -- 阶段1 (0~0.2): 白光闪烁爆发
            if progress < 0.2 then
                local flashP = progress / 0.2
                local flashR = hexSize * (0.5 + flashP * 1.0)
                local flashA = math.floor(255 * (1.0 - flashP * flashP))
                local flashGlow = nvgRadialGradient(nvg, cx, cy, 0, flashR,
                    nvgRGBA(255, 255, 220, flashA),
                    nvgRGBA(255, 200, 50, 0))
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, flashR)
                nvgFillPaint(nvg, flashGlow)
                nvgFill(nvg)
            end

            -- 阶段2 (0~0.5): 火焰爆发光晕（大范围）
            if progress < 0.6 then
                local burstP = math.min(1.0, progress / 0.3)
                local burstR = hexSize * (0.4 + burstP * 1.2)
                local burstAlpha = math.floor(240 * (1.0 - burstP * 0.7))
                local glow = nvgRadialGradient(nvg, cx, cy, 0, burstR,
                    nvgRGBA(255, 200, 50, burstAlpha),
                    nvgRGBA(255, 60, 10, 0))
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, burstR)
                nvgFillPaint(nvg, glow)
                nvgFill(nvg)
            end

            -- 冲击波扩散环
            if progress < 0.4 then
                local waveP = progress / 0.4
                local waveR = hexSize * (0.3 + waveP * 2.0)
                local waveA = math.floor(180 * (1.0 - waveP))
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, waveR)
                nvgStrokeColor(nvg, nvgRGBA(255, 180, 40, waveA))
                nvgStrokeWidth(nvg, 4 * (1.0 - waveP * 0.7))
                nvgStroke(nvg)
            end

            -- 火焰碎片向外飞散 + 旋转（更多粒子、更大范围）
            local numParticles = 18
            for i = 1, numParticles do
                local baseAngle = (i / numParticles) * math.pi * 2
                local spin = progress * 3.0 + i * 0.4
                local angle = baseAngle + spin
                local speed = 0.6 + math.sin(i * 1.7) * 0.4
                local dist = hexSize * (0.15 + progress * 1.8) * speed
                local px = cx + math.cos(angle) * dist
                local py = cy + math.sin(angle) * dist - progress * hexSize * 0.5
                -- 碎片大小：先大后小
                local pSize = hexSize * (0.1 + 0.08 * math.sin(i * 2.1)) * fade
                if pSize > 0.5 then
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, px, py, pSize)
                    local r = math.floor(255 - progress * 80)
                    local g = math.floor(200 * fade * (1.0 - progress * 0.4))
                    local b = math.floor(30 * fade)
                    local a = math.floor(220 * fade)
                    nvgFillColor(nvg, nvgRGBA(r, g, b, a))
                    nvgFill(nvg)
                end
            end

            -- 灰烬碎屑（深色碎片四散 + 缓慢下落）
            if progress > 0.15 then
                local ashP = (progress - 0.15) / 0.85
                local numAsh = 14
                for i = 1, numAsh do
                    local aAngle = (i / numAsh) * math.pi * 2 + i * 1.1
                    local aDist = hexSize * (0.2 + ashP * 1.4) * (0.5 + math.sin(i * 3.1) * 0.5)
                    local ax = cx + math.cos(aAngle) * aDist + math.sin(ashP * 3 + i) * hexSize * 0.1
                    local ay = cy + math.sin(aAngle) * aDist * 0.7 + ashP * hexSize * 0.3 * math.sin(i * 0.7)
                    local aSize = (2.5 + math.sin(i * 1.5) * 1.5) * math.max(0, 1.0 - ashP * 0.8)
                    local aAlpha = math.floor(140 * math.max(0, 1.0 - ashP * 1.1))
                    if aAlpha > 0 and aSize > 0.3 then
                        nvgSave(nvg)
                        nvgTranslate(nvg, ax, ay)
                        nvgRotate(nvg, ashP * 4 + i * 0.8)
                        nvgBeginPath(nvg)
                        nvgRect(nvg, -aSize * 0.5, -aSize * 0.3, aSize, aSize * 0.6)
                        nvgFillColor(nvg, nvgRGBA(60, 30, 15, aAlpha))
                        nvgFill(nvg)
                        nvgRestore(nvg)
                    end
                end
            end

            -- 上升的余烬火星（更多 + 飘散更高）
            if progress > 0.1 then
                local emberP = (progress - 0.1) / 0.9
                for i = 1, 14 do
                    local ex = cx + math.sin(i * 2.3 + progress * 5) * hexSize * (0.4 + emberP * 0.6)
                    local ey = cy - emberP * hexSize * (1.0 + i * 0.18) - math.sin(i * 2.7) * hexSize * 0.25
                    local eSize = (2.0 + math.sin(i * 1.9) * 1.0) * math.max(0, 1.0 - emberP * 0.9)
                    if eSize > 0.3 then
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, ex, ey, eSize)
                        local ea = math.floor(200 * math.max(0, 1.0 - emberP * 1.2))
                        nvgFillColor(nvg, nvgRGBA(255, 180 - i * 10, 20, ea))
                        nvgFill(nvg)
                    end
                end
            end

            -- 烟雾消散（多层灰色烟雾向上扩散）
            if progress > 0.25 then
                local smokeP = (progress - 0.25) / 0.75
                -- 主烟雾环
                local smokeR = hexSize * (0.6 + smokeP * 1.2)
                local smokeA = math.floor(80 * math.max(0, 1.0 - smokeP))
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy - smokeP * hexSize * 0.3, smokeR)
                nvgStrokeColor(nvg, nvgRGBA(80, 40, 20, smokeA))
                nvgStrokeWidth(nvg, 4 * (1.0 - smokeP * 0.5))
                nvgStroke(nvg)
                -- 上飘烟雾团
                for i = 1, 3 do
                    local sR = hexSize * (0.3 + i * 0.15) * (1.0 - smokeP * 0.5)
                    local sY = cy - smokeP * hexSize * (0.5 + i * 0.4)
                    local sX = cx + math.sin(i * 2.0 + smokeP * 2) * hexSize * 0.2
                    local sA = math.floor(40 * math.max(0, 1.0 - smokeP * 1.2))
                    if sA > 0 then
                        local sg = nvgRadialGradient(nvg, sX, sY, 0, sR,
                            nvgRGBA(60, 30, 15, sA),
                            nvgRGBA(40, 20, 10, 0))
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, sX, sY, sR)
                        nvgFillPaint(nvg, sg)
                        nvgFill(nvg)
                    end
                end
            end

        elseif fx.type == "shield_break" then
            -- 护盾碎裂特效：金色碎片爆裂 + 冲击波
            local cx, cy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)
            local fade = math.max(0, 1.0 - progress)

            -- 冲击波扩散环（快速扩散的金色圆环）
            if progress < 0.5 then
                local waveP = progress / 0.5
                local waveR = hexSize * (0.3 + waveP * 1.2)
                local waveA = math.floor(200 * (1.0 - waveP))
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, waveR)
                nvgStrokeColor(nvg, nvgRGBA(255, 200, 60, waveA))
                nvgStrokeWidth(nvg, 4 * (1.0 - waveP))
                nvgStroke(nvg)
            end

            -- 中心闪光爆发
            if progress < 0.3 then
                local flashP = progress / 0.3
                local flashR = hexSize * (0.2 + flashP * 0.5)
                local flashGlow = nvgRadialGradient(nvg, cx, cy, 0, flashR,
                    nvgRGBA(255, 255, 200, math.floor(255 * (1.0 - flashP))),
                    nvgRGBA(255, 180, 40, 0))
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, flashR)
                nvgFillPaint(nvg, flashGlow)
                nvgFill(nvg)
            end

            -- 金色碎片向外飞散
            local numShards = 10
            for i = 1, numShards do
                local angle = (i / numShards) * math.pi * 2 + i * 0.6
                local speed = 0.6 + math.sin(i * 2.7) * 0.4
                local dist = hexSize * progress * 1.5 * speed
                local px = cx + math.cos(angle) * dist
                local py = cy + math.sin(angle) * dist - progress * hexSize * 0.4
                -- 碎片：从大变小的菱形/方块
                local sSize = hexSize * (0.1 + 0.05 * math.sin(i * 1.3)) * fade
                if sSize > 0.5 then
                    nvgSave(nvg)
                    nvgTranslate(nvg, px, py)
                    nvgRotate(nvg, progress * 6 + i)
                    nvgBeginPath(nvg)
                    nvgRect(nvg, -sSize, -sSize, sSize * 2, sSize * 2)
                    local r = math.floor(255 - progress * 60)
                    local g = math.floor(200 * fade)
                    local b = math.floor(40 * fade)
                    nvgFillColor(nvg, nvgRGBA(r, g, b, math.floor(220 * fade)))
                    nvgFill(nvg)
                    nvgRestore(nvg)
                end
            end

            -- 残余火星上飘
            if progress > 0.3 then
                local sparkP = (progress - 0.3) / 0.7
                for i = 1, 6 do
                    local sx = cx + math.sin(i * 2.1 + progress * 5) * hexSize * 0.4
                    local sy = cy - sparkP * hexSize * (0.5 + i * 0.12)
                    local sA = math.floor(160 * math.max(0, 1.0 - sparkP * 1.3))
                    if sA > 0 then
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, sx, sy, 2.0 * (1.0 - sparkP))
                        nvgFillColor(nvg, nvgRGBA(255, 200, 60, sA))
                        nvgFill(nvg)
                    end
                end
            end

        elseif fx.type == "spawn_puff" then
            -- 外围刷怪烟雾
            local cx, cy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)
            local alpha = math.floor(math.max(0, 1.0 - progress) * 160)
            if alpha > 0 then
                for i = 1, 6 do
                    local angle = (i / 6) * math.pi * 2 + progress * 3
                    local dist = hexSize * (0.1 + progress * 0.6)
                    local px = cx + math.cos(angle) * dist
                    local py = cy + math.sin(angle) * dist
                    local pSize = (4 + math.sin(i * 2.3) * 2) * (1.0 - progress * 0.7)
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, px, py, pSize)
                    nvgFillColor(nvg, nvgRGBA(180, 60, 60, alpha))
                    nvgFill(nvg)
                end
            end

        elseif fx.type == "teleport_out" then
            -- 幽灵鲨瞬移消失：向内收缩的蓝色漩涡
            local cx, cy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)
            local alpha = math.floor(math.max(0, 1.0 - progress) * 200)
            if alpha > 0 then
                -- 收缩漩涡环
                for i = 1, 8 do
                    local angle = (i / 8) * math.pi * 2 + progress * 10
                    local dist = hexSize * 0.5 * (1.0 - progress)
                    local px = cx + math.cos(angle) * dist
                    local py = cy + math.sin(angle) * dist
                    local pSize = 3 * (1.0 - progress)
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, px, py, pSize)
                    nvgFillColor(nvg, nvgRGBA(100, 180, 255, alpha))
                    nvgFill(nvg)
                end
                -- 中心光点
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, hexSize * 0.15 * (1.0 - progress * 0.5))
                nvgFillColor(nvg, nvgRGBA(180, 220, 255, alpha))
                nvgFill(nvg)
            end

        elseif fx.type == "teleport_in" then
            -- 幽灵鲨瞬移出现：向外扩散的蓝色波纹
            local cx, cy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)
            local alpha = math.floor(math.max(0, 1.0 - progress) * 220)
            if alpha > 0 then
                -- 扩散波纹
                for ring = 1, 2 do
                    local rProgress = math.min(1.0, progress * 2.0 - (ring - 1) * 0.3)
                    if rProgress > 0 then
                        local rSize = hexSize * 0.2 + hexSize * 0.5 * rProgress
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, cx, cy, rSize)
                        nvgStrokeColor(nvg, nvgRGBA(100, 180, 255, math.floor(alpha * (1.0 - rProgress))))
                        nvgStrokeWidth(nvg, 2.5 - rProgress * 1.5)
                        nvgStroke(nvg)
                    end
                end
                -- 闪光粒子
                for i = 1, 6 do
                    local angle = (i / 6) * math.pi * 2 - progress * 5
                    local dist = hexSize * 0.1 + hexSize * 0.4 * progress
                    local px = cx + math.cos(angle) * dist
                    local py = cy + math.sin(angle) * dist
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, px, py, 2.5 * (1.0 - progress * 0.6))
                    nvgFillColor(nvg, nvgRGBA(150, 210, 255, alpha))
                    nvgFill(nvg)
                end
            end

        elseif fx.type == "split_spawn" then
            -- 裂焰精分裂：火焰爆裂扩散
            local cx, cy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)
            local alpha = math.floor(math.max(0, 1.0 - progress) * 200)
            if alpha > 0 then
                -- 火焰粒子向外扩散
                for i = 1, 10 do
                    local angle = (i / 10) * math.pi * 2 + i * 0.7
                    local dist = hexSize * 0.1 + hexSize * 0.6 * progress
                    local px = cx + math.cos(angle) * dist
                    local py = cy + math.sin(angle) * dist
                    local pSize = (2 + math.sin(i * 3.1) * 1.5) * (1.0 - progress * 0.5)
                    -- 火焰色渐变：黄→橙→红
                    local r = 255
                    local g = math.floor(200 - progress * 150)
                    local b = math.floor(50 * (1.0 - progress))
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, px, py, pSize)
                    nvgFillColor(nvg, nvgRGBA(r, g, b, alpha))
                    nvgFill(nvg)
                end
                -- 中心爆裂光
                if progress < 0.4 then
                    local coreAlpha = math.floor((1.0 - progress / 0.4) * 180)
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, cx, cy, hexSize * 0.3 * (1.0 + progress))
                    nvgFillColor(nvg, nvgRGBA(255, 240, 150, coreAlpha))
                    nvgFill(nvg)
                end
            end

        elseif fx.type == "heal_pickup" then
            -- 血瓶拾取：扩散绿色光环 + 上升绿色粒子 + 十字闪光
            local cx, cy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)
            local alpha = math.floor(math.max(0, 1.0 - progress * 0.8) * 255)
            if alpha > 0 then
                -- 扩散光环（两层）
                for ring = 1, 2 do
                    local ringProgress = math.min(1.0, progress * 1.5 + (ring - 1) * 0.15)
                    local ringR = hexSize * (0.3 + 0.7 * ringProgress)
                    local ringA = math.floor(alpha * (1.0 - ringProgress) * 0.7)
                    if ringA > 0 then
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, cx, cy, ringR)
                        nvgStrokeColor(nvg, nvgRGBA(80, 255, 120, ringA))
                        nvgStrokeWidth(nvg, 3.0 * (1.0 - ringProgress * 0.5))
                        nvgStroke(nvg)
                    end
                end
                -- 中心绿色闪光
                local flashA = math.floor(alpha * math.max(0, 1.0 - progress * 2.5))
                if flashA > 0 then
                    local flashPaint = nvgRadialGradient(nvg, cx, cy, 0, hexSize * 0.5,
                        nvgRGBA(120, 255, 160, flashA), nvgRGBA(80, 255, 120, 0))
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, cx, cy, hexSize * 0.5)
                    nvgFillPaint(nvg, flashPaint)
                    nvgFill(nvg)
                end
                -- 上升粒子
                for i = 1, 8 do
                    local angle = (i / 8) * math.pi * 2 + progress * 2
                    local dist = hexSize * 0.2 + hexSize * 0.4 * progress
                    local px = cx + math.cos(angle) * dist
                    local py = cy - hexSize * 0.8 * progress + math.sin(angle * 2) * 4
                    local pA = math.floor(alpha * (1.0 - progress * 0.7))
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, px, py, 2.5 * (1.0 - progress * 0.5))
                    nvgFillColor(nvg, nvgRGBA(100, 255, 150, pA))
                    nvgFill(nvg)
                end
                -- 十字闪光
                local crossLen = hexSize * 0.4 * (1.0 - progress * 0.3)
                local crossA = math.floor(alpha * 0.6)
                nvgStrokeColor(nvg, nvgRGBA(180, 255, 200, crossA))
                nvgStrokeWidth(nvg, 2.0)
                nvgBeginPath(nvg)
                nvgMoveTo(nvg, cx - crossLen, cy)
                nvgLineTo(nvg, cx + crossLen, cy)
                nvgStroke(nvg)
                nvgBeginPath(nvg)
                nvgMoveTo(nvg, cx, cy - crossLen)
                nvgLineTo(nvg, cx, cy + crossLen)
                nvgStroke(nvg)
            end

        elseif fx.type == "support_heal" then
            -- 珊瑚祭司治疗：上升的绿色光环+十字
            local cx, cy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)
            local alpha = math.floor(math.max(0, 1.0 - progress) * 220)
            if alpha > 0 then
                -- 上升光粒
                for i = 1, 6 do
                    local angle = (i / 6) * math.pi * 2
                    local dist = hexSize * 0.25
                    local px = cx + math.cos(angle) * dist
                    local py = cy - hexSize * 0.5 * progress + math.sin(angle + progress * 3) * 3
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, px, py, 2)
                    nvgFillColor(nvg, nvgRGBA(100, 255, 150, alpha))
                    nvgFill(nvg)
                end
                -- 底部光环
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, hexSize * 0.35 + hexSize * 0.15 * progress)
                nvgStrokeColor(nvg, nvgRGBA(100, 255, 150, math.floor(alpha * 0.6)))
                nvgStrokeWidth(nvg, 2.0)
                nvgStroke(nvg)
            end

        elseif fx.type == "support_buff" then
            -- 珊瑚祭司BUFF：金色闪光+上箭头
            local cx, cy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)
            local alpha = math.floor(math.max(0, 1.0 - progress) * 200)
            if alpha > 0 then
                -- 金色光环扩散
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, hexSize * 0.3 + hexSize * 0.3 * progress)
                nvgStrokeColor(nvg, nvgRGBA(255, 200, 80, alpha))
                nvgStrokeWidth(nvg, 2.5 * (1.0 - progress * 0.5))
                nvgStroke(nvg)
                -- 上升箭头
                nvgFontSize(nvg, hexSize * 0.4 * (1.0 + progress * 0.3))
                nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(nvg, nvgRGBA(255, 220, 80, alpha))
                nvgText(nvg, cx, cy - hexSize * 0.3 * progress, "⬆")
            end

        elseif fx.type == "vortex_shuffle" then
            -- 漩涡鳗打乱：中心旋转漩涡 + 扩散波纹
            local cx, cy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)
            local alpha = math.floor(math.max(0, 1.0 - progress) * 220)
            if alpha > 0 then
                -- 旋转漩涡粒子环
                local spinSpeed = 12 + progress * 8
                for ring = 1, 2 do
                    local rScale = 0.3 + ring * 0.35
                    local numDots = 6 + ring * 2
                    local ringAlpha = math.floor(alpha * (1.0 - (ring - 1) * 0.35))
                    for i = 1, numDots do
                        local angle = (i / numDots) * math.pi * 2 + progress * spinSpeed * (ring % 2 == 0 and -1 or 1)
                        local dist = hexSize * rScale * (0.6 + progress * 0.6)
                        local px = cx + math.cos(angle) * dist
                        local py = cy + math.sin(angle) * dist
                        local dotSize = (3.5 - ring * 0.5) * (1.0 - progress * 0.4)
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, px, py, dotSize)
                        nvgFillColor(nvg, nvgRGBA(80, 160, 255, ringAlpha))
                        nvgFill(nvg)
                    end
                end
                -- 中心发光漩涡
                local glowR = hexSize * 0.4 * (0.5 + progress * 0.8)
                local glowPaint = nvgRadialGradient(nvg, cx, cy, glowR * 0.2, glowR,
                    nvgRGBA(120, 200, 255, math.floor(alpha * 0.6)),
                    nvgRGBA(60, 120, 255, 0))
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, glowR)
                nvgFillPaint(nvg, glowPaint)
                nvgFill(nvg)
                -- 扩散波纹
                for w = 1, 3 do
                    local wProg = math.min(1.0, progress * 3.0 - (w - 1) * 0.5)
                    if wProg > 0 and wProg < 1.0 then
                        local wR = hexSize * (0.3 + 1.2 * wProg)
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, cx, cy, wR)
                        nvgStrokeColor(nvg, nvgRGBA(100, 180, 255, math.floor(alpha * (1.0 - wProg) * 0.5)))
                        nvgStrokeWidth(nvg, 2.0 * (1.0 - wProg))
                        nvgStroke(nvg)
                    end
                end
            end

        elseif fx.type == "shuffle_trail" then
            -- 漩涡鳗打乱轨迹：从旧位置到新位置的弧形光带
            local x1, y1 = HexGrid.HexToPixel(fx.fromCol, fx.fromRow, hexSize, ox, oy)
            local x2, y2 = HexGrid.HexToPixel(fx.toCol, fx.toRow, hexSize, ox, oy)
            local alpha = math.floor(math.max(0, 1.0 - progress) * 200)
            if alpha > 0 then
                -- 弧形控制点（垂直于连线方向偏移制造弧度）
                local dx = x2 - x1
                local dy = y2 - y1
                local dist = math.sqrt(dx * dx + dy * dy)
                -- 控制点垂直于连线方向偏移
                local perpX = -dy / math.max(dist, 1) * hexSize * 0.5
                local perpY = dx / math.max(dist, 1) * hexSize * 0.5
                local cpX = (x1 + x2) * 0.5 + perpX
                local cpY = (y1 + y2) * 0.5 + perpY

                -- 绘制移动光点沿弧线运动
                local tMove = math.min(1.0, progress * 1.5)

                -- 光点拖尾（多个渐隐点）
                for tail = 4, 0, -1 do
                    local tt = math.max(0, tMove - tail * 0.06)
                    local omt = 1.0 - tt
                    local tx = omt * omt * x1 + 2 * omt * tt * cpX + tt * tt * x2
                    local ty = omt * omt * y1 + 2 * omt * tt * cpY + tt * tt * y2
                    local tAlpha = math.floor(alpha * (1.0 - tail * 0.2))
                    local tSize = (4.0 - tail * 0.6)
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, tx, ty, tSize)
                    nvgFillColor(nvg, nvgRGBA(100, 200, 255, tAlpha))
                    nvgFill(nvg)
                end

                -- 起点消失光圈
                if progress < 0.4 then
                    local startAlpha = math.floor(alpha * (1.0 - progress / 0.4))
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, x1, y1, hexSize * 0.25 * (1.0 + progress))
                    nvgStrokeColor(nvg, nvgRGBA(80, 160, 255, startAlpha))
                    nvgStrokeWidth(nvg, 2.0)
                    nvgStroke(nvg)
                end

                -- 终点出现光圈
                if progress > 0.5 then
                    local endProg = (progress - 0.5) / 0.5
                    local endAlpha = math.floor(alpha * endProg)
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, x2, y2, hexSize * 0.3 * endProg)
                    nvgStrokeColor(nvg, nvgRGBA(120, 220, 255, endAlpha))
                    nvgStrokeWidth(nvg, 2.5 * (1.0 - endProg * 0.5))
                    nvgStroke(nvg)
                end
            end

        elseif fx.type == "life_drain" then
            -- ═══ 生命虹吸：绿光从四周向主角汇聚，吸收生命的感觉 ═══
            local cx, cy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)
            local fade = progress < 0.8 and 1.0 or math.max(0, 1.0 - (progress - 0.8) / 0.2)
            local alpha = math.floor(fade * 255)
            if alpha > 0 then

                -- ── 1) 汇聚光点（20颗，从远处飞向中心） ──
                local particleCount = 20
                for i = 1, particleCount do
                    local seed = i * 137.508
                    -- 每颗粒子有不同的出发时间和速度
                    local startDelay = ((i - 1) / particleCount) * 0.5
                    local pT = math.max(0, progress - startDelay) / math.max(0.01, 0.8 - startDelay)
                    pT = math.min(1.0, pT)
                    if pT > 0 and pT < 1 then
                        -- 从远处飞向中心（距离从大到小）
                        local startDist = hexSize * (2.5 + (i % 5) * 0.6)
                        local easeIn = pT * pT  -- 越靠近中心越快（加速汇聚）
                        local curDist = startDist * (1.0 - easeIn)
                        local pAngle = seed  -- 固定角度，不旋转
                        local px = cx + math.cos(pAngle) * curDist
                        local py = cy + math.sin(pAngle) * curDist
                        -- 靠近中心时变亮变小
                        local pBright = 0.3 + easeIn * 0.7
                        local pA = math.floor(alpha * 0.55 * pBright)
                        local pSize = hexSize * (0.10 + (i % 3) * 0.03) * (1.0 - easeIn * 0.5)
                        if pA > 2 then
                            nvgBeginPath(nvg)
                            nvgCircle(nvg, px, py, pSize)
                            nvgFillPaint(nvg, nvgRadialGradient(nvg,
                                px, py, 0, pSize,
                                nvgRGBA(140, 255, 180, pA),
                                nvgRGBA(60, 220, 120, 0)))
                            nvgFill(nvg)
                        end
                    end
                end

                -- ── 2) 汇聚拖尾线（8条弧线从外向中心弯曲收束） ──
                local trailCount = 8
                for i = 1, trailCount do
                    local tAngle = (i / trailCount) * math.pi * 2 + 0.5
                    local tDelay = (i % 3) * 0.1
                    local tT = math.max(0, progress - tDelay) / math.max(0.01, 0.85 - tDelay)
                    tT = math.min(1.0, tT)
                    if tT > 0.05 and tT < 0.95 then
                        local startDist = hexSize * 3.0
                        -- 尾部位置（还在远处）
                        local tailT = math.max(0, tT - 0.3)
                        local tailDist = startDist * (1.0 - tailT * tailT)
                        -- 头部位置（更靠近中心）
                        local headDist = startDist * (1.0 - tT * tT)
                        local tA = math.floor(alpha * 0.2 * math.sin(tT * math.pi))
                        if tA > 2 then
                            local hx = cx + math.cos(tAngle) * headDist
                            local hy = cy + math.sin(tAngle) * headDist
                            local tx = cx + math.cos(tAngle) * tailDist
                            local ty = cy + math.sin(tAngle) * tailDist
                            local trailW = hexSize * 0.06
                            nvgBeginPath(nvg)
                            nvgMoveTo(nvg, hx, hy)
                            nvgLineTo(nvg, tx, ty)
                            nvgStrokeWidth(nvg, trailW)
                            nvgStrokeColor(nvg, nvgRGBA(120, 240, 170, tA))
                            nvgStroke(nvg)
                            -- 头部亮点
                            nvgBeginPath(nvg)
                            nvgCircle(nvg, hx, hy, hexSize * 0.06)
                            nvgFillPaint(nvg, nvgRadialGradient(nvg,
                                hx, hy, 0, hexSize * 0.06,
                                nvgRGBA(180, 255, 210, math.floor(tA * 2.5)),
                                nvgRGBA(100, 230, 150, 0)))
                            nvgFill(nvg)
                        end
                    end
                end

                -- ── 3) 中心吸收脉冲（到达时闪一下，呼吸感） ──
                local pulseT = math.max(0, progress - 0.2)  -- 粒子开始到达后才有
                if pulseT > 0 then
                    local pulsePhase = pulseT * 6.0  -- 多次脉冲
                    local pulseBright = math.abs(math.sin(pulsePhase * math.pi)) * 0.5
                    local pulseR = hexSize * (0.25 + pulseBright * 0.15)
                    local pulseA = math.floor(alpha * (0.3 + pulseBright * 0.4))
                    -- 柔光晕
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, cx, cy, pulseR * 3.0)
                    nvgFillPaint(nvg, nvgRadialGradient(nvg,
                        cx, cy, pulseR * 0.3, pulseR * 3.0,
                        nvgRGBA(80, 240, 150, math.floor(pulseA * 0.15)),
                        nvgRGBA(40, 200, 100, 0)))
                    nvgFill(nvg)
                    -- 亮核
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, cx, cy, pulseR)
                    nvgFillPaint(nvg, nvgRadialGradient(nvg,
                        cx, cy, 0, pulseR,
                        nvgRGBA(210, 255, 230, pulseA),
                        nvgRGBA(100, 240, 160, 0)))
                    nvgFill(nvg)
                end
            end

        elseif fx.type == "doomsday_explosion" then
            -- ═══ 末日炸弹：蓄力 → 短白闪 → 粒子飞散 → 消散 ═══
            local cx, cy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)

            -- 整体分两大阶段：蓄力(0~0.12) + 爆发(0.12~1.0)
            local chargeEnd = 0.12
            local isCharging = progress < chargeEnd

            if isCharging then
                -- ═══ 蓄力阶段：薄光环收缩 + 小亮核 ═══
                local cP = progress / chargeEnd  -- 0→1
                -- 收缩薄环（从大到小，很淡）
                local shrinkR = hexSize * (3.0 * (1.0 - cP * 0.7))
                local shrinkA = math.floor(80 * cP)
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, shrinkR)
                nvgFillPaint(nvg, nvgRadialGradient(nvg,
                    cx, cy, shrinkR * 0.85, shrinkR,
                    nvgRGBA(255, 120, 200, shrinkA),
                    nvgRGBA(200, 50, 150, 0)))
                nvgFill(nvg)
                -- 中心小亮核
                local coreR = hexSize * (0.5 - cP * 0.2)
                local coreA = math.floor(200 * cP * cP)
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, coreR)
                nvgFillPaint(nvg, nvgRadialGradient(nvg,
                    cx, cy, 0, coreR,
                    nvgRGBA(255, 230, 255, coreA),
                    nvgRGBA(255, 100, 200, math.floor(coreA * 0.3))))
                nvgFill(nvg)
                -- 轻微屏幕震动
                G.battle.screenShake = math.max(G.battle.screenShake or 0, 0.15 + cP * 0.3)
            else
                -- ═══ 爆发阶段 ═══
                local bP = (progress - chargeEnd) / (1.0 - chargeEnd)  -- 0→1
                local fade = bP < 0.7 and 1.0 or math.max(0, 1.0 - (bP - 0.7) / 0.3)
                local alpha = math.floor(fade * 255)

                if alpha > 0 then
                    -- ── 1) 短白闪（非常短暂，范围小，不覆盖全屏） ──
                    if bP < 0.08 then
                        local flashT = bP / 0.08
                        local flashA = math.floor((1.0 - flashT) * 120)
                        local flashR = hexSize * 4.0
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, cx, cy, flashR)
                        nvgFillPaint(nvg, nvgRadialGradient(nvg,
                            cx, cy, 0, flashR,
                            nvgRGBA(255, 240, 255, flashA),
                            nvgRGBA(255, 200, 240, 0)))
                        nvgFill(nvg)
                        -- 爆发震动
                        G.battle.screenShake = math.max(G.battle.screenShake or 0, 1.5 * (1.0 - flashT))
                    end

                    -- ── 2) 淡紫雾气底（代替实心爆炸球，非常淡） ──
                    local expandT = math.min(1.0, bP * 2.0)
                    local expandEase = 1.0 - (1.0 - expandT) * (1.0 - expandT)
                    local mistR = hexSize * (1.0 + expandEase * 3.5)
                    local mistA = math.floor(alpha * 0.10 * (1.0 - expandEase * 0.6))
                    if mistA > 2 then
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, cx, cy, mistR)
                        nvgFillPaint(nvg, nvgRadialGradient(nvg,
                            cx, cy, mistR * 0.2, mistR,
                            nvgRGBA(220, 100, 255, mistA),
                            nvgRGBA(180, 60, 200, 0)))
                        nvgFill(nvg)
                    end

                    -- ── 3) 扩散薄环（3道，极淡） ──
                    for w = 1, 3 do
                        local wDelay = (w - 1) * 0.15
                        local wT = math.max(0, bP - wDelay) * 2.0
                        if wT > 0 and wT < 1.0 then
                            local wR = hexSize * (1.5 + wT * 5.0)
                            local wA = math.floor(alpha * 0.15 * math.sin(wT * math.pi))
                            nvgBeginPath(nvg)
                            nvgCircle(nvg, cx, cy, wR)
                            nvgFillPaint(nvg, nvgRadialGradient(nvg,
                                cx, cy, wR * 0.88, wR,
                                nvgRGBA(255, 150, 255, wA),
                                nvgRGBA(200, 80, 220, 0)))
                            nvgFill(nvg)
                        end
                    end

                    -- ── 4) 细光线（8道，很细很淡，快速射出） ──
                    local rayCount = 8
                    for i = 1, rayCount do
                        local rayAngle = (i / rayCount) * math.pi * 2 + 0.4
                        local rayT = math.min(1.0, bP * 2.0)
                        local rayEase = 1.0 - (1.0 - rayT) * (1.0 - rayT)
                        local rayLen = hexSize * (0.5 + rayEase * 6.0)
                        local rayW = hexSize * 0.12 * (1.0 - rayT * 0.7)
                        local rayA = math.floor(alpha * 0.25 * (1.0 - rayT * 0.8))
                        if rayA > 2 and rayW > 0.5 then
                            local rx = cx + math.cos(rayAngle) * hexSize * 0.5
                            local ry = cy + math.sin(rayAngle) * hexSize * 0.5
                            local ex = cx + math.cos(rayAngle) * rayLen
                            local ey = cy + math.sin(rayAngle) * rayLen
                            local perpX = -math.sin(rayAngle)
                            local perpY = math.cos(rayAngle)
                            nvgBeginPath(nvg)
                            nvgMoveTo(nvg, rx + perpX * rayW, ry + perpY * rayW)
                            nvgLineTo(nvg, ex + perpX * rayW * 0.1, ey + perpY * rayW * 0.1)
                            nvgLineTo(nvg, ex - perpX * rayW * 0.1, ey - perpY * rayW * 0.1)
                            nvgLineTo(nvg, rx - perpX * rayW, ry - perpY * rayW)
                            nvgClosePath(nvg)
                            nvgFillColor(nvg, nvgRGBA(255, 200, 255, rayA))
                            nvgFill(nvg)
                        end
                    end

                    -- ── 5) 飘散粒子（20颗，不同大小/速度/方向，主视觉） ──
                    for i = 1, 20 do
                        local seed = i * 137.508
                        local epDelay = ((i - 1) / 20) * 0.15
                        local eT = math.max(0, bP - epDelay) / math.max(0.01, 1.0 - epDelay)
                        if eT > 0 and eT < 1 then
                            local eAngle = seed + eT * 0.5
                            local eDist = hexSize * (0.3 + eT * (2.0 + (i % 5) * 0.8))
                            local ex = cx + math.cos(eAngle) * eDist
                            local ey = cy + math.sin(eAngle) * eDist - eT * hexSize * (0.5 + (i % 3) * 0.6)
                            local eFade = eT < 0.2 and (eT / 0.2) or (1.0 - (eT - 0.2) / 0.8)
                            local eA = math.floor(eFade * alpha * 0.5)
                            local eSize = hexSize * (0.06 + (i % 4) * 0.04) * (1.0 - eT * 0.4)
                            if eA > 3 then
                                nvgBeginPath(nvg)
                                nvgCircle(nvg, ex, ey, eSize)
                                nvgFillPaint(nvg, nvgRadialGradient(nvg,
                                    ex, ey, 0, eSize,
                                    nvgRGBA(255, 200, 245, eA),
                                    nvgRGBA(230, 120, 210, 0)))
                                nvgFill(nvg)
                            end
                        end
                    end

                    -- ── 6) 中心残留小亮核（快速缩小消散） ──
                    if bP < 0.4 then
                        local coreT = bP / 0.4
                        local coreR = hexSize * 0.4 * (1.0 - coreT)
                        local coreA = math.floor(alpha * 0.6 * (1.0 - coreT))
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, cx, cy, coreR * 2.0)
                        nvgFillPaint(nvg, nvgRadialGradient(nvg,
                            cx, cy, 0, coreR * 2.0,
                            nvgRGBA(255, 200, 240, math.floor(coreA * 0.3)),
                            nvgRGBA(200, 100, 180, 0)))
                        nvgFill(nvg)
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, cx, cy, coreR)
                        nvgFillPaint(nvg, nvgRadialGradient(nvg,
                            cx, cy, 0, coreR,
                            nvgRGBA(255, 240, 255, coreA),
                            nvgRGBA(240, 160, 230, 0)))
                        nvgFill(nvg)
                    end
                end
            end

        elseif fx.type == "lava_eruption" then
            -- ═══ 熔岩喷发：大小岩浆块飞溅 + 火星拖尾 + 多层冲击波 ═══
            local cx, cy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)
            local delay = fx.delay or 0
            local elapsed = (1.0 - fx.timer / fx.maxTimer) * fx.maxTimer
            local fxSeed = fx.col * 13 + fx.row * 29
            if elapsed >= delay then
                local localP = math.min(1.0, (elapsed - delay) / (fx.maxTimer - delay))
                local fade = localP < 0.25 and (localP / 0.25) or math.max(0, 1.0 - (localP - 0.25) / 0.75)
                local alpha = math.floor(fade * 255)

                -- 1) 底层岩浆涌出（暗红扩散）
                local burstR = hexSize * (0.3 + localP * 2.0)
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, burstR)
                nvgFillPaint(nvg, nvgRadialGradient(nvg,
                    cx, cy, 0, burstR,
                    nvgRGBA(200, 60, 10, math.floor(alpha * 0.5)),
                    nvgRGBA(150, 30, 0, 0)))
                nvgFill(nvg)

                -- 2) 中层亮橙岩浆涌泉
                local midR = hexSize * (0.5 + localP * 1.2)
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, midR)
                nvgFillPaint(nvg, nvgRadialGradient(nvg,
                    cx, cy, 0, midR,
                    nvgRGBA(255, 180, 40, alpha),
                    nvgRGBA(255, 80, 0, 0)))
                nvgFill(nvg)

                -- 3) 白热核心
                local coreR = hexSize * 0.35 * math.max(0, 1.0 - localP * 1.2)
                if coreR > 1 then
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, cx, cy, coreR)
                    nvgFillPaint(nvg, nvgRadialGradient(nvg,
                        cx, cy, 0, coreR,
                        nvgRGBA(255, 255, 220, math.floor(alpha * 0.95)),
                        nvgRGBA(255, 200, 80, 0)))
                    nvgFill(nvg)
                end

                -- 4) 大块岩浆碎石（3块，沿抛物线飞出，有拖尾）
                for i = 1, 3 do
                    local bSeed = fxSeed + i * 67
                    local bAngle = (i / 3) * math.pi * 2 + (bSeed % 314) / 100.0
                    local bSpeed = 0.8 + (bSeed % 40) / 100.0
                    local bDist = hexSize * localP * 2.2 * bSpeed
                    local bGravity = localP * localP * hexSize * 1.5
                    local bx = cx + math.cos(bAngle) * bDist
                    local by = cy + math.sin(bAngle) * bDist * 0.7 - hexSize * localP * 1.8 + bGravity
                    local bSize = hexSize * (0.12 + (bSeed % 15) / 100.0) * math.max(0.3, 1.0 - localP * 0.7)
                    local bAlpha = math.floor(fade * 240)
                    if bAlpha > 10 and bSize > 1 then
                        -- 拖尾（3段渐隐）
                        for ti = 1, 3 do
                            local tP = localP - ti * 0.04
                            if tP > 0 then
                                local tGrav = tP * tP * hexSize * 1.5
                                local tx = cx + math.cos(bAngle) * hexSize * tP * 2.2 * bSpeed
                                local ty = cy + math.sin(bAngle) * hexSize * tP * 2.2 * bSpeed * 0.7 - hexSize * tP * 1.8 + tGrav
                                local tSize = bSize * (0.7 - ti * 0.15)
                                local tAlpha = math.floor(bAlpha * (0.4 - ti * 0.1))
                                if tAlpha > 5 and tSize > 0.5 then
                                    nvgBeginPath(nvg)
                                    nvgCircle(nvg, tx, ty, tSize)
                                    nvgFillColor(nvg, nvgRGBA(255, 140, 20, tAlpha))
                                    nvgFill(nvg)
                                end
                            end
                        end
                        -- 岩浆块本体（暗边亮心）
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, bx, by, bSize)
                        nvgFillPaint(nvg, nvgRadialGradient(nvg,
                            bx, by, 0, bSize,
                            nvgRGBA(255, 230, 100, bAlpha),
                            nvgRGBA(200, 60, 10, math.floor(bAlpha * 0.6))))
                        nvgFill(nvg)
                    end
                end

                -- 5) 小碎片火星（8颗，更快更远）
                for i = 1, 8 do
                    local sSeed = fxSeed + i * 43
                    local sAngle = (i / 8) * math.pi * 2 + (sSeed % 200) / 100.0
                    local sSpeed = 1.0 + (sSeed % 60) / 100.0
                    local sDist = hexSize * localP * 2.8 * sSpeed
                    local sGrav = localP * localP * hexSize * (0.8 + (sSeed % 30) / 30.0)
                    local sx = cx + math.cos(sAngle) * sDist
                    local sy = cy + math.sin(sAngle) * sDist * 0.6 - hexSize * localP * 2.0 + sGrav
                    local sSize = hexSize * (0.03 + (sSeed % 8) / 200.0) * math.max(0.2, 1.0 - localP)
                    local sAlpha = math.floor(fade * 220 * math.max(0, 1.0 - localP * 0.8))
                    if sAlpha > 8 and sSize > 0.3 then
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, sx, sy, sSize)
                        nvgFillColor(nvg, nvgRGBA(255, 200 + (sSeed % 55), 60, sAlpha))
                        nvgFill(nvg)
                    end
                end

                -- 6) 双层冲击波
                if localP < 0.5 then
                    -- 内圈（快速扩散，橙色）
                    local r1 = hexSize * (0.4 + localP * 4.0)
                    local a1 = math.floor((1.0 - localP * 2) * 150)
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, cx, cy, r1)
                    nvgStrokeColor(nvg, nvgRGBA(255, 150, 30, a1))
                    nvgStrokeWidth(nvg, 3.0 * (1.0 - localP * 2))
                    nvgStroke(nvg)
                end
                if localP > 0.05 and localP < 0.6 then
                    -- 外圈（稍慢，红色）
                    local p2 = (localP - 0.05) / 0.55
                    local r2 = hexSize * (0.3 + p2 * 3.5)
                    local a2 = math.floor((1.0 - p2) * 80)
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, cx, cy, r2)
                    nvgStrokeColor(nvg, nvgRGBA(200, 50, 10, a2))
                    nvgStrokeWidth(nvg, 2.0 * (1.0 - p2))
                    nvgStroke(nvg)
                end
            end

        elseif fx.type == "lava_shield_regen" then
            -- ═══ 岩甲再生：岩石碎片向Boss汇聚并形成护盾 ═══
            local cx, cy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)
            local fade = progress < 0.2 and (progress / 0.2) or (progress < 0.7 and 1.0 or math.max(0, 1.0 - (progress - 0.7) / 0.3))
            local alpha = math.floor(fade * 255)

            -- 1) 岩石碎片从四周向中心汇聚
            for i = 1, 8 do
                local angle = (i / 8) * math.pi * 2 + 0.3
                local dist = hexSize * 2.5 * math.max(0, 1.0 - progress * 1.5)
                local sx = cx + math.cos(angle) * dist
                local sy = cy + math.sin(angle) * dist
                local sSize = hexSize * (0.12 + (i % 3) * 0.06)
                local sAlpha = math.floor(alpha * (0.5 + (i % 2) * 0.3))
                if sAlpha > 5 then
                    nvgBeginPath(nvg)
                    -- 岩石用不规则四边形
                    nvgMoveTo(nvg, sx - sSize, sy)
                    nvgLineTo(nvg, sx, sy - sSize * 1.2)
                    nvgLineTo(nvg, sx + sSize, sy + sSize * 0.3)
                    nvgLineTo(nvg, sx - sSize * 0.3, sy + sSize)
                    nvgClosePath(nvg)
                    nvgFillColor(nvg, nvgRGBA(160, 100, 40, sAlpha))
                    nvgFill(nvg)
                end
            end

            -- 2) 中心护盾光环（逐渐增强）
            local shieldR = hexSize * (0.8 + progress * 0.4)
            local shieldA = math.floor(alpha * 0.6 * math.min(1.0, progress * 2))
            nvgBeginPath(nvg)
            nvgCircle(nvg, cx, cy, shieldR)
            nvgFillPaint(nvg, nvgRadialGradient(nvg,
                cx, cy, shieldR * 0.6, shieldR,
                nvgRGBA(200, 140, 60, shieldA),
                nvgRGBA(140, 80, 20, 0)))
            nvgFill(nvg)

            -- 3) 护盾边缘亮线
            if progress > 0.3 then
                local edgeA = math.floor(alpha * 0.8 * math.min(1.0, (progress - 0.3) * 3))
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, shieldR)
                nvgStrokeColor(nvg, nvgRGBA(220, 170, 80, edgeA))
                nvgStrokeWidth(nvg, 2.0)
                nvgStroke(nvg)
            end

        elseif fx.type == "sword_slash" then
            -- ═══ 踏步斩剑光：3道剑气弧线斜劈向目标格，带拖尾消散 ═══
            local cx, cy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)
            local ox2, oy2 = HexGrid.HexToPixel(fx.fromCol, fx.fromRow, hexSize, ox, oy)
            -- 剑光颜色：粉红剑气
            local r1, g1, b1 = 255, 100, 180   -- 主色：亮粉红
            local r2, g2, b2 = 255, 220, 240   -- 高光：近白粉

            -- ── 目标格高亮：橙红锁定外圈（全程可见，前半段脉冲，后半段淡出）──
            local ringFade = math.max(0.0, 1.0 - progress / 0.85)
            local ringA = math.floor(ringFade * 230)
            if ringA > 10 then
                -- 外圈：大橙红色实线圆（六边形外接圆半径约 hexSize*0.9）
                local ringR = hexSize * (0.88 + math.sin(progress * math.pi * 4) * 0.06)
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, ringR)
                nvgStrokeColor(nvg, nvgRGBA(255, 80, 30, ringA))
                nvgStrokeWidth(nvg, 3.5)
                nvgStroke(nvg)
                -- 内圈：细白圈贴合目标
                local innerR = hexSize * 0.65
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, innerR)
                nvgStrokeColor(nvg, nvgRGBA(255, 200, 160, math.floor(ringA * 0.6)))
                nvgStrokeWidth(nvg, 1.5)
                nvgStroke(nvg)
                -- 中心底色：半透明橙红填充，让目标格在棋盘上一眼可见
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, hexSize * 0.72)
                nvgFillColor(nvg, nvgRGBA(255, 60, 20, math.floor(ringA * 0.18)))
                nvgFill(nvg)
            end

            -- 攻击方向向量 (英雄→敌人)
            local dx = cx - ox2
            local dy = cy - oy2
            local len = math.sqrt(dx * dx + dy * dy)
            if len < 1 then len = 1 end
            local nx, ny = dx / len, dy / len
            -- 法向量（垂直于攻击方向）
            local px, py = -ny, nx

            -- 阶段：0~0.5 展开，0.5~1.0 消散
            local appear = math.min(1.0, progress / 0.45)       -- 出现速度快
            local fadeOut = math.max(0.0, (progress - 0.45) / 0.55)  -- 消散慢
            local alpha = math.floor((1.0 - fadeOut) * 240)

            if alpha > 10 then
                -- 剑光弧：3道平行弧线，宽度不同
                local slashDefs = {
                    { offset = 0,    width = 4.5, lengthScale = 1.0,  alphaFactor = 1.0  },
                    { offset =  hexSize * 0.18, width = 2.5, lengthScale = 0.85, alphaFactor = 0.7  },
                    { offset = -hexSize * 0.18, width = 2.0, lengthScale = 0.75, alphaFactor = 0.55 },
                }
                for _, sd in ipairs(slashDefs) do
                    local slashLen = hexSize * 1.3 * appear * sd.lengthScale
                    -- 剑光中心在目标格子，从前方切入
                    local startX = cx - nx * slashLen * 0.4 + px * sd.offset
                    local startY = cy - ny * slashLen * 0.4 + py * sd.offset
                    local endX   = cx + nx * slashLen * 0.6 + px * sd.offset
                    local endY   = cy + ny * slashLen * 0.6 + py * sd.offset

                    local a = math.floor(alpha * sd.alphaFactor)
                    if a > 8 then
                        -- 渐变剑光：头部亮、尾部透明
                        local paint = nvgLinearGradient(nvg, startX, startY, endX, endY,
                            nvgRGBA(r2, g2, b2, 0),
                            nvgRGBA(r1, g1, b1, a))
                        nvgBeginPath(nvg)
                        nvgMoveTo(nvg, startX, startY)
                        nvgLineTo(nvg, endX, endY)
                        nvgStrokePaint(nvg, paint)
                        nvgStrokeWidth(nvg, sd.width * (1.0 - fadeOut * 0.5))
                        nvgLineCap(nvg, NVG_ROUND)
                        nvgStroke(nvg)
                    end
                end

                -- 命中闪光：目标格中心短暂爆光
                if progress < 0.35 then
                    local flashT  = progress / 0.35
                    local flashA  = math.floor((1.0 - flashT) * 200)
                    local flashR  = hexSize * (0.15 + flashT * 0.45)
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, cx, cy, flashR)
                    nvgFillPaint(nvg, nvgRadialGradient(nvg,
                        cx, cy, 0, flashR,
                        nvgRGBA(255, 255, 255, flashA),
                        nvgRGBA(r1, g1, b1, 0)))
                    nvgFill(nvg)
                end

                -- 飞散光粒：命中时向四周弹出4个小点
                if progress < 0.5 then
                    local sparkT = progress / 0.5
                    local sparkA = math.floor((1.0 - sparkT) * 200)
                    for i = 1, 4 do
                        local angle = (i / 4) * math.pi * 2 + math.atan(ny, nx) + 0.4
                        local dist  = hexSize * sparkT * 0.6
                        local sx = cx + math.cos(angle) * dist
                        local sy = cy + math.sin(angle) * dist
                        local sr = hexSize * 0.06 * (1.0 - sparkT)
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, sx, sy, sr)
                        nvgFillColor(nvg, nvgRGBA(r2, g2, b2, sparkA))
                        nvgFill(nvg)
                    end
                end
            end

        elseif fx.type == "abyss_claw" then
            -- ═══ 深渊海妖·触手重击：暗紫触手从中心猛击扫射，黑水飞溅 ═══
            local cx, cy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)
            local fade  = math.max(0, 1.0 - progress)
            local alpha = math.floor(fade * 255)
            if alpha > 5 then
                -- 中心黑暗闪光（前40%）
                if progress < 0.4 then
                    local flashP = progress / 0.4
                    local flashA = math.floor((1.0 - flashP) * 200)
                    local flashR = hexSize * (0.6 + flashP * 1.0)
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, cx, cy, flashR)
                    nvgFillPaint(nvg, nvgRadialGradient(nvg, cx, cy, 0, flashR,
                        nvgRGBA(200, 80, 255, flashA), nvgRGBA(80, 0, 120, 0)))
                    nvgFill(nvg)
                end
                -- 3条触手弧线向外扫射（放射状）
                for i = 1, 3 do
                    local baseAngle = (i / 3) * math.pi * 2 + progress * 3.0
                    local tentacleLen = hexSize * 1.8 * math.min(1.0, progress / 0.35)
                    local endX = cx + math.cos(baseAngle) * tentacleLen
                    local endY = cy + math.sin(baseAngle) * tentacleLen
                    -- 弯曲触手：用两段近似
                    local midX = cx + math.cos(baseAngle + 0.4) * tentacleLen * 0.55
                    local midY = cy + math.sin(baseAngle + 0.4) * tentacleLen * 0.55
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, cx, cy)
                    nvgQuadTo(nvg, midX, midY, endX, endY)
                    nvgStrokePaint(nvg, nvgLinearGradient(nvg, cx, cy, endX, endY,
                        nvgRGBA(160, 40, 220, alpha), nvgRGBA(60, 0, 100, 0)))
                    nvgStrokeWidth(nvg, 5.0 * fade)
                    nvgLineCap(nvg, NVG_ROUND)
                    nvgStroke(nvg)
                end
                -- 8颗黑紫碎水粒子向外飞散
                for i = 1, 8 do
                    local angle = (i / 8) * math.pi * 2 + progress * 1.2
                    local dist  = hexSize * progress * 1.5
                    local px2 = cx + math.cos(angle) * dist
                    local py2 = cy + math.sin(angle) * dist
                    local pSize = 4.0 * fade
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, px2, py2, pSize)
                    nvgFillColor(nvg, nvgRGBA(140, 30, 200, math.floor(alpha * 0.8)))
                    nvgFill(nvg)
                end
                -- 外层暗紫冲击环
                local ringR = hexSize * 2.2 * progress
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, ringR)
                nvgStrokeColor(nvg, nvgRGBA(120, 40, 180, math.floor(alpha * 0.7)))
                nvgStrokeWidth(nvg, 3.5 * fade)
                nvgStroke(nvg)
            end

        elseif fx.type == "abyss_venom" then
            -- ═══ 深渊海妖·深渊喷毒：深紫毒液喷溅，毒气云扩散 ═══
            local cx, cy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)
            local fade  = math.max(0, 1.0 - progress)
            local alpha = math.floor(fade * 230)
            if alpha > 5 then
                -- 毒液核心（径向渐变，从深紫到透明）
                local coreR = hexSize * (0.5 + progress * 0.6)
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, coreR)
                nvgFillPaint(nvg, nvgRadialGradient(nvg, cx, cy, 0, coreR,
                    nvgRGBA(100, 20, 180, math.floor(alpha * 0.8)),
                    nvgRGBA(40, 0, 80, 0)))
                nvgFill(nvg)
                -- 外层毒气云（更大，更透明）
                local fogR = hexSize * (0.9 + progress * 1.0)
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, fogR)
                nvgFillPaint(nvg, nvgRadialGradient(nvg, cx, cy, 0, fogR,
                    nvgRGBA(80, 0, 140, math.floor(alpha * 0.3)),
                    nvgRGBA(20, 0, 60, 0)))
                nvgFill(nvg)
                -- 16颗旋转毒粒（深紫，扁椭圆模拟俯视）
                for i = 1, 16 do
                    local angle = (i / 16) * math.pi * 2 + progress * 3.5
                    local dist  = hexSize * (0.2 + progress * 1.1)
                    local px2 = cx + math.cos(angle) * dist
                    local py2 = cy + math.sin(angle) * dist * 0.65
                    local pSize = (4 + math.sin(i * 1.3) * 2) * (1.0 - progress * 0.6)
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, px2, py2, math.max(1, pSize))
                    nvgFillColor(nvg, nvgRGBA(120, 30, 200, math.floor(alpha * 0.9)))
                    nvgFill(nvg)
                end
                -- 毒液滴落（3个向下滴落的大颗粒）
                for i = 1, 3 do
                    local angle = (i / 3) * math.pi * 2 + 0.5
                    local dist  = hexSize * progress * 0.7
                    local dropX = cx + math.cos(angle) * dist
                    local dropY = cy + math.sin(angle) * dist + hexSize * progress * 0.4
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, dropX, dropY, 6.0 * fade)
                    nvgFillColor(nvg, nvgRGBA(160, 60, 230, math.floor(alpha * 0.85)))
                    nvgFill(nvg)
                end
            end

        elseif fx.type == "lava_fist" then
            -- ═══ 熔岩领主·熔岩重拳：巨大橙红拳头砸落，地面裂开熔岩喷涌 ═══
            local cx, cy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)
            local fade  = math.max(0, 1.0 - progress)
            local alpha = math.floor(fade * 255)
            if alpha > 5 then
                -- 下砸轨迹（前45%：拳头从上方下砸到中心）
                if progress < 0.45 then
                    local dropP = progress / 0.45
                    local fistY = cy - hexSize * 2.0 * (1.0 - dropP)
                    local fistR = hexSize * (0.4 + dropP * 0.2)
                    -- 拳头圆球（炽热橙红）
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, cx, fistY, fistR)
                    nvgFillPaint(nvg, nvgRadialGradient(nvg, cx, fistY, 0, fistR,
                        nvgRGBA(255, 255, 100, 230), nvgRGBA(255, 80, 0, 180)))
                    nvgFill(nvg)
                    -- 拳头后方火焰尾迹
                    local trailH = hexSize * 1.2 * dropP
                    nvgBeginPath(nvg)
                    nvgRect(nvg, cx - hexSize * 0.25, fistY, hexSize * 0.5, trailH)
                    nvgFillPaint(nvg, nvgLinearGradient(nvg, cx, fistY, cx, fistY + trailH,
                        nvgRGBA(255, 120, 20, 180), nvgRGBA(255, 60, 0, 0)))
                    nvgFill(nvg)
                end
                -- 撞击后地面裂纹+熔岩喷射（45%以后）
                if progress >= 0.35 then
                    local impactP = math.min(1.0, (progress - 0.35) / 0.65)
                    -- 地面冲击波大圆（暗红/橙色）
                    local waveR = hexSize * 2.5 * impactP
                    local waveA = math.floor(math.max(0, 1.0 - impactP) * 220)
                    if waveA > 5 then
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, cx, cy, waveR)
                        nvgStrokeColor(nvg, nvgRGBA(255, 60, 0, waveA))
                        nvgStrokeWidth(nvg, 5.0 * (1.0 - impactP))
                        nvgStroke(nvg)
                    end
                    -- 5条地裂（从中心向外辐射）
                    for i = 1, 5 do
                        local angle = (i / 5) * math.pi * 2 + 0.3
                        local crackLen = hexSize * 1.6 * impactP
                        local ex2 = cx + math.cos(angle) * crackLen
                        local ey2 = cy + math.sin(angle) * crackLen
                        nvgBeginPath(nvg)
                        nvgMoveTo(nvg, cx, cy)
                        nvgLineTo(nvg, ex2, ey2)
                        nvgStrokePaint(nvg, nvgLinearGradient(nvg, cx, cy, ex2, ey2,
                            nvgRGBA(255, 200, 50, math.floor(waveA * 1.2)),
                            nvgRGBA(255, 60, 0, 0)))
                        nvgStrokeWidth(nvg, 3.0 * (1.0 - impactP) + 1)
                        nvgStroke(nvg)
                    end
                    -- 6颗熔岩飞溅（抛物线弹出）
                    for i = 1, 6 do
                        local angle = (i / 6) * math.pi * 2 + 0.8
                        local dist  = hexSize * impactP * 1.8
                        local gy    = hexSize * impactP * impactP * 1.2  -- 重力下落
                        local spx = cx + math.cos(angle) * dist
                        local spy = cy + math.sin(angle) * dist * 0.5 + gy
                        local spR = 5.0 * math.max(0, 1.0 - impactP)
                        if spR > 1 then
                            nvgBeginPath(nvg)
                            nvgCircle(nvg, spx, spy, spR)
                            nvgFillColor(nvg, nvgRGBA(255, 120, 20, math.floor(waveA * 0.9)))
                            nvgFill(nvg)
                        end
                    end
                end
            end

        elseif fx.type == "flame_bolt" then
            -- ═══ 熔岩领主·火焰弹射：橙红火球高速飞向目标，命中爆炸溅射 ═══
            local cx, cy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)
            local fade  = math.max(0, 1.0 - progress)
            local alpha = math.floor(fade * 255)
            if alpha > 5 then
                -- 火球命中爆炸（全程）
                local explodeR = hexSize * (0.3 + progress * 2.0)
                -- 外层爆炸冲击波（橙色）
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, explodeR)
                nvgStrokeColor(nvg, nvgRGBA(255, 100, 20, math.floor(alpha * 0.8)))
                nvgStrokeWidth(nvg, 4.0 * fade)
                nvgStroke(nvg)
                -- 中心火核（前50%明亮，后淡出）
                if progress < 0.5 then
                    local coreP = progress / 0.5
                    local coreA = math.floor((1.0 - coreP) * 240)
                    local coreR = hexSize * (0.7 - coreP * 0.3)
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, cx, cy, coreR)
                    nvgFillPaint(nvg, nvgRadialGradient(nvg, cx, cy, 0, coreR,
                        nvgRGBA(255, 255, 200, coreA), nvgRGBA(255, 80, 0, 0)))
                    nvgFill(nvg)
                end
                -- 8颗火花粒子飞散
                for i = 1, 8 do
                    local angle = (i / 8) * math.pi * 2 + progress * 0.5
                    local dist  = hexSize * progress * 2.0
                    local spx = cx + math.cos(angle) * dist
                    local spy = cy + math.sin(angle) * dist
                    local spR = 4.5 * fade
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, spx, spy, spR)
                    nvgFillColor(nvg, nvgRGBA(255, 160, 40, math.floor(alpha * 0.85)))
                    nvgFill(nvg)
                end
                -- 4个溅射熔岩点（比火花慢，范围更大）
                for i = 1, 4 do
                    local angle = (i / 4) * math.pi * 2 + 0.6
                    local dist  = hexSize * progress * 1.3
                    local lpx = cx + math.cos(angle) * dist
                    local lpy = cy + math.sin(angle) * dist
                    local lpR = 7.0 * fade
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, lpx, lpy, lpR)
                    nvgFillColor(nvg, nvgRGBA(255, 80, 0, math.floor(alpha * 0.7)))
                    nvgFill(nvg)
                end
                -- 整体橙红底光（径向渐变覆盖目标格）
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, hexSize * 0.85)
                nvgFillPaint(nvg, nvgRadialGradient(nvg, cx, cy, 0, hexSize * 0.85,
                    nvgRGBA(255, 120, 30, math.floor(alpha * 0.35)),
                    nvgRGBA(255, 60, 0, 0)))
                nvgFill(nvg)
            end

        elseif fx.type == "coral_spike" then
            -- ═══ 珊瑚守卫·珊瑚刺击：青绿尖刺从地面骤然刺出，带毒液光效 ═══
            local cx, cy = HexGrid.HexToPixel(fx.col, fx.row, hexSize, ox, oy)
            local fade  = math.max(0, 1.0 - progress)
            local alpha = math.floor(fade * 255)
            if alpha > 5 then
                -- 底层珊瑚青光（持续）
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, hexSize * 0.9)
                nvgFillPaint(nvg, nvgRadialGradient(nvg, cx, cy, 0, hexSize * 0.9,
                    nvgRGBA(80, 240, 180, math.floor(alpha * 0.3)),
                    nvgRGBA(20, 160, 120, 0)))
                nvgFill(nvg)
                -- 4根珊瑚尖刺（从中心刺出，菱形截面）
                for i = 1, 4 do
                    local angle = (i / 4) * math.pi * 2 + math.pi / 8
                    local spikeLen = hexSize * 1.4 * math.min(1.0, progress / 0.3)
                    local spikeWidth = hexSize * 0.12 * (1.0 - progress * 0.7)
                    if spikeLen > 2 and spikeWidth > 0.5 then
                        local tipX = cx + math.cos(angle) * spikeLen
                        local tipY = cy + math.sin(angle) * spikeLen
                        local perpX = -math.sin(angle) * spikeWidth
                        local perpY =  math.cos(angle) * spikeWidth
                        nvgBeginPath(nvg)
                        nvgMoveTo(nvg, cx + perpX, cy + perpY)
                        nvgLineTo(nvg, tipX, tipY)
                        nvgLineTo(nvg, cx - perpX, cy - perpY)
                        nvgLineTo(nvg, cx - math.cos(angle) * spikeWidth * 0.3,
                                       cy - math.sin(angle) * spikeWidth * 0.3)
                        nvgClosePath(nvg)
                        nvgFillPaint(nvg, nvgLinearGradient(nvg, cx, cy, tipX, tipY,
                            nvgRGBA(255, 255, 255, math.floor(alpha * 0.9)),
                            nvgRGBA(60, 220, 160, math.floor(alpha * 0.6))))
                        nvgFill(nvg)
                    end
                end
                -- 命中外圈脉冲（前60%）
                if progress < 0.6 then
                    local pulseP = progress / 0.6
                    local pulseR = hexSize * (0.6 + pulseP * 0.7)
                    local pulseA = math.floor((1.0 - pulseP) * 200)
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, cx, cy, pulseR)
                    nvgStrokeColor(nvg, nvgRGBA(100, 255, 200, pulseA))
                    nvgStrokeWidth(nvg, 3.0 * (1.0 - pulseP))
                    nvgStroke(nvg)
                end
                -- 毒液飞溅粒子（10颗绿紫色）
                for i = 1, 10 do
                    local angle = (i / 10) * math.pi * 2 + progress * 2.0
                    local dist  = hexSize * (0.1 + progress * 0.85)
                    local px2 = cx + math.cos(angle) * dist
                    local py2 = cy + math.sin(angle) * dist * 0.7
                    local pSize = 3.5 * fade
                    local isPoison = (i % 2 == 0)
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, px2, py2, pSize)
                    nvgFillColor(nvg, isPoison
                        and nvgRGBA(140, 80, 220, math.floor(alpha * 0.85))
                        or  nvgRGBA(60, 220, 160, math.floor(alpha * 0.85)))
                    nvgFill(nvg)
                end
            end

        end
        ::continue_fx::
    end


end

return BoardWidget_VFX
