import type { CosmicLawDef } from '../types';
import type { GameState } from '../state/GameState';
import { CONFIG } from '../config';

/** Cores awarded for a Big Crunch, from lifetime-best mass of this run. */
export function coresForPrestige(gs: GameState): number {
  if (gs.data.runBestMass < CONFIG.PRESTIGE_UNLOCK_MASS) return 0;
  const raw = Math.sqrt(gs.data.runBestMass / CONFIG.CORE_DIVISOR);
  return Math.max(1, Math.floor(raw * gs.derived.coreMult));
}

export function canPrestige(gs: GameState): boolean {
  return gs.data.runBestMass >= CONFIG.PRESTIGE_UNLOCK_MASS;
}

/** Perform the Big Crunch. Returns cores gained. Caller resets the world. */
export function performPrestige(gs: GameState): number {
  const cores = coresForPrestige(gs);
  if (cores <= 0) return 0;
  gs.data.cores += cores;
  gs.data.prestiges++;
  // Reset the run; cosmic laws, achievements, narrative and settings persist.
  gs.recompute(); // ensure startMassMult reflects current laws
  const startMass = 1 * gs.derived.startMassMult;
  gs.data.mass = startMass;
  gs.data.energy = 0;
  gs.data.upgrades = {};
  gs.data.sector = 0;
  gs.data.runBestMass = startMass;
  gs.recompute();
  gs.noteMass();
  return cores;
}

export function lawCost(def: CosmicLawDef, level: number): number {
  return Math.ceil(def.baseCost * Math.pow(def.costGrowth, level));
}

export function canAffordLaw(def: CosmicLawDef, gs: GameState): boolean {
  if (gs.law(def.id) >= def.maxLevel) return false;
  return gs.data.cores >= lawCost(def, gs.law(def.id));
}

export function buyLaw(def: CosmicLawDef, gs: GameState): boolean {
  if (!canAffordLaw(def, gs)) return false;
  const level = gs.law(def.id);
  gs.data.cores -= lawCost(def, level);
  gs.data.laws[def.id] = level + 1;
  gs.recompute();
  return true;
}
