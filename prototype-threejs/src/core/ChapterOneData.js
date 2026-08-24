export const HERO_TEMPLATE = Object.freeze({ hp: 100, attack: 15, defense: 1 });

export const CHAPTER_ONE_STAGES = Object.freeze([
  { stage: 1, name: '浅海珊瑚', subtitle: '水流平缓', killTarget: 5, initial: 7, pool: ['slime', 'slime', 'slime'], spawnPool: ['slime', 'slime'] },
  { stage: 2, name: '水母群落', subtitle: '触手密布', killTarget: 6, initial: 8, pool: ['jellyfish', 'jellyfish', 'iron_turtle'], spawnPool: ['jellyfish', 'iron_turtle'] },
  { stage: 3, name: '沉船墓地', subtitle: '暗藏危机', killTarget: 6, initial: 8, pool: ['jellyfish', 'iron_turtle', 'archerfish'], spawnPool: ['jellyfish', 'iron_turtle', 'archerfish'] },
  { stage: 4, name: '深海暗流', subtitle: '漩涡涌动', killTarget: 7, initial: 9, pool: ['jellyfish', 'iron_turtle', 'vortex_eel', 'archerfish'], spawnPool: ['jellyfish', 'iron_turtle', 'vortex_eel'] },
  { stage: 5, name: '铁甲礁石', subtitle: '坚不可摧', killTarget: 7, initial: 9, pool: ['jellyfish', 'iron_turtle', 'vortex_eel', 'archerfish'], spawnPool: ['jellyfish', 'iron_turtle', 'vortex_eel'] },
  { stage: 6, name: '海沟峡谷', subtitle: '越来越深', killTarget: 8, initial: 10, pool: ['jellyfish', 'iron_turtle', 'vortex_eel', 'archerfish', 'electric_ray'], spawnPool: ['jellyfish', 'iron_turtle', 'vortex_eel', 'electric_ray'] },
  { stage: 7, name: '寄居蟹巢', subtitle: '壳中有壳', killTarget: 8, initial: 10, pool: ['jellyfish', 'iron_turtle', 'vortex_eel', 'hermit_crab', 'ghost_shark', 'archerfish', 'electric_ray'], spawnPool: ['jellyfish', 'iron_turtle', 'vortex_eel', 'ghost_shark'] },
  { stage: 8, name: '幽暗深渊', subtitle: '光线全无', killTarget: 9, initial: 11, pool: ['jellyfish', 'iron_turtle', 'vortex_eel', 'hermit_crab', 'ghost_shark', 'archerfish', 'electric_ray'], continuationPool: ['iron_turtle', 'vortex_eel', 'hermit_crab', 'ghost_shark', 'ghost_shark', 'archerfish', 'electric_ray', 'electric_ray'], spawnPool: ['jellyfish', 'iron_turtle', 'vortex_eel', 'ghost_shark'] },
  { stage: 9, name: '海妖前厅', subtitle: '触手蠕动', killTarget: 9, initial: 11, pool: ['jellyfish', 'iron_turtle', 'vortex_eel', 'hermit_crab', 'ghost_shark', 'archerfish', 'electric_ray'], continuationPool: ['iron_turtle', 'vortex_eel', 'hermit_crab', 'ghost_shark', 'ghost_shark', 'archerfish', 'electric_ray', 'electric_ray'], spawnPool: ['jellyfish', 'iron_turtle', 'vortex_eel', 'ghost_shark'] },
  { stage: 10, name: '深渊王座', subtitle: 'Boss: 深渊海妖', killTarget: 1, initial: 5, pool: ['jellyfish', 'iron_turtle', 'vortex_eel', 'archerfish', 'electric_ray'], spawnPool: ['jellyfish', 'iron_turtle', 'archerfish', 'electric_ray'], isBoss: true },
]);

export const ENEMY_TEMPLATES = Object.freeze({
  slime: { name: '史莱姆', hp: 25, attack: 5, defense: 0, range: 1, gold: 1 },
  jellyfish: { name: '电水母', hp: 28, attack: 8, defense: 0, range: 1, gold: 1 },
  iron_turtle: { name: '铁甲龟', hp: 55, attack: 9, defense: 5, range: 1, gold: 3 },
  vortex_eel: { name: '漩涡鳗', hp: 35, attack: 10, defense: 0, range: 1, gold: 2, shuffleOnDeath: true },
  hermit_crab: { name: '寄居蟹', hp: 38, attack: 7, defense: 0, range: 1, gold: 1, hasShell: true },
  ghost_shark: { name: '幽灵鲨', hp: 22, attack: 11, defense: 0, range: 1, gold: 2, teleportCooldown: 1 },
  archerfish: { name: '射水鱼', hp: 18, attack: 9, defense: 0, range: 2, gold: 2, fleesWhenClose: true },
  electric_ray: { name: '电鳐', hp: 40, attack: 7, defense: 0, range: 1, gold: 2, aoeDamage: true },
  abyss_kraken: {
    name: '深渊海妖', hp: 350, attack: 14, defense: 0, range: 3, gold: 10,
    isBoss: true, bossType: 'abyss_kraken', phase: 1, shieldHp: 0, shieldMax: 60,
    skillCooldown: 2, clawCooldown: 2, tentacleCooldown: 4, whirlpoolCooldown: 6,
  },
});

