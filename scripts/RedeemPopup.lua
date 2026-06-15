---@diagnostic disable: param-type-mismatch, assign-type-mismatch
-- ============================================================================
-- RedeemPopup.lua - 兑换码系统
-- 点击右上角金币栏触发，支持键盘输入兑换码，发放金币奖励
-- ============================================================================

local UI  = require("urhox-libs/UI")
local AM  = require "AudioManager"
local G   = require "GameState"
local PD  = require "PlayerData"

local RedeemPopup = {}

-- ============================================================================
-- 兑换码表（在此添加/管理你的兑换码）
-- key   = 兑换码（大小写不敏感，玩家输入时自动转大写比较）
-- gold  = 奖励金币数量
-- desc  = 奖励描述（显示给玩家）
-- limit = 总使用次数上限（nil = 不限；1 = 只能全服用1次，但本项目无服务端，此处做客户端单设备防重用）
-- ============================================================================
local CODES = {
    ["COMBOMASTER"] = { gold = 2400, desc = "连击大师" },
    ["COMBOLEGEND"] = { gold = 50000, desc = "连击传奇" },
}

-- 弹窗引用
local popupRoot   = nil
---@type UIElement
local inputWidget = nil
---@type UIElement
local statusLabel = nil
---@type UIElement
local redeemBtn   = nil

-- 状态颜色
local COLOR_HINT    = {160, 155, 210, 180}
local COLOR_SUCCESS = {80,  220, 120, 255}
local COLOR_ERROR   = {255, 100, 90,  255}
local COLOR_USED    = {220, 180, 60,  200}

--- 关闭弹窗
function RedeemPopup.Close()
    if popupRoot then
        popupRoot:SetVisible(false)
    end
    AM.PlaySFX("ui_popup_close")
end

--- 尝试兑换
local function doRedeem()
    if not inputWidget or not statusLabel then return end

    -- 获取输入值
    local raw   = inputWidget:GetValue() or ""
    local code  = raw:match("^%s*(.-)%s*$"):upper()  -- 去首尾空格并转大写

    if code == "" then
        statusLabel:SetText("请输入兑换码")
        statusLabel:SetStyle({ fontColor = COLOR_ERROR })
        return
    end

    -- 检查兑换码是否存在
    local info = CODES[code]
    if not info then
        statusLabel:SetText("❌ 无效的兑换码")
        statusLabel:SetStyle({ fontColor = COLOR_ERROR })
        AM.PlaySFX("ui_error")
        return
    end

    -- 检查是否已使用过（存入 playerData）
    local data = G.playerData
    if not data then
        statusLabel:SetText("❌ 数据未初始化")
        statusLabel:SetStyle({ fontColor = COLOR_ERROR })
        return
    end

    if not data.usedCodes then data.usedCodes = {} end

    if data.usedCodes[code] then
        statusLabel:SetText("⚠️ 此兑换码已使用过")
        statusLabel:SetStyle({ fontColor = COLOR_USED })
        AM.PlaySFX("ui_error")
        return
    end

    -- 兑换成功
    data.usedCodes[code] = true
    PD.AddGold(data, info.gold)
    PD.Save(data)

    -- 更新菜单金币显示
    if G.menuGoldLabel then
        G.menuGoldLabel:SetText(tostring(data.gold))
    end

    statusLabel:SetText(string.format("✅ 兑换成功！%s +%d 金币", info.desc, info.gold))
    statusLabel:SetStyle({ fontColor = COLOR_SUCCESS })
    AM.PlaySFX("ui_popup_open")  -- 使用一个正向音效

    -- 禁用输入和按钮，防止重复提交
    if redeemBtn then
        redeemBtn:SetStyle({ opacity = 0.4 })
    end
    if inputWidget then
        inputWidget:SetStyle({ opacity = 0.5 })
    end
end

