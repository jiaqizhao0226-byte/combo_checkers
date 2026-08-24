import * as THREE from '../../vendor/three.module.js';
import {
  EQUIPMENT_ITEMS, PITY_THRESHOLD, PULL_COST_SINGLE, PULL_COST_TRIPLE, SETS, SLOT_NAMES, SLOT_ORDER,
  TALENTS, TALENT_COSTS, getCritRate, getEquipmentBonus, getItemDisplay,
  getSetCount, getTotalBonus,
} from '../core/MetaGame.js';
import { SKILLS, SKILL_BY_ID, SKILL_COMBOS } from '../core/ChapterOneData.js';
import { VFX_TEST_PRESETS } from '../vfx/VfxTestConfig.js';

const BATTLE_GUIDE_PAGES = [
  {
    title: '基础操作', icon: '⚔️', entries: [
      '点击相邻空格移动企鹅', '跳过敌人造成伤害', '连续规划落点形成连跳',
      '整条连跳执行完才结算奖励', '每次行动后轮到敌人', '击败目标数量即可过关',
    ],
  },
  {
    title: '道具与连击', icon: '🎁', entries: [
      '小血瓶 +40HP · 大血瓶回满', '金币袋 +10 · 护盾使下次受击减半',
      '2连追踪飞镖 · 3连稻草人', '4连六芒冲击 · 5连生命虹吸',
      '6连时间静止 · 7连流星火雨', '8连绝对反射 · 9连特殊三选一',
    ],
  },
  {
    title: '深渊海沟怪物', icon: '🌊', entries: [
      '铁甲龟：防御高', '漩涡鳗：死亡打乱周围棋子', '寄居蟹：缩壳时减伤并停止行动',
      '幽灵鲨：瞬移突袭', '射水鱼：远攻并在贴近时后退', '电鳐：攻击产生范围放电',
    ],
  },
  {
    title: '深渊海妖', icon: '🐙', entries: [
      '深渊压迫：靠近持续受伤', '深渊巨爪：近距离高伤重击', '触手丛生：制造可跳越的障碍',
      '深渊漩涡：把企鹅拉向 Boss', 'HP 低于 25% 后进入狂暴', '技能气泡会提前预告下一次施法',
    ],
  },
];

const SKILL_CARD_META = Object.freeze({
  quake_land: { glyph: '震', category: '范围打击' },
  chain_lightning: { glyph: '雷', category: '连锁伤害' },
  vampiric_jump: { glyph: '吸', category: '生命续航' },
  thorns: { glyph: '荆', category: '反伤防御' },
  spike_trap: { glyph: '刺', category: '路径陷阱' },
  blood_rage: { glyph: '怒', category: '低血爆发' },
  gravity_stomp: { glyph: '重', category: '连跳强化' },
  split_shot: { glyph: '裂', category: '弹射伤害' },
  hunter_mark: { glyph: '猎', category: '单体猎杀' },
  combo_shield: { glyph: '盾', category: '护盾防御' },
  glass_cannon: { glyph: '砲', category: '高风险增伤' },
  dawn_herald: { glyph: '曙', category: '致命保命' },
  step_strike: { glyph: '踏', category: '移动攻击' },
  collector: { glyph: '收', category: '残血收割' },
  frost_mark: { glyph: '霜', category: '冻结控制' },
  kingmaker: { glyph: '棋', category: '全图机动' },
  dart_storm: { glyph: '镖', category: '连击投射' },
  damage_amp: { glyph: '战', category: '全局增幅' },
  silence_path: { glyph: '寂', category: '沉默控制' },
});

function hexToRgba(color, alpha) {
  const hex = String(color || '#79f1cf').replace('#', '');
  const value = Number.parseInt(hex.length === 3 ? hex.split('').map(char => char + char).join('') : hex, 16);
  const red = Number.isFinite(value) ? value >> 16 & 255 : 121;
  const green = Number.isFinite(value) ? value >> 8 & 255 : 241;
  const blue = Number.isFinite(value) ? value & 255 : 207;
  return `rgba(${red}, ${green}, ${blue}, ${alpha})`;
}

function splitSkillDescription(text, maxUnits = 25, maxLines = 2) {
  const chars = [...String(text || '')];
  const lines = [];
  let line = '';
  let units = 0;
  for (const char of chars) {
    const weight = /[\x00-\xff]/.test(char) ? 0.55 : 1;
    if (line && units + weight > maxUnits) {
      lines.push(line);
      line = '';
      units = 0;
      if (lines.length >= maxLines) break;
    }
    line += char;
    units += weight;
  }
  if (lines.length < maxLines && line) lines.push(line);
  const consumed = lines.join('').length;
  if (consumed < chars.length && lines.length) lines[lines.length - 1] = `${lines[lines.length - 1].replace(/[；，、。]?$/, '')}…`;
  return lines;
}

function roundedRect(context, x, y, width, height, radius) {
  const r = Math.min(radius, width * 0.5, height * 0.5);
  context.beginPath();
  context.moveTo(x + r, y);
  context.lineTo(x + width - r, y);
  context.quadraticCurveTo(x + width, y, x + width, y + r);
  context.lineTo(x + width, y + height - r);
  context.quadraticCurveTo(x + width, y + height, x + width - r, y + height);
  context.lineTo(x + r, y + height);
  context.quadraticCurveTo(x, y + height, x, y + height - r);
  context.lineTo(x, y + r);
  context.quadraticCurveTo(x, y, x + r, y);
  context.closePath();
}

function panel(context, x, y, width, height, fill = 'rgba(8, 23, 29, .84)', stroke = 'rgba(120, 233, 213, .24)') {
  roundedRect(context, x, y, width, height, 14);
  context.fillStyle = fill;
  context.fill();
  context.lineWidth = 1.5;
  context.strokeStyle = stroke;
  context.stroke();
}

function button(context, bounds, label, accent, enabled = true) {
  const { x, y, width, height } = bounds;
  panel(
    context,
    x,
    y,
    width,
    height,
    enabled ? (accent ? 'rgba(19, 154, 143, .94)' : 'rgba(18, 43, 51, .92)') : 'rgba(18, 36, 41, .62)',
    enabled ? 'rgba(207, 255, 235, .44)' : 'rgba(180, 205, 198, .14)'
  );
  context.fillStyle = enabled ? '#efffe9' : 'rgba(222, 239, 232, .42)';
  context.font = '700 16px sans-serif';
  context.textAlign = 'center';
  context.textBaseline = 'middle';
  context.fillText(label, x + width * 0.5, y + height * 0.5 + 1);
}

function drawNavIcon(context, id, centerX, centerY, size, active) {
  const scale = size / 24;
  const primary = active ? '#ffe37a' : '#87a8a2';
  const secondary = active ? '#df7b2b' : '#345b5b';
  const dark = active ? '#5d3017' : '#152f33';

  context.save();
  context.translate(centerX, centerY);
  context.scale(scale, scale);
  context.lineCap = 'round';
  context.lineJoin = 'round';
  context.lineWidth = 1.65;
  context.strokeStyle = primary;

  if (active) {
    context.beginPath();
    context.arc(0, 0, 11, 0, Math.PI * 2);
    context.fillStyle = 'rgba(255, 218, 100, .13)';
    context.fill();
  }

  if (id === 'shop') {
    roundedRect(context, -8, -1, 16, 9, 1.5);
    context.fillStyle = dark;
    context.fill();
    context.stroke();
    roundedRect(context, -9, -8, 18, 6, 2);
    context.fillStyle = secondary;
    context.fill();
    context.stroke();
    context.beginPath();
    context.moveTo(-3, -7.5); context.lineTo(-3, -2.5);
    context.moveTo(3, -7.5); context.lineTo(3, -2.5);
    context.moveTo(1, 8); context.lineTo(1, 3);
    context.lineTo(6, 3); context.lineTo(6, 8);
    context.stroke();
    context.fillStyle = primary;
    context.fillRect(-6, 2, 4, 3);
  } else if (id === 'equip') {
    context.beginPath();
    context.moveTo(0, -9);
    context.lineTo(8, -6);
    context.lineTo(7, 1);
    context.quadraticCurveTo(6, 7, 0, 10);
    context.quadraticCurveTo(-6, 7, -7, 1);
    context.lineTo(-8, -6);
    context.closePath();
    context.fillStyle = dark;
    context.fill();
    context.stroke();
    context.beginPath();
    context.moveTo(-2, -5); context.lineTo(4, -1);
    context.lineTo(0, 1); context.lineTo(3, 5);
    context.lineTo(-4, 0); context.lineTo(0, -2);
    context.closePath();
    context.fillStyle = secondary;
    context.fill();
  } else if (id === 'adventure') {
    context.beginPath();
    context.arc(0, 0, 9, 0, Math.PI * 2);
    context.fillStyle = dark;
    context.fill();
    context.stroke();
    context.beginPath();
    context.moveTo(3, -7); context.lineTo(1, 1);
    context.lineTo(-4, 6); context.lineTo(-1, -2);
    context.closePath();
    context.fillStyle = secondary;
    context.fill();
    context.stroke();
    context.beginPath();
    context.arc(0, 0, 1.5, 0, Math.PI * 2);
    context.fillStyle = primary;
    context.fill();
  } else if (id === 'talent') {
    context.beginPath();
    context.moveTo(0, 8); context.lineTo(0, -1);
    context.moveTo(0, 2); context.lineTo(-6, -4);
    context.moveTo(0, 0); context.lineTo(6, -6);
    context.stroke();
    for (const [x, y, radius] of [[0, 8, 2.1], [-6, -4, 3], [6, -6, 3], [0, -1, 2.5]]) {
      context.beginPath();
      context.arc(x, y, radius, 0, Math.PI * 2);
      context.fillStyle = y < -3 ? secondary : dark;
      context.fill();
      context.stroke();
    }
  } else {
    context.beginPath();
    context.moveTo(-9, 8); context.lineTo(-9, -4);
    context.lineTo(-5, -4); context.lineTo(-5, -8);
    context.lineTo(-1, -8); context.lineTo(-1, -4);
    context.lineTo(2, -4); context.lineTo(2, -8);
    context.lineTo(6, -8); context.lineTo(6, -4);
    context.lineTo(9, -4); context.lineTo(9, 8);
    context.closePath();
    context.fillStyle = dark;
    context.fill();
    context.stroke();
    roundedRect(context, -3, 1, 6, 7, 3);
    context.fillStyle = secondary;
    context.fill();
    context.beginPath();
    context.moveTo(-6, 1); context.lineTo(6, 1);
    context.stroke();
  }

  context.restore();
}

