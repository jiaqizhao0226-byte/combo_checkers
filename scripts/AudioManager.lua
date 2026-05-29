-- ============================================================================
-- AudioManager - 集中管理 BGM 和音效播放
-- ============================================================================

local G = require "GameState"

local AM = {}

-- 音频节点（挂载 SoundSource 组件）
local bgmNode = nil
local sfxNodes = {}       -- SFX 对象池
local MAX_SFX_POOL = 12   -- 最大同时音效数

-- 当前 BGM 信息
local currentBGM = ""
local bgmSource = nil

-- 音量设置
AM.bgmVolume = 0.12
AM.sfxVolume = 0.6

-- 连跳音效风格: "scale" = 音阶递进, "classic" = 经典跳跃音
AM.comboSoundStyle = "classic"

-- ============================================================================
-- BGM 路径映射
-- ============================================================================
AM.BGM = {
    menu           = "audio/bgm_menu.ogg",
    battle         = "audio/bgm_battle.ogg",
    battle_calm    = "audio/bgm_battle_calm.ogg",
    battle_endless = "audio/music_1779603354052.ogg", -- 无尽深渊专属（暗黑电子管弦）
    boss           = "audio/bgm_boss.ogg",            -- 通用Boss BGM
    boss_lava      = "audio/bgm_boss_lava.ogg",       -- 熔岩领主专属（史诗管弦+战鼓）
    boss_abyss     = "audio/bgm_boss_abyss.ogg",      -- 深渊海妖专属（深海压迫恐惧）
    boss_coral     = "audio/music_1779514990986.ogg",  -- 珊瑚守卫专属（海洋宫殿决战）
    battle_desert  = "audio/music_1779955577605.ogg", -- 第四章沙漠战斗（阿拉伯风打击乐）
    boss_sand      = "audio/music_1779956688332.ogg", -- 沙丘巨虫专属（史诗战鼓）
}

