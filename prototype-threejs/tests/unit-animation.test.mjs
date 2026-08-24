import assert from 'node:assert/strict';

import { createPenguin, createScarecrow, createSlime } from '../src/game/Units.js';

const hero = createPenguin();
const heroRig = hero.getObjectByName('PenguinCandidateRig');
const sword = hero.getObjectByName('CandidateSword');
const heroJoints = hero.userData.joints;
assert.equal(hero.userData.modelVersion, 'v2', 'game-facing penguin must use the approved V2 model');
assert(hero.userData.healthBar, 'game-facing V2 penguin must expose the battle health bar');
assert(hero.userData.contactShadow, 'game-facing V2 penguin must expose its contact shadow');
assert(hero.getObjectByName('CandidateIntegratedFaceMask'), 'penguin must use the continuous rounded cream face mask');
assert(hero.getObjectByName('CandidateClosedBeak'), 'penguin must have the approved short closed beak');
assert(hero.getObjectByName('CandidateLeftFlipper'), 'penguin silhouette must include a jointed flipper');
assert(hero.getObjectByName('CandidateTailFeather'), 'game-facing penguin must include the approved short black tail');

hero.userData.animate(0, false);
const idleRotation = heroRig.rotation.z;
hero.userData.playAction('move', 0.34);
hero.userData.animate(0.0425, true);
assert(Math.abs(heroRig.rotation.z - idleRotation) > 0.02, 'move must visibly sway the jointed silhouette');
hero.userData.animate(0.339, true);
const finalTravelRotation = heroRig.rotation.z;
hero.userData.animate(0.341, false);
assert.equal(hero.userData.action, null, 'move action must finish with the travel interval');
assert(
  Math.abs(heroRig.rotation.z - finalTravelRotation) < 0.04,
  'arriving on a cell must return to idle without a post-move sideways snap'
);

hero.userData.animate(1, false);
hero.userData.playAction('jump_attack', 0.56);
hero.userData.animate(1.34, true);
assert(Math.abs(heroJoints.rightShoulder.rotation.x) > 0.7, 'jump attack must drive a broad shoulder-led sword swing');
assert(Math.abs(sword.quaternion.x) > 0.2, 'jump attack must pitch the blade into the target space');

hero.userData.animate(2, false);
hero.userData.playAction('hit', 0.48);
hero.userData.animate(2.2, false);
assert(heroRig.position.z < -0.035, 'hit reaction must visibly recoil');
assert(Math.abs(heroJoints.head.rotation.x) > 0.2, 'hit reaction must move the head independently');

hero.userData.animate(2.6, false);
hero.userData.playAction('approved_hit', 0.58, { recoilX: 0, recoilZ: -1 });
hero.userData.animate(2.7, false);
assert.equal(heroRig.position.y, 0, 'approved hero hit must remain fully grounded');
assert.equal(heroJoints.leftAnkle.position.y, 0.1, 'approved hero hit must not lift the left foot');
assert.equal(heroJoints.rightAnkle.position.y, 0.1, 'approved hero hit must not lift the right foot');
assert(Math.abs(heroJoints.hitBodyPivot.rotation.x) > 0.2,
  'approved hero hit must visibly tilt the upper body around the grounded pivot');

hero.userData.animate(3, false);
hero.userData.playAction('land', 0.34);
hero.userData.animate(3.17, false);
assert(heroRig.scale.y < 0.85, 'landing must have a readable squash and rebound beat');

hero.userData.animate(4, false);
hero.userData.playAction('pickup', 0.58);
hero.userData.animate(4.24, false);
assert(heroJoints.head.rotation.x > 0.3, 'pickup must visibly nod toward the item');

hero.userData.animate(5, false);
hero.userData.playAction('cast', 0.64);
hero.userData.animate(5.34, false);
assert(sword.rotation.z < -1.35, 'skill casting must raise the sword into a clear silhouette');
assert(heroRig.position.y > 0.05, 'skill casting must lift the full combat rig');

hero.userData.animate(6, false);
hero.userData.playAction('time_stop_cast', 1.05);
hero.userData.animate(6.52, false);
assert(heroJoints.leftShoulder.rotation.z < -1.2 && heroJoints.rightShoulder.rotation.z > 0.9,
  'time stop must snap both flippers into a broad halt silhouette');

hero.userData.animate(8, false);
hero.userData.playAction('meteor_cast', 1.78);
hero.userData.animate(8.82, false);
assert(heroRig.position.y > 0.65, 'meteor cast must visibly jump before the board-wide slam');

hero.userData.animate(11, false);
hero.userData.playAction('absolute_reflect_cast', 1.1);
hero.userData.animate(11.55, false);
assert(heroJoints.leftShoulder.position.x < -0.42 && heroJoints.rightShoulder.position.x > 0.45,
  'absolute reflect must keep both flippers visible outside the torso');

const slime = createSlime();
const slimeRig = slime.getObjectByName('SlimeCandidateRig');
assert.equal(slime.userData.modelVersion, 'approved-chapter-one-v2',
  'game-facing slime must use the approved light-blue model');
assert(slime.getObjectByName('SlimeCandidateBody'),
  'game-facing slime must expose the approved continuous gel body');
slime.userData.animate(0);
slime.userData.playAction('hit', 0.4);
slime.userData.animate(0.2);
assert(slimeRig.scale.y < 0.8, 'slime hit reaction must visibly squash');

const scarecrow = createScarecrow();
const scarecrowRig = scarecrow.getObjectByName('ScarecrowReadableRig');
assert(scarecrow.getObjectByName('ScarecrowFloppyHatRig'), 'scarecrow must have a readable straw-hat silhouette');
assert(scarecrow.getObjectByName('ScarecrowCrossWood'), 'scarecrow must visibly be supported by a wooden crossbar');
assert(scarecrow.getObjectByName('ScarecrowBurlapHeadRig'), 'scarecrow must have a stitched burlap head');
scarecrow.userData.animate(1);
scarecrow.userData.playAction('hit', 0.42);
scarecrow.userData.animate(1.21);
assert(scarecrowRig.rotation.x > -0.25,
  'scarecrow must recoil through its visual rig when absorbing an enemy attack');

console.log('unit animation presentation tests passed');
