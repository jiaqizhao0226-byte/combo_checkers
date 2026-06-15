---@diagnostic disable: assign-type-mismatch, param-type-mismatch, return-type-mismatch
-- ============================================================================
-- MenuPages.lua - 主菜单各标签页 UI 构建器
-- 天赋、商店(抽奖)、装备(全屏6槽+套装) 页面
-- ============================================================================

local UI = require("urhox-libs/UI")
local PlayerData = require "PlayerData"
local Equipment = require "Equipment"
local IconAtlas = require "IconAtlas"
local AM = require "AudioManager"
local G = require "GameState"

local MenuPages = {}

-- ============================================================================
-- 工具：稀有度颜色
-- ============================================================================

local RARITY_BORDER = {
    common = {140, 155, 175, 220},
    blue   = {70, 170, 255, 255},
    purple = {200, 120, 255, 255},
    gold   = {255, 200, 40, 255},
}

local RARITY_BG = {
    common = {52, 58, 75, 255},
    blue   = {38, 58, 95, 255},
    purple = {60, 38, 88, 255},
    gold   = {70, 55, 20, 255},
}

-- 稀有度渐变 (from = 亮, to = 暗)
local RARITY_GRAD_FROM = {
    common = {62, 68, 88, 255},
    blue   = {45, 68, 115, 255},
    purple = {75, 45, 105, 255},
    gold   = {80, 65, 25, 255},
}
local RARITY_GRAD_TO = {
    common = {42, 48, 65, 255},
    blue   = {30, 48, 82, 255},
    purple = {52, 30, 78, 255},
    gold   = {55, 42, 12, 255},
}

-- 稀有度阴影
local function RarityShadow(rarity)
    local bc = RARITY_BORDER[rarity] or RARITY_BORDER.common
    local glowAlpha = (rarity == "gold") and 50 or (rarity == "purple" and 35 or 20)
    return {
        { x = 0, y = 2, blur = 6, spread = 0, color = {0, 0, 0, 50} },
        { x = 0, y = 0, blur = 10, spread = 1, color = {bc[1], bc[2], bc[3], glowAlpha} },
        { x = 0, y = 1, blur = 3, spread = 0, color = {bc[1], bc[2], bc[3], 30}, inset = true },
    }
end

-- ============================================================================
-- 装备页面（全屏：英雄居中 + 左右各3槽 + 底部仓库）
-- ============================================================================

