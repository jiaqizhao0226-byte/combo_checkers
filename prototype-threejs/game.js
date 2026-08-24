import * as THREE from './vendor/three.module.js';
import { createEnvironment } from './src/game/Environment.js';
import { createHexBoard, axialToWorld } from './src/game/HexBoard.js';
import { BattleCameraController } from './src/game/BattleCameraController.js';
import { buildThreatLinks, threatLineStyle } from './src/game/ThreatPreview.js';
import { createBattleObstacle, createChapterOneEnemy, createPenguin, createScarecrow } from './src/game/Units.js';
import { createLevelOne } from './src/core/LevelOne.js';
import { skillChoiceView } from './src/core/ChapterOneData.js';
import { hexDistance } from './src/core/HexRules.js';
import {
  SETS, createMetaProgress, decomposeInventoryItems, equipInventoryItem, getCritRate,
  getGoldBonus, getHeroStats, getSetEffects, pullEquipment, redeemCode, unequipSlot, upgradeTalent,
} from './src/core/MetaGame.js';
import { createHudOverlay } from './src/wechat/HudOverlay.js';
import { createAudioManager } from './src/wechat/AudioManager.js';
import { VfxDirector } from './src/vfx/VfxDirector.js';
import { ComboRewardDirector } from './src/vfx/ComboRewardDirector.js';
import { createDamageNumberLaneAllocator } from './src/vfx/DamageNumberLayout.js';
import { VFX_TEST_MODE, VFX_TEST_PRESETS, isBattleVfxApproved } from './src/vfx/VfxTestConfig.js';
import { createTrackingDart, faceProjectileAlongScreen } from './src/vfx/ProjectileModels.js';

// Native WeChat Mini Game entry. There is intentionally no DOM, HTML, CSS or
// React here: Three.js renders to the wx canvas and the HUD uses an offscreen
// canvas texture. The browser prototype continues to use index.html.

const CHAPTER_ONE_THEME = 'abyss_trench';
// Keep the hub near the enemy shell while allowing the visible blades to enter
// the body silhouette. The dart disappears on the contact frame, so this reads
// as a committed hit without leaving the projectile embedded in the model.
const TRACKING_DART_ENEMY_CONTACT_OFFSET = 0.62;

const system = wx.getSystemInfoSync();
const canvas = wx.createCanvas();
if (!canvas.addEventListener) canvas.addEventListener = () => {};
if (!canvas.removeEventListener) canvas.removeEventListener = () => {};
if (!canvas.style) canvas.style = {};

const pixelRatio = Math.max(1, Math.min(2, system.pixelRatio || 1));
const viewportWidth = system.windowWidth || system.screenWidth || 375;
const viewportHeight = system.windowHeight || system.screenHeight || 812;
const reportedSafeTop = Number(system.safeArea?.top) || Number(system.statusBarHeight) || 0;
const hasTallIosCutout = system.platform === 'ios' && viewportHeight / viewportWidth > 1.8;
const safeAreaTop = Math.max(reportedSafeTop, hasTallIosCutout ? 47 : 20);
canvas.width = Math.round(viewportWidth * pixelRatio);
canvas.height = Math.round(viewportHeight * pixelRatio);

const renderer = new THREE.WebGLRenderer({ canvas, antialias: false, alpha: false, powerPreference: 'high-performance' });
renderer.setPixelRatio(pixelRatio);
renderer.setSize(viewportWidth, viewportHeight, false);
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFShadowMap;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.3;
renderer.outputColorSpace = THREE.SRGBColorSpace;

const scene = new THREE.Scene();
scene.background = new THREE.Color(0x0b4053);
scene.fog = new THREE.Fog(0x0b4053, 23, 42);

const aspect = viewportWidth / viewportHeight;
const viewWidth = 12.3;
const camera = new THREE.OrthographicCamera(
  -viewWidth * 0.5,
  viewWidth * 0.5,
  viewWidth / aspect * 0.5,
  -viewWidth / aspect * 0.5,
  0.1,
  80
);
const MENU_CAMERA_POSITION = new THREE.Vector3(13.2, 17.5, 18.4);
const MENU_CAMERA_TARGET = new THREE.Vector3(0, 0.2, 0.25);
const BATTLE_CAMERA_POSITION = new THREE.Vector3(0, 22, 11.5);
const BATTLE_CAMERA_TARGET = new THREE.Vector3(0, 0.15, 0.25);
const BATTLE_CAMERA_OFFSET = BATTLE_CAMERA_POSITION.clone().sub(BATTLE_CAMERA_TARGET);
const DEFAULT_BATTLE_ZOOM = 1.45;
const MIN_BATTLE_ZOOM = 0.82;
const MAX_BATTLE_ZOOM = 1.75;
let battleZoom = DEFAULT_BATTLE_ZOOM;
const battleCameraFocus = BATTLE_CAMERA_TARGET.clone();
let battleCameraController = null;
let cameraActionShot = null;

function applyBattleCameraTransform() {
  camera.position.copy(battleCameraFocus).add(BATTLE_CAMERA_OFFSET);
  camera.up.set(0, 1, 0);
  camera.zoom = battleZoom;
  camera.lookAt(battleCameraFocus);
  camera.updateProjectionMatrix();
  camera.updateMatrixWorld();
}

function applyCameraProfile(mode) {
  const battle = mode === 'battle';
  if (battle) {
    applyBattleCameraTransform();
    return;
  }
  camera.position.copy(MENU_CAMERA_POSITION);
  camera.up.set(0, 1, 0);
  camera.zoom = 1;
  camera.lookAt(MENU_CAMERA_TARGET);
  camera.updateProjectionMatrix();
  camera.updateMatrixWorld();
}

function setBattleZoom(nextZoom) {
  if (!battleCameraController) return;
  const state = battleCameraController.setUserZoom(nextZoom, { immediate: true });
  battleZoom = state.zoom;
  battleCameraFocus.copy(state.focus);
  if (appMode === 'battle') {
    applyBattleCameraTransform();
  }
}

applyCameraProfile('menu');

scene.add(new THREE.HemisphereLight(0xa1d9dc, 0x174c5d, 1.3));
scene.add(new THREE.AmbientLight(0x5799a4, 0.68));

const keyLight = new THREE.DirectionalLight(0xd0ece7, 2.72);
keyLight.position.set(14, 14, 9);
keyLight.castShadow = true;
keyLight.shadow.mapSize.set(1024, 1024);
keyLight.shadow.camera.near = 1;
keyLight.shadow.camera.far = 48;
// Both forest and abyss themes keep their largest silhouettes within roughly
// 14 world units, so the shadow box remains stable while the camera zooms.
Object.assign(keyLight.shadow.camera, { left: -15, right: 15, top: 15, bottom: -15 });
keyLight.shadow.bias = -0.001;
keyLight.shadow.normalBias = 0.075;
scene.add(keyLight, keyLight.target);

const fillLight = new THREE.DirectionalLight(0x70b7c4, 0.78);
fillLight.position.set(-10, 7, -9);
scene.add(fillLight);

const rimLight = new THREE.DirectionalLight(0x62d5c9, 0.92);
rimLight.position.set(-8, 10, -12);
scene.add(rimLight);

const environment = createEnvironment(scene, { theme: CHAPTER_ONE_THEME });
const board = createHexBoard(scene, { theme: CHAPTER_ONE_THEME });
const boardBounds = board.cells.reduce((bounds, cell) => ({
  minX: Math.min(bounds.minX, cell.mesh.position.x - 0.72),
  maxX: Math.max(bounds.maxX, cell.mesh.position.x + 0.72),
  minZ: Math.min(bounds.minZ, cell.mesh.position.z - 0.72),
  maxZ: Math.max(bounds.maxZ, cell.mesh.position.z + 0.72),
}), { minX: Infinity, maxX: -Infinity, minZ: Infinity, maxZ: -Infinity });
battleCameraController = new BattleCameraController({
  viewWidth,
  aspect,
  viewportWidth,
  viewportHeight,
  cameraOffset: BATTLE_CAMERA_OFFSET,
  boardBounds,
  focusY: BATTLE_CAMERA_TARGET.y,
  initialFocus: BATTLE_CAMERA_TARGET,
  defaultZoom: DEFAULT_BATTLE_ZOOM,
  minZoom: MIN_BATTLE_ZOOM,
  maxZoom: MAX_BATTLE_ZOOM,
  // Characters are framed between the compact top status bar and the bottom
  // tutorial/skill controls. The board itself may extend behind the HUD.
  safeRect: {
    left: 18,
    right: viewportWidth - 18,
    top: safeAreaTop + 118,
    bottom: viewportHeight - 196,
  },
});
let level = createLevelOne();
let appMode = 'menu';

const storedProgress = typeof wx.getStorageSync === 'function' ? wx.getStorageSync('combo-checkers-progress') : null;
const meta = createMetaProgress(storedProgress && typeof storedProgress === 'object' ? storedProgress : {});
const storedAudio = typeof wx.getStorageSync === 'function' ? wx.getStorageSync('combo-checkers-audio-settings') : null;
const audio = createAudioManager(wx, storedAudio && typeof storedAudio === 'object' ? storedAudio : {});
const menuState = {
  tab: 'adventure', notice: '', selectedInventoryIndex: null, inventoryPage: 0,
  shopResults: [], shopSetIndex: 0, selectedChapter: 1, guildTab: 'adventure',
  shopRulesOpen: false, shopResultOpen: false, shopResultOpenedAt: 0,
  redeemOpen: false, redeemCode: '', redeemStatus: '', redeemError: false, redeemSuccess: false,
  settingsOpen: false, audioState: audio.state,
  decomposeMode: false, decomposeSelectedIndices: [],
};
const battleUi = {
  settingsOpen: false, guideOpen: false, guidePage: 0,
  skillsOpen: false, skillsPage: 0, exitConfirmOpen: false,
  vfxTestEnabled: VFX_TEST_MODE, vfxTestOpen: false, vfxTestLast: '', vfxTestLastId: '',
  skillChoicePreview: null, tutorialPreview: false,
  audioState: audio.state,
};
let settledResult = null;
let runSettled = true;

function saveMeta() {
  if (typeof wx.setStorageSync === 'function') wx.setStorageSync('combo-checkers-progress', meta);
}

function setMenuNotice(message) {
  menuState.notice = message || '';
}

function hideRedeemKeyboard() {
  if (typeof wx.hideKeyboard === 'function') {
    try { wx.hideKeyboard({}); } catch (error) { console.warn('[combo-checkers] hideKeyboard unavailable', error?.message || error); }
  }
}

function showRedeemKeyboard() {
  if (typeof wx.showKeyboard !== 'function') return;
  try {
    wx.showKeyboard({ defaultValue: menuState.redeemCode, maxLength: 24, multiple: false, confirmType: 'done' });
  } catch (error) {
    menuState.redeemStatus = '请在真机微信环境中输入兑换码';
    menuState.redeemError = true;
    console.warn('[combo-checkers] showKeyboard unavailable', error?.message || error);
  }
}

function submitRedeem() {
  const outcome = redeemCode(meta, menuState.redeemCode);
  menuState.redeemError = !outcome.ok;
  menuState.redeemSuccess = outcome.ok;
  menuState.redeemStatus = outcome.ok ? `兑换成功！${outcome.desc} +${outcome.gold} 金币` : outcome.error;
  if (outcome.ok) { saveMeta(); hideRedeemKeyboard(); }
  refresh();
}

if (typeof wx.onKeyboardInput === 'function') {
  wx.onKeyboardInput(event => {
    if (!menuState.redeemOpen || menuState.redeemSuccess) return;
    menuState.redeemCode = String(event.value || '').slice(0, 24).toUpperCase();
    menuState.redeemStatus = '';
    menuState.redeemError = false;
    refresh();
  });
}
if (typeof wx.onKeyboardConfirm === 'function') {
  wx.onKeyboardConfirm(event => {
    if (!menuState.redeemOpen || menuState.redeemSuccess) return;
    menuState.redeemCode = String(event.value ?? menuState.redeemCode).slice(0, 24).toUpperCase();
    submitRedeem();
  });
}

const BATTLE_UNIT_SCALE = 0.86;
const HERO_BATTLE_SCALE = 0.91;
const hero = createPenguin();
hero.userData.baseY = 0.18;
hero.userData.menuScale = hero.scale.clone().multiplyScalar(1.72);
hero.userData.battleScale = hero.scale.clone().multiplyScalar(BATTLE_UNIT_SCALE * HERO_BATTLE_SCALE);
hero.scale.copy(hero.userData.battleScale);
hero.userData.facingYaw = 0;
hero.userData.targetFacingYaw = 0;
scene.add(hero);

const heroShieldAura = new THREE.Group();
heroShieldAura.name = 'HeroShieldAura';
const shieldShell = new THREE.Mesh(
  new THREE.SphereGeometry(0.68, 14, 9),
  new THREE.MeshBasicMaterial({
    color: 0x72dfff, transparent: true, opacity: 0.13,
    wireframe: true, depthWrite: false, toneMapped: false,
  })
);
shieldShell.position.y = 0.78;
const shieldOrbit = new THREE.Mesh(
  new THREE.TorusGeometry(0.62, 0.025, 5, 24),
  new THREE.MeshBasicMaterial({ color: 0xb7f4ff, transparent: true, opacity: 0.72, depthWrite: false, toneMapped: false })
);
shieldOrbit.position.y = 0.7;
shieldOrbit.rotation.x = Math.PI * 0.5;
heroShieldAura.add(shieldShell, shieldOrbit);
hero.add(heroShieldAura);
heroShieldAura.visible = false;

const actors = [hero];
const enemyActors = new Map();
const itemActors = new Map();
const obstacleActors = new Map();
let scarecrowActor = null;
let movement = null;
let turnSequence = null;
let queuedHeroAction = null;
const battleEffects = [];
const effectGroup = new THREE.Group();
effectGroup.name = 'BattlePresentationEffects';
scene.add(effectGroup);
let vfxShakeStrength = 0;
let vfxShakeDuration = 0;
let vfxShakeRemaining = 0;
const vfxDirector = new VfxDirector(scene, {
  onCameraImpulse(strength, duration) {
    vfxShakeStrength = Math.max(vfxShakeStrength, strength || 0);
    vfxShakeDuration = Math.max(vfxShakeDuration, duration || 0);
    vfxShakeRemaining = Math.max(vfxShakeRemaining, duration || 0);
  },
});
const comboRewardDirector = new ComboRewardDirector(scene, camera, {
  board,
  hero,
  getEnemyActor: enemyId => enemyActors.get(enemyId),
  holdActor(actor, seconds) {
    actor.userData.projectileHoldUntil = Math.max(
      actor.userData.projectileHoldUntil || 0,
      renderTime + seconds
    );
  },
  onActorsReleased() {
    syncEnemyActors(false);
  },
  createPreviewActor(position, index) {
    const previewTypes = ['slime', 'archerfish', 'iron_turtle', 'jellyfish'];
    const actor = createChapterOneEnemy(previewTypes[index % previewTypes.length]);
    actor.scale.multiplyScalar(BATTLE_UNIT_SCALE);
    actor.position.copy(position);
    actor.position.y = 0.18;
    actor.userData.baseY = 0.18;
    scene.add(actor);
    return actor;
  },
  releasePreviewActor(actor) {
    scene.remove(actor);
    actor.traverse?.(child => {
      child.geometry?.dispose?.();
      if (Array.isArray(child.material)) child.material.forEach(material => material?.dispose?.());
      else child.material?.dispose?.();
    });
  },
});
let announcementTime = 0;
let renderTime = 0;
const damageNumberLanes = createDamageNumberLaneAllocator();

function combatTextTargetKey(event, q, r) {
  if (event.target === 'hero' || event.type === 'hero_hit' || event.type === 'heal') return 'hero';
  return event.enemyId ? `enemy:${event.enemyId}` : `cell:${q}:${r}`;
}

