import * as THREE from '../../vendor/three.module.js';

const TAU = Math.PI * 2;
const clamp01 = value => Math.max(0, Math.min(1, value));
const easeOutCubic = value => 1 - Math.pow(1 - clamp01(value), 3);
const easeOutBack = value => {
  const t = clamp01(value) - 1;
  return 1 + 2.70158 * t * t * t + 1.70158 * t * t;
};

function seededNoise(index, seed = 1) {
  const value = Math.sin(index * 91.733 + seed * 47.221) * 43758.5453;
  return value - Math.floor(value);
}

function vfxMaterial(color, opacity = 1, options = {}) {
  return new THREE.MeshBasicMaterial({
    color,
    transparent: true,
    opacity,
    depthWrite: false,
    depthTest: options.depthTest !== false,
    side: options.side ?? THREE.DoubleSide,
    blending: options.blending ?? THREE.AdditiveBlending,
    toneMapped: false,
  });
}

function disposeMaterial(material) {
  if (!material) return;
  if (Array.isArray(material)) material.forEach(disposeMaterial);
  else material.dispose?.();
}

function makeRibbonGeometry(points, width, camera) {
  const positions = [];
  const viewDirection = new THREE.Vector3();
  camera.getWorldDirection(viewDirection).normalize();
  const tangent = new THREE.Vector3();
  const side = new THREE.Vector3();
  const left = [];
  const right = [];

  for (let index = 0; index < points.length; index += 1) {
    const previous = points[Math.max(0, index - 1)];
    const next = points[Math.min(points.length - 1, index + 1)];
    tangent.copy(next).sub(previous).normalize();
    side.crossVectors(tangent, viewDirection).normalize();
    if (side.lengthSq() < 0.001) side.set(1, 0, 0);
    const taper = Math.sin(index / Math.max(1, points.length - 1) * Math.PI) * 0.28 + 0.72;
    left.push(points[index].clone().addScaledVector(side, width * taper));
    right.push(points[index].clone().addScaledVector(side, -width * taper));
  }

  for (let index = 0; index < points.length - 1; index += 1) {
    const a = left[index]; const b = right[index];
    const c = left[index + 1]; const d = right[index + 1];
    positions.push(
      a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z,
      b.x, b.y, b.z, d.x, d.y, d.z, c.x, c.y, c.z
    );
  }

  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
  geometry.computeBoundingSphere();
  return geometry;
}

function makeBladeStreakGeometry(length = 1.5, width = 0.16) {
  const half = length * 0.5;
  const shoulder = length * 0.12;
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.Float32BufferAttribute([
    -half, 0, 0, -shoulder, width, 0, half, 0, 0,
    -half, 0, 0, half, 0, 0, -shoulder, -width, 0,
  ], 3));
  geometry.computeBoundingSphere();
  return geometry;
}

