import assert from 'node:assert/strict';
import {
  APPROVED_BATTLE_VFX,
  VFX_TEST_MODE,
  VFX_TEST_PRESETS,
  isBattleVfxApproved,
} from '../src/vfx/VfxTestConfig.js';

assert.equal(VFX_TEST_MODE, true, 'local VFX laboratory should remain available during development');
assert(VFX_TEST_PRESETS.length > 0, 'prototype effects should remain available for local review');
assert.deepEqual(APPROVED_BATTLE_VFX, [], 'normal combat must start with an empty VFX approval list');
assert.equal(isBattleVfxApproved('tracking_shuriken'), false,
  'the tracking shuriken must not enter normal combat before explicit approval');
assert.equal(isBattleVfxApproved('attack_impact'), false,
  'attack impact prototypes must not enter normal combat before explicit approval');

console.log('vfx approval gate tests passed');
