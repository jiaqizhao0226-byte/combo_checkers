export const SAVE_VERSION = 2;

export const SLOT_ORDER = ['weapon', 'necklace', 'helmet', 'top_armor', 'bottom_armor', 'shoes'];
export const SLOT_NAMES = {
  weapon: '武器', necklace: '项链', helmet: '头盔',
  top_armor: '上衣', bottom_armor: '下衣', shoes: '鞋子',
};

export const TALENTS = [
  { id: 'hp', name: '生命强化', icon: '❤️', desc: '基础生命值', bonusPerLevel: 10, maxLevel: 10, stat: 'hp' },
  { id: 'atk', name: '攻击强化', icon: '⚔️', desc: '基础攻击力', bonusPerLevel: 2, maxLevel: 10, stat: 'atk' },
  { id: 'def', name: '防御强化', icon: '🛡️', desc: '基础防御力', bonusPerLevel: 1, maxLevel: 10, stat: 'def' },
  { id: 'crit', name: '暴击直觉', icon: '💥', desc: '暴击率', bonusPerLevel: 2, maxLevel: 10, stat: 'crit' },
  { id: 'gold', name: '点金手', icon: '💰', desc: '金币加成', bonusPerLevel: 3, maxLevel: 10, stat: 'gold' },
];

export const TALENT_COSTS = [20, 40, 80, 150, 280, 500, 850, 1400, 2200, 3500];

export const RARITIES = [
  { id: 'blue', name: '蓝色', color: '#64b4ff', weight: 75, multiplier: 0.85, decompose: 5 },
  { id: 'purple', name: '紫色', color: '#c878ff', weight: 22, multiplier: 1.5, decompose: 15 },
  { id: 'gold', name: '金色', color: '#ffd700', weight: 3, multiplier: 2.2, decompose: 50 },
];

export const SETS = [
  { id: 'leap_pioneer', name: '金色套装-飞跃先锋', shortName: '飞跃先锋', icon: '🦅', color: '#50c878', desc4: '可跳过2连续敌人', desc6: '可跳过3连续敌人' },
  { id: 'combo_mastery', name: '金色套装-连击心得', shortName: '连击心得', icon: '🔥', color: '#ff8c28', desc4: '50%概率combo+1', desc6: '100%概率combo+1' },
  { id: 'soul_hunter', name: '金色套装-嗜血猎魂', shortName: '嗜血猎魂', icon: '🩸', color: '#dc283c', desc4: '击杀回血', desc6: '低血触发血怒叠层' },
];

