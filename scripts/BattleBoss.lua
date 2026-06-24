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
    tentacle    = { name = "深渊触手",   icon = "🦑", desc = "触手从英雄周围伸出，形成包围！跳过会受伤！", color = {120, 60, 180} },
    whirlpool   = { name = "漩涡牵引",   icon = "🌊", desc = "释放漩涡将你拉向Boss，造成伤害！",       color = {50, 120, 220} },
    abyss_claw  = { name = "触手重击",   icon = "🦑", desc = "巨大触手猛力横扫，近距离造成重击伤害！",  color = {120, 40, 180} },

    -- 熔岩领主
    eruption    = { name = "地脉喷发",   icon = "🌋", desc = "唤醒地脉裂缝，沿十字线爆发高温岩浆！",   color = {255, 80, 0} },
    lava_shield = { name = "岩石护甲",   icon = "🛡️", desc = "熔岩领主重新凝聚岩石护甲！",             color = {180, 100, 30} },
    altar_break_shield = { name = "祭坛破盾", icon = "💥", desc = "所有火焰祭坛熄灭，Boss护盾被击碎！", color = {255, 50, 50} },
    lava_fist   = { name = "熔岩重拳",   icon = "🔥", desc = "举起炽热拳头猛砸英雄，留下灼烧地形！",   color = {255, 60, 0} },
    flame_bolt  = { name = "火焰弹射",   icon = "💥", desc = "精准射出火球直击英雄，周边格子也受波及！", color = {255, 140, 0} },
    -- 珊瑚守卫
    coral_throw     = { name = "珊瑚雨",   icon = "🪸", desc = "蓄力后召唤大范围珊瑚雨，砸落并生成障碍！", color = {255, 120,  60} },
    coral_seal      = { name = "珊瑚封印", icon = "🔇", desc = "珊瑚将你重重包围，沉默你使其无法攻击！",  color = {200, 100, 255} },
    tide_surge      = { name = "潮汐冲击", icon = "🌊", desc = "汹涌潮汐将你推离，途经格子均受到伤害！", color = {80,  190, 230} },
    -- 光环技能
    aura_abyss   = { name = "深渊压迫",   icon = "🌊", desc = "深渊之力侵蚀周围，靠近Boss会持续受伤！", color = {60, 120, 200} },
    -- 沙丘巨虫
    burrow_start  = { name = "遁地准备",   icon = "⏳", desc = "巨虫身体下沉，准备钻入地下伏击！",       color = {180, 140, 60} },
    burrow_emerge = { name = "钻地突袭",   icon = "🕳️", desc = "巨虫从地下猛烈钻出，重创周围一切！",     color = {210, 160, 40} },
    tail_whip     = { name = "尾鞭横扫",   icon = "🌊", desc = "巨大尾巴横扫，击飞英雄并中断连跳！",     color = {180, 150, 80} },
    -- sandstorm（巨岩投掷）已移除
    sand_fury     = { name = "呼唤风沙",   icon = "🌪️", desc = "召唤持续狂风沙暴笼罩全场，每回合造成伤害！持续3回合！", color = {230, 160, 50} },
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
    local tentacleNext  = math.max(0, (boss.tentacleCooldown   or 0) - 1)
    local whirlpoolNext = math.max(0, (boss.whirlpoolCooldown  or 0) - 1)
    if clawNext <= 0 and dist <= 2 then
        BattleBoss.SetBossNextSkill(boss, "abyss_claw")
    elseif tentacleNext <= 0 then
        BattleBoss.SetBossNextSkill(boss, "tentacle")
    elseif whirlpoolNext <= 0 and dist > 1 then
        BattleBoss.SetBossNextSkill(boss, "whirlpool")
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
    local tideNext       = math.max(0, (boss.tideSurgeCooldown   or 0) - 1)
    local throwNext      = math.max(0, (boss.coralThrowCooldown  or 0) - 1)
    local sealNext       = math.max(0, (boss.coralSealCooldown   or 0) - 1)
    if tideNext <= 0 and dist <= 4 then
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
    -- 如果前摇阶段已经展示了公告，跳过重复设置
    if state.bossSkillAnnounce and state.bossSkillAnnounce.timer > 0 then return end
    local info = BOSS_SKILL_INFO[skillKey]
    if not info then return end
    state.bossSkillAnnounce = {
        skillName = info.name,
        icon = info.icon,
        desc = info.desc,
        color = info.color or {200, 50, 50},
        bossName = bossName or "",
        timer = 4.5,
        maxTimer = 4.5,
    }
end

-- ============================================================================
-- Boss 技能前摇系统 — 先展示技能公告，延迟后再执行
-- ============================================================================

--- 获取战场上的Boss棋子
---@param state table 战斗状态
---@return table|nil boss对象
local function FindBoss(state)
    local enemies = HexGrid.GetTeamPieces(state.board, "enemy")
    for _, e in ipairs(enemies) do
        if e.isBoss and e.hp > 0 then return e end
    end
    return nil
end



--- 预判熔岩领主本回合将释放的技能
local function PredictCurrentSkill_LavaLord(state, boss)
    -- 全局技能间隔期间不会释放技能（包括狂暴状态）
    if boss.skillGlobalCD and boss.skillGlobalCD > 0 then
        return nil
    end
    local hero = state.hero
    local distToHero = HexGrid.CubeDistance(boss.col, boss.row, hero.col, hero.row)
    if (boss.lavaFistCooldown or 0) <= 1 and distToHero <= 2 then
        return "lava_fist"
    end
    if (boss.flameBoltCooldown or 0) <= 1 and distToHero <= 6 then
        return "flame_bolt"
    end
    if (boss.eruptionCooldown or 0) <= 1 then
        return "eruption"
    end
    if (boss.shieldRegenCooldown or 0) <= 1 and (boss.shieldHp or 0) <= 0 then
        return "lava_shield"
    end
    return nil
end

--- 预判深渊海妖本回合将释放的技能
local function PredictCurrentSkill_AbyssKraken(state, boss)
    -- 全局技能间隔期间不会释放技能（包括狂暴状态）
    if boss.skillGlobalCD and boss.skillGlobalCD > 0 then
        return nil
    end
    local hero = state.hero
    local distToHero = HexGrid.CubeDistance(boss.col, boss.row, hero.col, hero.row)
    if (boss.abyssClawCooldown or 0) <= 1 and distToHero <= 2 then
        return "abyss_claw"
    end
    if (boss.tentacleCooldown or 0) <= 1 then
        return "tentacle"
    end
    if (boss.whirlpoolCooldown or 0) <= 1 and distToHero > 1 then
        return "whirlpool"
    end
    return nil
end

--- 预判珊瑚守卫本回合将释放的技能
local function PredictCurrentSkill_CoralGuardian(state, boss)
    -- 全局技能间隔期间不会释放技能（包括狂暴状态）
    if boss.skillGlobalCD and boss.skillGlobalCD > 0 then
        return nil
    end
    local hero = state.hero
    local distToHero = HexGrid.CubeDistance(boss.col, boss.row, hero.col, hero.row)
    if (boss.tideSurgeCooldown or 0) <= 1 and distToHero <= 4 then
        return "tide_surge"
    end
    if (boss.coralThrowCooldown or 0) <= 1 then
        return "coral_throw"
    end
    if (boss.coralSealCooldown or 0) <= 1 then
        return "coral_seal"
    end
    return nil
end

