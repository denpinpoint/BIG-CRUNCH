import type { UpgradeDef } from '../types';

/**
 * 44 upgrades across the six categories. Costs scale geometrically so there is
 * no runaway growth: each level costs `baseCost * costGrowth^level`, and the
 * per-level effects are deliberately sub-doubling. The four named idle systems
 * (Gravity Beacon, Mass Compressor, Dark Collector, Nebula Harvester) live in
 * the AUTOMATION category. Effect math lives in systems/UpgradeSystem.ts.
 */
export const UPGRADES: UpgradeDef[] = [
  // ----------------------------- GRAVITY ---------------------------------
  {
    id: 'gravRadius1', name: 'Gravity Well', category: 'gravity', currency: 'mass',
    description: 'Widen the radius that draws matter toward you.',
    baseCost: 8, costGrowth: 1.22, maxLevel: 30, unlockMass: 0,
    effectLabel: (l) => `+${(l * 7).toFixed(0)}% gravity radius`,
  },
  {
    id: 'gravPull1', name: 'Pull Strength', category: 'gravity', currency: 'mass',
    description: 'Increase the force tugging objects inward.',
    baseCost: 12, costGrowth: 1.24, maxLevel: 30, unlockMass: 4,
    effectLabel: (l) => `+${(l * 9).toFixed(0)}% pull force`,
  },
  {
    id: 'gravRadius2', name: 'Event Horizon Expansion', category: 'gravity', currency: 'energy',
    description: 'A permanent flat expansion of your horizon.',
    baseCost: 4, costGrowth: 1.5, maxLevel: 18, unlockMass: 120,
    effectLabel: (l) => `+${(l * 24).toFixed(0)} radius`,
  },
  {
    id: 'gravFalloff', name: 'Deep Reach', category: 'gravity', currency: 'energy',
    description: 'Distant matter feels your pull almost as strongly as near.',
    baseCost: 8, costGrowth: 1.6, maxLevel: 10, unlockMass: 800,
    effectLabel: (l) => `${(l * 6).toFixed(0)}% flatter falloff`,
  },
  {
    id: 'attractTiny', name: 'Whisper Pull', category: 'gravity', currency: 'mass',
    description: 'Tiny motes are drawn from far across the sector.',
    baseCost: 40, costGrowth: 1.3, maxLevel: 12, unlockMass: 30,
    effectLabel: (l) => `+${(l * 18).toFixed(0)}% reach on small bodies`,
  },

  // ----------------------------- MOBILITY --------------------------------
  {
    id: 'speed1', name: 'Thrust', category: 'mobility', currency: 'mass',
    description: 'Move faster through the void.',
    baseCost: 10, costGrowth: 1.23, maxLevel: 25, unlockMass: 0,
    effectLabel: (l) => `+${(l * 7).toFixed(0)}% move speed`,
  },
  {
    id: 'moveAccel', name: 'Reflexes', category: 'mobility', currency: 'mass',
    description: 'Reach top speed and change direction faster.',
    baseCost: 16, costGrowth: 1.26, maxLevel: 18, unlockMass: 20,
    effectLabel: (l) => `+${(l * 10).toFixed(0)}% acceleration`,
  },
  {
    id: 'speed2', name: 'Inertial Dampers', category: 'mobility', currency: 'energy',
    description: 'Trim drift for tight, responsive movement.',
    baseCost: 5, costGrowth: 1.5, maxLevel: 14, unlockMass: 200,
    effectLabel: (l) => `+${(l * 6).toFixed(0)}% control`,
  },
  {
    id: 'speed3', name: 'Warp Drift', category: 'mobility', currency: 'energy',
    description: 'Raise your absolute top speed.',
    baseCost: 10, costGrowth: 1.55, maxLevel: 12, unlockMass: 2500,
    effectLabel: (l) => `+${(l * 8).toFixed(0)}% top speed`,
  },

  // ---------------------------- EFFICIENCY -------------------------------
  {
    id: 'consume1', name: 'Digestion', category: 'efficiency', currency: 'mass',
    description: 'Pull captured matter into the core faster.',
    baseCost: 14, costGrowth: 1.24, maxLevel: 25, unlockMass: 6,
    effectLabel: (l) => `+${(l * 11).toFixed(0)}% consume speed`,
  },
  {
    id: 'orbitCapacity', name: 'Accretion Disk', category: 'efficiency', currency: 'mass',
    description: 'Hold more bodies in orbit at once.',
    baseCost: 30, costGrowth: 1.35, maxLevel: 18, unlockMass: 40,
    effectLabel: (l) => `+${l * 2} orbit slots`,
  },
  {
    id: 'consume2', name: 'Crush Depth', category: 'efficiency', currency: 'energy',
    description: 'Collapse orbiting bodies more aggressively.',
    baseCost: 6, costGrowth: 1.5, maxLevel: 15, unlockMass: 300,
    effectLabel: (l) => `-${Math.round((1 - Math.pow(0.94, l)) * 100)}% orbit time`,
  },
  {
    id: 'orbitCapacity2', name: 'Halo', category: 'efficiency', currency: 'energy',
    description: 'A second ring of captured matter.',
    baseCost: 12, costGrowth: 1.55, maxLevel: 12, unlockMass: 5000,
    effectLabel: (l) => `+${l * 3} orbit slots`,
  },
  {
    id: 'critConsume', name: 'Critical Mass', category: 'efficiency', currency: 'energy',
    description: 'Chance for a consumption to count double.',
    baseCost: 15, costGrowth: 1.6, maxLevel: 12, unlockMass: 6000,
    effectLabel: (l) => `${(l * 3).toFixed(0)}% double chance`,
  },

  // ---------------------------- AUTOMATION -------------------------------
  {
    id: 'beacon', name: 'Gravity Beacon', category: 'automation', currency: 'mass',
    description: 'Generates a steady trickle of mass on its own.',
    baseCost: 25, costGrowth: 1.28, maxLevel: 30, unlockMass: 12,
    effectLabel: (l) => `+${(l * 0.4).toFixed(1)} mass/s`,
  },
  {
    id: 'compressor', name: 'Mass Compressor', category: 'automation', currency: 'energy',
    description: 'Passive mass that scales with the square root of your size.',
    baseCost: 5, costGrowth: 1.5, maxLevel: 25, unlockMass: 150,
    effectLabel: (l) => `+${(l * 0.04).toFixed(2)}·√mass /s`,
  },
  {
    id: 'darkCollector', name: 'Dark Collector', category: 'automation', currency: 'energy',
    description: 'Harvests gravity energy from the vacuum.',
    baseCost: 6, costGrowth: 1.52, maxLevel: 25, unlockMass: 250,
    effectLabel: (l) => `+${(l * 0.25).toFixed(2)} energy/s`,
  },
  {
    id: 'nebulaHarvester', name: 'Nebula Harvester', category: 'automation', currency: 'energy',
    description: 'Draws both mass and energy from ambient gas.',
    baseCost: 14, costGrowth: 1.58, maxLevel: 20, unlockMass: 4000,
    effectLabel: (l) => `+${(l * 1).toFixed(0)} mass & +${(l * 0.4).toFixed(1)} energy/s`,
  },
  {
    id: 'passiveMult', name: 'Singularity Engine', category: 'automation', currency: 'energy',
    description: 'Amplifies all passive generation.',
    baseCost: 20, costGrowth: 1.62, maxLevel: 18, unlockMass: 9000,
    effectLabel: (l) => `+${(l * 10).toFixed(0)}% passive output`,
  },
  {
    id: 'autoConsume', name: 'Auto-Accretion', category: 'automation', currency: 'mass',
    description: 'Nearby small bodies are seized automatically.',
    baseCost: 120, costGrowth: 1.4, maxLevel: 10, unlockMass: 500,
    effectLabel: (l) => `auto-pull within ${(l * 10).toFixed(0)}% of horizon`,
  },
  {
    id: 'offlineEff', name: 'Stasis Field', category: 'automation', currency: 'energy',
    description: 'Retain more progress while you are away (max 8h).',
    baseCost: 10, costGrowth: 1.5, maxLevel: 10, unlockMass: 1200,
    effectLabel: (l) => `${Math.min(100, 50 + l * 5).toFixed(0)}% offline rate`,
  },

  // ---------------------------- DISCOVERY --------------------------------
  {
    id: 'spawnRate1', name: 'Matter Influx', category: 'discovery', currency: 'mass',
    description: 'More matter drifts into the sector.',
    baseCost: 18, costGrowth: 1.25, maxLevel: 25, unlockMass: 8,
    effectLabel: (l) => `+${(l * 7).toFixed(0)}% spawn rate`,
  },
  {
    id: 'densityCap', name: 'Saturation', category: 'discovery', currency: 'mass',
    description: 'Allow more matter to exist at once.',
    baseCost: 60, costGrowth: 1.3, maxLevel: 18, unlockMass: 60,
    effectLabel: (l) => `+${l * 12} max bodies`,
  },
  {
    id: 'spawnRate2', name: 'Cosmic Tide', category: 'discovery', currency: 'energy',
    description: 'The universe crowds toward your hunger.',
    baseCost: 7, costGrowth: 1.52, maxLevel: 14, unlockMass: 700,
    effectLabel: (l) => `+${(l * 8).toFixed(0)}% spawn rate`,
  },
  {
    id: 'rarityLuck', name: 'Improbability', category: 'discovery', currency: 'energy',
    description: 'Rare and valuable bodies appear more often.',
    baseCost: 9, costGrowth: 1.55, maxLevel: 12, unlockMass: 900,
    effectLabel: (l) => `+${(l * 6).toFixed(0)}% rare odds`,
  },
  {
    id: 'pioneer', name: 'Pioneer', category: 'discovery', currency: 'energy',
    description: 'Unlock larger classes of matter at lower mass.',
    baseCost: 18, costGrowth: 1.7, maxLevel: 8, unlockMass: 3000,
    effectLabel: (l) => `-${(l * 5).toFixed(0)}% unlock thresholds`,
  },
  {
    id: 'eventBoost', name: 'Cataclysm Affinity', category: 'discovery', currency: 'energy',
    description: 'Universe events last longer and hit harder.',
    baseCost: 16, costGrowth: 1.6, maxLevel: 10, unlockMass: 6000,
    effectLabel: (l) => `+${(l * 10).toFixed(0)}% event power`,
  },

  // ----------------------------- UTILITY ---------------------------------
  {
    id: 'massGain1', name: 'Density', category: 'utility', currency: 'mass',
    description: 'Every body you eat yields more mass.',
    baseCost: 20, costGrowth: 1.27, maxLevel: 30, unlockMass: 5,
    effectLabel: (l) => `+${(l * 6).toFixed(0)}% mass value`,
  },
  {
    id: 'energyGain1', name: 'Charge', category: 'utility', currency: 'mass',
    description: 'Extract more gravity energy per consumption.',
    baseCost: 35, costGrowth: 1.3, maxLevel: 25, unlockMass: 50,
    effectLabel: (l) => `+${(l * 8).toFixed(0)}% energy value`,
  },
  {
    id: 'comboWindow', name: 'Momentum', category: 'utility', currency: 'mass',
    description: 'Hold your feeding combo for longer.',
    baseCost: 45, costGrowth: 1.32, maxLevel: 15, unlockMass: 80,
    effectLabel: (l) => `+${(l * 0.25).toFixed(2)}s combo window`,
  },
  {
    id: 'comboMult', name: 'Chain Reaction', category: 'utility', currency: 'energy',
    description: 'Raise the ceiling on your combo multiplier.',
    baseCost: 8, costGrowth: 1.55, maxLevel: 14, unlockMass: 600,
    effectLabel: (l) => `combo cap +${(l * 0.5).toFixed(1)}×`,
  },
  {
    id: 'massGain2', name: 'Compression', category: 'utility', currency: 'energy',
    description: 'A potent multiplier to all mass gained.',
    baseCost: 10, costGrowth: 1.58, maxLevel: 18, unlockMass: 1500,
    effectLabel: (l) => `+${(l * 8).toFixed(0)}% mass value`,
  },
  {
    id: 'massValueBig', name: 'Apex Predator', category: 'utility', currency: 'energy',
    description: 'Bonus mass from the largest bodies you devour.',
    baseCost: 14, costGrowth: 1.6, maxLevel: 12, unlockMass: 12000,
    effectLabel: (l) => `+${(l * 10).toFixed(0)}% from giants`,
  },
  {
    id: 'shockwave', name: 'Collapse Pulse', category: 'utility', currency: 'mass',
    description: 'Devouring big bodies emits a gravity shock that yanks the field inward.',
    baseCost: 200, costGrowth: 1.45, maxLevel: 10, unlockMass: 900,
    effectLabel: (l) => `pulse strength ${(l * 12).toFixed(0)}%`,
  },
  {
    id: 'critPower', name: 'Annihilation', category: 'utility', currency: 'energy',
    description: 'Critical consumptions yield even more.',
    baseCost: 18, costGrowth: 1.62, maxLevel: 10, unlockMass: 15000,
    effectLabel: (l) => `crit gives +${(l * 25).toFixed(0)}%`,
  },
  {
    id: 'hawking', name: 'Hawking Radiation', category: 'utility', currency: 'mass',
    description: 'Your event horizon slowly radiates gravity energy.',
    baseCost: 80, costGrowth: 1.34, maxLevel: 15, unlockMass: 200,
    effectLabel: (l) => `+${(l * 0.05).toFixed(2)} energy/s`,
  },
  {
    id: 'transmute', name: 'Transmutation', category: 'utility', currency: 'energy',
    description: 'A fraction of mass overflow is converted to energy.',
    baseCost: 22, costGrowth: 1.6, maxLevel: 10, unlockMass: 20000,
    effectLabel: (l) => `${(l * 0.5).toFixed(1)}% mass → energy`,
  },
  {
    id: 'feedingFrenzy', name: 'Feeding Frenzy', category: 'utility', currency: 'energy',
    description: 'Higher combos summon matter even faster.',
    baseCost: 20, costGrowth: 1.65, maxLevel: 8, unlockMass: 25000,
    effectLabel: (l) => `+${(l * 5).toFixed(0)}% spawn at high combo`,
  },
  // A few more mass sinks to keep early game flowing
  {
    id: 'gravPull3', name: 'Tidal Lock', category: 'gravity', currency: 'mass',
    description: 'Heavier bodies are reeled in without slipping away.',
    baseCost: 90, costGrowth: 1.33, maxLevel: 16, unlockMass: 150,
    effectLabel: (l) => `+${(l * 6).toFixed(0)}% pull on large bodies`,
  },
  {
    id: 'consume3', name: 'Spaghettification', category: 'efficiency', currency: 'mass',
    description: 'Stretch and devour massive bodies far faster.',
    baseCost: 110, costGrowth: 1.34, maxLevel: 16, unlockMass: 200,
    effectLabel: (l) => `-${Math.round((1 - Math.pow(0.95, l)) * 100)}% giant orbit time`,
  },
  {
    id: 'beaconBoost', name: 'Resonant Beacon', category: 'automation', currency: 'mass',
    description: 'Supercharges the Gravity Beacon trickle.',
    baseCost: 300, costGrowth: 1.4, maxLevel: 14, unlockMass: 1000,
    effectLabel: (l) => `beacon +${(l * 15).toFixed(0)}%`,
  },
  {
    id: 'quantumFoam', name: 'Quantum Foam', category: 'automation', currency: 'mass',
    description: 'Energy bubbles from spacetime regardless of size.',
    baseCost: 260, costGrowth: 1.42, maxLevel: 16, unlockMass: 600,
    effectLabel: (l) => `+${(l * 0.08).toFixed(2)} energy/s`,
  },
  {
    id: 'scan', name: 'Long-Range Scan', category: 'discovery', currency: 'mass',
    description: 'Charts the sector — improves matter variety and density.',
    baseCost: 150, costGrowth: 1.36, maxLevel: 12, unlockMass: 300,
    effectLabel: (l) => `+${l * 8} max bodies`,
  },
];

export function upgradeById(id: string): UpgradeDef | undefined {
  return UPGRADES.find((u) => u.id === id);
}
