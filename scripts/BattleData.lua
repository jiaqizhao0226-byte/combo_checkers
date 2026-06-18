-- ============================================================================
-- BattleData - 纯静态数据表（从 Battle.lua 拆分）
-- 不依赖任何游戏状态，只有常量数据
-- ============================================================================

local BattleData = {}

BattleData.HERO_TEMPLATE = {
    team = "hero",
    hp = 100, maxHp = 100,
    atk = 15,
    def = 1,
    name = "剑士",
}

BattleData.ENEMY_GOLD = {
    slime    = 1,
    skeleton = 2,
    mushroom = 1,
    -- 第二章（海洋）
    jellyfish   = 1,
    iron_turtle  = 3,
    vortex_eel   = 2,
    hermit_crab  = 1,
    -- 第三章（火焰）
    fire_sprite     = 1,
    lava_giant      = 3,

    -- 第四章（珊瑚）
    coral_snapper   = 1,
    sea_urchin      = 2,
    reef_starfish   = 1,
    -- 新机制敌人
    ghost_shark     = 2,
    spine_anemone   = 1,
    archerfish      = 2,
    electric_ray    = 2,
    coral_priest    = 2,

    splitting_urchin = 3,
    fission_flame   = 1,
    flame_shard     = 0,
    -- 第四章（流沙荒漠）
    sand_scorpion   = 2,
    quicksand_worm  = 1,
    sand_hawk       = 2,
    sand_strider    = 3,
    sand_rattler    = 2,
    venom_lizard    = 2,
    -- 第五章（永冻绝境）
    frost_grunt      = 2,
    aurora_jelly     = 1,
    frost_barracuda  = 2,
    ice_crystal      = 2,
    blizzard_hawk    = 2,
    frost_bear       = 3,
    -- Boss
    boss     = 10,
}

