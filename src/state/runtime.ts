/**
 * Per-frame runtime modifiers produced by the active universe event and read by
 * the physics and spawn systems. Reset to neutral when no event is active.
 */
export interface Modifiers {
  pullMult: number;
  orbitSpeedMult: number;
  spawnMult: number;
  massMult: number;
  inwardDrift: number;
  rarityBonus: number;
}

export function neutralMods(): Modifiers {
  return {
    pullMult: 1,
    orbitSpeedMult: 1,
    spawnMult: 1,
    massMult: 1,
    inwardDrift: 0,
    rarityBonus: 0,
  };
}

export function resetMods(m: Modifiers): void {
  m.pullMult = 1;
  m.orbitSpeedMult = 1;
  m.spawnMult = 1;
  m.massMult = 1;
  m.inwardDrift = 0;
  m.rarityBonus = 0;
}
