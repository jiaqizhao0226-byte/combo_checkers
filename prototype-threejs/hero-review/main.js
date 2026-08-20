import * as THREE from '../vendor/three.module.js';
import { createPenguin } from '../src/game/Units.js';
import { createPenguinCandidate } from './PenguinCandidate.js?v=20260820j';

const canvas = document.getElementById('review-canvas');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true, powerPreference: 'high-performance' });
renderer.setPixelRatio(Math.min(2, window.devicePixelRatio || 1));
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.2;

const scene = new THREE.Scene();
scene.fog = new THREE.Fog(0x07191b, 9, 18);
scene.add(new THREE.HemisphereLight(0xb8dfe0, 0x17392f, 1.25));
const key = new THREE.DirectionalLight(0xffd9a8, 3.2);
key.position.set(-4, 7, 5);
key.castShadow = true;
key.shadow.mapSize.set(1024, 1024);
key.shadow.bias = -0.001;
key.shadow.normalBias = 0.05;
scene.add(key);
const rim = new THREE.DirectionalLight(0x59bde0, 1.3);
rim.position.set(5, 4, -4);
scene.add(rim);
const faceFill = new THREE.PointLight(0xffbb73, 0.65, 8);
faceFill.position.set(0, 2.3, 4.5);
scene.add(faceFill);

const floor = new THREE.Mesh(
  new THREE.CircleGeometry(7, 56),
  new THREE.MeshStandardMaterial({ color: 0x0b2c2b, roughness: 0.92, metalness: 0 })
);
floor.rotation.x = -Math.PI * 0.5;
floor.position.y = -0.04;
floor.receiveShadow = true;
scene.add(floor);

function makePad(x, accent) {
  const group = new THREE.Group();
  const base = new THREE.Mesh(
    new THREE.CylinderGeometry(1.05, 1.12, 0.18, 12),
    new THREE.MeshStandardMaterial({ color: 0x123d3d, roughness: 0.72 })
  );
  base.receiveShadow = true;
  base.castShadow = true;
  const ring = new THREE.Mesh(
    new THREE.RingGeometry(0.77, 0.92, 24),
    new THREE.MeshBasicMaterial({ color: accent, transparent: true, opacity: 0.24, side: THREE.DoubleSide, depthWrite: false })
  );
  ring.rotation.x = -Math.PI * 0.5;
  ring.position.y = 0.095;
  group.position.set(x, 0.05, 0);
  group.add(base, ring);
  scene.add(group);
  return ring;
}

const oldRing = makePad(-1.22, 0x738c86);
const newRing = makePad(1.22, 0x4ee4bd);
const oldMount = new THREE.Group();
const newMount = new THREE.Group();
oldMount.position.set(-1.22, 0.14, 0);
newMount.position.set(1.22, 0.14, 0);
scene.add(oldMount, newMount);

const oldHero = createPenguin();
oldHero.userData.healthBar.visible = false;
oldHero.scale.multiplyScalar(0.87);
const newHero = createPenguinCandidate();
newHero.scale.multiplyScalar(0.9);
oldMount.add(oldHero);
newMount.add(newHero);

[oldHero, newHero].forEach(model => model.traverse(child => {
  if (!child.isMesh) return;
  child.castShadow = true;
  child.receiveShadow = true;
}));

const camera = new THREE.OrthographicCamera(-4, 4, 3, -3, 0.1, 30);
const target = new THREE.Vector3(0, 0.82, 0);
let cameraYaw = 0;
let cameraPitch = 0.24;
let cameraDistance = 8;
let cameraZoom = 1;

function updateCamera() {
  const horizontal = Math.cos(cameraPitch) * cameraDistance;
  camera.position.set(
    Math.sin(cameraYaw) * horizontal,
    Math.sin(cameraPitch) * cameraDistance + target.y,
    Math.cos(cameraYaw) * horizontal
  );
  camera.zoom = cameraZoom;
  camera.lookAt(target);
  camera.updateProjectionMatrix();
}

const VIEWS = {
  game: { yaw: 0, pitch: 0.92, zoom: 1.02 },
  front: { yaw: 0, pitch: 0.24, zoom: 1.08 },
  threequarter: { yaw: Math.PI * 0.24, pitch: 0.34, zoom: 1.06 },
  side: { yaw: Math.PI * 0.5, pitch: 0.24, zoom: 1.08 },
  back: { yaw: Math.PI, pitch: 0.24, zoom: 1.08 },
};

document.querySelector('.camera-controls').addEventListener('click', event => {
  const button = event.target.closest('[data-view]');
  if (!button) return;
  const view = VIEWS[button.dataset.view];
  cameraYaw = view.yaw;
  cameraPitch = view.pitch;
  cameraZoom = view.zoom;
  updateCamera();
  document.querySelectorAll('[data-view]').forEach(item => item.classList.toggle('active', item === button));
});

let motion = 'idle';
let motionStartedAt = 0;
let nextActionAt = 0;
let attackPreviewActive = false;
const attackProgress = document.getElementById('attack-progress');
const attackProgressLabel = document.getElementById('attack-progress-label');
const attackScrubber = document.getElementById('attack-scrubber');

