import * as THREE from '../../vendor/three.module.js';
import { RAMPS, toon, markMesh } from './materials.js';
import { createPenguinCandidate } from '../../hero-review/PenguinCandidate.js';
import { createSlimeCandidate } from '../../model-review/SlimeCandidate.js';
import { createEnemyCandidate } from '../../model-review/EnemyCandidates.js';
import { createScarecrowModel } from './ScarecrowModel.js';

function add(group, geometry, material, position, scale = [1, 1, 1]) {
  const mesh = markMesh(new THREE.Mesh(geometry, material));
  mesh.position.set(...position);
  mesh.scale.set(...scale);
  group.add(mesh);
  return mesh;
}

function latheBody(profile, segments = 14) {
  const points = profile.map(([radius, y]) => new THREE.Vector2(radius, y));
  return new THREE.LatheGeometry(points, segments);
}

function addContactShadow(group, width, depth, opacity = 0.27) {
  const material = new THREE.MeshBasicMaterial({
    color: 0x07110f,
    transparent: true,
    opacity,
    depthWrite: false,
    toneMapped: false,
  });
  const geometry = new THREE.CircleGeometry(0.5, 18);
  geometry.rotateX(-Math.PI / 2);
  const shadow = new THREE.Mesh(geometry, material);
  shadow.position.y = 0.012;
  shadow.scale.set(width * 2, 1, depth * 2);
  shadow.renderOrder = 1;
  group.add(shadow);
  group.userData.contactShadow = shadow;
  shadow.userData.baseOpacity = opacity;
}

function penguinBeak() {
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.Float32BufferAttribute([
    -0.14, 0.07, 0, 0.14, 0.07, 0, 0, 0, 0.22,
    0.14, 0.07, 0, 0.11, -0.045, 0, 0, 0, 0.22,
    0.11, -0.045, 0, -0.11, -0.045, 0, 0, 0, 0.22,
    -0.11, -0.045, 0, -0.14, 0.07, 0, 0, 0, 0.22,
    -0.14, 0.07, 0, -0.11, -0.045, 0, 0.11, -0.045, 0,
    -0.14, 0.07, 0, 0.11, -0.045, 0, 0.14, 0.07, 0,
  ], 3));
  geometry.computeVertexNormals();
  geometry.computeBoundingSphere();
  return geometry;
}

function penguinFlipper() {
  const shape = new THREE.Shape();
  shape.moveTo(-0.09, 0.22);
  shape.bezierCurveTo(-0.14, 0.04, -0.11, -0.2, 0, -0.38);
  shape.bezierCurveTo(0.13, -0.2, 0.16, 0.05, 0.09, 0.22);
  shape.closePath();
  return new THREE.ExtrudeGeometry(shape, {
    depth: 0.09,
    bevelEnabled: false,
    steps: 1,
    curveSegments: 4,
  });
}

function swordBlade(length, width, depth) {
  const shape = new THREE.Shape();
  shape.moveTo(-width * 0.5, 0);
  shape.lineTo(-width * 0.44, length * 0.78);
  shape.lineTo(0, length);
  shape.lineTo(width * 0.44, length * 0.78);
  shape.lineTo(width * 0.5, 0);
  shape.closePath();
  const geometry = new THREE.ExtrudeGeometry(shape, {
    depth,
    bevelEnabled: false,
    steps: 1,
  });
  geometry.translate(0, 0, -depth * 0.5);
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
  group.position.set(0, 0.08, 0.48);
  group.userData.fill = fill;
  return group;
}

