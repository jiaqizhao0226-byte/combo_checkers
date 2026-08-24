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

function addAxialBands(geometry, baseColor, bandColor, bandCenters, bandWidth = 0.075) {
  const positions = geometry.getAttribute('position');
  const colors = new Float32Array(positions.count * 3);
  const base = new THREE.Color(baseColor);
  const band = new THREE.Color(bandColor);
  const sample = new THREE.Color();
  for (let index = 0; index < positions.count; index += 1) {
    const z = positions.getZ(index);
    const distance = Math.min(...bandCenters.map(center => Math.abs(z - center)));
    const blend = THREE.MathUtils.smoothstep(bandWidth - distance, 0, bandWidth);
    const grain = 1 + Math.sin(index * 1.73 + z * 19) * 0.018;
    sample.copy(base).lerp(band, blend * 0.82).multiplyScalar(grain);
    colors[index * 3] = sample.r;
    colors[index * 3 + 1] = sample.g;
    colors[index * 3 + 2] = sample.b;
  }
  geometry.setAttribute('color', new THREE.BufferAttribute(colors, 3));
  return geometry;
}

function addArcherfishPattern(geometry) {
  const positions = geometry.getAttribute('position');
  const normals = geometry.getAttribute('normal');
  const colors = new Float32Array(positions.count * 3);
  const silver = new THREE.Color(0xb9c8c0);
  const pearl = new THREE.Color(0xe3ece3);
  const olive = new THREE.Color(0x788878);
  const band = new THREE.Color(0x263331);
  const sample = new THREE.Color();
  const bands = [
    [-0.34, 0.078],
    [-0.14, 0.065],
    [0.075, 0.056],
    [0.285, 0.048],
  ];

  for (let index = 0; index < positions.count; index += 1) {
    const x = positions.getX(index);
    const y = positions.getY(index);
    const z = positions.getZ(index);
    const dorsal = THREE.MathUtils.smoothstep(y, 0.02, 0.4);
    const belly = 1 - THREE.MathUtils.smoothstep(y, -0.34, -0.04);
    const upperBody = THREE.MathUtils.smoothstep(y, -0.12, 0.08);
    let bandMask = 0;
    bands.forEach(([center, width]) => {
      const distance = Math.abs(z - center);
      bandMask = Math.max(
        bandMask,
        THREE.MathUtils.smoothstep(width - distance, 0, width)
      );
    });
    const lateral = 0.18 + THREE.MathUtils.smoothstep(Math.abs(normals.getX(index)), 0.12, 0.72) * 0.82;
    bandMask *= upperBody * lateral;
    const scaleGrain = Math.sin(x * 19 + z * 23 + index * 0.41) * 0.012;
    const sideLight = Math.max(0, normals.getZ(index)) * 0.05;
    sample.copy(silver)
      .lerp(olive, dorsal * 0.48)
      .lerp(pearl, belly * 0.72)
      .lerp(band, bandMask * 0.94)
      .multiplyScalar(1 + scaleGrain + sideLight);
    colors[index * 3] = sample.r;
    colors[index * 3 + 1] = sample.g;
    colors[index * 3 + 2] = sample.b;
  }
  geometry.setAttribute('color', new THREE.BufferAttribute(colors, 3));
  return geometry;
}

function addDorsalVertexColors(geometry, baseColor, ridgeColor) {
  const positions = geometry.getAttribute('position');
  const normals = geometry.getAttribute('normal');
  const colors = new Float32Array(positions.count * 3);
  const base = new THREE.Color(baseColor);
  const ridge = new THREE.Color(ridgeColor);
  const sample = new THREE.Color();
  for (let index = 0; index < positions.count; index += 1) {
    const dorsal = THREE.MathUtils.smoothstep(normals.getY(index), 0.5, 0.94);
    const grain = 1 + Math.sin(index * 2.07 + positions.getZ(index) * 13) * 0.016;
    sample.copy(base).lerp(ridge, dorsal * 0.82).multiplyScalar(grain);
    colors[index * 3] = sample.r;
    colors[index * 3 + 1] = sample.g;
    colors[index * 3 + 2] = sample.b;
  }
  geometry.setAttribute('color', new THREE.BufferAttribute(colors, 3));
  return geometry;
}

