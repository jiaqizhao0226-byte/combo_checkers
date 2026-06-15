---@diagnostic disable: param-type-mismatch, assign-type-mismatch
-- ============================================================================
-- WheelPopup.lua - 幸运/厄运轮盘弹窗 (NanoVG 圆形轮盘演出版)
-- 拾取轮盘道具后弹出全屏轮盘，自动旋转 → 减速 → 停止 → 揭示结果
-- 特效系统：好运(金色烟花粒子) / 厄运(紫色暗雾粒子)
-- ============================================================================

local AM = require "AudioManager"
local G  = require "GameState"
local BattleData = require "BattleData"
local Battle -- 延迟 require 避免循环引用

local WheelPopup = {}

-- ============================================================================
-- 状态
-- ============================================================================
local isOpen       = false
local wheelType    = ""       -- "lucky" | "doom"
local outcomes     = {}       -- 当前4个扇区事件
local onCloseCb    = nil      -- 关闭回调

-- 动画状态机: "spinning" → "result" → "closed"
local animState    = "closed"
local spinAngle    = 0        -- 当前旋转角度(rad)，轮盘整体旋转
local spinSpeed    = 0        -- 当前角速度(rad/s)
local spinTime     = 0        -- 已旋转时间
local targetIndex  = 0        -- 最终停在哪个扇区(1-4)
local resultTimer  = 0        -- 结果展示计时
local resultAlpha  = 0        -- 结果文本淡入

-- 动画参数
local SPIN_INITIAL_SPEED = 18.0   -- 初始角速度(rad/s) ~约3转/秒
local SPIN_DURATION_MIN  = 2.5    -- 最短旋转时间
local SPIN_DURATION_MAX  = 3.5    -- 最长旋转时间
local SPIN_DECEL_POWER   = 3.0    -- 减速曲线指数(越大越急刹)
local RESULT_DELAY       = 0.4    -- 停止后到显示结果的延迟
local RESULT_FADE_DUR    = 0.5    -- 结果文字淡入时长
local INTRO_FADE_DUR     = 0.4    -- 介绍文字淡入时长

-- 首次介绍状态
local introTimer   = 0
local introAlpha   = 0

-- ============================================================================
-- 轮盘配色方案 - 优雅渐变风格
-- ============================================================================

-- 幸运轮盘：深宝石色系交替（确保白色文字清晰可读）
local LUCKY_SECTOR_COLORS = {
    -- 每组: {浅色R,G,B}, {深色R,G,B} 用于渐变
    { light = {45, 140, 90},   dark = {25, 90, 55}    },   -- 翡翠绿
    { light = {55, 80, 160},   dark = {30, 50, 110}   },   -- 宝石蓝
    { light = {170, 120, 40},  dark = {120, 80, 20}   },   -- 琥珀金
    { light = {120, 55, 150},  dark = {75, 30, 100}   },   -- 紫水晶
}

-- 厄运轮盘：冷暗色系 (暗紫/暗红/深蓝交替)
local DOOM_SECTOR_COLORS = {
    { light = {90, 25, 35},    dark = {55, 12, 20}    },   -- 暗红
    { light = {60, 25, 90},    dark = {35, 12, 55}    },   -- 暗紫
    { light = {80, 20, 40},    dark = {50, 10, 25}    },   -- 深红
    { light = {45, 20, 75},    dark = {25, 10, 45}    },   -- 深紫
}

-- ============================================================================
-- 粒子系统
-- ============================================================================
local particles = {}
local MAX_PARTICLES = 80

---@class WheelParticle
---@field x number
---@field y number
---@field vx number
---@field vy number
---@field life number
---@field maxLife number
---@field size number
---@field color table
---@field type string "spark"|"firework"|"smoke"|"star"

--- 生成好运粒子（烟花/金色星星）
local function spawnLuckyParticles(cx, cy, radius)
    for _ = 1, 40 do
        local angle = math.random() * math.pi * 2
        local speed = 80 + math.random() * 200
        local life = 1.0 + math.random() * 1.5
        local r = math.random(220, 255)
        local g = math.random(180, 230)
        local b = math.random(50, 100)
        particles[#particles + 1] = {
            x = cx + math.cos(angle) * (radius * 0.3),
            y = cy + math.sin(angle) * (radius * 0.3),
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed - 60,
            life = life,
            maxLife = life,
            size = 3 + math.random() * 5,
            color = {r, g, b, 255},
            type = (math.random() > 0.5) and "star" or "spark",
        }
    end
    -- 加一些大的慢速闪光
    for _ = 1, 12 do
        local angle = math.random() * math.pi * 2
        local dist = radius * (0.5 + math.random() * 0.6)
        particles[#particles + 1] = {
            x = cx + math.cos(angle) * dist,
            y = cy + math.sin(angle) * dist,
            vx = math.cos(angle) * 15,
            vy = math.sin(angle) * 15 - 20,
            life = 1.5 + math.random() * 1.0,
            maxLife = 2.0,
            size = 8 + math.random() * 6,
            color = {255, 255, 200, 255},
            type = "firework",
        }
    end
