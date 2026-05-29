-- ============================================================================
-- PlayerData.lua - 持久化玩家数据 v4.0
-- 天赋: 5维度×10级（HP/ATK/DEF/暴击/金币）
-- 装备: 6槽位, 3品阶(蓝/紫/金), 5套装
-- ============================================================================

local PlayerData = {}

-- ============================================================================
-- 存档版本号
-- 每次需要强制重置所有玩家进度时，将此值 +1
-- 当存档中的 saveVersion 与此值不一致时，忽略旧存档、生成全新默认数据
-- ============================================================================
PlayerData.SAVE_VERSION = 2

-- ============================================================================
-- 天赋定义 (v4.0: 5维度×10级)
-- ============================================================================

PlayerData.TALENTS = {
    {
        id = "hp",
        name = "生命强化",
        icon = "❤️",
        desc = "基础生命值",
        bonusPerLevel = 3,   -- 满级+30 (基础110的27%)
        maxLevel = 10,
        stat = "hp",
    },
    {
        id = "atk",
        name = "攻击强化",
        icon = "⚔️",
        desc = "基础攻击力",
        bonusPerLevel = 0.5, -- 满级+5 (基础20的25%)
        maxLevel = 10,
        stat = "atk",
    },
    {
        id = "def",
        name = "防御强化",
        icon = "🛡️",
        desc = "基础防御力",
        bonusPerLevel = 0.3, -- 满级+3
        maxLevel = 10,
        stat = "def",
    },
    {
        id = "crit",
        name = "暴击直觉",
        icon = "💥",
        desc = "暴击率",
        bonusPerLevel = 1,   -- 满级+10%
        maxLevel = 10,
        stat = "crit",       -- 特殊: 百分比
    },
    {
        id = "gold",
        name = "点金手",
        icon = "💰",
        desc = "金币加成",
        bonusPerLevel = 2,   -- 满级+20%
        maxLevel = 10,
        stat = "gold",       -- 特殊: 百分比
    },
}

PlayerData.TALENT_COSTS = { 30, 60, 120, 250, 450, 800, 1400, 2200, 3500, 5000 }

function PlayerData.GetTalentDef(id)
    for _, t in ipairs(PlayerData.TALENTS) do
        if t.id == id then return t end
    end
    return nil
end

-- ============================================================================
-- 数据操作
-- ============================================================================

--- 创建默认数据（深拷贝）
function PlayerData.NewDefault()
    return {
        saveVersion = PlayerData.SAVE_VERSION,
        gold = 0,
        talents = { atk = 0, def = 0, hp = 0, crit = 0, gold = 0 },
        equipment = {
            weapon = nil, necklace = nil, helmet = nil,
            top_armor = nil, bottom_armor = nil, shoes = nil,
        },
        inventory = {},
        pityCounter = 0,
        highestLevel = 1,
        totalRuns = 0,
        highestEndlessWave = 0,
        comboTutorialSeen = false,
        scarecrowTutorialSeen = false,
        multiHopTutorialSeen = false,
        chainJumpTutorialSeen = false,
        tutorialSpawnSeen = false,
        seenComboTiers = {},
        seenEnemyTypes = {},
        usedCodes = {},
    }
end

--- 旧存档迁移：3槽 → 6槽
local function migrateEquipment(eq)
    if not eq then return nil end
    -- 检测旧格式（有 armor 或 accessory 字段）
    if eq.armor ~= nil or eq.accessory ~= nil then
        local migrated = {
            weapon = eq.weapon,
            necklace = eq.accessory,
            helmet = nil,
            top_armor = eq.armor,
            bottom_armor = nil,
            shoes = nil,
        }
        return migrated
    end
    return eq
end

--- v4.0 品阶迁移：旧品阶(common/rare/epic) → 新品阶(blue/purple/gold)
local function migrateItemRarity(item)
    if not item then return nil end
    local Equipment = require "Equipment"
    local newRarity = Equipment.RARITY_MIGRATE[item.rarity]
    if newRarity then
        item.rarity = newRarity
    end
    -- 检查装备ID是否还存在于新装备池
    local def = Equipment.GetItemDef(item.id)
    if not def then
        -- 旧装备不存在了，转为金币退还
        return nil  -- 调用方负责退还金币
    end
    return item
end