export function createLegacyPenguin() {
  const group = new THREE.Group();
  group.name = 'PenguinHero';
  const visual = new THREE.Group();
  visual.name = 'PenguinCombatRig';
  group.add(visual);

  const black = toon(0x173441, RAMPS.character, 0x07141d, 0.04);
  const deepBlack = toon(0x091b25, RAMPS.character);
  const flipperBlack = toon(0x214b5d, RAMPS.character, 0x0b2732, 0.08);
  const white = toon(0xfff1cc, RAMPS.soft);
  const teal = toon(0x21b9ac, RAMPS.character, 0x075e59, 0.1);
  const orange = toon(0xff9827, RAMPS.character, 0x7a3007, 0.06);
  const metal = toon(0xd9f4ef, RAMPS.metal, 0x4b7176, 0.16);
  const dark = new THREE.MeshBasicMaterial({ color: 0x071018 });
  const faceWhite = toon(0xfff5d8, RAMPS.soft);
  const beakOrange = toon(0xffa22e, RAMPS.character, 0x7c3005, 0.08);
  const eyeGlint = new THREE.MeshBasicMaterial({ color: 0xffffff, toneMapped: false });

  // Compact pear-shaped torso: the black outer silhouette and broad cream
  // belly must still read as a penguin when the unit is only a few dozen
  // pixels tall on a phone.
  add(visual, latheBody([
    [0, 0.09], [0.3, 0.11], [0.44, 0.28], [0.49, 0.55],
    [0.45, 0.79], [0.32, 0.98], [0.15, 1.06], [0, 1.07],
  ], 22), black, [0, 0, 0], [0.92, 0.96, 0.82]);

  const belly = add(visual, new THREE.SphereGeometry(0.4, 22, 15), white, [0, 0.54, 0.32], [0.82, 1.06, 0.28]);
  belly.name = 'PenguinCreamBelly';

  const headRig = new THREE.Group();
  headRig.name = 'PenguinHead';
  headRig.position.set(0, 1.12, 0.015);
  visual.add(headRig);
  add(headRig, new THREE.SphereGeometry(0.47, 24, 17), deepBlack, [0, 0, 0], [1.02, 1.02, 0.95]);

  // Two raised cheek patches create the unmistakable heart-shaped penguin
  // face. They catch the scene light, unlike the old flat mask which read as
  // a vague human face from the battle camera.
  const leftPatch = add(headRig, new THREE.SphereGeometry(0.29, 18, 12), faceWhite,
    [-0.13, -0.035, 0.36], [0.78, 1.05, 0.28]);
  leftPatch.name = 'PenguinFacePatchLeft';
  const rightPatch = add(headRig, new THREE.SphereGeometry(0.29, 18, 12), faceWhite,
    [0.13, -0.035, 0.36], [0.78, 1.05, 0.28]);
  rightPatch.name = 'PenguinFacePatchRight';
  const chinPatch = add(headRig, new THREE.SphereGeometry(0.3, 18, 12), faceWhite,
    [0, -0.18, 0.355], [0.88, 0.52, 0.26]);
  chinPatch.name = 'PenguinFaceChin';

  add(headRig, new THREE.SphereGeometry(0.064, 12, 8), dark, [-0.125, 0.07, 0.44], [0.82, 1.16, 0.48]);
  add(headRig, new THREE.SphereGeometry(0.064, 12, 8), dark, [0.125, 0.07, 0.44], [0.82, 1.16, 0.48]);
  add(headRig, new THREE.SphereGeometry(0.019, 7, 5), eyeGlint, [-0.143, 0.096, 0.477]);
  add(headRig, new THREE.SphereGeometry(0.019, 7, 5), eyeGlint, [0.107, 0.096, 0.477]);
  const beak = add(headRig, penguinBeak(), beakOrange, [0, -0.07, 0.425], [1.02, 1.04, 1.08]);
  beak.name = 'PenguinBeak3D';

  const leftFlipper = add(visual, penguinFlipper(), flipperBlack, [-0.37, 0.73, 0.02], [1.08, 1.1, 1.05]);
  leftFlipper.name = 'PenguinFlipperLeft';
  leftFlipper.rotation.z = -0.98;
  const rightFlipper = add(visual, penguinFlipper(), flipperBlack, [0.37, 0.72, 0.02], [1.08, 1.1, 1.05]);
  rightFlipper.name = 'PenguinFlipperRight';
  rightFlipper.rotation.z = 0.52;

  // A front scarf band replaces the old full torus collar, which looked like
  // a helmet or float ring from the near-top-down view.
  const scarfBand = add(visual, new THREE.CapsuleGeometry(0.052, 0.46, 4, 10), teal, [0, 0.94, 0.255]);
  scarfBand.rotation.z = Math.PI * 0.5;
  add(visual, new THREE.OctahedronGeometry(0.1, 0), teal, [0.25, 0.91, 0.31], [0.9, 1, 0.62]);
  const scarfTail = add(visual, new THREE.BoxGeometry(0.13, 0.38, 0.07), teal, [0.32, 0.72, 0.16]);
  scarfTail.rotation.z = -0.3;
  add(visual, new THREE.OctahedronGeometry(0.09, 0), teal, [0.37, 0.5, 0.16], [0.76, 1.2, 0.46]);

  const leftFoot = add(visual, new THREE.SphereGeometry(0.16, 12, 7), orange, [-0.23, 0.105, 0.23], [1.3, 0.32, 1.7]);
  leftFoot.rotation.y = -0.2;
  leftFoot.rotation.z = -0.08;
  const rightFoot = add(visual, new THREE.SphereGeometry(0.16, 12, 7), orange, [0.21, 0.1, 0.16], [1.27, 0.32, 1.62]);
  rightFoot.rotation.y = 0.2;
  rightFoot.rotation.z = 0.1;

  const sword = new THREE.Group();
  sword.name = 'PenguinSword';
  add(sword, swordBlade(0.76, 0.145, 0.08), metal, [0, 0, 0]);
  add(sword, new THREE.BoxGeometry(0.026, 0.57, 0.086), white, [-0.03, 0.29, 0]);
  add(sword, new THREE.BoxGeometry(0.28, 0.07, 0.1), orange, [0, -0.03, 0]);
  add(sword, new THREE.BoxGeometry(0.09, 0.25, 0.1), black, [0, -0.18, 0]);
  add(sword, new THREE.OctahedronGeometry(0.065, 0), teal, [0, -0.04, 0.07]);
  sword.position.set(0.47, 0.62, 0.1);
  sword.rotation.z = -0.72;
  visual.add(sword);

  addContactShadow(group, 0.43, 0.29, 0.3);
  const healthBar = makeHealthBar(0x42f1df);
  group.add(healthBar);
  group.userData.healthBar = healthBar;
  // The rig's face is authored toward local +Z. Keep the root unrotated so the
  // battle controller can make +Z the audience-facing idle direction and turn
  // the whole character toward its actual travel vector.
  group.rotation.y = 0;
  group.scale.setScalar(1.06);

  group.userData.action = null;
  group.userData.animationTime = 0;
  group.userData.playAction = (name, duration = 0.45) => {
    group.userData.action = { name, duration, startedAt: group.userData.animationTime || 0 };
  };
  group.userData.animate = (time, moving = false) => {
    group.userData.animationTime = time;
    let action = group.userData.action;
    if (action && time - action.startedAt >= action.duration) {
      group.userData.action = null;
      action = null;
    }
    const actionProgress = action ? Math.min(1, (time - action.startedAt) / action.duration) : 0;
    const locomotion = action?.name === 'move' || moving;
    const beat = Math.round(Math.sin(time * 3.4) * 3) / 3;
    const flutter = Math.round(Math.sin(time * 5.8 + 0.8) * 3) / 3;
    const cycle = time % 4.2;
    const ready = cycle < 0.62 ? Math.sin((cycle / 0.62) * Math.PI) : 0;
    visual.position.set(0, locomotion ? 0.035 : 0, 0);
    visual.scale.set(1, 1, 1);
    // Keep the travel pose centered. The gait below already supplies a broad
    // left/right waddle; a second fixed side lean caused a visible snap back
    // after the root had already arrived on its destination cell.
    visual.rotation.set(0, 0, -0.075 + beat * 0.012 - ready * 0.045);
    headRig.rotation.set(0, 0, (locomotion ? 0.1 : 0.025) - beat * 0.018 + ready * 0.035);
    leftFlipper.rotation.z = (locomotion ? -1.18 : -0.98) - beat * 0.035 - ready * 0.14;
    rightFlipper.rotation.z = (locomotion ? 0.68 : 0.52) + beat * 0.025 + ready * 0.08;
    sword.rotation.set(0, 0, (locomotion ? -1.08 : -0.72) + beat * 0.035 - ready * 0.3);
    scarfTail.rotation.z = (locomotion ? -0.52 : -0.24) + flutter * 0.055;
    leftFoot.rotation.z = -0.08 - beat * 0.018;
    rightFoot.rotation.z = 0.1 + beat * 0.018;

    if (action?.name === 'move') {
      // A large, fast waddle survives the small on-board render size. Moving
      // the feet, head, flippers and sword in opposite phases keeps it from
      // reading as a rigid model sliding across the cell.
      const gait = Math.sin(actionProgress * Math.PI * 4);
      const stepLift = Math.abs(Math.sin(actionProgress * Math.PI * 4));
      visual.position.y += stepLift * 0.09;
      visual.rotation.z += gait * 0.16;
      headRig.rotation.z -= gait * 0.12;
      leftFlipper.rotation.z -= gait * 0.22;
      rightFlipper.rotation.z -= gait * 0.18;
      leftFoot.rotation.z = -0.08 + gait * 0.24;
      rightFoot.rotation.z = 0.1 - gait * 0.24;
      sword.rotation.z -= gait * 0.2;
      scarfTail.rotation.z -= gait * 0.18;
    } else if (action?.name === 'jump_attack') {
      // Three readable beats: raise the sword, cut through the target, then
      // compress on landing. The angles are deliberately broad for portrait
      // phone screens and the near-top-down battle camera.
      const windup = actionProgress < 0.28 ? actionProgress / 0.28 : 1;
      const cut = actionProgress < 0.28 ? 0
        : actionProgress < 0.7 ? (actionProgress - 0.28) / 0.42
          : 1;
      const landing = actionProgress < 0.7 ? 0 : Math.sin((actionProgress - 0.7) / 0.3 * Math.PI);
      const strikePunch = Math.sin(cut * Math.PI);
      visual.position.z = strikePunch * 0.13;
      visual.position.y += windup * 0.08 - landing * 0.12;
      visual.rotation.x = -strikePunch * 0.28 + landing * 0.16;
      visual.rotation.z -= strikePunch * 0.18;
      visual.scale.set(1 + landing * 0.16, 1 - landing * 0.22, 1 + landing * 0.16);
      headRig.rotation.x = strikePunch * 0.18;
      leftFlipper.rotation.z = -1.18 - strikePunch * 0.46;
      rightFlipper.rotation.z = 0.18 - cut * 0.62;
      sword.rotation.z = 0.55 - cut * 3.35;
      sword.rotation.x = -strikePunch * 0.34;
      sword.rotation.y = strikePunch * 0.45;
      sword.scale.setScalar(1 + strikePunch * 0.16);
      scarfTail.rotation.z -= strikePunch * 0.72;
    } else if (action?.name === 'land') {
      const squash = Math.sin(actionProgress * Math.PI);
      visual.position.y -= squash * 0.11;
      visual.position.z += squash * 0.04;
      visual.scale.set(1 + squash * 0.14, 1 - squash * 0.2, 1 + squash * 0.14);
      headRig.rotation.x = squash * 0.13;
      leftFlipper.rotation.z -= squash * 0.3;
      rightFlipper.rotation.z += squash * 0.22;
      scarfTail.rotation.z -= squash * 0.35;
    } else if (action?.name === 'pickup') {
      const reach = Math.sin(actionProgress * Math.PI);
      const nod = Math.sin(actionProgress * Math.PI * 2) * (1 - actionProgress);
      visual.position.y -= reach * 0.08;
      visual.rotation.x = reach * 0.16;
      headRig.rotation.x = 0.2 + reach * 0.28;
      headRig.rotation.z += nod * 0.08;
      leftFlipper.rotation.z = -1.35 + reach * 0.24;
      rightFlipper.rotation.z = 0.85 - reach * 0.2;
      sword.rotation.z = -1.45;
    } else if (action?.name === 'cast') {
      const charge = Math.sin(Math.min(1, actionProgress * 1.7) * Math.PI * 0.5);
      const release = actionProgress < 0.48 ? 0 : Math.sin((actionProgress - 0.48) / 0.52 * Math.PI);
      visual.position.y += charge * 0.08;
      visual.rotation.x = -release * 0.13;
      headRig.rotation.x = -0.12 + release * 0.18;
      leftFlipper.rotation.z = -1.48 - charge * 0.18;
      rightFlipper.rotation.z = 0.12 - charge * 0.38;
      sword.rotation.z = -1.46 - release * 0.42;
      sword.rotation.x = -charge * 0.28;
      sword.scale.setScalar(1 + charge * 0.13);
      scarfTail.rotation.z -= release * 0.42;
    } else if (action?.name === 'hit') {
      const recoil = Math.sin(actionProgress * Math.PI);
      const shake = Math.sin(actionProgress * Math.PI * 6) * (1 - actionProgress);
      visual.position.x = shake * 0.085;
      visual.position.z = -recoil * 0.1;
      visual.rotation.x = recoil * 0.22;
      visual.scale.set(1 + recoil * 0.08, 1 - recoil * 0.12, 1 + recoil * 0.08);
      headRig.rotation.z += shake * 0.16;
      leftFlipper.rotation.z -= recoil * 0.42;
      rightFlipper.rotation.z += recoil * 0.38;
      sword.rotation.z += recoil * 0.55;
    } else if (action?.name === 'victory') {
      const cheer = Math.sin(actionProgress * Math.PI * 4) * (1 - actionProgress * 0.45);
      visual.position.y += Math.max(0, cheer) * 0.13;
      leftFlipper.rotation.z = -1.45 - cheer * 0.2;
      rightFlipper.rotation.z = 1.15 + cheer * 0.16;
      sword.rotation.z = -1.48;
    } else if (action?.name === 'defeat') {
      const fall = 1 - Math.pow(1 - actionProgress, 3);
      visual.rotation.z = -0.075 - fall * 1.3;
      visual.position.y = -fall * 0.2;
    }
    if (action?.name !== 'jump_attack') sword.scale.setScalar(1);
  };
  group.userData.animate(0, false);
  return group;
}

