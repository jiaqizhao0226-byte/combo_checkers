import assert from 'node:assert/strict';
import * as THREE from '../vendor/three.module.js';

import {
  HEX_RADIUS, TILE_HEIGHT, TILE_RADIUS, axialToWorld, createHexBoard,
} from '../src/game/HexBoard.js';

const scene = new THREE.Scene();
const board = createHexBoard(scene);

assert.equal(board.cells.length, 61, 'radius-four board must retain the original 61 logical cells');

const center = board.get(0, 0);
const east = board.get(1, 0);
assert(center && east, 'board must contain adjacent center and east cells');

const expectedEast = axialToWorld(1, 0);
assert(Math.abs(east.mesh.position.x - expectedEast.x) < 1e-9,
  'visual cells must continue to use the original pointy-top axial coordinates');

const position = center.mesh.geometry.attributes.position;
let minX = Infinity;
let maxX = -Infinity;
let minZ = Infinity;
let maxZ = -Infinity;
for (let index = 0; index < position.count; index += 1) {
  minX = Math.min(minX, position.getX(index));
  maxX = Math.max(maxX, position.getX(index));
  minZ = Math.min(minZ, position.getZ(index));
  maxZ = Math.max(maxZ, position.getZ(index));
}

const tileWidth = maxX - minX;
const tileDepth = maxZ - minZ;
const eastCenterDistance = east.mesh.position.x - center.mesh.position.x;
const visibleTopWidth = Math.sqrt(3) * TILE_RADIUS;
const visibleTopGap = eastCenterDistance - visibleTopWidth;

assert(tileDepth > tileWidth,
  'tile geometry must be pointy-top, matching the original DrawHex orientation');
assert(Math.abs(tileDepth - HEX_RADIUS * 2) < 1e-6,
  'the lower tile base must retain the full pointy-top footprint');
assert.equal(center.mesh.geometry.parameters.radiusTop, TILE_RADIUS,
  'the visible top face must use the review-board inset radius');
assert.equal(center.mesh.geometry.parameters.radiusBottom, HEX_RADIUS,
  'the lower base must keep the original gameplay cell radius');
assert.equal(center.mesh.geometry.parameters.height, TILE_HEIGHT,
  'the formal board must use the review-board tile height');
assert(visibleTopGap > HEX_RADIUS * 0.07,
  'adjacent visible top faces must leave a clearly readable seam');
assert(visibleTopGap < HEX_RADIUS * 0.1,
  'the seam must remain narrow enough for the cells to read as one board');
assert(center.mesh.material.isMeshStandardMaterial,
  'formal board cells must use the same rough standard material as the review board');
assert.equal(center.mesh.material.roughness, 0.78,
  'formal board roughness must match the review board');

const abyssBoard = createHexBoard(new THREE.Scene(), { theme: 'abyss_trench' });
assert.equal(abyssBoard.theme, 'abyss_trench');
assert.equal(abyssBoard.group.userData.theme, 'abyss_trench');
assert.equal(abyssBoard.cells.length, 61);
const abyssBaseColors = new Set(abyssBoard.cells.map(cell => cell.mesh.userData.baseColor));
assert.equal(abyssBaseColors.size, 3,
  'abyss board must use a varied three-tone deep-sea stone palette');
for (const colorHex of abyssBaseColors) {
  const color = new THREE.Color(colorHex);
  assert(color.b > color.r * 1.4,
    'abyss board base colors must remain distinctly blue rather than forest green');
}
const abyssCenter = abyssBoard.get(0, 0);
abyssBoard.setState(abyssCenter, 'route');
assert(abyssCenter.mesh.material.emissive.b > abyssCenter.mesh.material.emissive.r,
  'abyss route state must use cold bioluminescent guidance');
abyssBoard.clearStates();
assert.equal(abyssCenter.mesh.material.color.getHex(), abyssCenter.mesh.userData.baseColor,
  'clearing board state must restore the abyss base material');

console.log('hex board geometry tests passed');
