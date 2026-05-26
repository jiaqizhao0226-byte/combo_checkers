-- ============================================================================
-- TestPanel.lua - 套装试用面板
-- 一键穿戴金色6件套 → 重开当前关卡 → 实战体验套装效果
-- ============================================================================

local UI = require("urhox-libs/UI")
local AM = require "AudioManager"
local Equipment = require "Equipment"
local PlayerData = require "PlayerData"
local G = require "GameState"
local Battle = require "Battle"

local TestPanel = {}

---@type UIElement
local panelRoot = nil

--- 关闭面板
function TestPanel.Close()
    if panelRoot then
        panelRoot:Remove()
        panelRoot = nil
    end
    AM.PlaySFX("ui_popup_close")
end

--- 一键穿戴整套金色装备
local function equipFullGoldSet(setId)
    if not G.playerData then return end
    -- 先卸下所有已穿装备
    for _, slot in ipairs(Equipment.SLOT_ORDER) do
        if G.playerData.equipment[slot] then
            PlayerData.UnequipItem(G.playerData, slot)
        end
    end
    -- 直接写入6件金色
    for _, item in ipairs(Equipment.ITEMS) do
        if item.setId == setId then
            G.playerData.equipment[item.slot] = { id = item.id, rarity = "gold" }
        end
    end
end

--- 卸下所有装备
local function unequipAll()
    if not G.playerData then return end
    for _, slot in ipairs(Equipment.SLOT_ORDER) do
        G.playerData.equipment[slot] = nil
    end
end

--- 获取当前穿戴的套装id (如果是完整6件)
local function getCurrentSetId()
    if not G.playerData then return nil end
    local counts = Equipment.GetActiveSetCount(G.playerData.equipment)
    for setId, count in pairs(counts) do
        if count >= 6 then return setId end
    end
    -- 4件也算
    for setId, count in pairs(counts) do
        if count >= 4 then return setId end
    end
    return nil
end

