import assert from 'node:assert/strict';

import { createSlimeCandidate } from '../model-review/SlimeCandidate.js';

const slime = createSlimeCandidate();
const rig = slime.getObjectByName('SlimeCandidateRig');
const body = slime.getObjectByName('SlimeCandidateBody');

assert(rig, 'candidate slime must expose an animation rig');
assert(body, 'candidate slime must have a named primary body');
assert.equal(body.material.flatShading, false, 'primary gel surface must use smooth shading');
assert(body.geometry.attributes.position.count > 400, 'primary silhouette must have enough segments to avoid visible facets');
assert.equal(body.rotation.y, Math.PI, 'lathe seam must face away from the camera');
assert.equal(slime.getObjectByName('SlimeCandidateUnderside'), undefined,
  'candidate slime must remain one continuous body without a separate base ring');
assert(slime.getObjectByName('SlimeCandidateEyeLeft'), 'candidate slime must keep a readable face');
assert.equal(slime.getObjectByName('SlimeCandidateMouth'), undefined,
  'candidate slime must not have a mouth');

slime.userData.animate(0);
slime.userData.playAction('hit', 0.4);
slime.userData.animate(0.2);
assert(rig.scale.y < 0.8, 'candidate slime must retain a readable squash reaction');

console.log('slime candidate model tests passed');