BattleData.ENEMY_TEMPLATES = {
    slime = {
        team = "enemy", enemyType = "slime",
        hp = 25, maxHp = 25,
        atk = 5,
        attackRange = 1,
        attackLabel = "撞击",
        name = "史莱姆",
    },
    skeleton = {
        team = "enemy", enemyType = "skeleton",
        hp = 40, maxHp = 40,
        atk = 12,
        attackRange = 2,
        attackLabel = "投骨",
        name = "骷髅兵",
    },
    mushroom = {
        team = "enemy", enemyType = "mushroom",
        hp = 18, maxHp = 18,
        atk = 0,
        attackRange = 1,
        attackLabel = "孢子",
        deathDamage = 8,
        name = "毒蘑菇",
    },
    -- ====== 第二章: 烈焰山脉 ======
    fire_sprite = {
        team = "enemy", enemyType = "fire_sprite",
        hp = 32, maxHp = 32,
        atk = 11,
        attackRange = 1,
        attackLabel = "灼烧",
        burnDamage = 7,     -- 跳过时附加灼烧DOT（每回合7伤害，持续2回合）
        burnDuration = 2,
        name = "火灵",
    },
    lava_giant = {
        team = "enemy", enemyType = "lava_giant",
        hp = 72, maxHp = 72,
        atk = 18,
        attackRange = 1,
        attackLabel = "熔岩拳",
        leavesLava = true,  -- 死亡时留下熔岩地形（=毒地形，每回合10伤害）
        lavaDamage = 10,
        name = "熔岩巨人",
    },

    -- ====== 第三章: 珊瑚迷宫 ======
    coral_snapper = {
        team = "enemy", enemyType = "coral_snapper",
        hp = 40, maxHp = 40,
        atk = 13,
        attackRange = 1,
        attackLabel = "珊瑚钳",
        name = "珊瑚夹",
    },
    sea_urchin = {
        team = "enemy", enemyType = "sea_urchin",
        hp = 26, maxHp = 26,
        atk = 9,
        attackRange = 1,
        attackLabel = "尖刺",
        name = "海胆",
    },
    reef_starfish = {
        team = "enemy", enemyType = "reef_starfish",
        hp = 30, maxHp = 30,
        atk = 7,
        attackRange = 1,
        attackLabel = "缠绕",
        regenHp = 6,         -- 每回合回复6HP
        name = "礁石海星",
    },
    -- ====== 第一章: 深渊海沟 ======
    jellyfish = {
        team = "enemy", enemyType = "jellyfish",
        hp = 28, maxHp = 28,
        atk = 8,
        attackRange = 1,
        attackLabel = "电击",
        name = "电水母",
    },
    iron_turtle = {
        team = "enemy", enemyType = "iron_turtle",
        hp = 55, maxHp = 55,
        atk = 9,
        def = 5,            -- 防御力5，减免所有受到的伤害
        attackRange = 1,
        attackLabel = "重击",
        name = "铁甲龟",
    },
    vortex_eel = {
        team = "enemy", enemyType = "vortex_eel",
        hp = 35, maxHp = 35,
        atk = 10,
        attackRange = 1,
        attackLabel = "撕咬",
        shuffleOnDeath = true, -- 死亡时打乱周围1格内的棋子位置
        name = "漩涡鳗",
    },
    hermit_crab = {
        team = "enemy", enemyType = "hermit_crab",
        hp = 38, maxHp = 38,
        atk = 7,
        attackRange = 1,
        attackLabel = "钳击",
        hasShell = true,     -- 缩壳状态：受伤减半，不移动不攻击
        shellCooldown = 0,   -- 缩壳冷却计数
        name = "寄居蟹",
    },
    -- ====== 新机制敌人 ======
    ghost_shark = {
        team = "enemy", enemyType = "ghost_shark",
        hp = 22, maxHp = 22,
        atk = 11,
        attackRange = 1,
        attackLabel = "噬咬",
        teleportCooldown = 1,  -- 瞬移冷却（回合数）
        name = "幽灵鲨",
    },
    archerfish = {
        team = "enemy", enemyType = "archerfish",
        hp = 18, maxHp = 18,
        atk = 9,
        attackRange = 2,       -- 远程攻击2格
        attackLabel = "水弹",
        fleesWhenClose = true,  -- 英雄靠近时后退
        name = "射水鱼",
    },
    electric_ray = {
        team = "enemy", enemyType = "electric_ray",
        hp = 40, maxHp = 40,
        atk = 7,
        attackRange = 1,
        attackLabel = "放电",
        aoeDamage = true,      -- 攻击时对目标周围1格敌方也造成半额伤害
        aoeRadius = 1,
        name = "电鳐",
    },
    spine_anemone = {
        team = "enemy", enemyType = "spine_anemone",
        hp = 30, maxHp = 30,
        atk = 9,
        attackRange = 3,       -- 远程攻击3格
        attackLabel = "棘射",
        fleesWhenClose = true,  -- 英雄靠近时后退
        name = "棘刺海葵",
    },
    coral_priest = {
        team = "enemy", enemyType = "coral_priest",
        hp = 32, maxHp = 32,
        atk = 0,               -- 不攻击英雄
        attackRange = 1,
        attackLabel = "祝福",
        healAmount = 10,       -- 治疗友军+10HP
        buffATK = 5,           -- 增益友军+5ATK（1回合）
        isSupport = true,
        name = "珊瑚祭司",
    },

    splitting_urchin = {
        team = "enemy", enemyType = "splitting_urchin",
        hp = 36, maxHp = 36,
        atk = 10,
        attackRange = 1,
        attackLabel = "尖刺",
        splitThreshold = 0.5,  -- 首次被打到 50% HP 以下时分裂为 2 只小海胆
        _hasSplit = false,     -- 已分裂标记，每只只分裂一次
        name = "裂变海胆",
    },
    fission_flame = {
        team = "enemy", enemyType = "fission_flame",
        hp = 38, maxHp = 38,
        atk = 11,
        attackRange = 1,
        attackLabel = "烈焰",
        splitsOnDeath = true,  -- 死亡时分裂
        name = "裂焰精",
    },
    flame_shard = {
        team = "enemy", enemyType = "flame_shard",
        hp = 14, maxHp = 14,
        atk = 7,
        attackRange = 1,
        attackLabel = "灼击",
        isShard = true,        -- 碎片：不计入击杀目标，不再分裂
        name = "焰碎片",
    },
    -- ====== 第四章: 流沙荒漠 ======
    sand_scorpion = {
        team = "enemy", enemyType = "sand_scorpion",
        hp = 45, maxHp = 45,
        atk = 22,
        attackRange = 1,
        attackLabel = "蛰刺",
        name = "沙蝎",
    },
    quicksand_worm = {
        team = "enemy", enemyType = "quicksand_worm",
        hp = 28, maxHp = 28,
        atk = 18,
        attackRange = 1,
        attackLabel = "啃噬",
        name = "流沙虫",
    },
    sand_hawk = {
        team = "enemy", enemyType = "sand_hawk",
        hp = 30, maxHp = 30,
        atk = 24,
        attackRange = 2,
        attackLabel = "俯冲",
        fleesWhenClose = true,  -- 英雄靠近时后退
        name = "沙鹰",
    },
    -- ====== 第四章特殊机制敌人 ======
    sand_strider = {
        team = "enemy", enemyType = "sand_strider",
        hp = 22, maxHp = 22,
        atk = 24,
        attackRange = 99,       -- 全图攻击
        attackLabel = "沙暴射线",
        chargeTurns = 1,        -- 蓄力1回合后才能攻击
        _chargeCD = 0,          -- 当前蓄力状态（0=可蓄力，>0=蓄力中）
        _charged = false,       -- 蓄力完成标记
        name = "沙暴行者",
    },
    sand_rattler = {
        team = "enemy", enemyType = "sand_rattler",
        hp = 38, maxHp = 38,
        atk = 14,
        attackRange = 1,
        attackLabel = "咬击",
        counterMultiplier = 2.0, -- 反击时伤害倍率
        _enraged = false,        -- 狂怒状态（被攻击/跳过后激活）
        name = "沙漠响尾蛇",
    },
    venom_lizard = {
        team = "enemy", enemyType = "venom_lizard",
        hp = 32, maxHp = 32,
        atk = 15,
        attackRange = 1,
        attackLabel = "毒尾",
        poisonDamage = 7,       -- 中毒每回合伤害
        poisonDuration = 3,     -- 中毒持续回合
        name = "毒尾蜥",
    },
    -- ====== 无尽模式专属 ======
    swift_barracuda = {
        team = "enemy", enemyType = "swift_barracuda",
        hp = 30, maxHp = 30,
        atk = 10,
        attackRange = 1,
        attackLabel = "疾冲",
        moveSteps = 3,         -- 每回合最多移动3格
        name = "疾梭鱼",
    },
    charm_jelly = {
        team = "enemy", enemyType = "charm_jelly",
        hp = 20, maxHp = 20,
        atk = 8,
        attackRange = 1,
        attackLabel = "媚触",
        charmRange = 2,        -- 英雄进入2格范围内触发魅惑
        name = "魅惑水母",
    },
}

