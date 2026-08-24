import * as THREE from '../../vendor/three.module.js';
import { HexBlastEffect } from './combos/HexBlastEffect.js';
import { LifeDrainEffect } from './combos/LifeDrainEffect.js';
import { TimeStopEffect } from './combos/TimeStopEffect.js';
import { MeteorAoeEffect } from './combos/MeteorAoeEffect.js';
import { AbsoluteReflectShieldEffect } from './combos/AbsoluteReflectEffect.js';

const AXIAL_DIRECTIONS = [
  [1, 0], [1, -1], [0, -1], [-1, 0], [-1, 1], [0, 1],
];

function collectMaterials(model) {
  const materials = [];
  const seen = new Set();
  model.traverse(child => {
    if (!child.isMesh) return;
    const list = Array.isArray(child.material) ? child.material : [child.material];
    list.filter(Boolean).forEach(material => {
      if (seen.has(material)) return;
      seen.add(material);
      materials.push({
        material,
        opacity: material.opacity,
        transparent: material.transparent,
      });
    });
  });
  return materials;
}

function actorEntry(actor) {
  if (!actor) return null;
  actor.userData.comboHealthBarBaseScale ??= actor.userData.healthBar?.scale?.clone?.();
  actor.userData.comboActorBaseScale = actor.scale.clone();
  return {
    mount: actor,
    model: actor,
    materials: collectMaterials(actor),
    basePosition: actor.position.clone(),
    baseScale: actor.scale.clone(),
    baseRotationZ: actor.rotation.z,
    frozen: false,
    damageAt: null,
    hitAt: null,
  };
}

export class ComboRewardDirector {
  constructor(scene, camera, options) {
    this.scene = scene;
    this.camera = camera;
    this.board = options.board;
    this.hero = options.hero;
    this.getEnemyActor = options.getEnemyActor;
    this.createPreviewActor = options.createPreviewActor || (() => null);
    this.releasePreviewActor = options.releasePreviewActor || (() => {});
    this.holdActor = options.holdActor || (() => {});
    this.onActorsReleased = options.onActorsReleased || (() => {});
    this.hexBlast = new HexBlastEffect(scene);
    this.lifeDrain = new LifeDrainEffect(scene);
    this.timeStop = new TimeStopEffect(scene, camera);
    this.meteor = new MeteorAoeEffect(scene, camera);
    this.reflect = new AbsoluteReflectShieldEffect(scene);
    this.elapsed = 0;
    this.hexEndsAt = 0;
    this.timeStopEndsAt = 0;
    this.meteorEndsAt = 0;
    this.lifeDrainPreviewEndsAt = 0;
    this.reflectPreviewEndsAt = 0;
    this.previewActorsEndAt = 0;
    this.previewActors = [];
    this.previewMode = false;
  }

  buildTarget(target, origin, index = 0) {
    const actor = target.previewActor || this.getEnemyActor(target.enemyId);
    const entry = actorEntry(actor);
    if (!entry) return null;
    const incoming = actor.position.clone().sub(origin).setY(0);
    if (incoming.lengthSq() < 0.001) incoming.set(0, 0, 1);
    incoming.normalize();
    return {
      entry,
      kind: target.kind === 'boss' ? 'boss' : 'minion',
      hp: target.hp,
      damage: target.damage || 0,
      killed: Boolean(target.killed),
      incoming,
      fallDirection: index % 2 ? -1 : 1,
    };
  }

  buildPaths(originCell) {
    return AXIAL_DIRECTIONS.map(([dq, dr]) => {
      const cells = [];
      for (let distance = 1; distance <= 9; distance += 1) {
        const q = originCell.q + dq * distance;
        const r = originCell.r + dr * distance;
        const cell = this.board.get(q, r);
        if (!cell) break;
        cells.push({ q, r, position: cell.mesh.position.clone() });
      }
      const fallback = this.hero.position.clone().add(new THREE.Vector3(dq * 5, 0, dr * 5));
      const lastCell = cells[cells.length - 1];
      return { dq, dr, cells, end: lastCell ? lastCell.position.clone() : fallback };
    });
  }