function reserveCombatTextOffset(event, q, r) {
  return damageNumberLanes.reserve(combatTextTargetKey(event, q, r), renderTime);
}
let shieldVisualActive = false;
let shieldBreakAt = 0;

function cellPosition(q, r, y = 0.18) {
  const position = axialToWorld(q, r);
  return new THREE.Vector3(position.x, y, position.z);
}

function projectWorldToHud(position) {
  const projected = position.clone().project(camera);
  return {
    x: (projected.x * 0.5 + 0.5) * viewportWidth,
    y: (-projected.y * 0.5 + 0.5) * viewportHeight,
  };
}

function buildTutorialSpotlight() {
  const tutorial = level.state.tutorialOverlay;
  if (!tutorial) return null;
  const cells = Array.isArray(tutorial.focusCells) ? tutorial.focusCells : [];
  const points = cells.map(cell => projectWorldToHud(cellPosition(cell.q, cell.r, 0.42)));
  const target = tutorial.targetCell
    ? projectWorldToHud(cellPosition(tutorial.targetCell.q, tutorial.targetCell.r, 0.42))
    : (points[points.length - 1] || projectWorldToHud(hero.position.clone().add(new THREE.Vector3(0, 0.7, 0))));
  const worldCenter = tutorial.targetCell
    ? cellPosition(tutorial.targetCell.q, tutorial.targetCell.r, 0.42)
    : hero.position.clone();
  const edge = projectWorldToHud(worldCenter.clone().add(new THREE.Vector3(0.7, 0, 0)));
  const radius = THREE.MathUtils.clamp(Math.hypot(edge.x - target.x, edge.y - target.y), 34, 49);
  const future = tutorial.futureCell
    ? projectWorldToHud(cellPosition(tutorial.futureCell.q, tutorial.futureCell.r, 0.42))
    : null;
  return {
    points: points.length ? points : [target], target, future, radius,
    actionBounds: {
      x: target.x - radius * 0.92, y: target.y - radius * 0.92,
      width: radius * 1.84, height: radius * 1.84,
    },
  };
}

function runVfxTest(testId) {
  if (!VFX_TEST_MODE || appMode !== 'battle') return;
  const test = VFX_TEST_PRESETS.find(preset => preset.id === testId);
  if (!test) return;
  const livingEnemies = level.state.enemies
    .filter(enemy => enemy.hp > 0)
    .sort((first, second) => hexDistance(level.state.hero, first) - hexDistance(level.state.hero, second));
  const heroCenter = hero.position.clone();
  heroCenter.y += 0.76;
  const heroGround = hero.position.clone();
  heroGround.y = 0.22;
  const fallbackOffsets = [
    new THREE.Vector3(1.7, 0, -0.6),
    new THREE.Vector3(-1.15, 0, -1.55),
    new THREE.Vector3(1.35, 0, 1.45),
  ];
  const targetPoints = livingEnemies.slice(0, 3).map(enemy => {
    const actor = enemyActors.get(enemy.id);
    const point = actor?.position?.clone?.() || cellPosition(enemy.q, enemy.r);
    point.y += 0.68;
    return point;
  });
  while (targetPoints.length < 3) {
    const fallback = fallbackOffsets[targetPoints.length].clone().add(heroCenter);
    fallback.y = heroCenter.y;
    targetPoints.push(fallback);
  }

  if (test.effect === 'impact') {
    hero.userData.playAction?.('jump_attack', 0.56);
    const target = livingEnemies[0] ? enemyActors.get(livingEnemies[0].id) : null;
    target?.userData.playAction?.('hit', 0.46);
    vfxDirector.impact({
      position: targetPoints[0],
      direction: targetPoints[0].clone().sub(heroCenter),
      camera,
      strong: test.strong,
    });
    audio.playSfx('attack_hit');
  } else if (test.effect === 'combo') {
    hero.userData.playAction?.('cast', 0.78);
    vfxDirector.comboBurst({ position: heroGround, camera, combo: test.combo || 3 });
  } else if (test.effect === 'lightning') {
    hero.userData.playAction?.('cast', 0.68);
    livingEnemies.slice(0, 3).forEach(enemy => enemyActors.get(enemy.id)?.userData.playAction?.('hit', 0.5));
    vfxDirector.lightningChain({ points: [heroCenter, ...targetPoints], camera });
    audio.playSfx('attack_hit');
  } else if (test.effect === 'quake') {
    hero.userData.playAction?.('land', 0.5);
    livingEnemies.slice(0, 3).forEach(enemy => enemyActors.get(enemy.id)?.userData.playAction?.('hit', 0.5));
    vfxDirector.quake({ position: heroGround });
  } else if (test.effect === 'dart') {
    hero.userData.playAction?.('cast', 0.58);
    // Keep the in-game VFX test on the same timing as the real combo reward
    // and the original Lua implementation: 0.6s total, target reached in the
    // first 80% of the effect.
    launchTrackingDart(heroCenter, targetPoints[0], 0.6, 0xffb64c, { kind: 'enemy', damage: 30 });
  } else if (test.effect === 'scarecrow') {
    hero.userData.playAction?.('cast', 0.62);
    const previewPosition = heroGround.clone().add(new THREE.Vector3(-1.45, 0, -0.45));
    previewScarecrowModel(previewPosition);
  } else if (test.effect === 'combo_reward') {
    const actions = {
      4: ['hex_blast_cast', 0.9],
      5: ['life_drain_cast', 1.08],
      6: ['time_stop_cast', 1.05],
      7: ['meteor_cast', 1.78],
      8: ['absolute_reflect_cast', 1.1],
    };
    const [actionName, duration] = actions[test.combo] || ['cast', 0.72];
    hero.userData.playAction?.(actionName, duration);
    comboRewardDirector.preview(test.combo, level.state);
  } else if (test.effect === 'skill_choice_ui') {
    battleUi.skillChoicePreview = [
      skillChoiceView('quake_land', 0),
      skillChoiceView('combo_shield', 1),
      skillChoiceView('frost_mark', 2),
    ];
  }

  battleUi.vfxTestLast = test.label;
  battleUi.vfxTestLastId = test.id;
  battleUi.vfxTestOpen = false;
  console.log('[combo-checkers][vfx-test]', { preset: test.id, effect: test.effect, activeEffects: vfxDirector.activeCount });
  refresh({ consumeEvents: false });
}

function applyVfxCameraShake(delta, time) {
  if (vfxShakeRemaining <= 0 || appMode !== 'battle') return;
  vfxShakeRemaining = Math.max(0, vfxShakeRemaining - delta);
  const falloff = vfxShakeDuration > 0 ? vfxShakeRemaining / vfxShakeDuration : 0;
  const strength = vfxShakeStrength * falloff;
  camera.position.x += (Math.sin(time * 87) + Math.sin(time * 143) * 0.45) * strength;
  camera.position.y += Math.sin(time * 113) * strength * 0.34;
  camera.position.z += Math.cos(time * 97) * strength * 0.42;
  camera.lookAt(battleCameraFocus);
  camera.updateMatrixWorld();
  if (vfxShakeRemaining <= 0) {
    vfxShakeStrength = 0;
    vfxShakeDuration = 0;
  }
}

function buildPlayerCameraShot() {
  const heroPoint = hero.position.clone();
  // Follow the penguin's live ground projection during movement. Using the
  // start/end cells here made a multi-hop route change its camera target one
  // grid at a time, while using the jump height made the whole view bob.
  heroPoint.y = hero.userData.baseY ?? BATTLE_CAMERA_TARGET.y;
  if (cameraActionShot?.releaseAt != null && renderTime >= cameraActionShot.releaseAt) {
    cameraActionShot = null;
  }
  if (cameraActionShot?.mode === 'hero_action') {
    return {
      ...cameraActionShot,
      primary: heroPoint,
      points: [heroPoint],
    };
  }
  if (cameraActionShot) return cameraActionShot;

  if (level.state.phase === 'PLAYER_PLAN' || level.state.plan.length > 0) {
    const points = [heroPoint];
    level.state.plan.forEach(cell => points.push(cellPosition(cell.q, cell.r)));
    level.availableActions()
      .filter(action => action.kind === 'jump')
      .forEach(action => points.push(cellPosition(action.q, action.r)));
    return { mode: 'planning', primary: heroPoint, points, margin: 0.78 };
  }

  return { mode: 'idle', primary: heroPoint, points: [heroPoint], margin: 0.68 };
}

function updateDynamicBattleCamera(delta) {
  if (appMode !== 'battle') return;
  const state = battleCameraController.update(delta, buildPlayerCameraShot());
  battleZoom = state.zoom;
  battleCameraFocus.copy(state.focus);
  applyBattleCameraTransform();
}

function placeActor(actor, q, r, y = 0.18) {
  actor.position.copy(cellPosition(q, r, y));
  actor.userData.baseY = y;
  if (actor.userData.healthBar) {
    actor.userData.healthBarAnchor ??= new THREE.Vector3();
    actor.userData.healthBarAnchor.copy(actor.position);
  }
}

function syncHealthBarValue(actor, hp, maxHp) {
  const fill = actor?.userData.healthBar?.userData.fill;
  if (!fill || !Number.isFinite(maxHp) || maxHp <= 0) return;
  fill.userData.fullScaleX ??= fill.scale.x;
  fill.userData.fullPositionX ??= fill.position.x;
  const ratio = THREE.MathUtils.clamp((hp || 0) / maxHp, 0, 1);
  fill.scale.x = fill.userData.fullScaleX * ratio;
  fill.position.x = fill.userData.fullPositionX - (1 - ratio) * 0.34;
}

function faceHeroToward(from, to, instant = false) {
  const start = cellPosition(from.q, from.r);
  const end = cellPosition(to.q, to.r);
  const dx = end.x - start.x;
  const dz = end.z - start.z;
  if (Math.hypot(dx, dz) < 0.001) return;
  const yaw = Math.atan2(dx, dz);
  hero.userData.targetFacingYaw = yaw;
  if (instant) {
    hero.rotation.y = yaw;
    hero.userData.facingYaw = yaw;
  }
}

function faceHeroTowardAudience() {
  // Face the active camera on the ground plane. Battle is nearly +Z while the
  // menu camera is offset to the right, so a fixed yaw would look sideways in
  // one of the two views.
  const dx = camera.position.x - hero.position.x;
  const dz = camera.position.z - hero.position.z;
  const yaw = Math.atan2(dx, dz);
  hero.rotation.y = yaw;
  hero.userData.facingYaw = yaw;
  hero.userData.targetFacingYaw = yaw;
}

function updateHeroFacing(delta) {
  const current = hero.rotation.y;
  const target = hero.userData.targetFacingYaw ?? 0;
  const shortest = Math.atan2(Math.sin(target - current), Math.cos(target - current));
  hero.rotation.y = current + shortest * Math.min(1, delta * 16);
  hero.userData.facingYaw = hero.rotation.y;
}

function faceActorTowardWorld(actor, target, instant = false) {
  const dx = target.x - actor.position.x;
  const dz = target.z - actor.position.z;
  if (Math.hypot(dx, dz) < 0.001) return;
  const yaw = Math.atan2(dx, dz);
  actor.userData.targetFacingYaw = yaw;
  if (instant) actor.rotation.y = yaw;
}

function updateEnemyFacings(delta) {
  enemyActors.forEach(actor => {
    if (!actor.visible) return;
    const current = actor.rotation.y;
    const target = actor.userData.targetFacingYaw ?? current;
    const shortest = Math.atan2(Math.sin(target - current), Math.cos(target - current));
    actor.rotation.y = current + shortest * Math.min(1, delta * 14);
  });
}

function keepHealthBarsFacingCamera() {
  const parentQuaternion = new THREE.Quaternion();
  const inverseParentQuaternion = new THREE.Quaternion();
  const parentScale = new THREE.Vector3();
  const desiredWorldPosition = new THREE.Vector3();
  const cameraGroundDirection = new THREE.Vector3();
  actors.forEach(actor => {
    const healthBar = actor.userData.healthBar;
    if (!healthBar) return;
    healthBar.userData.localOffset ??= healthBar.position.clone();
    actor.userData.healthBarAnchor ??= actor.position.clone();
    actor.updateWorldMatrix(true, false);
    actor.getWorldQuaternion(parentQuaternion);
    actor.getWorldScale(parentScale);

    cameraGroundDirection.copy(camera.position).sub(actor.userData.healthBarAnchor).setY(0);
    if (cameraGroundDirection.lengthSq() > 0.0001) cameraGroundDirection.normalize();
    desiredWorldPosition.copy(actor.userData.healthBarAnchor)
      .addScaledVector(cameraGroundDirection, healthBar.userData.localOffset.z * parentScale.z);
    desiredWorldPosition.y += healthBar.userData.localOffset.y * parentScale.y;
    healthBar.position.copy(actor.worldToLocal(desiredWorldPosition));

    inverseParentQuaternion.copy(parentQuaternion).invert();
    healthBar.quaternion.copy(inverseParentQuaternion).multiply(camera.quaternion);
  });
}

function simpleSurface(color, emissive = 0x000000) {
  return new THREE.MeshToonMaterial({ color, emissive, emissiveIntensity: emissive ? 0.2 : 0 });
}

function addPart(group, geometry, material, position, scale = [1, 1, 1]) {
  const part = new THREE.Mesh(geometry, material);
  part.position.set(...position);
  part.scale.set(...scale);
  part.castShadow = true;
  part.receiveShadow = true;
  group.add(part);
  return part;
}

function statusMaterial(color, opacity = 0.9) {
  return new THREE.MeshBasicMaterial({
    color, transparent: opacity < 1, opacity, depthWrite: false, toneMapped: false,
  });
}

function ensureActorStatusRig(actor, height = 1.35) {
  if (actor.userData.statusRig) return actor.userData.statusRig;
  const root = new THREE.Group();
  root.name = 'ActorStatusRig';
  root.position.y = height;

  const freeze = new THREE.Group();
  for (let index = 0; index < 3; index += 1) {
    const angle = index * Math.PI * 2 / 3;
    const crystal = new THREE.Mesh(new THREE.OctahedronGeometry(0.105, 0), statusMaterial(0x82efff));
    crystal.position.set(Math.sin(angle) * 0.36, 0.03 + (index % 2) * 0.11, Math.cos(angle) * 0.36);
    crystal.scale.set(0.62, 1.45, 0.62);
    freeze.add(crystal);
  }

  const silence = new THREE.Group();
  const silenceRing = new THREE.Mesh(
    new THREE.TorusGeometry(0.34, 0.045, 6, 18), statusMaterial(0xcc75ff, 0.86)
  );
  silenceRing.rotation.x = Math.PI * 0.5;
  silence.add(silenceRing);
  for (let index = 0; index < 3; index += 1) {
    const mote = new THREE.Mesh(new THREE.TetrahedronGeometry(0.065, 0), statusMaterial(0xf0b4ff));
    const angle = index * Math.PI * 2 / 3;
    mote.position.set(Math.sin(angle) * 0.38, 0, Math.cos(angle) * 0.38);
    silence.add(mote);
  }

  const poison = new THREE.Group();
  for (let index = 0; index < 4; index += 1) {
    const bubble = new THREE.Mesh(
      new THREE.SphereGeometry(0.055 + (index % 2) * 0.025, 7, 5), statusMaterial(0x79e858, 0.78)
    );
    const angle = index * Math.PI * 2 / 4;
    bubble.position.set(Math.sin(angle) * 0.29, -0.12 + index * 0.08, Math.cos(angle) * 0.29);
    poison.add(bubble);
  }

  const mark = new THREE.Mesh(new THREE.OctahedronGeometry(0.13, 0), statusMaterial(0xffd45f));
  mark.scale.set(0.82, 1.3, 0.82);

  const armorBreak = new THREE.Group();
  [-1, 1].forEach(side => {
    const shard = new THREE.Mesh(new THREE.ConeGeometry(0.09, 0.28, 4), statusMaterial(0xff725f));
    shard.position.set(side * 0.18, 0, 0);
    shard.rotation.z = side * 0.72;
    armorBreak.add(shard);
  });

  const shield = new THREE.Mesh(
    new THREE.TorusGeometry(0.42, 0.035, 5, 20), statusMaterial(0x72dfff, 0.72)
  );
  shield.rotation.x = Math.PI * 0.5;

  root.add(freeze, silence, poison, mark, armorBreak, shield);
  [freeze, silence, poison, mark, armorBreak, shield].forEach(node => { node.visible = false; });
  actor.add(root);
  actor.userData.statusRig = { root, freeze, silence, poison, mark, armorBreak, shield };
  return actor.userData.statusRig;
}

