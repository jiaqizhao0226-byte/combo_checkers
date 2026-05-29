-- ============================================================================
-- TurnFlow - 游戏回合流程（技能选择、玩家操作、敌人回合、胜负判定）
-- ============================================================================

local Battle = require "Battle"
local HexGrid = require "HexGrid"
local Skills = require "Skills"
local PlayerData = require "PlayerData"
local SetEffects = require "SetEffects"
local G = require "GameState"
local GameUI = require "GameUI"
local MenuSystem = require "MenuSystem"
local AM = require "AudioManager"

local TurnFlow = {}

--- 构建 FindValidJumps 的 opts: 所有章节障碍物（岩石、珊瑚、祭坛等）均可作为飞跃先锋支点
local function buildJumpOpts()
    return { ch3Rocks = true }
end

-- TurnFlow.UploadProgress 定义在文件底部

--- 幂等结算：金币 + 进度，最多执行一次（通过 G.battle._rewardsSettled 保护）
local function SettleBattleRewards()
    if not G.battle or G.battle._rewardsSettled then return end
    G.battle._rewardsSettled = true

    -- 金币（无论胜负都结算当局累计金币）
    PlayerData.AddGold(G.playerData, G.battle.gold or 0)
    G.battle.gold = 0

    -- 进度
    if G.battle.isEndless then
        local wave = G.battle.endlessWave or 1
        if wave > (G.playerData.highestEndlessWave or 0) then
            G.playerData.highestEndlessWave = wave
        end
    else
        local level = G.battle.level or 1
        if level > G.highestLevel then
            G.highestLevel = level
        end
        if level > (G.playerData.highestLevel or 1) then
            G.playerData.highestLevel = level
        end
    end

    PlayerData.Save(G.playerData)
    TurnFlow.UploadProgress(G.playerData)
end

-- ============================================================================
-- 摄像机辅助
-- ============================================================================

--- 瞬间将摄像机对齐到英雄位置（无插值，用于关卡切换）
function TurnFlow.SnapCameraToHero()
    if not G.battle or not G.battle.hero then return end
    G.ZOOM_IN = 1.45
    G.ZOOM_OUT = 1.05
    -- 重置动态缩放到拉近状态（关卡切换时从近处开始）
    G.zoomCurrent = G.ZOOM_IN
    G.zoomTarget = G.ZOOM_IN
    G.BOARD_ZOOM = G.ZOOM_IN
    G.zoomOutCooldown = 0
    G.zoomOutReason = nil
    -- 使用 BoardWidget 缓存的布局尺寸（保持坐标系一致）
    -- 首次调用时可能还没有缓存值，回退到全屏尺寸
    local w = G.boardLayoutW or (graphics:GetWidth() / graphics:GetDPR())
    local h = G.boardLayoutH or (graphics:GetHeight() / graphics:GetDPR())
    local gp = HexGrid.CalcGridParams(w, h, HexGrid.COLS, HexGrid.ROWS, G.BOARD_ZOOM)
    local hero = G.battle.hero
    local heroGX, heroGY = HexGrid.HexToPixel(
        hero.col, hero.row, gp.hexSize, gp.offsetX, gp.offsetY
    )
    G.cameraTargetX = heroGX - w / 2
    G.cameraTargetY = heroGY - h / 2
    local maxCamX = math.max(0, (gp.totalW - w) / 2)
    local maxCamY = math.max(0, (gp.totalH - h) / 2)
    G.cameraTargetX = math.max(-maxCamX, math.min(maxCamX, G.cameraTargetX))
    G.cameraTargetY = math.max(-maxCamY, math.min(maxCamY, G.cameraTargetY))
    G.cameraX = G.cameraTargetX
    G.cameraY = G.cameraTargetY
end

-- ============================================================================
-- 场景切换
-- ============================================================================

--- 检测并展示新出现的怪物类型介绍弹窗
local function checkAndShowEnemyIntro()
    local seenTypes = G.playerData.seenEnemyTypes or {}
    local newIntros = Battle.DetectNewEnemyTypes(G.battle.board, seenTypes)
    if #newIntros > 0 then
        -- 标记为已见过并持久化
        for _, info in ipairs(newIntros) do
            seenTypes[info.enemyType] = true
        end
        G.playerData.seenEnemyTypes = seenTypes
        PlayerData.Save(G.playerData)
        -- 显示弹窗
        GameUI.ShowEnemyIntro(newIntros)
    end
end

function TurnFlow.EnterGame(startLevel)
    startLevel = startLevel or 1
    G.gamePhase = "GAME"
    G._defeatPopupShown = nil
    G._defeatPopupRef = nil
    local bonus = PlayerData.GetTotalBonus(G.playerData)
    G.battle = Battle.New(bonus)
    G.playerData.totalRuns = (G.playerData.totalRuns or 0) + 1
    PlayerData.Save(G.playerData)
    Battle.GenerateLevel(G.battle, startLevel)
    TurnFlow.SnapCameraToHero()
    GameUI.CreateUI()
    log:Write(LOG_INFO, string.format("[BGM] EnterGame: startLevel=%d currentBGM=%s", startLevel, AM.GetCurrentBGM()))
    AM.UpdateBattleBGM(startLevel)
    log:Write(LOG_INFO, string.format("[BGM] EnterGame after update: currentBGM=%s", AM.GetCurrentBGM()))

    -- 章节首关显示新手教学弹窗
    local chapter, stageInChapter = Battle.GetChapterInfo(startLevel)
    if stageInChapter == 1 then
        GameUI.ShowChapterTutorial(chapter)
    end

    -- 第1关首次操作：在棋盘上显示"移动"/"跳跃"操作提示
    if startLevel == 1 then
        G.showBoardTutorial = true
    end

    -- 新关卡开始时检测新怪物介绍弹窗
    checkAndShowEnemyIntro()

    TurnFlow.StartPlayerTurn()
end

--- 进入无尽模式
function TurnFlow.EnterEndless()
    G.gamePhase = "GAME"
    G._defeatPopupShown = nil
    G._defeatPopupRef = nil
    local bonus = PlayerData.GetTotalBonus(G.playerData)
    G.battle = Battle.New(bonus)
    G.battle.isEndless = true
    G.battle.endlessWave = 1
    G.playerData.totalRuns = (G.playerData.totalRuns or 0) + 1
    PlayerData.Save(G.playerData)
    Battle.GenerateEndlessWave(G.battle, 1)
    TurnFlow.SnapCameraToHero()
    GameUI.CreateUI()
    AM.PlayBGM("battle_endless")
    TurnFlow.StartPlayerTurn()
end

function TurnFlow.ReturnToMenu()
    G.gamePhase = "MENU"
    SettleBattleRewards()
    G.menuTab = "adventure"
    G.selectedLevel = G.highestLevel
    -- 主线仅3章，无尽模式在 selectedChapter=0
    local maxChapter = math.ceil(G.highestLevel / Battle.LEVELS_PER_CHAPTER)
    G.selectedChapter = math.min(maxChapter, 3)
    MenuSystem.CreateMenuUI()
    AM.PlayBGM("menu")
end

-- ============================================================================
-- 技能选择流程
-- ============================================================================

function TurnFlow.ShowSkillSelect()
    G.skillChoices = Skills.PickChoices(G.battle.skills, 3)
    if #G.skillChoices == 0 then
        TurnFlow.NextLevel()
        return
    end
    GameUI.PopulateSkillCards(G.skillChoices)
    if G.skillModal then
        G.skillModal:Open()
    else
        TurnFlow.NextLevel()
        return
    end
    -- 技能面板已弹出，清除看门狗，等玩家手动选择
    G._winShownAt = nil
end

function TurnFlow.OnSkillSelected(choice)
    if not choice then return end
    G._winShownAt = nil  -- 玩家已选技能，清除看门狗

    local def = choice.skill
    local prevCombos = Skills.GetActiveCombos(G.battle.skills)

    G.battle.skills = Skills.SelectUpgrade(G.battle.skills, choice.id)

    local newLv = Skills.Level(G.battle.skills, choice.id)
    if choice.currentLevel == 0 then
        Battle.AddLog(G.battle, string.format("✦ 习得 %s %s (Lv1)",
            def.icon, def.name))
    else
        Battle.AddLog(G.battle, string.format("★ %s %s → Lv%d",
            def.icon, def.name, newLv))
    end

    local newCombos = Skills.GetActiveCombos(G.battle.skills)
    if #newCombos > #prevCombos then
        for _, combo in ipairs(newCombos) do
            local wasActive = false
            for _, old in ipairs(prevCombos) do
                if old.id == combo.id then wasActive = true; break end
            end
            if not wasActive then
                Battle.AddLog(G.battle, "🔗 组合技激活: " .. combo.icon .. " " .. combo.name .. " - " .. combo.desc)
            end
        end
    end

    if G.skillModal then G.skillModal:Close() end
    TurnFlow.NextLevel()
end

function TurnFlow.NextLevel()
    G._winShownAt = nil  -- 清除看门狗计时，防止误触发

    -- ====== 无尽模式：进入下一波 ======
    if G.battle.isEndless then
        local nextWave = (G.battle.endlessWave or 1) + 1
        G.battle.combo = 0
        G.battle.maxCombo = 0
        -- 技能在无尽模式中持续保留，不重置
        Battle.GenerateEndlessWave(G.battle, nextWave)
        TurnFlow.SnapCameraToHero()
        TurnFlow.ClearPlan()
        TurnFlow.StartPlayerTurn()
        GameUI.UpdateLog(string.format("🌀 无尽第%d波！坚持住！", nextWave))
        return
    end

    -- ====== 普通模式：进入下一关 ======
    local nextLv = G.battle.level + 1
    G.battle.combo = 0
    G.battle.maxCombo = 0

    -- 跨章节时重置技能（技能不带入下一章）
    local curChapter = Battle.GetChapterInfo(G.battle.level)
    local nextChapter = Battle.GetChapterInfo(nextLv)
    local isNewChapter = (nextChapter ~= curChapter)
    if isNewChapter then
        G.battle.skills = {}
        -- 进入新章节：清除所有护盾状态（不应带入新关卡）
        G.battle.hasShield = false
        G.battle.drainShield = nil
        if G.battle.hero then
            G.battle.hero._shield = 0
        end
        Battle.AddLog(G.battle, string.format("📖 进入第%d章！技能已重置，重新选择技能吧！", nextChapter))
    end

    if Battle.IsBossLevel(nextLv) then
        -- Boss关: 完整重建棋盘
        G.battle.turnAccum = (G.battle.turnAccum or 0) + G.battle.turn
        G.battle.turn = 1
        Battle.GenerateLevel(G.battle, nextLv)
        TurnFlow.SnapCameraToHero()
        local chapter = Battle.GetChapterInfo(nextLv)
        local bossType = Battle.CHAPTER_BOSS and Battle.CHAPTER_BOSS[chapter]
        log:Write(LOG_INFO, string.format("[BGM] NextLevel->Boss: nextLv=%d chapter=%d bossType=%s currentBGM=%s", nextLv, chapter, tostring(bossType), AM.GetCurrentBGM()))
        -- Battle.AddLog(G.battle, string.format("[DEBUG] BGM切换: level=%d bossType=%s", nextLv, tostring(bossType)))  -- [TEST]
        AM.UpdateBattleBGM(nextLv)  -- 根据Boss类型自动选择专属BGM
        -- Battle.AddLog(G.battle, string.format("[DEBUG] BGM切换后: currentBGM=%s", AM.GetCurrentBGM()))  -- [TEST]
        -- 熔岩领主使用专属入场怒吼
        if bossType == "lava_lord" then
            AM.PlaySFX("lava_lord_roar")
        else
            AM.PlaySFX("boss_entrance")
        end
    elseif isNewChapter then
        -- 跨章节: 完整重建棋盘（清除上一章所有内容：触手、障碍、毒池等）
        G.battle.turnAccum = (G.battle.turnAccum or 0) + G.battle.turn
        G.battle.turn = 1
        Battle.GenerateLevel(G.battle, nextLv)
        TurnFlow.SnapCameraToHero()
        AM.UpdateBattleBGM(nextLv)
        GameUI.UpdateBackground()  -- 新章节：更新全屏背景渐变色
    else
        -- 同章节普通关: 无缝过渡，保留英雄和敌人位置
        Battle.ContinueLevel(G.battle, nextLv)
    end

    TurnFlow.ClearPlan()

    -- 新关卡开始时检测新怪物介绍弹窗
    checkAndShowEnemyIntro()

    TurnFlow.StartPlayerTurn()

    local chapter, stage = Battle.GetChapterInfo(nextLv)
    if Battle.IsBossLevel(nextLv) then
        GameUI.UpdateLog(string.format("⚠️ 第%d章 Boss战！", chapter))
    else
        GameUI.UpdateLog(string.format("第%d章 %d/%d — 新目标!", chapter, stage, Battle.LEVELS_PER_CHAPTER))
    end
