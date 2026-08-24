export function createVfxCanvas(width = 1, height = 1) {
  let canvas = null;
  if (typeof globalThis.wx?.createOffscreenCanvas === 'function') {
    canvas = globalThis.wx.createOffscreenCanvas({ type: '2d', width, height });
  } else if (typeof globalThis.document?.createElement === 'function') {
    canvas = globalThis.document.createElement('canvas');
  } else if (typeof globalThis.wx?.createCanvas === 'function') {
    canvas = globalThis.wx.createCanvas();
  }
  if (!canvas) throw new Error('No Canvas implementation is available for battle VFX');
  canvas.width = width;
  canvas.height = height;
  return canvas;
}