-- ============================================================================
-- SFX 路径映射
-- ============================================================================
AM.SFX = {
    -- UI
    ui_click       = "audio/sfx/ui_click.ogg",
    ui_tab_switch  = "audio/sfx/ui_tab_switch.ogg",
    ui_popup_open  = "audio/sfx/ui_popup_open.ogg",
    ui_popup_close = "audio/sfx/ui_popup_close.ogg",
    ui_equip       = "audio/sfx/ui_equip.ogg",
    ui_gacha_pull  = "audio/sfx/ui_gacha_pull.ogg",
    -- 战斗
    hero_jump      = "audio/sfx/sfx_hero_jump.ogg",
    hero_land      = "audio/sfx/sfx_hero_land.ogg",
    attack_hit     = "audio/sfx/sfx_attack_hit.ogg",
    enemy_death    = "audio/sfx/sfx_enemy_death.ogg",
    combo_trigger  = "audio/sfx/sfx_combo_trigger.ogg",
    combo_low      = "audio/sfx/sfx_combo_low.ogg",
    combo_mid      = "audio/sfx/sfx_combo_mid.ogg",
    combo_high     = "audio/sfx/sfx_combo_high.ogg",
    item_pickup    = "audio/sfx/sfx_item_pickup.ogg",
    hero_damage    = "audio/sfx/sfx_hero_damage.ogg",
    victory        = "audio/sfx/sfx_victory.ogg",
    defeat         = "audio/sfx/sfx_defeat.ogg",
    -- 技能/特殊
    poison_fog     = "audio/sfx/sfx_poison_fog.ogg",
    frost_ice      = "audio/sfx/sfx_frost_ice.ogg",
    lightning      = "audio/sfx/sfx_lightning.ogg",
    shield_ward    = "audio/sfx/sfx_shield_ward.ogg",
    shield_break   = "audio/sfx/sfx_shield_break.ogg",
    meteor_impact  = "audio/sfx/sfx_meteor_impact.ogg",
    time_freeze    = "audio/sfx/sfx_time_freeze.ogg",
    boss_entrance  = "audio/sfx/sfx_boss_entrance.ogg",
    heal           = "audio/sfx/sfx_heal.ogg",
    heal_pickup    = "audio/sfx/sfx_heal_pickup.ogg",
    dice_roll      = "audio/sfx/sfx_dice_roll.ogg",
    turn_start     = "audio/sfx/sfx_turn_start.ogg",
    bomb_clear     = "audio/sfx/sfx_bomb_clear.ogg",
    altar_destroy      = "audio/sfx/sfx_altar_destroy.ogg",
    -- 熔岩领主专属
    lava_eruption      = "audio/sfx/sfx_lava_eruption.ogg",
    lava_shield_regen  = "audio/sfx/sfx_lava_shield_regen.ogg",
    lava_lord_roar     = "audio/sfx/sfx_lava_lord_roar.ogg",
    chapter_clear  = "audio/sfx/sfx_chapter_clear.ogg",
    -- 连击专属音效
    combo_dart       = "audio/sfx/combo_dart.ogg",
    combo_scarecrow  = "audio/sfx/combo_scarecrow.ogg",
    combo_hex_blast  = "audio/sfx/combo_hex_blast.ogg",
    combo_life_drain = "audio/sfx/combo_life_drain.ogg",
    combo_hex_hit    = "audio/sfx/combo_hex_hit.ogg",
    combo_meteor     = "audio/sfx/combo_meteor.ogg",
    combo_bomb_clear = "audio/sfx/combo_bomb_clear.ogg",
    combo_doomsday_blast = "audio/sfx/combo_doomsday_blast.ogg",
    combo_doomsday_announce = "audio/sfx/combo_doomsday_announce.ogg",
    -- 连跳音阶基础音效（8bit风格）
    combo_note = "audio/sfx/note_do_C4.ogg",
    -- 金色套装效果触发
    gold_set_trigger = "audio/sfx/sfx_gold_set_trigger_v3.ogg",
    -- 翻页
    page_turn        = "audio/sfx/page_turn.ogg",
    -- 分裂弹
    split_shot       = "audio/sfx/sfx_attack_hit.ogg",
    -- 踏步斩专属音效
    step_strike      = "audio/sfx/sfx_step_strike.ogg",
    -- 深渊海妖新技能专属音效
    abyss_claw_hit       = "audio/sfx/abyss_claw_hit.ogg",
    abyss_venom_spray    = "audio/sfx/abyss_venom_spray.ogg",
    -- 熔岩领主新技能专属音效
    lava_fist_smash      = "audio/sfx/lava_fist_smash.ogg",
    flame_bolt_impact    = "audio/sfx/flame_bolt_impact.ogg",
    -- 珊瑚守卫新技能专属音效
    coral_spike_pierce   = "audio/sfx/coral_spike_pierce.ogg",
    -- 沙丘巨虫Boss专属音效
    boss_aoe             = "audio/sfx/boss_aoe.ogg",
    boss_stomp           = "audio/sfx/boss_stomp.ogg",
    quicksand_spawn      = "audio/sfx/quicksand_spawn.ogg",
    -- 未注册补录
    combo_shield_gain    = "audio/sfx/combo_shield_gain.ogg",
    vampiric_drain       = "audio/sfx/vampiric_drain.ogg",
    hunter_mark          = "audio/sfx/hunter_mark.ogg",
    spike_trap_hit       = "audio/sfx/spike_trap_hit.ogg",
    thorns_reflect       = "audio/sfx/thorns_reflect.ogg",
    ui_error             = "audio/sfx/ui_click.ogg",    -- 无专用错误音，复用点击音
    equip                = "audio/sfx/ui_equip.ogg",
}

