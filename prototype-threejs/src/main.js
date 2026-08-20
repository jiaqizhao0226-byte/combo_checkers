import * as THREE from 'three';
import { PixelPipeline } from './render/PixelPipeline.js';
import { PixelCamera } from './render/PixelCamera.js';
import { createHexBoard, axialToWorld } from './game/HexBoard.js';
import { createPenguin, createSkeleton, createSlime } from './game/Units.js';
import { createEnvironment } from './game/Environment.js';

const canvas = document.getElementById('game');
const stage = document.getElementById('stage');
const routeStatus = document.getElementById('routeStatus');
const confirmButton = document.getElementById('confirm');
const undoButton = document.getElementById('undo');

const renderer = new THREE.WebGLRenderer({ canvas, antialias: false });
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFShadowMap;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.2;

const scene = new THREE.Scene();
scene.background = new THREE.Color(0x102832);
scene.fog = new THREE.Fog(0x102832, 20, 38);

const camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0.1, 80);
const pixelPipeline = new PixelPipeline(renderer, scene, camera, {
  pixelSize: 3,
  lowWidth: 360,
});
// 360 横向游戏像素配合更小的世界像素，构图不变但角色细节提高约 18%。
const pixelCamera = new PixelCamera(camera, 0.038);

// 暖侧光压出体积，冷天光和冷轮廓光负责分离暗面。
const hemisphere = new THREE.HemisphereLight(0x95bde4, 0x39442f, 0.9);
scene.add(hemisphere);

const keyLight = new THREE.DirectionalLight(0xffcf87, 2.35);
keyLight.position.set(14, 13, 9);
keyLight.castShadow = true;
keyLight.shadow.mapSize.set(2048, 2048);
keyLight.shadow.camera.near = 1;
keyLight.shadow.camera.far = 50;
Object.assign(keyLight.shadow.camera, { left: -15, right: 15, top: 15, bottom: -15 });
keyLight.shadow.bias = -0.001;
keyLight.shadow.normalBias = 0.075;
scene.add(keyLight, keyLight.target);

const fillLight = new THREE.DirectionalLight(0x5f91d0, 0.38);
fillLight.position.set(-10, 7, -9);
scene.add(fillLight);

const rimLight = new THREE.DirectionalLight(0x78b9e8, 0.72);
rimLight.position.set(-8, 10, -12);
scene.add(rimLight);

const environment = createEnvironment(scene);
const board = createHexBoard(scene);
const hero = createPenguin();
const actors = [hero];
scene.add(hero);

let heroCell = board.get(0, 3);
let selectedCell = null;
let movement = null;

function placeOnCell(object, q, r, y = 0.18) {
  const position = axialToWorld(q, r);
  object.position.set(position.x, y, position.z);
  object.userData.baseY = y;
  scene.add(object);
  actors.push(object);
  return object;
}

placeOnCell(createSlime(), -2, -1);
placeOnCell(createSlime(), 1, -2);
placeOnCell(createSlime(), 2, 0);
placeOnCell(createSkeleton(), -1, -3);
placeOnCell(createSkeleton(), 3, -2);

const heroStart = axialToWorld(heroCell.q, heroCell.r);
hero.position.set(heroStart.x, 0.18, heroStart.z);
hero.userData.baseY = 0.18;

const routeGroup = new THREE.Group();
routeGroup.name = 'JumpRoute';
scene.add(routeGroup);

const routeMaterial = new THREE.MeshBasicMaterial({
  color: new THREE.Color(0x42f1df).multiplyScalar(2.1),
  toneMapped: false,
});

function clearGroup(group) {
  while (group.children.length) {
    const child = group.children[group.children.length - 1];
    group.remove(child);
    child.geometry?.dispose();
    if (child.material && child.material !== routeMaterial) child.material.dispose?.();
  }
}

function addRouteSegment(start, end) {
  const midpoint = start.clone().add(end).multiplyScalar(0.5);
  const direction = end.clone().sub(start);
  const length = direction.length();
  const segment = new THREE.Mesh(
    new THREE.CylinderGeometry(0.055, 0.055, length, 5),
    routeMaterial
  );
  segment.position.copy(midpoint);
  segment.quaternion.setFromUnitVectors(
    new THREE.Vector3(0, 1, 0),
    direction.normalize()
  );
  routeGroup.add(segment);
}

function rebuildRoute() {
  clearGroup(routeGroup);
  board.clearStates();
  board.setState(heroCell, 'hero');
  if (!selectedCell) return;

  board.setState(selectedCell, 'target');
  const start = hero.position.clone();
  start.y = 0.42;
  const target = axialToWorld(selectedCell.q, selectedCell.r);
  target.y = 0.42;

  let previous = start;
  for (let index = 1; index <= 3; index += 1) {
    const point = start.clone().lerp(target, index / 4);
    addRouteSegment(previous, point);
    const node = new THREE.Mesh(
      new THREE.OctahedronGeometry(0.12, 0),
      routeMaterial
    );
    node.position.copy(point);
    routeGroup.add(node);
    previous = point;
  }
  addRouteSegment(previous, target);
  routeStatus.textContent = `路线已规划 · 落点 ${selectedCell.q},${selectedCell.r}`;
}

