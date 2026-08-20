import assert from 'node:assert/strict';
import * as THREE from '../vendor/three.module.js';
import { VfxDirector } from '../src/vfx/VfxDirector.js';

const scene = new THREE.Scene();
const camera = new THREE.OrthographicCamera(-5, 5, 8, -8, 0.1, 50);
camera.position.set(0, 12, 8);
camera.lookAt(0, 0, 0);
camera.updateMatrixWorld();

const impulses = [];
const director = new VfxDirector(scene, {
  onCameraImpulse: (strength, duration) => impulses.push({ strength, duration }),
});

const directionalImpact = director.impact({
  position: new THREE.Vector3(1, 0.8, 0),
  direction: new THREE.Vector3(1, 0, 0),
  camera,
});
const comboFinish = director.comboBurst({ position: new THREE.Vector3(), camera, combo: 3 });
director.lightningChain({
  points: [new THREE.Vector3(0, 0.8, 0), new THREE.Vector3(1.5, 0.8, -1), new THREE.Vector3(-1, 0.8, -2)],
  camera,
});
director.quake({ position: new THREE.Vector3(0, 0.2, 0) });

assert.equal(director.activeCount, 4, 'all four VFX test presets should be active');
assert.equal(impulses.length, 4, 'each preset should request a camera impulse');
assert.ok(director.root.children.length >= 4, 'effects should be attached to the VFX scene root');
assert.ok(directionalImpact.getObjectByName('DirectionalBladeStreak'),
  'ordinary attack feedback should contain a directional blade streak');
assert.equal(
  directionalImpact.children.some(child => child.geometry?.type === 'TorusGeometry'),
  false,
  'ordinary attack feedback must not use ambiguous circular slash arcs'
);
assert.equal(
  comboFinish.children.filter(child => child.name.startsWith('ComboCut')).length,
  3,
  'a three-hit combo finish should visibly present three sequential cuts'
);

director.update(0.25);
assert.ok(director.activeCount > 0, 'effects should remain active before their durations expire');
director.update(2);
assert.equal(director.activeCount, 0, 'expired effects should be removed');
assert.equal(director.root.children.length, 0, 'expired effects should leave no scene children behind');

director.dispose();
assert.equal(scene.children.includes(director.root), false, 'dispose should detach the director root');

const countScene = new THREE.Scene();
const countDirector = new VfxDirector(countScene);
const twoHitFinish = countDirector.comboBurst({ position: new THREE.Vector3(), camera, combo: 2 });
const eightHitFinish = countDirector.comboBurst({ position: new THREE.Vector3(), camera, combo: 8 });
assert.equal(twoHitFinish.children.filter(child => child.name.startsWith('ComboCut')).length, 2,
  'actual two-hit rewards must display exactly two cuts');
assert.equal(eightHitFinish.children.filter(child => child.name.startsWith('ComboCut')).length, 8,
  'actual eight-hit rewards must display exactly eight cuts');
countDirector.dispose();

console.log('vfx director tests passed');
