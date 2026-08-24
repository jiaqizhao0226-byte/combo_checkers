import * as THREE from '../../../vendor/three.module.js';
import { createVfxCanvas } from '../createVfxCanvas.js';

const clamp01 = value => Math.max(0, Math.min(1, value));
const easeOutCubic = value => 1 - Math.pow(1 - clamp01(value), 3);
const easeInOutCubic = value => {
  const t = clamp01(value);
  return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) * 0.5;
};

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

function cylinderBetween(start, end, radius, material, segments = 6) {
  const direction = end.clone().sub(start);
  const length = direction.length();
  const mesh = new THREE.Mesh(
    new THREE.CylinderGeometry(radius, radius, length, segments),
    material
  );
  mesh.position.copy(start).add(end).multiplyScalar(0.5);
  mesh.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), direction.normalize());
  return mesh;
}

function createRomanNumeralMarker(label) {
  const canvas = createVfxCanvas();
  canvas.width = 256;
  canvas.height = 128;
  const context = canvas.getContext('2d');
  context.clearRect(0, 0, canvas.width, canvas.height);
  context.textAlign = 'center';
  context.textBaseline = 'middle';
  context.font = '700 84px Georgia, "Times New Roman", serif';
  context.lineJoin = 'round';
  context.strokeStyle = 'rgba(10, 52, 83, 0.82)';
  context.lineWidth = 9;
  context.strokeText(label, canvas.width * 0.5, canvas.height * 0.52);
  context.fillStyle = '#bdeeff';
  context.fillText(label, canvas.width * 0.5, canvas.height * 0.52);

  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.minFilter = THREE.LinearFilter;
  texture.magFilter = THREE.LinearFilter;
  texture.generateMipmaps = false;
  const material = new THREE.MeshBasicMaterial({
    map: texture,
    color: 0xffffff,
    transparent: true,
    opacity: 0,
    depthWrite: false,
    depthTest: true,
    blending: THREE.AdditiveBlending,
    toneMapped: false,
    side: THREE.DoubleSide,
  });
  const width = 0.58 + Math.max(0, label.length - 1) * 0.22;
  const marker = new THREE.Mesh(new THREE.PlaneGeometry(width, 0.52), material);
  marker.rotation.x = -Math.PI * 0.5;
  marker.renderOrder = 42;
  return { marker, material, texture };
}

function createClockSigil(origin) {
  const root = new THREE.Group();
  root.name = 'SixComboTemporalClockSigil';
  root.position.copy(origin).add(new THREE.Vector3(0, 0.205, 0));

  const faceMaterial = additiveMaterial(0x4aaee8, 0, true);
  const face = new THREE.Mesh(new THREE.CircleGeometry(0.58, 32), faceMaterial);
  face.name = 'SixComboClockFaceGlow';
  face.rotation.x = -Math.PI * 0.5;
  face.renderOrder = 35;
  root.add(face);

  const rimMaterial = additiveMaterial(0x9beaff, 0, true);
  const rim = new THREE.Mesh(new THREE.RingGeometry(0.48, 0.565, 24), rimMaterial);
  rim.name = 'SixComboClockRim';
  rim.rotation.x = -Math.PI * 0.5;
  rim.position.y = 0.012;
  rim.renderOrder = 37;
  root.add(rim);

  const tickMaterial = additiveMaterial(0xd7f8ff, 0, true);
  const ticks = [];
  for (let index = 0; index < 12; index += 1) {
    const angle = index / 12 * Math.PI * 2;
    const tick = new THREE.Mesh(
      new THREE.BoxGeometry(index % 3 === 0 ? 0.035 : 0.022, 0.024, index % 3 === 0 ? 0.16 : 0.11),
      tickMaterial
    );
    tick.name = `SixComboClockTick${index + 1}`;
    tick.position.set(Math.sin(angle) * 0.42, 0.03, Math.cos(angle) * 0.42);
    tick.rotation.y = angle;
    tick.renderOrder = 38;
    root.add(tick);
    ticks.push(tick);
  }

  const handMaterial = additiveMaterial(0xe9fcff, 0, true);
  const minuteHand = cylinderBetween(
    new THREE.Vector3(0, 0.045, 0),
    new THREE.Vector3(0.26, 0.045, -0.11),
    0.018,
    handMaterial
  );
  minuteHand.name = 'SixComboClockMinuteHand';
  minuteHand.renderOrder = 40;
  root.add(minuteHand);
  const hourHand = cylinderBetween(
    new THREE.Vector3(0, 0.047, 0),
    new THREE.Vector3(-0.08, 0.047, 0.2),
    0.025,
    handMaterial
  );
  hourHand.name = 'SixComboClockHourHand';
  hourHand.renderOrder = 41;
  root.add(hourHand);

  return {
    root, face, faceMaterial, rim, rimMaterial, tickMaterial,
    minuteHand, hourHand, handMaterial,
  };
}

