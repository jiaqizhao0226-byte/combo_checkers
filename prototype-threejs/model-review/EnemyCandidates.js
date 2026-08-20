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

function pivot(parent, name, position = [0, 0, 0]) {
  const node = new THREE.Group();
  node.name = name;
  node.position.set(...position);
  parent.add(node);
  return node;
}

function physical(color, options = {}) {
  return new THREE.MeshPhysicalMaterial({
    color,
    roughness: 0.58,
    metalness: 0,
    clearcoat: 0.04,
    clearcoatRoughness: 0.7,
    flatShading: false,
    ...options,
  });
}

function standard(color, options = {}) {
  return new THREE.MeshStandardMaterial({
    color,
    roughness: 0.48,
    metalness: 0,
    flatShading: false,
    ...options,
  });
}

function addVertexColorVariation(geometry, color, strength = 0.06, seed = 0) {
  const positions = geometry.getAttribute('position');
  const colors = new Float32Array(positions.count * 3);
  const base = new THREE.Color(color);
  const sample = new THREE.Color();
  for (let index = 0; index < positions.count; index += 1) {
    const x = positions.getX(index);
    const y = positions.getY(index);
    const z = positions.getZ(index);
    const broad = Math.sin(x * 6.7 + y * 9.1 + z * 5.3 + seed * 2.17);
    const fine = Math.sin(x * 17.3 - y * 13.7 + z * 11.9 + seed * 4.03);
    const value = 1 + (broad * 0.7 + fine * 0.3) * strength;
    sample.copy(base).multiplyScalar(value);
    colors[index * 3] = sample.r;
    colors[index * 3 + 1] = sample.g;
    colors[index * 3 + 2] = sample.b;
  }
  geometry.setAttribute('color', new THREE.BufferAttribute(colors, 3));
  return geometry;
}

function glow(color, intensity = 1.25) {
  return new THREE.MeshBasicMaterial({
    color: new THREE.Color(color).multiplyScalar(intensity),
    toneMapped: false,
  });
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
  group.position.set(0, 0.08, 0.52);
  return group;
}

function makeContactShadow(width = 0.46, depth = 0.34, opacity = 0.24) {
  const geometry = new THREE.CircleGeometry(0.5, 40);
  geometry.rotateX(-Math.PI / 2);
  const shadow = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial({
    color: 0x06110f,
    transparent: true,
    opacity,
    depthWrite: false,
    toneMapped: false,
  }));
  shadow.position.y = 0.012;
  shadow.scale.set(width * 2, 1, depth * 2);
  shadow.renderOrder = 1;
  shadow.userData.baseOpacity = opacity;
  return shadow;
}

function addEye(parent, x, y, z, size, eyeMaterial, glintMaterial, prefix) {
  const eye = add(parent, new THREE.SphereGeometry(size, 24, 16), eyeMaterial,
    [x, y, z], [0.88, 1.14, 0.42], `${prefix}Eye`);
  add(parent, new THREE.SphereGeometry(size * 0.24, 12, 8), glintMaterial,
    [x - size * 0.22, y + size * 0.26, z + size * 0.39], [1, 1, 0.55], `${prefix}Glint`);
  return eye;
}

function tube(points, radius, material, tubularSegments = 32, radialSegments = 10) {
  const curve = new THREE.CatmullRomCurve3(points.map(point => new THREE.Vector3(...point)));
  return new THREE.Mesh(
    new THREE.TubeGeometry(curve, tubularSegments, radius, radialSegments, false),
    material
  );
}

function taperedTube(points, startRadius, endRadius, material, tubularSegments = 56, radialSegments = 16) {
  const curve = new THREE.CatmullRomCurve3(points.map(point => new THREE.Vector3(...point)));
  const positions = [];
  const indices = [];
  const tangent = new THREE.Vector3();
  const normal = new THREE.Vector3();
  const binormal = new THREE.Vector3();
  const reference = new THREE.Vector3();

  for (let segment = 0; segment <= tubularSegments; segment += 1) {
    const t = segment / tubularSegments;
    const center = curve.getPointAt(t);
    curve.getTangentAt(t, tangent).normalize();
    reference.set(0, 1, 0);
    if (Math.abs(tangent.dot(reference)) > 0.92) reference.set(1, 0, 0);
    normal.crossVectors(tangent, reference).normalize();
    binormal.crossVectors(tangent, normal).normalize();
    const radius = THREE.MathUtils.lerp(startRadius, endRadius, Math.pow(t, 1.18));
    for (let side = 0; side < radialSegments; side += 1) {
      const angle = side / radialSegments * Math.PI * 2;
      const cos = Math.cos(angle) * radius;
      const sin = Math.sin(angle) * radius;
      positions.push(
        center.x + normal.x * cos + binormal.x * sin,
        center.y + normal.y * cos + binormal.y * sin,
        center.z + normal.z * cos + binormal.z * sin
      );
    }
  }

  for (let segment = 0; segment < tubularSegments; segment += 1) {
    for (let side = 0; side < radialSegments; side += 1) {
      const nextSide = (side + 1) % radialSegments;
      const a = segment * radialSegments + side;
      const b = (segment + 1) * radialSegments + side;
      const c = (segment + 1) * radialSegments + nextSide;
      const d = segment * radialSegments + nextSide;
      indices.push(a, b, d, b, c, d);
    }
  }

  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
  geometry.setIndex(indices);
  geometry.computeVertexNormals();
  geometry.computeBoundingSphere();
  return new THREE.Mesh(geometry, material);
}

function capturePose(nodes) {
  const states = nodes.map(node => ({
    node,
    position: node.position.clone(),
    rotation: node.rotation.clone(),
    scale: node.scale.clone(),
  }));
  return () => {
    states.forEach(({ node, position, rotation, scale }) => {
      node.position.copy(position);
      node.rotation.copy(rotation);
      node.scale.copy(scale);
    });
  };
}