BattleData.ENEMY_INTRO = {
    jellyfish    = { icon = "🎐", name = "电水母",   desc = "跳过它会被电击反伤" },
    sea_urchin   = { icon = "🌰", name = "海胆",     desc = "跳过它会被尖刺反伤" },
    iron_turtle  = { icon = "🐢", name = "铁甲龟",   desc = "高防御，受到伤害减免" },
    vortex_eel   = { icon = "🌀", name = "漩涡鳗",   desc = "死亡时打乱周围棋子" },
    hermit_crab  = { icon = "🐚", name = "寄居蟹",   desc = "缩壳时伤害减半" },
    ghost_shark  = { icon = "🦈", name = "幽灵鲨",   desc = "会瞬移到随机位置" },
    archerfish   = { icon = "🐠", name = "射水鱼",   desc = "远程攻击，靠近会后退" },
    electric_ray = { icon = "⚡", name = "电鳐",     desc = "攻击会波及周围目标" },
    reef_starfish= { icon = "⭐", name = "礁石海星", desc = "每回合自动回复生命" },
    fire_sprite  = { icon = "🔥", name = "火灵",     desc = "跳过会被灼烧，持续掉血" },
    lava_giant   = { icon = "🗿", name = "熔岩巨人", desc = "死后留下熔岩地形" },
    mushroom     = { icon = "🍄", name = "毒蘑菇",   desc = "死亡时释放毒孢子" },
    spine_anemone= { icon = "🌺", name = "棘刺海葵", desc = "超远程攻击，靠近会后退" },
    coral_priest = { icon = "🧙", name = "珊瑚祭司", desc = "治疗并强化附近敌人" },

    splitting_urchin = { icon = "💥", name = "裂变海胆", desc = "血量低于50%时分裂成两只小海胆，仍有反伤" },
    fission_flame= { icon = "🔥", name = "裂焰精",   desc = "死亡时分裂成小碎片" },
    swift_barracuda = { icon = "💨", name = "疾梭鱼", desc = "每回合最多移动3格，来势凶猛" },
    charm_jelly  = { icon = "💜", name = "魅惑水母", desc = "英雄进入2格范围将被魅惑，跳过一回合" },
    -- 第五章
    sand_scorpion   = { icon = "🦂", name = "沙蝎",   desc = "沙漠中的伏击者" },
    quicksand_worm  = { icon = "🪱", name = "流沙虫", desc = "潜伏沙中的蠕虫，近距啃噬" },
    sand_hawk       = { icon = "🦅", name = "沙鹰",   desc = "远程俯冲，靠近会后退" },
    sand_strider    = { icon = "🌪️", name = "沙暴行者", desc = "蓄力一回合后可攻击全图任意目标！" },
    sand_rattler    = { icon = "🐍", name = "响尾蛇", desc = "被攻击或跳过后狂怒，下回合造成双倍伤害" },
    venom_lizard    = { icon = "🦎", name = "毒尾蜥", desc = "攻击附带剧毒，持续掉血" },
}

