import * as THREE from '../vendor/three.module.js';

function add(group, geometry, material, position, scale = [1, 1, 1], name = '') {
  const mesh = new THREE.Mesh(geometry, material);
  mesh.position.set(...position);
  mesh.scale.set(...scale);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  if (name) mesh.name = name;
  group.add(mesh);
  return mesh;
}

function smoothLathe(profile, segments = 48) {
  const points = profile.map(([radius, y]) => new THREE.Vector2(radius, y));
  const geometry = new THREE.LatheGeometry(points, segments);
  geometry.computeVertexNormals();
  return geometry;
}

function bendIntegratedCrown(geometry) {
  const positions = geometry.getAttribute('position');
  for (let index = 0; index < positions.count; index += 1) {
    const y = positions.getY(index);
    const crownBlend = THREE.MathUtils.smoothstep(y, 0.86, 1.14);
    positions.setX(index, positions.getX(index) + crownBlend * 0.055);
  }
  positions.needsUpdate = true;
  geometry.computeVertexNormals();
  geometry.computeBoundingSphere();
  return geometry;
}

function makeHealthBar(color) {
  const group = new THREE.Group();
  const track = new THREE.Mesh(
    new THREE.BoxGeometry(0.85, 0.05, 0.12),
    new THREE.MeshBasicMaterial({ color: 0x071018 })
  );
  const fill = new THREE.Mesh(
    new THREE.BoxGeometry(0.68, 0.06, 0.13),
    new THREE.MeshBasicMaterial({ color })
  );
  fill.position.y = 0.015;
  group.add(track, fill);
  group.position.set(0, 0.08, 0.5);
  return group;
}

function makeContactShadow() {
  const material = new THREE.MeshBasicMaterial({
    color: 0x07110f,
    transparent: true,
    opacity: 0.25,
    depthWrite: false,
    toneMapped: false,
  });
  const geometry = new THREE.CircleGeometry(0.5, 40);
  geometry.rotateX(-Math.PI / 2);
  const shadow = new THREE.Mesh(geometry, material);
  shadow.position.y = 0.012;
  shadow.scale.set(0.92, 1, 0.68);
  shadow.renderOrder = 1;
  shadow.userData.baseOpacity = material.opacity;
  return shadow;
}

export function createSlimeCandidate() {
  const group = new THREE.Group();
  group.name = 'SlimeCandidate';

  const rig = new THREE.Group();
  rig.name = 'SlimeCandidateRig';
  group.add(rig);

  const gel = new THREE.MeshPhysicalMaterial({
    color: 0x62cbed,
    emissive: 0x0e3658,
    emissiveIntensity: 0.1,
    roughness: 0.36,
    metalness: 0,
    clearcoat: 0.3,
    clearcoatRoughness: 0.28,
    flatShading: false,
  });
  const eyeMaterial = new THREE.MeshStandardMaterial({
    color: 0x102431,
    roughness: 0.34,
    flatShading: false,
  });
  const glintMaterial = new THREE.MeshBasicMaterial({
    color: 0xf3fdff,
    toneMapped: false,
  });

  const body = add(rig, bendIntegratedCrown(smoothLathe([
    [0, 0.12],
    [0.24, 0.12],
    [0.4, 0.17],
    [0.51, 0.29],
    [0.55, 0.46],
    [0.52, 0.63],
    [0.43, 0.78],
    [0.29, 0.9],
    [0.17, 0.99],
    [0.09, 1.065],
    [0.035, 1.12],
    [0, 1.14],
  ])), gel, [0, 0, 0], [1, 1, 0.88], 'SlimeCandidateBody');
  // LatheGeometry closes at local +Z. Rotate that harmless duplicate-vertex
  // seam behind the character so it cannot read as a stripe down the face.
  body.rotation.y = Math.PI;

  const leftEye = add(rig, new THREE.SphereGeometry(0.085, 28, 18), eyeMaterial,
    [-0.145, 0.59, 0.448], [0.84, 1.22, 0.38], 'SlimeCandidateEyeLeft');
  const rightEye = add(rig, new THREE.SphereGeometry(0.085, 28, 18), eyeMaterial,
    [0.145, 0.59, 0.448], [0.84, 1.22, 0.38], 'SlimeCandidateEyeRight');
  leftEye.renderOrder = 2;
  rightEye.renderOrder = 2;

  add(rig, new THREE.SphereGeometry(0.021, 16, 10), glintMaterial,
    [-0.164, 0.622, 0.484], [1, 1.15, 0.55], 'SlimeCandidateGlintLeft');
  add(rig, new THREE.SphereGeometry(0.021, 16, 10), glintMaterial,
    [0.126, 0.622, 0.484], [1, 1.15, 0.55], 'SlimeCandidateGlintRight');

  const contactShadow = makeContactShadow();
  group.add(contactShadow);
  group.userData.contactShadow = contactShadow;

  const healthBar = makeHealthBar(0x63cfee);
  group.add(healthBar);
  group.userData.healthBar = healthBar;

  group.userData.action = null;
  group.userData.animationTime = 0;
  group.userData.playAction = (name, duration = 0.4) => {
    const current = group.userData.action;
    if (current?.name === name && group.userData.animationTime - current.startedAt < current.duration) return;
    group.userData.action = {
      name,
      duration,
      startedAt: group.userData.animationTime || 0,
    };
  };
  group.userData.animate = time => {
    group.userData.animationTime = time;
    let action = group.userData.action;
    if (action && time - action.startedAt >= action.duration) {
      group.userData.action = null;
      action = null;
    }
    const progress = action ? THREE.MathUtils.clamp((time - action.startedAt) / action.duration, 0, 1) : 0;
    const breathe = Math.sin(time * 2.6 + group.id) * 0.022;
    rig.position.set(0, -0.1 + Math.max(0, breathe) * 0.24, 0);
    rig.rotation.set(0, 0, breathe * 0.08);
    rig.scale.set(1 - breathe * 0.14, 1 + breathe, 1 - breathe * 0.14);

    if (action?.name === 'hit') {
      const recoil = Math.sin(progress * Math.PI);
      const shake = Math.sin(progress * Math.PI * 6) * (1 - progress);
      rig.position.x = shake * 0.07;
      rig.position.z = -recoil * 0.1;
      rig.scale.set(1 + recoil * 0.17, 1 - recoil * 0.27, 1 + recoil * 0.17);
    } else if (action?.name === 'attack') {
      const lunge = Math.sin(progress * Math.PI);
      rig.position.z = lunge * 0.1;
      rig.scale.set(1 - lunge * 0.08, 1 + lunge * 0.16, 1 - lunge * 0.08);
    } else if (action?.name === 'move') {
      const hop = Math.sin(progress * Math.PI);
      rig.position.y += hop * 0.1;
      rig.rotation.z += Math.sin(progress * Math.PI * 2) * 0.07;
    }
  };

  group.userData.animate(0);
  return group;
}
