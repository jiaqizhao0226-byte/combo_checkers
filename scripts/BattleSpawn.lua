-- ============================================================================
-- BattleSpawn.lua - Level generation & enemy spawning (split from Battle.lua)
-- Contains: GenerateLevel, GenerateEndlessWave, ContinueLevel, TrySpawn*, CreatePiece, etc.
-- Usage: require("BattleSpawn")(Battle)
-- ============================================================================

local HexGrid = require "HexGrid"
local Skills = require "Skills"
local AM = require "AudioManager"
local G = require "GameState"
local PlayerData = require "PlayerData"
local SetEffects = require "SetEffects"
local BattleData = require "BattleData"
local ENEMY_TEMPLATES = BattleData.ENEMY_TEMPLATES
local BOSS_TEMPLATES = BattleData.BOSS_TEMPLATES
local HERO_TEMPLATE = BattleData.HERO_TEMPLATE
local CHAPTER_BOSS = BattleData.CHAPTER_BOSS
local ITEM_TYPES = BattleData.ITEM_TYPES
local ENEMY_INTRO = BattleData.ENEMY_INTRO

return function(Battle)

local function IsBoardEdgeCell(col, row)
    return HexGrid.CubeDistance(col, row, HexGrid.CENTER_COL, HexGrid.CENTER_ROW) == HexGrid.RADIUS
end