function finishCandidate({
  group,
  rig,
  healthColor,
  scale = 1,
  shadow = [0.46, 0.34, 0.24],
  nodes = [],
  idle,
  actions = {},
}) {
  const contactShadow = makeContactShadow(...shadow);
  group.add(contactShadow);
  group.userData.contactShadow = contactShadow;

  const healthBar = makeHealthBar(healthColor);
  group.add(healthBar);
  group.userData.healthBar = healthBar;
  group.scale.setScalar(scale);
  group.rotation.y = 0;

  const restorePose = capturePose([rig, ...nodes]);
  group.userData.action = null;
  group.userData.animationTime = 0;
  group.userData.playAction = (name, duration = 0.5) => {
    const current = group.userData.action;
    const now = group.userData.animationTime || 0;
    if (current?.name === name && now - current.startedAt < current.duration) return;
    group.userData.action = { name, duration, startedAt: now };
  };
  group.userData.animate = time => {
    group.userData.animationTime = time;
    let action = group.userData.action;
    if (action && time - action.startedAt >= action.duration) {
      group.userData.action = null;
      action = null;
    }
    const progress = action
      ? THREE.MathUtils.clamp((time - action.startedAt) / action.duration, 0, 1)
      : 0;
    restorePose();
    idle?.(time, group.id);
    actions[action?.name]?.(progress, time);
  };
  group.userData.animate(0);
  return group;
}

export function createJellyfishCandidate() {
  const group = new THREE.Group();
  group.name = 'JellyfishCandidate';
  const rig = pivot(group, 'JellyfishCandidateRig');
  const bell = pivot(rig, 'JellyfishBell', [0, 0.68, 0]);

  const bellMaterial = physical(0x66cef0, {
    roughness: 0.34,
    clearcoat: 0.38,
    clearcoatRoughness: 0.3,
    transparent: true,
    opacity: 0.84,
    emissive: 0x123c64,
    emissiveIntensity: 0.18,
  });
  const rimMaterial = physical(0xb9f4ff, {
    roughness: 0.4,
    clearcoat: 0.24,
    emissive: 0x2b6f84,
    emissiveIntensity: 0.2,
  });
  const tentacleMaterial = physical(0x79d7e8, {
    roughness: 0.52,
    clearcoat: 0.12,
  });
  const dark = standard(0x10252e, { roughness: 0.38 });
  const glint = glow(0xf1ffff, 1.35);

  add(bell, new THREE.SphereGeometry(0.48, 40, 24, 0, Math.PI * 2, 0, Math.PI * 0.6),
    bellMaterial, [0, 0, 0], [1, 0.9, 0.92], 'JellyfishCandidateDome');
  const rim = add(bell, new THREE.TorusGeometry(0.39, 0.055, 14, 40),
    rimMaterial, [0, -0.025, 0], [1, 1, 0.92], 'JellyfishCandidateRim');
  rim.rotation.x = Math.PI / 2;
  add(bell, new THREE.SphereGeometry(0.24, 28, 18), rimMaterial,
    [0, -0.03, 0], [1, 0.28, 0.9], 'JellyfishCandidateCore');
  addEye(bell, -0.14, 0.08, 0.405, 0.062, dark, glint, 'JellyfishCandidateLeft');
  addEye(bell, 0.14, 0.08, 0.405, 0.062, dark, glint, 'JellyfishCandidateRight');

  const tentacles = [];
  [
    [-0.27, 0.02, -0.05, -0.04],
    [-0.1, 0.08, 0.04, 0.06],
    [0.1, -0.05, 0.03, -0.04],
    [0.27, 0.01, -0.04, 0.05],
  ].forEach(([x, z, curlX, curlZ], index) => {
    const tentacle = pivot(rig, `JellyfishTentacle${index + 1}`, [x, 0.62, z]);
    const mesh = tube([
      [0, 0, 0],
      [curlX, -0.18, curlZ],
      [-curlX * 0.7, -0.39, -curlZ * 0.5],
      [curlX * 0.8, -0.62 - (index % 2) * 0.08, curlZ * 0.8],
    ], 0.044, tentacleMaterial, 30, 10);
    mesh.name = `JellyfishCandidateTentacleMesh${index + 1}`;
    mesh.castShadow = true;
    tentacle.add(mesh);
    tentacles.push(tentacle);
  });

  return finishCandidate({
    group,
    rig,
    healthColor: 0x66cef0,
    scale: 0.96,
    shadow: [0.4, 0.3, 0.18],
    nodes: [bell, ...tentacles],
    idle: time => {
      const pulse = Math.sin(time * 2.5);
      rig.position.y = 0.1 + Math.sin(time * 1.7) * 0.045;
      bell.scale.set(1 + pulse * 0.035, 1 - pulse * 0.055, 1 + pulse * 0.035);
      tentacles.forEach((tentacle, index) => {
        tentacle.rotation.z = Math.sin(time * 2 + index * 0.9) * 0.11;
        tentacle.rotation.x = Math.cos(time * 1.6 + index) * 0.07;
      });
    },
    actions: {
      move: progress => {
        const pulse = Math.sin(progress * Math.PI);
        bell.scale.set(1 + pulse * 0.11, 1 - pulse * 0.16, 1 + pulse * 0.11);
        rig.position.y += pulse * 0.15;
      },
      attack: progress => {
        const shock = Math.sin(progress * Math.PI);
        bell.scale.set(1 + shock * 0.13, 1 - shock * 0.1, 1 + shock * 0.13);
        tentacles.forEach((tentacle, index) => {
          tentacle.rotation.x += shock * (index % 2 ? 0.38 : -0.38);
          tentacle.rotation.z += shock * (index - 1.5) * 0.12;
        });
      },
      hit: progress => {
        const recoil = Math.sin(progress * Math.PI);
        rig.position.z = -recoil * 0.16;
        rig.scale.set(1 + recoil * 0.12, 1 - recoil * 0.2, 1 + recoil * 0.12);
      },
    },
  });
}