// The V2 model was approved in the isolated hero review page. Keep the old
// constructor above only for side-by-side review; every game-facing import of
// createPenguin now receives the approved jointed model.
export function createPenguin() {
  const group = createPenguinCandidate();
  group.name = 'PenguinHero';
  group.userData.modelVersion = 'v2';
  const healthBar = makeHealthBar(0x42f1df);
  group.add(healthBar);
  group.userData.healthBar = healthBar;
  return group;
}

function createLegacyScarecrow() {
  const group = new THREE.Group();
  group.name = 'ComboScarecrow';
  const visual = new THREE.Group();
  visual.name = 'ScarecrowRig';
  group.add(visual);

  const wood = toon(0x755036, RAMPS.character, 0x2d1a0e, 0.05);
  const straw = toon(0xe5b94e, RAMPS.soft, 0x6b3d0b, 0.06);
  const burlap = toon(0xc89a59, RAMPS.soft, 0x553016, 0.04);
  const coat = toon(0x586b87, RAMPS.character, 0x222c40, 0.06);
  const coatDark = toon(0x394760, RAMPS.character);
  const patch = toon(0x9d5a54, RAMPS.soft);
  const hat = toon(0x7a4c30, RAMPS.character, 0x2e170d, 0.04);
  const hatBand = toon(0x2a7f78, RAMPS.character, 0x0c3e3b, 0.08);
  const stitch = new THREE.MeshBasicMaterial({ color: 0x24150f, toneMapped: false });

  const post = add(visual, new THREE.CylinderGeometry(0.055, 0.075, 1.28, 7), wood, [0, 0.62, -0.09]);
  post.name = 'ScarecrowPost';
  const crossbar = add(visual, new THREE.CylinderGeometry(0.052, 0.062, 1.02, 7), wood, [0, 0.93, -0.06]);
  crossbar.name = 'ScarecrowCrossbar';
  crossbar.rotation.z = Math.PI * 0.5;

  const torso = add(visual, new THREE.DodecahedronGeometry(0.35, 0), coat, [0, 0.69, 0.03], [0.83, 1.05, 0.52]);
  torso.name = 'ScarecrowCoat';
  add(visual, new THREE.BoxGeometry(0.48, 0.075, 0.24), coatDark, [0, 0.52, 0.08]);
  const chestPatch = add(visual, new THREE.BoxGeometry(0.16, 0.15, 0.025), patch, [-0.1, 0.72, 0.24]);
  chestPatch.rotation.z = -0.12;
  add(visual, new THREE.BoxGeometry(0.02, 0.14, 0.012), stitch, [-0.1, 0.72, 0.257]);
  add(visual, new THREE.BoxGeometry(0.13, 0.018, 0.012), stitch, [-0.1, 0.72, 0.258]);

  const leftSleeve = add(visual, new THREE.CapsuleGeometry(0.085, 0.34, 4, 8), coat, [-0.37, 0.88, 0.02]);
  leftSleeve.name = 'ScarecrowSleeveLeft';
  leftSleeve.rotation.z = Math.PI * 0.5;
  const rightSleeve = add(visual, new THREE.CapsuleGeometry(0.085, 0.34, 4, 8), coat, [0.37, 0.88, 0.02]);
  rightSleeve.name = 'ScarecrowSleeveRight';
  rightSleeve.rotation.z = Math.PI * 0.5;

  [-1, 1].forEach(side => {
    for (let index = -1; index <= 1; index += 1) {
      const tuft = add(visual, new THREE.ConeGeometry(0.026, 0.24, 5), straw,
        [side * (0.63 + Math.abs(index) * 0.015), 0.9 + index * 0.035, 0.02 + Math.abs(index) * 0.025]);
      tuft.rotation.z = side * -Math.PI * 0.5 + index * 0.14;
    }
  });
  [-0.14, 0.14].forEach((x, index) => {
    const legTuft = add(visual, new THREE.ConeGeometry(0.075, 0.34, 7), straw, [x, 0.29, 0]);
    legTuft.rotation.z = index === 0 ? -0.16 : 0.16;
  });

  const headRig = new THREE.Group();
  headRig.name = 'ScarecrowHead';
  headRig.position.set(0, 1.18, 0.015);
  visual.add(headRig);
  add(headRig, new THREE.DodecahedronGeometry(0.29, 1), burlap, [0, 0, 0], [0.9, 1.02, 0.78]);
  add(headRig, new THREE.SphereGeometry(0.046, 7, 5), stitch, [-0.105, 0.055, 0.225], [1, 0.8, 0.45]);
  add(headRig, new THREE.SphereGeometry(0.046, 7, 5), stitch, [0.105, 0.055, 0.225], [1, 0.8, 0.45]);
  const nose = add(headRig, new THREE.ConeGeometry(0.052, 0.16, 5), straw, [0, -0.015, 0.275]);
  nose.rotation.x = Math.PI * 0.5;
  const mouth = add(headRig, new THREE.BoxGeometry(0.2, 0.022, 0.018), stitch, [0, -0.11, 0.235]);
  mouth.rotation.z = -0.05;
  [-0.07, 0, 0.07].forEach((x, index) => {
    const mouthStitch = add(headRig, new THREE.BoxGeometry(0.018, 0.07, 0.016), stitch, [x, -0.11, 0.245]);
    mouthStitch.rotation.z = index === 1 ? 0.08 : -0.08;
  });

  const hatRig = new THREE.Group();
  hatRig.name = 'ScarecrowHat';
  hatRig.position.set(0, 0.27, -0.015);
  hatRig.rotation.z = 0.13;
  headRig.add(hatRig);
  add(hatRig, new THREE.CylinderGeometry(0.4, 0.36, 0.055, 10), hat, [0, 0, 0], [1, 1, 0.82]);
  add(hatRig, new THREE.ConeGeometry(0.29, 0.34, 8), hat, [0.025, 0.18, -0.02], [0.9, 1, 0.86]);
  add(hatRig, new THREE.CylinderGeometry(0.3, 0.3, 0.065, 10), hatBand, [0.025, 0.085, 0]);
  [-0.2, 0, 0.2].forEach((x, index) => {
    const hair = add(headRig, new THREE.ConeGeometry(0.025, 0.25 + index * 0.02, 5), straw,
      [x, 0.18, -0.12]);
    hair.rotation.z = x * 1.3;
  });

  addContactShadow(group, 0.45, 0.29, 0.28);
  const healthBar = makeHealthBar(0xe5b94e);
  group.add(healthBar);
  group.userData.healthBar = healthBar;
  group.scale.setScalar(0.78);
  group.userData.action = null;
  group.userData.animationTime = 0;
  group.userData.playAction = (name, duration = 0.5) => {
    group.userData.action = { name, duration, startedAt: group.userData.animationTime || 0 };
  };
  group.userData.animate = time => {
    group.userData.animationTime = time;
    let action = group.userData.action;
    if (action && time - action.startedAt >= action.duration) {
      group.userData.action = null;
      action = null;
    }
    const progress = action ? Math.min(1, (time - action.startedAt) / action.duration) : 0;
    const breeze = Math.sin(time * 2.2 + group.id) * 0.035;
    visual.position.set(0, 0, 0);
    visual.rotation.set(0, 0, breeze);
    visual.scale.set(1, 1, 1);
    headRig.rotation.set(0, 0, -breeze * 0.55);
    hatRig.rotation.z = 0.13 + breeze * 1.8;
    leftSleeve.rotation.z = Math.PI * 0.5 + breeze * 0.7;
    rightSleeve.rotation.z = Math.PI * 0.5 - breeze * 0.7;
    if (action?.name === 'spawn') {
      const pop = 1 - Math.pow(1 - progress, 3);
      visual.position.y = (1 - pop) * 0.55;
      visual.rotation.y = (1 - pop) * Math.PI * 0.8;
      visual.scale.setScalar(0.45 + pop * 0.55);
    } else if (action?.name === 'hit') {
      const recoil = Math.sin(progress * Math.PI);
      const shake = Math.sin(progress * Math.PI * 7) * (1 - progress);
      visual.position.x = shake * 0.1;
      visual.rotation.x = recoil * 0.17;
      visual.rotation.z += shake * 0.14;
      visual.scale.set(1 + recoil * 0.08, 1 - recoil * 0.14, 1 + recoil * 0.08);
      headRig.rotation.z -= shake * 0.2;
    }
  };
  group.userData.animate(0);
  return group;
}