function updateStatusRig(rig, time) {
  if (!rig) return;
  rig.freeze.rotation.y = time * 1.8;
  rig.freeze.children.forEach((crystal, index) => {
    crystal.position.y = 0.03 + (index % 2) * 0.11 + Math.sin(time * 4.2 + index) * 0.035;
    crystal.rotation.y = -time * 2.2 - index;
  });
  rig.silence.rotation.y = -time * 1.65;
  rig.silence.scale.setScalar(0.94 + Math.sin(time * 4.4) * 0.08);
  rig.poison.children.forEach((bubble, index) => {
    bubble.position.y = -0.12 + index * 0.08 + ((time * 0.38 + index * 0.19) % 0.42);
    bubble.scale.setScalar(0.82 + Math.sin(time * 5 + index) * 0.18);
  });
  rig.mark.rotation.y = time * 2.4;
  rig.mark.position.y = Math.sin(time * 4.8) * 0.06;
  rig.armorBreak.rotation.y = Math.sin(time * 3.2) * 0.25;
  rig.shield.rotation.z = time * 1.15;
  rig.shield.scale.setScalar(0.95 + Math.sin(time * 3.8) * 0.07);
}

function syncActorStatuses(time) {
  const heroRig = ensureActorStatusRig(hero, 1.82);
  heroRig.freeze.visible = false;
  heroRig.silence.visible = appMode === 'battle' && (level.state.hero.silencedTurns || 0) > 0;
  heroRig.poison.visible = appMode === 'battle' && (level.state.doomPoisonTurns || 0) > 0;
  heroRig.mark.visible = false;
  heroRig.armorBreak.visible = false;
  heroRig.shield.visible = false;
  updateStatusRig(heroRig, time);

  enemyActors.forEach((actor, id) => {
    const rig = actor.userData.statusRig;
    const enemy = level.state.enemies.find(entry => entry.id === id);
    const visible = appMode === 'battle' && Boolean(enemy) && !actor.userData.dying;
    if (!rig) return;
    rig.freeze.visible = visible && ((enemy.frozenTurns || 0) > 0 || level.state.timeStopTurns > 0);
    rig.silence.visible = visible && (enemy.silencedTurns || 0) > 0;
    rig.poison.visible = visible && ((enemy.poisonTurns || 0) > 0);
    rig.mark.visible = visible && Boolean(enemy.marked);
    rig.armorBreak.visible = visible && (enemy.armorBrokenTurns || 0) > 0;
    rig.shield.visible = visible && (enemy.shieldHp || 0) > 0;
    updateStatusRig(rig, time);
  });
}

function createItemActor(type) {
  const group = new THREE.Group();
  group.name = `BattleItem_${type}`;
  if (type === 'gold_bag') {
    addPart(group, new THREE.SphereGeometry(0.25, 8, 6), simpleSurface(0xe6aa2f, 0x6d4108), [0, 0.3, 0], [1, 1.15, 0.84]);
    addPart(group, new THREE.TorusGeometry(0.11, 0.035, 5, 8), simpleSurface(0xffd970), [0, 0.54, 0]).rotation.x = Math.PI / 2;
  } else if (type === 'shield') {
    addPart(group, new THREE.CylinderGeometry(0.3, 0.24, 0.09, 6), simpleSurface(0x5daee8, 0x164d78), [0, 0.32, 0]).rotation.x = Math.PI / 2;
    addPart(group, new THREE.BoxGeometry(0.08, 0.35, 0.08), simpleSurface(0xd7f4ff), [0, 0.33, 0.08]);
  } else {
    const big = type === 'health_potion_big';
    addPart(group, new THREE.CylinderGeometry(big ? 0.22 : 0.17, big ? 0.25 : 0.2, big ? 0.43 : 0.34, 7), simpleSurface(0xd94c58, 0x64121d), [0, big ? 0.32 : 0.27, 0]);
    addPart(group, new THREE.CylinderGeometry(0.1, 0.12, 0.13, 6), simpleSurface(0xf0dfb5), [0, big ? 0.58 : 0.49, 0]);
  }
  return group;
}

function effectColor(value, fallback = 0x79f1cf) {
  try { return new THREE.Color(value || fallback); } catch (_) { return new THREE.Color(fallback); }
}

function addBattleEffect(object, duration, update, onComplete = null) {
  effectGroup.add(object);
  battleEffects.push({ object, duration: Math.max(0.2, duration || 0.65), elapsed: 0, update, onComplete });
}

function trackingDartImpactFeedback(position, incomingDirection, impact = {}, heldActor = null, labelPosition = position) {
  const root = new THREE.Group();
  root.name = 'ApprovedTrackingDartImpact';
  root.position.copy(position);
  const color = impact.kind === 'heal' ? 0x6effc6 : impact.kind === 'item' ? 0xffdd72 : 0xffa43c;
  const flashMaterial = new THREE.MeshBasicMaterial({
    color, transparent: true, opacity: 1, depthWrite: false, depthTest: false,
    blending: THREE.AdditiveBlending, toneMapped: false,
  });
  const flash = new THREE.Mesh(new THREE.SphereGeometry(0.12, 8, 6), flashMaterial);
  flash.name = 'ApprovedTrackingDartContactFlash';
  root.add(flash);
  const light = new THREE.PointLight(color, impact.kind === 'enemy' ? 3.2 : 2.2, 2.6, 2);
  light.name = 'ApprovedTrackingDartContactLight';
  light.position.set(0, 0.08, 0.16);
  root.add(light);

  const incoming = incomingDirection.clone().setY(0).normalize();
  if (incoming.lengthSq() < 0.001) incoming.set(1, 0, 0);
  const lateral = new THREE.Vector3(-incoming.z, 0, incoming.x);
  const sparks = new THREE.Group();
  sparks.name = 'ApprovedTrackingDartDirectionalSparks';
  const sparkCount = impact.kind === 'enemy' ? 11 : 7;
  for (let index = 0; index < sparkCount; index += 1) {
    const material = new THREE.MeshBasicMaterial({
      color, transparent: true, opacity: 1, depthWrite: false, depthTest: false,
      blending: THREE.AdditiveBlending, toneMapped: false,
    });
    const spark = new THREE.Mesh(new THREE.BoxGeometry(0.025, 0.18, 0.025), material);
    spark.userData.direction = incoming.clone().multiplyScalar(-0.42 - (index % 3) * 0.09)
      .addScaledVector(lateral, (index - (sparkCount - 1) * 0.5) * 0.16)
      .add(new THREE.Vector3(0, 0.08 + (index % 4) * 0.08, 0)).normalize();
    spark.userData.speed = 0.5 + (index % 3) * 0.14;
    spark.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), spark.userData.direction);
    sparks.add(spark);
  }
  root.add(sparks);

  const label = impact.kind === 'enemy'
    ? approvedEnemyDamageSprite(impact.damage || 0)
    : combatTextSprite(impact.kind === 'heal' ? `+${impact.amount || 0}` : '自动拾取', '', impact.kind === 'heal' ? '#81ffd0' : '#ffe58a');
  label.position.copy(labelPosition).sub(position);
  label.position.y += impact.kind === 'item' ? 0.92 : 1.2;
  root.add(label);
  heldActor?.userData.playAction?.('hit', 0.46);

  addBattleEffect(root, 0.76, progress => {
    const flashPop = 1 - Math.pow(1 - Math.min(1, progress * 5), 3);
    flash.scale.setScalar(0.28 + flashPop * 0.9);
    flashMaterial.opacity = Math.max(0, 1 - progress * 4.3);
    light.intensity = Math.max(0, (impact.kind === 'enemy' ? 3.2 : 2.2) * (1 - progress * 5.4));
    sparks.children.forEach((spark, index) => {
      spark.position.copy(spark.userData.direction).multiplyScalar((1 - Math.pow(1 - progress, 3)) * spark.userData.speed);
      spark.position.y -= progress * progress * 0.12;
      spark.rotateY((index + 1) * 0.07);
      spark.material.opacity = Math.max(0, 1 - progress * 1.18);
      const scale = Math.max(0.03, 1 - progress) * (0.75 + (index % 3) * 0.11);
      spark.scale.set(scale * 0.8, scale * 1.25, scale * 0.8);
    });
    const labelPop = 1 - Math.pow(1 - Math.min(1, progress * 4.8), 3);
    label.scale.set(1.22 * labelPop, 0.61 * labelPop, 1);
    label.position.y += 0.006;
    label.material.opacity = progress < 0.72 ? 1 : Math.max(0, (1 - progress) / 0.28);
  });
}

function launchTrackingDart(from, to, duration = 0.6, color = 0xffb64c, impact = {}) {
  const launchDirection = to.clone().sub(from).setY(0);
  if (launchDirection.lengthSq() < 0.001) launchDirection.set(1, 0, 0);
  launchDirection.normalize();
  const start = from.clone().addScaledVector(launchDirection, 0.86).add(new THREE.Vector3(0, 0.28, 0));
  const targetCenter = to.clone();
  const target = impact.kind === 'heal'
    ? start.clone()
    : impact.kind === 'enemy'
      ? targetCenter.clone().addScaledVector(launchDirection, -TRACKING_DART_ENEMY_CONTACT_OFFSET)
      : targetCenter.clone();
  const dart = createTrackingDart(color);
  dart.position.copy(start);
  faceProjectileAlongScreen(dart, target.clone().sub(start), camera);
  dart.scale.setScalar(0.94);
  const rotor = dart.userData.rotor;
  const trailMaterial = dart.userData.trailMaterial;
  const heldActor = impact.kind === 'enemy'
    ? enemyActors.get(impact.targetId)
    : impact.kind === 'item' ? itemActors.get(impact.targetId) : null;
  if (heldActor) heldActor.userData.projectileHoldUntil = renderTime + duration + 0.8;
  addBattleEffect(dart, duration, (progress, delta) => {
    const travel = 1 - Math.pow(1 - Math.min(1, progress / 0.8), 2);
    if (impact.kind === 'heal') {
      const oneMinus = 1 - travel;
      const outward = start.clone().add(new THREE.Vector3(1.55, 1, -0.38));
      const returnArc = start.clone().add(new THREE.Vector3(-1.15, 0.78, -0.62));
      dart.position.copy(start).multiplyScalar(oneMinus * oneMinus * oneMinus)
        .add(outward.multiplyScalar(3 * oneMinus * oneMinus * travel))
        .add(returnArc.multiplyScalar(3 * oneMinus * travel * travel))
        .add(start.clone().multiplyScalar(travel * travel * travel));
    } else {
      const midpoint = start.clone().lerp(target, 0.5);
      const lateral = new THREE.Vector3(-launchDirection.z, 0, launchDirection.x);
      const control = midpoint.addScaledVector(lateral, 0.38).add(new THREE.Vector3(0, 1.08, 0));
      const oneMinus = 1 - travel;
      dart.position.copy(start).multiplyScalar(oneMinus * oneMinus)
        .add(control.multiplyScalar(2 * oneMinus * travel))
        .add(target.clone().multiplyScalar(travel * travel));
    }
    rotor.rotation.z += delta * 8.5;
    dart.scale.setScalar(0.94 + Math.sin(travel * Math.PI) * 0.08);
    const fade = progress < 0.85 ? 1 : Math.max(0, (1 - progress) / 0.15);
    trailMaterial.opacity = 0.72 * Math.min(1, travel * 6) * fade;
  }, () => {
    const labelPosition = impact.kind === 'enemy' ? targetCenter : target;
    trackingDartImpactFeedback(target, target.clone().sub(start), impact, heldActor, labelPosition);
    if (impact.kind === 'enemy' && impact.killed && heldActor) {
      heldActor.userData.projectileHoldUntil = 0;
      heldActor.userData.dying = {
        startedAt: renderTime + 0.12,
        duration: 0.55,
        baseScale: heldActor.scale.clone(),
        baseRotationZ: heldActor.rotation.z,
      };
    } else if (impact.kind === 'item' && heldActor) {
      heldActor.userData.projectileHoldUntil = 0;
      itemActors.delete(impact.targetId);
      scene.remove(heldActor);
    }
  });
  return dart;
}

function previewScarecrowModel(position) {
  const preview = createScarecrow();
  preview.name = 'ScarecrowModelPreview';
  preview.position.copy(position);
  preview.userData.animate?.(renderTime);
  preview.userData.playAction?.('spawn', 0.62);
  addBattleEffect(preview, 2.8, () => preview.userData.animate?.(renderTime));
  return preview;
}

function combatTextSprite(primary, secondary = '', color = '#fff0a8') {
  const textCanvas = typeof wx.createOffscreenCanvas === 'function'
    ? wx.createOffscreenCanvas({ type: '2d', width: 256, height: 128 })
    : wx.createCanvas();
  textCanvas.width = 256;
  textCanvas.height = 128;
  const context = textCanvas.getContext('2d');
  context.clearRect(0, 0, 256, 128);
  context.textAlign = 'center';
  context.textBaseline = 'middle';
  context.lineJoin = 'round';
  context.lineWidth = 12;
  context.strokeStyle = 'rgba(5, 13, 18, .92)';
  context.font = '900 62px sans-serif';
  context.strokeText(String(primary), 128, secondary ? 52 : 64);
  context.fillStyle = color;
  context.fillText(String(primary), 128, secondary ? 52 : 64);
  if (secondary) {
    context.lineWidth = 7;
    context.font = '900 25px sans-serif';
    context.strokeText(String(secondary), 128, 99);
    context.fillStyle = '#fff4d3';
    context.fillText(String(secondary), 128, 99);
  }
  const texture = new THREE.CanvasTexture(textCanvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.minFilter = THREE.LinearFilter;
  texture.magFilter = THREE.LinearFilter;
  texture.generateMipmaps = false;
  const material = new THREE.SpriteMaterial({ map: texture, transparent: true, depthTest: false, toneMapped: false });
  const sprite = new THREE.Sprite(material);
  sprite.renderOrder = 40;
  sprite.scale.set(1.55, 0.78, 1);
  return sprite;
}

function approvedEnemyDamageSprite(value) {
  const textCanvas = typeof wx.createOffscreenCanvas === 'function'
    ? wx.createOffscreenCanvas({ type: '2d', width: 384, height: 192 })
    : wx.createCanvas();
  textCanvas.width = 384;
  textCanvas.height = 192;
  const context = textCanvas.getContext('2d');
  context.clearRect(0, 0, 384, 192);
  context.textAlign = 'center';
  context.textBaseline = 'middle';
  context.font = '900 98px sans-serif';
  context.shadowColor = 'rgba(67, 27, 10, .55)';
  context.shadowBlur = 10;
  context.shadowOffsetY = 5;
  const gradient = context.createLinearGradient(0, 38, 0, 144);
  gradient.addColorStop(0, '#fff1a8');
  gradient.addColorStop(0.45, '#ffc85b');
  gradient.addColorStop(1, '#ed7c2e');
  context.fillStyle = gradient;
  context.fillText(`-${Math.max(0, Math.round(value || 0))}`, 192, 88);

  const texture = new THREE.CanvasTexture(textCanvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.minFilter = THREE.LinearFilter;
  texture.magFilter = THREE.LinearFilter;
  texture.generateMipmaps = false;
  const material = new THREE.SpriteMaterial({
    map: texture,
    transparent: true,
    depthTest: false,
    depthWrite: false,
    toneMapped: false,
  });
  const sprite = new THREE.Sprite(material);
  sprite.name = 'ApprovedEnemyDamageNumber';
  sprite.center.set(0.5, 0.3);
  sprite.renderOrder = 55;
  return sprite;
}

function impactBurst(position, color, strong = false) {
  const root = new THREE.Group();
  root.position.copy(position);
  const material = new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 1, toneMapped: false });
  const count = strong ? 8 : 6;
  for (let index = 0; index < count; index += 1) {
    const angle = index / count * Math.PI * 2;
    const shard = new THREE.Mesh(new THREE.OctahedronGeometry(strong ? 0.085 : 0.06, 0), material.clone());
    shard.userData.direction = new THREE.Vector3(Math.sin(angle), 0.35 + (index % 2) * 0.2, Math.cos(angle));
    root.add(shard);
  }
  addBattleEffect(root, strong ? 0.48 : 0.38, progress => {
    root.children.forEach((shard, index) => {
      shard.position.copy(shard.userData.direction).multiplyScalar(progress * (strong ? 0.85 : 0.6));
      shard.rotation.x = progress * 4 + index;
      shard.rotation.y = progress * 5;
      shard.material.opacity = 1 - progress;
      shard.scale.setScalar(1 + progress * 0.8);
    });
  });
}

