import * as THREE from '../vendor/three.module.js';
import { createPenguin, createSlime } from '../src/game/Units.js';
import { MeleeImpactCandidate } from './MeleeImpactCandidate.js?v=20260821a';
import { DamageNumberCandidate } from './DamageNumberCandidate.js?v=20260821a';
import { HitReactionCandidate } from './HitReactionCandidate.js?v=20260821a';

const effectId = new URLSearchParams(location.search).get('effect') || 'impact';
const canvas = document.getElementById('review-canvas');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: false, powerPreference: 'high-performance' });
renderer.setPixelRatio(Math.min(2, window.devicePixelRatio || 1));
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFShadowMap;
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
    scene.add(tile);
  }
}

const heroCell = effectId === 'hit' ? axialToWorld(0, 0) : axialToWorld(-1, 0);
const enemyCell = effectId === 'hit' ? axialToWorld(2, -1) : axialToWorld(1, 0);
const heroMount = new THREE.Group();
heroMount.position.copy(heroCell);
heroMount.position.y = 0.15;
scene.add(heroMount);
const hero = createPenguin();
hero.scale.multiplyScalar(0.88);
hero.userData.healthBar.visible = false;
heroMount.add(hero);

const enemyMount = new THREE.Group();
enemyMount.position.copy(enemyCell);
enemyMount.position.y = 0.15;
scene.add(enemyMount);
const enemy = createSlime();
enemy.scale.multiplyScalar(0.86);
enemy.userData.healthBar.visible = false;
enemyMount.add(enemy);

function faceToward(mount, target) {
  const direction = target.clone().sub(mount.position).setY(0);
  if (direction.lengthSq() > 0.001) mount.rotation.y = Math.atan2(direction.x, direction.z);
}
faceToward(heroMount, enemyCell);
faceToward(enemyMount, heroCell);

[hero, enemy].forEach(model => model.traverse(child => {
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

const candidate = effectId === 'damage'
  ? new DamageNumberCandidate(scene)
  : effectId === 'hit'
    ? new HitReactionCandidate(scene, hero, heroMount)
    : new MeleeImpactCandidate(scene);

const popup = document.getElementById('combo-popup');
let scenario = document.querySelector('[data-scenario].active')?.dataset.scenario || 'normal';
let playbackSpeed = 1;
let loopEnabled = true;
let sequenceStart = performance.now() * 0.001 + 0.16;
let fired = false;
let playing = true;
const sequenceDuration = effectId === 'hit' ? 2.5 : 2.25;

function reset(now = performance.now() * 0.001) {
  candidate.clear?.();
  heroMount.position.copy(heroCell);
  heroMount.position.y = 0.15;
  enemyMount.position.copy(enemyCell);
  enemyMount.position.y = 0.15;
  faceToward(heroMount, enemyCell);
  faceToward(enemyMount, heroCell);
  hero.userData.action = null;
  enemy.userData.action = null;
  sequenceStart = now + 0.12;
  fired = false;
  playing = true;
  popup.classList.remove('active');
}

function fire() {
  fired = true;
  popup.classList.remove('active');
  void popup.offsetWidth;
  popup.classList.add('active');
  if (effectId === 'impact') {
    hero.userData.playAction?.('jump_attack', 0.56 / playbackSpeed);
    enemy.userData.playAction?.('hit', 0.46 / playbackSpeed);
    const position = enemyCell.clone().add(new THREE.Vector3(0, 0.82, 0));
    candidate.play({ position, direction: position.clone().sub(heroCell), camera });
    if (scenario === 'heavy') {
      setTimeout(() => candidate.play({ position, direction: position.clone().sub(heroCell), camera }), 70 / playbackSpeed);
    }
  } else if (effectId === 'damage') {
    enemy.userData.playAction?.('hit', 0.46 / playbackSpeed);
    candidate.play({ position: enemyCell.clone().add(new THREE.Vector3(0, 1.45, 0)), value: Number(scenario) || 24 });
  } else {
    enemy.userData.playAction?.('attack', 0.48 / playbackSpeed);
    const incoming = heroCell.clone().sub(enemyCell).setY(0);
    if (scenario === 'side') incoming.applyAxisAngle(new THREE.Vector3(0, 1, 0), -0.72);
    candidate.play({ direction: incoming, playbackSpeed });
  }
}

document.getElementById('play-once').addEventListener('click', () => reset());
document.getElementById('toggle-loop').addEventListener('click', event => {
  loopEnabled = !loopEnabled;
  event.currentTarget.classList.toggle('active', loopEnabled);
  event.currentTarget.textContent = loopEnabled ? '循环开启' : '循环关闭';
  if (loopEnabled && !playing) reset();
});
document.querySelectorAll('[data-speed]').forEach(button => {
  button.addEventListener('click', () => {
    playbackSpeed = Number(button.dataset.speed) || 1;
    document.querySelectorAll('[data-speed]').forEach(item => item.classList.toggle('active', item === button));
    reset();
  });
});
document.querySelectorAll('[data-scenario]').forEach(button => {
  button.addEventListener('click', () => {
    scenario = button.dataset.scenario;
    document.querySelectorAll('[data-scenario]').forEach(item => item.classList.toggle('active', item === button));
    reset();
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
reset();
function animate() {
  requestAnimationFrame(animate);
  const delta = Math.min(0.05, clock.getDelta());
  elapsed += delta;
  hero.userData.animate?.(elapsed, false);
  enemy.userData.animate?.(elapsed, false);
  const sequenceElapsed = Math.max(0, (performance.now() * 0.001 - sequenceStart) * playbackSpeed);
  if (playing && !fired && sequenceElapsed >= 0.72) fire();
  candidate.update?.(delta * playbackSpeed);
  if (playing && sequenceElapsed >= sequenceDuration) {
    playing = false;
    if (loopEnabled) reset(performance.now() * 0.001 + 0.22);
  }
  renderer.render(scene, camera);
}
animate();
