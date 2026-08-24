import * as THREE from '../../../vendor/three.module.js';
import { createVfxCanvas } from '../createVfxCanvas.js';

const clamp01 = value => Math.max(0, Math.min(1, value));
const easeOutCubic = value => 1 - Math.pow(1 - clamp01(value), 3);
const easeOutQuad = value => 1 - Math.pow(1 - clamp01(value), 2);

function additiveMaterial(color, opacity = 1, depthTest = false) {
  return new THREE.MeshBasicMaterial({
    color,
    transparent: true,
    opacity,
    depthWrite: false,
    depthTest,
    blending: THREE.AdditiveBlending,
    toneMapped: false,
  });
}

function directionalFadeMaterial(color) {
  const material = new THREE.ShaderMaterial({
    name: 'FourComboDirectionalFadeMaterial',
    uniforms: {
      uColor: { value: new THREE.Color(color) },
      uOpacity: { value: 0 },
    },
    vertexShader: `
      varying float vLongitudinalFade;
      void main() {
        vLongitudinalFade = clamp(0.5 - position.y, 0.0, 1.0);
        gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
      }
    `,
    fragmentShader: `
      uniform vec3 uColor;
      uniform float uOpacity;
      varying float vLongitudinalFade;
      void main() {
        float feather = pow(smoothstep(0.0, 1.0, vLongitudinalFade), 2.15);
        gl_FragColor = vec4(uColor, uOpacity * feather);
      }
    `,
    transparent: true,
    depthWrite: false,
    depthTest: true,
    blending: THREE.AdditiveBlending,
    side: THREE.DoubleSide,
    toneMapped: false,
  });
  return material;
}

function resultSprite(label, color) {
  const canvas = createVfxCanvas();
  canvas.width = 512;
  canvas.height = 224;
  const context = canvas.getContext('2d');
  context.clearRect(0, 0, canvas.width, canvas.height);
  context.textAlign = 'center';
  context.textBaseline = 'middle';
  context.shadowColor = 'rgba(35, 12, 55, .42)';
  context.shadowBlur = 9;
  context.shadowOffsetY = 4;
  context.fillStyle = color;
  context.font = `900 ${label.length > 3 ? 78 : 102}px Inter, "PingFang SC", sans-serif`;
  context.fillText(label, canvas.width * 0.5, canvas.height * 0.47);
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.minFilter = THREE.LinearFilter;
  texture.magFilter = THREE.LinearFilter;
  texture.generateMipmaps = false;
  const material = new THREE.SpriteMaterial({
    map: texture,
    transparent: true,
    opacity: 0,
    depthWrite: false,
    depthTest: false,
    toneMapped: false,
  });
  const sprite = new THREE.Sprite(material);
  sprite.name = 'HexBlastResultLabel';
  sprite.center.set(0.5, 0.25);
  sprite.scale.set(0.001, 0.001, 1);
  sprite.renderOrder = 76;
  sprite.userData.texture = texture;
  return sprite;
}

function cylinderBetween(start, end, radius, material) {
  const direction = end.clone().sub(start);
  const length = direction.length();
  const segment = new THREE.Mesh(new THREE.CylinderGeometry(radius, radius, length, 6), material);
  segment.position.copy(start).add(end).multiplyScalar(0.5);
  segment.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), direction.normalize());
  return segment;
}

function createHexagram(origin) {
  const root = new THREE.Group();
  root.name = 'FourComboCenterHexagram';
  root.position.copy(origin).add(new THREE.Vector3(0, 0.2, 0));
  const plateMaterial = additiveMaterial(0x7e3ff2, 0.26, true);
  const plate = new THREE.Mesh(new THREE.CylinderGeometry(0.52, 0.58, 0.035, 6), plateMaterial);
  plate.name = 'FourComboHexCorePlate';
  plate.renderOrder = 34;
  root.add(plate);

  const points = Array.from({ length: 6 }, (_, index) => {
    const angle = index * Math.PI / 3 + Math.PI / 6;
    return new THREE.Vector3(Math.sin(angle) * 0.68, 0.025, Math.cos(angle) * 0.68);
  });
  const lineMaterial = additiveMaterial(0xdab9ff, 0.72, true);
  [[0, 2, 4, 0], [1, 3, 5, 1]].forEach(path => {
    for (let index = 0; index < path.length - 1; index += 1) {
      const line = cylinderBetween(points[path[index]], points[path[index + 1]], 0.022, lineMaterial);
      line.name = 'FourComboHexagramStroke';
      line.renderOrder = 36;
      root.add(line);
    }
  });
  root.userData.plateMaterial = plateMaterial;
  root.userData.lineMaterial = lineMaterial;
  return root;
}