function radialParticles(position, color, count = 9, duration = 0.72, upward = true) {
  const root = new THREE.Group();
  root.position.copy(position);
  for (let index = 0; index < count; index += 1) {
    const angle = index / count * Math.PI * 2;
    const material = new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.95, toneMapped: false });
    const particle = new THREE.Mesh(new THREE.OctahedronGeometry(0.045 + (index % 3) * 0.012, 0), material);
    particle.userData.direction = new THREE.Vector3(
      Math.sin(angle) * (0.52 + (index % 2) * 0.18),
      upward ? 0.65 + (index % 3) * 0.18 : 0.16 + (index % 2) * 0.08,
      Math.cos(angle) * (0.52 + ((index + 1) % 2) * 0.18)
    );
    root.add(particle);
  }
  addBattleEffect(root, duration, progress => {
    root.children.forEach((particle, index) => {
      particle.position.copy(particle.userData.direction).multiplyScalar(progress);
      if (upward) particle.position.y -= progress * progress * 0.28;
      particle.rotation.x = progress * 5 + index;
      particle.rotation.y = progress * 6;
      particle.material.opacity = Math.max(0, 1 - progress);
      particle.scale.setScalar(1 + Math.sin(progress * Math.PI) * 0.65);
    });
  });
}

function landingPulse(q, r, combo = 1) {
  const root = new THREE.Group();
  root.position.copy(cellPosition(q, r, 0.25));
  const color = combo >= 3 ? 0xffc75d : 0xa0f0dc;
  const ring = new THREE.Mesh(
    new THREE.TorusGeometry(0.27, 0.045, 6, 24),
    new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.8, depthWrite: false, toneMapped: false })
  );
  ring.rotation.x = Math.PI * 0.5;
  root.add(ring);
  addBattleEffect(root, 0.4, progress => {
    ring.scale.setScalar(1 + progress * (combo >= 3 ? 3.6 : 2.5));
    ring.material.opacity = Math.max(0, 0.8 - progress * 0.8);
  });
  radialParticles(cellPosition(q, r, 0.24), color, combo >= 3 ? 10 : 7, 0.46, false);
}

const DEATH_COLORS = {
  slime: 0x83e34b, jellyfish: 0x70d9f3, iron_turtle: 0x9aaba8,
  vortex_eel: 0x557be6, hermit_crab: 0xdd8a45, ghost_shark: 0x8299c4,
  archerfish: 0xe3b952, electric_ray: 0x9b78db, abyss_kraken: 0x8d4bbb,
};

function beginEnemyDeath(event) {
  const actor = enemyActors.get(event.enemyId);
  if (actor && !actor.userData.dying) {
    actor.userData.dying = {
      startedAt: renderTime,
      duration: event.duration || 0.7,
      baseScale: actor.scale.clone(),
      baseRotationZ: actor.rotation.z,
    };
    if (actor.userData.healthBar) actor.userData.healthBar.visible = false;
  }
  if (isBattleVfxApproved('enemy_death')) {
    const color = DEATH_COLORS[event.enemyType] || 0xe07070;
    radialParticles(cellPosition(event.q, event.r, 0.62), color, event.enemyType === 'abyss_kraken' ? 18 : 11, event.duration || 0.7, true);
    const puff = new THREE.Mesh(
      new THREE.IcosahedronGeometry(0.3, 1),
      new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.42, wireframe: true, depthWrite: false, toneMapped: false })
    );
    puff.position.copy(cellPosition(event.q, event.r, 0.62));
    addBattleEffect(puff, event.duration || 0.7, progress => {
      puff.scale.setScalar(0.65 + progress * 2.6);
      puff.rotation.x += 0.05;
      puff.rotation.y += 0.08;
      puff.material.opacity = Math.max(0, 0.42 - progress * 0.42);
    });
  }
  audio.playSfx('enemy_death');
}

function beamBetween(fromCell, toCell, color, radius = 0.035) {
  const from = cellPosition(fromCell.q, fromCell.r, 0.7);
  const to = cellPosition(toCell.q, toCell.r, 0.7);
  const direction = to.clone().sub(from);
  const material = new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.9, toneMapped: false });
  const beam = new THREE.Mesh(new THREE.CylinderGeometry(radius, radius, direction.length(), 6), material);
  beam.position.copy(from).add(to).multiplyScalar(0.5);
  beam.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), direction.normalize());
  return beam;
}

function spawnPresentationEvent(event) {
  if (event.type === 'announcement') {
    level.state.announcement = event;
    announcementTime = Math.max(announcementTime, event.duration || 1.2);
    return;
  }
  if (event.type === 'combo_reward') {
    const approvalIds = {
      3: 'scarecrow_reward',
      4: 'hex_blast',
      5: 'life_drain',
      6: 'time_stop',
      7: 'meteor_aoe',
      8: 'absolute_reflect',
    };
    const actionByCombo = {
      3: ['cast', 0.62],
      4: ['hex_blast_cast', 0.9],
      5: ['life_drain_cast', 1.08],
      6: ['time_stop_cast', 1.05],
      7: ['meteor_cast', 1.78],
      8: ['absolute_reflect_cast', 1.1],
    };
    const approvalId = approvalIds[event.threshold];
    if (!approvalId || !isBattleVfxApproved(approvalId)) return;
    const [actionName, duration] = actionByCombo[event.threshold] || ['cast', 0.64];
    hero.userData.playAction?.(actionName, duration);
    if (event.threshold >= 4) comboRewardDirector.play(event, level.state);
    return;
  }
  if (event.type === 'absolute_reflect_turn') {
    comboRewardDirector.handleEvent(event);
    return;
  }
  if (event.type === 'absolute_reflect_hit') {
    comboRewardDirector.handleEvent(event);
    const actor = enemyActors.get(event.enemyId);
    actor?.userData.playAction?.('hit', 0.46);
    if (actor && (event.damage || 0) > 0) {
      const position = actor.position.clone().add(new THREE.Vector3(0, 1.42, 0));
      const sprite = approvedEnemyDamageSprite(event.damage);
      sprite.position.copy(position);
      addBattleEffect(sprite, 0.72, progress => {
        const pop = 0.62 + Math.sin(Math.min(1, progress * 2.4) * Math.PI * 0.5) * 0.58;
        sprite.scale.set(1.45 * pop, 0.725 * pop, 1);
        sprite.position.y = position.y + progress * 0.48;
        sprite.material.opacity = progress < 0.64 ? 1 : (1 - progress) / 0.36;
      });
    }
    return;
  }
  const color = effectColor(event.color, event.type === 'hero_hit' ? 0xff5d62 : 0x79f1cf);
  const heroCastTypes = new Set(['hex_rays', 'doomsday', 'rebirth', 'electric_discharge', 'shield']);
  const projectileFromHero = event.type === 'projectile' && event.from
    && event.from.q === level.state.hero.q && event.from.r === level.state.hero.r;
  if (heroCastTypes.has(event.type) || projectileFromHero) {
    hero.userData.playAction?.('cast', event.duration ? Math.min(0.8, Math.max(0.56, event.duration)) : 0.64);
  }
  if (event.type === 'death') {
    beginEnemyDeath(event);
    return;
  }
  if (event.type === 'pickup') {
    const pickupColors = {
      health_potion: 0x66f29a, health_potion_big: 0x75ffbd,
      gold_bag: 0xffd45f, shield: 0x73dfff,
      lucky_wheel: 0xffdf69, doom_wheel: 0xc985ff,
    };
    const pickupColor = pickupColors[event.itemType] || 0x8cf2db;
    if (event.itemType === 'shield') {
      shieldVisualActive = true;
      shieldBreakAt = 0;
    }
    const sprite = combatTextSprite(event.label || '拾取道具', '', `#${pickupColor.toString(16).padStart(6, '0')}`);
    const position = cellPosition(event.q, event.r, 1.45);
    sprite.position.copy(position);
    const startY = position.y;
    addBattleEffect(sprite, event.duration || 0.8, progress => {
      sprite.position.y = startY + progress * 0.82;
      const pop = 0.78 + Math.sin(Math.min(1, progress * 2.2) * Math.PI * 0.5) * 0.34;
      sprite.scale.set(1.7 * pop, 0.85 * pop, 1);
      sprite.material.opacity = progress < 0.64 ? 1 : (1 - progress) / 0.36;
    });
    if (isBattleVfxApproved('pickup_particles')) {
      radialParticles(cellPosition(event.q, event.r, 0.55), pickupColor, event.itemType === 'gold_bag' ? 11 : 9, event.duration || 0.8, true);
    }
    return;
  }
  if (event.type === 'shield') {
    shieldVisualActive = true;
    shieldBreakAt = 0;
    if (isBattleVfxApproved('shield_particles')) {
      radialParticles(cellPosition(event.q, event.r, 0.72), 0x72dfff, 11, event.duration || 0.6, true);
    }
  }
  if (event.type === 'shield_hit' || event.type === 'shield_break') {
    const q = event.q ?? level.state.hero.q;
    const r = event.r ?? level.state.hero.r;
    const isBreak = event.type === 'shield_break';
    const heroStillProtected = Boolean(level.state.oneHitShield || level.state.hero.shield > 0 || level.state.drainShield > 0);
    if (event.target === 'hero' && isBreak && !heroStillProtected) shieldBreakAt = renderTime + 0.28;
    const sprite = combatTextSprite(
      isBreak ? '护盾破裂' : `护盾 -${event.damage || 0}`,
      '', isBreak ? '#ccefff' : '#73dfff'
    );
    const position = cellPosition(q, r, event.target === 'hero' ? 1.72 : 1.38);
    const laneOffset = reserveCombatTextOffset(event, q, r);
    position.x += laneOffset.x;
    position.y += laneOffset.y;
    sprite.position.copy(position);
    const startY = position.y;
    addBattleEffect(sprite, isBreak ? 0.78 : 0.58, progress => {
      sprite.position.y = startY + progress * 0.58;
      const pop = 0.78 + Math.sin(Math.min(1, progress * 2.2) * Math.PI * 0.5) * 0.3;
      sprite.scale.set(1.42 * pop, 0.71 * pop, 1);
      sprite.material.opacity = progress < 0.58 ? 1 : (1 - progress) / 0.42;
    });
    if (isBattleVfxApproved('shield_particles')) {
      radialParticles(
        cellPosition(q, r, event.target === 'hero' ? 0.9 : 0.72),
        isBreak ? 0xc7f4ff : 0x65d7ff, isBreak ? 14 : 8, event.duration || 0.6, true
      );
    }
    return;
  }
  if (event.type === 'combo_burst') {
    if (!isBattleVfxApproved('combo_burst')) return;
    vfxDirector.comboBurst({
      position: cellPosition(event.q, event.r, 0.22),
      camera,
      combo: event.threshold || 3,
    });
    return;
  }
  if (event.type === 'quake') {
    if (!isBattleVfxApproved('quake')) return;
    vfxDirector.quake({ position: cellPosition(event.q, event.r, 0.22) });
    return;
  }
  if (event.type === 'lightning' && event.from && event.to) {
    if (!isBattleVfxApproved('lightning')) return;
    vfxDirector.lightningChain({
      points: [
        cellPosition(event.from.q, event.from.r, 0.86),
        cellPosition(event.to.q, event.to.r, 0.86),
      ],
      camera,
    });
    return;
  }
  if (['frost', 'freeze', 'silence'].includes(event.type) && !(event.from && event.to)) {
    if (!isBattleVfxApproved('status_effects')) return;
    const q = event.q ?? level.state.hero.q;
    const r = event.r ?? level.state.hero.r;
    const statusColor = event.type === 'silence' ? 0xc875ff : event.type === 'freeze' ? 0x88efff : 0x65dfff;
    const ring = new THREE.Mesh(
      new THREE.TorusGeometry(0.23, 0.045, 6, 20),
      new THREE.MeshBasicMaterial({ color: statusColor, transparent: true, opacity: 0.9, depthWrite: false, toneMapped: false })
    );
    ring.rotation.x = Math.PI * 0.5;
    ring.position.copy(cellPosition(q, r, 0.3));
    addBattleEffect(ring, event.duration || 0.65, progress => {
      ring.scale.setScalar(1 + progress * (event.type === 'freeze' ? 5.2 : 3.8));
      ring.position.y += 0.006;
      ring.material.opacity = 1 - progress;
    });
    radialParticles(cellPosition(q, r, 0.68), statusColor, event.type === 'freeze' ? 12 : 8, event.duration || 0.65, true);
    return;
  }
  if (event.type === 'damage' || event.type === 'hero_hit' || event.type === 'heal' || event.type === 'crit') {
    const isHeroHit = event.type === 'hero_hit';
    const isHeal = event.type === 'heal';
    const isCrit = event.type === 'crit';
    const actor = isHeroHit ? hero : enemyActors.get(event.enemyId);
    if (!(isHeroHit && (event.damage || 0) <= 0)) {
      if (isHeroHit && isBattleVfxApproved('hero_hit_reaction')) {
        if (actor?.userData.action?.name !== 'approved_hit') actor?.userData.playAction?.('approved_hit', 0.58);
      } else actor?.userData.playAction?.('hit', isHeroHit ? 0.48 : 0.4);
    }
    const q = event.q ?? level.state.hero.q;
    const r = event.r ?? level.state.hero.r;
    const showDamageNumber = !event.suppressNumber;
    const laneOffset = showDamageNumber ? reserveCombatTextOffset(event, q, r) : { x: 0, y: 0 };
    const useApprovedDamageNumber = showDamageNumber && event.type === 'damage' && isBattleVfxApproved('enemy_damage_number');
    if (useApprovedDamageNumber) {
      const position = cellPosition(q, r, 1.42);
      position.x += 0.12 + laneOffset.x;
      position.y += laneOffset.y;
      const sprite = approvedEnemyDamageSprite(event.damage || 0);
      sprite.position.copy(position);
      addBattleEffect(sprite, 0.72, progress => {
        const popTime = Math.min(1, progress * 4.6);
        const popOffset = popTime - 1;
        const pop = 1 + 2.70158 * popOffset * popOffset * popOffset + 1.70158 * popOffset * popOffset;
        const settle = THREE.MathUtils.clamp((progress - 0.22) / 0.38, 0, 1);
        const scale = (0.56 + pop * 0.62) * (1 - settle * 0.12);
        sprite.scale.set(1.45 * scale, 0.725 * scale, 1);
        sprite.position.x = position.x + (1 - Math.pow(1 - progress, 3)) * 0.08;
        sprite.position.y = position.y + (1 - Math.pow(1 - progress, 3)) * 0.52;
        sprite.material.opacity = progress < 0.64 ? 1 : (1 - progress) / 0.36;
      });
    } else if (showDamageNumber) {
      const position = cellPosition(q, r, isHeroHit ? 1.7 : 1.35);
      position.x += laneOffset.x;
      position.y += laneOffset.y;
      const label = isCrit ? `暴击 −${event.damage || 0}` : isHeal ? (event.label || `+${event.amount || 0}`) : `-${event.damage || 0}`;
      const secondary = isCrit ? '' : event.combo > 1 ? `${event.combo} COMBO` : event.label || '';
      const sprite = combatTextSprite(label, secondary, isHeal ? '#7dffd0' : isCrit ? '#fff16e' : isHeroHit ? '#ff7d75' : '#ffc45d');
      sprite.position.copy(position);
      const startY = position.y;
      addBattleEffect(sprite, isCrit ? 0.82 : 0.68, progress => {
        sprite.position.y = startY + progress * 0.72;
        const pop = 0.82 + Math.sin(Math.min(1, progress * 2) * Math.PI * 0.5) * 0.28;
        sprite.scale.set(1.55 * pop, 0.78 * pop, 1);
        sprite.material.opacity = progress < 0.62 ? 1 : (1 - progress) / 0.38;
      });
    }
    if (!isHeal && isBattleVfxApproved('hero_melee_impact') && event.type === 'damage' && event.source === 'jump') {
      const hitPosition = cellPosition(q, r, 0.82);
      const travelDirection = hitPosition.clone().sub(hero.position).setY(0);
      vfxDirector.impact({
        position: hitPosition,
        direction: travelDirection,
        camera,
      });
    }
    return;
  }
  if (event.type === 'projectile') {
    const from = cellPosition(event.from.q, event.from.r, 0.72);
    const to = cellPosition(event.to.q, event.to.r, 0.72);
    if (event.projectileType === 'tracking_dart') {
      if (!isBattleVfxApproved('tracking_shuriken')) return;
      launchTrackingDart(from, to, event.duration, event.color || 0xffb64c, event.impact || {});
      return;
    }
    if (!isBattleVfxApproved('skill_projectiles')) return;
    const projectile = new THREE.Mesh(
      new THREE.OctahedronGeometry(0.12, 0),
      new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 1, toneMapped: false })
    );
    projectile.position.copy(from);
    addBattleEffect(projectile, event.duration, progress => {
      projectile.position.lerpVectors(from, to, progress);
      projectile.position.y += Math.sin(progress * Math.PI) * 0.75;
      projectile.rotation.x += 0.22;
      projectile.rotation.y += 0.28;
    });
    return;
  }
  if (['lightning', 'drain', 'thorns', 'slash', 'silence'].includes(event.type) && event.from && event.to) {
    if (!isBattleVfxApproved('skill_beams')) return;
    const beam = beamBetween(event.from, event.to, event.type === 'drain' ? 0xf05c95 : color, event.type === 'slash' ? 0.075 : 0.035);
    addBattleEffect(beam, event.duration, progress => {
      beam.material.opacity = Math.max(0, 1 - progress);
      beam.scale.x = beam.scale.z = 1 + Math.sin(progress * Math.PI) * 2;
    });
    return;
  }
  if (event.type === 'hex_rays') {
    if (!isBattleVfxApproved('hex_rays')) return;
    const root = new THREE.Group();
    for (let index = 0; index < 6; index += 1) {
      const angle = index * Math.PI / 3;
      const from = { q: event.q, r: event.r };
      const center = cellPosition(from.q, from.r, 0.5);
      const endpoint = center.clone().add(new THREE.Vector3(Math.sin(angle) * 7, 0, Math.cos(angle) * 7));
      const direction = endpoint.clone().sub(center);
      const ray = new THREE.Mesh(
        new THREE.CylinderGeometry(0.045, 0.045, direction.length(), 6),
        new THREE.MeshBasicMaterial({ color: 0x60dfff, transparent: true, opacity: 0.9, toneMapped: false })
      );
      ray.position.copy(center).add(endpoint).multiplyScalar(0.5);
      ray.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), direction.normalize());
      root.add(ray);
    }
    addBattleEffect(root, event.duration, progress => { root.children.forEach(ray => { ray.material.opacity = 1 - progress; }); });
    return;
  }
  if (event.type === 'meteor') {
    if (!isBattleVfxApproved('meteor')) return;
    const meteor = new THREE.Mesh(
      new THREE.IcosahedronGeometry(0.32, 0),
      new THREE.MeshBasicMaterial({ color: 0xff843e, transparent: true, opacity: 1, toneMapped: false })
    );
    const target = cellPosition(event.q, event.r, 0.28);
    meteor.position.copy(target).add(new THREE.Vector3(1.2, 6, -1.2));
    const start = meteor.position.clone();
    addBattleEffect(meteor, event.duration, progress => {
      meteor.position.lerpVectors(start, target, Math.min(1, progress * 1.3));
      meteor.scale.setScalar(1 + Math.sin(progress * Math.PI) * 0.7);
      meteor.material.opacity = progress > 0.8 ? (1 - progress) * 5 : 1;
    });
    return;
  }
  const q = event.q ?? event.to?.q ?? level.state.hero.q;
  const r = event.r ?? event.to?.r ?? level.state.hero.r;
  if (!isBattleVfxApproved('skill_rings')) return;
  const major = ['combo_burst', 'doomsday', 'rebirth', 'quake', 'electric_discharge'].includes(event.type);
  const ring = new THREE.Mesh(
    new THREE.TorusGeometry(major ? 0.34 : 0.2, major ? 0.075 : 0.04, 6, 20),
    new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.95, toneMapped: false })
  );
  ring.rotation.x = Math.PI / 2;
  ring.position.copy(cellPosition(q, r, 0.24));
  addBattleEffect(ring, event.duration, progress => {
    const scale = 1 + progress * (major ? 9 : 4);
    ring.scale.setScalar(scale);
    ring.material.opacity = Math.max(0, 1 - progress);
    ring.position.y += major ? 0.006 : 0.002;
  });
}

