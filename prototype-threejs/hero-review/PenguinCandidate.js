import * as THREE from '../vendor/three.module.js';
import { RAMPS, toon, markMesh } from '../src/game/materials.js';

const clamp01 = value => Math.max(0, Math.min(1, value));
const actionPulse = (value, start, end) => {
  const t = clamp01((value - start) / Math.max(0.0001, end - start));
  return Math.sin(t * Math.PI);
};

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

function tailFeatherGeometry() {
  const shape = new THREE.Shape();
  // A compact rounded wedge gives the tail a real feather silhouette. The
  // broad root is buried in the lower back and only the tapered tip remains
  // visible, avoiding the look of a black ball glued onto the torso.
  shape.moveTo(-0.115, 0.11);
  shape.bezierCurveTo(-0.13, 0.025, -0.075, -0.17, 0, -0.235);
  shape.bezierCurveTo(0.075, -0.17, 0.13, 0.025, 0.115, 0.11);
  shape.closePath();
  const geometry = new THREE.ExtrudeGeometry(shape, {
    depth: 0.1,
    bevelEnabled: true,
    bevelSegments: 2,
    bevelSize: 0.014,
    bevelThickness: 0.014,
    curveSegments: 10,
    steps: 1,
  });
  geometry.translate(0, 0, -0.05);
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
      const circleRadius = Math.max(...faceCircles.map(circle =>
        circleBoundaryRadius(angle, circle)));
      // Preserve a small area of the black head between the two cream
      // forehead lobes, as in the visual reference. This is carved into the
      // cream silhouette itself rather than added as a raised black patch, so
      // it reads as natural feather colouring instead of a diamond accessory.
      const topOffset = Math.atan2(
        Math.sin(angle - Math.PI * 0.5),
        Math.cos(angle - Math.PI * 0.5)
      );
      const roundedForeheadInset = Math.exp(
        -(topOffset * topOffset) / (2 * 0.22 * 0.22)
      ) * Math.max(0, Math.sin(angle));
      const boundaryRadius = circleRadius - roundedForeheadInset * 0.052;
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
  group.userData.contactShadow = shadow;
  shadow.userData.baseOpacity = 0.3;
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

  // Penguins have a short, stiff tail that supports their rear silhouette.
  // Keep its root well inside the torso and angle the tip backward/downward,
  // so it reads as one anatomical form rather than a floating accessory.
  const tail = add(rig, tailFeatherGeometry(), penguinBlack,
    [0, 0.285, -0.29], [0.9, 0.92, 0.9]);
  tail.name = 'CandidateTailFeather';
  tail.rotation.x = 0.38;

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

  // The approved hit reaction tilts only the upper body around a foot-level
  // pivot. Ankles stay directly under the main rig, which keeps both feet on
  // the board even when the torso fall is deliberately broad.
  const hitBodyPivot = new THREE.Group();
  hitBodyPivot.name = 'PenguinGroundedHitBodyPivot';
  rig.add(hitBodyPivot);
  const groundedParts = new Set([leftAnkle, rightAnkle]);
  [...rig.children].forEach(child => {
    if (child !== hitBodyPivot && !groundedParts.has(child)) hitBodyPivot.add(child);
  });

  addContactShadow(group);
  group.scale.setScalar(1.02);
  group.userData.joints = {
    head,
    tail,
    leftShoulder,
    rightShoulder,
    rightHand,
    leftAnkle,
    rightAnkle,
    sword,
    hitBodyPivot,
  };
  group.userData.action = null;
  group.userData.animationTime = 0;
  const attackRigWorldQuaternion = new THREE.Quaternion();
  const attackHandWorldQuaternion = new THREE.Quaternion();
  const attackDesiredWorldQuaternion = new THREE.Quaternion();
  const attackBladeRigQuaternion = new THREE.Quaternion();
  const attackBladeEuler = new THREE.Euler();
  group.userData.playAction = (name, duration = 0.55, options = {}) => {
    group.userData.action = { name, duration, startedAt: group.userData.animationTime, ...options };
  };
  group.userData.previewAction = (name, progress = 0) => {
    group.userData.action = {
      name,
      duration: 1,
      startedAt: group.userData.animationTime,
      previewProgress: THREE.MathUtils.clamp(progress, 0, 1),
    };
  };
  group.userData.animate = (time, moving = false) => {
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
    hitBodyPivot.position.set(0, 0, 0);
    hitBodyPivot.rotation.set(0, 0, 0);
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

    if (action?.name === 'move' || (moving && !action)) {
      const locomotionProgress = action?.name === 'move' ? progress : (time * 1.8) % 1;
      const gait = Math.sin(locomotionProgress * Math.PI * 4);
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
    } else if (action?.name === 'approved_hit') {
      const contactSnap = actionPulse(progress, 0, 0.26);
      const bodyStagger = actionPulse(progress, 0.08, 0.72);
      const headLag = actionPulse(progress, 0.035, 0.48);
      const freeArmFlail = actionPulse(progress, 0.08, 0.68);
      const rearFootSlip = actionPulse(progress, 0.02, 0.5);
      const recoveryStep = actionPulse(progress, 0.42, 0.9);
      const settle = actionPulse(progress, 0.72, 1);
      const recoil = contactSnap * 0.105 + bodyStagger * 0.07
        - recoveryStep * 0.018 - settle * 0.012;
      const rawX = Number.isFinite(action.recoilX) ? action.recoilX : 0;
      const rawZ = Number.isFinite(action.recoilZ) ? action.recoilZ : -1;
      const recoilLength = Math.hypot(rawX, rawZ) || 1;
      const recoilX = rawX / recoilLength;
      const recoilZ = rawZ / recoilLength;
      const sideX = -recoilZ;
      const sideZ = recoilX;
      const staggerSign = action.staggerSign === -1 ? -1 : 1;
      const sideShift = (bodyStagger * 0.045 - recoveryStep * 0.025) * staggerSign;

      // No vertical translation, ankle lift, Y scaling or whole-rig tilt is
      // allowed here. The approved reaction remains fully grounded.
      rig.position.set(
        recoilX * recoil + sideX * sideShift,
        0,
        recoilZ * recoil + sideZ * sideShift
      );
      rig.rotation.set(0, bodyStagger * 0.045 * staggerSign - recoveryStep * 0.018 * staggerSign, 0);
      rig.scale.x = 1 + contactSnap * 0.035 - bodyStagger * 0.012;
      rig.scale.y = 1;
      rig.scale.z = 1 + contactSnap * 0.025;

      const directionalTilt = contactSnap * 0.2 + bodyStagger * 0.14 - recoveryStep * 0.045;
      const lateralTilt = (contactSnap * 0.075 - bodyStagger * 0.18 + recoveryStep * 0.065) * staggerSign;
      hitBodyPivot.rotation.x = directionalTilt * recoilZ;
      hitBodyPivot.rotation.z = -directionalTilt * recoilX + lateralTilt;

      head.rotation.x += headLag * recoilZ * 0.34 - recoveryStep * recoilZ * 0.075;
      head.rotation.y += headLag * 0.075 * staggerSign - recoveryStep * 0.03 * staggerSign;
      head.rotation.z += -headLag * recoilX * 0.22
        + (contactSnap * 0.07 - headLag * 0.12 + settle * 0.035) * staggerSign;
      leftShoulder.rotation.x -= freeArmFlail * 0.32 - recoveryStep * 0.08;
      leftShoulder.rotation.y += freeArmFlail * 0.1 * staggerSign;
      leftShoulder.rotation.z -= (contactSnap * 0.18 + freeArmFlail * 0.62
        - recoveryStep * 0.12) * staggerSign;

      leftAnkle.position.x += recoilX * rearFootSlip * 0.06 - sideX * bodyStagger * 0.035;
      leftAnkle.position.z += recoilZ * rearFootSlip * 0.06 - sideZ * bodyStagger * 0.035;
      leftAnkle.rotation.x += rearFootSlip * 0.18 - recoveryStep * 0.14;
      leftAnkle.rotation.z -= bodyStagger * 0.1 * staggerSign;
      rightAnkle.position.x += recoilX * recoveryStep * 0.065 + sideX * bodyStagger * 0.045;
      rightAnkle.position.z += recoilZ * recoveryStep * 0.065 + sideZ * bodyStagger * 0.045;
      rightAnkle.rotation.x -= rearFootSlip * 0.24;
      rightAnkle.rotation.z += (bodyStagger * 0.14 - recoveryStep * 0.08) * staggerSign;
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
    } else if (action?.name === 'land') {
      const squash = Math.sin(progress * Math.PI);
      rig.position.y -= squash * 0.085;
      rig.position.z += squash * 0.035;
      rig.scale.set(1 + squash * 0.12, 1 - squash * 0.18, 1 + squash * 0.1);
      head.rotation.x += squash * 0.14;
      leftShoulder.rotation.z -= squash * 0.34;
      rightShoulder.rotation.z += squash * 0.28;
      leftAnkle.rotation.x = -squash * 0.2;
      rightAnkle.rotation.x = -squash * 0.2;
    } else if (action?.name === 'pickup') {
      const reach = Math.sin(progress * Math.PI);
      const nod = Math.sin(progress * Math.PI * 2) * (1 - progress);
      rig.position.y -= reach * 0.055;
      rig.rotation.x = reach * 0.16;
      head.rotation.x += reach * 0.38;
      head.rotation.z += nod * 0.055;
      leftShoulder.rotation.x = reach * 0.42;
      leftShoulder.rotation.z -= reach * 0.18;
      rightShoulder.rotation.x = -reach * 0.2;
      rightHand.rotation.x = -reach * 0.18;
    } else if (action?.name === 'cast') {
      const charge = Math.sin(Math.min(1, progress * 1.7) * Math.PI * 0.5);
      const release = progress < 0.48 ? 0 : Math.sin((progress - 0.48) / 0.52 * Math.PI);
      rig.position.y += charge * 0.075;
      rig.rotation.x = -release * 0.1;
      head.rotation.x -= charge * 0.1;
      leftShoulder.rotation.x = -charge * 0.42;
      leftShoulder.rotation.z -= charge * 0.38;
      rightShoulder.rotation.x = -charge * 0.5 + release * 0.16;
      rightShoulder.rotation.z = -charge * 0.58;
      rightHand.rotation.z = -charge * 0.28;
      sword.rotation.z = -0.69 - charge * 0.72;
    } else if (action?.name === 'hex_blast_cast') {
      const brace = THREE.MathUtils.smoothstep(progress, 0, 0.14);
      const plant = THREE.MathUtils.smoothstep(progress, 0.12, 0.24);
      const recover = THREE.MathUtils.smoothstep(progress, 0.7, 1);
      const chargePose = brace * (1 - plant);
      const channelPose = plant * (1 - recover);
      const releaseSnap = actionPulse(progress, 0.12, 0.34);

      // Grounded spell-cast: draw the weapon in during anticipation, then
      // plant its tip diagonally toward the board while the free flipper opens
      // as a brace. This communicates "channel energy into the ground" from
      // any facing direction without turning toward the camera or borrowing a
      // horizontal attack sweep.
      hitBodyPivot.position.y -= chargePose * 0.025 + channelPose * 0.055;
      hitBodyPivot.position.z -= chargePose * 0.025;
      hitBodyPivot.position.z += channelPose * 0.045;
      hitBodyPivot.rotation.x = chargePose * 0.08 + channelPose * 0.14;
      head.rotation.x += chargePose * 0.1 + channelPose * 0.19;
      head.rotation.z += releaseSnap * 0.02;

      leftShoulder.rotation.x = chargePose * 0.18 - channelPose * 0.2;
      leftShoulder.rotation.z = -chargePose * 0.32 - channelPose * 0.7;
      rightShoulder.rotation.x = chargePose * 0.48 - channelPose * 0.92;
      rightShoulder.rotation.y = chargePose * 0.05 - channelPose * 0.08;
      rightShoulder.rotation.z = chargePose * 0.12 + channelPose * 0.1;
      rightHand.rotation.x = -chargePose * 0.08 + channelPose * 0.18;
      rightHand.rotation.z = chargePose * 0.08 - channelPose * 0.06;

      const bladePitch = chargePose * 0.12 + channelPose * 2.18;
      const bladeRoll = -chargePose * 0.28 - channelPose * 0.08;
      attackBladeEuler.set(bladePitch, 0, bladeRoll, 'XYZ');
      attackBladeRigQuaternion.setFromEuler(attackBladeEuler);
      group.updateMatrixWorld(true);
      rig.getWorldQuaternion(attackRigWorldQuaternion);
      rightHand.getWorldQuaternion(attackHandWorldQuaternion);
      attackDesiredWorldQuaternion.copy(attackRigWorldQuaternion).multiply(attackBladeRigQuaternion);
      sword.quaternion.copy(attackHandWorldQuaternion).invert().multiply(attackDesiredWorldQuaternion);

      leftAnkle.position.x -= channelPose * 0.028;
      rightAnkle.position.x += channelPose * 0.028;
      leftAnkle.rotation.z = -channelPose * 0.065;
      rightAnkle.rotation.z = channelPose * 0.065;
    } else if (action?.name === 'life_drain_cast') {
      const reach = THREE.MathUtils.smoothstep(progress, 0, 0.2);
      const draw = THREE.MathUtils.smoothstep(progress, 0.5, 0.72);
      const recover = THREE.MathUtils.smoothstep(progress, 0.8, 1);
      const channelPose = reach * (1 - recover);
      const drawPose = draw * (1 - recover);

      // Keep the last movement facing. The free flipper reaches toward the
      // surrounding enemies, then draws their life energy back to the chest;
      // the sword arm braces close to the body and never performs a strike.
      hitBodyPivot.position.z += channelPose * 0.025 - drawPose * 0.055;
      hitBodyPivot.rotation.x = -channelPose * 0.045 + drawPose * 0.08;
      head.rotation.x += -channelPose * 0.06 + drawPose * 0.13;
      head.rotation.y += channelPose * 0.055 - drawPose * 0.025;

      leftShoulder.rotation.x = -channelPose * 0.72 + drawPose * 0.92;
      leftShoulder.rotation.y = channelPose * 0.12 - drawPose * 0.08;
      leftShoulder.rotation.z = -channelPose * 0.52 + drawPose * 0.22;
      rightShoulder.rotation.x = channelPose * 0.18 - drawPose * 0.12;
      rightShoulder.rotation.z = channelPose * 0.26 + drawPose * 0.08;
      rightHand.rotation.x = channelPose * 0.06;
      rightHand.rotation.z = -channelPose * 0.08;
      sword.rotation.z = -0.69 - channelPose * 0.16;

      leftAnkle.position.x -= channelPose * 0.02;
      rightAnkle.position.x += channelPose * 0.02;
      leftAnkle.rotation.z = -channelPose * 0.04;
      rightAnkle.rotation.z = channelPose * 0.04;
    } else if (action?.name === 'time_stop_cast') {
      const gather = THREE.MathUtils.smoothstep(progress, 0, 0.16);
      const open = THREE.MathUtils.smoothstep(progress, 0.17, 0.29);
      const recover = THREE.MathUtils.smoothstep(progress, 0.76, 1);
      const closedPose = gather * (1 - open) * (1 - recover);
      const stopPose = open * (1 - recover);

      // A compact cross-body gather snaps into a broad two-arm halt pose.
      // It remains grounded and keeps the current facing, so it cannot be
      // mistaken for either a sword strike or the life-drain pull.
      hitBodyPivot.position.y -= closedPose * 0.125 + stopPose * 0.04;
      hitBodyPivot.position.z += -closedPose * 0.075 + stopPose * 0.09;
      hitBodyPivot.rotation.x = closedPose * 0.16 - stopPose * 0.12;
      hitBodyPivot.rotation.y = -closedPose * 0.14 + stopPose * 0.08;
      head.rotation.x += closedPose * 0.27 - stopPose * 0.11;
      head.rotation.y -= closedPose * 0.17;
      leftShoulder.rotation.x = -closedPose * 0.88 - stopPose * 0.38;
      leftShoulder.rotation.y = closedPose * 0.24 + stopPose * 0.12;
      leftShoulder.rotation.z = closedPose * 1.24 - stopPose * 1.45;
      rightShoulder.rotation.x = -closedPose * 0.38 - stopPose * 0.27;
      rightShoulder.rotation.y = closedPose * 0.17 - stopPose * 0.09;
      rightShoulder.rotation.z = -closedPose * 0.9 + stopPose * 1.12;
      rightHand.rotation.x = -closedPose * 0.22 + stopPose * 0.12;
      rightHand.rotation.z = closedPose * 0.32 - stopPose * 0.12;
      sword.rotation.x = -closedPose * 0.28 + stopPose * 0.12;
      sword.rotation.z = -0.69 - closedPose * 0.72 + stopPose * 0.42;
      leftAnkle.position.x -= stopPose * 0.055;
      rightAnkle.position.x += stopPose * 0.055;
      leftAnkle.rotation.z = -stopPose * 0.1;
      rightAnkle.rotation.z = stopPose * 0.1;
    } else if (action?.name === 'meteor_cast') {
      const gather = THREE.MathUtils.smoothstep(progress, 0, 0.12)
        * (1 - THREE.MathUtils.smoothstep(progress, 0.14, 0.25));
      const takeoff = THREE.MathUtils.smoothstep(progress, 0.08, 0.24);
      const dive = THREE.MathUtils.smoothstep(progress, 0.38, 0.69);
      const airbornePose = takeoff * (1 - THREE.MathUtils.smoothstep(progress, 0.43, 0.62));
      const slamPose = dive * (1 - THREE.MathUtils.smoothstep(progress, 0.66, 0.71));
      const strikePose = dive * (1 - THREE.MathUtils.smoothstep(progress, 0.73, 0.82));
      const brace = THREE.MathUtils.smoothstep(progress, 0.67, 0.71)
        * (1 - THREE.MathUtils.smoothstep(progress, 0.77, 0.87));
      const jumpLocal = THREE.MathUtils.clamp((progress - 0.08) / 0.62, 0, 1);
      const jumpLift = progress >= 0.08 && progress <= 0.7
        ? Math.sin(jumpLocal * Math.PI) * 0.92
        : 0;

      rig.position.y += jumpLift;
      hitBodyPivot.position.y += -gather * 0.15 + airbornePose * 0.055 - brace * 0.16;
      hitBodyPivot.position.z += gather * 0.1 + airbornePose * 0.035 - slamPose * 0.12;
      hitBodyPivot.rotation.x = gather * 0.2 - airbornePose * 0.13 + slamPose * 0.34 + brace * 0.22;
      head.rotation.x += gather * 0.2 - airbornePose * 0.18 + slamPose * 0.16 + brace * 0.08;
      leftShoulder.rotation.x = -gather * 0.38 - airbornePose * 0.3 - strikePose * 0.42;
      leftShoulder.rotation.z = gather * 0.48 - airbornePose * 1.14 + strikePose * 0.64 + brace * 0.22;
      rightShoulder.rotation.x = gather * 0.18 - airbornePose * 0.44 + strikePose * 0.38;
      rightShoulder.rotation.y = -gather * 0.2 - airbornePose * 0.12 + strikePose * 0.16;
      rightShoulder.rotation.z = -gather * 0.72 + airbornePose * 1.52 - strikePose * 1.22 - brace * 0.34;
      rightHand.rotation.x = -gather * 0.24 + airbornePose * 0.22 - strikePose * 0.18;
      rightHand.rotation.z = gather * 0.28 - airbornePose * 0.18 + strikePose * 0.2;
      sword.rotation.x = -gather * 0.22 + airbornePose * 0.16 - strikePose * 0.2;
      sword.rotation.z = -0.69 - gather * 0.32 + airbornePose * 0.68 - strikePose * 0.88 - brace * 0.18;
      leftAnkle.position.x -= gather * 0.035 + airbornePose * 0.055 + brace * 0.025;
      rightAnkle.position.x += gather * 0.035 + airbornePose * 0.055 + brace * 0.025;
      leftAnkle.rotation.z = -gather * 0.05 - airbornePose * 0.14 + slamPose * 0.08;
      rightAnkle.rotation.z = gather * 0.05 + airbornePose * 0.14 - slamPose * 0.08;
    } else if (action?.name === 'absolute_reflect_cast') {
      const plant = THREE.MathUtils.smoothstep(progress, 0, 0.13);
      const lock = THREE.MathUtils.smoothstep(progress, 0.1, 0.2);
      const release = THREE.MathUtils.smoothstep(progress, 0.82, 1);
      const guardPose = plant * lock * (1 - release);

      // Both arms remain outside the torso silhouette: the free flipper braces
      // the shield while the sword stays clearly visible beside the body.
      hitBodyPivot.position.y -= guardPose * 0.105;
      hitBodyPivot.position.z += guardPose * 0.085;
      hitBodyPivot.rotation.x = -guardPose * 0.1;
      hitBodyPivot.rotation.y = guardPose * 0.12;
      head.rotation.x -= guardPose * 0.12;
      head.rotation.y += guardPose * 0.08;
      leftShoulder.position.x -= guardPose * 0.06;
      leftShoulder.position.z += guardPose * 0.08;
      leftShoulder.rotation.x = -guardPose * 0.34;
      leftShoulder.rotation.y = -guardPose * 0.16;
      leftShoulder.rotation.z = -guardPose * 0.58;
      rightShoulder.position.x += guardPose * 0.06;
      rightShoulder.position.z += guardPose * 0.08;
      rightShoulder.rotation.x = -guardPose * 0.3;
      rightShoulder.rotation.y = guardPose * 0.18;
      rightShoulder.rotation.z = guardPose * 0.46;
      rightHand.rotation.x = -guardPose * 0.12;
      rightHand.rotation.y = -guardPose * 0.12;
      rightHand.rotation.z = -guardPose * 0.05;
      sword.rotation.x = -guardPose * 0.22;
      sword.rotation.y = guardPose * 0.12;
      sword.rotation.z = -0.69 - guardPose * 0.72;
      leftAnkle.position.x -= guardPose * 0.055;
      rightAnkle.position.x += guardPose * 0.055;
      leftAnkle.rotation.z = -guardPose * 0.08;
      rightAnkle.rotation.z = guardPose * 0.08;
    } else if (action?.name === 'victory') {
      const cheer = Math.sin(progress * Math.PI * 4) * (1 - progress * 0.45);
      rig.position.y += Math.max(0, cheer) * 0.13;
      rig.rotation.z += cheer * 0.055;
      head.rotation.x -= Math.max(0, cheer) * 0.1;
      leftShoulder.rotation.z = -0.72 - cheer * 0.18;
      rightShoulder.rotation.z = 0.72 + cheer * 0.15;
    } else if (action?.name === 'defeat') {
      const fall = 1 - Math.pow(1 - progress, 3);
      rig.rotation.z = -fall * 1.25;
      rig.position.x = -fall * 0.22;
      rig.position.y -= fall * 0.16;
      head.rotation.z += fall * 0.18;
    }
  };
  group.userData.animate(0);
  return group;
}
