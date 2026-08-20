import assert from 'node:assert/strict';
import {
  EQUIPMENT_ITEMS, PITY_THRESHOLD, SLOT_ORDER, TALENT_COSTS,
  createMetaProgress, decomposeInventoryItems, equipInventoryItem,
  getCritRate, getEquipmentBonus, getGoldBonus, getHeroStats, getItemStats,
  getSetTier, pullEquipment, redeemCode, unequipSlot, upgradeTalent,
} from '../src/core/MetaGame.js';

function test(name, body) {
  try {
    body();
    console.log(`✓ ${name}`);
  } catch (error) {
    console.error(`✗ ${name}`);
    throw error;
  }
}

test('新存档与 Lua PlayerData.NewDefault 一致', () => {
  const meta = createMetaProgress();
  assert.equal(meta.gold, 0);
  assert.equal(meta.highestLevel, 1);
  assert.equal(meta.totalRuns, 0);
  assert.deepEqual(meta.talents, { hp: 0, atk: 0, def: 0, crit: 0, gold: 0 });
  assert.deepEqual(Object.keys(meta.equipment), SLOT_ORDER);
  assert.ok(SLOT_ORDER.every(slot => meta.equipment[slot] === null));
  assert.deepEqual(meta.usedCodes, {});
});

test('兑换码与原版奖励一致且单设备不可重复领取', () => {
  const meta = createMetaProgress();
  assert.equal(redeemCode(meta, ' bad-code ').ok, false);
  const master = redeemCode(meta, ' combomaster ');
  assert.deepEqual(master, { ok: true, code: 'COMBOMASTER', gold: 2400, desc: '连击大师' });
  assert.equal(meta.gold, 2400);
  assert.equal(redeemCode(meta, 'COMBOMASTER').ok, false);
  assert.equal(redeemCode(meta, 'combolegend').gold, 50000);
  assert.equal(meta.gold, 52400);
});

test('旧三槽装备会迁移，旧品阶会映射', () => {
  const meta = createMetaProgress({
    equipment: {
      weapon: { id: 'leap_axe', rarity: 'epic' },
      armor: { id: 'combo_vest', rarity: 'common' },
      accessory: { id: 'soul_pendant', rarity: 'rare' },
    },
    skills: [{ id: 'quake', level: 5 }],
  });
  assert.equal(meta.equipment.weapon.rarity, 'purple');
  assert.equal(meta.equipment.top_armor.rarity, 'blue');
  assert.equal(meta.equipment.necklace.rarity, 'blue');
  assert.equal('skills' in meta, false, '冒险技能不应成为永久 Meta 属性');
});

test('天赋花费和成长数值精确一致', () => {
  const meta = createMetaProgress({ gold: 10000 });
  assert.deepEqual(TALENT_COSTS, [20, 40, 80, 150, 280, 500, 850, 1400, 2200, 3500]);
  for (let i = 0; i < 10; i += 1) assert.equal(upgradeTalent(meta, 'atk').ok, true);
  assert.equal(upgradeTalent(meta, 'atk').ok, false);
  upgradeTalent(meta, 'hp');
  upgradeTalent(meta, 'def');
  upgradeTalent(meta, 'crit');
  upgradeTalent(meta, 'gold');
  assert.deepEqual(getHeroStats(meta), { hp: 110, maxHp: 110, attack: 35, defense: 2 });
  assert.equal(getCritRate(meta), 2);
  assert.equal(getGoldBonus(meta), 3);
});

test('装备倍率向下取整', () => {
  assert.deepEqual(getItemStats({ id: 'leap_axe', rarity: 'blue' }), { atk: 5 });
  assert.deepEqual(getItemStats({ id: 'leap_axe', rarity: 'purple' }), { atk: 10 });
  assert.deepEqual(getItemStats({ id: 'leap_axe', rarity: 'gold' }), { atk: 15 });
});

test('穿戴、替换、卸下与属性统计完整闭环', () => {
  const meta = createMetaProgress({ inventory: [
    { id: 'leap_axe', rarity: 'gold' },
    { id: 'combo_sword', rarity: 'purple' },
  ] });
  assert.equal(equipInventoryItem(meta, 0).ok, true);
  assert.deepEqual(getEquipmentBonus(meta), { atk: 15, def: 0, hp: 0, crit: 0 });
  assert.equal(equipInventoryItem(meta, 0).ok, true);
  assert.equal(meta.inventory[0].id, 'leap_axe');
  assert.equal(unequipSlot(meta, 'weapon').ok, true);
  assert.equal(meta.equipment.weapon, null);
  assert.equal(meta.inventory.length, 2);
});

test('保底第15抽产出不重复金装并重置计数', () => {
  const meta = createMetaProgress({
    gold: 1000,
    pityCounter: PITY_THRESHOLD - 1,
    inventory: [{ id: EQUIPMENT_ITEMS[0].id, rarity: 'gold' }],
  });
  const result = pullEquipment(meta, 1, () => 0);
  assert.equal(result.ok, true);
  assert.equal(result.results[0].rarity, 'gold');
  assert.notEqual(result.results[0].id, EQUIPMENT_ITEMS[0].id);
  assert.equal(meta.pityCounter, 0);
  assert.equal(meta.gold, 900);
});

test('自然出金也会重置保底', () => {
  const values = [0.99, 0];
  const meta = createMetaProgress({ gold: 100, pityCounter: 7 });
  const result = pullEquipment(meta, 1, () => values.shift() ?? 0);
  assert.equal(result.results[0].rarity, 'gold');
  assert.equal(meta.pityCounter, 0);
});

test('只有金色装备计入4/6与6/6套装', () => {
  const leapItems = EQUIPMENT_ITEMS.filter(item => item.setId === 'leap_pioneer');
  const meta = createMetaProgress();
  leapItems.forEach((item, index) => { meta.equipment[item.slot] = { id: item.id, rarity: index < 3 ? 'gold' : 'purple' }; });
  assert.equal(getSetTier(meta, 'leap_pioneer'), 0);
  meta.equipment[leapItems[3].slot].rarity = 'gold';
  assert.equal(getSetTier(meta, 'leap_pioneer'), 4);
  meta.equipment[leapItems[4].slot].rarity = 'gold';
  meta.equipment[leapItems[5].slot].rarity = 'gold';
  assert.equal(getSetTier(meta, 'leap_pioneer'), 6);
});

test('分解蓝紫金分别返还5/15/50金币', () => {
  const meta = createMetaProgress({ inventory: [
    { id: 'leap_axe', rarity: 'blue' },
    { id: 'combo_sword', rarity: 'purple' },
    { id: 'soul_scythe', rarity: 'gold' },
  ] });
  assert.deepEqual(decomposeInventoryItems(meta, [0, 1, 2]), { ok: true, gold: 70, count: 3 });
  assert.equal(meta.gold, 70);
  assert.equal(meta.inventory.length, 0);
});

console.log('MetaGame parity tests passed.');
