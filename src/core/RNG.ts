/**
 * Deterministic, fast PRNG (mulberry32). Used so spawns/events can be made
 * reproducible if needed and to avoid Math.random's unknown distribution.
 */
export class RNG {
  private state: number;

  constructor(seed: number = (Math.random() * 0xffffffff) >>> 0) {
    this.state = seed >>> 0;
  }

  /** Returns a float in [0, 1). */
  next = (): number => {
    this.state |= 0;
    this.state = (this.state + 0x6d2b79f5) | 0;
    let t = Math.imul(this.state ^ (this.state >>> 15), 1 | this.state);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };

  range(min: number, max: number): number {
    return min + this.next() * (max - min);
  }

  int(min: number, max: number): number {
    return Math.floor(min + this.next() * (max - min + 1));
  }

  /** Random unit-ish vector scaled by [minR, maxR]. Writes into out. */
  pointInRing(out: { x: number; y: number }, minR: number, maxR: number): void {
    const a = this.next() * Math.PI * 2;
    const r = minR + this.next() * (maxR - minR);
    out.x = Math.cos(a) * r;
    out.y = Math.sin(a) * r;
  }
}
