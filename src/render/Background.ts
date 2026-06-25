import type { Camera } from '../core/Camera';
import type { SectorDef } from '../types';
import { RNG } from '../core/RNG';
import { rgba } from '../utils/color';

interface Star {
  x: number;
  y: number;
  r: number;
  a: number;
  tw: number; // twinkle phase
}

interface Nebula {
  x: number;
  y: number;
  r: number;
  color: string;
  drift: number;
}

const TILE = 1400;
const STARS_PER_LAYER = 70;
const PARALLAX = [0.25, 0.5, 0.85];

/**
 * Deep-space backdrop: three parallax star layers tiled infinitely, a few slow
 * drifting nebula blooms tinted to the current sector, and a vignette. Tuned to
 * stay cheap — a few hundred primitives per frame.
 */
export class Background {
  private layers: Star[][] = [];
  private nebulae: Nebula[] = [];
  private time = 0;
  private curTint = '#160c33';
  private targetTint = '#160c33';

  constructor() {
    const rng = new RNG(1337);
    for (let l = 0; l < PARALLAX.length; l++) {
      const stars: Star[] = [];
      for (let i = 0; i < STARS_PER_LAYER; i++) {
        stars.push({
          x: rng.next() * TILE,
          y: rng.next() * TILE,
          r: 0.5 + rng.next() * (l === 2 ? 1.8 : 1.1),
          a: 0.3 + rng.next() * 0.7,
          tw: rng.next() * Math.PI * 2,
        });
      }
      this.layers.push(stars);
    }
    const palette = ['#6c3fd6', '#2a6cd6', '#54e6ff', '#d63f9a'];
    for (let i = 0; i < 5; i++) {
      this.nebulae.push({
        x: rng.range(-3000, 3000),
        y: rng.range(-3000, 3000),
        r: rng.range(600, 1400),
        color: palette[Math.floor(rng.next() * palette.length)]!,
        drift: rng.range(4, 14),
      });
    }
  }

  setSector(sector: SectorDef): void {
    this.targetTint = sector.tint;
  }

  update(dt: number): void {
    this.time += dt;
    // Ease the base tint toward the sector colour.
    this.curTint = this.targetTint;
  }

  render(ctx: CanvasRenderingContext2D, cam: Camera): void {
    const w = cam.viewW;
    const h = cam.viewH;

    // Base fill.
    const bg = ctx.createRadialGradient(w * 0.5, h * 0.42, 0, w * 0.5, h * 0.5, Math.max(w, h) * 0.8);
    bg.addColorStop(0, this.curTint);
    bg.addColorStop(1, '#04030c');
    ctx.fillStyle = bg;
    ctx.fillRect(0, 0, w, h);

    // Nebula blooms (additive, slow drift).
    ctx.globalCompositeOperation = 'lighter';
    for (const n of this.nebulae) {
      const dx = Math.sin(this.time / n.drift) * 40;
      const sx = (n.x - cam.x * 0.3) + dx;
      const sy = (n.y - cam.y * 0.3);
      const px = sx * cam.zoom + w * 0.5;
      const py = sy * cam.zoom + h * 0.5;
      const pr = n.r * cam.zoom;
      if (px + pr < 0 || px - pr > w || py + pr < 0 || py - pr > h) continue;
      const g = ctx.createRadialGradient(px, py, 0, px, py, pr);
      g.addColorStop(0, rgba(n.color, 0.1));
      g.addColorStop(0.5, rgba(n.color, 0.04));
      g.addColorStop(1, rgba(n.color, 0));
      ctx.fillStyle = g;
      ctx.fillRect(px - pr, py - pr, pr * 2, pr * 2);
    }
    ctx.globalCompositeOperation = 'source-over';

    // Parallax star layers, tiled in screen space (scroll with camera, no zoom).
    ctx.fillStyle = '#ffffff';
    for (let l = 0; l < this.layers.length; l++) {
      const p = PARALLAX[l]!;
      const stars = this.layers[l]!;
      const offX = (((cam.x * p) % TILE) + TILE) % TILE;
      const offY = (((cam.y * p) % TILE) + TILE) % TILE;
      const tilesX = Math.ceil(w / TILE) + 1;
      const tilesY = Math.ceil(h / TILE) + 1;
      for (let ty = -1; ty <= tilesY; ty++) {
        for (let tx = -1; tx <= tilesX; tx++) {
          const baseX = tx * TILE - offX;
          const baseY = ty * TILE - offY;
          for (let i = 0; i < stars.length; i++) {
            const s = stars[i]!;
            const sx = baseX + s.x;
            const sy = baseY + s.y;
            if (sx < 0 || sx > w || sy < 0 || sy > h) continue;
            const twinkle = 0.6 + 0.4 * Math.sin(this.time * 2 + s.tw);
            ctx.globalAlpha = s.a * twinkle;
            ctx.fillRect(sx, sy, s.r, s.r);
          }
        }
      }
    }
    ctx.globalAlpha = 1;
  }
}
