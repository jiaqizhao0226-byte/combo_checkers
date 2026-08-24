import * as THREE from '../../vendor/three.module.js';
import { RAMPS, toon, markMesh } from './materials.js';
import { createAbyssTrenchEnvironment } from './AbyssTrenchEnvironment.js';

const CLEARING_RADIUS = 6.05;
const TAU = Math.PI * 2;
// This foreground tree repeatedly produced unstable flashing at the lower-left
// edge on the WeChat WebGL preview. It is intentionally omitted; nearby shrubs,
// rocks and ground patches remain, so the natural border keeps its density.
const OMITTED_TREE_INDICES = new Set([14]);

function add(group, geometry, material, position, scale = [1, 1, 1]) {
  const mesh = markMesh(new THREE.Mesh(geometry, material));
  mesh.position.set(...position);
  mesh.scale.set(...scale);
  group.add(mesh);
  return mesh;
}

function seeded(index) {
  const value = Math.sin(index * 91.73 + 18.17) * 43758.5453;
  return value - Math.floor(value);
}

function ringPoint(index, minRadius, maxRadius) {
  const angle = seeded(index * 3 + 1) * TAU;
  const radius = minRadius + Math.sqrt(seeded(index * 3 + 2)) * (maxRadius - minRadius);
  return [Math.cos(angle) * radius, Math.sin(angle) * radius, angle];
}

function createTerrain(material) {
  const geometry = new THREE.PlaneGeometry(32, 34, 28, 30);
  geometry.rotateX(-Math.PI / 2);
  const positions = geometry.attributes.position;

  for (let index = 0; index < positions.count; index += 1) {
    const x = positions.getX(index);
    const z = positions.getZ(index);
    const radius = Math.hypot(x, z);
    const edge = THREE.MathUtils.smoothstep(radius, CLEARING_RADIUS, 13);
    const undulation = (
      Math.sin(x * 0.72) * 0.045
      + Math.cos(z * 0.58) * 0.035
      + Math.sin((x + z) * 0.37) * 0.028
    ) * edge;
    positions.setY(index, -0.105 + undulation);
  }
  geometry.computeVertexNormals();
  return markMesh(new THREE.Mesh(geometry, material));
}

function createTree(trunk, leafA, leafB, index) {
  const group = new THREE.Group();
  const trunkHeight = 1.25 + seeded(index + 20) * 0.55;
  const trunkMesh = add(group, new THREE.CylinderGeometry(0.13, 0.24, trunkHeight, 7), trunk, [0, trunkHeight * 0.5 - 0.04, 0]);
  trunkMesh.rotation.z = (seeded(index + 40) - 0.5) * 0.12;
  const crownY = trunkHeight * 0.78;
  const crowns = [
    add(group, new THREE.IcosahedronGeometry(0.56, 1), leafA, [-0.22, crownY + 0.3, 0], [1.05, 0.78, 0.9]),
    add(group, new THREE.IcosahedronGeometry(0.48, 1), leafB, [0.28, crownY + 0.35, -0.04], [1, 0.82, 0.9]),
    add(group, new THREE.IcosahedronGeometry(0.43, 1), leafA, [0.05, crownY + 0.73, 0.02], [0.92, 0.82, 0.86]),
  ];
  // Low-poly crowns intersect each other by design. Receiving a low-resolution
  // dynamic shadow on those intersections creates unstable dark facets while
  // the camera zooms. They still cast a unified tree shadow onto the terrain.
  crowns.forEach(crown => { crown.receiveShadow = false; crown.userData.foliage = true; });
  return group;
}

function createBush(leafA, leafB, index) {
  const group = new THREE.Group();
  const foliage = [
    add(group, new THREE.IcosahedronGeometry(0.32, 0), leafA, [-0.24, 0.24, 0], [1.15, 0.82, 0.95]),
    add(group, new THREE.IcosahedronGeometry(0.38, 0), leafB, [0.08, 0.3, 0.03], [1.05, 0.9, 1]),
    add(group, new THREE.IcosahedronGeometry(0.27, 0), leafA, [0.36, 0.22, -0.02], [1, 0.78, 0.9]),
  ];
  foliage.forEach(leaf => { leaf.receiveShadow = false; leaf.userData.foliage = true; });
  group.rotation.y = seeded(index + 90) * TAU;
  return group;
}

function createGrass(material, index) {
  const group = new THREE.Group();
  for (let blade = 0; blade < 5; blade += 1) {
    const height = 0.3 + seeded(index * 7 + blade) * 0.22;
    const mesh = add(group, new THREE.ConeGeometry(0.045, height, 4), material, [
      (blade - 2) * 0.07,
      height * 0.47,
      (seeded(index + blade * 9) - 0.5) * 0.15,
    ], [1, 1, 0.58]);
    mesh.rotation.z = (blade - 2) * 0.11;
  }
  return group;
}

