-- BattleBoss.lua
-- Boss AI 逻辑（从 Battle.lua 拆分）
-- 包含：BOSS_SKILL_INFO、技能公告、BossAct 派发、各 Boss 的 Act 实现、ApplyBossDamage
-- 外部依赖：BattleUtils（AddVFX/AddFloatingText/AddLog/FindClosestMove）
--          HexGrid（网格操作）
--          Battle（CreatePiece）通过懒加载避免循环依赖
-- ============================================================================

local HexGrid     = require "HexGrid"
local BattleUtils = require "BattleUtils"
local AM          = require "AudioManager"
local Skills      = require "Skills"
local BattleData  = require "BattleData"
local ENEMY_TEMPLATES = BattleData.ENEMY_TEMPLATES

-- 从 BattleUtils 引入本段频繁使用的工具函数（避免每次通过 Battle 转发）
local AddVFX          = BattleUtils.AddVFX
local AddFloatingText = BattleUtils.AddFloatingText
local AddLog          = BattleUtils.AddLog
local FindClosestMove = BattleUtils.FindClosestMove

-- 懒加载 Battle（避免循环依赖：BattleBoss ← Battle ← BattleBoss）
local _Battle
local function B()
    if not _Battle then _Battle = require "Battle" end
    return _Battle
end

local BattleBoss = {}

-- ============================================================================
-- Boss 技能公告系统
-- ============================================================================

--- Boss 技能描述配置（每个技能的名称、图标、说明、颜色）
local BOSS_SKILL_INFO = {
    -- 深渊海妖
    tentacle    = { name = "深渊触手",   icon = "🦑", desc = "在你周围伸出触手，阻断逃跑路线！",       color = {120, 60, 180} },
    whirlpool   = { name = "漩涡牵引",   icon = "🌊", desc = "释放漩涡将你拉向Boss，造成伤害！",       color = {50, 120, 220} },
    shrink      = { name = "深渊收缩",   icon = "🕳️", desc = "棋盘边缘崩塌！可活动范围缩小！",        color = {100, 0, 140} },
    abyss_shield= { name = "深渊护盾",   icon = "🛡️", desc = "Boss展开护盾，必须先击破护盾！",         color = {50, 80, 180} },
    abyss_claw  = { name = "触手重击",   icon = "🦑", desc = "巨大触手猛力横扫，近距离造成重击伤害！",  color = {120, 40, 180} },
    abyss_venom = { name = "深渊喷毒",   icon = "☠️", desc = "喷射深渊毒液，造成伤害并附加持续中毒！",  color = {80, 30, 140} },
    -- 暗影骑士
    shadow_aoe  = { name = "暗影爆发",   icon = "🌑", desc = "释放暗影能量，伤害周围并散布毒雾！",     color = {140, 50, 180} },
    shadow_shield={name = "暗影护盾",    icon = "🛡️", desc = "暗影骑士重新凝聚护盾！",                 color = {100, 60, 160} },
    shadow_summon={name = "暗影召唤",    icon = "👥", desc = "召唤暗影仆从协助作战！",                  color = {130, 50, 160} },
    -- 熔岩领主
    eruption    = { name = "熔岩喷发",   icon = "🌋", desc = "地面喷出岩浆，踩到将持续灼烧！",         color = {255, 80, 0} },
    lava_shield = { name = "岩石护甲",   icon = "🛡️", desc = "熔岩领主重新凝聚岩石护甲！",             color = {180, 100, 30} },
    altar_break_shield = { name = "祭坛破盾", icon = "💥", desc = "所有火焰祭坛熄灭，Boss护盾被击碎！", color = {255, 50, 50} },
    lava_fist   = { name = "熔岩重拳",   icon = "🔥", desc = "举起炽热拳头猛砸英雄，留下灼烧地形！",   color = {255, 60, 0} },
    flame_bolt  = { name = "火焰弹射",   icon = "💥", desc = "精准射出火球直击英雄，周边格子也受波及！", color = {255, 140, 0} },
    -- 珊瑚守卫
    coral_throw     = { name = "珊瑚投掷", icon = "🪸", desc = "抛出巨大珊瑚块砸向英雄，碎片封堵退路！", color = {255, 120,  60} },
    coral_seal      = { name = "珊瑚封印", icon = "🔇", desc = "珊瑚将你重重包围，沉默你使其无法攻击！",  color = {200, 100, 255} },
    tide_surge      = { name = "潮汐冲击", icon = "🌊", desc = "汹涌潮汐将你推离，途经格子均受到伤害！", color = {80,  190, 230} },
    coral_regen     = { name = "珊瑚护甲", icon = "🛡️", desc = "珊瑚护甲重新凝聚，护盾完全恢复！",      color = {255, 180, 210} },
    coral_spike     = { name = "珊瑚刺击", icon = "⚡", desc = "飞速刺出珊瑚长矛，贯穿英雄并留下毒刺！", color = {100, 220, 180} },
    -- 光环技能
    aura_abyss   = { name = "深渊压迫",   icon = "🌊", desc = "深渊之力侵蚀周围，靠近Boss会持续受伤！", color = {60, 120, 200} },
    aura_shadow  = { name = "暗影侵蚀",   icon = "🌑", desc = "暗影能量腐蚀周围，靠近Boss会持续受伤！", color = {180, 60, 200} },
    -- aura_lava 已移除（灼烧光环改为祭坛破盾机制）
    aura_coral   = { name = "珊瑚荆棘",   icon = "🪸", desc = "珊瑚荆棘刺伤周围，靠近Boss会持续受伤！", color = {255, 150, 200} },
    -- 通用
    boss_attack = { name = "Boss攻击",   icon = "⚔️", desc = "Boss发动普通攻击！",                     color = {220, 50, 50} },
}

--- 设置 Boss 下回合意图（用于棋子上方蓄力预告）
---@param boss table Boss 棋子对象
---@param skillKey string|nil 技能标识，nil 表示普通攻击/移动
function BattleBoss.SetBossNextSkill(boss, skillKey)
    local info = skillKey and BOSS_SKILL_INFO[skillKey]
    if info then
        boss.nextSkillKey   = skillKey
        boss.nextSkillIcon  = info.icon
        boss.nextSkillColor = info.color or {200, 50, 50}
    else
        boss.nextSkillKey   = nil
        boss.nextSkillIcon  = nil
        boss.nextSkillColor = nil
    end
end

--- 预测深渊海妖下回合意图（行动后调用）
local function PredictNextSkill_AbyssKraken(state, boss)
    local hero = state.hero
    local dist = HexGrid.CubeDistance(boss.col, boss.row, hero.col, hero.row)
    local clawNext      = math.max(0, (boss.abyssClawCooldown  or 0) - 1)
    local venomNext     = math.max(0, (boss.abyssVenomCooldown or 0) - 1)
    local tentacleNext  = math.max(0, (boss.tentacleCooldown   or 0) - 1)
    local whirlpoolNext = math.max(0, (boss.whirlpoolCooldown  or 0) - 1)
    local shrinkNext    = math.max(0, (boss.shrinkCooldown     or 0) - 1)
    if clawNext <= 0 and dist <= 2 then
        BattleBoss.SetBossNextSkill(boss, "abyss_claw")
    elseif venomNext <= 0 and dist <= 5 then
        BattleBoss.SetBossNextSkill(boss, "abyss_venom")
    elseif tentacleNext <= 0 then
        BattleBoss.SetBossNextSkill(boss, "tentacle")
    elseif whirlpoolNext <= 0 and dist > 1 then
        BattleBoss.SetBossNextSkill(boss, "whirlpool")
    elseif shrinkNext <= 0 and boss.enraged and (boss.shrinkCount or 0) < 2 then
        BattleBoss.SetBossNextSkill(boss, "shrink")
    else
        BattleBoss.SetBossNextSkill(boss, nil)
    end
end

--- 预测熔岩领主下回合意图（行动后调用）
local function PredictNextSkill_LavaLord(state, boss)
    local hero = state.hero
    local dist = HexGrid.CubeDistance(boss.col, boss.row, hero.col, hero.row)
    local fistNext       = math.max(0, (boss.lavaFistCooldown    or 0) - 1)
    local boltNext       = math.max(0, (boss.flameBoltCooldown   or 0) - 1)
    local eruptNext      = math.max(0, (boss.eruptionCooldown    or 0) - 1)
    local shieldRegenNext= math.max(0, (boss.shieldRegenCooldown or 0) - 1)
    if fistNext <= 0 and dist <= 2 then
        BattleBoss.SetBossNextSkill(boss, "lava_fist")
    elseif boltNext <= 0 and dist <= 6 then
        BattleBoss.SetBossNextSkill(boss, "flame_bolt")
    elseif eruptNext <= 0 then
        BattleBoss.SetBossNextSkill(boss, "eruption")
    elseif shieldRegenNext <= 0 and (boss.shieldHp or 0) <= 0 then
        BattleBoss.SetBossNextSkill(boss, "lava_shield")
    else
        BattleBoss.SetBossNextSkill(boss, nil)
    end
end