export const EQUIPMENT_ITEMS = [
  { id: 'leap_axe', name: '先锋战斧', nameBlue: '铁斧', namePurple: '精钢斧', icon: '🦅', slot: 'weapon', setId: 'leap_pioneer', stats: { atk: 7 }, desc: '开拓者的巨斧' },
  { id: 'leap_charm', name: '先锋护符', nameBlue: '木护符', namePurple: '翡翠护符', icon: '🦅', slot: 'necklace', setId: 'leap_pioneer', stats: { crit: 4 }, desc: '先锋之力护符' },
  { id: 'leap_helm', name: '先锋角盔', nameBlue: '皮盔', namePurple: '银角盔', icon: '🦅', slot: 'helmet', setId: 'leap_pioneer', stats: { def: 3 }, desc: '冲锋号角头盔' },
  { id: 'leap_plate', name: '先锋铠甲', nameBlue: '链甲', namePurple: '秘银甲', icon: '🦅', slot: 'top_armor', setId: 'leap_pioneer', stats: { def: 3 }, desc: '先锋者的重甲' },
  { id: 'leap_guards', name: '先锋战裙', nameBlue: '布裙甲', namePurple: '锁环裙甲', icon: '🦅', slot: 'bottom_armor', setId: 'leap_pioneer', stats: { hp: 28 }, desc: '先锋者的裙甲' },
  { id: 'leap_boots', name: '先锋跃靴', nameBlue: '草鞋', namePurple: '疾风靴', icon: '🦅', slot: 'shoes', setId: 'leap_pioneer', stats: { hp: 22 }, desc: '弹跳增强之靴' },
  { id: 'combo_sword', name: '心得之剑', nameBlue: '短剑', namePurple: '利刃剑', icon: '🔥', slot: 'weapon', setId: 'combo_mastery', stats: { atk: 5 }, desc: '领悟连击的剑' },
  { id: 'combo_trinket', name: '心得挂饰', nameBlue: '铜挂饰', namePurple: '琥珀挂饰', icon: '🔥', slot: 'necklace', setId: 'combo_mastery', stats: { crit: 6 }, desc: '连击经验之饰' },
  { id: 'combo_band', name: '心得发带', nameBlue: '麻发带', namePurple: '丝绒发带', icon: '🔥', slot: 'helmet', setId: 'combo_mastery', stats: { def: 2 }, desc: '专注连击的发带' },
  { id: 'combo_vest', name: '心得战衣', nameBlue: '粗布衣', namePurple: '织锦衣', icon: '🔥', slot: 'top_armor', setId: 'combo_mastery', stats: { def: 2 }, desc: '轻便的战斗衣' },
  { id: 'combo_belt', name: '心得腰带', nameBlue: '皮腰带', namePurple: '镶石腰带', icon: '🔥', slot: 'bottom_armor', setId: 'combo_mastery', stats: { hp: 20 }, desc: '连击者的腰带' },
  { id: 'combo_kicks', name: '心得快靴', nameBlue: '布靴', namePurple: '轻羽靴', icon: '🔥', slot: 'shoes', setId: 'combo_mastery', stats: { hp: 16 }, desc: '快速反应之靴' },
  { id: 'soul_scythe', name: '猎魂镰', nameBlue: '铁镰刀', namePurple: '猩红镰刀', icon: '🩸', slot: 'weapon', setId: 'soul_hunter', stats: { atk: 9 }, desc: '饮血方能长鸣' },
  { id: 'soul_pendant', name: '血滴吊坠', nameBlue: '骨头坠', namePurple: '红玉坠', icon: '🩸', slot: 'necklace', setId: 'soul_hunter', stats: { crit: 5 }, desc: '凝固的鲜血吊坠' },
  { id: 'soul_mask', name: '嗜血面罩', nameBlue: '皮面罩', namePurple: '铁牙面罩', icon: '🩸', slot: 'helmet', setId: 'soul_hunter', stats: { def: 2 }, desc: '猎手的血色面罩' },
  { id: 'soul_armor', name: '猎魂战甲', nameBlue: '皮甲', namePurple: '血纹甲', icon: '🩸', slot: 'top_armor', setId: 'soul_hunter', stats: { def: 3 }, desc: '以猎物血肉锻造' },
  { id: 'soul_greaves', name: '猩红护腿', nameBlue: '布护腿', namePurple: '猩红裙甲', icon: '🩸', slot: 'bottom_armor', setId: 'soul_hunter', stats: { hp: 22 }, desc: '染红的猎手护腿' },
  { id: 'soul_boots', name: '猩血战靴', nameBlue: '软皮靴', namePurple: '血迹战靴', icon: '🩸', slot: 'shoes', setId: 'soul_hunter', stats: { hp: 18 }, desc: '踏血而行的战靴' },
];

export const PULL_COST_SINGLE = 100;
export const PULL_COST_TRIPLE = 260;
export const PITY_THRESHOLD = 15;

const rarityMigrate = { common: 'blue', rare: 'blue', epic: 'purple' };
const itemById = Object.fromEntries(EQUIPMENT_ITEMS.map(item => [item.id, item]));
const rarityById = Object.fromEntries(RARITIES.map(rarity => [rarity.id, rarity]));

const clampInt = (value, min, max) => Math.max(min, Math.min(max, Math.floor(Number(value) || 0)));
const cleanItem = item => {
  if (!item || !itemById[item.id]) return null;
  const rarity = rarityMigrate[item.rarity] || item.rarity;
  if (!rarityById[rarity]) return null;
  return { id: item.id, rarity };
};

