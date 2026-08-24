import * as THREE from '../vendor/three.module.js';
import { createTrackingDart, faceProjectileAlongScreen } from '../src/vfx/ProjectileModels.js?v=20260821c';

const clamp01 = value => Math.max(0, Math.min(1, value));
const easeOutCubic = value => 1 - Math.pow(1 - clamp01(value), 3);
const easeOutQuad = value => 1 - Math.pow(1 - clamp01(value), 2);
// Stop the hub near the slime shell while allowing the four blades to overlap
// the body silhouette. The dart is hidden immediately on contact, so the hit
// reads as forceful without leaving the weapon embedded in the enemy.
const TRACKING_DART_ENEMY_CONTACT_OFFSET = 0.62;

function canvasTexture(draw, width = 512, height = 256) {
  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  const context = canvas.getContext('2d');
  context.clearRect(0, 0, width, height);
  draw(context, width, height);
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.minFilter = THREE.LinearFilter;
  texture.magFilter = THREE.LinearFilter;
  texture.generateMipmaps = false;
  return texture;
}

function resultTexture(mode) {
  const settings = {
    enemy: { label: '-30', color: '#ffc35b' },
    item: { label: '自动拾取', color: '#ffe58a' },
    heal: { label: '+15', color: '#81ffd0' },
  }[mode];
  return canvasTexture((context, width, height) => {
    context.textAlign = 'center';
    context.textBaseline = 'middle';
    context.shadowColor = 'rgba(6, 22, 26, .55)';
    context.shadowBlur = 10;
    context.shadowOffsetY = 5;
    context.fillStyle = settings.color;
    context.font = `900 ${mode === 'item' ? 64 : 92}px Inter, "PingFang SC", sans-serif`;
    context.fillText(settings.label, width * 0.5, height * 0.48);
  });
}

function additiveMaterial(color, opacity = 1) {
  return new THREE.MeshBasicMaterial({
    color,
    transparent: true,
    opacity,
    depthWrite: false,
    depthTest: false,
    blending: THREE.AdditiveBlending,
    toneMapped: false,
  });
}

function disposeObject(root) {
  root.traverse(child => {
    if (child.geometry?.dispose) child.geometry.dispose();
    if (Array.isArray(child.material)) child.material.forEach(material => material.dispose?.());
    else child.material?.dispose?.();
  });
}

export class TrackingDartRewardCandidate {
  constructor(scene) {
    this.root = new THREE.Group();
    this.root.name = 'ReviewOnly_TrackingDartRewardCandidateA';
    scene.add(this.root);
    this.effects = [];
    this._dummy = new THREE.Object3D();
    this._up = new THREE.Vector3(0, 1, 0);
  }