end

--- 生成厄运粒子（暗紫烟雾/下沉暗影）
local function spawnDoomParticles(cx, cy, radius)
    for _ = 1, 35 do
        local angle = math.random() * math.pi * 2
        local dist = radius * (0.2 + math.random() * 0.8)
        local speed = 20 + math.random() * 50
        local life = 1.5 + math.random() * 2.0
        local r = math.random(60, 120)
        local g = math.random(10, 40)
        local b = math.random(80, 160)
        particles[#particles + 1] = {
            x = cx + math.cos(angle) * dist,
            y = cy + math.sin(angle) * dist,
            vx = math.cos(angle) * speed * 0.3,
            vy = speed * 0.4 + math.random() * 20,  -- 往下飘
            life = life,
            maxLife = life,
            size = 6 + math.random() * 10,
            color = {r, g, b, 200},
            type = "smoke",
        }
    end
    -- 暗红裂痕闪光
    for _ = 1, 8 do
        local angle = math.random() * math.pi * 2
        local dist = radius * 0.5
        particles[#particles + 1] = {
            x = cx + math.cos(angle) * dist,
            y = cy + math.sin(angle) * dist,
            vx = 0,
            vy = 0,
            life = 0.6 + math.random() * 0.4,
            maxLife = 1.0,
            size = 12 + math.random() * 8,
            color = {200, 30, 30, 180},
            type = "spark",
        }
    end
end

