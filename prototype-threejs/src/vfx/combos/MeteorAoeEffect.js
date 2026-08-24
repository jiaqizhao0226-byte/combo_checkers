import * as THREE from '../../../vendor/three.module.js';
import { createVfxCanvas } from '../createVfxCanvas.js';

const clamp01 = value => Math.max(0, Math.min(1, value));
const easeOutCubic = value => 1 - Math.pow(1 - clamp01(value), 3);
const easeInCubic = value => Math.pow(clamp01(value), 3);
let softSparkTexture = null;

function getSoftSparkTexture() {
  if (softSparkTexture) return softSparkTexture;
  const canvas = createVfxCanvas();
  canvas.width = 64;
  canvas.height = 64;
  const context = canvas.getContext('2d');
  const gradient = context.createRadialGradient(32, 32, 1, 32, 32, 31);
  gradient.addColorStop(0, 'rgba(255,255,255,1)');
  gradient.addColorStop(0.28, 'rgba(255,255,255,0.94)');
  gradient.addColorStop(0.66, 'rgba(255,255,255,0.38)');
  gradient.addColorStop(1, 'rgba(255,255,255,0)');
  context.fillStyle = gradient;
  context.fillRect(0, 0, 64, 64);
  softSparkTexture = new THREE.CanvasTexture(canvas);
  softSparkTexture.colorSpace = THREE.SRGBColorSpace;
  softSparkTexture.minFilter = THREE.LinearFilter;
  softSparkTexture.magFilter = THREE.LinearFilter;
  softSparkTexture.generateMipmaps = false;
  softSparkTexture.userData.sharedVfxTexture = true;
  return softSparkTexture;
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

function createMeteorRockMaterial(size, index) {
  return new THREE.ShaderMaterial({
    name: 'SevenComboMeteorRockWithMoltenCracks',
    uniforms: {
      uScale: { value: 1 / size },
      uVariant: { value: index * 0.73 },
    },
    vertexShader: `
      varying vec3 vRockPosition;
      varying vec3 vRockNormal;
      uniform float uScale;
      void main() {
        vRockPosition = position * uScale;
        vRockNormal = normalize(normalMatrix * normal);
        gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
      }
    `,
    fragmentShader: `
      varying vec3 vRockPosition;
      varying vec3 vRockNormal;
      uniform float uVariant;
      void main() {
        vec3 p = vRockPosition;
        float seamA = abs(sin(p.x * 7.3 + p.y * 5.1 + sin(p.z * 4.4 + uVariant) * 1.35));
        float seamB = abs(cos(p.z * 6.7 - p.y * 4.2 + sin(p.x * 5.0 - uVariant) * 1.1));
        float cracks = 1.0 - smoothstep(0.035, 0.15, min(seamA, seamB));
        float facets = 0.5 + 0.5 * dot(normalize(vRockNormal), normalize(vec3(-0.45, 0.8, 0.55)));
        float rim = pow(1.0 - abs(vRockNormal.z), 2.4);
        vec3 rock = mix(vec3(0.055, 0.018, 0.012), vec3(0.19, 0.055, 0.025), facets);
        vec3 lava = mix(vec3(1.0, 0.12, 0.01), vec3(1.0, 0.56, 0.08), facets);
        vec3 color = mix(rock, lava, cracks * 0.88) + vec3(0.32, 0.055, 0.01) * rim;
        gl_FragColor = vec4(color, 1.0);
      }
    `,
    side: THREE.DoubleSide,
    toneMapped: false,
  });
}

function createDamageSprite(label, color) {
  const canvas = createVfxCanvas();
  canvas.width = 512;
  canvas.height = 256;
  const context = canvas.getContext('2d');
  context.clearRect(0, 0, canvas.width, canvas.height);
  context.textAlign = 'center';
  context.textBaseline = 'middle';
  context.shadowColor = 'rgba(83, 18, 4, 0.48)';
  context.shadowBlur = 13;
  context.shadowOffsetY = 5;
  context.fillStyle = color;
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
  sprite.name = 'SevenComboMeteorShowerDamageNumber';
  sprite.center.set(0.5, 0.2);
  sprite.scale.set(0.001, 0.001, 1);
  sprite.renderOrder = 94;
  sprite.userData.texture = texture;
  return sprite;
}

function createImpactFlameSprite(index) {
  const canvas = createVfxCanvas();
  canvas.width = 128;
  canvas.height = 256;
  const context = canvas.getContext('2d');
  context.clearRect(0, 0, canvas.width, canvas.height);
  const outer = context.createLinearGradient(0, canvas.height, 0, 0);
  outer.addColorStop(0, 'rgba(255, 54, 8, 0.96)');
  outer.addColorStop(0.48, index % 2 ? 'rgba(255, 126, 20, 0.9)' : 'rgba(255, 92, 10, 0.92)');
  outer.addColorStop(1, 'rgba(255, 214, 84, 0)');
  context.fillStyle = outer;
  context.beginPath();
  context.moveTo(64, 248);
  context.bezierCurveTo(23, 226, 30, 170, 54, 124);
  context.bezierCurveTo(70, 92, 64, 54, 78, 18);
  context.bezierCurveTo(112, 92, 108, 174, 102, 210);
  context.bezierCurveTo(95, 242, 79, 252, 64, 248);
  context.closePath();
  context.fill();
  const inner = context.createLinearGradient(0, 232, 0, 86);
  inner.addColorStop(0, 'rgba(255, 250, 184, 0.94)');
  inner.addColorStop(1, 'rgba(255, 184, 52, 0)');
  context.fillStyle = inner;
  context.beginPath();
  context.moveTo(63, 232);
  context.bezierCurveTo(45, 210, 50, 178, 66, 145);
  context.bezierCurveTo(84, 178, 88, 218, 63, 232);
  context.fill();

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
    blending: THREE.AdditiveBlending,
    toneMapped: false,
  });
  const flame = new THREE.Sprite(material);
  flame.name = 'SevenComboSmallMeteorImpactFlame';
  flame.center.set(0.5, 0.08);
  flame.scale.set(0.001, 0.001, 1);
  flame.renderOrder = 83;
  return { flame, material };
}

