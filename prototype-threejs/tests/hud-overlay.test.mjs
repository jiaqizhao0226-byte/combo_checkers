import assert from 'node:assert/strict';

import { createMetaProgress } from '../src/core/MetaGame.js';
import { createHudOverlay } from '../src/wechat/HudOverlay.js';

const drawnText = [];
function fakeCanvas() {
  const context = new Proxy({
    beginPath() {}, moveTo() {}, lineTo() {}, quadraticCurveTo() {}, closePath() {},
    fill() {}, stroke() {}, fillRect() {}, clearRect() {}, fillText(value) { drawnText.push(String(value)); }, arc() {},
    setTransform() {}, scale() {}, save() {}, restore() {}, translate() {},
  }, {
    get(target, key) { return key in target ? target[key] : 0; },
    set(target, key, value) { target[key] = value; return true; },
  });
  return { width: 1, height: 1, getContext: () => context };
}

const viewportWidth = 390;
const viewportHeight = 844;
const renderer = { autoClear: true, clearDepth() {}, render() {} };
const hud = createHudOverlay(renderer, viewportWidth, viewportHeight, 1, fakeCanvas, { safeAreaTop: 47 });
const inventory = [
  { id: 'leap_axe', rarity: 'gold' }, { id: 'combo_sword', rarity: 'purple' },
  { id: 'soul_scythe', rarity: 'blue' }, { id: 'leap_boots', rarity: 'blue' },
  { id: 'combo_trinket', rarity: 'purple' }, { id: 'soul_mask', rarity: 'blue' },
  { id: 'leap_helm', rarity: 'gold' },
];
const meta = createMetaProgress({ gold: 999, highestLevel: 11, totalRuns: 4, inventory });
const baseMenu = {
  mode: 'menu', meta,
  menuState: {
    tab: 'equip', notice: '', inventoryPage: 0, selectedInventoryIndex: 0,
    decomposeMode: false, decomposeSelectedIndices: [], shopResults: [],
    shopSetIndex: 0, shopRulesOpen: false, shopResultOpen: false, shopResultOpenedAt: 0,
    selectedChapter: 1, guildTab: 'adventure', redeemOpen: false, redeemCode: '',
    settingsOpen: false,
  },
};

assert.doesNotThrow(() => hud.draw(baseMenu), '装备详情弹层应可渲染完整金装与套装说明');
assert.equal(drawnText.includes('Ch.1  Combo Checkers'), false, '主界面顶栏不应保留冗长游戏标题');
assert.equal(drawnText.includes('金币+0%'), false, '主界面顶栏不应显示次要金币加成文字');
assert.equal(drawnText.includes('冒险进度'), false, '主界面顶栏应保持最简信息层级');
assert.equal(hud.hitTest(330, 220), 'detail_close');
assert.equal(hud.hitTest(80, viewportHeight - 160), 'equip_selected');

const bulkMenu = {
  ...baseMenu,
  menuState: { ...baseMenu.menuState, selectedInventoryIndex: null, decomposeMode: true, decomposeSelectedIndices: [0, 2, 3] },
};
assert.doesNotThrow(() => hud.draw(bulkMenu), '批量分解多选状态应可渲染');
assert.equal(hud.hitTest(30, viewportHeight - 170), 'bulk_blue');
assert.equal(hud.hitTest(viewportWidth - 40, viewportHeight - 170), 'bulk_confirm');

for (const menuState of [
  { ...baseMenu.menuState, tab: 'shop', selectedInventoryIndex: null, shopSetIndex: 2 },
  { ...baseMenu.menuState, tab: 'adventure', selectedInventoryIndex: null, selectedChapter: 0 },
  { ...baseMenu.menuState, tab: 'adventure', selectedInventoryIndex: null, selectedChapter: 2 },
  { ...baseMenu.menuState, tab: 'guild', selectedInventoryIndex: null, guildTab: 'endless' },
]) assert.doesNotThrow(() => hud.draw({ mode: 'menu', meta, menuState }));