export function createIronTurtleCandidate() {
  const group = new THREE.Group();
  group.name = 'IronTurtleCandidate';
  const rig = pivot(group, 'IronTurtleCandidateRig');
  const shell = pivot(rig, 'IronTurtleShell', [0, 0, -0.06]);
  const head = pivot(rig, 'IronTurtleHead', [0, 0.43, 0.47]);

  const ironDark = physical(0x43575a, {
    roughness: 0.74,
    metalness: 0.36,
    clearcoat: 0,
  });
  const ironPlate = physical(0x91a1a0, {
    roughness: 0.52,
    metalness: 0.5,
    clearcoat: 0,
  });
  const ironPlatePaint = physical(0xffffff, {
    roughness: 0.54,
    metalness: 0.52,
    clearcoat: 0,
    vertexColors: true,
  });
  const skin = standard(0x8eb882, { roughness: 0.82 });
  const skinLight = standard(0xc5d9a9, { roughness: 0.88 });
  const skinShade = standard(0x66845f, { roughness: 0.9 });
  const groove = standard(0x26383b, { roughness: 0.92, metalness: 0.28 });
  const edge = physical(0x788b8b, { roughness: 0.6, metalness: 0.46, clearcoat: 0 });
  const rust = standard(0x76503b, { roughness: 0.96 });
  const dark = standard(0x10191a, { roughness: 0.42 });
  const glint = glow(0xf5fff2, 1.25);

  const bodyGeometry = addVertexColorVariation(
    new THREE.SphereGeometry(0.4, 40, 26), 0x8eb882, 0.045, 1
  );
  const bodyMaterial = standard(0xffffff, { roughness: 0.84, vertexColors: true });
  add(rig, bodyGeometry, bodyMaterial,
    [0, 0.34, 0.04], [1.12, 0.68, 1.08], 'IronTurtleCandidateBody');

  // A thick outer lip and a recessed dome give the shell a readable profile
  // at actual board scale. The dark inset stays visible between armor plates.
  add(shell, new THREE.SphereGeometry(0.56, 44, 28), ironDark,
    [0, 0.42, -0.05], [1.07, 0.38, 0.94], 'IronTurtleCandidateShellUnderlay');
  const shellGeometry = addVertexColorVariation(
    new THREE.SphereGeometry(0.515, 48, 30), 0x667a7b, 0.06, 3
  );
  const shellMaterial = physical(0xffffff, {
    roughness: 0.64,
    metalness: 0.46,
    clearcoat: 0,
    vertexColors: true,
  });
  add(shell, shellGeometry, shellMaterial,
    [0, 0.55, -0.05], [1.04, 0.67, 0.92], 'IronTurtleCandidateShell');

  const shellRim = add(shell, new THREE.TorusGeometry(0.49, 0.062, 14, 56), edge,
    [0, 0.47, -0.05], [1.08, 1, 0.9], 'IronTurtleCandidateShellRim');
  shellRim.rotation.x = Math.PI / 2;

  const plateSpecs = [
    [0, 0.875, -0.04, 0.205, 0],
    [-0.26, 0.79, 0.01, 0.155, 1],
    [0.26, 0.79, 0.01, 0.155, 2],
    [0, 0.785, 0.245, 0.16, 3],
    [0, 0.8, -0.325, 0.15, 4],
    [-0.34, 0.69, -0.2, 0.125, 5],
    [0.34, 0.69, -0.2, 0.125, 6],
  ];
  const shellUp = new THREE.Vector3(0, 1, 0);
  plateSpecs.forEach(([x, y, z, radius, seed], index) => {
    const plateMount = pivot(shell, `IronTurtleCandidatePlateMount${index + 1}`, [x, y, z]);
    const normal = new THREE.Vector3(x * 0.75, 1, (z + 0.05) * 0.72).normalize();
    plateMount.quaternion.setFromUnitVectors(shellUp, normal);
    add(plateMount, new THREE.CylinderGeometry(radius * 1.06, radius * 1.08, 0.028, 6), groove,
      [0, 0, 0], [1, 1, 0.92], `IronTurtleCandidatePlateGroove${index + 1}`);
    const plateGeometry = addVertexColorVariation(
      new THREE.CylinderGeometry(radius, radius * 1.025, 0.046, 6, 2, false),
      index === 0 ? 0x82979a : 0x73898a,
      0.045,
      seed + 6
    );
    add(plateMount, plateGeometry, ironPlatePaint,
      [0, 0.035, 0], [1, 1, 0.9], `IronTurtleCandidatePlate${index + 1}`);
  });

  // Six articulated rim guards break up the otherwise continuous dark band.
  // Their face normals follow the shell ellipse and each carries one rivet.
  [-1.2, -0.78, -0.38, 0.38, 0.78, 1.2].forEach((angle, index) => {
    const x = Math.sin(angle) * 0.49 * 1.12;
    const z = -0.05 + Math.cos(angle) * 0.49 * 1.02;
    const guardMount = pivot(shell, `IronTurtleCandidateRimGuardMount${index + 1}`, [x, 0.5, z]);
    const outward = new THREE.Vector3(Math.sin(angle), 0.28, Math.cos(angle)).normalize();
    guardMount.quaternion.setFromUnitVectors(shellUp, outward);
    add(guardMount, new THREE.CylinderGeometry(0.07, 0.076, 0.036, 6), edge,
      [0, 0.018, 0], [1, 1, 0.82], `IronTurtleCandidateRimGuard${index + 1}`);
    add(guardMount, new THREE.SphereGeometry(0.021, 14, 10), ironPlate,
      [0, 0.052, 0], [1, 0.7, 1], `IronTurtleCandidateRivet${index + 1}`);
  });

  // Two shallow scratches and a rust bloom keep the armor from reading as a
  // perfectly molded toy. They are deliberately oversized for game view.
  const scratchOne = add(shell, new THREE.BoxGeometry(0.014, 0.018, 0.16), groove,
    [-0.08, 0.925, -0.045], [1, 1, 1], 'IronTurtleCandidateScratch1');
  scratchOne.rotation.y = -0.58;
  scratchOne.rotation.z = 0.08;
  const scratchTwo = add(shell, new THREE.BoxGeometry(0.011, 0.018, 0.11), groove,
    [-0.015, 0.928, -0.02], [1, 1, 1], 'IronTurtleCandidateScratch2');
  scratchTwo.rotation.y = -0.58;
  scratchTwo.rotation.z = 0.08;
  const rustPatch = add(shell, new THREE.SphereGeometry(0.07, 18, 12), rust,
    [0.38, 0.735, -0.12], [1, 0.12, 0.58], 'IronTurtleCandidateRustPatch');
  rustPatch.rotation.x = -0.34;

  add(rig, new THREE.SphereGeometry(0.2, 30, 20), skinShade,
    [0, 0.42, 0.36], [0.86, 0.72, 1.08], 'IronTurtleCandidateNeck');
  add(head, addVertexColorVariation(new THREE.SphereGeometry(0.255, 38, 24), 0x8eb882, 0.04, 9),
    bodyMaterial, [0, 0, 0], [1, 0.84, 1.08], 'IronTurtleCandidateHeadMesh');
  add(head, new THREE.SphereGeometry(0.19, 30, 20), skinLight,
    [0, -0.045, 0.178], [0.88, 0.6, 0.29], 'IronTurtleCandidateMuzzle');
  addEye(head, -0.092, 0.06, 0.23, 0.047, dark, glint, 'IronTurtleCandidateLeft');
  addEye(head, 0.092, 0.06, 0.23, 0.047, dark, glint, 'IronTurtleCandidateRight');
  add(head, new THREE.SphereGeometry(0.012, 12, 8), dark,
    [-0.05, -0.035, 0.245], [1, 0.7, 0.45], 'IronTurtleCandidateNostrilLeft');
  add(head, new THREE.SphereGeometry(0.012, 12, 8), dark,
    [0.05, -0.035, 0.245], [1, 0.7, 0.45], 'IronTurtleCandidateNostrilRight');
  const mouth = tube([
    [-0.075, -0.1, 0.24], [0, -0.112, 0.255], [0.075, -0.1, 0.24],
  ], 0.007, dark, 18, 6);
  mouth.name = 'IronTurtleCandidateMouth';
  head.add(mouth);

  const feet = [];
  [
    [-0.39, 0.24, 0.3], [0.39, 0.24, 0.3],
    [-0.4, 0.23, -0.26], [0.4, 0.23, -0.26],
  ].forEach(([x, y, z], index) => {
    const foot = pivot(rig, `IronTurtleFoot${index + 1}`, [x, y, z]);
    const front = index < 2;
    add(foot, new THREE.SphereGeometry(front ? 0.175 : 0.15, 28, 18), skin,
      [0, 0, 0], [front ? 1.18 : 1.05, 0.52, front ? 1.05 : 0.9], `IronTurtleFootMesh${index + 1}`);
    add(foot, new THREE.SphereGeometry(0.12, 22, 14), skinShade,
      [0, -0.025, front ? 0.075 : 0.045], [1.08, 0.28, 0.74], `IronTurtleFootPad${index + 1}`);
    const clawCount = front ? 3 : 2;
    for (let clawIndex = 0; clawIndex < clawCount; clawIndex += 1) {
      const claw = add(foot, new THREE.ConeGeometry(0.025, front ? 0.105 : 0.082, 10), skinLight,
        [(clawIndex - (clawCount - 1) * 0.5) * 0.065, -0.005, front ? 0.15 : 0.115],
        [1, 1, 1], `IronTurtleClaw${index + 1}_${clawIndex + 1}`);
      claw.rotation.x = Math.PI / 2;
    }
    if (front) {
      const cuff = add(foot, new THREE.TorusGeometry(0.12, 0.025, 10, 28), edge,
        [0, 0.02, -0.07], [1.12, 1, 0.85], `IronTurtleCuff${index + 1}`);
      cuff.rotation.x = Math.PI / 2;
    }
    feet.push(foot);
  });
  const tail = add(rig, new THREE.ConeGeometry(0.095, 0.28, 18), skin,
    [0, 0.32, -0.54], [1, 1, 1], 'IronTurtleCandidateTail');
  tail.rotation.x = -Math.PI / 2;

  return finishCandidate({
    group,
    rig,
    healthColor: 0x69868a,
    scale: 0.9,
    shadow: [0.55, 0.4, 0.29],
    nodes: [shell, head, ...feet],
    idle: time => {
      rig.position.y = -0.015 + Math.sin(time * 2) * 0.009;
      head.rotation.y = Math.sin(time * 1.25) * 0.08;
      feet.forEach((foot, index) => { foot.rotation.z = Math.sin(time * 2.2 + index) * 0.025; });
    },
    actions: {
      move: progress => {
        const stride = Math.sin(progress * Math.PI * 2);
        feet.forEach((foot, index) => {
          foot.position.z += stride * (index % 2 ? -0.07 : 0.07);
          foot.rotation.x = stride * (index % 2 ? 0.24 : -0.24);
        });
        rig.position.y += Math.abs(stride) * 0.025;
      },
      attack: progress => {
        const lunge = Math.sin(progress * Math.PI);
        head.position.z += lunge * 0.28;
        head.scale.set(1 + lunge * 0.08, 1 - lunge * 0.05, 1 + lunge * 0.08);
        shell.position.z -= lunge * 0.045;
      },
      hit: progress => {
        const recoil = Math.sin(progress * Math.PI);
        head.position.z -= recoil * 0.26;
        feet.forEach(foot => { foot.position.x *= 1 - recoil * 0.28; });
        shell.rotation.z = Math.sin(progress * Math.PI * 5) * (1 - progress) * 0.06;
      },
    },
  });
}

