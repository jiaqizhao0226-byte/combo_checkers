-- ============================================================================
-- MenuSystem - 主菜单 UI 构建与 Tab 切换
-- ============================================================================

local UI = require("urhox-libs/UI")
local Battle = require "Battle"
local PlayerData = require "PlayerData"
local Equipment = require "Equipment"
local MenuPages = require "MenuPages"
local MenuHeroWidget = require "MenuHeroWidget"
local IconAtlas = require "IconAtlas"
local G = require "GameState"
local AM = require "AudioManager"
local SettingsPopup = require "SettingsPopup"
local GuildPage = require "GuildPage"

local MenuSystem = {}

-- 公会排行榜自动刷新状态
local _guildRefresh = {
    timer   = 0,        -- 距离上次刷新已累计的秒数
    fetchFn = nil,      -- 由公会页面构建后注入
    INTERVAL = 3600,    -- 自动刷新间隔（秒）
}

--- Tab 页面信息
local TAB_INFO = {
    { id = "shop",      emoji = "🛒", label = "商店" },
    { id = "equip",     emoji = "🛡️", label = "装备" },
    { id = "adventure", emoji = "🗺️", label = "冒险" },
    { id = "talent",    emoji = "⭐", label = "天赋" },
    { id = "guild",     emoji = "🏰", label = "公会" },
}

local TAB_PAGE_CONTENT = {
    shop      = { title = "商店", desc = "即将开放，敬请期待..." },
    equip     = { title = "角色装备", desc = "即将开放，敬请期待..." },
    adventure = { title = "开始冒险", desc = "" },
    talent    = { title = "天赋升级", desc = "即将开放，敬请期待..." },
    guild     = { title = "公会", desc = "即将开放，敬请期待..." },
}

function MenuSystem.SwitchTab(tabId)
    AM.PlaySFX("ui_tab_switch")
    G.menuTab = tabId
    -- 更新按钮高亮：选中放大突出 + 文字标签
    for _, btn in ipairs(G.menuTabButtons) do
        local isActive = (btn._tabId == tabId)
        -- 图标：选中放大上移，未选中正常（GetChildAt 是 1-based）
        local iconLabel = btn:GetChildAt(1)
        if iconLabel then
            iconLabel:SetStyle({
                fontSize = isActive and 38 or 26,
                top = isActive and -8 or 0,
            })
        end
        -- 文字标签：仅选中时显示（用 SetVisible 而非 display）
        local textLabel = btn:GetChildAt(2)
        if textLabel then
            textLabel:SetVisible(isActive)
        end
    end
    -- 更新菜单顶部金币
    if G.menuGoldLabel then
        G.menuGoldLabel:SetText(tostring(G.playerData.gold))
    end
    -- 动态刷新页面内容
    MenuSystem.RebuildMenuPage(tabId)
end