function createBeam(origin, end, index) {
  const direction = end.clone().sub(origin).setY(0);
  const length = direction.length();
  direction.normalize();
  const group = new THREE.Group();
  group.name = `FourComboAxisBeam${index + 1}`;

  const outerMaterial = additiveMaterial(0x743be8, 0.2, true);
  const outer = new THREE.Mesh(new THREE.BoxGeometry(0.56, 0.055, 1), outerMaterial);
  outer.name = 'FourComboAxisGlow';
  outer.renderOrder = 38;
  group.add(outer);

  const beamMaterial = additiveMaterial(0xb46dff, 0.76, true);
  const beam = new THREE.Mesh(new THREE.BoxGeometry(0.23, 0.075, 1), beamMaterial);
  beam.name = 'FourComboAxisBody';
  beam.renderOrder = 39;
  group.add(beam);

  const coreMaterial = additiveMaterial(0xeaf8ff, 0.9, true);
  const core = new THREE.Mesh(new THREE.BoxGeometry(0.07, 0.088, 1), coreMaterial);
  core.name = 'FourComboAxisWhiteCore';
  core.renderOrder = 40;
  group.add(core);

  const headMaterial = additiveMaterial(0xdaf7ff, 0.92, true);
  const head = new THREE.Mesh(new THREE.OctahedronGeometry(0.18, 1), headMaterial);
  head.name = 'FourComboAxisWaveHead';
  head.renderOrder = 43;
  group.add(head);

  const edgeFadeLength = 0.86;
  const featherStart = Math.max(0, length - 0.28);
  const featherMeshes = [
    {
      name: 'FourComboEdgeFeatherGlow',
      radius: 0.31,
      color: 0x743be8,
      opacity: 0.13,
      renderOrder: 38,
    },
    {
      name: 'FourComboEdgeFeatherBody',
      radius: 0.14,
      color: 0xb46dff,
      opacity: 0.38,
      renderOrder: 39,
    },
    {
      name: 'FourComboEdgeFeatherCore',
      radius: 0.048,
      color: 0xeaf8ff,
      opacity: 0.3,
      renderOrder: 40,
    },
  ].map(config => {
    const material = directionalFadeMaterial(config.color);
    const mesh = new THREE.Mesh(
      new THREE.CylinderGeometry(0, config.radius, 1, 8, 1, true),
      material
    );
    mesh.name = config.name;
    mesh.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), direction);
    mesh.scale.y = 0.001;
    mesh.visible = false;
    mesh.renderOrder = config.renderOrder;
    group.add(mesh);
    return { mesh, material, opacity: config.opacity };
  });

  const particles = Array.from({ length: 4 }, (_, particleIndex) => {
    const material = additiveMaterial(particleIndex % 2 ? 0x75e8ff : 0xc18aff, 0.8, true);
    const particle = new THREE.Mesh(new THREE.OctahedronGeometry(0.045 + (particleIndex % 2) * 0.015, 0), material);
    particle.name = 'FourComboAxisParticle';
    particle.renderOrder = 42;
    group.add(particle);
    return { particle, material, phase: particleIndex / 4, side: (particleIndex - 1.5) * 0.12 };
  });

  return {
    group, outer, beam, core, head, particles,
    outerMaterial, beamMaterial, coreMaterial, headMaterial,
    featherMeshes, featherStart, edgeFadeLength,
    origin: origin.clone().add(new THREE.Vector3(0, 0.23, 0)),
    end: end.clone().add(new THREE.Vector3(0, 0.23, 0)),
    direction, length, visualLength: length + edgeFadeLength,
  };
}