drawnText.length = 0;
hud.draw(baseMenu);
for (const legacyIcon of ['🛒', '🛡️', '🗺️', '⭐', '🏰']) {
  assert.equal(drawnText.includes(legacyIcon), false, `底栏不应继续复用 ${legacyIcon} 旧图标资产`);
}
assert.ok(drawnText.includes('装备'), '选中的装备 Tab 应显示文字');
for (const hiddenLabel of ['商店', '冒险', '天赋', '公会']) {
  assert.equal(drawnText.includes(hiddenLabel), false, `未选中的 ${hiddenLabel} Tab 不应显示文字`);
}
assert.equal(hud.hitTest(viewportWidth * 0.5, viewportHeight - 48), 'tab_adventure', '放大的底栏仍应保持五等分点击区域');

hud.draw({ ...baseMenu, menuState: { ...baseMenu.menuState, tab: 'adventure', selectedInventoryIndex: null } });
assert.equal(hud.hitTest(viewportWidth * 0.5, viewportHeight - 232), 'start', '开始冒险按钮应上移并保持可点击');

const rulesMenu = {
  ...baseMenu,
  menuState: { ...baseMenu.menuState, tab: 'shop', selectedInventoryIndex: null, shopRulesOpen: true },
};
assert.doesNotThrow(() => hud.draw(rulesMenu), '抽取规则弹窗应可渲染');
assert.equal(hud.hitTest(viewportWidth * 0.5, viewportHeight * 0.5 + 210), 'shop_rules_close');
assert.equal(hud.hitTest(40, viewportHeight - 60), null, '规则弹窗应拦截底层导航');

const resultMenu = {
  ...baseMenu,
  menuState: {
    ...baseMenu.menuState, tab: 'shop', selectedInventoryIndex: null, shopResultOpen: true,
    shopResults: inventory.slice(0, 3), shopResultOpenedAt: Date.now() - 1000,
  },
};
assert.doesNotThrow(() => hud.draw(resultMenu), '三抽结果弹窗应可渲染');
assert.equal(hud.hitTest(viewportWidth * 0.5, viewportHeight * 0.5 + 180), 'shop_result_close');
assert.equal(hud.hitTest(viewportWidth - 40, 300), null, '结果弹窗应拦截海报箭头');

const redeemMenu = {
  ...baseMenu,
  menuState: { ...baseMenu.menuState, selectedInventoryIndex: null, redeemOpen: true, redeemCode: 'COMBOMASTER' },
};
assert.doesNotThrow(() => hud.draw(redeemMenu), '兑换码弹窗应可渲染');
assert.equal(hud.hitTest(60, viewportHeight * 0.5 + 145), 'redeem_cancel');
assert.equal(hud.hitTest(viewportWidth - 70, viewportHeight * 0.5 + 145), 'redeem_submit');
assert.equal(hud.hitTest(40, viewportHeight - 60), null, '兑换码弹窗应拦截底层导航');

const settingsMenu = {
  ...baseMenu,
  menuState: {
    ...baseMenu.menuState, selectedInventoryIndex: null, settingsOpen: true,
    audioState: { bgmVolume: 0.5, sfxVolume: 0.8, comboSoundStyle: 'scale', currentBgm: 'menu' },
  },
};
assert.doesNotThrow(() => hud.draw(settingsMenu), '音频设置弹窗应可渲染');
assert.equal(hud.hitTest(60, viewportHeight * 0.5 - 115), 'bgm_minus');
assert.equal(hud.hitTest(viewportWidth - 60, viewportHeight * 0.5 - 41), 'sfx_plus');
assert.equal(hud.hitTest(viewportWidth * 0.5, viewportHeight * 0.5 + 225), 'settings_close');