export function createArcherfishCandidate() {
  const group = new THREE.Group();
  group.name = 'ArcherfishCandidate';
  const rig = pivot(group, 'ArcherfishCandidateRig');
  const body = pivot(rig, 'ArcherfishBody');
  const tail = pivot(rig, 'ArcherfishTail', [0, 0.5, -0.75]);
  const leftFin = pivot(rig, 'ArcherfishFinLeft', [-0.34, 0.48, 0.02]);
  const rightFin = pivot(rig, 'ArcherfishFinRight', [0.34, 0.48, 0.02]);

  const gold = standard(0xdca64b, { roughness: 0.62 });
  const cream = standard(0xead292, { roughness: 0.76 });
  const teal = standard(0x3b969e, { roughness: 0.7 });
  const stripe = standard(0x53523d, { roughness: 0.8 });
  const dark = standard(0x142021, { roughness: 0.38 });
  const glint = glow(0xf8fff5, 1.3);

  add(body, new THREE.SphereGeometry(0.48, 36, 24), gold,
    [0, 0.5, 0], [0.84, 0.72, 1.22], 'ArcherfishCandidateBody');
  add(body, new THREE.SphereGeometry(0.39, 30, 20), cream,
    [0, 0.4, 0.25], [0.72, 0.42, 0.78], 'ArcherfishCandidateBelly');

  [-0.26, 0, 0.25].forEach((z, index) => {
    [-1, 1].forEach(side => {
      add(body, new THREE.SphereGeometry(0.105 - index * 0.012, 20, 14), stripe,
        [side * 0.345, 0.56, z], [0.18, 1.12, 0.54], `ArcherfishStripe${index + 1}${side < 0 ? 'L' : 'R'}`);
    });
  });

  const nozzle = add(body, new THREE.CylinderGeometry(0.075, 0.105, 0.24, 24), teal,
    [0, 0.43, 0.59], [1, 1, 1], 'ArcherfishCandidateNozzle');
  nozzle.rotation.x = Math.PI / 2;
  addEye(body, -0.19, 0.61, 0.43, 0.058, dark, glint, 'ArcherfishCandidateLeft');
  addEye(body, 0.19, 0.61, 0.43, 0.058, dark, glint, 'ArcherfishCandidateRight');

  const dorsal = add(body, new THREE.ConeGeometry(0.16, 0.38, 20), teal,
    [0, 0.91, -0.25], [1.1, 1, 0.5], 'ArcherfishCandidateDorsalFin');
  dorsal.rotation.x = -0.12;
  add(leftFin, new THREE.SphereGeometry(0.2, 24, 14), teal,
    [-0.08, 0, 0], [1.15, 0.18, 0.72], 'ArcherfishCandidateLeftFinMesh').rotation.z = -0.3;
  add(rightFin, new THREE.SphereGeometry(0.2, 24, 14), teal,
    [0.08, 0, 0], [1.15, 0.18, 0.72], 'ArcherfishCandidateRightFinMesh').rotation.z = 0.3;

  [-1, 1].forEach(side => {
    const lobe = add(tail, new THREE.SphereGeometry(0.22, 24, 16), teal,
      [side * 0.13, 0, -0.16], [0.9, 0.2, 1], `ArcherfishTailLobe${side < 0 ? 'L' : 'R'}`);
    lobe.rotation.z = side * 0.34;
  });
  const tailStem = add(tail, new THREE.CapsuleGeometry(0.085, 0.22, 8, 18), gold,
    [0, 0, 0.1], [1, 1, 0.9], 'ArcherfishCandidateTailStem');
  tailStem.rotation.x = Math.PI / 2;

  return finishCandidate({
    group,
    rig,
    healthColor: 0xd9aa48,
    scale: 0.94,
    shadow: [0.49, 0.42, 0.22],
    nodes: [body, tail, leftFin, rightFin],
    idle: time => {
      rig.position.y = 0.04 + Math.sin(time * 1.9) * 0.025;
      tail.rotation.y = Math.sin(time * 3.1) * 0.2;
      leftFin.rotation.z = -0.16 + Math.sin(time * 2.7) * 0.08;
      rightFin.rotation.z = 0.16 - Math.sin(time * 2.7) * 0.08;
    },
    actions: {
      move: progress => {
        const swim = Math.sin(progress * Math.PI * 3);
        tail.rotation.y += swim * 0.34;
        rig.rotation.z = swim * 0.055;
        rig.position.y += Math.sin(progress * Math.PI) * 0.08;
      },
      attack: progress => {
        const shot = Math.sin(progress * Math.PI);
        body.position.z -= shot * 0.11;
        nozzle.scale.set(1 + shot * 0.16, 1 + shot * 0.25, 1 + shot * 0.16);
        tail.rotation.y += Math.sin(progress * Math.PI * 2) * 0.22;
      },
      hit: progress => {
        const recoil = Math.sin(progress * Math.PI);
        rig.position.z = -recoil * 0.18;
        rig.rotation.z = Math.sin(progress * Math.PI * 5) * (1 - progress) * 0.11;
      },
    },
  });
}

