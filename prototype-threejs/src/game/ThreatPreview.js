export function threatLineStyle(link) {
  const immediateMelee = !link.pending && (link.distance == null || link.distance <= 1);
  return {
    color: immediateMelee ? 0xff3048 : link.pending ? 0xffd23f : 0xff8b24,
    opacity: link.pending ? 0.82 : 0.88,
    radius: link.pending ? 0.032 : immediateMelee ? 0.044 : 0.036,
    outlineScale: 1.65,
    outlineOpacity: null,
    dashed: Boolean(link.pending || !immediateMelee),
    dashLength: 0.34,
    gapLength: 0.13,
    arrowAt: 0.67,
    arrowRadius: 0.12,
    arrowHeight: 0.27,
    arrowOutlineScale: 1.42,
  };
}

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