const baseBattle = {
  mode: 'battle', meta, menuState: baseMenu.menuState,
  battleUi: {
    settingsOpen: false, guideOpen: false, guidePage: 0, skillsOpen: false, skillsPage: 0,
    exitConfirmOpen: false,
    audioState: { bgmVolume: 0.5, sfxVolume: 0.8, comboSoundStyle: 'scale', currentBgm: 'battle_calm' },
  },
  stage: 2, chapterName: '深渊海沟', stageName: '水母群落', turn: 1, gold: 0,
  hero: { hp: 100, maxHp: 100, shield: 0 }, drainShield: 0,
  kills: 0, killTarget: 6, isBossStage: false, boss: null, bossIntent: null,
  cameraZoom: 1.45, threatPreview: [], message: '选择落点', lastReward: null,
  plan: [], result: null, announcement: null, wheelResult: null, wheelSkillChoices: [],
  tutorialOverlay: null, enemyIntro: [], skills: { quake_land: 3, chain_lightning: 2 },
};
assert.doesNotThrow(() => hud.draw(baseBattle), '战斗内工具栏应可渲染');
assert.equal(drawnText.includes('通关目标'), false, '战斗顶栏不应保留冗长目标说明');
assert.equal(drawnText.includes('金币 0'), false, '战斗顶栏不应显示次要金币信息');
assert.equal(hud.hitTest(40, viewportHeight - 102), 'guide_open');
assert.equal(hud.hitTest(viewportWidth - 40, viewportHeight - 102), 'battle_skills_open');
assert.equal(hud.hitTest(30, 112), null, '战斗 HUD 不应保留缩放减号的隐藏热区');
assert.equal(hud.hitTest(viewportWidth - 30, 112), null, '战斗 HUD 不应保留缩放加号的隐藏热区');
assert.equal(hud.hitTest(40, viewportHeight - 40), null, '战斗 HUD 不应保留撤销按钮的隐藏热区');
assert.equal(hud.hitTest(viewportWidth - 40, viewportHeight - 40), null, '战斗 HUD 不应保留确认跳跃按钮的隐藏热区');
for (const removedText of ['撤销', '确认跳跃', '选择落点']) {
  assert.equal(drawnText.includes(removedText), false, `战斗 HUD 不应显示“${removedText}”`);
}

drawnText.length = 0;
const tutorialBattle = {
  ...baseBattle,
  tutorialOverlay: {
    id: 'board', interaction: 'board', stepLabel: '1 / 5', title: '移动企鹅',
    desc: '点击相邻空格移动。你完成一次行动后，敌人才会开始它们的回合。',
    hint: '点击绿色落点', accent: '#79f1cf',
  },
  tutorialSpotlight: {
    points: [{ x: 150, y: 470 }, { x: 220, y: 430 }], target: { x: 220, y: 430 }, radius: 40,
    actionBounds: { x: 184, y: 394, width: 72, height: 72 },
  },
  tutorialTime: 0.4,
};
assert.doesNotThrow(() => hud.draw(tutorialBattle), '棋盘教学应渲染挖洞式聚光灯');
for (const label of ['1 / 5', '移动企鹅', '点击绿色落点']) {
  assert(drawnText.some(text => text.includes(label)), `聚光教程应显示“${label}”`);
}
assert.equal(hud.hitTest(220, 430), 'tutorial_action', '只有聚光灯目标区域应转交棋盘操作');
assert.equal(hud.hitTest(40, 430), 'tutorial_block', '聚光灯外必须拦截误触');

const comboTutorialBattle = {
  ...baseBattle,
  tutorialOverlay: {
    id: 'combo', interaction: 'continue', stepLabel: '5 / 5', title: '2 连击奖励',
    desc: '追踪飞镖已触发。整条路线执行完成后统一结算奖励。',
    hint: '点击继续战斗', accent: '#ffb64c',
  },
  tutorialSpotlight: {
    points: [{ x: 195, y: 430 }], target: { x: 195, y: 430 }, radius: 44,
    actionBounds: { x: 155, y: 390, width: 80, height: 80 },
  },
};
assert.doesNotThrow(() => hud.draw(comboTutorialBattle), '连击教学应保留聚光目标并提供继续按钮');
assert.equal(hud.hitTest(viewportWidth * 0.5, 650), 'tutorial_close');
assert.equal(hud.hitTest(12, 430), 'tutorial_block');

