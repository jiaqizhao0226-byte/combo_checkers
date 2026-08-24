import * as THREE from '../vendor/three.module.js';
import { createPenguin, createSlime } from '../src/game/Units.js';
import { TrackingDartRewardCandidate } from './TrackingDartRewardCandidate.js?v=20260821t';

const canvas = document.getElementById('review-canvas');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true, powerPreference: 'high-performance' });
renderer.setPixelRatio(Math.min(2, window.devicePixelRatio || 1));
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.15;

const scene = new THREE.Scene();
scene.fog = new THREE.Fog(0x071b24, 21, 39);
scene.add(new THREE.HemisphereLight(0x9dd3dc, 0x153c44, 1.18));
const key = new THREE.DirectionalLight(0xffd9ad, 2.55);
key.position.set(-5, 8, 6);
key.castShadow = true;
key.shadow.mapSize.set(1024, 1024);
Object.assign(key.shadow.camera, { left: -7, right: 7, top: 7, bottom: -7, near: 1, far: 24 });
key.shadow.bias = -0.001;
key.shadow.normalBias = 0.05;
scene.add(key);
const rim = new THREE.DirectionalLight(0x58bde0, 1.05);
rim.position.set(6, 5, -5);
scene.add(rim);

const floor = new THREE.Mesh(
  new THREE.CircleGeometry(8.2, 56),
  new THREE.MeshStandardMaterial({ color: 0x0a2832, roughness: 0.94, metalness: 0 })
);
floor.rotation.x = -Math.PI * 0.5;
floor.position.y = -0.05;
floor.receiveShadow = true;
scene.add(floor);

const board = new THREE.Group();
scene.add(board);
const tileGeometry = new THREE.CylinderGeometry(0.78, 0.82, 0.17, 6);
const tileMaterials = [0x174c62, 0x1d5b6d, 0x25697a].map(color => new THREE.MeshStandardMaterial({ color, roughness: 0.78 }));
function axialToWorld(q, r) {
  const radius = 0.82;
  return new THREE.Vector3(
    Math.sqrt(3) * radius * (q + r * 0.5),
    0.04,
    1.5 * radius * r
  );
}

function addTile(q, r) {
  const tile = new THREE.Mesh(tileGeometry, tileMaterials[Math.abs(q * 3 + r) % tileMaterials.length]);
  tile.position.copy(axialToWorld(q, r));
  tile.castShadow = true;
  tile.receiveShadow = true;
  board.add(tile);
}
for (let q = -3; q <= 3; q += 1) {
  const rMin = Math.max(-3, -q - 3);
  const rMax = Math.min(3, -q + 3);
  for (let r = rMin; r <= rMax; r += 1) addTile(q, r);
}

const jumpCells = {
  start: axialToWorld(-2, 1),
  first: axialToWorld(-1, 0),
  second: axialToWorld(0, 0),
};
const enemyCell = axialToWorld(2, -1);
const itemCell = axialToWorld(2, 0);

function faceToward(mount, target) {
  const direction = target.clone().sub(mount.position).setY(0);
  mount.rotation.y = Math.atan2(direction.x, direction.z);
}

const heroMount = new THREE.Group();
heroMount.name = 'ReviewHeroCellMount';
heroMount.position.copy(jumpCells.start);
heroMount.position.y = 0.15;
faceToward(heroMount, jumpCells.first);
scene.add(heroMount);
const hero = createPenguin();
hero.scale.multiplyScalar(0.88);
hero.userData.healthBar.visible = false;
heroMount.add(hero);

const enemyMount = new THREE.Group();
enemyMount.name = 'ReviewEnemyCellMount';
enemyMount.position.copy(enemyCell);
enemyMount.position.y = 0.15;
faceToward(enemyMount, jumpCells.second);
scene.add(enemyMount);
const enemy = createSlime();
enemy.scale.multiplyScalar(0.92);
enemy.userData.healthBar.visible = false;
enemyMount.add(enemy);

function createGoldBag() {
  const group = new THREE.Group();
  group.name = 'ReviewDartPickupTarget';
  const cloth = new THREE.MeshStandardMaterial({ color: 0xd9992f, roughness: 0.7, metalness: 0.05 });
  const cord = new THREE.MeshStandardMaterial({ color: 0xffdd72, roughness: 0.4, metalness: 0.36 });
  const bag = new THREE.Mesh(new THREE.SphereGeometry(0.28, 18, 12), cloth);
  bag.scale.set(0.9, 1.12, 0.82);
  bag.position.y = 0.31;
  bag.castShadow = true;
  group.add(bag);
  const neck = new THREE.Mesh(new THREE.CylinderGeometry(0.12, 0.16, 0.16, 10), cloth);
  neck.position.y = 0.56;
  neck.castShadow = true;
  group.add(neck);
  const tie = new THREE.Mesh(new THREE.TorusGeometry(0.13, 0.025, 7, 18), cord);
  tie.rotation.x = Math.PI * 0.5;
  tie.position.y = 0.5;
  group.add(tie);
  return group;
}

const itemMount = new THREE.Group();
itemMount.position.copy(itemCell);
itemMount.position.y = 0.14;
const item = createGoldBag();
itemMount.add(item);
scene.add(itemMount);

[hero, enemy].forEach(model => model.traverse(child => {
  if (!child.isMesh) return;
  child.castShadow = true;
  child.receiveShadow = true;
}));

