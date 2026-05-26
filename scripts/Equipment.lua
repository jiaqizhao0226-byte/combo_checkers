-- ============================================================================
-- Equipment.lua - 装备系统 v4.0
-- 3品阶（蓝/紫/金）× 2套装 × 6件 = 12件装备
-- 蓝/紫 = 纯数值加成，金色 = 数值 + 套装效果(4/6一阶, 6/6二阶)
-- ============================================================================

local Equipment = {}

-- ============================================================================
-- 槽位定义
-- ============================================================================

Equipment.SLOT_ORDER = { "weapon", "necklace", "helmet", "top_armor", "bottom_armor", "shoes" }

Equipment.SLOT_NAMES = {
    weapon       = "武器",
    necklace     = "项链",
    helmet       = "头盔",
    top_armor    = "上衣",
    bottom_armor = "下衣",
    shoes        = "鞋子",
}

Equipment.SLOT_ICONS = {
    weapon       = "equip_weapon",
    necklace     = "equip_accessory",
    helmet       = "equip_helmet",
    top_armor    = "equip_armor",
    bottom_armor = "equip_pants",
    shoes        = "equip_boots",
}

-- ============================================================================
-- 品阶定义 (v4.0: 蓝/紫/金 三级)
-- ============================================================================

Equipment.RARITIES = {
    { id = "blue",   name = "蓝色", color = {100, 180, 255, 255}, weight = 75 },
    { id = "purple", name = "紫色", color = {200, 120, 255, 255}, weight = 22 },
    { id = "gold",   name = "金色", color = {255, 215, 0,   255}, weight = 3  },
}

Equipment.RARITY_MULT = {
    blue   = 1.0,
    purple = 1.8,
    gold   = 3.0,
}

Equipment.RARITY_DECOMPOSE = {
    blue   = 5,
    purple = 15,
    gold   = 50,
}

--- 品阶排序权重（用于背包排序）
Equipment.RARITY_SORT = {
    blue   = 1,
    purple = 2,
    gold   = 3,
}

-- 兼容旧存档品阶映射
Equipment.RARITY_MIGRATE = {
    common = "blue",
    rare   = "blue",
    epic   = "purple",
}

-- ============================================================================
-- 套装定义 (v4.0: 3套金色套装, 只有金色触发效果)
-- ============================================================================

Equipment.SETS = {
    {
        id = "leap_pioneer", name = "金色套装-飞跃先锋", icon = "🦅",
        color = {80, 200, 120, 255},
        -- 金4/6: 可跳过2个相连敌人
        -- 金6/6: 可跳过3个相连敌人
        desc4 = "可跳过2连续敌人",
        desc6 = "可跳过3连续敌人",
        effectType = "leap_upgrade",
    },

    {
        id = "combo_mastery", name = "金色套装-连击心得", icon = "🔥",
        color = {255, 140, 40, 255},
        -- 金4/6: 连跳链结算后30%概率combo+1
        -- 金6/6: 75%概率combo+1
        desc4 = "30%概率combo+1",
        desc6 = "75%概率combo+1",
        effectType = "combo_boost",
    },

    {
        id = "soul_hunter", name = "金色套装-嗜血猎魂", icon = "🩸",
        color = {220, 40, 60, 255},
        -- 金4/6: 每击杀一个敌人回复少量HP
        -- 金6/6: HP<50%时击杀触发「血怒」，下一跳ATK+50%，最多叠3层
        desc4 = "击杀回血",
        desc6 = "低血触发血怒叠层",
        effectType = "kill_heal",
    },
}

--- 获取套装定义
function Equipment.GetSetDef(setId)
    if not setId then return nil end
    for _, s in ipairs(Equipment.SETS) do
        if s.id == setId then return s end
    end
    return nil
end

-- ============================================================================
-- 装备定义 (base stats 为蓝色数值，紫/金按倍率缩放)
-- ============================================================================

