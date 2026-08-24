import * as THREE from '../../../vendor/three.module.js';
import { createVfxCanvas } from '../createVfxCanvas.js';

const clamp01 = value => Math.max(0, Math.min(1, value));
const easeOutCubic = value => 1 - Math.pow(1 - clamp01(value), 3);
const easeInCubic = value => Math.pow(clamp01(value), 3);
const easeInOutCubic = value => {
  const t = clamp01(value);
  return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) * 0.5;
};

function setReflectDebug(name, value) {
  const dataset = globalThis.document?.documentElement?.dataset;
  if (dataset) dataset[name] = String(value);
}

function additiveMaterial(color, opacity = 1, depthTest = true) {
  return new THREE.MeshBasicMaterial({
    color,
    transparent: true,
    opacity,
    depthWrite: false,
    depthTest,
    blending: THREE.AdditiveBlending,
    toneMapped: false,
    side: THREE.DoubleSide,
  });
}

function makeSoftTexture() {
  const canvas = createVfxCanvas();
  canvas.width = 96;
  canvas.height = 96;
  const context = canvas.getContext('2d');
  const gradient = context.createRadialGradient(48, 48, 1, 48, 48, 47);
  gradient.addColorStop(0, 'rgba(255,255,255,1)');
  gradient.addColorStop(0.2, 'rgba(255,244,190,0.92)');
  gradient.addColorStop(0.56, 'rgba(255,190,66,0.38)');
  gradient.addColorStop(1, 'rgba(255,166,36,0)');
  context.fillStyle = gradient;
  context.fillRect(0, 0, 96, 96);
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.minFilter = THREE.LinearFilter;
  texture.magFilter = THREE.LinearFilter;
  texture.generateMipmaps = false;
  return texture;
}

function makeGoldenSparkleTexture() {
  const canvas = createVfxCanvas();
  canvas.width = 96;
  canvas.height = 96;
  const context = canvas.getContext('2d');
  const glow = context.createRadialGradient(48, 48, 0, 48, 48, 44);
  glow.addColorStop(0, 'rgba(255,255,244,1)');
  glow.addColorStop(0.12, 'rgba(255,239,156,0.96)');
  glow.addColorStop(0.42, 'rgba(255,193,54,0.34)');
  glow.addColorStop(1, 'rgba(255,174,24,0)');
  context.fillStyle = glow;
  context.fillRect(0, 0, 96, 96);
  const streak = context.createLinearGradient(0, 48, 96, 48);
  streak.addColorStop(0, 'rgba(255,220,104,0)');
  streak.addColorStop(0.42, 'rgba(255,238,172,0.18)');
  streak.addColorStop(0.5, 'rgba(255,255,238,0.96)');
  streak.addColorStop(0.58, 'rgba(255,238,172,0.18)');
  streak.addColorStop(1, 'rgba(255,220,104,0)');
  context.fillStyle = streak;
  context.fillRect(5, 45.5, 86, 5);
  context.save();
  context.translate(48, 48);
  context.rotate(Math.PI * 0.5);
  context.translate(-48, -48);
  context.fillStyle = streak;
  context.fillRect(18, 46.5, 60, 3);
  context.restore();
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.minFilter = THREE.LinearFilter;
  texture.magFilter = THREE.LinearFilter;
  texture.generateMipmaps = false;
  return texture;
}

function createDamageSprite(label) {
  const canvas = createVfxCanvas();
  canvas.width = 512;
  canvas.height = 256;
  const context = canvas.getContext('2d');
  context.clearRect(0, 0, canvas.width, canvas.height);
  context.textAlign = 'center';
  context.textBaseline = 'middle';
  context.shadowColor = 'rgba(91, 48, 8, 0.58)';
  context.shadowBlur = 12;
  context.shadowOffsetY = 5;
  context.fillStyle = '#ffe39a';
  context.font = '900 112px Inter, "PingFang SC", sans-serif';
  context.fillText(label, canvas.width * 0.5, canvas.height * 0.48);
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
  sprite.name = 'EightComboReflectedDamageNumber';
  sprite.center.set(0.5, 0.18);
  sprite.scale.set(0.001, 0.001, 1);
  sprite.renderOrder = 96;
  sprite.userData.texture = texture;
  return { sprite, material };
}

