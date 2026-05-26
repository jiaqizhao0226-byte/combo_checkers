-- ============================================================================
-- GameUI - 游戏内 UI 构建（HUD、底栏、结果面板、技能面板）
-- ============================================================================

local UI = require("urhox-libs/UI")
local Battle = require "Battle"
local HexGrid = require "HexGrid"
local Skills = require "Skills"
local G = require "GameState"
local BoardWidget = require "BoardWidget"
local IconAtlas = require "IconAtlas"
local AM = require "AudioManager"
local SettingsPopup = require "SettingsPopup"


local GameUI = {}

function GameUI.CreateHUD()
    local logW = graphics:GetWidth() / graphics:GetDPR()
    local isMobile = logW < 500
    return UI.SafeAreaView {
        width = "100%",
        children = {
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
                paddingLeft = 8, paddingRight = 8,
                paddingTop = 8, paddingBottom = 6,
                children = {
                    -- ===== 左侧: HP 徽章 + 血条 =====
                    UI.Panel {
                        flexDirection = "row", alignItems = "center",
                        flexShrink = 1,
                        overflow = "visible",
                        children = {
                            -- HP 圆形图标
                            UI.Panel {
                                width = isMobile and 30 or 34,
                                height = isMobile and 30 or 34,
                                borderRadius = isMobile and 15 or 17,
                                justifyContent = "center", alignItems = "center",
                                backgroundGradient = {
                                    type = "linear", direction = "to-bottom",
                                    from = {180, 50, 60, 255}, to = {120, 25, 35, 255},
                                },
                                borderWidth = 2.5,
                                borderColor = {90, 15, 25, 255},
                                boxShadow = {
                                    { x = 0, y = 0, blur = 8, spread = 1, color = {200, 50, 50, 70} },
                                    { x = 0, y = 1, blur = 3, spread = 0, color = {0, 0, 0, 50} },
                                    { x = 0, y = 1, blur = 1, spread = 0, color = {255, 120, 120, 30}, inset = true },
                                },
                                children = {
                                    UI.Panel {
                                        backgroundImage = IconAtlas.GetPath("hud_hp"),
                                        width = isMobile and 18 or 20,
                                        height = isMobile and 18 or 20,
                                        backgroundFit = "contain",
                                    },
                                },
                            },
                            -- HP 数值槽
                            UI.Panel {
                                flexDirection = "row", alignItems = "center", gap = 3,
                                marginLeft = -4,
                                backgroundColor = {55, 16, 22, 230},
                                borderRadius = 12,
                                borderWidth = 1.5,
                                borderColor = {130, 40, 40, 140},
                                paddingLeft = 10, paddingRight = 8,
                                paddingTop = 4, paddingBottom = 4,
                                boxShadow = {
                                    { x = 0, y = 1, blur = 3, spread = 0, color = {0, 0, 0, 40}, inset = true },
                                },
                                children = {
                                    UI.Label {
                                        id = "hpLabel", text = "100/100",
                                        fontSize = isMobile and 16 or 18,
                                        fontColor = {255, 210, 210, 255},
                                        fontWeight = "bold", numberOfLines = 1,
                                        textShadow = { offsetX = 0, offsetY = 1, blur = 2, color = {0, 0, 0, 100} },
                                    },
                                    UI.Panel {
                                        id = "shieldIcon",
                                        backgroundImage = IconAtlas.GetPath("hud_shield"),
                                        width = 14, height = 14, backgroundFit = "contain",
                                        visible = false,
                                    },
                                },
                            },
                        },
                    },
                    -- ===== 中间: 关卡+回合 药丸 =====
                    UI.Panel {
                        flexDirection = "row", alignItems = "center", gap = 4,
                        flexShrink = 1,
                        backgroundGradient = {
                            type = "linear", direction = "to-bottom",
                            from = {48, 40, 78, 230}, to = {30, 25, 55, 230},
                        },
                        borderRadius = 14,
                        borderWidth = 1.5,
                        borderColor = {100, 80, 160, 120},
                        paddingLeft = 10, paddingRight = 10,
                        paddingTop = 5, paddingBottom = 5,
                        boxShadow = {
                            { x = 0, y = 2, blur = 5, spread = 0, color = {0, 0, 0, 50} },
                            { x = 0, y = 1, blur = 2, spread = 0, color = {120, 90, 200, 20}, inset = true },
                        },
                        children = {
                            UI.Label {
                                id = "levelLabel", text = "Lv.1",
                                fontSize = isMobile and 16 or 18,
                                fontColor = {255, 220, 60, 255},
                                fontWeight = "bold", numberOfLines = 1,
                                textShadow = { offsetX = 0, offsetY = 1, blur = 2, color = {0, 0, 0, 100} },
                            },
                            UI.Label {
                                text = "·", fontSize = 15,
                                fontColor = {130, 120, 170, 160},
                            },
                            UI.Label {
                                id = "turnLabel", text = "回合 1",
                                fontSize = isMobile and 16 or 18,
                                fontColor = {195, 205, 230, 255},
                                numberOfLines = 1,
                            },
                        },
                    },
                    -- ===== 右侧: 金币显示 =====
                    UI.Panel {
                        flexDirection = "row", alignItems = "center", gap = 3,
                        flexShrink = 1,
                        overflow = "visible",
                        children = {
                            -- 金币圆形图标
                            UI.Panel {
                                width = isMobile and 28 or 32,
                                height = isMobile and 28 or 32,
                                borderRadius = isMobile and 14 or 16,
                                justifyContent = "center", alignItems = "center",
                                backgroundGradient = {
                                    type = "linear", direction = "to-bottom",
                                    from = {200, 160, 40, 255}, to = {140, 100, 20, 255},
                                },
                                borderWidth = 2,
                                borderColor = {100, 70, 10, 255},
                                boxShadow = {
                                    { x = 0, y = 0, blur = 6, spread = 1, color = {220, 180, 50, 60} },
                                    { x = 0, y = 1, blur = 2, spread = 0, color = {0, 0, 0, 40} },
                                },
                                children = {
                                    UI.Panel {
                                        backgroundImage = IconAtlas.GetPath("hud_gold"),
                                        width = isMobile and 18 or 20,
                                        height = isMobile and 18 or 20,
                                        backgroundFit = "contain",
                                    },
                                },
                            },
                            -- 金币数值
                            UI.Panel {
                                marginLeft = -3,
                                backgroundColor = {50, 38, 10, 220},
                                borderRadius = 12,
                                borderWidth = 1.5,
                                borderColor = {160, 125, 40, 140},
                                paddingLeft = 8, paddingRight = 10,
                                paddingTop = 4, paddingBottom = 4,
                                boxShadow = {
                                    { x = 0, y = 1, blur = 3, spread = 0, color = {0, 0, 0, 40}, inset = true },
                                },
                                children = {
                                    UI.Label {
                                        id = "goldLabel", text = "0",
                                        fontSize = isMobile and 16 or 19,
                                        fontColor = {255, 230, 75, 255},
                                        fontWeight = "bold", numberOfLines = 1,
                                        textShadow = { offsetX = 0, offsetY = 1, blur = 2, color = {0, 0, 0, 100} },
                                    },
                                },
                            },
                        },
                    },
                },
            },
            -- 第二行: 技能图标 + 退出按钮
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
                paddingLeft = 12, paddingRight = 10,
                paddingBottom = 6,
                children = {
                    -- 左侧: 设置按钮 + 技能图标
                    UI.Panel {
                        flexDirection = "row", alignItems = "center", gap = 4, flexShrink = 1,
                        children = {
                            UI.Button {
                                text = "⚙",
                                fontSize = 22,
                                width = 32, height = 28,
                                borderRadius = 8,
                                backgroundColor = {45, 38, 75, 200},
                                fontColor = {180, 175, 215, 230},
                                borderWidth = 1,
                                borderColor = {80, 65, 130, 120},
                                pressedBackgroundColor = {55, 45, 90, 255},
                                onClick = function(self)
                                    SettingsPopup.Show()
                                end,
                            },

                            -- 教程按钮
                            UI.Button {
                                text = "📖",
                                fontSize = 20,
                                width = 32, height = 28,
                                borderRadius = 8,
                                backgroundColor = {35, 55, 75, 200},
                                fontColor = {150, 200, 230, 230},
                                borderWidth = 1,
                                borderColor = {60, 100, 150, 120},
                                pressedBackgroundColor = {45, 65, 90, 255},
                                onClick = function(self)
                                    GameUI.ShowTutorialGuide()
                                end,
                            },


                            UI.Panel {
                                id = "skillsRow",
                                flexDirection = "row", alignItems = "center",
                                gap = 4, flexShrink = 1, flexWrap = "wrap",
                            },
                        },
                    },
                    UI.Panel {
                        width = 44, height = 44,
                        borderRadius = 22,
                        justifyContent = "center", alignItems = "center",
                        backgroundGradient = {
                            type = "linear", direction = "to-bottom",
                            from = {85, 40, 40, 230}, to = {55, 25, 25, 230},
                        },
                        borderWidth = 1.5,
                        borderColor = {180, 70, 70, 150},
                        boxShadow = {
                            { x = 0, y = 2, blur = 6, spread = 0, color = {0, 0, 0, 60} },
                        },
                        onClick = function(self)
                            AM.PlaySFX("ui_click")
                            if G.callbacks and G.callbacks.ReturnToMenu then
                                G.callbacks.ReturnToMenu()
                            end
                        end,
                        children = {
                            UI.Label {
                                text = "X",
                                fontSize = 20,
                                fontWeight = "bold",
                                fontColor = {255, 200, 200, 255},
                                textAlign = "center",
                            },
                        },
                    },
                },
            },

        },
    }
end