--- 创建装备槽位
---@param onReceiveDrop function|nil 当背包格子拖拽到此槽松手时的回调 function(x, y, widget)
local function BuildEquipSlot(slotId, equippedItem, size, onUnequip, dragCallbacks, onReceiveDrop)
    local slotName = Equipment.SLOT_NAMES[slotId] or slotId
    local slotIcon = Equipment.SLOT_ICONS[slotId] or "❓"

    if equippedItem then
        local display = Equipment.GetItemDisplay(equippedItem)
        if not display then return nil end
        local rarity = equippedItem.rarity or "common"
        local borderCol = RARITY_BORDER[rarity] or RARITY_BORDER.common
        local bgCol = RARITY_BG[rarity] or RARITY_BG.common
        -- 套装色条
        local setDef = display.setId and Equipment.GetSetDef(display.setId) or nil
        local setColor = setDef and setDef.color or nil

        local children = {}
        -- 套装色条（顶部）
        if setColor then
            children[#children + 1] = UI.Panel {
                width = "100%", height = 3,
                backgroundColor = setColor,
                borderRadius = 0,
                position = "absolute", top = 0, left = 0, right = 0,
            }
        end
        local iconSize = math.floor(size * 0.42)
        local iconPath = display.iconId and IconAtlas.GetPath(display.iconId) or nil
        if iconPath then
            children[#children + 1] = UI.Panel { backgroundImage = iconPath, width = iconSize, height = iconSize, backgroundFit = "contain" }
        else
            children[#children + 1] = UI.Label { text = display.icon, fontSize = math.floor(size * 0.38), textAlign = "center" }
        end
        children[#children + 1] = UI.Label {
            text = display.name,
            fontSize = 15, fontColor = borderCol,
            textAlign = "center", numberOfLines = 1,
        }

        local gFrom = RARITY_GRAD_FROM[rarity] or RARITY_GRAD_FROM.common
        local gTo   = RARITY_GRAD_TO[rarity] or RARITY_GRAD_TO.common

        local panelStyle = {
            width = size, height = size,
            backgroundGradient = {
                type = "linear", direction = "to-bottom",
                from = gFrom, to = gTo,
            },
            borderRadius = 0,
            borderWidth = 2,
            borderColor = borderCol,
            boxShadow = RarityShadow(rarity),
            justifyContent = "center", alignItems = "center",
            flexDirection = "column", gap = 1,
            overflow = "hidden",
        }

        if dragCallbacks then
            -- 支持拖拽脱下：用 Panel + onPointer* 事件
            local dragState = { pressing = false, dragging = false, startX = 0, startY = 0 }
            local DRAG_THRESHOLD = 10
            panelStyle.onPointerDown = function(event, widget)
                -- 清理上次可能残留的拖拽状态（防止 ghost 卡住）
                if dragState.dragging and dragCallbacks.onDragEnd then
                    dragCallbacks.onDragEnd(event.x, event.y)
                end
                dragState.pressing = true
                dragState.dragging = false
                dragState.startX = event.x
                dragState.startY = event.y
            end
            panelStyle.onPointerMove = function(event, widget)
                if not dragState.pressing then return end
                local dx = event.x - dragState.startX
                local dy = event.y - dragState.startY
                if not dragState.dragging then
                    if math.abs(dx) > DRAG_THRESHOLD or math.abs(dy) > DRAG_THRESHOLD then
                        dragState.dragging = true
                        if dragCallbacks.onDragStart then
                            dragCallbacks.onDragStart(event.x, event.y)
                        end
                    end
                else
                    if dragCallbacks.onDragMove then
                        dragCallbacks.onDragMove(event.x, event.y)
                    end
                end
            end
            panelStyle.onPointerUp = function(event, widget)
                -- 优先处理：来自背包的拖拽放置（本槽没有 pressing 说明按下在背包格子上）
                if not dragState.pressing then
                    if onReceiveDrop and G.dragItemIdx then
                        onReceiveDrop(event.x, event.y, widget)
                    end
                    return
                end
                dragState.pressing = false
                if dragState.dragging then
                    dragState.dragging = false
                    if dragCallbacks.onDragEnd then
                        dragCallbacks.onDragEnd(event.x, event.y)
                    end
                else
                    -- 短按 = 点击卸下
                    AM.PlaySFX("ui_equip")
                    if onUnequip then onUnequip(slotId) end
                end
            end
            -- OS 中断（通知栏/来电）时强制结束拖拽
            panelStyle.onPointerCancel = function(event, widget)
                if dragState.pressing and dragState.dragging and dragCallbacks.onDragEnd then
                    dragCallbacks.onDragEnd(event.x, event.y)
                end
                dragState.pressing = false
                dragState.dragging = false
            end
            panelStyle.children = children
            return UI.Panel(panelStyle)
        else
            panelStyle.pressedBackgroundColor = {gTo[1] - 8, gTo[2] - 8, gTo[3] - 8, 255}
            if onReceiveDrop then
                -- Button 不支持自定义 onPointerUp，改用 Panel 同时支持点击和接收拖拽放置
                local clickState = { pressing = false }
                panelStyle.onPointerDown = function(event, widget)
                    clickState.pressing = true
                end
                panelStyle.onPointerUp = function(event, widget)
                    -- 来自背包的拖拽放置
                    if not clickState.pressing then
                        if G.dragItemIdx then
                            onReceiveDrop(event.x, event.y, widget)
                        end
                        return
                    end
                    clickState.pressing = false
                    -- 短按 = 点击卸下
                    AM.PlaySFX("ui_equip")
                    if onUnequip then onUnequip(slotId) end
                end
                panelStyle.onPointerCancel = function(event, widget)
                    clickState.pressing = false
                end
                panelStyle.children = children
                return UI.Panel(panelStyle)
            else
                panelStyle.onClick = function(self)
                    AM.PlaySFX("ui_equip")
                    if onUnequip then onUnequip(slotId) end
                end
                panelStyle.children = children
                return UI.Button(panelStyle)
            end
        end
    else
        local iconPath = IconAtlas.GetPath(slotIcon)
        local iconSize = math.floor(size * 0.38)
        local emptyPanel = {
            width = size, height = size,
            backgroundGradient = {
                type = "linear", direction = "to-bottom",
                from = {45, 50, 65, 255}, to = {30, 34, 48, 255},
            },
            borderRadius = 0,
            borderWidth = 2,
            borderColor = {70, 75, 95, 180},
            borderStyle = "dashed",
            boxShadow = {
                { x = 0, y = 1, blur = 4, spread = 0, color = {0, 0, 0, 40} },
            },
            justifyContent = "center", alignItems = "center",
            flexDirection = "column", gap = 2,
            children = {
                iconPath
                    and UI.Panel { backgroundImage = iconPath, width = iconSize, height = iconSize, backgroundFit = "contain" }
                    or  UI.Label { text = "?", fontSize = math.floor(size * 0.32), fontColor = {80, 85, 110, 200}, textAlign = "center" },
                UI.Label {
                    text = slotName,
                    fontSize = 15, fontColor = {100, 110, 140, 200},
                    textAlign = "center",
                },
            },
        }
        -- 空槽接收拖拽放置：当背包格子拖来松手（onPointerUp 在槽位上触发）时触发 onReceiveDrop
        if onReceiveDrop then
            emptyPanel.onPointerUp = function(event, widget)
                onReceiveDrop(event.x, event.y, widget)
            end
        end
        return UI.Panel(emptyPanel)
    end
end

--- 创建装备详情弹窗内容
---@param item table 装备实例 { id, rarity }
---@param equipment table 当前已装备表
---@return table UI.Panel 弹窗面板
function MenuPages.BuildItemDetailPopup(item, equipment)
    local display = Equipment.GetItemDisplay(item)
    if not display then return nil end
    local rarityId = Equipment.RARITY_MIGRATE[item.rarity] or item.rarity
    local rarityDef = Equipment.GetRarityDef(rarityId)
    local stats = Equipment.GetItemStats(item.id, rarityId)
    local itemDef = Equipment.GetItemDef(item.id)
    local borderCol = RARITY_BORDER[rarityId] or RARITY_BORDER.common
    local bgCol = RARITY_BG[rarityId] or RARITY_BG.common
    local slotName = Equipment.SLOT_NAMES[itemDef.slot] or ""

    local children = {}

    -- 顶部：图标 + 名称 + 稀有度
    local iconSize = 56
    local iconPath = display.iconId and IconAtlas.GetPath(display.iconId) or nil
    children[#children + 1] = UI.Panel {
        width = "100%", flexDirection = "row", alignItems = "center", gap = 12,
        children = {
            UI.Panel {
                width = iconSize + 10, height = iconSize + 10,
                backgroundColor = bgCol,
                borderRadius = 0, borderWidth = 2.5, borderColor = borderCol,
                justifyContent = "center", alignItems = "center",
                children = {
                    iconPath
                        and UI.Panel { backgroundImage = iconPath, width = iconSize, height = iconSize, backgroundFit = "contain" }
                        or  UI.Label { text = display.icon, fontSize = 38, textAlign = "center" },
                },
            },
            UI.Panel {
                flexGrow = 1, flexShrink = 1, gap = 3,
                children = {
                    UI.Label { text = display.name, fontSize = 22, fontWeight = "bold", fontColor = borderCol },
                    UI.Panel { flexDirection = "row", gap = 6, children = {
                        UI.Label { text = rarityDef and rarityDef.name or "", fontSize = 15, fontColor = borderCol },
                        UI.Label { text = "·", fontSize = 15, fontColor = {120, 130, 150, 150} },
                        UI.Label { text = slotName, fontSize = 15, fontColor = {160, 170, 190, 220} },
                    }},
                },
            },
        },
    }

    -- 分隔线
    children[#children + 1] = UI.Panel {
        width = "100%", height = 1,
        backgroundGradient = { type = "linear", direction = "to-right",
            from = {borderCol[1], borderCol[2], borderCol[3], 60},
            to = {borderCol[1], borderCol[2], borderCol[3], 10},
        },
    }

    -- 属性
    local statChildren = {}
    local statIcons = { atk = "equip_weapon", def = "hud_shield", hp = "hud_hp" }
    local statNames = { atk = "攻击", def = "防御", hp = "生命" }
    local statColors = { atk = {255, 130, 100, 255}, def = {100, 180, 255, 255}, hp = {100, 255, 130, 255} }
    for _, key in ipairs({"atk", "def", "hp"}) do
        if stats[key] and stats[key] > 0 then
            statChildren[#statChildren + 1] = UI.Panel {
                flexDirection = "row", alignItems = "center", gap = 5,
                children = {
                    UI.Panel { backgroundImage = IconAtlas.GetPath(statIcons[key]), width = 20, height = 20, backgroundFit = "contain" },
                    UI.Label { text = statNames[key] .. " +" .. stats[key], fontSize = 18, fontColor = statColors[key], fontWeight = "bold" },
                },
            }
        end
    end
    if #statChildren > 0 then
        children[#children + 1] = UI.Panel {
            width = "100%", flexDirection = "row", gap = 14, flexWrap = "wrap",
            children = statChildren,
        }
    end

    -- 装备描述
    if display.desc and display.desc ~= "" then
        children[#children + 1] = UI.Label {
            text = display.desc, fontSize = 15, fontColor = {140, 150, 170, 200},
            fontStyle = "italic",
        }
    end

    -- 套装信息（仅金色显示）
    local setDef = itemDef.setId and Equipment.GetSetDef(itemDef.setId) or nil
    if setDef and rarityId == "gold" then
        local setCounts = Equipment.GetActiveSetCount(equipment or {})
        local setCount = setCounts[setDef.id] or 0

        children[#children + 1] = UI.Panel {
            width = "100%", height = 1,
            backgroundGradient = { type = "linear", direction = "to-right",
                from = {setDef.color[1], setDef.color[2], setDef.color[3], 60},
                to = {setDef.color[1], setDef.color[2], setDef.color[3], 10},
            },
        }

        local sc = setDef.color
        local setChildren = {
            UI.Label {
                text = setDef.icon .. " " .. setDef.name .. " (" .. setCount .. "/6)",
                fontSize = 16, fontWeight = "bold",
                fontColor = setCount >= 4 and sc or {sc[1], sc[2], sc[3], 160},
            },
        }
        if setDef.desc4 then
            local active4 = setCount >= 4
            setChildren[#setChildren + 1] = UI.Panel {
                flexDirection = "row", gap = 5, alignItems = "center",
                children = {
                    UI.Label { text = active4 and "[+]" or "[ ]", fontSize = 14,
                        fontColor = active4 and {255, 220, 80, 255} or {80, 85, 100, 180} },
                    UI.Label {
                        text = "4件: " .. setDef.desc4,
                        fontSize = 15,
                        fontColor = active4 and {sc[1], sc[2], sc[3], 255} or {100, 110, 130, 150},
                    },
                },
            }
        end
        if setDef.desc6 then
            local active6 = setCount >= 6
            setChildren[#setChildren + 1] = UI.Panel {
                flexDirection = "row", gap = 5, alignItems = "center",
                children = {
                    UI.Label { text = active6 and "[+]" or "[ ]", fontSize = 14,
                        fontColor = active6 and {255, 230, 100, 255} or {80, 85, 100, 180} },
                    UI.Label {
                        text = "6件: " .. setDef.desc6,
                        fontSize = 15,
                        fontColor = active6 and {255, 230, 100, 255} or {100, 110, 130, 150},
                    },
                },
            }
        end
        children[#children + 1] = UI.Panel {
            width = "100%", gap = 3, children = setChildren,
        }
    end

    -- 弹窗面板
    local gFrom = RARITY_GRAD_FROM[rarityId] or RARITY_GRAD_FROM.common
    local gTo   = RARITY_GRAD_TO[rarityId] or RARITY_GRAD_TO.common
    return UI.Panel {
        width = 300, padding = 16, gap = 10,
        backgroundGradient = {
            type = "linear", direction = "to-bottom",
            from = {gFrom[1] + 8, gFrom[2] + 8, gFrom[3] + 12, 252},
            to = {gTo[1] + 5, gTo[2] + 5, gTo[3] + 8, 252},
        },
        borderRadius = 0,
        borderWidth = 2,
        borderColor = {borderCol[1], borderCol[2], borderCol[3], 180},
        boxShadow = {
            { x = 0, y = 4, blur = 16, spread = 2, color = {0, 0, 0, 120} },
            { x = 0, y = 0, blur = 12, spread = 2, color = {borderCol[1], borderCol[2], borderCol[3], 30} },
        },
        children = children,
    }
end

--- 创建仓库格子
---@param item table|nil 装备数据
---@param size number 格子尺寸
---@param onClick function|nil 点击回调
---@param selected boolean|nil 是否被选中（分解模式）
---@param dragCallbacks table|nil 拖拽回调 { onDragStart, onDragMove, onDragEnd }
local function BuildItemCell(item, size, onClick, selected, dragCallbacks)
    if not item then
        return UI.Panel {
            width = size, height = size,
            backgroundGradient = {
                type = "linear", direction = "to-bottom",
                from = {48, 52, 68, 255}, to = {35, 38, 52, 255},
            },
            borderRadius = 0,
            borderWidth = 1.5,
            borderColor = {60, 65, 82, 170},
            justifyContent = "center", alignItems = "center",
        }
    end

    local display = Equipment.GetItemDisplay(item)
    if not display then return nil end
    local rarity = item.rarity or "common"
    local borderCol = RARITY_BORDER[rarity] or RARITY_BORDER.common
    local bgCol = RARITY_BG[rarity] or RARITY_BG.common
    local setDef = display.setId and Equipment.GetSetDef(display.setId) or nil
    local setColor = setDef and setDef.color or nil

    local cellChildren = {}
    if setColor then
        cellChildren[#cellChildren + 1] = UI.Panel {
            width = "100%", height = 3,
            backgroundColor = setColor,
            borderRadius = 0,
            position = "absolute", top = 0, left = 0, right = 0,
        }
    end
    local iconSize = math.floor(size * 0.42)
    local iconPath = display.iconId and IconAtlas.GetPath(display.iconId) or nil
    if iconPath then
        cellChildren[#cellChildren + 1] = UI.Panel { backgroundImage = iconPath, width = iconSize, height = iconSize, backgroundFit = "contain" }
    else
        cellChildren[#cellChildren + 1] = UI.Label {
            text = display.icon, fontSize = math.floor(size * 0.38),
            textAlign = "center",
        }
    end
    cellChildren[#cellChildren + 1] = UI.Label {
        text = display.name,
        fontSize = 13, fontColor = borderCol,
        textAlign = "center", numberOfLines = 1,
        width = "100%",
    }

    -- 分解模式：选中覆盖层（勾选标记）
    if selected then
        cellChildren[#cellChildren + 1] = UI.Panel {
            position = "absolute", top = 0, left = 0, right = 0, bottom = 0,
            backgroundColor = {255, 80, 60, 50},
            borderRadius = 0,
            justifyContent = "center", alignItems = "center",
        }
        cellChildren[#cellChildren + 1] = UI.Panel {
            position = "absolute", top = 3, right = 3,
            width = 22, height = 22,
            backgroundColor = {255, 80, 60, 240},
            borderRadius = 0,
            justifyContent = "center", alignItems = "center",
            boxShadow = {
                { x = 0, y = 1, blur = 3, spread = 0, color = {0, 0, 0, 60} },
            },
            children = {
                UI.Label { text = "\xe2\x9c\x93", fontSize = 14, fontColor = {255, 255, 255, 255}, fontWeight = "bold" },
            },
        }
    end

    local gFrom = RARITY_GRAD_FROM[rarity] or RARITY_GRAD_FROM.common
    local gTo   = RARITY_GRAD_TO[rarity] or RARITY_GRAD_TO.common
    local actualBorderCol = selected and {255, 90, 70, 255} or borderCol

    -- 拖拽状态
    local dragState = { pressing = false, dragging = false, startX = 0, startY = 0 }
    local DRAG_THRESHOLD = 10  -- 像素

    -- 有拖拽回调时使用 Panel + onPointer* 事件（Button 子类覆盖了基类的 onPointer*，无法自定义）
    -- 无拖拽回调时使用 Button + onClick
    local btn
    if dragCallbacks then
        btn = UI.Panel {
            width = size, height = size,
            backgroundGradient = {
                type = "linear", direction = "to-bottom",
                from = gFrom, to = gTo,
            },
            borderRadius = 0,
            borderWidth = selected and 2.5 or 2,
            borderColor = actualBorderCol,
            boxShadow = selected
                and { { x = 0, y = 0, blur = 8, spread = 1, color = {255, 80, 60, 60} } }
                or RarityShadow(rarity),
            justifyContent = "center", alignItems = "center",
            flexDirection = "column", gap = 0,
            overflow = "hidden",
            onPointerDown = function(event, widget)
                -- 清理上次可能残留的拖拽状态（防止 ghost 卡住）
                if dragState.dragging and dragCallbacks.onDragEnd then
                    dragCallbacks.onDragEnd(event.x, event.y)
                end
                dragState.pressing = true
                dragState.dragging = false
                dragState.startX = event.x
                dragState.startY = event.y
            end,
            onPointerMove = function(event, widget)
                if not dragState.pressing then return end
                local dx = event.x - dragState.startX
                local dy = event.y - dragState.startY
                if not dragState.dragging then
                    if math.abs(dx) > DRAG_THRESHOLD or math.abs(dy) > DRAG_THRESHOLD then
                        dragState.dragging = true
                        if dragCallbacks.onDragStart then
                            dragCallbacks.onDragStart(event.x, event.y)
                        end
                    end
                else
                    if dragCallbacks.onDragMove then
                        dragCallbacks.onDragMove(event.x, event.y)
                    end
                end
            end,
            onPointerUp = function(event, widget)
                if not dragState.pressing then return end
                dragState.pressing = false
                if dragState.dragging then
                    dragState.dragging = false
                    if dragCallbacks.onDragEnd then
                        dragCallbacks.onDragEnd(event.x, event.y)
                    end
                else
                    -- 短按 = 点击
                    if onClick then onClick(widget) end
                end
            end,
            -- OS 中断（通知栏/来电）时强制结束拖拽
            onPointerCancel = function(event, widget)
                if dragState.pressing and dragState.dragging and dragCallbacks.onDragEnd then
                    dragCallbacks.onDragEnd(event.x, event.y)
                end
                dragState.pressing = false
                dragState.dragging = false
            end,
            children = cellChildren,
        }
    else
        btn = UI.Button {
            width = size, height = size,
            backgroundGradient = {
                type = "linear", direction = "to-bottom",
                from = gFrom, to = gTo,
            },
            borderRadius = 0,
            borderWidth = selected and 2.5 or 2,
            borderColor = actualBorderCol,
            boxShadow = selected
                and { { x = 0, y = 0, blur = 8, spread = 1, color = {255, 80, 60, 60} } }
                or RarityShadow(rarity),
            pressedBackgroundColor = {gTo[1] - 8, gTo[2] - 8, gTo[3] - 8, 255},
            justifyContent = "center", alignItems = "center",
            flexDirection = "column", gap = 0,
            overflow = "hidden",
            onClick = onClick,
            children = cellChildren,
        }
    end

    -- 防止 ScrollView 抢夺拖拽手势：当格子正在按压时，
    -- 由格子优先处理 Pan，阻止 ScrollView 的 CancelPointer
    if dragCallbacks then
        btn.OnPanStart = function(self, event)
            if dragState.pressing then
                self.state = self.state or {}
                self.state.isDragging = true
                return true  -- 拦截手势，不让 ScrollView 滚动
            end
            return false
        end
        btn.OnPanEnd = function(self, event)
            if self.state then
                self.state.isDragging = false
            end
        end
    end

    return btn
end

function MenuPages.BuildEquipPage(data, callbacks)
    local children = {}
    local slotSize = 88

    -- ======== 英雄区域：左3槽 + 英雄 + 右3槽 ========
    local leftSlots = { "weapon", "necklace", "shoes" }
    local rightSlots = { "helmet", "top_armor", "bottom_armor" }

    -- 存储槽位 widget 引用，用于拖拽高亮
    local slotWidgets = {}

    -- 为已装备槽位创建拖拽回调（拖出脱下装备）
    local function makeSlotDragCallbacks(slot)
        if not data.equipment[slot] then return nil end
        return {
            onDragStart = function(x, y)
                if callbacks and callbacks.onEquipDragStart then
                    callbacks.onEquipDragStart(slot, x, y)
                end
            end,
            onDragMove = function(x, y)
                if callbacks and callbacks.onDragMove then
                    callbacks.onDragMove(x, y)
                end
            end,
            onDragEnd = function(x, y)
                if callbacks and callbacks.onEquipDragEnd then
                    callbacks.onEquipDragEnd(slot, x, y)
                end
            end,
        }
    end

    -- 为槽位创建接收背包拖拽放置的回调
    -- 当用户从背包格子拖到此槽松手时触发（onPointerUp 在槽位上触发，而非背包格子上）
    local function makeReceiveDrop(slot)
        return function(x, y, widget)
            -- G.dragItemIdx / G.dragTargetSlot 由 StartDrag 设置，松手时读取
            local idx = G.dragItemIdx
            local targetSlot = G.dragTargetSlot
            if idx and callbacks and callbacks.onDragEnd then
                callbacks.onDragEnd(idx, targetSlot, x, y, widget)
            end
        end
    end

    local leftWidgets = {}
    for _, slot in ipairs(leftSlots) do
        local w = BuildEquipSlot(slot, data.equipment[slot], slotSize,
            callbacks and callbacks.onUnequip, makeSlotDragCallbacks(slot), makeReceiveDrop(slot))
        slotWidgets[slot] = w
        leftWidgets[#leftWidgets + 1] = w
    end

    local rightWidgets = {}
    for _, slot in ipairs(rightSlots) do
        local w = BuildEquipSlot(slot, data.equipment[slot], slotSize,
            callbacks and callbacks.onUnequip, makeSlotDragCallbacks(slot), makeReceiveDrop(slot))
        slotWidgets[slot] = w
        rightWidgets[#rightWidgets + 1] = w
    end

    -- ======== 属性 + 套装摘要 ========
    local totalBonus = PlayerData.GetTotalBonus(data)
    local critRate = PlayerData.GetCritRate(data)
    local setCounts = Equipment.GetActiveSetCount(data.equipment)

    -- 套装状态行 (v4.1: 显示效果描述)
    local setLabels = {}
    for _, setDef in ipairs(Equipment.SETS) do
        local count = setCounts[setDef.id] or 0
        if count > 0 then
            local is4 = count >= 4
            local is6 = count >= 6
            local labelColor = is4 and setDef.color or {120, 130, 150, 180}
            local sc = setDef.color

            local setChildren = {
                UI.Panel {
                    flexDirection = "row", alignItems = "center", gap = 4,
                    children = {
                        UI.Label {
                            text = setDef.icon .. " " .. setDef.name .. " " .. count .. "/6",
                            fontSize = 16, fontColor = labelColor, fontWeight = is4 and "bold" or nil,
                            textShadow = is4 and { offsetX = 0, offsetY = 1, blur = 2, color = {0, 0, 0, 60} } or nil,
                        },
                        is4 and UI.Label {
                            text = is6 and "++" or "+",
                            fontSize = 15, fontColor = {255, 220, 80, 255},
                            textShadow = { offsetX = 0, offsetY = 1, blur = 3, color = {255, 200, 40, 50} },
                        } or nil,
                    },
                },
            }
            -- 显示效果描述
            if is4 and setDef.desc4 then
                setChildren[#setChildren + 1] = UI.Label {
                    text = "4/6: " .. setDef.desc4,
                    fontSize = 13,
                    fontColor = is4 and {sc[1], sc[2], sc[3], 200} or {100, 110, 130, 150},
                }
            end
            if is6 and setDef.desc6 then
                setChildren[#setChildren + 1] = UI.Label {
                    text = "6/6: " .. setDef.desc6,
                    fontSize = 13, fontWeight = "bold",
                    fontColor = {255, 230, 100, 255},
                }
            end

            setLabels[#setLabels + 1] = UI.Panel {
                flexDirection = "column", gap = 2,
                backgroundGradient = is4 and {
                    type = "linear", direction = "to-right",
                    from = {sc[1], sc[2], sc[3], 45}, to = {sc[1], sc[2], sc[3], 15},
                } or nil,
                backgroundColor = (not is4) and {35, 38, 52, 200} or nil,
                borderRadius = 0,
                borderWidth = is4 and 1.5 or 1,
                borderColor = is4 and {sc[1], sc[2], sc[3], 120} or {60, 65, 82, 120},
                boxShadow = is4 and {
                    { x = 0, y = 1, blur = 6, spread = 0, color = {sc[1], sc[2], sc[3], 40} },
                } or nil,
                paddingLeft = 10, paddingRight = 10, paddingTop = 5, paddingBottom = 5,
                children = setChildren,
            }
        end
    end

    -- ======== 上半区：装备区（flexGrow=1 占50%）========
    local topChildren = {
        -- 英雄+槽位区
        UI.Panel {
            width = "100%",
            flexGrow = 1,
            flexDirection = "row",
            justifyContent = "center",
            alignItems = "center",
            gap = 14,
            children = {
                -- 左侧3槽
                UI.Panel {
                    flexDirection = "column", gap = 10,
                    alignItems = "center",
                    children = leftWidgets,
                },
                -- 英雄图标（小企鹅）
                UI.Panel {
                    width = 140, height = 190,
                    backgroundGradient = {
                        type = "linear", direction = "to-bottom",
                        from = {55, 65, 105, 255}, to = {35, 42, 72, 255},
                    },
                    borderRadius = 0,
                    borderWidth = 2.5,
                    borderColor = {95, 115, 185, 200},
                    boxShadow = {
                        { x = 0, y = 3, blur = 10, spread = 0, color = {0, 0, 0, 60} },
                        { x = 0, y = 1, blur = 4, spread = 0, color = {100, 120, 200, 25}, inset = true },
                    },
                    justifyContent = "center", alignItems = "center",
                    flexDirection = "column", gap = 4,
                    overflow = "hidden",
                    children = {
                        UI.Panel { backgroundImage = "image/hero_penguin_pixel_sword.png", width = 130, height = 130, backgroundFit = "contain" },
                        UI.Label {
                            text = "英雄",
                            fontSize = 19, fontColor = {160, 180, 230, 220},
                            textAlign = "center",
                            textShadow = { offsetX = 0, offsetY = 1, blur = 2, color = {0, 0, 0, 80} },
                        },
                    },
                },
                -- 右侧3槽
                UI.Panel {
                    flexDirection = "column", gap = 10,
                    alignItems = "center",
                    children = rightWidgets,
                },
            },
        },
        -- 总属性行
        UI.Panel {
            width = "100%", flexDirection = "row",
            justifyContent = "center", gap = 16,
            paddingTop = 6, paddingBottom = 4,
            children = {
                UI.Panel { flexDirection = "row", alignItems = "center", gap = 4, children = {
                    UI.Panel { backgroundImage = IconAtlas.GetPath("equip_weapon"), width = 18, height = 18, backgroundFit = "contain" },
                    UI.Label { text = tostring(math.floor(totalBonus.atk + 0.5)), fontSize = 21, fontColor = {255, 130, 100, 255},
                        textShadow = { offsetX = 0, offsetY = 1, blur = 3, color = {255, 80, 60, 40} } },
                }},
                UI.Panel { flexDirection = "row", alignItems = "center", gap = 4, children = {
                    UI.Panel { backgroundImage = IconAtlas.GetPath("hud_shield"), width = 18, height = 18, backgroundFit = "contain" },
                    UI.Label { text = tostring(math.floor(totalBonus.def + 0.5)), fontSize = 21, fontColor = {100, 180, 255, 255},
                        textShadow = { offsetX = 0, offsetY = 1, blur = 3, color = {60, 130, 255, 40} } },
                }},
                UI.Panel { flexDirection = "row", alignItems = "center", gap = 4, children = {
                    UI.Panel { backgroundImage = IconAtlas.GetPath("hud_hp"), width = 18, height = 18, backgroundFit = "contain" },
                    UI.Label { text = tostring(math.floor(totalBonus.hp + 0.5)), fontSize = 21, fontColor = {100, 255, 130, 255},
                        textShadow = { offsetX = 0, offsetY = 1, blur = 3, color = {60, 220, 100, 40} } },
                }},
                critRate > 0 and UI.Panel { flexDirection = "row", alignItems = "center", gap = 4, children = {
                    UI.Label { text = "💥", fontSize = 16 },
                    UI.Label { text = math.floor(critRate) .. "%", fontSize = 21, fontColor = {255, 200, 60, 255},
                        textShadow = { offsetX = 0, offsetY = 1, blur = 3, color = {255, 180, 0, 40} } },
                }} or nil,
            },
        },
    }
    -- 套装标签（如果有）
    if #setLabels > 0 then
        topChildren[#topChildren + 1] = UI.Panel {
            width = "100%", flexDirection = "row",
            justifyContent = "center", gap = 8,
            paddingBottom = 4,
            flexWrap = "wrap",
            children = setLabels,
        }
    end

    children[#children + 1] = UI.Panel {
        width = "100%",
        flexShrink = 0,
        flexDirection = "column",
        justifyContent = "center",
        alignItems = "center",
        paddingTop = 10, paddingBottom = 6,
        children = topChildren,
    }

    -- 分割线
    children[#children + 1] = UI.Panel {
        width = "92%", height = 1.5,
        flexShrink = 0,
        backgroundGradient = {
            type = "linear", direction = "to-right",
            from = {60, 55, 90, 0}, to = {80, 75, 130, 130},
        },
        alignSelf = "center",
    }

    -- ======== 下半区：仓库（flexGrow=1 填充剩余空间）========
    local isDecomposing = data._decomposing or false
    local selectedSet = data._selectedForDecompose or {}

    -- 计算选中项的预计金币收益
    local selectedCount = 0
    local selectedGold = 0
    if isDecomposing then
        for idx, _ in pairs(selectedSet) do
            local item = data.inventory[idx]
            if item then
                selectedCount = selectedCount + 1
                local rarity = Equipment.RARITY_MIGRATE[item.rarity] or item.rarity
                selectedGold = selectedGold + (Equipment.RARITY_DECOMPOSE[rarity] or 5)
            end
        end
    end

    -- 仓库标题栏（带左侧装饰条 + 分解按钮）
    local titleBarColor = isDecomposing
        and { from = {120, 50, 40, 255}, to = {80, 30, 25, 255} }
        or nil
    local decoBarColor = isDecomposing
        and { from = {255, 100, 70, 255}, to = {200, 60, 40, 255} }
        or { from = {100, 120, 240, 255}, to = {60, 80, 180, 255} }

    local titleRightChildren = {}
    if not isDecomposing then
        -- 普通模式：显示"X 件" + "分解"按钮
        titleRightChildren[#titleRightChildren + 1] = UI.Panel {
            backgroundGradient = {
                type = "linear", direction = "to-bottom",
                from = {48, 52, 72, 240}, to = {35, 38, 55, 240},
            },
            borderRadius = 0,
            borderWidth = 1,
            borderColor = {70, 75, 100, 150},
            paddingLeft = 10, paddingRight = 10,
            paddingTop = 3, paddingBottom = 3,
            children = {
                UI.Label {
                    text = #data.inventory .. " 件",
                    fontSize = 16, fontColor = {140, 150, 180, 220},
                },
            },
        }
        if #data.inventory > 0 then
            titleRightChildren[#titleRightChildren + 1] = UI.Button {
                backgroundGradient = {
                    type = "linear", direction = "to-bottom",
                    from = {180, 70, 50, 240}, to = {140, 45, 35, 240},
                },
                pressedBackgroundColor = {200, 90, 70, 255},
                borderRadius = 0,
                borderWidth = 1,
                borderColor = {220, 100, 70, 150},
                paddingLeft = 12, paddingRight = 12,
                paddingTop = 4, paddingBottom = 4,
                boxShadow = {
                    { x = 0, y = 1, blur = 4, spread = 0, color = {0, 0, 0, 40} },
                },
                onClick = function(self)
                    AM.PlaySFX("ui_click")
                    if callbacks and callbacks.onToggleDecompose then
                        callbacks.onToggleDecompose(true)
                    end
                end,
                children = {
                    UI.Label {
                        text = "分解",
                        fontSize = 15, fontColor = {255, 220, 200, 255},
                        fontWeight = "bold",
                    },
                },
            }
        end
    else
        -- 分解模式：一键全选蓝色按钮 + 提示文字
        -- 检查是否有蓝色装备
        local hasBlue = false
        for _, item in ipairs(data.inventory) do
            local r = Equipment.RARITY_MIGRATE[item.rarity] or item.rarity
            if r == "blue" then hasBlue = true; break end
        end
        if hasBlue then
            titleRightChildren[#titleRightChildren + 1] = UI.Button {
                backgroundGradient = {
                    type = "linear", direction = "to-bottom",
                    from = {60, 100, 180, 240}, to = {40, 70, 140, 240},
                },
                pressedBackgroundColor = {80, 120, 200, 255},
                borderRadius = 0,
                borderWidth = 1,
                borderColor = {90, 140, 220, 180},
                paddingLeft = 10, paddingRight = 10,
                paddingTop = 4, paddingBottom = 4,
                onClick = function(self)
                    AM.PlaySFX("ui_click")
                    if callbacks and callbacks.onSelectAllBlue then
                        callbacks.onSelectAllBlue()
                    end
                end,
                children = {
                    UI.Label {
                        text = "全选蓝色",
                        fontSize = 13, fontColor = {200, 220, 255, 255},
                        fontWeight = "bold",
                    },
                },
            }
        end
        -- 检查是否有紫色装备
        local hasPurple = false
        for _, item in ipairs(data.inventory) do
            local r = Equipment.RARITY_MIGRATE[item.rarity] or item.rarity
            if r == "purple" then hasPurple = true; break end
        end
        if hasPurple then
            titleRightChildren[#titleRightChildren + 1] = UI.Button {
                backgroundGradient = {
                    type = "linear", direction = "to-bottom",
                    from = {140, 60, 200, 240}, to = {100, 40, 160, 240},
                },
                pressedBackgroundColor = {160, 80, 220, 255},
                borderRadius = 0,
                borderWidth = 1,
                borderColor = {180, 100, 240, 180},
                paddingLeft = 10, paddingRight = 10,
                paddingTop = 4, paddingBottom = 4,
                onClick = function(self)
                    AM.PlaySFX("ui_click")
                    if callbacks and callbacks.onSelectAllPurple then
                        callbacks.onSelectAllPurple()
                    end
                end,
                children = {
                    UI.Label {
                        text = "全选紫色",
                        fontSize = 13, fontColor = {230, 200, 255, 255},
                        fontWeight = "bold",
                    },
                },
            }
        end
        titleRightChildren[#titleRightChildren + 1] = UI.Label {
            text = "点击选择装备",
            fontSize = 14, fontColor = {255, 180, 150, 200},
        }
    end

    local invTitle = UI.Panel {
        width = "100%", flexDirection = "row",
        alignItems = "center", justifyContent = "space-between",
        paddingTop = 10, paddingBottom = 8,
        children = {
            UI.Panel {
                flexDirection = "row", alignItems = "center", gap = 8,
                children = {
                    -- 左侧装饰条
                    UI.Panel {
                        width = 3, height = 20,
                        backgroundGradient = {
                            type = "linear", direction = "to-bottom",
                            from = decoBarColor.from, to = decoBarColor.to,
                        },
                        borderRadius = 0,
                    },
                    UI.Label {
                        text = isDecomposing and "分解模式" or "仓库",
                        fontSize = 23,
                        fontColor = isDecomposing and {255, 180, 150, 255} or {200, 210, 240, 255},
                        fontWeight = "bold",
                        textShadow = { offsetX = 0, offsetY = 1, blur = 2, color = {0, 0, 0, 60} },
                    },
                },
            },
            UI.Panel {
                flexDirection = "row", alignItems = "center", gap = 8,
                children = titleRightChildren,
            },
        },
    }

    -- 仓库网格 (4列)
    local cellSize = 88
    local invRows = {}
    if #data.inventory == 0 then
        -- 空仓库: 显示引导提示
        invRows[#invRows + 1] = UI.Panel {
            width = "100%",
            justifyContent = "center", alignItems = "center",
            paddingTop = 20, paddingBottom = 20, gap = 8,
            children = {
                UI.Label { text = "📦", fontSize = 42 },
                UI.Label {
                    text = "仓库空空如也",
                    fontSize = 19, fontColor = {130, 140, 170, 200},
                },
                UI.Label {
                    text = "去商店开宝箱获取装备吧",
                    fontSize = 16, fontColor = {100, 110, 140, 160},
                },
            },
        }
    else
        -- 按部位分组展示
        local SLOT_ICONS = {
            weapon = "⚔️", necklace = "📿", helmet = "🪖",
            top_armor = "🛡️", bottom_armor = "👖", shoes = "👟",
        }

        -- 按部位分组（保留原始索引用于回调）
        local slotGroups = {}
        for _, slot in ipairs(Equipment.SLOT_ORDER) do
            slotGroups[slot] = {}
        end
        for i, entry in ipairs(data.inventory) do
            local itemDef = Equipment.GetItemDef(entry.id)
            local slot = itemDef and itemDef.slot or "weapon"
            if not slotGroups[slot] then slotGroups[slot] = {} end
            slotGroups[slot][#slotGroups[slot] + 1] = i
        end

        -- 各部位内按稀有度排序（金→紫→蓝）
        for _, slot in ipairs(Equipment.SLOT_ORDER) do
            local group = slotGroups[slot]
            table.sort(group, function(a, b)
                local ra = data.inventory[a] and data.inventory[a].rarity or "blue"
                local rb = data.inventory[b] and data.inventory[b].rarity or "blue"
                local sa = Equipment.RARITY_SORT[ra] or 0
                local sb = Equipment.RARITY_SORT[rb] or 0
                if sa ~= sb then return sa > sb end
                return a < b
            end)
        end

        -- 渲染每个部位分区
        for _, slot in ipairs(Equipment.SLOT_ORDER) do
            local group = slotGroups[slot]
            local slotName = Equipment.SLOT_NAMES[slot] or slot
            local slotIcon = SLOT_ICONS[slot] or "📦"

            -- 部位分区标题
            invRows[#invRows + 1] = UI.Panel {
                width = "100%", flexDirection = "row",
                alignItems = "center", gap = 6,
                paddingTop = 10, paddingBottom = 4, paddingLeft = 2,
                children = {
                    UI.Label { text = slotIcon, fontSize = 15 },
                    UI.Label {
                        text = slotName,
                        fontSize = 15, fontColor = {170, 180, 210, 255},
                        fontWeight = "bold",
                    },
                    UI.Panel {
                        backgroundColor = {60, 65, 90, 180},
                        borderRadius = 0,
                        paddingLeft = 6, paddingRight = 6,
                        paddingTop = 1, paddingBottom = 1,
                        children = {
                            UI.Label {
                                text = tostring(#group),
                                fontSize = 12, fontColor = {140, 150, 180, 200},
                            },
                        },
                    },
                },
            }

            if #group == 0 then
                -- 空部位占位
                invRows[#invRows + 1] = UI.Panel {
                    width = "100%", justifyContent = "center", alignItems = "center",
                    paddingTop = 6, paddingBottom = 10,
                    children = {
                        UI.Label {
                            text = "暂无",
                            fontSize = 14, fontColor = {90, 95, 120, 150},
                        },
                    },
                }
            else
                -- 渲染该部位的装备格子（4列）
                local currentRow = {}
                for i, idx in ipairs(group) do
                    local entry = data.inventory[idx]
                    local isSelected = selectedSet[idx] == true
                    local cellOnClick
                    if isDecomposing then
                        cellOnClick = function(self)
                            AM.PlaySFX("ui_click")
                            if callbacks and callbacks.onSelectDecompose then
                                callbacks.onSelectDecompose(idx)
                            end
                        end
                    else
                        cellOnClick = function(self)
                            AM.PlaySFX("ui_click")
                            if callbacks and callbacks.onShowDetail then
                                callbacks.onShowDetail(idx, self)
                            end
                        end
                    end

                    -- 非分解模式下支持拖拽穿戴
                    local cellDragCb = nil
                    if not isDecomposing and entry then
                        local itemDef = Equipment.GetItemDef(entry.id)
                        local targetSlot = itemDef and itemDef.slot or nil
                        if targetSlot then
                            cellDragCb = {
                                onDragStart = function(x, y)
                                    if callbacks and callbacks.onDragStart then
                                        callbacks.onDragStart(idx, targetSlot, x, y)
                                    end
                                    local sw = slotWidgets[targetSlot]
                                    if sw then
                                        sw:SetStyle({
                                            borderColor = {255, 255, 100, 255},
                                            borderWidth = 3,
                                            boxShadow = {
                                                { x = 0, y = 0, blur = 14, spread = 3, color = {255, 230, 80, 120} },
                                                { x = 0, y = 0, blur = 6, spread = 1, color = {255, 255, 150, 80} },
                                            },
                                        })
                                    end
                                end,
                                onDragMove = function(x, y)
                                    if callbacks and callbacks.onDragMove then
                                        callbacks.onDragMove(x, y)
                                    end
                                end,
                                onDragEnd = function(x, y)
                                    local sw = slotWidgets[targetSlot]
                                    if sw then
                                        local equipped = data.equipment[targetSlot]
                                        if equipped then
                                            local r = equipped.rarity or "common"
                                            local bc = RARITY_BORDER[r] or RARITY_BORDER.common
                                            sw:SetStyle({
                                                borderColor = bc,
                                                borderWidth = 2,
                                                boxShadow = RarityShadow(r),
                                            })
                                        else
                                            sw:SetStyle({
                                                borderColor = {70, 75, 95, 180},
                                                borderWidth = 2,
                                                borderStyle = "dashed",
                                                boxShadow = {
                                                    { x = 0, y = 1, blur = 4, spread = 0, color = {0, 0, 0, 40} },
                                                },
                                            })
                                        end
                                    end
                                    if callbacks and callbacks.onDragEnd then
                                        callbacks.onDragEnd(idx, targetSlot, x, y, sw)
                                    end
                                end,
                            }
                        end
                    end

                    local cell = BuildItemCell(entry, cellSize, cellOnClick, isDecomposing and isSelected, cellDragCb)
                    if cell then
                        currentRow[#currentRow + 1] = cell
                    end
                    if #currentRow >= 4 or i == #group then
                        while #currentRow < 4 do
                            currentRow[#currentRow + 1] = BuildItemCell(nil, cellSize, nil)
                        end
                        invRows[#invRows + 1] = UI.Panel {
                            width = "100%", flexDirection = "row",
                            justifyContent = "center", gap = 8,
                            paddingBottom = 6,
                            children = currentRow,
                        }
                        currentRow = {}
                    end
                end
            end
        end
    end

    -- 分解模式：底部操作栏
    local decomposeBar = nil
    if isDecomposing then
        decomposeBar = UI.Panel {
            width = "100%", flexDirection = "row",
            flexShrink = 0,
            alignItems = "center", justifyContent = "center",
            gap = 10,
            paddingTop = 10, paddingBottom = 14,
            paddingLeft = 14, paddingRight = 14,
            marginBottom = 18,
            backgroundGradient = {
                type = "linear", direction = "to-bottom",
                from = {45, 28, 25, 245}, to = {30, 18, 16, 255},
            },
            boxShadow = {
                { x = 0, y = -3, blur = 8, spread = 0, color = {0, 0, 0, 60} },
            },
            children = {
                -- 取消按钮
                UI.Button {
                    backgroundGradient = {
                        type = "linear", direction = "to-bottom",
                        from = {60, 65, 85, 240}, to = {42, 46, 62, 240},
                    },
                    pressedBackgroundColor = {75, 80, 100, 255},
                    borderRadius = 0,
                    borderWidth = 1,
                    borderColor = {90, 95, 120, 150},
                    paddingLeft = 18, paddingRight = 18,
                    paddingTop = 8, paddingBottom = 8,
                    onClick = function(self)
                        AM.PlaySFX("ui_click")
                        if callbacks and callbacks.onToggleDecompose then
                            callbacks.onToggleDecompose(false)
                        end
                    end,
                    children = {
                        UI.Label {
                            text = "取消",
                            fontSize = 16, fontColor = {180, 190, 210, 255},
                        },
                    },
                },
                -- 确认分解按钮（显示金币预览）
                UI.Button {
                    flexGrow = 1,
                    backgroundGradient = selectedCount > 0
                        and { type = "linear", direction = "to-bottom",
                              from = {200, 75, 50, 255}, to = {160, 50, 35, 255} }
                        or  { type = "linear", direction = "to-bottom",
                              from = {80, 60, 55, 200}, to = {60, 45, 40, 200} },
                    pressedBackgroundColor = selectedCount > 0 and {220, 95, 70, 255} or nil,
                    borderRadius = 0,
                    borderWidth = 1.5,
                    borderColor = selectedCount > 0 and {255, 130, 90, 180} or {100, 80, 70, 120},
                    paddingTop = 8, paddingBottom = 8,
                    boxShadow = selectedCount > 0 and {
                        { x = 0, y = 2, blur = 8, spread = 0, color = {200, 60, 30, 60} },
                    } or nil,
                    justifyContent = "center", alignItems = "center",
                    onClick = selectedCount > 0 and function(self)
                        AM.PlaySFX("ui_click")
                        if callbacks and callbacks.onConfirmDecompose then
                            callbacks.onConfirmDecompose()
                        end
                    end or nil,
                    children = {
                        UI.Label {
                            text = selectedCount > 0
                                and string.format("确认分解 %d 件 -> %d 金币", selectedCount, selectedGold)
                                or "请选择要分解的装备",
                            fontSize = 16,
                            fontColor = selectedCount > 0 and {255, 240, 220, 255} or {140, 120, 110, 180},
                            fontWeight = selectedCount > 0 and "bold" or nil,
                        },
                    },
                },
            },
        }
    end

    local invContentChildren = { invTitle, table.unpack(invRows) }

    -- 仓库滚动区域（不含 decomposeBar）
    children[#children + 1] = UI.Panel {
        id = "equipInvScroll",
        width = "100%", flexGrow = 1, flexShrink = 1,
        minHeight = 180,
        flexDirection = "column",
        paddingTop = 4, paddingLeft = 14, paddingRight = 14,
        paddingBottom = 10,
        backgroundGradient = {
            type = "linear", direction = "to-bottom",
            from = isDecomposing and {50, 32, 30, 220} or {32, 36, 55, 220},
            to = isDecomposing and {35, 22, 20, 240} or {22, 25, 40, 240},
        },
        borderTopLeftRadius = 18, borderTopRightRadius = 18,
        boxShadow = {
            { x = 0, y = -2, blur = 8, spread = 0, color = {0, 0, 0, 40} },
            { x = 0, y = 1, blur = 3, spread = 0, color = {60, 65, 100, 15}, inset = true },
        },
        overflow = "scroll",
        children = invContentChildren,
    }

    -- 分解操作栏固定在底部（不随滚动）
    if decomposeBar then
        children[#children + 1] = decomposeBar
    end

    -- 用一个 minHeight=100% 的容器包裹，让 flexGrow 在 ScrollView 内正确分配空间
    return { UI.Panel {
        width = "100%", minHeight = "100%",
        flexDirection = "column",
        children = children,
    } }
end

-- ============================================================================
-- 天赋页面
-- ============================================================================

local function BuildTalentNode(talent, data, isLast, callbacks)
    local level = data.talents[talent.id] or 0
    local maxLv = talent.maxLevel
    local cost = PlayerData.GetUpgradeCost(data, talent.id)
    local bonusRaw = level * talent.bonusPerLevel
    -- 格式化显示：整数不带小数，浮点保留1位；百分比类加%后缀
    local bonusStr
    if bonusRaw == math.floor(bonusRaw) then
        bonusStr = tostring(math.floor(bonusRaw))
    else
        bonusStr = string.format("%.1f", bonusRaw)
    end
    if talent.stat == "crit" or talent.stat == "gold" then
        bonusStr = bonusStr .. "%"
    end
    local isMax = (level >= maxLv)
    local canAfford = cost and data.gold >= cost

    local nodeGradFrom, nodeGradTo, nodeBorder
    if isMax then
        nodeGradFrom = {38, 78, 42, 255}
        nodeGradTo   = {25, 55, 28, 255}
        nodeBorder   = {55, 145, 55, 255}
    elseif level > 0 then
        nodeGradFrom = {35, 48, 78, 255}
        nodeGradTo   = {22, 32, 55, 255}
        nodeBorder   = {48, 68, 125, 255}
    else
        nodeGradFrom = {55, 58, 78, 255}
        nodeGradTo   = {40, 42, 58, 255}
        nodeBorder   = {80, 85, 110, 220}
    end

    local btnText = isMax and "MAX" or (cost .. "G")
    local btnGradFrom, btnGradTo, btnPressed
    if isMax then
        btnGradFrom = {35, 75, 40, 255}
        btnGradTo   = {25, 55, 28, 255}
        btnPressed  = {20, 45, 22, 255}
    elseif canAfford then
        btnGradFrom = {255, 215, 60, 255}
        btnGradTo   = {235, 185, 30, 255}
        btnPressed  = {210, 165, 20, 255}
    else
        btnGradFrom = {65, 68, 82, 255}
        btnGradTo   = {50, 52, 65, 255}
        btnPressed  = {42, 44, 55, 255}
    end
    local btnFontColor = isMax and {55, 200, 70, 255}
        or (canAfford and {80, 50, 0, 255} or {100, 105, 125, 220})

    local talentId = talent.id

    local dots = {}
    for i = 1, maxLv do
        dots[#dots + 1] = UI.Panel {
            width = 10, height = 10,
            borderRadius = 0,
            backgroundColor = i <= level
                and {255, 200, 60, 255}
                or {55, 58, 72, 255},
            borderWidth = 1,
            borderColor = i <= level
                and {240, 200, 80, 220}
                or {75, 78, 95, 180},
        }
    end

    return UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "flex-start",
        gap = 0,
        children = {
            UI.Panel {
                width = 56, alignItems = "center",
                children = {
                    UI.Panel {
                        width = 50, height = 50,
                        borderRadius = 0,
                        backgroundGradient = {
                            type = "linear", direction = "to-bottom",
                            from = nodeGradFrom, to = nodeGradTo,
                        },
                        borderWidth = 2,
                        borderColor = nodeBorder,
                        boxShadow = {
                            { x = 0, y = 2, blur = 5, spread = 0, color = {0, 0, 0, 50} },
                            { x = 0, y = 1, blur = 2, spread = 0, color = {nodeBorder[1], nodeBorder[2], nodeBorder[3], 20}, inset = true },
                        },
                        justifyContent = "center", alignItems = "center",
                        children = {
                            UI.Label { text = talent.icon, fontSize = 30, textAlign = "center" },
                        },
                    },
                    not isLast and UI.Panel {
                        width = 3, height = 20,
                        backgroundColor = level > 0
                            and {80, 160, 255, 150}
                            or {55, 58, 72, 150},
                    } or nil,
                },
            },
            UI.Panel {
                flexGrow = 1, flexShrink = 1,
                paddingLeft = 10, paddingTop = 2, gap = 4,
                children = {
                    UI.Panel {
                        flexDirection = "row", alignItems = "center", gap = 6,
                        children = {
                            UI.Label {
                                text = talent.name,
                                fontSize = 21,
                                fontColor = level > 0
                                    and {210, 220, 245, 255}
                                    or {110, 115, 140, 210},
                                textShadow = level > 0 and { offsetX = 0, offsetY = 1, blur = 2, color = {0, 0, 0, 60} } or nil,
                            },
                            UI.Panel {
                                backgroundGradient = level > 0 and {
                                    type = "linear", direction = "to-bottom",
                                    from = {38, 58, 92, 255}, to = {25, 42, 70, 255},
                                } or nil,
                                backgroundColor = level <= 0 and {50, 52, 65, 255} or nil,
                                borderRadius = 0,
                                paddingLeft = 6, paddingRight = 6,
                                paddingTop = 1, paddingBottom = 1,
                                children = {
                                    UI.Label {
                                        text = "Lv." .. level .. "/" .. maxLv,
                                        fontSize = 16,
                                        fontColor = level > 0
                                            and {100, 180, 255, 255}
                                            or {90, 95, 115, 210},
                                    },
                                },
                            },
                        },
                    },
                    UI.Label {
                        text = talent.desc .. " +" .. bonusStr,
                        fontSize = 19, fontColor = {140, 150, 180, 220},
                    },
                    UI.Panel {
                        width = "100%", flexDirection = "row",
                        justifyContent = "space-between", alignItems = "center",
                        children = {
                            UI.Panel {
                                flexDirection = "row", gap = 4,
                                children = dots,
                            },
                            UI.Button {
                                text = btnText,
                                height = 30, paddingLeft = 14, paddingRight = 14,
                                fontSize = 16, fontWeight = "bold",
                                backgroundGradient = {
                                    type = "linear", direction = "to-bottom",
                                    from = btnGradFrom, to = btnGradTo,
                                },
                                pressedBackgroundColor = btnPressed,
                                textColor = btnFontColor,
                                borderRadius = 0,
                                boxShadow = canAfford and (not isMax) and {
                                    { x = 0, y = 2, blur = 5, spread = 0, color = {0, 0, 0, 40} },
                                    { x = 0, y = 1, blur = 2, spread = 0, color = {255, 255, 255, 20}, inset = true },
                                } or nil,
                                textShadow = isMax and { offsetX = 0, offsetY = 1, blur = 2, color = {0, 80, 0, 40} }
                                    or (canAfford and { offsetX = 0, offsetY = 1, blur = 1, color = {255, 255, 200, 60} } or nil),
                                onClick = (not isMax and canAfford) and function(self)
                                    AM.PlaySFX("ui_click")
                                    if callbacks and callbacks.onUpgrade then
                                        callbacks.onUpgrade(talentId)
                                    end
                                end or nil,
                            },
                        },
                    },
                },
            },
        },
    }
end

function MenuPages.BuildTalentPage(data, callbacks)
    local children = {}

    children[#children + 1] = UI.Panel {
        width = "100%", alignItems = "center", paddingBottom = 8,
        children = {
            UI.Label {
                text = "天赋强化",
                fontSize = 23, fontColor = {255, 220, 60, 255},
                fontWeight = "bold",
                textShadow = { offsetX = 0, offsetY = 1, blur = 4, color = {255, 200, 40, 40} },
            },
            UI.Label {
                text = "提升角色基础属性",
                fontSize = 19, fontColor = {140, 150, 180, 200},
            },
        },
    }

    for i, talent in ipairs(PlayerData.TALENTS) do
        local isLast = (i == #PlayerData.TALENTS)
        children[#children + 1] = BuildTalentNode(talent, data, isLast, callbacks)
    end

    local bonus = PlayerData.GetTalentBonus(data)
    -- 格式化数值：整数不带小数，浮点保留1位
    local function fmtBonus(v)
        if v == math.floor(v) then return tostring(math.floor(v)) end
        return string.format("%.1f", v)
    end
    if bonus.atk > 0 or bonus.def > 0 or bonus.hp > 0 or bonus.crit > 0 then
        local statItems = {
            bonus.atk > 0 and UI.Panel { flexDirection = "row", alignItems = "center", gap = 3, children = {
                UI.Panel { backgroundImage = IconAtlas.GetPath("equip_weapon"), width = 15, height = 15, backgroundFit = "contain" },
                UI.Label { text = "+" .. fmtBonus(bonus.atk), fontSize = 16, fontColor = {255, 130, 100, 220},
                    textShadow = { offsetX = 0, offsetY = 1, blur = 2, color = {255, 80, 60, 35} } },
            }} or nil,
            bonus.def > 0 and UI.Panel { flexDirection = "row", alignItems = "center", gap = 3, children = {
                UI.Panel { backgroundImage = IconAtlas.GetPath("hud_shield"), width = 15, height = 15, backgroundFit = "contain" },
                UI.Label { text = "+" .. fmtBonus(bonus.def), fontSize = 16, fontColor = {100, 180, 255, 220},
                    textShadow = { offsetX = 0, offsetY = 1, blur = 2, color = {60, 130, 255, 35} } },
            }} or nil,
            bonus.hp > 0 and UI.Panel { flexDirection = "row", alignItems = "center", gap = 3, children = {
                UI.Panel { backgroundImage = IconAtlas.GetPath("hud_hp"), width = 15, height = 15, backgroundFit = "contain" },
                UI.Label { text = "+" .. fmtBonus(bonus.hp), fontSize = 16, fontColor = {100, 255, 130, 220},
                    textShadow = { offsetX = 0, offsetY = 1, blur = 2, color = {60, 220, 100, 35} } },
            }} or nil,
            bonus.crit > 0 and UI.Panel { flexDirection = "row", alignItems = "center", gap = 3, children = {
                UI.Label { text = "💥", fontSize = 13 },
                UI.Label { text = "+" .. fmtBonus(bonus.crit) .. "%", fontSize = 16, fontColor = {255, 200, 60, 220},
                    textShadow = { offsetX = 0, offsetY = 1, blur = 2, color = {255, 180, 0, 35} } },
            }} or nil,
        }
        -- 过滤 nil
        local filtered = {}
        for _, v in ipairs(statItems) do if v then filtered[#filtered + 1] = v end end
        children[#children + 1] = UI.Panel {
            width = "100%", paddingTop = 10,
            flexDirection = "row", justifyContent = "center", gap = 14,
            children = filtered,
        }
    end

    return children
end

-- ============================================================================
-- 商店页面 (v4.1: 上部套装海报轮播 + 下部开宝箱)
-- ============================================================================

--- 套装海报轮播状态 (模块级)
MenuPages._shopCarousel = {
    index = 1,        -- 当前展示的套装索引
    timer = 0,        -- 轮播计时器
    interval = 4.0,   -- 每个套装展示时长(秒)
    sparkles = {},    -- 粒子数据
    fadeAlpha = 1.0,  -- 淡入淡出
    fadeDir = 0,      -- 0=稳定, 1=淡出, 2=淡入
    fadeTimer = 0,
    sparkleTime = 0,  -- 粒子动画累计时间
}

--- 初始化闪光粒子
local function InitSparkles(count)
    local sparkles = {}
    for i = 1, count do
        sparkles[i] = {
            x = math.random(5, 95) / 100,   -- 相对x (0~1)
            y = math.random(5, 95) / 100,   -- 相对y (0~1)
            size = math.random(3, 8),
            speed = 0.3 + math.random() * 0.7,
            phase = math.random() * math.pi * 2,
            alpha = 0,
            driftX = (math.random() - 0.5) * 6,   -- 水平漂移幅度
            driftY = (math.random() - 0.5) * 4,   -- 垂直漂移幅度
            warmth = math.random() * 100 / 100,    -- 色温随机值 0~1
        }
    end
    return sparkles
end

-- ============================================================================
-- ShopSparkleWidget - 海报十字发光粒子覆盖层 (NanoVG 自定义渲染)
-- ============================================================================
local ShopSparkleWidget = UI.Widget:Extend("ShopSparkleWidget")

function ShopSparkleWidget:Init(props)
    UI.Widget.Init(self, props)
end

function ShopSparkleWidget:Render(nvg)
    local l = self:GetAbsoluteLayout()
    if l.w <= 0 or l.h <= 0 then return end

    local c = MenuPages._shopCarousel
    local time = c.sparkleTime or 0

    nvgSave(nvg)
    nvgIntersectScissor(nvg, l.x, l.y, l.w, l.h)

    for i, sp in ipairs(c.sparkles) do
        -- 基于时间的闪烁值（二次方，更柔和持久的闪耀）
        local blinkPhase = time * sp.speed * 1.8 + sp.phase
        local blinkVal = math.sin(blinkPhase) * 0.5 + 0.5
        blinkVal = blinkVal * blinkVal

        local intensity = sp.alpha * (0.3 + blinkVal * 0.7)
        if intensity < 0.03 then goto continue end

        -- 位置 + 轻微正弦漂移
        local sx = l.x + sp.x * l.w + math.sin(time * 0.3 + sp.phase) * sp.driftX
        local sy = l.y + sp.y * l.h + math.cos(time * 0.25 + sp.phase * 1.3) * sp.driftY

        -- 金白色调
        local sr = 255
        local sg = math.floor(230 + sp.warmth * 25)
        local sb = math.floor(180 + sp.warmth * 60)
        local alpha = math.floor(intensity * 255)

        local starR = (sp.size + 2) * (0.6 + blinkVal * 0.7)

        -- 1. 柔和光晕（大半径径向渐变，更明显）
        nvgBeginPath(nvg)
        nvgCircle(nvg, sx, sy, starR * 6)
        local glow = nvgRadialGradient(nvg, sx, sy, starR * 0.3, starR * 6,
            nvgRGBA(sr, sg, sb, math.floor(alpha * 0.3)),
            nvgRGBA(sr, sg, sb, 0))
        nvgFillPaint(nvg, glow)
        nvgFill(nvg)

        -- 2. 主十字星芒（水平+垂直，更粗更长）
        local crossLen = starR * 4.0 * (0.4 + blinkVal * 0.6)
        local crossA = math.floor(alpha * 0.85)
        nvgStrokeWidth(nvg, 2.0 + blinkVal * 1.0)
        nvgStrokeColor(nvg, nvgRGBA(sr, sg, sb, crossA))
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, sx - crossLen, sy)
        nvgLineTo(nvg, sx + crossLen, sy)
        nvgStroke(nvg)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, sx, sy - crossLen)
        nvgLineTo(nvg, sx, sy + crossLen)
        nvgStroke(nvg)

        -- 3. 45°对角星芒（较短较淡）
        local diagLen = crossLen * 0.5
        nvgStrokeWidth(nvg, 1.2 + blinkVal * 0.5)
        nvgStrokeColor(nvg, nvgRGBA(sr, sg, sb, math.floor(crossA * 0.5)))
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, sx - diagLen, sy - diagLen)
        nvgLineTo(nvg, sx + diagLen, sy + diagLen)
        nvgStroke(nvg)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, sx + diagLen, sy - diagLen)
        nvgLineTo(nvg, sx - diagLen, sy + diagLen)
        nvgStroke(nvg)

        -- 4. 核心亮点（更大更亮）
        nvgBeginPath(nvg)
        nvgCircle(nvg, sx, sy, starR * 0.8)
        nvgFillColor(nvg, nvgRGBA(255, 255, 250, alpha))
        nvgFill(nvg)

        ::continue::
    end

    nvgRestore(nvg)
end

--- 更新商店轮播动画 (由 MenuSystem 的 Update 每帧调用)
function MenuPages.UpdateShopCarousel(dt)
    local c = MenuPages._shopCarousel
    local numSets = #Equipment.SETS
    if numSets == 0 then return end

    -- 更新闪光粒子（慢速闪烁）
    c.sparkleTime = (c.sparkleTime or 0) + dt
    for _, sp in ipairs(c.sparkles) do
        sp.phase = sp.phase + dt * sp.speed * 1.2
        sp.alpha = math.abs(math.sin(sp.phase)) * 0.95
    end

    -- 淡入淡出状态机
    if c.fadeDir == 0 then
        -- 稳定展示
        c.timer = c.timer + dt
        if c.timer >= c.interval and numSets > 1 then
            c.fadeDir = 1  -- 开始淡出
            c.fadeTimer = 0
        end
    elseif c.fadeDir == 1 then
        -- 淡出
        c.fadeTimer = c.fadeTimer + dt
        local fadeDur = 0.35
        c.fadeAlpha = math.max(0, 1.0 - c.fadeTimer / fadeDur)
        if c.fadeTimer >= fadeDur then
            -- 切换索引（支持手动方向）
            local dir = c._switchDir or 1
            c._switchDir = nil
            c.index = ((c.index - 1 + dir) % numSets) + 1
            c.fadeDir = 2  -- 开始淡入
            c.fadeTimer = 0
            -- 刷新UI
            if c.onSwitch then c.onSwitch(c.index) end
        end
    elseif c.fadeDir == 2 then
        -- 淡入
        c.fadeTimer = c.fadeTimer + dt
        local fadeDur = 0.35
        c.fadeAlpha = math.min(1.0, c.fadeTimer / fadeDur)
        if c.fadeTimer >= fadeDur then
            c.fadeDir = 0
            c.fadeAlpha = 1.0
            c.timer = 0
        end
    end
end

--- 手动切换轮播到指定方向 (dir: 1=下一个, -1=上一个)
function MenuPages.SwitchCarousel(dir)
    local c = MenuPages._shopCarousel
    local numSets = #Equipment.SETS
    if numSets <= 1 or c.fadeDir ~= 0 then return end -- 正在切换中不响应

    -- 计算目标索引
    c._switchDir = dir
    c.fadeDir = 1  -- 开始淡出
    c.fadeTimer = 0
    c.timer = 0
end

--- 构建套装海报卡片 (v4.2: 竖版全幅海报)
-- 套装海报背景图映射
local SET_POSTER_IMAGES = {
    leap_pioneer  = "image/edited_poster_leap_pioneer_gold_20260521091656.png",
    combo_mastery = "image/edited_poster_combo_mastery_gold_20260521092040.png",
    soul_hunter   = "image/poster_soul_hunter_v5_20260523114549.png",
}

local function BuildSetPoster(setDef)
    local posterImg = SET_POSTER_IMAGES[setDef.id]

    -- 套装效果描述
    local descText = ""
    if setDef.desc4 and setDef.desc6 then
        descText = "4件: " .. setDef.desc4 .. " / 6件: " .. setDef.desc6
    elseif setDef.desc4 then
        descText = setDef.desc4
    end

    return UI.Panel {
        width = "100%",
        borderRadius = 0,
        borderWidth = 2,
        borderColor = {255, 225, 100, 120},
        overflow = "hidden",
        -- 纯金黄色底色
        backgroundGradient = {
            type = "linear", direction = "to-bottom",
            from = {255, 210, 60, 255}, to = {235, 180, 30, 255},
        },
        boxShadow = {
            { x = 0, y = 4, blur = 16, spread = 0, color = {0, 0, 0, 80} },
            { x = 0, y = 0, blur = 20, spread = 4, color = {255, 215, 0, 35} },
        },
        children = {
            -- 海报图片（contain 完整显示，16:9 更扁节省空间）
            posterImg and UI.Panel {
                width = "100%",
                aspectRatio = 16 / 9,
                backgroundImage = posterImg,
                backgroundFit = "contain",
            } or UI.Panel {
                width = "100%", aspectRatio = 16 / 9,
            },
            -- 底部套装信息（金色背景上直接显示，无黑色遮罩）
            UI.Panel {
                width = "100%",
                paddingTop = 4, paddingBottom = 6,
                paddingLeft = 16, paddingRight = 16,
                alignItems = "center", gap = 1,
                children = {
                    -- 套装名称（深色文字在金底上）
                    UI.Label {
                        text = setDef.icon .. "  " .. setDef.name,
                        fontSize = 19, fontWeight = "bold",
                        fontColor = {80, 40, 0, 255},
                        textShadow = {
                            offsetX = 0, offsetY = 1, blur = 3, color = {255, 255, 200, 120},
                        },
                    },
                    -- 套装效果
                    descText ~= "" and UI.Label {
                        text = descText,
                        fontSize = 12, fontColor = {100, 60, 10, 200},
                        textAlign = "center",
                    } or nil,
                },
            },
            -- ✨ 十字发光粒子覆盖层
            ShopSparkleWidget {
                position = "absolute",
                top = 0, left = 0, right = 0, bottom = 0,
            },
            -- "当期UP!" 标签 — 右上角，醒目旗帜
            UI.Panel {
                position = "absolute", top = 8, right = -8,
                width = 110,
                paddingTop = 6, paddingBottom = 6,
                backgroundGradient = {
                    type = "linear", direction = "to-right",
                    from = {255, 70, 70, 255}, to = {255, 120, 40, 255},
                },
                borderRadius = 0,
                justifyContent = "center", alignItems = "center",
                transform = { rotate = 28 },
                boxShadow = {
                    { x = 0, y = 3, blur = 12, spread = 2, color = {0, 0, 0, 100} },
                    { x = 0, y = 0, blur = 16, spread = 4, color = {255, 80, 40, 80} },
                },
                children = {
                    UI.Label {
                        text = "当期UP!",
                        fontSize = 15, fontWeight = "bold",
                        fontColor = {255, 255, 255, 255},
                        textShadow = { offsetX = 0, offsetY = 1, blur = 4, color = {0, 0, 0, 120} },
                    },
                },
            },
        },
    }
end

function MenuPages.BuildShopPage(data, callbacks)
    local children = {}
    local c = MenuPages._shopCarousel
    -- 初始化粒子（14颗十字发光粒子）
    if #c.sparkles < 14 then
        c.sparkles = InitSparkles(14)
    end

    local numSets = #Equipment.SETS
    local currentSet = Equipment.SETS[c.index] or Equipment.SETS[1]

    -- 海报使用 aspectRatio 自适应，无需计算固定高度

    -- ======== 0. 页面标题 ========
    children[#children + 1] = UI.Panel {
        width = "100%", alignItems = "center",
        paddingTop = 4, paddingBottom = 2,
        children = {
            UI.Label {
                text = "装备抽奖",
                fontSize = 24, fontWeight = "bold",
                fontColor = {255, 240, 180, 255},
                textShadow = { offsetX = 0, offsetY = 1, blur = 6, color = {255, 200, 40, 60} },
            },
        },
    }

    -- ======== 1. 全幅套装海报 + 翻页箭头 ========
    local arrowBtn = function(label, dir)
        return UI.Button {
            text = label,
            width = 36, height = 36,
            fontSize = 18, fontWeight = "bold",
            borderRadius = 18,
            backgroundColor = {30, 25, 50, 180},
            pressedBackgroundColor = {255, 215, 0, 220},
            fontColor = {255, 230, 120, 255},
            borderWidth = 1.5, borderColor = {255, 215, 0, 100},
            onClick = function(self)
                AM.PlaySFX("ui_click", 0.7)
                MenuPages.SwitchCarousel(dir)
            end,
        }
    end

    children[#children + 1] = UI.Panel {
        width = "100%", flexDirection = "row",
        alignItems = "center",
        paddingLeft = 4, paddingRight = 4,
        paddingTop = 4, paddingBottom = 0,
        children = {
            -- 左箭头
            numSets > 1 and arrowBtn("<", -1) or nil,
            -- 海报
            UI.Panel {
                flexGrow = 1, flexShrink = 1,
                paddingLeft = 4, paddingRight = 4,
                children = {
                    BuildSetPoster(currentSet),
                },
            },
            -- 右箭头
            numSets > 1 and arrowBtn(">", 1) or nil,
        },
    }

    -- 轮播指示器 (小圆点) — 多套装时显示
    if numSets > 1 then
        local dots = {}
        for i = 1, numSets do
            dots[#dots + 1] = UI.Panel {
                width = i == c.index and 18 or 8,
                height = 8,
                borderRadius = 0,
                backgroundColor = i == c.index and {255, 215, 0, 255} or {255, 255, 255, 80},
                transition = "all 0.3s easeOut",
            }
        end
        children[#children + 1] = UI.Panel {
            width = "100%", flexDirection = "row",
            justifyContent = "center", gap = 6,
            paddingTop = 2, paddingBottom = 6,
            children = dots,
        }
    end

    -- ======== 4. 装备宝箱图标 ========
    children[#children + 1] = UI.Panel {
        width = "100%", alignItems = "center",
        paddingTop = 2, paddingBottom = 0,
        children = {
            UI.Panel {
                width = 130, height = 130,
                justifyContent = "center", alignItems = "center",
                children = {
                    UI.Panel {
                        backgroundImage = "image/chest_flat_icon.png",
                        width = 130, height = 130,
                        backgroundFit = "contain",
                    },
                },
            },
        },
    }

    -- ======== 5. 开宝箱按钮 ========
    local canSingle = data.gold >= Equipment.PULL_COST_SINGLE
    local canTriple = data.gold >= Equipment.PULL_COST_TRIPLE

    children[#children + 1] = UI.Panel {
        width = "100%", flexDirection = "row",
        justifyContent = "center", gap = 16,
        paddingLeft = 24, paddingRight = 24,
        paddingBottom = 8,
        children = {
            -- "开一次" 按钮 (金色，3D凸起质感)
            UI.Panel {
                flexGrow = 1, height = 60,
                borderRadius = 0,
                backgroundGradient = canSingle and {
                    type = "linear", direction = "to-bottom",
                    from = {160, 110, 10, 255}, to = {90, 60, 0, 255},
                } or {
                    type = "linear", direction = "to-bottom",
                    from = {40, 42, 55, 255}, to = {25, 27, 35, 255},
                },
                paddingBottom = canSingle and 4 or 0,
                boxShadow = canSingle and {
                    { x = 0, y = 5, blur = 14, spread = 0, color = {0, 0, 0, 100} },
                    { x = 0, y = 0, blur = 18, spread = 3, color = {255, 200, 40, 40} },
                    { x = 0, y = -1, blur = 0, spread = 0, color = {255, 240, 160, 40} },
                } or {
                    { x = 0, y = 3, blur = 8, spread = 0, color = {0, 0, 0, 60} },
                    { x = 0, y = 0, blur = 1, spread = 0, color = {60, 65, 85, 80} },
                },
                onClick = canSingle and function(self)
                    AM.PlaySFX("ui_gacha_pull")
                    if callbacks and callbacks.onPull then callbacks.onPull(1) end
                end or nil,
                children = {
                    UI.Panel {
                        width = "100%", flexGrow = 1,
                        borderRadius = 0,
                        justifyContent = "center", alignItems = "center",
                        backgroundGradient = canSingle and {
                            type = "linear", direction = "to-bottom",
                            from = {255, 235, 100, 255}, to = {225, 170, 25, 255},
                        } or {
                            type = "linear", direction = "to-bottom",
                            from = {50, 53, 68, 255}, to = {38, 40, 52, 255},
                        },
                        borderWidth = 1.5,
                        borderColor = canSingle and {255, 245, 160, 200} or {65, 70, 90, 200},
                        gap = 2,
                        children = {
                            UI.Label {
                                text = "开一次",
                                fontSize = 18, fontWeight = "bold",
                                fontColor = canSingle and {50, 30, 0, 255} or {120, 125, 145, 255},
                                textShadow = canSingle and { offsetX = 0, offsetY = 1, blur = 0, color = {255, 255, 200, 80} } or nil,
                            },
                            UI.Label {
                                text = canSingle and (Equipment.PULL_COST_SINGLE .. "G") or ("金币不足 · " .. Equipment.PULL_COST_SINGLE .. "G"),
                                fontSize = canSingle and 13 or 12,
                                fontColor = canSingle and {90, 55, 0, 220} or {255, 100, 100, 200},
                            },
                        },
                    },
                },
            },
            -- "开三次" 按钮 (紫色，3D凸起质感)
            UI.Panel {
                flexGrow = 1, height = 60,
                borderRadius = 0,
                backgroundGradient = canTriple and {
                    type = "linear", direction = "to-bottom",
                    from = {100, 45, 160, 255}, to = {50, 15, 90, 255},
                } or {
                    type = "linear", direction = "to-bottom",
                    from = {40, 42, 55, 255}, to = {25, 27, 35, 255},
                },
                paddingBottom = canTriple and 4 or 0,
                boxShadow = canTriple and {
                    { x = 0, y = 5, blur = 14, spread = 0, color = {0, 0, 0, 100} },
                    { x = 0, y = 0, blur = 18, spread = 3, color = {160, 80, 240, 40} },
                    { x = 0, y = -1, blur = 0, spread = 0, color = {220, 170, 255, 40} },
                } or {
                    { x = 0, y = 3, blur = 8, spread = 0, color = {0, 0, 0, 60} },
                    { x = 0, y = 0, blur = 1, spread = 0, color = {60, 65, 85, 80} },
                },
                onClick = canTriple and function(self)
                    AM.PlaySFX("ui_gacha_pull")
                    if callbacks and callbacks.onPull then callbacks.onPull(3) end
                end or nil,
                children = {
                    UI.Panel {
                        width = "100%", flexGrow = 1,
                        borderRadius = 0,
                        justifyContent = "center", alignItems = "center",
                        backgroundGradient = canTriple and {
                            type = "linear", direction = "to-bottom",
                            from = {200, 120, 255, 255}, to = {140, 60, 220, 255},
                        } or {
                            type = "linear", direction = "to-bottom",
                            from = {50, 53, 68, 255}, to = {38, 40, 52, 255},
                        },
                        borderWidth = 1.5,
                        borderColor = canTriple and {230, 180, 255, 200} or {65, 70, 90, 200},
                        gap = 2,
                        children = {
                            UI.Label {
                                text = "开三次",
                                fontSize = 18, fontWeight = "bold",
                                fontColor = canTriple and {255, 255, 255, 255} or {120, 125, 145, 255},
                                textShadow = canTriple and { offsetX = 0, offsetY = 1, blur = 3, color = {0, 0, 0, 60} } or nil,
                            },
                            UI.Panel {
                                flexDirection = "row", alignItems = "center", gap = 3,
                                children = {
                                    UI.Label {
                                        text = canTriple and (Equipment.PULL_COST_TRIPLE .. "G") or ("金币不足 · " .. Equipment.PULL_COST_TRIPLE .. "G"),
                                        fontSize = canTriple and 13 or 12,
                                        fontColor = canTriple and {220, 195, 255, 230} or {255, 100, 100, 200},
                                    },
                                    canTriple and UI.Label {
                                        text = "省40G",
                                        fontSize = 11, fontColor = {120, 255, 120, 200},
                                    } or nil,
                                },
                            },
                        },
                    },
                },
            },
        },
    }

    -- ======== 6. 抽奖规则入口按钮 ========
    children[#children + 1] = UI.Panel {
        width = "100%", alignItems = "center",
        paddingTop = 4, paddingBottom = 8,
        children = {
            UI.Panel {
                flexDirection = "row", alignItems = "center", gap = 5,
                paddingTop = 6, paddingBottom = 6,
                paddingLeft = 18, paddingRight = 18,
                borderRadius = 0,
                backgroundColor = {255, 255, 255, 10},
                borderWidth = 1,
                borderColor = {255, 255, 255, 35},
                onClick = function(self)
                    AM.PlaySFX("ui_click")
                    if callbacks and callbacks.onShowRules then callbacks.onShowRules() end
                end,
                children = {
                    UI.Label {
                        text = "📋",
                        fontSize = 13,
                    },
                    UI.Label {
                        text = "抽奖规则",
                        fontSize = 13,
                        fontColor = {200, 200, 220, 200},
                    },
                },
            },
        },
    }

    return children
end

-- ============================================================================
-- 抽奖结果弹窗内容
-- ============================================================================

function MenuPages.BuildPullResults(results)
    local children = {}
    children[#children + 1] = UI.Label {
        text = "获得装备！", fontSize = 28, fontColor = {255, 220, 60, 255},
        fontWeight = "bold",
        textShadow = { offsetX = 0, offsetY = 1, blur = 5, color = {255, 200, 40, 50} },
        marginBottom = 8,
    }

    -- 稀有度颜色（直接从 Equipment 定义获取）
    local rarityColors = {}
    for _, r in ipairs(Equipment.RARITIES) do
        rarityColors[r.id] = r.color
    end

    -- 构建装备图标项
    local iconItems = {}
    for _, item in ipairs(results) do
        local display = Equipment.GetItemDisplay(item)
        if display then
            local rarity = item.rarity or "blue"
            local rc = rarityColors[rarity] or {140, 155, 175, 255}
            -- 背景色：稀有度颜色的暗色版本
            local bgColor = {
                math.floor(rc[1] * 0.25),
                math.floor(rc[2] * 0.25),
                math.floor(rc[3] * 0.25),
                240,
            }
            -- 金色装备用更亮的背景突出
            if rarity == "gold" then
                bgColor = {60, 48, 10, 240}
            end

            local iconElem
            if display.iconId and IconAtlas.GetPath(display.iconId) then
                iconElem = UI.Panel {
                    backgroundImage = IconAtlas.GetPath(display.iconId),
                    width = 64, height = 64,
                    backgroundFit = "contain",
                }
            else
                iconElem = UI.Label {
                    text = display.icon,
                    fontSize = 44,
                    textAlign = "center",
                }
            end

            iconItems[#iconItems + 1] = UI.Panel {
                width = 88, height = 108,
                alignItems = "center",
                justifyContent = "center",
                gap = 4,
                backgroundColor = bgColor,
                borderRadius = 0,
                borderWidth = 2.5,
                borderColor = rc,
                boxShadow = {
                    { x = 0, y = 2, blur = 8, spread = 0, color = {0, 0, 0, 60} },
                    { x = 0, y = 0, blur = 10, spread = 2, color = {rc[1], rc[2], rc[3], rarity == "gold" and 60 or 25} },
                },
                children = {
                    iconElem,
                    UI.Label {
                        text = display.name,
                        fontSize = 13,
                        fontColor = rc,
                        textAlign = "center",
                        numberOfLines = 1,
                    },
                },
            }
        end
    end

    -- 按每行5个分行
    local perRow = 5
    local totalItems = #iconItems
    -- 如果只有1-3个，单行居中即可
    if totalItems <= perRow then
        children[#children + 1] = UI.Panel {
            width = "100%",
            flexDirection = "row",
            justifyContent = "center",
            gap = 8,
            flexWrap = "wrap",
            children = iconItems,
        }
    else
        -- 分行展示
        local row1 = {}
        local row2 = {}
        for i, item in ipairs(iconItems) do
            if i <= perRow then
                row1[#row1 + 1] = item
            else
                row2[#row2 + 1] = item
            end
        end
        children[#children + 1] = UI.Panel {
            width = "100%",
            gap = 8,
            alignItems = "center",
            children = {
                UI.Panel {
                    flexDirection = "row",
                    justifyContent = "center",
                    gap = 8,
                    children = row1,
                },
                UI.Panel {
                    flexDirection = "row",
                    justifyContent = "center",
                    gap = 8,
                    children = row2,
                },
            },
        }
    end

    return children
end

return MenuPages
