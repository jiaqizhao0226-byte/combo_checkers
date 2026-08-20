import * as THREE from '../vendor/three.module.js';
import { createChapterOneEnemy, createPenguin } from '../src/game/Units.js';
import { ENEMY_TEMPLATES } from '../src/core/ChapterOneData.js';
import { createSlimeCandidate } from './SlimeCandidate.js?v=20260820e';
import { createEnemyCandidate } from './EnemyCandidates.js?v=20260820h';

const ENEMIES = [
  { id: 'slime', stage: '1-1', role: '近战基础单位', desc: '近距离移动并攻击企鹅。' },
  { id: 'jellyfish', stage: '1-2', role: '反击型单位', desc: '跳过它会触发电击反伤。' },
  { id: 'iron_turtle', stage: '1-2', role: '高耐久单位', desc: '高生命与防御，承担棋盘阻挡。' },
  { id: 'archerfish', stage: '1-3', role: '远程游击单位', desc: '远程攻击，企鹅靠近时会后退。' },
  { id: 'vortex_eel', stage: '1-4', role: '扰乱型单位', desc: '死亡时打乱周围棋子的位置。' },
  { id: 'electric_ray', stage: '1-6', role: '范围攻击单位', desc: '攻击会波及目标周围的单位。' },
  { id: 'hermit_crab', stage: '1-7', role: '防御切换单位', desc: '进入缩壳状态后获得伤害减免。' },
  { id: 'ghost_shark', stage: '1-7', role: '瞬移突袭单位', desc: '会瞬移到随机位置接近目标。' },
];

const canvas = document.getElementById('review-canvas');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true, powerPreference: 'high-performance' });
renderer.setPixelRatio(Math.min(2, window.devicePixelRatio || 1));
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.08;
renderer.outputColorSpace = THREE.SRGBColorSpace;

const scene = new THREE.Scene();
scene.fog = new THREE.Fog(0x0b272a, 10, 19);
scene.add(new THREE.HemisphereLight(0xb5d8e1, 0x274639, 1.28));

const keyLight = new THREE.DirectionalLight(0xffd6a0, 2.55);
keyLight.position.set(-4.5, 8, 5.5);
keyLight.castShadow = true;
keyLight.shadow.mapSize.set(1024, 1024);
Object.assign(keyLight.shadow.camera, { left: -7, right: 7, top: 7, bottom: -7, near: 1, far: 22 });
keyLight.shadow.bias = -0.001;
keyLight.shadow.normalBias = 0.055;
scene.add(keyLight);

const rimLight = new THREE.DirectionalLight(0x66b9dc, 0.72);
rimLight.position.set(5, 5, -5);
scene.add(rimLight);

const camera = new THREE.OrthographicCamera(-4, 4, 3, -3, 0.1, 40);
const target = new THREE.Vector3(0, 0.62, 0);
let cameraYaw = 0;
let cameraPitch = 0.92;
let cameraDistance = 8.2;
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

const floor = new THREE.Mesh(
  new THREE.CircleGeometry(6.8, 48),
  new THREE.MeshStandardMaterial({ color: 0x0b2c2b, roughness: 0.94, metalness: 0 })
);
floor.rotation.x = -Math.PI * 0.5;
floor.position.y = -0.04;
floor.receiveShadow = true;
scene.add(floor);

const board = new THREE.Group();
scene.add(board);
const tileGeometry = new THREE.CylinderGeometry(0.78, 0.81, 0.18, 6);
const tileMaterials = [
  new THREE.MeshStandardMaterial({ color: 0x164a4e, roughness: 0.72 }),
  new THREE.MeshStandardMaterial({ color: 0x1c5b58, roughness: 0.68 }),
  new THREE.MeshStandardMaterial({ color: 0x123d43, roughness: 0.78 }),
];

function axialToWorld(q, r) {
  const radius = 0.82;
  return new THREE.Vector3(Math.sqrt(3) * radius * (q + r * 0.5), 0.06, 1.5 * radius * r);
}

for (let q = -2; q <= 2; q += 1) {
  const rMin = Math.max(-2, -q - 2);
  const rMax = Math.min(2, -q + 2);
  for (let r = rMin; r <= rMax; r += 1) {
    const tile = new THREE.Mesh(tileGeometry, tileMaterials[Math.abs(q * 2 + r) % tileMaterials.length]);
    tile.position.copy(axialToWorld(q, r));
    tile.receiveShadow = true;
    tile.castShadow = true;
    board.add(tile);
  }
}

