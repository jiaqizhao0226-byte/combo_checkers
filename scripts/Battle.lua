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
-- 伤害计算
-- ============================================================================

--- 计算敌人对目标的实际伤害（防御减免 + 最低伤害保底）
--- 防御不能完全挡住伤害，至少造成 ATK 的 25%
---@param atk number 攻击力
---@param def number 防御力
---@return number actualDmg
function Battle.CalcEnemyDmg(atk, def)
    -- 抗性公式: 减伤率 = def/(def+100), 实际伤害 = atk * 100/(def+100)
    -- def=0 → 0%减伤, def=100 → 50%减伤, def=200 → 66.7%减伤
    local d = def or 0
    local reduction = d / (d + 100)
    local dmg = math.ceil(atk * (1 - reduction))
    -- 厄运轮盘: 脆弱诅咒期间承伤+30%
    if G and G.battle and G.battle.doomDamageTakenTurns and G.battle.doomDamageTakenTurns > 0 then
        dmg = math.ceil(dmg * 1.3)
    end
    return math.max(1, dmg)  -- 最低保底1点伤害
end

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
    [0] = "虚空试炼",   -- 特殊模式：在第1章左边（菜单导航用）
    [1] = "深渊海沟",
    [2] = "烈焰山脉",
    [3] = "珊瑚迷宫",
    [4] = "流沙荒漠",
    [5] = "永冻绝境 🚧",   -- 第五章：冰原主题（施工中）
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
    -- 第五章: 永冻绝境（冰面滑行）
    [5] = {
        { name = "冰封港湾", icon = "❄️", desc = "极寒入口" },
        { name = "极光海峡", icon = "🌌", desc = "北极光下" },
        { name = "冰晶洞窟", icon = "💎", desc = "水晶深处" },
        { name = "企鹅墓地", icon = "🐧", desc = "故乡遗迹" },
        { name = "霜熊领地", icon = "🐻", desc = "巨兽巢穴" },
        { name = "暴风雪眼", icon = "🌪️", desc = "风暴中心" },
        { name = "冰川裂谷", icon = "🏔️", desc = "千年冰川" },
        { name = "永冻核心", icon = "🧊", desc = "寒气源头" },
        { name = "霸主前厅", icon = "👑", desc = "最终考验" },
        { name = "永冻王座", icon = "⚔️", desc = "决战永冻之王" },
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
    lava_lord       = "image/boss_lava_lord_normal_20260424093454.png",
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
    local bossHpScale = 1.0 + 0.25 * (chapter - 1)
    local bossAtkScale = 1.0 + 0.18 * (chapter - 1)
    boss.hp = math.floor(boss.hp * bossHpScale)
    boss.maxHp = boss.hp
    boss.atk = math.floor(boss.atk * bossAtkScale)
    boss.shieldMax = math.floor(boss.shieldMax * bossHpScale)
    HexGrid.AddPiece(board, boss)
    state.boss = boss

    -- Boss 入场公告
    local bossIcons = {
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
    local bossHpScaleM = 1.0 + 0.20 * (chapter - 1)
    local bossAtkScaleM = 1.0 + 0.15 * (chapter - 1)

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
    placeMinionsForTest(state, { "jellyfish", "iron_turtle", "vortex_eel", "archerfish", "electric_ray" }, 5, 1, usedPositions)

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

-- ============================================================================
-- 道具系统测试关卡：棋盘上摆放所有种类道具供逐个拾取测试
-- ============================================================================
function Battle.GenerateTestLevel_Items(state)
    state.level = 1
    state.testMode = "items"
    local board = state.board

    board.pieces      = {}
    board.obstacles   = {}
    board.items       = {}
    board.poisonTiles = {}
    board.wards       = {}
    board.frostTiles  = {}

    HexGrid.ResetToHexagon()
    board.cols = HexGrid.COLS
    board.rows = HexGrid.ROWS

    state.kills          = 0
    state.killTarget     = 999
    state.comboKillCount = 0
    state.comboAtkBonus  = 0
    state.boss           = nil

    -- 英雄放在棋盘中心
    local heroCol = HexGrid.CENTER_COL
    local heroRow = HexGrid.CENTER_ROW
    if not state.hero then
        state.hero = Battle.CreatePiece(HERO_TEMPLATE, heroCol, heroRow)
        local bs = state.bonusStats or {}
        state.hero.atk   = math.floor(state.hero.atk  + (bs.atk or 0))
        state.hero.def   = math.floor(state.hero.def  + (bs.def or 0))
        state.hero.hp    = math.floor(state.hero.hp   + (bs.hp  or 0))
        state.hero.maxHp = math.floor(state.hero.maxHp + (bs.hp or 0))
    else
        state.hero.col = heroCol
        state.hero.row = heroRow
    end
    -- 让英雄掉一些血，方便测试回复道具
    state.hero.hp = math.max(1, math.floor(state.hero.maxHp * 0.4))

    if G.playerData then
        state.critRate  = PlayerData.GetCritRate(G.playerData)
        state.goldBonus = PlayerData.GetGoldBonus(G.playerData)
        state.setEffects = SetEffects.Init(G.playerData.equipment, state.critRate)
    end

    HexGrid.AddPiece(board, state.hero)

    -- 道具测试布局：靶子在英雄相邻格，道具在跳过靶子后的落点上
    -- 英雄(5,5) → 跳过靶子(相邻) → 落在道具格(距离2)
    -- 六方向对应的 靶子位置 和 落点位置:
    --   方向右:     英雄(5,5) → 靶子(6,5) → 落点(7,5)
    --   方向左:     英雄(5,5) → 靶子(4,5) → 落点(3,5)
    --   方向右上:   英雄(5,5) → 靶子(5,4) → 落点(5,3)
    --   方向左上:   英雄(5,5) → 靶子(4,4) → 落点(4,3)
    --   方向右下:   英雄(5,5) → 靶子(5,6) → 落点(5,7)
    --   方向左下:   英雄(5,5) → 靶子(4,6) → 落点(4,7)
    local itemPlacements = {
        { col = 7, row = 5, type = "lucky_wheel" },   -- 跳过右侧靶子(6,5)后落地
        { col = 3, row = 5, type = "doom_wheel" },    -- 跳过左侧靶子(4,5)后落地
        { col = 6, row = 3, type = "health_potion" }, -- 跳过右上靶子(5,4)后落地 (cube: 2*enemy-hero)
        { col = 4, row = 3, type = "gold_bag" },      -- 跳过左上靶子(4,4)后落地
        { col = 6, row = 7, type = "lucky_wheel" },   -- 跳过右下靶子(5,6)后落地 (cube: 2*enemy-hero)
        { col = 4, row = 7, type = "shield" },        -- 跳过左下靶子(4,6)后落地
    }

    for _, item in ipairs(itemPlacements) do
        if HexGrid.InBounds(item.col, item.row) then
            HexGrid.AddItem(board, { col = item.col, row = item.row, type = item.type })
        end
    end

    -- 靶子放在英雄相邻格（英雄可以跳过它们）
    local weakTemplate = {
        team = "enemy", enemyType = "slime",
        hp = 80, maxHp = 80, atk = 3, attackRange = 1,
        attackLabel = "轻击", name = "靶子",
    }
    local enemyPositions = {
        { col = 6, row = 5 },  -- 右
        { col = 4, row = 5 },  -- 左
        { col = 5, row = 4 },  -- 右上
        { col = 4, row = 4 },  -- 左上
        { col = 5, row = 6 },  -- 右下
        { col = 4, row = 6 },  -- 左下
    }
    for _, pos in ipairs(enemyPositions) do
        if HexGrid.InBounds(pos.col, pos.row) then
            HexGrid.AddPiece(board, Battle.CreatePiece(weakTemplate, pos.col, pos.row))
        end
    end

    Battle.AddLog(state, "=== 🎒 道具系统测试关卡 ===")
    Battle.AddLog(state, "棋盘中央有各种道具，走过去拾取测试效果")
    Battle.AddLog(state, "道具: 小血瓶/大血瓶/金币袋/护盾/幸运轮盘/厄运轮盘")
    Battle.AddLog(state, "四角放了靶子(HP80)用于测试灭霸响指等需要敌人的效果")
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

--- 战意增幅: 计算全技能伤害加成倍率
--- @param state table 战斗状态
--- @return number 倍率 (>=1.0)
function Battle.GetDamageAmpMultiplier(state)
    local ampLv = Skills.Level(state.skills, "damage_amp")
    if ampLv < 1 then return 1.0 end
    local basePct = 5 + ampLv * 3  -- Lv1=8%, Lv2=11%, ..., Lv5=20%
    local totalPct = basePct
    -- Lv3+: 连跳>=4时额外+8%
    if ampLv >= 3 and state.combo >= 4 then
        totalPct = totalPct + 8
    end
    -- Lv5: 击杀叠加(最多+12%,战斗结束重置)
    if ampLv >= 5 then
        local killStack = state._damageAmpKillStack or 0
        totalPct = totalPct + killStack
    end
    return 1.0 + totalPct / 100
end

--- 战意增幅: 应用伤害加成（带浮动文字提示，仅首次显示/大倍率时显示）
--- @param state table 战斗状态
--- @param damage number 原始伤害
--- @param col number|nil 浮动文字位置列
--- @param row number|nil 浮动文字位置行
--- @return number 增幅后的伤害
function Battle.ApplyDamageAmp(state, damage, col, row)
    if damage <= 0 then return damage end
    local mult = Battle.GetDamageAmpMultiplier(state)
    if mult <= 1.0 then return damage end
    local newDmg = math.floor(damage * mult)
    return newDmg
end

--- 战意增幅Lv5: 击杀时叠加伤害(最多+12%)
--- @param state table 战斗状态
--- @param enemy table|nil 被击杀的敌人（用于特效定位，可选）
function Battle.OnKillDamageAmpStack(state, enemy)
    local ampLv = Skills.Level(state.skills, "damage_amp")
    if ampLv >= 5 then
        local stack = state._damageAmpKillStack or 0
        if stack < 12 then
            state._damageAmpKillStack = stack + 3  -- 每次击杀+3%, 4次到顶(+12%)
            -- 战意叠加红色反馈
            if enemy then
                Battle.AddFloatingText(state, enemy.col, enemy.row,
                    "💪战意+3%", {255, 90, 90, 255})
            end
            AM.PlaySFX("attack_hit", 0.7, 1.3)
            -- 叠满(+12%)时在英雄身上爆发红色战意光环
            if state._damageAmpKillStack >= 12 and not state._damageAmpMaxNoticed then
                state._damageAmpMaxNoticed = true
                local hero = state.hero
                if hero then
                    Battle.AddFloatingText(state, hero.col, hero.row,
                        "💪战意巅峰!", {255, 60, 60, 255}, "combo")
                    Battle.AddVFX(state, "boss_enrage", {
                        col = hero.col, row = hero.row,
                        bossColor = {255, 60, 60},
                        duration = 0.8,
                    })
                    AM.PlaySFX("boss_entrance", 0.9, 1.2)
                end
            end
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
--- 第四章: 呼唤风沙持续伤害（每敌方回合开始调用）
--- 每回合对英雄造成全场AOE伤害，持续回合数递减
function Battle.ProcessSandFury(state)
    if not state.sandFuryActive then return end
    local hero = state.hero
    local dmg = state.sandFuryDmg or 8
    hero.hp = hero.hp - dmg
    Battle.AddFloatingText(state, hero.col, hero.row,
        "🌪️-" .. dmg .. "风沙!", {230, 160, 50, 255}, "hit")
    state.screenShake = (state.screenShake or 0) + 0.2
    Battle.AddLog(state, string.format("风沙肆虐！英雄受到 %d 伤害！(剩余%d回合)", dmg, state.sandFuryTurns))
    -- VFX: 全场风沙粒子（每回合触发）
    Battle.AddVFX(state, "sand_fury_tick", {
        col = hero.col, row = hero.row, duration = 0.8,
    })
    -- 回合递减
    state.sandFuryTurns = state.sandFuryTurns - 1
    if state.sandFuryTurns <= 0 then
        state.sandFuryActive = false
        state.sandFuryTurns = nil
        state.sandFuryDmg = nil
        state.sandFuryBoss = nil
        Battle.AddFloatingText(state, hero.col, hero.row,
            "🌪️风沙消散", {180, 160, 100, 255})
        Battle.AddLog(state, "风沙逐渐平息...")
    end
end

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
    -- 停沙格一旦生成就永久存在于棋盘上，不随流沙消散而消失
    -- （仅在玩家踩上时才触发效果并消除）
end

function Battle.GetActiveAltarCount(board)
    local count = 0
    for _, alt in ipairs(board.altars) do
        if alt.active then count = count + 1 end
    end
    return count
end

--- 生成指定关卡

-- Level generation & spawning (delegated to submodule)
require("BattleSpawn")(Battle)

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

    -- 第五章冰块：企鹅移动到冰块边时，会沿本次移动方向把冰块推出去
    -- 示意：旧位置 A -> 新位置 B -> 冰块 C，冰块从 C 继续向前飞出，清掉路径上的小怪。
    if Battle.GetChapterInfo(state.level) == 5 then
        local dx, dy, dz = HexGrid.OffsetToCube(targetCol, targetRow)
        local ox, oy, oz = HexGrid.OffsetToCube(oldCol, oldRow)
        local dirX, dirY, dirZ = dx - ox, dy - oy, dz - oz
        local dist = math.max(math.abs(dirX), math.abs(dirY), math.abs(dirZ))
        if dist == 1 then
            local blockCol, blockRow = HexGrid.CubeToOffset(dx + dirX, dy + dirY, dz + dirZ)
            local obs = HexGrid.GetObstacleAt(state.board, blockCol, blockRow)
            if obs and obs.type == "ice_block" then
                local IceMechanic = require "IceMechanic"
                IceMechanic.PushIceBlock(state, Battle, blockCol, blockRow, targetCol, targetRow)
            end
        end
    end

    -- 简单移动不触发震地落（只有跳跃最终落点才触发）

    -- 踏步斩: 移动时对最近敌人发起近战攻击
    local stepStrikeLv = Skills.Level(state.skills, "step_strike")
    if stepStrikeLv >= 1 then
        local ssBaseDmg  = 5 + stepStrikeLv * 5     -- 保底伤害(Boss/未达斩杀线时)
        local ssExecPct  = math.min(100, 30 + stepStrikeLv * 14)  -- 斩杀血量线: Lv1=44%,Lv2=58%,Lv3=72%,Lv4=86%,Lv5=100%
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
                local hpPct   = target.hp / (target.maxHp or target.hp) * 100
                -- 斩杀判定: 非Boss且血量百分比 <= 斩杀线 → 直接处决
                if not target.isBoss and hpPct <= ssExecPct then
                    local overkill = target.hp
                    target.hp = 0
                    state.totalDamage = state.totalDamage + overkill
                    target.hitFlash = 0.15
                    Battle.AddVFX(state, "step_strike_slash", {
                        col = target.col, row = target.row,
                        fromCol = targetCol, fromRow = targetRow,
                        duration = 0.6, isExecute = true,
                    })
                    Battle.AddFloatingText(state, target.col, target.row,
                        "⚔斩杀", {255, 80, 30, 255}, "hit", 0.8)
                    AM.PlaySFX("attack_hit", 1.1, 0.8)
                    Battle.HandleEnemyDeath(state, target, false)
                else
                    -- 保底近战伤害(Boss/高血敌人)
                    local actualDmg = Battle.ApplyAltarReduction(state, target, ssBaseDmg)
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

    -- 检查停沙格
    Battle.CheckSandStopTile(state, targetCol, targetRow)

    -- 检查冰弹陷阱
    Battle.CheckIceTrap(state, targetCol, targetRow)
end

--- 检查英雄是否踩到冰弹陷阱（暴风雪鹰投下的AOE持续伤害区域）
function Battle.CheckIceTrap(state, col, row)
    if not state._iceTraps then return end
    local hero = state.hero
    for _, trap in ipairs(state._iceTraps) do
        if trap.col == col and trap.row == row and trap.turnsLeft > 0 then
            local dmg = trap.damage or 12
            if state.hasShield then
                dmg = math.floor(dmg / 2)
                state.hasShield = false
                Battle.AddFloatingText(state, hero.col, hero.row, "🛡️挡!", {120, 180, 255, 255})
            end
            if (hero._shield or 0) > 0 and dmg > 0 then
                local absorbed = math.min(hero._shield, dmg)
                dmg = dmg - absorbed
                hero._shield = hero._shield - absorbed
            end
            hero.hp = hero.hp - dmg
            state.hitFlash = 0.25
            state.screenShake = (state.screenShake or 0) + 0.15
            Battle.AddFloatingText(state, col, row,
                "🦅陷阱-" .. dmg, {140, 200, 255, 255}, "hit")
            Battle.AddLog(state, string.format("踩到冰弹陷阱！受到%d伤害", dmg))
            local AM = require "AudioManager"
            AM.PlaySFX("hero_damage", 0.7, 1.3)
            break  -- 同格只触发一次
        end
    end
end

--- 每回合开始递减冰弹陷阱倒计时，到期清除
function Battle.TickIceTraps(state)
    if not state._iceTraps then return end
    for i = #state._iceTraps, 1, -1 do
        state._iceTraps[i].turnsLeft = state._iceTraps[i].turnsLeft - 1
        if state._iceTraps[i].turnsLeft <= 0 then
            table.remove(state._iceTraps, i)
        end
    end
end

--- 执行跳跃 (跳过敌人造成伤害, 或跳过岩石不造成伤害)
---@param isLastStep boolean 是否是连跳的最后一步（只有最后一步触发震地落等落地技能）
---@return table|nil 被攻击的敌人(岩石跳跃返回nil)
function Battle.ExecuteJump(state, jumpInfo, isLastStep)
    local hero = state.hero
    state._isKingmakerJump = nil  -- 重置棋步跳标记

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

        if jumpInfo.isScarecrowJump then
            -- 稻草人跳：显示专属文字
            local comboText = state.combo >= 2
                and string.format("🎃跳! %dx", state.combo)
                or "🎃跳!"
            Battle.AddFloatingText(state, jumpInfo.jumpedCol, jumpInfo.jumpedRow,
                comboText, {255, 180, 80, 255})
            Battle.AddLog(state, string.format("跳过稻草人到 (%d,%d)", jumpInfo.col, jumpInfo.row))
        elseif isShellJump then
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
        Battle.CheckSandStopTile(state, jumpInfo.col, jumpInfo.row)
        return nil
    end

    -- === 敌人跳跃: 正常伤害流程 ===
    local enemy = jumpInfo.enemy

    -- Combo 递增
    state.combo = state.combo + 1
    if state.combo > state.maxCombo then
        state.maxCombo = state.combo
    end

    -- === 棋步: 有效跳跃计数（每轮combo chain只算1次，第一跳时计数） ===
    local kmLv = Skills.Level(state.skills, "kingmaker")
    if kmLv >= 1 and state.combo == 1 then
        state._kingmakerCount = (state._kingmakerCount or 0) + 1
        -- 计算间隔: Lv1=7, Lv2=6, Lv3=5, Lv4=4, Lv5=4
        local kmInterval
        if kmLv <= 3 then
            kmInterval = 8 - kmLv  -- Lv1=7, Lv2=6, Lv3=5
        else
            kmInterval = 5 - math.floor((kmLv - 3) / 2)  -- Lv4=4, Lv5=4
        end
        if state._kingmakerCount >= kmInterval then
            state._kingmakerReady = true
            state._kingmakerJustTriggered = true  -- 本跳刚触发，不在本跳消耗
            state._kingmakerCount = 0
            Battle.AddFloatingText(state, state.hero.col, state.hero.row,
                "♟棋步就绪!", {220, 180, 60, 255}, "combo")
            Battle.AddLog(state, "♟ 棋步就绪！下次跳跃可到达任意位置！")
        end
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

    -- === 寂灭之路: 连跳经过的敌人被沉默 ===
    local silenceLv = Skills.Level(state.skills, "silence_path")
    if silenceLv >= 1 then
        local silenceTurns = 1 + math.floor(silenceLv / 2)  -- Lv1=1, Lv2=2, Lv3=2, Lv4=3, Lv5=3
        local silenceRange = silenceLv >= 4 and 2 or 1       -- Lv4+: 路径周围2格
        -- 对被跳过的敌人施加沉默
        if not enemy._silencedTurns or enemy._silencedTurns < silenceTurns then
            enemy._silencedTurns = silenceTurns
            Battle.AddFloatingText(state, jumpInfo.jumpedCol, jumpInfo.jumpedRow,
                "🤐沉默" .. silenceTurns .. "回合", {100, 60, 160, 255})
            -- 紫色封印魔法阵特效 + 封印音效
            Battle.AddVFX(state, "coral_seal_ring", {
                col = jumpInfo.jumpedCol, row = jumpInfo.jumpedRow,
                duration = 0.75,
            })
            AM.PlaySFX("coral_seal_enclosure", 0.9, 1.15)
        end
        -- Lv4+扩展范围: 对路径周围的其他敌人也施加沉默
        if silenceRange >= 2 then
            local nearEnemies = HexGrid.GetNeighbors(jumpInfo.jumpedCol, jumpInfo.jumpedRow)
            for _, n in ipairs(nearEnemies) do
                local nearby = HexGrid.GetPieceAt(state.board, n.col, n.row)
                if nearby and nearby.team == "enemy" and nearby ~= enemy and nearby.hp > 0 then
                    if not nearby._silencedTurns or nearby._silencedTurns < silenceTurns then
                        nearby._silencedTurns = silenceTurns
                        Battle.AddFloatingText(state, n.col, n.row,
                            "🤐沉默", {100, 60, 160, 200})
                        -- 扩散目标也升起封印魔法阵（稍短，营造涟漪感）
                        Battle.AddVFX(state, "coral_seal_ring", {
                            col = n.col, row = n.row,
                            duration = 0.6,
                        })
                    end
                end
            end
        end
    end

    -- 计算伤害: ATK × (1.0 + (combo-1) × multiplierRate)
    local baseDmg = hero.atk + state.comboAtkBonus
    -- 厄运轮盘: 力量枯竭期间输出-30%
    if state.doomOutputDownTurns and state.doomOutputDownTurns > 0 then
        baseDmg = math.ceil(baseDmg * 0.7)
    end
    -- 幸运轮盘: 战意高涨期间输出+30%
    if state.luckyAtkUpTurns and state.luckyAtkUpTurns > 0 then
        baseDmg = math.ceil(baseDmg * 1.3)
    end

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
    -- === 组合技·焚身狂战: 血怒期间跳杀附加 ATK×40% 真伤 ===
    local burningRageBonus = 0
    if Skills.HasCombo(state.skills, "combo_burning_rage") then
        local brRageLv = Skills.Level(state.skills, "blood_rage")
        local brThresh = brRageLv >= 5 and 0.3 or 0.5
        if brRageLv >= 1 and hero.hp < hero.maxHp * brThresh then
            burningRageBonus = math.floor(hero.atk * 0.4)
        end
    end
    -- 重力践踏/震地落Lv4/吸血跳Lv3/蓄势Lv3: combo≥3 基伤翻倍
    local gravLv = Skills.Level(state.skills, "gravity_stomp")
    local hasGravity = gravLv >= 1
        or Skills.Level(state.skills, "quake_land") >= 4
        or Skills.Level(state.skills, "vampiric_jump") >= 3
    if hasGravity and state.combo >= 3 then
        local bonus = 50 + gravLv * 22  -- Lv0=50%, Lv1=72%, ..., Lv5=160%（削减,保留Lv0基线不误伤震地落/吸血跳借用）
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
    -- === 组合技·焚身狂战: 附加真伤(无视DEF) ===
    if burningRageBonus > 0 then
        damage = damage + burningRageBonus
        Battle.AddFloatingText(state, jumpInfo.jumpedCol, jumpInfo.jumpedRow,
            "+" .. burningRageBonus .. "🔥焚身", {255, 80, 20, 255})
    end

    -- 猎手印记: 对标记敌人额外伤害
    local markLv = Skills.Level(state.skills, "hunter_mark")
    if markLv >= 1 and enemy._hunterMarked then
        local markBonus = (20 + markLv * 5) / 100  -- Lv1=+25%, ..., Lv5=+45%（削减）
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

    -- === 冰霜印记Lv5: 冻结中的敌人受伤+30% ===
    local frostLv = Skills.Level(state.skills, "frost_mark")
    if frostLv >= 5 and enemy._frozenTurns and enemy._frozenTurns > 0 then
        damage = math.floor(damage * 1.3)
        Battle.AddFloatingText(state, jumpInfo.jumpedCol, jumpInfo.jumpedRow,
            "❄+30%", {100, 200, 255, 255})
    end

    -- === 棋步: 消耗棋步状态并应用伤害加成 ===
    if state._kingmakerJustTriggered then
        -- 本跳刚触发棋步就绪，不消耗，等下次跳跃
        state._kingmakerJustTriggered = nil
    elseif state._kingmakerReady and jumpInfo.isKingmaker then
        state._kingmakerReady = false
        state._isKingmakerJump = true  -- 标记本次为棋步跳（用于后续逻辑）
        local kmLv2 = Skills.Level(state.skills, "kingmaker")
        -- Lv3+: 棋步跳伤害+20%
        if kmLv2 >= 3 then
            damage = math.floor(damage * 1.2)
            Battle.AddFloatingText(state, jumpInfo.jumpedCol, jumpInfo.jumpedRow,
                "♟+20%", {220, 180, 60, 255})
        end
        -- Lv5: 棋步跳无视防御（额外加回被扣除的DEF部分）
        if kmLv2 >= 5 and (enemy.def or 0) > 0 then
            local defBonus = enemy.def
            damage = damage + defBonus
            Battle.AddFloatingText(state, jumpInfo.jumpedCol, jumpInfo.jumpedRow,
                "♟破防+" .. defBonus, {255, 220, 60, 255})
        end
        Battle.AddFloatingText(state, jumpInfo.col, jumpInfo.row,
            "♟棋步!", {220, 180, 60, 255}, "combo")
        AM.PlaySFX("kingmaker_jump", 1.8, 1.15)
        Battle.AddVFX(state, "kingmaker_burst", {col = jumpInfo.col, row = jumpInfo.row, duration = 0.7})
    end

    -- === 战意增幅: 全技能伤害加成 ===
    damage = Battle.ApplyDamageAmp(state, damage, jumpInfo.jumpedCol, jumpInfo.jumpedRow)
    -- Lv3+: 连跳刚达到4时提示"战意爆发"（只在阈值那一跳显示，避免刷屏）
    do
        local ampLv = Skills.Level(state.skills, "damage_amp")
        if ampLv >= 3 and state.combo == 4 then
            Battle.AddFloatingText(state, jumpInfo.jumpedCol, jumpInfo.jumpedRow,
                "💪战意爆发+8%", {255, 110, 90, 255})
            AM.PlaySFX("step_strike", 0.7, 1.25)
        end
    end

    -- === 寂灭之路Lv3: 被沉默敌人受伤+15% ===
    if enemy._silencedTurns and enemy._silencedTurns > 0 then
        local spLv = Skills.Level(state.skills, "silence_path")
        if spLv >= 3 then
            damage = math.floor(damage * 1.15)
            Battle.AddFloatingText(state, jumpInfo.jumpedCol, jumpInfo.jumpedRow,
                "🤐+15%", {100, 60, 160, 255})
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
    -- 蓄怒冰熊：被跳过时+1怒气
    if enemy.rageable and damage > 0 then
        enemy._bearRage = (enemy._bearRage or 0) + 1
        Battle.AddFloatingText(state, enemy.col, enemy.row,
            "💢" .. enemy._bearRage .. "/3", {255, 150, 80, 255}, nil, 0.7)
        if enemy._bearRage >= 3 then
            Battle.AddFloatingText(state, enemy.col, enemy.row,
                "🐻怒气满！", {255, 80, 40, 255}, "combo", 1.0)
            Battle.AddLog(state, "🐻 蓄怒冰熊怒气爆满！下回合将冲锋！")
        end
    end
    -- 打击音效随combo递进：音调升高+音量加大，打击感更强（棋步跳有专属音效，跳过通用音效）
    if not state._isKingmakerJump then
        local hitGain = math.min(1.0 + state.combo * 0.06, 1.5)
        local hitPitch = 1.0 + math.min(state.combo, 8) * 0.03
        AM.PlaySFX("attack_hit", hitGain, hitPitch)
    end

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

    -- === 沙丘巨虫: 从虫体(头/身躯)上跳过会被尖刺利齿反伤 ===
    if enemy.bossType == "sand_worm" or enemy.bossType == "sand_worm_body" then
        local wormHead = enemy.snakeHead or enemy   -- 身体段伤害路由到头部，头部本身即自己
        if not wormHead.burrowed then               -- 遁地状态虫体不在场，不反伤
            local wormDmg = math.max(5, math.floor((wormHead.atk or 38) * 0.4))  -- 约 atk×40%
            -- 护盾吸收反伤
            local shieldAbs = math.min(hero._shield or 0, wormDmg)
            if shieldAbs > 0 then
                hero._shield = hero._shield - shieldAbs
                wormDmg = wormDmg - shieldAbs
            end
            if wormDmg > 0 then
                hero.hp = hero.hp - wormDmg
                Battle.AddFloatingText(state, hero.col, hero.row,
                    "🪱虫体-" .. wormDmg, {200, 120, 40, 255})
                Battle.AddLog(state, "踏过沙虫躯体，受到虫体反伤！")
                AM.PlaySFX("hero_damage", 0.8)
            elseif shieldAbs > 0 then
                -- 护盾完全吸收，不显示 -0、不播受伤音
                Battle.AddFloatingText(state, hero.col, hero.row,
                    "🛡️护盾抵挡", {120, 200, 255, 255})
                Battle.AddLog(state, "护盾抵挡了沙虫反伤！")
            end
        end
    end

    -- === 沙漠响尾蛇: 被攻击后进入狂怒 ===
    if enemy.enemyType == "sand_rattler" and damage > 0 and enemy.hp > 0 then
        if not enemy._enraged then
            enemy._enraged = true
            Battle.AddFloatingText(state, enemy.col, enemy.row,
                "🐍狂怒!", {255, 80, 40, 255})
            Battle.AddLog(state, enemy.name .. " 被激怒了！下回合攻击力翻倍！")
        end
    end

    -- === 冰霜印记: 攻击叠加冰霜层数，满层冻结 ===
    if damage > 0 and enemy.hp > 0 then
        local frostMarkLv = Skills.Level(state.skills, "frost_mark")
        if frostMarkLv >= 1 then
            -- 计算冻结所需层数: Lv1=4, Lv2=3, Lv3=3, Lv4=2, Lv5=2
            local maxStacks
            if frostMarkLv <= 2 then
                maxStacks = 4 - (frostMarkLv - 1)  -- Lv1=4, Lv2=3
            else
                maxStacks = 3 - math.floor((frostMarkLv - 3) / 2)  -- Lv3=3, Lv4=2, Lv5=2
            end
            -- 叠加层数
            enemy._frostStacks = (enemy._frostStacks or 0) + 1
            Battle.AddFloatingText(state, enemy.col, enemy.row,
                "❄" .. enemy._frostStacks .. "/" .. maxStacks, {100, 200, 255, 255})
            -- 达到阈值：冻结
            if enemy._frostStacks >= maxStacks then
                enemy._frostStacks = 0  -- 重置层数
                local freezeDur = frostMarkLv >= 3 and 2 or 1
                enemy._frozenTurns = (enemy._frozenTurns or 0) + freezeDur
                Battle.AddFloatingText(state, enemy.col, enemy.row,
                    "❄冻结!" .. freezeDur .. "回合", {80, 180, 255, 255}, "combo")
                Battle.AddLog(state, string.format("❄ %s 被冰霜印记冻结%d回合！", enemy.name, freezeDur))
                AM.PlaySFX("frost_freeze", 1.0, 1.0)
            end
        end
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
            -- 7连跳以上使用金紫色特效，低于7连使用蓝色
            local shieldColor
            if state.combo >= 7 then
                shieldColor = {255, 180, 60, 255}    -- 金色（7连+高阶）
            else
                shieldColor = {60, 160, 220, 255}    -- 蓝色（常规）
            end
            Battle.AddFloatingText(state, jumpInfo.col, jumpInfo.row,
                string.format("🛡+%d(%d)", actualGain, newShield), shieldColor)
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

    -- 组合技: 猎杀本能 — 全屏HP≤20%小怪直接处决，每次回复10HP
    if Skills.HasCombo(state.skills, "combo_hunter_instinct") then
        local allEnemies = HexGrid.GetTeamPieces(state.board, "enemy")
        for _, e in ipairs(allEnemies) do
            if e.hp > 0 and not e.isBoss then
                local hpPct = e.hp / (e.maxHp or e.hp)
                if hpPct <= 0.20 and hpPct > 0 then
                    local overkill = e.hp
                    e.hp = 0
                    state.totalDamage = state.totalDamage + overkill
                    -- 回复10HP
                    local heal = math.min(10, hero.maxHp - hero.hp)
                    if heal > 0 then
                        hero.hp = hero.hp + heal
                        Battle.AddFloatingText(state, hero.col, hero.row,
                            "+" .. heal .. "💀", {100, 255, 100, 255})
                    end
                    -- 处决文字：用专属样式，更慢更大更显眼
                    Battle.AddFloatingText(state, e.col, e.row,
                        "💀 处决", {255, 50, 10, 255}, "execution", 2.5)
                    -- 处决专属特效
                    Battle.AddVFX(state, "execution", {
                        col = e.col, row = e.row, duration = 1.2,
                    })
                    Battle.AddLog(state, "💀 猎杀本能！处决 " .. e.name .. "，回复" .. heal .. "HP")
                    AM.PlaySFX("lightning", 1.0, 0.7)
                    state.screenShake = (state.screenShake or 0) + 0.4
                    Battle.HandleEnemyDeath(state, e, true)
                end
            end
        end
    end

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

    -- 检查停沙格
    Battle.CheckSandStopTile(state, jumpInfo.col, jumpInfo.row)

    -- 地刺陷阱: 在跳跃出发位置周围放置地刺
    Battle.PlaceSpikeTraps(state, jumpFromCol, jumpFromRow)

    -- === 第五章: 冰面滑行（延迟执行，等跳跃动画播完后再滑行）===
    if isLastStep then
        local IceMechanic = require "IceMechanic"
        if IceMechanic.IsIceTile(state, jumpInfo.col, jumpInfo.row) then
            local dirFromCol = jumpInfo.jumpedCol or jumpFromCol
            local dirFromRow = jumpInfo.jumpedRow or jumpFromRow
            -- 预计算滑行结果，标记为待执行
            local slideResult = IceMechanic.CalcSlide(state, jumpInfo.col, jumpInfo.row, dirFromCol, dirFromRow)
            if slideResult then
                state._pendingIceSlide = {
                    landCol = jumpInfo.col, landRow = jumpInfo.row,
                    dirFromCol = dirFromCol, dirFromRow = dirFromRow,
                    result = slideResult,
                }
            end
        end
    end

    -- 连击奖励已移至 TurnFlow.FinishExecution（落地后触发）

    return enemy
end

--- 落地效果主体: 震地落(T1) / 天崩地裂(T2) / 地震连锁(T2) / 基础移动冲击
--- 注意: 各分支会提前 return，连锁释放的处理已移到外层 ApplyLandingSkills 包装函数
function Battle.DoLandingEffect(state, col, row)
    local quakeLv = Skills.Level(state.skills, "quake_land")
    local hasQuake = quakeLv >= 1
    local hasCataclysm = quakeLv >= 4     -- Lv4: combo≥3全场AOE
    local hasSeismic = quakeLv >= 3        -- Lv3: 2圈范围+闪电弹射

    -- 基础移动冲击: 即使没有震地落技能，移动也对周围敌人造成伤害（基于ATK的40%）
    if not hasQuake and not hasCataclysm and not hasSeismic then
        local hero = state.hero
        local baseDmg = math.max(5, math.floor(hero.atk * 0.4))
        baseDmg = Battle.ApplyDamageAmp(state, baseDmg)  -- 战意增幅
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

    -- 天崩地裂(T2): combo≥3时全场AOE，伤害12+5×combo
    if hasCataclysm and state.combo >= 3 then
        local aoeDmg = 12 + 5 * state.combo
        aoeDmg = Battle.ApplyDamageAmp(state, aoeDmg)  -- 战意增幅
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

    -- 震地落: 周围AOE (伤害随等级缩放: 10+lv*5)
    local aoeDmg = 10 + quakeLv * 5   -- Lv1=15, Lv2=20, Lv3=25, Lv4=30, Lv5=35（伤害加强）
    aoeDmg = Battle.ApplyDamageAmp(state, aoeDmg)  -- 战意增幅
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

    -- 组合技: 雷震天罚 — 震地落命中敌人50%概率追加闪电(15伤,弹射1次)
    if hit and Skills.HasCombo(state.skills, "combo_thunder_quake") then
        -- 落点雷震光环特效（瞬间爆开，短促有力）
        Battle.AddVFX(state, "combo_thunder_ring", {
            col = state.hero.col, row = state.hero.row,
            duration = 0.9,
        })
        for _, target in ipairs(hitTargets) do
            if target.hp > 0 and math.random() < 0.5 then
                Battle.ApplyChainLightning(state, target, 1, 15)
                -- 闪电延迟 0.3s 出现，形成"先震后电"节奏
                Battle.AddVFX(state, "lightning", {
                    fromCol = state.hero.col, fromRow = state.hero.row,
                    toCol = target.col, toRow = target.row,
                    duration = 0.7,
                    startDelay = 0.25,
                })
                Battle.AddLog(state, "⚡ 雷震天罚！追加闪电击中附近敌人")
            end
        end
    end

    -- 地震连锁(T2): 每个被击中的敌人触发一次闪电弹射
    if hasSeismic then
        for _, target in ipairs(hitTargets) do
            if target.hp > 0 then
                Battle.ApplyChainLightning(state, target, 1)
            end
        end
    end

end

--- 落地完整重演: 连锁释放额外触发时调用，重新结算"落地点"的落地相关效果
--- 包含: 落地AOE(震地落/基础冲击/天崩地裂) + 地刺布置
--- 这样连锁释放不再只依赖震地落——地刺陷阱玩家同样能从额外触发中受益
---@param state table
---@param col integer
---@param row integer
function Battle.DoLandingReplay(state, col, row)
    Battle.DoLandingEffect(state, col, row)    -- 落地AOE（基础冲击/震地落/天崩地裂 + 雷震天罚/地震连锁）
    Battle.PlaceSpikeTraps(state, col, row)     -- 在落地点周围额外布一圈地刺（需地刺陷阱技能）
end

--- 统一落地技能入口: 执行一次正常落地效果
--- 正常流程下地刺由 ExecuteJump 外层单独调用，此处只做落地AOE
function Battle.ApplyLandingSkills(state, col, row)
    Battle.DoLandingEffect(state, col, row)
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
            txt = string.format("🩸+%d 血怒x%d!", totalHeal, stacks)
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

        abyss_kraken = {100, 20, 160}, lava_lord = {255, 100, 0},
        ghost_shark = {100, 140, 200}, spine_anemone = {200, 80, 150},
        coral_priest = {255, 180, 120}, fission_flame = {255, 100, 30}, flame_shard = {255, 160, 60},
        splitting_urchin = {200, 100, 220},
        -- 第五章
        frost_grunt = {140, 200, 240}, aurora_jelly = {180, 120, 255},
        frost_barracuda = {80, 160, 220}, ice_crystal = {200, 230, 255},
        blizzard_hawk = {120, 180, 240}, frost_bear = {160, 200, 230},
    }
    Battle.AddVFX(state, "death_puff", {
        col = enemy.col, row = enemy.row, duration = 0.7,
        enemyColor = deathColors[enemy.enemyType] or {180, 60, 60},
        isBoss = enemy.isBoss or false,
    })
    if not skipDeathSFX then
        AM.PlaySFX("enemy_death")
    end

    -- === 战意增幅Lv5: 击杀叠加伤害 ===
    Battle.OnKillDamageAmpStack(state, enemy)

    -- === 寂灭之路Lv5: 沉默结束时造成固定伤害(击杀时触发残余沉默爆发) ===
    -- (实际沉默到期伤害在 TickSealDebuff 中处理)

    -- === 沙虫头部死亡: 清除所有身体段 + 风沙状态 ===
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
        -- 沙虫死亡：立即解除呼唤风沙
        if state.sandFuryActive then
            state.sandFuryActive = false
            state.sandFuryTurns = nil
            state.sandFuryDmg = nil
            state.sandFuryBoss = nil
            Battle.AddFloatingText(state, enemy.col, enemy.row,
                "🌪️风沙消散!", {180, 160, 100, 255})
            Battle.AddLog(state, "巨虫倒下，风沙随之平息！")
        end
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

    -- === 第五章: 冰锥兵死亡生成冰面格 ===
    if enemy.deathSpawnIce then
        local IceMechanic = require "IceMechanic"
        IceMechanic.AddIceTile(state, enemy.col, enemy.row)
        -- 30%概率扩展到1个相邻空格
        local neighbors = HexGrid.GetNeighbors(enemy.col, enemy.row)
        for _, n in ipairs(neighbors) do
            if math.random(1, 100) <= 30 and HexGrid.InBounds(n.col, n.row) then
                if not HexGrid.GetPieceAt(state.board, n.col, n.row)
                   and not HexGrid.IsBlocked(state.board, n.col, n.row) then
                    IceMechanic.AddIceTile(state, n.col, n.row)
                    break
                end
            end
        end
        Battle.AddFloatingText(state, enemy.col, enemy.row,
            "🧊冰面扩展!", {140, 210, 255, 255})
        Battle.AddLog(state, "冰锥兵倒下，地面凝结成冰！")
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
                -- 应用当前关卡难度缩放（章内关卡号 + 逐章递增）
                local chapter, stageInChapter = Battle.GetChapterInfo(state.level)
                local hpScale, atkScale
                if chapter == 1 then
                    hpScale = 1 + 0.08 * (stageInChapter - 1)
                    atkScale = 1 + 0.05 * (stageInChapter - 1)
                elseif chapter == 2 then
                    hpScale = 1 + 0.16 * (stageInChapter - 1)
                    atkScale = 1 + 0.10 * (stageInChapter - 1)
                elseif chapter == 3 then
                    hpScale = 1 + 0.20 * (stageInChapter - 1)
                    atkScale = 1 + 0.14 * (stageInChapter - 1)
                else
                    hpScale = 1 + 0.25 * (stageInChapter - 1)
                    atkScale = 1 + 0.16 * (stageInChapter - 1)
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

    -- === 第四章: 敌人死亡有概率产生大流沙区（7格，5回合后消失，最多3个） ===
    -- Boss关概率50%，普通关50%
    local ch4 = Battle.GetChapterInfo(state.level)
    local zoneCount = state.board.quicksandZones and #state.board.quicksandZones or 0
    if ch4 == 4 and not enemy.isSegment and not enemy.isBoss and zoneCount < 3 then
        local sandProb = 0.3
        if math.random() < sandProb then
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
                            -- 推到停沙格上也要触发效果
                            Battle.CheckSandStopTile(state, safeCol, safeRow)
                        else
                            Battle.AddFloatingText(state, safeCol, safeRow,
                                "被推开", {180, 150, 80, 200})
                        end
                    end
                end
            end
            -- 流沙区产生后，刷新停沙格
            Battle.SpawnSandStopTile(state)
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

    -- === 组合技·焚身狂战: 血怒期间击杀回复3HP ===
    if Skills.HasCombo(state.skills, "combo_burning_rage") then
        local brRageLv = Skills.Level(state.skills, "blood_rage")
        local brThresh = brRageLv >= 5 and 0.3 or 0.5
        if brRageLv >= 1 and state.hero.hp < state.hero.maxHp * brThresh then
            local heal = math.min(3, state.hero.maxHp - state.hero.hp)
            if heal > 0 then
                state.hero.hp = state.hero.hp + heal
                Battle.AddFloatingText(state, state.hero.col, state.hero.row,
                    "+3🔥狂战", {255, 120, 40, 255})
            end
        end
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
        -- === 组合技·碎片雷区: 碎片落点变地刺(25伤2回合) ===
        -- not isSecondary 防止"地刺射出的碎片"再生成地刺，避免地刺无限增殖
        if not isSecondary and Skills.HasCombo(state.skills, "combo_shard_minefield") then
            if not state._spikeTraps then state._spikeTraps = {} end
            if not Battle.GetSpikeAt(state, target.col, target.row) then
                state._spikeTraps[#state._spikeTraps + 1] = {
                    col = target.col, row = target.row, damage = 25, turns = 2,
                }
                Battle.AddVFX(state, "spike_place", { col = target.col, row = target.row, duration = 0.4 })
            end
        end
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
    local dur = 4 + spikeLv               -- Lv1=5, Lv2=6, Lv3=7, Lv4=8, Lv5=9（持续回合加强）
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
    -- 停沙格也可作为飞镖目标（拾取后清除全场流沙）
    if board.sandStopTile then
        dartTargets[#dartTargets + 1] = { kind = "sandStop", col = board.sandStopTile.col, row = board.sandStopTile.row }
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
        -- === 2连: 飞镖 (飞镖风暴技能: 多枚飞镖) ===
        local dartStormLv = Skills.Level(state.skills, "dart_storm")
        local dartCount = 1 + dartStormLv  -- 无技能=1枚, Lv1=2, Lv2=3, ..., Lv5=6
        local dartBaseDmg = 30 + dartStormLv * 5  -- 无技能=30, Lv1=35, ..., Lv5=55（平衡下调）
        local dartPierce = dartStormLv >= 3  -- Lv3+: 穿透(同一敌人可被多镖命中)
        local dartBurn = dartStormLv >= 5    -- Lv5: 灼烧

        local enemies = HexGrid.GetTeamPieces(board, "enemy")
        local aliveEnemies = {}
        for _, e in ipairs(enemies) do
            if e.hp > 0 then
                aliveEnemies[#aliveEnemies + 1] = e
            end
        end
        -- 收集所有可用目标：敌人 + 道具 + 停沙格
        ---@type table[]
        local dartTargets = {}
        for _, e in ipairs(aliveEnemies) do
            dartTargets[#dartTargets + 1] = { kind = "enemy", obj = e, col = e.col, row = e.row }
        end
        for _, it in ipairs(board.items) do
            dartTargets[#dartTargets + 1] = { kind = "item", obj = it, col = it.col, row = it.row }
        end
        -- 停沙格也可作为飞镖目标（拾取后清除全场流沙）
        if board.sandStopTile then
            dartTargets[#dartTargets + 1] = { kind = "sandStop", obj = board.sandStopTile, col = board.sandStopTile.col, row = board.sandStopTile.row }
        end

        if #dartTargets > 0 then
            -- 按距离排序
            table.sort(dartTargets, function(a, b)
                local da = HexGrid.CubeDistance(a.col, a.row, hero.col, hero.row)
                local db = HexGrid.CubeDistance(b.col, b.row, hero.col, hero.row)
                return da < db
            end)

            -- 发射 dartCount 枚飞镖，每枚选择不同目标（穿透模式下可重复命中）
            local usedTargets = {}  -- 非穿透模式下记录已选目标
            for dartIdx = 1, dartCount do
                local pick = nil
                if dartPierce then
                    -- 穿透模式：循环选择目标（允许重复命中同一敌人）
                    local idx = ((dartIdx - 1) % #dartTargets) + 1
                    pick = dartTargets[idx]
                else
                    -- 非穿透模式：依次选择不同目标
                    for _, t in ipairs(dartTargets) do
                        if not usedTargets[t] then
                            pick = t
                            usedTargets[t] = true
                            break
                        end
                    end
                    if not pick then
                        -- 所有目标已分配完，循环使用
                        local idx = ((dartIdx - 1) % #dartTargets) + 1
                        pick = dartTargets[idx]
                    end
                end

                -- 飞镖伤害延迟到动画结束才生效
                local capturedPick = pick
                local capturedState = state
                -- 额外飞镖伤害递减：首枚全额，后续每枚-12%，最低40%（避免多镖叠加过强）
                local dartFactor = math.max(0.4, 1 - (dartIdx - 1) * 0.12)
                local capturedDmg = math.floor(dartBaseDmg * dartFactor)
                local capturedBurn = dartBurn
                local capturedIdx = dartIdx
                AM.PlaySFX("combo_dart")
                Battle.AddVFX(state, "dart_fly", {
                    fromCol = hero.col, fromRow = hero.row,
                    toCol = pick.col, toRow = pick.row,
                    duration = 0.6 + (dartIdx - 1) * 0.12,  -- 多镖错开时间
                    onComplete = function()
                        if capturedPick.kind == "enemy" then
                            local target = capturedPick.obj
                            if target.hp <= 0 then return end
                            local dartDmg = capturedDmg
                            dartDmg = Battle.ApplyAltarReduction(capturedState, target, dartDmg)
                            if target.isBoss then
                                Battle.ApplyBossDamage(capturedState, target, dartDmg)
                            else
                                target.hp = target.hp - dartDmg
                            end
                            capturedState.totalDamage = capturedState.totalDamage + dartDmg
                            Battle.AddFloatingText(capturedState, target.col, target.row,
                                "-" .. dartDmg .. "🗡️飞镖!", {255, 180, 50, 255})
                            -- Lv5灼烧效果
                            if capturedBurn and target.hp > 0 then
                                target._burnTurns = (target._burnTurns or 0) + 2
                                target._burnDmg = 6
                                Battle.AddFloatingText(capturedState, target.col, target.row,
                                    "🔥灼烧!", {255, 100, 0, 255})
                                -- 橙红火球爆裂特效 + 火焰命中音效
                                Battle.AddVFX(capturedState, "flame_bolt", {
                                    col = target.col, row = target.row,
                                    duration = 0.5,
                                })
                                AM.PlaySFX("flame_bolt_impact", 0.7, 1.1)
                            end
                            if target.hp <= 0 then
                                Battle.HandleEnemyDeath(capturedState, target, true)
                            end
                            -- 最后一枚飞镖命中后刷新HUD
                            if capturedIdx == dartCount then
                                local GameUI = require "GameUI"
                                pcall(GameUI.UpdateHUD)
                            end
                        elseif capturedPick.kind == "sandStop" then
                            Battle.CheckSandStopTile(capturedState, capturedPick.col, capturedPick.row)
                            Battle.AddFloatingText(capturedState, capturedPick.col, capturedPick.row,
                                "🗡️飞镖触发停沙!", {100, 220, 255, 255}, "combo", 2.8)
                            Battle.AddLog(capturedState, "🗡️ 飞镖命中停沙格，全场流沙消除！")
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
            end
            -- 多镖公告
            if dartStormLv >= 1 then
                Battle.AddLog(state, string.format("🗡️ 飞镖风暴! 发射%d枚飞镖!", dartCount))
            end
        else
            -- 无目标时：飞镖转化为回血效果（敌人全被连跳击杀的情况）
            local healAmt = 15 + dartStormLv * 5
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
        string.format("🛡+%d(%d)", shieldAmt, hero._shield), {255, 200, 50, 255})
    Battle.AddVFX(state, "shield_gain", {
        col = hero.col, row = hero.row, duration = 0.6,
    })
    AM.PlaySFX("combo_shield_gain")
    Battle.AddLog(state, string.format("🛡 连击结束！获得%d护盾（%d连），当前护盾%d", shieldAmt, finalCombo, hero._shield))
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

--- 处理英雄毒DOT（毒尾蜥施加，每回合开始时调用）
function Battle.ProcessHeroPoison(state)
    if state.poisonDot and state.poisonDot.turns > 0 then
        local dmg = state.poisonDot.damage or 5
        state.hero.hp = state.hero.hp - dmg
        state.poisonDot.turns = state.poisonDot.turns - 1
        Battle.AddFloatingText(state, state.hero.col, state.hero.row,
            "-" .. dmg .. "🐍中毒", {120, 200, 50, 255})
        Battle.AddLog(state, string.format("毒液伤害！-%dHP（剩余%d回合）", dmg, state.poisonDot.turns))
        if state.poisonDot.turns <= 0 then
            state.poisonDot = nil
            Battle.AddLog(state, "毒液效果消退")
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
                    local actualDmg = Battle.CalcEnemyDmg(dmg, hero.def or 0)
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
                        abyss_kraken = "aura_abyss",
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


-- Enemy AI (delegated to submodule)
require("BattleEnemy")(Battle)

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
    Battle.BossAct_LavaLord      = BattleBoss.BossAct_LavaLord
    Battle.BossAct_AbyssKraken   = BattleBoss.BossAct_AbyssKraken
    Battle.BossAct_CoralGuardian = BattleBoss.BossAct_CoralGuardian
    Battle.ApplyBossDamage       = BattleBoss.ApplyBossDamage
end
_initBattleBoss()

return Battle
