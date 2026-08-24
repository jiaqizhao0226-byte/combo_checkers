import * as THREE from '../../vendor/three.module.js';
import { markMesh } from './materials.js';

const SQRT3 = Math.sqrt(3);
export const BOARD_RADIUS = 4;
export const HEX_RADIUS = 0.72;
// Match the local VFX review board: cell centres retain the gameplay spacing,
// while the visible top face is slightly inset over a full-size lower base.
// The tapered sides expose a clean seam without changing any logical cells.
export const TILE_RADIUS = HEX_RADIUS * (0.78 / 0.82);
export const TILE_HEIGHT = 0.17;
const TILE_BASE_RADIUS = HEX_RADIUS;
const TILE_CENTER_Y = 0.18 - TILE_HEIGHT * 0.5;

const BOARD_THEMES = {
  forest: {
    base: [0x214b5e, 0x28566a],
    hero: [0x0f6f78, 0x0eb7bf, 0.22],
    route: [0x087a79, 0x20e4d4, 0.3],
    target: [0x7d4517, 0xff8c22, 0.42],
  },
  abyss_trench: {
    base: [0x1d5c73, 0x256b81, 0x2e7b8d],
    hero: [0x176f80, 0x31c7c4, 0.26],
    route: [0x117b88, 0x43d8ca, 0.32],
    target: [0x783c28, 0xff8355, 0.44],
  },
};

export function axialKey(q, r) {
  return `${q},${r}`;
}

export function axialToWorld(q, r) {
  return new THREE.Vector3(
    HEX_RADIUS * SQRT3 * (q + r / 2),
    TILE_CENTER_Y,
    HEX_RADIUS * 1.5 * r
  );
}

export function createHexBoard(scene, options = {}) {
  const theme = typeof options === 'string' ? options : options.theme || 'forest';
  const palette = BOARD_THEMES[theme] || BOARD_THEMES.forest;
  const group = new THREE.Group();
  group.name = 'HexBoard';
  group.userData.theme = theme;
  scene.add(group);

  const cells = [];
  const byKey = new Map();
  // CylinderGeometry already starts as a pointy-top hexagon in the XZ plane.
  // The smaller upper radius mirrors the review board and creates visible,
  // even seams; the full-size base keeps the board from reading as floating
  // individual tiles.
  const geometry = new THREE.CylinderGeometry(TILE_RADIUS, TILE_BASE_RADIUS, TILE_HEIGHT, 6);

  for (let q = -BOARD_RADIUS; q <= BOARD_RADIUS; q += 1) {
    const rMin = Math.max(-BOARD_RADIUS, -q - BOARD_RADIUS);
    const rMax = Math.min(BOARD_RADIUS, -q + BOARD_RADIUS);

    for (let r = rMin; r <= rMax; r += 1) {
      const colorIndex = Math.abs(q * 2 - r + (q + r) * 3) % palette.base.length;
      const baseColor = palette.base[colorIndex];
      const material = new THREE.MeshStandardMaterial({
        color: baseColor,
        roughness: 0.78,
        metalness: 0,
      });
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
      cell.mesh.position.y = TILE_CENTER_Y;
    }
  }

  function setState(cell, state) {
    if (!cell) return;
    const material = cell.mesh.material;
    if (state === 'hero') {
      material.color.setHex(palette.hero[0]);
      material.emissive.setHex(palette.hero[1]);
      material.emissiveIntensity = palette.hero[2];
    } else if (state === 'route') {
      material.color.setHex(palette.route[0]);
      material.emissive.setHex(palette.route[1]);
      material.emissiveIntensity = palette.route[2];
    } else if (state === 'target') {
      material.color.setHex(palette.target[0]);
      material.emissive.setHex(palette.target[1]);
      material.emissiveIntensity = palette.target[2];
      cell.mesh.position.y = TILE_CENTER_Y + 0.06;
    }
  }

  return { group, cells, get, clearStates, setState, theme };
}
