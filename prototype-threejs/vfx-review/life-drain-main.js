import * as THREE from '../vendor/three.module.js';
import { createChapterOneEnemy, createPenguin, createSlime } from '../src/game/Units.js';
import { LifeDrainRewardCandidate } from './LifeDrainRewardCandidate.js?v=20260822i';

const clamp01 = value => Math.max(0, Math.min(1, value));
const canvas = document.getElementById('review-canvas');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: false, powerPreference: 'high-performance' });
renderer.setPixelRatio(Math.min(2, window.devicePixelRatio || 1));
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFShadowMap;
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.12;

const scene = new THREE.Scene();
scene.background = new THREE.Color(0x071f38);
scene.fog = new THREE.Fog(0x071f38, 21, 39);
scene.add(new THREE.HemisphereLight(0xa6dbe1, 0x171a46, 1.22));
const key = new THREE.DirectionalLight(0xffd9b0, 2.4);
key.position.set(-5, 8, 6);
key.castShadow = true;
key.shadow.mapSize.set(1024, 1024);
Object.assign(key.shadow.camera, { left: -7, right: 7, top: 7, bottom: -7, near: 1, far: 24 });
key.shadow.bias = -0.001;
key.shadow.normalBias = 0.05;
scene.add(key);
const lifeRim = new THREE.DirectionalLight(0x65efb1, 1.25);
lifeRim.position.set(6, 5, -5);
scene.add(lifeRim);
const lifeFill = new THREE.DirectionalLight(0x8cffc7, 0.72);
lifeFill.position.set(-5, 3, -4);
scene.add(lifeFill);

const floor = new THREE.Mesh(
  new THREE.CircleGeometry(8.2, 56),
  new THREE.MeshStandardMaterial({ color: 0x081c32, roughness: 0.94, metalness: 0 })
);
floor.rotation.x = -Math.PI * 0.5;
floor.position.y = -0.05;
floor.receiveShadow = true;
scene.add(floor);

const BOARD_RADIUS = 3;
const CELL_RADIUS = 0.82;
function axialToWorld(q, r) {
  return new THREE.Vector3(Math.sqrt(3) * CELL_RADIUS * (q + r * 0.5), 0.04, 1.5 * CELL_RADIUS * r);
}

const board = new THREE.Group();
board.name = 'LifeDrainReviewBoard';
scene.add(board);
const tileGeometry = new THREE.CylinderGeometry(0.78, 0.82, 0.17, 6);
const tileMaterials = [0x153f63, 0x1a4f72, 0x225f82].map(color => (
  new THREE.MeshStandardMaterial({ color, roughness: 0.76, metalness: 0.02 })
));
for (let q = -BOARD_RADIUS; q <= BOARD_RADIUS; q += 1) {
  const rMin = Math.max(-BOARD_RADIUS, -q - BOARD_RADIUS);
  const rMax = Math.min(BOARD_RADIUS, -q + BOARD_RADIUS);
  for (let r = rMin; r <= rMax; r += 1) {
    const tile = new THREE.Mesh(tileGeometry, tileMaterials[Math.abs(q * 3 + r) % tileMaterials.length]);
    tile.position.copy(axialToWorld(q, r));
    tile.castShadow = true;
    tile.receiveShadow = true;
    board.add(tile);
  }
}

function faceToward(mount, target) {
  const direction = target.clone().sub(mount.position).setY(0);
  if (direction.lengthSq() < 0.001) return;
  mount.rotation.y = Math.atan2(direction.x, direction.z);
}

function collectMaterials(model) {
  const materials = [];
  const seen = new Set();
  model.traverse(child => {
    if (!child.isMesh) return;
    const list = Array.isArray(child.material) ? child.material : [child.material];
    list.filter(Boolean).forEach(material => {
      if (seen.has(material)) return;
      seen.add(material);
      materials.push({ material, opacity: material.opacity, transparent: material.transparent });
    });
  });
  return materials;
}

function createActor(model, scale) {
  const mount = new THREE.Group();
  mount.position.y = 0.15;
  scene.add(mount);
  model.scale.multiplyScalar(scale);
  if (model.userData.healthBar) model.userData.healthBar.visible = false;
  mount.add(model);
  model.traverse(child => {
    if (!child.isMesh) return;
    child.castShadow = true;
    child.receiveShadow = true;
  });
  return {
    mount, model, materials: collectMaterials(model),
    basePosition: mount.position.clone(), baseScale: model.scale.clone(), damageAt: null,
  };
}

