import assert from 'node:assert/strict';
import { createSlimeCandidate } from '../model-review/SlimeCandidate.js';
import { createEnemyCandidate } from '../model-review/EnemyCandidates.js';

function materialFor(model, meshName) {
  const mesh = model.getObjectByName(meshName);
  assert.ok(mesh?.isMesh, `missing review mesh: ${meshName}`);
  return mesh.material;
}

const slime = materialFor(createSlimeCandidate(), 'SlimeCandidateBody');
assert.ok(slime.roughness >= 0.35);
assert.ok(slime.clearcoat <= 0.4);

const turtle = createEnemyCandidate('iron_turtle');
const turtleShell = materialFor(turtle, 'IronTurtleCandidateShell');
const turtleSkin = materialFor(turtle, 'IronTurtleCandidateBody');
assert.ok(turtleShell.metalness >= 0.4);
assert.ok(turtleShell.roughness >= 0.55);
assert.equal(turtleSkin.isMeshStandardMaterial, true);
assert.ok(turtleSkin.roughness >= 0.8);
assert.ok(turtle.getObjectByName('IronTurtleCandidateShellRim'));
assert.ok(turtle.getObjectByName('IronTurtleCandidateNeck'));
assert.ok(turtle.getObjectByName('IronTurtleCandidateMouth'));
const turtleNames = [];
turtle.traverse(child => turtleNames.push(child.name));
assert.equal(turtleNames.filter(name => /^IronTurtleCandidatePlate\d+$/.test(name)).length, 7);
assert.equal(turtleNames.filter(name => /^IronTurtleCandidatePlateGroove\d+$/.test(name)).length, 7);
assert.equal(turtleNames.filter(name => /^IronTurtleCandidateRimGuard\d+$/.test(name)).length, 6);
assert.equal(turtleNames.filter(name => /^IronTurtleCandidateRivet\d+$/.test(name)).length, 6);
assert.equal(turtleNames.filter(name => /^IronTurtleClaw\d+_\d+$/.test(name)).length, 10);
assert.ok(turtleNames.includes('IronTurtleCandidateScratch1'));
assert.ok(turtleNames.includes('IronTurtleCandidateRustPatch'));
assert.ok(turtle.getObjectByName('IronTurtleCandidateShell').geometry.getAttribute('color'));

const archerfish = createEnemyCandidate('archerfish');
const archerfishSkin = materialFor(archerfish, 'ArcherfishCandidateBody');
assert.equal(archerfishSkin.isMeshStandardMaterial, true);
assert.ok(archerfishSkin.roughness >= 0.6);

const ray = createEnemyCandidate('electric_ray');
const raySkin = materialFor(ray, 'ElectricRayCandidateBody');
assert.equal(raySkin.clearcoat, 0);
assert.ok(raySkin.roughness >= 0.7);

const crab = createEnemyCandidate('hermit_crab');
const crabShell = materialFor(crab, 'HermitCrabCandidateShell');
assert.equal(crabShell.isMeshStandardMaterial, true);
assert.ok(crabShell.roughness >= 0.85);

const jellyfish = createEnemyCandidate('jellyfish');
const jellyBell = materialFor(jellyfish, 'JellyfishCandidateDome');
assert.equal(jellyBell.transparent, true);
assert.ok(jellyBell.clearcoat >= 0.3);

const ghost = createEnemyCandidate('ghost_shark');
const ghostBody = materialFor(ghost, 'GhostSharkCandidateBody');
assert.equal(ghostBody.clearcoat, 0);
assert.equal(ghostBody.depthWrite, false);
assert.ok(ghostBody.emissiveIntensity >= 0.25);

console.log('model review material tests passed');
