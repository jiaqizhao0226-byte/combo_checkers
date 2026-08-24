import assert from 'node:assert/strict';

import {
  comboDamage,
  createLevelOne,
  resistanceDamage,
} from '../src/core/LevelOne.js';
import { allCells } from '../src/core/HexRules.js';

const fixedRng = () => 0;

function resolveEnemyTurn(game) {
  const outcome = game.processEnemyTurn();
  if (!game.state.result) {
    assert.equal(game.state.phase, 'ENEMY_RESOLVE');
    assert.equal(game.startPlayerTurn(), true);
    assert.equal(game.state.phase, 'PLAYER_SELECT');
  }
  return outcome;
}

function resolveJumpExecution(game, start) {
  assert.equal(start.kind, 'jump_start');
  const steps = [];
  while (game.state.phase === 'PLAYER_EXECUTE') {
    const step = game.executeNextJump();
    assert.equal(step.kind, 'jump_step');
    steps.push(step);
    if (step.done) break;
  }
  const summary = game.finishJumpExecution();
  assert.equal(summary.kind, 'jump');
  return { summary, steps };
}

function finishRewardWait(game) {
  if (game.state.phase !== 'COMBO_REWARD_WAIT') return null;
  return game.completeComboRewardWait();
}

assert.equal(allCells().length, 61, 'radius-4 board must contain 61 cells');
assert.equal(resistanceDamage(5, 1), 5, 'slime damage must match the Lua resistance formula');
assert.deepEqual(
  [1, 2, 3, 4].map(combo => comboDamage(combo)),
  [15, 22, 30, 37],
  'jump damage must scale by 50% of base attack for every combo step'
);

const tutorial = createLevelOne({ rng: fixedRng });
assert.equal(tutorial.state.tutorialOverlay?.id, 'board');
assert.equal(tutorial.state.tutorialOverlay?.interaction, 'board');
assert.deepEqual(tutorial.availableActions().map(({ q, r }) => ({ q, r })), [{ q: -1, r: 4 }], '聚光灯只开放指定移动格');
assert.deepEqual(
  { q: tutorial.state.hero.q, r: tutorial.state.hero.r },
  { q: -2, r: 4 },
  'the hero must start at the original bottom-center cell'
);
assert.equal(tutorial.state.enemies.length, 0, 'first-ever 1-1 starts without enemies');
assert.equal(tutorial.state.items.length, 1, '1-1 starts with one non-wheel item');
assert(tutorial.availableActions().every(action => action.kind === 'move'));

let outcome = tutorial.select(-1, 4);
assert.equal(outcome.kind, 'move');
assert.equal(tutorial.state.tutorialOverlay, null, '点击聚光目标后移动教学应自动收起');
assert.equal(tutorial.state.turn, 1, 'the turn counter waits for the enemy phase');
assert.equal(tutorial.state.phase, 'ENEMY_TURN');
assert.equal(tutorial.state.enemies.length, 0, 'scripted spawning happens after enemy actions');
resolveEnemyTurn(tutorial);
assert.equal(tutorial.state.tutorialOverlay?.id, 'jump');
assert.deepEqual(tutorial.availableActions().map(({ q, r }) => ({ q, r })), [{ q: 1, r: 2 }], '基础跳跃只开放橙色落点');
assert.equal(tutorial.state.turn, 2);
assert.equal(tutorial.state.tutorialPhase, 1);
assert.equal(tutorial.state.enemies.length, 1);
assert.equal(tutorial.state.message, '敌人出现！跳过它即可攻击');

outcome = tutorial.select(1, 2);
assert.equal(outcome.kind, 'jump_start', 'a jump with no continuation begins execution');
assert.equal(tutorial.state.phase, 'PLAYER_EXECUTE');
assert.equal(tutorial.state.combo, 0, 'planning does not execute the hop immediately');
({ summary: outcome } = resolveJumpExecution(tutorial, outcome));
assert.equal(outcome.combo, 1);
assert(
  tutorial.state.presentationQueue.some(event => event.type === 'damage' && event.combo === 1),
  'jump damage presentation must carry its combo count for floating combat text'
);
assert.equal(tutorial.state.hero.hp, 100, 'the enemy must not act before the jump finishes');
resolveEnemyTurn(tutorial);
assert.equal(tutorial.state.tutorialOverlay?.id, 'multiHop');
assert.deepEqual(tutorial.availableActions().map(({ q, r }) => ({ q, r })), [{ q: 1, r: -2 }], '远距跳跃只开放路径终点');
assert.equal(tutorial.state.hero.hp, 95, 'an adjacent enemy attacks during its following enemy phase');
assert.equal(tutorial.state.tutorialPhase, 2);
assert.equal(tutorial.state.message, '直线上隔一格的敌人也能跳过');

outcome = tutorial.select(1, -2);
({ summary: outcome } = resolveJumpExecution(tutorial, outcome));
assert.equal(outcome.kind, 'jump');
resolveEnemyTurn(tutorial);
assert.equal(tutorial.state.tutorialOverlay?.id, 'chainJump');
assert.equal(tutorial.state.tutorialOverlay?.stage, 1);
assert.equal(tutorial.state.tutorialPhase, 3);
assert.equal(tutorial.state.message, '连续选择落点，完成二连跳');

outcome = tutorial.select(3, -4);
assert.equal(outcome.kind, 'planned', 'the scripted third lesson must offer a chain jump');
assert.equal(tutorial.state.tutorialOverlay?.stage, 2, '首跳规划后聚光灯应切换到第二个落点');
assert.equal(tutorial.state.phase, 'PLAYER_PLAN');
assert.equal(tutorial.state.plan.length, 1);
assert.deepEqual(
  tutorial.availableActions().map(({ q, r }) => ({ q, r })),
  [{ q: 1, r: -4 }]
);

outcome = tutorial.select(1, -4);
assert.equal(outcome.kind, 'jump_start', 'the last planned landing begins execution');
assert.equal(tutorial.state.tutorialOverlay, null, '第二个落点选中后路径教学自动结束');
({ summary: outcome } = resolveJumpExecution(tutorial, outcome));
assert.equal(outcome.combo, 2);
assert.equal(tutorial.state.lastReward?.name, '追踪飞镖');
assert(tutorial.state.presentationQueue.some(event => event.type === 'combo_burst'));
assert(tutorial.state.presentationQueue.some(event => event.type === 'announcement'));
assert.equal(tutorial.state.kills, 2, '原版无需技能也会在落地时对邻格造成基础冲击');
assert(tutorial.state.presentationQueue.some(event => event.type === 'death'), 'defeated enemies must queue a death presentation');
assert.equal(tutorial.state.gold, 2, 'a slime drops one gold in the original first level');
assert.equal(tutorial.state.phase, 'COMBO_REWARD_WAIT');
assert.equal(tutorial.state.tutorialOverlay?.id, 'combo');
tutorial.dismissTutorial();
finishRewardWait(tutorial);
resolveEnemyTurn(tutorial);
assert.equal(tutorial.state.tutorialPhase, 4);
assert.equal(tutorial.state.tutorialJustCompleted, true);
assert.equal(tutorial.state.message, '3 个敌人从外围出现了！');