export function createScarecrow() {
  const group = createScarecrowModel();
  const internalBar = group.userData.healthBar;
  if (internalBar) group.remove(internalBar);
  const healthBar = makeHealthBar(0x62e49f);
  healthBar.name = 'ScarecrowFriendlyHealthBar';
  healthBar.position.set(0, 2.36, 0.34);
  group.add(healthBar);
  group.userData.healthBar = healthBar;
  group.userData.modelVersion = 'approved-straw-v2';
  return group;
}

export function createLegacySlime() {
  const group = new THREE.Group();
  group.name = 'SlimeEnemy';
  const visual = new THREE.Group();
  visual.name = 'SlimeCombatRig';
  group.add(visual);
  const shell = new THREE.MeshPhysicalMaterial({
    color: 0x82df3c,
    emissive: 0x163b08,
    emissiveIntensity: 0.16,
    roughness: 0.2,
    metalness: 0,
    clearcoat: 1,
    clearcoatRoughness: 0.16,
    transparent: true,
    opacity: 0.9,
    flatShading: true,
  });
  const core = toon(0x3f8e20, RAMPS.gel, 0x163f09, 0.1);
  const underside = toon(0x315f21, RAMPS.gel);
  const dark = new THREE.MeshBasicMaterial({ color: 0x0b1510 });
  const eye = toon(0xeaffc8, RAMPS.soft);
  const shine = new THREE.MeshBasicMaterial({ color: new THREE.Color(0xe6ff9a).multiplyScalar(1.4), toneMapped: false });
  add(visual, latheBody([
    [0, 0.19], [0.22, 0.2], [0.31, 0.33], [0.3, 0.55],
    [0.23, 0.68], [0.1, 0.75], [0, 0.76],
  ], 14), core, [0, 0, 0.015], [0.82, 0.84, 0.76]);
  add(visual, latheBody([
    [0, 0.12], [0.3, 0.13], [0.44, 0.22], [0.48, 0.43],
    [0.43, 0.64], [0.3, 0.8], [0.12, 0.89], [0, 0.9],
  ], 18), shell, [0, 0, 0], [1, 1, 0.92]);
  add(visual, new THREE.SphereGeometry(0.21, 9, 6), shell, [-0.29, 0.22, 0.02], [1, 0.6, 0.84]);
  add(visual, new THREE.SphereGeometry(0.22, 9, 6), underside, [0, 0.16, 0.045], [1.1, 0.48, 0.9]);
  add(visual, new THREE.SphereGeometry(0.2, 9, 6), shell, [0.29, 0.22, 0.02], [1, 0.6, 0.84]);
  add(visual, new THREE.SphereGeometry(0.085, 7, 5), eye, [-0.14, 0.54, 0.36], [0.85, 1.05, 0.5]);
  add(visual, new THREE.SphereGeometry(0.085, 7, 5), eye, [0.14, 0.54, 0.36], [0.85, 1.05, 0.5]);
  add(visual, new THREE.SphereGeometry(0.04, 5, 3), dark, [-0.14, 0.54, 0.405]);
  add(visual, new THREE.SphereGeometry(0.04, 5, 3), dark, [0.14, 0.54, 0.405]);
  add(visual, new THREE.BoxGeometry(0.15, 0.035, 0.035), dark, [0, 0.39, 0.43]);
  add(visual, new THREE.SphereGeometry(0.075, 7, 5), shine, [-0.26, 0.67, 0.32], [0.62, 1, 0.3]);
  add(visual, new THREE.SphereGeometry(0.045, 6, 4), shine, [-0.18, 0.76, 0.28], [0.5, 0.72, 0.28]);
  add(visual, new THREE.SphereGeometry(0.035, 6, 4), shine, [0.27, 0.42, 0.39], [0.46, 0.72, 0.24]);
  add(visual, new THREE.SphereGeometry(0.08, 7, 5), toon(0xa8ed4b, RAMPS.soft), [0.12, 0.3, 0.21], [0.72, 1, 0.48]);
  add(visual, new THREE.ConeGeometry(0.11, 0.24, 7), shell, [0, 0.89, 0]);
  add(visual, new THREE.SphereGeometry(0.075, 8, 5), shell, [0, 1.02, 0]);
  addContactShadow(group, 0.42, 0.31, 0.28);
  const healthBar = makeHealthBar(0x75de45);
  group.add(healthBar);
  group.userData.healthBar = healthBar;
  // Slime facial features are authored toward local +Z. The battle controller
  // owns the runtime facing so every slime can track its current target.
  group.rotation.y = 0;
  group.userData.action = null;
  group.userData.animationTime = 0;
  group.userData.playAction = (name, duration = 0.4) => {
    group.userData.action = { name, duration, startedAt: group.userData.animationTime || 0 };
  };
  group.userData.animate = time => {
    group.userData.animationTime = time;
    let action = group.userData.action;
    if (action && time - action.startedAt >= action.duration) { group.userData.action = null; action = null; }
    const progress = action ? Math.min(1, (time - action.startedAt) / action.duration) : 0;
    const idle = Math.sin(time * 3.1 + group.id) * 0.035;
    visual.position.set(0, Math.max(0, idle) * 0.35, 0);
    visual.rotation.set(0, 0, idle * 0.12);
    visual.scale.set(1 - idle * 0.2, 1 + idle, 1 - idle * 0.2);
    if (action?.name === 'hit') {
      const recoil = Math.sin(progress * Math.PI);
      const shake = Math.sin(progress * Math.PI * 7) * (1 - progress);
      visual.position.x = shake * 0.09;
      visual.position.z = -recoil * 0.13;
      visual.scale.set(1 + recoil * 0.2, 1 - recoil * 0.3, 1 + recoil * 0.2);
    } else if (action?.name === 'attack') {
      const squash = Math.sin(progress * Math.PI);
      visual.position.z = squash * 0.08;
      visual.scale.set(1 - squash * 0.12, 1 + squash * 0.22, 1 - squash * 0.12);
    } else if (action?.name === 'move') {
      const hop = Math.sin(progress * Math.PI * 2);
      visual.position.y += Math.max(0, hop) * 0.08;
      visual.rotation.z += hop * 0.08;
    }
  };
  return group;
}

