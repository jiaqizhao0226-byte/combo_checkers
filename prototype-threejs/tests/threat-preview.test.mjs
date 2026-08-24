import assert from 'node:assert/strict';

import { buildThreatLinks, threatLineStyle } from '../src/game/ThreatPreview.js';

const state = {
  phase: 'PLAYER_PLAN',
  hero: { q: 0, r: 2 },
  plan: [{ q: 1, r: 0 }],
  scarecrow: null,
  enemies: [
    { id: 'near', q: 1, r: -1, hp: 25, attack: 5 },
    { id: 'pending', q: -1, r: 0, hp: 25, attack: 5 },
    { id: 'dead', q: 2, r: -2, hp: 0, attack: 5 },
  ],
  threatPreview: [
    { enemyId: 'near', pending: false, distance: 1, damage: 5 },
    { enemyId: 'pending', pending: true, distance: 2, damage: 5 },
    { enemyId: 'dead', pending: false, distance: 1, damage: 5 },
  ],
};

assert.deepEqual(buildThreatLinks(state), [
  {
    enemyId: 'near', from: { q: 1, r: -1 }, to: { q: 1, r: 0 },
    target: 'hero', pending: false, distance: 1, damage: 5,
  },
  {
    enemyId: 'pending', from: { q: -1, r: 0 }, to: { q: 1, r: 0 },
    target: 'hero', pending: true, distance: 2, damage: 5,
  },
]);

state.phase = 'ENEMY_TURN';
state.scarecrow = { q: -2, r: 2, hp: 100 };
assert.deepEqual(
  buildThreatLinks(state).map(link => ({ enemyId: link.enemyId, to: link.to, target: link.target })),
  [
    { enemyId: 'near', to: { q: -2, r: 2 }, target: 'scarecrow' },
    { enemyId: 'pending', to: { q: -2, r: 2 }, target: 'scarecrow' },
  ],
  'a living scarecrow redirects every living enemy intent line during every phase'
);

const everydayImmediateStyle = threatLineStyle({ target: 'hero', pending: false, distance: 1 });
const scarecrowStyle = threatLineStyle({ target: 'scarecrow', pending: false, distance: null });
assert.deepEqual(scarecrowStyle, everydayImmediateStyle,
  '稻草人攻击预警必须完全复用普通即时伤害线样式');
assert(everydayImmediateStyle.radius < 0.05,
  '统一后的日常伤害线应比旧版更细');

console.log('threat preview tests passed');