Equipment.ITEMS = {
    -- ==================== 套装1: 飞跃先锋 🦅 ====================
    { id = "leap_axe",       name = "先锋战斧", nameBlue = "铁斧",   namePurple = "精钢斧",   icon = "🦅", iconId = "equip_item_frost",  slot = "weapon",       setId = "leap_pioneer",  stats = { atk = 7 },  desc = "开拓者的巨斧" },
    { id = "leap_charm",     name = "先锋护符", nameBlue = "木护符", namePurple = "翡翠护符", icon = "🦅", iconId = "equip_item_frost",  slot = "necklace",     setId = "leap_pioneer",  stats = { hp = 25 },  desc = "先锋之力护符" },
    { id = "leap_helm",      name = "先锋角盔", nameBlue = "皮盔",   namePurple = "银角盔",   icon = "🦅", iconId = "equip_item_frost",  slot = "helmet",       setId = "leap_pioneer",  stats = { def = 5 },  desc = "冲锋号角头盔" },
    { id = "leap_plate",     name = "先锋铠甲", nameBlue = "链甲",   namePurple = "秘银甲",   icon = "🦅", iconId = "equip_item_frost",  slot = "top_armor",    setId = "leap_pioneer",  stats = { def = 6 },  desc = "先锋者的重甲" },
    { id = "leap_guards",    name = "先锋战裙", nameBlue = "布裙甲", namePurple = "锁环裙甲", icon = "🦅", iconId = "equip_item_frost",  slot = "bottom_armor", setId = "leap_pioneer",  stats = { hp = 20 },  desc = "先锋者的裙甲" },
    { id = "leap_boots",     name = "先锋跃靴", nameBlue = "草鞋",   namePurple = "疾风靴",   icon = "🦅", iconId = "equip_item_frost",  slot = "shoes",        setId = "leap_pioneer",  stats = { atk = 3 },  desc = "弹跳增强之靴" },

    -- ==================== 套装2: 连击心得 🔥 ====================
    { id = "combo_sword",    name = "心得之剑", nameBlue = "短剑",   namePurple = "利刃剑",   icon = "🔥", iconId = "equip_item_health_ring", slot = "weapon",       setId = "combo_mastery", stats = { atk = 4 },  desc = "领悟连击的剑" },
    { id = "combo_trinket",  name = "心得挂饰", nameBlue = "铜挂饰", namePurple = "琥珀挂饰", icon = "🔥", iconId = "equip_item_health_ring", slot = "necklace",     setId = "combo_mastery", stats = { hp = 18 },  desc = "连击经验之饰" },
    { id = "combo_band",     name = "心得发带", nameBlue = "麻发带", namePurple = "丝绒发带", icon = "🔥", iconId = "equip_item_health_ring", slot = "helmet",       setId = "combo_mastery", stats = { def = 3 },  desc = "专注连击的发带" },
    { id = "combo_vest",     name = "心得战衣", nameBlue = "粗布衣", namePurple = "织锦衣",   icon = "🔥", iconId = "equip_item_health_ring", slot = "top_armor",    setId = "combo_mastery", stats = { def = 3 },  desc = "轻便的战斗衣" },
    { id = "combo_belt",     name = "心得腰带", nameBlue = "皮腰带", namePurple = "镶石腰带", icon = "🔥", iconId = "equip_item_health_ring", slot = "bottom_armor", setId = "combo_mastery", stats = { hp = 12 },  desc = "连击者的腰带" },
    { id = "combo_kicks",    name = "心得快靴", nameBlue = "布靴",   namePurple = "轻羽靴",   icon = "🔥", iconId = "equip_item_health_ring", slot = "shoes",        setId = "combo_mastery", stats = { atk = 3 },  desc = "快速反应之靴" },

    -- ==================== 套装3: 猎魂·嗜血 🩸 ====================
    { id = "soul_scythe",    name = "猎魂镰",   nameBlue = "铁镰刀", namePurple = "猩红镰刀", icon = "🩸", iconId = "equip_item_health_ring", slot = "weapon",       setId = "soul_hunter",   stats = { atk = 6 },  desc = "饮血方能长鸣" },
    { id = "soul_pendant",   name = "血滴吊坠", nameBlue = "骨头坠", namePurple = "红玉坠",   icon = "🩸", iconId = "equip_item_health_ring", slot = "necklace",     setId = "soul_hunter",   stats = { hp = 30 },  desc = "凝固的鲜血吊坠" },
    { id = "soul_mask",      name = "嗜血面罩", nameBlue = "皮面罩", namePurple = "铁牙面罩", icon = "🩸", iconId = "equip_item_health_ring", slot = "helmet",       setId = "soul_hunter",   stats = { def = 4 },  desc = "猎手的血色面罩" },
    { id = "soul_armor",     name = "猎魂战甲", nameBlue = "皮甲",   namePurple = "血纹甲",   icon = "🩸", iconId = "equip_item_health_ring", slot = "top_armor",    setId = "soul_hunter",   stats = { hp = 22 },  desc = "以猎物血肉锻造" },
    { id = "soul_greaves",   name = "猩红护腿", nameBlue = "布护腿", namePurple = "猩红裙甲", icon = "🩸", iconId = "equip_item_health_ring", slot = "bottom_armor", setId = "soul_hunter",   stats = { def = 4 },  desc = "染红的猎手护腿" },
    { id = "soul_boots",     name = "猩血战靴", nameBlue = "软皮靴", namePurple = "血迹战靴", icon = "🩸", iconId = "equip_item_health_ring", slot = "shoes",        setId = "soul_hunter",   stats = { atk = 4 },  desc = "踏血而行的战靴" },
}