const tapToConfirm = createLevelOne({ tutorialSeen: true, rng: fixedRng });
const [tapEnemyOne, tapEnemyTwo] = tapToConfirm.state.enemies;
tapToConfirm.state.enemies = [
  { ...tapEnemyOne, id: 'tap-enemy-1', q: -1, r: 3, hp: 25, maxHp: 25 },
  { ...tapEnemyTwo, id: 'tap-enemy-2', q: 1, r: 1, hp: 25, maxHp: 25 },
];
tapToConfirm.state.items = [];
tapToConfirm.state.obstacles = [];
let tapOutcome = tapToConfirm.select(0, 2);
assert.equal(tapOutcome.kind, 'planned', '有后续跳点时第一跳只进入规划状态');
tapOutcome = tapToConfirm.select(0, 2);
assert.equal(tapOutcome.kind, 'jump_start', '再次点击当前规划落点应直接开始执行连跳');
assert.equal(tapToConfirm.state.phase, 'PLAYER_EXECUTE');

const pickupFeedback = createLevelOne({ tutorialSeen: true, rng: fixedRng });
pickupFeedback.state.enemies = [];
pickupFeedback.state.items = [{ id: 'test-gold', type: 'gold_bag', q: -1, r: 4 }];
pickupFeedback.state.presentationQueue.length = 0;
const pickupMove = pickupFeedback.select(-1, 4);
assert.equal(pickupMove.kind, 'move');
assert.equal(pickupMove.item.amount, 10, 'gold pickup summary must expose its actual reward');
assert.equal(pickupMove.item.label, '+10 金币');
assert(
  pickupFeedback.state.presentationQueue.some(event => event.type === 'pickup' && event.amount === 10 && event.label === '+10 金币'),
  'pickup presentation must contain the value shown by floating text'
);

for (let step = 0; step < 60 && !tutorial.state.result; step += 1) {
  const action = tutorial.availableActions().find(candidate => candidate.kind === 'jump')
    || tutorial.availableActions().find(candidate => candidate.kind === 'move');
  assert(action, 'the mobility safeguard must always leave a legal action');
  const result = tutorial.select(action.q, action.r);
  const started = result.kind === 'planned' ? tutorial.confirm() : result;
  if (started.kind === 'jump_start') resolveJumpExecution(tutorial, started);
  finishRewardWait(tutorial);
  if (!tutorial.state.result && tutorial.state.phase === 'ENEMY_TURN') resolveEnemyTurn(tutorial);
}
assert.equal(tutorial.state.result, 'win');
assert.equal(tutorial.state.phase, 'WIN');
assert.equal(tutorial.state.kills, 5);
assert.equal(tutorial.state.gold, 5);
assert.equal(tutorial.state.skillChoices.length, 3, 'victory presents three skill choices');

const replay = createLevelOne({ tutorialSeen: true, rng: fixedRng });
assert.equal(replay.state.tutorialPhase, 4);
assert.equal(replay.state.enemies.length, 7, 'a replay after the tutorial starts with seven slimes');
assert.equal(replay.state.items.length, 1);
assert.equal(replay.state.killTarget, 5);

const moveThenAttack = createLevelOne({ rng: fixedRng });
moveThenAttack.state.items.length = 0;
Object.assign(moveThenAttack.state.hero, { q: 0, r: 2, hp: 100 });
moveThenAttack.state.tutorialPhase = 4;
moveThenAttack.state.enemies.push({
  id: 'timing-slime', type: 'slime', name: '史莱姆', q: 0, r: 0,
  hp: 25, maxHp: 25, attack: 5, defense: 0, gold: 1, stunnedTurns: 0,
});
moveThenAttack.state.phase = 'ENEMY_TURN';
let enemyOutcome = moveThenAttack.processEnemyTurn();
assert.equal(enemyOutcome.actions[0].type, 'move');
assert.equal(moveThenAttack.state.hero.hp, 100, 'a slime does not attack immediately after moving');
moveThenAttack.startPlayerTurn();
moveThenAttack.state.phase = 'ENEMY_TURN';
enemyOutcome = moveThenAttack.processEnemyTurn();
assert.equal(enemyOutcome.actions[0].type, 'attack');
assert.equal(moveThenAttack.state.hero.hp, 95, 'it attacks on its next enemy phase when already adjacent');

const shieldBreakFeedback = createLevelOne({ tutorialSeen: true, rng: fixedRng });
shieldBreakFeedback.state.items.length = 0;
shieldBreakFeedback.state.enemies = [{
  id: 'shield-break-slime', type: 'slime', name: '史莱姆', q: 0, r: 1,
  hp: 25, maxHp: 25, attack: 5, defense: 0, range: 1, gold: 1,
  stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0, frostStacks: 0,
}];
Object.assign(shieldBreakFeedback.state.hero, { q: 0, r: 2, hp: 100 });
shieldBreakFeedback.state.oneHitShield = true;
shieldBreakFeedback.state.phase = 'ENEMY_TURN';
shieldBreakFeedback.state.presentationQueue.length = 0;
shieldBreakFeedback.processEnemyTurn();
assert.equal(shieldBreakFeedback.state.hero.hp, 98, 'one-hit shield halves the next five-point slime hit');
assert.equal(shieldBreakFeedback.state.oneHitShield, false);
assert(
  shieldBreakFeedback.state.presentationQueue.some(event => event.type === 'shield_hit' && event.target === 'hero' && event.damage === 3),
  'shield absorption must expose the prevented damage to presentation'
);
assert(
  shieldBreakFeedback.state.presentationQueue.some(event => event.type === 'shield_break' && event.target === 'hero'),
  'consuming a one-hit shield must queue a readable break presentation'
);

const delayedVictory = createLevelOne({ rng: fixedRng });
delayedVictory.dismissTutorial();
delayedVictory.state.items.length = 0;
delayedVictory.state.enemies.length = 0;
Object.assign(delayedVictory.state.hero, { q: 0, r: 2 });
delayedVictory.state.tutorialPhase = 4;
delayedVictory.state.killTarget = 1;
delayedVictory.state.enemies.push({
  id: 'first-hop-slime', type: 'slime', name: '史莱姆', q: 0, r: 1,
  hp: 25, maxHp: 25, attack: 5, defense: 0, gold: 1, stunnedTurns: 0,
});
delayedVictory.state.enemies.push({
  id: 'final-hop-slime', type: 'slime', name: '史莱姆', q: 1, r: 0,
  hp: 22, maxHp: 25, attack: 5, defense: 0, gold: 1, stunnedTurns: 0,
});
const plannedFinalChain = delayedVictory.select(0, 0);
assert.equal(plannedFinalChain.kind, 'planned');
const finalStart = delayedVictory.select(2, 0);
assert.equal(finalStart.kind, 'jump_start');
assert.equal(delayedVictory.state.result, null, 'confirming a winning route must not show skill choices');
const firstStep = delayedVictory.executeNextJump();
assert.equal(firstStep.done, false);
assert.equal(delayedVictory.state.kills, 0);
assert.equal(delayedVictory.state.result, null, 'the first hop cannot settle a planned chain');
const finalStep = delayedVictory.executeNextJump();
assert.equal(finalStep.done, true);
assert.equal(delayedVictory.state.kills, 1);
assert.equal(delayedVictory.state.result, null, 'a kill during the hop must wait for landing');
assert.equal(delayedVictory.state.phase, 'PLAYER_EXECUTE');
const finalSummary = delayedVictory.finishJumpExecution();
assert.equal(finalSummary.resultPending, 'win');
assert.equal(delayedVictory.state.phase, 'COMBO_REWARD_WAIT');
assert.equal(delayedVictory.state.result, null, 'victory must wait for the post-jump presentation');
assert.equal(delayedVictory.state.skillChoices.length, 0);
finishRewardWait(delayedVictory);
assert.equal(delayedVictory.state.result, 'win');
assert.equal(delayedVictory.state.phase, 'WIN');
assert.equal(delayedVictory.state.skillChoices.length, 3, 'skill choices appear only after execution settles');

