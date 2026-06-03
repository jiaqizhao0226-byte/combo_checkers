-- ============================================================================
-- SetEffects.lua - 套装效果系统 v4.0
-- 封装2套金色套装的机制效果，供 Battle.lua 调用
-- 只有金色装备计入套装件数，4/6 = 一阶, 6/6 = 二阶
-- ============================================================================

local SetEffects = {}

local Equipment = require "Equipment"

-- ============================================================================
-- 初始化：每场战斗开始时调用，读取玩家装备，缓存激活的套装
-- ============================================================================

--- 初始化套装效果状态
--- @param playerEquipment table PlayerData.equipment (6槽位)
--- @param critRate number 暴击率(百分比整数, 如 15)
--- @return table setEffectState 套装效果运行时状态
function SetEffects.Init(playerEquipment, critRate)
    local effects = Equipment.GetActiveSetEffects(playerEquipment)
    local state = {
        effects = effects,               -- 激活的套装效果列表
        critRate = critRate or 0,         -- 暴击率
        -- 飞跃先锋
        leapTier = Equipment.GetSetTier(playerEquipment, "leap_pioneer"),
        freeJumpAvailable = false,        -- 是否有免费额外跳
        -- 连击心得
        comboMasteryTier = Equipment.GetSetTier(playerEquipment, "combo_mastery"),
        -- 猎魂·嗜血
        soulHunterTier = Equipment.GetSetTier(playerEquipment, "soul_hunter"),
        bloodRageStacks = 0,             -- 血怒叠层（最多3层）
    }
    return state
end

--- 是否有任何套装效果激活
function SetEffects.HasAnyEffect(seState)
    return seState and #seState.effects > 0
end

--- 获取所有激活效果的摘要（用于UI展示）
function SetEffects.GetSummary(seState)
    if not seState then return {} end
    local summary = {}
    for _, eff in ipairs(seState.effects) do
        local desc = eff.tier == 6 and eff.setDef.desc6 or eff.setDef.desc4
        summary[#summary + 1] = {
            name = eff.setDef.name,
            icon = eff.setDef.icon,
            tier = eff.tier,
            desc = desc,
        }
    end
    return summary
end

-- ============================================================================
-- 套装1: 飞跃先锋 🦅 — 跳连续敌人
-- ============================================================================

--- 获取可跳过的最大连续敌人数
function SetEffects.GetMaxJumpOverCount(seState)
    if not seState or seState.leapTier == 0 then
        return 1  -- 默认只能跳1个
    end
    if seState.leapTier >= 6 then
        return 3  -- 6/6: 可跳过3个连续敌人
    end
    return 2  -- 4/6: 可跳过2个连续敌人
end

-- ============================================================================
-- 套装2: 连击心得 🔥 — 连跳链结算后概率combo+1/+2
-- ============================================================================

--- 连跳链全部执行完毕后调用
--- @return number comboBonus 额外增加的combo数(0/1)
--- @return string|nil floatText
function SetEffects.OnComboChainComplete(seState, currentCombo)
    if not seState or seState.comboMasteryTier == 0 then
        return 0, nil
    end

    local tier = seState.comboMasteryTier
    local bonus = 0

    if tier >= 6 then
        -- 6/6: 75% combo+1
        if math.random(1, 100) <= 75 then
            bonus = 1
        end
    else
        -- 4/6: 50% combo+1
        if math.random(1, 100) <= 50 then
            bonus = 1
        end
    end

    if bonus <= 0 then
        return 0, nil
    end

    local text = "🔥连击+" .. bonus .. "!"
    return bonus, text
end

-- ============================================================================
-- 套装3: 猎魂·嗜血 🩸 — 击杀回血 + 血怒
-- ============================================================================

--- 击杀敌人时调用（isShard=true 的碎片不触发）
--- @param hero table 英雄对象 {hp, maxHp}
--- @param isShard boolean 是否是碎片敌人
--- @return number healAmt 实际回血量
--- @return string|nil floatText 浮动文字
--- @return boolean bloodRageTriggered 是否触发血怒
function SetEffects.OnKillHeal(seState, hero, isShard)
    if not seState or seState.soulHunterTier == 0 then
        return 0, nil, false
    end
    if isShard then
        return 0, nil, false
    end

    -- 4/6+: 击杀回血 = 3 + floor(maxHp * 1.5%)
    local baseHeal = 3 + math.floor((hero.maxHp or 100) * 0.015)
    local actualHeal = math.min(hero.maxHp - hero.hp, baseHeal)
    local bloodRageTriggered = false

    -- 6/6: HP < 50% 时额外触发血怒（最多3层）
    if seState.soulHunterTier >= 6 then
        local hpPct = hero.hp / (hero.maxHp or 100)
        if hpPct < 0.5 and seState.bloodRageStacks < 3 then
            seState.bloodRageStacks = seState.bloodRageStacks + 1
            bloodRageTriggered = true
        end
    end

    local text
    if bloodRageTriggered then
        text = string.format("🩸+%d 血怒x%d!", actualHeal > 0 and actualHeal or 0, seState.bloodRageStacks)
    elseif actualHeal > 0 then
        text = "🩸+" .. actualHeal
    end

    return actualHeal, text, bloodRageTriggered
end

--- 计算血怒给当前跳跃的ATK加成倍率，并消耗1层
--- @return number atkMult 额外攻击倍率（如1.5表示原伤×1.5），无血怒则返回1.0
--- @return string|nil floatText
function SetEffects.ConsumeBloodRage(seState)
    if not seState or seState.bloodRageStacks <= 0 then
        return 1.0, nil
    end
    seState.bloodRageStacks = seState.bloodRageStacks - 1
    local text = "🩸血怒! ATKx1.5"
    return 1.5, text
end

-- ============================================================================
-- 暴击判定（独立于套装，但放这里集中管理战斗效果）
-- ============================================================================

--- 判定是否暴击
--- @param critRate number 暴击率(百分比整数)
--- @return boolean isCrit
function SetEffects.RollCrit(critRate)
    if critRate <= 0 then return false end
    return math.random(1, 100) <= critRate
end

--- 暴击伤害倍率
SetEffects.CRIT_MULTIPLIER = 1.5

return SetEffects