export function createAbyssKraken() {
  const group = new THREE.Group();
  group.name = 'AbyssKrakenBoss';
  const rig = new THREE.Group(); group.add(rig);
  const mantle = toon(0x502779, RAMPS.character, 0x241039, 0.14);
  const skin = toon(0x8d4bbb, RAMPS.character, 0x3f1d62, 0.12);
  const underside = toon(0xc78bd5, RAMPS.soft, 0x6a367b, 0.08);
  const crown = toon(0x44c9c4, RAMPS.metal, 0x17636b, 0.18);
  const eyeWhite = new THREE.MeshBasicMaterial({ color: 0xfff4d7, toneMapped: false });
  const eyeDark = new THREE.MeshBasicMaterial({ color: 0x12081d, toneMapped: false });
  const glow = new THREE.MeshBasicMaterial({ color: new THREE.Color(0xff4c9d).multiplyScalar(1.5), toneMapped: false });

  add(rig, latheBody([
    [0, 0.18], [0.48, 0.22], [0.67, 0.57], [0.64, 1.05],
    [0.5, 1.43], [0.24, 1.67], [0, 1.72],
  ], 20), mantle, [0, 0, 0], [1, 1, 0.83]);
  add(rig, new THREE.SphereGeometry(0.53, 18, 12), underside, [0, 0.93, 0.43], [0.76, 1.02, 0.25]);

  [-0.26, 0.26].forEach(x => {
    add(rig, new THREE.SphereGeometry(0.16, 12, 8), eyeWhite, [x, 1.28, 0.52], [0.9, 1.12, 0.35]);
    add(rig, new THREE.SphereGeometry(0.075, 8, 6), eyeDark, [x, 1.27, 0.59], [0.8, 1.15, 0.45]);
    add(rig, new THREE.SphereGeometry(0.023, 6, 4), glow, [x - 0.018, 1.3, 0.625]);
  });
  add(rig, new THREE.ConeGeometry(0.13, 0.28, 7), crown, [0, 1.86, 0]);
  [-0.38, -0.19, 0.19, 0.38].forEach((x, index) => {
    const spike = add(rig, new THREE.ConeGeometry(0.085, 0.33 + (index % 2) * 0.08, 6), crown, [x, 1.68 - Math.abs(x) * 0.12, -0.04]);
    spike.rotation.z = -x * 0.65;
  });

  const tentacleRigs = [];
  [-0.72, -0.5, -0.24, 0.24, 0.5, 0.72].forEach((x, index) => {
    const tentacle = new THREE.Group();
    tentacle.position.set(x, 0.22, index % 2 ? -0.08 : 0.08);
    for (let segment = 0; segment < 4; segment += 1) {
      const piece = add(tentacle, new THREE.CapsuleGeometry(0.11 - segment * 0.012, 0.28, 4, 7), segment % 2 ? skin : mantle,
        [x < 0 ? -segment * 0.1 : segment * 0.1, -segment * 0.18, segment * 0.08]);
      piece.rotation.z = (x < 0 ? 1 : -1) * (0.48 + segment * 0.09);
    }
    rig.add(tentacle); tentacleRigs.push(tentacle);
  });
  addContactShadow(group, 0.82, 0.5, 0.38);
  const healthBar = makeHealthBar(0xd957b8); healthBar.scale.set(1.55, 1.25, 1.25);
  healthBar.position.set(0, 0.06, 0.72); group.add(healthBar); group.userData.healthBar = healthBar;
  group.scale.setScalar(1.34);
  group.userData.animate = time => {
    rig.position.y = Math.sin(time * 1.8) * 0.035;
    rig.rotation.z = Math.sin(time * 1.15) * 0.025;
    tentacleRigs.forEach((tentacle, index) => { tentacle.rotation.y = Math.sin(time * 2 + index) * 0.16; });
  };
  return group;
}

