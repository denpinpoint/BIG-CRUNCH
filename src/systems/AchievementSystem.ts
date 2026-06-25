import type { AchievementProbe, AchievementDef } from '../types';
import type { GameState } from '../state/GameState';
import { ACHIEVEMENTS } from '../data/achievements';

/**
 * Evaluates achievement conditions against a state probe. Newly unlocked
 * achievements are returned so the UI can toast them.
 */
export class AchievementSystem {
  private probe: AchievementProbe = {
    mass: 0, energy: 0, totalConsumed: 0,
    consumedByKind: {
      dust: 0, micro: 0, asteroid: 0, satellite: 0, station: 0,
      moon: 0, planet: 0, gasGiant: 0, star: 0, neutron: 0,
    },
    sector: 0, prestiges: 0, cores: 0, eventsTriggered: 0,
    upgradesPurchased: 0, playTime: 0,
  };

  check(gs: GameState): AchievementDef[] {
    const p = this.probe;
    p.mass = gs.data.stats.bestMass;
    p.energy = gs.data.energy;
    p.totalConsumed = gs.data.stats.totalConsumed;
    p.consumedByKind = gs.data.stats.consumedByKind;
    p.sector = gs.data.sector;
    p.prestiges = gs.data.prestiges;
    p.cores = gs.data.cores;
    p.eventsTriggered = gs.data.stats.eventsTriggered;
    p.upgradesPurchased = gs.data.stats.upgradesPurchased;
    p.playTime = gs.data.stats.playTime;

    const unlocked: AchievementDef[] = [];
    const have = gs.data.achievements;
    for (const a of ACHIEVEMENTS) {
      if (have.includes(a.id)) continue;
      if (a.check(p)) {
        have.push(a.id);
        unlocked.push(a);
      }
    }
    return unlocked;
  }
}