function createMushrooms(stem, cap, index) {
  const group = new THREE.Group();
  for (let item = 0; item < 3; item += 1) {
    const height = 0.16 + seeded(index + item * 6) * 0.16;
    const x = (item - 1) * 0.17;
    const z = (seeded(index + item * 8) - 0.5) * 0.17;
    add(group, new THREE.CylinderGeometry(0.025, 0.035, height, 6), stem, [x, height * 0.5, z]);
    add(group, new THREE.IcosahedronGeometry(0.09, 0), cap, [x, height, z], [1, 0.55, 1]);
  }
  return group;
}

function createFallenLog(trunk, cut, moss) {
  const group = new THREE.Group();
  const log = add(group, new THREE.CylinderGeometry(0.18, 0.21, 1.5, 7), trunk, [0, 0.18, 0]);
  log.rotation.z = Math.PI / 2;
  const end = add(group, new THREE.CylinderGeometry(0.17, 0.17, 0.035, 7), cut, [0.765, 0.18, 0]);
  end.rotation.z = Math.PI / 2;
  add(group, new THREE.BoxGeometry(0.82, 0.045, 0.18), moss, [0, 0.39, 0], [1, 1, 0.72]);
  return group;
}

export function createForestEnvironment(scene) {
  const group = new THREE.Group();
  group.name = 'NaturalForestEnvironment';
  scene.add(group);

  const ground = toon(0x355f4b, RAMPS.stone);
  const groundLight = toon(0x477456, RAMPS.stone);
  const groundDark = toon(0x294b42, RAMPS.stone);
  const leafA = toon(0x3f7750, RAMPS.soft);
  const leafB = toon(0x285e48, RAMPS.soft);
  const grassA = toon(0x5d864d, RAMPS.soft);
  const grassB = toon(0x3e7249, RAMPS.soft);
  const trunk = toon(0x5b4030, RAMPS.soft);
  const cutWood = toon(0xb08355, RAMPS.soft);
  const rock = toon(0x65767a, RAMPS.stone);
  const rockDark = toon(0x40585d, RAMPS.stone);
  const stem = toon(0xe5d2a7, RAMPS.soft);
  const mushroom = toon(0xc85a4b, RAMPS.soft);
  const flower = new THREE.MeshBasicMaterial({ color: 0xf6c55d });
  const moteMaterial = new THREE.MeshBasicMaterial({
    color: new THREE.Color(0xd8f3bd).multiplyScalar(1.15),
    transparent: true,
    opacity: 0.72,
    toneMapped: false,
  });

  const terrain = createTerrain(ground);
  terrain.receiveShadow = true;
  group.add(terrain);
  const treeFootprints = [];

  for (let index = 0; index < 24; index += 1) {
    const patchRadius = 0.65 + seeded(index + 150) * 1.45;
    const [x, z] = ringPoint(index + 170, CLEARING_RADIUS + patchRadius * 1.12, 14);
    const patch = add(group, new THREE.CylinderGeometry(patchRadius, patchRadius, 0.018, 12), index % 3 === 0 ? groundDark : groundLight, [x, -0.075, z], [
      1,
      1,
      0.68 + seeded(index + 190) * 0.55,
    ]);
    patch.rotation.y = seeded(index + 210) * TAU;
    patch.receiveShadow = true;
  }

  // 高树只在镜头远侧与两翼生成，构成森林背景但不遮挡棋盘。
  for (let index = 0; index < 15; index += 1) {
    if (OMITTED_TREE_INDICES.has(index)) continue;
    const angle = 2.15 + seeded(index + 240) * 3.55;
    const radius = 6.7 + Math.sqrt(seeded(index + 260)) * 5.8;
    const tree = createTree(trunk, index % 3 ? leafA : leafB, index % 3 ? leafB : leafA, index);
    tree.position.set(Math.cos(angle) * radius, -0.02, Math.sin(angle) * radius);
    const treeScale = 0.72 + seeded(index + 280) * 0.5;
    tree.scale.setScalar(treeScale);
    tree.rotation.y = seeded(index + 300) * TAU;
    tree.name = `ForestTree_${index}`;
    tree.userData.glowClearance = 1.15 * treeScale;
    treeFootprints.push({ x: tree.position.x, z: tree.position.z, radius: tree.userData.glowClearance });
    group.add(tree);
  }

  for (let index = 0; index < 20; index += 1) {
    const [x, z] = ringPoint(index + 330, 6.35, 13.2);
    const shrub = createBush(index % 2 ? leafA : leafB, index % 2 ? leafB : leafA, index);
    shrub.position.set(x, -0.02, z);
    shrub.scale.setScalar(0.7 + seeded(index + 350) * 0.62);
    group.add(shrub);
  }

  for (let index = 0; index < 28; index += 1) {
    const [x, z] = ringPoint(index + 380, 6.25, 14);
    const scale = 0.22 + seeded(index + 400) * 0.55;
    const stone = add(group, new THREE.IcosahedronGeometry(0.72, 0), index % 3 ? rock : rockDark, [x, scale * 0.36 - 0.05, z], [
      scale * (1.1 + seeded(index + 420) * 0.5),
      scale * 0.72,
      scale,
    ]);
    stone.rotation.set(seeded(index + 440), seeded(index + 460) * TAU, seeded(index + 480) * 0.4);
  }

  for (let index = 0; index < 46; index += 1) {
    const [x, z] = ringPoint(index + 510, 6.2, 14.5);
    const tuft = createGrass(index % 3 ? grassA : grassB, index);
    tuft.position.set(x, -0.03, z);
    tuft.rotation.y = seeded(index + 530) * TAU;
    tuft.scale.setScalar(0.72 + seeded(index + 550) * 0.55);
    group.add(tuft);
  }

  for (let index = 0; index < 12; index += 1) {
    const [x, z] = ringPoint(index + 580, 6.35, 12.5);
    const cluster = createMushrooms(stem, mushroom, index);
    cluster.position.set(x, -0.03, z);
    cluster.rotation.y = seeded(index + 600) * TAU;
    cluster.scale.setScalar(0.8 + seeded(index + 620) * 0.6);
    group.add(cluster);
  }

  for (let index = 0; index < 5; index += 1) {
    const [x, z, angle] = ringPoint(index + 650, 7, 11.5);
    const log = createFallenLog(trunk, cutWood, grassB);
    log.position.set(x, -0.03, z);
    log.rotation.y = angle + seeded(index + 670) * 1.4;
    log.scale.setScalar(0.72 + seeded(index + 690) * 0.35);
    group.add(log);
  }

  for (let index = 0; index < 18; index += 1) {
    const [x, z] = ringPoint(index + 720, 6.25, 12.8);
    const stalkHeight = 0.18 + seeded(index + 740) * 0.14;
    add(group, new THREE.CylinderGeometry(0.018, 0.025, stalkHeight, 5), grassA, [x, stalkHeight * 0.5 - 0.03, z]);
    const blossom = add(group, new THREE.BoxGeometry(0.11, 0.055, 0.11), flower, [x, stalkHeight - 0.015, z]);
    blossom.rotation.y = seeded(index + 760) * TAU;
  }

  const motes = [];
  for (let index = 0; index < 22; index += 1) {
    let x = 0;
    let z = 0;
    // Bright motes pulsing inside a low-poly crown read as the whole tree
    // flickering. Keep the atmospheric lights, but deterministically resample
    // their positions until they clear every tree canopy.
    for (let attempt = 0; attempt < 18; attempt += 1) {
      [x, z] = ringPoint(index + 790 + attempt * 37, 5.9, 12.5);
      const clearsTrees = treeFootprints.every(tree => (
        Math.hypot(x - tree.x, z - tree.z) > tree.radius + 0.72
      ));
      if (clearsTrees) break;
    }
    const mote = add(group, new THREE.BoxGeometry(0.05, 0.05, 0.05), moteMaterial, [x, 0.65 + seeded(index + 810) * 1.7, z]);
    mote.name = `ForestMote_${index}`;
    mote.castShadow = false;
    mote.receiveShadow = false;
    mote.userData.baseY = mote.position.y;
    mote.userData.phase = seeded(index + 830) * TAU;
    mote.userData.baseScale = 0.72 + seeded(index + 850) * 0.16;
    mote.scale.setScalar(mote.userData.baseScale);
    motes.push(mote);
  }

  function update(time) {
    motes.forEach((mote, index) => {
      mote.position.y = mote.userData.baseY
        + Math.sin(time * (0.8 + (index % 4) * 0.11) + mote.userData.phase) * 0.08;
      // Keep brightness and size stable. The old quantised scale pulse jumped
      // between five discrete sizes and could read as nearby foliage flashing.
      mote.scale.setScalar(mote.userData.baseScale);
    });
  }

  return { group, update };
}

export function createEnvironment(scene, options = {}) {
  const theme = typeof options === 'string' ? options : options.theme || 'forest';
  if (theme === 'abyss_trench') return createAbyssTrenchEnvironment(scene);
  const forest = createForestEnvironment(scene);
  forest.theme = 'forest';
  forest.group.userData.theme = 'forest';
  return forest;
}