function GameUI.CreateBottomBar()
    return UI.Panel {
        width = "100%",
        paddingLeft = 12, paddingRight = 12,
        paddingTop = 5, paddingBottom = 9,
        gap = 4,
        borderTopWidth = 1,
        borderTopColor = {80, 60, 120, 60},
        children = {
            UI.Label {
                id = "comboLabel", text = "",
                fontSize = 21, fontColor = {230, 185, 30, 255},
                textAlign = "center", width = "100%",
                textShadow = { offsetX = 0, offsetY = 1, blur = 3, color = {200, 150, 0, 60} },
            },
            UI.Label {
                id = "logLabel",
                text = "点击橙色格子规划跳跃路径，蓝色格子直接移动",
                fontSize = 19, fontColor = {130, 140, 170, 190},
                textAlign = "center", width = "100%", numberOfLines = 2,
            },
        },
    }
end

function GameUI.CreateResultPanel()
    return UI.Panel {
        id = "resultPanel",
        visible = false,
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center", alignItems = "center",
        backgroundColor = {0, 0, 0, 160},
        backdropBlur = 6,
        children = {
            UI.Panel {
                width = "85%", maxWidth = 340,
                padding = 28, gap = 18,
                backgroundGradient = {
                    type = "linear", direction = "to-bottom",
                    from = {38, 42, 72, 252}, to = {22, 24, 48, 252},
                },
                borderRadius = 24, borderWidth = 1.5,
                borderColor = {130, 110, 210, 120},
                alignItems = "center",
                boxShadow = {
                    { x = 0, y = 8, blur = 30, spread = 2, color = {0, 0, 0, 100} },
                    { x = 0, y = 0, blur = 1, spread = 0, color = {140, 120, 220, 40}, inset = true },
                },
                children = {
                    UI.Label {
                        id = "resultTitle", text = "胜利！",
                        fontSize = 38, fontColor = {255, 225, 65, 255},
                        fontWeight = "bold",
                        textShadow = { offsetX = 0, offsetY = 2, blur = 8, color = {200, 160, 0, 100} },
                    },
                    UI.Label {
                        id = "resultInfo", text = "",
                        fontSize = 21, fontColor = {195, 205, 230, 240},
                        textAlign = "center", numberOfLines = 10,
                        width = "100%",
                    },
                    UI.Button {
                        id = "resultBtn",
                        text = "再来一局", variant = "primary",
                        width = 210, height = 50, fontSize = 23,
                        borderRadius = 25,
                        backgroundGradient = {
                            type = "linear", direction = "to-bottom",
                            from = {255, 215, 60, 255}, to = {235, 180, 30, 255},
                        },
                        fontColor = {20, 15, 5, 255},
                        fontWeight = "bold",
                        pressedBackgroundColor = {220, 170, 25, 255},
                        boxShadow = {
                            { x = 0, y = 3, blur = 10, spread = 0, color = {200, 160, 20, 60} },
                        },
                        onClick = function(self)
                            AM.PlaySFX("ui_click")
                            G.callbacks.RestartGame()
                        end,
                    },
                    UI.Button {
                        text = "返回主菜单", variant = "secondary",
                        width = 210, height = 50, fontSize = 21,
                        borderRadius = 25,
                        backgroundGradient = {
                            type = "linear", direction = "to-bottom",
                            from = {52, 48, 78, 255}, to = {35, 32, 58, 255},
                        },
                        borderWidth = 1,
                        borderColor = {95, 85, 145, 140},
                        fontColor = {190, 185, 225, 255},
                        pressedBackgroundColor = {40, 36, 62, 255},
                        boxShadow = {
                            { x = 0, y = 2, blur = 6, spread = 0, color = {0, 0, 0, 40} },
                        },
                        onClick = function(self)
                            AM.PlaySFX("ui_click")
                            G.callbacks.ReturnToMenu()
                        end,
                    },
                },
            },
        },
    }
end

function GameUI.CreateSkillModal()
    local modal = UI.Modal {
        id = "skillModal",
        -- 不设 title，省掉标题栏高度
        size = "fullscreen",
        closeOnOverlay = false,
        closeOnEscape = false,
        showCloseButton = false,
        contentPadding = 0,
        contentGap = 0,
        children = {
            UI.Panel {
                width = "100%",
                padding = 18, paddingTop = 22, paddingBottom = 18, gap = 16,
                alignItems = "center",
                children = {
                    UI.Label {
                        id = "skillSubtitle",
                        text = "选择一个技能升级",
                        fontSize = 24, fontColor = {220, 210, 255, 230},
                    },
                    -- 卡片容器
                    UI.Panel {
                        id = "skillCardsContainer",
                        width = "100%", gap = 14,
                    },
                },
            },
        },
    }
    G.skillModal = modal
    return modal
end

function GameUI.PopulateSkillCards(choices)
    -- Modal 的子元素在 contentContainer_ 中，需要从那里搜索
    local searchRoot = G.skillModal and G.skillModal.contentContainer_ or G.uiRoot
    local container = searchRoot:FindById("skillCardsContainer")
    if not container then return end
    container:ClearChildren()

    local subtitleLabel = searchRoot:FindById("skillSubtitle")
    if subtitleLabel then
        subtitleLabel:SetText("🎉 恭喜过关！选择一个技能")
        subtitleLabel:SetStyle({ fontSize = 24, fontColor = {255, 220, 100, 230} })
    end

    for _, choice in ipairs(choices) do
        local capturedChoice = choice
        local def = choice.skill
        local clr = def.color or {100, 100, 200}
        local curLv = choice.currentLevel
        local nextLv = choice.nextLevel
        local isNew = curLv == 0
        local tagText = isNew and "新技能" or ("Lv" .. curLv .. "→" .. nextLv)
        local tagColor = isNew and {100, 220, 255, 255} or {255, 200, 50, 255}
        local nextDesc = def.desc(nextLv)

        -- 等级进度条：实心=已选等级，空心=未选等级
        local levelDots = {}
        for i = 1, def.maxLevel do
            local filled = i <= curLv
            levelDots[#levelDots + 1] = UI.Panel {
                width = 18, height = 6, borderRadius = 3,
                backgroundColor = filled
                    and {clr[1], clr[2], clr[3], 255}
                    or {60, 65, 85, 150},
            }
        end

        -- 左侧色条 + 图标 + 右侧信息
        container:AddChild(UI.Panel {
            width = "100%",
            flexDirection = "row",
            borderRadius = 12, overflow = "hidden",
            backgroundColor = isNew and {30, 25, 45, 250} or {25, 28, 42, 240},
            borderWidth = isNew and 2.0 or 1.5,
            borderColor = {clr[1], clr[2], clr[3], isNew and 220 or 80},
            boxShadow = isNew and {
                { x = 0, y = 0, blur = 16, spread = 4,  color = {clr[1], clr[2], clr[3], 90} },
                { x = 0, y = 3, blur = 10, spread = 0,  color = {0, 0, 0, 80} },
            } or {
                { x = 0, y = 3, blur = 10, spread = 0,  color = {0, 0, 0, 70} },
            },
            onPointerDown = function(event, widget)
                AM.PlaySFX("ui_click")
                G.callbacks.OnSkillSelected(capturedChoice)
            end,
            children = {
                -- 左侧色条 + 图标区
                UI.Panel {
                    width = 76, alignItems = "center", justifyContent = "center",
                    backgroundGradient = isNew and {
                        type = "linear", direction = "to-bottom",
                        from = {math.floor(clr[1] * 0.65), math.floor(clr[2] * 0.65), math.floor(clr[3] * 0.65), 220},
                        to = {math.floor(clr[1] * 0.35), math.floor(clr[2] * 0.35), math.floor(clr[3] * 0.35), 220},
                    } or {
                        type = "linear", direction = "to-bottom",
                        from = {math.floor(clr[1] * 0.5), math.floor(clr[2] * 0.5), math.floor(clr[3] * 0.5), 200},
                        to = {math.floor(clr[1] * 0.25), math.floor(clr[2] * 0.25), math.floor(clr[3] * 0.25), 200},
                    },
                    paddingTop = 18, paddingBottom = 18,
                    children = {
                        UI.Panel {
                            backgroundImage = IconAtlas.GetPath(def.icon),
                            width = isNew and 56 or 48,
                            height = isNew and 56 or 48,
                            backgroundFit = "contain",
                        },
                    },
                },
                -- 右侧信息区
                UI.Panel {
                    flexGrow = 1, flexShrink = 1,
                    padding = 14, paddingLeft = 14, gap = 6,
                    justifyContent = "center",
                    children = {
                        -- 名称 + 标签
                        UI.Panel {
                            flexDirection = "row", alignItems = "center", gap = 8,
                            children = {
                                UI.Label {
                                    text = def.name,
                                    fontSize = isNew and 28 or 26,
                                    fontColor = isNew
                                        and {clr[1] + 60 > 255 and 255 or clr[1] + 60,
                                             clr[2] + 60 > 255 and 255 or clr[2] + 60,
                                             clr[3] + 60 > 255 and 255 or clr[3] + 60, 255}
                                        or {255, 255, 255, 240},
                                },
                                UI.Label {
                                    text = tagText,
                                    fontSize = isNew and 16 or 15,
                                    fontColor = tagColor,
                                },
                            },
                        },
                        -- 等级进度条
                        UI.Panel {
                            flexDirection = "row", gap = 4, marginBottom = 2,
                            children = levelDots,
                        },
                        -- 效果描述
                        UI.Label {
                            text = nextDesc,
                            fontSize = 20, fontColor = {170, 180, 210, 210},
                            numberOfLines = 2,
                        },
                    },
                },
            },
        })
    end

    -- 显示已激活的组合技（图标+名称行）
    local battle = G.battle
    local combos = Skills.GetActiveCombos(battle.skills)
    if #combos > 0 then
        local comboChildren = {
            UI.Label { text = "组合技: ", fontSize = 16, fontColor = {200, 150, 50, 220} },
        }
        for _, c in ipairs(combos) do
            comboChildren[#comboChildren + 1] = UI.Panel {
                backgroundImage = IconAtlas.GetPath(c.icon),
                width = 16, height = 16, backgroundFit = "contain",
            }
            comboChildren[#comboChildren + 1] = UI.Label {
                text = c.name .. " ", fontSize = 16, fontColor = {200, 150, 50, 220},
            }
        end
        container:AddChild(UI.Panel {
            flexDirection = "row", alignItems = "center", flexWrap = "wrap",
            marginTop = 4, gap = 2,
            children = comboChildren,
        })
    end

    -- 显示接近解锁的组合技提示（图标+进度）
    local nearCombos = Skills.GetNearCombos(battle.skills)
    for _, nc in ipairs(nearCombos) do
        local c = nc.combo
        local hintChildren = {
            UI.Label { text = "🔗 ", fontSize = 16, fontColor = {180, 160, 255, 150} },
            UI.Panel {
                backgroundImage = IconAtlas.GetPath(c.icon),
                width = 14, height = 14, backgroundFit = "contain",
            },
            UI.Label { text = c.name .. " (", fontSize = 16, fontColor = {180, 160, 255, 150} },
        }
        for i, reqId in ipairs(c.requires) do
            local reqDef = Skills.GetDef(reqId)
            local lv = Skills.Level(battle.skills, reqId)
            local maxLv = reqDef and reqDef.maxLevel or 5
            if i > 1 then
                hintChildren[#hintChildren + 1] = UI.Label {
                    text = "+", fontSize = 16, fontColor = {180, 160, 255, 150},
                }
            end
            hintChildren[#hintChildren + 1] = UI.Panel {
                backgroundImage = IconAtlas.GetPath(reqDef and reqDef.icon or ""),
                width = 14, height = 14, backgroundFit = "contain",
            }
            local lvText = lv >= maxLv and "MAX" or ("Lv" .. lv .. "/" .. maxLv)
            hintChildren[#hintChildren + 1] = UI.Label {
                text = lvText, fontSize = 16, fontColor = {180, 160, 255, 150},
            }
        end
        hintChildren[#hintChildren + 1] = UI.Label {
            text = ")", fontSize = 16, fontColor = {180, 160, 255, 150},
        }
        container:AddChild(UI.Panel {
            flexDirection = "row", alignItems = "center", flexWrap = "wrap",
            gap = 2,
            children = hintChildren,
        })
    end