--- 重新构建菜单页面内容
function MenuSystem.RebuildMenuPage(tabId)
    if not G.menuPageContainer then return end
    -- 清理弹窗和拖拽状态
    MenuSystem.HideItemDetail()
    if G.dragOverlay then
        G.dragOverlay:SetVisible(false)
        G.dragOverlay = nil
    end
    G.dragItemIdx = nil
    G.dragTargetSlot = nil
    -- 切离装备页时清除分解模式状态
    if tabId ~= "equip" then
        G._decomposeMode = false
        G._decomposeSelected = nil
    end
    -- 刷新顶部金币显示
    if G.menuGoldLabel then
        G.menuGoldLabel:SetText(tostring(G.playerData.gold))
    end
    G.menuPageContainer:ClearChildren()

    local contentSlot = G.menuContentSlot
    if contentSlot then
        if G.menuHeroArea and G.menuHeroArea.parent == contentSlot then
            G.menuHeroArea:Remove()
        end
        if G.menuScrollView and G.menuScrollView.parent == contentSlot then
            G.menuScrollView:Remove()
        end
        if G.menuAdvBottomBar and G.menuAdvBottomBar.parent == contentSlot then
            G.menuAdvBottomBar:Remove()
        end

        if tabId == "adventure" then
            contentSlot:AddChild(G.menuHeroArea)
            contentSlot:AddChild(G.menuAdvBottomBar)
        else
            contentSlot:AddChild(G.menuScrollView)
        end
    end

    if tabId == "talent" then
        local children = MenuPages.BuildTalentPage(G.playerData, {
            onUpgrade = function(talentId)
                local ok, err = PlayerData.UpgradeTalent(G.playerData, talentId)
                if ok then
                    PlayerData.Save(G.playerData)
                    MenuSystem.RebuildMenuPage("talent")
                end
            end,
        })
        for _, child in ipairs(children) do
            G.menuPageContainer:AddChild(child)
        end

    elseif tabId == "shop" then
        -- 注册轮播切换回调
        MenuPages._shopCarousel.onSwitch = function(newIndex)
            MenuSystem.RebuildMenuPage("shop")
        end
        local children = MenuPages.BuildShopPage(G.playerData, {
            onPull = function(count)
                local results, err = Equipment.Pull(G.playerData, count)
                if results then
                    PlayerData.Save(G.playerData)
                    MenuSystem.ShowGachaResults(results)
                    MenuSystem.RebuildMenuPage("shop")
                end
            end,
            onShowRules = function()
                MenuSystem.ShowGachaRules()
            end,
        })
        for _, child in ipairs(children) do
            G.menuPageContainer:AddChild(child)
        end

    elseif tabId == "equip" then
        -- 分解模式状态（临时，切页面时自动清除）
        G._decomposeMode = G._decomposeMode or false
        G._decomposeSelected = G._decomposeSelected or {}

        -- 将分解状态注入 data 供 UI 读取
        G.playerData._decomposing = G._decomposeMode
        G.playerData._selectedForDecompose = G._decomposeSelected

        local children = MenuPages.BuildEquipPage(G.playerData, {
            onShowDetail = function(idx, cellWidget)
                MenuSystem.ShowItemDetail(idx, cellWidget)
            end,
            onDragStart = function(idx, targetSlot, x, y)
                MenuSystem.StartDrag(idx, targetSlot, x, y)
            end,
            onDragMove = function(x, y)
                MenuSystem.UpdateDrag(x, y)
            end,
            onDragEnd = function(idx, targetSlot, x, y, slotWidget)
                MenuSystem.EndDrag(idx, targetSlot, x, y, slotWidget)
            end,
            onEquipDragStart = function(slot, x, y)
                MenuSystem.StartEquipSlotDrag(slot, x, y)
            end,
            onEquipDragEnd = function(slot, x, y)
                MenuSystem.EndEquipSlotDrag(slot)
            end,
            onUnequip = function(slot)
                PlayerData.UnequipItem(G.playerData, slot)
                PlayerData.Save(G.playerData)
                MenuSystem.RebuildMenuPage("equip")
            end,
            onToggleDecompose = function(enter)
                G._decomposeMode = enter
                G._decomposeSelected = {}
                MenuSystem.RebuildMenuPage("equip")
            end,
            onSelectDecompose = function(idx)
                if G._decomposeSelected[idx] then
                    G._decomposeSelected[idx] = nil
                else
                    G._decomposeSelected[idx] = true
                end
                -- 保存滚动位置
                local scrollPanel = G.menuPageContainer and G.menuPageContainer:FindById("equipInvScroll")
                if scrollPanel and scrollPanel.GetScroll then
                    local _, sy = scrollPanel:GetScroll()
                    G._decomposeScrollY = sy
                end
                MenuSystem.RebuildMenuPage("equip")
                -- 恢复滚动位置
                local newScrollPanel = G.menuPageContainer and G.menuPageContainer:FindById("equipInvScroll")
                if newScrollPanel and newScrollPanel.SetScrollDirect and G._decomposeScrollY then
                    newScrollPanel:SetScrollDirect(0, G._decomposeScrollY)
                end
            end,
            onConfirmDecompose = function()
                local indices = {}
                for idx, _ in pairs(G._decomposeSelected) do
                    indices[#indices + 1] = idx
                end
                if #indices == 0 then return end
                local totalGold, count = Equipment.Decompose(G.playerData, indices)
                PlayerData.Save(G.playerData)
                AM.PlaySFX("item_pickup")
                log:Write(LOG_INFO, string.format("[Decompose] 分解 %d 件装备，获得 %d 金币", count, totalGold))
                -- 退出分解模式并刷新
                G._decomposeMode = false
                G._decomposeSelected = {}
                MenuSystem.RebuildMenuPage("equip")
            end,
            onSelectAllBlue = function()
                -- 全选/全取消蓝色装备
                local inventory = G.playerData.inventory
                -- 先检查是否已全选蓝色，若是则全取消
                local allSelected = true
                local blueCount = 0
                for i, item in ipairs(inventory) do
                    local r = Equipment.RARITY_MIGRATE[item.rarity] or item.rarity
                    if r == "blue" then
                        blueCount = blueCount + 1
                        if not G._decomposeSelected[i] then
                            allSelected = false
                        end
                    end
                end
                if blueCount == 0 then return end
                if allSelected then
                    -- 已全选 → 取消全部蓝色
                    for i, item in ipairs(inventory) do
                        local r = Equipment.RARITY_MIGRATE[item.rarity] or item.rarity
                        if r == "blue" then
                            G._decomposeSelected[i] = nil
                        end
                    end
                else
                    -- 未全选 → 选中全部蓝色
                    for i, item in ipairs(inventory) do
                        local r = Equipment.RARITY_MIGRATE[item.rarity] or item.rarity
                        if r == "blue" then
                            G._decomposeSelected[i] = true
                        end
                    end
                end
                -- 保存滚动位置
                local scrollPanel = G.menuPageContainer and G.menuPageContainer:FindById("equipInvScroll")
                if scrollPanel and scrollPanel.GetScroll then
                    local _, sy = scrollPanel:GetScroll()
                    G._decomposeScrollY = sy
                end
                MenuSystem.RebuildMenuPage("equip")
                -- 恢复滚动位置
                local newScrollPanel = G.menuPageContainer and G.menuPageContainer:FindById("equipInvScroll")
                if newScrollPanel and newScrollPanel.SetScrollDirect and G._decomposeScrollY then
                    newScrollPanel:SetScrollDirect(0, G._decomposeScrollY)
                end
            end,
            onSelectAllPurple = function()
                -- 全选/全取消紫色装备
                local inventory = G.playerData.inventory
                -- 先检查是否已全选紫色，若是则全取消
                local allSelected = true
                local purpleCount = 0
                for i, item in ipairs(inventory) do
                    local r = Equipment.RARITY_MIGRATE[item.rarity] or item.rarity
                    if r == "purple" then
                        purpleCount = purpleCount + 1
                        if not G._decomposeSelected[i] then
                            allSelected = false
                        end
                    end
                end
                if purpleCount == 0 then return end
                if allSelected then
                    -- 已全选 → 取消全部紫色
                    for i, item in ipairs(inventory) do
                        local r = Equipment.RARITY_MIGRATE[item.rarity] or item.rarity
                        if r == "purple" then
                            G._decomposeSelected[i] = nil
                        end
                    end
                else
                    -- 未全选 → 选中全部紫色
                    for i, item in ipairs(inventory) do
                        local r = Equipment.RARITY_MIGRATE[item.rarity] or item.rarity
                        if r == "purple" then
                            G._decomposeSelected[i] = true
                        end
                    end
                end
                -- 保存滚动位置
                local scrollPanel = G.menuPageContainer and G.menuPageContainer:FindById("equipInvScroll")
                if scrollPanel and scrollPanel.GetScroll then
                    local _, sy = scrollPanel:GetScroll()
                    G._decomposeScrollY = sy
                end
                MenuSystem.RebuildMenuPage("equip")
                -- 恢复滚动位置
                local newScrollPanel = G.menuPageContainer and G.menuPageContainer:FindById("equipInvScroll")
                if newScrollPanel and newScrollPanel.SetScrollDirect and G._decomposeScrollY then
                    newScrollPanel:SetScrollDirect(0, G._decomposeScrollY)
                end
            end,
        })

        -- 清理临时字段
        G.playerData._decomposing = nil
        G.playerData._selectedForDecompose = nil

        for _, child in ipairs(children) do
            G.menuPageContainer:AddChild(child)
        end

    elseif tabId == "adventure" then
        -- 判断章节是否已解锁
        local function IsChapterUnlocked(ch)
            if ch == 0 then
                -- 无尽模式：通关第3章后解锁
                return (G.playerData.highestLevel or 1) > 3 * Battle.LEVELS_PER_CHAPTER
            end
            if ch <= 1 then return true end
            -- 主线章节：必须通关上一章 Boss（highestLevel > 上一章末尾关卡）
            return (G.playerData.highestLevel or 1) > (ch - 1) * Battle.LEVELS_PER_CHAPTER
        end

        -- 章节主题色映射（箭头按钮跟随章节变色）
        local arrowThemes = {
            [0] = { from = {100, 55, 140, 220}, to = {55, 28, 80, 240},  pressed = {140, 80, 190, 240}, border = {180, 120, 255, 100}, glow = {140, 80, 220, 50} },
            [1] = { from = {50, 70, 140, 220},  to = {25, 35, 80, 240},  pressed = {80, 110, 190, 240}, border = {100, 150, 255, 100}, glow = {70, 120, 220, 50} },
            [2] = { from = {140, 60, 40, 220},  to = {80, 30, 20, 240},  pressed = {190, 90, 60, 240},  border = {255, 130, 80, 100},  glow = {220, 90, 40, 50} },
            [3] = { from = {50, 130, 100, 220}, to = {25, 70, 55, 240},  pressed = {80, 180, 140, 240}, border = {120, 220, 180, 100}, glow = {80, 200, 150, 50} },
            [4] = { from = {140, 110, 40, 220}, to = {80, 60, 20, 240},  pressed = {190, 150, 60, 240}, border = {220, 180, 80, 100},  glow = {200, 160, 50, 50} },
        }
        local at = arrowThemes[G.selectedChapter] or arrowThemes[1]

        -- 更新箭头按钮可见性 + 主题色
        if G.menuArrowLeft then
            G.menuArrowLeft:SetVisible(G.selectedChapter > 0)
            G.menuArrowLeft:SetStyle({
                backgroundGradient = { type = "linear", direction = "to-bottom", from = at.from, to = at.to },
                pressedBackgroundColor = at.pressed,
                borderColor = at.border,
                boxShadow = {
                    { x = 0, y = 2, blur = 8, spread = 0, color = {0, 0, 0, 90} },
                    { x = 0, y = 0, blur = 10, spread = 1, color = at.glow },
                },
            })
        end
        if G.menuArrowRight then
            G.menuArrowRight:SetVisible(G.selectedChapter < 4)
            G.menuArrowRight:SetStyle({
                backgroundGradient = { type = "linear", direction = "to-bottom", from = at.from, to = at.to },
                pressedBackgroundColor = at.pressed,
                borderColor = at.border,
                boxShadow = {
                    { x = 0, y = 2, blur = 8, spread = 0, color = {0, 0, 0, 90} },
                    { x = 0, y = 0, blur = 10, spread = 1, color = at.glow },
                },
            })
        end

        local advBar = G.menuAdvBottomBar
        if advBar then
            advBar:ClearChildren()
            local ch = G.selectedChapter
            -- 动态匹配章节底部背景色（与 MenuHeroWidget 渲染保持一致）
            local chapterGlowColors = {
                [0] = {160, 100, 240},
                [1] = {40, 120, 220},
                [2] = {220, 100, 40},
                [3] = {80, 200, 150},
                [4] = {200, 160, 50},
            }
            local gc = chapterGlowColors[ch] or chapterGlowColors[1]
            local botR = math.floor(10 + gc[1] * 0.06)
            local botG = math.floor(8 + gc[2] * 0.05)
            local botB = math.floor(28 + gc[3] * 0.05)
            advBar:SetStyle({
                backgroundGradient = {
                    type = "linear", direction = "to-bottom",
                    from = {botR, botG, botB, 255}, to = {botR, botG, botB, 255},
                },
            })
            local chapterFirst = (ch - 1) * Battle.LEVELS_PER_CHAPTER + 1
            local chapterLast = ch * Battle.LEVELS_PER_CHAPTER
            local chapterUnlocked = IsChapterUnlocked(ch)


            if chapterUnlocked then
                if ch == 0 then
                    -- ── 无尽模式入口（特殊模式，在第1章左边）──
                    local bestWave = G.playerData.highestEndlessWave or 0
                    local bestText = bestWave > 0 and ("历史最高：第 " .. bestWave .. " 波") or "尚未挑战"
                    -- 外壳（紫色暗底）
                    advBar:AddChild(UI.Panel {
                        width = "75%", maxWidth = 320, height = 72,
                        borderRadius = 16,
                        backgroundGradient = {
                            type = "linear", direction = "to-bottom",
                            from = {60, 15, 100, 255}, to = {35, 8, 60, 255},
                        },
                        paddingBottom = 5,
                        boxShadow = {
                            { x = 0, y = 8, blur = 18, spread = 2, color = {30, 5, 60, 220} },
                            { x = 0, y = 3, blur = 24, spread = 6, color = {160, 60, 255, 40} },
                            { x = 0, y = -1, blur = 3, spread = 0, color = {200, 140, 255, 50} },
                        },
                        onClick = function(self)
                            AM.PlaySFX("ui_click")
                            if G.callbacks.EnterEndless then
                                G.callbacks.EnterEndless()
                            end
                        end,
                        children = {
                            UI.Panel {
                                width = "100%", flexGrow = 1,
                                borderRadius = 16,
                                justifyContent = "center", alignItems = "center",
                                backgroundGradient = {
                                    type = "linear", direction = "to-bottom",
                                    from = {170, 70, 255, 255}, to = {110, 30, 190, 255},
                                },
                                borderWidth = 1.5,
                                borderColor = {200, 140, 255, 180},
                                children = {
                                    UI.Panel {
                                        position = "absolute",
                                        top = 2, left = "12%", right = "12%", height = 12,
                                        borderRadius = 6,
                                        backgroundGradient = {
                                            type = "linear", direction = "to-bottom",
                                            from = {255, 255, 255, 100}, to = {255, 255, 255, 0},
                                        },
                                    },
                                    UI.Label {
                                        text = "🌀  无尽挑战",
                                        fontSize = 28, fontWeight = "bold",
                                        fontColor = {255, 255, 255, 255},
                                        textStroke = { width = 1.5, color = {60, 10, 120, 220} },
                                        textShadow = { offsetX = 0, offsetY = 2, blur = 4, color = {30, 5, 80, 200} },
                                    },
                                },
                            },
                        },
                    })
                    advBar:AddChild(UI.Label {
                        text = bestText,
                        fontSize = 15, fontColor = {180, 140, 255, 200},
                        marginTop = 6,
                    })
                else
                    -- ── 已解锁：显示"开始冒险"按钮 ──
                    -- 3D 立体按钮：外壳(暗色底边) + 内容面板(橘色渐变) + 高光层
                    advBar:AddChild(UI.Panel {
                        width = "75%", maxWidth = 320, height = 72,
                        borderRadius = 16,
                        backgroundGradient = {
                            type = "linear", direction = "to-bottom",
                            from = {140, 55, 5, 255}, to = {90, 30, 0, 255},
                        },
                        paddingBottom = 5,
                        boxShadow = {
                            { x = 0, y = 8, blur = 18, spread = 2, color = {50, 15, 0, 220} },
                            { x = 0, y = 3, blur = 24, spread = 6, color = {255, 120, 20, 40} },
                            { x = 0, y = -1, blur = 3, spread = 0, color = {255, 180, 80, 50} },
                        },
                        onClick = function(self)
                            AM.PlaySFX("ui_click")
                            G.callbacks.EnterGame(chapterFirst)
                        end,
                        children = {
                            UI.Panel {
                                width = "100%", flexGrow = 1,
                                borderRadius = 16,
                                justifyContent = "center", alignItems = "center",
                                backgroundGradient = {
                                    type = "linear", direction = "to-bottom",
                                    from = {255, 175, 50, 255}, to = {215, 100, 15, 255},
                                },
                                borderWidth = 1.5,
                                borderColor = {255, 185, 80, 180},
                                children = {
                                    UI.Panel {
                                        position = "absolute",
                                        top = 2, left = "12%", right = "12%", height = 12,
                                        borderRadius = 6,
                                        backgroundGradient = {
                                            type = "linear", direction = "to-bottom",
                                            from = {255, 255, 255, 110}, to = {255, 255, 255, 0},
                                        },
                                    },
                                    UI.Panel {
                                        flexDirection = "row", alignItems = "center", gap = 6,
                                        children = {
                                            UI.Label {
                                                text = "⚔️",
                                                fontSize = 26,
                                            },
                                            UI.Label {
                                                text = "开始冒险",
                                                fontSize = 28, fontWeight = "bold",
                                                fontColor = {255, 255, 255, 255},
                                                textStroke = { width = 1.5, color = {120, 40, 0, 220} },
                                                textShadow = { offsetX = 0, offsetY = 2, blur = 4, color = {60, 15, 0, 200} },
                                            },
                                        },
                                    },
                                },
                            },
                        },
                    })
                    advBar:AddChild(UI.Label {
                        text = "已冒险 " .. (G.playerData.totalRuns or 0) .. " 次",
                        fontSize = 16, fontColor = {100, 110, 140, 180},
                        marginTop = 6,
                    })
                end
            else
                -- ── 未解锁：橘色 3D 按钮（与"开始冒险"同款视觉，禁用态）+ 测试按钮 ──
                local prevChapterName
                if ch == 0 then
                    prevChapterName = Battle.CHAPTER_NAMES[3] or "珊瑚迷宫"
                else
                    prevChapterName = Battle.CHAPTER_NAMES and Battle.CHAPTER_NAMES[ch - 1] or ("第" .. (ch-1) .. "章")
                end
                advBar:AddChild(UI.Panel {
                    width = "75%", maxWidth = 320, height = 72,
                    borderRadius = 16,
                    backgroundGradient = {
                        type = "linear", direction = "to-bottom",
                        from = {140, 55, 5, 255}, to = {90, 30, 0, 255},
                    },
                    paddingBottom = 5,
                    boxShadow = {
                        { x = 0, y = 8, blur = 18, spread = 2, color = {50, 15, 0, 220} },
                        { x = 0, y = 3, blur = 24, spread = 6, color = {255, 120, 20, 40} },
                        { x = 0, y = -1, blur = 3, spread = 0, color = {255, 180, 80, 50} },
                    },
                    children = {
                        UI.Panel {
                            width = "100%", flexGrow = 1,
                            borderRadius = 16,
                            justifyContent = "center", alignItems = "center",
                            backgroundGradient = {
                                type = "linear", direction = "to-bottom",
                                from = {255, 175, 50, 255}, to = {215, 100, 15, 255},
                            },
                            borderWidth = 1.5,
                            borderColor = {255, 185, 80, 180},
                            children = {
                                -- 顶部高光条
                                UI.Panel {
                                    position = "absolute",
                                    top = 2, left = "12%", right = "12%", height = 12,
                                    borderRadius = 6,
                                    backgroundGradient = {
                                        type = "linear", direction = "to-bottom",
                                        from = {255, 255, 255, 110}, to = {255, 255, 255, 0},
                                    },
                                },
                                UI.Panel {
                                    flexDirection = "row", alignItems = "center", gap = 6,
                                    children = {
                                        UI.Label {
                                            text = "🔒",
                                            fontSize = 26,
                                        },
                                        UI.Label {
                                            text = "未解锁",
                                            fontSize = 28, fontWeight = "bold",
                                            fontColor = {255, 255, 255, 255},
                                            textStroke = { width = 1.5, color = {120, 40, 0, 220} },
                                            textShadow = { offsetX = 0, offsetY = 2, blur = 4, color = {60, 15, 0, 200} },
                                        },
                                    },
                                },
                            },
                        },
                    },
                })
                advBar:AddChild(UI.Label {
                    text = "通关「" .. prevChapterName .. "」后解锁",
                    fontSize = 16, fontColor = {100, 110, 140, 180},
                    marginTop = 6,
                })
            end
        end

    elseif tabId == "guild" then
        -- ----------------------------------------------------------------
        -- 公会排行榜页面（含 Tab：冒险排行 / 无尽排行）
        -- ----------------------------------------------------------------
        local activeGuildTab = "adventure"  -- "adventure" | "endless"

        -- ---- Tab 切换栏 ----
        local tabAdventureBtn, tabEndlessBtn  -- 前向声明
        local adventureContainer, endlessContainer

        local function setGuildTab(which)
            activeGuildTab = which
            local advActive   = (which == "adventure")
            local endActive   = (which == "endless")

            -- Tab 按钮高亮
            tabAdventureBtn:SetStyle({
                backgroundGradient = advActive
                    and { type="linear", direction="to-bottom", from={80,55,160,220}, to={50,30,110,240} }
                    or  nil,
                backgroundColor   = advActive and nil or {30, 30, 50, 0},
                borderBottomWidth = advActive and 2 or 0,
                borderColor       = advActive and {160, 120, 255, 255} or {0,0,0,0},
            })
            tabEndlessBtn:SetStyle({
                backgroundGradient = endActive
                    and { type="linear", direction="to-bottom", from={80,30,140,220}, to={50,15,100,240} }
                    or  nil,
                backgroundColor   = endActive and nil or {30, 30, 50, 0},
                borderBottomWidth = endActive and 2 or 0,
                borderColor       = endActive and {200, 100, 255, 255} or {0,0,0,0},
            })

            -- 容器显示切换
            adventureContainer:SetVisible(advActive)
            endlessContainer:SetVisible(endActive)
        end

        tabAdventureBtn = UI.Panel {
            flexGrow = 1, height = 40,
            borderRadius = 8,
            justifyContent = "center", alignItems = "center",
            onClick = function()
                AM.PlaySFX("ui_click")
                setGuildTab("adventure")
            end,
            children = {
                UI.Label {
                    text = "⚔️ 冒险排行",
                    fontSize = 14, fontWeight = "bold",
                    fontColor = {200, 195, 235, 240},
                },
            },
        }
        tabEndlessBtn = UI.Panel {
            flexGrow = 1, height = 40,
            borderRadius = 8,
            justifyContent = "center", alignItems = "center",
            onClick = function()
                AM.PlaySFX("ui_click")
                setGuildTab("endless")
            end,
            children = {
                UI.Label {
                    text = "🌀 无尽排行",
                    fontSize = 14, fontWeight = "bold",
                    fontColor = {200, 170, 255, 240},
                },
            },
        }

        local tabBar = UI.Panel {
            width = "100%",
            flexDirection = "row", gap = 4,
            paddingLeft = 12, paddingRight = 12,
            paddingBottom = 8,
            borderBottomWidth = 1, borderColor = {255, 255, 255, 18},
            marginBottom = 6,
            children = { tabAdventureBtn, tabEndlessBtn },
        }
        G.menuPageContainer:AddChild(tabBar)

        -- ---- 冒险排行容器 ----
        -- 1. 我的进度卡片 + 排行列表（onRefresh 转发，fetchAllRankData 在下方定义）
        local onRefreshProxy = function() end  -- 占位，fetchAllRankData 定义后覆盖
        local staticChildren = GuildPage.Build(G.playerData, function() onRefreshProxy() end)
        adventureContainer = UI.Panel {
            width = "100%", flexDirection = "column", alignItems = "stretch",
        }
        for _, child in ipairs(staticChildren) do
            adventureContainer:AddChild(child)
        end

        local rankContainer = UI.Panel {
            width = "100%", flexDirection = "column",
            alignItems = "stretch", gap = 0,
            paddingLeft = 12, paddingRight = 12,
            paddingBottom = 20,
        }
        adventureContainer:AddChild(rankContainer)
        G.menuPageContainer:AddChild(adventureContainer)

        -- 加载中占位（冒险）
        local loadingItems = GuildPage.BuildLoading()
        for _, child in ipairs(loadingItems) do
            rankContainer:AddChild(child)
        end

        -- ---- 无尽排行容器 ----
        endlessContainer = UI.Panel {
            width = "100%", flexDirection = "column", alignItems = "stretch",
            visible = false,
        }
        -- 我的无尽记录卡片
        local myEndlessCard = GuildPage.BuildEndlessMyCard(G.playerData)
        endlessContainer:AddChild(myEndlessCard)

        local endlessRankContainer = UI.Panel {
            width = "100%", flexDirection = "column",
            alignItems = "stretch", gap = 0,
            paddingLeft = 12, paddingRight = 12,
            paddingBottom = 20,
        }
        endlessContainer:AddChild(endlessRankContainer)
        G.menuPageContainer:AddChild(endlessContainer)

        -- 无尽排行加载占位
        local endlessLoadingItems = GuildPage.BuildLoading()
        for _, child in ipairs(endlessLoadingItems) do
            endlessRankContainer:AddChild(child)
        end

        -- 初始高亮第一个 Tab
        setGuildTab("adventure")

        -- ----------------------------------------------------------------
        -- 通用：将 rankList + nicknameMap 拼装格式化数据
        -- ----------------------------------------------------------------
        ---@diagnostic disable-next-line: undefined-global
        local myUserId = lobby and lobby:GetMyUserId() or ""

        local function buildRankDataAdventure(rankList, nicknameMap)
            local rankData = {}
            for _, entry in ipairs(rankList) do
                local uid  = tostring(entry.userId)
                local mapped = nicknameMap and nicknameMap[uid]
                local nick = (mapped and mapped ~= "") and mapped or ("玩家" .. uid:sub(-4))
                local iscore = entry.iscore or {}
                rankData[#rankData + 1] = {
                    nickname = nick,
                    level    = math.floor(tonumber(iscore.highest_level) or 1),
                    runs     = math.floor(tonumber(iscore.total_runs) or 0),
                    isMe     = (uid == myUserId),
                }
            end
            -- 重新排序：进度高优先，进度相同时把数少优先
            table.sort(rankData, function(a, b)
                if a.level ~= b.level then return a.level > b.level end
                return a.runs < b.runs
            end)
            -- 重新写入 rank 序号
            for i, row in ipairs(rankData) do
                row.rank = i
            end
            return rankData
        end

        local function buildRankDataEndless(rankList, nicknameMap)
            local rankData = {}
            for i, entry in ipairs(rankList) do
                local uid  = tostring(entry.userId)
                local mapped = nicknameMap and nicknameMap[uid]
                local nick = (mapped and mapped ~= "") and mapped or ("玩家" .. uid:sub(-4))
                local iscore = entry.iscore or {}
                rankData[i] = {
                    rank     = i,
                    nickname = nick,
                    wave     = math.floor(tonumber(iscore.endless_wave) or 0),
                    isMe     = (uid == myUserId),
                }
            end
            return rankData
        end

        local function fillContainer(container, rowChildren)
            if not container then return end
            container:ClearChildren()
            for _, child in ipairs(rowChildren) do
                container:AddChild(child)
            end
        end

        local function fetchNicknamesAndFill(rankList, container, buildFn, buildRowsFn)
            local userIds = {}
            for _, entry in ipairs(rankList) do
                -- 保持原始类型（数字），GetUserNickname 需要数字 ID，传字符串会静默失败
                userIds[#userIds + 1] = entry.userId
            end
            -- GetUserNickname 只在联网且 lobby 可用时存在
            if type(GetUserNickname) == "function" then
                GetUserNickname({
                    userIds = userIds,
                    onSuccess = function(nicknames)
                        local nicknameMap = {}
                        for _, info in ipairs(nicknames) do
                            -- 只存非空昵称，空字符串跳过，让 fallback 生效
                            if info.nickname and info.nickname ~= "" then
                                nicknameMap[tostring(info.userId)] = info.nickname
                            end
                        end
                        fillContainer(container, buildRowsFn(buildFn(rankList, nicknameMap)))
                    end,
                    onError = function()
                        fillContainer(container, buildRowsFn(buildFn(rankList, nil)))
                    end,
                })
            else
                -- 离线/测试：直接用 userId 后四位作为昵称
                fillContainer(container, buildRowsFn(buildFn(rankList, nil)))
            end
        end

        -- 2. 拉取函数（供首次加载和刷新按钮共用）
        local function fetchAllRankData()
            if clientCloud then
                -- 显示加载中
                local loadingRows = GuildPage.BuildLoading()
                fillContainer(rankContainer, loadingRows)
                local endlessLoadingRows = GuildPage.BuildLoading()
                fillContainer(endlessRankContainer, endlessLoadingRows)

                clientCloud:GetRankList("adventure_rank", 0, 20, {
                    ok = function(rankList)
                        if not rankList or #rankList == 0 then
                            fillContainer(rankContainer, GuildPage.BuildError("暂无排名数据，快去冒险吧！"))
                            return
                        end
                        fetchNicknamesAndFill(rankList, rankContainer,
                            buildRankDataAdventure, GuildPage.BuildRankList)
                    end,
                    error = function()
                        fillContainer(rankContainer, GuildPage.BuildError("加载失败，请稍后再试"))
                    end,
                }, "highest_level", "total_runs")

                clientCloud:GetRankList("endless_wave", 0, 20, {
                    ok = function(rankList)
                        if not rankList or #rankList == 0 then
                            fillContainer(endlessRankContainer, GuildPage.BuildEndlessRankList({}))
                            return
                        end
                        fetchNicknamesAndFill(rankList, endlessRankContainer,
                            buildRankDataEndless, GuildPage.BuildEndlessRankList)
                    end,
                    error = function()
                        fillContainer(endlessRankContainer, GuildPage.BuildError("加载失败，请稍后再试"))
                    end,
                })
            else
                -- 离线/测试环境
                fillContainer(rankContainer, GuildPage.BuildError("需要联网才能查看排行榜"))
                fillContainer(endlessRankContainer, GuildPage.BuildError("需要联网才能查看排行榜"))
            end
        end

        -- 将真正的拉取函数绑定到刷新代理（按钮用）和自动刷新（计时器用）
        onRefreshProxy = fetchAllRankData
        _guildRefresh.fetchFn = fetchAllRankData
        _guildRefresh.timer   = 0   -- 进入页面时重置计时器

        -- 首次加载
        fetchAllRankData()

    else
        G.menuPageContainer:AddChild(UI.Label {
            text = TAB_PAGE_CONTENT[tabId] and TAB_PAGE_CONTENT[tabId].title or "未知",
            fontSize = 28, fontColor = {220, 225, 245, 255},
            fontWeight = "bold",
        })
        G.menuPageContainer:AddChild(UI.Label {
            text = "即将开放，敬请期待...",
            fontSize = 19, fontColor = {120, 130, 160, 200},
        })
    end
end

-- ============================================================================
-- 装备详情弹窗
-- ============================================================================

function MenuSystem.ShowItemDetail(idx, cellWidget)
    MenuSystem.HideItemDetail()  -- 先关闭已有弹窗

    local item = G.playerData.inventory[idx]
    if not item then return end

    local popupContent = MenuPages.BuildItemDetailPopup(item, G.playerData.equipment)
    if not popupContent then return end

    -- 穿戴按钮
    local itemDef = Equipment.GetItemDef(item.id)
    local equipBtn = UI.Button {
        width = "100%", height = 42,
        backgroundGradient = {
            type = "linear", direction = "to-bottom",
            from = {80, 180, 100, 255}, to = {50, 140, 65, 255},
        },
        pressedBackgroundColor = {40, 120, 55, 255},
        borderRadius = 12,
        borderWidth = 1.5,
        borderColor = {120, 220, 140, 180},
        boxShadow = {
            { x = 0, y = 2, blur = 6, spread = 0, color = {0, 0, 0, 40} },
        },
        justifyContent = "center", alignItems = "center",
        onClick = function(self)
            AM.PlaySFX("ui_equip")
            MenuSystem.HideItemDetail()
            PlayerData.EquipItem(G.playerData, idx)
            PlayerData.Save(G.playerData)
            MenuSystem.RebuildMenuPage("equip")
        end,
        children = {
            UI.Label {
                text = "穿戴",
                fontSize = 18, fontWeight = "bold",
                fontColor = {255, 255, 255, 255},
                textShadow = { offsetX = 0, offsetY = 1, blur = 2, color = {0, 0, 0, 60} },
            },
        },
    }

    -- 将穿戴按钮加入弹窗内容
    popupContent:AddChild(equipBtn)

    -- 计算弹窗位置：始终在格子下方显示（不遮挡上方装备栏）
    local popupW = 300
    local screenW = graphics:GetWidth() / graphics:GetDPR()
    local screenH = graphics:GetHeight() / graphics:GetDPR()

    -- 默认水平居中、垂直偏下
    local popLeft = (screenW - popupW) / 2
    local popTop = screenH * 0.55

    -- 尝试获取格子的绝对位置
    if cellWidget then
        local ok, layout = pcall(function() return cellWidget:GetAbsoluteLayout() end)
        if ok and layout and layout.x and layout.y and layout.width and layout.height then
            local cx = layout.x + layout.width / 2
            local cellBottom = layout.y + layout.height

            -- 水平：弹窗居中对齐格子，但不超出屏幕
            popLeft = cx - popupW / 2
            if popLeft < 8 then popLeft = 8 end
            if popLeft + popupW > screenW - 8 then popLeft = screenW - popupW - 8 end

            -- 垂直：始终在格子下方
            popTop = cellBottom + 8
        end
    end

    -- 透明遮罩（点击关闭）+ 定位弹窗
    G.itemDetailPopup = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        onClick = function(self)
            MenuSystem.HideItemDetail()
        end,
        children = {
            UI.Panel {
                position = "absolute",
                left = popLeft,
                top = popTop,
                onClick = function(self) end,  -- 拦截冒泡
                children = { popupContent },
            },
        },
    }
    G.menuRoot:AddChild(G.itemDetailPopup)
end

function MenuSystem.HideItemDetail()
    if G.itemDetailPopup then
        G.itemDetailPopup:SetVisible(false)
        G.itemDetailPopup = nil
    end
end

-- ============================================================================
-- 装备拖拽管理
-- ============================================================================

function MenuSystem.StartDrag(idx, targetSlot, x, y)
    MenuSystem.HideItemDetail()  -- 拖拽时关闭弹窗
    MenuSystem.EndDrag()         -- 清除旧拖拽

    local item = G.playerData.inventory[idx]
    if not item then return end

    G.dragItemIdx = idx
    G.dragTargetSlot = targetSlot

    local display = Equipment.GetItemDisplay(item)
    if not display then return end

    local rarity = item.rarity or "common"
    -- 稀有度颜色（与 MenuPages 保持一致）
    local DRAG_BORDER = {
        common = {140, 155, 175, 220}, blue = {70, 170, 255, 255},
        purple = {200, 120, 255, 255}, gold = {255, 200, 40, 255},
    }
    local DRAG_BG = {
        common = {52, 58, 75, 255}, blue = {38, 58, 95, 255},
        purple = {60, 38, 88, 255}, gold = {70, 55, 20, 255},
    }
    local borderCol = DRAG_BORDER[rarity] or DRAG_BORDER.common
    local bgCol = DRAG_BG[rarity] or DRAG_BG.common
    local iconSize = 36
    local iconPath = display.iconId and IconAtlas.GetPath(display.iconId) or nil

    -- 创建浮动拖拽图标
    -- pointerEvents = "none"：让事件穿透到下方的格子，防止 ghost 把自己卡死
    local dragSize = 64
    G.dragOverlay = UI.Panel {
        position = "absolute",
        left = x - dragSize / 2,
        top = y - dragSize / 2,
        width = dragSize, height = dragSize,
        backgroundColor = bgCol,
        borderRadius = 12,
        borderWidth = 2.5,
        borderColor = borderCol,
        justifyContent = "center", alignItems = "center",
        opacity = 0.9,
        pointerEvents = "none",
        boxShadow = {
            { x = 0, y = 4, blur = 12, spread = 2, color = {0, 0, 0, 100} },
            { x = 0, y = 0, blur = 8, spread = 2, color = {borderCol[1], borderCol[2], borderCol[3], 60} },
        },
        children = {
            iconPath
                and UI.Panel { backgroundImage = iconPath, width = iconSize, height = iconSize, backgroundFit = "contain", pointerEvents = "none" }
                or  UI.Label { text = display.icon, fontSize = 28, textAlign = "center" },
        },
    }
    G.menuRoot:AddChild(G.dragOverlay)
end

function MenuSystem.UpdateDrag(x, y)
    if G.dragOverlay then
        local dragSize = 64
        G.dragOverlay:SetStyle({
            left = x - dragSize / 2,
            top = y - dragSize / 2,
        })
    end
end

function MenuSystem.EndDrag(idx, targetSlot, x, y, slotWidget)
    -- 清除浮动图标
    if G.dragOverlay then
        G.dragOverlay:SetVisible(false)
        G.dragOverlay = nil
    end

    -- 判断是否成功放置：检查松手位置是否在目标槽位上
    if idx and targetSlot and slotWidget then
        local ok, layout = pcall(function() return slotWidget:GetAbsoluteLayoutForHitTest() end)
        if ok and layout and layout.x and layout.y and layout.w and layout.h then
            local sx, sy, sw, sh = layout.x, layout.y, layout.w, layout.h
            if x >= sx and x <= sx + sw and y >= sy and y <= sy + sh then
                -- 成功放置！穿戴装备
                AM.PlaySFX("ui_equip")
                PlayerData.EquipItem(G.playerData, idx)
                PlayerData.Save(G.playerData)
                MenuSystem.RebuildMenuPage("equip")
                return
            end
        end
    end

    -- 未成功放置，不做任何操作（装备留在原位）
    G.dragItemIdx = nil
    G.dragTargetSlot = nil
end

-- ============================================================================
-- 装备槽拖拽脱下
-- ============================================================================

function MenuSystem.StartEquipSlotDrag(slot, x, y)
    MenuSystem.HideItemDetail()
    -- 清除可能存在的仓库拖拽
    if G.dragOverlay then
        G.dragOverlay:SetVisible(false)
        G.dragOverlay = nil
    end

    local item = G.playerData.equipment[slot]
    if not item then return end

    G.dragEquipSlot = slot

    local display = Equipment.GetItemDisplay(item)
    if not display then return end

    local rarity = item.rarity or "common"
    local DRAG_BORDER = {
        common = {140, 155, 175, 220}, blue = {70, 170, 255, 255},
        purple = {200, 120, 255, 255}, gold = {255, 200, 40, 255},
    }
    local DRAG_BG = {
        common = {52, 58, 75, 255}, blue = {38, 58, 95, 255},
        purple = {60, 38, 88, 255}, gold = {70, 55, 20, 255},
    }
    local borderCol = DRAG_BORDER[rarity] or DRAG_BORDER.common
    local bgCol = DRAG_BG[rarity] or DRAG_BG.common
    local iconSize = 36
    local iconPath = display.iconId and IconAtlas.GetPath(display.iconId) or nil

    local dragSize = 64
    G.dragOverlay = UI.Panel {
        position = "absolute",
        left = x - dragSize / 2,
        top = y - dragSize / 2,
        width = dragSize, height = dragSize,
        backgroundColor = bgCol,
        borderRadius = 12,
        borderWidth = 2.5,
        borderColor = borderCol,
        justifyContent = "center", alignItems = "center",
        opacity = 0.9,
        pointerEvents = "none",
        boxShadow = {
            { x = 0, y = 4, blur = 12, spread = 2, color = {0, 0, 0, 100} },
            { x = 0, y = 0, blur = 8, spread = 2, color = {borderCol[1], borderCol[2], borderCol[3], 60} },
        },
        children = {
            iconPath
                and UI.Panel { backgroundImage = iconPath, width = iconSize, height = iconSize, backgroundFit = "contain", pointerEvents = "none" }
                or  UI.Label { text = display.icon, fontSize = 28, textAlign = "center" },
        },
    }
    G.menuRoot:AddChild(G.dragOverlay)
end

function MenuSystem.EndEquipSlotDrag(slot)
    -- 清除浮动图标
    if G.dragOverlay then
        G.dragOverlay:SetVisible(false)
        G.dragOverlay = nil
    end

    -- 拖拽完成即脱下装备（拖拽阈值已防误触）
    local actualSlot = slot or G.dragEquipSlot
    if actualSlot and G.playerData.equipment[actualSlot] then
        AM.PlaySFX("ui_equip")
        PlayerData.UnequipItem(G.playerData, actualSlot)
        PlayerData.Save(G.playerData)
        G.dragEquipSlot = nil
        MenuSystem.RebuildMenuPage("equip")
        return
    end

    G.dragEquipSlot = nil
end

--- 显示抽奖规则弹窗
function MenuSystem.ShowGachaRules()
    -- 移除旧的（如有）
    if G.gachaRulesPopup then
        G.gachaRulesPopup:Remove()
        G.gachaRulesPopup = nil
    end

    -- 概率行构建辅助
    local function RarityRow(icon, label, pct, barColor, labelColor)
        return UI.Panel {
            width = "100%", flexDirection = "row",
            alignItems = "center", gap = 10,
            paddingTop = 5, paddingBottom = 5,
            borderBottomWidth = 1, borderColor = {255, 255, 255, 12},
            children = {
                -- 图标+名称
                UI.Panel {
                    width = 90, flexDirection = "row", alignItems = "center", gap = 6,
                    children = {
                        UI.Label { text = icon, fontSize = 14 },
                        UI.Label {
                            text = label, fontSize = 14, fontWeight = "bold",
                            fontColor = labelColor or {220, 220, 240, 255},
                        },
                    },
                },
                -- 进度条底
                UI.Panel {
                    flexGrow = 1, height = 8, borderRadius = 4,
                    backgroundColor = {255, 255, 255, 18},
                    children = {
                        UI.Panel {
                            width = pct .. "%", height = "100%",
                            borderRadius = 4,
                            backgroundGradient = {
                                type = "linear", direction = "to-right",
                                from = barColor[1], to = barColor[2],
                            },
                        },
                    },
                },
                -- 百分比文字
                UI.Label {
                    text = pct .. "%", fontSize = 13, fontWeight = "bold",
                    fontColor = labelColor or {200, 210, 230, 220},
                    width = 40, textAlign = "right",
                },
            },
        }
    end

    local pityLeft = Equipment.PITY_THRESHOLD - ((G.playerData.pityCounter or 0))

    local popup = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center", alignItems = "center",
        backgroundColor = {0, 0, 0, 170},
        backdropBlur = 3,
        zIndex = 950,
        onClick = function(self)
            if G.gachaRulesPopup then
                G.gachaRulesPopup:SetVisible(false)
                G.gachaRulesPopup:Remove()
                G.gachaRulesPopup = nil
            end
        end,
        children = {
            UI.Panel {
                width = "86%", maxWidth = 300,
                borderRadius = 18,
                backgroundGradient = {
                    type = "linear", direction = "to-bottom",
                    from = {30, 26, 55, 255}, to = {18, 15, 38, 255},
                },
                borderWidth = 1.5,
                borderColor = {120, 90, 200, 130},
                boxShadow = {
                    { x = 0, y = 6, blur = 24, spread = 0, color = {0, 0, 0, 140} },
                    { x = 0, y = 0, blur = 30, spread = 2, color = {100, 60, 200, 30} },
                },
                paddingTop = 20, paddingBottom = 20,
                paddingLeft = 20, paddingRight = 20,
                gap = 14,
                onClick = function(self) end,  -- 阻止穿透
                children = {
                    -- 标题
                    UI.Panel {
                        width = "100%", alignItems = "center", gap = 3,
                        children = {
                            UI.Label {
                                text = "📋 抽奖规则",
                                fontSize = 18, fontWeight = "bold",
                                fontColor = {255, 240, 180, 255},
                                textShadow = { offsetX = 0, offsetY = 1, blur = 5, color = {255, 200, 40, 50} },
                            },
                        },
                    },

                    -- 分隔线
                    UI.Panel { width = "100%", height = 1, backgroundColor = {255, 255, 255, 20} },

                    -- 概率区块
                    UI.Panel {
                        width = "100%", gap = 0,
                        children = {
                            UI.Label {
                                text = "掉落概率",
                                fontSize = 12, fontColor = {160, 165, 185, 200},
                                marginBottom = 6,
                            },
                            RarityRow("🔵", "蓝色", 75,
                                { {80, 160, 255, 255}, {50, 110, 220, 255} },
                                {130, 190, 255, 255}),
                            RarityRow("🟣", "紫色", 22,
                                { {200, 100, 255, 255}, {150, 60, 220, 255} },
                                {210, 150, 255, 255}),
                            RarityRow("🟡", "金色", 3,
                                { {255, 220, 40, 255}, {220, 150, 20, 255} },
                                {255, 220, 80, 255}),
                        },
                    },

                    -- 分隔线
                    UI.Panel { width = "100%", height = 1, backgroundColor = {255, 255, 255, 20} },

                    -- 保底说明
                    UI.Panel {
                        width = "100%",
                        backgroundColor = {255, 200, 40, 12},
                        borderRadius = 10,
                        borderWidth = 1, borderColor = {255, 200, 40, 40},
                        paddingTop = 10, paddingBottom = 10,
                        paddingLeft = 12, paddingRight = 12,
                        gap = 6,
                        children = {
                            UI.Panel {
                                flexDirection = "row", alignItems = "center", gap = 6,
                                children = {
                                    UI.Label { text = "⭐", fontSize = 14 },
                                    UI.Label {
                                        text = "保底机制",
                                        fontSize = 14, fontWeight = "bold",
                                        fontColor = {255, 220, 80, 255},
                                    },
                                },
                            },
                            UI.Label {
                                text = "每 " .. Equipment.PITY_THRESHOLD .. " 抽必得 1 件未拥有的金色装备；已集齐全部金色后随机一件。",
                                fontSize = 12,
                                fontColor = {220, 215, 200, 220},
                                flexWrap = "wrap",
                            },
                            -- 当前保底进度
                            UI.Panel {
                                width = "100%", flexDirection = "row",
                                alignItems = "center", gap = 8,
                                marginTop = 2,
                                children = {
                                    UI.Label {
                                        text = "当前进度",
                                        fontSize = 12, fontColor = {180, 175, 165, 200},
                                    },
                                    -- 进度条底
                                    UI.Panel {
                                        flexGrow = 1, height = 7, borderRadius = 4,
                                        backgroundColor = {255, 255, 255, 18},
                                        children = {
                                            UI.Panel {
                                                width = math.floor((G.playerData.pityCounter or 0) / Equipment.PITY_THRESHOLD * 100) .. "%",
                                                height = "100%", borderRadius = 4,
                                                backgroundGradient = {
                                                    type = "linear", direction = "to-right",
                                                    from = {255, 210, 40, 255}, to = {255, 160, 20, 255},
                                                },
                                            },
                                        },
                                    },
                                    UI.Label {
                                        text = (G.playerData.pityCounter or 0) .. "/" .. Equipment.PITY_THRESHOLD,
                                        fontSize = 12, fontWeight = "bold",
                                        fontColor = {255, 210, 80, 230},
                                    },
                                },
                            },
                        },
                    },

                    -- 套装说明
                    UI.Panel {
                        width = "100%",
                        backgroundColor = {140, 100, 255, 12},
                        borderRadius = 10,
                        borderWidth = 1, borderColor = {140, 100, 255, 40},
                        paddingTop = 10, paddingBottom = 10,
                        paddingLeft = 12, paddingRight = 12,
                        gap = 8,
                        children = {
                            -- 标题行
                            UI.Panel {
                                flexDirection = "row", alignItems = "center", gap = 6,
                                children = {
                                    UI.Label { text = "🎽", fontSize = 14 },
                                    UI.Label {
                                        text = "套装属性",
                                        fontSize = 14, fontWeight = "bold",
                                        fontColor = {200, 160, 255, 255},
                                    },
                                },
                            },
                            -- 说明文字
                            UI.Label {
                                text = "蓝色、紫色装备仅提升数值。只有金色装备可激活套装效果（同套装4件/6件触发）。",
                                fontSize = 12,
                                fontColor = {220, 215, 200, 220},
                                flexWrap = "wrap",
                            },
                            -- 分隔线
                            UI.Panel { width = "100%", height = 1, backgroundColor = {255, 255, 255, 15} },
                            -- 套装列表
                            UI.Label {
                                text = "当前共 3 套金色套装：",
                                fontSize = 12, fontWeight = "bold",
                                fontColor = {255, 210, 80, 230},
                            },
                            UI.Panel {
                                width = "100%", gap = 4,
                                children = {
                                    -- 飞跃先锋
                                    UI.Panel {
                                        width = "100%", flexDirection = "row",
                                        alignItems = "flex-start", gap = 6,
                                        children = {
                                            UI.Label { text = "◆", fontSize = 11, fontColor = {255, 200, 40, 255}, marginTop = 1 },
                                            UI.Panel { flexGrow = 1, gap = 2, children = {
                                                UI.Label { text = "🦅 飞跃先锋", fontSize = 12, fontWeight = "bold", fontColor = {255, 220, 100, 255} },
                                                UI.Label { text = "4件：可跳过2连续敌人\n6件：可跳过3连续敌人", fontSize = 11, fontColor = {200, 195, 185, 200}, flexWrap = "wrap" },
                                            }},
                                        },
                                    },
                                    -- 连击心得
                                    UI.Panel {
                                        width = "100%", flexDirection = "row",
                                        alignItems = "flex-start", gap = 6,
                                        children = {
                                            UI.Label { text = "◆", fontSize = 11, fontColor = {255, 200, 40, 255}, marginTop = 1 },
                                            UI.Panel { flexGrow = 1, gap = 2, children = {
                                                UI.Label { text = "🔥 连击心得", fontSize = 12, fontWeight = "bold", fontColor = {255, 220, 100, 255} },
                                                UI.Label { text = "4件：50%概率Combo+1\n6件：75%概率Combo+1", fontSize = 11, fontColor = {200, 195, 185, 200}, flexWrap = "wrap" },
                                            }},
                                        },
                                    },
                                    -- 嗜血猎魂
                                    UI.Panel {
                                        width = "100%", flexDirection = "row",
                                        alignItems = "flex-start", gap = 6,
                                        children = {
                                            UI.Label { text = "◆", fontSize = 11, fontColor = {255, 200, 40, 255}, marginTop = 1 },
                                            UI.Panel { flexGrow = 1, gap = 2, children = {
                                                UI.Label { text = "🩸 嗜血猎魂", fontSize = 12, fontWeight = "bold", fontColor = {255, 220, 100, 255} },
                                                UI.Label { text = "4件：击杀敌人回血\n6件：HP<50%时击杀触发血怒，下一跳ATK×1.5（最多叠3层）", fontSize = 11, fontColor = {200, 195, 185, 200}, flexWrap = "wrap" },
                                            }},
                                        },
                                    },
                                },
                            },
                        },
                    },

                    -- 费用说明
                    UI.Panel {
                        width = "100%", flexDirection = "row", gap = 8,
                        children = {
                            UI.Panel {
                                flexGrow = 1, alignItems = "center", gap = 3,
                                backgroundColor = {255, 255, 255, 8},
                                borderRadius = 10, borderWidth = 1,
                                borderColor = {255, 255, 255, 18},
                                paddingTop = 8, paddingBottom = 8,
                                children = {
                                    UI.Label { text = "开一次", fontSize = 12, fontColor = {200, 200, 215, 210} },
                                    UI.Label {
                                        text = Equipment.PULL_COST_SINGLE .. " G",
                                        fontSize = 16, fontWeight = "bold",
                                        fontColor = {255, 220, 60, 255},
                                    },
                                },
                            },
                            UI.Panel {
                                flexGrow = 1, alignItems = "center", gap = 3,
                                backgroundColor = {255, 255, 255, 8},
                                borderRadius = 10, borderWidth = 1,
                                borderColor = {255, 255, 255, 18},
                                paddingTop = 8, paddingBottom = 8,
                                children = {
                                    UI.Panel {
                                        flexDirection = "row", alignItems = "center", gap = 4,
                                        children = {
                                            UI.Label { text = "开三次", fontSize = 12, fontColor = {200, 200, 215, 210} },
                                            UI.Label {
                                                text = "省40G",
                                                fontSize = 10, fontColor = {120, 255, 120, 200},
                                                backgroundColor = {0, 160, 80, 60},
                                                borderRadius = 6,
                                                paddingLeft = 4, paddingRight = 4,
                                                paddingTop = 1, paddingBottom = 1,
                                            },
                                        },
                                    },
                                    UI.Label {
                                        text = Equipment.PULL_COST_TRIPLE .. " G",
                                        fontSize = 16, fontWeight = "bold",
                                        fontColor = {200, 150, 255, 255},
                                    },
                                },
                            },
                        },
                    },

                    -- 关闭按钮
                    UI.Panel {
                        width = "100%", alignItems = "center", marginTop = 2,
                        children = {
                            UI.Panel {
                                paddingTop = 9, paddingBottom = 9,
                                paddingLeft = 36, paddingRight = 36,
                                borderRadius = 20,
                                backgroundGradient = {
                                    type = "linear", direction = "to-bottom",
                                    from = {80, 65, 130, 255}, to = {55, 42, 100, 255},
                                },
                                borderWidth = 1, borderColor = {150, 120, 220, 150},
                                onClick = function(self)
                                    if G.gachaRulesPopup then
                                        G.gachaRulesPopup:SetVisible(false)
                                        G.gachaRulesPopup:Remove()
                                        G.gachaRulesPopup = nil
                                    end
                                end,
                                children = {
                                    UI.Label {
                                        text = "知道了",
                                        fontSize = 15, fontWeight = "bold",
                                        fontColor = {230, 220, 255, 255},
                                    },
                                },
                            },
                        },
                    },
                },
            },
        },
    }

    G.gachaRulesPopup = popup
    G.menuRoot:AddChild(popup)
