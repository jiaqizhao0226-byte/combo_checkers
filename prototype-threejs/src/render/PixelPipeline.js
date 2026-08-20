import * as THREE from 'three';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPixelatedPass } from 'three/addons/postprocessing/RenderPixelatedPass.js';
import { ShaderPass } from 'three/addons/postprocessing/ShaderPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';

const clamp = (value, min, max) => Math.max(min, Math.min(max, value));

const PixelGlowShader = {
  uniforms: {
    tDiffuse: { value: null },
    uStep: { value: new THREE.Vector2() },
    uGlow: { value: 0.5 },
    uVignette: { value: 0.24 },
  },
  vertexShader: `
    varying vec2 vUv;
    void main() {
      vUv = uv;
      gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
    }
  `,
  fragmentShader: `
    uniform sampler2D tDiffuse;
    uniform vec2 uStep;
    uniform float uGlow;
    uniform float uVignette;
    varying vec2 vUv;

    void main() {
      vec3 base = texture2D(tDiffuse, vUv).rgb;
      vec3 bloom = vec3(0.0);
      float weightTotal = 0.0;

      for (int y = -2; y <= 2; y++) {
        for (int x = -2; x <= 2; x++) {
          float radius2 = float(x * x + y * y);
          if (radius2 > 6.5) continue;
          float weight = exp(-radius2 / 3.2);
          vec3 sampleColor = texture2D(
            tDiffuse,
            vUv + vec2(float(x), float(y)) * uStep
          ).rgb;
          float peak = max(max(sampleColor.r, sampleColor.g), sampleColor.b);
          bloom += sampleColor * smoothstep(1.0, 1.9, peak) * weight;
          weightTotal += weight;
        }
      }

      vec3 color = base + bloom / max(weightTotal, 0.001) * uGlow;
      color = mix(color, color * vec3(1.05, 1.0, 0.9), 0.48);
      vec2 centered = (vUv - 0.5) * vec2(1.0, 1.08);
      color *= 1.0 - dot(centered, centered) * uVignette;
      gl_FragColor = vec4(color, 1.0);
    }
  `,
};

export class PixelPipeline {
  constructor(renderer, scene, camera, options = {}) {
    this.renderer = renderer;
    this.pixelSize = options.pixelSize ?? 6;
    this.targetLowWidth = options.lowWidth ?? 184;
    this.lowWidth = this.targetLowWidth;
    this.lowHeight = Math.round(this.targetLowWidth * 2);
    this.bufferSize = new THREE.Vector2();
    this.lastWidth = 0;
    this.lastHeight = 0;

    this.composer = new EffectComposer(renderer);
    this.pixelPass = new RenderPixelatedPass(this.pixelSize, scene, camera);
    this.pixelPass.normalEdgeStrength = 0.045;
    this.pixelPass.depthEdgeStrength = 0.46;

    // Quantising the normal buffer removes bright lines between facets of the
    // same low-poly object while preserving real silhouettes.
    const normalMaterial = this.pixelPass._normalMaterial;
    if (normalMaterial) {
      normalMaterial.onBeforeCompile = shader => {
        shader.uniforms.uNormalSteps = { value: 1.5 };
        shader.fragmentShader = shader.fragmentShader
          .replace(
            'uniform float opacity;',
            'uniform float opacity;\nuniform float uNormalSteps;'
          )
          .replace(
            'gl_FragColor = vec4( normalize( normal ) * 0.5 + 0.5, diffuseColor.a );',
            `vec3 normalValue = normalize(normal);
             vec3 quantised = floor(normalValue * uNormalSteps + 0.5);
             if (dot(quantised, quantised) > 0.25) normalValue = normalize(quantised);
             gl_FragColor = vec4(normalValue * 0.5 + 0.5, diffuseColor.a);`
          );
      };
    }

    this.glowPass = new ShaderPass(PixelGlowShader);
    this.composer.addPass(this.pixelPass);
    this.composer.addPass(this.glowPass);
    this.composer.addPass(new OutputPass());
  }

  setScene(scene, camera) {
    this.pixelPass.scene = scene;
    this.pixelPass.camera = camera;
  }

  resize(canvas) {
    const width = Math.max(2, canvas.clientWidth);
    const height = Math.max(2, canvas.clientHeight);
    if (width === this.lastWidth && height === this.lastHeight) return false;

    this.lastWidth = width;
    this.lastHeight = height;

    // pixelSize is measured in backing-store pixels. Solve the backing ratio so
    // the horizontal field always contains roughly targetLowWidth game pixels.
    const ratio = clamp(this.pixelSize * this.targetLowWidth / width, 1, 3);
    this.renderer.setPixelRatio(ratio);
    this.renderer.setSize(width, height, false);
    this.renderer.getDrawingBufferSize(this.bufferSize);
    this.composer.setSize(this.bufferSize.x, this.bufferSize.y);

    this.lowWidth = Math.max(1, Math.floor(this.bufferSize.x / this.pixelSize));
    this.lowHeight = Math.max(1, Math.floor(this.bufferSize.y / this.pixelSize));
    this.glowPass.uniforms.uStep.value.set(
      this.pixelSize / this.bufferSize.x,
      this.pixelSize / this.bufferSize.y
    );
    return true;
  }

  render() {
    this.composer.render();
  }
}
