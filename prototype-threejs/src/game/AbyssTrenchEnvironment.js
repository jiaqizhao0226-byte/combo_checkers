import * as THREE from '../../vendor/three.module.js';
import { RAMPS, toon, markMesh } from './materials.js';

export const ABYSS_CLEARING_RADIUS = 6.05;
const TAU = Math.PI * 2;

function add(group, geometry, material, position, scale = [1, 1, 1], name = '') {
  const mesh = markMesh(new THREE.Mesh(geometry, material));
  mesh.position.set(...position);
  mesh.scale.set(...scale);
  if (name) mesh.name = name;
  group.add(mesh);
  return mesh;
}

function seeded(index) {
  const value = Math.sin(index * 83.19 + 41.73) * 43758.5453;
  return value - Math.floor(value);
}

function ringPoint(index, minRadius, maxRadius) {
  const angle = seeded(index * 3 + 1) * TAU;
  const radius = minRadius + Math.sqrt(seeded(index * 3 + 2)) * (maxRadius - minRadius);
  return [Math.cos(angle) * radius, Math.sin(angle) * radius, angle, radius];
}

function createSeabed(material) {
  const geometry = new THREE.PlaneGeometry(32, 34, 28, 30);
  geometry.rotateX(-Math.PI / 2);
  const positions = geometry.getAttribute('position');

  for (let index = 0; index < positions.count; index += 1) {
    const x = positions.getX(index);
    const z = positions.getZ(index);
    const radius = Math.hypot(x, z);
    const outer = THREE.MathUtils.smoothstep(radius, ABYSS_CLEARING_RADIUS - 0.2, 13.5);
    const broadShelf = Math.sin(x * 0.34) * 0.075 + Math.cos(z * 0.29) * 0.065;
    const fracturedFloor = Math.sin((x + z) * 0.78) * 0.05 + Math.cos((x - z) * 0.61) * 0.04;
    positions.setY(index, -0.12 + (broadShelf + fracturedFloor) * outer);
  }
  geometry.computeVertexNormals();
  const seabed = markMesh(new THREE.Mesh(geometry, material));
  seabed.name = 'AbyssSeabed';
  seabed.receiveShadow = true;
  return seabed;
}

function markBoundaryObject(object, clearanceRadius = 0.4) {
  object.userData.abyssBoundaryObject = true;
  object.userData.clearanceRadius = clearanceRadius;
  return object;
}

function createRockSpire(rock, rockLight, index) {
  const group = new THREE.Group();
  const height = 0.9 + seeded(index + 20) * 1.15;
  const base = add(group, new THREE.DodecahedronGeometry(0.58, 0), rock,
    [0, height * 0.22, 0], [1.05, height * 0.58, 0.82], `AbyssRidgeBase_${index}`);
  base.rotation.set(0.12, seeded(index + 40) * TAU, (seeded(index + 60) - 0.5) * 0.18);
  const crown = add(group, new THREE.DodecahedronGeometry(0.42, 0), rockLight,
    [0.12, height * 0.72, -0.04], [0.7, height * 0.62, 0.64], `AbyssRidgeCrown_${index}`);
  crown.rotation.set(-0.08, seeded(index + 80) * TAU, (seeded(index + 100) - 0.5) * 0.22);
  if (index % 3 === 0) {
    const shard = add(group, new THREE.ConeGeometry(0.18, 0.7, 6), rockLight,
      [-0.28, 0.48, 0.09], [0.85, 1, 0.76], `AbyssRidgeShard_${index}`);
    shard.rotation.z = -0.22;
  }
  return markBoundaryObject(group, 0.82);
}