function createBoardImpactGlow() {
  const canvas = createVfxCanvas();
  canvas.width = 256;
  canvas.height = 256;
  const context = canvas.getContext('2d');
  const gradient = context.createRadialGradient(128, 128, 4, 128, 128, 124);
  gradient.addColorStop(0, 'rgba(255, 246, 196, 0.84)');
  gradient.addColorStop(0.14, 'rgba(255, 184, 62, 0.62)');
  gradient.addColorStop(0.4, 'rgba(255, 76, 18, 0.25)');
  gradient.addColorStop(1, 'rgba(255, 32, 5, 0)');
  context.fillStyle = gradient;
  context.fillRect(0, 0, 256, 256);
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
    blending: THREE.AdditiveBlending,
    toneMapped: false,
  });
  const glow = new THREE.Sprite(material);
  glow.name = 'SevenComboMeteorShowerBoardGlow';
  glow.position.y = 0.56;
  glow.scale.set(0.001, 0.001, 1);
  glow.renderOrder = 76;
  glow.userData.texture = texture;
  return { glow, material };
}

function createSmallMeteor(end, index, hitTime) {
  const fallDuration = 0.42 + (index % 3) * 0.03;
  const startTime = hitTime - fallDuration;
  const start = end.clone().add(new THREE.Vector3(
    -0.5 - (index % 3) * 0.12,
    4.15 + (index % 4) * 0.2,
    -1.12 + (index % 2) * 0.18
  ));
  const direction = end.clone().sub(start).normalize();
  const root = new THREE.Group();
  root.name = `SevenComboSmallMeteor${index + 1}`;
  root.position.copy(start);
  root.visible = false;

  const size = 0.19 + (index % 3) * 0.02;
  const coreMaterial = createMeteorRockMaterial(size, index);
  const core = new THREE.Mesh(new THREE.IcosahedronGeometry(size, 1), coreMaterial);
  core.name = 'SevenComboSmallMeteorRockCore';
  core.castShadow = false;
  core.renderOrder = 67;
  root.add(core);

  const auraMaterial = additiveMaterial(index % 2 ? 0xff5010 : 0xff8b20, 0.3, false);
  const aura = new THREE.Mesh(new THREE.IcosahedronGeometry(size * 1.25, 1), auraMaterial);
  aura.name = 'SevenComboSmallMeteorHeat';
  aura.renderOrder = 69;
  root.add(aura);

  const tailLength = 0.88 + (index % 3) * 0.08;
  const tailLayers = [
    {
      name: 'SevenComboSmallMeteorOuterFlameTail', length: tailLength,
      radius: size * 0.58, tip: 0.018, color: index % 2 ? 0xff3b0b : 0xff5a0d,
      opacity: 0.28, order: 64,
    },
    {
      name: 'SevenComboSmallMeteorInnerFlameTail', length: tailLength * 0.68,
      radius: size * 0.22, tip: 0.008, color: 0xffc34f,
      opacity: 0.52, order: 66,
    },
  ].map(layer => {
    const material = additiveMaterial(layer.color, layer.opacity, false);
    const mesh = new THREE.Mesh(
      new THREE.CylinderGeometry(layer.radius, layer.tip, layer.length, 8, 1, true),
      material
    );
    mesh.name = layer.name;
    mesh.position.addScaledVector(direction, -layer.length * 0.5 - size * 0.58);
    mesh.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), direction);
    mesh.renderOrder = layer.order;
    root.add(mesh);
    return { mesh, material, baseOpacity: layer.opacity };
  });

  const sparks = Array.from({ length: 3 }, (_, sparkIndex) => {
    const material = additiveMaterial(sparkIndex === 0 ? 0xfff0a2 : 0xff6920, 0.85, false);
    const spark = new THREE.Mesh(new THREE.TetrahedronGeometry(0.026 + sparkIndex * 0.007, 0), material);
    spark.name = 'SevenComboSmallMeteorSpark';
    spark.renderOrder = 70;
    root.add(spark);
    return { spark, material, phase: sparkIndex / 3, side: (sparkIndex - 1) * 0.07 };
  });

  const impactRoot = new THREE.Group();
  impactRoot.name = 'SevenComboGroundMeteorImpact';
  impactRoot.position.copy(end);
  impactRoot.position.y = 0.18;
  impactRoot.visible = false;

  const flashMaterial = additiveMaterial(0xff7b21, 0, false);
  const flash = new THREE.Mesh(new THREE.IcosahedronGeometry(0.17, 1), flashMaterial);
  flash.name = 'SevenComboSmallMeteorContactFlash';
  flash.position.y = 0.18;
  flash.renderOrder = 86;
  impactRoot.add(flash);

  const ringMaterial = additiveMaterial(0xff5d12, 0, true);
  const ring = new THREE.Mesh(new THREE.CircleGeometry(1, 16), ringMaterial);
  ring.name = 'SevenComboSmallMeteorGroundFlash';
  ring.rotation.x = -Math.PI * 0.5;
  ring.position.y = 0.025;
  ring.scale.setScalar(0.001);
  ring.renderOrder = 78;
  impactRoot.add(ring);

  const { flame, material: flameMaterial } = createImpactFlameSprite(index);
  flame.position.y = 0.18;
  impactRoot.add(flame);

  const fragmentPositions = new Float32Array(8 * 3);
  const fragmentColors = new Float32Array(8 * 3);
  const fragmentGeometry = new THREE.BufferGeometry();
  fragmentGeometry.setAttribute('position', new THREE.BufferAttribute(fragmentPositions, 3));
  fragmentGeometry.setAttribute('color', new THREE.BufferAttribute(fragmentColors, 3));
  const fragmentMaterial = new THREE.PointsMaterial({
    map: getSoftSparkTexture(),
    size: 6.2,
    sizeAttenuation: true,
    vertexColors: true,
    transparent: true,
    opacity: 0,
    depthWrite: false,
    depthTest: false,
    blending: THREE.AdditiveBlending,
    toneMapped: false,
  });
  const fragmentPoints = new THREE.Points(fragmentGeometry, fragmentMaterial);
  fragmentPoints.name = 'SevenComboSmallMeteorBatchedImpactFragments';
  fragmentPoints.frustumCulled = false;
  fragmentPoints.renderOrder = 84;
  impactRoot.add(fragmentPoints);
  const fragmentItems = Array.from({ length: 8 }, (_, fragmentIndex) => {
    const angle = fragmentIndex / 8 * Math.PI * 2 + index * 0.17;
    const color = new THREE.Color(
      fragmentIndex % 3 === 0 ? 0xffe291 : fragmentIndex % 2 ? 0xff5414 : 0xff9a30
    );
    color.toArray(fragmentColors, fragmentIndex * 3);
    return {
      angle, speed: 0.32 + (fragmentIndex % 4) * 0.1,
      height: 0.24 + (fragmentIndex % 3) * 0.08,
    };
  });
  const fragments = {
    points: fragmentPoints,
    material: fragmentMaterial,
    items: fragmentItems,
    positions: fragmentPositions,
    positionAttribute: fragmentGeometry.getAttribute('position'),
  };

  return {
    root, start, end, direction, startTime, hitTime, fallDuration,
    core, aura, auraMaterial, tailLayers, sparks,
    impactRoot, flash, flashMaterial, ring, ringMaterial, flame, flameMaterial, fragments,
    impacted: false,
  };
}