const raycaster = new THREE.Raycaster();
const pointer = new THREE.Vector2();

function pickCell(event) {
  if (movement) return;
  const bounds = canvas.getBoundingClientRect();
  pointer.x = ((event.clientX - bounds.left) / bounds.width) * 2 - 1;
  pointer.y = -((event.clientY - bounds.top) / bounds.height) * 2 + 1;
  raycaster.setFromCamera(pointer, camera);
  const hit = raycaster.intersectObjects(board.cells.map(cell => cell.mesh), false)[0];
  if (!hit) return;
  const { q, r } = hit.object.userData.cell;
  const cell = board.get(q, r);
  if (!cell || cell === heroCell) return;
  selectedCell = cell;
  rebuildRoute();
}

canvas.addEventListener('pointerup', pickCell);

undoButton.addEventListener('click', () => {
  if (movement) return;
  selectedCell = null;
  routeStatus.textContent = '点击六角格规划跳跃';
  rebuildRoute();
});

confirmButton.addEventListener('click', () => {
  if (movement) return;
  if (!selectedCell) {
    routeStatus.textContent = '请先选择落点';
    return;
  }

  const target = axialToWorld(selectedCell.q, selectedCell.r);
  movement = {
    from: hero.position.clone(),
    to: new THREE.Vector3(target.x, hero.userData.baseY, target.z),
    targetCell: selectedCell,
    elapsed: 0,
    duration: 0.62,
  };
  routeStatus.textContent = '执行跳跃';
});

document.getElementById('settings').addEventListener('click', () => {
  routeStatus.textContent = '设置功能未接入 · 技术原型';
});

document.getElementById('exit').addEventListener('click', () => {
  routeStatus.textContent = '退出功能未接入 · 技术原型';
});

function fitPixelGrid() {
  const width = stage.clientWidth || 375;
  const dpr = Math.max(1, Math.min(3, Math.round(window.devicePixelRatio || 1)));
  const unit = Math.max(2, Math.floor(width / 180 * dpr) / dpr);
  document.documentElement.style.setProperty('--u', `${unit}px`);
  pixelPipeline.resize(canvas);
}

window.addEventListener('resize', fitPixelGrid);
fitPixelGrid();

const timer = new THREE.Timer();
timer.connect(document);
const boardTarget = new THREE.Vector3(0, 0.15, 0.45);

function updateMovement(delta) {
  if (!movement) return;
  movement.elapsed += delta;
  const progress = Math.min(1, movement.elapsed / movement.duration);
  const eased = 1 - Math.pow(1 - progress, 3);
  hero.position.lerpVectors(movement.from, movement.to, eased);
  hero.position.y += Math.sin(progress * Math.PI) * 1.15;

  if (progress >= 1) {
    hero.position.copy(movement.to);
    heroCell = movement.targetCell;
    selectedCell = null;
    movement = null;
    routeStatus.textContent = '跳跃完成 · 可继续规划';
    rebuildRoute();
  }
}

function animate(timestamp) {
  requestAnimationFrame(animate);
  timer.update(timestamp);
  const delta = Math.min(timer.getDelta(), 1 / 20);
  const time = timer.getElapsed();

  pixelPipeline.resize(canvas);
  updateMovement(delta);

  if (!movement) {
    hero.position.y = hero.userData.baseY + Math.round(Math.sin(time * 3.2) * 2) * 0.018;
  }
  actors.forEach((actor, index) => {
    if (actor === hero || movement) return;
    actor.position.y = actor.userData.baseY + Math.round(Math.sin(time * 2.4 + index) * 2) * 0.014;
  });
  actors.forEach(actor => {
    const shadow = actor.userData.contactShadow;
    if (!shadow) return;
    const lift = Math.max(0, actor.position.y - actor.userData.baseY);
    shadow.position.y = (0.012 - lift) / actor.scale.y;
    shadow.material.opacity = shadow.userData.baseOpacity * Math.max(0.18, 1 - lift * 0.72);
  });
  actors.forEach(actor => actor.userData.animate?.(time, actor === hero && Boolean(movement)));
  environment.update(time);

  const snappedTarget = pixelCamera.update(
    boardTarget,
    pixelPipeline.lowWidth,
    pixelPipeline.lowHeight
  );
  keyLight.target.position.copy(snappedTarget);
  keyLight.position.set(snappedTarget.x + 14, snappedTarget.y + 13, snappedTarget.z + 9);
  keyLight.target.updateMatrixWorld();

  pixelCamera.snapActors(actors);
  pixelPipeline.render();
  pixelCamera.restoreActors();
}

rebuildRoute();
animate();