function consumePresentationEvents() {
  level.consumePresentationEvents?.().forEach(spawnPresentationEvent);
}

function updateBattleEffects(delta) {
  if (announcementTime > 0) {
    announcementTime -= delta;
    if (announcementTime <= 0) level.state.announcement = null;
  }
  for (let index = battleEffects.length - 1; index >= 0; index -= 1) {
    const effect = battleEffects[index];
    effect.elapsed += delta;
    const progress = Math.min(1, effect.elapsed / effect.duration);
    effect.update?.(progress, delta);
    if (progress < 1) continue;
    effect.onComplete?.();
    effectGroup.remove(effect.object);
    effect.object.traverse?.(child => {
      child.geometry?.dispose?.();
      if (Array.isArray(child.material)) child.material.forEach(material => { material.map?.dispose?.(); material.dispose?.(); });
      else { child.material?.map?.dispose?.(); child.material?.dispose?.(); }
    });
    battleEffects.splice(index, 1);
  }
}

function clearBattleEffects() {
  while (battleEffects.length) {
    const effect = battleEffects.pop();
    effectGroup.remove(effect.object);
  }
  comboRewardDirector.clear();
  announcementTime = 0;
}

placeActor(hero, level.state.hero.q, level.state.hero.r);

function syncEnemyActors(preserveMissing = false) {
  const livingIds = new Set(level.state.enemies.map(enemy => enemy.id));
  enemyActors.forEach((actor, id) => {
    if (livingIds.has(id)) return;
    if (preserveMissing || actor.userData.dying || (actor.userData.projectileHoldUntil || 0) > renderTime) return;
    enemyActors.delete(id);
    const index = actors.indexOf(actor);
    if (index >= 0) actors.splice(index, 1);
    scene.remove(actor);
  });

  level.state.enemies.forEach(enemy => {
    let actor = enemyActors.get(enemy.id);
    const isNewActor = !actor;
    if (!actor) {
      actor = createChapterOneEnemy(enemy.type);
      actor.scale.multiplyScalar(BATTLE_UNIT_SCALE);
      actor.userData.enemyId = enemy.id;
      actor.userData.baseY = 0.18;
      ensureActorStatusRig(actor, enemy.type === 'abyss_kraken' ? 2.28 : 1.32);
      enemyActors.set(enemy.id, actor);
      actors.push(actor);
      scene.add(actor);
    }
    if (actor.userData.dying) {
      const death = actor.userData.dying;
      actor.userData.dying = null;
      actor.scale.copy(death.baseScale);
      actor.rotation.z = death.baseRotationZ;
      if (actor.userData.healthBar) actor.userData.healthBar.visible = true;
    }
    placeActor(actor, enemy.q, enemy.r, actor.userData.baseY);
    syncHealthBarValue(actor, enemy.hp, enemy.maxHp);
    // Establish a spawned enemy's initial pose once. Existing enemies keep
    // their locked facing while the player moves and only turn when their own
    // action is presented in beginEnemyAnimation().
    if (isNewActor) {
      const target = level.state.scarecrow || level.state.hero;
      faceActorTowardWorld(actor, cellPosition(target.q, target.r), true);
    }
    actor.visible = appMode === 'battle';
  });

  const liveObstacleIds = new Set((level.state.obstacles || []).map(obstacle => obstacle.id));
  obstacleActors.forEach((actor, id) => {
    if (liveObstacleIds.has(id)) return;
    obstacleActors.delete(id);
    const index = actors.indexOf(actor);
    if (index >= 0) actors.splice(index, 1);
    scene.remove(actor);
  });
  (level.state.obstacles || []).forEach(obstacle => {
    let actor = obstacleActors.get(obstacle.id);
    if (!actor) {
      actor = createBattleObstacle(obstacle.type);
      actor.userData.baseY = 0.16;
      obstacleActors.set(obstacle.id, actor);
      actors.push(actor); scene.add(actor);
    }
    placeActor(actor, obstacle.q, obstacle.r, actor.userData.baseY);
    actor.visible = appMode === 'battle';
  });

  const liveItemIds = new Set(level.state.items.map(item => item.id));
  itemActors.forEach((actor, id) => {
    if (liveItemIds.has(id)) return;
    if ((actor.userData.projectileHoldUntil || 0) > renderTime) return;
    itemActors.delete(id);
    scene.remove(actor);
  });
  level.state.items.forEach(item => {
    let actor = itemActors.get(item.id);
    if (!actor) {
      actor = createItemActor(item.type);
      itemActors.set(item.id, actor);
      scene.add(actor);
    }
    placeActor(actor, item.q, item.r, 0.17);
    actor.visible = appMode === 'battle';
  });

  if (level.state.scarecrow) {
    const shouldPlaySpawn = !scarecrowActor || !scarecrowActor.visible;
    if (!scarecrowActor) {
      scarecrowActor = createScarecrow();
      scarecrowActor.userData.baseY = 0.17;
      scarecrowActor.visible = false;
      actors.push(scarecrowActor);
      scene.add(scarecrowActor);
    }
    placeActor(scarecrowActor, level.state.scarecrow.q, level.state.scarecrow.r, 0.17);
    syncHealthBarValue(scarecrowActor, level.state.scarecrow.hp, level.state.scarecrow.maxHp);
    scarecrowActor.visible = appMode === 'battle';
    if (shouldPlaySpawn && scarecrowActor.visible) scarecrowActor.userData.playAction?.('spawn', 0.62);
  } else if (scarecrowActor) scarecrowActor.visible = false;
}

function updateDyingActors(time) {
  enemyActors.forEach((actor, id) => {
    const death = actor.userData.dying;
    if (!death) return;
    const progress = Math.min(1, Math.max(0, (time - death.startedAt) / death.duration));
    const lift = Math.sin(progress * Math.PI) * 0.28;
    actor.scale.copy(death.baseScale).multiplyScalar(Math.max(0.12, 1 - progress * 0.82));
    actor.position.y = actor.userData.baseY + lift;
    actor.rotation.z = death.baseRotationZ + progress * 1.15;
    if (progress < 1) return;
    enemyActors.delete(id);
    const index = actors.indexOf(actor);
    if (index >= 0) actors.splice(index, 1);
    scene.remove(actor);
  });
}

const routeGroup = new THREE.Group();
routeGroup.name = 'PlannedComboRoute';
scene.add(routeGroup);
const threatGroup = new THREE.Group();
threatGroup.name = 'EnemyThreatIndicators';
scene.add(threatGroup);
const routeMaterial = new THREE.MeshBasicMaterial({
  color: new THREE.Color(0x42f1df).multiplyScalar(1.9),
  toneMapped: false,
});
const routeConfirmMaterial = new THREE.MeshBasicMaterial({
  color: new THREE.Color(0xffd86a).multiplyScalar(1.65),
  transparent: true,
  opacity: 0.92,
  side: THREE.DoubleSide,
  toneMapped: false,
});

function clearRoute() {
  while (routeGroup.children.length) {
    const child = routeGroup.children[routeGroup.children.length - 1];
    routeGroup.remove(child);
    child.geometry?.dispose();
  }
}

function clearThreatIndicators() {
  while (threatGroup.children.length) {
    const child = threatGroup.children[threatGroup.children.length - 1];
    threatGroup.remove(child);
    child.traverse?.(node => {
      node.geometry?.dispose?.();
      node.material?.map?.dispose?.();
      node.material?.dispose?.();
    });
  }
}

function addThreatCylinder(start, end, color, opacity, radius, renderOrder = 16) {
  const direction = end.clone().sub(start);
  if (direction.lengthSq() < 0.001) return null;
  const material = new THREE.MeshBasicMaterial({
    color, transparent: true, opacity, depthWrite: false, toneMapped: false,
  });
  const segment = new THREE.Mesh(
    new THREE.CylinderGeometry(radius, radius, direction.length(), 5), material
  );
  segment.position.copy(start).add(end).multiplyScalar(0.5);
  segment.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), direction.normalize());
  segment.renderOrder = renderOrder;
  segment.userData.threatPulse = true;
  segment.userData.baseOpacity = opacity;
  threatGroup.add(segment);
  return segment;
}

function addThreatStroke(start, end, color, opacity, radius, outlineScale = 1.9, outlineOpacity = null) {
  addThreatCylinder(
    start, end, 0x071018,
    outlineOpacity ?? Math.min(0.88, opacity * 0.86),
    radius * outlineScale, 15
  );
  addThreatCylinder(start, end, color, opacity, radius, 16);
}

function addThreatLink(link) {
  const style = threatLineStyle(link);
  const start = cellPosition(link.from.q, link.from.r, 0.56);
  const end = cellPosition(link.to.q, link.to.r, 0.56);
  const fullDirection = end.clone().sub(start);
  const fullLength = fullDirection.length();
  if (fullLength < 0.2) return;
  const unit = fullDirection.clone().normalize();
  start.addScaledVector(unit, 0.34);
  end.addScaledVector(unit, -0.34);
  const usableLength = start.distanceTo(end);

  if (style.dashed) {
    const count = Math.max(1, Math.ceil(usableLength / (style.dashLength + style.gapLength)));
    for (let index = 0; index < count; index += 1) {
      const distanceStart = index * (style.dashLength + style.gapLength);
      if (distanceStart >= usableLength) break;
      const distanceEnd = Math.min(usableLength, distanceStart + style.dashLength);
      addThreatStroke(
        start.clone().addScaledVector(unit, distanceStart),
        start.clone().addScaledVector(unit, distanceEnd),
        style.color, style.opacity, style.radius,
        style.outlineScale, style.outlineOpacity
      );
    }
  } else {
    addThreatStroke(
      start, end, style.color, style.opacity, style.radius,
      style.outlineScale, style.outlineOpacity
    );
  }

  const arrowPosition = start.clone().lerp(end, style.arrowAt);
  arrowPosition.y += 0.03;
  [
    {
      radius: style.arrowRadius * style.arrowOutlineScale, height: style.arrowHeight * 1.13,
      arrowColor: 0x071018, arrowOpacity: 0.76, order: 16,
    },
    {
      radius: style.arrowRadius, height: style.arrowHeight, arrowColor: style.color,
      arrowOpacity: 0.94, order: 17,
    },
  ].forEach(style => {
    const arrow = new THREE.Mesh(
      new THREE.ConeGeometry(style.radius, style.height, 3),
      new THREE.MeshBasicMaterial({
        color: style.arrowColor, transparent: true, opacity: style.arrowOpacity,
        depthWrite: false, toneMapped: false,
      })
    );
    arrow.position.copy(arrowPosition);
    arrow.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), unit);
    arrow.renderOrder = style.order;
    arrow.userData.threatPulse = true;
    arrow.userData.baseOpacity = style.arrowOpacity;
    threatGroup.add(arrow);
  });

  if (!link.pending && link.damage != null) {
    const label = combatTextSprite(`-${link.damage}`, '', '#ff7f73');
    label.position.copy(start).lerp(end, 0.5);
    label.position.y = 0.92;
    label.scale.set(0.98, 0.49, 1);
    label.userData.threatPulse = true;
    label.userData.baseOpacity = 0.92;
    threatGroup.add(label);
  }
}

