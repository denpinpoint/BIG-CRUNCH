import type { Vec2 } from '../utils/math';
import { clamp, damp } from '../utils/math';
import { CONFIG } from '../config';
import type { GameState } from '../state/GameState';

/**
 * The player: a living singularity. Movement is intentionally "heavy but
 * responsive" — velocity eases toward a target with no lingering momentum, so
 * there is never overshoot frustration. Size and gravity reach are derived from
 * mass each frame.
 */
export class Player {
  pos: Vec2 = { x: 0, y: 0 };
  vel: Vec2 = { x: 0, y: 0 };
  radius: number = CONFIG.PLAYER_BASE_RADIUS;
  gravityRadius = 120;
  /** 0..1 transient pulse used for the consume "thump" visual. */
  pulse = 0;
  /** Accumulated spin for the swirling accretion ring. */
  spin = 0;

  recomputeSize(gs: GameState): void {
    const mass = gs.data.mass;
    this.radius = CONFIG.PLAYER_BASE_RADIUS + CONFIG.PLAYER_RADIUS_GROWTH * Math.cbrt(mass);
    const d = gs.derived;
    this.gravityRadius =
      (this.radius * CONFIG.GRAVITY_RADIUS_FACTOR + CONFIG.GRAVITY_RADIUS_FLAT) *
        d.gravityRadiusMult +
      d.gravityRadiusFlat;
  }

  update(dt: number, dir: Vec2, gs: GameState, sectorSize: number): void {
    this.recomputeSize(gs);
    const d = gs.derived;
    const speed =
      (CONFIG.PLAYER_BASE_SPEED + this.radius * CONFIG.PLAYER_SPEED_SIZE_BONUS) *
      d.moveSpeedMult *
      d.topSpeedMult;

    const targetVx = dir.x * speed;
    const targetVy = dir.y * speed;
    const accel = CONFIG.PLAYER_ACCEL * d.accelMult;
    this.vel.x = damp(this.vel.x, targetVx, accel, dt);
    this.vel.y = damp(this.vel.y, targetVy, accel, dt);

    this.pos.x += this.vel.x * dt;
    this.pos.y += this.vel.y * dt;

    // Keep the player inside the current sector with a soft margin.
    const half = sectorSize * 0.5 - this.radius;
    this.pos.x = clamp(this.pos.x, -half, half);
    this.pos.y = clamp(this.pos.y, -half, half);

    this.spin += dt * (1.2 + this.vel.x * 0.0002);
    if (this.pulse > 0) this.pulse = Math.max(0, this.pulse - dt * 3.5);
  }

  /** Trigger the consume pulse, scaled by how big the meal was. */
  thump(scale: number): void {
    this.pulse = Math.min(1, this.pulse + scale);
  }
}