function addGhostSharkSurfaceColors(geometry) {
  const positions = geometry.getAttribute('position');
  const normals = geometry.getAttribute('normal');
  const colors = new Float32Array(positions.count * 3);
  const shadow = new THREE.Color(0x4f7393);
  const pearl = new THREE.Color(0xa7d4dc);
  const spectral = new THREE.Color(0xd7f7ef);
  const sample = new THREE.Color();
  for (let index = 0; index < positions.count; index += 1) {
    const front = THREE.MathUtils.smoothstep(positions.getZ(index), -0.34, 0.34);
    const dorsal = THREE.MathUtils.smoothstep(normals.getY(index), 0.15, 0.9);
    const grain = 1 + Math.sin(index * 1.81 + positions.getY(index) * 15.7) * 0.014;
    sample.copy(shadow)
      .lerp(pearl, front * 0.72)
      .lerp(spectral, dorsal * 0.32)
      .multiplyScalar(grain);
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

function fanFinGeometry(side = 1, width = 0.28, length = 0.46, depth = 0.035) {
  const shape = new THREE.Shape();
  shape.moveTo(0, 0.04);
  shape.bezierCurveTo(
    side * width * 0.48, -length * 0.08,
    side * width, -length * 0.48,
    side * width * 0.82, -length * 0.78
  );
  shape.bezierCurveTo(
    side * width * 0.58, -length,
    side * width * 0.18, -length * 0.92,
    0, -length * 0.72
  );
  shape.closePath();
  const geometry = new THREE.ExtrudeGeometry(shape, {
    depth,
    bevelEnabled: true,
    bevelSegments: 2,
    bevelSize: depth * 0.35,
    bevelThickness: depth * 0.3,
    curveSegments: 8,
    steps: 1,
  });
  geometry.translate(0, 0, -depth * 0.5);
  geometry.rotateX(Math.PI / 2);
  geometry.computeVertexNormals();
  return geometry;
}

function archerfishBodyGeometry(longitudinalSegments = 36, radialSegments = 28) {
  const profiles = [
    { z: -0.58, y: 0.49, rx: 0.09, ry: 0.13 },
    { z: -0.42, y: 0.5, rx: 0.2, ry: 0.25 },
    { z: -0.12, y: 0.52, rx: 0.29, ry: 0.34 },
    { z: 0.2, y: 0.54, rx: 0.27, ry: 0.31 },
    { z: 0.45, y: 0.55, rx: 0.2, ry: 0.22 },
    { z: 0.62, y: 0.565, rx: 0.075, ry: 0.095 },
  ];
  const positions = [];
  const indices = [];

  function profileAt(z) {
    for (let index = 0; index < profiles.length - 1; index += 1) {
      const current = profiles[index];
      const next = profiles[index + 1];
      if (z > next.z) continue;
      const raw = (z - current.z) / (next.z - current.z);
      const t = raw * raw * (3 - 2 * raw);
      return {
        y: THREE.MathUtils.lerp(current.y, next.y, t),
        rx: THREE.MathUtils.lerp(current.rx, next.rx, t),
        ry: THREE.MathUtils.lerp(current.ry, next.ry, t),
      };
    }
    return profiles[profiles.length - 1];
  }

  for (let segment = 0; segment <= longitudinalSegments; segment += 1) {
    const z = THREE.MathUtils.lerp(profiles[0].z, profiles[profiles.length - 1].z,
      segment / longitudinalSegments);
    const profile = profileAt(z);
    for (let side = 0; side < radialSegments; side += 1) {
      const angle = side / radialSegments * Math.PI * 2;
      positions.push(
        Math.cos(angle) * profile.rx,
        profile.y + Math.sin(angle) * profile.ry,
        z
      );
    }
  }
  for (let segment = 0; segment < longitudinalSegments; segment += 1) {
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
  return geometry;
}

function archerfishTailFinGeometry(depth = 0.07) {
  const shape = new THREE.Shape();
  shape.moveTo(0, 0.08);
  shape.bezierCurveTo(0.16, 0.18, 0.31, 0.31, 0.43, 0.32);
  shape.bezierCurveTo(0.39, 0.17, 0.32, 0.06, 0.22, 0);
  shape.bezierCurveTo(0.32, -0.06, 0.39, -0.17, 0.43, -0.3);
  shape.bezierCurveTo(0.29, -0.28, 0.14, -0.16, 0, -0.08);
  shape.closePath();
  const geometry = new THREE.ExtrudeGeometry(shape, {
    depth,
    bevelEnabled: true,
    bevelSegments: 3,
    bevelSize: 0.012,
    bevelThickness: 0.01,
    curveSegments: 16,
    steps: 1,
  });
  geometry.translate(0, 0, -depth * 0.5);
  geometry.rotateY(Math.PI / 2);
  geometry.computeVertexNormals();
  return geometry;
}

function archerfishRearFinGeometry(depth = 0.055) {
  const shape = new THREE.Shape();
  shape.moveTo(-0.22, 0);
  shape.bezierCurveTo(-0.13, 0.12, -0.02, 0.25, 0.08, 0.29);
  shape.bezierCurveTo(0.16, 0.19, 0.2, 0.08, 0.22, 0);
  shape.closePath();
  const geometry = new THREE.ExtrudeGeometry(shape, {
    depth,
    bevelEnabled: true,
    bevelSegments: 2,
    bevelSize: 0.01,
    bevelThickness: 0.009,
    curveSegments: 12,
    steps: 1,
  });
  geometry.translate(0, 0, -depth * 0.5);
  geometry.rotateY(Math.PI / 2);
  geometry.computeVertexNormals();
  return geometry;
}

function rayWingGeometry(side = 1, depth = 0.045) {
  const shape = new THREE.Shape();
  shape.moveTo(0, 0.34);
  shape.bezierCurveTo(
    side * 0.26, 0.34,
    side * 0.62, 0.22,
    side * 0.72, 0.02
  );
  shape.bezierCurveTo(
    side * 0.62, -0.18,
    side * 0.3, -0.26,
    0, -0.18
  );
  shape.bezierCurveTo(side * 0.08, -0.02, side * 0.08, 0.18, 0, 0.34);
  shape.closePath();
  const geometry = new THREE.ExtrudeGeometry(shape, {
    depth,
    bevelEnabled: true,
    bevelSegments: 2,
    bevelSize: 0.014,
    bevelThickness: 0.012,
    curveSegments: 12,
    steps: 1,
  });
  geometry.translate(0, 0, -depth * 0.5);
  geometry.rotateX(Math.PI / 2);
  geometry.computeVertexNormals();
  return geometry;
}

function sharkDorsalFinGeometry(depth = 0.075) {
  const shape = new THREE.Shape();
  shape.moveTo(-0.14, 0);
  shape.bezierCurveTo(-0.07, 0.15, -0.025, 0.34, 0.015, 0.42);
  shape.bezierCurveTo(0.07, 0.31, 0.13, 0.13, 0.16, 0);
  shape.closePath();
  const geometry = new THREE.ExtrudeGeometry(shape, {
    depth,
    bevelEnabled: true,
    bevelSegments: 2,
    bevelSize: 0.012,
    bevelThickness: 0.01,
    curveSegments: 10,
    steps: 1,
  });
  geometry.translate(0, 0, -depth * 0.5);
  // Dorsal fin lies in the shark's depth/vertical plane; extrusion provides
  // only a small amount of width so the side view reads as a fin, not a post.
  geometry.rotateY(Math.PI / 2);
  geometry.computeVertexNormals();
  return geometry;
}

function sharkTailFinGeometry(depth = 0.07) {
  const shape = new THREE.Shape();
  shape.moveTo(0, 0.055);
  shape.bezierCurveTo(0.14, 0.15, 0.27, 0.34, 0.35, 0.38);
  shape.bezierCurveTo(0.32, 0.18, 0.27, 0.06, 0.21, 0);
  shape.bezierCurveTo(0.27, -0.06, 0.32, -0.2, 0.35, -0.31);
  shape.bezierCurveTo(0.22, -0.25, 0.09, -0.1, 0, -0.055);
  shape.closePath();
  const geometry = new THREE.ExtrudeGeometry(shape, {
    depth,
    bevelEnabled: true,
    bevelSegments: 2,
    bevelSize: 0.012,
    bevelThickness: 0.01,
    curveSegments: 12,
    steps: 1,
  });
  geometry.translate(0, 0, -depth * 0.5);
  // Shape x becomes model depth, shape y remains vertical, and extrusion
  // thickness becomes model width: a real vertical shark caudal fin.
  geometry.rotateY(Math.PI / 2);
  geometry.computeVertexNormals();
  return geometry;
}

function ghostSharkBodyGeometry(longitudinalSegments = 40, radialSegments = 28) {
  const profiles = [
    { z: -0.58, y: 0.55, rx: 0.095, ry: 0.085 },
    { z: -0.4, y: 0.55, rx: 0.25, ry: 0.18 },
    { z: -0.08, y: 0.55, rx: 0.36, ry: 0.235 },
    { z: 0.24, y: 0.54, rx: 0.32, ry: 0.215 },
    { z: 0.48, y: 0.525, rx: 0.22, ry: 0.145 },
    { z: 0.67, y: 0.5, rx: 0.055, ry: 0.05 },
  ];
  const positions = [];
  const indices = [];

  function profileAt(z) {
    for (let index = 0; index < profiles.length - 1; index += 1) {
      const current = profiles[index];
      const next = profiles[index + 1];
      if (z > next.z) continue;
      const raw = (z - current.z) / (next.z - current.z);
      const t = raw * raw * (3 - 2 * raw);
      return {
        y: THREE.MathUtils.lerp(current.y, next.y, t),
        rx: THREE.MathUtils.lerp(current.rx, next.rx, t),
        ry: THREE.MathUtils.lerp(current.ry, next.ry, t),
      };
    }
    return profiles[profiles.length - 1];
  }

  for (let segment = 0; segment <= longitudinalSegments; segment += 1) {
    const z = THREE.MathUtils.lerp(profiles[0].z, profiles[profiles.length - 1].z,
      segment / longitudinalSegments);
    const profile = profileAt(z);
    for (let side = 0; side < radialSegments; side += 1) {
      const angle = side / radialSegments * Math.PI * 2;
      const vertical = Math.sin(angle);
      positions.push(
        Math.cos(angle) * profile.rx,
        profile.y + vertical * profile.ry * (vertical < 0 ? 0.78 : 1),
        z
      );
    }
  }
  for (let segment = 0; segment < longitudinalSegments; segment += 1) {
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
  return geometry;
}

function sharkPectoralFinGeometry(side = 1, depth = 0.045) {
  const shape = new THREE.Shape();
  shape.moveTo(0, 0.075);
  shape.bezierCurveTo(side * 0.14, 0.005, side * 0.4, -0.2, side * 0.58, -0.46);
  shape.lineTo(side * 0.22, -0.27);
  shape.bezierCurveTo(side * 0.13, -0.22, side * 0.06, -0.14, 0, -0.075);
  shape.closePath();
  const geometry = new THREE.ExtrudeGeometry(shape, {
    depth,
    bevelEnabled: true,
    bevelSegments: 1,
    bevelSize: 0.006,
    bevelThickness: 0.006,
    curveSegments: 12,
    steps: 1,
  });
  geometry.translate(0, 0, -depth * 0.5);
  geometry.rotateX(Math.PI / 2);
  geometry.computeVertexNormals();
  return geometry;
}

function seaTurtleFlipperGeometry(side = 1, depth = 0.055) {
  const shape = new THREE.Shape();
  shape.moveTo(0, 0.14);
  shape.bezierCurveTo(
    side * 0.18, 0.18,
    side * 0.48, 0.08,
    side * 0.62, -0.08
  );
  shape.bezierCurveTo(
    side * 0.65, -0.2,
    side * 0.54, -0.31,
    side * 0.38, -0.34
  );
  shape.bezierCurveTo(
    side * 0.2, -0.28,
    side * 0.08, -0.14,
    0, -0.08
  );
  shape.closePath();
  const geometry = new THREE.ExtrudeGeometry(shape, {
    depth,
    bevelEnabled: true,
    bevelSegments: 2,
    bevelSize: 0.015,
    bevelThickness: 0.012,
    curveSegments: 12,
    steps: 1,
  });
  geometry.translate(0, 0, -depth * 0.5);
  geometry.rotateX(Math.PI / 2);
  geometry.computeVertexNormals();
  return geometry;
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
    roughness: 0.38,
    clearcoat: 0.08,
    clearcoatRoughness: 0.68,
    transmission: 0.34,
    thickness: 0.28,
    ior: 1.18,
    attenuationColor: 0x4abbd4,
    attenuationDistance: 1.35,
    transparent: false,
    opacity: 1,
    emissive: 0x164c67,
    emissiveIntensity: 0.2,
    depthWrite: true,
  });
  const rimMaterial = physical(0xb9f4ff, {
    roughness: 0.46,
    clearcoat: 0,
    emissive: 0x3bd8e8,
    emissiveIntensity: 0.62,
  });
  const tentacleMaterial = physical(0x72dce8, {
    roughness: 0.72,
    clearcoat: 0,
    emissive: 0x1a5963,
    emissiveIntensity: 0.2,
  });
  const innerMaterial = physical(0x8ce6ef, {
    roughness: 0.62,
    clearcoat: 0,
    transparent: true,
    opacity: 0.38,
    emissive: 0x276f7e,
    emissiveIntensity: 0.42,
    depthWrite: false,
  });
  const electricInternal = new THREE.MeshBasicMaterial({
    color: 0xbaffff,
    transparent: true,
    opacity: 0.92,
    depthWrite: false,
    toneMapped: false,
  });
  const electricCore = new THREE.MeshBasicMaterial({
    color: 0x78f5ff,
    transparent: false,
    toneMapped: false,
  });
  const dark = standard(0x10252e, { roughness: 0.38 });
  const glint = glow(0xf1ffff, 1.35);

  add(bell, new THREE.SphereGeometry(0.48, 40, 24, 0, Math.PI * 2, 0, Math.PI * 0.6),
    bellMaterial, [0, 0, 0], [1, 0.9, 0.92], 'JellyfishCandidateDome');
  add(bell, new THREE.SphereGeometry(0.415, 36, 22, 0, Math.PI * 2, 0, Math.PI * 0.58),
    innerMaterial, [0, -0.018, 0], [1, 0.78, 0.88], 'JellyfishCandidateInnerBell');
  const rim = add(bell, new THREE.TorusGeometry(0.39, 0.055, 14, 40),
    rimMaterial, [0, -0.025, 0], [1, 1, 0.92], 'JellyfishCandidateRim');
  rim.rotation.x = Math.PI / 2;
  const core = add(bell, new THREE.SphereGeometry(0.19, 28, 18), electricCore,
    [0, -0.015, 0], [1, 0.24, 0.86], 'JellyfishCandidateCore');
  [-0.095, 0, 0.095].forEach((x, index) => {
    add(bell, new THREE.SphereGeometry(0.073, 20, 14), innerMaterial,
      [x, 0.035 + Math.abs(x) * 0.25, 0.04], [0.78, 1.18, 0.72],
      `JellyfishCandidatePulseLobe${index + 1}`);
  });
  for (let index = 0; index < 6; index += 1) {
    const angle = index / 6 * Math.PI * 2;
    const radialX = Math.sin(angle);
    const radialZ = Math.cos(angle);
    const tangentX = Math.cos(angle);
    const tangentZ = -Math.sin(angle);
    const direction = index % 2 === 0 ? 1 : -1;
    const points = [0.16, 0.68, 1.16, 1.62].map((phi, pointIndex) => {
      const radius = Math.sin(phi) * 0.49;
      const tangentOffset = pointIndex === 1
        ? direction * 0.028
        : pointIndex === 2 ? direction * -0.02 : 0;
      return [
        radialX * radius + tangentX * tangentOffset,
        Math.cos(phi) * 0.49 * 0.9,
        radialZ * radius * 0.92 + tangentZ * tangentOffset,
      ];
    });
    const vein = tube(points, 0.012, electricInternal, 28, 8);
    vein.name = `JellyfishCandidateInnerVein${index + 1}`;
    vein.castShadow = false;
    vein.renderOrder = 3;
    bell.add(vein);

    const forkStart = points[2];
    const fork = tube([
      forkStart,
      [forkStart[0] + tangentX * direction * 0.07, forkStart[1] - 0.045,
        forkStart[2] + tangentZ * direction * 0.07],
      [forkStart[0] + tangentX * direction * 0.13, forkStart[1] - 0.1,
        forkStart[2] + tangentZ * direction * 0.13],
    ], 0.008, electricInternal, 16, 7);
    fork.name = `JellyfishCandidateElectricFork${index + 1}`;
    fork.castShadow = false;
    fork.renderOrder = 3;
    bell.add(fork);
  }
  for (let index = 0; index < 8; index += 1) {
    const angle = index / 8 * Math.PI * 2;
    add(bell, new THREE.SphereGeometry(0.055, 16, 10), rimMaterial,
      [Math.sin(angle) * 0.38, -0.035, Math.cos(angle) * 0.35],
      [1, 0.65, 0.85], `JellyfishCandidateRimLobe${index + 1}`);
  }
  addEye(bell, -0.14, 0.08, 0.405, 0.062, dark, glint, 'JellyfishCandidateLeft');
  addEye(bell, 0.14, 0.08, 0.405, 0.062, dark, glint, 'JellyfishCandidateRight');

  const tentacles = [];
  // Six tapered tentacles start inside the underside of the bell and arc
  // radially outward. Their horizontal spread is intentional: a mostly
  // vertical bundle disappears behind the bell in the elevated game camera.
  for (let index = 0; index < 6; index += 1) {
    const angle = index / 6 * Math.PI * 2 + Math.PI / 6;
    const radialX = Math.sin(angle);
    const radialZ = Math.cos(angle);
    const tangentX = Math.cos(angle);
    const tangentZ = -Math.sin(angle);
    const sway = index % 2 === 0 ? 0.075 : -0.075;
    const tentacle = pivot(rig, `JellyfishTentacle${index + 1}`, [
      radialX * 0.3,
      0.62,
      radialZ * 0.27,
    ]);
    const mesh = taperedTube([
      [0, 0, 0],
      [radialX * 0.1, -0.15, radialZ * 0.1],
      [radialX * 0.21 + tangentX * sway, -0.36, radialZ * 0.21 + tangentZ * sway],
      [radialX * 0.35 - tangentX * sway * 0.45, -0.62 - (index % 3) * 0.045,
        radialZ * 0.35 - tangentZ * sway * 0.45],
    ], 0.052, 0.024, tentacleMaterial, 38, 12);
    mesh.name = `JellyfishCandidateTentacleMesh${index + 1}`;
    mesh.castShadow = true;
    mesh.receiveShadow = true;
    tentacle.add(mesh);
    tentacles.push(tentacle);
  }
  [-0.1, 0.1].forEach((x, index) => {
    const oralArm = tube([
      [x, 0.61, 0.02],
      [x * 0.45, 0.39, index === 0 ? 0.08 : -0.08],
      [-x * 0.35, 0.17, index === 0 ? -0.04 : 0.04],
    ], 0.066, innerMaterial, 30, 12);
    oralArm.name = `JellyfishCandidateOralArm${index + 1}`;
    oralArm.castShadow = true;
    rig.add(oralArm);
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
      const electricPulse = 0.5 + Math.sin(time * 5.6) * 0.5;
      rig.position.y = 0.1 + Math.sin(time * 1.7) * 0.045;
      bell.scale.set(1 + pulse * 0.035, 1 - pulse * 0.055, 1 + pulse * 0.035);
      core.scale.set(1 + electricPulse * 0.08, 0.24 + electricPulse * 0.035, 0.86 + electricPulse * 0.06);
      electricInternal.opacity = 0.66 + electricPulse * 0.3;
      rimMaterial.emissiveIntensity = 0.48 + electricPulse * 0.32;
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
          tentacle.rotation.z += shock * (index - (tentacles.length - 1) * 0.5) * 0.08;
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
    roughness: 0.7,
    metalness: 0.52,
    clearcoat: 0,
  });
  const ironPlate = physical(0x91a1a0, {
    roughness: 0.48,
    metalness: 0.68,
    clearcoat: 0,
  });
  const ironPlatePaint = physical(0xffffff, {
    roughness: 0.5,
    metalness: 0.66,
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

  // The load-bearing shell stays deliberately low. It is only the dark base
  // beneath the armor, not a tall smooth turtle dome competing with the steel
  // plates for the silhouette.
  add(shell, new THREE.SphereGeometry(0.56, 44, 28), ironDark,
    [0, 0.39, -0.05], [1.1, 0.28, 0.97], 'IronTurtleCandidateShellUnderlay');
  const shellGeometry = addVertexColorVariation(
    new THREE.SphereGeometry(0.515, 48, 30), 0x667a7b, 0.06, 3
  );
  const shellMaterial = physical(0xffffff, {
    roughness: 0.58,
    metalness: 0.62,
    clearcoat: 0,
    vertexColors: true,
  });
  add(shell, shellGeometry, shellMaterial,
    [0, 0.455, -0.05], [1.06, 0.44, 0.93], 'IronTurtleCandidateShell');

  const shellRim = add(shell, new THREE.TorusGeometry(0.49, 0.062, 14, 56), edge,
    [0, 0.405, -0.05], [1.1, 1, 0.93], 'IronTurtleCandidateShellRim');
  shellRim.rotation.x = Math.PI / 2;

  const plateSpecs = [
    [0, 0.685, -0.04, 0.235, 0],
    [-0.255, 0.65, 0.02, 0.205, 1],
    [0.255, 0.65, 0.02, 0.205, 2],
    [0, 0.625, 0.265, 0.205, 3],
    [0, 0.645, -0.31, 0.2, 4],
    [-0.31, 0.615, -0.2, 0.17, 5],
    [0.31, 0.615, -0.2, 0.17, 6],
  ];
  const shellUp = new THREE.Vector3(0, 1, 0);
  plateSpecs.forEach(([x, y, z, radius, seed], index) => {
    const plateMount = pivot(shell, `IronTurtleCandidatePlateMount${index + 1}`, [x, y, z]);
    const normal = new THREE.Vector3(x, 1, (z + 0.05) * 0.9).normalize();
    plateMount.quaternion.setFromUnitVectors(shellUp, normal);
    add(plateMount, new THREE.CylinderGeometry(radius * 1.06, radius * 1.1, 0.034, 6), groove,
      [0, 0, 0], [1, 1, 0.94], `IronTurtleCandidatePlateGroove${index + 1}`);
    const plateGeometry = addVertexColorVariation(
      new THREE.CylinderGeometry(radius * 0.94, radius, 0.074, 6, 2, false),
      index === 0 ? 0x98a5a5 : 0x7e8d8e,
      0.045,
      seed + 6
    );
    add(plateMount, plateGeometry, ironPlatePaint,
      [0, 0.046, 0], [1, 1, 0.94], `IronTurtleCandidatePlate${index + 1}`);
  });

  // Eight broad skirt plates overlap the dark rim, turning the shell edge
  // into articulated armor instead of a continuous tire-like ring.
  Array.from({ length: 8 }, (_, index) => index / 8 * Math.PI * 2).forEach((angle, index) => {
    const x = Math.sin(angle) * 0.49 * 1.12;
    const z = -0.05 + Math.cos(angle) * 0.49 * 1.02;
    const guardMount = pivot(shell, `IronTurtleCandidateRimGuardMount${index + 1}`, [x, 0.415, z]);
    const outward = new THREE.Vector3(Math.sin(angle), 0.34, Math.cos(angle)).normalize();
    guardMount.quaternion.setFromUnitVectors(shellUp, outward);
    add(guardMount, new THREE.CylinderGeometry(0.105, 0.118, 0.058, 6), edge,
      [0, 0.028, 0], [1.06, 1, 0.8], `IronTurtleCandidateRimGuard${index + 1}`);
    add(guardMount, new THREE.SphereGeometry(0.025, 14, 10), ironPlate,
      [0, 0.066, 0], [1, 0.68, 1], `IronTurtleCandidateRivet${index + 1}`);
  });

  // Two shallow scratches and a rust bloom keep the armor from reading as a
  // perfectly molded toy. They are deliberately oversized for game view.
  const scratchOne = add(shell, new THREE.BoxGeometry(0.014, 0.018, 0.16), groove,
    [-0.08, 0.77, -0.045], [1, 1, 1], 'IronTurtleCandidateScratch1');
  scratchOne.rotation.y = -0.58;
  scratchOne.rotation.z = 0.08;
  const scratchTwo = add(shell, new THREE.BoxGeometry(0.011, 0.018, 0.11), groove,
    [-0.015, 0.773, -0.02], [1, 1, 1], 'IronTurtleCandidateScratch2');
  scratchTwo.rotation.y = -0.58;
  scratchTwo.rotation.z = 0.08;
  const rustPatch = add(shell, new THREE.SphereGeometry(0.07, 18, 12), rust,
    [0.37, 0.65, -0.1], [1, 0.12, 0.58], 'IronTurtleCandidateRustPatch');
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
  const tail = pivot(rig, 'ArcherfishTail', [0, 0.49, -0.56]);
  const leftFin = pivot(rig, 'ArcherfishFinLeft', [-0.17, 0.5, 0.22]);
  const rightFin = pivot(rig, 'ArcherfishFinRight', [0.17, 0.5, 0.22]);

  const silver = standard(0xffffff, { roughness: 0.7, vertexColors: true });
  const pale = standard(0xdce7df, { roughness: 0.76 });
  const fin = standard(0x7d927f, { roughness: 0.82 });
  const tailFinMaterial = standard(0x536d63, { roughness: 0.84 });
  const stripe = standard(0x263331, { roughness: 0.84 });
  const dark = standard(0x142021, { roughness: 0.38 });
  const glint = glow(0xf8fff5, 1.3);

  const archerBodyGeometry = addArcherfishPattern(archerfishBodyGeometry());
  add(body, archerBodyGeometry, silver,
    [0, 0, 0], [1, 1, 1], 'ArcherfishCandidateBody');

  const mouthRing = add(body, new THREE.TorusGeometry(0.054, 0.012, 12, 30), pale,
    [0, 0.565, 0.645], [0.86, 0.52, 0.8], 'ArcherfishCandidateMouthRing');
  mouthRing.rotation.x = -0.18;
  const mouthAperture = add(body, new THREE.CircleGeometry(0.038, 24), dark,
    [0, 0.565, 0.66], [0.86, 0.5, 1], 'ArcherfishCandidateMouthAperture');
  mouthAperture.rotation.x = -0.18;
  addEye(body, -0.145, 0.645, 0.49, 0.056, dark, glint, 'ArcherfishCandidateLeft');
  addEye(body, 0.145, 0.645, 0.49, 0.056, dark, glint, 'ArcherfishCandidateRight');

  add(body, archerfishRearFinGeometry(), fin,
    [0, 0.785, -0.25], [1, 1, 1], 'ArcherfishCandidateDorsalFin');
  add(body, archerfishRearFinGeometry(), fin,
    [0, 0.285, -0.25], [1, -0.78, 0.9], 'ArcherfishCandidateAnalFin');
  add(leftFin, fanFinGeometry(-1, 0.16, 0.23, 0.03), fin,
    [0, 0, 0.04], [1, 1, 1], 'ArcherfishCandidateLeftFinMesh');
  add(rightFin, fanFinGeometry(1, 0.16, 0.23, 0.03), fin,
    [0, 0, 0.04], [1, 1, 1], 'ArcherfishCandidateRightFinMesh');

  const tailStem = taperedTube([
    [0, 0, 0.08],
    [0, 0, -0.08],
    [0, 0, -0.22],
  ], 0.115, 0.075, fin, 28, 14);
  tailStem.name = 'ArcherfishCandidateTailStem';
  tail.add(tailStem);
  add(tail, archerfishTailFinGeometry(0.12), tailFinMaterial,
    [0, 0, -0.18], [1, 0.82, 0.82], 'ArcherfishCandidateTailFin');
  [-1, 1].forEach(side => {
    const gill = tube([
      [side * 0.165, 0.62, 0.37],
      [side * 0.18, 0.55, 0.39],
      [side * 0.17, 0.47, 0.36],
    ], 0.007, stripe, 18, 6);
    gill.name = `ArcherfishCandidateGill${side < 0 ? 'Left' : 'Right'}`;
    body.add(gill);
  });
  return finishCandidate({
    group,
    rig,
    healthColor: 0x7f9f91,
    scale: 0.92,
    shadow: [0.42, 0.52, 0.2],
    nodes: [body, tail, leftFin, rightFin],
    idle: time => {
      rig.position.y = 0.04 + Math.sin(time * 1.9) * 0.025;
      // Hold the caudal fin in a slight swimming bend so its vertical plane
      // remains legible from the elevated head-on game camera.
      tail.rotation.y = 0.22 + Math.sin(time * 3.1) * 0.12;
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
        body.position.z -= shot * 0.09;
        mouthRing.scale.set(0.86 + shot * 0.1, 0.52 + shot * 0.08, 0.8 + shot * 0.06);
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

  const blue = physical(0x416bbb, { roughness: 0.68, clearcoat: 0.04, clearcoatRoughness: 0.82 });
  const cyan = physical(0x59c7ca, {
    roughness: 0.64,
    clearcoat: 0,
    emissive: 0x14545b,
    emissiveIntensity: 0.28,
  });
  const belly = standard(0x9cdadd, { roughness: 0.7 });
  const eelBodyMaterial = physical(0xffffff, {
    roughness: 0.68,
    clearcoat: 0.04,
    clearcoatRoughness: 0.82,
    vertexColors: true,
  });
  const dark = standard(0x101b2d, { roughness: 0.4 });
  const glint = glow(0xeaffff, 1.4);
  const vortexGlow = new THREE.MeshBasicMaterial({
    color: 0x75edf0,
    transparent: true,
    opacity: 0.58,
    depthWrite: false,
    toneMapped: false,
  });

  const bodyMesh = taperedTube([
    [0.08, 0.55, 0.35],
    [-0.22, 0.5, 0.08],
    [0.2, 0.48, -0.28],
    [-0.18, 0.46, -0.62],
    [-0.06, 0.45, -0.92],
  ], 0.215, 0.07, blue, 64, 18);
  addDorsalVertexColors(bodyMesh.geometry, 0x416bbb, 0x59c7ca);
  bodyMesh.material = eelBodyMaterial;
  bodyMesh.name = 'VortexEelCandidateBodyMesh';
  bodyMesh.castShadow = true;
  body.add(bodyMesh);

  add(head, new THREE.SphereGeometry(0.28, 32, 22), blue,
    [0, 0, 0], [0.9, 0.72, 1.18], 'VortexEelCandidateHeadMesh');
  add(head, new THREE.SphereGeometry(0.2, 26, 18), belly,
    [0, -0.06, 0.18], [0.78, 0.5, 0.32], 'VortexEelCandidateMuzzle');
  addEye(head, -0.1, 0.06, 0.23, 0.052, dark, glint, 'VortexEelCandidateLeft');
  addEye(head, 0.1, 0.06, 0.23, 0.052, dark, glint, 'VortexEelCandidateRight');
  const eelMouth = tube([
    [-0.085, -0.1, 0.275], [0, -0.12, 0.294], [0.085, -0.1, 0.275],
  ], 0.008, dark, 18, 6);
  eelMouth.name = 'VortexEelCandidateMouth';
  head.add(eelMouth);
  [-1, 1].forEach(side => {
    for (let index = 0; index < 2; index += 1) {
      const gill = add(head, new THREE.BoxGeometry(0.008, 0.07, 0.012), dark,
        [side * (0.19 + index * 0.018), -0.02 - index * 0.045, 0.17],
        [1, 1, 1], `VortexEelCandidateGill${side < 0 ? 'L' : 'R'}${index + 1}`);
      gill.rotation.z = side * -0.16;
    }
  });

  [-1, 1].forEach(side => {
    add(tail, fanFinGeometry(side, 0.19, 0.34, 0.03), cyan,
      [0, 0, -0.04], [1, 1, 1], `VortexEelTailFin${side < 0 ? 'L' : 'R'}`);
  });
  [
    [0.02, 0.73, 0.2], [-0.12, 0.68, -0.02], [0.13, 0.66, -0.27],
    [-0.1, 0.62, -0.5], [0, 0.58, -0.72],
  ].forEach(([x, y, z], index) => {
    const spine = add(body, new THREE.ConeGeometry(0.04, 0.16, 10), cyan,
      [x, y, z], [1, 1, 0.72], `VortexEelCandidateDorsalSpine${index + 1}`);
    spine.rotation.x = -0.12;
  });
  [0.12, 0.19].forEach((radius, index) => {
    const ring = add(tail, new THREE.TorusGeometry(radius, 0.018, 8, 32), vortexGlow,
      [0, 0, -0.2 - index * 0.09], [1, 0.72, 1], `VortexEelCandidateVortexRing${index + 1}`);
    ring.rotation.z = index === 0 ? 0.22 : -0.18;
  });

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
  // The tail joint sits inside the rear edge of the body. Rotating around a
  // pivot outside the torso previously opened a visible gap between both
  // forms, making the tail look like a floating accessory.
  const tail = pivot(rig, 'ElectricRayTail', [0, 0.49, -0.4]);

  const purple = physical(0x7258b8, {
    roughness: 0.86,
    clearcoat: 0,
    sheen: 0.28,
    sheenColor: 0xa998cc,
    sheenRoughness: 0.92,
  });
  const purpleDark = standard(0x493b72, { roughness: 0.86 });
  const underside = standard(0xcbbfd6, { roughness: 0.9 });
  const electric = glow(0xffe96a, 1.45);
  const electricLine = new THREE.LineBasicMaterial({
    color: new THREE.Color(0xffe96a).multiplyScalar(1.35),
    transparent: true,
    opacity: 0.9,
    toneMapped: false,
  });
  const dark = standard(0x17152a, { roughness: 0.38 });
  const glint = glow(0xfaffdf, 1.35);

  add(body, new THREE.SphereGeometry(0.43, 36, 24), purple,
    [0, 0, 0.08], [0.8, 0.32, 1.15], 'ElectricRayCandidateBody');
  add(body, new THREE.SphereGeometry(0.35, 30, 20), underside,
    [0, -0.1, 0.1], [0.72, 0.18, 0.88], 'ElectricRayCandidateUnderside');

  add(leftWing, rayWingGeometry(-1), purple,
    [0.02, 0, 0], [1, 1, 1], 'ElectricRayCandidateLeftWingMesh');
  add(rightWing, rayWingGeometry(1), purple,
    [-0.02, 0, 0], [1, 1, 1], 'ElectricRayCandidateRightWingMesh');

  addEye(body, -0.14, 0.105, 0.34, 0.044, dark, glint, 'ElectricRayCandidateLeft');
  addEye(body, 0.14, 0.105, 0.34, 0.044, dark, glint, 'ElectricRayCandidateRight');
  [-1, 1].forEach(side => {
    const parent = side < 0 ? leftWing : rightWing;
    const branches = [
      [[0, 0.045, 0.22], [side * 0.22, 0.052, 0.14], [side * 0.47, 0.045, 0.02], [side * 0.62, 0.038, -0.08]],
      [[side * 0.17, 0.047, 0.12], [side * 0.3, 0.052, 0.24], [side * 0.45, 0.045, 0.28]],
      [[side * 0.31, 0.047, 0.04], [side * 0.42, 0.052, -0.08], [side * 0.52, 0.043, -0.17]],
    ];
    branches.forEach((points, index) => {
      const geometry = new THREE.BufferGeometry().setFromPoints(
        points.map(([x, y, z]) => new THREE.Vector3(x, y, z))
      );
      const vein = new THREE.Line(geometry, electricLine);
      vein.name = `ElectricRayCandidateElectricVein${side < 0 ? 'L' : 'R'}${index + 1}`;
      parent.add(vein);
    });
  });
  [-1, 1].forEach(side => {
    add(body, new THREE.SphereGeometry(0.024, 14, 10), dark,
      [side * 0.11, 0.09, 0.02], [1, 0.38, 1.3], `ElectricRayCandidateSpiracle${side < 0 ? 'Left' : 'Right'}`);
    for (let index = 0; index < 3; index += 1) {
      const gill = add(body, new THREE.BoxGeometry(0.055, 0.008, 0.012), purpleDark,
        [side * (0.09 + index * 0.045), -0.12, 0.18 - index * 0.04],
        [1, 1, 1], `ElectricRayCandidateGill${side < 0 ? 'L' : 'R'}${index + 1}`);
      gill.rotation.y = side * 0.18;
    }
  });

  const tailStem = taperedTube([
    [0, 0, 0.12],
    [0, 0.004, -0.12],
    [0.018, -0.008, -0.48],
    [0, 0.004, -0.84],
  ], 0.078, 0.026, purple, 52, 16);
  tailStem.name = 'ElectricRayCandidateTailStem';
  tailStem.castShadow = true;
  tailStem.receiveShadow = true;
  tail.add(tailStem);
  const barb = add(tail, new THREE.ConeGeometry(0.09, 0.24, 18), electric,
    [0, 0, -0.91], [0.72, 1, 0.34], 'ElectricRayCandidateTailBarb');
  barb.rotation.x = -Math.PI / 2;
  [0.22, 0.44, 0.66].forEach((z, index) => {
    const band = add(tail, new THREE.TorusGeometry(0.052 - index * 0.006, 0.012, 8, 22), electric,
      [0, 0, -z], [1, 1, 0.72], `ElectricRayCandidateTailBand${index + 1}`);
    band.rotation.x = Math.PI / 2;
  });

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

  const shellMaterial = standard(0xffffff, { roughness: 0.96, vertexColors: true });
  const shellDark = standard(0x875634, { roughness: 0.94 });
  const orange = physical(0xc86137, { roughness: 0.74, clearcoat: 0.03, clearcoatRoughness: 0.84 });
  const orangeLight = physical(0xe77f46, { roughness: 0.68, clearcoat: 0.04, clearcoatRoughness: 0.8 });
  const cream = standard(0xe4bd79, { roughness: 0.86 });
  const dark = standard(0x21130d, { roughness: 0.4 });
  const glint = glow(0xfffae9, 1.3);

  const hermitShellGeometry = addVertexColorVariation(
    new THREE.SphereGeometry(0.48, 44, 30), 0xc58b50, 0.1, 12
  );
  add(shell, hermitShellGeometry, shellMaterial,
    [0, 0.58, -0.2], [0.92, 1.02, 0.84], 'HermitCrabCandidateShell');
  add(shell, new THREE.SphereGeometry(0.39, 30, 20), shellDark,
    [0, 0.6, -0.24], [0.86, 0.9, 0.77], 'HermitCrabCandidateShellInset');

  const spiralPoints = [];
  const shellCenter = new THREE.Vector3(0, 0.58, -0.2);
  const shellRadii = new THREE.Vector3(0.48 * 0.92, 0.48 * 1.02, 0.48 * 0.84);
  const sideDirection = new THREE.Vector3(0.72, 0.06, 0.69).normalize();
  const spiralCenter = shellCenter.clone().add(new THREE.Vector3(
    sideDirection.x * shellRadii.x,
    sideDirection.y * shellRadii.y,
    sideDirection.z * shellRadii.z
  ));
  const horizontalTangent = new THREE.Vector3(sideDirection.z, 0, -sideDirection.x).normalize();
  const verticalTangent = new THREE.Vector3(0, 1, 0);
  for (let index = 0; index < 28; index += 1) {
    const t = index / 27;
    const angle = t * Math.PI * 4.2;
    const radius = 0.17 * (1 - t * 0.78);
    const rawPoint = spiralCenter.clone()
      .addScaledVector(horizontalTangent, Math.sin(angle) * radius)
      .addScaledVector(verticalTangent, Math.cos(angle) * radius);
    // Project every point back to the ellipsoid surface so the groove follows
    // the shell instead of becoming a flat coil hovering in front of it.
    const normalized = new THREE.Vector3(
      (rawPoint.x - shellCenter.x) / shellRadii.x,
      (rawPoint.y - shellCenter.y) / shellRadii.y,
      (rawPoint.z - shellCenter.z) / shellRadii.z
    ).normalize().multiplyScalar(1.008);
    spiralPoints.push([
      shellCenter.x + normalized.x * shellRadii.x,
      shellCenter.y + normalized.y * shellRadii.y,
      shellCenter.z + normalized.z * shellRadii.z,
    ]);
  }
  const spiral = tube(spiralPoints, 0.009, shellDark, 48, 7);
  spiral.name = 'HermitCrabCandidateShellSpiral';
  spiral.castShadow = true;
  shell.add(spiral);
  const opening = add(shell, new THREE.SphereGeometry(0.25, 30, 20), dark,
    [0, 0.34, 0.12], [0.92, 0.58, 0.22], 'HermitCrabCandidateShellOpening');
  const openingRim = add(shell, new THREE.TorusGeometry(0.22, 0.038, 12, 38), shellDark,
    [0, 0.35, 0.155], [1, 0.72, 1], 'HermitCrabCandidateShellOpeningRim');
  [
    [-0.22, 0.82, 0.045, 0.065], [0.13, 0.91, 0.015, 0.052],
    [0.28, 0.7, 0.065, 0.045], [-0.31, 0.59, 0.04, 0.04],
    [0.02, 0.76, 0.18, 0.038],
  ].forEach(([x, y, z, radius], index) => {
    const barnacle = add(shell, new THREE.CylinderGeometry(radius * 0.6, radius, radius * 0.82, 9), cream,
      [x, y, z], [1, 1, 0.82], `HermitCrabCandidateBarnacle${index + 1}`);
    barnacle.rotation.x = Math.PI * 0.5 - 0.18;
    barnacle.rotation.z = x * -0.45;
  });

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
    const clawScale = index === 0 ? 0.82 : 1.28;
    claw.scale.setScalar(clawScale);
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
    const knuckle = add(claw, new THREE.TorusGeometry(0.13, 0.026, 10, 28), cream,
      [side * -0.015, 0.015, -0.07], [1, 1, 0.82], `HermitCrabClawKnuckle${index + 1}`);
    knuckle.rotation.x = Math.PI / 2;
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
  const leftFin = pivot(rig, 'GhostSharkFinLeft', [-0.29, 0.52, 0.12]);
  const rightFin = pivot(rig, 'GhostSharkFinRight', [0.29, 0.52, 0.12]);
  const tail = pivot(rig, 'GhostSharkTail', [0, 0.55, -0.55]);

  // The body remains opaque for a stable mobile-game shark silhouette.
  // Spectral character comes from the pearlescent gradient, aura and tail.
  const ghost = physical(0xffffff, {
    roughness: 0.7,
    clearcoat: 0,
    transparent: false,
    opacity: 1,
    emissive: 0x285b72,
    emissiveIntensity: 0.42,
    depthWrite: true,
    vertexColors: true,
  });
  const finMaterial = physical(0x83b4c2, {
    roughness: 0.74,
    clearcoat: 0,
    transparent: false,
    opacity: 1,
    emissive: 0x28566a,
    emissiveIntensity: 0.38,
    depthWrite: true,
  });
  const spectralTrail = new THREE.MeshBasicMaterial({
    color: 0x8cecf1,
    transparent: true,
    opacity: 0.4,
    depthWrite: false,
    blending: THREE.AdditiveBlending,
    toneMapped: false,
  });
  const auraMaterial = new THREE.MeshBasicMaterial({
    color: 0x7ce7ee,
    side: THREE.BackSide,
    transparent: true,
    opacity: 0.2,
    depthWrite: false,
    blending: THREE.AdditiveBlending,
    toneMapped: false,
  });
  const dark = standard(0x07101b, { roughness: 0.32 });
  const eyeGlow = glow(0xbaffff, 1.75);

  const bodyGeometry = addGhostSharkSurfaceColors(ghostSharkBodyGeometry());
  add(body, bodyGeometry, ghost,
    [0, 0, 0], [1, 1, 1], 'GhostSharkCandidateBody');
  const aura = add(body, bodyGeometry.clone(), auraMaterial,
    [0, 0, 0], [1.045, 1.065, 1.035], 'GhostSharkCandidateAura');
  aura.castShadow = false;
  aura.receiveShadow = false;
  [-1, 1].forEach(side => {
    const sideName = side < 0 ? 'Left' : 'Right';
    add(body, new THREE.SphereGeometry(0.058, 24, 16), dark,
      [side * 0.225, 0.61, 0.42], [0.38, 1, 0.82],
      `GhostSharkCandidate${sideName}Eye`);
    const reflectedCore = add(body, new THREE.SphereGeometry(0.019, 14, 10), eyeGlow,
      [side * 0.244, 0.62, 0.435], [0.3, 0.8, 0.65],
      `GhostSharkCandidate${sideName}Glint`);
    reflectedCore.castShadow = false;
  });
  const sharkMouth = tube([
    [-0.14, 0.455, 0.615], [0, 0.43, 0.665], [0.14, 0.455, 0.615],
  ], 0.011, dark, 24, 7);
  sharkMouth.name = 'GhostSharkCandidateMouth';
  body.add(sharkMouth);

  [-1, 1].forEach(side => {
    const sideName = side < 0 ? 'L' : 'R';
    for (let index = 0; index < 3; index += 1) {
      const gill = add(body, new THREE.BoxGeometry(0.01, 0.115, 0.016), dark,
        [side * (0.32 - index * 0.012), 0.53, 0.12 - index * 0.075],
        [1, 1, 1], `GhostSharkCandidateGill${sideName}${index + 1}`);
      gill.rotation.z = side * (0.18 + index * 0.025);
    }
  });
  add(body, sharkDorsalFinGeometry(), finMaterial,
    [0, 0.73, -0.12], [1, 0.92, 1], 'GhostSharkCandidateDorsalFinMesh');

  add(leftFin, sharkPectoralFinGeometry(-1), finMaterial,
    [0.02, 0, 0.08], [1, 1, 1], 'GhostSharkCandidateLeftFinMesh');
  add(rightFin, sharkPectoralFinGeometry(1), finMaterial,
    [-0.02, 0, 0.08], [1, 1, 1], 'GhostSharkCandidateRightFinMesh');

  const tailStem = taperedTube([
    [0, 0, 0.08],
    [0, 0, -0.1],
    [0.018, -0.006, -0.28],
  ], 0.12, 0.065, finMaterial, 36, 16);
  tailStem.name = 'GhostSharkCandidateTailStem';
  tail.add(tailStem);
  const tailVeil = add(tail, sharkTailFinGeometry(0.09), spectralTrail,
    [0, 0, -0.24], [1, 0.88, 1], 'GhostSharkCandidateTailFinMesh');
  tailVeil.castShadow = false;
  tailVeil.receiveShadow = false;
  [-0.14, 0, 0.14].forEach((x, index) => {
    const wisp = tube([
      [x * 0.12, 0, -0.5],
      [x * 0.42, 0.02 + index * 0.008, -0.61],
      [-x * 0.26, -0.006, -0.72 - index * 0.025],
    ], 0.022 - index * 0.0025, spectralTrail, 32, 8);
    wisp.name = `GhostSharkCandidateWisp${index + 1}`;
    wisp.castShadow = false;
    tail.add(wisp);
  });

  return finishCandidate({
    group,
    rig,
    healthColor: 0x7089b9,
    scale: 0.94,
    shadow: [0.5, 0.62, 0.14],
    nodes: [body, leftFin, rightFin, tail],
    idle: time => {
      rig.position.y = 0.1 + Math.sin(time * 1.35) * 0.045;
      rig.rotation.z = Math.sin(time * 1.05) * 0.022;
      tail.rotation.y = Math.sin(time * 2.25) * 0.2;
      leftFin.rotation.z = -0.06 + Math.sin(time * 1.7) * 0.1;
      rightFin.rotation.z = 0.06 - Math.sin(time * 1.7) * 0.1;
      auraMaterial.opacity = 0.17 + (Math.sin(time * 1.8) + 1) * 0.025;
      spectralTrail.opacity = 0.35 + (Math.sin(time * 1.5 + 0.8) + 1) * 0.035;
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

function createArmoredSeaTurtleCandidate() {
  const group = new THREE.Group();
  group.name = 'IronTurtleCandidate';
  const rig = pivot(group, 'IronTurtleCandidateRig');
  const shell = pivot(rig, 'IronTurtleShell');
  const head = pivot(rig, 'IronTurtleHead', [0, 0.42, 0.59]);
  const frontLeft = pivot(rig, 'IronTurtleFrontFlipperLeft', [-0.38, 0.36, 0.24]);
  const frontRight = pivot(rig, 'IronTurtleFrontFlipperRight', [0.38, 0.36, 0.24]);
  const rearLeft = pivot(rig, 'IronTurtleRearFlipperLeft', [-0.39, 0.33, -0.3]);
  const rearRight = pivot(rig, 'IronTurtleRearFlipperRight', [0.39, 0.33, -0.3]);

  const ironDark = physical(0x354d55, {
    roughness: 0.76,
    metalness: 0.5,
    clearcoat: 0,
  });
  const shellPaint = physical(0xffffff, {
    roughness: 0.58,
    metalness: 0.63,
    clearcoat: 0,
    vertexColors: true,
  });
  const platePaint = physical(0xffffff, {
    roughness: 0.52,
    metalness: 0.68,
    clearcoat: 0,
    vertexColors: true,
  });
  const edge = physical(0x718b90, { roughness: 0.66, metalness: 0.48, clearcoat: 0 });
  const groove = standard(0x22363d, { roughness: 0.94, metalness: 0.24 });
  const rust = standard(0x6f5343, { roughness: 0.97 });
  const skin = standard(0x4f8c83, { roughness: 0.86 });
  const skinLight = standard(0x82b1a0, { roughness: 0.9 });
  const bodyPaint = standard(0xffffff, { roughness: 0.88, vertexColors: true });
  const dark = standard(0x101a1d, { roughness: 0.42 });
  const glint = glow(0xe9fff3, 1.25);

  const bodyGeometry = addVertexColorVariation(
    new THREE.SphereGeometry(0.5, 42, 28), 0x4f8c83, 0.045, 21
  );
  add(rig, bodyGeometry, bodyPaint,
    [0, 0.36, 0.01], [1.03, 0.36, 1.12], 'IronTurtleCandidateBody');

  // A sea turtle carapace is a low hydrodynamic oval. The steel shell keeps
  // the defensive role, but never rises into a land-tortoise backpack.
  add(shell, new THREE.SphereGeometry(0.54, 46, 30), ironDark,
    [0, 0.46, -0.02], [1.15, 0.24, 1.25], 'IronTurtleCandidateShellUnderlay');
  const shellGeometry = addVertexColorVariation(
    new THREE.SphereGeometry(0.52, 50, 32), 0x607b80, 0.055, 23
  );
  add(shell, shellGeometry, shellPaint,
    [0, 0.5, -0.02], [1.12, 0.28, 1.22], 'IronTurtleCandidateShell');
  const shellRim = add(shell, new THREE.TorusGeometry(0.5, 0.052, 14, 56), edge,
    [0, 0.47, -0.02], [1.08, 1.18, 0.86], 'IronTurtleCandidateShellRim');
  shellRim.rotation.x = Math.PI / 2;

  const plateSpecs = [
    [0, 0.675, 0.2, 0.17, 0],
    [0, 0.69, -0.06, 0.19, 1],
    [0, 0.655, -0.32, 0.15, 2],
    [-0.255, 0.64, 0.12, 0.145, 3],
    [0.255, 0.64, 0.12, 0.145, 4],
    [-0.275, 0.615, -0.19, 0.135, 5],
    [0.275, 0.615, -0.19, 0.135, 6],
  ];
  const shellUp = new THREE.Vector3(0, 1, 0);
  plateSpecs.forEach(([x, y, z, radius, seed], index) => {
    const mount = pivot(shell, `IronTurtleCandidatePlateMount${index + 1}`, [x, y, z]);
    const normal = new THREE.Vector3(x * 0.8, 1, (z + 0.02) * 0.72).normalize();
    mount.quaternion.setFromUnitVectors(shellUp, normal);
    add(mount, new THREE.CylinderGeometry(radius * 1.06, radius * 1.1, 0.026, 6), groove,
      [0, 0, 0], [1, 1, 0.92], `IronTurtleCandidatePlateGroove${index + 1}`);
    const plateGeometry = addVertexColorVariation(
      new THREE.CylinderGeometry(radius * 0.94, radius, 0.062, 6, 2, false),
      index === 1 ? 0x9aa9aa : 0x7f9194,
      0.042,
      seed + 30
    );
    add(mount, plateGeometry, platePaint,
      [0, 0.038, 0], [1, 1, 0.92], `IronTurtleCandidatePlate${index + 1}`);
  });

  // Low overlapping edge guards suggest articulated deep-sea armor without
  // rebuilding the rim as a tall mechanical wall.
  for (let index = 0; index < 8; index += 1) {
    const angle = index / 8 * Math.PI * 2;
    const x = Math.sin(angle) * 0.54;
    const z = -0.02 + Math.cos(angle) * 0.59;
    const mount = pivot(shell, `IronTurtleCandidateRimGuardMount${index + 1}`, [x, 0.485, z]);
    const outward = new THREE.Vector3(Math.sin(angle), 0.3, Math.cos(angle)).normalize();
    mount.quaternion.setFromUnitVectors(shellUp, outward);
    add(mount, new THREE.CylinderGeometry(0.088, 0.1, 0.05, 6), edge,
      [0, 0.024, 0], [1.08, 1, 0.78], `IronTurtleCandidateRimGuard${index + 1}`);
    add(mount, new THREE.SphereGeometry(0.022, 12, 8), shellPaint,
      [0, 0.055, 0], [1, 0.68, 1], `IronTurtleCandidateRivet${index + 1}`);
  }

  const scratchOne = add(shell, new THREE.BoxGeometry(0.012, 0.015, 0.14), groove,
    [-0.07, 0.72, -0.04], [1, 1, 1], 'IronTurtleCandidateScratch1');
  scratchOne.rotation.y = -0.55;
  const rustPatch = add(shell, new THREE.SphereGeometry(0.06, 16, 10), rust,
    [0.34, 0.63, -0.12], [1, 0.11, 0.55], 'IronTurtleCandidateRustPatch');
  rustPatch.rotation.x = -0.3;

  // The head and neck remain low and forward, continuing the swimming line.
  add(rig, new THREE.SphereGeometry(0.2, 30, 20), skin,
    [0, 0.39, 0.43], [0.84, 0.5, 1.02], 'IronTurtleCandidateNeck');
  add(head, addVertexColorVariation(new THREE.SphereGeometry(0.24, 38, 24), 0x4f8c83, 0.04, 26),
    bodyPaint, [0, 0, 0], [0.86, 0.62, 1.15], 'IronTurtleCandidateHeadMesh');
  add(head, new THREE.SphereGeometry(0.16, 28, 18), skinLight,
    [0, -0.035, 0.19], [0.88, 0.46, 0.36], 'IronTurtleCandidateMuzzle');
  addEye(head, -0.085, 0.045, 0.225, 0.043, dark, glint, 'IronTurtleCandidateLeft');
  addEye(head, 0.085, 0.045, 0.225, 0.043, dark, glint, 'IronTurtleCandidateRight');
  [-0.045, 0.045].forEach((x, index) => {
    add(head, new THREE.SphereGeometry(0.011, 10, 7), dark,
      [x, -0.035, 0.253], [1, 0.62, 0.38], `IronTurtleCandidateNostril${index + 1}`);
  });
  const mouth = tube([
    [-0.066, -0.085, 0.245], [0, -0.095, 0.257], [0.066, -0.085, 0.245],
  ], 0.006, dark, 18, 6);
  mouth.name = 'IronTurtleCandidateMouth';
  head.add(mouth);

  add(frontLeft, seaTurtleFlipperGeometry(-1), skin,
    [0, 0, 0], [1, 1, 1], 'IronTurtleCandidateFrontFlipperMeshL');
  add(frontRight, seaTurtleFlipperGeometry(1), skin,
    [0, 0, 0], [1, 1, 1], 'IronTurtleCandidateFrontFlipperMeshR');
  const rearLeftMesh = add(rearLeft, seaTurtleFlipperGeometry(-1), skinLight,
    [0, 0, 0], [0.68, 0.78, 0.7], 'IronTurtleCandidateRearFlipperMeshL');
  const rearRightMesh = add(rearRight, seaTurtleFlipperGeometry(1), skinLight,
    [0, 0, 0], [0.68, 0.78, 0.7], 'IronTurtleCandidateRearFlipperMeshR');
  rearLeftMesh.rotation.y = -0.12;
  rearRightMesh.rotation.y = 0.12;

  const tail = add(rig, new THREE.ConeGeometry(0.075, 0.22, 16), skin,
    [0, 0.37, -0.65], [1, 1, 0.7], 'IronTurtleCandidateTail');
  tail.rotation.x = -Math.PI / 2;

  return finishCandidate({
    group,
    rig,
    healthColor: 0x668b91,
    // Wide sea-turtle flippers need a species-specific footprint. At 0.74,
    // the complete tip-to-tip silhouette stays inside one review hex after
    // the page's shared 0.86 model scale is applied.
    scale: 0.74,
    shadow: [0.73, 0.58, 0.2],
    nodes: [shell, head, frontLeft, frontRight, rearLeft, rearRight, tail],
    idle: time => {
      const swim = Math.sin(time * 1.8);
      rig.position.y = 0.035 + Math.sin(time * 1.45) * 0.018;
      head.rotation.y = Math.sin(time * 1.15) * 0.055;
      frontLeft.rotation.z = 0.035 + swim * 0.045;
      frontRight.rotation.z = -0.035 - swim * 0.045;
      rearLeft.rotation.z = swim * -0.02;
      rearRight.rotation.z = swim * 0.02;
    },
    actions: {
      move: progress => {
        const stroke = Math.sin(progress * Math.PI * 3);
        frontLeft.rotation.z += stroke * 0.34;
        frontRight.rotation.z -= stroke * 0.34;
        rearLeft.rotation.z -= stroke * 0.14;
        rearRight.rotation.z += stroke * 0.14;
        rig.position.y += Math.sin(progress * Math.PI) * 0.07;
      },
      attack: progress => {
        const lunge = Math.sin(progress * Math.PI);
        head.position.z += lunge * 0.27;
        frontLeft.rotation.z += lunge * 0.16;
        frontRight.rotation.z -= lunge * 0.16;
        shell.position.z -= lunge * 0.035;
      },
      hit: progress => {
        const recoil = Math.sin(progress * Math.PI);
        head.position.z -= recoil * 0.2;
        frontLeft.rotation.z -= recoil * 0.28;
        frontRight.rotation.z += recoil * 0.28;
        rearLeft.rotation.z += recoil * 0.14;
        rearRight.rotation.z -= recoil * 0.14;
        shell.rotation.z = Math.sin(progress * Math.PI * 5) * (1 - progress) * 0.055;
      },
    },
  });
}

const CANDIDATE_FACTORIES = {
  jellyfish: createJellyfishCandidate,
  iron_turtle: createArmoredSeaTurtleCandidate,
  archerfish: createArcherfishCandidate,
  vortex_eel: createVortexEelCandidate,
  electric_ray: createElectricRayCandidate,
  hermit_crab: createHermitCrabCandidate,
  ghost_shark: createGhostSharkCandidate,
};

export function createEnemyCandidate(type) {
  return CANDIDATE_FACTORIES[type]?.() || null;
}
