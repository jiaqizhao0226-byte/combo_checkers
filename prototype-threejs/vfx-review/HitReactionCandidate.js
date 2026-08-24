import * as THREE from '../vendor/three.module.js';

const clamp01 = value => Math.max(0, Math.min(1, value));
const pulse = (value, start, end) => {
  const t = clamp01((value - start) / Math.max(0.0001, end - start));
  return Math.sin(t * Math.PI);
};

export class HitReactionCandidate {
  constructor(scene, model, mount) {
    this.root = new THREE.Group();
    this.root.name = 'ReviewOnly_HitReactionCandidateI';
    scene.add(this.root);
    this.model = model;
    this.mount = mount;
    this.basePosition = mount.position.clone();
    this.baseRotationY = mount.rotation.y;
    this.baseRotationZ = mount.rotation.z;
    this.rig = model.getObjectByName('PenguinCandidateRig');
    this.joints = model.userData.joints || {};
    this.bodyPivot = new THREE.Group();
    this.bodyPivot.name = 'ReviewOnly_GroundedUpperBodyPivot';
    if (this.rig) {
      this.rig.add(this.bodyPivot);
      const groundedParts = new Set([this.joints.leftAnkle, this.joints.rightAnkle]);
      [...this.rig.children].forEach(child => {
        if (child !== this.bodyPivot && !groundedParts.has(child)) this.bodyPivot.add(child);
      });
    }
    this.active = null;
  }

  restore() {
    this.mount.position.copy(this.basePosition);
    this.mount.rotation.y = this.baseRotationY;
    this.mount.rotation.z = this.baseRotationZ;
    if (this.bodyPivot) {
      this.bodyPivot.position.set(0, 0, 0);
      this.bodyPivot.rotation.set(0, 0, 0);
    }
  }

  play({ direction = new THREE.Vector3(1, 0, 0), playbackSpeed = 1 } = {}) {
    this.restore();
    const recoilDirection = direction.clone().setY(0).normalize();
    if (recoilDirection.lengthSq() < 0.001) recoilDirection.set(1, 0, 0);
    this.active = {
      elapsed: 0,
      duration: 0.58,
      direction: recoilDirection,
      playbackSpeed: Math.max(0.1, playbackSpeed),
    };
  }

  update(delta) {
    if (!this.active) return;
    this.active.elapsed += Math.max(0, delta);
    const progress = clamp01(this.active.elapsed / this.active.duration);
    // Five overlapping beats make the hit read as a short loss of balance:
    // contact snap -> backward skid -> off-axis stagger -> recovery step -> settle.
    const contactSnap = pulse(progress, 0, 0.26);
    const bodyStagger = pulse(progress, 0.08, 0.72);
    const headLag = pulse(progress, 0.035, 0.48);
    const freeArmFlail = pulse(progress, 0.08, 0.68);
    const rearFootSlip = pulse(progress, 0.02, 0.5);
    const recoveryStep = pulse(progress, 0.42, 0.9);
    const settle = pulse(progress, 0.72, 1);
    const recoil = contactSnap * 0.105 + bodyStagger * 0.07 - recoveryStep * 0.018 - settle * 0.012;
    const sideDirection = new THREE.Vector3(-this.active.direction.z, 0, this.active.direction.x);
    this.mount.position.copy(this.basePosition).addScaledVector(this.active.direction, recoil);
    this.mount.position.addScaledVector(sideDirection, bodyStagger * 0.045 - recoveryStep * 0.025);
    // Keep the character's centre of mass grounded. Individual feet may lift
    // for the recovery step, but the penguin itself never hops on impact.
    this.mount.position.y = this.basePosition.y;
    this.mount.rotation.y = this.baseRotationY + bodyStagger * 0.045 - recoveryStep * 0.018;
    this.mount.rotation.z = this.baseRotationZ;

    if (this.rig) {
      // Cancel the penguin's idle breathing lift during the reaction so its
      // feet and centre of mass stay visually pinned to the board.
      this.rig.position.y = 0;
      this.rig.position.x += bodyStagger * 0.035 - recoveryStep * 0.018;
      this.rig.position.z -= contactSnap * 0.03 + bodyStagger * 0.018;
      this.rig.scale.x *= 1 + contactSnap * 0.035 - bodyStagger * 0.012;
      this.rig.scale.z *= 1 + contactSnap * 0.025;
    }
    if (this.bodyPivot) {
      // Tilt only the torso around a foot-level pivot. The ankles remain
      // outside this group, so a stronger fall never lifts the whole penguin.
      this.bodyPivot.rotation.x = -contactSnap * 0.2 - bodyStagger * 0.14 + recoveryStep * 0.045;
      this.bodyPivot.rotation.z = contactSnap * 0.075 - bodyStagger * 0.18 + recoveryStep * 0.065;
    }
    const { head, leftShoulder, leftAnkle, rightAnkle } = this.joints;
    if (head) {
      head.rotation.x += -headLag * 0.34 + recoveryStep * 0.075;
      head.rotation.y += headLag * 0.075 - recoveryStep * 0.03;
      head.rotation.z += contactSnap * 0.07 - headLag * 0.12 + settle * 0.035;
    }
    if (leftShoulder) {
      leftShoulder.rotation.x -= freeArmFlail * 0.32 - recoveryStep * 0.08;
      leftShoulder.rotation.y += freeArmFlail * 0.1;
      leftShoulder.rotation.z -= contactSnap * 0.18 + freeArmFlail * 0.62 - recoveryStep * 0.12;
    }
    if (leftAnkle) {
      // Both feet remain on the board; the planted foot only slides and rolls.
      leftAnkle.position.x -= rearFootSlip * 0.035;
      leftAnkle.position.z -= rearFootSlip * 0.085 - recoveryStep * 0.035;
      leftAnkle.rotation.x += rearFootSlip * 0.18 - recoveryStep * 0.14;
      leftAnkle.rotation.z -= bodyStagger * 0.1;
    }
    if (rightAnkle) {
      // The opposite foot performs a flat recovery slide without lifting.
      rightAnkle.position.x += bodyStagger * 0.045;
      rightAnkle.position.z += rearFootSlip * 0.075 - recoveryStep * 0.08;
      rightAnkle.rotation.x -= rearFootSlip * 0.24;
      rightAnkle.rotation.z += bodyStagger * 0.14 - recoveryStep * 0.08;
    }

    if (progress < 1) return;
    this.restore();
    this.active = null;
  }

  clear() {
    this.restore();
    this.active = null;
  }
}
