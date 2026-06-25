import type { CosmicObject } from '../types';

/**
 * Uniform-bucket spatial hash for broad-phase neighbour queries. Rebuilt each
 * physics step from the active object list — clearing buckets via length = 0
 * reuses their backing arrays, so steady-state churn allocates nothing.
 *
 * World coordinates can be negative and unbounded, so cells are addressed by a
 * hashed (cx, cy) pair rather than a fixed dense array.
 */
export class SpatialGrid {
  private readonly cellSize: number;
  private readonly buckets = new Map<number, CosmicObject[]>();

  constructor(cellSize: number = 220) {
    this.cellSize = cellSize;
  }

  private key(cx: number, cy: number): number {
    // Pack two 16-bit signed cell coords into one number key.
    return ((cx & 0xffff) << 16) | (cy & 0xffff);
  }

  clear(): void {
    for (const arr of this.buckets.values()) arr.length = 0;
  }

  insert(obj: CosmicObject): void {
    const cx = Math.floor(obj.pos.x / this.cellSize);
    const cy = Math.floor(obj.pos.y / this.cellSize);
    const k = this.key(cx, cy);
    let bucket = this.buckets.get(k);
    if (!bucket) {
      bucket = [];
      this.buckets.set(k, bucket);
    }
    bucket.push(obj);
  }

  /**
   * Invoke `cb` for every object whose cell overlaps a circle of `radius`
   * centred at (x, y). May include objects slightly outside the radius — the
   * caller does the exact distance test.
   */
  queryCircle(x: number, y: number, radius: number, cb: (o: CosmicObject) => void): void {
    const cs = this.cellSize;
    const minX = Math.floor((x - radius) / cs);
    const maxX = Math.floor((x + radius) / cs);
    const minY = Math.floor((y - radius) / cs);
    const maxY = Math.floor((y + radius) / cs);
    for (let cx = minX; cx <= maxX; cx++) {
      for (let cy = minY; cy <= maxY; cy++) {
        const bucket = this.buckets.get(this.key(cx, cy));
        if (!bucket) continue;
        for (let i = 0; i < bucket.length; i++) cb(bucket[i]!);
      }
    }
  }
}
