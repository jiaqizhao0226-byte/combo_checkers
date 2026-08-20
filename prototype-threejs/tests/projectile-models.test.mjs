import assert from 'node:assert/strict';
import * as THREE from '../vendor/three.module.js';
import { createTrackingDart, faceProjectileAlongScreen } from '../src/vfx/ProjectileModels.js';

const dart = createTrackingDart(0xffb64c);
const rotor = dart.getObjectByName('TrackingDartRotor');
assert(rotor, 'tracking dart must contain a rotating hub');
assert.equal(
  rotor.children.filter(child => child.name.startsWith('TrackingDartBlade')).length,
  4,
  'tracking dart must have four readable metal blades'
);
assert.equal(
  dart.getObjectByName('TrackingDartBlade1').material.metalness,
  1,
  'tracking dart blades must use a real reflective metal material'
);
assert(dart.getObjectByName('TrackingDartMetalRing'), 'tracking dart must have a polished metal hub ring');
assert(dart.getObjectByName('TrackingDartEnergyCore'), 'tracking dart must keep energy color limited to its core');
assert(dart.getObjectByName('TrackingDartTrail'), 'tracking dart must carry a directional flight trail');

const camera = new THREE.OrthographicCamera(-5, 5, 8, -8, 0.1, 50);
camera.position.set(0, 12, 8);
camera.lookAt(0, 0, 0);
camera.updateMatrixWorld();
const before = dart.quaternion.clone();
faceProjectileAlongScreen(dart, new THREE.Vector3(2, 0, -1), camera);
assert(before.angleTo(dart.quaternion) > 0.01,
  'tracking dart should align its trail with the screen-space flight direction');

console.log('projectile model tests passed');