const jumpCells = {
  start: axialToWorld(0, 0),
  first: axialToWorld(2, 0),
  second: axialToWorld(2, -2),
  third: axialToWorld(0, -2),
  fourth: axialToWorld(-2, 0),
  fifth: axialToWorld(0, 0),
};
const heroEntry = createActor(createPenguin(), 0.88);
const enemyEntries = [
  { entry: createActor(createSlime(), 0.84), kind: 'minion', hp: 80, q: -2, r: 2 },
  { entry: createActor(createChapterOneEnemy('archerfish'), 0.62), kind: 'minion', hp: 25, q: 3, r: -1 },
  { entry: createActor(createChapterOneEnemy('iron_turtle'), 0.54), kind: 'minion', hp: 12, q: -3, r: 0 },
  { entry: createActor(createChapterOneEnemy('abyss_kraken'), 0.46), kind: 'boss', hp: 420, q: 0, r: 3 },
];

function restoreEntry(entry) {
  entry.mount.visible = true;
  entry.mount.position.copy(entry.basePosition);
  entry.mount.rotation.set(0, 0, 0);
  entry.model.scale.copy(entry.baseScale);
  entry.damageAt = null;
  entry.materials.forEach(({ material, opacity, transparent }) => {
    material.opacity = opacity;
    material.transparent = transparent;
  });
}

function placeEnemy(definition) {
  const entry = definition.entry;
  restoreEntry(entry);
  entry.mount.position.copy(axialToWorld(definition.q, definition.r));
  entry.mount.position.y = 0.15;
  entry.basePosition.copy(entry.mount.position);
  faceToward(entry.mount, jumpCells.fifth);
  const damage = definition.kind === 'boss' ? 30 : Math.max(5, Math.floor(definition.hp * 0.2));
  return { entry, kind: definition.kind, hp: definition.hp, damage, killed: damage >= definition.hp };
}

let scenario = 'heal';
let activeTargets = [];
let activeOutcome = null;
function configureScenario() {
  activeTargets = enemyEntries.map(placeEnemy);
  const totalDrain = activeTargets.reduce((sum, target) => sum + target.damage, 0);
  const heroHpBefore = scenario === 'heal' ? 38 : scenario === 'overflow' ? 86 : 100;
  const shieldBefore = scenario === 'cap' ? 60 : 0;
  const missingHp = 100 - heroHpBefore;
  const heal = Math.min(totalDrain, missingHp);
  const overflow = totalDrain - heal;
  const shieldAdded = Math.min(overflow, Math.max(0, 60 - shieldBefore));
  const shieldTotal = shieldBefore + shieldAdded;
  activeOutcome = {
    totalDrain, heroHpBefore, heal, overflow,
    shieldBefore, shieldAdded, shieldTotal, shieldFull: shieldTotal >= 60,
  };
}

const FORMAL_BATTLE_VIEW_WIDTH = 12.3;
const FORMAL_BATTLE_ZOOM = 1.45;
const camera = new THREE.OrthographicCamera(-4, 4, 3, -3, 0.1, 30);
const cameraTarget = new THREE.Vector3(0, 0.15, 0.25);
camera.position.copy(cameraTarget).add(new THREE.Vector3(0, 21.85, 11.25));
camera.zoom = FORMAL_BATTLE_ZOOM;
camera.lookAt(cameraTarget);
camera.updateProjectionMatrix();

const reward = new LifeDrainRewardCandidate(scene);
const comboPopup = document.getElementById('combo-popup');
const jumpWindows = [
  { start: 0.1, end: 0.4, from: jumpCells.start, to: jumpCells.first },
  { start: 0.52, end: 0.82, from: jumpCells.first, to: jumpCells.second },
  { start: 0.94, end: 1.24, from: jumpCells.second, to: jumpCells.third },
  { start: 1.36, end: 1.66, from: jumpCells.third, to: jumpCells.fourth },
  { start: 1.78, end: 2.08, from: jumpCells.fourth, to: jumpCells.fifth },
];
const rewardStart = 2.28;
const rewardCastStart = 2.1;
const rewardCastDuration = 1.08;
let sequenceStart = performance.now() * 0.001 + 0.2;
let jumpActionIndex = 0;
let rewardCastPlayed = false;
let rewardPlayed = false;
let loopEnabled = true;
let playbackSpeed = 1;
let playing = true;

function setHeroAt(position, lift = 0) {
  heroEntry.mount.position.copy(position);
  heroEntry.mount.position.y = 0.15 + lift;
}

function startSequence(now = performance.now() * 0.001) {
  comboPopup.classList.remove('active');
  reward.clear();
  configureScenario();
  jumpActionIndex = 0;
  rewardCastPlayed = false;
  rewardPlayed = false;
  playing = true;
  sequenceStart = now + 0.12;
  heroEntry.model.userData.action = null;
  setHeroAt(jumpCells.start);
  faceToward(heroEntry.mount, jumpCells.first);
}