const vfxBattle = {
  ...baseBattle,
  battleUi: {
    ...baseBattle.battleUi,
    vfxTestEnabled: true, vfxTestOpen: false, vfxTestLast: '', vfxTestLastId: '',
  },
};
assert.doesNotThrow(() => hud.draw(vfxBattle), 'VFX 测试开关开启时应显示局内入口');
assert.equal(hud.hitTest(viewportWidth * 0.5, viewportHeight - 102), 'battle_vfx_test_open');
const vfxPanelBattle = {
  ...vfxBattle,
  battleUi: { ...vfxBattle.battleUi, vfxTestOpen: true },
};
assert.doesNotThrow(() => hud.draw(vfxPanelBattle), 'VFX 测试入口应打开独立测试面板');
for (const label of [
  '跳斩命中', '蓄力重斩', '连锁闪电', '震地落', '追踪飞镖', '稻草人模型',
  '四连 · 六芒冲击波', '五连 · 生命虹吸', '六连 · 时间静止', '七连 · 流星火雨', '八连 · 绝对反射',
  '技能三选一',
]) {
  assert.equal(drawnText.includes(label), true, `VFX 测试面板应显示“${label}”按钮`);
}
assert.equal(hud.hitTest(105, 265), 'battle_vfx_test_impact_light');
assert.equal(hud.hitTest(viewportWidth - 46, 190), 'battle_vfx_test_close');
assert.equal(hud.hitTest(viewportWidth * 0.5, 640), 'battle_vfx_test_clear');
assert.equal(hud.hitTest(8, viewportHeight * 0.5), 'battle_vfx_test_block', '测试面板必须拦截底层棋盘点击');
const skillPreviewBattle = {
  ...vfxBattle,
  battleUi: {
    ...vfxBattle.battleUi,
    skillChoicePreview: [
      { id: 'quake_land', name: '震地落', color: '#dc8c28', level: 1, desc: '跳跃落地时对周围1圈敌人造成15伤害' },
      { id: 'combo_shield', name: '连击护盾', color: '#3ca0dc', level: 2, desc: '每次跳跃增加护盾，吸收下一次伤害' },
      { id: 'frost_mark', name: '冰霜印记', color: '#64c8ff', level: 3, desc: '攻击叠加冰霜印记，触发时冻结敌人' },
    ],
  },
};
assert.doesNotThrow(() => hud.draw(skillPreviewBattle), '微信测试台应能直接预览新版技能三选一界面');
for (const label of ['界面测试 · 关卡奖励', '选择一项能力', '范围打击', '护盾防御', '冻结控制', '新技能', 'Lv.1 → 2']) {
  assert.equal(drawnText.includes(label), true, `新版三选一应显示“${label}”`);
}
assert.equal(hud.hitTest(100, 250), 'battle_skill_preview_0');
assert.equal(hud.hitTest(8, viewportHeight * 0.5), 'battle_skill_preview_block');
assert.doesNotThrow(() => hud.draw({
  ...vfxBattle,
  battleUi: { ...vfxBattle.battleUi, vfxTestEnabled: false },
}), 'VFX 测试开关关闭时应完全隐藏入口');
assert.equal(hud.hitTest(viewportWidth * 0.5, viewportHeight - 102), null);

assert.doesNotThrow(() => hud.draw({ ...baseBattle, battleUi: { ...baseBattle.battleUi, guideOpen: true, vfxTestEnabled: true } }));
assert.equal(hud.hitTest(viewportWidth * 0.5, viewportHeight - 143), 'guide_replay_tutorial');
assert.equal(hud.hitTest(viewportWidth * 0.5, viewportHeight - 80), 'guide_close');
assert.equal(hud.hitTest(viewportWidth - 50, viewportHeight - 80), 'guide_next');

assert.doesNotThrow(() => hud.draw({ ...baseBattle, battleUi: { ...baseBattle.battleUi, skillsOpen: true } }));
assert.equal(hud.hitTest(viewportWidth * 0.5, viewportHeight - 80), 'battle_skills_close');

assert.doesNotThrow(() => hud.draw({ ...baseBattle, enemyIntro: [{ enemyType: 'electric_ray', icon: '⚡', name: '电鳐', desc: '攻击会波及周围目标' }] }));
assert.equal(hud.hitTest(viewportWidth * 0.5, viewportHeight - 70), 'enemy_intro_close');
assert.equal(hud.hitTest(40, viewportHeight - 170), null, '怪物介绍弹窗必须拦截底层战斗按钮');

console.log('hud overlay state tests passed');
