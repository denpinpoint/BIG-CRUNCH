import type { Camera } from '../core/Camera';
import type { Player } from '../entities/Player';
import type { ObjectPool } from '../core/ObjectPool';
import type { CosmicObject } from '../types';
import type { ParticleSystem } from '../entities/Particles';
import type { GameState } from '../state/GameState';
import { SpriteCache } from './sprites';
import { Background } from './Background';
import { rgba } from '../utils/color';

interface FloatText {
  active: boolean;
  x: number;
  y: number;
  vy: number;
  life: number;
  maxLife: number;
  text: string;
  color: string;
  size: number;
}

/**
 * Canvas2D renderer. Draws in CSS-pixel space (DPR applied via transform), culls
 * off-screen bodies, and composes everything from cached sprites plus a small
 * amount of procedural drawing for the player and floating numbers.
 */
export class Renderer {
  readonly canvas: HTMLCanvasElement;
  private ctx: CanvasRenderingContext2D;
  private dpr = 1;
  readonly sprites = new SpriteCache();
  readonly background = new Background();

  private floats: FloatText[] = [];

  constructor(canvas: HTMLCanvasElement) {
    this.canvas = canvas;
    const ctx = canvas.getContext('2d', { alpha: false });
    if (!ctx) throw new Error('2D canvas context unavailable');
    this.ctx = ctx;
    for (let i = 0; i < 48; i++) {
      this.floats.push({
        active: false, x: 0, y: 0, vy: 0, life: 0, maxLife: 1,
        text: '', color: '#fff', size: 16,
      });
    }
  }

  /** Resize backing store to viewport * DPR. Returns CSS pixel size. */
  resize(): { w: number; h: number } {
    const rect = this.canvas.getBoundingClientRect();
    const w = Math.max(1, Math.round(rect.width));
    const h = Math.max(1, Math.round(rect.height));
    // Clamp DPR to keep fill-rate sane on hi-DPI mobile / Chromebooks.
    this.dpr = Math.min(window.devicePixelRatio || 1, 2);
    this.canvas.width = Math.round(w * this.dpr);
    this.canvas.height = Math.round(h * this.dpr);
    return { w, h };
  }

  addFloat(x: number, y: number, text: string, color: string, size = 18): void {
    for (const f of this.floats) {
      if (f.active) continue;
      f.active = true;
      f.x = x; f.y = y; f.vy = -38;
      f.maxLife = 1.1; f.life = f.maxLife;
      f.text = text; f.color = color; f.size = size;
      return;
    }
  }

  updateFloats(dt: number): void {
    for (const f of this.floats) {
      if (!f.active) continue;
      f.life -= dt;
      if (f.life <= 0) { f.active = false; continue; }
      f.y += f.vy * dt;
      f.vy *= Math.pow(0.9, dt * 60);
    }
  }

  render(
    cam: Camera,
    player: Player,
    pool: ObjectPool<CosmicObject>,
    particles: ParticleSystem,
    gs: GameState,
    eventTint: string | null,
    eventStrength: number,
  ): void {
    const ctx = this.ctx;
    ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);

    this.background.render(ctx, cam);

    const w = cam.viewW;
    const h = cam.viewH;
    const zoom = cam.zoom;
    const coreFrac = this.sprites.objectCoreFrac;

    // ---- Cosmic objects (cached sprites, additive glow) ----
    ctx.globalCompositeOperation = 'lighter';
    const items = pool.items;
    for (let i = 0; i < items.length; i++) {
      const o = items[i]!;
      if (!o.active) continue;
      const sx = cam.worldToScreenX(o.pos.x);
      const sy = cam.worldToScreenY(o.pos.y);
      const drawW = (o.radius * zoom * 2) / coreFrac;
      const half = drawW * 0.5;
      if (sx + half < 0 || sx - half > w || sy + half < 0 || sy - half > h) continue;
      const sprite = this.sprites.getObject(o.kind);
      const fade = o.age < 0.35 ? o.age / 0.35 : 1;
      ctx.globalAlpha = fade;
      ctx.drawImage(sprite, sx - half, sy - half, drawW, drawW);
    }
    ctx.globalAlpha = 1;
    ctx.globalCompositeOperation = 'source-over';

    // ---- Particles ----
    this.renderParticles(ctx, cam, particles);

    // ---- Player black hole ----
    this.renderPlayer(ctx, cam, player, gs);

    // ---- Floating numbers ----
    this.renderFloats(ctx, cam);