end

-- 章节背景主题色表（饱和度提高，确保棋盘外区域也能体现章节色）
local BG_THEMES = {
    [1] = { top={15,25,60,255},   bot={22,42,85,255}  },  -- 深海蓝（保持不变）
    [2] = { top={40,16,8,255},    bot={58,22,10,255}  },  -- 熔岩暗红棕（调暗降饱和）
    [3] = { top={15,45,35,255},   bot={22,68,52,255}  },  -- 珊瑚深绿（保持不变）
    [4] = { top={32,20,58,255},   bot={42,28,72,255}  },  -- 深渊紫（调暗降饱和）
}

--- 动态更新根面板背景渐变（换章节时调用）
function GameUI.UpdateBackground()
    if not G.uiRoot then return end
    local isEndless = G.battle and G.battle.isEndless
    local ch = 1
    if G.battle and G.battle.level then
        ch = math.ceil(G.battle.level / Battle.LEVELS_PER_CHAPTER)
    end
    if isEndless then ch = 4 end
    local t = BG_THEMES[ch] or BG_THEMES[1]
    G.uiRoot:SetBackgroundGradient({
        type = "linear", direction = "to-bottom",
        from = t.top, to = t.bot,
    })
end

--- 构建完整游戏 UI（HUD + 棋盘 + 底栏 + 面板）
function GameUI.CreateUI()
    -- 根据章节/模式选择全屏背景渐变色
    local isEndless = G.battle and G.battle.isEndless
    local ch = 1
    if G.battle and G.battle.level then
        ch = math.ceil(G.battle.level / Battle.LEVELS_PER_CHAPTER)
    end
    if isEndless then ch = 4 end

    -- 直接用棋盘主题的 bgTop/bgBot，与 BoardWidget 背景无缝衔接
    local t = BG_THEMES[ch] or BG_THEMES[1]
    local gradFrom = t.top
    local gradTo   = t.bot

    G.uiRoot = UI.Panel {
        width = "100%", height = "100%",
        flexDirection = "column",
        backgroundGradient = {
            type = "linear", direction = "to-bottom",
            from = gradFrom, to = gradTo,
        },
        children = {
            GameUI.CreateHUD(),
            -- 棋盘容器（透明，背景由根节点渐变透出）
            UI.Panel {
                flexGrow = 1,
                children = {
                    BoardWidget {
                        width = "100%", height = "100%",
                        onCellClick = function(col, row)
                            G.callbacks.HandleCellClick(col, row)
                        end,
                    },
                    -- 击杀/救援目标提示条（绝对定位浮在棋盘上方）
                    UI.Panel {
                        id = "killBar",
                        visible = false,
                        position = "absolute",
                        top = 4, left = 0, right = 0,
                        flexDirection = "row",
                        justifyContent = "center",
                        alignItems = "center",
                        gap = 8,
                        children = {
                            UI.Panel {
                                flexDirection = "row", alignItems = "center", gap = 8,
                                backgroundGradient = {
                                    type = "linear", direction = "to-right",
                                    from = {155, 35, 35, 245}, to = {120, 25, 28, 245},
                                },
                                borderRadius = 18,
                                borderWidth = 1.5,
                                borderColor = {210, 65, 65, 150},
                                paddingLeft = 16, paddingRight = 16,
                                paddingTop = 7, paddingBottom = 7,
                                boxShadow = {
                                    { x = 0, y = 2, blur = 8, spread = 0, color = {120, 20, 20, 70} },
                                },
                                children = {
                                    UI.Panel {
                                        backgroundImage = IconAtlas.GetPath("hud_kill"),
                                        width = 18, height = 18, backgroundFit = "contain",
                                    },
                                    UI.Label {
                                        id = "killLabel", text = "击杀目标: 0/5",
                                        fontSize = 19, fontColor = {255, 225, 225, 255},
                                        fontWeight = "bold",
                                        textShadow = { offsetX = 0, offsetY = 1, blur = 2, color = {0, 0, 0, 80} },
                                    },
                                },
                            },
                            -- 救援目标（第三章专用）
                            UI.Panel {
                                id = "rescueBar",
                                visible = false,
                                flexDirection = "row", alignItems = "center", gap = 8,
                                backgroundGradient = {
                                    type = "linear", direction = "to-right",
                                    from = {35, 120, 100, 245}, to = {25, 95, 80, 245},
                                },
                                borderRadius = 18,
                                borderWidth = 1.5,
                                borderColor = {65, 200, 150, 150},
                                paddingLeft = 16, paddingRight = 16,
                                paddingTop = 7, paddingBottom = 7,
                                boxShadow = {
                                    { x = 0, y = 2, blur = 8, spread = 0, color = {20, 80, 60, 70} },
                                },
                                children = {
                                    UI.Label {
                                        text = "🦀", fontSize = 19,
                                    },
                                    UI.Label {
                                        id = "rescueLabel", text = "救援: 0/1",
                                        fontSize = 19, fontColor = {200, 255, 230, 255},
                                        fontWeight = "bold",
                                        textShadow = { offsetX = 0, offsetY = 1, blur = 2, color = {0, 0, 0, 80} },
                                    },
                                },
                            },
                            -- 祭坛计数（第二章专用）
                            UI.Panel {
                                id = "altarBar",
                                visible = false,
                                flexDirection = "row", alignItems = "center", gap = 8,
                                backgroundGradient = {
                                    type = "linear", direction = "to-right",
                                    from = {120, 50, 20, 245}, to = {90, 35, 15, 245},
                                },
                                borderRadius = 18,
                                borderWidth = 1.5,
                                borderColor = {255, 140, 50, 150},
                                paddingLeft = 16, paddingRight = 16,
                                paddingTop = 7, paddingBottom = 7,
                                boxShadow = {
                                    { x = 0, y = 2, blur = 8, spread = 0, color = {80, 30, 10, 70} },
                                },
                                children = {
                                    UI.Label {
                                        text = "🔥", fontSize = 19,
                                    },
                                    UI.Label {
                                        id = "altarLabel", text = "祭坛: 0",
                                        fontSize = 19, fontColor = {255, 200, 140, 255},
                                        fontWeight = "bold",
                                        textShadow = { offsetX = 0, offsetY = 1, blur = 2, color = {0, 0, 0, 80} },
                                    },
                                },
                            },
                        },
                    },
                    -- Boss 血条（绝对定位浮在棋盘上方）
                    UI.Panel {
                        id = "bossHpBar",
                        visible = false,
                        position = "absolute",
                        top = 0, left = 0, right = 0,
                        flexDirection = "column",
                        alignItems = "center",
                        paddingTop = 6, paddingBottom = 8,
                        paddingLeft = 16, paddingRight = 16,
                        backgroundGradient = {
                            type = "linear", direction = "to-bottom",
                            from = {40, 15, 25, 220}, to = {25, 10, 18, 0},
                        },
                        children = {
                            -- Boss 名字
                            UI.Label {
                                id = "bossNameLabel", text = "",
                                fontSize = 17, fontColor = {255, 200, 200, 240},
                                fontWeight = "bold",
                                marginBottom = 4,
                                textShadow = { offsetX = 0, offsetY = 1, blur = 4, color = {0, 0, 0, 150} },
                            },
                            -- 血条外框
                            UI.Panel {
                                width = "90%", height = 26,
                                borderRadius = 13,
                                backgroundColor = {10, 5, 20, 230},
                                borderWidth = 2,
                                borderColor = {200, 50, 50, 200},
                                boxShadow = {
                                    { x = 0, y = 0, blur = 14, spread = 3, color = {220, 40, 40, 80} },
                                    { x = 0, y = 2, blur = 4, spread = 0, color = {0, 0, 0, 100} },
                                },
                                overflow = "hidden",
                                children = {
                                    -- 血条填充
                                    UI.Panel {
                                        id = "bossHpFill",
                                        width = "100%", height = "100%",
                                        borderRadius = 12,
                                        backgroundGradient = {
                                            type = "linear", direction = "to-right",
                                            from = {200, 35, 35, 255}, to = {255, 70, 50, 255},
                                        },
                                    },
                                    -- HP 文字（叠在血条上）
                                    UI.Panel {
                                        position = "absolute",
                                        left = 0, right = 0, top = 0, bottom = 0,
                                        justifyContent = "center", alignItems = "center",
                                        children = {
                                            UI.Label {
                                                id = "bossHpLabel", text = "",
                                                fontSize = 14, fontColor = {255, 255, 255, 245},
                                                fontWeight = "bold",
                                                textShadow = { offsetX = 0, offsetY = 1, blur = 3, color = {0, 0, 0, 180} },
                                            },
                                        },
                                    },
                                },
                            },
                        },
                    },
                    -- 浮动确认/撤销/重选按钮
                    UI.Panel {
                        id = "btnPanel",
                        visible = false,
                        position = "absolute",
                        bottom = 16, left = 0, right = 0,
                        flexDirection = "row",
                        justifyContent = "center",
                        gap = 8,
                        children = {
                            UI.Button {
                                id = "confirmBtn",
                                text = "✓ 确认跳跃",
                                variant = "primary",
                                height = 46, paddingLeft = 24, paddingRight = 24,
                                fontSize = 21,
                                borderRadius = 23,
                                backgroundGradient = {
                                    type = "linear", direction = "to-bottom",
                                    from = {255, 218, 65, 255}, to = {235, 180, 30, 255},
                                },
                                fontColor = {20, 15, 5, 255},
                                fontWeight = "bold",
                                pressedBackgroundColor = {215, 165, 20, 255},
                                boxShadow = {
                                    { x = 0, y = 3, blur = 10, spread = 0, color = {200, 160, 20, 70} },
                                    { x = 0, y = 1, blur = 0, spread = 0, color = {255, 240, 150, 40}, inset = true },
                                },
                                onClick = function(self)
                                    AM.PlaySFX("ui_click")
                                    G.callbacks.ConfirmJumps()
                                end,
                            },
                            UI.Button {
                                id = "undoBtn",
                                text = "↩ 撤销",
                                variant = "secondary",
                                height = 46, paddingLeft = 18, paddingRight = 18,
                                fontSize = 19,
                                borderRadius = 23,
                                backgroundGradient = {
                                    type = "linear", direction = "to-bottom",
                                    from = {55, 50, 82, 245}, to = {38, 34, 60, 245},
                                },
                                fontColor = {190, 185, 225, 255},
                                borderWidth = 1,
                                borderColor = {95, 85, 145, 150},
                                pressedBackgroundColor = {42, 38, 65, 255},
                                boxShadow = {
                                    { x = 0, y = 2, blur = 6, spread = 0, color = {0, 0, 0, 50} },
                                },
                                onClick = function(self)
                                    AM.PlaySFX("ui_click")
                                    G.callbacks.UndoLastJump()
                                end,
                            },
                            UI.Button {
                                id = "cancelBtn",
                                text = "× 重选",
                                variant = "secondary",
                                height = 46, paddingLeft = 18, paddingRight = 18,
                                fontSize = 19,
                                borderRadius = 23,
                                backgroundGradient = {
                                    type = "linear", direction = "to-bottom",
                                    from = {55, 50, 82, 245}, to = {38, 34, 60, 245},
                                },
                                fontColor = {190, 185, 225, 255},
                                borderWidth = 1,
                                borderColor = {95, 85, 145, 150},
                                pressedBackgroundColor = {42, 38, 65, 255},
                                boxShadow = {
                                    { x = 0, y = 2, blur = 6, spread = 0, color = {0, 0, 0, 50} },
                                },
                                onClick = function(self)
                                    AM.PlaySFX("ui_click")
                                    G.callbacks.CancelPlan()
                                end,
                            },
                        },
                    },

                },
            },
            GameUI.CreateBottomBar(),
            GameUI.CreateResultPanel(),
            GameUI.CreateSkillModal(),
        },
    }
    UI.SetRoot(G.uiRoot)

    G.hpLabel = G.uiRoot:FindById("hpLabel")
    G.comboLabel = G.uiRoot:FindById("comboLabel")
    G.turnLabel = G.uiRoot:FindById("turnLabel")
    G.goldLabel = G.uiRoot:FindById("goldLabel")
    G.logLabel = G.uiRoot:FindById("logLabel")
    G.levelLabel = G.uiRoot:FindById("levelLabel")
    G.skillsRow = G.uiRoot:FindById("skillsRow")
    G.shieldIcon = G.uiRoot:FindById("shieldIcon")
    G.killLabel = G.uiRoot:FindById("killLabel")
    G.killBar = G.uiRoot:FindById("killBar")
    G.rescueLabel = G.uiRoot:FindById("rescueLabel")
    G.rescueBar = G.uiRoot:FindById("rescueBar")
    G.altarBar = G.uiRoot:FindById("altarBar")
    G.altarLabel = G.uiRoot:FindById("altarLabel")
    G.btnPanel = G.uiRoot:FindById("btnPanel")
    G.confirmBtn = G.uiRoot:FindById("confirmBtn")
    G.resultPanel = G.uiRoot:FindById("resultPanel")
    -- G.skillModal 已在 CreateSkillModal() 中赋值