--- 更新粒子
local function updateParticles(dt)
    local i = 1
    while i <= #particles do
        local p = particles[i]
        p.life = p.life - dt
        if p.life <= 0 then
            particles[i] = particles[#particles]
            particles[#particles] = nil
        else
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            -- 重力
            if p.type == "spark" or p.type == "star" then
                p.vy = p.vy + 120 * dt
            elseif p.type == "firework" then
                p.vy = p.vy + 30 * dt
                p.size = p.size * (1 - dt * 0.5)
            elseif p.type == "smoke" then
                p.vx = p.vx * 0.97
                p.vy = p.vy * 0.97
                p.size = p.size + dt * 3
            end
            i = i + 1
        end
    end
end

--- 渲染粒子
local function renderParticles(nvg)
    for _, p in ipairs(particles) do
        local alpha = math.floor((p.life / p.maxLife) * p.color[4])
        if alpha > 0 then
            nvgBeginPath(nvg)
            if p.type == "star" then
                -- 小菱形星
                nvgMoveTo(nvg, p.x, p.y - p.size)
                nvgLineTo(nvg, p.x + p.size * 0.4, p.y)
                nvgLineTo(nvg, p.x, p.y + p.size)
                nvgLineTo(nvg, p.x - p.size * 0.4, p.y)
                nvgClosePath(nvg)
            else
                nvgCircle(nvg, p.x, p.y, p.size * 0.5)
            end
            nvgFillColor(nvg, nvgRGBA(p.color[1], p.color[2], p.color[3], alpha))
            nvgFill(nvg)
        end
    end
end

-- 缓存的 NVG 字体
local fontReady = false

-- ============================================================================
-- 从事件池随机抽取3个不重复事件 + 1个固定保底，随机排列为4个扇区
-- ============================================================================

---@param pool table 事件池数组
---@param fixed table 固定保底事件
---@return table 4个事件的数组
function WheelPopup.PickOutcomes(pool, fixed)
    local indices = {}
    for i = 1, #pool do indices[i] = i end
    for i = #indices, 2, -1 do
        local j = math.random(1, i)
        indices[i], indices[j] = indices[j], indices[i]
    end
    local picked = {}
    for i = 1, math.min(3, #indices) do
        picked[i] = pool[indices[i]]
    end
    picked[4] = fixed
    for i = 4, 2, -1 do
        local j = math.random(1, i)
        picked[i], picked[j] = picked[j], picked[i]
    end
    return picked
end

-- ============================================================================
-- 打开轮盘
-- ============================================================================

---@param type string "lucky" or "doom"
---@param callback function|nil 关闭时的回调
function WheelPopup.Open(type, callback)
    if not Battle then Battle = require "Battle" end
    local PlayerData = require "PlayerData"

    wheelType = type
    onCloseCb = callback
    isOpen = true

    -- 清空粒子
    particles = {}

    -- 从事件池随机抽取
    if type == "lucky" then
        outcomes = WheelPopup.PickOutcomes(BattleData.LUCKY_WHEEL_POOL, BattleData.LUCKY_WHEEL_FIXED)
    else
        outcomes = WheelPopup.PickOutcomes(BattleData.DOOM_WHEEL_POOL, BattleData.DOOM_WHEEL_FIXED)
    end

    -- 决定最终结果
    targetIndex = math.random(1, 4)

    -- 计算旋转参数
    local extraRotations = math.random(4, 6)
    local totalAngle = extraRotations * math.pi * 2 + math.rad(405 - targetIndex * 90)

    -- 使用固定时长方式：时间固定，通过 easing 控制速度曲线
    spinAngle = 0
    spinSpeed = SPIN_INITIAL_SPEED
    spinTime = 0
    resultTimer = 0
    resultAlpha = 0

    -- 存储目标总角度用于 easing 计算
    WheelPopup._totalAngle = totalAngle
    WheelPopup._spinDuration = SPIN_DURATION_MIN + math.random() * (SPIN_DURATION_MAX - SPIN_DURATION_MIN)

    -- 首次遇到轮盘：显示介绍
    local pdata = G.playerData
    if pdata and not pdata.wheelIntroSeen then
        pdata.wheelIntroSeen = true
        PlayerData.Save(pdata)
        animState = "intro"
        introTimer = 0
        introAlpha = 0
    else
        animState = "spinning"
        AM.PlaySFX("wheel_spin", 0.9)
    end
end

-- ============================================================================
-- 每帧更新
-- ============================================================================

function WheelPopup.Update(dt)
    if not isOpen then return end

    -- 更新粒子
    updateParticles(dt)

    if animState == "intro" then
        introTimer = introTimer + dt
        introAlpha = math.min(introTimer / INTRO_FADE_DUR, 1.0)
        return
    end

    if animState == "spinning" then
        spinTime = spinTime + dt
        local dur = WheelPopup._spinDuration
        local progress = math.min(spinTime / dur, 1.0)

        -- easeOutQuart 减速曲线
        local eased = 1 - (1 - progress) ^ SPIN_DECEL_POWER
        spinAngle = eased * WheelPopup._totalAngle

        -- 旋转期间 tick 音效（每经过一个扇区边界播放一次）
        local sectorsPassed = math.floor(spinAngle / (math.pi * 0.5))
        if not WheelPopup._lastSector then WheelPopup._lastSector = 0 end
        if sectorsPassed > WheelPopup._lastSector and progress < 0.95 then
            WheelPopup._lastSector = sectorsPassed
            AM.PlaySFX("ui_click", 0.4)
        end

        if progress >= 1.0 then
            spinAngle = WheelPopup._totalAngle
            animState = "result"
            resultTimer = 0
            WheelPopup._lastSector = nil

            -- 播放结果音效并生成粒子
            local cx = (WheelPopup._screenW or 400) * 0.5
            local cy = (WheelPopup._screenH or 800) * 0.5
            local radius = math.min(WheelPopup._screenW or 400, WheelPopup._screenH or 800) * 0.32

            if wheelType == "lucky" then
                AM.PlaySFX("wheel_lucky", 1.0)
                spawnLuckyParticles(cx, cy, radius)
            else
                local outcome = outcomes[targetIndex]
                if outcome and outcome.id == "nothing" then
                    AM.PlaySFX("wheel_lucky", 0.7)
                    spawnLuckyParticles(cx, cy, radius)
                else
                    AM.PlaySFX("wheel_doom", 1.0)
                    spawnDoomParticles(cx, cy, radius)
                end
            end

            -- 应用效果
            WheelPopup.ApplyOutcome(outcomes[targetIndex])
        end

    elseif animState == "result" then
        resultTimer = resultTimer + dt
        resultAlpha = math.min(1.0, (resultTimer - RESULT_DELAY) / RESULT_FADE_DUR)
        if resultAlpha < 0 then resultAlpha = 0 end
    end
end

-- ============================================================================
-- NanoVG 渲染（从 BoardWidget:Render 调用）
-- ============================================================================

---@param nvg NVGContextWrapper
---@param screenW number 逻辑屏幕宽
---@param screenH number 逻辑屏幕高
function WheelPopup.RenderNVG(nvg, screenW, screenH)
    if not isOpen then return end

    -- 缓存屏幕尺寸给粒子用
    WheelPopup._screenW = screenW
    WheelPopup._screenH = screenH

    -- 确保字体
    if not fontReady then
        nvgFontFace(nvg, "sans")
        fontReady = true
    end

    local cx = screenW * 0.5
    local cy = screenH * 0.45  -- 稍微偏上，给底部结果卡片留空间
    local radius = math.min(screenW, screenH) * 0.30

    -- === 1. 全屏半透明遮罩 ===
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, screenW, screenH)
    if wheelType == "lucky" then
        nvgFillColor(nvg, nvgRGBA(10, 8, 20, 200))
    else
        nvgFillColor(nvg, nvgRGBA(5, 2, 10, 220))
    end
    nvgFill(nvg)

    -- === 首次介绍标记（不 return，让轮盘正常绘制，最后叠加文字） ===
    local showIntroOverlay = (animState == "intro")

    -- === 2. 标题（带装饰） ===
    local titleY = cy - radius - 58
    local titleText = (wheelType == "lucky") and "幸运轮盘" or "厄运轮盘"
    nvgFontFace(nvg, "sans")
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- 标题背景光晕
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, cx - 90, titleY - 22, 180, 44, 22)
    if wheelType == "lucky" then
        nvgFillColor(nvg, nvgRGBA(255, 200, 50, 25))
    else
        nvgFillColor(nvg, nvgRGBA(200, 40, 60, 25))
    end
    nvgFill(nvg)

    -- 标题文字阴影
    nvgFontSize(nvg, 38)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 160))
    nvgText(nvg, cx + 1, titleY + 2, titleText)

    -- 标题文字本体
    if wheelType == "lucky" then
        nvgFillColor(nvg, nvgRGBA(255, 225, 80, 255))
    else
        nvgFillColor(nvg, nvgRGBA(220, 70, 90, 255))
    end
    nvgText(nvg, cx, titleY, titleText)

    -- 左右装饰线 + 星星
    local lineW = 50
    local lineGap = 72
    -- 左装饰线
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, cx - lineGap - lineW, titleY)
    nvgLineTo(nvg, cx - lineGap, titleY)
    nvgStrokeWidth(nvg, 2)
    if wheelType == "lucky" then
        nvgStrokeColor(nvg, nvgRGBA(255, 210, 80, 140))
    else
        nvgStrokeColor(nvg, nvgRGBA(180, 50, 70, 140))
    end
    nvgStroke(nvg)
    -- 右装饰线
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, cx + lineGap, titleY)
    nvgLineTo(nvg, cx + lineGap + lineW, titleY)
    nvgStrokeWidth(nvg, 2)
    nvgStroke(nvg)
    -- 左星
    nvgFontSize(nvg, 16)
    if wheelType == "lucky" then
        nvgFillColor(nvg, nvgRGBA(255, 220, 80, 200))
        nvgText(nvg, cx - lineGap - lineW - 12, titleY, "✦")
        nvgText(nvg, cx + lineGap + lineW + 12, titleY, "✦")
    else
        nvgFillColor(nvg, nvgRGBA(200, 60, 80, 200))
        nvgText(nvg, cx - lineGap - lineW - 12, titleY, "☠")
        nvgText(nvg, cx + lineGap + lineW + 12, titleY, "☠")
    end

    -- === 3. 轮盘外圈 ===
    -- 外圈深色底环
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy, radius + 14)
    if wheelType == "lucky" then
        nvgFillColor(nvg, nvgRGBA(60, 45, 15, 255))
    else
        nvgFillColor(nvg, nvgRGBA(25, 10, 30, 255))
    end
    nvgFill(nvg)

    -- 外圈金属感环
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy, radius + 10)
    nvgStrokeWidth(nvg, 6)
    if wheelType == "lucky" then
        nvgStrokeColor(nvg, nvgRGBA(200, 170, 60, 240))
    else
        nvgStrokeColor(nvg, nvgRGBA(100, 40, 80, 240))
    end
    nvgStroke(nvg)

    -- 内侧细金边
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy, radius + 4)
    nvgStrokeWidth(nvg, 2)
    if wheelType == "lucky" then
        nvgStrokeColor(nvg, nvgRGBA(255, 230, 100, 180))
    else
        nvgStrokeColor(nvg, nvgRGBA(160, 60, 100, 180))
    end
    nvgStroke(nvg)

    -- 外圈装饰灯(高级感小方块)
    local bulbCount = 24
    local bulbTime = (G.time or 0) * 4
    for i = 0, bulbCount - 1 do
        local angle = (i / bulbCount) * math.pi * 2
        local bx = cx + math.cos(angle) * (radius + 10)
        local by = cy + math.sin(angle) * (radius + 10)
        local phase = ((i + math.floor(bulbTime)) % 3)
        local bright = (phase == 0) and 255 or (phase == 1) and 150 or 60
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, bx - 2.5, by - 2.5, 5, 5, 1.5)
        if wheelType == "lucky" then
            nvgFillColor(nvg, nvgRGBA(255, 220, 80, bright))
        else
            nvgFillColor(nvg, nvgRGBA(200, 60, 100, bright))
        end
        nvgFill(nvg)
    end

    -- === 4. 轮盘扇区（旋转） ===
    nvgSave(nvg)
    nvgTranslate(nvg, cx, cy)
    nvgRotate(nvg, spinAngle)

    local sectorColors = (wheelType == "lucky") and LUCKY_SECTOR_COLORS or DOOM_SECTOR_COLORS
    local sectorAngle = math.pi * 0.5  -- 每扇区90度

    for i = 1, 4 do
        local startA = (i - 1) * sectorAngle - math.pi * 0.5  -- 从12点方向开始
        local endA = startA + sectorAngle
        local c = sectorColors[i]

        -- 扇形渐变填充（从中心到边缘由深到浅）
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, 0, 0)
        nvgArc(nvg, 0, 0, radius, startA, endA, NVG_CW)
        nvgClosePath(nvg)
        -- 使用径向渐变
        local grd = nvgRadialGradient(nvg, 0, 0, radius * 0.1, radius,
            nvgRGBA(c.dark[1], c.dark[2], c.dark[3], 255),
            nvgRGBA(c.light[1], c.light[2], c.light[3], 255))
        nvgFillPaint(nvg, grd)
        nvgFill(nvg)

        -- 扇区分割线（发光效果）
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, 0, 0)
        local lx = math.cos(endA) * radius
        local ly = math.sin(endA) * radius
        nvgLineTo(nvg, lx, ly)
        nvgStrokeWidth(nvg, 2.5)
        if wheelType == "lucky" then
            nvgStrokeColor(nvg, nvgRGBA(255, 240, 180, 120))
        else
            nvgStrokeColor(nvg, nvgRGBA(120, 50, 80, 150))
        end
        nvgStroke(nvg)

        -- 扇区内容：图标 + 名称（径向排列，文字上方朝轮盘外侧）
        local midA = startA + sectorAngle * 0.5
        local textR = radius * 0.6

        if outcomes[i] then
            nvgSave(nvg)
            local tx = math.cos(midA) * textR
            local ty = math.sin(midA) * textR
            nvgTranslate(nvg, tx, ty)
            nvgRotate(nvg, midA + math.pi * 0.5)

            -- 图标(emoji) - 放在上方（靠外）
            nvgFontSize(nvg, radius * 0.22)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, 250))
            nvgText(nvg, 0, -radius * 0.08, outcomes[i].icon or "?")

            -- 名称 - 放在下方（靠里），加阴影增强可读性
            nvgFontSize(nvg, radius * 0.11)
            -- 文字阴影
            nvgFillColor(nvg, nvgRGBA(0, 0, 0, 150))
            nvgText(nvg, 1, radius * 0.12 + 1, outcomes[i].name or "???")
            -- 文字本体
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, 240))
            nvgText(nvg, 0, radius * 0.12, outcomes[i].name or "???")

            nvgRestore(nvg)
        end
    end

    -- 内圈装饰环
    nvgBeginPath(nvg)
    nvgCircle(nvg, 0, 0, radius * 0.22)
    if wheelType == "lucky" then
        local innerGrd = nvgRadialGradient(nvg, 0, 0, 0, radius * 0.22,
            nvgRGBA(80, 60, 20, 255), nvgRGBA(50, 40, 15, 255))
        nvgFillPaint(nvg, innerGrd)
    else
        local innerGrd = nvgRadialGradient(nvg, 0, 0, 0, radius * 0.22,
            nvgRGBA(40, 15, 30, 255), nvgRGBA(20, 8, 15, 255))
        nvgFillPaint(nvg, innerGrd)
    end
    nvgFill(nvg)

    -- 中心圆（金属感）
    nvgBeginPath(nvg)
    nvgCircle(nvg, 0, 0, radius * 0.15)
    if wheelType == "lucky" then
        local centerGrd = nvgRadialGradient(nvg, -radius*0.03, -radius*0.03, 0, radius * 0.15,
            nvgRGBA(180, 150, 60, 255), nvgRGBA(100, 80, 30, 255))
        nvgFillPaint(nvg, centerGrd)
    else
        local centerGrd = nvgRadialGradient(nvg, -radius*0.03, -radius*0.03, 0, radius * 0.15,
            nvgRGBA(80, 30, 50, 255), nvgRGBA(40, 15, 25, 255))
        nvgFillPaint(nvg, centerGrd)
    end
    nvgFill(nvg)
    -- 中心圆高光
    nvgBeginPath(nvg)
    nvgCircle(nvg, 0, 0, radius * 0.15)
    nvgStrokeWidth(nvg, 2)
    if wheelType == "lucky" then
        nvgStrokeColor(nvg, nvgRGBA(255, 220, 100, 160))
    else
        nvgStrokeColor(nvg, nvgRGBA(160, 50, 80, 160))
    end
    nvgStroke(nvg)

    nvgRestore(nvg)

    -- === 5. 固定指针（顶部三角形，更精致）===
    local ptrH = 28
    local ptrW = 18
    local ptrY = cy - radius - 10
    -- 指针阴影
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, cx, ptrY + ptrH + 4)
    nvgLineTo(nvg, cx - ptrW * 0.5 - 1, ptrY + 2)
    nvgLineTo(nvg, cx + ptrW * 0.5 + 1, ptrY + 2)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 100))
    nvgFill(nvg)
    -- 指针本体
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, cx, ptrY + ptrH)
    nvgLineTo(nvg, cx - ptrW * 0.5, ptrY)
    nvgLineTo(nvg, cx + ptrW * 0.5, ptrY)
    nvgClosePath(nvg)
    if wheelType == "lucky" then
        nvgFillColor(nvg, nvgRGBA(255, 220, 60, 255))
    else
        nvgFillColor(nvg, nvgRGBA(220, 50, 60, 255))
    end
    nvgFill(nvg)
    -- 指针边框
    nvgStrokeWidth(nvg, 2)
    nvgStrokeColor(nvg, nvgRGBA(255, 255, 255, 220))
    nvgStroke(nvg)

    -- === 6. 粒子特效层 ===
    renderParticles(nvg)

    -- === 7. 结果文字（停止后淡入） ===
    if animState == "result" and resultAlpha > 0 then
        local outcome = outcomes[targetIndex]
        if outcome then
            local alpha = math.floor(resultAlpha * 255)

            -- 结果背景卡片（磨砂玻璃感）
            local cardW = radius * 2.0
            local cardH = 115
            local cardX = cx - cardW * 0.5
            local cardY = cy + radius + 40
            -- 卡片阴影
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, cardX + 2, cardY + 3, cardW, cardH, 14)
            nvgFillColor(nvg, nvgRGBA(0, 0, 0, math.floor(alpha * 0.4)))
            nvgFill(nvg)
            -- 卡片本体
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, cardX, cardY, cardW, cardH, 14)
            if wheelType == "lucky" then
                nvgFillColor(nvg, nvgRGBA(30, 25, 10, math.floor(alpha * 0.92)))
            else
                nvgFillColor(nvg, nvgRGBA(20, 8, 15, math.floor(alpha * 0.92)))
            end
            nvgFill(nvg)
            -- 卡片边框
            nvgStrokeWidth(nvg, 2)
            if wheelType == "lucky" then
                nvgStrokeColor(nvg, nvgRGBA(200, 170, 60, alpha))
            else
                nvgStrokeColor(nvg, nvgRGBA(160, 50, 70, alpha))
            end
            nvgStroke(nvg)

            -- 图标 + 名称
            nvgFontSize(nvg, 36)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, alpha))
            nvgText(nvg, cx, cardY + 40, (outcome.icon or "") .. " " .. (outcome.name or ""))

            -- 描述
            nvgFontSize(nvg, 20)
            if wheelType == "lucky" then
                nvgFillColor(nvg, nvgRGBA(255, 230, 140, math.floor(alpha * 0.85)))
            else
                nvgFillColor(nvg, nvgRGBA(220, 140, 160, math.floor(alpha * 0.85)))
            end
            nvgText(nvg, cx, cardY + 80, outcome.desc or "")

            -- 提示点击
            if resultTimer > RESULT_DELAY + RESULT_FADE_DUR + 0.5 then
                local blink = math.floor((math.sin((G.time or 0) * 4) * 0.5 + 0.5) * 160) + 80
                nvgFontSize(nvg, 14)
                nvgFillColor(nvg, nvgRGBA(180, 180, 180, blink))
                nvgText(nvg, cx, cardY + cardH + 22, "- 点击任意处继续 -")
            end
        end
    end

    -- === 首次介绍文字叠加（在轮盘上层显示） ===
    if showIntroOverlay then
        local alpha = math.floor(introAlpha * 255)
        -- 底部半透明卡片
        local cardW = math.min(screenW * 0.88, 380)
        local cardH = 180
        local cardX = cx - cardW * 0.5
        local cardY = cy + radius + 26

        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, cardX, cardY, cardW, cardH, 14)
        nvgFillColor(nvg, nvgRGBA(20, 15, 40, math.floor(alpha * 0.9)))
        nvgFill(nvg)
        -- 卡片边框
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, cardX, cardY, cardW, cardH, 14)
        nvgStrokeWidth(nvg, 1.5)
        if wheelType == "lucky" then
            nvgStrokeColor(nvg, nvgRGBA(255, 200, 80, math.floor(alpha * 0.5)))
        else
            nvgStrokeColor(nvg, nvgRGBA(200, 60, 80, math.floor(alpha * 0.5)))
        end
        nvgStroke(nvg)

        -- 介绍文字
        nvgFontFace(nvg, "sans")
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFontSize(nvg, 20)
        nvgFillColor(nvg, nvgRGBA(220, 220, 230, alpha))
        nvgText(nvg, cx, cardY + 34, "旅途中你可能遇到两种命运之轮：")
        nvgFontSize(nvg, 19)
        nvgFillColor(nvg, nvgRGBA(255, 225, 100, alpha))
        nvgText(nvg, cx, cardY + 70, "🌟 幸运轮盘 — 带来各种好运加持")
        nvgFillColor(nvg, nvgRGBA(220, 100, 120, alpha))
        nvgText(nvg, cx, cardY + 100, "💀 厄运轮盘 — 施加诅咒与惩罚")
        nvgFontSize(nvg, 17)
        nvgFillColor(nvg, nvgRGBA(180, 180, 190, alpha))
        nvgText(nvg, cx, cardY + 138, "踏上轮盘即自动触发，祝你好运！")

        -- 点击提示（闪烁）
        local blink = math.floor((math.sin((G.time or 0) * 3.5) * 0.5 + 0.5) * alpha)
        nvgFontSize(nvg, 18)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, blink))
        nvgText(nvg, cx, cardY + cardH + 28, "— 点击屏幕开始 —")
    end
