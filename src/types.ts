/* ============================================================================
   Shared type definitions for Event Horizon: Eat the Universe.
   ========================================================================== */

import type { Vec2 } from './utils/math';

/** The ten consumable matter classes, ordered by mass tier. */
export type ObjectKind =
  | 'dust'
  | 'micro'
  | 'asteroid'
  | 'satellite'
  | 'station'
  | 'moon'
  | 'planet'
  | 'gasGiant'
  | 'star'
  | 'neutron';

/** How long an object lingers in orbit before being consumed. */
export type OrbitTier = 'tiny' | 'medium' | 'large' | 'massive';

export type Rarity = 'common' | 'uncommon' | 'rare' | 'epic' | 'legendary';

export interface ObjectDef {
  kind: ObjectKind;
  name: string;
  /** Mass the player must meet/exceed to consume; also the spawn gate. */
  mass: number;
  /** Visual radius in world units. */
  radius: number;
  /** Base mass granted on consumption (before multipliers). */
  massValue: number;
  /** Base gravity-energy granted on consumption. */
  energyValue: number;
  orbitTier: OrbitTier;
  rarity: Rarity;
  /** Core / glow colours for procedural sprites. */
  color: string;
  glow: string;
  /** Relative spawn weight once unlocked. */
  weight: number;
  /** Player mass at which this object begins to spawn. */
  unlockMass: number;
}

export type ObjectState = 'idle' | 'attracted' | 'orbiting' | 'consumed';

/** Runtime cosmic object. Pooled — never allocate these in the hot loop. */
export interface CosmicObject {
  active: boolean;
  kind: ObjectKind;
  state: ObjectState;
  pos: Vec2;
  vel: Vec2;
  mass: number;
  radius: number;
  massValue: number;
  energyValue: number;
  orbitTier: OrbitTier;
  rarity: Rarity;
  color: string;
  glow: string;
  /** Orbit bookkeeping. */
  orbitAngle: number;
  orbitRadius: number;
  orbitTime: number;
  orbitDuration: number;
  /** Visual spin for rendering. */
  spin: number;
  spinSpeed: number;
  /** Birth time for fade-in. */
  age: number;
  /** Grid cell index cached for fast removal. */
  cell: number;
}

export type UpgradeCategory =
  | 'gravity'
  | 'mobility'
  | 'efficiency'
  | 'automation'
  | 'discovery'
  | 'utility';

export type Currency = 'mass' | 'energy';

export interface UpgradeDef {
  id: string;
  name: string;
  category: UpgradeCategory;
  description: string;
  currency: Currency;
  baseCost: number;
  costGrowth: number;
  maxLevel: number;
  /** Player mass required before the upgrade appears in the shop. */
  unlockMass: number;
  /** Short label describing the per-level effect, e.g. "+12% pull". */
  effectLabel: (level: number) => string;
}

export interface SectorDef {
  id: number;
  name: string;
  size: number;
  /** Mass needed to unlock travel to this sector. */
  unlockMass: number;
  tagline: string;
  /** Background tint hue shift (0..1). */
  tint: string;
  /** Object kinds emphasized in this sector's spawn pool. */
  emphasis: ObjectKind[];
}

export type EventId =
  | 'meteorShower'
  | 'solarCollapse'
  | 'nebulaBloom'
  | 'galaxyDrift'
  | 'temporalDistortion'
  | 'universeTear';

export interface CosmicEventDef {
  id: EventId;
  name: string;
  description: string;
  duration: number;
  /** Minimum player mass before this event can trigger. */
  unlockMass: number;
  color: string;
}

export interface CosmicLawDef {
  id: string;
  name: string;
  description: string;
  maxLevel: number;
  baseCost: number;
  costGrowth: number;
  effectLabel: (level: number) => string;
}

export interface AchievementDef {
  id: string;
  name: string;
  description: string;
  /** Returns true when unlocked, given the live game state. */
  check: (s: AchievementProbe) => boolean;
}

/** Read-only snapshot the achievement checks read from. */
export interface AchievementProbe {
  mass: number;
  energy: number;
  totalConsumed: number;
  consumedByKind: Record<ObjectKind, number>;
  sector: number;
  prestiges: number;
  cores: number;
  eventsTriggered: number;
  upgradesPurchased: number;
  playTime: number;
}

export interface NarrativeBeat {
  id: string;
  /** Triggered when player mass first crosses this threshold. */
  atMass: number;
  text: string;
}