function createShieldMaterial() {
  return new THREE.ShaderMaterial({
    name: 'EightComboAbsoluteReflectFresnel',
    uniforms: {
      uInnerColor: { value: new THREE.Color(0xb86a12) },
      uRimColor: { value: new THREE.Color(0xfff1ad) },
      uOpacity: { value: 0 },
      uPulse: { value: 0 },
      uContact: { value: 0 },
    },
    vertexShader: `
      varying vec3 vViewNormal;
      varying vec3 vViewPosition;
      varying vec3 vLocalPosition;
      void main() {
        vec4 viewPosition = modelViewMatrix * vec4(position, 1.0);
        vViewPosition = viewPosition.xyz;
        vViewNormal = normalize(normalMatrix * normal);
        vLocalPosition = position;
        gl_Position = projectionMatrix * viewPosition;
      }
    `,
    fragmentShader: `
      uniform vec3 uInnerColor;
      uniform vec3 uRimColor;
      uniform float uOpacity;
      uniform float uPulse;
      uniform float uContact;
      varying vec3 vViewNormal;
      varying vec3 vViewPosition;
      varying vec3 vLocalPosition;
      void main() {
        vec3 viewDirection = normalize(-vViewPosition);
        float facing = abs(dot(normalize(vViewNormal), viewDirection));
        float fresnel = pow(1.0 - facing, 2.25);
        float facets = 0.88 + 0.12 * sin((vLocalPosition.x + vLocalPosition.y * 0.7 - vLocalPosition.z) * 14.0 + uPulse * 6.28318);
        vec3 color = mix(uInnerColor, uRimColor, fresnel + uContact * 0.28);
        float alpha = (0.055 + fresnel * 0.54 + uContact * 0.09) * facets * uOpacity;
        gl_FragColor = vec4(color, alpha);
      }
    `,
    transparent: true,
    depthWrite: false,
    depthTest: true,
    blending: THREE.AdditiveBlending,
    toneMapped: false,
    side: THREE.DoubleSide,
  });
}

