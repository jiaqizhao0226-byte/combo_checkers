-- ============================================================================
-- BoardWidget - 棋盘 NanoVG 渲染控件
-- ============================================================================
---@diagnostic disable: redefined-local, param-type-mismatch

local UI = require("urhox-libs/UI")
local HexGrid = require "HexGrid"
local Battle = require "Battle"
local G = require "GameState"
local IconAtlas = require "IconAtlas"
local BoardWidget_VFX      = require "BoardWidget_VFX"
local BoardWidget_Overlays = require "BoardWidget_Overlays"
local WheelPopup           = require "WheelPopup"
local Skills               = require "Skills"

-- 跨子模块共享的渲染上下文（复用 table 避免 GC 压力）
local _ctx = {}

-- 敌人/Boss 配色表（用于死亡特效、击中特效等）
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
    sand_scorpion   = {200, 160, 60},
    quicksand_worm  = {180, 140, 80},
    sand_hawk       = {220, 180, 100},
    sand_strider    = {160, 100, 200},
    sand_rattler    = {180, 80, 60},
    venom_lizard    = {100, 180, 70},
}
local function GetEnemyColor(enemyType)
    return ENEMY_COLORS[enemyType] or {180, 60, 60}
end

-- 章节主题色配置（棋盘视觉）
local BOARD_THEMES = {
    [1] = { -- 深渊海沟
        hexFill     = {32, 50, 80, 255},
        hexStroke   = {55, 90, 140, 200},
        hexGlow     = {40, 120, 220},
        bgTop       = {15, 25, 60, 255},
        bgBot       = {22, 42, 85, 255},
        fogColor    = {15, 30, 60, 60},
        particle    = "bubble",
        particleClr = {{80, 180, 255}, {60, 140, 220}, {120, 200, 255}},
        shaftClr    = {30, 80, 180},
        frameClr    = {40, 120, 220},
        silClr      = {8, 15, 40, 180},
        silType     = "seaweed",
    },
    [2] = { -- 烈焰山脉
        hexFill     = {55, 30, 15, 255},          -- 调暗降饱和：暗橙棕
        hexStroke   = {105, 55, 25, 180},          -- 低调描边：深橙棕，alpha降低参考ch1风格
        hexGlow     = {160, 70, 25},
        bgTop       = {40, 16, 8, 255},            -- 调暗：深暗红棕
        bgBot       = {58, 22, 10, 255},           -- 调暗
        fogColor    = {50, 20, 10, 60},
        particle    = "ember",
        particleClr = {{255, 140, 30}, {255, 80, 20}, {255, 200, 60}},
        shaftClr    = {200, 100, 20},
        frameClr    = {220, 100, 40},
        silClr      = {35, 10, 5, 200},
        silType     = "rocks",
    },
    [3] = { -- 珊瑚迷宫
        hexFill     = {42, 65, 58, 255},
        hexStroke   = {82, 145, 125, 200},
        hexGlow     = {120, 220, 180},
        bgTop       = {15, 45, 35, 255},
        bgBot       = {22, 68, 52, 255},
        fogColor    = {20, 40, 35, 60},
        particle    = "bubble",
        particleClr = {{120, 255, 200}, {80, 220, 180}, {180, 255, 220}},
        shaftClr    = {40, 160, 120},
        frameClr    = {120, 220, 180},
        silClr      = {10, 30, 25, 180},
        silType     = "coral",
    },
    [4] = { -- 流沙荒漠
        hexFill     = {65, 50, 28, 255},
        hexStroke   = {120, 90, 40, 200},
        hexGlow     = {200, 160, 50},
        bgTop       = {40, 30, 12, 255},
        bgBot       = {55, 40, 18, 255},
        fogColor    = {50, 38, 15, 50},
        particle    = "ember",
        particleClr = {{220, 180, 80}, {200, 150, 50}, {240, 200, 100}},
        shaftClr    = {180, 140, 40},
        frameClr    = {200, 160, 50},
        silClr      = {30, 22, 10, 180},
        silType     = "rocks",
    },
    [5] = { -- 永冻绝境：冰白蓝主题
        hexFill     = {38, 55, 78, 255},
        hexStroke   = {70, 110, 150, 180},
        hexGlow     = {100, 180, 240},
        bgTop       = {12, 18, 38, 255},
        bgBot       = {22, 30, 58, 255},
        fogColor    = {20, 40, 70, 40},
        particle    = "snowflake",
        particleClr = {{200, 230, 255}, {160, 210, 245}, {240, 248, 255}},
        shaftClr    = {80, 160, 220},
        frameClr    = {120, 200, 240},
        silClr      = {10, 15, 30, 180},
        silType     = "rocks",
    },
    [0] = { -- 无尽深渊：紫色主题
        hexFill     = {58, 40, 90, 255},
        hexStroke   = {90, 68, 135, 180},
        hexGlow     = {150, 110, 210},
        bgTop       = {32, 20, 58, 255},
        bgBot       = {42, 28, 72, 255},
        fogColor    = {35, 22, 65, 45},
        particle    = "aurora",
        particleClr = {{200, 160, 255}, {160, 120, 240}, {220, 180, 255}},
        shaftClr    = {130, 70, 200},
        frameClr    = {175, 125, 250},
        silClr      = {18, 10, 40, 180},
        silType     = "rocks",
    },
}

--- 获取当前战斗的章节主题
local function GetCurrentBoardTheme()
    if G.battle then
        -- 无尽模式使用专属紫色主题
        if G.battle.isEndless then
            return BOARD_THEMES[0]
        end
        if G.battle.level then
            local chapter = math.ceil(G.battle.level / Battle.LEVELS_PER_CHAPTER)
            return BOARD_THEMES[chapter] or BOARD_THEMES[1]
        end
    end
    return BOARD_THEMES[1]
end

local BoardWidget = UI.Widget:Extend("BoardWidget")

function BoardWidget:Init(props)
    props.width = props.width or "100%"
    props.height = props.height or "100%"
    props.onPointerDown = function(event, widget)
        self:HandleClick(event)
    end
    self.onCellClick_ = props.onCellClick
    UI.Widget.Init(self, props)
    G.boardWidgetRef = self
end

--- 判断一个格子是否需要渲染（用于剔除，向外扩展避免边缘裁切）
--- cx/cy 是已含 widget 位置和相机偏移的屏幕绝对坐标
--- margin 默认传 hexSize；有大范围视觉效果的格子（如祭坛光晕）传更大值
local function IsCellOnScreen(cx, cy, margin, lx, ly, lw, lh)
    return cx >= lx - margin and cx <= lx + lw + margin
       and cy >= ly - margin and cy <= ly + lh + margin
end

