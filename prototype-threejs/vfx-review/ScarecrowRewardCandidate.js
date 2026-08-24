import * as THREE from '../vendor/three.module.js';

const clamp01 = value => Math.max(0, Math.min(1, value));
const easeOutCubic = value => 1 - Math.pow(1 - clamp01(value), 3);

function damageSprite(value) {
  const canvas = document.createElement('canvas');
  canvas.width = 384;
  canvas.height = 192;
  const context = canvas.getContext('2d');
  context.clearRect(0, 0, canvas.width, canvas.height);
  context.textAlign = 'center';
  context.textBaseline = 'middle';
  context.shadowColor = 'rgba(62, 31, 9, .42)';
  context.shadowBlur = 8;
  context.shadowOffsetY = 4;
  const gradient = context.createLinearGradient(0, 38, 0, 145);
  gradient.addColorStop(0, '#fff0a0');
  gradient.addColorStop(0.5, '#ffc756');
  gradient.addColorStop(1, '#e7792d');
  context.fillStyle = gradient;
  context.font = '900 98px Inter, "PingFang SC", sans-serif';
  context.fillText(`-${Math.max(0, Math.round(value))}`, 192, 88);
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.minFilter = THREE.LinearFilter;
  texture.magFilter = THREE.LinearFilter;
  texture.generateMipmaps = false;
  const material = new THREE.SpriteMaterial({
    map: texture, transparent: true, opacity: 1,
    depthWrite: false, depthTest: false, toneMapped: false,
  });
  const sprite = new THREE.Sprite(material);
  sprite.name = 'ScarecrowDamageNumber';
  sprite.center.set(0.5, 0.3);
  sprite.renderOrder = 70;
  sprite.scale.set(0.001, 0.001, 1);
  return sprite;
}

function solidThreatLine(start, end) {
  const root = new THREE.Group();
  root.name = 'ScarecrowSolidTauntLine';
  const direction = end.clone().sub(start);
  const length = direction.length();
  const midpoint = start.clone().add(end).multiplyScalar(0.5);
  const quaternion = new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 1, 0), direction.clone().normalize());
  const outline = new THREE.Mesh(
    new THREE.CylinderGeometry(0.034, 0.034, length, 6),
    new THREE.MeshBasicMaterial({
      color: 0x19070a, transparent: true, opacity: 0.5,
      depthWrite: false, depthTest: false, toneMapped: false,
    })
  );
  outline.position.copy(midpoint);
  outline.quaternion.copy(quaternion);
  outline.renderOrder = 42;
  root.add(outline);
  const core = new THREE.Mesh(
    new THREE.CylinderGeometry(0.019, 0.019, length, 6),
    new THREE.MeshBasicMaterial({
      color: 0xff3f50, transparent: true, opacity: 0.9,
      depthWrite: false, depthTest: false, toneMapped: false,
    })
  );
  core.position.copy(midpoint);
  core.quaternion.copy(quaternion);
  core.renderOrder = 43;
  core.userData.baseOpacity = 0.9;
  root.add(core);
  const glow = new THREE.Mesh(
    new THREE.CylinderGeometry(0.052, 0.052, length, 8),
    new THREE.MeshBasicMaterial({
      color: 0xff3048, transparent: true, opacity: 0.16,
      depthWrite: false, depthTest: false,
      blending: THREE.AdditiveBlending, toneMapped: false,
    })
  );
  glow.name = 'ScarecrowSolidTauntGlow';
  glow.position.copy(midpoint);
  glow.quaternion.copy(quaternion);
  glow.renderOrder = 41;
  glow.userData.baseOpacity = 0.16;
  root.add(glow);
  const arrow = new THREE.Mesh(
    new THREE.ConeGeometry(0.09, 0.22, 7),
    new THREE.MeshBasicMaterial({
      color: 0xff5964, transparent: true, opacity: 0.96,
      depthWrite: false, depthTest: false, toneMapped: false,
    })
  );
  arrow.position.copy(end).addScaledVector(direction.clone().normalize(), -0.2);
  arrow.quaternion.copy(quaternion);
  arrow.renderOrder = 44;
  root.add(arrow);
  root.userData.glow = glow;
  return root;
}