function createBranchCoral(primary, secondary, glowMaterial, index) {
  const group = new THREE.Group();
  const branchMaterial = index % 2 ? primary : secondary;
  const branchCount = 4 + (index % 2);
  for (let branch = 0; branch < branchCount; branch += 1) {
    const angle = -0.76 + branch / Math.max(1, branchCount - 1) * 1.52;
    const height = 0.48 + seeded(index * 11 + branch) * 0.42;
    const stem = add(group, new THREE.CylinderGeometry(0.045, 0.075, height, 7), branchMaterial,
      [(branch - (branchCount - 1) * 0.5) * 0.1, height * 0.44, 0],
      [1, 1, 0.86], `AbyssCoralBranch_${index}_${branch}`);
    stem.rotation.z = angle * 0.48;
    const tipX = stem.position.x - Math.sin(stem.rotation.z) * height * 0.48;
    const tipY = stem.position.y + Math.cos(stem.rotation.z) * height * 0.48;
    const tip = add(group, new THREE.IcosahedronGeometry(0.095, 1), glowMaterial,
      [tipX, tipY, 0], [1, 0.82, 1], `AbyssCoralTip_${index}_${branch}`);
    tip.castShadow = false;
    tip.receiveShadow = false;
  }
  add(group, new THREE.DodecahedronGeometry(0.28, 0), secondary,
    [0, 0.12, 0], [1.25, 0.5, 0.9], `AbyssCoralRoot_${index}`);
  return markBoundaryObject(group, 0.68);
}

function createKelpCluster(kelpA, kelpB, index) {
  const group = new THREE.Group();
  const bladeCount = 3 + (index % 2);
  for (let blade = 0; blade < bladeCount; blade += 1) {
    const height = 0.62 + seeded(index * 9 + blade) * 0.72;
    const mesh = add(group, new THREE.CapsuleGeometry(0.045, height, 4, 7),
      blade % 2 ? kelpA : kelpB,
      [(blade - (bladeCount - 1) * 0.5) * 0.13, height * 0.5 - 0.02, (blade % 2 - 0.5) * 0.08],
      [0.72, 1, 0.48], `AbyssKelpBlade_${index}_${blade}`);
    mesh.rotation.z = (blade - (bladeCount - 1) * 0.5) * 0.11;
  }
  group.userData.baseRotationZ = (seeded(index + 160) - 0.5) * 0.04;
  group.userData.phase = seeded(index + 180) * TAU;
  group.userData.frequency = 0.42 + seeded(index + 200) * 0.18;
  return markBoundaryObject(group, 0.46);
}

function createAnemone(baseMaterial, tentacleA, tentacleB, index) {
  const group = new THREE.Group();
  add(group, new THREE.SphereGeometry(0.25, 12, 7), baseMaterial,
    [0, 0.12, 0], [1.2, 0.52, 1], `AbyssAnemoneBase_${index}`);
  for (let tentacle = 0; tentacle < 7; tentacle += 1) {
    const angle = tentacle / 7 * TAU;
    const height = 0.32 + seeded(index * 13 + tentacle) * 0.22;
    const mesh = add(group, new THREE.ConeGeometry(0.04, height, 6),
      tentacle % 2 ? tentacleA : tentacleB,
      [Math.cos(angle) * 0.16, 0.22 + height * 0.42, Math.sin(angle) * 0.16],
      [1, 1, 0.88], `AbyssAnemoneTentacle_${index}_${tentacle}`);
    mesh.rotation.z = Math.cos(angle) * 0.18;
    mesh.rotation.x = -Math.sin(angle) * 0.18;
  }
  return markBoundaryObject(group, 0.44);
}

function createThermalVent(rock, vent, glowMaterial, index) {
  const group = new THREE.Group();
  add(group, new THREE.DodecahedronGeometry(0.46, 0), rock,
    [0, 0.18, 0], [1.25, 0.58, 1], `AbyssVentBase_${index}`);
  [-0.18, 0, 0.18].forEach((x, pipeIndex) => {
    const height = 0.44 + pipeIndex * 0.13 + seeded(index + pipeIndex * 21) * 0.12;
    add(group, new THREE.CylinderGeometry(0.07, 0.12, height, 7), vent,
      [x, 0.2 + height * 0.5, (pipeIndex - 1) * 0.06],
      [1, 1, 0.9], `AbyssVentPipe_${index}_${pipeIndex}`);
    const rim = add(group, new THREE.TorusGeometry(0.073, 0.018, 6, 12), glowMaterial,
      [x, 0.21 + height, (pipeIndex - 1) * 0.06], [1, 1, 1],
      `AbyssVentGlow_${index}_${pipeIndex}`);
    rim.rotation.x = Math.PI * 0.5;
    rim.castShadow = false;
    rim.receiveShadow = false;
  });
  return markBoundaryObject(group, 0.62);
}

