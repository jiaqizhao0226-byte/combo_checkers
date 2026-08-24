const DEFAULT_OFFSETS = Object.freeze([
  Object.freeze({ x: 0, y: 0 }),
  Object.freeze({ x: -0.24, y: 0.38 }),
  Object.freeze({ x: 0.22, y: 0.72 }),
  Object.freeze({ x: -0.08, y: 1.04 }),
]);

export function createDamageNumberLaneAllocator(options = {}) {
  const windowSeconds = Math.max(0, options.windowSeconds ?? 0.3);
  const offsets = options.offsets?.length ? options.offsets : DEFAULT_OFFSETS;
  const recent = new Map();

  return {
    reserve(key, time) {
      const safeKey = String(key || 'unknown');
      const safeTime = Number.isFinite(time) ? time : 0;
      const previous = recent.get(safeKey);
      const lane = previous && safeTime - previous.time <= windowSeconds
        ? (previous.lane + 1) % offsets.length
        : 0;
      recent.set(safeKey, { lane, time: safeTime });
      return { x: offsets[lane].x, y: offsets[lane].y, lane };
    },
    reset() {
      recent.clear();
    },
  };
}