function playReward() {
  comboPopup.classList.remove('active');
  void comboPopup.offsetWidth;
  comboPopup.classList.add('active');
  reward.play({ origin: jumpCells.fifth, targets: activeTargets, outcome: activeOutcome });
}

document.getElementById('play-once').addEventListener('click', () => startSequence());
document.getElementById('toggle-loop').addEventListener('click', event => {
  loopEnabled = !loopEnabled;
  event.currentTarget.classList.toggle('active', loopEnabled);
  event.currentTarget.textContent = loopEnabled ? '循环开启' : '循环关闭';
  if (loopEnabled && !playing) startSequence();
});
document.querySelectorAll('[data-speed]').forEach(button => {
  button.addEventListener('click', () => {
    playbackSpeed = Number(button.dataset.speed) || 1;
    document.querySelectorAll('[data-speed]').forEach(item => item.classList.toggle('active', item === button));
    startSequence();
  });
});
document.querySelectorAll('[data-scenario]').forEach(button => {
  button.addEventListener('click', () => {
    scenario = button.dataset.scenario || 'heal';
    document.querySelectorAll('[data-scenario]').forEach(item => item.classList.toggle('active', item === button));
    startSequence();
  });
});

function resize() {
  const width = Math.max(1, canvas.clientWidth);
  const height = Math.max(1, canvas.clientHeight);
  renderer.setSize(width, height, false);
  const aspect = width / height;
  const viewHeight = FORMAL_BATTLE_VIEW_WIDTH / aspect;
  camera.left = -FORMAL_BATTLE_VIEW_WIDTH * 0.5;
  camera.right = FORMAL_BATTLE_VIEW_WIDTH * 0.5;
  camera.top = viewHeight * 0.5;
  camera.bottom = -viewHeight * 0.5;
  camera.updateProjectionMatrix();
}
window.addEventListener('resize', resize);
resize();

const clock = new THREE.Clock();
let elapsed = 0;
startSequence();
function animate() {
  requestAnimationFrame(animate);
  const delta = Math.min(0.05, clock.getDelta());
  elapsed += delta;
  const now = performance.now() * 0.001;
  const sequenceElapsed = Math.max(0, (now - sequenceStart) * playbackSpeed);

  while (playing && jumpActionIndex < jumpWindows.length && sequenceElapsed >= jumpWindows[jumpActionIndex].start) {
    const jump = jumpWindows[jumpActionIndex];
    faceToward(heroEntry.mount, jump.to);
    heroEntry.model.userData.playAction?.('jump_attack', (jump.end - jump.start) / playbackSpeed);
    jumpActionIndex += 1;
  }

  let activeJump = null;
  for (const jump of jumpWindows) {
    if (sequenceElapsed >= jump.start && sequenceElapsed <= jump.end) activeJump = jump;
  }
  if (activeJump) {
    const local = clamp01((sequenceElapsed - activeJump.start) / (activeJump.end - activeJump.start));
    const eased = easeOutCubic(local);
    setHeroAt(activeJump.from.clone().lerp(activeJump.to, eased), Math.sin(local * Math.PI) * 0.76);
  } else if (sequenceElapsed < jumpWindows[0].start) setHeroAt(jumpCells.start);
  else if (sequenceElapsed < jumpWindows[1].start) setHeroAt(jumpCells.first);
  else if (sequenceElapsed < jumpWindows[2].start) setHeroAt(jumpCells.second);
  else if (sequenceElapsed < jumpWindows[3].start) setHeroAt(jumpCells.third);
  else if (sequenceElapsed < jumpWindows[4].start) setHeroAt(jumpCells.fourth);
  else setHeroAt(jumpCells.fifth);

  if (playing && !rewardCastPlayed && sequenceElapsed >= rewardCastStart) {
    rewardCastPlayed = true;
    heroEntry.model.userData.playAction?.('life_drain_cast', rewardCastDuration / playbackSpeed);
  }
  if (playing && !rewardPlayed && sequenceElapsed >= rewardStart) {
    rewardPlayed = true;
    playReward();
  }
  if (rewardPlayed) reward.update(delta * playbackSpeed);

  const sequenceDuration = rewardStart + reward.duration + 0.78;
  if (playing && sequenceElapsed >= sequenceDuration) {
    playing = false;
    if (loopEnabled) startSequence(now + 0.34);
  }

  heroEntry.model.userData.animate?.(elapsed);
  enemyEntries.forEach(({ entry }) => entry.model.userData.animate?.(elapsed));
  renderer.render(scene, camera);
}
animate();

function easeOutCubic(value) {
  return 1 - Math.pow(1 - clamp01(value), 3);
}
