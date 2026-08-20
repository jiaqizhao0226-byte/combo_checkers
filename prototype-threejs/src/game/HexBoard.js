import * as THREE from '../../vendor/three.module.js';
import { RAMPS, toon, markMesh } from './materials.js';

const SQRT3 = Math.sqrt(3);
export const BOARD_RADIUS = 4;
export const HEX_RADIUS = 0.72;
export const TILE_RADIUS = HEX_RADIUS * 0.995;

export function axialKey(q, r) {
  return `${q},${r}`;
}

export function axialToWorld(q, r) {
  return new THREE.Vector3(
    HEX_RADIUS * SQRT3 * (q + r / 2),
    0.08,
    HEX_RADIUS * 1.5 * r
  );
}

export function createHexBoard(scene) {
  const group = new THREE.Group();
  group.name = 'HexBoard';
  scene.add(group);

  const cells = [];
  const byKey = new Map();
  // CylinderGeometry already starts as a pointy-top hexagon in the XZ plane.
  // The axial coordinate formula below is also pointy-top. Rotating the mesh
  // by 30 degrees made it flat-top while preserving pointy-top spacing, which
  // opened large triangular holes between every three neighboring cells.
  const geometry = new THREE.CylinderGeometry(TILE_RADIUS, TILE_RADIUS, 0.2, 6);

  for (let q = -BOARD_RADIUS; q <= BOARD_RADIUS; q += 1) {
    const rMin = Math.max(-BOARD_RADIUS, -q - BOARD_RADIUS);
    const rMax = Math.min(BOARD_RADIUS, -q + BOARD_RADIUS);

    for (let r = rMin; r <= rMax; r += 1) {
      const baseColor = (q - r) % 2 === 0 ? 0x214b5e : 0x28566a;
      const material = toon(baseColor, RAMPS.stone);
      const mesh = markMesh(new THREE.Mesh(geometry, material));
      mesh.position.copy(axialToWorld(q, r));
      mesh.userData.cell = { q, r };
      mesh.userData.baseColor = baseColor;
      mesh.name = `Hex_${q}_${r}`;
      group.add(mesh);

      const cell = { q, r, mesh, key: axialKey(q, r) };
      cells.push(cell);
      byKey.set(cell.key, cell);
    }
  }

  function get(q, r) {
    return byKey.get(axialKey(q, r));
  }

  function clearStates() {
    for (const cell of cells) {
      cell.mesh.material.color.setHex(cell.mesh.userData.baseColor);
      cell.mesh.material.emissive.setHex(0x000000);
      cell.mesh.material.emissiveIntensity = 0;
      cell.mesh.position.y = 0.08;
    }
  }

  function setState(cell, state) {
    if (!cell) return;
    const material = cell.mesh.material;
    if (state === 'hero') {
      material.color.setHex(0x0f6f78);
      material.emissive.setHex(0x0eb7bf);
      material.emissiveIntensity = 0.22;
    } else if (state === 'route') {
      material.color.setHex(0x087a79);
      material.emissive.setHex(0x20e4d4);
      material.emissiveIntensity = 0.3;
    } else if (state === 'target') {
      material.color.setHex(0x7d4517);
      material.emissive.setHex(0xff8c22);
      material.emissiveIntensity = 0.42;
      cell.mesh.position.y = 0.14;
    }
  }

  return { group, cells, get, clearStates, setState };
}
