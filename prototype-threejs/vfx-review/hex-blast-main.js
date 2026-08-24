import * as THREE from '../vendor/three.module.js';
import { createChapterOneEnemy, createPenguin, createSlime } from '../src/game/Units.js';
import { HexBlastRewardCandidate } from './HexBlastRewardCandidate.js?v=20260821a';

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
scene.add(new THREE.HemisphereLight(0x9fd4e5, 0x151f4a, 1.2));
const key = new THREE.DirectionalLight(0xffd9b0, 2.45);
key.position.set(-5, 8, 6);
key.castShadow = true;
key.shadow.mapSize.set(1024, 1024);
Object.assign(key.shadow.camera, { left: -7, right: 7, top: 7, bottom: -7, near: 1, far: 24 });
key.shadow.bias = -0.001;
key.shadow.normalBias = 0.05;
scene.add(key);
const violetRim = new THREE.DirectionalLight(0x9274ff, 1.25);
violetRim.position.set(6, 5, -5);
scene.add(violetRim);

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
function isInside(q, r) {
  return Math.max(Math.abs(q), Math.abs(r), Math.abs(-q - r)) <= BOARD_RADIUS;
}

const board = new THREE.Group();
board.name = 'HexBlastReviewBoard';
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
  model.userData.healthBar.visible = false;
  mount.add(model);
  model.traverse(child => {
    if (!child.isMesh) return;
    child.castShadow = true;
    child.receiveShadow = true;
  });
  return {
    mount, model, materials: collectMaterials(model),
    basePosition: mount.position.clone(), baseScale: model.scale.clone(), baseRotationZ: 0,
    hitAt: null,
  };
}

const jumpCells = {
  start: axialToWorld(-2, 0),
  first: axialToWorld(0, -2),
  second: axialToWorld(2, -2),
  third: axialToWorld(2, 0),
  fourth: axialToWorld(0, 0),
};
const heroEntry = createActor(createPenguin(), 0.88);
const minionEntries = Array.from({ length: 5 }, () => createActor(createSlime(), 0.86));
const bossEntry = createActor(createChapterOneEnemy('abyss_kraken'), 0.52);
const allEnemyEntries = [...minionEntries, bossEntry];

const CUBE_DIRECTIONS = [
  [1, 0], [1, -1], [0, -1], [-1, 0], [-1, 1], [0, 1],
];
const rayPaths = CUBE_DIRECTIONS.map(([dq, dr]) => {
  const cells = [];
  for (let distance = 1; distance <= BOARD_RADIUS; distance += 1) {
    const q = dq * distance;
    const r = dr * distance;
    if (!isInside(q, r)) break;
    cells.push({ q, r, position: axialToWorld(q, r) });
  }
  return { dq, dr, cells, end: cells[cells.length - 1].position.clone() };
});

function restoreEntry(entry) {
  entry.mount.visible = false;
  entry.mount.position.copy(entry.basePosition);
  entry.mount.rotation.set(0, 0, 0);
  entry.model.scale.copy(entry.baseScale);
  entry.hitAt = null;
  entry.materials.forEach(({ material, opacity, transparent }) => {
    material.opacity = opacity;
    material.transparent = transparent;
  });
}

function placeEntry(entry, q, r) {
  entry.mount.visible = true;
  entry.mount.position.copy(axialToWorld(q, r));
  entry.mount.position.y = 0.15;
  entry.basePosition.copy(entry.mount.position);
  entry.baseRotationZ = 0;
  faceToward(entry.mount, jumpCells.fourth);
  return entry;
}

let scenario = 'minions';
let activeTargets = [];
function configureScenario() {
  allEnemyEntries.forEach(restoreEntry);
  if (scenario === 'boss') {
    const boss = placeEntry(bossEntry, 0, 2);
    const observer = placeEntry(minionEntries[0], 1, 1);
    observer.mount.rotation.y += 0.18;
    activeTargets = [{
      entry: boss, kind: 'boss', incoming: boss.mount.position.clone().sub(jumpCells.fourth).normalize(), fallDirection: 0,
    }];
    return;
  }
  if (scenario === 'path') {
    const aligned = placeEntry(minionEntries[0], -3, 3);
    placeEntry(minionEntries[1], 1, 1);
    placeEntry(minionEntries[2], -1, -1);
    activeTargets = [{
      entry: aligned, kind: 'minion', incoming: aligned.mount.position.clone().sub(jumpCells.fourth).normalize(), fallDirection: -1,
    }];
    return;
  }
  const targets = [
    placeEntry(minionEntries[0], 0, 2),
    placeEntry(minionEntries[1], -2, 2),
    placeEntry(minionEntries[2], 3, 0),
  ];
  placeEntry(minionEntries[3], 1, 1);
  activeTargets = targets.map((entry, index) => ({
    entry, kind: 'minion', incoming: entry.mount.position.clone().sub(jumpCells.fourth).normalize(),
    fallDirection: index % 2 ? -1 : 1,
  }));
}

const FORMAL_BATTLE_VIEW_WIDTH = 12.3;
const FORMAL_BATTLE_ZOOM = 1.45;
const camera = new THREE.OrthographicCamera(-4, 4, 3, -3, 0.1, 30);
const cameraTarget = new THREE.Vector3(0, 0.15, 0.25);
camera.position.copy(cameraTarget).add(new THREE.Vector3(0, 21.85, 11.25));
camera.zoom = FORMAL_BATTLE_ZOOM;
camera.lookAt(cameraTarget);
camera.updateProjectionMatrix();

const reward = new HexBlastRewardCandidate(scene);
const comboPopup = document.getElementById('combo-popup');
const jumpWindows = [
  { start: 0.12, end: 0.48, from: jumpCells.start, to: jumpCells.first },
  { start: 0.62, end: 0.98, from: jumpCells.first, to: jumpCells.second },
  { start: 1.12, end: 1.48, from: jumpCells.second, to: jumpCells.third },
  { start: 1.62, end: 1.98, from: jumpCells.third, to: jumpCells.fourth },
];
const rewardStart = 2.18;
const rewardCastLead = 0.2;
const rewardCastStart = rewardStart - rewardCastLead;
const rewardCastDuration = 0.9;
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
  reward.play({ origin: jumpCells.fourth, paths: rayPaths, targets: activeTargets });
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
    scenario = button.dataset.scenario || 'minions';
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
  else setHeroAt(jumpCells.fourth);

  if (playing && !rewardCastPlayed && sequenceElapsed >= rewardCastStart) {
    rewardCastPlayed = true;
    heroEntry.model.userData.playAction?.('hex_blast_cast', rewardCastDuration / playbackSpeed);
  }
  if (playing && !rewardPlayed && sequenceElapsed >= rewardStart) {
    rewardPlayed = true;
    playReward();
  }
  if (rewardPlayed) reward.update(delta * playbackSpeed);

  const sequenceDuration = rewardStart + reward.duration + 0.72;
  if (playing && sequenceElapsed >= sequenceDuration) {
    playing = false;
    if (loopEnabled) startSequence(now + 0.34);
  }

  heroEntry.model.userData.animate?.(elapsed);
  allEnemyEntries.forEach(entry => entry.model.userData.animate?.(elapsed));
  renderer.render(scene, camera);
}
animate();

function easeOutCubic(value) {
  return 1 - Math.pow(1 - clamp01(value), 3);
}
