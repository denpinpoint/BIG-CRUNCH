import type { EventId } from '../types';
import type { GameState } from '../state/GameState';
import type { Modifiers } from '../state/runtime';
import { EVENTS, EVENT_ORDER } from '../data/events';
import { CONFIG } from '../config';
import { RNG } from '../core/RNG';

/**
 * Schedules and runs universe events. Events fire automatically on a cadence,
 * each reshaping spawn patterns, physics and visuals for their duration. The
 * EventSystem both ticks the schedule and writes per-frame Modifiers.
 */
export class EventSystem {
  activeId: EventId | null = null;
  remaining = 0;
  duration = 0;
  private nextIn: number = CONFIG.EVENT_FIRST_DELAY;
  private rng = new RNG((Math.random() * 1e9) >>> 0);

  onStart: (id: EventId) => void = () => {};
  onEnd: (id: EventId) => void = () => {};

  update(dt: number, gs: GameState): void {
    if (this.activeId) {
      this.remaining -= dt;
      if (this.remaining <= 0) {
        const ended = this.activeId;
        this.activeId = null;
        this.remaining = 0;
        this.nextIn = this.rng.range(CONFIG.EVENT_INTERVAL_MIN, CONFIG.EVENT_INTERVAL_MAX);
        this.onEnd(ended);
      }
      return;
    }
    this.nextIn -= dt;
    if (this.nextIn <= 0) {
      const id = this.pick(gs);
      if (id) {
        this.activeId = id;
        this.duration = EVENTS[id].duration * gs.derived.eventPowerMult;
        this.remaining = this.duration;
        gs.data.stats.eventsTriggered++;
        this.onStart(id);
      } else {
        this.nextIn = 20; // nothing unlocked yet; check again shortly
      }
    }
  }

  private pick(gs: GameState): EventId | null {
    const mass = gs.data.stats.bestMass;
    const pool: EventId[] = [];
    for (const id of EVENT_ORDER) {
      if (mass >= EVENTS[id].unlockMass) pool.push(id);
    }
    if (pool.length === 0) return null;
    return pool[this.rng.int(0, pool.length - 1)] ?? null;
  }

  /** Write event-driven modifiers for this frame. */
  applyMods(mods: Modifiers, gs: GameState): void {
    if (!this.activeId) return;
    const power = gs.derived.eventPowerMult;
    switch (this.activeId) {
      case 'meteorShower':
        mods.spawnMult *= 2.0;
        mods.pullMult *= 1.1;
        break;
      case 'nebulaBloom':
        mods.massMult *= 1.4 * power;
        mods.spawnMult *= 1.3;
        break;
      case 'solarCollapse':
        mods.spawnMult *= 1.4;
        mods.inwardDrift += 70 * power;
        mods.rarityBonus += 0.3;
        break;
      case 'galaxyDrift':
        mods.inwardDrift += 150 * power;
        mods.pullMult *= 1.3;
        break;
      case 'temporalDistortion':
        mods.orbitSpeedMult *= 2.4 * power;
        mods.spawnMult *= 1.2;
        break;
      case 'universeTear':
        mods.spawnMult *= 2.0;
        mods.massMult *= 1.3 * power;
        mods.inwardDrift += 90 * power;
        mods.rarityBonus += 0.5;
        break;
    }
  }

  /** Vignette tint for the active event, or null. */
  tint(): string | null {
    return this.activeId ? EVENTS[this.activeId].color : null;
  }

  /** 0..1 vignette strength, gently pulsing and fading at the edges. */
  strength(): number {
    if (!this.activeId || this.duration <= 0) return 0;
    const t = this.remaining / this.duration;
    const edge = Math.min(1, t * 4, (1 - t) * 4 + 0.4);
    return 0.6 + 0.4 * Math.sin(this.remaining * 3) * edge;
  }

  reset(): void {
    this.activeId = null;
    this.remaining = 0;
    this.nextIn = CONFIG.EVENT_FIRST_DELAY;
  }
}
