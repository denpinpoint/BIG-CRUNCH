import type { CosmicEventDef, EventId } from '../types';

/**
 * Universe events trigger automatically on a cadence. Each one changes spawn
 * patterns, visuals and feel for its duration. Effects are applied by the
 * EventSystem reading the active event id.
 */
export const EVENTS: Record<EventId, CosmicEventDef> = {
  meteorShower: {
    id: 'meteorShower',
    name: 'Meteor Shower',
    description: 'A torrent of asteroids streaks across the sector.',
    duration: 18,
    unlockMass: 8,
    color: '#c0a070',
  },
  nebulaBloom: {
    id: 'nebulaBloom',
    name: 'Nebula Bloom',
    description: 'Drifting gas condenses — mass gains surge.',
    duration: 22,
    unlockMass: 200,
    color: '#9a8cff',
  },
  solarCollapse: {
    id: 'solarCollapse',
    name: 'Solar Collapse',
    description: 'A dying star scatters dense matter outward.',
    duration: 16,
    unlockMass: 4000,
    color: '#ffd166',
  },
  galaxyDrift: {
    id: 'galaxyDrift',
    name: 'Galaxy Drift',
    description: 'Tidal currents drag everything toward you.',
    duration: 20,
    unlockMass: 30000,
    color: '#54e6ff',
  },
  temporalDistortion: {
    id: 'temporalDistortion',
    name: 'Temporal Distortion',
    description: 'Time dilates — orbits collapse almost instantly.',
    duration: 15,
    unlockMass: 120000,
    color: '#7df0ff',
  },
  universeTear: {
    id: 'universeTear',
    name: 'Universe Tear',
    description: 'Reality splits. Everything pours through the rift.',
    duration: 14,
    unlockMass: 500000,
    color: '#ff5d73',
  },
};

export const EVENT_ORDER: EventId[] = [
  'meteorShower',
  'nebulaBloom',
  'solarCollapse',
  'galaxyDrift',
  'temporalDistortion',
  'universeTear',
];
