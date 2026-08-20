import assert from 'node:assert/strict';

import { createPenguin, createScarecrow, createSlime } from '../src/game/Units.js';

const hero = createPenguin();
const heroRig = hero.getObjectByName('PenguinCombatRig');
const sword = hero.getObjectByName('PenguinSword');
assert(hero.getObjectByName('PenguinFacePatchLeft'), 'penguin must have a raised cream cheek patch');
assert(hero.getObjectByName('PenguinFacePatchRight'), 'penguin must have two-part classic face markings');
assert(hero.getObjectByName('PenguinBeak3D'), 'penguin must have a projecting three-dimensional beak');
assert(hero.getObjectByName('PenguinFlipperLeft'), 'penguin silhouette must include a named flipper');

hero.userData.animate(0, false);
const idleRotation = heroRig.rotation.z;
hero.userData.playAction('move', 0.34);
hero.userData.animate(0.0425, true);
assert(Math.abs(heroRig.rotation.z - idleRotation) > 0.08, 'move must visibly sway the full silhouette');
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
assert(Math.abs(sword.rotation.z) > 1, 'jump attack must use a broad sword swing');
assert(heroRig.position.z > 0.04, 'jump attack must punch the body toward the target');

hero.userData.animate(2, false);
hero.userData.playAction('hit', 0.48);
hero.userData.animate(2.2, false);
assert(heroRig.rotation.x > 0.1, 'hit reaction must visibly recoil');
assert(heroRig.scale.y < 0.95, 'hit reaction must squash the body');

hero.userData.animate(3, false);
hero.userData.playAction('land', 0.34);
hero.userData.animate(3.17, false);
assert(heroRig.scale.y < 0.85, 'landing must have a readable squash and rebound beat');

hero.userData.animate(4, false);
hero.userData.playAction('pickup', 0.58);
hero.userData.animate(4.24, false);
assert(hero.getObjectByName('PenguinHead').rotation.x > 0.35, 'pickup must visibly nod toward the item');

hero.userData.animate(5, false);
hero.userData.playAction('cast', 0.64);
hero.userData.animate(5.34, false);
assert(sword.rotation.z < -1.4, 'skill casting must raise the sword into a clear silhouette');
assert(heroRig.position.y > 0.05, 'skill casting must lift the full combat rig');

const slime = createSlime();
const slimeRig = slime.getObjectByName('SlimeCombatRig');
slime.userData.animate(0);
slime.userData.playAction('hit', 0.4);
slime.userData.animate(0.2);
assert(slimeRig.scale.y < 0.8, 'slime hit reaction must visibly squash');

const scarecrow = createScarecrow();
const scarecrowRig = scarecrow.getObjectByName('ScarecrowRig');
assert(scarecrow.getObjectByName('ScarecrowHat'), 'scarecrow must have a readable straw-hat silhouette');
assert(scarecrow.getObjectByName('ScarecrowCrossbar'), 'scarecrow must visibly be supported by a wooden crossbar');
assert(scarecrow.getObjectByName('ScarecrowHead'), 'scarecrow must have a stitched burlap head');
scarecrow.userData.animate(1);
scarecrow.userData.playAction('hit', 0.42);
scarecrow.userData.animate(1.21);
assert(scarecrowRig.scale.y < 0.95, 'scarecrow must react visibly when absorbing an enemy attack');

console.log('unit animation presentation tests passed');
