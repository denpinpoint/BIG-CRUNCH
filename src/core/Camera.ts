import { clamp, damp } from '../utils/math';

/**
 * Smoothed follow-camera with zoom and trauma-based screen shake. Zoom eases
 * out as the player grows, which sells the sense of cosmic scale: the universe
 * appears to shrink around you.
 */
export class Camera {
  x = 0;
  y = 0;
  zoom = 1;
  targetZoom = 1;

  /** Viewport size in CSS pixels (not device pixels). */
  viewW = 1;
  viewH = 1;

  // Trauma in [0,1]; shake magnitude scales with trauma^2 for punchy feel.
  private trauma = 0;
  private shakeX = 0;
  private shakeY = 0;
  private shakeT = 0;

  setViewport(w: number, h: number): void {
    this.viewW = w;
    this.viewH = h;
  }

  snapTo(x: number, y: number): void {
    this.x = x;
    this.y = y;
  }

  /** Add screen shake. `amount` ~0.2 small hit, ~0.6 big, clamps at 1. */
  addTrauma(amount: number): void {
    this.trauma = clamp(this.trauma + amount, 0, 1);
  }

  update(targetX: number, targetY: number, desiredZoom: number, dt: number): void {
    this.targetZoom = desiredZoom;
    // Follow with critically-damped smoothing — heavy but responsive.
    this.x = damp(this.x, targetX, 6, dt);
    this.y = damp(this.y, targetY, 6, dt);
    this.zoom = damp(this.zoom, this.targetZoom, 3.5, dt);

    // Decay trauma and compute jittered offset.
    this.trauma = Math.max(0, this.trauma - dt * 1.4);
    this.shakeT += dt * 60;
    const mag = this.trauma * this.trauma * 26;
    this.shakeX = (Math.sin(this.shakeT * 1.7) + Math.sin(this.shakeT * 3.1)) * 0.5 * mag;
    this.shakeY = (Math.cos(this.shakeT * 1.3) + Math.sin(this.shakeT * 2.7)) * 0.5 * mag;
  }

  worldToScreenX(wx: number): number {
    return (wx - this.x) * this.zoom + this.viewW * 0.5 + this.shakeX;
  }
  worldToScreenY(wy: number): number {
    return (wy - this.y) * this.zoom + this.viewH * 0.5 + this.shakeY;
  }

  screenToWorldX(sx: number): number {
    return (sx - this.viewW * 0.5 - this.shakeX) / this.zoom + this.x;
  }
  screenToWorldY(sy: number): number {
    return (sy - this.viewH * 0.5 - this.shakeY) / this.zoom + this.y;
  }

  /** Half-width / half-height of the visible world region (for culling). */
  get halfViewW(): number {
    return this.viewW * 0.5 / this.zoom;
  }
  get halfViewH(): number {
    return this.viewH * 0.5 / this.zoom;
  }
}