export function createVortexEelCandidate() {
  const group = new THREE.Group();
  group.name = 'VortexEelCandidate';
  const rig = pivot(group, 'VortexEelCandidateRig');
  const body = pivot(rig, 'VortexEelBody');
  const head = pivot(rig, 'VortexEelHead', [0.08, 0.55, 0.5]);
  const tail = pivot(rig, 'VortexEelTail', [-0.06, 0.45, -0.92]);

  const blue = physical(0x416bbb, { roughness: 0.52, clearcoat: 0.16, clearcoatRoughness: 0.64 });
  const cyan = physical(0x59c7ca, {
    roughness: 0.46,
    clearcoat: 0.18,
    clearcoatRoughness: 0.58,
    emissive: 0x14545b,
    emissiveIntensity: 0.18,
  });
  const belly = standard(0x9cdadd, { roughness: 0.7 });
  const dark = standard(0x101b2d, { roughness: 0.4 });
  const glint = glow(0xeaffff, 1.4);

  const bodyMesh = taperedTube([
    [0.08, 0.55, 0.35],
    [-0.12, 0.5, 0.05],
    [0.12, 0.48, -0.28],
    [-0.08, 0.46, -0.62],
    [-0.06, 0.45, -0.92],
  ], 0.205, 0.075, blue, 56, 16);
  bodyMesh.name = 'VortexEelCandidateBodyMesh';
  bodyMesh.castShadow = true;
  body.add(bodyMesh);

  add(head, new THREE.SphereGeometry(0.28, 32, 22), blue,
    [0, 0, 0], [0.94, 0.78, 1.08], 'VortexEelCandidateHeadMesh');
  add(head, new THREE.SphereGeometry(0.2, 26, 18), belly,
    [0, -0.06, 0.18], [0.78, 0.5, 0.32], 'VortexEelCandidateMuzzle');
  addEye(head, -0.1, 0.06, 0.23, 0.052, dark, glint, 'VortexEelCandidateLeft');
  addEye(head, 0.1, 0.06, 0.23, 0.052, dark, glint, 'VortexEelCandidateRight');

  [
    [-0.17, 0.54, 0.15], [0.18, 0.49, -0.09],
    [-0.14, 0.48, -0.37], [0.1, 0.46, -0.62],
  ].forEach(([x, y, z], index) => {
    add(body, new THREE.SphereGeometry(0.07, 20, 14), cyan,
      [x, y, z], [0.55, 1, 0.32], `VortexEelCandidateGlowMark${index + 1}`);
  });

  [-1, 1].forEach(side => {
    const fin = add(tail, new THREE.SphereGeometry(0.18, 24, 16), cyan,
      [side * 0.11, 0, -0.12], [0.75, 0.18, 1], `VortexEelTailFin${side < 0 ? 'L' : 'R'}`);
    fin.rotation.z = side * 0.38;
  });
  const dorsal = tube([
    [0, 0, 0], [0, 0.03, -0.25], [0, 0.02, -0.52], [0, 0, -0.75],
  ], 0.028, cyan, 24, 8);
  dorsal.name = 'VortexEelCandidateDorsalGlow';
  dorsal.position.set(0, 0.69, 0.18);
  body.add(dorsal);

  return finishCandidate({
    group,
    rig,
    healthColor: 0x4b7ada,
    scale: 0.92,
    shadow: [0.42, 0.52, 0.2],
    nodes: [body, head, tail],
    idle: time => {
      rig.position.y = 0.02 + Math.sin(time * 1.7) * 0.025;
      rig.rotation.z = Math.sin(time * 1.45) * 0.025;
      tail.rotation.y = Math.sin(time * 3) * 0.28;
      head.rotation.y = Math.sin(time * 1.5) * 0.05;
    },
    actions: {
      move: progress => {
        const wave = Math.sin(progress * Math.PI * 3);
        body.rotation.y = wave * 0.12;
        head.rotation.y = -wave * 0.14;
        tail.rotation.y += wave * 0.45;
        rig.position.y += Math.sin(progress * Math.PI) * 0.08;
      },
      attack: progress => {
        const strike = Math.sin(progress * Math.PI);
        head.position.z += strike * 0.3;
        body.rotation.y = Math.sin(progress * Math.PI * 2) * strike * 0.17;
        tail.rotation.y += Math.sin(progress * Math.PI * 2) * 0.4;
      },
      hit: progress => {
        const recoil = Math.sin(progress * Math.PI);
        rig.position.z = -recoil * 0.2;
        rig.rotation.y = Math.sin(progress * Math.PI * 4) * (1 - progress) * 0.12;
      },
    },
  });
}

