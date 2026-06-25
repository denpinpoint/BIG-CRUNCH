import type { ObjectKind } from '../types';
import { CONFIG, SAVE_VERSION } from '../config';

/** Player-facing options. Volumes are 0..1. */
export interface Settings {
  master: number;
  music: number;
  sfx: number;
  muted: boolean;
  reducedMotion: boolean;
  showMinimap: boolean;
}

export interface Stats {
  totalConsumed: number;
  consumedByKind: Record<ObjectKind, number>;
  eventsTriggered: number;
  upgradesPurchased: number;
  playTime: number;
  bestMass: number;
}

/** The full serializable snapshot persisted to IndexedDB. */
export interface SaveData {
  version: number;
  mass: number;
  energy: number;
  cores: number;
  prestiges: number;
  /** Highest mass reached this run, drives prestige core payout. */
  runBestMass: number;
  sector: number;
  upgrades: Record<string, number>;
  laws: Record<string, number>;
  achievements: string[];
  narrativeSeen: string[];
  stats: Stats;
  settings: Settings;
  lastSaved: number;
}

/** Every gameplay multiplier resolved from upgrade + cosmic-law levels. */
export interface Derived {
  gravityRadiusMult: number;
  gravityRadiusFlat: number;
  pullMult: number;
  largePullMult: number;
  pullFalloffReduction: number;
  tinyReachMult: number;

  moveSpeedMult: number;
  accelMult: number;
  topSpeedMult: number;

  consumeSpeedMult: number;
  orbitCapacity: number;
  orbitTimeMult: number;
  giantOrbitTimeMult: number;

  massValueMult: number;
  energyValueMult: number;
  massValueBigPct: number;
  comboWindow: number;
  comboCap: number;

  critChance: number;
  critPower: number; // extra multiplier on a crit (1.0 = +100%)

  // Passive generation (per second, before passiveMult).
  beaconFlat: number;
  compressorPct: number; // fraction of current mass / s
  darkEnergyFlat: number;
  nebulaMass: number;
  nebulaEnergy: number;
  quantumEnergyFlat: number;
  hawkingEnergyFlat: number;
  passiveMult: number;
  transmuteFrac: number;

  spawnRateMult: number;
  maxObjects: number;
  rarityBonus: number;
  unlockReduction: number;
  feedingFrenzyPct: number;
  eventPowerMult: number;

  autoConsumeFrac: number;
  shockwaveStrength: number;
  offlineRate: number;

  coreMult: number;
  startMassMult: number;
}

const EMPTY_KIND_COUNTS = (): Record<ObjectKind, number> => ({
  dust: 0, micro: 0, asteroid: 0, satellite: 0, station: 0,
  moon: 0, planet: 0, gasGiant: 0, star: 0, neutron: 0,
});

export const DEFAULT_SETTINGS: Settings = {
  master: 0.8,
  music: 0.6,
  sfx: 0.9,
  muted: false,
  reducedMotion: false,
  showMinimap: true,
};

export function newSaveData(): SaveData {
  return {
    version: SAVE_VERSION,
    mass: 1,
    energy: 0,
    cores: 0,
    prestiges: 0,
    runBestMass: 1,
    sector: 0,
    upgrades: {},
    laws: {},
    achievements: [],
    narrativeSeen: [],
    stats: {
      totalConsumed: 0,
      consumedByKind: EMPTY_KIND_COUNTS(),
      eventsTriggered: 0,
      upgradesPurchased: 0,
      playTime: 0,
      bestMass: 1,
    },
    settings: { ...DEFAULT_SETTINGS },
    lastSaved: Date.now(),
  };
}

/**
 * Central game state. Holds the persistent `data` plus the recomputed `derived`
 * multipliers and a small amount of transient run state (combo). Systems read
 * derived numbers; UI mutates levels then calls recompute().
 */
export class GameState {
  data: SaveData;
  derived!: Derived;

  // Transient run state (not persisted).
  combo = 1;
  comboTimer = 0;
  comboCount = 0;

  constructor(data?: SaveData) {
    this.data = data ?? newSaveData();
    this.recompute();
  }

  lvl(id: string): number {
    return this.data.upgrades[id] ?? 0;
  }
  law(id: string): number {
    return this.data.laws[id] ?? 0;
  }

