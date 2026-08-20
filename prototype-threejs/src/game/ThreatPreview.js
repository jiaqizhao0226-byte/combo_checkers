export function buildThreatLinks(state) {
  const enemies = (state.enemies || []).filter(enemy => enemy.hp > 0 && enemy.attack > 0);

  if (state.scarecrow?.hp > 0) {
    return enemies.map(enemy => ({
      enemyId: enemy.id,
      from: { q: enemy.q, r: enemy.r },
      to: { q: state.scarecrow.q, r: state.scarecrow.r },
      target: 'scarecrow',
      pending: false,
      distance: null,
      damage: null,
    }));
  }

  if (!['PLAYER_SELECT', 'PLAYER_PLAN'].includes(state.phase)) return [];
  const target = state.plan?.length ? state.plan[state.plan.length - 1] : state.hero;
  return (state.threatPreview || []).flatMap(threat => {
    const enemy = enemies.find(entry => entry.id === threat.enemyId);
    if (!enemy) return [];
    return [{
      enemyId: enemy.id,
      from: { q: enemy.q, r: enemy.r },
      to: { q: target.q, r: target.r },
      target: 'hero',
      pending: Boolean(threat.pending),
      distance: threat.distance ?? null,
      damage: threat.damage ?? 0,
    }];
  });
}