function createMirrorShield(center) {
  const root = new THREE.Group();
  root.name = 'EightComboAbsoluteReflectMirrorShield';
  root.position.copy(center);

  const shellMaterial = createShieldMaterial();
  const shell = new THREE.Mesh(new THREE.IcosahedronGeometry(1.08, 2), shellMaterial);
  shell.name = 'EightComboReflectiveFresnelShell';
  shell.scale.set(0.001, 0.001, 0.001);
  shell.renderOrder = 72;
  root.add(shell);

  const plates = [];
  const plateGeometry = new THREE.CircleGeometry(0.31, 6);
  for (let index = 0; index < 8; index += 1) {
    const angle = index / 8 * Math.PI * 2;
    const material = new THREE.MeshPhysicalMaterial({
      color: index % 2 ? 0xe8ad39 : 0xffdf7d,
      emissive: 0x8b460a,
      emissiveIntensity: 0.8,
      metalness: 0.72,
      roughness: 0.16,
      clearcoat: 1,
      clearcoatRoughness: 0.12,
      transparent: true,
      opacity: 0,
      depthWrite: false,
      side: THREE.DoubleSide,
    });
    const plate = new THREE.Mesh(plateGeometry, material);
    plate.name = `EightComboAssembledMirrorPlate${index + 1}`;
    plate.position.set(Math.sin(angle) * 0.96, 0.05 + (index % 2) * 0.18, Math.cos(angle) * 0.96);
    plate.lookAt(new THREE.Vector3(0, plate.position.y, 0));
    plate.rotateY(Math.PI);
    plate.scale.setScalar(0.001);
    plate.renderOrder = 74;
    root.add(plate);
    plates.push({ plate, material, angle });
  }

  const baseMaterial = additiveMaterial(0xffcc55, 0, true);
  const base = new THREE.Mesh(new THREE.RingGeometry(0.72, 0.83, 24), baseMaterial);
  base.name = 'EightComboMirrorShieldGroundSeal';
  base.rotation.x = -Math.PI * 0.5;
  base.position.y = -0.82;
  base.scale.setScalar(0.001);
  base.renderOrder = 69;
  root.add(base);

  const texture = makeSoftTexture();
  const contactMaterial = new THREE.SpriteMaterial({
    map: texture,
    transparent: true,
    opacity: 0,
    depthWrite: false,
    depthTest: false,
    blending: THREE.AdditiveBlending,
    toneMapped: false,
  });
  const contact = new THREE.Sprite(contactMaterial);
  contact.name = 'EightComboShieldContactCompressionFlash';
  contact.scale.set(0.001, 0.001, 1);
  contact.visible = false;
  contact.renderOrder = 98;
  root.add(contact);

  const sparkleCount = 28;
  const sparklePositions = new Float32Array(sparkleCount * 3);
  const sparkleItems = Array.from({ length: sparkleCount }, (_, index) => {
    const band = index % 4;
    const angle = index / sparkleCount * Math.PI * 2 + Math.sin(index * 7.13) * 0.18;
    const radius = 1.02 + band * 0.055 + (Math.sin(index * 5.37) * 0.5 + 0.5) * 0.06;
    const baseY = -0.7 + ((index * 11) % sparkleCount) / (sparkleCount - 1) * 1.45;
    const speed = 0.15 + (index % 5) * 0.022;
    const phase = index * 1.71;
    sparklePositions[index * 3] = Math.sin(angle) * radius;
    sparklePositions[index * 3 + 1] = baseY;
    sparklePositions[index * 3 + 2] = Math.cos(angle) * radius;
    return { angle, radius, baseY, speed, phase };
  });
  const sparkleGeometry = new THREE.BufferGeometry();
  const sparklePositionAttribute = new THREE.BufferAttribute(sparklePositions, 3);
  sparkleGeometry.setAttribute('position', sparklePositionAttribute);
  const sparkleTexture = makeGoldenSparkleTexture();
  const sparkleMaterial = new THREE.PointsMaterial({
    color: 0xffd56a,
    map: sparkleTexture,
    size: 5.6,
    sizeAttenuation: false,
    transparent: true,
    opacity: 0,
    alphaTest: 0.015,
    depthWrite: false,
    depthTest: false,
    blending: THREE.AdditiveBlending,
    toneMapped: false,
  });
  const sparklePoints = new THREE.Points(sparkleGeometry, sparkleMaterial);
  sparklePoints.name = 'EightComboBatchedGoldenShieldSparkles';
  sparklePoints.visible = false;
  sparklePoints.renderOrder = 97;
  root.add(sparklePoints);
  const sparkles = {
    points: sparklePoints,
    material: sparkleMaterial,
    positions: sparklePositions,
    positionAttribute: sparklePositionAttribute,
    items: sparkleItems,
  };

  return { root, shell, shellMaterial, plates, base, baseMaterial, contact, contactMaterial, texture, sparkles };
}

