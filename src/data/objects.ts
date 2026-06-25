import type { ObjectDef, ObjectKind } from '../types';

/**
 * The matter ladder. Each tier requires the player to meet/exceed its mass to
 * consume it. `massValue` is intentionally a multiple of `mass` so devouring
 * larger bodies accelerates growth — while the consumption gate keeps the
 * ascent ordered. Tuned so the first minute is explosive and prestige lands
 * around the 60–90 minute mark.
 */
export const OBJECTS: Record<ObjectKind, ObjectDef> = {
  dust: {
    kind: 'dust',
    name: 'Stardust',
    mass: 0.3,
    radius: 5,
    massValue: 0.6,
    energyValue: 0,
    orbitTier: 'tiny',
    rarity: 'common',
    color: '#8a7fb0',
    glow: '#6c5fd0',
    weight: 100,
    unlockMass: 0,
  },
  micro: {
    kind: 'micro',
    name: 'Micro Asteroid',
    mass: 1.2,
    radius: 8,
    massValue: 2.0,
    energyValue: 0,
    orbitTier: 'tiny',
    rarity: 'common',
    color: '#9a8c78',
    glow: '#c0a070',
    weight: 78,
    unlockMass: 0,
  },
  asteroid: {
    kind: 'asteroid',
    name: 'Asteroid',
    mass: 6,
    radius: 14,
    massValue: 10,
    energyValue: 0.3,
    orbitTier: 'medium',
    rarity: 'common',
    color: '#8c8a96',
    glow: '#b6b6cc',
    weight: 56,
    unlockMass: 3,
  },
  satellite: {
    kind: 'satellite',
    name: 'Satellite',
    mass: 28,
    radius: 18,
    massValue: 46,
    energyValue: 1.2,
    orbitTier: 'medium',
    rarity: 'uncommon',
    color: '#aee8ff',
    glow: '#54e6ff',
    weight: 40,
    unlockMass: 15,
  },
  station: {
    kind: 'station',
    name: 'Orbital Station',
    mass: 130,
    radius: 26,
    massValue: 220,
    energyValue: 5,
    orbitTier: 'large',
    rarity: 'uncommon',
    color: '#d8f4ff',
    glow: '#54e6ff',
    weight: 28,
    unlockMass: 70,
  },
  moon: {
    kind: 'moon',
    name: 'Moon',
    mass: 650,
    radius: 40,
    massValue: 1200,
    energyValue: 22,
    orbitTier: 'large',
    rarity: 'rare',
    color: '#cfc9e6',
    glow: '#9a8cff',
    weight: 20,
    unlockMass: 360,
  },
  planet: {
    kind: 'planet',
    name: 'Planet',
    mass: 3400,
    radius: 62,
    massValue: 6600,
    energyValue: 110,
    orbitTier: 'massive',
    rarity: 'rare',
    color: '#5fd0e0',
    glow: '#54e6ff',
    weight: 14,
    unlockMass: 1900,
  },
  gasGiant: {
    kind: 'gasGiant',
    name: 'Gas Giant',
    mass: 19000,
    radius: 96,
    massValue: 40000,
    energyValue: 720,
    orbitTier: 'massive',
    rarity: 'epic',
    color: '#ffcf8a',
    glow: '#ffd166',
    weight: 9,
    unlockMass: 10500,
  },
  star: {
    kind: 'star',
    name: 'Star',
    mass: 110000,
    radius: 150,
    massValue: 260000,
    energyValue: 6000,
    orbitTier: 'massive',
    rarity: 'epic',
    color: '#fff4d0',
    glow: '#ffd166',
    weight: 5,
    unlockMass: 62000,
  },
  neutron: {
    kind: 'neutron',
    name: 'Neutron Star',
    mass: 850000,
    radius: 92,
    massValue: 2300000,
    energyValue: 72000,
    orbitTier: 'massive',
    rarity: 'legendary',
    color: '#eaffff',
    glow: '#7df0ff',
    weight: 2.5,
    unlockMass: 470000,
  },
};

export const OBJECT_ORDER: ObjectKind[] = [
  'dust',
  'micro',
  'asteroid',
  'satellite',
  'station',
  'moon',
  'planet',
  'gasGiant',
  'star',
  'neutron',
];

/** Orbit lingering durations (seconds) by tier, per the design spec. */
export const ORBIT_DURATIONS: Record<string, number> = {
  tiny: 0,
  medium: 1,
  large: 3,
  massive: 6,
};

/** The next still-locked object kind for "next unlock" UI hints. */
export function nextLockedObject(mass: number): ObjectDef | null {
  for (const kind of OBJECT_ORDER) {
    const def = OBJECTS[kind];
    if (mass < def.unlockMass) return def;
  }
  return null;
}
