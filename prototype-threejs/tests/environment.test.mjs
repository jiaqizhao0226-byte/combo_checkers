import assert from 'node:assert/strict';
import * as THREE from '../vendor/three.module.js';

import { createEnvironment } from '../src/game/Environment.js';

const scene = new THREE.Scene();
const environment = createEnvironment(scene);
const trees = environment.group.children.filter(child => child.name.startsWith('ForestTree_'));
const motes = environment.group.children.filter(child => child.name.startsWith('ForestMote_'));

assert.equal(trees.length, 14);
assert.equal(
  environment.group.getObjectByName('ForestTree_14'),
  undefined,
  'the unstable lower-left foreground tree must remain omitted'
);
assert.equal(motes.length, 22);

for (const mote of motes) {
  for (const tree of trees) {
    const distance = Math.hypot(mote.position.x - tree.position.x, mote.position.z - tree.position.z);
    assert(
      distance > tree.userData.glowClearance + 0.72,
      `${mote.name} must not float inside ${tree.name}'s canopy`
    );
  }
}

const foliage = [];
environment.group.traverse(child => {
  if (child.userData.foliage) foliage.push(child);
});
assert(foliage.length >= trees.length * 3, 'tree and shrub foliage must be explicitly marked');
assert(foliage.every(leaf => leaf.receiveShadow === false), 'intersecting foliage must not receive unstable self-shadows');

environment.update(0);
const initialMoteScales = motes.map(mote => mote.scale.x);
environment.update(3.7);
assert.deepEqual(
  motes.map(mote => mote.scale.x),
  initialMoteScales,
  'environment motes may float but must never pulse or flicker in size'
);

console.log('environment placement tests passed');
