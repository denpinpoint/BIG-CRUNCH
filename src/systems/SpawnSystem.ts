import type { CosmicObject, ObjectKind, SectorDef, EventId } from '../types';
import type { Player } from '../entities/Player';
import type { ObjectPool } from '../core/ObjectPool';
import type { GameState } from '../state/GameState';
import type { Modifiers } from '../state/runtime';
import { OBJECTS, OBJECT_ORDER } from '../data/objects';
import { initObject } from '../entities/cosmicObject';
import { CONFIG } from '../config';
import { clamp } from '../utils/math';

/**
 * Streams matter into the sector around the player: spawns just beyond the view
 * edge, culls idle bodies that drift too far, and weights the spawn pool by
 * unlocked tiers, sector emphasis, rarity luck and the active event.
 */
export class SpawnSystem {
  private timer = 0;
  private readonly candidates: ObjectKind[] = [];
  private readonly weights: number[] = [];

  reset(): void {
    this.timer = 0;
  }

  update(
    dt: number,
    player: Player,
    pool: ObjectPool<CosmicObject>,
    gs: GameState,
    mods: Modifiers,
    rng: () => number,
    viewHalfW: number,
    viewHalfH: number,
    sector: SectorDef,
    activeEvent: EventId | null,
    combo: number,
  ): void {
    const d = gs.derived;
    const active = pool.countActive();
    const maxObjects = d.maxObjects;

    // Cull idle bodies that have drifted well outside the view.
    const cullR = Math.max(viewHalfW, viewHalfH) * 1.7 + CONFIG.SPAWN_MARGIN;
    const cullR2 = cullR * cullR;
    const items = pool.items;
    for (let i = 0; i < items.length; i++) {
      const o = items[i]!;
      if (!o.active || o.state === 'orbiting' || o.state === 'attracted') continue;
      const dx = o.pos.x - player.pos.x;
      const dy = o.pos.y - player.pos.y;
      if (dx * dx + dy * dy > cullR2) o.active = false;
    }

    if (active >= maxObjects) {
      this.timer = 0;
      return;
    }

    // Combo-driven "feeding frenzy" raises spawn rate at high combos.
    const frenzy = 1 + d.feedingFrenzyPct * Math.max(0, combo - 1);
    const rate = d.spawnRateMult * mods.spawnMult * frenzy;
    const interval = CONFIG.BASE_SPAWN_INTERVAL / Math.max(0.2, rate);

    this.timer += dt;
    let guard = 0;
    while (this.timer >= interval && pool.countActive() < maxObjects && guard < 12) {
      this.timer -= interval;
      guard++;
      this.spawnOne(player, pool, gs, rng, viewHalfW, viewHalfH, sector, activeEvent, mods);
    }
  }

  /** Fill the area around the player on load / sector change. */
  prewarm(
    player: Player,
    pool: ObjectPool<CosmicObject>,
    gs: GameState,
    rng: () => number,
    viewHalfW: number,
    viewHalfH: number,
    sector: SectorDef,
    count: number,
  ): void {
    for (let i = 0; i < count; i++) {
      // Spread across the visible area (not just the ring) for a full field.
      const ang = rng() * Math.PI * 2;
      const r = Math.max(viewHalfW, viewHalfH) * (0.2 + rng() * 1.1);
      const x = clamp(player.pos.x + Math.cos(ang) * r, -sector.size / 2, sector.size / 2);
      const y = clamp(player.pos.y + Math.sin(ang) * r, -sector.size / 2, sector.size / 2);
      this.spawnAt(x, y, pool, gs, rng, sector, null, 0, 0);
    }
  }

