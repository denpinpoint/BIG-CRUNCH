import type { CosmicObject } from '../types';
import type { Player } from '../entities/Player';
import type { ObjectPool } from '../core/ObjectPool';
import type { ParticleSystem } from '../entities/Particles';
import type { GameState } from '../state/GameState';
import type { Modifiers } from '../state/runtime';
import { ORBIT_DURATIONS } from '../data/objects';
import { clamp, lerp } from '../utils/math';
import { easeInCubic } from '../utils/easing';

const PULL_ACCEL = 1150;

/**
 * Drives attraction, orbital capture and consumption. Objects the player is too
 * small to eat are never captured — they drift as visible motivation and are
 * gently deflected on contact ("the object escapes"). Everything drawn into the
 * gravity well is guaranteed to be consumed, so the loop always pays off.
 */
export class PhysicsSystem {
  /** Set by Game; invoked the instant an object is consumed. */
  onConsume: (o: CosmicObject) => void = () => {};

  update(
    dt: number,
    player: Player,
    pool: ObjectPool<CosmicObject>,
    particles: ParticleSystem,
    gs: GameState,
    mods: Modifiers,
    rng: () => number,
  ): void {
    const d = gs.derived;
    const items = pool.items;
    const px = player.pos.x;
    const py = player.pos.y;
    const pr = player.radius;

    for (let i = 0; i < items.length; i++) {
      const o = items[i]!;
      if (!o.active) continue;
      o.age += dt;
      o.spin += o.spinSpeed * dt;

      const dx = px - o.pos.x;
      const dy = py - o.pos.y;
      const dist = Math.hypot(dx, dy) || 0.0001;
      const consumable = gs.data.mass >= o.mass;
      const small = o.orbitTier === 'tiny' || o.orbitTier === 'medium';
      const large = o.orbitTier === 'massive';

      if (!consumable) {
        // Too big to eat: deflect on contact, otherwise let it drift past.
        const minD = pr + o.radius;
        if (dist < minD) {
          const push = ((minD - dist) / minD) * 240;
          o.vel.x -= (dx / dist) * push * dt;
          o.vel.y -= (dy / dist) * push * dt;
        }
        o.state = 'idle';
        this.integrateDrift(o, dt);
        continue;
      }

      let effGravity = player.gravityRadius;
      if (small) effGravity *= d.tinyReachMult * (1 + d.autoConsumeFrac * 1.5);

      if (o.state === 'idle' && dist < effGravity) {
        o.state = 'attracted';
      }

      if (o.state === 'attracted') {
        const falloff = clamp(1 - dist / effGravity, 0, 1);
        const shaped = Math.pow(falloff, Math.max(0.2, 1 - d.pullFalloffReduction));
        let f = PULL_ACCEL * d.pullMult * mods.pullMult * (0.3 + shaped);
        if (large) f *= d.largePullMult;
        o.vel.x += (dx / dist) * f * dt;
        o.vel.y += (dy / dist) * f * dt;
        if (mods.inwardDrift > 0) {
          o.vel.x += (dx / dist) * mods.inwardDrift * dt;
          o.vel.y += (dy / dist) * mods.inwardDrift * dt;
        }
        const drag = Math.pow(0.86, dt * 60);
        o.vel.x *= drag;
        o.vel.y *= drag;

        const baseOrbit = ORBIT_DURATIONS[o.orbitTier] ?? 0;
        const orbitDur =
          (baseOrbit * d.orbitTimeMult * (large ? d.giantOrbitTimeMult : 1)) /
          Math.max(0.25, d.consumeSpeedMult) /
          Math.max(0.25, mods.orbitSpeedMult);

        if (orbitDur > 0.03 && dist < pr + o.radius * 2.0 + 10) {
          o.state = 'orbiting';
          o.orbitRadius = Math.max(pr + o.radius, dist);
          o.orbitAngle = Math.atan2(o.pos.y - py, o.pos.x - px);
          o.orbitTime = 0;
          o.orbitDuration = orbitDur;
        } else if (dist < pr + o.radius * 0.5) {
          this.onConsume(o);
          o.active = false;
          continue;
        }
        o.pos.x += o.vel.x * dt;
        o.pos.y += o.vel.y * dt;
        continue;
      }

      if (o.state === 'orbiting') {
        o.orbitTime += dt;
        const t = clamp(o.orbitTime / o.orbitDuration, 0, 1);
        const curR = lerp(o.orbitRadius, pr * 0.7, easeInCubic(t));
        const angSpeed = (3.2 + 7 * t) * mods.orbitSpeedMult;
        o.orbitAngle += angSpeed * dt;
        o.pos.x = px + Math.cos(o.orbitAngle) * curR;
        o.pos.y = py + Math.sin(o.orbitAngle) * curR;
        // Energy-transfer sparks streaming into the core.
        if (rng() < dt * 30) {
          particles.stream(o.pos.x, o.pos.y, 1, large ? 2 : 1, 0.5, 240, rng);
        }
        if (t >= 1) {
          this.onConsume(o);
          o.active = false;
          continue;
        }
        continue;
      }

      // idle & drifting
      this.integrateDrift(o, dt);
    }
  }

  private integrateDrift(o: CosmicObject, dt: number): void {
    o.pos.x += o.vel.x * dt;
    o.pos.y += o.vel.y * dt;
    const drag = Math.pow(0.985, dt * 60);
    o.vel.x *= drag;
    o.vel.y *= drag;
  }

  /** Inward gravity shock on consuming a large body — yanks the field in. */
  applyShockwave(
    pool: ObjectPool<CosmicObject>,
    x: number,
    y: number,
    radius: number,
    strength: number,
  ): void {
    if (strength <= 0) return;
    const items = pool.items;
    for (let i = 0; i < items.length; i++) {
      const o = items[i]!;
      if (!o.active || o.state === 'orbiting') continue;
      const dx = x - o.pos.x;
      const dy = y - o.pos.y;
      const dist = Math.hypot(dx, dy) || 0.0001;
      if (dist > radius) continue;
      const f = (1 - dist / radius) * strength * 600;
      o.vel.x += (dx / dist) * f;
      o.vel.y += (dy / dist) * f;
    }
  }
}