export function createMetaProgress(stored = {}) {
  const oldEquipment = stored.equipment || {};
  const equipment = Object.fromEntries(SLOT_ORDER.map(slot => {
    let source = oldEquipment[slot];
    if (slot === 'necklace' && source == null) source = oldEquipment.accessory;
    if (slot === 'top_armor' && source == null) source = oldEquipment.armor;
    return [slot, cleanItem(source)];
  }));
  return {
    saveVersion: SAVE_VERSION,
    gold: Math.max(0, Math.floor(Number(stored.gold) || 0)),
    talents: Object.fromEntries(TALENTS.map(talent => [talent.id, clampInt(stored.talents?.[talent.id], 0, talent.maxLevel)])),
    equipment,
    inventory: Array.isArray(stored.inventory) ? stored.inventory.map(cleanItem).filter(Boolean) : [],
    pityCounter: clampInt(stored.pityCounter, 0, PITY_THRESHOLD - 1),
    highestLevel: Math.max(1, Math.floor(Number(stored.highestLevel) || 1)),
    totalRuns: Math.max(0, Math.floor(Number(stored.totalRuns) || 0)),
    runsAtHighest: Math.max(0, Math.floor(Number(stored.runsAtHighest) || 0)),
    highestEndlessWave: Math.max(0, Math.floor(Number(stored.highestEndlessWave) || 0)),
    tutorialSpawnSeen: Boolean(stored.tutorialSpawnSeen),
    comboTutorialSeen: Boolean(stored.comboTutorialSeen),
    scarecrowTutorialSeen: Boolean(stored.scarecrowTutorialSeen),
    multiHopTutorialSeen: Boolean(stored.multiHopTutorialSeen),
    chainJumpTutorialSeen: Boolean(stored.chainJumpTutorialSeen),
    wheelIntroSeen: Boolean(stored.wheelIntroSeen),
    seenComboTiers: stored.seenComboTiers && typeof stored.seenComboTiers === 'object' ? { ...stored.seenComboTiers } : {},
    seenEnemyTypes: stored.seenEnemyTypes && typeof stored.seenEnemyTypes === 'object' ? { ...stored.seenEnemyTypes } : {},
    usedCodes: stored.usedCodes && typeof stored.usedCodes === 'object' ? { ...stored.usedCodes } : {},
  };
}

const REDEEM_CODES = {
  COMBOMASTER: { gold: 2400, desc: '连击大师' },
  COMBOLEGEND: { gold: 50000, desc: '连击传奇' },
};

export function redeemCode(meta, rawCode) {
  const code = String(rawCode || '').trim().toUpperCase();
  if (!code) return { ok: false, error: '请输入兑换码' };
  const reward = REDEEM_CODES[code];
  if (!reward) return { ok: false, error: '无效的兑换码' };
  if (!meta.usedCodes || typeof meta.usedCodes !== 'object') meta.usedCodes = {};
  if (meta.usedCodes[code]) return { ok: false, error: '此兑换码已使用过' };
  meta.usedCodes[code] = true;
  meta.gold += reward.gold;
  return { ok: true, code, gold: reward.gold, desc: reward.desc };
}

export function getTalentBonus(meta) {
  const bonus = { atk: 0, def: 0, hp: 0, crit: 0, gold: 0 };
  TALENTS.forEach(talent => { bonus[talent.stat] += (meta.talents[talent.id] || 0) * talent.bonusPerLevel; });
  return bonus;
}

export function getItemDefinition(id) { return itemById[id] || null; }

export function getItemStats(item) {
  const definition = itemById[item?.id];
  const rarity = rarityById[rarityMigrate[item?.rarity] || item?.rarity];
  if (!definition || !rarity) return {};
  return Object.fromEntries(Object.entries(definition.stats).map(([stat, value]) => [stat, Math.floor(value * rarity.multiplier)]));
}

export function getItemDisplay(item) {
  const definition = itemById[item?.id];
  const rarity = rarityById[rarityMigrate[item?.rarity] || item?.rarity];
  if (!definition || !rarity) return null;
  const name = rarity.id === 'blue' ? definition.nameBlue : rarity.id === 'purple' ? definition.namePurple : definition.name;
  return { ...definition, name, rarity, stats: getItemStats(item) };
}

export function getEquipmentBonus(meta) {
  const bonus = { atk: 0, def: 0, hp: 0, crit: 0 };
  SLOT_ORDER.forEach(slot => Object.entries(getItemStats(meta.equipment[slot])).forEach(([stat, value]) => { bonus[stat] += value; }));
  return bonus;
}

export function getTotalBonus(meta) {
  const talent = getTalentBonus(meta);
  const equipment = getEquipmentBonus(meta);
  return { atk: talent.atk + equipment.atk, def: talent.def + equipment.def, hp: talent.hp + equipment.hp };
}

export function getCritRate(meta) { const t = getTalentBonus(meta); const e = getEquipmentBonus(meta); return t.crit + e.crit; }
export function getGoldBonus(meta) { return getTalentBonus(meta).gold; }
export function getHeroStats(meta) {
  const bonus = getTotalBonus(meta);
  return { hp: 100 + bonus.hp, maxHp: 100 + bonus.hp, attack: 15 + bonus.atk, defense: 1 + bonus.def };
}