end

--- 更新 HUD 显示
function GameUI.UpdateHUD()
    if not G.battle then return end
    local hero = G.battle.hero
    if G.hpLabel then
        G.hpLabel:SetText(string.format("%d/%d", math.floor(math.max(0, hero.hp)), math.floor(hero.maxHp)))
    end
    if G.levelLabel then
        if G.battle.isEndless then
            local wave = math.floor(G.battle.endlessWave or 1)
            G.levelLabel:SetText(string.format("无尽 第%d波", wave))
        else
            local chapter, stage = Battle.GetChapterInfo(G.battle.level)
            if Battle.IsBossLevel(G.battle.level) then
                G.levelLabel:SetText(string.format("第%d章 Boss", chapter))
            else
                G.levelLabel:SetText(string.format("第%d章 %d/%d", chapter, stage, Battle.LEVELS_PER_CHAPTER))
            end
        end
    end
    if G.turnLabel then
        if G.battle.isEndless then
            -- 无尽模式累计存活回合数
            local totalTurns = G.battle.endlessTotalTurns or 0
            G.turnLabel:SetText("存活 " .. totalTurns .. " 回合")
        else
            G.turnLabel:SetText("回合 " .. G.battle.turn)
        end
    end
    if G.killLabel then
        local isBoss = Battle.IsBossLevel(G.battle.level)
        if isBoss then
            -- Boss关不显示击杀目标条
            if G.killBar then G.killBar:SetVisible(false) end
        else
            local kills = math.floor(G.battle.kills or 0)
            local target = math.floor(G.battle.killTarget or 5)
            if G.killBar then G.killBar:SetVisible(true) end
            G.killLabel:SetText(string.format("击杀目标: %d/%d", kills, target))
            -- 快完成时变色
            if kills >= target then
                G.killLabel:SetStyle({ fontColor = {120, 255, 140, 255} })
            elseif kills >= target - 1 then
                G.killLabel:SetStyle({ fontColor = {255, 230, 100, 255} })
            else
                G.killLabel:SetStyle({ fontColor = {255, 220, 220, 255} })
            end
        end
    end
    -- 救援目标（第三章）
    if G.rescueBar then
        local rescueTarget = G.battle.rescueTarget or 0
        if rescueTarget > 0 and not Battle.IsBossLevel(G.battle.level) then
            G.rescueBar:SetVisible(true)
            local rescued = math.floor(G.battle.rescueCount or 0)
            if G.rescueLabel then
                G.rescueLabel:SetText(string.format("救援: %d/%d", rescued, math.floor(rescueTarget)))
                if rescued >= rescueTarget then
                    G.rescueLabel:SetStyle({ fontColor = {120, 255, 200, 255} })
                else
                    G.rescueLabel:SetStyle({ fontColor = {200, 255, 230, 255} })
                end
            end
        else
            G.rescueBar:SetVisible(false)
        end
    end
    -- 炎魔祭坛（第二章）
    if G.altarBar then
        local chapter = math.ceil(G.battle.level / 10)
        local isBoss = Battle.IsBossLevel(G.battle.level)
        if chapter == 2 and not isBoss and G.battle.board and G.battle.board.altars then
            local active = Battle.GetActiveAltarCount(G.battle.board)
            local total = #G.battle.board.altars
            G.altarBar:SetVisible(true)
            if G.altarLabel then
                if active == 0 then
                    G.altarLabel:SetText("祭坛已全部摧毁！")
                    G.altarLabel:SetStyle({ fontColor = {120, 255, 140, 255} })
                else
                    G.altarLabel:SetText(string.format("🔥 祭坛: %d/%d 存活", math.floor(active), math.floor(total)))
                    G.altarLabel:SetStyle({ fontColor = {255, 200, 120, 255} })
                end
            end
        else
            G.altarBar:SetVisible(false)
        end
    end
    if G.goldLabel then
        G.goldLabel:SetText(tostring(G.battle.gold))
    end
    -- Boss 血条
    if G.bossHpBar then
        if Battle.IsBossLevel(G.battle.level) then
            local boss = nil
            local enemies = HexGrid.GetTeamPieces(G.battle.board, "enemy")
            for _, e in ipairs(enemies) do
                if e.isBoss then boss = e; break end
            end
            if boss then
                G.bossHpBar:SetVisible(true)
                local hp = math.max(0, boss.hp)
                local maxHp = boss.maxHp or 1
                local pct = hp / maxHp
                if G.bossNameLabel then
                    G.bossNameLabel:SetText(boss.name or "Boss")
                end
                if G.bossHpFill then
                    G.bossHpFill:SetStyle({ width = string.format("%.1f%%", pct * 100) })
                    -- 血量低时变色
                    if pct <= 0.25 then
                        G.bossHpFill:SetStyle({
                            backgroundGradient = {
                                type = "linear", direction = "to-right",
                                from = {255, 50, 20, 255}, to = {255, 100, 30, 255},
                            },
                        })
                    elseif pct <= 0.5 then
                        G.bossHpFill:SetStyle({
                            backgroundGradient = {
                                type = "linear", direction = "to-right",
                                from = {230, 140, 20, 255}, to = {255, 180, 40, 255},
                            },
                        })
                    else
                        G.bossHpFill:SetStyle({
                            backgroundGradient = {
                                type = "linear", direction = "to-right",
                                from = {200, 35, 35, 255}, to = {255, 70, 50, 255},
                            },
                        })
                    end
                end
                if G.bossHpLabel then
                    local hpText = string.format("%d / %d", math.floor(hp), math.floor(maxHp))
                    -- 有护盾时显示护盾信息
                    if boss.shieldHp and boss.shieldMax and boss.shieldMax > 0 and boss.shieldHp > 0 then
                        hpText = hpText .. string.format("  +%d", math.floor(boss.shieldHp))
                    end
                    G.bossHpLabel:SetText(hpText)
                end
            else
                -- Boss已死亡
                G.bossHpBar:SetVisible(false)
            end
        else
            G.bossHpBar:SetVisible(false)
        end
    end
    if G.comboLabel then
        G.comboLabel:SetText("")
    end
    if G.skillsRow then
        G.skillsRow:ClearChildren()
        local owned = G.battle.skills
        local hasAny = false
        for id, lv in pairs(owned) do
            if lv > 0 then
                local def = Skills.GetDef(id)
                if def then
                    hasAny = true
                    G.skillsRow:AddChild(UI.Panel {
                        backgroundImage = IconAtlas.GetPath(def.icon),
                        width = 22, height = 22, backgroundFit = "contain",
                    })
                end
            end
        end
        -- 已激活的组合技图标
        local combos = Skills.GetActiveCombos(owned)
        for _, c in ipairs(combos) do
            hasAny = true
            G.skillsRow:AddChild(UI.Panel {
                backgroundImage = IconAtlas.GetPath(c.icon),
                width = 22, height = 22, backgroundFit = "contain",
                borderWidth = 1, borderColor = {255, 200, 60, 150}, borderRadius = 4,
            })
        end
    end
    if G.shieldIcon then
        G.shieldIcon:SetVisible(G.battle.hasShield)
    end
