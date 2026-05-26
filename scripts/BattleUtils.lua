-- ============================================================================
-- BattleUtils - 纯工具函数（从 Battle.lua 拆分）
-- 不调用 Battle 模块，只依赖 HexGrid 和基础数学
-- ============================================================================

local HexGrid = require "HexGrid"

local BattleUtils = {}

function BattleUtils.FindClosestMove(validMoves, targetCol, targetRow)
    local bestMove = nil
    local bestDist = math.huge
    for _, m in ipairs(validMoves) do
        local dist = HexGrid.CubeDistance(m.col, m.row, targetCol, targetRow)
        if dist < bestDist then
            bestDist = dist
            bestMove = m
        end
    end
    return bestMove
end

function BattleUtils.FindFarthestMove(validMoves, targetCol, targetRow)
    local bestMove = nil
    local bestDist = -1
    for _, m in ipairs(validMoves) do
        local dist = HexGrid.CubeDistance(m.col, m.row, targetCol, targetRow)
        if dist > bestDist then
            bestDist = dist
            bestMove = m
        end
    end
    return bestMove
end

function BattleUtils.FindOptimalRangeMove(validMoves, targetCol, targetRow, idealRange)
    local bestMove = nil
    local bestDiff = math.huge
    for _, m in ipairs(validMoves) do
        local dist = HexGrid.CubeDistance(m.col, m.row, targetCol, targetRow)
        local diff = math.abs(dist - idealRange)
        if diff < bestDiff then
            bestDiff = diff
            bestMove = m
        end
    end
    return bestMove
end

function BattleUtils.ClearPriestBuffs(state)
    local enemies = HexGrid.GetTeamPieces(state.board, "enemy")
    for _, e in ipairs(enemies) do
        if e._priestBuff and e._priestBuff > 0 then
            e.atk = e.atk - e._priestBuff
            e._priestBuff = 0
        end
    end
end

function BattleUtils.GetThreats(state, col, row)
    local threats = {}
    local immediateSet = {}  -- 记录已经是即时威胁的敌人，避免重复
    local enemies = HexGrid.GetTeamPieces(state.board, "enemy")

    -- 第一遍：检测即时威胁（敌人当前位置就能攻击）
    for _, e in ipairs(enemies) do
        if e.hp > 0 and e.atk > 0 then
            local range = e.attackRange or 1
            local dist = HexGrid.CubeDistance(e.col, e.row, col, row)
            if dist <= range then
                threats[#threats + 1] = {
                    enemy = e,
                    dist = dist,
                    label = e.attackLabel or "攻击",
                    damage = e.atk,
                    pending = false,
                }
                immediateSet[e] = true
            end
        end
    end

    -- 第二遍：检测潜在威胁（敌人移动1步后能攻击）
    for _, e in ipairs(enemies) do
        if e.hp > 0 and e.atk > 0 and not immediateSet[e] then
            -- 幽灵鲨瞬移威胁：冷却就绪时可瞬移到目标相邻格攻击（视为即时威胁）
            if e.enemyType == "ghost_shark" and (e._teleportCD or 0) <= 0 then
                local dist = HexGrid.CubeDistance(e.col, e.row, col, row)
                -- 瞬移范围：目标周围有空位即可到达
                local heroNeighbors = HexGrid.GetNeighbors(col, row)
                local canTeleport = false
                for _, hn in ipairs(heroNeighbors) do
                    if not HexGrid.IsBlocked(state.board, hn.col, hn.row) then
                        canTeleport = true
                        break
                    end
                end
                if canTeleport then
                    threats[#threats + 1] = {
                        enemy = e,
                        dist = 1,
                        label = "⚡瞬移" .. (e.attackLabel or "攻击"),
                        damage = e.atk,
                        pending = false,  -- 瞬移视为即时威胁
                    }
                    immediateSet[e] = true
                end
            end

            -- 普通移动1步后攻击的潜在威胁
            if not immediateSet[e] then
                local range = e.attackRange or 1
                local neighbors = HexGrid.GetNeighbors(e.col, e.row)
                for _, n in ipairs(neighbors) do
                    local blocked = HexGrid.IsBlocked(state.board, n.col, n.row)
                    if not blocked or (n.col == col and n.row == row) then
                        local distAfterMove = HexGrid.CubeDistance(n.col, n.row, col, row)
                        if distAfterMove <= range then
                            threats[#threats + 1] = {
                                enemy = e,
                                dist = distAfterMove,
                                label = "即将" .. (e.attackLabel or "攻击"),
                                damage = e.atk,
                                pending = true,
                            }
                            break
                        end
                    end
                end
            end
        end
    end

    return threats
end

function BattleUtils.AddVFX(state, vfxType, data)
    data.type = vfxType
    data.timer = data.duration or 0.6
    data.maxTimer = data.timer
    state.vfx[#state.vfx + 1] = data
end

function BattleUtils.AddFloatingText(state, col, row, text, color, style, duration, startDelay)
    local dur = duration or 1.5
    local sty = style or "normal"
    -- 同一格子及相邻格子的已有文字向上错开，避免重叠
    -- 有延迟的浮字（如分裂弹碎片）不参与错开计算，避免提前占位
    local baseOffset = 0
    if not startDelay or startDelay <= 0 then
        local spacing = (sty == "combo" or sty == "combo_reward") and 26 or 20
        for _, ft in ipairs(state.floatingTexts) do
            local dist = HexGrid.CubeDistance(ft.col, ft.row, col, row)
            if dist <= 1 then
                local age = ft.maxTimer - ft.timer
                if age < 0.5 then
                    baseOffset = baseOffset - spacing
                end
            end
        end
    end
    state.floatingTexts[#state.floatingTexts + 1] = {
        col = col, row = row,
        text = text,
        color = color or {255, 255, 255, 255},
        timer = dur,
        maxTimer = dur,
        offsetY = baseOffset,
        style = sty,
        scale = 1.0,
        comboLevel = 0,  -- 用于连跳递进视觉（0=普通，>=3开始增强）
        startDelay = startDelay or 0,  -- >0 时倒计时期间不渲染、不移动
    }
end

function BattleUtils.AddLog(state, msg)
    state.log[#state.log + 1] = msg
end


return BattleUtils