export function createBattleObstacle(type = 'reef') {
  const group = new THREE.Group();
  group.name = type === 'tentacle' ? 'AbyssTentacle' : 'ReefJumpSupport';
  if (type === 'tentacle') {
    const purple = toon(0x6d3596, RAMPS.character, 0x2d1647, 0.12);
    const sucker = toon(0xd786c1, RAMPS.soft);
    for (let segment = 0; segment < 4; segment += 1) {
      const piece = add(group, new THREE.CapsuleGeometry(0.14 - segment * 0.018, 0.29, 4, 7), purple,
        [Math.sin(segment * 0.8) * 0.1, 0.18 + segment * 0.25, 0]);
      piece.rotation.z = Math.sin(segment * 0.9) * 0.22;
      if (segment < 3) add(group, new THREE.SphereGeometry(0.045, 6, 4), sucker, [-0.11, 0.2 + segment * 0.25, 0.1]);
    }
    group.userData.animate = time => { group.rotation.z = Math.sin(time * 2.6 + group.id) * 0.07; };
  } else {
    const rock = toon(0x355f64, RAMPS.stone, 0x183438, 0.06);
    const coral = toon(0x58b9aa, RAMPS.soft, 0x205f5c, 0.1);
    add(group, new THREE.DodecahedronGeometry(0.4, 0), rock, [0, 0.32, 0], [1, 0.8, 0.88]);
    add(group, new THREE.ConeGeometry(0.1, 0.42, 6), coral, [-0.16, 0.62, 0]);
    add(group, new THREE.ConeGeometry(0.08, 0.31, 6), coral, [0.12, 0.55, 0.04]);
  }
  addContactShadow(group, 0.38, 0.27, 0.26);
  group.scale.setScalar(type === 'tentacle' ? 0.86 : 0.9);
  return group;
}

