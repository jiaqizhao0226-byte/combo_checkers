import * as THREE from '../../../vendor/three.module.js';
import { createVfxCanvas } from '../createVfxCanvas.js';

const clamp01 = value => Math.max(0, Math.min(1, value));
const easeInCubic = value => Math.pow(clamp01(value), 3);
const easeOutCubic = value => 1 - Math.pow(1 - clamp01(value), 3);

function additiveMaterial(color, opacity = 1, depthTest = true) {
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

function createTextSprite(text, color, size = 96) {
  const canvas = createVfxCanvas();
  canvas.width = 512;
  canvas.height = 224;
  const context = canvas.getContext('2d');
  context.clearRect(0, 0, canvas.width, canvas.height);
  context.textAlign = 'center';
  context.textBaseline = 'middle';
  context.shadowColor = 'rgba(45, 4, 24, .42)';
  context.shadowBlur = 8;
  context.shadowOffsetY = 4;
  context.fillStyle = color;
  context.font = `900 ${size}px Inter, "PingFang SC", sans-serif`;
  context.fillText(text, canvas.width * 0.5, canvas.height * 0.48);
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
  sprite.name = 'LifeDrainResultLabel';
  sprite.center.set(0.5, 0.25);
  sprite.scale.set(0.001, 0.001, 1);
  sprite.renderOrder = 84;
  sprite.userData.texture = texture;
  return sprite;
}

function createShieldValueBadge(value) {
  const canvas = createVfxCanvas();
  canvas.width = 256;
  canvas.height = 256;
  const context = canvas.getContext('2d');
  const gradient = context.createLinearGradient(52, 36, 204, 210);
  gradient.addColorStop(0, '#d9fff0');
  gradient.addColorStop(0.48, '#71efb0');
  gradient.addColorStop(1, '#1a9f6a');

  context.clearRect(0, 0, canvas.width, canvas.height);
  context.save();
  context.shadowColor = 'rgba(100, 255, 188, .72)';
  context.shadowBlur = 20;
  context.beginPath();
  context.moveTo(128, 24);
  context.bezierCurveTo(151, 42, 180, 49, 207, 54);
  context.lineTo(199, 133);
  context.bezierCurveTo(195, 173, 168, 204, 128, 226);
  context.bezierCurveTo(88, 204, 61, 173, 57, 133);
  context.lineTo(49, 54);
  context.bezierCurveTo(76, 49, 105, 42, 128, 24);
  context.closePath();
  context.fillStyle = gradient;
  context.fill();
  context.restore();

  context.beginPath();
  context.moveTo(128, 43);
  context.bezierCurveTo(148, 57, 171, 63, 188, 67);
  context.lineTo(182, 129);
  context.bezierCurveTo(179, 159, 160, 184, 128, 204);
  context.bezierCurveTo(96, 184, 77, 159, 74, 129);
  context.lineTo(68, 67);
  context.bezierCurveTo(85, 63, 108, 57, 128, 43);
  context.closePath();
  context.fillStyle = 'rgba(7, 68, 52, .78)';
  context.fill();

  context.textAlign = 'center';
  context.textBaseline = 'middle';
  context.fillStyle = '#f2fff9';
  context.font = '900 82px Inter, "PingFang SC", sans-serif';
  context.fillText(String(value), 128, 126);

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
  sprite.name = 'FiveComboShieldValueBadge';
  sprite.center.set(0.5, 0.2);
  sprite.scale.set(0.001, 0.001, 1);
  sprite.renderOrder = 86;
  sprite.userData.texture = texture;
  return sprite;
}

function createHealingBloom() {
  const canvas = createVfxCanvas();
  canvas.width = 256;
  canvas.height = 512;
  const context = canvas.getContext('2d');
  context.clearRect(0, 0, canvas.width, canvas.height);
  context.save();
  context.translate(128, 270);
  context.scale(0.62, 1);
  const glow = context.createRadialGradient(0, 0, 0, 0, 0, 205);
  glow.addColorStop(0, 'rgba(222, 255, 238, .96)');
  glow.addColorStop(0.16, 'rgba(126, 255, 188, .72)');
  glow.addColorStop(0.48, 'rgba(68, 222, 145, .28)');
  glow.addColorStop(1, 'rgba(47, 203, 129, 0)');
  context.fillStyle = glow;
  context.fillRect(-220, -220, 440, 440);
  context.restore();

  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.minFilter = THREE.LinearFilter;
  texture.magFilter = THREE.LinearFilter;
  texture.generateMipmaps = false;
  const material = new THREE.SpriteMaterial({
    map: texture,
    color: 0xb8ffda,
    transparent: true,
    opacity: 0,
    depthWrite: false,
    depthTest: false,
    blending: THREE.AdditiveBlending,
    toneMapped: false,
  });
  const sprite = new THREE.Sprite(material);
  sprite.name = 'FiveComboHealingBloom';
  sprite.center.set(0.5, 0.45);
  sprite.scale.set(0.001, 0.001, 1);
  sprite.position.set(0, 0.12, 0);
  sprite.renderOrder = 58;
  sprite.userData.texture = texture;
  return sprite;
}

function createPersistentShieldMaterial() {
  return new THREE.ShaderMaterial({
    name: 'FiveComboPersistentShieldFresnel',
    uniforms: {
      uInnerColor: { value: new THREE.Color(0x5debac) },
      uRimColor: { value: new THREE.Color(0xc5ffe5) },
      uOpacity: { value: 0 },
      uFormation: { value: 0 },
      uArrivalPulse: { value: 0 },
    },
    vertexShader: `
      varying vec3 vViewNormal;
      varying vec3 vViewPosition;
      varying float vLocalY;
      void main() {
        vec4 viewPosition = modelViewMatrix * vec4(position, 1.0);
        vViewPosition = viewPosition.xyz;
        vViewNormal = normalize(normalMatrix * normal);
        vLocalY = position.y;
        gl_Position = projectionMatrix * viewPosition;
      }
    `,
    fragmentShader: `
      uniform vec3 uInnerColor;
      uniform vec3 uRimColor;
      uniform float uOpacity;
      uniform float uFormation;
      uniform float uArrivalPulse;
      varying vec3 vViewNormal;
      varying vec3 vViewPosition;
      varying float vLocalY;
      void main() {
        vec3 viewDirection = normalize(-vViewPosition);
        float facing = abs(dot(normalize(vViewNormal), viewDirection));
        float fresnel = pow(1.0 - facing, 2.35);
        float softInterior = smoothstep(0.16, 0.92, fresnel);
        float latitude = abs(vLocalY) / 0.78;
        float formationMask = 1.0 - smoothstep(
          max(0.0, uFormation - 0.12),
          min(1.0, uFormation + 0.16),
          latitude
        );
        vec3 color = mix(uInnerColor, uRimColor, softInterior);
        float alpha = (0.12 + fresnel * 0.46) * uOpacity * formationMask;
        alpha *= 1.0 + uArrivalPulse * 0.3;
        gl_FragColor = vec4(color, alpha);
      }
    `,
    transparent: true,
    depthWrite: false,
    depthTest: true,
    blending: THREE.AdditiveBlending,
    side: THREE.FrontSide,
    toneMapped: false,
  });
}

function createDrainStream(target, heroOrigin, index) {
  const start = target.entry.mount.position.clone().add(new THREE.Vector3(0, target.kind === 'boss' ? 1.05 : 0.68, 0));
  const end = heroOrigin.clone().add(new THREE.Vector3(0, 0.9, 0));
  const direction = end.clone().sub(start).setY(0);
  const distance = Math.max(0.001, direction.length());
  const lateral = new THREE.Vector3(-direction.z, 0, direction.x).normalize();
  const side = index % 2 === 0 ? 1 : -1;
  const controlA = start.clone().lerp(end, 0.32)
    .addScaledVector(lateral, side * Math.min(0.5, distance * 0.12));
  controlA.y += 0.44 + (index % 2) * 0.1;
  const controlB = start.clone().lerp(end, 0.72)
    .addScaledVector(lateral, -side * Math.min(0.28, distance * 0.07));
  controlB.y += 0.72;
  const curve = new THREE.CubicBezierCurve3(start, controlA, controlB, end);

  const tetherGlowMaterial = additiveMaterial(0x42d995, 0);
  const tetherGlow = new THREE.Mesh(new THREE.TubeGeometry(curve, 32, 0.058, 6, false), tetherGlowMaterial);
  tetherGlow.name = 'FiveComboLifeDrainTetherGlow';
  tetherGlow.renderOrder = 43;
  const tetherMaterial = additiveMaterial(0xa3ffd2, 0);
  const tether = new THREE.Mesh(new THREE.TubeGeometry(curve, 32, 0.026, 6, false), tetherMaterial);
  tether.name = 'FiveComboLifeDrainTether';
  tether.renderOrder = 44;

  const sourceMaterial = additiveMaterial(target.kind === 'boss' ? 0x54e9a4 : 0x8bf5c2, 0);
  const sourceFlash = new THREE.Mesh(
    new THREE.OctahedronGeometry(target.kind === 'boss' ? 0.26 : 0.19, 1),
    sourceMaterial
  );
  sourceFlash.name = 'FiveComboLifeExtractionFlash';
  sourceFlash.position.copy(start);
  sourceFlash.scale.setScalar(0.01);
  sourceFlash.renderOrder = 55;

  const droplets = Array.from({ length: 6 }, (_, dropletIndex) => {
    const material = additiveMaterial(dropletIndex % 2 ? 0x73edb3 : 0xc4ffe2, 0);
    const droplet = new THREE.Mesh(
      new THREE.OctahedronGeometry(0.092 - dropletIndex * 0.005, 1),
      material
    );
    droplet.name = 'FiveComboLifeDroplet';
    droplet.scale.set(0.75, 1.45, 0.75);
    droplet.visible = false;
    droplet.renderOrder = 53;
    return { droplet, material, phase: dropletIndex * 0.035 };
  });

  const damageLabel = createTextSprite(`-${target.damage}`, '#ff759c', target.kind === 'boss' ? 116 : 108);
  damageLabel.position.copy(target.entry.mount.position).add(new THREE.Vector3(0, target.kind === 'boss' ? 1.85 : 1.35, 0));
  damageLabel.userData.baseY = damageLabel.position.y;

  const flightStart = 0.1 + index * 0.04;
  return {
    target, curve, tetherGlow, tetherGlowMaterial, tether, tetherMaterial,
    sourceFlash, sourceMaterial, droplets, damageLabel,
    flightStart, arrivalTime: flightStart + 0.68, damageFired: false, arrivalFired: false,
  };
}

function createHeroReception(heroOrigin, outcome) {
  const group = new THREE.Group();
  group.name = 'FiveComboHeroLifeReception';
  group.position.copy(heroOrigin).add(new THREE.Vector3(0, 0.78, 0));

  const coreMaterial = additiveMaterial(0x79ffc0, 0, false);
  const core = new THREE.Mesh(new THREE.TetrahedronGeometry(0.095, 0), coreMaterial);
  core.name = 'FiveComboAbsorptionSpark';
  core.scale.setScalar(0.01);
  core.rotation.z = Math.PI * 0.25;
  core.renderOrder = 62;
  group.add(core);

  const wisps = Array.from({ length: 7 }, (_, index) => {
    const material = additiveMaterial(index % 2 ? 0x65f5aa : 0xb8ffdc, 0, false);
    const wisp = new THREE.Mesh(new THREE.TetrahedronGeometry(0.048, 0), material);
    wisp.name = 'FiveComboReceptionStreak';
    wisp.scale.set(0.34, 1.7, 0.34);
    wisp.renderOrder = 61;
    group.add(wisp);
    return {
      wisp,
      material,
      angle: index / 7 * Math.PI * 2 + (index % 2) * 0.22,
      radius: 0.42 + (index % 3) * 0.1,
      phase: index / 7,
    };
  });

  const healBloom = outcome.heal > 0 ? createHealingBloom() : null;
  if (healBloom) group.add(healBloom);

  const shieldMaterial = createPersistentShieldMaterial();
  const shield = new THREE.Mesh(new THREE.SphereGeometry(0.78, 28, 20), shieldMaterial);
  shield.name = 'FiveComboPersistentShieldShell';
  shield.scale.setScalar(0.01);
  shield.visible = outcome.shieldTotal > 0;
  shield.renderOrder = 59;
  group.add(shield);

  const healLabel = outcome.heal > 0 ? createTextSprite(`+${outcome.heal}`, '#8effbe', 122) : null;
  if (healLabel) {
    healLabel.position.copy(heroOrigin).add(new THREE.Vector3(0, 1.72, 0));
    healLabel.userData.baseY = healLabel.position.y;
  }
  const shieldBadge = outcome.shieldTotal > 0 ? createShieldValueBadge(outcome.shieldTotal) : null;
  if (shieldBadge) {
    shieldBadge.position.copy(heroOrigin).add(new THREE.Vector3(0.42, 2.22, 0));
    shieldBadge.userData.baseY = shieldBadge.position.y;
  }

  return {
    group, core, coreMaterial, wisps, healBloom, shield, shieldMaterial, healLabel, shieldBadge,
    firstArrival: null, finalArrival: null, pulseStrength: 0,
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

function updateLabel(sprite, local, width = 1.22, height = 0.54) {
  if (!sprite) return;
  const pop = easeOutCubic(Math.min(1, local * 5));
  sprite.scale.set(width * pop, height * pop, 1);
  sprite.position.y = sprite.userData.baseY + easeOutCubic(local) * 0.34;
  sprite.material.opacity = local < 0.7 ? 1 : Math.max(0, (1 - local) / 0.3);
}

export class LifeDrainEffect {
  constructor(scene) {
    this.scene = scene;
    this.root = new THREE.Group();
    this.root.name = 'ComboReward_LifeDrainEffect';
    scene.add(this.root);
    this.effect = null;
    this.duration = 1.25;
  }

  play({ origin, targets, outcome }) {
    this.clear();
    const group = new THREE.Group();
    group.name = 'FiveComboAllEnemyLifeDrain';
    this.root.add(group);

    const streams = targets.map((target, index) => {
      const stream = createDrainStream(target, origin, index);
      group.add(stream.tetherGlow, stream.tether, stream.sourceFlash, stream.damageLabel);
      stream.droplets.forEach(({ droplet }) => group.add(droplet));
      return stream;
    });
    const reception = createHeroReception(origin, outcome);
    group.add(reception.group);
    if (reception.healLabel) group.add(reception.healLabel);
    if (reception.shieldBadge) group.add(reception.shieldBadge);

    this.effect = {
      group, streams, reception, outcome,
      elapsed: 0, duration: this.duration,
      finalArrivalTime: Math.max(...streams.map(stream => stream.arrivalTime)),
      origin: origin.clone(),
      shieldValue: outcome.shieldTotal || 0,
    };
  }

  setShield(value) {
    const effect = this.effect;
    if (!effect) return;
    const shieldValue = Math.max(0, Math.floor(value || 0));
    const reception = effect.reception;
    reception.shield.visible = shieldValue > 0;
    if (shieldValue <= 0) {
      reception.shieldMaterial.uniforms.uOpacity.value = 0;
      if (reception.shieldBadge) reception.shieldBadge.visible = false;
      effect.shieldValue = 0;
      return;
    }
    if (!reception.shieldBadge) {
      reception.shieldBadge = createShieldValueBadge(shieldValue);
      reception.shieldBadge.position.copy(effect.origin).add(new THREE.Vector3(0.42, 2.22, 0));
      reception.shieldBadge.userData.baseY = reception.shieldBadge.position.y;
      reception.shieldBadge.scale.set(0.54, 0.54, 1);
      reception.shieldBadge.material.opacity = 1;
      effect.group.add(reception.shieldBadge);
    } else if (shieldValue !== effect.shieldValue) {
      const replacement = createShieldValueBadge(shieldValue);
      reception.shieldBadge.material.map?.dispose?.();
      reception.shieldBadge.material.map = replacement.material.map;
      reception.shieldBadge.material.needsUpdate = true;
      replacement.material.map = null;
      replacement.material.dispose();
    }
    reception.shieldBadge.visible = true;
    effect.shieldValue = shieldValue;
  }

  fireDamage(stream) {
    stream.damageFired = true;
    stream.target.entry.model.userData.playAction?.('hit', stream.target.kind === 'boss' ? 0.5 : 0.4);
    stream.target.entry.damageAt = this.effect.elapsed;
    stream.sourceFlash.scale.setScalar(0.55);
  }

  fireArrival(stream) {
    stream.arrivalFired = true;
    const reception = this.effect.reception;
    reception.firstArrival ??= this.effect.elapsed;
    reception.pulseStrength = 1;
    if (this.effect.streams.every(item => item.arrivalFired)) reception.finalArrival = this.effect.elapsed;
  }

  updateTarget(stream, elapsed) {
    const entry = stream.target.entry;
    if (entry.damageAt == null) return;
    const local = Math.max(0, elapsed - entry.damageAt);
    const drainPulse = Math.sin(clamp01(local / 0.42) * Math.PI);
    entry.model.scale.copy(entry.baseScale).multiplyScalar(1 - drainPulse * 0.065);
    if (stream.target.killed && local >= 0.58) entry.mount.visible = false;
  }

  update(delta) {
    const effect = this.effect;
    if (!effect) return;
    effect.elapsed += Math.max(0, delta);
    const elapsed = effect.elapsed;
    const fade = elapsed < 0.98 ? 1 : clamp01((effect.duration - elapsed) / 0.27);

    effect.streams.forEach((stream, streamIndex) => {
      if (!stream.damageFired && elapsed >= stream.flightStart) this.fireDamage(stream);
      if (!stream.arrivalFired && elapsed >= stream.arrivalTime) this.fireArrival(stream);

      const travel = clamp01((elapsed - stream.flightStart) / 0.68);
      stream.tetherGlowMaterial.opacity = Math.sin(travel * Math.PI) * 0.13 * fade;
      stream.tetherMaterial.opacity = Math.sin(travel * Math.PI) * 0.46 * fade;
      stream.sourceMaterial.opacity = Math.max(0, 1 - travel * 3.4) * 0.9;
      stream.sourceFlash.scale.setScalar(0.25 + easeOutCubic(Math.min(1, travel * 4)) * 1.05);

      stream.droplets.forEach(({ droplet, material, phase }, dropletIndex) => {
        const local = (elapsed - stream.flightStart - phase) / 0.5;
        droplet.visible = local > 0 && local < 1;
        if (!droplet.visible) return;
        const point = stream.curve.getPoint(easeInCubic(local));
        droplet.position.copy(point);
        const previous = stream.curve.getPoint(easeInCubic(Math.max(0, local - 0.025)));
        droplet.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), point.clone().sub(previous).normalize());
        const pulse = 0.82 + Math.sin(elapsed * 18 + dropletIndex + streamIndex) * 0.12;
        droplet.scale.set(0.72 * pulse, 1.5 * pulse, 0.72 * pulse);
        material.opacity = Math.sin(local * Math.PI) * 0.92 * fade;
      });

      if (stream.damageFired) {
        const damageLocal = clamp01((elapsed - stream.flightStart) / 0.72);
        updateLabel(stream.damageLabel, damageLocal, stream.target.kind === 'boss' ? 1.58 : 1.42, stream.target.kind === 'boss' ? 0.68 : 0.62);
      }
      this.updateTarget(stream, elapsed);
    });

    const reception = effect.reception;
    reception.pulseStrength = Math.max(0, reception.pulseStrength - delta * 2.7);
    if (reception.firstArrival != null) {
      const local = Math.max(0, elapsed - reception.firstArrival);
      const pulse = reception.pulseStrength;
      const formation = reception.shield.visible
        ? 0.14 + easeOutCubic(clamp01(local / 0.18)) * 0.86
        : 0;
      const coreTransfer = reception.shield.visible
        ? 0.24 * (1 - formation * 0.78)
        : 1;
      const coreScale = (0.3 + pulse * 0.52 + Math.sin(local * 14) * 0.025) * coreTransfer;
      reception.core.scale.set(coreScale * 0.5, coreScale * 1.35, coreScale * 0.5);
      reception.coreMaterial.opacity = (0.1 + pulse * 0.3) * coreTransfer * fade;
      reception.wisps.forEach(({ wisp, material, angle, radius, phase }, index) => {
        const trailProgress = clamp01((local - phase * 0.15) / 0.36);
        const envelope = Math.sin(trailProgress * Math.PI);
        const inward = 1 - easeOutCubic(trailProgress) * 0.82;
        const sweep = angle + trailProgress * (index % 2 ? 0.5 : -0.5);
        const height = (phase - 0.5) * 0.4 * (1 - trailProgress) + trailProgress * 0.05;
        wisp.position.set(Math.cos(sweep) * radius * inward, height, Math.sin(sweep) * radius * inward);
        const towardCenter = wisp.position.clone().multiplyScalar(-1).normalize();
        wisp.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), towardCenter);
        const streakScale = 0.7 + pulse * 0.24;
        wisp.scale.set(0.3 * streakScale, 1.75 * streakScale, 0.3 * streakScale);
        material.opacity = envelope * (0.3 + pulse * 0.38) * fade;
      });
      if (reception.shield.visible) {
        const shieldBreath = 1 + Math.sin(local * 2.6) * 0.014;
        const formationScale = 0.82 + formation * 0.18;
        reception.shield.scale.set(
          0.91 * formationScale * shieldBreath,
          1.12 * formationScale * shieldBreath,
          0.91 * formationScale * shieldBreath
        );
        reception.shieldMaterial.uniforms.uFormation.value = formation;
        reception.shieldMaterial.uniforms.uArrivalPulse.value = pulse;
        reception.shieldMaterial.uniforms.uOpacity.value = formation * (0.42 + Math.sin(local * 2.6) * 0.015);
      }
    }

    if (reception.finalArrival != null) {
      const shieldLocal = Math.max(0, elapsed - reception.finalArrival);
      const resultLocal = clamp01(shieldLocal / 0.72);
      updateLabel(reception.healLabel, resultLocal, 1.62, 0.72);
      if (reception.healBloom) {
        const bloomProgress = clamp01(shieldLocal / 0.86);
        const bloomEnvelope = Math.sin(bloomProgress * Math.PI);
        const bloomOpen = easeOutCubic(clamp01(shieldLocal / 0.28));
        reception.healBloom.visible = shieldLocal < 0.88;
        reception.healBloom.scale.set(1.12 + bloomOpen * 0.78, 1.82 + bloomOpen * 0.92, 1);
        reception.healBloom.material.opacity = bloomEnvelope * 0.78;
      }
      if (reception.shieldBadge) {
        const badgePop = easeOutCubic(clamp01(shieldLocal / 0.24));
        reception.shieldBadge.scale.set(0.54 * badgePop, 0.54 * badgePop, 1);
        reception.shieldBadge.position.y = reception.shieldBadge.userData.baseY + Math.sin(shieldLocal * 2.2) * 0.016;
        reception.shieldBadge.material.opacity = badgePop;
      }
    }
  }

  clear() {
    if (!this.effect) return;
    this.effect.streams.forEach(stream => {
      const entry = stream.target.entry;
      entry.mount.visible = true;
      entry.model.scale.copy(entry.baseScale);
      entry.damageAt = null;
    });
    this.root.remove(this.effect.group);
    disposeObject(this.effect.group);
    this.effect = null;
  }
}