const FORMAL_BATTLE_VIEW_WIDTH = 12.3;
const FORMAL_BATTLE_ZOOM = 1.45;
const camera = new THREE.OrthographicCamera(-4, 4, 3, -3, 0.1, 30);
const cameraTarget = new THREE.Vector3(0, 0.15, 0.25);
function updateCamera() {
  // This is the production battle direction. The review page has no orbit or
  // zoom controls, so the reward is judged only from the actual game view.
  camera.position.copy(cameraTarget).add(new THREE.Vector3(0, 21.85, 11.25));
  camera.zoom = FORMAL_BATTLE_ZOOM;
  camera.lookAt(cameraTarget);
  camera.updateProjectionMatrix();
}
updateCamera();

const trackingDartReward = new TrackingDartRewardCandidate(scene);
const comboPopup = document.getElementById('combo-popup');
const jumpWindows = [
  { start: 0.16, end: 0.72, from: jumpCells.start, to: jumpCells.first },
  { start: 0.9, end: 1.46, from: jumpCells.first, to: jumpCells.second },
];
const rewardStart = 1.58;
const sequenceDuration = 4.28;
let sequenceStart = performance.now() * 0.001 + 0.2;
let jumpActionIndex = 0;
let rewardPlayed = false;
let scenario = 'enemy';
let loopEnabled = true;
let playbackSpeed = 1;
let playing = true;

function setHeroAt(position, lift = 0) {
  heroMount.position.copy(position);
  heroMount.position.y = 0.15 + lift;
}

function startSequence(now = performance.now() * 0.001) {
  trackingDartReward.clear();
  comboPopup.classList.remove('active');
  jumpActionIndex = 0;
  rewardPlayed = false;
  playing = true;
  sequenceStart = now + 0.12;
  hero.userData.action = null;
  enemy.userData.action = null;
  setHeroAt(jumpCells.start);
  faceToward(heroMount, jumpCells.first);
  enemyMount.visible = scenario === 'enemy';
  itemMount.visible = scenario === 'item';
  item.visible = true;
}

function playReward() {
  comboPopup.classList.remove('active');
  void comboPopup.offsetWidth;
  comboPopup.classList.add('active');
  const targetCell = scenario === 'enemy'
    ? enemyCell.clone().add(new THREE.Vector3(0, 0.78, 0))
    : scenario === 'item'
      ? itemCell.clone().add(new THREE.Vector3(0, 0.48, 0))
      : jumpCells.second.clone().add(new THREE.Vector3(1, 0.9, 0));
  const launchDirection = targetCell.clone().sub(jumpCells.second).setY(0).normalize();
  const from = jumpCells.second.clone()
    .addScaledVector(launchDirection, 0.86)
    .add(new THREE.Vector3(0, 1.0, 0));
  const target = scenario === 'heal' ? from.clone() : targetCell;
  trackingDartReward.play({
    from,
    to: target,
    camera,
    mode: scenario,
    onContact: mode => {
      if (mode === 'enemy') enemy.userData.playAction?.('hit', 0.46 / playbackSpeed);
      if (mode === 'item') item.visible = false;
    },
  });
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
    document.querySelectorAll('[data-speed]').forEach(itemButton => itemButton.classList.toggle('active', itemButton === button));
    startSequence();
  });
});
document.querySelectorAll('[data-scenario]').forEach(button => {
  button.addEventListener('click', () => {
    scenario = button.dataset.scenario || 'enemy';
    document.querySelectorAll('[data-scenario]').forEach(itemButton => itemButton.classList.toggle('active', itemButton === button));
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

  while (playing && jumpActionIndex < jumpWindows.length
    && sequenceElapsed >= jumpWindows[jumpActionIndex].start) {
    hero.userData.playAction?.('jump_attack', (jumpWindows[jumpActionIndex].end - jumpWindows[jumpActionIndex].start) / playbackSpeed);
    jumpActionIndex += 1;
  }

  const activeJump = jumpWindows.find(windowInfo => sequenceElapsed >= windowInfo.start && sequenceElapsed < windowInfo.end);
  if (activeJump) {
    const progress = clamp01((sequenceElapsed - activeJump.start) / (activeJump.end - activeJump.start));
    const movement = progress * progress * (3 - 2 * progress);
    setHeroAt(activeJump.from.clone().lerp(activeJump.to, movement), Math.sin(progress * Math.PI) * 0.72);
    faceToward(heroMount, activeJump.to);
  } else if (sequenceElapsed < jumpWindows[0].start) {
    setHeroAt(jumpCells.start);
  } else if (sequenceElapsed < jumpWindows[1].start) {
    setHeroAt(jumpCells.first);
    faceToward(heroMount, jumpCells.second);
  } else {
    setHeroAt(jumpCells.second);
    const target = scenario === 'enemy' ? enemyCell : scenario === 'item' ? itemCell : jumpCells.second.clone().add(new THREE.Vector3(1, 0, 0));
    faceToward(heroMount, target);
  }

  if (playing && !rewardPlayed && sequenceElapsed >= rewardStart) {
    rewardPlayed = true;
    playReward();
  }
  if (playing && sequenceElapsed >= sequenceDuration) {
    playing = false;
    if (loopEnabled) startSequence(now + 0.24);
  }

  hero.userData.animate?.(elapsed, false);
  enemy.userData.animate?.(elapsed, false);
  item.rotation.y += delta * 0.45;
  trackingDartReward.update(delta * playbackSpeed);
  renderer.render(scene, camera);
}
animate();

function clamp01(value) {
  return Math.max(0, Math.min(1, value));
}