    // ---- Event vignette ----
    if (eventTint && eventStrength > 0) {
      ctx.globalCompositeOperation = 'lighter';
      const g = ctx.createRadialGradient(w / 2, h / 2, Math.min(w, h) * 0.3, w / 2, h / 2, Math.max(w, h) * 0.75);
      g.addColorStop(0, rgba(eventTint, 0));
      g.addColorStop(1, rgba(eventTint, 0.18 * eventStrength));
      ctx.fillStyle = g;
      ctx.fillRect(0, 0, w, h);
      ctx.globalCompositeOperation = 'source-over';
    }
  }

  private renderParticles(ctx: CanvasRenderingContext2D, cam: Camera, particles: ParticleSystem): void {
    ctx.globalCompositeOperation = 'lighter';
    const items = particles.pool.items;
    const zoom = cam.zoom;
    const w = cam.viewW;
    const h = cam.viewH;
    for (let i = 0; i < items.length; i++) {
      const p = items[i]!;
      if (!p.active) continue;
      const sx = cam.worldToScreenX(p.x);
      const sy = cam.worldToScreenY(p.y);
      const size = p.size * zoom * 3.2;
      const half = size * 0.5;
      if (sx + half < 0 || sx - half > w || sy + half < 0 || sy - half > h) continue;
      ctx.globalAlpha = Math.min(1, p.life / p.maxLife);
      ctx.drawImage(this.sprites.getParticle(p.color), sx - half, sy - half, size, size);
    }
    ctx.globalAlpha = 1;
    ctx.globalCompositeOperation = 'source-over';
  }

  private renderPlayer(ctx: CanvasRenderingContext2D, cam: Camera, player: Player, gs: GameState): void {
    const sx = cam.worldToScreenX(player.pos.x);
    const sy = cam.worldToScreenY(player.pos.y);
    const rp = Math.max(6, player.radius * cam.zoom);
    const reduced = gs.data.settings.reducedMotion;

    // Faint gravity-reach ring so the player understands their pull.
    const gr = player.gravityRadius * cam.zoom;
    if (gr < Math.max(cam.viewW, cam.viewH) * 1.5) {
      ctx.beginPath();
      ctx.arc(sx, sy, gr, 0, Math.PI * 2);
      ctx.strokeStyle = rgba('#6c3fd6', 0.12);
      ctx.lineWidth = 1.5;
      ctx.stroke();
    }

    ctx.globalCompositeOperation = 'lighter';

    // Lensing halo.
    const halo = ctx.createRadialGradient(sx, sy, rp * 0.6, sx, sy, rp * 3.4);
    halo.addColorStop(0, rgba('#6c3fd6', 0.55));
    halo.addColorStop(0.4, rgba('#54e6ff', 0.18));
    halo.addColorStop(1, rgba('#54e6ff', 0));
    ctx.fillStyle = halo;
    ctx.beginPath();
    ctx.arc(sx, sy, rp * 3.4, 0, Math.PI * 2);
    ctx.fill();

    // Accretion disk: rotating hot gradient annulus.
    const spin = reduced ? 0 : player.spin;
    const gx = Math.cos(spin);
    const gy = Math.sin(spin);
    const disk = ctx.createLinearGradient(sx - gx * rp * 2, sy - gy * rp * 2, sx + gx * rp * 2, sy + gy * rp * 2);
    disk.addColorStop(0, rgba('#ffd166', 0.0));
    disk.addColorStop(0.35, rgba('#ffd166', 0.5));
    disk.addColorStop(0.5, rgba('#ffffff', 0.85));
    disk.addColorStop(0.65, rgba('#54e6ff', 0.5));
    disk.addColorStop(1, rgba('#54e6ff', 0.0));
    ctx.fillStyle = disk;
    ctx.beginPath();
    ctx.arc(sx, sy, rp * 1.95, 0, Math.PI * 2);
    ctx.arc(sx, sy, rp * 1.08, 0, Math.PI * 2, true);
    ctx.fill('evenodd');

    // Consume pulse ring.
    if (player.pulse > 0) {
      const pr = rp * (1 + player.pulse * 2.2);
      ctx.beginPath();
      ctx.arc(sx, sy, pr, 0, Math.PI * 2);
      ctx.strokeStyle = rgba('#ffffff', player.pulse * 0.6);
      ctx.lineWidth = 2 + player.pulse * 4;
      ctx.stroke();
    }

    ctx.globalCompositeOperation = 'source-over';

    // Event horizon (true black) + photon ring.
    ctx.beginPath();
    ctx.arc(sx, sy, rp, 0, Math.PI * 2);
    ctx.fillStyle = '#000000';
    ctx.fill();

    ctx.globalCompositeOperation = 'lighter';
    ctx.beginPath();
    ctx.arc(sx, sy, rp * 1.04, 0, Math.PI * 2);
    ctx.strokeStyle = rgba('#aef3ff', 0.9);
    ctx.lineWidth = Math.max(1, rp * 0.06);
    ctx.stroke();
    ctx.globalCompositeOperation = 'source-over';
  }

  /** Draw the floating mobile joystick (screen space; call after render). */
  drawJoystick(originX: number, originY: number, curX: number, curY: number): void {
    const ctx = this.ctx;
    ctx.globalCompositeOperation = 'source-over';
    ctx.beginPath();
    ctx.arc(originX, originY, 52, 0, Math.PI * 2);
    ctx.fillStyle = rgba('#6c3fd6', 0.16);
    ctx.fill();
    ctx.strokeStyle = rgba('#54e6ff', 0.35);
    ctx.lineWidth = 2;
    ctx.stroke();
    // Clamp knob to the ring.
    let dx = curX - originX;
    let dy = curY - originY;
    const len = Math.hypot(dx, dy);
    if (len > 52) { dx = (dx / len) * 52; dy = (dy / len) * 52; }
    ctx.beginPath();
    ctx.arc(originX + dx, originY + dy, 22, 0, Math.PI * 2);
    ctx.fillStyle = rgba('#54e6ff', 0.6);
    ctx.fill();
  }

  private renderFloats(ctx: CanvasRenderingContext2D, cam: Camera): void {
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    for (const f of this.floats) {
      if (!f.active) continue;
      const sx = cam.worldToScreenX(f.x);
      const sy = cam.worldToScreenY(f.y);
      const t = f.life / f.maxLife;
      ctx.globalAlpha = Math.min(1, t * 1.6);
      ctx.font = `700 ${f.size}px Rajdhani, system-ui, sans-serif`;
      ctx.fillStyle = f.color;
      ctx.shadowColor = f.color;
      ctx.shadowBlur = 8;
      ctx.fillText(f.text, sx, sy);
    }
    ctx.shadowBlur = 0;
    ctx.globalAlpha = 1;
  }
}