BattleData.BOSS_TEMPLATES = {
    -- 第二章Boss: 熔岩领主
    lava_lord = {
        team = "enemy", enemyType = "boss",
        hp = 480, maxHp = 480,
        atk = 28,
        attackRange = 2,
        attackLabel = "熔岩喷射",
        name = "熔岩领主",
        isBoss = true,
        bossType = "lava_lord",
        -- Boss特殊属性
        phase = 1,
        shieldHp = 50,
        shieldMax = 90,
        eruptionCooldown = 0,   -- 熔岩喷发冷却（在英雄周围放置岩浆）
        shieldRegenCooldown = 0, -- 护盾再生冷却
        enraged = false,
    },
    -- 第三章Boss: 珊瑚守卫
    coral_guardian = {
        team = "enemy", enemyType = "boss",
        hp = 650, maxHp = 650,
        atk = 30,
        attackRange = 2,
        attackLabel = "珊瑚冲撞",
        name = "珊瑚守卫",
        isBoss = true,
        bossType = "coral_guardian",
        phase = 1,
        shieldHp = 0,
        shieldMax = 110,         -- 护甲值
        tideSurgeCooldown = 0,   -- 潮汐冲击冷却
        coralWallCooldown = 0,   -- 珊瑚墙冷却
        summonCooldown = 0,      -- 召唤冷却
        enraged = false,
    },
    -- 第一章Boss: 深渊海妖
    abyss_kraken = {
        team = "enemy", enemyType = "boss",
        hp = 350, maxHp = 350,
        atk = 14,  -- 降低30%
        attackRange = 3,
        attackLabel = "触手鞭打",
        name = "深渊海妖",
        isBoss = true,
        bossType = "abyss_kraken",
        -- Boss特殊属性
        phase = 1,
        shieldHp = 0,
        shieldMax = 60,
        tentacleCooldown = 0,   -- 触手障碍冷却（包围英雄周围放置触手）
        whirlpoolCooldown = 0,  -- 漩涡冷却（拉拽英雄靠近）
        enraged = false,
    },
    -- 第四章Boss: 沙丘巨虫（最终Boss，强度全面高于第三章珊瑚守卫）
    sand_worm = {
        team = "enemy", enemyType = "boss",
        hp = 1180, maxHp = 1180,   -- 820→1180（最终Boss，明显高于珊瑚守卫650）
        atk = 38,                  -- 26→38（高于珊瑚守卫30，各技能伤害随之提升）
        attackRange = 1,
        attackLabel = "吞噬",
        name = "沙丘巨虫",
        isBoss = true,
        bossType = "sand_worm",
        phase = 1,
        shieldHp = 0,
        shieldMax = 130,           -- 70→130（高于珊瑚守卫110）
        segments = 7,           -- 总节数（含头）
        burrowCooldown = 0,     -- 钻地冷却
        tailWhipCooldown = 0,   -- 尾部甩飞冷却
        -- sandstormCooldown 已移除（巨岩投掷技能已删除）
        sandFuryCooldown = 4,   -- 呼唤风沙冷却（首次延迟4回合）
        enraged = false,
    },

    -- ====== 第五章: 永冻绝境 ======
    frost_grunt = {
        team = "enemy", enemyType = "frost_grunt",
        hp = 48, maxHp = 48,
        atk = 24,
        attackRange = 1,
        attackLabel = "冰锥",
        name = "冰锥兵",
        iceImmune = true,      -- 免疫冰面滑行推动
        deathSpawnIce = true,  -- 死亡时生成冰面格
    },
    aurora_jelly = {
        team = "enemy", enemyType = "aurora_jelly",
        hp = 22, maxHp = 22,
        atk = 0,
        attackRange = 1,
        attackLabel = "魅惑",
        name = "极光水母",
        charmRange = 2,        -- 魅惑光环范围
        iceSpeedBoost = true,  -- 冰面上移速×2
    },
    frost_barracuda = {
        team = "enemy", enemyType = "frost_barracuda",
        hp = 30, maxHp = 30,
        atk = 28,
        attackRange = 1,
        attackLabel = "冲刺",
        name = "寒冰梭鱼",
        chargeRange = 4,       -- 冲刺攻击距离
        iceChargeUnlimited = true, -- 冰面上冲刺无距离限制
    },
    ice_crystal = {
        team = "enemy", enemyType = "ice_crystal",
        hp = 60, maxHp = 60,
        atk = 0,
        attackRange = 3,
        attackLabel = "冻结射线",
        name = "冰晶体",
        isStationary = true,   -- 不移动
        freezeRayCooldown = 0, -- 冻结射线冷却（每2回合射一次）
        freezeDuration = 1,    -- 冻结英雄回合数
    },
    blizzard_hawk = {
        team = "enemy", enemyType = "blizzard_hawk",
        hp = 26, maxHp = 26,
        atk = 20,
        attackRange = 3,
        attackLabel = "暴风吐息",
        name = "暴风雪鹰",
        fleeRange = 1,         -- 英雄靠近1格时逃跑
        iceTrailAttack = true, -- 攻击路径铺冰面
    },
    frost_bear = {
        team = "enemy", enemyType = "frost_bear",
        hp = 90, maxHp = 90,
        atk = 30,
        attackRange = 1,
        attackLabel = "冰面推击",
        name = "寒霜巨熊",
        pushDistance = 3,      -- 推飞英雄距离
        iceImmune = true,      -- 免疫冰面滑行推动
    },
    -- 第五章Boss: 永冻之王
    frost_king = {
        team = "enemy", enemyType = "boss",
        hp = 1600, maxHp = 1600,
        atk = 42,
        attackRange = 2,
        attackLabel = "寒冰投枪",
        name = "永冻之王",
        isBoss = true,
        bossType = "frost_king",
        phase = 1,
        shieldHp = 0,
        shieldMax = 170,
        iceFieldCooldown = 0,    -- 冰封领域冷却
        iceArmorCooldown = 0,    -- 冰甲凝聚冷却
        iceSpearCooldown = 0,    -- 寒冰投枪冷却
        enraged = false,
    },
}