  holdTargets(targets, seconds) {
    targets.forEach(target => this.holdActor(target.entry.mount, seconds));
  }

  play(presentation, state, options = {}) {
    const threshold = presentation?.threshold;
    const origin = this.hero.position.clone();
    origin.y = this.hero.userData.baseY ?? origin.y;
    const targets = (presentation?.targets || [])
      .map((target, index) => this.buildTarget(target, origin, index))
      .filter(Boolean);
    this.previewMode = Boolean(options.preview);

    if (threshold === 4 && targets.length) {
      this.holdTargets(targets, this.hexBlast.duration + 0.15);
      this.hexBlast.play({
        origin,
        paths: this.buildPaths(state.hero),
        targets,
      });
      this.hexEndsAt = this.elapsed + this.hexBlast.duration + 0.04;
    } else if (threshold === 5 && targets.length) {
      this.holdTargets(targets, this.lifeDrain.duration + 0.15);
      this.lifeDrain.play({ origin, targets, outcome: presentation.outcome });
      this.lifeDrainPreviewEndsAt = options.preview ? this.elapsed + 3.2 : 0;
    } else if (threshold === 6 && targets.length) {
      this.timeStop.play({ origin, targets });
      this.timeStopEndsAt = this.elapsed + this.timeStop.duration + 0.04;
    } else if (threshold === 7 && targets.length) {
      this.holdTargets(targets, this.meteor.duration + 0.15);
      this.meteor.play({ origin, targets });
      this.meteorEndsAt = this.elapsed + this.meteor.duration + 0.04;
    } else if (threshold === 8) {
      this.reflect.play({ hero: this.hero, turns: presentation.turns || 4 });
      this.reflectPreviewEndsAt = options.preview ? this.elapsed + 3.4 : 0;
    }
  }

  preview(threshold, state) {
    this.releasePreviewActors();
    const available = state.enemies.filter(enemy => enemy.hp > 0).slice(0, 6);
    let targets = available.map(enemy => ({
      enemyId: enemy.id,
      q: enemy.q,
      r: enemy.r,
      kind: enemy.isBoss ? 'boss' : 'minion',
      hp: enemy.hp,
      damage: threshold === 7 ? (enemy.isBoss ? 120 : 180) : threshold === 5 ? Math.max(5, Math.floor(enemy.hp * 0.2)) : 30,
      killed: false,
    }));
    if (!targets.length && threshold >= 4 && threshold <= 7) {
      const fallbackCells = [
        { q: state.hero.q + 2, r: state.hero.r - 1 },
        { q: state.hero.q - 2, r: state.hero.r + 1 },
        { q: state.hero.q + 1, r: state.hero.r + 2 },
        { q: state.hero.q - 1, r: state.hero.r - 2 },
      ].filter(cell => Boolean(this.board.get(cell.q, cell.r)));
      targets = fallbackCells.map((cell, index) => {
        const boardCell = this.board.get(cell.q, cell.r);
        const actor = this.createPreviewActor(boardCell.mesh.position.clone(), index);
        if (actor) this.previewActors.push(actor);
        return {
          enemyId: `vfx-preview-${index}`,
          previewActor: actor,
          q: cell.q,
          r: cell.r,
          kind: 'minion',
          hp: 60,
          damage: threshold === 7 ? 180 : threshold === 5 ? 12 : 30,
          killed: false,
        };
      }).filter(target => target.previewActor);
      const previewDurations = { 4: this.hexBlast.duration, 5: 3.2, 6: this.timeStop.duration, 7: this.meteor.duration };
      this.previewActorsEndAt = this.elapsed + (previewDurations[threshold] || 2) + 0.08;
    }
    const totalDrain = targets.reduce((sum, target) => sum + target.damage, 0);
    this.play({
      threshold,
      turns: threshold === 8 ? 4 : threshold === 6 ? 2 : 0,
      targets,
      outcome: {
        totalDrain,
        heroHpBefore: state.hero.hp,
        heal: Math.min(totalDrain, Math.max(0, state.hero.maxHp - state.hero.hp)),
        overflow: totalDrain,
        shieldBefore: 0,
        shieldAdded: Math.min(60, totalDrain),
        shieldTotal: Math.min(60, totalDrain),
        shieldFull: totalDrain >= 60,
      },
    }, state, { preview: true });
  }