function createProjectile(target, heroCenter, targetIndex, enemyPhaseIndex) {
  const enemyCenter = target.entry.mount.position.clone().add(new THREE.Vector3(0, target.kind === 'boss' ? 1.05 : 0.86, 0));
  const toHero = heroCenter.clone().sub(enemyCenter).normalize();
  const start = enemyCenter.clone().addScaledVector(toHero, 0.34);
  const contact = heroCenter.clone().addScaledVector(toHero, -0.93);
  const returnEnd = enemyCenter.clone().addScaledVector(toHero, 0.24);
  const root = new THREE.Group();
  root.name = `EightComboEnemyPhase${enemyPhaseIndex + 1}Attack${targetIndex + 1}`;
  root.visible = false;

  const coreMaterial = additiveMaterial(0xff6b57, 0.96, false);
  const core = new THREE.Mesh(new THREE.OctahedronGeometry(targetIndex === 0 ? 0.13 : 0.115, 1), coreMaterial);
  core.name = 'EightComboIncomingAttackCore';
  core.renderOrder = 82;
  root.add(core);

  const auraMaterial = additiveMaterial(0xffa05e, 0.44, false);
  const aura = new THREE.Mesh(new THREE.SphereGeometry(0.2, 12, 8), auraMaterial);
  aura.name = 'EightComboIncomingAttackAura';
  aura.renderOrder = 80;
  root.add(aura);

  const tailMaterial = additiveMaterial(0xff493d, 0.48, false);
  const tail = new THREE.Mesh(new THREE.ConeGeometry(0.12, 0.62, 8, 1, true), tailMaterial);
  tail.name = 'EightComboIncomingAttackTail';
  tail.position.set(0, -0.34, 0);
  tail.renderOrder = 79;
  root.add(tail);

  const contactFlashMaterial = additiveMaterial(0xfff2b0, 0, false);
  const contactFlash = new THREE.Mesh(new THREE.OctahedronGeometry(0.24, 1), contactFlashMaterial);
  contactFlash.name = 'EightComboMirrorContactFlash';
  contactFlash.position.copy(contact);
  contactFlash.scale.setScalar(0.001);
  contactFlash.renderOrder = 92;

  const hitFlashMaterial = additiveMaterial(0xffd46a, 0, false);
  const hitFlash = new THREE.Mesh(new THREE.OctahedronGeometry(target.kind === 'boss' ? 0.56 : 0.42, 1), hitFlashMaterial);
  hitFlash.name = 'EightComboReflectedImpactFlash';
  hitFlash.position.copy(returnEnd);
  hitFlash.scale.setScalar(0.001);
  hitFlash.renderOrder = 92;

  const number = createDamageSprite(`-${target.damage}`);
  number.sprite.position.copy(enemyCenter).add(new THREE.Vector3(0, target.kind === 'boss' ? 1.2 : 1.0, 0));
  const launchTime = 0.72 + enemyPhaseIndex * 1.25 + targetIndex * 0.14;
  const contactTime = launchTime + 0.31;
  const returnTime = contactTime + 0.1;
  const hitTime = returnTime + 0.29;
  return {
    target, root, core, coreMaterial, aura, auraMaterial, tail, tailMaterial,
    contactFlash, contactFlashMaterial, hitFlash, hitFlashMaterial,
    number: number.sprite, numberMaterial: number.material,
    start, contact, returnEnd, toHero, launchTime, contactTime, returnTime, hitTime,
    enemyPhaseIndex, targetIndex,
    launched: false, reflected: false, hit: false,
  };
}

function orientProjectile(projectile, direction) {
  projectile.root.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), direction);
}

function faceToward(mount, target) {
  const direction = target.clone().sub(mount.position).setY(0);
  if (direction.lengthSq() < 0.001) return;
  mount.rotation.y = Math.atan2(direction.x, direction.z);
}

function disposeObject(root) {
  root.traverse(child => {
    child.geometry?.dispose?.();
    const materials = Array.isArray(child.material) ? child.material : [child.material];
    materials.filter(Boolean).forEach(material => {
      material.map?.dispose?.();
      material.dispose?.();
    });
  });
}

export class AbsoluteReflectEffect {
  constructor(scene, camera) {
    this.scene = scene;
    this.camera = camera;
    this.root = new THREE.Group();
    this.root.name = 'ComboReward_AbsoluteReflectEffect';
    scene.add(this.root);
    this.effect = null;
    this.duration = 6.65;
  }

  play({ hero, targets }) {
    this.clear();
    const group = new THREE.Group();
    group.name = 'EightComboAbsoluteReflectEnemyPhase';
    this.root.add(group);
    const heroCenter = hero.mount.position.clone().add(new THREE.Vector3(0, 1.02, 0));
    const shield = createMirrorShield(heroCenter);
    group.add(shield.root);
    const enemyPhaseCount = 4;
    const projectiles = Array.from({ length: enemyPhaseCount }, (_, enemyPhaseIndex) => (
      targets.map((target, targetIndex) => createProjectile(target, heroCenter, targetIndex, enemyPhaseIndex))
    )).flat();
    projectiles.forEach(projectile => {
      group.add(projectile.root, projectile.contactFlash, projectile.hitFlash, projectile.number);
    });
    this.effect = {
      group, hero, targets, heroCenter, shield, projectiles,
      elapsed: 0, prepared: false, enemyPhaseCount, reflectedEnemyPhases: 0,
      allEnemyPhasesComplete: false,
    };
  }

  prepare(payload) {
    this.play(payload);
    if (!this.effect) return;
    this.effect.group.visible = false;
    this.effect.prepared = true;
  }