end

-- ============================================================================
-- 游戏流程
-- ============================================================================

function TurnFlow.StartPlayerTurn()
    -- 回合开始前先检查胜负（可能上一回合的延迟效果已达成条件）
    local result = Battle.CheckEndCondition(G.battle)
    if result then
        TurnFlow.ClearPlan()
        TurnFlow.ShowResult(result)
        return
    end

    G.battle.phase = "PLAYER_SELECT"
    log:Write(LOG_INFO, string.format("[PHASE] turn=%d → PLAYER_SELECT", math.floor(G.battle.turn or 0)))
    G.battle.combo = 0
    Battle.ResetComboRewards(G.battle)  -- 每回合开始清空触发记录，防止跨关卡污染
    -- 连击护盾跨回合保留，不再清零
    G.battle._auraAnnouncedThisTurn = nil   -- 重置光环公告标记
    TurnFlow.ClearPlan()
    AM.PlaySFX("turn_start", 0.6)

    -- 沉默倒计时
    local hero = G.battle.hero
    if hero.silencedTurns and hero.silencedTurns > 0 then
        hero.silencedTurns = hero.silencedTurns - 1
        if hero.silencedTurns <= 0 then
            hero.silencedTurns = 0
            Battle.AddLog(G.battle, "🔊 沉默效果解除，可以攻击了！")
            GameUI.UpdateLog("🔊 沉默效果解除！")
        end
    end

    -- 猎手印记: 每回合开始标记血量最高的敌人
    Battle.ApplyHunterMarks(G.battle)

    -- 魅惑免疫期递减（每回合开始时）
    if G.battle.heroCharmImmunity and G.battle.heroCharmImmunity > 0 then
        G.battle.heroCharmImmunity = G.battle.heroCharmImmunity - 1
    end

    -- 魅惑水母: 被魅惑则跳过本回合玩家行动
    if G.battle.heroCharmedTurns and G.battle.heroCharmedTurns > 0 then
        G.battle.heroCharmedTurns = G.battle.heroCharmedTurns - 1
        -- 魅惑结束后给予2回合免疫期，防止被连续魅惑无限控死
        if G.battle.heroCharmedTurns <= 0 then
            G.battle.heroCharmImmunity = 2
        end
        GameUI.UpdateLog("💜 被魅惑！本回合无法行动…")
        GameUI.UpdateHUD()
        if G.btnPanel then G.btnPanel:SetVisible(false) end
        -- 延迟一点后直接进入敌人回合，让玩家能看到提示
        G.battle.phase = "ENEMY_TURN"
        G.enemyTurnTimer = 1.2
        return
    end

    TurnFlow.RefreshHighlightsForSelect()
    GameUI.UpdateHUD()
    if G.btnPanel then G.btnPanel:SetVisible(false) end

    if #G.validMoves == 0 and #G.validJumps == 0 then
        GameUI.UpdateLog("无路可走，自动跳过回合")
        -- 显示醒目"受困"浮动提示
        Battle.AddFloatingText(G.battle, G.battle.hero.col, G.battle.hero.row,
            "⛓️受困!", {255, 160, 60, 255}, "combo", 1.5)
        TurnFlow.EndPlayerTurn()
    end
end

function TurnFlow.RefreshHighlightsForSelect()
    local hero = G.battle.hero
    if hero.hp <= 0 then
        G.validMoves = {}
        G.validJumps = {}
        return
    end
    G.validMoves = HexGrid.FindValidMoves(G.battle.board, hero.col, hero.row)
    -- 沉默状态：无法跳跃攻击
    if hero.silencedTurns and hero.silencedTurns > 0 then
        G.validJumps = {}
    else
        local maxJump = G.battle.setEffects and SetEffects.GetMaxJumpOverCount(G.battle.setEffects) or 1
        G.validJumps = HexGrid.FindValidJumps(G.battle.board, hero.col, hero.row, maxJump, buildJumpOpts())
    end

    -- 过滤掉稻草人所在格子（稻草人不在 board.pieces 中，IsBlocked 检测不到）
    local sc = G.battle.scarecrow
    if sc and G.battle.scarecrowActive then
        for i = #G.validMoves, 1, -1 do
            if G.validMoves[i].col == sc.col and G.validMoves[i].row == sc.row then
                table.remove(G.validMoves, i)
            end
        end
        for i = #G.validJumps, 1, -1 do
            if G.validJumps[i].col == sc.col and G.validJumps[i].row == sc.row then
                table.remove(G.validJumps, i)
            end
        end
    end

    -- 检查是否存在多格跳（dist > 1），用于决定是否跳过普通跳跃气泡
    local hasMultiHop = false
    if not G.playerData.multiHopTutorialSeen then
        for _, j in ipairs(G.validJumps) do
            if j.dist and j.dist > 1 then
                hasMultiHop = true
                break
            end
        end
    end

    -- 首次出现可跳跃格子时显示跳跃提示
    -- 但如果有多格跳且多格跳教程未看过，跳过普通跳跃气泡，直接弹多格跳教程
    if #G.validJumps > 0 and not G.hasSeenJumpTutorial then
        G.hasSeenJumpTutorial = true
        if not hasMultiHop then
            G.showJumpTutorial = true
        end
    end

    -- 首次出现多格跳跃时显示聚光灯教程
    if not G.playerData.multiHopTutorialSeen then
        local maxDist = 0
        for _, j in ipairs(G.validJumps) do
            if j.dist and j.dist > maxDist then maxDist = j.dist end
        end
        for _, j in ipairs(G.validJumps) do
            if j.dist and j.dist > 1 then
                -- 如果跳跃标签教程正在显示，先暂存，等标签教程关闭后再弹聚光灯
                if G.showBoardTutorial or G.showJumpTutorial then
                    G.pendingMultiHopJump = j
                    G.pendingMultiHopOriginCol = hero.col
                    G.pendingMultiHopOriginRow = hero.row
                else
                    G.multiHopSpotlightJump = j
                    G.multiHopSpotlightOriginCol = hero.col
                    G.multiHopSpotlightOriginRow = hero.row
                    G.multiHopSpotlightActive = true
                    G.playerData.multiHopTutorialSeen = true
                    PlayerData.Save(G.playerData)
                    GameUI.ShowMultiHopTutorial(function()
                        G.multiHopSpotlightActive = false
                        G.multiHopSpotlightJump = nil
                    end)
                end
                break
            end
        end
    end

    -- 二连跳教程（聚光灯式）：phase 2 刷出链式敌人后，检测首跳落点是否可继续跳
    if G.battle.tutorialPhase == 3
       and not G.playerData.chainJumpTutorialSeen
       and #G.validJumps >= 1
       and not G.chainJumpSpotlightActive then
        -- 找到第一个"首跳落点还能再跳"的有效跳跃
        local maxJumpChain = G.battle.setEffects and SetEffects.GetMaxJumpOverCount(G.battle.setEffects) or 1
        for _, j in ipairs(G.validJumps) do
            -- 从这个跳跃的落点出发，看能不能再跳（二连跳）
            local chainJumps = HexGrid.FindValidJumps(G.battle.board, j.col, j.row, maxJumpChain, buildJumpOpts())
            -- 过滤：第二跳落点不能是英雄当前位置
            local validChain = nil
            for _, cj in ipairs(chainJumps) do
                if not (cj.col == hero.col and cj.row == hero.row) then
                    validChain = cj
                    break
                end
            end
            if validChain then
                -- 找到二连跳机会：激活聚光灯
                G.chainJumpSpotlightActive = true
                G.chainJumpSpotlightJump1 = j          -- 首跳
                G.chainJumpSpotlightJump2 = validChain  -- 二跳（展示用）
                G.chainJumpSpotlightOriginCol = hero.col
                G.chainJumpSpotlightOriginRow = hero.row
                G.playerData.chainJumpTutorialSeen = true
                PlayerData.Save(G.playerData)
                GameUI.ShowChainJumpSpotlight(function()
                    G.chainJumpSpotlightActive = false
                    G.chainJumpSpotlightJump1 = nil
                    G.chainJumpSpotlightJump2 = nil
                end)
                break
            end
        end
    end
end