--- 预测珊瑚守卫下回合意图（行动后调用）
local function PredictNextSkill_CoralGuardian(state, boss)
    local hero = state.hero
    local dist = HexGrid.CubeDistance(boss.col, boss.row, hero.col, hero.row)
    local shieldNext     = math.max(0, (boss.shieldRegenCooldown or 0) - 1)
    local spikeNext      = math.max(0, (boss.coralSpikeCooldown  or 0) - 1)
    local tideNext       = math.max(0, (boss.tideSurgeCooldown   or 0) - 1)
    local throwNext      = math.max(0, (boss.coralThrowCooldown  or 0) - 1)
    local sealNext       = math.max(0, (boss.coralSealCooldown   or 0) - 1)
    if shieldNext <= 0 and (not boss.shieldHp or boss.shieldHp <= 0) then
        BattleBoss.SetBossNextSkill(boss, "coral_regen")
    elseif spikeNext <= 0 and dist <= 2 then
        BattleBoss.SetBossNextSkill(boss, "coral_spike")
    elseif tideNext <= 0 and dist <= 4 then
        BattleBoss.SetBossNextSkill(boss, "tide_surge")
    elseif throwNext <= 0 then
        BattleBoss.SetBossNextSkill(boss, "coral_throw")
    elseif sealNext <= 0 then
        BattleBoss.SetBossNextSkill(boss, "coral_seal")
    else
        BattleBoss.SetBossNextSkill(boss, nil)
    end
end

--- 添加 Boss 技能全屏公告
---@param state table 战斗状态
---@param skillKey string 技能标识（对应 BOSS_SKILL_INFO 的 key）
---@param bossName string|nil Boss 名称（可选，用于显示）
function BattleBoss.AddBossSkillAnnounce(state, skillKey, bossName)
    local info = BOSS_SKILL_INFO[skillKey]
    if not info then return end
    state.bossSkillAnnounce = {
        skillName = info.name,
        icon = info.icon,
        desc = info.desc,
        color = info.color or {200, 50, 50},
        bossName = bossName or "",
        timer = 1.8,
        maxTimer = 1.8,
    }
end

-- ============================================================================
-- Boss 特殊行动系统 (暗影骑士)
-- ============================================================================

--- Boss行动入口（在EnemyAct中调用）
--- Boss行动入口（分发到具体Boss）
function BattleBoss.BossAct(state, boss)
    local bt = boss.bossType or "abyss_kraken"
    if bt == "lava_lord" then
        return BattleBoss.BossAct_LavaLord(state, boss)
    elseif bt == "abyss_kraken" then
        return BattleBoss.BossAct_AbyssKraken(state, boss)
    elseif bt == "coral_guardian" then
        return BattleBoss.BossAct_CoralGuardian(state, boss)
    elseif bt == "sand_worm" then
        return BattleBoss.BossAct_SandWorm(state, boss)
    else
        return BattleBoss.BossAct_ShadowKnight(state, boss)
    end
end

--- Boss通用: 普通攻击英雄
function BattleBoss.BossBasicAttack(state, boss)
    local hero = state.hero

    -- === 稻草人嘲讽优先：Boss也受嘲讽影响 ===
    local target = hero
    local targetIsScarecrow = false
    if state.scarecrowActive and state.scarecrow and state.scarecrow.hp > 0 then
        target = state.scarecrow
        targetIsScarecrow = true
    end

    local distToTarget = HexGrid.CubeDistance(boss.col, boss.row, target.col, target.row)
    if distToTarget > (boss.attackRange or 2) then return nil end

    local targetDef = target.def or 0
    local actualDmg = math.max(1, boss.atk - targetDef)

    if targetIsScarecrow then
        -- Boss攻击稻草人（单条不显示，ProcessEnemyTurn 汇总）
        target.hp = target.hp - actualDmg
        target.totalDamageAbsorbed = (target.totalDamageAbsorbed or 0) + actualDmg
        target.hitCount = (target.hitCount or 0) + 1
        AddLog(state, string.format("%s 攻击了稻草人！稻草人替你承受了 %d 伤害", boss.name, actualDmg))
        if target.hp <= 0 then
            state.scarecrowActive = false
            state.scarecrow_destroyed = target
        end
    else
        -- Boss攻击英雄（原逻辑）
        if state.hasShield then
            actualDmg = math.floor(actualDmg / 2)
            state.hasShield = false
            AddFloatingText(state, hero.col, hero.row,
                "🛡️挡!", {120, 180, 255, 255})
        elseif state.drainShield and state.drainShield > 0 then
            local absorbed = math.min(state.drainShield, actualDmg)
            actualDmg = actualDmg - absorbed
            state.drainShield = state.drainShield - absorbed
            AddFloatingText(state, hero.col, hero.row,
                "🔮盾-" .. absorbed, {200, 80, 200, 255})
            if state.drainShield <= 0 then state.drainShield = nil end
        end
        hero.hp = hero.hp - actualDmg
        AM.PlaySFX("hero_damage")
        AddFloatingText(state, hero.col, hero.row,
            "-" .. actualDmg, {255, 60, 60, 255}, "hit")
        state.screenShake = (state.screenShake or 0) + 0.35
        state.hitFlash = 0.25
        AddLog(state, string.format("%s 攻击！伤害 %d", boss.name, actualDmg))
    end

    AddVFX(state, "ranged_attack", {
        fromCol = boss.col, fromRow = boss.row,
        toCol = target.col, toRow = target.row,
        duration = 0.4, enemyType = boss.enemyType,
    })

    -- 荆棘护甲反弹（仅攻击英雄时）
    if not targetIsScarecrow then
        local thornLv = Skills.Level(state.skills, "thorns")
        if thornLv >= 1 then
            local thornsDmg = math.floor(boss.atk * (20 + thornLv * 8) / 100)
            if thornsDmg > 0 then
                BattleBoss.ApplyBossDamage(state, boss, thornsDmg)
                AM.PlaySFX("thorns_reflect", 0.6)
                AddFloatingText(state, boss.col, boss.row,
                    "-" .. thornsDmg .. "🛡️反弹", {200, 150, 255, 255})
            end
        end
    end

    return { type = "attack", enemy = boss, damage = actualDmg }
end

--- Boss通用: 向目标移动（稻草人嘲讽时朝稻草人移动）
function BattleBoss.BossMoveToHero(state, boss)
    local hero = state.hero
    -- 嘲讽目标优先
    local targetCol, targetRow = hero.col, hero.row
    if state.scarecrowActive and state.scarecrow and state.scarecrow.hp > 0 then
        targetCol, targetRow = state.scarecrow.col, state.scarecrow.row
    end
    local validMoves = HexGrid.FindValidMoves(state.board, boss.col, boss.row)
    if #validMoves > 0 then
        local bestMove = FindClosestMove(validMoves, targetCol, targetRow)
        if bestMove then
            boss.animFromCol = boss.col
            boss.animFromRow = boss.row
            boss.animTimer = 0.3
            boss.animMaxTimer = 0.3
            boss.col = bestMove.col
            boss.row = bestMove.row
            return { type = "move", enemy = boss }
        end
    end
    return { type = "idle", enemy = boss }
end

--- Boss通用: 狂暴检查
function BattleBoss.BossEnrageCheck(state, boss, bossLabel)
    if not boss.enraged and boss.hp <= boss.maxHp * 0.5 then
        boss.enraged = true
        boss.phase = 2
        boss.atk = math.floor(boss.atk * 1.3)
        AddFloatingText(state, boss.col, boss.row,
            "💀 狂暴!", {255, 50, 50, 255}, "combo")
        AddLog(state, "⚠️ " .. bossLabel .. "进入狂暴状态！ATK提升！")
        local bossColors = {
            shadow_knight = {180, 30, 50}, abyss_kraken = {100, 20, 160}, lava_lord = {255, 100, 0}, coral_guardian = {255, 120, 180},
        }
        AddVFX(state, "boss_enrage", {
            col = boss.col, row = boss.row, duration = 1.0,
            bossColor = bossColors[boss.enemyType] or {255, 50, 50},
        })
        -- 狂暴二阶段红色警告横幅
        state.bossEnrageAnnounce = {
            subtitle = bossLabel .. "进入狂暴状态！攻击力大幅提升！",
            timer = 2.5,
            maxTimer = 2.5,
        }
        boss.shieldHp = boss.shieldMax or 0
        if boss.shieldMax and boss.shieldMax > 0 then
            AddFloatingText(state, boss.col, boss.row,
                "🛡️+" .. boss.shieldMax, {100, 180, 255, 255})
        end
    end
end