  warmup(renderer) {
    if (!this.effect || !renderer) return;
    const visibility = [];
    this.effect.group.traverse(object => {
      visibility.push([object, object.visible]);
      object.visible = true;
    });
    renderer.compile(this.scene, this.camera);
    const previousRenderTarget = renderer.getRenderTarget();
    const warmupTarget = new THREE.WebGLRenderTarget(4, 4, { depthBuffer: true, stencilBuffer: false });
    renderer.setRenderTarget(warmupTarget);
    renderer.render(this.scene, this.camera);
    renderer.setRenderTarget(previousRenderTarget);
    warmupTarget.dispose();
    visibility.forEach(([object, visible]) => { object.visible = visible; });
  }

  activate() {
    if (!this.effect?.prepared) return false;
    this.effect.prepared = false;
    this.effect.elapsed = 0;
    this.effect.group.visible = true;
    return true;
  }

  launchEnemyAttack(projectile) {
    if (projectile.launched) return;
    projectile.launched = true;
    projectile.root.visible = true;
    projectile.root.position.copy(projectile.start);
    faceToward(projectile.target.entry.mount, this.effect.heroCenter);
    projectile.target.entry.model.userData.playAction?.('attack', 0.52);
  }

  reflectAttack(projectile) {
    if (projectile.reflected) return;
    projectile.reflected = true;
    projectile.coreMaterial.color.setHex(0xfff3bd);
    projectile.auraMaterial.color.setHex(0xffcc4d);
    projectile.tailMaterial.color.setHex(0xff9e2f);
    projectile.contactFlash.visible = true;
    this.effect.shield.contact.visible = true;
    this.effect.shield.contact.position.copy(projectile.contact).sub(this.effect.heroCenter);
  }

  hitAttacker(projectile) {
    if (projectile.hit) return;
    projectile.hit = true;
    projectile.root.visible = false;
    projectile.hitFlash.visible = true;
    projectile.number.visible = true;
    projectile.target.entry.model.userData.playAction?.('hit', projectile.target.kind === 'boss' ? 0.62 : 0.5);
  }

