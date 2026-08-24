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
assert.equal(slime.getObjectByName('SlimeCandidateHighlightLarge'), undefined,
  'body highlights must come from the gel material instead of a pasted mesh');
assert.equal(slime.getObjectByName('SlimeCandidateHighlightSmall'), undefined,
  'slime surface must stay visually continuous without a second highlight blob');
assert.equal(slime.getObjectByName('SlimeCandidateCrown'), undefined,
  'slime crown must be formed by the primary body instead of a glued sphere');
let highestBodyPoint = -Infinity;
const bodyPositions = body.geometry.getAttribute('position');
for (let index = 0; index < bodyPositions.count; index += 1) {
  highestBodyPoint = Math.max(highestBodyPoint, bodyPositions.getY(index));
}
assert.ok(highestBodyPoint > 1.1, 'continuous primary body must retain a readable crown silhouette');
assert.ok(body.material.clearcoat > 0 && body.material.roughness < 0.4,
  'continuous gel material must still produce a readable light response');
assert.ok(body.material.color.b > body.material.color.g
  && body.material.color.g > body.material.color.r,
  'chapter-one slime must use a light ocean-blue gel palette');
assert.ok(body.material.emissive.b > body.material.emissive.g,
  'slime subsurface tint must stay blue instead of reverting to green');

slime.userData.animate(0);
slime.userData.playAction('hit', 0.4);
slime.userData.animate(0.2);
assert(rig.scale.y < 0.8, 'candidate slime must retain a readable squash reaction');

console.log('slime candidate model tests passed');