function createTargetDamageFeedback(target) {
  const root = new THREE.Group();
  root.name = 'SevenComboAoeTargetFeedback';
  root.position.copy(target.entry.mount.position);
  root.position.y = 0.18;
  root.visible = false;

  const flashMaterial = additiveMaterial(target.kind === 'boss' ? 0xffac3f : 0xffd05a, 0, false);
  const flash = new THREE.Mesh(
    new THREE.IcosahedronGeometry(target.kind === 'boss' ? 0.27 : 0.21, 1),
    flashMaterial
  );
  flash.name = 'SevenComboAoeTargetContactFlash';
  flash.position.y = target.kind === 'boss' ? 0.94 : 0.64;
  flash.renderOrder = 90;
  root.add(flash);

  const number = createDamageSprite(`−${target.damage}`, target.kind === 'boss' ? '#ffc06a' : '#fff0ad');
  const numberBaseY = target.kind === 'boss' ? 1.9 : 1.32;
  number.position.y = numberBaseY;
  root.add(number);

  return {
    root, target, flash, flashMaterial,
    number, numberMaterial: number.material, numberBaseY,
  };
}

function createBoardShockwave(origin) {
  const root = new THREE.Group();
  root.name = 'SevenComboMeteorShowerBoardImpact';
  root.position.copy(origin).add(new THREE.Vector3(0, 0.23, 0));
  root.visible = false;

  const material = additiveMaterial(0xff5a12, 0, true);
  const wave = new THREE.Mesh(new THREE.CircleGeometry(1, 20), material);
  wave.name = 'SevenComboMeteorShowerAoeFlash';
  wave.rotation.x = -Math.PI * 0.5;
  wave.scale.setScalar(0.001);
  wave.renderOrder = 74;
  root.add(wave);

  const { glow, material: glowMaterial } = createBoardImpactGlow();
  root.add(glow);

  const light = new THREE.PointLight(0xff6727, 0, 13, 2);
  light.name = 'SevenComboMeteorShowerImpactLight';
  light.position.y = 1.15;
  root.add(light);

  const emberPositions = new Float32Array(32 * 3);
  const emberColors = new Float32Array(32 * 3);
  const emberGeometry = new THREE.BufferGeometry();
  emberGeometry.setAttribute('position', new THREE.BufferAttribute(emberPositions, 3));
  emberGeometry.setAttribute('color', new THREE.BufferAttribute(emberColors, 3));
  const emberMaterial = new THREE.PointsMaterial({
    map: getSoftSparkTexture(),
    size: 5.4,
    sizeAttenuation: true,
    vertexColors: true,
    transparent: true,
    opacity: 0,
    depthWrite: false,
    depthTest: false,
    blending: THREE.AdditiveBlending,
    toneMapped: false,
  });
  const emberPoints = new THREE.Points(emberGeometry, emberMaterial);
  emberPoints.name = 'SevenComboMeteorShowerBatchedRadialEmbers';
  emberPoints.frustumCulled = false;
  emberPoints.renderOrder = 88;
  root.add(emberPoints);
  const emberItems = Array.from({ length: 32 }, (_, index) => {
    const angle = index / 32 * Math.PI * 2 + (index % 5) * 0.14;
    const color = new THREE.Color(
      index % 4 === 0 ? 0xfff0a6 : index % 2 ? 0xff6b18 : 0xffb43c
    );
    color.toArray(emberColors, index * 3);
    return {
      angle, speed: 2.8 + (index % 8) * 0.4,
      height: 0.72 + (index % 5) * 0.16,
      delay: (index % 4) * 0.025,
    };
  });
  const embers = {
    points: emberPoints,
    material: emberMaterial,
    items: emberItems,
    positions: emberPositions,
    positionAttribute: emberGeometry.getAttribute('position'),
  };

  return { root, wave, material, glow, glowMaterial, light, embers };
}

