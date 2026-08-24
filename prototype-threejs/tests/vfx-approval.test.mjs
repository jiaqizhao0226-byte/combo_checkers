import assert from 'node:assert/strict';
import {
  APPROVED_BATTLE_VFX,
  VFX_TEST_MODE,
  VFX_TEST_PRESETS,
  isBattleVfxApproved,
} from '../src/vfx/VfxTestConfig.js';

assert.equal(VFX_TEST_MODE, true, 'local VFX laboratory should remain available during development');
assert(VFX_TEST_PRESETS.length > 0, 'prototype effects should remain available for local review');
assert.deepEqual(APPROVED_BATTLE_VFX, [
  'hero_melee_impact', 'enemy_damage_number', 'hero_hit_reaction', 'tracking_shuriken',
  'scarecrow_reward', 'hex_blast', 'life_drain', 'time_stop', 'meteor_aoe', 'absolute_reflect',
],
  'only explicitly approved combat VFX may enter normal play');
assert.equal(isBattleVfxApproved('tracking_shuriken'), true,
  'the explicitly reviewed tracking shuriken should be available in normal combat');
assert.equal(isBattleVfxApproved('hero_melee_impact'), true,
  'the reviewed hero melee impact should be available in normal combat');
assert.equal(isBattleVfxApproved('enemy_attack_impact'), false,
  'enemy attack feedback still requires a separate review');
assert.equal(isBattleVfxApproved('enemy_damage_number'), true,
  'the reviewed ordinary enemy damage number should be available in normal combat');
assert.equal(isBattleVfxApproved('hero_hit_reaction'), true,
  'the reviewed grounded hero hit reaction should be available in normal combat');
['scarecrow_reward', 'hex_blast', 'life_drain', 'time_stop', 'meteor_aoe', 'absolute_reflect']
  .forEach(effectId => assert.equal(isBattleVfxApproved(effectId), true,
    `${effectId} was explicitly approved and should be available in normal combat`));
console.log('vfx approval gate tests passed');
