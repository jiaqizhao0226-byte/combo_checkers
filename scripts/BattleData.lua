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
    -- 第五章（黄沙）
    sand_scorpion   = 2,
    quicksand_worm  = 1,
    sand_hawk       = 2,
    sand_strider    = 3,
    sand_rattler    = 2,
    venom_lizard    = 2,
    -- Boss
    boss     = 10,
}

BattleData.ENEMY_TEMPLATES = {
    slime = {
        team = "enemy", enemyType = "slime",
        hp = 25, maxHp = 25,
        atk = 6,
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
    -- ====== 第三章: 烈焰山脉 ======
    fire_sprite = {
        team = "enemy", enemyType = "fire_sprite",
        hp = 22, maxHp = 22,
        atk = 8,
        attackRange = 1,
        attackLabel = "灼烧",
        burnDamage = 5,     -- 跳过时附加灼烧DOT（每回合5伤害，持续2回合）
        burnDuration = 2,
        name = "火灵",
    },
    lava_giant = {
        team = "enemy", enemyType = "lava_giant",
        hp = 55, maxHp = 55,
        atk = 14,
        attackRange = 1,
        attackLabel = "熔岩拳",
        leavesLava = true,  -- 死亡时留下熔岩地形（=毒地形，每回合8伤害）
        lavaDamage = 8,
        name = "熔岩巨人",
    },

    -- ====== 第四章: 珊瑚迷宫 ======
    coral_snapper = {
        team = "enemy", enemyType = "coral_snapper",
        hp = 28, maxHp = 28,
        atk = 9,
        attackRange = 1,
        attackLabel = "珊瑚钳",
        name = "珊瑚夹",
    },
    sea_urchin = {
        team = "enemy", enemyType = "sea_urchin",
        hp = 18, maxHp = 18,
        atk = 6,
        attackRange = 1,
        attackLabel = "尖刺",
        name = "海胆",
    },
    reef_starfish = {
        team = "enemy", enemyType = "reef_starfish",
        hp = 20, maxHp = 20,
        atk = 5,
        attackRange = 1,
        attackLabel = "缠绕",
        regenHp = 4,         -- 每回合回复4HP
        name = "礁石海星",
    },
    -- ====== 第二章: 深渊海沟 ======
    jellyfish = {
        team = "enemy", enemyType = "jellyfish",
        hp = 28, maxHp = 28,
        atk = 10,
        attackRange = 1,
        attackLabel = "电击",
        name = "电水母",
    },
    iron_turtle = {
        team = "enemy", enemyType = "iron_turtle",
        hp = 55, maxHp = 55,
        atk = 11,
        def = 5,            -- 防御力5，减免所有受到的伤害
        attackRange = 1,
        attackLabel = "重击",
        name = "铁甲龟",
    },
    vortex_eel = {
        team = "enemy", enemyType = "vortex_eel",
        hp = 35, maxHp = 35,
        atk = 12,
        attackRange = 1,
        attackLabel = "撕咬",
        shuffleOnDeath = true, -- 死亡时打乱周围1格内的棋子位置
        name = "漩涡鳗",
    },
    hermit_crab = {
        team = "enemy", enemyType = "hermit_crab",
        hp = 38, maxHp = 38,
        atk = 9,
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
        atk = 14,
        attackRange = 1,
        attackLabel = "噬咬",
        teleportCooldown = 1,  -- 瞬移冷却（回合数）
        name = "幽灵鲨",
    },
    archerfish = {
        team = "enemy", enemyType = "archerfish",
        hp = 18, maxHp = 18,
        atk = 11,
        attackRange = 2,       -- 远程攻击2格
        attackLabel = "水弹",
        fleesWhenClose = true,  -- 英雄靠近时后退
        name = "射水鱼",
    },
    electric_ray = {
        team = "enemy", enemyType = "electric_ray",
        hp = 40, maxHp = 40,
        atk = 9,
        attackRange = 1,
        attackLabel = "放电",
        aoeDamage = true,      -- 攻击时对目标周围1格敌方也造成半额伤害
        aoeRadius = 1,
        name = "电鳐",
    },
    spine_anemone = {
        team = "enemy", enemyType = "spine_anemone",
        hp = 22, maxHp = 22,
        atk = 7,
        attackRange = 3,       -- 远程攻击3格
        attackLabel = "棘射",
        fleesWhenClose = true,  -- 英雄靠近时后退
        name = "棘刺海葵",
    },
    coral_priest = {
        team = "enemy", enemyType = "coral_priest",
        hp = 25, maxHp = 25,
        atk = 0,               -- 不攻击英雄
        attackRange = 1,
        attackLabel = "祝福",
        healAmount = 6,        -- 治疗友军+6HP
        buffATK = 3,           -- 增益友军+3ATK（1回合）
        isSupport = true,
        name = "珊瑚祭司",
    },

    splitting_urchin = {
        team = "enemy", enemyType = "splitting_urchin",
        hp = 26, maxHp = 26,
        atk = 7,
        attackRange = 1,
        attackLabel = "尖刺",
        splitThreshold = 0.5,  -- 首次被打到 50% HP 以下时分裂为 2 只小海胆
        _hasSplit = false,     -- 已分裂标记，每只只分裂一次
        name = "裂变海胆",
    },
    fission_flame = {
        team = "enemy", enemyType = "fission_flame",
        hp = 28, maxHp = 28,
        atk = 8,
        attackRange = 1,
        attackLabel = "烈焰",
        splitsOnDeath = true,  -- 死亡时分裂
        name = "裂焰精",
    },
    flame_shard = {
        team = "enemy", enemyType = "flame_shard",
        hp = 10, maxHp = 10,
        atk = 5,
        attackRange = 1,
        attackLabel = "灼击",
        isShard = true,        -- 碎片：不计入击杀目标，不再分裂
        name = "焰碎片",
    },
    -- ====== 第四章: 流沙荒漠 ======
    sand_scorpion = {
        team = "enemy", enemyType = "sand_scorpion",
        hp = 32, maxHp = 32,
        atk = 18,
        attackRange = 1,
        attackLabel = "蛰刺",
        name = "沙蝎",
    },
    quicksand_worm = {
        team = "enemy", enemyType = "quicksand_worm",
        hp = 18, maxHp = 18,
        atk = 14,
        attackRange = 1,
        attackLabel = "啃噬",
        name = "流沙虫",
    },
    sand_hawk = {
        team = "enemy", enemyType = "sand_hawk",
        hp = 22, maxHp = 22,
        atk = 20,
        attackRange = 2,
        attackLabel = "俯冲",
        fleesWhenClose = true,  -- 英雄靠近时后退
        name = "沙鹰",
    },
    -- ====== 第四章特殊机制敌人 ======
    sand_strider = {
        team = "enemy", enemyType = "sand_strider",
        hp = 16, maxHp = 16,
        atk = 18,
        attackRange = 99,       -- 全图攻击
        attackLabel = "沙暴射线",
        chargeTurns = 1,        -- 蓄力1回合后才能攻击
        _chargeCD = 0,          -- 当前蓄力状态（0=可蓄力，>0=蓄力中）
        _charged = false,       -- 蓄力完成标记
        name = "沙暴行者",
    },
    sand_rattler = {
        team = "enemy", enemyType = "sand_rattler",
        hp = 28, maxHp = 28,
        atk = 10,
        attackRange = 1,
        attackLabel = "咬击",
        counterMultiplier = 2.0, -- 反击时伤害倍率
        _enraged = false,        -- 狂怒状态（被攻击/跳过后激活）
        name = "沙漠响尾蛇",
    },
    venom_lizard = {
        team = "enemy", enemyType = "venom_lizard",
        hp = 24, maxHp = 24,
        atk = 11,
        attackRange = 1,
        attackLabel = "毒尾",
        poisonDamage = 5,       -- 中毒每回合伤害
        poisonDuration = 2,     -- 中毒持续回合
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
        hp = 350, maxHp = 350,
        atk = 21,  -- 原26，降低20%
        attackRange = 2,
        attackLabel = "熔岩喷射",
        name = "熔岩领主",
        isBoss = true,
        bossType = "lava_lord",
        -- Boss特殊属性
        phase = 1,
        shieldHp = 40,
        shieldMax = 70,
        eruptionCooldown = 0,   -- 熔岩喷发冷却（在英雄周围放置岩浆）
        shieldRegenCooldown = 0, -- 护盾再生冷却
        enraged = false,
    },
    -- 第三章Boss: 珊瑚守卫
    coral_guardian = {
        team = "enemy", enemyType = "boss",
        hp = 480, maxHp = 480,
        atk = 22,  -- 原27，降低20%
        attackRange = 2,
        attackLabel = "珊瑚冲撞",
        name = "珊瑚守卫",
        isBoss = true,
        bossType = "coral_guardian",
        phase = 1,
        shieldHp = 0,
        shieldMax = 80,          -- 护甲值
        shieldRegenCooldown = 0, -- 护甲重生冷却（每5回合重生一次）
        tideSurgeCooldown = 0,   -- 潮汐冲击冷却
        coralWallCooldown = 0,   -- 珊瑚墙冷却
        summonCooldown = 0,      -- 召唤冷却
        enraged = false,
    },
    -- 第一章Boss: 深渊海妖
    abyss_kraken = {
        team = "enemy", enemyType = "boss",
        hp = 450, maxHp = 450,
        atk = 20,  -- 原25，降低20%
        attackRange = 3,
        attackLabel = "触手鞭打",
        name = "深渊海妖",
        isBoss = true,
        bossType = "abyss_kraken",
        -- Boss特殊属性
        phase = 1,
        shieldHp = 0,
        shieldMax = 60,
        tentacleCooldown = 0,   -- 触手障碍冷却（在棋盘放置触手障碍物）
        whirlpoolCooldown = 0,  -- 漩涡冷却（拉拽英雄靠近）
        shrinkCooldown = 0,     -- 缩圈冷却（缩小可用棋盘范围）
        shrinkCount = 0,        -- 已缩圈次数（最多2次）
        enraged = false,
    },
    -- 第四章Boss: 沙丘巨虫
    sand_worm = {
        team = "enemy", enemyType = "boss",
        hp = 600, maxHp = 600,
        atk = 18,
        attackRange = 1,
        attackLabel = "吞噬",
        name = "沙丘巨虫",
        isBoss = true,
        bossType = "sand_worm",
        phase = 1,
        shieldHp = 0,
        shieldMax = 50,
        segments = 7,           -- 总节数（含头）
        burrowCooldown = 0,     -- 钻地冷却
        tailWhipCooldown = 0,   -- 尾部甩飞冷却
        sandstormCooldown = 0,  -- 巨岩投掷冷却
        sandFuryCooldown = 4,   -- 呼唤风沙冷却（首次延迟4回合）
        enraged = false,
    },
}

BattleData.CHAPTER_BOSS = {
    [1] = "abyss_kraken",
    [2] = "lava_lord",
    [3] = "coral_guardian",
    [4] = "sand_worm",
}

BattleData.BOSS_AURA = {
    abyss_kraken  = { range = 2, damage = 4, icon = "🌊", name = "深渊压迫", color = {60, 120, 200, 255} },
    -- lava_lord 灼烧光环已移除（改为祭坛破盾机制）
    coral_guardian = { range = 1, damage = 7, icon = "🪸", name = "珊瑚荆棘", color = {255, 120, 180, 255} },
    -- sand_worm 光环已移除（沙虫Boss不使用周边伤害光环）
}

BattleData.ITEM_TYPES = {
    health_potion     = { icon = "item_health_potion",     name = "小血瓶", desc = "回复20HP" },
    health_potion_big = { icon = "item_health_potion_big", name = "大血瓶", desc = "回满HP" },
    gold_bag          = { icon = "item_gold_bag",          name = "金币袋", desc = "获得3金币" },
    shield            = { icon = "item_shield",            name = "护盾",   desc = "下次受击伤害减半" },
}


return BattleData
