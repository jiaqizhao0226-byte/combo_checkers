import assert from 'node:assert/strict';
import * as THREE from '../vendor/three.module.js';
import { createPenguinCandidate } from '../hero-review/PenguinCandidate.js';

const hero = createPenguinCandidate();
const joints = hero.userData.joints;
const beak = hero.getObjectByName('CandidateClosedBeak');
const faceMask = hero.getObjectByName('CandidateIntegratedFaceMask');
const swordHandle = hero.getObjectByName('CandidateSwordHandle');
const gripHand = hero.getObjectByName('CandidateSwordGripHand');
const tail = hero.getObjectByName('CandidateTailFeather');

assert.ok(beak, 'candidate exposes a closed beak mesh');
assert.equal(beak.material.transparent, false, 'beak material remains opaque');
assert.equal(beak.material.opacity, 1, 'beak material uses full opacity');
assert.equal(beak.geometry.type, 'SphereGeometry', 'beak uses a closed rounded mesh');
assert.ok(beak.scale.y < beak.scale.x && beak.scale.z < beak.scale.x,
  'beak is flattened into a short oval instead of a square front plate');

const facePositions = faceMask.geometry.attributes.position;
let foreheadCenterY = -Infinity;
let foreheadLobeY = -Infinity;
for (let index = 0; index < facePositions.count; index += 1) {
  const x = facePositions.getX(index);
  const y = facePositions.getY(index);
  if (Math.abs(x) < 0.006) foreheadCenterY = Math.max(foreheadCenterY, y);
  if (Math.abs(x) > 0.04 && Math.abs(x) < 0.11) foreheadLobeY = Math.max(foreheadLobeY, y);
}
assert.ok(foreheadLobeY - foreheadCenterY > 0.04,
  'cream face outline leaves a rounded area of black head between the forehead lobes');

assert.ok(joints.head, 'candidate exposes a head joint');
assert.ok(tail, 'candidate includes a short black tail feather');
assert.equal(tail.material, hero.getObjectByName('CandidateLeftFlipper').material,
  'tail uses the same black feather material as the penguin body and flippers');
assert.ok(tail.position.z < -0.2 && tail.rotation.x > 0,
  'tail root is embedded behind the lower torso and points backward');
assert.equal(joints.tail, tail, 'candidate exposes the tail for future animation refinement');
assert.ok(joints.leftShoulder, 'candidate exposes a left shoulder joint');
assert.ok(joints.rightShoulder, 'candidate exposes a right shoulder joint');
assert.ok(joints.rightHand, 'candidate exposes a separate sword hand joint');
assert.ok(joints.leftAnkle, 'candidate exposes a left ankle joint');
assert.ok(joints.rightAnkle, 'candidate exposes a right ankle joint');
assert.equal(joints.sword.parent, joints.rightHand, 'sword follows the separate right hand joint');
assert.ok(swordHandle && gripHand, 'candidate exposes a visible handle and gripping hand');
assert.equal(swordHandle.parent, joints.sword, 'sword is anchored at the handle centre');
assert.ok(joints.rightHand.position.length() > 0.5, 'grip joint sits at the flipper tip');

hero.userData.animate(2);
hero.userData.playAction('move', 1);
hero.userData.animate(2.125);
assert.notEqual(joints.leftAnkle.position.y, joints.rightAnkle.position.y, 'walk cycle lifts feet independently');
assert.notEqual(joints.leftShoulder.rotation.x, joints.rightShoulder.rotation.x, 'walk cycle counter-swings shoulders');

hero.userData.animate(3);
hero.updateMatrixWorld(true);
const idleShoulderPosition = joints.rightShoulder.position.clone();
const idleHandWorldPosition = joints.rightHand.getWorldPosition(new THREE.Vector3());
hero.userData.previewAction('jump_attack', 0.28);
hero.userData.animate(3);
hero.updateMatrixWorld(true);
const windupHandWorldPosition = joints.rightHand.getWorldPosition(new THREE.Vector3());
hero.userData.previewAction('jump_attack', 0.58);
hero.userData.animate(3);
hero.updateMatrixWorld(true);
const attackHandWorldPosition = joints.rightHand.getWorldPosition(new THREE.Vector3());
const attackBladeDirection = new THREE.Vector3(0, 1, 0)
  .applyQuaternion(joints.sword.getWorldQuaternion(new THREE.Quaternion()))
  .normalize();
assert.ok(joints.rightShoulder.position.distanceTo(idleShoulderPosition) < 0.0001, 'sword shoulder position stays fixed');
assert.ok(windupHandWorldPosition.z < idleHandWorldPosition.z - 0.15,
  'windup carries the sword hand behind the torso');
assert.ok(attackHandWorldPosition.z > idleHandWorldPosition.z + 0.25,
  'contact carries the sword hand decisively into the space in front of the torso');
assert.ok(attackHandWorldPosition.z - windupHandWorldPosition.z > 0.5,
  'slash traces a substantial back-to-front arc in depth');
assert.ok(attackBladeDirection.z > 0.75 && Math.abs(attackBladeDirection.x) < 0.25,
  'blade tip still points into the target space instead of sideways at contact');
assert.ok(attackBladeDirection.y > 0.35 && attackBladeDirection.y < 0.65,
  'contact pose aims the sword diagonally upward instead of straight forward');

hero.userData.animate(4);
hero.userData.playAction('hit', 1);
hero.userData.animate(4.5);
assert.notEqual(joints.leftAnkle.position.z, joints.rightAnkle.position.z, 'hit reaction staggers feet independently');
assert.notEqual(joints.leftShoulder.rotation.z, joints.rightShoulder.rotation.z, 'hit reaction separates flipper poses');

hero.userData.animate(5);
hero.updateMatrixWorld(true);
const castIdleBladeDirection = new THREE.Vector3(0, 1, 0)
  .applyQuaternion(joints.sword.getWorldQuaternion(new THREE.Quaternion()))
  .normalize();
hero.userData.previewAction('hex_blast_cast', 0.24);
hero.userData.animate(5);
hero.updateMatrixWorld(true);
const castBladeDirection = new THREE.Vector3(0, 1, 0)
  .applyQuaternion(joints.sword.getWorldQuaternion(new THREE.Quaternion()))
  .normalize();
assert.ok(joints.leftShoulder.rotation.z < -0.6,
  'hex blast cast opens the free flipper into a readable bracing pose');
assert.ok(castBladeDirection.y < -0.45 && castBladeDirection.z > 0.45,
  'hex blast cast plants the sword diagonally toward the board in front of the penguin');
assert.ok(castBladeDirection.distanceTo(castIdleBladeDirection) > 0.8,
  'hex blast cast produces a real weapon pose change rather than whole-body wobble');
assert.equal(joints.leftAnkle.position.y, 0.1,
  'hex blast cast keeps the left foot planted instead of jumping');
assert.equal(joints.rightAnkle.position.y, 0.1,
  'hex blast cast keeps the right foot planted instead of jumping');

hero.userData.previewAction('life_drain_cast', 0.38);
hero.userData.animate(6);
const drainReachX = joints.leftShoulder.rotation.x;
hero.userData.previewAction('life_drain_cast', 0.7);
hero.userData.animate(6);
assert.ok(drainReachX < -0.6 && joints.leftShoulder.rotation.x > 0.05,
  'life drain cast reaches outward and then pulls the free flipper back to the chest');
assert.equal(joints.leftAnkle.position.y, 0.1,
  'life drain cast keeps the left foot planted');
assert.equal(joints.rightAnkle.position.y, 0.1,
  'life drain cast keeps the right foot planted');

console.log('hero candidate joint rig tests passed');