-- ============================================================================
-- 连跳音阶：用一个基础音效 + pitch 倍率实现精确 do re mi fa sol la si do'
-- 大调音阶（十二平均律）: 每个半音 = 2^(1/12)
-- do=0, re=2, mi=4, fa=5, sol=7, la=9, si=11, do'=12 半音
-- ============================================================================
local SCALE_SEMITONES = { 0, 2, 4, 5, 7, 9, 11, 12 }  -- 完整大调音阶，跨一个八度
local SCALE_BASE = 0.38  -- 整体降调：压到浑厚低沉的音区
local SCALE_PITCH = {}
for i, semi in ipairs(SCALE_SEMITONES) do
    SCALE_PITCH[i] = SCALE_BASE * 2 ^ (semi / 12)
end

--- 播放连跳音效（根据 comboSoundStyle 自动选择风格）
function AM.PlayComboNote(combo)
    if AM.comboSoundStyle == "classic" then
        -- 经典模式：每次跳跃播放原始 hero_jump 音效
        AM.PlaySFX("hero_jump")
        return
    end

    -- 音阶模式：do re mi fa sol la si do'（多层叠加）
    local idx = math.min((combo or 0) + 1, 8)
    local pitch = SCALE_PITCH[idx]
    local gain = math.min(1.0 + (idx - 1) * 0.06, 1.4)

    -- 主音
    AM.PlaySFX("combo_note", gain, pitch)
    -- 合唱层：微微走调 +3%，模拟 chorus/unison 厚度
    AM.PlaySFX("combo_note", gain * 0.45, pitch * 1.03)
    -- 低八度层：增加低频身体感
    AM.PlaySFX("combo_note", gain * 0.35, pitch * 0.5)
end

-- ============================================================================
-- 初始化（在 Start() 中调用一次）
-- ============================================================================
function AM.Init()
    -- 创建 BGM 节点
    bgmNode = Node()
    bgmSource = bgmNode:CreateComponent("SoundSource")
    bgmSource.soundType = "Music"
    bgmSource.gain = AM.bgmVolume

    -- 预创建 SFX 对象池
    for i = 1, MAX_SFX_POOL do
        local n = Node()
        local src = n:CreateComponent("SoundSource")
        src.soundType = "Effect"
        src.gain = AM.sfxVolume
        src.autoRemoveMode = REMOVE_DISABLED
        sfxNodes[i] = { node = n, source = src }
    end

    -- 预加载所有 BGM 并设置循环
    for key, path in pairs(AM.BGM) do
        local snd = cache:GetResource("Sound", path)
        if snd then
            snd.looped = true
            log:Write(LOG_INFO, "[BGM] Init preload OK: " .. key .. " -> " .. path)
        else
            log:Write(LOG_ERROR, "[BGM] Init preload FAILED: " .. key .. " -> " .. path)
        end
    end

    -- 设置全局音量
    audio:SetMasterGain("Music", 1.0)
    audio:SetMasterGain("Effect", 1.0)
end

-- ============================================================================
-- BGM 播放
-- ============================================================================

--- 播放 BGM（如果已经是同一首则不重复播放）
---@param key string BGM key: "menu" | "battle" | "boss"
function AM.PlayBGM(key)
    if not bgmSource then
        log:Write(LOG_ERROR, "[BGM] PlayBGM: bgmSource is nil! AM.Init() not called? key=" .. tostring(key))
        return
    end
    local path = AM.BGM[key]
    if not path then
        log:Write(LOG_WARNING, "[BGM] PlayBGM: unknown key=" .. tostring(key))
        return
    end
    if currentBGM == key and bgmSource:IsPlaying() then
        log:Write(LOG_INFO, "[BGM] PlayBGM: skip (already playing) key=" .. key)
        return
    end
    local snd = cache:GetResource("Sound", path)
    if not snd then
        log:Write(LOG_WARNING, "[BGM] PlayBGM: resource not found path=" .. path)
        return
    end
    log:Write(LOG_INFO, "[BGM] PlayBGM: switching " .. tostring(currentBGM) .. " -> " .. key)
    snd.looped = true
    bgmSource.gain = AM.bgmVolume
    bgmSource:Play(snd)
    currentBGM = key
    log:Write(LOG_INFO, "[BGM] PlayBGM: play called, IsPlaying=" .. tostring(bgmSource:IsPlaying()))
