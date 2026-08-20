import * as THREE from '../../vendor/three.module.js';

const DEFAULT_SAFE_MARGIN = 0.72;

function damp(current, target, speed, delta) {
  if (delta <= 0 || speed <= 0) return current;
  return THREE.MathUtils.lerp(current, target, 1 - Math.exp(-speed * delta));
}

function smoothDampAxis(current, target, velocity, smoothTime, maxSpeed, delta) {
  if (delta <= 0) return { value: current, velocity };
  const duration = Math.max(0.0001, smoothTime);
  const omega = 2 / duration;
  const step = omega * delta;
  const decay = 1 / (1 + step + 0.48 * step * step + 0.235 * step * step * step);
  const originalTarget = target;
  let change = current - target;
  const maxChange = Math.max(0, maxSpeed) * duration;
  change = THREE.MathUtils.clamp(change, -maxChange, maxChange);
  target = current - change;

  const temporary = (velocity + omega * change) * delta;
  let nextVelocity = (velocity - omega * temporary) * decay;
  let value = target + (change + temporary) * decay;

  // Avoid a low-frame-rate step carrying the spring past its requested focus.
  if ((originalTarget - current > 0) === (value > originalTarget)) {
    value = originalTarget;
    nextVelocity = 0;
  }
  return { value, velocity: nextVelocity };
}

function finitePoint(point) {
  return point
    && Number.isFinite(point.x)
    && Number.isFinite(point.y)
    && Number.isFinite(point.z);
}

export class BattleCameraController {
  constructor(options) {
    this.viewWidth = options.viewWidth;
    this.aspect = options.aspect;
    this.viewHeight = this.viewWidth / this.aspect;
    this.viewportWidth = options.viewportWidth;
    this.viewportHeight = options.viewportHeight;
    this.cameraOffset = options.cameraOffset.clone();
    this.boardBounds = { ...options.boardBounds };
    this.focusY = options.focusY ?? 0.15;
    this.defaultZoom = options.defaultZoom ?? 1.45;
    this.minZoom = options.minZoom ?? 0.82;
    this.maxZoom = options.maxZoom ?? 1.75;
    this.safeRect = this.normaliseSafeRect(options.safeRect);

    const offsetLength = Math.hypot(this.cameraOffset.y, this.cameraOffset.z);
    this.upY = this.cameraOffset.z / offsetLength;
    this.upZ = -this.cameraOffset.y / offsetLength;

    this.focus = (options.initialFocus || new THREE.Vector3(0, this.focusY, 0)).clone();
    this.focusTarget = this.focus.clone();
    this.focusVelocity = new THREE.Vector3();
    this.userZoom = this.defaultZoom;
    this.zoom = this.defaultZoom;
    this.fitZoom = this.maxZoom;
    this.zoomTarget = this.defaultZoom;
    this.zoomInDelay = 0;
    this.lastMode = 'idle';
  }

  normaliseSafeRect(rect = {}) {
    const left = THREE.MathUtils.clamp(rect.left ?? 16, 0, this.viewportWidth - 1);
    const right = THREE.MathUtils.clamp(rect.right ?? this.viewportWidth - 16, left + 1, this.viewportWidth);
    const top = THREE.MathUtils.clamp(rect.top ?? 120, 0, this.viewportHeight - 1);
    const bottom = THREE.MathUtils.clamp(rect.bottom ?? this.viewportHeight - 190, top + 1, this.viewportHeight);
    return { left, right, top, bottom };
  }

  reset(focus) {
    this.userZoom = this.defaultZoom;
    this.zoom = this.defaultZoom;
    this.fitZoom = this.maxZoom;
    this.zoomTarget = this.defaultZoom;
    this.zoomInDelay = 0;
    this.lastMode = 'idle';
    if (focus) this.focus.copy(focus);
    this.focus.y = this.focusY;
    this.focusTarget.copy(this.focus);
    this.focusVelocity.set(0, 0, 0);
    return this.snapshot();
  }

  setUserZoom(nextZoom, { immediate = true } = {}) {
    this.userZoom = THREE.MathUtils.clamp(nextZoom, this.minZoom, this.maxZoom);
    this.zoomTarget = Math.min(this.userZoom, this.fitZoom);
    if (immediate) this.zoom = this.zoomTarget;
    return this.snapshot();
  }