  private spawnOne(
    player: Player,
    pool: ObjectPool<CosmicObject>,
    gs: GameState,
    rng: () => number,
    viewHalfW: number,
    viewHalfH: number,
    sector: SectorDef,
    activeEvent: EventId | null,
    mods: Modifiers,
  ): void {
    const ang = rng() * Math.PI * 2;
    const ring = Math.max(viewHalfW, viewHalfH) * (1.05 + rng() * 0.4);
    let x = player.pos.x + Math.cos(ang) * ring;
    let y = player.pos.y + Math.sin(ang) * ring;
    const half = sector.size / 2;
    x = clamp(x, -half, half);
    y = clamp(y, -half, half);
    // Gentle drift, biased slightly inward so the field feels alive.
    let vx = (player.pos.x - x) * 0.05 * rng();
    let vy = (player.pos.y - y) * 0.05 * rng();
    // Meteor showers streak across with momentum.
    if (activeEvent === 'meteorShower') {
      const a = ang + Math.PI + (rng() - 0.5);
      vx += Math.cos(a) * 160;
      vy += Math.sin(a) * 160;
    }
    this.spawnAt(x, y, pool, gs, rng, sector, activeEvent, vx, vy, mods);
  }

  private spawnAt(
    x: number,
    y: number,
    pool: ObjectPool<CosmicObject>,
    gs: GameState,
    rng: () => number,
    sector: SectorDef,
    activeEvent: EventId | null,
    vx: number,
    vy: number,
    mods?: Modifiers,
  ): void {
    const kind = this.pickKind(gs, sector, activeEvent, mods);
    if (!kind) return;
    const o = pool.obtain();
    if (!o) return;
    initObject(o, OBJECTS[kind], x, y, vx, vy, rng);
  }

  private pickKind(
    gs: GameState,
    sector: SectorDef,
    activeEvent: EventId | null,
    mods?: Modifiers,
  ): ObjectKind | null {
    const d = gs.derived;
    const mass = gs.data.mass;
    const cands = this.candidates;
    const weights = this.weights;
    cands.length = 0;
    weights.length = 0;

    const rarityBoost = d.rarityBonus + (mods?.rarityBonus ?? 0);

    for (const kind of OBJECT_ORDER) {
      const def = OBJECTS[kind];
      const gate = def.unlockMass * (1 - d.unlockReduction);
      if (mass < gate) continue;

      let w = def.weight;
      // Sector emphasis.
      if (sector.emphasis.includes(kind)) w *= 2.2;
      // Rarity luck biases toward rarer bodies.
      if (def.rarity === 'rare') w *= 1 + rarityBoost * 2;
      else if (def.rarity === 'epic') w *= 1 + rarityBoost * 3;
      else if (def.rarity === 'legendary') w *= 1 + rarityBoost * 4;
      else if (def.rarity === 'uncommon') w *= 1 + rarityBoost;
      // Fade out tiers far below the player so the field stays meaningful.
      if (mass > def.mass * 120) w *= 0.12;
      else if (mass > def.mass * 40) w *= 0.5;
      // Event flavour.
      w *= eventWeight(activeEvent, kind);
      if (w <= 0) continue;
      cands.push(kind);
      weights.push(w);
    }
    if (cands.length === 0) return 'dust';

    let total = 0;
    for (let i = 0; i < weights.length; i++) total += weights[i]!;
    let r = Math.random() * total;
    for (let i = 0; i < cands.length; i++) {
      r -= weights[i]!;
      if (r <= 0) return cands[i]!;
    }
    return cands[cands.length - 1]!;
  }
}

/** Per-event spawn weight multipliers, flavouring the matter mix. */
function eventWeight(event: EventId | null, kind: ObjectKind): number {
  if (!event) return 1;
  switch (event) {
    case 'meteorShower':
      return kind === 'asteroid' || kind === 'micro' ? 3 : 0.6;
    case 'nebulaBloom':
      return kind === 'dust' || kind === 'gasGiant' ? 2.4 : 1;
    case 'solarCollapse':
      return kind === 'star' || kind === 'planet' ? 2.6 : 0.8;
    case 'galaxyDrift':
      return 1;
    case 'temporalDistortion':
      return 1.2;
    case 'universeTear':
      return kind === 'neutron' || kind === 'star' || kind === 'gasGiant' ? 2.2 : 1.1;
    default:
      return 1;
  }
}