function rebuildThreatIndicators() {
  clearThreatIndicators();
  const links = buildThreatLinks(level.state);
  links.forEach(addThreatLink);
  const heroLinks = links.filter(link => link.target === 'hero');
  if (!heroLinks.length) return;
  const target = heroLinks[0].to;
  const hasImmediate = heroLinks.some(link => !link.pending);
  [
    { inner: 0.47, outer: 0.71, color: 0x071018, opacity: 0.62, order: 14 },
    { inner: 0.53, outer: 0.66, color: hasImmediate ? 0xff3048 : 0xffd23f, opacity: 0.78, order: 15 },
  ].forEach(style => {
    const ring = new THREE.Mesh(
      new THREE.RingGeometry(style.inner, style.outer, 32),
      new THREE.MeshBasicMaterial({
        color: style.color, transparent: true, opacity: style.opacity,
        side: THREE.DoubleSide, depthWrite: false, toneMapped: false,
      })
    );
    ring.position.copy(cellPosition(target.q, target.r, 0.38));
    ring.rotation.x = -Math.PI * 0.5;
    ring.renderOrder = style.order;
    ring.userData.threatRing = true;
    ring.userData.baseOpacity = style.opacity;
    threatGroup.add(ring);
  });
}

function routeSegment(from, to) {
  const start = cellPosition(from.q, from.r, 0.4);
  const end = cellPosition(to.q, to.r, 0.4);
  const direction = end.clone().sub(start);
  const segment = new THREE.Mesh(new THREE.CylinderGeometry(0.045, 0.045, direction.length(), 5), routeMaterial);
  segment.position.copy(start).add(end).multiplyScalar(0.5);
  segment.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), direction.normalize());
  routeGroup.add(segment);

  const marker = new THREE.Mesh(new THREE.OctahedronGeometry(0.11, 0), routeMaterial);
  marker.position.copy(end);
  routeGroup.add(marker);
}

function routeConfirmMarker(cell) {
  const marker = new THREE.Mesh(new THREE.RingGeometry(0.25, 0.36, 6), routeConfirmMaterial);
  marker.position.copy(cellPosition(cell.q, cell.r, 0.43));
  marker.rotation.x = -Math.PI * 0.5;
  marker.userData.confirmMarker = true;
  routeGroup.add(marker);
}

function rebuildBoardState() {
  clearRoute();
  board.clearStates();
  board.setState(board.get(level.state.hero.q, level.state.hero.r), 'hero');
  let previous = level.state.hero;
  level.state.plan.forEach(step => {
    board.setState(board.get(step.q, step.r), 'route');
    routeSegment(previous, step);
    previous = step;
  });
  if (level.state.plan.length) routeConfirmMarker(level.state.plan[level.state.plan.length - 1]);
  if (level.state.plan.length && level.state.threatPreview.length) {
    const danger = level.state.plan[level.state.plan.length - 1];
    board.setState(board.get(danger.q, danger.r), 'target');
  }
  level.availableActions().forEach(action => {
    board.setState(board.get(action.q, action.r), action.kind === 'jump' ? 'target' : 'route');
  });
  rebuildThreatIndicators();
}

const makeHudCanvas = () => {
  if (typeof wx.createOffscreenCanvas === 'function') {
    return wx.createOffscreenCanvas({ type: '2d', width: 1, height: 1 });
  }
  return wx.createCanvas();
};
const hud = createHudOverlay(renderer, viewportWidth, viewportHeight, pixelRatio, makeHudCanvas, { safeAreaTop });

function refresh(options = {}) {
  if (level.state.tutorialJustCompleted) {
    if (!battleUi.tutorialPreview && !meta.tutorialSpawnSeen) {
      meta.tutorialSpawnSeen = true;
      saveMeta();
    }
    level.state.tutorialJustCompleted = false;
  }
  const resultKey = level.state.result ? `${level.state.result}-${level.state.stage}` : null;
  if (appMode === 'battle' && resultKey && settledResult !== resultKey) {
    settledResult = resultKey;
    audio.playSfx(level.state.result === 'lose' ? 'defeat' : 'victory');
    hero.userData.playAction?.(level.state.result === 'lose' ? 'defeat' : 'victory', level.state.result === 'lose' ? 1.1 : 1.8);
    if (level.state.result === 'win') {
      meta.highestLevel = Math.max(meta.highestLevel, Math.min(11, level.state.stage + 1));
      meta.runsAtHighest = meta.totalRuns;
      saveMeta();
    }
  }
  if (options.consumeEvents !== false) consumePresentationEvents();
  syncEnemyActors(options.consumeEvents === false);
  if (appMode === 'battle') rebuildBoardState();
  else clearRoute();
  hud.draw({
    ...level.state, mode: appMode, meta, menuState, battleUi, cameraZoom: battleZoom,
    tutorialSpotlight: buildTutorialSpotlight(), tutorialTime: renderTime,
  });
}

function settleRunRewards() {
  if (runSettled) return;
  const gain = Math.floor((level.state.gold || 0) * 1.8);
  meta.gold += gain;
  level.state.gold = 0;
  meta.highestLevel = Math.max(meta.highestLevel, Math.min(10, level.state.stage));
  meta.runsAtHighest = meta.totalRuns;
  runSettled = true;
  saveMeta();
  setMenuNotice(gain > 0 ? `本次冒险获得 ${gain} 金币` : '');
}

function enterMenu() {
  if (appMode === 'battle') settleRunRewards();
  appMode = 'menu';
  clearBattleEffects();
  vfxDirector.clear();
  applyCameraProfile('menu');
  movement = null;
  turnSequence = null;
  cameraActionShot = null;
  queuedHeroAction = null;
  shieldVisualActive = false;
  shieldBreakAt = 0;
  vfxShakeStrength = 0;
  vfxShakeDuration = 0;
  vfxShakeRemaining = 0;
  Object.assign(battleUi, {
    settingsOpen: false, guideOpen: false, skillsOpen: false,
    exitConfirmOpen: false, vfxTestOpen: false, skillChoicePreview: null, tutorialPreview: false,
  });
  board.group.visible = false;
  routeGroup.visible = false;
  threatGroup.visible = false;
  clearThreatIndicators();
  enemyActors.forEach(actor => { actor.visible = false; });
  itemActors.forEach(actor => { actor.visible = false; });
  obstacleActors.forEach(actor => { actor.visible = false; });
  if (scarecrowActor) scarecrowActor.visible = false;
  hero.scale.copy(hero.userData.menuScale);
  placeActor(hero, 0, 0, 0.18);
  faceHeroTowardAudience();
  // Release builds load only the compact menu-audio package at startup.
  // The larger battle-audio package is requested by enterBattle(), avoiding a
  // 9 MiB background download while the first screen is becoming interactive.
  audio.playBgm('menu');
  refresh();
}

function enterBattle() {
  appMode = 'battle';
  clearBattleEffects();
  vfxDirector.clear();
  menuState.notice = '';
  menuState.shopResults = [];
  meta.totalRuns += 1;
  runSettled = false;
  saveMeta();
  level = createLevelOne({
    tutorialSeen: meta.tutorialSpawnSeen,
    tutorialFlags: {
      comboTutorialSeen: meta.comboTutorialSeen,
      scarecrowTutorialSeen: meta.scarecrowTutorialSeen,
      multiHopTutorialSeen: meta.multiHopTutorialSeen,
      chainJumpTutorialSeen: meta.chainJumpTutorialSeen,
    },
    hero: getHeroStats(meta),
    critRate: getCritRate(meta),
    goldBonus: getGoldBonus(meta),
    setEffects: getSetEffects(meta),
    seenEnemyTypes: meta.seenEnemyTypes,
  });
  settledResult = null;
  movement = null;
  turnSequence = null;
  cameraActionShot = null;
  queuedHeroAction = null;
  shieldVisualActive = false;
  shieldBreakAt = 0;
  Object.assign(battleUi, {
    settingsOpen: false, guideOpen: false, guidePage: 0, skillsOpen: false, skillsPage: 0,
    exitConfirmOpen: false, vfxTestEnabled: VFX_TEST_MODE,
    vfxTestOpen: false, vfxTestLast: '', vfxTestLastId: '', skillChoicePreview: null,
    tutorialPreview: false,
  });
  const initialHeroFocus = cellPosition(level.state.hero.q, level.state.hero.r, BATTLE_CAMERA_TARGET.y);
  initialHeroFocus.y = BATTLE_CAMERA_TARGET.y;
  const cameraState = battleCameraController.reset(initialHeroFocus);
  battleZoom = cameraState.zoom;
  battleCameraFocus.copy(cameraState.focus);
  applyCameraProfile('battle');
  board.group.visible = true;
  routeGroup.visible = true;
  threatGroup.visible = true;
  hero.scale.copy(hero.userData.battleScale);
  placeActor(hero, level.state.hero.q, level.state.hero.r);
  faceHeroTowardAudience();
  audio.playBgm('battle_calm');
  refresh();
}

function replayOpeningTutorial() {
  if (!VFX_TEST_MODE || appMode !== 'battle') return;
  clearBattleEffects();
  vfxDirector.clear();
  level = createLevelOne({
    tutorialSeen: false,
    tutorialFlags: {},
    hero: getHeroStats(meta),
    critRate: getCritRate(meta),
    goldBonus: getGoldBonus(meta),
    setEffects: getSetEffects(meta),
    seenEnemyTypes: meta.seenEnemyTypes,
  });
  settledResult = null;
  movement = null;
  turnSequence = null;
  cameraActionShot = null;
  queuedHeroAction = null;
  shieldVisualActive = false;
  shieldBreakAt = 0;
  Object.assign(battleUi, {
    settingsOpen: false, guideOpen: false, guidePage: 0,
    skillsOpen: false, skillsPage: 0, exitConfirmOpen: false,
    vfxTestOpen: false, vfxTestLast: '', vfxTestLastId: '',
    skillChoicePreview: null, tutorialPreview: true,
  });
  const initialHeroFocus = cellPosition(level.state.hero.q, level.state.hero.r, BATTLE_CAMERA_TARGET.y);
  initialHeroFocus.y = BATTLE_CAMERA_TARGET.y;
  const cameraState = battleCameraController.reset(initialHeroFocus);
  battleZoom = cameraState.zoom;
  battleCameraFocus.copy(cameraState.focus);
  applyCameraProfile('battle');
  placeActor(hero, level.state.hero.q, level.state.hero.r);
  faceHeroTowardAudience();
  refresh();
}

function startHeroMovement(summary) {
  if (!summary || (summary.kind !== 'move' && summary.kind !== 'jump_step')) return;
  // Turn before take-off so the silhouette clearly reads in the travel
  // direction from the very first animation frame.
  faceHeroToward(summary.from, summary.to, true);
  if (summary.kind === 'jump_step') audio.playSfx('hero_jump');
  const segmentDuration = summary.kind === 'jump_step'
    ? Math.max(0.36, 0.48 - Math.min(summary.combo - 1, 6) * 0.018)
    : 0.34;
  hero.userData.playAction?.(
    summary.kind === 'jump_step' ? 'jump_attack' : 'move',
    summary.kind === 'jump_step' ? 0.64 : segmentDuration
  );
  queuedHeroAction = null;
  const movementPoints = [
    cellPosition(summary.from.q, summary.from.r),
    cellPosition(summary.to.q, summary.to.r),
  ];
  cameraActionShot = {
    mode: 'hero_action',
    margin: summary.kind === 'jump_step' ? 0.84 : 0.72,
  };
  movement = {
    points: movementPoints,
    elapsed: 0,
    segmentDuration,
    jumping: summary.kind === 'jump_step',
    combo: summary.combo || 0,
    item: summary.item || null,
  };
}

function beginTurnSequence(summary) {
  if (!summary) return;
  if (summary.kind === 'move' && level.state.phase === 'ENEMY_TURN') {
    startHeroMovement(summary);
    turnSequence = {
      // Lua starts the enemy wind-up as soon as a normal move commits, so the
      // 0.15s slide overlaps the 0.6s delay.
      stage: 'ENEMY_DELAY',
      remaining: 0.6,
      elapsed: 0,
      duration: 0.3,
      animations: [],
    };
  } else if (summary.kind === 'jump_start' && level.state.phase === 'PLAYER_EXECUTE') {
    // Original ConfirmJumps waits 0.15s, then resolves and animates one hop at a
    // time. No reward/result state exists until the final hop has landed.
    turnSequence = {
      stage: 'JUMP_INITIAL_DELAY',
      remaining: 0.15,
      elapsed: 0,
      duration: 0,
      animations: [],
      currentJump: null,
    };
  }
}

const raycaster = new THREE.Raycaster();
const pointer = new THREE.Vector2();
let pinchStartDistance = 0;
let pinchStartZoom = 1;
let pinchActive = false;
let suppressTap = false;

function distanceBetweenTouches(touches) {
  if (!touches || touches.length < 2) return 0;
  const first = touches[0];
  const second = touches[1];
  const dx = (second.clientX ?? second.x ?? 0) - (first.clientX ?? first.x ?? 0);
  const dy = (second.clientY ?? second.y ?? 0) - (first.clientY ?? first.y ?? 0);
  return Math.hypot(dx, dy);
}

function touchPoint(event) {
  const touch = event.changedTouches?.[0] || event.touches?.[0] || event;
  return {
    x: touch.clientX ?? touch.x ?? touch.pageX ?? 0,
    y: touch.clientY ?? touch.y ?? touch.pageY ?? 0,
  };
}

