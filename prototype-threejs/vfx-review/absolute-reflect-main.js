import * as THREE from '../vendor/three.module.js';
import { createChapterOneEnemy, createPenguin, createSlime } from '../src/game/Units.js';
import { AbsoluteReflectRewardCandidate } from './AbsoluteReflectRewardCandidate.js?v=20260824i';

const clamp01 = value => Math.max(0, Math.min(1, value));
const easeOutCubic = value => 1 - Math.pow(1 - clamp01(value), 3);
const canvas = document.getElementById('review-canvas');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: false, powerPreference: 'high-performance' });
renderer.setPixelRatio(Math.min(2, window.devicePixelRatio || 1));
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFShadowMap;
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.1;

const scene = new THREE.Scene();
scene.background = new THREE.Color(0x07182e);
scene.fog = new THREE.Fog(0x07182e, 21, 39);
scene.add(new THREE.HemisphereLight(0xa6d9ee, 0x111934, 1.18));
const key = new THREE.DirectionalLight(0xffddb9, 2.38);
key.position.set(-5, 8, 6);
key.castShadow = true;
key.shadow.mapSize.set(1024, 1024);
Object.assign(key.shadow.camera, { left: -7, right: 7, top: 7, bottom: -7, near: 1, far: 24 });
key.shadow.bias = -0.001;
key.shadow.normalBias = 0.05;
scene.add(key);
const reflectRim = new THREE.DirectionalLight(0xffd76a, 1.38);
reflectRim.position.set(6, 5, -5);
scene.add(reflectRim);
const goldenFill = new THREE.DirectionalLight(0xffa53d, 0.62);
goldenFill.position.set(-4, 3, -5);
scene.add(goldenFill);

const floor = new THREE.Mesh(
  new THREE.CircleGeometry(8.2, 56),
  new THREE.MeshStandardMaterial({ color: 0x07192d, roughness: 0.95, metalness: 0 })
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
board.name = 'AbsoluteReflectReviewBoard';
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
    mount, model, basePosition: mount.position.clone(), baseScale: model.scale.clone(),
    active: false, kind: 'minion', damage: 0,
  };
}

const jumpCells = {
  start: axialToWorld(-2, 0),
  first: axialToWorld(-2, 2),
  second: axialToWorld(0, 2),
  third: axialToWorld(2, 0),
  fourth: axialToWorld(2, -2),
  fifth: axialToWorld(0, -2),
  sixth: axialToWorld(-2, 0),
  seventh: axialToWorld(0, -2),
  eighth: axialToWorld(0, 0),
};

const heroEntry = createActor(createPenguin(), 0.88);
const actors = {
  slime: createActor(createSlime(), 0.84),
  jellyfish: createActor(createChapterOneEnemy('jellyfish'), 0.58),
  turtle: createActor(createChapterOneEnemy('iron_turtle'), 0.52),
  shark: createActor(createChapterOneEnemy('ghost_shark'), 0.5),
  eel: createActor(createChapterOneEnemy('vortex_eel'), 0.58),
  ray: createActor(createChapterOneEnemy('electric_ray'), 0.56),
  crab: createActor(createChapterOneEnemy('hermit_crab'), 0.56),
  boss: createActor(createChapterOneEnemy('abyss_kraken'), 0.46),
};
actors.boss.kind = 'boss';

function hideActor(entry) {
  entry.mount.visible = false;
  entry.active = false;
  entry.mount.position.copy(entry.basePosition);
  entry.mount.rotation.set(0, 0, 0);
  entry.model.scale.copy(entry.baseScale);
  entry.model.userData.action = null;
}

function placeActor(entry, q, r, damage) {
  entry.mount.visible = true;
  entry.active = true;
  entry.damage = damage;
  entry.mount.position.copy(axialToWorld(q, r));
  entry.mount.position.y = 0.15;
  entry.basePosition.copy(entry.mount.position);
  return { entry, kind: entry.kind, damage };
}

let scenario = 'volley';
let activeTargets = [];
function configureScenario() {
  Object.values(actors).forEach(hideActor);
  if (scenario === 'boss') {
    activeTargets = [
      placeActor(actors.boss, 0, 3, 120),
      placeActor(actors.slime, -3, 1, 32),
      placeActor(actors.ray, 3, -2, 44),
    ];
    return;
  }
  if (scenario === 'pressure') {
    activeTargets = [
      placeActor(actors.eel, -3, 1, 48),
      placeActor(actors.shark, 1, 2, 64),
      placeActor(actors.crab, 2, -3, 38),
      placeActor(actors.jellyfish, -1, -2, 42),
    ];
    return;
  }
  activeTargets = [
    placeActor(actors.slime, -3, 1, 36),
    placeActor(actors.jellyfish, 0, 3, 44),
    placeActor(actors.turtle, 3, -1, 52),
  ];
}