function playMotionAction(time) {
  if (motion === 'move') {
    oldHero.userData.playAction?.('move', 0.72);
    newHero.userData.playAction?.('move', 0.72);
    nextActionAt = time + 1.05;
  } else if (motion === 'attack') {
    oldHero.userData.playAction?.('jump_attack', 0.92);
    newHero.userData.playAction?.('jump_attack', 0.92);
    nextActionAt = time + 1.45;
  } else if (motion === 'hit') {
    oldHero.userData.playAction?.('hit', 0.55);
    newHero.userData.playAction?.('hit', 0.55);
    nextActionAt = time + 1.05;
  }
}

function setMotion(nextMotion) {
  attackPreviewActive = false;
  motion = nextMotion;
  motionStartedAt = performance.now() * 0.001;
  nextActionAt = 0;
  oldHero.userData.action = null;
  newHero.userData.action = null;
  document.querySelectorAll('[data-motion]').forEach(button => {
    const active = button.dataset.motion === motion;
    button.classList.toggle('active', active);
    button.setAttribute('aria-pressed', String(active));
  });
  attackScrubber.classList.toggle('active', motion === 'attack');
}

function setAttackPreview(percent) {
  const clampedPercent = THREE.MathUtils.clamp(Number(percent) || 0, 0, 100);
  const progress = clampedPercent / 100;
  attackPreviewActive = true;
  motion = 'attack';
  nextActionAt = Number.POSITIVE_INFINITY;
  oldHero.userData.action = null;
  newHero.userData.previewAction?.('jump_attack', progress);
  attackProgress.value = String(clampedPercent);
  attackProgressLabel.value = `${Math.round(clampedPercent)}%`;
  attackScrubber.classList.add('active');
  document.querySelectorAll('[data-motion]').forEach(button => {
    const active = button.dataset.motion === 'attack';
    button.classList.toggle('active', active);
    button.setAttribute('aria-pressed', String(active));
  });
  document.querySelectorAll('[data-attack-frame]').forEach(button => {
    button.classList.toggle('active', Number(button.dataset.attackFrame) === clampedPercent);
  });
}

attackProgress.addEventListener('input', event => {
  setAttackPreview(event.target.value);
});

document.querySelectorAll('[data-attack-frame]').forEach(button => {
  button.addEventListener('click', () => setAttackPreview(button.dataset.attackFrame));
});

document.addEventListener('click', event => {
  const button = event.target.closest('[data-motion]');
  if (button) setMotion(button.dataset.motion);
});

document.getElementById('display-scale').addEventListener('change', event => {
  const scale = Number(event.target.value) || 1;
  oldHero.scale.setScalar(0.87 * scale);
  newHero.scale.setScalar(0.9 * scale);
});

let dragging = false;
let pointerX = 0;
let pointerY = 0;
canvas.addEventListener('pointerdown', event => {
  dragging = true;
  pointerX = event.clientX;
  pointerY = event.clientY;
  canvas.setPointerCapture(event.pointerId);
});
canvas.addEventListener('pointermove', event => {
  if (!dragging) return;
  cameraYaw -= (event.clientX - pointerX) * 0.008;
  cameraPitch = THREE.MathUtils.clamp(cameraPitch + (event.clientY - pointerY) * 0.006, 0.14, 1.35);
  pointerX = event.clientX;
  pointerY = event.clientY;
  updateCamera();
  document.querySelectorAll('[data-view]').forEach(button => button.classList.remove('active'));
});
canvas.addEventListener('pointerup', () => { dragging = false; });
canvas.addEventListener('pointercancel', () => { dragging = false; });
canvas.addEventListener('wheel', event => {
  event.preventDefault();
  cameraZoom = THREE.MathUtils.clamp(cameraZoom * Math.exp(-event.deltaY * 0.0012), 0.72, 1.75);
  updateCamera();
}, { passive: false });

function resize() {
  const width = Math.max(1, canvas.clientWidth);
  const height = Math.max(1, canvas.clientHeight);
  renderer.setSize(width, height, false);
  const viewHeight = 5.2;
  const aspect = width / height;
  camera.left = -viewHeight * aspect * 0.5;
  camera.right = viewHeight * aspect * 0.5;
  camera.top = viewHeight * 0.5;
  camera.bottom = -viewHeight * 0.5;
  camera.updateProjectionMatrix();
}

new ResizeObserver(resize).observe(canvas);

function frame() {
  const time = performance.now() * 0.001;
  const localTime = time - motionStartedAt;
  oldMount.rotation.set(0, 0, 0);
  newMount.rotation.set(0, 0, 0);
  if (motion === 'turntable') {
    oldMount.rotation.y = localTime * 0.72;
    newMount.rotation.y = localTime * 0.72;
  } else if (!attackPreviewActive && motion !== 'idle' && time >= nextActionAt) {
    playMotionAction(time);
  }
  oldHero.userData.animate?.(time, motion === 'move');
  newHero.userData.animate?.(time, motion === 'move');
  oldRing.material.opacity = 0.16 + (Math.sin(time * 2) + 1) * 0.035;
  newRing.material.opacity = 0.25 + (Math.sin(time * 2.4) + 1) * 0.05;
  renderer.render(scene, camera);
  requestAnimationFrame(frame);
}

updateCamera();
resize();
setMotion('idle');
frame();