  snapshot() {
    return {
      zoom: this.zoom,
      userZoom: this.userZoom,
      fitZoom: this.fitZoom,
      zoomTarget: this.zoomTarget,
      focus: this.focus,
      focusTarget: this.focusTarget,
      mode: this.lastMode,
    };
  }

  projectPoint(point, focus = this.focus, zoom = this.zoom) {
    const screenX = point.x - focus.x;
    const screenY = (point.y - focus.y) * this.upY + (point.z - focus.z) * this.upZ;
    const ndcX = screenX * zoom / (this.viewWidth * 0.5);
    const ndcY = screenY * zoom / (this.viewHeight * 0.5);
    return {
      x: (ndcX + 1) * 0.5 * this.viewportWidth,
      y: (1 - ndcY) * 0.5 * this.viewportHeight,
    };
  }

  isPointVisible(point, { safe = false, margin = 18 } = {}) {
    if (!finitePoint(point)) return false;
    const projected = this.projectPoint(point);
    const rect = safe
      ? this.safeRect
      : { left: 0, right: this.viewportWidth, top: 0, bottom: this.viewportHeight };
    return projected.x >= rect.left + margin
      && projected.x <= rect.right - margin
      && projected.y >= rect.top + margin
      && projected.y <= rect.bottom - margin;
  }

  needsEnemyActionShot({ from, to, ranged = false, actionType = 'attack' }) {
    // Off-screen walking is background simulation, not a cinematic event. If
    // every moving monster could claim the camera during the 0.3s enemy phase,
    // the view would start travelling and immediately snap back to the hero.
    if (actionType !== 'attack' && actionType !== 'boss_claw') return false;
    const sourceOutside = !this.isPointVisible(from, { safe: false, margin: 10 });
    if (sourceOutside) return true;
    if (!ranged || !finitePoint(to)) return false;
    // A ranged attack only takes the camera when both ends cannot be read in
    // the unobstructed gameplay area at the player's current framing.
    return !this.isPointVisible(from, { safe: true, margin: 8 })
      || !this.isPointVisible(to, { safe: true, margin: 8 });
  }

  ndcSafeBounds() {
    return {
      minX: this.safeRect.left / this.viewportWidth * 2 - 1,
      maxX: this.safeRect.right / this.viewportWidth * 2 - 1,
      minY: 1 - this.safeRect.bottom / this.viewportHeight * 2,
      maxY: 1 - this.safeRect.top / this.viewportHeight * 2,
    };
  }

  fitShot(points, margin = DEFAULT_SAFE_MARGIN) {
    const valid = points.filter(finitePoint);
    if (!valid.length) return { zoom: this.maxZoom, focus: this.focus.clone() };

    let minX = Infinity;
    let maxX = -Infinity;
    let minY = Infinity;
    let maxY = -Infinity;
    for (const point of valid) {
      const projectedY = point.y * this.upY + point.z * this.upZ;
      minX = Math.min(minX, point.x);
      maxX = Math.max(maxX, point.x);
      minY = Math.min(minY, projectedY);
      maxY = Math.max(maxY, projectedY);
    }
    minX -= margin;
    maxX += margin;
    minY -= margin;
    maxY += margin;

    const safe = this.ndcSafeBounds();
    const safeSpanX = Math.max(0.1, safe.maxX - safe.minX);
    const safeSpanY = Math.max(0.1, safe.maxY - safe.minY);
    const fitX = safeSpanX * this.viewWidth / (2 * Math.max(0.01, maxX - minX));
    const fitY = safeSpanY * this.viewHeight / (2 * Math.max(0.01, maxY - minY));
    const zoom = THREE.MathUtils.clamp(Math.min(fitX, fitY), this.minZoom, this.maxZoom);

    const safeCenterX = (safe.minX + safe.maxX) * 0.5;
    const safeCenterY = (safe.minY + safe.maxY) * 0.5;
    const centerX = (minX + maxX) * 0.5;
    const centerY = (minY + maxY) * 0.5;
    const focus = new THREE.Vector3(
      centerX - safeCenterX * (this.viewWidth * 0.5) / zoom,
      this.focusY,
      0
    );
    const wantedProjectedY = safeCenterY * (this.viewHeight * 0.5) / zoom;
    focus.z = (centerY - this.focusY * this.upY - wantedProjectedY) / this.upZ;
    this.clampFocusToBoard(focus, zoom);
    return { zoom, focus };
  }