function handleTouch(event) {
  if (movement) return;
  audio.unlock();
  const point = touchPoint(event);
  const control = hud.hitTest(point.x, point.y);
  if (appMode === 'menu') {
    if (control?.startsWith('tab_')) {
      audio.playSfx('ui_click');
      menuState.tab = control.slice('tab_'.length);
      menuState.notice = '';
      menuState.selectedInventoryIndex = null;
      menuState.decomposeMode = false;
      menuState.decomposeSelectedIndices = [];
      menuState.shopRulesOpen = false;
      menuState.shopResultOpen = false;
      menuState.redeemOpen = false;
      menuState.settingsOpen = false;
      refresh();
      return;
    }
    if (control === 'settings_open') {
      menuState.settingsOpen = true; menuState.notice = ''; refresh();
    } else if (control === 'settings_close') {
      menuState.settingsOpen = false; refresh();
    } else if (control === 'bgm_minus' || control === 'bgm_plus') {
      audio.setBgmVolume(audio.state.bgmVolume + (control === 'bgm_plus' ? 0.05 : -0.05)); refresh();
    } else if (control === 'sfx_minus' || control === 'sfx_plus') {
      audio.setSfxVolume(audio.state.sfxVolume + (control === 'sfx_plus' ? 0.05 : -0.05));
      if (control === 'sfx_plus') audio.playSfx('ui_click');
      refresh();
    } else if (control === 'combo_scale' || control === 'combo_classic') {
      audio.setComboSoundStyle(control === 'combo_classic' ? 'classic' : 'scale'); audio.playSfx('ui_click'); refresh();
    } else if (control?.startsWith('track_')) {
      audio.playBgm(control.slice('track_'.length)); refresh();
    } else if (control === 'adventure_prev' || control === 'adventure_next') {
      menuState.selectedChapter = THREE.MathUtils.clamp(menuState.selectedChapter + (control === 'adventure_next' ? 1 : -1), 0, 5);
      menuState.notice = ''; refresh();
    } else if (control === 'start') {
      if (menuState.selectedChapter === 1) enterBattle();
      else { setMenuNotice(menuState.selectedChapter === 0 ? '无尽模式将在第一章复刻验收后接入' : '当前复刻范围为完整第一章'); refresh(); }
    } else if (control === 'redeem_open') {
      menuState.redeemOpen = true; menuState.redeemCode = ''; menuState.redeemStatus = '';
      menuState.redeemError = false; menuState.redeemSuccess = false; refresh(); showRedeemKeyboard();
    } else if (control === 'redeem_cancel') {
      menuState.redeemOpen = false; hideRedeemKeyboard(); refresh();
    } else if (control === 'redeem_submit') {
      if (!menuState.redeemSuccess) submitRedeem();
    } else if (control === 'shop_prev' || control === 'shop_next') {
      menuState.shopSetIndex = (menuState.shopSetIndex + (control === 'shop_next' ? 1 : -1) + SETS.length) % SETS.length;
      menuState.shopResults = []; menuState.notice = ''; refresh();
    } else if (control === 'shop_rules') {
      menuState.shopRulesOpen = true; menuState.notice = ''; refresh();
    } else if (control === 'shop_rules_close') {
      menuState.shopRulesOpen = false; refresh();
    } else if (control === 'shop_result_close') {
      menuState.shopResultOpen = false; menuState.shopResults = []; setMenuNotice(''); refresh();
    } else if (control === 'guild_adventure' || control === 'guild_endless') {
      menuState.guildTab = control === 'guild_endless' ? 'endless' : 'adventure';
      menuState.notice = ''; refresh();
    }
    else if (control === 'pull_1' || control === 'pull_3') {
      const count = control === 'pull_1' ? 1 : 3;
      const outcome = pullEquipment(meta, count);
      menuState.shopResults = outcome.results;
      menuState.shopResultOpen = outcome.ok;
      menuState.shopResultOpenedAt = outcome.ok ? Date.now() : 0;
      setMenuNotice(outcome.ok ? `获得 ${outcome.results.length} 件装备` : outcome.error);
      saveMeta();
      refresh();
    } else if (control?.startsWith('talent_')) {
      const outcome = upgradeTalent(meta, control.slice('talent_'.length));
      setMenuNotice(outcome.ok ? `天赋已升至 Lv.${outcome.level}` : outcome.error);
      saveMeta();
      refresh();
    } else if (/^inventory_\d+$/.test(control || '')) {
      const index = Number(control.slice('inventory_'.length));
      if (menuState.decomposeMode && meta.inventory[index]) {
        const selected = new Set(menuState.decomposeSelectedIndices);
        if (selected.has(index)) selected.delete(index); else selected.add(index);
        menuState.decomposeSelectedIndices = [...selected].sort((a, b) => a - b);
        setMenuNotice(`已选择 ${selected.size} 件装备`);
      } else {
        menuState.selectedInventoryIndex = meta.inventory[index] ? index : null;
        setMenuNotice(meta.inventory[index] ? '装备详情' : '');
      }
      refresh();
    } else if (control === 'inventory_prev' || control === 'inventory_next') {
      const pages = Math.max(1, Math.ceil(meta.inventory.length / 6));
      menuState.inventoryPage = THREE.MathUtils.clamp(menuState.inventoryPage + (control === 'inventory_next' ? 1 : -1), 0, pages - 1);
      menuState.selectedInventoryIndex = null;
      setMenuNotice(''); refresh();
    } else if (control === 'detail_close') {
      menuState.selectedInventoryIndex = null; setMenuNotice(''); refresh();
    } else if (control === 'bulk_toggle') {
      menuState.decomposeMode = !menuState.decomposeMode;
      menuState.decomposeSelectedIndices = [];
      menuState.selectedInventoryIndex = null;
      setMenuNotice(menuState.decomposeMode ? '选择要分解的装备，可按品阶快速选择' : '');
      refresh();
    } else if (control === 'bulk_blue' || control === 'bulk_purple') {
      const rarity = control === 'bulk_blue' ? 'blue' : 'purple';
      const selected = new Set(menuState.decomposeSelectedIndices);
      meta.inventory.forEach((item, index) => { if (item.rarity === rarity) selected.add(index); });
      menuState.decomposeSelectedIndices = [...selected].sort((a, b) => a - b);
      setMenuNotice(`已选择 ${selected.size} 件装备`); refresh();
    } else if (control === 'bulk_confirm') {
      const outcome = decomposeInventoryItems(meta, menuState.decomposeSelectedIndices);
      setMenuNotice(outcome.ok ? `批量分解 ${outcome.count} 件，获得 ${outcome.gold} 金币` : outcome.error);
      menuState.decomposeSelectedIndices = [];
      menuState.inventoryPage = Math.min(menuState.inventoryPage, Math.max(0, Math.ceil(meta.inventory.length / 6) - 1));
      saveMeta(); refresh();
    } else if (control === 'equip_selected') {
      const outcome = equipInventoryItem(meta, menuState.selectedInventoryIndex);
      setMenuNotice(outcome.ok ? '已穿戴装备' : outcome.error);
      menuState.selectedInventoryIndex = null;
      menuState.inventoryPage = Math.min(menuState.inventoryPage, Math.max(0, Math.ceil(meta.inventory.length / 6) - 1));
      saveMeta();
      refresh();
    } else if (control === 'decompose_selected') {
      const outcome = decomposeInventoryItems(meta, [menuState.selectedInventoryIndex]);
      setMenuNotice(outcome.ok ? `分解获得 ${outcome.gold} 金币` : '请先选择装备');
      menuState.selectedInventoryIndex = null;
      menuState.inventoryPage = Math.min(menuState.inventoryPage, Math.max(0, Math.ceil(meta.inventory.length / 6) - 1));
      saveMeta();
      refresh();
    } else if (control?.startsWith('slot_')) {
      const outcome = unequipSlot(meta, control.slice('slot_'.length));
      setMenuNotice(outcome.ok ? '已卸下装备' : outcome.error);
      saveMeta();
      refresh();
    }
    return;
  }
  if (control === 'wheel_close') {
    const outcome = level.dismissWheel();
    if (outcome.kind === 'extra_turn') {
      turnSequence = null;
      movement = null;
      queuedHeroAction = null;
      placeActor(hero, level.state.hero.q, level.state.hero.r);
    }
    refresh();
    return;
  }
  if (control === 'tutorial_close') {
    const outcome = level.dismissTutorial();
    const keyById = {
      combo: 'comboTutorialSeen', scarecrow: 'scarecrowTutorialSeen',
      multiHop: 'multiHopTutorialSeen', chainJump: 'chainJumpTutorialSeen',
    };
    const key = keyById[outcome.id];
    if (key) { meta[key] = true; saveMeta(); }
    refresh(); return;
  }
  if (control === 'tutorial_block') return;
  if (control === 'enemy_intro_close') {
    const outcome = level.dismissEnemyIntro();
    for (const enemyType of outcome.enemyTypes || []) meta.seenEnemyTypes[enemyType] = true;
    saveMeta(); refresh(); return;
  }
  if (control === 'battle_settings_open') {
    battleUi.settingsOpen = true; refresh(); return;
  }
  if (control === 'battle_settings_close') {
    battleUi.settingsOpen = false; refresh(); return;
  }
  if (control === 'bgm_minus' || control === 'bgm_plus') {
    audio.setBgmVolume(audio.state.bgmVolume + (control === 'bgm_plus' ? 0.05 : -0.05)); refresh(); return;
  }
  if (control === 'sfx_minus' || control === 'sfx_plus') {
    audio.setSfxVolume(audio.state.sfxVolume + (control === 'sfx_plus' ? 0.05 : -0.05));
    if (control === 'sfx_plus') audio.playSfx('ui_click');
    refresh(); return;
  }
  if (control === 'combo_scale' || control === 'combo_classic') {
    audio.setComboSoundStyle(control === 'combo_classic' ? 'classic' : 'scale'); audio.playSfx('ui_click'); refresh(); return;
  }
  if (control?.startsWith('track_')) {
    audio.playBgm(control.slice('track_'.length)); refresh(); return;
  }
  if (control === 'guide_open') {
    battleUi.guideOpen = true; battleUi.guidePage = 0; refresh(); return;
  }
  if (control === 'guide_close') {
    battleUi.guideOpen = false; refresh(); return;
  }
  if (control === 'guide_replay_tutorial') {
    replayOpeningTutorial(); return;
  }
  if (control === 'guide_prev' || control === 'guide_next') {
    battleUi.guidePage = THREE.MathUtils.clamp(battleUi.guidePage + (control === 'guide_next' ? 1 : -1), 0, 3); refresh(); return;
  }
  if (control === 'battle_skills_open') {
    battleUi.skillsOpen = true; battleUi.skillsPage = 0; refresh(); return;
  }
  if (control === 'battle_skills_close') {
    battleUi.skillsOpen = false; refresh(); return;
  }
  if (control === 'battle_skills_prev' || control === 'battle_skills_next') {
    const ownedCount = Object.values(level.state.skills || {}).filter(value => value > 0).length;
    const maxPage = Math.max(0, Math.ceil(ownedCount / 5) - 1);
    battleUi.skillsPage = THREE.MathUtils.clamp(battleUi.skillsPage + (control === 'battle_skills_next' ? 1 : -1), 0, maxPage);
    refresh(); return;
  }
  if (control === 'battle_vfx_test_open') {
    battleUi.vfxTestOpen = true; refresh(); return;
  }
  if (control === 'battle_vfx_test_close') {
    battleUi.vfxTestOpen = false; refresh(); return;
  }
  if (control === 'battle_vfx_test_clear') {
    vfxDirector.clear();
    battleUi.vfxTestLast = '已清空';
    battleUi.vfxTestLastId = '';
    refresh({ consumeEvents: false });
    return;
  }
  if (control?.startsWith('battle_vfx_test_')) {
    runVfxTest(control.slice('battle_vfx_test_'.length)); return;
  }
  if (control === 'battle_vfx_test_block') {
    return;
  }
  if (control === 'battle_skill_preview_block') return;
  if (control?.startsWith('battle_skill_preview_')) {
    battleUi.skillChoicePreview = null;
    refresh({ consumeEvents: false });
    return;
  }
  if (control === 'battle_exit') {
    battleUi.exitConfirmOpen = true; refresh(); return;
  }
  if (control === 'exit_cancel') {
    battleUi.exitConfirmOpen = false; refresh(); return;
  }
  if (control === 'exit_confirm') {
    enterMenu(); return;
  }
  if (control?.startsWith('wheel_skill_')) {
    const index = Number(control.slice('wheel_skill_'.length));
    level.selectWheelSkill(index);
    refresh();
    return;
  }
  if (level.state.result) {
    if (level.state.result === 'win' && control?.startsWith('skill_')) {
      const index = Number(control.slice('skill_'.length));
      const skill = level.state.skillChoices[index];
      if (skill) {
        const outcome = level.selectSkill(index);
        meta.highestLevel = Math.max(meta.highestLevel, Math.min(11, level.state.stage + 1));
        meta.runsAtHighest = meta.totalRuns;
        saveMeta();
        if (outcome.kind === 'skill') {
          const next = level.continueToNextStage();
          settledResult = null;
          movement = null;
          turnSequence = null;
          queuedHeroAction = null;
          placeActor(hero, level.state.hero.q, level.state.hero.r);
          faceHeroTowardAudience();
          if (next.kind === 'chapter_complete') refresh();
          else {
            if (level.state.stage >= 10) audio.playBgm('boss_abyss');
            else if (level.state.stage >= 6) audio.playBgm('battle');
            refresh();
          }
        }
      }
      return;
    }
    if (control === 'home') enterMenu();
    return;
  }
  if (turnSequence || !['PLAYER_SELECT', 'PLAYER_PLAN'].includes(level.state.phase)) return;
  pointer.x = point.x / viewportWidth * 2 - 1;
  pointer.y = -(point.y / viewportHeight) * 2 + 1;
  raycaster.setFromCamera(pointer, camera);
  const hit = raycaster.intersectObjects(board.cells.map(cell => cell.mesh), false)[0];
  if (!hit) return;
  const { q, r } = hit.object.userData.cell;
  const summary = level.select(q, r);
  beginTurnSequence(summary);
  refresh();
}

function handleTouchStart(event) {
  if (appMode !== 'battle' || !event.touches || event.touches.length < 2) return;
  pinchStartDistance = distanceBetweenTouches(event.touches);
  pinchStartZoom = battleCameraController.userZoom;
  pinchActive = pinchStartDistance > 0;
  suppressTap = pinchActive;
}

function handleTouchMove(event) {
  if (!pinchActive || !event.touches || event.touches.length < 2) return;
  const distance = distanceBetweenTouches(event.touches);
  if (!distance || !pinchStartDistance) return;
  setBattleZoom(pinchStartZoom * distance / pinchStartDistance);
}

function handleTouchEnd(event) {
  if (pinchActive || suppressTap) {
    if (!event.touches || event.touches.length === 0) {
      pinchActive = false;
      suppressTap = false;
      refresh();
    } else if (event.touches.length < 2) pinchActive = false;
    return;
  }
  handleTouch(event);
}

if (typeof wx.onTouchEnd === 'function') {
  if (typeof wx.onTouchStart === 'function') wx.onTouchStart(handleTouchStart);
  if (typeof wx.onTouchMove === 'function') wx.onTouchMove(handleTouchMove);
  wx.onTouchEnd(handleTouchEnd);
} else if (typeof wx.onTouchStart === 'function') wx.onTouchStart(handleTouch);

function updateMovement(delta) {
  if (!movement) return;
  movement.elapsed += delta;
  const totalSegments = movement.points.length - 1;
  const raw = movement.elapsed / movement.segmentDuration;
  const segmentIndex = Math.min(totalSegments - 1, Math.floor(raw));
  const progress = Math.min(1, raw - segmentIndex);
  const eased = 1 - Math.pow(1 - progress, 3);
  hero.position.lerpVectors(movement.points[segmentIndex], movement.points[segmentIndex + 1], eased);
  if (movement.jumping) hero.position.y += Math.sin(progress * Math.PI) * 0.92;
  if (movement.elapsed >= movement.segmentDuration * totalSegments) {
    const completed = movement;
    placeActor(hero, level.state.hero.q, level.state.hero.r);
    movement = null;
    // Keep one continuous camera shot across the short gaps between combo
    // jumps. A normal move can return to idle framing as soon as it lands.
    if (!completed.jumping && cameraActionShot?.mode === 'hero_action') cameraActionShot = null;
    if (completed.jumping) {
      hero.userData.playAction?.('land', 0.34);
      landingPulse(level.state.hero.q, level.state.hero.r, completed.combo || 1);
      if (completed.item) queuedHeroAction = { name: 'pickup', duration: 0.58, startsAt: renderTime + 0.2 };
    } else if (completed.item) hero.userData.playAction?.('pickup', 0.58);
  }
}