BattleData.CHAPTER_BOSS = {
    [1] = "abyss_kraken",
    [2] = "lava_lord",
    [3] = "coral_guardian",
    [4] = "sand_worm",
    [5] = "frost_king",
}

BattleData.BOSS_AURA = {
    abyss_kraken  = { range = 2, damage = 3, icon = "🌊", name = "深渊压迫", color = {60, 120, 200, 255} },
    -- lava_lord 灼烧光环已移除（改为祭坛破盾机制）
    -- coral_guardian 珊瑚荆棘光环已移除（改为未受伤回血被动）
    -- sand_worm 光环已移除（沙虫Boss不使用周边伤害光环）
}

BattleData.ITEM_TYPES = {
    health_potion     = { icon = "item_health_potion",     name = "小血瓶", desc = "回复40HP" },
    health_potion_big = { icon = "item_health_potion_big", name = "大血瓶", desc = "回满HP" },
    gold_bag          = { icon = "item_gold_bag",          name = "金币袋", desc = "获得10金币(受点金手加成)" },
    shield            = { icon = "item_shield",            name = "护盾",   desc = "下次受击伤害减半" },
    lucky_wheel       = { icon = "item_lucky_wheel",       name = "幸运轮盘", desc = "转动轮盘获取好运！", isWheel = true },
    doom_wheel        = { icon = "item_doom_wheel",        name = "厄运轮盘", desc = "冒险转动，后果自负…", isWheel = true },
}