export function createElectricRayCandidate() {
  const group = new THREE.Group();
  group.name = 'ElectricRayCandidate';
  const rig = pivot(group, 'ElectricRayCandidateRig');
  const body = pivot(rig, 'ElectricRayBody', [0, 0.5, 0.02]);
  const leftWing = pivot(rig, 'ElectricRayWingLeft', [-0.16, 0.5, 0]);
  const rightWing = pivot(rig, 'ElectricRayWingRight', [0.16, 0.5, 0]);
  const tail = pivot(rig, 'ElectricRayTail', [0, 0.49, -0.56]);

  const purple = physical(0x7258b8, {
    roughness: 0.76,
    clearcoat: 0,
    sheen: 0.18,
    sheenColor: 0xa998cc,
    sheenRoughness: 0.86,
  });
  const purpleDark = standard(0x493b72, { roughness: 0.86 });
  const underside = standard(0xcbbfd6, { roughness: 0.9 });
  const electric = glow(0xffe96a, 1.45);
  const dark = standard(0x17152a, { roughness: 0.38 });
  const glint = glow(0xfaffdf, 1.35);

  add(body, new THREE.SphereGeometry(0.43, 36, 24), purple,
    [0, 0, 0.08], [0.8, 0.32, 1.15], 'ElectricRayCandidateBody');
  add(body, new THREE.SphereGeometry(0.35, 30, 20), underside,
    [0, -0.1, 0.1], [0.72, 0.18, 0.88], 'ElectricRayCandidateUnderside');

  const leftWingMesh = add(leftWing, new THREE.SphereGeometry(0.46, 34, 22), purple,
    [-0.28, 0, 0], [1.1, 0.18, 0.9], 'ElectricRayCandidateLeftWingMesh');
  leftWingMesh.rotation.y = 0.16;
  leftWingMesh.rotation.z = -0.09;
  const rightWingMesh = add(rightWing, new THREE.SphereGeometry(0.46, 34, 22), purple,
    [0.28, 0, 0], [1.1, 0.18, 0.9], 'ElectricRayCandidateRightWingMesh');
  rightWingMesh.rotation.y = -0.16;
  rightWingMesh.rotation.z = 0.09;

  addEye(body, -0.14, 0.105, 0.34, 0.044, dark, glint, 'ElectricRayCandidateLeft');
  addEye(body, 0.14, 0.105, 0.34, 0.044, dark, glint, 'ElectricRayCandidateRight');
  [
    [-0.44, 0.09, 0.07], [-0.31, 0.1, 0.23],
    [0.44, 0.09, 0.07], [0.31, 0.1, 0.23],
  ].forEach(([x, y, z], index) => {
    const parent = x < 0 ? leftWing : rightWing;
    const localX = x - parent.position.x;
    add(parent, new THREE.SphereGeometry(index % 2 ? 0.045 : 0.06, 18, 12), electric,
      [localX, y - parent.position.y, z], [1, 0.45, 1], `ElectricRayGlowSpot${index + 1}`);
  });

  const tailStem = add(tail, new THREE.CapsuleGeometry(0.045, 0.82, 8, 16), purpleDark,
    [0, 0, -0.42], [1, 1, 1], 'ElectricRayCandidateTailStem');
  tailStem.rotation.x = Math.PI / 2;
  const barb = add(tail, new THREE.ConeGeometry(0.09, 0.24, 18), electric,
    [0, 0, -0.91], [0.72, 1, 0.34], 'ElectricRayCandidateTailBarb');
  barb.rotation.x = -Math.PI / 2;

  return finishCandidate({
    group,
    rig,
    healthColor: 0x8068c4,
    scale: 0.92,
    shadow: [0.68, 0.52, 0.2],
    nodes: [body, leftWing, rightWing, tail],
    idle: time => {
      rig.position.y = 0.03 + Math.sin(time * 1.8) * 0.025;
      const flap = Math.sin(time * 2.35) * 0.08;
      leftWing.rotation.z = -0.05 + flap;
      rightWing.rotation.z = 0.05 - flap;
      tail.rotation.y = Math.sin(time * 2.4) * 0.14;
    },
    actions: {
      move: progress => {
        const flap = Math.sin(progress * Math.PI * 3);
        leftWing.rotation.z += flap * 0.18;
        rightWing.rotation.z -= flap * 0.18;
        tail.rotation.y += flap * 0.22;
        rig.position.y += Math.sin(progress * Math.PI) * 0.08;
      },
      attack: progress => {
        const charge = Math.sin(progress * Math.PI);
        leftWing.scale.setScalar(1 + charge * 0.08);
        rightWing.scale.setScalar(1 + charge * 0.08);
        body.scale.set(1 - charge * 0.06, 1 + charge * 0.18, 1 - charge * 0.06);
        rig.position.z += charge * 0.09;
      },
      hit: progress => {
        const recoil = Math.sin(progress * Math.PI);
        rig.position.z = -recoil * 0.17;
        leftWing.rotation.z += recoil * 0.24;
        rightWing.rotation.z -= recoil * 0.24;
      },
    },
  });
}