  update(delta) {
    const effect = this.effect;
    if (!effect || effect.prepared) return;
    effect.elapsed += Math.max(0, delta);
    const elapsed = effect.elapsed;
    const formation = THREE.MathUtils.smoothstep(elapsed, 0.02, 0.44);
    const lastHitTime = Math.max(...effect.projectiles.map(projectile => projectile.hitTime));
    const phaseDone = THREE.MathUtils.smoothstep(elapsed, lastHitTime + 0.38, lastHitTime + 0.7);
    const shieldEnvelope = formation * (1 - phaseDone);
    setReflectDebug('reflectEffectElapsed', elapsed.toFixed(2));
    setReflectDebug('reflectShieldEnvelope', shieldEnvelope.toFixed(3));
    effect.shield.shell.scale.setScalar(Math.max(0.001, easeOutCubic(formation) * (1 - phaseDone * 0.18)));
    effect.shield.shellMaterial.uniforms.uOpacity.value = shieldEnvelope * (0.78 + Math.sin(elapsed * 5.5) * 0.08);
    effect.shield.shellMaterial.uniforms.uPulse.value = elapsed;
    effect.shield.shell.rotation.y += delta * 0.22;
    effect.shield.base.scale.setScalar(Math.max(0.001, easeOutCubic(formation) * (1 + phaseDone * 0.28)));
    effect.shield.baseMaterial.opacity = shieldEnvelope * 0.52;
    effect.shield.plates.forEach(({ plate, material, angle }, index) => {
      const local = clamp01((elapsed - index * 0.025) / 0.38);
      const plateFormation = easeOutCubic(local) * (1 - phaseDone);
      plate.scale.setScalar(Math.max(0.001, plateFormation));
      plate.position.y = 0.05 + (index % 2) * 0.18 + Math.sin(elapsed * 2.6 + angle) * 0.025;
      material.opacity = plateFormation * (0.22 + Math.sin(elapsed * 4.6 + angle) * 0.045);
      material.emissiveIntensity = 0.66 + Math.sin(elapsed * 5.2 + angle) * 0.18;
    });

    let contactEnergy = 0;
    effect.projectiles.forEach((projectile, index) => {
      if (elapsed >= projectile.launchTime) this.launchEnemyAttack(projectile);
      if (!projectile.launched) return;
      if (elapsed < projectile.contactTime) {
        const local = clamp01((elapsed - projectile.launchTime) / (projectile.contactTime - projectile.launchTime));
        projectile.root.position.copy(projectile.start).lerp(projectile.contact, easeInCubic(local));
        orientProjectile(projectile, projectile.toHero);
      } else {
        this.reflectAttack(projectile);
        if (elapsed < projectile.returnTime) {
          projectile.root.position.copy(projectile.contact);
          projectile.root.scale.setScalar(1 + Math.sin((elapsed - projectile.contactTime) / 0.1 * Math.PI) * 0.42);
        } else if (elapsed < projectile.hitTime) {
          const local = clamp01((elapsed - projectile.returnTime) / (projectile.hitTime - projectile.returnTime));
          projectile.root.scale.setScalar(1);
          projectile.root.position.copy(projectile.contact).lerp(projectile.returnEnd, easeInOutCubic(local));
          orientProjectile(projectile, projectile.toHero.clone().negate());
        } else {
          this.hitAttacker(projectile);
        }
      }

      projectile.core.rotation.y += delta * (7.2 + index * 0.4);
      projectile.core.rotation.x += delta * 4.6;
      projectile.aura.scale.setScalar(0.9 + Math.sin(elapsed * 18 + index) * 0.1);
      const contactLocal = clamp01((elapsed - projectile.contactTime) / 0.27);
      if (elapsed >= projectile.contactTime && contactLocal < 1) {
        const flash = Math.sin(contactLocal * Math.PI);
        projectile.contactFlash.scale.setScalar(0.24 + easeOutCubic(contactLocal) * 0.72);
        projectile.contactFlashMaterial.opacity = flash * 0.88;
        contactEnergy = Math.max(contactEnergy, flash);
      } else {
        projectile.contactFlashMaterial.opacity = 0;
        if (elapsed >= projectile.contactTime + 0.27) projectile.contactFlash.visible = false;
      }

      const hitLocal = clamp01((elapsed - projectile.hitTime) / 0.68);
      if (projectile.hit && hitLocal < 1) {
        const hitPop = easeOutCubic(Math.min(1, hitLocal * 5));
        projectile.hitFlash.scale.setScalar(0.3 + hitPop * (projectile.target.kind === 'boss' ? 1.25 : 0.96));
        projectile.hitFlashMaterial.opacity = Math.max(0, 1 - hitLocal * 3.7) * 0.9;
        const numberPop = easeOutCubic(Math.min(1, hitLocal * 4.2));
        const numberScale = projectile.target.kind === 'boss' ? 1.62 : 1.48;
        projectile.number.scale.set(numberScale * numberPop, numberScale * 0.46 * numberPop, 1);
        projectile.number.position.y += delta * 0.34;
        projectile.numberMaterial.opacity = hitLocal < 0.62 ? 1 : Math.max(0, (1 - hitLocal) / 0.38);
      } else if (projectile.hit) {
        projectile.hitFlash.visible = false;
        projectile.number.visible = false;
      }
    });

    effect.shield.shellMaterial.uniforms.uContact.value = contactEnergy;
    const sparkleShimmer = 0.5 + Math.sin(elapsed * 7.4) * 0.23 + Math.sin(elapsed * 12.7) * 0.12;
    effect.shield.sparkles.points.visible = shieldEnvelope > 0.015;
    effect.shield.sparkles.items.forEach((sparkle, index) => {
      const orbitAngle = sparkle.angle + elapsed * sparkle.speed;
      const breathe = Math.sin(elapsed * 2.5 + sparkle.phase) * 0.045;
      const contactPush = contactEnergy * (0.06 + (index % 3) * 0.025);
      const disperse = phaseDone * (0.28 + (index % 4) * 0.06);
      const radius = sparkle.radius + breathe + contactPush + disperse;
      effect.shield.sparkles.positions[index * 3] = Math.sin(orbitAngle) * radius;
      effect.shield.sparkles.positions[index * 3 + 1] = sparkle.baseY
        + Math.sin(elapsed * (1.7 + (index % 4) * 0.13) + sparkle.phase) * 0.09
        + phaseDone * Math.sin(sparkle.phase) * 0.22;
      effect.shield.sparkles.positions[index * 3 + 2] = Math.cos(orbitAngle) * radius;
    });
    effect.shield.sparkles.positionAttribute.needsUpdate = true;
    effect.shield.sparkles.material.opacity = shieldEnvelope * Math.min(0.94,
      0.42 + sparkleShimmer * 0.24 + contactEnergy * 0.36);
    effect.shield.sparkles.material.size = 5.3 + sparkleShimmer * 1.25 + contactEnergy * 1.7;
    effect.shield.sparkles.points.rotation.y = elapsed * 0.05;
    if (effect.shield.contact.visible) {
      const contactFade = Math.max(...effect.projectiles.map(projectile => {
        const local = clamp01((elapsed - projectile.contactTime) / 0.22);
        return elapsed >= projectile.contactTime && local < 1 ? Math.sin(local * Math.PI) : 0;
      }));
      effect.shield.contact.scale.setScalar(0.4 + contactFade * 0.86);
      effect.shield.contactMaterial.opacity = contactFade * 0.92;
      if (contactFade <= 0) effect.shield.contact.visible = false;
    }

    effect.reflectedEnemyPhases = Array.from({ length: effect.enemyPhaseCount }, (_, phaseIndex) => {
      const phaseHitTimes = effect.projectiles
        .filter(projectile => projectile.enemyPhaseIndex === phaseIndex)
        .map(projectile => projectile.hitTime);
      return Math.max(...phaseHitTimes) + 0.2 <= elapsed;
    }).filter(Boolean).length;
    effect.group.userData.reflectedEnemyPhases = effect.reflectedEnemyPhases;
    setReflectDebug('reflectEnemyPhases', effect.reflectedEnemyPhases);

    if (!effect.allEnemyPhasesComplete && elapsed >= lastHitTime + 0.36) {
      effect.allEnemyPhasesComplete = true;
      effect.group.userData.absoluteReflectState = 'expired_after_four_enemy_phases';
      setReflectDebug('reflectState', 'expired_after_four_enemy_phases');
    }
  }

