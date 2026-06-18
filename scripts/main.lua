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
local TestPanel = require "TestPanel"  -- 测试中

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

    -- PixelForge 像素风格主题
    local PIXEL_SHADOW = {
        { x = 3, y = 3, blur = 0, color = {10, 10, 26, 204} },
        { x = -1, y = -1, blur = 0, color = {255, 255, 255, 48} },
    }
    local PixelForgeTheme = UI.Theme.ExtendTheme(UI.Theme.defaultTheme, {
        colors = {
            primary = {33, 189, 174, 255},
            primaryHover = {61, 208, 193, 255},
            primaryPressed = {25, 168, 153, 255},
            secondary = {108, 92, 231, 255},
            secondaryHover = {133, 119, 237, 255},
            secondaryPressed = {90, 75, 214, 255},
            background = {15, 15, 35, 255},
            surface = {27, 27, 58, 255},
            surfaceHover = {37, 37, 80, 255},
            text = {240, 240, 240, 255},
            textSecondary = {160, 160, 192, 255},
            textDisabled = {80, 80, 112, 255},
            border = {58, 58, 106, 255},
            borderFocus = {33, 189, 174, 255},
            disabled = {42, 42, 74, 255},
            disabledText = {80, 80, 112, 255},
            success = {80, 200, 120, 255},
            successHover = {102, 216, 142, 255},
            warning = {255, 217, 61, 255},
            warningHover = {255, 224, 102, 255},
            error = {255, 71, 87, 255},
            errorHover = {255, 107, 122, 255},
            info = {69, 170, 242, 255},
            overlay = {0, 0, 0, 180},
        },
        radius = { sm = 2, md = 2, lg = 4, xl = 4, full = 0 },
        componentDefaults = { borderRadius = 0 },
        components = {
            Button = { borderWidth = 2, boxShadow = PIXEL_SHADOW },
            TextField = { borderWidth = 2 },
            Checkbox = {
                borderWidth = 2,
                checkedBgColor = {33, 189, 174, 255},
                checkedBorderColor = {27, 176, 161, 255},
                checkmarkColor = {255, 255, 255, 255},
                hoverBorderColor = {33, 189, 174, 255},
            },
            Toggle = {
                borderWidth = 2, thumbSize = 18,
                thumbColor = {160, 160, 192, 255},
                thumbCheckedColor = {255, 255, 255, 255},
                thumbHoverColor = {240, 240, 240, 255},
                trackHoverBgColor = {37, 37, 80, 255},
                trackHoverBorderColor = {33, 189, 174, 255},
            },
            Slider = {
                borderWidth = 1,
                trackBgColor = {27, 27, 58, 255},
                trackFillColor = {33, 189, 174, 255},
                thumbColor = {33, 189, 174, 255},
                thumbBorderWidth = 2,
                thumbBorderColor = {27, 176, 161, 255},
            },
            Card = {
                borderWidth = 2,
                boxShadow = { { x = 4, y = 4, blur = 0, color = {10, 10, 26, 204} } },
            },
            Badge = { borderWidth = 1 },
            Alert = { borderWidth = 2 },
            Chip = { borderWidth = 2 },
            Avatar = { showBorder = true, shape = "square" },
            ProgressBar = { height = 16, borderWidth = 2 },
            Tabs = {
                borderWidth = 2,
                activeBorderColor = {33, 189, 174, 255},
                activeFontWeight = "700",
                inactiveTextColor = {160, 160, 192, 255},
                tabGap = 8,
            },
            Modal = {
                borderWidth = 2,
                boxShadow = { { x = 4, y = 4, blur = 0, color = {0, 0, 0, 204} } },
                headerBgColor = {20, 20, 46, 255},
                headerBorderWidth = 2,
                headerFullWidthBorder = true,
                footerBorderWidth = 2,
                footerFullWidthBorder = true,
                contentPadding = 16,
                footerPadding = {10, 16},
            },
            Toast = {
                borderWidth = 2,
                boxShadow = { { x = 3, y = 3, blur = 0, color = {10, 10, 26, 204} } },
                accentBarHeight = 32, accentBarWidth = 4, accentBarInset = 12,
                showIcon = false,
            },
            Tooltip = {
                borderWidth = 2,
                boxShadow = { { x = 2, y = 2, blur = 0, color = {10, 10, 26, 204} } },
                tooltipBgColor = {30, 30, 58, 240},
            },
            Dropdown = {
                borderWidth = 2,
                boxShadow = { { x = 3, y = 3, blur = 0, color = {10, 10, 26, 204} } },
                arrowColor = {33, 189, 174, 255},
                itemHoverBgColor = {37, 213, 194, 24},
                itemHoverTextColor = {33, 189, 174, 255},
            },
        },
    })

    UI.Init({
        theme = PixelForgeTheme,
        fonts = {
            { family = "sans", weights = {
                normal = "Fonts/FusionPixel-12px-Prop-zh_hans.ttf",
                bold = "Fonts/FusionPixel-12px-Prop-zh_hans-Bold.ttf",
            } },
            { family = "mono", weights = {
                normal = "Fonts/FusionPixel-12px-Mono-zh_hans.ttf",
            } },
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
    if key == KEY_T then TestPanel.Show() return end  -- 测试中
    if G.gamePhase == "MENU" then return end
    TurnFlow.HandleKeyDown(key)
end