function faceToward(mount, target) {
  const direction = target.clone().sub(mount.position).setY(0);
  if (direction.lengthSq() < 0.001) return;
  mount.rotation.y = Math.atan2(direction.x, direction.z);
}

function createFriendlyHealthBar() {
  const root = new THREE.Group();
  root.name = 'ScarecrowWorldLockedHealthBar';

  const back = new THREE.Mesh(
    new THREE.PlaneGeometry(1.08, 0.17),
    new THREE.MeshBasicMaterial({
      color: 0x092b2b, transparent: true, opacity: 0.92,
      depthWrite: false, depthTest: false, toneMapped: false,
      side: THREE.DoubleSide,
    })
  );
  back.name = 'ScarecrowFriendlyHealthBack';
  back.renderOrder = 88;
  root.add(back);

  const inner = new THREE.Mesh(
    new THREE.PlaneGeometry(0.98, 0.09),
    new THREE.MeshBasicMaterial({
      color: 0x17433d, transparent: true, opacity: 0.96,
      depthWrite: false, depthTest: false, toneMapped: false,
      side: THREE.DoubleSide,
    })
  );
  inner.position.z = 0.002;
  inner.renderOrder = 89;
  root.add(inner);

  const fillPivot = new THREE.Group();
  fillPivot.name = 'ScarecrowFriendlyHealthFillPivot';
  fillPivot.position.set(-0.49, 0, 0.004);
  const fill = new THREE.Mesh(
    new THREE.PlaneGeometry(0.98, 0.09),
    new THREE.MeshBasicMaterial({
      color: 0x62e49f, transparent: true, opacity: 1,
      depthWrite: false, depthTest: false, toneMapped: false,
      side: THREE.DoubleSide,
    })
  );
  fill.name = 'ScarecrowFriendlyHealthFill';
  fill.position.x = 0.49;
  fill.renderOrder = 90;
  fillPivot.add(fill);
  root.add(fillPivot);

  root.userData.back = back;
  root.userData.inner = inner;
  root.userData.fillPivot = fillPivot;
  root.userData.fill = fill;
  root.visible = false;
  return root;
}

export class ScarecrowRewardCandidate {
  constructor(scene, { camera, scarecrowMount, scarecrow, enemyEntries }) {
    this.scene = scene;
    this.camera = camera;
    this.scarecrowMount = scarecrowMount;
    this.scarecrow = scarecrow;
    this.enemyEntries = enemyEntries;
    this.root = new THREE.Group();
    this.root.name = 'ReviewOnly_ScarecrowRewardCandidateA';
    scene.add(this.root);
    this.effects = [];
    this.elapsed = 0;
    this.scenario = 'guard';
    this.hp = 100;
    this.maxHp = 100;
    this.started = false;
    this.finished = false;
    this.threatLines = new THREE.Group();
    this.threatLines.name = 'ScarecrowTauntTargets';
    this.root.add(this.threatLines);
    this.healthRoot = createFriendlyHealthBar();
    this.root.add(this.healthRoot);
  }

  scenarioEvents() {
    if (this.scenario === 'endure') {
      return [
        { enemy: 0, start: 1.22, damage: 18 },
        { enemy: 1, start: 1.92, damage: 15 },
        { enemy: 2, start: 3.02, damage: 20 },
      ];
    }
    if (this.scenario === 'break') {
      return [
        { enemy: 0, start: 1.22, damage: 54 },
        { enemy: 1, start: 1.92, damage: 60 },
      ];
    }
    return [
      { enemy: 0, start: 1.22, damage: 24 },
      { enemy: 1, start: 1.92, damage: 18 },
    ];
  }

