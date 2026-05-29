-- ============================================================================
-- Skills.lua - 吸血鬼幸存者风格技能系统
-- 12 独立基础技能 (Lv1-Lv5) + 6 组合技 (前置均 Lv5 自动激活)
-- ============================================================================

local Skills = {}

-- ============================================================================
-- 稀有度系统
-- ============================================================================

Skills.RARITY = {
    COMMON    = 1,  -- 蓝色 - 普通
    RARE      = 2,  -- 紫色 - 稀有
    EPIC      = 3,  -- 金色 - 史诗
    LEGENDARY = 4,  -- 红色 - 传说
}

Skills.RARITY_META = {
    [1] = { label = "普通", color = {100, 180, 255}, borderWidth = 1.5, glow = false },
    [2] = { label = "稀有", color = {180, 100, 255}, borderWidth = 2.0, glow = false },
    [3] = { label = "史诗", color = {255, 200, 50},  borderWidth = 2.5, glow = true },
    [4] = { label = "传说", color = {255, 60, 60},   borderWidth = 3.0, glow = true },
}

-- ============================================================================
-- 15 个基础技能定义
-- owned 结构: { quake_land = 3, chain_lightning = 5, ... }  (id -> 等级)
-- rarity[lv] = 升到该等级时的稀有度
-- ============================================================================

