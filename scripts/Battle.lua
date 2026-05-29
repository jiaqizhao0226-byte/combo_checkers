-- ============================================================================
-- Battle.lua - 战斗系统模块 (肉鸽版)
-- 多关卡、道具、技能钩子、毒雾、护盾、章节Boss
-- ============================================================================

local HexGrid = require "HexGrid"
local Skills = require "Skills"
local AM = require "AudioManager"
local PlayerData = require "PlayerData"
local SetEffects = require "SetEffects"
local G = require "GameState"

-- 静态数据表（从 BattleData.lua 加载，local 别名保持内部代码零改动）
local BattleData      = require "BattleData"

-- 纯工具函数（从 BattleUtils.lua 加载）
local BattleUtils       = require "BattleUtils"
local FindClosestMove    = BattleUtils.FindClosestMove
local FindFarthestMove   = BattleUtils.FindFarthestMove
local FindOptimalRangeMove = BattleUtils.FindOptimalRangeMove
local AddVFX             = BattleUtils.AddVFX
local AddFloatingText    = BattleUtils.AddFloatingText
local AddLog             = BattleUtils.AddLog
-- Battle.GetThreats, Battle.ClearPriestBuffs 转发到 BattleUtils
local HERO_TEMPLATE   = BattleData.HERO_TEMPLATE
local ENEMY_GOLD      = BattleData.ENEMY_GOLD
local ENEMY_TEMPLATES = BattleData.ENEMY_TEMPLATES
local ENEMY_INTRO     = BattleData.ENEMY_INTRO
local BOSS_TEMPLATES  = BattleData.BOSS_TEMPLATES
local CHAPTER_BOSS    = BattleData.CHAPTER_BOSS
local BOSS_AURA       = BattleData.BOSS_AURA
local ITEM_TYPES      = BattleData.ITEM_TYPES

local Battle = {}

-- 工具函数转发：保持 Battle.XXX API 不变（内部实现已移至 BattleUtils）
-- 注意：BattleUtils 在文件顶部 require，此处延迟赋值（Battle 表刚创建）
local function _initBattleUtils()
    Battle.AddVFX              = BattleUtils.AddVFX
    Battle.AddFloatingText     = BattleUtils.AddFloatingText
    Battle.AddLog              = BattleUtils.AddLog
    Battle.GetThreats          = BattleUtils.GetThreats
    Battle.ClearPriestBuffs    = BattleUtils.ClearPriestBuffs
    Battle.FindClosestMove     = BattleUtils.FindClosestMove
    Battle.FindFarthestMove    = BattleUtils.FindFarthestMove
    Battle.FindOptimalRangeMove = BattleUtils.FindOptimalRangeMove
end
_initBattleUtils()

-- ============================================================================
-- 章节配置
-- ============================================================================

Battle.LEVELS_PER_CHAPTER = 10   -- 每章10关

--- 获取章节号和章内关卡号
function Battle.GetChapterInfo(level)
    -- 用 math.floor 确保 level 是整数再参与运算，防止 Lua 5.4 浮点数传入 %d 报错
    local lvInt = math.floor(level)
    local chapter = math.ceil(lvInt / Battle.LEVELS_PER_CHAPTER)
    local stageInChapter = ((lvInt - 1) % Battle.LEVELS_PER_CHAPTER) + 1
    return chapter, stageInChapter
end

--- 是否为Boss关
function Battle.IsBossLevel(level)
    return (level % Battle.LEVELS_PER_CHAPTER) == 0
end

-- ============================================================================
-- 关卡信息（名称、图标、描述）
-- ============================================================================

--- 章节名称
Battle.CHAPTER_NAMES = {
    [0] = "无尽深渊",   -- 特殊模式：在第1章左边（菜单导航用）
    [1] = "深渊海沟",
    [2] = "烈焰山脉",
    [3] = "珊瑚迷宫",
    [4] = "流沙荒漠",
    [5] = "无尽深渊",   -- GetChapterInfo(level>=41) fallback，与 [0] 同义
}

--- 每章10关的关卡信息（按章节索引）
Battle.STAGE_INFO = {
    -- 第一章: 深渊海沟（连击奖励）
    [1] = {
        { name = "浅海珊瑚", icon = "🐚", desc = "水流平缓" },
        { name = "水母群落", icon = "🪼", desc = "触手密布" },
        { name = "沉船墓地", icon = "🚢", desc = "暗藏危机" },
        { name = "深海暗流", icon = "🌊", desc = "漩涡涌动" },
        { name = "铁甲礁石", icon = "🪨", desc = "坚不可摧" },
        { name = "海沟峡谷", icon = "🏔️", desc = "越来越深" },
        { name = "寄居蟹巢", icon = "🦀", desc = "壳中有壳" },
        { name = "幽暗深渊", icon = "🌑", desc = "光线全无" },
        { name = "海妖前厅", icon = "🐙", desc = "触手蠕动" },
        { name = "深渊王座", icon = "🔱", desc = "Boss: 深渊海妖" },
    },
    -- 第二章: 烈焰山脉（炎魔祭坛）
    [2] = {
        { name = "灼热入口", icon = "🔥", desc = "祭坛初现" },
        { name = "熔岩裂谷", icon = "🌋", desc = "破坏祭坛" },
        { name = "火灵栖地", icon = "✨", desc = "护盾敌人" },
        { name = "岩浆暗河", icon = "🟠", desc = "双坛夹击" },
        { name = "硫磺矿洞", icon = "💎", desc = "先坛后敌" },
        { name = "烈焰高原", icon = "☀️", desc = "三坛围攻" },
        { name = "熔岩之心", icon = "❤️‍🔥", desc = "坛盾交织" },
        { name = "炎魔前厅", icon = "🗡️", desc = "祭坛迷阵" },
        { name = "岩浆风暴", icon = "🌋", desc = "最后冲刺" },
        { name = "领主殿堂", icon = "👑", desc = "Boss: 熔岩领主" },
    },
    -- 第三章: 珊瑚迷宫（障碍清除+寄居蟹救援）
    [3] = {
        { name = "潮间浅滩", icon = "🐚", desc = "初遇寄居蟹" },
        { name = "珊瑚丛林", icon = "🪸", desc = "路障密布" },
        { name = "海星礁盘", icon = "⭐", desc = "分岔路口" },
        { name = "螺壳谷地", icon = "🐌", desc = "蟹壳遍地" },
        { name = "海胆暗礁", icon = "🦔", desc = "荆棘满途" },
        { name = "珊瑚迷阵", icon = "🧩", desc = "路线复杂" },
        { name = "贝壳广场", icon = "🐚", desc = "蟹群求救" },
        { name = "深海珊瑚", icon = "💎", desc = "障碍重重" },
        { name = "迷宫核心", icon = "🌀", desc = "最后冲刺" },
        { name = "珊瑚王庭", icon = "👑", desc = "Boss: 珊瑚守卫" },
    },
    -- 第四章: 流沙荒漠
    [4] = {
        { name = "沙丘入口", icon = "🏜️", desc = "流沙初现" },
        { name = "蝎巢沙地", icon = "🦂", desc = "沙蝎伏击" },
        { name = "风蚀峡谷", icon = "🌪️", desc = "沙暴来袭" },
        { name = "流沙陷阱", icon = "⏳", desc = "脚下塌陷" },
        { name = "沙鹰领地", icon = "🦅", desc = "空中威胁" },
        { name = "虫巢外围", icon = "🪱", desc = "沙虫出没" },
        { name = "沙漠绿洲", icon = "🌴", desc = "短暂歇息" },
        { name = "沙暴核心", icon = "💨", desc = "能见度为零" },
        { name = "巨虫领地", icon = "🐛", desc = "地面震颤" },
        { name = "沙丘之王", icon = "👑", desc = "Boss: 沙丘巨虫" },
    },
    -- 第五章: 无尽深渊（无尽模式，无固定关卡）
    [5] = {
        { name = "深渊入口", icon = "🌀", desc = "第1波" },
        { name = "幽暗涌动", icon = "🌑", desc = "第2波" },
        { name = "深渊回响", icon = "🔮", desc = "第3波" },
        { name = "虚空低语", icon = "👁️", desc = "第4波" },
        { name = "混沌侵蚀", icon = "💀", desc = "第5波" },
        { name = "无尽咆哮", icon = "⚡", desc = "第6波" },
        { name = "深渊之心", icon = "❤️‍🔥", desc = "第7波" },
        { name = "星陨之地", icon = "☄️", desc = "第8波" },
        { name = "绝望深处", icon = "🌊", desc = "第9波" },
        { name = "深渊主宰", icon = "👑", desc = "第10波" },
    },
}

--- 获取关卡完整信息
function Battle.GetLevelInfo(level)
    local chapter, stage = Battle.GetChapterInfo(level)
    local chapterStages = Battle.STAGE_INFO[chapter]
    local info = chapterStages and chapterStages[stage]
    local chapterName = Battle.CHAPTER_NAMES[chapter] or ("第" .. chapter .. "章")
    if info then
        return {
            name = info.name,
            icon = info.icon,
            desc = info.desc,
            chapter = chapter,
            chapterName = chapterName,
            stage = stage,
            isBoss = Battle.IsBossLevel(level),
            level = level,
        }
    end
    return {
        name = "未知区域",
        icon = "❓",
        desc = "等待探索",
        chapter = chapter,
        chapterName = chapterName,
        stage = stage,
        isBoss = Battle.IsBossLevel(level),
        level = level,
    }
end

-- ============================================================================
-- 棋子模板
-- ============================================================================


-- 每种敌人的基础金币奖励


-- ============================================================================
-- 怪物机制简介（首次遇到时弹窗提示）
-- 只收录有特殊机制的敌人，普通纯近战怪不需要提示
-- ============================================================================

--- 检查本关出现了哪些新怪物类型（有机制介绍的）
---@param board table
---@param seenTypes table<string, boolean> 玩家已见过的怪物类型集合
---@return table[] 新怪物介绍列表 { icon, name, desc, enemyType }
function Battle.DetectNewEnemyTypes(board, seenTypes)
    local newIntros = {}
    local checked = {}
    for _, p in ipairs(board.pieces) do
        local et = p.enemyType
        if et and not p.isBoss and not checked[et] and not seenTypes[et] and ENEMY_INTRO[et] then
            checked[et] = true
            local info = ENEMY_INTRO[et]
            newIntros[#newIntros + 1] = {
                enemyType = et,
                icon = info.icon,
                name = info.name,
                desc = info.desc,
            }
        end
    end
    return newIntros
end

-- ============================================================================
-- Boss 模板
-- ============================================================================


--- Boss 章节映射

--- Boss 光环效果配置（靠近Boss时自动受伤）
Battle.BOSS_AURA = BOSS_AURA
Battle.CHAPTER_BOSS = CHAPTER_BOSS

--- Boss 肖像资源映射
Battle.BOSS_PORTRAITS = {
    abyss_kraken    = "image/boss_abyss_kraken_20260423082421.png",
    lava_lord       = "image/boss_lava_lord_20260423082419.png",
    coral_guardian  = "image/boss_coral_guardian_20260523054145.png",
    sand_worm       = "image/boss_sand_worm_20260528082517.png",
}

-- 道具类型定义

Battle.ITEM_TYPES = ITEM_TYPES

-- ============================================================================
-- 创建战斗
-- ============================================================================

--- @param bonusStats table|nil 天赋+装备加成 {atk=N, def=N, hp=N}
function Battle.New(bonusStats)
    bonusStats = bonusStats or {}
    local board = HexGrid.CreateBoard()
    local state = {
        board = board,
        hero = nil,
        phase = "PLAYER_SELECT",
        turn = 1,
        combo = 0,
        maxCombo = 0,
        totalDamage = 0,
        gold = 0,
        floatingTexts = {},
        vfx = {},               -- 视觉特效列表
        log = {},
        -- 肉鸽新增
        level = 1,              -- 当前关卡
        skills = {},            -- 已拥有技能 {skillId = level} map
        hasShield = false,      -- 护盾状态
        screenShake = 0,
        hitFlash = 0,
        -- 进化系统新增
        comboKillCount = 0,          -- bounty_hunter: 连击中击杀数
        comboAtkBonus = 0,           -- blood_frenzy: 连击中临时ATK叠加
        -- 天赋/装备加成
        bonusStats = bonusStats,
        -- v4.0 套装效果
        setEffects = nil,          -- SetEffects 运行时状态(GenerateLevel中初始化)
        critRate = 0,              -- 暴击率(百分比整数)
        goldBonus = 0,             -- 金币加成(百分比整数)
        -- 黎明使者: 整次冒险仅一次免死，放在 state 顶层避免随 hero 重建而丢失
        dawnHeraldUsed = false,
        -- ====== 第三章: 战争迷雾 ======
        heroBurn = 0,                -- 英雄灼烧剩余回合数
        heroBurnDmg = 0,             -- 每回合灼烧伤害
        -- ====== 第二章: 连击奖励 ======
        comboRewardsTriggered = {},  -- 本回合已触发的连击阈值 {[2]=true,[3]=true,...}
        timeFreezeActive = false,    -- 时间冻结：跳过敌人回合
        timeFreezeCount = 0,         -- 时间冻结剩余回合数
        -- 稻草人
        scarecrow = nil,             -- {col, row, hp, maxHp, atk, def, turnsLeft}
        scarecrowActive = false,     -- 稻草人是否存在
        -- 击杀通关
        kills = 0,                   -- 当前关卡已击杀数
        killTarget = 8,              -- 当前关卡通关所需击杀数
        -- 无尽模式
        isEndless = false,
        endlessWave = 1,
        endlessTotalTurns = 0,       -- 无尽模式累计存活回合数

    }
    return state
end

-- ============================================================================
-- 炎魔祭坛系统（第二章）
-- ============================================================================

--- 获取祭坛数量（根据关卡阶段）
function Battle.GetAltarCount(stageInChapter)
    if stageInChapter <= 3 then return 2
    elseif stageInChapter <= 7 then return 3
    else return 3
    end
end

--- 六角距离
local function hexDist(c1, r1, c2, r2)
    local x1, y1, z1 = HexGrid.OffsetToCube(c1, r1)
    local x2, y2, z2 = HexGrid.OffsetToCube(c2, r2)
    return math.max(math.abs(x1 - x2), math.abs(y1 - y2), math.abs(z1 - z2))
end

--- 祭坛影响半径
Battle.ALTAR_RADIUS = 2

