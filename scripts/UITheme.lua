-- ============================================================================
-- UITheme - 全局 UI 主题与缩放配置
--
-- 视觉重制期间，颜色、字体、圆角和组件默认样式只在这里维护。
-- 业务界面不应再自行复制全局主题令牌。
-- ============================================================================

local UITheme = {}

UITheme.DESIGN_SHORT_SIDE = 480

UITheme.COLORS = {
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
}

local PIXEL_SHADOW = {
    { x = 3, y = 3, blur = 0, color = {10, 10, 26, 204} },
    { x = -1, y = -1, blur = 0, color = {255, 255, 255, 48} },
}

local function BuildTheme(UI)
    return UI.Theme.ExtendTheme(UI.Theme.defaultTheme, {
        colors = UITheme.COLORS,
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
                borderWidth = 2,
                thumbSize = 18,
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
                accentBarHeight = 32,
                accentBarWidth = 4,
                accentBarInset = 12,
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
end

function UITheme.Init(UI)
    UI.Init({
        theme = BuildTheme(UI),
        fonts = {
            { family = "sans", weights = {
                normal = "Fonts/FusionPixel-12px-Prop-zh_hans.ttf",
                bold = "Fonts/FusionPixel-12px-Prop-zh_hans-Bold.ttf",
            } },
            { family = "mono", weights = {
                normal = "Fonts/FusionPixel-12px-Mono-zh_hans.ttf",
            } },
        },
        scale = UI.Scale.DESIGN_SHORT_SIDE(UITheme.DESIGN_SHORT_SIDE),
    })
end

return UITheme
