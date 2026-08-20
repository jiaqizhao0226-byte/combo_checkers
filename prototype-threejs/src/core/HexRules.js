export const BOARD_RADIUS = 4;

export const HEX_DIRECTIONS = Object.freeze([
  Object.freeze([1, 0]),
  Object.freeze([1, -1]),
  Object.freeze([0, -1]),
  Object.freeze([-1, 0]),
  Object.freeze([-1, 1]),
  Object.freeze([0, 1]),
]);

export function cellKey(q, r) {
  return `${q},${r}`;
}

export function isInsideBoard(q, r, radius = BOARD_RADIUS) {
  return Math.max(Math.abs(q), Math.abs(r), Math.abs(q + r)) <= radius;
}

export function hexDistance(a, b) {
  const dq = a.q - b.q;
  const dr = a.r - b.r;
  return Math.max(Math.abs(dq), Math.abs(dr), Math.abs(dq + dr));
}

export function allCells(radius = BOARD_RADIUS) {
  const cells = [];
  for (let q = -radius; q <= radius; q += 1) {
    const rMin = Math.max(-radius, -q - radius);
    const rMax = Math.min(radius, -q + radius);
    for (let r = rMin; r <= rMax; r += 1) cells.push({ q, r });
  }
  return cells;
}

export function occupiedByEnemy(enemies) {
  const occupied = new Map();
  enemies.forEach(enemy => {
    if (enemy.hp > 0) occupied.set(cellKey(enemy.q, enemy.r), enemy);
  });
  return occupied;
}

export function adjacentMoves(from, enemies, blockers = []) {
  const occupied = occupiedByEnemy(enemies);
  blockers.forEach(blocker => occupied.set(cellKey(blocker.q, blocker.r), blocker));
  return HEX_DIRECTIONS
    .map(([dq, dr]) => ({ q: from.q + dq, r: from.r + dr, kind: 'move' }))
    .filter(cell => isInsideBoard(cell.q, cell.r) && !occupied.has(cellKey(cell.q, cell.r)));
}

// Combo Checkers keeps the original Lua rule: in each of the six straight
// directions, the first enemy can be jumped. If it is N cells away, the landing
// is another N cells beyond it and every cell between enemy and landing is empty.
export function jumpOptions(from, enemies, usedEnemyIds = new Set(), pathBlockers = new Set(), supports = [], maxJumpOver = 1) {
  const occupied = occupiedByEnemy(enemies);
  const supportMap = new Map(supports.map(support => [cellKey(support.q, support.r), support]));
  const options = [];

  for (const [dq, dr] of HEX_DIRECTIONS) {
    for (let distance = 1; distance <= BOARD_RADIUS * 2; distance += 1) {
      const q = from.q + dq * distance;
      const r = from.r + dr * distance;
      if (!isInsideBoard(q, r)) break;

      const enemy = occupied.get(cellKey(q, r));
      const support = supportMap.get(cellKey(q, r));
      const jumped = enemy || support;
      if (!jumped) {
        if (pathBlockers.has(cellKey(q, r))) break;
        continue;
      }
      if (usedEnemyIds.has(jumped.id)) break;

      if (enemy && maxJumpOver >= 2) {
        const consecutive = [enemy];
        for (let count = 2; count <= maxJumpOver; count += 1) {
          const next = occupied.get(cellKey(q + dq * (count - 1), r + dr * (count - 1)));
          if (!next || usedEnemyIds.has(next.id)) break;
          consecutive.push(next);
          const multiLanding = {
            q: q + dq * ((count - 1) + distance),
            r: r + dr * ((count - 1) + distance),
          };
          if (!isInsideBoard(multiLanding.q, multiLanding.r)) continue;
          let multiPathClear = !occupied.has(cellKey(multiLanding.q, multiLanding.r))
            && !supportMap.has(cellKey(multiLanding.q, multiLanding.r));
          for (let step = 1; multiPathClear && step < distance; step += 1) {
            const pathKey = cellKey(q + dq * ((count - 1) + step), r + dr * ((count - 1) + step));
            if (occupied.has(pathKey) || supportMap.has(pathKey) || pathBlockers.has(pathKey)) multiPathClear = false;
          }
          if (multiPathClear) {
            options.push({
              kind: 'jump', q: multiLanding.q, r: multiLanding.r,
              enemyId: enemy.id, enemyIds: consecutive.map(entry => entry.id),
              jumpedAt: { q: enemy.q, r: enemy.r },
              jumpedTargets: consecutive.map(entry => ({ id: entry.id, q: entry.q, r: entry.r })),
              distance, isMultiEnemyJump: true,
            });
          }
        }
      }

      const landing = {
        q: from.q + dq * distance * 2,
        r: from.r + dr * distance * 2,
      };
      if (!isInsideBoard(landing.q, landing.r)) break;

      let pathClear = true;
      for (let step = distance + 1; step <= distance * 2; step += 1) {
        const pathKey = cellKey(from.q + dq * step, from.r + dr * step);
        const itemBlocksPath = step < distance * 2 && pathBlockers.has(pathKey);
        if (occupied.has(pathKey) || supportMap.has(pathKey) || itemBlocksPath) {
          pathClear = false;
          break;
        }
      }

      if (pathClear) {
        options.push({
          kind: 'jump',
          q: landing.q,
          r: landing.r,
          enemyId: enemy?.id || null,
          supportId: support?.id || null,
          isObstacle: Boolean(support),
          jumpedAt: { q: jumped.q, r: jumped.r },
          distance,
        });
      }
      break;
    }
  }

  return options;
}