const dartItemTarget = createLevelOne({ tutorialSeen: true, rng: fixedRng });
dartItemTarget.state.enemies.length = 0;
dartItemTarget.state.items = [{ id: 'dart-gold', type: 'gold_bag', q: 2, r: -1 }];
Object.assign(dartItemTarget.state.hero, { q: 0, r: 2, attack: 30, hp: 100 });
dartItemTarget.state.killTarget = 99;
dartItemTarget.state.enemies.push(
  { id: 'dart-hop-one', type: 'slime', name: '史莱姆', q: 0, r: 1, hp: 1, maxHp: 25, attack: 5, defense: 0, range: 1, gold: 1, stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0, frostStacks: 0 },
  { id: 'dart-hop-two', type: 'slime', name: '史莱姆', q: 1, r: 0, hp: 1, maxHp: 25, attack: 5, defense: 0, range: 1, gold: 1, stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0, frostStacks: 0 },
);
assert.equal(dartItemTarget.select(0, 0).kind, 'planned');
const dartRoute = dartItemTarget.select(2, 0);
assert.equal(dartRoute.kind, 'jump_start');
resolveJumpExecution(dartItemTarget, dartRoute);
assert.equal(dartItemTarget.state.items.length, 0, '2连飞镖在无存活敌人时应拾取最近道具');
assert.equal(dartItemTarget.state.gold, 12, '两只史莱姆金币与金币袋奖励都必须结算');
assert(
  dartItemTarget.state.presentationQueue.some(event => event.type === 'projectile'
    && event.projectileType === 'tracking_dart'),
  '2连奖励必须请求专用追踪飞镖模型，而不是通用能量弹'
);

const chapterTargets = [5, 6, 6, 7, 7, 8, 8, 9, 9, 1];
for (let stage = 1; stage <= 10; stage += 1) {
  const game = createLevelOne({ stage, tutorialSeen: true, rng: fixedRng });
  assert.equal(game.state.stage, stage);
  assert.equal(game.state.killTarget, chapterTargets[stage - 1]);
  assert(game.state.enemies.length >= (stage === 10 ? 6 : 7), `stage ${stage} must start populated`);
  assert.notEqual(game.state.stageName, '', `stage ${stage} must have original stage metadata`);
}

const firstEnemyIntro = createLevelOne({ stage: 2, tutorialSeen: true, rng: fixedRng });
assert(firstEnemyIntro.state.enemyIntro.some(info => info.enemyType === 'jellyfish'));
assert.deepEqual(
  firstEnemyIntro.dismissEnemyIntro().enemyTypes.sort(),
  ['jellyfish'],
  '首次遭遇的特殊怪物必须展示并记录'
);
const seenEnemyIntro = createLevelOne({
  stage: 2, tutorialSeen: true, rng: fixedRng,
  seenEnemyTypes: { jellyfish: true, iron_turtle: true },
});
assert.equal(seenEnemyIntro.state.enemyIntro.length, 0, '已经介绍过的怪物不重复弹窗');

const skillCampaign = createLevelOne({ tutorialSeen: true, rng: fixedRng });
skillCampaign.state.result = 'win';
skillCampaign.state.phase = 'WIN';
skillCampaign.state.skillChoices = [{ id: 'quake_land', name: '震地落', color: '#dc8c28' }];
assert.deepEqual(skillCampaign.selectSkill(0), {
  kind: 'skill', id: 'quake_land', level: 1, chapterComplete: false,
});
assert.equal(skillCampaign.state.skills.quake_land, 1);
assert.deepEqual(skillCampaign.continueToNextStage(), { kind: 'next_stage', stage: 2 });
assert.equal(skillCampaign.state.result, null);
assert.equal(skillCampaign.state.phase, 'PLAYER_SELECT');
assert.equal(skillCampaign.state.killTarget, 6);
assert.equal(skillCampaign.state.skills.quake_land, 1, 'skills persist into the next stage');
assert(skillCampaign.consumePresentationEvents().some(event => event.type === 'announcement'));

const liveSkill = createLevelOne({ tutorialSeen: true, rng: fixedRng, skills: { quake_land: 1, combo_shield: 1 } });
liveSkill.state.items.length = 0;
liveSkill.state.enemies.length = 0;
Object.assign(liveSkill.state.hero, { q: 0, r: 2, shield: 0 });
liveSkill.state.enemies.push({
  id: 'skill-target', type: 'slime', name: '史莱姆', q: 0, r: 1,
  hp: 100, maxHp: 100, attack: 5, defense: 0, range: 1, gold: 1,
  stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0, frostStacks: 0,
});
const skillJumpStart = liveSkill.select(0, 0);
const skillJump = liveSkill.executeNextJump();
assert.equal(skillJumpStart.kind, 'jump_start');
assert.equal(skillJump.hit.damage, 15);
assert.equal(liveSkill.state.enemies[0].hp, 70, 'quake land applies real landing damage after the jump hit');
assert.equal(liveSkill.state.hero.shield, 4, 'combo shield applies its original Lv1 per-hop shield value');
assert(liveSkill.state.presentationQueue.some(event => event.type === 'quake'));
assert(liveSkill.state.presentationQueue.some(event => event.type === 'shield'));

const chapterClear = createLevelOne({ stage: 9, tutorialSeen: true, rng: fixedRng });
chapterClear.state.result = 'win';
chapterClear.state.phase = 'WIN';
chapterClear.state.skillChoices = [{ id: 'dawn_herald', name: '黎明使者', color: '#ffc850' }];
chapterClear.selectSkill(0);
assert.deepEqual(chapterClear.continueToNextStage(), { kind: 'next_stage', stage: 10 });
assert.equal(chapterClear.state.isBossStage, true);
assert.equal(chapterClear.state.boss?.name, '深渊海妖');
assert.equal(chapterClear.state.boss?.hp, 350);
assert.equal(chapterClear.state.obstacles.filter(entry => entry.type === 'reef').length, 5);
assert.equal(chapterClear.state.items.length, 2);
chapterClear.state.result = 'win';
chapterClear.state.phase = 'WIN';
chapterClear.state.skillChoices = [{ id: 'chain_lightning', name: '连锁闪电', color: '#64b4ff' }];
chapterClear.selectSkill(0);
assert.deepEqual(chapterClear.continueToNextStage(), { kind: 'chapter_complete' });
assert.equal(chapterClear.state.phase, 'CHAPTER_COMPLETE');
assert.equal(chapterClear.state.result, 'chapter_complete');

