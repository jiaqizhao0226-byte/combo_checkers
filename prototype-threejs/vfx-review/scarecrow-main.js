import * as THREE from '../vendor/three.module.js';
import { createPenguin, createSlime } from '../src/game/Units.js';
import { createScarecrowModelCandidate } from './ScarecrowModelCandidate.js?v=20260821e';
import { ScarecrowRewardCandidate } from './ScarecrowRewardCandidate.js?v=20260822k';

const canvas = document.getElementById('review-canvas');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: false, powerPreference: 'high-performance' });
renderer.setPixelRatio(Math.min(2, window.devicePixelRatio || 1));
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.15;

const scene = new THREE.Scene();
scene.background = new THREE.Color(0x073247);
scene.fog = new THREE.Fog(0x073247, 21, 39);
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
  return new THREE.Vector3(Math.sqrt(3) * radius * (q + r * 0.5), 0.04, 1.5 * radius * r);
}
for (let q = -3; q <= 3; q += 1) {
  const rMin = Math.max(-3, -q - 3);
  const rMax = Math.min(3, -q + 3);
  for (let r = rMin; r <= rMax; r += 1) {
    const tile = new THREE.Mesh(tileGeometry, tileMaterials[Math.abs(q * 3 + r) % tileMaterials.length]);
    tile.position.copy(axialToWorld(q, r));
    tile.castShadow = true;
    tile.receiveShadow = true;
    board.add(tile);
  }
}

const jumpCells = {
  start: axialToWorld(-3, 0),
  first: axialToWorld(-1, 0),
  second: axialToWorld(-1, 2),
  third: axialToWorld(0, 0),
};
const scarecrowCell = axialToWorld(1, 0);
const enemyCells = [axialToWorld(2, -1), axialToWorld(2, 0), axialToWorld(-2, 2)];

function faceToward(mount, target) {
  const direction = target.clone().sub(mount.position).setY(0);
  if (direction.lengthSq() < 0.001) return;
  mount.rotation.y = Math.atan2(direction.x, direction.z);
}

const heroMount = new THREE.Group();
heroMount.name = 'ReviewHeroCellMount';
heroMount.position.copy(jumpCells.start);
heroMount.position.y = 0.15;
scene.add(heroMount);
const hero = createPenguin();
hero.scale.multiplyScalar(0.88);
hero.userData.healthBar.visible = false;
heroMount.add(hero);

const enemyEntries = enemyCells.map((cell, index) => {
  const mount = new THREE.Group();
  mount.name = `ScarecrowReviewEnemyMount${index + 1}`;
  mount.position.copy(cell);
  mount.position.y = 0.15;
  scene.add(mount);
  const model = createSlime();
  model.scale.multiplyScalar(0.86);
  model.userData.healthBar.visible = false;
  mount.add(model);
  faceToward(mount, jumpCells.start);
  return { mount, model, home: mount.position.clone(), homeRotation: mount.rotation.y };
});

const scarecrowMount = new THREE.Group();
scarecrowMount.name = 'ScarecrowReviewCellMount';
scarecrowMount.position.copy(scarecrowCell);
scarecrowMount.position.y = 0.17;
scarecrowMount.userData.baseY = 0.17;
scene.add(scarecrowMount);
const scarecrow = createScarecrowModelCandidate();
scarecrow.userData.healthBar.visible = false;
scarecrowMount.add(scarecrow);

[hero, scarecrow, ...enemyEntries.map(entry => entry.model)].forEach(model => model.traverse(child => {
  if (!child.isMesh) return;
  child.castShadow = true;
  child.receiveShadow = true;
}));

const FORMAL_BATTLE_VIEW_WIDTH = 12.3;
const FORMAL_BATTLE_ZOOM = 1.45;
const camera = new THREE.OrthographicCamera(-4, 4, 3, -3, 0.1, 30);
const cameraTarget = new THREE.Vector3(0, 0.15, 0.25);
camera.position.copy(cameraTarget).add(new THREE.Vector3(0, 21.85, 11.25));
camera.zoom = FORMAL_BATTLE_ZOOM;
camera.lookAt(cameraTarget);
camera.updateProjectionMatrix();

const reward = new ScarecrowRewardCandidate(scene, {
  camera, scarecrowMount, scarecrow, enemyEntries,
});
const comboPopup = document.getElementById('combo-popup');
const jumpWindows = [
  { start: 0.14, end: 0.58, from: jumpCells.start, to: jumpCells.first },
  { start: 0.72, end: 1.16, from: jumpCells.first, to: jumpCells.second },
  { start: 1.3, end: 1.74, from: jumpCells.second, to: jumpCells.third },
];
const rewardStart = 1.88;
let sequenceStart = performance.now() * 0.001 + 0.2;
let jumpActionIndex = 0;
let rewardPlayed = false;
let scenario = 'guard';
let loopEnabled = true;
let playbackSpeed = 1;
let playing = true;

function setHeroAt(position, lift = 0) {
  heroMount.position.copy(position);
  heroMount.position.y = 0.15 + lift;
}

function startSequence(now = performance.now() * 0.001) {
  comboPopup.classList.remove('active');
  jumpActionIndex = 0;
  rewardPlayed = false;
  playing = true;
  sequenceStart = now + 0.12;
  hero.userData.action = null;
  setHeroAt(jumpCells.start);
  faceToward(heroMount, jumpCells.first);
  enemyEntries.forEach(entry => {
    entry.mount.position.copy(entry.home);
    faceToward(entry.mount, jumpCells.start);
    entry.homeRotation = entry.mount.rotation.y;
  });
  reward.reset(scenario);
}

function playReward() {
  comboPopup.classList.remove('active');
  void comboPopup.offsetWidth;
  comboPopup.classList.add('active');
  reward.reset(scenario);
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
    scenario = button.dataset.scenario || 'guard';
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
    faceToward(heroMount, jump.to);
    hero.userData.playAction?.('jump_attack', (jump.end - jump.start) / playbackSpeed);
    jumpActionIndex += 1;
  }

  let activeJump = null;
  for (const jump of jumpWindows) {
    if (sequenceElapsed >= jump.start && sequenceElapsed <= jump.end) activeJump = jump;
  }
  if (activeJump) {
    const local = Math.max(0, Math.min(1, (sequenceElapsed - activeJump.start) / (activeJump.end - activeJump.start)));
    const eased = 1 - Math.pow(1 - local, 3);
    const position = activeJump.from.clone().lerp(activeJump.to, eased);
    setHeroAt(position, Math.sin(local * Math.PI) * 0.82);
  } else if (sequenceElapsed < jumpWindows[0].start) setHeroAt(jumpCells.start);
  else if (sequenceElapsed < jumpWindows[1].start) setHeroAt(jumpCells.first);
  else if (sequenceElapsed < jumpWindows[2].start) setHeroAt(jumpCells.second);
  else setHeroAt(jumpCells.third);

  if (playing && !rewardPlayed && sequenceElapsed >= rewardStart) {
    rewardPlayed = true;
    playReward();
  }
  if (rewardPlayed) reward.update(delta * playbackSpeed);

  const sequenceDuration = rewardStart + reward.duration() + 0.55;
  if (playing && sequenceElapsed >= sequenceDuration) {
    playing = false;
    if (loopEnabled) startSequence(now + 0.34);
  }

  hero.userData.animate?.(elapsed);
  enemyEntries.forEach(entry => entry.model.userData.animate?.(elapsed));
  renderer.render(scene, camera);
}
animate();
