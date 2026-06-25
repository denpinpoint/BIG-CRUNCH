import type { ObjectKind } from '../types';
import { OBJECTS, OBJECT_ORDER } from '../data/objects';
import { PARTICLE_COLORS } from '../entities/Particles';
import { rgba, lighten, darken } from '../utils/color';

/**
 * Pre-rendered, cached art. Glowing orbs and particle halos are generated once
 * to offscreen canvases, then drawn scaled each frame. This avoids per-object
 * gradient construction and expensive shadowBlur in the hot loop — the single
 * biggest win for steady 60 FPS on low-end hardware.
 */

const OBJ_SPRITE_SIZE = 256;
const OBJ_CORE_FRAC = 0.4; // core radius as fraction of half-sprite
const PARTICLE_SPRITE_SIZE = 64;

function createCanvas(size: number): HTMLCanvasElement {
  const c = document.createElement('canvas');
  c.width = size;
  c.height = size;
  return c;
}

export class SpriteCache {
  /** core diameter as fraction of full sprite — used to map radius→draw size. */
  readonly objectCoreFrac = OBJ_CORE_FRAC;
  private objectSprites = new Map<ObjectKind, HTMLCanvasElement>();
  private particleSprites: HTMLCanvasElement[] = [];

  constructor() {
    for (const kind of OBJECT_ORDER) {
      this.objectSprites.set(kind, this.buildObjectSprite(kind));
    }
    for (let i = 0; i < PARTICLE_COLORS.length; i++) {
      this.particleSprites.push(this.buildGlow(PARTICLE_COLORS[i]!));
    }
  }

  getObject(kind: ObjectKind): HTMLCanvasElement {
    return this.objectSprites.get(kind)!;
  }
  getParticle(index: number): HTMLCanvasElement {
    return this.particleSprites[index] ?? this.particleSprites[0]!;
  }

  private buildGlow(color: string): HTMLCanvasElement {
    const s = PARTICLE_SPRITE_SIZE;
    const c = createCanvas(s);
    const ctx = c.getContext('2d')!;
    const g = ctx.createRadialGradient(s / 2, s / 2, 0, s / 2, s / 2, s / 2);
    g.addColorStop(0, rgba(color, 1));
    g.addColorStop(0.25, rgba(color, 0.85));
    g.addColorStop(0.6, rgba(color, 0.25));
    g.addColorStop(1, rgba(color, 0));
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, s, s);
    return c;
  }

  private buildObjectSprite(kind: ObjectKind): HTMLCanvasElement {
    const def = OBJECTS[kind];
    const s = OBJ_SPRITE_SIZE;
    const c = createCanvas(s);
    const ctx = c.getContext('2d')!;
    const cx = s / 2;
    const cy = s / 2;
    const coreR = (s / 2) * OBJ_CORE_FRAC;

    // 1) Outer glow halo, extending well past the core.
    const halo = ctx.createRadialGradient(cx, cy, coreR * 0.5, cx, cy, s / 2);
    halo.addColorStop(0, rgba(def.glow, 0.55));
    halo.addColorStop(0.4, rgba(def.glow, 0.28));
    halo.addColorStop(0.75, rgba(def.glow, 0.06));
    halo.addColorStop(1, rgba(def.glow, 0));
    ctx.fillStyle = halo;
    ctx.fillRect(0, 0, s, s);

    // 2) Sphere-shaded core with an offset highlight for depth.
    const core = ctx.createRadialGradient(
      cx - coreR * 0.32, cy - coreR * 0.32, coreR * 0.1,
      cx, cy, coreR,
    );
    core.addColorStop(0, lighten(def.color, 0.55));
    core.addColorStop(0.55, def.color);
    core.addColorStop(1, darken(def.color, 0.45));
    ctx.beginPath();
    ctx.arc(cx, cy, coreR, 0, Math.PI * 2);
    ctx.fillStyle = core;
    ctx.fill();

    // 3) Bright rim to read as a luminous body.
    ctx.beginPath();
    ctx.arc(cx, cy, coreR * 0.98, 0, Math.PI * 2);
    ctx.lineWidth = coreR * 0.06;
    ctx.strokeStyle = rgba(def.glow, 0.5);
    ctx.stroke();

    // 4) Stars/neutron get an extra hot inner bloom.
    if (kind === 'star' || kind === 'neutron') {
      const bloom = ctx.createRadialGradient(cx, cy, 0, cx, cy, coreR * 0.7);
      bloom.addColorStop(0, rgba('#ffffff', 0.85));
      bloom.addColorStop(0.5, rgba(def.glow, 0.3));
      bloom.addColorStop(1, rgba(def.glow, 0));
      ctx.globalCompositeOperation = 'lighter';
      ctx.fillStyle = bloom;
      ctx.beginPath();
      ctx.arc(cx, cy, coreR * 0.7, 0, Math.PI * 2);
      ctx.fill();
      ctx.globalCompositeOperation = 'source-over';
    }
    return c;
  }
}