const FORMAL_BATTLE_VIEW_WIDTH = 12.3;
const FORMAL_BATTLE_ZOOM = 1.45;
const camera = new THREE.OrthographicCamera(-4, 4, 3, -3, 0.1, 30);
const cameraTarget = new THREE.Vector3(0, 0.15, 0.25);
camera.position.copy(cameraTarget).add(new THREE.Vector3(0, 21.85, 11.25));
camera.zoom = FORMAL_BATTLE_ZOOM;
camera.lookAt(cameraTarget);
camera.updateProjectionMatrix();

const reward = new AbsoluteReflectRewardCandidate(scene, camera);
const comboPopup = document.getElementById('combo-popup');
const jumpWindows = [
  { start: 0.08, end: 0.34, from: jumpCells.start, to: jumpCells.first },
  { start: 0.43, end: 0.69, from: jumpCells.first, to: jumpCells.second },
  { start: 0.78, end: 1.04, from: jumpCells.second, to: jumpCells.third },
  { start: 1.13, end: 1.39, from: jumpCells.third, to: jumpCells.fourth },
  { start: 1.48, end: 1.74, from: jumpCells.fourth, to: jumpCells.fifth },
  { start: 1.83, end: 2.09, from: jumpCells.fifth, to: jumpCells.sixth },
  { start: 2.18, end: 2.44, from: jumpCells.sixth, to: jumpCells.seventh },
  { start: 2.53, end: 2.79, from: jumpCells.seventh, to: jumpCells.eighth },
];
const rewardCastStart = 2.86;
const rewardStart = 3.2;
const rewardCastDuration = 6.75;
let sequenceStart = performance.now() * 0.001 + 0.2;
let jumpActionIndex = 0;
let rewardCastPlayed = false;
let rewardPlayed = false;
let loopEnabled = true;
let playbackSpeed = 1;
let playing = true;
let transitionFrameGapMax = 0;
let transitionUpdateCostMax = 0;
let transitionRenderCostMax = 0;
let lastFrameSample = performance.now();

function setHeroAt(position, lift = 0) {
  heroEntry.mount.position.copy(position);
  heroEntry.mount.position.y = 0.15 + lift;
}

function applyAbsoluteReflectGuardPose(model, progress) {
  const joints = model.userData.joints;
  if (!joints) return;
  const plant = THREE.MathUtils.smoothstep(progress, 0, 0.13);
  const lock = THREE.MathUtils.smoothstep(progress, 0.1, 0.2);
  const release = THREE.MathUtils.smoothstep(progress, 0.82, 1);
  const guardPose = plant * lock * (1 - release);
  const contactBrace = Math.pow(Math.max(0, Math.sin(progress * Math.PI * 7)), 12) * guardPose;

  // Absolute reflect uses a defensive silhouette distinct from every spell:
  // both arms stay outside the torso silhouette, with the free flipper braced
  // forward-left and the sword arm opened to the right. The blade remains
  // diagonally visible beside the body instead of disappearing across it.
  joints.hitBodyPivot.position.y -= guardPose * 0.105;
  joints.hitBodyPivot.position.z += guardPose * 0.085 - contactBrace * 0.045;
  joints.hitBodyPivot.rotation.x = -guardPose * 0.1 + contactBrace * 0.11;
  joints.hitBodyPivot.rotation.y = guardPose * 0.12;
  joints.head.rotation.x -= guardPose * 0.12;
  joints.head.rotation.y += guardPose * 0.08;

  joints.leftShoulder.position.x -= guardPose * 0.06;
  joints.leftShoulder.position.z += guardPose * 0.08;
  joints.leftShoulder.rotation.x = -guardPose * 0.34 - contactBrace * 0.1;
  joints.leftShoulder.rotation.y = -guardPose * 0.16;
  joints.leftShoulder.rotation.z = -guardPose * 0.58 - contactBrace * 0.08;

  joints.rightShoulder.position.x += guardPose * 0.06;
  joints.rightShoulder.position.z += guardPose * 0.08;
  joints.rightShoulder.rotation.x = -guardPose * 0.3 - contactBrace * 0.08;
  joints.rightShoulder.rotation.y = guardPose * 0.18;
  joints.rightShoulder.rotation.z = guardPose * 0.46 + contactBrace * 0.1;
  joints.rightHand.rotation.x = -guardPose * 0.12;
  joints.rightHand.rotation.y = -guardPose * 0.12;
  joints.rightHand.rotation.z = -guardPose * 0.05;
  joints.sword.rotation.x = -guardPose * 0.22;
  joints.sword.rotation.y = guardPose * 0.12;
  joints.sword.rotation.z = -0.69 - guardPose * 0.72;

  joints.leftAnkle.position.x -= guardPose * 0.055;
  joints.rightAnkle.position.x += guardPose * 0.055;
  joints.leftAnkle.rotation.z = -guardPose * 0.08;
  joints.rightAnkle.rotation.z = guardPose * 0.08;
}