-- ============================================================================
-- 暗影骑士 Boss (第一章)
-- ============================================================================
function BattleBoss.BossAct_ShadowKnight(state, boss)
    local hero = state.hero
    BattleBoss.BossEnrageCheck(state, boss, "暗影骑士")

    -- 冷却递减
    if boss.summonCooldown > 0 then boss.summonCooldown = boss.summonCooldown - 1 end
    if boss.aoeCooldown > 0 then boss.aoeCooldown = boss.aoeCooldown - 1 end

    -- 技能1: 护盾再生（狂暴时）
    if boss.enraged and (boss.shieldHp or 0) <= 0 and boss.aoeCooldown <= 0 then
        boss.shieldHp = boss.shieldMax
        boss.aoeCooldown = 4
        AddFloatingText(state, boss.col, boss.row,
            "🛡️护盾再生!", {100, 180, 255, 255})
        BattleBoss.AddBossSkillAnnounce(state, "shadow_shield", boss.name)
        AddLog(state, "暗影骑士重新展开护盾！")
        AddVFX(state, "ward_place", { col = boss.col, row = boss.row, duration = 0.6 })
        return { type = "boss_shield", enemy = boss }
    end

    -- 技能2: 召唤暗影仆从
    local minionCount = 0
    local allEnemies = HexGrid.GetTeamPieces(state.board, "enemy")
    for _, e in ipairs(allEnemies) do
        if e ~= boss and e.hp > 0 then minionCount = minionCount + 1 end
    end
    if boss.summonCooldown <= 0 and minionCount < 2 then
        boss.summonCooldown = boss.enraged and 4 or 5
        local summonCount = boss.enraged and 2 or 1
        local neighbors = HexGrid.GetNeighbors(boss.col, boss.row)
        local spawned = 0
        for _, n in ipairs(neighbors) do
            if spawned >= summonCount then break end
            if HexGrid.InBounds(n.col, n.row)
               and not HexGrid.IsBlocked(state.board, n.col, n.row)
               and not HexGrid.GetPieceAt(state.board, n.col, n.row) then
                local minion = B().CreatePiece(ENEMY_TEMPLATES["slime"], n.col, n.row)
                minion.hp = 20; minion.maxHp = 20; minion.atk = 5
                minion.name = "暗影仆从"; minion.enemyType = "slime"
                HexGrid.AddPiece(state.board, minion)
                AddFloatingText(state, n.col, n.row, "👻召唤!", {180, 100, 255, 255})
                spawned = spawned + 1
            end
        end
        if spawned > 0 then
            BattleBoss.AddBossSkillAnnounce(state, "shadow_summon", boss.name)
            AddLog(state, string.format("暗影骑士召唤了 %d 个暗影仆从！", spawned))
            AddVFX(state, "poison_puff", { col = boss.col, row = boss.row, duration = 0.7 })
            return { type = "boss_summon", enemy = boss, count = spawned }
        end
    end

    -- 技能3: 暗影冲击 AOE
    local distToHero = HexGrid.CubeDistance(boss.col, boss.row, hero.col, hero.row)
    if boss.aoeCooldown <= 0 and distToHero <= 4 then
        boss.aoeCooldown = boss.enraged and 2 or 3
        local aoeDmg = boss.enraged and 15 or 10
        local hitCells = { { col = hero.col, row = hero.row } }
        local neighbors = HexGrid.GetNeighbors(hero.col, hero.row)
        for _, n in ipairs(neighbors) do
            if HexGrid.InBounds(n.col, n.row) then hitCells[#hitCells + 1] = n end
        end
        local actualDmg = math.max(1, math.floor(aoeDmg - (hero.def or 0)))
        if state.hasShield then
            actualDmg = math.floor(actualDmg / 2); state.hasShield = false
            AddFloatingText(state, hero.col, hero.row,
                "🛡️挡!", {120, 180, 255, 255})
        elseif state.drainShield and state.drainShield > 0 then
            local absorbed = math.min(state.drainShield, actualDmg)
            actualDmg = actualDmg - absorbed
            state.drainShield = state.drainShield - absorbed
            AddFloatingText(state, hero.col, hero.row,
                "🔮盾-" .. absorbed, {200, 80, 200, 255})
            if state.drainShield <= 0 then state.drainShield = nil end
        end
        hero.hp = hero.hp - actualDmg
        AddFloatingText(state, hero.col, hero.row,
            "-" .. actualDmg .. "🌑", {180, 60, 200, 255}, "hit")
        state.screenShake = (state.screenShake or 0) + 0.5
        for _, cell in ipairs(hitCells) do
            if math.random() < 0.4 then HexGrid.AddPoison(state.board, cell.col, cell.row, 2) end
        end
        BattleBoss.AddBossSkillAnnounce(state, "shadow_aoe", boss.name)
        AddLog(state, string.format("🌑 暗影冲击！造成 %d 伤害！", actualDmg))
        AddVFX(state, "shockwave", { col = hero.col, row = hero.row, duration = 0.6 })
        return { type = "boss_aoe", enemy = boss, damage = actualDmg }
    end

    -- 普通攻击/移动
    local atk = BattleBoss.BossBasicAttack(state, boss)
    if atk then return atk end
    return BattleBoss.BossMoveToHero(state, boss)
end

-- ============================================================================
-- 熔岩领主 Boss (第三章)
-- ============================================================================
function BattleBoss.BossAct_LavaLord(state, boss)
    local hero = state.hero
    BattleBoss.BossEnrageCheck(state, boss, "熔岩领主")

    -- 冷却递减
    if boss.eruptionCooldown    and boss.eruptionCooldown    > 0 then boss.eruptionCooldown    = boss.eruptionCooldown    - 1 end
    if boss.shieldRegenCooldown and boss.shieldRegenCooldown > 0 then boss.shieldRegenCooldown = boss.shieldRegenCooldown - 1 end
    if boss.lavaFistCooldown    and boss.lavaFistCooldown    > 0 then boss.lavaFistCooldown    = boss.lavaFistCooldown    - 1 end
    if boss.flameBoltCooldown   and boss.flameBoltCooldown   > 0 then boss.flameBoltCooldown   = boss.flameBoltCooldown   - 1 end

    local distToHero = HexGrid.CubeDistance(boss.col, boss.row, hero.col, hero.row)

    -- 技能0a: 熔岩重拳 — 近身重击+留下熔岩（距离<=2，每2回合，狂暴1回合）
    if (boss.lavaFistCooldown or 0) <= 0 and distToHero <= 2 then
        boss.lavaFistCooldown = boss.enraged and 1 or 2
        local fistDmg = boss.enraged and math.floor(boss.atk * 3.0) or math.floor(boss.atk * 2.4)
        hero.hp = hero.hp - fistDmg
        AddFloatingText(state, hero.col, hero.row, "🔥-" .. fistDmg .. "重拳!", {255, 80, 0, 255}, "hit")
        -- 在英雄脚下留下熔岩
        HexGrid.AddPoison(state.board, hero.col, hero.row, 99)
        local pt = HexGrid.GetPoisonAt(state.board, hero.col, hero.row)
        if pt then pt.damage = 8; pt.isLava = true end
        BattleBoss.AddBossSkillAnnounce(state, "lava_fist", boss.name)
        AddVFX(state, "lava_fist",    { col = hero.col,  row = hero.row,  duration = 1.2 })
        AddVFX(state, "lava_eruption",{ col = hero.col,  row = hero.row,  duration = 0.8, delay = 0.5 })
        boss.skillAnimTimer    = 0.65
        boss.skillAnimDuration = 0.65
        boss.skillAnimType     = "fist"
        state.screenShake = (state.screenShake or 0) + 0.7
        AM.PlaySFX("lava_fist_smash", 1.0)
        AddLog(state, string.format("熔岩领主熔岩重拳！造成%d点伤害并留下灼烧地形！", fistDmg))
        return { type = "boss_lava_fist", enemy = boss }
    end

    -- 技能0b: 火焰弹射 — 精准打击英雄位置+溅射（距离<=6，每3回合，狂暴2回合）
    if (boss.flameBoltCooldown or 0) <= 0 and distToHero <= 6 then
        boss.flameBoltCooldown = boss.enraged and 2 or 3
        local boltDmg = boss.enraged and math.floor(boss.atk * 1.8) or math.floor(boss.atk * 1.4)
        local splashDmg = math.floor(boltDmg * 0.5)
        -- 直击英雄
        hero.hp = hero.hp - boltDmg
        AddFloatingText(state, hero.col, hero.row, "💥-" .. boltDmg .. "火球!", {255, 160, 0, 255}, "hit")
        -- 溅射：英雄邻格留下熔岩
        local neighbors = HexGrid.GetNeighbors(hero.col, hero.row)
        local splashCount = 0
        for _, nb in ipairs(neighbors) do
            if HexGrid.InBounds(nb.col, nb.row) and not HexGrid.IsBlocked(state.board, nb.col, nb.row) then
                HexGrid.AddPoison(state.board, nb.col, nb.row, 99)
                local nbpt = HexGrid.GetPoisonAt(state.board, nb.col, nb.row)
                if nbpt then nbpt.damage = 6; nbpt.isLava = true end
                AddVFX(state, "lava_eruption", { col = nb.col, row = nb.row, duration = 0.7, delay = 0.1 })
                splashCount = splashCount + 1
                if splashCount >= 3 then break end
            end
        end
        BattleBoss.AddBossSkillAnnounce(state, "flame_bolt", boss.name)
        AddVFX(state, "flame_bolt", { col = hero.col, row = hero.row, duration = 0.9 })
        boss.skillAnimTimer    = 0.5
        boss.skillAnimDuration = 0.5
        boss.skillAnimType     = "bolt"
        state.screenShake = (state.screenShake or 0) + 0.4
        AM.PlaySFX("flame_bolt_impact", 1.0)
        AddLog(state, string.format("熔岩领主火焰弹射！直击英雄造成%d点伤害，溅射%d格熔岩！", boltDmg, splashCount))
        return { type = "boss_flame_bolt", enemy = boss }
    end

    -- 技能1: 熔岩喷发 — 放置熔岩地形（支持单格和多格连片）（每3回合，狂暴1回合）
    if (boss.eruptionCooldown or 0) <= 0 then
        boss.eruptionCooldown = boss.enraged and 1 or 3
        -- 决定熔岩区域数（每个区域可能是1-3格的连片）
        local clusterCount = boss.enraged and 4 or 3
        local allCells = HexGrid.GetAllValidCells(state.board)
        if #allCells == 0 then
            -- 棋盘无有效格，跳过熔岩喷发技能
            return { type = "skill", skillName = "lava_burst_skip", enemy = boss }
        end

        -- 辅助：判断格子是否可放熔岩（不在Boss/英雄位置）
        local function canPlaceLava(c, r)
            if c == boss.col and r == boss.row then return false end
            if c == hero.col and r == hero.row then return false end
            return HexGrid.InBounds(c, r)
        end

        -- 辅助：在指定格放置熔岩并添加VFX
        local erupted = 0
        local function placeLava(c, r, delay)
            HexGrid.AddPoison(state.board, c, r, 99)
            local pt = HexGrid.GetPoisonAt(state.board, c, r)
            if pt then pt.damage = 8; pt.isLava = true end
            AddVFX(state, "lava_eruption", {
                col = c, row = r, duration = 1.2,
                delay = delay,
            })
            local d = HexGrid.CubeDistance(c, r, hero.col, hero.row)
            if d <= 1 then
                local eruptDmg = boss.enraged and 18 or 10
                hero.hp = hero.hp - eruptDmg
                AddFloatingText(state, hero.col, hero.row,
                    "-" .. eruptDmg .. "🌋", {255, 100, 0, 255}, "hit")
            end
            erupted = erupted + 1
        end

        -- 放置多个熔岩区域
        local placed = {}  -- 已放置的格子集合，key = "col,row"
        for ci = 1, clusterCount do
            -- 随机选一个中心格
            local center = nil
            for _ = 1, 20 do
                local cell = allCells[math.random(1, #allCells)]
                local key = cell.col .. "," .. cell.row
                if canPlaceLava(cell.col, cell.row) and not placed[key] then
                    center = cell
                    break
                end
            end
            if center then
                -- 放置中心格
                local key = center.col .. "," .. center.row
                placed[key] = true
                placeLava(center.col, center.row, (ci - 1) * 0.3)

                -- 随机决定扩展大小：40%单格，35%双格，25%三格
                local roll = math.random(1, 100)
                local expandCount = roll <= 40 and 0 or (roll <= 75 and 1 or 2)
                if boss.enraged then
                    -- 狂暴时更容易出大片：20%单格，35%双格，45%三格
                    expandCount = roll <= 20 and 0 or (roll <= 55 and 1 or 2)
                end

                -- 扩展相邻格
                if expandCount > 0 then
                    local neighbors = HexGrid.GetNeighbors(center.col, center.row)
                    -- 随机打乱邻居顺序
                    for i = #neighbors, 2, -1 do
                        local j = math.random(1, i)
                        neighbors[i], neighbors[j] = neighbors[j], neighbors[i]
                    end
                    local expanded = 0
                    for _, nb in ipairs(neighbors) do
                        if expanded >= expandCount then break end
                        local nk = nb.col .. "," .. nb.row
                        if canPlaceLava(nb.col, nb.row) and not placed[nk] then
                            placed[nk] = true
                            placeLava(nb.col, nb.row, (ci - 1) * 0.3 + (expanded + 1) * 0.1)
                            expanded = expanded + 1
                        end
                    end
                end
            end
        end

        if erupted > 0 then
            BattleBoss.AddBossSkillAnnounce(state, "eruption", boss.name)
            AddFloatingText(state, boss.col, boss.row,
                "🌋熔岩喷发!", {255, 80, 0, 255}, "combo")
            AddLog(state, string.format("熔岩领主引发熔岩喷发！%d处新熔岩涌出！", erupted))
            -- Boss位置冲击波 + 强震屏
            AddVFX(state, "shockwave", { col = boss.col, row = boss.row, duration = 0.8 })
            state.screenShake = (state.screenShake or 0) + 0.5
            AM.PlaySFX("lava_eruption", 1.0)  -- 熔岩喷发专属音效
            return { type = "boss_eruption", enemy = boss }
        end
    end

    -- 护盾再生（护盾被击碎后，冷却结束时重新生成）
    if (boss.shieldHp or 0) <= 0 and (boss.shieldRegenCooldown or 0) <= 0 then
        -- 非狂暴恢复40护盾（4回合冷却），狂暴恢复满护盾（2回合冷却）
        local regenAmount = boss.enraged and (boss.shieldMax or 70) or 40
        boss.shieldRegenCooldown = boss.enraged and 2 or 4
        BattleBoss.AddBossSkillAnnounce(state, "lava_shield", boss.name)
        boss.shieldHp = regenAmount
        AddFloatingText(state, boss.col, boss.row,
            "🛡️岩甲再生!", {180, 100, 50, 255}, "combo")
        AddLog(state, "熔岩领主的岩石护甲重新凝聚！")
        -- 岩甲再生视觉特效：护盾增益 + 冲击波
        AddVFX(state, "shield_gain", { col = boss.col, row = boss.row, duration = 1.0 })
        AddVFX(state, "lava_shield_regen", { col = boss.col, row = boss.row, duration = 1.5 })
        state.screenShake = (state.screenShake or 0) + 0.4
        AM.PlaySFX("lava_shield_regen", 0.8)  -- 岩甲再生专属音效
        return { type = "boss_shield", enemy = boss }
    end

    -- 普通攻击/移动
    PredictNextSkill_LavaLord(state, boss)
    local atk = BattleBoss.BossBasicAttack(state, boss)
    if atk then return atk end
    return BattleBoss.BossMoveToHero(state, boss)
end

-- ============================================================================
-- 深渊海妖 Boss (第二章)
-- ============================================================================
function BattleBoss.BossAct_AbyssKraken(state, boss)
    local hero = state.hero
    BattleBoss.BossEnrageCheck(state, boss, "深渊海妖")

    -- 冷却递减
    if boss.tentacleCooldown and boss.tentacleCooldown > 0 then boss.tentacleCooldown = boss.tentacleCooldown - 1 end
    if boss.whirlpoolCooldown and boss.whirlpoolCooldown > 0 then boss.whirlpoolCooldown = boss.whirlpoolCooldown - 1 end
    if boss.shrinkCooldown    and boss.shrinkCooldown    > 0 then boss.shrinkCooldown    = boss.shrinkCooldown    - 1 end
    if boss.abyssClawCooldown and boss.abyssClawCooldown > 0 then boss.abyssClawCooldown = boss.abyssClawCooldown - 1 end
    if boss.abyssVenomCooldown and boss.abyssVenomCooldown > 0 then boss.abyssVenomCooldown = boss.abyssVenomCooldown - 1 end

    local distToHero = HexGrid.CubeDistance(boss.col, boss.row, hero.col, hero.row)

    -- 技能0a: 触手重击 — 近距离重击（距离<=2）
    if (boss.abyssClawCooldown or 0) <= 0 and distToHero <= 2 then
        boss.abyssClawCooldown = boss.enraged and 1 or 2
        local clawDmg = boss.enraged and math.floor(boss.atk * 2.8) or math.floor(boss.atk * 2.2)
        hero.hp = hero.hp - clawDmg
        AddFloatingText(state, hero.col, hero.row, "🦑-" .. clawDmg .. "重击!", {150, 50, 220, 255}, "hit")
        BattleBoss.AddBossSkillAnnounce(state, "abyss_claw", boss.name)
        AddVFX(state, "abyss_claw", { col = hero.col, row = hero.row, duration = 0.7 })
        boss.skillAnimTimer    = 0.55
        boss.skillAnimDuration = 0.55
        boss.skillAnimType     = "claw"
        state.screenShake = (state.screenShake or 0) + 0.5
        AM.PlaySFX("abyss_claw_hit", 1.0)
        AddLog(state, string.format("深渊海妖触手重击！造成%d点伤害！", clawDmg))
        return { type = "boss_claw", enemy = boss }
    end

    -- 技能0b: 深渊喷毒 — 中距离毒液攻击（距离<=5，每3回合，狂暴2回合）
    if (boss.abyssVenomCooldown or 0) <= 0 and distToHero <= 5 then
        boss.abyssVenomCooldown = boss.enraged and 2 or 3
        local venomDmg = boss.enraged and math.floor(boss.atk * 1.6) or math.floor(boss.atk * 1.2)
        local poisonTurns = boss.enraged and 4 or 3
        local poisonDmg = boss.enraged and 8 or 5
        hero.hp = hero.hp - venomDmg
        hero.poisonTurns = (hero.poisonTurns or 0) + poisonTurns
        hero.poisonDmg   = math.max(hero.poisonDmg or 0, poisonDmg)
        AddFloatingText(state, hero.col, hero.row, "☠️-" .. venomDmg .. "中毒!", {100, 20, 160, 255}, "hit")
        AddFloatingText(state, hero.col, hero.row, "🤢中毒" .. poisonTurns .. "回合", {120, 50, 180, 255})
        BattleBoss.AddBossSkillAnnounce(state, "abyss_venom", boss.name)
        AddVFX(state, "abyss_venom", { col = hero.col, row = hero.row, duration = 1.0 })
        boss.skillAnimTimer    = 0.7
        boss.skillAnimDuration = 0.7
        boss.skillAnimType     = "venom"
        state.screenShake = (state.screenShake or 0) + 0.3
        AM.PlaySFX("abyss_venom_spray", 1.0)
        AddLog(state, string.format("深渊海妖喷射毒液！造成%d点伤害并附加%d回合中毒！", venomDmg, poisonTurns))
        return { type = "boss_venom", enemy = boss }
    end

    -- 技能1: 触手障碍 — 在棋盘随机位置放置触手（每3回合，狂暴2回合）
    if (boss.tentacleCooldown or 0) <= 0 then
        boss.tentacleCooldown = boss.enraged and 2 or 3
        local tentacleCount = boss.enraged and 5 or 3
        -- 收集棋盘上所有空位（排除英雄和Boss所在格）
        local candidates = {}
        for r = 1, state.board.rows do
            for c = 1, state.board.cols do
                if HexGrid.InBounds(c, r)
                   and not HexGrid.IsBlocked(state.board, c, r)
                   and not HexGrid.GetPieceAt(state.board, c, r)
                   and not (c == hero.col and r == hero.row) then
                    candidates[#candidates + 1] = { col = c, row = r }
                end
            end
        end
        -- Fisher-Yates 洗牌
        for i = #candidates, 2, -1 do
            local j = math.random(1, i)
            candidates[i], candidates[j] = candidates[j], candidates[i]
        end
        local placed = 0
        for _, pos in ipairs(candidates) do
            if placed >= tentacleCount then break end
            HexGrid.AddObstacle(state.board, pos.col, pos.row)
            -- 标记为触手障碍（普通3回合，狂暴4回合）
            local tentacleDuration = boss.enraged and 4 or 3
            local obs = state.board.obstacles
            for _, o in ipairs(obs) do
                if o.col == pos.col and o.row == pos.row then
                    o.isTentacle = true
                    o.turns = tentacleDuration
                    break
                end
            end
            AddFloatingText(state, pos.col, pos.row,
                "🦑触手!", {100, 50, 150, 255})
            placed = placed + 1
        end
        if placed > 0 then
            BattleBoss.AddBossSkillAnnounce(state, "tentacle", boss.name)
            AddLog(state, string.format("深渊海妖伸出%d条触手阻断路线！", placed))
            AddVFX(state, "poison_puff", { col = hero.col, row = hero.row, duration = 0.6 })
            return { type = "boss_tentacle", enemy = boss }
        end
    end

    -- 技能2: 漩涡牵引 — 将英雄拉向Boss 1-2格（每5回合，狂暴3回合）
    if (boss.whirlpoolCooldown or 0) <= 0 and distToHero > 1 then
        boss.whirlpoolCooldown = boss.enraged and 3 or 5
        -- 计算英雄朝Boss方向移动1格
        local hx, hy, hz = HexGrid.OffsetToCube(hero.col, hero.row)
        local bx, by, bz = HexGrid.OffsetToCube(boss.col, boss.row)
        local dx = bx - hx
        local dy = by - hy
        local dz = bz - hz
        -- 归一化到最近的方向
        local maxD = math.max(math.abs(dx), math.abs(dy), math.abs(dz))
        if maxD > 0 then
            dx = math.floor(dx / maxD + 0.5)
            dy = math.floor(dy / maxD + 0.5)
            dz = math.floor(dz / maxD + 0.5)
            -- 确保 dx+dy+dz==0
            if dx + dy + dz ~= 0 then dz = -dx - dy end
        end
        local newX, newY, newZ = hx + dx, hy + dy, hz + dz
        local newCol, newRow = HexGrid.CubeToOffset(newX, newY, newZ)
        if HexGrid.InBounds(newCol, newRow)
           and not HexGrid.IsBlocked(state.board, newCol, newRow)
           and not HexGrid.GetPieceAt(state.board, newCol, newRow) then
            hero.animFromCol = hero.col
            hero.animFromRow = hero.row
            hero.animTimer = 0.3
            hero.animMaxTimer = 0.3
            hero.col = newCol
            hero.row = newRow
            -- 拉动造成伤害
            local pullDmg = boss.enraged and 10 or 5
            hero.hp = hero.hp - pullDmg
            AddFloatingText(state, hero.col, hero.row,
                "-" .. pullDmg .. "🌊拉扯!", {50, 100, 200, 255}, "hit")
            state.screenShake = (state.screenShake or 0) + 0.3
        end
        BattleBoss.AddBossSkillAnnounce(state, "whirlpool", boss.name)
        AddLog(state, "🌊 深渊海妖释放漩涡，将英雄拉向自己！")
        AddVFX(state, "shockwave", { col = boss.col, row = boss.row, duration = 0.7 })
        return { type = "boss_whirlpool", enemy = boss }
    end

    -- 技能3: 深渊收缩 — 棋盘外圈变为不可通行（最多收缩2次）
    if (boss.shrinkCooldown or 0) <= 0 and (boss.shrinkCount or 0) < 2 and boss.enraged then
        boss.shrinkCooldown = 6
        boss.shrinkCount = (boss.shrinkCount or 0) + 1
        -- 在棋盘边缘添加障碍物
        local shrinkCount = 0
        local allCells = HexGrid.GetAllValidCells(state.board)
        for _, cell in ipairs(allCells) do
            -- 距离中心4格（边缘格）
            local dist = HexGrid.CubeDistance(cell.col, cell.row, 5, 5)  -- 中心(5,5)
            if dist >= 4 and not HexGrid.IsBlocked(state.board, cell.col, cell.row)
               and not HexGrid.GetPieceAt(state.board, cell.col, cell.row) then
                if math.random() < 0.5 then
                    HexGrid.AddObstacle(state.board, cell.col, cell.row)
                    local obs = state.board.obstacles
                    for _, o in ipairs(obs) do
                        if o.col == cell.col and o.row == cell.row then
                            o.isAbyssCrack = true
                            break
                        end
                    end
                    shrinkCount = shrinkCount + 1
                end
            end
        end
        if shrinkCount > 0 then
            BattleBoss.AddBossSkillAnnounce(state, "shrink", boss.name)
            AddFloatingText(state, boss.col, boss.row,
                "🕳️深渊收缩!", {80, 0, 120, 255}, "combo")
            AddLog(state, string.format("深渊海妖引发板块崩塌！%d格被深渊吞没！", shrinkCount))
            AddVFX(state, "shockwave", { col = boss.col, row = boss.row, duration = 1.0 })
            state.screenShake = (state.screenShake or 0) + 0.6
            return { type = "boss_shrink", enemy = boss }
        end
    end

    -- 护盾再生（狂暴时）
    if boss.enraged and (boss.shieldHp or 0) <= 0 then
        BattleBoss.AddBossSkillAnnounce(state, "abyss_shield", boss.name)
        boss.shieldHp = boss.shieldMax or 60
        AddFloatingText(state, boss.col, boss.row,
            "🛡️深渊护盾!", {50, 80, 180, 255})
        AddLog(state, "深渊海妖展开深渊护盾！")
        return { type = "boss_shield", enemy = boss }
    end

    -- 普通攻击/移动
    PredictNextSkill_AbyssKraken(state, boss)
    local atk = BattleBoss.BossBasicAttack(state, boss)
    if atk then return atk end
    return BattleBoss.BossMoveToHero(state, boss)
end

-- ============================================================================
-- 珊瑚守卫 Boss (第三章) — 重制版
-- 技能体系:
--   [珊瑚护甲] 护盾归零后每5回合（狂暴3回合）自动恢复满护盾
--   [珊瑚阵]   在Boss与英雄之间构筑横向珊瑚墙（留1缺口），分割战场 (冷却4/2)
--   [潮汐冲击] 将英雄沿远离Boss方向推2~3格，每推1格受一次伤 (冷却3/2)
--   [深海召唤] 召唤珊瑚精英小怪，狂暴时额外附带毒刺 (冷却5/3)
--   [珊瑚荆棘] 光环：靠近持续受伤（由BossAura系统处理）
-- ============================================================================
function BattleBoss.BossAct_CoralGuardian(state, boss)
    local hero = state.hero
    BattleBoss.BossEnrageCheck(state, boss, "珊瑚守卫")

    -- 冷却递减
    if boss.shieldRegenCooldown and boss.shieldRegenCooldown > 0 then boss.shieldRegenCooldown = boss.shieldRegenCooldown - 1 end
    if boss.tideSurgeCooldown   and boss.tideSurgeCooldown   > 0 then boss.tideSurgeCooldown   = boss.tideSurgeCooldown   - 1 end
    if boss.coralThrowCooldown  and boss.coralThrowCooldown  > 0 then boss.coralThrowCooldown  = boss.coralThrowCooldown  - 1 end
    if boss.coralSealCooldown   and boss.coralSealCooldown   > 0 then boss.coralSealCooldown   = boss.coralSealCooldown   - 1 end
    if boss.coralSpikeCooldown  and boss.coralSpikeCooldown  > 0 then boss.coralSpikeCooldown  = boss.coralSpikeCooldown  - 1 end

    -- 字段兼容旧存档
    if boss.shieldRegenCooldown == nil then boss.shieldRegenCooldown = 0 end
    if boss.tideSurgeCooldown   == nil then boss.tideSurgeCooldown   = 0 end
    if boss.coralThrowCooldown  == nil then boss.coralThrowCooldown  = 0 end
    if boss.coralSealCooldown   == nil then boss.coralSealCooldown   = 0 end
    if boss.coralSpikeCooldown  == nil then boss.coralSpikeCooldown  = 0 end

    local distToHero = HexGrid.CubeDistance(boss.col, boss.row, hero.col, hero.row)

    -- ── 优先级0: 珊瑚护甲重生（护盾耗尽后触发）───────────────────────────
    if (not boss.shieldHp or boss.shieldHp <= 0) and boss.shieldRegenCooldown <= 0 then
        boss.shieldHp = boss.shieldMax
        boss.shieldRegenCooldown = boss.enraged and 3 or 5
        BattleBoss.AddBossSkillAnnounce(state, "coral_regen", boss.name)
        AddFloatingText(state, boss.col, boss.row,
            "🛡️护甲重生!", {255, 180, 220, 255}, "combo")
        AM.PlaySFX("shield_ward", 0.8)
        AddLog(state, "珊瑚守卫的珊瑚护甲完全恢复！")
        state.screenShake = 0.2
        return { type = "skill", enemy = boss, skill = "coral_regen" }
    end

    -- ── 优先级0.5: 珊瑚刺击 — 近身高伤+中毒（距离<=2，每2回合，狂暴1回合）──
    if boss.coralSpikeCooldown <= 0 and distToHero <= 2 then
        boss.coralSpikeCooldown = boss.enraged and 1 or 2
        local spikeDmg = boss.enraged and math.floor(boss.atk * 2.6) or math.floor(boss.atk * 2.0)
        local poisonTurns = boss.enraged and 3 or 2
        hero.hp = hero.hp - spikeDmg
        hero.poisonTurns = (hero.poisonTurns or 0) + poisonTurns
        hero.poisonDmg   = math.max(hero.poisonDmg or 0, 6)
        AddFloatingText(state, hero.col, hero.row, "⚡-" .. spikeDmg .. "刺击!", {100, 220, 180, 255}, "hit")
        AddFloatingText(state, hero.col, hero.row, "🤢中毒" .. poisonTurns .. "回合", {80, 180, 140, 255})
        BattleBoss.AddBossSkillAnnounce(state, "coral_spike", boss.name)
        AddVFX(state, "coral_spike", { col = hero.col, row = hero.row, duration = 0.8 })
        boss.skillAnimTimer    = 0.45
        boss.skillAnimDuration = 0.45
        boss.skillAnimType     = "spike"
        state.screenShake = (state.screenShake or 0) + 0.45
        AM.PlaySFX("coral_spike_pierce", 1.0)
        AddLog(state, string.format("珊瑚守卫珊瑚刺击！造成%d点伤害并附加%d回合中毒！", spikeDmg, poisonTurns))
        return { type = "skill", enemy = boss, skill = "coral_spike" }
    end

    -- ── 优先级1: 潮汐冲击（英雄距离≤4时触发）────────────────────────────
    if boss.tideSurgeCooldown <= 0 and distToHero <= 4 then
        local pushSteps = boss.enraged and 4 or 2
        local pushDmg   = boss.enraged and math.floor(boss.atk * 1.5) or math.floor(boss.atk * 1.2)
        local totalDmg  = 0
        local pushed    = 0

        for _ = 1, pushSteps do
            -- 在英雄所有相邻格中，选离Boss最远的空格作为推送目标
            local neighbors = HexGrid.GetNeighbors(hero.col, hero.row)
            local bestCell, bestDist = nil, -1
            for _, nb in ipairs(neighbors) do
                if HexGrid.InBounds(nb.col, nb.row)
                   and not HexGrid.IsBlocked(state.board, nb.col, nb.row)
                   and not HexGrid.GetPieceAt(state.board, nb.col, nb.row) then
                    local d = HexGrid.CubeDistance(nb.col, nb.row, boss.col, boss.row)
                    if d > bestDist then
                        bestDist = d
                        bestCell = nb
                    end
                end
            end
            if bestCell then
                hero.col = bestCell.col
                hero.row = bestCell.row
                pushed = pushed + 1
                hero.hp = hero.hp - pushDmg
                totalDmg = totalDmg + pushDmg
                AddVFX(state, "spawn_puff", { col = hero.col, row = hero.row, duration = 0.4 })
            else
                break  -- 无法继续推
            end
        end

        if pushed > 0 then
            BattleBoss.AddBossSkillAnnounce(state, "tide_surge", boss.name)
            boss.tideSurgeCooldown = boss.enraged and 2 or 3
            AddFloatingText(state, hero.col, hero.row,
                "🌊-" .. totalDmg, {80, 190, 230, 255}, "hit")
            AM.PlaySFX("lightning", 0.5)
            AddLog(state, string.format(
                "珊瑚守卫潮汐冲击！英雄被推离%d格，受到%d点伤害！", pushed, totalDmg))
            state.screenShake = 0.5
            return { type = "skill", enemy = boss, skill = "tide_surge" }
        end
    end

    -- ── 优先级1: 珊瑚投掷（向英雄抛出大珊瑚块，造成重击并堵路）─────────
    if boss.coralThrowCooldown <= 0 then
        local throwDmg = boss.enraged and math.floor(boss.atk * 2.5) or math.floor(boss.atk * 1.8)
        hero.hp = hero.hp - throwDmg
        AddFloatingText(state, hero.col, hero.row,
            "🪸-" .. throwDmg, {255, 120, 60, 255}, "hit")
        AddVFX(state, "spawn_puff", { col = hero.col, row = hero.row, duration = 0.5 })

        -- 在英雄周围的随机空格放置1~2个珊瑚障碍（堵住退路）
        local heroNeighbors = HexGrid.GetNeighbors(hero.col, hero.row)
        local freeCells = {}
        for _, nb in ipairs(heroNeighbors) do
            if HexGrid.InBounds(nb.col, nb.row)
               and not HexGrid.IsBlocked(state.board, nb.col, nb.row)
               and not HexGrid.GetPieceAt(state.board, nb.col, nb.row) then
                freeCells[#freeCells + 1] = nb
            end
        end
        -- 打乱后放1~2块（狂暴放2块）
        for i = #freeCells, 2, -1 do
            local j = math.random(1, i)
            freeCells[i], freeCells[j] = freeCells[j], freeCells[i]
        end
        local blockCount = boss.enraged and 2 or 1
        for i = 1, math.min(blockCount, #freeCells) do
            HexGrid.AddObstacle(state.board, freeCells[i].col, freeCells[i].row)
            AddVFX(state, "spawn_puff",
                { col = freeCells[i].col, row = freeCells[i].row, duration = 0.6 })
        end

        BattleBoss.AddBossSkillAnnounce(state, "coral_throw", boss.name)
        boss.coralThrowCooldown = boss.enraged and 1 or 2
        AddLog(state, string.format(
            "珊瑚守卫抛出巨大珊瑚块！英雄受到%d点伤害！", throwDmg))
        state.screenShake = 0.5
        return { type = "skill", enemy = boss, skill = "coral_throw" }
    end

    -- ── 优先级2: 珊瑚封印（在英雄周围召唤珊瑚群 + 沉默英雄）──────────
    if boss.coralSealCooldown <= 0 then
        -- 收集英雄周围半径1的格子（6邻格）以及英雄外延格子
        local sealCells = {}
        local heroNbs = HexGrid.GetNeighbors(hero.col, hero.row)
        for _, nb in ipairs(heroNbs) do
            if HexGrid.InBounds(nb.col, nb.row)
               and not HexGrid.IsBlocked(state.board, nb.col, nb.row)
               and not HexGrid.GetPieceAt(state.board, nb.col, nb.row) then
                sealCells[#sealCells + 1] = nb
            end
        end
        -- 再收集英雄外延一圈（距离2），补充到7格目标
        if #sealCells < 6 then
            for r = 1, HexGrid.ROWS do
                for c = 1, HexGrid.COLS do
                    local d = HexGrid.CubeDistance(c, r, hero.col, hero.row)
                    if d == 2
                       and HexGrid.InBounds(c, r)
                       and not HexGrid.IsBlocked(state.board, c, r)
                       and not HexGrid.GetPieceAt(state.board, c, r) then
                        sealCells[#sealCells + 1] = { col = c, row = r }
                    end
                end
            end
        end
        -- 打乱后放最多7块珊瑚（形成包围圈）
        for i = #sealCells, 2, -1 do
            local j = math.random(1, i)
            sealCells[i], sealCells[j] = sealCells[j], sealCells[i]
        end
        local sealLimit = boss.enraged and 7 or 5
        local placed = 0
        for i = 1, math.min(sealLimit, #sealCells) do
            HexGrid.AddObstacle(state.board, sealCells[i].col, sealCells[i].row)
            AddVFX(state, "spawn_puff",
                { col = sealCells[i].col, row = sealCells[i].row, duration = 0.8 })
            placed = placed + 1
        end

        -- 沉默英雄（无法攻击）
        local silenceTurns = boss.enraged and 3 or 2
        hero.silencedTurns = (hero.silencedTurns or 0) + silenceTurns

        if placed >= 2 then
            BattleBoss.AddBossSkillAnnounce(state, "coral_seal", boss.name)
            boss.coralSealCooldown = boss.enraged and 2 or 4
            AddFloatingText(state, hero.col, hero.row,
                "🔇沉默" .. silenceTurns .. "回合!", {200, 100, 255, 255}, "combo")
            AddFloatingText(state, boss.col, boss.row,
                "🪸珊瑚封印!", {255, 150, 200, 255}, "combo")
            AM.PlaySFX("shield_ward", 0.6)
            AddLog(state, string.format(
                "珊瑚守卫施放珊瑚封印！召唤%d块珊瑚，英雄被沉默%d回合无法攻击！",
                placed, silenceTurns))
            state.screenShake = 0.6
            return { type = "skill", enemy = boss, skill = "coral_seal" }
        end
    end

    -- 普通攻击/移动
    PredictNextSkill_CoralGuardian(state, boss)
    local atk = BattleBoss.BossBasicAttack(state, boss)
    if atk then return atk end
    return BattleBoss.BossMoveToHero(state, boss)
end

-- =============================================================================
-- 第四章: 沙丘巨虫 (sand_worm) — 蛇形移动 + 尾鞭 + 沙暴 + 钻地
-- =============================================================================

--- 沙虫蛇形移动: 头移动到新格，身体段依次跟随（仅限相邻1格移动）
local function SandWormSnakeMove(state, boss, targetCol, targetRow)
    local segments = state.sandWormSegments
    if not segments or #segments < 2 then
        boss.col, boss.row = targetCol, targetRow
        return
    end

    -- 从尾到头依次移动：每段移到前一段的旧位置
    for i = #segments, 2, -1 do
        local seg = segments[i]
        local prev = segments[i - 1]
        seg.col, seg.row = prev.col, prev.row
    end
    -- 头移到目标位置
    boss.col, boss.row = targetCol, targetRow
end

--- 沙虫传送后重排身体：头部已到新位置，身体段依次排列在头后面形成连续蛇形
local function SandWormReformBody(state, boss)
    local segments = state.sandWormSegments
    if not segments or #segments < 2 then return end

    -- 从第2段开始，每段找前一段的相邻空格放置
    for i = 2, #segments do
        local prev = segments[i - 1]
        local seg = segments[i]
        local neighbors = HexGrid.GetNeighbors(prev.col, prev.row)
        -- 优先选行号更大的（身体向下延伸）
        table.sort(neighbors, function(a, b) return a.row > b.row end)
        local placed = false
        for _, nb in ipairs(neighbors) do
            if HexGrid.InBounds(nb.col, nb.row) then
                -- 不能放在有棋子的格子（排除自己身体段）
                local occupied = false
                local pieceAt = HexGrid.GetPieceAt(state.board, nb.col, nb.row)
                if pieceAt then
                    -- 检查是否是自己的身体段
                    local isSelf = false
                    for k = 1, #segments do
                        if segments[k] == pieceAt then isSelf = true; break end
                    end
                    if not isSelf then occupied = true end
                end
                -- 不能放在已排好的前面身体段上
                if not occupied then
                    local isEarlierSeg = false
                    for k = 1, i - 1 do
                        if segments[k].col == nb.col and segments[k].row == nb.row then
                            isEarlierSeg = true; break
                        end
                    end
                    if not isEarlierSeg
                       and not HexGrid.GetObstacleAt(state.board, nb.col, nb.row) then
                        -- 沙虫不受流沙影响，身体段可放在流沙区上
                        seg.col, seg.row = nb.col, nb.row
                        placed = true
                        break
                    end
                end
            end
        end
        -- 如果找不到合适位置，紧贴前一段（容错）
        if not placed then
            seg.col, seg.row = prev.col, prev.row
        end
    end
end

--- 沙虫判断某格是否可通行（忽略流沙，Boss不受流沙影响）
local function SandWormCanPass(state, boss, col, row)
    if not HexGrid.InBounds(col, row) then return false end
    if HexGrid.GetObstacleAt(state.board, col, row) then return false end
    -- 不能移动到英雄所在格
    if col == state.hero.col and row == state.hero.row then return false end
    -- 不能移动到其他敌人所在格（排除自己的身体段）
    local pieceAt = HexGrid.GetPieceAt(state.board, col, row)
    if pieceAt then
        local isSelf = false
        if state.sandWormSegments then
            for _, seg in ipairs(state.sandWormSegments) do
                if seg == pieceAt then isSelf = true; break end
            end
        end
        if not isSelf then return false end
    end
    -- 不能移动到自己身体段所在格（避免自咬）
    if state.sandWormSegments then
        for _, seg in ipairs(state.sandWormSegments) do
            if seg ~= boss and seg.col == col and seg.row == row then return false end
        end
    end
    return true
end

--- 沙虫寻找朝英雄方向的最佳移动格（忽略流沙）
local function SandWormFindMoveTarget(state, boss)
    local hero = state.hero
    local neighbors = HexGrid.GetNeighbors(boss.col, boss.row)
    local best, bestDist = nil, 999
    for _, nb in ipairs(neighbors) do
        if SandWormCanPass(state, boss, nb.col, nb.row) then
            local d = HexGrid.CubeDistance(nb.col, nb.row, hero.col, hero.row)
            if d < bestDist then
                bestDist = d
                best = nb
            end
        end
    end
    return best
end

function BattleBoss.BossAct_SandWorm(state, boss)
    local hero = state.hero
    BattleBoss.BossEnrageCheck(state, boss, "沙丘巨虫")

    -- 冷却递减
    boss.burrowCooldown    = (boss.burrowCooldown or 0) - 1
    boss.tailWhipCooldown  = (boss.tailWhipCooldown or 0) - 1
    boss.sandstormCooldown = (boss.sandstormCooldown or 0) - 1

    -- ══ 部分露出状态（钻出后第一回合只显示头+2节，本回合结束恢复全部）══════
    if boss.emerging then
        boss.emerging = false
        -- 恢复所有隐藏的身体段
        if state.sandWormSegments then
            for _, seg in ipairs(state.sandWormSegments) do
                seg.hidden = false
            end
        end
        AddFloatingText(state, boss.col, boss.row, "🐛完全钻出!", {210, 180, 100, 255})
        AddLog(state, "沙丘巨虫完全从地下钻出！")
        -- 本回合正常行动（继续往下走到移动/攻击逻辑）
    end

    -- ══ 遁地读条阶段（Boss还在地面，准备钻入地下）══════════════════════
    if boss.burrowCasting then
        boss.burrowCasting = false
        -- 读条结束，正式遁地
        boss.burrowed = true
        boss.hidden = true
        boss.burrowTimer = 2  -- 地下2回合
        -- 隐藏所有身体段
        if state.sandWormSegments then
            for _, seg in ipairs(state.sandWormSegments) do
                seg.hidden = true
            end
        end
        AddFloatingText(state, boss.col, boss.row, "🕳️遁入地下!", {180, 140, 60, 255})
        AddVFX(state, "burrow_start", { col = boss.col, row = boss.row, duration = 0.6 })
        state.screenShake = (state.screenShake or 0) + 0.3
        AM.PlaySFX("boss_aoe", 0.7)
        AddLog(state, "沙丘巨虫钻入地下！地面开始震动...")
        return { type = "skill", enemy = boss, skill = "burrow_dive" }
    end

    -- ══ 遁地状态处理（Boss在地下，倒计时结束后钻出AOE）══════════════════
    if boss.burrowed then
        boss.burrowTimer = (boss.burrowTimer or 0) - 1
        if boss.burrowTimer <= 0 then
            -- 钻出！在英雄附近造成大范围AOE
            boss.burrowed = false
            boss.hidden = false
            -- 找英雄附近的空格作为Boss头部钻出点
            local heroNeighbors = HexGrid.GetNeighbors(hero.col, hero.row)
            local validSpots = {}
            for _, nb in ipairs(heroNeighbors) do
                if SandWormCanPass(state, boss, nb.col, nb.row) then
                    validSpots[#validSpots + 1] = nb
                end
            end
            if #validSpots > 0 then
                local dest = validSpots[math.random(1, #validSpots)]
                boss.col, boss.row = dest.col, dest.row
            end
            -- 身体重新排列在头部后面（爬出动画：头先出，身体段延迟逐节显示）
            SandWormReformBody(state, boss)
            boss.emerging = true  -- 标记：下回合再完全显示
            if state.sandWormSegments then
                for i, seg in ipairs(state.sandWormSegments) do
                    if i == 1 then
                        seg.hidden = false  -- 头部立即显示
                    elseif i == 2 then
                        seg.hidden = false  -- 第1节紧跟头部
                        seg.emergeDelay = 0.3  -- 延迟0.3秒显示（爬出效果）
                    elseif i == 3 then
                        seg.hidden = false
                        seg.emergeDelay = 0.6  -- 延迟0.6秒
                    else
                        seg.hidden = true   -- 其余隐藏，下回合再露出
                    end
                end
            end
            -- 对钻出点周围造成AOE伤害（头部+相邻6格范围）
            local aoeRange = HexGrid.GetNeighbors(boss.col, boss.row)
            aoeRange[#aoeRange + 1] = { col = boss.col, row = boss.row }
            local burrowDmg = boss.enraged and math.floor(boss.atk * 1.8) or math.floor(boss.atk * 1.2)
            -- 检查英雄是否在AOE范围内
            local heroHit = false
            for _, tile in ipairs(aoeRange) do
                if tile.col == hero.col and tile.row == hero.row then
                    heroHit = true; break
                end
            end
            if heroHit then
                hero.hp = hero.hp - burrowDmg
                AddFloatingText(state, hero.col, hero.row,
                    "🕳️-" .. burrowDmg .. "钻地突袭!", {180, 140, 60, 255}, "hit")
            end
            -- AOE范围红光高亮（供BoardWidget渲染）
            state.sandWormEmergeAOE = {
                tiles = aoeRange,
                timer = 1.2,  -- 高亮持续1.2秒
                maxTimer = 1.2,
            }
            BattleBoss.AddBossSkillAnnounce(state, "burrow_emerge", boss.name)
            AddVFX(state, "burrow_strike", { col = boss.col, row = boss.row, duration = 0.8 })
            state.screenShake = (state.screenShake or 0) + 1.2  -- 更强烈的屏幕震动
            AM.PlaySFX("boss_stomp", 1.0)
            AddLog(state, string.format("沙丘巨虫从地下钻出！%s",
                heroHit and ("造成 " .. burrowDmg .. " 伤害！") or "英雄闪避成功！"))
            return { type = "skill", enemy = boss, skill = "burrow_emerge" }
        else
            -- 还在地下，显示提示
            AddFloatingText(state, hero.col, hero.row,
                "🌊地面震动..(" .. boss.burrowTimer .. "回合)", {180, 140, 60, 180})
            AddLog(state, "地面在震动...沙丘巨虫即将钻出！(剩余 " .. boss.burrowTimer .. " 回合)")
            return { type = "wait", enemy = boss }
        end
    end

    local distToHero = HexGrid.CubeDistance(boss.col, boss.row, hero.col, hero.row)

    -- ── 优先级0: 遁地读条（1回合准备→下回合正式遁地）─────────────────────
    if boss.burrowCooldown <= 0 and distToHero >= 3 then
        boss.burrowCooldown = boss.enraged and 7 or 10
        boss.burrowCasting = true  -- 进入读条阶段，下回合正式遁地
        BattleBoss.AddBossSkillAnnounce(state, "burrow_start", boss.name)
        AddFloatingText(state, boss.col, boss.row, "⏳准备遁地...", {180, 140, 60, 255})
        AddVFX(state, "burrow_casting", { col = boss.col, row = boss.row, duration = 1.0 })
        AM.PlaySFX("boss_aoe", 0.5)
        AddLog(state, "沙丘巨虫身体下沉，准备钻入地下！")
        return { type = "skill", enemy = boss, skill = "burrow_casting" }
    end

    -- ── 优先级1: 尾鞭横扫（英雄靠近尾巴时触发，打断连跳弹到附近格）──────────────────
    local tailSeg = nil
    if state.sandWormSegments and #state.sandWormSegments > 1 then
        tailSeg = state.sandWormSegments[#state.sandWormSegments]
    end
    local distToTail = tailSeg and HexGrid.CubeDistance(tailSeg.col, tailSeg.row, hero.col, hero.row) or distToHero
    if boss.tailWhipCooldown <= 0 and distToTail <= 2 then
        boss.tailWhipCooldown = boss.enraged and 2 or 4
        local whipDmg = boss.enraged and math.floor(boss.atk * 1.4) or boss.atk
        hero.hp = hero.hp - whipDmg
        -- 弹到Boss附近的安全格（不是全场随机）
        local knockNeighbors = HexGrid.GetNeighbors(hero.col, hero.row)
        local safeSpots = {}
        for _, nb in ipairs(knockNeighbors) do
            if HexGrid.InBounds(nb.col, nb.row)
               and not HexGrid.GetPieceAt(state.board, nb.col, nb.row)
               and not HexGrid.GetObstacleAt(state.board, nb.col, nb.row)
               and (nb.col ~= boss.col or nb.row ~= boss.row) then
                safeSpots[#safeSpots + 1] = nb
            end
        end
        if #safeSpots > 0 then
            local dest = safeSpots[math.random(1, #safeSpots)]
            hero.col, hero.row = dest.col, dest.row
        end
        -- 强制中断连跳
        state.combo = 0
        state.isChaining = false
        AddFloatingText(state, hero.col, hero.row,
            "🌊-" .. whipDmg .. "尾鞭!", {210, 180, 100, 255}, "hit")
        AddFloatingText(state, hero.col, hero.row,
            "💫连跳中断!", {255, 100, 100, 255})
        BattleBoss.AddBossSkillAnnounce(state, "tail_whip", boss.name)
        state.screenShake = (state.screenShake or 0) + 0.4
        AM.PlaySFX("boss_stomp", 0.9)
        AddLog(state, string.format("沙丘巨虫尾鞭横扫！造成 %d 伤害并中断连跳！", whipDmg))
        return { type = "skill", enemy = boss, skill = "tail_whip" }
    end

    -- ── 优先级2: 沙暴（全场AOE，伤害较低）─────────────────────────────
    if boss.sandstormCooldown <= 0 then
        boss.sandstormCooldown = boss.enraged and 3 or 6
        local stormDmg = boss.enraged and math.floor(boss.atk * 0.8) or math.floor(boss.atk * 0.5)
        hero.hp = hero.hp - stormDmg
        -- 沙暴还会在随机空格生成流沙
        local allCells = HexGrid.GetAllValidCells()
        local sandCount = boss.enraged and 3 or 2
        local shuffled = {}
        for _, c in ipairs(allCells) do
            if not HexGrid.IsBlocked(state.board, c.col, c.row)
               and (c.col ~= hero.col or c.row ~= hero.row)
               and not HexGrid.GetQuicksandAt(state.board, c.col, c.row) then
                shuffled[#shuffled + 1] = c
            end
        end
        for i = #shuffled, 2, -1 do
            local j = math.random(1, i)
            shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
        end
        for i = 1, math.min(sandCount, #shuffled) do
            HexGrid.AddQuicksand(state.board, shuffled[i].col, shuffled[i].row)
        end
        AddFloatingText(state, hero.col, hero.row,
            "🏜️-" .. stormDmg .. "沙暴!", {210, 180, 100, 255}, "hit")
        BattleBoss.AddBossSkillAnnounce(state, "sandstorm", boss.name)
        AddVFX(state, "sandstorm", { col = boss.col, row = boss.row, duration = 1.0 })
        state.screenShake = (state.screenShake or 0) + 0.3
        AM.PlaySFX("boss_aoe", 0.8)
        AddLog(state, string.format("沙丘巨虫掀起沙暴！全场 %d 伤害并制造流沙！", stormDmg))
        return { type = "skill", enemy = boss, skill = "sandstorm" }
    end

    -- ── 蛇形移动 + 普通攻击 ─────────────────────────────────────────
    -- 先移动一步靠近英雄
    local moveTarget = SandWormFindMoveTarget(state, boss)
    if moveTarget then
        SandWormSnakeMove(state, boss, moveTarget.col, moveTarget.row)
    end

    -- 移动后检查是否能攻击
    local newDist = HexGrid.CubeDistance(boss.col, boss.row, hero.col, hero.row)
    if newDist <= (boss.attackRange or 1) then
        local dmg = math.max(1, boss.atk - (hero.def or 0))
        hero.hp = hero.hp - dmg
        AddFloatingText(state, hero.col, hero.row,
            "🐛-" .. dmg, {210, 180, 100, 255}, "hit")
        boss.skillAnimTimer    = 0.35
        boss.skillAnimDuration = 0.35
        boss.skillAnimType     = "bite"
        AM.PlaySFX("attack_hit", 1.0)
        AddLog(state, string.format("沙丘巨虫撕咬！造成 %d 伤害！", dmg))
        return { type = "attack", enemy = boss, damage = dmg }
    end

    return { type = "move", enemy = boss }
end

--- 对Boss造成伤害（考虑护盾）
function BattleBoss.ApplyBossDamage(state, boss, damage)
    -- 沙虫身体段: 伤害路由到头部
    if boss.snakeHead then
        boss = boss.snakeHead
    end
    -- 遁地状态免疫伤害
    if boss.burrowed then
        AddFloatingText(state, boss.col, boss.row, "遁地中!", {150, 150, 150, 180})
        return
    end
    if boss.shieldHp and boss.shieldHp > 0 then
        local shieldAbsorb = math.min(boss.shieldHp, damage)
        boss.shieldHp = boss.shieldHp - shieldAbsorb
        damage = damage - shieldAbsorb
        if shieldAbsorb > 0 then
            AddFloatingText(state, boss.col, boss.row,
                "🛡️-" .. shieldAbsorb, {100, 180, 255, 200})
        end
        if boss.shieldHp <= 0 then
            AddFloatingText(state, boss.col, boss.row,
                "💥护盾破碎!", {255, 200, 50, 255}, "combo")
            AddLog(state, boss.name .. "的护盾被击碎了！")
            AddVFX(state, "shockwave", { col = boss.col, row = boss.row, duration = 0.5 })
        end
    end
    if damage > 0 then
        boss.hp = boss.hp - damage
    end
end


return BattleBoss
