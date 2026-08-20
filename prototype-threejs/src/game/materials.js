import * as THREE from '../../vendor/three.module.js';

function createRamp(values) {
  const data = new Uint8Array(values.map(value => Math.round(value * 255)));
  const texture = new THREE.DataTexture(data, data.length, 1, THREE.RedFormat);
  texture.minFilter = THREE.NearestFilter;
  texture.magFilter = THREE.NearestFilter;
  texture.needsUpdate = true;
  return texture;
}

export const RAMPS = {
  soft: createRamp([0.28, 0.55, 0.82, 1.0]),
  character: createRamp([0.12, 0.36, 0.72, 1.0]),
  gel: createRamp([0.08, 0.3, 0.66, 1.0]),
  metal: createRamp([0.12, 0.28, 0.56, 1.0]),
  stone: createRamp([0.28, 0.46, 0.64, 0.82]),
};

export function toon(color, ramp = RAMPS.soft, emissive = 0x000000, intensity = 0) {
  return new THREE.MeshToonMaterial({
    color,
    gradientMap: ramp,
    emissive,
    emissiveIntensity: intensity,
  });
}

export function markMesh(mesh) {
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  return mesh;
}