function BoardWidget:Render(nvg)
    self:RenderFullBackground(nvg)
    local l = self:GetAbsoluteLayout()
    if l.w <= 0 or l.h <= 0 then return end
    if not G.battle then return end

    -- 缓存 widget 布局尺寸，供 SnapCameraToHero 等外部使用（保持坐标系一致）
    G.boardLayoutW = l.w
    G.boardLayoutH = l.h

    nvgFontFace(nvg, UI.Theme.FontFace("sans", "normal"))
    G.gridParams = HexGrid.CalcGridParams(l.w, l.h, HexGrid.COLS, HexGrid.ROWS, G.BOARD_ZOOM)

    -- === 章节主题背景：以棋盘为中心的径向晕染，边缘透明，与全局渐变无缝融合 ===
    local theme = GetCurrentBoardTheme()
    local bt = theme.bgTop
    local bb = theme.bgBot
    -- 棋盘中心点和覆盖半径
    local bcx = l.x + l.w * 0.5
    local bcy = l.y + l.h * 0.5
    local boardR = math.min(l.w, l.h) * 0.62  -- 略大于六边形棋盘外接圆
    -- 上半段：以棋盘中上为圆心的径向渐变（bgTop色调，向外透明）
    local topPaint = nvgRadialGradient(nvg, bcx, bcy - boardR * 0.15, boardR * 0.1, boardR * 1.3,
        nvgRGBA(bt[1], bt[2], bt[3], 220),
        nvgRGBA(bt[1], bt[2], bt[3], 0))
    nvgBeginPath(nvg)
    nvgRect(nvg, l.x, l.y, l.w, l.h)
    nvgFillPaint(nvg, topPaint)
    nvgFill(nvg)
    -- 下半段：略偏下，bgBot色调叠加，形成上深下浅（或上浅下深）的纵向过渡
    local botPaint = nvgRadialGradient(nvg, bcx, bcy + boardR * 0.2, boardR * 0.1, boardR * 1.1,
        nvgRGBA(bb[1], bb[2], bb[3], 160),
        nvgRGBA(bb[1], bb[2], bb[3], 0))
    nvgBeginPath(nvg)
    nvgRect(nvg, l.x, l.y, l.w, l.h)
    nvgFillPaint(nvg, botPaint)
    nvgFill(nvg)



    local t = G.time or 0

    -- === 0.2 大气光柱 Light Shafts ===
    do
        local sc = theme.shaftClr
        for si = 1, 3 do
            local speed = 0.08 + si * 0.03
            local phase = si * 2.1
            local drift = math.sin(t * speed + phase) * l.w * 0.3
            local shaftX = l.x + l.w * (0.2 + si * 0.25) + drift
            local shaftW = l.w * (0.06 + si * 0.02)
            local shaftAlpha = math.floor(18 + math.sin(t * 0.4 + si) * 8)
            nvgSave(nvg)
            nvgTranslate(nvg, shaftX, l.y + l.h * 0.5)
            nvgRotate(nvg, 0.3 + si * 0.15)
            nvgBeginPath(nvg)
            nvgRect(nvg, -shaftW * 0.5, -l.h * 0.8, shaftW, l.h * 1.6)
            local sp = nvgLinearGradient(nvg, -shaftW * 0.5, -l.h * 0.8,
                -shaftW * 0.5, -l.h * 0.8 + l.h * 1.6,
                nvgRGBA(sc[1], sc[2], sc[3], 0),
                nvgRGBA(sc[1], sc[2], sc[3], shaftAlpha))
            nvgFillPaint(nvg, sp)
            nvgFill(nvg)
            -- 中段更亮
            nvgBeginPath(nvg)
            nvgRect(nvg, -shaftW * 0.3, -l.h * 0.2, shaftW * 0.6, l.h * 0.4)
            local sp2 = nvgLinearGradient(nvg, 0, -l.h * 0.2, 0, l.h * 0.2,
                nvgRGBA(sc[1], sc[2], sc[3], 0),
                nvgRGBA(sc[1], sc[2], sc[3], math.floor(shaftAlpha * 0.6)))
            nvgFillPaint(nvg, sp2)
            nvgFill(nvg)
            nvgRestore(nvg)
        end
    end

    -- === 0.3 飘动迷雾层 ===
    do
        local fc = theme.fogColor
        for fi = 1, 3 do
            local fogSpeed = 0.15 + fi * 0.08
            local fogPhase = fi * 1.7
            local fogCX = l.x + l.w * 0.5 + math.sin(t * fogSpeed + fogPhase) * l.w * 0.25
            local fogCY = l.y + l.h * (0.25 + fi * 0.2)
            local fogRX = l.w * (0.3 + fi * 0.08)
            local fogRY = l.h * (0.12 + fi * 0.04)
            local fogA = math.floor(fc[4] * (0.5 + math.sin(t * 0.3 + fi * 0.9) * 0.3))
            nvgSave(nvg)
            nvgTranslate(nvg, fogCX, fogCY)
            nvgScale(nvg, 1.0, fogRY / fogRX)
            local fogPaint = nvgRadialGradient(nvg, 0, 0, 0, fogRX,
                nvgRGBA(fc[1], fc[2], fc[3], fogA),
                nvgRGBA(fc[1], fc[2], fc[3], 0))
            nvgBeginPath(nvg)
            nvgCircle(nvg, 0, 0, fogRX)
            nvgFillPaint(nvg, fogPaint)
            nvgFill(nvg)
            nvgRestore(nvg)
        end
    end

    -- === 章节环境粒子特效 ===
    local pType = theme.particle
    local pColors = theme.particleClr
    for i = 1, 28 do
        local seed = i * 137 + 53
        local clr = pColors[((i - 1) % #pColors) + 1]
        local phase = (seed % 100) / 100 * math.pi * 2

        if pType == "firefly" then
            -- 萤火虫：缓慢漂移+忽明忽暗
            local fx = l.x + ((seed * 73) % math.floor(l.w))
            local fy = l.y + ((seed * 41) % math.floor(l.h))
            fx = fx + math.sin(t * 0.3 + phase) * 20
            fy = fy + math.cos(t * 0.4 + phase * 0.7) * 15
            local glow = math.sin(t * 1.8 + phase) * 0.5 + 0.5
            local alpha = math.floor(30 + glow * 100)
            local radius = 1.5 + glow * 2.5
            -- 外发光
            local glowPaint = nvgRadialGradient(nvg, fx, fy, 0, radius * 3,
                nvgRGBA(clr[1], clr[2], clr[3], math.floor(alpha * 0.4)),
                nvgRGBA(clr[1], clr[2], clr[3], 0))
            nvgBeginPath(nvg)
            nvgCircle(nvg, fx, fy, radius * 3)
            nvgFillPaint(nvg, glowPaint)
            nvgFill(nvg)
            -- 核心
            nvgBeginPath(nvg)
            nvgCircle(nvg, fx, fy, radius)
            nvgFillColor(nvg, nvgRGBA(clr[1], clr[2], clr[3], alpha))
            nvgFill(nvg)

        elseif pType == "bubble" then
            -- 气泡：从底部向上缓缓漂浮
            local bx = l.x + ((seed * 73) % math.floor(l.w))
            local cycleDur = 6.0 + (seed % 40) / 10
            local byProgress = ((t + phase * 2) / cycleDur) % 1.0
            local by = l.y + l.h - byProgress * (l.h + 40) + 20
            bx = bx + math.sin(t * 0.5 + phase) * 12
            local radius = 2 + (seed % 30) / 10
            local alpha = math.floor((0.3 + math.sin(t * 2 + phase) * 0.2) * 180 * (1.0 - byProgress * 0.5))
            alpha = math.max(0, alpha)
            -- 气泡轮廓
            nvgBeginPath(nvg)
            nvgCircle(nvg, bx, by, radius)
            nvgStrokeColor(nvg, nvgRGBA(clr[1], clr[2], clr[3], alpha))
            nvgStrokeWidth(nvg, 1.0)
            nvgStroke(nvg)
            -- 高光点
            nvgBeginPath(nvg)
            nvgCircle(nvg, bx - radius * 0.3, by - radius * 0.3, radius * 0.3)
            nvgFillColor(nvg, nvgRGBA(200, 240, 255, math.floor(alpha * 0.6)))
            nvgFill(nvg)

        elseif pType == "ember" then
            -- 火星：从下方飘起，上升时摇曳
            local ex = l.x + ((seed * 73) % math.floor(l.w))
            local cycleDur = 4.0 + (seed % 30) / 10
            local eyProgress = ((t + phase * 2) / cycleDur) % 1.0
            local ey = l.y + l.h - eyProgress * (l.h + 30) + 15
            ex = ex + math.sin(t * 1.2 + phase) * 8
            local radius = 1.0 + (seed % 20) / 10
            local alpha = math.floor((0.5 + math.sin(t * 3 + phase) * 0.3) * 200 * (1.0 - eyProgress * 0.7))
            alpha = math.max(0, alpha)
            -- 火星光晕
            local emberPaint = nvgRadialGradient(nvg, ex, ey, 0, radius * 2.5,
                nvgRGBA(clr[1], clr[2], clr[3], alpha),
                nvgRGBA(clr[1], clr[2], clr[3], 0))
            nvgBeginPath(nvg)
            nvgCircle(nvg, ex, ey, radius * 2.5)
            nvgFillPaint(nvg, emberPaint)
            nvgFill(nvg)
            -- 核心亮点
            nvgBeginPath(nvg)
            nvgCircle(nvg, ex, ey, radius)
            nvgFillColor(nvg, nvgRGBA(255, 220, 150, alpha))
            nvgFill(nvg)

        elseif pType == "aurora" then
            -- 极光粒子：缓慢漂移的彩虹色光点
            local ax = l.x + ((seed * 73) % math.floor(l.w))
            local ay = l.y + ((seed * 41) % math.floor(l.h))
            ax = ax + math.sin(t * 0.25 + phase) * 30
            ay = ay + math.cos(t * 0.35 + phase * 0.7) * 20
            local glow = math.sin(t * 1.0 + phase) * 0.5 + 0.5
            -- 彩虹色相随时间和位置偏移
            local hue = (t * 0.15 + i * 0.3) % 1.0
            local hr, hg, hb = 0, 0, 0
            local h6 = hue * 6
            if h6 < 1 then     hr, hg, hb = 255, math.floor(h6 * 255), 100
            elseif h6 < 2 then hr, hg, hb = math.floor((2 - h6) * 255), 255, 100
            elseif h6 < 3 then hr, hg, hb = 100, 255, math.floor((h6 - 2) * 255)
            elseif h6 < 4 then hr, hg, hb = 100, math.floor((4 - h6) * 255), 255
            elseif h6 < 5 then hr, hg, hb = math.floor((h6 - 4) * 200 + 55), 100, 255
            else               hr, hg, hb = 255, 100, math.floor((6 - h6) * 255)
            end
            local alpha = math.floor(20 + glow * 60)
            local radius = 2 + glow * 3
            -- 外发光
            local aurPaint = nvgRadialGradient(nvg, ax, ay, 0, radius * 4,
                nvgRGBA(hr, hg, hb, math.floor(alpha * 0.3)),
                nvgRGBA(hr, hg, hb, 0))
            nvgBeginPath(nvg)
            nvgCircle(nvg, ax, ay, radius * 4)
            nvgFillPaint(nvg, aurPaint)
            nvgFill(nvg)
            -- 核心
            nvgBeginPath(nvg)
            nvgCircle(nvg, ax, ay, radius)
            nvgFillColor(nvg, nvgRGBA(hr, hg, hb, alpha))
            nvgFill(nvg)
        end
    end

    local board = G.battle.board
    local hexSize = G.gridParams.hexSize

    -- 屏幕震动偏移
    local shakeX, shakeY = 0, 0
    if G.battle.screenShake and G.battle.screenShake > 0 then
        local intensity = G.battle.screenShake * 12
        shakeX = math.random() * intensity * 2 - intensity
        shakeY = math.random() * intensity * 2 - intensity
    end

    local ox = G.gridParams.offsetX + l.x + shakeX - G.cameraX
    local oy = G.gridParams.offsetY + l.y + shakeY - G.cameraY

    -- 填充子模块渲染上下文
    _ctx.nvg=nvg; _ctx.hexSize=hexSize; _ctx.ox=ox; _ctx.oy=oy; _ctx.t=t; _ctx.l=l
    _ctx.theme=theme; _ctx.shakeX=shakeX; _ctx.shakeY=shakeY

    -- 0.5 Boss肖像背景（半透明大图悬浮在棋盘上方）
    if Battle.IsBossLevel(G.battle.level) then
        -- 懒加载Boss肖像纹理（检查bossKey是否变化以支持跨章节切换）
        local chapter = math.ceil(G.battle.level / Battle.LEVELS_PER_CHAPTER)
        local CHAPTER_BOSS_MAP = { [1] = "abyss_kraken", [2] = "lava_lord", [3] = "coral_guardian", [4] = "sand_worm" }
        local bossKey = CHAPTER_BOSS_MAP[chapter]
        if bossKey ~= self.bossKey_ then
            -- Boss 变了，清除旧肖像
            if self.bossImageHandle_ then
                nvgDeleteImage(nvg, self.bossImageHandle_)
                self.bossImageHandle_ = nil
                self.bossKey_ = nil
            end
        end
        if not self.bossImageHandle_ then
            if bossKey and Battle.BOSS_PORTRAITS[bossKey] then
                self.bossImageHandle_ = nvgCreateImage(nvg, Battle.BOSS_PORTRAITS[bossKey], 0)
                self.bossKey_ = bossKey
            end
        end

        if self.bossImageHandle_ and self.bossImageHandle_ > 0 then
            -- 在棋盘上方大面积绘制Boss肖像，占满棋盘上方空间
            -- 棋盘第一行中心位置（作为参考）
            local topRowCY = oy + hexSize  -- 第一行大致 y 位置

            -- 肖像宽度接近棋盘宽度，高度自适应（正方形原图）
            local portraitW = hexSize * 8.5   -- 宽度约覆盖棋盘80%
            local portraitH = portraitW        -- 正方形原图保持比例
            local portraitX = l.x + l.w / 2 - portraitW / 2
            -- 底部对齐到棋盘上方，让Boss身体悬浮在棋盘之上
            local portraitY = topRowCY - portraitH * 0.75 - G.cameraY

            -- 脉动效果（Boss存活时呼吸，Boss死后淡出）
            local bossAlive = false
            local bossEnraged = false
            local enemies = HexGrid.GetTeamPieces(board, "enemy")
            for _, e in ipairs(enemies) do
                if e.isBoss and e.hp > 0 then
                    bossAlive = true
                    bossEnraged = e.enraged or false
                    break
                end
            end

            local breathPulse = math.sin((G.time or 0) * 1.5) * 0.04 + 0.98  -- 大图呼吸幅度减小
            local baseAlpha = bossAlive and 0.55 or 0.15  -- 存活时稍亮一些
            local alphaVal = baseAlpha * breathPulse

            -- 狂暴时红色调，正常时原色半透明
            local tintR, tintG, tintB = 255, 255, 255
            if bossEnraged then
                local ragePulse = math.sin((G.time or 0) * 4.0) * 0.3 + 0.7
                tintR = 255
                tintG = math.floor(120 * ragePulse)
                tintB = math.floor(100 * ragePulse)
                alphaVal = alphaVal * 1.2  -- 狂暴时稍微亮一些
            end

            local drawW = portraitW * breathPulse
            local drawH = portraitH * breathPulse
            local drawX = portraitX + (portraitW - drawW) / 2
            local drawY = portraitY + (portraitH - drawH) / 2

            -- 绘制大范围暗色渐变底衬（增加Boss压迫感）
            local vigCX = drawX + drawW / 2
            local vigCY = drawY + drawH / 2
            local vigR = math.max(drawW, drawH) * 0.55
            local vigPaint = nvgRadialGradient(nvg, vigCX, vigCY, vigR * 0.15, vigR,
                nvgRGBA(tintR, tintG, tintB, math.floor(50 * alphaVal)),
                nvgRGBA(0, 0, 0, 0))
            nvgBeginPath(nvg)
            nvgCircle(nvg, vigCX, vigCY, vigR)
            nvgFillPaint(nvg, vigPaint)
            nvgFill(nvg)

            -- 绘制Boss肖像（半透明，底部渐隐融入棋盘）
            -- 先绘制完整肖像
            local imgPaint = nvgImagePatternTinted(nvg,
                drawX, drawY, drawW, drawH,
                0, self.bossImageHandle_,
                nvgRGBA(tintR, tintG, tintB, math.floor(255 * alphaVal)))
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, drawX, drawY, drawW, drawH, drawW * 0.06)
            nvgFillPaint(nvg, imgPaint)
            nvgFill(nvg)

            -- 底部渐隐遮罩：让Boss下半身自然融入棋盘背景
            local fadeH = drawH * 0.35
            local fadeY = drawY + drawH - fadeH
            local fadePaint = nvgLinearGradient(nvg,
                drawX, fadeY,
                drawX, drawY + drawH,
                nvgRGBA(0, 0, 0, 0),
                nvgRGBA(30, 35, 50, math.floor(255 * alphaVal)))  -- 与背景色融合
            nvgBeginPath(nvg)
            nvgRect(nvg, drawX, fadeY, drawW, fadeH)
            nvgFillPaint(nvg, fadePaint)
            nvgFill(nvg)
        end
    else
        -- 非Boss关清理纹理句柄
        if self.bossImageHandle_ then
            nvgDeleteImage(nvg, self.bossImageHandle_)
            self.bossImageHandle_ = nil
            self.bossKey_ = nil
        end
    end

    -- === 0.9 棋盘边框辉光 ===
    do
        local gp = G.gridParams
        local pad = hexSize * 0.6
        local bx = gp.offsetX + l.x - pad + shakeX - G.cameraX
        local by = gp.offsetY + l.y - pad + shakeY - G.cameraY
        local bw = gp.totalW + pad * 2
        local bh = gp.totalH + pad * 2
        local fc = theme.frameClr
        local framePulse = math.sin(t * 1.2) * 0.25 + 0.75
        local frameA = math.floor(50 * framePulse)
        local cornerR = hexSize * 0.8
        -- 外层辉光（大范围柔光）
        local outerPad = hexSize * 0.5
        local glowPaint = nvgBoxGradient(nvg,
            bx - outerPad, by - outerPad, bw + outerPad * 2, bh + outerPad * 2,
            cornerR + outerPad, hexSize * 1.5,
            nvgRGBA(fc[1], fc[2], fc[3], frameA),
            nvgRGBA(fc[1], fc[2], fc[3], 0))
        nvgBeginPath(nvg)
        nvgRect(nvg, bx - outerPad * 2, by - outerPad * 2,
            bw + outerPad * 4, bh + outerPad * 4)
        nvgFillPaint(nvg, glowPaint)
        nvgFill(nvg)
        -- 内层描边已移除（避免产生可见白线）
    end

    -- 1. 绘制所有六角格（章节主题色 + 内发光）
    local hf = theme.hexFill
    local hs = theme.hexStroke
    local hg = theme.hexGlow
    for r = 1, HexGrid.ROWS do
        for c = 1, HexGrid.COLS do
            if HexGrid.InBounds(c, r) then
                local cx, cy = HexGrid.HexToPixel(c, r, hexSize, ox, oy)
                -- 微妙的距离中心渐变：越靠近边缘越暗
                local dist = HexGrid.CubeDistance(c, r, HexGrid.CENTER_COL, HexGrid.CENTER_ROW)
                local maxDist = HexGrid.boardShape == "hexagram" and (HexGrid.RADIUS * 2 + 1) or (HexGrid.RADIUS + 1)
                local edgeDim = 1.0 - dist / maxDist * 0.3
                local fillR = math.floor(hf[1] * edgeDim)
                local fillG = math.floor(hf[2] * edgeDim)
                local fillB = math.floor(hf[3] * edgeDim)
                local fillA = hf[4]
                -- 六芒星臂部着色: 3种玩家颜色（低饱和度紫色调变体）
                if HexGrid.boardShape == "hexagram" then
                    local armPlayer = HexGrid.GetArmPlayer(c, r)
                    if armPlayer == 1 then
                        -- 玫红方 (臂1+4) — 低饱和暗玫红
                        fillR = math.floor(100 * edgeDim)
                        fillG = math.floor(45 * edgeDim)
                        fillB = math.floor(70 * edgeDim)
                    elseif armPlayer == 2 then
                        -- 青蓝方 (臂2+5) — 低饱和暗青蓝
                        fillR = math.floor(45 * edgeDim)
                        fillG = math.floor(75 * edgeDim)
                        fillB = math.floor(95 * edgeDim)
                    elseif armPlayer == 3 then
                        -- 琥珀方 (臂3+6) — 低饱和暗琥珀
                        fillR = math.floor(95 * edgeDim)
                        fillG = math.floor(80 * edgeDim)
                        fillB = math.floor(55 * edgeDim)
                    end
                end
                local strokeA = math.floor(hs[4] * edgeDim)
                HexGrid.DrawHex(nvg, cx, cy, hexSize * 0.90,
                    nvgRGBA(fillR, fillG, fillB, fillA), nvgRGBA(hs[1], hs[2], hs[3], strokeA))
                -- 每个格子中心微弱内发光（营造宝石感）
                local glowPulse = math.sin(t * 1.2 + c * 0.5 + r * 0.7) * 0.3 + 0.7
                -- 无尽模式背景极深，内发光加强以增加格子层次感
                local baseGlowAlpha = (G.battle and G.battle.isEndless) and 30 or 15
                local innerGlowA = math.floor(baseGlowAlpha * glowPulse * edgeDim)
                local innerPaint = nvgRadialGradient(nvg, cx, cy, 0, hexSize * 0.5,
                    nvgRGBA(hg[1], hg[2], hg[3], innerGlowA),
                    nvgRGBA(hg[1], hg[2], hg[3], 0))
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, hexSize * 0.5)
                nvgFillPaint(nvg, innerPaint)
                nvgFill(nvg)

                -- 主题装饰纹路
                if pType == "firefly" and (c + r) % 3 == 0 then
                    -- 森林：角落小藤蔓弧线
                    local vineA = math.floor(25 * edgeDim)
                    nvgBeginPath(nvg)
                    local va = t * 0.2 + c * 1.1
                    nvgMoveTo(nvg, cx - hexSize * 0.3, cy + hexSize * 0.2)
                    nvgQuadTo(nvg, cx + math.sin(va) * hexSize * 0.1, cy,
                              cx + hexSize * 0.3, cy - hexSize * 0.25)
                    nvgStrokeColor(nvg, nvgRGBA(40, 120, 50, vineA))
                    nvgStrokeWidth(nvg, 1.2)
                    nvgStroke(nvg)
                elseif pType == "bubble" and (c + r) % 4 == 0 then
                    -- 海洋：微弱水波纹圈
                    local wavePhase = t * 0.6 + c * 0.8 + r * 0.3
                    local waveR = hexSize * 0.2 + math.sin(wavePhase) * hexSize * 0.08
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, cx, cy, waveR)
                    nvgStrokeColor(nvg, nvgRGBA(60, 140, 200, math.floor(20 * edgeDim)))
                    nvgStrokeWidth(nvg, 0.8)
                    nvgStroke(nvg)
                elseif pType == "ember" and (c + r) % 3 == 1 then
                    -- 火山：裂缝线
                    local crackA = math.floor(35 * edgeDim)
                    local crackPulse = math.sin(t * 0.8 + c * 1.5) * 0.4 + 0.6
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, cx - hexSize * 0.2, cy - hexSize * 0.15)
                    nvgLineTo(nvg, cx + hexSize * 0.05, cy + hexSize * 0.05)
                    nvgLineTo(nvg, cx + hexSize * 0.25, cy + hexSize * 0.2)
                    nvgStrokeColor(nvg, nvgRGBA(255, 120, 30, math.floor(crackA * crackPulse)))
                    nvgStrokeWidth(nvg, 1.0)
                    nvgStroke(nvg)
                elseif pType == "aurora" then
                    -- 流沙荒漠：流光溢彩渐变光效
                    -- 每个格子一个缓慢漂移的彩虹色光斑
                    local auroraPhase = t * 0.4 + c * 0.7 + r * 1.1
                    local hue = (auroraPhase * 0.1) % 1.0
                    local ar, ag, ab = 0, 0, 0
                    local h6 = hue * 6
                    if h6 < 1 then     ar, ag, ab = 200, math.floor(100 + h6 * 100), 180
                    elseif h6 < 2 then ar, ag, ab = math.floor(200 - (h6-1) * 80), 200, 180
                    elseif h6 < 3 then ar, ag, ab = 120, 200, math.floor(180 + (h6-2) * 60)
                    elseif h6 < 4 then ar, ag, ab = 120, math.floor(200 - (h6-3) * 60), 240
                    elseif h6 < 5 then ar, ag, ab = math.floor(120 + (h6-4) * 80), 140, 240
                    else               ar, ag, ab = 200, 140, math.floor(240 - (h6-5) * 60)
                    end
                    local auroraGlow = math.sin(auroraPhase) * 0.4 + 0.6
                    local auroraA = math.floor(22 * auroraGlow * edgeDim)
                    -- 偏心渐变光斑（模拟流光移动）
                    local spotOx = math.sin(auroraPhase * 0.7) * hexSize * 0.25
                    local spotOy = math.cos(auroraPhase * 0.5) * hexSize * 0.25
                    local aurPaint = nvgRadialGradient(nvg,
                        cx + spotOx, cy + spotOy, 0, hexSize * 0.55,
                        nvgRGBA(ar, ag, ab, auroraA),
                        nvgRGBA(ar, ag, ab, 0))
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, cx + spotOx, cy + spotOy, hexSize * 0.55)
                    nvgFillPaint(nvg, aurPaint)
                    nvgFill(nvg)
                    -- 边缘流光描边（微弱虹彩边线）
                    if (c + r) % 2 == 0 then
                        local edgeHue = (hue + 0.3) % 1.0
                        local eh6 = edgeHue * 6
                        local er, eg, eb = 0, 0, 0
                        if eh6 < 1 then     er, eg, eb = 180, math.floor(100 + eh6 * 80), 160
                        elseif eh6 < 2 then er, eg, eb = math.floor(180 - (eh6-1) * 60), 180, 160
                        elseif eh6 < 3 then er, eg, eb = 120, 180, math.floor(160 + (eh6-2) * 50)
                        elseif eh6 < 4 then er, eg, eb = 120, math.floor(180 - (eh6-3) * 50), 210
                        elseif eh6 < 5 then er, eg, eb = math.floor(120 + (eh6-4) * 60), 130, 210
                        else               er, eg, eb = 180, 130, math.floor(210 - (eh6-5) * 50)
                        end
                        local edgeA = math.floor(12 * auroraGlow * edgeDim)
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, cx, cy, hexSize * 0.85)
                        nvgStrokeColor(nvg, nvgRGBA(er, eg, eb, edgeA))
                        nvgStrokeWidth(nvg, 1.2)
                        nvgStroke(nvg)
                    end
                end
            end
        end
    end

    -- === 1.45 底部/侧面剪影装饰 ===
    do
        local sc = theme.silClr
        local sType = theme.silType
        local baseY = l.y + l.h  -- 屏幕底部
        if sType == "seaweed" then
            -- 深渊海沟：海草从底部伸出，轻微摇曳
            for si = 1, 8 do
                local seed = si * 47
                local sx = l.x + (seed * 73 % math.floor(l.w))
                local sway = math.sin(t * 0.6 + si * 0.9) * 8
                local h = 40 + (seed % 50)
                nvgBeginPath(nvg)
                nvgMoveTo(nvg, sx, baseY)
                nvgBezierTo(nvg,
                    sx + sway * 0.3, baseY - h * 0.33,
                    sx + sway * 0.7, baseY - h * 0.66,
                    sx + sway, baseY - h)
                nvgBezierTo(nvg,
                    sx + sway + 4, baseY - h * 0.66,
                    sx + sway * 0.5 + 6, baseY - h * 0.33,
                    sx + 8, baseY)
                nvgClosePath(nvg)
                nvgFillColor(nvg, nvgRGBA(sc[1], sc[2], sc[3], sc[4]))
                nvgFill(nvg)
            end
            -- 两侧岩壁暗影
            for side = 0, 1 do
                local wallX = side == 0 and l.x or (l.x + l.w)
                local dir = side == 0 and 1 or -1
                local wallW = 25
                local wp = nvgLinearGradient(nvg, wallX, l.y,
                    wallX + dir * wallW, l.y,
                    nvgRGBA(sc[1], sc[2], sc[3], sc[4]),
                    nvgRGBA(sc[1], sc[2], sc[3], 0))
                nvgBeginPath(nvg)
                nvgRect(nvg, side == 0 and wallX or (wallX - wallW), l.y, wallW, l.h)
                nvgFillPaint(nvg, wp)
                nvgFill(nvg)
            end
        elseif sType == "rocks" then
            -- 烈焰山脉：底部尖锐岩石剪影
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, l.x, baseY)
            local rockCount = 12
            for si = 0, rockCount do
                local rx = l.x + (si / rockCount) * l.w
                local seed = si * 31 + 7
                local rh = 20 + (seed % 45)
                local rPeak = rx + (seed % 15) - 7
                if si % 2 == 0 then
                    nvgLineTo(nvg, rPeak, baseY - rh)
                else
                    nvgLineTo(nvg, rx, baseY - 5 - (seed % 10))
                end
            end
            nvgLineTo(nvg, l.x + l.w, baseY)
            nvgClosePath(nvg)
            nvgFillColor(nvg, nvgRGBA(sc[1], sc[2], sc[3], sc[4]))
            nvgFill(nvg)
            -- 熔岩反光条
            nvgBeginPath(nvg)
            nvgRect(nvg, l.x, baseY - 3, l.w, 3)
            nvgFillColor(nvg, nvgRGBA(255, 80, 20, math.floor(40 + math.sin(t * 2) * 20)))
            nvgFill(nvg)
        elseif sType == "coral" then
            -- 珊瑚迷宫：底部珊瑚丛剪影
            for si = 1, 10 do
                local seed = si * 53
                local cx = l.x + (seed * 67 % math.floor(l.w))
                local ch = 25 + (seed % 40)
                local cw = 12 + (seed % 18)
                local sway = math.sin(t * 0.4 + si * 1.3) * 3
                -- 珊瑚主干
                nvgBeginPath(nvg)
                nvgMoveTo(nvg, cx, baseY)
                nvgLineTo(nvg, cx - cw * 0.3, baseY - ch * 0.5)
                nvgBezierTo(nvg,
                    cx - cw * 0.1 + sway, baseY - ch * 0.8,
                    cx + sway, baseY - ch,
                    cx + cw * 0.2 + sway, baseY - ch * 0.7)
                nvgLineTo(nvg, cx + cw * 0.4, baseY - ch * 0.4)
                nvgLineTo(nvg, cx + cw * 0.3, baseY)
                nvgClosePath(nvg)
                nvgFillColor(nvg, nvgRGBA(sc[1], sc[2], sc[3], sc[4]))
                nvgFill(nvg)
                -- 小分枝
                if si % 3 == 0 then
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, cx + sway + cw * 0.1, baseY - ch * 0.9, cw * 0.15)
                    nvgFillColor(nvg, nvgRGBA(sc[1] + 10, sc[2] + 15, sc[3] + 10, math.floor(sc[4] * 0.7)))
                    nvgFill(nvg)
                end
            end
            -- 两侧海藻渐变
            for side = 0, 1 do
                local wallX = side == 0 and l.x or (l.x + l.w)
                local dir = side == 0 and 1 or -1
                local wallW = 20
                local wp = nvgLinearGradient(nvg, wallX, l.y,
                    wallX + dir * wallW, l.y,
                    nvgRGBA(sc[1], sc[2], sc[3], math.floor(sc[4] * 0.8)),
                    nvgRGBA(sc[1], sc[2], sc[3], 0))
                nvgBeginPath(nvg)
                nvgRect(nvg, side == 0 and wallX or (wallX - wallW), l.y, wallW, l.h)
                nvgFillPaint(nvg, wp)
                nvgFill(nvg)
            end
        end
    end

    -- 1.5 绘制毒雾/岩浆格子
    for _, poison in ipairs(board.poisonTiles) do
        local cx, cy = HexGrid.HexToPixel(poison.col, poison.row, hexSize, ox, oy)
        if not IsCellOnScreen(cx, cy, hexSize, l.x, l.y, l.w, l.h) then goto cull_poison end
        do
        if poison.isLava then
            -- ═══ 岩浆地形：大小岩浆块 + 气泡 + 热浪 ═══
            local t = G.time or 0
            local seed = poison.col * 17 + poison.row * 31
            local lavaPulse = math.sin(t * 2.0 + seed * 0.3) * 0.3 + 0.7

            -- 底层：暗红熔岩底色（六角形）
            HexGrid.DrawHex(nvg, cx, cy, hexSize * 0.88,
                nvgRGBA(120, 20, 5, math.floor(90 * lavaPulse)),
                nvgRGBA(180, 50, 10, math.floor(170 * lavaPulse)))

            -- 中层：流动的岩浆纹路（大块岩浆，2-3块）
            for li = 1, 3 do
                local lSeed = seed + li * 53
                local lAngle = (lSeed % 628) / 100.0 + t * 0.3 * (li % 2 == 0 and 1 or -1)
                local lDist = hexSize * (0.1 + (lSeed % 30) / 100.0)
                local lx = cx + math.cos(lAngle) * lDist
                local ly = cy + math.sin(lAngle) * lDist * 0.7
                local lSize = hexSize * (0.2 + (lSeed % 20) / 80.0)
                local lPulse = math.sin(t * 1.5 + lSeed * 0.5) * 0.3 + 0.7
                nvgBeginPath(nvg)
                nvgEllipse(nvg, lx, ly, lSize, lSize * 0.65)
                nvgFillPaint(nvg, nvgRadialGradient(nvg,
                    lx, ly, 0, lSize,
                    nvgRGBA(255, 180, 40, math.floor(180 * lPulse)),
                    nvgRGBA(255, 80, 10, 0)))
                nvgFill(nvg)
            end

            -- 小块岩浆碎片（4-5颗，更亮更快闪烁）
            for si = 1, 5 do
                local sSeed = seed + si * 97
                local sAngle = (sSeed % 628) / 100.0 + t * 0.8 * (si % 2 == 0 and -1 or 1)
                local sDist = hexSize * (0.25 + (sSeed % 25) / 80.0)
                local sx = cx + math.cos(sAngle) * sDist
                local sy = cy + math.sin(sAngle) * sDist * 0.6
                local sFlicker = math.sin(t * 4.0 + sSeed) * 0.4 + 0.6
                local sSize = hexSize * (0.06 + (sSeed % 10) / 200.0)
                nvgBeginPath(nvg)
                nvgCircle(nvg, sx, sy, sSize)
                nvgFillColor(nvg, nvgRGBA(255, 220, 80, math.floor(200 * sFlicker)))
                nvgFill(nvg)
            end

            -- 气泡上浮效果（2-3个气泡循环冒出）
            for bi = 1, 3 do
                local bSeed = seed + bi * 41
                local bCycle = (t * 0.7 + bSeed * 0.1) % 2.0  -- 2秒循环
                if bCycle < 1.2 then
                    local bProgress = bCycle / 1.2
                    local bx = cx + (((bSeed % 50) - 25) / 25.0) * hexSize * 0.3
                    local by = cy + hexSize * 0.2 - bProgress * hexSize * 0.5
                    local bSize = hexSize * (0.03 + bProgress * 0.04) * (1.0 - bProgress * 0.5)
                    local bAlpha = math.floor((1.0 - bProgress) * 180)
                    if bAlpha > 10 then
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, bx, by, bSize)
                        nvgFillColor(nvg, nvgRGBA(255, 200, 100, bAlpha))
                        nvgFill(nvg)
                    end
                end
            end

            -- 热浪扭曲光环
            local heatR = hexSize * (0.6 + math.sin(t * 1.5 + seed) * 0.1)
            local heatA = math.floor(30 + math.sin(t * 2.5 + seed * 0.7) * 15)
            nvgBeginPath(nvg)
            nvgCircle(nvg, cx, cy - hexSize * 0.05, heatR)
            nvgStrokeColor(nvg, nvgRGBA(255, 120, 30, heatA))
            nvgStrokeWidth(nvg, 1.5)
            nvgStroke(nvg)

            -- 图标
            IconAtlas.DrawNVG(nvg, "board_lava", cx, cy - hexSize * 0.06, hexSize * 0.4)
            -- 回合数
            nvgFontSize(nvg, hexSize * 0.22)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            nvgFillColor(nvg, nvgRGBA(255, 180, 60, 220))
            nvgText(nvg, cx, cy + hexSize * 0.12, tostring(poison.turns))
        else
            -- 毒雾底色（脉动）
            local t = G.time or 0
            local poisonPulse = math.sin(t * 1.8 + poison.col * 1.1 + poison.row * 0.7) * 0.25 + 0.75
            HexGrid.DrawHex(nvg, cx, cy, hexSize * 0.88,
                nvgRGBA(60, 160, 60, math.floor(55 * poisonPulse)),
                nvgRGBA(70, 190, 70, math.floor(130 * poisonPulse)))
            -- 漂浮雾气粒子
            for pi = 1, 5 do
                local seed = poison.col * 7 + poison.row * 13 + pi * 3
                local angle = math.sin(t * 0.6 + seed) * math.pi * 2
                local dist = hexSize * (0.15 + math.sin(t * 0.9 + seed * 0.5) * 0.2)
                local px = cx + math.cos(angle) * dist
                local py = cy + math.sin(angle) * dist * 0.6
                local pAlpha = math.floor((0.3 + math.sin(t * 1.2 + seed * 0.8) * 0.2) * 255)
                local pSize = hexSize * (0.08 + math.sin(t * 0.7 + seed) * 0.03)
                nvgBeginPath(nvg)
                nvgCircle(nvg, px, py, pSize)
                nvgFillColor(nvg, nvgRGBA(80, 200, 80, pAlpha))
                nvgFill(nvg)
            end
            -- 图标
            IconAtlas.DrawNVG(nvg, "board_poison", cx, cy - hexSize * 0.06, hexSize * 0.4)
            -- 回合数
            nvgFontSize(nvg, hexSize * 0.22)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            nvgFillColor(nvg, nvgRGBA(100, 220, 100, 180))
            nvgText(nvg, cx, cy + hexSize * 0.12, tostring(poison.turns))
        end
        end -- do
        ::cull_poison::
    end

    -- 1.55 绘制地刺格（静态三角尖刺）
    local spikeTraps = G.battle and G.battle._spikeTraps or {}
    for _, spike in ipairs(spikeTraps) do
        local cx, cy = HexGrid.HexToPixel(spike.col, spike.row, hexSize, ox, oy)
        if not IsCellOnScreen(cx, cy, hexSize, l.x, l.y, l.w, l.h) then goto cull_spike end
        do
        -- 无底色/无边框：仅绘制尖刺图标本身（避免与"可跳格子"的红色高亮混淆）
        -- 3根向上三角尖刺（带发光感的红色）
        local spikeH = hexSize * 0.46
        local spikeW = hexSize * 0.16
        local offsets = {-0.25, 0, 0.25}
        local heights = {0.8, 1.0, 0.8}  -- 中间最高
        local pulse = 0.85 + 0.15 * math.sin((G.time or 0) * 3.0)  -- 微呼吸
        for i = 1, 3 do
            local bx = cx + offsets[i] * hexSize
            local by = cy + hexSize * 0.14
            local h = spikeH * heights[i] * pulse
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, bx, by - h)         -- 尖端
            nvgLineTo(nvg, bx - spikeW, by)    -- 左底
            nvgLineTo(nvg, bx + spikeW, by)    -- 右底
            nvgClosePath(nvg)
            -- 尖刺渐变：尖端亮橙 → 底部暗红
            local spikePaint = nvgLinearGradient(nvg, bx, by - h, bx, by,
                nvgRGBA(255, 160, 60, 250), nvgRGBA(200, 40, 30, 240))
            nvgFillPaint(nvg, spikePaint)
            nvgFill(nvg)
            nvgStrokeColor(nvg, nvgRGBA(255, 200, 120, math.floor(160 * pulse)))
            nvgStrokeWidth(nvg, 1.2)
            nvgStroke(nvg)
        end
        -- 剩余回合数（暗底描边 + 亮色数字）
        nvgFontSize(nvg, hexSize * 0.36)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(0, 0, 0, 200))
        nvgText(nvg, cx + 1, cy - hexSize * 0.24 + 1, tostring(spike.turns))
        nvgFillColor(nvg, nvgRGBA(255, 220, 180, 255))
        nvgText(nvg, cx, cy - hexSize * 0.24, tostring(spike.turns))
        end -- do
        ::cull_spike::
    end

    -- 1.56 绘制霜冻格（动态冰霜粒子效果）
    local gt = G.time or 0
    for _, frost in ipairs(board.frostTiles or {}) do
        local cx, cy = HexGrid.HexToPixel(frost.col, frost.row, hexSize, ox, oy)
        if not IsCellOnScreen(cx, cy, hexSize, l.x, l.y, l.w, l.h) then goto cull_frost end
        do
        local isPoisoned = frost.hasPoison
        -- 每格用固定种子产生伪随机偏移
        local seed = frost.col * 7 + frost.row * 13

        -- 呼吸脉冲光晕
        local pulse = math.sin(gt * 2.0 + seed * 0.5) * 0.15 + 0.85
        local fillAlpha = math.floor((isPoisoned and 80 or 45) * pulse)
        local borderAlpha = math.floor((isPoisoned and 180 or 130) * pulse)
        HexGrid.DrawHex(nvg, cx, cy, hexSize * 0.88,
            nvgRGBA(210, 235, 255, fillAlpha), nvgRGBA(170, 210, 240, borderAlpha))

        -- 外圈呼吸光环
        local glowR = hexSize * (0.75 + math.sin(gt * 1.5 + seed) * 0.08)
        local glowA = math.floor(30 * pulse)
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, glowR)
        nvgStrokeColor(nvg, nvgRGBA(180, 220, 255, glowA))
        nvgStrokeWidth(nvg, 1.5)
        nvgStroke(nvg)

        -- 冰晶裂纹（微弱闪烁）
        nvgSave(nvg)
        nvgTranslate(nvg, cx, cy)
        for i = 1, 3 do
            local a = (i * 2.09 + seed * 0.3)
            local flicker = math.sin(gt * 3.0 + i * 1.7 + seed) * 0.3 + 0.7
            local len = hexSize * (0.25 + (i % 2) * 0.12)
            local dx, dy = math.cos(a), math.sin(a)
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, -dx * len * 0.3, -dy * len * 0.3)
            nvgLineTo(nvg, dx * len, dy * len)
            local ba = a + 0.5 * (i % 2 == 0 and 1 or -1)
            nvgLineTo(nvg, dx * len + math.cos(ba) * len * 0.3, dy * len + math.sin(ba) * len * 0.3)
            local lineA = math.floor((isPoisoned and 150 or 100) * flicker)
            nvgStrokeColor(nvg, nvgRGBA(200, 230, 255, lineA))
            nvgStrokeWidth(nvg, 1.0)
            nvgStroke(nvg)
        end
        nvgRestore(nvg)

        -- 漂浮冰晶微粒（6颗小粒子绕中心缓慢运动）
        for i = 1, 6 do
            local angle = (i / 6) * math.pi * 2 + gt * (0.4 + (i % 3) * 0.15) + seed
            local dist = hexSize * (0.2 + math.sin(gt * 1.2 + i * 2.1 + seed) * 0.12)
            local px = cx + math.cos(angle) * dist
            local py = cy + math.sin(angle) * dist
            local pSize = hexSize * (0.025 + math.sin(gt * 2.5 + i * 1.3) * 0.01)
            local pAlpha = math.floor(120 + math.sin(gt * 3.0 + i * 0.9) * 60)
            nvgBeginPath(nvg)
            nvgCircle(nvg, px, py, pSize)
            nvgFillColor(nvg, nvgRGBA(200, 230, 255, pAlpha))
            nvgFill(nvg)
        end

        -- 雪花图标（缓慢旋转）
        nvgSave(nvg)
        nvgTranslate(nvg, cx, cy - hexSize * 0.06)
        nvgRotate(nvg, math.sin(gt * 0.8 + seed) * 0.3)
        IconAtlas.DrawNVG(nvg, "board_frost", 0, 0, hexSize * 0.4)
        nvgRestore(nvg)

        -- 回合数文字
        nvgFontSize(nvg, hexSize * 0.22)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(nvg, nvgRGBA(180, 210, 240, 220))
        nvgText(nvg, cx, cy + hexSize * 0.12, tostring(frost.turns))
        end -- do
        ::cull_frost::
    end

    -- 1.57 绘制流沙区（第四章简化版：zone 覆盖中心+6邻居=7格）
    for _, zone in ipairs(board.quicksandZones or {}) do
        -- 收集 zone 内所有格子（中心 + 邻居）
        local zoneTiles = {{ col = zone.col, row = zone.row }}
        local neighbors = HexGrid.GetNeighbors(zone.col, zone.row)
        for _, n in ipairs(neighbors) do
            zoneTiles[#zoneTiles + 1] = n
        end
        local gt = G.time or 0
        -- 懒初始化 spawnTime（HexGrid 中无法访问 G.time）
        if zone.spawnTime < 0 then zone.spawnTime = gt end
        -- 淡入动画：生成后 0.6 秒内逐渐显现
        local spawnElapsed = gt - zone.spawnTime
        local fadeIn = math.min(1.0, spawnElapsed / 0.6)
        -- 淡出动画：timer==1 时逐渐消散
        local fadeOut = (zone.timer == 1) and math.max(0.3, 0.7 + 0.3 * math.sin(gt * 4)) or 1.0
        local alphaFactor = fadeIn * fadeOut
        for ti, tile in ipairs(zoneTiles) do
            local cx, cy = HexGrid.HexToPixel(tile.col, tile.row, hexSize, ox, oy)
            if IsCellOnScreen(cx, cy, hexSize, l.x, l.y, l.w, l.h) then
                local seed = tile.col * 2.3 + tile.row * 3.7
                -- 生成动画：扩展缩放
                local scaleAnim = fadeIn < 1.0 and (0.5 + 0.5 * fadeIn) or 1.0
                local drawSize = hexSize * 0.88 * scaleAnim
                -- 琥珀色流沙底
                local baseAlpha = math.floor(160 * alphaFactor)
                local borderAlpha = math.floor(120 * alphaFactor)
                HexGrid.DrawHex(nvg, cx, cy, drawSize,
                    nvgRGBA(160, 120, 40, baseAlpha), nvgRGBA(200, 160, 60, borderAlpha))
                -- 沙面漩涡渐变
                local vortGlow = nvgRadialGradient(nvg, cx, cy, 0, hexSize * 0.45 * scaleAnim,
                    nvgRGBA(180, 140, 50, math.floor(100 * alphaFactor)),
                    nvgRGBA(120, 80, 20, 0))
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, hexSize * 0.45 * scaleAnim)
                nvgFillPaint(nvg, vortGlow)
                nvgFill(nvg)
                -- 旋转沙粒（3颗）
                for i = 1, 3 do
                    local angle = (gt * 0.6 + seed + i * 2.094) % 6.2832
                    local dist = hexSize * (0.18 + 0.1 * math.sin(gt * 1.2 + i)) * scaleAnim
                    local sx = cx + math.cos(angle) * dist
                    local sy = cy + math.sin(angle) * dist
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, sx, sy, 1.8)
                    nvgFillColor(nvg, nvgRGBA(220, 180, 80, math.floor(140 * alphaFactor)))
                    nvgFill(nvg)
                end
                -- 仅在中心格显示倒计时（大号 + 描边 + 脉冲）
                if ti == 1 then
                    local pulse = 1.0 + 0.08 * math.sin(gt * 3.5)
                    local fontSize = hexSize * 0.55 * pulse
                    nvgFontSize(nvg, fontSize)
                    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    -- 深色描边
                    nvgFontBlur(nvg, 3)
                    nvgFillColor(nvg, nvgRGBA(60, 30, 0, math.floor(220 * alphaFactor)))
                    nvgText(nvg, cx, cy, tostring(zone.timer or ""))
                    -- 亮色正文
                    nvgFontBlur(nvg, 0)
                    nvgFillColor(nvg, nvgRGBA(255, 230, 100, math.floor(255 * alphaFactor)))
                    nvgText(nvg, cx, cy, tostring(zone.timer or ""))
                end
            end
        end
    end

    -- 1.58 绘制停沙格（青蓝色特殊格子，踩上消除全场流沙）
    if board.sandStopTile then
        local st = board.sandStopTile
        local cx, cy = HexGrid.HexToPixel(st.col, st.row, hexSize, ox, oy)
        if IsCellOnScreen(cx, cy, hexSize, l.x, l.y, l.w, l.h) then
            local gt = G.time or 0
            local pulse = 0.85 + 0.15 * math.sin(gt * 3.0)
            local drawSize = hexSize * 0.82 * pulse
            -- 青蓝色底色（与流沙琥珀色形成对比）
            HexGrid.DrawHex(nvg, cx, cy, drawSize,
                nvgRGBA(60, 180, 220, 180), nvgRGBA(80, 220, 255, 140))
            -- 内部冰晶渐变光
            nvgBeginPath(nvg)
            nvgCircle(nvg, cx, cy, hexSize * 0.4 * pulse)
            nvgFillPaint(nvg, nvgRadialGradient(nvg, cx, cy, 0, hexSize * 0.4 * pulse,
                nvgRGBA(150, 240, 255, 160),
                nvgRGBA(60, 160, 200, 0)))
            nvgFill(nvg)
            -- 旋转的小粒子（3个）
            for i = 1, 3 do
                local angle = gt * 1.5 + i * 2.094
                local dist = hexSize * 0.25
                local px = cx + math.cos(angle) * dist
                local py = cy + math.sin(angle) * dist
                nvgBeginPath(nvg)
                nvgCircle(nvg, px, py, 2.5)
                nvgFillColor(nvg, nvgRGBA(180, 255, 255, 200))
                nvgFill(nvg)
            end
            -- 中心图标
            nvgFontSize(nvg, hexSize * 0.5)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFontBlur(nvg, 0)
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, 230))
            nvgText(nvg, cx, cy, "🛑")
            -- 漂浮"停沙"文字（上下浮动，大字+深色描边更醒目）
            local floatY = math.sin(gt * 2.5) * 3.0
            local txtY = cy - hexSize * 0.44 + floatY
            nvgFontSize(nvg, hexSize * 0.38)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFontBlur(nvg, 0)
            -- 深色描边（多方向偏移）
            nvgFillColor(nvg, nvgRGBA(10, 40, 60, 220))
            for _, off in ipairs({{1,1},{-1,1},{1,-1},{-1,-1},{0,2},{0,-2}}) do
                nvgText(nvg, cx + off[1], txtY + off[2], "停沙")
            end
            -- 文字主体（纯白，与青蓝底色对比强烈）
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
            nvgText(nvg, cx, txtY, "停沙")
        end
    end

    -- 1.6 绘制障碍物（岩石 / 触手 / 珊瑚）
    local obsChapter = G.battle and math.ceil((G.battle.level or 1) / Battle.LEVELS_PER_CHAPTER) or 1
    for _, obs in ipairs(board.obstacles) do
        local cx, cy = HexGrid.HexToPixel(obs.col, obs.row, hexSize, ox, oy)
        if not IsCellOnScreen(cx, cy, hexSize, l.x, l.y, l.w, l.h) then goto cull_obs end
        do
        if obs.isTentacle then
            -- 触手障碍：粉紫色触手，清晰突出
            local tt = (G.time or 0)
            local tentSeed = obs.col * 1.7 + obs.row * 2.3

            -- 底部涟漪（粉紫色调）
            for ri = 0, 1 do
                local ripple = (tt * 0.7 + ri * 0.5 + tentSeed * 0.1) % 1.0
                local rippleR = hexSize * 0.3 + ripple * hexSize * 0.6
                local rippleA = math.floor(110 * (1.0 - ripple))
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, rippleR)
                nvgStrokeColor(nvg, nvgRGBA(200, 80, 220, rippleA))
                nvgStrokeWidth(nvg, 2)
                nvgStroke(nvg)
            end

            -- 六角底色（粉紫色，更亮）
            local tentPulse = math.sin(tt * 3.0 + tentSeed) * 0.12 + 0.88
            HexGrid.DrawHex(nvg, cx, cy, hexSize * 0.88 * tentPulse,
                nvgRGBA(60, 15, 80, 200), nvgRGBA(180, 60, 200, 220))

            -- 触手图片（粉色版，下缘渐隐处理）
            local imgHandle = IconAtlas.EnsureImage(nvg, "board_tentacle")
            if imgHandle then
                local tentW = hexSize * 1.4
                local tentH = tentW * 1.8       -- 粉色版比例略宽
                -- 出生动画（前0.8秒：猛烈弹出 + 砸击摇晃）
                if not obs.spawnTime then obs.spawnTime = tt end  -- 首次渲染时补记
                local spawnElapsed = tt - obs.spawnTime
                local spawnDur = 0.8
                local spawnT = math.min(1.0, spawnElapsed / spawnDur) -- 0→1
                local spawnScale, spawnSway, spawnFlash = 1.0, 0, 0
                if spawnT < 1.0 then
                    -- 缩放：弹性过冲 0→1.5→0.85→1.0
                    if spawnT < 0.35 then
                        spawnScale = (spawnT / 0.35) * 1.5
                    elseif spawnT < 0.6 then
                        spawnScale = 1.5 - (spawnT - 0.35) / 0.25 * 0.65
                    else
                        spawnScale = 0.85 + (spawnT - 0.6) / 0.4 * 0.15
                    end
                    -- 攻击性摇晃（快速衰减正弦）
                    local shakeFade = 1.0 - spawnT
                    spawnSway = math.sin(spawnElapsed * 28) * 0.25 * shakeFade
                    -- 闪光脉冲（前半段亮，后半段消退）
                    spawnFlash = math.max(0, 1.0 - spawnT * 2.0)
                end
                -- 蠕动摇晃 + 呼吸缩放（常态动画）
                local tentSway = math.sin(tt * 2.0 + tentSeed) * 0.06 + spawnSway
                local tentScaleAnim = (0.97 + math.sin(tt * 3.0 + tentSeed) * 0.03) * spawnScale
                local tentFloat = math.sin(tt * 1.5 + tentSeed * 0.7) * 1.5
                local drawW = tentW * tentScaleAnim
                local drawH = tentH * tentScaleAnim

                nvgSave(nvg)
                nvgTranslate(nvg, cx, cy + tentFloat)
                nvgRotate(nvg, tentSway)
                -- 下缘对齐格子中心偏下，整体向上延伸
                local imgX = -drawW / 2
                local bottomEdge = hexSize * 0.35
                local imgY = bottomEdge - drawH
                local imgPaint = nvgImagePattern(nvg, imgX, imgY, drawW, drawH, 0, imgHandle, 1.0)
                nvgBeginPath(nvg)
                nvgRect(nvg, imgX, imgY, drawW, drawH)
                nvgFillPaint(nvg, imgPaint)
                nvgFill(nvg)

                -- 出生闪光覆盖层（白紫色闪烁）
                if spawnFlash > 0 then
                    local flashA = math.floor(spawnFlash * 200)
                    nvgBeginPath(nvg)
                    nvgRect(nvg, imgX, imgY, drawW, drawH)
                    nvgFillColor(nvg, nvgRGBA(240, 180, 255, flashA))
                    nvgFill(nvg)
                end

                -- 下缘渐隐遮罩（让触手根部自然融入格子）
                local fadeH = drawH * 0.2
                local fadeY = bottomEdge - fadeH
                nvgBeginPath(nvg)
                nvgRect(nvg, imgX - 2, fadeY, drawW + 4, fadeH + 4)
                nvgFillPaint(nvg, nvgLinearGradient(nvg,
                    imgX, fadeY, imgX, fadeY + fadeH,
                    nvgRGBA(0, 0, 0, 0),
                    nvgRGBA(60, 15, 80, 220)))
                nvgFill(nvg)

                nvgRestore(nvg)

                -- 出生冲击波（出生瞬间扩散圆环）
                if spawnT < 1.0 then
                    local ringR = hexSize * 0.3 + spawnT * hexSize * 0.9
                    local ringA = math.floor((1.0 - spawnT) * 180)
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, cx, cy, ringR)
                    nvgStrokeColor(nvg, nvgRGBA(220, 100, 255, ringA))
                    nvgStrokeWidth(nvg, 3 * (1.0 - spawnT) + 1)
                    nvgStroke(nvg)
                end
            end

            -- 底部发光（粉紫色根部光芒，更亮）
            local baseGlow = nvgRadialGradient(nvg, cx, cy + hexSize * 0.1, 0, hexSize * 0.5,
                nvgRGBA(220, 80, 255, math.floor(80 * tentPulse)),
                nvgRGBA(180, 40, 220, 0))
            nvgBeginPath(nvg)
            nvgCircle(nvg, cx, cy + hexSize * 0.1, hexSize * 0.5)
            nvgFillPaint(nvg, baseGlow)
            nvgFill(nvg)

            -- 剩余回合数
            if obs.turns then
                nvgFontSize(nvg, hexSize * 0.3)
                nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFontBlur(nvg, 4)
                nvgFillColor(nvg, nvgRGBA(255, 120, 255, 180))
                nvgText(nvg, cx, cy + hexSize * 0.42, tostring(obs.turns))
                nvgFontBlur(nvg, 0)
                nvgFillColor(nvg, nvgRGBA(255, 240, 255, 240))
                nvgText(nvg, cx, cy + hexSize * 0.42, tostring(obs.turns))
            end
        elseif obs.isAbyss then
            -- 深渊坍缩：黑洞旋转效果
            local abyssSpin = (G.time or 0) * 1.5 + obs.col * 2.0
            HexGrid.DrawHex(nvg, cx, cy, hexSize * 0.88,
                nvgRGBA(10, 10, 20, 240), nvgRGBA(30, 20, 50, 255))
            -- 旋转吸力线
            for j = 0, 3 do
                local angle = abyssSpin + j * math.pi / 2
                local armR = hexSize * 0.35
                local ax = cx + math.cos(angle) * armR
                local ay = cy + math.sin(angle) * armR
                nvgBeginPath(nvg)
                nvgMoveTo(nvg, cx, cy)
                nvgLineTo(nvg, ax, ay)
                nvgStrokeColor(nvg, nvgRGBA(80, 40, 140, 60))
                nvgStrokeWidth(nvg, 1.5)
                nvgStroke(nvg)
            end
            -- 中心深渊光
            local abyssPaint = nvgRadialGradient(nvg, cx, cy, 0, hexSize * 0.4,
                nvgRGBA(40, 20, 80, 100), nvgRGBA(0, 0, 0, 0))
            nvgBeginPath(nvg)
            nvgCircle(nvg, cx, cy, hexSize * 0.4)
            nvgFillPaint(nvg, abyssPaint)
            nvgFill(nvg)
            IconAtlas.DrawNVG(nvg, "board_abyss", cx, cy, hexSize * 0.55)
        elseif obs.isBoulder then
            -- ── 巨岩碎石：沙黄色碎裂岩块，临时障碍 ──
            local t = G.time or 0
            local rs = hexSize * 0.75
            local wobble = math.sin(t * 1.5 + obs.col * 2.1) * 0.02

            -- 阴影
            nvgBeginPath(nvg)
            nvgCircle(nvg, cx + hexSize * 0.04, cy + hexSize * 0.05, rs * 0.9)
            nvgFillColor(nvg, nvgRGBA(0, 0, 0, 80))
            nvgFill(nvg)

            -- 岩块主体（不规则沙黄色多边形）
            nvgBeginPath(nvg)
            local verts = 6
            for i = 1, verts do
                local angle = (i / verts) * math.pi * 2 - math.pi / 2
                local r = rs * (0.82 + 0.18 * math.sin(i * 2.7 + obs.row))
                local vx = cx + math.cos(angle + wobble) * r
                local vy = cy + math.sin(angle + wobble) * r
                if i == 1 then nvgMoveTo(nvg, vx, vy) else nvgLineTo(nvg, vx, vy) end
            end
            nvgClosePath(nvg)
            local bGrad = nvgLinearGradient(nvg, cx, cy - rs, cx, cy + rs,
                nvgRGBA(180, 145, 80, 255), nvgRGBA(110, 80, 40, 255))
            nvgFillPaint(nvg, bGrad)
            nvgFill(nvg)
            nvgStrokeColor(nvg, nvgRGBA(80, 55, 25, 200))
            nvgStrokeWidth(nvg, 2.0)
            nvgStroke(nvg)

            -- 裂纹（表示即将碎裂）
            for ci = 1, 3 do
                local ca = (ci / 3) * math.pi * 2 + obs.col * 1.3
                local x1 = cx + math.cos(ca) * rs * 0.15
                local y1 = cy + math.sin(ca) * rs * 0.15
                local x2 = cx + math.cos(ca) * rs * 0.7
                local y2 = cy + math.sin(ca) * rs * 0.7
                nvgBeginPath(nvg)
                nvgMoveTo(nvg, x1, y1)
                nvgLineTo(nvg, x2, y2)
                nvgStrokeColor(nvg, nvgRGBA(50, 30, 10, 180))
                nvgStrokeWidth(nvg, 1.5)
                nvgStroke(nvg)
            end

            -- 碎石散落小颗粒
            for pi = 1, 4 do
                local pa = (pi / 4) * math.pi * 2 + obs.row * 0.9
                local pd = rs * (1.1 + 0.15 * math.sin(pi * 2.1))
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx + math.cos(pa) * pd, cy + math.sin(pa) * pd, hexSize * 0.04)
                nvgFillColor(nvg, nvgRGBA(150, 115, 60, 180))
                nvgFill(nvg)
            end
        else
            -- 普通障碍：深色实心填充 + 几何纹路，与怪物明确区分
            local isCoral = (obsChapter == 3)
            local t = G.time or 0
            local obsSeed = obs.col * 3.7 + obs.row * 2.1

            if isCoral then
                -- ── 第三章障碍物：珊瑚岩（统一青绿色有机风格） ──
                local rs = hexSize * 0.94
                local pulse = math.sin(t * 0.8 + obsSeed) * 0.1 + 0.9

                -- 1. 底层阴影（加大偏移，明显浮起感）
                local shadowOff = hexSize * 0.12
                HexGrid.DrawHex(nvg, cx + shadowOff, cy + shadowOff * 1.2, rs,
                    nvgRGBA(0, 0, 0, 160), nvgRGBA(0, 0, 0, 80))

                -- 2. 主体：深海深绿渐变
                local bodyGrad = nvgLinearGradient(nvg, cx, cy - rs * 0.7, cx, cy + rs * 0.9,
                    nvgRGBA(30, 85, 70, 255), nvgRGBA(8, 25, 22, 255))
                nvgBeginPath(nvg)
                for i = 0, 5 do
                    local ang = math.rad(60 * i - 90)
                    local vx = cx + rs * math.cos(ang)
                    local vy = cy + rs * math.sin(ang)
                    if i == 0 then nvgMoveTo(nvg, vx, vy) else nvgLineTo(nvg, vx, vy) end
                end
                nvgClosePath(nvg)
                nvgFillPaint(nvg, bodyGrad)
                nvgFill(nvg)

                -- 3. 凸面高光（大面积，模拟球面弧度）
                local hlx = cx - hexSize * 0.08
                local hly = cy - hexSize * 0.18
                local hlGrad = nvgRadialGradient(nvg, hlx, hly, 0, hexSize * 0.42,
                    nvgRGBA(120, 230, 200, math.floor(100 * pulse)),
                    nvgRGBA(50, 130, 110, 0))
                nvgBeginPath(nvg)
                nvgEllipse(nvg, hlx, hly, hexSize * 0.40, hexSize * 0.30)
                nvgFillPaint(nvg, hlGrad)
                nvgFill(nvg)

                -- 4. 表面有机色块（更亮、更大面积）
                local patches = {
                    { ox=-0.14, oy=-0.10, r=0.24, c={60, 150, 125, 100} },
                    { ox= 0.16, oy=-0.16, r=0.18, c={50, 130, 110, 90} },
                    { ox=-0.06, oy= 0.20, r=0.20, c={35, 100, 85, 80} },
                    { ox= 0.22, oy= 0.10, r=0.15, c={45, 120, 100, 70} },
                }
                for _, p in ipairs(patches) do
                    local px = cx + p.ox * hexSize
                    local py = cy + p.oy * hexSize
                    local pr = p.r * hexSize
                    local pGrad = nvgRadialGradient(nvg, px, py, 0, pr,
                        nvgRGBA(p.c[1], p.c[2], p.c[3], p.c[4]),
                        nvgRGBA(p.c[1], p.c[2], p.c[3], 0))
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, px, py, pr)
                    nvgFillPaint(nvg, pGrad)
                    nvgFill(nvg)
                end

                -- 5. 珊瑚枝纹路（Y形分叉 + 粗细变化 + 发光描边）
                for bi = 0, 2 do
                    local baseAngle = bi * math.pi * 2 / 3 - math.pi / 2 + obsSeed * 0.3
                    local branchLen = hexSize * 0.34
                    local ex = cx + math.cos(baseAngle) * branchLen
                    local ey = cy + math.sin(baseAngle) * branchLen
                    -- 主干发光底层（宽、半透明）
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, cx, cy)
                    nvgLineTo(nvg, ex, ey)
                    nvgStrokeColor(nvg, nvgRGBA(80, 240, 200, 50))
                    nvgStrokeWidth(nvg, 5.0)
                    nvgStroke(nvg)
                    -- 主干实体（粗）
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, cx, cy)
                    nvgLineTo(nvg, ex, ey)
                    nvgStrokeColor(nvg, nvgRGBA(70, 210, 170, 200))
                    nvgStrokeWidth(nvg, 2.5)
                    nvgStroke(nvg)
                    -- 分叉
                    for side = -1, 1, 2 do
                        local forkAngle = baseAngle + side * 0.55
                        local forkLen = hexSize * 0.18
                        local fx = ex + math.cos(forkAngle) * forkLen
                        local fy = ey + math.sin(forkAngle) * forkLen
                        nvgBeginPath(nvg)
                        nvgMoveTo(nvg, ex, ey)
                        nvgLineTo(nvg, fx, fy)
                        nvgStrokeColor(nvg, nvgRGBA(60, 190, 155, 150))
                        nvgStrokeWidth(nvg, 1.5)
                        nvgStroke(nvg)
                        -- 末端珊瑚息肉（更大更亮）
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, fx, fy, hexSize * 0.035)
                        nvgFillColor(nvg, nvgRGBA(110, 255, 210, math.floor(160 * pulse)))
                        nvgFill(nvg)
                    end
                end

                -- 6. 中心发光核心（更亮更大）
                local cg = nvgRadialGradient(nvg, cx, cy, 0, hexSize * 0.22,
                    nvgRGBA(100, 255, 210, math.floor(120 * pulse)), nvgRGBA(0, 0, 0, 0))
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, hexSize * 0.22)
                nvgFillPaint(nvg, cg)
                nvgFill(nvg)

                -- 7. 底部强暗角（增加立体隆起感）
                local bs = nvgLinearGradient(nvg, cx, cy + rs * 0.1, cx, cy + rs * 0.95,
                    nvgRGBA(0, 0, 0, 0), nvgRGBA(0, 8, 12, 180))
                nvgBeginPath(nvg)
                for i = 0, 5 do
                    local ang = math.rad(60 * i - 90)
                    nvgLineTo(nvg, cx + rs * math.cos(ang), cy + rs * math.sin(ang))
                end
                nvgClosePath(nvg)
                nvgFillPaint(nvg, bs)
                nvgFill(nvg)

                -- 8. 外边框（深色）+ 内发光边（更明显的边缘光）
                nvgBeginPath(nvg)
                for i = 0, 5 do
                    local ang = math.rad(60 * i - 90)
                    local vx = cx + rs * math.cos(ang)
                    local vy = cy + rs * math.sin(ang)
                    if i == 0 then nvgMoveTo(nvg, vx, vy) else nvgLineTo(nvg, vx, vy) end
                end
                nvgClosePath(nvg)
                nvgStrokeColor(nvg, nvgRGBA(8, 18, 20, 240))
                nvgStrokeWidth(nvg, 2.8)
                nvgStroke(nvg)

                local innerR = rs * 0.90
                nvgBeginPath(nvg)
                for i = 0, 5 do
                    local ang = math.rad(60 * i - 90)
                    nvgLineTo(nvg, cx + innerR * math.cos(ang), cy + innerR * math.sin(ang))
                end
                nvgClosePath(nvg)
                nvgStrokeColor(nvg, nvgRGBA(70, 210, 170, math.floor(130 * pulse)))
                nvgStrokeWidth(nvg, 1.5)
                nvgStroke(nvg)

            else
                -- ── 普通岩石障碍：多层立体岩石效果 ──
                local rs = hexSize * 0.94  -- rock size
                local rockPulse = math.sin(t * 0.8 + obsSeed) * 0.1 + 0.9

                -- 1. 底层阴影（让岩石有"浮起"感）
                local shadowOff = hexSize * 0.06
                HexGrid.DrawHex(nvg, cx + shadowOff, cy + shadowOff, rs,
                    nvgRGBA(0, 0, 0, 120), nvgRGBA(0, 0, 0, 60))

                -- 2. 岩石主体：深灰渐变（上亮下暗，模拟顶光）
                local bodyGrad = nvgLinearGradient(nvg, cx, cy - rs * 0.8, cx, cy + rs * 0.8,
                    nvgRGBA(72, 68, 62, 255), nvgRGBA(28, 25, 22, 255))
                nvgBeginPath(nvg)
                for i = 0, 5 do
                    local ang = math.rad(60 * i - 90)
                    local vx = cx + rs * math.cos(ang)
                    local vy = cy + rs * math.sin(ang)
                    if i == 0 then nvgMoveTo(nvg, vx, vy) else nvgLineTo(nvg, vx, vy) end
                end
                nvgClosePath(nvg)
                nvgFillPaint(nvg, bodyGrad)
                nvgFill(nvg)

                -- 3. 岩石表面凹凸纹理层（多个不规则色块模拟石头纹理）
                local patches = {
                    { ox=-0.18, oy=-0.25, r=0.22, c={58, 54, 48, 160} },
                    { ox= 0.20, oy=-0.10, r=0.18, c={48, 44, 38, 140} },
                    { ox=-0.08, oy= 0.20, r=0.20, c={40, 37, 32, 130} },
                    { ox= 0.12, oy= 0.28, r=0.15, c={35, 32, 28, 120} },
                    { ox=-0.30, oy= 0.05, r=0.14, c={52, 48, 42, 100} },
                }
                for _, p in ipairs(patches) do
                    local px = cx + p.ox * hexSize
                    local py = cy + p.oy * hexSize
                    local pr = p.r * hexSize
                    local pGrad = nvgRadialGradient(nvg, px, py, 0, pr,
                        nvgRGBA(p.c[1], p.c[2], p.c[3], p.c[4]),
                        nvgRGBA(p.c[1], p.c[2], p.c[3], 0))
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, px, py, pr)
                    nvgFillPaint(nvg, pGrad)
                    nvgFill(nvg)
                end

                -- 4. 顶部高光（模拟光滑石面反光）
                local hlx = cx - hexSize * 0.15
                local hly = cy - hexSize * 0.22
                local highlight = nvgRadialGradient(nvg, hlx, hly,
                    0, hexSize * 0.32,
                    nvgRGBA(140, 130, 110, math.floor(65 * rockPulse)),
                    nvgRGBA(80, 75, 65, 0))
                nvgBeginPath(nvg)
                nvgEllipse(nvg, hlx, hly, hexSize * 0.30, hexSize * 0.22)
                nvgFillPaint(nvg, highlight)
                nvgFill(nvg)

                -- 5. 裂缝纹路（带深色裂缝 + 亮边高光，模拟凹陷效果）
                local cracks = {
                    { {-0.12, -0.40}, {0.02, -0.15}, {-0.06, 0.08}, {0.08, 0.35} },
                    { {0.28, -0.22}, {0.12, -0.02}, {0.20, 0.18}, {0.15, 0.32} },
                    { {-0.32, 0.08}, {-0.12, 0.00}, {-0.20, 0.22}, {-0.08, 0.38} },
                }
                for _, crack in ipairs(cracks) do
                    -- 暗色裂缝主线
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, cx + crack[1][1] * hexSize, cy + crack[1][2] * hexSize)
                    for pi2 = 2, #crack do
                        nvgLineTo(nvg, cx + crack[pi2][1] * hexSize, cy + crack[pi2][2] * hexSize)
                    end
                    nvgStrokeColor(nvg, nvgRGBA(12, 10, 8, 200))
                    nvgStrokeWidth(nvg, 1.8)
                    nvgStroke(nvg)
                    -- 裂缝亮边（偏移1px模拟凹陷高光）
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, cx + crack[1][1] * hexSize + 1, cy + crack[1][2] * hexSize + 1)
                    for pi2 = 2, #crack do
                        nvgLineTo(nvg, cx + crack[pi2][1] * hexSize + 1, cy + crack[pi2][2] * hexSize + 1)
                    end
                    nvgStrokeColor(nvg, nvgRGBA(100, 92, 78, 70))
                    nvgStrokeWidth(nvg, 0.8)
                    nvgStroke(nvg)
                end

                -- 6. 底部暗角渐变（增强立体感）
                local bottomShadow = nvgLinearGradient(nvg, cx, cy + rs * 0.3, cx, cy + rs * 0.9,
                    nvgRGBA(0, 0, 0, 0), nvgRGBA(0, 0, 0, 100))
                nvgBeginPath(nvg)
                for i = 0, 5 do
                    local ang = math.rad(60 * i - 90)
                    local vx = cx + rs * math.cos(ang)
                    local vy = cy + rs * math.sin(ang)
                    if i == 0 then nvgMoveTo(nvg, vx, vy) else nvgLineTo(nvg, vx, vy) end
                end
                nvgClosePath(nvg)
                nvgFillPaint(nvg, bottomShadow)
                nvgFill(nvg)

                -- 7. 边缘内描边（双层：外深内浅，模拟石头边缘厚度）
                nvgBeginPath(nvg)
                for i = 0, 5 do
                    local ang = math.rad(60 * i - 90)
                    local vx = cx + rs * math.cos(ang)
                    local vy = cy + rs * math.sin(ang)
                    if i == 0 then nvgMoveTo(nvg, vx, vy) else nvgLineTo(nvg, vx, vy) end
                end
                nvgClosePath(nvg)
                nvgStrokeColor(nvg, nvgRGBA(18, 16, 14, 220))
                nvgStrokeWidth(nvg, 2.5)
                nvgStroke(nvg)

                -- 内侧亮边（模拟倒角光）
                nvgBeginPath(nvg)
                local innerR = rs * 0.92
                for i = 0, 5 do
                    local ang = math.rad(60 * i - 90)
                    local vx = cx + innerR * math.cos(ang)
                    local vy = cy + innerR * math.sin(ang)
                    if i == 0 then nvgMoveTo(nvg, vx, vy) else nvgLineTo(nvg, vx, vy) end
                end
                nvgClosePath(nvg)
                nvgStrokeColor(nvg, nvgRGBA(95, 88, 75, math.floor(90 * rockPulse)))
                nvgStrokeWidth(nvg, 1.0)
                nvgStroke(nvg)

                -- 8. 细小石粒散点（增加表面粗糙感）
                local grainSeed = obsSeed * 7.3
                for gi = 1, 8 do
                    local ga = grainSeed + gi * 2.39996  -- golden angle
                    local gr = hexSize * (0.15 + 0.45 * ((math.sin(ga * 3.7) + 1) * 0.5))
                    local gx = cx + gr * math.cos(ga)
                    local gy = cy + gr * math.sin(ga)
                    local gSize = hexSize * (0.015 + 0.012 * math.sin(ga * 5.1))
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, gx, gy, gSize)
                    nvgFillColor(nvg, nvgRGBA(90, 82, 70, 80))
                    nvgFill(nvg)
                end
            end
            -- 第三章：如果该岩石挡住寄居蟹回家路径，悬浮红色感叹号
            if board.crabs then
                local blocking = false
                for _, crab in ipairs(board.crabs) do
                    if not crab.rescued and obs.row == crab.row
                       and obs.col > crab.col and obs.col < crab.shellCol then
                        blocking = true
                        break
                    end
                end
                if blocking then
                    local t = G.time or 0
                    local bob = math.sin(t * 4.0 + obs.col * 2.1) * hexSize * 0.06
                    local ey = cy - hexSize * 0.48 + bob
                    -- 大号红色感叹号 + 白色粗描边（模拟加粗）
                    nvgFontSize(nvg, hexSize * 0.8)
                    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    -- 白色双层描边（外圈 + 内圈，模拟粗体）
                    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
                    local sw2 = hexSize * 0.06
                    for a = 0, 7 do
                        local ang = a * 0.7854
                        nvgText(nvg, cx + math.cos(ang) * sw2, ey + math.sin(ang) * sw2, "!")
                    end
                    local sw1 = hexSize * 0.03
                    for a = 0, 7 do
                        local ang = a * 0.7854
                        nvgText(nvg, cx + math.cos(ang) * sw1, ey + math.sin(ang) * sw1, "!")
                    end
                    -- 红色填充
                    nvgFillColor(nvg, nvgRGBA(230, 30, 30, 255))
                    nvgText(nvg, cx, ey, "!")
                end
            end
        end
        end -- do
        ::cull_obs::
    end

    -- 1.61 绘制寄居蟹和贝壳（第三章救援机制）
    if board.shells then
        local gt = G.time or 0
        for _, shell in ipairs(board.shells) do
            local sx, sy = HexGrid.HexToPixel(shell.col, shell.row, hexSize, ox, oy)
            if not IsCellOnScreen(sx, sy, hexSize * 2, l.x, l.y, l.w, l.h) then goto cull_shell end
            do
            local shellPulse = 0.6 + math.abs(math.sin(gt * 3.0 + shell.col * 1.5)) * 0.4

            if not shell.occupied then
                -- === 空壳：强化视觉 ===

                -- 1) 大发光底圈（双层，金色脉冲）
                local glowR = hexSize * 0.72
                local glowA = math.floor(55 * shellPulse)
                local glow = nvgRadialGradient(nvg, sx, sy, hexSize * 0.2, glowR,
                    nvgRGBA(255, 220, 80, glowA), nvgRGBA(255, 180, 40, 0))
                nvgBeginPath(nvg)
                nvgCircle(nvg, sx, sy, glowR)
                nvgFillPaint(nvg, glow)
                nvgFill(nvg)

                -- 2) 扩散光圈（向外扩散动画）
                local ringT = (gt * 1.2 + shell.col * 0.7) % 1.0
                local ringR = hexSize * (0.38 + ringT * 0.48)
                local ringA = math.floor(130 * (1.0 - ringT))
                nvgBeginPath(nvg)
                nvgCircle(nvg, sx, sy, ringR)
                nvgStrokeColor(nvg, nvgRGBA(255, 210, 80, ringA))
                nvgStrokeWidth(nvg, 2.0)
                nvgStroke(nvg)

                -- 3) 底座金色实心小圆
                local baseA = math.floor(60 * shellPulse)
                nvgBeginPath(nvg)
                nvgCircle(nvg, sx, sy, hexSize * 0.38)
                nvgFillColor(nvg, nvgRGBA(255, 200, 60, baseA))
                nvgFill(nvg)

                -- 4) 贝壳图标（放大 + 上下浮动）
                local shellBob = math.sin(gt * 3.5 + shell.col * 2.1) * hexSize * 0.05
                nvgFontSize(nvg, hexSize * 0.70)
                nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(nvg, nvgRGBA(255, 255, 255, 235))
                nvgText(nvg, sx, sy + shellBob, "🐚")

                -- 5) "HOME" 气泡（上方，脉冲）
                local bubBob = math.sin(gt * 3.5 + shell.col * 2.1) * 2.5
                local bubY = sy - hexSize * 0.72 + bubBob + shellBob
                local bubW = hexSize * 0.72
                local bubH = hexSize * 0.36
                local bubR2 = hexSize * 0.09
                local bubAlpha = math.floor(190 + 55 * shellPulse)
                -- 气泡背景（深色渐变）
                local bubBg = nvgLinearGradient(nvg,
                    sx, bubY - bubH * 0.5, sx, bubY + bubH * 0.5,
                    nvgRGBA(30, 20, 5, 230), nvgRGBA(15, 10, 0, 245))
                nvgBeginPath(nvg)
                nvgRoundedRect(nvg, sx - bubW / 2, bubY - bubH / 2, bubW, bubH, bubR2)
                nvgFillPaint(nvg, bubBg)
                nvgFill(nvg)
                -- 气泡边框（金色脉冲）
                nvgBeginPath(nvg)
                nvgRoundedRect(nvg, sx - bubW / 2, bubY - bubH / 2, bubW, bubH, bubR2)
                nvgStrokeColor(nvg, nvgRGBA(255, 200, 60, bubAlpha))
                nvgStrokeWidth(nvg, 1.8)
                nvgStroke(nvg)
                -- 气泡小三角
                nvgBeginPath(nvg)
                nvgMoveTo(nvg, sx - hexSize * 0.06, bubY + bubH / 2 - 1)
                nvgLineTo(nvg, sx + hexSize * 0.06, bubY + bubH / 2 - 1)
                nvgLineTo(nvg, sx, bubY + bubH / 2 + hexSize * 0.08)
                nvgClosePath(nvg)
                nvgFillColor(nvg, nvgRGBA(20, 14, 0, 240))
                nvgFill(nvg)
                nvgStrokeColor(nvg, nvgRGBA(255, 200, 60, bubAlpha))
                nvgStrokeWidth(nvg, 1.5)
                nvgStroke(nvg)
                -- "🏠 HOME" 文字
                nvgFontSize(nvg, hexSize * 0.25)
                nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(nvg, nvgRGBA(0, 0, 0, 100))
                nvgText(nvg, sx + 1, bubY + 1, "🏠HOME")
                nvgFillColor(nvg, nvgRGBA(255, 220, 100, bubAlpha))
                nvgText(nvg, sx, bubY, "🏠HOME")

                -- 6) 找到对应螃蟹，画虚线引导箭头（同行）
                if board.crabs then
                    for _, crab in ipairs(board.crabs) do
                        if not crab.rescued and crab.shellCol == shell.col and crab.shellRow == shell.row then
                            local drawCol = crab.displayCol or crab.col
                            local cx2, cy2 = HexGrid.HexToPixel(drawCol, crab.row, hexSize, ox, oy)
                            -- 只在距离大于1格时绘制
                            local dx, dy = sx - cx2, sy - cy2
                            local dist2 = math.sqrt(dx * dx + dy * dy)
                            if dist2 > hexSize * 1.2 then
                                local nx2, ny2 = dx / dist2, dy / dist2
                                -- 起点缩进（避免覆盖蟹图标）
                                local startX = cx2 + nx2 * hexSize * 0.52
                                local startY = cy2 + ny2 * hexSize * 0.52
                                -- 终点缩进（避免覆盖贝壳图标）
                                local endX = sx - nx2 * hexSize * 0.45
                                local endY = sy - ny2 * hexSize * 0.45
                                -- 虚线（多段短线）
                                local dashLen = hexSize * 0.16
                                local gapLen  = hexSize * 0.10
                                local lineLen = math.sqrt((endX-startX)^2 + (endY-startY)^2)
                                local pos = 0
                                local dashAlpha = math.floor(140 * shellPulse)
                                nvgStrokeColor(nvg, nvgRGBA(255, 210, 80, dashAlpha))
                                nvgStrokeWidth(nvg, 1.8)
                                while pos < lineLen do
                                    local dEnd = math.min(pos + dashLen, lineLen)
                                    local t1 = pos / lineLen
                                    local t2 = dEnd / lineLen
                                    nvgBeginPath(nvg)
                                    nvgMoveTo(nvg, startX + (endX - startX) * t1, startY + (endY - startY) * t1)
                                    nvgLineTo(nvg, startX + (endX - startX) * t2, startY + (endY - startY) * t2)
                                    nvgStroke(nvg)
                                    pos = pos + dashLen + gapLen
                                end
                                -- 箭头头部（指向贝壳）
                                local arrowLen = hexSize * 0.14
                                local arrowW   = hexSize * 0.08
                                local px2, py2 = -ny2, nx2
                                nvgBeginPath(nvg)
                                nvgMoveTo(nvg, endX, endY)
                                nvgLineTo(nvg, endX - nx2 * arrowLen + px2 * arrowW,
                                               endY - ny2 * arrowLen + py2 * arrowW)
                                nvgLineTo(nvg, endX - nx2 * arrowLen - px2 * arrowW,
                                               endY - ny2 * arrowLen - py2 * arrowW)
                                nvgClosePath(nvg)
                                nvgFillColor(nvg, nvgRGBA(255, 210, 80, dashAlpha))
                                nvgFill(nvg)
                            end
                            break
                        end
                    end
                end
            else
                -- === 已占用：安静的绿色暖光 ===
                nvgBeginPath(nvg)
                nvgCircle(nvg, sx, sy, hexSize * 0.45)
                nvgFillColor(nvg, nvgRGBA(80, 220, 120, math.floor(45 * shellPulse)))
                nvgFill(nvg)
                nvgFontSize(nvg, hexSize * 0.55)
                nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(nvg, nvgRGBA(255, 220, 160, 120))
                nvgText(nvg, sx, sy, "🐚")
            end
            end -- do
            ::cull_shell::
        end
    end
    if board.crabs then
        for _, crab in ipairs(board.crabs) do
            if not crab.rescued then
                -- 计算当前显示位置（支持动画插值）
                local drawCol = crab.displayCol or crab.col
                local drawRow = crab.row
                local cx, cy = HexGrid.HexToPixel(drawCol, drawRow, hexSize, ox, oy)
                if not IsCellOnScreen(cx, cy, hexSize, l.x, l.y, l.w, l.h) then goto cull_crab end
                do
                local t = G.time or 0
                local crabBob = math.sin(t * 3.5 + crab.col) * hexSize * 0.06

                -- 寄居蟹图标（无圆底，直接绘制大图标）
                nvgFontSize(nvg, hexSize * 0.85)
                nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
                nvgText(nvg, cx, cy + crabBob, "🦀")

                -- ★ 求救气泡（强化版：脉冲外发光 + 扫光 + 粗体SOS）
                if not crab.animTimer then
                    local bubBob = math.sin(t * 4.0 + crab.col * 2) * 3
                    local bubY = cy - hexSize * 0.65 + bubBob
                    local pulse = 0.55 + math.abs(math.sin(t * 5.5)) * 0.45  -- 快速脉冲

                    local bubW = hexSize * 0.78
                    local bubH = hexSize * 0.42
                    local bubR = hexSize * 0.10

                    -- 1) 外发光晕（双层，红色脉冲）
                    local glowR1 = bubW * 0.72
                    local glowAlpha1 = math.floor(70 * pulse)
                    local glowPaint1 = nvgRadialGradient(nvg,
                        cx, bubY, bubW * 0.3, glowR1,
                        nvgRGBA(255, 60, 60, glowAlpha1),
                        nvgRGBA(255, 60, 60, 0))
                    nvgBeginPath(nvg)
                    nvgEllipse(nvg, cx, bubY, glowR1, glowR1 * 0.55)
                    nvgFillPaint(nvg, glowPaint1)
                    nvgFill(nvg)

                    -- 2) 气泡背景（深红渐变）
                    local bgPaint = nvgLinearGradient(nvg,
                        cx, bubY - bubH * 0.5, cx, bubY + bubH * 0.5,
                        nvgRGBA(80, 10, 10, 230),
                        nvgRGBA(40, 5, 5, 240))
                    nvgBeginPath(nvg)
                    nvgRoundedRect(nvg, cx - bubW / 2, bubY - bubH / 2, bubW, bubH, bubR)
                    nvgFillPaint(nvg, bgPaint)
                    nvgFill(nvg)

                    -- 3) 扫光条纹（斜向亮线，循环移动）
                    local sweepT = (t * 0.9) % 1.0
                    local sweepX = (cx - bubW * 0.5) + sweepT * (bubW * 1.6) - bubW * 0.3
                    nvgSave(nvg)
                    nvgScissor(nvg, cx - bubW / 2, bubY - bubH / 2, bubW, bubH)
                    local sweepPaint = nvgLinearGradient(nvg,
                        sweepX - bubH * 0.3, bubY - bubH,
                        sweepX + bubH * 0.3, bubY + bubH,
                        nvgRGBA(255, 200, 200, 0),
                        nvgRGBA(255, 255, 255, math.floor(55 * pulse)))
                    nvgBeginPath(nvg)
                    nvgRect(nvg, sweepX - bubH * 0.5, bubY - bubH, bubH * 1.0, bubH * 2)
                    nvgFillPaint(nvg, sweepPaint)
                    nvgFill(nvg)
                    nvgResetScissor(nvg)
                    nvgRestore(nvg)

                    -- 4) 气泡边框（脉冲亮红色）
                    local borderAlpha = math.floor(180 + 75 * pulse)
                    nvgBeginPath(nvg)
                    nvgRoundedRect(nvg, cx - bubW / 2, bubY - bubH / 2, bubW, bubH, bubR)
                    nvgStrokeColor(nvg, nvgRGBA(255, 80, 80, borderAlpha))
                    nvgStrokeWidth(nvg, 2.2)
                    nvgStroke(nvg)

                    -- 5) 气泡小三角
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, cx - hexSize * 0.07, bubY + bubH / 2 - 1)
                    nvgLineTo(nvg, cx + hexSize * 0.07, bubY + bubH / 2 - 1)
                    nvgLineTo(nvg, cx, bubY + bubH / 2 + hexSize * 0.09)
                    nvgClosePath(nvg)
                    nvgFillColor(nvg, nvgRGBA(60, 8, 8, 235))
                    nvgFill(nvg)
                    nvgStrokeColor(nvg, nvgRGBA(255, 80, 80, borderAlpha))
                    nvgStrokeWidth(nvg, 1.8)
                    nvgStroke(nvg)

                    -- 6) "SOS" 文字阴影
                    nvgFontSize(nvg, hexSize * 0.36)
                    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 120))
                    nvgText(nvg, cx + 1.5, bubY + 1.5, "SOS")
                    -- "SOS" 文字本体（白色+红色叠加，脉冲亮度）
                    local textAlpha = math.floor(220 + 35 * pulse)
                    nvgFillColor(nvg, nvgRGBA(255, 210, 210, textAlpha))
                    nvgText(nvg, cx, bubY, "SOS")
                end
                end -- do
            end
            ::cull_crab::
        end
    end

    -- 1.62 绘制炎魔祭坛（第二章）— 底座 + 外层灼烧光晕 + 火弧 + 图标
    if board.altars then
        for _, alt in ipairs(board.altars) do
            if alt.active then
                local cx, cy = HexGrid.HexToPixel(alt.col, alt.row, hexSize, ox, oy)
                if not IsCellOnScreen(cx, cy, hexSize * 3, l.x, l.y, l.w, l.h) then goto cull_altar end
                do
                local t = G.time or 0
                local altPulse = math.sin(t * 3.0 + alt.col * 1.7) * 0.12 + 0.88

                -- 外层灼烧光晕（覆盖2格范围，与 ALTAR_RADIUS 对应）
                local burnRadius = hexSize * 3.0  -- 覆盖2格半径，稍大以确保视觉覆盖
                -- 第一层：大范围柔和底光
                local outerAlpha1 = math.sin(t * 1.5 + alt.col * 0.9) * 20 + 70
                local glow1 = nvgRadialGradient(nvg, cx, cy,
                    hexSize * 0.3, burnRadius,
                    nvgRGBA(255, 60, 0, math.floor(outerAlpha1 * altPulse)),
                    nvgRGBA(180, 30, 0, 0))
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, burnRadius)
                nvgFillPaint(nvg, glow1)
                nvgFill(nvg)
                -- 第二层：中圈聚焦光晕（更亮）
                local outerAlpha2 = math.sin(t * 2.5 + alt.col * 1.3) * 25 + 100
                local glow2 = nvgRadialGradient(nvg, cx, cy,
                    hexSize * 0.5, hexSize * 2.2,
                    nvgRGBA(255, 100, 10, math.floor(outerAlpha2 * altPulse)),
                    nvgRGBA(220, 50, 0, 0))
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, hexSize * 2.2)
                nvgFillPaint(nvg, glow2)
                nvgFill(nvg)

                -- 外层范围边界圈（实线，高亮橙红）
                local borderR = hexSize * 2.7
                local borderAlpha = math.sin(t * 2.0 + alt.col) * 30 + 180
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, borderR)
                nvgStrokeColor(nvg, nvgRGBA(255, 120, 30, math.floor(borderAlpha * altPulse)))
                nvgStrokeWidth(nvg, 2.5)
                nvgStroke(nvg)

                -- 外层灼烧虚线圈（旋转，粗且亮）
                local dashR = hexSize * 2.85
                local dashCount = 16
                for d = 0, dashCount - 1 do
                    local a0 = t * 0.5 + d * (2 * math.pi / dashCount)
                    local a1 = a0 + (math.pi / dashCount) * 0.6
                    nvgBeginPath(nvg)
                    nvgArc(nvg, cx, cy, dashR, a0, a1, NVG_CW)
                    nvgStrokeColor(nvg, nvgRGBA(255, 160, 40, math.floor(160 * altPulse)))
                    nvgStrokeWidth(nvg, 2.5)
                    nvgLineCap(nvg, NVG_ROUND)
                    nvgStroke(nvg)
                end

                -- 暗红填充底座
                HexGrid.DrawHex(nvg, cx, cy, hexSize * 0.88,
                    nvgRGBA(80, 20, 8, 220), nvgRGBA(200, 80, 20, math.floor(160 * altPulse)))

                -- 单层旋转火焰弧（简洁，120度间隔）
                local ringR = hexSize * 0.88
                for arc = 0, 2 do
                    local baseAngle = t * 1.5 + arc * 2.094
                    local sweep = 1.6
                    nvgBeginPath(nvg)
                    nvgArc(nvg, cx, cy, ringR, baseAngle, baseAngle + sweep, NVG_CW)
                    nvgStrokeColor(nvg, nvgRGBA(255, 140, 30, math.floor(200 * altPulse)))
                    nvgStrokeWidth(nvg, 3.0)
                    nvgLineCap(nvg, NVG_ROUND)
                    nvgStroke(nvg)
                end

                -- 内焰光晕
                local flameGlow = nvgRadialGradient(nvg, cx, cy, 0, hexSize * 0.5,
                    nvgRGBA(255, 120, 20, math.floor(100 * altPulse)),
                    nvgRGBA(120, 20, 5, 0))
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, hexSize * 0.5)
                nvgFillPaint(nvg, flameGlow)
                nvgFill(nvg)

                -- 火焰图标
                local flameBob = math.sin(t * 4.0 + alt.col) * hexSize * 0.03
                nvgFontSize(nvg, hexSize * 0.6)
                nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
                nvgText(nvg, cx, cy + flameBob - hexSize * 0.05, "🔥")
                end -- do
            end
            ::cull_altar::
        end
    end

    -- 1.65 绘制Boss光环危险区域（简化版：底层填充 + 辉光 + 轻描边 + 警告符号）
    if Battle.IsBossLevel(G.battle.level) then
        local enemies = HexGrid.GetTeamPieces(board, "enemy")
        local gt = G.time or 0
        for _, e in ipairs(enemies) do
            if e.isBoss and e.hp > 0 then
                local aura = Battle.BOSS_AURA[e.bossType]
                if aura then
                    local ar, ag, ab = aura.color[1], aura.color[2], aura.color[3]
                    local isEnraged = e.enraged
                    -- 遍历光环范围内的格子
                    for r = 1, HexGrid.ROWS do
                        for c = 1, HexGrid.COLS do
                            if HexGrid.InBounds(c, r) then
                                local dist = HexGrid.CubeDistance(c, r, e.col, e.row)
                                if dist >= 1 and dist <= aura.range then
                                    local cx, cy = HexGrid.HexToPixel(c, r, hexSize, ox, oy)
                                    local intensity = 1.0 - (dist - 1) / math.max(1, aura.range)
                                    local phase = c * 1.3 + r * 0.9
                                    local auraPulse = math.sin(gt * 2.5 + phase) * 0.3 + 0.7

                                    -- (a) 底层填充（半透明主题色）
                                    local fillA = math.floor((35 + 30 * intensity) * auraPulse)
                                    if isEnraged then fillA = math.floor(fillA * 1.3) end
                                    HexGrid.DrawHex(nvg, cx, cy, hexSize * 0.88,
                                        nvgRGBA(ar, ag, ab, fillA), nil)

                                    -- (b) 中心辉光
                                    local glowR = hexSize * (0.4 + intensity * 0.2)
                                    local glowA = math.floor((40 + 30 * intensity) * auraPulse)
                                    if isEnraged then glowA = math.floor(glowA * 1.3) end
                                    local gPaint = nvgRadialGradient(nvg, cx, cy, 0, glowR,
                                        nvgRGBA(ar, ag, ab, glowA),
                                        nvgRGBA(ar, ag, ab, 0))
                                    nvgBeginPath(nvg)
                                    nvgCircle(nvg, cx, cy, glowR)
                                    nvgFillPaint(nvg, gPaint)
                                    nvgFill(nvg)

                                    -- (c) 轻描边
                                    local borderA = math.floor((60 + 50 * intensity) * auraPulse)
                                    if isEnraged then borderA = math.floor(math.min(255, borderA * 1.3)) end
                                    HexGrid.DrawHex(nvg, cx, cy, hexSize * 0.88,
                                        nil, nvgRGBA(ar, ag, ab, borderA))

                                    -- (f) 危险符号（最内圈）
                                    if dist == 1 then
                                        local warnA = math.floor(fillA * 1.2)
                                        if isEnraged then warnA = math.floor(math.min(255, warnA * 1.4)) end
                                        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                                        nvgFontSize(nvg, 14)
                                        nvgFillColor(nvg, nvgRGBA(ar, ag, ab, warnA))
                                        nvgText(nvg, cx, cy + hexSize * 0.35, "⚠")
                                    end
                                end
                            end
                        end
                    end

                    -- (g) 外围伤害范围边界环（脉动虚线圆 + 外发光）
                    local bossCX, bossCY = HexGrid.HexToPixel(e.col, e.row, hexSize, ox, oy)
                    local outerRadius = (aura.range + 0.5) * hexSize * 1.73 * 0.5
                    local borderPulse = math.sin(gt * 2.0) * 0.25 + 0.75
                    local baseAlpha = isEnraged and 200 or 140

                    -- 外发光（柔和宽光带）
                    local glowWidth = hexSize * 0.4
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, bossCX, bossCY, outerRadius)
                    nvgStrokeColor(nvg, nvgRGBA(ar, ag, ab, math.floor(baseAlpha * 0.3 * borderPulse)))
                    nvgStrokeWidth(nvg, glowWidth)
                    nvgStroke(nvg)

                    -- 主边界线（实线脉动）
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, bossCX, bossCY, outerRadius)
                    nvgStrokeColor(nvg, nvgRGBA(ar, ag, ab, math.floor(baseAlpha * borderPulse)))
                    nvgStrokeWidth(nvg, 2.5)
                    nvgStroke(nvg)

                    -- 内层亮线（高光边界）
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, bossCX, bossCY, outerRadius - 1.5)
                    nvgStrokeColor(nvg, nvgRGBA(
                        math.min(255, ar + 80), math.min(255, ag + 80), math.min(255, ab + 80),
                        math.floor(baseAlpha * 0.5 * borderPulse)))
                    nvgStrokeWidth(nvg, 1.0)
                    nvgStroke(nvg)

                    -- 呼吸扩散环（从边界向外慢速扩张的薄圈，增强动态警示感）
                    local expandT = (gt * 0.6) % 1.0
                    local expandR = outerRadius + expandT * hexSize * 0.8
                    local expandA = math.floor((1.0 - expandT) * baseAlpha * 0.5)
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, bossCX, bossCY, expandR)
                    nvgStrokeColor(nvg, nvgRGBA(ar, ag, ab, expandA))
                    nvgStrokeWidth(nvg, 1.5 * (1.0 - expandT) + 0.5)
                    nvgStroke(nvg)

                    -- 第二层扩散环（错相位）
                    local expandT2 = (gt * 0.6 + 0.5) % 1.0
                    local expandR2 = outerRadius + expandT2 * hexSize * 0.8
                    local expandA2 = math.floor((1.0 - expandT2) * baseAlpha * 0.35)
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, bossCX, bossCY, expandR2)
                    nvgStrokeColor(nvg, nvgRGBA(ar, ag, ab, expandA2))
                    nvgStrokeWidth(nvg, 1.0 * (1.0 - expandT2) + 0.5)
                    nvgStroke(nvg)
                end
            end
        end
    end

    -- 1.7 绘制地面道具（呼吸脉冲 + 绿色菱形底标）
    local pulse = math.sin((G.time or 0) * 3.0) * 0.5 + 0.5  -- 0~1 呼吸
    for _, item in ipairs(board.items) do
        local cx, cy = HexGrid.HexToPixel(item.col, item.row, hexSize, ox, oy)
        if not IsCellOnScreen(cx, cy, hexSize, l.x, l.y, l.w, l.h) then goto cull_item end
        do
        local def = Battle.ITEM_TYPES[item.type]
        if def then
            -- 菱形底标颜色（轮盘道具用独特颜色区分）
            local fillR, fillG, fillB = 40, 200, 100    -- 默认绿色
            local strokeR, strokeG, strokeB = 80, 255, 140
            if item.type == "lucky_wheel" then
                fillR, fillG, fillB = 220, 180, 30       -- 金色
                strokeR, strokeG, strokeB = 255, 215, 0
            elseif item.type == "doom_wheel" then
                fillR, fillG, fillB = 140, 40, 180       -- 紫色
                strokeR, strokeG, strokeB = 180, 60, 255
            end
            local dSize = hexSize * 0.45
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, cx, cy - dSize)
            nvgLineTo(nvg, cx + dSize, cy)
            nvgLineTo(nvg, cx, cy + dSize)
            nvgLineTo(nvg, cx - dSize, cy)
            nvgClosePath(nvg)
            nvgFillColor(nvg, nvgRGBA(fillR, fillG, fillB, 120 + math.floor(pulse * 80)))
            nvgFill(nvg)
            nvgStrokeColor(nvg, nvgRGBA(strokeR, strokeG, strokeB, 170 + math.floor(pulse * 60)))
            nvgStrokeWidth(nvg, 2.0)
            nvgStroke(nvg)
            -- 轮盘道具额外旋转光芒
            if def.isWheel then
                local spinAngle = (G.time or 0) * 1.5
                nvgSave(nvg)
                nvgTranslate(nvg, cx, cy)
                nvgRotate(nvg, spinAngle)
                nvgBeginPath(nvg)
                for i = 0, 3 do
                    local a = i * math.pi * 0.5
                    local rx = math.cos(a) * dSize * 1.1
                    local ry = math.sin(a) * dSize * 1.1
                    nvgMoveTo(nvg, 0, 0)
                    nvgLineTo(nvg, rx, ry)
                end
                nvgStrokeColor(nvg, nvgRGBA(strokeR, strokeG, strokeB, 80 + math.floor(pulse * 60)))
                nvgStrokeWidth(nvg, 1.5)
                nvgStroke(nvg)
                nvgRestore(nvg)
            end
            -- 道具图标（随呼吸微微浮动）
            local floatY = -pulse * 4
            IconAtlas.DrawNVG(nvg, def.icon, cx, cy + floatY, hexSize * 0.78)
        end
        end -- do
        ::cull_item::
    end

    -- 2. 绘制可移动高亮 (蓝色) — 仅 PLAYER_SELECT 阶段
    if G.battle.phase == "PLAYER_SELECT" then
        for _, m in ipairs(G.validMoves) do
            local cx, cy = HexGrid.HexToPixel(m.col, m.row, hexSize, ox, oy)
            HexGrid.DrawHex(nvg, cx, cy, hexSize * 0.88,
                nvgRGBA(74, 144, 217, 80), nvgRGBA(74, 144, 217, 200))
        end
    end

    -- 3. 绘制可跳跃高亮（章节自适应颜色）
    -- 第二章火山棋盘偏暗棕，用金黄色对比；其他章节保持橙色
    local jumpFillR, jumpFillG, jumpFillB = 255, 107, 53
    local jumpCrossR, jumpCrossG, jumpCrossB = 255, 50, 50
    local chapter = G.battle and G.battle.chapter or 1
    if chapter == 2 then
        jumpFillR, jumpFillG, jumpFillB = 255, 210, 60   -- 金黄色
        jumpCrossR, jumpCrossG, jumpCrossB = 255, 180, 30
    end
    if G.battle.phase == "PLAYER_SELECT" or G.battle.phase == "PLAYER_PLAN" then
        for _, j in ipairs(G.validJumps) do
            local cx, cy = HexGrid.HexToPixel(j.col, j.row, hexSize, ox, oy)
            HexGrid.DrawHex(nvg, cx, cy, hexSize * 0.88,
                nvgRGBA(jumpFillR, jumpFillG, jumpFillB, 80),
                nvgRGBA(jumpFillR, jumpFillG, jumpFillB, 200))
            local ex, ey = HexGrid.HexToPixel(j.jumpedCol, j.jumpedRow, hexSize, ox, oy)
            nvgBeginPath(nvg)
            nvgCircle(nvg, ex, ey, hexSize * 0.3)
            nvgFillColor(nvg, nvgRGBA(jumpCrossR, jumpCrossG, jumpCrossB, 60))
            nvgFill(nvg)
        end
    end

    -- 3.2 (moved to section 7.8 for top-layer rendering)

    -- 3.5 绘制威胁预览（落点处会被哪些敌人攻击）
    if #G.threatPreview > 0 and
       (G.battle.phase == "PLAYER_SELECT" or G.battle.phase == "PLAYER_PLAN") then
        local tcx, tcy = HexGrid.HexToPixel(G.threatTargetCol, G.threatTargetRow, hexSize, ox, oy)
        local dangerPulse = math.sin((G.time or 0) * 5.0) * 0.3 + 0.7

        -- 统计即时伤害和潜在伤害
        local immediateDmg = 0
        local pendingDmg = 0
        for _, th in ipairs(G.threatPreview) do
            if th.pending then
                pendingDmg = pendingDmg + th.damage
            else
                immediateDmg = immediateDmg + th.damage
            end
        end

        -- 落点危险圈（有即时威胁用红色，只有潜在威胁用黄色）
        local hasImmediate = immediateDmg > 0
        local ringR, ringG, ringB = 255, 60, 60
        if not hasImmediate then ringR, ringG, ringB = 255, 180, 40 end
        nvgBeginPath(nvg)
        nvgCircle(nvg, tcx, tcy, hexSize * 0.85)
        nvgStrokeColor(nvg, nvgRGBA(ringR, ringG, ringB, math.floor(80 * dangerPulse)))
        nvgStrokeWidth(nvg, 2.5)
        nvgStroke(nvg)

        -- 总伤害提示
        nvgFontSize(nvg, hexSize * 0.28)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
        if immediateDmg > 0 then
            nvgFillColor(nvg, nvgRGBA(255, 80, 80, math.floor(220 * dangerPulse)))
            local totalText = "⚠️-" .. immediateDmg
            if pendingDmg > 0 then
                totalText = totalText .. " (下回合再-" .. pendingDmg .. ")"
            end
            nvgText(nvg, tcx, tcy - hexSize * 0.85 - 2, totalText)
        else
            nvgFillColor(nvg, nvgRGBA(255, 200, 60, math.floor(220 * dangerPulse)))
            nvgText(nvg, tcx, tcy - hexSize * 0.85 - 2, "⚠️下回合-" .. pendingDmg)
        end

        for _, th in ipairs(G.threatPreview) do
            local ecx, ecy = HexGrid.HexToPixel(th.enemy.col, th.enemy.row, hexSize, ox, oy)

            if th.pending then
                -- 潜在威胁: 黄色虚线连接
                local dx = tcx - ecx
                local dy = tcy - ecy
                local len = math.sqrt(dx * dx + dy * dy)
                local segments = math.max(4, math.floor(len / 8))
                for s = 0, segments - 1, 2 do
                    local t0 = s / segments
                    local t1 = math.min(1.0, (s + 1) / segments)
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, ecx + dx * t0, ecy + dy * t0)
                    nvgLineTo(nvg, ecx + dx * t1, ecy + dy * t1)
                    nvgStrokeColor(nvg, nvgRGBA(255, 200, 50, math.floor(140 * dangerPulse)))
                    nvgStrokeWidth(nvg, 2)
                    nvgStroke(nvg)
                end
            elseif th.dist <= 1 then
                -- 即时近战: 红色实线连接
                nvgBeginPath(nvg)
                nvgMoveTo(nvg, ecx, ecy)
                nvgLineTo(nvg, tcx, tcy)
                nvgStrokeColor(nvg, nvgRGBA(255, 70, 70, math.floor(160 * dangerPulse)))
                nvgStrokeWidth(nvg, 2.5)
                nvgStroke(nvg)
            else
                -- 即时远程: 橙色虚线连接
                local dx = tcx - ecx
                local dy = tcy - ecy
                local len = math.sqrt(dx * dx + dy * dy)
                local segments = math.max(4, math.floor(len / 8))
                for s = 0, segments - 1, 2 do
                    local t0 = s / segments
                    local t1 = math.min(1.0, (s + 1) / segments)
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, ecx + dx * t0, ecy + dy * t0)
                    nvgLineTo(nvg, ecx + dx * t1, ecy + dy * t1)
                    nvgStrokeColor(nvg, nvgRGBA(255, 160, 40, math.floor(180 * dangerPulse)))
                    nvgStrokeWidth(nvg, 2)
                    nvgStroke(nvg)
                end
            end

            -- 敌人脚下攻击范围指示圈
            local rangeRingR = (th.enemy.attackRange or 1) * hexSize * 1.1
            nvgBeginPath(nvg)
            nvgCircle(nvg, ecx, ecy, rangeRingR)
            local circleR, circleG, circleB = 255, 80, 50
            if th.pending then circleR, circleG, circleB = 255, 200, 50 end
            nvgStrokeColor(nvg, nvgRGBA(circleR, circleG, circleB, math.floor(50 * dangerPulse)))
            nvgStrokeWidth(nvg, 1.5)
            nvgStroke(nvg)

            -- 攻击标签浮于连线中间
            local mx = (ecx + tcx) * 0.5
            local my = (ecy + tcy) * 0.5 - 6
            nvgFontSize(nvg, hexSize * 0.3)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            if th.pending then
                nvgFillColor(nvg, nvgRGBA(255, 220, 100, math.floor(230 * dangerPulse)))
            else
                nvgFillColor(nvg, nvgRGBA(255, 100, 80, math.floor(230 * dangerPulse)))
            end
            nvgText(nvg, mx, my, "-" .. th.damage)
        end
    end

    -- 4. 绘制规划路径（含出发点到第一落点的连线）
    if #G.plannedJumps > 0 and
       (G.battle.phase == "PLAYER_PLAN" or G.battle.phase == "PLAYER_EXECUTE") then
        for i, pj in ipairs(G.plannedJumps) do
            local cx, cy = HexGrid.HexToPixel(pj.col, pj.row, hexSize, ox, oy)

            -- 画与上一个点的连线（只有连击时才画起点到第一落点的线）
            local px, py
            if i >= 2 then
                local prev = G.plannedJumps[i - 1]
                px, py = HexGrid.HexToPixel(prev.col, prev.row, hexSize, ox, oy)
            elseif #G.plannedJumps >= 2 then
                -- 连击时：第1个落点连回英雄出发位置
                -- PLAN阶段用hero当前位置（还没移动），EXECUTE阶段用记录的起点（hero已移动）
                local startCol, startRow
                if G.battle.phase == "PLAYER_EXECUTE" and G.jumpStartCol then
                    startCol = G.jumpStartCol
                    startRow = G.jumpStartRow
                else
                    startCol = G.battle.hero.col
                    startRow = G.battle.hero.row
                end
                px, py = HexGrid.HexToPixel(startCol, startRow, hexSize, ox, oy)
            end
            if px then
                nvgBeginPath(nvg)
                nvgMoveTo(nvg, px, py)
                nvgLineTo(nvg, cx, cy)
                nvgStrokeColor(nvg, nvgRGBA(255, 215, 0, 160))
                nvgStrokeWidth(nvg, 2.5)
                nvgStroke(nvg)
            end

            -- 落点编号圆圈（金色）
            nvgBeginPath(nvg)
            nvgCircle(nvg, cx, cy, hexSize * 0.28)
            nvgFillColor(nvg, nvgRGBA(255, 215, 0, 200))
            nvgFill(nvg)

            nvgFontSize(nvg, hexSize * 0.35)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(nvg, nvgRGBA(30, 30, 30, 255))
            nvgText(nvg, cx, cy, tostring(i))

            -- 被跳过敌人标记（红色半透明）
            local jx, jy = HexGrid.HexToPixel(pj.jumpedCol, pj.jumpedRow, hexSize, ox, oy)
            nvgBeginPath(nvg)
            nvgCircle(nvg, jx, jy, hexSize * 0.25)
            nvgFillColor(nvg, nvgRGBA(255, 50, 50, 100))
            nvgFill(nvg)
        end
    end

    -- 5. 英雄选中高亮（醒目大光圈）
    if G.battle.hero and G.battle.hero.hp > 0 and
       (G.battle.phase == "PLAYER_SELECT" or G.battle.phase == "PLAYER_PLAN") then
        local hx, hy = HexGrid.HexToPixel(G.battle.hero.col, G.battle.hero.row, hexSize, ox, oy)
        local ht = G.time or 0
        local hPulse = math.sin(ht * 3.5) * 0.15 + 0.85

        -- 外层柔光（大范围淡色光晕）
        nvgBeginPath(nvg)
        nvgCircle(nvg, hx, hy, hexSize * 0.85)
        nvgStrokeColor(nvg, nvgRGBA(255, 230, 50, math.floor(60 * hPulse)))
        nvgStrokeWidth(nvg, 6)
        nvgStroke(nvg)

        -- 主高亮圈（亮黄色粗描边）
        nvgBeginPath(nvg)
        nvgCircle(nvg, hx, hy, hexSize * 0.72)
        nvgStrokeColor(nvg, nvgRGBA(255, 240, 60, math.floor(230 * hPulse)))
        nvgStrokeWidth(nvg, 3.5)
        nvgStroke(nvg)
    end

    -- 6. 规划中模拟位置指示器
    if G.battle.phase == "PLAYER_PLAN" and #G.plannedJumps > 0 then
        local sx, sy = HexGrid.HexToPixel(G.planHeroCol, G.planHeroRow, hexSize, ox, oy)
        nvgBeginPath(nvg)
        nvgCircle(nvg, sx, sy, hexSize * 0.5)
        nvgStrokeColor(nvg, nvgRGBA(255, 215, 0, 120))
        nvgStrokeWidth(nvg, 2)
        nvgStroke(nvg)
    end

    -- 7.04 沙虫emerging期间尾部沙坑（虫身正在从地下爬出时，在洞口画沙坑）
    if G.battle.sandWormSegments and G.battle.boss and G.battle.boss.emerging then
        -- 找到洞口位置：优先用 sandWormEmergeHole，否则用最后一个隐藏段的位置
        local holeCol, holeRow
        if G.battle.sandWormEmergeHole then
            holeCol = G.battle.sandWormEmergeHole.col
            holeRow = G.battle.sandWormEmergeHole.row
        else
            for i = #G.battle.sandWormSegments, 1, -1 do
                local seg = G.battle.sandWormSegments[i]
                if seg.hidden then
                    holeCol, holeRow = seg.col, seg.row
                    break
                end
            end
        end
        if holeCol and holeRow then
            local gt = G.time or 0
            local px, py = HexGrid.HexToPixel(holeCol, holeRow, hexSize, ox, oy)
            local pitR = hexSize * 0.55

            -- 外圈：大范围沙土堆积（浅棕色柔和扩散）
            nvgBeginPath(nvg)
            nvgCircle(nvg, px, py, pitR * 1.6)
            nvgFillPaint(nvg, nvgRadialGradient(nvg, px, py,
                pitR * 0.6, pitR * 1.6,
                nvgRGBA(160, 120, 55, 130),
                nvgRGBA(160, 120, 55, 0)))
            nvgFill(nvg)

            -- 沙坑主体（深色凹陷）
            nvgBeginPath(nvg)
            nvgCircle(nvg, px, py, pitR)
            nvgFillPaint(nvg, nvgRadialGradient(nvg, px, py,
                0, pitR,
                nvgRGBA(35, 22, 8, 200),
                nvgRGBA(90, 60, 25, 120)))
            nvgFill(nvg)

            -- 坑口凸起边缘（沙土堆高亮环）
            nvgBeginPath(nvg)
            nvgCircle(nvg, px, py, pitR * 1.05)
            nvgStrokeColor(nvg, nvgRGBA(180, 140, 60, 160))
            nvgStrokeWidth(nvg, 3.5)
            nvgStroke(nvg)

            -- 内部深色描边
            nvgBeginPath(nvg)
            nvgCircle(nvg, px, py, pitR * 0.7)
            nvgStrokeColor(nvg, nvgRGBA(50, 30, 10, 140))
            nvgStrokeWidth(nvg, 2.0)
            nvgStroke(nvg)

            -- 辐射裂缝（6条，从坑口向外延伸）
            for ci = 1, 6 do
                local angle = (ci / 6) * math.pi * 2 + holeCol * 0.7
                local innerR = pitR * 0.8
                local outerR = pitR * (1.3 + 0.2 * math.sin(ci * 1.7))
                local ix = px + math.cos(angle) * innerR
                local iy = py + math.sin(angle) * innerR
                local ex = px + math.cos(angle) * outerR
                local ey = py + math.sin(angle) * outerR
                nvgBeginPath(nvg)
                nvgMoveTo(nvg, ix, iy)
                nvgLineTo(nvg, ex, ey)
                nvgStrokeColor(nvg, nvgRGBA(100, 65, 25, 120))
                nvgStrokeWidth(nvg, 1.8)
                nvgStroke(nvg)
            end

            -- 沙粒从坑口向外飞溅动画
            for si = 1, 8 do
                local angle = (si / 8) * math.pi * 2 + gt * 0.5 + si * 0.3
                local dist = pitR * (1.1 + 0.15 * math.sin(gt * 2.0 + si * 1.5))
                local sx2 = px + math.cos(angle) * dist
                local sy2 = py + math.sin(angle) * dist
                local pSize = hexSize * (0.03 + 0.01 * math.sin(gt * 3.0 + si))
                nvgBeginPath(nvg)
                nvgCircle(nvg, sx2, sy2, pSize)
                nvgFillColor(nvg, nvgRGBA(200, 155, 70, 140))
                nvgFill(nvg)
            end

            -- 坑内蠕动暗影（暗示地下有东西在爬出）
            local wriggle = math.sin(gt * 3.5) * pitR * 0.1
            nvgBeginPath(nvg)
            nvgEllipse(nvg, px + wriggle, py, pitR * 0.4, pitR * 0.3)
            nvgFillColor(nvg, nvgRGBA(15, 8, 3, math.floor(140 + 50 * math.sin(gt * 4.0))))
            nvgFill(nvg)
        end
    end

    -- 7.05 沙虫身体连接管（宽体管道，匹配鳞甲风格）
    if G.battle.sandWormSegments and #G.battle.sandWormSegments >= 2 then
        local segs = G.battle.sandWormSegments
        local bossHead = segs[1]
        -- 遁地状态不绘制连线
        if not (bossHead.burrowed or bossHead.hidden) then
        local gt = G.time or 0
        for i = 1, #segs - 1 do
            local s1 = segs[i]
            local s2 = segs[i + 1]
            if s1.hp > 0 and s2.hp > 0 and not s1.hidden and not s2.hidden
               and not (s1.emergeDelay and s1.emergeDelay > 0)
               and not (s2.emergeDelay and s2.emergeDelay > 0) then
                local x1, y1 = HexGrid.HexToPixel(s1.col, s1.row, hexSize, ox, oy)
                local x2, y2 = HexGrid.HexToPixel(s2.col, s2.row, hexSize, ox, oy)

                -- 计算连接管宽度（从头到尾逐渐变细，但比之前更宽）
                local segScale1 = math.max(0.55, 1.0 - (i - 1) * 0.06)
                local segScale2 = math.max(0.55, 1.0 - i * 0.06)
                local drawR = hexSize * 0.5 * 1.25  -- boss draw radius
                local tubeW1 = drawR * segScale1 * 1.4  -- 起始宽度（接近段体直径）
                local tubeW2 = drawR * segScale2 * 1.4  -- 结束宽度
                local tubeW = (tubeW1 + tubeW2) * 0.5   -- 平均宽度

                -- 计算方向向量和法向量
                local dx = x2 - x1
                local dy = y2 - y1
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist > 1 then
                    local nx = -dy / dist  -- 法向量
                    local ny = dx / dist
                    local pulse = math.sin(gt * 2.0 + i * 0.8) * 0.08 + 0.92

                    -- 管道外形（用四边形路径绘制梯形管道）
                    local hw1 = tubeW1 * 0.5 * pulse
                    local hw2 = tubeW2 * 0.5 * pulse
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, x1 + nx * hw1, y1 + ny * hw1)
                    nvgLineTo(nvg, x2 + nx * hw2, y2 + ny * hw2)
                    nvgLineTo(nvg, x2 - nx * hw2, y2 - ny * hw2)
                    nvgLineTo(nvg, x1 - nx * hw1, y1 - ny * hw1)
                    nvgClosePath(nvg)

                    -- 填充：深沙色渐变
                    local dimFactor = math.max(0.6, 1.0 - (i - 1) * 0.07)
                    local midX, midY = (x1 + x2) * 0.5, (y1 + y2) * 0.5
                    local tubeFill = nvgLinearGradient(nvg,
                        midX + nx * tubeW * 0.4, midY + ny * tubeW * 0.4,
                        midX - nx * tubeW * 0.4, midY - ny * tubeW * 0.4,
                        nvgRGBA(math.floor(200 * dimFactor), math.floor(160 * dimFactor), math.floor(65 * dimFactor), 230),
                        nvgRGBA(math.floor(140 * dimFactor), math.floor(100 * dimFactor), math.floor(35 * dimFactor), 220))
                    nvgFillPaint(nvg, tubeFill)
                    nvgFill(nvg)

                    -- 管道描边（深褐色粗边，鳞甲质感）
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, x1 + nx * hw1, y1 + ny * hw1)
                    nvgLineTo(nvg, x2 + nx * hw2, y2 + ny * hw2)
                    nvgStrokeColor(nvg, nvgRGBA(100, 70, 30, 180))
                    nvgStrokeWidth(nvg, 2.0)
                    nvgStroke(nvg)
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, x1 - nx * hw1, y1 - ny * hw1)
                    nvgLineTo(nvg, x2 - nx * hw2, y2 - ny * hw2)
                    nvgStrokeColor(nvg, nvgRGBA(100, 70, 30, 180))
                    nvgStrokeWidth(nvg, 2.0)
                    nvgStroke(nvg)

                    -- 横向褶皱环纹（2-3条，沿管道长度分布）
                    local ringCount = (dist > hexSize * 0.8) and 3 or 2
                    for ri = 1, ringCount do
                        local t = ri / (ringCount + 1)
                        local rx = x1 + dx * t
                        local ry = y1 + dy * t
                        local rhw = hw1 + (hw2 - hw1) * t  -- 插值宽度
                        nvgBeginPath(nvg)
                        nvgMoveTo(nvg, rx + nx * rhw * 0.9, ry + ny * rhw * 0.9)
                        nvgLineTo(nvg, rx - nx * rhw * 0.9, ry - ny * rhw * 0.9)
                        nvgStrokeColor(nvg, nvgRGBA(math.floor(130 * dimFactor), math.floor(90 * dimFactor), 25, 130))
                        nvgStrokeWidth(nvg, 1.5)
                        nvgStroke(nvg)
                        -- 褶皱高光
                        nvgBeginPath(nvg)
                        local offX = dx / dist * 1.5
                        local offY = dy / dist * 1.5
                        nvgMoveTo(nvg, rx + nx * rhw * 0.7 + offX, ry + ny * rhw * 0.7 + offY)
                        nvgLineTo(nvg, rx - nx * rhw * 0.7 + offX, ry - ny * rhw * 0.7 + offY)
                        nvgStrokeColor(nvg, nvgRGBA(220, 190, 100, 50))
                        nvgStrokeWidth(nvg, 1.0)
                        nvgStroke(nvg)
                    end

                    -- 中心橙色发光线（模拟裂缝光芒）
                    local glowPulse = math.sin(gt * 3.0 + i * 1.2) * 0.3 + 0.7
                    local glowAlpha = math.floor(120 * glowPulse * dimFactor)
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, x1, y1)
                    nvgLineTo(nvg, x2, y2)
                    nvgStrokeColor(nvg, nvgRGBA(255, 150, 30, glowAlpha))
                    nvgStrokeWidth(nvg, tubeW * 0.12)
                    nvgLineCap(nvg, NVG_ROUND)
                    nvgStroke(nvg)
                    -- 核心亮线
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, x1, y1)
                    nvgLineTo(nvg, x2, y2)
                    nvgStrokeColor(nvg, nvgRGBA(255, 200, 80, math.floor(glowAlpha * 0.5)))
                    nvgStrokeWidth(nvg, tubeW * 0.04)
                    nvgLineCap(nvg, NVG_ROUND)
                    nvgStroke(nvg)
                end
            end
        end
        end -- if not burrowed/hidden
    end

    -- 7.06 沙虫遁地中提示（固定位置和大小，不随镜头缩放浮动）
    if G.battle.sandWormSegments and #G.battle.sandWormSegments >= 1 then
        local bossHead = G.battle.sandWormSegments[1]
        if bossHead and (bossHead.burrowed or bossHead.burrowCasting) and bossHead.hp > 0 then
            local gt = G.time or 0
            -- 使用 widget 绝对坐标（固定屏幕位置，不随相机/缩放变化）
            local tipX = l.x + 12
            local tipY = l.y + 90
            -- 固定像素尺寸，不随 hexSize 缩放
            local labelW = 260
            local labelH = 32
            local bgAlpha = math.floor(160 + 40 * math.sin(gt * 3.0))
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, tipX, tipY, labelW, labelH, 6)
            nvgFillColor(nvg, nvgRGBA(40, 30, 15, bgAlpha))
            nvgFill(nvg)
            -- 文字（固定字号）
            nvgFontSize(nvg, 15)
            nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            local textAlpha = math.floor(200 + 55 * math.sin(gt * 2.5))
            nvgFillColor(nvg, nvgRGBA(255, 210, 100, textAlpha))
            local textX = tipX + 8
            local textY = tipY + labelH / 2
            if bossHead.burrowCasting then
                nvgText(nvg, textX, textY, "⏳ 沙虫正在准备遁地...")
            else
                local remain = bossHead.burrowTimer or 0
                nvgText(nvg, textX, textY, "🕳️ 沙虫遁地中... (" .. remain .. "回合后钻出)")
            end
        end
    end

    -- 7.06b 沙虫钻出预警（红色描边闪烁，7格AOE范围）
    if G.battle.sandWormEmergeWarning then
        local warn = G.battle.sandWormEmergeWarning
        local warnTiles = warn.tiles or { { col = warn.col, row = warn.row } }
        local pulse = 0.6 + 0.4 * math.sin((G.time or 0) * 8)  -- 快速闪烁
        for tIdx, tile in ipairs(warnTiles) do
            if HexGrid.InBounds(tile.col, tile.row) then
                local tx, ty = HexGrid.HexToPixel(tile.col, tile.row, hexSize, ox, oy)
                -- 红色描边六边形
                nvgBeginPath(nvg)
                local rWarn = hexSize * 0.52
                for vi = 0, 5 do
                    local angle = math.pi / 3 * vi - math.pi / 6
                    local vx = tx + rWarn * math.cos(angle)
                    local vy = ty + rWarn * math.sin(angle)
                    if vi == 0 then nvgMoveTo(nvg, vx, vy) else nvgLineTo(nvg, vx, vy) end
                end
                nvgClosePath(nvg)
                -- 中心格描边更粗更亮
                local isCenter = (tile.col == warn.col and tile.row == warn.row)
                local strokeAlpha = isCenter and math.floor(240 * pulse) or math.floor(180 * pulse)
                local strokeW = isCenter and 4.0 or 2.5
                nvgStrokeColor(nvg, nvgRGBA(255, 40, 20, strokeAlpha))
                nvgStrokeWidth(nvg, strokeW)
                nvgStroke(nvg)
                -- 半透明红色填充
                nvgBeginPath(nvg)
                local rFill = hexSize * 0.46
                for vi = 0, 5 do
                    local angle = math.pi / 3 * vi - math.pi / 6
                    local vx = tx + rFill * math.cos(angle)
                    local vy = ty + rFill * math.sin(angle)
                    if vi == 0 then nvgMoveTo(nvg, vx, vy) else nvgLineTo(nvg, vx, vy) end
                end
                nvgClosePath(nvg)
                local fillAlpha = isCenter and math.floor(80 * pulse) or math.floor(40 * pulse)
                nvgFillColor(nvg, nvgRGBA(255, 30, 20, fillAlpha))
                nvgFill(nvg)
                -- 仅中心格显示警告图标
                if isCenter then
                    nvgFontFace(nvg, "emoji")
                    nvgFontSize(nvg, hexSize * 0.5)
                    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(nvg, nvgRGBA(255, 60, 30, math.floor(220 * pulse)))
                    nvgText(nvg, tx, ty, "⚠️")
                end
            end
        end
    end

    -- 7.065 Boss AOE预警渲染（通用：剧毒喷射/地脉喷发/珊瑚雨）
    if G.battle.bossAoeWarning then
        local warn = G.battle.bossAoeWarning
        local wColor = warn.color or {255, 80, 0}
        local pulse = 0.6 + 0.4 * math.sin((G.time or 0) * 6)
        for _, tile in ipairs(warn.tiles or {}) do
            if HexGrid.InBounds(tile.col, tile.row) then
                local tx, ty = HexGrid.HexToPixel(tile.col, tile.row, hexSize, ox, oy)
                -- 描边六边形
                nvgBeginPath(nvg)
                local rWarn = hexSize * 0.52
                for vi = 0, 5 do
                    local angle = math.pi / 3 * vi - math.pi / 6
                    local vx = tx + rWarn * math.cos(angle)
                    local vy = ty + rWarn * math.sin(angle)
                    if vi == 0 then nvgMoveTo(nvg, vx, vy) else nvgLineTo(nvg, vx, vy) end
                end
                nvgClosePath(nvg)
                local isCenter = (tile.col == warn.centerCol and tile.row == warn.centerRow)
                local strokeAlpha = isCenter and math.floor(230 * pulse) or math.floor(160 * pulse)
                local strokeW = isCenter and 3.5 or 2.0
                nvgStrokeColor(nvg, nvgRGBA(wColor[1], wColor[2], wColor[3], strokeAlpha))
                nvgStrokeWidth(nvg, strokeW)
                nvgStroke(nvg)
                -- 半透明填充
                nvgBeginPath(nvg)
                local rFill = hexSize * 0.46
                for vi = 0, 5 do
                    local angle = math.pi / 3 * vi - math.pi / 6
                    local vx = tx + rFill * math.cos(angle)
                    local vy = ty + rFill * math.sin(angle)
                    if vi == 0 then nvgMoveTo(nvg, vx, vy) else nvgLineTo(nvg, vx, vy) end
                end
                nvgClosePath(nvg)
                local fillAlpha = isCenter and math.floor(60 * pulse) or math.floor(30 * pulse)
                nvgFillColor(nvg, nvgRGBA(wColor[1], wColor[2], wColor[3], fillAlpha))
                nvgFill(nvg)
                -- 中心格显示图标
                if isCenter and warn.icon then
                    nvgFontFace(nvg, "emoji")
                    nvgFontSize(nvg, hexSize * 0.5)
                    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(nvg, nvgRGBA(wColor[1], wColor[2], wColor[3], math.floor(220 * pulse)))
                    nvgText(nvg, tx, ty, warn.icon)
                end
            end
        end
    end

    -- 7.07 沙虫钻出AOE红光高亮
    if G.battle.sandWormEmergeAOE and G.battle.sandWormEmergeAOE.timer > 0 then
        local aoeData = G.battle.sandWormEmergeAOE
        local progress = aoeData.timer / aoeData.maxTimer  -- 1→0 fade out
        local pulseAlpha = math.floor(120 * progress * (0.7 + 0.3 * math.sin((G.time or 0) * 12)))
        for _, tile in ipairs(aoeData.tiles) do
            if HexGrid.InBounds(tile.col, tile.row) then
                local tx, ty = HexGrid.HexToPixel(tile.col, tile.row, hexSize, ox, oy)
                -- 外圈发光边框（更大、更醒目）
                nvgBeginPath(nvg)
                local rOuter = hexSize * 0.52
                for vi = 0, 5 do
                    local angle = math.pi / 3 * vi - math.pi / 6
                    local vx = tx + rOuter * math.cos(angle)
                    local vy = ty + rOuter * math.sin(angle)
                    if vi == 0 then nvgMoveTo(nvg, vx, vy) else nvgLineTo(nvg, vx, vy) end
                end
                nvgClosePath(nvg)
                nvgStrokeColor(nvg, nvgRGBA(255, 50, 20, math.floor(220 * progress)))
                nvgStrokeWidth(nvg, 3.5)
                nvgStroke(nvg)
                -- 红色六边形填充
                nvgBeginPath(nvg)
                local r = hexSize * 0.46
                for vi = 0, 5 do
                    local angle = math.pi / 3 * vi - math.pi / 6
                    local vx = tx + r * math.cos(angle)
                    local vy = ty + r * math.sin(angle)
                    if vi == 0 then nvgMoveTo(nvg, vx, vy) else nvgLineTo(nvg, vx, vy) end
                end
                nvgClosePath(nvg)
                nvgFillColor(nvg, nvgRGBA(220, 40, 30, pulseAlpha))
                nvgFill(nvg)
                -- 内层亮边
                nvgStrokeColor(nvg, nvgRGBA(255, 120, 60, math.floor(200 * progress)))
                nvgStrokeWidth(nvg, 1.5)
                nvgStroke(nvg)
            end
        end
        -- 递减计时器
        aoeData.timer = aoeData.timer - (G.dt or 0.016)
        if aoeData.timer <= 0 then
            G.battle.sandWormEmergeAOE = nil
        end
    end

    -- 7.07 沙虫钻入动画处理（身体段逐节滑入洞口后隐藏）
    if G.battle.sandWormSegments and G.battle.sandWormDiveHole then
        local dt = G.dt or 0.016
        local allDived = true
        for _, seg in ipairs(G.battle.sandWormSegments) do
            if seg.diveDelay then
                allDived = false
                if seg.diveDelay > 0 then
                    seg.diveDelay = seg.diveDelay - dt
                else
                    -- delay结束，开始0.7秒滑动动画（从当前位置滑入洞口，较慢以保持整体感）
                    if not seg.diveProgress then
                        seg.diveProgress = 0
                        seg.diveFromCol = seg.col
                        seg.diveFromRow = seg.row
                    end
                    seg.diveProgress = seg.diveProgress + dt / 0.7
                    if seg.diveProgress >= 1.0 then
                        -- 滑入完成，隐藏该节
                        seg.hidden = true
                        seg.diveDelay = nil
                        seg.diveProgress = nil
                        seg.diveFromCol = nil
                        seg.diveFromRow = nil
                        seg.diveTargetCol = nil
                        seg.diveTargetRow = nil
                    end
                end
            end
        end
        -- 所有段都钻入完毕，清理洞口标记
        if allDived then
            G.battle.sandWormDiveHole = nil
        end
    end

    -- 7.08 沙虫爬出动画处理（身体段从洞口爬出到目标位置）
    if G.battle.sandWormSegments then
        local dt = G.dt or 0.016
        for _, seg in ipairs(G.battle.sandWormSegments) do
            if seg.emergeDelay and seg.emergeDelay > 0 then
                seg.emergeDelay = seg.emergeDelay - dt
                if seg.emergeDelay <= 0 then
                    seg.emergeDelay = nil
                    -- 不清除 emergeFromCol/Row，让滑动阶段继续使用
                end
            elseif seg.emergeFromCol and not seg.emergeDelay then
                -- delay结束后，开始0.4秒的滑动动画（从洞口到目标位置）
                if not seg.emergeProgress then
                    seg.emergeProgress = 0
                end
                seg.emergeProgress = seg.emergeProgress + dt / 0.4
                if seg.emergeProgress >= 1.0 then
                    seg.emergeFromCol = nil
                    seg.emergeFromRow = nil
                    seg.emergeProgress = nil
                end
            end
        end
    end
    -- 7.09 沙虫洞口视觉效果（显示虫身从地下伸出，避免看起来凭空截断）
    if G.battle.sandWormEmergeHole then
        local hole = G.battle.sandWormEmergeHole
        local hx, hy = HexGrid.HexToPixel(hole.col, hole.row, hexSize, ox, oy)
        local gt = G.time or 0
        local holeR = hexSize * 0.48  -- 洞口半径（略小于格子）

        -- 0) 从最后一个可见段到洞口的"渐入地下"连接管
        if G.battle.sandWormSegments then
            local segs = G.battle.sandWormSegments
            local lastVisible = nil
            local lastVisIdx = 0
            for i = #segs, 1, -1 do
                if not segs[i].hidden and segs[i].hp > 0
                   and not (segs[i].emergeDelay and segs[i].emergeDelay > 0) then
                    lastVisible = segs[i]
                    lastVisIdx = i
                    break
                end
            end
            if lastVisible and (lastVisible.col ~= hole.col or lastVisible.row ~= hole.row) then
                local sx, sy = HexGrid.HexToPixel(lastVisible.col, lastVisible.row, hexSize, ox, oy)
                local drawR = hexSize * 0.5 * 1.25
                local segScale = math.max(0.55, 1.0 - (lastVisIdx - 1) * 0.06)
                local tubeStart = drawR * segScale * 1.4
                local tubeEnd = tubeStart * 0.4  -- 越靠近洞口越细（钻入地下效果）
                -- 渐变管道：从可见段到洞口
                local dx, dy = hx - sx, hy - sy
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist > 1 then
                    local nx, ny = -dy / dist, dx / dist
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, sx + nx * tubeStart * 0.5, sy + ny * tubeStart * 0.5)
                    nvgLineTo(nvg, hx + nx * tubeEnd * 0.5, hy + ny * tubeEnd * 0.5)
                    nvgLineTo(nvg, hx - nx * tubeEnd * 0.5, hy - ny * tubeEnd * 0.5)
                    nvgLineTo(nvg, sx - nx * tubeStart * 0.5, sy - ny * tubeStart * 0.5)
                    nvgClosePath(nvg)
                    -- 渐变填充：身体色到暗色
                    nvgFillPaint(nvg, nvgLinearGradient(nvg, sx, sy, hx, hy,
                        nvgRGBA(180, 140, 60, 200),
                        nvgRGBA(80, 50, 20, 160)))
                    nvgFill(nvg)
                    -- 细腻鳞甲纹理线
                    nvgStrokeColor(nvg, nvgRGBA(120, 80, 30, 100))
                    nvgStrokeWidth(nvg, 1.5)
                    nvgStroke(nvg)
                end
            end
        end

        -- 1) 外圈：扰动的沙土堆（浅棕色环形，模拟掘出的沙土）
        nvgBeginPath(nvg)
        nvgCircle(nvg, hx, hy, holeR * 1.3)
        nvgFillPaint(nvg, nvgRadialGradient(nvg, hx, hy,
            holeR * 0.8, holeR * 1.3,
            nvgRGBA(160, 120, 60, 120),
            nvgRGBA(160, 120, 60, 0)))
        nvgFill(nvg)

        -- 2) 洞口暗色椭圆（深色的地洞）
        nvgBeginPath(nvg)
        nvgEllipse(nvg, hx, hy + holeR * 0.1, holeR * 0.75, holeR * 0.55)
        nvgFillPaint(nvg, nvgRadialGradient(nvg, hx, hy + holeR * 0.1,
            0, holeR * 0.5,
            nvgRGBA(15, 8, 5, 220),
            nvgRGBA(50, 30, 15, 180)))
        nvgFill(nvg)

        -- 3) 洞口边缘裂纹（深色描边环）
        nvgBeginPath(nvg)
        nvgEllipse(nvg, hx, hy + holeR * 0.1, holeR * 0.78, holeR * 0.58)
        nvgStrokeColor(nvg, nvgRGBA(80, 50, 20, 160))
        nvgStrokeWidth(nvg, 2.5)
        nvgStroke(nvg)

        -- 4) 散落的沙粒（围绕洞口的小圆点，轻微动态）
        nvgFillColor(nvg, nvgRGBA(180, 140, 70, 100))
        for i = 1, 8 do
            local angle = (i / 8) * math.pi * 2 + gt * 0.3
            local dist = holeR * (1.0 + 0.15 * math.sin(gt * 2.0 + i * 1.7))
            local px = hx + math.cos(angle) * dist
            local py = hy + math.sin(angle) * dist * 0.7
            nvgBeginPath(nvg)
            nvgCircle(nvg, px, py, hexSize * 0.03)
            nvgFill(nvg)
        end

        -- 5) 洞口内部微弱的蠕动暗影（暗示地下有东西）
        local wriggle = math.sin(gt * 4.0) * holeR * 0.08
        nvgBeginPath(nvg)
        nvgEllipse(nvg, hx + wriggle, hy + holeR * 0.05, holeR * 0.4, holeR * 0.25)
        nvgFillColor(nvg, nvgRGBA(10, 5, 2, math.floor(100 + 40 * math.sin(gt * 3.0))))
        nvgFill(nvg)
    end

    -- 清理洞口标记（所有身体段都已爬出后，且boss不再处于逐步钻出状态）
    if G.battle.sandWormEmergeHole then
        local boss = G.battle.boss
        local stillEmerging = boss and boss.emerging
        if not stillEmerging then
            local allDone = true
            if G.battle.sandWormSegments then
                for _, seg in ipairs(G.battle.sandWormSegments) do
                    if seg.emergeDelay or seg.emergeFromCol then
                        allDone = false; break
                    end
                end
            end
            if allDone then G.battle.sandWormEmergeHole = nil end
        end
    end

    -- 7. 绘制所有棋子（支持移动动画插值）
    local pieceRadius = hexSize * 0.42
    for _, p in ipairs(board.pieces) do
        if p.hidden or (p.emergeDelay and p.emergeDelay > 0) then goto continue_piece end
        if p.hp > 0 or p._dead then
            -- 注入动画状态临时字段供精灵图帧选择 (所有棋子都需要)
            p._gameTime = G.time or 0
            if p.team == "hero" then
                p._hitFlash = G.battle.hitFlash or 0
            elseif p.team == "enemy" then
                p._hitFlash = p.hitFlash or 0
            end
            -- 注入 Boss 技能攻击动画字段
            p._skillAnim     = p.skillAnim     or 0
            p._skillAnimType = p.skillAnimType or ""

            local cx, cy
            if p.animTimer and p.animTimer > 0 then
                -- ease-out 插值: 从旧位置滑到新位置
                local t = 1.0 - p.animTimer / p.animMaxTimer  -- 0→1
                t = 1.0 - (1.0 - t) * (1.0 - t)  -- ease-out
                local fromX, fromY = HexGrid.HexToPixel(p.animFromCol, p.animFromRow, hexSize, ox, oy)
                local toX, toY = HexGrid.HexToPixel(p.col, p.row, hexSize, ox, oy)
                cx = fromX + (toX - fromX) * t
                cy = fromY + (toY - fromY) * t
                -- 跳跃弧线: 抛物线向上偏移（combo越高弧线越高）
                if p.animIsJump then
                    local arcMul = p.animArcScale or 1.0
                    local arc = math.sin(t * math.pi) * hexSize * 1.2 * arcMul
                    cy = cy - arc
                end
            elseif p.diveProgress and p.diveFromCol then
                -- 沙虫身体段钻入动画：从当前位置滑向洞口并缩小
                local t = math.min(1.0, p.diveProgress)
                t = t * t * (3.0 - 2.0 * t)  -- smoothstep
                local fromX, fromY = HexGrid.HexToPixel(p.diveFromCol, p.diveFromRow, hexSize, ox, oy)
                local toX, toY = HexGrid.HexToPixel(p.diveTargetCol, p.diveTargetRow, hexSize, ox, oy)
                cx = fromX + (toX - fromX) * t
                cy = fromY + (toY - fromY) * t
                -- 随着接近洞口，棋子缩小（模拟钻入地下效果）
                p._diveScale = 1.0 - t * 0.6  -- 从1.0缩小到0.4
            elseif p.emergeFromCol and p.emergeProgress then
                -- 沙虫身体段爬出动画：从洞口平滑移动到目标位置
                local t = math.min(1.0, p.emergeProgress)
                t = t * t * (3.0 - 2.0 * t)  -- smoothstep
                local fromX, fromY = HexGrid.HexToPixel(p.emergeFromCol, p.emergeFromRow, hexSize, ox, oy)
                local toX, toY = HexGrid.HexToPixel(p.col, p.row, hexSize, ox, oy)
                cx = fromX + (toX - fromX) * t
                cy = fromY + (toY - fromY) * t
                -- 爬出时从小变大（从洞口挤出效果）
                p._diveScale = 0.4 + t * 0.6  -- 从0.4放大到1.0
            else
                cx, cy = HexGrid.HexToPixel(p.col, p.row, hexSize, ox, oy)
            end
            -- 疾梭鱼速度拖影：移动动画时，在身后画3个渐隐光圈
            if p.enemyType == "swift_barracuda" and p.animTimer and p.animTimer > 0 then
                local fromX, fromY = HexGrid.HexToPixel(p.animFromCol, p.animFromRow, hexSize, ox, oy)
                local trailCount = 3
                for ti = 1, trailCount do
                    local tt = (ti / (trailCount + 1))  -- 0.25, 0.5, 0.75
                    local trailX = fromX + (cx - fromX) * tt
                    local trailY = fromY + (cy - fromY) * tt
                    local trailAlpha = math.floor(80 * (1.0 - tt))  -- 越靠后越淡
                    local trailR = pieceRadius * (0.55 - ti * 0.1)
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, trailX, trailY, trailR)
                    nvgFillColor(nvg, nvgRGBA(100, 200, 255, trailAlpha))
                    nvgFill(nvg)
                end
            end
            -- 流沙推开受击效果：抖动 + 沙尘包裹
            if p.sandPushed and p.animTimer and p.animTimer > 0 then
                local gt = G.time or 0
                local pushProgress = 1.0 - p.animTimer / p.animMaxTimer  -- 0→1
                -- 受击抖动（垂直于运动方向的快速震动，越接近结束越弱）
                local shakeStrength = (1.0 - pushProgress) * hexSize * 0.12
                local shakeFreq = 25.0
                local shakeOff = math.sin(gt * shakeFreq) * shakeStrength
                -- 计算垂直于运动方向的法线
                local fromX, fromY = HexGrid.HexToPixel(p.animFromCol, p.animFromRow, hexSize, ox, oy)
                local toX, toY = HexGrid.HexToPixel(p.col, p.row, hexSize, ox, oy)
                local dx = toX - fromX
                local dy = toY - fromY
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist > 0.1 then
                    local nx = -dy / dist  -- 法线方向
                    local ny = dx / dist
                    cx = cx + nx * shakeOff
                    cy = cy + ny * shakeOff
                end
                -- 沙尘包裹（跟随英雄的旋转沙粒群）
                local wrapAlpha = math.floor((1.0 - pushProgress * 0.7) * 200)
                if wrapAlpha > 10 then
                    for si = 1, 12 do
                        local angle = si * 0.524 + gt * 6.0 + si * 0.8
                        local sandDist = pieceRadius * (0.6 + 0.4 * math.sin(gt * 4.0 + si * 1.3))
                        local sx = cx + math.cos(angle) * sandDist
                        local sy = cy + math.sin(angle) * sandDist
                        local sAlpha = math.floor(wrapAlpha * (0.5 + 0.5 * math.sin(si * 2.1 + gt * 3.0)))
                        local sSize = 2.0 + math.sin(si * 1.7) * 1.5
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, sx, sy, sSize)
                        nvgFillColor(nvg, nvgRGBA(230, 180, 50, sAlpha))
                        nvgFill(nvg)
                    end
                    -- 淡黄色沙尘光晕（半透明圆形底层）
                    local glowR = pieceRadius * 1.3 * (1.0 - pushProgress * 0.4)
                    local glowAlpha = math.floor((1.0 - pushProgress) * 60)
                    local sandGlow = nvgRadialGradient(nvg, cx, cy, pieceRadius * 0.3, glowR,
                        nvgRGBA(255, 200, 60, glowAlpha), nvgRGBA(200, 150, 30, 0))
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, cx, cy, glowR)
                    nvgFillPaint(nvg, sandGlow)
                    nvgFill(nvg)
                end
            end
            -- 应用钻入/爬出缩放效果
            local drawRadius = pieceRadius
            if p._diveScale then
                drawRadius = pieceRadius * p._diveScale
                p._diveScale = nil  -- 一次性字段，用完清理
            end
            HexGrid.DrawPiece(nvg, cx, cy, drawRadius, p)

            -- 冰霜冻结蓝色遮罩（冻结中的敌人覆盖冰蓝色半透明层 + 冰晶边框）
            if p.team == "enemy" and p.hp > 0 and (p._frozenTurns or 0) > 0 then
                local ft = G.time or 0
                local fPulse = math.sin(ft * 3.0) * 0.15 + 0.85
                local frostR = drawRadius * 1.05

                -- 冰蓝色半透明圆形遮罩
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, frostR)
                nvgFillColor(nvg, nvgRGBA(60, 160, 255, math.floor(80 * fPulse)))
                nvgFill(nvg)

                -- 冰晶边框（双层）
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, frostR)
                nvgStrokeColor(nvg, nvgRGBA(120, 200, 255, math.floor(200 * fPulse)))
                nvgStrokeWidth(nvg, 2.5)
                nvgStroke(nvg)

                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, frostR * 1.1)
                nvgStrokeColor(nvg, nvgRGBA(180, 230, 255, math.floor(100 * fPulse)))
                nvgStrokeWidth(nvg, 1.2)
                nvgStroke(nvg)

                -- 小冰晶粒子装饰（围绕圆周 6 个点）
                for i = 0, 5 do
                    local angle = i * math.pi / 3 + ft * 0.5
                    local px = cx + math.cos(angle) * frostR * 0.85
                    local py = cy + math.sin(angle) * frostR * 0.85
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, px, py, 2.5 * fPulse)
                    nvgFillColor(nvg, nvgRGBA(200, 240, 255, math.floor(180 * fPulse)))
                    nvgFill(nvg)
                end
            end
        end
        ::continue_piece::
    end

    -- 7.15 Boss 技能意图气泡（下回合将释放的技能图标）
    do
        local gt = G.time or 0
        for _, p in ipairs(board.pieces) do
            if p.isBoss and p.hp > 0 and not p.hidden and p.nextSkillKey and p.nextSkillIcon then
                local bx, by = HexGrid.HexToPixel(p.col, p.row, hexSize, ox, oy)
                -- 震颤偏移（蓄力时身体微震）
                local shakeX = math.sin(gt * 18.0) * 2.0
                local shakeY = math.cos(gt * 22.0) * 1.5
                -- 气泡悬浮位置：Boss上方
                local bubbleX = bx + shakeX
                local bubbleY = by - hexSize * 1.55 + math.sin(gt * 2.2) * 4 + shakeY
                local bubbleR  = hexSize * 0.38
                local nc = p.nextSkillColor or {220, 50, 50}
                local nr, ng2, nb3 = nc[1], nc[2], nc[3]
                -- 脉动
                local pulse = 0.6 + math.abs(math.sin(gt * 5.0)) * 0.4
                local bgAlpha = math.floor(200 * pulse)

                -- 气泡背景（深色圆）
                nvgBeginPath(nvg)
                nvgCircle(nvg, bubbleX, bubbleY, bubbleR)
                nvgFillColor(nvg, nvgRGBA(10, 5, 20, bgAlpha))
                nvgFill(nvg)

                -- 气泡边框（主题色，脉动）
                nvgBeginPath(nvg)
                nvgCircle(nvg, bubbleX, bubbleY, bubbleR)
                nvgStrokeColor(nvg, nvgRGBA(nr, ng2, nb3, bgAlpha))
                nvgStrokeWidth(nvg, 2.5 * pulse)
                nvgStroke(nvg)

                -- 外发光圈
                local glowPaint = nvgRadialGradient(nvg,
                    bubbleX, bubbleY, bubbleR * 0.6, bubbleR * 1.8,
                    nvgRGBA(nr, ng2, nb3, math.floor(80 * pulse)),
                    nvgRGBA(nr, ng2, nb3, 0))
                nvgBeginPath(nvg)
                nvgCircle(nvg, bubbleX, bubbleY, bubbleR * 1.8)
                nvgFillPaint(nvg, glowPaint)
                nvgFill(nvg)

                -- 技能图标（大号 emoji）
                nvgFontSize(nvg, bubbleR * 1.4)
                nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(nvg, nvgRGBA(255, 255, 255, bgAlpha))
                nvgText(nvg, bubbleX, bubbleY, p.nextSkillIcon)

                -- 气泡尾巴（小三角，指向Boss）
                local tailY = bubbleY + bubbleR
                nvgBeginPath(nvg)
                nvgMoveTo(nvg, bubbleX - 5, tailY)
                nvgLineTo(nvg, bubbleX + 5, tailY)
                nvgLineTo(nvg, bubbleX, tailY + 8)
                nvgClosePath(nvg)
                nvgFillColor(nvg, nvgRGBA(10, 5, 20, bgAlpha))
                nvgFill(nvg)
                nvgStrokeColor(nvg, nvgRGBA(nr, ng2, nb3, bgAlpha))
                nvgStrokeWidth(nvg, 1.5)
                nvgStroke(nvg)

                -- "NEXT" 小标签
                nvgFontSize(nvg, 9)
                nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
                nvgFillColor(nvg, nvgRGBA(nr, ng2, nb3, math.floor(bgAlpha * 0.8)))
                nvgText(nvg, bubbleX, bubbleY - bubbleR - 2, "下回合")
            end
        end
    end

    -- 7.155 沙虫遁地读条进度条（burrowCasting阶段显示）
    do
        for _, p in ipairs(board.pieces) do
            if p.isBoss and p.burrowCasting and p.hp > 0 and not p.hidden then
                local bx, by = HexGrid.HexToPixel(p.col, p.row, hexSize, ox, oy)
                local gt = G.time or 0
                -- 进度条背景
                local barW = hexSize * 1.6
                local barH = 8
                local barX = bx - barW / 2
                local barY = by - hexSize * 0.9
                nvgBeginPath(nvg)
                nvgRoundedRect(nvg, barX, barY, barW, barH, 4)
                nvgFillColor(nvg, nvgRGBA(30, 20, 10, 200))
                nvgFill(nvg)
                -- 进度条填充（脉动动画模拟读条）
                local progress = math.min(1.0, (math.sin(gt * 4.0) * 0.15 + 0.85))
                nvgBeginPath(nvg)
                nvgRoundedRect(nvg, barX + 1, barY + 1, (barW - 2) * progress, barH - 2, 3)
                nvgFillColor(nvg, nvgRGBA(210, 160, 60, 220))
                nvgFill(nvg)
                -- 文字标签
                nvgFontSize(nvg, 11)
                nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
                nvgFillColor(nvg, nvgRGBA(255, 220, 120, 230))
                nvgText(nvg, bx, barY - 3, "⏳ 准备遁地")
            end
        end
    end

    -- 7.16 疾梭鱼"⚡3步"速度提示标签（玩家回合时显示在鱼身左上角）
    do
        local phase = G.battle.phase or ""
        if phase == "PLAYER_SELECT" or phase == "PLAYER_PLAN" then
            local gt = G.time or 0
            for _, p in ipairs(board.pieces) do
                if p.enemyType == "swift_barracuda" and p.hp > 0 then
                    local bx, by = HexGrid.HexToPixel(p.col, p.row, hexSize, ox, oy)
                    local steps = p.moveSteps or 3
                    -- 标签位置：鱼身左上角
                    local tagX = bx - pieceRadius * 0.55
                    local tagY = by - pieceRadius * 0.85
                    -- 脉动效果
                    local pulse = 0.75 + math.sin(gt * 4.0) * 0.25
                    local tagAlpha = math.floor(210 * pulse)
                    -- 胶囊背景
                    local tw, th = hexSize * 0.54, hexSize * 0.22
                    nvgBeginPath(nvg)
                    nvgRoundedRect(nvg, tagX - tw * 0.5, tagY - th * 0.5, tw, th, th * 0.5)
                    nvgFillColor(nvg, nvgRGBA(20, 20, 40, math.floor(tagAlpha * 0.85)))
                    nvgFill(nvg)
                    nvgStrokeColor(nvg, nvgRGBA(80, 200, 255, tagAlpha))
                    nvgStrokeWidth(nvg, 1.2)
                    nvgStroke(nvg)
                    -- 文字 "⚡Nx"
                    nvgFontSize(nvg, hexSize * 0.17)
                    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(nvg, nvgRGBA(120, 220, 255, tagAlpha))
                    nvgText(nvg, tagX, tagY, "⚡" .. steps .. "步")
                end
            end
        end
    end

    -- 7.2 绘制被棋子遮挡的道具角标（敌人站在道具格上时显示小图标提示）
    for _, item in ipairs(board.items) do
        -- 检查该道具位置是否有棋子
        local piece = HexGrid.GetPieceAt(board, item.col, item.row)
        if piece and piece.hp > 0 then
            local def = Battle.ITEM_TYPES[item.type]
            if def then
                local cx, cy = HexGrid.HexToPixel(item.col, item.row, hexSize, ox, oy)
                local badgeR = hexSize * 0.18
                local badgeX = cx + pieceRadius * 0.7
                local badgeY = cy + pieceRadius * 0.7
                -- 绿色圆形底标
                nvgBeginPath(nvg)
                nvgCircle(nvg, badgeX, badgeY, badgeR)
                nvgFillColor(nvg, nvgRGBA(40, 160, 80, 220))
                nvgFill(nvg)
                nvgStrokeColor(nvg, nvgRGBA(200, 255, 200, 200))
                nvgStrokeWidth(nvg, 1.0)
                nvgStroke(nvg)
                -- 道具小图标
                IconAtlas.DrawNVG(nvg, def.icon, badgeX, badgeY, badgeR * 1.6)
            end
        end
    end

    -- 7.3 绘制稻草人（如果存在）—— 直接绘制稻草人图标+动态特效
    if G.battle.scarecrowActive and G.battle.scarecrow and G.battle.scarecrow.hp > 0 then
        local sc = G.battle.scarecrow
        local scx, scy = HexGrid.HexToPixel(sc.col, sc.row, hexSize, ox, oy)
        local scRadius = pieceRadius * 1.0
        local t = G.time or 0
        local tauntPulse = math.sin(t * 4.0) * 0.3 + 0.7

        -- 1) 地面嘲讽光圈（圆形扩散波纹）
        local ripple1 = (t * 0.7) % 1.0
        local ripple2 = (t * 0.7 + 0.5) % 1.0
        for _, rp in ipairs({ripple1, ripple2}) do
            local rippleR = scRadius * 0.5 + rp * hexSize * 0.8
            local rippleA = math.floor((1.0 - rp) * 70)
            nvgBeginPath(nvg)
            nvgCircle(nvg, scx, scy + scRadius * 0.3, rippleR)
            nvgStrokeColor(nvg, nvgRGBA(255, 200, 60, rippleA))
            nvgStrokeWidth(nvg, 2)
            nvgStroke(nvg)
        end

        -- 2) 脚底柔和光晕（椭圆形）
        local glowA = math.floor(40 + 25 * tauntPulse)
        nvgSave(nvg)
        nvgTranslate(nvg, scx, scy + scRadius * 0.35)
        nvgScale(nvg, 1.0, 0.45)
        nvgBeginPath(nvg)
        nvgCircle(nvg, 0, 0, scRadius * 1.0)
        nvgFillColor(nvg, nvgRGBA(255, 200, 50, glowA))
        nvgFill(nvg)
        nvgRestore(nvg)

        -- 3) 飘浮稻草粒子（8颗小碎片绕稻草人飘散）
        for i = 1, 8 do
            local seed = i * 37
            local angle = (i / 8) * math.pi * 2 + t * (0.3 + (i % 3) * 0.15)
            local dist = scRadius * (0.6 + math.sin(t * 0.9 + seed) * 0.25)
            local py = math.sin(t * 1.5 + seed * 0.7) * scRadius * 0.3
            local px = scx + math.cos(angle) * dist
            local ppy = scy + math.sin(angle) * dist * 0.4 + py - scRadius * 0.2
            local pAlpha = math.floor(120 + math.sin(t * 2.0 + seed) * 60)
            local pSize = 2.0 + math.sin(t * 1.8 + i) * 0.8
            -- 小稻草碎片（短线段，随机角度）
            local rot = t * (1.0 + i * 0.3) + seed
            nvgSave(nvg)
            nvgTranslate(nvg, px, ppy)
            nvgRotate(nvg, rot)
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, -pSize, 0)
            nvgLineTo(nvg, pSize, 0)
            nvgStrokeColor(nvg, nvgRGBA(210, 180, 80, pAlpha))
            nvgStrokeWidth(nvg, 1.5)
            nvgStroke(nvg)
            nvgRestore(nvg)
        end

        -- 4) 稻草人图标（微摇晃 + 轻微浮动 + 背光圈）
        local sway = math.sin(t * 1.5) * 0.06  -- 左右摇晃角度
        local floatY = math.sin(t * 2.0) * 2.0 -- 上下浮动
        local iconCX, iconCY = scx, scy - scRadius * 0.15 + floatY

        -- 4a) 背光圆形光晕（暖黄色，让稻草人从深色背景跳出）
        local bgGlowR = scRadius * 1.5
        local bgGlowA = math.floor(90 + 30 * tauntPulse)
        nvgBeginPath(nvg)
        nvgCircle(nvg, iconCX, iconCY, bgGlowR)
        nvgFillPaint(nvg, nvgRadialGradient(nvg,
            iconCX, iconCY, bgGlowR * 0.2, bgGlowR,
            nvgRGBA(255, 220, 80, bgGlowA),
            nvgRGBA(255, 200, 50, 0)))
        nvgFill(nvg)

        -- 4b) 稻草人图标（放大显示，无外框）
        nvgSave(nvg)
        nvgTranslate(nvg, iconCX, iconCY)
        nvgRotate(nvg, sway)
        IconAtlas.DrawNVG(nvg, "board_scarecrow", 0, 0, scRadius * 3.2)
        nvgRestore(nvg)

        -- 5) "嘲讽中" 标签（稻草人上方，放大文字 + 呼吸效果）
        local labelFontSize = hexSize * 0.38
        nvgFontSize(nvg, labelFontSize)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        local labelY = scy - scRadius * 1.35 + floatY - 10
        local labelHalfW = 46
        local labelHalfH = 14
        -- 标签背景（半透明暗底 + 金色描边）
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, scx - labelHalfW, labelY - labelHalfH, labelHalfW * 2, labelHalfH * 2, 10)
        nvgFillColor(nvg, nvgRGBA(40, 30, 15, math.floor(180 * tauntPulse)))
        nvgFill(nvg)
        nvgStrokeColor(nvg, nvgRGBA(255, 220, 80, math.floor(200 * tauntPulse)))
        nvgStrokeWidth(nvg, 1.5)
        nvgStroke(nvg)
        -- 标签文字（发光 + 实体）
        nvgFontBlur(nvg, 3)
        nvgFillColor(nvg, nvgRGBA(255, 200, 50, math.floor(180 * tauntPulse)))
        nvgText(nvg, scx, labelY, "嘲讽中")
        nvgFontBlur(nvg, 0)
        nvgFillColor(nvg, nvgRGBA(255, 230, 100, 255))
        nvgText(nvg, scx, labelY, "嘲讽中")

        -- 6) 敌人→稻草人 嘲讽连线（红色 + 攻击方向箭头）
        local enemies = HexGrid.GetTeamPieces(board, "enemy")
        for _, e in ipairs(enemies) do
            if e.hp > 0 and not e.isSegment and not e.hidden then
                local ex, ey = HexGrid.HexToPixel(e.col, e.row, hexSize, ox, oy)
                local lineAlpha = math.floor(80 + 40 * tauntPulse)
                -- 红色连线
                nvgBeginPath(nvg)
                nvgMoveTo(nvg, ex, ey)
                nvgLineTo(nvg, scx, scy)
                nvgStrokeColor(nvg, nvgRGBA(230, 50, 50, lineAlpha))
                nvgStrokeWidth(nvg, 3)
                nvgStroke(nvg)
                -- 攻击方向箭头（敌人→稻草人，箭头在连线中点）
                local dx = scx - ex
                local dy = scy - ey
                local len = math.sqrt(dx * dx + dy * dy)
                if len > 1 then
                    local nx, ny = dx / len, dy / len  -- 单位方向
                    local arrowLen = math.min(hexSize * 0.35, len * 0.25)
                    -- 箭头尖端在连线中点偏稻草人方向半个箭头长度
                    local midX = (ex + scx) * 0.5
                    local midY = (ey + scy) * 0.5
                    local tipX = midX + nx * arrowLen * 0.5
                    local tipY = midY + ny * arrowLen * 0.5
                    -- 箭头两翼（垂直方向偏移）
                    local px, py = -ny, nx  -- 垂直向量
                    local wingW = arrowLen * 0.45
                    local tailX = tipX - nx * arrowLen
                    local tailY = tipY - ny * arrowLen
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, tipX, tipY)
                    nvgLineTo(nvg, tailX + px * wingW, tailY + py * wingW)
                    nvgLineTo(nvg, tailX - px * wingW, tailY - py * wingW)
                    nvgClosePath(nvg)
                    nvgFillColor(nvg, nvgRGBA(230, 50, 50, math.floor(lineAlpha * 1.3)))
                    nvgFill(nvg)
                end
            end
        end

        -- 7) HP条
        local barW = scRadius * 1.8
        local barH = 4
        local barX = scx - barW / 2
        local barY = scy + scRadius * 0.6
        local hpRatio = math.max(0, sc.hp / sc.maxHp)
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, barX, barY, barW, barH, 2)
        nvgFillColor(nvg, nvgRGBA(60, 60, 60, 200))
        nvgFill(nvg)
        if hpRatio > 0 then
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, barX, barY, barW * hpRatio, barH, 2)
            nvgFillColor(nvg, nvgRGBA(220, 200, 60, 255))
            nvgFill(nvg)
        end
    end

    -- 7.5 英雄受击闪光
    if G.battle.hitFlash and G.battle.hitFlash > 0 and G.battle.hero.hp > 0 then
        local hx, hy = HexGrid.HexToPixel(G.battle.hero.col, G.battle.hero.row, hexSize, ox, oy)
        local flashAlpha = math.min(255, math.floor(G.battle.hitFlash / 0.25 * 200))
        nvgBeginPath(nvg)
        nvgCircle(nvg, hx, hy, hexSize * 0.75)
        nvgFillColor(nvg, nvgRGBA(255, 40, 40, flashAlpha))
        nvgFill(nvg)
        local ringRadius = hexSize * (0.6 + (0.25 - G.battle.hitFlash) * 2.0)
        nvgBeginPath(nvg)
        nvgCircle(nvg, hx, hy, ringRadius)
        nvgStrokeColor(nvg, nvgRGBA(255, 100, 80, math.floor(flashAlpha * 0.7)))
        nvgStrokeWidth(nvg, 3)
        nvgStroke(nvg)
    end

    -- 7.6 护盾指示器（多层盾形光晕）
    if G.battle.hasShield and G.battle.hero.hp > 0 then
        local hx, hy = HexGrid.HexToPixel(G.battle.hero.col, G.battle.hero.row, hexSize, ox, oy)
        local t = G.time or 0
        local pulse = math.sin(t * 3.0) * 0.3 + 0.7  -- 0.4~1.0 脉动
        local fastPulse = math.sin(t * 5.0) * 0.5 + 0.5
        local baseR = hexSize * 0.7

        -- 层1: 外层扩散光晕（大范围柔光）
        nvgBeginPath(nvg)
        nvgCircle(nvg, hx, hy, baseR + 12 + pulse * 5)
        nvgFillPaint(nvg, nvgRadialGradient(nvg,
            hx, hy, baseR * 0.3, baseR + 12 + pulse * 5,
            nvgRGBA(80, 160, 255, math.floor(50 * pulse)),
            nvgRGBA(60, 140, 255, 0)))
        nvgFill(nvg)

        -- 层2: 主盾圈（厚实亮圈）
        nvgBeginPath(nvg)
        nvgCircle(nvg, hx, hy, baseR + 2 + pulse * 2)
        nvgStrokeColor(nvg, nvgRGBA(100, 190, 255, math.floor(200 * pulse)))
        nvgStrokeWidth(nvg, 3.5)
        nvgStroke(nvg)

        -- 层3: 内圈高亮
        nvgBeginPath(nvg)
        nvgCircle(nvg, hx, hy, baseR - 2)
        nvgStrokeColor(nvg, nvgRGBA(160, 220, 255, math.floor(120 * fastPulse)))
        nvgStrokeWidth(nvg, 1.5)
        nvgStroke(nvg)

        -- 层4: 半透明填充（蓝色护盾感）
        nvgBeginPath(nvg)
        nvgCircle(nvg, hx, hy, baseR)
        nvgFillColor(nvg, nvgRGBA(60, 150, 255, math.floor(30 * pulse)))
        nvgFill(nvg)

        -- 层5: 顶部盾牌图标
        nvgFontSize(nvg, hexSize * 0.55)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(150, 220, 255, math.floor(220 * pulse)))
        nvgText(nvg, hx, hy - baseR - 6, "🛡️")
    end

    -- 7.6.5 虹吸护盾指示器（紫色/深红光晕，与蓝色道具护盾区分）
    if G.battle.drainShield and G.battle.drainShield > 0 and G.battle.hero.hp > 0 then
        local hx, hy = HexGrid.HexToPixel(G.battle.hero.col, G.battle.hero.row, hexSize, ox, oy)
        local t = G.time or 0
        local pulse = math.sin(t * 2.5) * 0.3 + 0.7
        local fastPulse = math.sin(t * 4.0) * 0.5 + 0.5
        local baseR = hexSize * 0.7

        -- 层1: 外层紫色扩散光晕
        nvgBeginPath(nvg)
        nvgCircle(nvg, hx, hy, baseR + 10 + pulse * 4)
        nvgFillPaint(nvg, nvgRadialGradient(nvg,
            hx, hy, baseR * 0.3, baseR + 10 + pulse * 4,
            nvgRGBA(180, 60, 200, math.floor(45 * pulse)),
            nvgRGBA(140, 40, 160, 0)))
        nvgFill(nvg)

        -- 层2: 主盾圈（紫红色厚实亮圈）
        nvgBeginPath(nvg)
        nvgCircle(nvg, hx, hy, baseR + 2 + pulse * 2)
        nvgStrokeColor(nvg, nvgRGBA(200, 80, 200, math.floor(200 * pulse)))
        nvgStrokeWidth(nvg, 3.0)
        nvgStroke(nvg)

        -- 层3: 内圈高亮（深红）
        nvgBeginPath(nvg)
        nvgCircle(nvg, hx, hy, baseR - 2)
        nvgStrokeColor(nvg, nvgRGBA(220, 100, 180, math.floor(110 * fastPulse)))
        nvgStrokeWidth(nvg, 1.5)
        nvgStroke(nvg)

        -- 层4: 半透明填充（紫色护盾感）
        nvgBeginPath(nvg)
        nvgCircle(nvg, hx, hy, baseR)
        nvgFillColor(nvg, nvgRGBA(160, 50, 180, math.floor(25 * pulse)))
        nvgFill(nvg)

        -- 层5: 顶部护盾数值
        nvgFontSize(nvg, hexSize * 0.35)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(220, 140, 255, math.floor(220 * pulse)))
        nvgText(nvg, hx, hy - baseR - 6, "🔮" .. G.battle.drainShield)
    end

    -- 7.6.8 封印指示器（被封印的敌人显示紫色魔法阵 + 剩余回合）
    if G.battle.board then
        local enemies = HexGrid.GetTeamPieces(G.battle.board, "enemy")
        for _, e in ipairs(enemies) do
            if e.hp > 0 and e._sealedTurns and e._sealedTurns > 0 then
                local ex, ey = HexGrid.HexToPixel(e.col, e.row, hexSize, ox, oy)
                local t = G.time or 0
                local pulse = math.sin(t * 3.0) * 0.3 + 0.7
                local sealR = hexSize * 0.55

                -- 外圈旋转魔法阵
                nvgSave(nvg)
                nvgTranslate(nvg, ex, ey)
                nvgRotate(nvg, t * 0.8)
                -- 六芒星外圈
                nvgBeginPath(nvg)
                for i = 0, 5 do
                    local angle = i * math.pi / 3
                    local px = math.cos(angle) * sealR
                    local py = math.sin(angle) * sealR
                    if i == 0 then nvgMoveTo(nvg, px, py) else nvgLineTo(nvg, px, py) end
                end
                nvgClosePath(nvg)
                nvgStrokeColor(nvg, nvgRGBA(180, 100, 255, math.floor(160 * pulse)))
                nvgStrokeWidth(nvg, 2.0)
                nvgStroke(nvg)

                -- 内三角
                nvgBeginPath(nvg)
                for i = 0, 2 do
                    local angle = i * math.pi * 2 / 3
                    local px = math.cos(angle) * sealR * 0.6
                    local py = math.sin(angle) * sealR * 0.6
                    if i == 0 then nvgMoveTo(nvg, px, py) else nvgLineTo(nvg, px, py) end
                end
                nvgClosePath(nvg)
                nvgStrokeColor(nvg, nvgRGBA(200, 120, 255, math.floor(120 * pulse)))
                nvgStrokeWidth(nvg, 1.5)
                nvgStroke(nvg)

                -- 中心填充光晕
                nvgBeginPath(nvg)
                nvgCircle(nvg, 0, 0, sealR * 0.3)
                nvgFillColor(nvg, nvgRGBA(160, 60, 220, math.floor(50 * pulse)))
                nvgFill(nvg)
                nvgRestore(nvg)

                -- 封印回合数标签
                nvgFontSize(nvg, hexSize * 0.3)
                nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(nvg, nvgRGBA(220, 160, 255, 230))
                nvgText(nvg, ex, ey - sealR - 4, "🔮" .. e._sealedTurns)
            end
        end
    end

    -- 7.6.8.2 冰霜印记层数指示器（怪头上持续显示 ❄X/Y）
    if G.battle.board then
        local frostSkillLv = Skills.Level(G.battle.skills, "frost_mark")
        if frostSkillLv >= 1 then
            local maxStacks
            if frostSkillLv <= 2 then
                maxStacks = 4 - (frostSkillLv - 1)
            else
                maxStacks = 3 - math.floor((frostSkillLv - 3) / 2)
            end
            local enemies = HexGrid.GetTeamPieces(G.battle.board, "enemy")
            for _, e in ipairs(enemies) do
                if e.hp > 0 and (e._frostStacks or 0) > 0 then
                    local ex, ey = HexGrid.HexToPixel(e.col, e.row, hexSize, ox, oy)
                    local frostY = ey - hexSize * 0.72
                    local t = G.time or 0
                    local pulse = math.sin(t * 2.5) * 0.15 + 0.85

                    -- 冰霜背景小圆
                    nvgBeginPath(nvg)
                    nvgRoundedRect(nvg, ex - hexSize * 0.35, frostY - hexSize * 0.16,
                        hexSize * 0.7, hexSize * 0.32, 4)
                    nvgFillColor(nvg, nvgRGBA(30, 80, 160, math.floor(140 * pulse)))
                    nvgFill(nvg)

                    -- 层数文字
                    nvgFontFace(nvg, "sans")
                    nvgFontSize(nvg, hexSize * 0.26)
                    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(nvg, nvgRGBA(160, 230, 255, math.floor(240 * pulse)))
                    nvgText(nvg, ex, frostY, "❄" .. e._frostStacks .. "/" .. maxStacks)
                end

                -- 冻结状态也显示
                if e.hp > 0 and (e._frozenTurns or 0) > 0 then
                    local ex, ey = HexGrid.HexToPixel(e.col, e.row, hexSize, ox, oy)
                    local frzY = ey - hexSize * 0.48
                    local t = G.time or 0
                    local pulse = math.sin(t * 4.0) * 0.2 + 0.8

                    nvgFontFace(nvg, "sans")
                    nvgFontSize(nvg, hexSize * 0.24)
                    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(nvg, nvgRGBA(100, 200, 255, math.floor(220 * pulse)))
                    nvgText(nvg, ex, frzY, "🧊冻" .. e._frozenTurns .. "回合")
                end
            end
        end
    end

    -- 7.6.8.4 敌人沉默标记（寂灭之路：被沉默的敌人头顶持续显示，独立于冰霜印记技能）
    if G.battle.board then
        local silencedEnemies = HexGrid.GetTeamPieces(G.battle.board, "enemy")
        for _, e in ipairs(silencedEnemies) do
            if e.hp > 0 and (e._silencedTurns or 0) > 0 then
                local ex, ey = HexGrid.HexToPixel(e.col, e.row, hexSize, ox, oy)
                local silY = ey - hexSize * 0.74  -- 高于冻结标记，避免重叠
                local t = G.time or 0
                local pulse = math.sin(t * 4.5) * 0.25 + 0.75
                -- 紫色光环底座（柔和发光，让标记更醒目）
                nvgBeginPath(nvg)
                nvgCircle(nvg, ex, silY, hexSize * 0.5 * pulse)
                nvgFillPaint(nvg, nvgRadialGradient(nvg, ex, silY, 0, hexSize * 0.5 * pulse,
                    nvgRGBA(175, 75, 235, math.floor(75 * pulse)),
                    nvgRGBA(120, 40, 190, 0)))
                nvgFill(nvg)
                -- 紫色背景框（醒目）
                nvgBeginPath(nvg)
                nvgRoundedRect(nvg, ex - hexSize * 0.52, silY - hexSize * 0.19,
                    hexSize * 1.04, hexSize * 0.38, 4)
                nvgFillColor(nvg, nvgRGBA(85, 35, 145, math.floor(205 * pulse)))
                nvgFill(nvg)
                -- 紫色描边
                nvgStrokeColor(nvg, nvgRGBA(195, 125, 255, math.floor(235 * pulse)))
                nvgStrokeWidth(nvg, 1.6)
                nvgStroke(nvg)
                -- 文字（亮紫白色）
                nvgFontFace(nvg, "sans")
                nvgFontSize(nvg, hexSize * 0.28)
                nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(nvg, nvgRGBA(235, 195, 255, math.floor(255 * pulse)))
                nvgText(nvg, ex, silY, "🤐沉默" .. e._silencedTurns .. "回合")
            end
        end
    end

    -- 7.6.8.5 沉默指示器（英雄被珊瑚封印沉默时，头顶显示🔇图标+紫色光环）
    if G.battle.hero and (G.battle.hero.silencedTurns or 0) > 0 and G.battle.hero.hp > 0 then
        local hero = G.battle.hero
        local hx, hy
        if hero.animTimer and hero.animTimer > 0 and hero.animFromCol then
            local at = 1.0 - hero.animTimer / hero.animMaxTimer
            at = 1.0 - (1.0 - at) * (1.0 - at)
            local fx2, fy2 = HexGrid.HexToPixel(hero.animFromCol, hero.animFromRow, hexSize, ox, oy)
            local tx2, ty2 = HexGrid.HexToPixel(hero.col, hero.row, hexSize, ox, oy)
            hx = fx2 + (tx2 - fx2) * at
            hy = fy2 + (ty2 - fy2) * at
        else
            hx, hy = HexGrid.HexToPixel(hero.col, hero.row, hexSize, ox, oy)
        end
        local gt = G.time or 0
        local pulse = math.sin(gt * 3.5) * 0.25 + 0.75
        local silenceY = hy - hexSize * 0.75

        -- 紫色光环底座
        nvgBeginPath(nvg)
        nvgCircle(nvg, hx, silenceY, hexSize * 0.28 * pulse)
        nvgFillPaint(nvg, nvgRadialGradient(nvg, hx, silenceY, 0, hexSize * 0.28 * pulse,
            nvgRGBA(200, 80, 255, math.floor(80 * pulse)),
            nvgRGBA(160, 40, 200, 0)))
        nvgFill(nvg)

        -- 沉默图标
        nvgFontFace(nvg, "emoji")
        nvgFontSize(nvg, hexSize * 0.4)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(220, 120, 255, math.floor(230 * pulse)))
        nvgText(nvg, hx, silenceY, "🔇")

        -- 剩余回合数
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, hexSize * 0.22)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(255, 200, 255, 220))
        nvgText(nvg, hx, silenceY + hexSize * 0.25, tostring(hero.silencedTurns) .. "回合")
    end

    -- 7.6.8.6 棋步就绪持续指示器（英雄头顶金色闪光提示，直到棋步跳跃执行后消失）
    if G.battle._kingmakerReady and G.battle.hero and G.battle.hero.hp > 0 then
        local hero = G.battle.hero
        local hx, hy
        if hero.animTimer and hero.animTimer > 0 and hero.animFromCol then
            local at = 1.0 - hero.animTimer / hero.animMaxTimer
            at = 1.0 - (1.0 - at) * (1.0 - at)
            local fx2, fy2 = HexGrid.HexToPixel(hero.animFromCol, hero.animFromRow, hexSize, ox, oy)
            local tx2, ty2 = HexGrid.HexToPixel(hero.col, hero.row, hexSize, ox, oy)
            hx = fx2 + (tx2 - fx2) * at
            hy = fy2 + (ty2 - fy2) * at
        else
            hx, hy = HexGrid.HexToPixel(hero.col, hero.row, hexSize, ox, oy)
        end
        local gt = G.time or 0
        local kmY = hy - hexSize * 1.35
        local pulse = math.sin(gt * 3.0) * 0.12 + 0.88
        local floatOff = math.sin(gt * 1.8) * 3.0  -- 上下浮动

        -- "♟棋步就绪" 文字（无外框，带描边增强可读性）
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, hexSize * 0.55)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        -- 深色描边（增强对比度）
        nvgFillColor(nvg, nvgRGBA(40, 20, 0, math.floor(200 * pulse)))
        for dx = -1.5, 1.5, 1.5 do
            for dy = -1.5, 1.5, 1.5 do
                if dx ~= 0 or dy ~= 0 then
                    nvgText(nvg, hx + dx, kmY + floatOff + dy, "♟棋步就绪")
                end
            end
        end
        -- 金色文字
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, hexSize * 0.55)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(255, 230, 100, math.floor(255 * pulse)))
        nvgText(nvg, hx, kmY + floatOff, "♟棋步就绪")

        -- 闪闪发光粒子（10颗围绕文字旋转的金色星星，更大更亮）
        for i = 0, 9 do
            local angle = i * math.pi / 5 + gt * 1.5
            local dist = hexSize * (0.85 + math.sin(gt * 2.5 + i * 1.3) * 0.15)
            local px = hx + math.cos(angle) * dist
            local py = kmY + floatOff + math.sin(angle) * hexSize * 0.35
            local sparkSize = (3.5 + math.sin(gt * 4.0 + i * 0.8) * 1.8) * pulse
            local sparkAlpha = math.floor((200 + math.sin(gt * 3.5 + i * 1.1) * 55) * pulse)

            -- 十字星形粒子
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, px - sparkSize, py)
            nvgLineTo(nvg, px, py - sparkSize * 1.5)
            nvgLineTo(nvg, px + sparkSize, py)
            nvgLineTo(nvg, px, py + sparkSize * 1.5)
            nvgClosePath(nvg)
            nvgFillColor(nvg, nvgRGBA(255, 240, 120, sparkAlpha))
            nvgFill(nvg)
        end

        -- 额外小圆点闪烁（随机分布感，更大范围）
        for i = 0, 7 do
            local seed = i * 2.37
            local sx = hx + math.sin(gt * 1.5 + seed) * hexSize * 0.95
            local sy = kmY + floatOff + math.cos(gt * 1.9 + seed) * hexSize * 0.35
            local dotAlpha = math.floor(math.max(0, math.sin(gt * 5.0 + seed * 3.0)) * 240)
            if dotAlpha > 20 then
                nvgBeginPath(nvg)
                nvgCircle(nvg, sx, sy, 3.0)
                nvgFillColor(nvg, nvgRGBA(255, 255, 200, dotAlpha))
                nvgFill(nvg)
            end
        end
    end

    -- 7.6.9 猎手印记指示器（被标记的敌人显示橙色靶心，跟随移动动画插值）
    if G.battle.board then
        local enemies = HexGrid.GetTeamPieces(G.battle.board, "enemy")
        for _, e in ipairs(enemies) do
            if e.hp > 0 and e._hunterMarked then
                -- 计算插值位置（与棋子渲染逻辑一致，跟随移动动画）
                local ex, ey
                if e.animTimer and e.animTimer > 0 and e.animFromCol then
                    local at = 1.0 - e.animTimer / e.animMaxTimer
                    at = 1.0 - (1.0 - at) * (1.0 - at) -- ease-out
                    local fx2, fy2 = HexGrid.HexToPixel(e.animFromCol, e.animFromRow, hexSize, ox, oy)
                    local tx2, ty2 = HexGrid.HexToPixel(e.col, e.row, hexSize, ox, oy)
                    ex = fx2 + (tx2 - fx2) * at
                    ey = fy2 + (ty2 - fy2) * at
                else
                    ex, ey = HexGrid.HexToPixel(e.col, e.row, hexSize, ox, oy)
                end
                local gt = G.time or 0
                local pulse = math.sin(gt * 4.0) * 0.2 + 0.8
                local markR = hexSize * 0.35
                local markY = ey - hexSize * 0.45
                -- 外圈
                nvgBeginPath(nvg)
                nvgCircle(nvg, ex, markY, markR)
                nvgStrokeColor(nvg, nvgRGBA(255, 120, 40, math.floor(200 * pulse)))
                nvgStrokeWidth(nvg, 2.0)
                nvgStroke(nvg)
                -- 内圈
                nvgBeginPath(nvg)
                nvgCircle(nvg, ex, markY, markR * 0.5)
                nvgStrokeColor(nvg, nvgRGBA(255, 120, 40, math.floor(160 * pulse)))
                nvgStrokeWidth(nvg, 1.5)
                nvgStroke(nvg)
                -- 中心点
                nvgBeginPath(nvg)
                nvgCircle(nvg, ex, markY, 3)
                nvgFillColor(nvg, nvgRGBA(255, 80, 20, math.floor(240 * pulse)))
                nvgFill(nvg)
            end
        end
    end

    -- 7.6.10 连击护盾视觉特效（蓝色六边形光罩 + 护盾值）
    if G.battle and G.battle.hero and (G.battle.hero._shield or 0) > 0 then
        local hero = G.battle.hero
        local hx, hy
        -- 跟随英雄动画插值
        if hero.animTimer and hero.animTimer > 0 and hero.animFromCol then
            local at = 1.0 - hero.animTimer / hero.animMaxTimer
            at = 1.0 - (1.0 - at) * (1.0 - at)
            local fx2, fy2 = HexGrid.HexToPixel(hero.animFromCol, hero.animFromRow, hexSize, ox, oy)
            local tx2, ty2 = HexGrid.HexToPixel(hero.col, hero.row, hexSize, ox, oy)
            hx = fx2 + (tx2 - fx2) * at
            hy = fy2 + (ty2 - fy2) * at
        else
            hx, hy = HexGrid.HexToPixel(hero.col, hero.row, hexSize, ox, oy)
        end
        local gt = G.time or 0
        local shieldVal = hero._shield
        local pulse = math.sin(gt * 3.0) * 0.15 + 0.85
        local shieldR = hexSize * 0.55

        -- 外层光罩（旋转六边形）
        nvgSave(nvg)
        nvgTranslate(nvg, hx, hy)
        nvgRotate(nvg, gt * 0.5)
        nvgBeginPath(nvg)
        for i = 0, 5 do
            local a = i * math.pi / 3
            local sx2 = math.cos(a) * shieldR * pulse
            local sy2 = math.sin(a) * shieldR * pulse
            if i == 0 then nvgMoveTo(nvg, sx2, sy2) else nvgLineTo(nvg, sx2, sy2) end
        end
        nvgClosePath(nvg)
        nvgStrokeColor(nvg, nvgRGBA(80, 180, 255, math.floor(160 * pulse)))
        nvgStrokeWidth(nvg, 2.0)
        nvgStroke(nvg)
        nvgFillColor(nvg, nvgRGBA(60, 140, 220, math.floor(30 * pulse)))
        nvgFill(nvg)
        nvgRestore(nvg)

        -- 内层光环（反向旋转）
        nvgSave(nvg)
        nvgTranslate(nvg, hx, hy)
        nvgRotate(nvg, -gt * 0.8)
        nvgBeginPath(nvg)
        local innerR = shieldR * 0.7
        for i = 0, 5 do
            local a = i * math.pi / 3
            local sx2 = math.cos(a) * innerR * pulse
            local sy2 = math.sin(a) * innerR * pulse
            if i == 0 then nvgMoveTo(nvg, sx2, sy2) else nvgLineTo(nvg, sx2, sy2) end
        end
        nvgClosePath(nvg)
        nvgStrokeColor(nvg, nvgRGBA(100, 200, 255, math.floor(100 * pulse)))
        nvgStrokeWidth(nvg, 1.2)
        nvgStroke(nvg)
        nvgRestore(nvg)

        -- 顶部能量球（4个沿圆周流转）
        for i = 1, 4 do
            local orbA = gt * 2.0 + i * math.pi * 0.5
            local orbR = shieldR * 0.9
            local orbX = hx + math.cos(orbA) * orbR
            local orbY = hy + math.sin(orbA) * orbR * 0.5 -- 椭圆感
            nvgBeginPath(nvg)
            nvgCircle(nvg, orbX, orbY, 2.5 * pulse)
            nvgFillColor(nvg, nvgRGBA(140, 220, 255, math.floor(200 * pulse)))
            nvgFill(nvg)
        end

        -- 护盾值数字（头顶）
        nvgFontSize(nvg, hexSize * 0.3)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        -- 描边
        nvgFillColor(nvg, nvgRGBA(0, 40, 80, 200))
        for dx = -1, 1 do
            for dy = -1, 1 do
                if dx ~= 0 or dy ~= 0 then
                    nvgText(nvg, hx + dx, hy - hexSize * 0.78 + dy, tostring(shieldVal))
                end
            end
        end
        nvgFillColor(nvg, nvgRGBA(120, 220, 255, math.floor(255 * pulse)))
        nvgText(nvg, hx, hy - hexSize * 0.78, tostring(shieldVal))
    end

    -- 7.8 首次操作教学提示（"移动"/"跳跃"悬浮气泡，置于最上层）
    local showMove = G.showBoardTutorial and G.battle.phase == "PLAYER_SELECT"
    local showJump = (G.showBoardTutorial or G.showJumpTutorial) and
                     (G.battle.phase == "PLAYER_SELECT" or G.battle.phase == "PLAYER_PLAN")
    if showMove or showJump then
        nvgSave(nvg)
        local tutFontSize = math.max(18, hexSize * 0.5)

        local function drawFloatingHint(cx, cy, label, borderColor, phase)
            local t = G.time or 0
            local floatY = math.sin(t * 2.5 + phase) * 5
            local breathAlpha = math.sin(t * 3.0 + phase) * 0.1 + 0.9
            local alpha = math.floor(255 * breathAlpha)

            -- 气泡位置（悬浮在格子上方）
            local labelY = cy - hexSize * 1.1 + floatY
            local tw = tutFontSize * 3.6
            local th = tutFontSize * 1.9
            local labelX = cx - tw / 2
            local cornerR = th / 2  -- 胶囊形

            -- 阴影
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, labelX + 2, labelY - th / 2 + 3, tw, th, cornerR)
            nvgFillColor(nvg, nvgRGBA(0, 0, 0, math.floor(40 * breathAlpha)))
            nvgFill(nvg)

            -- 白色背景
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, labelX, labelY - th / 2, tw, th, cornerR)
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, alpha))
            nvgFill(nvg)
            -- 彩色边框
            nvgStrokeWidth(nvg, 2.5)
            nvgStrokeColor(nvg, nvgRGBA(borderColor[1], borderColor[2], borderColor[3], alpha))
            nvgStroke(nvg)

            -- 向下箭头三角形
            local arrowW = 8
            local arrowH = 7
            local arrowTop = labelY + th / 2 - 1
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, cx - arrowW, arrowTop)
            nvgLineTo(nvg, cx + arrowW, arrowTop)
            nvgLineTo(nvg, cx, arrowTop + arrowH)
            nvgClosePath(nvg)
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, alpha))
            nvgFill(nvg)
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, cx - arrowW, arrowTop)
            nvgLineTo(nvg, cx, arrowTop + arrowH)
            nvgLineTo(nvg, cx + arrowW, arrowTop)
            nvgStrokeWidth(nvg, 2.5)
            nvgStrokeColor(nvg, nvgRGBA(borderColor[1], borderColor[2], borderColor[3], alpha))
            nvgStroke(nvg)

            -- 深色文字
            nvgFontSize(nvg, tutFontSize)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFontFace(nvg, UI.Theme.FontFace("sans", "normal"))
            nvgFillColor(nvg, nvgRGBA(40, 40, 50, alpha))
            nvgText(nvg, cx, labelY, label)
        end

        -- "移动"提示
        if showMove and #G.validMoves > 0 then
            local m = G.validMoves[1]
            local cx, cy = HexGrid.HexToPixel(m.col, m.row, hexSize, ox, oy)
            drawFloatingHint(cx, cy, "移动", {50, 130, 220}, 0)
        end

        -- "跳跃"提示
        if showJump and #G.validJumps > 0 then
            local j = G.validJumps[1]
            local cx, cy = HexGrid.HexToPixel(j.col, j.row, hexSize, ox, oy)
            drawFloatingHint(cx, cy, "跳跃", {220, 90, 40}, 1.0)
        end

        nvgRestore(nvg)
    end

    -- 7.9 视觉特效 VFX（委托子模块渲染）
    BoardWidget_VFX.Render(_ctx)

    -- 8. 绘制浮动文字
    local annActiveForFT = G.battle.comboAnnouncement and G.battle.comboAnnouncement.timer > 0
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    for _, ft in ipairs(G.battle.floatingTexts) do
        -- startDelay 倒计时未结束：不渲染
        if ft.startDelay and ft.startDelay > 0 then
            goto continue_ft
        end
        -- 连击公告激活时，隐藏 combo/combo_reward 样式浮动文字，避免与公告重叠
        if (ft.style == "combo" or ft.style == "combo_reward") and annActiveForFT then
            goto continue_ft
        end
        local cx, cy = HexGrid.HexToPixel(ft.col, ft.row, hexSize, ox, oy)
        local progress = 1.0 - ft.timer / ft.maxTimer
        local baseAlpha = math.min(255, math.floor(ft.timer / ft.maxTimer * 255))
        -- 连击公告激活时，普通浮动文字降低透明度避免干扰
        local alpha = annActiveForFT and math.floor(baseAlpha * 0.4) or baseAlpha

        if ft.style == "hit" then
            local cl = ft.comboLevel or 0
            -- combo越高弹跳越夸张
            local bounceExtra = math.min(cl, 8) * 0.1  -- 0→0.8
            local bounceScale = 1.0
            if progress < 0.15 then
                bounceScale = 1.0 + progress / 0.15 * (0.8 + bounceExtra)
            elseif progress < 0.3 then
                bounceScale = (1.8 + bounceExtra) - (progress - 0.15) / 0.15 * (0.5 + bounceExtra * 0.5)
            else
                bounceScale = (1.3 + bounceExtra * 0.5) - (progress - 0.3) / 0.7 * 0.3
            end
            -- combo越高基础字号越大: 0.6→0.6, 3→0.72, 5→0.84, 7+→0.96
            local baseFontMul = 0.6 + math.min(cl, 8) * 0.04
            local fontSize = hexSize * baseFontMul * bounceScale
            local outY = cy - hexSize * 0.5 + ft.offsetY
            -- combo>=5时加外层光晕（颜色与文字同色半透明）
            if cl >= 5 then
                local glowA = math.floor(alpha * 0.35)
                nvgFontSize(nvg, fontSize * 1.08)
                nvgFillColor(nvg, nvgRGBA(ft.color[1], ft.color[2], ft.color[3], glowA))
                for dx = -2, 2, 2 do
                    for dy = -2, 2, 2 do
                        if dx ~= 0 or dy ~= 0 then
                            nvgText(nvg, cx + dx, outY + dy, ft.text)
                        end
                    end
                end
            end
            -- 黑色描边
            nvgFontSize(nvg, fontSize)
            nvgFillColor(nvg, nvgRGBA(0, 0, 0, alpha))
            local off = cl >= 5 and 2.5 or 2
            nvgText(nvg, cx + off, outY, ft.text)
            nvgText(nvg, cx - off, outY, ft.text)
            nvgText(nvg, cx, outY + off, ft.text)
            nvgText(nvg, cx, outY - off, ft.text)
            -- 正文
            nvgFillColor(nvg, nvgRGBA(ft.color[1], ft.color[2], ft.color[3], alpha))
            nvgText(nvg, cx, outY, ft.text)

        elseif ft.style == "combo" then
            local cl = ft.comboLevel or 0
            -- combo越高弹跳越猛烈
            local popExtra = math.min(cl, 8) * 0.08
            local comboScale = 1.0
            if progress < 0.1 then
                comboScale = 1.0 + progress / 0.1 * (0.5 + popExtra)
            else
                comboScale = (1.5 + popExtra) - math.min(0.5, (progress - 0.1) * 0.6)
            end
            -- combo越高基础字号越大: 0.45→0.45, 3→0.51, 5→0.57, 7+→0.63
            local comboFontMul = 0.45 + math.min(cl, 8) * 0.02
            local fontSize = hexSize * comboFontMul * comboScale
            local outY = cy - hexSize * 0.5 + ft.offsetY
            -- combo>=5时加光晕
            if cl >= 5 then
                local glowA = math.floor(alpha * 0.4)
                nvgFontSize(nvg, fontSize * 1.06)
                nvgFillColor(nvg, nvgRGBA(ft.color[1], ft.color[2], ft.color[3], glowA))
                nvgText(nvg, cx - 1, outY - 1, ft.text)
                nvgText(nvg, cx + 1, outY - 1, ft.text)
                nvgText(nvg, cx - 1, outY + 1, ft.text)
                nvgText(nvg, cx + 1, outY + 1, ft.text)
            end
            nvgFontSize(nvg, fontSize)
            nvgFillColor(nvg, nvgRGBA(0, 0, 0, math.floor(alpha * 0.6)))
            nvgText(nvg, cx + 1, outY + 1, ft.text)
            nvgFillColor(nvg, nvgRGBA(ft.color[1], ft.color[2], ft.color[3], alpha))
            nvgText(nvg, cx, outY, ft.text)

        elseif ft.style == "execution" then
            -- 处决：超大字体、缓慢上浮、红黑光晕、持续显眼
            local exeScale = 1.0
            if progress < 0.15 then
                -- 爆发放大
                exeScale = 1.0 + (progress / 0.15) * 1.8
            elseif progress < 0.4 then
                -- 缓慢缩回
                exeScale = 2.8 - (progress - 0.15) / 0.25 * 0.6
            else
                -- 平稳维持
                exeScale = 2.2 - (progress - 0.4) * 0.5
            end
            exeScale = math.max(1.0, exeScale)
            local fontSize = hexSize * 0.7 * exeScale
            -- 缓慢上浮（比普通文字慢很多）
            local outY = cy - hexSize * 0.3 - progress * hexSize * 0.6
            -- 淡出从60%进度才开始
            local exeAlpha = progress < 0.6 and 255 or math.floor((1.0 - (progress - 0.6) / 0.4) * 255)
            -- 红色外层光晕（多方向粗描边）
            nvgFontSize(nvg, fontSize * 1.05)
            local glowA = math.floor(exeAlpha * 0.5)
            nvgFillColor(nvg, nvgRGBA(180, 0, 0, glowA))
            for dx = -3, 3, 3 do
                for dy = -3, 3, 3 do
                    if dx ~= 0 or dy ~= 0 then
                        nvgText(nvg, cx + dx, outY + dy, ft.text)
                    end
                end
            end
            -- 黑色粗描边
            nvgFontSize(nvg, fontSize)
            nvgFillColor(nvg, nvgRGBA(0, 0, 0, exeAlpha))
            for dx = -2, 2, 1 do
                for dy = -2, 2, 1 do
                    if dx ~= 0 or dy ~= 0 then
                        nvgText(nvg, cx + dx, outY + dy, ft.text)
                    end
                end
            end
            -- 主体文字（亮红）
            nvgFillColor(nvg, nvgRGBA(ft.color[1], ft.color[2], ft.color[3], exeAlpha))
            nvgText(nvg, cx, outY, ft.text)

        elseif ft.style == "combo_reward" then
            -- 连击奖励：大字弹跳 + 光晕描边
            local rewardScale = 1.0
            if progress < 0.08 then
                rewardScale = 1.0 + (progress / 0.08) * 1.2
            elseif progress < 0.2 then
                rewardScale = 2.2 - (progress - 0.08) / 0.12 * 0.6
            elseif progress < 0.35 then
                rewardScale = 1.6 + math.sin((progress - 0.2) / 0.15 * math.pi) * 0.2
            else
                rewardScale = 1.6 - (progress - 0.35) * 0.4
            end
            rewardScale = math.max(0.8, rewardScale)
            local fontSize = hexSize * 0.75 * rewardScale
            local outY = cy - hexSize * 0.8 + ft.offsetY
            -- 外层光晕（3像素偏移多方向）
            nvgFontSize(nvg, fontSize)
            local glowA = math.floor(alpha * 0.5)
            nvgFillColor(nvg, nvgRGBA(ft.color[1], ft.color[2], ft.color[3], glowA))
            for dx = -2, 2, 2 do
                for dy = -2, 2, 2 do
                    if dx ~= 0 or dy ~= 0 then
                        nvgText(nvg, cx + dx, outY + dy, ft.text)
                    end
                end
            end
            -- 黑色描边
            nvgFillColor(nvg, nvgRGBA(0, 0, 0, math.floor(alpha * 0.8)))
            local off = 1.5
            nvgText(nvg, cx + off, outY + off, ft.text)
            nvgText(nvg, cx - off, outY + off, ft.text)
            nvgText(nvg, cx + off, outY - off, ft.text)
            nvgText(nvg, cx - off, outY - off, ft.text)
            -- 主文字
            nvgFillColor(nvg, nvgRGBA(ft.color[1], ft.color[2], ft.color[3], alpha))
            nvgText(nvg, cx, outY, ft.text)

        elseif ft.style == "heal" then
            -- 治疗/血瓶：大字弹跳 + 绿色光晕 + 脉冲缩放
            local healScale = 1.0
            if progress < 0.1 then
                -- 弹入：从小到大
                local t = progress / 0.1
                healScale = 0.3 + 0.7 * t
                healScale = healScale + math.sin(t * math.pi) * 0.4
            elseif progress < 0.3 then
                -- 弹跳稳定
                local t = (progress - 0.1) / 0.2
                healScale = 1.0 + math.sin(t * math.pi * 2) * 0.15
            else
                healScale = 1.0
            end
            local fontSize = hexSize * 0.65 * healScale
            local outY = cy - hexSize * 0.5 + ft.offsetY

            -- 绿色光晕圈
            local glowR = hexSize * 0.8 * healScale
            local glowA = math.floor(alpha * 0.3)
            local healGlow = nvgRadialGradient(nvg, cx, outY, glowR * 0.2, glowR,
                nvgRGBA(80, 255, 120, glowA), nvgRGBA(80, 255, 120, 0))
            nvgBeginPath(nvg)
            nvgCircle(nvg, cx, outY, glowR)
            nvgFillPaint(nvg, healGlow)
            nvgFill(nvg)

            -- 外层光晕描边
            nvgFontFace(nvg, UI.Theme.FontFace("sans", "bold"))
            nvgFontSize(nvg, fontSize)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            local hlGlowA = math.floor(alpha * 0.5)
            nvgFillColor(nvg, nvgRGBA(0, 180, 60, hlGlowA))
            for ddx2 = -2, 2, 2 do
                for ddy2 = -2, 2, 2 do
                    if ddx2 ~= 0 or ddy2 ~= 0 then
                        nvgText(nvg, cx + ddx2, outY + ddy2, ft.text)
                    end
                end
            end
            -- 黑色描边
            nvgFillColor(nvg, nvgRGBA(0, 0, 0, math.floor(alpha * 0.8)))
            local off2 = 1.5
            nvgText(nvg, cx + off2, outY + off2, ft.text)
            nvgText(nvg, cx - off2, outY + off2, ft.text)
            nvgText(nvg, cx + off2, outY - off2, ft.text)
            nvgText(nvg, cx - off2, outY - off2, ft.text)
            -- 主文字（亮绿色）
            nvgFillColor(nvg, nvgRGBA(ft.color[1], ft.color[2], ft.color[3], alpha))
            nvgText(nvg, cx, outY, ft.text)

        else
            nvgFontSize(nvg, hexSize * 0.3)
            nvgFillColor(nvg, nvgRGBA(ft.color[1], ft.color[2], ft.color[3], alpha))
            nvgText(nvg, cx, cy - hexSize * 0.5 + ft.offsetY, ft.text)
        end
        ::continue_ft::
    end

    -- 9-13. 全屏叠加层（连击/Boss公告、回合提示、技能横幅等）
    BoardWidget_Overlays.Render(_ctx)

    -- 14. 轮盘弹窗覆盖层（最顶层）
    if WheelPopup.IsOpen() then
        WheelPopup.RenderNVG(nvg, l.w, l.h)
    end