function createImpact(target) {
  const group = new THREE.Group();
  group.name = target.kind === 'boss' ? 'FourComboBossImpact' : 'FourComboMinionExecuteImpact';
  group.position.copy(target.entry.mount.position).add(new THREE.Vector3(0, target.kind === 'boss' ? 1.1 : 0.72, 0));
  group.visible = false;

  const flashMaterial = additiveMaterial(target.kind === 'boss' ? 0xff74b7 : 0xf2d8ff, 1);
  const flash = new THREE.Mesh(new THREE.OctahedronGeometry(target.kind === 'boss' ? 0.3 : 0.24, 1), flashMaterial);
  flash.name = 'FourComboTargetContactFlash';
  flash.renderOrder = 58;
  group.add(flash);

  const shards = Array.from({ length: 8 }, (_, index) => {
    const shard = new THREE.Mesh(
      new THREE.BoxGeometry(0.035, 0.2, 0.035),
      additiveMaterial(target.kind === 'boss' ? 0xff66a8 : 0xb87cff, 1)
    );
    const angle = index / 8 * Math.PI * 2;
    shard.userData.direction = new THREE.Vector3(Math.sin(angle), 0.25 + (index % 3) * 0.18, Math.cos(angle)).normalize();
    shard.userData.speed = 0.42 + (index % 3) * 0.12;
    shard.renderOrder = 57;
    group.add(shard);
    return shard;
  });

  const label = resultSprite(target.kind === 'boss' ? '-60' : '秒杀', target.kind === 'boss' ? '#ff8fc0' : '#f2d3ff');
  label.position.copy(target.entry.mount.position).add(new THREE.Vector3(0, target.kind === 'boss' ? 2.05 : 1.45, 0));
  group.parent?.worldToLocal?.(label.position);

  return { group, flash, flashMaterial, shards, label, labelMaterial: label.material };
}

function resolveImpactContact(target, beams, origin) {
  const offset = target.entry.mount.position.clone().sub(origin).setY(0);
  const centerDistance = offset.length();
  const direction = centerDistance > 0.0001
    ? offset.clone().multiplyScalar(1 / centerDistance)
    : new THREE.Vector3(0, 0, 1);
  const beam = beams.reduce((best, candidate) => (
    candidate.direction.dot(direction) > best.direction.dot(direction) ? candidate : best
  ), beams[0]);
  const targetRadius = target.kind === 'boss' ? 0.56 : 0.3;
  const waveHeadRadius = 0.18;
  return {
    beam,
    contactDistance: Math.max(0, centerDistance - targetRadius - waveHeadRadius),
  };
}

function disposeObject(root) {
  root.traverse(child => {
    child.geometry?.dispose?.();
    if (Array.isArray(child.material)) child.material.forEach(material => {
      material.map?.dispose?.();
      material.dispose?.();
    });
    else {
      child.material?.map?.dispose?.();
      child.material?.dispose?.();
    }
  });
}

export class HexBlastEffect {
  constructor(scene) {
    this.scene = scene;
    this.root = new THREE.Group();
    this.root.name = 'ComboReward_HexBlastEffect';
    scene.add(this.root);
    this.effect = null;
    this.duration = 1.5;
  }

  play({ origin, paths, targets }) {
    this.clear();
    const group = new THREE.Group();
    group.name = 'FourComboSixAxisBlast';
    this.root.add(group);

    const hexagram = createHexagram(origin);
    hexagram.scale.setScalar(0.01);
    group.add(hexagram);
    const beams = paths.map((path, index) => {
      const beam = createBeam(origin, path.end, index);
      group.add(beam.group);
      return beam;
    });

    const highlights = [];
    paths.forEach((path, rayIndex) => {
      path.cells.forEach((cell, cellIndex) => {
        const material = additiveMaterial(cellIndex % 2 ? 0x965cff : 0x60dfff, 0, true);
        const tile = new THREE.Mesh(new THREE.CylinderGeometry(0.69, 0.73, 0.035, 6), material);
        tile.name = `FourComboPathCell_${rayIndex + 1}_${cellIndex + 1}`;
        tile.position.copy(cell.position);
        tile.position.y = 0.155;
        tile.renderOrder = 32;
        group.add(tile);
        highlights.push({ tile, material, step: cellIndex + 1, rayIndex });
      });
    });

    const centerLight = new THREE.PointLight(0xb578ff, 0, 5.5, 2);
    centerLight.name = 'FourComboCenterPulseLight';
    centerLight.position.copy(origin).add(new THREE.Vector3(0, 1.1, 0));
    group.add(centerLight);

    const impacts = targets.map(target => {
      const impact = createImpact(target);
      const contact = resolveImpactContact(target, beams, origin);
      group.add(impact.group);
      group.add(impact.label);
      return { ...impact, ...contact, target, fired: false, hitAt: null };
    });

    this.effect = {
      group, hexagram, beams, highlights, impacts, centerLight,
      elapsed: 0, duration: this.duration,
    };
  }