export function getSetCount(meta, setId) {
  return SLOT_ORDER.reduce((count, slot) => {
    const item = meta.equipment[slot];
    return count + (item?.rarity === 'gold' && itemById[item.id]?.setId === setId ? 1 : 0);
  }, 0);
}

export function getSetTier(meta, setId) { const count = getSetCount(meta, setId); return count >= 6 ? 6 : count >= 4 ? 4 : 0; }
export function getSetEffects(meta) { return Object.fromEntries(SETS.map(set => [set.id, getSetTier(meta, set.id)])); }

export function upgradeTalent(meta, talentId) {
  const talent = TALENTS.find(entry => entry.id === talentId);
  if (!talent) return { ok: false, error: '天赋不存在' };
  const level = meta.talents[talentId] || 0;
  if (level >= talent.maxLevel) return { ok: false, error: '已满级' };
  const cost = TALENT_COSTS[level];
  if (meta.gold < cost) return { ok: false, error: `金币不足（需要 ${cost}）` };
  meta.gold -= cost;
  meta.talents[talentId] = level + 1;
  return { ok: true, cost, level: level + 1 };
}

const randomIndex = (rng, length) => Math.min(length - 1, Math.floor(rng() * length));
function ownedGoldIds(meta) {
  const owned = new Set();
  [...meta.inventory, ...SLOT_ORDER.map(slot => meta.equipment[slot]).filter(Boolean)].forEach(item => {
    if (item.rarity === 'gold') owned.add(item.id);
  });
  return owned;
}

function pickItem(meta, rarity, rng) {
  let candidates = EQUIPMENT_ITEMS;
  if (rarity === 'gold') {
    const owned = ownedGoldIds(meta);
    const missing = EQUIPMENT_ITEMS.filter(item => !owned.has(item.id));
    if (missing.length) candidates = missing;
  }
  return { id: candidates[randomIndex(rng, candidates.length)].id, rarity };
}

function rollRarity(rng) {
  const roll = 1 + Math.floor(rng() * 100);
  let cumulative = 0;
  for (const rarity of RARITIES) {
    cumulative += rarity.weight;
    if (roll <= cumulative) return rarity.id;
  }
  return 'blue';
}

export function pullEquipment(meta, count = 1, rng = Math.random) {
  const pullCount = count === 1 ? 1 : 3;
  const cost = pullCount === 1 ? PULL_COST_SINGLE : PULL_COST_TRIPLE;
  if (meta.gold < cost) return { ok: false, error: `金币不足（需要 ${cost}）`, results: [] };
  meta.gold -= cost;
  const results = [];
  for (let index = 0; index < pullCount; index += 1) {
    meta.pityCounter += 1;
    let rarity = meta.pityCounter >= PITY_THRESHOLD ? 'gold' : rollRarity(rng);
    const item = pickItem(meta, rarity, rng);
    if (rarity === 'gold') meta.pityCounter = 0;
    meta.inventory.push(item);
    results.push(item);
  }
  return { ok: true, cost, results };
}

export function equipInventoryItem(meta, inventoryIndex) {
  const item = meta.inventory[inventoryIndex];
  const definition = itemById[item?.id];
  if (!definition) return { ok: false, error: '装备不存在' };
  const oldItem = meta.equipment[definition.slot];
  meta.inventory.splice(inventoryIndex, 1);
  meta.equipment[definition.slot] = item;
  if (oldItem) meta.inventory.push(oldItem);
  return { ok: true, slot: definition.slot, item, oldItem };
}

export function unequipSlot(meta, slot) {
  if (!SLOT_ORDER.includes(slot) || !meta.equipment[slot]) return { ok: false, error: '该槽位没有装备' };
  const item = meta.equipment[slot];
  meta.equipment[slot] = null;
  meta.inventory.push(item);
  return { ok: true, item };
}

export function decomposeInventoryItems(meta, indices) {
  const unique = [...new Set(indices)].filter(index => Number.isInteger(index)).sort((a, b) => b - a);
  let gold = 0;
  let count = 0;
  unique.forEach(index => {
    const item = meta.inventory[index];
    if (!item) return;
    gold += rarityById[item.rarity]?.decompose || 5;
    meta.inventory.splice(index, 1);
    count += 1;
  });
  meta.gold += gold;
  return { ok: count > 0, gold, count };
}