  clear() {
    if (!this.effect) return;
    this.root.remove(this.effect.group);
    disposeObject(this.effect.group);
    this.effect = null;
  }
}

export class AbsoluteReflectShieldEffect {
  constructor(scene) {
    this.scene = scene;
    this.root = new THREE.Group();
    this.root.name = 'ComboReward_PersistentAbsoluteReflectShield';
    scene.add(this.root);
    this.effect = null;
  }

  play({ hero, turns = 4 }) {
    this.clear();
    const center = hero.position.clone().add(new THREE.Vector3(0, 1.02, 0));
    const shield = createMirrorShield(center);
    this.root.add(shield.root);
    this.effect = {
      hero, shield, elapsed: 0, turnsLeft: turns,
      releaseStartedAt: null, contactStartedAt: -10,
    };
  }

  setTurns(turnsLeft) {
    if (!this.effect) return;
    this.effect.turnsLeft = Math.max(0, turnsLeft || 0);
    if (this.effect.turnsLeft === 0) this.release();
  }

  contact(sourcePosition) {
    const effect = this.effect;
    if (!effect || effect.releaseStartedAt != null) return;
    const center = effect.shield.root.position;
    const direction = sourcePosition.clone().sub(center).setY(0);
    if (direction.lengthSq() < 0.001) direction.set(0, 0, 1);
    direction.normalize();
    effect.shield.contact.position.copy(direction.multiplyScalar(0.94));
    effect.shield.contact.position.y = -0.02;
    effect.shield.contact.visible = true;
    effect.contactStartedAt = effect.elapsed;
  }

  release() {
    if (!this.effect || this.effect.releaseStartedAt != null) return;
    this.effect.releaseStartedAt = this.effect.elapsed;
  }

