import assert from 'node:assert/strict';
import * as THREE from '../vendor/three.module.js';
import { createPenguinCandidate } from '../hero-review/PenguinCandidate.js';

const hero = createPenguinCandidate();
const joints = hero.userData.joints;
const beak = hero.getObjectByName('CandidateClosedBeak');
const swordHandle = hero.getObjectByName('CandidateSwordHandle');
const gripHand = hero.getObjectByName('CandidateSwordGripHand');

assert.ok(beak, 'candidate exposes a closed beak mesh');
assert.equal(beak.material.transparent, false, 'beak material remains opaque');
assert.equal(beak.material.opacity, 1, 'beak material uses full opacity');
assert.equal(beak.geometry.type, 'SphereGeometry', 'beak uses a closed rounded mesh');
assert.ok(beak.scale.y < beak.scale.x && beak.scale.z < beak.scale.x,
  'beak is flattened into a short oval instead of a square front plate');

assert.ok(joints.head, 'candidate exposes a head joint');
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

console.log('hero candidate joint rig tests passed');