Skills.SKILLS = {
    -- 1. 震地落 - AOE 范围伤害
    quake_land = {
        name = "震地落",
        icon = "skill_quake_land",
        color = {220, 140, 40},
        maxLevel = 5,
        rarity = {1, 1, 2, 3, 4},  -- Lv3范围扩大=稀有, Lv4全场AOE=史诗, Lv5碎甲=传说
        desc = function(lv)
            local dmg = 6 + lv * 2          -- Lv1=8, Lv2=10, Lv3=12, Lv4=14, Lv5=16
            local range = lv >= 3 and 2 or 1
            local extra = ""
            if lv >= 4 then extra = extra .. "；连跳≥3全场AOE" end
            if lv >= 5 then extra = extra .. "；碎甲(DEF减半1回合)" end
            return string.format("跳跃落地时对周围%d圈敌人造成%d伤害%s", range, dmg, extra)
        end,
    },

    -- 2. 连锁闪电 - 弹射伤害
    chain_lightning = {
        name = "连锁闪电",
        icon = "skill_chain_lightning",
        color = {100, 180, 255},
        maxLevel = 5,
        rarity = {1, 1, 2, 3, 4},  -- Lv3毒雾电击=稀有, Lv4高弹射=史诗, Lv5雷爆=传说
        desc = function(lv)
            local dmg = 13 + lv * 2          -- Lv1=15, Lv2=17, Lv3=19, Lv4=21, Lv5=23
            local bounces = lv              -- Lv1=1, Lv2=2, ..., Lv5=5
            local extra = ""
            if lv >= 3 then extra = extra .. "；毒雾电击相邻敌人" end
            if lv >= 5 then extra = extra .. "；弹射后雷爆(范围10伤)" end
            return string.format("击杀敌人时闪电弹射%d次，每次%d伤%s", bounces, dmg, extra)
        end,
    },

    -- 3. 吸血跳 - 击杀回复
    vampiric_jump = {
        name = "吸血跳",
        icon = "skill_vampiric_jump",
        color = {200, 50, 50},
        maxLevel = 5,
        rarity = {1, 1, 2, 3, 4},  -- Lv3连击回复=稀有, Lv4暗血=史诗, Lv5永久ATK=传说
        desc = function(lv)
            local pct = 5 + lv * 3           -- Lv1=8%, Lv2=11%, Lv3=14%, Lv4=17%, Lv5=20%
            local extra = ""
            if lv >= 3 then extra = extra .. "；连击击杀+5临时ATK+12HP（上限+30ATK）" end
            if lv >= 5 then extra = extra .. "；HP>80%时附带ATK×20%真实伤害" end
            return string.format("跳杀敌人时回复%d%%伤害为生命%s", pct, extra)
        end,
    },

    -- 5. 荆棘护甲 - 反伤 / 防御
    thorns = {
        name = "荆棘护甲",
        icon = "skill_thorns",
        color = {80, 200, 120},
        maxLevel = 5,
        rarity = {1, 1, 2, 2, 3},  -- 防御技能，最高史诗
        desc = function(lv)
            local pct = 20 + lv * 8          -- Lv1=28%, Lv2=36%, ..., Lv5=60%
            local extra = ""
            if lv >= 3 then extra = extra .. "；反弹→治疗50%；被攻+3护盾" end
            if lv >= 5 then extra = extra .. "；护盾>10反弹+20%" end
            return string.format("受到攻击时反弹%d%%伤害给敌人%s", pct, extra)
        end,
    },

    -- 7. (已删除: bounty_hunter 赏金猎人)

    -- 8. (已删除: frost_land 霜降)

    -- 9. 地刺陷阱 - 路径布控
    spike_trap = {
        name = "地刺陷阱",
        icon = "skill_spike_trap",
        color = {180, 100, 80},
        maxLevel = 5,
        rarity = {1, 1, 2, 2, 3},  -- 控制技能，最高史诗
        desc = function(lv)
            local dmg = 5 + lv * 5           -- Lv1=10, Lv2=15, ..., Lv5=30
            local dur = 2 + math.floor(lv / 2) -- Lv1=2, Lv2=3, Lv3=3, Lv4=4, Lv5=4
            local extra = ""
            if lv >= 3 then extra = extra .. "；减速1回合" end
            if lv >= 5 then extra = extra .. "；踩刺敌人受全伤害+20%" end
            return string.format("跳跃路径空格变地刺(%d伤,持续%d回合)%s", dmg, dur, extra)
        end,
    },

    -- 10. 血怒 - 低血量爆发
    blood_rage = {
        name = "血怒",
        icon = "skill_blood_rage",
        color = {180, 30, 30},
        maxLevel = 5,
        rarity = {1, 1, 2, 3, 4},  -- Lv5免死+ATK翻倍=传说
        desc = function(lv)
            local threshold = lv >= 5 and 30 or 50
            local atkBonus = 20 + lv * 6     -- Lv1=26%, Lv2=32%, ..., Lv5=50%
            local extra = ""
            if lv >= 5 then extra = extra .. "；ATK翻倍；免疫一次致死" end
            return string.format("生命值低于%d%%时，攻击力提升%d%%%s", threshold, atkBonus, extra)
        end,
    },

    -- 11. 重力践踏 - 连跳高伤
    gravity_stomp = {
        name = "重力践踏",
        icon = "skill_gravity_stomp",
        color = {160, 130, 80},
        maxLevel = 5,
        rarity = {1, 1, 2, 3, 4},  -- Lv4连跳上限=史诗, Lv5极限倍率=传说
        desc = function(lv)
            local bonus = 50 + lv * 30       -- Lv1=80%, ..., Lv5=200%
            local extra = ""
            if lv >= 4 then extra = extra .. "；连跳加成上限提升至+200%（最高×3）" end
            if lv >= 5 then extra = extra .. "；重击加成提升至+200%（即基伤×3）" end
            return string.format("连续跳杀≥3次时，伤害提升%d%%%s", bonus, extra)
        end,
    },

    -- 12. 分裂弹 - 击杀扩散
    split_shot = {
        name = "分裂弹",
        icon = "skill_split_shot",
        color = {80, 200, 220},
        maxLevel = 5,
        desc = function(lv)
            local count = 1 + math.floor(lv / 2) -- Lv1=1, Lv2=2, Lv3=2, Lv4=3, Lv5=3
            local dmg = 5 + lv * 5               -- Lv1=10, Lv2=15, ..., Lv5=30
            local extra = ""
            if lv >= 3 then extra = extra .. "；碎片穿透(伤害不递减)" end
            if lv >= 5 then extra = extra .. "；碎片击杀再分裂1次" end
            return string.format("击杀时发射%d枚碎片，每枚%d伤害%s", count, dmg, extra)
        end,
    },

    -- 新技能: 猎手印记 - 标记高血量敌人
    hunter_mark = {
        name = "猎手印记",
        icon = "skill_hunter_mark",
        color = {255, 120, 60},
        maxLevel = 5,
        desc = function(lv)
            local bonus = 20 + lv * 7        -- Lv1=+27%, Lv2=+34%, ..., Lv5=+55%
            local marks = lv >= 4 and 2 or 1
            local extra = ""
            if lv >= 3 then extra = extra .. "；印记敌人被击回复5HP" end
            if lv >= 5 then extra = extra .. "；击杀印记敌人回复15%最大HP" end
            return string.format("自动标记血量最高的%d个敌人，对其伤害+%d%%%s", marks, bonus, extra)
        end,
    },

    -- 新技能: 连击护盾 - 防御累积
    combo_shield = {
        name = "连击护盾",
        icon = "skill_combo_shield",
        color = {60, 160, 220},
        maxLevel = 5,
        desc = function(lv)
            local perStack = 2 + lv * 2       -- Lv1=4, Lv2=6, Lv3=8, Lv4=10, Lv5=12
            local shieldCap = 10 + lv * 10    -- Lv1=20, Lv2=30, Lv3=40, Lv4=50, Lv5=60
            local extra = string.format("(上限%d)", shieldCap)
            if lv >= 3 then extra = extra .. "；未消耗时回合结束反弹30%给周围敌人" end
            if lv >= 5 then extra = extra .. "；5连击护盾翻倍" end
            return string.format("每次跳跃+%d护盾(吸收伤害)%s", perStack, extra)
        end,
    },
    -- 13. 玻璃大炮 - 牺牲生命换取伤害
    glass_cannon = {
        name = "玻璃大炮",
        icon = "skill_glass_cannon",
        color = {255, 100, 50},
        maxLevel = 5,
        desc = function(lv)
            local hpReduce = 10 + lv * 5     -- Lv1=-15%, Lv2=-20%, ..., Lv5=-35%
            local atkBoost = 15 + lv * 5     -- Lv1=+20%, Lv2=+25%, ..., Lv5=+40%
            return string.format("最大HP减少%d%%，攻击力永久提升%d%%", hpReduce, atkBoost)
        end,
    },

    -- 14. 黎明使者 - 免死一次
    dawn_herald = {
        name = "黎明使者",
        icon = "skill_dawn_herald",
        color = {255, 200, 80},
        maxLevel = 1,
        desc = function(lv)
            return "首次受到致命伤害时不会死亡，恢复至30%HP（每次冒险仅一次）"
        end,
    },

    -- 15. 踏步斩 - 移动时顺手打出近战攻击
    step_strike = {
        name = "踏步斩",
        icon = "skill_step_strike",
        color = {220, 80, 120},
        maxLevel = 5,
        desc = function(lv)
            local dmg = 5 + lv * 5             -- Lv1=10, Lv2=15, Lv3=20, Lv4=25, Lv5=30
            return string.format("每次移动时对1个相邻敌人造成%d点近战伤害", dmg)
        end,
    },

    -- 16. 收集者 - 对残血敌人额外伤害
    collector = {
        name = "收集者",
        icon = "skill_collector",
        color = {180, 120, 200},
        maxLevel = 5,
        desc = function(lv)
            local threshold = 30 + lv * 5    -- Lv1=<35%, Lv2=<40%, ..., Lv5=<55%
            local bonus = lv == 5 and 50 or (20 + lv * 10)  -- Lv1=+30%, Lv2=+40%, Lv3=+50%, Lv4=+60%, Lv5=+50%(上限)
            return string.format("对生命值低于%d%%的敌人造成额外%d%%伤害", threshold, bonus)
        end,
    },
}