end

--- 显示抽奖结果弹窗 (v4.1 动画版: 宝箱震动→打开→光柱→装备展示)
function MenuSystem.ShowGachaResults(results)
    if G.gachaPopup then
        G.gachaPopup:SetVisible(false)
        G.gachaPopup:Remove()
        G.gachaPopup = nil
    end
    G._gachaAnim = nil

    -- 检查是否出金
    local hasGold = false
    for _, item in ipairs(results) do
        if item.rarity == "gold" then hasGold = true; break end
    end

    -- 动画状态
    local anim = {
        phase = "shake",  -- shake → burst → reveal → done
        timer = 0,
        shakeCount = 0,
        revealIndex = 0,
        cardWidgets = {},
        hasGold = hasGold,
        sparkleTimer = 0,
    }

    -- ======== 宝箱 + 光柱容器 ========
    local chestIcon = UI.Label {
        text = "🎁",
        fontSize = 72,
        textAlign = "center",
    }

    local lightBurst = UI.Panel {
        position = "absolute",
        top = -40, left = -60, right = -60, bottom = -40,
        borderRadius = 200,
        backgroundGradient = {
            type = "radial",
            from = {255, 230, 100, 0}, to = {255, 200, 40, 0},
        },
        opacity = 0,
    }

    local chestArea = UI.Panel {
        width = 120, height = 120,
        justifyContent = "center", alignItems = "center",
        overflow = "visible",
        children = { lightBurst, chestIcon },
    }

    -- ======== 装备卡片 (初始隐藏) ========
    local cardContainer = UI.Panel {
        width = "100%",
        gap = 10,
        alignItems = "center",
        opacity = 0,
    }

    -- 预创建卡片内容
    local resultChildren = MenuPages.BuildPullResults(results)
    for _, child in ipairs(resultChildren) do
        cardContainer:AddChild(child)
    end

    -- ======== 确认按钮 (初始隐藏) ========
    local confirmBtn = UI.Button {
        text = "好的",
        variant = "primary",
        width = 170, height = 46, fontSize = 23,
        fontWeight = "bold",
        borderRadius = 23,
        backgroundGradient = {
            type = "linear", direction = "to-bottom",
            from = {255, 220, 65, 255}, to = {235, 185, 30, 255},
        },
        pressedBackgroundColor = {210, 165, 20, 255},
        fontColor = {15, 12, 30, 255},
        borderWidth = 2,
        borderColor = {255, 225, 90, 180},
        boxShadow = {
            { x = 0, y = 3, blur = 8, spread = 0, color = {0, 0, 0, 50} },
            { x = 0, y = 1, blur = 2, spread = 0, color = {255, 255, 255, 30}, inset = true },
        },
        opacity = 0,
        onClick = function(self)
            AM.PlaySFX("ui_popup_close")
            if G.gachaPopup then
                G.gachaPopup:SetVisible(false)
                G.gachaPopup:Remove()
                G.gachaPopup = nil
            end
            G._gachaAnim = nil
        end,
    }

    -- ======== 金色闪光粒子（出金时显示） ========
    local goldSparkles = {}
    local goldSparkleWidgets = {}
    if hasGold then
        for i = 1, 12 do
            local sp = {
                x = math.random(5, 95) / 100,
                y = math.random(5, 95) / 100,
                size = math.random(4, 10),
                speed = 1.5 + math.random() * 2.0,
                phase = math.random() * math.pi * 2,
                drift = (math.random() - 0.5) * 30,
            }
            goldSparkles[i] = sp
            goldSparkleWidgets[i] = UI.Label {
                position = "absolute",
                text = "✦",
                fontSize = sp.size,
                fontColor = {255, 215, 0, 0},
                left = math.floor(sp.x * 300),
                top = math.floor(sp.y * 400),
            }
        end
    end

    local goldOverlay = hasGold and UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        overflow = "hidden",
        borderRadius = 24,
        opacity = 0,
        children = goldSparkleWidgets,
    } or nil

    -- ======== 金色光晕边框（出金时显示） ========
    local goldGlow = hasGold and UI.Panel {
        position = "absolute",
        top = -3, left = -3, right = -3, bottom = -3,
        borderRadius = 27,
        borderWidth = 3,
        borderColor = {255, 215, 0, 0},
        boxShadow = {
            { x = 0, y = 0, blur = 20, spread = 4, color = {255, 215, 0, 0} },
            { x = 0, y = 0, blur = 40, spread = 8, color = {255, 180, 0, 0} },
        },
    } or nil

    -- ======== 弹窗面板 ========
    local popupPanel = UI.Panel {
        width = "85%", maxWidth = 340,
        padding = 24, gap = 14,
        backgroundGradient = {
            type = "linear", direction = "to-bottom",
            from = hasGold and {50, 42, 20, 250} or {32, 36, 65, 250},
            to = hasGold and {30, 25, 10, 250} or {20, 22, 45, 250},
        },
        borderRadius = 24, borderWidth = 2.5,
        borderColor = hasGold and {255, 200, 60, 200} or {170, 100, 235, 170},
        boxShadow = {
            { x = 0, y = 6, blur = 24, spread = 0, color = {0, 0, 0, 80} },
            { x = 0, y = 1, blur = 4, spread = 0, color = hasGold and {255, 200, 40, 30} or {170, 100, 235, 20}, inset = true },
        },
        alignItems = "center",
        overflow = "visible",
        children = (function()
            local c = {}
            if goldGlow then c[#c + 1] = goldGlow end
            if goldOverlay then c[#c + 1] = goldOverlay end
            c[#c + 1] = chestArea
            c[#c + 1] = cardContainer
            c[#c + 1] = confirmBtn
            return c
        end)(),
    }

    G.gachaPopup = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center", alignItems = "center",
        backgroundColor = {0, 0, 0, 170},
        backdropBlur = 4,
        children = { popupPanel },
    }
    G.menuRoot:AddChild(G.gachaPopup)

    -- ======== 动画更新函数 (由 main.lua Update 调用) ========
    G._gachaAnim = function(dt)
        anim.timer = anim.timer + dt

        if anim.phase == "shake" then
            -- 宝箱震动 0.8秒, 4次震动
            local shakeT = anim.timer
            local shakePeriod = 0.2
            local shakeAmplitude = 6
            if shakeT < 0.8 then
                local offset = math.sin(shakeT / shakePeriod * math.pi * 2) * shakeAmplitude
                offset = offset * (1 + shakeT * 2) -- 越来越剧烈
                chestIcon:SetStyle({ left = math.floor(offset) })
            else
                chestIcon:SetStyle({ left = 0 })
                anim.phase = "burst"
                anim.timer = 0
            end

        elseif anim.phase == "burst" then
            -- 光柱爆发 0.5秒
            local t = anim.timer
            -- 出金时使用金色光柱，否则用原来的颜色
            local burstR, burstG, burstB = 255, 240, 150
            if anim.hasGold then burstR, burstG, burstB = 255, 215, 0 end
            if t < 0.15 then
                -- 宝箱变大
                local scale = 1 + t / 0.15 * 0.3
                chestIcon:SetStyle({ fontSize = math.floor(72 * scale) })
            elseif t < 0.4 then
                -- 光柱从中心扩散
                local progress = (t - 0.15) / 0.25
                local alpha = math.floor((anim.hasGold and 240 or 180) * (1 - progress * 0.5))
                lightBurst:SetStyle({
                    opacity = 1,
                    backgroundGradient = {
                        type = "radial",
                        from = {burstR, burstG, burstB, alpha}, to = {burstR, burstG, burstB, 0},
                    },
                })
                chestIcon:SetStyle({ text = "✨", fontSize = math.floor(72 * 1.3) })
                -- 出金: 激活金色边框光晕
                if anim.hasGold and goldGlow then
                    local glowA = math.floor(progress * 200)
                    goldGlow:SetStyle({
                        borderColor = {255, 215, 0, glowA},
                        boxShadow = {
                            { x = 0, y = 0, blur = 20, spread = 4, color = {255, 215, 0, math.floor(glowA * 0.5)} },
                            { x = 0, y = 0, blur = 40, spread = 8, color = {255, 180, 0, math.floor(glowA * 0.3)} },
                        },
                    })
                end
            else
                -- 光柱消散
                lightBurst:SetStyle({ opacity = 0 })
                chestIcon:SetStyle({ text = "✨", fontSize = 48 })
                -- 出金: 开始显示粒子层
                if anim.hasGold and goldOverlay then
                    goldOverlay:SetStyle({ opacity = 1 })
                end
                anim.phase = "reveal"
                anim.timer = 0
            end

        elseif anim.phase == "reveal" then
            -- 卡片逐个显示 + 淡入
            local revealDelay = 0.15
            local t = anim.timer
            -- 淡入卡片容器
            if t < 0.3 then
                cardContainer:SetStyle({ opacity = t / 0.3 })
            else
                cardContainer:SetStyle({ opacity = 1 })
            end
            -- 0.6秒后显示按钮
            if t >= 0.6 then
                if t < 0.9 then
                    confirmBtn:SetStyle({ opacity = (t - 0.6) / 0.3 })
                else
                    confirmBtn:SetStyle({ opacity = 1 })
                    anim.phase = "done"
                end
            end

        elseif anim.phase == "done" then
            -- 动画完成，只更新金色粒子
        end

        -- 出金: 持续更新金色闪光粒子（reveal 和 done 阶段）
        if anim.hasGold and (anim.phase == "reveal" or anim.phase == "done") then
            anim.sparkleTimer = anim.sparkleTimer + dt
            for i, sp in ipairs(goldSparkles) do
                sp.phase = sp.phase + dt * sp.speed * 3.0
                local a = math.abs(math.sin(sp.phase))
                -- 粒子缓慢上飘
                sp.y = sp.y - dt * 0.06 * sp.speed
                if sp.y < -0.05 then
                    sp.y = 1.05
                    sp.x = math.random(5, 95) / 100
                end
                local alpha = math.floor(a * 220)
                local sz = math.floor(sp.size + a * 8)
                local w = goldSparkleWidgets[i]
                if w then
                    w:SetStyle({
                        fontSize = sz,
                        fontColor = {255, math.floor(200 + a * 55), math.floor(a * 80), alpha},
                        left = math.floor(sp.x * 300 + math.sin(sp.phase * 0.7) * sp.drift),
                        top = math.floor(sp.y * 400),
                    })
                end
            end

            -- 金色边框光晕呼吸效果
            if goldGlow then
                local breathe = 0.6 + 0.4 * math.sin(anim.sparkleTimer * 2.5)
                local glowA = math.floor(breathe * 200)
                goldGlow:SetStyle({
                    borderColor = {255, 215, 0, glowA},
                    boxShadow = {
                        { x = 0, y = 0, blur = 20, spread = 4, color = {255, 215, 0, math.floor(breathe * 100)} },
                        { x = 0, y = 0, blur = 40, spread = 8, color = {255, 180, 0, math.floor(breathe * 60)} },
                    },
                })
            end
        end
    end
end

function MenuSystem.CreateMenuUI()
    local tabChildren = {}
    G.menuTabButtons = {}
    for i, tab in ipairs(TAB_INFO) do
        local isActive = (tab.id == G.menuTab)
        local btn = UI.Button {
            flexGrow = 1,
            height = 110,
            flexDirection = "column",
            justifyContent = "center", alignItems = "center",
            backgroundColor = {0, 0, 0, 0},
            borderRadius = 0,
            pressedBackgroundColor = {35, 30, 60, 100},
            gap = 0,
            overflow = "visible",
            paddingBottom = 10,
            borderRightWidth = (i < #TAB_INFO) and 1 or 0,
            borderColor = {60, 50, 100, 120},
            onClick = function(self)
                MenuSystem.SwitchTab(tab.id)
            end,
            children = {
                -- 图标 emoji（选中时放大上移突出）
                UI.Label {
                    text = tab.emoji,
                    fontSize = isActive and 38 or 26,
                    top = isActive and -8 or 0,
                    textAlign = "center",
                },
                -- 文字标签（仅选中时显示）
                UI.Label {
                    text = tab.label,
                    fontSize = 18,
                    fontColor = {255, 220, 80, 255},
                    fontWeight = "bold",
                    textAlign = "center",
                    visible = isActive,
                },
            },
        }
        btn._tabId = tab.id
        G.menuTabButtons[#G.menuTabButtons + 1] = btn
        tabChildren[#tabChildren + 1] = btn
    end

    local runs = G.playerData and G.playerData.totalRuns or 0
    local gold = G.playerData and G.playerData.gold or 0

    G.menuRoot = UI.Panel {
        width = "100%", height = "100%",
        flexDirection = "column",
        backgroundGradient = {
            type = "linear", direction = "to-bottom",
            from = {8, 8, 24, 255}, to = {10, 10, 26, 255},
        },
        -- 全局兜底：在任意空白处松手时清理残留的拖拽 overlay（不触发实际操作）
        onPointerUp = function(event, widget)
            if G.dragItemIdx then
                -- 背包拖拽在空白处松手：只清理 overlay，不穿戴
                if G.dragOverlay then
                    G.dragOverlay:SetVisible(false)
                    G.dragOverlay = nil
                end
                G.dragItemIdx = nil
                G.dragTargetSlot = nil
            end
            if G.dragEquipSlot then
                -- 装备槽拖拽在空白处松手：只清理 overlay，不脱下
                if G.dragOverlay then
                    G.dragOverlay:SetVisible(false)
                    G.dragOverlay = nil
                end
                G.dragEquipSlot = nil
            end
        end,
        children = {
            -- 顶部安全区（避开刘海+左右系统UI，透明）
            UI.SafeAreaView {
                width = "100%",
                edges = { "top", "left", "right" },
                children = {
                    -- 顶栏内容行
                    (function()
                        local logW = graphics:GetWidth() / graphics:GetDPR()
                        local isMobile = logW < 500
                        -- 章节进度计算
                        local ch = math.ceil(G.highestLevel / Battle.LEVELS_PER_CHAPTER)
                        local chFirst = (ch - 1) * Battle.LEVELS_PER_CHAPTER + 1
                        local stagesCleared = math.min(G.highestLevel - chFirst, Battle.LEVELS_PER_CHAPTER)
                        if G.highestLevel > ch * Battle.LEVELS_PER_CHAPTER then stagesCleared = Battle.LEVELS_PER_CHAPTER end
                        local barW = isMobile and 72 or 90
                        local fillW = math.floor(barW * stagesCleared / Battle.LEVELS_PER_CHAPTER)
                        local badgeSize = isMobile and 44 or 52

                        return UI.Panel {
                            width = "100%",
                            flexDirection = "row",
                            justifyContent = "space-between",
                            alignItems = "center",
                            paddingTop = 8, paddingBottom = 8,
                            paddingLeft = 10, paddingRight = 12,
                            children = {
                                -- ===== 左侧：等级徽章 + 进度条 =====
                                UI.Panel {
                                    flexDirection = "row", alignItems = "center",
                                    overflow = "visible",
                                    children = {
                                        -- 等级药丸
                                        UI.Panel {
                                            flexDirection = "row", alignItems = "center",
                                            paddingLeft = 10, paddingRight = 10,
                                            paddingTop = 4, paddingBottom = 4,
                                            borderRadius = 14,
                                            backgroundGradient = {
                                                type = "linear", direction = "to-bottom",
                                                from = {45, 120, 210, 255}, to = {30, 80, 160, 255},
                                            },
                                            borderWidth = 1.5,
                                            borderColor = {80, 160, 240, 180},
                                            boxShadow = {
                                                { x = 0, y = 2, blur = 5, spread = 0, color = {0, 0, 0, 50} },
                                            },
                                            children = {
                                                UI.Label {
                                                    text = "Ch.",
                                                    fontSize = isMobile and 14 or 16,
                                                    fontWeight = "bold",
                                                    fontColor = {180, 220, 255, 220},
                                                },
                                                UI.Label {
                                                    text = tostring(math.min(4, math.ceil(G.highestLevel / Battle.LEVELS_PER_CHAPTER))),
                                                    fontSize = isMobile and 18 or 22,
                                                    fontWeight = "bold",
                                                    fontColor = {255, 255, 255, 255},
                                                    marginLeft = 2,
                                                    textShadow = {
                                                        offsetX = 0, offsetY = 1, blur = 3,
                                                        color = {10, 40, 80, 180},
                                                    },
                                                },
                                            },
                                        },

                                    },
                                },
                                -- ===== 中间：游戏名 =====
                                UI.Panel {
                                    flexGrow = 1,
                                    justifyContent = "center", alignItems = "center",
                                    children = {
                                        UI.Label {
                                            text = "Combo Checkers",
                                            fontSize = isMobile and 16 or 20,
                                            fontWeight = "bold",
                                            fontColor = {220, 230, 245, 200},
                                            textShadow = {
                                                offsetX = 0, offsetY = 1, blur = 4,
                                                color = {0, 0, 0, 120},
                                            },
                                        },
                                    },
                                },
                                -- ===== 右侧：金币显示（点击弹出兑换码）=====
                                UI.Panel {
                                    flexDirection = "row", alignItems = "center", gap = 4,
                                    backgroundGradient = {
                                        type = "linear", direction = "to-right",
                                        from = {55, 42, 12, 240}, to = {35, 28, 8, 240},
                                    },
                                    borderRadius = 18,
                                    borderWidth = 1.5,
                                    borderColor = {160, 125, 40, 160},
                                    paddingLeft = 4, paddingRight = 14,
                                    paddingTop = 5, paddingBottom = 5,
                                    overflow = "visible",
                                    boxShadow = {
                                        { x = 0, y = 2, blur = 6, spread = 0, color = {0, 0, 0, 50} },
                                        { x = 0, y = 1, blur = 2, spread = 0, color = {220, 180, 60, 20}, inset = true },
                                    },
                                    pressedBackgroundColor = {70, 55, 18, 255},
                                    onClick = function(self)
                                        local RedeemPopup = require "RedeemPopup"
                                        RedeemPopup.Show()
                                    end,
                                    children = {
                                        -- 金币图标（突出显示）
                                        UI.Panel {
                                            width = isMobile and 32 or 38,
                                            height = isMobile and 32 or 38,
                                            justifyContent = "center", alignItems = "center",
                                            children = {
                                                UI.Panel {
                                                    backgroundImage = IconAtlas.GetPath("hud_gold"),
                                                    width = isMobile and 28 or 34,
                                                    height = isMobile and 28 or 34,
                                                    backgroundFit = "contain",
                                                },
                                            },
                                        },
                                        UI.Label {
                                            id = "menuGoldLabel",
                                            text = tostring(gold),
                                            fontSize = isMobile and 22 or 26,
                                            fontColor = {255, 230, 75, 255},
                                            fontWeight = "bold",
                                            textShadow = { offsetX = 0, offsetY = 1, blur = 3, color = {0, 0, 0, 100} },
                                        },
                                    },
                                },
                            },
                        }
                    end)(),
                },
            },
            -- （分隔线已移除，顶栏与背景自然融合）
            -- 设置按钮（独立于顶栏，无背景，浮在页面渐变上）
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                alignItems = "center",
                paddingLeft = 12, paddingTop = 4, paddingBottom = 2,
                children = {
                    UI.Button {
                        text = "⚙",
                        fontSize = 22,
                        width = 32, height = 28,
                        borderRadius = 8,
                        backgroundColor = {0, 0, 0, 0},
                        fontColor = {180, 175, 215, 180},
                        pressedBackgroundColor = {255, 255, 255, 20},
                        onClick = function(self)
                            SettingsPopup.Show()
                        end,
                    },
                },
            },
            -- 动态内容插槽
            (function()
                G.menuArrowLeft = UI.Button {
                    position = "absolute",
                    left = 32, top = "50%",
                    width = 42, height = 42,
                    backgroundGradient = {
                        type = "linear", direction = "to-bottom",
                        from = {50, 70, 140, 220}, to = {25, 35, 80, 240},
                    },
                    pressedBackgroundColor = {80, 110, 190, 240},
                    borderRadius = 21,
                    borderWidth = 1,
                    borderColor = {100, 150, 255, 100},
                    text = "<",
                    fontSize = 24,
                    fontWeight = "bold",
                    fontColor = {220, 235, 255, 255},
                    boxShadow = {
                        { x = 0, y = 2, blur = 8, spread = 0, color = {0, 0, 0, 90} },
                        { x = 0, y = 0, blur = 10, spread = 1, color = {70, 120, 220, 50} },
                    },
                    zIndex = 10,
                    onClick = function(self)
                        AM.PlaySFX("ui_click")
                        if G.selectedChapter > 0 then
                            G.selectedChapter = G.selectedChapter - 1
                            MenuSystem.RebuildMenuPage(G.menuTab)
                        end
                    end,
                }
                G.menuArrowRight = UI.Button {
                    position = "absolute",
                    right = 32, top = "50%",
                    width = 42, height = 42,
                    backgroundGradient = {
                        type = "linear", direction = "to-bottom",
                        from = {50, 70, 140, 220}, to = {25, 35, 80, 240},
                    },
                    pressedBackgroundColor = {80, 110, 190, 240},
                    borderRadius = 21,
                    borderWidth = 1,
                    borderColor = {100, 150, 255, 100},
                    text = ">",
                    fontSize = 24,
                    fontWeight = "bold",
                    fontColor = {220, 235, 255, 255},
                    boxShadow = {
                        { x = 0, y = 2, blur = 8, spread = 0, color = {0, 0, 0, 90} },
                        { x = 0, y = 0, blur = 10, spread = 1, color = {70, 120, 220, 50} },
                    },
                    zIndex = 10,
                    onClick = function(self)
                        AM.PlaySFX("ui_click")
                        if G.selectedChapter < 4 then
                            G.selectedChapter = G.selectedChapter + 1
                            MenuSystem.RebuildMenuPage(G.menuTab)
                        end
                    end,
                }
                G.menuHeroArea = UI.Panel {
                    width = "100%", flexGrow = 1, flexShrink = 1,
                    onSwipeLeft = function(event, widget)
                        if G.selectedChapter < 4 then
                            G.selectedChapter = G.selectedChapter + 1
                            MenuSystem.RebuildMenuPage(G.menuTab)
                        end
                    end,
                    onSwipeRight = function(event, widget)
                        if G.selectedChapter > 0 then
                            G.selectedChapter = G.selectedChapter - 1
                            MenuSystem.RebuildMenuPage(G.menuTab)
                        end
                    end,
                    children = {
                        MenuHeroWidget {
                            width = "100%", height = "100%",
                        },
                        G.menuArrowLeft,
                        G.menuArrowRight,
                    },
                }
                G.menuScrollView = UI.ScrollView {
                    width = "100%", flexGrow = 1, flexShrink = 1,
                    backgroundColor = {30, 35, 48, 255},
                    children = {
                        UI.Panel {
                            id = "menuPageContainer",
                            width = "100%",
                            paddingTop = 16, paddingBottom = 16,
                            paddingLeft = 16, paddingRight = 16,
                            alignItems = "center", gap = 12,
                        },
                    },
                }
                G.menuAdvBottomBar = UI.Panel {
                    width = "100%", flexShrink = 0,
                    alignItems = "center",
                    paddingTop = 24, paddingBottom = 80,
                }
                G.menuContentSlot = UI.Panel {
                    width = "100%", flexGrow = 1, flexShrink = 1,
                    flexDirection = "column",
                }
                return G.menuContentSlot
            end)(),
            -- Tab 栏顶部分隔线
            UI.Panel {
                width = "100%", height = 1, flexShrink = 0,
                backgroundGradient = {
                    type = "linear", direction = "to-right",
                    from = {50, 45, 80, 30}, to = {80, 60, 140, 80},
                },
            },
            -- 底部 Tab 栏
            UI.Panel {
                width = "100%", flexShrink = 0,
                backgroundColor = {18, 14, 36, 255},
                children = {
                    -- 分割线
                    UI.Panel {
                        width = "100%", height = 1,
                        backgroundGradient = {
                            type = "linear", direction = "to-right",
                            from = {40, 35, 70, 0}, to = {80, 65, 140, 180},
                            mid = {100, 80, 180, 200}, midPoint = 0.5,
                        },
                    },
                    -- Tab 按钮行
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        overflow = "visible",
                        backgroundGradient = {
                            type = "linear", direction = "to-bottom",
                            from = {35, 28, 65, 255}, to = {18, 14, 36, 255},
                        },
                        children = tabChildren,
                    },
                },
            },

        },
    }
    UI.SetRoot(G.menuRoot)

    G.menuPageContainer = G.menuScrollView:FindById("menuPageContainer")
    G.menuGoldLabel = G.menuRoot:FindById("menuGoldLabel")
    G.gachaPopup = nil

    -- 强制刷新 tab 状态（确保只有选中 tab 显示文字）
    MenuSystem.SwitchTab(G.menuTab)
end

--- 每帧调用（由 main.lua HandleUpdate 驱动），处理公会排行榜自动刷新
--- @param dt number 帧时间（秒）
function MenuSystem.UpdateGuild(dt)
    if not _guildRefresh.fetchFn then return end
    _guildRefresh.timer = _guildRefresh.timer + dt
    if _guildRefresh.timer >= _guildRefresh.INTERVAL then
        _guildRefresh.timer = 0
        _guildRefresh.fetchFn()
    end
end

return MenuSystem
