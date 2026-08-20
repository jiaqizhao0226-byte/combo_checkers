import * as THREE from '../../vendor/three.module.js';
import { markMesh } from '../game/materials.js';

function dartBladeGeometry() {
  const shape = new THREE.Shape();
  // Broad roots keep the spinning silhouette solid on a phone, while the
  // swept tip makes it read as a forged shuriken instead of an energy star.
  shape.moveTo(-0.055, 0.035);
  shape.lineTo(-0.13, 0.13);
  shape.lineTo(-0.085, 0.255);
  shape.quadraticCurveTo(-0.035, 0.355, 0.008, 0.445);
  shape.lineTo(0.135, 0.235);
  shape.lineTo(0.105, 0.105);
  shape.lineTo(0.045, 0.03);
  shape.closePath();
  const geometry = new THREE.ExtrudeGeometry(shape, {
    depth: 0.065,
    bevelEnabled: true,
    bevelSegments: 1,
    bevelSize: 0.014,
    bevelThickness: 0.014,
    steps: 1,
    curveSegments: 3,
  });
  geometry.translate(0, 0, -0.0325);
  geometry.computeVertexNormals();
  return geometry;
}

export function createTrackingDart(color = 0xffb64c) {
  const root = new THREE.Group();
  root.name = 'TrackingDartProjectile';
  const rotor = new THREE.Group();
  rotor.name = 'TrackingDartRotor';
  root.add(rotor);

  const energyColor = new THREE.Color(color || 0xffb64c);
  const bladeMaterial = new THREE.MeshPhysicalMaterial({
    color: 0xd0dade,
    metalness: 1,
    roughness: 0.2,
    clearcoat: 0.55,
    clearcoatRoughness: 0.12,
    flatShading: true,
  });
  const polishedMetal = new THREE.MeshPhysicalMaterial({
    color: 0xf0f7f6,
    metalness: 0.96,
    roughness: 0.08,
    clearcoat: 0.8,
    clearcoatRoughness: 0.05,
  });
  const hubMaterial = new THREE.MeshPhysicalMaterial({
    color: 0x263c46,
    metalness: 0.92,
    roughness: 0.3,
    clearcoat: 0.35,
  });
  const energyMaterial = new THREE.MeshBasicMaterial({
    color: energyColor.clone().multiplyScalar(1.25),
    toneMapped: false,
  });
  const bladeGeometry = dartBladeGeometry();
  const ridgeGeometry = new THREE.BoxGeometry(0.026, 0.275, 0.034);

  for (let index = 0; index < 4; index += 1) {
    const angle = index * Math.PI * 0.5;
    const blade = markMesh(new THREE.Mesh(bladeGeometry, bladeMaterial));
    blade.name = `TrackingDartBlade${index + 1}`;
    blade.rotation.z = angle;
    rotor.add(blade);

    // A raised polished spine creates a moving specular stripe as the weapon
    // spins, which supplies the metallic read that a flat toon shape lacked.
    const ridge = markMesh(new THREE.Mesh(ridgeGeometry, polishedMetal));
    ridge.name = `TrackingDartRidge${index + 1}`;
    ridge.position.set(0.018, 0.195, 0.052).applyAxisAngle(new THREE.Vector3(0, 0, 1), angle);
    ridge.rotation.z = angle - 0.08;
    rotor.add(ridge);
  }

  const hub = markMesh(new THREE.Mesh(new THREE.CylinderGeometry(0.132, 0.132, 0.09, 16), hubMaterial));
  hub.name = 'TrackingDartHub';
  hub.rotation.x = Math.PI * 0.5;
  rotor.add(hub);

  const metalRing = markMesh(new THREE.Mesh(new THREE.TorusGeometry(0.09, 0.018, 7, 18), polishedMetal));
  metalRing.name = 'TrackingDartMetalRing';
  metalRing.position.z = 0.054;
  rotor.add(metalRing);

  const gem = new THREE.Mesh(new THREE.OctahedronGeometry(0.055, 0), energyMaterial);
  gem.name = 'TrackingDartEnergyCore';
  gem.position.z = 0.076;
  gem.renderOrder = 35;
  rotor.add(gem);

  const trailMaterial = new THREE.MeshBasicMaterial({
    color: energyColor.clone().lerp(new THREE.Color(0xeafcff), 0.42).multiplyScalar(1.2),
    transparent: true,
    opacity: 0.76,
    depthWrite: false,
    blending: THREE.AdditiveBlending,
    toneMapped: false,
  });
  const trail = new THREE.Group();
  trail.name = 'TrackingDartTrail';
  for (let index = 0; index < 3; index += 1) {
    const mote = new THREE.Mesh(new THREE.OctahedronGeometry(0.04 - index * 0.007, 0), trailMaterial);
    mote.position.set(-0.31 - index * 0.13, (index - 1) * 0.05, 0);
    mote.scale.set(1.15, 0.55, 0.55);
    mote.renderOrder = 33;
    trail.add(mote);
  }
  root.add(trail);

  root.userData.rotor = rotor;
  root.userData.trailMaterial = trailMaterial;
  return root;
}

export function faceProjectileAlongScreen(projectile, direction, camera) {
  camera.updateMatrixWorld();
  const forward = direction.clone().normalize();
  const cameraRight = new THREE.Vector3().setFromMatrixColumn(camera.matrixWorld, 0).normalize();
  const cameraUp = new THREE.Vector3().setFromMatrixColumn(camera.matrixWorld, 1).normalize();
  const angle = Math.atan2(forward.dot(cameraUp), forward.dot(cameraRight));
  projectile.quaternion.copy(camera.quaternion);
  projectile.rotateZ(angle);
  return projectile;
}
