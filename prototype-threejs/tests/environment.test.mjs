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

const abyssScene = new THREE.Scene();
const abyss = createEnvironment(abyssScene, { theme: 'abyss_trench' });
assert.equal(abyss.theme, 'abyss_trench');
assert.equal(abyss.group.name, 'AbyssTrenchEnvironment');
assert.equal(abyss.group.userData.theme, 'abyss_trench');
assert(abyss.group.getObjectByName('AbyssSeabed'),
  'abyss theme must provide a continuous trench seabed');
assert(abyss.group.getObjectByName('AbyssRuinArch'),
  'abyss theme must include a readable submerged ruin outside the board');
assert(abyss.group.getObjectByName('AbyssShipwreck'),
  'abyss theme must include shipwreck remains outside the board');
assert.equal(abyss.group.getObjectByName('ForestTree_0'), undefined,
  'chapter-one abyss theme must not accidentally keep forest trees');

const boundaryObjects = abyss.group.children.filter(child => child.userData.abyssBoundaryObject);
assert.equal(boundaryObjects.length, 50,
  'abyss border must include ridges, coral, kelp, anemones, vents and two set pieces');
boundaryObjects.forEach(object => {
  const centerDistance = Math.hypot(object.position.x, object.position.z);
  assert(centerDistance > 6.3,
    `${object.name} must remain outside the playable board clearing`);
});

const bubbleField = abyss.group.getObjectByName('AbyssBubbleField');
assert(bubbleField?.isInstancedMesh, 'abyss bubbles should use one mobile-friendly instanced field');
assert.equal(bubbleField.count, 28, 'bubble plumes must remain visible in the portrait battle framing');
const initialBubbleMatrix = bubbleField.instanceMatrix.array.slice();
abyss.update(3.2);
assert.notDeepEqual(Array.from(bubbleField.instanceMatrix.array), Array.from(initialBubbleMatrix),
  'bubble plumes should visibly rise through the water rather than only pulse in place');
assert(abyss.group.getObjectByName('AbyssCausticField')?.children.length >= 8,
  'the seabed must include moving caustic arcs outside the playable board');
assert.equal(abyss.group.getObjectByName('AbyssLightShafts')?.children.length, 3,
  'the far trench must include soft overhead light shafts');
assert(abyss.group.getObjectByName('AbyssMarineSnow')?.isPoints,
  'suspended marine particles should provide underwater depth without extra mesh draw calls');

let abyssMeshCount = 0;
let abyssTriangleCount = 0;
abyss.group.traverse(child => {
  if (!child.isMesh) return;
  abyssMeshCount += 1;
  abyssTriangleCount += child.geometry.index
    ? child.geometry.index.count / 3
    : child.geometry.getAttribute('position').count / 3;
});
assert(abyssMeshCount <= 320,
  'abyss environment must stay within the WeChat preview draw-object budget');
assert(abyssTriangleCount <= 24000,
  'abyss environment must stay within the procedural mobile geometry budget');

console.log('environment placement tests passed');