  recompute(): void {
    const u = (id: string) => this.lvl(id);
    const L = (id: string) => this.law(id);

    const lawMassMult = 1 + 0.15 * L('massMult');
    const massPct = 1 + 0.06 * u('massGain1') + 0.08 * u('massGain2');

    let orbitTimeMult = Math.pow(0.94, u('consume2')) * Math.pow(0.92, L('orbitFaster'));
    const giantOrbitTimeMult = Math.pow(0.95, u('consume3'));

    let passiveMult = 1 + 0.1 * u('passiveMult') + 0.12 * L('timeWarp');

    const d: Derived = {
      gravityRadiusMult: 1 + 0.07 * u('gravRadius1') + 0.1 * L('gravitas'),
      gravityRadiusFlat: 24 * u('gravRadius2'),
      pullMult: 1 + 0.09 * u('gravPull1'),
      largePullMult: 1 + 0.06 * u('gravPull3'),
      pullFalloffReduction: Math.min(0.7, 0.06 * u('gravFalloff')),
      tinyReachMult: 1 + 0.18 * u('attractTiny'),

      moveSpeedMult: 1 + 0.07 * u('speed1'),
      accelMult: 1 + 0.1 * u('moveAccel') + 0.06 * u('speed2'),
      topSpeedMult: 1 + 0.08 * u('speed3'),

      consumeSpeedMult: 1 + 0.11 * u('consume1'),
      orbitCapacity: CONFIG.BASE_ORBIT_CAPACITY + 2 * u('orbitCapacity') + 3 * u('orbitCapacity2'),
      orbitTimeMult,
      giantOrbitTimeMult,

      massValueMult: massPct * lawMassMult,
      energyValueMult: 1 + 0.08 * u('energyGain1'),
      massValueBigPct: 0.1 * u('massValueBig'),
      comboWindow: CONFIG.BASE_COMBO_WINDOW + 0.25 * u('comboWindow'),
      comboCap: CONFIG.COMBO_BASE_CAP + 0.5 * u('comboMult'),

      critChance: Math.min(0.75, 0.03 * u('critConsume')),
      critPower: 1 + 0.25 * u('critPower'),

      beaconFlat: 0.4 * u('beacon') * (1 + 0.15 * u('beaconBoost')),
      compressorPct: 0.0012 * u('compressor'),
      darkEnergyFlat: 0.25 * u('darkCollector'),
      nebulaMass: 1 * u('nebulaHarvester'),
      nebulaEnergy: 0.4 * u('nebulaHarvester'),
      quantumEnergyFlat: 0.08 * u('quantumFoam'),
      hawkingEnergyFlat: 0.05 * u('hawking'),
      passiveMult,
      transmuteFrac: 0.005 * u('transmute'),

      spawnRateMult: 1 + 0.07 * u('spawnRate1') + 0.08 * u('spawnRate2') + 0.12 * L('spawnDensity'),
      maxObjects: Math.min(
        CONFIG.HARD_MAX_OBJECTS,
        CONFIG.BASE_MAX_OBJECTS + 12 * u('densityCap') + 8 * u('scan'),
      ),
      rarityBonus: 0.06 * u('rarityLuck'),
      unlockReduction: Math.min(0.6, 0.05 * u('pioneer')),
      feedingFrenzyPct: 0.05 * u('feedingFrenzy'),
      eventPowerMult: 1 + 0.1 * u('eventBoost'),

      autoConsumeFrac: Math.min(1, 0.1 * u('autoConsume')),
      shockwaveStrength: 0.12 * u('shockwave'),
      offlineRate: u('offlineEff') > 0 ? Math.min(1, (50 + 5 * u('offlineEff')) / 100) : 0.5,

      coreMult: 1 + 0.1 * L('coreAffinity'),
      startMassMult: 1 + 4 * L('voidSeed'),
    };

    this.derived = d;
  }

  /** Lifetime-best mass bookkeeping. */
  noteMass(): void {
    if (this.data.mass > this.data.runBestMass) this.data.runBestMass = this.data.mass;
    if (this.data.mass > this.data.stats.bestMass) this.data.stats.bestMass = this.data.mass;
  }
}