  duration() {
    return this.scenario === 'endure' ? 4.65 : this.scenario === 'break' ? 3.25 : 3.35;
  }

  updateHealthBar() {
    const ratio = clamp01(this.hp / this.maxHp);
    this.healthRoot.userData.fillPivot.scale.x = Math.max(0.001, ratio);
    this.healthRoot.userData.fill.material.color.setHex(
      ratio <= 0.3 ? 0xffb857 : ratio <= 0.6 ? 0xa9df68 : 0x62e49f
    );
  }

  updateHealthBarTransform() {
    this.healthRoot.position.set(
      this.scarecrowMount.position.x,
      this.scarecrowMount.userData.baseY + 2.68,
      this.scarecrowMount.position.z
    );
    this.healthRoot.quaternion.copy(this.camera.quaternion);
  }

  reset(scenario = this.scenario) {
    this.scenario = scenario;
    this.events = this.scenarioEvents();
    this.elapsed = 0;
    this.hp = this.maxHp;
    this.started = false;
    this.finished = false;
    this.scarecrowMount.visible = false;
    this.scarecrowMount.position.y = this.scarecrowMount.userData.baseY;
    this.scarecrowMount.scale.setScalar(1);
    this.scarecrow.userData.healthBar.visible = false;
    this.healthRoot.visible = false;
    this.healthRoot.scale.setScalar(1);
    this.healthRoot.traverse(child => {
      if (!child.material) return;
      child.material.opacity = child.name === 'ScarecrowFriendlyHealthBack'
        ? 0.92
        : child.name === 'ScarecrowFriendlyHealthFill' ? 1 : 0.96;
    });
    this.updateHealthBar();
    this.updateHealthBarTransform();
    this.scarecrow.userData.animate?.(0);
    while (this.threatLines.children.length) this.threatLines.remove(this.threatLines.children[0]);
    this.threatLines.visible = false;
    while (this.effects.length) {
      const effect = this.effects.pop();
      this.root.remove(effect.root);
      effect.root.traverse(child => {
        child.geometry?.dispose?.();
        child.material?.map?.dispose?.();
        child.material?.dispose?.();
      });
    }
    this.enemyEntries.forEach(entry => {
      entry.mount.position.copy(entry.home);
      entry.mount.rotation.y = entry.homeRotation;
      entry.started = false;
    });
  }

  summon() {
    this.started = true;
    this.scarecrowMount.visible = true;
    this.healthRoot.visible = true;
    this.updateHealthBar();
    this.updateHealthBarTransform();
    this.scarecrow.userData.playAction?.('spawn', 0.7);
    const summonRoot = new THREE.Group();
    summonRoot.name = 'ScarecrowWardPlacement';
    summonRoot.position.copy(this.scarecrowMount.position);
    const hex = new THREE.Mesh(
      new THREE.CylinderGeometry(0.5, 0.54, 0.035, 6),
      new THREE.MeshBasicMaterial({ color: 0xf6bd55, transparent: true, opacity: 0.55, depthWrite: false, toneMapped: false })
    );
    hex.position.y = 0.04;
    summonRoot.add(hex);
    for (let index = 0; index < 10; index += 1) {
      const angle = index / 10 * Math.PI * 2;
      const straw = new THREE.Mesh(
        new THREE.BoxGeometry(0.025, 0.2 + (index % 3) * 0.04, 0.025),
        new THREE.MeshBasicMaterial({ color: index % 2 ? 0xffd56d : 0xd99c35, transparent: true, opacity: 0.9, toneMapped: false })
      );
      straw.position.set(Math.sin(angle) * 0.34, 0.08, Math.cos(angle) * 0.34);
      straw.userData.angle = angle;
      summonRoot.add(straw);
    }
    const light = new THREE.PointLight(0xffc768, 2.8, 3, 2);
    light.position.set(0, 0.65, 0);
    summonRoot.add(light);
    this.root.add(summonRoot);
    this.effects.push({ root: summonRoot, kind: 'summon', elapsed: 0, duration: 0.72 });
  }