  clampFocusToBoard(focus, zoom) {
    const halfWidth = this.viewWidth / (2 * zoom);
    const halfHeight = this.viewHeight / (2 * zoom);
    const halfVisibleZ = halfHeight / Math.max(0.001, Math.abs(this.upZ));
    const clampAxis = (value, min, max, halfVisible) => {
      if (max - min <= halfVisible * 2) return (min + max) * 0.5;
      return THREE.MathUtils.clamp(value, min + halfVisible, max - halfVisible);
    };
    focus.x = clampAxis(focus.x, this.boardBounds.minX, this.boardBounds.maxX, halfWidth);
    focus.z = clampAxis(focus.z, this.boardBounds.minZ, this.boardBounds.maxZ, halfVisibleZ);
    focus.y = this.focusY;
    return focus;
  }

  applyDeadZone(primary, targetFocus, zoom) {
    if (!finitePoint(primary)) return targetFocus;
    const screen = this.projectPoint(primary, this.focus, zoom);
    const safeWidth = this.safeRect.right - this.safeRect.left;
    const safeHeight = this.safeRect.bottom - this.safeRect.top;
    const deadZone = {
      left: this.safeRect.left + safeWidth * 0.25,
      right: this.safeRect.right - safeWidth * 0.25,
      top: this.safeRect.top + safeHeight * 0.23,
      bottom: this.safeRect.bottom - safeHeight * 0.23,
    };
    if (screen.x >= deadZone.left && screen.x <= deadZone.right
      && screen.y >= deadZone.top && screen.y <= deadZone.bottom) {
      return this.focus.clone();
    }

    // Move only far enough to put the actor back on the nearest dead-zone
    // edge. Re-centering it every time it crossed the edge produced a visible
    // cell-sized camera step at the start of each move.
    const wantedX = THREE.MathUtils.clamp(screen.x, deadZone.left, deadZone.right);
    const wantedY = THREE.MathUtils.clamp(screen.y, deadZone.top, deadZone.bottom);
    const corrected = this.focus.clone();
    corrected.x += (screen.x - wantedX) * this.viewWidth / (this.viewportWidth * zoom);
    const screenYPerFocusZ = this.viewportHeight * zoom * this.upZ / this.viewHeight;
    if (Math.abs(screenYPerFocusZ) > 0.0001) {
      corrected.z += (wantedY - screen.y) / screenYPerFocusZ;
    }
    return this.clampFocusToBoard(corrected, zoom);
  }

  update(delta, shot = {}) {
    const mode = shot.mode || 'idle';
    const points = (shot.points || []).filter(finitePoint);
    const primary = finitePoint(shot.primary) ? shot.primary : points[0];
    const framingPoints = points.length ? points : (primary ? [primary] : []);
    const fitted = this.fitShot(framingPoints, shot.margin ?? DEFAULT_SAFE_MARGIN);

    this.fitZoom = mode === 'idle' ? this.maxZoom : fitted.zoom;
    this.zoomTarget = Math.min(this.userZoom, this.fitZoom);
    this.focusTarget.copy(fitted.focus);
    if (mode === 'idle' || mode === 'hero_action') {
      this.focusTarget.copy(this.applyDeadZone(primary, this.focusTarget, this.zoomTarget));
    }

    const pullingOut = this.zoomTarget < this.zoom - 0.002;
    if (pullingOut) {
      this.zoomInDelay = 0.6;
      this.zoom = damp(this.zoom, this.zoomTarget, 11, delta);
    } else {
      this.zoomInDelay = Math.max(0, this.zoomInDelay - delta);
      if (this.zoomInDelay <= 0) this.zoom = damp(this.zoom, this.zoomTarget, 5.5, delta);
    }

    const focusSmoothTime = mode === 'enemy_action'
      ? 0.18
      : mode === 'hero_action'
        ? 0.24
        : mode === 'planning'
          ? 0.3
          : 0.34;
    const nextX = smoothDampAxis(
      this.focus.x,
      this.focusTarget.x,
      this.focusVelocity.x,
      focusSmoothTime,
      18,
      delta
    );
    const nextZ = smoothDampAxis(
      this.focus.z,
      this.focusTarget.z,
      this.focusVelocity.z,
      focusSmoothTime,
      18,
      delta
    );
    this.focus.x = nextX.value;
    this.focus.z = nextZ.value;
    this.focusVelocity.x = nextX.velocity;
    this.focusVelocity.z = nextZ.velocity;
    this.focus.y = this.focusY;
    this.lastMode = mode;
    return this.snapshot();
  }
}
