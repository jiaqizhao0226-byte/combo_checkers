import {
  BOARD_RADIUS, HEX_DIRECTIONS, adjacentMoves, allCells, cellKey,
  hexDistance, isInsideBoard, jumpOptions, occupiedByEnemy,
} from './HexRules.js';
import {
  COMBO_REWARDS, ENEMY_INTROS, ENEMY_TEMPLATES, HERO_TEMPLATE, SKILLS, SKILL_BY_ID,
  skillChoiceView, stageData, stageScale,
} from './ChapterOneData.js';

export function comboDamage(combo, attack = HERO_TEMPLATE.attack) {
  return Math.floor(attack * (1 + (combo - 1) * 0.5));
}

export function resistanceDamage(attack, defense) {
  return Math.max(1, Math.ceil(attack * 100 / ((defense || 0) + 100)));
}

const copyCell = cell => ({ q: cell.q, r: cell.r });
const randomInt = (rng, min, max) => min + Math.floor(rng() * (max - min + 1));
const shuffle = (values, rng) => {
  const result = [...values];
  for (let index = result.length - 1; index > 0; index -= 1) {
    const swapIndex = Math.floor(rng() * (index + 1));
    [result[index], result[swapIndex]] = [result[swapIndex], result[index]];
  }
  return result;
};

const LUCKY_WHEEL_POOL = [
  { id: 'full_hp', name: '生命涌泉', desc: '回满全部HP', icon: '❤️‍🔥' },
  { id: 'shield', name: '神圣护盾', desc: '获得30点护盾', icon: '🛡️' },
  { id: 'extra_skill', name: '天赋觉醒', desc: '额外技能三选一', icon: '⭐' },
  { id: 'extra_turn', name: '时光加速', desc: '获得额外一回合行动', icon: '⏩' },
  { id: 'lucky_strike', name: '灭霸响指', desc: '随机消灭半数小怪', icon: '🫰' },
  { id: 'max_hp_up', name: '体魄强化', desc: '本次战斗最大HP+25', icon: '💗' },
  { id: 'atk_up_buff', name: '战意高涨', desc: '10回合内攻击力+30%', icon: '🔥' },
];
const LUCKY_WHEEL_FIXED = { id: 'small_reward', name: '小确幸', desc: '获得10金币', icon: '🍀' };
const DOOM_WHEEL_POOL = [
  { id: 'dmg_taken_up', name: '脆弱诅咒', desc: '10回合内承伤+30%', icon: '💀' },
  { id: 'max_hp_down', name: '生命侵蚀', desc: '本章最大HP-25%', icon: '💔' },
  { id: 'output_down', name: '力量枯竭', desc: '10回合内输出-30%', icon: '⬇️' },
  { id: 'gold_loss', name: '破财消灾', desc: '失去一半金币', icon: '💸' },
  { id: 'poison', name: '暗毒侵蚀', desc: '5回合每回合损失5%HP', icon: '🧪' },
  { id: 'max_hp_small_down', name: '虚弱诅咒', desc: '最大HP-15', icon: '🩸' },
  { id: 'silence', name: '封喉之咒', desc: '沉默3回合无法攻击', icon: '🤐' },
];
const DOOM_WHEEL_FIXED = { id: 'nothing', name: '无事发生', desc: '虚惊一场，获得3金币', icon: '😮‍💨' };

function normalizeSkills(input = {}) {
  return Array.isArray(input)
    ? Object.fromEntries(input.map(entry => [entry.id, entry.level || 1]))
    : { ...input };
}