export const ENEMY_INTROS = Object.freeze({
  jellyfish: { icon: '🎐', name: '电水母', desc: '跳过它会被电击反伤' },
  iron_turtle: { icon: '🐢', name: '铁甲龟', desc: '高防御，受到伤害减免' },
  vortex_eel: { icon: '🌀', name: '漩涡鳗', desc: '死亡时打乱周围棋子' },
  hermit_crab: { icon: '🐚', name: '寄居蟹', desc: '缩壳时伤害减半' },
  ghost_shark: { icon: '🦈', name: '幽灵鲨', desc: '会瞬移到随机位置' },
  archerfish: { icon: '🐠', name: '射水鱼', desc: '远程攻击，靠近会后退' },
  electric_ray: { icon: '⚡', name: '电鳐', desc: '攻击会波及周围目标' },
});

export const COMBO_REWARDS = Object.freeze({
  2: { name: '追踪飞镖', color: '#ffb64c', duration: 1.25 },
  3: { name: '稻草人', color: '#c48cff', duration: 1.35 },
  4: { name: '六芒冲击波', color: '#60dfff', duration: 1.5 },
  5: { name: '生命虹吸', color: '#73edb3', duration: 1.65 },
  6: { name: '时间静止', color: '#8be5ff', duration: 1.45 },
  7: { name: '流星火雨', color: '#ff843e', duration: 2.25 },
  8: { name: '绝对反射', color: '#ffd56a', duration: 1.25 },
  9: { name: '特殊技能抉择', color: '#f5d7ff', duration: 0.8, deferred: true },
});

const skill = (id, name, color, maxLevel, describe) => ({ id, name, color, maxLevel, describe });

export const SKILLS = Object.freeze([
  skill('quake_land', '震地落', '#dc8c28', 5, lv => `跳跃落地时对周围${lv >= 3 ? 2 : 1}圈敌人造成${10 + lv * 5}伤害${lv >= 4 ? '；连跳>=3全场AOE' : ''}${lv >= 5 ? '；碎甲(DEF减半1回合)' : ''}`),
  skill('chain_lightning', '连锁闪电', '#64b4ff', 5, lv => `击杀敌人时闪电弹射${lv}次，每次${13 + lv * 2}伤${lv >= 3 ? '；毒雾电击相邻敌人' : ''}${lv >= 5 ? '；弹射后雷爆(范围10伤)' : ''}`),
  skill('vampiric_jump', '吸血跳', '#c83246', 5, lv => `跳杀敌人时回复${5 + lv * 3}%伤害为生命${lv >= 3 ? '；连击击杀+5临时ATK+12HP（上限+30ATK）' : ''}${lv >= 5 ? '；HP>80%时附带ATK×20%真实伤害' : ''}`),
  skill('thorns', '荆棘护甲', '#50c878', 5, lv => `受到攻击时反弹${20 + lv * 8}%伤害给敌人${lv >= 3 ? '；反弹→治疗50%；被攻+3护盾' : ''}${lv >= 5 ? '；护盾>10反弹+20%' : ''}`),
  skill('spike_trap', '地刺陷阱', '#b46450', 5, lv => `跳跃路径空格变地刺(${5 + lv * 5}伤,持续${4 + lv}回合)${lv >= 3 ? '；减速1回合' : ''}${lv >= 5 ? '；踩刺敌人受全伤害+20%' : ''}`),
  skill('blood_rage', '血怒', '#b41e1e', 5, lv => `生命值低于${lv >= 5 ? 30 : 50}%时，攻击力提升${20 + lv * 6}%${lv >= 5 ? '；ATK翻倍；免疫一次致死' : ''}`),
  skill('gravity_stomp', '重力践踏', '#a08250', 5, lv => `连续跳杀>=3次时，伤害提升${50 + lv * 22}%${lv >= 4 ? '；连跳加成上限提升（最高×3）' : ''}${lv >= 5 ? '；满级重击加成达+160%' : ''}`),
  skill('split_shot', '分裂弹', '#50c8dc', 5, lv => `击杀时发射${1 + Math.floor(lv / 2)}枚碎片，每枚${5 + lv * 5}伤害${lv >= 3 ? '；碎片穿透(伤害不递减)' : ''}${lv >= 5 ? '；碎片击杀再分裂1次' : ''}`),
  skill('hunter_mark', '猎手印记', '#ff783c', 5, lv => `自动标记血量最高的${lv >= 4 ? 2 : 1}个敌人，对其伤害+${20 + lv * 5}%${lv >= 3 ? '；印记敌人被击回复5HP' : ''}${lv >= 5 ? '；击杀印记敌人回复15%最大HP' : ''}`),
  skill('combo_shield', '连击护盾', '#3ca0dc', 5, lv => `每次跳跃+${2 + lv * 2}护盾(吸收伤害)(上限${10 + lv * 10})${lv >= 3 ? '；未消耗时回合结束反弹30%给周围敌人' : ''}${lv >= 5 ? '；5连击护盾翻倍' : ''}`),
  skill('glass_cannon', '玻璃大炮', '#ff6432', 5, lv => `最大生命 -${10 + lv * 5}%，攻击 +${15 + lv * 5}%`),
  skill('dawn_herald', '黎明使者', '#ffc850', 1, () => '首次受到致命伤害时不会死亡，恢复至30%HP（每次冒险仅一次）'),
  skill('step_strike', '踏步斩', '#dc5078', 5, lv => lv >= 5
    ? '每次移动时直接斩杀1个相邻敌人(Boss除外，Boss受30伤害)'
    : `每次移动时斩杀血量<=${Math.min(100, 30 + lv * 14)}%的相邻敌人；未达线则造成${5 + lv * 5}近战伤害(Boss除外)`),
  skill('collector', '收集者', '#b478c8', 5, lv => `对生命值低于${30 + lv * 5}%的敌人造成额外${lv === 5 ? 50 : 20 + lv * 10}%伤害`),
  skill('frost_mark', '冰霜印记', '#64c8ff', 5, lv => `攻击叠加冰霜印记，${lv === 1 ? 4 : lv < 4 ? 3 : 2}层时冻结敌人(跳过行动)${lv >= 3 ? '；冻结持续2回合' : ''}${lv >= 5 ? '；冻结时受伤+30%' : ''}`),
  skill('kingmaker', '棋步', '#dcb43c', 5, lv => `每${lv <= 3 ? 8 - lv : 4}轮行动后，下一跳可跳杀全图任意敌人${lv >= 3 ? '；棋步跳伤害+20%' : ''}${lv >= 5 ? '；棋步跳无视防御' : ''}`),
  skill('dart_storm', '飞镖风暴', '#ffa032', 5, lv => `2连跳飞镖变为${1 + lv}枚，首枚${30 + lv * 5}伤害，后续飞镖递减${lv >= 3 ? '；飞镖穿透(可命中同一敌人多次)' : ''}${lv >= 5 ? '；飞镖附带灼烧(每回合6伤害,2回合)' : ''}`),
  skill('damage_amp', '战意增幅', '#ff5050', 5, lv => `所有技能伤害提升${5 + lv * 3}%${lv >= 3 ? '；连跳>=4时额外+8%' : ''}${lv >= 5 ? '；击杀时叠加(最多+12%,战斗结束重置)' : ''}`),
  skill('silence_path', '寂灭之路', '#643ca0', 5, lv => `连跳经过的敌人被沉默${1 + Math.floor(lv / 2)}回合(无法攻击)，影响范围${lv >= 4 ? 2 : 1}格${lv >= 3 ? '；被沉默敌人受伤+15%' : ''}${lv >= 5 ? '；沉默结束时造成20固定伤害' : ''}`),
]);

