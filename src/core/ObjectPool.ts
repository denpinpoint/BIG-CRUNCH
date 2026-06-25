/**
 * Fixed-capacity object pool. Objects are pre-allocated once and reused so the
 * hot loop never allocates (no GC churn → stable 60 FPS on low-end hardware).
 */
export class ObjectPool<T extends { active: boolean }> {
  readonly items: T[];
  private readonly factory: () => T;
  /** Rolling search cursor so obtain() is amortized near O(1). */
  private cursor = 0;

  constructor(capacity: number, factory: () => T) {
    this.factory = factory;
    this.items = new Array(capacity);
    for (let i = 0; i < capacity; i++) {
      const obj = factory();
      obj.active = false;
      this.items[i] = obj;
    }
  }

  get capacity(): number {
    return this.items.length;
  }

  /** Grab an inactive slot, marking it active. Returns null if full. */
  obtain(): T | null {
    const items = this.items;
    const n = items.length;
    for (let k = 0; k < n; k++) {
      const i = (this.cursor + k) % n;
      const it = items[i]!;
      if (!it.active) {
        it.active = true;
        this.cursor = (i + 1) % n;
        return it;
      }
    }
    return null;
  }

  /** Number of currently active items (linear scan; call sparingly). */
  countActive(): number {
    let n = 0;
    for (let i = 0; i < this.items.length; i++) if (this.items[i]!.active) n++;
    return n;
  }

  /** Grow the pool to a larger capacity, preserving existing items. */
  grow(newCapacity: number): void {
    for (let i = this.items.length; i < newCapacity; i++) {
      const obj = this.factory();
      obj.active = false;
      this.items.push(obj);
    }
  }

  release(item: T): void {
    item.active = false;
  }

  releaseAll(): void {
    for (let i = 0; i < this.items.length; i++) this.items[i]!.active = false;
  }
}