function createRuinArch(stone, darkStone) {
  const group = new THREE.Group();
  [-0.58, 0.58].forEach((x, index) => {
    const column = add(group, new THREE.CylinderGeometry(0.14, 0.2, 1.45, 8), stone,
      [x, 0.7, 0], [1, 1, 0.82], `AbyssRuinColumn_${index}`);
    column.rotation.z = index ? 0.08 : -0.05;
    add(group, new THREE.CylinderGeometry(0.23, 0.23, 0.12, 8), darkStone,
      [x, 0.08, 0], [1, 1, 0.84], `AbyssRuinFoot_${index}`);
  });
  const lintel = add(group, new THREE.BoxGeometry(1.55, 0.22, 0.34), stone,
    [0.05, 1.42, 0], [1, 1, 0.86], 'AbyssRuinLintel');
  lintel.rotation.z = -0.11;
  add(group, new THREE.DodecahedronGeometry(0.28, 0), darkStone,
    [0.9, 0.18, 0.08], [1.25, 0.7, 0.9], 'AbyssRuinFragment');
  return markBoundaryObject(group, 1.05);
}

function createShipwreckRemains(wood, metal) {
  const group = new THREE.Group();
  const keel = add(group, new THREE.BoxGeometry(2.15, 0.18, 0.26), wood,
    [0, 0.2, 0], [1, 1, 1], 'AbyssWreckKeel');
  keel.rotation.y = -0.18;
  for (let rib = -2; rib <= 2; rib += 1) {
    const ribMesh = add(group, new THREE.TorusGeometry(0.52, 0.055, 7, 14, Math.PI), wood,
      [rib * 0.38, 0.24, 0], [1, 1.18, 0.82], `AbyssWreckRib_${rib + 2}`);
    ribMesh.rotation.set(Math.PI * 0.5, 0, Math.PI * 0.5);
  }
  const band = add(group, new THREE.BoxGeometry(0.11, 0.7, 0.11), metal,
    [0.5, 0.45, 0], [1, 1, 1], 'AbyssWreckIronBand');
  band.rotation.z = -0.38;
  return markBoundaryObject(group, 1.25);
}

function createBubbleField(material) {
  const plumeOrigins = [
    [-5.15, 4.55],
    [5.2, 4.35],
    [0.95, 6.58],
    [-6.45, 1.85],
  ];
  const count = 28;
  const geometry = new THREE.SphereGeometry(1, 8, 6);
  const field = new THREE.InstancedMesh(geometry, material, count);
  field.name = 'AbyssBubbleField';
  field.castShadow = false;
  field.receiveShadow = false;
  field.frustumCulled = false;
  field.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
  field.userData.bubbles = Array.from({ length: count }, (_, index) => {
    const plume = plumeOrigins[index % plumeOrigins.length];
    return {
      originX: plume[0] + (seeded(index + 690) - 0.5) * 0.42,
      originZ: plume[1] + (seeded(index + 710) - 0.5) * 0.34,
      radius: 0.045 + seeded(index + 730) * 0.052,
      phase: seeded(index + 750),
      speed: 0.085 + seeded(index + 770) * 0.055,
      travel: 2.25 + seeded(index + 790) * 1.15,
      sway: 0.07 + seeded(index + 810) * 0.08,
    };
  });
  return field;
}

function updateBubbleField(field, time) {
  const dummy = new THREE.Object3D();
  field.userData.bubbles.forEach((bubble, index) => {
    const progress = (bubble.phase + time * bubble.speed) % 1;
    const drift = Math.sin(progress * TAU * 1.35 + index) * bubble.sway;
    dummy.position.set(
      bubble.originX + drift,
      0.24 + progress * bubble.travel,
      bubble.originZ + Math.cos(progress * TAU + index * 0.7) * bubble.sway * 0.62
    );
    dummy.scale.setScalar(bubble.radius);
    dummy.updateMatrix();
    field.setMatrixAt(index, dummy.matrix);
  });
  field.instanceMatrix.needsUpdate = true;
}

