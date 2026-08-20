import assert from 'node:assert/strict';

import { createEnemyCandidate } from '../model-review/EnemyCandidates.js';

const CASES = [
  ['jellyfish', 'JellyfishCandidateRig', 'JellyfishCandidateDome', 'JellyfishBell'],
  ['iron_turtle', 'IronTurtleCandidateRig', 'IronTurtleCandidateShell', 'IronTurtleHead'],
  ['archerfish', 'ArcherfishCandidateRig', 'ArcherfishCandidateBody', 'ArcherfishBody'],
  ['vortex_eel', 'VortexEelCandidateRig', 'VortexEelCandidateBodyMesh', 'VortexEelHead'],
  ['electric_ray', 'ElectricRayCandidateRig', 'ElectricRayCandidateBody', 'ElectricRayBody'],
  ['hermit_crab', 'HermitCrabCandidateRig', 'HermitCrabCandidateShell', 'HermitCrabClawLeft'],
  ['ghost_shark', 'GhostSharkCandidateRig', 'GhostSharkCandidateBody', 'GhostSharkCandidateRig'],
];

for (const [type, rigName, primaryName, actionNodeName] of CASES) {
  const enemy = createEnemyCandidate(type);
  assert(enemy, `${type} must have an independent candidate factory`);
  assert(enemy.userData.healthBar, `${type} must expose a detachable health bar`);
  assert.equal(typeof enemy.userData.animate, 'function', `${type} must own an animation rig`);
  assert.equal(typeof enemy.userData.playAction, 'function', `${type} must support combat actions`);

  const rig = enemy.getObjectByName(rigName);
  const primary = enemy.getObjectByName(primaryName);
  const actionNode = enemy.getObjectByName(actionNodeName);
  assert(rig, `${type} must expose its named root rig`);
  assert(primary, `${type} must expose its defining silhouette mesh`);
  assert(actionNode, `${type} must expose an independently animated body part`);
  assert(primary.geometry.attributes.position.count > 100,
    `${type} primary silhouette must have enough geometry for a smooth mobile-sized contour`);

  enemy.traverse(child => {
    if (!child.isMesh) return;
    const materials = Array.isArray(child.material) ? child.material : [child.material];
    materials.forEach(material => {
      assert.notEqual(material.flatShading, true,
        `${type} candidate must not expose intentional faceted shading`);
    });
  });

  enemy.userData.animate(0);
  const beforePosition = actionNode.position.clone();
  const beforeRotation = actionNode.rotation.clone();
  const beforeScale = actionNode.scale.clone();
  enemy.userData.playAction('attack', 0.5);
  enemy.userData.animate(0.25);
  const changed = !actionNode.position.equals(beforePosition)
    || !actionNode.rotation.equals(beforeRotation)
    || !actionNode.scale.equals(beforeScale);
  assert(changed, `${type} attack must articulate a real model part`);
}

assert.equal(createEnemyCandidate('unknown'), null, 'unknown enemy types must fall back cleanly');

console.log('chapter one enemy candidate tests passed');