function makeMeleeCutGeometry(length = 1.1, width = 0.13) {
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

function makeContactBurstGeometry(rays = 8, innerRadius = 0.13, outerRadius = 0.52) {
  const positions = [];
  const pointCount = rays * 2;
  for (let index = 0; index < pointCount; index += 1) {
    const next = (index + 1) % pointCount;
    const angle = index / pointCount * TAU;
    const nextAngle = next / pointCount * TAU;
    const radius = index % 2 === 0 ? outerRadius : innerRadius;
    const nextRadius = next % 2 === 0 ? outerRadius : innerRadius;
    positions.push(
      0, 0, 0,
      Math.cos(angle) * radius, Math.sin(angle) * radius, 0,
      Math.cos(nextAngle) * nextRadius, Math.sin(nextAngle) * nextRadius, 0
    );
  }
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
  geometry.computeBoundingSphere();
  return geometry;
}

function screenAngleForDirection(direction, camera) {
  camera.updateMatrixWorld();
  const forward = direction.clone().setY(0).normalize();
  if (forward.lengthSq() < 0.001) forward.set(1, 0, 0);
  const cameraRight = new THREE.Vector3().setFromMatrixColumn(camera.matrixWorld, 0).normalize();
  const cameraUp = new THREE.Vector3().setFromMatrixColumn(camera.matrixWorld, 1).normalize();
  return Math.atan2(forward.dot(cameraUp), forward.dot(cameraRight));
}

function jaggedPath(from, to, seed, steps = 10) {
  const direction = to.clone().sub(from);
  const length = direction.length();
  direction.normalize();
  const horizontal = new THREE.Vector3(-direction.z, 0, direction.x).normalize();
  if (horizontal.lengthSq() < 0.001) horizontal.set(1, 0, 0);
  const vertical = new THREE.Vector3().crossVectors(direction, horizontal).normalize();
  const points = [];
  for (let index = 0; index <= steps; index += 1) {
    const progress = index / steps;
    const envelope = Math.sin(progress * Math.PI);
    const lateral = (seededNoise(index * 2, seed) - 0.5) * length * 0.16 * envelope;
    const lift = (seededNoise(index * 2 + 1, seed) - 0.5) * length * 0.1 * envelope;
    points.push(from.clone().lerp(to, progress)
      .addScaledVector(horizontal, lateral)
      .addScaledVector(vertical, lift));
  }
  return points;
}

function quakeMaterial(color) {
  return new THREE.ShaderMaterial({
    uniforms: {
      uColor: { value: new THREE.Color(color) },
      uProgress: { value: 0 },
      uOpacity: { value: 1 },
    },
    vertexShader: `
      varying vec2 vUv;
      void main() {
        vUv = uv;
        gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
      }
    `,
    fragmentShader: `
      uniform vec3 uColor;
      uniform float uProgress;
      uniform float uOpacity;
      varying vec2 vUv;

      void main() {
        vec2 centered = (vUv - 0.5) * 2.0;
        float radius = length(centered);
        float waveRadius = mix(0.08, 0.92, uProgress);
        float ring = 1.0 - smoothstep(0.025, 0.095, abs(radius - waveRadius));
        float angle = atan(centered.y, centered.x);
        float fracture = pow(max(0.0, sin(angle * 9.0 + radius * 25.0)), 12.0);
        fracture *= smoothstep(waveRadius + 0.2, waveRadius - 0.15, radius);
        float core = (1.0 - smoothstep(0.0, 0.3, radius)) * (1.0 - uProgress);
        float alpha = (ring + fracture * 0.5 + core * 0.7) * uOpacity;
        if (alpha < 0.015) discard;
        gl_FragColor = vec4(uColor * (1.2 + ring * 1.4), alpha);
      }
    `,
    transparent: true,
    depthWrite: false,
    depthTest: true,
    side: THREE.DoubleSide,
    blending: THREE.AdditiveBlending,
    toneMapped: false,
  });
}

export class VfxDirector {
  constructor(scene, options = {}) {
    this.root = new THREE.Group();
    this.root.name = 'VfxDirector';
    scene.add(this.root);
    this.effects = [];
    this.onCameraImpulse = options.onCameraImpulse || (() => {});
    this.shared = {
      spark: new THREE.OctahedronGeometry(0.06, 0),
      mote: new THREE.IcosahedronGeometry(0.055, 0),
      flash: new THREE.IcosahedronGeometry(0.18, 1),
      bladeStreak: makeBladeStreakGeometry(),
      meleeCut: makeMeleeCutGeometry(),
      contactBurst: makeContactBurstGeometry(),
      groundPlane: new THREE.PlaneGeometry(2, 2),
      rock: new THREE.TetrahedronGeometry(0.12, 0),
    };
    this._dummy = new THREE.Object3D();
  }

  get activeCount() {
    return this.effects.length;
  }

  _add(root, duration, update, cleanup = {}) {
    this.root.add(root);
    this.effects.push({
      root,
      duration: Math.max(0.12, duration),
      elapsed: 0,
      update,
      materials: cleanup.materials || [],
      geometries: cleanup.geometries || [],
    });
    return root;
  }

  _remove(effect) {
    this.root.remove(effect.root);
    effect.materials.forEach(disposeMaterial);
    effect.geometries.forEach(geometry => geometry.dispose?.());
  }

  update(delta) {
    for (let index = this.effects.length - 1; index >= 0; index -= 1) {
      const effect = this.effects[index];
      effect.elapsed += Math.max(0, delta);
      const progress = clamp01(effect.elapsed / effect.duration);
      effect.update?.(progress, effect.elapsed, delta);
      if (progress < 1) continue;
      this._remove(effect);
      this.effects.splice(index, 1);
    }
  }

  clear() {
    while (this.effects.length) this._remove(this.effects.pop());
  }

  dispose() {
    this.clear();
    this.root.removeFromParent();
    Object.values(this.shared).forEach(geometry => geometry.dispose?.());
  }

  impact({ position, direction = new THREE.Vector3(1, 0, 0), camera }) {
    const root = new THREE.Group();
    root.name = 'ApprovedHeroMeleeImpact';
    root.position.copy(position);
    const cutMaterial = vfxMaterial(0xffa43c, 0.92, { depthTest: false });
    const coreMaterial = vfxMaterial(0xfff3c0, 1, { depthTest: false });
    const flashMaterial = vfxMaterial(0xffd36a, 1, { depthTest: false });
    const shardMaterial = vfxMaterial(0xffb548, 1, { depthTest: false });
    const angle = screenAngleForDirection(direction, camera) + 0.34;

    const cut = new THREE.Mesh(this.shared.meleeCut, cutMaterial);
    cut.name = 'DirectionalCut';
    cut.quaternion.copy(camera.quaternion);
    cut.rotateZ(angle);
    cut.renderOrder = 41;
    root.add(cut);

    const core = new THREE.Mesh(this.shared.meleeCut, coreMaterial);
    core.name = 'CutCore';
    core.quaternion.copy(camera.quaternion);
    core.rotateZ(angle);
    core.renderOrder = 42;
    root.add(core);

    const flash = new THREE.Mesh(this.shared.flash, flashMaterial);
    flash.name = 'ContactFlash';
    flash.quaternion.copy(camera.quaternion);
    flash.renderOrder = 43;
    root.add(flash);

    const count = 9;
    const shards = new THREE.InstancedMesh(this.shared.spark, shardMaterial, count);
    shards.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
    shards.frustumCulled = false;
    shards.renderOrder = 42;
    root.add(shards);

    const forward = direction.clone().setY(0).normalize();
    if (forward.lengthSq() < 0.001) forward.set(1, 0, 0);
    const lateral = new THREE.Vector3(-forward.z, 0, forward.x);
    const particles = Array.from({ length: count }, (_, index) => {
      const centered = index - (count - 1) * 0.5;
      const side = centered / Math.max(1, count - 1);
      return {
        direction: forward.clone().multiplyScalar(0.72 + (index % 3) * 0.12)
          .addScaledVector(lateral, side * 0.95)
          .add(new THREE.Vector3(0, 0.28 + (index % 4) * 0.14, 0))
          .normalize(),
        speed: 0.52 + (index % 3) * 0.16,
        spin: index * 1.71,
        scale: 0.72 + (index % 4) * 0.16,
      };
    });

    return this._add(root, 0.29, progress => {
      const snap = easeOutCubic(Math.min(1, progress * 3.2));
      const fade = 1 - easeOutCubic(clamp01((progress - 0.18) / 0.82));
      cut.scale.set(0.14 + snap * 0.86, 1.04 - snap * 0.14, 1);
      core.scale.set(0.09 + snap * 0.7, 0.27, 1);
      cutMaterial.opacity = fade * 0.9;
      coreMaterial.opacity = fade;

      const flashPop = easeOutCubic(Math.min(1, progress * 4.8));
      flash.scale.set(0.35 + flashPop * 1.42, 0.35 + flashPop * 0.9, 0.35);
      flashMaterial.opacity = Math.max(0, 1 - progress * 3.6);

      particles.forEach((particle, index) => {
        const travel = easeOutCubic(progress) * particle.speed;
        this._dummy.position.copy(particle.direction).multiplyScalar(travel);
        this._dummy.position.y -= progress * progress * 0.16;
        this._dummy.rotation.set(particle.spin + progress * 6, progress * 8 + index, progress * 4);
        const scale = particle.scale * Math.max(0.04, 1 - progress);
        this._dummy.scale.set(scale * 1.75, scale * 0.5, scale * 0.5);
        this._dummy.updateMatrix();
        shards.setMatrixAt(index, this._dummy.matrix);
      });
      shards.instanceMatrix.needsUpdate = true;
      shardMaterial.opacity = Math.max(0, 1 - progress * 1.12);
    }, { materials: [cutMaterial, coreMaterial, flashMaterial, shardMaterial] });
  }

  comboBurst({ position, camera, combo = 3 }) {
    const root = new THREE.Group();
    root.name = `ComboFinish${combo}`;
    root.position.copy(position);
    const slashCount = THREE.MathUtils.clamp(Math.round(combo), 2, 8);
    const colors = [0x7ff4ff, 0xffd46d, 0xc97cff, 0xff9f63, 0xf8f6cb];
    const slashMaterials = [];
    const slashes = [];
    for (let index = 0; index < slashCount; index += 1) {
      const material = vfxMaterial(colors[index % colors.length], 0, { depthTest: false });
      const slash = new THREE.Mesh(this.shared.bladeStreak, material);
      slash.name = `ComboCut${index + 1}`;
      slash.quaternion.copy(camera.quaternion);
      const layoutProgress = slashCount === 1 ? 0.5 : index / (slashCount - 1);
      const angle = (index % 2 === 0 ? -0.78 : 0.72) + (layoutProgress - 0.5) * 0.32;
      slash.rotateZ(angle);
      slash.position.set(
        (layoutProgress - 0.5) * 1.02,
        0.72 + Math.sin(layoutProgress * Math.PI) * 0.38,
        0
      );
      slash.renderOrder = 32 + index;
      root.add(slash);
      slashMaterials.push(material);
      slashes.push(slash);
    }

    const finishMaterial = vfxMaterial(0xfff2a8, 0, { depthTest: false });
    const finishBurst = new THREE.Mesh(this.shared.contactBurst, finishMaterial);
    finishBurst.name = 'ComboFinishBurst';
    finishBurst.quaternion.copy(camera.quaternion);
    finishBurst.position.y = 0.92;
    finishBurst.renderOrder = 39;
    root.add(finishBurst);

    const moteMaterial = vfxMaterial(0xffe88f, 0.95, { depthTest: false });
    const moteCount = 15 + slashCount * 2;
    const motes = new THREE.InstancedMesh(this.shared.mote, moteMaterial, moteCount);
    motes.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
    motes.frustumCulled = false;
    motes.renderOrder = 34;
    root.add(motes);
    const moteData = Array.from({ length: moteCount }, (_, index) => ({
      angle: seededNoise(index, 31) * TAU,
      radius: 0.35 + seededNoise(index, 37) * 0.95,
      height: seededNoise(index, 41) * 1.15,
      speed: 0.8 + seededNoise(index, 43) * 1.5,
      scale: 0.55 + seededNoise(index, 47) * 0.85,
    }));

    this.onCameraImpulse(0.045 + combo * 0.006, 0.24);
    const slashInterval = slashCount > 5 ? 0.09 : 0.13;
    const finishStartsAt = (slashCount - 1) * slashInterval + 0.22;
    return this._add(root, 0.98 + (slashCount - 1) * slashInterval, (progress, elapsed) => {
      slashes.forEach((slash, index) => {
        const local = clamp01((elapsed - index * slashInterval) / 0.5);
        const reveal = easeOutCubic(Math.min(1, local * 2.6));
        const fade = Math.sin(local * Math.PI);
        slash.scale.set(0.12 + reveal * (0.7 + slashCount * 0.035), 1.08 - reveal * 0.34, 1);
        slash.material.opacity = fade * 0.92;
      });
      const finish = clamp01((elapsed - finishStartsAt) / 0.58);
      const finishPop = easeOutBack(Math.min(1, finish * 2.5));
      finishBurst.scale.setScalar(0.1 + finishPop * (0.52 + slashCount * 0.065));
      finishMaterial.opacity = Math.sin(finish * Math.PI) * 0.95;
      moteData.forEach((mote, index) => {
        const angle = mote.angle + elapsed * mote.speed;
        const radius = mote.radius * (1 - progress * 0.35);
        this._dummy.position.set(Math.cos(angle) * radius, mote.height + finish * 1.25, Math.sin(angle) * radius);
        this._dummy.rotation.set(angle, elapsed * 4, angle * 0.5);
        const scale = mote.scale * Math.sin(Math.min(1, finish * 2.4) * Math.PI * 0.5) * Math.max(0.04, 1 - finish);
        this._dummy.scale.setScalar(scale);
        this._dummy.updateMatrix();
        motes.setMatrixAt(index, this._dummy.matrix);
      });
      motes.instanceMatrix.needsUpdate = true;
      moteMaterial.opacity = Math.max(0, 1 - finish * 0.92);
    }, { materials: [...slashMaterials, finishMaterial, moteMaterial] });
  }

  lightningChain({ points, camera }) {
    if (!points || points.length < 2) return null;
    const root = new THREE.Group();
    const outerMaterial = vfxMaterial(0x319eff, 0.72, { depthTest: false });
    const coreMaterial = vfxMaterial(0xeaffff, 1, { depthTest: false });
    const glowMaterial = vfxMaterial(0x8be8ff, 0.9, { depthTest: false });
    const geometries = [];
    const bolts = [];

    for (let index = 0; index < points.length - 1; index += 1) {
      const path = jaggedPath(points[index], points[index + 1], index + 5, 11);
      const outerGeometry = makeRibbonGeometry(path, 0.075, camera);
      const coreGeometry = makeRibbonGeometry(path, 0.024, camera);
      geometries.push(outerGeometry, coreGeometry);
      const outer = new THREE.Mesh(outerGeometry, outerMaterial);
      const core = new THREE.Mesh(coreGeometry, coreMaterial);
      outer.renderOrder = 38;
      core.renderOrder = 39;
      root.add(outer, core);
      bolts.push({ outer, core });
    }

    const nodes = new THREE.InstancedMesh(this.shared.flash, glowMaterial, points.length);
    nodes.frustumCulled = false;
    nodes.renderOrder = 40;
    points.forEach((point, index) => {
      this._dummy.position.copy(point);
      this._dummy.scale.setScalar(index === 0 ? 0.85 : 1.05);
      this._dummy.updateMatrix();
      nodes.setMatrixAt(index, this._dummy.matrix);
    });
    nodes.instanceMatrix.needsUpdate = true;
    root.add(nodes);

    this.onCameraImpulse(0.085, 0.28);
    const duration = 0.68 + Math.min(0.24, (bolts.length - 1) * 0.08);
    return this._add(root, duration, (progress, elapsed) => {
      const flicker = 0.72 + Math.sin(elapsed * 92) * 0.2 + Math.sin(elapsed * 151) * 0.08;
      bolts.forEach((bolt, index) => {
        const local = clamp01((elapsed - index * 0.08) / 0.48);
        const attack = Math.min(1, local * 7);
        const decay = Math.max(0, 1 - Math.max(0, local - 0.32) / 0.68);
        const pulse = 1 + Math.sin(elapsed * 54 + index) * 0.06;
        bolt.outer.material = outerMaterial;
        bolt.core.material = coreMaterial;
        bolt.outer.visible = local > 0 && decay > 0;
        bolt.core.visible = local > 0 && decay > 0;
        bolt.outer.scale.setScalar(pulse);
        bolt.core.scale.setScalar(2 - pulse);
        bolt.outer.userData.opacity = attack * decay * flicker * 0.7;
        bolt.core.userData.opacity = attack * decay * Math.min(1, flicker + 0.25);
      });
      // Shared materials cannot hold different per-segment opacity, so drive
      // the material from the newest active link; visibility still reveals
      // each connection in travel order instead of flashing the full chain.
      const activeBolt = [...bolts].reverse().find(bolt => bolt.outer.visible);
      outerMaterial.opacity = activeBolt?.outer.userData.opacity || 0;
      coreMaterial.opacity = activeBolt?.core.userData.opacity || 0;
      const chainDecay = Math.max(0, 1 - Math.max(0, progress - 0.5) / 0.5);
      glowMaterial.opacity = chainDecay * (0.55 + flicker * 0.35);
      nodes.scale.setScalar(0.8 + Math.sin(Math.min(1, progress * 3.2) * Math.PI) * 0.75);
    }, { materials: [outerMaterial, coreMaterial, glowMaterial], geometries });
  }

  quake({ position }) {
    const root = new THREE.Group();
    root.position.copy(position);
    const waveMaterial = quakeMaterial(0xffb14f);
    const wave = new THREE.Mesh(this.shared.groundPlane, waveMaterial);
    wave.rotation.x = -Math.PI * 0.5;
    wave.scale.setScalar(3.5);
    wave.position.y = 0.035;
    wave.renderOrder = 27;
    root.add(wave);

    const rockMaterial = vfxMaterial(0xffbf69, 0.92, { blending: THREE.NormalBlending });
    const rockCount = 18;
    const rocks = new THREE.InstancedMesh(this.shared.rock, rockMaterial, rockCount);
    rocks.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
    rocks.frustumCulled = false;
    rocks.renderOrder = 28;
    root.add(rocks);
    const rockData = Array.from({ length: rockCount }, (_, index) => ({
      angle: index / rockCount * TAU + (seededNoise(index, 53) - 0.5) * 0.28,
      radius: 0.65 + seededNoise(index, 59) * 1.8,
      height: 0.35 + seededNoise(index, 61) * 0.9,
      scale: 0.75 + seededNoise(index, 67) * 1.35,
      delay: seededNoise(index, 71) * 0.22,
      spin: seededNoise(index, 73) * TAU,
    }));

    const dustMaterial = vfxMaterial(0xf2c989, 0.48, { depthTest: false });
    const dustCount = 20;
    const dust = new THREE.InstancedMesh(this.shared.mote, dustMaterial, dustCount);
    dust.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
    dust.frustumCulled = false;
    dust.renderOrder = 29;
    root.add(dust);
    const dustData = Array.from({ length: dustCount }, (_, index) => ({
      angle: seededNoise(index, 79) * TAU,
      radius: 0.25 + seededNoise(index, 83) * 1.6,
      lift: 0.12 + seededNoise(index, 89) * 0.6,
      scale: 0.6 + seededNoise(index, 97) * 1.3,
    }));

    this.onCameraImpulse(0.14, 0.38);
    return this._add(root, 0.92, progress => {
      waveMaterial.uniforms.uProgress.value = easeOutCubic(progress);
      waveMaterial.uniforms.uOpacity.value = Math.max(0, 1 - progress * 0.82);
      rockData.forEach((rock, index) => {
        const local = clamp01((progress - rock.delay) / Math.max(0.01, 1 - rock.delay));
        const arc = Math.sin(local * Math.PI);
        this._dummy.position.set(
          Math.cos(rock.angle) * rock.radius * easeOutCubic(local),
          arc * rock.height - local * 0.12,
          Math.sin(rock.angle) * rock.radius * easeOutCubic(local)
        );
        this._dummy.rotation.set(rock.spin + local * 4, local * 6 + index, rock.spin * 0.5);
        const scale = rock.scale * Math.max(0.05, 1 - Math.max(0, local - 0.72) / 0.28);
        this._dummy.scale.setScalar(scale);
        this._dummy.updateMatrix();
        rocks.setMatrixAt(index, this._dummy.matrix);
      });
      rocks.instanceMatrix.needsUpdate = true;
      rockMaterial.opacity = Math.max(0, 1 - Math.max(0, progress - 0.74) / 0.26);
      dustData.forEach((mote, index) => {
        const distance = mote.radius * easeOutCubic(progress);
        this._dummy.position.set(Math.cos(mote.angle) * distance, mote.lift * Math.sin(progress * Math.PI), Math.sin(mote.angle) * distance);
        this._dummy.rotation.set(progress * 5 + index, mote.angle, 0);
        const scale = mote.scale * Math.sin(Math.min(1, progress * 2.8) * Math.PI * 0.5) * Math.max(0.02, 1 - progress);
        this._dummy.scale.setScalar(scale);
        this._dummy.updateMatrix();
        dust.setMatrixAt(index, this._dummy.matrix);
      });
      dust.instanceMatrix.needsUpdate = true;
      dustMaterial.opacity = Math.max(0, 0.48 * (1 - progress));
    }, { materials: [waveMaterial, rockMaterial, dustMaterial] });
  }
}