  fireImpact(impact) {
    impact.fired = true;
    impact.group.visible = true;
    impact.target.entry.model.userData.playAction?.('hit', impact.target.kind === 'boss' ? 0.58 : 0.46);
    impact.hitAt = this.effect.elapsed;
    impact.target.entry.hitAt = this.effect.elapsed;
  }

  updateTarget(target, elapsed) {
    const entry = target.entry;
    if (entry.hitAt == null) return;
    const local = Math.max(0, elapsed - entry.hitAt);
    if (target.kind === 'boss') {
      const recoil = Math.sin(clamp01(local / 0.58) * Math.PI);
      entry.mount.position.copy(entry.basePosition).addScaledVector(target.incoming, -recoil * 0.2);
      entry.model.scale.copy(entry.baseScale).multiplyScalar(1 - recoil * 0.08);
      return;
    }
    const fall = easeOutCubic(clamp01(local / 0.62));
    entry.mount.rotation.z = entry.baseRotationZ + (target.fallDirection || 1) * fall * 1.08;
    entry.mount.position.copy(entry.basePosition);
    entry.mount.position.y -= fall * 0.12;
    entry.materials.forEach(({ material, opacity }) => {
      material.transparent = true;
      material.opacity = opacity * Math.max(0, 1 - clamp01((local - 0.2) / 0.42));
    });
    if (local >= 0.64) entry.mount.visible = false;
  }