export const SKILL_COMBOS = Object.freeze([
  { id: 'combo_thunder_quake', name: '雷震天罚', requires: ['chain_lightning', 'quake_land'], desc: '震地追加可弹射闪电' },
  { id: 'combo_blood_thorns', name: '血棘共生', requires: ['vampiric_jump', 'thorns'], desc: '荆棘反弹伤害50%转治疗；HP<50%时转化率额外+20%' },
  { id: 'combo_hunter_instinct', name: '猎杀本能', requires: ['hunter_mark', 'collector'], desc: '每次跳跃后处决全屏HP≤20%的小怪，每次回复10HP' },
  { id: 'combo_burning_rage', name: '焚身狂战', requires: ['blood_rage', 'glass_cannon'], desc: '血怒期间跳杀附加ATK×40%真伤；击杀回复3HP' },
  { id: 'combo_shard_minefield', name: '碎片雷区', requires: ['split_shot', 'spike_trap'], desc: '碎片落点变地刺(25伤2回合)；地刺被踩射出1枚碎片' },
]);

export const SKILL_BY_ID = Object.freeze(Object.fromEntries(SKILLS.map(entry => [entry.id, entry])));

export function stageData(stage) {
  return CHAPTER_ONE_STAGES[Math.max(1, Math.min(10, stage)) - 1];
}

export function stageScale(stage, continuing = false) {
  const accel = (stage - 1) / 8;
  const bonus = accel * accel;
  return continuing
    ? { hp: 1 + 0.10 * (stage - 1) + 0.30 * bonus, attack: 1 + 0.07 * (stage - 1) + 0.20 * bonus }
    : { hp: 1 + 0.08 * (stage - 1) + 0.20 * bonus, attack: 1 + 0.05 * (stage - 1) + 0.15 * bonus };
}

export function skillChoiceView(id, level = 0) {
  const def = SKILL_BY_ID[id];
  const nextLevel = Math.min(def.maxLevel, level + 1);
  return { ...def, level: nextLevel, desc: def.describe(nextLevel) };
}