function createTemporalField(origin, maxRadius) {
  const root = new THREE.Group();
  root.name = 'SixComboBoardWideTemporalField';
  root.position.copy(origin).add(new THREE.Vector3(0, 0.165, 0));

  const veilMaterial = additiveMaterial(0x247fc3, 0, true);
  const veil = new THREE.Mesh(new THREE.CircleGeometry(1, 6), veilMaterial);
  veil.name = 'SixComboHexTimeVeil';
  veil.rotation.x = -Math.PI * 0.5;
  veil.scale.set(0.001, 0.001, 1);
  veil.renderOrder = 31;
  root.add(veil);

  const frontGlowMaterial = additiveMaterial(0x5dcfff, 0, true);
  const frontGlow = new THREE.Mesh(new THREE.RingGeometry(0.93, 1, 6), frontGlowMaterial);
  frontGlow.name = 'SixComboExpandingTimeFrontGlow';
  frontGlow.rotation.x = -Math.PI * 0.5;
  frontGlow.position.y = 0.032;
  frontGlow.scale.setScalar(0.001);
  frontGlow.renderOrder = 45;
  root.add(frontGlow);

  const frontCoreMaterial = additiveMaterial(0xd7f8ff, 0, true);
  const frontCore = new THREE.Mesh(new THREE.RingGeometry(0.985, 1, 6), frontCoreMaterial);
  frontCore.name = 'SixComboExpandingTimeFrontCore';
  frontCore.rotation.x = -Math.PI * 0.5;
  frontCore.position.y = 0.044;
  frontCore.scale.setScalar(0.001);
  frontCore.renderOrder = 46;
  root.add(frontCore);

  const turnPulses = [0, 1].map(index => {
    const material = additiveMaterial(index ? 0x75d9ff : 0xa3eaff, 0, true);
    const pulse = new THREE.Mesh(new THREE.RingGeometry(0.93, 1, 6), material);
    pulse.name = `SixComboEnemyTurnLockPulse${index + 1}`;
    pulse.rotation.x = -Math.PI * 0.5;
    pulse.position.y = 0.038 + index * 0.004;
    pulse.scale.setScalar(maxRadius);
    pulse.renderOrder = 43;
    root.add(pulse);
    return { pulse, material };
  });

  const perimeterClock = new THREE.Group();
  perimeterClock.name = 'SixComboBoardPerimeterClock';
  perimeterClock.position.y = 0.052;
  root.add(perimeterClock);
  const romanNumerals = ['XII', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI'];
  const perimeterRomanNumerals = romanNumerals.map((label, index) => {
    const angle = index / 12 * Math.PI * 2;
    const numeral = createRomanNumeralMarker(label);
    numeral.marker.name = `SixComboBoardRomanNumeral${label}`;
    numeral.marker.position.set(0, 0, -3.96);
    const radialAnchor = new THREE.Group();
    radialAnchor.name = `SixComboBoardRomanRadialAnchor${index + 1}`;
    radialAnchor.rotation.y = -angle;
    radialAnchor.add(numeral.marker);
    perimeterClock.add(radialAnchor);
    return { ...numeral, radialAnchor };
  });

  const ambientMotes = Array.from({ length: 18 }, (_, index) => {
    const material = additiveMaterial(index % 3 === 0 ? 0xd8f8ff : 0x6acfff, 0, true);
    const mote = new THREE.Mesh(new THREE.TetrahedronGeometry(0.035 + (index % 3) * 0.008, 0), material);
    mote.name = 'SixComboBoardSuspendedTimeMote';
    mote.renderOrder = 47;
    root.add(mote);
    return {
      mote, material,
      angle: index / 18 * Math.PI * 2 + (index % 4) * 0.19,
      radius: 1.15 + (index % 6) * 0.54,
      speed: 0.42 + (index % 5) * 0.07,
      baseY: 0.09 + (index % 4) * 0.07,
    };
  });

  return {
    root, veil, veilMaterial, frontGlow, frontGlowMaterial,
    frontCore, frontCoreMaterial, turnPulses, maxRadius,
    perimeterClock, perimeterRomanNumerals,
    ambientMotes,
  };
}

function createStasisMaterial() {
  return new THREE.ShaderMaterial({
    name: 'SixComboTemporalStasisFresnel',
    uniforms: {
      uInnerColor: { value: new THREE.Color(0x3e9fda) },
      uRimColor: { value: new THREE.Color(0xcaf6ff) },
      uOpacity: { value: 0 },
      uPulse: { value: 0 },
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
      uniform float uPulse;
      varying vec3 vViewNormal;
      varying vec3 vViewPosition;
      varying float vLocalY;
      void main() {
        vec3 viewDirection = normalize(-vViewPosition);
        float facing = abs(dot(normalize(vViewNormal), viewDirection));
        float fresnel = pow(1.0 - facing, 2.15);
        float horizontalBand = 0.72 + sin(vLocalY * 18.0 + uPulse * 6.28318) * 0.08;
        vec3 color = mix(uInnerColor, uRimColor, fresnel);
        float alpha = (0.055 + fresnel * 0.5) * horizontalBand * uOpacity;
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

function createStasisTarget(target, index) {
  const root = new THREE.Group();
  root.name = `SixComboFrozenEnemy${index + 1}`;
  const height = target.kind === 'boss' ? 1.65 : 1.2;
  const radius = target.kind === 'boss' ? 0.92 : 0.64;
  root.position.copy(target.entry.mount.position).add(new THREE.Vector3(0, height * 0.54, 0));

  const shellMaterial = createStasisMaterial();
  const shell = new THREE.Mesh(new THREE.SphereGeometry(1, 24, 16), shellMaterial);
  shell.name = 'SixComboPersistentStasisShell';
  shell.scale.set(radius, height * 0.55, radius * 0.82);
  shell.visible = false;
  shell.renderOrder = 51;
  root.add(shell);

  const marker = new THREE.Group();
  marker.name = 'SixComboTwoTurnStatusMarker';
  marker.position.y = height * 0.64 + 0.27;
  root.add(marker);
  const markerMaterial = additiveMaterial(0x8be5ff, 0, false);
  const markerFace = new THREE.Mesh(new THREE.RingGeometry(0.15, 0.215, 12), markerMaterial);
  markerFace.name = 'SixComboFrozenClockMarker';
  markerFace.renderOrder = 68;
  marker.add(markerFace);
  const markerHand = new THREE.Mesh(new THREE.BoxGeometry(0.028, 0.165, 0.025), markerMaterial);
  markerHand.name = 'SixComboFrozenClockHand';
  markerHand.position.y = 0.055;
  markerHand.rotation.z = -0.55;
  markerHand.renderOrder = 69;
  marker.add(markerHand);

  const pips = [-0.12, 0.12].map((x, pipIndex) => {
    const material = additiveMaterial(pipIndex ? 0x7ed8ff : 0xd1f8ff, 0, false);
    const pip = new THREE.Mesh(new THREE.OctahedronGeometry(0.087, 0), material);
    pip.name = `SixComboFrozenTurnPip${pipIndex + 1}`;
    pip.position.set(x, -0.285, 0.01);
    pip.renderOrder = 70;
    marker.add(pip);
    return { pip, material };
  });

  const shards = Array.from({ length: 8 }, (_, shardIndex) => {
    const material = additiveMaterial(shardIndex % 2 ? 0x70d8ff : 0xc7f4ff, 0, false);
    const shard = new THREE.Mesh(new THREE.TetrahedronGeometry(0.055, 0), material);
    shard.name = 'SixComboFreezeContactShard';
    shard.renderOrder = 62;
    const angle = shardIndex / 8 * Math.PI * 2;
    const direction = new THREE.Vector3(Math.sin(angle), 0.2 + (shardIndex % 3) * 0.12, Math.cos(angle));
    root.add(shard);
    return { shard, material, direction };
  });

  const suspendedMotes = Array.from({ length: target.kind === 'boss' ? 10 : 7 }, (_, moteIndex) => {
    const material = additiveMaterial(moteIndex % 2 ? 0x79d8ff : 0xd2f7ff, 0, false);
    const mote = new THREE.Mesh(new THREE.TetrahedronGeometry(0.038 + (moteIndex % 3) * 0.008, 0), material);
    mote.name = 'SixComboEnemySuspendedTimeMote';
    mote.renderOrder = 61;
    root.add(mote);
    return {
      mote, material,
      angle: moteIndex / (target.kind === 'boss' ? 10 : 7) * Math.PI * 2,
      radius: radius * (0.76 + (moteIndex % 3) * 0.17),
      speed: 1.1 + (moteIndex % 4) * 0.2,
      height: -height * 0.25 + (moteIndex % 4) * height * 0.17,
    };
  });

  return {
    target, root, shell, shellMaterial, marker, markerFace, markerHand,
    markerMaterial, pips, shards, suspendedMotes, frozen: false, released: false,
    arrivalTime: 0, shellBaseScale: shell.scale.clone(),
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

export class TimeStopEffect {
  constructor(scene, camera) {
    this.scene = scene;
    this.camera = camera;
    this.root = new THREE.Group();
    this.root.name = 'ComboReward_TimeStopEffect';
    scene.add(this.root);
    this.effect = null;
    this.duration = 4.35;
  }

  play({ origin, targets }) {
    this.clear();
    const group = new THREE.Group();
    group.name = 'SixComboBoardWideTimeStop';
    this.root.add(group);

    const maxRadius = 5.45;
    const clock = createClockSigil(origin);
    const field = createTemporalField(origin, maxRadius);
    group.add(clock.root, field.root);

    const stasisTargets = targets.map((target, index) => {
      const stasis = createStasisTarget(target, index);
      const distance = target.entry.mount.position.clone().sub(origin).setY(0).length();
      stasis.arrivalTime = 0.14 + clamp01(distance / maxRadius) * 0.62;
      group.add(stasis.root);
      target.entry.frozen = false;
      return stasis;
    });

    this.effect = {
      group, clock, field, stasisTargets,
      elapsed: 0, origin: origin.clone(), maxRadius,
    };
  }

  freezeTarget(stasis) {
    stasis.frozen = true;
    stasis.target.entry.frozen = true;
    stasis.shell.visible = true;
    stasis.marker.visible = true;
    stasis.shards.forEach(({ shard }) => shard.visible = true);
  }

  releaseTarget(stasis) {
    if (stasis.released) return;
    stasis.released = true;
    stasis.target.entry.frozen = false;
  }

  update(delta) {
    const effect = this.effect;
    if (!effect) return;
    effect.elapsed += Math.max(0, delta);
    const elapsed = effect.elapsed;

    const clockIn = easeOutCubic(elapsed / 0.24);
    const clockOut = 1 - easeInOutCubic((elapsed - 3.55) / 0.68);
    const clockOpacity = clockIn * clockOut;
    effect.clock.faceMaterial.opacity = clockOpacity * 0.23;
    effect.clock.rimMaterial.opacity = clockOpacity * 0.8;
    effect.clock.tickMaterial.opacity = clockOpacity * 0.88;
    effect.clock.handMaterial.opacity = clockOpacity;
    effect.clock.root.scale.setScalar(0.6 + clockIn * 0.4);
    const clockSample = elapsed < 0.82 ? elapsed
      : elapsed < 3.82 ? 0.82 : 0.82 + (elapsed - 3.82) * 1.8;
    const snappedTime = Math.floor(clockSample * 8) / 8;
    effect.clock.minuteHand.rotation.y = -snappedTime * Math.PI * 1.75;
    effect.clock.hourHand.rotation.y = snappedTime * Math.PI * 0.35;

    const expansion = easeOutCubic((elapsed - 0.08) / 0.72);
    const fieldScale = Math.max(0.001, expansion * effect.maxRadius);
    effect.field.veil.scale.set(fieldScale, fieldScale, 1);
    effect.field.frontGlow.scale.setScalar(fieldScale);
    effect.field.frontCore.scale.setScalar(fieldScale);
    effect.field.veilMaterial.opacity = expansion * (elapsed < 3.55 ? 0.12 : 0.12 * clamp01((4.16 - elapsed) / 0.61));
    const frontEnvelope = Math.sin(clamp01((elapsed - 0.08) / 0.76) * Math.PI);
    effect.field.frontGlowMaterial.opacity = frontEnvelope * 0.34;
    effect.field.frontCoreMaterial.opacity = frontEnvelope * 0.78;

    const fieldHold = easeOutCubic((elapsed - 0.45) / 0.38);
    const fieldRelease = easeInOutCubic((elapsed - 3.48) / 0.64);
    const turnPulseTimes = [1.48, 2.48];
    const perimeterPulse = turnPulseTimes.reduce((strongest, pulseTime) => {
      const local = (elapsed - pulseTime) / 0.54;
      const envelope = local > 0 && local < 1 ? Math.sin(local * Math.PI) : 0;
      return Math.max(strongest, envelope);
    }, 0);
    effect.field.perimeterRomanNumerals.forEach(({ marker, material }, index) => {
      const arrival = easeOutCubic((elapsed - 0.42 - index * 0.018) / 0.26);
      material.opacity = fieldHold * arrival * (1 - fieldRelease) * (0.22 + perimeterPulse * 0.74);
      marker.scale.setScalar(1 + perimeterPulse * 0.16);
    });
    effect.field.ambientMotes.forEach(({ mote, material, angle, radius, speed, baseY }, moteIndex) => {
      const motionSample = elapsed < 0.82 ? elapsed
        : elapsed < 3.82 ? 0.82 : 0.82 + (elapsed - 3.82) * 1.6;
      const moteAngle = angle + motionSample * speed;
      mote.position.set(
        Math.sin(moteAngle) * radius,
        baseY + Math.sin(motionSample * 2.2 + moteIndex) * 0.035,
        Math.cos(moteAngle) * radius
      );
      mote.rotation.set(moteAngle * 0.7, moteAngle, moteAngle * 0.45);
      material.opacity = expansion * (1 - fieldRelease) * 0.62;
    });

    turnPulseTimes.forEach((pulseTime, index) => {
      const local = (elapsed - pulseTime) / 0.54;
      const envelope = local > 0 && local < 1 ? Math.sin(local * Math.PI) : 0;
      const pulseScale = effect.maxRadius * (0.92 + easeOutCubic(local) * 0.12);
      effect.field.turnPulses[index].pulse.scale.setScalar(pulseScale);
      effect.field.turnPulses[index].material.opacity = envelope * 0.34;
    });

    effect.stasisTargets.forEach((stasis, targetIndex) => {
      const moteMotionSample = elapsed < stasis.arrivalTime
        ? elapsed
        : elapsed < 3.82 ? stasis.arrivalTime : stasis.arrivalTime + (elapsed - 3.82) * 1.8;
      stasis.suspendedMotes.forEach(({ mote, material, angle, radius, speed, height }, moteIndex) => {
        const moteAngle = angle + moteMotionSample * speed;
        mote.position.set(
          Math.sin(moteAngle) * radius,
          height + Math.sin(moteMotionSample * 3 + moteIndex) * 0.045,
          Math.cos(moteAngle) * radius * 0.78
        );
        mote.rotation.set(moteAngle, moteAngle * 0.62, moteAngle * 0.4);
        material.opacity = elapsed < stasis.arrivalTime
          ? clamp01(elapsed / 0.18) * 0.52
          : (1 - easeInOutCubic((elapsed - 3.48) / 0.64)) * 0.86;
      });
      if (!stasis.frozen && elapsed >= stasis.arrivalTime) this.freezeTarget(stasis);
      if (!stasis.frozen) return;

      const local = Math.max(0, elapsed - stasis.arrivalTime);
      const formation = easeOutCubic(local / 0.22);
      const release = easeInOutCubic((elapsed - 3.48) / 0.64);
      const turnPulseOne = Math.max(0, 1 - Math.abs(elapsed - 1.54) / 0.34);
      const turnPulseTwo = Math.max(0, 1 - Math.abs(elapsed - 2.54) / 0.34);
      const pulse = Math.max(turnPulseOne, turnPulseTwo);
      stasis.shellMaterial.uniforms.uOpacity.value = formation * (1 - release) * (0.74 + pulse * 0.2);
      stasis.shellMaterial.uniforms.uPulse.value = moteMotionSample * 0.8;
      stasis.shell.scale.copy(stasis.shellBaseScale).multiplyScalar(1 + pulse * 0.08);

      stasis.marker.quaternion.copy(this.camera.quaternion);
      stasis.markerMaterial.opacity = formation * (1 - release) * 0.92;
      stasis.pips.forEach(({ pip, material }, pipIndex) => {
        const consumedAt = pipIndex === 0 ? 1.72 : 2.72;
        const consume = clamp01((elapsed - consumedAt) / 0.18);
        pip.scale.setScalar(1 - consume * 0.8);
        material.opacity = formation * (1 - consume) * (1 - release);
      });

      stasis.shards.forEach(({ shard, material, direction }, shardIndex) => {
        const capturedProgress = clamp01(local / 0.16);
        const capturedTime = Math.min(local, 0.16);
        const scatter = release * 0.44;
        shard.position.copy(direction).multiplyScalar(
          easeOutCubic(capturedProgress) * (0.42 + targetIndex * 0.02) + scatter
        );
        shard.rotation.x = capturedTime * (4 + shardIndex * 0.14) + release * 1.2;
        shard.rotation.z = capturedTime * (3.2 + shardIndex * 0.12) + release * 0.9;
        material.opacity = formation * (1 - release) * 0.62;
      });

      if (elapsed >= 3.82) this.releaseTarget(stasis);
      if (release >= 1) {
        stasis.shell.visible = false;
        stasis.marker.visible = false;
      }
    });
  }

  clear() {
    if (!this.effect) return;
    this.effect.stasisTargets.forEach(stasis => {
      stasis.target.entry.frozen = false;
    });
    this.root.remove(this.effect.group);
    disposeObject(this.effect.group);
    this.effect = null;
  }
}