export function createHudOverlay(renderer, viewportWidth, viewportHeight, pixelRatio, makeCanvas, uiInsets = {}) {
  const hudCanvas = makeCanvas();
  hudCanvas.width = Math.round(viewportWidth * pixelRatio);
  hudCanvas.height = Math.round(viewportHeight * pixelRatio);
  const context = hudCanvas.getContext('2d');
  context.scale(pixelRatio, pixelRatio);

  const texture = new THREE.CanvasTexture(hudCanvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.minFilter = THREE.LinearFilter;
  texture.magFilter = THREE.LinearFilter;
  texture.generateMipmaps = false;

  const scene = new THREE.Scene();
  let lastState = null;
  const camera = new THREE.OrthographicCamera(0, viewportWidth, viewportHeight, 0, -1, 1);
  const plane = new THREE.Mesh(
    new THREE.PlaneGeometry(viewportWidth, viewportHeight),
    new THREE.MeshBasicMaterial({ map: texture, transparent: true, depthTest: false, depthWrite: false, toneMapped: false })
  );
  plane.position.set(viewportWidth * 0.5, viewportHeight * 0.5, 0);
  scene.add(plane);

  const safeTop = Math.max(14, Math.min(76, Number(uiInsets.safeAreaTop) || 0) + 8);
  const menuTabHeight = 116;
  const menuTabY = viewportHeight - menuTabHeight;
  const adventureButtonWidth = Math.min(320, viewportWidth * 0.75);
  const adventureButtonHeight = 72;
  const adventureButtonBottomGap = 80;
  const battleFooterY = viewportHeight - 124;
  const vfxTestWidth = Math.min(126, Math.max(96, viewportWidth - 220));
  const vfxPanelWidth = Math.min(364, viewportWidth - 28);
  const vfxPanelHeight = 520;
  const vfxPanelX = (viewportWidth - vfxPanelWidth) * 0.5;
  const vfxPanelY = Math.max(safeTop + 18, (viewportHeight - vfxPanelHeight) * 0.5);
  const vfxButtonGap = 10;
  const vfxButtonWidth = (vfxPanelWidth - 46 - vfxButtonGap) * 0.5;
  const skillCardWidth = Math.min(382, viewportWidth - 32);
  const skillCardHeight = 128;
  const skillCardGap = 12;
  const skillCardsHeight = skillCardHeight * 3 + skillCardGap * 2;
  const skillChoiceStartY = Math.max(
    safeTop + 168,
    Math.min(viewportHeight - skillCardsHeight - 96, Math.round(viewportHeight * 0.25))
  );
  const controls = {
    start: {
      x: (viewportWidth - adventureButtonWidth) * 0.5,
      y: menuTabY - adventureButtonBottomGap - adventureButtonHeight,
      width: adventureButtonWidth,
      height: adventureButtonHeight,
    },
    home: { x: (viewportWidth - 190) * 0.5, y: (viewportHeight - 190) * 0.5 + 118, width: 190, height: 48 },
    wheelClose: { x: (viewportWidth - 190) * 0.5, y: viewportHeight * 0.5 + 170, width: 190, height: 48 },
    tutorialClose: { x: (viewportWidth - 190) * 0.5, y: viewportHeight * 0.5 + 92, width: 190, height: 48 },
    enemyIntroClose: { x: (viewportWidth - 190) * 0.5, y: viewportHeight - 98, width: 190, height: 48 },
    skills: [0, 1, 2].map(index => ({
      x: (viewportWidth - skillCardWidth) * 0.5,
      y: skillChoiceStartY + index * (skillCardHeight + skillCardGap),
      width: skillCardWidth,
      height: skillCardHeight,
    })),
    tabs: ['shop', 'equip', 'adventure', 'talent', 'guild'].map((id, index) => ({
      id, x: viewportWidth / 5 * index, y: menuTabY,
      width: viewportWidth / 5, height: menuTabHeight,
    })),
    talents: TALENTS.map((talent, index) => ({ id: talent.id, x: viewportWidth - 94, y: 160 + index * 88, width: 68, height: 48 })),
    pullSingle: { x: 28, y: viewportHeight - 190, width: (viewportWidth - 68) * 0.5, height: 58 },
    pullTriple: { x: 40 + (viewportWidth - 68) * 0.5, y: viewportHeight - 190, width: (viewportWidth - 68) * 0.5, height: 58 },
    equipSlots: SLOT_ORDER.map((slot, index) => ({
      slot, x: index < 3 ? 24 : viewportWidth - 142, y: 204 + (index % 3) * 76, width: 118, height: 62,
    })),
    inventory: Array.from({ length: 6 }, (_, index) => ({
      x: 24 + (index % 3) * ((viewportWidth - 56) / 3), y: 470 + Math.floor(index / 3) * 68,
      width: (viewportWidth - 68) / 3, height: 58,
    })),
    equipSelected: { x: 28, y: viewportHeight - 190, width: (viewportWidth - 68) * 0.5, height: 58 },
    decomposeSelected: { x: 40 + (viewportWidth - 68) * 0.5, y: viewportHeight - 190, width: (viewportWidth - 68) * 0.5, height: 58 },
    inventoryPrev: { x: 24, y: 610, width: 52, height: 34 },
    inventoryNext: { x: viewportWidth - 76, y: 610, width: 52, height: 34 },
    bulkToggle: { x: (viewportWidth - 126) * 0.5, y: 610, width: 126, height: 34 },
    bulkBlue: { x: 20, y: viewportHeight - 190, width: (viewportWidth - 52) / 3, height: 58 },
    bulkPurple: { x: 26 + (viewportWidth - 52) / 3, y: viewportHeight - 190, width: (viewportWidth - 52) / 3, height: 58 },
    bulkConfirm: { x: 32 + (viewportWidth - 52) / 3 * 2, y: viewportHeight - 190, width: (viewportWidth - 52) / 3, height: 58 },
    detailClose: { x: viewportWidth - 76, y: 202, width: 38, height: 34 },
    adventurePrev: { x: 18, y: 300, width: 44, height: 58 },
    adventureNext: { x: viewportWidth - 62, y: 300, width: 44, height: 58 },
    shopPrev: { x: 22, y: 286, width: 40, height: 48 },
    shopNext: { x: viewportWidth - 62, y: 286, width: 40, height: 48 },
    shopRules: { x: viewportWidth - 78, y: 122, width: 58, height: 38 },
    shopRulesClose: { x: (viewportWidth - 190) * 0.5, y: viewportHeight * 0.5 + 190, width: 190, height: 48 },
    shopResultClose: { x: (viewportWidth - 190) * 0.5, y: viewportHeight * 0.5 + 166, width: 190, height: 48 },
    guildAdventure: { x: 28, y: 176, width: (viewportWidth - 60) * 0.5, height: 42 },
    guildEndless: { x: 32 + (viewportWidth - 60) * 0.5, y: 176, width: (viewportWidth - 60) * 0.5, height: 42 },
    redeemOpen: { x: viewportWidth - 142, y: 28, width: 118, height: 62 },
    redeemCancel: { x: 38, y: viewportHeight * 0.5 + 128, width: (viewportWidth - 88) * 0.42, height: 48 },
    redeemSubmit: { x: 50 + (viewportWidth - 88) * 0.42, y: viewportHeight * 0.5 + 128, width: (viewportWidth - 88) * 0.58, height: 48 },
    settingsOpen: { x: 18, y: safeTop + 66, width: 40, height: 40 },
    settingsClose: { x: (viewportWidth - 190) * 0.5, y: viewportHeight * 0.5 + 206, width: 190, height: 48 },
    bgmMinus: { x: 48, y: viewportHeight * 0.5 - 132, width: 48, height: 40 },
    bgmPlus: { x: viewportWidth - 96, y: viewportHeight * 0.5 - 132, width: 48, height: 40 },
    sfxMinus: { x: 48, y: viewportHeight * 0.5 - 58, width: 48, height: 40 },
    sfxPlus: { x: viewportWidth - 96, y: viewportHeight * 0.5 - 58, width: 48, height: 40 },
    comboScale: { x: 42, y: viewportHeight * 0.5 + 38, width: (viewportWidth - 92) * 0.5, height: 44 },
    comboClassic: { x: 50 + (viewportWidth - 92) * 0.5, y: viewportHeight * 0.5 + 38, width: (viewportWidth - 92) * 0.5, height: 44 },
    trackButtons: ['menu', 'battle_calm', 'battle', 'boss_abyss'].map((id, index) => ({
      id, x: 42 + (index % 2) * ((viewportWidth - 92) * 0.5 + 8), y: viewportHeight * 0.5 + 112 + Math.floor(index / 2) * 42,
      width: (viewportWidth - 100) * 0.5, height: 34,
    })),
    battleSettings: { x: 18, y: safeTop + 64, width: 44, height: 40 },
    battleExit: { x: viewportWidth - 62, y: safeTop + 64, width: 44, height: 40 },
    battleGuide: { x: 18, y: battleFooterY, width: 92, height: 42 },
    battleSkills: { x: viewportWidth - 110, y: battleFooterY, width: 92, height: 42 },
    battleVfxTestOpen: { x: (viewportWidth - vfxTestWidth) * 0.5, y: battleFooterY, width: vfxTestWidth, height: 42 },
    battleVfxTestClose: { x: vfxPanelX + vfxPanelWidth - 50, y: vfxPanelY + 16, width: 34, height: 34 },
    battleVfxTestClear: { x: vfxPanelX + 20, y: vfxPanelY + vfxPanelHeight - 58, width: vfxPanelWidth - 40, height: 38 },
    battleVfxTests: VFX_TEST_PRESETS.map((preset, index) => ({
      id: preset.id,
      x: vfxPanelX + 18 + (index % 2) * (vfxButtonWidth + vfxButtonGap),
      y: vfxPanelY + 82 + Math.floor(index / 2) * 56,
      width: vfxButtonWidth,
      height: 44,
    })),
    guidePrev: { x: 30, y: viewportHeight - 104, width: 54, height: 42 },
    guideNext: { x: viewportWidth - 84, y: viewportHeight - 104, width: 54, height: 42 },
    guideClose: { x: (viewportWidth - 150) * 0.5, y: viewportHeight - 104, width: 150, height: 42 },
    guideReplayTutorial: { x: (viewportWidth - 220) * 0.5, y: viewportHeight - 164, width: 220, height: 42 },
    skillsPrev: { x: 30, y: viewportHeight - 104, width: 54, height: 42 },
    skillsNext: { x: viewportWidth - 84, y: viewportHeight - 104, width: 54, height: 42 },
    skillsClose: { x: (viewportWidth - 150) * 0.5, y: viewportHeight - 104, width: 150, height: 42 },
    exitCancel: { x: 36, y: viewportHeight * 0.5 + 70, width: (viewportWidth - 84) * 0.45, height: 48 },
    exitConfirm: { x: 48 + (viewportWidth - 84) * 0.45, y: viewportHeight * 0.5 + 70, width: (viewportWidth - 84) * 0.55, height: 48 },
  };

  function menuTitle(title, subtitle) {
    context.textAlign = 'left'; context.textBaseline = 'alphabetic';
    context.fillStyle = '#f2ffe9'; context.font = '900 25px sans-serif'; context.fillText(title, 70, 142);
    context.fillStyle = '#77a99e'; context.font = '600 11px sans-serif'; context.fillText(subtitle, 70, 161);
  }

  function drawAdventureButton(label, enabled) {
    const { x, y, width, height } = controls.start;
    roundedRect(context, x, y + 6, width, height - 6, 7);
    context.fillStyle = enabled ? '#71300c' : '#293a3b';
    context.fill();
    roundedRect(context, x, y, width, height - 6, 7);
    context.fillStyle = enabled ? '#e78021' : '#475b59';
    context.fill();
    context.lineWidth = 1.5;
    context.strokeStyle = enabled ? 'rgba(255, 211, 122, .82)' : 'rgba(193, 214, 207, .24)';
    context.stroke();
    roundedRect(context, x + width * 0.12, y + 3, width * 0.76, 12, 5);
    context.fillStyle = enabled ? 'rgba(255, 248, 217, .25)' : 'rgba(255, 255, 255, .06)';
    context.fill();
    context.textAlign = 'center';
    context.textBaseline = 'middle';
    context.fillStyle = enabled ? '#fff9e8' : 'rgba(225, 237, 232, .48)';
    context.font = '900 24px sans-serif';
    context.fillText(`${enabled ? '⚔️' : '🔒'}  ${label}`, x + width * 0.5, y + (height - 6) * 0.53);
  }

  function drawAdventure(state) {
    const chapters = [
      { id: 0, name: '虚空试炼', icon: '🌀', subtitle: '无尽挑战', color: '#c58cff' },
      { id: 1, name: '深渊海沟', icon: '🐙', subtitle: '浅海珊瑚 → 深渊王座', color: '#8debd2' },
      { id: 2, name: '烈焰山脉', icon: '🌋', subtitle: '灼热入口 → 领主殿堂', color: '#ff9a58' },
      { id: 3, name: '珊瑚迷宫', icon: '🪸', subtitle: '潮间浅滩 → 珊瑚王庭', color: '#6de1b4' },
      { id: 4, name: '流沙荒漠', icon: '🏜️', subtitle: '沙丘入口 → 沙丘之王', color: '#e5bd61' },
      { id: 5, name: '永冻绝境', icon: '❄️', subtitle: '冰封港湾 → 永冻王座', color: '#8dcfff' },
    ];
    const selected = Math.max(0, Math.min(5, state.menuState.selectedChapter ?? 1));
    const chapter = chapters[selected];
    const unlocked = selected === 0 || selected === 1 || state.meta.highestLevel > (selected - 1) * 10;
    menuTitle(selected === 0 ? chapter.name : `第${selected}章 · ${chapter.name}`, '左右切换章节 · 原版章节选择结构');
    context.textAlign = 'center';
    context.fillStyle = chapter.color; context.font = '900 54px sans-serif'; context.fillText(chapter.icon, viewportWidth * 0.5, 284);
    context.fillStyle = '#effff6'; context.font = '900 22px sans-serif'; context.fillText(chapter.name, viewportWidth * 0.5, 330);
    context.fillStyle = '#8dbab0'; context.font = '600 12px sans-serif';
    const progress = selected === 0 ? `历史最高 第 ${state.meta.highestEndlessWave} 波`
      : selected === 1 ? `第一章进度 ${Math.min(10, state.meta.highestLevel)}/10`
        : unlocked ? '已解锁' : `通关「${chapters[selected - 1].name}」后解锁`;
    context.fillText(progress, viewportWidth * 0.5, 360);
    context.fillText(chapter.subtitle, viewportWidth * 0.5, 386);
    button(context, controls.adventurePrev, '‹', false, selected > 0);
    button(context, controls.adventureNext, '›', false, selected < 5);
    const playable = selected === 1;
    drawAdventureButton(
      selected === 0 ? '无尽挑战' : selected === 1 ? '开始冒险' : unlocked ? '后续章节暂未复刻' : '尚未解锁',
      playable
    );
    context.fillStyle = '#728f8a';
    context.font = '600 12px sans-serif';
    context.fillText(`已冒险 ${state.meta.totalRuns} 次`, viewportWidth * 0.5, controls.start.y + controls.start.height + 24);
  }

  function drawShop(state) {
    const setIndex = Math.max(0, Math.min(SETS.length - 1, state.menuState.shopSetIndex || 0));
    const featured = SETS[setIndex];
    menuTitle('装备抽奖', '套装海报轮播 · 蓝 / 紫 / 金三阶装备');
    button(context, controls.shopRules, '规则', false, true);
    panel(context, 28, 182, viewportWidth - 56, 270, 'rgba(14, 27, 44, .78)', 'rgba(197, 149, 255, .3)');
    context.textAlign = 'center'; context.fillStyle = featured.color; context.font = '900 58px sans-serif'; context.fillText(featured.icon, viewportWidth * 0.5, 272);
    context.fillStyle = '#f3eaff'; context.font = '900 20px sans-serif'; context.fillText(featured.shortName, viewportWidth * 0.5, 310);
    context.fillStyle = '#aa96bd'; context.font = '600 11px sans-serif'; context.fillText(`4件：${featured.desc4}`, viewportWidth * 0.5, 336);
    context.fillText(`6件：${featured.desc6}`, viewportWidth * 0.5, 355);
    button(context, controls.shopPrev, '‹', false, true); button(context, controls.shopNext, '›', false, true);
    SETS.forEach((set, index) => { context.fillStyle = index === setIndex ? '#ffd866' : '#536a73'; context.fillRect(viewportWidth * 0.5 - 24 + index * 18, 366, index === setIndex ? 12 : 7, 5); });
    context.fillStyle = '#ffd177'; context.font = '800 13px sans-serif'; context.fillText(`保底进度 ${state.meta.pityCounter}/${PITY_THRESHOLD}`, viewportWidth * 0.5, 382);
    const results = state.menuState.shopResults || [];
    if (results.length) {
      context.font = '700 12px sans-serif'; context.fillStyle = '#d7eee8';
      context.fillText(results.map(getItemDisplay).filter(Boolean).map(item => item.name).join(' · '), viewportWidth * 0.5, 416);
    } else {
      context.fillStyle = '#78998f'; context.font = '600 11px sans-serif'; context.fillText('金色装备优先获得未收集部件', viewportWidth * 0.5, 416);
    }
    button(context, controls.pullSingle, `抽取 1 次  ${PULL_COST_SINGLE}G`, false, state.meta.gold >= PULL_COST_SINGLE);
    button(context, controls.pullTriple, `抽取 3 次  ${PULL_COST_TRIPLE}G`, true, state.meta.gold >= PULL_COST_TRIPLE);
  }

  function drawShopRulesModal() {
    context.fillStyle = 'rgba(2, 8, 14, .78)';
    context.fillRect(0, 0, viewportWidth, viewportHeight);
    const width = Math.min(350, viewportWidth - 34);
    const height = 470;
    const x = (viewportWidth - width) * 0.5;
    const y = (viewportHeight - height) * 0.5;
    panel(context, x, y, width, height, 'rgba(11, 25, 38, .99)', 'rgba(199, 151, 255, .54)');
    context.textAlign = 'center';
    context.fillStyle = '#f0e3ff'; context.font = '900 25px sans-serif';
    context.fillText('装备抽取规则', viewportWidth * 0.5, y + 46);
    context.fillStyle = '#9c8eae'; context.font = '600 11px sans-serif';
    context.fillText('原版概率、保底与分解规则', viewportWidth * 0.5, y + 67);
    const rows = [
      { color: '#64b4ff', title: '蓝色装备  75%', desc: '基础属性 · 分解获得 5 金币' },
      { color: '#c878ff', title: '紫色装备  22%', desc: '进阶属性 · 分解获得 15 金币' },
      { color: '#ffd700', title: '金色装备  3%', desc: '计入套装 · 分解获得 50 金币' },
    ];
    rows.forEach((row, index) => {
      const rowY = y + 88 + index * 66;
      panel(context, x + 22, rowY, width - 44, 54, 'rgba(19, 37, 51, .82)', `${row.color}88`);
      context.textAlign = 'left'; context.fillStyle = row.color; context.font = '900 14px sans-serif';
      context.fillText(row.title, x + 38, rowY + 22);
      context.fillStyle = '#9db5b0'; context.font = '600 10px sans-serif';
      context.fillText(row.desc, x + 38, rowY + 40);
    });
    context.textAlign = 'left'; context.fillStyle = '#ffe08a'; context.font = '800 12px sans-serif';
    context.fillText(`• 每 ${PITY_THRESHOLD} 抽必得金色装备`, x + 32, y + 307);
    context.fillStyle = '#adc7c0'; context.font = '600 11px sans-serif';
    context.fillText('• 金色优先获得尚未收集的部件', x + 32, y + 333);
    context.fillText('• 集齐后，金色保底恢复随机', x + 32, y + 355);
    context.fillText(`• 单抽 ${PULL_COST_SINGLE}G · 三抽 ${PULL_COST_TRIPLE}G`, x + 32, y + 377);
    button(context, controls.shopRulesClose, '我知道了', true, true);
  }

  function drawShopResultModal(state) {
    context.fillStyle = 'rgba(2, 8, 14, .8)';
    context.fillRect(0, 0, viewportWidth, viewportHeight);
    const results = (state.menuState.shopResults || []).map(getItemDisplay).filter(Boolean);
    const elapsed = Math.max(0, (Date.now() - (state.menuState.shopResultOpenedAt || Date.now())) / 1000);
    const revealReady = elapsed >= 0.68;
    const width = Math.min(356, viewportWidth - 28);
    const height = 422;
    const x = (viewportWidth - width) * 0.5;
    const y = (viewportHeight - height) * 0.5;
    panel(context, x, y, width, height, 'rgba(11, 25, 38, .99)', 'rgba(255, 218, 112, .5)');
    context.textAlign = 'center'; context.fillStyle = '#ffe28d'; context.font = '900 27px sans-serif';
    context.fillText('获得装备', viewportWidth * 0.5, y + 49);
    context.fillStyle = '#91ada7'; context.font = '600 11px sans-serif';
    context.fillText(`已放入背包 · 保底进度 ${state.meta.pityCounter}/${PITY_THRESHOLD}`, viewportWidth * 0.5, y + 71);
    if (!revealReady) {
      const shake = elapsed < 0.34 ? Math.sin(elapsed * 90) * (7 - elapsed * 12) : 0;
      const burst = Math.max(0, Math.min(1, (elapsed - 0.34) / 0.28));
      if (burst > 0) {
        context.save(); context.globalAlpha = 0.5 * (1 - burst);
        context.beginPath(); context.arc(viewportWidth * 0.5, y + 203, 36 + burst * 118, 0, Math.PI * 2);
        context.fillStyle = results.some(item => item.rarity.id === 'gold') ? '#ffd94f' : '#bd8cff'; context.fill(); context.restore();
      }
      context.save(); context.translate(shake, 0);
      context.textAlign = 'center'; context.font = `${Math.round(66 + burst * 18)}px sans-serif`;
      context.fillStyle = '#fff'; context.fillText(burst > 0.55 ? '✨' : '🎁', viewportWidth * 0.5, y + 231);
      context.restore();
      context.fillStyle = '#9fb7b1'; context.font = '700 12px sans-serif';
      context.fillText(elapsed < 0.34 ? '宝箱正在开启…' : '稀有度判定中…', viewportWidth * 0.5, y + 276);
      return;
    }
    const gap = 8;
    const cardWidth = results.length === 1 ? Math.min(170, width - 56) : (width - 48 - gap * 2) / 3;
    const startX = results.length === 1 ? viewportWidth * 0.5 - cardWidth * 0.5 : x + 24;
    results.forEach((display, index) => {
      const cardX = startX + index * (cardWidth + gap);
      const cardY = y + 94;
      panel(context, cardX, cardY, cardWidth, 206, 'rgba(18, 39, 51, .94)', display.rarity.color);
      context.textAlign = 'center'; context.fillStyle = display.rarity.color; context.font = results.length === 1 ? '900 48px sans-serif' : '900 38px sans-serif';
      context.fillText(display.icon, cardX + cardWidth * 0.5, cardY + 62);
      context.font = '900 13px sans-serif';
      context.fillText(display.rarity.name, cardX + cardWidth * 0.5, cardY + 91);
      context.fillStyle = '#effbf7'; context.font = results.length === 1 ? '800 14px sans-serif' : '800 11px sans-serif';
      context.fillText(display.name, cardX + cardWidth * 0.5, cardY + 121);
      context.fillStyle = '#8eb1a9'; context.font = '600 10px sans-serif';
      context.fillText(SLOT_NAMES[display.slot], cardX + cardWidth * 0.5, cardY + 145);
      context.fillText(Object.entries(display.stats).map(([key, value]) => `${key.toUpperCase()}+${value}`).join(' '), cardX + cardWidth * 0.5, cardY + 170);
      if (display.rarity.id === 'gold') {
        context.fillStyle = '#ffd976'; context.font = '700 9px sans-serif';
        context.fillText('金色套装部件', cardX + cardWidth * 0.5, cardY + 190);
      }
    });
    if (results.some(item => item.rarity.id === 'gold')) {
      context.save(); context.globalAlpha = 0.5 + Math.sin(elapsed * 7) * 0.2;
      context.fillStyle = '#ffe47a'; context.font = '900 17px sans-serif';
      for (let index = 0; index < 8; index += 1) {
        const angle = elapsed * 0.8 + index * Math.PI * 0.25;
        context.fillText('+', viewportWidth * 0.5 + Math.cos(angle) * 148, y + 195 + Math.sin(angle) * 118);
      }
      context.restore();
    }
    button(context, controls.shopResultClose, '确认收下', true, true);
  }

  function drawRedeemModal(state) {
    context.fillStyle = 'rgba(2, 8, 14, .8)'; context.fillRect(0, 0, viewportWidth, viewportHeight);
    const width = Math.min(340, viewportWidth - 36); const height = 350;
    const x = (viewportWidth - width) * 0.5; const y = (viewportHeight - height) * 0.5;
    panel(context, x, y, width, height, 'rgba(29, 23, 51, .99)', 'rgba(230, 186, 70, .54)');
    context.textAlign = 'center'; context.fillStyle = '#ffe075'; context.font = '900 27px sans-serif';
    context.fillText('🎁  兑换码', viewportWidth * 0.5, y + 54);
    context.fillStyle = '#9d98b8'; context.font = '600 12px sans-serif';
    context.fillText('输入兑换码即可领取金币奖励', viewportWidth * 0.5, y + 82);
    panel(context, x + 25, y + 110, width - 50, 58, 'rgba(21, 18, 43, .96)', 'rgba(198, 157, 49, .5)');
    const code = String(state.menuState.redeemCode || '').toUpperCase();
    context.fillStyle = code ? '#f4eec7' : '#726e90'; context.font = '800 17px sans-serif';
    context.fillText(code || '点击后使用微信键盘输入', viewportWidth * 0.5, y + 146);
    const status = state.menuState.redeemStatus || '输入兑换码后点击确认';
    context.fillStyle = state.menuState.redeemSuccess ? '#58e596' : state.menuState.redeemError ? '#ff8d80' : '#9d98b8';
    context.font = '700 12px sans-serif'; context.fillText(status, viewportWidth * 0.5, y + 205);
    button(context, controls.redeemCancel, '取消', false, true);
    button(context, controls.redeemSubmit, '✨ 确认兑换', true, Boolean(code) && !state.menuState.redeemSuccess);
    context.fillStyle = '#655f7c'; context.font = '600 9px sans-serif';
    context.fillText('兑换记录保存在本地存档中', viewportWidth * 0.5, y + 245);
  }

  function drawSettingsModal(state) {
    context.fillStyle = 'rgba(2, 8, 14, .8)'; context.fillRect(0, 0, viewportWidth, viewportHeight);
    const width = Math.min(350, viewportWidth - 32); const height = 500;
    const x = (viewportWidth - width) * 0.5; const y = (viewportHeight - height) * 0.5;
    panel(context, x, y, width, height, 'rgba(28, 23, 52, .99)', 'rgba(149, 118, 225, .52)');
    context.textAlign = 'center'; context.fillStyle = '#eee7ff'; context.font = '900 26px sans-serif';
    context.fillText('⚙  设置', viewportWidth * 0.5, y + 47);
    const audio = state.menuState.audioState || { bgmVolume: 0.5, sfxVolume: 0.8, comboSoundStyle: 'scale', currentBgm: 'menu' };
    const volumeRow = (label, value, rowY, minus, plus) => {
      context.textAlign = 'left'; context.fillStyle = '#d3cbed'; context.font = '800 14px sans-serif'; context.fillText(label, x + 28, rowY);
      context.textAlign = 'right'; context.fillStyle = '#a69dbe'; context.font = '700 13px sans-serif'; context.fillText(`${Math.round(value * 100)}%`, x + width - 28, rowY);
      roundedRect(context, x + 74, rowY + 21, width - 148, 7, 4); context.fillStyle = '#30274f'; context.fill();
      roundedRect(context, x + 74, rowY + 21, (width - 148) * value, 7, 4); context.fillStyle = '#9d7bea'; context.fill();
      button(context, minus, '−', false, value > 0); button(context, plus, '+', false, value < 1);
    };
    volumeRow('🎵 BGM 音量', audio.bgmVolume, y + 92, controls.bgmMinus, controls.bgmPlus);
    volumeRow('🔊 音效音量', audio.sfxVolume, y + 166, controls.sfxMinus, controls.sfxPlus);
    context.textAlign = 'left'; context.fillStyle = '#d3cbed'; context.font = '800 14px sans-serif'; context.fillText('🎹 连跳音效', x + 28, y + 239);
    button(context, controls.comboScale, '音阶递进', audio.comboSoundStyle === 'scale', true);
    button(context, controls.comboClassic, '经典跳跃', audio.comboSoundStyle === 'classic', true);
    context.textAlign = 'left'; context.fillStyle = '#d3cbed'; context.font = '800 14px sans-serif'; context.fillText('🎶 当前曲目', x + 28, y + 313);
    const names = { menu: '主菜单', battle_calm: '深海漫游', battle: '激烈战斗', boss_abyss: '深渊海妖' };
    controls.trackButtons.forEach(bounds => button(context, bounds, names[bounds.id], audio.currentBgm === bounds.id, true));
    button(context, controls.settingsClose, '关闭设置', true, true);
  }

  function drawTalent(state) {
    menuTitle('天赋之树', '五维成长 · 每项最高 10 级');
    TALENTS.forEach((talent, index) => {
      const level = state.meta.talents[talent.id] || 0;
      const y = 176 + index * 88;
      panel(context, 20, y, viewportWidth - 40, 74, 'rgba(8, 28, 33, .84)', 'rgba(127, 231, 207, .16)');
      context.textAlign = 'left'; context.fillStyle = '#eafff3'; context.font = '800 14px sans-serif';
      context.fillText(`${talent.icon} ${talent.name}`, 34, y + 24);
      context.fillStyle = '#779e94'; context.font = '600 10px sans-serif';
      const suffix = ['crit', 'gold'].includes(talent.stat) ? '%' : '';
      context.fillText(`${talent.desc} +${level * talent.bonusPerLevel}${suffix}`, 34, y + 44);
      for (let dot = 0; dot < 10; dot += 1) {
        context.fillStyle = dot < level ? '#66e1c1' : '#1b4b4c';
        context.fillRect(34 + dot * 10, y + 55, 7, 5);
      }
      const cost = level >= talent.maxLevel ? null : TALENT_COSTS[level];
      button(context, controls.talents[index], cost ? `${cost}G` : '满级', true, cost != null && state.meta.gold >= cost);
    });
  }

  function drawEquipment(state) {
    menuTitle('装备库', '六槽位 · 只有金色部件计入套装');
    const bonus = getTotalBonus(state.meta); const equipmentBonus = getEquipmentBonus(state.meta);
    context.textAlign = 'center'; context.fillStyle = '#d9f7ec'; context.font = '800 12px sans-serif';
    context.fillText(`ATK +${bonus.atk}   DEF +${bonus.def}   HP +${bonus.hp}   暴击 ${getCritRate(state.meta)}%`, viewportWidth * 0.5, 184);
    controls.equipSlots.forEach(bounds => {
      const item = state.meta.equipment[bounds.slot]; const display = getItemDisplay(item);
      panel(context, bounds.x, bounds.y, bounds.width, bounds.height, 'rgba(9, 29, 35, .9)', display?.rarity.color || 'rgba(112, 156, 147, .18)');
      context.textAlign = 'left'; context.fillStyle = '#789d94'; context.font = '600 9px sans-serif'; context.fillText(SLOT_NAMES[bounds.slot], bounds.x + 9, bounds.y + 16);
      context.fillStyle = display?.rarity.color || '#496c65'; context.font = '800 12px sans-serif'; context.fillText(display?.name || '未装备', bounds.x + 9, bounds.y + 38);
      if (display) { context.fillStyle = '#8dbab0'; context.font = '600 9px sans-serif'; context.fillText(Object.entries(display.stats).map(([k, v]) => `${k}+${v}`).join(' '), bounds.x + 9, bounds.y + 53); }
    });
    context.textAlign = 'center'; context.fillStyle = '#8debd2'; context.font = '900 38px sans-serif'; context.fillText('🐧', viewportWidth * 0.5, 300);
    SETS.forEach((set, index) => {
      const count = getSetCount(state.meta, set.id);
      context.fillStyle = count >= 4 ? set.color : '#59766f'; context.font = '700 10px sans-serif';
      context.fillText(`${set.icon}${count}/6`, viewportWidth * 0.5, 342 + index * 20);
    });
    const pageCount = Math.max(1, Math.ceil(state.meta.inventory.length / 6));
    const page = Math.max(0, Math.min(pageCount - 1, state.menuState.inventoryPage || 0));
    context.textAlign = 'left'; context.fillStyle = '#d7eee8'; context.font = '800 12px sans-serif'; context.fillText(`背包 ${state.meta.inventory.length} · ${page + 1}/${pageCount}`, 24, 456);
    const bulkSelected = new Set(state.menuState.decomposeSelectedIndices || []);
    controls.inventory.forEach((bounds, index) => {
      const inventoryIndex = page * 6 + index;
      const item = state.meta.inventory[inventoryIndex]; const display = getItemDisplay(item);
      const selected = state.menuState.decomposeMode ? bulkSelected.has(inventoryIndex) : state.menuState.selectedInventoryIndex === inventoryIndex;
      panel(context, bounds.x, bounds.y, bounds.width, bounds.height, selected ? 'rgba(35, 87, 82, .95)' : 'rgba(8, 25, 31, .88)', selected ? '#8fffe0' : display?.rarity.color || 'rgba(100,140,130,.16)');
      context.textAlign = 'center'; context.fillStyle = display?.rarity.color || '#496c65'; context.font = '800 10px sans-serif';
      context.fillText(display?.name || '空', bounds.x + bounds.width * 0.5, bounds.y + 22);
      if (display) { context.fillStyle = '#8dbab0'; context.font = '600 9px sans-serif'; context.fillText(`${selected && state.menuState.decomposeMode ? '✓ ' : ''}${SLOT_NAMES[display.slot]}`, bounds.x + bounds.width * 0.5, bounds.y + 41); }
    });
    button(context, controls.inventoryPrev, '‹', false, page > 0);
    button(context, controls.inventoryNext, '›', false, page < pageCount - 1);
    button(context, controls.bulkToggle, state.menuState.decomposeMode ? '退出批量分解' : '批量分解', false, state.meta.inventory.length > 0);
    const hasSelection = Number.isInteger(state.menuState.selectedInventoryIndex) && state.meta.inventory[state.menuState.selectedInventoryIndex];
    if (state.menuState.decomposeMode) {
      button(context, controls.bulkBlue, '选择蓝装', false, state.meta.inventory.some(item => item.rarity === 'blue'));
      button(context, controls.bulkPurple, '选择紫装', false, state.meta.inventory.some(item => item.rarity === 'purple'));
      button(context, controls.bulkConfirm, `分解 ${bulkSelected.size} 件`, true, bulkSelected.size > 0);
    } else {
      button(context, controls.equipSelected, '穿戴选中装备', true, Boolean(hasSelection));
      button(context, controls.decomposeSelected, '分解选中装备', false, Boolean(hasSelection));
    }
    if (hasSelection && !state.menuState.decomposeMode) {
      const display = getItemDisplay(state.meta.inventory[state.menuState.selectedInventoryIndex]);
      panel(context, 34, 198, viewportWidth - 68, 232, 'rgba(8, 20, 29, .98)', display.rarity.color);
      context.textAlign = 'center'; context.fillStyle = display.rarity.color; context.font = '900 42px sans-serif'; context.fillText(display.icon, viewportWidth * 0.5, 252);
      context.font = '900 20px sans-serif'; context.fillText(display.name, viewportWidth * 0.5, 286);
      context.fillStyle = '#d8eee7'; context.font = '700 12px sans-serif'; context.fillText(`${display.rarity.name} · ${SLOT_NAMES[display.slot]}`, viewportWidth * 0.5, 310);
      context.fillStyle = '#8fc0b5'; context.font = '600 12px sans-serif';
      context.fillText(Object.entries(display.stats).map(([key, value]) => `${key.toUpperCase()} +${value}`).join('   '), viewportWidth * 0.5, 338);
      context.fillText(display.desc, viewportWidth * 0.5, 365);
      const set = SETS.find(entry => entry.id === display.setId);
      context.fillStyle = set?.color || '#789d94'; context.font = '700 11px sans-serif';
      if (display.rarity.id === 'gold') {
        context.fillText(`${set.shortName} · 4件：${set.desc4}`, viewportWidth * 0.5, 392);
        context.fillText(`6件：${set.desc6}`, viewportWidth * 0.5, 410);
      } else context.fillText('蓝色与紫色装备提供基础属性，不计入金色套装', viewportWidth * 0.5, 400);
      button(context, controls.detailClose, '×', false, true);
    }
    void equipmentBonus;
  }

  function drawGuild(state) {
    const guildTab = state.menuState.guildTab || 'adventure';
    menuTitle('公会排行', '冒险排行 / 无尽排行');
    button(context, controls.guildAdventure, '⚔ 冒险排行', guildTab === 'adventure', true);
    button(context, controls.guildEndless, '🌀 无尽排行', guildTab === 'endless', true);
    panel(context, 28, 230, viewportWidth - 56, 126, 'rgba(10, 30, 39, .88)', guildTab === 'endless' ? 'rgba(200, 100, 255, .3)' : 'rgba(116, 202, 255, .25)');
    context.textAlign = 'center'; context.fillStyle = guildTab === 'endless' ? '#d19aff' : '#8bcfff'; context.font = '900 34px sans-serif'; context.fillText('🏆', viewportWidth * 0.5, 276);
    context.fillStyle = '#e7f7ff'; context.font = '900 18px sans-serif';
    context.fillText(guildTab === 'endless' ? `最高 第 ${state.meta.highestEndlessWave} 波` : `最高 1-${Math.min(10, state.meta.highestLevel)}`, viewportWidth * 0.5, 306);
    context.fillStyle = '#8eaca7'; context.font = '600 11px sans-serif';
    context.fillText(guildTab === 'endless' ? '虚空试炼个人记录' : `总冒险 ${state.meta.totalRuns} 次`, viewportWidth * 0.5, 328);
    panel(context, 28, 374, viewportWidth - 56, 192, 'rgba(8, 23, 29, .8)', 'rgba(120, 233, 213, .16)');
    context.textAlign = 'left'; context.fillStyle = '#ffe58b'; context.font = '800 14px sans-serif'; context.fillText('1  ▶ 你', 48, 412);
    context.textAlign = 'right'; context.fillText(guildTab === 'endless' ? `${state.meta.highestEndlessWave} 波` : `1-${Math.min(10, state.meta.highestLevel)} · ${state.meta.totalRuns}把`, viewportWidth - 48, 412);
    context.textAlign = 'center'; context.fillStyle = '#789b93'; context.font = '600 12px sans-serif';
    context.fillText('等待微信云排行数据…', viewportWidth * 0.5, 482);
    context.textAlign = 'center'; context.fillStyle = '#617f78'; context.font = '600 10px sans-serif'; context.fillText('联机配置完成后同步真实玩家数据', viewportWidth * 0.5, 598);
  }

  function drawMenu(state) {
    context.fillStyle = 'rgba(7, 20, 25, .34)'; context.fillRect(0, 0, viewportWidth, viewportHeight);
    panel(context, 14, safeTop, 154, 42, 'rgba(8, 23, 31, .88)', 'rgba(126, 221, 203, .18)');
    context.textBaseline = 'middle';
    context.textAlign = 'left';
    context.fillStyle = '#f2ffe9'; context.font = '900 15px sans-serif'; context.fillText(`1-${Math.min(10, state.meta.highestLevel)}`, 28, safeTop + 22);
    context.textAlign = 'right'; context.fillStyle = '#ffd177'; context.font = '800 13px sans-serif';
    context.fillText(`${state.meta.gold} G`, 154, safeTop + 22);
    const tab = state.menuState?.tab || 'adventure';
    button(context, controls.settingsOpen, '⚙', false, true);
    if (tab === 'shop') drawShop(state);
    else if (tab === 'equip') drawEquipment(state);
    else if (tab === 'talent') drawTalent(state);
    else if (tab === 'guild') drawGuild(state);
    else drawAdventure(state);
    if (state.menuState?.notice) {
      panel(context, 34, viewportHeight - 246, viewportWidth - 68, 38, 'rgba(12, 37, 43, .94)', 'rgba(255, 220, 130, .32)');
      context.textAlign = 'center'; context.fillStyle = '#ffe39b'; context.font = '700 11px sans-serif'; context.fillText(state.menuState.notice, viewportWidth * 0.5, viewportHeight - 222);
    }
    const labels = ['商店', '装备', '冒险', '天赋', '公会'];
    const tabY = menuTabY;
    context.fillStyle = 'rgba(10, 20, 29, .98)';
    context.fillRect(0, tabY, viewportWidth, menuTabHeight);
    context.fillStyle = 'rgba(116, 221, 201, .28)';
    context.fillRect(0, tabY, viewportWidth, 1.5);
    controls.tabs.forEach((bounds, index) => {
      const active = bounds.id === tab; const centerX = bounds.x + bounds.width * 0.5;
      context.textAlign = 'center';
      context.textBaseline = 'middle';
      drawNavIcon(context, bounds.id, centerX, active ? tabY + 38 : tabY + 60, active ? 38 : 26, active);
      if (active) {
        context.fillStyle = '#ffe06d';
        context.font = '800 16px sans-serif';
        context.fillText(labels[index], centerX, tabY + 84);
      }
    });
    if (tab === 'shop' && state.menuState?.shopRulesOpen) drawShopRulesModal();
    else if (tab === 'shop' && state.menuState?.shopResultOpen) drawShopResultModal(state);
    else if (state.menuState?.redeemOpen) drawRedeemModal(state);
    else if (state.menuState?.settingsOpen) drawSettingsModal(state);
  }

  function drawBattleGuide(state) {
    const pageIndex = Math.max(0, Math.min(BATTLE_GUIDE_PAGES.length - 1, state.battleUi.guidePage || 0));
    const page = BATTLE_GUIDE_PAGES[pageIndex];
    context.fillStyle = 'rgba(2, 8, 14, .82)'; context.fillRect(0, 0, viewportWidth, viewportHeight);
    panel(context, 20, 34, viewportWidth - 40, viewportHeight - 86, 'rgba(11, 27, 42, .99)', 'rgba(111, 180, 235, .5)');
    context.textAlign = 'center'; context.textBaseline = 'middle';
    context.font = '34px sans-serif'; context.fillText(page.icon, viewportWidth * 0.5, 86);
    context.fillStyle = '#a9d7ff'; context.font = '900 24px sans-serif'; context.fillText(page.title, viewportWidth * 0.5, 124);
    context.fillStyle = '#6f8f9e'; context.font = '700 11px sans-serif'; context.fillText(`${pageIndex + 1} / ${BATTLE_GUIDE_PAGES.length}`, viewportWidth * 0.5, 149);
    page.entries.forEach((entry, index) => {
      const y = 177 + index * 66;
      panel(context, 38, y, viewportWidth - 76, 52, 'rgba(255,255,255,.04)', 'rgba(132,190,220,.11)');
      context.textAlign = 'left'; context.fillStyle = '#7fc5ea'; context.font = '900 14px sans-serif'; context.fillText(`${index + 1}`, 54, y + 27);
      context.fillStyle = '#d6e9ed'; context.font = '650 12px sans-serif'; context.fillText(entry, 82, y + 27);
    });
    if (pageIndex === 0 && state.battleUi?.vfxTestEnabled) {
      button(context, controls.guideReplayTutorial, '重播开场聚光引导', true, true);
    }
    button(context, controls.guidePrev, '‹', false, pageIndex > 0);
    button(context, controls.guideClose, '关闭教程', true, true);
    button(context, controls.guideNext, '›', false, pageIndex < BATTLE_GUIDE_PAGES.length - 1);
  }

  function drawTutorialSpotlight(state) {
    const tutorial = state.tutorialOverlay;
    if (!tutorial) return;
    const spotlight = state.tutorialSpotlight || {};
    const points = Array.isArray(spotlight.points) && spotlight.points.length
      ? spotlight.points
      : [{ x: viewportWidth * 0.5, y: viewportHeight * 0.5 }];
    const target = spotlight.target || points[points.length - 1];
    const radius = Math.max(32, spotlight.radius || 42);
    const time = Number(state.tutorialTime) || 0;
    const pulse = 1 + Math.sin(time * 5.2) * 0.08;
    const accent = tutorial.accent || '#79f1cf';

    context.save();
    context.fillStyle = 'rgba(1, 7, 12, .78)';
    context.fillRect(0, 0, viewportWidth, viewportHeight);
    context.globalCompositeOperation = 'destination-out';
    if (points.length > 1) {
      context.beginPath();
      context.moveTo(points[0].x, points[0].y);
      points.slice(1).forEach(point => context.lineTo(point.x, point.y));
      context.lineWidth = radius * 1.72;
      context.lineCap = 'round';
      context.lineJoin = 'round';
      context.strokeStyle = '#000';
      context.stroke();
    }
    for (const point of points) {
      context.beginPath();
      context.arc(point.x, point.y, radius, 0, Math.PI * 2);
      context.fillStyle = '#000';
      context.fill();
    }
    context.restore();

    if (points.length > 1) {
      context.save();
      context.beginPath();
      context.moveTo(points[0].x, points[0].y);
      points.slice(1).forEach(point => context.lineTo(point.x, point.y));
      context.lineWidth = 3;
      context.lineCap = 'round';
      context.lineJoin = 'round';
      context.strokeStyle = hexToRgba(accent, 0.72);
      context.shadowColor = accent;
      context.shadowBlur = 14;
      context.stroke();
      context.restore();
    }

    points.forEach(point => {
      const isTarget = Math.hypot(point.x - target.x, point.y - target.y) < 2;
      context.save();
      context.beginPath();
      context.arc(point.x, point.y, radius * (isTarget ? pulse : 0.82), 0, Math.PI * 2);
      context.strokeStyle = hexToRgba(accent, isTarget ? 0.96 : 0.48);
      context.lineWidth = isTarget ? 4 : 2;
      context.shadowColor = accent;
      context.shadowBlur = isTarget ? 18 : 8;
      context.stroke();
      context.restore();
    });

    if (spotlight.future) {
      context.save();
      context.setLineDash?.([5, 6]);
      context.beginPath();
      context.arc(spotlight.future.x, spotlight.future.y, radius * 0.82, 0, Math.PI * 2);
      context.strokeStyle = hexToRgba('#61ddff', 0.62);
      context.lineWidth = 2;
      context.stroke();
      context.restore();
    }

    const width = Math.min(334, viewportWidth - 36);
    const isAction = tutorial.interaction === 'board';
    const height = isAction ? 158 : 190;
    const x = (viewportWidth - width) * 0.5;
    const pathMinY = Math.min(...points.map(point => point.y));
    const pathMaxY = Math.max(...points.map(point => point.y));
    const minBubbleY = safeTop + 70;
    const maxBubbleY = viewportHeight - height - 146;
    const belowY = pathMaxY + radius + 22;
    const aboveY = pathMinY - radius - height - 22;
    let y;
    if (belowY <= maxBubbleY) y = Math.max(minBubbleY, belowY);
    else if (aboveY >= minBubbleY) y = Math.min(maxBubbleY, aboveY);
    else y = (pathMinY + pathMaxY) * 0.5 > viewportHeight * 0.5 ? minBubbleY : maxBubbleY;
    panel(context, x, y, width, height, 'rgba(8, 25, 35, .97)', hexToRgba(accent, 0.72));

    context.textAlign = 'center'; context.textBaseline = 'middle';
    const chipWidth = 76;
    roundedRect(context, viewportWidth * 0.5 - chipWidth * 0.5, y + 13, chipWidth, 24, 12);
    context.fillStyle = hexToRgba(accent, 0.15); context.fill();
    context.fillStyle = accent; context.font = '800 11px sans-serif';
    context.fillText(tutorial.stepLabel || '新手引导', viewportWidth * 0.5, y + 25);
    context.fillStyle = '#f4fbf9'; context.font = '900 22px sans-serif';
    context.fillText(tutorial.title || '新手引导', viewportWidth * 0.5, y + 55);
    context.fillStyle = '#bdd4d3'; context.font = '600 12px sans-serif';
    const lines = splitSkillDescription(tutorial.desc || '', 27, 2);
    lines.forEach((line, index) => context.fillText(line, viewportWidth * 0.5, y + 83 + index * 19));

    if (isAction) {
      context.fillStyle = accent; context.font = '900 14px sans-serif';
      context.fillText(`⌄  ${tutorial.hint || '点击高亮落点'}`, viewportWidth * 0.5, y + height - 22);
    } else {
      Object.assign(controls.tutorialClose, {
        x: (viewportWidth - 190) * 0.5, y: y + height - 55, width: 190, height: 40,
      });
      button(context, controls.tutorialClose, tutorial.hint || '继续战斗', true, true);
    }
  }

  function drawBattleSkills(state) {
    const owned = Object.entries(state.skills || {}).filter(([, level]) => level > 0)
      .map(([id, level]) => ({ ...SKILL_BY_ID[id], level })).filter(entry => entry.id);
    const pageCount = Math.max(1, Math.ceil(owned.length / 5));
    const pageIndex = Math.max(0, Math.min(pageCount - 1, state.battleUi.skillsPage || 0));
    const visible = owned.slice(pageIndex * 5, pageIndex * 5 + 5);
    context.fillStyle = 'rgba(2, 8, 14, .82)'; context.fillRect(0, 0, viewportWidth, viewportHeight);
    panel(context, 18, 28, viewportWidth - 36, viewportHeight - 74, 'rgba(30, 24, 54, .99)', 'rgba(178, 132, 241, .5)');
    context.textAlign = 'center'; context.textBaseline = 'middle'; context.fillStyle = '#eee7ff'; context.font = '900 24px sans-serif';
    context.fillText('⚔ 技能 & 组合技', viewportWidth * 0.5, 67);
    context.fillStyle = '#9289ad'; context.font = '700 11px sans-serif'; context.fillText(`已拥有 ${owned.length}/${SKILLS.length} · 第 ${pageIndex + 1}/${pageCount} 页`, viewportWidth * 0.5, 94);
    if (!visible.length) {
      context.fillStyle = '#8f87a4'; context.font = '700 14px sans-serif'; context.fillText('尚未获得技能 · 过关后可三选一', viewportWidth * 0.5, 170);
    }
    visible.forEach((skill, index) => {
      const y = 116 + index * 78;
      panel(context, 34, y, viewportWidth - 68, 66, 'rgba(56, 45, 85, .72)', `${skill.color}88`);
      context.textAlign = 'left'; context.fillStyle = skill.color; context.font = '900 15px sans-serif'; context.fillText(`${skill.name}  Lv.${skill.level}`, 50, y + 22);
      context.fillStyle = '#c9c1dc'; context.font = '600 10px sans-serif'; context.fillText(skill.describe(skill.level), 50, y + 45);
    });
    const comboY = 528;
    context.textAlign = 'left'; context.fillStyle = '#d5b8ff'; context.font = '900 13px sans-serif'; context.fillText('组合技（等级和 ≥ 5）', 38, comboY);
    SKILL_COMBOS.forEach((combo, index) => {
      const total = combo.requires.reduce((sum, id) => sum + (state.skills[id] || 0), 0);
      const active = combo.requires.every(id => (state.skills[id] || 0) > 0) && total >= 5;
      context.fillStyle = active ? '#73efad' : '#706882'; context.font = '700 10px sans-serif';
      context.fillText(`${active ? '✓' : '○'} ${combo.name}  ${total}/5 · ${combo.desc}`, 40, comboY + 25 + index * 22);
    });
    button(context, controls.skillsPrev, '‹', false, pageIndex > 0);
    button(context, controls.skillsClose, '关闭技能', true, true);
    button(context, controls.skillsNext, '›', false, pageIndex < pageCount - 1);
  }

  function drawExitConfirm() {
    context.fillStyle = 'rgba(2, 8, 14, .82)'; context.fillRect(0, 0, viewportWidth, viewportHeight);
    const width = Math.min(326, viewportWidth - 42); const height = 260;
    const x = (viewportWidth - width) * 0.5; const y = (viewportHeight - height) * 0.5;
    panel(context, x, y, width, height, 'rgba(43, 23, 31, .99)', 'rgba(255, 113, 118, .5)');
    context.textAlign = 'center'; context.fillStyle = '#ff9b9c'; context.font = '900 26px sans-serif'; context.fillText('退出本次冒险？', viewportWidth * 0.5, y + 62);
    context.fillStyle = '#d9c9cc'; context.font = '650 12px sans-serif'; context.fillText('已获得金币会按原版规则结算', viewportWidth * 0.5, y + 104);
    context.fillStyle = '#90777d'; context.font = '600 11px sans-serif'; context.fillText('本章技能与当前关卡进度将结束', viewportWidth * 0.5, y + 128);
    button(context, controls.exitCancel, '继续战斗', false, true);
    button(context, controls.exitConfirm, '确认退出', true, true);
  }

  function drawVfxTestPanel(state) {
    context.fillStyle = 'rgba(2, 7, 13, .72)';
    context.fillRect(0, 0, viewportWidth, viewportHeight);
    panel(
      context,
      vfxPanelX,
      vfxPanelY,
      vfxPanelWidth,
      vfxPanelHeight,
      'rgba(16, 24, 42, .985)',
      'rgba(195, 124, 255, .56)'
    );

    context.textAlign = 'left';
    context.textBaseline = 'middle';
    context.fillStyle = '#f4eaff';
    context.font = '900 23px sans-serif';
    context.fillText('3D 特效测试台', vfxPanelX + 22, vfxPanelY + 35);
    context.fillStyle = '#9c8eb5';
    context.font = '650 11px sans-serif';
    context.fillText('选择一种效果 · 触发后自动回到战场', vfxPanelX + 22, vfxPanelY + 62);

    button(context, controls.battleVfxTestClose, '×', false, true);

    VFX_TEST_PRESETS.forEach((preset, index) => {
      const bounds = controls.battleVfxTests[index];
      const active = state.battleUi?.vfxTestLastId === preset.id;
      const groupColors = {
        '攻击反馈': '#ffb67a',
        '技能特效': '#9fd9ff',
        '战斗物件': '#a9e3bd',
        '连击奖励': '#ffd66f',
        '界面测试': '#e7b7ff',
      };
      panel(
        context,
        bounds.x,
        bounds.y,
        bounds.width,
        bounds.height,
        active ? 'rgba(87, 49, 113, .98)' : 'rgba(28, 42, 62, .98)',
        active ? 'rgba(238, 180, 255, .72)' : 'rgba(141, 175, 207, .24)'
      );
      context.textAlign = 'center';
      context.textBaseline = 'middle';
      context.fillStyle = active ? '#fff3c9' : '#eaf5ff';
      context.font = preset.icon.length > 1 ? '900 11px sans-serif' : '16px sans-serif';
      context.fillText(preset.icon, bounds.x + 21, bounds.y + bounds.height * 0.5);
      context.textAlign = 'left';
      context.fillStyle = groupColors[preset.group] || '#9c8eb5';
      context.font = '750 8px sans-serif';
      context.fillText(preset.group, bounds.x + 38, bounds.y + 12);
      context.fillStyle = active ? '#fff3c9' : '#eaf5ff';
      context.font = '800 10px sans-serif';
      context.fillText(preset.label, bounds.x + 38, bounds.y + 30);
    });

    if (state.battleUi?.vfxTestLast) {
      context.textAlign = 'center';
      context.fillStyle = '#cbb9dc';
      context.font = '700 10px sans-serif';
      context.fillText(`最近触发：${state.battleUi.vfxTestLast}`, viewportWidth * 0.5, vfxPanelY + 430);
    }
    button(context, controls.battleVfxTestClear, '清空当前特效', false, true);
  }

  function drawSkillChoiceOverlay(options) {
    const choices = options.choices || [];
    const accent = options.accent || '#79f1cf';
    context.fillStyle = 'rgba(1, 8, 14, .84)';
    context.fillRect(0, 0, viewportWidth, viewportHeight);

    const headerY = skillChoiceStartY - 92;
    context.textAlign = 'center';
    context.textBaseline = 'middle';
    context.fillStyle = accent;
    context.font = '850 11px sans-serif';
    context.fillText(options.eyebrow || '关卡奖励', viewportWidth * 0.5, headerY);
    context.fillStyle = '#f4fff9';
    context.font = '900 31px sans-serif';
    context.fillText(options.title || '选择一项能力', viewportWidth * 0.5, headerY + 31);
    context.fillStyle = '#91aaa6';
    context.font = '650 12px sans-serif';
    context.fillText(options.subtitle || '三选一 · 本次冒险持续生效', viewportWidth * 0.5, headerY + 59);

    context.fillStyle = hexToRgba(accent, 0.78);
    context.fillRect(viewportWidth * 0.5 - 28, headerY + 76, 56, 2);

    choices.slice(0, 3).forEach((skill, index) => {
      const bounds = controls.skills[index];
      const color = skill.color || accent;
      const meta = SKILL_CARD_META[skill.id] || { glyph: skill.name?.slice(0, 1) || '?', category: '战斗能力' };
      const level = Math.max(1, Number(skill.level) || 1);

      context.save();
      context.shadowColor = 'rgba(0, 0, 0, .36)';
      context.shadowBlur = 14;
      context.shadowOffsetY = 7;
      panel(context, bounds.x, bounds.y, bounds.width, bounds.height, 'rgba(8, 26, 36, .975)', hexToRgba(color, 0.62));
      context.restore();

      roundedRect(context, bounds.x, bounds.y + 12, 5, bounds.height - 24, 3);
      context.fillStyle = color;
      context.fill();

      const iconX = bounds.x + 53;
      const iconY = bounds.y + bounds.height * 0.5;
      context.beginPath();
      context.arc(iconX, iconY, 31, 0, Math.PI * 2);
      context.fillStyle = hexToRgba(color, 0.13);
      context.fill();
      context.lineWidth = 2;
      context.strokeStyle = hexToRgba(color, 0.68);
      context.stroke();
      context.beginPath();
      context.arc(iconX, iconY, 23, 0, Math.PI * 2);
      context.fillStyle = hexToRgba(color, 0.2);
      context.fill();
      context.textAlign = 'center';
      context.fillStyle = color;
      context.font = '900 24px sans-serif';
      context.fillText(meta.glyph, iconX, iconY + 1);

      const textX = bounds.x + 98;
      context.textAlign = 'left';
      context.fillStyle = hexToRgba(color, 0.9);
      context.font = '800 10px sans-serif';
      context.fillText(meta.category, textX, bounds.y + 22);
      context.fillStyle = '#f5fff9';
      context.font = '900 19px sans-serif';
      context.fillText(skill.name || '未知技能', textX, bounds.y + 47);

      const levelLabel = level <= 1 ? '新技能' : `Lv.${level - 1} → ${level}`;
      const levelWidth = level <= 1 ? 54 : 72;
      const levelX = bounds.x + bounds.width - levelWidth - 15;
      roundedRect(context, levelX, bounds.y + 14, levelWidth, 24, 12);
      context.fillStyle = hexToRgba(color, 0.16);
      context.fill();
      context.lineWidth = 1;
      context.strokeStyle = hexToRgba(color, 0.42);
      context.stroke();
      context.textAlign = 'center';
      context.fillStyle = color;
      context.font = '800 10px sans-serif';
      context.fillText(levelLabel, levelX + levelWidth * 0.5, bounds.y + 26);

      const lines = splitSkillDescription(skill.desc, viewportWidth >= 420 ? 27 : 23, 2);
      context.textAlign = 'left';
      context.fillStyle = '#a9c0bc';
      context.font = '650 11px sans-serif';
      lines.forEach((line, lineIndex) => context.fillText(line, textX, bounds.y + 76 + lineIndex * 19));

      context.textAlign = 'right';
      context.fillStyle = hexToRgba(color, 0.82);
      context.font = '900 18px sans-serif';
      context.fillText('›', bounds.x + bounds.width - 18, bounds.y + bounds.height - 18);
    });

    context.textAlign = 'center';
    context.fillStyle = '#77918c';
    context.font = '650 11px sans-serif';
    context.fillText(options.footer || '点击卡片选择 · 效果立即生效', viewportWidth * 0.5, skillChoiceStartY + skillCardsHeight + 34);
  }

  function drawBattle(state) {
    context.setTransform(pixelRatio, 0, 0, pixelRatio, 0, 0);
    const leftWidth = Math.min(224, viewportWidth * 0.58);
    panel(context, 14, safeTop, leftWidth, 52, 'rgba(8, 23, 31, .9)', 'rgba(126, 221, 203, .2)');
    context.textBaseline = 'middle';
    context.textAlign = 'left';
    context.fillStyle = '#eafff3';
    context.font = '800 13px sans-serif';
    context.fillText(`1-${state.stage}  ${state.stageName}`, 26, safeTop + 16);
    context.textAlign = 'right';
    context.fillStyle = '#ffd177';
    context.font = '900 12px sans-serif';
    context.fillText(state.isBossStage ? 'BOSS' : `${state.kills}/${state.killTarget}`, 14 + leftWidth - 14, safeTop + 16);

    const healthX = 26;
    const healthY = safeTop + 33;
    const healthWidth = leftWidth - 54;
    roundedRect(context, healthX, healthY, healthWidth, 7, 3.5);
    context.fillStyle = '#112a31';
    context.fill();
    roundedRect(context, healthX, healthY, healthWidth * state.hero.hp / state.hero.maxHp, 7, 3.5);
    context.fillStyle = state.hero.hp > 35 ? '#37dfbd' : '#f07167';
    context.fill();
    context.fillStyle = '#c8e8df';
    context.font = '700 9px sans-serif';
    context.fillText(`${state.hero.hp}`, healthX + healthWidth + 7, healthY + 3.5);

    button(context, controls.battleSettings, '⚙', false, !state.result);
    button(context, controls.battleExit, '×', false, !state.result);
    if (state.isBossStage && state.boss) {
      const bossX = 72; const bossY = safeTop + 91; const bossWidth = viewportWidth - 144;
      roundedRect(context, bossX, bossY, bossWidth, 12, 6); context.fillStyle = '#281731'; context.fill();
      roundedRect(context, bossX, bossY, bossWidth * Math.max(0, state.boss.hp) / state.boss.maxHp, 12, 6);
      context.fillStyle = state.boss.enraged ? '#ff4f85' : '#b95bd4'; context.fill();
      context.textAlign = 'center'; context.fillStyle = '#f8dcff'; context.font = '800 10px sans-serif';
      context.fillText(`${state.boss.hp}/${state.boss.maxHp}${state.bossIntent ? ` · ${state.bossIntent.name}` : ''}`, viewportWidth * 0.5, bossY + 10);
    }
    if (state.combo > 0 && !state.result) {
      const comboWidth = state.combo >= 10 ? 116 : 102;
      const comboX = (viewportWidth - comboWidth) * 0.5;
      const comboY = safeTop + (state.isBossStage ? 112 : 72);
      const comboColor = state.combo >= 5 ? '#ffdb66' : state.combo >= 3 ? '#ff9e54' : '#85f4d5';
      panel(context, comboX, comboY, comboWidth, 42, 'rgba(7, 23, 30, .88)', `${comboColor}88`);
      context.textAlign = 'center';
      context.textBaseline = 'middle';
      context.fillStyle = comboColor;
      context.font = '900 22px sans-serif';
      context.fillText(`×${state.combo}`, viewportWidth * 0.5 - 19, comboY + 21);
      context.fillStyle = '#f5fff9';
      context.font = '900 10px sans-serif';
      context.fillText('COMBO', viewportWidth * 0.5 + 24, comboY + 21);
    }
    button(context, controls.battleGuide, '📖 教程', false, !state.result);
    button(context, controls.battleSkills, '⚔ 技能', false, !state.result);
    if (state.battleUi?.vfxTestEnabled && !state.result) {
      button(context, controls.battleVfxTestOpen, '✨ 特效测试', true, true);
      if (state.battleUi.vfxTestLast) {
        const badgeWidth = Math.min(152, viewportWidth - 40);
        const badgeX = (viewportWidth - badgeWidth) * 0.5;
        const badgeY = controls.battleVfxTestOpen.y - 27;
        panel(context, badgeX, badgeY, badgeWidth, 22, 'rgba(34, 18, 48, .9)', 'rgba(221, 155, 255, .45)');
        context.textAlign = 'center';
        context.textBaseline = 'middle';
        context.fillStyle = '#f1d3ff';
        context.font = '800 10px sans-serif';
        context.fillText(`刚触发：${state.battleUi.vfxTestLast}`, viewportWidth * 0.5, badgeY + 11);
      }
    }

    if (state.battleUi?.skillChoicePreview?.length) {
      drawSkillChoiceOverlay({
        choices: state.battleUi.skillChoicePreview,
        eyebrow: '界面测试 · 关卡奖励',
        title: '选择一项能力',
        subtitle: '比较三张技能卡的层级、文字和点击区域',
        footer: '测试模式 · 点击任意卡片返回战场',
      });
    } else if (state.result === 'win') {
      drawSkillChoiceOverlay({
        choices: state.skillChoices,
        eyebrow: state.isBossStage ? '首领击破 · 最终奖励' : `1-${state.stage} 关卡完成`,
        title: '选择一项能力',
        subtitle: state.isBossStage ? '深渊海妖已被击败' : `${state.stageName} · ${state.kills}/${state.killTarget} 击杀`,
        footer: state.stage >= 10 ? '点击卡片选择 · 选择后完成第一章' : '点击卡片选择 · 本章持续生效',
      });
    } else if (state.result === 'lose') {
      context.fillStyle = 'rgba(3, 13, 18, .68)';
      context.fillRect(0, 0, viewportWidth, viewportHeight);
      const width = Math.min(310, viewportWidth - 48);
      const height = 190;
      const x = (viewportWidth - width) * 0.5;
      const y = (viewportHeight - height) * 0.5;
      panel(context, x, y, width, height, 'rgba(11, 36, 42, .97)', 'rgba(255, 120, 110, .45)');
      context.textAlign = 'center';
      context.fillStyle = '#ff8d80';
      context.font = '900 30px sans-serif';
      context.fillText('企鹅倒下了', viewportWidth * 0.5, y + 62);
      context.fillStyle = '#d7eee8';
      context.font = '600 15px sans-serif';
      context.fillText('重新挑战第一关', viewportWidth * 0.5, y + 108);
      button(context, controls.home, '返回冒险营地', true, true);
    } else if (state.result === 'chapter_complete') {
      context.fillStyle = 'rgba(3, 13, 18, .72)';
      context.fillRect(0, 0, viewportWidth, viewportHeight);
      const width = Math.min(330, viewportWidth - 40);
      const height = 240;
      const x = (viewportWidth - width) * 0.5;
      const y = (viewportHeight - height) * 0.5;
      panel(context, x, y, width, height, 'rgba(12, 38, 43, .98)', 'rgba(255, 226, 130, .54)');
      context.textAlign = 'center';
      context.fillStyle = '#ffe58b';
      context.font = '900 29px sans-serif';
      context.fillText('第一章完成', viewportWidth * 0.5, y + 62);
      context.fillStyle = '#d7eee8';
      context.font = '700 14px sans-serif';
      context.fillText('深渊海沟 · 1-1 至 1-10', viewportWidth * 0.5, y + 102);
      context.fillStyle = '#89b9ae';
      context.font = '600 12px sans-serif';
      context.fillText('深渊海妖已被击败', viewportWidth * 0.5, y + 128);
      button(context, controls.home, '返回冒险营地', true, true);
    }

    if (state.announcement) {
      const width = Math.min(300, viewportWidth - 54);
      const x = (viewportWidth - width) * 0.5;
      const y = safeTop + 128;
      panel(context, x, y, width, 74, 'rgba(5, 20, 27, .92)', 'rgba(255,255,255,.28)');
      context.textAlign = 'center';
      context.textBaseline = 'middle';
      context.fillStyle = state.announcement.color || '#79f1cf';
      context.font = '900 24px sans-serif';
      context.fillText(state.announcement.title, viewportWidth * 0.5, y + 27);
      context.fillStyle = '#d8eee7';
      context.font = '600 12px sans-serif';
      context.fillText(state.announcement.subtitle || '', viewportWidth * 0.5, y + 52);
    }
    if (state.wheelResult) {
      context.fillStyle = 'rgba(3, 8, 18, .78)'; context.fillRect(0, 0, viewportWidth, viewportHeight);
      const lucky = state.wheelResult.type === 'lucky';
      const width = Math.min(330, viewportWidth - 40); const height = 430;
      const x = (viewportWidth - width) * 0.5; const y = (viewportHeight - height) * 0.5;
      panel(context, x, y, width, height, lucky ? 'rgba(18, 49, 54, .98)' : 'rgba(39, 18, 50, .98)', lucky ? 'rgba(255, 220, 100, .55)' : 'rgba(203, 115, 255, .5)');
      context.textAlign = 'center'; context.fillStyle = lucky ? '#ffe58b' : '#d79aff'; context.font = '900 25px sans-serif';
      context.fillText(lucky ? '幸运轮盘' : '厄运轮盘', viewportWidth * 0.5, y + 46);
      const cx = viewportWidth * 0.5; const cy = y + 176; const radius = 102;
      state.wheelResult.outcomes.forEach((outcome, index) => {
        context.beginPath(); context.moveTo(cx, cy); context.arc(cx, cy, radius, -Math.PI * 0.5 + index * Math.PI * 0.5, -Math.PI * 0.5 + (index + 1) * Math.PI * 0.5); context.closePath();
        context.fillStyle = lucky ? (index % 2 ? '#3156a0' : '#2c8059') : (index % 2 ? '#542172' : '#761f37'); context.fill();
        const angle = -Math.PI * 0.25 + index * Math.PI * 0.5;
        context.fillStyle = '#fff'; context.font = '800 20px sans-serif'; context.fillText(outcome.icon, cx + Math.cos(angle) * 59, cy + Math.sin(angle) * 59 + 7);
      });
      context.beginPath(); context.arc(cx, cy, 34, 0, Math.PI * 2); context.fillStyle = '#101b27'; context.fill();
      context.fillStyle = '#fff'; context.font = '900 22px sans-serif'; context.fillText(state.wheelResult.outcome.icon, cx, cy + 8);
      context.fillStyle = lucky ? '#ffe58b' : '#e1a8ff'; context.font = '900 21px sans-serif'; context.fillText(state.wheelResult.outcome.name, cx, y + 310);
      context.fillStyle = '#c7d8d5'; context.font = '600 12px sans-serif'; context.fillText(state.wheelResult.outcome.desc, cx, y + 336);
      button(context, controls.wheelClose, state.wheelResult.outcome.id === 'extra_skill' ? '选择技能' : '继续战斗', lucky, true);
    } else if (state.wheelSkillChoices?.length) {
      drawSkillChoiceOverlay({
        choices: state.wheelSkillChoices,
        accent: '#ffe58b',
        eyebrow: '幸运轮盘 · 额外奖励',
        title: '天赋觉醒',
        subtitle: '额外选择一项能力 · 不消耗本回合',
        footer: '点击卡片选择 · 效果立即生效',
      });
    }
    if (state.tutorialOverlay) drawTutorialSpotlight(state);
    if (state.enemyIntro?.length) {
      context.fillStyle = 'rgba(2, 9, 14, .8)'; context.fillRect(0, 0, viewportWidth, viewportHeight);
      const width = Math.min(348, viewportWidth - 34);
      const height = viewportHeight - 52;
      const x = (viewportWidth - width) * 0.5; const y = (viewportHeight - height) * 0.5;
      panel(context, x, y, width, height, 'rgba(12, 30, 43, .99)', 'rgba(255, 220, 130, .5)');
      context.textAlign = 'center'; context.textBaseline = 'middle';
      context.fillStyle = '#ffe08a'; context.font = '900 25px sans-serif';
      context.fillText('发现新怪物', viewportWidth * 0.5, y + 42);
      context.fillStyle = '#8eaaa5'; context.font = '600 11px sans-serif';
      context.fillText('首次遭遇 · 留意它们的特殊机制', viewportWidth * 0.5, y + 66);
      state.enemyIntro.forEach((info, index) => {
        const rowY = y + 84 + index * 72;
        panel(context, x + 18, rowY, width - 36, 60, 'rgba(255, 255, 255, .045)', 'rgba(255, 255, 255, .08)');
        context.textAlign = 'center'; context.font = '30px sans-serif'; context.fillText(info.icon, x + 49, rowY + 31);
        context.textAlign = 'left'; context.fillStyle = '#ffdc82'; context.font = '900 16px sans-serif'; context.fillText(info.name, x + 82, rowY + 22);
        context.fillStyle = '#bed2cd'; context.font = '600 11px sans-serif'; context.fillText(info.desc, x + 82, rowY + 43);
      });
      button(context, controls.enemyIntroClose, '知道了', true, true);
    }
    if (state.battleUi?.vfxTestOpen) drawVfxTestPanel(state);
    else if (state.battleUi?.settingsOpen) drawSettingsModal({ menuState: { audioState: state.battleUi.audioState } });
    else if (state.battleUi?.guideOpen) drawBattleGuide(state);
    else if (state.battleUi?.skillsOpen) drawBattleSkills(state);
    else if (state.battleUi?.exitConfirmOpen) drawExitConfirm();
  }

  function draw(state) {
    lastState = state;
    context.setTransform(pixelRatio, 0, 0, pixelRatio, 0, 0);
    context.clearRect(0, 0, viewportWidth, viewportHeight);
    if (state.mode === 'menu') drawMenu(state);
    else drawBattle(state);

    texture.needsUpdate = true;
  }

  function contains(bounds, x, y) {
    return x >= bounds.x && x <= bounds.x + bounds.width && y >= bounds.y && y <= bounds.y + bounds.height;
  }

  function hitTest(x, y) {
    if (lastState?.mode === 'menu') {
      if (lastState.menuState?.settingsOpen) {
        if (contains(controls.settingsClose, x, y)) return 'settings_close';
        if (contains(controls.bgmMinus, x, y)) return 'bgm_minus';
        if (contains(controls.bgmPlus, x, y)) return 'bgm_plus';
        if (contains(controls.sfxMinus, x, y)) return 'sfx_minus';
        if (contains(controls.sfxPlus, x, y)) return 'sfx_plus';
        if (contains(controls.comboScale, x, y)) return 'combo_scale';
        if (contains(controls.comboClassic, x, y)) return 'combo_classic';
        for (const bounds of controls.trackButtons) if (contains(bounds, x, y)) return `track_${bounds.id}`;
        return null;
      }
      if (lastState.menuState?.redeemOpen) {
        if (contains(controls.redeemCancel, x, y)) return 'redeem_cancel';
        if (contains(controls.redeemSubmit, x, y)) return 'redeem_submit';
        return null;
      }
      if (lastState.menuState?.shopRulesOpen) {
        return contains(controls.shopRulesClose, x, y) ? 'shop_rules_close' : null;
      }
      if (lastState.menuState?.shopResultOpen) {
        const elapsed = (Date.now() - (lastState.menuState.shopResultOpenedAt || Date.now())) / 1000;
        return elapsed >= 0.68 && contains(controls.shopResultClose, x, y) ? 'shop_result_close' : null;
      }
      if (contains(controls.redeemOpen, x, y)) return 'redeem_open';
      if (contains(controls.settingsOpen, x, y)) return 'settings_open';
      for (const bounds of controls.tabs) if (contains(bounds, x, y)) return `tab_${bounds.id}`;
      const tab = lastState.menuState?.tab || 'adventure';
      if (tab === 'adventure' && contains(controls.start, x, y)) return 'start';
      if (tab === 'adventure') {
        if (contains(controls.adventurePrev, x, y)) return 'adventure_prev';
        if (contains(controls.adventureNext, x, y)) return 'adventure_next';
      }
      if (tab === 'shop') {
        if (contains(controls.shopRules, x, y)) return 'shop_rules';
        if (contains(controls.shopPrev, x, y)) return 'shop_prev';
        if (contains(controls.shopNext, x, y)) return 'shop_next';
        if (contains(controls.pullSingle, x, y)) return 'pull_1';
        if (contains(controls.pullTriple, x, y)) return 'pull_3';
      }
      if (tab === 'guild') {
        if (contains(controls.guildAdventure, x, y)) return 'guild_adventure';
        if (contains(controls.guildEndless, x, y)) return 'guild_endless';
      }
      if (tab === 'talent') {
        for (const bounds of controls.talents) if (contains(bounds, x, y)) return `talent_${bounds.id}`;
      }
      if (tab === 'equip') {
        if (lastState.menuState?.selectedInventoryIndex != null && !lastState.menuState?.decomposeMode) {
          if (contains(controls.detailClose, x, y)) return 'detail_close';
          if (contains(controls.equipSelected, x, y)) return 'equip_selected';
          if (contains(controls.decomposeSelected, x, y)) return 'decompose_selected';
          return null;
        }
        for (const bounds of controls.equipSlots) if (contains(bounds, x, y)) return `slot_${bounds.slot}`;
        const page = Math.max(0, lastState.menuState?.inventoryPage || 0);
        for (let index = 0; index < controls.inventory.length; index += 1) {
          if (contains(controls.inventory[index], x, y)) return `inventory_${page * 6 + index}`;
        }
        if (contains(controls.inventoryPrev, x, y)) return 'inventory_prev';
        if (contains(controls.inventoryNext, x, y)) return 'inventory_next';
        if (contains(controls.bulkToggle, x, y)) return 'bulk_toggle';
        if (lastState.menuState?.decomposeMode) {
          if (contains(controls.bulkBlue, x, y)) return 'bulk_blue';
          if (contains(controls.bulkPurple, x, y)) return 'bulk_purple';
          if (contains(controls.bulkConfirm, x, y)) return 'bulk_confirm';
        } else {
          if (contains(controls.equipSelected, x, y)) return 'equip_selected';
          if (contains(controls.decomposeSelected, x, y)) return 'decompose_selected';
        }
      }
      return null;
    }
    if (lastState?.enemyIntro?.length) return contains(controls.enemyIntroClose, x, y) ? 'enemy_intro_close' : null;
    if (lastState?.tutorialOverlay) {
      if (lastState.tutorialOverlay.interaction !== 'board') {
        return contains(controls.tutorialClose, x, y) ? 'tutorial_close' : 'tutorial_block';
      }
      const targetBounds = lastState.tutorialSpotlight?.actionBounds;
      return targetBounds && contains(targetBounds, x, y) ? 'tutorial_action' : 'tutorial_block';
    }
    if (lastState?.wheelResult) return contains(controls.wheelClose, x, y) ? 'wheel_close' : null;
    if (lastState?.battleUi?.skillChoicePreview?.length) {
      for (let index = 0; index < controls.skills.length; index += 1) {
        if (contains(controls.skills[index], x, y)) return `battle_skill_preview_${index}`;
      }
      return 'battle_skill_preview_block';
    }
    if (lastState?.wheelSkillChoices?.length) {
      for (let index = 0; index < controls.skills.length; index += 1) {
        if (contains(controls.skills[index], x, y)) return `wheel_skill_${index}`;
      }
      return null;
    }
    if (lastState?.battleUi?.vfxTestOpen) {
      if (contains(controls.battleVfxTestClose, x, y)) return 'battle_vfx_test_close';
      if (contains(controls.battleVfxTestClear, x, y)) return 'battle_vfx_test_clear';
      for (const bounds of controls.battleVfxTests) {
        if (contains(bounds, x, y)) return `battle_vfx_test_${bounds.id}`;
      }
      return 'battle_vfx_test_block';
    }
    if (lastState?.battleUi?.settingsOpen) {
      if (contains(controls.settingsClose, x, y)) return 'battle_settings_close';
      if (contains(controls.bgmMinus, x, y)) return 'bgm_minus';
      if (contains(controls.bgmPlus, x, y)) return 'bgm_plus';
      if (contains(controls.sfxMinus, x, y)) return 'sfx_minus';
      if (contains(controls.sfxPlus, x, y)) return 'sfx_plus';
      if (contains(controls.comboScale, x, y)) return 'combo_scale';
      if (contains(controls.comboClassic, x, y)) return 'combo_classic';
      for (const bounds of controls.trackButtons) if (contains(bounds, x, y)) return `track_${bounds.id}`;
      return null;
    }
    if (lastState?.battleUi?.guideOpen) {
      if (lastState.battleUi.guidePage === 0 && lastState.battleUi.vfxTestEnabled
        && contains(controls.guideReplayTutorial, x, y)) return 'guide_replay_tutorial';
      if (contains(controls.guidePrev, x, y)) return 'guide_prev';
      if (contains(controls.guideNext, x, y)) return 'guide_next';
      return contains(controls.guideClose, x, y) ? 'guide_close' : null;
    }
    if (lastState?.battleUi?.skillsOpen) {
      if (contains(controls.skillsPrev, x, y)) return 'battle_skills_prev';
      if (contains(controls.skillsNext, x, y)) return 'battle_skills_next';
      return contains(controls.skillsClose, x, y) ? 'battle_skills_close' : null;
    }
    if (lastState?.battleUi?.exitConfirmOpen) {
      if (contains(controls.exitCancel, x, y)) return 'exit_cancel';
      return contains(controls.exitConfirm, x, y) ? 'exit_confirm' : null;
    }
    if (contains(controls.battleSettings, x, y)) return 'battle_settings_open';
    if (contains(controls.battleExit, x, y)) return 'battle_exit';
    if (contains(controls.battleGuide, x, y)) return 'guide_open';
    if (contains(controls.battleSkills, x, y)) return 'battle_skills_open';
    if (lastState?.battleUi?.vfxTestEnabled && contains(controls.battleVfxTestOpen, x, y)) return 'battle_vfx_test_open';
    for (let index = 0; index < controls.skills.length; index += 1) {
      if (contains(controls.skills[index], x, y)) return `skill_${index}`;
    }
    if (contains(controls.start, x, y)) return 'start';
    if (contains(controls.home, x, y)) return 'home';
    return null;
  }

  function render() {
    renderer.autoClear = false;
    renderer.clearDepth();
    renderer.render(scene, camera);
    renderer.autoClear = true;
  }

  return { draw, hitTest, render };
}