const bossCadence = createLevelOne({ stage: 10, tutorialSeen: true, rng: fixedRng });
bossCadence.state.obstacles.length = 0;
bossCadence.state.enemies = [bossCadence.state.boss];
Object.assign(bossCadence.state.hero, { q: 0, r: -1, hp: 200, maxHp: 200 });
bossCadence.state.phase = 'ENEMY_TURN';
const bossBasic = bossCadence.processEnemyTurn();
assert(bossBasic.actions.some(action => action.type === 'attack'), '全局冷却中的 Boss 先进行一次普通攻击');
bossCadence.startPlayerTurn(); bossCadence.state.phase = 'ENEMY_TURN';
const bossBasicTwo = bossCadence.processEnemyTurn();
assert(bossBasicTwo.actions.some(action => action.type === 'attack'), 'Boss开场第二回合仍处于安全期');
bossCadence.startPlayerTurn(); bossCadence.state.phase = 'ENEMY_TURN';
const bossClaw = bossCadence.processEnemyTurn();
assert(bossClaw.actions.some(action => action.type === 'boss_claw'), '巨爪冷却完成且距离2格内时优先施放');

const bossTentacles = createLevelOne({ stage: 10, tutorialSeen: true, rng: fixedRng });
bossTentacles.state.obstacles.length = 0;
bossTentacles.state.enemies = [bossTentacles.state.boss];
Object.assign(bossTentacles.state.hero, { q: -2, r: 4, hp: 200, maxHp: 200 });
Object.assign(bossTentacles.state.boss, { skillCooldown: 0, clawCooldown: 9, tentacleCooldown: 0, whirlpoolCooldown: 9 });
bossTentacles.state.phase = 'ENEMY_TURN';
const tentacleAction = bossTentacles.processEnemyTurn();
assert(tentacleAction.actions.some(action => action.type === 'boss_tentacle'));
assert.equal(bossTentacles.state.obstacles.filter(entry => entry.type === 'tentacle').length, 4);

const bossSkillBypassesShield = createLevelOne({ stage: 10, tutorialSeen: true, rng: fixedRng });
bossSkillBypassesShield.state.obstacles.length = 0;
bossSkillBypassesShield.state.enemies = [bossSkillBypassesShield.state.boss];
Object.assign(bossSkillBypassesShield.state.hero, { q: 0, r: -1, hp: 200, maxHp: 200, shield: 100 });
Object.assign(bossSkillBypassesShield.state.boss, {
  q: 0, r: -3, skillCooldown: 0, clawCooldown: 0, tentacleCooldown: 9, whirlpoolCooldown: 9,
});
bossSkillBypassesShield.state.phase = 'ENEMY_TURN';
const shieldBypassTurn = bossSkillBypassesShield.processEnemyTurn();
assert(shieldBypassTurn.actions.some(action => action.type === 'boss_claw'));
assert.equal(bossSkillBypassesShield.state.hero.hp, 170, '海妖主动技能按原版直接扣生命，不被护盾吸收');
assert.equal(bossSkillBypassesShield.state.hero.shield, 97, '只有行动前的深渊光环会消耗3点护盾');

const obstacleJump = createLevelOne({ stage: 10, tutorialSeen: true, rng: fixedRng });
obstacleJump.state.enemies.length = 0; obstacleJump.state.boss.hp = 0;
obstacleJump.state.items.length = 0; obstacleJump.state.obstacles = [{ id: 'test-tentacle', type: 'tentacle', q: 0, r: 1, turnsLeft: 3 }];
Object.assign(obstacleJump.state.hero, { q: 0, r: 2, hp: 100 });
const tentacleJumpStart = obstacleJump.select(0, 0);
assert.equal(tentacleJumpStart.kind, 'jump_start', '触手既阻挡移动，也能作为跳跃支点');
const tentacleJumpStep = obstacleJump.executeNextJump();
assert.equal(tentacleJumpStep.step.isObstacle, true);
assert.equal(obstacleJump.state.hero.hp, 90, '跳过触手至少承受10点伤害');

const bossCap = createLevelOne({ stage: 10, tutorialSeen: true, rng: fixedRng });
bossCap.state.obstacles.length = 0; bossCap.state.items.length = 0;
bossCap.state.enemies = [bossCap.state.boss];
Object.assign(bossCap.state.boss, { q: 0, r: 1, hp: 350 });
Object.assign(bossCap.state.hero, { q: 0, r: 2, attack: 1000 });
const bossCapStart = bossCap.select(0, 0);
assert.equal(bossCapStart.kind, 'jump_start');
const bossCapStep = bossCap.executeNextJump();
assert.equal(bossCapStep.hit.damage, 140, 'Boss 单次受伤不超过最大生命40%');

const leapPioneer = createLevelOne({ tutorialSeen: true, rng: fixedRng, setEffects: { leap_pioneer: 4 } });
leapPioneer.state.items.length = 0; leapPioneer.state.enemies.length = 0;
Object.assign(leapPioneer.state.hero, { q: 0, r: 2 });
leapPioneer.state.enemies.push(
  { id: 'leap-one', type: 'slime', name: '史莱姆', q: 0, r: 1, hp: 100, maxHp: 100, attack: 5, defense: 0, range: 1, gold: 1, stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0, frostStacks: 0 },
  { id: 'leap-two', type: 'slime', name: '史莱姆', q: 0, r: 0, hp: 100, maxHp: 100, attack: 5, defense: 0, range: 1, gold: 1, stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0, frostStacks: 0 },
);
const pioneerStart = leapPioneer.select(0, -1);
assert.equal(pioneerStart.kind, 'jump_start');
const pioneerStep = leapPioneer.executeNextJump();
assert.deepEqual(pioneerStep.step.enemyIds, ['leap-one', 'leap-two']);
assert(leapPioneer.state.enemies.every(enemy => enemy.hp < 100), '飞跃先锋4件套一次跳跃同时伤害连续2名敌人');

const wheelPickup = createLevelOne({ stage: 2, tutorialSeen: true, rng: fixedRng });
wheelPickup.state.enemies.length = 0;
wheelPickup.state.items = [{ id: 'test-wheel', type: 'lucky_wheel', q: -1, r: 4 }];
const wheelMove = wheelPickup.select(-1, 4);
assert.equal(wheelMove.kind, 'move');
assert.equal(wheelPickup.state.wheelResult?.type, 'lucky', '1-2 起拾取轮盘必须打开结果演出');
assert.equal(wheelPickup.state.wheelResult.outcomes.length, 4, '轮盘由3个随机事件和1个固定保底组成');
assert(['closed', 'extra_turn', 'wheel_skill'].includes(wheelPickup.dismissWheel().kind));