const centerHalo = new THREE.Mesh(
  new THREE.RingGeometry(0.55, 0.72, 6),
  new THREE.MeshBasicMaterial({ color: 0x62ddc2, transparent: true, opacity: 0.32, side: THREE.DoubleSide, depthWrite: false })
);
centerHalo.rotation.x = -Math.PI * 0.5;
centerHalo.rotation.z = Math.PI / 6;
centerHalo.position.y = 0.165;
scene.add(centerHalo);

const modelMount = new THREE.Group();
modelMount.position.set(0, 0.16, 0);
scene.add(modelMount);

const referenceMount = new THREE.Group();
referenceMount.position.copy(axialToWorld(-2, 1));
referenceMount.position.y = 0.16;
const referenceHero = createPenguin();
referenceHero.scale.multiplyScalar(0.86 * 0.91);
referenceHero.userData.healthBar.visible = false;
referenceMount.add(referenceHero);
scene.add(referenceMount);

let selectedIndex = 0;
let selectedModel = null;
let selectedHealthBar = null;
let selectedMotion = 'idle';
let motionStartedAt = 0;
let displayScale = 1;
const healthBarAnchor = new THREE.Vector3(0, 0.16, 0);
const healthBarGroundDirection = new THREE.Vector3();
const healthBarWorldPosition = new THREE.Vector3();

function markModelMeshes(model) {
  model.traverse(child => {
    if (!child.isMesh) return;
    child.castShadow = true;
    child.receiveShadow = true;
  });
}

function disposeSelectedModel() {
  if (!selectedModel) return;
  if (selectedHealthBar) {
    scene.remove(selectedHealthBar);
    selectedHealthBar.traverse(child => {
      child.geometry?.dispose?.();
      if (Array.isArray(child.material)) child.material.forEach(material => material.dispose?.());
      else child.material?.dispose?.();
    });
    selectedHealthBar = null;
  }
  modelMount.remove(selectedModel);
  selectedModel.traverse(child => {
    child.geometry?.dispose?.();
    if (Array.isArray(child.material)) child.material.forEach(material => material.dispose?.());
    else child.material?.dispose?.();
  });
}

function applyModelScale() {
  if (!selectedModel) return;
  selectedModel.scale.copy(selectedModel.userData.reviewBaseScale).multiplyScalar(displayScale);
}

function selectEnemy(index) {
  selectedIndex = index;
  const entry = ENEMIES[index];
  const template = ENEMY_TEMPLATES[entry.id];
  disposeSelectedModel();
  selectedModel = entry.id === 'slime'
    ? createSlimeCandidate()
    : createEnemyCandidate(entry.id) || createChapterOneEnemy(entry.id);
  selectedModel.scale.multiplyScalar(0.86);
  selectedModel.userData.reviewBaseScale = selectedModel.scale.clone();
  selectedHealthBar = selectedModel.userData.healthBar;
  selectedHealthBar.userData.reviewLocalOffset = selectedHealthBar.position.clone();
  selectedHealthBar.userData.reviewBaseScale = selectedHealthBar.scale.clone()
    .multiply(selectedModel.userData.reviewBaseScale);
  selectedModel.remove(selectedHealthBar);
  selectedHealthBar.scale.copy(selectedHealthBar.userData.reviewBaseScale);
  selectedHealthBar.visible = document.getElementById('show-health').checked;
  scene.add(selectedHealthBar);
  selectedModel.rotation.y = 0;
  markModelMeshes(selectedModel);
  modelMount.add(selectedModel);
  applyModelScale();
  setMotion('idle');

  document.getElementById('stage-index').textContent = `MODEL ${String(index + 1).padStart(2, '0')}`;
  document.getElementById('stage-name').textContent = template.name;
  document.getElementById('stage-type').textContent = entry.role;
  document.getElementById('enemy-stage').textContent = `${entry.stage} 初次出现`;
  document.getElementById('enemy-name').textContent = template.name;
  document.getElementById('enemy-desc').textContent = entry.desc;
  document.getElementById('enemy-hp').textContent = template.hp;
  document.getElementById('enemy-atk').textContent = template.attack;
  document.getElementById('enemy-range').textContent = template.range;
  document.getElementById('review-progress').textContent = `${String(index + 1).padStart(2, '0')} / ${String(ENEMIES.length).padStart(2, '0')}`;
  document.querySelectorAll('.enemy-button').forEach((button, buttonIndex) => {
    button.classList.toggle('active', buttonIndex === index);
    button.setAttribute('aria-pressed', String(buttonIndex === index));
  });
}

function setMotion(motion) {
  selectedMotion = motion;
  motionStartedAt = performance.now() * 0.001;
  document.querySelectorAll('[data-motion]').forEach(button => {
    const active = button.dataset.motion === motion;
    button.classList.toggle('active', active);
    button.setAttribute('aria-pressed', String(active));
  });
}

