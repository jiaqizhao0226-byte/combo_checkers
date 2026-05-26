-- ============================================================================
-- TestSetEffects.lua - 套装效果单元测试 (v3: 同步当前代码库)
-- ============================================================================

local Equipment = require "Equipment"
local SetEffects = require "SetEffects"
local PlayerData = require "PlayerData"

local T = {}

-- ============================================================================
-- 测试框架
-- ============================================================================

---@class TestResult
---@field name string
---@field passed boolean
---@field detail string

local ctx = { results = {}, passed = 0, failed = 0 }

local function resetCtx()
    ctx = { results = {}, passed = 0, failed = 0 }
end

local function assert_eq(desc, actual, expected)
    if actual == expected then
        ctx.passed = ctx.passed + 1
        ctx.results[#ctx.results + 1] = { name = desc, passed = true, detail = tostring(actual) }
    else
        ctx.failed = ctx.failed + 1
        ctx.results[#ctx.results + 1] = { name = desc, passed = false,
            detail = "期望 " .. tostring(expected) .. " 实际 " .. tostring(actual) }
    end
end

local function assert_true(desc, val)
    assert_eq(desc, val == true, true)
end

local function assert_false(desc, val)
    assert_eq(desc, val == true, false)
end

local function assert_gt(desc, actual, threshold)
    if actual > threshold then
        ctx.passed = ctx.passed + 1
        ctx.results[#ctx.results + 1] = { name = desc, passed = true,
            detail = tostring(actual) .. " > " .. tostring(threshold) }
    else
        ctx.failed = ctx.failed + 1
        ctx.results[#ctx.results + 1] = { name = desc, passed = false,
            detail = tostring(actual) .. " 不 > " .. tostring(threshold) }
    end
end

local function assert_range(desc, actual, lo, hi)
    if actual >= lo and actual <= hi then
        ctx.passed = ctx.passed + 1
        ctx.results[#ctx.results + 1] = { name = desc, passed = true,
            detail = tostring(actual) .. " in [" .. lo .. "," .. hi .. "]" }
    else
        ctx.failed = ctx.failed + 1
        ctx.results[#ctx.results + 1] = { name = desc, passed = false,
            detail = tostring(actual) .. " 不在 [" .. lo .. "," .. hi .. "]" }
    end
end

-- ============================================================================
-- 辅助：构造测试数据
-- ============================================================================

local function makeFullGoldSet(setId)
    local equip = { weapon = nil, necklace = nil, helmet = nil, top_armor = nil, bottom_armor = nil, shoes = nil }
    for _, item in ipairs(Equipment.ITEMS) do
        if item.setId == setId then
            equip[item.slot] = { id = item.id, rarity = "gold" }
        end
    end
    return equip
end

local function make4GoldSet(setId)
    local equip = { weapon = nil, necklace = nil, helmet = nil, top_armor = nil, bottom_armor = nil, shoes = nil }
    local count = 0
    for _, item in ipairs(Equipment.ITEMS) do
        if item.setId == setId and count < 4 then
            equip[item.slot] = { id = item.id, rarity = "gold" }
            count = count + 1
        end
    end
    return equip
end

local function makeEmptyEquip()
    return { weapon = nil, necklace = nil, helmet = nil, top_armor = nil, bottom_armor = nil, shoes = nil }
end

local function makeHero(hp, maxHp, atk, def)
    return { hp = hp or 100, maxHp = maxHp or 100, atk = atk or 20, def = def or 2 }
end

-- ============================================================================
-- 测试组定义
-- ============================================================================

T.GROUPS = {}

local function defGroup(id, name, icon)
    local g = { id = id, name = name, icon = icon, tests = {} }
    T.GROUPS[#T.GROUPS + 1] = g
    return g
end

local function addTest(group, name, fn)
    group.tests[#group.tests + 1] = { name = name, fn = fn }
end

-- ============================================================
-- 组1: 基础系统
-- ============================================================
local gBase = defGroup("base", "基础系统", "📦")

addTest(gBase, "3套装×6件=18件", function()
    assert_eq("套装总数", #Equipment.SETS, 3)
    assert_eq("装备总数", #Equipment.ITEMS, 18)
    for _, s in ipairs(Equipment.SETS) do
        local c = 0
        for _, item in ipairs(Equipment.ITEMS) do
            if item.setId == s.id then c = c + 1 end
        end
        assert_eq(s.name .. "件数", c, 6)
    end
end)

addTest(gBase, "品阶权重与倍率", function()
    assert_eq("蓝75%", Equipment.RARITIES[1].weight, 75)
    assert_eq("紫22%", Equipment.RARITIES[2].weight, 22)
    assert_eq("金3%",  Equipment.RARITIES[3].weight, 3)
    assert_eq("蓝×1.0", Equipment.RARITY_MULT.blue,   1.0)
    assert_eq("紫×1.8", Equipment.RARITY_MULT.purple,  1.8)
    assert_eq("金×3.0", Equipment.RARITY_MULT.gold,    3.0)
end)

addTest(gBase, "只有金色计入套装", function()
    local gold6 = makeFullGoldSet("leap_pioneer")
    assert_eq("6金=tier6", Equipment.GetSetTier(gold6, "leap_pioneer"), 6)

    local blue6 = {}
    for slot, v in pairs(gold6) do
        blue6[slot] = { id = v.id, rarity = "blue" }
    end
    assert_eq("6蓝=tier0", Equipment.GetSetTier(blue6, "leap_pioneer"), 0)

    local purple6 = {}
    for slot, v in pairs(gold6) do
        purple6[slot] = { id = v.id, rarity = "purple" }
    end
    assert_eq("6紫=tier0", Equipment.GetSetTier(purple6, "leap_pioneer"), 0)
end)

addTest(gBase, "属性计算(品阶倍率)", function()
    local s1 = Equipment.GetItemStats("leap_axe", "blue")
    assert_eq("蓝atk=7",  s1.atk, 7)
    local s2 = Equipment.GetItemStats("leap_axe", "purple")
    assert_eq("紫atk=12", s2.atk, 12)
    local s3 = Equipment.GetItemStats("leap_axe", "gold")
    assert_eq("金atk=21", s3.atk, 21)
end)

addTest(gBase, "抽卡&分解", function()
    local data = PlayerData.NewDefault()
    data.gold = 1000
    local r1, e1 = Equipment.Pull(data, 1)
    assert_eq("单抽成功", e1, nil)
    assert_eq("扣费80",   data.gold, 920)
    local r3, e3 = Equipment.Pull(data, 3)
    assert_eq("三连成功", e3, nil)
    assert_eq("扣费200",  data.gold, 720)

    data.gold = 0
    data.inventory = {
        { id = "leap_axe", rarity = "blue" },
        { id = "leap_axe", rarity = "purple" },
        { id = "leap_axe", rarity = "gold" },
    }
    local goldGained = Equipment.Decompose(data, {1, 2, 3})
    assert_eq("分解金币5+15+50=70", goldGained, 70)
end)

-- ============================================================
-- 组2: 飞跃先锋
-- ============================================================
local gLeap = defGroup("leap_pioneer", "飞跃先锋", "🦘")

addTest(gLeap, "4/6 可跳2个敌人", function()
    local se = SetEffects.Init(make4GoldSet("leap_pioneer"), 0)
    assert_eq("跳2", SetEffects.GetMaxJumpOverCount(se), 2)
end)

addTest(gLeap, "6/6 可跳3个敌人", function()
    local se = SetEffects.Init(makeFullGoldSet("leap_pioneer"), 0)
    assert_eq("跳3", SetEffects.GetMaxJumpOverCount(se), 3)
end)

addTest(gLeap, "无套装默认跳1", function()
    local se = SetEffects.Init(makeEmptyEquip(), 0)
    assert_eq("默认跳1", SetEffects.GetMaxJumpOverCount(se), 1)
end)

-- ============================================================
-- 组3: 连击心得
-- ============================================================
local gCombo = defGroup("combo_mastery", "连击心得", "🔥")

addTest(gCombo, "4/6 约50%概率combo+1", function()
    local se = SetEffects.Init(make4GoldSet("combo_mastery"), 0)
    local bonusCount = 0
    for i = 1, 1000 do
        local b = SetEffects.OnComboChainComplete(se, 3)
        if b > 0 then bonusCount = bonusCount + 1 end
    end
    assert_range("触发率约50%", bonusCount / 10, 38, 62)
end)

addTest(gCombo, "6/6 必定combo+1", function()
    local se = SetEffects.Init(makeFullGoldSet("combo_mastery"), 0)
    local allTriggered = true
    for i = 1, 100 do
        local b = SetEffects.OnComboChainComplete(se, 3)
        if b ~= 1 then allTriggered = false; break end
    end
    assert_true("100%必触发", allTriggered)
end)

addTest(gCombo, "无套装不触发", function()
    local se = SetEffects.Init(makeEmptyEquip(), 0)
    local b = SetEffects.OnComboChainComplete(se, 5)
    assert_eq("无套装bonus=0", b, 0)
end)

-- ============================================================
-- 组4: 猎魂·嗜血
-- ============================================================
local gSoul = defGroup("soul_hunter", "猎魂·嗜血", "🩸")

addTest(gSoul, "4/6 击杀回血", function()
    local se = SetEffects.Init(make4GoldSet("soul_hunter"), 0)
    local hero = makeHero(50, 100)
    local heal, text, rage = SetEffects.OnKillHeal(se, hero, false)
    assert_gt("回血>0", heal, 0)
    assert_false("4件套不触发血怒", rage)
end)

addTest(gSoul, "碎片敌人不触发", function()
    local se = SetEffects.Init(makeFullGoldSet("soul_hunter"), 0)
    local hero = makeHero(30, 100)
    local heal, text, rage = SetEffects.OnKillHeal(se, hero, true)
    assert_eq("碎片heal=0", heal, 0)
    assert_false("碎片不触发血怒", rage)
end)

addTest(gSoul, "6/6 低血量触发血怒", function()
    local se = SetEffects.Init(makeFullGoldSet("soul_hunter"), 0)
    -- HP < 50% 时触发血怒
    local hero = makeHero(40, 100)
    local heal, text, rage = SetEffects.OnKillHeal(se, hero, false)
    assert_true("低血触发血怒", rage)
    assert_eq("血怒叠层=1", se.bloodRageStacks, 1)
end)

addTest(gSoul, "6/6 血怒最多叠3层", function()
    local se = SetEffects.Init(makeFullGoldSet("soul_hunter"), 0)
    local hero = makeHero(20, 100)
    for i = 1, 5 do
        SetEffects.OnKillHeal(se, hero, false)
    end
    assert_eq("血怒上限=3", se.bloodRageStacks, 3)
end)

addTest(gSoul, "血怒消耗ATK×1.5", function()
    local se = SetEffects.Init(makeFullGoldSet("soul_hunter"), 0)
    se.bloodRageStacks = 2
    local mult, text = SetEffects.ConsumeBloodRage(se)
    assert_eq("倍率1.5", mult, 1.5)
    assert_eq("消耗后剩1层", se.bloodRageStacks, 1)
    local mult2, _ = SetEffects.ConsumeBloodRage(se)
    assert_eq("倍率1.5", mult2, 1.5)
    assert_eq("消耗后剩0层", se.bloodRageStacks, 0)
    local mult3, _ = SetEffects.ConsumeBloodRage(se)
    assert_eq("无血怒返回1.0", mult3, 1.0)
end)

addTest(gSoul, "高血量不触发血怒", function()
    local se = SetEffects.Init(makeFullGoldSet("soul_hunter"), 0)
    local hero = makeHero(80, 100)   -- HP=80%，不触发
    local heal, text, rage = SetEffects.OnKillHeal(se, hero, false)
    assert_false("高血不触发血怒", rage)
    assert_eq("血怒叠层=0", se.bloodRageStacks, 0)
end)

addTest(gSoul, "无套装不触发", function()
    local se = SetEffects.Init(makeEmptyEquip(), 0)
    local hero = makeHero(20, 100)
    local heal, text, rage = SetEffects.OnKillHeal(se, hero, false)
    assert_eq("无套装heal=0", heal, 0)
    assert_false("无套装无血怒", rage)
end)

-- ============================================================
-- 组5: 暴击
-- ============================================================
local gCrit = defGroup("crit", "暴击", "⚔️")

addTest(gCrit, "暴击判定统计(30%)", function()
    local crits = 0
    for i = 1, 1000 do
        if SetEffects.RollCrit(30) then crits = crits + 1 end
    end
    assert_range("暴击率约30%", crits / 10, 20, 40)
    assert_eq("暴击倍率1.5", SetEffects.CRIT_MULTIPLIER, 1.5)
end)

addTest(gCrit, "0%必不暴击 100%必暴击", function()
    local noCrit = true
    for i = 1, 100 do
        if SetEffects.RollCrit(0) then noCrit = false; break end
    end
    assert_true("0%不暴击", noCrit)

    local allCrit = true
    for i = 1, 100 do
        if not SetEffects.RollCrit(100) then allCrit = false; break end
    end
    assert_true("100%必暴击", allCrit)
end)

-- ============================================================
-- 组6: 天赋
-- ============================================================
local gTalent = defGroup("talent", "天赋升级", "🌟")

addTest(gTalent, "天赋升级+加成计算", function()
    local data = PlayerData.NewDefault()
    data.gold = 10000
    PlayerData.UpgradeTalent(data, "crit")
    PlayerData.UpgradeTalent(data, "crit")
    PlayerData.UpgradeTalent(data, "gold")
    assert_eq("暴击率6%", PlayerData.GetCritRate(data), 6)
    assert_eq("金币加成5%", PlayerData.GetGoldBonus(data), 5)
end)

-- ============================================================================
-- 运行接口
-- ============================================================================

function T.RunGroup(groupId)
    for _, g in ipairs(T.GROUPS) do
        if g.id == groupId then
            resetCtx()
            for _, t in ipairs(g.tests) do
                t.fn()
            end
            return {
                groupId = g.id,
                groupName = g.name,
                icon = g.icon,
                passed = ctx.passed,
                failed = ctx.failed,
                total = ctx.passed + ctx.failed,
                results = ctx.results,
            }
        end
    end
    return nil
end

function T.RunAll()
    local allGroups = {}
    local tp, tf = 0, 0
    for _, g in ipairs(T.GROUPS) do
        local r = T.RunGroup(g.id)
        allGroups[#allGroups + 1] = r
        tp = tp + r.passed
        tf = tf + r.failed

        local status = r.failed == 0 and "PASS" or "FAIL"
        log:Write(r.failed == 0 and LOG_INFO or LOG_ERROR,
            string.format("[%s] %s %s: %d/%d", status, g.icon, g.name, r.passed, r.total))
        for _, res in ipairs(r.results) do
            if not res.passed then
                log:Write(LOG_ERROR, "  ✗ " .. res.name .. " — " .. res.detail)
            end
        end
    end
    return {
        groups = allGroups,
        totalPassed = tp,
        totalFailed = tf,
        allPassed = (tf == 0),
    }
end

function T.GetGroupList()
    local list = {}
    for _, g in ipairs(T.GROUPS) do
        list[#list + 1] = { id = g.id, name = g.name, icon = g.icon, testCount = #g.tests }
    end
    return list
end

return T