  buildThreatLines() {
    const target = this.scarecrowMount.position.clone().add(new THREE.Vector3(0, 0.62, 0));
    this.enemyEntries.forEach(entry => {
      const start = entry.mount.position.clone().add(new THREE.Vector3(0, 0.58, 0));
      const direction = target.clone().sub(start).normalize();
      const line = solidThreatLine(
        start.addScaledVector(direction, 0.35),
        target.clone().addScaledVector(direction, -0.38)
      );
      this.threatLines.add(line);
    });
  }

  hit(damage) {
    if (this.finished) return;
    this.hp = Math.max(0, this.hp - damage);
    this.updateHealthBar();
    this.scarecrow.userData.playAction?.('hit', 0.44);
    const hitRoot = new THREE.Group();
    hitRoot.name = 'ScarecrowHitFeedback';
    hitRoot.position.copy(this.scarecrowMount.position).add(new THREE.Vector3(0, 0.78, 0));
    const number = damageSprite(damage);
    number.position.y = 0.7;
    hitRoot.add(number);
    for (let index = 0; index < 8; index += 1) {
      const angle = index / 8 * Math.PI * 2;
      const chip = new THREE.Mesh(
        new THREE.BoxGeometry(0.035, 0.16, 0.035),
        new THREE.MeshBasicMaterial({ color: index % 2 ? 0xf1c65b : 0x9a6639, transparent: true, opacity: 1, toneMapped: false })
      );
      chip.userData.direction = new THREE.Vector3(Math.sin(angle) * 0.45, 0.3 + (index % 3) * 0.12, Math.cos(angle) * 0.45);
      hitRoot.add(chip);
    }
    this.root.add(hitRoot);
    this.effects.push({ root: hitRoot, kind: 'hit', elapsed: 0, duration: 0.68, number });
    if (this.hp <= 0) this.finish('break');
  }

  finish(reason) {
    if (this.finished) return;
    this.finished = true;
    this.threatLines.visible = false;
    const finishRoot = new THREE.Group();
    finishRoot.name = reason === 'break' ? 'ScarecrowBreak' : 'ScarecrowExpire';
    finishRoot.position.copy(this.scarecrowMount.position).add(new THREE.Vector3(0, 0.52, 0));
    for (let index = 0; index < 14; index += 1) {
      const angle = index / 14 * Math.PI * 2;
      const straw = new THREE.Mesh(
        new THREE.BoxGeometry(0.028, 0.2 + (index % 4) * 0.035, 0.028),
        new THREE.MeshBasicMaterial({ color: index % 3 ? 0xe4b64e : 0x8e5e34, transparent: true, opacity: 1, toneMapped: false })
      );
      straw.userData.direction = new THREE.Vector3(
        Math.sin(angle) * (reason === 'break' ? 0.8 : 0.42),
        reason === 'break' ? 0.55 + (index % 3) * 0.16 : 0.24 + (index % 3) * 0.08,
        Math.cos(angle) * (reason === 'break' ? 0.8 : 0.42)
      );
      finishRoot.add(straw);
    }
    this.root.add(finishRoot);
    this.effects.push({ root: finishRoot, kind: reason, elapsed: 0, duration: reason === 'break' ? 0.82 : 1.05 });
  }