--- 在棋盘上放置祭坛
function Battle.PlaceAltars(state, count)
    local board = state.board
    board.altars = {}

    -- 收集已占用位置
    local used = {}
    for _, p in ipairs(board.pieces) do used[p.col..","..p.row] = true end
    for _, o in ipairs(board.obstacles) do used[o.col..","..o.row] = true end
    for _, it in ipairs(board.items) do used[it.col..","..it.row] = true end

    -- 英雄位置（用于保证祭坛不会离英雄太近）
    local heroCol = state.hero and state.hero.col or (HexGrid.CENTER_COL)
    local heroRow = state.hero and state.hero.row or (HexGrid.CENTER_ROW + HexGrid.RADIUS)

    -- 收集候选位置（非中心、非边缘1圈的内部区域，且离英雄足够远）
    local candidates = {}
    for col = 1, HexGrid.COLS do
        for row = 1, HexGrid.ROWS do
            if HexGrid.InBounds(col, row) and not used[col..","..row] then
                local dist = hexDist(col, row, HexGrid.CENTER_COL, HexGrid.CENTER_ROW)
                local heroDist = hexDist(col, row, heroCol, heroRow)
                if dist >= 2 and dist <= 3 and heroDist >= 3 then
                    candidates[#candidates + 1] = {col = col, row = row}
                end
            end
        end
    end

    -- 随机打乱
    for i = #candidates, 2, -1 do
        local j = math.random(1, i)
        candidates[i], candidates[j] = candidates[j], candidates[i]
    end

    -- 选取祭坛位置（相互间距 >= 3）
    for _, pos in ipairs(candidates) do
        if #board.altars >= count then break end
        local tooClose = false
        for _, alt in ipairs(board.altars) do
            if hexDist(pos.col, pos.row, alt.col, alt.row) < 3 then
                tooClose = true
                break
            end
        end
        if not tooClose then
            board.altars[#board.altars + 1] = { col = pos.col, row = pos.row, active = true }
            Battle.AddVFX(state, "spawn_puff", { col = pos.col, row = pos.row, duration = 0.8 })
        end
    end

    Battle.AddLog(state, string.format("🔥 放置了 %d 个炎魔祭坛", #board.altars))
end

--- 获取指定位置的祭坛
function Battle.GetAltarAt(board, col, row)
    for _, alt in ipairs(board.altars) do
        if alt.active and alt.col == col and alt.row == row then
            return alt
        end
    end
    return nil
end

--- 计算某位置被多少个活跃祭坛笼罩
function Battle.CountNearActiveAltars(board, col, row)
    local count = 0
    for _, alt in ipairs(board.altars) do
        if alt.active and hexDist(col, row, alt.col, alt.row) <= Battle.ALTAR_RADIUS then
            count = count + 1
        end
    end
    return count
end

--- 判断敌人是否在任意活跃祭坛范围内（兼容接口）
function Battle.IsNearActiveAltar(board, col, row)
    return Battle.CountNearActiveAltars(board, col, row) > 0
end

-- ============================================================================
-- 套装效果专用测试关卡
-- ============================================================================

--- 生成飞跃先锋测试关卡：多对连续敌人，方便测试双敌跳跃
function Battle.GenerateTestLevel_LeapPioneer(state)
    state.level = 1
    state.testMode = "leap_pioneer"
    local board = state.board

    -- 清空棋盘
    board.pieces = {}
    board.obstacles = {}
    board.items = {}
    board.poisonTiles = {}
    board.wards = {}
    board.frostTiles = {}

    -- 确保使用正六边形棋盘
    HexGrid.ResetToHexagon()
    board.cols = HexGrid.COLS
    board.rows = HexGrid.ROWS

    state.kills = 0
    state.killTarget = 999  -- 测试关不通过击杀通关
    state.comboKillCount = 0
    state.comboAtkBonus = 0
    state.boss = nil

    -- 英雄放置在底部中央
    local heroCol = HexGrid.CENTER_COL  -- 5
    local heroRow = HexGrid.CENTER_ROW + HexGrid.RADIUS  -- 9
    if not state.hero then
        state.hero = Battle.CreatePiece(HERO_TEMPLATE, heroCol, heroRow)
        local bs = state.bonusStats or {}
        state.hero.atk = math.floor(state.hero.atk + (bs.atk or 0))
        state.hero.def = math.floor(state.hero.def + (bs.def or 0))
        state.hero.hp = math.floor(state.hero.hp + (bs.hp or 0))
        state.hero.maxHp = math.floor(state.hero.maxHp + (bs.hp or 0))
    else
        state.hero.col = heroCol
        state.hero.row = heroRow
    end

    -- 初始化套装效果
    if G.playerData then
        state.critRate = PlayerData.GetCritRate(G.playerData)
        state.goldBonus = PlayerData.GetGoldBonus(G.playerData)
        state.setEffects = SetEffects.Init(G.playerData.equipment, state.critRate)
    end

    HexGrid.AddPiece(board, state.hero)

    -- 弱敌模板：低HP便于测试，不会轻易击杀英雄
    local weakTemplate = {
        team = "enemy", enemyType = "slime",
        hp = 15, maxHp = 15, atk = 1, attackRange = 1,
        attackLabel = "轻触", name = "测试靶",
    }

    -- ── 敌人布局：3组双敌对 + 1组延伸对 + 散落敌人 ──
    local allEnemies = {
        -- 组1: hero(5,9) NE直跳
        {col=5, row=8},
        {col=6, row=7},
        -- 组2: hero(5,9) NW直跳
        {col=4, row=8},
        {col=4, row=7},
        -- 组3: hero(5,9)→E跳到(7,9)，再NE双跳
        {col=6, row=9},   -- 跳板
        {col=7, row=8},
        {col=8, row=7},
        -- 组4: 从组2落点(3,6)继续NW双跳
        {col=3, row=5},
        {col=2, row=4},
        -- 补充：中部散落单敌，让测试更灵活
        {col=5, row=5},   -- 中心
        {col=7, row=5},   -- 右侧
        {col=3, row=3},   -- 左上
    }

    for _, pos in ipairs(allEnemies) do
        if HexGrid.InBounds(pos.col, pos.row) then
            local piece = Battle.CreatePiece(weakTemplate, pos.col, pos.row)
            HexGrid.AddPiece(board, piece)
        end
    end

    Battle.AddLog(state, "=== 🦅 飞跃先锋 测试关卡 ===")
    Battle.AddLog(state, "提示: 连续2个敌人排成一线时，可一跳跳过2个！")
    Battle.AddLog(state, "测试提示: NE/NW方向有连续敌人对，尝试双敌跳跃！")
end

--- 生成飞跃先锋6/6专用测试关卡：多组3连敌人直线排布，专门测试三连跳效果
--- 布局说明:
---   英雄(5,9)出发，可立刻触发A/B两个三连跳组
---   落地后分别能接C/D/E三组，形成完整的三连跳连锁链路
function Battle.GenerateTestLevel_LeapPioneer6(state)
    state.level = 1
    state.testMode = "leap_pioneer"
    local board = state.board

    board.pieces   = {}
    board.obstacles = {}
    board.items     = {}
    board.poisonTiles = {}
    board.wards = {}
    board.frostTiles = {}

    HexGrid.ResetToHexagon()
    board.cols = HexGrid.COLS
    board.rows = HexGrid.ROWS

    state.kills          = 0
    state.killTarget     = 999
    state.comboKillCount = 0
    state.comboAtkBonus  = 0
    state.boss           = nil

    -- 英雄 → 底部中央
    local heroCol = HexGrid.CENTER_COL   -- 5
    local heroRow = HexGrid.CENTER_ROW + HexGrid.RADIUS  -- 9
    if not state.hero then
        state.hero = Battle.CreatePiece(HERO_TEMPLATE, heroCol, heroRow)
        local bs = state.bonusStats or {}
        state.hero.atk    = math.floor(state.hero.atk    + (bs.atk or 0))
        state.hero.def    = math.floor(state.hero.def    + (bs.def or 0))
        state.hero.hp     = math.floor(state.hero.hp     + (bs.hp  or 0))
        state.hero.maxHp  = math.floor(state.hero.maxHp  + (bs.hp  or 0))
    else
        state.hero.col = heroCol
        state.hero.row = heroRow
    end

    -- 初始化6/6套装效果
    if G.playerData then
        state.critRate  = PlayerData.GetCritRate(G.playerData)
        state.goldBonus = PlayerData.GetGoldBonus(G.playerData)
        state.setEffects = SetEffects.Init(G.playerData.equipment, state.critRate)
    end

    HexGrid.AddPiece(board, state.hero)

    -- 测试靶模板：足够承受1次攻击，方便反复观察三连特效
    local tpl = {
        team = "enemy", enemyType = "slime",
        hp = 40, maxHp = 40, atk = 1, attackRange = 1,
        attackLabel = "轻触", name = "三连靶",
    }

    --[[
      三连跳需要：英雄 → E1 → E2 → E3 → 落点（全在同一直线，每格相邻）
      坐标系：odd-row offset，六向cube坐标

      【组A】英雄(5,9) 方向{1,0,-1}（NE斜右）
        E1(5,8)→E2(6,7)→E3(6,6)  落点(7,5)
      【组B】英雄(5,9) 方向{0,1,-1}（NW斜左）
        E1(4,8)→E2(4,7)→E3(3,6)  落点(3,5)
      【组D】落地(7,5) 方向{0,1,-1}（NW斜左）
        E1(6,4)→E2(6,3)→E3(5,2)  落点(5,1)
      【组E】落地(7,5) 方向{-1,1,0}（正左）
        E1(6,5)→E2(5,5)→E3(4,5)  落点(3,5)
      【组C】落地(3,5) 方向{1,0,-1}（NE斜右）
        E1(3,4)→E2(4,3)→E3(4,2)  落点(5,1)
    --]]
    local tripleGroups = {
        -- 组A
        {col=5,row=8}, {col=6,row=7}, {col=6,row=6},
        -- 组B
        {col=4,row=8}, {col=4,row=7}, {col=3,row=6},
        -- 组D (落地(7,5)后可触发)
        {col=6,row=4}, {col=6,row=3}, {col=5,row=2},
        -- 组E (落地(7,5)后可触发，向左穿越中心)
        {col=6,row=5}, {col=5,row=5}, {col=4,row=5},
        -- 组C (落地(3,5)后可触发)
        {col=3,row=4}, {col=4,row=3}, {col=4,row=2},
    }

    for _, pos in ipairs(tripleGroups) do
        if HexGrid.InBounds(pos.col, pos.row) then
            local piece = Battle.CreatePiece(tpl, pos.col, pos.row)
            HexGrid.AddPiece(board, piece)
        end
    end

    Battle.AddLog(state, "=== 🦅 飞跃先锋6/6 三连跳 测试关卡 ===")
    Battle.AddLog(state, "【组A】NE方向: (5,8)→(6,7)→(6,6)，落点(7,5)")
    Battle.AddLog(state, "【组B】NW方向: (4,8)→(4,7)→(3,6)，落点(3,5)")
    Battle.AddLog(state, "落地后可续接 D组/E组 或 C组，形成三连跳链路！")
    Battle.AddLog(state, "提示: 需穿戴飞跃先锋6件金色套装才能触发三连跳")
end

--- 生成飞跃先锋含岩石测试关卡：敌人+岩石混合排列，测试第三章跳2/跳3
--- 布局说明:
---   level=21（第三章），启用 ch3Rocks 岩石作为跳跃支点
---   组A: E+R 双跳 (敌人+岩石)
---   组B: R+E 双跳 (岩石+敌人)
---   组C: E+R+E 三连跳 (敌人+岩石+敌人)
---   组D: R+E+R 三连跳 (岩石+敌人+岩石)
---   组E: E+E+R 三连跳 (敌人+敌人+岩石)
function Battle.GenerateTestLevel_LeapPioneerRocks(state)
    state.level = 21  -- 第三章，启用 ch3Rocks
    state.testMode = "leap_pioneer"
    local board = state.board

    board.pieces    = {}
    board.obstacles = {}
    board.items     = {}
    board.poisonTiles = {}
    board.wards     = {}
    board.frostTiles = {}
    board.crabs     = {}
    board.shells    = {}

    HexGrid.ResetToHexagon()
    board.cols = HexGrid.COLS
    board.rows = HexGrid.ROWS

    state.kills          = 0
    state.killTarget     = 999
    state.comboKillCount = 0
    state.comboAtkBonus  = 0
    state.boss           = nil

    -- 英雄 → 底部中央
    local heroCol = HexGrid.CENTER_COL   -- 5
    local heroRow = HexGrid.CENTER_ROW + HexGrid.RADIUS  -- 9
    if not state.hero then
        state.hero = Battle.CreatePiece(HERO_TEMPLATE, heroCol, heroRow)
        local bs = state.bonusStats or {}
        state.hero.atk    = math.floor(state.hero.atk    + (bs.atk or 0))
        state.hero.def    = math.floor(state.hero.def    + (bs.def or 0))
        state.hero.hp     = math.floor(state.hero.hp     + (bs.hp  or 0))
        state.hero.maxHp  = math.floor(state.hero.maxHp  + (bs.hp  or 0))
    else
        state.hero.col = heroCol
        state.hero.row = heroRow
    end

    if G.playerData then
        state.critRate  = PlayerData.GetCritRate(G.playerData)
        state.goldBonus = PlayerData.GetGoldBonus(G.playerData)
        state.setEffects = SetEffects.Init(G.playerData.equipment, state.critRate)
    end

    HexGrid.AddPiece(board, state.hero)

    local tpl = {
        team = "enemy", enemyType = "slime",
        hp = 30, maxHp = 30, atk = 1, attackRange = 1,
        attackLabel = "轻触", name = "岩石靶",
    }

    --[[
      英雄(5,9) — odd-row offset 坐标系
      方向参考(NE = row-1, col按奇偶行调整):
        奇数行(row=9): NE→(5,8), NW→(4,8), E→(6,9), W→(4,9)
        偶数行(row=8): NE→(6,7), NW→(5,7)

      ===== 跳2组 (4/6套装即可) =====

      【组A】E+R: hero(5,9) → NE方向
        位置1: 敌人(5,8)
        位置2: 岩石(6,7)
        落点: (6,6)

      【组B】R+E: hero(5,9) → NW方向
        位置1: 岩石(4,8)  ← 石头开头
        位置2: 敌人(4,7)
        落点: (3,6)

      ===== 跳3组 (6/6套装) =====

      【组C】E+R+E: 从落点(6,6)出发 → NW方向
        位置1: 敌人(5,5)
        位置2: 岩石(5,4)
        位置3: 敌人(4,3)
        落点: (4,2)

      【组D】R+E+R: 从落点(3,6)出发 → NE方向
        位置1: 岩石(3,5)   ← 石头开头
        位置2: 敌人(4,4)
        位置3: 岩石(4,3)   ← 与组C共用？不，用独立的(5,3)
        改：从(3,6) → E方向(偶数行 E = col+1,same row)
        实际用另一个方向避免冲突:
        从hero(5,9) → E方向:
        位置1: 岩石(6,9)
        位置2: 敌人(7,9)
        位置3: 岩石(8,9)
        落点: (9,9) — 可能越界

      改用更安全的布局:
      【组D】R+E+R: 从(3,6)→ NE方向(偶数行row=6: NE=(4,5))
        位置1: 岩石(4,5)
        位置2: 敌人(4,4)
        位置3: 岩石(5,3)
        落点: (5,2)

      【组E】E+E+R: hero(5,9)→ 正上方(row-2同列,但hex无正上)
        改：从hero(5,9)向W: W方向(4,9)
        hero在奇数行row=9: W=(4,9)
        位置1: 敌人(4,9) — 但这会挡住其他方向
        改用独立起点: 从组A落点(6,6) → NE方向(偶数行: NE=(7,5))
        位置1: 敌人(7,5)
        位置2: 敌人(7,4)
        位置3: 岩石(8,3)
        落点: (8,2) — 检查边界
    ]]

    -- ===== 跳2测试 =====

    -- 组A: E+R (NE方向) — hero(5,9)向NE
    local piece_a1 = Battle.CreatePiece(tpl, 5, 8)  -- 敌人
    HexGrid.AddPiece(board, piece_a1)
    HexGrid.AddObstacle(board, 6, 7)                 -- 岩石

    -- 组B: R+E (NW方向) — hero(5,9)向NW
    HexGrid.AddObstacle(board, 4, 8)                 -- 岩石（开头）
    local piece_b2 = Battle.CreatePiece(tpl, 4, 7)  -- 敌人
    HexGrid.AddPiece(board, piece_b2)

    -- ===== 跳3测试 =====

    -- 组C: E+R+E — 从组A落点(6,6)向NW方向
    -- 偶数行row=6: NW = (col-1, row-1) = (5,5)
    local piece_c1 = Battle.CreatePiece(tpl, 5, 5)  -- 敌人
    HexGrid.AddPiece(board, piece_c1)
    HexGrid.AddObstacle(board, 5, 4)                 -- 岩石
    local piece_c3 = Battle.CreatePiece(tpl, 4, 3)  -- 敌人
    HexGrid.AddPiece(board, piece_c3)

    -- 组D: R+E+R — 从组B落点(3,6)向NE方向
    -- 偶数行row=6: NE = (col+1, row-1) = (4,5)
    HexGrid.AddObstacle(board, 4, 5)                 -- 岩石（开头）
    local piece_d2 = Battle.CreatePiece(tpl, 4, 4)  -- 敌人
    HexGrid.AddPiece(board, piece_d2)
    HexGrid.AddObstacle(board, 5, 3)                 -- 岩石

    -- 组E: E+E+R — 从组A落点(6,6)向NE方向
    -- 偶数行row=6: NE = (7,5)
    local piece_e1 = Battle.CreatePiece(tpl, 7, 5)  -- 敌人
    HexGrid.AddPiece(board, piece_e1)
    local piece_e2 = Battle.CreatePiece(tpl, 7, 4)  -- 敌人 (奇数行row=5: NE=(7,4))
    HexGrid.AddPiece(board, piece_e2)
    HexGrid.AddObstacle(board, 8, 3)                 -- 岩石

    Battle.AddLog(state, "=== 🦅🪨 飞跃先锋 岩石测试关 (第三章) ===")
    Battle.AddLog(state, "【跳2】组A(NE): 敌(5,8)+石(6,7) → 落(6,6)")
    Battle.AddLog(state, "【跳2】组B(NW): 石(4,8)+敌(4,7) → 落(3,6)")
    Battle.AddLog(state, "【跳3】组C(NW): 敌(5,5)+石(5,4)+敌(4,3) → 落(4,2) [从(6,6)出发]")
    Battle.AddLog(state, "【跳3】组D(NE): 石(4,5)+敌(4,4)+石(5,3) → 落(5,2) [从(3,6)出发]")
    Battle.AddLog(state, "【跳3】组E(NE): 敌(7,5)+敌(7,4)+石(8,3) → 落(8,2) [从(6,6)出发]")
    Battle.AddLog(state, "提示: 4/6可跳2(含岩石)，6/6可跳3(含岩石)")
end

--- 生成连击心得测试关卡：锯齿形敌人链，方便测试连跳combo奖励
function Battle.GenerateTestLevel_ComboMastery(state)
    state.level = 1
    state.testMode = "combo_mastery"
    local board = state.board

    -- 清空棋盘
    board.pieces = {}
    board.obstacles = {}
    board.items = {}
    board.poisonTiles = {}
    board.wards = {}
    board.frostTiles = {}

    -- 确保使用正六边形棋盘
    HexGrid.ResetToHexagon()
    board.cols = HexGrid.COLS
    board.rows = HexGrid.ROWS

    state.kills = 0
    state.killTarget = 999
    state.comboKillCount = 0
    state.comboAtkBonus = 0
    state.boss = nil

    -- 英雄放置在底部中央
    local heroCol = HexGrid.CENTER_COL
    local heroRow = HexGrid.CENTER_ROW + HexGrid.RADIUS
    if not state.hero then
        state.hero = Battle.CreatePiece(HERO_TEMPLATE, heroCol, heroRow)
        local bs = state.bonusStats or {}
        state.hero.atk = math.floor(state.hero.atk + (bs.atk or 0))
        state.hero.def = math.floor(state.hero.def + (bs.def or 0))
        state.hero.hp = math.floor(state.hero.hp + (bs.hp or 0))
        state.hero.maxHp = math.floor(state.hero.maxHp + (bs.hp or 0))
    else
        state.hero.col = heroCol
        state.hero.row = heroRow
    end

    -- 初始化套装效果
    if G.playerData then
        state.critRate = PlayerData.GetCritRate(G.playerData)
        state.goldBonus = PlayerData.GetGoldBonus(G.playerData)
        state.setEffects = SetEffects.Init(G.playerData.equipment, state.critRate)
    end

    HexGrid.AddPiece(board, state.hero)

    -- 弱敌模板：低HP方便连跳
    local weakTemplate = {
        team = "enemy", enemyType = "slime",
        hp = 10, maxHp = 10, atk = 1, attackRange = 1,
        attackLabel = "轻触", name = "测试靶",
    }

    -- ── 锯齿形6跳链路 ──
    -- 路径: (5,9)→NE→(6,7)→W→(4,7)→NW→(3,5)→NE→(4,3)→E→(6,3)→NW→(5,1)
    local chainEnemies = {
        {col=5, row=8},   -- 跳1: hero(5,9) NE跳过 → 落(6,7)
        {col=5, row=7},   -- 跳2: (6,7) W跳过 → 落(4,7)
        {col=3, row=6},   -- 跳3: (4,7) NW跳过 → 落(3,5)
        {col=3, row=4},   -- 跳4: (3,5) NE跳过 → 落(4,3)
        {col=5, row=3},   -- 跳5: (4,3) E跳过 → 落(6,3)
        {col=5, row=2},   -- 跳6: (6,3) NW跳过 → 落(5,1)
    }

    -- ── 第二条链路（右侧平行） ──
    -- 从(6,7)落点处分叉，向NE继续
    -- (6,7)→NE: enemy at (7,6), land at (7,5)
    -- (7,5)→NW: enemy at (6,4), land at (6,3) (已是主链落点)
    -- 再加几个散落敌人供自由练习
    local extraEnemies = {
        {col=7, row=6},   -- 分支跳1: (6,7) NE
        {col=6, row=4},   -- 分支跳2: (7,5) NW
        -- 散落敌人：增加连跳机会
        {col=7, row=4},   -- 右侧
        {col=4, row=5},   -- 中左
        {col=6, row=5},   -- 中右
    }

    for _, pos in ipairs(chainEnemies) do
        if HexGrid.InBounds(pos.col, pos.row) then
            local piece = Battle.CreatePiece(weakTemplate, pos.col, pos.row)
            HexGrid.AddPiece(board, piece)
        end
    end
    for _, pos in ipairs(extraEnemies) do
        if HexGrid.InBounds(pos.col, pos.row) then
            local piece = Battle.CreatePiece(weakTemplate, pos.col, pos.row)
            HexGrid.AddPiece(board, piece)
        end
    end

    Battle.AddLog(state, "=== 🔥 连击心得 测试关卡 ===")
    Battle.AddLog(state, "提示: 规划连续跳跃路径，一次选择多个跳跃形成连击链！")
    Battle.AddLog(state, "锯齿形敌人链: 从底部跳到顶部，可达6连击！")
end

-- ============================================================================
-- Boss 测试关卡
-- ============================================================================

--- 初始化 Boss 测试关卡的通用部分（清空棋盘、放置英雄、设置状态）
---@param state table
---@param testName string
local function initBossTestLevel(state, testName, chapter)
    chapter = chapter or 1
    state.level = chapter * Battle.LEVELS_PER_CHAPTER  -- Boss关需要为10的倍数，且章节号要正确
    state.testMode = testName
    local board = state.board

    -- 清空棋盘
    board.pieces = {}
    board.obstacles = {}
    board.items = {}
    board.poisonTiles = {}
    board.wards = {}
    board.frostTiles = {}
    board.altars = {}

    -- 确保使用正六边形棋盘
    HexGrid.ResetToHexagon()
    board.cols = HexGrid.COLS
    board.rows = HexGrid.ROWS

    state.kills = 0
    state.killTarget = 999  -- Boss关: 击杀Boss即过关
    state.comboKillCount = 0
    state.comboAtkBonus = 0

    -- 英雄放置在底部中央
    local heroCol = HexGrid.CENTER_COL
    local heroRow = HexGrid.CENTER_ROW + HexGrid.RADIUS
    if not state.hero then
        state.hero = Battle.CreatePiece(HERO_TEMPLATE, heroCol, heroRow)
        local bs = state.bonusStats or {}
        state.hero.atk = math.floor(state.hero.atk + (bs.atk or 0))
        state.hero.def = math.floor(state.hero.def + (bs.def or 0))
        state.hero.hp = math.floor(state.hero.hp + (bs.hp or 0))
        state.hero.maxHp = math.floor(state.hero.maxHp + (bs.hp or 0))
    else
        state.hero.col = heroCol
        state.hero.row = heroRow
    end

    -- 初始化套装效果
    if G.playerData then
        state.critRate = PlayerData.GetCritRate(G.playerData)
        state.goldBonus = PlayerData.GetGoldBonus(G.playerData)
        state.setEffects = SetEffects.Init(G.playerData.equipment, state.critRate)
    end

    HexGrid.AddPiece(board, state.hero)
    return heroCol, heroRow
end

--- 在 Boss 测试关卡中放置 Boss
---@param state table
---@param bossKey string
---@param chapter number 用于缩放系数
---@return table boss
local function placeBossForTest(state, bossKey, chapter)
    local board = state.board
    local bossTemplate = BOSS_TEMPLATES[bossKey]

    local bossCol = HexGrid.CENTER_COL
    local bossRow = HexGrid.CENTER_ROW - HexGrid.RADIUS + 1

    local boss = Battle.CreatePiece(bossTemplate, bossCol, bossRow)
    -- 与正式关卡相同的缩放
    local bossHpScale = 1.0 + 0.15 * (chapter - 1)
    local bossAtkScale = 1.0 + 0.1 * (chapter - 1)
    boss.hp = math.floor(boss.hp * bossHpScale)
    boss.maxHp = boss.hp
    boss.atk = math.floor(boss.atk * bossAtkScale)
    boss.shieldMax = math.floor(boss.shieldMax * bossHpScale)
    HexGrid.AddPiece(board, boss)
    state.boss = boss

    -- Boss 入场公告
    local bossIcons = {
        shadow_knight = "🗡️",
        lava_lord = "🌋",
        abyss_kraken = "🐙",
        coral_guardian = "🪸",
    }
    state.bossAnnouncement = {
        bossName = boss.name,
        icon = bossIcons[bossKey] or "💀",
        chapter = chapter,
        timer = 3.5,
        maxTimer = 3.5,
    }
    state.screenShake = 0.6

    return boss
end

--- 在 Boss 测试关卡中放置小怪
---@param state table
---@param enemyTypes string[] 可用敌人类型列表
---@param count number 小怪数量
---@param chapter number 用于缩放
---@param usedPositions table 已占用位置集合
local function placeMinionsForTest(state, enemyTypes, count, chapter, usedPositions)
    local board = state.board
    local bossHpScaleM = 1.0 + 0.12 * (chapter - 1)
    local bossAtkScaleM = 1.0 + 0.08 * (chapter - 1)

    -- 收集空位，优先中间环带
    local candidates = {}
    for r = 1, HexGrid.ROWS do
        for c = 1, HexGrid.COLS do
            if HexGrid.InBounds(c, r) then
                local key = c .. "," .. r
                if not usedPositions[key] then
                    local dist = HexGrid.CubeDistance(c, r, HexGrid.CENTER_COL, HexGrid.CENTER_ROW)
                    local score = math.abs(dist - 2.5)
                    candidates[#candidates + 1] = { col = c, row = r, score = score }
                end
            end
        end
    end
    for _, mc in ipairs(candidates) do
        mc.sortKey = mc.score + math.random() * 1.5
    end
    table.sort(candidates, function(a, b) return a.sortKey < b.sortKey end)

    for i = 1, math.min(count, #candidates) do
        local pos = candidates[i]
        usedPositions[pos.col .. "," .. pos.row] = true
        local etype = enemyTypes[math.random(1, #enemyTypes)]
        local template = ENEMY_TEMPLATES[etype]
        local minion = Battle.CreatePiece(template, pos.col, pos.row)
        minion.hp = math.floor(minion.hp * bossHpScaleM)
        minion.maxHp = minion.hp
        if minion.atk > 0 then
            minion.atk = math.floor(minion.atk * bossAtkScaleM)
        end
        HexGrid.AddPiece(board, minion)
    end
end

--- 生成第一关 Boss 测试关卡：深渊海妖
function Battle.GenerateTestLevel_Boss_AbyssKraken(state)
    local heroCol, heroRow = initBossTestLevel(state, "boss_abyss_kraken", 1)

    local usedPositions = {}
    usedPositions[heroCol .. "," .. heroRow] = true

    -- 放置 Boss
    local boss = placeBossForTest(state, "abyss_kraken", 1)
    usedPositions[boss.col .. "," .. boss.row] = true

    -- 第一章小怪
    placeMinionsForTest(state, { "slime", "skeleton", "jellyfish", "iron_turtle" }, 5, 1, usedPositions)

    -- 道具
    Battle.TrySpawnItems(state, 2)

    Battle.AddLog(state, "=== 🐙 Boss测试: 深渊海妖 (第一章) ===")
    Battle.AddLog(state, "特色: 深渊触手封路、漩涡牵引、深渊护盾")
    Battle.AddLog(state, "提示: 狂暴后棋盘会收缩，保持距离！")
end

--- 生成第二关 Boss 测试关卡：熔岩领主（含炎魔祭坛）
function Battle.GenerateTestLevel_Boss_LavaLord(state)
    local heroCol, heroRow = initBossTestLevel(state, "boss_lava_lord", 2)

    local usedPositions = {}
    usedPositions[heroCol .. "," .. heroRow] = true

    -- 放置 Boss
    local boss = placeBossForTest(state, "lava_lord", 2)
    usedPositions[boss.col .. "," .. boss.row] = true

    -- 第二章Boss战不放障碍（用祭坛机制替代）

    -- 第二章小怪（减少数量降低视觉负担）
    placeMinionsForTest(state, { "fire_sprite", "lava_giant" }, 5, 2, usedPositions)

    -- 第二章Boss战：放置3个火焰祭坛（全灭破盾）
    Battle.PlaceAltars(state, 3)
    Battle.UpdateAltarShields(state)

    -- 大血瓶
    local potCandidates = {}
    for r = 1, HexGrid.ROWS do
        for c = 1, HexGrid.COLS do
            if HexGrid.InBounds(c, r) and not usedPositions[c..","..r] then
                potCandidates[#potCandidates + 1] = {col = c, row = r}
            end
        end
    end
    if #potCandidates > 0 then
        local pot = potCandidates[math.random(1, #potCandidates)]
        HexGrid.AddItem(state.board, { col = pot.col, row = pot.row, type = "health_potion_big" })
    end
    Battle.TrySpawnItems(state, 2)

    Battle.AddLog(state, "=== 🌋 Boss测试: 熔岩领主 (第二章) ===")
    Battle.AddLog(state, "特色: 熔岩喷发放置岩浆地形，岩甲再生恢复护盾")
    Battle.AddLog(state, "提示: 踩灭3个火焰祭坛可破除Boss护盾！")
end

--- 生成第三关 Boss 测试关卡：珊瑚守卫（含珊瑚路障+召唤）
function Battle.GenerateTestLevel_Boss_CoralGuardian(state)
    local heroCol, heroRow = initBossTestLevel(state, "boss_coral_guardian", 3)

    local usedPositions = {}
    usedPositions[heroCol .. "," .. heroRow] = true

    -- 放置 Boss
    local boss = placeBossForTest(state, "coral_guardian", 3)
    usedPositions[boss.col .. "," .. boss.row] = true

    -- 少量障碍（第三章珊瑚路障由Boss技能放置，初始少一些）
    for i = 1, 2 do
        local attempts = 0
        while attempts < 50 do
            local c = math.random(1, HexGrid.COLS)
            local r = math.random(1, HexGrid.ROWS)
            if HexGrid.InBounds(c, r) and not usedPositions[c..","..r] then
                usedPositions[c..","..r] = true
                HexGrid.AddObstacle(state.board, c, r)
                break
            end
            attempts = attempts + 1
        end
    end

    -- 第三章小怪
    placeMinionsForTest(state, { "coral_snapper", "sea_urchin", "reef_starfish", "splitting_urchin" }, 8, 3, usedPositions)

    -- 大血瓶
    local potCandidates = {}
    for r = 1, HexGrid.ROWS do
        for c = 1, HexGrid.COLS do
            if HexGrid.InBounds(c, r) and not usedPositions[c..","..r] then
                potCandidates[#potCandidates + 1] = {col = c, row = r}
            end
        end
    end
    if #potCandidates > 0 then
        local pot = potCandidates[math.random(1, #potCandidates)]
        HexGrid.AddItem(state.board, { col = pot.col, row = pot.row, type = "health_potion_big" })
    end
    Battle.TrySpawnItems(state, 2)

    Battle.AddLog(state, "=== 🪸 Boss测试: 珊瑚守卫 (第三章) ===")
    Battle.AddLog(state, "特色: 珊瑚路障封锁英雄移动，召唤海洋生物增援")
    Battle.AddLog(state, "提示: 注意走位避开障碍包围，优先击杀召唤物")
end

--- 生成嗜血套装测试关卡
--- 设计目标：
---   4/6 效果：击杀回血 — 密集小怪方便连续击杀，验证每杀回血
---   6/6 效果：血怒叠层 — 英雄HP被压低到<50%后，通过击杀累积血怒（最多3层），
---             血怒层数会在下次攻击时消耗并将ATK×1.5
function Battle.GenerateTestLevel_SoulHunter(state)
    state.level = 1
    state.testMode = "soul_hunter"
    local board = state.board

    board.pieces   = {}
    board.obstacles = {}
    board.items    = {}
    board.poisonTiles = {}
    board.wards = {}
    board.frostTiles = {}

    HexGrid.ResetToHexagon()
    board.cols = HexGrid.COLS
    board.rows = HexGrid.ROWS

    state.kills         = 0
    state.killTarget    = 999
    state.comboKillCount = 0
    state.comboAtkBonus  = 0
    state.boss           = nil

    local heroCol = HexGrid.CENTER_COL
    local heroRow = HexGrid.CENTER_ROW + HexGrid.RADIUS
    if not state.hero then
        state.hero = Battle.CreatePiece(HERO_TEMPLATE, heroCol, heroRow)
        local bs = state.bonusStats or {}
        state.hero.atk  = math.floor(state.hero.atk  + (bs.atk or 0))
        state.hero.def  = math.floor(state.hero.def  + (bs.def or 0))
        state.hero.hp   = math.floor(state.hero.hp   + (bs.hp  or 0))
        state.hero.maxHp = math.floor(state.hero.maxHp + (bs.hp or 0))
    else
        state.hero.col = heroCol
        state.hero.row = heroRow
    end

    -- 初始化套装效果
    if G.playerData then
        state.critRate  = PlayerData.GetCritRate(G.playerData)
        state.goldBonus = PlayerData.GetGoldBonus(G.playerData)
        state.setEffects = SetEffects.Init(G.playerData.equipment, state.critRate)
    end

    -- 将英雄HP压低到45%，触发6/6血怒条件
    state.hero.hp = math.max(1, math.floor(state.hero.maxHp * 0.45))

    HexGrid.AddPiece(board, state.hero)

    -- 大量弱敌：HP极低，方便逐一击杀堆叠血怒和验证回血
    local weakTemplate = {
        team = "enemy", enemyType = "slime",
        hp = 8, maxHp = 8, atk = 4, attackRange = 1,
        attackLabel = "轻咬", name = "血靶",
    }
    -- 强敌模板：HP较高，用于验证血怒ATK×1.5倍效果
    local strongTemplate = {
        team = "enemy", enemyType = "troll",
        hp = 60, maxHp = 60, atk = 6, attackRange = 1,
        attackLabel = "重击", name = "铁靶",
    }

    -- 弱敌：密集分布，连续击杀叠血怒
    local weakPositions = {
        {col=5, row=8}, {col=4, row=8}, {col=6, row=8},
        {col=4, row=7}, {col=6, row=7},
        {col=5, row=6}, {col=3, row=6}, {col=7, row=6},
        {col=4, row=5}, {col=6, row=5},
        {col=3, row=4}, {col=5, row=4},
    }
    -- 强敌：放在上半区，用于验证血怒爆发伤害
    local strongPositions = {
        {col=5, row=3},
        {col=3, row=3},
        {col=7, row=3},
    }

    for _, pos in ipairs(weakPositions) do
        if HexGrid.InBounds(pos.col, pos.row) then
            HexGrid.AddPiece(board, Battle.CreatePiece(weakTemplate, pos.col, pos.row))
        end
    end
    for _, pos in ipairs(strongPositions) do
        if HexGrid.InBounds(pos.col, pos.row) then
            HexGrid.AddPiece(board, Battle.CreatePiece(strongTemplate, pos.col, pos.row))
        end
    end

    -- 放置1个大血瓶，方便测试回血后血怒重置触发
    HexGrid.AddItem(board, { col = 7, row = 7, type = "health_potion_big" })

    Battle.AddLog(state, "=== 🩸 嗜血套装 测试关卡 ===")
    Battle.AddLog(state, "英雄HP已压至45%，满足6/6血怒触发条件(HP<50%)")
    Battle.AddLog(state, "4/6: 击杀血靶验证回血；6/6: 击杀累积血怒，对铁靶验证ATK×1.5爆发")
    Battle.AddLog(state, "血怒最多3层，每次攻击消耗1层，注意观察浮动文字")
end

--- 生成踏步斩技能测试关卡
--- 踏步斩：每次移动时自动对最近敌人造成近战伤害
---   Lv1-2: 打最近1个；Lv3-4: 打最近2个；Lv5: 打最近3个+击中回5HP
--- 测试关卡强制设为 Lv5，展示全部效果
function Battle.GenerateTestLevel_StepStrike(state)
    state.level = 1
    state.testMode = "step_strike"
    local board = state.board

    board.pieces    = {}
    board.obstacles = {}
    board.items     = {}
    board.poisonTiles = {}
    board.wards = {}
    board.frostTiles = {}

    HexGrid.ResetToHexagon()
    board.cols = HexGrid.COLS
    board.rows = HexGrid.ROWS

    state.kills         = 0
    state.killTarget    = 999
    state.comboKillCount = 0
    state.comboAtkBonus  = 0
    state.boss           = nil

    local heroCol = HexGrid.CENTER_COL
    local heroRow = HexGrid.CENTER_ROW + HexGrid.RADIUS
    if not state.hero then
        state.hero = Battle.CreatePiece(HERO_TEMPLATE, heroCol, heroRow)
        local bs = state.bonusStats or {}
        state.hero.atk  = math.floor(state.hero.atk  + (bs.atk or 0))
        state.hero.def  = math.floor(state.hero.def  + (bs.def or 0))
        state.hero.hp   = math.floor(state.hero.hp   + (bs.hp  or 0))
        state.hero.maxHp = math.floor(state.hero.maxHp + (bs.hp or 0))
    else
        state.hero.col = heroCol
        state.hero.row = heroRow
    end

    -- 强制踏步斩 Lv5（覆盖 playerData 中的等级）
    state.skills = state.skills or {}
    state.skills["step_strike"] = 5

    -- 初始化套装效果
    if G.playerData then
        state.critRate  = PlayerData.GetCritRate(G.playerData)
        state.goldBonus = PlayerData.GetGoldBonus(G.playerData)
        state.setEffects = SetEffects.Init(G.playerData.equipment, state.critRate)
    end

    HexGrid.AddPiece(board, state.hero)

    -- 耐打靶：HP高、不会轻易死，方便多次移动触发踏步斩观察伤害
    local tankTemplate = {
        team = "enemy", enemyType = "iron_turtle",
        hp = 120, maxHp = 120, atk = 2, attackRange = 1,
        attackLabel = "撞击", name = "踏步靶",
    }
    -- 弱靶：放在跳跃落点，验证移动到达后踏步斩是否立即触发
    local weakTemplate = {
        team = "enemy", enemyType = "slime",
        hp = 15, maxHp = 15, atk = 1, attackRange = 1,
        attackLabel = "轻触", name = "跳点靶",
    }

    -- 靶子围绕中心区域分布：每次移动/跳跃落点附近都有敌人
    -- Lv5踏步斩打3个最近敌人，所以多放一些并且聚集
    local tankPositions = {
        {col=5, row=6}, {col=4, row=6}, {col=6, row=6},  -- 中央簇
        {col=3, row=5}, {col=7, row=5},                   -- 两侧
        {col=5, row=4}, {col=4, row=4}, {col=6, row=4},  -- 上方簇
        {col=3, row=3}, {col=5, row=2}, {col=7, row=3},  -- 顶部
    }
    -- 跳跃落点放弱靶，方便跳过去后立即看踏步斩效果
    local weakPositions = {
        {col=5, row=8}, {col=4, row=7}, {col=6, row=7},
        {col=5, row=5},
    }

    for _, pos in ipairs(tankPositions) do
        if HexGrid.InBounds(pos.col, pos.row) then
            HexGrid.AddPiece(board, Battle.CreatePiece(tankTemplate, pos.col, pos.row))
        end
    end
    for _, pos in ipairs(weakPositions) do
        if HexGrid.InBounds(pos.col, pos.row) then
            HexGrid.AddPiece(board, Battle.CreatePiece(weakTemplate, pos.col, pos.row))
        end
    end

    Battle.AddLog(state, "=== ⚔️ 踏步斩 测试关卡 (强制Lv5) ===")
    Battle.AddLog(state, "Lv5效果: 移动时打最近3个敌人各60伤害，每次击中回5HP")
    Battle.AddLog(state, "踏步靶(HP120)用于多次触发观察伤害；跳过跳点靶验证跳跃落地也触发")
    Battle.AddLog(state, "注意: 踏步斩在每步移动/每次跳跃落地时各触发一次")
end

--- 刷新所有敌人的祭坛减伤状态
--- 1个祭坛笼罩=80%减伤，2个及以上=90%减伤
function Battle.UpdateAltarShields(state)
    local enemies = HexGrid.GetTeamPieces(state.board, "enemy")
    for _, e in ipairs(enemies) do
        local altarCount = Battle.CountNearActiveAltars(state.board, e.col, e.row)
        if altarCount >= 2 then
            e.altarDamageReduction = 0.90
            e.altarShield = true  -- 保留用于渲染指示
        elseif altarCount == 1 then
            e.altarDamageReduction = 0.80
            e.altarShield = true
        else
            e.altarDamageReduction = 0
            e.altarShield = false
        end
    end
end

--- 对敌人造成伤害前统一应用祭坛减伤
--- @param state table 战斗状态
--- @param enemy table 目标敌人
--- @param damage number 原始伤害
--- @param srcLabel string|nil 伤害来源标签（用于日志，可选）
--- @return number 减伤后的实际伤害
function Battle.ApplyAltarReduction(state, enemy, damage, srcLabel)
    if (enemy.altarDamageReduction or 0) > 0 and damage > 0 then
        local reduction = enemy.altarDamageReduction
        local reducedAmt = math.floor(damage * reduction)
        damage = damage - reducedAmt
        if damage < 1 then damage = 1 end
    end
    return damage
end

--- 摧毁祭坛
function Battle.DestroyAltar(state, altar)
    altar.active = false
    Battle.AddFloatingText(state, altar.col, altar.row, "💥祭坛摧毁!", {255, 200, 50, 255}, "combo", 3.0)
    Battle.AddVFX(state, "altar_burn", { col = altar.col, row = altar.row, duration = 2.0 })
    AM.PlaySFX("altar_destroy")
    Battle.AddLog(state, string.format("🔥 祭坛 (%d,%d) 被摧毁！", altar.col, altar.row))

    -- 重新计算所有护盾
    Battle.UpdateAltarShields(state)

    -- Boss战祭坛全灭破盾机制
    if state.boss and state.boss.bossType == "lava_lord" and state.boss.hp > 0 then
        local remaining = Battle.GetActiveAltarCount(state.board)
        if remaining > 0 then
            Battle.AddFloatingText(state, altar.col, altar.row,
                string.format("剩余祭坛: %d/3", remaining), {255, 180, 60, 255})
        else
            -- 全部祭坛熄灭！破除Boss护盾
            local boss = state.boss
            local oldShield = boss.shieldHp or 0
            boss.shieldHp = 0
            -- 额外造成Boss最大HP 10%的伤害
            local bonusDmg = math.floor((boss.maxHp or 280) * 0.10)
            boss.hp = math.max(1, boss.hp - bonusDmg)
            -- 震撼特效
            Battle.AddBossSkillAnnounce(state, "altar_break_shield", boss.name)
            Battle.AddFloatingText(state, boss.col, boss.row,
                "💥护盾破碎! -" .. (oldShield + bonusDmg), {255, 50, 50, 255}, "combo", 3.0)
            Battle.AddVFX(state, "shield_break", { col = boss.col, row = boss.row, duration = 1.5 })
            Battle.AddVFX(state, "shockwave", { col = boss.col, row = boss.row, duration = 1.0 })
            state.screenShake = (state.screenShake or 0) + 0.8
            AM.PlaySFX("boss_entrance", 1.0)
            Battle.AddLog(state, string.format(
                "🔥🔥🔥 三个祭坛全部熄灭！熔岩领主护盾破碎！额外造成 %d 伤害！", bonusDmg))
        end
    end
end

--- 获取剩余活跃祭坛数
--- 第四章: 流沙区回合推进（每敌方回合结束调用）
--- 每回合 timer-1，归零自动消失，恢复通行
function Battle.ProcessQuicksandTurn(state)
    local board = state.board
    if not board.quicksandZones or #board.quicksandZones == 0 then return end

    local removed = {}
    for i = #board.quicksandZones, 1, -1 do
        local zone = board.quicksandZones[i]
        zone.timer = zone.timer - 1
        if zone.timer <= 0 then
            table.remove(board.quicksandZones, i)
            removed[#removed + 1] = zone
        end
    end
    for _, zone in ipairs(removed) do
        Battle.AddFloatingText(state, zone.col, zone.row,
            "✨流沙消散", {180, 160, 100, 255})
        Battle.AddLog(state, string.format("(%d,%d) 的流沙区消散了", zone.col, zone.row))
    end
end

function Battle.GetActiveAltarCount(board)
    local count = 0
    for _, alt in ipairs(board.altars) do
        if alt.active then count = count + 1 end
    end
    return count
end

--- 生成指定关卡
function Battle.GenerateLevel(state, level)
    level = level or 1
    state.level = level
    local board = state.board

    -- 清空棋盘（保留英雄）
    board.pieces = {}
    board.obstacles = {}
    board.items = {}
    board.poisonTiles = {}
    board.wards = {}
    board.frostTiles = {}
    board.altars = {}
    board.crabs = {}
    board.shells = {}
    board.quicksandZones = {}
    board.fogRevealed = nil
    board.hasFog = false

    state.rescueTarget = 0
    state.rescueCount = 0
    state.sandWormSegments = nil

    -- 始终使用正六边形棋盘
    do
        HexGrid.ResetToHexagon()
        board.cols = HexGrid.COLS
        board.rows = HexGrid.ROWS
    end

    -- 重置击杀计数，设置击杀目标
    state.kills = 0
    do
        local ch, stg = Battle.GetChapterInfo(level)
        if Battle.IsBossLevel(level) then
            state.killTarget = 999  -- Boss关: 击杀Boss即过关
        else
            state.killTarget = 6 + ch + math.floor(stg / 2)
        end
    end

    -- 重置连击临时状态
    state.comboKillCount = 0
    state.comboAtkBonus = 0

    -- 吸血跳Lv4: 每回合消耗HP换ATK（在turn处理中执行，这里标记状态）
    state.bloodPactActive = Skills.Level(state.skills, "vampiric_jump") >= 4

    -- 吸血跳Lv5: 击杀永久+2ATK（累计计数在state中追踪）
    if not state.bloodOverlordATK then state.bloodOverlordATK = 0 end

    -- 英雄位置: 正六边形→底部中央
    local heroCol = HexGrid.CENTER_COL
    local heroRow = HexGrid.CENTER_ROW + HexGrid.RADIUS  -- 正六边形: 底部边缘
    if not state.hero then
        state.hero = Battle.CreatePiece(HERO_TEMPLATE, heroCol, heroRow)
        -- 应用天赋/装备加成到初始属性
        local bs = state.bonusStats or {}
        state.hero.atk = math.floor(state.hero.atk + (bs.atk or 0))
        state.hero.def = math.floor(state.hero.def + (bs.def or 0))
        state.hero.hp = math.floor(state.hero.hp + (bs.hp or 0))
        state.hero.maxHp = math.floor(state.hero.maxHp + (bs.hp or 0))

        -- 玻璃大炮: 初始化时应用HP减少+ATK提升
        local gcLv = Skills.Level(state.skills, "glass_cannon")
        if gcLv >= 1 then
            local hpRedPct = (10 + gcLv * 5) / 100   -- Lv1=15%, ..., Lv5=35%
            local atkBoostPct = (15 + gcLv * 5) / 100 -- Lv1=20%, ..., Lv5=40%
            local hpLoss = math.floor(state.hero.maxHp * hpRedPct)
            state.hero.maxHp = state.hero.maxHp - hpLoss
            state.hero.hp = math.min(state.hero.hp, state.hero.maxHp)
            local atkGain = math.floor(state.hero.atk * atkBoostPct)
            state.hero.atk = state.hero.atk + atkGain
            state.hero._glassCannonApplied = gcLv
        end

        -- v4.0: 初始化套装效果和暴击/金币加成
        if G.playerData then
            state.critRate = PlayerData.GetCritRate(G.playerData)
            state.goldBonus = PlayerData.GetGoldBonus(G.playerData)
            state.setEffects = SetEffects.Init(G.playerData.equipment, state.critRate)
        end
    else
        state.hero.col = heroCol
        state.hero.row = heroRow
    end

    -- 玻璃大炮: 升级后需要追加效果（与上次应用的等级差）
    local gcLv = Skills.Level(state.skills, "glass_cannon")
    local prevGcLv = state.hero._glassCannonApplied or 0
    if gcLv > prevGcLv and prevGcLv > 0 then
        -- 追加新等级增量的效果
        local oldHpPct = (10 + prevGcLv * 5) / 100
        local newHpPct = (10 + gcLv * 5) / 100
        local oldAtkPct = (15 + prevGcLv * 5) / 100
        local newAtkPct = (15 + gcLv * 5) / 100
        -- 用基础maxHp估算增量
        local baseMaxHp = math.floor(state.hero.maxHp / (1 - oldHpPct))
        local extraHpLoss = math.floor(baseMaxHp * (newHpPct - oldHpPct))
        state.hero.maxHp = math.max(1, state.hero.maxHp - extraHpLoss)
        state.hero.hp = math.min(state.hero.hp, state.hero.maxHp)
        local baseAtk = math.floor(state.hero.atk / (1 + oldAtkPct))
        local extraAtkGain = math.floor(baseAtk * (newAtkPct - oldAtkPct))
        state.hero.atk = state.hero.atk + extraAtkGain
        state.hero._glassCannonApplied = gcLv
    elseif gcLv >= 1 and prevGcLv == 0 then
        -- 首次获得（非初始创建时）
        local hpRedPct = (10 + gcLv * 5) / 100
        local atkBoostPct = (15 + gcLv * 5) / 100
        local hpLoss = math.floor(state.hero.maxHp * hpRedPct)
        state.hero.maxHp = math.max(1, state.hero.maxHp - hpLoss)
        state.hero.hp = math.min(state.hero.hp, state.hero.maxHp)
        local atkGain = math.floor(state.hero.atk * atkBoostPct)
        state.hero.atk = state.hero.atk + atkGain
        state.hero._glassCannonApplied = gcLv
        Battle.AddLog(state, string.format("🔥 玻璃大炮Lv%d: ATK+%d%%, MaxHP-%d%%",
            gcLv, 15 + gcLv * 5, 10 + gcLv * 5))
    end

    HexGrid.AddPiece(board, state.hero)

    local chapter, stageInChapter = Battle.GetChapterInfo(level)
    local isBoss = Battle.IsBossLevel(level)

    -- 收集可用位置
    local usedPositions = {}
    usedPositions[heroCol .. "," .. heroRow] = true

    local function claimRandomPos(maxRow)
        maxRow = maxRow or HexGrid.ROWS
        local attempts = 0
        while attempts < 80 do
            local c = math.random(1, HexGrid.COLS)
            local r = math.random(1, maxRow)
            if HexGrid.InBounds(c, r) then
                local key = c .. "," .. r
                if not usedPositions[key] then
                    usedPositions[key] = true
                    return c, r
                end
            end
            attempts = attempts + 1
        end
        return nil, nil
    end

    local function claimPos(c, r)
        usedPositions[c .. "," .. r] = true
    end

    if isBoss then
        -- =============== Boss 关 ===============
        local bossKey = CHAPTER_BOSS[chapter] or "abyss_kraken"
        local bossTemplate = BOSS_TEMPLATES[bossKey]

        -- Boss 放在上方中央（正六边形顶端附近）
        local bossCol = HexGrid.CENTER_COL
        local bossRow = HexGrid.CENTER_ROW - HexGrid.RADIUS + 1  -- 靠近顶端
        claimPos(bossCol, bossRow)

        local boss = Battle.CreatePiece(bossTemplate, bossCol, bossRow)
        -- Boss 按章节缩放（比普通敌人温和）
        local bossHpScale = 1.0 + 0.15 * (chapter - 1)
        local bossAtkScale = 1.0 + 0.1 * (chapter - 1)
        boss.hp = math.floor(boss.hp * bossHpScale)
        boss.maxHp = boss.hp
        boss.atk = math.floor(boss.atk * bossAtkScale)
        boss.shieldMax = math.floor(boss.shieldMax * bossHpScale)
        HexGrid.AddPiece(board, boss)
        state.boss = boss

        -- === 第四章沙虫: 创建6个身体段（head已经是boss本体） ===
        if bossKey == "sand_worm" then
            boss.isHead = true
            boss.segmentIndex = 1
            state.sandWormSegments = { boss }  -- segments[1] = head
            -- 从head往下依次放置身体段
            local prevCol, prevRow = bossCol, bossRow
            for seg = 2, (bossTemplate.segments or 7) do
                -- 寻找相邻空位（优先向下/向两侧展开）
                local neighbors = HexGrid.GetNeighbors(prevCol, prevRow)
                local placed = false
                -- 打乱邻居顺序但优先行号更大的（蛇身往下延伸）
                table.sort(neighbors, function(a, b) return a.row > b.row end)
                for _, nb in ipairs(neighbors) do
                    if HexGrid.InBounds(nb.col, nb.row)
                       and not usedPositions[nb.col .. "," .. nb.row]
                       and not HexGrid.IsBlocked(board, nb.col, nb.row) then
                        local segment = Battle.CreatePiece({
                            team = "enemy", enemyType = "boss",
                            hp = 99999, maxHp = 99999, atk = 0, attackRange = 0,
                            attackLabel = "", name = "沙虫身躯",
                            isBoss = true, bossType = "sand_worm_body",
                            isSegment = true, segmentIndex = seg,
                            snakeHead = boss,  -- 伤害路由到头部
                        }, nb.col, nb.row)
                        HexGrid.AddPiece(board, segment)
                        claimPos(nb.col, nb.row)
                        state.sandWormSegments[seg] = segment
                        prevCol, prevRow = nb.col, nb.row
                        placed = true
                        break
                    end
                end
                if not placed then break end  -- 空间不足则少放
            end
            -- 初始化流沙系统
            board.quicksandZones = {}
        end

        -- Boss关放少量障碍（第2章熔岩领主不放障碍，用祭坛机制替代；第4章沙虫不放障碍）
        if chapter ~= 2 and chapter ~= 4 then
            local obstacleCount = 3
            for i = 1, obstacleCount do
                local c, r = claimRandomPos()
                if c then HexGrid.AddObstacle(board, c, r) end
            end
        end

        -- Boss关初始小怪：分散放置，方便连跳
        local bossChapterEnemies
        if chapter == 1 then
            bossChapterEnemies = { "jellyfish", "iron_turtle", "vortex_eel", "archerfish", "electric_ray" }
        elseif chapter == 2 then
            bossChapterEnemies = { "fire_sprite", "lava_giant" }
        elseif chapter == 3 then
            bossChapterEnemies = { "coral_snapper", "sea_urchin", "reef_starfish", "splitting_urchin" }
        elseif chapter == 4 then
            bossChapterEnemies = { "sand_scorpion", "quicksand_worm", "sand_hawk" }
        else
            bossChapterEnemies = { "jellyfish", "iron_turtle" }
        end

        -- 按距离分散放置：优先离Boss和英雄都有一定距离的位置
        local minionCount = 3 + math.min(chapter, 3)  -- 3/4/5/6 随章节递增（减少视觉负担）
        local bossHpScaleM = 1.0 + 0.12 * (chapter - 1)
        local bossAtkScaleM = 1.0 + 0.08 * (chapter - 1)

        -- 收集所有空位并按离中心距离排序（优先中间环带，避免全挤在边缘或中心）
        local minionCandidates = {}
        for r2 = 1, HexGrid.ROWS do
            for c2 = 1, HexGrid.COLS do
                if HexGrid.InBounds(c2, r2) then
                    local key = c2 .. "," .. r2
                    if not usedPositions[key] then
                        local dist = HexGrid.CubeDistance(c2, r2, HexGrid.CENTER_COL, HexGrid.CENTER_ROW)
                        -- 优先距离2-3的环带（不靠Boss也不靠英雄）
                        local score = math.abs(dist - 2.5)
                        minionCandidates[#minionCandidates + 1] = { col = c2, row = r2, score = score }
                    end
                end
            end
        end
        -- 按分散度排序后加随机扰动（预计算随机值，避免排序函数内调用 math.random）
        for _, mc in ipairs(minionCandidates) do
            mc.sortKey = mc.score + math.random() * 1.5
        end
        table.sort(minionCandidates, function(a, b)
            return a.sortKey < b.sortKey
        end)

        for i = 1, math.min(minionCount, #minionCandidates) do
            local pos = minionCandidates[i]
            claimPos(pos.col, pos.row)
            local etype = bossChapterEnemies[math.random(1, #bossChapterEnemies)]
            local template = ENEMY_TEMPLATES[etype]
            local minion = Battle.CreatePiece(template, pos.col, pos.row)
            minion.hp = math.floor(minion.hp * bossHpScaleM)
            minion.maxHp = minion.hp
            if minion.atk > 0 then
                minion.atk = math.floor(minion.atk * bossAtkScaleM)
            end
            HexGrid.AddPiece(board, minion)
        end

        -- Boss关提供大血瓶和道具
        local potC, potR = claimRandomPos()
        if potC then
            HexGrid.AddItem(board, { col = potC, row = potR, type = "health_potion_big" })
        end
        Battle.TrySpawnItems(state, 2)  -- Boss关多给一些道具

        -- 第2章Boss战：放置3个火焰祭坛（全灭破盾机制）
        if chapter == 2 then
            Battle.PlaceAltars(state, 3)
            Battle.UpdateAltarShields(state)
        end

        -- 第3章Boss战：放置2只寄居蟹（与章节主题呼应）
        if chapter == 3 then
            board.crabs = {}
            board.shells = {}
            state.rescueCount = 0
            state.rescueTarget = 2  -- Boss关固定2只，任务量适中

            local availableRows = {}
            for r = 2, HexGrid.ROWS - 1 do
                if r ~= heroRow then
                    local leftOk, rightOk = false, false
                    for c = 1, 3 do
                        if HexGrid.InBounds(c, r) then leftOk = true; break end
                    end
                    for c = HexGrid.COLS - 2, HexGrid.COLS do
                        if HexGrid.InBounds(c, r) then rightOk = true; break end
                    end
                    if leftOk and rightOk then
                        availableRows[#availableRows + 1] = r
                    end
                end
            end
            -- 打乱行顺序
            for i = #availableRows, 2, -1 do
                local j = math.random(1, i)
                availableRows[i], availableRows[j] = availableRows[j], availableRows[i]
            end

            for ci = 1, math.min(2, #availableRows) do
                local row = availableRows[ci]
                local crabCol, shellCol
                for c = 1, 4 do
                    if HexGrid.InBounds(c, row) and not usedPositions[c..","..row] then
                        crabCol = c; break
                    end
                end
                for c = HexGrid.COLS, HexGrid.COLS - 3, -1 do
                    if HexGrid.InBounds(c, row) and not usedPositions[c..","..row] then
                        shellCol = c; break
                    end
                end
                if crabCol and shellCol and crabCol < shellCol then
                    claimPos(crabCol, row)
                    claimPos(shellCol, row)
                    board.crabs[#board.crabs + 1] = {
                        col = crabCol, row = row,
                        shellCol = shellCol, shellRow = row,
                        rescued = false,
                        animTimer = nil,
                    }
                    board.shells[#board.shells + 1] = {
                        col = shellCol, row = row,
                        occupied = false,
                    }
                    -- 蟹与壳之间放1块障碍（排除紧邻两端格，避免无法清除）
                    local pathCols = {}
                    for c = crabCol + 2, shellCol - 2 do
                        if HexGrid.InBounds(c, row) and not usedPositions[c..","..row] then
                            pathCols[#pathCols + 1] = c
                        end
                    end
                    if #pathCols > 0 then
                        local oc = pathCols[math.random(1, #pathCols)]
                        claimPos(oc, row)
                        HexGrid.AddObstacle(board, oc, row)
                    end
                    Battle.AddLog(state, string.format("🐚 Boss关寄居蟹在(%d,%d)，壳在(%d,%d)", crabCol, row, shellCol, row))
                end
            end
            -- 修正：用实际放置数覆盖目标
            state.rescueTarget = #board.crabs
            Battle.AddLog(state, string.format("🦀 Boss关救援任务：%d只寄居蟹需要回家！", state.rescueTarget))
        end

        Battle.AddLog(state, string.format("=== 第%d章 Boss战！%s 出现了！===", chapter, boss.name))

        -- Boss 入场全屏公告
        local bossIcons = {
            shadow_knight = "🗡️",
            lava_lord = "🌋",
            abyss_kraken = "🐙",
            coral_guardian = "🪸",
            sand_worm = "🐛",
        }
        state.bossAnnouncement = {
            bossName = boss.name,
            icon = bossIcons[bossKey] or "💀",
            chapter = chapter,
            timer = 3.5,
            maxTimer = 3.5,
        }
        state.screenShake = 0.6
    else
        -- =============== 普通关 ===============
        state.boss = nil

        -- 难度缩放：基础线性 + 章内加速因子（后期关卡更难，平滑过渡到Boss）
        local hpScale, atkScale
        -- 章内加速因子：stg 1-3 几乎无加成，stg 7-9 显著加成
        local stgAccel = (stageInChapter - 1) / 8  -- 0~1 范围
        local accelBonus = stgAccel * stgAccel      -- 二次方加速：S1=0, S5=0.25, S7=0.56, S9=1.0
        if chapter >= 2 then
            -- 第二章+: 基础线性 + 章内加速（最多额外+40% HP, +25% ATK）
            hpScale = 1.0 + 0.12 * (level - 1) + 0.40 * accelBonus
            atkScale = 1.0 + 0.09 * (level - 1) + 0.25 * accelBonus
        else
            -- 第一章: 基础线性 + 章内加速（最多额外+50% HP, +35% ATK）
            hpScale = 1.0 + 0.18 * (level - 1) + 0.50 * accelBonus
            atkScale = 1.0 + 0.13 * (level - 1) + 0.35 * accelBonus
        end

        -- 敌人数量: 保持平稳（怪多反而容易连击，不加难度）
        local enemyCount = math.min(7 + math.floor(stageInChapter / 2), 14)

        -- 按章节选择敌人类型池
        local enemyTypes
        if chapter == 1 then
            -- 第一章: 逐步解锁新敌人，第1关只有普通敌人（不触发新敌人教学）
            if stageInChapter <= 1 then
                enemyTypes = { "slime", "slime", "slime" }
            elseif stageInChapter <= 2 then
                enemyTypes = { "jellyfish", "jellyfish", "iron_turtle" }
            elseif stageInChapter <= 3 then
                enemyTypes = { "jellyfish", "iron_turtle", "archerfish" }
            elseif stageInChapter <= 5 then
                enemyTypes = { "jellyfish", "iron_turtle", "vortex_eel", "archerfish" }
            elseif stageInChapter <= 6 then
                enemyTypes = { "jellyfish", "iron_turtle", "vortex_eel", "archerfish", "electric_ray" }
            elseif stageInChapter <= 7 then
                enemyTypes = { "jellyfish", "iron_turtle", "vortex_eel", "hermit_crab", "ghost_shark", "archerfish", "electric_ray" }
            else
                -- S8-S9: 高威胁怪权重更高（幽灵鲨、电鳐出现概率翻倍）
                enemyTypes = { "iron_turtle", "vortex_eel", "hermit_crab", "ghost_shark", "ghost_shark", "archerfish", "electric_ray", "electric_ray" }
            end
        elseif chapter == 2 then
            -- 第二章: 火灵、熔岩巨人为主，后期加入蘑菇和裂焰精
            enemyTypes = { "fire_sprite", "fire_sprite", "lava_giant" }
            if stageInChapter >= 4 then
                enemyTypes = { "fire_sprite", "lava_giant", "lava_giant", "fission_flame" }
            end
            if stageInChapter >= 7 and stageInChapter <= 7 then
                enemyTypes = { "fire_sprite", "lava_giant", "fission_flame", "mushroom" }
            elseif stageInChapter >= 8 then
                -- S8-S9: 裂焰精和熔岩巨人权重更高
                enemyTypes = { "lava_giant", "lava_giant", "fission_flame", "fission_flame", "mushroom" }
            end
        elseif chapter == 3 then
            -- 第三章: 珊瑚系敌人，后期加入特殊机制怪
            enemyTypes = { "coral_snapper", "coral_snapper", "sea_urchin", "reef_starfish" }
            if stageInChapter >= 4 then
                enemyTypes = { "coral_snapper", "sea_urchin", "reef_starfish", "spine_anemone", "splitting_urchin" }
            end
            if stageInChapter >= 7 and stageInChapter <= 7 then
                enemyTypes = { "coral_snapper", "sea_urchin", "reef_starfish", "spine_anemone", "coral_priest", "splitting_urchin" }
            elseif stageInChapter >= 8 then
                -- S8-S9: 牧师和分裂海胆权重更高（更多治疗和分裂压力）
                enemyTypes = { "coral_snapper", "spine_anemone", "spine_anemone", "coral_priest", "coral_priest", "splitting_urchin", "splitting_urchin" }
            end
        elseif chapter == 4 then
            -- 第四章: 沙漠系敌人，流沙虫可填坑
            enemyTypes = { "sand_scorpion", "sand_scorpion", "quicksand_worm", "sand_hawk" }
            if stageInChapter >= 4 then
                enemyTypes = { "sand_scorpion", "quicksand_worm", "quicksand_worm", "sand_hawk", "sand_hawk" }
            end
            if stageInChapter >= 7 then
                enemyTypes = { "sand_scorpion", "sand_scorpion", "quicksand_worm", "sand_hawk", "sand_hawk", "sand_hawk" }
            end
        else
            enemyTypes = { "jellyfish", "iron_turtle" }
        end

        -- 障碍物数量：只有第三章放珊瑚/礁石（配合寄居蟹营救机制）
        local obstacleCount = 0
        if chapter == 3 then
            obstacleCount = math.min(math.floor(stageInChapter / 3), 3)
        end

        -- 1-1 教学关：不预放敌人/障碍，由 TryScriptedSpawn 分阶段刷出（仅首次）
        if level == 1 and G and G.playerData and not G.playerData.tutorialSpawnSeen then
            state.tutorialPhase = 0
            enemyCount = 0
            obstacleCount = 0
        end

        -- 放置障碍物
        for i = 1, obstacleCount do
            local c, r = claimRandomPos()
            if c then HexGrid.AddObstacle(board, c, r) end
        end

        -- 放置敌人
        for i = 1, enemyCount do
            local c, r = claimRandomPos()
            if c then
                local etype = enemyTypes[math.random(1, #enemyTypes)]
                local template = ENEMY_TEMPLATES[etype]
                local piece = Battle.CreatePiece(template, c, r)
                piece.hp = math.floor(piece.hp * hpScale)
                piece.maxHp = piece.hp
                if piece.atk > 0 then
                    piece.atk = math.floor(piece.atk * atkScale)
                end
                HexGrid.AddPiece(board, piece)
            end
        end



        -- 第三章: 寄居蟹救援系统（每3关触发一次）
        if chapter == 3 and stageInChapter % 3 ~= 1 then
            -- 非救蟹关（第2、3、5、6、8、9关），清空状态
            board.crabs = {}
            board.shells = {}
            state.rescueTarget = 0
            state.rescueCount = 0
        elseif chapter == 3 then
            board.crabs = {}
            board.shells = {}
            state.rescueCount = 0
            -- 救援目标: 固定2只寄居蟹
            local crabCount = 2
            state.rescueTarget = crabCount

            -- 选择可用的行（避开英雄所在行和边缘行）
            local availableRows = {}
            for r = 2, HexGrid.ROWS - 1 do
                if r ~= heroRow then
                    -- 检查这一行左侧和右侧都有有效格子
                    local leftOk, rightOk = false, false
                    for c = 1, 3 do
                        if HexGrid.InBounds(c, r) then leftOk = true; break end
                    end
                    for c = HexGrid.COLS - 2, HexGrid.COLS do
                        if HexGrid.InBounds(c, r) then rightOk = true; break end
                    end
                    if leftOk and rightOk then
                        availableRows[#availableRows + 1] = r
                    end
                end
            end
            -- 打乱行顺序
            for i = #availableRows, 2, -1 do
                local j = math.random(1, i)
                availableRows[i], availableRows[j] = availableRows[j], availableRows[i]
            end
            -- 确保两只蟹不在相邻行（行距 >= 2），从打乱后的候选行中挑选
            local selectedRows = {}
            for _, r in ipairs(availableRows) do
                local tooClose = false
                for _, sr in ipairs(selectedRows) do
                    if math.abs(sr - r) < 2 then tooClose = true; break end
                end
                if not tooClose then
                    selectedRows[#selectedRows + 1] = r
                    if #selectedRows >= crabCount then break end
                end
            end
            availableRows = selectedRows

            for ci = 1, crabCount do
                if ci > #availableRows then break end
                local row = availableRows[ci]
                -- 寄居蟹放左侧，壳放右侧
                local crabCol, shellCol
                -- 找左侧最靠边的有效格
                for c = 1, 4 do
                    if HexGrid.InBounds(c, row) and not usedPositions[c..","..row] then
                        crabCol = c; break
                    end
                end
                -- 找右侧最靠边的有效格
                for c = HexGrid.COLS, HexGrid.COLS - 3, -1 do
                    if HexGrid.InBounds(c, row) and not usedPositions[c..","..row] then
                        shellCol = c; break
                    end
                end
                if crabCol and shellCol and crabCol < shellCol then
                    claimPos(crabCol, row)
                    claimPos(shellCol, row)
                    board.crabs[#board.crabs + 1] = {
                        col = crabCol, row = row,
                        shellCol = shellCol, shellRow = row,
                        rescued = false,
                        animTimer = nil,  -- 奔跑动画计时
                    }
                    board.shells[#board.shells + 1] = {
                        col = shellCol, row = row,
                        occupied = false,
                    }
                    -- 在蟹和壳之间放置障碍物
                    -- 规则：排除紧邻螃蟹(crabCol+1)和紧邻贝壳(shellCol-1)的格子
                    -- 这两个位置两侧都被堵死，无法被跳过清除
                    -- 最多放2个，且相互不相邻（否则互相挡住起跳位）
                    local pathLen = shellCol - crabCol - 1
                    local obstCount = math.min(2, math.floor(pathLen / 3))
                    local pathCols = {}
                    for c = crabCol + 2, shellCol - 2 do  -- 排除两端各1格
                        if HexGrid.InBounds(c, row) and not usedPositions[c..","..row] then
                            pathCols[#pathCols + 1] = c
                        end
                    end
                    -- 打乱候选位置
                    for i = #pathCols, 2, -1 do
                        local j = math.random(1, i)
                        pathCols[i], pathCols[j] = pathCols[j], pathCols[i]
                    end
                    -- 放置障碍：确保已放置的障碍彼此不相邻（列距≥2）
                    local placedCols = {}
                    for _, oc in ipairs(pathCols) do
                        if #placedCols >= obstCount then break end
                        local tooClose = false
                        for _, pc in ipairs(placedCols) do
                            if math.abs(pc - oc) <= 1 then
                                tooClose = true; break
                            end
                        end
                        if not tooClose then
                            placedCols[#placedCols + 1] = oc
                            claimPos(oc, row)
                            HexGrid.AddObstacle(board, oc, row)
                        end
                    end
                    Battle.AddLog(state, string.format("🐚 寄居蟹在 (%d,%d)，壳在 (%d,%d)", crabCol, row, shellCol, row))
                end
            end
            -- 修正：用实际放置的螃蟹数覆盖目标，防止放置失败导致无法通关
            state.rescueTarget = #board.crabs
            Battle.AddLog(state, string.format("🦀 救援目标: %d只寄居蟹需要回家！", state.rescueTarget))
        end

        -- 第二章: 放置炎魔祭坛 & 计算护盾（第1、4、7关触发）
        if chapter == 2 and stageInChapter % 3 == 1 then
            local altarCount = Battle.GetAltarCount(stageInChapter)
            Battle.PlaceAltars(state, altarCount)
            Battle.UpdateAltarShields(state)
        elseif chapter == 2 then
            board.altars = {}  -- 无祭坛关卡，确保数据干净
        end

        -- 随机生成道具
        Battle.TrySpawnItems(state, 1)

        Battle.AddLog(state, string.format("=== 第%d章 第%d关开始！===", chapter, stageInChapter))
    end
end

-- ============================================================================
-- 无尽模式：波次生成
-- ============================================================================

--- 无尽模式所有波次使用的完整敌人池（混合三章所有怪）
Battle.ENDLESS_ENEMY_POOLS = {
    -- Wave 1-4: 简单怪，第一章为主
    [1] = { "slime", "jellyfish", "iron_turtle", "swift_barracuda" },
    -- Wave 5-9: 加入第一章后期 + 第二章前期 + 魅惑水母
    [2] = { "jellyfish", "iron_turtle", "archerfish", "vortex_eel", "fire_sprite",
            "swift_barracuda", "charm_jelly" },
    -- Wave 10-14: 加入第二章主力怪
    [3] = { "iron_turtle", "archerfish", "vortex_eel", "fire_sprite", "lava_giant",
            "electric_ray", "swift_barracuda", "charm_jelly" },
    -- Wave 15-19: 加入第三章
    [4] = { "vortex_eel", "fire_sprite", "lava_giant", "fission_flame",
            "coral_snapper", "sea_urchin", "ghost_shark", "splitting_urchin",
            "swift_barracuda", "charm_jelly" },
    -- Wave 20+: 全部最强怪
    [5] = { "lava_giant", "fission_flame", "ghost_shark", "electric_ray",
            "coral_priest", "spine_anemone", "reef_starfish", "vortex_eel",
            "swift_barracuda", "charm_jelly" },
}

--- 根据波次号获取敌人池
local function GetEndlessEnemyPool(wave)
    if wave >= 18 then return Battle.ENDLESS_ENEMY_POOLS[5] end
    if wave >= 12 then return Battle.ENDLESS_ENEMY_POOLS[4] end
    if wave >= 8  then return Battle.ENDLESS_ENEMY_POOLS[3] end
    if wave >= 4  then return Battle.ENDLESS_ENEMY_POOLS[2] end
    return Battle.ENDLESS_ENEMY_POOLS[1]
end

--- 生成无尽模式波次（完整重建棋盘，保留英雄血量/技能/装备）
--- @param state table Battle.New 返回的战斗状态
--- @param wave number 波次号（从1开始）
function Battle.GenerateEndlessWave(state, wave)
    wave = wave or 1
    state.endlessWave = wave
    state.isEndless = true
    local board = state.board

    -- 清空棋盘（保留英雄）
    board.pieces = {}
    board.obstacles = {}
    board.items = {}
    board.poisonTiles = {}
    board.wards = {}
    board.frostTiles = {}
    board.altars = {}
    board.crabs = {}
    board.shells = {}

    -- 始终使用正六边形棋盘
    HexGrid.ResetToHexagon()
    board.cols = HexGrid.COLS
    board.rows = HexGrid.ROWS

    -- 重置击杀计数和目标（随波次快速增加）
    state.kills = 0
    state.killTarget = 9 + math.floor((wave - 1) / 2)
    state.rescueTarget = 0
    state.rescueCount = 0

    -- 重置连击临时状态
    state.comboKillCount = 0
    state.comboAtkBonus = 0

    -- 英雄位置
    local heroCol = HexGrid.CENTER_COL
    local heroRow = HexGrid.CENTER_ROW + HexGrid.RADIUS
    if not state.hero then
        -- 首波：创建英雄，应用装备加成
        state.hero = Battle.CreatePiece(HERO_TEMPLATE, heroCol, heroRow)
        local bs = state.bonusStats or {}
        state.hero.atk = math.floor(state.hero.atk + (bs.atk or 0))
        state.hero.def = math.floor(state.hero.def + (bs.def or 0))
        state.hero.hp  = math.floor(state.hero.hp  + (bs.hp or 0))
        state.hero.maxHp = math.floor(state.hero.maxHp + (bs.hp or 0))
        if G.playerData then
            state.critRate = PlayerData.GetCritRate(G.playerData)
            state.goldBonus = PlayerData.GetGoldBonus(G.playerData)
            state.setEffects = SetEffects.Init(G.playerData.equipment, state.critRate)
        end
    else
        -- 后续波：仅重置位置，保留英雄当前血量/ATK/DEF
        state.hero.col = heroCol
        state.hero.row = heroRow
    end

    -- 英雄加入棋盘（每波都必须重新 AddPiece，因为 board.pieces 已清空）
    HexGrid.AddPiece(board, state.hero)

    -- 难度缩放：大幅提升，陡峭指数曲线
    -- Wave1:  HP×1.0   ATK×1.0
    -- Wave5:  HP×4.9   ATK×4.2
    -- Wave10: HP×11.8  ATK×10.5
    -- Wave20: HP×37.5  ATK×34.2
    local w = wave - 1
    local hpScale  = 1.0 + 0.65 * w + 0.040 * w * w
    local atkScale = 1.0 + 0.55 * w + 0.035 * w * w

    -- 每3波出现精英怪（原5波）
    local eliteExtra = math.floor((wave - 1) / 3)  -- 0,1,2...额外精英

    -- 敌人数量: 9 + floor(wave/3)，最多18
    local enemyCount = math.min(9 + math.floor((wave - 1) / 3), 18)

    -- 无尽模式不放岩石（岩石会让飞跃先锋过于强势）
    local obstacleCount = 0

    -- 获取可用位置（排除英雄格）
    local claimed = {}
    local function claimRandomPos()
        local attempts = 0
        while attempts < 50 do
            attempts = attempts + 1
            local c = math.random(1, HexGrid.COLS)
            local r = math.random(1, HexGrid.ROWS)
            if HexGrid.InBounds(c, r) then
                local key = c .. "," .. r
                local isHero = (c == heroCol and r == heroRow)
                local tooClose = (math.abs(c - heroCol) + math.abs(r - heroRow) <= 2)
                if not claimed[key] and not isHero and not tooClose then
                    claimed[key] = true
                    return c, r
                end
            end
        end
        return nil, nil
    end

    -- 放障碍
    for _ = 1, obstacleCount do
        local c, r = claimRandomPos()
        if c then HexGrid.AddObstacle(board, c, r) end
    end

    -- 获取当前波次敌人池
    local enemyPool = GetEndlessEnemyPool(wave)

    -- 放普通敌人
    for i = 1, enemyCount do
        local c, r = claimRandomPos()
        if c then
            local etype = enemyPool[math.random(1, #enemyPool)]
            local template = ENEMY_TEMPLATES[etype]
            local piece = Battle.CreatePiece(template, c, r)
            piece.hp    = math.max(1, math.floor(piece.hp    * hpScale))
            piece.maxHp = piece.hp
            if piece.atk > 0 then
                piece.atk = math.max(1, math.floor(piece.atk * atkScale))
            end
            HexGrid.AddPiece(board, piece)
        end
    end

    -- 精英怪：每5波新增1只高HP强怪（从高阶池里选）
    local elitePool = { "ghost_shark", "lava_giant", "coral_priest", "vortex_eel", "iron_turtle" }
    for _ = 1, eliteExtra do
        local c, r = claimRandomPos()
        if c then
            local etype = elitePool[math.random(1, #elitePool)]
            local template = ENEMY_TEMPLATES[etype]
            local piece = Battle.CreatePiece(template, c, r)
            piece.hp    = math.max(1, math.floor(piece.hp    * hpScale * 2.5))  -- 精英额外×2.5 HP
            piece.maxHp = piece.hp
            if piece.atk > 0 then
                piece.atk = math.max(1, math.floor(piece.atk * atkScale * 2.2))
            end
            piece.name = "⭐" .. piece.name  -- 精英标记
            piece.isElite = true
            HexGrid.AddPiece(board, piece)
        end
    end

    -- 道具掉落（低概率）
    if wave >= 3 then
        Battle.TrySpawnItems(state, 1)
    end

    Battle.AddLog(state, string.format("🌀 无尽模式 第%d波！击杀目标: %d", wave, state.killTarget))
end

--- 无缝过渡到下一关：保留英雄和存活敌人位置，只重置击杀计数、补充新敌人
function Battle.ContinueLevel(state, nextLevel)
    state.level = nextLevel
    local board = state.board

    -- 重置击杀计数，设置新击杀目标
    state.kills = 0
    do
        local ch, stg = Battle.GetChapterInfo(nextLevel)
        if Battle.IsBossLevel(nextLevel) then
            state.killTarget = 999
        else
            state.killTarget = 6 + ch + math.floor(stg / 2)
        end
    end

    -- 重置连击临时状态
    state.comboKillCount = 0
    state.comboAtkBonus = 0

    state.bloodPactActive = Skills.Level(state.skills, "vampiric_jump") >= 4
    if not state.bloodOverlordATK then state.bloodOverlordATK = 0 end

    -- 玻璃大炮: 升级后追加效果
    local gcLv = Skills.Level(state.skills, "glass_cannon")
    local prevGcLv = state.hero._glassCannonApplied or 0
    if gcLv > prevGcLv and prevGcLv > 0 then
        local oldHpPct = (10 + prevGcLv * 5) / 100
        local newHpPct = (10 + gcLv * 5) / 100
        local oldAtkPct = (15 + prevGcLv * 5) / 100
        local newAtkPct = (15 + gcLv * 5) / 100
        local baseMaxHp = math.floor(state.hero.maxHp / (1 - oldHpPct))
        local extraHpLoss = math.floor(baseMaxHp * (newHpPct - oldHpPct))
        state.hero.maxHp = math.max(1, state.hero.maxHp - extraHpLoss)
        state.hero.hp = math.min(state.hero.hp, state.hero.maxHp)
        local baseAtk = math.floor(state.hero.atk / (1 + oldAtkPct))
        local extraAtkGain = math.floor(baseAtk * (newAtkPct - oldAtkPct))
        state.hero.atk = state.hero.atk + extraAtkGain
        state.hero._glassCannonApplied = gcLv
    elseif gcLv >= 1 and prevGcLv == 0 then
        local hpRedPct = (10 + gcLv * 5) / 100
        local atkBoostPct = (15 + gcLv * 5) / 100
        local hpLoss = math.floor(state.hero.maxHp * hpRedPct)
        state.hero.maxHp = math.max(1, state.hero.maxHp - hpLoss)
        state.hero.hp = math.min(state.hero.hp, state.hero.maxHp)
        local atkGain = math.floor(state.hero.atk * atkBoostPct)
        state.hero.atk = state.hero.atk + atkGain
        state.hero._glassCannonApplied = gcLv
        Battle.AddLog(state, string.format("🔥 玻璃大炮Lv%d: ATK+%d%%, MaxHP-%d%%",
            gcLv, 15 + gcLv * 5, 10 + gcLv * 5))
    end

    -- 清除过期的稻草人、结界等临时状态
    state.scarecrow = nil
    board.wards = {}
    board.frostTiles = {}
    board.poisonTiles = {}
    state.timeFreezeActive = false
    state.timeFreezeCount = nil

    -- 清除已死亡的敌人碎片（确保棋盘干净，保留英雄）
    local cleanPieces = {}
    for _, p in ipairs(board.pieces) do
        if p.hp > 0 or p.team == "hero" then
            cleanPieces[#cleanPieces + 1] = p
        end
    end
    board.pieces = cleanPieces

    local chapter, stageInChapter = Battle.GetChapterInfo(nextLevel)

    -- 计算当前存活敌人数
    local aliveEnemies = HexGrid.GetTeamPieces(board, "enemy")
    local aliveCount = #aliveEnemies

    -- 难度缩放：基础线性 + 章内加速因子（与 GenerateLevel 一致）
    local hpScale, atkScale
    local stgAccel = (stageInChapter - 1) / 8
    local accelBonus = stgAccel * stgAccel
    if chapter >= 2 then
        hpScale = 1.0 + 0.12 * (nextLevel - 1) + 0.40 * accelBonus
        atkScale = 1.0 + 0.09 * (nextLevel - 1) + 0.25 * accelBonus
    else
        hpScale = 1.0 + 0.18 * (nextLevel - 1) + 0.50 * accelBonus
        atkScale = 1.0 + 0.13 * (nextLevel - 1) + 0.35 * accelBonus
    end

    -- 目标敌人总数（和 GenerateLevel 一致）
    local targetCount = math.min(6 + math.floor(stageInChapter / 2), 12)
    local toSpawn = math.max(0, targetCount - aliveCount)

    -- 收集已占用位置
    local usedPositions = {}
    for _, p in ipairs(board.pieces) do
        usedPositions[p.col .. "," .. p.row] = true
    end
    for _, obs in ipairs(board.obstacles) do
        usedPositions[obs.col .. "," .. obs.row] = true
    end
    for _, it in ipairs(board.items) do
        usedPositions[it.col .. "," .. it.row] = true
    end

    -- 按章节选敌人类型（与GenerateLevel保持一致）
    local enemyTypes
    if chapter == 1 then
        if stageInChapter <= 1 then
            enemyTypes = { "slime", "slime", "slime" }
        elseif stageInChapter <= 2 then
            enemyTypes = { "jellyfish", "jellyfish", "iron_turtle" }
        elseif stageInChapter <= 3 then
            enemyTypes = { "jellyfish", "iron_turtle", "archerfish" }
        elseif stageInChapter <= 5 then
            enemyTypes = { "jellyfish", "iron_turtle", "vortex_eel", "archerfish" }
        elseif stageInChapter <= 6 then
            enemyTypes = { "jellyfish", "iron_turtle", "vortex_eel", "archerfish", "electric_ray" }
        elseif stageInChapter <= 7 then
            enemyTypes = { "jellyfish", "iron_turtle", "vortex_eel", "hermit_crab", "ghost_shark", "archerfish", "electric_ray" }
        else
            enemyTypes = { "iron_turtle", "vortex_eel", "hermit_crab", "ghost_shark", "ghost_shark", "archerfish", "electric_ray", "electric_ray" }
        end
    elseif chapter == 2 then
        enemyTypes = { "fire_sprite", "fire_sprite", "lava_giant" }
        if stageInChapter >= 4 then
            enemyTypes = { "fire_sprite", "lava_giant", "lava_giant", "fission_flame" }
        end
        if stageInChapter >= 7 and stageInChapter <= 7 then
            enemyTypes = { "fire_sprite", "lava_giant", "fission_flame", "mushroom" }
        elseif stageInChapter >= 8 then
            enemyTypes = { "lava_giant", "lava_giant", "fission_flame", "fission_flame", "mushroom" }
        end
    elseif chapter == 3 then
        enemyTypes = { "coral_snapper", "coral_snapper", "sea_urchin", "reef_starfish" }
        if stageInChapter >= 4 then
            enemyTypes = { "coral_snapper", "sea_urchin", "reef_starfish", "spine_anemone", "splitting_urchin" }
        end
        if stageInChapter >= 7 and stageInChapter <= 7 then
            enemyTypes = { "coral_snapper", "sea_urchin", "reef_starfish", "spine_anemone", "coral_priest", "splitting_urchin" }
        elseif stageInChapter >= 8 then
            enemyTypes = { "coral_snapper", "spine_anemone", "spine_anemone", "coral_priest", "coral_priest", "splitting_urchin", "splitting_urchin" }
        end
    else
        enemyTypes = { "jellyfish", "iron_turtle" }
    end

    -- 在空位刷新新敌人
    -- 辅助：在随机空位生成一个指定类型的敌人，返回是否成功
    local function spawnOneEnemy(etype)
        local template = ENEMY_TEMPLATES[etype]
        if not template then return false end
        for attempts = 1, 80 do
            local tc = math.random(1, HexGrid.COLS)
            local tr = math.random(1, HexGrid.ROWS)
            if HexGrid.InBounds(tc, tr) then
                local key = tc .. "," .. tr
                if not usedPositions[key] then
                    usedPositions[key] = true
                    local piece = Battle.CreatePiece(template, tc, tr)
                    piece.hp = math.floor(piece.hp * hpScale)
                    piece.maxHp = piece.hp
                    if piece.atk > 0 then
                        piece.atk = math.floor(piece.atk * atkScale)
                    end
                    HexGrid.AddPiece(board, piece)
                    Battle.AddVFX(state, "spawn_puff", { col = tc, row = tr, duration = 0.6 })
                    return true
                end
            end
        end
        return false
    end

    -- 优先保证有介绍的新敌人类型各出现至少一次，避免弹窗因随机未选中而延迟
    local seenTypes = (G and G.playerData and G.playerData.seenEnemyTypes) or {}
    local guaranteedDone = {}
    for _, et in ipairs(enemyTypes) do
        if toSpawn > 0 and ENEMY_INTRO[et] and not seenTypes[et] and not guaranteedDone[et] then
            guaranteedDone[et] = true
            if spawnOneEnemy(et) then
                toSpawn = toSpawn - 1
            end
        end
    end

    -- 随机补充剩余名额
    for i = 1, toSpawn do
        local etype = enemyTypes[math.random(1, #enemyTypes)]
        spawnOneEnemy(etype)
    end

    -- 第二章: 放置炎魔祭坛 & 计算护盾（第1、4、7关触发）
    if chapter == 2 and stageInChapter % 3 == 1 then
        board.altars = {}  -- 清除旧祭坛
        local altarCount = Battle.GetAltarCount(stageInChapter)
        Battle.PlaceAltars(state, altarCount)
        Battle.UpdateAltarShields(state)
    elseif chapter == 2 then
        board.altars = {}  -- 无祭坛关卡，清除旧数据
    end

    -- 第三章: 寄居蟹救援系统（第1、4、7关触发，ContinueLevel处理4、7关）
    if chapter == 3 and stageInChapter % 3 == 1 then
        board.crabs = {}
        board.shells = {}
        state.rescueCount = 0
        local crabCount = 2  -- 固定2只寄居蟹
        state.rescueTarget = crabCount

        local availableRows = {}
        for r = 2, HexGrid.ROWS - 1 do
            if r ~= state.hero.row then
                local leftOk, rightOk = false, false
                for c = 1, 3 do
                    if HexGrid.InBounds(c, r) then leftOk = true; break end
                end
                for c = HexGrid.COLS - 2, HexGrid.COLS do
                    if HexGrid.InBounds(c, r) then rightOk = true; break end
                end
                if leftOk and rightOk then
                    availableRows[#availableRows + 1] = r
                end
            end
        end
        for i = #availableRows, 2, -1 do
            local j = math.random(1, i)
            availableRows[i], availableRows[j] = availableRows[j], availableRows[i]
        end
        -- 确保两只蟹不在相邻行（行距 >= 2）
        local selectedRows = {}
        for _, r in ipairs(availableRows) do
            local tooClose = false
            for _, sr in ipairs(selectedRows) do
                if math.abs(sr - r) < 2 then tooClose = true; break end
            end
            if not tooClose then
                selectedRows[#selectedRows + 1] = r
                if #selectedRows >= crabCount then break end
            end
        end
        availableRows = selectedRows

        for ci = 1, crabCount do
            if ci > #availableRows then break end
            local row = availableRows[ci]
            local crabCol, shellCol
            for c = 1, 4 do
                if HexGrid.InBounds(c, row) and not usedPositions[c..","..row] then
                    crabCol = c; break
                end
            end
            for c = HexGrid.COLS, HexGrid.COLS - 3, -1 do
                if HexGrid.InBounds(c, row) and not usedPositions[c..","..row] then
                    shellCol = c; break
                end
            end
            if crabCol and shellCol and crabCol < shellCol then
                usedPositions[crabCol..","..row] = true
                usedPositions[shellCol..","..row] = true
                board.crabs[#board.crabs + 1] = {
                    col = crabCol, row = row,
                    shellCol = shellCol, shellRow = row,
                    rescued = false, animTimer = nil,
                }
                board.shells[#board.shells + 1] = {
                    col = shellCol, row = row, occupied = false,
                }
                -- 障碍放置：排除紧邻两端格（不可清除），最多2个，互不相邻
                local pathLen = shellCol - crabCol - 1
                local obstCount = math.min(2, math.floor(pathLen / 3))
                local pathCols = {}
                for c = crabCol + 2, shellCol - 2 do
                    if HexGrid.InBounds(c, row) and not usedPositions[c..","..row] then
                        pathCols[#pathCols + 1] = c
                    end
                end
                for i = #pathCols, 2, -1 do
                    local j = math.random(1, i)
                    pathCols[i], pathCols[j] = pathCols[j], pathCols[i]
                end
                local placedCols = {}
                for _, oc in ipairs(pathCols) do
                    if #placedCols >= obstCount then break end
                    local tooClose = false
                    for _, pc in ipairs(placedCols) do
                        if math.abs(pc - oc) <= 1 then tooClose = true; break end
                    end
                    if not tooClose then
                        placedCols[#placedCols + 1] = oc
                        usedPositions[oc..","..row] = true
                        HexGrid.AddObstacle(board, oc, row)
                    end
                end
                Battle.AddLog(state, string.format("🐚 寄居蟹在(%d,%d)，壳在(%d,%d)", crabCol, row, shellCol, row))
            end
        end
        -- 修正：用实际放置的螃蟹数覆盖目标，防止放置失败导致无法通关
        state.rescueTarget = #board.crabs
        Battle.AddLog(state, string.format("🦀 救援目标: %d只寄居蟹需要回家！", state.rescueTarget))
    elseif chapter == 3 then
        board.crabs = {}
        board.shells = {}
        state.rescueTarget = 0
        state.rescueCount = 0
    end

    -- 补充道具
    Battle.TrySpawnItems(state, 1)

    Battle.AddFloatingText(state, state.hero.col, state.hero.row,
        "🔄 新目标!", {100, 255, 200, 255}, "combo")
    Battle.AddLog(state, string.format("=== 第%d章 第%d关 无缝过渡！击杀目标: %d ===",
        chapter, stageInChapter, state.killTarget))
end

--- 随机刷新道具 (最多 maxCount 个)
function Battle.TrySpawnItems(state, maxCount)
    local board = state.board
    local currentItemCount = #board.items
    local toSpawn = maxCount - currentItemCount
    if toSpawn <= 0 then return end

    local empty = HexGrid.GetEmptyPositions(board)
    -- 排除英雄位置
    local candidates = {}
    for _, pos in ipairs(empty) do
        if not (pos.col == state.hero.col and pos.row == state.hero.row) then
            candidates[#candidates + 1] = pos
        end
    end

    -- Fisher-Yates 洗牌，确保道具随机分布
    for i = #candidates, 2, -1 do
        local j = math.random(1, i)
        candidates[i], candidates[j] = candidates[j], candidates[i]
    end

    -- 从打乱后的候选中加权随机选取道具
    -- 小血瓶概率高(30%)，大血瓶概率低(5%)，金币袋(35%)，护盾(30%)
    local weightedTypes = {
        { type = "health_potion",     weight = 30 },
        { type = "health_potion_big", weight = 5  },
        { type = "gold_bag",          weight = 35 },
        { type = "shield",            weight = 30 },
    }
    local totalWeight = 0
    for _, wt in ipairs(weightedTypes) do totalWeight = totalWeight + wt.weight end

    local spawned = 0
    for _, pos in ipairs(candidates) do
        if spawned >= toSpawn then break end
        local roll = math.random(1, totalWeight)
        local cumulative = 0
        local itemType = weightedTypes[1].type
        for _, wt in ipairs(weightedTypes) do
            cumulative = cumulative + wt.weight
            if roll <= cumulative then
                itemType = wt.type
                break
            end
        end
        HexGrid.AddItem(board, {
            col = pos.col, row = pos.row,
            type = itemType,
        })
        spawned = spawned + 1
    end
end

--- 获取外围空位（CubeDistance == RADIUS 的可用格子）
function Battle.GetOuterRingEmpty(board)
    local result = {}
    for r = 1, board.rows do
        for c = 1, board.cols do
            if HexGrid.InBounds(c, r)
                and HexGrid.CubeDistance(c, r, HexGrid.CENTER_COL, HexGrid.CENTER_ROW) == HexGrid.RADIUS
                and not HexGrid.IsBlocked(board, c, r)
                and not HexGrid.GetItemAt(board, c, r) then
                result[#result + 1] = { col = c, row = r }
            end
        end
    end
    return result
end

--- 1-1 教学关分阶段刷怪
--- Phase 0 → 1: 放置1个相邻敌人（普通跳教学）
--- Phase 1 → 2: 放置1个距离2的敌人（多格跳教学）
--- Phase 2 → 3: 批量刷出剩余敌人，恢复正常刷新
function Battle.TryScriptedSpawn(state)
    local board = state.board
    local hero = state.hero
    if not hero then return end

    local phase = state.tutorialPhase
    local hx, hy, hz = HexGrid.OffsetToCube(hero.col, hero.row)

    -- 6个hex方向（cube坐标）
    local DIRS = {
        { 1, -1,  0}, { 1,  0, -1}, { 0,  1, -1},
        {-1,  1,  0}, {-1,  0,  1}, { 0, -1,  1},
    }
    -- 随机打乱方向，增加变化
    for i = #DIRS, 2, -1 do
        local j = math.random(1, i)
        DIRS[i], DIRS[j] = DIRS[j], DIRS[i]
    end

    if phase == 0 then
        -- 放置1个相邻敌人（距离1），确保跳跃落点有效
        for _, d in ipairs(DIRS) do
            local ex, ey, ez = hx + d[1], hy + d[2], hz + d[3]
            local ec, er = HexGrid.CubeToOffset(ex, ey, ez)
            if HexGrid.InBounds(ec, er) and not HexGrid.IsBlocked(board, ec, er) then
                -- 检查落点（跳过敌人后的对称位置）
                local lx, ly, lz = 2 * ex - hx, 2 * ey - hy, 2 * ez - hz
                local lc, lr = HexGrid.CubeToOffset(lx, ly, lz)
                if HexGrid.InBounds(lc, lr) and not HexGrid.IsBlocked(board, lc, lr) then
                    local template = ENEMY_TEMPLATES["slime"]
                    local piece = Battle.CreatePiece(template, ec, er)
                    HexGrid.AddPiece(board, piece)
                    Battle.AddVFX(state, "spawn_puff", { col = ec, row = er, duration = 0.6 })
                    state.tutorialPhase = 1
                    Battle.AddLog(state, "⚠️ 1个敌人出现了！")
                    return
                end
            end
        end
        -- 找不到有效位置（极少见），跳到正常刷新
        state.tutorialPhase = 4

    elseif phase == 1 then
        -- 放置1个距离2的敌人，确保路径畅通且落点有效（多格跳教学）
        for _, d in ipairs(DIRS) do
            -- 中间格（距离1）必须为空且在界内
            local mx, my, mz = hx + d[1], hy + d[2], hz + d[3]
            local mc, mr = HexGrid.CubeToOffset(mx, my, mz)
            if HexGrid.InBounds(mc, mr) and not HexGrid.IsBlocked(board, mc, mr) then
                -- 敌人位置（距离2）
                local ex, ey, ez = hx + d[1] * 2, hy + d[2] * 2, hz + d[3] * 2
                local ec, er = HexGrid.CubeToOffset(ex, ey, ez)
                if HexGrid.InBounds(ec, er) and not HexGrid.IsBlocked(board, ec, er) then
                    -- 落点（2×敌人位置 - 英雄位置）
                    local lx, ly, lz = 2 * ex - hx, 2 * ey - hy, 2 * ez - hz
                    local lc, lr = HexGrid.CubeToOffset(lx, ly, lz)
                    if HexGrid.InBounds(lc, lr) and not HexGrid.IsBlocked(board, lc, lr) then
                        local template = ENEMY_TEMPLATES["slime"]
                        local piece = Battle.CreatePiece(template, ec, er)
                        HexGrid.AddPiece(board, piece)
                        Battle.AddVFX(state, "spawn_puff", { col = ec, row = er, duration = 0.6 })
                        state.tutorialPhase = 2
                        Battle.AddLog(state, "⚠️ 1个敌人出现了！")
                        return
                    end
                end
            end
        end
        -- 找不到有效位置，跳到正常刷新
        state.tutorialPhase = 4

    elseif phase == 2 then
        -- 二连跳教学：放置2个敌人，排成链式可连跳路径
        -- 在英雄周围找一个方向，放第1个敌人在距离1处，
        -- 第2个敌人放在跳过第1个后的落点的相邻位置（另一个方向），
        -- 确保跳过第2个后的落点也有效
        for _, d1 in ipairs(DIRS) do
            -- 第1个敌人位置（距离1）
            local e1x, e1y, e1z = hx + d1[1], hy + d1[2], hz + d1[3]
            local e1c, e1r = HexGrid.CubeToOffset(e1x, e1y, e1z)
            if HexGrid.InBounds(e1c, e1r) and not HexGrid.IsBlocked(board, e1c, e1r) then
                -- 跳过第1个敌人后的落点
                local l1x, l1y, l1z = 2 * e1x - hx, 2 * e1y - hy, 2 * e1z - hz
                local l1c, l1r = HexGrid.CubeToOffset(l1x, l1y, l1z)
                if HexGrid.InBounds(l1c, l1r) and not HexGrid.IsBlocked(board, l1c, l1r) then
                    -- 从落点出发，找另一个方向放第2个敌人
                    local DIRS2 = {
                        { 1, -1,  0}, { 1,  0, -1}, { 0,  1, -1},
                        {-1,  1,  0}, {-1,  0,  1}, { 0, -1,  1},
                    }
                    for i = #DIRS2, 2, -1 do
                        local j = math.random(1, i)
                        DIRS2[i], DIRS2[j] = DIRS2[j], DIRS2[i]
                    end
                    for _, d2 in ipairs(DIRS2) do
                        local e2x, e2y, e2z = l1x + d2[1], l1y + d2[2], l1z + d2[3]
                        local e2c, e2r = HexGrid.CubeToOffset(e2x, e2y, e2z)
                        -- 第2个敌人不能和第1个重叠，不能在英雄位置
                        if HexGrid.InBounds(e2c, e2r) and not HexGrid.IsBlocked(board, e2c, e2r)
                           and not (e2c == e1c and e2r == e1r)
                           and not (e2c == hero.col and e2r == hero.row) then
                            -- 检查跳过第2个敌人后的落点
                            local l2x, l2y, l2z = 2 * e2x - l1x, 2 * e2y - l1y, 2 * e2z - l1z
                            local l2c, l2r = HexGrid.CubeToOffset(l2x, l2y, l2z)
                            if HexGrid.InBounds(l2c, l2r) and not HexGrid.IsBlocked(board, l2c, l2r)
                               and not (l2c == e1c and l2r == e1r)
                               and not (l2c == hero.col and l2r == hero.row) then
                                -- 放置2个敌人
                                local template = ENEMY_TEMPLATES["slime"]
                                local piece1 = Battle.CreatePiece(template, e1c, e1r)
                                HexGrid.AddPiece(board, piece1)
                                Battle.AddVFX(state, "spawn_puff", { col = e1c, row = e1r, duration = 0.6 })
                                local piece2 = Battle.CreatePiece(template, e2c, e2r)
                                HexGrid.AddPiece(board, piece2)
                                Battle.AddVFX(state, "spawn_puff", { col = e2c, row = e2r, duration = 0.6 })
                                state.tutorialPhase = 3
                                Battle.AddLog(state, "⚠️ 2个敌人出现了！")
                                return
                            end
                        end
                    end
                end
            end
        end
        -- 找不到有效的链式位置，跳到批量刷怪
        state.tutorialPhase = 4

    elseif phase == 3 then
        -- 批量刷出敌人，恢复正常刷新
        local outerEmpty = Battle.GetOuterRingEmpty(board)
        if #outerEmpty > 0 then
            for i = #outerEmpty, 2, -1 do
                local j = math.random(1, i)
                outerEmpty[i], outerEmpty[j] = outerEmpty[j], outerEmpty[i]
            end
            local spawnCount = math.min(3, #outerEmpty)
            for i = 1, spawnCount do
                local pos = outerEmpty[i]
                local template = ENEMY_TEMPLATES["slime"]
                local piece = Battle.CreatePiece(template, pos.col, pos.row)
                HexGrid.AddPiece(board, piece)
                Battle.AddVFX(state, "spawn_puff", { col = pos.col, row = pos.row, duration = 0.6 })
            end
            Battle.AddLog(state, string.format("⚠️ %d个敌人从外围出现了！", spawnCount))
        end
        state.tutorialPhase = 4
    end

    -- 教学刷怪完成（phase→4），标记已完成，后续重玩不再触发
    if state.tutorialPhase == 4 and G and G.playerData and not G.playerData.tutorialSpawnSeen then
        G.playerData.tutorialSpawnSeen = true
        PlayerData.Save(G.playerData)
    end
end

--- 回合中刷新敌人（外围）
--- 普通关：每2回合在外围空位刷1-2个敌人，场上敌人上限10
--- Boss关：每回合在外围刷1-2个小怪，场上小怪（不含Boss）上限8
function Battle.TrySpawnEnemies(state)
    -- 1-1 教学关：分阶段刷怪，跳过普通刷新逻辑
    if state.tutorialPhase and state.tutorialPhase < 4 then
        Battle.TryScriptedSpawn(state)
        return
    end
    local isBoss = state.boss ~= nil
    -- 普通关每2回合，Boss关每回合都刷
    if not isBoss and state.turn % 2 ~= 0 then return end

    local board = state.board
    local chapter, stageInChapter = Battle.GetChapterInfo(state.level)

    -- 检查场上敌人数量上限
    local aliveEnemies = HexGrid.GetTeamPieces(board, "enemy")
    local nonBossCount = 0
    for _, e in ipairs(aliveEnemies) do
        if not e.isBoss then nonBossCount = nonBossCount + 1 end
    end
    local maxEnemies = isBoss and 8 or 10  -- Boss关小怪上限更严格，防止棋盘拥挤
    if nonBossCount >= maxEnemies then return end

    -- 按章节选择敌人类型池（与GenerateLevel保持一致）
    local enemyTypes
    if chapter == 1 then
        -- 第一章: 逐步解锁，与GenerateLevel同步
        if stageInChapter <= 1 then
            enemyTypes = { "slime", "slime" }
        elseif stageInChapter <= 2 then
            enemyTypes = { "jellyfish", "iron_turtle" }
        elseif stageInChapter <= 3 then
            enemyTypes = { "jellyfish", "iron_turtle", "archerfish" }
        elseif stageInChapter <= 5 then
            enemyTypes = { "jellyfish", "iron_turtle", "vortex_eel" }
        elseif stageInChapter <= 6 then
            enemyTypes = { "jellyfish", "iron_turtle", "vortex_eel", "electric_ray" }
        else
            enemyTypes = { "jellyfish", "iron_turtle", "vortex_eel", "ghost_shark" }
        end
    elseif chapter == 2 then
        enemyTypes = { "fire_sprite", "lava_giant" }
        if stageInChapter >= 4 then
            enemyTypes = { "fire_sprite", "lava_giant", "fission_flame" }
        end
    elseif chapter == 3 then
        enemyTypes = { "coral_snapper", "sea_urchin", "reef_starfish" }
        if stageInChapter >= 4 then
            enemyTypes = { "coral_snapper", "sea_urchin", "spine_anemone", "splitting_urchin" }
        end
        if stageInChapter >= 7 then
            enemyTypes = { "coral_snapper", "sea_urchin", "spine_anemone", "coral_priest", "splitting_urchin" }
        end
    elseif chapter == 4 then
        enemyTypes = { "sand_scorpion", "quicksand_worm", "sand_hawk" }
    else
        enemyTypes = { "jellyfish" }
    end

    -- 获取外围空位
    local outerEmpty = Battle.GetOuterRingEmpty(board)
    if #outerEmpty == 0 then return end

    -- 洗牌
    for i = #outerEmpty, 2, -1 do
        local j = math.random(1, i)
        outerEmpty[i], outerEmpty[j] = outerEmpty[j], outerEmpty[i]
    end

    -- 刷新1-2个敌人（不超过上限差值）
    local spawnSlots = maxEnemies - nonBossCount
    local maxSpawn = math.min(2, spawnSlots, #outerEmpty)
    if maxSpawn <= 0 then return end
    local spawnCount = math.random(1, maxSpawn)

    -- 难度缩放（与GenerateLevel一致：基础线性 + 章内加速）
    local spawnChapter, spawnStage = Battle.GetChapterInfo(state.level)
    local spawnAccel = (spawnStage - 1) / 8
    local spawnAccelBonus = spawnAccel * spawnAccel
    local hpScale, atkScale
    if spawnChapter >= 2 then
        hpScale = 1.0 + 0.12 * (state.level - 1) + 0.40 * spawnAccelBonus
        atkScale = 1.0 + 0.09 * (state.level - 1) + 0.25 * spawnAccelBonus
    else
        hpScale = 1.0 + 0.18 * (state.level - 1) + 0.50 * spawnAccelBonus
        atkScale = 1.0 + 0.13 * (state.level - 1) + 0.35 * spawnAccelBonus
    end

    for i = 1, spawnCount do
        local pos = outerEmpty[i]
        local etype = enemyTypes[math.random(1, #enemyTypes)]
        local template = ENEMY_TEMPLATES[etype]
        local piece = Battle.CreatePiece(template, pos.col, pos.row)
        piece.hp = math.floor(piece.hp * hpScale)
        piece.maxHp = piece.hp
        if piece.atk > 0 then
            piece.atk = math.floor(piece.atk * atkScale)
        end
        HexGrid.AddPiece(board, piece)

        -- 第三章：新刷的怪在迷雾下不可见（不揭示）
        Battle.AddVFX(state, "spawn_puff", { col = pos.col, row = pos.row, duration = 0.6 })
    end

    Battle.AddLog(state, string.format("⚠️ %d个敌人从外围出现了！", spawnCount))

    -- 新刷出的敌人如果靠近祭坛，也需要获得护盾
    if Battle.GetActiveAltarCount(state.board) > 0 then
        Battle.UpdateAltarShields(state)
    end
end

--- 主角移动空间保护：当主角周围可移动空格不足时，清除最远的非Boss敌人
function Battle.EnsureHeroMobility(state)
    local hero = state.hero
    if not hero or hero.hp <= 0 then return end
    local board = state.board
    local MIN_FREE = 2  -- 主角至少需要2个相邻空格可移动

    -- 计算主角周围的空闲格数
    local function countHeroFreeNeighbors()
        local neighbors = HexGrid.GetNeighbors(hero.col, hero.row)
        local free = 0
        for _, n in ipairs(neighbors) do
            if HexGrid.InBounds(n.col, n.row) and not HexGrid.IsBlocked(board, n.col, n.row)
               and not HexGrid.GetPieceAt(board, n.col, n.row) then
                free = free + 1
            end
        end
        return free
    end

    local freeCount = countHeroFreeNeighbors()
    if freeCount >= MIN_FREE then return end

    -- 空间不足，尝试移除主角相邻的非Boss敌人（优先移除血量最低的）
    local neighbors = HexGrid.GetNeighbors(hero.col, hero.row)
    local adjacentEnemies = {}
    for _, n in ipairs(neighbors) do
        if HexGrid.InBounds(n.col, n.row) then
            local piece = HexGrid.GetPieceAt(board, n.col, n.row)
            if piece and piece.team == "enemy" and not piece.isBoss and piece.hp > 0 then
                adjacentEnemies[#adjacentEnemies + 1] = piece
            end
        end
    end

    -- 按血量升序排列，优先移除血量低的
    table.sort(adjacentEnemies, function(a, b) return a.hp < b.hp end)

    -- 逐个击退敌人直到主角有足够空间
    for _, enemy in ipairs(adjacentEnemies) do
        if countHeroFreeNeighbors() >= MIN_FREE then break end
        -- 尝试将敌人推到远离主角的空位
        local pushed = false
        local enemyNeighbors = HexGrid.GetNeighbors(enemy.col, enemy.row)
        -- 打乱顺序增加随机性
        for i = #enemyNeighbors, 2, -1 do
            local j = math.random(1, i)
            enemyNeighbors[i], enemyNeighbors[j] = enemyNeighbors[j], enemyNeighbors[i]
        end
        for _, en in ipairs(enemyNeighbors) do
            if HexGrid.InBounds(en.col, en.row)
               and not HexGrid.IsBlocked(board, en.col, en.row)
               and not HexGrid.GetPieceAt(board, en.col, en.row)
               and (en.col ~= hero.col or en.row ~= hero.row) then
                -- 直接修改敌人位置（推开）
                local oldCol, oldRow = enemy.col, enemy.row
                enemy.col = en.col
                enemy.row = en.row
                Battle.AddVFX(state, "spawn_puff", { col = en.col, row = en.row, duration = 0.4 })
                Battle.AddFloatingText(state, oldCol, oldRow,
                    "💨击退", {180, 220, 255, 255})
                pushed = true
                break
            end
        end
        -- 如果无法推开，直接击杀（极端情况保底）
        if not pushed then
            Battle.AddFloatingText(state, enemy.col, enemy.row,
                "💨驱散", {180, 180, 180, 255})
            Battle.AddLog(state, enemy.name .. "因空间挤压被驱散！")
            enemy.hp = 0
        end
    end
    -- 清理死亡敌人
    HexGrid.RemoveDead(board)
end

--- 创建一个棋子实例
function Battle.CreatePiece(template, col, row)
    local p = {}
    for k, v in pairs(template) do
        p[k] = v
    end
    p.col = col
    p.row = row
    return p
end

-- ============================================================================
-- 道具拾取
-- ============================================================================

function Battle.CheckItemPickup(state, col, row)
    local item = HexGrid.GetItemAt(state.board, col, row)
    if not item then return end

    local hero = state.hero
    local def = ITEM_TYPES[item.type]

    if item.type == "health_potion" then
        local heal = 20
        hero.hp = math.min(hero.maxHp, hero.hp + heal)
        Battle.AddFloatingText(state, hero.col, hero.row, "+" .. heal, {80, 255, 100, 255}, "heal", 3.0)
        Battle.AddVFX(state, "heal_pickup", { col = hero.col, row = hero.row, duration = 1.0 })
        Battle.AddLog(state, "拾取 " .. def.name .. "，回复 " .. heal .. " HP")
        AM.PlaySFX("heal_pickup", 1.0)

    elseif item.type == "health_potion_big" then
        local heal = hero.maxHp - hero.hp
        hero.hp = hero.maxHp
        Battle.AddFloatingText(state, hero.col, hero.row, "回满HP! +" .. heal, {0, 255, 80, 255}, "heal", 3.0)
        Battle.AddVFX(state, "heal_pickup", { col = hero.col, row = hero.row, duration = 1.0 })
        Battle.AddLog(state, "拾取 " .. def.name .. "，回满 HP！(+" .. heal .. ")")
        AM.PlaySFX("heal_pickup", 1.0)

    elseif item.type == "gold_bag" then
        local goldOverflow = (state.kills or 0) - (state.killTarget or 999)
        local bagBlocked = (goldOverflow > 5) and not Battle.IsBossLevel(state.level)
        local bagGold = bagBlocked and 1 or 3
        state.gold = state.gold + bagGold
        Battle.AddFloatingText(state, col, row, "+" .. bagGold .. "💰", {255, 215, 0, 255}, nil, 2.5)
        Battle.AddLog(state, "拾取 " .. def.name .. "，获得" .. bagGold .. "金币")
        AM.PlaySFX("item_pickup")

    elseif item.type == "shield" then
        state.hasShield = true
        Battle.AddFloatingText(state, col, row, "🛡️护盾!", {120, 180, 255, 255}, nil, 2.5)
        Battle.AddLog(state, "拾取 " .. def.name .. "，下次受击伤害减半")
        AM.PlaySFX("shield_ward")
    end

    HexGrid.RemoveItemAt(state.board, col, row)
end

-- ============================================================================
-- 行动执行
-- ============================================================================

--- 执行移动 (走到相邻空格)
---@param isFreeMove boolean|nil 是否为免费移动（不结束回合、不断combo）
function Battle.ExecuteMove(state, targetCol, targetRow, isFreeMove)
    local hero = state.hero
    local oldCol, oldRow = hero.col, hero.row

    local keepCombo = isFreeMove

    -- 移动动画（平滑滑动）
    hero.animFromCol = oldCol
    hero.animFromRow = oldRow
    hero.animTimer = 0.15
    hero.animMaxTimer = 0.15
    hero.animIsJump = false

    hero.col = targetCol
    hero.row = targetRow
    if not keepCombo then
        Battle.SettlePendingComboShield(state)  -- 连击链结束，结算延迟护盾
        state.combo = 0
    end
    Battle.AddLog(state, "剑士移动到 (" .. targetCol .. "," .. targetRow .. ")")

    -- 简单移动不触发震地落（只有跳跃最终落点才触发）

    -- 踏步斩: 移动时对最近敌人发起近战攻击
    local stepStrikeLv = Skills.Level(state.skills, "step_strike")
    if stepStrikeLv >= 1 then
        local ssBaseDmg  = 5 + stepStrikeLv * 5     -- Lv1=10, Lv2=15, Lv3=20, Lv4=25, Lv5=30
        local ssTargetN  = 1                         -- 始终只打1个敌人

        -- 收集场上存活敌人，按距离排序
        local aliveEnemies = HexGrid.GetTeamPieces(state.board, "enemy")
        local ssPool = {}
        for _, e in ipairs(aliveEnemies) do
            if e.hp > 0 then
                local d = HexGrid.CubeDistance(targetCol, targetRow, e.col, e.row)
                if d <= 1 then  -- 只打相邻格（距离=1）的敌人
                    ssPool[#ssPool + 1] = { enemy = e, dist = d }
                end
            end
        end
        table.sort(ssPool, function(a, b) return a.dist < b.dist end)

        local ssHits = math.min(ssTargetN, #ssPool)
        if ssHits > 0 then
            AM.PlaySFX("step_strike", 0.9)
            for i = 1, ssHits do
                local target  = ssPool[i].enemy
                local actualDmg = ssBaseDmg
                actualDmg = Battle.ApplyAltarReduction(state, target, actualDmg)
                if target.isBoss then
                    Battle.ApplyBossDamage(state, target, actualDmg)
                else
                    target.hp = target.hp - actualDmg
                end
                state.totalDamage = state.totalDamage + actualDmg
                target.hitFlash = 0.15
                Battle.AddVFX(state, "sword_slash", {
                    col = target.col, row = target.row,
                    fromCol = targetCol, fromRow = targetRow,
                    duration = 0.45,
                })
                Battle.AddFloatingText(state, target.col, target.row,
                    "-" .. actualDmg, {220, 80, 120, 255}, "hit")
                if target.hp <= 0 then
                    Battle.HandleEnemyDeath(state, target, false)
                end
            end
        end
    end

    -- 祭坛摧毁: 英雄移动到祭坛格时摧毁祭坛
    local altar = Battle.GetAltarAt(state.board, targetCol, targetRow)
    if altar then
        Battle.DestroyAltar(state, altar)
    end

    -- Boss光环检查（移动到Boss附近时立即触发）
    Battle.ProcessBossAura(state)

    -- 检查道具拾取
    Battle.CheckItemPickup(state, targetCol, targetRow)
end

--- 执行跳跃 (跳过敌人造成伤害, 或跳过岩石不造成伤害)
---@param isLastStep boolean 是否是连跳的最后一步（只有最后一步触发震地落等落地技能）
---@return table|nil 被攻击的敌人(岩石跳跃返回nil)
function Battle.ExecuteJump(state, jumpInfo, isLastStep)
    local hero = state.hero

    -- 记录跳跃出发位置（用于地刺陷阱）
    local jumpFromCol, jumpFromRow = hero.col, hero.row

    -- 跳跃动画（弧线抛物线）— combo越高弧线越高、速度越快
    hero.animFromCol = hero.col
    hero.animFromRow = hero.row
    local comboNow = state.combo  -- 当前combo（本跳递增前的值）
    local arcScale = 1.0 + math.min(comboNow, 8) * 0.15  -- 1.0→2.2 弧线倍率
    local speedUp = math.max(0.15, 0.25 - math.min(comboNow, 6) * 0.012) -- 0.25→0.178 越快
    hero.animTimer = speedUp
    hero.animMaxTimer = speedUp
    hero.animIsJump = true
    hero.animArcScale = arcScale  -- 传给BoardWidget用于弧线高度

    -- 移动英雄到落点
    hero.col = jumpInfo.col
    hero.row = jumpInfo.row

    -- === 岩石跳跃: 只移动，不造成伤害，但计入连跳combo ===
    if jumpInfo.isRockJump then
        -- 判断是岩石跳还是贝壳跳
        local isShellJump = false
        if state.board.shells then
            for _, s in ipairs(state.board.shells) do
                if s.col == jumpInfo.jumpedCol and s.row == jumpInfo.jumpedRow then
                    isShellJump = true
                    break
                end
            end
        end

        state.combo = state.combo + 1
        if state.combo > state.maxCombo then
            state.maxCombo = state.combo
        end

        if isShellJump then
            -- 贝壳跳：显示不同文字
            local comboText = state.combo >= 2
                and string.format("🐚跳! %dx", state.combo)
                or "🐚跳!"
            Battle.AddFloatingText(state, jumpInfo.jumpedCol, jumpInfo.jumpedRow,
                comboText, {255, 220, 80, 255})
            Battle.AddLog(state, string.format("跳过贝壳到 (%d,%d)", jumpInfo.col, jumpInfo.row))
            -- 跳过贝壳后检查寄居蟹路径（贝壳不被清除，保留给寄居蟹）
            Battle.CheckCrabRescue(state)
        else
            -- 岩石跳
            local comboText = state.combo >= 2
                and string.format("🪨跳! %dx", state.combo)
                or "🪨跳!"
            Battle.AddFloatingText(state, jumpInfo.jumpedCol, jumpInfo.jumpedRow,
                comboText, {180, 170, 150, 255})
            Battle.AddLog(state, string.format("跳过岩石到 (%d,%d)", jumpInfo.col, jumpInfo.row))

            -- 触手伤害: 跳过触手时英雄受到伤害
            if jumpInfo.obstacle and jumpInfo.obstacle.isTentacle then
                -- 伤害 = Boss ATK的50%，至少10点
                local tentacleDmg = 10
                local enemies = HexGrid.GetTeamPieces(state.board, "enemy")
                for _, e in ipairs(enemies) do
                    if e.isBoss then
                        tentacleDmg = math.max(10, math.floor(e.atk * 0.5))
                        break
                    end
                end
                hero.hp = hero.hp - tentacleDmg
                Battle.AddFloatingText(state, jumpInfo.col, jumpInfo.row,
                    string.format("触手缠绕! -%d", tentacleDmg), {180, 60, 220, 255})
                Battle.AddVFX(state, "poison_puff", { col = jumpInfo.col, row = jumpInfo.row, duration = 0.5 })
                state.screenShake = (state.screenShake or 0) + 0.12
                Battle.AddLog(state, string.format("跳过触手受到 %d 点伤害！", tentacleDmg))
                if hero.hp <= 0 then
                    hero.hp = 0
                end
            end

            -- 跳过障碍物/祭坛时：祭坛摧毁、第3章珊瑚清除、其他章岩石保留(永久支点)
            if jumpInfo.obstacle then
                if jumpInfo.obstacle.isAltar then
                    Battle.DestroyAltar(state, jumpInfo.obstacle)
                    Battle.AddFloatingText(state, jumpInfo.jumpedCol, jumpInfo.jumpedRow,
                        "🔥摧毁!", {255, 150, 50, 255})
                    Battle.AddVFX(state, "spawn_puff", { col = jumpInfo.jumpedCol, row = jumpInfo.jumpedRow, duration = 0.5 })
                elseif Battle.GetChapterInfo(state.level) == 3 then
                    HexGrid.RemoveObstacle(state.board, jumpInfo.jumpedCol, jumpInfo.jumpedRow)
                    Battle.AddFloatingText(state, jumpInfo.jumpedCol, jumpInfo.jumpedRow,
                        "💥清除!", {255, 200, 100, 255})
                    Battle.AddVFX(state, "spawn_puff", { col = jumpInfo.jumpedCol, row = jumpInfo.jumpedRow, duration = 0.5 })
                    Battle.AddLog(state, string.format("🪸 清除了 (%d,%d) 的珊瑚！", jumpInfo.jumpedCol, jumpInfo.jumpedRow))
                    Battle.CheckCrabRescue(state)
                end
            end
        end

        -- === 飞跃先锋: 石头在前的双跳/三跳 — 处理位置2的敌人或石头 ===
        if jumpInfo.isDoubleJump then
            -- 位置2是敌人：造成伤害
            if jumpInfo.enemy2 or (jumpInfo.jumpedCol2 and not jumpInfo.jumpedObstacle2) then
                local e2 = jumpInfo.enemy2 or (jumpInfo.jumpedCol2 and HexGrid.GetPieceAt(state.board, jumpInfo.jumpedCol2, jumpInfo.jumpedRow2))
                if e2 and e2.hp and e2.hp > 0 then
                    local dmg2 = hero.atk + (state.comboAtkBonus or 0)
                    dmg2 = Battle.ApplyAltarReduction(state, e2, dmg2)
                    if e2.isBoss then
                        Battle.ApplyBossDamage(state, e2, dmg2)
                    else
                        e2.hp = e2.hp - dmg2
                    end
                    e2.hitFlash = 0.2
                    state.totalDamage = (state.totalDamage or 0) + dmg2
                    Battle.AddFloatingText(state, jumpInfo.jumpedCol2, jumpInfo.jumpedRow2,
                        "-" .. dmg2, {255, 180, 50, 255}, "hit")
                    Battle.AddFloatingText(state, jumpInfo.jumpedCol2, jumpInfo.jumpedRow2,
                        "🦅飞跃!", {100, 220, 180, 255})
                    if dmg2 > 0 and e2.hp <= 0 then
                        Battle.HandleEnemyDeath(state, e2, false)
                    end
                end
            end
            -- 位置2是障碍物/祭坛：祭坛摧毁、第3章珊瑚清除、其他保留
            if jumpInfo.jumpedObstacle2 and jumpInfo.jumpedCol2 then
                if jumpInfo.jumpedObstacle2.isAltar then
                    Battle.DestroyAltar(state, jumpInfo.jumpedObstacle2)
                    Battle.AddFloatingText(state, jumpInfo.jumpedCol2, jumpInfo.jumpedRow2,
                        "🔥摧毁!", {255, 150, 50, 255})
                    Battle.AddVFX(state, "spawn_puff", { col = jumpInfo.jumpedCol2, row = jumpInfo.jumpedRow2, duration = 0.5 })
                elseif Battle.GetChapterInfo(state.level) == 3 then
                    HexGrid.RemoveObstacle(state.board, jumpInfo.jumpedCol2, jumpInfo.jumpedRow2)
                    Battle.AddFloatingText(state, jumpInfo.jumpedCol2, jumpInfo.jumpedRow2,
                        "💥清除!", {255, 200, 100, 255})
                    Battle.AddVFX(state, "spawn_puff", { col = jumpInfo.jumpedCol2, row = jumpInfo.jumpedRow2, duration = 0.5 })
                    Battle.CheckCrabRescue(state)
                end
            end
            -- 飞跃先锋公告
            if not state.leapPioneerShownThisChain then
                state.leapPioneerShownThisChain = true
                state.leapPioneerAnnouncement = {
                    timer = 2.2, maxTimer = 2.2, jumpCount = 2,
                }
                AM.PlaySFX("gold_set_trigger", 1.5)
            end
        end

        -- === 飞跃先锋6/6: 石头在前的三跳 — 处理位置3 ===
        if jumpInfo.isTripleJump then
            if jumpInfo.enemy3 or (jumpInfo.jumpedCol3 and not jumpInfo.jumpedObstacle3) then
                local e3 = jumpInfo.enemy3 or (jumpInfo.jumpedCol3 and HexGrid.GetPieceAt(state.board, jumpInfo.jumpedCol3, jumpInfo.jumpedRow3))
                if e3 and e3.hp and e3.hp > 0 then
                    local dmg3 = hero.atk + (state.comboAtkBonus or 0)
                    dmg3 = Battle.ApplyAltarReduction(state, e3, dmg3)
                    if e3.isBoss then
                        Battle.ApplyBossDamage(state, e3, dmg3)
                    else
                        e3.hp = e3.hp - dmg3
                    end
                    e3.hitFlash = 0.2
                    state.totalDamage = (state.totalDamage or 0) + dmg3
                    Battle.AddFloatingText(state, jumpInfo.jumpedCol3, jumpInfo.jumpedRow3,
                        "-" .. dmg3, {255, 180, 50, 255}, "hit")
                    Battle.AddFloatingText(state, jumpInfo.jumpedCol3, jumpInfo.jumpedRow3,
                        "🦅三连!", {100, 255, 180, 255})
                    if dmg3 > 0 and e3.hp <= 0 then
                        Battle.HandleEnemyDeath(state, e3, false)
                    end
                end
            end
            if jumpInfo.jumpedObstacle3 and jumpInfo.jumpedCol3 then
                if jumpInfo.jumpedObstacle3.isAltar then
                    Battle.DestroyAltar(state, jumpInfo.jumpedObstacle3)
                    Battle.AddFloatingText(state, jumpInfo.jumpedCol3, jumpInfo.jumpedRow3,
                        "🔥摧毁!", {255, 150, 50, 255})
                    Battle.AddVFX(state, "spawn_puff", { col = jumpInfo.jumpedCol3, row = jumpInfo.jumpedRow3, duration = 0.5 })
                elseif Battle.GetChapterInfo(state.level) == 3 then
                    HexGrid.RemoveObstacle(state.board, jumpInfo.jumpedCol3, jumpInfo.jumpedRow3)
                    Battle.AddFloatingText(state, jumpInfo.jumpedCol3, jumpInfo.jumpedRow3,
                        "💥清除!", {255, 200, 100, 255})
                    Battle.AddVFX(state, "spawn_puff", { col = jumpInfo.jumpedCol3, row = jumpInfo.jumpedRow3, duration = 0.5 })
                    Battle.CheckCrabRescue(state)
                end
            end
            if state.leapPioneerAnnouncement then
                state.leapPioneerAnnouncement.jumpCount = 3
            end
        end

        -- 岩石跳跃：只有最终落点才触发震地落/落地技能
        if isLastStep then
            Battle.ApplyLandingSkills(state, jumpInfo.col, jumpInfo.row)
        end
        -- 祭坛摧毁: 跳跃落地到祭坛格时摧毁祭坛
        local rockJumpAltar = Battle.GetAltarAt(state.board, jumpInfo.col, jumpInfo.row)
        if rockJumpAltar then
            Battle.DestroyAltar(state, rockJumpAltar)
        end
        -- Boss光环检查（跳跃落地到Boss附近）
        Battle.ProcessBossAura(state)
        Battle.CheckItemPickup(state, jumpInfo.col, jumpInfo.row)
        return nil
    end

    -- === 敌人跳跃: 正常伤害流程 ===
    local enemy = jumpInfo.enemy

    -- Combo 递增
    state.combo = state.combo + 1
    if state.combo > state.maxCombo then
        state.maxCombo = state.combo
    end

    -- === 连跳过程中的递进反馈（combo越高越爽） ===
    if state.combo >= 3 then
        -- 每跳落地微震：3连=0.08, 4连=0.12, 5连=0.16, 6+=0.20
        local jumpShake = math.min(0.04 + state.combo * 0.04, 0.25)
        state.screenShake = (state.screenShake or 0) + jumpShake
        -- 每跳落地冲击波VFX（小型，与combo_burst区别）
        Battle.AddVFX(state, "jump_impact", {
            col = jumpInfo.col, row = jumpInfo.row,
            duration = 0.3 + math.min(state.combo, 7) * 0.05,
            combo = state.combo,
        })
    end

    -- 计算伤害: ATK × (1.0 + (combo-1) × multiplierRate)
    local baseDmg = hero.atk + state.comboAtkBonus

    -- 血怒: HP低时ATK加成 (Lv1-4: <50%→+26~44%, Lv5: <30%→ATK翻倍+50%)
    local rageLv = Skills.Level(state.skills, "blood_rage")
    if rageLv >= 1 then
        local threshold = rageLv >= 5 and 0.3 or 0.5
        if hero.hp < hero.maxHp * threshold then
            if rageLv >= 5 then
                baseDmg = baseDmg * 2
                Battle.AddFloatingText(state, hero.col, hero.row, "🪓狂战!", {255, 50, 50, 255})
            else
                local atkPct = 1.0 + (20 + rageLv * 6) / 100  -- Lv1=1.26, Lv4=1.44
                baseDmg = math.floor(baseDmg * atkPct)
            end
        end
    end
    -- 吸血跳Lv5: HP>80%时附带真实伤害
    local bloodOverlordBonus = 0
    if Skills.Level(state.skills, "vampiric_jump") >= 5 and hero.hp > hero.maxHp * 0.8 then
        bloodOverlordBonus = math.floor(hero.atk * 0.2)
    end
    -- 重力践踏/震地落Lv4/吸血跳Lv3/蓄势Lv3: combo≥3 基伤翻倍
    local gravLv = Skills.Level(state.skills, "gravity_stomp")
    local hasGravity = gravLv >= 1
        or Skills.Level(state.skills, "quake_land") >= 4
        or Skills.Level(state.skills, "vampiric_jump") >= 3
    if hasGravity and state.combo >= 3 then
        local bonus = 50 + gravLv * 30  -- Lv0=50%, Lv1=80%, ..., Lv5=200%
        baseDmg = math.floor(baseDmg * (1 + bonus / 100))
        Battle.AddFloatingText(state, jumpInfo.col, jumpInfo.row, "🦶重力!", {200, 150, 50, 255})
        Battle.AddVFX(state, "stomp", { col = jumpInfo.col, row = jumpInfo.row, duration = 0.5 })
    end

    -- 连跳伤害加成
    local comboRate = 0.5
    -- 重力践踏Lv4: 连跳伤害加成上限提升至+200%
    if gravLv >= 4 then
        comboRate = 0.75
    end
    local multiplier = 1.0 + (state.combo - 1) * comboRate
    if gravLv >= 4 then
        multiplier = math.min(multiplier, 3.0)  -- 最高300%(+200%)
    end
    local damage = math.floor(baseDmg * multiplier)

    -- 附加真实伤害(无视DEF)
    if bloodOverlordBonus > 0 then
        damage = damage + bloodOverlordBonus
        Battle.AddFloatingText(state, jumpInfo.jumpedCol, jumpInfo.jumpedRow,
            "+" .. bloodOverlordBonus .. "👑真伤", {255, 215, 0, 255})
    end

    -- 猎手印记: 对标记敌人额外伤害
    local markLv = Skills.Level(state.skills, "hunter_mark")
    if markLv >= 1 and enemy._hunterMarked then
        local markBonus = (20 + markLv * 7) / 100  -- Lv1=+27%, ..., Lv5=+55%
        local bonusDmg = math.floor(damage * markBonus)
        damage = damage + bonusDmg
        Battle.AddFloatingText(state, jumpInfo.jumpedCol, jumpInfo.jumpedRow,
            "🎯印记+" .. bonusDmg, {255, 120, 60, 255})
        -- Lv3: 击打印记敌人回复5HP
        if markLv >= 3 then
            local heal = math.min(5, hero.maxHp - hero.hp)
            if heal > 0 then
                hero.hp = hero.hp + heal
                Battle.AddFloatingText(state, hero.col, hero.row,
                    "+" .. heal .. "🎯", {100, 255, 100, 255})
            end
        end
    end

    -- 地刺陷阱Lv5: 踩刺敌人受全伤害+20%
    if Skills.Level(state.skills, "spike_trap") >= 5 then
        local spike = Battle.GetSpikeAt(state, enemy.col, enemy.row)
        if spike then
            damage = math.floor(damage * 1.2)
            Battle.AddFloatingText(state, jumpInfo.jumpedCol, jumpInfo.jumpedRow,
                "🔺刺伤+20%", {180, 100, 80, 255})
        end
    end

    -- 收集者: 对残血敌人额外伤害
    local collectorLv = Skills.Level(state.skills, "collector")
    if collectorLv >= 1 and enemy.maxHp and enemy.maxHp > 0 then
        local hpPct = enemy.hp / enemy.maxHp
        local threshold = (30 + collectorLv * 5) / 100  -- Lv1=35%, ..., Lv5=55%
        if hpPct < threshold then
            local bonusPct = (collectorLv == 5 and 50 or (20 + collectorLv * 10)) / 100  -- Lv1=+30%, ..., Lv4=+60%, Lv5=+50%(上限)
            local bonusDmg = math.floor(damage * bonusPct)
            damage = damage + bonusDmg
            Battle.AddFloatingText(state, jumpInfo.jumpedCol, jumpInfo.jumpedRow,
                "🎯收割+" .. bonusDmg, {180, 120, 200, 255})
        end
    end

    -- 祭坛减伤: 被祭坛笼罩的敌人获得百分比减伤（统一入口）
    damage = Battle.ApplyAltarReduction(state, enemy, damage)

    -- === 猎魂·嗜血 6/6: 血怒消耗（ATK×1.5）===
    local bloodRageMult, bloodRageText = SetEffects.ConsumeBloodRage(state.setEffects)
    if bloodRageMult > 1.0 and damage > 0 then
        damage = math.floor(damage * bloodRageMult)
        Battle.AddFloatingText(state, jumpInfo.jumpedCol, jumpInfo.jumpedRow,
            bloodRageText, {220, 40, 60, 255}, "combo")
        AM.PlaySFX("gold_set_trigger", 1.2)
    end

    -- v4.0 暴击判定
    local isCrit = SetEffects.RollCrit(state.critRate or 0)
    if isCrit and damage > 0 then
        damage = math.floor(damage * SetEffects.CRIT_MULTIPLIER)
        Battle.AddFloatingText(state, jumpInfo.jumpedCol, jumpInfo.jumpedRow,
            "💥暴击!" .. damage, {255, 50, 50, 255}, "combo")
        state.screenShake = (state.screenShake or 0) + 0.3
        AM.PlaySFX("attack_hit", 1.5, 1.2)
    end

    -- === 气泡鲀护甲: 第一次攻击被完全免伤，护甲破碎 ===
    if damage > 0 and enemy.bubbleArmor then
        enemy.bubbleArmor = false
        Battle.AddFloatingText(state, jumpInfo.jumpedCol, jumpInfo.jumpedRow,
            "🫧护甲破！", {80, 200, 240, 255})
        Battle.AddLog(state, enemy.name .. " 的气泡护甲被击破！")
        damage = 0  -- 本次免伤
    end

    -- Boss护盾减伤
    if damage > 0 and enemy.isBoss then
        Battle.ApplyBossDamage(state, enemy, damage)
    elseif damage > 0 then
        enemy.hp = enemy.hp - damage
    end
    if damage > 0 then
        state.totalDamage = state.totalDamage + damage
    end
    enemy.hitFlash = 0.2  -- per-piece 受击闪白
    -- 打击音效随combo递进：音调升高+音量加大，打击感更强
    local hitGain = math.min(1.0 + state.combo * 0.06, 1.5)
    local hitPitch = 1.0 + math.min(state.combo, 8) * 0.03
    AM.PlaySFX("attack_hit", hitGain, hitPitch)

    -- 英雄攻击动画 (精灵图帧切换用)
    hero._attackAnim = 0.35
    hero._attackAnimMax = 0.35

    -- === 裂变海胆: 首次被打到 50% HP 以下时分裂为 2 只小海胆 ===
    if enemy.enemyType == "splitting_urchin" and damage > 0
       and not enemy._hasSplit and enemy.hp > 0
       and enemy.hp < enemy.maxHp * 0.5 then
        enemy._hasSplit = true
        local board = state.board
        local neighbors = HexGrid.GetNeighbors(enemy.col, enemy.row)
        local freeSlots = {}
        for _, nb in ipairs(neighbors) do
            if HexGrid.InBounds(nb.col, nb.row)
               and not HexGrid.IsBlocked(board, nb.col, nb.row) then
                table.insert(freeSlots, nb)
            end
        end
        -- 随机打乱后取前2个格子
        for i = #freeSlots, 2, -1 do
            local j = math.random(1, i)
            freeSlots[i], freeSlots[j] = freeSlots[j], freeSlots[i]
        end
        local spawnCount = math.min(2, #freeSlots)
        if spawnCount > 0 then
            local miniTemplate = ENEMY_TEMPLATES["sea_urchin"]
            for i = 1, spawnCount do
                local slot = freeSlots[i]
                local mini = Battle.CreatePiece(miniTemplate, slot.col, slot.row)
                -- 小海胆 HP = 当前海胆剩余 HP 的一半（向上取整）
                local miniHp = math.max(1, math.ceil(enemy.hp / 2))
                mini.hp = miniHp
                mini.maxHp = miniHp
                mini.atk = math.max(1, math.floor(enemy.atk * 0.7))
                mini._hasSplit = true  -- 小海胆不再分裂
                mini.name = "小裂变海胆"
                HexGrid.AddPiece(board, mini)
                Battle.AddVFX(state, "split_spawn", {
                    col = slot.col, row = slot.row, duration = 0.5,
                    enemyType = "splitting_urchin",
                })
            end
            Battle.AddFloatingText(state, enemy.col, enemy.row,
                "💥分裂!", {200, 100, 220, 255}, "combo")
            Battle.AddLog(state, string.format(
                "裂变海胆分裂成 %d 只小海胆！", spawnCount))
        end
    end

    -- === 海胆反伤: 跳踩海胆/裂变海胆受到反伤 ===
    if (enemy.enemyType == "sea_urchin" or enemy.enemyType == "splitting_urchin") and damage > 0 then
        local thornDmg = math.floor(enemy.atk * 0.6)  -- 反伤 = 海胆ATK × 60%
        thornDmg = math.max(1, thornDmg)
        -- 护盾吸收反伤
        local shieldAbs = math.min(hero._shield or 0, thornDmg)
        if shieldAbs > 0 then
            hero._shield = hero._shield - shieldAbs
            thornDmg = thornDmg - shieldAbs
        end
        if thornDmg > 0 then
            hero.hp = hero.hp - thornDmg
            Battle.AddFloatingText(state, hero.col, hero.row,
                "🌰尖刺-" .. thornDmg, {180, 80, 20, 255})
        end
        Battle.AddLog(state, string.format("海胆反伤! 英雄受到 %d 点刺伤", math.floor(enemy.atk * 0.6)))
    end

    -- === 吸血跳: 等级决定吸血比例 ===
    local vampLv = Skills.Level(state.skills, "vampiric_jump")
    local vampRate = 0
    if vampLv >= 1 then
        vampRate = (5 + vampLv * 3) / 100  -- Lv1=8%, Lv2=11%, Lv3=14%, Lv4=17%, Lv5=20%
    end
    if vampRate > 0 then
        local heal = math.floor(damage * vampRate)
        if heal > 0 then
            local actualHeal = math.min(hero.maxHp - hero.hp, heal)
            hero.hp = hero.hp + actualHeal
            Battle.AddFloatingText(state, jumpInfo.col, jumpInfo.row,
                "+" .. actualHeal .. "🩸", {200, 50, 50, 255})
            Battle.AddVFX(state, "heal", {
                fromCol = jumpInfo.jumpedCol, fromRow = jumpInfo.jumpedRow,
                toCol = jumpInfo.col, toRow = jumpInfo.row,
                duration = 0.7,
            })

        end
    end

    -- === 连击护盾: 每次跳跃累积护盾 ===
    local shieldLv = Skills.Level(state.skills, "combo_shield")
    if shieldLv >= 1 then
        local perStack = 2 + shieldLv * 2     -- Lv1=4, Lv2=6, Lv3=8, Lv4=10, Lv5=12
        local shieldAmt = perStack
        -- Lv5: 5+连击护盾翻倍
        if shieldLv >= 5 and state.combo >= 5 then
            shieldAmt = shieldAmt * 2
        end
        -- 连击护盾固定上限: Lv1=20, Lv2=30, Lv3=40, Lv4=50, Lv5=60
        local shieldCap = 10 + shieldLv * 10
        local prevShield = state.hero._shield or 0
        local newShield = math.min(prevShield + shieldAmt, shieldCap)
        local actualGain = newShield - prevShield
        state.hero._shield = newShield
        if actualGain > 0 then
            Battle.AddFloatingText(state, jumpInfo.col, jumpInfo.row,
                "🛡+" .. actualGain, {60, 160, 220, 255})
            Battle.AddVFX(state, "shield_gain", {
                col = jumpInfo.col, row = jumpInfo.row, duration = 0.4,
            })
            AM.PlaySFX("combo_shield_gain", 0.5)
        end
    end

    -- 浮动伤害数字（护盾吸收时不显示伤害）— combo越高颜色越烈、字号越大
    if damage > 0 then
        local combo = state.combo
        -- 颜色递进：1-2白红, 3-4金黄, 5-6亮橙, 7+炽红
        local dmgColor
        if combo >= 7 then
            dmgColor = {255, 50, 30, 255}    -- 炽红
        elseif combo >= 5 then
            dmgColor = {255, 140, 30, 255}   -- 亮橙
        elseif combo >= 3 then
            dmgColor = {255, 200, 50, 255}   -- 金黄
        else
            dmgColor = {255, 80, 80, 255}    -- 普通红
        end
        Battle.AddFloatingText(state, jumpInfo.jumpedCol, jumpInfo.jumpedRow,
            "-" .. damage, dmgColor, "hit")
        -- 设置 comboLevel 用于字号递进
        local fts = state.floatingTexts
        fts[#fts].comboLevel = combo
    end

    -- Combo 提示已移至顶部横幅公告，棋盘上不再弹出浮动文字

    Battle.AddLog(state, string.format("跳跃攻击 %s！伤害 %d (%dx连跳)",
        enemy.name, damage, state.combo))

    -- 死亡处理（护盾吸收时不触发）
    if damage > 0 and enemy.hp <= 0 then
        Battle.HandleEnemyDeath(state, enemy, false)
    end
    -- 沙虫身体段: 伤害路由到头部，检查头部是否死亡
    if damage > 0 and enemy.snakeHead and enemy.snakeHead.hp <= 0 then
        Battle.HandleEnemyDeath(state, enemy.snakeHead, false)
    end

    -- === 飞跃先锋: 双敌跳 — 对第二个敌人造成伤害 / 清除石头 ===
    if jumpInfo.isDoubleJump then
        if jumpInfo.enemy2 then
            local enemy2 = jumpInfo.enemy2
            if enemy2.hp > 0 then
                local dmg2 = damage  -- 与第一个敌人相同伤害
                dmg2 = Battle.ApplyAltarReduction(state, enemy2, dmg2)
                if enemy2.isBoss then
                    Battle.ApplyBossDamage(state, enemy2, dmg2)
                else
                    enemy2.hp = enemy2.hp - dmg2
                end
                enemy2.hitFlash = 0.2
                state.totalDamage = state.totalDamage + dmg2
                Battle.AddFloatingText(state, jumpInfo.jumpedCol2, jumpInfo.jumpedRow2,
                    "-" .. dmg2, {255, 180, 50, 255}, "hit")
                local fts3 = state.floatingTexts
                fts3[#fts3].comboLevel = state.combo
                Battle.AddFloatingText(state, jumpInfo.jumpedCol2, jumpInfo.jumpedRow2,
                    "🦅飞跃!", {100, 220, 180, 255})
                if dmg2 > 0 and enemy2.hp <= 0 then
                    Battle.HandleEnemyDeath(state, enemy2, false)
                end
            end
        elseif jumpInfo.jumpedObstacle2 and jumpInfo.jumpedCol2 then
            -- 位置2是障碍物/祭坛：祭坛摧毁、第3章珊瑚清除、其他保留
            if jumpInfo.jumpedObstacle2.isAltar then
                Battle.DestroyAltar(state, jumpInfo.jumpedObstacle2)
                Battle.AddFloatingText(state, jumpInfo.jumpedCol2, jumpInfo.jumpedRow2,
                    "🔥摧毁!", {255, 150, 50, 255})
                Battle.AddVFX(state, "spawn_puff", { col = jumpInfo.jumpedCol2, row = jumpInfo.jumpedRow2, duration = 0.5 })
            elseif Battle.GetChapterInfo(state.level) == 3 then
                HexGrid.RemoveObstacle(state.board, jumpInfo.jumpedCol2, jumpInfo.jumpedRow2)
                Battle.AddFloatingText(state, jumpInfo.jumpedCol2, jumpInfo.jumpedRow2,
                    "💥清除!", {255, 200, 100, 255})
                Battle.AddVFX(state, "spawn_puff", { col = jumpInfo.jumpedCol2, row = jumpInfo.jumpedRow2, duration = 0.5 })
                Battle.CheckCrabRescue(state)
            end
        end
        -- 飞跃先锋公告横幅（一次跳跃链只触发一次）
        if not state.leapPioneerShownThisChain then
            state.leapPioneerShownThisChain = true
            state.leapPioneerAnnouncement = {
                timer = 2.2,
                maxTimer = 2.2,
                jumpCount = 2,
            }
            AM.PlaySFX("gold_set_trigger", 1.5)
        end
    end

    -- === 飞跃先锋6/6: 三敌跳 — 对第三个敌人造成伤害 / 清除石头 ===
    if jumpInfo.isTripleJump then
        if jumpInfo.enemy3 then
            local enemy3 = jumpInfo.enemy3
            if enemy3.hp > 0 then
                local dmg3 = damage  -- 与第一个敌人相同伤害
                dmg3 = Battle.ApplyAltarReduction(state, enemy3, dmg3)
                if enemy3.isBoss then
                    Battle.ApplyBossDamage(state, enemy3, dmg3)
                else
                    enemy3.hp = enemy3.hp - dmg3
                end
                enemy3.hitFlash = 0.2
                state.totalDamage = state.totalDamage + dmg3
                Battle.AddFloatingText(state, jumpInfo.jumpedCol3, jumpInfo.jumpedRow3,
                    "-" .. dmg3, {255, 180, 50, 255}, "hit")
                local fts4 = state.floatingTexts
                fts4[#fts4].comboLevel = state.combo
                Battle.AddFloatingText(state, jumpInfo.jumpedCol3, jumpInfo.jumpedRow3,
                    "🦅三连!", {100, 255, 180, 255})
                if dmg3 > 0 and enemy3.hp <= 0 then
                    Battle.HandleEnemyDeath(state, enemy3, false)
                end
            end
        elseif jumpInfo.jumpedObstacle3 and jumpInfo.jumpedCol3 then
            -- 位置3是障碍物/祭坛：祭坛摧毁、第3章珊瑚清除、其他保留
            if jumpInfo.jumpedObstacle3.isAltar then
                Battle.DestroyAltar(state, jumpInfo.jumpedObstacle3)
                Battle.AddFloatingText(state, jumpInfo.jumpedCol3, jumpInfo.jumpedRow3,
                    "🔥摧毁!", {255, 150, 50, 255})
                Battle.AddVFX(state, "spawn_puff", { col = jumpInfo.jumpedCol3, row = jumpInfo.jumpedRow3, duration = 0.5 })
            elseif Battle.GetChapterInfo(state.level) == 3 then
                HexGrid.RemoveObstacle(state.board, jumpInfo.jumpedCol3, jumpInfo.jumpedRow3)
                Battle.AddFloatingText(state, jumpInfo.jumpedCol3, jumpInfo.jumpedRow3,
                    "💥清除!", {255, 200, 100, 255})
                Battle.AddVFX(state, "spawn_puff", { col = jumpInfo.jumpedCol3, row = jumpInfo.jumpedRow3, duration = 0.5 })
                Battle.CheckCrabRescue(state)
            end
        end
        if state.leapPioneerAnnouncement then
            state.leapPioneerAnnouncement.jumpCount = 3
        end
    end

    -- === 第三章: 火灵灼烧DOT ===
    if enemy.enemyType == "fire_sprite" and enemy.burnDamage then
        state.heroBurn = enemy.burnDuration or 2
        state.heroBurnDmg = enemy.burnDamage or 5
        Battle.AddFloatingText(state, hero.col, hero.row,
            "🔥灼烧!" .. state.heroBurnDmg .. "/回合", {255, 120, 30, 255})
        Battle.AddLog(state, string.format("火灵灼烧！每回合%d伤害，持续%d回合", state.heroBurnDmg, state.heroBurn))
    end





    -- 落地技能（震地落/天崩地裂/地震连锁）—— 只在最终落点触发
    if isLastStep then
        Battle.ApplyLandingSkills(state, jumpInfo.col, jumpInfo.row)
    end

    -- 祭坛摧毁: 跳跃落地到祭坛格时摧毁祭坛
    local enemyJumpAltar = Battle.GetAltarAt(state.board, jumpInfo.col, jumpInfo.row)
    if enemyJumpAltar then
        Battle.DestroyAltar(state, enemyJumpAltar)
    end

    -- Boss光环检查（跳跃落地到Boss附近）
    Battle.ProcessBossAura(state)

    -- 检查道具拾取
    Battle.CheckItemPickup(state, jumpInfo.col, jumpInfo.row)

    -- 地刺陷阱: 在跳跃出发位置周围放置地刺
    Battle.PlaceSpikeTraps(state, jumpFromCol, jumpFromRow)

    -- 连击奖励已移至 TurnFlow.FinishExecution（落地后触发）

    return enemy
end

--- 统一落地技能入口: 震地落(T1) / 天崩地裂(T2) / 地震连锁(T2)
function Battle.ApplyLandingSkills(state, col, row)
    local quakeLv = Skills.Level(state.skills, "quake_land")
    local hasQuake = quakeLv >= 1
    local hasCataclysm = quakeLv >= 4     -- Lv4: combo≥3全场AOE
    local hasSeismic = quakeLv >= 3        -- Lv3: 2圈范围+闪电弹射

    -- 基础移动冲击: 即使没有震地落技能，移动也对周围敌人造成伤害（基于ATK的40%）
    if not hasQuake and not hasCataclysm and not hasSeismic then
        local hero = state.hero
        local baseDmg = math.max(5, math.floor(hero.atk * 0.4))
        local neighbors = HexGrid.GetNeighbors(col, row)
        local hit = false
        for _, n in ipairs(neighbors) do
            local target = HexGrid.GetPieceAt(state.board, n.col, n.row)
            if target and target.team == "enemy" and target.hp > 0 then
                -- 计算实际伤害（扣除敌人防御）
                local actualDmg = math.max(1, baseDmg - (target.def or 0))
                actualDmg = Battle.ApplyAltarReduction(state, target, actualDmg)
                target.hp = target.hp - actualDmg
                state.totalDamage = state.totalDamage + actualDmg
                Battle.AddFloatingText(state, n.col, n.row,
                    "-" .. actualDmg .. "⚔", {255, 220, 100, 230})
                hit = true
                if target.hp <= 0 then
                    Battle.HandleEnemyDeath(state, target, false)
                end
            end
        end
        -- 始终显示落地冲击波（命中时更强）
        state.screenShake = (state.screenShake or 0) + (hit and 0.15 or 0.05)
        Battle.AddVFX(state, "shockwave", { col = col, row = row, duration = hit and 0.4 or 0.25 })
        return
    end

    -- 天崩地裂(T2): combo≥3时全场AOE，伤害8+4×combo
    if hasCataclysm and state.combo >= 3 then
        local aoeDmg = 8 + 4 * state.combo
        local allEnemies = HexGrid.GetTeamPieces(state.board, "enemy")
        for _, target in ipairs(allEnemies) do
            if target.hp > 0 then
                local aoeDmgReduced = Battle.ApplyAltarReduction(state, target, aoeDmg)
                target.hp = target.hp - aoeDmgReduced
                state.totalDamage = state.totalDamage + aoeDmg
                Battle.AddFloatingText(state, target.col, target.row,
                    "-" .. aoeDmg .. "🌋", {255, 80, 20, 255})
                if target.hp <= 0 then
                    Battle.HandleEnemyDeath(state, target, false)
                end
            end
        end
        AM.PlaySFX("meteor_impact")
        Battle.AddLog(state, "🌋 天崩地裂！全场AOE " .. aoeDmg .. " 伤害！")
        state.screenShake = (state.screenShake or 0) + 0.6
        Battle.AddVFX(state, "shockwave", { col = col, row = row, duration = 0.8 })
        return
    end

    -- 震地落: 周围AOE (伤害随等级缩放: 6+lv*2)
    local aoeDmg = 6 + quakeLv * 2   -- Lv1=8, Lv2=10, ..., Lv5=16
    local aoeRange = hasSeismic and 2 or 1  -- Lv3+ 范围扩展到2圈
    -- 收集范围内所有格子（用于范围高亮）
    local affectedCells = {}
    local neighbors
    if aoeRange == 1 then
        neighbors = HexGrid.GetNeighbors(col, row)
    else
        neighbors = {}
        for r2 = 1, HexGrid.ROWS do
            for c2 = 1, HexGrid.COLS do
                if HexGrid.InBounds(c2, r2) then
                    local dist = HexGrid.CubeDistance(c2, r2, col, row)
                    if dist >= 1 and dist <= aoeRange then
                        neighbors[#neighbors + 1] = { col = c2, row = r2 }
                    end
                end
            end
        end
    end
    for _, n in ipairs(neighbors) do
        affectedCells[#affectedCells + 1] = { col = n.col, row = n.row }
    end

    local hit = false
    local hitTargets = {}
    local hitCells = {}  -- 实际命中的格子
    for _, n in ipairs(neighbors) do
        local target = HexGrid.GetPieceAt(state.board, n.col, n.row)
        if target and target.team == "enemy" and target.hp > 0 then
            local aoeDmgR = Battle.ApplyAltarReduction(state, target, aoeDmg)
            target.hp = target.hp - aoeDmgR
            state.totalDamage = state.totalDamage + aoeDmgR
            Battle.AddFloatingText(state, n.col, n.row,
                "-" .. aoeDmgR .. "💥", {255, 120, 30, 255})
            hit = true
            hitTargets[#hitTargets + 1] = target
            hitCells[#hitCells + 1] = { col = n.col, row = n.row }
            if target.hp <= 0 then
                Battle.HandleEnemyDeath(state, target, false)
            end
        end
    end
    if hit then
        AM.PlaySFX("hero_land")
        Battle.AddLog(state, "💥 震地落！对周围敌人造成 " .. aoeDmg .. " AOE伤害")
    end
    -- 每次震地落都加屏幕抖动，命中时更强
    state.screenShake = (state.screenShake or 0) + (hit and 0.4 or 0.2)
    Battle.AddVFX(state, "quake_land", {
        col = col, row = row, duration = 0.8,
        affectedCells = affectedCells,
        hitCells = hitCells,
        damage = aoeDmg,
        range = aoeRange,
    })

    -- 地震连锁(T2): 每个被击中的敌人触发一次闪电弹射
    if hasSeismic then
        for _, target in ipairs(hitTargets) do
            if target.hp > 0 then
                Battle.ApplyChainLightning(state, target, 1)
            end
        end
    end

end

--- 延迟应用漩涡鳗的打乱效果（在英雄落地动画完成后调用）
function Battle.ApplyPendingShuffles(state)
    if not state.pendingShuffles or #state.pendingShuffles == 0 then return end
    for _, info in ipairs(state.pendingShuffles) do
        local neighbors = HexGrid.GetNeighbors(info.col, info.row)
        local movablePieces = {}
        local emptySlots = {}
        for _, n in ipairs(neighbors) do
            local p = HexGrid.GetPieceAt(state.board, n.col, n.row)
            if p and p.hp > 0 and not p.isBoss then
                movablePieces[#movablePieces + 1] = p
                emptySlots[#emptySlots + 1] = { col = n.col, row = n.row }
            elseif not p and not HexGrid.IsBlocked(state.board, n.col, n.row) then
                emptySlots[#emptySlots + 1] = { col = n.col, row = n.row }
            end
        end
        if #movablePieces > 1 then
            -- 记录每个棋子的原始位置
            local oldPositions = {}
            for i, piece in ipairs(movablePieces) do
                oldPositions[i] = { col = piece.col, row = piece.row }
            end
            for i = #emptySlots, 2, -1 do
                local j = math.random(1, i)
                emptySlots[i], emptySlots[j] = emptySlots[j], emptySlots[i]
            end
            for i, piece in ipairs(movablePieces) do
                if i <= #emptySlots then
                    piece.col = emptySlots[i].col
                    piece.row = emptySlots[i].row
                end
            end
            -- 中心漩涡特效
            Battle.AddVFX(state, "vortex_shuffle", {
                col = info.col, row = info.row, duration = 1.2,
            })
            -- 每个被移动的棋子添加位移轨迹特效
            for i, piece in ipairs(movablePieces) do
                if i <= #emptySlots then
                    local old = oldPositions[i]
                    if old.col ~= piece.col or old.row ~= piece.row then
                        Battle.AddVFX(state, "shuffle_trail", {
                            fromCol = old.col, fromRow = old.row,
                            toCol = piece.col, toRow = piece.row,
                            duration = 0.8,
                        })
                    end
                end
            end
            Battle.AddFloatingText(state, info.col, info.row,
                "🌀打乱!", {80, 180, 255, 255})
            Battle.AddLog(state, "漩涡鳗死亡！周围棋子被打乱位置！")
        end
    end
    state.pendingShuffles = nil
end

--- 嗜血猎魂: 将本次行动中累积的回血量统一弹出一条浮动文字 + 血怒公告
--- 在 ExecuteMove / ExecuteJump 末尾调用，保证一次行动只出现一条文字
function Battle.FlushSoulHunterAccum(state, col, row)
    local totalHeal = state._soulHealAccum or 0
    local bloodRage  = state._bloodRageThisAction
    -- 清除累积
    state._soulHealAccum       = nil
    state._bloodRageThisAction = nil

    if totalHeal > 0 then
        -- 一条汇总回血文字
        local stacks = state.setEffects and state.setEffects.bloodRageStacks or 0
        local txt
        if bloodRage and stacks > 0 then
            txt = string.format("🩸+%d 血怒×%d!", totalHeal, stacks)
        else
            txt = "🩸+" .. totalHeal
        end
        Battle.AddFloatingText(state, col, row, txt, {220, 80, 100, 255}, "heal", 2.0)
        Battle.AddVFX(state, "heal", {
            fromCol = col, fromRow = row,
            toCol   = col, toRow   = row,
            duration = 0.6,
        })
    end

    -- 血怒公告：每次叠层都播报（不限次数）
    if bloodRage then
        local stacks = state.setEffects and state.setEffects.bloodRageStacks or 1
        state.soulHunterAnnouncement = { timer = 2.0, maxTimer = 2.0, stacks = stacks }
    end
end

--- 处理敌人死亡
---@param fromChain boolean 是否由连锁闪电触发（防止无限递归）
function Battle.HandleEnemyDeath(state, enemy, fromChain, skipShockwave, skipDeathSFX)
    -- 沙虫身体段保护：身体段不可单独死亡，只有头部死亡时才统一清除
    if enemy.isSegment and enemy.snakeHead and enemy.snakeHead.hp > 0 then
        enemy.hp = enemy.maxHp  -- 恢复身体段HP，防止后续再次触发死亡
        return
    end
    -- 死亡特效（配色匹配敌人类型）
    local deathColors = {
        slime = {120, 220, 80}, skeleton = {220, 210, 190}, mushroom = {160, 80, 200},
        jellyfish = {100, 200, 255}, iron_turtle = {150, 170, 190}, vortex_eel = {80, 120, 255},
        hermit_crab = {200, 140, 60}, fire_sprite = {255, 120, 30}, lava_giant = {255, 80, 0},

        shadow_knight = {180, 30, 50}, abyss_kraken = {100, 20, 160}, lava_lord = {255, 100, 0},
        ghost_shark = {100, 140, 200}, spine_anemone = {200, 80, 150},
        coral_priest = {255, 180, 120}, fission_flame = {255, 100, 30}, flame_shard = {255, 160, 60},
        splitting_urchin = {200, 100, 220},
    }
    Battle.AddVFX(state, "death_puff", {
        col = enemy.col, row = enemy.row, duration = 0.7,
        enemyColor = deathColors[enemy.enemyType] or {180, 60, 60},
        isBoss = enemy.isBoss or false,
    })
    if not skipDeathSFX then
        AM.PlaySFX("enemy_death")
    end

    -- === 沙虫头部死亡: 清除所有身体段 ===
    if enemy.isHead and state.sandWormSegments then
        for _, seg in ipairs(state.sandWormSegments) do
            if seg ~= enemy and seg.hp > 0 then
                seg.hp = 0
                Battle.AddVFX(state, "death_puff", {
                    col = seg.col, row = seg.row, duration = 0.5,
                    enemyColor = {210, 180, 100},
                })
            end
        end
        state.sandWormSegments = nil
        Battle.AddLog(state, "沙丘巨虫全身崩溃！")
    end

    -- 累加击杀计数（碎片不计入击杀目标）
    if not enemy.isShard and not enemy.isSegment then
        state.kills = (state.kills or 0) + 1
        Battle.AddLog(state, enemy.name .. " 被击败！(" .. state.kills .. "/" .. state.killTarget .. ")")
    else
        Battle.AddLog(state, enemy.name .. " 消散了！")
    end

    -- === 基础金币 (根据敌人类型) ===
    -- 防刷机制：击杀数超过目标+5后，不再获得金币（防止故意不完成章节任务拖关刷金）
    local killOverflow = (state.kills or 0) - (state.killTarget or 999)
    local goldBlocked = (killOverflow > 5) and not Battle.IsBossLevel(state.level)

    local baseGold = ENEMY_GOLD[enemy.enemyType] or 3
    local killGold = baseGold
    state.comboKillCount = state.comboKillCount + 1
    -- v4.0 金币加成(天赋: 点金手)
    local totalKillGold = killGold
    if (state.goldBonus or 0) > 0 then
        local bonusAmt = math.floor(totalKillGold * state.goldBonus / 100)
        totalKillGold = totalKillGold + bonusAmt
    end

    if goldBlocked then
        -- 超出击杀目标过多，金币收益降为1（保留正反馈但去除刷金收益）
        totalKillGold = 1
    end

    state.gold = state.gold + totalKillGold

    -- 吸血跳Lv3: 击杀+5临时ATK（单链上限+30）+ 回复12HP
    if Skills.Level(state.skills, "vampiric_jump") >= 3 then
        if state.comboAtkBonus < 30 then
            state.comboAtkBonus = math.min(30, state.comboAtkBonus + 5)
        end
        state.hero.hp = math.min(state.hero.maxHp, state.hero.hp + 12)
        Battle.AddFloatingText(state, state.hero.col, state.hero.row,
            "+5ATK +12HP🔥", {255, 100, 30, 255})
        AM.PlaySFX("vampiric_drain", 0.6)
    end



    -- 毒蘑菇死亡时对周围敌方造成伤害（不伤害英雄）
    if enemy.deathDamage and enemy.deathDamage > 0 then
        local neighbors = HexGrid.GetNeighbors(enemy.col, enemy.row)
        for _, n in ipairs(neighbors) do
            local target = HexGrid.GetPieceAt(state.board, n.col, n.row)
            if target and target.hp > 0 and target.team == "enemy" then
                target.hp = target.hp - enemy.deathDamage
                Battle.AddFloatingText(state, n.col, n.row,
                    "-" .. enemy.deathDamage .. "☠", {160, 80, 200, 255})
                Battle.AddLog(state, string.format("毒蘑菇爆炸！%s 受到 %d 伤害",
                    target.name, enemy.deathDamage))
            end
        end
    end

    -- === 第三章: 熔岩巨人死亡留下熔岩地形（有概率扩展到相邻格）===
    if enemy.leavesLava then
        local lavaDmg = enemy.lavaDamage or 8
        HexGrid.AddPoison(state.board, enemy.col, enemy.row, 99)  -- 持久熔岩
        local pt = HexGrid.GetPoisonAt(state.board, enemy.col, enemy.row)
        if pt then pt.damage = lavaDmg; pt.isLava = true end
        Battle.AddFloatingText(state, enemy.col, enemy.row,
            "🌋熔岩!", {255, 100, 0, 255})
        -- 30%概率扩展1个相邻格
        if math.random(1, 100) <= 30 then
            local neighbors = HexGrid.GetNeighbors(enemy.col, enemy.row)
            if #neighbors > 0 then
                local nb = neighbors[math.random(1, #neighbors)]
                if nb.col ~= state.hero.col or nb.row ~= state.hero.row then
                    HexGrid.AddPoison(state.board, nb.col, nb.row, 99)
                    local pt2 = HexGrid.GetPoisonAt(state.board, nb.col, nb.row)
                    if pt2 then pt2.damage = lavaDmg; pt2.isLava = true end
                end
            end
        end
        Battle.AddLog(state, "熔岩巨人倒下，留下灼热的熔岩地形！")
    end



    -- === 第二章: 漩涡鳗死亡打乱周围棋子（延迟到英雄落地后执行） ===
    if enemy.shuffleOnDeath then
        if not state.pendingShuffles then state.pendingShuffles = {} end
        state.pendingShuffles[#state.pendingShuffles + 1] = {
            col = enemy.col, row = enemy.row,
        }
    end

    -- === 裂焰精: 死亡分裂为2个焰碎片 ===
    if enemy.splitsOnDeath and not enemy.isShard then
        local splitNeighbors = HexGrid.GetNeighbors(enemy.col, enemy.row)
        local splitSlots = {}
        for _, n in ipairs(splitNeighbors) do
            if HexGrid.InBounds(n.col, n.row) and
               not HexGrid.IsBlocked(state.board, n.col, n.row) then
                splitSlots[#splitSlots + 1] = n
            end
        end
        -- 最多生成2个碎片
        local spawnCount = math.min(2, #splitSlots)
        if spawnCount > 0 then
            -- 随机打乱选出位置
            for i = #splitSlots, 2, -1 do
                local j = math.random(1, i)
                splitSlots[i], splitSlots[j] = splitSlots[j], splitSlots[i]
            end
            local shardTemplate = ENEMY_TEMPLATES["flame_shard"]
            for i = 1, spawnCount do
                local slot = splitSlots[i]
                local shard = Battle.CreatePiece(shardTemplate, slot.col, slot.row)
                -- 应用当前关卡难度缩放
                local chapter, stageInChapter = Battle.GetChapterInfo(state.level)
                local hpScale, atkScale
                if chapter == 1 then
                    hpScale = 1 + 0.15 * (stageInChapter - 1)
                    atkScale = 1 + 0.10 * (stageInChapter - 1)
                else
                    hpScale = 1 + 0.08 * (stageInChapter - 1)
                    atkScale = 1 + 0.06 * (stageInChapter - 1)
                end
                shard.hp = math.floor(shard.hp * hpScale)
                shard.maxHp = shard.hp
                shard.atk = math.floor(shard.atk * atkScale)
                HexGrid.AddPiece(state.board, shard)
                Battle.AddVFX(state, "split_spawn", {
                    col = slot.col, row = slot.row, duration = 0.5,
                    enemyType = "flame_shard",
                })
            end
            Battle.AddFloatingText(state, enemy.col, enemy.row,
                "💥分裂!", {255, 140, 30, 255}, "combo")
            Battle.AddLog(state, string.format("%s 分裂为 %d 个焰碎片！", enemy.name, spawnCount))
        end
    end

    -- === 第四章: 敌人死亡有 70% 概率产生大流沙区（7格，5回合后消失，最多5个） ===
    local ch4 = Battle.GetChapterInfo(state.level)
    local zoneCount = state.board.quicksandZones and #state.board.quicksandZones or 0
    if ch4 == 4 and not enemy.isSegment and not enemy.isBoss and zoneCount < 5 then
        if math.random() < 0.7 then
            local zoneCenter = { col = enemy.col, row = enemy.row }
            HexGrid.AddQuicksandZone(state.board, zoneCenter.col, zoneCenter.row)
            AM.PlaySFX("quicksand_spawn", 0.8)
            Battle.AddFloatingText(state, zoneCenter.col, zoneCenter.row,
                "⏳流沙区!", {210, 180, 100, 255})
            Battle.AddLog(state, enemy.name .. " 死亡处涌出大片流沙！(5回合后消散)")

            -- 推走流沙区内的所有角色（主角受伤）
            local zoneTiles = {{ col = zoneCenter.col, row = zoneCenter.row }}
            local zoneNeighbors = HexGrid.GetNeighbors(zoneCenter.col, zoneCenter.row)
            for _, n in ipairs(zoneNeighbors) do
                zoneTiles[#zoneTiles + 1] = n
            end
            for _, tile in ipairs(zoneTiles) do
                local piece = HexGrid.GetPieceAt(state.board, tile.col, tile.row)
                if piece and piece ~= enemy and not piece.isBoss and not piece.isSegment then
                    local safeCol, safeRow = HexGrid.FindNearestSafeCell(state.board, tile.col, tile.row)
                    if safeCol then
                        local oldCol, oldRow = piece.col, piece.row
                        piece.col, piece.row = safeCol, safeRow
                        if piece.isHero then
                            -- 主角被流沙推走时受到伤害并中断连跳
                            local pushDmg = 8
                            piece.hp = math.max(1, piece.hp - pushDmg)
                            state.quicksandInterrupted = true
                            -- 受击闪红动画（加长）
                            state.hitFlash = 0.6
                            -- 推开滑动动画（更慢，体现被沙流冲走的感觉）
                            piece.animFromCol = oldCol
                            piece.animFromRow = oldRow
                            piece.animTimer = 1.2
                            piece.animMaxTimer = 1.2
                            piece.animIsJump = false
                            piece.sandPushed = true  -- 标记：被流沙推开（用于渲染抖动+沙尘）
                            piece.sandPushTime = 1.2  -- 沙尘包裹特效计时
                            -- 起点警示圈（标记企鹅被推离此处）
                            Battle.AddVFX(state, "quicksand_warn", {
                                col = oldCol, row = oldRow,
                                duration = 1.0,
                            })
                            -- 沙尘冲击波特效（从旧位置到新位置，持续时间与动画匹配）
                            Battle.AddVFX(state, "sand_push", {
                                fromCol = oldCol, fromRow = oldRow,
                                toCol = safeCol, toRow = safeRow,
                                duration = 2.0,
                            })
                            -- 落点冲击波
                            Battle.AddVFX(state, "quicksand_land", {
                                col = safeCol, row = safeRow,
                                duration = 0.8,
                            })
                            -- 屏幕震动（更强）
                            state.screenShake = (state.screenShake or 0) + 1.2
                            -- 伤害浮动数字（更大更明显）
                            Battle.AddFloatingText(state, safeCol, safeRow,
                                "💨 -" .. pushDmg .. " 流沙冲击!", {255, 140, 30, 255}, "combo", 2.0)
                            -- 起点也弹出提示
                            Battle.AddFloatingText(state, oldCol, oldRow,
                                "⚠️被推开!", {255, 200, 50, 255}, "damage", 1.5)
                            AM.PlaySFX("combo_doomsday_blast", 0.7)
                            Battle.AddLog(state, "主角被流沙涌出推开，连跳中断！受到 " .. pushDmg .. " 点伤害！")
                        else
                            Battle.AddFloatingText(state, safeCol, safeRow,
                                "被推开", {180, 150, 80, 200})
                        end
                    end
                end
            end
        end
    end

    -- === 连锁闪电: 击杀弹射（六芒冲击时也跳过） ===
    if not fromChain and not skipShockwave then
        local chainLv = Skills.Level(state.skills, "chain_lightning")
        if chainLv >= 1 then
            local bounces = chainLv  -- Lv1=1, Lv2=2, ..., Lv5=5
            local chainDmg = 13 + chainLv * 2  -- Lv1=15, Lv2=17, ..., Lv5=23
            Battle.ApplyChainLightning(state, enemy, bounces, chainDmg)
        end
    end

    -- === 分裂弹: 击杀发射碎片 ===
    if not fromChain and not skipShockwave then
        local splitLv = Skills.Level(state.skills, "split_shot")
        if splitLv >= 1 then
            Battle.ApplySplitShot(state, enemy, splitLv, false)
        end
    end





    -- === 猎手印记Lv5: 击杀印记敌人回复15%最大HP ===
    if enemy._hunterMarked then
        local hMarkLv = Skills.Level(state.skills, "hunter_mark")
        if hMarkLv >= 5 then
            local heal = math.floor(state.hero.maxHp * 0.15)
            heal = math.min(heal, state.hero.maxHp - state.hero.hp)
            if heal > 0 then
                state.hero.hp = state.hero.hp + heal
                Battle.AddFloatingText(state, state.hero.col, state.hero.row,
                    "+" .. heal .. "🎯猎杀", {100, 255, 100, 255})
            end
        end
        enemy._hunterMarked = false
    end

    -- === 猎魂·嗜血 4/6+: 击杀回血 + 6/6血怒叠层 ===
    -- 回血累积到 _soulHealAccum，由 ExecuteMove/ExecuteJump 末尾统一弹出一条汇总文字
    if state.setEffects and state.setEffects.soulHunterTier > 0 then
        local healAmt, _, bloodRageTriggered =
            SetEffects.OnKillHeal(state.setEffects, state.hero, enemy.isShard)
        if healAmt > 0 then
            state.hero.hp = state.hero.hp + healAmt
            state._soulHealAccum = (state._soulHealAccum or 0) + healAmt
        end
        if bloodRageTriggered then
            AM.PlaySFX("gold_set_trigger", 1.0)
            state._bloodRageThisAction = true  -- 本次行动触发了血怒，末尾统一播报
        end
    end

    -- 清理死亡棋子
    HexGrid.RemoveDead(state.board)

    -- 第三章: 敌人被清除后路径可能通了，重新检查寄居蟹
    if state.board.crabs then
        Battle.CheckCrabRescue(state)
    end
end

--- 连锁闪电: 找到距离来源最近的存活敌人，造成伤害
---@param targetCount number 弹射目标数量 (默认1)
---@param chainDmg number|nil 自定义伤害 (默认15)
function Battle.ApplyChainLightning(state, source, targetCount, chainDmg)
    targetCount = targetCount or 1
    chainDmg = chainDmg or 15
    AM.PlaySFX("lightning", 0.7)
    local aliveEnemies = HexGrid.GetTeamPieces(state.board, "enemy")

    -- 按距离排序
    local candidates = {}
    for _, e in ipairs(aliveEnemies) do
        if e.hp > 0 and e ~= source then
            local dist = HexGrid.CubeDistance(source.col, source.row, e.col, e.row)
            candidates[#candidates + 1] = { enemy = e, dist = dist }
        end
    end
    table.sort(candidates, function(a, b) return a.dist < b.dist end)

    local hitCount = math.min(targetCount, #candidates)
    for i = 1, hitCount do
        local target = candidates[i].enemy
        local chainDmgR = Battle.ApplyAltarReduction(state, target, chainDmg)
        target.hp = target.hp - chainDmgR
        state.totalDamage = state.totalDamage + chainDmgR
        Battle.AddFloatingText(state, target.col, target.row,
            "-" .. chainDmgR .. "⚡", {255, 255, 50, 255})
        Battle.AddVFX(state, "lightning", {
            fromCol = source.col, fromRow = source.row,
            toCol = target.col, toRow = target.row,
            duration = 0.5,
        })
        Battle.AddLog(state, string.format("⚡ 连锁闪电击中 %s！伤害 %d",
            target.name, chainDmg))
        if target.hp <= 0 then
            Battle.HandleEnemyDeath(state, target, true)
        end
    end
end

-- ============================================================================
-- 新技能: 分裂弹 / 猎手印记 / 地刺陷阱 / 连击护盾
-- ============================================================================

--- 分裂弹: 击杀后向最近敌人发射碎片
function Battle.ApplySplitShot(state, deadEnemy, splitLv, isSecondary)
    local count = 1 + math.floor(splitLv / 2)  -- Lv1=1, Lv2=2, Lv3=2, Lv4=3, Lv5=3
    local dmg = 5 + splitLv * 5                 -- Lv1=10, Lv2=15, ..., Lv5=30

    local alive = HexGrid.GetTeamPieces(state.board, "enemy")
    local candidates = {}
    for _, e in ipairs(alive) do
        if e.hp > 0 and e ~= deadEnemy then
            local dist = HexGrid.CubeDistance(deadEnemy.col, deadEnemy.row, e.col, e.row)
            candidates[#candidates + 1] = { enemy = e, dist = dist }
        end
    end
    table.sort(candidates, function(a, b) return a.dist < b.dist end)

    local hitCount = math.min(count, #candidates)
    if hitCount <= 0 then return end

    AM.PlaySFX("split_shot", 0.6)
    -- VFX 飞行时间 0.8s，impact 在 progress=0.75 时出现（约 0.6s）
    local SHARD_DURATION = 0.8
    local SHARD_IMPACT_DELAY = SHARD_DURATION * 0.75  -- 伤害数字延迟到弹体到达时显示
    for i = 1, hitCount do
        local target = candidates[i].enemy
        -- 跳过在本次多碎片循环中已被冲击波/其他效果击杀的目标
        if target.hp <= 0 then goto continue_shard end
        -- Lv3: 碎片穿透(不递减)
        local actualDmg = dmg
        if splitLv < 3 then
            actualDmg = math.floor(dmg * (1 - (i - 1) * 0.2))  -- 递减20%
        end
        actualDmg = Battle.ApplyAltarReduction(state, target, actualDmg)
        if target.isBoss then
            Battle.ApplyBossDamage(state, target, actualDmg)
        else
            target.hp = target.hp - actualDmg
        end
        state.totalDamage = state.totalDamage + actualDmg
        target.hitFlash = 0.2
        -- 伤害数字延迟显示，与弹体到达动画同步
        Battle.AddFloatingText(state, target.col, target.row,
            "-" .. actualDmg .. "💥", {80, 200, 220, 255}, "hit", nil, SHARD_IMPACT_DELAY)
        Battle.AddVFX(state, "split_shard", {
            fromCol = deadEnemy.col, fromRow = deadEnemy.row,
            toCol = target.col, toRow = target.row,
            duration = SHARD_DURATION,
        })
        -- Lv5: 碎片击杀再分裂1次(非二次碎片)
        if target.hp <= 0 then
            if splitLv >= 5 and not isSecondary then
                Battle.ApplySplitShot(state, target, splitLv, true)
            end
            Battle.HandleEnemyDeath(state, target, true)
        end
        ::continue_shard::
    end
end

--- 猎手印记: 自动标记血量最高的敌人（每回合开始时调用）
function Battle.ApplyHunterMarks(state)
    local markLv = Skills.Level(state.skills, "hunter_mark")
    if markLv < 1 then return end

    -- 先清除所有旧印记
    local alive = HexGrid.GetTeamPieces(state.board, "enemy")
    for _, e in ipairs(alive) do
        e._hunterMarked = false
    end

    -- 按HP排序（高→低）
    local candidates = {}
    for _, e in ipairs(alive) do
        if e.hp > 0 then
            candidates[#candidates + 1] = e
        end
    end
    table.sort(candidates, function(a, b) return a.hp > b.hp end)

    -- 标记最高HP的敌人
    local marks = markLv >= 4 and 2 or 1
    local marked = false
    for i = 1, math.min(marks, #candidates) do
        candidates[i]._hunterMarked = true
        marked = true
    end
    if marked then
        AM.PlaySFX("hunter_mark", 0.5)
    end
end

--- 地刺陷阱: 跳跃落地后在起点周围空格放置地刺
function Battle.PlaceSpikeTraps(state, fromCol, fromRow)
    local spikeLv = Skills.Level(state.skills, "spike_trap")
    if spikeLv < 1 then return end

    local dmg = 5 + spikeLv * 5           -- Lv1=10, ..., Lv5=30
    local dur = 2 + math.floor(spikeLv / 2) -- Lv1=2, Lv2=3, Lv3=3, Lv4=4, Lv5=4
    local maxTraps = math.min(spikeLv, 3)  -- Lv1=1, Lv2=2, Lv3+=3

    if not state._spikeTraps then state._spikeTraps = {} end

    -- 在英雄跳跃出发位置周围空格放置地刺
    local neighbors = HexGrid.GetNeighbors(fromCol, fromRow)
    local placed = 0
    for _, n in ipairs(neighbors) do
        if placed >= maxTraps then break end
        if not HexGrid.IsBlocked(state.board, n.col, n.row) and
           not HexGrid.GetPieceAt(state.board, n.col, n.row) and
           not Battle.GetSpikeAt(state, n.col, n.row) then
            state._spikeTraps[#state._spikeTraps + 1] = {
                col = n.col, row = n.row,
                damage = dmg, turns = dur,
            }
            Battle.AddFloatingText(state, n.col, n.row,
                "🔺地刺", {180, 100, 80, 255})
            Battle.AddVFX(state, "spike_place", {
                col = n.col, row = n.row, duration = 0.4,
            })
            placed = placed + 1
        end
    end
end

--- 连击护盾: 回合结束时检查护盾反弹
function Battle.ProcessShieldReflect(state)
    local shieldLv = Skills.Level(state.skills, "combo_shield")
    if shieldLv < 3 then return end
    local shield = state.hero._shield or 0
    if shield <= 0 then return end

    -- Lv3: 护盾未消耗时，回合结束反弹30%给周围敌人
    local reflectDmg = math.floor(shield * 0.3)
    if reflectDmg < 1 then return end

    local neighbors = HexGrid.GetNeighbors(state.hero.col, state.hero.row)
    for _, n in ipairs(neighbors) do
        local target = HexGrid.GetPieceAt(state.board, n.col, n.row)
        if target and target.team == "enemy" and target.hp > 0 then
            target.hp = target.hp - reflectDmg
            state.totalDamage = state.totalDamage + reflectDmg
            Battle.AddFloatingText(state, target.col, target.row,
                "-" .. reflectDmg .. "🛡", {60, 160, 220, 255})
            if target.hp <= 0 then
                Battle.HandleEnemyDeath(state, target, true, true)
            end
        end
    end
end

-- ============================================================================
-- 第二章: 连击奖励系统
-- ============================================================================

--- 连击奖励配置
Battle.COMBO_REWARDS = {
    [2] = { name = "追踪飞镖", icon = "combo_tier1", desc = "自动追踪一个敌人造成50伤害，或拾取一个道具" },
    [3] = { name = "稻草人",   icon = "combo_tier2", desc = "吸引全部仇恨，替你挡刀2回合" },
    [4] = { name = "六芒冲击波", icon = "combo_tier3", desc = "6方向射线秒杀小怪，对Boss造成60伤害" },
    [5] = { name = "生命虹吸", icon = "combo_tier4", desc = "吸取全体敌人20%当前生命(Boss固定30)，等量恢复自身血量，溢出转虹吸护盾(上限60)" },
    [6] = { name = "天罚陨石", icon = "combo_tier5", desc = "主角周围4格内秒杀小怪，对Boss造成240伤害；范围外敌人眩晕1回合" },
    [7] = { name = "末日炸弹", icon = "combo_tier6", desc = "秒杀全部小怪，对Boss造成150伤害" },
    [8] = { name = "毁灭重生", icon = "combo_tier6", desc = "秒杀全部小怪，对Boss造成150伤害，回满血+护盾" },
}

--- 连击奖励颜色配置（按阈值递增的华丽程度）
local COMBO_REWARD_COLORS = {
    [2] = { glow = {255, 200, 60},  text = {255, 230, 100}, flash = {255, 220, 80}  },
    [3] = { glow = {255, 160, 40},  text = {255, 200, 80},  flash = {255, 180, 50}  },
    [4] = { glow = {200, 120, 255}, text = {220, 160, 255},  flash = {180, 100, 255} },
    [5] = { glow = {40, 220, 80},   text = {80, 255, 130},  flash = {50, 240, 100}  },
    [6] = { glow = {255, 80, 20},   text = {255, 160, 80},   flash = {255, 120, 30}  },
    [7] = { glow = {255, 60, 200},  text = {255, 150, 230},  flash = {255, 80, 220}  },
}

--- 预检查连击奖励：返回即将触发的奖励等级和信息（不执行任何效果）
---@return number|nil tier, table|nil rewardInfo
function Battle.PeekComboReward(state)
    local combo = state.combo
    if not state.comboRewardsTriggered then return nil, nil end
    local threshold = math.min(combo, 8)
    if threshold >= 2 and not state.comboRewardsTriggered[threshold] then
        local reward = Battle.COMBO_REWARDS[threshold]
        if reward then
            return threshold, reward
        end
    end
    return nil, nil
end

--- 预选飞镖目标（仅返回位置信息，不执行任何效果）
--- 用于聚光灯教学时预算稻草人将出现的位置（在实际生成前调用）
--- 逻辑与 CheckComboRewards tier==3 保持一致，取最近空位作为预览
---@return table|nil { col, row }
function Battle.PeekScarecrowPos(state)
    local hero = state.hero
    local board = state.board
    local empty = HexGrid.GetEmptyPositions(board)
    -- 排除主角当前位置
    for i = #empty, 1, -1 do
        if empty[i].col == hero.col and empty[i].row == hero.row then
            table.remove(empty, i)
        end
    end
    if #empty == 0 then return nil end
    table.sort(empty, function(a, b)
        local da = HexGrid.CubeDistance(a.col, a.row, hero.col, hero.row)
        local db = HexGrid.CubeDistance(b.col, b.row, hero.col, hero.row)
        return da < db
    end)
    return empty[1]  -- 取最近空位（实际生成会从前4随机，教学预览用最近的即可）
end

--- 用于聚光灯教学时展示飞镖飞行路径
---@return table|nil { col, row, kind } 飞镖目标位置，无目标返回nil
function Battle.PeekDartTarget(state)
    local board = state.board
    local enemies = HexGrid.GetTeamPieces(board, "enemy")
    local aliveEnemies = {}
    for _, e in ipairs(enemies) do
        if e.hp > 0 then
            aliveEnemies[#aliveEnemies + 1] = e
        end
    end
    local dartTargets = {}
    for _, e in ipairs(aliveEnemies) do
        dartTargets[#dartTargets + 1] = { kind = "enemy", col = e.col, row = e.row }
    end
    for _, it in ipairs(board.items) do
        dartTargets[#dartTargets + 1] = { kind = "item", col = it.col, row = it.row }
    end
    if #dartTargets > 0 then
        -- 优先选离主角最近的目标（教学展示直观）
        local hero = state.hero
        table.sort(dartTargets, function(a, b)
            local da = HexGrid.CubeDistance(a.col, a.row, hero.col, hero.row)
            local db = HexGrid.CubeDistance(b.col, b.row, hero.col, hero.row)
            return da < db
        end)
        return dartTargets[1]
    end
    return nil
end

--- 检查并触发连击奖励（每个阈值每回合只触发一次）
---@return boolean triggered 是否触发了新奖励
function Battle.CheckComboRewards(state)
    local combo = state.combo
    if not state.comboRewardsTriggered then
        state.comboRewardsTriggered = {}
    end

    -- 只触发最高阈值的奖励（4连击只触发4连击效果，不触发2、3）
    -- 8连以上统一为 threshold=8（一次性触发毁灭重生，护盾由实际连击数决定）
    local threshold = math.min(combo, 8)
    if threshold >= 2 and not state.comboRewardsTriggered[threshold] then
        state.comboRewardsTriggered[threshold] = true
        -- 标记所有更低阈值为已触发，防止后续重复
        for t = 2, threshold - 1 do
            state.comboRewardsTriggered[t] = true
        end
        local reward = Battle.COMBO_REWARDS[threshold]
        if reward then
            local colors = COMBO_REWARD_COLORS[threshold] or COMBO_REWARD_COLORS[7]

            state.comboAnnouncement = {
                threshold = threshold,
                icon = reward.icon,
                name = reward.name,
                desc = reward.desc,
                timer = 2.5,
                maxTimer = 2.5,
                colors = colors,
            }

            -- 屏幕震动：高连击大幅增强
            local shakeIntensity
            if threshold >= 6 then
                shakeIntensity = 1.2 + (threshold - 6) * 0.4   -- 6连=1.2, 7连=1.6
            elseif threshold >= 5 then
                shakeIntensity = 0.8                             -- 5连=0.8
            else
                shakeIntensity = 0.3 + threshold * 0.12          -- 2~4连=0.54~0.78
            end
            state.screenShake = math.max(state.screenShake or 0, shakeIntensity)

            -- VFX 持续时间：高连击更久
            local vfxDuration = threshold >= 6 and 1.8 or (threshold >= 5 and 1.5 or 1.2)
            Battle.AddVFX(state, "combo_burst", {
                col = state.hero.col,
                row = state.hero.row,
                duration = vfxDuration,
                threshold = threshold,
                colors = colors,
            })

            -- 全屏公告已经显示连击信息，不再添加浮动文字避免重叠

            -- 分层连击音效：低/中/高，高连击更大声
            local comboSfxKey, comboGain
            if threshold >= 7 then
                comboSfxKey = "combo_doomsday_announce"
                comboGain = 1.5
            elseif threshold >= 6 then
                comboSfxKey = "combo_high"
                comboGain = 1.4
            elseif threshold == 5 then
                comboSfxKey = "combo_life_drain"
                comboGain = 1.3
            elseif threshold >= 4 then
                comboSfxKey = "combo_mid"
                comboGain = 1.2
            else
                comboSfxKey = "combo_low"
                comboGain = 1.0
            end
            AM.PlaySFX(comboSfxKey, comboGain)
            Battle.AddLog(state, string.format("🎯 %d连击奖励: %s%s - %s",
                threshold, reward.icon, reward.name, reward.desc))
            Battle.ExecuteComboReward(state, threshold)

            -- 标记连击等级信息，用于聚光灯教学（是否首次由 TurnFlow 判断）
            state.comboSpotlightPending = {
                tier = threshold,
                name = reward.name,
                desc = reward.desc,
                icon = reward.icon,
            }

            return true
        end
    end
    return false
end

--- 执行具体的连击奖励效果
function Battle.ExecuteComboReward(state, threshold)
    local hero = state.hero
    local board = state.board

    if threshold == 2 then
        -- === 2连: 飞镖 ===
        -- 从主角身上发出飞镖，随机打向一个敌人造成伤害，或打向一个道具拾取
        local enemies = HexGrid.GetTeamPieces(board, "enemy")
        local aliveEnemies = {}
        for _, e in ipairs(enemies) do
            if e.hp > 0 then
                aliveEnemies[#aliveEnemies + 1] = e
            end
        end
        -- 收集所有可用目标：敌人 + 道具
        ---@type table[]
        local dartTargets = {}
        for _, e in ipairs(aliveEnemies) do
            dartTargets[#dartTargets + 1] = { kind = "enemy", obj = e, col = e.col, row = e.row }
        end
        for _, it in ipairs(board.items) do
            dartTargets[#dartTargets + 1] = { kind = "item", obj = it, col = it.col, row = it.row }
        end

        if #dartTargets > 0 then
            -- 选择离主角最近的目标（与 PeekDartTarget 保持一致，确保聚光灯高亮和实际飞行目标相同）
            table.sort(dartTargets, function(a, b)
                local da = HexGrid.CubeDistance(a.col, a.row, hero.col, hero.row)
                local db = HexGrid.CubeDistance(b.col, b.row, hero.col, hero.row)
                return da < db
            end)
            local pick = dartTargets[1]

            -- 飞镖伤害延迟到动画结束才生效
            local capturedPick = pick
            local capturedState = state
            AM.PlaySFX("combo_dart")
            Battle.AddVFX(state, "dart_fly", {
                fromCol = hero.col, fromRow = hero.row,
                toCol = pick.col, toRow = pick.row,
                duration = 0.6,
                onComplete = function()
                    if capturedPick.kind == "enemy" then
                        local target = capturedPick.obj
                        local dartDmg = 50
                        if target.hp <= 0 then return end  -- 已死亡则跳过
                        dartDmg = Battle.ApplyAltarReduction(capturedState, target, dartDmg)
                        if target.isBoss then
                            Battle.ApplyBossDamage(capturedState, target, dartDmg)
                        else
                            target.hp = target.hp - dartDmg
                        end
                        capturedState.totalDamage = capturedState.totalDamage + dartDmg
                        Battle.AddFloatingText(capturedState, target.col, target.row,
                            "-" .. dartDmg .. "🗡️飞镖!", {255, 180, 50, 255})
                        if target.hp <= 0 then
                            Battle.HandleEnemyDeath(capturedState, target, true)
                        end
                        -- 刷新HUD显示
                        local GameUI = require "GameUI"
                        pcall(GameUI.UpdateHUD)
                    else
                        local item = capturedPick.obj
                        local itemDef = ITEM_TYPES[item.type]
                        local itemName = itemDef and itemDef.name or "道具"
                        Battle.AddFloatingText(capturedState, item.col, item.row,
                            "🗡️飞镖拾取: " .. itemName, {255, 215, 0, 255}, nil, 2.8)
                        Battle.CheckItemPickup(capturedState, item.col, item.row)
                    end
                end,
            })
        else
            -- 无目标时：飞镖转化为回血效果（敌人全被连跳击杀的情况）
            local healAmt = 15
            hero.hp = math.min(hero.hp + healAmt, hero.maxHp)
            AM.PlaySFX("combo_dart")
            Battle.AddFloatingText(state, hero.col, hero.row,
                "🗡️飞镖回旋! +" .. healAmt .. "HP", {100, 255, 180, 255})
            Battle.AddVFX(state, "combo_burst", {
                col = hero.col, row = hero.row,
                duration = 0.5,
                threshold = 2,
                colors = COMBO_REWARD_COLORS[2],
            })
            Battle.AddLog(state, "🗡️ 飞镖找不到目标，回旋恢复" .. healAmt .. "HP")
        end

    elseif threshold == 3 then
        -- === 3连: 稻草人 ===
        -- 在靠近主角的空位生成稻草人，复制英雄属性，嘲讽所有敌人
        local empty = HexGrid.GetEmptyPositions(board)
        -- 排除主角当前位置（主角不在 board.pieces 中，GetEmptyPositions 会误判为空位）
        for i = #empty, 1, -1 do
            if empty[i].col == hero.col and empty[i].row == hero.row then
                table.remove(empty, i)
            end
        end
        if #empty > 0 then
            -- 按与主角的距离排序，优先选近处（距离1~2格）
            table.sort(empty, function(a, b)
                local da = HexGrid.CubeDistance(a.col, a.row, hero.col, hero.row)
                local db = HexGrid.CubeDistance(b.col, b.row, hero.col, hero.row)
                return da < db
            end)
            -- 从距离最近的前几个候选中随机选（避免总在同一格）
            local nearCount = math.min(#empty, 4)
            local pos = empty[math.random(1, nearCount)]
            state.scarecrow = {
                col = pos.col, row = pos.row,
                hp = hero.maxHp,
                maxHp = hero.maxHp,
                atk = hero.atk,
                def = hero.def,
                turnsLeft = 2,  -- 持续2个敌人回合
                totalDamageAbsorbed = 0,  -- 累计承受伤害
                hitCount = 0,             -- 被攻击次数
            }
            state.scarecrowActive = true
            state.scarecrowTutorialPending = true  -- 标记待弹教程（由TurnFlow检查）
            -- 只在稻草人位置显示高亮提示（连击横幅已由 CheckComboRewards 统一显示）
            AM.PlaySFX("combo_scarecrow")
            Battle.AddVFX(state, "ward_place", {
                col = pos.col, row = pos.row, duration = 0.7,
            })
            Battle.AddLog(state, string.format("🎃 稻草人出现在(%d,%d)！接下来2个敌人回合，所有敌人只会攻击稻草人！",
                pos.col, pos.row))
        end

    elseif threshold == 4 then
        -- === 4连: 六芒冲击波 ===
        -- 从英雄位置6个方向延伸射线，秒杀路径上小怪，对Boss造成60固定伤害
        -- 伤害延迟到VFX射线到达后才结算（onHit回调）
        local CUBE_DIRS = {
            {1, -1, 0}, {1, 0, -1}, {0, 1, -1},
            {-1, 1, 0}, {-1, 0, 1}, {0, -1, 1},
        }
        local hq, hr, hs = HexGrid.OffsetToCube(hero.col, hero.row)
        local maxDist = math.max(HexGrid.COLS, HexGrid.ROWS)
        -- 收集所有 AOE 覆盖的格子（用于 VFX 显示边界）
        local aoeCells = {}
        -- 只收集目标信息，不立即扣血
        local hitInfos = {}
        -- 收集每条射线方向最远的格子坐标，用于 VFX 射线方向对齐
        local rayEndCells = {}
        for dirIdx, dir in ipairs(CUBE_DIRS) do
            local lastCol, lastRow = hero.col, hero.row
            for dist = 1, maxDist do
                local tq = hq + dir[1] * dist
                local tr = hr + dir[2] * dist
                local ts = hs + dir[3] * dist
                local tc, trow = HexGrid.CubeToOffset(tq, tr, ts)
                if not HexGrid.InBounds(tc, trow) then
                    break  -- 超出棋盘边缘，此方向停止
                end
                lastCol, lastRow = tc, trow
                aoeCells[#aoeCells + 1] = { col = tc, row = trow }
                local target = HexGrid.GetPieceAt(board, tc, trow)
                if target and target.team == "enemy" and target.hp > 0 then
                    hitInfos[#hitInfos + 1] = {
                        target = target, col = tc, row = trow,
                        isBoss = target.isBoss or false,
                    }
                end
            end
            rayEndCells[#rayEndCells + 1] = { col = lastCol, row = lastRow }
        end
        local waveDmg = 60  -- 对Boss的固定伤害
        Battle.AddLog(state, string.format("六芒冲击波射线覆盖%d格, 发现%d个目标", #aoeCells, #hitInfos))
        local capturedState = state
        local capturedHitInfos = hitInfos
        local capturedWaveDmg = waveDmg
        AM.PlaySFX("combo_hex_blast")
        Battle.AddVFX(state, "hex_blast", {
            col = hero.col, row = hero.row,
            cells = aoeCells,
            rayEndCells = rayEndCells,
            hitCount = #hitInfos,
            totalDmg = waveDmg * #hitInfos,
            duration = 1.2,
            hitTime = 0.45,
            onHit = function()
                -- 六芒冲击波：秒杀路径上小怪，对Boss造成固定伤害
                local killCount = 0
                local totalDamage = 0
                for _, info in ipairs(capturedHitInfos) do
                    local e = info.target
                    if e.hp > 0 then
                        if info.isBoss then
                            -- Boss：固定伤害（不秒杀，正常扣血）
                            local dmg = capturedWaveDmg
                            Battle.ApplyBossDamage(capturedState, e, dmg)
                            totalDamage = totalDamage + dmg
                            Battle.AddFloatingText(capturedState, e.col, e.row,
                                "-" .. dmg .. "⚡", {255, 100, 100, 255})
                            if e.hp <= 0 then
                                killCount = killCount + 1
                                Battle.HandleEnemyDeath(capturedState, e, nil, true)
                            end
                        else
                            -- 小怪：祭坛保护下不秒杀，改为固定伤害
                            if (e.altarDamageReduction or 0) > 0 then
                                local dmg = Battle.ApplyAltarReduction(capturedState, e, capturedWaveDmg)
                                e.hp = e.hp - dmg
                                totalDamage = totalDamage + dmg
                                Battle.AddFloatingText(capturedState, e.col, e.row,
                                    "-" .. dmg .. "⚡", {255, 100, 100, 255})
                                if e.hp <= 0 then
                                    killCount = killCount + 1
                                    Battle.HandleEnemyDeath(capturedState, e, nil, true)
                                end
                            else
                                local dmg = e.hp
                                e.hp = 0
                                totalDamage = totalDamage + dmg
                                killCount = killCount + 1
                                Battle.AddFloatingText(capturedState, e.col, e.row,
                                    "💀秒杀", {255, 60, 60, 255})
                                Battle.HandleEnemyDeath(capturedState, e, nil, true)
                            end
                        end
                    end
                end
                if killCount > 0 or totalDamage > 0 then
                    AM.PlaySFX("shield_ward")
                    Battle.AddLog(capturedState, string.format("⚡ 六芒冲击波！击杀%d个敌人，造成%d总伤害！", killCount, totalDamage))
                end
                -- 刷新HUD
                local GameUI = require "GameUI"
                pcall(GameUI.UpdateHUD)
            end,
        })

    elseif threshold == 5 then
        -- === 5连: 生命虹吸 ===
        -- 吸取全体敌人生命（小怪20%当前HP，Boss固定30），治疗英雄
        -- 溢出的治疗转化为虹吸护盾（数值型，可叠加，与道具护盾区分）
        local enemies = HexGrid.GetTeamPieces(board, "enemy")
        local totalDrain = 0
        for _, e in ipairs(enemies) do
            if e.hp > 0 then
                local drainDmg
                if e.isBoss then
                    drainDmg = 30
                    Battle.ApplyBossDamage(state, e, drainDmg)
                else
                    drainDmg = math.floor(e.hp * 0.2)
                    drainDmg = math.max(drainDmg, 5)  -- 最少吸5
                    drainDmg = Battle.ApplyAltarReduction(state, e, drainDmg)
                    e.hp = e.hp - drainDmg
                end
                state.totalDamage = state.totalDamage + drainDmg
                totalDrain = totalDrain + drainDmg
                Battle.AddFloatingText(state, e.col, e.row,
                    "-" .. drainDmg .. "🩸", {200, 50, 80, 255})
                if e.hp <= 0 then
                    Battle.HandleEnemyDeath(state, e, true, true)
                end
            end
        end
        -- 治疗英雄，溢出部分转化为虹吸护盾（drainShield）
        local missingHp = hero.maxHp - hero.hp
        local healAmt = math.min(totalDrain, missingHp)
        local overflow = totalDrain - healAmt
        if healAmt > 0 then
            hero.hp = hero.hp + healAmt
            Battle.AddFloatingText(state, hero.col, hero.row,
                "💚+" .. healAmt, {80, 255, 120, 255})
        end
        if overflow > 0 then
            local MAX_DRAIN_SHIELD = 60
            local shieldBefore = state.drainShield or 0
            local shieldAdded = math.min(overflow, math.max(0, MAX_DRAIN_SHIELD - shieldBefore))
            if shieldAdded > 0 then
                state.drainShield = shieldBefore + shieldAdded
                Battle.AddFloatingText(state, hero.col, hero.row,
                    "🔮盾+" .. shieldAdded, {200, 80, 200, 255})
            else
                -- 护盾已满（60），溢出被吸收但无法增加，给出反馈
                Battle.AddFloatingText(state, hero.col, hero.row,
                    "🔮盾满!", {200, 80, 200, 255})
            end
        end
        state.screenShake = 0.5
        Battle.AddVFX(state, "life_drain", {
            col = hero.col, row = hero.row, duration = 1.2,
        })
        AM.PlaySFX("combo_hex_blast")
        local logMsg = string.format("🩸 生命虹吸！吸取%d生命，治疗%d", totalDrain, healAmt)
        if overflow > 0 then
            logMsg = logMsg .. string.format("，溢出%d转为护盾", overflow)
        end
        logMsg = logMsg .. "！"
        Battle.AddLog(state, logMsg)

    elseif threshold == 6 then
        -- === 6连: 天罚陨石（秒杀范围内小兵 + 范围外眩晕） ===
        -- 主角周围4格内秒杀小怪，对Boss造成240伤害；范围外敌人眩晕1回合
        local meteorRange = 4
        local enemies = HexGrid.GetTeamPieces(board, "enemy")
        local killCount = 0
        local stunCount = 0
        local totalMeteorDmg = 0
        -- 收集范围内的格子用于VFX显示
        local meteorCells = {}
        for r = -meteorRange, meteorRange do
            for q = -meteorRange, meteorRange do
                local s = -q - r
                if math.abs(q) + math.abs(r) + math.abs(s) <= meteorRange * 2 then
                    local hq2, hr2, hs2 = HexGrid.OffsetToCube(hero.col, hero.row)
                    local tc, trow = HexGrid.CubeToOffset(hq2 + q, hr2 + r, hs2 + s)
                    if HexGrid.InBounds(tc, trow) then
                        meteorCells[#meteorCells + 1] = { col = tc, row = trow }
                    end
                end
            end
        end
        for _, e in ipairs(enemies) do
            if e.hp > 0 then
                local dist = HexGrid.CubeDistance(hero.col, hero.row, e.col, e.row)
                if dist <= meteorRange then
                    -- 范围内：小兵秒杀，Boss造成240伤害
                    if e.isBoss then
                        local meteorDmg = 240
                        meteorDmg = Battle.ApplyAltarReduction(state, e, meteorDmg)
                        Battle.ApplyBossDamage(state, e, meteorDmg)
                        state.totalDamage = state.totalDamage + meteorDmg
                        totalMeteorDmg = totalMeteorDmg + meteorDmg
                        Battle.AddFloatingText(state, e.col, e.row,
                            "-" .. meteorDmg .. "☄️", {255, 100, 0, 255})
                        if e.hp <= 0 then
                            killCount = killCount + 1
                        end
                    else
                        -- 秒杀小兵
                        local meteorDmg = e.hp
                        state.totalDamage = state.totalDamage + meteorDmg
                        totalMeteorDmg = totalMeteorDmg + meteorDmg
                        e.hp = 0
                        Battle.AddFloatingText(state, e.col, e.row,
                            "秒杀☄️", {255, 60, 0, 255})
                        Battle.HandleEnemyDeath(state, e, true, true)
                        killCount = killCount + 1
                    end
                else
                    -- 范围外：眩晕1回合（Boss免疫眩晕）
                    if not e.isBoss then
                        e._stunnedTurns = (e._stunnedTurns or 0) + 1
                        stunCount = stunCount + 1
                        Battle.AddFloatingText(state, e.col, e.row,
                            "💫眩晕!", {255, 200, 0, 255})
                    end
                end
            end
        end
        state.screenShake = 0.7
        Battle.AddVFX(state, "meteor", {
            col = hero.col, row = hero.row, duration = 1.2,
            range = meteorRange,
            cells = meteorCells,
        })
        AM.PlaySFX("combo_meteor")
        Battle.AddLog(state, string.format("☄️ 天罚陨石降临！秒杀%d个敌人，眩晕%d个敌人，共%d伤害！", killCount, stunCount, totalMeteorDmg))

    elseif threshold >= 7 then
        -- === 7连+: 末日炸弹 / 8连+: 毁灭重生 ===
        -- 秒杀所有小怪 + 对Boss造成重击伤害（不秒杀）
        local bombEmoji = "💣"
        local enemies = HexGrid.GetTeamPieces(board, "enemy")
        local killCount = 0
        local toKill = {}
        for _, e in ipairs(enemies) do
            if e.hp > 0 then
                if e.isBoss then
                    -- 对Boss造成固定重击伤害（不秒杀，正常扣血）
                    local bossDmg = 150
                    Battle.ApplyBossDamage(state, e, bossDmg)
                    state.totalDamage = state.totalDamage + bossDmg
                    Battle.AddFloatingText(state, e.col, e.row,
                        "💥-" .. bossDmg .. " 重击!", {255, 80, 40, 255}, "hit")
                    Battle.AddLog(state, string.format("💣 末日炸弹对Boss造成%d重击伤害！", bossDmg))
                    if e.hp <= 0 then
                        killCount = killCount + 1
                        Battle.HandleEnemyDeath(state, e, true)
                    end
                else
                    toKill[#toKill + 1] = e
                end
            end
        end
        for _, e in ipairs(toKill) do
            if (e.altarDamageReduction or 0) > 0 then
                -- 祭坛保护下不秒杀，改为固定150伤害
                local dmg = Battle.ApplyAltarReduction(state, e, 150)
                e.hp = e.hp - dmg
                state.totalDamage = state.totalDamage + dmg
                Battle.AddFloatingText(state, e.col, e.row,
                    "-" .. dmg .. "💣", {255, 80, 40, 255})
                if e.hp <= 0 then
                    killCount = killCount + 1
                    Battle.HandleEnemyDeath(state, e, true)
                end
            else
                local killDmg = e.hp
                e.hp = 0
                state.totalDamage = state.totalDamage + killDmg
                killCount = killCount + 1
                Battle.AddFloatingText(state, e.col, e.row,
                    "💥清除!", {255, 60, 20, 255})
                Battle.HandleEnemyDeath(state, e, true)
            end
        end
        state.screenShake = 1.2
        -- 增强版VFX：收束 + 二次爆炸
        Battle.AddVFX(state, "convergence", {
            col = hero.col, row = hero.row, duration = 1.0,
        })
        Battle.AddVFX(state, "doomsday_explosion", {
            col = hero.col, row = hero.row, duration = 1.8,
            killCount = killCount,
        })
        AM.PlaySFX("combo_doomsday_blast")
        Battle.AddLog(state, string.format("💣💥 末日炸弹！清除%d个小怪，对Boss造成重击！", killCount))

        -- === 8连+: 毁灭重生 — 回满血（立即）+ 护盾（延迟到连击链结束）===
        if state.combo >= 8 then
            -- 回满血（立即生效）
            local healAmt = hero.maxHp - hero.hp
            hero.hp = hero.maxHp
            if healAmt > 0 then
                Battle.AddFloatingText(state, hero.col, hero.row,
                    "+" .. healAmt .. " 满血!", {80, 255, 80, 255})
            end
            -- 护盾延迟：标记待结算，连击链结束时按最终combo数计算
            state._pendingComboShield = true
            Battle.AddLog(state, "✨ 毁灭重生！回满血！护盾将在连击结束后结算")
        end
    end
end

--- 重置连击奖励追踪（每回合开始时调用）
function Battle.ResetComboRewards(state)
    state.comboRewardsTriggered = {}
    state.leapPioneerShownThisChain = false
end

--- 连击链结束时结算延迟护盾（在 combo 清零前调用）
function Battle.SettlePendingComboShield(state)
    if not state._pendingComboShield then return end
    state._pendingComboShield = nil

    local hero = state.hero
    local finalCombo = state.combo
    if finalCombo < 8 then return end  -- 安全检查

    -- 护盾：基础30 + 每多1连+15（8连=30, 9连=45, 10连=60...）
    local shieldAmt = 30 + (finalCombo - 8) * 15
    hero._shield = (hero._shield or 0) + shieldAmt
    Battle.AddFloatingText(state, hero.col, hero.row,
        "🛡+" .. shieldAmt, {60, 200, 255, 255})
    Battle.AddVFX(state, "shield_gain", {
        col = hero.col, row = hero.row, duration = 0.6,
    })
    AM.PlaySFX("combo_shield_gain")
    Battle.AddLog(state, string.format("🛡 连击结束！获得%d护盾（%d连）", shieldAmt, finalCombo))
end



--- 处理英雄灼烧DOT（每回合开始时调用）
function Battle.ProcessHeroBurn(state)
    if state.heroBurn and state.heroBurn > 0 then
        local dmg = state.heroBurnDmg or 5
        state.hero.hp = state.hero.hp - dmg
        state.heroBurn = state.heroBurn - 1
        Battle.AddFloatingText(state, state.hero.col, state.hero.row,
            "-" .. dmg .. "🔥灼烧", {255, 120, 30, 255})
        Battle.AddLog(state, string.format("灼烧伤害！-%dHP（剩余%d回合）", dmg, state.heroBurn))
        if state.heroBurn <= 0 then
            state.heroBurnDmg = 0
            Battle.AddLog(state, "灼烧效果消退")
        end
    end
end

--- 处理Boss光环伤害（英雄靠近Boss时自动受伤）
--- 触发时机: 每回合敌人行动前 + 英雄移动/跳跃落地后
function Battle.ProcessBossAura(state)
    local hero = state.hero
    if hero.hp <= 0 then return end
    if not Battle.IsBossLevel(state.level) then return end

    local enemies = HexGrid.GetTeamPieces(state.board, "enemy")
    for _, e in ipairs(enemies) do
        if e.isBoss and e.hp > 0 then
            local aura = BOSS_AURA[e.bossType]
            if aura then
                local dist = HexGrid.CubeDistance(hero.col, hero.row, e.col, e.row)
                if dist <= aura.range then
                    local dmg = aura.damage
                    -- 狂暴时光环伤害提升50%
                    if e.enraged then dmg = math.floor(dmg * 1.5) end
                    local actualDmg = math.max(1, math.floor(dmg - (hero.def or 0)))
                    -- 护盾减半
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
                    -- 连击护盾吸收
                    if (hero._shield or 0) > 0 and actualDmg > 0 then
                        local absorbed = math.min(hero._shield, actualDmg)
                        actualDmg = actualDmg - absorbed
                        hero._shield = hero._shield - absorbed
                        Battle.AddFloatingText(state, hero.col, hero.row,
                            "🛡-" .. absorbed, {60, 160, 220, 255})
                        if hero._shield <= 0 then
                            hero._shield = 0
                            Battle.AddVFX(state, "shield_break", { col = hero.col, row = hero.row })
                            AM.PlaySFX("shield_break", 0.6)
                        end
                    end
                    hero.hp = hero.hp - actualDmg
                    Battle.AddFloatingText(state, hero.col, hero.row,
                        "-" .. actualDmg .. aura.icon .. aura.name,
                        {aura.color[1], aura.color[2], aura.color[3], 255}, "hit")
                    state.screenShake = (state.screenShake or 0) + 0.2
                    state.hitFlash = 0.15
                    Battle.AddLog(state, string.format(
                        "%s的%s光环！对英雄造成 %d 伤害（距离%d格）",
                        e.name, aura.name, actualDmg, dist))
                    -- 光环技能公告
                    local auraSkillMap = {
                        abyss_kraken = "aura_abyss", shadow_knight = "aura_shadow",
                        lava_lord = "aura_lava", coral_guardian = "aura_coral",
                    }
                    local auraKey = auraSkillMap[e.bossType]
                    if auraKey and not state._auraAnnouncedThisTurn then
                        state._auraAnnouncedThisTurn = true
                        Battle.AddBossSkillAnnounce(state, auraKey, e.name)
                    end
                    -- 光环特效: 从Boss向英雄的波纹
                    Battle.AddVFX(state, "shockwave", {
                        col = hero.col, row = hero.row, duration = 0.5,
                    })
                    return  -- 每回合只触发一个Boss的光环
                end
            end
        end
    end
end

--- 处理寄居蟹缩壳状态切换（每回合敌人行动前调用）
function Battle.UpdateHermitCrabShell(state)
    local enemies = HexGrid.GetTeamPieces(state.board, "enemy")
    for _, e in ipairs(enemies) do
        if e.enemyType == "hermit_crab" and e.hp > 0 then
            if e.shellCooldown and e.shellCooldown > 0 then
                e.shellCooldown = e.shellCooldown - 1
                if e.shellCooldown <= 0 then
                    e.hasShell = not e.hasShell
                    e.shellCooldown = 2  -- 每2回合切换
                    if e.hasShell then
                        Battle.AddFloatingText(state, e.col, e.row,
                            "🐚缩壳!", {180, 140, 100, 255})
                    else
                        Battle.AddFloatingText(state, e.col, e.row,
                            "🦀出壳!", {255, 100, 50, 255})
                    end
                end
            else
                e.shellCooldown = 2
            end
        end
    end
end

--- 检查是否可以继续连跳
function Battle.CanChainJump(state)
    local hero = state.hero
    local jumps = HexGrid.FindValidJumps(state.board, hero.col, hero.row)
    return #jumps > 0
end

-- ============================================================================
-- 敌人回合
-- ============================================================================

--- 执行所有敌人的回合
---@return table 行动日志列表
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
                action = { type = "idle", enemy = enemy }
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
            local baseDmg = math.max(1, enemy.atk - targetDef)
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

    -- === 幽灵鲨: 瞬移到英雄身边攻击 ===
    if enemy.enemyType == "ghost_shark" then
        return Battle.GhostSharkAct(state, enemy)
    end

    -- === 棘刺海葵: 远程攻击 + 保持距离 ===
    if enemy.enemyType == "spine_anemone" then
        return Battle.SpineAnemoneAct(state, enemy)
    end

    -- === 射水鱼: 远程攻击 + 逃跑 ===
    if enemy.enemyType == "archerfish" then
        return Battle.ArcherfishAct(state, enemy)
    end

    -- === 电鳐: 近战AOE放电 ===
    if enemy.enemyType == "electric_ray" then
        return Battle.ElectricRayAct(state, enemy)
    end

    -- === 珊瑚祭司: 治疗/增益友军 ===
    if enemy.enemyType == "coral_priest" then
        return Battle.CoralPriestAct(state, enemy)
    end

    -- === 裂变海胆: 普通近战，分裂逻辑在跳跃伤害处处理 ===
    if enemy.enemyType == "splitting_urchin" then
        -- 近战行为与普通敌人相同，直接走下方通用逻辑
    end

    -- === 疾梭鱼: 每回合最多移动3格 ===
    if enemy.enemyType == "swift_barracuda" then
        return Battle.SwiftBarracudaAct(state, enemy)
    end

    -- === 魅惑水母: 普通近战，魅惑由 ProcessEnemyTurn 统一处理 ===
    if enemy.enemyType == "charm_jelly" then
        return Battle.CharmJellyAct(state, enemy)
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
        local actualDmg = math.max(1, enemy.atk - targetDef)

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

                    if thornsLv >= 3 then
                        local heal = math.min(math.floor(thornsDmg * 0.5), hero.maxHp - hero.hp)
                        if heal > 0 then
                            hero.hp = hero.hp + heal
                            Battle.AddFloatingText(state, hero.col, hero.row,
                                "+" .. heal .. "🩸", {200, 50, 50, 255})
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
        local actualDmg = math.max(1, enemy.atk - targetDef)

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
        local actualDmg = math.max(1, enemy.atk - targetDef)

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
        local actualDmg = math.max(1, enemy.atk - targetDef)

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
        local actualDmg = math.max(1, enemy.atk - targetDef)

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
        local actualDmg = math.max(1, enemy.atk - def)
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
        local actualDmg = math.max(1, enemy.atk - targetDef)

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
        local actualDmg = math.max(1, enemy.atk - targetDef)

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

-- ============================================================================
-- 辅助
-- ============================================================================


-- ============================================================================
-- Boss AI（委托子模块）
-- ============================================================================
local BattleBoss = require "BattleBoss"

local function _initBattleBoss()
    Battle.SetBossNextSkill      = BattleBoss.SetBossNextSkill
    Battle.AddBossSkillAnnounce  = BattleBoss.AddBossSkillAnnounce
    Battle.BossAct               = BattleBoss.BossAct
    Battle.BossBasicAttack       = BattleBoss.BossBasicAttack
    Battle.BossMoveToHero        = BattleBoss.BossMoveToHero
    Battle.BossEnrageCheck       = BattleBoss.BossEnrageCheck
    Battle.BossAct_ShadowKnight  = BattleBoss.BossAct_ShadowKnight
    Battle.BossAct_LavaLord      = BattleBoss.BossAct_LavaLord
    Battle.BossAct_AbyssKraken   = BattleBoss.BossAct_AbyssKraken
    Battle.BossAct_CoralGuardian = BattleBoss.BossAct_CoralGuardian
    Battle.ApplyBossDamage       = BattleBoss.ApplyBossDamage
end
_initBattleBoss()

return Battle