export function createLegacyChapterOneEnemy(type = 'slime') {
  if (type === 'abyss_kraken') return createAbyssKraken();
  if (type === 'slime') return createLegacySlime();
  const group = new THREE.Group();
  group.name = `ChapterOneEnemy_${type}`;
  const palettes = {
    jellyfish: [0x72d7f2, 0xd8fbff], iron_turtle: [0x657b78, 0xb8cfb0],
    vortex_eel: [0x4269d8, 0x7de5ed], hermit_crab: [0xc66a35, 0xf2bd69],
    ghost_shark: [0x637caa, 0xc4e1ef], archerfish: [0xdba94a, 0x5ac5ca],
    electric_ray: [0x7357b7, 0xf0dc69],
  };
  const [mainColor, accentColor] = palettes[type] || palettes.jellyfish;
  const main = toon(mainColor, RAMPS.character, mainColor, 0.08);
  const accent = toon(accentColor, RAMPS.soft, accentColor, 0.12);
  const dark = new THREE.MeshBasicMaterial({ color: 0x071018 });
  const glow = new THREE.MeshBasicMaterial({ color: new THREE.Color(accentColor).multiplyScalar(1.45), toneMapped: false });
  const eye = (x, y, z, size = 0.045) => {
    add(group, new THREE.SphereGeometry(size, 7, 5), dark, [x, y, z]);
    add(group, new THREE.SphereGeometry(size * 0.28, 5, 3), glow, [x - size * 0.25, y + size * 0.25, z + size * 0.72]);
  };

  if (type === 'jellyfish') {
    add(group, new THREE.SphereGeometry(0.43, 14, 9, 0, Math.PI * 2, 0, Math.PI * 0.57), main, [0, 0.62, 0], [1, 0.92, 0.9]);
    add(group, new THREE.TorusGeometry(0.33, 0.08, 6, 14), accent, [0, 0.58, 0]).rotation.x = Math.PI / 2;
    [-0.24, -0.08, 0.08, 0.24].forEach((x, index) => {
      const tentacle = add(group, new THREE.CylinderGeometry(0.035, 0.055, 0.48 + (index % 2) * 0.13, 6), main, [x, 0.3 - (index % 2) * 0.05, 0]);
      tentacle.rotation.z = x * 0.45;
    });
    eye(-0.13, 0.7, 0.345); eye(0.13, 0.7, 0.345);
  } else if (type === 'iron_turtle') {
    add(group, new THREE.SphereGeometry(0.48, 12, 8), main, [0, 0.45, 0], [1.1, 0.68, 0.92]);
    add(group, new THREE.SphereGeometry(0.43, 9, 6), accent, [0, 0.51, -0.05], [1, 0.72, 0.82]);
    for (let i = 0; i < 6; i += 1) {
      const angle = i * Math.PI / 3;
      add(group, new THREE.BoxGeometry(0.2, 0.045, 0.035), main, [Math.sin(angle) * 0.28, 0.7, Math.cos(angle) * 0.24]).rotation.y = angle;
    }
    add(group, new THREE.SphereGeometry(0.23, 9, 6), main, [0, 0.43, 0.47], [0.9, 0.82, 1]);
    eye(-0.08, 0.48, 0.65, 0.04); eye(0.08, 0.48, 0.65, 0.04);
  } else if (type === 'vortex_eel') {
    add(group, new THREE.CapsuleGeometry(0.2, 0.92, 5, 10), main, [0, 0.53, 0], [1, 1, 0.78]).rotation.z = Math.PI / 2;
    add(group, new THREE.ConeGeometry(0.23, 0.42, 7), accent, [-0.66, 0.53, 0]).rotation.z = Math.PI / 2;
    add(group, new THREE.SphereGeometry(0.28, 10, 7), main, [0.48, 0.54, 0.02], [1, 0.8, 0.82]);
    eye(0.54, 0.62, 0.225); add(group, new THREE.TorusGeometry(0.56, 0.035, 5, 18), glow, [0, 0.2, 0]).rotation.x = Math.PI / 2;
  } else if (type === 'hermit_crab') {
    add(group, new THREE.SphereGeometry(0.42, 10, 7), accent, [0, 0.52, -0.13], [1.06, 1, 0.88]);
    add(group, new THREE.TorusGeometry(0.23, 0.095, 6, 12), main, [0, 0.55, -0.38]).rotation.x = Math.PI / 2;
    add(group, new THREE.SphereGeometry(0.28, 9, 6), main, [0, 0.35, 0.2], [1.18, 0.65, 0.86]);
    [-1, 1].forEach(side => {
      add(group, new THREE.SphereGeometry(0.18, 7, 5), main, [side * 0.42, 0.37, 0.27], [1, 0.72, 0.75]);
      add(group, new THREE.ConeGeometry(0.13, 0.27, 6), accent, [side * 0.54, 0.42, 0.38]).rotation.z = side * -0.75;
    });
    eye(-0.1, 0.48, 0.43); eye(0.1, 0.48, 0.43);
  } else if (type === 'electric_ray') {
    add(group, new THREE.OctahedronGeometry(0.57, 1), main, [0, 0.45, 0], [1.2, 0.32, 0.92]);
    add(group, new THREE.ConeGeometry(0.13, 0.62, 6), accent, [0, 0.43, -0.59]).rotation.x = -Math.PI / 2;
    eye(-0.12, 0.52, 0.36, 0.038); eye(0.12, 0.52, 0.36, 0.038);
    [-0.48, 0.48].forEach(x => add(group, new THREE.TorusGeometry(0.16, 0.028, 5, 10), glow, [x, 0.42, 0]).rotation.x = Math.PI / 2);
  } else {
    const shark = type === 'ghost_shark';
    add(group, new THREE.SphereGeometry(0.39, 12, 8), main, [0, 0.53, 0], [1.25, 0.68, 0.84]);
    add(group, new THREE.ConeGeometry(0.3, 0.52, 6), accent, [0, 0.53, -0.5]).rotation.x = -Math.PI / 2;
    add(group, new THREE.ConeGeometry(0.18, 0.35, 6), main, [0, 0.86, -0.08]).rotation.x = -0.2;
    eye(-0.14, 0.61, 0.31); eye(0.14, 0.61, 0.31);
    if (shark) {
      add(group, new THREE.ConeGeometry(0.2, 0.38, 6), accent, [-0.16, 0.52, -0.75]).rotation.z = -0.6;
      add(group, new THREE.ConeGeometry(0.2, 0.38, 6), accent, [0.16, 0.52, -0.75]).rotation.z = 0.6;
      group.traverse(child => { if (child.isMesh) child.material.transparent = true; if (child.isMesh) child.material.opacity = 0.78; });
    } else {
      add(group, new THREE.CylinderGeometry(0.07, 0.09, 0.42, 6), accent, [0, 0.37, 0.38]).rotation.x = Math.PI / 2;
    }
  }
  addContactShadow(group, 0.43, 0.3, 0.27);
  const healthBar = makeHealthBar(mainColor);
  group.add(healthBar);
  group.userData.healthBar = healthBar;
  group.scale.setScalar(type === 'iron_turtle' ? 0.88 : 0.94);
  return group;
}

