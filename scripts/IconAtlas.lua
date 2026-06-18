-- ============================================================================
-- IconAtlas - 图标资源统一管理模块
-- 管理所有游戏图标的路径、NanoVG 缓存和绘制
-- ============================================================================

local IconAtlas = {}

-- NanoVG 图标缓存 (handle -> nvgImage handle)
local spriteCache_ = {}

-- ============================================================================
-- 图标路径注册表
-- 路径相对于 assets/ 目录 (资源根目录)
-- ============================================================================

IconAtlas.PATHS = {
    -- === 技能图标 (14) — 64x64 极简像素风 ===
    skill_quake_land       = "image/skill_quake_land_20260601034119.png",
    skill_chain_lightning   = "image/skill_chain_lightning_20260601034121.png",
    skill_vampiric_jump    = "image/skill_vampiric_jump_20260601035305.png",
    skill_thorns           = "image/skill_thorns_20260601034124.png",
    skill_blood_rage       = "image/skill_blood_rage_20260601033158.png",
    skill_gravity_stomp    = "image/skill_gravity_stomp_20260601033201.png",
    skill_glass_cannon     = "image/skill_glass_cannon_20260601033313.png",
    skill_dawn_herald      = "image/skill_dawn_herald_20260601033317.png",
    skill_collector        = "image/skill_collector_20260601034007.png",
    skill_spike_trap       = "image/skill_spike_trap_20260601033159.png",
    skill_split_shot       = "image/skill_split_shot_20260601033209.png",
    skill_hunter_mark      = "image/skill_hunter_mark_20260601033312.png",
    skill_combo_shield     = "image/skill_combo_shield_20260601033314.png",
    skill_step_strike      = "image/skill_step_strike_20260601033527.png",
    skill_frost_mark       = "image/skill_frost_mark_20260617123756.png",
    skill_kingmaker        = "image/skill_kingmaker_20260617123811.png",
    skill_gravity_pull     = "image/skill_gravity_pull_20260617123924.png",
    skill_dart_storm       = "image/skill_dart_storm_20260617123810.png",
    skill_multi_cast       = "image/skill_multi_cast_20260617123804.png",
    skill_damage_amp       = "image/skill_damage_amp_20260617124030.png",
    skill_silence_path     = "image/skill_silence_path_20260617123803.png",
    -- 组合技能
    skill_combo_storm      = "image/skill_combo_thunder_quake_20260601033526.png",
    skill_combo_thorn      = "image/skill_combo_blood_thorns_20260601033523.png",
    skill_combo_fire       = "image/skill_combo_fire_20260609063807.png",
    skill_combo_pirate     = "image/skill_combo_pirate_20260617123816.png",

    -- === HUD 图标 (4) ===
    hud_hp                 = "icons/hud/hud_hp_20260427110233.png",
    hud_shield             = "icons/hud/hud_shield_20260427110230.png",
    hud_gold               = "icons/hud/hud_gold_20260427110235.png",
    hud_kill               = "icons/hud/hud_kill_20260427110236.png",

    -- === 菜单 Tab 图标 (5) ===
    tab_shop               = "icons/tabs/tab_shop_20260427110231.png",
    tab_equip              = "icons/tabs/tab_equip_20260427110231.png",
    tab_adventure          = "icons/tabs/tab_adventure_20260427110246.png",
    tab_talent             = "icons/tabs/tab_talent_20260427110453.png",
    tab_guild              = "icons/tabs/tab_guild_20260427110241.png",

    -- === 道具图标 (5) ===
    item_health_potion     = "icons/items/item_health_potion_20260427110358.png",
    item_health_potion_big = "icons/items/item_health_potion_big_20260521032413.png",
    item_gold_bag          = "icons/items/item_gold_bag_20260427110618.png",
    item_shield            = "icons/items/item_shield_20260427110945.png",
    item_lucky_wheel       = "image/item_lucky_wheel_20260604090826.png",
    item_doom_wheel        = "image/item_doom_wheel_20260604090828.png",

    -- === 装备槽位图标 (6) ===
    equip_weapon           = "icons/equip/equip_weapon_20260427110614.png",
    equip_accessory        = "icons/equip/equip_accessory_20260427110620.png",
    equip_helmet           = "icons/equip/equip_helmet_20260427110621.png",
    equip_armor            = "icons/equip/equip_armor_20260427111018.png",
    equip_pants            = "icons/equip/equip_pants_20260427110622.png",
    equip_boots            = "icons/equip/equip_boots_20260427110627.png",

    -- === 装备物品图标 (10) ===
    equip_item_flame       = "icons/equip_items/equip_flame_set.png",
    equip_item_frost       = "icons/equip_items/equip_frost_set.png",
    equip_item_shadow      = "icons/equip_items/equip_shadow_set.png",
    equip_item_iron_sword  = "icons/equip_items/equip_iron_sword.png",
    equip_item_health_ring = "icons/equip_items/equip_health_ring.png",
    equip_item_leather_cap = "icons/equip_items/equip_leather_cap.png",
    equip_item_leather_armor = "icons/equip_items/equip_leather_armor.png",
    equip_item_linen_pants = "icons/equip_items/equip_linen_pants.png",
    equip_item_cloth_shoes = "icons/equip_items/equip_cloth_shoes.png",
    icon_gacha_shop        = "icons/equip_items/icon_gacha_shop.png",

    -- === 连击等级图标 (6) ===
    combo_tier1            = "icons/combo/combo_tier1_20260427110623.png",
    combo_tier2            = "icons/combo/combo_tier2_20260427110618.png",
    combo_tier3            = "icons/combo/combo_tier3_20260427111118.png",
    combo_tier4            = "icons/combo/combo_tier4_20260427111117.png",
    combo_tier5            = "image/combo_tier5_meteor_20260516141940.png",
    combo_tier6            = "icons/combo/combo_tier6_20260427111120.png",

    -- === 棋盘元素图标 (10) ===
    board_rock             = "icons/board/board_rock_20260427111116.png",
    board_coral            = "image/board_coral_20260522081437.png",
    board_tentacle         = "image/tentacle_big_20260513071227.png",
    board_abyss            = "icons/board/board_abyss_20260427111117.png",
    board_poison           = "icons/board/board_poison_20260427111113.png",
    board_lava             = "icons/board/board_lava_20260427111119.png",
    board_ward             = "icons/board/board_ward_20260427111211.png",
    board_frost            = "icons/board/board_frost_20260427111330.png",
    board_scarecrow        = "image/scarecrow_icon_20260513064747.png",
    board_fog              = "icons/board/board_fog_20260427111216.png",
    board_dagger           = "icons/board/board_dagger_20260427111217.png",
}

