import * as THREE from '../vendor/three.module.js';
import { RAMPS, toon, markMesh } from '../src/game/materials.js';

function add(group, geometry, material, position, scale = [1, 1, 1]) {
  const mesh = markMesh(new THREE.Mesh(geometry, material));
  mesh.position.set(...position);
  mesh.scale.set(...scale);
  group.add(mesh);
  return mesh;
}

function latheBody(profile, segments = 28) {
  return new THREE.LatheGeometry(
    profile.map(([radius, y]) => new THREE.Vector2(radius, y)),
    segments
  );
}

function flipperGeometry() {
  const shape = new THREE.Shape();
  shape.moveTo(-0.1, 0.25);
  shape.bezierCurveTo(-0.18, 0.08, -0.15, -0.23, -0.015, -0.43);
  shape.bezierCurveTo(0.12, -0.26, 0.17, 0.05, 0.1, 0.25);
  shape.closePath();
  const geometry = new THREE.ExtrudeGeometry(shape, {
    depth: 0.105,
    bevelEnabled: true,
    bevelSegments: 2,
    bevelSize: 0.018,
    bevelThickness: 0.018,
    curveSegments: 8,
    steps: 1,
  });
  geometry.translate(0, 0, -0.0525);
  return geometry;
}

function integratedThreeCircleFaceGeometry(rings = 10, segments = 72) {
  const positions = [];
  const uvs = [];
  const indices = [];

  const headRadiusX = 0.46 * 0.98;
  const headRadiusY = 0.46 * 1.03;
  const headRadiusZ = 0.46 * 0.9;
  const faceCenterY = -0.05;

  // The face silhouette is the literal union of three circles: two equal,
  // overlapping forehead circles and one round lower-face circle. Building a
  // single radial mesh from their union keeps the visual construction simple
  // without stacking coplanar meshes that would flicker.
  const faceCircles = [
    // The two forehead circles are deliberately smaller, closer together and
    // lower than before. Their outside edges now line up with the lower face
    // circle instead of widening into a separate pair of white bumps.
    { x: -0.074, y: 0.035, radius: 0.205 },
    { x: 0.074, y: 0.035, radius: 0.205 },
    { x: 0, y: -0.095, radius: 0.305 },
  ];

  function faceZ(x, y) {
    const shell = 1 - (x * x) / (headRadiusX * headRadiusX)
      - (y * y) / (headRadiusY * headRadiusY);
    return headRadiusZ * Math.sqrt(Math.max(0.025, shell)) + 0.006;
  }

  function circleBoundaryRadius(angle, circle) {
    const dirX = Math.cos(angle);
    const dirY = Math.sin(angle);
    const originToCenterX = -circle.x;
    const originToCenterY = faceCenterY - circle.y;
    const projection = dirX * originToCenterX + dirY * originToCenterY;
    const constant = originToCenterX * originToCenterX
      + originToCenterY * originToCenterY
      - circle.radius * circle.radius;
    const discriminant = projection * projection - constant;
    return -projection + Math.sqrt(Math.max(0, discriminant));
  }

  positions.push(0, faceCenterY, faceZ(0, faceCenterY));
  uvs.push(0.5, 0.5);

  for (let ring = 1; ring <= rings; ring += 1) {
    const radius = ring / rings;
    for (let segment = 0; segment < segments; segment += 1) {
      const angle = segment / segments * Math.PI * 2;
      const boundaryRadius = Math.max(...faceCircles.map(circle =>
        circleBoundaryRadius(angle, circle)));
      const x = Math.cos(angle) * boundaryRadius * radius;
      const y = faceCenterY + Math.sin(angle) * boundaryRadius * radius;
      positions.push(x, y, faceZ(x, y));
      uvs.push(0.5 + x / 0.68, 0.5 + (y - faceCenterY) / 0.78);
    }
  }

  for (let segment = 0; segment < segments; segment += 1) {
    indices.push(0, 1 + segment, 1 + (segment + 1) % segments);
  }

  for (let ring = 2; ring <= rings; ring += 1) {
    const innerStart = 1 + (ring - 2) * segments;
    const outerStart = 1 + (ring - 1) * segments;
    for (let segment = 0; segment < segments; segment += 1) {
      const next = (segment + 1) % segments;
      const innerCurrent = innerStart + segment;
      const innerNext = innerStart + next;
      const outerCurrent = outerStart + segment;
      const outerNext = outerStart + next;
      indices.push(innerCurrent, outerCurrent, outerNext);
      indices.push(innerCurrent, outerNext, innerNext);
    }
  }

  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
  geometry.setAttribute('uv', new THREE.Float32BufferAttribute(uvs, 2));
  geometry.setIndex(indices);
  geometry.computeVertexNormals();
  geometry.computeBoundingSphere();
  return geometry;
}

