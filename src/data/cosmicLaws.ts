import type { CosmicLawDef } from '../types';

/**
 * Cosmic Laws are the prestige ("Big Crunch") upgrade tree. They persist across
 * resets and are purchased with Singularity Cores. Each provides a permanent,
 * compounding multiplier so successive runs feel faster and reach further.
 */
export const COSMIC_LAWS: CosmicLawDef[] = [
  {
    id: 'massMult',
    name: 'Mass Multipliers',
    description: 'All mass gained is permanently amplified.',
    maxLevel: 20,
    baseCost: 1,
    costGrowth: 1.55,
    effectLabel: (l) => `+${l * 15}% mass gain`,
  },
  {
    id: 'orbitFaster',
    name: 'Orbit Faster',
    description: 'Captured bodies collapse into you more quickly.',
    maxLevel: 12,
    baseCost: 2,
    costGrowth: 1.6,
    effectLabel: (l) => `-${Math.round((1 - Math.pow(0.92, l)) * 100)}% orbit time`,
  },
  {
    id: 'timeWarp',
    name: 'Time Warp',
    description: 'Passive and idle generation run faster.',
    maxLevel: 15,
    baseCost: 2,
    costGrowth: 1.62,
    effectLabel: (l) => `+${l * 12}% passive rate`,
  },
  {
    id: 'spawnDensity',
    name: 'Higher Spawn Density',
    description: 'The universe crowds in around you.',
    maxLevel: 12,
    baseCost: 3,
    costGrowth: 1.7,
    effectLabel: (l) => `+${l * 12}% matter density`,
  },
  {
    id: 'gravitas',
    name: 'Eternal Gravitas',
    description: 'A permanent boost to your gravitational reach.',
    maxLevel: 12,
    baseCost: 3,
    costGrowth: 1.66,
    effectLabel: (l) => `+${l * 10}% gravity radius`,
  },
  {
    id: 'coreAffinity',
    name: 'Core Affinity',
    description: 'Each Big Crunch yields more Singularity Cores.',
    maxLevel: 10,
    baseCost: 5,
    costGrowth: 1.85,
    effectLabel: (l) => `+${l * 10}% cores earned`,
  },
  {
    id: 'voidSeed',
    name: 'Void Seed',
    description: 'Begin every new universe already grown.',
    maxLevel: 10,
    baseCost: 4,
    costGrowth: 1.9,
    effectLabel: (l) => `start at ${(1 + l * 4).toFixed(0)}× base mass`,
  },
];

export function lawById(id: string): CosmicLawDef | undefined {
  return COSMIC_LAWS.find((l) => l.id === id);
}
