// Development-only switch for the in-battle VFX laboratory.
// Keep this false for release builds. When false the test button is not drawn
// and none of the test-only controls can be triggered.
export const VFX_TEST_MODE = true;

// Production battle integration is approval-driven. New effects must first
// live in the local test panel; add an id here only after explicit visual
// approval. Keeping this list empty guarantees prototypes cannot leak into
// normal combat just because their presentation event already exists.
export const APPROVED_BATTLE_VFX = Object.freeze([]);

export function isBattleVfxApproved(effectId) {
  return APPROVED_BATTLE_VFX.includes(effectId);
}

export const VFX_TEST_PRESETS = Object.freeze([
  { id: 'impact_light', effect: 'impact', label: '跳斩命中', group: '攻击反馈', icon: '╱', strong: false },
  { id: 'impact_heavy', effect: 'impact', label: '蓄力重斩', group: '攻击反馈', icon: '✦', strong: true },
  { id: 'combo_3', effect: 'combo', label: '3 连击收束', group: '连击反馈', icon: '×3', combo: 3 },
  { id: 'combo_5', effect: 'combo', label: '5 连击收束', group: '连击反馈', icon: '×5', combo: 5 },
  { id: 'lightning_chain', effect: 'lightning', label: '连锁闪电', group: '技能特效', icon: '⚡' },
  { id: 'quake_land', effect: 'quake', label: '震地落', group: '技能特效', icon: '⬡' },
  { id: 'tracking_dart', effect: 'dart', label: '追踪飞镖', group: '战斗物件', icon: '✥' },
  { id: 'scarecrow_model', effect: 'scarecrow', label: '稻草人模型', group: '战斗物件', icon: '木' },
]);
