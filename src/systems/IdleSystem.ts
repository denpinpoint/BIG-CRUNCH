import type { GameState } from '../state/GameState';
import { CONFIG } from '../config';

export interface OfflineReport {
  seconds: number;
  mass: number;
  energy: number;
}

/**
 * Passive generation (the four idle engines) plus offline progress. Rates are
 * derived from upgrade levels; offline gains are capped at 8 hours and scaled by
 * the Stasis Field efficiency.
 */
export class IdleSystem {
  massRate(gs: GameState): number {
    const d = gs.derived;
    // Compressor scales with √mass — meaningful at scale but sub-exponential, so
    // mass can never run away on idle alone (a flat %-of-mass term would).
    const compressor = d.compressorPct * Math.sqrt(gs.data.mass);
    const base = d.beaconFlat + d.nebulaMass + compressor;
    return base * d.passiveMult;
  }

  energyRate(gs: GameState): number {
    const d = gs.derived;
    const base = d.darkEnergyFlat + d.nebulaEnergy + d.quantumEnergyFlat + d.hawkingEnergyFlat;
    return base * d.passiveMult;
  }

  /** Apply one simulation tick of passive generation. */
  tick(gs: GameState, dt: number): void {
    gs.data.mass += this.massRate(gs) * dt;
    gs.data.energy += this.energyRate(gs) * dt;
  }

  /**
   * Compute offline gains for an elapsed wall-clock gap. Uses current rates as a
   * stable approximation (compressor uses the saved mass), capped and scaled.
   */
  computeOffline(gs: GameState, elapsedSeconds: number): OfflineReport {
    const seconds = Math.min(Math.max(0, elapsedSeconds), CONFIG.OFFLINE_MAX_SECONDS);
    if (seconds < 5) return { seconds: 0, mass: 0, energy: 0 };
    const rate = gs.derived.offlineRate;
    const mass = this.massRate(gs) * seconds * rate;
    const energy = this.energyRate(gs) * seconds * rate;
    return { seconds, mass, energy };
  }

  applyOffline(gs: GameState, report: OfflineReport): void {
    gs.data.mass += report.mass;
    gs.data.energy += report.energy;
    gs.noteMass();
  }
}