function createCausticField(materials) {
  const group = new THREE.Group();
  group.name = 'AbyssCausticField';
  for (let index = 0; index < 8; index += 1) {
    const [x, z] = ringPoint(index + 840, 6.5, 11.2);
    const radius = 0.42 + seeded(index + 860) * 0.48;
    const arc = new THREE.Mesh(
      new THREE.TorusGeometry(radius, 0.024 + seeded(index + 880) * 0.018, 5, 24, 3.7 + seeded(index + 900) * 1.55),
      materials[index % materials.length]
    );
    arc.name = `AbyssCausticArc_${index}`;
    arc.position.set(x, 0.015, z);
    arc.rotation.set(Math.PI * 0.5, 0, seeded(index + 920) * TAU);
    arc.scale.set(1.25 + seeded(index + 940) * 0.65, 0.62 + seeded(index + 960) * 0.28, 1);
    arc.castShadow = false;
    arc.receiveShadow = false;
    arc.renderOrder = 2;
    arc.userData.baseRotationZ = arc.rotation.z;
    arc.userData.phase = seeded(index + 980) * TAU;
    group.add(arc);
  }
  return group;
}

function createLightShafts(material) {
  const group = new THREE.Group();
  group.name = 'AbyssLightShafts';
  const placements = [
    [-6.8, -5.4, -0.11],
    [0.2, -8.4, 0.08],
    [6.6, -5.1, 0.14],
  ];
  placements.forEach(([x, z, tilt], index) => {
    const shaft = new THREE.Mesh(
      new THREE.CylinderGeometry(0.34, 1.25 + index * 0.18, 7.6, 10, 1, true),
      material
    );
    shaft.name = `AbyssLightShaft_${index}`;
    shaft.position.set(x, 3.35, z);
    shaft.rotation.z = tilt;
    shaft.castShadow = false;
    shaft.receiveShadow = false;
    shaft.renderOrder = 1;
    group.add(shaft);
  });
  return group;
}

function createMarineSnow() {
  const count = 44;
  const positions = new Float32Array(count * 3);
  for (let index = 0; index < count; index += 1) {
    const [x, z] = ringPoint(index + 1020, 6.3, 13.2);
    positions[index * 3] = x;
    positions[index * 3 + 1] = 0.42 + seeded(index + 1040) * 3.6;
    positions[index * 3 + 2] = z;
  }
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
  const snow = new THREE.Points(geometry, new THREE.PointsMaterial({
    color: 0xb7eff2,
    size: 0.055,
    sizeAttenuation: true,
    transparent: true,
    opacity: 0.34,
    depthWrite: false,
    toneMapped: false,
  }));
  snow.name = 'AbyssMarineSnow';
  snow.frustumCulled = false;
  return snow;
}