--- 获取装备定义
function Equipment.GetItemDef(id)
    for _, item in ipairs(Equipment.ITEMS) do
        if item.id == id then return item end
    end
    return nil
end

--- 获取稀有度定义
function Equipment.GetRarityDef(rarityId)
    -- 兼容旧品阶
    rarityId = Equipment.RARITY_MIGRATE[rarityId] or rarityId
    for _, r in ipairs(Equipment.RARITIES) do
        if r.id == rarityId then return r end
    end
    return nil
end

--- 获取装备实际属性（基础 × 稀有度倍率）
function Equipment.GetItemStats(itemId, rarity)
    local def = Equipment.GetItemDef(itemId)
    if not def then return {} end
    -- 兼容旧品阶
    rarity = Equipment.RARITY_MIGRATE[rarity] or rarity
    local mult = Equipment.RARITY_MULT[rarity] or 1.0
    local stats = {}
    for stat, val in pairs(def.stats) do
        stats[stat] = math.floor(val * mult)
    end
    return stats
end

--- 获取装备完整展示信息
function Equipment.GetItemDisplay(item)
    if not item then return nil end
    local def = Equipment.GetItemDef(item.id)
    if not def then return nil end
    local rarityId = Equipment.RARITY_MIGRATE[item.rarity] or item.rarity
    local rarity = Equipment.GetRarityDef(rarityId)
    local stats = Equipment.GetItemStats(item.id, rarityId)
    local statLine = ""
    for stat, val in pairs(stats) do
        local label = stat == "atk" and "攻击" or (stat == "def" and "防御" or "生命")
        statLine = statLine .. label .. "+" .. val .. " "
    end
    local setDef = Equipment.GetSetDef(def.setId)
    -- 按稀有度选择显示名：蓝色用 nameBlue，紫色用 namePurple，金色用 name（套装名）
    local displayName = def.name
    if rarityId == "blue" and def.nameBlue then
        displayName = def.nameBlue
    elseif rarityId == "purple" and def.namePurple then
        displayName = def.namePurple
    end
    return {
        name = displayName,
        icon = def.icon,
        iconId = def.iconId,
        desc = def.desc,
        slot = def.slot,
        setId = def.setId,
        setName = setDef and setDef.name or nil,
        rarity = rarity,
        statLine = statLine,
        stats = stats,
    }
end

-- ============================================================================
-- 套装计算 (v4.0: 只有金色装备计入套装件数)
-- ============================================================================

--- 计算已装备中各套装的**金色**件数 { [setId] = count }
function Equipment.GetActiveSetCount(equipment)
    local counts = {}
    for _, slot in ipairs(Equipment.SLOT_ORDER) do
        local item = equipment[slot]
        if item then
            -- 兼容旧品阶
            local rarity = Equipment.RARITY_MIGRATE[item.rarity] or item.rarity
            local def = Equipment.GetItemDef(item.id)
            if def and def.setId and rarity == "gold" then
                counts[def.setId] = (counts[def.setId] or 0) + 1
            end
        end
    end
    return counts
end