  update(delta) {
    const effect = this.effect;
    if (!effect) return;
    effect.elapsed += Math.max(0, delta);
    const elapsed = effect.elapsed;
    effect.shield.root.position.copy(effect.hero.position).add(new THREE.Vector3(0, 1.02, 0));
    const formation = THREE.MathUtils.smoothstep(elapsed, 0.02, 0.44);
    const releaseLocal = effect.releaseStartedAt == null ? 0 : elapsed - effect.releaseStartedAt;
    const phaseDone = easeInOutCubic(releaseLocal / 0.62);
    const shieldEnvelope = formation * (1 - phaseDone);
    const contactLocal = elapsed - effect.contactStartedAt;
    const contactEnergy = contactLocal >= 0 && contactLocal < 0.3
      ? Math.sin(clamp01(contactLocal / 0.3) * Math.PI)
      : 0;

    effect.shield.shell.scale.setScalar(Math.max(0.001, easeOutCubic(formation) * (1 - phaseDone * 0.18)));
    effect.shield.shellMaterial.uniforms.uOpacity.value = shieldEnvelope * (0.78 + Math.sin(elapsed * 5.5) * 0.08);
    effect.shield.shellMaterial.uniforms.uPulse.value = elapsed;
    effect.shield.shellMaterial.uniforms.uContact.value = contactEnergy;
    effect.shield.shell.rotation.y += delta * 0.22;
    effect.shield.base.scale.setScalar(Math.max(0.001, easeOutCubic(formation) * (1 + phaseDone * 0.28)));
    effect.shield.baseMaterial.opacity = shieldEnvelope * 0.52;
    effect.shield.plates.forEach(({ plate, material, angle }, index) => {
      const local = clamp01((elapsed - index * 0.025) / 0.38);
      const plateFormation = easeOutCubic(local) * (1 - phaseDone);
      plate.scale.setScalar(Math.max(0.001, plateFormation));
      plate.position.y = 0.05 + (index % 2) * 0.18 + Math.sin(elapsed * 2.6 + angle) * 0.025;
      material.opacity = plateFormation * (0.22 + Math.sin(elapsed * 4.6 + angle) * 0.045);
      material.emissiveIntensity = 0.66 + Math.sin(elapsed * 5.2 + angle) * 0.18 + contactEnergy * 0.26;
    });

    const sparkleShimmer = 0.5 + Math.sin(elapsed * 7.4) * 0.23 + Math.sin(elapsed * 12.7) * 0.12;
    effect.shield.sparkles.points.visible = shieldEnvelope > 0.015;
    effect.shield.sparkles.items.forEach((sparkle, index) => {
      const orbitAngle = sparkle.angle + elapsed * sparkle.speed;
      const breathe = Math.sin(elapsed * 2.5 + sparkle.phase) * 0.045;
      const contactPush = contactEnergy * (0.06 + (index % 3) * 0.025);
      const disperse = phaseDone * (0.28 + (index % 4) * 0.06);
      const radius = sparkle.radius + breathe + contactPush + disperse;
      effect.shield.sparkles.positions[index * 3] = Math.sin(orbitAngle) * radius;
      effect.shield.sparkles.positions[index * 3 + 1] = sparkle.baseY
        + Math.sin(elapsed * (1.7 + (index % 4) * 0.13) + sparkle.phase) * 0.09
        + phaseDone * Math.sin(sparkle.phase) * 0.22;
      effect.shield.sparkles.positions[index * 3 + 2] = Math.cos(orbitAngle) * radius;
    });
    effect.shield.sparkles.positionAttribute.needsUpdate = true;
    effect.shield.sparkles.material.opacity = shieldEnvelope * Math.min(0.94,
      0.42 + sparkleShimmer * 0.24 + contactEnergy * 0.36);
    effect.shield.sparkles.material.size = 5.3 + sparkleShimmer * 1.25 + contactEnergy * 1.7;
    effect.shield.sparkles.points.rotation.y = elapsed * 0.05;

    effect.shield.contact.scale.setScalar(0.4 + contactEnergy * 0.86);
    effect.shield.contactMaterial.opacity = contactEnergy * 0.92;
    if (contactEnergy <= 0 && contactLocal >= 0.3) effect.shield.contact.visible = false;
    if (phaseDone >= 1) this.clear();
  }

  clear() {
    if (!this.effect) return;
    this.root.remove(this.effect.shield.root);
    disposeObject(this.effect.shield.root);
    this.effect = null;
  }
}