  play({ from, to, camera, mode = 'enemy', onContact = null }) {
    const group = new THREE.Group();
    group.name = `TwoComboTrackingDart_${mode}`;
    this.root.add(group);

    const dart = createTrackingDart(0xffb64c);
    dart.name = 'TwoComboTrackingShuriken';
    dart.position.copy(from);
    dart.scale.setScalar(0.94);
    dart.renderOrder = 48;
    group.add(dart);
    const dartMaterials = [];
    const seenDartMaterials = new Set();
    dart.traverse(child => {
      const materials = Array.isArray(child.material) ? child.material : [child.material];
      materials.filter(Boolean).forEach(material => {
        if (seenDartMaterials.has(material)) return;
        seenDartMaterials.add(material);
        material.transparent = true;
        dartMaterials.push({ material, baseOpacity: material.opacity });
      });
    });

    const targetCenter = to.clone();
    const incoming = targetCenter.clone().sub(from).setY(0).normalize();
    if (incoming.lengthSq() < 0.001) incoming.set(1, 0, 0);
    const flightTarget = mode === 'enemy'
      ? targetCenter.clone().addScaledVector(incoming, -TRACKING_DART_ENEMY_CONTACT_OFFSET)
      : targetCenter.clone();

    const impact = new THREE.Group();
    impact.name = 'TrackingDartContact';
    impact.visible = false;
    impact.position.copy(mode === 'heal' ? from : flightTarget);
    group.add(impact);
    const impactColor = mode === 'heal' ? 0x6effc6 : mode === 'item' ? 0xffdd72 : 0xffa43c;
    const flashMaterial = additiveMaterial(impactColor, 1);
    const flash = new THREE.Mesh(new THREE.SphereGeometry(0.12, 8, 6), flashMaterial);
    flash.name = 'TrackingDartContactFlash';
    flash.renderOrder = 54;
    impact.add(flash);
    let impactLight = null;
    if (mode === 'enemy') {
      impactLight = new THREE.PointLight(0xff9d3e, 0, 2.6, 2);
      impactLight.name = 'TrackingDartWarmContactLight';
      impactLight.position.set(0, 0.08, 0.16);
      impact.add(impactLight);
    }
    const shardMaterial = additiveMaterial(impactColor, 1);
    const shardCount = mode === 'enemy' ? 11 : 7;
    const shards = new THREE.InstancedMesh(new THREE.BoxGeometry(0.025, 0.18, 0.025), shardMaterial, shardCount);
    shards.name = 'TrackingDartDirectionalSparks';
    shards.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
    shards.frustumCulled = false;
    shards.renderOrder = 53;
    impact.add(shards);
    const lateral = new THREE.Vector3(-incoming.z, 0, incoming.x);
    const shardData = Array.from({ length: shardCount }, (_, index) => ({
      direction: incoming.clone().multiplyScalar(-0.42 - (index % 3) * 0.09)
        .addScaledVector(lateral, (index - (shardCount - 1) * 0.5) * 0.16)
        .add(new THREE.Vector3(0, 0.08 + (index % 4) * 0.08, 0)).normalize(),
      speed: 0.5 + (index % 3) * 0.14,
      spin: index * 1.47,
    }));

    const resultMap = resultTexture(mode);
    const resultMaterial = new THREE.SpriteMaterial({
      map: resultMap,
      transparent: true,
      opacity: 0,
      depthWrite: false,
      depthTest: false,
      toneMapped: false,
    });
    const result = new THREE.Sprite(resultMaterial);
    result.name = 'TrackingDartResultLabel';
    result.position.copy(mode === 'heal' ? from : targetCenter).add(new THREE.Vector3(0, mode === 'item' ? 0.92 : 1.2, 0));
    result.center.set(0.5, 0.3);
    result.scale.set(0.001, 0.001, 1);
    result.renderOrder = 72;
    group.add(result);

    // Match the original Lua presentation: the projectile launches immediately,
    // reaches the target during the first 80% of a 0.6s VFX, then fades out.
    const flightStart = 0;
    const travelEnd = 0.48;
    const flightEnd = 0.6;
    const contactEnd = 1.36;
    this.effects.push({
      group, dart, impact, flash, flashMaterial,
      impactLight,
      shards, shardMaterial, shardData, result, resultMaterial, resultMap, dartMaterials,
      from: from.clone(), to: flightTarget, targetCenter, incoming, lateral, camera, mode, onContact,
      flightStart, travelEnd, flightEnd, contactEnd, elapsed: 0, duration: 1.52, contactFired: false,
    });
  }

  sampleFlight(effect, progress) {
    const t = easeOutQuad(progress);
    if (effect.mode === 'heal') {
      const start = effect.from;
      const outward = start.clone().add(new THREE.Vector3(1.55, 1.0, -0.38));
      const returnArc = start.clone().add(new THREE.Vector3(-1.15, 0.78, -0.62));
      const oneMinus = 1 - t;
      return start.clone().multiplyScalar(oneMinus * oneMinus * oneMinus)
        .add(outward.clone().multiplyScalar(3 * oneMinus * oneMinus * t))
        .add(returnArc.clone().multiplyScalar(3 * oneMinus * t * t))
        .add(start.clone().multiplyScalar(t * t * t));
    }
    const midpoint = effect.from.clone().lerp(effect.to, 0.5);
    const forward = effect.to.clone().sub(effect.from).setY(0).normalize();
    const lateral = new THREE.Vector3(-forward.z, 0, forward.x);
    const control = midpoint.addScaledVector(lateral, 0.38).add(new THREE.Vector3(0, 1.08, 0));
    const oneMinus = 1 - t;
    return effect.from.clone().multiplyScalar(oneMinus * oneMinus)
      .add(control.multiplyScalar(2 * oneMinus * t))
      .add(effect.to.clone().multiplyScalar(t * t));
  }