  handleEvent(event) {
    if (event.type === 'absolute_reflect_turn') this.reflect.setTurns(event.turnsLeft);
    if (event.type === 'absolute_reflect_hit') {
      const actor = this.getEnemyActor(event.enemyId);
      if (actor) this.reflect.contact(actor.position.clone().add(new THREE.Vector3(0, 0.7, 0)));
    }
  }

  syncState(state) {
    if (this.lifeDrain.effect) {
      const shield = this.previewMode && this.lifeDrainPreviewEndsAt > this.elapsed
        ? this.lifeDrain.effect.shieldValue
        : state.drainShield;
      this.lifeDrain.setShield(shield);
      if (shield <= 0 && this.elapsed >= this.lifeDrainPreviewEndsAt) this.lifeDrain.clear();
    }
    if (this.reflect.effect && !this.previewMode) this.reflect.setTurns(state.absoluteReflectTurns);
  }

  update(delta, state) {
    this.elapsed += Math.max(0, delta);
    this.hexBlast.update(delta);
    this.lifeDrain.update(delta);
    this.timeStop.update(delta);
    this.meteor.update(delta);
    this.reflect.update(delta);
    this.syncState(state);

    let released = false;
    if (this.hexEndsAt && this.elapsed >= this.hexEndsAt) {
      this.hexBlast.clear();
      this.hexEndsAt = 0;
      released = true;
    }
    if (this.timeStopEndsAt && this.elapsed >= this.timeStopEndsAt) {
      this.timeStop.clear();
      this.timeStopEndsAt = 0;
    }
    if (this.meteorEndsAt && this.elapsed >= this.meteorEndsAt) {
      this.meteor.clear();
      this.meteorEndsAt = 0;
      released = true;
    }
    if (this.lifeDrainPreviewEndsAt && this.elapsed >= this.lifeDrainPreviewEndsAt) {
      this.lifeDrainPreviewEndsAt = 0;
      this.lifeDrain.clear();
      released = true;
    }
    if (this.reflectPreviewEndsAt && this.elapsed >= this.reflectPreviewEndsAt) {
      this.reflectPreviewEndsAt = 0;
      this.reflect.release();
    }
    if (this.previewActorsEndAt && this.elapsed >= this.previewActorsEndAt) this.releasePreviewActors();
    if (released) this.onActorsReleased();
  }

  stabilizeHealthBars() {
    const actors = new Set();
    [this.hexBlast.effect, this.lifeDrain.effect, this.timeStop.effect, this.meteor.effect]
      .filter(Boolean)
      .forEach(effect => {
        (effect.impacts || effect.streams || effect.stasisTargets || effect.targets || []).forEach(item => {
          const target = item.target || item;
          if (target?.entry?.mount) actors.add(target.entry.mount);
        });
      });
    actors.forEach(actor => {
      const bar = actor.userData.healthBar;
      const baseBar = actor.userData.comboHealthBarBaseScale;
      const baseActor = actor.userData.comboActorBaseScale;
      if (!bar || !baseBar || !baseActor) return;
      bar.scale.set(
        baseBar.x * baseActor.x / Math.max(0.001, actor.scale.x),
        baseBar.y * baseActor.y / Math.max(0.001, actor.scale.y),
        baseBar.z * baseActor.z / Math.max(0.001, actor.scale.z)
      );
    });
  }

  clear() {
    this.hexBlast.clear();
    this.lifeDrain.clear();
    this.timeStop.clear();
    this.meteor.clear();
    this.reflect.clear();
    this.hexEndsAt = 0;
    this.timeStopEndsAt = 0;
    this.meteorEndsAt = 0;
    this.lifeDrainPreviewEndsAt = 0;
    this.reflectPreviewEndsAt = 0;
    this.releasePreviewActors();
    this.previewMode = false;
  }

  releasePreviewActors() {
    this.previewActors.forEach(actor => this.releasePreviewActor(actor));
    this.previewActors.length = 0;
    this.previewActorsEndAt = 0;
  }
}