--- 预判沙丘巨虫本回合将释放的技能
local function PredictCurrentSkill_SandWorm(state, boss)
    -- 全局技能间隔期间不会释放技能（包括狂暴状态）
    if boss.skillGlobalCD and boss.skillGlobalCD > 0 then
        return nil
    end
    local hero = state.hero
    local distToHero = HexGrid.CubeDistance(boss.col, boss.row, hero.col, hero.row)
    -- 遁地读条中 → 下回合正式遁地（不需要前摇公告）
    if boss.burrowCasting then return nil end
    -- 地下状态处理
    if boss.burrowed then
        if (boss.burrowTimer or 0) <= 1 then
            return "burrow_emerge"
        end
        return nil
    end
    -- 遁地准备
    if (boss.burrowCooldown or 0) <= 1 and distToHero >= 3 then
        return "burrow_start"
    end
    -- 尾鞭
    local tailSeg = nil
    if state.sandWormSegments and #state.sandWormSegments > 1 then
        tailSeg = state.sandWormSegments[#state.sandWormSegments]
    end
    local distToTail = tailSeg and HexGrid.CubeDistance(tailSeg.col, tailSeg.row, hero.col, hero.row) or distToHero
    if (boss.tailWhipCooldown or 0) <= 1 and distToTail <= 2 then
        return "tail_whip"
    end
    -- 呼唤风沙
    if (boss.sandFuryCooldown or 0) <= 1 and not state.sandFuryActive then
        return "sand_fury"
    end
    return nil
end

--- Boss前摇公告入口 — 在敌方回合执行前调用，展示即将释放的技能
--- 返回 true 表示有技能需要前摇展示，false 表示无技能（普攻/移动不需要前摇）
---@param state table 战斗状态
---@return boolean
function BattleBoss.PreCastAnnounce(state)
    local boss = FindBoss(state)
    if not boss then return false end

    local bt = boss.bossType or "abyss_kraken"
    local skillKey = nil
    if bt == "lava_lord" then
        skillKey = PredictCurrentSkill_LavaLord(state, boss)
    elseif bt == "abyss_kraken" then
        skillKey = PredictCurrentSkill_AbyssKraken(state, boss)
    elseif bt == "coral_guardian" then
        skillKey = PredictCurrentSkill_CoralGuardian(state, boss)
    elseif bt == "sand_worm" then
        skillKey = PredictCurrentSkill_SandWorm(state, boss)
    end

    if not skillKey then return false end

    -- 展示技能公告
    local info = BOSS_SKILL_INFO[skillKey]
    if not info then return false end
    state.bossSkillAnnounce = {
        skillName = info.name,
        icon = info.icon,
        desc = info.desc,
        color = info.color or {200, 50, 50},
        bossName = boss.name or "",
        timer = 3.0,
        maxTimer = 3.0,
    }
    return true
end

-- ============================================================================
-- 预警AOE系统（通用）
-- state.bossAoeWarning = { type, tiles, timer, damage, ... }
-- timer: 每回合递减，到0时引爆
-- ============================================================================

--- 获取扇形区域格子（从origin朝target方向，扩散角度约120°，距离maxDist）
local function GetConeTiles(originCol, originRow, targetCol, targetRow, maxDist)
    local ox, oy, oz = HexGrid.OffsetToCube(originCol, originRow)
    local tx, ty, tz = HexGrid.OffsetToCube(targetCol, targetRow)
    local dx, dy, dz = tx - ox, ty - oy, tz - oz
    -- 归一化方向（取主方向）
    local adx, ady, adz = math.abs(dx), math.abs(dy), math.abs(dz)
    local maxAbs = math.max(adx, ady, adz)
    if maxAbs == 0 then return {} end
    -- 主方向
    local ndx = dx > 0 and 1 or (dx < 0 and -1 or 0)
    local ndy = dy > 0 and 1 or (dy < 0 and -1 or 0)
    local ndz = dz > 0 and 1 or (dz < 0 and -1 or 0)
    -- 收集锥形范围内的格子（用cube坐标向量夹角判断）
    local tiles = {}
    for r = 1, HexGrid.ROWS do
        for c = 1, HexGrid.COLS do
            if HexGrid.InBounds(c, r) then
                local cx, cy, cz = HexGrid.OffsetToCube(c, r)
                local vx, vy, vz = cx - ox, cy - oy, cz - oz
                local dist = HexGrid.CubeDistance(originCol, originRow, c, r)
                if dist >= 1 and dist <= maxDist then
                    -- 点积判断方向一致性（>0表示同侧）
                    local dot = vx * dx + vy * dy + vz * dz
                    if dot > 0 then
                        -- 宽松锥形：点积占比 > 0.3（约120°扇形）
                        local lenV = math.sqrt(vx*vx + vy*vy + vz*vz)
                        local lenD = math.sqrt(dx*dx + dy*dy + dz*dz)
                        local cosAngle = dot / (lenV * lenD + 0.001)
                        if cosAngle > 0.3 then
                            tiles[#tiles + 1] = { col = c, row = r }
                        end
                    end
                end
            end
        end
    end
    return tiles
end

--- 获取十字线格子（从center沿3条hex轴线延伸）
local function GetCrossTiles(centerCol, centerRow, maxDist)
    local cx, cy, cz = HexGrid.OffsetToCube(centerCol, centerRow)
    local tiles = {}
    local added = {}
    -- 6方向CUBE_DIRS，取3条轴（每条包含正反两个方向）
    local DIRS = {
        { 1, -1,  0},
        { 1,  0, -1},
        { 0,  1, -1},
    }
    for _, dir in ipairs(DIRS) do
        for sign = -1, 1, 2 do
            for step = 1, maxDist do
                local nx = cx + dir[1] * sign * step
                local ny = cy + dir[2] * sign * step
                local nz = cz + dir[3] * sign * step
                local nc, nr = HexGrid.CubeToOffset(nx, ny, nz)
                local key = nc .. "," .. nr
                if HexGrid.InBounds(nc, nr) and not added[key] then
                    added[key] = true
                    tiles[#tiles + 1] = { col = nc, row = nr }
                end
            end
        end
    end
    return tiles
end

--- 获取圆形区域格子
local function GetCircleTiles(centerCol, centerRow, radius)
    local tiles = {}
    for r = 1, HexGrid.ROWS do
        for c = 1, HexGrid.COLS do
            if HexGrid.InBounds(c, r) then
                local d = HexGrid.CubeDistance(c, r, centerCol, centerRow)
                if d >= 1 and d <= radius then
                    tiles[#tiles + 1] = { col = c, row = r }
                end
            end
        end
    end
    return tiles
end

--- Boss回合开始时：检查并引爆待引爆的预警AOE
--- 返回 action result 如果引爆了，否则返回 nil
function BattleBoss.DetonateAoeWarning(state, boss)
    local warn = state.bossAoeWarning
    if not warn then return nil end

    warn.timer = (warn.timer or 1) - 1
    if warn.timer > 0 then return nil end

    -- 引爆！
    local hero = state.hero
    local heroKey = hero.col .. "," .. hero.row
    local heroHit = false

    -- 检查英雄是否在AOE范围内
    for _, tile in ipairs(warn.tiles or {}) do
        if tile.col == hero.col and tile.row == hero.row then
            heroHit = true
            break
        end
    end

    local warnType = warn.type

    if warnType == "venom_aoe" then
        -- 深渊海妖：毒液AOE引爆 + 留下毒区
        local venomDmg = warn.damage or 15
        if heroHit then
            hero.hp = hero.hp - venomDmg
            AddFloatingText(state, hero.col, hero.row,
                "☠️-" .. venomDmg .. "毒液!", {100, 20, 160, 255}, "hit")
        end
        -- 在AOE区域放置毒区（持续3回合）
        local poisonTurns = warn.poisonTurns or 3
        local poisonDmg = warn.poisonDmg or 5
        for _, tile in ipairs(warn.tiles or {}) do
            HexGrid.AddPoison(state.board, tile.col, tile.row, poisonTurns)
            local pt = HexGrid.GetPoisonAt(state.board, tile.col, tile.row)
            if pt then pt.damage = poisonDmg; pt.isVenom = true end
        end
        AddFloatingText(state, warn.centerCol or boss.col, warn.centerRow or boss.row,
            "☠️毒液扩散!", {100, 20, 160, 255}, "combo")
        BattleBoss.AddBossSkillAnnounce(state, "abyss_venom", boss.name)
        AddVFX(state, "abyss_venom", { col = warn.centerCol or hero.col, row = warn.centerRow or hero.row, duration = 1.0 })
        state.screenShake = (state.screenShake or 0) + 0.4
        AM.PlaySFX("abyss_venom_spray", 1.0)
        AddLog(state, string.format("毒液喷涌而出！%s", heroHit and ("英雄受到" .. venomDmg .. "点伤害！") or "英雄成功闪避！"))
        state.bossAoeWarning = nil
        return { type = "boss_aoe_detonate", skill = "venom_aoe", hit = heroHit }

    elseif warnType == "eruption_cross" then
        -- 熔岩领主：十字线岩浆爆发
        local eruptDmg = warn.damage or 25
        if heroHit then
            hero.hp = hero.hp - eruptDmg
            AddFloatingText(state, hero.col, hero.row,
                "🌋-" .. eruptDmg .. "喷发!", {255, 80, 0, 255}, "hit")
        end
        -- 十字线上放短暂岩浆（1回合）
        for _, tile in ipairs(warn.tiles or {}) do
            HexGrid.AddPoison(state.board, tile.col, tile.row, 1)
            local pt = HexGrid.GetPoisonAt(state.board, tile.col, tile.row)
            if pt then pt.damage = 8; pt.isLava = true end
        end
        AddFloatingText(state, warn.centerCol or boss.col, warn.centerRow or boss.row,
            "🌋地脉喷发!", {255, 80, 0, 255}, "combo")
        BattleBoss.AddBossSkillAnnounce(state, "eruption", boss.name)
        AddVFX(state, "lava_eruption", { col = warn.centerCol or hero.col, row = warn.centerRow or hero.row, duration = 1.0 })
        AddVFX(state, "shockwave", { col = warn.centerCol or boss.col, row = warn.centerRow or boss.row, duration = 0.8 })
        state.screenShake = (state.screenShake or 0) + 0.6
        AM.PlaySFX("lava_eruption", 1.0)
        AddLog(state, string.format("地脉沿裂缝喷发！%s", heroHit and ("英雄受到" .. eruptDmg .. "点伤害！") or "英雄成功闪避！"))
        state.bossAoeWarning = nil
        return { type = "boss_aoe_detonate", skill = "eruption_cross", hit = heroHit }

    elseif warnType == "coral_rain" then
        -- 珊瑚守卫：珊瑚雨砸落
        local throwDmg = warn.damage or 20
        if heroHit then
            hero.hp = hero.hp - throwDmg
            AddFloatingText(state, hero.col, hero.row,
                "🪸-" .. throwDmg .. "珊瑚雨!", {255, 120, 60, 255}, "hit")
        end
        -- 在AOE内随机放2~3个珊瑚障碍
        local obstacleCount = warn.obstacleCount or 2
        local validTiles = {}
        for _, tile in ipairs(warn.tiles or {}) do
            if not HexGrid.IsBlocked(state.board, tile.col, tile.row)
               and not HexGrid.GetPieceAt(state.board, tile.col, tile.row)
               and not (tile.col == hero.col and tile.row == hero.row)
               and not (tile.col == boss.col and tile.row == boss.row) then
                validTiles[#validTiles + 1] = tile
            end
        end
        -- 随机打乱
        for i = #validTiles, 2, -1 do
            local j = math.random(1, i)
            validTiles[i], validTiles[j] = validTiles[j], validTiles[i]
        end
        for i = 1, math.min(obstacleCount, #validTiles) do
            HexGrid.AddObstacle(state.board, validTiles[i].col, validTiles[i].row)
            AddVFX(state, "spawn_puff", { col = validTiles[i].col, row = validTiles[i].row, duration = 0.6 })
        end
        AddFloatingText(state, warn.centerCol or boss.col, warn.centerRow or boss.row,
            "🪸珊瑚雨!", {255, 120, 60, 255}, "combo")
        BattleBoss.AddBossSkillAnnounce(state, "coral_throw", boss.name)
        state.screenShake = (state.screenShake or 0) + 0.5
        AM.PlaySFX("coral_throw_impact", 0.9)
        AddLog(state, string.format("珊瑚雨从天而降！%s 生成了%d处珊瑚障碍！",
            heroHit and ("英雄受到" .. throwDmg .. "点伤害！") or "英雄闪避成功！",
            math.min(obstacleCount, #validTiles)))
        state.bossAoeWarning = nil
        return { type = "boss_aoe_detonate", skill = "coral_rain", hit = heroHit }
    end

    -- 未识别类型，清除
    state.bossAoeWarning = nil
    return nil
end

-- ============================================================================
-- Boss 特殊行动系统
-- ============================================================================

--- 递减Boss个体技能冷却（每回合都应递减，不论是否被全局CD阻塞）
local function TickBossCooldowns(boss)
    local bt = boss.bossType or "abyss_kraken"
    if bt == "lava_lord" then
        if boss.eruptionCooldown    and boss.eruptionCooldown    > 0 then boss.eruptionCooldown    = boss.eruptionCooldown    - 1 end
        if boss.shieldRegenCooldown and boss.shieldRegenCooldown > 0 then boss.shieldRegenCooldown = boss.shieldRegenCooldown - 1 end
        if boss.lavaFistCooldown    and boss.lavaFistCooldown    > 0 then boss.lavaFistCooldown    = boss.lavaFistCooldown    - 1 end
        if boss.flameBoltCooldown   and boss.flameBoltCooldown   > 0 then boss.flameBoltCooldown   = boss.flameBoltCooldown   - 1 end
    elseif bt == "abyss_kraken" then
        if boss.tentacleCooldown  and boss.tentacleCooldown  > 0 then boss.tentacleCooldown  = boss.tentacleCooldown  - 1 end
        if boss.whirlpoolCooldown and boss.whirlpoolCooldown > 0 then boss.whirlpoolCooldown = boss.whirlpoolCooldown - 1 end
        if boss.abyssClawCooldown and boss.abyssClawCooldown > 0 then boss.abyssClawCooldown = boss.abyssClawCooldown - 1 end
    elseif bt == "coral_guardian" then
        if boss.tideSurgeCooldown  and boss.tideSurgeCooldown  > 0 then boss.tideSurgeCooldown  = boss.tideSurgeCooldown  - 1 end
        if boss.coralThrowCooldown and boss.coralThrowCooldown > 0 then boss.coralThrowCooldown = boss.coralThrowCooldown - 1 end
        if boss.coralSealCooldown  and boss.coralSealCooldown  > 0 then boss.coralSealCooldown  = boss.coralSealCooldown  - 1 end
    elseif bt == "sand_worm" then
        boss.burrowCooldown   = (boss.burrowCooldown or 0) - 1
        boss.tailWhipCooldown = (boss.tailWhipCooldown or 0) - 1
        boss.sandFuryCooldown = (boss.sandFuryCooldown or 0) - 1
    end
end

--- Boss行动入口（分发到具体Boss）
function BattleBoss.BossAct(state, boss)
    -- 每回合统一递减个体技能冷却（无论全局CD是否阻塞）
    TickBossCooldowns(boss)

    -- 优先检查预警AOE引爆
    local detonateResult = BattleBoss.DetonateAoeWarning(state, boss)
    if detonateResult then
        -- AOE引爆也算一次技能行动，设置全局CD确保下回合普攻
        boss.skillGlobalCD = 1
        return detonateResult
    end

    -- === 全局技能间隔机制（强制 技能→普攻→技能→普攻 交替节奏）===
    -- 无论普通/狂暴/特殊状态，只要上回合释放了技能，本回合强制普攻
    -- 唯一例外：SandWorm 遁地中（burrowed状态下只做等待/钻出，不是主动技能选择）
    local isBurrowed = boss.burrowed  -- 遁地期间行为由内部状态机控制，不受CD约束
    if not isBurrowed then
        if boss.skillGlobalCD and boss.skillGlobalCD > 0 then
            boss.skillGlobalCD = boss.skillGlobalCD - 1
            -- 全局CD期间：只做普攻/移动
            local atk = BattleBoss.BossBasicAttack(state, boss)
            if atk then return atk end
            return BattleBoss.BossMoveToHero(state, boss)
        end
    end

    local bt = boss.bossType or "abyss_kraken"
    local result
    if bt == "lava_lord" then
        result = BattleBoss.BossAct_LavaLord(state, boss)
    elseif bt == "abyss_kraken" then
        result = BattleBoss.BossAct_AbyssKraken(state, boss)
    elseif bt == "coral_guardian" then
        result = BattleBoss.BossAct_CoralGuardian(state, boss)
    elseif bt == "sand_worm" then
        result = BattleBoss.BossAct_SandWorm(state, boss)
    elseif bt == "frost_king" then
        result = BattleBoss.BossAct_FrostKing(state, boss)
    end

    -- 如果本回合释放了技能（非普攻/移动/等待），设置1回合全局冷却
    if result and result.type ~= "attack" and result.type ~= "move" and result.type ~= "wait" then
        boss.skillGlobalCD = 1
    end

    return result
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
    if not boss.enraged and boss.hp <= boss.maxHp * 0.25 then
        boss.enraged = true
        boss.phase = 2
        boss.atk = math.floor(boss.atk * 1.3)
        AddFloatingText(state, boss.col, boss.row,
            "💀 狂暴!", {255, 50, 50, 255}, "combo")
        AddLog(state, "⚠️ " .. bossLabel .. "进入狂暴状态！ATK提升！")
        local bossColors = {
            abyss_kraken = {100, 20, 160}, lava_lord = {255, 100, 0}, coral_guardian = {255, 120, 180},
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
        -- 狂暴不再回盾，仅提升攻击力
    end
end

-- ============================================================================
-- ============================================================================
-- 熔岩领主 Boss (第三章)
-- ============================================================================
function BattleBoss.BossAct_LavaLord(state, boss)
    local hero = state.hero
    BattleBoss.BossEnrageCheck(state, boss, "熔岩领主")

    -- 冷却递减已由 TickBossCooldowns 统一处理

    local distToHero = HexGrid.CubeDistance(boss.col, boss.row, hero.col, hero.row)

    -- 技能0a: 熔岩重拳 — 近身重击+留下熔岩（距离<=2，每4回合，狂暴2回合）
    if (boss.lavaFistCooldown or 0) <= 0 and distToHero <= 2 then
        boss.lavaFistCooldown = boss.enraged and 2 or 4
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

    -- 技能0b: 火焰弹射 — 精准打击英雄位置+溅射（距离<=6，每5回合，狂暴3回合）
    if (boss.flameBoltCooldown or 0) <= 0 and distToHero <= 6 then
        boss.flameBoltCooldown = boss.enraged and 3 or 5
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

    -- 技能1: 熔岩喷发 — 放置熔岩地形（支持单格和多格连片）（每7回合，狂暴4回合）
    if (boss.eruptionCooldown or 0) <= 0 and not state.bossAoeWarning then
        boss.eruptionCooldown = boss.enraged and 4 or 7
        -- 预警AOE：十字线（以英雄当前位置为中心，沿3条hex轴延伸）
        local crossDist = boss.enraged and 4 or 3
        local crossTiles = GetCrossTiles(hero.col, hero.row, crossDist)
        local eruptDmg = boss.enraged and math.floor(boss.atk * 2.2) or math.floor(boss.atk * 1.8)
        -- 设置预警
        state.bossAoeWarning = {
            type = "eruption_cross",
            tiles = crossTiles,
            timer = 1,  -- 下回合引爆
            damage = eruptDmg,
            centerCol = hero.col,
            centerRow = hero.row,
            color = {255, 80, 0},  -- 橙红色预警
            icon = "🌋",
        }
        AddFloatingText(state, boss.col, boss.row,
            "🌋地脉蓄能!", {255, 80, 0, 255}, "combo")
        AddFloatingText(state, hero.col, hero.row,
            "⚠️地面裂开!", {255, 60, 20, 255})
        AddLog(state, "熔岩领主唤醒地脉！英雄脚下出现十字形裂缝预警！")
        BattleBoss.AddBossSkillAnnounce(state, "eruption", boss.name)
        boss.skillAnimTimer    = 0.5
        boss.skillAnimDuration = 0.5
        boss.skillAnimType     = "eruption"
        return { type = "boss_aoe_warning", enemy = boss, skill = "eruption_cross" }
    end

    -- 护盾再生（护盾被击碎后，冷却结束时重新生成）
    if (boss.shieldHp or 0) <= 0 and (boss.shieldRegenCooldown or 0) <= 0 then
        -- 非狂暴恢复40护盾（6回合冷却），狂暴恢复满护盾（3回合冷却）
        local regenAmount = boss.enraged and (boss.shieldMax or 70) or 40
        boss.shieldRegenCooldown = boss.enraged and 3 or 6
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

    -- 冷却递减已由 TickBossCooldowns 统一处理

    local distToHero = HexGrid.CubeDistance(boss.col, boss.row, hero.col, hero.row)

    -- 技能0a: 触手重击 — 近距离重击（距离<=2）
    if (boss.abyssClawCooldown or 0) <= 0 and distToHero <= 2 then
        boss.abyssClawCooldown = boss.enraged and 3 or 4
        local clawDmg = boss.enraged and math.floor(boss.atk * 2.8) or math.floor(boss.atk * 2.2)
        hero.hp = hero.hp - clawDmg
        AddFloatingText(state, hero.col, hero.row, "🦑-" .. clawDmg .. "重击!", {150, 50, 220, 255}, "hit")
        BattleBoss.AddBossSkillAnnounce(state, "abyss_claw", boss.name)
        AddVFX(state, "abyss_claw", { col = hero.col, row = hero.row, fromCol = boss.col, fromRow = boss.row, duration = 0.8 })
        boss.skillAnimTimer    = 0.55
        boss.skillAnimDuration = 0.55
        boss.skillAnimType     = "claw"
        state.screenShake = (state.screenShake or 0) + 0.5
        AM.PlaySFX("abyss_claw_hit", 1.0)
        AddLog(state, string.format("深渊海妖触手重击！造成%d点伤害！", clawDmg))
        return { type = "boss_claw", enemy = boss }
    end

    -- 技能1: 触手障碍 — 包围英雄周围放置触手（每5回合，狂暴3回合）
    if (boss.tentacleCooldown or 0) <= 0 then
        boss.tentacleCooldown = boss.enraged and 3 or 5
        local tentacleCount = boss.enraged and 5 or 4
        -- 收集英雄附近1~3格范围内的空闲格子（随机散布，不再死板围一圈）
        local candidates = {}
        for r = 1, HexGrid.ROWS do
            for c = 1, HexGrid.COLS do
                if HexGrid.InBounds(c, r) then
                    local dist = HexGrid.CubeDistance(c, r, hero.col, hero.row)
                    if dist >= 1 and dist <= 3
                       and not HexGrid.IsBlocked(state.board, c, r)
                       and not HexGrid.GetPieceAt(state.board, c, r)
                       and not (c == boss.col and r == boss.row)
                       and not (c == hero.col and r == hero.row) then
                        -- 距离越近权重越高（更可能出现在身边但不绝对）
                        local weight = (dist <= 1) and 3 or (dist <= 2 and 2 or 1)
                        for _ = 1, weight do
                            candidates[#candidates + 1] = { col = c, row = r }
                        end
                    end
                end
            end
        end
        -- Fisher-Yates 洗牌后取前 N 个
        for i = #candidates, 2, -1 do
            local j = math.random(1, i)
            candidates[i], candidates[j] = candidates[j], candidates[i]
        end
        local placed = 0
        local placedSet = {}  -- 去重：加权候选可能重复
        for _, pos in ipairs(candidates) do
            if placed >= tentacleCount then break end
            local key = pos.col * 100 + pos.row
            if placedSet[key] then goto skip_tentacle end
            placedSet[key] = true
            HexGrid.AddObstacle(state.board, pos.col, pos.row)
            -- 标记为触手障碍（普通3回合，狂暴4回合）
            local tentacleDuration = boss.enraged and 4 or 3
            local obs = state.board.obstacles
            for _, o in ipairs(obs) do
                if o.col == pos.col and o.row == pos.row then
                    o.isTentacle = true
                    o.turns = tentacleDuration
                    o.spawnTime = _G.G and _G.G.time or 0  -- 出生时间戳，用于出生动画
                    break
                end
            end
            AddFloatingText(state, pos.col, pos.row,
                "🦑触手!", {100, 50, 150, 255})
            placed = placed + 1
            ::skip_tentacle::
        end
        if placed > 0 then
            -- 触手涌出时对英雄造成一次伤害（基础atk的40%，狂暴50%）
            local tentacleDmg = math.floor(boss.atk * (boss.enraged and 0.5 or 0.4))
            hero.hp = hero.hp - tentacleDmg
            AddFloatingText(state, hero.col, hero.row,
                "🦑-" .. tentacleDmg .. "缠绕!", {140, 60, 180, 255}, "hit")
            -- 受击反馈：屏幕震动 + 英雄闪红
            state.screenShake = (state.screenShake or 0) + 0.3
            state.hitFlash = 0.25
            BattleBoss.AddBossSkillAnnounce(state, "tentacle", boss.name)
            AM.PlaySFX("abyss_tentacle_rise", 0.9)
            AddLog(state, string.format("深渊海妖伸出%d条触手包围英雄！造成%d点伤害！", placed, tentacleDmg))
            -- 触手从Boss方向甩向英雄的攻击特效
            AddVFX(state, "tentacle_strike", {
                fromCol = boss.col, fromRow = boss.row,
                toCol = hero.col, toRow = hero.row,
                duration = 0.6
            })
            return { type = "boss_tentacle", enemy = boss }
        end
    end

    -- 技能2: 漩涡牵引 — 将英雄拉向Boss 1-2格（每7回合，狂暴4回合）
    if (boss.whirlpoolCooldown or 0) <= 0 and distToHero > 1 then
        boss.whirlpoolCooldown = boss.enraged and 4 or 7
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
        AM.PlaySFX("abyss_whirlpool_pull", 0.8)
        AddLog(state, "🌊 深渊海妖释放漩涡，将英雄拉向自己！")
        AddVFX(state, "shockwave", { col = boss.col, row = boss.row, duration = 0.7 })
        return { type = "boss_whirlpool", enemy = boss }
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

    -- 冷却递减已由 TickBossCooldowns 统一处理

    -- 字段兼容旧存档
    if boss.tideSurgeCooldown   == nil then boss.tideSurgeCooldown   = 0 end
    if boss.coralThrowCooldown  == nil then boss.coralThrowCooldown  = 0 end
    if boss.coralSealCooldown   == nil then boss.coralSealCooldown   = 0 end

    local distToHero = HexGrid.CubeDistance(boss.col, boss.row, hero.col, hero.row)

    -- ── 被动：未受伤回血（该回合若Boss未受到伤害，恢复10%最大生命）────────
    if not boss.tookDamageThisTurn then
        local regenAmt = math.floor((boss.maxHp or boss.hp) * 0.10)
        local maxHp = boss.maxHp or boss.hp
        if boss.hp < maxHp then
            boss.hp = math.min(maxHp, boss.hp + regenAmt)
            AddFloatingText(state, boss.col, boss.row,
                "💚+" .. regenAmt .. "回血", {80, 220, 120, 255})
            AddVFX(state, "coral_heal", { col = boss.col, row = boss.row, duration = 1.0 })
            AM.PlaySFX("coral_regen_armor", 0.6)
            AddLog(state, string.format("珊瑚守卫未受攻击，自然恢复%d点生命！", regenAmt))
        end
    end
    boss.tookDamageThisTurn = false  -- 重置标记，留给本回合后续英雄攻击设置

    -- ── 优先级1: 潮汐冲击（英雄距离≤4时触发）────────────────────────────
    if boss.tideSurgeCooldown <= 0 and distToHero <= 4 then
        local pushSteps = boss.enraged and 4 or 2
        local pushDmg   = boss.enraged and math.floor(boss.atk * 1.5) or math.floor(boss.atk * 1.2)
        local totalDmg  = 0
        local pushed    = 0
        local hitCoral  = false  -- 是否撞到珊瑚（障碍物）

        -- 先在Boss位播放潮汐发动VFX
        AddVFX(state, "coral_tide_surge", { col = boss.col, row = boss.row, duration = 1.5 })
        AM.PlaySFX("coral_tide_surge", 0.8)

        for step = 1, pushSteps do
            -- 在英雄所有相邻格中，选离Boss最远的空格作为推送目标
            local neighbors = HexGrid.GetNeighbors(hero.col, hero.row)
            local bestCell, bestDist = nil, -1
            local blockedByObstacle = false
            for _, nb in ipairs(neighbors) do
                if HexGrid.InBounds(nb.col, nb.row)
                   and not HexGrid.GetPieceAt(state.board, nb.col, nb.row) then
                    local d = HexGrid.CubeDistance(nb.col, nb.row, boss.col, boss.row)
                    if not HexGrid.IsBlocked(state.board, nb.col, nb.row) then
                        if d > bestDist then
                            bestDist = d
                            bestCell = nb
                        end
                    else
                        -- 该方向有障碍物（珊瑚），标记撞击
                        if d > bestDist then
                            blockedByObstacle = true
                        end
                    end
                end
            end
            if bestCell then
                hero.col = bestCell.col
                hero.row = bestCell.row
                pushed = pushed + 1
                hero.hp = hero.hp - pushDmg
                totalDmg = totalDmg + pushDmg
                AddVFX(state, "frost_puff", { col = hero.col, row = hero.row, duration = 0.5 })
            else
                -- 无法继续推 → 检查是否因为撞到珊瑚（障碍物）
                if blockedByObstacle then
                    hitCoral = true
                end
                break
            end
        end

        -- 撞到珊瑚：额外+50%伤害
        if hitCoral and totalDmg > 0 then
            local coralBonusDmg = math.floor(totalDmg * 0.5)
            hero.hp = hero.hp - coralBonusDmg
            totalDmg = totalDmg + coralBonusDmg
            AddFloatingText(state, hero.col, hero.row,
                "💥撞击珊瑚-" .. coralBonusDmg, {255, 160, 60, 255}, "hit")
            AddVFX(state, "coral_spike", { col = hero.col, row = hero.row, duration = 0.8 })
            state.screenShake = (state.screenShake or 0) + 0.3
        end

        if pushed > 0 or hitCoral then
            BattleBoss.AddBossSkillAnnounce(state, "tide_surge", boss.name)
            boss.tideSurgeCooldown = boss.enraged and 3 or 5
            AddFloatingText(state, hero.col, hero.row,
                "🌊-" .. totalDmg, {80, 190, 230, 255}, "hit")
            -- VFX: 英雄落点水花爆发
            AddVFX(state, "shockwave", { col = hero.col, row = hero.row, duration = 0.6 })
            AddLog(state, string.format(
                "珊瑚守卫潮汐冲击！英雄被推离%d格，受到%d点伤害！%s",
                pushed, totalDmg, hitCoral and "撞击珊瑚受到额外伤害！" or ""))
            state.screenShake = (state.screenShake or 0) + 0.5
            return { type = "skill", enemy = boss, skill = "tide_surge" }
        end
    end

    -- ── 优先级1: 珊瑚投掷（预警AOE：大圆形珊瑚雨 + 珊瑚障碍）─────────
    if boss.coralThrowCooldown <= 0 and not state.bossAoeWarning then
        boss.coralThrowCooldown = boss.enraged and 4 or 6
        local circleRadius = boss.enraged and 3 or 3
        local circleTiles = GetCircleTiles(hero.col, hero.row, circleRadius)
        local throwDmg = boss.enraged and math.floor(boss.atk * 2.2) or math.floor(boss.atk * 1.6)
        local obstacleCount = boss.enraged and 3 or 2

        state.bossAoeWarning = {
            type = "coral_rain",
            tiles = circleTiles,
            timer = 1,
            damage = throwDmg,
            obstacleCount = obstacleCount,
            centerCol = hero.col,
            centerRow = hero.row,
            color = {255, 120, 60},
            icon = "🪸",
        }

        AddFloatingText(state, boss.col, boss.row, "🪸珊瑚蓄力!", {255, 120, 60, 255}, "combo")
        -- VFX: 蓄力阶段的能量聚集效果 + SFX
        AddVFX(state, "coral_throw_charge", { col = boss.col, row = boss.row, duration = 1.5 })
        AM.PlaySFX("coral_throw_impact", 0.6)
        AddLog(state, "珊瑚守卫高举巨大珊瑚块瞄准英雄区域！下回合珊瑚雨将砸落！")
        BattleBoss.AddBossSkillAnnounce(state, "coral_throw", boss.name)
        return { type = "skill_charge", enemy = boss, skill = "coral_throw" }
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
            AddVFX(state, "coral_spike",
                { col = sealCells[i].col, row = sealCells[i].row, duration = 0.9, delay = i * 0.08 })
            placed = placed + 1
        end

        -- 沉默英雄（无法攻击）
        local silenceTurns = boss.enraged and 3 or 2
        hero.silencedTurns = (hero.silencedTurns or 0) + silenceTurns

        if placed >= 2 then
            BattleBoss.AddBossSkillAnnounce(state, "coral_seal", boss.name)
            boss.coralSealCooldown = boss.enraged and 4 or 7
            AddFloatingText(state, hero.col, hero.row,
                "🔇沉默" .. silenceTurns .. "回合!", {200, 100, 255, 255}, "combo")
            AddFloatingText(state, boss.col, boss.row,
                "🪸珊瑚封印!", {255, 150, 200, 255}, "combo")
            -- VFX: 英雄位置紫色魔法封印阵 + Boss位置珊瑚刺击
            AddVFX(state, "coral_seal_ring", { col = hero.col, row = hero.row, duration = 1.5 })
            AddVFX(state, "coral_spike", { col = boss.col, row = boss.row, duration = 0.8 })
            AM.PlaySFX("coral_seal_enclosure", 0.8)
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
-- 第四章: 沙丘巨虫 (sand_worm) — 蛇形移动 + 尾鞭 + 呼唤风沙 + 钻地 + 头弱体硬被动
-- =============================================================================

--- 沙虫蛇形移动: 头移动到新格，身体段依次跟随（仅限相邻1格移动）
local function SandWormSnakeMove(state, boss, targetCol, targetRow)
    local segments = state.sandWormSegments
    if not segments or #segments < 2 then
        boss.col, boss.row = targetCol, targetRow
        return
    end

    -- 从尾到头依次移动：每段移到前一段的旧位置（带滑动动画）
    -- 跳过隐藏的段（还在洞口等待钻出的身体段）
    local CRAWL_DURATION = 0.35

    -- 记录最后一个可见段的旧位置（用于 emerging 时拖出新段）
    local lastVisibleIdx = nil
    local lastVisibleOldCol, lastVisibleOldRow = nil, nil
    for i = #segments, 1, -1 do
        if not segments[i].hidden then
            lastVisibleIdx = i
            lastVisibleOldCol = segments[i].col
            lastVisibleOldRow = segments[i].row
            break
        end
    end

    for i = #segments, 2, -1 do
        local seg = segments[i]
        if not seg.hidden then
            local prev = segments[i - 1]
            local oldCol, oldRow = seg.col, seg.row
            seg.col, seg.row = prev.col, prev.row
            -- 设置滑动动画（仅当位置真的变了）
            if oldCol ~= seg.col or oldRow ~= seg.row then
                seg.animFromCol = oldCol
                seg.animFromRow = oldRow
                seg.animTimer = CRAWL_DURATION
                seg.animMaxTimer = CRAWL_DURATION
            end
        end
    end
    -- 头移到目标位置（带滑动动画）
    local oldCol, oldRow = boss.col, boss.row
    boss.col, boss.row = targetCol, targetRow
    if oldCol ~= boss.col or oldRow ~= boss.row then
        boss.animFromCol = oldCol
        boss.animFromRow = oldRow
        boss.animTimer = CRAWL_DURATION
        boss.animMaxTimer = CRAWL_DURATION
    end

    -- ── emerging 拖出逻辑：头部每前进一步，从洞口拖出一个隐藏段 ──
    if boss.emerging and lastVisibleIdx and (oldCol ~= targetCol or oldRow ~= targetRow) then
        local nextHiddenIdx = lastVisibleIdx + 1
        if nextHiddenIdx <= #segments then
            local seg = segments[nextHiddenIdx]
            if seg and seg.hidden then
                -- 将该段放到最后可见段的旧位置（尾巴腾出的空间）
                seg.col = lastVisibleOldCol
                seg.row = lastVisibleOldRow
                seg.hidden = false
                -- 从洞口滑动到目标位置的动画
                local holeCol = state.sandWormEmergeHole and state.sandWormEmergeHole.col or oldCol
                local holeRow = state.sandWormEmergeHole and state.sandWormEmergeHole.row or oldRow
                seg.emergeFromCol = holeCol
                seg.emergeFromRow = holeRow
                seg.emergeDelay = 0.1  -- 略微延迟，紧跟尾巴移动后出现
                -- 更新计数
                boss.segmentsAboveGround = (boss.segmentsAboveGround or 3) + 1
            end
        end
    end
end

--- 沙虫传送后重排身体：头部已到新位置，身体段依次排列在头后面形成连续蛇形
local function SandWormReformBody(state, boss)
    local segments = state.sandWormSegments
    if not segments or #segments < 2 then return end

    -- 计算身体延伸方向：从英雄指向头部的方向（即远离英雄的方向）
    local hero = state.hero
    local hx, hy, hz = HexGrid.OffsetToCube(boss.col, boss.row)
    local ex, ey, ez = HexGrid.OffsetToCube(hero.col, hero.row)
    -- 方向向量（cube坐标下）：头部远离英雄的方向
    local dx, dy, dz = hx - ex, hy - ey, hz - ez
    -- 归一化到6方向之一（取绝对值最大的分量）
    local absDx, absDy, absDz = math.abs(dx), math.abs(dy), math.abs(dz)
    local maxAbs = math.max(absDx, absDy, absDz)
    if maxAbs > 0 then
        -- 四舍五入到最近的单位方向
        dx = math.floor(dx / maxAbs + 0.5)
        dy = math.floor(dy / maxAbs + 0.5)
        dz = math.floor(dz / maxAbs + 0.5)
        -- 修正确保 dx+dy+dz=0
        if dx + dy + dz ~= 0 then
            -- 找偏差最大的分量修正
            local rd = math.abs(dx - (hx - ex) / maxAbs)
            local rdy = math.abs(dy - (hy - ey) / maxAbs)
            local rdz = math.abs(dz - (hz - ez) / maxAbs)
            if rd >= rdy and rd >= rdz then
                dx = -dy - dz
            elseif rdy >= rdz then
                dy = -dx - dz
            else
                dz = -dx - dy
            end
        end
    else
        -- 英雄和头重合（不太可能），默认向下延伸
        dx, dy, dz = 0, -1, 1
    end

    -- 辅助函数：检查某格是否可放置身体段
    local function canPlaceAt(col, row, upToIndex)
        if not HexGrid.InBounds(col, row) then return false end
        if HexGrid.GetObstacleAt(state.board, col, row) then return false end
        -- 不能放在非自身棋子上
        local pieceAt = HexGrid.GetPieceAt(state.board, col, row)
        if pieceAt then
            local isSelf = false
            for k = 1, #segments do
                if segments[k] == pieceAt then isSelf = true; break end
            end
            if not isSelf then return false end
        end
        -- 不能放在已排好的前面身体段上
        for k = 1, upToIndex - 1 do
            if segments[k].col == col and segments[k].row == row then
                return false
            end
        end
        return true
    end

    -- 从第2段开始，沿直线方向延伸
    for i = 2, #segments do
        local prev = segments[i - 1]
        local seg = segments[i]
        -- 首选：沿主方向直线前进
        local px, py, pz = HexGrid.OffsetToCube(prev.col, prev.row)
        local nx, ny, nz = px + dx, py + dy, pz + dz
        local nc, nr = HexGrid.CubeToOffset(nx, ny, nz)
        if canPlaceAt(nc, nr, i) then
            seg.col, seg.row = nc, nr
        else
            -- 备选：从前一段的邻居中选最接近主方向的
            local neighbors = HexGrid.GetNeighbors(prev.col, prev.row)
            -- 按与主方向的一致程度排序
            table.sort(neighbors, function(a, b)
                local ax, ay, az = HexGrid.OffsetToCube(a.col, a.row)
                local bx, by, bz = HexGrid.OffsetToCube(b.col, b.row)
                local dax, day, daz = ax - px, ay - py, az - pz
                local dbx, dby, dbz = bx - px, by - py, bz - pz
                -- 点积（与主方向的余弦）
                local dotA = dax * dx + day * dy + daz * dz
                local dotB = dbx * dx + dby * dy + dbz * dz
                return dotA > dotB
            end)
            local placed = false
            for _, nb in ipairs(neighbors) do
                if canPlaceAt(nb.col, nb.row, i) then
                    seg.col, seg.row = nb.col, nb.row
                    placed = true
                    break
                end
            end
            if not placed then
                seg.col, seg.row = prev.col, prev.row
            end
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
    -- 不能移动到自己身体段所在格（避免自咬，隐藏段除外）
    if state.sandWormSegments then
        for _, seg in ipairs(state.sandWormSegments) do
            if seg ~= boss and not seg.hidden and seg.col == col and seg.row == row then return false end
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

    -- 冷却递减已由 TickBossCooldowns 统一处理

    -- 碎石障碍回合递减（2回合后消失）
    if state.boulderDebris then
        local remaining = {}
        for _, bd in ipairs(state.boulderDebris) do
            bd.turns = bd.turns - 1
            if bd.turns <= 0 then
                HexGrid.RemoveObstacle(state.board, bd.col, bd.row)
            else
                remaining[#remaining + 1] = bd
            end
        end
        state.boulderDebris = #remaining > 0 and remaining or nil
    end

    -- ══ 部分露出状态（头部移动时自动从洞口拖出身体段）══════════════════════
    if boss.emerging then
        local totalSegs = state.sandWormSegments and #state.sandWormSegments or 0
        local aboveGround = boss.segmentsAboveGround or 3
        if aboveGround >= totalSegs then
            -- 所有段都已钻出
            boss.emerging = false
            boss.segmentsAboveGround = nil
            state.sandWormEmergeHole = nil
            AddFloatingText(state, boss.col, boss.row, "🐛完全钻出!", {210, 180, 100, 255})
            AddLog(state, "沙丘巨虫完全从地下钻出！")
        end
        -- 正常行动（头部移动时 SandWormSnakeMove 会自动拖出隐藏段）
    end

    -- ══ 遁地读条阶段（Boss还在地面，准备钻入地下）══════════════════════
    if boss.burrowCasting then
        boss.burrowCasting = false
        -- 读条结束，正式遁地
        boss.burrowed = true
        boss.burrowTimer = 3  -- 地下3回合（第2回合显示预警，第3回合钻出）
        -- 连续钻入动画：整条虫身作为整体依次滑入同一洞口（头先入，身体紧随）
        local holeCol, holeRow = boss.col, boss.row
        if state.sandWormSegments then
            for i, seg in ipairs(state.sandWormSegments) do
                -- 短间隔(0.12s)让多段同时在运动中，看起来是连续整体
                seg.diveDelay = (i - 1) * 0.12
                -- 所有段都滑向同一洞口位置（形成被吸入的效果）
                seg.diveTargetCol = holeCol
                seg.diveTargetRow = holeRow
            end
        end
        -- 记录洞口位置（供渲染用）
        state.sandWormDiveHole = { col = holeCol, row = holeRow }
        AddFloatingText(state, boss.col, boss.row, "🕳️遁入地下!", {180, 140, 60, 255})
        AddVFX(state, "burrow_start", { col = boss.col, row = boss.row, duration = 1.8 })
        state.screenShake = (state.screenShake or 0) + 0.3
        AM.PlaySFX("boss_aoe", 0.7)
        AddLog(state, "沙丘巨虫钻入地下！地面开始震动...")
        return { type = "skill", enemy = boss, skill = "burrow_dive" }
    end

    -- ══ 遁地状态处理（Boss在地下，倒计时结束后钻出AOE）══════════════════
    if boss.burrowed then
        boss.burrowTimer = (boss.burrowTimer or 0) - 1

        -- 倒数第1回合（即将钻出前一回合）：显示红色描边预警
        if boss.burrowTimer == 1 and not state.sandWormEmergeWarning then
            -- 确定钻出目标位置（预警用，实际钻出时以此为准）
            -- 优先被稻草人嘲讽吸引
            local targetCol, targetRow = hero.col, hero.row
            if state.scarecrowActive and state.scarecrow and state.scarecrow.hp > 0 then
                targetCol, targetRow = state.scarecrow.col, state.scarecrow.row
            end
            -- 在目标身边2格范围内随机一个可钻出位置（宽松判断：只要求在棋盘内、无障碍物）
            -- 注：钻出是从地下突破，不受地面棋子阻挡
            local validSpots = {}
            for dc = -3, 3 do
                for dr = -3, 3 do
                    local c, r = targetCol + dc, targetRow + dr
                    local dist = HexGrid.CubeDistance(c, r, targetCol, targetRow)
                    if HexGrid.InBounds(c, r)
                       and dist <= 2
                       and dist >= 1
                       and not HexGrid.GetObstacleAt(state.board, c, r) then
                        validSpots[#validSpots + 1] = { col = c, row = r }
                    end
                end
            end
            -- 兜底：如果2格内没有空位，退回到相邻1格（仍然宽松判断）
            if #validSpots == 0 then
                local neighbors = HexGrid.GetNeighbors(targetCol, targetRow)
                for _, nb in ipairs(neighbors) do
                    if HexGrid.InBounds(nb.col, nb.row)
                       and not HexGrid.GetObstacleAt(state.board, nb.col, nb.row) then
                        validSpots[#validSpots + 1] = nb
                    end
                end
            end
            -- 最终兜底：直接选目标相邻的任意格子（忽略所有限制）
            if #validSpots == 0 then
                local neighbors = HexGrid.GetNeighbors(targetCol, targetRow)
                for _, nb in ipairs(neighbors) do
                    if HexGrid.InBounds(nb.col, nb.row) then
                        validSpots[#validSpots + 1] = nb
                        break
                    end
                end
            end
            local emergeSpot
            if #validSpots > 0 then
                emergeSpot = validSpots[math.random(1, #validSpots)]
            else
                -- 绝对兜底：在目标旁边1格
                local neighbors = HexGrid.GetNeighbors(targetCol, targetRow)
                emergeSpot = neighbors[1] or { col = targetCol, row = targetRow }
            end
            -- 保存预定钻出位置
            boss.emergeTargetCol = emergeSpot.col
            boss.emergeTargetRow = emergeSpot.row
            -- 设置红色描边预警（7格AOE范围）
            local warnTiles = { { col = emergeSpot.col, row = emergeSpot.row } }
            local warnNeighbors = HexGrid.GetNeighbors(emergeSpot.col, emergeSpot.row)
            for _, nb in ipairs(warnNeighbors) do
                if HexGrid.InBounds(nb.col, nb.row) then
                    warnTiles[#warnTiles + 1] = { col = nb.col, row = nb.row }
                end
            end
            state.sandWormEmergeWarning = {
                col = emergeSpot.col,
                row = emergeSpot.row,
                tiles = warnTiles,  -- 7格AOE预警范围
                timer = 99,  -- 持续到钻出时清除
            }
            AddFloatingText(state, emergeSpot.col, emergeSpot.row,
                "⚠️即将钻出!", {255, 80, 40, 255})
            AddLog(state, "地面出现裂缝！沙丘巨虫即将从此处钻出！(剩余1回合)")
            return { type = "wait", enemy = boss }
        end

        if boss.burrowTimer <= 0 then
            -- 钻出！
            boss.burrowed = false
            boss.hidden = false
            -- 使用预定位置（或重新计算）
            local emergeCol = boss.emergeTargetCol
            local emergeRow = boss.emergeTargetRow
            if not emergeCol then
                -- 兜底：重新计算（正常不会走到这里）
                local targetCol, targetRow = hero.col, hero.row
                if state.scarecrowActive and state.scarecrow and state.scarecrow.hp > 0 then
                    targetCol, targetRow = state.scarecrow.col, state.scarecrow.row
                end
                -- 选目标相邻1格（不直接重叠在目标身上）
                local neighbors = HexGrid.GetNeighbors(targetCol, targetRow)
                local picked = false
                for _, nb in ipairs(neighbors) do
                    if HexGrid.InBounds(nb.col, nb.row)
                       and not HexGrid.GetObstacleAt(state.board, nb.col, nb.row) then
                        emergeCol, emergeRow = nb.col, nb.row
                        picked = true
                        break
                    end
                end
                if not picked then
                    emergeCol, emergeRow = targetCol, targetRow
                end
            end
            boss.col, boss.row = emergeCol, emergeRow
            boss.emergeTargetCol = nil
            boss.emergeTargetRow = nil
            -- 清除预警标记
            state.sandWormEmergeWarning = nil
            -- 身体重新排列在头部后面（爬出动画：头部先爬出，身体从洞口拽出跟随）
            SandWormReformBody(state, boss)
            boss.emerging = true  -- 标记：后续回合逐步露出更多身体
            -- 确定洞口位置：选头部身后的格子作为洞口（身体第二节位置）
            local holeCol, holeRow = boss.col, boss.row
            if state.sandWormSegments and #state.sandWormSegments >= 2 then
                local seg2 = state.sandWormSegments[2]
                holeCol, holeRow = seg2.col, seg2.row
            end
            state.sandWormEmergeHole = { col = holeCol, row = holeRow }
            -- 钻出时只露出头+2节身子（共3段），其余隐藏在洞口
            local INITIAL_EMERGE = 3  -- 头 + 2节身体
            boss.segmentsAboveGround = INITIAL_EMERGE
            if state.sandWormSegments then
                for i, seg in ipairs(state.sandWormSegments) do
                    if i <= INITIAL_EMERGE then
                        seg.hidden = false
                        seg.emergeDelay = (i - 1) * 0.2
                        seg.emergeFromCol = holeCol
                        seg.emergeFromRow = holeRow
                    else
                        seg.hidden = true
                        seg.col = holeCol
                        seg.row = holeRow
                    end
                end
            end
            -- 对钻出格 + 周围1圈（共7格）造成AOE伤害
            local burrowDmg = boss.enraged and math.floor(boss.atk * 1.8) or math.floor(boss.atk * 1.2)
            -- 收集AOE范围内的所有格子（中心 + 6邻居）
            local aoeTiles = { { col = boss.col, row = boss.row } }
            local neighbors = HexGrid.GetNeighbors(boss.col, boss.row)
            for _, nb in ipairs(neighbors) do
                if HexGrid.InBounds(nb.col, nb.row) then
                    aoeTiles[#aoeTiles + 1] = { col = nb.col, row = nb.row }
                end
            end
            -- 检查英雄是否在AOE范围内
            local heroHit = false
            for _, tile in ipairs(aoeTiles) do
                if hero.col == tile.col and hero.row == tile.row then
                    heroHit = true
                    break
                end
            end
            if heroHit then
                hero.hp = hero.hp - burrowDmg
                AddFloatingText(state, hero.col, hero.row,
                    "🕳️-" .. burrowDmg .. "钻地突袭!", {180, 140, 60, 255}, "hit")
            end
            -- 7格AOE特效（每格都显示冲击波）
            for _, tile in ipairs(aoeTiles) do
                AddVFX(state, "burrow_aoe_hit", {
                    col = tile.col, row = tile.row,
                    duration = 0.7,
                })
            end
            -- AOE红光高亮（7格）
            state.sandWormEmergeAOE = {
                tiles = aoeTiles,
                timer = 1.2,
                maxTimer = 1.2,
            }
            BattleBoss.AddBossSkillAnnounce(state, "burrow_emerge", boss.name)
            AddVFX(state, "burrow_hole", { col = boss.col, row = boss.row, duration = 2.5 })
            AddVFX(state, "burrow_strike", { col = boss.col, row = boss.row, duration = 0.8 })
            state.screenShake = (state.screenShake or 0) + 1.2
            AM.PlaySFX("sandworm_burrow_emerge", 1.0)
            AddLog(state, string.format("沙丘巨虫从地下钻出！%s",
                heroHit and ("造成 " .. burrowDmg .. " 伤害！") or "英雄闪避成功！"))
            return { type = "skill", enemy = boss, skill = "burrow_emerge" }
        else
            -- 还在地下，不释放技能，只等待
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
        AM.PlaySFX("sandworm_burrow_emerge", 0.5)
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
        boss.tailWhipCooldown = boss.enraged and 3 or 5
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
        AM.PlaySFX("sandworm_tail_whip", 0.9)
        AddLog(state, string.format("沙丘巨虫尾鞭横扫！造成 %d 伤害并中断连跳！", whipDmg))
        return { type = "skill", enemy = boss, skill = "tail_whip" }
    end

    -- ── 呼唤风沙（独立技能，不消耗行动回合，释放后继续移动+攻击）──────────────
    if boss.sandFuryCooldown <= 0 and not state.sandFuryActive then
        boss.sandFuryCooldown = boss.enraged and 6 or 9
        state.sandFuryActive = true
        state.sandFuryTurns = 3
        state.sandFuryDmg = boss.enraged and math.floor(boss.atk * 0.6) or math.floor(boss.atk * 0.4)
        state.sandFuryBoss = boss
        BattleBoss.AddBossSkillAnnounce(state, "sand_fury", boss.name)
        AddFloatingText(state, boss.col, boss.row, "🌪️呼唤风沙!", {230, 160, 50, 255}, "combo")
        AddFloatingText(state, hero.col, hero.row,
            "🌪️风沙来袭!持续3回合", {230, 160, 50, 255})
        AddVFX(state, "sand_fury_start", { col = boss.col, row = boss.row, duration = 1.5 })
        state.screenShake = (state.screenShake or 0) + 0.5
        AM.PlaySFX("sandworm_sand_fury", 1.0)
        AddLog(state, "沙丘巨虫呼唤风沙！持续沙暴将笼罩全场3回合！")
        return { type = "skill", enemy = boss, skill = "sand_fury" }
    end

    -- ── 蛇形移动 + 普通攻击 ─────────────────────────────────────────
    -- 先移动一步靠近英雄
    local moveTarget = SandWormFindMoveTarget(state, boss)
    if moveTarget then
        SandWormSnakeMove(state, boss, moveTarget.col, moveTarget.row)
    elseif boss.emerging then
        -- 安全兜底：无法移动但仍在钻出状态，强制拖出一个隐藏段防止卡死
        local segments = state.sandWormSegments
        if segments then
            for i, seg in ipairs(segments) do
                if seg.hidden then
                    -- 放到最后一个可见段旁边
                    local lastVisible = segments[i - 1]
                    if lastVisible then
                        seg.col = lastVisible.col
                        seg.row = lastVisible.row
                        seg.hidden = false
                        seg.emergeFromCol = seg.col
                        seg.emergeFromRow = seg.row
                        boss.segmentsAboveGround = (boss.segmentsAboveGround or 3) + 1
                    end
                    break
                end
            end
        end
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
    -- 沙虫头弱体硬：身体段50%伤害路由到头部，打头130%伤害
    if boss.snakeHead then
        damage = math.floor(damage * 0.5)
        boss = boss.snakeHead
        AddFloatingText(state, boss.col, boss.row, "体硬×0.5", {180, 180, 180, 200})
    elseif boss.bossType == "sand_worm" and not boss.isSegment then
        damage = math.floor(damage * 1.3)
        AddFloatingText(state, boss.col, boss.row, "头弱×1.3!", {255, 80, 80, 255})
    end
    -- 遁地状态免疫伤害
    if boss.burrowed then
        AddFloatingText(state, boss.col, boss.row, "遁地中!", {150, 150, 150, 180})
        return
    end
    -- 单次伤害上限: 不超过 maxHp 的 40%，确保至少需要 3 次有效攻击
    local dmgCap = math.floor((boss.maxHp or boss.hp) * 0.4)
    if damage > dmgCap then
        damage = dmgCap
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
        boss.tookDamageThisTurn = true  -- 标记本回合受伤（珊瑚守卫被动回血判定用）
    end
end

-- ============================================================================
-- 第五章Boss: 永冻之王
-- 技能: 冰封领域(铺冰) / 冰甲凝聚(护盾) / 寒冰投枪(远程+冻结) / 暴风雪怒(狂暴)
-- ============================================================================

function BattleBoss.BossAct_FrostKing(state, boss)
    local hero = state.hero
    local IceMechanic = require "IceMechanic"

    -- 狂暴判定: HP<30% 进入P2
    if not boss.enraged and boss.hp <= boss.maxHp * 0.3 then
        boss.enraged = true
        boss.phase = 2
        AddFloatingText(state, boss.col, boss.row,
            "🔥永冻之怒!", {100, 180, 255, 255}, "combo", 2.0)
        AddLog(state, "⚠️ 永冻之王进入狂暴状态！攻击力提升，技能冷却缩短！")
        AM.PlaySFX("boss_enrage", 0.8)
        state.screenShake = (state.screenShake or 0) + 0.6
        -- 狂暴立即全场铺冰
        for r = 1, HexGrid.ROWS do
            for c = 1, HexGrid.COLS do
                if HexGrid.InBounds(c, r) and math.random(1, 100) <= 60 then
                    IceMechanic.AddIceTile(state, c, r)
                end
            end
        end
        AddVFX(state, "shockwave", { col = boss.col, row = boss.row, duration = 0.8 })
        return { type = "enrage", enemy = boss }
    end

    -- 技能优先级: 冰甲(护盾空时) > 冰封领域(冷却好) > 寒冰投枪 > 普攻

    -- === 冰甲凝聚: 护盾为0时生成护盾 ===
    if (boss.iceArmorCooldown or 0) <= 0 and (boss.shieldHp or 0) <= 0 then
        local shieldAmt = boss.shieldMax or 170
        if boss.enraged then shieldAmt = math.floor(shieldAmt * 1.3) end
        boss.shieldHp = shieldAmt
        boss.iceArmorCooldown = boss.enraged and 3 or 4

        AddFloatingText(state, boss.col, boss.row,
            "🛡️冰甲+" .. shieldAmt, {140, 210, 255, 255}, "combo", 1.5)
        AddLog(state, string.format("永冻之王凝聚冰甲！获得%d点护盾", shieldAmt))
        AddVFX(state, "shield_cast", { col = boss.col, row = boss.row, duration = 0.6 })
        AM.PlaySFX("shield_ward", 0.8)
        return { type = "ice_armor", enemy = boss }
    end

    -- === 冰封领域: 在英雄周围铺设冰面 ===
    if (boss.iceFieldCooldown or 0) <= 0 then
        local placed = 0
        for r = 1, HexGrid.ROWS do
            for c = 1, HexGrid.COLS do
                if HexGrid.InBounds(c, r) then
                    local distToHero = HexGrid.CubeDistance(c, r, hero.col, hero.row)
                    if distToHero <= 2 and not IceMechanic.IsIceTile(state, c, r) then
                        if math.random(1, 100) <= 70 then
                            IceMechanic.AddIceTile(state, c, r)
                            placed = placed + 1
                        end
                    end
                end
            end
        end
        boss.iceFieldCooldown = boss.enraged and 2 or 3

        AddFloatingText(state, hero.col, hero.row,
            "❄冰封领域!", {100, 180, 240, 255}, "combo", 1.5)
        AddLog(state, string.format("永冻之王释放冰封领域！你脚下%d格被冻结", placed))
        AM.PlaySFX("hero_damage", 0.5, 1.5)
        state.screenShake = (state.screenShake or 0) + 0.2
        return { type = "ice_field", enemy = boss }
    end

    -- === 寒冰投枪: 远程攻击+冻结1回合 ===
    if (boss.iceSpearCooldown or 0) <= 0 then
        local range = boss.attackRange or 2
        local dist = HexGrid.CubeDistance(boss.col, boss.row, hero.col, hero.row)
        if dist <= range + 1 then  -- 投枪比普攻远1格
            local baseDmg = boss.atk
            if boss.enraged then baseDmg = math.floor(baseDmg * 1.4) end
            local actualDmg = B().CalcEnemyDmg(baseDmg, hero.def or 0)

            if state.hasShield then
                actualDmg = math.floor(actualDmg / 2)
                state.hasShield = false
                AddFloatingText(state, hero.col, hero.row, "🛡️挡!", {120, 180, 255, 255})
            end
            if (hero._shield or 0) > 0 and actualDmg > 0 then
                local absorbed = math.min(hero._shield, actualDmg)
                actualDmg = actualDmg - absorbed
                hero._shield = hero._shield - absorbed
            end

            hero.hp = hero.hp - actualDmg
            state.hitFlash = 0.3
            state._heroFrozenTurns = (state._heroFrozenTurns or 0) + 1

            boss.iceSpearCooldown = boss.enraged and 2 or 3
            AddFloatingText(state, hero.col, hero.row,
                "🔱投枪-" .. actualDmg .. "+❄冻结", {80, 160, 240, 255}, "hit")
            AddLog(state, string.format("永冻之王投掷寒冰枪！-%d 并冻结你1回合", actualDmg))
            AM.PlaySFX("hero_damage")
            state.screenShake = (state.screenShake or 0) + 0.35
            AddVFX(state, "freeze_ray", {
                fromCol = boss.col, fromRow = boss.row,
                toCol = hero.col, toRow = hero.row,
                duration = 0.4,
            })
            return { type = "ice_spear", enemy = boss, damage = actualDmg }
        end
    end

    -- 普攻/移动
    local atk = BattleBoss.BossBasicAttack(state, boss)
    if atk then return atk end
    return BattleBoss.BossMoveToHero(state, boss)
end


return BattleBoss
