import * as THREE from '../../vendor/three.module.js';

const clamp01 = value => Math.max(0, Math.min(1, value));
const easeOutCubic = value => 1 - Math.pow(1 - clamp01(value), 3);

function material(color, roughness = 0.86, emissive = 0x000000, emissiveIntensity = 0) {
  return new THREE.MeshStandardMaterial({
    color,
    roughness,
    metalness: 0,
    emissive,
    emissiveIntensity,
    flatShading: false,
  });
}

function add(group, geometry, surface, position, scale = [1, 1, 1], name = '') {
  const mesh = new THREE.Mesh(geometry, surface);
  mesh.position.set(...position);
  mesh.scale.set(...scale);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  if (name) mesh.name = name;
  group.add(mesh);
  return mesh;
}

function createContactShadow() {
  const shadow = new THREE.Mesh(
    new THREE.CircleGeometry(0.52, 32),
    new THREE.MeshBasicMaterial({
      color: 0x06141a,
      transparent: true,
      opacity: 0.32,
      depthWrite: false,
      toneMapped: false,
    })
  );
  shadow.rotation.x = -Math.PI * 0.5;
  shadow.position.y = 0.012;
  shadow.scale.set(0.92, 0.62, 1);
  return shadow;
}

export function createScarecrowModel() {
  const group = new THREE.Group();
  group.name = 'ComboScarecrowApprovedModel';

  const visual = new THREE.Group();
  visual.name = 'ScarecrowReadableRig';
  group.add(visual);

  const wood = material(0x604027, 0.96);
  const woodCut = material(0x966638, 0.92);
  const straw = material(0xd8aa49, 0.94, 0x3f2906, 0.03);
  const strawLight = material(0xe9c667, 0.92, 0x4e3509, 0.035);
  const burlap = material(0xb88a58, 0.98);
  const burlapLight = material(0xcda66d, 0.97);
  // Keep the entire character within one straw-and-burlap family. The coat,
  // patch and hat differ by value and roughness, not by unrelated accent hues.
  const coat = material(0xc39a54, 0.96);
  const coatDark = material(0x8c6a3e, 0.98);
  const patch = material(0x9b7846, 0.97);
  const hat = material(0x765333, 0.98);
  const hatBand = material(0xb38b4d, 0.96);
  const stitch = new THREE.MeshBasicMaterial({ color: 0x25150f, toneMapped: false });

  // A full T-shaped wooden frame remains visible around the clothes. From the
  // locked battle camera this is the strongest scarecrow silhouette cue.
  const post = add(visual, new THREE.CylinderGeometry(0.062, 0.082, 1.42, 10), wood,
    [0, 0.68, -0.13], [1, 1, 1], 'ScarecrowVerticalWoodPost');
  add(visual, new THREE.CylinderGeometry(0.065, 0.085, 0.56, 10), woodCut,
    [0, 0.26, 0.08], [1, 1, 1], 'ScarecrowExposedGroundStake');
  const postCut = add(visual, new THREE.CylinderGeometry(0.084, 0.084, 0.025, 10), woodCut,
    [0, 1.39, -0.13], [1, 1, 1], 'ScarecrowWoodPostCut');
  postCut.rotation.x = 0;
  const crossbar = add(visual, new THREE.CylinderGeometry(0.06, 0.066, 1.48, 10), wood,
    [0, 1.0, -0.1], [1, 1, 1], 'ScarecrowCrossWood');
  crossbar.rotation.z = Math.PI * 0.5;

  const torso = add(visual, new THREE.DodecahedronGeometry(0.42, 1), coat,
    [0, 0.77, 0.015], [0.82, 0.92, 0.58], 'ScarecrowTornCoat');
  torso.rotation.z = -0.025;
  add(visual, new THREE.BoxGeometry(0.5, 0.095, 0.29), coatDark,
    [0, 0.55, 0.045], [1, 1, 1], 'ScarecrowCoatHem');

  // Three uneven cloth points make the coat read as stuffed, torn fabric
  // instead of a compact humanoid torso.
  [-0.16, 0, 0.16].forEach((x, index) => {
    const hem = add(visual, new THREE.ConeGeometry(0.09, 0.26 - index * 0.025, 5),
      index === 1 ? coatDark : coat, [x, 0.43 + (index % 2) * 0.02, 0.04], [1, 1, 0.78], `ScarecrowTornHem${index + 1}`);
    hem.rotation.z = (index - 1) * 0.1;
  });

  const belt = add(visual, new THREE.TorusGeometry(0.28, 0.024, 7, 28), strawLight,
    [0, 0.69, 0.075], [1, 0.62, 1], 'ScarecrowRopeBelt');
  belt.rotation.x = Math.PI * 0.5;

  const chestPatch = add(visual, new THREE.BoxGeometry(0.18, 0.17, 0.026), patch,
    [-0.105, 0.8, 0.265], [1, 1, 1], 'ScarecrowChestPatch');
  chestPatch.rotation.z = -0.13;
  add(visual, new THREE.BoxGeometry(0.018, 0.15, 0.014), stitch,
    [-0.105, 0.8, 0.281], [1, 1, 1], 'ScarecrowPatchStitchVertical');
  add(visual, new THREE.BoxGeometry(0.15, 0.018, 0.014), stitch,
    [-0.105, 0.8, 0.282], [1, 1, 1], 'ScarecrowPatchStitchHorizontal');

  const leftSleeve = add(visual, new THREE.CapsuleGeometry(0.105, 0.36, 5, 12), coat,
    [-0.42, 1.0, 0.015], [1, 1, 0.8], 'ScarecrowSleeveLeft');
  leftSleeve.rotation.z = Math.PI * 0.5;
  const rightSleeve = add(visual, new THREE.CapsuleGeometry(0.105, 0.36, 5, 12), coat,
    [0.42, 1.0, 0.015], [1, 1, 0.8], 'ScarecrowSleeveRight');
  rightSleeve.rotation.z = Math.PI * 0.5;

  const handRoots = [];
  [-1, 1].forEach(side => {
    const handRoot = new THREE.Group();
    handRoot.name = side < 0 ? 'ScarecrowStrawHandLeft' : 'ScarecrowStrawHandRight';
    handRoot.position.set(side * 0.67, 1.0, 0.015);
    visual.add(handRoot);
    handRoots.push(handRoot);
    [-0.14, 0, 0.14].forEach((fan, index) => {
      const tuft = add(handRoot, new THREE.ConeGeometry(0.036, 0.29, 6),
        index === 1 ? strawLight : straw,
        [side * 0.09, fan * 0.28, Math.abs(fan) * 0.11], [1, 1, 0.86], `ScarecrowHandStraw${side < 0 ? 'L' : 'R'}${index + 1}`);
      tuft.rotation.z = side * -Math.PI * 0.5 + fan;
    });
    const binding = add(handRoot, new THREE.TorusGeometry(0.065, 0.018, 6, 18), strawLight,
      [side * -0.015, 0, 0.005], [1, 0.72, 1], `ScarecrowHandBinding${side < 0 ? 'L' : 'R'}`);
    binding.rotation.y = Math.PI * 0.5;
  });

  // A wide burlap face, large button eyes and a stitched mouth stay readable
  // even when the character occupies only a few dozen pixels on a phone.
  const headRig = new THREE.Group();
  headRig.name = 'ScarecrowBurlapHeadRig';
  headRig.position.set(0, 1.29, 0.035);
  visual.add(headRig);
  add(headRig, new THREE.SphereGeometry(0.32, 30, 20), burlap,
    [0, 0, 0], [0.94, 1.02, 0.78], 'ScarecrowBurlapHead');
  add(headRig, new THREE.SphereGeometry(0.067, 14, 9), stitch,
    [-0.11, 0.055, 0.25], [1, 0.88, 0.4], 'ScarecrowButtonEyeLeft');
  add(headRig, new THREE.SphereGeometry(0.067, 14, 9), stitch,
    [0.11, 0.055, 0.25], [1, 0.88, 0.4], 'ScarecrowButtonEyeRight');
  const nose = add(headRig, new THREE.ConeGeometry(0.067, 0.19, 8), strawLight,
    [0, -0.015, 0.295], [1, 1, 1], 'ScarecrowStrawNose');
  nose.rotation.x = Math.PI * 0.5;
  const mouth = add(headRig, new THREE.BoxGeometry(0.25, 0.028, 0.018), stitch,
    [0, -0.11, 0.262], [1, 1, 1], 'ScarecrowStitchedMouth');
  mouth.rotation.z = -0.05;
  [-0.075, 0, 0.075].forEach((x, index) => {
    const mouthStitch = add(headRig, new THREE.BoxGeometry(0.018, 0.073, 0.016), stitch,
      [x, -0.105, 0.264], [1, 1, 1], `ScarecrowMouthStitch${index + 1}`);
    mouthStitch.rotation.z = index === 1 ? 0.08 : -0.08;
  });
  // Small cloth seams connect the head visually to the stuffed body.
  [-0.23, 0.23].forEach((x, index) => {
    const seam = add(headRig, new THREE.BoxGeometry(0.08, 0.018, 0.014), burlapLight,
      [x, -0.02 + index * 0.03, 0.22], [1, 1, 1], `ScarecrowFaceSeam${index + 1}`);
    seam.rotation.z = index ? 0.55 : -0.55;
  });

  const hatRig = new THREE.Group();
  hatRig.name = 'ScarecrowFloppyHatRig';
  // The entire character leans toward the locked high camera. A rearward hat
  // offset compounded that tilt and made the brim read as a floating object
  // behind the head. Seat it slightly lower and forward so the brim visibly
  // overlaps the burlap crown from the actual gameplay angle.
  hatRig.position.set(0, 0.245, 0.08);
  hatRig.rotation.z = 0.09;
  headRig.add(hatRig);
  // The brim is deliberately shallow front-to-back so the high battle camera
  // can still see the burlap face instead of reducing the hat to a round ring.
  add(hatRig, new THREE.CylinderGeometry(0.41, 0.39, 0.055, 14), hat,
    [0, 0, 0], [1, 1, 0.42], 'ScarecrowFloppyHatBrim');
  add(hatRig, new THREE.ConeGeometry(0.29, 0.34, 12), hat,
    [0.025, 0.18, -0.015], [0.92, 1, 0.78], 'ScarecrowFloppyHatCrown');
  add(hatRig, new THREE.CylinderGeometry(0.29, 0.29, 0.065, 14), hatBand,
    [0.025, 0.085, -0.005], [1, 1, 0.78], 'ScarecrowHatBand');

  [-0.22, -0.08, 0.08, 0.22].forEach((x, index) => {
    const hair = add(headRig, new THREE.ConeGeometry(0.026, 0.25 + (index % 2) * 0.04, 6),
      index % 2 ? strawLight : straw, [x, 0.19, -0.105], [1, 1, 0.9], `ScarecrowStrawHair${index + 1}`);
    hair.rotation.z = x * 1.05;
  });

  // Straw dangling below the coat and the exposed stake remove the impression
  // of a small armored unit standing on two legs.
  [-0.17, 0, 0.17].forEach((x, index) => {
    const lowerStraw = add(visual, new THREE.ConeGeometry(0.045, 0.31 + (index % 2) * 0.05, 6),
      index === 1 ? strawLight : straw, [x, 0.34, -0.015], [1, 1, 0.86], `ScarecrowLowerStraw${index + 1}`);
    lowerStraw.rotation.z = (index - 1) * 0.14;
  });

  const contactShadow = createContactShadow();
  group.add(contactShadow);
  group.userData.contactShadow = contactShadow;
  const healthBar = new THREE.Group();
  healthBar.name = 'ScarecrowHiddenInternalHealthBar';
  healthBar.visible = false;
  group.add(healthBar);
  group.userData.healthBar = healthBar;

  group.scale.setScalar(0.98);
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
    const progress = action ? clamp01((time - action.startedAt) / action.duration) : 0;
    const breeze = Math.sin(time * 2.05 + group.id) * 0.027;
    visual.position.set(0, 0, 0);
    // Lean the face plane toward the locked high camera. The feet remain at
    // the cell anchor, but the facial features and vertical stake stop
    // collapsing into a top-down silhouette.
    visual.rotation.set(-0.34, 0, breeze);
    visual.scale.set(1, 1, 1);
    headRig.rotation.set(0, 0, -breeze * 0.52);
    hatRig.rotation.z = 0.09 + breeze * 1.6;
    leftSleeve.rotation.z = Math.PI * 0.5 + breeze * 0.55;
    rightSleeve.rotation.z = Math.PI * 0.5 - breeze * 0.55;
    handRoots[0].rotation.z = breeze * 0.45;
    handRoots[1].rotation.z = -breeze * 0.45;
    if (action?.name === 'spawn') {
      const pop = easeOutCubic(progress);
      visual.position.y = (1 - pop) * 0.48;
      visual.rotation.y = (1 - pop) * Math.PI * 0.65;
      visual.scale.setScalar(0.5 + pop * 0.5);
    } else if (action?.name === 'hit') {
      const recoil = Math.sin(progress * Math.PI);
      const shake = Math.sin(progress * Math.PI * 6) * (1 - progress);
      visual.position.x = shake * 0.085;
      visual.rotation.x = -0.34 + recoil * 0.14;
      visual.rotation.z += shake * 0.11;
      headRig.rotation.z -= shake * 0.18;
    }
  };
  group.userData.animate(0);
  return group;
}