const metaBattle = createLevelOne({
  tutorialSeen: true,
  rng: fixedRng,
  hero: { hp: 140, maxHp: 140, attack: 30, defense: 8 },
  critRate: 100,
  goldBonus: 100,
  setEffects: { soul_hunter: 4 },
});
assert.deepEqual(
  { hp: metaBattle.state.hero.hp, maxHp: metaBattle.state.hero.maxHp, attack: metaBattle.state.hero.attack, defense: metaBattle.state.hero.defense },
  { hp: 140, maxHp: 140, attack: 30, defense: 8 },
  '天赋和装备数值必须真正进入战斗英雄属性'
);
metaBattle.state.items.length = 0;
metaBattle.state.enemies.length = 0;
Object.assign(metaBattle.state.hero, { q: 0, r: 2, hp: 100 });
metaBattle.state.enemies.push({
  id: 'crit-target', type: 'slime', name: '史莱姆', q: 0, r: 1,
  hp: 40, maxHp: 40, attack: 5, defense: 0, range: 1, gold: 1,
  stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0, frostStacks: 0,
});
const critStart = metaBattle.select(0, 0);
const critStep = metaBattle.executeNextJump();
assert.equal(critStart.kind, 'jump_start');
assert.equal(critStep.hit.damage, 45, '100%暴击使30点基础跳跃伤害按原版1.5倍计算');
assert.equal(metaBattle.state.gold, 2, '点金手100%使1金币击杀奖励翻倍');
assert(metaBattle.state.presentationQueue.some(event => event.type === 'crit'));
const critNumberEvents = metaBattle.state.presentationQueue.filter(event =>
  (event.type === 'crit' || event.type === 'damage') && !event.suppressNumber
);
assert.equal(critNumberEvents.length, 1, '一次暴击只能生成一张合并后的伤害浮字');
assert.equal(
  metaBattle.state.presentationQueue.find(event => event.type === 'damage')?.suppressNumber,
  true,
  '暴击的 damage 事件仍负责受击动作和命中特效，但不得重复显示数字'
);

const spikePlacement = createLevelOne({ tutorialSeen: true, rng: fixedRng, skills: { spike_trap: 3 } });
spikePlacement.state.items.length = 0; spikePlacement.state.enemies.length = 0;
Object.assign(spikePlacement.state.hero, { q: 0, r: 2, attack: 30 });
spikePlacement.state.enemies.push({
  id: 'spike-hop', type: 'slime', name: '史莱姆', q: 0, r: 1,
  hp: 100, maxHp: 100, attack: 5, defense: 0, range: 1, gold: 1,
  stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0, frostStacks: 0,
});
const spikeJump = spikePlacement.select(0, 0);
assert.equal(spikeJump.kind, 'jump_start');
spikePlacement.executeNextJump();
assert.equal(spikePlacement.state.traps.length, 3, '地刺陷阱Lv3应在起跳点周围放置3枚地刺');
assert(spikePlacement.state.traps.every(trap => Math.max(Math.abs(trap.q), Math.abs(trap.r - 2), Math.abs(trap.q + trap.r - 2)) === 1));
assert.equal(spikePlacement.state.traps.some(trap => trap.q === 0 && trap.r === 2), false, '地刺不能直接放在起跳格本身');

const stepStrikeDefense = createLevelOne({ tutorialSeen: true, rng: fixedRng, skills: { step_strike: 1, damage_amp: 5 } });
stepStrikeDefense.state.items.length = 0; stepStrikeDefense.state.enemies.length = 0;
Object.assign(stepStrikeDefense.state.hero, { q: 0, r: 2 });
stepStrikeDefense.state.enemies.push({
  id: 'step-turtle', type: 'iron_turtle', name: '铁甲龟', q: 1, r: 1,
  hp: 100, maxHp: 100, attack: 9, defense: 5, range: 1, gold: 3,
  stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0, frostStacks: 0,
});
const stepMove = stepStrikeDefense.select(0, 1);
assert.equal(stepMove.kind, 'move');
assert.equal(stepStrikeDefense.state.enemies[0].hp, 90, '踏步斩Lv1保底10伤害不受防御或战意增幅修正');

const cataclysm = createLevelOne({ tutorialSeen: true, rng: fixedRng, skills: { quake_land: 4 } });
cataclysm.state.items.length = 0; cataclysm.state.enemies.length = 0; cataclysm.state.killTarget = 99;
Object.assign(cataclysm.state.hero, { q: 0, r: 3, attack: 15 });
cataclysm.state.enemies.push(
  { id: 'cat-one', type: 'slime', name: '史莱姆', q: 0, r: 2, hp: 999, maxHp: 999, attack: 5, defense: 0, range: 1, gold: 1, stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0, frostStacks: 0 },
  { id: 'cat-two', type: 'slime', name: '史莱姆', q: 1, r: 0, hp: 999, maxHp: 999, attack: 5, defense: 0, range: 1, gold: 1, stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0, frostStacks: 0 },
  { id: 'cat-three', type: 'slime', name: '史莱姆', q: 1, r: -1, hp: 999, maxHp: 999, attack: 5, defense: 0, range: 1, gold: 1, stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0, frostStacks: 0 },
  { id: 'cat-far', type: 'iron_turtle', name: '铁甲龟', q: -3, r: 0, hp: 100, maxHp: 100, attack: 9, defense: 5, range: 1, gold: 3, stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0, frostStacks: 0 },
);
assert.equal(cataclysm.select(0, 1).kind, 'planned');
assert.equal(cataclysm.select(2, -1).kind, 'planned');
const cataclysmStart = cataclysm.select(0, -1);
assert.equal(cataclysmStart.kind, 'jump_start');
resolveJumpExecution(cataclysm, cataclysmStart);
assert.equal(cataclysm.state.enemies.find(enemy => enemy.id === 'cat-far').hp, 73, '震地落Lv4三连全场AOE按12+5×combo造成27固定伤害');

const vampiricChainKill = createLevelOne({ tutorialSeen: true, rng: fixedRng, skills: { vampiric_jump: 3 } });
vampiricChainKill.state.items.length = 0; vampiricChainKill.state.enemies.length = 0; vampiricChainKill.state.killTarget = 99;
Object.assign(vampiricChainKill.state.hero, { q: 0, r: 2, hp: 50, maxHp: 100, attack: 30 });
vampiricChainKill.state.enemies.push(
  { id: 'vamp-one', type: 'slime', name: '史莱姆', q: 0, r: 1, hp: 1, maxHp: 25, attack: 5, defense: 0, range: 1, gold: 1, stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0, frostStacks: 0 },
  { id: 'vamp-two', type: 'slime', name: '史莱姆', q: 1, r: 0, hp: 1, maxHp: 25, attack: 5, defense: 0, range: 1, gold: 1, stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0, frostStacks: 0 },
  { id: 'vamp-dart', type: 'slime', name: '史莱姆', q: -2, r: 0, hp: 30, maxHp: 30, attack: 5, defense: 0, range: 1, gold: 1, stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0, frostStacks: 0 },
);
assert.equal(vampiricChainKill.select(0, 0).kind, 'planned');
const vampiricStart = vampiricChainKill.select(2, 0);
resolveJumpExecution(vampiricChainKill, vampiricStart);
assert.equal(vampiricChainKill.state.hero.hp, 97, '吸血跳Lv3的+12HP适用于飞镖等连锁击杀，而不只直接跳杀');