--- 显示面板
function TestPanel.Show()
    AM.PlaySFX("ui_popup_open")
    if panelRoot then
        panelRoot:Remove()
        panelRoot = nil
    end

    -- 当前暴击率
    local critRate = 0
    if G.playerData then
        critRate = PlayerData.GetCritRate(G.playerData)
    end

    local currentSetId = getCurrentSetId()

    ---@type UIElement
    local statusLabel = nil
    ---@type UIElement
    local critLabel = nil
    local setBtns = {}

    --- 刷新选中状态
    local function refreshBtnStates(activeSetId)
        for sid, btn in pairs(setBtns) do
            local isActive = (sid == activeSetId)
            btn:SetStyle({
                borderColor = isActive
                    and {255, 200, 60, 220}
                    or  {80, 65, 140, 120},
                backgroundColor = isActive
                    and {55, 45, 95, 255}
                    or  {40, 34, 72, 255},
            })
        end
    end

    --- 穿上并刷新状态
    local function onSelectSet(setId)
        equipFullGoldSet(setId)
        currentSetId = setId
        local setDef = Equipment.GetSetDef(setId)
        if statusLabel and setDef then
            statusLabel:SetText("已穿戴: " .. setDef.icon .. " " .. setDef.name .. " 6/6 金")
            statusLabel:SetStyle({ fontColor = {255, 220, 80, 255} })
        end
        refreshBtnStates(setId)
        AM.PlaySFX("equip")
    end

    -- 构建套装选项卡
    local setCards = {}
    for _, setDef in ipairs(Equipment.SETS) do
        local isActive = (setDef.id == currentSetId)

        local card = UI.Panel {
            width = "100%",
            flexDirection = "row", alignItems = "center",
            gap = 10,
            paddingTop = 8, paddingBottom = 8,
            paddingLeft = 12, paddingRight = 12,
            borderRadius = 12,
            borderWidth = 1.5,
            borderColor = isActive
                and {255, 200, 60, 220}
                or  {80, 65, 140, 120},
            backgroundColor = isActive
                and {55, 45, 95, 255}
                or  {40, 34, 72, 255},
            pressedBackgroundColor = {60, 50, 105, 255},
            onClick = function(self)
                onSelectSet(setDef.id)
            end,
            children = {
                -- 套装图标+名称
                UI.Panel {
                    width = 110, gap = 2,
                    children = {
                        UI.Label {
                            text = setDef.icon .. " " .. setDef.name,
                            fontSize = 16, fontWeight = "bold",
                            fontColor = setDef.color,
                        },
                    },
                },
                -- 效果描述
                UI.Panel {
                    flexGrow = 1, flexShrink = 1, gap = 1,
                    children = {
                        UI.Label {
                            text = "4/6: " .. setDef.desc4,
                            fontSize = 12,
                            fontColor = {180, 175, 210, 200},
                        },
                        UI.Label {
                            text = "6/6: " .. setDef.desc6,
                            fontSize = 12,
                            fontColor = {220, 200, 130, 220},
                        },
                    },
                },
            },
        }
        setCards[#setCards + 1] = card
        setBtns[setDef.id] = card
    end

    panelRoot = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center", alignItems = "center",
        backgroundColor = {0, 0, 0, 160},
        backdropBlur = 4,
        zIndex = 950,
        onClick = function(self) TestPanel.Close() end,
        children = {
            UI.Panel {
                width = "92%", maxWidth = 420,
                maxHeight = "88%",
                backgroundGradient = {
                    type = "linear", direction = "to-bottom",
                    from = {38, 32, 68, 255}, to = {22, 18, 45, 255},
                },
                borderRadius = 16,
                borderWidth = 1.5,
                borderColor = {90, 70, 160, 150},
                paddingTop = 16, paddingBottom = 16,
                paddingLeft = 16, paddingRight = 16,
                gap = 10,
                boxShadow = {
                    { x = 0, y = 4, blur = 20, spread = 0, color = {0, 0, 0, 120} },
                },
                onClick = function(self) end, -- 阻止穿透
                children = {
                    -- 标题
                    UI.Label {
                        text = "🧪 套装试用",
                        fontSize = 22, fontWeight = "bold",
                        fontColor = {230, 225, 255, 255},
                        textAlign = "center", width = "100%",
                    },

                    -- 当前状态
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row", justifyContent = "space-between", alignItems = "center",
                        paddingLeft = 4, paddingRight = 4,
                        children = {
                            (function()
                                local setDef = currentSetId and Equipment.GetSetDef(currentSetId)
                                local txt = setDef
                                    and ("已穿戴: " .. setDef.icon .. " " .. setDef.name)
                                    or "未穿戴套装"
                                statusLabel = UI.Label {
                                    text = txt,
                                    fontSize = 14,
                                    fontColor = setDef and {255, 220, 80, 255} or {160, 155, 200, 180},
                                }
                                return statusLabel
                            end)(),
                            (function()
                                critLabel = UI.Label {
                                    text = "暴击: " .. critRate .. "%",
                                    fontSize = 13,
                                    fontColor = {255, 130, 100, 220},
                                }
                                return critLabel
                            end)(),
                        },
                    },

                    -- 无敌模式开关
                    (function()
                        local isGod = G.godMode == true
                        ---@type UIElement
                        local godBtn = nil
                        local function refreshGodBtn()
                            isGod = G.godMode == true
                            if godBtn then
                                godBtn:SetStyle({
                                    backgroundGradient = isGod
                                        and { type="linear", direction="to-right", from={120,60,20,255}, to={180,100,20,255} }
                                        or  { type="linear", direction="to-right", from={35,32,60,255}, to={50,45,85,255} },
                                    borderColor = isGod and {255,160,40,200} or {80,65,140,100},
                                })
                                godBtn:SetText(isGod and "🛡️ 无敌  ON" or "🛡️ 无敌  OFF")
                                godBtn:SetStyle({ fontColor = isGod and {255,220,100,255} or {160,155,200,180} })
                            end
                        end
                        godBtn = UI.Button {
                            text = isGod and "🛡️ 无敌  ON" or "🛡️ 无敌  OFF",
                            fontSize = 15, fontWeight = "bold",
                            width = "100%", height = 36,
                            borderRadius = 10,
                            backgroundGradient = isGod
                                and { type="linear", direction="to-right", from={120,60,20,255}, to={180,100,20,255} }
                                or  { type="linear", direction="to-right", from={35,32,60,255}, to={50,45,85,255} },
                            fontColor = isGod and {255,220,100,255} or {160,155,200,180},
                            borderWidth = 1,
                            borderColor = isGod and {255,160,40,200} or {80,65,140,100},
                            pressedBackgroundColor = {60,50,30,255},
                            onClick = function(self)
                                G.godMode = not G.godMode
                                AM.PlaySFX("ui_click")
                                refreshGodBtn()
                            end,
                        }
                        return godBtn
                    end)(),

                    -- 分隔线
                    UI.Panel { width = "100%", height = 1, backgroundColor = {80, 65, 140, 80} },

                    -- 提示
                    UI.Label {
                        text = "点击套装一键穿戴，重开后生效",
                        fontSize = 13, fontColor = {140, 135, 175, 150},
                        textAlign = "center", width = "100%",
                    },

                    -- 套装列表（滚动区）
                    UI.ScrollView {
                        width = "100%", flexGrow = 1, flexShrink = 1,
                        minHeight = 100,
                        children = {
                            UI.Panel {
                                width = "100%", gap = 6,
                                children = setCards,
                            },
                        },
                    },

                    -- 分隔线
                    UI.Panel { width = "100%", height = 1, backgroundColor = {80, 65, 140, 60} },

                    -- 暴击率调节
                    UI.Panel {
                        width = "100%", gap = 4,
                        children = {
                            UI.Panel {
                                width = "100%",
                                flexDirection = "row", justifyContent = "space-between", alignItems = "center",
                                children = {
                                    UI.Label {
                                        text = "⚔️ 测试暴击率",
                                        fontSize = 14, fontColor = {200, 195, 230, 230},
                                    },
                                    (function()
                                        critLabel = UI.Label {
                                            text = critRate .. "%",
                                            fontSize = 14, fontColor = {255, 130, 100, 255},
                                            fontWeight = "bold",
                                        }
                                        return critLabel
                                    end)(),
                                },
                            },
                            UI.Slider {
                                value = critRate,
                                min = 0, max = 60, step = 3,
                                width = "100%",
                                trackHeight = 5,
                                thumbSize = 20,
                                trackColor = {50, 42, 90, 255},
                                activeTrackColor = {220, 100, 80, 255},
                                thumbColor = {255, 140, 110, 255},
                                onChange = function(self, v)
                                    critRate = math.floor(v)
                                    if critLabel then
                                        critLabel:SetText(critRate .. "%")
                                    end
                                    -- 直接修改天赋等级来达到目标暴击率
                                    if G.playerData then
                                        local targetLevel = math.floor(critRate / 3) -- 每级+3%
                                        G.playerData.talents.crit = math.min(targetLevel, 10)
                                    end
                                end,
                            },
                        },
                    },

                    -- 分隔线
                    UI.Panel { width = "100%", height = 1, backgroundColor = {80, 65, 140, 60} },

                    -- 专用测试关卡
                    UI.Panel {
                        width = "100%", gap = 6,
                        children = {
                            UI.Label {
                                text = "🎯 专用测试关卡",
                                fontSize = 14, fontWeight = "bold",
                                fontColor = {200, 195, 230, 230},
                            },
                            UI.Label {
                                text = "自动穿戴对应套装，生成专属布局",
                                fontSize = 11, fontColor = {140, 135, 175, 140},
                            },
                            -- 第一行：飞跃先锋 + 连击心得
                            UI.Panel {
                                width = "100%",
                                flexDirection = "row", gap = 8,
                                children = {
                                    -- 飞跃先锋测试关
                                    UI.Button {
                                        text = "🦅 飞跃先锋",
                                        fontSize = 14, fontWeight = "bold",
                                        flexGrow = 1, height = 38,
                                        borderRadius = 10,
                                        backgroundGradient = {
                                            type = "linear", direction = "to-right",
                                            from = {40, 70, 120, 255}, to = {30, 100, 90, 255},
                                        },
                                        fontColor = {180, 230, 255, 255},
                                        borderWidth = 1,
                                        borderColor = {80, 140, 180, 150},
                                        pressedBackgroundColor = {50, 80, 100, 255},
                                        onClick = function(self)
                                            AM.PlaySFX("ui_click")
                                            equipFullGoldSet("leap_pioneer")
                                            if G.playerData then
                                                PlayerData.Save(G.playerData)
                                            end
                                            TestPanel.Close()
                                            -- 生成飞跃先锋测试关卡
                                            local TurnFlow = require "TurnFlow"
                                            local bonus = PlayerData.GetTotalBonus(G.playerData)
                                            G.battle = Battle.New(bonus)
                                            Battle.GenerateTestLevel_LeapPioneer(G.battle)
                                            TurnFlow.SnapCameraToHero()
                                            TurnFlow.ClearPlan()
                                            if G.resultPanel then G.resultPanel:SetVisible(false) end
                                            TurnFlow.StartPlayerTurn()
                                        end,
                                    },
                                    -- 连击心得测试关
                                    UI.Button {
                                        text = "🔥 连击心得",
                                        fontSize = 14, fontWeight = "bold",
                                        flexGrow = 1, height = 38,
                                        borderRadius = 10,
                                        backgroundGradient = {
                                            type = "linear", direction = "to-right",
                                            from = {120, 50, 30, 255}, to = {100, 80, 30, 255},
                                        },
                                        fontColor = {255, 210, 150, 255},
                                        borderWidth = 1,
                                        borderColor = {180, 100, 60, 150},
                                        pressedBackgroundColor = {100, 60, 40, 255},
                                        onClick = function(self)
                                            AM.PlaySFX("ui_click")
                                            equipFullGoldSet("combo_mastery")
                                            if G.playerData then
                                                PlayerData.Save(G.playerData)
                                            end
                                            TestPanel.Close()
                                            -- 生成连击心得测试关卡
                                            local TurnFlow = require "TurnFlow"
                                            local bonus = PlayerData.GetTotalBonus(G.playerData)
                                            G.battle = Battle.New(bonus)
                                            Battle.GenerateTestLevel_ComboMastery(G.battle)
                                            TurnFlow.SnapCameraToHero()
                                            TurnFlow.ClearPlan()
                                            if G.resultPanel then G.resultPanel:SetVisible(false) end
                                            TurnFlow.StartPlayerTurn()
                                        end,
                                    },
                                },
                            },
                            -- 第二行：飞跃先锋6/6 三连跳专项测试
                            UI.Panel {
                                width = "100%",
                                flexDirection = "row", gap = 8,
                                children = {
                                    UI.Button {
                                        text = "🦅✕3 三连跳(6/6)",
                                        fontSize = 14, fontWeight = "bold",
                                        flexGrow = 1, height = 38,
                                        borderRadius = 10,
                                        backgroundGradient = {
                                            type = "linear", direction = "to-right",
                                            from = {20, 90, 80, 255}, to = {40, 130, 60, 255},
                                        },
                                        fontColor = {160, 255, 210, 255},
                                        borderWidth = 1.5,
                                        borderColor = {80, 200, 140, 180},
                                        pressedBackgroundColor = {20, 70, 60, 255},
                                        onClick = function(self)
                                            AM.PlaySFX("ui_click")
                                            equipFullGoldSet("leap_pioneer")
                                            if G.playerData then
                                                PlayerData.Save(G.playerData)
                                            end
                                            TestPanel.Close()
                                            local TurnFlow = require "TurnFlow"
                                            local bonus = PlayerData.GetTotalBonus(G.playerData)
                                            G.battle = Battle.New(bonus)
                                            Battle.GenerateTestLevel_LeapPioneer6(G.battle)
                                            TurnFlow.SnapCameraToHero()
                                            TurnFlow.ClearPlan()
                                            if G.resultPanel then G.resultPanel:SetVisible(false) end
                                            TurnFlow.StartPlayerTurn()
                                        end,
                                    },
                                },
                            },
                            -- 第三行：嗜血套装 + 踏步斩
                            UI.Panel {
                                width = "100%",
                                flexDirection = "row", gap = 8,
                                children = {
                                    -- 嗜血套装测试关
                                    UI.Button {
                                        text = "🩸 嗜血套装",
                                        fontSize = 14, fontWeight = "bold",
                                        flexGrow = 1, height = 38,
                                        borderRadius = 10,
                                        backgroundGradient = {
                                            type = "linear", direction = "to-right",
                                            from = {110, 20, 30, 255}, to = {80, 10, 50, 255},
                                        },
                                        fontColor = {255, 160, 180, 255},
                                        borderWidth = 1,
                                        borderColor = {180, 60, 80, 150},
                                        pressedBackgroundColor = {90, 15, 25, 255},
                                        onClick = function(self)
                                            AM.PlaySFX("ui_click")
                                            equipFullGoldSet("soul_hunter")
                                            if G.playerData then
                                                PlayerData.Save(G.playerData)
                                            end
                                            TestPanel.Close()
                                            local TurnFlow = require "TurnFlow"
                                            local bonus = PlayerData.GetTotalBonus(G.playerData)
                                            G.battle = Battle.New(bonus)
                                            Battle.GenerateTestLevel_SoulHunter(G.battle)
                                            TurnFlow.SnapCameraToHero()
                                            TurnFlow.ClearPlan()
                                            if G.resultPanel then G.resultPanel:SetVisible(false) end
                                            TurnFlow.StartPlayerTurn()
                                        end,
                                    },
                                    -- 踏步斩技能测试关
                                    UI.Button {
                                        text = "⚔️ 踏步斩",
                                        fontSize = 14, fontWeight = "bold",
                                        flexGrow = 1, height = 38,
                                        borderRadius = 10,
                                        backgroundGradient = {
                                            type = "linear", direction = "to-right",
                                            from = {60, 40, 100, 255}, to = {90, 30, 70, 255},
                                        },
                                        fontColor = {200, 180, 255, 255},
                                        borderWidth = 1,
                                        borderColor = {130, 100, 200, 150},
                                        pressedBackgroundColor = {50, 30, 80, 255},
                                        onClick = function(self)
                                            AM.PlaySFX("ui_click")
                                            TestPanel.Close()
                                            local TurnFlow = require "TurnFlow"
                                            local bonus = PlayerData.GetTotalBonus(G.playerData)
                                            G.battle = Battle.New(bonus)
                                            Battle.GenerateTestLevel_StepStrike(G.battle)
                                            TurnFlow.SnapCameraToHero()
                                            TurnFlow.ClearPlan()
                                            if G.resultPanel then G.resultPanel:SetVisible(false) end
                                            TurnFlow.StartPlayerTurn()
                                        end,
                                    },
                                },
                            },
                        },
                    },

                    -- 分隔线
                    UI.Panel { width = "100%", height = 1, backgroundColor = {80, 65, 140, 60} },

                    -- Boss 测试关卡
                    UI.Panel {
                        width = "100%", gap = 6,
                        children = {
                            UI.Label {
                                text = "👹 Boss 测试",
                                fontSize = 14, fontWeight = "bold",
                                fontColor = {200, 195, 230, 230},
                            },
                            UI.Label {
                                text = "直接进入关底Boss战，含小怪和章节机制",
                                fontSize = 11, fontColor = {140, 135, 175, 140},
                            },
                            UI.Panel {
                                width = "100%",
                                flexDirection = "row", gap = 8,
                                children = {
                                    -- 第一章 Boss: 深渊海妖
                                    UI.Button {
                                        text = "🐙 深渊海妖",
                                        fontSize = 14, fontWeight = "bold",
                                        flexGrow = 1, height = 38,
                                        borderRadius = 10,
                                        backgroundGradient = {
                                            type = "linear", direction = "to-right",
                                            from = {40, 20, 90, 255}, to = {20, 50, 120, 255},
                                        },
                                        fontColor = {180, 160, 255, 255},
                                        borderWidth = 1,
                                        borderColor = {100, 80, 180, 150},
                                        pressedBackgroundColor = {30, 15, 70, 255},
                                        onClick = function(self)
                                            AM.PlaySFX("ui_click")
                                            TestPanel.Close()
                                            local TurnFlow = require "TurnFlow"
                                            local bonus = PlayerData.GetTotalBonus(G.playerData)
                                            G.battle = Battle.New(bonus)
                                            Battle.GenerateTestLevel_Boss_AbyssKraken(G.battle)
                                            AM.UpdateBattleBGM(10)  -- 第1章Boss关
                                            TurnFlow.SnapCameraToHero()
                                            TurnFlow.ClearPlan()
                                            if G.resultPanel then G.resultPanel:SetVisible(false) end
                                            TurnFlow.StartPlayerTurn()
                                        end,
                                    },
                                    -- 第二章 Boss: 熔岩领主
                                    UI.Button {
                                        text = "🌋 熔岩领主",
                                        fontSize = 14, fontWeight = "bold",
                                        flexGrow = 1, height = 38,
                                        borderRadius = 10,
                                        backgroundGradient = {
                                            type = "linear", direction = "to-right",
                                            from = {140, 50, 10, 255}, to = {100, 30, 0, 255},
                                        },
                                        fontColor = {255, 180, 80, 255},
                                        borderWidth = 1,
                                        borderColor = {200, 100, 30, 150},
                                        pressedBackgroundColor = {110, 40, 10, 255},
                                        onClick = function(self)
                                            AM.PlaySFX("ui_click")
                                            TestPanel.Close()
                                            local TurnFlow = require "TurnFlow"
                                            local bonus = PlayerData.GetTotalBonus(G.playerData)
                                            G.battle = Battle.New(bonus)
                                            Battle.GenerateTestLevel_Boss_LavaLord(G.battle)
                                            AM.UpdateBattleBGM(20)  -- 第2章Boss关
                                            TurnFlow.SnapCameraToHero()
                                            TurnFlow.ClearPlan()
                                            if G.resultPanel then G.resultPanel:SetVisible(false) end
                                            TurnFlow.StartPlayerTurn()
                                        end,
                                    },
                                    -- 第三章 Boss: 珊瑚守卫
                                    UI.Button {
                                        text = "🪸 珊瑚守卫",
                                        fontSize = 14, fontWeight = "bold",
                                        flexGrow = 1, height = 38,
                                        borderRadius = 10,
                                        backgroundGradient = {
                                            type = "linear", direction = "to-right",
                                            from = {20, 80, 100, 255}, to = {60, 40, 90, 255},
                                        },
                                        fontColor = {180, 240, 220, 255},
                                        borderWidth = 1,
                                        borderColor = {100, 160, 160, 150},
                                        pressedBackgroundColor = {30, 60, 80, 255},
                                        onClick = function(self)
                                            AM.PlaySFX("ui_click")
                                            TestPanel.Close()
                                            local TurnFlow = require "TurnFlow"
                                            local bonus = PlayerData.GetTotalBonus(G.playerData)
                                            G.battle = Battle.New(bonus)
                                            Battle.GenerateTestLevel_Boss_CoralGuardian(G.battle)
                                            AM.UpdateBattleBGM(30)  -- 第3章Boss关
                                            TurnFlow.SnapCameraToHero()
                                            TurnFlow.ClearPlan()
                                            if G.resultPanel then G.resultPanel:SetVisible(false) end
                                            TurnFlow.StartPlayerTurn()
                                        end,
                                    },
                                },
                            },
                        },
                    },

                    -- 分隔线
                    UI.Panel { width = "100%", height = 1, backgroundColor = {80, 65, 140, 60} },

                    -- 章节速达
                    UI.Panel {
                        width = "100%", gap = 6,
                        children = {
                            UI.Label {
                                text = "🗺️ 章节速达",
                                fontSize = 14, fontWeight = "bold",
                                fontColor = {200, 195, 230, 230},
                            },
                            UI.Label {
                                text = "直接跳到指定章节第1关游玩",
                                fontSize = 11, fontColor = {140, 135, 175, 140},
                            },
                            UI.Panel {
                                width = "100%",
                                flexDirection = "row", gap = 8,
                                children = {
                                    -- 第二章
                                    UI.Button {
                                        text = "🌋 第2章",
                                        fontSize = 14, fontWeight = "bold",
                                        flexGrow = 1, height = 38,
                                        borderRadius = 10,
                                        backgroundGradient = {
                                            type = "linear", direction = "to-right",
                                            from = {110, 45, 15, 255}, to = {80, 30, 10, 255},
                                        },
                                        fontColor = {255, 190, 100, 255},
                                        borderWidth = 1,
                                        borderColor = {180, 90, 40, 150},
                                        pressedBackgroundColor = {90, 35, 10, 255},
                                        onClick = function(self)
                                            AM.PlaySFX("ui_click")
                                            if G.playerData then PlayerData.Save(G.playerData) end
                                            TestPanel.Close()
                                            local TurnFlow = require "TurnFlow"
                                            local GameUI = require "GameUI"
                                            local bonus = PlayerData.GetTotalBonus(G.playerData)
                                            G.battle = Battle.New(bonus)
                                            Battle.GenerateLevel(G.battle, 11)
                                            TurnFlow.SnapCameraToHero()
                                            TurnFlow.ClearPlan()
                                            if G.resultPanel then G.resultPanel:SetVisible(false) end
                                            AM.UpdateBattleBGM(11)
                                            GameUI.UpdateBackground()
                                            TurnFlow.StartPlayerTurn()
                                        end,
                                    },
                                    -- 第三章
                                    UI.Button {
                                        text = "🪸 第3章",
                                        fontSize = 14, fontWeight = "bold",
                                        flexGrow = 1, height = 38,
                                        borderRadius = 10,
                                        backgroundGradient = {
                                            type = "linear", direction = "to-right",
                                            from = {15, 75, 90, 255}, to = {40, 55, 80, 255},
                                        },
                                        fontColor = {160, 240, 210, 255},
                                        borderWidth = 1,
                                        borderColor = {80, 150, 150, 150},
                                        pressedBackgroundColor = {20, 55, 70, 255},
                                        onClick = function(self)
                                            AM.PlaySFX("ui_click")
                                            if G.playerData then PlayerData.Save(G.playerData) end
                                            TestPanel.Close()
                                            local TurnFlow = require "TurnFlow"
                                            local GameUI = require "GameUI"
                                            local bonus = PlayerData.GetTotalBonus(G.playerData)
                                            G.battle = Battle.New(bonus)
                                            Battle.GenerateLevel(G.battle, 21)
                                            TurnFlow.SnapCameraToHero()
                                            TurnFlow.ClearPlan()
                                            if G.resultPanel then G.resultPanel:SetVisible(false) end
                                            AM.UpdateBattleBGM(21)
                                            GameUI.UpdateBackground()
                                            TurnFlow.StartPlayerTurn()
                                        end,
                                    },
                                    -- 第四章
                                    UI.Button {
                                        text = "🌀 第4章",
                                        fontSize = 14, fontWeight = "bold",
                                        flexGrow = 1, height = 38,
                                        borderRadius = 10,
                                        backgroundGradient = {
                                            type = "linear", direction = "to-right",
                                            from = {50, 20, 90, 255}, to = {30, 15, 70, 255},
                                        },
                                        fontColor = {200, 160, 255, 255},
                                        borderWidth = 1,
                                        borderColor = {130, 80, 200, 150},
                                        pressedBackgroundColor = {35, 15, 65, 255},
                                        onClick = function(self)
                                            AM.PlaySFX("ui_click")
                                            if G.playerData then PlayerData.Save(G.playerData) end
                                            TestPanel.Close()
                                            local TurnFlow = require "TurnFlow"
                                            local GameUI = require "GameUI"
                                            local bonus = PlayerData.GetTotalBonus(G.playerData)
                                            G.battle = Battle.New(bonus)
                                            Battle.GenerateLevel(G.battle, 31)
                                            TurnFlow.SnapCameraToHero()
                                            TurnFlow.ClearPlan()
                                            if G.resultPanel then G.resultPanel:SetVisible(false) end
                                            AM.UpdateBattleBGM(31)
                                            GameUI.UpdateBackground()
                                            TurnFlow.StartPlayerTurn()
                                        end,
                                    },
                                },
                            },
                        },
                    },

                    -- 分隔线
                    UI.Panel { width = "100%", height = 1, backgroundColor = {80, 65, 140, 60} },

                    -- 💰 一键加金币
                    UI.Panel {
                        width = "100%", gap = 4,
                        children = {
                            UI.Label {
                                text = "💰 测试资源",
                                fontSize = 14, fontWeight = "bold",
                                fontColor = {200, 195, 230, 230},
                            },
                            UI.Panel {
                                width = "100%",
                                flexDirection = "row", gap = 8,
                                children = {
                                    UI.Button {
                                        text = "💰 +10000 金币",
                                        fontSize = 14, fontWeight = "bold",
                                        flexGrow = 1, height = 38,
                                        borderRadius = 10,
                                        backgroundGradient = {
                                            type = "linear", direction = "to-right",
                                            from = {120, 100, 20, 255}, to = {100, 80, 10, 255},
                                        },
                                        fontColor = {255, 240, 140, 255},
                                        borderWidth = 1,
                                        borderColor = {180, 160, 60, 150},
                                        pressedBackgroundColor = {90, 75, 15, 255},
                                        onClick = function(self)
                                            AM.PlaySFX("item_pickup")
                                            if G.playerData then
                                                PlayerData.AddGold(G.playerData, 10000)
                                                PlayerData.Save(G.playerData)
                                                self:SetText("💰 已到账! (" .. G.playerData.gold .. ")")
                                            end
                                        end,
                                    },
                                },
                            },
                        },
                    },

                    -- 分隔线
                    UI.Panel { width = "100%", height = 1, backgroundColor = {80, 65, 140, 60} },

                    -- 底部按钮区
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row", gap = 8,
                        children = {
                            -- 卸下全部
                            UI.Button {
                                text = "🚫 卸下",
                                fontSize = 15,
                                flexGrow = 1, height = 40,
                                borderRadius = 12,
                                backgroundColor = {55, 35, 35, 255},
                                fontColor = {220, 150, 150, 255},
                                borderWidth = 1,
                                borderColor = {120, 60, 60, 130},
                                pressedBackgroundColor = {70, 40, 40, 255},
                                onClick = function(self)
                                    AM.PlaySFX("ui_click")
                                    unequipAll()
                                    currentSetId = nil
                                    if statusLabel then
                                        statusLabel:SetText("未穿戴套装")
                                        statusLabel:SetStyle({ fontColor = {160, 155, 200, 180} })
                                    end
                                    refreshBtnStates(nil)
                                end,
                            },
                            -- 穿戴并重开
                            UI.Button {
                                text = "⚡ 重开体验",
                                fontSize = 16, fontWeight = "bold",
                                flexGrow = 2, height = 40,
                                borderRadius = 12,
                                backgroundGradient = {
                                    type = "linear", direction = "to-right",
                                    from = {70, 55, 130, 255}, to = {50, 90, 70, 255},
                                },
                                fontColor = {230, 240, 220, 255},
                                borderWidth = 1,
                                borderColor = {100, 120, 100, 150},
                                pressedBackgroundColor = {55, 70, 55, 255},
                                onClick = function(self)
                                    AM.PlaySFX("ui_click")
                                    -- 保存并关闭面板
                                    if G.playerData then
                                        PlayerData.Save(G.playerData)
                                    end
                                    TestPanel.Close()
                                    -- 重开当前关卡
                                    local TurnFlow = require "TurnFlow"
                                    TurnFlow.RetryCurrentLevel()
                                end,
                            },
                        },
                    },

                    -- 关闭
                    UI.Button {
                        text = "关闭",
                        fontSize = 17, fontWeight = "bold",
                        width = "100%", height = 38,
                        borderRadius = 12,
                        backgroundGradient = {
                            type = "linear", direction = "to-bottom",
                            from = {70, 55, 130, 255}, to = {45, 35, 90, 255},
                        },
                        fontColor = {220, 215, 245, 255},
                        borderWidth = 1,
                        borderColor = {100, 80, 170, 130},
                        pressedBackgroundColor = {55, 40, 100, 255},
                        onClick = function(self)
                            TestPanel.Close()
                        end,
                    },
                },
            },
        },
    }

    local root = UI.GetRoot()
    if root then
        root:AddChild(panelRoot)
    end
end

return TestPanel
