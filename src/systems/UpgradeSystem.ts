import type { UpgradeDef } from '../types';
import type { GameState } from '../state/GameState';

/** Geometric cost curve — guarantees diminishing returns, no runaway growth. */
export function upgradeCost(def: UpgradeDef, level: number): number {
  return Math.ceil(def.baseCost * Math.pow(def.costGrowth, level));
}

export function isMaxed(def: UpgradeDef, gs: GameState): boolean {
  return gs.lvl(def.id) >= def.maxLevel;
}

export function canAfford(def: UpgradeDef, gs: GameState): boolean {
  if (isMaxed(def, gs)) return false;
  const cost = upgradeCost(def, gs.lvl(def.id));
  const wallet = def.currency === 'mass' ? gs.data.mass : gs.data.energy;
  return wallet >= cost;
}

/** Attempt to buy one level. Returns the cost paid, or 0 if it failed. */
export function buyUpgrade(def: UpgradeDef, gs: GameState): number {
  if (!canAfford(def, gs)) return 0;
  const level = gs.lvl(def.id);
  const cost = upgradeCost(def, level);
  if (def.currency === 'mass') gs.data.mass -= cost;
  else gs.data.energy -= cost;
  gs.data.upgrades[def.id] = level + 1;
  gs.data.stats.upgradesPurchased++;
  gs.recompute();
  return cost;
}

/** True if the upgrade should be visible in the shop given current progress. */
export function isUnlocked(def: UpgradeDef, gs: GameState): boolean {
  return gs.data.stats.bestMass >= def.unlockMass || gs.lvl(def.id) > 0;
}