end

function GameUI.UpdateLog(msg)
    if G.logLabel then
        G.logLabel:SetText(msg)
    end
end

-- ============================================================================
-- 章节新手教学弹窗
-- ============================================================================

--- 章节教学配置（可视化图解风格）
local CHAPTER_TUTORIALS = {
    [1] = {
        title = "新手教学",
        accentColor = {70, 150, 230, 255},
        steps = {
            { icon = "🔵  👉  ⬜", caption = "点击相邻空格移动英雄" },
            { icon = "🔵 ⚔️ 🔴  💥", caption = "跳过敌人，造成伤害" },
            { icon = "💥💥💥 ➡️ 🌟", caption = "连跳触发COMBO奖励" },
            { icon = "💊  💰  🛡️", caption = "路上有血瓶、金币、护盾可拾取" },
        },
        goal = "⚔️ 消灭足够的敌人  =  通关",
        buttonText = "出发！🌊",
    },
    [2] = {
        title = "炎魔祭坛",
        accentColor = {230, 120, 50, 255},
        steps = {
            { icon = "🔥  🛡️🔴🛡️🔴", caption = "祭坛给周围敌人套上护盾" },
            { icon = "🐧  👉  🔥  💥", caption = "移动到祭坛上摧毁它" },
            { icon = "💥  ➡️  🔴🔴", caption = "祭坛摧毁，护盾消失！" },
        },
        goal = "🔥摧毁祭坛 + ⚔️击杀目标 = 通关",
        buttonText = "迎战火焰！🔥",
    },
    [3] = {
        title = "珊瑚迷宫",
        accentColor = {80, 210, 190, 255},
        steps = {
            { icon = "🦀  🪨  🐚", caption = "蟹和壳被障碍隔开了" },
            { icon = "💥  ➡️  🦀🐚", caption = "清除障碍，打通道路" },
            { icon = "🦀🐚  ✅", caption = "路通了，蟹自动回家" },
        },
        goal = "⚔️ 击杀目标  +  🦀 救出全部蟹  =  通关",
        buttonText = "出发救蟹！🦀",
    },
}

--- 创建单个步骤卡片
---@param stepNum number
---@param step table
---@param accent table
---@return UIElement
local function MakeTutorialStep(stepNum, step, accent)
    return UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        gap = 10,
        paddingTop = 8, paddingBottom = 8,
        paddingLeft = 10, paddingRight = 10,
        backgroundColor = {accent[1], accent[2], accent[3], 18},
        borderRadius = 12,
        children = {
            -- 步骤编号圆圈
            UI.Panel {
                width = 26, height = 26,
                borderRadius = 13,
                backgroundColor = {accent[1], accent[2], accent[3], 200},
                justifyContent = "center", alignItems = "center",
                flexShrink = 0,
                children = {
                    UI.Label {
                        text = tostring(stepNum),
                        fontSize = 16, fontWeight = "bold",
                        fontColor = {10, 20, 20, 255},
                    },
                },
            },
            -- 右侧：图解 + 说明
            UI.Panel {
                flexGrow = 1, flexShrink = 1,
                alignItems = "center",
                gap = 2,
                children = {
                    UI.Label {
                        text = step.icon,
                        fontSize = 28,
                        textAlign = "center",
                    },
                    UI.Label {
                        text = step.caption,
                        fontSize = 15,
                        fontColor = {200, 220, 230, 220},
                        textAlign = "center",
                        numberOfLines = 1,
                    },
                },
            },
        },
    }
end

--- 显示章节教学弹窗（可视化图解）
---@param chapter number
function GameUI.ShowChapterTutorial(chapter)
    local tut = CHAPTER_TUTORIALS[chapter]
    if not tut then return end

    AM.PlaySFX("ui_popup_open")
    local ac = tut.accentColor

    local contentChildren = {}

    -- 标题
    contentChildren[#contentChildren + 1] = UI.Label {
        text = tut.title,
        fontSize = 26, fontWeight = "bold",
        fontColor = ac,
        textAlign = "center",
        marginBottom = 4,
    }

    -- 短分割线
    contentChildren[#contentChildren + 1] = UI.Panel {
        width = 60, height = 2,
        backgroundColor = {ac[1], ac[2], ac[3], 120},
        alignSelf = "center", borderRadius = 1,
        marginBottom = 12,
    }

    -- 三步图解
    for i, step in ipairs(tut.steps) do
        contentChildren[#contentChildren + 1] = MakeTutorialStep(i, step, ac)
        -- 步骤间的向下箭头
        if i < #tut.steps then
            contentChildren[#contentChildren + 1] = UI.Label {
                text = "⬇",
                fontSize = 17,
                fontColor = {ac[1], ac[2], ac[3], 100},
                textAlign = "center",
                alignSelf = "center",
            }
        end
    end

    -- 通关条件高亮条
    contentChildren[#contentChildren + 1] = UI.Panel {
        width = "100%",
        marginTop = 10,
        paddingTop = 10, paddingBottom = 10,
        paddingLeft = 8, paddingRight = 8,
        backgroundColor = {ac[1], ac[2], ac[3], 45},
        borderRadius = 10,
        borderWidth = 2,
        borderColor = {ac[1], ac[2], ac[3], 100},
        justifyContent = "center",
        alignItems = "center",
        children = {
            UI.Label {
                text = tut.goal,
                fontSize = 16, fontWeight = "bold",
                fontColor = {ac[1], ac[2], ac[3], 255},
                textAlign = "center",
                numberOfLines = 1,
            },
        },
    }

    -- 出发按钮
    contentChildren[#contentChildren + 1] = UI.Button {
        text = tut.buttonText or "出发！",
        variant = "primary",
        width = 180, height = 44, fontSize = 20,
        fontWeight = "bold",
        borderRadius = 22,
        backgroundGradient = {
            type = "linear", direction = "to-bottom",
            from = {ac[1], ac[2], ac[3], 255},
            to = {math.max(0, ac[1] - 30), math.max(0, ac[2] - 30), math.max(0, ac[3] - 20), 255},
        },
        fontColor = {10, 10, 20, 255},
        marginTop = 10,
        onClick = function(self)
            AM.PlaySFX("ui_popup_close")
            if G.chapterTutorialPopup then
                G.chapterTutorialPopup:SetVisible(false)
            end
        end,
    }

    -- 移除旧弹窗
    if G.chapterTutorialPopup then
        G.chapterTutorialPopup:Remove()
        G.chapterTutorialPopup = nil
    end

    G.chapterTutorialPopup = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center", alignItems = "center",
        backgroundColor = {0, 0, 0, 170},
        backdropBlur = 4,
        zIndex = 800,
        children = {
            UI.Panel {
                width = "85%", maxWidth = 320,
                backgroundGradient = {
                    type = "linear", direction = "to-bottom",
                    from = {25, 40, 45, 250}, to = {15, 25, 30, 250},
                },
                borderRadius = 16,
                borderWidth = 1.5,
                borderColor = {ac[1], ac[2], ac[3], 100},
                paddingTop = 20, paddingBottom = 20,
                paddingLeft = 16, paddingRight = 16,
                gap = 4,
                alignItems = "center",
                children = contentChildren,
            },
        },
    }
    UI.GetRoot():AddChild(G.chapterTutorialPopup)
end