function TurnFlow.RefreshHighlightsForPlan()
    G.validMoves = {}
    local maxJumpPlan = G.battle.setEffects and SetEffects.GetMaxJumpOverCount(G.battle.setEffects) or 1
    local allJumps = HexGrid.FindValidJumps(G.battle.board, G.planHeroCol, G.planHeroRow, maxJumpPlan, buildJumpOpts())
    G.validJumps = {}
    for _, j in ipairs(allJumps) do
        local jumpKey = j.enemy or j.obstacle
        local alreadyJumped = (jumpKey and G.jumpedEnemySet[jumpKey])
            or (j.enemy2 and G.jumpedEnemySet[j.enemy2])
            or (j.enemy3 and G.jumpedEnemySet[j.enemy3])
            or (j.jumpedObstacle and G.jumpedEnemySet[j.jumpedObstacle])
            or (j.jumpedObstacle2 and G.jumpedEnemySet[j.jumpedObstacle2])
            or (j.jumpedObstacle3 and G.jumpedEnemySet[j.jumpedObstacle3])
        if not alreadyJumped then
            local blocked = false
            for _, pj in ipairs(G.plannedJumps) do
                if pj.col == j.col and pj.row == j.row then
                    blocked = true
                    break
                end
            end
            if j.col == G.battle.hero.col and j.row == G.battle.hero.row then
                blocked = true
            end
            -- 稻草人格子不可落脚
            local sc = G.battle.scarecrow
            if not blocked and sc and G.battle.scarecrowActive
               and j.col == sc.col and j.row == sc.row then
                blocked = true
            end
            if not blocked then
                G.validJumps[#G.validJumps + 1] = j
            end
        end
    end

    -- 规划阶段首次出现多格跳跃时，触发教程
    if not G.playerData.multiHopTutorialSeen and not G.multiHopSpotlightActive then
        for _, j in ipairs(G.validJumps) do
            if j.dist and j.dist > 1 then
                G.multiHopSpotlightJump = j
                G.multiHopSpotlightOriginCol = G.planHeroCol
                G.multiHopSpotlightOriginRow = G.planHeroRow
                G.multiHopSpotlightActive = true
                G.playerData.multiHopTutorialSeen = true
                PlayerData.Save(G.playerData)
                GameUI.ShowMultiHopTutorial(function()
                    G.multiHopSpotlightActive = false
                    G.multiHopSpotlightJump = nil
                end)
                break
            end
        end
    end
end

function TurnFlow.ClearPlan()
    G.plannedJumps = {}
    G.planHeroCol = 0
    G.planHeroRow = 0
    G.jumpedEnemySet = {}
    G.threatPreview = {}
    G.threatTargetCol = 0
    G.threatTargetRow = 0
end

function TurnFlow.UpdateThreatPreview(col, row)
    if not G.battle or not col or col == 0 then
        G.threatPreview = {}
        return
    end
    G.threatPreview = Battle.GetThreats(G.battle, col, row)
    G.threatTargetCol = col
    G.threatTargetRow = row
end

function TurnFlow.HandleCellClick(col, row)
    -- 非玩家操作阶段忽略点击，防止误操作干扰动画
    if G.battle.phase == "PLAYER_SELECT" then
        TurnFlow.HandleSelectClick(col, row)
    elseif G.battle.phase == "PLAYER_PLAN" then
        TurnFlow.HandlePlanClick(col, row)
    end
    -- ENEMY_TURN / EXECUTING / RESULT 等阶段不做任何响应
end

function TurnFlow.HandleSelectClick(col, row)
    -- 玩家做出操作，关闭首次操作教学提示
    local hadLabelTutorial = G.showBoardTutorial or G.showJumpTutorial
    if G.showBoardTutorial then
        G.showBoardTutorial = false
    end
    if G.showJumpTutorial then
        G.showJumpTutorial = false
    end

    -- 标签教程刚关闭，触发暂存的多格跳跃聚光灯教程
    if hadLabelTutorial and G.pendingMultiHopJump and not G.playerData.multiHopTutorialSeen then
        local j = G.pendingMultiHopJump
        G.pendingMultiHopJump = nil
        G.multiHopSpotlightJump = j
        G.multiHopSpotlightOriginCol = G.pendingMultiHopOriginCol or G.battle.hero.col
        G.multiHopSpotlightOriginRow = G.pendingMultiHopOriginRow or G.battle.hero.row
        G.pendingMultiHopOriginCol = nil
        G.pendingMultiHopOriginRow = nil
        G.multiHopSpotlightActive = true
        G.playerData.multiHopTutorialSeen = true
        PlayerData.Save(G.playerData)
        GameUI.ShowMultiHopTutorial(function()
            G.multiHopSpotlightActive = false
            G.multiHopSpotlightJump = nil
        end)
        return  -- 先看教程，不处理本次点击
    end

    for _, j in ipairs(G.validJumps) do
        if j.col == col and j.row == row then
            G.battle.phase = "PLAYER_PLAN"
            G.planHeroCol = j.col
            G.planHeroRow = j.row
            G.plannedJumps = { j }
            local jumpKey = j.enemy or j.obstacle
            G.jumpedEnemySet = {}
            if jumpKey then G.jumpedEnemySet[jumpKey] = true end
            -- 飞跃先锋: 第一跳是双敌跳/三敌跳时也标记额外敌人/石头
            if j.enemy2 then G.jumpedEnemySet[j.enemy2] = true end
            if j.enemy3 then G.jumpedEnemySet[j.enemy3] = true end
            if j.jumpedObstacle then G.jumpedEnemySet[j.jumpedObstacle] = true end
            if j.jumpedObstacle2 then G.jumpedEnemySet[j.jumpedObstacle2] = true end
            if j.jumpedObstacle3 then G.jumpedEnemySet[j.jumpedObstacle3] = true end
            TurnFlow.RefreshHighlightsForPlan()
            TurnFlow.UpdateThreatPreview(j.col, j.row)
            if #G.validJumps == 0 then
                TurnFlow.ConfirmJumps()
            else
                TurnFlow.UpdatePlanUI()
            end
            return
        end
    end

    for _, m in ipairs(G.validMoves) do
        if m.col == col and m.row == row then
            Battle.ExecuteMove(G.battle, col, row, false)
            TurnFlow.EndPlayerTurn()
            return
        end
    end

end

function TurnFlow.HandlePlanClick(col, row)
    if col == G.planHeroCol and row == G.planHeroRow and #G.plannedJumps > 0 then
        TurnFlow.ConfirmJumps()
        return
    end

    for _, j in ipairs(G.validJumps) do
        if j.col == col and j.row == row then
            G.plannedJumps[#G.plannedJumps + 1] = j
            local jumpKey = j.enemy or j.obstacle
            if jumpKey then G.jumpedEnemySet[jumpKey] = true end
            -- 飞跃先锋: 双敌跳/三敌跳时标记额外敌人/石头
            if j.enemy2 then G.jumpedEnemySet[j.enemy2] = true end
            if j.enemy3 then G.jumpedEnemySet[j.enemy3] = true end
            if j.jumpedObstacle then G.jumpedEnemySet[j.jumpedObstacle] = true end
            if j.jumpedObstacle2 then G.jumpedEnemySet[j.jumpedObstacle2] = true end
            if j.jumpedObstacle3 then G.jumpedEnemySet[j.jumpedObstacle3] = true end
            G.planHeroCol = j.col
            G.planHeroRow = j.row
            TurnFlow.RefreshHighlightsForPlan()
            TurnFlow.UpdateThreatPreview(j.col, j.row)
            if #G.validJumps == 0 then
                TurnFlow.ConfirmJumps()
            else
                TurnFlow.UpdatePlanUI()
            end
            return
        end
    end

end

function TurnFlow.UpdatePlanUI()
    local n = #G.plannedJumps
    if G.btnPanel then G.btnPanel:SetVisible(n > 0) end
    if n > 0 and G.confirmBtn then
        G.confirmBtn:SetText("确认跳跃 (" .. n .. "步)")
    end
    if #G.validJumps > 0 then
        GameUI.UpdateLog(n .. " 步已规划，点当前格子或确认结束")
    else
        GameUI.UpdateLog(n .. " 步已规划，无更多跳跃，点确认执行")
    end
end

function TurnFlow.UndoLastJump()
    if #G.plannedJumps == 0 then return end
    local removed = table.remove(G.plannedJumps)
    local removedKey = removed.enemy or removed.obstacle
    if removedKey then G.jumpedEnemySet[removedKey] = nil end
    -- 飞跃先锋: 撤销时同步移除多敌跳跃的额外标记（含石头）
    if removed.enemy2 then G.jumpedEnemySet[removed.enemy2] = nil end
    if removed.enemy3 then G.jumpedEnemySet[removed.enemy3] = nil end
    if removed.jumpedObstacle then G.jumpedEnemySet[removed.jumpedObstacle] = nil end
    if removed.jumpedObstacle2 then G.jumpedEnemySet[removed.jumpedObstacle2] = nil end
    if removed.jumpedObstacle3 then G.jumpedEnemySet[removed.jumpedObstacle3] = nil end

    if #G.plannedJumps == 0 then
        G.battle.phase = "PLAYER_SELECT"
        TurnFlow.ClearPlan()
        TurnFlow.RefreshHighlightsForSelect()
        GameUI.UpdateHUD()
        if G.btnPanel then G.btnPanel:SetVisible(false) end
        GameUI.UpdateLog("已撤销全部，重新选择行动")
    else
        local lastJump = G.plannedJumps[#G.plannedJumps]
        G.planHeroCol = lastJump.col
        G.planHeroRow = lastJump.row
        TurnFlow.RefreshHighlightsForPlan()
        TurnFlow.UpdateThreatPreview(G.planHeroCol, G.planHeroRow)
        TurnFlow.UpdatePlanUI()
        GameUI.UpdateLog("已撤销，当前 " .. #G.plannedJumps .. " 步")
    end
end

function TurnFlow.CancelPlan()
    G.battle.phase = "PLAYER_SELECT"
    TurnFlow.ClearPlan()
    TurnFlow.RefreshHighlightsForSelect()
    GameUI.UpdateHUD()
    if G.btnPanel then G.btnPanel:SetVisible(false) end
    GameUI.UpdateLog("已取消，重新选择行动")
end

function TurnFlow.ConfirmJumps()
    if #G.plannedJumps == 0 then return end
    -- 记录英雄出发位置（用于绘制起点到第一落点的连线）
    G.jumpStartCol = G.battle.hero.col
    G.jumpStartRow = G.battle.hero.row
    G.battle.phase = "PLAYER_EXECUTE"
    G.validMoves = {}
    G.validJumps = {}
    if G.btnPanel then G.btnPanel:SetVisible(false) end
    GameUI.UpdateLog("执行跳跃...")
    AM.PlaySFX("dice_roll", 0.5)
    G.executeIndex = 0
    G.executeTimer = 0.15
end

function TurnFlow.ExecuteOneJump()
    G.executeIndex = G.executeIndex + 1
    if G.executeIndex > #G.plannedJumps then
        TurnFlow.FinishExecution()
        return
    end

    local jumpInfo = G.plannedJumps[G.executeIndex]

    -- === 执行前验证：棋盘可能因前一步的死亡效果而改变 ===
    -- 漩涡鳗打乱位置、毒蘑菇连锁击杀、冲击波击杀、岩石被清除等
    local jumpValid = true
    if jumpInfo.enemy then
        -- 敌人已死亡或已被移位
        if jumpInfo.enemy.hp <= 0
            or jumpInfo.enemy.col ~= jumpInfo.jumpedCol
            or jumpInfo.enemy.row ~= jumpInfo.jumpedRow then
            jumpValid = false
        end
        -- 飞跃先锋: 双敌跳时验证第二个敌人
        if jumpValid and jumpInfo.isDoubleJump and jumpInfo.enemy2 then
            if jumpInfo.enemy2.hp <= 0
                or jumpInfo.enemy2.col ~= jumpInfo.jumpedCol2
                or jumpInfo.enemy2.row ~= jumpInfo.jumpedRow2 then
                jumpValid = false
            end
        end
        -- 飞跃先锋: 三敌跳时验证第三个敌人
        if jumpValid and jumpInfo.isTripleJump and jumpInfo.enemy3 then
            if jumpInfo.enemy3.hp <= 0
                or jumpInfo.enemy3.col ~= jumpInfo.jumpedCol3
                or jumpInfo.enemy3.row ~= jumpInfo.jumpedRow3 then
                jumpValid = false
            end
        end
    elseif jumpInfo.isRockJump then
        -- 岩石已被清除（第三章跳岩石会清除障碍物）
        local obs = HexGrid.GetObstacleAt(G.battle.board, jumpInfo.jumpedCol, jumpInfo.jumpedRow)
        -- 也检查贝壳（贝壳不在 board.obstacles，需单独查）
        local shellHere = false
        if G.battle.board.shells then
            for _, s in ipairs(G.battle.board.shells) do
                if s.col == jumpInfo.jumpedCol and s.row == jumpInfo.jumpedRow then
                    shellHere = true
                    break
                end
            end
        end
        if not obs and not shellHere then
            jumpValid = false
        end
    end
    -- 落点被其他棋子/障碍物占据（漩涡鳗可能把敌人洗到落点上）
    if jumpValid and HexGrid.IsBlocked(G.battle.board, jumpInfo.col, jumpInfo.row) then
        jumpValid = false
    end

    if not jumpValid then
        -- 跳跃目标因连锁效果失效（冲击波/毒蘑菇/闪电击杀了后续目标）
        -- 如果落点仍然空闲，继续完成路线移动（不造成伤害，保持跳跃链连贯）
        local landingFree = not HexGrid.IsBlocked(G.battle.board, jumpInfo.col, jumpInfo.row)
        if landingFree then
            local hero = G.battle.hero
            hero.animFromCol = hero.col
            hero.animFromRow = hero.row
            hero.animTimer = 0.25
            hero.animMaxTimer = 0.25
            hero.animIsJump = true
            hero.col = jumpInfo.col
            hero.row = jumpInfo.row
            -- 目标虽失效但英雄仍完成了跳跃动作，计入combo
            G.battle.combo = G.battle.combo + 1
            if G.battle.combo > G.battle.maxCombo then
                G.battle.maxCombo = G.battle.combo
            end
            AM.PlayComboNote(G.battle.combo - 1) -- combo刚+1, 传入递增前的值
            Battle.ProcessBossAura(G.battle)
            Battle.CheckItemPickup(G.battle, jumpInfo.col, jumpInfo.row)
            GameUI.UpdateHUD()
            if G.battle.hero.hp <= 0 then
                if G.godMode then
                    G.battle.hero.hp = 1
                else
                    TurnFlow.ClearPlan()
                    TurnFlow.ShowResult("LOSE")
                    return
                end
            end
            local hasQuake = G.battle and Skills.Level(G.battle.skills, "quake_land") >= 1
            G.executeTimer = hasQuake and 0.5 or 0.3
        else
            -- 落点也被堵了，终止连跳链
            TurnFlow.FinishExecution()
        end
        return
    end

    local isLastStep = G.executeIndex == #G.plannedJumps
    -- 连跳音阶递进：do re mi fa sol la si do'
    AM.PlayComboNote(G.battle.combo or 0)
    Battle.ExecuteJump(G.battle, jumpInfo, isLastStep)
    GameUI.UpdateHUD()

    -- 第四章: 流沙冲击中断连跳——主角被推到新位置，后续跳跃作废
    if G.battle.quicksandInterrupted then
        G.battle.quicksandInterrupted = nil
        -- 显示醒目的"连跳被打断"提示
        Battle.AddFloatingText(G.battle, G.battle.hero.col, G.battle.hero.row,
            "⚠️连跳被打断!", {255, 180, 50, 255}, "combo", 2.0)
        TurnFlow.ClearPlan()
        TurnFlow.FinishExecution()
        return
    end

    -- 跳跃中途只检查失败（英雄死亡），不检查胜利
    -- 胜利判定延迟到所有跳跃+连击奖励结算完毕后再执行
    if G.battle.hero.hp <= 0 then
        if G.godMode then
            G.battle.hero.hp = 1
        else
            TurnFlow.ClearPlan()
            TurnFlow.ShowResult("LOSE")
            return
        end
    end

    -- 有震地落技能时加长间隔，让VFX充分展示
    local hasQuake = G.battle and Skills.Level(G.battle.skills, "quake_land") >= 1
    G.executeTimer = hasQuake and 0.5 or 0.3
end

-- ============================================================================
-- FinishExecution 子流程（拆分自原嵌套闭包，按调用顺序排列）
-- ============================================================================

-- 阶段3：触发连击奖励并决定下一 phase
-- rewardsPreTriggered: tier3 稻草人已提前触发，跳过重复触发
-- comboTriggered: mastery bonus 或 CheckComboRewards 已触发动画
function TurnFlow.ProceedWithRewards(rewardsPreTriggered, comboTriggered)
    if not rewardsPreTriggered and G.battle.combo >= 2 then
        comboTriggered = Battle.CheckComboRewards(G.battle)
    end

    -- 连击心得公告也需要等待动画播完
    if G.battle.comboMasteryAnnouncement then
        comboTriggered = true
    end

    local result = Battle.CheckEndCondition(G.battle)

    -- === 延迟结算：WIN 条件达成但玩家还有可跳格子，让其继续跳 ===
    -- Boss关 / 击杀数已满目标时不延迟
    local killsMetTarget = Battle.IsBossLevel(G.battle.level)
        or (G.battle.kills and G.battle.killTarget
            and G.battle.kills >= G.battle.killTarget)
    if result == "WIN" and not killsMetTarget then
        local hero = G.battle.hero
        local maxJumpW = G.battle.setEffects and SetEffects.GetMaxJumpOverCount(G.battle.setEffects) or 1
        local remainJumps = HexGrid.FindValidJumps(G.battle.board, hero.col, hero.row, maxJumpW, buildJumpOpts())
        if #remainJumps > 0 then
            G.battle.phase = "COMBO_REWARD_WAIT"
            G.comboRewardTimer = comboTriggered and 1.2 or 0.05
            G.comboRewardElapsed = 0
            G.battle._deferredWin = true
            pcall(GameUI.UpdateHUD)
            G.battle.comboSpotlightPending = nil
            G.battle.scarecrowTutorialPending = nil
            return
        end
    end

    if result or comboTriggered then
        G.battle.phase = "COMBO_REWARD_WAIT"
        G.comboRewardTimer = comboTriggered and 1.2 or 0.5
        G.comboRewardElapsed = 0
        pcall(GameUI.UpdateHUD)
        G.battle.comboSpotlightPending = nil
        G.battle.scarecrowTutorialPending = nil
    else
        TurnFlow.EndPlayerTurn()
    end
end

-- 阶段2：mastery bonus → spotlight 检测 → ProceedWithRewards
function TurnFlow.ExecuteComboAndProceed()
    local ok, err = pcall(function()
        -- === 嗜血猎魂：整条连跳链结束后统一弹出回血汇总 ===
        if G.battle and G.battle._soulHealAccum then
            local hero = G.battle.hero
            Battle.FlushSoulHunterAccum(G.battle, hero.col, hero.row)
        end

        if not G.battle then return end

        -- === v4.0 连击心得：先算 mastery bonus，再统一触发一次连击奖励 ===
        local comboTriggered = false
        if G.battle.combo >= 1 and G.battle.setEffects then
            local comboBonus = SetEffects.OnComboChainComplete(G.battle.setEffects, G.battle.combo)
            if comboBonus > 0 then
                local oldCombo = G.battle.combo
                G.battle.combo = G.battle.combo + comboBonus
                if G.battle.combo > G.battle.maxCombo then
                    G.battle.maxCombo = G.battle.combo
                end
                G.battle.comboMasteryAnnouncement = {
                    oldCombo = oldCombo,
                    newCombo = G.battle.combo,
                    bonus = comboBonus,
                    timer = 2.0,
                    maxTimer = 2.0,
                }
                AM.PlaySFX("gold_set_trigger", 1.5)
                G.battle.screenShake = (G.battle.screenShake or 0) + 0.4
                Battle.AddLog(G.battle, string.format("🔥 连击心得发动！连击 %d → %d！", oldCombo, G.battle.combo))
            end
        end

        -- === 聚光灯教学预检查（在 mastery bonus 之后，确保预览与实际触发一致）===
        local needSpotlight = false
        local spotlightInfo = nil
        if not G.battle.testMode and G.battle.combo >= 2 then
            local tier, reward = Battle.PeekComboReward(G.battle)
            if tier and reward then
                local seenTiers = G.playerData.seenComboTiers or {}
                if not seenTiers[tostring(tier)] then
                    needSpotlight = true
                    spotlightInfo = { tier = tier, name = reward.name, desc = reward.desc, icon = reward.icon }
                    if tier == 2 then
                        local dartTarget = Battle.PeekDartTarget(G.battle)
                        if dartTarget then spotlightInfo.dartTarget = dartTarget end
                    end
                end
            end
        end

        -- tier3 稻草人：先触发连击奖励生成稻草人，再弹聚光灯高亮实际位置
        local rewardsPreTriggered = false
        if needSpotlight and spotlightInfo and spotlightInfo.tier == 3 then
            if G.battle.combo >= 2 then
                comboTriggered = Battle.CheckComboRewards(G.battle)
            end
            if G.battle.comboMasteryAnnouncement then comboTriggered = true end
            rewardsPreTriggered = true
            if G.battle.scarecrowActive and G.battle.scarecrow then
                spotlightInfo.scarecrowPos = G.battle.scarecrow
            end
        end

        -- 如果需要聚光灯教学，先弹教学再触发奖励
        if needSpotlight then
            -- 切换到 COMBO_REWARD_WAIT，防止 PLAYER_EXECUTE 循环在下一帧再次调用 FinishExecution
            G.battle.phase = "COMBO_REWARD_WAIT"
            G.comboRewardTimer = 60  -- 大数值；comboSpotlightShowing=true 时 timer 不递减
            G.comboRewardElapsed = 0
            G.comboSpotlightShowing = true
            G._spotlightStuckTimer = 0
            log:Write(LOG_INFO, string.format("[PHASE] turn=%d → COMBO_REWARD_WAIT(spotlight tier=%s)",
                math.floor(G.battle.turn or 0), tostring(spotlightInfo.tier)))

            local showOk, showErr = pcall(GameUI.ShowComboSpotlight, spotlightInfo, function()
                G.comboSpotlightShowing = false
                G._spotlightStuckTimer = nil
                log:Write(LOG_INFO, string.format("[PHASE] turn=%d spotlight dismissed", math.floor(G.battle.turn or 0)))
                TurnFlow.ProceedWithRewards(rewardsPreTriggered, comboTriggered)
            end)

            if showOk then
                if not G.playerData.seenComboTiers then G.playerData.seenComboTiers = {} end
                G.playerData.seenComboTiers[tostring(spotlightInfo.tier)] = true
                PlayerData.Save(G.playerData)
            else
                log:Write(LOG_ERROR, "[ComboSpotlight] " .. tostring(showErr))
                G.comboSpotlightShowing = false
                -- phase 已切换为 COMBO_REWARD_WAIT，ProceedWithRewards 会覆盖 timer 为正确值
                TurnFlow.ProceedWithRewards(rewardsPreTriggered, comboTriggered)
            end
            return  -- 等待聚光灯回调（phase 已切换，不会再次进入 PLAYER_EXECUTE 循环）
        end

        -- 无需聚光灯，直接触发奖励
        TurnFlow.ProceedWithRewards(rewardsPreTriggered, comboTriggered)
    end)

    if not ok then
        log:Write(LOG_ERROR, "[FinishExecution] " .. tostring(err))
        local result = Battle.CheckEndCondition(G.battle)
        if result then pcall(TurnFlow.ShowResult, result)
        else pcall(TurnFlow.EndPlayerTurn) end
    end
end

function TurnFlow.FinishExecution()
    TurnFlow.ClearPlan()

    -- 最后一步落地后，应用漩涡鳗的延迟打乱效果
    if G.battle then
        Battle.ApplyPendingShuffles(G.battle)
    end

    TurnFlow.ExecuteComboAndProceed()
end

function TurnFlow.EndPlayerTurn()
    G.validMoves = {}
    G.validJumps = {}
    if G.btnPanel then G.btnPanel:SetVisible(false) end
    G.battle.phase = "ENEMY_TURN"
    log:Write(LOG_INFO, string.format("[PHASE] turn=%d → ENEMY_TURN (combo=%d spotlight=%s tutorial=%s)",
        math.floor(G.battle.turn or 0), math.floor(G.battle.combo or 0),
        tostring(G.comboSpotlightShowing), tostring(G.comboTutorialShowing)))
    GameUI.UpdateHUD()
    G.enemyTurnTimer = 0.6
end

function TurnFlow.ProcessEnemyTurn()
    local actions = Battle.ProcessEnemyTurn(G.battle)

    -- 第四章: 流沙回合推进（敌方行动后，流沙倒计时）
    Battle.ProcessQuicksandTurn(G.battle)

    pcall(GameUI.UpdateHUD)  -- pcall 保护，防止 HUD 崩溃阻塞胜负检查

    local result = Battle.CheckEndCondition(G.battle)
    if result then
        TurnFlow.ShowResult(result)
        return
    end

    -- 时间冻结：actions 为空表
    if #actions == 0 then
        G.enemyAnimWait = true
        G.enemyTurnTimer = 0.5
        G.enemyTurnMsg = "⏳ 时间冻结！敌人无法行动 — 你的回合"
        return
    end

    -- 统计各类行动
    local attackCount = 0
    local moveCount = 0
    local bossActCount = 0
    local specialCount = 0  -- dormant/shelled/frozen/idle
    for _, act in ipairs(actions) do
        local t = act.type
        if t == "attack" then
            attackCount = attackCount + 1
        elseif t == "move" then
            moveCount = moveCount + 1
        elseif t == "boss_shield" or t == "boss_summon" or t == "boss_aoe"
            or t == "boss_smoke" or t == "boss_eruption"
            or t == "boss_tentacle" or t == "boss_whirlpool"
            or t == "boss_shrink" then
            bossActCount = bossActCount + 1
        elseif t == "dormant" or t == "shelled" or t == "frozen" or t == "idle" then
            specialCount = specialCount + 1
        end
    end

    -- 构建回合摘要
    local parts = {}
    if attackCount > 0 then
        parts[#parts + 1] = attackCount .. "次攻击"
    end
    if moveCount > 0 then
        parts[#parts + 1] = moveCount .. "次移动"
    end
    if bossActCount > 0 then
        parts[#parts + 1] = "Boss施放技能"
    end

    local msg = "你的回合"
    if #parts > 0 then
        msg = "敌人: " .. table.concat(parts, ", ") .. " — 你的回合"
    end

    G.enemyAnimWait = true
    G.enemyTurnTimer = 0.35
    G.enemyTurnMsg = msg
end

-- 通用失败弹窗（ShowResult 和看门狗共用，确保始终能弹出）
local function CreateDefeatPopup()
    -- 防止重复创建
    if G._defeatPopupShown then return end
    G._defeatPopupShown = true

    local ok, err = pcall(function()
        if not G.battle then return end
        local isEndless = G.battle.isEndless
        local wave = G.battle.endlessWave or 1
        -- 失败时统一结算（幂等，后续 ReturnToMenu/RestartGame 不会重复执行）
        SettleBattleRewards()

        local infoText
        if isEndless then
            local best = G.playerData.highestEndlessWave or wave
            infoText = string.format("🌀 无尽第%d波\n坚持了 %d 回合", math.floor(wave), math.floor(G.battle.turn or 0))
            if best >= wave then
                infoText = infoText .. string.format("\n历史最高: 第%d波", math.floor(best))
            end
        else
            local chapter, stage = Battle.GetChapterInfo(G.battle.level)
            local totalTurns = math.floor((G.battle.turnAccum or 0) + (G.battle.turn or 0))
            infoText = string.format("第%d章 第%d关\n坚持了 %d 回合", math.floor(chapter), math.floor(stage), totalTurns)
        end

        local UI = require("urhox-libs/UI")
        local defeatPopup
        defeatPopup = UI.Panel {
            position = "absolute", top = 0, left = 0, right = 0, bottom = 0,
            zIndex = 900,
            justifyContent = "center", alignItems = "center",
            backgroundColor = {0, 0, 0, 160},
            children = {
                UI.Panel {
                    width = 280, paddingTop = 28, paddingBottom = 22,
                    paddingLeft = 24, paddingRight = 24,
                    alignItems = "center", borderRadius = 18,
                    backgroundColor = {30, 28, 50, 240},
                    borderWidth = 1, borderColor = isEndless and {160, 60, 200, 180} or {120, 60, 60, 180},
                    children = {
                        UI.Label {
                            text = isEndless and "💀 无尽终结" or "💀 闯关失败",
                            fontSize = 28,
                            fontColor = isEndless and {200, 80, 255, 255} or {255, 100, 100, 255},
                            fontWeight = "bold",
                        },
                        UI.Label { text = infoText, fontSize = 18,
                            fontColor = {190, 185, 220, 220}, textAlign = "center",
                            marginTop = 12, numberOfLines = 5 },
                        UI.Button {
                            text = isEndless and "🌀 再挑战" or "🔄 重新挑战",
                            variant = "primary",
                            width = 220, height = 48, fontSize = 21, marginTop = 20,
                            borderRadius = 24,
                            backgroundGradient = {
                                type = "linear", direction = "to-bottom",
                                from = isEndless and {120, 40, 200, 255} or {60, 140, 220, 255},
                                to   = isEndless and {80,  20, 140, 255} or {40, 100, 180, 255},
                            },
                            fontColor = {255, 255, 255, 255},
                            fontWeight = "bold",
                            pressedBackgroundColor = isEndless and {70, 15, 120, 255} or {35, 90, 160, 255},
                            boxShadow = {
                                { x = 0, y = 3, blur = 10, spread = 0,
                                  color = isEndless and {80, 20, 120, 80} or {30, 80, 160, 80} },
                            },
                            onClick = function(self)
                                AM.PlaySFX("ui_click")
                                if defeatPopup then defeatPopup:SetVisible(false) end
                                if isEndless then
                                    TurnFlow.EnterEndless()
                                else
                                    TurnFlow.RetryCurrentLevel()
                                end
                            end,
                        },
                        UI.Button { text = "返回主菜单", variant = "secondary",
                            width = 220, height = 42, fontSize = 18, marginTop = 10,
                            borderRadius = 21,
                            backgroundColor = {52, 48, 78, 200},
                            fontColor = {160, 155, 195, 220},
                            onClick = function(self)
                                AM.PlaySFX("ui_click")
                                if defeatPopup then defeatPopup:SetVisible(false) end
                                G.callbacks.ReturnToMenu()
                            end,
                        },
                    },
                },
            },
        }
        UI.GetRoot():AddChild(defeatPopup)
        G._defeatPopupRef = defeatPopup
    end)
    if not ok then
        log:Write(LOG_ERROR, "[LOSE] CreateDefeatPopup FAILED: " .. tostring(err))
        G._defeatPopupShown = false  -- 允许重试
    end
end

function TurnFlow.ShowResult(result)
    -- 重入保护：如果已经在处理 WIN/LOSE，不重复执行
    if G.battle.phase == "WIN" or G.battle.phase == "LOSE" then
        return
    end
    -- 教程弹窗阻塞：教程显示期间不允许弹出技能选择/结算界面
    -- proceedAfterTutorials 会在教程关闭后正确触发 ShowResult
    if G.comboTutorialShowing or G.comboSpotlightShowing then

        return
    end
    G.battle.phase = result
    G.validMoves = {}
    G.validJumps = {}
    -- 用 pcall 保护 UpdateHUD，防止异常导致后续 ShowSkillSelect 不被调用
    pcall(GameUI.UpdateHUD)

    if result == "WIN" then
        AM.PlaySFX("victory")
        G._winShownAt = G.time or 0  -- 记录胜利触发时间，用于看门狗检测卡死
        local ok, err = pcall(function()
            if Battle.IsBossLevel(G.battle.level) then
                -- Boss关通关：显示恭喜通关界面，结束后返回主菜单
                local chapter = Battle.GetChapterInfo(G.battle.level)
                GameUI.UpdateLog(string.format("🎉 第%d章通关！Boss已击败！", chapter))
                G.battle.gold = G.battle.gold + 80
                Battle.AddFloatingText(G.battle, G.battle.hero.col, G.battle.hero.row,
                    "+80💰 Boss奖励!", {255, 215, 0, 255}, "combo")
                TurnFlow.ShowChapterClear(chapter)
            else
                TurnFlow.ShowSkillSelect()
            end
        end)
        if not ok then
            log:Write(LOG_ERROR, "[ShowResult WIN] " .. tostring(err))
            -- 出错时强制进入下一关，防止卡死
            pcall(TurnFlow.NextLevel)
        end
    else
        AM.PlaySFX("defeat")
        -- 启动英雄死亡倒地动画，延迟后再弹失败弹窗
        local hero = G.battle.hero
        local deathDuration = 1.2  -- 死亡动画时长（秒）
        hero._dead = true
        hero._deadStartTime = hero._gameTime or 0
        hero._deadDuration = deathDuration
        -- 延迟弹窗：等死亡动画播完再弹
        G._defeatPopupDelay = deathDuration + 0.3  -- 多等0.3秒留一拍
    end
end

--- 上报玩家进度到云端排行榜（公会排行榜用）
--- 上报进度到云端（也作为公开接口供启动时调用）
---@param pd table playerData
TurnFlow.UploadProgress = function(pd)
    if not clientCloud then return end
    local ok, err = pcall(function()
        local level       = pd.highestLevel or 1
        local runs        = pd.totalRuns or 0
        local endlessWave = pd.highestEndlessWave or 0
        -- 复合分数：进度高优先，同进度把数少优先（降序排列时自然正确）
        -- adventure_rank = level * 100000 + (99999 - clamp(runs, 0, 99999))
        local clampedRuns = math.max(0, math.min(runs, 99999))
        local adventureRank = level * 100000 + (99999 - clampedRuns)
        -- highest_level 作为冒险排行分数，endless_wave 作为无尽排行分数
        clientCloud:BatchSet()
            :SetInt("highest_level", level)
            :SetInt("total_runs", runs)
            :SetInt("endless_wave", endlessWave)
            :SetInt("adventure_rank", adventureRank)
            :Save("进度上报")
    end)
    if not ok then
        log:Write(LOG_WARNING, "[Cloud] UploadProgress failed: " .. tostring(err))
    end
end

function TurnFlow.ShowChapterClear(chapter)
    -- 通关Boss后，highestLevel 推进到下一章第一关（解锁下一章）
    local nextLevel = G.battle.level + 1
    if nextLevel > G.highestLevel then
        G.highestLevel = nextLevel
    end
    if nextLevel > (G.playerData.highestLevel or 1) then
        G.playerData.highestLevel = nextLevel
    end
    PlayerData.Save(G.playerData)
    TurnFlow.UploadProgress(G.playerData)

    -- 播放通关庆祝音效
    AM.PlaySFX("chapter_clear")

    -- 隐藏旧 resultPanel，用全新弹窗替代
    if G.resultPanel then G.resultPanel:SetVisible(false) end

    -- 章节主题数据
    local CHAPTER_THEME = {
        [1] = { icon = "🐙", name = "深渊海沟", color1 = {60, 140, 255}, color2 = {30, 80, 180} },
        [2] = { icon = "🌋", name = "烈焰山脉", color1 = {255, 140, 40}, color2 = {200, 60, 20} },
        [3] = { icon = "🪸", name = "珊瑚迷宫", color1 = {255, 120, 200}, color2 = {180, 60, 140} },
        [4] = { icon = "🏜️", name = "流沙荒漠", color1 = {210, 180, 100}, color2 = {160, 120, 50} },
    }
    local theme = CHAPTER_THEME[chapter] or { icon = "⭐", name = "未知领域", color1 = {200, 180, 60}, color2 = {160, 130, 30} }

    -- 统计数据
    local skillIcons = Skills.GetOwnedIcons(G.battle.skills)
    local skillLine = skillIcons ~= "" and ("技能: " .. skillIcons) or nil
    local goldLine = G.battle.gold > 0 and ("💰 +" .. G.battle.gold .. " 金币") or nil

    local UI = require("urhox-libs/UI")
    local clearPopup

    -- 星星粒子数据（用于 NanoVG 渲染特效）
    local particles = {}
    for i = 1, 30 do
        particles[i] = {
            x = math.random() * 340 - 170,
            y = math.random() * -400 - 50,
            vy = 30 + math.random() * 60,
            vx = math.random() * 40 - 20,
            size = 8 + math.random() * 14,
            rot = math.random() * 360,
            rotV = math.random() * 120 - 60,
            alpha = 0.5 + math.random() * 0.5,
            emoji = ({"⭐", "✨", "🌟", "💫", "🎉", "🏆"})[math.random(1, 6)],
            delay = math.random() * 1.5,
        }
    end
    local elapsed = 0.0

    -- 构建统计行
    local statChildren = {
        TurnFlow._MakeClearStatRow("⚔️ 历经回合", tostring(G.battle.turn)),
        TurnFlow._MakeClearStatRow("🔥 最大连跳", G.battle.maxCombo .. "x"),
        TurnFlow._MakeClearStatRow("💥 总伤害", tostring(G.battle.totalDamage)),
    }
    if goldLine then
        statChildren[#statChildren + 1] = TurnFlow._MakeClearStatRow("💰 获得金币", "+" .. G.battle.gold)
    end
    if skillLine then
        statChildren[#statChildren + 1] = UI.Label {
            text = skillLine, fontSize = 16,
            fontColor = {180, 170, 220, 200}, textAlign = "center", marginTop = 4,
        }
    end

    -- 是否有下一章（第4章为无尽模式入口，已开放）
    local maxChapter = 4
    local hasNextChapter = chapter < maxChapter

    -- 按钮区
    local btnChildren = {}
    if hasNextChapter then
        btnChildren[#btnChildren + 1] = UI.Button {
            text = "⚔️ 进入下一章", variant = "primary",
            width = 230, height = 52, fontSize = 22,
            borderRadius = 26,
            backgroundGradient = {
                type = "linear", direction = "to-bottom",
                from = {theme.color1[1], theme.color1[2], theme.color1[3], 255},
                to   = {theme.color2[1], theme.color2[2], theme.color2[3], 255},
            },
            fontColor = {255, 255, 255, 255}, fontWeight = "bold",
            pressedBackgroundColor = {theme.color2[1], theme.color2[2], theme.color2[3], 255},
            boxShadow = {
                { x = 0, y = 4, blur = 16, spread = 0, color = {theme.color1[1], theme.color1[2], theme.color1[3], 100} },
            },
            onClick = function(self)
                AM.PlaySFX("ui_click")
                if clearPopup then clearPopup:SetVisible(false) end
                G._chapterClearPopupRef = nil
                -- 进入下一章第一关
                TurnFlow.NextLevel()
            end,
        }
    end
    btnChildren[#btnChildren + 1] = UI.Button {
        text = "🏠 返回主菜单", variant = "secondary",
        width = 230, height = 46, fontSize = 19,
        borderRadius = 23, marginTop = hasNextChapter and 8 or 0,
        backgroundGradient = {
            type = "linear", direction = "to-bottom",
            from = {52, 48, 78, 255}, to = {35, 32, 58, 255},
        },
        borderWidth = 1, borderColor = {95, 85, 145, 140},
        fontColor = {190, 185, 225, 255},
        pressedBackgroundColor = {40, 36, 62, 255},
        onClick = function(self)
            AM.PlaySFX("ui_click")
            if clearPopup then clearPopup:SetVisible(false) end
            G._chapterClearPopupRef = nil
            TurnFlow.ReturnToMenu()
        end,
    }

    clearPopup = UI.Panel {
        position = "absolute", top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 950, justifyContent = "center", alignItems = "center",
        backgroundColor = {0, 0, 0, 0},  -- 淡入动画由 NanoVG 绘制背景
        -- NanoVG 自绘粒子特效层
        onRender = function(self, nvg)
            local al = self:GetAbsoluteLayout()
            elapsed = elapsed + (1.0 / 60.0)
            -- 半透明黑色背景（带淡入）
            local bgAlpha = math.min(180, elapsed * 300)
            nvgBeginPath(nvg)
            nvgRect(nvg, al.x, al.y, al.w, al.h)
            nvgFillColor(nvg, nvgRGBA(0, 0, 0, math.floor(bgAlpha)))
            nvgFill(nvg)
            -- 顶部金色光晕
            local glowAlpha = math.floor(math.min(60, elapsed * 80))
            local cx, cy = al.x + al.w / 2, al.y + al.h * 0.32
            local gr = al.w * 0.6
            local glowPaint = nvgRadialGradient(nvg, cx, cy, 0, gr,
                nvgRGBA(theme.color1[1], theme.color1[2], theme.color1[3], glowAlpha),
                nvgRGBA(theme.color1[1], theme.color1[2], theme.color1[3], 0))
            nvgBeginPath(nvg)
            nvgRect(nvg, cx - gr, cy - gr, gr * 2, gr * 2)
            nvgFillPaint(nvg, glowPaint)
            nvgFill(nvg)
            -- 飘落的星星/emoji 粒子
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            for _, p in ipairs(particles) do
                if elapsed > p.delay then
                    local t = elapsed - p.delay
                    local px = cx + p.x + p.vx * t
                    local py = al.y + p.y + p.vy * t
                    local a = math.max(0, p.alpha - t * 0.15)
                    if a > 0 and py < al.y + al.h + 30 then
                        nvgSave(nvg)
                        nvgFontSize(nvg, p.size)
                        nvgFillColor(nvg, nvgRGBA(255, 255, 255, math.floor(a * 255)))
                        nvgText(nvg, px, py, p.emoji)
                        nvgRestore(nvg)
                    end
                end
            end
        end,
        children = {
            UI.Panel {
                width = 310, paddingTop = 30, paddingBottom = 24,
                paddingLeft = 26, paddingRight = 26,
                alignItems = "center", borderRadius = 22,
                backgroundGradient = {
                    type = "linear", direction = "to-bottom",
                    from = {38, 42, 72, 248}, to = {22, 24, 48, 248},
                },
                borderWidth = 1.5, borderColor = {theme.color1[1], theme.color1[2], theme.color1[3], 120},
                boxShadow = {
                    { x = 0, y = 8, blur = 40, spread = 4, color = {theme.color1[1], theme.color1[2], theme.color1[3], 60} },
                    { x = 0, y = 0, blur = 1, spread = 0, color = {theme.color1[1], theme.color1[2], theme.color1[3], 30}, inset = true },
                },
                children = {
                    -- 大 emoji icon
                    UI.Label {
                        text = theme.icon, fontSize = 56,
                        textShadow = { offsetX = 0, offsetY = 3, blur = 12, color = {theme.color1[1], theme.color1[2], theme.color1[3], 120} },
                    },
                    -- 标题
                    UI.Label {
                        text = "🎉 恭喜通关！", fontSize = 32,
                        fontColor = {255, 225, 65, 255}, fontWeight = "bold", marginTop = 8,
                        textShadow = { offsetX = 0, offsetY = 2, blur = 10, color = {200, 160, 0, 100} },
                        numberOfLines = 1,
                    },
                    -- 章节名
                    UI.Label {
                        text = string.format("第%d章 · %s", chapter, theme.name),
                        fontSize = 20, fontColor = {theme.color1[1], theme.color1[2], theme.color1[3], 255},
                        fontWeight = "bold", marginTop = 4,
                    },
                    -- 分割线
                    UI.Panel {
                        width = "80%", height = 1, marginTop = 16, marginBottom = 12,
                        backgroundGradient = {
                            type = "linear", direction = "to-right",
                            from = {theme.color1[1], theme.color1[2], theme.color1[3], 0},
                            to   = {theme.color1[1], theme.color1[2], theme.color1[3], 120},
                        },
                    },
                    -- 统计数据区
                    UI.Panel {
                        width = "100%", gap = 6, alignItems = "center",
                        children = statChildren,
                    },
                    -- 分割线
                    UI.Panel {
                        width = "80%", height = 1, marginTop = 12, marginBottom = 16,
                        backgroundGradient = {
                            type = "linear", direction = "to-right",
                            from = {theme.color1[1], theme.color1[2], theme.color1[3], 120},
                            to   = {theme.color1[1], theme.color1[2], theme.color1[3], 0},
                        },
                    },
                    -- 按钮区
                    UI.Panel {
                        width = "100%", alignItems = "center", gap = 0,
                        children = btnChildren,
                    },
                },
            },
        },
    }

    UI.GetRoot():AddChild(clearPopup)
    G._chapterClearPopupRef = clearPopup
end

--- 通关弹窗统计行辅助函数
function TurnFlow._MakeClearStatRow(label, value)
    local UI = require("urhox-libs/UI")
    return UI.Panel {
        width = "100%", flexDirection = "row",
        justifyContent = "space-between", paddingLeft = 10, paddingRight = 10,
        children = {
            UI.Label { text = label, fontSize = 17, fontColor = {160, 155, 195, 220} },
            UI.Label { text = value, fontSize = 17, fontColor = {255, 225, 130, 255}, fontWeight = "bold" },
        },
    }
end

function TurnFlow.RestartGame()
    -- Boss通关时，"再来一局"按钮已变为"返回主菜单"，直接返回
    if G.battle and Battle.IsBossLevel(G.battle.level) and G.battle.phase == "WIN" then
        TurnFlow.ReturnToMenu()
        return
    end
    SettleBattleRewards()
    if G.battle then
        G.playerData.totalRuns = (G.playerData.totalRuns or 0) + 1
        PlayerData.Save(G.playerData)
    end
    -- 从当前章节第一关重新开始（而非回到第一章）
    local restartLevel = 1
    if G.battle then
        local chapter = Battle.GetChapterInfo(G.battle.level)
        restartLevel = (chapter - 1) * Battle.LEVELS_PER_CHAPTER + 1
    end
    local bonus = PlayerData.GetTotalBonus(G.playerData)
    G.battle = Battle.New(bonus)
    Battle.GenerateLevel(G.battle, restartLevel)
    TurnFlow.SnapCameraToHero()
    TurnFlow.ClearPlan()
    if G.resultPanel then G.resultPanel:SetVisible(false) end
    if G.skillModal then G.skillModal:Close() end
    AM.UpdateBattleBGM(restartLevel)
    GameUI.UpdateBackground()  -- 重开时刷新全屏背景色（避免跨章节重开后背景不更新）
    checkAndShowEnemyIntro()
    TurnFlow.StartPlayerTurn()
    local chapter, _ = Battle.GetChapterInfo(restartLevel)
    GameUI.UpdateLog("第" .. chapter .. "章 重新开始！1/" .. Battle.LEVELS_PER_CHAPTER)
end

--- 从当前章节第一关重新开始（不回主菜单，直接重开）
function TurnFlow.RetryCurrentLevel()
    -- 清理失败弹窗
    if G._defeatPopupRef then
        pcall(function() G._defeatPopupRef:SetVisible(false) end)
    end
    G._defeatPopupShown = nil
    G._defeatPopupRef = nil

    -- 复用 RestartGame 的逻辑（从章节第一关重开）
    TurnFlow.RestartGame()
end

-- ============================================================================
-- 帧更新（游戏内逻辑 tick）
-- ============================================================================

function TurnFlow.Update(dt)
    if G.gamePhase ~= "GAME" then return end

    -- 英雄死亡动画延迟弹窗
    if G._defeatPopupDelay then
        G._defeatPopupDelay = G._defeatPopupDelay - dt
        if G._defeatPopupDelay <= 0 then
            G._defeatPopupDelay = nil
            CreateDefeatPopup()
        end
    end

    -- 寄居蟹救援动画更新（第三章）
    if G.battle then
        local anyRescued = Battle.UpdateCrabAnimation(G.battle, dt)
        -- 寄居蟹动画完成后重新检查胜利条件
        -- COMBO_REWARD_WAIT 阶段由自己的 timer 流程结算胜负，这里不抢先
        if anyRescued and G.battle.phase ~= "WIN" and G.battle.phase ~= "LOSE" and G.battle.phase ~= "COMBO_REWARD_WAIT" then
            local result = Battle.CheckEndCondition(G.battle)
            if result then
                TurnFlow.ClearPlan()
                TurnFlow.ShowResult(result)
            end
        end
    end

    if G.battle and G.battle.phase == "PLAYER_EXECUTE" then
        G.executeTimer = G.executeTimer - dt
        if G.executeTimer <= 0 then
            -- 英雄落地后，应用漩涡鳗的延迟打乱效果
            local shuffleOk, shuffleErr = pcall(Battle.ApplyPendingShuffles, G.battle)
            if not shuffleOk then
                log:Write(LOG_WARNING, "ApplyPendingShuffles failed: " .. tostring(shuffleErr))
            end
            local jumpOk, jumpErr = pcall(TurnFlow.ExecuteOneJump)
            if not jumpOk then
                log:Write(LOG_ERROR, "ExecuteOneJump failed: " .. tostring(jumpErr))
                -- 跳跃执行崩溃，强制结束玩家回合以避免永久卡死
                G.executeTimer = 99
                local endOk, endErr = pcall(TurnFlow.FinishExecution)
                if not endOk then
                    log:Write(LOG_ERROR, "FinishExecution also failed: " .. tostring(endErr))
                    pcall(TurnFlow.EndPlayerTurn)
                end
            end
        end
    end

    -- 连击奖励等待：特效播完后再检查胜负，然后才进入敌人回合
    if G.battle and G.battle.phase == "COMBO_REWARD_WAIT" and G.comboRewardTimer then
        -- 连击教程弹窗期间暂停流程
        if G.comboTutorialShowing or G.comboSpotlightShowing then
            -- 不递减计时器，等弹窗/公告关闭后再继续
        else
        G.comboRewardTimer = G.comboRewardTimer - dt
        G.comboRewardElapsed = (G.comboRewardElapsed or 0) + dt
        -- 动态结束：如果没有待完成的 onComplete VFX 且已过最小等待时间，提前结束
        local hasOnCompleteVFX = false
        if G.battle.vfx then
            for _, v in ipairs(G.battle.vfx) do
                if v.onComplete or v.onHit then hasOnCompleteVFX = true; break end
            end
        end
        -- 检查 comboAnnouncement / comboMasteryAnnouncement 是否还在播放
        local annStillPlaying = (G.battle.comboAnnouncement and G.battle.comboAnnouncement.timer > 0)
            or (G.battle.comboMasteryAnnouncement and G.battle.comboMasteryAnnouncement.timer > 0)
            or (G.battle.leapPioneerAnnouncement and G.battle.leapPioneerAnnouncement.timer > 0)
        -- 最小等待时间：有异步VFX等0.8秒；有公告横幅在播等0.6s；否则0.1s
        local minWait
        if hasOnCompleteVFX then
            minWait = 0.8
        elseif annStillPlaying then
            minWait = 0.6
        else
            minWait = 0.1
        end
        -- 计时器到期 或 已过最小等待且无VFX/横幅 → 可以结束等待
        if (G.comboRewardTimer <= 0 and not annStillPlaying)
            or (not hasOnCompleteVFX and not annStillPlaying and G.comboRewardElapsed >= minWait) then
            -- 继续流程：检查胜负 → 敌人回合
            local function proceedAfterTutorials()
                G.comboRewardTimer = nil
                G.comboRewardElapsed = nil

                -- === 延迟结算：连击奖励动画播完后，如果之前标记了延迟WIN，回到PLAYER_SELECT ===
                if G.battle._deferredWin then
                    G.battle._deferredWin = nil
                    local hero = G.battle.hero
                    local maxJumpD = G.battle.setEffects and SetEffects.GetMaxJumpOverCount(G.battle.setEffects) or 1
                    local remainJumps = HexGrid.FindValidJumps(G.battle.board, hero.col, hero.row, maxJumpD, buildJumpOpts())
                    if #remainJumps > 0 then
                        G.battle.combo = 0  -- 重置连击计数，避免跨回合累积导致错误的高连击数
                        G.battle.phase = "PLAYER_SELECT"
                        TurnFlow.RefreshHighlightsForSelect()
                        pcall(GameUI.UpdateHUD)
                        return
                    end
                end

                local result = Battle.CheckEndCondition(G.battle)
                if result then
                    TurnFlow.ClearPlan()
                    TurnFlow.ShowResult(result)
                else
                    TurnFlow.EndPlayerTurn()
                end
            end

            proceedAfterTutorials()
        end
        end -- else (not comboTutorialShowing)
    end

    if G.battle and G.battle.phase == "ENEMY_TURN" and G.enemyTurnTimer > 0 then
        G.enemyTurnTimer = G.enemyTurnTimer - dt
        if G.enemyTurnTimer <= 0 then
            if G.enemyAnimWait then
                G.enemyAnimWait = false
                local ok, err = xpcall(TurnFlow.StartPlayerTurn, function(e)
                    return e .. "\n" .. debug.traceback("", 2)
                end)
                if not ok then
                    log:Write(LOG_ERROR, "StartPlayerTurn crashed: " .. tostring(err))
                    -- 崩溃恢复：强制进入 PLAYER_SELECT
                    G.battle.phase = "PLAYER_SELECT"
                    G.battle.combo = 0
                    pcall(GameUI.UpdateHUD)
                end
                pcall(GameUI.UpdateLog, G.enemyTurnMsg)
            else
                local ok, err = pcall(TurnFlow.ProcessEnemyTurn)
                if not ok then
                    log:Write(LOG_ERROR, "ProcessEnemyTurn crashed: " .. tostring(err))
                    -- 崩溃恢复：跳过敌人回合，直接进入玩家回合
                    G.enemyAnimWait = true
                    G.enemyTurnTimer = 0.3
                    G.enemyTurnMsg = "⚠️ 敌人行动异常 — 你的回合"
                end
            end
        end
    end

    -- 🔴 看门狗安全网 (三重保护)
    if G.battle then
        local phase = G.battle.phase
        -- 保护1: 胜负条件已满足但 phase 不是 WIN/LOSE（逻辑层卡死）
        -- 注意: PLAYER_EXECUTE 和 COMBO_REWARD_WAIT 阶段有自己的结算逻辑，看门狗不应抢先
        if phase ~= "WIN" and phase ~= "LOSE" and phase ~= "COMBO_REWARD_WAIT" and phase ~= "PLAYER_EXECUTE" then
            local checkOk, result = pcall(Battle.CheckEndCondition, G.battle)
            if not checkOk then
                -- CheckEndCondition 本身崩溃，尝试简单判定
                result = nil
                if G.battle.hero and G.battle.hero.hp <= 0 and not G.godMode then
                    result = "LOSE"
                elseif (G.battle.kills or 0) >= (G.battle.killTarget or 5) then
                    result = "WIN"
                end
            end
            if result == "WIN" then
                -- 延迟结算：如果玩家还有可用跳跃，不触发看门狗WIN
                local hero = G.battle.hero
                local stillCanJump = false
                if hero and hero.hp > 0 then
                    local maxJumpS = G.battle.setEffects and SetEffects.GetMaxJumpOverCount(G.battle.setEffects) or 1
                    local rj = HexGrid.FindValidJumps(G.battle.board, hero.col, hero.row, maxJumpS, buildJumpOpts())
                    stillCanJump = #rj > 0
                end
                if stillCanJump then
                    G._winWatchdogTimer = nil  -- 还能跳，重置看门狗
                else
                    if not G._winWatchdogTimer then
                        G._winWatchdogTimer = 0
                    end
                    G._winWatchdogTimer = G._winWatchdogTimer + dt
                    if G._winWatchdogTimer >= 0.3 then
                        G._winWatchdogTimer = nil
                        TurnFlow.ClearPlan()
                        pcall(TurnFlow.ShowResult, "WIN")
                    end
                end
            elseif result == "LOSE" then
                -- 英雄已死但 phase 未切换，立即触发失败结算
                TurnFlow.ClearPlan()
                pcall(TurnFlow.ShowResult, "LOSE")
            else
                G._winWatchdogTimer = nil
            end
        else
            G._winWatchdogTimer = nil
        end
        -- 保护2: phase 已经是 WIN 但 UI 卡死（ShowSkillSelect 崩溃等）
        -- 如果 phase="WIN" 超过 3 秒还没进入下一关，强制推进
        if phase == "WIN" and G._winShownAt then
            local elapsed = (G.time or 0) - G._winShownAt
            if elapsed >= 3.0 then
                G._winShownAt = nil
                pcall(TurnFlow.NextLevel)
            end
        end
        -- 保护3: phase 是 WIN 但 _winShownAt 已被清除（技能面板弹出后）
        -- 仅在技能 Modal 未打开时生效（Modal 打开 = 玩家正在选技能，不是卡死）
        local skillModalOpen = G.skillModal and G.skillModal:IsOpen()
        if phase == "WIN" and not G._winShownAt and not skillModalOpen then
            if not G._winPhaseStuckTimer then
                G._winPhaseStuckTimer = 0
            end
            G._winPhaseStuckTimer = G._winPhaseStuckTimer + dt
            if G._winPhaseStuckTimer >= 5.0 then
                G._winPhaseStuckTimer = nil
                if G.skillModal then pcall(G.skillModal.Close, G.skillModal) end
                pcall(TurnFlow.NextLevel)
            end
        else
            G._winPhaseStuckTimer = nil
        end

        -- 保护4: ENEMY_TURN 超时看门狗（防止敌人回合卡死）
        -- 如果 phase 停留在 ENEMY_TURN 超过 5 秒且 timer 已失效，强制推进
        if phase == "ENEMY_TURN" then
            if not G._enemyTurnStuckTimer then
                G._enemyTurnStuckTimer = 0
            end
            G._enemyTurnStuckTimer = G._enemyTurnStuckTimer + dt
            if G._enemyTurnStuckTimer >= 5.0 then
                -- 打印关键现场信息，方便从玩家反馈日志中定位原因
                local b = G.battle
                local enemies = b and b.board and HexGrid.GetTeamPieces(b.board, "enemy") or {}
                local enemyInfo = {}
                for _, e in ipairs(enemies) do
                    if e.hp > 0 then
                        local moves = HexGrid.FindValidMoves(b.board, e.col, e.row)
                        enemyInfo[#enemyInfo+1] = string.format("%s(%d,%d)hp=%d moves=%d",
                            e.enemyType or "?", e.col, e.row, e.hp, #moves)
                    end
                end
                local hero = b and b.hero
                local heroInfo = hero and string.format("hero(%d,%d)hp=%d", hero.col, hero.row, hero.hp) or "no hero"
                log:Write(LOG_WARNING, string.format(
                    "ENEMY_TURN watchdog: stuck>5s | turn=%d level=%d | %s | enemies=[%s]",
                    b and b.turn or -1,
                    b and b.level or -1,
                    heroInfo,
                    table.concat(enemyInfo, ", ")
                ))
                G._enemyTurnStuckTimer = nil
                G.enemyAnimWait = false
                G.enemyTurnTimer = 0
                local ok, err = xpcall(TurnFlow.StartPlayerTurn, function(e)
                    return e .. "\n" .. debug.traceback("", 2)
                end)
                if not ok then
                    log:Write(LOG_ERROR, "Watchdog StartPlayerTurn failed: " .. tostring(err))
                    G.battle.phase = "PLAYER_SELECT"
                    G.battle.combo = 0
                    pcall(GameUI.UpdateHUD)
                end
            end
        else
            G._enemyTurnStuckTimer = nil
        end

        -- 保护4.5: LOSE 阶段卡死看门狗
        -- 弹窗未显示时 1.5 秒内强制创建弹窗
        if phase == "LOSE" then
            local popupVisible = G._defeatPopupShown
            if not popupVisible then
                if not G._loseStuckTimer then
                    G._loseStuckTimer = 0
                end
                G._loseStuckTimer = G._loseStuckTimer + dt
                if G._loseStuckTimer >= 1.5 then
                    log:Write(LOG_WARNING, "LOSE watchdog: no defeat popup for 1.5s, creating now")
                    G._loseStuckTimer = nil
                    pcall(CreateDefeatPopup)
                end
            else
                G._loseStuckTimer = nil
            end
        else
            G._loseStuckTimer = nil
        end

        -- 保护4.6: 英雄已死但 phase 未切换到 LOSE（卡在其他阶段）
        if phase ~= "WIN" and phase ~= "LOSE" then
            if G.battle.hero and G.battle.hero.hp <= 0 and not G.godMode then
                G._heroDeadTimer = (G._heroDeadTimer or 0) + dt
                if G._heroDeadTimer >= 0.8 then
                    log:Write(LOG_WARNING, "Hero dead but phase=" .. phase .. " for 0.8s, forcing LOSE")
                    G._heroDeadTimer = nil
                    TurnFlow.ClearPlan()
                    G.battle.phase = "LOSE"
                    pcall(CreateDefeatPopup)
                end
            else
                G._heroDeadTimer = nil
            end
        else
            G._heroDeadTimer = nil
        end

        -- 保护5: COMBO_REWARD_WAIT 超时看门狗
        if phase == "COMBO_REWARD_WAIT" then
            -- 聚光灯卡死：回调未触发超过60秒，强制跳过（这是真实卡死，不是玩家在阅读）
            if G.comboSpotlightShowing and G._spotlightStuckTimer ~= nil then
                G._spotlightStuckTimer = G._spotlightStuckTimer + dt
                if G._spotlightStuckTimer >= 60.0 then
                    log:Write(LOG_WARNING, string.format(
                        "spotlight watchdog: callback not fired for 60s (turn=%d), force dismiss",
                        G.battle and G.battle.turn or -1))
                    G._spotlightStuckTimer = nil
                    G.comboSpotlightShowing = false
                    G.comboRewardTimer = 0.1
                end
            end
            -- 聚光灯/教程弹窗显示期间重置计时器，玩家正在阅读教学，不算卡死
            if G.comboSpotlightShowing or G.comboTutorialShowing then
                G._comboWaitStuckTimer = nil
            else
                if not G._comboWaitStuckTimer then
                    G._comboWaitStuckTimer = 0
                end
                G._comboWaitStuckTimer = G._comboWaitStuckTimer + dt
                if G._comboWaitStuckTimer >= 5.0 then
                    log:Write(LOG_WARNING, "COMBO_REWARD_WAIT watchdog: stuck > 5s, force EndPlayerTurn")
                    G._comboWaitStuckTimer = nil
                    G.comboRewardTimer = nil
                    pcall(TurnFlow.EndPlayerTurn)
                end
            end
        else
            G._comboWaitStuckTimer = nil
        end

        -- 保护6: PLAYER_EXECUTE 卡死看门狗
        -- 判断标准：executeIndex 连续 3 秒没有推进（而不是总时长），说明单步卡死
        -- 正常每步 0.3~0.5s，玩家规划再多步也不会触发
        if phase == "PLAYER_EXECUTE" then
            local curIdx = G.executeIndex or 0
            if G._executeWatchdogLastIdx ~= curIdx then
                -- index 有推进，重置计时
                G._executeWatchdogLastIdx = curIdx
                G._executeWatchdogStuckTime = 0
            else
                G._executeWatchdogStuckTime = (G._executeWatchdogStuckTime or 0) + dt
                if G._executeWatchdogStuckTime >= 3.0 then
                    log:Write(LOG_WARNING, "PLAYER_EXECUTE watchdog: executeIndex=" .. tostring(curIdx) ..
                        " stuck > 3s (executeTimer=" .. tostring(G.executeTimer) ..
                        ", plannedJumps=" .. tostring(G.plannedJumps and #G.plannedJumps or 0) .. "), force FinishExecution")
                    G._executeWatchdogStuckTime = nil
                    G._executeWatchdogLastIdx = nil
                    G.executeTimer = 99  -- 阻止正常路径再次触发 ExecuteOneJump
                    local ok, err = pcall(TurnFlow.FinishExecution)
                    if not ok then
                        log:Write(LOG_ERROR, "Watchdog FinishExecution failed: " .. tostring(err))
                        pcall(TurnFlow.EndPlayerTurn)
                        if G.battle and G.battle.phase == "PLAYER_EXECUTE" then
                            -- 最后手段：直接切换 phase
                            G.battle.phase = "PLAYER_SELECT"
                            G.battle.combo = 0
                            TurnFlow.ClearPlan()
                            pcall(GameUI.UpdateHUD)
                        end
                    end
                end
            end
        else
            G._executeWatchdogLastIdx = nil
            G._executeWatchdogStuckTime = nil
        end
    end
end

--- 键盘事件处理
function TurnFlow.HandleKeyDown(key)
    if key == KEY_ESCAPE then
        if G.battle and G.battle.phase == "PLAYER_PLAN" then
            TurnFlow.CancelPlan()
        end
    end
    if key == KEY_RETURN then
        if G.battle and G.battle.phase == "PLAYER_PLAN" and #G.plannedJumps > 0 then
            TurnFlow.ConfirmJumps()
        end
    end
    if key == KEY_R then
        local phase = G.battle and G.battle.phase
        if phase == "PLAYER_SELECT" or phase == "PLAYER_PLAN" or phase == "GAME_OVER" then
            TurnFlow.RestartGame()
        end
    end
    if key == KEY_Z then
        if G.battle and G.battle.phase == "PLAYER_PLAN" and #G.plannedJumps > 0 then
            TurnFlow.UndoLastJump()
        end
    end
end

return TurnFlow
