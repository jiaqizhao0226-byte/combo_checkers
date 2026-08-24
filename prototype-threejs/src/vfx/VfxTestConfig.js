// Development-only switch for the in-battle VFX laboratory.
// Keep this false for release builds. When false the test button is not drawn
// and none of the test-only controls can be triggered.
export const VFX_TEST_MODE = true;

// Production battle integration is approval-driven. New effects must first
// live in the local test panel; add an id here only after explicit visual
// approval. The whitelist remains deliberately narrow so prototypes cannot
// leak into normal combat just because their presentation event already exists.
export const APPROVED_BATTLE_VFX = Object.freeze([
  'hero_melee_impact',
  'enemy_damage_number',
  'hero_hit_reaction',
  'tracking_shuriken',
  'scarecrow_reward',
  'hex_blast',
  'life_drain',
  'time_stop',
  'meteor_aoe',
  'absolute_reflect',
]);

export function isBattleVfxApproved(effectId) {
  return APPROVED_BATTLE_VFX.includes(effectId);
}

export const VFX_TEST_PRESETS = Object.freeze([
  { id: 'impact_light', effect: 'impact', label: '跳斩命中', group: '攻击反馈', icon: '╱', strong: false },
  { id: 'impact_heavy', effect: 'impact', label: '蓄力重斩', group: '攻击反馈', icon: '✦', strong: true },
  { id: 'lightning_chain', effect: 'lightning', label: '连锁闪电', group: '技能特效', icon: '⚡' },
  { id: 'quake_land', effect: 'quake', label: '震地落', group: '技能特效', icon: '⬡' },
  { id: 'tracking_dart', effect: 'dart', label: '追踪飞镖', group: '战斗物件', icon: '✥' },
  { id: 'scarecrow_model', effect: 'scarecrow', label: '稻草人模型', group: '战斗物件', icon: '木' },
  { id: 'combo_hex_blast', effect: 'combo_reward', combo: 4, label: '四连 · 六芒冲击波', group: '连击奖励', icon: '✦' },
  { id: 'combo_life_drain', effect: 'combo_reward', combo: 5, label: '五连 · 生命虹吸', group: '连击奖励', icon: '绿' },
  { id: 'combo_time_stop', effect: 'combo_reward', combo: 6, label: '六连 · 时间静止', group: '连击奖励', icon: '时' },
  { id: 'combo_meteor', effect: 'combo_reward', combo: 7, label: '七连 · 流星火雨', group: '连击奖励', icon: '火' },
  { id: 'combo_reflect', effect: 'combo_reward', combo: 8, label: '八连 · 绝对反射', group: '连击奖励', icon: '盾' },
  { id: 'ui_skill_choice', effect: 'skill_choice_ui', label: '技能三选一', group: '界面测试', icon: 'UI' },
]);