--- 第五章道具更偏向刷在棋盘最外圈，鼓励玩家用冰面滑行去边缘拾取。
--- 非第五章保持普通随机。
function Battle.PickItemSpawnPosition(state, candidates)
    if #candidates == 0 then return nil end
    local chapter = 1
    if Battle.GetChapterInfo and state.level then
        chapter = Battle.GetChapterInfo(state.level)
    end
    if chapter ~= 5 then
        return candidates[math.random(1, #candidates)]
    end

    local totalWeight = 0
    for _, pos in ipairs(candidates) do
        pos._itemSpawnWeight = IsBoardEdgeCell(pos.col, pos.row) and 12 or 1
        totalWeight = totalWeight + pos._itemSpawnWeight
    end
    local roll = math.random(1, totalWeight)
    local cumulative = 0
    for _, pos in ipairs(candidates) do
        cumulative = cumulative + pos._itemSpawnWeight
        if roll <= cumulative then
            return pos
        end
    end
    return candidates[#candidates]
end

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
    -- 清理呼唤风沙持续状态
    state.sandFuryActive = false
    state.sandFuryTurns = nil
    state.sandFuryDmg = nil
    state.sandFuryBoss = nil

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
            state.killTarget = 4 + ch + math.floor(stg / 2)
        end
        -- 每章第1关重置厄运转盘刷出计数（每章最多1个）
        if stg == 1 then
            state.doomWheelSpawnedThisChapter = 0
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
        -- Boss 按章节缩放（每章递增显著）
        local bossHpScale = 1.0 + 0.25 * (chapter - 1)
        local bossAtkScale = 1.0 + 0.18 * (chapter - 1)
        boss.hp = math.floor(boss.hp * bossHpScale)
        boss.maxHp = boss.hp
        boss.atk = math.floor(boss.atk * bossAtkScale)
        boss.shieldMax = math.floor(boss.shieldMax * bossHpScale)
        HexGrid.AddPiece(board, boss)
        state.boss = boss

        -- === Boss初始技能CD：让技能错开就绪，前几回合Boss以移动/普攻为主 ===
        -- 全局CD机制保证"技能→普攻→技能"交替，初始CD确保开场安全期
        boss.skillGlobalCD = 2  -- 开场前2回合只普攻/移动
        if bossKey == "abyss_kraken" then
            boss.abyssClawCooldown  = 2   -- 近身重击
            boss.tentacleCooldown   = 4   -- 触手障碍
            boss.whirlpoolCooldown  = 6   -- 漩涡牵引
        elseif bossKey == "lava_lord" then
            boss.lavaFistCooldown   = 2   -- 熔岩重拳
            boss.flameBoltCooldown  = 4   -- 火焰弹射
            boss.eruptionCooldown   = 6   -- 火山爆发
            boss.shieldRegenCooldown = 5  -- 护盾再生
        elseif bossKey == "coral_guardian" then
            boss.tideSurgeCooldown  = 3   -- 潮汐冲击
            boss.coralThrowCooldown = 5   -- 珊瑚投掷
            boss.coralSealCooldown  = 7   -- 珊瑚封印
        elseif bossKey == "sand_worm" then
            boss.burrowCooldown     = 4   -- 钻地
            boss.tailWhipCooldown   = 2   -- 尾鞭
            boss.sandFuryCooldown   = 7   -- 沙暴狂怒
        end

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

        -- Boss关放障碍当跳板（第4章沙虫身体段已足够，不额外放障碍）
        if chapter ~= 4 then
            -- 第五章冰块改为撞边后掉落的战术道具，不再开局预放。
            local obstacleCount = (chapter <= 2) and 5 or (chapter == 5 and 0 or 3)
            local obstacleType = nil
            for i = 1, obstacleCount do
                local c, r = claimRandomPos()
                if c then HexGrid.AddObstacle(board, c, r, obstacleType) end
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
            bossChapterEnemies = { "sand_scorpion", "sand_hawk", "venom_lizard", "sand_rattler", "sand_strider" }
        elseif chapter == 5 then
            bossChapterEnemies = { "frost_grunt", "frost_barracuda", "frost_grunt", "frost_barracuda" }
        else
            bossChapterEnemies = { "frost_grunt", "frost_barracuda", "blizzard_hawk" }
        end

        -- 按距离分散放置：优先离Boss和英雄都有一定距离的位置
        -- 第1/2章Boss多放小怪当跳板，第3/4章按原来递增
        local minionCount = (chapter <= 2) and 5 or (2 + math.min(chapter, 2))
        local bossHpScaleM = 1.0 + 0.20 * (chapter - 1)
        local bossAtkScaleM = 1.0 + 0.15 * (chapter - 1)

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
        Battle.TrySpawnItems(state, 2, { noWheel = true })  -- Boss关不出轮盘

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
        if chapter == 1 then
            -- 第一章: 平缓线性 + 章内加速（最多额外+20% HP, +15% ATK）
            hpScale = 1.0 + 0.08 * (stageInChapter - 1) + 0.20 * accelBonus
            atkScale = 1.0 + 0.05 * (stageInChapter - 1) + 0.15 * accelBonus
        elseif chapter == 2 then
            -- 第二章: 中高线性 + 章内加速（最多额外+55% HP, +40% ATK）
            hpScale = 1.0 + 0.18 * (stageInChapter - 1) + 0.55 * accelBonus
            atkScale = 1.0 + 0.12 * (stageInChapter - 1) + 0.40 * accelBonus
        elseif chapter == 3 then
            -- 第三章: 高线性 + 章内加速（最多额外+75% HP, +55% ATK）
            hpScale = 1.0 + 0.22 * (stageInChapter - 1) + 0.75 * accelBonus
            atkScale = 1.0 + 0.15 * (stageInChapter - 1) + 0.55 * accelBonus
        else
            -- 第四章: 极高线性 + 章内加速（最多额外+95% HP, +70% ATK）
            hpScale = 1.0 + 0.28 * (stageInChapter - 1) + 0.95 * accelBonus
            atkScale = 1.0 + 0.18 * (stageInChapter - 1) + 0.70 * accelBonus
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
                -- S8-S9: 保留多样性，高威胁怪适度出现（避免难度过高）
                enemyTypes = { "jellyfish", "iron_turtle", "vortex_eel", "hermit_crab", "ghost_shark", "archerfish", "electric_ray" }
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
            -- 第四章: 沙漠系敌人，后期加入特殊机制怪
            enemyTypes = { "sand_scorpion", "sand_scorpion", "quicksand_worm", "sand_hawk" }
            if stageInChapter >= 3 then
                enemyTypes = { "sand_scorpion", "quicksand_worm", "sand_hawk", "venom_lizard" }
            end
            if stageInChapter >= 5 then
                enemyTypes = { "sand_scorpion", "quicksand_worm", "sand_hawk", "venom_lizard", "sand_rattler" }
            end
            if stageInChapter >= 7 then
                enemyTypes = { "sand_scorpion", "sand_hawk", "venom_lizard", "sand_rattler", "sand_strider" }
            end
        elseif chapter == 5 then
            -- 第五章: 逐步解锁冰系敌人
            enemyTypes = { "frost_grunt", "frost_grunt", "frost_barracuda" }
            if stageInChapter >= 3 then
                enemyTypes = { "frost_grunt", "frost_barracuda", "aurora_jelly" }
            end
            if stageInChapter >= 5 then
                enemyTypes = { "frost_grunt", "frost_barracuda", "aurora_jelly", "ice_crystal", "blizzard_hawk" }
            end
            if stageInChapter >= 7 then
                enemyTypes = { "frost_grunt", "frost_barracuda", "aurora_jelly", "ice_crystal", "blizzard_hawk", "frost_bear" }
            end
        else
            enemyTypes = { "frost_grunt", "frost_barracuda", "blizzard_hawk" }
        end

        -- 障碍物数量：只有第三章放珊瑚/礁石（配合寄居蟹营救机制）。
        -- 第五章冰块由撞边累计掉落，作为风险换资源的战术道具。
        local obstacleCount = 0
        local obstacleType = nil
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
            if c then HexGrid.AddObstacle(board, c, r, obstacleType) end
        end

        -- 放置敌人
        local ghostSharkCount = 0
        local GHOST_SHARK_CAP = 2  -- 第一章同屏隐形鲨上限
        -- 安全断言：确保第五章刷的是冰系敌人
        if chapter == 5 then
            local firstType = enemyTypes[1] or "?"
            if firstType ~= "frost_grunt" and firstType ~= "frost_barracuda" then
                -- 异常：强制修正
                enemyTypes = { "frost_grunt", "frost_grunt", "frost_barracuda" }
                Battle.AddLog(state, "⚠️ [BUG] chapter5 enemyTypes was wrong, forced fix!")
            end
            Battle.AddLog(state, string.format("❄️ 第%d章第%d关: 敌人池=%s (v2)",
                chapter, stageInChapter, table.concat(enemyTypes, ",")))
        end
        for i = 1, enemyCount do
            local c, r = claimRandomPos()
            if c then
                local etype = enemyTypes[math.random(1, #enemyTypes)]
                -- 第一章: 限制隐形鲨同屏最多3只
                if chapter == 1 and etype == "ghost_shark" and ghostSharkCount >= GHOST_SHARK_CAP then
                    -- 已达上限，换成其他怪物
                    local fallback = { "jellyfish", "iron_turtle", "vortex_eel", "hermit_crab" }
                    etype = fallback[math.random(1, #fallback)]
                end
                if etype == "ghost_shark" then ghostSharkCount = ghostSharkCount + 1 end
                local template = ENEMY_TEMPLATES[etype]
                -- 第五章强制保护：如果模板查找失败，直接用内联数据兜底
                if not template and chapter == 5 then
                    if etype == "frost_barracuda" then
                        template = { team = "enemy", enemyType = "frost_barracuda", hp = 30, maxHp = 30, atk = 28, attackRange = 1, attackLabel = "冲刺", name = "寒冰梭鱼", chargeRange = 4, iceChargeUnlimited = true }
                    else
                        template = { team = "enemy", enemyType = "frost_grunt", hp = 52, maxHp = 52, atk = 20, attackRange = 1, attackLabel = "冰锥刺击", name = "冰锥兵" }
                    end
                end
                local piece = Battle.CreatePiece(template, c, r)
                -- 第五章双重保险：确保piece类型正确，防止CreatePiece兜底为slime
                if chapter == 5 and piece.enemyType == "slime" then
                    piece.enemyType = etype
                    piece.name = (etype == "frost_barracuda") and "寒冰梭鱼" or "冰锥兵"
                    piece.hp = (etype == "frost_barracuda") and 30 or 52
                    piece.maxHp = piece.hp
                    piece.atk = (etype == "frost_barracuda") and 28 or 20
                    piece.attackLabel = (etype == "frost_barracuda") and "冲刺" or "冰锥刺击"
                    piece.attackRange = 1
                end
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

        -- 随机生成道具（每章第1关不刷轮盘，2-9关可刷轮盘）
        local itemOpts = stageInChapter <= 1 and { noWheel = true } or nil
        Battle.TrySpawnItems(state, 1, itemOpts)

        Battle.AddLog(state, string.format("=== 第%d章 第%d关开始！===", chapter, stageInChapter))
    end

    -- Chapter 5: generate initial ice tiles
    if chapter == 5 then
        local IceMechanic = require "IceMechanic"
        IceMechanic.GenerateInitialIce(state, stageInChapter)
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
    state.killTarget = 7 + math.floor((wave - 1) / 2)
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

        -- 玻璃大炮: 首波初始化时应用HP减少+ATK提升
        local gcLv = Skills.Level(state.skills, "glass_cannon")
        if gcLv >= 1 then
            local hpRedPct = (10 + gcLv * 5) / 100
            local atkBoostPct = (15 + gcLv * 5) / 100
            local hpLoss = math.floor(state.hero.maxHp * hpRedPct)
            state.hero.maxHp = state.hero.maxHp - hpLoss
            state.hero.hp = math.min(state.hero.hp, state.hero.maxHp)
            local atkGain = math.floor(state.hero.atk * atkBoostPct)
            state.hero.atk = state.hero.atk + atkGain
            state.hero._glassCannonApplied = gcLv
        end

        if G.playerData then
            state.critRate = PlayerData.GetCritRate(G.playerData)
            state.goldBonus = PlayerData.GetGoldBonus(G.playerData)
            state.setEffects = SetEffects.Init(G.playerData.equipment, state.critRate)
        end
    else
        -- 后续波：仅重置位置，保留英雄当前血量/ATK/DEF
        state.hero.col = heroCol
        state.hero.row = heroRow

        -- 玻璃大炮: 后续波次追加效果（升级或首次获得时）
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
            state.killTarget = 4 + ch + math.floor(stg / 2)
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

    -- 难度缩放：章内关卡号 + 逐章递增系数（与 GenerateLevel 一致）
    local hpScale, atkScale
    local stgAccel = (stageInChapter - 1) / 8
    local accelBonus = stgAccel * stgAccel
    if chapter == 1 then
        hpScale = 1.0 + 0.10 * (stageInChapter - 1) + 0.30 * accelBonus
        atkScale = 1.0 + 0.07 * (stageInChapter - 1) + 0.20 * accelBonus
    elseif chapter == 2 then
        hpScale = 1.0 + 0.18 * (stageInChapter - 1) + 0.55 * accelBonus
        atkScale = 1.0 + 0.12 * (stageInChapter - 1) + 0.40 * accelBonus
    elseif chapter == 3 then
        hpScale = 1.0 + 0.22 * (stageInChapter - 1) + 0.75 * accelBonus
        atkScale = 1.0 + 0.15 * (stageInChapter - 1) + 0.55 * accelBonus
    else
        hpScale = 1.0 + 0.28 * (stageInChapter - 1) + 0.95 * accelBonus
        atkScale = 1.0 + 0.18 * (stageInChapter - 1) + 0.70 * accelBonus
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
    elseif chapter == 4 then
        enemyTypes = { "sand_scorpion", "sand_scorpion", "quicksand_worm", "sand_hawk" }
        if stageInChapter >= 3 then
            enemyTypes = { "sand_scorpion", "quicksand_worm", "sand_hawk", "venom_lizard" }
        end
        if stageInChapter >= 5 then
            enemyTypes = { "sand_scorpion", "quicksand_worm", "sand_hawk", "venom_lizard", "sand_rattler" }
        end
        if stageInChapter >= 7 then
            enemyTypes = { "sand_scorpion", "sand_hawk", "venom_lizard", "sand_rattler", "sand_strider" }
        end
    elseif chapter == 5 then
        enemyTypes = { "frost_grunt", "frost_grunt", "frost_barracuda" }
        if stageInChapter >= 3 then
            enemyTypes = { "frost_grunt", "frost_barracuda", "aurora_jelly" }
        end
        if stageInChapter >= 5 then
            enemyTypes = { "frost_grunt", "frost_barracuda", "aurora_jelly", "ice_crystal", "blizzard_hawk" }
        end
        if stageInChapter >= 7 then
            enemyTypes = { "frost_grunt", "frost_barracuda", "aurora_jelly", "ice_crystal", "blizzard_hawk", "frost_bear" }
        end
    else
        enemyTypes = { "frost_grunt", "frost_barracuda", "blizzard_hawk" }
    end

    -- 在空位刷新新敌人
    -- 辅助：在随机空位生成一个指定类型的敌人，返回是否成功
    local function spawnOneEnemy(etype)
        local template = ENEMY_TEMPLATES[etype]
        -- 第五章强制保护
        if not template and chapter == 5 then
            if etype == "frost_barracuda" then
                template = { team = "enemy", enemyType = "frost_barracuda", hp = 30, maxHp = 30, atk = 28, attackRange = 1, attackLabel = "冲刺", name = "寒冰梭鱼", chargeRange = 4, iceChargeUnlimited = true }
            else
                template = { team = "enemy", enemyType = "frost_grunt", hp = 52, maxHp = 52, atk = 20, attackRange = 1, attackLabel = "冰锥刺击", name = "冰锥兵" }
            end
        end
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

    -- 补充道具（每章第1关不刷轮盘，2-9关可刷轮盘）
    local transItemOpts = stageInChapter <= 1 and { noWheel = true } or nil
    Battle.TrySpawnItems(state, 1, transItemOpts)

    Battle.AddFloatingText(state, state.hero.col, state.hero.row,
        "🔄 新目标!", {100, 255, 200, 255}, "combo")
    Battle.AddLog(state, string.format("=== 第%d章 第%d关 无缝过渡！击杀目标: %d ===",
        chapter, stageInChapter, state.killTarget))
end

--- 随机刷新道具 (最多 maxCount 个, opts.noWheel=true 时排除轮盘)
function Battle.TrySpawnItems(state, maxCount, opts)
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
    local noWheel = opts and opts.noWheel
    -- 厄运转盘每章最多1个：检查本章是否已刷出
    local noDoomWheel = (state.doomWheelSpawnedThisChapter or 0) >= 1
    local weightedTypes = {
        { type = "health_potion",     weight = 25 },
        { type = "health_potion_big", weight = 5  },
        { type = "gold_bag",          weight = 30 },
        { type = "shield",            weight = 25 },
    }
    if not noWheel then
        weightedTypes[#weightedTypes + 1] = { type = "lucky_wheel", weight = 24 }
        if not noDoomWheel then
            weightedTypes[#weightedTypes + 1] = { type = "doom_wheel",  weight = 12  }
        end
    end
    local totalWeight = 0
    for _, wt in ipairs(weightedTypes) do totalWeight = totalWeight + wt.weight end

    local spawned = 0
    while spawned < toSpawn and #candidates > 0 do
        local pos = Battle.PickItemSpawnPosition(state, candidates)
        if not pos then break end
        for i = #candidates, 1, -1 do
            if candidates[i] == pos then
                table.remove(candidates, i)
                break
            end
        end
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
        -- 追踪厄运转盘刷出数量（每章限1个）
        if itemType == "doom_wheel" then
            state.doomWheelSpawnedThisChapter = (state.doomWheelSpawnedThisChapter or 0) + 1
        end
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
    -- 普通关和Boss关都每2回合刷一次
    if state.turn % 2 ~= 0 then return end

    local board = state.board
    local chapter, stageInChapter = Battle.GetChapterInfo(state.level)

    -- 检查场上敌人数量上限
    local aliveEnemies = HexGrid.GetTeamPieces(board, "enemy")
    local nonBossCount = 0
    for _, e in ipairs(aliveEnemies) do
        if not e.isBoss then nonBossCount = nonBossCount + 1 end
    end
    -- Boss关小怪上限4只（保持战斗聚焦Boss本身），普通关上限10
    local maxEnemies = isBoss and 4 or 10
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
        if stageInChapter >= 3 then
            enemyTypes = { "sand_scorpion", "sand_hawk", "venom_lizard" }
        end
        if stageInChapter >= 5 then
            enemyTypes = { "sand_scorpion", "sand_hawk", "venom_lizard", "sand_rattler" }
        end
        if stageInChapter >= 7 then
            enemyTypes = { "sand_hawk", "venom_lizard", "sand_rattler", "sand_strider" }
        end
    elseif chapter == 5 then
        enemyTypes = { "frost_grunt", "frost_barracuda", "frost_grunt" }
        if stageInChapter >= 3 then
            enemyTypes = { "frost_grunt", "frost_barracuda", "aurora_jelly" }
        end
        if stageInChapter >= 5 then
            enemyTypes = { "frost_grunt", "frost_barracuda", "aurora_jelly", "ice_crystal", "blizzard_hawk" }
        end
        if stageInChapter >= 7 then
            enemyTypes = { "frost_grunt", "frost_barracuda", "aurora_jelly", "ice_crystal", "blizzard_hawk", "frost_bear" }
        end
    else
        enemyTypes = { "frost_grunt", "frost_barracuda", "blizzard_hawk" }
    end

    -- Boss关：使用专用安全小怪池（排除ghost_shark等高难度/隐身类怪物）
    if isBoss then
        if chapter == 1 then
            enemyTypes = { "jellyfish", "iron_turtle", "archerfish", "electric_ray" }
        elseif chapter == 2 then
            enemyTypes = { "fire_sprite", "lava_giant" }
        elseif chapter == 3 then
            enemyTypes = { "coral_snapper", "sea_urchin", "reef_starfish" }
        elseif chapter == 4 then
            enemyTypes = { "sand_scorpion", "sand_hawk", "venom_lizard" }
        elseif chapter == 5 then
            enemyTypes = { "frost_grunt", "frost_barracuda", "aurora_jelly", "ice_crystal" }
        else
            enemyTypes = { "frost_grunt", "frost_barracuda" }
        end
    end

    -- 获取外围空位
    local outerEmpty = Battle.GetOuterRingEmpty(board)
    if #outerEmpty == 0 then return end

    -- 洗牌
    for i = #outerEmpty, 2, -1 do
        local j = math.random(1, i)
        outerEmpty[i], outerEmpty[j] = outerEmpty[j], outerEmpty[i]
    end

    -- 刷新敌人数量：Boss关每次只刷1个，普通关1-2个（不超过上限差值）
    local spawnSlots = maxEnemies - nonBossCount
    local maxSpawn = math.min(isBoss and 1 or 2, spawnSlots, #outerEmpty)
    if maxSpawn <= 0 then return end
    local spawnCount = math.random(1, maxSpawn)

    -- 难度缩放（与GenerateLevel一致：章内关卡号 + 逐章递增系数）
    local spawnChapter, spawnStage = Battle.GetChapterInfo(state.level)
    local spawnAccel = (spawnStage - 1) / 8
    local spawnAccelBonus = spawnAccel * spawnAccel
    local hpScale, atkScale
    if spawnChapter == 1 then
        hpScale = 1.0 + 0.10 * (spawnStage - 1) + 0.30 * spawnAccelBonus
        atkScale = 1.0 + 0.07 * (spawnStage - 1) + 0.20 * spawnAccelBonus
    elseif spawnChapter == 2 then
        hpScale = 1.0 + 0.18 * (spawnStage - 1) + 0.55 * spawnAccelBonus
        atkScale = 1.0 + 0.12 * (spawnStage - 1) + 0.40 * spawnAccelBonus
    elseif spawnChapter == 3 then
        hpScale = 1.0 + 0.22 * (spawnStage - 1) + 0.75 * spawnAccelBonus
        atkScale = 1.0 + 0.15 * (spawnStage - 1) + 0.55 * spawnAccelBonus
    else
        hpScale = 1.0 + 0.28 * (spawnStage - 1) + 0.95 * spawnAccelBonus
        atkScale = 1.0 + 0.18 * (spawnStage - 1) + 0.70 * spawnAccelBonus
    end

    -- 第一章: 统计当前场上隐形鲨数量，限制上限2只
    local currentGhostSharks = 0
    if chapter == 1 then
        for _, p in ipairs(board.pieces or {}) do
            if p.enemyType == "ghost_shark" and (p.hp or 0) > 0 then
                currentGhostSharks = currentGhostSharks + 1
            end
        end
    end

    for i = 1, spawnCount do
        local pos = outerEmpty[i]
        local etype = enemyTypes[math.random(1, #enemyTypes)]
        -- 第一章: 限制隐形鲨同屏最多2只
        if chapter == 1 and etype == "ghost_shark" and currentGhostSharks >= 2 then
            local fallback = { "jellyfish", "iron_turtle", "vortex_eel" }
            etype = fallback[math.random(1, #fallback)]
        end
        if etype == "ghost_shark" then currentGhostSharks = currentGhostSharks + 1 end
        local template = ENEMY_TEMPLATES[etype]
        -- 第五章强制保护：模板缺失时用内联数据兜底
        if not template and chapter == 5 then
            if etype == "frost_barracuda" then
                template = { team = "enemy", enemyType = "frost_barracuda", hp = 30, maxHp = 30, atk = 28, attackRange = 1, attackLabel = "冲刺", name = "寒冰梭鱼", chargeRange = 4, iceChargeUnlimited = true }
            else
                template = { team = "enemy", enemyType = "frost_grunt", hp = 52, maxHp = 52, atk = 20, attackRange = 1, attackLabel = "冰锥刺击", name = "冰锥兵" }
            end
        end
        local piece = Battle.CreatePiece(template, pos.col, pos.row)
        -- 第五章双重保险
        if chapter == 5 and piece.enemyType == "slime" then
            piece.enemyType = etype
            piece.name = (etype == "frost_barracuda") and "寒冰梭鱼" or "冰锥兵"
            piece.hp = (etype == "frost_barracuda") and 30 or 52
            piece.maxHp = piece.hp
            piece.atk = (etype == "frost_barracuda") and 28 or 20
            piece.attackLabel = (etype == "frost_barracuda") and "冲刺" or "冰锥刺击"
            piece.attackRange = 1
        end
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
    if not template then
        print("[WARN] CreatePiece: nil template at col=" .. tostring(col) .. " row=" .. tostring(row))
        -- 返回一个最小化占位棋子防止崩溃
        return { team = "enemy", enemyType = "slime", hp = 1, maxHp = 1, atk = 0,
                 attackRange = 1, attackLabel = "?", name = "???", col = col, row = row }
    end
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
        local heal = 40
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
        local bagGold = bagBlocked and 2 or 10
        -- 金币袋享受点金手天赋加成
        if (state.goldBonus or 0) > 0 then
            local bonusAmt = math.floor(bagGold * state.goldBonus / 100)
            bagGold = bagGold + bonusAmt
        end
        state.gold = state.gold + bagGold
        Battle.AddFloatingText(state, col, row, "+" .. bagGold .. "💰", {255, 215, 0, 255}, nil, 2.5)
        Battle.AddLog(state, "拾取 " .. def.name .. "，获得" .. bagGold .. "金币")
        AM.PlaySFX("item_pickup")

    elseif item.type == "shield" then
        state.hasShield = true
        Battle.AddFloatingText(state, col, row, "🛡️护盾!", {120, 180, 255, 255}, nil, 2.5)
        Battle.AddLog(state, "拾取 " .. def.name .. "，下次受击伤害减半")
        AM.PlaySFX("shield_ward")

    elseif item.type == "lucky_wheel" or item.type == "doom_wheel" then
        -- 轮盘道具：标记待弹窗，TurnFlow 中处理弹出
        local wType = (item.type == "lucky_wheel") and "lucky" or "doom"
        state.pendingWheel = wType
        log:Write(LOG_INFO, "[Wheel] pendingWheel set to '" .. wType .. "' at (" .. col .. "," .. row .. ")")
        Battle.AddLog(state, "拾取 " .. def.name .. "！")
        AM.PlaySFX("item_pickup", 0.8)
    end

    HexGrid.RemoveItemAt(state.board, col, row)
end

--- 停沙格：在随机空格子上生成一个停沙格（玩家踩上后消除全场流沙）
--- 仅在有流沙且当前没有停沙格时才生成
function Battle.SpawnSandStopTile(state)
    local board = state.board
    -- 已有停沙格则不重复生成
    if board.sandStopTile then return end
    -- 没有流沙区则不生成
    if not board.quicksandZones or #board.quicksandZones == 0 then return end
    -- 找到所有可用空格
    local allCells = HexGrid.GetAllValidCells(board)
    local candidates = {}
    local hero = state.hero
    for _, c in ipairs(allCells) do
        if not HexGrid.IsBlocked(board, c.col, c.row)
           and not HexGrid.IsInQuicksandZone(board, c.col, c.row)
           and (c.col ~= hero.col or c.row ~= hero.row) then
            candidates[#candidates + 1] = c
        end
    end
    if #candidates == 0 then return end
    local pick = candidates[math.random(1, #candidates)]
    board.sandStopTile = { col = pick.col, row = pick.row }
    Battle.AddFloatingText(state, pick.col, pick.row,
        "🛑停沙格!", {100, 220, 255, 255}, nil, 2.5)
    Battle.AddVFX(state, "sand_stop_spawn", { col = pick.col, row = pick.row, duration = 1.0 })
    Battle.AddLog(state, "停沙格出现！踩上去可以消除全场流沙！")
    AM.PlaySFX("item_spawn", 0.7)
end

--- 检查英雄是否踩到停沙格，踩到则清除全场流沙
function Battle.CheckSandStopTile(state, col, row)
    local board = state.board
    if not board.sandStopTile then return end
    local st = board.sandStopTile
    if st.col == col and st.row == row then
        -- 消除全场流沙
        local removedCount = board.quicksandZones and #board.quicksandZones or 0
        board.quicksandZones = {}
        board.sandStopTile = nil
        Battle.AddFloatingText(state, col, row,
            "✨流沙全消!", {100, 255, 200, 255}, "combo", 3.0)
        Battle.AddVFX(state, "sand_stop_clear", { col = col, row = row, duration = 1.2 })
        state.screenShake = (state.screenShake or 0) + 0.3
        AM.PlaySFX("heal_pickup", 1.0)
        Battle.AddLog(state, string.format("踩上停沙格！消除全场 %d 片流沙区！", removedCount))
    end
end


end