function disposeObject(root) {
  root.traverse(child => {
    child.geometry?.dispose?.();
    const materials = Array.isArray(child.material) ? child.material : [child.material];
    materials.filter(Boolean).forEach(material => {
      if (!material.map?.userData?.sharedVfxTexture) material.map?.dispose?.();
      material.dispose?.();
    });
  });
}

export class MeteorAoeEffect {
  constructor(scene, camera) {
    this.scene = scene;
    this.camera = camera;
    this.root = new THREE.Group();
    this.root.name = 'ComboReward_MeteorAoeEffect';
    scene.add(this.root);
    this.effect = null;
    this.duration = 2.25;
    this.damageTime = 0.66;
  }

  play({ origin, targets }) {
    this.clear();
    const group = new THREE.Group();
    group.name = 'SevenComboMeteorShower';
    this.root.add(group);

    const boardMeteorOffsets = [
      [-3.5, -1.2], [-2.6, 2.15], [-1.25, -3.45], [1.25, 3.4],
      [2.75, 1.6], [3.55, -1.1], [1.9, -3.05], [-3.15, 1.25],
      [0.15, 0.1], [-0.65, 2.65], [2.15, -0.2], [-1.85, -1.55],
    ];
    const meteors = boardMeteorOffsets.map((offset, index) => {
      const end = origin.clone().add(new THREE.Vector3(offset[0], 0.32, offset[1]));
      const hitTime = 0.58 + (index % 8) * 0.016;
      return createSmallMeteor(end, index, hitTime);
    });
    const damageFeedbacks = targets.map(createTargetDamageFeedback);

    const boardShock = createBoardShockwave(origin);
    group.add(boardShock.root);
    meteors.forEach(meteor => group.add(meteor.root, meteor.impactRoot));
    damageFeedbacks.forEach(feedback => group.add(feedback.root));
    this.effect = {
      group, meteors, boardShock, targets, damageFeedbacks,
      elapsed: 0,
      damageFired: false,
      cameraPosition: this.camera.position.clone(),
      cameraQuaternion: this.camera.quaternion.clone(),
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
    const warmupTarget = new THREE.WebGLRenderTarget(4, 4, {
      depthBuffer: true,
      stencilBuffer: false,
    });
    renderer.setRenderTarget(warmupTarget);
    renderer.render(this.scene, this.camera);
    renderer.setRenderTarget(previousRenderTarget);
    warmupTarget.dispose();
    visibility.forEach(([object, visible]) => {
      object.visible = visible;
    });
  }

  activate() {
    if (!this.effect?.prepared) return false;
    this.effect.prepared = false;
    this.effect.elapsed = 0;
    this.effect.damageFired = false;
    this.effect.group.visible = true;
    return true;
  }

  fireMeteor(meteor) {
    if (meteor.impacted) return;
    meteor.impacted = true;
    meteor.root.visible = false;
    meteor.impactRoot.visible = true;
  }

  fireDamage() {
    const effect = this.effect;
    if (!effect || effect.damageFired) return;
    effect.damageFired = true;
    effect.boardShock.root.visible = true;
    effect.damageFeedbacks.forEach(feedback => {
      feedback.root.position.copy(feedback.target.entry.mount.position);
      feedback.root.position.y = 0.18;
      feedback.root.visible = true;
      feedback.target.entry.model.userData.playAction?.(
        'hit',
        feedback.target.kind === 'boss' ? 0.62 : 0.5
      );
    });
  }

  update(delta) {
    const effect = this.effect;
    if (!effect || effect.prepared) return;
    effect.elapsed += Math.max(0, delta);
    const elapsed = effect.elapsed;
    this.camera.position.copy(effect.cameraPosition);
    this.camera.quaternion.copy(effect.cameraQuaternion);

    effect.meteors.forEach((meteor, meteorIndex) => {
      const local = clamp01((elapsed - meteor.startTime) / meteor.fallDuration);
      const active = elapsed >= meteor.startTime && elapsed < meteor.hitTime;
      meteor.root.visible = active;
      if (active) {
        const fall = easeInCubic(local);
        meteor.root.position.copy(meteor.start).lerp(meteor.end, fall);
        meteor.core.rotation.x += delta * (5.2 + meteorIndex * 0.08);
        meteor.core.rotation.y += delta * (6.4 + meteorIndex * 0.1);
        meteor.aura.rotation.x -= delta * 3.4;
        meteor.aura.rotation.y += delta * 4.6;
        meteor.aura.scale.setScalar(0.92 + Math.sin(elapsed * 22 + meteorIndex) * 0.1);
        meteor.auraMaterial.opacity = 0.24 + Math.sin(elapsed * 19 + meteorIndex) * 0.055;
        meteor.tailLayers.forEach((layer, layerIndex) => {
          layer.material.opacity = layer.baseOpacity * (0.82 + fall * 0.18)
            * (0.94 + Math.sin(elapsed * 23 + meteorIndex + layerIndex) * 0.06);
        });
        meteor.sparks.forEach(({ spark, material, phase, side }, sparkIndex) => {
          const trail = (phase + local * 1.7) % 1;
          spark.position.copy(meteor.direction).multiplyScalar(-0.32 - trail * 0.78);
          spark.position.x += side + Math.sin(elapsed * 18 + sparkIndex) * 0.035;
          spark.position.y += Math.cos(elapsed * 16 + sparkIndex) * 0.035;
          spark.rotation.y += delta * 8;
          material.opacity = (1 - trail * 0.58) * 0.82;
        });
      }
      if (!meteor.impacted && elapsed >= meteor.hitTime) this.fireMeteor(meteor);
      if (!meteor.impacted) return;

      const impactLocal = clamp01((elapsed - meteor.hitTime) / 0.72);
      const pop = easeOutCubic(Math.min(1, impactLocal * 4.5));
      const flashScale = 0.32 + pop * 0.68;
      meteor.flash.scale.set(flashScale, flashScale * 0.68, flashScale);
      meteor.flashMaterial.opacity = Math.max(0, 1 - impactLocal * 4.2);
      meteor.ring.scale.setScalar(Math.max(0.001, easeOutCubic(impactLocal / 0.42) * 0.42));
      meteor.ringMaterial.opacity = Math.max(0, 1 - impactLocal * 3.2) * 0.48;
      const flameLocal = clamp01(impactLocal / 0.58);
      const flameEnvelope = Math.sin(flameLocal * Math.PI);
      meteor.flame.position.y = 0.18 + flameEnvelope * 0.22;
      meteor.flame.scale.set(0.3 + flameEnvelope * 0.24, 0.48 + flameEnvelope * 0.56, 1);
      meteor.flameMaterial.opacity = flameEnvelope * 0.82;
      meteor.fragments.items.forEach(({ angle, speed, height }, fragmentIndex) => {
        const distance = easeOutCubic(impactLocal) * speed;
        const offset = fragmentIndex * 3;
        meteor.fragments.positions[offset] = Math.sin(angle) * distance;
        meteor.fragments.positions[offset + 1] = 0.14 + Math.sin(impactLocal * Math.PI) * height;
        meteor.fragments.positions[offset + 2] = Math.cos(angle) * distance;
      });
      meteor.fragments.positionAttribute.needsUpdate = true;
      meteor.fragments.material.opacity = Math.max(0, 1 - impactLocal * 1.08) * 0.94;
    });

    if (!effect.damageFired && elapsed >= this.damageTime) this.fireDamage();
    if (effect.damageFired) {
      const damageLocal = clamp01((elapsed - this.damageTime) / 0.72);
      effect.damageFeedbacks.forEach(feedback => {
        const numberPop = easeOutCubic(Math.min(1, damageLocal * 4.1));
        const numberScale = feedback.target.kind === 'boss' ? 1.72 : 1.58;
        const flashPop = easeOutCubic(Math.min(1, damageLocal * 4.8));
        feedback.flash.scale.setScalar(0.35 + flashPop * (feedback.target.kind === 'boss' ? 1.05 : 0.82));
        feedback.flashMaterial.opacity = Math.max(0, 1 - damageLocal * 4.1);
        feedback.number.scale.set(numberScale * numberPop, numberScale * 0.46 * numberPop, 1);
        feedback.number.position.y = feedback.numberBaseY + damageLocal * 0.26;
        feedback.numberMaterial.opacity = damageLocal < 0.62
          ? 1
          : Math.max(0, (1 - damageLocal) / 0.38);
      });
      const waveLocal = clamp01((elapsed - this.damageTime) / 0.5);
      effect.boardShock.wave.scale.setScalar(Math.max(0.001, easeOutCubic(waveLocal) * 5.45));
      effect.boardShock.material.opacity = Math.max(0, 1 - waveLocal * 2.8) * 0.34;
      const glowLocal = clamp01((elapsed - this.damageTime) / 0.62);
      const glowEnvelope = Math.max(0, 1 - glowLocal) * Math.min(1, glowLocal * 10);
      const glowScale = 4.8 + easeOutCubic(glowLocal) * 5.6;
      effect.boardShock.glow.scale.set(glowScale, glowScale * 0.74, 1);
      effect.boardShock.glowMaterial.opacity = glowEnvelope * 0.64;
      effect.boardShock.light.intensity = glowEnvelope * 5.8;
      effect.boardShock.embers.items.forEach(({ angle, speed, height, delay }, index) => {
        const emberLocal = clamp01((elapsed - this.damageTime - delay) / 0.86);
        const distance = easeOutCubic(emberLocal) * speed;
        const envelope = Math.max(0, 1 - emberLocal) * Math.min(1, emberLocal * 12);
        const offset = index * 3;
        effect.boardShock.embers.positions[offset] = Math.sin(angle) * distance;
        effect.boardShock.embers.positions[offset + 1] = 0.18 + Math.sin(emberLocal * Math.PI) * height;
        effect.boardShock.embers.positions[offset + 2] = Math.cos(angle) * distance;
        if (envelope <= 0) effect.boardShock.embers.positions[offset + 1] = -20;
      });
      effect.boardShock.embers.positionAttribute.needsUpdate = true;
      effect.boardShock.embers.material.opacity = Math.max(0, 1 - glowLocal) * 0.9;
    }

    const rumbleStart = 0.48;
    const rumbleEnd = 0.98;
    if (elapsed >= rumbleStart && elapsed < rumbleEnd) {
      const edge = Math.min(clamp01((elapsed - rumbleStart) / 0.08), clamp01((rumbleEnd - elapsed) / 0.16));
      const strength = edge * 0.052;
      this.camera.position.x += Math.sin(elapsed * 126) * strength;
      this.camera.position.y += Math.cos(elapsed * 104) * strength * 0.48;
      this.camera.position.z += Math.sin(elapsed * 116 + 0.8) * strength * 0.82;
    }

    const slamShakeDuration = 0.36;
    const slamShakeLocal = clamp01((elapsed - this.damageTime) / slamShakeDuration);
    if (elapsed >= this.damageTime && slamShakeLocal < 1) {
      const attack = THREE.MathUtils.smoothstep(slamShakeLocal, 0, 0.075);
      const decay = Math.pow(1 - slamShakeLocal, 2.15);
      const slamEnvelope = attack * decay;
      this.camera.position.x += Math.sin(slamShakeLocal * Math.PI * 9) * slamEnvelope * 0.19;
      this.camera.position.y += Math.sin(slamShakeLocal * Math.PI * 6) * slamEnvelope * 0.045;
      this.camera.position.z += Math.sin(slamShakeLocal * Math.PI * 10 + 0.7) * slamEnvelope * 0.15;
    }
  }

  clear() {
    if (!this.effect) return;
    this.camera.position.copy(this.effect.cameraPosition);
    this.camera.quaternion.copy(this.effect.cameraQuaternion);
    this.root.remove(this.effect.group);
    disposeObject(this.effect.group);
    this.effect = null;
  }
}
