import * as THREE from '../vendor/three.module.js';
import { createChapterOneEnemy, createPenguin, createSlime } from '../src/game/Units.js';
import { TimeStopRewardCandidate } from './TimeStopRewardCandidate.js?v=20260822j';

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
scene.background = new THREE.Color(0x061c35);
scene.fog = new THREE.Fog(0x061c35, 21, 39);
scene.add(new THREE.HemisphereLight(0xa5d8ef, 0x121c46, 1.18));
const key = new THREE.DirectionalLight(0xffddb9, 2.35);
key.position.set(-5, 8, 6);
key.castShadow = true;
key.shadow.mapSize.set(1024, 1024);
Object.assign(key.shadow.camera, { left: -7, right: 7, top: 7, bottom: -7, near: 1, far: 24 });
key.shadow.bias = -0.001;
key.shadow.normalBias = 0.05;
scene.add(key);
const timeRim = new THREE.DirectionalLight(0x58bfff, 1.45);
timeRim.position.set(6, 5, -5);
scene.add(timeRim);
const timeFill = new THREE.DirectionalLight(0x8edfff, 0.55);
timeFill.position.set(-5, 3, -4);
scene.add(timeFill);

const floor = new THREE.Mesh(
  new THREE.CircleGeometry(8.2, 56),
  new THREE.MeshStandardMaterial({ color: 0x071a30, roughness: 0.94, metalness: 0 })
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
board.name = 'TimeStopReviewBoard';
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
    frozen: false, kind: 'minion', active: false,
  };
}

const jumpCells = {
  start: axialToWorld(-2, 0),
  first: axialToWorld(-2, 2),
  second: axialToWorld(0, 2),
  third: axialToWorld(2, 0),
  fourth: axialToWorld(2, -2),
  fifth: axialToWorld(0, -2),
  sixth: axialToWorld(0, 0),
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
  entry.frozen = false;
  entry.mount.position.copy(entry.basePosition);
  entry.mount.rotation.set(0, 0, 0);
  entry.model.scale.copy(entry.baseScale);
  entry.model.userData.action = null;
}

function placeActor(entry, q, r) {
  entry.mount.visible = true;
  entry.active = true;
  entry.frozen = false;
  entry.mount.position.copy(axialToWorld(q, r));
  entry.mount.position.y = 0.15;
  entry.basePosition.copy(entry.mount.position);
  faceToward(entry.mount, jumpCells.sixth);
  return { entry, kind: entry.kind };
}