--- v4.0 迁移旧存档的装备和背包
local function migrateToV4(data)
    local Equipment = require "Equipment"
    local refundGold = 0

    -- 迁移已装备的装备
    for _, slot in ipairs(Equipment.SLOT_ORDER) do
        local item = data.equipment[slot]
        if item then
            local migrated = migrateItemRarity(item)
            if migrated then
                data.equipment[slot] = migrated
            else
                -- 旧装备不在新池中，退还金币
                local oldRarity = Equipment.RARITY_MIGRATE[item.rarity] or item.rarity
                refundGold = refundGold + (Equipment.RARITY_DECOMPOSE[oldRarity] or 5)
                data.equipment[slot] = nil
            end
        end
    end

    -- 迁移背包
    local newInventory = {}
    for _, item in ipairs(data.inventory) do
        local migrated = migrateItemRarity(item)
        if migrated then
            newInventory[#newInventory + 1] = migrated
        else
            local oldRarity = Equipment.RARITY_MIGRATE[item.rarity] or item.rarity
            refundGold = refundGold + (Equipment.RARITY_DECOMPOSE[oldRarity] or 5)
        end
    end
    data.inventory = newInventory

    -- 退还金币
    if refundGold > 0 then
        data.gold = data.gold + refundGold
        log:Write(LOG_INFO, "[PlayerData] v4.0迁移: 退还 " .. refundGold .. " 金币")
    end

    -- 标记已迁移
    data._equipVersion = 4

    return data
end

--- 从本地文件加载
function PlayerData.Load()
    if not fileSystem:FileExists("save.json") then
        return PlayerData.NewDefault()
    end
    local file = File("save.json", FILE_READ)
    if not file:IsOpen() then
        log:Write(LOG_ERROR, "[PlayerData] Failed to open save file")
        return PlayerData.NewDefault()
    end
    local str = file:ReadString()
    file:Close()
    local ok, data = pcall(cjson.decode, str)
    if not ok or type(data) ~= "table" then
        log:Write(LOG_ERROR, "[PlayerData] Failed to decode save: " .. tostring(data))
        return PlayerData.NewDefault()
    end
    -- 防止 cjson 将整数字段解码为 Lua 浮点数（Lua 5.4 中 %d 不接受浮点数）
    data.gold                = math.floor(data.gold or 0)
    data.highestLevel        = math.floor(data.highestLevel or 1)
    data.totalRuns           = math.floor(data.totalRuns or 0)
    data.highestEndlessWave  = math.floor(data.highestEndlessWave or 0)
    data.pityCounter         = math.floor(data.pityCounter or 0)
    if type(data.talents) == "table" then
        for k, v in pairs(data.talents) do
            data.talents[k] = math.floor(v or 0)
        end
    end
    -- 版本号检查：不匹配时只更新版本号，保留所有玩家资产
    if (data.saveVersion or 1) ~= PlayerData.SAVE_VERSION then
        log:Write(LOG_INFO, "[PlayerData] 存档版本不匹配 (存档=" ..
            tostring(data.saveVersion) .. " 当前=" .. PlayerData.SAVE_VERSION ..
            ")，更新版本号，保留所有玩家资产")
        data.saveVersion = PlayerData.SAVE_VERSION
        -- 不清空任何数据，继续走下方的字段补齐和迁移逻辑
    end
    -- 填充缺失字段
    local defaults = PlayerData.NewDefault()
    for k, v in pairs(defaults) do
        if data[k] == nil then
            data[k] = v
        end
    end
    if type(data.talents) ~= "table" then data.talents = defaults.talents end
    -- 补齐新天赋维度
    for _, t in ipairs(PlayerData.TALENTS) do
        if data.talents[t.id] == nil then
            data.talents[t.id] = 0
        end
    end
    if type(data.inventory) ~= "table" then data.inventory = {} end
    if type(data.seenEnemyTypes) ~= "table" then data.seenEnemyTypes = {} end
    -- 迁移装备格式
    if type(data.equipment) ~= "table" then
        data.equipment = defaults.equipment
    else
        data.equipment = migrateEquipment(data.equipment)
    end
    -- v4.0 品阶迁移
    if (data._equipVersion or 0) < 4 then
        data = migrateToV4(data)
    end
    -- 章节迁移: 删除旧第一章（幽暗森林），关卡编号前移10
    if (data.highestLevel or 1) > 1 and not data._chapterMigrated then
        if data.highestLevel <= 10 then
            data.highestLevel = 1
        else
            data.highestLevel = data.highestLevel - 10
        end
        data._chapterMigrated = true
        log:Write(LOG_INFO, "[PlayerData] 章节迁移: highestLevel → " .. data.highestLevel)
    end
    return data
end

--- 保存到本地文件
function PlayerData.Save(data)
    local file = File("save.json", FILE_WRITE)
    if not file:IsOpen() then
        log:Write(LOG_ERROR, "[PlayerData] Failed to write save file")
        return false
    end
    file:WriteString(cjson.encode(data))
    file:Close()
    return true
end

--- 增加金币
function PlayerData.AddGold(data, amount)
    data.gold = data.gold + amount
end

--- 花费金币
function PlayerData.SpendGold(data, amount)
    if data.gold < amount then return false end
    data.gold = data.gold - amount
    return true
end

--- 升级天赋
function PlayerData.UpgradeTalent(data, talentId)
    local def = PlayerData.GetTalentDef(talentId)
    if not def then return false, "天赋不存在" end
    local currentLevel = data.talents[talentId] or 0
    if currentLevel >= def.maxLevel then return false, "已满级" end
    local cost = PlayerData.TALENT_COSTS[currentLevel + 1]
    if not cost then return false, "费用数据错误" end
    if data.gold < cost then return false, "金币不足" end
    data.gold = data.gold - cost
    data.talents[talentId] = currentLevel + 1
    return true, nil
end

--- 获取天赋加成 (返回 {atk, def, hp, crit, gold})
function PlayerData.GetTalentBonus(data)
    local bonus = { atk = 0, def = 0, hp = 0, crit = 0, gold = 0 }
    -- crit/gold 是百分比，保留小数；hp/atk/def 是整数属性，向下取整避免浮点污染
    local intStats = { hp = true, atk = true, def = true }
    for _, talent in ipairs(PlayerData.TALENTS) do
        local level = data.talents[talent.id] or 0
        if level > 0 then
            local val = (bonus[talent.stat] or 0) + level * talent.bonusPerLevel
            if intStats[talent.stat] then
                val = math.floor(val)
            end
            bonus[talent.stat] = val
        end
    end
    return bonus
end

function PlayerData.GetUpgradeCost(data, talentId)
    local level = data.talents[talentId] or 0
    local def = PlayerData.GetTalentDef(talentId)
    if not def or level >= def.maxLevel then return nil end
    return PlayerData.TALENT_COSTS[level + 1]
end

-- ============================================================================
-- 装备操作
-- ============================================================================

--- 装备物品到对应槽位
function PlayerData.EquipItem(data, inventoryIndex)
    local item = data.inventory[inventoryIndex]
    if not item then return nil end
    local Equipment = require "Equipment"
    local def = Equipment.GetItemDef(item.id)
    if not def then return nil end
    local slot = def.slot
    local oldEquipped = data.equipment[slot]
    table.remove(data.inventory, inventoryIndex)
    data.equipment[slot] = item
    if oldEquipped then
        data.inventory[#data.inventory + 1] = oldEquipped
    end
    return oldEquipped
end

--- 卸下装备到背包
function PlayerData.UnequipItem(data, slot)
    local item = data.equipment[slot]
    if not item then return false end
    data.equipment[slot] = nil
    data.inventory[#data.inventory + 1] = item
    return true
end

--- 获取装备基础属性加成（含稀有度倍率）
function PlayerData.GetEquipmentBonus(data)
    local Equipment = require "Equipment"
    local bonus = { atk = 0, def = 0, hp = 0, crit = 0 }
    for _, slot in ipairs(Equipment.SLOT_ORDER) do
        local item = data.equipment[slot]
        if item then
            local stats = Equipment.GetItemStats(item.id, item.rarity)
            for stat, val in pairs(stats) do
                bonus[stat] = (bonus[stat] or 0) + val
            end
        end
    end
    return bonus
end

--- 获取套装数值加成（v4.0: 套装效果是机制性的，不加数值）
function PlayerData.GetSetBonus(data)
    local Equipment = require "Equipment"
    return Equipment.GetSetBonuses(data.equipment)
end

--- 获取天赋+装备+套装总加成 (atk/def/hp)
function PlayerData.GetTotalBonus(data)
    local talent = PlayerData.GetTalentBonus(data)
    local equip = PlayerData.GetEquipmentBonus(data)
    local setBonus = PlayerData.GetSetBonus(data)
    return {
        atk = talent.atk + equip.atk + setBonus.atk,
        def = talent.def + equip.def + setBonus.def,
        hp  = talent.hp  + equip.hp  + setBonus.hp,
    }
end

--- 获取暴击率（百分比整数，如 15 表示 15%）
function PlayerData.GetCritRate(data)
    local talent = PlayerData.GetTalentBonus(data)
    local equip = PlayerData.GetEquipmentBonus(data)
    return (talent.crit or 0) + (equip.crit or 0)
end

--- 获取金币加成（百分比整数，如 25 表示 25%）
function PlayerData.GetGoldBonus(data)
    local talent = PlayerData.GetTalentBonus(data)
    return talent.gold or 0
end

return PlayerData