export function createHermitCrabCandidate() {
  const group = new THREE.Group();
  group.name = 'HermitCrabCandidate';
  const rig = pivot(group, 'HermitCrabCandidateRig');
  const shell = pivot(rig, 'HermitCrabShell');
  const body = pivot(rig, 'HermitCrabBody');
  const leftEyeStalk = pivot(rig, 'HermitCrabEyeStalkLeft', [-0.13, 0.43, 0.34]);
  const rightEyeStalk = pivot(rig, 'HermitCrabEyeStalkRight', [0.13, 0.43, 0.34]);
  const leftClaw = pivot(rig, 'HermitCrabClawLeft', [-0.39, 0.32, 0.3]);
  const rightClaw = pivot(rig, 'HermitCrabClawRight', [0.39, 0.32, 0.3]);

  const shellMaterial = standard(0xd39a5c, { roughness: 0.88 });
  const shellDark = standard(0x875634, { roughness: 0.94 });
  const orange = physical(0xc86137, { roughness: 0.62, clearcoat: 0.08, clearcoatRoughness: 0.72 });
  const orangeLight = physical(0xe77f46, { roughness: 0.56, clearcoat: 0.12, clearcoatRoughness: 0.66 });
  const cream = standard(0xe4bd79, { roughness: 0.86 });
  const dark = standard(0x21130d, { roughness: 0.4 });
  const glint = glow(0xfffae9, 1.3);

  add(shell, new THREE.SphereGeometry(0.48, 38, 26), shellMaterial,
    [0, 0.58, -0.2], [0.92, 1.02, 0.84], 'HermitCrabCandidateShell');
  add(shell, new THREE.SphereGeometry(0.39, 30, 20), shellDark,
    [0, 0.6, -0.24], [0.86, 0.9, 0.77], 'HermitCrabCandidateShellInset');

  const spiralPoints = [];
  for (let index = 0; index < 28; index += 1) {
    const t = index / 27;
    const angle = t * Math.PI * 4.2;
    const radius = 0.25 * (1 - t * 0.78);
    spiralPoints.push([
      0.385,
      0.59 + Math.sin(angle) * radius,
      -0.2 + Math.cos(angle) * radius,
    ]);
  }
  const spiral = tube(spiralPoints, 0.027, cream, 48, 8);
  spiral.name = 'HermitCrabCandidateShellSpiral';
  spiral.castShadow = true;
  shell.add(spiral);

  add(body, new THREE.SphereGeometry(0.31, 30, 20), orange,
    [0, 0.29, 0.2], [1.05, 0.62, 0.9], 'HermitCrabCandidateBody');
  add(body, new THREE.SphereGeometry(0.23, 26, 18), cream,
    [0, 0.26, 0.34], [0.82, 0.42, 0.32], 'HermitCrabCandidateFace');

  [leftEyeStalk, rightEyeStalk].forEach((stalk, index) => {
    add(stalk, new THREE.CapsuleGeometry(0.035, 0.2, 6, 12), orangeLight,
      [0, 0.11, 0.02], [1, 1, 1], `HermitCrabEyeStalkMesh${index + 1}`);
    addEye(stalk, 0, 0.25, 0.04, 0.06, dark, glint,
      `HermitCrabCandidate${index === 0 ? 'Left' : 'Right'}`);
  });

  [leftClaw, rightClaw].forEach((claw, index) => {
    const side = index === 0 ? -1 : 1;
    add(claw, new THREE.SphereGeometry(0.19, 26, 18), orangeLight,
      [side * 0.07, 0.02, 0.03], [1.05, 0.78, 0.9], `HermitCrabClawPalm${index + 1}`);
    const upper = add(claw, new THREE.ConeGeometry(0.085, 0.24, 18), orangeLight,
      [side * 0.12, 0.08, 0.14], [0.9, 1, 0.72], `HermitCrabClawUpper${index + 1}`);
    upper.rotation.x = Math.PI / 2;
    upper.rotation.z = side * 0.28;
    const lower = add(claw, new THREE.ConeGeometry(0.07, 0.2, 18), orange,
      [side * 0.1, -0.045, 0.13], [0.8, 1, 0.68], `HermitCrabClawLower${index + 1}`);
    lower.rotation.x = Math.PI / 2;
    lower.rotation.z = side * -0.22;
  });

  const legs = [];
  [-1, 1].forEach(side => {
    for (let index = 0; index < 3; index += 1) {
      const leg = pivot(rig, `HermitCrabLeg${side < 0 ? 'L' : 'R'}${index + 1}`,
        [side * (0.23 + index * 0.07), 0.2, 0.14 - index * 0.14]);
      const legMesh = add(leg, new THREE.CapsuleGeometry(0.035, 0.25, 6, 12), orange,
        [side * 0.08, 0, 0], [1, 1, 1], `HermitCrabLegMesh${side < 0 ? 'L' : 'R'}${index + 1}`);
      legMesh.rotation.z = side * 0.86;
      legMesh.rotation.x = 0.2 + index * 0.08;
      legs.push(leg);
    }
  });

  return finishCandidate({
    group,
    rig,
    healthColor: 0xcf6e3c,
    scale: 0.92,
    shadow: [0.58, 0.42, 0.28],
    nodes: [shell, body, leftEyeStalk, rightEyeStalk, leftClaw, rightClaw, ...legs],
    idle: time => {
      rig.position.y = -0.015 + Math.sin(time * 2.1) * 0.012;
      leftEyeStalk.rotation.z = Math.sin(time * 1.4) * 0.06;
      rightEyeStalk.rotation.z = -Math.sin(time * 1.4) * 0.06;
      leftClaw.rotation.y = Math.sin(time * 1.8) * 0.08;
      rightClaw.rotation.y = -Math.sin(time * 1.8) * 0.08;
    },
    actions: {
      move: progress => {
        const stride = Math.sin(progress * Math.PI * 3);
        legs.forEach((leg, index) => {
          leg.rotation.z = stride * (index % 2 ? 0.22 : -0.22);
          leg.position.z += stride * (index % 2 ? 0.04 : -0.04);
        });
        rig.position.x = Math.sin(progress * Math.PI * 2) * 0.04;
      },
      attack: progress => {
        const snap = Math.sin(progress * Math.PI);
        leftClaw.position.z += snap * 0.25;
        rightClaw.position.z += snap * 0.25;
        leftClaw.rotation.y -= snap * 0.32;
        rightClaw.rotation.y += snap * 0.32;
      },
      hit: progress => {
        const hide = Math.sin(progress * Math.PI);
        body.position.z -= hide * 0.2;
        leftEyeStalk.scale.setScalar(1 - hide * 0.45);
        rightEyeStalk.scale.setScalar(1 - hide * 0.45);
        leftClaw.position.x *= 1 - hide * 0.3;
        rightClaw.position.x *= 1 - hide * 0.3;
        shell.rotation.z = Math.sin(progress * Math.PI * 5) * (1 - progress) * 0.07;
      },
    },
  });
}