end

--- 获取当前 BGM key
function AM.GetCurrentBGM()
    return currentBGM
end

--- 停止 BGM
function AM.StopBGM()
    if bgmSource then
        bgmSource:Stop()
    end
    currentBGM = ""
end

--- 设置 BGM 音量
function AM.SetBGMVolume(vol)
    AM.bgmVolume = vol
    if bgmSource then
        bgmSource.gain = vol
    end
end

-- ============================================================================
-- SFX 播放
-- ============================================================================

--- 找一个空闲的 SFX 通道
local function GetFreeSFXSource()
    -- 优先找未播放的
    for i = 1, MAX_SFX_POOL do
        if not sfxNodes[i].source:IsPlaying() then
            return sfxNodes[i].source
        end
    end
    -- 全部占满则复用最早的（第一个）
    return sfxNodes[1].source
end

--- 播放音效
---@param key string SFX key (如 "hero_jump", "attack_hit" 等)
---@param gain? number 音量倍率 (默认 1.0)
---@param pitchMul? number 音调倍率 (默认 1.0, >1.0 音调升高)
function AM.PlaySFX(key, gain, pitchMul)
    local path = AM.SFX[key]
    if not path then return end

    local snd = cache:GetResource("Sound", path)
    if not snd then
        log:Write(LOG_WARNING, "[AudioManager] SFX not found: " .. path)
        return
    end

    local src = GetFreeSFXSource()
    local finalGain = AM.sfxVolume * (gain or 1.0)
    local freq = snd.frequency * (pitchMul or 1.0)
    src:Play(snd, freq, finalGain)
end

--- 设置 SFX 音量
function AM.SetSFXVolume(vol)
    AM.sfxVolume = vol
end

-- ============================================================================
-- 便捷方法：根据游戏状态自动选择 BGM
-- ============================================================================

--- Boss类型 → BGM key 映射
local BOSS_BGM_MAP = {
    lava_lord      = "boss_lava",   -- 熔岩领主：史诗管弦战鼓
    abyss_kraken   = "boss_abyss",  -- 深渊海妖：深海压迫恐惧
    coral_guardian = "boss_coral",   -- 珊瑚守卫：海洋宫殿决战
    sand_worm      = "boss_sand",    -- 沙丘巨虫：史诗沙漠战鼓
}

--- 根据关卡自动切换 BGM
function AM.UpdateBattleBGM(level)
    local Battle = require "Battle"
    local chapter = math.ceil(level / Battle.LEVELS_PER_CHAPTER)

    -- 第5章及以上 fallback 到战斗BGM（无尽模式由 EnterEndless 单独设置）
    if chapter >= 5 then
        AM.PlayBGM("battle")
        return
    end

    if Battle.IsBossLevel and Battle.IsBossLevel(level) then
        -- 根据Boss类型选择专属BGM
        local bossType = Battle.CHAPTER_BOSS and Battle.CHAPTER_BOSS[chapter]
        local bgmKey = (bossType and BOSS_BGM_MAP[bossType]) or "boss"
        log:Write(LOG_INFO, string.format("[BGM] UpdateBattleBGM: level=%d boss chapter=%d bossType=%s bgmKey=%s currentBGM=%s",
            level, chapter, tostring(bossType), bgmKey, tostring(currentBGM)))
        AM.PlayBGM(bgmKey)
    else
        -- 按章节选择战斗BGM
        if chapter <= 1 then
            AM.PlayBGM("battle_calm")
        elseif chapter == 4 then
            AM.PlayBGM("battle_desert")
        else
            AM.PlayBGM("battle")
        end
    end
end

return AM