function promoteApprovedEnemyModel(group, type) {
  group.name = type === 'slime' ? 'SlimeEnemy' : `ChapterOneEnemy_${type}`;
  group.userData.modelVersion = 'approved-chapter-one-v2';
  group.userData.enemyType = type;
  return group;
}

// The eight Chapter One models have passed the isolated model-review stage.
// Keep their procedural source shared with the review page so later visual
// refinements cannot silently diverge between the review board and the game.
export function createSlime() {
  return promoteApprovedEnemyModel(createSlimeCandidate(), 'slime');
}

export function createChapterOneEnemy(type = 'slime') {
  if (type === 'abyss_kraken') return createAbyssKraken();
  if (type === 'slime') return createSlime();
  const approvedModel = createEnemyCandidate(type);
  if (approvedModel) return promoteApprovedEnemyModel(approvedModel, type);
  return createLegacyChapterOneEnemy(type);
}

export function createSkeleton() {
  const group = new THREE.Group();
  group.name = 'SkeletonEnemy';
  const bone = toon(0xe4ddbd, RAMPS.stone);
  const dark = new THREE.MeshBasicMaterial({ color: 0x12141b });
  const metal = toon(0x9fb5b8, RAMPS.metal);
  const rust = toon(0x8e4b2e, RAMPS.soft);
  const eyeGlow = new THREE.MeshBasicMaterial({ color: new THREE.Color(0xef5350).multiplyScalar(1.8) });

  add(group, new THREE.DodecahedronGeometry(0.35, 1), bone, [0, 1.2, 0], [0.78, 0.8, 0.72]);
  add(group, new THREE.BoxGeometry(0.36, 0.16, 0.32), bone, [0, 0.94, 0.02]);
  add(group, new THREE.SphereGeometry(0.105, 7, 5), dark, [-0.13, 1.23, 0.225], [1, 0.9, 0.34]);
  add(group, new THREE.SphereGeometry(0.105, 7, 5), dark, [0.13, 1.23, 0.225], [1, 0.9, 0.34]);
  add(group, new THREE.SphereGeometry(0.032, 6, 4), eyeGlow, [-0.13, 1.23, 0.268]);
  add(group, new THREE.SphereGeometry(0.032, 6, 4), eyeGlow, [0.13, 1.23, 0.268]);
  add(group, new THREE.OctahedronGeometry(0.055, 0), dark, [0, 1.1, 0.235], [0.65, 0.85, 0.45]);
  add(group, new THREE.BoxGeometry(0.23, 0.055, 0.05), dark, [0, 0.98, 0.205]);
  add(group, new THREE.BoxGeometry(0.045, 0.07, 0.035), bone, [-0.075, 0.98, 0.238]);
  add(group, new THREE.BoxGeometry(0.045, 0.07, 0.035), bone, [0.075, 0.98, 0.238]);
  add(group, new THREE.CylinderGeometry(0.06, 0.06, 0.58, 5), bone, [0, 0.7, 0]);
  add(group, new THREE.BoxGeometry(0.48, 0.08, 0.1), bone, [0, 0.78, 0.05]);
  add(group, new THREE.BoxGeometry(0.36, 0.07, 0.08), bone, [0, 0.61, 0.05]);
  add(group, new THREE.BoxGeometry(0.28, 0.065, 0.075), bone, [0, 0.48, 0.04]);
  add(group, new THREE.SphereGeometry(0.095, 7, 4), bone, [-0.27, 0.79, 0]);
  add(group, new THREE.SphereGeometry(0.095, 7, 4), bone, [0.27, 0.79, 0]);
  add(group, new THREE.CylinderGeometry(0.05, 0.05, 0.5, 6), bone, [-0.31, 0.61, 0]).rotation.z = -0.28;
  add(group, new THREE.CylinderGeometry(0.05, 0.05, 0.5, 6), bone, [0.31, 0.61, 0]).rotation.z = 0.28;
  add(group, new THREE.SphereGeometry(0.08, 7, 4), bone, [-0.38, 0.38, 0]);
  add(group, new THREE.SphereGeometry(0.08, 7, 4), bone, [0.38, 0.38, 0]);
  add(group, new THREE.BoxGeometry(0.34, 0.13, 0.16), rust, [0, 0.38, 0]);
  add(group, new THREE.CylinderGeometry(0.055, 0.055, 0.46, 5), bone, [-0.12, 0.25, 0]);
  add(group, new THREE.CylinderGeometry(0.055, 0.055, 0.46, 5), bone, [0.12, 0.25, 0]);

  const sword = new THREE.Group();
  add(sword, swordBlade(0.58, 0.105, 0.07), metal, [0, 0, 0]);
  add(sword, new THREE.BoxGeometry(0.23, 0.07, 0.09), rust, [0, -0.04, 0]);
  sword.position.set(0.38, 0.74, 0.02);
  sword.rotation.z = -0.4;
  group.add(sword);
  addContactShadow(group, 0.34, 0.24, 0.26);
  group.add(makeHealthBar(0xef5350));
  group.rotation.y = Math.PI / 4;
  group.scale.setScalar(0.86);
  return group;
}