--- 连击教程弹窗（第一章首次打出连击时显示）
function GameUI.ShowComboTutorial(onClose)
    AM.PlaySFX("ui_popup_open")

    local ac = {255, 200, 60, 255}  -- 金色主题

    -- 连击奖励数据
    local comboTiers = {
        { combo = "2连击", icon = "🗡️",  name = "追踪飞镖", desc = "飞向最近敌人造成50伤害，\n或自动拾取最近道具", color = {255, 220, 100} },
        { combo = "3连击", icon = "🌾",  name = "稻草人",   desc = "召唤稻草人嘲讽所有敌人，\n替你承受2回合伤害", color = {255, 180, 60} },
        { combo = "4连击", icon = "✡️",   name = "六芒冲击波", desc = "6方向射线贯穿全场，\n秒杀小怪，Boss受60伤害", color = {200, 140, 255} },
        { combo = "5连击", icon = "🩸",  name = "生命虹吸", desc = "吸取全体敌人50%当前生命，\nBoss固定80，溢出转护盾", color = {40, 220, 80} },
        { combo = "6连击", icon = "☄️",   name = "天罚陨石", desc = "主角周围4格陨石轰炸，\n造成敌人75%当前HP伤害", color = {255, 100, 60} },
        { combo = "7连击",  icon = "💣", name = "末日炸弹", desc = "秒杀全部小怪，\n对Boss造成150伤害", color = {80, 200, 255} },
        { combo = "8连击+", icon = "💣", name = "末日炸弹", desc = "秒杀全部小怪，\n对Boss造成150伤害", color = {80, 200, 255} },
    }

    local rows = {}
    for i, tier in ipairs(comboTiers) do
        rows[#rows + 1] = UI.Panel {
            width = "100%",
            flexDirection = "row",
            alignItems = "center",
            gap = 10,
            paddingTop = 10, paddingBottom = 10,
            paddingLeft = 12, paddingRight = 12,
            backgroundColor = {tier.color[1], tier.color[2], tier.color[3], 20},
            borderRadius = 12,
            children = {
                -- 连击数标签
                UI.Panel {
                    width = 64, height = 32,
                    borderRadius = 16,
                    backgroundColor = {tier.color[1], tier.color[2], tier.color[3], 180},
                    justifyContent = "center", alignItems = "center",
                    flexShrink = 0,
                    children = {
                        UI.Label {
                            text = tier.combo,
                            fontSize = 15, fontWeight = "bold",
                            fontColor = {10, 10, 20, 255},
                        },
                    },
                },
                -- 图标
                UI.Label {
                    text = tier.icon,
                    fontSize = 32,
                    flexShrink = 0,
                },
                -- 名称 + 描述
                UI.Panel {
                    flexGrow = 1, flexShrink = 1,
                    gap = 2,
                    children = {
                        UI.Label {
                            text = tier.name,
                            fontSize = 18, fontWeight = "bold",
                            fontColor = {tier.color[1], tier.color[2], tier.color[3], 255},
                        },
                        UI.Label {
                            text = tier.desc,
                            fontSize = 14,
                            fontColor = {200, 215, 225, 220},
                        },
                    },
                },
            },
        }
    end

    -- 移除旧弹窗
    if G.comboTutorialPopup then
        G.comboTutorialPopup:Remove()
        G.comboTutorialPopup = nil
    end

    -- 手动构建 children 数组，避免 table.unpack 位置陷阱
    local cardChildren = {
        -- 标题
        UI.Label {
            text = "连击奖励",
            fontSize = 30, fontWeight = "bold",
            fontColor = ac,
            textAlign = "center",
        },
        -- 副标题
        UI.Label {
            text = "连续跳杀敌人，触发强力COMBO！",
            fontSize = 16,
            fontColor = {200, 210, 220, 190},
            textAlign = "center",
            marginBottom = 6,
        },
        -- 分割线
        UI.Panel {
            width = 70, height = 2,
            backgroundColor = {ac[1], ac[2], ac[3], 100},
            alignSelf = "center", borderRadius = 1,
            marginBottom = 6,
        },
    }
    -- 各连击等级
    for _, row in ipairs(rows) do
        cardChildren[#cardChildren + 1] = row
    end
    -- "知道了"按钮
    cardChildren[#cardChildren + 1] = UI.Panel {
        width = "100%",
        alignItems = "center",
        marginTop = 8,
        children = {
            UI.Button {
                text = "知道了！",
                variant = "primary",
                width = 180, height = 48, fontSize = 20,
                fontWeight = "bold",
                borderRadius = 21,
                backgroundGradient = {
                    type = "linear", direction = "to-bottom",
                    from = {255, 210, 70, 255},
                    to = {230, 170, 30, 255},
                },
                fontColor = {10, 10, 20, 255},
                onClick = function(self)
                    AM.PlaySFX("ui_popup_close")
                    if G.comboTutorialPopup then
                        G.comboTutorialPopup:SetVisible(false)
                    end
                    if onClose then onClose() end
                end,
            },
        },
    }

    G.comboTutorialPopup = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center", alignItems = "center",
        backgroundColor = {0, 0, 0, 180},
        backdropBlur = 4,
        zIndex = 800,
        children = {
            UI.Panel {
                width = "92%", maxWidth = 400,
                backgroundGradient = {
                    type = "linear", direction = "to-bottom",
                    from = {30, 35, 45, 250}, to = {15, 20, 28, 250},
                },
                borderRadius = 18,
                borderWidth = 1.5,
                borderColor = {ac[1], ac[2], ac[3], 100},
                paddingTop = 22, paddingBottom = 22,
                paddingLeft = 18, paddingRight = 18,
                gap = 8,
                alignItems = "center",
                children = cardChildren,
            },
        },
    }

    UI.GetRoot():AddChild(G.comboTutorialPopup)
end

--- 连击聚光灯教学（首次打出某个连击等级时，聚焦英雄位置展示说明）
---@param info table { tier=number, name=string, desc=string, icon=string }
---@param onClose function
function GameUI.ShowComboSpotlight(info, onClose)
    AM.PlaySFX("ui_popup_open")

    -- 移除旧弹窗
    if G.comboSpotlightPopup then
        G.comboSpotlightPopup:Remove()
        G.comboSpotlightPopup = nil
    end

    -- 设置标志，BoardWidget 渲染时会绘制聚光灯遮罩 + 提示气泡
    G.comboSpotlightActive = info

    -- 透明全屏点击拦截层
    G.comboSpotlightPopup = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 810,
        onClick = function(self)
            AM.PlaySFX("ui_popup_close")
            G.comboSpotlightActive = nil
            if G.comboSpotlightPopup then
                G.comboSpotlightPopup:SetVisible(false)
            end
            if onClose then onClose() end
        end,
    }

    UI.GetRoot():AddChild(G.comboSpotlightPopup)
end

--- 新怪物首次出现介绍弹窗
---@param introList table[] { icon, name, desc, enemyType }[]
function GameUI.ShowEnemyIntro(introList)
    if not introList or #introList == 0 then return end
    AM.PlaySFX("ui_popup_open")

    -- 构建每个怪物的介绍条目
    local rows = {}
    for i, info in ipairs(introList) do
        rows[#rows + 1] = UI.Panel {
            width = "100%",
            flexDirection = "row",
            alignItems = "center",
            paddingTop = 10, paddingBottom = 10,
            paddingLeft = 14, paddingRight = 14,
            backgroundColor = {255, 255, 255, 12},
            borderRadius = 12,
            gap = 12,
            children = {
                -- 怪物图标
                UI.Label {
                    text = info.icon,
                    fontSize = 36,
                    width = 44,
                    textAlign = "center",
                },
                -- 名称 + 机制描述
                UI.Panel {
                    flexShrink = 1, flexGrow = 1,
                    gap = 3,
                    children = {
                        UI.Label {
                            text = info.name,
                            fontSize = 20, fontWeight = "bold",
                            fontColor = {255, 220, 130, 255},
                        },
                        UI.Label {
                            text = info.desc,
                            fontSize = 15,
                            fontColor = {200, 210, 230, 220},
                        },
                    },
                },
            },
        }
    end

    -- 关闭按钮
    rows[#rows + 1] = UI.Button {
        text = "知道了",
        variant = "primary",
        width = 140, height = 42, fontSize = 17,
        fontWeight = "bold",
        borderRadius = 21,
        backgroundGradient = {
            type = "linear", direction = "to-bottom",
            from = {80, 140, 220, 255}, to = {50, 100, 180, 255},
        },
        fontColor = {255, 255, 255, 255},
        marginTop = 6,
        onClick = function(self)
            AM.PlaySFX("ui_popup_close")
            if G.enemyIntroPopup then
                G.enemyIntroPopup:SetVisible(false)
            end
        end,
    }

    -- 移除旧弹窗
    if G.enemyIntroPopup then
        G.enemyIntroPopup:Remove()
        G.enemyIntroPopup = nil
    end

    local title = #introList == 1
        and "新敌人出现！"
        or string.format("%d种新敌人出现！", #introList)

    -- 构建 children（避免 table.unpack 展开陷阱）
    local contentChildren = {
        -- 标题
        UI.Label {
            text = "⚠️ " .. title,
            fontSize = 22, fontWeight = "bold",
            fontColor = {255, 200, 80, 255},
            textAlign = "center",
            marginBottom = 4,
        },
        -- 分割线
        UI.Panel {
            width = 60, height = 2.5,
            backgroundColor = {255, 180, 80, 100},
            borderRadius = 1,
            marginBottom = 6,
        },
    }
    for _, row in ipairs(rows) do
        contentChildren[#contentChildren + 1] = row
    end

    G.enemyIntroPopup = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center", alignItems = "center",
        backgroundColor = {0, 0, 0, 150},
        backdropBlur = 3,
        zIndex = 750,
        children = {
            UI.Panel {
                width = "85%", maxWidth = 340,
                backgroundGradient = {
                    type = "linear", direction = "to-bottom",
                    from = {30, 35, 55, 245}, to = {18, 22, 38, 245},
                },
                borderRadius = 16,
                borderWidth = 1.5,
                borderColor = {255, 180, 80, 80},
                paddingTop = 20, paddingBottom = 20,
                paddingLeft = 18, paddingRight = 18,
                gap = 10,
                alignItems = "center",
                children = contentChildren,
            },
        },
    }
    UI.GetRoot():AddChild(G.enemyIntroPopup)
end

--- 二连跳教程（聚光灯高亮样式）
--- 遮罩和高亮由 BoardWidget 的 NanoVG 渲染完成，这里只放透明点击拦截层
function GameUI.ShowChainJumpSpotlight(onClose)
    AM.PlaySFX("ui_popup_open")

    -- 移除旧弹窗
    if G.chainJumpTutorialPopup then
        G.chainJumpTutorialPopup:Remove()
        G.chainJumpTutorialPopup = nil
    end

    -- 透明全屏点击拦截层
    -- 只有点击首跳的落点格子才关闭教程并执行跳跃
    G.chainJumpTutorialPopup = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 810,
        onClick = function(self, event)
            local jump = G.chainJumpSpotlightJump1
            if not jump then return end

            local hitLanding = false
            if G.gridParams and G.boardWidgetRef and event then
                local boardWidget = G.boardWidgetRef
                local bl = boardWidget:GetAbsoluteLayout()
                local localX = event.x - bl.x + (G.cameraX or 0)
                local localY = event.y - bl.y + (G.cameraY or 0)
                local col, row = HexGrid.PixelToHex(localX, localY, G.gridParams)
                if col and row and col == jump.col and row == jump.row then
                    hitLanding = true
                end
            end

            if hitLanding then
                AM.PlaySFX("ui_popup_close")
                if G.chainJumpTutorialPopup then
                    G.chainJumpTutorialPopup:SetVisible(false)
                end
                if onClose then onClose() end
                -- 转发点击到棋盘执行跳跃
                if G.callbacks and G.callbacks.HandleCellClick then
                    G.callbacks.HandleCellClick(jump.col, jump.row)
                end
            end
        end,
    }

    UI.GetRoot():AddChild(G.chainJumpTutorialPopup)