export function createAbyssTrenchEnvironment(scene) {
  const group = new THREE.Group();
  group.name = 'AbyssTrenchEnvironment';
  group.userData.theme = 'abyss_trench';
  scene.add(group);

  const seabed = toon(0x1a5368, RAMPS.stone, 0x082d3d, 0.12);
  const sediment = toon(0x2b6a79, RAMPS.stone, 0x0b3542, 0.08);
  const sedimentDark = toon(0x16475b, RAMPS.stone, 0x082735, 0.08);
  const rock = toon(0x36717d, RAMPS.stone, 0x0c3440, 0.07);
  const rockLight = toon(0x4d8990, RAMPS.stone, 0x123f48, 0.08);
  const coralCyan = toon(0x50c6b9, RAMPS.soft, 0x176b6c, 0.18);
  const coralPurple = toon(0x9680bd, RAMPS.soft, 0x41316b, 0.14);
  const coralWarm = toon(0xd68487, RAMPS.soft, 0x713c4a, 0.13);
  const kelpA = toon(0x319384, RAMPS.soft, 0x0d3f3b, 0.05);
  const kelpB = toon(0x4aae8f, RAMPS.soft, 0x164c3f, 0.05);
  const ruinStone = toon(0x78969a, RAMPS.stone, 0x243f46, 0.06);
  const ruinDark = toon(0x536f78, RAMPS.stone, 0x1b3540, 0.06);
  const wreckWood = toon(0x80685b, RAMPS.soft, 0x33241f, 0.04);
  const wreckMetal = toon(0x7e9ba0, RAMPS.metal, 0x243c42, 0.06);
  const vent = toon(0x506f76, RAMPS.stone, 0x17383f, 0.06);
  const bioGlow = new THREE.MeshBasicMaterial({
    color: new THREE.Color(0x68e1d2).multiplyScalar(1.2),
    toneMapped: false,
  });
  const bubbleMaterial = new THREE.MeshBasicMaterial({
    color: 0xc2f4f7,
    transparent: true,
    opacity: 0.58,
    depthWrite: false,
    toneMapped: false,
  });
  const causticMaterials = [0.15, 0.095].map(opacity => new THREE.MeshBasicMaterial({
    color: 0x8ce5dc,
    transparent: true,
    opacity,
    depthWrite: false,
    blending: THREE.AdditiveBlending,
    toneMapped: false,
  }));
  const shaftMaterial = new THREE.MeshBasicMaterial({
    color: 0x6ccbd2,
    transparent: true,
    opacity: 0.068,
    depthWrite: false,
    side: THREE.DoubleSide,
    blending: THREE.AdditiveBlending,
    toneMapped: false,
  });

  group.add(createSeabed(seabed));

  for (let index = 0; index < 18; index += 1) {
    const patchRadius = 0.72 + seeded(index + 240) * 1.25;
    const [x, z] = ringPoint(index + 260, ABYSS_CLEARING_RADIUS + patchRadius * 1.08, 14.2);
    const patch = add(group, new THREE.CylinderGeometry(patchRadius, patchRadius, 0.022, 11),
      index % 3 ? sediment : sedimentDark, [x, -0.084, z],
      [1, 1, 0.55 + seeded(index + 280) * 0.5], `AbyssSedimentPatch_${index}`);
    patch.rotation.y = seeded(index + 300) * TAU;
    patch.receiveShadow = true;
  }

  const foregroundRidges = [[-5.55, 3.55], [5.55, 3.65], [0, 6.7]];
  for (let index = 0; index < 14; index += 1) {
    const [randomX, randomZ] = ringPoint(index + 330, 6.75, 13.5);
    const [x, z] = foregroundRidges[index] || [randomX, randomZ];
    const ridge = createRockSpire(index % 2 ? rock : rockLight, index % 2 ? rockLight : rock, index);
    ridge.position.set(x, -0.05, z);
    const scale = 0.72 + seeded(index + 350) * 0.5;
    ridge.scale.setScalar(scale);
    ridge.userData.clearanceRadius *= scale;
    ridge.rotation.y = seeded(index + 370) * TAU;
    ridge.name = `AbyssRidge_${index}`;
    group.add(ridge);
  }

  const foregroundCorals = [[-4.85, 4.25], [4.85, 4.25], [-2.15, 6.15]];
  for (let index = 0; index < 10; index += 1) {
    const [randomX, randomZ] = ringPoint(index + 400, 6.55, 12.7);
    const [x, z] = foregroundCorals[index] || [randomX, randomZ];
    const coral = createBranchCoral(coralCyan, index % 3 ? coralPurple : coralWarm, bioGlow, index);
    coral.position.set(x, -0.04, z);
    const scale = 0.72 + seeded(index + 420) * 0.42;
    coral.scale.setScalar(scale);
    coral.userData.clearanceRadius *= scale;
    coral.rotation.y = seeded(index + 440) * TAU;
    coral.name = `AbyssCoral_${index}`;
    group.add(coral);
  }

  const kelpClusters = [];
  const foregroundKelp = [
    [-3.2, 5.6], [3.2, 5.6], [-5.55, 3.25], [5.55, 3.25],
  ];
  for (let index = 0; index < 14; index += 1) {
    const [randomX, randomZ] = ringPoint(index + 470, 6.45, 13.3);
    const [x, z] = foregroundKelp[index] || [randomX, randomZ];
    const kelp = createKelpCluster(kelpA, kelpB, index);
    kelp.position.set(x, -0.06, z);
    const scale = 0.7 + seeded(index + 490) * 0.48;
    kelp.scale.setScalar(scale);
    kelp.userData.clearanceRadius *= scale;
    kelp.rotation.y = seeded(index + 510) * TAU;
    kelp.name = `AbyssKelp_${index}`;
    group.add(kelp);
    kelpClusters.push(kelp);
  }

  const foregroundAnemones = [[-4.55, 4.65], [4.55, 4.65]];
  for (let index = 0; index < 6; index += 1) {
    const [randomX, randomZ] = ringPoint(index + 540, 6.5, 11.8);
    const [x, z] = foregroundAnemones[index] || [randomX, randomZ];
    const anemone = createAnemone(rock, coralWarm, coralPurple, index);
    anemone.position.set(x, -0.04, z);
    const scale = 0.76 + seeded(index + 560) * 0.38;
    anemone.scale.setScalar(scale);
    anemone.userData.clearanceRadius *= scale;
    anemone.rotation.y = seeded(index + 580) * TAU;
    anemone.name = `AbyssAnemone_${index}`;
    group.add(anemone);
  }

  const foregroundVents = [[0.95, 6.55]];
  for (let index = 0; index < 4; index += 1) {
    const [randomX, randomZ] = ringPoint(index + 610, 7.1, 11.6);
    const [x, z] = foregroundVents[index] || [randomX, randomZ];
    const thermalVent = createThermalVent(rock, vent, bioGlow, index);
    thermalVent.position.set(x, -0.04, z);
    thermalVent.rotation.y = seeded(index + 630) * TAU;
    thermalVent.name = `AbyssVent_${index}`;
    group.add(thermalVent);
  }

  const ruin = createRuinArch(ruinStone, ruinDark);
  ruin.position.set(-5.9, -0.04, 4.35);
  ruin.scale.setScalar(0.82);
  ruin.userData.clearanceRadius *= 0.82;
  ruin.rotation.y = 0.42;
  ruin.name = 'AbyssRuinArch';
  group.add(ruin);

  const wreck = createShipwreckRemains(wreckWood, wreckMetal);
  wreck.position.set(6.05, -0.02, 4.45);
  wreck.scale.setScalar(0.78);
  wreck.userData.clearanceRadius *= 0.78;
  wreck.rotation.y = -0.58;
  wreck.name = 'AbyssShipwreck';
  group.add(wreck);

  const bubbleField = createBubbleField(bubbleMaterial);
  updateBubbleField(bubbleField, 0);
  group.add(bubbleField);

  const causticField = createCausticField(causticMaterials);
  group.add(causticField);

  const lightShafts = createLightShafts(shaftMaterial);
  group.add(lightShafts);

  const marineSnow = createMarineSnow();
  group.add(marineSnow);

  function update(time) {
    kelpClusters.forEach(kelp => {
      kelp.rotation.z = kelp.userData.baseRotationZ
        + Math.sin(time * kelp.userData.frequency + kelp.userData.phase) * 0.025;
    });
    updateBubbleField(bubbleField, time);
    causticField.children.forEach((arc, index) => {
      arc.rotation.z = arc.userData.baseRotationZ
        + Math.sin(time * 0.18 + arc.userData.phase) * 0.09;
    });
    causticMaterials[0].opacity = 0.135 + Math.sin(time * 0.34) * 0.02;
    causticMaterials[1].opacity = 0.085 + Math.sin(time * 0.29 + 1.7) * 0.016;
    lightShafts.rotation.y = Math.sin(time * 0.08) * 0.025;
    marineSnow.rotation.y = time * 0.006;
    marineSnow.position.y = Math.sin(time * 0.17) * 0.07;
  }

  return { group, update, theme: 'abyss_trench' };
}