const enemyList = document.getElementById('enemy-list');
ENEMIES.forEach((entry, index) => {
  const template = ENEMY_TEMPLATES[entry.id];
  const button = document.createElement('button');
  button.type = 'button';
  button.className = 'enemy-button';
  button.innerHTML = `
    <span class="enemy-number">${String(index + 1).padStart(2, '0')}</span>
    <span class="enemy-label"><strong>${template.name}</strong><small>${entry.stage}</small></span>
  `;
  button.addEventListener('click', () => selectEnemy(index));
  enemyList.appendChild(button);
});

document.getElementById('motion-controls').addEventListener('click', event => {
  const button = event.target.closest('[data-motion]');
  if (button) setMotion(button.dataset.motion);
});

document.getElementById('show-reference').addEventListener('change', event => {
  referenceMount.visible = event.target.checked;
});

document.getElementById('show-health').addEventListener('change', event => {
  if (selectedHealthBar) selectedHealthBar.visible = event.target.checked;
});

document.getElementById('display-scale').addEventListener('change', event => {
  displayScale = Number(event.target.value) || 1;
  applyModelScale();
});

const VIEW_PRESETS = {
  game: { yaw: 0, pitch: 0.92, zoom: 1 },
  front: { yaw: 0, pitch: 0.24, zoom: 1.16 },
  side: { yaw: Math.PI * 0.5, pitch: 0.24, zoom: 1.16 },
  back: { yaw: Math.PI, pitch: 0.24, zoom: 1.16 },
};

document.querySelector('.camera-controls').addEventListener('click', event => {
  const button = event.target.closest('[data-view]');
  if (!button) return;
  const preset = VIEW_PRESETS[button.dataset.view];
  cameraYaw = preset.yaw;
  cameraPitch = preset.pitch;
  cameraZoom = preset.zoom;
  updateCamera();
  document.querySelectorAll('[data-view]').forEach(viewButton => viewButton.classList.toggle('active', viewButton === button));
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
  cameraPitch = THREE.MathUtils.clamp(cameraPitch + (event.clientY - pointerY) * 0.006, 0.14, 1.36);
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
  const viewHeight = 5.5;
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
  const motionTime = Math.max(0, time - motionStartedAt);
  modelMount.position.set(0, 0.16, 0);
  modelMount.rotation.set(0, 0, 0);
  modelMount.scale.set(1, 1, 1);
  if (selectedModel) {
    selectedModel.userData.animate?.(time);
    if (selectedMotion === 'turntable') {
      modelMount.rotation.y = motionTime * 0.75;
    } else if (selectedMotion === 'move') {
      const step = Math.sin(motionTime * 6);
      modelMount.position.y += Math.abs(step) * 0.11;
      modelMount.position.x = Math.sin(motionTime * 2.2) * 0.3;
      modelMount.rotation.z = step * 0.06;
    } else if (selectedMotion === 'attack') {
      const phase = motionTime % 1.15;
      const punch = Math.sin(Math.min(1, phase / 0.62) * Math.PI);
      modelMount.position.z = punch * 0.52;
      modelMount.scale.set(1 - punch * 0.08, 1 + punch * 0.12, 1 - punch * 0.08);
      selectedModel.userData.playAction?.('attack', 0.55);
    } else if (selectedMotion === 'hit') {
      const phase = motionTime % 1.1;
      const recoil = Math.sin(Math.min(1, phase / 0.55) * Math.PI);
      modelMount.position.z = -recoil * 0.3;
      modelMount.rotation.z = Math.sin(phase * 28) * recoil * 0.08;
      modelMount.scale.set(1 + recoil * 0.1, 1 - recoil * 0.14, 1 + recoil * 0.1);
      selectedModel.userData.playAction?.('hit', 0.5);
    }
  }
  if (selectedHealthBar) {
    const offset = selectedHealthBar.userData.reviewLocalOffset;
    const baseScale = selectedModel.userData.reviewBaseScale;
    healthBarGroundDirection.copy(camera.position).sub(healthBarAnchor).setY(0);
    if (healthBarGroundDirection.lengthSq() > 0.0001) healthBarGroundDirection.normalize();
    healthBarWorldPosition.copy(healthBarAnchor)
      .addScaledVector(healthBarGroundDirection, offset.z * baseScale.z);
    healthBarWorldPosition.y += offset.y * baseScale.y;
    selectedHealthBar.position.copy(healthBarWorldPosition);
    selectedHealthBar.quaternion.copy(camera.quaternion);
  }
  referenceHero.userData.animate?.(time, false);
  centerHalo.material.opacity = 0.22 + (Math.sin(time * 2.2) + 1) * 0.06;
  renderer.render(scene, camera);
  requestAnimationFrame(frame);
}

updateCamera();
resize();
selectEnemy(0);
frame();