export function createGhostSharkCandidate() {
  const group = new THREE.Group();
  group.name = 'GhostSharkCandidate';
  const rig = pivot(group, 'GhostSharkCandidateRig');
  const body = pivot(rig, 'GhostSharkBody');
  const leftFin = pivot(rig, 'GhostSharkFinLeft', [-0.31, 0.52, 0.02]);
  const rightFin = pivot(rig, 'GhostSharkFinRight', [0.31, 0.52, 0.02]);
  const tail = pivot(rig, 'GhostSharkTail', [0, 0.5, -0.58]);

  const ghost = physical(0x6c86b8, {
    roughness: 0.62,
    clearcoat: 0,
    transparent: true,
    opacity: 0.7,
    emissive: 0x1b2c55,
    emissiveIntensity: 0.3,
    depthWrite: false,
  });
  const ghostLight = physical(0xb8d8eb, {
    roughness: 0.7,
    clearcoat: 0,
    transparent: true,
    opacity: 0.62,
    emissive: 0x31546e,
    emissiveIntensity: 0.26,
    depthWrite: false,
  });
  const dark = standard(0x101528, { roughness: 0.36 });
  const eyeGlow = glow(0x8ff5ff, 1.55);

  add(body, new THREE.SphereGeometry(0.42, 36, 24), ghost,
    [0, 0.54, 0], [0.86, 0.68, 1.3], 'GhostSharkCandidateBody');
  add(body, new THREE.SphereGeometry(0.28, 30, 20), ghostLight,
    [0, 0.44, 0.32], [0.72, 0.4, 0.9], 'GhostSharkCandidateBelly');
  const snout = add(body, new THREE.CapsuleGeometry(0.09, 0.44, 8, 18), ghostLight,
    [0, 0.53, 0.66], [1, 1, 0.8], 'GhostSharkCandidateSnout');
  snout.rotation.x = Math.PI / 2;
  addEye(body, -0.17, 0.62, 0.41, 0.06, dark, eyeGlow, 'GhostSharkCandidateLeft');
  addEye(body, 0.17, 0.62, 0.41, 0.06, dark, eyeGlow, 'GhostSharkCandidateRight');

  const spine = add(body, new THREE.ConeGeometry(0.09, 0.5, 18), ghostLight,
    [0, 0.98, -0.12], [0.72, 1, 0.58], 'GhostSharkCandidateDorsalSpine');
  spine.rotation.x = -0.12;
  const dorsal = add(body, new THREE.SphereGeometry(0.18, 24, 16), ghost,
    [0, 0.82, -0.35], [0.48, 1, 0.68], 'GhostSharkCandidateDorsalFin');
  dorsal.rotation.x = -0.25;

  const leftFinMesh = add(leftFin, new THREE.ConeGeometry(0.17, 0.48, 24), ghostLight,
    [-0.16, 0, 0], [1, 1, 0.52], 'GhostSharkCandidateLeftFinMesh');
  leftFinMesh.quaternion.setFromUnitVectors(
    new THREE.Vector3(0, 1, 0),
    new THREE.Vector3(-1, 0, -0.16).normalize()
  );
  const rightFinMesh = add(rightFin, new THREE.ConeGeometry(0.17, 0.48, 24), ghostLight,
    [0.16, 0, 0], [1, 1, 0.52], 'GhostSharkCandidateRightFinMesh');
  rightFinMesh.quaternion.setFromUnitVectors(
    new THREE.Vector3(0, 1, 0),
    new THREE.Vector3(1, 0, -0.16).normalize()
  );

  const tailStem = add(tail, new THREE.CapsuleGeometry(0.11, 0.5, 8, 18), ghost,
    [0, 0, -0.18], [1, 1, 0.86], 'GhostSharkCandidateTailStem');
  tailStem.rotation.x = Math.PI / 2;
  [-1, 1].forEach(side => {
    const lobe = add(tail, new THREE.ConeGeometry(0.15, 0.4, 24), ghostLight,
      [side * 0.1, 0, -0.6], [1, 1, 0.48], `GhostSharkTailLobe${side < 0 ? 'L' : 'R'}`);
    lobe.quaternion.setFromUnitVectors(
      new THREE.Vector3(0, 1, 0),
      new THREE.Vector3(side * 0.46, 0, -1).normalize()
    );
  });

  return finishCandidate({
    group,
    rig,
    healthColor: 0x7089b9,
    scale: 0.94,
    shadow: [0.48, 0.56, 0.18],
    nodes: [body, leftFin, rightFin, tail],
    idle: time => {
      rig.position.y = 0.08 + Math.sin(time * 1.55) * 0.04;
      rig.rotation.z = Math.sin(time * 1.2) * 0.025;
      tail.rotation.y = Math.sin(time * 2.8) * 0.25;
      leftFin.rotation.z = -0.08 + Math.sin(time * 2) * 0.07;
      rightFin.rotation.z = 0.08 - Math.sin(time * 2) * 0.07;
    },
    actions: {
      move: progress => {
        const swim = Math.sin(progress * Math.PI * 3);
        tail.rotation.y += swim * 0.42;
        rig.rotation.z = swim * 0.05;
        rig.position.y += Math.sin(progress * Math.PI) * 0.08;
      },
      attack: progress => {
        const rush = Math.sin(progress * Math.PI);
        rig.position.z += rush * 0.32;
        body.rotation.x = -rush * 0.09;
        tail.rotation.y += Math.sin(progress * Math.PI * 2) * 0.38;
      },
      hit: progress => {
        const recoil = Math.sin(progress * Math.PI);
        rig.position.z = -recoil * 0.22;
        rig.rotation.y = Math.sin(progress * Math.PI * 5) * (1 - progress) * 0.15;
        leftFin.rotation.z += recoil * 0.2;
        rightFin.rotation.z -= recoil * 0.2;
      },
    },
  });
}

const CANDIDATE_FACTORIES = {
  jellyfish: createJellyfishCandidate,
  iron_turtle: createIronTurtleCandidate,
  archerfish: createArcherfishCandidate,
  vortex_eel: createVortexEelCandidate,
  electric_ray: createElectricRayCandidate,
  hermit_crab: createHermitCrabCandidate,
  ghost_shark: createGhostSharkCandidate,
};

export function createEnemyCandidate(type) {
  return CANDIDATE_FACTORIES[type]?.() || null;
}