const fixedChainLightning = createLevelOne({
  tutorialSeen: true, rng: fixedRng, skills: { chain_lightning: 2, damage_amp: 5 },
});
fixedChainLightning.state.items.length = 0; fixedChainLightning.state.enemies.length = 0; fixedChainLightning.state.killTarget = 99;
Object.assign(fixedChainLightning.state.hero, { q: 0, r: 2, attack: 30 });
fixedChainLightning.state.enemies.push(
  { id: 'chain-origin', type: 'slime', name: '史莱姆', q: 0, r: 1, hp: 1, maxHp: 25, attack: 5, defense: 0, range: 1, gold: 1, stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0, frostStacks: 0 },
  { id: 'chain-near-a', type: 'iron_turtle', name: '铁甲龟', q: 2, r: 0, hp: 100, maxHp: 100, attack: 9, defense: 5, range: 1, gold: 3, stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0, frostStacks: 0 },
  { id: 'chain-near-b', type: 'iron_turtle', name: '铁甲龟', q: -2, r: 1, hp: 100, maxHp: 100, attack: 9, defense: 5, range: 1, gold: 3, stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0, frostStacks: 0 },
  { id: 'chain-near-a-only', type: 'slime', name: '史莱姆', q: 3, r: -1, hp: 100, maxHp: 100, attack: 5, defense: 0, range: 1, gold: 1, stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0, frostStacks: 0 },
);
let fixedChainStart = fixedChainLightning.select(0, 0);
if (fixedChainStart.kind === 'planned') fixedChainStart = fixedChainLightning.confirm();
assert.equal(fixedChainStart.kind, 'jump_start');
fixedChainLightning.executeNextJump();
assert.equal(fixedChainLightning.state.enemies.find(enemy => enemy.id === 'chain-near-a').hp, 83);
assert.equal(fixedChainLightning.state.enemies.find(enemy => enemy.id === 'chain-near-b').hp, 83, '连锁闪电从死亡点选择最近目标，且固定伤害不吃防御和战意增幅');
assert.equal(fixedChainLightning.state.enemies.find(enemy => enemy.id === 'chain-near-a-only').hp, 100, '连锁闪电不能把每次命中点当成下一次选目标的起点');

const recursiveSplitShot = createLevelOne({
  tutorialSeen: true, rng: fixedRng, skills: { split_shot: 5, damage_amp: 5 },
});
recursiveSplitShot.state.items.length = 0; recursiveSplitShot.state.enemies.length = 0; recursiveSplitShot.state.killTarget = 99;
Object.assign(recursiveSplitShot.state.hero, { q: 0, r: 2, attack: 30 });
recursiveSplitShot.state.enemies.push(
  { id: 'split-origin', type: 'slime', name: '史莱姆', q: 0, r: 1, hp: 1, maxHp: 25, attack: 5, defense: 0, range: 1, gold: 1, stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0, frostStacks: 0 },
  { id: 'split-primary-kill', type: 'slime', name: '史莱姆', q: 1, r: 1, hp: 30, maxHp: 30, attack: 5, defense: 0, range: 1, gold: 1, stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0, frostStacks: 0 },
  { id: 'split-primary-two', type: 'slime', name: '史莱姆', q: -1, r: 2, hp: 100, maxHp: 100, attack: 5, defense: 0, range: 1, gold: 1, stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0, frostStacks: 0 },
  { id: 'split-primary-three', type: 'slime', name: '史莱姆', q: 2, r: 0, hp: 100, maxHp: 100, attack: 5, defense: 0, range: 1, gold: 1, stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0, frostStacks: 0 },
  { id: 'split-secondary-only', type: 'iron_turtle', name: '铁甲龟', q: 2, r: -1, hp: 100, maxHp: 100, attack: 9, defense: 5, range: 1, gold: 3, stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0, frostStacks: 0 },
);
let splitStart = recursiveSplitShot.select(0, 0);
if (splitStart.kind === 'planned') splitStart = recursiveSplitShot.confirm();
assert.equal(splitStart.kind, 'jump_start');
recursiveSplitShot.executeNextJump();
assert.equal(recursiveSplitShot.state.enemies.find(enemy => enemy.id === 'split-secondary-only').hp, 70, '满级分裂弹击杀后应再发射一整轮固定伤害碎片');

const firstJumpSilence = createLevelOne({ tutorialSeen: true, rng: fixedRng, skills: { silence_path: 3 } });
firstJumpSilence.state.items.length = 0; firstJumpSilence.state.enemies.length = 0; firstJumpSilence.state.killTarget = 99;
Object.assign(firstJumpSilence.state.hero, { q: 0, r: 2, attack: 20 });
firstJumpSilence.state.enemies.push({
  id: 'silence-first-hop', type: 'slime', name: '史莱姆', q: 0, r: 1,
  hp: 100, maxHp: 100, attack: 5, defense: 0, range: 1, gold: 1,
  stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0, frostStacks: 0,
});
let silenceStart = firstJumpSilence.select(0, 0);
if (silenceStart.kind === 'planned') silenceStart = firstJumpSilence.confirm();
const silenceHit = firstJumpSilence.executeNextJump();
assert.equal(silenceHit.hit.damage, 23, '寂灭之路从第一跳起先施加沉默，再结算Lv3的15%伤害加成');
assert.equal(firstJumpSilence.state.enemies[0].silencedTurns, 2);

const kingmakerCadence = createLevelOne({ tutorialSeen: true, rng: fixedRng, skills: { kingmaker: 1 } });
kingmakerCadence.state.items.length = 0; kingmakerCadence.state.enemies.length = 0; kingmakerCadence.state.killTarget = 99;
Object.assign(kingmakerCadence.state.hero, { q: 0, r: 2, attack: 15 });
kingmakerCadence.state.enemies.push(
  { id: 'king-chain-one', type: 'slime', name: '史莱姆', q: 0, r: 1, hp: 100, maxHp: 100, attack: 5, defense: 0, range: 1, gold: 1, stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0, frostStacks: 0 },
  { id: 'king-chain-two', type: 'slime', name: '史莱姆', q: 1, r: 0, hp: 100, maxHp: 100, attack: 5, defense: 0, range: 1, gold: 1, stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0, frostStacks: 0 },
);
assert.equal(kingmakerCadence.select(0, 0).kind, 'planned');
const kingChainStart = kingmakerCadence.select(2, 0);
resolveJumpExecution(kingmakerCadence, kingChainStart);
assert.equal(kingmakerCadence.state._kingmakerCount, 1, '棋步每条连跳链只累计一次行动，而不是每跳或每个敌方回合累计');