end

--- 多格跳跃教程（聚光灯高亮样式）
--- 遮罩和高亮由 BoardWidget 的 NanoVG 渲染完成，这里只放透明点击拦截层
function GameUI.ShowMultiHopTutorial(onClose)
    AM.PlaySFX("ui_popup_open")

    -- 移除旧弹窗
    if G.multiHopTutorialPopup then
        G.multiHopTutorialPopup:Remove()
        G.multiHopTutorialPopup = nil
    end

    -- 透明全屏点击拦截层
    -- 只有点击高亮终点格子才关闭教程并执行跳跃，其他位置不响应
    G.multiHopTutorialPopup = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 810,
        onClick = function(self, event)
            -- 获取点击坐标，判断是否点击了终点格子
            local jump = G.multiHopSpotlightJump
            if not jump then return end

            local hitLanding = false
            if G.gridParams and G.boardWidgetRef and event then
                -- 使用与 BoardWidget:HandleClick 完全一致的坐标转换
                -- event.x/y 是物理像素坐标（UI系统已处理），与 GetAbsoluteLayout 同一坐标空间
                local boardWidget = G.boardWidgetRef
                local bl = boardWidget:GetAbsoluteLayout()
                local localX = event.x - bl.x + (G.cameraX or 0)
                local localY = event.y - bl.y + (G.cameraY or 0)
                local col, row = HexGrid.PixelToHex(localX, localY, G.gridParams)
                if col and row and col == jump.col and row == jump.row then
                    hitLanding = true
                end
            end

            if hitLanding then
                -- 点击了终点格子：关闭教程并执行跳跃
                AM.PlaySFX("ui_popup_close")
                if G.multiHopTutorialPopup then
                    G.multiHopTutorialPopup:SetVisible(false)
                end
                if onClose then onClose() end
                -- 转发点击到棋盘执行跳跃
                if G.callbacks and G.callbacks.HandleCellClick then
                    G.callbacks.HandleCellClick(jump.col, jump.row)
                end
            end
            -- 点击其他位置：不做任何反应，教程保持打开
        end,
    }

    UI.GetRoot():AddChild(G.multiHopTutorialPopup)
end

-- ============================================================================
-- 教程指南系统（可翻页，覆盖全部教学、敌人、机制介绍）
-- ============================================================================

--- 教程指南页面数据
local TUTORIAL_PAGES = {
    -- ========== Page 1: 基础操作 ==========
    {
        title = "基础操作",
        accent = {70, 150, 230},
        icon = "⚔️",
        entries = {
            { emoji = "🔵  👉  ⬜",  text = "点击相邻空格移动英雄" },
            { emoji = "🔵 ⚔️ 🔴 💥", text = "跳过敌人造成伤害（消耗行动点）" },
            { emoji = "💥💥💥 ➡️ 🌟", text = "连续跳杀触发COMBO奖励" },
            { emoji = "💊  💰  🛡️",  text = "路上可拾取血瓶、金币、护盾" },
            { emoji = "⏭️  🔴  ⚔️",  text = "行动点耗尽后轮到敌人行动" },
            { emoji = "🏆  ⚔️  🔢",  text = "击杀足够敌人即可通关" },
        },
    },
    -- ========== Page 2: 道具与连击 ==========
    {
        title = "道具与连击",
        accent = {220, 180, 50},
        icon = "🎁",
        entries = {
            { emoji = "💊", text = "小血瓶 — 回复20HP", isSeparator = false },
            { emoji = "💖", text = "大血瓶 — 回满HP（稀有）" },
            { emoji = "💰", text = "金币袋 — 获得8金币" },
            { emoji = "🛡️", text = "护盾 — 下次受击伤害减半" },
            { separator = true, text = "── 连击奖励 ──" },
            { emoji = "2️⃣", text = "追踪飞镖 — 追踪敌人50伤害或拾取道具" },
            { emoji = "3️⃣", text = "稻草人 — 吸引仇恨替挡2回合" },
            { emoji = "4️⃣", text = "六芒冲击波 — 6方向秒杀小怪，Boss受60伤害" },
            { emoji = "5️⃣", text = "生命虹吸 — 吸取全体生命，溢出转护盾" },
            { emoji = "6️⃣", text = "天罚陨石 — 主角周围4格陨石轰炸" },
            { emoji = "7️⃣", text = "末日炸弹 — 秒杀小怪+Boss受150伤害" },
        },
    },
    -- ========== Page 3: 海洋怪物 ==========
    {
        title = "深渊海沟·怪物",
        accent = {50, 180, 210},
        icon = "🌊",
        entries = {
            { emoji = "👾", text = "史莱姆 — HP25 ATK6 | 基础近战敌人" },
            { emoji = "💀", text = "骷髅兵 — HP40 ATK12 | 射程2，投骨远攻" },
            { emoji = "🎐", text = "电水母 — HP28 ATK10 | 反伤6：攻击它会被电" },
            { emoji = "🐢", text = "铁甲龟 — HP55 ATK11 | 防御5：减免所有伤害" },
            { emoji = "🌀", text = "漩涡鳗 — HP35 ATK12 | 死亡时搅乱棋盘" },
            { emoji = "🦈", text = "幽灵鲨 — HP22 ATK14 | 瞬移：会随机传送" },
            { emoji = "🐠", text = "射水鱼 — HP18 ATK11 | 射程2+逃跑：保持距离" },
            { emoji = "⚡", text = "电鳐 — HP40 ATK9 | AOE放电：伤害周围全部" },
            { emoji = "🐚", text = "寄居蟹 — HP38 ATK9 | 缩壳：受击时缩入壳中减伤" },
        },
    },
    -- ========== Page 4: 炎魔怪物 ==========
    {
        title = "炎魔祭坛·怪物",
        accent = {230, 120, 50},
        icon = "🔥",
        entries = {
            { emoji = "🔥", text = "火灵 — HP22 ATK8 | 灼烧：跳过它会持续掉血2回合" },
            { emoji = "🗿", text = "熔岩巨人 — HP55 ATK14 | 死亡留岩浆：每回合8伤害" },
            { emoji = "🍄", text = "毒蘑菇 — HP18 ATK0 | 死亡爆炸：对周围造成8伤害" },
            { emoji = "✨", text = "裂焰精 — HP28 ATK8 | 分裂：死亡时变成两个焰碎片" },
            { emoji = "💥", text = "焰碎片 — HP10 ATK5 | 碎片：裂焰精死后的分裂体" },
            { separator = true, text = "── 特殊机制 ──" },
            { emoji = "🔥", text = "炎魔祭坛 — 给周围敌人套护盾，移动到祭坛可摧毁" },
        },
    },
    -- ========== Page 5: 珊瑚怪物 ==========
    {
        title = "珊瑚迷宫·怪物",
        accent = {210, 100, 170},
        icon = "🪸",
        entries = {
            { emoji = "🦞", text = "珊瑚夹 — HP28 ATK9 | 基础近战" },
            { emoji = "🌰", text = "海胆 — HP18 ATK6 | 反伤6：近战攻击它会受伤" },
            { emoji = "⭐", text = "礁石海星 — HP20 ATK5 | 回血4：每回合恢复生命" },
            { emoji = "🌺", text = "棘刺海葵 — HP22 ATK7 | 射程3+逃跑：远程狙击" },
            { emoji = "🧙", text = "珊瑚祭司 — HP25 ATK0 | 辅助：治疗6HP+强化ATK3" },
            { separator = true, text = "── 特殊机制 ──" },
            { emoji = "🦀", text = "珊瑚迷宫 — 清除障碍打通道路，帮助小蟹回家" },
        },
    },
    -- ========== Page 6 (新): 无尽模式·特殊怪 ==========
    {
        title = "无尽模式·特殊怪",
        accent = {160, 80, 220},
        icon = "🌀",
        entries = {
            { emoji = "💨", text = "疾梭鱼 — 每回合移动3格：出现即急速逼近" },
            { emoji = "💜", text = "魅惑水母 — 靠近2格触发魅惑：英雄跳过下一回合" },
            { separator = true, text = "── 无尽模式 ──" },
            { emoji = "🌀", text = "每波击杀目标递增，难度持续提升" },
            { emoji = "⭐", text = "每3波出现精英怪（⭐标记），HP与ATK大幅强化" },
            { emoji = "🏆", text = "无尽坚持越久，排行榜名次越高" },
        },
    },
    -- ========== Page 6: Boss 图鉴 ==========
    {
        title = "Boss 图鉴",
        accent = {200, 60, 70},
        icon = "👑",
        entries = {
            { separator = true, text = "── 深渊海沟 Boss ──" },
            { emoji = "🐙", text = "深渊海妖 — HP450 ATK25 | 护盾60" },
            { emoji = "🦑", text = "触手重击 — 近距离猛力横扫，重击伤害×2.2" },
            { emoji = "☠️", text = "深渊喷毒 — 中距喷射毒液，附加3~4回合持续中毒" },
            { emoji = "🌊", text = "漩涡牵引 — 将你拉向Boss并造成伤害" },
            { emoji = "🕳️", text = "深渊收缩 — 棋盘边缘崩塌，可活动范围缩小" },
            { separator = true, text = "── 熔岩祭坛 Boss ──" },
            { emoji = "🌋", text = "熔岩领主 — HP280 ATK22 | 护盾50" },
            { emoji = "🔥", text = "熔岩重拳 — 近身砸落，英雄脚下留下持续灼烧地形" },
            { emoji = "💥", text = "火焰弹射 — 精准射出火球，周边3格溅射熔岩" },
            { emoji = "🌋", text = "熔岩喷发 — 随机区域喷出岩浆，踩到持续灼烧" },
            { separator = true, text = "── 珊瑚迷宫 Boss ──" },
            { emoji = "🪸", text = "珊瑚守卫 — HP320 ATK20 | 护盾55" },
            { emoji = "⚡", text = "珊瑚刺击 — 近身贯穿刺击，附加2~3回合中毒" },
            { emoji = "🪸", text = "珊瑚投掷 — 砸出巨石，碎片封堵退路" },
            { emoji = "🌊", text = "潮汐冲击 — 汹涌冲击将你推离，途经格受伤" },
            { separator = true, text = "── Boss 通用机制 ──" },
            { emoji = "🛡️", text = "Boss护盾 — 每阶段恢复护盾，必须先击破" },
            { emoji = "😡", text = "狂暴阶段 — HP低于50%进入狂暴，技能CD缩短" },
            { emoji = "💡", text = "技能预警 — 蓄力气泡提示下回合技能，提前规避" },
        },
    },
}

