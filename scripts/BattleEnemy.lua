-- ============================================================================
-- BattleEnemy.lua - Enemy turn behavior module (split from Battle.lua)
-- Contains: ProcessEnemyTurn, EnemyAct, special enemy xxxAct, CheckEndCondition
-- Usage: require("BattleEnemy")(Battle)
-- ============================================================================

local HexGrid = require "HexGrid"
local Skills = require "Skills"
local AM = require "AudioManager"
local G = require "GameState"

return function(Battle)

function Battle.ProcessEnemyTurn(state)
    -- === 第二章: 时间冻结 — 跳过整个敌人回合（支持多回合） ===
    if state.timeFreezeActive then
        local remaining = (state.timeFreezeCount or 1) - 1
        if remaining > 0 then
            state.timeFreezeCount = remaining
            Battle.AddLog(state, string.format("⏳ 时间冻结生效！敌人无法行动！（剩余%d回合）", remaining))
            Battle.AddFloatingText(state, state.hero.col, state.hero.row,
                "⏳冻结!" .. remaining .. "回合", {100, 200, 255, 255}, "combo")
        else
            state.timeFreezeActive = false
            state.timeFreezeCount = nil
            Battle.AddLog(state, "⏳ 时间冻结生效！敌人无法行动！（最后一回合）")
            Battle.AddFloatingText(state, state.hero.col, state.hero.row,
                "⏳冻结解除!", {100, 200, 255, 255}, "combo")
        end
        -- 仍然需要递进回合数和清理
        state.turn = state.turn + 1
        if state.isEndless then
            state.endlessTotalTurns = (state.endlessTotalTurns or 0) + 1
        end
        Battle.SettlePendingComboShield(state)  -- 连击链结束，结算延迟护盾
        state.combo = 0
        state.comboKillCount = 0
        state.comboAtkBonus = 0
        Battle.ResetComboRewards(state)
        -- 毒雾/结界/封印回合递减仍然进行
        Battle.TickTerrain(state)
        Battle.TickSealDebuff(state)
        return {}
    end

    -- 0. 英雄灼烧DOT（第三章火精灵）
    Battle.ProcessHeroBurn(state)

    -- 0.05 英雄毒DOT（第四章毒尾蜥）
    Battle.ProcessHeroPoison(state)

    -- 0.1 Boss光环伤害（英雄靠近Boss时自动受伤）
    Battle.ProcessBossAura(state)

    -- 0.45 清除珊瑚祭司BUFF（每回合重新施加）
    Battle.ClearPriestBuffs(state)

    -- 0.5 寄居蟹缩壳状态切换
    Battle.UpdateHermitCrabShell(state)

    -- 0.55 礁石海星回血
    for _, e in ipairs(HexGrid.GetTeamPieces(state.board, "enemy")) do
        if e.hp > 0 and e.regenHp and e.regenHp > 0 then
            local heal = math.min(e.regenHp, e.maxHp - e.hp)
            if heal > 0 then
                e.hp = e.hp + heal
                Battle.AddFloatingText(state, e.col, e.row,
                    "+" .. heal, {100, 255, 150, 255})
            end
        end
    end

    -- 0.6 (已移至敌人攻击后清理)

    -- 0.7 魅惑水母：英雄进入2格范围则触发魅惑（下一玩家回合跳过）
    -- 免疫期内不触发（被魅惑结束后有2回合免疫，防止无限循环控制）
    if (state.heroCharmImmunity and state.heroCharmImmunity > 0) then
        -- 免疫期中，不检查魅惑
    elseif not (state.heroCharmedTurns and state.heroCharmedTurns > 0) then
        -- 本回合还未被魅惑，才检查（避免重复触发）
        for _, e in ipairs(HexGrid.GetTeamPieces(state.board, "enemy")) do
            if e.hp > 0 and e.enemyType == "charm_jelly" then
                local dist = HexGrid.CubeDistance(e.col, e.row, state.hero.col, state.hero.row)
                if dist <= (e.charmRange or 2) then
                    state.heroCharmedTurns = 1
                    Battle.AddFloatingText(state, state.hero.col, state.hero.row,
                        "💜魅惑！", {220, 100, 255, 255}, "combo")
                    Battle.AddFloatingText(state, e.col, e.row,
                        "💜魅惑生效", {220, 100, 255, 255})
                    Battle.AddLog(state, string.format("💜 %s 魅惑了英雄！下回合无法行动！", e.name))
                    break  -- 一次只触发一个
                end
            end
        end
    end

    -- 1. 处理毒雾伤害
    Battle.ProcessPoison(state)

    -- 2. 处理地刺陷阱伤害
    Battle.ProcessSpikeTraps(state)

    -- 3. 连锁闪电Lv3: 毒雾格每回合电击一个相邻敌人
    if Skills.Level(state.skills, "chain_lightning") >= 3 then
        Battle.ProcessPhantomStorm(state)
    end

    local actions = {}
    local enemies = HexGrid.GetTeamPieces(state.board, "enemy")

    -- 记录本回合开始前稻草人的累积伤害，用于回合结束后计算本回合增量
    local scarecrowAbsorbedBefore = 0
    local scarecrowHitsBefore = 0
    if state.scarecrowActive and state.scarecrow then
        scarecrowAbsorbedBefore = state.scarecrow.totalDamageAbsorbed or 0
        scarecrowHitsBefore = state.scarecrow.hitCount or 0
    end

    for _, enemy in ipairs(enemies) do
        if enemy.hp > 0 then
            local ok, action = pcall(Battle.EnemyAct, state, enemy)
            if not ok then
                -- AI 异常：记录错误，敌人本回合跳过，不阻断 state.turn 递增
                Battle.AddLog(state, string.format("[错误] %s AI 异常: %s", tostring(enemy.enemyType), tostring(action)))
                action = { type = "idle", enemy = enemy } ---@diagnostic disable-line: assign-type-mismatch
            end
            if action then
                actions[#actions + 1] = action
            end
        end
    end

    -- === 敌人移动后刷新祭坛护盾状态 ===
    -- 敌人行动可能改变位置，需要重新计算谁在祭坛保护范围内
    Battle.UpdateAltarShields(state)

    -- === 稻草人本回合伤害汇总通知 ===
    if state.scarecrow_destroyed then
        -- 稻草人被击毁：显示总汇总
        local sc = state.scarecrow_destroyed
        local totalAbsorbed = sc.totalDamageAbsorbed or 0
        local hits = sc.hitCount or 0
        Battle.AddVFX(state, "scarecrow_fade", {
            col = sc.col, row = sc.row,
            duration = 1.2,
            totalAbsorbed = totalAbsorbed,
            hitCount = hits,
            reason = "destroy",
        })
        Battle.AddFloatingText(state, sc.col, sc.row,
            string.format("🎃稻草人倒下！共挡住%d次%d伤害", hits, totalAbsorbed),
            {255, 100, 50, 255}, "combo", 3.0)
        Battle.AddLog(state, string.format("稻草人被击毁！共替你承受了 %d 次攻击，挡住 %d 伤害！", hits, totalAbsorbed))
        state.scarecrow = nil
        state.scarecrow_destroyed = nil
    elseif state.scarecrowActive and state.scarecrow then
        -- 稻草人存活：如果本回合有承伤，显示本回合汇总
        -- 但如果稻草人本回合即将消散（turnsLeft <= 1），跳过本回合汇总，由消散汇总统一显示总伤害
        local sc = state.scarecrow
        if sc.turnsLeft > 1 then
            local totalNow = sc.totalDamageAbsorbed or 0
            local hitsNow = sc.hitCount or 0
            local turnDmg = totalNow - scarecrowAbsorbedBefore
            local turnHits = hitsNow - scarecrowHitsBefore
            if turnDmg > 0 and turnHits > 0 then
                Battle.AddFloatingText(state, sc.col, sc.row,
                    string.format("🎃挡住%d次共%d伤害", turnHits, turnDmg),
                    {255, 220, 80, 255}, "combo", 2.5)
            end
        end
    end

    -- 清理死亡棋子
    HexGrid.RemoveDead(state.board)

    -- 第三章: 敌人移动/死亡后路径可能畅通，重新检查寄居蟹救援
    if state.board.crabs then
        Battle.CheckCrabRescue(state)
    end

    -- 稻草人：敌人回合结束后递减回合数
    if state.scarecrowActive and state.scarecrow then
        state.scarecrow.turnsLeft = state.scarecrow.turnsLeft - 1
        if state.scarecrow.turnsLeft <= 0 then
            -- 到期消散，显示承伤汇总
            local totalAbsorbed = state.scarecrow.totalDamageAbsorbed or 0
            local hits = state.scarecrow.hitCount or 0
            -- 淡出特效
            Battle.AddVFX(state, "scarecrow_fade", {
                col = state.scarecrow.col, row = state.scarecrow.row,
                duration = 1.2,
                totalAbsorbed = totalAbsorbed,
                hitCount = hits,
                reason = "expire",
            })
            if totalAbsorbed > 0 then
                Battle.AddFloatingText(state, state.scarecrow.col, state.scarecrow.row,
                    string.format("🎃消散！共挡住%d次%d伤害", hits, totalAbsorbed),
                    {255, 200, 80, 255}, "combo")
                Battle.AddLog(state, string.format("稻草人消散！共替你承受了 %d 次攻击，挡住 %d 伤害！", hits, totalAbsorbed))
            else
                Battle.AddFloatingText(state, state.scarecrow.col, state.scarecrow.row,
                    "🎃消散", {200, 150, 100, 255})
                Battle.AddLog(state, "稻草人消散了")
            end
            state.scarecrowActive = false
            state.scarecrow = nil
        else
            -- 还有剩余回合，显示剩余提示
            Battle.AddFloatingText(state, state.scarecrow.col, state.scarecrow.row,
                string.format("🎃还能挡%d回合", state.scarecrow.turnsLeft),
                {120, 255, 120, 255})
            Battle.AddLog(state, string.format("稻草人还能坚持 %d 个敌人回合", state.scarecrow.turnsLeft))
        end
    end

    -- 连击护盾: 回合结束反弹（护盾跨回合保留，不清零）
    Battle.ProcessShieldReflect(state)

    state.turn = state.turn + 1
    if state.isEndless then
        state.endlessTotalTurns = (state.endlessTotalTurns or 0) + 1
    end
    Battle.SettlePendingComboShield(state)  -- 连击链结束，结算延迟护盾
    state.combo = 0
    state.comboKillCount = 0
    state.comboAtkBonus = 0
    Battle.ResetComboRewards(state)

    Battle.TickTerrain(state)
    Battle.TickSealDebuff(state)

    -- 回合中刷新外围敌人
    Battle.TrySpawnEnemies(state)

    -- 主角移动空间保护：确保主角至少有2个相邻空格可移动
    Battle.EnsureHeroMobility(state)

    -- 低血量补给：HP<30% 且场上无血瓶时，刷一个血瓶
    Battle.CheckLowHpPotionSpawn(state)

    return actions
end

--- 低血量血瓶补给（HP<30% 且场上无血瓶时刷一个）
function Battle.CheckLowHpPotionSpawn(state)
    local hero = state.hero
    if hero.hp <= 0 then return end
    if hero.hp >= hero.maxHp * 0.3 then return end

    -- 场上已有任意血瓶则不刷
    for _, item in ipairs(state.board.items) do
        if item.type == "health_potion" or item.type == "health_potion_big" then return end
    end

    -- 找随机空位（排除英雄所在格）
    local empty = HexGrid.GetEmptyPositions(state.board)
    local candidates = {}
    for _, pos in ipairs(empty) do
        if not (pos.col == hero.col and pos.row == hero.row) then
            candidates[#candidates + 1] = pos
        end
    end
    if #candidates == 0 then return end

    local pos = candidates[math.random(1, #candidates)]
    HexGrid.AddItem(state.board, { col = pos.col, row = pos.row, type = "health_potion" })
    Battle.AddLog(state, "💊 危急时刻！一瓶小血药出现在了战场上！")
end

--- 地形效果回合递减（毒雾/结界）
function Battle.TickTerrain(state)
    for i = #state.board.poisonTiles, 1, -1 do
        state.board.poisonTiles[i].turns = state.board.poisonTiles[i].turns - 1
        if state.board.poisonTiles[i].turns <= 0 then
            table.remove(state.board.poisonTiles, i)
        end
    end
    for i = #state.board.wards, 1, -1 do
        state.board.wards[i].turns = state.board.wards[i].turns - 1
        if state.board.wards[i].turns <= 0 then
            table.remove(state.board.wards, i)
        end
    end
    -- 临时障碍物衰减（触手等）
    for i = #state.board.obstacles, 1, -1 do
        local obs = state.board.obstacles[i]
        if obs.turns then
            obs.turns = obs.turns - 1
            if obs.turns <= 0 then
                table.remove(state.board.obstacles, i)
            end
        end
    end
end

--- 处理毒雾伤害（敌人回合开始时）
function Battle.ProcessPoison(state)
    local board = state.board
    for _, poison in ipairs(board.poisonTiles) do
        local enemy = HexGrid.GetPieceAt(board, poison.col, poison.row)
        if enemy and enemy.team == "enemy" and enemy.hp > 0 then
            local poisonDmg = 10
            poisonDmg = Battle.ApplyAltarReduction(state, enemy, poisonDmg)
            enemy.hp = enemy.hp - poisonDmg
            state.totalDamage = state.totalDamage + poisonDmg
            Battle.AddFloatingText(state, poison.col, poison.row,
                "-" .. poisonDmg .. "☁️", {100, 200, 100, 255})
            Battle.AddLog(state, string.format("%s 踩到毒雾！受到 %d 伤害",
                enemy.name, poisonDmg))
            if enemy.hp <= 0 then
                Battle.HandleEnemyDeath(state, enemy, false)
            end
        end
    end
end

--- 处理结界伤害（敌人站在结界上受伤）
--- 处理地刺陷阱伤害（敌人站在地刺上受伤）
function Battle.ProcessSpikeTraps(state)
    local spikes = state._spikeTraps
    if not spikes then return end
    for i = #spikes, 1, -1 do
        local spike = spikes[i]
        local enemy = HexGrid.GetPieceAt(state.board, spike.col, spike.row)
        if enemy and enemy.team == "enemy" and enemy.hp > 0 then
            local dmg = spike.damage or 10
            dmg = Battle.ApplyAltarReduction(state, enemy, dmg)
            enemy.hp = enemy.hp - dmg
            state.totalDamage = state.totalDamage + dmg
            Battle.AddFloatingText(state, enemy.col, enemy.row,
                "-" .. dmg .. "🔺", {180, 100, 80, 255})
            Battle.AddLog(state, string.format("%s 踩到地刺！受到 %d 伤害", enemy.name, dmg))
            Battle.AddVFX(state, "spike_hit", { col = enemy.col, row = enemy.row, duration = 0.5 })
            AM.PlaySFX("spike_trap_hit", 0.7)

            -- Lv3: 减速1回合
            local spikeLv = Skills.Level(state.skills, "spike_trap")
            if spikeLv >= 3 then
                enemy._spikeSlowed = true
                Battle.AddFloatingText(state, enemy.col, enemy.row,
                    "🔺减速", {180, 100, 80, 255})
            end

            -- === 组合技·碎片雷区: 地刺被踩，射出1枚碎片(isSecondary=true，碎片不再生成地刺) ===
            if Skills.HasCombo(state.skills, "combo_shard_minefield") then
                Battle.ApplySplitShot(state, { col = spike.col, row = spike.row }, 1, true)
            end

            if enemy.hp <= 0 then
                Battle.HandleEnemyDeath(state, enemy, false)
            end
        end
        -- 减少持续回合
        spike.turns = spike.turns - 1
        if spike.turns <= 0 then
            table.remove(spikes, i)
        end
    end
end

--- 获取指定位置的地刺
function Battle.GetSpikeAt(state, col, row)
    local spikes = state._spikeTraps
    if not spikes then return nil end
    for _, spike in ipairs(spikes) do
        if spike.col == col and spike.row == row then
            return spike
        end
    end
    return nil
end

--- 封印/眩晕减益回合递减（回合结束递减，到0时解除）
function Battle.TickSealDebuff(state)
    local enemies = HexGrid.GetTeamPieces(state.board, "enemy")
    for _, enemy in ipairs(enemies) do
        if enemy._sealedTurns and enemy._sealedTurns > 0 then
            enemy._sealedTurns = enemy._sealedTurns - 1
            if enemy._sealedTurns <= 0 then
                enemy._sealedTurns = nil
                enemy._sealedDmgReduction = nil
                Battle.AddFloatingText(state, enemy.col, enemy.row,
                    "🔓封印解除", {200, 200, 100, 255})
            end
        end
        if enemy._stunnedTurns and enemy._stunnedTurns > 0 then
            enemy._stunnedTurns = enemy._stunnedTurns - 1
            if enemy._stunnedTurns <= 0 then
                enemy._stunnedTurns = nil
                Battle.AddFloatingText(state, enemy.col, enemy.row,
                    "💫眩晕解除", {200, 200, 100, 255})
            end
        end
        -- 冰霜印记冻结回合递减
        if enemy._frozenTurns and enemy._frozenTurns > 0 then
            enemy._frozenTurns = enemy._frozenTurns - 1
            if enemy._frozenTurns <= 0 then
                enemy._frozenTurns = nil
                Battle.AddFloatingText(state, enemy.col, enemy.row,
                    "❄冻结解除", {150, 220, 255, 255})
            end
        end
        -- 寂灭之路: 沉默回合递减
        if enemy._silencedTurns and enemy._silencedTurns > 0 then
            enemy._silencedTurns = enemy._silencedTurns - 1
            if enemy._silencedTurns <= 0 then
                enemy._silencedTurns = nil
                Battle.AddFloatingText(state, enemy.col, enemy.row,
                    "🤐沉默解除", {100, 60, 160, 255})
                -- Lv5: 沉默结束时造成20固定伤害
                local spLv5 = Skills.Level(state.skills, "silence_path")
                if spLv5 >= 5 and enemy.hp > 0 then
                    local silenceDmg = 20
                    silenceDmg = Battle.ApplyAltarReduction(state, enemy, silenceDmg)
                    enemy.hp = enemy.hp - silenceDmg
                    state.totalDamage = (state.totalDamage or 0) + silenceDmg
                    Battle.AddFloatingText(state, enemy.col, enemy.row,
                        "-" .. silenceDmg .. "🤐爆", {140, 60, 200, 255})
                    -- 紫色魔法爆裂特效（复用 boss_enrage 传入紫色）+ 低沉爆裂音
                    Battle.AddVFX(state, "boss_enrage", {
                        col = enemy.col, row = enemy.row,
                        bossColor = {160, 60, 220},
                        duration = 0.65,
                    })
                    AM.PlaySFX("meteor_impact", 0.85, 0.8)
                    if enemy.hp <= 0 then
                        Battle.HandleEnemyDeath(state, enemy, false)
                    end
                end
            end
        end
        -- 飞镖风暴Lv5: 灼烧DOT递减
        if enemy._burnTurns and enemy._burnTurns > 0 then
            local burnDmg = enemy._burnDmg or 8
            burnDmg = Battle.ApplyAltarReduction(state, enemy, burnDmg)
            enemy.hp = enemy.hp - burnDmg
            state.totalDamage = (state.totalDamage or 0) + burnDmg
            Battle.AddFloatingText(state, enemy.col, enemy.row,
                "-" .. burnDmg .. "🔥", {255, 120, 30, 255})
            -- 灼烧跳动小火焰特效 + 轻微噼啪音效
            Battle.AddVFX(state, "flame_bolt", {
                col = enemy.col, row = enemy.row,
                duration = 0.4,
            })
            AM.PlaySFX("flame_bolt_impact", 0.4, 1.3)
            enemy._burnTurns = enemy._burnTurns - 1
            if enemy._burnTurns <= 0 then
                enemy._burnTurns = nil
                enemy._burnDmg = nil
            end
            if enemy.hp <= 0 then
                Battle.HandleEnemyDeath(state, enemy, false)
            end
        end
    end
end

--- 幽影雷暴：每个毒雾格电击一个相邻敌人（每回合）
function Battle.ProcessPhantomStorm(state)
    local board = state.board
    for _, poison in ipairs(board.poisonTiles) do
        -- 找毒雾格的相邻敌人
        local neighbors = HexGrid.GetNeighbors(poison.col, poison.row)
        for _, n in ipairs(neighbors) do
            local target = HexGrid.GetPieceAt(board, n.col, n.row)
            if target and target.team == "enemy" and target.hp > 0 then
                local zapDmg = 10
                zapDmg = Battle.ApplyAltarReduction(state, target, zapDmg)
                target.hp = target.hp - zapDmg
                state.totalDamage = state.totalDamage + zapDmg
                Battle.AddFloatingText(state, n.col, n.row,
                    "-" .. zapDmg .. "⚡", {200, 100, 255, 255})
                Battle.AddVFX(state, "lightning", {
                    fromCol = poison.col, fromRow = poison.row,
                    toCol = n.col, toRow = n.row,
                    duration = 0.4,
                })
                Battle.AddLog(state, string.format("⚡ 幽影雷暴！%s 受到 %d 伤害", target.name, zapDmg))
                if target.hp <= 0 then
                    Battle.HandleEnemyDeath(state, target, true)
                end
                break -- 每个毒雾格只电一个
            end
        end
    end
end

--- 单个敌人行动
function Battle.EnemyAct(state, enemy)
    -- Boss使用专用行动逻辑
    if enemy.isBoss then
        return Battle.BossAct(state, enemy)
    end

    -- === 第二章: 寄居蟹缩壳状态跳过行动 ===
    if enemy.enemyType == "hermit_crab" and enemy.hasShell then
        Battle.AddFloatingText(state, enemy.col, enemy.row,
            "🐚防御中", {180, 140, 100, 255})
        return { type = "shelled", enemy = enemy }
    end

    -- === 天罚眩晕: 被眩晕的敌人完全跳过行动 ===
    if enemy._stunnedTurns and enemy._stunnedTurns > 0 then
        Battle.AddFloatingText(state, enemy.col, enemy.row,
            "💫眩晕中", {255, 200, 0, 255})
        return { type = "stunned", enemy = enemy }
    end

    -- === 冰霜印记: 被冻结的敌人完全跳过行动 ===
    if enemy._frozenTurns and enemy._frozenTurns > 0 then
        Battle.AddFloatingText(state, enemy.col, enemy.row,
            "❄冻结中", {100, 200, 255, 255})
        return { type = "frozen", enemy = enemy }
    end

    -- === 六芒封印: 被封印的敌人无法移动，可攻击但伤害降低 ===
    if enemy._sealedTurns and enemy._sealedTurns > 0 then
        local hero = state.hero
        -- 确定攻击目标
        local sealTarget = hero
        local sealTargetIsScarecrow = false
        if state.scarecrowActive and state.scarecrow and state.scarecrow.hp > 0 then
            sealTarget = state.scarecrow
            sealTargetIsScarecrow = true
        end
        local range = enemy.attackRange or 1
        local distToTarget = HexGrid.CubeDistance(enemy.col, enemy.row, sealTarget.col, sealTarget.row)
        if distToTarget <= range and enemy.atk > 0 then
            -- 在攻击范围内：可以攻击，但伤害降低50%
            local reduction = enemy._sealedDmgReduction or 0.5
            local targetDef = sealTarget.def or 0
            local baseDmg = Battle.CalcEnemyDmg(enemy.atk, targetDef)
            local actualDmg = math.max(1, math.floor(baseDmg * (1 - reduction)))

            if sealTargetIsScarecrow then
                sealTarget.hp = sealTarget.hp - actualDmg
                sealTarget.totalDamageAbsorbed = (sealTarget.totalDamageAbsorbed or 0) + actualDmg
                sealTarget.hitCount = (sealTarget.hitCount or 0) + 1
                Battle.AddLog(state, string.format("🔮%s封印中攻击稻草人，伤害减半！-%d", enemy.name, actualDmg))
                if sealTarget.hp <= 0 then
                    state.scarecrowActive = false
                    state.scarecrow_destroyed = sealTarget
                end
            else
                -- 检查护盾
                if state.hasShield then
                    actualDmg = math.floor(actualDmg / 2)
                    state.hasShield = false
                    Battle.AddFloatingText(state, hero.col, hero.row,
                        "🛡️挡!", {120, 180, 255, 255})
                elseif state.drainShield and state.drainShield > 0 then
                    local absorbed = math.min(state.drainShield, actualDmg)
                    actualDmg = actualDmg - absorbed
                    state.drainShield = state.drainShield - absorbed
                    Battle.AddFloatingText(state, hero.col, hero.row,
                        "🔮盾-" .. absorbed, {200, 80, 200, 255})
                    if state.drainShield <= 0 then state.drainShield = nil end
                end
                hero.hp = hero.hp - actualDmg
                AM.PlaySFX("hero_damage")
                Battle.AddFloatingText(state, hero.col, hero.row,
                    "-" .. actualDmg .. "🔮弱", {255, 120, 180, 255}, "hit")
                state.screenShake = (state.screenShake or 0) + 0.2
                state.hitFlash = 0.15
            end
            Battle.AddFloatingText(state, enemy.col, enemy.row,
                "🔮封印中(攻击减半)", {180, 100, 255, 255})
            return { type = "sealed_attack", enemy = enemy, damage = actualDmg }
        else
            -- 不在攻击范围内：完全无法行动
            Battle.AddFloatingText(state, enemy.col, enemy.row,
                "🔮封印(" .. enemy._sealedTurns .. ")", {180, 100, 255, 255})
            return { type = "sealed", enemy = enemy }
        end
    end

    local hero = state.hero

    -- === 寂灭之路: 被沉默的敌人无法使用特殊技能，只能普通移动+攻击 ===
    local isSilenced = enemy._silencedTurns and enemy._silencedTurns > 0
    -- 沉默状态由头顶持续标记显示（见 BoardWidget 渲染），此处不再弹一次性浮字

    -- === 幽灵鲨: 瞬移到英雄身边攻击 ===
    if not isSilenced and enemy.enemyType == "ghost_shark" then
        return Battle.GhostSharkAct(state, enemy)
    end

    -- === 棘刺海葵: 远程攻击 + 保持距离 ===
    if not isSilenced and enemy.enemyType == "spine_anemone" then
        return Battle.SpineAnemoneAct(state, enemy)
    end

    -- === 射水鱼: 远程攻击 + 逃跑 ===
    if not isSilenced and enemy.enemyType == "archerfish" then
        return Battle.ArcherfishAct(state, enemy)
    end

    -- === 电鳐: 近战AOE放电 ===
    if not isSilenced and enemy.enemyType == "electric_ray" then
        return Battle.ElectricRayAct(state, enemy)
    end

    -- === 珊瑚祭司: 治疗/增益友军 ===
    if not isSilenced and enemy.enemyType == "coral_priest" then
        return Battle.CoralPriestAct(state, enemy)
    end

    -- === 裂变海胆: 普通近战，分裂逻辑在跳跃伤害处处理 ===
    if enemy.enemyType == "splitting_urchin" then
        -- 近战行为与普通敌人相同，直接走下方通用逻辑
    end

    -- === 疾梭鱼: 每回合最多移动3格 ===
    if not isSilenced and enemy.enemyType == "swift_barracuda" then
        return Battle.SwiftBarracudaAct(state, enemy)
    end

    -- === 魅惑水母: 普通近战，魅惑由 ProcessEnemyTurn 统一处理 ===
    if not isSilenced and enemy.enemyType == "charm_jelly" then
        return Battle.CharmJellyAct(state, enemy)
    end

    -- === 第四章特殊机制敌人 ===
    if not isSilenced and enemy.enemyType == "sand_strider" then
        return Battle.SandStriderAct(state, enemy)
    end
    if not isSilenced and enemy.enemyType == "sand_rattler" then
        return Battle.SandRattlerAct(state, enemy)
    end
    if not isSilenced and enemy.enemyType == "venom_lizard" then
        return Battle.VenomLizardAct(state, enemy)
    end

    -- === 确定攻击目标：稻草人嘲讽优先 ===
    local target = hero
    local targetIsScarecrow = false
    if state.scarecrowActive and state.scarecrow and state.scarecrow.hp > 0 then
        target = state.scarecrow
        targetIsScarecrow = true
    end

    -- 1. 检查是否在攻击范围内 → 攻击
    local range = enemy.attackRange or 1
    local distToTarget = HexGrid.CubeDistance(enemy.col, enemy.row, target.col, target.row)
    local canAttack = distToTarget <= range and enemy.atk > 0

    if canAttack then
        -- 铁龟防御减伤
        local targetDef = target.def or 0
        local actualDmg = Battle.CalcEnemyDmg(enemy.atk, targetDef)

        if targetIsScarecrow then
            -- 攻击稻草人
            target.hp = target.hp - actualDmg
            target.totalDamageAbsorbed = (target.totalDamageAbsorbed or 0) + actualDmg
            target.hitCount = (target.hitCount or 0) + 1
            -- 单条浮动文字不显示，由 ProcessEnemyTurn 结束后汇总
            Battle.AddLog(state, string.format("%s 攻击了稻草人！稻草人替你承受了 %d 伤害", enemy.name, actualDmg))
            -- 稻草人被摧毁
            if target.hp <= 0 then
                -- 击毁特效和汇总通知由 ProcessEnemyTurn 统一处理
                state.scarecrowActive = false
                state.scarecrow_destroyed = target  -- 暂存，供汇总使用
            end
        else
            -- 攻击英雄（原逻辑）
            -- 护盾: 减半伤害
            if state.hasShield then
                actualDmg = math.floor(actualDmg / 2)
                state.hasShield = false
                Battle.AddFloatingText(state, hero.col, hero.row,
                    "🛡️挡!", {120, 180, 255, 255})
                Battle.AddLog(state, "护盾抵消部分伤害！护盾消失")
            elseif state.drainShield and state.drainShield > 0 then
                local absorbed = math.min(state.drainShield, actualDmg)
                actualDmg = actualDmg - absorbed
                state.drainShield = state.drainShield - absorbed
                Battle.AddFloatingText(state, hero.col, hero.row,
                    "🔮盾-" .. absorbed, {200, 80, 200, 255})
                if state.drainShield <= 0 then state.drainShield = nil end
            end

            -- 连击护盾: 吸收伤害
            if (hero._shield or 0) > 0 and actualDmg > 0 then
                local absorbed = math.min(hero._shield, actualDmg)
                actualDmg = actualDmg - absorbed
                hero._shield = hero._shield - absorbed
                Battle.AddFloatingText(state, hero.col, hero.row,
                    "🛡-" .. absorbed, {60, 160, 220, 255})
                if hero._shield <= 0 then
                    hero._shield = 0
                    -- 护盾被完全打碎：播放破碎特效和音效
                    Battle.AddVFX(state, "shield_break", {
                        col = hero.col, row = hero.row, duration = 0.6,
                    })
                    AM.PlaySFX("shield_break", 0.6)
                    Battle.AddFloatingText(state, hero.col, hero.row,
                        "护盾破碎!", {100, 200, 255, 255})
                end
            end

            hero.hp = hero.hp - actualDmg
            AM.PlaySFX("hero_damage")
            Battle.AddFloatingText(state, hero.col, hero.row,
                "-" .. actualDmg, {255, 60, 60, 255}, "hit")
            state.screenShake = (state.screenShake or 0) + 0.35
            state.hitFlash = 0.25

        end

        local atkLabel = enemy.attackLabel or "攻击"
        if not targetIsScarecrow then
            Battle.AddLog(state, string.format("%s %s了剑士！伤害 %d",
                enemy.name, atkLabel, actualDmg))
        end

        -- 攻击特效
        if distToTarget > 1 then
            Battle.AddVFX(state, "ranged_attack", {
                fromCol = enemy.col, fromRow = enemy.row,
                toCol = target.col, toRow = target.row,
                duration = 0.4,
                enemyType = enemy.enemyType,
            })
        else
            Battle.AddVFX(state, "melee_slam", {
                col = target.col, row = target.row,
                fromCol = enemy.col, fromRow = enemy.row,
                duration = 0.45,
                enemyType = enemy.enemyType,
            })
        end

        -- === 荆棘护甲: 反弹伤害（仅对攻击英雄生效）===
        if not targetIsScarecrow then
            local thornsLv = Skills.Level(state.skills, "thorns")
            if thornsLv >= 1 then
                local thornRate = (20 + thornsLv * 8) / 100
                local thornsDmg = math.floor(enemy.atk * thornRate)
                if thornsDmg > 0 then
                    enemy.hp = enemy.hp - thornsDmg
                    AM.PlaySFX("thorns_reflect", 0.6)
                    Battle.AddFloatingText(state, enemy.col, enemy.row,
                        "-" .. thornsDmg .. "🛡️荆棘", {200, 150, 255, 255})
                    Battle.AddVFX(state, "thorns", {
                        col = hero.col, row = hero.row,
                        targetCol = enemy.col, targetRow = enemy.row,
                        duration = 0.5,
                    })
                    Battle.AddLog(state, string.format("🛡️荆棘！%s 受到 %d 反弹伤害",
                        enemy.name, thornsDmg))

                    -- Lv3 或 组合技·血棘共生: 反弹伤害转治疗
                    local thornHealRate = 0
                    if thornsLv >= 3 then thornHealRate = 0.5 end
                    local isBloodThorns = Skills.HasCombo(state.skills, "combo_blood_thorns")
                    if isBloodThorns then
                        thornHealRate = math.max(thornHealRate, 0.5)
                        if hero.hp < hero.maxHp * 0.5 then
                            thornHealRate = thornHealRate + 0.2  -- HP<50%额外+20% → 70%转治疗
                        end
                    end
                    if thornHealRate > 0 then
                        local heal = math.min(math.floor(thornsDmg * thornHealRate), hero.maxHp - hero.hp)
                        if heal > 0 then
                            hero.hp = hero.hp + heal
                            Battle.AddFloatingText(state, hero.col, hero.row,
                                "+" .. heal .. (isBloodThorns and "🌿共生" or "🩸"),
                                isBloodThorns and {120, 220, 120, 255} or {200, 50, 50, 255})
                        end
                    end

                    if enemy.hp <= 0 then
                        Battle.HandleEnemyDeath(state, enemy, false)
                    end
                end
            end
        end

        return { type = "attack", enemy = enemy, damage = actualDmg }
    end

    -- 2. 移动（朝目标方向）
    local validMoves = HexGrid.FindValidMoves(state.board, enemy.col, enemy.row)
    if #validMoves == 0 then
        return { type = "idle", enemy = enemy }
    end

    local bestMove = Battle.FindClosestMove(validMoves, target.col, target.row)

    if bestMove then
        enemy.animFromCol = enemy.col
        enemy.animFromRow = enemy.row
        enemy.animTimer = 0.3
        enemy.animMaxTimer = 0.3
        enemy.col = bestMove.col
        enemy.row = bestMove.row
        return { type = "move", enemy = enemy }
    end

    return { type = "idle", enemy = enemy }
end

-- ============================================================================
-- 新机制敌人专用 AI
-- ============================================================================

--- 幽灵鲨 AI：瞬移到英雄身边攻击，1回合冷却
function Battle.GhostSharkAct(state, enemy)
    local hero = state.hero
    -- 稻草人嘲讽优先
    local target = hero
    if state.scarecrowActive and state.scarecrow and state.scarecrow.hp > 0 then
        target = state.scarecrow
    end

    -- 冷却中 → 普通移动AI
    if enemy._teleportCD and enemy._teleportCD > 0 then
        enemy._teleportCD = enemy._teleportCD - 1
        -- 普通移动逻辑
        local validMoves = HexGrid.FindValidMoves(state.board, enemy.col, enemy.row)
        if #validMoves > 0 then
            local bestMove = Battle.FindClosestMove(validMoves, target.col, target.row)
            if bestMove then
                enemy.animFromCol = enemy.col
                enemy.animFromRow = enemy.row
                enemy.animTimer = 0.3
                enemy.animMaxTimer = 0.3
                enemy.col = bestMove.col
                enemy.row = bestMove.row
                return { type = "move", enemy = enemy }
            end
        end
        return { type = "idle", enemy = enemy }
    end

    -- 瞬移：找目标相邻空格
    local neighbors = HexGrid.GetNeighbors(target.col, target.row)
    local candidates = {}
    for _, n in ipairs(neighbors) do
        if HexGrid.InBounds(n.col, n.row) and
           not HexGrid.IsBlocked(state.board, n.col, n.row) and
           not (n.col == enemy.col and n.row == enemy.row) then
            candidates[#candidates + 1] = n
        end
    end

    if #candidates > 0 then
        -- 记录消失位置
        local fromCol, fromRow = enemy.col, enemy.row
        -- 瞬移到随机空位
        local dest = candidates[math.random(1, #candidates)]

        -- 瞬移VFX: 消失
        Battle.AddVFX(state, "teleport_out", {
            col = fromCol, row = fromRow, duration = 0.4,
            enemyType = enemy.enemyType,
        })

        enemy.col = dest.col
        enemy.row = dest.row

        -- 瞬移VFX: 出现
        Battle.AddVFX(state, "teleport_in", {
            col = dest.col, row = dest.row, duration = 0.4,
            enemyType = enemy.enemyType,
        })

        Battle.AddFloatingText(state, dest.col, dest.row,
            "🦈瞬移!", {100, 180, 255, 255})
        Battle.AddLog(state, string.format("%s 瞬移到了英雄身边！", enemy.name))

        -- 立即攻击
        local targetDef = target.def or 0
        local actualDmg = Battle.CalcEnemyDmg(enemy.atk, targetDef)

        if target == hero then
            -- 护盾减伤
            if state.hasShield then
                actualDmg = math.floor(actualDmg / 2)
                state.hasShield = false
                Battle.AddFloatingText(state, hero.col, hero.row,
                    "🛡️挡!", {120, 180, 255, 255})
            elseif state.drainShield and state.drainShield > 0 then
                local absorbed = math.min(state.drainShield, actualDmg)
                actualDmg = actualDmg - absorbed
                state.drainShield = state.drainShield - absorbed
                Battle.AddFloatingText(state, hero.col, hero.row,
                    "🔮盾-" .. absorbed, {200, 80, 200, 255})
                if state.drainShield <= 0 then state.drainShield = nil end
            end
            hero.hp = hero.hp - actualDmg
            AM.PlaySFX("hero_damage")
            Battle.AddFloatingText(state, hero.col, hero.row,
                "-" .. actualDmg, {255, 60, 60, 255}, "hit")
            state.screenShake = (state.screenShake or 0) + 0.4
            state.hitFlash = 0.25
        else
            -- 攻击稻草人（单条不显示，ProcessEnemyTurn 汇总）
            target.hp = target.hp - actualDmg
            target.totalDamageAbsorbed = (target.totalDamageAbsorbed or 0) + actualDmg
            target.hitCount = (target.hitCount or 0) + 1
            if target.hp <= 0 then
                state.scarecrowActive = false
                state.scarecrow_destroyed = target
            end
        end

        Battle.AddVFX(state, "melee_slam", {
            col = target.col, row = target.row,
            fromCol = dest.col, fromRow = dest.row,
            duration = 0.45, enemyType = enemy.enemyType,
        })

        -- 设置冷却
        enemy._teleportCD = enemy.teleportCooldown or 1

        -- 荆棘反伤（如果攻击英雄）
        if target == hero then
            local thornsLv = Skills.Level(state.skills, "thorns")
            if thornsLv >= 1 then
                local thornRate = (20 + thornsLv * 8) / 100
                local thornsDmg = math.floor(enemy.atk * thornRate)
                if thornsDmg > 0 then
                    enemy.hp = enemy.hp - thornsDmg
                    AM.PlaySFX("thorns_reflect", 0.6)
                    Battle.AddFloatingText(state, enemy.col, enemy.row,
                        "-" .. thornsDmg .. "🛡️荆棘", {200, 150, 255, 255})
                    if enemy.hp <= 0 then
                        Battle.HandleEnemyDeath(state, enemy, false)
                    end
                end
            end
        end

        return { type = "attack", enemy = enemy, damage = actualDmg }
    end

    -- 找不到空位 → 普通移动
    local validMoves = HexGrid.FindValidMoves(state.board, enemy.col, enemy.row)
    if #validMoves > 0 then
        local bestMove = Battle.FindClosestMove(validMoves, target.col, target.row)
        if bestMove then
            enemy.animFromCol = enemy.col
            enemy.animFromRow = enemy.row
            enemy.animTimer = 0.3
            enemy.animMaxTimer = 0.3
            enemy.col = bestMove.col
            enemy.row = bestMove.row
            return { type = "move", enemy = enemy }
        end
    end
    return { type = "idle", enemy = enemy }
end

--- 射水鱼 AI：远程攻击 + 灵活走位
function Battle.ArcherfishAct(state, enemy)
    local hero = state.hero
    local target = hero
    if state.scarecrowActive and state.scarecrow and state.scarecrow.hp > 0 then
        target = state.scarecrow
    end

    local range = enemy.attackRange or 2
    local distToTarget = HexGrid.CubeDistance(enemy.col, enemy.row, target.col, target.row)
    local validMoves = HexGrid.FindValidMoves(state.board, enemy.col, enemy.row)

    -- 英雄太近（距离<=1）→ 逃跑优先
    if distToTarget <= 1 then
        if #validMoves > 0 then
            local fleeMove = Battle.FindFarthestMove(validMoves, target.col, target.row)
            if fleeMove then
                enemy.animFromCol = enemy.col
                enemy.animFromRow = enemy.row
                enemy.animTimer = 0.3
                enemy.animMaxTimer = 0.3
                enemy.col = fleeMove.col
                enemy.row = fleeMove.row
                Battle.AddFloatingText(state, enemy.col, enemy.row,
                    "🐟闪避!", {80, 200, 255, 255})
                return { type = "move", enemy = enemy }
            end
        end
        -- 逃不了 → 近战攻击
    end

    -- 在射程内（1~range）→ 远程攻击
    if distToTarget <= range and distToTarget >= 1 then
        local targetDef = target.def or 0
        local actualDmg = Battle.CalcEnemyDmg(enemy.atk, targetDef)

        if target == hero then
            if state.hasShield then
                actualDmg = math.floor(actualDmg / 2)
                state.hasShield = false
                Battle.AddFloatingText(state, hero.col, hero.row,
                    "🛡️挡!", {120, 180, 255, 255})
            elseif state.drainShield and state.drainShield > 0 then
                local absorbed = math.min(state.drainShield, actualDmg)
                actualDmg = actualDmg - absorbed
                state.drainShield = state.drainShield - absorbed
                Battle.AddFloatingText(state, hero.col, hero.row,
                    "🔮盾-" .. absorbed, {200, 80, 200, 255})
                if state.drainShield <= 0 then state.drainShield = nil end
            end
            hero.hp = hero.hp - actualDmg
            AM.PlaySFX("hero_damage")
            Battle.AddFloatingText(state, hero.col, hero.row,
                "-" .. actualDmg, {255, 60, 60, 255}, "hit")
            state.screenShake = (state.screenShake or 0) + 0.2
            state.hitFlash = 0.15
        else
            -- 攻击稻草人（单条不显示，ProcessEnemyTurn 汇总）
            target.hp = target.hp - actualDmg
            target.totalDamageAbsorbed = (target.totalDamageAbsorbed or 0) + actualDmg
            target.hitCount = (target.hitCount or 0) + 1
            if target.hp <= 0 then
                state.scarecrowActive = false
                state.scarecrow_destroyed = target
            end
        end

        Battle.AddVFX(state, "ranged_attack", {
            fromCol = enemy.col, fromRow = enemy.row,
            toCol = target.col, toRow = target.row,
            duration = 0.4, enemyType = enemy.enemyType,
        })

        local atkLabel = enemy.attackLabel or "水弹"
        Battle.AddLog(state, string.format("%s %s了目标！伤害 %d",
            enemy.name, atkLabel, actualDmg))

        -- 荆棘反伤
        if target == hero then
            local thornsLv = Skills.Level(state.skills, "thorns")
            if thornsLv >= 1 then
                local thornRate = (20 + thornsLv * 8) / 100
                local thornsDmg = math.floor(enemy.atk * thornRate)
                if thornsDmg > 0 then
                    enemy.hp = enemy.hp - thornsDmg
                    AM.PlaySFX("thorns_reflect", 0.6)
                    Battle.AddFloatingText(state, enemy.col, enemy.row,
                        "-" .. thornsDmg .. "🛡️荆棘", {200, 150, 255, 255})
                    if enemy.hp <= 0 then
                        Battle.HandleEnemyDeath(state, enemy, false)
                    end
                end
            end
        end

        return { type = "attack", enemy = enemy, damage = actualDmg }
    end

    -- 距离太远 → 靠近到射程边缘（距离=2）
    if #validMoves > 0 then
        local optMove = Battle.FindOptimalRangeMove(validMoves, target.col, target.row, 2)
        if optMove then
            enemy.animFromCol = enemy.col
            enemy.animFromRow = enemy.row
            enemy.animTimer = 0.3
            enemy.animMaxTimer = 0.3
            enemy.col = optMove.col
            enemy.row = optMove.row
            return { type = "move", enemy = enemy }
        end
    end

    return { type = "idle", enemy = enemy }
end

--- 电鳐 AI：近战 + AOE放电（攻击时对英雄周围友军也造成半额伤害）
function Battle.ElectricRayAct(state, enemy)
    local hero = state.hero
    local target = hero
    local targetIsScarecrow = false
    if state.scarecrowActive and state.scarecrow and state.scarecrow.hp > 0 then
        target = state.scarecrow
        targetIsScarecrow = true
    end

    local distToTarget = HexGrid.CubeDistance(enemy.col, enemy.row, target.col, target.row)
    local validMoves = HexGrid.FindValidMoves(state.board, enemy.col, enemy.row)

    -- 在攻击范围内 → 放电攻击（AOE）
    if distToTarget <= 1 and enemy.atk > 0 then
        local targetDef = target.def or 0
        local actualDmg = Battle.CalcEnemyDmg(enemy.atk, targetDef)

        if target == hero then
            if state.hasShield then
                actualDmg = math.floor(actualDmg / 2)
                state.hasShield = false
                Battle.AddFloatingText(state, hero.col, hero.row,
                    "🛡️挡!", {120, 180, 255, 255})
            elseif state.drainShield and state.drainShield > 0 then
                local absorbed = math.min(state.drainShield, actualDmg)
                actualDmg = actualDmg - absorbed
                state.drainShield = state.drainShield - absorbed
                Battle.AddFloatingText(state, hero.col, hero.row,
                    "🔮盾-" .. absorbed, {200, 80, 200, 255})
                if state.drainShield <= 0 then state.drainShield = nil end
            end
            hero.hp = hero.hp - actualDmg
            AM.PlaySFX("hero_damage")
            Battle.AddFloatingText(state, hero.col, hero.row,
                "-" .. actualDmg .. "⚡", {180, 220, 255, 255}, "hit")
            state.screenShake = (state.screenShake or 0) + 0.3
            state.hitFlash = 0.2
        else
            -- 攻击稻草人（单条不显示，ProcessEnemyTurn 汇总）
            target.hp = target.hp - actualDmg
            target.totalDamageAbsorbed = (target.totalDamageAbsorbed or 0) + actualDmg
            target.hitCount = (target.hitCount or 0) + 1
            Battle.AddLog(state, string.format("电鳗放电攻击了稻草人！稻草人替你承受了 %d 伤害", actualDmg))
            if target.hp <= 0 then
                state.scarecrowActive = false
                state.scarecrow_destroyed = target
            end
        end

        -- ⚡ AOE 放电：对目标周围1格内的其他友方英雄造成半额伤害
        -- （在当前棋盘逻辑中，英雄只有一个，所以AOE主要体现为视觉特效+对英雄的额外伤害说明）
        -- 实际效果：对英雄位置周围1格内所有己方棋子（如果有稻草人等）也造成半额伤害
        local aoeDmg = math.floor(actualDmg / 2)
        if aoeDmg > 0 and not targetIsScarecrow then
            -- 检查稻草人是否在AOE范围内
            if state.scarecrowActive and state.scarecrow and state.scarecrow.hp > 0 then
                local scareDist = HexGrid.CubeDistance(hero.col, hero.row, state.scarecrow.col, state.scarecrow.row)
                if scareDist <= 1 then
                    state.scarecrow.hp = state.scarecrow.hp - aoeDmg
                    state.scarecrow.totalDamageAbsorbed = (state.scarecrow.totalDamageAbsorbed or 0) + aoeDmg
                    state.scarecrow.hitCount = (state.scarecrow.hitCount or 0) + 1
                    if state.scarecrow.hp <= 0 then
                        state.scarecrowActive = false
                        state.scarecrow_destroyed = state.scarecrow
                    end
                end
            end
        end

        -- 放电视觉特效
        Battle.AddVFX(state, "electric_discharge", {
            col = target.col, row = target.row,
            duration = 0.5, radius = 1,
        })

        Battle.AddLog(state, string.format("%s 放电攻击！伤害 %d（AOE⚡）",
            enemy.name, actualDmg))

        -- 荆棘反伤
        if target == hero then
            local thornsLv = Skills.Level(state.skills, "thorns")
            if thornsLv >= 1 then
                local thornRate = (20 + thornsLv * 8) / 100
                local thornsDmg = math.floor(enemy.atk * thornRate)
                if thornsDmg > 0 then
                    enemy.hp = enemy.hp - thornsDmg
                    AM.PlaySFX("thorns_reflect", 0.6)
                    Battle.AddFloatingText(state, enemy.col, enemy.row,
                        "-" .. thornsDmg .. "🛡️荆棘", {200, 150, 255, 255})
                    if enemy.hp <= 0 then
                        Battle.HandleEnemyDeath(state, enemy, false)
                    end
                end
            end
        end

        return { type = "attack", enemy = enemy, damage = actualDmg }
    end

    -- 不在攻击范围 → 移向目标
    if #validMoves > 0 then
        local bestMove = Battle.FindClosestMove(validMoves, target.col, target.row)
        if bestMove then
            enemy.animFromCol = enemy.col
            enemy.animFromRow = enemy.row
            enemy.animTimer = 0.3
            enemy.animMaxTimer = 0.3
            enemy.col = bestMove.col
            enemy.row = bestMove.row
            return { type = "move", enemy = enemy }
        end
    end

    return { type = "idle", enemy = enemy }
end

--- 棘刺海葵 AI：远程攻击 + 保持距离
function Battle.SpineAnemoneAct(state, enemy)
    local hero = state.hero
    local target = hero
    if state.scarecrowActive and state.scarecrow and state.scarecrow.hp > 0 then
        target = state.scarecrow
    end

    local range = enemy.attackRange or 3
    local distToTarget = HexGrid.CubeDistance(enemy.col, enemy.row, target.col, target.row)
    local validMoves = HexGrid.FindValidMoves(state.board, enemy.col, enemy.row)

    -- 英雄太近（距离<=1）→ 逃跑优先
    if distToTarget <= 1 then
        if #validMoves > 0 then
            local fleeMove = Battle.FindFarthestMove(validMoves, target.col, target.row)
            if fleeMove then
                enemy.animFromCol = enemy.col
                enemy.animFromRow = enemy.row
                enemy.animTimer = 0.3
                enemy.animMaxTimer = 0.3
                enemy.col = fleeMove.col
                enemy.row = fleeMove.row
                Battle.AddFloatingText(state, enemy.col, enemy.row,
                    "🌺后退!", {200, 120, 180, 255})
                return { type = "move", enemy = enemy }
            end
        end
        -- 逃不了 → 尝试近战
    end

    -- 在射程内（2~range）→ 远程攻击（不移动）
    if distToTarget <= range and distToTarget >= 1 then
        local targetDef = target.def or 0
        local actualDmg = Battle.CalcEnemyDmg(enemy.atk, targetDef)

        if target == hero then
            if state.hasShield then
                actualDmg = math.floor(actualDmg / 2)
                state.hasShield = false
                Battle.AddFloatingText(state, hero.col, hero.row,
                    "🛡️挡!", {120, 180, 255, 255})
            elseif state.drainShield and state.drainShield > 0 then
                local absorbed = math.min(state.drainShield, actualDmg)
                actualDmg = actualDmg - absorbed
                state.drainShield = state.drainShield - absorbed
                Battle.AddFloatingText(state, hero.col, hero.row,
                    "🔮盾-" .. absorbed, {200, 80, 200, 255})
                if state.drainShield <= 0 then state.drainShield = nil end
            end
            hero.hp = hero.hp - actualDmg
            AM.PlaySFX("hero_damage")
            Battle.AddFloatingText(state, hero.col, hero.row,
                "-" .. actualDmg, {255, 60, 60, 255}, "hit")
            state.screenShake = (state.screenShake or 0) + 0.25
            state.hitFlash = 0.2
        else
            -- 攻击稻草人（单条不显示，ProcessEnemyTurn 汇总）
            target.hp = target.hp - actualDmg
            target.totalDamageAbsorbed = (target.totalDamageAbsorbed or 0) + actualDmg
            target.hitCount = (target.hitCount or 0) + 1
            if target.hp <= 0 then
                state.scarecrowActive = false
                state.scarecrow_destroyed = target
            end
        end

        Battle.AddVFX(state, "ranged_attack", {
            fromCol = enemy.col, fromRow = enemy.row,
            toCol = target.col, toRow = target.row,
            duration = 0.4, enemyType = enemy.enemyType,
        })

        local atkLabel = enemy.attackLabel or "棘射"
        Battle.AddLog(state, string.format("%s 远程%s了目标！伤害 %d",
            enemy.name, atkLabel, actualDmg))

        -- 荆棘反伤
        if target == hero then
            local thornsLv = Skills.Level(state.skills, "thorns")
            if thornsLv >= 1 then
                local thornRate = (20 + thornsLv * 8) / 100
                local thornsDmg = math.floor(enemy.atk * thornRate)
                if thornsDmg > 0 then
                    enemy.hp = enemy.hp - thornsDmg
                    AM.PlaySFX("thorns_reflect", 0.6)
                    Battle.AddFloatingText(state, enemy.col, enemy.row,
                        "-" .. thornsDmg .. "🛡️荆棘", {200, 150, 255, 255})
                    if enemy.hp <= 0 then
                        Battle.HandleEnemyDeath(state, enemy, false)
                    end
                end
            end
        end

        return { type = "attack", enemy = enemy, damage = actualDmg }
    end

    -- 距离太远 → 靠近到理想射程
    if #validMoves > 0 then
        local optMove = Battle.FindOptimalRangeMove(validMoves, target.col, target.row, 2)
        if optMove then
            enemy.animFromCol = enemy.col
            enemy.animFromRow = enemy.row
            enemy.animTimer = 0.3
            enemy.animMaxTimer = 0.3
            enemy.col = optMove.col
            enemy.row = optMove.row
            return { type = "move", enemy = enemy }
        end
    end

    return { type = "idle", enemy = enemy }
end

--- 珊瑚祭司 AI：治疗/增益友军，不攻击英雄
function Battle.CoralPriestAct(state, enemy)
    local hero = state.hero
    local enemies = HexGrid.GetTeamPieces(state.board, "enemy")

    -- 找需要治疗的友军（HP不满，且不是自己）
    local woundedAlly = nil
    local lowestHpRatio = 1.1
    for _, e in ipairs(enemies) do
        if e ~= enemy and e.hp > 0 and not e.isBoss then
            local ratio = e.hp / e.maxHp
            if ratio < lowestHpRatio then
                lowestHpRatio = ratio
                woundedAlly = e
            end
        end
    end

    -- 找相邻友军（用于治疗/buff）
    local adjacentAllies = {}
    local neighbors = HexGrid.GetNeighbors(enemy.col, enemy.row)
    for _, n in ipairs(neighbors) do
        for _, e in ipairs(enemies) do
            if e ~= enemy and e.hp > 0 and e.col == n.col and e.row == n.row then
                adjacentAllies[#adjacentAllies + 1] = e
            end
        end
    end

    -- 有相邻友军 → 治疗最伤的 + 给所有相邻友军buff
    if #adjacentAllies > 0 then
        -- 治疗
        local healTarget = adjacentAllies[1]
        for _, a in ipairs(adjacentAllies) do
            if a.hp / a.maxHp < healTarget.hp / healTarget.maxHp then
                healTarget = a
            end
        end
        local healAmt = enemy.healAmount or 6
        local actualHeal = math.min(healAmt, healTarget.maxHp - healTarget.hp)
        if actualHeal > 0 then
            healTarget.hp = healTarget.hp + actualHeal
            Battle.AddFloatingText(state, healTarget.col, healTarget.row,
                "+" .. actualHeal .. "💚", {100, 255, 150, 255})
            Battle.AddLog(state, string.format("%s 治疗了 %s %d HP！",
                enemy.name, healTarget.name, actualHeal))
        end

        -- 给所有相邻友军ATK buff
        local buffVal = enemy.buffATK or 3
        for _, a in ipairs(adjacentAllies) do
            a.atk = a.atk + buffVal
            a._priestBuff = (a._priestBuff or 0) + buffVal
            Battle.AddFloatingText(state, a.col, a.row,
                "+ATK" .. buffVal .. "🧙", {255, 200, 100, 255})
        end

        -- 治疗VFX
        if actualHeal > 0 then
            Battle.AddVFX(state, "support_heal", {
                col = healTarget.col, row = healTarget.row, duration = 0.7,
            })
        end
        -- BUFF VFX（给每个被增益的友军）
        for _, a in ipairs(adjacentAllies) do
            Battle.AddVFX(state, "support_buff", {
                col = a.col, row = a.row, duration = 0.6,
            })
        end

        return { type = "support", enemy = enemy }
    end

    -- 没有相邻友军 → 移向需要治疗的友军
    if woundedAlly then
        local validMoves = HexGrid.FindValidMoves(state.board, enemy.col, enemy.row)
        if #validMoves > 0 then
            local bestMove = Battle.FindClosestMove(validMoves, woundedAlly.col, woundedAlly.row)
            if bestMove then
                enemy.animFromCol = enemy.col
                enemy.animFromRow = enemy.row
                enemy.animTimer = 0.3
                enemy.animMaxTimer = 0.3
                enemy.col = bestMove.col
                enemy.row = bestMove.row
                return { type = "move", enemy = enemy }
            end
        end
    end

    -- 没有友军 → 靠近英雄（让玩家有机会跳到它）
    local validMoves = HexGrid.FindValidMoves(state.board, enemy.col, enemy.row)
    if #validMoves > 0 then
        local approachMove = Battle.FindClosestMove(validMoves, hero.col, hero.row)
        if approachMove then
            enemy.animFromCol = enemy.col
            enemy.animFromRow = enemy.row
            enemy.animTimer = 0.3
            enemy.animMaxTimer = 0.3
            enemy.col = approachMove.col
            enemy.row = approachMove.row
            Battle.AddFloatingText(state, approachMove.col, approachMove.row,
                "🧙召唤...", {255, 200, 100, 180})
            return { type = "move", enemy = enemy }
        end
    end

    return { type = "idle", enemy = enemy }
end

--- 潮汐使者 AI：每2回合对相邻友军施加潮涌增益(+4ATK)，平时靠近英雄攻击
function Battle.TideCallerAct(state, enemy)
    local hero = state.hero
    local target = hero
    if state.scarecrowActive and state.scarecrow and state.scarecrow.hp > 0 then
        target = state.scarecrow
    end

    -- 冷却计时
    enemy.tideCooldown = (enemy.tideCooldown or 0) + 1

    -- 每2回合释放潮涌（对相邻友军ATK+4，持续1回合）
    if enemy.tideCooldown >= 2 then
        enemy.tideCooldown = 0
        local enemies = HexGrid.GetTeamPieces(state.board, "enemy")
        local neighbors = HexGrid.GetNeighbors(enemy.col, enemy.row)
        local buffed = 0
        for _, n in ipairs(neighbors) do
            for _, e in ipairs(enemies) do
                if e ~= enemy and e.hp > 0 and e.col == n.col and e.row == n.row then
                    e.atk = e.atk + 4
                    e._tideBuff = (e._tideBuff or 0) + 4
                    Battle.AddFloatingText(state, e.col, e.row,
                        "🌊+ATK4", {60, 160, 240, 255})
                    Battle.AddVFX(state, "support_buff", {
                        col = e.col, row = e.row, duration = 0.5,
                    })
                    buffed = buffed + 1
                end
            end
        end
        if buffed > 0 then
            Battle.AddLog(state, string.format("🌊 %s 发动潮涌！为%d只友军提升攻击！", enemy.name, buffed))
            return { type = "support", enemy = enemy }
        end
    end

    -- 普通行动：靠近英雄攻击
    local range = enemy.attackRange or 1
    local dist = HexGrid.CubeDistance(enemy.col, enemy.row, target.col, target.row)
    if dist <= range and enemy.atk > 0 then
        local def = target.def or 0
        local actualDmg = Battle.CalcEnemyDmg(enemy.atk, def)
        if target == state.scarecrow then
            target.hp = target.hp - actualDmg
            target.totalDamageAbsorbed = (target.totalDamageAbsorbed or 0) + actualDmg
        else
            Battle.DamageHero(state, actualDmg, enemy)
        end
        return { type = "attack", enemy = enemy, damage = actualDmg }
    end

    local validMoves = HexGrid.FindValidMoves(state.board, enemy.col, enemy.row)
    if #validMoves > 0 then
        local bestMove = Battle.FindClosestMove(validMoves, target.col, target.row)
        if bestMove then
            enemy.animFromCol = enemy.col
            enemy.animFromRow = enemy.row
            enemy.animTimer = 0.3
            enemy.animMaxTimer = 0.3
            enemy.col = bestMove.col
            enemy.row = bestMove.row
            return { type = "move", enemy = enemy }
        end
    end

    return { type = "idle", enemy = enemy }
end

--- 疾梭鱼 AI：每回合最多移动3格后攻击
function Battle.SwiftBarracudaAct(state, enemy)
    local hero = state.hero
    -- 稻草人嘲讽优先
    local target = hero
    if state.scarecrowActive and state.scarecrow and state.scarecrow.hp > 0 then
        target = state.scarecrow
    end

    local steps = enemy.moveSteps or 3
    local range = enemy.attackRange or 1
    local moved = false

    -- 尝试移动 steps 步（每步都重新查合法格）
    for _ = 1, steps do
        local distNow = HexGrid.CubeDistance(enemy.col, enemy.row, target.col, target.row)
        if distNow <= range then break end  -- 已在攻击范围内，不再移动

        local validMoves = HexGrid.FindValidMoves(state.board, enemy.col, enemy.row)
        if #validMoves == 0 then break end

        local bestMove = Battle.FindClosestMove(validMoves, target.col, target.row)
        if not bestMove then break end

        -- 只记录第一步的起始位置用于动画
        if not moved then
            enemy.animFromCol = enemy.col
            enemy.animFromRow = enemy.row
            enemy.animTimer = 0.35
            enemy.animMaxTimer = 0.35
        end
        moved = true
        enemy.col = bestMove.col
        enemy.row = bestMove.row
    end

    -- 移动后检查是否在攻击范围内
    local distAfterMove = HexGrid.CubeDistance(enemy.col, enemy.row, target.col, target.row)
    if distAfterMove <= range and enemy.atk > 0 then
        local targetDef = target.def or 0
        local actualDmg = Battle.CalcEnemyDmg(enemy.atk, targetDef)

        if target == state.scarecrow then
            target.hp = target.hp - actualDmg
            target.totalDamageAbsorbed = (target.totalDamageAbsorbed or 0) + actualDmg
            target.hitCount = (target.hitCount or 0) + 1
            Battle.AddLog(state, string.format("%s 疾冲攻击稻草人！-%d", enemy.name, actualDmg))
            if target.hp <= 0 then
                state.scarecrowActive = false
                state.scarecrow_destroyed = target
            end
        else
            if state.hasShield then
                actualDmg = math.floor(actualDmg / 2)
                state.hasShield = false
                Battle.AddFloatingText(state, hero.col, hero.row, "🛡️挡!", {120, 180, 255, 255})
            elseif state.drainShield and state.drainShield > 0 then
                local absorbed = math.min(state.drainShield, actualDmg)
                actualDmg = actualDmg - absorbed
                state.drainShield = state.drainShield - absorbed
                Battle.AddFloatingText(state, hero.col, hero.row, "🔮盾-" .. absorbed, {200, 80, 200, 255})
                if state.drainShield <= 0 then state.drainShield = nil end
            end
            if (hero._shield or 0) > 0 and actualDmg > 0 then
                local absorbed = math.min(hero._shield, actualDmg)
                actualDmg = actualDmg - absorbed
                hero._shield = hero._shield - absorbed
                Battle.AddFloatingText(state, hero.col, hero.row, "🛡-" .. absorbed, {60, 160, 220, 255})
                if hero._shield <= 0 then
                    hero._shield = 0
                    Battle.AddVFX(state, "shield_break", { col = hero.col, row = hero.row, duration = 0.6 })
                    AM.PlaySFX("shield_break", 0.6)
                    Battle.AddFloatingText(state, hero.col, hero.row, "护盾破碎!", {100, 200, 255, 255})
                end
            end
            hero.hp = hero.hp - actualDmg
            AM.PlaySFX("hero_damage")
            Battle.AddFloatingText(state, hero.col, hero.row, "-" .. actualDmg, {255, 60, 60, 255}, "hit")
            state.screenShake = (state.screenShake or 0) + 0.35
            state.hitFlash = 0.25
        end
        Battle.AddFloatingText(state, enemy.col, enemy.row, "💨疾冲!", {180, 220, 255, 255})
        Battle.AddLog(state, string.format("💨 %s 疾冲3格发动攻击！-%d", enemy.name, actualDmg))
        return { type = "attack", enemy = enemy, damage = actualDmg }
    end

    if moved then
        return { type = "move", enemy = enemy }
    end
    return { type = "idle", enemy = enemy }
end

--- 魅惑水母 AI：普通近战；魅惑效果由 ProcessEnemyTurn 统一处理
function Battle.CharmJellyAct(state, enemy)
    local hero = state.hero
    local target = hero
    if state.scarecrowActive and state.scarecrow and state.scarecrow.hp > 0 then
        target = state.scarecrow
    end

    local range = enemy.attackRange or 1
    local distToTarget = HexGrid.CubeDistance(enemy.col, enemy.row, target.col, target.row)

    -- 在攻击范围内直接攻击
    if distToTarget <= range and enemy.atk > 0 then
        local targetDef = target.def or 0
        local actualDmg = Battle.CalcEnemyDmg(enemy.atk, targetDef)

        if target == state.scarecrow then
            target.hp = target.hp - actualDmg
            target.totalDamageAbsorbed = (target.totalDamageAbsorbed or 0) + actualDmg
            target.hitCount = (target.hitCount or 0) + 1
            Battle.AddLog(state, string.format("%s 攻击稻草人！-%d", enemy.name, actualDmg))
            if target.hp <= 0 then
                state.scarecrowActive = false
                state.scarecrow_destroyed = target
            end
        else
            if state.hasShield then
                actualDmg = math.floor(actualDmg / 2)
                state.hasShield = false
                Battle.AddFloatingText(state, hero.col, hero.row, "🛡️挡!", {120, 180, 255, 255})
            elseif state.drainShield and state.drainShield > 0 then
                local absorbed = math.min(state.drainShield, actualDmg)
                actualDmg = actualDmg - absorbed
                state.drainShield = state.drainShield - absorbed
                Battle.AddFloatingText(state, hero.col, hero.row, "🔮盾-" .. absorbed, {200, 80, 200, 255})
                if state.drainShield <= 0 then state.drainShield = nil end
            end
            if (hero._shield or 0) > 0 and actualDmg > 0 then
                local absorbed = math.min(hero._shield, actualDmg)
                actualDmg = actualDmg - absorbed
                hero._shield = hero._shield - absorbed
                Battle.AddFloatingText(state, hero.col, hero.row, "🛡-" .. absorbed, {60, 160, 220, 255})
                if hero._shield <= 0 then
                    hero._shield = 0
                    Battle.AddVFX(state, "shield_break", { col = hero.col, row = hero.row, duration = 0.6 })
                    AM.PlaySFX("shield_break", 0.6)
                    Battle.AddFloatingText(state, hero.col, hero.row, "护盾破碎!", {100, 200, 255, 255})
                end
            end
            hero.hp = hero.hp - actualDmg
            AM.PlaySFX("hero_damage")
            Battle.AddFloatingText(state, hero.col, hero.row, "-" .. actualDmg, {255, 60, 60, 255}, "hit")
            state.screenShake = (state.screenShake or 0) + 0.35
            state.hitFlash = 0.25
        end
        return { type = "attack", enemy = enemy, damage = actualDmg }
    end

    -- 移向英雄
    local validMoves = HexGrid.FindValidMoves(state.board, enemy.col, enemy.row)
    if #validMoves == 0 then
        return { type = "idle", enemy = enemy }
    end
    local bestMove = Battle.FindClosestMove(validMoves, target.col, target.row)
    if bestMove then
        enemy.animFromCol = enemy.col
        enemy.animFromRow = enemy.row
        enemy.animTimer = 0.3
        enemy.animMaxTimer = 0.3
        enemy.col = bestMove.col
        enemy.row = bestMove.row
        return { type = "move", enemy = enemy }
    end
    return { type = "idle", enemy = enemy }
end

-- ============================================================================
-- 第四章特殊机制敌人 AI
-- ============================================================================

--- 沙暴行者: 蓄力1回合 → 全图攻击
function Battle.SandStriderAct(state, enemy)
    local hero = state.hero
    local target = hero
    if state.scarecrowActive and state.scarecrow and state.scarecrow.hp > 0 then
        target = state.scarecrow
    end

    -- 蓄力状态判断
    if enemy._charged then
        -- 蓄力完成，发动全图攻击
        enemy._charged = false
        enemy._chargeCD = enemy.chargeTurns or 1
        local actualDmg = Battle.CalcEnemyDmg(enemy.atk, target.def or 0)
        -- 应用护盾
        if target == hero then
            if state.hasShield then
                actualDmg = math.floor(actualDmg / 2)
                state.hasShield = false
                Battle.AddFloatingText(state, hero.col, hero.row, "🛡️挡!", {120, 180, 255, 255})
            elseif state.drainShield and state.drainShield > 0 then
                local absorbed = math.min(state.drainShield, actualDmg)
                actualDmg = actualDmg - absorbed
                state.drainShield = state.drainShield - absorbed
                if state.drainShield <= 0 then state.drainShield = nil end
            end
            if (hero._shield or 0) > 0 and actualDmg > 0 then
                local absorbed = math.min(hero._shield, actualDmg)
                actualDmg = actualDmg - absorbed
                hero._shield = hero._shield - absorbed
                if hero._shield <= 0 then
                    hero._shield = 0
                    Battle.AddVFX(state, "shield_break", { col = hero.col, row = hero.row, duration = 0.6 })
                end
            end
            hero.hp = hero.hp - actualDmg
            state.screenShake = (state.screenShake or 0) + 0.4
            state.hitFlash = 0.25
        else
            target.hp = target.hp - actualDmg
            target.totalDamageAbsorbed = (target.totalDamageAbsorbed or 0) + actualDmg
            target.hitCount = (target.hitCount or 0) + 1
            if target.hp <= 0 then state.scarecrowActive = false; state.scarecrow_destroyed = target end
        end
        Battle.AddVFX(state, "sand_strider_blast", {
            fromCol = enemy.col, fromRow = enemy.row,
            toCol = target.col, toRow = target.row,
            duration = 0.7
        })
        AM.PlaySFX("boss_stomp", 0.7)
        Battle.AddFloatingText(state, target.col, target.row, "🌪️-" .. actualDmg, {200, 160, 60, 255}, "hit")
        Battle.AddLog(state, string.format("沙暴行者释放沙暴射线！造成 %d 伤害！", actualDmg))
        return { type = "attack", enemy = enemy, damage = actualDmg }
    end

    -- 开始蓄力
    if (enemy._chargeCD or 0) <= 0 then
        enemy._charged = true
        enemy._chargeCD = 0
        Battle.AddFloatingText(state, enemy.col, enemy.row, "⚡蓄力!", {255, 200, 50, 255})
        Battle.AddLog(state, "沙暴行者开始蓄力——下回合将发动全图攻击！")
        return { type = "charge", enemy = enemy }
    end

    -- 冷却中：向英雄移动
    enemy._chargeCD = (enemy._chargeCD or 0) - 1
    local validMoves = HexGrid.FindValidMoves(state.board, enemy.col, enemy.row)
    if #validMoves > 0 then
        local bestMove = Battle.FindClosestMove(validMoves, target.col, target.row)
        if bestMove then
            enemy.animFromCol = enemy.col
            enemy.animFromRow = enemy.row
            enemy.animTimer = 0.3
            enemy.animMaxTimer = 0.3
            enemy.col = bestMove.col
            enemy.row = bestMove.row
            return { type = "move", enemy = enemy }
        end
    end
    return { type = "idle", enemy = enemy }
end

--- 沙漠响尾蛇: 被攻击/跳过后进入狂怒，下回合双倍伤害
function Battle.SandRattlerAct(state, enemy)
    local hero = state.hero
    local target = hero
    if state.scarecrowActive and state.scarecrow and state.scarecrow.hp > 0 then
        target = state.scarecrow
    end

    local range = enemy.attackRange or 1
    local distToTarget = HexGrid.CubeDistance(enemy.col, enemy.row, target.col, target.row)

    -- 狂怒状态下攻击（双倍伤害）
    if enemy._enraged and distToTarget <= range then
        local multiplier = enemy.counterMultiplier or 2.0
        local rawDmg = math.floor(enemy.atk * multiplier)
        local actualDmg = Battle.CalcEnemyDmg(rawDmg, target.def or 0)
        enemy._enraged = false
        if target == hero then
            if state.hasShield then
                actualDmg = math.floor(actualDmg / 2)
                state.hasShield = false
                Battle.AddFloatingText(state, hero.col, hero.row, "🛡️挡!", {120, 180, 255, 255})
            elseif state.drainShield and state.drainShield > 0 then
                local absorbed = math.min(state.drainShield, actualDmg)
                actualDmg = actualDmg - absorbed
                state.drainShield = state.drainShield - absorbed
                if state.drainShield <= 0 then state.drainShield = nil end
            end
            if (hero._shield or 0) > 0 and actualDmg > 0 then
                local absorbed = math.min(hero._shield, actualDmg)
                actualDmg = actualDmg - absorbed
                hero._shield = hero._shield - absorbed
                if hero._shield <= 0 then
                    hero._shield = 0
                    Battle.AddVFX(state, "shield_break", { col = hero.col, row = hero.row, duration = 0.6 })
                end
            end
            hero.hp = hero.hp - actualDmg
            state.screenShake = (state.screenShake or 0) + 0.5
            state.hitFlash = 0.3
        else
            target.hp = target.hp - actualDmg
            target.totalDamageAbsorbed = (target.totalDamageAbsorbed or 0) + actualDmg
            target.hitCount = (target.hitCount or 0) + 1
            if target.hp <= 0 then state.scarecrowActive = false; state.scarecrow_destroyed = target end
        end
        Battle.AddVFX(state, "rattler_strike", {
            col = target.col, row = target.row, duration = 0.5
        })
        AM.PlaySFX("hero_damage")
        Battle.AddFloatingText(state, target.col, target.row, "🐍狂怒-" .. actualDmg .. "!", {255, 80, 40, 255}, "hit")
        Battle.AddLog(state, string.format("响尾蛇怒击！造成 %d 伤害！", actualDmg))
        return { type = "attack", enemy = enemy, damage = actualDmg }
    end

    -- 非狂怒：普通攻击
    if distToTarget <= range and enemy.atk > 0 then
        local actualDmg = Battle.CalcEnemyDmg(enemy.atk, target.def or 0)
        if target == hero then
            if state.hasShield then
                actualDmg = math.floor(actualDmg / 2)
                state.hasShield = false
            elseif state.drainShield and state.drainShield > 0 then
                local absorbed = math.min(state.drainShield, actualDmg)
                actualDmg = actualDmg - absorbed
                state.drainShield = state.drainShield - absorbed
                if state.drainShield <= 0 then state.drainShield = nil end
            end
            if (hero._shield or 0) > 0 and actualDmg > 0 then
                local absorbed = math.min(hero._shield, actualDmg)
                actualDmg = actualDmg - absorbed
                hero._shield = hero._shield - absorbed
                if hero._shield <= 0 then hero._shield = 0 end
            end
            hero.hp = hero.hp - actualDmg
            state.hitFlash = 0.2
        else
            target.hp = target.hp - actualDmg
            target.totalDamageAbsorbed = (target.totalDamageAbsorbed or 0) + actualDmg
            target.hitCount = (target.hitCount or 0) + 1
            if target.hp <= 0 then state.scarecrowActive = false; state.scarecrow_destroyed = target end
        end
        AM.PlaySFX("hero_damage")
        Battle.AddFloatingText(state, target.col, target.row, "-" .. actualDmg, {255, 60, 60, 255}, "hit")
        return { type = "attack", enemy = enemy, damage = actualDmg }
    end

    -- 移向英雄
    local validMoves = HexGrid.FindValidMoves(state.board, enemy.col, enemy.row)
    if #validMoves > 0 then
        local bestMove = Battle.FindClosestMove(validMoves, target.col, target.row)
        if bestMove then
            enemy.animFromCol = enemy.col
            enemy.animFromRow = enemy.row
            enemy.animTimer = 0.3
            enemy.animMaxTimer = 0.3
            enemy.col = bestMove.col
            enemy.row = bestMove.row
            return { type = "move", enemy = enemy }
        end
    end
    return { type = "idle", enemy = enemy }
end

--- 毒尾蜥: 攻击附带毒DOT
function Battle.VenomLizardAct(state, enemy)
    local hero = state.hero
    local target = hero
    if state.scarecrowActive and state.scarecrow and state.scarecrow.hp > 0 then
        target = state.scarecrow
    end

    local range = enemy.attackRange or 1
    local distToTarget = HexGrid.CubeDistance(enemy.col, enemy.row, target.col, target.row)

    if distToTarget <= range and enemy.atk > 0 then
        local actualDmg = Battle.CalcEnemyDmg(enemy.atk, target.def or 0)
        if target == hero then
            if state.hasShield then
                actualDmg = math.floor(actualDmg / 2)
                state.hasShield = false
                Battle.AddFloatingText(state, hero.col, hero.row, "🛡️挡!", {120, 180, 255, 255})
            elseif state.drainShield and state.drainShield > 0 then
                local absorbed = math.min(state.drainShield, actualDmg)
                actualDmg = actualDmg - absorbed
                state.drainShield = state.drainShield - absorbed
                if state.drainShield <= 0 then state.drainShield = nil end
            end
            if (hero._shield or 0) > 0 and actualDmg > 0 then
                local absorbed = math.min(hero._shield, actualDmg)
                actualDmg = actualDmg - absorbed
                hero._shield = hero._shield - absorbed
                if hero._shield <= 0 then hero._shield = 0 end
            end
            hero.hp = hero.hp - actualDmg
            state.hitFlash = 0.2
            -- 施加毒DOT（叠加/刷新）
            state.poisonDot = {
                damage = enemy.poisonDamage or 5,
                turns = enemy.poisonDuration or 2,
                source = "venom_lizard",
            }
            Battle.AddFloatingText(state, hero.col, hero.row, "🦎毒-" .. actualDmg, {120, 200, 50, 255}, "hit")
            Battle.AddLog(state, string.format("毒尾蜥攻击！-%d 并施加剧毒（每回合%d伤害，%d回合）",
                actualDmg, enemy.poisonDamage or 5, enemy.poisonDuration or 2))
        else
            target.hp = target.hp - actualDmg
            target.totalDamageAbsorbed = (target.totalDamageAbsorbed or 0) + actualDmg
            target.hitCount = (target.hitCount or 0) + 1
            if target.hp <= 0 then state.scarecrowActive = false; state.scarecrow_destroyed = target end
            Battle.AddFloatingText(state, target.col, target.row, "-" .. actualDmg, {255, 60, 60, 255}, "hit")
        end
        AM.PlaySFX("hero_damage")
        state.screenShake = (state.screenShake or 0) + 0.25
        return { type = "attack", enemy = enemy, damage = actualDmg }
    end

    -- 移向英雄
    local validMoves = HexGrid.FindValidMoves(state.board, enemy.col, enemy.row)
    if #validMoves > 0 then
        local bestMove = Battle.FindClosestMove(validMoves, target.col, target.row)
        if bestMove then
            enemy.animFromCol = enemy.col
            enemy.animFromRow = enemy.row
            enemy.animTimer = 0.3
            enemy.animMaxTimer = 0.3
            enemy.col = bestMove.col
            enemy.row = bestMove.row
            return { type = "move", enemy = enemy }
        end
    end
    return { type = "idle", enemy = enemy }
end

--- 从可用移动中找到最接近目标的格子
--- 从可用移动中找到最远离目标的格子（用于逃跑）
--- 从可用移动中找到最接近理想距离的格子（用于远程敌人保持距离）
--- 清除珊瑚祭司上回合给的ATK增益（每轮敌方行动开始时调用）
-- ============================================================================
-- 第三章: 寄居蟹救援系统
-- ============================================================================

--- 检查是否有寄居蟹路径被清通，触发救援
function Battle.CheckCrabRescue(state)
    local board = state.board
    if not board.crabs or #board.crabs == 0 then return end

    for _, crab in ipairs(board.crabs) do
        if not crab.rescued and not crab.animTimer then
            -- 检查从蟹到壳之间的同行路径是否清通
            local pathClear = true
            for c = crab.col + 1, crab.shellCol - 1 do
                if HexGrid.InBounds(c, crab.row) then
                    -- 障碍物
                    if HexGrid.GetObstacleAt(board, c, crab.row) then
                        pathClear = false; break
                    end
                    -- 贝壳（另一只蟹的目标壳也会挡路）
                    if board.shells then
                        for _, s in ipairs(board.shells) do
                            if s.col == c and s.row == crab.row then
                                pathClear = false; break
                            end
                        end
                    end
                    if not pathClear then break end
                    -- 敌人挡路（英雄不算阻挡，螃蟹可以从英雄脚下钻过）
                    local piece = HexGrid.GetPieceAt(board, c, crab.row)
                    if piece and piece.team ~= "hero" then
                        pathClear = false; break
                    end
                end
            end
            if pathClear then
                -- 路径清通！启动奔跑动画（rescueCount 在动画完成时递增，确保WIN判定在蟹真正到家后触发）
                crab.animTimer = 0
                crab.animDuration = 1.2  -- 奔跑1.2秒
                crab.animStartCol = crab.col
                Battle.AddFloatingText(state, crab.col, crab.row,
                    "🦀 回家啦!", {255, 200, 80, 255}, "combo")
                Battle.AddLog(state, string.format("🦀 寄居蟹出发！(%d/%d)",
                    state.rescueCount or 0, state.rescueTarget or 0))
            end
        end
    end
end

--- 更新寄居蟹奔跑动画（在 Update 中调用）
--- 更新寄居蟹奔跑动画，返回是否有蟹刚完成救援
---@return boolean rescued 本帧是否有蟹完成救援
function Battle.UpdateCrabAnimation(state, dt)
    local board = state.board
    if not board.crabs then return false end

    local anyRescued = false
    for _, crab in ipairs(board.crabs) do
        if crab.animTimer and not crab.rescued then
            crab.animTimer = crab.animTimer + dt
            -- 更新蟹的显示位置（线性插值）
            local t = math.min(crab.animTimer / crab.animDuration, 1.0)
            crab.displayCol = crab.animStartCol + (crab.shellCol - crab.animStartCol) * t
            
            if crab.animTimer >= crab.animDuration then
                -- 到达壳！完成救援，此时才计入 rescueCount（确保WIN判定在蟹真正到家后触发）
                state.rescueCount = (state.rescueCount or 0) + 1
                crab.rescued = true
                crab.col = crab.shellCol
                crab.row = crab.shellRow
                crab.displayCol = nil
                crab.animTimer = nil
                anyRescued = true
                -- 蟹到家后壳从棋盘上消失
                if board.shells then
                    for si = #board.shells, 1, -1 do
                        local shell = board.shells[si]
                        if shell.col == crab.shellCol and shell.row == crab.shellRow then
                            table.remove(board.shells, si)
                            break
                        end
                    end
                end
                Battle.AddFloatingText(state, crab.shellCol, crab.shellRow,
                    "🏠 安全了!", {100, 255, 150, 255}, "combo")
                AM.PlaySFX("item_pickup")
                Battle.AddLog(state, string.format("🦀 寄居蟹回家了！(%d/%d)",
                    state.rescueCount, state.rescueTarget or 0))
            end
        end
    end
    return anyRescued
end

-- ============================================================================
-- 胜负检查
-- ============================================================================

function Battle.CheckEndCondition(state)
    -- === WIN 优先判定 ===
    -- 击杀目标达成 → 即使英雄同归于尽也算胜利（同帧击杀+死亡 = 胜利）
    local won = false
    if Battle.IsBossLevel(state.level) then
        -- Boss关胜利条件: 击杀Boss（身体段不算）
        local enemies = HexGrid.GetTeamPieces(state.board, "enemy")
        local bossAlive = false
        for _, e in ipairs(enemies) do
            if e.isBoss and e.hp > 0 and not e.isSegment then bossAlive = true; break end
        end
        if not bossAlive then
            won = true
        end
    else
        local killsMet = (state.kills or 0) >= (state.killTarget or 5)
        -- 第二章: 还需要踩灭所有祭坛
        local chapter = Battle.GetChapterInfo(state.level)
        local altarsMet = true
        if chapter == 2 and state.board.altars and #state.board.altars > 0 then
            local remaining = Battle.GetActiveAltarCount(state.board)
            if remaining > 0 then
                altarsMet = false
            end
        end
        -- 第三章: 还需要完成救援目标
        local rescueMet = true
        if state.rescueTarget and state.rescueTarget > 0 then
            rescueMet = (state.rescueCount or 0) >= state.rescueTarget
        end
        if killsMet and altarsMet and rescueMet then
            won = true
        end
    end
    if won then
        -- 英雄完成目标，即使 HP<=0 也算过关（同归于尽 = 胜利）
        if state.hero.hp <= 0 then
            state.hero.hp = 1  -- 保命1HP，避免死亡动画
            Battle.AddLog(state, "⚔️ 击杀目标达成！英雄险死还生！")
        end
        return "WIN"
    end
    if state.hero.hp <= 0 then
        -- 无敌模式：锁血到1，正常显示伤害但不死亡
        if G.godMode then
            state.hero.hp = 1
            return nil
        end
        -- 黎明使者: 首次致死恢复30%HP（整次冒险仅一次）
        if Skills.Level(state.skills, "dawn_herald") >= 1 and not state.dawnHeraldUsed then
            state.dawnHeraldUsed = true
            local reviveHp = math.max(1, math.floor(state.hero.maxHp * 0.3))
            -- 先保命1HP，标记正在复活（VFX期间不操作）
            state.hero.hp = 1
            state.hero._dawnReviving = true
            state._dawnReviveHp = reviveHp
            Battle.AddFloatingText(state, state.hero.col, state.hero.row,
                "☀️黎明守护!", {255, 220, 80, 255}, "combo")
            Battle.AddVFX(state, "dawn_guard", {
                col = state.hero.col, row = state.hero.row,
                reviveHp = reviveHp,
                duration = 2.0,
                onComplete = function()
                    -- VFX结束时真正回血 + 弹提示
                    state.hero.hp = reviveHp
                    state.hero._dawnReviving = false
                    Battle.AddFloatingText(state, state.hero.col, state.hero.row,
                        "💚+" .. reviveHp, {80, 255, 120, 255}, "combo", 2.0)
                end,
            })
            AM.PlaySFX("shield_ward")
            Battle.AddLog(state, string.format("☀️ 黎明使者发动！免于致命一击，恢复至%dHP！", reviveHp))
            return nil
        end
        return "LOSE"
    end
    return nil
end


end