function swordBlade() {
  const shape = new THREE.Shape();
  shape.moveTo(-0.075, 0);
  shape.lineTo(-0.06, 0.56);
  shape.lineTo(0, 0.78);
  shape.lineTo(0.06, 0.56);
  shape.lineTo(0.075, 0);
  shape.closePath();
  const geometry = new THREE.ExtrudeGeometry(shape, {
    depth: 0.075,
    bevelEnabled: true,
    bevelSegments: 1,
    bevelSize: 0.012,
    bevelThickness: 0.012,
    steps: 1,
  });
  geometry.translate(0, 0, -0.0375);
  return geometry;
}

function addContactShadow(group) {
  const geometry = new THREE.CircleGeometry(0.5, 24);
  geometry.rotateX(-Math.PI * 0.5);
  const shadow = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial({
    color: 0x06100f,
    transparent: true,
    opacity: 0.3,
    depthWrite: false,
    toneMapped: false,
  }));
  shadow.position.y = 0.012;
  shadow.scale.set(0.94, 1, 0.62);
  group.add(shadow);
}

export function createPenguinCandidate() {
  const group = new THREE.Group();
  group.name = 'PenguinHeroCandidateV2';
  const rig = new THREE.Group();
  rig.name = 'PenguinCandidateRig';
  group.add(rig);

  const penguinBlack = toon(0x0a2029, RAMPS.character, 0x020a0f, 0.045);
  const feather = penguinBlack;
  const featherDark = penguinBlack;
  const flipper = penguinBlack;
  const face = toon(0xfff2d2, RAMPS.soft, 0x9b7754, 0.025);
  const bellyMaterial = toon(0xf5dfb7, RAMPS.soft, 0x8d6745, 0.035);
  const beakUpper = toon(0xe78a1c, RAMPS.character, 0x672707, 0.06);
  const footMaterial = toon(0xff9c24, RAMPS.character, 0x7d2d06, 0.07);
  const eye = new THREE.MeshBasicMaterial({ color: 0x071018, toneMapped: false });
  const eyeWarmth = new THREE.MeshBasicMaterial({ color: 0x5a2c17, toneMapped: false });
  const eyeGlint = new THREE.MeshBasicMaterial({ color: 0xffffff, toneMapped: false });
  const handleMaterial = toon(0x6e4328, RAMPS.character, 0x24130a, 0.025);
  const blade = new THREE.MeshStandardMaterial({
    color: 0xdff8f6,
    metalness: 0.72,
    roughness: 0.22,
    emissive: 0x173c44,
    emissiveIntensity: 0.12,
  });

  // A narrower upper body and fuller lower body create the classic penguin
  // pear silhouette without making the hero look like a round toy ball.
  add(rig, latheBody([
    [0, 0.08], [0.3, 0.09], [0.45, 0.25], [0.49, 0.5],
    [0.44, 0.75], [0.31, 0.96], [0.14, 1.04], [0, 1.05],
  ]), feather, [0, 0, 0], [0.9, 0.97, 0.78]);

  // Keep the belly deeply embedded in the torso, but give its front surface
  // enough depth to catch light as a soft rounded volume instead of reading
  // as a flat cream patch.
  const belly = add(rig, new THREE.SphereGeometry(0.41, 28, 20), bellyMaterial,
    [0, 0.51, 0.205], [0.82, 1.07, 0.56]);
  belly.name = 'CandidateBelly';
  add(rig, new THREE.SphereGeometry(0.16, 18, 12), face,
    [0, 0.86, 0.35], [1.35, 0.56, 0.2]);

  const head = new THREE.Group();
  head.name = 'CandidateHeadRig';
  head.position.set(0, 1.13, 0.025);
  rig.add(head);
  add(head, new THREE.SphereGeometry(0.46, 30, 22), featherDark,
    [0, 0, 0], [0.98, 1.03, 0.9]);

  // One continuous cream shell follows the curvature of the black head. It
  // sits only a few millimetres forward, so the face reads as feather
  // colouring rather than two white balls attached to the skull.
  const faceMask = add(head, integratedThreeCircleFaceGeometry(), face,
    [0, 0, 0], [1, 1, 1]);
  faceMask.name = 'CandidateIntegratedFaceMask';
  // Larger vertical eyes, warm lower irises and offset highlights remain
  // legible at phone-game scale while avoiding the previous blank stare.
  const blinkingEyeParts = [];
  [-0.118, 0.118].forEach((x, index) => {
    const eyeShape = add(head, new THREE.SphereGeometry(0.075, 16, 12), eye,
      [x, 0.04, 0.414], [0.78, 1.24, 0.12]);
    const iris = add(head, new THREE.SphereGeometry(0.035, 12, 8), eyeWarmth,
      [x + (index === 0 ? 0.005 : -0.005), 0.015, 0.424], [0.72, 0.88, 0.1]);
    const glint = add(head, new THREE.SphereGeometry(0.018, 9, 7), eyeGlint,
      [x - 0.014, 0.072, 0.428], [1, 1, 0.08]);
    [eyeShape, iris, glint].forEach(part => {
      part.userData.blinkBaseScaleY = part.scale.y;
      blinkingEyeParts.push(part);
    });
  });

  // A short flattened ellipsoid keeps the bill fully closed while giving it
  // a rounded oval silhouette from the front. Its rear half sits inside the
  // face so it reads as an attached beak rather than a floating nose.
  const closedBeak = add(head, new THREE.SphereGeometry(0.12, 24, 16), beakUpper,
    [0, -0.085, 0.438], [1, 0.46, 0.44]);
  closedBeak.name = 'CandidateClosedBeak';

  const leftShoulder = new THREE.Group();
  leftShoulder.name = 'CandidateLeftShoulderJoint';
  leftShoulder.position.set(-0.38, 0.88, 0.005);
  rig.add(leftShoulder);
  const leftFlipper = add(leftShoulder, flipperGeometry(), flipper,
    [0, -0.16, 0], [1.02, 1.08, 1]);
  leftFlipper.name = 'CandidateLeftFlipper';
  leftFlipper.rotation.z = -0.9;

  const rightShoulder = new THREE.Group();
  rightShoulder.name = 'CandidateRightShoulderJoint';
  rightShoulder.position.set(0.4, 0.88, 0.005);
  rig.add(rightShoulder);
  const rightFlipper = add(rightShoulder, flipperGeometry(), flipper,
    [0, -0.16, 0], [1.02, 1.08, 1]);
  rightFlipper.name = 'CandidateRightFlipper';
  rightFlipper.rotation.z = 0.68;

  const leftAnkle = new THREE.Group();
  leftAnkle.name = 'CandidateLeftAnkleJoint';
  leftAnkle.position.set(-0.225, 0.1, 0.25);
  rig.add(leftAnkle);
  const leftFoot = add(leftAnkle, new THREE.SphereGeometry(0.17, 18, 10), footMaterial,
    [0, 0, 0], [1.12, 0.44, 1.34]);
  leftFoot.rotation.y = -0.16;
  leftFoot.rotation.z = -0.06;

  const rightAnkle = new THREE.Group();
  rightAnkle.name = 'CandidateRightAnkleJoint';
  rightAnkle.position.set(0.225, 0.1, 0.25);
  rig.add(rightAnkle);
  const rightFoot = add(rightAnkle, new THREE.SphereGeometry(0.17, 18, 10), footMaterial,
    [0, 0, 0], [1.12, 0.44, 1.34]);
  rightFoot.rotation.y = 0.16;
  rightFoot.rotation.z = 0.06;

  [-0.052, 0.004, 0.056].forEach(x => {
    add(leftAnkle, new THREE.SphereGeometry(0.034, 10, 6), footMaterial,
      [x, -0.002, 0.13], [0.92, 0.52, 1.18]);
  });
  [-0.056, -0.004, 0.052].forEach(x => {
    add(rightAnkle, new THREE.SphereGeometry(0.034, 10, 6), footMaterial,
      [x, -0.002, 0.13], [0.92, 0.52, 1.18]);
  });

  const sword = new THREE.Group();
  sword.name = 'CandidateSword';
  // The sword's local origin is the centre of its handle, so every attack
  // rotates around the penguin's actual grip instead of around the guard.
  const swordHandle = add(sword, new THREE.CapsuleGeometry(0.043, 0.22, 5, 10),
    handleMaterial, [0, 0, 0]);
  swordHandle.name = 'CandidateSwordHandle';
  const swordGuard = add(sword, new THREE.BoxGeometry(0.3, 0.065, 0.12),
    beakUpper, [0, 0.15, 0]);
  swordGuard.name = 'CandidateSwordGuard';
  add(sword, new THREE.SphereGeometry(0.045, 12, 8), blade,
    [0, 0.15, 0.082], [1, 0.72, 0.72]);
  add(sword, swordBlade(), blade, [0, 0.19, 0]);
  add(sword, new THREE.BoxGeometry(0.018, 0.55, 0.082), eyeGlint,
    [-0.032, 0.47, 0]);
  const rightHand = new THREE.Group();
  rightHand.name = 'CandidateRightHandJoint';
  rightHand.position.set(0.37, -0.49, 0.06);
  rightShoulder.add(rightHand);
  const gripHand = add(rightHand, new THREE.SphereGeometry(0.07, 14, 10), flipper,
    [0, 0, 0], [1, 0.82, 0.72]);
  gripHand.name = 'CandidateSwordGripHand';
  sword.position.set(0, 0, 0);
  sword.rotation.z = -0.69;
  rightHand.add(sword);

  addContactShadow(group);
  group.scale.setScalar(1.02);
  group.userData.joints = {
    head,
    leftShoulder,
    rightShoulder,
    rightHand,
    leftAnkle,
    rightAnkle,
    sword,
  };
  group.userData.action = null;
  group.userData.animationTime = 0;
  const attackRigWorldQuaternion = new THREE.Quaternion();
  const attackHandWorldQuaternion = new THREE.Quaternion();
  const attackDesiredWorldQuaternion = new THREE.Quaternion();
  const attackBladeRigQuaternion = new THREE.Quaternion();
  const attackBladeEuler = new THREE.Euler();
  group.userData.playAction = (name, duration = 0.55) => {
    group.userData.action = { name, duration, startedAt: group.userData.animationTime };
  };
  group.userData.previewAction = (name, progress = 0) => {
    group.userData.action = {
      name,
      duration: 1,
      startedAt: group.userData.animationTime,
      previewProgress: THREE.MathUtils.clamp(progress, 0, 1),
    };
  };
  group.userData.animate = time => {
    group.userData.animationTime = time;
    let action = group.userData.action;
    if (action && action.previewProgress == null && time - action.startedAt >= action.duration) {
      group.userData.action = null;
      action = null;
    }
    const progress = action
      ? action.previewProgress ?? THREE.MathUtils.clamp((time - action.startedAt) / action.duration, 0, 1)
      : 0;
    const breath = Math.sin(time * 2.25);
    const blinkPhase = time % 4.7;
    const blink = blinkPhase < 0.12 ? Math.max(0.12, Math.abs(blinkPhase - 0.06) / 0.06) : 1;
    rig.position.set(0, Math.max(0, breath) * 0.008, 0);
    rig.rotation.set(0, 0, breath * 0.006);
    rig.scale.set(1, 1, 1);
    head.rotation.set(0, Math.sin(time * 0.7) * 0.035, -breath * 0.01);
    leftShoulder.position.set(-0.38, 0.88, 0.005);
    rightShoulder.position.set(0.4, 0.88, 0.005);
    leftShoulder.rotation.set(0, 0, -breath * 0.025);
    rightShoulder.rotation.set(0, 0, breath * 0.02);
    leftAnkle.position.set(-0.225, 0.1, 0.25);
    rightAnkle.position.set(0.225, 0.1, 0.25);
    leftAnkle.rotation.set(0, 0, 0);
    rightAnkle.rotation.set(0, 0, 0);
    blinkingEyeParts.forEach(part => {
      part.scale.y = part.userData.blinkBaseScaleY * blink;
    });
    rightHand.position.set(0.37, -0.49, 0.06);
    rightHand.rotation.set(0, 0, 0);
    sword.position.set(0, 0, 0);
    sword.rotation.set(0, 0, -0.69 + breath * 0.018);

    if (action?.name === 'move') {
      const gait = Math.sin(progress * Math.PI * 4);
      const leftLift = Math.max(0, gait);
      const rightLift = Math.max(0, -gait);
      rig.position.y += Math.max(leftLift, rightLift) * 0.026;
      rig.rotation.z += gait * 0.035;
      head.rotation.z -= gait * 0.055;
      head.rotation.x = -0.035 + Math.abs(gait) * 0.025;

      // Arms counter-swing from their shoulder joints. The sword is parented
      // to the right shoulder, so it follows the hand instead of floating.
      leftShoulder.rotation.x = gait * 0.52;
      leftShoulder.rotation.z -= gait * 0.09;
      rightShoulder.rotation.x = -gait * 0.48;
      rightShoulder.rotation.z -= gait * 0.07;

      // Each foot has its own ankle pivot, lift and fore-aft travel.
      leftAnkle.position.y += leftLift * 0.1;
      leftAnkle.position.z += gait * 0.13;
      leftAnkle.rotation.x = -gait * 0.48;
      leftAnkle.rotation.z = -gait * 0.06;
      rightAnkle.position.y += rightLift * 0.1;
      rightAnkle.position.z -= gait * 0.13;
      rightAnkle.rotation.x = gait * 0.48;
      rightAnkle.rotation.z = gait * 0.06;
    } else if (action?.name === 'jump_attack') {
      const windup = THREE.MathUtils.smoothstep(progress, 0, 0.28);
      const cut = THREE.MathUtils.smoothstep(progress, 0.28, 0.58);
      const recover = THREE.MathUtils.smoothstep(progress, 0.72, 1);
      const windupPose = windup * (1 - cut);
      const sweepPose = cut * (1 - recover);
      const attackPose = windup * (1 - recover);
      rig.position.y += windupPose * 0.025;
      rig.position.x -= sweepPose * 0.018;
      rig.rotation.y += windupPose * 0.035 - sweepPose * 0.055;

      // The head sights the target while the free flipper braces the body.
      head.rotation.x = -windupPose * 0.045 + sweepPose * 0.025;
      head.rotation.y = -windupPose * 0.06 + sweepPose * 0.045;
      head.rotation.z += windupPose * 0.035 - sweepPose * 0.045;
      leftShoulder.rotation.z = -windupPose * 0.3 + sweepPose * 0.12;
      leftShoulder.rotation.x = windupPose * 0.22;

      // The fixed shoulder drives a real back-to-front cutting arc. From the
      // side, the hand visibly travels from behind the torso into the target
      // space instead of wiping across a flat plane in front of the camera.
      rightShoulder.rotation.x = windupPose * 0.58 - sweepPose * 1;
      rightShoulder.rotation.y = windupPose * 0.06 - sweepPose * 0.1;
      rightShoulder.rotation.z = windupPose * 0.12 - sweepPose * 0.08;
      rightHand.rotation.set(
        -windupPose * 0.08 + sweepPose * 0.18,
        windupPose * 0.05 - sweepPose * 0.08,
        windupPose * 0.08 - sweepPose * 0.06
      );

      // Aim the blade in the penguin's local 3D space. It begins mostly
      // upright during anticipation and pitches forward with the arm, so at
      // contact the tip points diagonally up into the target space rather
      // than straight ahead or sideways. The
      // conversion to hand-local space preserves this direction despite the
      // nested shoulder and wrist rotations.
      const bladePitch = windupPose * 0.2 + sweepPose * 1.05;
      const bladeRoll = -windupPose * 0.38 - sweepPose * 0.16;
      attackBladeEuler.set(bladePitch, 0, bladeRoll, 'XYZ');
      attackBladeRigQuaternion.setFromEuler(attackBladeEuler);
      group.updateMatrixWorld(true);
      rig.getWorldQuaternion(attackRigWorldQuaternion);
      rightHand.getWorldQuaternion(attackHandWorldQuaternion);
      attackDesiredWorldQuaternion.copy(attackRigWorldQuaternion).multiply(attackBladeRigQuaternion);
      sword.quaternion.copy(attackHandWorldQuaternion).invert().multiply(attackDesiredWorldQuaternion);

      // Opposed foot placement sells force without squashing the whole body.
      leftAnkle.position.x -= sweepPose * 0.025;
      leftAnkle.rotation.z = -windupPose * 0.06 - sweepPose * 0.08;
      rightAnkle.position.x += windupPose * 0.02 + sweepPose * 0.015;
      rightAnkle.rotation.z = windupPose * 0.08 + sweepPose * 0.055;
    } else if (action?.name === 'hit') {
      const recoil = Math.sin(progress * Math.PI);
      const shake = Math.sin(progress * Math.PI * 7) * (1 - progress);
      rig.position.x = shake * 0.028;
      rig.position.z = -recoil * 0.045;
      rig.rotation.z += shake * 0.035;
      head.rotation.x = recoil * 0.31;
      head.rotation.z += shake * 0.1;
      leftShoulder.rotation.z = recoil * -0.68;
      leftShoulder.rotation.x = recoil * -0.25;
      rightShoulder.rotation.z = recoil * 0.62;
      rightShoulder.rotation.x = recoil * 0.3;
      leftAnkle.position.z += recoil * 0.04;
      leftAnkle.rotation.x = recoil * -0.16;
      rightAnkle.position.z -= recoil * 0.13;
      rightAnkle.position.y += recoil * 0.025;
      rightAnkle.rotation.x = recoil * 0.36;
    }
  };
  group.userData.animate(0);
  return group;
}