end

-- ============================================================================
-- 点击处理（结果显示后点击关闭）
-- ============================================================================

function WheelPopup.HandleClick()
    if not isOpen then return false end
    -- 首次介绍界面：点击后开始旋转
    if animState == "intro" then
        animState = "spinning"
        AM.PlaySFX("wheel_spin", 0.9)
        return true
    end
    if animState == "result" and resultTimer > RESULT_DELAY + RESULT_FADE_DUR + 0.3 then
        WheelPopup.Close()
        return true  -- 消费点击
    end
    return true  -- 旋转中也消费点击（不让穿透到棋盘）
end

-- ============================================================================
-- 应用轮盘结果
-- ============================================================================

function WheelPopup.ApplyOutcome(outcome)
    if not Battle then Battle = require "Battle" end
    local state = G.battle
    if not state then return end
    local hero = state.hero

    if outcome.id == "full_hp" then
        local heal = hero.maxHp - hero.hp
        hero.hp = hero.maxHp
        Battle.AddFloatingText(state, hero.col, hero.row, "回满HP! +" .. heal, {80, 255, 100, 255}, "heal", 3.0)
        Battle.AddLog(state, "幸运轮盘：回满HP！(+" .. heal .. ")")

    elseif outcome.id == "shield" then
        hero._shield = (hero._shield or 0) + 30
        Battle.AddFloatingText(state, hero.col, hero.row, "+30护盾!", {120, 180, 255, 255}, nil, 3.0)
        Battle.AddLog(state, "幸运轮盘：获得30点护盾！")

    elseif outcome.id == "extra_skill" then
        state.pendingExtraSkillPick = true
        Battle.AddFloatingText(state, hero.col, hero.row, "技能选择!", {255, 215, 0, 255}, nil, 3.0)
        Battle.AddLog(state, "幸运轮盘：额外技能选择机会！")

    elseif outcome.id == "extra_turn" then
        state.pendingExtraTurn = true
        Battle.AddFloatingText(state, hero.col, hero.row, "额外行动!", {180, 120, 255, 255}, nil, 3.0)
        Battle.AddLog(state, "幸运轮盘：获得额外一回合行动！")

    elseif outcome.id == "lucky_strike" then
        local enemies = state.enemies or {}
        local alive = {}
        for _, e in ipairs(enemies) do
            if e.hp and e.hp > 0 then alive[#alive + 1] = e end
        end
        if #alive > 0 then
            local target = alive[math.random(1, #alive)]
            local dmg = 50
            target.hp = target.hp - dmg
            Battle.AddFloatingText(state, target.col, target.row, "⚡-" .. dmg, {255, 220, 80, 255}, "hit", 3.0)
            Battle.AddLog(state, "幸运轮盘：幸运一击！对" .. (target.name or "敌人") .. "造成" .. dmg .. "点伤害！")
            if target.hp <= 0 then
                target.hp = 0
                Battle.AddLog(state, (target.name or "敌人") .. "被幸运一击击败！")
            end
        else
            state.gold = (state.gold or 0) + 2
            Battle.AddFloatingText(state, hero.col, hero.row, "⚡+2金币", {255, 220, 80, 255}, nil, 3.0)
            Battle.AddLog(state, "幸运一击：场上无敌人，获得2金币补偿")
        end

    elseif outcome.id == "max_hp_up" then
        hero.maxHp = hero.maxHp + 25
        Battle.AddFloatingText(state, hero.col, hero.row, "HP上限+25!", {255, 100, 150, 255}, "heal", 3.0)
        Battle.AddLog(state, "幸运轮盘：体魄强化！本次战斗最大HP+25！")

    elseif outcome.id == "atk_up_buff" then
        state.luckyAtkUpTurns = (state.luckyAtkUpTurns or 0) + 10
        Battle.AddFloatingText(state, hero.col, hero.row, "攻击+30%!", {255, 140, 50, 255}, nil, 3.0)
        Battle.AddLog(state, "幸运轮盘：战意高涨！10回合内攻击力+30%！")

    elseif outcome.id == "small_reward" then
        state.gold = (state.gold or 0) + 10
        Battle.AddFloatingText(state, hero.col, hero.row, "小确幸 +10金币", {160, 220, 160, 255}, nil, 3.0)
        Battle.AddLog(state, "幸运轮盘：小确幸！获得10金币")

    -- === 厄运事件 ===
    elseif outcome.id == "dmg_taken_up" then
        state.doomDamageTakenTurns = (state.doomDamageTakenTurns or 0) + 10
        Battle.AddFloatingText(state, hero.col, hero.row, "承伤+30%!", {255, 80, 80, 255}, "hit", 3.0)
        Battle.AddLog(state, "厄运轮盘：10回合内承受伤害增加30%！")

    elseif outcome.id == "max_hp_down" then
        local reduction = math.floor(hero.maxHp * 0.25)
        hero.maxHp = hero.maxHp - reduction
        if hero.hp > hero.maxHp then hero.hp = hero.maxHp end
        Battle.AddFloatingText(state, hero.col, hero.row, "最大HP-" .. reduction .. "!", {200, 50, 50, 255}, "hit", 3.0)
        Battle.AddLog(state, "厄运轮盘：最大HP降低25%！(-" .. reduction .. ")")

    elseif outcome.id == "output_down" then
        state.doomOutputDownTurns = (state.doomOutputDownTurns or 0) + 10
        Battle.AddFloatingText(state, hero.col, hero.row, "输出-30%!", {180, 80, 200, 255}, "hit", 3.0)
        Battle.AddLog(state, "厄运轮盘：10回合内输出降低30%！")

    elseif outcome.id == "gold_loss" then
        local lost = math.floor((state.gold or 0) / 2)
        state.gold = (state.gold or 0) - lost
        Battle.AddFloatingText(state, hero.col, hero.row, "破财 -" .. lost .. "金币", {200, 150, 50, 255}, "hit", 3.0)
        Battle.AddLog(state, "厄运轮盘：破财消灾！失去" .. lost .. "金币！")

    elseif outcome.id == "poison" then
        state.doomPoisonTurns = (state.doomPoisonTurns or 0) + 5
        Battle.AddFloatingText(state, hero.col, hero.row, "中毒5回合!", {120, 200, 50, 255}, "hit", 3.0)
        Battle.AddLog(state, "厄运轮盘：暗毒侵蚀！5回合每回合损失5%HP！")

    elseif outcome.id == "max_hp_small_down" then
        hero.maxHp = math.max(1, hero.maxHp - 15)
        if hero.hp > hero.maxHp then hero.hp = hero.maxHp end
        Battle.AddFloatingText(state, hero.col, hero.row, "HP上限-15!", {180, 60, 60, 255}, "hit", 3.0)
        Battle.AddLog(state, "厄运轮盘：虚弱诅咒！最大HP-15！")

    elseif outcome.id == "silence" then
        hero.silencedTurns = (hero.silencedTurns or 0) + 3
        Battle.AddFloatingText(state, hero.col, hero.row, "沉默3回合!", {100, 100, 150, 255}, "hit", 3.0)
        Battle.AddLog(state, "厄运轮盘：封喉之咒！3回合内无法攻击！")

    elseif outcome.id == "nothing" then
        state.gold = (state.gold or 0) + 3
        Battle.AddFloatingText(state, hero.col, hero.row, "虚惊一场 +3金币", {200, 200, 200, 255}, nil, 3.0)
        Battle.AddLog(state, "厄运轮盘：虚惊一场！获得3金币安慰奖")
    end
end

-- ============================================================================
-- 关闭弹窗
-- ============================================================================

function WheelPopup.Close()
    isOpen = false
    animState = "closed"
    particles = {}

    -- pendingExtraSkillPick 由 TurnFlow 的 onCloseCb 处理，此处不提前清除

    if onCloseCb then
        onCloseCb()
        onCloseCb = nil
    end

    AM.PlaySFX("ui_popup_close", 0.6)
end

--- 是否正在显示轮盘
function WheelPopup.IsOpen()
    return isOpen
end

return WheelPopup