--- 显示兑换码弹窗
function RedeemPopup.Show()
    AM.PlaySFX("ui_popup_open")

    -- 已存在则先移除
    if popupRoot then
        popupRoot:Remove()
        popupRoot = nil
        inputWidget = nil
        statusLabel = nil
        redeemBtn   = nil
    end

    popupRoot = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center", alignItems = "center",
        backgroundColor = {0, 0, 0, 160},
        backdropBlur = 5,
        zIndex = 910,
        onClick = function(self)
            RedeemPopup.Close()
        end,
        children = {
            -- 主卡片
            UI.Panel {
                width = "82%", maxWidth = 330,
                backgroundGradient = {
                    type = "linear", direction = "to-bottom",
                    from = {35, 28, 60, 255}, to = {20, 16, 42, 255},
                },
                borderRadius = 0,
                borderWidth = 1.5,
                borderColor = {140, 110, 40, 180},
                paddingTop = 24, paddingBottom = 24,
                paddingLeft = 22, paddingRight = 22,
                gap = 18,
                boxShadow = {
                    { x = 0, y = 6, blur = 24, spread = 0, color = {0, 0, 0, 140} },
                    { x = 0, y = 1, blur = 0,  spread = 0, color = {220, 180, 60, 18}, inset = true },
                },
                onClick = function(self) end,  -- 阻止穿透关闭
                children = {
                    -- 标题行
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row", alignItems = "center", justifyContent = "center",
                        gap = 8,
                        children = {
                            UI.Label {
                                text = "🎁",
                                fontSize = 26,
                            },
                            UI.Label {
                                text = "兑换码",
                                fontSize = 22, fontWeight = "bold",
                                fontColor = {255, 220, 80, 255},
                                textShadow = { offsetX = 0, offsetY = 1, blur = 4, color = {0, 0, 0, 100} },
                            },
                        },
                    },

                    -- 说明文字
                    UI.Label {
                        text = "输入兑换码即可领取金币奖励",
                        fontSize = 14,
                        fontColor = {160, 155, 200, 180},
                        textAlign = "center",
                        width = "100%",
                    },

                    -- 分隔线
                    UI.Panel {
                        width = "100%", height = 1,
                        backgroundColor = {90, 70, 30, 80},
                    },

                    -- 输入框
                    (function()
                        inputWidget = UI.TextField {
                            placeholder = "请输入兑换码…",
                            maxLength = 24,
                            width = "100%",
                            height = 48,
                            fontSize = 18,
                            fontColor = {240, 235, 200, 255},
                            placeholderColor = {120, 115, 160, 140},
                            backgroundColor = {28, 22, 52, 255},
                            borderRadius = 0,
                            borderWidth = 1.5,
                            borderColor = {100, 80, 30, 160},
                            focusBorderColor = {220, 180, 60, 220},
                            paddingLeft = 14, paddingRight = 14,
                            textAlign = "center",
                            onSubmit = function(self, value)
                                doRedeem()
                            end,
                        }
                        return inputWidget
                    end)(),

                    -- 状态提示
                    (function()
                        statusLabel = UI.Label {
                            text = "输入兑换码后点击确认",
                            fontSize = 14,
                            fontColor = COLOR_HINT,
                            textAlign = "center",
                            width = "100%",
                            minHeight = 20,
                        }
                        return statusLabel
                    end)(),

                    -- 按钮行
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row", gap = 10,
                        children = {
                            -- 取消
                            UI.Button {
                                text = "取消",
                                fontSize = 17,
                                flexGrow = 1, height = 44,
                                borderRadius = 0,
                                backgroundColor = {40, 32, 70, 255},
                                borderWidth = 1,
                                borderColor = {80, 65, 130, 120},
                                fontColor = {180, 175, 215, 220},
                                pressedBackgroundColor = {55, 45, 88, 255},
                                onClick = function(self)
                                    RedeemPopup.Close()
                                end,
                            },
                            -- 确认兑换
                            (function()
                                redeemBtn = UI.Button {
                                    text = "✨ 确认兑换",
                                    fontSize = 17, fontWeight = "bold",
                                    flexGrow = 2, height = 44,
                                    borderRadius = 0,
                                    backgroundGradient = {
                                        type = "linear", direction = "to-bottom",
                                        from = {200, 155, 30, 255}, to = {150, 110, 15, 255},
                                    },
                                    fontColor = {40, 30, 5, 255},
                                    borderWidth = 1,
                                    borderColor = {255, 210, 60, 120},
                                    pressedBackgroundColor = {170, 130, 20, 255},
                                    onClick = function(self)
                                        doRedeem()
                                    end,
                                }
                                return redeemBtn
                            end)(),
                        },
                    },
                },
            },
        },
    }

    local root = UI.GetRoot()
    if root then
        root:AddChild(popupRoot)
    end

    -- 触摸设备需要用户点击输入框来激活软键盘（引擎防误触机制）
end

return RedeemPopup