-- ============================================================================
-- 6 个组合技定义
-- 解锁条件：两个前置技能均达到 maxLevel (Lv5) 时自动激活
-- ============================================================================

Skills.COMBOS = {
    {
        id = "combo_thunder_quake",
        name = "雷震天罚",
        icon = "skill_combo_storm",
        color = {160, 160, 40},
        desc = "AOE击中敌人50%触发闪电(15伤)",
        requires = {"chain_lightning", "quake_land"},
    },
    {
        id = "combo_blood_thorns",
        name = "血棘共生",
        icon = "skill_combo_thorn",
        color = {180, 80, 80},
        desc = "反弹50%→治疗；HP<50%反弹+20%",
        requires = {"vampiric_jump", "thorns"},
    },

}

-- ============================================================================
-- 核心 API
-- ============================================================================

--- 检查技能等级（0=未拥有，1~5=已拥有等级）
--- 0 在 Lua 中为 falsy? 不，0 在 Lua 中是 truthy!
--- 因此我们用 nil 表示未拥有，兼容 if Skills.Has(...) 判断
---@param owned table  {skillId = level, ...}
---@param id string    技能id
---@return number|nil  等级(1~5) 或 nil(未拥有)
function Skills.Has(owned, id)
    local lv = owned[id]
    if lv and lv > 0 then return lv end
    return nil
end

--- 获取技能等级（语法糖，未拥有返回0）
---@param owned table  {skillId = level, ...}
---@param id string    技能id
---@return number      等级(0~5)
function Skills.Level(owned, id)
    return owned[id] or 0