--- 获取当前激活的套装效果列表
--- @return table[] 数组，每项 {setId, setDef, tier} tier=4表示4/6效果, tier=6表示6/6效果
function Equipment.GetActiveSetEffects(equipment)
    local counts = Equipment.GetActiveSetCount(equipment)
    local effects = {}
    for setId, count in pairs(counts) do
        local setDef = Equipment.GetSetDef(setId)
        if setDef then
            if count >= 6 then
                effects[#effects + 1] = { setId = setId, setDef = setDef, tier = 6 }
            elseif count >= 4 then
                effects[#effects + 1] = { setId = setId, setDef = setDef, tier = 4 }
            end
        end
    end
    return effects
end

--- 检查指定套装是否激活及层级
--- @return number 0=未激活, 4=一阶, 6=二阶
function Equipment.GetSetTier(equipment, setId)
    local counts = Equipment.GetActiveSetCount(equipment)
    local count = counts[setId] or 0
    if count >= 6 then return 6 end
    if count >= 4 then return 4 end
    return 0
end

--- 计算套装数值加成（v4.0: 套装不直接加数值，效果是机制性的）
--- 保留接口兼容，返回空加成
function Equipment.GetSetBonuses(equipment)
    return { atk = 0, def = 0, hp = 0 }
end

-- ============================================================================
-- Gacha 抽奖
-- ============================================================================

Equipment.PULL_COST_SINGLE = 100
Equipment.PULL_COST_TRIPLE = 260
Equipment.PITY_THRESHOLD = 15  -- 每15抽保底一个不重复金色

local function rollRarity()
    local roll = math.random(1, 100)
    local cumulative = 0
    for _, r in ipairs(Equipment.RARITIES) do
        cumulative = cumulative + r.weight
        if roll <= cumulative then
            return r.id
        end
    end
    return "blue"
end

--- 收集玩家已拥有的金色装备 id 集合（背包 + 已装备）
local function collectOwnedGoldIds(playerData)
    local owned = {}
    for _, item in ipairs(playerData.inventory) do
        local r = Equipment.RARITY_MIGRATE[item.rarity] or item.rarity
        if r == "gold" then owned[item.id] = true end
    end
    for _, slot in ipairs(Equipment.SLOT_ORDER) do
        local item = playerData.equipment[slot]
        if item then
            local r = Equipment.RARITY_MIGRATE[item.rarity] or item.rarity
            if r == "gold" then owned[item.id] = true end
        end
    end
    return owned
end

--- 保底：随机一个不重复的金色装备
local function rollPityGold(playerData)
    local owned = collectOwnedGoldIds(playerData)
    -- 收集未拥有的装备
    local candidates = {}
    for _, itemDef in ipairs(Equipment.ITEMS) do
        if not owned[itemDef.id] then
            candidates[#candidates + 1] = itemDef
        end
    end
    -- 如果全部金色已集齐，随机一个金色（允许重复）
    if #candidates == 0 then
        local itemDef = Equipment.ITEMS[math.random(1, #Equipment.ITEMS)]
        return { id = itemDef.id, rarity = "gold" }
    end
    local pick = candidates[math.random(1, #candidates)]
    return { id = pick.id, rarity = "gold" }
end

local function rollOneItem()
    local rarity = rollRarity()
    local itemDef = Equipment.ITEMS[math.random(1, #Equipment.ITEMS)]
    return {
        id = itemDef.id,
        rarity = rarity,
    }
end

function Equipment.Pull(playerData, count)
    count = count or 1
    local cost = count == 1 and Equipment.PULL_COST_SINGLE or Equipment.PULL_COST_TRIPLE
    if playerData.gold < cost then
        return nil, "金币不足（需要 " .. cost .. "）"
    end
    playerData.gold = playerData.gold - cost
    playerData.pityCounter = playerData.pityCounter or 0

    local results = {}
    for i = 1, count do
        playerData.pityCounter = playerData.pityCounter + 1
        local item
        if playerData.pityCounter >= Equipment.PITY_THRESHOLD then
            -- 保底触发：出不重复金色
            item = rollPityGold(playerData)
            playerData.pityCounter = 0
            log:Write(LOG_INFO, "[Gacha] 保底触发! 获得金色: " .. item.id)
        else
            item = rollOneItem()
            -- 自然出金时也重置计数器
            if item.rarity == "gold" then
                playerData.pityCounter = 0
                log:Write(LOG_INFO, "[Gacha] 自然出金! 重置保底计数器")
            end
        end
        playerData.inventory[#playerData.inventory + 1] = item
        results[#results + 1] = item
    end
    return results, nil
end

--- 分解装备（从背包移除并返还金币）
function Equipment.Decompose(playerData, inventoryIndices)
    -- 从大到小排序避免索引偏移
    table.sort(inventoryIndices, function(a, b) return a > b end)
    local totalGold = 0
    local count = 0
    for _, idx in ipairs(inventoryIndices) do
        local item = playerData.inventory[idx]
        if item then
            local rarity = Equipment.RARITY_MIGRATE[item.rarity] or item.rarity
            local gold = Equipment.RARITY_DECOMPOSE[rarity] or 5
            totalGold = totalGold + gold
            count = count + 1
            table.remove(playerData.inventory, idx)
        end
    end
    playerData.gold = playerData.gold + totalGold
    return totalGold, count
end

--- 获取指定槽位的背包装备列表
function Equipment.GetInventoryBySlot(inventory, slot)
    local result = {}
    for i, item in ipairs(inventory) do
        local def = Equipment.GetItemDef(item.id)
        if def and def.slot == slot then
            result[#result + 1] = { index = i, item = item }
        end
    end
    return result
end

return Equipment
