import type { CosmicObject, ObjectDef } from '../types';

export function makeCosmicObject(): CosmicObject {
  return {
    active: false,
    kind: 'dust',
    state: 'idle',
    pos: { x: 0, y: 0 },
    vel: { x: 0, y: 0 },
    mass: 0,
    radius: 0,
    massValue: 0,
    energyValue: 0,
    orbitTier: 'tiny',
    rarity: 'common',
    color: '#fff',
    glow: '#fff',
    orbitAngle: 0,
    orbitRadius: 0,
    orbitTime: 0,
    orbitDuration: 0,
    spin: 0,
    spinSpeed: 0,
    age: 0,
    cell: -1,
  };
}

/** Initialise a pooled object from its definition at a world position. */
export function initObject(
  o: CosmicObject,
  def: ObjectDef,
  x: number,
  y: number,
  vx: number,
  vy: number,
  rng: () => number,
): void {
  o.kind = def.kind;
  o.state = 'idle';
  o.pos.x = x;
  o.pos.y = y;
  o.vel.x = vx;
  o.vel.y = vy;
  o.mass = def.mass;
  o.radius = def.radius;
  o.massValue = def.massValue;
  o.energyValue = def.energyValue;
  o.orbitTier = def.orbitTier;
  o.rarity = def.rarity;
  o.color = def.color;
  o.glow = def.glow;
  o.orbitAngle = 0;
  o.orbitRadius = 0;
  o.orbitTime = 0;
  o.orbitDuration = 0;
  o.spin = rng() * Math.PI * 2;
  o.spinSpeed = (rng() - 0.5) * 1.4;
  o.age = 0;
}
