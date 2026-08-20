import assert from 'node:assert/strict';
import * as THREE from '../vendor/three.module.js';
import { BattleCameraController } from '../src/game/BattleCameraController.js';

function createController() {
  return new BattleCameraController({
    viewWidth: 12.3,
    aspect: 375 / 812,
    viewportWidth: 375,
    viewportHeight: 812,
    cameraOffset: new THREE.Vector3(0, 21.85, 11.25),
    boardBounds: { minX: -5.7, maxX: 5.7, minZ: -5.1, maxZ: 5.1 },
    focusY: 0.15,
    initialFocus: new THREE.Vector3(0, 0.15, 0),
    defaultZoom: 1.45,
    minZoom: 0.82,
    maxZoom: 1.75,
    safeRect: { left: 18, right: 357, top: 170, bottom: 616 },
  });
}

const controller = createController();
const hero = new THREE.Vector3(0, 0.18, 0);

controller.setUserZoom(1.12);
let state = controller.update(1, { mode: 'idle', primary: hero, points: [hero] });
assert.equal(state.userZoom, 1.12, 'manual zoom should be stored as an absolute preference');
assert.ok(state.zoomTarget <= 1.12, 'automatic framing must never move closer than the user preference');

controller.reset(new THREE.Vector3(0, 0.15, 0));
controller.setUserZoom(1.32);
const farTarget = new THREE.Vector3(5.2, 0.18, -4.2);
const farSource = new THREE.Vector3(-5.2, 0.18, 3.8);
state = controller.update(0.25, {
  mode: 'enemy_action',
  primary: farTarget,
  points: [farSource, farTarget],
  margin: 0.9,
});
assert.ok(state.zoomTarget < 1.32, 'a cross-screen action should temporarily pull the camera out');

for (let index = 0; index < 18; index += 1) {
  state = controller.update(0.1, { mode: 'idle', primary: hero, points: [hero] });
}
assert.ok(Math.abs(state.zoomTarget - 1.32) < 0.0001, 'returning from auto framing must preserve manual zoom exactly');
assert.ok(Math.abs(state.zoom - 1.32) < 0.015, 'camera should return smoothly to the manual preference');

controller.reset(new THREE.Vector3(0, 0.15, 0));
const visibleEnemy = new THREE.Vector3(1.2, 0.18, 0.4);
const offscreenEnemy = new THREE.Vector3(9, 0.18, 0);
assert.equal(
  controller.needsEnemyActionShot({ from: visibleEnemy, to: farTarget, ranged: false }),
  false,
  'a visible melee actor should not move the camera merely because its destination is distant'
);
assert.equal(
  controller.needsEnemyActionShot({ from: offscreenEnemy, to: hero, ranged: false }),
  true,
  'an off-screen attacking enemy should request an action shot'
);
assert.equal(
  controller.needsEnemyActionShot({ from: offscreenEnemy, to: hero, ranged: false, actionType: 'move' }),
  false,
  'off-screen walking must never pull the camera away from the hero'
);
assert.equal(
  controller.needsEnemyActionShot({ from: visibleEnemy, to: farTarget, ranged: true }),
  true,
  'a ranged attack crossing the gameplay frame should request an action shot'
);

controller.reset(new THREE.Vector3(0, 0.15, 0));
state = controller.update(1 / 60, {
  mode: 'hero_action',
  primary: hero,
  points: [hero],
  margin: 0.72,
});
assert.ok(state.focusTarget.distanceTo(new THREE.Vector3(0, 0.15, 0)) < 0.0001,
  'hero movement inside the dead zone must not recenter the camera');
const movingHero = new THREE.Vector3(3.2, 0.18, -1.8);
const firstFollow = controller.update(1 / 60, {
  mode: 'hero_action',
  primary: movingHero,
  points: [movingHero],
  margin: 0.72,
});
assert.ok(firstFollow.focus.distanceTo(firstFollow.focusTarget) > 0.1,
  'live follow should ease toward a new cell instead of snapping there in one frame');
const firstX = firstFollow.focus.x;
for (let index = 0; index < 20; index += 1) {
  state = controller.update(1 / 60, {
    mode: 'hero_action',
    primary: movingHero,
    points: [movingHero],
    margin: 0.72,
  });
}
assert.ok(Math.abs(state.focus.x - state.focusTarget.x) < Math.abs(firstX - state.focusTarget.x),
  'live follow should make continuous progress toward the moving actor');
assert.ok(Math.abs(controller.focusVelocity.x) > 0.001,
  'camera follow should retain velocity between frames');
controller.reset(new THREE.Vector3(0, 0.15, 0));
assert.equal(controller.focusVelocity.lengthSq(), 0,
  'reset should clear residual camera velocity');

console.log('battle camera controller tests passed');
