-- ============================================================================
-- BoardWidget_Overlays - 全屏叠加层渲染（从 BoardWidget.lua 拆分）
-- ctx 字段: nvg, l, t, hexSize, ox, oy, shakeX, shakeY, theme
-- 全局依赖: G, HexGrid, Battle, UI
-- ============================================================================
---@diagnostic disable: redefined-local, undefined-global

local G         = require "GameState"
local HexGrid   = require "HexGrid"
local Battle    = require "Battle"
local UI        = require("urhox-libs/UI")
local IconAtlas = require "IconAtlas"

local BoardWidget_Overlays = {}

--- 渲染所有全屏叠加层（连击公告、Boss公告、回合提示、技能横幅等）
--- @param ctx table  {nvg, l, t, hexSize, ox, oy, shakeX, shakeY, theme}
function BoardWidget_Overlays.Render(ctx)
    local nvg     = ctx.nvg
    local l       = ctx.l
    local t       = ctx.t
    local hexSize = ctx.hexSize
    local ox      = ctx.ox
    local oy      = ctx.oy
    local shakeX  = ctx.shakeX
    local shakeY  = ctx.shakeY
    local theme   = ctx.theme

    -- 9. Combo 大字显示（已移除：只保留中文连击公告，避免重复显示拖慢节奏）

    -- 9.5 时间冻结全屏指示
    if G.battle.timeFreezeActive then
        local freezePulse = math.sin((G.time or 0) * 3.0) * 0.3 + 0.7
        -- 半透明蓝色叠层
        nvgBeginPath(nvg)
        nvgRect(nvg, l.x, l.y, l.w, l.h)
        nvgFillColor(nvg, nvgRGBA(80, 150, 255, math.floor(15 * freezePulse)))
        nvgFill(nvg)
        -- 时间冻结提示文字
        nvgFontSize(nvg, 30)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(120, 200, 255, math.floor(180 * freezePulse)))
        nvgText(nvg, l.x + l.w / 2, l.y + 66, "⏳ 时间冻结中")
    end

    -- 9.6 呼唤风沙持续效果覆盖层（全屏黄沙暴风特效）
    if G.battle.sandFuryActive then
        local furyTime = G.time or 0
        local turnsLeft = G.battle.sandFuryTurns or 0
        local pulse = 0.6 + 0.4 * math.sin(furyTime * 2.0)

        -- ① 全屏黄沙底色渐变（上深下浅，模拟沙暴遮天）
        nvgBeginPath(nvg)
        nvgRect(nvg, l.x, l.y, l.w, l.h)
        nvgFillPaint(nvg, nvgLinearGradient(nvg, l.x, l.y, l.x, l.y + l.h,
            nvgRGBA(180, 130, 40, math.floor(45 * pulse)),
            nvgRGBA(200, 160, 60, math.floor(20 * pulse))))
        nvgFill(nvg)

        -- ② 横向大沙带（3条不同速度的水平沙雾带，模拟狂风卷沙）
        for band = 1, 3 do
            local bandY = l.y + l.h * (0.2 + band * 0.2) + math.sin(furyTime * (1.5 + band * 0.3)) * 15
            local bandH = l.h * (0.08 + band * 0.02)
            local bandAlpha = math.floor((30 + band * 8) * pulse)
            local shiftX = (furyTime * (60 + band * 25)) % l.w
            nvgBeginPath(nvg)
            nvgRect(nvg, l.x - shiftX, bandY, l.w + shiftX, bandH)
            nvgFillColor(nvg, nvgRGBA(210, 170, 70, bandAlpha))
            nvgFill(nvg)
        end

        -- ③ 大量飞沙粒子（40颗，横向高速飘动 + 轻微纵向抖动）
        for i = 1, 40 do
            local seed = i * 97.3
            local speed = 80 + (i % 5) * 30
            local sx = l.x + ((seed + furyTime * speed) % l.w)
            local sy = l.y + ((seed * 1.7) % l.h) + math.sin(furyTime * 3 + i) * 4
            local sz = 1.5 + (i % 4) * 0.8
            local alpha = math.floor((60 + (i % 3) * 25) * pulse)
            nvgBeginPath(nvg)
            -- 沙粒用椭圆（水平拉长，模拟风速感）
            nvgEllipse(nvg, sx, sy, sz * 2.0, sz * 0.7)
            nvgFillColor(nvg, nvgRGBA(220, 180, 80, alpha))
            nvgFill(nvg)
        end

        -- ④ 边缘沙尘加重（四边暗角渐变，增加暴风感）
        local edgeSize = l.w * 0.18
        -- 左边缘
        nvgBeginPath(nvg)
        nvgRect(nvg, l.x, l.y, edgeSize, l.h)
        nvgFillPaint(nvg, nvgLinearGradient(nvg, l.x, l.y, l.x + edgeSize, l.y,
            nvgRGBA(160, 120, 40, math.floor(50 * pulse)), nvgRGBA(160, 120, 40, 0)))
        nvgFill(nvg)
        -- 右边缘
        nvgBeginPath(nvg)
        nvgRect(nvg, l.x + l.w - edgeSize, l.y, edgeSize, l.h)
        nvgFillPaint(nvg, nvgLinearGradient(nvg, l.x + l.w - edgeSize, l.y, l.x + l.w, l.y,
            nvgRGBA(160, 120, 40, 0), nvgRGBA(160, 120, 40, math.floor(50 * pulse))))
        nvgFill(nvg)

        -- ⑤ 旋转风线（2条弧形风线在画面上旋转）
        for w = 1, 2 do
            local wcx = l.x + l.w * (0.3 + w * 0.25)
            local wcy = l.y + l.h * 0.5
            local wr = l.w * 0.25
            local wspin = furyTime * (2.0 + w * 0.5) * (w % 2 == 0 and -1 or 1)
            nvgBeginPath(nvg)
            nvgArc(nvg, wcx, wcy, wr, wspin, wspin + math.pi * 0.8, 1)
            nvgStrokeColor(nvg, nvgRGBA(230, 190, 90, math.floor(40 * pulse)))
            nvgStrokeWidth(nvg, 2.5)
            nvgStroke(nvg)
        end

        -- ⑥ 顶部状态栏：风沙剩余回合数
        local barW = 170
        local barH = 30
        local barX = l.x + l.w / 2 - barW / 2
        local barY = l.y + 36
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, barX, barY, barW, barH, 15)
        nvgFillColor(nvg, nvgRGBA(50, 35, 10, 200))
        nvgFill(nvg)
        nvgStrokeColor(nvg, nvgRGBA(230, 180, 60, 180))
        nvgStrokeWidth(nvg, 1.5)
        nvgStroke(nvg)
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 17)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(255, 220, 80, 240))
        nvgText(nvg, barX + barW / 2, barY + barH / 2,
            string.format("🌪️ 风沙肆虐 %d回合", turnsLeft))
    end

    -- 9.8 连击奖励全屏公告
    local ann = G.battle.comboAnnouncement
    if ann and ann.timer > 0 then
        local progress = 1.0 - ann.timer / ann.maxTimer
        local c = ann.colors or { glow = {255, 200, 60}, text = {255, 230, 100}, flash = {255, 220, 80} }

        -- 入场动画：快速放大 → 回弹 → 稳定 → 淡出
        local scale, alphaF
        if progress < 0.08 then
            -- 爆发放大
            scale = progress / 0.08 * 2.5
            alphaF = progress / 0.08
        elseif progress < 0.18 then
            -- 回弹收缩
            scale = 2.5 - (progress - 0.08) / 0.1 * 1.3
            alphaF = 1.0
        elseif progress < 0.25 then
            -- 轻微弹跳
            scale = 1.2 + math.sin((progress - 0.18) / 0.07 * math.pi) * 0.15
            alphaF = 1.0
        elseif progress < 0.75 then
            -- 稳定显示
            scale = 1.0
            alphaF = 1.0
        else
            -- 淡出上飘
            scale = 1.0
            alphaF = 1.0 - (progress - 0.75) / 0.25
        end

        local alpha = math.floor(math.max(0, math.min(255, alphaF * 255)))
        if alpha > 5 then
            local centerX = l.x + l.w / 2
            -- 放在击杀目标条下方，不遮挡棋盘
            -- 如果 Boss 技能公告正在播放，下移避让（技能横幅高度约 120px，起始 y+50）
            local hasBossAnn = (G.battle.bossSkillAnnounce and G.battle.bossSkillAnnounce.timer > 0)
            -- killBar 高度约 44+36=80px，公告放在其下方
            local hasKillBar = (G.killBar and G.killBar:IsVisible())
            local baseY = hasKillBar and (l.y + 145) or (l.y + 105)
            local centerY = hasBossAnn and (baseY + 100) or baseY
            -- 淡出时上飘
            if progress > 0.75 then
                centerY = centerY - (progress - 0.75) / 0.25 * 25
            end

            nvgSave(nvg)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

            -- 背景光晕带（紧凑高度）
            local bannerH = 70 * scale
            local bannerAlpha = math.floor(alpha * 0.35)
            nvgBeginPath(nvg)
            nvgRect(nvg, l.x, centerY - bannerH / 2, l.w, bannerH)
            nvgFillColor(nvg, nvgRGBA(0, 0, 0, bannerAlpha))
            nvgFill(nvg)

            -- 发光边线（上下）
            local glowAlpha = math.floor(alpha * 0.6)
            nvgBeginPath(nvg)
            nvgRect(nvg, l.x, centerY - bannerH / 2, l.w, 2)
            nvgFillColor(nvg, nvgRGBA(c.glow[1], c.glow[2], c.glow[3], glowAlpha))
            nvgFill(nvg)
            nvgBeginPath(nvg)
            nvgRect(nvg, l.x, centerY + bannerH / 2 - 2, l.w, 2)
            nvgFillColor(nvg, nvgRGBA(c.glow[1], c.glow[2], c.glow[3], glowAlpha))
            nvgFill(nvg)

            -- 图标 + 标题横排：整体居中
            local title = ann.threshold .. "连击! " .. (ann.name or "")
            local iconId = ann.icon

            local iconSize = 36 * scale
            local gap = 8 * scale
            local hasIcon = iconId and IconAtlas.PATHS[iconId]

            -- 测量标题文本宽度，计算整体居中位置
            nvgFontSize(nvg, 28 * scale)
            nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            local titleW = nvgTextBounds(nvg, 0, 0, title)
            local totalW = titleW + (hasIcon and (iconSize + gap) or 0)
            local groupX = centerX - totalW / 2

            -- 图标（使用 IconAtlas 绘制图片）
            if hasIcon then
                IconAtlas.DrawNVG(nvg, iconId, groupX + iconSize / 2, centerY - 4, iconSize, alpha / 255)
            end

            -- 主标题（在图标右侧）
            local titleX = groupX + (hasIcon and (iconSize + gap) or 0)
            nvgFontBlur(nvg, 5)
            nvgFillColor(nvg, nvgRGBA(c.glow[1], c.glow[2], c.glow[3], math.floor(alpha * 0.8)))
            nvgText(nvg, titleX, centerY - 4, title)
            nvgFontBlur(nvg, 0)
            nvgFillColor(nvg, nvgRGBA(c.text[1], c.text[2], c.text[3], alpha))
            nvgText(nvg, titleX, centerY - 4, title)

            -- 描述文字（标题下方一行，居中）
            if ann.desc and ann.desc ~= "" then
                nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFontSize(nvg, 15 * math.min(scale, 1.2))
                nvgFillColor(nvg, nvgRGBA(220, 220, 220, math.floor(alpha * 0.7)))
                nvgText(nvg, centerX, centerY + 20, ann.desc)
            end

            nvgRestore(nvg)
        end
    end

    -- 9.8.5 & 9.8.6 金色套装效果公告（v3: 右上角紧凑弹窗，不遮挡游戏区域）
    local function drawGoldBadge(ann, titleText, subText, badgeCY, alpha, scaleF, progress)
        nvgSave(nvg)

        local badgeW = 240
        local badgeH = 62
        -- 右上角定位：距右边缘 10px
        local badgeCX = l.x + l.w - badgeW * 0.5 - 10

        -- 缩放变换（以中心为原点）
        nvgTranslate(nvg, badgeCX, badgeCY)
        nvgScale(nvg, scaleF, scaleF)
        nvgTranslate(nvg, -badgeCX, -badgeCY)

        local badgeX = badgeCX - badgeW * 0.5
        local badgeY = badgeCY - badgeH * 0.5

        -- 外部脉冲光晕（呼吸感）
        local time = ann.maxTimer - ann.timer
        local pulseR = 6 + math.sin(time * 4.0) * 2
        local pulseA = math.floor(alpha * (0.10 + math.sin(time * 3.0) * 0.04))
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, badgeX - pulseR, badgeY - pulseR, badgeW + pulseR * 2, badgeH + pulseR * 2, 16 + pulseR * 0.5)
        nvgFillColor(nvg, nvgRGBA(255, 215, 0, pulseA))
        nvgFill(nvg)

        -- 金色渐变背景
        local bgPaint = nvgLinearGradient(nvg, badgeX, badgeY, badgeX + badgeW, badgeY + badgeH,
            nvgRGBA(55, 35, 5, math.floor(alpha * 0.94)),
            nvgRGBA(35, 20, 0, math.floor(alpha * 0.94)))
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, badgeX, badgeY, badgeW, badgeH, 12)
        nvgFillPaint(nvg, bgPaint)
        nvgFill(nvg)

        -- 内部顶部高光条
        local hlPaint = nvgLinearGradient(nvg, badgeX, badgeY, badgeX, badgeY + 14,
            nvgRGBA(255, 240, 150, math.floor(alpha * 0.12)),
            nvgRGBA(255, 240, 150, 0))
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, badgeX + 2, badgeY + 2, badgeW - 4, 14, 10)
        nvgFillPaint(nvg, hlPaint)
        nvgFill(nvg)

        -- 金色边框（双层）
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, badgeX, badgeY, badgeW, badgeH, 12)
        nvgStrokeColor(nvg, nvgRGBA(255, 215, 0, math.floor(alpha * 0.6)))
        nvgStrokeWidth(nvg, 1.5)
        nvgStroke(nvg)
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, badgeX + 2, badgeY + 2, badgeW - 4, badgeH - 4, 10)
        nvgStrokeColor(nvg, nvgRGBA(255, 230, 100, math.floor(alpha * 0.2)))
        nvgStrokeWidth(nvg, 1.0)
        nvgStroke(nvg)

        -- 左侧金色竖条（发光）
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, badgeX + 2, badgeY + 8, 4, badgeH - 16, 2)
        nvgFillColor(nvg, nvgRGBA(255, 215, 0, alpha))
        nvgFill(nvg)
        -- 竖条光晕
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, badgeX - 1, badgeY + 6, 8, badgeH - 12, 4)
        nvgFillColor(nvg, nvgRGBA(255, 215, 0, math.floor(alpha * 0.15)))
        nvgFill(nvg)

        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        -- 标题
        nvgFontSize(nvg, 20)
        nvgFillColor(nvg, nvgRGBA(255, 235, 110, alpha))
        nvgText(nvg, badgeX + 14, badgeY + 22, titleText)
        -- 副标题
        nvgFontSize(nvg, 14)
        nvgFillColor(nvg, nvgRGBA(255, 210, 100, math.floor(alpha * 0.85)))
        nvgText(nvg, badgeX + 16, badgeY + 44, subText)

        -- 金色闪光粒子
        if progress > 0.05 and progress < 0.88 then
            local sparkleAlpha = alpha
            if progress < 0.15 then sparkleAlpha = math.floor(alpha * (progress - 0.05) / 0.10) end
            if progress > 0.75 then sparkleAlpha = math.floor(alpha * (0.88 - progress) / 0.13) end
            for i = 1, 6 do
                local seed = i * 137.5 + (ann.maxTimer or 2)
                local px = badgeX + (math.sin(seed + time * (1.5 + i * 0.3)) * 0.5 + 0.5) * badgeW
                local py = badgeY + (math.cos(seed * 1.7 + time * (1.2 + i * 0.2)) * 0.5 + 0.5) * badgeH
                local sz = 2.0 + math.sin(time * 3 + seed) * 1.0
                local pAlpha = math.floor(sparkleAlpha * (0.5 + math.sin(time * 4 + seed * 2) * 0.3))
                -- 粒子光晕
                nvgBeginPath(nvg)
                nvgCircle(nvg, px, py, sz + 2)
                nvgFillColor(nvg, nvgRGBA(255, 220, 50, math.floor(pAlpha * 0.3)))
                nvgFill(nvg)
                -- 粒子核心
                nvgBeginPath(nvg)
                nvgCircle(nvg, px, py, sz)
                nvgFillColor(nvg, nvgRGBA(255, 245, 180, pAlpha))
                nvgFill(nvg)
            end
        end

        nvgRestore(nvg)
    end

    -- 酷炫弹入/弹出动画计算（缩放 + 弹性 + 淡入淡出）
    local function calcBadgeAnim(ann)
        local progress = 1.0 - ann.timer / ann.maxTimer
        local scaleF, alphaF

        if progress < 0.12 then
            -- 弹入阶段：从小到大，带弹性过冲
            local t = progress / 0.12
            -- elastic overshoot: 先冲到1.15再回落
            local ease = 1.0 - (1.0 - t) * (1.0 - t)
            scaleF = ease * 1.15
            alphaF = math.min(1.0, t * 1.5)
        elseif progress < 0.20 then
            -- 回弹稳定
            local t = (progress - 0.12) / 0.08
            scaleF = 1.15 - t * 0.15  -- 1.15 → 1.0
            alphaF = 1.0
        elseif progress < 0.78 then
            -- 稳定展示
            scaleF = 1.0
            alphaF = 1.0
        else
            -- 淡出缩小
            local t = (progress - 0.78) / 0.22
            local ease = t * t
            scaleF = 1.0 - ease * 0.3  -- 1.0 → 0.7
            alphaF = 1.0 - ease
        end

        local alpha = math.floor(math.max(0, math.min(255, alphaF * 255)))
        return progress, scaleF, alpha
    end

    -- 如果连击公告正在播放，金色徽章下移避让
    local goldBadgeExtraY = (ann and ann.timer and ann.timer > 0) and 80 or 0

    local cmAnn = G.battle.comboMasteryAnnouncement
    if cmAnn and cmAnn.timer > 0 then
        local progress, scaleF, alpha = calcBadgeAnim(cmAnn)
        if alpha > 5 then
            -- 右上角位置：距顶部约 12%，连击公告激活时下移
            local badgeCY = l.y + l.h * 0.12 + goldBadgeExtraY
            local subText = string.format("连击 %d -> %d", cmAnn.oldCombo, cmAnn.newCombo)
            drawGoldBadge(cmAnn, "🔥 连击心得发动!", subText, badgeCY, alpha, scaleF, progress)
        end
    end

    local lpAnn = G.battle.leapPioneerAnnouncement
    if lpAnn and lpAnn.timer > 0 then
        local progress, scaleF, alpha = calcBadgeAnim(lpAnn)
        if alpha > 5 then
            -- 两个公告同时出现时，第二个往下偏移 70px；连击公告激活时整体下移
            local offsetY = (cmAnn and cmAnn.timer and cmAnn.timer > 0) and 70 or 0
            local badgeCY = l.y + l.h * 0.12 + goldBadgeExtraY + offsetY
            local lpSubText = (lpAnn.jumpCount == 3) and "连续跳跃三个敌人!" or "连续跳跃两个敌人!"
            drawGoldBadge(lpAnn, "🦅 飞跃先锋发动!", lpSubText, badgeCY, alpha, scaleF, progress)
        end
    end

    local shAnn = G.battle.soulHunterAnnouncement
    if shAnn and shAnn.timer > 0 then
        local progress, scaleF, alpha = calcBadgeAnim(shAnn)
        if alpha > 5 then
            -- 排在其他公告下方
            local offsetY = 0
            if cmAnn and cmAnn.timer and cmAnn.timer > 0 then offsetY = offsetY + 70 end
            if lpAnn and lpAnn.timer and lpAnn.timer > 0 then offsetY = offsetY + 70 end
            local badgeCY = l.y + l.h * 0.12 + goldBadgeExtraY + offsetY
            local stacks = shAnn.stacks or (G.battle.setEffects and G.battle.setEffects.bloodRageStacks) or 1
            drawGoldBadge(shAnn, "🩸 嗜血猎魂发动!", string.format("血怒 ATKx1.5  叠层x%d", stacks), badgeCY, alpha, scaleF, progress)
        end
    end

    -- 9.9 Boss 入场全屏公告
    local bossAnn = G.battle.bossAnnouncement
    if bossAnn and bossAnn.timer > 0 then
        local progress = 1.0 - bossAnn.timer / bossAnn.maxTimer

        -- 动画阶段
        local alphaF, scale, overlayAlpha
        if progress < 0.10 then
            -- 暗幕渐入 + 图标猛冲放大
            local t = progress / 0.10
            alphaF = t
            scale = 3.0 - t * 1.8  -- 3.0 → 1.2
            overlayAlpha = t * 0.55
        elseif progress < 0.20 then
            -- 回弹稳定
            local t = (progress - 0.10) / 0.10
            alphaF = 1.0
            scale = 1.2 - t * 0.2  -- 1.2 → 1.0
            overlayAlpha = 0.55
        elseif progress < 0.70 then
            -- 稳定显示（微呼吸）
            local breathe = math.sin((progress - 0.20) / 0.50 * math.pi * 3) * 0.03
            alphaF = 1.0
            scale = 1.0 + breathe
            overlayAlpha = 0.55
        else
            -- 淡出
            local t = (progress - 0.70) / 0.30
            alphaF = 1.0 - t
            scale = 1.0
            overlayAlpha = 0.55 * (1.0 - t)
        end

        local alpha = math.floor(math.max(0, math.min(255, alphaF * 255)))
        if alpha > 3 then
            local centerX = l.x + l.w / 2
            local centerY = l.y + l.h * 0.38

            nvgSave(nvg)

            -- 全屏暗幕（压迫感）
            nvgBeginPath(nvg)
            nvgRect(nvg, l.x, l.y, l.w, l.h)
            nvgFillColor(nvg, nvgRGBA(10, 0, 0, math.floor(overlayAlpha * 255)))
            nvgFill(nvg)

            -- 横幅背景条（暗红渐变）
            local bannerH = 90 * scale
            nvgBeginPath(nvg)
            nvgRect(nvg, l.x, centerY - bannerH / 2, l.w, bannerH)
            nvgFillColor(nvg, nvgRGBA(40, 5, 5, math.floor(alpha * 0.7)))
            nvgFill(nvg)

            -- 上下红色光线边框
            local glowA = math.floor(alpha * 0.8)
            for _, yOff in ipairs({ centerY - bannerH / 2, centerY + bannerH / 2 - 2 }) do
                nvgBeginPath(nvg)
                nvgRect(nvg, l.x, yOff, l.w, 2)
                nvgFillColor(nvg, nvgRGBA(200, 40, 40, glowA))
                nvgFill(nvg)
            end

            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

            -- "WARNING" 小字（上方）
            if progress > 0.08 then
                local warnA = math.floor(alpha * 0.5)
                local blink = math.sin((G.time or 0) * 6) > 0
                if blink or progress > 0.70 then
                    nvgFontSize(nvg, 15 * math.min(scale, 1.3))
                    nvgFillColor(nvg, nvgRGBA(255, 80, 80, warnA))
                    nvgText(nvg, centerX, centerY - 30 * scale, "⚠ WARNING ⚠")
                end
            end

            -- Boss 图标（大）
            nvgFontSize(nvg, 40 * scale)
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, alpha))
            nvgText(nvg, centerX - 90 * scale, centerY + 2, bossAnn.icon)

            -- Boss 名字（主标题）
            nvgFontSize(nvg, 32 * scale)
            -- 红色外发光
            nvgFontBlur(nvg, 6)
            nvgFillColor(nvg, nvgRGBA(255, 50, 30, math.floor(alpha * 0.7)))
            nvgText(nvg, centerX + 10, centerY, bossAnn.bossName)
            -- 实体字
            nvgFontBlur(nvg, 0)
            nvgFillColor(nvg, nvgRGBA(255, 220, 200, alpha))
            nvgText(nvg, centerX + 10, centerY, bossAnn.bossName)

            -- 副标题（下方）
            local subtitle = "第" .. bossAnn.chapter .. "章 Boss战"
            nvgFontSize(nvg, 16 * math.min(scale, 1.2))
            nvgFillColor(nvg, nvgRGBA(255, 160, 140, math.floor(alpha * 0.65)))
            nvgText(nvg, centerX, centerY + 24 * scale, subtitle)

            nvgRestore(nvg)
        end
    end

    -- 10. 回合提示
    if G.battle.phase == "ENEMY_TURN" then
        nvgFontSize(nvg, 26)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(255, 120, 120, 220))
        nvgText(nvg, l.x + l.w / 2, l.y + l.h - 24, "敌人回合...")
    elseif G.battle.phase == "PLAYER_EXECUTE" then
        nvgFontSize(nvg, 26)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(255, 215, 0, 220))
        nvgText(nvg, l.x + l.w / 2, l.y + l.h - 24, "执行跳跃...")
    end

    -- 11. Boss 技能公告（大区域压迫感横幅）
    local ska = G.battle.bossSkillAnnounce
    if ska and ska.timer > 0 then
        local progress = 1.0 - ska.timer / ska.maxTimer
        local cr, cg, cb = ska.color[1], ska.color[2], ska.color[3]
        local gt = G.time or 0

        -- 动画: 0-10% 展开, 10-80% 停留(闪烁), 80-100% 收缩淡出
        local alphaF, scaleY
        if progress < 0.10 then
            local t = progress / 0.10
            local ease = 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t)
            alphaF = ease
            scaleY = ease
        elseif progress < 0.80 then
            alphaF = 1.0
            scaleY = 1.0
        else
            local t = (progress - 0.80) / 0.20
            local ease = t * t
            alphaF = 1.0 - ease
            scaleY = 1.0 - ease * 0.5
        end

        local alpha = math.floor(math.max(0, math.min(255, alphaF * 255)))
        if alpha > 3 then
            nvgSave(nvg)

            -- 横幅参数：覆盖棋盘上方大区域（留出顶部间距）
            local bannerH = 120 * scaleY
            local bannerY = l.y + 50
            local bannerX = l.x
            local bannerW = l.w
            local centerX = bannerX + bannerW / 2
            local centerY = bannerY + bannerH / 2

            -- 主背景（深色 + 主题色渐变）
            nvgBeginPath(nvg)
            nvgRect(nvg, bannerX, bannerY, bannerW, bannerH)
            nvgFillColor(nvg, nvgRGBA(8, 2, 15, math.floor(alpha * 0.92)))
            nvgFill(nvg)

            -- 主题色横向渐变叠加（脉动闪烁）
            local pulse = 0.25 + math.sin(gt * 5.0) * 0.15
            nvgBeginPath(nvg)
            nvgRect(nvg, bannerX, bannerY, bannerW, bannerH)
            nvgFillPaint(nvg, nvgLinearGradient(nvg,
                bannerX, bannerY, bannerX + bannerW, bannerY,
                nvgRGBA(cr, cg, cb, math.floor(alpha * pulse * 0.5)),
                nvgRGBA(cr, cg, cb, math.floor(alpha * pulse))))
            nvgFill(nvg)

            -- 3) 上下边框发光线（闪烁）
            local borderPulse = 0.6 + math.sin(gt * 8.0) * 0.4
            local borderA = math.floor(alpha * borderPulse)
            for _, edgeY in ipairs({ bannerY, bannerY + bannerH - 2 }) do
                nvgBeginPath(nvg)
                nvgRect(nvg, bannerX, edgeY, bannerW, 2)
                nvgFillPaint(nvg, nvgLinearGradient(nvg,
                    bannerX, edgeY, bannerX + bannerW, edgeY,
                    nvgRGBA(cr, cg, cb, 0),
                    nvgRGBA(cr, cg, cb, borderA)))
                nvgFill(nvg)
                -- 对称渐变
                nvgBeginPath(nvg)
                nvgRect(nvg, bannerX, edgeY, bannerW, 2)
                nvgFillPaint(nvg, nvgLinearGradient(nvg,
                    bannerX + bannerW, edgeY, bannerX, edgeY,
                    nvgRGBA(cr, cg, cb, 0),
                    nvgRGBA(cr, cg, cb, borderA)))
                nvgFill(nvg)
            end

            -- 4) 左侧主题色竖条（粗）
            nvgBeginPath(nvg)
            nvgRect(nvg, bannerX, bannerY, 5, bannerH)
            nvgFillColor(nvg, nvgRGBA(cr, cg, cb, alpha))
            nvgFill(nvg)

            -- 5) 扫光效果（从左到右扫过的亮条）
            local sweepT = (gt * 0.4) % 1.0
            local sweepX = bannerX + sweepT * bannerW
            local sweepW = bannerW * 0.15
            nvgBeginPath(nvg)
            nvgRect(nvg, sweepX, bannerY, sweepW, bannerH)
            nvgFillPaint(nvg, nvgLinearGradient(nvg,
                sweepX, bannerY, sweepX + sweepW, bannerY,
                nvgRGBA(cr, cg, cb, 0),
                nvgRGBA(255, 255, 255, math.floor(alpha * 0.08))))
            nvgFill(nvg)

            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

            -- 6) 技能图标（大号，居中偏左）
            local iconSize = 48
            nvgFontSize(nvg, iconSize)
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, alpha))
            nvgText(nvg, centerX - 100, centerY - 8, ska.icon)

            -- 7) 技能名称（大字，发光效果）
            nvgFontSize(nvg, 36)
            -- 外发光
            nvgFontBlur(nvg, 10)
            nvgFillColor(nvg, nvgRGBA(cr, cg, cb, math.floor(alpha * 0.7)))
            nvgText(nvg, centerX + 10, centerY - 18, ska.skillName)
            -- 实体字
            nvgFontBlur(nvg, 0)
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, alpha))
            nvgText(nvg, centerX + 10, centerY - 18, ska.skillName)

            -- 8) 技能描述
            nvgFontSize(nvg, 20)
            nvgFillColor(nvg, nvgRGBA(220, 210, 200, math.floor(alpha * 0.85)))
            nvgText(nvg, centerX + 10, centerY + 20, ska.desc)

            -- 9) Boss名称（右下角小字）
            if ska.bossName and #ska.bossName > 0 then
                nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_BOTTOM)
                nvgFontSize(nvg, 13)
                nvgFillColor(nvg, nvgRGBA(cr, cg, cb, math.floor(alpha * 0.5)))
                nvgText(nvg, bannerX + bannerW - 12, bannerY + bannerH - 8, ska.bossName)
            end

            -- 10) 两侧装饰三角
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            local triA = math.floor(alpha * (0.4 + math.sin(gt * 6.0) * 0.2))
            nvgFontSize(nvg, 20)
            nvgFillColor(nvg, nvgRGBA(cr, cg, cb, triA))
            nvgText(nvg, bannerX + 24, centerY, "<>")
            nvgText(nvg, bannerX + bannerW - 24, centerY, "<>")

            nvgRestore(nvg)
        end
    end

    -- 12. Boss 狂暴二阶段红色警告横幅
    local era = G.battle.bossEnrageAnnounce
    if era and era.timer > 0 then
        local progress = 1.0 - era.timer / era.maxTimer
        local gt = G.time or 0

        -- 动画: 0-15% 闪烁展开, 15-75% 停留震动, 75-100% 收缩淡出
        local alphaF, shakeX
        if progress < 0.15 then
            local t = progress / 0.15
            -- 快速闪烁3次
            local blink = math.sin(t * math.pi * 6) > 0
            alphaF = blink and t or (t * 0.3)
            shakeX = math.sin(t * math.pi * 8) * 4 * (1.0 - t)
        elseif progress < 0.75 then
            alphaF = 1.0
            shakeX = math.sin(gt * 15) * 2 * (1.0 - (progress - 0.15) / 0.60)
        else
            local t = (progress - 0.75) / 0.25
            alphaF = 1.0 - t * t
            shakeX = 0
        end

        local alpha = math.floor(math.max(0, math.min(255, alphaF * 255)))
        if alpha > 3 then
            nvgSave(nvg)

            local bannerH = 100
            local bannerY = l.y + l.h * 0.30
            local bannerX = l.x + shakeX
            local bannerW = l.w
            local centerX = bannerX + bannerW / 2
            local centerY = bannerY + bannerH / 2

            -- 全屏红色暗幕
            nvgBeginPath(nvg)
            nvgRect(nvg, l.x, l.y, l.w, l.h)
            local overlayA = math.floor(alpha * 0.35)
            nvgFillColor(nvg, nvgRGBA(30, 0, 0, overlayA))
            nvgFill(nvg)

            -- 横幅深红背景
            nvgBeginPath(nvg)
            nvgRect(nvg, bannerX, bannerY, bannerW, bannerH)
            nvgFillColor(nvg, nvgRGBA(25, 0, 0, math.floor(alpha * 0.9)))
            nvgFill(nvg)

            -- 红色脉动渐变叠加
            local rPulse = 0.3 + math.sin(gt * 6.0) * 0.2
            nvgBeginPath(nvg)
            nvgRect(nvg, bannerX, bannerY, bannerW, bannerH)
            nvgFillPaint(nvg, nvgLinearGradient(nvg,
                bannerX, bannerY, bannerX + bannerW, bannerY + bannerH,
                nvgRGBA(200, 20, 20, math.floor(alpha * rPulse)),
                nvgRGBA(120, 0, 0, math.floor(alpha * rPulse * 0.5))))
            nvgFill(nvg)

            -- 3) 上下边框红色发光线（快速闪烁）
            local bFlash = 0.5 + math.sin(gt * 12.0) * 0.5
            local bA = math.floor(alpha * bFlash)
            for _, edgeY in ipairs({ bannerY, bannerY + bannerH - 2 }) do
                nvgBeginPath(nvg)
                nvgRect(nvg, bannerX, edgeY, bannerW, 2.5)
                nvgFillColor(nvg, nvgRGBA(255, 40, 40, bA))
                nvgFill(nvg)
            end

            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

            -- 4) "⚠ WARNING ⚠"（闪烁）
            local warnBlink = math.sin(gt * 10) > 0
            if warnBlink then
                nvgFontSize(nvg, 14)
                nvgFillColor(nvg, nvgRGBA(255, 100, 80, math.floor(alpha * 0.7)))
                nvgText(nvg, centerX, centerY - 30, "⚠ WARNING ⚠")
            end

            -- 5) 主标题：💀 狂暴模式（红色大字 + 外发光）
            nvgFontSize(nvg, 32)
            -- 红色外发光
            nvgFontBlur(nvg, 10)
            nvgFillColor(nvg, nvgRGBA(255, 30, 10, math.floor(alpha * 0.8)))
            nvgText(nvg, centerX, centerY - 2, "💀 狂暴模式")
            -- 实体字
            nvgFontBlur(nvg, 0)
            nvgFillColor(nvg, nvgRGBA(255, 60, 40, alpha))
            nvgText(nvg, centerX, centerY - 2, "💀 狂暴模式")

            -- 6) 副标题
            nvgFontSize(nvg, 15)
            nvgFillColor(nvg, nvgRGBA(255, 150, 130, math.floor(alpha * 0.75)))
            nvgText(nvg, centerX, centerY + 24, era.subtitle or "Boss进入二阶段，攻击力大幅提升！")

            -- 7) 两侧红色菱形装饰（闪烁）
            local dA = math.floor(alpha * (0.5 + math.sin(gt * 8.0) * 0.3))
            nvgFontSize(nvg, 22)
            nvgFillColor(nvg, nvgRGBA(255, 40, 40, dA))
            nvgText(nvg, bannerX + 30, centerY, "<>")
            nvgText(nvg, bannerX + bannerW - 30, centerY, "<>")

            nvgRestore(nvg)
        end
    end

    -- === 最终：上下边缘渐变遮罩（棋盘无缝融入外部背景）===
    do
        -- layout already in ctx.l
        -- 外层容器背景色 {10, 8, 18}
        local obg = {10, 8, 18}
        -- 上方渐变遮罩：轻柔渐变，仅覆盖顶部约 8% 高度
        local topH = l.h * 0.08
        local topPaint = nvgLinearGradient(nvg, l.x, l.y, l.x, l.y + topH,
            nvgRGBA(obg[1], obg[2], obg[3], 200),
            nvgRGBA(obg[1], obg[2], obg[3], 0))
        nvgBeginPath(nvg)
        nvgRect(nvg, l.x, l.y, l.w, topH)
        nvgFillPaint(nvg, topPaint)
        nvgFill(nvg)

        -- 下方渐变遮罩：覆盖底部约 18% 高度
        local botH = l.h * 0.18
        local botPaint = nvgLinearGradient(nvg, l.x, l.y + l.h - botH, l.x, l.y + l.h,
            nvgRGBA(obg[1], obg[2], obg[3], 0),
            nvgRGBA(obg[1], obg[2], obg[3], 255))
        nvgBeginPath(nvg)
        nvgRect(nvg, l.x, l.y + l.h - botH, l.w, botH)
        nvgFillPaint(nvg, botPaint)
        nvgFill(nvg)
    end

    -- === 多格跳跃教程：胶囊形一体聚光灯高亮整条路径 ===
    if G.multiHopSpotlightActive and G.multiHopSpotlightJump and G.battle and G.battle.hero then
        -- layout already in ctx.l
        local jump = G.multiHopSpotlightJump
        -- 使用记录的起点坐标（规划阶段起点是 planHeroCol，非原始 hero 位置）
        local heroCol = G.multiHopSpotlightOriginCol or G.battle.hero.col
        local heroRow = G.multiHopSpotlightOriginRow or G.battle.hero.row
        local hx, hy = HexGrid.HexToPixel(heroCol, heroRow, hexSize, ox, oy)
        local jx, jy = HexGrid.HexToPixel(jump.jumpedCol, jump.jumpedRow, hexSize, ox, oy)
        local lx, ly = HexGrid.HexToPixel(jump.col, jump.row, hexSize, ox, oy)

        -- 胶囊参数：从英雄起点(hx,hy)到落点(lx,ly)，覆盖完整路径
        local capR = hexSize * 1.15  -- 胶囊半径（略大于格子）
        local ddx = lx - hx
        local ddy = ly - hy
        local pathLen = math.sqrt(ddx * ddx + ddy * ddy)
        -- 方向单位向量和法向量
        local ux, uy, nx, ny
        if pathLen > 1 then
            ux, uy = ddx / pathLen, ddy / pathLen
            nx, ny = -uy, ux  -- 法线（左侧）
        else
            ux, uy = 0, -1
            nx, ny = 1, 0
        end

        -- 胶囊形挖洞：用 NanoVG 路径画一个由两个半圆+两条直线组成的胶囊
        -- 半圆段数
        local segments = 16

        nvgSave(nvg)

        -- 1) 半透明遮罩 + 胶囊形挖洞（从跳板到落点）
        nvgBeginPath(nvg)
        nvgRect(nvg, l.x, l.y, l.w, l.h)
        nvgPathWinding(nvg, NVG_SOLID)

        -- 画胶囊形状作为 HOLE
        -- 从英雄端右侧开始，顺时针：右直线 → 落点半圆 → 左直线 → 英雄半圆
        nvgMoveTo(nvg, hx + nx * capR, hy + ny * capR)
        -- 右侧直线到落点
        nvgLineTo(nvg, lx + nx * capR, ly + ny * capR)
        -- 落点端半圆（顺时针，从右侧法线转到左侧法线）
        for i = 0, segments do
            local a = math.pi * i / segments  -- 0 → π
            local cosA = math.cos(a)
            local sinA = math.sin(a)
            local px = lx + capR * (nx * cosA + ux * sinA)
            local py = ly + capR * (ny * cosA + uy * sinA)
            nvgLineTo(nvg, px, py)
        end
        -- 左侧直线回英雄
        nvgLineTo(nvg, hx - nx * capR, hy - ny * capR)
        -- 英雄端半圆（顺时针，从左侧法线转到右侧法线）
        for i = 0, segments do
            local a = math.pi + math.pi * i / segments  -- π → 2π
            local cosA = math.cos(a)
            local sinA = math.sin(a)
            local px = hx + capR * (nx * cosA + ux * sinA)
            local py = hy + capR * (ny * cosA + uy * sinA)
            nvgLineTo(nvg, px, py)
        end
        nvgClosePath(nvg)
        nvgPathWinding(nvg, NVG_HOLE)
        nvgFillColor(nvg, nvgRGBA(0, 0, 0, 120))
        nvgFill(nvg)

        -- 2) 路径上的标注
        local pathCX = (hx + lx) / 2
        local pathCY = (hy + ly) / 2
        local t = G.time or 0

        -- 被跳过棋子（跳板）圆环高亮
        nvgBeginPath(nvg)
        nvgCircle(nvg, jx, jy, hexSize * 0.55)
        nvgStrokeColor(nvg, nvgRGBA(255, 120, 60, 200))
        nvgStrokeWidth(nvg, 2.5)
        nvgStroke(nvg)

        -- 落点脉冲光环
        local pulseR = hexSize * 0.5 + math.sin(t * 3.0) * hexSize * 0.15
        nvgBeginPath(nvg)
        nvgCircle(nvg, lx, ly, pulseR)
        nvgStrokeColor(nvg, nvgRGBA(60, 200, 255, 180))
        nvgStrokeWidth(nvg, 2.5)
        nvgStroke(nvg)

        -- 英雄起点标记（胶囊内，醒目的起点光环）
        local heroGlow = 0.4 + math.sin(t * 2.5) * 0.15
        nvgBeginPath(nvg)
        nvgCircle(nvg, hx, hy, hexSize * 0.55)
        nvgStrokeColor(nvg, nvgRGBA(100, 255, 180, 200))
        nvgStrokeWidth(nvg, 2.5)
        nvgStroke(nvg)
        nvgBeginPath(nvg)
        nvgCircle(nvg, hx, hy, hexSize * heroGlow)
        nvgFillColor(nvg, nvgRGBA(100, 255, 180, 30))
        nvgFill(nvg)

        -- 方向箭头（沿路径方向，在落点附近）
        local arrX = lx - ux * hexSize * 0.6
        local arrY = ly - uy * hexSize * 0.6
        local arrSize = hexSize * 0.3
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, arrX + ux * arrSize, arrY + uy * arrSize)
        nvgLineTo(nvg, arrX - ux * arrSize * 0.5 + nx * arrSize * 0.5, arrY - uy * arrSize * 0.5 + ny * arrSize * 0.5)
        nvgLineTo(nvg, arrX - ux * arrSize * 0.5 - nx * arrSize * 0.5, arrY - uy * arrSize * 0.5 - ny * arrSize * 0.5)
        nvgClosePath(nvg)
        nvgFillColor(nvg, nvgRGBA(60, 200, 255, 160))
        nvgFill(nvg)

        -- 4) 提示气泡：放在路径外侧，不遮挡
        local tipW = l.w * 0.78
        local tipH = 210
        local tipPad = 16

        -- 计算路径的屏幕空间包围盒（含胶囊区域+英雄标记）
        local pMinX = math.min(hx, jx, lx) - capR
        local pMaxX = math.max(hx, jx, lx) + capR
        local pMinY = math.min(hy, jy, ly) - capR
        local pMaxY = math.max(hy, jy, ly) + capR

        -- 优先放路径下方；不够放上方
        local tipX = math.max(l.x + 8, math.min(pathCX - tipW / 2, l.x + l.w - tipW - 8))
        local tipY = pMaxY + 20
        if tipY + tipH > l.y + l.h - 10 then
            -- 下方放不下，放上方
            tipY = pMinY - tipH - 20
        end
        if tipY < l.y + 10 then
            -- 上方也放不下，放左侧或右侧
            if pathCX < l.x + l.w / 2 then
                tipX = math.min(pMaxX + 16, l.x + l.w - tipW - 8)
            else
                tipX = math.max(pMinX - tipW - 16, l.x + 8)
            end
            tipY = math.max(l.y + 10, math.min(pathCY - tipH / 2, l.y + l.h - tipH - 10))
        end
        -- 最终安全 clamp：无论如何气泡必须完整在屏幕内
        tipX = math.max(l.x + 4, math.min(tipX, l.x + l.w - tipW - 4))
        tipY = math.max(l.y + 4, math.min(tipY, l.y + l.h - tipH - 4))

        -- 气泡背景
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, tipX, tipY, tipW, tipH, 14)
        nvgFillColor(nvg, nvgRGBA(12, 20, 30, 235))
        nvgFill(nvg)
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, tipX, tipY, tipW, tipH, 14)
        nvgStrokeColor(nvg, nvgRGBA(60, 200, 255, 100))
        nvgStrokeWidth(nvg, 1.5)
        nvgStroke(nvg)

        -- 标题
        local tipCX = tipX + tipW / 2
        nvgFontFace(nvg, UI.Theme.FontFace("sans", "bold"))
        nvgFontSize(nvg, 28)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(nvg, nvgRGBA(60, 230, 255, 255))
        nvgText(nvg, tipCX, tipY + tipPad, "🦘 多格跳跃")

        -- 描述文字
        nvgFontFace(nvg, UI.Theme.FontFace("sans", "normal"))
        nvgFontSize(nvg, 21)
        nvgFillColor(nvg, nvgRGBA(220, 225, 235, 230))
        local descY = tipY + tipPad + 40
        nvgText(nvg, tipCX, descY, "跳跃不限于相邻格！只要路径上有棋子，")
        nvgText(nvg, tipCX, descY + 30, "就能隔多格跳过去，跳得越远越好！")
        nvgFontSize(nvg, 17)
        nvgFillColor(nvg, nvgRGBA(255, 200, 100, 200))
        nvgText(nvg, tipCX, descY + 64, "⚠️ 注意：路径中间不能有其他敌人或道具挡路")

        -- 引导提示：点击终点格子跳跃
        nvgFontFace(nvg, UI.Theme.FontFace("sans", "bold"))
        nvgFontSize(nvg, 18)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        local hintAlpha = math.floor(160 + math.sin(t * 4) * 80)
        nvgFillColor(nvg, nvgRGBA(100, 255, 200, hintAlpha))
        nvgText(nvg, tipCX, tipY + tipH - tipPad - 16, "👆 点击高亮终点格子，试试多格跳！")

        -- 终点格子脉动高亮引导（在落点画一个呼吸光环）
        local landPulse = 0.6 + math.sin(t * 5) * 0.25
        local landAlpha = math.floor(180 + math.sin(t * 5) * 60)
        -- 外圈呼吸光环
        nvgBeginPath(nvg)
        nvgCircle(nvg, lx, ly, hexSize * landPulse)
        nvgStrokeColor(nvg, nvgRGBA(100, 255, 200, landAlpha))
        nvgStrokeWidth(nvg, 3.0)
        nvgStroke(nvg)
        -- 内圈柔光
        local landGlow = nvgRadialGradient(nvg,
            lx, ly, hexSize * 0.1, hexSize * landPulse * 0.8,
            nvgRGBA(100, 255, 200, math.floor(landAlpha * 0.3)),
            nvgRGBA(100, 255, 200, 0))
        nvgBeginPath(nvg)
        nvgCircle(nvg, lx, ly, hexSize * landPulse * 0.8)
        nvgFillPaint(nvg, landGlow)
        nvgFill(nvg)
        -- 小箭头指示（在落点上方）
        nvgFontFace(nvg, UI.Theme.FontFace("sans", "normal"))
        nvgFontSize(nvg, 22)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
        local arrowBounce = math.sin(t * 6) * 4
        nvgFillColor(nvg, nvgRGBA(100, 255, 200, landAlpha))
        nvgText(nvg, lx, ly - hexSize * 0.7 + arrowBounce, "👇")

        nvgRestore(nvg)
    end

    -- === 二连跳教程：聚光灯高亮整条链式跳跃路径 ===
    if G.chainJumpSpotlightActive and G.chainJumpSpotlightJump1 and G.chainJumpSpotlightJump2
       and G.battle and G.battle.hero then
        -- layout already in ctx.l
        local j1 = G.chainJumpSpotlightJump1   -- 首跳
        local j2 = G.chainJumpSpotlightJump2   -- 二跳
        local heroCol = G.chainJumpSpotlightOriginCol or G.battle.hero.col
        local heroRow = G.chainJumpSpotlightOriginRow or G.battle.hero.row

        -- 计算所有关键点的像素坐标
        local hx, hy = HexGrid.HexToPixel(heroCol, heroRow, hexSize, ox, oy)           -- 英雄起点
        local e1x, e1y = HexGrid.HexToPixel(j1.jumpedCol, j1.jumpedRow, hexSize, ox, oy) -- 敌人1
        local l1x, l1y = HexGrid.HexToPixel(j1.col, j1.row, hexSize, ox, oy)            -- 落点1
        local e2x, e2y = HexGrid.HexToPixel(j2.jumpedCol, j2.jumpedRow, hexSize, ox, oy) -- 敌人2
        local l2x, l2y = HexGrid.HexToPixel(j2.col, j2.row, hexSize, ox, oy)            -- 落点2

        local t = G.time or 0
        local capR = hexSize * 1.15

        nvgSave(nvg)

        -- 1) 半透明遮罩 + 两段胶囊形挖洞
        nvgBeginPath(nvg)
        nvgRect(nvg, l.x, l.y, l.w, l.h)
        nvgPathWinding(nvg, NVG_SOLID)

        -- 辅助函数：画胶囊形 HOLE
        local function drawCapsuleHole(ax, ay, bx, by, r)
            local ddx = bx - ax
            local ddy = by - ay
            local pLen = math.sqrt(ddx * ddx + ddy * ddy)
            local cux, cuy, cnx, cny
            if pLen > 1 then
                cux, cuy = ddx / pLen, ddy / pLen
                cnx, cny = -cuy, cux
            else
                cux, cuy = 0, -1
                cnx, cny = 1, 0
            end
            local seg = 16
            nvgMoveTo(nvg, ax + cnx * r, ay + cny * r)
            nvgLineTo(nvg, bx + cnx * r, by + cny * r)
            for i = 0, seg do
                local a2 = math.pi * i / seg
                local px = bx + r * (cnx * math.cos(a2) + cux * math.sin(a2))
                local py = by + r * (cny * math.cos(a2) + cuy * math.sin(a2))
                nvgLineTo(nvg, px, py)
            end
            nvgLineTo(nvg, ax - cnx * r, ay - cny * r)
            for i = 0, seg do
                local a2 = math.pi + math.pi * i / seg
                local px = ax + r * (cnx * math.cos(a2) + cux * math.sin(a2))
                local py = ay + r * (cny * math.cos(a2) + cuy * math.sin(a2))
                nvgLineTo(nvg, px, py)
            end
            nvgClosePath(nvg)
            nvgPathWinding(nvg, NVG_HOLE)
        end

        -- 胶囊1：英雄 → 落点1
        drawCapsuleHole(hx, hy, l1x, l1y, capR)
        -- 胶囊2：落点1 → 落点2
        drawCapsuleHole(l1x, l1y, l2x, l2y, capR)

        nvgFillColor(nvg, nvgRGBA(0, 0, 0, 120))
        nvgFill(nvg)

        -- 2) 路径标注

        -- 英雄起点光环
        local heroGlow = 0.4 + math.sin(t * 2.5) * 0.15
        nvgBeginPath(nvg)
        nvgCircle(nvg, hx, hy, hexSize * 0.55)
        nvgStrokeColor(nvg, nvgRGBA(100, 255, 180, 200))
        nvgStrokeWidth(nvg, 2.5)
        nvgStroke(nvg)
        nvgBeginPath(nvg)
        nvgCircle(nvg, hx, hy, hexSize * heroGlow)
        nvgFillColor(nvg, nvgRGBA(100, 255, 180, 30))
        nvgFill(nvg)

        -- 敌人1圆环（橙色）
        nvgBeginPath(nvg)
        nvgCircle(nvg, e1x, e1y, hexSize * 0.55)
        nvgStrokeColor(nvg, nvgRGBA(255, 120, 60, 200))
        nvgStrokeWidth(nvg, 2.5)
        nvgStroke(nvg)

        -- 落点1脉冲（首跳目标 - 强调，因为玩家要点这里）
        local pulse1R = hexSize * 0.5 + math.sin(t * 3.0) * hexSize * 0.15
        nvgBeginPath(nvg)
        nvgCircle(nvg, l1x, l1y, pulse1R)
        nvgStrokeColor(nvg, nvgRGBA(255, 200, 80, 200))
        nvgStrokeWidth(nvg, 3.0)
        nvgStroke(nvg)

        -- 敌人2圆环（橙色，虚线感 - 用更淡的颜色表示"将来"）
        nvgBeginPath(nvg)
        nvgCircle(nvg, e2x, e2y, hexSize * 0.55)
        nvgStrokeColor(nvg, nvgRGBA(255, 140, 60, 140))
        nvgStrokeWidth(nvg, 2.0)
        nvgStroke(nvg)

        -- 落点2脉冲（最终目标 - 较淡，表示连跳终点）
        local pulse2R = hexSize * 0.45 + math.sin(t * 2.5) * hexSize * 0.1
        nvgBeginPath(nvg)
        nvgCircle(nvg, l2x, l2y, pulse2R)
        nvgStrokeColor(nvg, nvgRGBA(60, 200, 255, 150))
        nvgStrokeWidth(nvg, 2.0)
        nvgStroke(nvg)

        -- 3) 两段路径的方向箭头
        -- 箭头1：英雄 → 落点1
        do
            local dx1 = l1x - hx
            local dy1 = l1y - hy
            local len1 = math.sqrt(dx1 * dx1 + dy1 * dy1)
            if len1 > 1 then
                local ux1, uy1 = dx1 / len1, dy1 / len1
                local nx1, ny1 = -uy1, ux1
                local arrX = l1x - ux1 * hexSize * 0.6
                local arrY = l1y - uy1 * hexSize * 0.6
                local arrS = hexSize * 0.3
                nvgBeginPath(nvg)
                nvgMoveTo(nvg, arrX + ux1 * arrS, arrY + uy1 * arrS)
                nvgLineTo(nvg, arrX - ux1 * arrS * 0.5 + nx1 * arrS * 0.5, arrY - uy1 * arrS * 0.5 + ny1 * arrS * 0.5)
                nvgLineTo(nvg, arrX - ux1 * arrS * 0.5 - nx1 * arrS * 0.5, arrY - uy1 * arrS * 0.5 - ny1 * arrS * 0.5)
                nvgClosePath(nvg)
                nvgFillColor(nvg, nvgRGBA(255, 200, 80, 180))
                nvgFill(nvg)
            end
        end

        -- 箭头2：落点1 → 落点2（稍淡，表示"接下来"）
        do
            local dx2 = l2x - l1x
            local dy2 = l2y - l1y
            local len2 = math.sqrt(dx2 * dx2 + dy2 * dy2)
            if len2 > 1 then
                local ux2, uy2 = dx2 / len2, dy2 / len2
                local nx2, ny2 = -uy2, ux2
                local arrX = l2x - ux2 * hexSize * 0.6
                local arrY = l2y - uy2 * hexSize * 0.6
                local arrS = hexSize * 0.25
                nvgBeginPath(nvg)
                nvgMoveTo(nvg, arrX + ux2 * arrS, arrY + uy2 * arrS)
                nvgLineTo(nvg, arrX - ux2 * arrS * 0.5 + nx2 * arrS * 0.5, arrY - uy2 * arrS * 0.5 + ny2 * arrS * 0.5)
                nvgLineTo(nvg, arrX - ux2 * arrS * 0.5 - nx2 * arrS * 0.5, arrY - uy2 * arrS * 0.5 - ny2 * arrS * 0.5)
                nvgClosePath(nvg)
                nvgFillColor(nvg, nvgRGBA(60, 200, 255, 140))
                nvgFill(nvg)
            end
        end

        -- 4) 提示气泡
        local allPts = {{hx,hy},{e1x,e1y},{l1x,l1y},{e2x,e2y},{l2x,l2y}}
        local pMinX, pMaxX = hx, hx
        local pMinY, pMaxY = hy, hy
        for _, pt in ipairs(allPts) do
            if pt[1] < pMinX then pMinX = pt[1] end
            if pt[1] > pMaxX then pMaxX = pt[1] end
            if pt[2] < pMinY then pMinY = pt[2] end
            if pt[2] > pMaxY then pMaxY = pt[2] end
        end
        pMinX = pMinX - capR
        pMaxX = pMaxX + capR
        pMinY = pMinY - capR
        pMaxY = pMaxY + capR

        local pathCX = (pMinX + pMaxX) / 2
        local pathCY = (pMinY + pMaxY) / 2
        local tipW = l.w * 0.78
        local tipH = 180
        local tipPad = 14

        local tipX = math.max(l.x + 8, math.min(pathCX - tipW / 2, l.x + l.w - tipW - 8))
        local tipY = pMaxY + 20
        if tipY + tipH > l.y + l.h - 10 then
            tipY = pMinY - tipH - 20
        end
        if tipY < l.y + 10 then
            if pathCX < l.x + l.w / 2 then
                tipX = math.min(pMaxX + 16, l.x + l.w - tipW - 8)
            else
                tipX = math.max(pMinX - tipW - 16, l.x + 8)
            end
            tipY = math.max(l.y + 10, math.min(pathCY - tipH / 2, l.y + l.h - tipH - 10))
        end
        tipX = math.max(l.x + 4, math.min(tipX, l.x + l.w - tipW - 4))
        tipY = math.max(l.y + 4, math.min(tipY, l.y + l.h - tipH - 4))

        -- 气泡背景
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, tipX, tipY, tipW, tipH, 14)
        nvgFillColor(nvg, nvgRGBA(12, 20, 30, 235))
        nvgFill(nvg)
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, tipX, tipY, tipW, tipH, 14)
        nvgStrokeColor(nvg, nvgRGBA(255, 160, 60, 100))
        nvgStrokeWidth(nvg, 1.5)
        nvgStroke(nvg)

        -- 标题
        local tipCX = tipX + tipW / 2
        nvgFontFace(nvg, UI.Theme.FontFace("sans", "bold"))
        nvgFontSize(nvg, 26)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(nvg, nvgRGBA(255, 180, 60, 255))
        nvgText(nvg, tipCX, tipY + tipPad, "⚡ 连续跳跃！")

        -- 描述
        nvgFontFace(nvg, UI.Theme.FontFace("sans", "normal"))
        nvgFontSize(nvg, 20)
        nvgFillColor(nvg, nvgRGBA(220, 225, 235, 230))
        local descY = tipY + tipPad + 36
        nvgText(nvg, tipCX, descY, "跳过敌人后，落点附近还有敌人？")
        nvgText(nvg, tipCX, descY + 28, "继续跳！连跳越多，COMBO越高！")

        -- 引导提示
        nvgFontFace(nvg, UI.Theme.FontFace("sans", "bold"))
        nvgFontSize(nvg, 17)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        local hintAlpha = math.floor(160 + math.sin(t * 4) * 80)
        nvgFillColor(nvg, nvgRGBA(255, 220, 100, hintAlpha))
        nvgText(nvg, tipCX, tipY + tipH - tipPad - 14, "👆 点击第一个落点，开始连跳！")

        -- 5) 首跳落点呼吸引导（玩家需要点这里）
        local landPulse = 0.6 + math.sin(t * 5) * 0.25
        local landAlpha = math.floor(180 + math.sin(t * 5) * 60)
        nvgBeginPath(nvg)
        nvgCircle(nvg, l1x, l1y, hexSize * landPulse)
        nvgStrokeColor(nvg, nvgRGBA(255, 220, 100, landAlpha))
        nvgStrokeWidth(nvg, 3.0)
        nvgStroke(nvg)
        local landGlow = nvgRadialGradient(nvg,
            l1x, l1y, hexSize * 0.1, hexSize * landPulse * 0.8,
            nvgRGBA(255, 220, 100, math.floor(landAlpha * 0.3)),
            nvgRGBA(255, 220, 100, 0))
        nvgBeginPath(nvg)
        nvgCircle(nvg, l1x, l1y, hexSize * landPulse * 0.8)
        nvgFillPaint(nvg, landGlow)
        nvgFill(nvg)
        -- 指向箭头
        nvgFontFace(nvg, UI.Theme.FontFace("sans", "normal"))
        nvgFontSize(nvg, 22)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
        local arrowBounce = math.sin(t * 6) * 4
        nvgFillColor(nvg, nvgRGBA(255, 220, 100, landAlpha))
        nvgText(nvg, l1x, l1y - hexSize * 0.7 + arrowBounce, "👇")

        nvgRestore(nvg)
    end

    -- === 连击聚光灯教学：首次打出某连击等级时展示 ===
    if G.comboSpotlightActive and G.battle and G.battle.hero then
        -- layout already in ctx.l
        local hero = G.battle.hero
        local info = G.comboSpotlightActive
        local hx, hy
        -- 3连击（稻草人）时聚光灯聚焦稻草人位置而非主角
        -- 优先用 spotlightInfo 中预算的位置（spotlight在稻草人实际生成前显示）
        if info.tier == 3 then
            local scPos = info.scarecrowPos
                       or (G.battle.scarecrowActive and G.battle.scarecrow)
            if scPos then
                hx, hy = HexGrid.HexToPixel(scPos.col, scPos.row, hexSize, ox, oy)
            else
                hx, hy = HexGrid.HexToPixel(hero.col, hero.row, hexSize, ox, oy)
            end
        else
            hx, hy = HexGrid.HexToPixel(hero.col, hero.row, hexSize, ox, oy)
        end
        local spotR = hexSize * 1.8
        local tier = info.tier or 2

        -- 连击等级对应主题色
        local themeColors = {
            [2] = {255, 220, 100},
            [3] = {255, 180, 60},
            [4] = {200, 140, 255},
            [5] = {255, 100, 60},
            [6] = {80, 200, 255},
            [7] = {255, 80, 220},
        }
        local tc = themeColors[tier] or themeColors[2]

        -- === tier2 飞镖：计算目标位置（胶囊高亮用） ===
        local tx, ty  -- 飞镖目标像素坐标
        local hasCapsule = false
        if tier == 2 and info.dartTarget then
            tx, ty = HexGrid.HexToPixel(info.dartTarget.col, info.dartTarget.row, hexSize, ox, oy)
            local ddx = tx - hx
            local ddy = ty - hy
            local dist = math.sqrt(ddx * ddx + ddy * ddy)
            if dist > 1 then hasCapsule = true end
        end

        -- 1) 半透明遮罩
        nvgSave(nvg)
        nvgBeginPath(nvg)
        nvgRect(nvg, l.x, l.y, l.w, l.h)
        nvgPathWinding(nvg, NVG_SOLID)
        if hasCapsule then
            -- 胶囊形高亮：覆盖英雄到飞镖目标的整条线
            local capR = hexSize * 1.3
            local ddx = tx - hx
            local ddy = ty - hy
            local la = math.atan(ddy, ddx)
            local startAngle = la + math.pi / 2
            -- 手动构建胶囊路径（两个半圆 + 两条直线）
            local sx = hx + capR * math.cos(startAngle)
            local sy = hy + capR * math.sin(startAngle)
            nvgMoveTo(nvg, sx, sy)
            nvgArc(nvg, hx, hy, capR, la + math.pi / 2, la - math.pi / 2, NVG_CW)
            nvgArc(nvg, tx, ty, capR, la - math.pi / 2, la + math.pi / 2, NVG_CW)
            nvgClosePath(nvg)
        else
            nvgCircle(nvg, hx, hy, spotR)
        end
        nvgPathWinding(nvg, NVG_HOLE)
        nvgFillColor(nvg, nvgRGBA(0, 0, 0, 120))
        nvgFill(nvg)

        -- 2) 聚光灯边缘柔光
        if hasCapsule then
            -- 胶囊形柔光边缘
            local glowR = hexSize * 1.5
            local ddx = tx - hx
            local ddy = ty - hy
            local la = math.atan(ddy, ddx)
            local gsx = hx + glowR * math.cos(la + math.pi / 2)
            local gsy = hy + glowR * math.sin(la + math.pi / 2)
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, gsx, gsy)
            nvgArc(nvg, hx, hy, glowR, la + math.pi / 2, la - math.pi / 2, NVG_CW)
            nvgArc(nvg, tx, ty, glowR, la - math.pi / 2, la + math.pi / 2, NVG_CW)
            nvgClosePath(nvg)
            nvgFillColor(nvg, nvgRGBA(tc[1], tc[2], tc[3], 30))
            nvgFill(nvg)

            -- 飞镖飞行路径箭头指示线
            local ddx2 = tx - hx
            local ddy2 = ty - hy
            local la2 = math.atan(ddy2, ddx2)
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, hx, hy)
            nvgLineTo(nvg, tx, ty)
            nvgStrokeColor(nvg, nvgRGBA(tc[1], tc[2], tc[3], 140))
            nvgStrokeWidth(nvg, 2.5)
            nvgStroke(nvg)
            -- 箭头头部
            local arrLen = hexSize * 0.5
            local arrAng = math.pi * 0.82
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, tx, ty)
            nvgLineTo(nvg, tx + arrLen * math.cos(la2 + arrAng), ty + arrLen * math.sin(la2 + arrAng))
            nvgMoveTo(nvg, tx, ty)
            nvgLineTo(nvg, tx + arrLen * math.cos(la2 - arrAng), ty + arrLen * math.sin(la2 - arrAng))
            nvgStrokeColor(nvg, nvgRGBA(tc[1], tc[2], tc[3], 180))
            nvgStrokeWidth(nvg, 3)
            nvgStroke(nvg)

            -- 起点标记（英雄位置小圆）
            nvgBeginPath(nvg)
            nvgCircle(nvg, hx, hy, 6)
            nvgFillColor(nvg, nvgRGBA(tc[1], tc[2], tc[3], 200))
            nvgFill(nvg)
            -- 终点标记（目标位置小圆）
            nvgBeginPath(nvg)
            nvgCircle(nvg, tx, ty, 6)
            nvgFillColor(nvg, nvgRGBA(255, 80, 80, 220))
            nvgFill(nvg)
        else
            local ringPaint = nvgRadialGradient(nvg, hx, hy, spotR * 0.85, spotR * 1.2,
                nvgRGBA(tc[1], tc[2], tc[3], 0),
                nvgRGBA(tc[1], tc[2], tc[3], 50))
            nvgBeginPath(nvg)
            nvgCircle(nvg, hx, hy, spotR * 1.2)
            nvgFillPaint(nvg, ringPaint)
            nvgFill(nvg)
        end

        -- 3) 提示气泡
        -- 锚点：胶囊用中点，圆形用焦点
        local anchorX = hasCapsule and (hx + tx) / 2 or hx
        local anchorY = hasCapsule and (hy + ty) / 2 or hy
        local spotTopY = hasCapsule and (math.min(hy, ty) - hexSize * 1.3) or (hy - spotR)
        local spotBotY = hasCapsule and (math.max(hy, ty) + hexSize * 1.3) or (hy + spotR)

        local tipW = l.w * 0.78
        local tipH = (tier == 3) and 240 or 175  -- tier3 需要更多空间解释嘲讽
        local tipPad = 18
        local tipX = math.max(l.x + 8, math.min(anchorX - tipW / 2, l.x + l.w - tipW - 8))
        -- 优先放下方，避免被顶部 HUD（击杀目标等）遮挡
        local tipY = spotBotY + 20
        if tipY + tipH > l.y + l.h - 10 then
            -- 下方放不下才放上方
            tipY = spotTopY - tipH - 20
        end
        -- 最终安全 clamp：无论如何气泡必须完整在屏幕内
        tipX = math.max(l.x + 4, math.min(tipX, l.x + l.w - tipW - 4))
        tipY = math.max(l.y + 4, math.min(tipY, l.y + l.h - tipH - 4))

        -- 气泡背景
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, tipX, tipY, tipW, tipH, 14)
        nvgFillColor(nvg, nvgRGBA(20, 18, 12, 235))
        nvgFill(nvg)
        -- 气泡主题色边框
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, tipX, tipY, tipW, tipH, 14)
        nvgStrokeColor(nvg, nvgRGBA(tc[1], tc[2], tc[3], 100))
        nvgStrokeWidth(nvg, 1.5)
        nvgStroke(nvg)

        -- 气泡箭头（三角形指向锚点）
        local arrowX = math.max(tipX + 20, math.min(anchorX, tipX + tipW - 20))
        nvgBeginPath(nvg)
        if tipY < anchorY then
            nvgMoveTo(nvg, arrowX - 8, tipY + tipH)
            nvgLineTo(nvg, arrowX, tipY + tipH + 10)
            nvgLineTo(nvg, arrowX + 8, tipY + tipH)
        else
            nvgMoveTo(nvg, arrowX - 8, tipY)
            nvgLineTo(nvg, arrowX, tipY - 10)
            nvgLineTo(nvg, arrowX + 8, tipY)
        end
        nvgClosePath(nvg)
        nvgFillColor(nvg, nvgRGBA(20, 18, 12, 235))
        nvgFill(nvg)

        -- 文字内容
        local tipCX = tipX + tipW / 2
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

        -- 标题：「N连击 · 技能名」
        nvgFontFace(nvg, UI.Theme.FontFace("sans", "bold"))
        nvgFontSize(nvg, 28)
        nvgFillColor(nvg, nvgRGBA(tc[1], tc[2], tc[3], 255))
        nvgText(nvg, tipCX, tipY + tipPad, string.format("⚡ %d连击 · %s", tier, info.name or ""))

        -- 描述
        nvgFontFace(nvg, UI.Theme.FontFace("sans", "normal"))
        nvgFontSize(nvg, 21)
        nvgFillColor(nvg, nvgRGBA(220, 225, 235, 230))
        if tier == 3 then
            -- tier3 稻草人：详细解释嘲讽机制（替代原独立教程弹窗）
            local descY = tipY + tipPad + 42
            nvgText(nvg, tipCX, descY,      "召唤稻草人，吸引全部仇恨！")
            nvgText(nvg, tipCX, descY + 30, "红线 = 仇恨锁定，敌人只打它不打你")
            nvgFontSize(nvg, 17)
            nvgFillColor(nvg, nvgRGBA(tc[1], tc[2], tc[3], 180))
            nvgText(nvg, tipCX, descY + 66, "持续2回合，趁机安全移动和输出！")
        else
            local descMaxW = tipW - tipPad * 2
            nvgTextBox(nvg, tipX + tipPad, tipY + tipPad + 42, descMaxW, info.desc or "")
        end

        -- "知道了"按钮
        local btnW = 140
        local btnH = 40
        local btnX = tipX + (tipW - btnW) / 2
        local btnY = tipY + tipH - tipPad - btnH
        local btnPaint = nvgLinearGradient(nvg, btnX, btnY, btnX, btnY + btnH,
            nvgRGBA(tc[1], tc[2], tc[3], 255), nvgRGBA(math.floor(tc[1]*0.85), math.floor(tc[2]*0.85), math.floor(tc[3]*0.85), 255))
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, btnX, btnY, btnW, btnH, 20)
        nvgFillPaint(nvg, btnPaint)
        nvgFill(nvg)
        nvgFontFace(nvg, UI.Theme.FontFace("sans", "bold"))
        nvgFontSize(nvg, 20)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(10, 10, 20, 255))
        nvgText(nvg, btnX + btnW / 2, btnY + btnH / 2, "知道了！")

        nvgRestore(nvg)
    end

end

return BoardWidget_Overlays