function finishPlayerJump() {
  const summary = level.finishJumpExecution();
  if (cameraActionShot?.mode === 'hero_action') cameraActionShot = null;
  refresh();
  if (summary.kind === 'invalid') {
    turnSequence = null;
    return;
  }
  if (level.state.phase === 'COMBO_REWARD_WAIT') {
    turnSequence = {
      stage: 'COMBO_REWARD_WAIT',
      remaining: summary.reward ? Math.max(1.2, summary.reward.duration || 0) : 0.5,
      elapsed: 0,
      duration: 0,
      animations: [],
    };
  } else if (level.state.phase === 'ENEMY_TURN') {
    turnSequence = {
      stage: 'ENEMY_DELAY',
      remaining: 0.6,
      elapsed: 0,
      duration: 0.3,
      animations: [],
    };
  } else turnSequence = null;
}

function beginNextJumpStep() {
  const outcome = level.executeNextJump();
  if (outcome.kind !== 'jump_step') {
    finishPlayerJump();
    return;
  }
  startHeroMovement(outcome);
  turnSequence.stage = 'JUMP_ANIMATION';
  turnSequence.currentJump = outcome;
  turnSequence.remaining = 0;
}

function beginEnemyAnimation() {
  const outcome = level.processEnemyTurn();
  // Enemy logic resolves first, but its hit flashes and damage numbers wait
  // until the lunge reaches the hero instead of appearing at wind-up.
  refresh({ consumeEvents: false });
  const animations = [];
  let enemyCameraCandidate = null;
  for (const action of outcome.actions || []) {
    const actor = enemyActors.get(action.enemyId);
    if (!actor) continue;
    const sourceCell = action.from || level.state.enemies.find(enemy => enemy.id === action.enemyId);
    const destinationCell = action.targetAt || action.to || null;
    const sourcePoint = sourceCell
      ? cellPosition(sourceCell.q, sourceCell.r, actor.userData.baseY)
      : actor.position.clone();
    const destinationPoint = destinationCell
      ? cellPosition(destinationCell.q, destinationCell.r, actor.userData.baseY)
      : null;
    const enemyState = level.state.enemies.find(enemy => enemy.id === action.enemyId);
    const rangedAttack = action.type === 'attack'
      && Boolean(destinationCell)
      && ((enemyState?.range || 1) > 1 || (sourceCell && hexDistance(sourceCell, destinationCell) > 1));
    const cameraRelevantAction = action.type === 'attack' || action.type === 'boss_claw';
    if (cameraRelevantAction && battleCameraController.needsEnemyActionShot({
      from: sourcePoint,
      to: destinationPoint,
      ranged: rangedAttack,
      actionType: action.type,
    })) {
      const candidate = {
        priority: rangedAttack ? 2 : 1,
        mode: 'enemy_action',
        primary: destinationPoint || sourcePoint,
        points: destinationPoint ? [sourcePoint, destinationPoint] : [sourcePoint],
        margin: rangedAttack ? 0.94 : 0.8,
        // Keep the attack framing through impact and a short readability beat.
        // buildPlayerCameraShot releases it later instead of reversing on the
        // exact frame the 0.3s enemy animation completes.
        releaseAt: renderTime + 0.72,
      };
      if (!enemyCameraCandidate || candidate.priority > enemyCameraCandidate.priority) {
        enemyCameraCandidate = candidate;
      }
    }
    if ((action.type === 'move' || action.type === 'push' || action.type === 'teleport') && action.from && action.to) {
      const from = cellPosition(action.from.q, action.from.r, actor.userData.baseY);
      const to = cellPosition(action.to.q, action.to.r, actor.userData.baseY);
      actor.position.copy(from);
      actor.userData.healthBarAnchor?.copy(from);
      faceActorTowardWorld(actor, to);
      actor.userData.playAction?.('move', 0.3);
      animations.push({ type: action.type === 'teleport' ? 'teleport' : 'move', actor, from, to });
    } else if (action.type === 'attack' || action.type === 'boss_claw') {
      audio.playSfx('attack_hit');
      const from = actor.position.clone();
      actor.userData.healthBarAnchor?.copy(from);
      const target = action.targetAt
        ? cellPosition(action.targetAt.q, action.targetAt.r, actor.userData.baseY)
        : hero.position.clone();
      faceActorTowardWorld(actor, target);
      actor.userData.playAction?.('attack', 0.34);
      animations.push({
        type: 'attack', actor, from, target,
        targetType: action.target,
        damage: action.damage || 0,
        reflected: action.reflected || 0,
      });
    } else if (action.targetAt) {
      // Boss skills can act without a move/lunge animation. They still turn
      // toward their snapshotted target when that action begins.
      faceActorTowardWorld(
        actor,
        cellPosition(action.targetAt.q, action.targetAt.r, actor.userData.baseY)
      );
    }
  }
  cameraActionShot = enemyCameraCandidate;
  turnSequence = {
    stage: 'ENEMY_ANIMATION',
    remaining: 0,
    elapsed: 0,
    duration: 0.3,
    animations,
    impactsPresented: false,
  };
}

function updateTurnSequence(delta) {
  if (!turnSequence) return;
  if (turnSequence.stage === 'JUMP_INITIAL_DELAY' || turnSequence.stage === 'JUMP_GAP') {
    turnSequence.remaining -= delta;
    if (turnSequence.remaining <= 0 && !movement) beginNextJumpStep();
    return;
  }

  if (turnSequence.stage === 'JUMP_ANIMATION') {
    if (movement) return;
    const completed = turnSequence.currentJump;
    refresh();
    if (completed?.done) finishPlayerJump();
    else {
      turnSequence.stage = 'JUMP_GAP';
      turnSequence.remaining = 0.05;
      turnSequence.currentJump = null;
    }
    return;
  }

  if (turnSequence.stage === 'COMBO_REWARD_WAIT') {
    turnSequence.remaining -= delta;
    if (turnSequence.remaining <= 0) {
      level.completeComboRewardWait();
      refresh();
      if (level.state.phase === 'ENEMY_TURN') {
        turnSequence = {
          stage: 'ENEMY_DELAY',
          remaining: 0.6,
          elapsed: 0,
          duration: 0.3,
          animations: [],
        };
      } else turnSequence = null;
    }
    return;
  }

  if (turnSequence.stage === 'ENEMY_DELAY') {
    turnSequence.remaining -= delta;
    if (turnSequence.remaining <= 0 && !movement) {
      const intent = level.prepareEnemyTurn();
      if (intent) {
        refresh();
        turnSequence.stage = 'BOSS_PRECAST';
        turnSequence.remaining = 0.8;
      } else beginEnemyAnimation();
    }
    return;
  }

  if (turnSequence.stage === 'BOSS_PRECAST') {
    turnSequence.remaining -= delta;
    if (turnSequence.remaining <= 0 && !movement) beginEnemyAnimation();
    return;
  }

  if (movement) return;

  if (turnSequence.stage === 'ENEMY_ANIMATION') {
    turnSequence.elapsed += delta;
    const progress = Math.min(1, turnSequence.elapsed / turnSequence.duration);
    const eased = 1 - Math.pow(1 - progress, 3);
    for (const animation of turnSequence.animations) {
      if (animation.type === 'move' || animation.type === 'teleport') {
        animation.actor.position.lerpVectors(animation.from, animation.to, eased);
        animation.actor.userData.healthBarAnchor?.copy(animation.actor.position);
      } else {
        const lunge = Math.sin(progress * Math.PI) * 0.22;
        animation.actor.position.copy(animation.from).lerp(animation.target, lunge);
      }
    }
    if (!turnSequence.impactsPresented && progress >= 0.52) {
      turnSequence.impactsPresented = true;
      const heroHits = turnSequence.animations.filter(animation => animation.targetType === 'hero' && animation.damage > 0);
      if (heroHits.length && isBattleVfxApproved('hero_hit_reaction')) {
        const strongestHit = heroHits.reduce((strongest, hit) =>
          (hit.damage || 0) > (strongest.damage || 0) ? hit : strongest, heroHits[0]);
        const worldRecoil = hero.position.clone().sub(strongestHit.from).setY(0);
        if (worldRecoil.lengthSq() < 0.001) worldRecoil.set(0, 0, -1);
        worldRecoil.normalize();
        const localRecoil = worldRecoil.applyQuaternion(hero.quaternion.clone().invert()).setY(0).normalize();
        hero.userData.playAction?.('approved_hit', 0.58, {
          recoilX: localRecoil.x,
          recoilZ: localRecoil.z,
          staggerSign: localRecoil.x < 0 ? -1 : 1,
        });
      }
      const scarecrowHits = turnSequence.animations.filter(animation => animation.targetType === 'scarecrow');
      if (scarecrowHits.length && scarecrowActor?.visible) {
        scarecrowActor.userData.playAction?.('hit', 0.42);
        const damage = scarecrowHits.reduce((total, animation) => total + (animation.damage || 0), 0);
        const position = scarecrowActor.position.clone();
        position.y += 1.34;
        const sprite = combatTextSprite(`-${damage}`, '稻草人承伤', '#ffd56e');
        sprite.position.copy(position);
        addBattleEffect(sprite, 0.68, local => {
          sprite.position.y = position.y + local * 0.62;
          sprite.material.opacity = local < 0.62 ? 1 : (1 - local) / 0.38;
        });
        if (isBattleVfxApproved('enemy_attack_impact')) {
          impactBurst(scarecrowActor.position.clone().add(new THREE.Vector3(0, 0.85, 0)), 0xffc45d, true);
        }
      }
      consumePresentationEvents();
    }
    if (progress >= 1) {
      if (!turnSequence.impactsPresented) consumePresentationEvents();
      for (const animation of turnSequence.animations) {
        if (animation.type === 'move' || animation.type === 'teleport') {
          animation.actor.position.copy(animation.to);
          animation.actor.userData.healthBarAnchor?.copy(animation.to);
        } else {
          animation.actor.position.copy(animation.from);
          animation.actor.userData.healthBarAnchor?.copy(animation.from);
        }
      }
      // Lua's 0.35s post-action timer runs alongside the 0.3s enemy animation.
      turnSequence = { stage: 'ENEMY_RESOLVE', remaining: 0.05, elapsed: 0, duration: 0, animations: [] };
    }
    return;
  }

  if (turnSequence.stage === 'ENEMY_RESOLVE') {
    turnSequence.remaining -= delta;
    if (turnSequence.remaining <= 0) {
      if (!level.state.result) level.startPlayerTurn();
      turnSequence = null;
      refresh();
    }
  }
}

let running = true;
let previousTime = 0;

function frame(timestamp = 0) {
  if (!running) return;
  const time = timestamp * 0.001;
  renderTime = time;
  const delta = Math.min(0.05, Math.max(0, time - previousTime));
  previousTime = time;
  updateMovement(delta);
  if (queuedHeroAction && time >= queuedHeroAction.startsAt) {
    hero.userData.playAction?.(queuedHeroAction.name, queuedHeroAction.duration);
    queuedHeroAction = null;
  }
  const confirmPulse = 1 + Math.sin(time * 5.4) * 0.13;
  routeGroup.children.forEach(child => {
    if (child.userData.confirmMarker) child.scale.setScalar(confirmPulse);
  });
  const threatPulse = 0.78 + (Math.sin(time * 5) + 1) * 0.11;
  threatGroup.children.forEach(child => {
    if (child.userData.threatPulse && child.material) {
      child.material.opacity = child.userData.baseOpacity * threatPulse;
    }
    if (child.userData.threatRing) {
      child.material.opacity = child.userData.baseOpacity * threatPulse;
      child.scale.setScalar(0.94 + threatPulse * 0.1);
    }
  });
  const tutorialBlocksTimeline = level.state.tutorialOverlay
    && level.state.tutorialOverlay.interaction !== 'board';
  if (!level.state.wheelResult && !level.state.wheelSkillChoices?.length
    && !tutorialBlocksTimeline && !level.state.enemyIntro?.length
    && !battleUi.settingsOpen && !battleUi.guideOpen && !battleUi.skillsOpen
    && !battleUi.vfxTestOpen && !battleUi.skillChoicePreview && !battleUi.exitConfirmOpen) updateTurnSequence(delta);
  updateBattleEffects(delta);
  vfxDirector.update(delta);
  updateDynamicBattleCamera(delta);
  updateHeroFacing(delta);
  updateEnemyFacings(delta);
  if (!movement) hero.position.y = hero.userData.baseY + Math.round(Math.sin(time * 3.2) * 2) * 0.018;
  const globalTimeStopped = appMode === 'battle' && level.state.timeStopTurns > 0;
  actors.forEach((actor, index) => {
    if (actor === hero) return;
    if (globalTimeStopped && actor.userData.enemyId) {
      actor.position.y = actor.userData.baseY;
      return;
    }
    actor.position.y = actor.userData.baseY + Math.round(Math.sin(time * 2.4 + index) * 2) * 0.014;
  });
  actors.forEach(actor => {
    const shadow = actor.userData.contactShadow;
    if (!shadow) return;
    const lift = Math.max(0, actor.position.y - actor.userData.baseY);
    shadow.position.y = (0.012 - lift) / actor.scale.y;
    shadow.material.opacity = shadow.userData.baseOpacity * Math.max(0.18, 1 - lift * 0.72);
  });
  actors.forEach(actor => {
    if (globalTimeStopped && actor.userData.enemyId) return;
    actor.userData.animate?.(time, actor === hero && Boolean(movement));
  });
  updateDyingActors(time);
  syncActorStatuses(time);
  comboRewardDirector.update(delta, level.state);
  comboRewardDirector.stabilizeHealthBars();
  keepHealthBarsFacingCamera();
  applyVfxCameraShake(delta, time);
  const logicalShield = Boolean(level.state.oneHitShield || level.state.hero.shield > 0 || level.state.drainShield > 0);
  const approvedDrainShieldVisible = level.state.drainShield > 0 && Boolean(comboRewardDirector.lifeDrain.effect);
  if (logicalShield) shieldVisualActive = true;
  if (shieldBreakAt && time >= shieldBreakAt) {
    shieldVisualActive = logicalShield;
    shieldBreakAt = 0;
  }
  // The approved five-combo shell owns the persistent drain-shield visual.
  // Keep the generic blue aura as a fallback only, avoiding two shields
  // occupying the same silhouette after Life Drain resolves.
  heroShieldAura.visible = appMode === 'battle' && shieldVisualActive && !approvedDrainShieldVisible;
  if (heroShieldAura.visible) {
    shieldShell.material.opacity = 0.1 + Math.sin(time * 4.2) * 0.035;
    shieldOrbit.rotation.z = time * 0.85;
    shieldOrbit.scale.setScalar(0.96 + Math.sin(time * 3.1) * 0.06);
  }
  environment.update(time);
  if ((appMode === 'menu' && menuState.shopResultOpen) || (appMode === 'battle' && level.state.tutorialOverlay)) {
    hud.draw({
      ...level.state, mode: appMode, meta, menuState, battleUi, cameraZoom: battleZoom,
      tutorialSpotlight: buildTutorialSpotlight(), tutorialTime: time,
    });
  }
  renderer.render(scene, camera);
  hud.render();
  const raf = canvas.requestAnimationFrame || globalThis.requestAnimationFrame;
  raf(frame);
}

wx.onHide(() => {
  running = false;
});

wx.onShow(() => {
  if (running) return;
  running = true;
  previousTime = 0;
  frame();
});

enterMenu();
console.log('[combo-checkers] WeChat chapter one campaign started', {
  viewportWidth,
  viewportHeight,
  pixelRatio,
  threeRevision: THREE.REVISION,
  boardCells: board.cells.length,
  killTarget: level.state.killTarget,
  initialEnemies: level.state.enemies.length,
  initialMode: appMode,
  stages: 10,
  skillCount: 19,
  comboPresentation: true,
  sceneTheme: CHAPTER_ONE_THEME,
  architecture: 'TypeScript-ready JavaScript + Three.js + wx adapter',
});
frame();