  update(delta) {
    const effect = this.effect;
    if (!effect) return;
    effect.elapsed += Math.max(0, delta);
    const elapsed = effect.elapsed;
    const progress = clamp01(elapsed / effect.duration);
    const grow = easeOutQuad(clamp01(elapsed / 0.6));
    const fade = elapsed < 0.94 ? 1 : clamp01((effect.duration - elapsed) / 0.56);

    const sigilPop = easeOutCubic(clamp01(elapsed / 0.22));
    effect.hexagram.scale.setScalar(0.01 + sigilPop * (1 + Math.sin(elapsed * 8) * 0.025));
    effect.hexagram.rotation.y = elapsed * 0.16;
    effect.hexagram.userData.plateMaterial.opacity = 0.26 * fade;
    effect.hexagram.userData.lineMaterial.opacity = 0.72 * fade;
    effect.centerLight.intensity = (elapsed < 0.3 ? 4.2 * (1 - elapsed / 0.3) : 0.7 * fade);

    effect.beams.forEach((beam, index) => {
      const edgeGrow = easeOutQuad(clamp01((elapsed - 0.6) / 0.22));
      const currentLength = beam.length * grow + beam.edgeFadeLength * edgeGrow;
      beam.currentLength = currentLength;
      const bodyLength = Math.min(currentLength, beam.featherStart);
      const midpoint = beam.origin.clone().addScaledVector(beam.direction, bodyLength * 0.5);
      beam.group.position.set(0, 0, 0);
      const rotation = Math.atan2(beam.direction.x, beam.direction.z);
      [beam.outer, beam.beam, beam.core].forEach(mesh => {
        mesh.position.copy(midpoint);
        mesh.rotation.y = rotation;
        mesh.scale.z = Math.max(0.001, bodyLength);
      });
      beam.head.position.copy(beam.origin).addScaledVector(beam.direction, currentLength);
      beam.head.rotation.y = elapsed * 5 + index;
      const terminalHeadFade = clamp01((beam.visualLength - currentLength) / 0.34);
      const headPulse = 0.72 + Math.sin(elapsed * 14 + index) * 0.12;
      beam.head.scale.setScalar(headPulse * (0.16 + terminalHeadFade * 0.84));
      beam.outerMaterial.opacity = 0.2 * fade;
      beam.beamMaterial.opacity = 0.76 * fade;
      beam.coreMaterial.opacity = 0.9 * fade;
      beam.headMaterial.opacity = fade * 0.92 * terminalHeadFade;
      const featherLength = Math.max(0, currentLength - beam.featherStart);
      const featherStrength = easeOutQuad(clamp01(featherLength / 0.22));
      const featherMidpoint = beam.origin.clone().addScaledVector(
        beam.direction,
        beam.featherStart + featherLength * 0.5
      );
      beam.featherMeshes.forEach(({ mesh, material, opacity }) => {
        mesh.visible = featherLength > 0.002;
        mesh.position.copy(featherMidpoint);
        mesh.scale.y = Math.max(0.001, featherLength);
        material.uniforms.uOpacity.value = opacity * featherStrength * fade;
      });
      beam.particles.forEach(({ particle, material, phase, side }) => {
        const travel = (grow * 1.3 + phase) % 1;
        const lateral = new THREE.Vector3(-beam.direction.z, 0, beam.direction.x);
        particle.position.copy(beam.origin)
          .addScaledVector(beam.direction, currentLength * travel)
          .addScaledVector(lateral, side);
        particle.position.y += 0.08 + Math.sin((elapsed + phase) * 12) * 0.045;
        particle.rotation.y += delta * 5;
        material.opacity = 0.7 * fade * Math.min(1, grow * 3);
      });
    });

    effect.highlights.forEach(({ tile, material, step, rayIndex }) => {
      const activation = clamp01((grow - step / 3 + 0.18) * 5.5);
      const pulse = 0.72 + Math.sin(elapsed * 9 + rayIndex + step) * 0.18;
      material.opacity = activation * fade * 0.34 * pulse;
      tile.scale.setScalar(0.88 + activation * 0.12);
    });

    effect.impacts.forEach(impact => {
      if (!impact.fired && impact.beam.currentLength >= impact.contactDistance) this.fireImpact(impact);
    });
    effect.impacts.forEach(impact => {
      if (!impact.fired) return;
      const local = clamp01((elapsed - impact.hitAt) / 0.78);
      const pop = easeOutCubic(Math.min(1, local * 4.2));
      impact.flash.scale.setScalar(0.4 + pop * 1.15);
      impact.flashMaterial.opacity = Math.max(0, 1 - local * 4.4);
      impact.shards.forEach((shard, index) => {
        shard.position.copy(shard.userData.direction).multiplyScalar(easeOutCubic(local) * shard.userData.speed);
        shard.position.y -= local * local * 0.18;
        shard.rotation.y = index + local * 5;
        shard.material.opacity = Math.max(0, 1 - local * 1.15);
      });
      const labelPop = easeOutCubic(Math.min(1, local * 4));
      impact.label.scale.set(1.26 * labelPop, 0.55 * labelPop, 1);
      impact.label.position.y += delta * 0.34;
      impact.labelMaterial.opacity = local < 0.68 ? 1 : Math.max(0, (1 - local) / 0.32);
      this.updateTarget(impact.target, elapsed);
    });

    if (progress >= 1) {
      effect.beams.forEach(beam => { beam.group.visible = false; });
      effect.highlights.forEach(({ tile }) => { tile.visible = false; });
      effect.hexagram.visible = false;
    }
  }

  clear() {
    if (!this.effect) return;
    this.effect.impacts.forEach(({ target }) => {
      const entry = target.entry;
      entry.mount.visible = true;
      entry.mount.position.copy(entry.basePosition);
      entry.mount.rotation.z = entry.baseRotationZ;
      entry.model.scale.copy(entry.baseScale);
      entry.hitAt = null;
      entry.materials.forEach(({ material, opacity, transparent }) => {
        material.opacity = opacity;
        material.transparent = transparent;
      });
    });
    this.root.remove(this.effect.group);
    disposeObject(this.effect.group);
    this.effect = null;
  }
}
