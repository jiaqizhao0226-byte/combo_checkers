import assert from 'node:assert/strict';
import * as THREE from '../vendor/three.module.js';
import { createEnemyCandidate } from '../model-review/EnemyCandidates.js';

function boxFor(node) {
  assert.ok(node, 'continuity check received a missing model node');
  return new THREE.Box3().setFromObject(node);
}

function assertConnected(model, coreName, partName) {
  model.updateMatrixWorld(true);
  const core = model.getObjectByName(coreName);
  const part = model.getObjectByName(partName);
  assert.ok(core, `missing continuity core: ${coreName}`);
  assert.ok(part, `missing continuity part: ${partName}`);
  assert.ok(boxFor(core).intersectsBox(boxFor(part)),
    `${partName} must overlap ${coreName} instead of floating beside it`);
}

const checks = [
  ['jellyfish', 'JellyfishCandidateDome', [
    'JellyfishCandidateTentacleMesh1',
    'JellyfishCandidateTentacleMesh2',
    'JellyfishCandidateTentacleMesh3',
    'JellyfishCandidateTentacleMesh4',
    'JellyfishCandidateTentacleMesh5',
    'JellyfishCandidateTentacleMesh6',
  ]],
  ['iron_turtle', 'IronTurtleCandidateShellUnderlay', ['IronTurtleCandidateTail']],
  ['iron_turtle', 'IronTurtleCandidateBody', [
    'IronTurtleCandidateFrontFlipperMeshL',
    'IronTurtleCandidateFrontFlipperMeshR',
    'IronTurtleCandidateRearFlipperMeshL',
    'IronTurtleCandidateRearFlipperMeshR',
    'IronTurtleCandidateNeck',
  ]],
  ['archerfish', 'ArcherfishCandidateBody', [
    'ArcherfishCandidateLeftFinMesh',
    'ArcherfishCandidateRightFinMesh',
    'ArcherfishCandidateTailStem',
  ]],
  ['vortex_eel', 'VortexEelCandidateBodyMesh', [
    'VortexEelCandidateHeadMesh',
    'VortexEelTailFinL',
    'VortexEelTailFinR',
  ]],
  ['electric_ray', 'ElectricRayCandidateBody', [
    'ElectricRayCandidateLeftWingMesh',
    'ElectricRayCandidateRightWingMesh',
    'ElectricRayCandidateTailStem',
  ]],
  ['hermit_crab', 'HermitCrabCandidateBody', [
    'HermitCrabCandidateShellOpening',
    'HermitCrabEyeStalkMesh1',
    'HermitCrabEyeStalkMesh2',
    'HermitCrabClawPalm1',
    'HermitCrabClawPalm2',
    'HermitCrabLegMeshL1',
    'HermitCrabLegMeshR1',
  ]],
  ['ghost_shark', 'GhostSharkCandidateBody', [
    'GhostSharkCandidateLeftFinMesh',
    'GhostSharkCandidateRightFinMesh',
    'GhostSharkCandidateTailStem',
    'GhostSharkCandidateDorsalFinMesh',
  ]],
];

checks.forEach(([modelId, coreName, partNames]) => {
  const model = createEnemyCandidate(modelId);
  partNames.forEach(partName => assertConnected(model, coreName, partName));
});

const ghostShark = createEnemyCandidate('ghost_shark');
assertConnected(ghostShark, 'GhostSharkCandidateTailStem', 'GhostSharkCandidateTailFinMesh');

const archerfish = createEnemyCandidate('archerfish');
assertConnected(archerfish, 'ArcherfishCandidateTailStem', 'ArcherfishCandidateTailFin');

// The electric ray's tail joint must remain buried in the torso through its
// strongest left/right motion, not just happen to touch in the idle pose.
const animatedRay = createEnemyCandidate('electric_ray');
animatedRay.userData.animate(0);
animatedRay.userData.playAction('move', 1);
[1 / 6, 0.5].forEach(time => {
  animatedRay.userData.animate(time);
  assertConnected(animatedRay, 'ElectricRayCandidateBody', 'ElectricRayCandidateTailStem');
});

console.log('model review continuity tests passed');
