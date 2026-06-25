import type { SectorDef } from '../types';

/** Five sectors, unlocked naturally by growth. Content streams in-place. */
export const SECTORS: SectorDef[] = [
  {
    id: 0,
    name: 'Starter Nursery',
    size: 1500,
    unlockMass: 0,
    tagline: 'A quiet pocket of drifting dust.',
    tint: '#160c33',
    emphasis: ['dust', 'micro', 'asteroid'],
  },
  {
    id: 1,
    name: 'Outer Belt',
    size: 3000,
    unlockMass: 90,
    tagline: 'Derelict stations litter the dark.',
    tint: '#101a3a',
    emphasis: ['asteroid', 'satellite', 'station'],
  },
  {
    id: 2,
    name: 'Deep Space',
    size: 6000,
    unlockMass: 1900,
    tagline: 'Lonely moons and wandering worlds.',
    tint: '#0c1430',
    emphasis: ['station', 'moon', 'planet'],
  },
  {
    id: 3,
    name: 'The Nebula',
    size: 8000,
    unlockMass: 62000,
    tagline: 'Stellar nurseries blaze with newborn light.',
    tint: '#1c0e34',
    emphasis: ['planet', 'gasGiant', 'star'],
  },
  {
    id: 4,
    name: 'Singularity Zone',
    size: 12000,
    unlockMass: 470000,
    tagline: 'Where reality itself begins to fray.',
    tint: '#06030f',
    emphasis: ['gasGiant', 'star', 'neutron'],
  },
];

export function sectorForMass(mass: number): SectorDef {
  let best = SECTORS[0]!;
  for (const s of SECTORS) {
    if (mass >= s.unlockMass) best = s;
  }
  return best;
}

export function nextSector(currentId: number): SectorDef | null {
  return SECTORS[currentId + 1] ?? null;
}
