import type { GameState } from '../state/GameState';
import { NARRATIVE } from '../data/narrative';

/**
 * Fires ambient discovery messages the first time the player crosses each mass
 * threshold. Non-blocking — it only reports a beat to display; the UI fades it
 * in and out without ever interrupting play.
 */
export class NarrativeSystem {
  /** Returns the text of a newly-unlocked beat this tick, or null. */
  update(gs: GameState): string | null {
    const seen = gs.data.narrativeSeen;
    for (const beat of NARRATIVE) {
      if (gs.data.mass >= beat.atMass && !seen.includes(beat.id)) {
        seen.push(beat.id);
        return beat.text;
      }
    }
    return null;
  }
}
