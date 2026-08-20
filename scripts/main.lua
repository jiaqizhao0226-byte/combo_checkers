-- ============================================================================
-- Combo Checkers - 跳棋战斗 Roguelite
-- 主入口: 初始化引擎 + 注册回调 + 事件分发
-- ============================================================================

local UI = require("urhox-libs/UI")
local UITheme = require "UITheme"
local PlayerData = require "PlayerData"
local G = require "GameState"
local TurnFlow = require "TurnFlow"
local MenuSystem = require "MenuSystem"
local MenuPages = require "MenuPages"
local AM = require "AudioManager"
local Battle = require "Battle"
-- local TestPanel = require "TestPanel"  -- 测试入口发布时关闭

-- ============================================================================
-- 注册模块间回调（解耦 UI 按钮 → 流程函数）
-- ============================================================================

local function RegisterCallbacks()
    G.callbacks.HandleCellClick = TurnFlow.HandleCellClick
    G.callbacks.ConfirmJumps    = TurnFlow.ConfirmJumps
    G.callbacks.UndoLastJump    = TurnFlow.UndoLastJump
    G.callbacks.CancelPlan      = TurnFlow.CancelPlan
    G.callbacks.RestartGame     = TurnFlow.RestartGame
    G.callbacks.ReturnToMenu    = TurnFlow.ReturnToMenu
    G.callbacks.EnterGame       = TurnFlow.EnterGame
    G.callbacks.EnterEndless    = TurnFlow.EnterEndless
    G.callbacks.OnSkillSelected = TurnFlow.OnSkillSelected
end

-- ============================================================================
-- 生命周期
-- ============================================================================

function Start()
    graphics.windowTitle = "Combo Checkers"

    UITheme.Init(UI)

    print(string.format("[UI] physical=%dx%d dpr=%.2f scale=%.3f base=%.1fx%.1f",
        graphics:GetWidth(), graphics:GetHeight(), graphics:GetDPR(),
        UI.GetScale(), UI.GetWidth(), UI.GetHeight()))

    -- 注册模块间回调
    RegisterCallbacks()

    -- 初始化音频系统
    AM.Init()

    -- 加载持久化存档
    G.playerData = PlayerData.Load()
    G.highestLevel = G.playerData.highestLevel or 1
    -- 若 Load 内部执行了迁移或恢复操作，立即持久化
    if G.playerData._chapterMigrated or G.playerData._recoveredFromBackup or G.playerData._recoveredFromCorruption then
        PlayerData.Save(G.playerData)
        G.playerData._recoveredFromBackup = nil
        G.playerData._recoveredFromCorruption = nil
    end

    -- 启动时上报一次进度（确保 adventure_rank 字段存在，兼容老玩家）
    TurnFlow.UploadProgress(G.playerData)

    G.selectedLevel = G.highestLevel
    G.selectedChapter = math.min(5, math.ceil(G.highestLevel / Battle.LEVELS_PER_CHAPTER))

    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("KeyDown", "HandleKeyDown")

    -- 显示菜单
    MenuSystem.CreateMenuUI()
    AM.PlayBGM("menu")

end

function Stop()
    UI.Shutdown()
end

-- ============================================================================
-- 事件处理
-- ============================================================================

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    G.time = G.time + dt

    if G.gamePhase == "MENU" then
        -- 菜单阶段：更新商店轮播动画
        if G.menuTab == "shop" then
            MenuPages.UpdateShopCarousel(dt)
        end
        -- 开宝箱动画
        if G._gachaAnim then
            G._gachaAnim(dt)
        end
        -- 公会排行榜每小时自动刷新
        if G.menuTab == "guild" then
            MenuSystem.UpdateGuild(dt)
        end
        -- 无尽模式标签呼吸闪烁动画
        if G.menuEndlessHint and G.menuEndlessHint:IsVisible() then
            local breath = 0.5 + 0.5 * math.sin(G.time * 2.2)  -- 0~1 缓慢呼吸
            local alpha = 0.45 + 0.55 * breath  -- 0.45 ~ 1.0
            G.menuEndlessHint:SetStyle({ opacity = alpha })
        end
        return
    end

    TurnFlow.Update(dt)
end

---@param eventType string
---@param eventData KeyDownEventData
function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()
    -- 测试快捷键发布时关闭
    if G.gamePhase == "MENU" then return end
    TurnFlow.HandleKeyDown(key)
end