const fixedSpikeTick = createLevelOne({ tutorialSeen: true, rng: fixedRng, skills: { spike_trap: 2, damage_amp: 5 } });
fixedSpikeTick.state.items.length = 0; fixedSpikeTick.state.enemies.length = 0; fixedSpikeTick.state.killTarget = 99;
Object.assign(fixedSpikeTick.state.hero, { q: 0, r: 4, hp: 100 });
fixedSpikeTick.state.enemies.push({
  id: 'spike-tick-turtle', type: 'iron_turtle', name: '铁甲龟', q: 0, r: 0,
  hp: 100, maxHp: 100, attack: 9, defense: 5, range: 1, gold: 3,
  stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0, frostStacks: 0,
});
fixedSpikeTick.state.traps = [{ q: 0, r: 0, damage: 15, turnsLeft: 3, slow: false }];
fixedSpikeTick.state.phase = 'ENEMY_TURN';
fixedSpikeTick.processEnemyTurn();
assert.equal(fixedSpikeTick.state.enemies[0].hp, 85, '地刺在敌方回合开始结算固定伤害，不受防御或战意增幅影响');

const bloodThorns = createLevelOne({ tutorialSeen: true, rng: fixedRng, skills: { vampiric_jump: 4, thorns: 1 } });
bloodThorns.state.items.length = 0; bloodThorns.state.enemies.length = 0; bloodThorns.state.killTarget = 99;
Object.assign(bloodThorns.state.hero, { q: 0, r: 1, hp: 30, maxHp: 100, defense: 1 });
bloodThorns.state.enemies.push({
  id: 'blood-thorns-attacker', type: 'slime', name: '史莱姆', q: 0, r: 0,
  hp: 100, maxHp: 100, attack: 20, defense: 0, range: 1, gold: 1,
  stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0, frostStacks: 0,
});
bloodThorns.state.phase = 'ENEMY_TURN';
bloodThorns.processEnemyTurn();
assert.equal(bloodThorns.state.enemies[0].hp, 95, '血棘共生不额外提高荆棘反伤本身');
assert.equal(bloodThorns.state.hero.hp, 13, '低血时血棘共生把70%反伤转为治疗');

const crabCadence = createLevelOne({ stage: 7, tutorialSeen: true, rng: fixedRng });
crabCadence.state.items.length = 0;
crabCadence.state.enemies = [{
  id: 'shell-crab', type: 'hermit_crab', name: '寄居蟹', q: 0, r: 0,
  hp: 38, maxHp: 38, attack: 7, defense: 0, range: 1, gold: 1,
  hasShell: true, shellCooldown: 0, stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0,
}];
Object.assign(crabCadence.state.hero, { q: 0, r: 4 });
crabCadence.state.phase = 'ENEMY_TURN';
assert.equal(crabCadence.processEnemyTurn().actions[0].type, 'shelled');
crabCadence.startPlayerTurn(); crabCadence.state.phase = 'ENEMY_TURN';
assert.equal(crabCadence.processEnemyTurn().actions.find(action => action.enemyId === 'shell-crab').type, 'shelled');
crabCadence.startPlayerTurn(); crabCadence.state.phase = 'ENEMY_TURN';
assert.notEqual(crabCadence.processEnemyTurn().actions.find(action => action.enemyId === 'shell-crab').type, 'shelled', '寄居蟹按原版每2个敌人回合切换缩壳状态');

const sharkCadence = createLevelOne({ stage: 8, tutorialSeen: true, rng: fixedRng });
sharkCadence.state.items.length = 0;
sharkCadence.state.enemies = [{
  id: 'ghost-shark', type: 'ghost_shark', name: '幽灵鲨', q: -4, r: 0,
  hp: 22, maxHp: 22, attack: 11, defense: 0, range: 1, gold: 2,
  teleportCooldown: 1, teleportCooldownRemaining: 0,
  stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0,
}];
Object.assign(sharkCadence.state.hero, { q: 0, r: 0, hp: 100 });
sharkCadence.state.phase = 'ENEMY_TURN';
const sharkFirst = sharkCadence.processEnemyTurn();
assert(sharkFirst.actions.some(action => action.type === 'teleport'));
assert(sharkFirst.actions.some(action => action.type === 'attack'));
sharkCadence.startPlayerTurn(); sharkCadence.state.phase = 'ENEMY_TURN';
const sharkCooldown = sharkCadence.processEnemyTurn();
assert.equal(sharkCooldown.actions.some(action => action.type === 'teleport' && action.enemyId === 'ghost-shark'), false, '幽灵鲨瞬移后有1回合冷却');

const silenceMovement = createLevelOne({ stage: 8, tutorialSeen: true, rng: fixedRng });
silenceMovement.state.items.length = 0;
silenceMovement.state.enemies = [{
  id: 'silenced-ray', type: 'electric_ray', name: '电鳐', q: 0, r: -3,
  hp: 40, maxHp: 40, attack: 7, defense: 0, range: 1, gold: 2,
  stunnedTurns: 0, frozenTurns: 0, silencedTurns: 1,
}];
Object.assign(silenceMovement.state.hero, { q: 0, r: 3, hp: 100 });
silenceMovement.state.phase = 'ENEMY_TURN';
const silencedFar = silenceMovement.processEnemyTurn();
assert.equal(silencedFar.actions[0].type, 'move', '沉默只禁用技能和攻击，射程外的敌人仍会朝目标移动');

const electricDischarge = createLevelOne({ stage: 6, tutorialSeen: true, rng: fixedRng });
electricDischarge.state.items.length = 0;
electricDischarge.state.enemies = [{
  id: 'electric-ray', type: 'electric_ray', name: '电鳐', q: 0, r: 0,
  hp: 40, maxHp: 40, attack: 7, defense: 0, range: 1, gold: 2, aoeDamage: true,
  stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0,
}];
Object.assign(electricDischarge.state.hero, { q: 0, r: 1, hp: 100 });
electricDischarge.state.phase = 'ENEMY_TURN';
const electricTurn = electricDischarge.processEnemyTurn();
assert(electricTurn.actions.some(action => action.type === 'attack' && action.enemyId === 'electric-ray'));
assert(electricDischarge.state.presentationQueue.some(event => event.type === 'electric_discharge'), '电鳐攻击必须产生范围放电演出');

const vortexShuffle = createLevelOne({ stage: 6, tutorialSeen: true, rng: fixedRng });
vortexShuffle.state.items.length = 0;
vortexShuffle.state.enemies = [
  {
    id: 'vortex-test', type: 'vortex_eel', name: '漩涡鳗', q: 0, r: 1,
    hp: 1, maxHp: 35, attack: 10, defense: 0, range: 1, gold: 2, shuffleOnDeath: true,
    stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0, frostStacks: 0,
  },
  {
    id: 'vortex-neighbor', type: 'iron_turtle', name: '铁甲龟', q: 1, r: 0,
    hp: 100, maxHp: 100, attack: 9, defense: 5, range: 1, gold: 3,
    stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0, frostStacks: 0,
  },
];
Object.assign(vortexShuffle.state.hero, { q: 0, r: 2, hp: 100, attack: 30 });
let vortexStart = vortexShuffle.select(0, 0);
if (vortexStart.kind === 'planned') vortexStart = vortexShuffle.confirm();
const vortexStep = vortexShuffle.executeNextJump();
assert.equal(vortexStart.kind, 'jump_start');
assert(vortexStep.shuffled.length >= 1, '漩涡鳗死亡效果必须等企鹅落地后再移动周围棋子');
assert.equal(vortexShuffle.state.pendingShuffles.length, 0);
assert(vortexShuffle.state.presentationQueue.some(event => event.type === 'vortex'));