  update(delta) {
    for (let index = this.effects.length - 1; index >= 0; index -= 1) {
      const effect = this.effects[index];
      effect.elapsed += Math.max(0, delta);
      const progress = clamp01(effect.elapsed / effect.duration);

      if (effect.elapsed < effect.flightEnd) {
        const flight = clamp01((effect.elapsed - effect.flightStart) / (effect.travelEnd - effect.flightStart));
        const vfxProgress = clamp01(effect.elapsed / effect.flightEnd);
        const fade = vfxProgress < 0.85 ? 1 : clamp01((1 - vfxProgress) / 0.15);
        const position = this.sampleFlight(effect, flight);
        const next = this.sampleFlight(effect, Math.min(1, flight + 0.025));
        effect.dart.position.copy(position);
        effect.dart.scale.setScalar(0.94 + Math.sin(flight * Math.PI) * 0.08);
        if (flight < 1) faceProjectileAlongScreen(effect.dart, next.sub(position), effect.camera);
        effect.dart.userData.rotor.rotation.z += delta * 8.5;
        effect.dartMaterials.forEach(({ material, baseOpacity }) => {
          material.opacity = baseOpacity * fade;
        });
        effect.dart.userData.trailMaterial.opacity = 0.72 * Math.min(1, flight * 6) * fade;
      } else {
        if (!effect.contactFired) {
          effect.contactFired = true;
          effect.impact.visible = true;
          effect.dart.position.copy(effect.to);
          effect.dart.userData.trailMaterial.opacity = 0;
          effect.onContact?.(effect.mode);
        }
      }

      if (effect.contactFired) {
        const contact = clamp01((effect.elapsed - effect.flightEnd) / (effect.contactEnd - effect.flightEnd));
        effect.dart.visible = false;
        const flashPop = easeOutCubic(Math.min(1, contact * 5));
        effect.flash.scale.setScalar(0.28 + flashPop * 0.9);
        effect.flashMaterial.opacity = Math.max(0, 1 - contact * 4.3);
        if (effect.impactLight) {
          effect.impactLight.intensity = Math.max(0, 3.2 * (1 - contact * 5.4));
        }
        effect.shardData.forEach((shard, shardIndex) => {
          this._dummy.position.copy(shard.direction).multiplyScalar(easeOutCubic(contact) * shard.speed);
          this._dummy.position.y -= contact * contact * 0.12;
          this._dummy.quaternion.setFromUnitVectors(this._up, shard.direction);
          this._dummy.rotateY(shard.spin + contact * 2.4);
          const scale = Math.max(0.03, 1 - contact) * (0.75 + (shardIndex % 3) * 0.11);
          this._dummy.scale.set(scale * 0.8, scale * 1.25, scale * 0.8);
          this._dummy.updateMatrix();
          effect.shards.setMatrixAt(shardIndex, this._dummy.matrix);
        });
        effect.shards.instanceMatrix.needsUpdate = true;
        effect.shardMaterial.opacity = Math.max(0, 1 - contact * 1.18);

        const labelProgress = clamp01(contact * 1.45);
        const labelScale = easeOutCubic(Math.min(1, labelProgress * 3.5));
        effect.result.scale.set(1.22 * labelScale, 0.61 * labelScale, 1);
        effect.result.position.y += delta * 0.36;
        effect.resultMaterial.opacity = contact < 0.72 ? 1 : Math.max(0, (1 - contact) / 0.28);
      }

      if (progress < 1) continue;
      this.disposeEffect(effect);
      this.effects.splice(index, 1);
    }
  }

  disposeEffect(effect) {
    this.root.remove(effect.group);
    effect.resultMap.dispose();
    disposeObject(effect.group);
  }

  clear() {
    while (this.effects.length) this.disposeEffect(this.effects.pop());
  }
}