function startSequence(now = performance.now() * 0.001) {
  comboPopup.classList.remove('active');
  reward.clear();
  configureScenario();
  setHeroAt(jumpCells.eighth);
  reward.prepare({ hero: heroEntry, targets: activeTargets });
  reward.warmup(renderer);
  jumpActionIndex = 0;
  rewardCastPlayed = false;
  rewardPlayed = false;
  playing = true;
  sequenceStart = Math.max(now, performance.now() * 0.001) + 0.12;
  transitionFrameGapMax = 0;
  transitionUpdateCostMax = 0;
  transitionRenderCostMax = 0;
  lastFrameSample = performance.now();
  document.documentElement.dataset.reflectTransitionMaxFrameGap = '0.0';
  document.documentElement.dataset.reflectTransitionUpdateCost = '0.0';
  document.documentElement.dataset.reflectTransitionRenderCost = '0.0';
  heroEntry.model.userData.action = null;
  setHeroAt(jumpCells.start);
  faceToward(heroEntry.mount, jumpCells.first);
}

function showRewardPopup() {
  comboPopup.classList.remove('active');
  void comboPopup.offsetWidth;
  comboPopup.classList.add('active');
}

function playReward() {
  if (!reward.activate()) reward.play({ hero: heroEntry, targets: activeTargets });
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
    scenario = button.dataset.scenario || 'volley';
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
  const frameSample = performance.now();
  const frameGap = frameSample - lastFrameSample;
  lastFrameSample = frameSample;
  if (sequenceElapsed >= 2.7 && sequenceElapsed <= rewardStart + reward.duration) {
    transitionFrameGapMax = Math.max(transitionFrameGapMax, frameGap);
    document.documentElement.dataset.reflectTransitionMaxFrameGap = transitionFrameGapMax.toFixed(1);
  }

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
    setHeroAt(activeJump.from.clone().lerp(activeJump.to, easeOutCubic(local)), Math.sin(local * Math.PI) * 0.76);
  } else if (sequenceElapsed < jumpWindows[0].start) setHeroAt(jumpCells.start);
  else if (sequenceElapsed < jumpWindows[1].start) setHeroAt(jumpCells.first);
  else if (sequenceElapsed < jumpWindows[2].start) setHeroAt(jumpCells.second);
  else if (sequenceElapsed < jumpWindows[3].start) setHeroAt(jumpCells.third);
  else if (sequenceElapsed < jumpWindows[4].start) setHeroAt(jumpCells.fourth);
  else if (sequenceElapsed < jumpWindows[5].start) setHeroAt(jumpCells.fifth);
  else if (sequenceElapsed < jumpWindows[6].start) setHeroAt(jumpCells.sixth);
  else if (sequenceElapsed < jumpWindows[7].start) setHeroAt(jumpCells.seventh);
  else setHeroAt(jumpCells.eighth);

  if (playing && !rewardCastPlayed && sequenceElapsed >= rewardCastStart) {
    rewardCastPlayed = true;
    heroEntry.model.userData.action = null;
    showRewardPopup();
  }
  if (playing && !rewardPlayed && sequenceElapsed >= rewardStart) {
    rewardPlayed = true;
    playReward();
  }
  const updateCostStart = performance.now();
  if (rewardPlayed) reward.update(delta * playbackSpeed);
  transitionUpdateCostMax = Math.max(transitionUpdateCostMax, performance.now() - updateCostStart);

  heroEntry.model.userData.animate?.(elapsed);
  if (rewardCastPlayed) {
    const castProgress = clamp01((sequenceElapsed - rewardCastStart) / rewardCastDuration);
    if (castProgress < 1) applyAbsoluteReflectGuardPose(heroEntry.model, castProgress);
  }
  Object.values(actors).forEach(entry => {
    if (entry.active) entry.model.userData.animate?.(elapsed);
  });

  const sequenceDuration = rewardStart + reward.duration + 0.7;
  if (playing && sequenceElapsed >= sequenceDuration) {
    playing = false;
    if (loopEnabled) startSequence(now + 0.34);
  }
  const renderCostStart = performance.now();
  renderer.render(scene, camera);
  transitionRenderCostMax = Math.max(transitionRenderCostMax, performance.now() - renderCostStart);
  document.documentElement.dataset.reflectTransitionUpdateCost = transitionUpdateCostMax.toFixed(1);
  document.documentElement.dataset.reflectTransitionRenderCost = transitionRenderCostMax.toFixed(1);
}
animate();
