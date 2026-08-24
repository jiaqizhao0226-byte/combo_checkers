import * as THREE from '../vendor/three.module.js';

const clamp01 = value => Math.max(0, Math.min(1, value));
const easeOutCubic = value => 1 - Math.pow(1 - clamp01(value), 3);

function material(color, opacity = 1) {
  return new THREE.MeshBasicMaterial({
    color,
    transparent: true,
    opacity,
    depthWrite: false,
    depthTest: false,
    side: THREE.DoubleSide,
    blending: THREE.AdditiveBlending,
    toneMapped: false,
  });
}

function taperedCutGeometry(length = 1.1, width = 0.13) {
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.Float32BufferAttribute([
    -length * 0.54, -width * 0.08, 0,
    -length * 0.22, width, 0,
    length * 0.54, width * 0.02, 0,
    -length * 0.54, -width * 0.08, 0,
    length * 0.54, width * 0.02, 0,
    -length * 0.18, -width * 0.55, 0,
  ], 3));
  geometry.computeBoundingSphere();
  return geometry;
}

function screenAngle(direction, camera) {
  camera.updateMatrixWorld();
  const forward = direction.clone().setY(0).normalize();
  const right = new THREE.Vector3().setFromMatrixColumn(camera.matrixWorld, 0).normalize();
  const up = new THREE.Vector3().setFromMatrixColumn(camera.matrixWorld, 1).normalize();
  return Math.atan2(forward.dot(up), forward.dot(right));
}

export class MeleeImpactCandidate {
  constructor(scene) {
    this.root = new THREE.Group();
    this.root.name = 'ReviewOnly_MeleeImpactCandidateA';
    scene.add(this.root);
    this.effects = [];
    this.cutGeometry = taperedCutGeometry();
    this.shardGeometry = new THREE.OctahedronGeometry(0.055, 0);
    this.flashGeometry = new THREE.OctahedronGeometry(0.18, 0);
    this._dummy = new THREE.Object3D();
  }

  play({ position, direction, camera }) {
    const group = new THREE.Group();
    group.position.copy(position);
    group.name = 'MeleeContactCandidateA';
    this.root.add(group);

    const outerMaterial = material(0xffa43c, 0.92);
    const coreMaterial = material(0xfff3c0, 1);
    const flashMaterial = material(0xffd36a, 1);
    const shardMaterial = material(0xffb548, 1);
    const angle = screenAngle(direction, camera) + 0.34;

    const cut = new THREE.Mesh(this.cutGeometry, outerMaterial);
    cut.name = 'DirectionalCut';
    cut.quaternion.copy(camera.quaternion);
    cut.rotateZ(angle);
    cut.renderOrder = 41;
    group.add(cut);

    const core = new THREE.Mesh(this.cutGeometry, coreMaterial);
    core.name = 'CutCore';
    core.quaternion.copy(camera.quaternion);
    core.rotateZ(angle);
    core.renderOrder = 42;
    group.add(core);

    const flash = new THREE.Mesh(this.flashGeometry, flashMaterial);
    flash.name = 'ContactFlash';
    flash.quaternion.copy(camera.quaternion);
    flash.renderOrder = 43;
    group.add(flash);

    const shardCount = 9;
    const shards = new THREE.InstancedMesh(this.shardGeometry, shardMaterial, shardCount);
    shards.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
    shards.frustumCulled = false;
    shards.renderOrder = 42;
    group.add(shards);

    const forward = direction.clone().setY(0).normalize();
    if (forward.lengthSq() < 0.001) forward.set(1, 0, 0);
    const lateral = new THREE.Vector3(-forward.z, 0, forward.x);
    const shardData = Array.from({ length: shardCount }, (_, index) => {
      const centered = index - (shardCount - 1) * 0.5;
      const side = centered / Math.max(1, shardCount - 1);
      return {
        vector: forward.clone().multiplyScalar(0.72 + (index % 3) * 0.12)
          .addScaledVector(lateral, side * 0.95)
          .add(new THREE.Vector3(0, 0.28 + (index % 4) * 0.14, 0))
          .normalize(),
        speed: 0.52 + (index % 3) * 0.16,
        spin: index * 1.71,
        scale: 0.72 + (index % 4) * 0.16,
      };
    });

    this.effects.push({
      group,
      elapsed: 0,
      duration: 0.29,
      cut,
      core,
      flash,
      shards,
      outerMaterial,
      coreMaterial,
      flashMaterial,
      shardMaterial,
      shardData,
    });
  }

  update(delta) {
    for (let index = this.effects.length - 1; index >= 0; index -= 1) {
      const effect = this.effects[index];
      effect.elapsed += Math.max(0, delta);
      const progress = clamp01(effect.elapsed / effect.duration);
      const snap = easeOutCubic(Math.min(1, progress * 3.2));
      const fade = 1 - easeOutCubic(clamp01((progress - 0.18) / 0.82));

      effect.cut.scale.set(0.14 + snap * 0.86, 1.04 - snap * 0.14, 1);
      effect.core.scale.set(0.09 + snap * 0.7, 0.27, 1);
      effect.outerMaterial.opacity = fade * 0.9;
      effect.coreMaterial.opacity = fade;

      const flashPop = easeOutCubic(Math.min(1, progress * 4.8));
      effect.flash.scale.set(0.35 + flashPop * 1.42, 0.35 + flashPop * 0.9, 0.35);
      effect.flashMaterial.opacity = Math.max(0, 1 - progress * 3.6);

      effect.shardData.forEach((shard, shardIndex) => {
        const travel = easeOutCubic(progress) * shard.speed;
        this._dummy.position.copy(shard.vector).multiplyScalar(travel);
        this._dummy.position.y -= progress * progress * 0.16;
        this._dummy.rotation.set(shard.spin + progress * 6, progress * 8 + shardIndex, progress * 4);
        const scale = shard.scale * Math.max(0.04, 1 - progress);
        this._dummy.scale.set(scale * 1.75, scale * 0.5, scale * 0.5);
        this._dummy.updateMatrix();
        effect.shards.setMatrixAt(shardIndex, this._dummy.matrix);
      });
      effect.shards.instanceMatrix.needsUpdate = true;
      effect.shardMaterial.opacity = Math.max(0, 1 - progress * 1.12);

      if (progress < 1) continue;
      this.root.remove(effect.group);
      [effect.outerMaterial, effect.coreMaterial, effect.flashMaterial, effect.shardMaterial].forEach(item => item.dispose());
      this.effects.splice(index, 1);
    }
  }

  clear() {
    while (this.effects.length) {
      const effect = this.effects.pop();
      this.root.remove(effect.group);
      [effect.outerMaterial, effect.coreMaterial, effect.flashMaterial, effect.shardMaterial].forEach(item => item.dispose());
    }
  }
}