-- ============================================================================
-- NanoVG 图标缓存与绘制 (用于 BoardWidget 棋盘层)
-- ============================================================================

--- 确保图标的 NanoVG 图片句柄已加载（带缓存）
---@param nvg NVGContextWrapper
---@param iconId string 图标 ID (如 "board_rock")
---@return integer|nil handle NanoVG 图片句柄
function IconAtlas.EnsureImage(nvg, iconId)
    if spriteCache_[iconId] then return spriteCache_[iconId] end
    local path = IconAtlas.PATHS[iconId]
    if not path then return nil end
    local handle = nvgCreateImage(nvg, path, 0)
    if handle and handle > 0 then
        spriteCache_[iconId] = handle
        return handle
    end
    return nil
end

--- 在 NanoVG 中绘制图标（居中绘制）
--- 用于 BoardWidget 棋盘层替代 nvgText(emoji)
---@param nvg NVGContextWrapper
---@param iconId string 图标 ID
---@param cx number 中心 X 坐标
---@param cy number 中心 Y 坐标
---@param size number 图标绘制尺寸
---@param alpha number|nil 透明度 0~1，默认 1.0
function IconAtlas.DrawNVG(nvg, iconId, cx, cy, size, alpha)
    local handle = IconAtlas.EnsureImage(nvg, iconId)
    if not handle then return end
    alpha = alpha or 1.0
    local halfSize = size / 2
    local sx = cx - halfSize
    local sy = cy - halfSize
    local imgPaint = nvgImagePattern(nvg, sx, sy, size, size, 0, handle, alpha)
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, size, size)
    nvgFillPaint(nvg, imgPaint)
    nvgFill(nvg)
end

--- 在 NanoVG 中绘制图标（支持旋转）
---@param nvg NVGContextWrapper
---@param iconId string 图标 ID
---@param cx number 中心 X 坐标
---@param cy number 中心 Y 坐标
---@param size number 图标绘制尺寸
---@param angle number 旋转角度（弧度）
---@param alpha number|nil 透明度
function IconAtlas.DrawNVGRotated(nvg, iconId, cx, cy, size, angle, alpha)
    local handle = IconAtlas.EnsureImage(nvg, iconId)
    if not handle then return end
    alpha = alpha or 1.0
    local halfSize = size / 2
    nvgSave(nvg)
    nvgTranslate(nvg, cx, cy)
    nvgRotate(nvg, angle)
    local imgPaint = nvgImagePattern(nvg, -halfSize, -halfSize, size, size, 0, handle, alpha)
    nvgBeginPath(nvg)
    nvgRect(nvg, -halfSize, -halfSize, size, size)
    nvgFillPaint(nvg, imgPaint)
    nvgFill(nvg)
    nvgRestore(nvg)
end

-- ============================================================================
-- UI 组件层接口 (用于 GameUI / MenuSystem 等)
-- ============================================================================

--- 获取图标的资源路径（用于 UI 组件的 backgroundImage 属性）
---@param iconId string 图标 ID
---@return string|nil path 资源路径
function IconAtlas.GetPath(iconId)
    return IconAtlas.PATHS[iconId]
end

return IconAtlas
