import { ObjectPool } from '../core/ObjectPool';
import { CONFIG } from '../config';

/** Particle glow colours, referenced by index to avoid per-frame strings. */
export const PARTICLE_COLORS = [
  '#ffffff', // 0 white
  '#54e6ff', // 1 cyan
  '#ffd166', // 2 gold
  '#9a8cff', // 3 violet
  '#ff5d73', // 4 red
  '#7dffb0', // 5 green
] as const;

export interface Particle {
  active: boolean;
  x: number;
  y: number;
  vx: number;
  vy: number;
  life: number;
  maxLife: number;
  size: number;
  color: number; // index into PARTICLE_COLORS
  drag: number;
  /** Pull toward a moving point (the player) — used for absorption sparks. */
  pull: number;
}

function makeParticle(): Particle {
  return {
    active: false, x: 0, y: 0, vx: 0, vy: 0,
    life: 0, maxLife: 1, size: 4, color: 0, drag: 1, pull: 0,
  };
}

export class ParticleSystem {
  readonly pool = new ObjectPool<Particle>(CONFIG.MAX_PARTICLES, makeParticle);

  /** A radial burst of glowing motes. */
  burst(
    x: number, y: number, count: number, color: number,
    speedMin: number, speedMax: number, sizeMin: number, sizeMax: number,
    life: number, drag = 0.9, rng: () => number = Math.random,
  ): void {
    for (let i = 0; i < count; i++) {
      const p = this.pool.obtain();
      if (!p) return;
      const a = rng() * Math.PI * 2;
      const sp = speedMin + rng() * (speedMax - speedMin);
      p.x = x; p.y = y;
      p.vx = Math.cos(a) * sp;
      p.vy = Math.sin(a) * sp;
      p.size = sizeMin + rng() * (sizeMax - sizeMin);
      p.color = color;
      p.maxLife = life * (0.7 + rng() * 0.6);
      p.life = p.maxLife;
      p.drag = drag;
      p.pull = 0;
    }
  }

  /** Sparks that stream toward (tx,ty) — the absorption flow into the core. */
  stream(
    x: number, y: number, count: number, color: number,
    life: number, pull: number, rng: () => number = Math.random,
  ): void {
    for (let i = 0; i < count; i++) {
      const p = this.pool.obtain();
      if (!p) return;
      const a = rng() * Math.PI * 2;
      const sp = 20 + rng() * 60;
      p.x = x; p.y = y;
      p.vx = Math.cos(a) * sp;
      p.vy = Math.sin(a) * sp;
      p.size = 2 + rng() * 2.5;
      p.color = color;
      p.maxLife = life * (0.6 + rng() * 0.8);
      p.life = p.maxLife;
      p.drag = 0.94;
      p.pull = pull;
    }
  }

  /**
   * Advance particles. Those with `pull` accelerate toward (px,py) — the live
   * player position — producing the swirling in-fall effect.
   */
  update(dt: number, px: number, py: number): void {
    const items = this.pool.items;
    for (let i = 0; i < items.length; i++) {
      const p = items[i]!;
      if (!p.active) continue;
      p.life -= dt;
      if (p.life <= 0) {
        p.active = false;
        continue;
      }
      if (p.pull > 0) {
        const dx = px - p.x;
        const dy = py - p.y;
        const inv = p.pull / (Math.hypot(dx, dy) + 1);
        p.vx += dx * inv * dt;
        p.vy += dy * inv * dt;
      }
      const drag = Math.pow(p.drag, dt * 60);
      p.vx *= drag;
      p.vy *= drag;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
    }
  }

  clear(): void {
    this.pool.releaseAll();
  }
}