end

function BoardWidget:HandleClick(event)
    -- 轮盘弹窗打开时拦截所有点击
    if WheelPopup.IsOpen() then
        WheelPopup.HandleClick()
        return
    end

    if not G.gridParams then return end
    local l = self:GetAbsoluteLayout()
    -- 使用与渲染相同的 gridParams，保证点击判定与视觉位置一致
    -- （G.cameraX/Y 也是基于 G.gridParams 计算的，必须使用同一套参数）
    local localX = event.x - l.x + G.cameraX
    local localY = event.y - l.y + G.cameraY
    local col, row = HexGrid.PixelToHex(localX, localY, G.gridParams)
    if col and row and self.onCellClick_ then
        self.onCellClick_(col, row)
    end
end

function BoardWidget:Update(dt)
    if not G.battle then return end

    for i = #G.battle.floatingTexts, 1, -1 do
        local ft = G.battle.floatingTexts[i]
        -- startDelay 期间：只倒计时延迟，不推进 timer（不移动、不淡出）
        if ft.startDelay and ft.startDelay > 0 then
            ft.startDelay = ft.startDelay - dt
        else
            ft.timer = ft.timer - dt
            if ft.style == "hit" then
                ft.offsetY = ft.offsetY - 55 * dt
            else
                ft.offsetY = ft.offsetY - 18 * dt
            end
            if ft.timer <= 0 then
                table.remove(G.battle.floatingTexts, i)
            end
        end
    end

    if G.battle.screenShake and G.battle.screenShake > 0 then
        G.battle.screenShake = G.battle.screenShake - dt * 1.5
        if G.battle.screenShake < 0.01 then
            G.battle.screenShake = 0
        end
    end

    if G.battle.hitFlash and G.battle.hitFlash > 0 then
        G.battle.hitFlash = G.battle.hitFlash - dt
        if G.battle.hitFlash < 0 then
            G.battle.hitFlash = 0
        end
    end

    -- 递减所有棋子的 per-piece hitFlash
    if G.battle.board and G.battle.board.pieces then
        for _, p in ipairs(G.battle.board.pieces) do
            if p.hitFlash and p.hitFlash > 0 then
                p.hitFlash = p.hitFlash - dt
                if p.hitFlash < 0 then p.hitFlash = 0 end
            end
        end
    end

    -- 棋子移动动画计时
    for _, p in ipairs(G.battle.board.pieces) do
        if p.animTimer and p.animTimer > 0 then
            p.animTimer = p.animTimer - dt
            if p.animTimer <= 0 then
                p.animTimer = 0
                -- 流沙推开动画结束，清除标记
                if p.sandPushed then p.sandPushed = nil end
            end
        end
        -- 流沙推开沙尘特效计时（独立于动画，可稍微延后消散）
        if p.sandPushTime and p.sandPushTime > 0 then
            p.sandPushTime = p.sandPushTime - dt
            if p.sandPushTime <= 0 then p.sandPushTime = nil end
        end
        -- 英雄攻击动画计时
        if p._attackAnim and p._attackAnim > 0 then
            p._attackAnim = p._attackAnim - dt
            if p._attackAnim < 0 then p._attackAnim = 0 end
        end
        -- Boss 技能攻击动画计时（skillAnim 从 duration 倒数到 0，skillAnimProg 推进到1）
        if p.skillAnimTimer and p.skillAnimTimer > 0 then
            p.skillAnimTimer = p.skillAnimTimer - dt
            if p.skillAnimTimer < 0 then p.skillAnimTimer = 0 end
            local dur = p.skillAnimDuration or 0.5
            p.skillAnim = 1.0 - p.skillAnimTimer / dur  -- 0→1
            if p.skillAnimTimer <= 0 then
                p.skillAnim = 0
                p.skillAnimType = ""
            end
        end
    end

    -- VFX 计时更新
    for i = #G.battle.vfx, 1, -1 do
        local v = G.battle.vfx[i]
        -- startDelay 支持：延迟期间不递减主 timer
        if v.startDelay and v.startDelay > 0 then
            v.startDelay = v.startDelay - dt
            if v.startDelay > 0 then goto continue_vfx end
        end
        v.timer = v.timer - dt
        -- 中间时间点回调（射线到达时触发伤害等）
        if v.onHit and v.hitTime and v.timer <= v.hitTime then
            v.onHit()
            v.onHit = nil  -- 只触发一次
        end
        if v.timer <= 0 then
            -- 动画结束回调（飞镖到达后才扣血等）
            if v.onComplete then
                v.onComplete()
                v.onComplete = nil  -- 防止重复调用
            end
            table.remove(G.battle.vfx, i)
        end
        ::continue_vfx::
    end

    -- 连击公告计时
    if G.battle.comboAnnouncement and G.battle.comboAnnouncement.timer > 0 then
        G.battle.comboAnnouncement.timer = G.battle.comboAnnouncement.timer - dt
        if G.battle.comboAnnouncement.timer <= 0 then
            G.battle.comboAnnouncement = nil
        end
    end

    -- 连击心得公告计时
    if G.battle.comboMasteryAnnouncement and G.battle.comboMasteryAnnouncement.timer > 0 then
        G.battle.comboMasteryAnnouncement.timer = G.battle.comboMasteryAnnouncement.timer - dt
        if G.battle.comboMasteryAnnouncement.timer <= 0 then
            G.battle.comboMasteryAnnouncement = nil
        end
    end

    -- 飞跃先锋公告计时
    if G.battle.leapPioneerAnnouncement and G.battle.leapPioneerAnnouncement.timer > 0 then
        G.battle.leapPioneerAnnouncement.timer = G.battle.leapPioneerAnnouncement.timer - dt
        if G.battle.leapPioneerAnnouncement.timer <= 0 then
            G.battle.leapPioneerAnnouncement = nil
        end
    end

    -- 猎魂·嗜血血怒公告计时
    if G.battle.soulHunterAnnouncement and G.battle.soulHunterAnnouncement.timer > 0 then
        G.battle.soulHunterAnnouncement.timer = G.battle.soulHunterAnnouncement.timer - dt
        if G.battle.soulHunterAnnouncement.timer <= 0 then
            G.battle.soulHunterAnnouncement = nil
        end
    end

    -- Boss 入场公告计时
    if G.battle.bossAnnouncement and G.battle.bossAnnouncement.timer > 0 then
        G.battle.bossAnnouncement.timer = G.battle.bossAnnouncement.timer - dt
        if G.battle.bossAnnouncement.timer <= 0 then
            G.battle.bossAnnouncement = nil
        end
    end

    -- Boss 技能公告计时
    if G.battle.bossSkillAnnounce and G.battle.bossSkillAnnounce.timer > 0 then
        G.battle.bossSkillAnnounce.timer = G.battle.bossSkillAnnounce.timer - dt
        if G.battle.bossSkillAnnounce.timer <= 0 then
            G.battle.bossSkillAnnounce = nil
        end
    end

    -- Boss 狂暴警告计时
    if G.battle.bossEnrageAnnounce and G.battle.bossEnrageAnnounce.timer > 0 then
        G.battle.bossEnrageAnnounce.timer = G.battle.bossEnrageAnnounce.timer - dt
        if G.battle.bossEnrageAnnounce.timer <= 0 then
            G.battle.bossEnrageAnnounce = nil
        end
    end

    -- ========================================
    -- 动态缩放检测
    -- ========================================
    self:UpdateDynamicZoom(dt)

    -- 缩放变化后立即刷新 gridParams，保证相机计算和点击判定与渲染一致
    do
        local ul = self:GetAbsoluteLayout()
        if ul.w > 0 and ul.h > 0 then
            G.gridParams = HexGrid.CalcGridParams(ul.w, ul.h, HexGrid.COLS, HexGrid.ROWS, G.BOARD_ZOOM)
            G.boardLayoutW = ul.w
            G.boardLayoutH = ul.h
        end
    end

    -- 摄像机跟随英雄（使用最新的 gridParams）
    if G.gridParams and G.battle.hero then
        local l = self:GetAbsoluteLayout()
        local hero = G.battle.hero
        -- 英雄在棋盘本地坐标中的像素位置
        local heroGX, heroGY = HexGrid.HexToPixel(
            hero.col, hero.row,
            G.gridParams.hexSize, G.gridParams.offsetX, G.gridParams.offsetY
        )
        -- 目标：让英雄居中
        G.cameraTargetX = heroGX - l.w / 2
        G.cameraTargetY = heroGY - l.h / 2
        -- 边界裁剪：不让摄像机超出棋盘范围
        local maxCamX = math.max(0, (G.gridParams.totalW - l.w) / 2)
        local maxCamY = math.max(0, (G.gridParams.totalH - l.h) / 2)
        G.cameraTargetX = math.max(-maxCamX, math.min(maxCamX, G.cameraTargetX))
        G.cameraTargetY = math.max(-maxCamY, math.min(maxCamY, G.cameraTargetY))
        -- 平滑插值
        local t = math.min(1, G.CAMERA_LERP_SPEED * dt)
        G.cameraX = G.cameraX + (G.cameraTargetX - G.cameraX) * t
        G.cameraY = G.cameraY + (G.cameraTargetY - G.cameraY) * t
    end