export function createLevelOne(options = {}) {
  const rng = options.rng || Math.random;
  const tutorialSeen = Boolean(options.tutorialSeen);
  const tutorialFlags = options.tutorialFlags || {};
  const initialStage = Math.max(1, Math.min(10, options.stage || 1));
  const heroInput = options.hero || {};
  const setEffects = {
    leap_pioneer: options.setEffects?.leap_pioneer || 0,
    combo_mastery: options.setEffects?.combo_mastery || 0,
    soul_hunter: options.setEffects?.soul_hunter || 0,
  };
  const state = {
    chapter: 1, chapterName: '深渊海沟', level: initialStage, stage: initialStage,
    stageName: '', stageSubtitle: '', turn: 1, phase: 'PLAYER_SELECT',
    killTarget: 5, kills: 0, gold: options.gold || 0, combo: 0, maxCombo: 0,
    totalDamage: 0, result: null, chapterComplete: false, message: '',
    hero: {
      q: heroInput.q ?? -2, r: heroInput.r ?? 4,
      hp: heroInput.hp ?? HERO_TEMPLATE.hp, maxHp: heroInput.maxHp ?? HERO_TEMPLATE.hp,
      attack: heroInput.attack ?? HERO_TEMPLATE.attack, defense: heroInput.defense ?? HERO_TEMPLATE.defense,
      shield: heroInput.shield || 0,
    },
    baseHero: { maxHp: heroInput.maxHp ?? heroInput.hp ?? HERO_TEMPLATE.hp, attack: heroInput.attack ?? HERO_TEMPLATE.attack },
    skills: normalizeSkills(options.skills), enemies: [], items: [], traps: [], obstacles: [], scarecrow: null,
    isBossStage: initialStage === 10, boss: null, bossIntent: null,
    drainShield: 0, oneHitShield: false, timeStopTurns: 0, absoluteReflectTurns: 0,
    scarecrowMaxHp: Math.max(1, options.scarecrowMaxHp || 100), plan: [], threatPreview: [],
    tutorialPhase: initialStage === 1 && !tutorialSeen ? 0 : 4,
    tutorialOverlay: null,
    tutorialQueue: [],
    tutorialFlags: { ...tutorialFlags },
    tutorialJustCompleted: false, lastReward: null, lastAction: null, skillChoices: [],
    pendingExecution: null, pendingResult: null, presentationQueue: [], announcement: null,
    skillProc: null, _damageAmpKillStack: 0, _kingmakerCount: 0, _kingmakerReady: false,
    _dawnHeraldUsed: false, _bloodRageSaveUsed: false, comboAtkBonus: 0,
    critRate: Math.max(0, options.critRate || 0), goldBonus: Math.max(0, options.goldBonus || 0),
    setEffects, bloodRageStacks: 0,
    doomWheelSpawnedThisChapter: 0, wheelResult: null, wheelSkillChoices: [], pendingExtraTurn: false,
    luckyAtkUpTurns: 0, doomDamageTakenTurns: 0, doomOutputDownTurns: 0, doomPoisonTurns: 0,
    pendingShuffles: [], bossCasting: null,
    seenEnemyTypes: { ...(options.seenEnemyTypes || {}) }, enemyIntro: [],
  };
  let nextEnemyId = 1;
  let nextItemId = 1;
  let nextObstacleId = 1;
  let nextEventId = 1;

  const skillLevel = id => state.skills[id] || 0;
  const hasCombo = (first, second) => skillLevel(first) > 0 && skillLevel(second) > 0
    && skillLevel(first) + skillLevel(second) >= 5;
  const livingEnemies = () => state.enemies.filter(enemy => enemy.hp > 0);
  const emit = (type, payload = {}) => {
    const event = { id: `fx-${nextEventId++}`, type, duration: payload.duration || 0.65, ...payload };
    state.presentationQueue.push(event);
    return event;
  };
  const announce = (title, subtitle = '', color = '#7ff1d0', duration = 1.2) => {
    state.announcement = { title, subtitle, color, duration };
    emit('announcement', { title, subtitle, color, duration });
  };

  function applyPermanentSkillStats() {
    const glass = skillLevel('glass_cannon');
    const hpFactor = glass ? 1 - (10 + glass * 5) / 100 : 1;
    const attackFactor = glass ? 1 + (15 + glass * 5) / 100 : 1;
    state.hero.maxHp = Math.max(25, Math.floor(state.baseHero.maxHp * hpFactor));
    state.hero.attack = Math.max(1, Math.floor(state.baseHero.attack * attackFactor));
    state.hero.hp = Math.min(state.hero.hp, state.hero.maxHp);
  }

  function blockingUnits() {
    const units = livingEnemies();
    if (state.scarecrow?.hp > 0) units.push({ ...state.scarecrow, id: 'scarecrow', type: 'support' });
    return units;
  }
  const isHeroAt = (q, r) => state.hero.q === q && state.hero.r === r;
  function isFree(q, r, ignoreEnemyId = null) {
    if (!isInsideBoard(q, r) || isHeroAt(q, r)) return false;
    if (state.obstacles.some(obstacle => obstacle.q === q && obstacle.r === r)) return false;
    return !blockingUnits().some(unit => unit.id !== ignoreEnemyId && unit.q === q && unit.r === r && unit.hp > 0);
  }

  function createEnemy(type, q, r, continuing = false) {
    const template = ENEMY_TEMPLATES[type] || ENEMY_TEMPLATES.slime;
    const scale = stageScale(state.stage, continuing);
    const hp = Math.max(1, Math.floor(template.hp * scale.hp));
    return {
      id: `${type}-${nextEnemyId++}`, type, name: template.name, q, r, hp, maxHp: hp,
      attack: Math.max(1, Math.floor(template.attack * scale.attack)),
      defense: template.defense || 0, range: template.range || 1, gold: template.gold || 1,
      stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0, frostStacks: 0,
      hasShell: Boolean(template.hasShell), shellCooldown: 0,
      teleportCooldown: template.teleportCooldown || 0, teleportCooldownRemaining: 0,
      jumpRetaliation: template.jumpRetaliation || 0,
      shuffleOnDeath: Boolean(template.shuffleOnDeath), fleesWhenClose: Boolean(template.fleesWhenClose),
      aoeDamage: Boolean(template.aoeDamage), marked: false,
      armorBrokenTurns: 0, slowedTurns: 0, burnTurns: 0, burnDamage: 0,
    };
  }

  function createBoss(q = 0, r = -3) {
    const template = ENEMY_TEMPLATES.abyss_kraken;
    const boss = {
      id: `abyss_kraken-${nextEnemyId++}`, type: 'abyss_kraken', name: template.name, q, r,
      hp: template.hp, maxHp: template.hp, attack: template.attack, defense: template.defense,
      range: template.range, gold: template.gold, isBoss: true, bossType: template.bossType,
      phase: 1, shieldHp: template.shieldHp, shieldMax: template.shieldMax, enraged: false,
      skillCooldown: template.skillCooldown, clawCooldown: template.clawCooldown,
      tentacleCooldown: template.tentacleCooldown, whirlpoolCooldown: template.whirlpoolCooldown,
      stunnedTurns: 0, frozenTurns: 0, silencedTurns: 0, frostStacks: 0,
      marked: false, armorBrokenTurns: 0, slowedTurns: 0, burnTurns: 0, burnDamage: 0,
    };
    state.enemies.push(boss); state.boss = boss;
    emit('spawn', { q, r, enemyType: boss.type, duration: 0.9 });
    return boss;
  }

  function placeObstacle(type, q, r, turnsLeft = null) {
    if (!isFree(q, r)) return null;
    const obstacle = { id: `obstacle-${nextObstacleId++}`, type, q, r, turnsLeft };
    state.obstacles.push(obstacle);
    emit('obstacle_spawn', { q, r, obstacleType: type, duration: 0.6 });
    return obstacle;
  }

  function spawnEnemy(type, q, r, continuing = false) {
    if (!isFree(q, r)) return null;
    const enemy = createEnemy(type, q, r, continuing);
    state.enemies.push(enemy);
    emit('spawn', { q, r, enemyType: type, duration: 0.55 });
    return enemy;
  }

  function randomPoolType(pool) {
    let type = pool[Math.floor(rng() * pool.length)] || 'slime';
    if (type === 'ghost_shark' && livingEnemies().filter(enemy => enemy.type === type).length >= 2) {
      type = ['jellyfish', 'iron_turtle', 'vortex_eel'][Math.floor(rng() * 3)];
    }
    return type;
  }

  function spawnAtRandomCells(count, pool, outerOnly = false, continuing = false) {
    const candidates = shuffle(allCells(BOARD_RADIUS)
      .filter(cell => !outerOnly || hexDistance(cell, { q: 0, r: 0 }) === BOARD_RADIUS)
      .filter(cell => isFree(cell.q, cell.r))
      .filter(cell => !state.items.some(item => item.q === cell.q && item.r === cell.r)), rng);
    const spawned = [];
    for (const cell of candidates) {
      if (spawned.length >= count) break;
      const enemy = spawnEnemy(randomPoolType(pool), cell.q, cell.r, continuing);
      if (enemy) spawned.push(enemy);
    }
    return spawned;
  }

  function detectNewEnemyTypes() {
    const checked = new Set();
    const intros = [];
    for (const enemy of livingEnemies()) {
      if (enemy.isBoss || checked.has(enemy.type) || state.seenEnemyTypes[enemy.type] || !ENEMY_INTROS[enemy.type]) continue;
      checked.add(enemy.type);
      state.seenEnemyTypes[enemy.type] = true;
      intros.push({ enemyType: enemy.type, ...ENEMY_INTROS[enemy.type] });
    }
    if (intros.length) state.enemyIntro.push(...intros);
    return intros;
  }

  function spawnItem(noWheel = false) {
    const occupied = occupiedByEnemy(livingEnemies());
    const candidates = allCells(BOARD_RADIUS).filter(cell => !isHeroAt(cell.q, cell.r)
      && !occupied.has(cellKey(cell.q, cell.r)) && !state.obstacles.some(obstacle => obstacle.q === cell.q && obstacle.r === cell.r));
    if (!candidates.length) return null;
    const position = candidates[Math.floor(rng() * candidates.length)];
    const weighted = [
      ['health_potion', 25], ['health_potion_big', 5], ['gold_bag', 30], ['shield', 25],
    ];
    if (!noWheel && state.stage > 1) {
      weighted.push(['lucky_wheel', 24]);
      if (state.doomWheelSpawnedThisChapter < 1) weighted.push(['doom_wheel', 12]);
    }
    const total = weighted.reduce((sum, entry) => sum + entry[1], 0);
    let roll = randomInt(rng, 1, total);
    let type = weighted[0][0];
    for (const [candidate, weight] of weighted) {
      roll -= weight;
      if (roll <= 0) { type = candidate; break; }
    }
    if (type === 'doom_wheel') state.doomWheelSpawnedThisChapter += 1;
    const item = { id: `item-${nextItemId++}`, type, q: position.q, r: position.r };
    state.items.push(item);
    return item;
  }

  function spawnSpecificItem(type) {
    const cells = shuffle(allCells(BOARD_RADIUS).filter(cell => isFree(cell.q, cell.r)
      && !state.items.some(item => item.q === cell.q && item.r === cell.r)), rng);
    if (!cells.length) return null;
    const item = { id: `item-${nextItemId++}`, type, ...cells[0] };
    state.items.push(item); return item;
  }

  function refreshHunterMarks() {
    livingEnemies().forEach(enemy => { enemy.marked = false; });
    const lv = skillLevel('hunter_mark');
    if (!lv) return;
    livingEnemies().sort((a, b) => b.hp - a.hp).slice(0, lv >= 4 ? 2 : 1).forEach(enemy => { enemy.marked = true; });
  }

  function configureStage(stage, preserveEnemies = false) {
    const data = stageData(stage);
    Object.assign(state, {
      level: stage, stage, stageName: data.name, stageSubtitle: data.subtitle,
      killTarget: data.killTarget, kills: 0, turn: 1, combo: 0, result: null,
      pendingResult: null, pendingExecution: null, phase: 'PLAYER_SELECT', lastReward: null,
      announcement: null, _damageAmpKillStack: 0, comboAtkBonus: 0,
      isBossStage: stage === 10, bossIntent: null,
    });
    state.pendingShuffles.length = 0; state.bossCasting = null;
    state.plan.length = 0; state.skillChoices.length = 0; state.threatPreview.length = 0;
    state.traps.length = 0; state.obstacles.length = 0; state.scarecrow = null; state.presentationQueue.length = 0;
    if (stage === 10) {
      state.enemies = []; state.items = []; state.boss = null;
      createBoss(0, -3);
      const obstacleCells = shuffle(allCells(BOARD_RADIUS).filter(cell => isFree(cell.q, cell.r)
        && hexDistance(cell, state.hero) > 1 && hexDistance(cell, state.boss) > 1), rng);
      obstacleCells.slice(0, 5).forEach(cell => placeObstacle('reef', cell.q, cell.r));
      spawnAtRandomCells(5, data.pool);
      spawnSpecificItem('health_potion_big'); spawnItem(true);
      state.message = '击败深渊海妖 · 留意触手与漩涡';
      refreshHunterMarks(); computeThreats(state.hero);
      announce('1-10 深渊王座', 'Boss: 深渊海妖', '#c38cff', 1.8);
      detectNewEnemyTypes();
      return;
    }
    state.boss = null;
    state.enemies = preserveEnemies ? livingEnemies() : [];
    const desired = preserveEnemies ? Math.min(6 + Math.floor(stage / 2), 12) : data.initial;
    spawnAtRandomCells(Math.max(0, desired - livingEnemies().length), preserveEnemies ? (data.continuationPool || data.pool) : data.pool, false, preserveEnemies);
    if (!state.items.length) spawnItem();
    state.message = `${data.name} · 击败 ${data.killTarget} 名敌人`;
    refreshHunterMarks(); computeThreats(state.hero);
    announce(`1-${stage} ${data.name}`, data.subtitle, '#79f1cf', 1.35);
    detectNewEnemyTypes();
  }

  function spawnJumpSetup(distance) {
    for (const [dq, dr] of shuffle(HEX_DIRECTIONS, rng)) {
      const enemyCell = { q: state.hero.q + dq * distance, r: state.hero.r + dr * distance };
      const landing = { q: state.hero.q + dq * distance * 2, r: state.hero.r + dr * distance * 2 };
      let clear = true;
      for (let step = 1; step < distance; step += 1) if (!isFree(state.hero.q + dq * step, state.hero.r + dr * step)) clear = false;
      if (clear && isFree(enemyCell.q, enemyCell.r) && isFree(landing.q, landing.r)) return spawnEnemy('slime', enemyCell.q, enemyCell.r);
    }
    return null;
  }

  function spawnChainSetup() {
    for (const [dq1, dr1] of shuffle(HEX_DIRECTIONS, rng)) {
      const enemyOne = { q: state.hero.q + dq1, r: state.hero.r + dr1 };
      const landingOne = { q: state.hero.q + dq1 * 2, r: state.hero.r + dr1 * 2 };
      if (!isFree(enemyOne.q, enemyOne.r) || !isFree(landingOne.q, landingOne.r)) continue;
      for (const [dq2, dr2] of shuffle(HEX_DIRECTIONS, rng)) {
        const enemyTwo = { q: landingOne.q + dq2, r: landingOne.r + dr2 };
        const landingTwo = { q: landingOne.q + dq2 * 2, r: landingOne.r + dr2 * 2 };
        if (!isFree(enemyTwo.q, enemyTwo.r) || !isFree(landingTwo.q, landingTwo.r) || isHeroAt(landingTwo.q, landingTwo.r)) continue;
        const first = spawnEnemy('slime', enemyOne.q, enemyOne.r);
        const second = spawnEnemy('slime', enemyTwo.q, enemyTwo.r);
        if (first && second) return [first, second];
      }
    }
    return [];
  }

  function tryScriptedSpawn() {
    if (state.tutorialPhase === 0) {
      spawnJumpSetup(1); state.tutorialPhase = 1; state.message = '敌人出现！跳过它即可攻击';
      const action = filteredJumpOptions(state.hero)[0];
      if (action) state.tutorialOverlay = actionTutorial({
        id: 'jump', stepLabel: '2 / 5', title: '跳过敌人',
        desc: '越过敌人并落到对称位置，就会立刻发动攻击。',
        hint: '点击橙色落点', accent: '#ffb25f', action,
        focusCells: [state.hero, action.jumpedAt, action],
      });
    }
    else if (state.tutorialPhase === 1) {
      spawnJumpSetup(2); state.tutorialPhase = 2; state.message = '直线上隔一格的敌人也能跳过';
      const action = filteredJumpOptions(state.hero).sort((a, b) => (b.distance || 0) - (a.distance || 0))[0];
      if (action) state.tutorialOverlay = actionTutorial({
        id: 'multiHop', stepLabel: '3 / 5', title: '远距跳跃',
        desc: '直线上遇到的第一个敌人，即使相隔一格，也能以相同距离越过。',
        hint: '点击路径尽头', accent: '#61ddff', action,
        focusCells: [state.hero, action.jumpedAt, action],
      });
    }
    else if (state.tutorialPhase === 2) {
      spawnChainSetup(); state.tutorialPhase = 3; state.message = '连续选择落点，完成二连跳';
      const chain = findTutorialChain();
      if (chain) state.tutorialOverlay = actionTutorial({
        id: 'chainJump', stage: 1, stepLabel: '4 / 5', title: '连续跳跃',
        desc: '落点旁还有可跳过的敌人时，可以继续规划下一跳。',
        hint: '先点击第一个金色落点', accent: '#ffd56c', action: chain.first,
        focusCells: [state.hero, chain.first.jumpedAt, chain.first, chain.second.jumpedAt, chain.second],
        futureCell: chain.second,
      });
    }
    else if (state.tutorialPhase === 3) {
      const spawned = spawnAtRandomCells(3, ['slime'], true);
      state.tutorialPhase = 4; state.tutorialJustCompleted = true; state.message = `${spawned.length} 个敌人从外围出现了！`;
    }
  }

  function tryRegularSpawn() {
    if (state.isBossStage) {
      const minions = livingEnemies().filter(enemy => !enemy.isBoss);
      if (state.turn % 2 !== 0 || minions.length >= 4) return [];
      const spawned = spawnAtRandomCells(1, stageData(state.stage).spawnPool, true, true);
      detectNewEnemyTypes();
      return spawned;
    }
    if (state.turn % 2 !== 0 || livingEnemies().length >= 10) return [];
    const count = randomInt(rng, 1, Math.min(2, 10 - livingEnemies().length));
    const spawned = spawnAtRandomCells(count, stageData(state.stage).spawnPool, true, true);
    detectNewEnemyTypes();
    return spawned;
  }

  const plannedCell = () => copyCell(state.plan.length ? state.plan[state.plan.length - 1] : state.hero);
  function filteredJumpOptions(from) {
    const usedIds = new Set(state.plan.flatMap(step => step.enemyIds || [step.enemyId || step.supportId]).filter(Boolean));
    const blockedLandings = new Set(state.plan.map(step => cellKey(step.q, step.r)));
    blockedLandings.add(cellKey(state.hero.q, state.hero.r));
    const itemBlockers = new Set(state.items.map(item => cellKey(item.q, item.r)));
    const maxJumpOver = state.setEffects.leap_pioneer >= 6 ? 3 : state.setEffects.leap_pioneer >= 4 ? 2 : 1;
    const normal = jumpOptions(from, blockingUnits(), usedIds, itemBlockers, state.obstacles, maxJumpOver)
      .map(action => ({ ...action, isSupport: action.enemyId === 'scarecrow' || action.isObstacle }))
      .filter(action => !blockedLandings.has(cellKey(action.q, action.r)));
    if (state._kingmakerReady && !state.plan.length) {
      const occupied = occupiedByEnemy(blockingUnits());
      for (const enemy of livingEnemies()) {
        const landing = HEX_DIRECTIONS.map(([dq, dr]) => ({ q: enemy.q + dq, r: enemy.r + dr }))
          .find(cell => isInsideBoard(cell.q, cell.r) && !occupied.has(cellKey(cell.q, cell.r)) && !isHeroAt(cell.q, cell.r));
        if (landing && !normal.some(entry => entry.enemyId === enemy.id)) normal.push({ ...landing, kind: 'jump', enemyId: enemy.id, jumpedAt: copyCell(enemy), isKingmaker: true });
      }
    }
    return normal;
  }

  function availableActions() {
    if (state.result || !['PLAYER_SELECT', 'PLAYER_PLAN'].includes(state.phase)) return [];
    const from = plannedCell();
    const jumps = filteredJumpOptions(from);
    const attackOptions = state.hero.silencedTurns > 0 ? [] : jumps;
    const actions = state.plan.length ? attackOptions : [...adjacentMoves(from, blockingUnits(), state.obstacles), ...attackOptions];
    if (!state.tutorialOverlay) return actions;
    if (state.tutorialOverlay.interaction !== 'board') return [];
    const target = state.tutorialOverlay.targetCell;
    return target ? actions.filter(action => action.q === target.q && action.r === target.r) : [];
  }

  function actionTutorial({ id, stage = 1, stepLabel, title, desc, hint, accent, action, focusCells, futureCell = null }) {
    return {
      id, stage, stepLabel, title, desc, hint, accent,
      interaction: 'board', targetCell: copyCell(action),
      focusCells: focusCells.filter(Boolean).map(copyCell),
      futureCell: futureCell ? copyCell(futureCell) : null,
    };
  }

  function completeActionTutorial(id) {
    state.tutorialFlags[`${id}TutorialSeen`] = true;
    state.tutorialOverlay = null;
  }

  function findTutorialChain() {
    for (const first of filteredJumpOptions(state.hero)) {
      state.plan.push(first);
      const second = filteredJumpOptions(first)[0] || null;
      state.plan.pop();
      if (second) return { first, second };
    }
    return null;
  }

  function computeThreats(cell) {
    state.threatPreview = livingEnemies()
      .filter(enemy => enemy.attack > 0 && !enemy.stunnedTurns && !enemy.frozenTurns && !enemy.silencedTurns)
      .map(enemy => ({ enemy, distance: hexDistance(enemy, cell) }))
      .filter(entry => entry.distance <= entry.enemy.range || entry.distance === entry.enemy.range + 1)
      .map(entry => ({
        enemyId: entry.enemy.id,
        distance: entry.distance,
        pending: entry.distance > entry.enemy.range,
        damage: resistanceDamage(entry.enemy.attack, state.hero.defense),
      }));
    return state.threatPreview;
  }

  function select(q, r) {
    if (state.result) return { kind: 'ignored' };
    if (state.phase === 'PLAYER_PLAN' && state.plan.length) {
      const current = plannedCell();
      if (current.q === q && current.r === r) return confirm();
    }
    const action = availableActions().find(option => option.q === q && option.r === r);
    if (!action) { state.message = state.plan.length ? '请选择发光的后续跳跃落点' : '请选择绿色移动格或橙色跳跃落点'; return { kind: 'invalid' }; }
    const tutorial = state.tutorialOverlay?.interaction === 'board' ? state.tutorialOverlay : null;
    if (action.kind === 'move') {
      if (tutorial) completeActionTutorial(tutorial.id);
      return commitMove(action);
    }
    state.phase = 'PLAYER_PLAN'; state.plan.push(action); computeThreats(action);
    if (tutorial?.id === 'chainJump' && tutorial.stage === 1) {
      const next = filteredJumpOptions(action)[0];
      if (next) {
        state.tutorialOverlay = actionTutorial({
          id: 'chainJump', stage: 2, stepLabel: '4 / 5', title: '接上第二跳',
          desc: '第一段已经规划好了。继续选择第二个落点，整条路线才会开始执行。',
          hint: '再点击蓝色终点', accent: '#61ddff', action: next,
          focusCells: [state.hero, action.jumpedAt, action, next.jumpedAt, next],
        });
        state.message = '第一跳已规划，选择聚光灯中的第二个落点';
        return { kind: 'planned', action };
      }
    }
    if (tutorial) completeActionTutorial(tutorial.id);
    if (!filteredJumpOptions(action).length) return confirm();
    state.message = `${state.plan.length} 步已规划，点当前格或确认结束`;
    return { kind: 'planned', action };
  }

  function undo() {
    if (!state.plan.length || state.result) return false;
    state.plan.pop(); state.phase = state.plan.length ? 'PLAYER_PLAN' : 'PLAYER_SELECT'; computeThreats(plannedCell());
    state.message = state.plan.length ? `已撤销，当前 ${state.plan.length} 步` : '已撤销全部，重新选择行动';
    return true;
  }

  function pickupItemAt(q, r, options = {}) {
    const index = state.items.findIndex(item => item.q === q && item.r === r);
    if (index < 0) return null;
    const [item] = state.items.splice(index, 1);
    let amount = 0;
    let label = '';
    if (item.type === 'health_potion') {
      const before = state.hero.hp;
      state.hero.hp = Math.min(state.hero.maxHp, state.hero.hp + 40);
      amount = state.hero.hp - before;
      label = `+${amount} HP`;
    }
    else if (item.type === 'health_potion_big') {
      amount = state.hero.maxHp - state.hero.hp;
      state.hero.hp = state.hero.maxHp;
      label = amount > 0 ? `回满 HP · +${amount}` : 'HP 已满';
    }
    else if (item.type === 'gold_bag') {
      const baseGold = !state.isBossStage && state.kills - state.killTarget > 5 ? 2 : 10;
      amount = baseGold + Math.floor(baseGold * state.goldBonus / 100);
      state.gold += amount;
      label = `+${amount} 金币`;
    }
    else if (item.type === 'shield') { state.oneHitShield = true; label = '护盾就绪'; }
    else if (item.type === 'lucky_wheel' || item.type === 'doom_wheel') spinWheel(item.type === 'lucky_wheel' ? 'lucky' : 'doom');
    if (!options.suppressPresentation) {
      emit('pickup', { q, r, itemType: item.type, amount, label, duration: 0.8 });
    }
    return { ...item, amount, label };
  }

  function spinWheel(type) {
    const lucky = type === 'lucky';
    const pool = lucky ? LUCKY_WHEEL_POOL : DOOM_WHEEL_POOL;
    const fixed = lucky ? LUCKY_WHEEL_FIXED : DOOM_WHEEL_FIXED;
    const outcomes = shuffle(pool, rng).slice(0, 3);
    outcomes.push(fixed);
    const outcome = shuffle(outcomes, rng)[0];
    applyWheelOutcome(outcome);
    state.wheelResult = { type, outcome, outcomes };
    emit('wheel', { q: state.hero.q, r: state.hero.r, wheelType: type, outcomeId: outcome.id, duration: 1.2 });
    announce(`${outcome.icon} ${outcome.name}`, outcome.desc, lucky ? '#ffe17a' : '#cf83ff', 1.4);
  }

  function applyWheelOutcome(outcome) {
    if (outcome.id === 'full_hp') state.hero.hp = state.hero.maxHp;
    else if (outcome.id === 'shield') state.hero.shield += 30;
    else if (outcome.id === 'extra_skill') state.wheelSkillChoices = shuffle(SKILLS.filter(def => (state.skills[def.id] || 0) < def.maxLevel), rng).slice(0, 3).map(def => skillChoiceView(def.id, state.skills[def.id] || 0));
    else if (outcome.id === 'extra_turn') state.pendingExtraTurn = true;
    else if (outcome.id === 'lucky_strike') {
      const minions = livingEnemies().filter(enemy => !enemy.isBoss);
      const targets = shuffle(minions, rng).slice(0, Math.max(1, Math.ceil(minions.length / 2)));
      targets.forEach(enemy => damageEnemy(enemy, enemy.hp, 'lucky_strike', [], { ignoreDefense: true, fromChain: true }));
    } else if (outcome.id === 'max_hp_up') state.hero.maxHp += 25;
    else if (outcome.id === 'atk_up_buff') state.luckyAtkUpTurns += 10;
    else if (outcome.id === 'small_reward') state.gold += 10;
    else if (outcome.id === 'dmg_taken_up') state.doomDamageTakenTurns += 10;
    else if (outcome.id === 'max_hp_down') {
      state.hero.maxHp -= Math.floor(state.hero.maxHp * 0.25);
      state.hero.hp = Math.min(state.hero.hp, state.hero.maxHp);
    } else if (outcome.id === 'output_down') state.doomOutputDownTurns += 10;
    else if (outcome.id === 'gold_loss') state.gold -= Math.floor(state.gold / 2);
    else if (outcome.id === 'poison') state.doomPoisonTurns += 5;
    else if (outcome.id === 'max_hp_small_down') {
      state.hero.maxHp = Math.max(1, state.hero.maxHp - 15);
      state.hero.hp = Math.min(state.hero.hp, state.hero.maxHp);
    } else if (outcome.id === 'silence') state.hero.silencedTurns = (state.hero.silencedTurns || 0) + 3;
    else if (outcome.id === 'nothing') state.gold += 3;
  }

  function dismissWheel() {
    if (!state.wheelResult) return { kind: 'invalid' };
    state.wheelResult = null;
    if (state.wheelSkillChoices.length) return { kind: 'wheel_skill' };
    if (state.pendingExtraTurn) {
      state.pendingExtraTurn = false;
      state.phase = 'PLAYER_SELECT';
      state.plan.length = 0;
      computeThreats(state.hero);
      return { kind: 'extra_turn' };
    }
    return { kind: 'closed' };
  }

  function selectWheelSkill(index) {
    const choice = state.wheelSkillChoices[index];
    if (!choice) return { kind: 'invalid' };
    const definition = SKILL_BY_ID[choice.id];
    const level = Math.min(definition.maxLevel, (state.skills[choice.id] || 0) + 1);
    state.skills[choice.id] = level;
    state.wheelSkillChoices.length = 0;
    applyPermanentSkillStats();
    announce(`${choice.name} Lv.${level}`, definition.describe(level), choice.color, 1.3);
    return { kind: 'wheel_skill', id: choice.id, level };
  }

  function damageAmp() {
    const lv = skillLevel('damage_amp');
    return lv ? 1 + (5 + lv * 3 + (lv >= 3 && state.combo >= 4 ? 8 : 0) + (lv >= 5 ? state._damageAmpKillStack : 0)) / 100 : 1;
  }

  function queueNearbyShuffle(origin) {
    state.pendingShuffles.push(copyCell(origin));
  }

  function applyPendingShuffles() {
    if (!state.pendingShuffles.length) return [];
    const movements = [];
    for (const origin of state.pendingShuffles) {
      const neighborKeys = new Set(HEX_DIRECTIONS.map(([dq, dr]) => cellKey(origin.q + dq, origin.r + dr)));
      const movable = [state.hero, ...livingEnemies().filter(enemy => !enemy.isBoss)];
      if (state.scarecrow?.hp > 0) movable.push(state.scarecrow);
      const nearby = movable.filter(piece => neighborKeys.has(cellKey(piece.q, piece.r)));
      const fixedCells = new Set([
        ...livingEnemies().filter(enemy => enemy.isBoss).map(enemy => cellKey(enemy.q, enemy.r)),
        ...state.obstacles.map(obstacle => cellKey(obstacle.q, obstacle.r)),
      ]);
      const slots = HEX_DIRECTIONS.map(([dq, dr]) => ({ q: origin.q + dq, r: origin.r + dr }))
        .filter(cell => isInsideBoard(cell.q, cell.r) && !fixedCells.has(cellKey(cell.q, cell.r)));
      if (nearby.length <= 1 || slots.length < nearby.length) continue;
      const destinations = shuffle(slots, rng).slice(0, nearby.length);
      const effectMovements = [];
      nearby.forEach((piece, index) => {
        const from = copyCell(piece); const to = destinations[index];
        Object.assign(piece, to);
        if (from.q !== to.q || from.r !== to.r) {
          const movement = { id: piece.id || 'hero', from, to: copyCell(to) };
          movements.push(movement); effectMovements.push(movement);
        }
      });
      emit('vortex', { q: origin.q, r: origin.r, movements: effectMovements, duration: 1.2 });
    }
    state.pendingShuffles.length = 0;
    return movements;
  }

  function handleDeath(enemy, source, hits, fromChain = false, suppressPresentation = false) {
    state.kills += 1;
    const overflow = state.kills - state.killTarget;
    state.gold += enemy.isBoss ? enemy.gold : overflow > 5 ? 1 : enemy.gold + Math.floor(enemy.gold * state.goldBonus / 100);
    if (!suppressPresentation) {
      emit('death', { q: enemy.q, r: enemy.r, enemyId: enemy.id, enemyType: enemy.type, duration: 0.7 });
    }
    if (skillLevel('vampiric_jump') >= 3) {
      state.comboAtkBonus = Math.min(30, state.comboAtkBonus + 5);
      state.hero.hp = Math.min(state.hero.maxHp, state.hero.hp + 12);
      emit('heal', { q: state.hero.q, r: state.hero.r, amount: 12, label: '+12 吸血', duration: 0.7 });
    }
    if (skillLevel('damage_amp') >= 5) state._damageAmpKillStack = Math.min(12, state._damageAmpKillStack + 3);
    if (enemy.isBoss) {
      state.boss = enemy;
      state.bossIntent = null;
      announce('深渊海妖被击败', '深渊王座恢复平静', '#ffe58b', 1.8);
      emit('boss_defeat', { q: enemy.q, r: enemy.r, duration: 1.8 });
    }
    if (enemy.shuffleOnDeath) queueNearbyShuffle(enemy);
    if (!fromChain) { applyChainLightning(enemy, hits); applySplitShot(enemy, hits); }
    if (enemy.marked && skillLevel('hunter_mark') >= 5) state.hero.hp = Math.min(state.hero.maxHp, state.hero.hp + Math.floor(state.hero.maxHp * 0.15));
    if (hasCombo('blood_rage', 'glass_cannon')) {
      const rage = skillLevel('blood_rage');
      if (rage && state.hero.hp < state.hero.maxHp * (rage >= 5 ? 0.3 : 0.5)) state.hero.hp = Math.min(state.hero.maxHp, state.hero.hp + 3);
    }
    if (state.setEffects.soul_hunter >= 4) {
      const heal = Math.min(state.hero.maxHp - state.hero.hp, 3 + Math.floor(state.hero.maxHp * 0.015));
      state.hero.hp += heal;
      if (heal > 0) emit('heal', { q: state.hero.q, r: state.hero.r, amount: heal, label: `+${heal} 猎魂`, duration: 0.6 });
      if (state.setEffects.soul_hunter >= 6 && state.hero.hp / state.hero.maxHp < 0.5 && state.bloodRageStacks < 3) {
        state.bloodRageStacks += 1;
        announce('血怒叠层', `当前 ${state.bloodRageStacks}/3`, '#e63e52', 0.8);
      }
    }
  }

  function damageEnemy(enemy, damage, source, hits = [], options = {}) {
    if (!enemy || enemy.hp <= 0) return 0;
    let scaled = damage;
    if (!options.skipModifiers) {
      if (options.skill) scaled *= damageAmp();
      if (enemy.marked) scaled *= 1 + (20 + skillLevel('hunter_mark') * 5) / 100;
      if (enemy.silencedTurns > 0 && skillLevel('silence_path') >= 3) scaled *= 1.15;
      if (skillLevel('spike_trap') >= 5 && state.traps.some(trap => trap.q === enemy.q && trap.r === enemy.r)) scaled *= 1.2;
      const collector = skillLevel('collector');
      if (collector && enemy.hp / enemy.maxHp < (30 + collector * 5) / 100) scaled *= 1 + (collector === 5 ? 50 : 20 + collector * 10) / 100;
      if (enemy.frozenTurns > 0 && skillLevel('frost_mark') >= 5) scaled *= 1.3;
      if (enemy.hasShell && source === 'jump') scaled *= 0.5;
    }
    const defense = options.ignoreDefense ? 0 : enemy.armorBrokenTurns > 0 ? Math.floor((enemy.defense || 0) * 0.5) : enemy.defense || 0;
    let actual = Math.max(1, Math.floor(scaled) - defense);
    if (enemy.isBoss) actual = Math.min(actual, Math.floor(enemy.maxHp * 0.4));
    if (enemy.isBoss && enemy.shieldHp > 0) {
      const absorbed = Math.min(enemy.shieldHp, actual);
      enemy.shieldHp -= absorbed; actual -= absorbed;
      emit('shield_hit', { q: enemy.q, r: enemy.r, damage: absorbed, duration: 0.5 });
    }
    enemy.hp = Math.max(0, enemy.hp - actual); state.totalDamage += actual;
    const hit = { enemyId: enemy.id, q: enemy.q, r: enemy.r, damage: actual, killed: enemy.hp === 0, source };
    hits.push(hit);
    if (!options.suppressPresentation && actual > 0) {
      emit('damage', {
        ...hit,
        combo: source === 'jump' ? state.combo : 0,
        suppressNumber: Boolean(options.suppressNumber),
        duration: 0.5,
      });
    }
    if (!options.skipModifiers && enemy.marked && skillLevel('hunter_mark') >= 3) {
      state.hero.hp = Math.min(state.hero.maxHp, state.hero.hp + 5);
      emit('heal', { q: state.hero.q, r: state.hero.r, amount: 5, label: '+5 印记', duration: 0.45 });
    }
    if (enemy.isBoss && !enemy.enraged && enemy.hp > 0 && enemy.hp <= enemy.maxHp * 0.25) {
      enemy.enraged = true; enemy.phase = 2; enemy.attack = Math.floor(enemy.attack * 1.3);
      announce('海妖狂暴', '攻击提升，技能冷却缩短', '#ff5d8f', 1.35);
      emit('boss_enrage', { q: enemy.q, r: enemy.r, duration: 1.2 });
    }
    if (enemy.hp === 0) handleDeath(enemy, source, hits, options.fromChain, options.suppressDeathPresentation);
    return actual;
  }

  function applyChainLightning(origin, hits) {
    const lv = skillLevel('chain_lightning');
    if (!lv) return;
    const targets = livingEnemies()
      .filter(enemy => enemy.id !== origin.id)
      .sort((a, b) => hexDistance(a, origin) - hexDistance(b, origin))
      .slice(0, lv);
    targets.forEach(target => {
      emit('lightning', { from: copyCell(origin), to: copyCell(target), duration: 0.42 });
      damageEnemy(target, 13 + lv * 2, 'chain_lightning', hits, {
        ignoreDefense: true, skipModifiers: true, fromChain: true,
      });
    });
  }

  function applySplitShot(origin, hits, isSecondary = false) {
    const lv = skillLevel('split_shot');
    if (!lv) return;
    const count = 1 + Math.floor(lv / 2);
    livingEnemies().sort((a, b) => hexDistance(a, origin) - hexDistance(b, origin)).slice(0, count).forEach((target, index) => {
      emit('projectile', {
        from: copyCell(origin), to: copyCell(target), color: '#66e0f2',
        projectileType: 'energy_shard', duration: 0.45,
      });
      const damage = lv >= 3 ? 5 + lv * 5 : Math.floor((5 + lv * 5) * (1 - index * 0.2));
      const wasAlive = target.hp > 0;
      damageEnemy(target, damage, isSecondary ? 'split_shot_secondary' : 'split_shot', hits, {
        ignoreDefense: true, skipModifiers: true, fromChain: true,
      });
      if (!isSecondary && hasCombo('split_shot', 'spike_trap')) {
        const existing = state.traps.find(entry => entry.q === target.q && entry.r === target.r);
        const mine = { q: target.q, r: target.r, damage: 25, turnsLeft: 2, slow: true };
        if (!existing) {
          state.traps.push(mine);
          emit('trap', { q: target.q, r: target.r, duration: 0.5 });
        }
      }
      if (lv >= 5 && !isSecondary && wasAlive && target.hp <= 0) applySplitShot(target, hits, true);
    });
  }

  function applyFrostMark(enemy) {
    const lv = skillLevel('frost_mark');
    if (!lv || enemy.hp <= 0) return;
    const threshold = lv === 1 ? 4 : lv < 4 ? 3 : 2;
    enemy.frostStacks += 1; emit('frost', { q: enemy.q, r: enemy.r, stacks: enemy.frostStacks, duration: 0.5 });
    if (enemy.frostStacks >= threshold) {
      enemy.frostStacks = 0; enemy.frozenTurns += lv >= 3 ? 2 : 1;
      emit('freeze', { q: enemy.q, r: enemy.r, duration: 0.9 });
    }
  }

  function applySilencePath(step, jumpedEnemy) {
    const lv = skillLevel('silence_path');
    if (!lv || !jumpedEnemy) return;
    const turns = 1 + Math.floor(lv / 2);
    jumpedEnemy.silencedTurns = Math.max(jumpedEnemy.silencedTurns || 0, turns);
    if (lv >= 4) {
      livingEnemies()
        .filter(enemy => enemy.id !== jumpedEnemy.id && hexDistance(enemy, step.jumpedAt) <= 1)
        .forEach(enemy => { enemy.silencedTurns = Math.max(enemy.silencedTurns || 0, turns); });
    }
    emit('silence', { q: step.jumpedAt.q, r: step.jumpedAt.r, range: lv >= 4 ? 2 : 1, duration: 0.7 });
  }

  function jumpDamageFor(combo, step) {
    let attack = state.hero.attack + state.comboAtkBonus;
    if (state.doomOutputDownTurns > 0) attack = Math.ceil(attack * 0.7);
    if (state.luckyAtkUpTurns > 0) attack = Math.ceil(attack * 1.3);
    const rage = skillLevel('blood_rage');
    if (rage && state.hero.hp < state.hero.maxHp * (rage >= 5 ? 0.3 : 0.5)) attack *= rage >= 5 ? 2 : 1 + (20 + rage * 6) / 100;
    const gravity = skillLevel('gravity_stomp');
    if (combo >= 3 && (gravity || skillLevel('quake_land') >= 4 || skillLevel('vampiric_jump') >= 3)) {
      attack *= 1 + (50 + gravity * 22) / 100;
    }
    const comboRate = gravity >= 4 ? 0.75 : 0.5;
    const comboMultiplier = gravity >= 4 ? Math.min(3, 1 + (combo - 1) * comboRate) : 1 + (combo - 1) * comboRate;
    let damage = attack * comboMultiplier;
    if (step.isKingmaker && skillLevel('kingmaker') >= 3) damage *= 1.2;
    if (skillLevel('vampiric_jump') >= 5 && state.hero.hp > state.hero.maxHp * 0.8) damage += state.hero.attack * 0.2;
    if (hasCombo('blood_rage', 'glass_cannon')) {
      const rageLv = skillLevel('blood_rage');
      const threshold = rageLv >= 5 ? 0.3 : 0.5;
      if (rageLv && state.hero.hp < state.hero.maxHp * threshold) damage += state.hero.attack * 0.4;
    }
    if (state.bloodRageStacks > 0) {
      state.bloodRageStacks -= 1;
      damage *= 1.5;
      announce('血怒', '本次跳跃伤害 x1.5', '#e63e52', 0.75);
    }
    return Math.floor(damage);
  }

  function applyHeroDamage(damage, label = '', options = {}) {
    let remaining = Math.max(0, options.raw ? damage : state.doomDamageTakenTurns > 0 ? Math.ceil(damage * 1.3) : damage);
    if (!options.raw && state.oneHitShield) {
      const before = remaining;
      remaining = Math.floor(remaining / 2);
      state.oneHitShield = false;
      emit('shield_hit', { q: state.hero.q, r: state.hero.r, damage: before - remaining, target: 'hero', duration: 0.45 });
      emit('shield_break', { q: state.hero.q, r: state.hero.r, target: 'hero', duration: 0.6 });
    }
    if (!options.raw && state.drainShield > 0) {
      const absorbed = Math.min(state.drainShield, remaining);
      state.drainShield -= absorbed;
      remaining -= absorbed;
      if (absorbed > 0) emit('shield_hit', { q: state.hero.q, r: state.hero.r, damage: absorbed, target: 'hero', duration: 0.45 });
      if (state.drainShield === 0) emit('shield_break', { q: state.hero.q, r: state.hero.r, target: 'hero', duration: 0.6 });
    }
    if (!options.raw && state.hero.shield > 0) {
      const absorbed = Math.min(state.hero.shield, remaining);
      state.hero.shield -= absorbed;
      remaining -= absorbed;
      if (absorbed > 0) emit('shield_hit', { q: state.hero.q, r: state.hero.r, damage: absorbed, target: 'hero', duration: 0.45 });
      if (state.hero.shield === 0) emit('shield_break', { q: state.hero.q, r: state.hero.r, target: 'hero', duration: 0.6 });
    }
    state.hero.hp -= remaining;
    if (state.hero.hp <= 0 && skillLevel('dawn_herald') && !state._dawnHeraldUsed) {
      state._dawnHeraldUsed = true; state.hero.hp = Math.max(1, Math.floor(state.hero.maxHp * 0.3)); announce('黎明使者', '免疫致命伤害', '#ffd76a');
    } else if (state.hero.hp <= 0 && skillLevel('blood_rage') >= 5 && !state._bloodRageSaveUsed) {
      state._bloodRageSaveUsed = true; state.hero.hp = 1; announce('血怒不屈', '免疫一次致死', '#ff594d');
    }
    if (remaining > 0) emit('hero_hit', { q: state.hero.q, r: state.hero.r, damage: remaining, label, duration: 0.55 });
    return remaining;
  }

  function processBossAura() {
    const boss = state.boss;
    if (!state.isBossStage || !boss || boss.hp <= 0 || hexDistance(boss, state.hero) > 2) return 0;
    const aura = boss.enraged ? 4 : 3;
    const damage = resistanceDamage(aura, state.hero.defense);
    return applyHeroDamage(damage, '深渊压迫');
  }

  function applyQuakeChain(source, hits, label = 'quake_chain') {
    if (!source || source.hp <= 0) return null;
    const target = livingEnemies().filter(enemy => enemy.id !== source.id)
      .sort((a, b) => hexDistance(a, source) - hexDistance(b, source))[0];
    if (!target) return null;
    emit('lightning', { from: copyCell(source), to: copyCell(target), duration: 0.5 });
    damageEnemy(target, 15, label, hits, { ignoreDefense: true, skipModifiers: true, fromChain: true });
    return target;
  }

  function applyLandingSkills(from, to, jumpedEnemy, hits, isLastStep = true) {
    const quake = skillLevel('quake_land');
    if (isLastStep && quake) {
      const range = quake >= 3 ? 2 : 1;
      const fullMap = quake >= 4 && state.combo >= 3;
      const targets = fullMap ? [...livingEnemies()] : livingEnemies().filter(enemy => hexDistance(enemy, to) <= range);
      const quakeDamage = fullMap ? 12 + 5 * state.combo : 10 + quake * 5;
      emit('quake', { q: to.q, r: to.r, range, duration: 0.75 });
      const survivors = [];
      targets.forEach(enemy => {
        damageEnemy(enemy, quakeDamage * damageAmp(), fullMap ? 'cataclysm' : 'quake_land', hits, { ignoreDefense: true, skipModifiers: true });
        if (enemy.hp > 0) survivors.push(enemy);
        if (!fullMap && enemy.hp > 0 && hasCombo('chain_lightning', 'quake_land') && rng() < 0.5) {
          applyQuakeChain(enemy, hits, 'thunder_quake');
        }
      });
      if (!fullMap && quake >= 3) survivors.forEach(enemy => applyQuakeChain(enemy, hits));
    } else if (isLastStep) {
      const baseDamage = Math.max(5, Math.floor(state.hero.attack * 0.4)) * damageAmp();
      emit('shockwave', { q: to.q, r: to.r, duration: 0.4 });
      [...livingEnemies()].filter(enemy => hexDistance(enemy, to) === 1).forEach(enemy => {
        damageEnemy(enemy, baseDamage, 'landing_shock', hits, { skipModifiers: true });
      });
    }
    const trap = skillLevel('spike_trap');
    if (trap) {
      const candidates = HEX_DIRECTIONS.map(([dq, dr]) => ({ q: from.q + dq, r: from.r + dr }))
        .filter(cell => isInsideBoard(cell.q, cell.r) && isFree(cell.q, cell.r)
          && !state.traps.some(entry => entry.q === cell.q && entry.r === cell.r));
      candidates.slice(0, Math.min(trap, 3)).forEach(cell => {
        state.traps.push({ ...cell, damage: 5 + trap * 5, turnsLeft: 4 + trap, slow: trap >= 3 });
        emit('trap', { ...cell, duration: 0.6 });
      });
    }
    const shield = skillLevel('combo_shield');
    if (shield) {
      const amount = (2 + shield * 2) * (shield >= 5 && state.combo >= 5 ? 2 : 1);
      state.hero.shield = Math.min(10 + shield * 10, state.hero.shield + amount);
      emit('shield', { q: to.q, r: to.r, amount, duration: 0.55 });
    }
    if (jumpedEnemy?.jumpRetaliation && jumpedEnemy.hp > 0) {
      resolveReflectedHeroAttack(jumpedEnemy, jumpedEnemy.jumpRetaliation, '电水母反伤');
    }
    if (hasCombo('hunter_mark', 'collector')) {
      [...livingEnemies()].filter(enemy => !enemy.isBoss && enemy.hp / enemy.maxHp <= 0.2).forEach(enemy => {
        damageEnemy(enemy, enemy.hp, 'hunter_instinct', hits, {
          ignoreDefense: true, skipModifiers: true, fromChain: true,
        });
        state.hero.hp = Math.min(state.hero.maxHp, state.hero.hp + 10);
        emit('execute', { q: enemy.q, r: enemy.r, duration: 0.65 });
      });
    }
  }

  function closestEnemy() {
    return livingEnemies().sort((a, b) => hexDistance(a, state.hero) - hexDistance(b, state.hero))[0];
  }

  function executeComboReward(hits) {
    if (state.combo < 2) return null;
    // Nine-combo and above has its own reserved reward route. Until the
    // special skill-choice system is rebuilt it deliberately does not fall
    // back to the eight-combo reflect reward.
    const threshold = Math.min(state.combo, 9);
    const definition = COMBO_REWARDS[threshold];
    const reward = { threshold, ...definition, hits: [], presentation: { threshold, targets: [] } };
    if (!state.tutorialFlags.comboTutorialSeen) {
      state.tutorialOverlay = {
        id: 'combo', stepLabel: state.tutorialPhase < 4 ? '5 / 5' : '连击教学',
        title: `${threshold} 连击奖励`,
        desc: `${definition.name} 已触发。连续跳跃会累积连击，并在整条路线执行完成后统一结算奖励。`,
        hint: '点击继续战斗', accent: definition.color,
        interaction: 'continue', focusCells: [copyCell(state.hero)],
      };
    }
    announce(`${threshold} 连击`, definition.name, definition.color, definition.duration);
    emit('combo_burst', { threshold, q: state.hero.q, r: state.hero.r, color: definition.color, duration: definition.duration });
    if (threshold === 2) {
      const dartLv = skillLevel('dart_storm');
      const count = dartLv ? 1 + dartLv : 1;
      const targets = [
        ...livingEnemies().map(enemy => ({ kind: 'enemy', object: enemy, q: enemy.q, r: enemy.r })),
        ...state.items.map(item => ({ kind: 'item', object: item, q: item.q, r: item.r })),
      ].sort((a, b) => hexDistance(a, state.hero) - hexDistance(b, state.hero));
      for (let index = 0; index < count && targets.length; index += 1) {
        const targetInfo = targets[index % targets.length];
        const target = targetInfo.object;
        const damage = Math.floor((30 + dartLv * 5) * Math.max(0.4, 1 - index * 0.12));
        let impact = { kind: targetInfo.kind, targetId: target.id, q: target.q, r: target.r };
        if (targetInfo.kind === 'item') {
          pickupItemAt(target.q, target.r, { suppressPresentation: true });
          impact = { ...impact, label: '自动拾取' };
        } else if (target.hp > 0) {
          const actualDamage = damageEnemy(target, damage, 'dart', reward.hits, {
            ignoreDefense: true, skipModifiers: true, fromChain: true,
            suppressPresentation: true, suppressDeathPresentation: true,
          });
          impact = { ...impact, damage: actualDamage, killed: target.hp <= 0 };
          if (dartLv >= 5 && target.hp > 0) { target.burnTurns = 2; target.burnDamage = 6; }
        }
        emit('projectile', {
          from: copyCell(state.hero), to: copyCell(targetInfo), color: '#ffb64c', impact,
          projectileType: 'tracking_dart', duration: 0.6 + index * 0.12,
        });
      }
      if (!targets.length) {
        const heal = 15 + dartLv * 5;
        state.hero.hp = Math.min(state.hero.maxHp, state.hero.hp + heal);
        emit('projectile', {
          from: copyCell(state.hero), to: copyCell(state.hero), color: '#6effc6',
          projectileType: 'tracking_dart', duration: 0.6,
          impact: { kind: 'heal', amount: heal, q: state.hero.q, r: state.hero.r },
        });
      }
    } else if (threshold === 3) {
      const occupied = occupiedByEnemy(livingEnemies());
      const candidates = allCells(BOARD_RADIUS).filter(cell => !isHeroAt(cell.q, cell.r) && !occupied.has(cellKey(cell.q, cell.r))).sort((a, b) => hexDistance(a, state.hero) - hexDistance(b, state.hero));
      if (candidates.length) {
        const position = candidates[Math.floor(rng() * Math.min(4, candidates.length))];
        state.scarecrow = {
          ...position,
          hp: state.scarecrowMaxHp,
          maxHp: state.scarecrowMaxHp,
          defense: state.hero.defense,
        };
        reward.presentation.scarecrow = { ...position, hp: state.scarecrow.hp, maxHp: state.scarecrow.maxHp };
        emit('scarecrow', { ...position, duration: 0.9 });
        if (!state.tutorialFlags.scarecrowTutorialSeen) {
          const tutorial = {
            id: 'scarecrow', stepLabel: '连击教学', title: '稻草人友军',
            desc: '稻草人拥有独立生命值并吸引所有敌人攻击；生命耗尽时才会消散。',
            hint: '点击继续战斗', accent: '#e2b86f', interaction: 'continue',
            focusCells: [copyCell(state.scarecrow)],
          };
          if (state.tutorialOverlay) state.tutorialQueue.push(tutorial); else state.tutorialOverlay = tutorial;
        }
      }
    } else if (threshold === 4) {
      [...livingEnemies()].forEach(enemy => {
        const dq = enemy.q - state.hero.q; const dr = enemy.r - state.hero.r;
        const onRay = dq === 0 || dr === 0 || dq + dr === 0;
        if (!onRay) return;
        const damage = damageEnemy(enemy, enemy.isBoss ? 60 : enemy.hp, 'hex_blast', reward.hits, {
          ignoreDefense: true, skipModifiers: true, fromChain: true,
          suppressPresentation: true, suppressDeathPresentation: true,
        });
        reward.presentation.targets.push({
          enemyId: enemy.id, q: enemy.q, r: enemy.r, kind: enemy.isBoss ? 'boss' : 'minion',
          damage, killed: enemy.hp <= 0,
        });
      });
    } else if (threshold === 5) {
      let totalDrain = 0;
      const heroHpBefore = state.hero.hp;
      const shieldBefore = state.drainShield;
      [...livingEnemies()].forEach(enemy => {
        const hpBefore = enemy.hp;
        const damage = damageEnemy(enemy, enemy.isBoss ? 30 : Math.max(5, Math.floor(enemy.hp * 0.2)), 'life_drain', reward.hits, {
          ignoreDefense: true, skipModifiers: true, fromChain: true,
          suppressPresentation: true, suppressDeathPresentation: true,
        });
        totalDrain += damage;
        reward.presentation.targets.push({
          enemyId: enemy.id, q: enemy.q, r: enemy.r, kind: enemy.isBoss ? 'boss' : 'minion',
          hp: hpBefore, damage, killed: enemy.hp <= 0,
        });
      });
      const healing = Math.min(totalDrain, state.hero.maxHp - state.hero.hp);
      state.hero.hp += healing; state.drainShield = Math.min(60, state.drainShield + totalDrain - healing);
      reward.presentation.outcome = {
        totalDrain, heroHpBefore, heal: healing, overflow: Math.max(0, totalDrain - healing),
        shieldBefore, shieldAdded: state.drainShield - shieldBefore,
        shieldTotal: state.drainShield, shieldFull: state.drainShield >= 60,
      };
    } else if (threshold === 6) {
      state.timeStopTurns = 2;
      reward.presentation.turns = 2;
      reward.presentation.targets = livingEnemies().map(enemy => ({
        enemyId: enemy.id, q: enemy.q, r: enemy.r, kind: enemy.isBoss ? 'boss' : 'minion',
      }));
    } else if (threshold === 7) {
      [...livingEnemies()].forEach(enemy => {
        const damage = damageEnemy(enemy, enemy.isBoss ? 120 : 180, 'meteor_aoe', reward.hits, {
          ignoreDefense: true, skipModifiers: true, fromChain: true,
          suppressPresentation: true, suppressDeathPresentation: true,
        });
        reward.presentation.targets.push({
          enemyId: enemy.id, q: enemy.q, r: enemy.r, kind: enemy.isBoss ? 'boss' : 'minion',
          damage, killed: enemy.hp <= 0,
        });
      });
    } else if (threshold === 8) {
      state.absoluteReflectTurns = 4;
      reward.presentation.turns = 4;
    } else if (threshold === 9) {
      reward.presentation.deferredSkillChoice = true;
    }
    emit('combo_reward', reward.presentation);
    state.lastReward = reward; hits.push(...reward.hits); return reward;
  }

  function resolveReflectedHeroAttack(attacker, damage, label, options = {}) {
    if (state.absoluteReflectTurns <= 0 || !attacker || attacker.hp <= 0) {
      return { damage: applyHeroDamage(damage, label, options), reflected: 0 };
    }
    const reflected = damageEnemy(attacker, Math.max(1, damage), 'absolute_reflect', [], {
      ignoreDefense: true, skipModifiers: true, fromChain: true,
      suppressPresentation: true, suppressDeathPresentation: true,
    });
    emit('absolute_reflect_hit', {
      enemyId: attacker.id, from: copyCell(attacker), to: copyCell(state.hero),
      damage: reflected, killed: attacker.hp <= 0, duration: 0.72,
    });
    return { damage: 0, reflected };
  }

  function chooseStep(enemy, target, away = false) {
    const occupied = occupiedByEnemy(blockingUnits()); occupied.delete(cellKey(enemy.q, enemy.r));
    return HEX_DIRECTIONS.map(([dq, dr]) => ({ q: enemy.q + dq, r: enemy.r + dr }))
      .filter(cell => isInsideBoard(cell.q, cell.r) && !occupied.has(cellKey(cell.q, cell.r))
        && !state.obstacles.some(obstacle => obstacle.q === cell.q && obstacle.r === cell.r) && !isHeroAt(cell.q, cell.r))
      .sort((a, b) => (away ? -1 : 1) * (hexDistance(a, target) - hexDistance(b, target)))[0];
  }

  function resolveBossBasicAttack(boss, actions) {
    const target = state.scarecrow?.hp > 0 ? state.scarecrow : state.hero;
    const from = copyCell(boss); const targetAt = copyCell(target);
    let damage = resistanceDamage(boss.attack, target.defense || 0);
    let reflected = 0;
    if (target === state.hero) ({ damage, reflected } = resolveReflectedHeroAttack(boss, damage, boss.name));
    else target.hp -= damage;
    actions.push({ type: 'attack', enemyId: boss.id, damage, reflected, from, targetAt, target: target === state.hero ? 'hero' : 'scarecrow' });
    state.bossIntent = { id: 'basic', name: '深渊重击', desc: `${damage} 伤害` };
  }

  function placeBossTentacles(boss, count) {
    const weighted = [];
    allCells(BOARD_RADIUS).filter(cell => isFree(cell.q, cell.r)
      && hexDistance(cell, state.hero) >= 1 && hexDistance(cell, state.hero) <= 3
      && hexDistance(cell, boss) > 0).forEach(cell => {
      const distance = hexDistance(cell, state.hero);
      for (let weight = distance === 1 ? 3 : distance === 2 ? 2 : 1; weight > 0; weight -= 1) weighted.push(cell);
    });
    const placed = []; const used = new Set();
    for (const cell of shuffle(weighted, rng)) {
      const key = cellKey(cell.q, cell.r);
      if (used.has(key)) continue;
      used.add(key);
      const obstacle = placeObstacle('tentacle', cell.q, cell.r, boss.enraged ? 4 : 3);
      if (obstacle) placed.push(obstacle);
      if (placed.length >= count) break;
    }
    return placed;
  }

  function bossAct(boss, actions) {
    boss.clawCooldown = Math.max(0, boss.clawCooldown - 1);
    boss.tentacleCooldown = Math.max(0, boss.tentacleCooldown - 1);
    boss.whirlpoolCooldown = Math.max(0, boss.whirlpoolCooldown - 1);
    const distance = hexDistance(boss, state.hero);
    processBossAura();

    if (boss.skillCooldown > 0) {
      boss.skillCooldown -= 1;
      const target = state.scarecrow?.hp > 0 ? state.scarecrow : state.hero;
      if (hexDistance(boss, target) <= boss.range) resolveBossBasicAttack(boss, actions);
      else {
        const destination = chooseStep(boss, target);
        if (destination) { const from = copyCell(boss); Object.assign(boss, destination); actions.push({ type: 'move', enemyId: boss.id, from, to: copyCell(boss) }); }
        else actions.push({ type: 'idle', enemyId: boss.id });
        state.bossIntent = { id: 'move', name: '逼近', desc: '海妖正在靠近' };
      }
      return;
    }

    if (boss.clawCooldown <= 0 && distance <= 2) {
      const damage = Math.floor(boss.attack * (boss.enraged ? 2.8 : 2.2));
      const result = resolveReflectedHeroAttack(boss, damage, '深渊巨爪', { raw: true });
      boss.clawCooldown = boss.enraged ? 3 : 4; boss.skillCooldown = 1;
      state.bossIntent = { id: 'claw', name: '深渊巨爪', desc: `${damage} 伤害` };
      actions.push({ type: 'boss_claw', enemyId: boss.id, damage: result.damage, reflected: result.reflected, from: copyCell(boss), targetAt: copyCell(state.hero), target: 'hero' });
      emit('boss_claw', { from: copyCell(boss), to: copyCell(state.hero), duration: 0.9 });
      if (!state.bossCasting) announce('深渊巨爪', '海妖挥下致命重击', '#ff729b', 0.9);
      state.bossCasting = null; return;
    }
    if (boss.tentacleCooldown <= 0) {
      const tentacles = placeBossTentacles(boss, boss.enraged ? 5 : 4);
      const damage = Math.floor(boss.attack * (boss.enraged ? 0.5 : 0.4));
      const result = resolveReflectedHeroAttack(boss, damage, '触手丛生', { raw: true });
      boss.tentacleCooldown = boss.enraged ? 3 : 5; boss.skillCooldown = 1;
      state.bossIntent = { id: 'tentacle', name: '触手丛生', desc: `${tentacles.length} 条触手封锁棋盘` };
      actions.push({ type: 'boss_tentacle', enemyId: boss.id, damage: result.damage, reflected: result.reflected, tentacles: tentacles.map(copyCell), targetAt: copyCell(state.hero) });
      if (!state.bossCasting) announce('触手丛生', '触手可作为跳板，但跳过会受伤', '#c88cff', 1.05);
      state.bossCasting = null; return;
    }
    if (boss.whirlpoolCooldown <= 0 && distance > 1) {
      const destination = HEX_DIRECTIONS.map(([dq, dr]) => ({ q: state.hero.q + dq, r: state.hero.r + dr }))
        .filter(cell => isFree(cell.q, cell.r))
        .sort((a, b) => hexDistance(a, boss) - hexDistance(b, boss))[0];
      const from = copyCell(state.hero);
      if (destination) Object.assign(state.hero, destination);
      const damage = boss.enraged ? 10 : 5;
      const result = resolveReflectedHeroAttack(boss, damage, '深渊漩涡', { raw: true });
      boss.whirlpoolCooldown = boss.enraged ? 4 : 7; boss.skillCooldown = 1;
      state.bossIntent = { id: 'whirlpool', name: '深渊漩涡', desc: `拉近并造成 ${damage} 伤害` };
      actions.push({ type: 'boss_whirlpool', enemyId: boss.id, damage: result.damage, reflected: result.reflected, from, to: copyCell(state.hero), targetAt: copyCell(state.hero) });
      emit('boss_whirlpool', { from: copyCell(boss), to: copyCell(state.hero), duration: 1 });
      if (!state.bossCasting) announce('深渊漩涡', '企鹅被拖向海妖', '#6fb7ff', 1);
      state.bossCasting = null; return;
    }
    const target = state.scarecrow?.hp > 0 ? state.scarecrow : state.hero;
    if (hexDistance(boss, target) <= boss.range) resolveBossBasicAttack(boss, actions);
    else {
      const destination = chooseStep(boss, target);
      if (destination) { const from = copyCell(boss); Object.assign(boss, destination); actions.push({ type: 'move', enemyId: boss.id, from, to: copyCell(boss) }); }
      else actions.push({ type: 'idle', enemyId: boss.id });
    }
    state.bossCasting = null;
  }

  function prepareEnemyTurn() {
    const boss = state.boss;
    if (state.phase !== 'ENEMY_TURN' || !state.isBossStage || !boss || boss.hp <= 0) return null;
    if (boss.skillCooldown > 0) return null;
    const distance = hexDistance(boss, state.hero);
    let intent = null;
    if (boss.clawCooldown <= 1 && distance <= 2) {
      intent = { id: 'claw', name: '深渊巨爪', desc: '巨大触手即将横扫' };
    } else if (boss.tentacleCooldown <= 1) {
      intent = { id: 'tentacle', name: '触手丛生', desc: '触手即将在企鹅周围涌出' };
    } else if (boss.whirlpoolCooldown <= 1 && distance > 1) {
      intent = { id: 'whirlpool', name: '深渊漩涡', desc: '漩涡即将把企鹅拉向海妖' };
    }
    if (!intent) return null;
    state.bossCasting = intent; state.bossIntent = intent;
    const colors = { claw: '#ff729b', tentacle: '#c88cff', whirlpool: '#6fb7ff' };
    announce(intent.name, intent.desc, colors[intent.id], 3);
    state.message = `${intent.name} · 技能蓄力中`;
    return intent;
  }

  function resolveEnemyAttack(enemy, target, actions) {
    const from = copyCell(enemy); const targetAt = copyCell(target);
    let damage = resistanceDamage(enemy.attack, target.defense || 0);
    let reflected = 0;
    if (target === state.hero) {
      const reflectedResult = resolveReflectedHeroAttack(enemy, damage, enemy.name);
      damage = reflectedResult.damage;
      reflected = reflectedResult.reflected;
      const thorns = skillLevel('thorns');
      if (thorns) {
        const bloodThorns = hasCombo('vampiric_jump', 'thorns');
        const reflected = Math.floor(enemy.attack * (20 + thorns * 8) / 100);
        damageEnemy(enemy, reflected, 'thorns', [], { ignoreDefense: true, skipModifiers: true });
        let healRate = thorns >= 3 || bloodThorns ? 0.5 : 0;
        if (bloodThorns && state.hero.hp < state.hero.maxHp * 0.5) healRate += 0.2;
        if (healRate > 0) state.hero.hp = Math.min(state.hero.maxHp, state.hero.hp + Math.floor(reflected * healRate));
        emit('thorns', { from: copyCell(state.hero), to: copyCell(enemy), duration: 0.55 });
      }
    } else target.hp -= damage;
    if (enemy.aoeDamage) {
      const splashDamage = Math.floor(damage / 2);
      if (target === state.hero && splashDamage > 0 && state.scarecrow?.hp > 0
        && hexDistance(state.scarecrow, state.hero) <= 1) {
        state.scarecrow.hp -= splashDamage;
        state.scarecrow.totalDamageAbsorbed = (state.scarecrow.totalDamageAbsorbed || 0) + splashDamage;
        state.scarecrow.hitCount = (state.scarecrow.hitCount || 0) + 1;
      }
      emit('electric_discharge', {
        q: target.q, r: target.r, radius: 1, color: '#9deaff', duration: 0.5,
      });
    }
    actions.push({
      type: 'attack', enemyId: enemy.id, damage,
      reflected,
      from, targetAt, target: target === state.hero ? 'hero' : 'scarecrow',
    });
  }

  function enemyTurn() {
    const actions = [];
    if (state.timeStopTurns > 0) {
      const turnsLeft = --state.timeStopTurns;
      livingEnemies().forEach(enemy => actions.push({ type: 'time_stopped', enemyId: enemy.id }));
      emit('time_stop_turn', { turnsLeft, duration: 0.7 });
      return actions;
    }
    state.obstacles.forEach(obstacle => { if (obstacle.turnsLeft != null) obstacle.turnsLeft -= 1; });
    state.obstacles = state.obstacles.filter(obstacle => obstacle.turnsLeft == null || obstacle.turnsLeft > 0);
    livingEnemies().filter(enemy => enemy.type === 'hermit_crab').forEach(enemy => {
      if (enemy.shellCooldown > 0) {
        enemy.shellCooldown -= 1;
        if (enemy.shellCooldown <= 0) {
          enemy.hasShell = !enemy.hasShell;
          enemy.shellCooldown = 2;
          emit(enemy.hasShell ? 'shell_close' : 'shell_open', { q: enemy.q, r: enemy.r, duration: 0.55 });
        }
      } else enemy.shellCooldown = 2;
    });
    for (const trap of state.traps) {
      const enemy = livingEnemies().find(candidate => candidate.q === trap.q && candidate.r === trap.r);
      if (!enemy) continue;
      damageEnemy(enemy, trap.damage, 'spike_trap', [], { ignoreDefense: true, skipModifiers: true });
      emit('trap_hit', { q: enemy.q, r: enemy.r, duration: 0.6 });
      if (hasCombo('split_shot', 'spike_trap')) {
        const target = livingEnemies().filter(candidate => candidate.id !== enemy.id)
          .sort((a, b) => hexDistance(a, enemy) - hexDistance(b, enemy))[0];
        if (target) {
          emit('projectile', {
            from: copyCell(enemy), to: copyCell(target), color: '#c7a3ff',
            projectileType: 'enemy_orb', duration: 0.42,
          });
          damageEnemy(target, 10, 'minefield_shard', [], {
            ignoreDefense: true, skipModifiers: true, fromChain: true,
          });
        }
      }
    }
    for (const enemy of [...livingEnemies()]) {
      if (enemy.isBoss) { bossAct(enemy, actions); continue; }
      if (enemy.burnTurns > 0) {
        damageEnemy(enemy, enemy.burnDamage || 6, 'burn', [], { ignoreDefense: true, skipModifiers: true });
        enemy.burnTurns -= 1;
        if (enemy.hp <= 0) continue;
      }
      if (enemy.armorBrokenTurns > 0) enemy.armorBrokenTurns -= 1;
      if (enemy.stunnedTurns > 0 || enemy.frozenTurns > 0) {
        if (enemy.stunnedTurns > 0) enemy.stunnedTurns -= 1;
        if (enemy.frozenTurns > 0) enemy.frozenTurns -= 1;
        actions.push({ type: 'stunned', enemyId: enemy.id }); continue;
      }
      if (enemy.hasShell) { actions.push({ type: 'shelled', enemyId: enemy.id }); continue; }
      const target = state.scarecrow?.hp > 0 ? state.scarecrow : state.hero;
      const distance = hexDistance(enemy, target);
      const wasSilenced = enemy.silencedTurns > 0;
      if (wasSilenced) {
        enemy.silencedTurns -= 1;
        if (enemy.silencedTurns === 0 && skillLevel('silence_path') >= 5) {
          damageEnemy(enemy, 20, 'silence_burst', [], { ignoreDefense: true, skipModifiers: true });
        }
        if (enemy.hp <= 0) continue;
        if (distance <= (enemy.range || 1)) { actions.push({ type: 'silenced', enemyId: enemy.id }); continue; }
      }
      if (!wasSilenced && enemy.type === 'ghost_shark') {
        if (enemy.teleportCooldownRemaining > 0) {
          enemy.teleportCooldownRemaining -= 1;
          const destination = chooseStep(enemy, target);
          if (destination) {
            const from = copyCell(enemy); Object.assign(enemy, destination);
            actions.push({ type: 'move', enemyId: enemy.id, from, to: copyCell(enemy) });
          } else actions.push({ type: 'idle', enemyId: enemy.id });
          continue;
        }
        const destination = shuffle(HEX_DIRECTIONS, rng).map(([dq, dr]) => ({ q: target.q + dq, r: target.r + dr })).find(cell => isFree(cell.q, cell.r, enemy.id));
        if (destination) { const from = copyCell(enemy); Object.assign(enemy, destination); actions.push({ type: 'teleport', enemyId: enemy.id, from, to: copyCell(enemy) }); emit('teleport', { from, to: copyCell(enemy), duration: 0.65 }); }
        if (hexDistance(enemy, target) <= 1) resolveEnemyAttack(enemy, target, actions);
        enemy.teleportCooldownRemaining = enemy.teleportCooldown || 1;
        continue;
      }
      if (!wasSilenced && enemy.fleesWhenClose && distance <= 1) {
        const destination = chooseStep(enemy, target, true);
        if (destination) { const from = copyCell(enemy); Object.assign(enemy, destination); actions.push({ type: 'move', enemyId: enemy.id, from, to: copyCell(enemy) }); continue; }
      }
      if (distance <= (enemy.range || 1)) resolveEnemyAttack(enemy, target, actions);
      else {
        const destination = chooseStep(enemy, target);
        if (destination) {
          const from = copyCell(enemy); Object.assign(enemy, destination);
          actions.push({ type: 'move', enemyId: enemy.id, from, to: copyCell(enemy) });
        } else actions.push({ type: 'idle', enemyId: enemy.id });
      }
    }
    const comboShield = skillLevel('combo_shield');
    if (comboShield >= 3 && state.hero.shield > 0) {
      const reflected = Math.floor(state.hero.shield * 0.3);
      if (reflected > 0) {
        livingEnemies().filter(enemy => hexDistance(enemy, state.hero) === 1).forEach(enemy => {
          damageEnemy(enemy, reflected, 'combo_shield_reflect', [], {
            ignoreDefense: true, skipModifiers: true, fromChain: true,
          });
        });
        emit('shield_reflect', { q: state.hero.q, r: state.hero.r, damage: reflected, duration: 0.6 });
      }
    }
    if (state.scarecrow?.hp <= 0) state.scarecrow = null;
    state.traps.forEach(trap => { trap.turnsLeft -= 1; }); state.traps = state.traps.filter(trap => trap.turnsLeft > 0);
    state.enemies = livingEnemies(); return actions;
  }

  function ensureHeroMobility() {
    const actions = [];
    const freeCount = () => adjacentMoves(state.hero, blockingUnits(), state.obstacles).length;
    if (freeCount() >= 2) return actions;
    for (const enemy of livingEnemies().filter(enemy => hexDistance(enemy, state.hero) === 1).sort((a, b) => a.hp - b.hp)) {
      if (freeCount() >= 2) break;
      const destination = shuffle(HEX_DIRECTIONS, rng).map(([dq, dr]) => ({ q: enemy.q + dq, r: enemy.r + dr })).find(cell => isFree(cell.q, cell.r, enemy.id));
      if (destination) { const from = copyCell(enemy); Object.assign(enemy, destination); actions.push({ type: 'push', enemyId: enemy.id, from, to: copyCell(enemy) }); }
      else enemy.hp = 0;
    }
    state.enemies = livingEnemies(); return actions;
  }

  function beginEnemyTurn(summary) {
    state.lastAction = summary; state.phase = 'ENEMY_TURN'; state.plan.length = 0; state.threatPreview.length = 0; state.message = '敌人回合…';
    return summary;
  }

  function showResult(result) {
    state.pendingResult = null; state.result = result; state.phase = result === 'win' ? 'WIN' : 'LOSE';
    if (result === 'win') {
      const eligible = SKILLS.filter(def => (state.skills[def.id] || 0) < def.maxLevel);
      state.skillChoices = shuffle(eligible, rng).slice(0, 3).map(def => skillChoiceView(def.id, state.skills[def.id] || 0));
      state.message = state.stage >= 10 ? '深渊海妖已被击败，选择最后一项技能' : '关卡完成，选择一个技能';
      announce('关卡完成', `1-${state.stage} ${state.stageName}`, '#79f1cf', 1.25);
    } else state.message = '闯关失败';
    return result;
  }

  function finishJumpExecution() {
    const execution = state.pendingExecution;
    if (!execution || state.phase !== 'PLAYER_EXECUTE' || execution.index < execution.path.length) return { kind: 'invalid' };
    const summary = { kind: 'jump', from: execution.from, to: copyCell(state.hero), path: execution.path.map(step => ({ ...step })), hits: execution.hits, combo: state.combo };
    state.pendingExecution = null; state.plan.length = 0; state.threatPreview.length = 0; state.lastAction = summary;
    if (state.setEffects.combo_mastery >= 4 && state.combo > 0) {
      const triggered = state.setEffects.combo_mastery >= 6 || rng() < 0.5;
      if (triggered) {
        state.combo += 1;
        state.maxCombo = Math.max(state.maxCombo, state.combo);
        summary.combo = state.combo;
        announce('连击心得', 'Combo +1', '#ff943d', 0.8);
      }
    }
    const reward = executeComboReward(summary.hits); state.enemies = livingEnemies();
    const won = state.isBossStage ? Boolean(state.boss && state.boss.hp <= 0) : state.kills >= state.killTarget;
    state.pendingResult = won ? 'win' : null;
    if (reward || won) { state.phase = 'COMBO_REWARD_WAIT'; state.message = reward ? `${state.combo} 连击奖励 · ${reward.name}` : '目标达成！'; }
    else beginEnemyTurn(summary);
    return { ...summary, reward, resultPending: state.pendingResult };
  }

  function completeComboRewardWait() {
    if (state.phase !== 'COMBO_REWARD_WAIT') return { kind: 'invalid' };
    if (state.pendingResult) { const result = state.pendingResult; showResult(result); return { kind: 'result', result }; }
    beginEnemyTurn(state.lastAction); return { kind: 'enemy_turn_pending' };
  }

  function processEnemyTurn() {
    if (state.result || state.phase !== 'ENEMY_TURN') return { kind: 'invalid', actions: [] };
    const actions = enemyTurn(); state.lastReward = null; state.turn += 1;
    if (state.absoluteReflectTurns > 0) {
      state.absoluteReflectTurns -= 1;
      emit('absolute_reflect_turn', { turnsLeft: state.absoluteReflectTurns, duration: 0.7 });
    }
    state.combo = 0; state.comboAtkBonus = 0;
    const won = state.isBossStage ? Boolean(state.boss && state.boss.hp <= 0) : state.kills >= state.killTarget;
    if (won) { if (state.hero.hp <= 0) state.hero.hp = 1; showResult('win'); return { kind: 'enemy_turn', actions, result: 'win' }; }
    if (state.hero.hp <= 0) { showResult('lose'); return { kind: 'enemy_turn', actions, result: 'lose' }; }
    const tutorialAdvanced = state.tutorialPhase < 4;
    if (tutorialAdvanced) tryScriptedSpawn(); else tryRegularSpawn();
    if (state.hero.hp > 0 && state.hero.hp < state.hero.maxHp * 0.3
      && !state.items.some(item => item.type === 'health_potion' || item.type === 'health_potion_big')) {
      const occupied = occupiedByEnemy(livingEnemies());
      const candidates = shuffle(allCells(BOARD_RADIUS).filter(cell => !isHeroAt(cell.q, cell.r)
        && !occupied.has(cellKey(cell.q, cell.r)) && !state.items.some(item => item.q === cell.q && item.r === cell.r)), rng);
      if (candidates[0]) state.items.push({ id: `item-${nextItemId++}`, type: 'health_potion', ...candidates[0] });
    }
    actions.push(...ensureHeroMobility()); refreshHunterMarks(); state.phase = 'ENEMY_RESOLVE';
    if (!tutorialAdvanced) {
      const attacks = actions.filter(action => action.type === 'attack').length;
      const moves = actions.filter(action => ['move', 'teleport'].includes(action.type)).length;
      state.message = attacks || moves ? `敌人：${attacks ? `${attacks} 次攻击` : ''}${attacks && moves ? '，' : ''}${moves ? `${moves} 次移动` : ''} — 你的回合` : '你的回合';
    }
    return { kind: 'enemy_turn', actions, result: null };
  }

  function startPlayerTurn() {
    if (state.result || state.phase !== 'ENEMY_RESOLVE') return false;
    state.phase = 'PLAYER_SELECT'; state.combo = 0;
    if (state.hero.silencedTurns > 0) state.hero.silencedTurns -= 1;
    if (state.doomDamageTakenTurns > 0) state.doomDamageTakenTurns -= 1;
    if (state.doomOutputDownTurns > 0) state.doomOutputDownTurns -= 1;
    if (state.luckyAtkUpTurns > 0) state.luckyAtkUpTurns -= 1;
    if (state.doomPoisonTurns > 0) {
      const damage = Math.max(1, Math.floor(state.hero.maxHp * 0.05));
      state.hero.hp = Math.max(1, state.hero.hp - damage);
      state.doomPoisonTurns -= 1;
      emit('hero_hit', { q: state.hero.q, r: state.hero.r, damage, label: '暗毒', duration: 0.55 });
    }
    computeThreats(state.hero); return true;
  }

  function applyStepStrike(hits) {
    const lv = skillLevel('step_strike');
    if (!lv) return;
    const target = livingEnemies().find(enemy => hexDistance(enemy, state.hero) <= 1);
    if (!target) return;
    const execute = !target.isBoss && target.hp / target.maxHp <= Math.min(100, 30 + lv * 14) / 100;
    emit('slash', { from: copyCell(state.hero), to: copyCell(target), duration: 0.5 });
    damageEnemy(target, execute ? target.hp : 5 + lv * 5, 'step_strike', hits, { ignoreDefense: true, skipModifiers: true });
  }

  function commitMove(action) {
    const from = copyCell(state.hero); state.hero.q = action.q; state.hero.r = action.r; state.combo = 0; state.lastReward = null;
    const item = pickupItemAt(action.q, action.r); const hits = []; applyStepStrike(hits); processBossAura();
    state.message = item ? '拾取了战场道具' : hits.length ? '踏步斩！' : '移动完成';
    return beginEnemyTurn({ kind: 'move', from, to: copyCell(state.hero), item, hits });
  }

  function confirm() {
    if (!state.plan.length || state.result) return { kind: 'invalid' };
    state.phase = 'PLAYER_EXECUTE';
    const from = copyCell(state.hero); const path = state.plan.map(step => ({ ...step }));
    state.combo = 0; state.lastReward = null; state.pendingResult = null;
    state.pendingExecution = { from, path, index: 0, hits: [] }; state.message = '执行跳跃…';
    return { kind: 'jump_start', from, path };
  }

  function executeNextJump() {
    const execution = state.pendingExecution;
    if (!execution || state.phase !== 'PLAYER_EXECUTE') return { kind: 'invalid' };
    if (execution.index >= execution.path.length) return { kind: 'complete' };
    const step = execution.path[execution.index]; const from = copyCell(state.hero);
    if (blockingUnits().some(unit => unit.hp > 0 && unit.q === step.q && unit.r === step.r)
      || state.obstacles.some(obstacle => obstacle.q === step.q && obstacle.r === step.r)) {
      execution.index = execution.path.length; return { kind: 'jump_blocked', from, to: from, done: true };
    }
    state.combo += 1; state.maxCombo = Math.max(state.maxCombo, state.combo);
    const kingmaker = skillLevel('kingmaker');
    if (kingmaker && state.combo === 1) {
      state._kingmakerCount += 1;
      const interval = kingmaker <= 3 ? 8 - kingmaker : 4;
      if (state._kingmakerCount >= interval) {
        state._kingmakerCount = 0; state._kingmakerReady = true;
        announce('棋步就绪', '下一跳可选择全图敌人', '#f1d56a');
      }
    }
    let hit = null; let enemy = null; let dealtJumpDamage = 0;
    if (!step.isSupport) {
      enemy = state.enemies.find(candidate => candidate.id === step.enemyId && candidate.hp > 0 && candidate.q === step.jumpedAt?.q && candidate.r === step.jumpedAt?.r);
      if (enemy) {
        applySilencePath(step, enemy);
        const before = execution.hits.length;
        let jumpDamage = jumpDamageFor(state.combo, step);
        const isCrit = state.critRate > 0 && rng() * 100 < state.critRate;
        if (isCrit) {
          jumpDamage = Math.floor(jumpDamage * 1.5);
          emit('crit', { q: enemy.q, r: enemy.r, damage: jumpDamage, duration: 0.65 });
        }
        dealtJumpDamage = jumpDamage;
        damageEnemy(enemy, jumpDamage, 'jump', execution.hits, {
          ignoreDefense: step.isKingmaker && skillLevel('kingmaker') >= 5,
          // 暴击事件已经负责显示合并后的“暴击 + 伤害”浮字；保留 damage
          // 事件用于受击动作和命中特效，但不能再生成第二张数字。
          suppressNumber: isCrit,
        });
        hit = execution.hits[before] || null; applyFrostMark(enemy);
        const vamp = skillLevel('vampiric_jump');
        if (vamp && hit) state.hero.hp = Math.min(state.hero.maxHp, state.hero.hp + Math.floor(hit.damage * (5 + vamp * 3) / 100));
      }
      if (step.isMultiEnemyJump && step.enemyIds?.length > 1) {
        step.enemyIds.slice(1).forEach(id => {
          const extra = state.enemies.find(candidate => candidate.id === id && candidate.hp > 0);
          if (!extra) return;
          damageEnemy(extra, dealtJumpDamage, 'leap_pioneer', execution.hits, { ignoreDefense: step.isKingmaker && skillLevel('kingmaker') >= 5 });
          applyFrostMark(extra);
        });
        announce('飞跃先锋', `一次跨越 ${step.enemyIds.length} 名敌人`, '#6ce1b6', 0.85);
        emit('leap_pioneer', { targets: step.jumpedTargets, duration: 0.85 });
      }
    } else if (step.isObstacle) {
      const obstacle = state.obstacles.find(candidate => candidate.id === step.supportId);
      if (obstacle?.type === 'tentacle') {
        const damage = Math.max(10, Math.floor((state.boss?.attack || 14) * 0.5));
        applyHeroDamage(damage, '穿越触手');
        emit('tentacle_hit', { q: obstacle.q, r: obstacle.r, damage, duration: 0.65 });
      }
    }
    const isLastStep = execution.index === execution.path.length - 1;
    state.hero.q = step.q; state.hero.r = step.r; applyLandingSkills(from, step, enemy, execution.hits, isLastStep);
    const shuffled = applyPendingShuffles();
    processBossAura();
    if (step.isKingmaker) state._kingmakerReady = false;
    const item = pickupItemAt(step.q, step.r); execution.index += 1;
    const done = execution.index >= execution.path.length;
    state.message = done && execution.path.length > 1 ? `${execution.path.length} 连跳！` : `第 ${execution.index} 跳 · ${hit ? `${hit.damage} 伤害` : '完成'}`;
    return {
      kind: 'jump_step', from, to: copyCell(step), resolvedTo: copyCell(state.hero), step: { ...step },
      index: execution.index, total: execution.path.length, combo: state.combo, hit, item, shuffled, done,
    };
  }

  function selectSkill(idOrIndex) {
    if (state.result !== 'win') return { kind: 'invalid' };
    const choice = typeof idOrIndex === 'number' ? state.skillChoices[idOrIndex] : state.skillChoices.find(entry => entry.id === idOrIndex);
    if (!choice) return { kind: 'invalid' };
    const definition = SKILL_BY_ID[choice.id];
    const level = Math.min(definition.maxLevel, (state.skills[choice.id] || 0) + 1);
    state.skills[choice.id] = level; applyPermanentSkillStats(); state.skillProc = { id: choice.id, name: choice.name, level };
    announce(`${choice.name} Lv.${level}`, definition.describe(level), choice.color, 1.3);
    return { kind: 'skill', id: choice.id, level, chapterComplete: state.stage >= 10 };
  }

  function continueToNextStage() {
    if (state.result !== 'win' || !state.skillProc) return { kind: 'invalid' };
    if (state.stage >= 10) {
      state.chapterComplete = true; state.result = 'chapter_complete'; state.phase = 'CHAPTER_COMPLETE';
      state.message = '第一章完成！深渊海妖已被击败';
      announce('第一章完成', '深渊海沟 · 1-1 至 1-10', '#ffe58b', 2);
      return { kind: 'chapter_complete' };
    }
    state.skillProc = null; configureStage(state.stage + 1, true);
    return { kind: 'next_stage', stage: state.stage };
  }

  function dismissTutorial() {
    if (!state.tutorialOverlay) return { kind: 'invalid' };
    const id = state.tutorialOverlay.id;
    state.tutorialFlags[`${id}TutorialSeen`] = true;
    state.tutorialOverlay = state.tutorialQueue.shift() || null;
    return { kind: 'tutorial', id };
  }

  function dismissEnemyIntro() {
    if (!state.enemyIntro.length) return { kind: 'invalid', enemyTypes: [] };
    const enemyTypes = state.enemyIntro.map(entry => entry.enemyType);
    state.enemyIntro.length = 0;
    return { kind: 'enemy_intro', enemyTypes };
  }

  function consumePresentationEvents() {
    return state.presentationQueue.splice(0, state.presentationQueue.length);
  }

  applyPermanentSkillStats();
  const data = stageData(initialStage);
  if (initialStage === 10) configureStage(10, false);
  else {
    Object.assign(state, { stageName: data.name, stageSubtitle: data.subtitle, killTarget: data.killTarget });
    state.message = state.tutorialPhase < 4 ? '先移动一步，熟悉六角棋盘' : '选择绿色移动格或橙色跳跃落点';
    if (state.tutorialPhase >= 4) {
      spawnAtRandomCells(data.initial, data.pool);
      detectNewEnemyTypes();
    }
    spawnItem(); refreshHunterMarks(); computeThreats(state.hero);
    if (state.tutorialPhase < 4) {
      const firstMove = adjacentMoves(state.hero, blockingUnits(), state.obstacles)[0];
      if (firstMove) state.tutorialOverlay = actionTutorial({
        id: 'board', stepLabel: '1 / 5', title: '移动企鹅',
        desc: '点击相邻空格移动。你完成一次行动后，敌人才会开始它们的回合。',
        hint: '点击绿色落点', accent: '#79f1cf', action: firstMove,
        focusCells: [state.hero, firstMove],
      });
    }
  }
  state.presentationQueue.length = 0;

  return {
    state, availableActions, plannedCell, computeThreats, select, undo, confirm,
    executeNextJump, finishJumpExecution, completeComboRewardWait, prepareEnemyTurn, processEnemyTurn,
    startPlayerTurn, selectSkill, continueToNextStage, consumePresentationEvents,
    dismissWheel, selectWheelSkill,
    dismissTutorial, dismissEnemyIntro,
  };
}