let scenario = 'all';
let activeTargets = [];
function configureScenario() {
  Object.values(actors).forEach(hideActor);
  if (scenario === 'boss') {
    activeTargets = [
      placeActor(actors.boss, 0, 2),
      placeActor(actors.slime, -2, 2),
      placeActor(actors.jellyfish, 3, -2),
    ];
    return;
  }
  if (scenario === 'turns') {
    activeTargets = [
      placeActor(actors.eel, -2, 1),
      placeActor(actors.ray, 2, -1),
      placeActor(actors.jellyfish, 0, 2),
      placeActor(actors.crab, 0, -2),
    ];
    return;
  }
  activeTargets = [
    placeActor(actors.slime, -2, 2),
    placeActor(actors.jellyfish, 2, -2),
    placeActor(actors.turtle, -2, 0),
    placeActor(actors.shark, 1, 2),
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

const reward = new TimeStopRewardCandidate(scene, camera);
const comboPopup = document.getElementById('combo-popup');
const jumpWindows = [
  { start: 0.1, end: 0.38, from: jumpCells.start, to: jumpCells.first },
  { start: 0.49, end: 0.77, from: jumpCells.first, to: jumpCells.second },
  { start: 0.88, end: 1.16, from: jumpCells.second, to: jumpCells.third },
  { start: 1.27, end: 1.55, from: jumpCells.third, to: jumpCells.fourth },
  { start: 1.66, end: 1.94, from: jumpCells.fourth, to: jumpCells.fifth },
  { start: 2.05, end: 2.33, from: jumpCells.fifth, to: jumpCells.sixth },
];
const rewardCastStart = 2.34;
const rewardStart = 2.58;
const rewardCastDuration = 1.05;
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

function applyTimeStopCastPose(model, progress) {
  const joints = model.userData.joints;
  if (!joints) return;
  const gather = THREE.MathUtils.smoothstep(progress, 0, 0.16);
  const open = THREE.MathUtils.smoothstep(progress, 0.17, 0.29);
  const recover = THREE.MathUtils.smoothstep(progress, 0.76, 1);
  const closedPose = gather * (1 - open) * (1 - recover);
  const stopPose = open * (1 - recover);

  // Time-stop gets a large, unique silhouette. The penguin crouches and
  // crosses the sword and free flipper tightly over its chest, then snaps
  // both arms wide into a sustained halt pose exactly as the field expands.
  // There is no raised blade, ground stab, forward slash or energy-pull pose.
  joints.hitBodyPivot.position.y -= closedPose * 0.125 + stopPose * 0.04;
  joints.hitBodyPivot.position.z -= closedPose * 0.075;
  joints.hitBodyPivot.position.z += stopPose * 0.09;
  joints.hitBodyPivot.rotation.x = closedPose * 0.16 - stopPose * 0.12;
  joints.hitBodyPivot.rotation.y = -closedPose * 0.14 + stopPose * 0.08;
  joints.head.rotation.x += closedPose * 0.27 - stopPose * 0.11;
  joints.head.rotation.y -= closedPose * 0.17;

  joints.leftShoulder.rotation.x = -closedPose * 0.88 - stopPose * 0.38;
  joints.leftShoulder.rotation.y = closedPose * 0.24 + stopPose * 0.12;
  joints.leftShoulder.rotation.z = closedPose * 1.24 - stopPose * 1.45;

  joints.rightShoulder.rotation.x = -closedPose * 0.38 - stopPose * 0.27;
  joints.rightShoulder.rotation.y = closedPose * 0.17 - stopPose * 0.09;
  joints.rightShoulder.rotation.z = -closedPose * 0.9 + stopPose * 1.12;
  joints.rightHand.rotation.x = -closedPose * 0.22 + stopPose * 0.12;
  joints.rightHand.rotation.z = closedPose * 0.32 - stopPose * 0.12;
  joints.sword.rotation.x = -closedPose * 0.28 + stopPose * 0.12;
  joints.sword.rotation.z = -0.69 - closedPose * 0.72 + stopPose * 0.42;

  joints.leftAnkle.position.x -= stopPose * 0.055;
  joints.rightAnkle.position.x += stopPose * 0.055;
  joints.leftAnkle.rotation.z = -stopPose * 0.1;
  joints.rightAnkle.rotation.z = stopPose * 0.1;
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
  activeTargets.forEach(({ entry }, index) => {
    entry.model.userData.playAction?.('attack', 1.12 + index * 0.06);
  });
  reward.play({ origin: jumpCells.sixth, targets: activeTargets });
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
    scenario = button.dataset.scenario || 'all';
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
    setHeroAt(activeJump.from.clone().lerp(activeJump.to, easeOutCubic(local)), Math.sin(local * Math.PI) * 0.76);
  } else if (sequenceElapsed < jumpWindows[0].start) setHeroAt(jumpCells.start);
  else if (sequenceElapsed < jumpWindows[1].start) setHeroAt(jumpCells.first);
  else if (sequenceElapsed < jumpWindows[2].start) setHeroAt(jumpCells.second);
  else if (sequenceElapsed < jumpWindows[3].start) setHeroAt(jumpCells.third);
  else if (sequenceElapsed < jumpWindows[4].start) setHeroAt(jumpCells.fourth);
  else if (sequenceElapsed < jumpWindows[5].start) setHeroAt(jumpCells.fifth);
  else setHeroAt(jumpCells.sixth);

  if (playing && !rewardCastPlayed && sequenceElapsed >= rewardCastStart) {
    rewardCastPlayed = true;
    heroEntry.model.userData.action = null;
  }
  if (playing && !rewardPlayed && sequenceElapsed >= rewardStart) {
    rewardPlayed = true;
    playReward();
  }
  if (rewardPlayed) reward.update(delta * playbackSpeed);

  heroEntry.model.userData.animate?.(elapsed);
  if (rewardCastPlayed) {
    const castProgress = clamp01((sequenceElapsed - rewardCastStart) / rewardCastDuration);
    if (castProgress < 1) applyTimeStopCastPose(heroEntry.model, castProgress);
  }
  Object.values(actors).forEach(entry => {
    if (entry.active && !entry.frozen) entry.model.userData.animate?.(elapsed);
  });

  const sequenceDuration = rewardStart + reward.duration + 0.72;
  if (playing && sequenceElapsed >= sequenceDuration) {
    playing = false;
    if (loopEnabled) startSequence(now + 0.34);
  }
  renderer.render(scene, camera);
}
animate();