--- 生成单个条目卡片
---@param entry table
---@param idx number
---@param accent table
---@return UIElement
local function MakeTutorialEntry(entry, idx, accent)
    -- 分隔线
    if entry.separator then
        return UI.Panel {
            width = "100%",
            alignItems = "center",
            marginTop = 8, marginBottom = 4,
            children = {
                UI.Label {
                    text = entry.text,
                    fontSize = 14,
                    fontColor = {accent[1], accent[2], accent[3], 160},
                    textAlign = "center",
                },
            },
        }
    end
    -- 普通条目
    return UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        gap = 10,
        paddingTop = 7, paddingBottom = 7,
        paddingLeft = 10, paddingRight = 10,
        backgroundColor = {20, 28, 42, 220},
        borderRadius = 10,
        children = {
            -- 左侧emoji
            UI.Label {
                text = entry.emoji or "",
                fontSize = 26,
                width = 36,
                textAlign = "center",
                flexShrink = 0,
            },
            -- 右侧文本
            UI.Label {
                text = entry.text or "",
                fontSize = 15,
                fontColor = {210, 220, 235, 230},
                flexGrow = 1, flexShrink = 1,
                numberOfLines = 2,
            },
        },
    }
end

--- 构建指定页面的内容 children 列表
---@param pageIdx number
---@return table children
---@return table accent
local function BuildTutorialPageContent(pageIdx)
    local page = TUTORIAL_PAGES[pageIdx]
    if not page then return {}, {100, 100, 100} end
    local ac = page.accent
    local totalPages = #TUTORIAL_PAGES
    local children = {}

    -- 顶栏: 页码指示器 + 关闭按钮
    children[#children + 1] = UI.Panel {
        width = "100%",
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        marginBottom = 4,
        children = {
            -- 左侧占位
            UI.Panel { width = 32, height = 32 },
            -- 页码标签
            UI.Label {
                text = page.icon .. "  " .. page.title,
                fontSize = 22, fontWeight = "bold",
                fontColor = {ac[1], ac[2], ac[3], 255},
                textAlign = "center",
                flexGrow = 1,
            },
            -- 关闭按钮
            UI.Button {
                text = "X",
                fontSize = 16, fontWeight = "bold",
                width = 32, height = 32,
                borderRadius = 16,
                backgroundColor = {255, 255, 255, 25},
                fontColor = {200, 200, 200, 200},
                pressedBackgroundColor = {255, 80, 80, 100},
                onClick = function(self)
                    AM.PlaySFX("ui_popup_close")
                    if G.tutorialGuidePopup then
                        G.tutorialGuidePopup:SetVisible(false)
                    end
                end,
            },
        },
    }

    -- 分割线
    children[#children + 1] = UI.Panel {
        width = 50, height = 2,
        backgroundColor = {ac[1], ac[2], ac[3], 100},
        alignSelf = "center", borderRadius = 1,
        marginBottom = 6,
    }

    -- 内容条目
    for i, entry in ipairs(page.entries) do
        children[#children + 1] = MakeTutorialEntry(entry, i, ac)
    end

    -- 底部: 页码 + 翻页按钮
    local navChildren = {}
    -- 上一页按钮
    navChildren[#navChildren + 1] = UI.Button {
        text = "◀ 上一页",
        fontSize = 15,
        width = 90, height = 36,
        borderRadius = 16,
        backgroundColor = pageIdx > 1 and {ac[1], ac[2], ac[3], 60} or {80, 80, 80, 40},
        fontColor = pageIdx > 1 and {ac[1], ac[2], ac[3], 240} or {120, 120, 120, 120},
        pressedBackgroundColor = {ac[1], ac[2], ac[3], 120},
        onClick = pageIdx > 1 and function(self)
            AM.PlaySFX("ui_click")
            GameUI.ShowTutorialGuide(pageIdx - 1)
        end or nil,
    }
    -- 页码指示点
    local dotsChildren = {}
    for i = 1, totalPages do
        dotsChildren[#dotsChildren + 1] = UI.Panel {
            width = i == pageIdx and 16 or 8,
            height = 8,
            borderRadius = 4,
            backgroundColor = i == pageIdx
                and {ac[1], ac[2], ac[3], 220}
                or {150, 150, 150, 80},
        }
    end
    navChildren[#navChildren + 1] = UI.Panel {
        flexDirection = "row", gap = 4, alignItems = "center",
        justifyContent = "center", flexGrow = 1,
        children = dotsChildren,
    }
    -- 下一页按钮
    navChildren[#navChildren + 1] = UI.Button {
        text = "下一页 ▶",
        fontSize = 15,
        width = 90, height = 36,
        borderRadius = 16,
        backgroundColor = pageIdx < totalPages and {ac[1], ac[2], ac[3], 60} or {80, 80, 80, 40},
        fontColor = pageIdx < totalPages and {ac[1], ac[2], ac[3], 240} or {120, 120, 120, 120},
        pressedBackgroundColor = {ac[1], ac[2], ac[3], 120},
        onClick = pageIdx < totalPages and function(self)
            AM.PlaySFX("ui_click")
            GameUI.ShowTutorialGuide(pageIdx + 1)
        end or nil,
    }

    children[#children + 1] = UI.Panel {
        width = "100%",
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        marginTop = 10,
        children = navChildren,
    }

    -- 页码文字
    children[#children + 1] = UI.Label {
        text = pageIdx .. " / " .. totalPages,
        fontSize = 14,
        fontColor = {160, 160, 170, 120},
        textAlign = "center",
        alignSelf = "center",
        marginTop = 2,
    }

    return children, ac
end

--- 显示教程指南弹窗（可翻页）
---@param pageIdx? number 起始页码，默认1
function GameUI.ShowTutorialGuide(pageIdx)
    pageIdx = pageIdx or 1
    if pageIdx < 1 then pageIdx = 1 end
    if pageIdx > #TUTORIAL_PAGES then pageIdx = #TUTORIAL_PAGES end

    AM.PlaySFX("ui_popup_open")

    local contentChildren, ac = BuildTutorialPageContent(pageIdx)

    -- 移除旧弹窗
    if G.tutorialGuidePopup then
        G.tutorialGuidePopup:Remove()
        G.tutorialGuidePopup = nil
    end

    G.tutorialGuidePopup = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center", alignItems = "center",
        backgroundColor = {8, 12, 22, 160},
        zIndex = 800,
        onClick = function(self)
            -- 点击遮罩关闭
            AM.PlaySFX("ui_popup_close")
            if G.tutorialGuidePopup then
                G.tutorialGuidePopup:SetVisible(false)
            end
        end,
        children = {
            UI.Panel {
                width = "90%", maxWidth = 420,
                maxHeight = "85%",
                backgroundGradient = {
                    type = "linear", direction = "to-bottom",
                    from = {25, 35, 50, 255}, to = {15, 20, 32, 255},
                },
                borderRadius = 18,
                borderWidth = 2,
                borderColor = {ac[1], ac[2], ac[3], 180},
                paddingTop = 16, paddingBottom = 14,
                paddingLeft = 14, paddingRight = 14,
                gap = 3,
                alignItems = "center",
                overflow = "scroll",
                boxShadow = {
                    { x = 0, y = 4, blur = 20, spread = 0, color = {0, 0, 0, 120} },
                    { x = 0, y = 0, blur = 30, spread = 5, color = {ac[1], ac[2], ac[3], 25} },
                },
                onClick = function(self)
                    -- 阻止事件冒泡到遮罩层
                end,
                children = contentChildren,
            },
        },
    }

    UI.GetRoot():AddChild(G.tutorialGuidePopup)
end

return GameUI