-- 幸运轮盘事件池（每次随机抽3个 + 固定1个"小确幸"）
BattleData.LUCKY_WHEEL_POOL = {
    { id = "full_hp",      name = "生命涌泉",   desc = "回满全部HP",          icon = "❤️‍🔥", color = {80, 255, 100, 255} },
    { id = "shield",       name = "神圣护盾",   desc = "获得一次性护盾(30点)", icon = "🛡️", color = {120, 180, 255, 255} },
    { id = "extra_skill",  name = "天赋觉醒",   desc = "额外技能三选一",      icon = "⭐",  color = {255, 215, 0, 255} },
    { id = "extra_turn",   name = "时光加速",   desc = "获得额外一回合行动",   icon = "⏩",  color = {180, 120, 255, 255} },
    { id = "lucky_strike", name = "幸运一击",   desc = "对随机敌人造成50伤害", icon = "⚡",  color = {255, 220, 80, 255} },
    { id = "max_hp_up",    name = "体魄强化",   desc = "本次战斗最大HP+25",   icon = "💗",  color = {255, 100, 150, 255} },
    { id = "atk_up_buff",  name = "战意高涨",   desc = "10回合内攻击力+30%",  icon = "🔥",  color = {255, 140, 50, 255} },
}
-- 幸运轮盘固定保底（概率最低的安慰奖）
BattleData.LUCKY_WHEEL_FIXED = { id = "small_reward", name = "小确幸", desc = "获得10金币", icon = "🍀", color = {160, 220, 160, 255} }

-- 厄运轮盘事件池（每次随机抽3个 + 固定1个"无事发生"）
BattleData.DOOM_WHEEL_POOL = {
    { id = "dmg_taken_up", name = "脆弱诅咒",   desc = "10回合内承伤+30%",   icon = "💀", color = {255, 80, 80, 255} },
    { id = "max_hp_down",  name = "生命侵蚀",   desc = "本章最大HP-25%",     icon = "💔", color = {200, 50, 50, 255} },
    { id = "output_down",  name = "力量枯竭",   desc = "10回合内输出-30%",   icon = "⬇️", color = {180, 80, 200, 255} },
    { id = "gold_loss",    name = "破财消灾",   desc = "失去一半金币",       icon = "💸", color = {200, 150, 50, 255} },
    { id = "poison",       name = "暗毒侵蚀",   desc = "5回合每回合损失5%HP", icon = "🧪", color = {120, 200, 50, 255} },
    { id = "max_hp_small_down", name = "虚弱诅咒", desc = "最大HP-15（本场战斗）", icon = "🩸", color = {180, 60, 60, 255} },
    { id = "silence",      name = "封喉之咒",   desc = "沉默3回合无法攻击",   icon = "🤐", color = {100, 100, 150, 255} },
}
-- 厄运轮盘固定保底（唯一的安全区）
BattleData.DOOM_WHEEL_FIXED = { id = "nothing", name = "无事发生", desc = "虚惊一场，获得3金币", icon = "😮‍💨", color = {200, 200, 200, 255} }


return BattleData
