import * as THREE from '../vendor/three.module.js';

const clamp01 = value => Math.max(0, Math.min(1, value));
const easeOutCubic = value => 1 - Math.pow(1 - clamp01(value), 3);
const easeOutBack = value => {
  const t = clamp01(value) - 1;
  return 1 + 2.70158 * t * t * t + 1.70158 * t * t;
};

function createNumberTexture(value) {
  const canvas = document.createElement('canvas');
  canvas.width = 384;
  canvas.height = 192;
  const context = canvas.getContext('2d');
  context.clearRect(0, 0, canvas.width, canvas.height);
  context.textAlign = 'center';
  context.textBaseline = 'middle';
  context.font = '900 98px Inter, Arial, sans-serif';
  const label = `-${Math.max(0, Math.round(value))}`;

  context.shadowColor = 'rgba(67, 27, 10, .55)';
  context.shadowBlur = 10;
  context.shadowOffsetY = 5;
  const gradient = context.createLinearGradient(0, 38, 0, 144);
  gradient.addColorStop(0, '#fff1a8');
  gradient.addColorStop(0.45, '#ffc85b');
  gradient.addColorStop(1, '#ed7c2e');
  context.fillStyle = gradient;
  context.fillText(label, 192, 88);

  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.minFilter = THREE.LinearFilter;
  texture.magFilter = THREE.LinearFilter;
  texture.generateMipmaps = false;
  return texture;
}

export class DamageNumberCandidate {
  constructor(scene) {
    this.root = new THREE.Group();
    this.root.name = 'ReviewOnly_DamageNumberCandidateB';
    scene.add(this.root);
    this.effects = [];
  }

  play({ position, value = 24 }) {
    const texture = createNumberTexture(value);
    const material = new THREE.SpriteMaterial({
      map: texture,
      transparent: true,
      opacity: 1,
      depthTest: false,
      depthWrite: false,
      toneMapped: false,
    });
    const sprite = new THREE.Sprite(material);
    sprite.name = 'ReviewDamageNumber';
    sprite.position.copy(position);
    sprite.center.set(0.5, 0.3);
    sprite.renderOrder = 55;
    this.root.add(sprite);
    this.effects.push({
      sprite,
      material,
      texture,
      origin: position.clone(),
      elapsed: 0,
      duration: 0.72,
    });
    return sprite;
  }

  update(delta) {
    for (let index = this.effects.length - 1; index >= 0; index -= 1) {
      const effect = this.effects[index];
      effect.elapsed += Math.max(0, delta);
      const progress = clamp01(effect.elapsed / effect.duration);
      const pop = easeOutBack(Math.min(1, progress * 4.6));
      const settle = clamp01((progress - 0.22) / 0.38);
      const scale = (0.56 + pop * 0.62) * (1 - settle * 0.12);
      effect.sprite.scale.set(1.45 * scale, 0.725 * scale, 1);
      effect.sprite.position.copy(effect.origin);
      effect.sprite.position.x += easeOutCubic(progress) * 0.08;
      effect.sprite.position.y += easeOutCubic(progress) * 0.52;
      effect.material.opacity = progress < 0.64 ? 1 : (1 - progress) / 0.36;

      if (progress < 1) continue;
      this.root.remove(effect.sprite);
      effect.material.dispose();
      effect.texture.dispose();
      this.effects.splice(index, 1);
    }
  }

  clear() {
    while (this.effects.length) {
      const effect = this.effects.pop();
      this.root.remove(effect.sprite);
      effect.material.dispose();
      effect.texture.dispose();
    }
  }
}