const bossPrecast = createLevelOne({ stage: 10, tutorialSeen: true, rng: fixedRng });
bossPrecast.state.enemies = [bossPrecast.state.boss];
Object.assign(bossPrecast.state.hero, { q: 0, r: 3, hp: 100 });
Object.assign(bossPrecast.state.boss, {
  q: 0, r: -3, skillCooldown: 0, clawCooldown: 5, tentacleCooldown: 1, whirlpoolCooldown: 5,
});
bossPrecast.state.phase = 'ENEMY_TURN';
const hpBeforePrecast = bossPrecast.state.hero.hp;
assert.equal(bossPrecast.prepareEnemyTurn()?.id, 'tentacle');
assert.equal(bossPrecast.state.hero.hp, hpBeforePrecast, 'Boss前摇只预告，不可提前结算伤害');
const bossCast = bossPrecast.processEnemyTurn();
assert(bossCast.actions.some(action => action.type === 'boss_tentacle'));
assert(bossPrecast.state.hero.hp < hpBeforePrecast, '0.8秒前摇后才执行Boss技能伤害');

const bossOpening = createLevelOne({ stage: 10, tutorialSeen: true, rng: fixedRng });
bossOpening.state.enemies = [bossOpening.state.boss];
Object.assign(bossOpening.state.hero, { q: 0, r: -1, hp: 100 });
Object.assign(bossOpening.state.boss, { q: 0, r: -3 });
for (let turn = 0; turn < 2; turn += 1) {
  bossOpening.state.phase = 'ENEMY_TURN';
  const openingAction = bossOpening.processEnemyTurn();
  assert.equal(openingAction.actions.some(action => action.type === 'boss_claw'), false, 'Boss开场前2回合只能普攻或移动');
  if (!bossOpening.state.result) bossOpening.startPlayerTurn();
}
bossOpening.state.phase = 'ENEMY_TURN';
assert(bossOpening.processEnemyTurn().actions.some(action => action.type === 'boss_claw'), '第3个敌方回合近身巨爪才可发动');

const bossTaunt = createLevelOne({ stage: 10, tutorialSeen: true, rng: fixedRng });
bossTaunt.state.enemies = [bossTaunt.state.boss];
Object.assign(bossTaunt.state.boss, { q: 0, r: -2, skillCooldown: 1 });
Object.assign(bossTaunt.state.hero, { q: 0, r: 3, hp: 100 });
bossTaunt.state.scarecrow = { q: 0, r: -1, hp: 100, maxHp: 100, defense: 1, turnsLeft: 2 };
bossTaunt.state.phase = 'ENEMY_TURN';
const heroBeforeTaunt = bossTaunt.state.hero.hp;
const scarecrowBefore = bossTaunt.state.scarecrow.hp;
const tauntedAction = bossTaunt.processEnemyTurn();
assert.equal(tauntedAction.actions.find(action => action.enemyId === bossTaunt.state.boss.id)?.target, 'scarecrow');
assert.equal(bossTaunt.state.hero.hp, heroBeforeTaunt, 'Boss普攻受稻草人嘲讽');
assert(bossTaunt.state.scarecrow.hp < scarecrowBefore);

const timeStop = createLevelOne({ tutorialSeen: true, rng: fixedRng });
timeStop.state.items.length = 0;
timeStop.state.enemies = [{
  id: 'time-stop-slime', type: 'slime', name: '史莱姆', q: 0, r: 1,
  hp: 25, maxHp: 25, attack: 5, defense: 0, range: 1, gold: 1,
  stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0,
}];
Object.assign(timeStop.state.hero, { q: 0, r: 2, hp: 100 });
timeStop.state.timeStopTurns = 2;
timeStop.state.phase = 'ENEMY_TURN';
const frozenTurnOne = timeStop.processEnemyTurn();
assert(frozenTurnOne.actions.every(action => action.type === 'time_stopped'));
assert.equal(timeStop.state.hero.hp, 100, '六连必须完整跳过第一次敌方行动');
assert.equal(timeStop.state.timeStopTurns, 1);
timeStop.startPlayerTurn();
timeStop.state.phase = 'ENEMY_TURN';
const frozenTurnTwo = timeStop.processEnemyTurn();
assert(frozenTurnTwo.actions.every(action => action.type === 'time_stopped'));
assert.equal(timeStop.state.hero.hp, 100, '六连必须完整跳过第二次敌方行动');
assert.equal(timeStop.state.timeStopTurns, 0);
assert(timeStop.state.presentationQueue.filter(event => event.type === 'time_stop_turn').length >= 2,
  '每个被跳过的敌方阶段都必须发出时间静止状态事件');

const absoluteReflect = createLevelOne({ tutorialSeen: true, rng: fixedRng });
absoluteReflect.state.items.length = 0;
absoluteReflect.state.enemies = [{
  id: 'reflect-slime', type: 'slime', name: '史莱姆', q: 0, r: 1,
  hp: 25, maxHp: 25, attack: 5, defense: 0, range: 1, gold: 1,
  stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0,
}];
Object.assign(absoluteReflect.state.hero, { q: 0, r: 2, hp: 100 });
absoluteReflect.state.absoluteReflectTurns = 4;
absoluteReflect.state.phase = 'ENEMY_TURN';
const reflectTurn = absoluteReflect.processEnemyTurn();
assert.equal(absoluteReflect.state.hero.hp, 100, '八连反射期间企鹅受到的敌方伤害必须为零');
assert.equal(absoluteReflect.state.enemies[0].hp, 20, '八连必须把同额伤害返还给攻击者');
assert.equal(reflectTurn.actions[0].reflected, 5);
assert.equal(absoluteReflect.state.absoluteReflectTurns, 3, '八连效果按真实敌方回合消耗，初始持续四回合');
assert(absoluteReflect.state.presentationQueue.some(event => event.type === 'absolute_reflect_hit' && event.damage === 5));

const scarecrowHealth = createLevelOne({ tutorialSeen: true, rng: fixedRng });
scarecrowHealth.state.items.length = 0;
scarecrowHealth.state.enemies = [{
  id: 'scarecrow-slime', type: 'slime', name: '史莱姆', q: 0, r: 1,
  hp: 25, maxHp: 25, attack: 5, defense: 0, range: 1, gold: 1,
  stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0,
}];
Object.assign(scarecrowHealth.state.hero, { q: 0, r: 3, hp: 100 });
scarecrowHealth.state.scarecrow = { q: 0, r: 2, hp: 6, maxHp: 100, defense: 0 };
scarecrowHealth.state.phase = 'ENEMY_TURN';
scarecrowHealth.processEnemyTurn();
assert.equal(scarecrowHealth.state.scarecrow.hp, 1, '稻草人承伤后只要仍有生命就必须继续存在');
scarecrowHealth.startPlayerTurn();
scarecrowHealth.state.phase = 'ENEMY_TURN';
scarecrowHealth.processEnemyTurn();
assert.equal(scarecrowHealth.state.scarecrow, null, '稻草人仅在生命耗尽时消散，不再按回合到期');

console.log('level-one tests passed');
