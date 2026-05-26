-- ============================================================================
-- Combo Checkers - 跳棋战斗 Roguelite
-- 主入口: 初始化引擎 + 注册回调 + 事件分发
-- ============================================================================

local UI = require("urhox-libs/UI")
local PlayerData = require "PlayerData"
local G = require "GameState"
local TurnFlow = require "TurnFlow"
local MenuSystem = require "MenuSystem"
local MenuPages = require "MenuPages"
local AM = require "AudioManager"
local Battle = require "Battle"

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

    UI.Init({
        fonts = {
            { family = "sans", weights = {
                normal = "Fonts/MiSans-Regular.ttf",
            } }
        },
        scale = UI.Scale.DEFAULT,
    })

    -- 注册模块间回调
    RegisterCallbacks()

    -- 初始化音频系统
    AM.Init()

    -- 加载持久化存档
    G.playerData = PlayerData.Load()
    G.highestLevel = G.playerData.highestLevel or 1
    -- 若 Load 内部执行了迁移，立即持久化
    if G.playerData._chapterMigrated then
        PlayerData.Save(G.playerData)
    end

    G.selectedLevel = G.highestLevel
    G.selectedChapter = math.min(3, math.ceil(G.highestLevel / 10))  -- 第4章暂时隐藏

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
        return
    end

    TurnFlow.Update(dt)
end

---@param eventType string
---@param eventData KeyDownEventData
function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()
    if G.gamePhase == "MENU" then return end
    TurnFlow.HandleKeyDown(key)
end