  update(delta) {
    this.elapsed += Math.max(0, delta);
    if (!this.started) this.summon();
    this.scarecrow.userData.animate?.(this.elapsed);
    if (!this.threatLines.children.length && this.elapsed >= 0.72) this.buildThreatLines();
    this.threatLines.visible = !this.finished && this.elapsed >= 0.72;
    this.threatLines.children.forEach((line, index) => {
      const core = line.children[1];
      const glow = line.userData.glow;
      const pulse = 0.88 + Math.sin(this.elapsed * 4.6 + index) * 0.12;
      core.material.opacity = core.userData.baseOpacity * pulse;
      if (glow) glow.material.opacity = glow.userData.baseOpacity * (0.82 + pulse * 0.38);
    });

    const target = this.scarecrowMount.position.clone();
    this.events.forEach(event => {
      const entry = this.enemyEntries[event.enemy];
      if (!entry) return;
      const local = this.elapsed - event.start;
      if (local >= 0 && !event._started) {
        event._started = true;
        faceToward(entry.mount, target);
        entry.model.userData.playAction?.('attack', 0.48);
      }
      if (local >= 0 && local <= 0.52) {
        const lunge = Math.sin(clamp01(local / 0.52) * Math.PI) * 0.24;
        entry.mount.position.copy(entry.home).lerp(target, lunge);
      } else if (local > 0.52) entry.mount.position.copy(entry.home);
      if (local >= 0.27 && !event._hit) {
        event._hit = true;
        this.hit(event.damage);
      }
    });

    if (this.scenario === 'guard' && this.elapsed >= this.duration()) this.finished = true;
    if (this.finished) {
      const finishStart = this.scenario === 'break' ? 2.2 : this.duration();
      const finishProgress = clamp01((this.elapsed - finishStart) / 0.8);
      if (this.scenario === 'break') {
        this.scarecrowMount.position.y = this.scarecrowMount.userData.baseY - finishProgress * 0.34;
        this.scarecrowMount.scale.setScalar(Math.max(0.05, 1 - easeOutCubic(finishProgress) * 0.88));
        this.healthRoot.scale.setScalar(Math.max(0.05, 1 - easeOutCubic(finishProgress) * 0.88));
        this.healthRoot.traverse(child => {
          if (child.material) child.material.opacity = Math.max(0, child.material.opacity * (1 - finishProgress));
        });
      }
    }

    // The bar is anchored to the board cell and billboards to the battle
    // camera, so the scarecrow can recoil without dragging the UI with it.
    this.updateHealthBarTransform();

    for (let index = this.effects.length - 1; index >= 0; index -= 1) {
      const effect = this.effects[index];
      effect.elapsed += delta;
      const progress = clamp01(effect.elapsed / effect.duration);
      if (effect.kind === 'summon') {
        effect.root.children.forEach((child, childIndex) => {
          if (!child.isMesh || childIndex === 0) return;
          child.position.y = 0.08 + easeOutCubic(progress) * (0.24 + (childIndex % 3) * 0.07);
          child.material.opacity = 1 - progress;
        });
        effect.root.children[0].scale.setScalar(0.35 + easeOutCubic(progress) * 1.3);
        effect.root.children[0].material.opacity = Math.max(0, 0.55 * (1 - progress));
      } else if (effect.kind === 'hit') {
        const pop = easeOutCubic(Math.min(1, progress * 4.2));
        effect.number.scale.set(1.34 * pop, 0.67 * pop, 1);
        effect.number.position.y = 0.7 + progress * 0.52;
        effect.number.material.opacity = progress < 0.68 ? 1 : (1 - progress) / 0.32;
        effect.root.children.slice(1).forEach(chip => {
          chip.position.copy(chip.userData.direction).multiplyScalar(easeOutCubic(progress));
          chip.position.y -= progress * progress * 0.16;
          chip.material.opacity = 1 - progress;
        });
      } else if (effect.kind === 'break' || effect.kind === 'expire') {
        effect.root.children.forEach(straw => {
          straw.position.copy(straw.userData.direction).multiplyScalar(easeOutCubic(progress));
          straw.position.y -= progress * progress * 0.38;
          straw.rotation.z += delta * 5;
          straw.material.opacity = 1 - progress;
        });
      }
      if (progress < 1) continue;
      this.root.remove(effect.root);
      effect.root.traverse(child => {
        child.geometry?.dispose?.();
        child.material?.map?.dispose?.();
        child.material?.dispose?.();
      });
      this.effects.splice(index, 1);
    }
  }
}