end

-- ============================================================================
-- 动态缩放系统
-- ============================================================================

--- 全屏 VFX 类型集合（出现时需要拉远镜头）
local FULLSCREEN_VFX_TYPES = {
    quake_land = true,
    combo_burst = true,
    meteor = true,
    hex_blast = true,
    convergence = true,
    doomsday_explosion = true,
    life_drain = true,
    time_freeze = true,
    boss_enrage = true,
}

--- 判断一个格子是否在当前视口内（用于逻辑判断，向内收缩确保完全可见）
local function IsCellVisible(col, row, gp, viewW, viewH, camX, camY)
    local px, py = HexGrid.HexToPixel(col, row, gp.hexSize, gp.offsetX, gp.offsetY)
    local screenX = px - camX
    local screenY = py - camY
    -- 向内收缩一个 hexSize，确保整个六边形完全在视口内才算可见
    local margin = gp.hexSize
    return screenX >= margin and screenX <= viewW - margin
       and screenY >= margin and screenY <= viewH - margin
end

function BoardWidget:UpdateDynamicZoom(dt)
    if not G.battle or not G.battle.hero then return end
    local l = self:GetAbsoluteLayout()
    if l.w <= 0 or l.h <= 0 then return end

    -- 始终用 ZOOM_IN 参数做可见性检查，防止震荡：
    -- 在 ZOOM_IN 下看不到 → 拉远；在 ZOOM_IN 下能看到 → 拉近
    -- 结果不随当前缩放变化，所以不会反复抖动
    local gp = HexGrid.CalcGridParams(l.w, l.h, HexGrid.COLS, HexGrid.ROWS, G.ZOOM_IN)
    local hero = G.battle.hero
    local hx, hy = HexGrid.HexToPixel(hero.col, hero.row, gp.hexSize, gp.offsetX, gp.offsetY)
    local camX = hx - l.w / 2
    local camY = hy - l.h / 2
    local maxCX = math.max(0, (gp.totalW - l.w) / 2)
    local maxCY = math.max(0, (gp.totalH - l.h) / 2)
    camX = math.max(-maxCX, math.min(maxCX, camX))
    camY = math.max(-maxCY, math.min(maxCY, camY))

    local needZoomOut = false

    -- 条件1: 有全屏攻击 VFX 正在播放
    if G.battle.vfx then
        for _, vfx in ipairs(G.battle.vfx) do
            if FULLSCREEN_VFX_TYPES[vfx.type] then
                needZoomOut = true
                break
            end
        end
    end

    -- 条件2: 有可跳跃目标在 ZOOM_IN 视野外
    if not needZoomOut and #G.validJumps > 0 then
        for _, j in ipairs(G.validJumps) do
            if not IsCellVisible(j.col, j.row, gp, l.w, l.h, camX, camY) then
                needZoomOut = true
                break
            end
        end
    end

    -- 条件2.5: 规划路径中的步骤在 ZOOM_IN 视野外
    if not needZoomOut and #G.plannedJumps > 0 then
        for _, pj in ipairs(G.plannedJumps) do
            if not IsCellVisible(pj.col, pj.row, gp, l.w, l.h, camX, camY) then
                needZoomOut = true
                break
            end
        end
    end

    -- 条件3: 英雄附近的存活敌人在 ZOOM_IN 视野外（远处敌人不触发拉远）
    local ZOOM_CHECK_RANGE = 4  -- 只关心 hex 距离 ≤ 4 的敌人
    if not needZoomOut then
        local enemies = HexGrid.GetTeamPieces(G.battle.board, "enemy")
        for _, e in ipairs(enemies) do
            local dist = HexGrid.CubeDistance(hero.col, hero.row, e.col, e.row)
            if dist <= ZOOM_CHECK_RANGE and not IsCellVisible(e.col, e.row, gp, l.w, l.h, camX, camY) then
                needZoomOut = true
                break
            end
        end
    end

    -- 条件4: 英雄附近的重要棋子（道具等）在 ZOOM_IN 视野外
    if not needZoomOut and G.battle.board and G.battle.board.pieces then
        for _, p in ipairs(G.battle.board.pieces) do
            if p.hp > 0 and p.team ~= "hero" and p.team ~= "enemy" then
                local dist = HexGrid.CubeDistance(hero.col, hero.row, p.col, p.row)
                if dist <= ZOOM_CHECK_RANGE and not IsCellVisible(p.col, p.row, gp, l.w, l.h, camX, camY) then
                    needZoomOut = true
                    break
                end
            end
        end
    end

    -- 防抖：拉远状态至少维持 0.4 秒，避免因 validJumps 瞬间变化导致频繁抖动
    local ZOOM_OUT_MIN_HOLD = 0.4
    if needZoomOut then
        -- 需要拉远：重置/延长冷却计时
        G.zoomOutCooldown = ZOOM_OUT_MIN_HOLD
    else
        -- 不需要拉远：冷却倒计时，归零前保持拉远目标
        if G.zoomOutCooldown > 0 then
            G.zoomOutCooldown = G.zoomOutCooldown - dt
            if G.zoomOutCooldown < 0 then G.zoomOutCooldown = 0 end
            needZoomOut = (G.zoomOutCooldown > 0)
        end
    end

    -- 设置目标，靠 lerp 平滑过渡
    G.zoomTarget = needZoomOut and G.ZOOM_OUT or G.ZOOM_IN

    -- 平滑插值缩放
    local zoomDiff = G.zoomTarget - G.zoomCurrent
    if math.abs(zoomDiff) > 0.001 then
        local zt = math.min(1, G.ZOOM_LERP_SPEED * dt)
        G.zoomCurrent = G.zoomCurrent + zoomDiff * zt
    else
        G.zoomCurrent = G.zoomTarget
    end

    G.BOARD_ZOOM = G.zoomCurrent
end

return BoardWidget