end

--- 根据id获取技能定义
---@param id string
---@return table|nil
function Skills.GetDef(id)
    return Skills.SKILLS[id]
end

--- 获取当前已激活的组合技
---@param owned table  {skillId = level, ...}
---@return table[]     激活的组合技定义列表
function Skills.GetActiveCombos(owned)
    local result = {}
    for _, combo in ipairs(Skills.COMBOS) do
        local allMax = true
        for _, req in ipairs(combo.requires) do
            local def = Skills.SKILLS[req]
            local maxLv = def and def.maxLevel or 5
            if (owned[req] or 0) < maxLv then
                allMax = false
                break
            end
        end
        if allMax then
            result[#result + 1] = combo
        end
    end
    return result
end

--- 检查指定组合技是否激活
---@param owned table
---@param comboId string
---@return boolean
function Skills.HasCombo(owned, comboId)
    local combos = Skills.GetActiveCombos(owned)
    for _, c in ipairs(combos) do
        if c.id == comboId then return true end
    end
    return false
end

--- 选择升级：技能等级+1
---@param owned table  当前技能 {id=level}
---@param skillId string  要升级的技能id
---@return table       新的技能表(浅拷贝)
function Skills.SelectUpgrade(owned, skillId)
    local newOwned = {}
    for k, v in pairs(owned) do newOwned[k] = v end
    local def = Skills.SKILLS[skillId]
    if not def then return newOwned end
    local cur = newOwned[skillId] or 0
    if cur < def.maxLevel then
        newOwned[skillId] = cur + 1
    end
    return newOwned
end

--- 从技能池中随机挑选 count 个候选技能（未满级的）
--- 返回 choice = {id, skill, currentLevel, nextLevel}
---@param owned table  当前技能 {id=level}
---@param count number 需要几个(默认3)
---@return table[]     候选列表
function Skills.PickChoices(owned, count)
    count = count or 3
    local pool = {}
    for id, def in pairs(Skills.SKILLS) do
        if not def.disabled then
            local curLv = owned[id] or 0
            if curLv < def.maxLevel then
                pool[#pool + 1] = {
                    id = id,
                    skill = def,
                    currentLevel = curLv,
                    nextLevel = curLv + 1,
                }
            end
        end
    end
    -- Fisher-Yates 洗牌
    for i = #pool, 2, -1 do
        local j = math.random(1, i)
        pool[i], pool[j] = pool[j], pool[i]
    end
    local choices = {}
    for i = 1, math.min(count, #pool) do
        choices[i] = pool[i]
    end
    return choices
end

--- 获取已拥有技能的图标列表（用于HUD展示）
---@param owned table  {skillId = level, ...}
---@return string      拼接的图标字符串
function Skills.GetOwnedIcons(owned)
    local names = {}
    -- 收集已拥有的基础技能名称
    for id, lv in pairs(owned) do
        if lv > 0 then
            local def = Skills.SKILLS[id]
            if def then
                names[#names + 1] = def.name .. "Lv" .. lv
            end
        end
    end
    -- 加上激活的组合技名称
    local combos = Skills.GetActiveCombos(owned)
    for _, combo in ipairs(combos) do
        names[#names + 1] = combo.name
    end
    return table.concat(names, " | ")
end

--- 获取接近解锁的组合技（前置之一已 Lv4+）
---@param owned table  {skillId = level, ...}
---@return table[]     接近解锁的组合技列表（含 progress 信息）
function Skills.GetNearCombos(owned)
    local result = {}
    for _, combo in ipairs(Skills.COMBOS) do
        local totalReq = #combo.requires
        local metCount = 0
        local nearCount = 0
        for _, req in ipairs(combo.requires) do
            local lv = owned[req] or 0
            local def = Skills.SKILLS[req]
            local maxLv = def and def.maxLevel or 5
            if lv >= maxLv then
                metCount = metCount + 1
            elseif lv >= 4 then
                nearCount = nearCount + 1
            end
        end
        -- 至少一个满级或接近满级，但尚未全部满级
        if metCount < totalReq and (metCount + nearCount) > 0 then
            result[#result + 1] = {
                combo = combo,
                metCount = metCount,
                totalReq = totalReq,
            }
        end
    end
    return result
end

--- 获取基础技能总数
function Skills.GetTotalSkillCount()
    local count = 0
    for _ in pairs(Skills.SKILLS) do
        count = count + 1
    end
    return count
end

return Skills
