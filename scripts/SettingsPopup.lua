---@diagnostic disable: assign-type-mismatch
-- ============================================================================
-- SettingsPopup - BGM 音量调节 + 切歌弹窗
-- ============================================================================

local UI = require("urhox-libs/UI")
local AM = require "AudioManager"
local G  = require "GameState"


local SettingsPopup = {}

-- BGM 显示名映射
local BGM_NAMES = {
    menu           = "主菜单",
    battle_calm    = "深海漫游",
    battle         = "激烈战斗",
    boss           = "Boss 战",
    boss_lava      = "熔岩领主",
    boss_abyss     = "深渊海妖",
    boss_coral     = "珊瑚守卫",
    battle_endless = "无尽深渊",
}

-- 可切换的 BGM 列表（按顺序）
local BGM_KEYS = { "menu", "battle_calm", "battle", "boss", "boss_lava", "boss_abyss", "boss_coral", "battle_endless" }

--- 弹窗引用
local popupRoot = nil

--- 关闭弹窗
function SettingsPopup.Close()
    if popupRoot then
        popupRoot:SetVisible(false)
    end
    AM.PlaySFX("ui_popup_close")
end

--- 显示设置弹窗（挂载到当前 UI 根节点）
function SettingsPopup.Show()
    AM.PlaySFX("ui_popup_open")

    -- 如果已存在，先移除旧的
    if popupRoot then
        popupRoot:Remove()
        popupRoot = nil
    end

    local currentBGM = AM.GetCurrentBGM()
    local bgmName = BGM_NAMES[currentBGM] or currentBGM or "无"

    -- BGM 音量百分比 (0~100)
    local bgmPct = math.floor(AM.bgmVolume * 100 / 0.5 + 0.5) -- 0.5 为最大音量
    bgmPct = math.min(100, math.max(0, bgmPct))
    local sfxPct = math.floor(AM.sfxVolume * 100 + 0.5)
    sfxPct = math.min(100, math.max(0, sfxPct))

    ---@type UIElement
    local bgmNameLabel = nil
    ---@type UIElement
    local bgmVolLabel = nil
    ---@type UIElement
    local sfxVolLabel = nil

    popupRoot = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center", alignItems = "center",
        backgroundColor = {0, 0, 0, 150},
        backdropBlur = 4,
        zIndex = 900,
        onClick = function(self)
            SettingsPopup.Close()
        end,
        children = {
            UI.Panel {
                width = "82%", maxWidth = 320,
                maxHeight = "88%",
                overflowY = "scroll",
                backgroundGradient = {
                    type = "linear", direction = "to-bottom",
                    from = {38, 32, 68, 255}, to = {22, 18, 45, 255},
                },
                borderRadius = 0,
                borderWidth = 1.5,
                borderColor = {90, 70, 160, 150},
                paddingTop = 20, paddingBottom = 20,
                paddingLeft = 22, paddingRight = 22,
                gap = 16,
                boxShadow = {
                    { x = 0, y = 4, blur = 20, spread = 0, color = {0, 0, 0, 120} },
                },
                onClick = function(self) end, -- 阻止点击穿透
                children = {
                    -- 标题
                    UI.Label {
                        text = "⚙ 设置",
                        fontSize = 24, fontWeight = "bold",
                        fontColor = {230, 225, 255, 255},
                        textAlign = "center", width = "100%",
                        textShadow = { offsetX = 0, offsetY = 1, blur = 3, color = {0, 0, 0, 80} },
                    },

                    -- 分隔线
                    UI.Panel {
                        width = "100%", height = 1,
                        backgroundColor = {80, 65, 140, 80},
                    },

                    -- ====== BGM 音量 ======
                    UI.Panel {
                        width = "100%", gap = 8,
                        children = {
                            UI.Panel {
                                width = "100%",
                                flexDirection = "row", justifyContent = "space-between", alignItems = "center",
                                children = {
                                    UI.Label {
                                        text = "🎵 BGM 音量",
                                        fontSize = 17, fontColor = {200, 195, 230, 255},
                                    },
                                    (function()
                                        bgmVolLabel = UI.Label {
                                            text = bgmPct .. "%",
                                            fontSize = 16, fontColor = {160, 155, 200, 200},
                                        }
                                        return bgmVolLabel
                                    end)(),
                                },
                            },
                            UI.Slider {
                                value = bgmPct,
                                min = 0, max = 100, step = 5,
                                width = "100%",
                                trackHeight = 5,
                                thumbSize = 20,
                                trackColor = {50, 42, 90, 255},
                                activeTrackColor = {130, 100, 220, 255},
                                thumbColor = {180, 160, 255, 255},
                                onChange = function(self, v)
                                    local vol = v / 100 * 0.5  -- 最大 0.5
                                    AM.SetBGMVolume(vol)
                                    if bgmVolLabel then
                                        bgmVolLabel:SetText(math.floor(v + 0.5) .. "%")
                                    end
                                end,
                            },
                        },
                    },

                    -- ====== SFX 音量 ======
                    UI.Panel {
                        width = "100%", gap = 8,
                        children = {
                            UI.Panel {
                                width = "100%",
                                flexDirection = "row", justifyContent = "space-between", alignItems = "center",
                                children = {
                                    UI.Label {
                                        text = "🔊 音效音量",
                                        fontSize = 17, fontColor = {200, 195, 230, 255},
                                    },
                                    (function()
                                        sfxVolLabel = UI.Label {
                                            text = sfxPct .. "%",
                                            fontSize = 16, fontColor = {160, 155, 200, 200},
                                        }
                                        return sfxVolLabel
                                    end)(),
                                },
                            },
                            UI.Slider {
                                value = sfxPct,
                                min = 0, max = 100, step = 5,
                                width = "100%",
                                trackHeight = 5,
                                thumbSize = 20,
                                trackColor = {50, 42, 90, 255},
                                activeTrackColor = {130, 100, 220, 255},
                                thumbColor = {180, 160, 255, 255},
                                onChange = function(self, v)
                                    local vol = v / 100
                                    AM.SetSFXVolume(vol)
                                    if sfxVolLabel then
                                        sfxVolLabel:SetText(math.floor(v + 0.5) .. "%")
                                    end
                                end,
                            },
                        },
                    },

                    -- ====== 连跳音效风格 ======
                    UI.Panel {
                        width = "100%", gap = 8,
                        children = {
                            UI.Label {
                                text = "🎹 连跳音效",
                                fontSize = 17, fontColor = {200, 195, 230, 255},
                            },
                            UI.Panel {
                                width = "100%",
                                flexDirection = "row", gap = 8,
                                children = (function()
                                    local styles = {
                                        { key = "scale",   label = "音阶递进" },
                                        { key = "classic", label = "经典跳跃" },
                                    }
                                    local btns = {}
                                    local btnByKey = {}
                                    for _, s in ipairs(styles) do
                                        local isActive = (AM.comboSoundStyle == s.key)
                                        local btn = UI.Button {
                                            text = s.label,
                                            fontSize = 16,
                                            flexGrow = 1,
                                            paddingTop = 7, paddingBottom = 7,
                                            borderRadius = 0,
                                            borderWidth = 1,
                                            borderColor = isActive
                                                and {255, 200, 60, 200}
                                                or  {80, 65, 140, 120},
                                            backgroundColor = isActive
                                                and {60, 45, 110, 255}
                                                or  {35, 28, 65, 255},
                                            fontColor = isActive
                                                and {255, 220, 80, 255}
                                                or  {170, 165, 200, 220},
                                            pressedBackgroundColor = {55, 42, 100, 255},
                                            onClick = function(self)
                                                AM.comboSoundStyle = s.key
                                                for _, st in ipairs(styles) do
                                                    local b = btnByKey[st.key]
                                                    if b then
                                                        local active = (st.key == s.key)
                                                        b:SetStyle({
                                                            borderColor = active
                                                                and {255, 200, 60, 200}
                                                                or  {80, 65, 140, 120},
                                                            backgroundColor = active
                                                                and {60, 45, 110, 255}
                                                                or  {35, 28, 65, 255},
                                                            fontColor = active
                                                                and {255, 220, 80, 255}
                                                                or  {170, 165, 200, 220},
                                                        })
                                                    end
                                                end
                                                AM.PlaySFX("ui_click")
                                            end,
                                        }
                                        btns[#btns + 1] = btn
                                        btnByKey[s.key] = btn
                                    end
                                    return btns
                                end)(),
                            },
                        },
                    },

                    -- 分隔线
                    UI.Panel {
                        width = "100%", height = 1,
                        backgroundColor = {80, 65, 140, 80},
                    },

                    -- ====== 切歌 ======
                    UI.Panel {
                        width = "100%", gap = 10,
                        children = {
                            UI.Panel {
                                width = "100%",
                                flexDirection = "row", justifyContent = "space-between", alignItems = "center",
                                children = {
                                    UI.Label {
                                        text = "🎶 当前曲目",
                                        fontSize = 17, fontColor = {200, 195, 230, 255},
                                    },
                                    (function()
                                        bgmNameLabel = UI.Label {
                                            text = bgmName,
                                            fontSize = 16, fontColor = {255, 220, 80, 230},
                                            fontWeight = "bold",
                                        }
                                        return bgmNameLabel
                                    end)(),
                                },
                            },
                            -- 曲目按钮列表
                            UI.Panel {
                                width = "100%",
                                flexDirection = "row", flexWrap = "wrap",
                                gap = 8,
                                children = (function()
                                    local btns = {}
                                    local btnByKey = {}
                                    for _, key in ipairs(BGM_KEYS) do
                                        local isActive = (key == currentBGM)
                                        local btn = UI.Button {
                                            text = BGM_NAMES[key] or key,
                                            fontSize = 16,
                                            paddingLeft = 12, paddingRight = 12,
                                            paddingTop = 7, paddingBottom = 7,
                                            borderRadius = 0,
                                            borderWidth = 1,
                                            borderColor = isActive
                                                and {255, 200, 60, 200}
                                                or  {80, 65, 140, 120},
                                            backgroundColor = isActive
                                                and {60, 45, 110, 255}
                                                or  {35, 28, 65, 255},
                                            fontColor = isActive
                                                and {255, 220, 80, 255}
                                                or  {170, 165, 200, 220},
                                            pressedBackgroundColor = {55, 42, 100, 255},
                                            onClick = function(self)
                                                AM.PlayBGM(key)
                                                if bgmNameLabel then
                                                    bgmNameLabel:SetText(BGM_NAMES[key] or key)
                                                end
                                                -- 更新所有按钮高亮状态
                                                for _, k in ipairs(BGM_KEYS) do
                                                    local b = btnByKey[k]
                                                    if b then
                                                        local active = (k == key)
                                                        b:SetStyle({
                                                            borderColor = active
                                                                and {255, 200, 60, 200}
                                                                or  {80, 65, 140, 120},
                                                            backgroundColor = active
                                                                and {60, 45, 110, 255}
                                                                or  {35, 28, 65, 255},
                                                            fontColor = active
                                                                and {255, 220, 80, 255}
                                                                or  {170, 165, 200, 220},
                                                        })
                                                    end
                                                end
                                                AM.PlaySFX("ui_click")
                                            end,
                                        }
                                        btns[#btns + 1] = btn
                                        btnByKey[key] = btn
                                    end
                                    return btns
                                end)(),
                            },
                        },
                    },

                    -- 关闭按钮
                    UI.Button {
                        text = "关闭",
                        fontSize = 19, fontWeight = "bold",
                        width = "100%", height = 42,
                        borderRadius = 0,
                        backgroundGradient = {
                            type = "linear", direction = "to-bottom",
                            from = {70, 55, 130, 255}, to = {45, 35, 90, 255},
                        },
                        fontColor = {220, 215, 245, 255},
                        borderWidth = 1,
                        borderColor = {100, 80, 170, 130},
                        pressedBackgroundColor = {55, 40, 100, 255},
                        onClick = function(self)
                            SettingsPopup.Close()
                        end,
                    },
                },
            },
        },
    }

    -- 挂载到当前 UI root
    local root = UI.GetRoot()
    if root then
        root:AddChild(popupRoot)
    end
end

return SettingsPopup
