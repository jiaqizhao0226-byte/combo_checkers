import assert from 'node:assert/strict';
import * as THREE from '../vendor/three.module.js';

import {
  HEX_RADIUS, TILE_RADIUS, axialToWorld, createHexBoard,
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

assert(tileDepth > tileWidth,
  'tile geometry must be pointy-top, matching the original DrawHex orientation');
assert(Math.abs(tileDepth - TILE_RADIUS * 2) < 1e-6,
  'pointy tips must span the configured tile diameter');
assert(eastCenterDistance - tileWidth < HEX_RADIUS * 0.02,
  'adjacent cells must be nearly edge-to-edge instead of leaving large gaps');
assert(eastCenterDistance - tileWidth >= -1e-6,
  'neighboring cells must not overlap each other');

console.log('hex board geometry tests passed');
