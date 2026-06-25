import type { SaveData, Settings } from '../state/GameState';
import { newSaveData, DEFAULT_SETTINGS } from '../state/GameState';
import type { ObjectKind } from '../types';
import { SAVE_VERSION } from '../config';

function num(v: unknown, fallback: number): number {
  return typeof v === 'number' && isFinite(v) ? v : fallback;
}
function rec(v: unknown): Record<string, number> {
  const out: Record<string, number> = {};
  if (v && typeof v === 'object') {
    for (const [k, val] of Object.entries(v as Record<string, unknown>)) {
      if (typeof val === 'number' && isFinite(val) && val > 0) out[k] = Math.floor(val);
    }
  }
  return out;
}
function strArr(v: unknown): string[] {
  return Array.isArray(v) ? v.filter((x): x is string => typeof x === 'string') : [];
}

function settings(v: unknown): Settings {
  const s = (v ?? {}) as Partial<Settings>;
  return {
    master: clamp01(num(s.master, DEFAULT_SETTINGS.master)),
    music: clamp01(num(s.music, DEFAULT_SETTINGS.music)),
    sfx: clamp01(num(s.sfx, DEFAULT_SETTINGS.sfx)),
    muted: typeof s.muted === 'boolean' ? s.muted : DEFAULT_SETTINGS.muted,
    reducedMotion: typeof s.reducedMotion === 'boolean' ? s.reducedMotion : DEFAULT_SETTINGS.reducedMotion,
    showMinimap: typeof s.showMinimap === 'boolean' ? s.showMinimap : DEFAULT_SETTINGS.showMinimap,
  };
}
function clamp01(v: number): number {
  return v < 0 ? 0 : v > 1 ? 1 : v;
}

/**
 * Build a fully valid SaveData from arbitrary (possibly old, partial, or
 * corrupt) input. This doubles as our migration path and corruption recovery:
 * every field is validated against a fresh default.
 */
export function sanitize(raw: unknown): SaveData {
  const base = newSaveData();
  if (!raw || typeof raw !== 'object') return base;
  const r = raw as Record<string, unknown>;
  const statsIn = (r.stats ?? {}) as Record<string, unknown>;
  const kindsIn = (statsIn.consumedByKind ?? {}) as Record<string, unknown>;

  const consumedByKind = { ...base.stats.consumedByKind };
  for (const k of Object.keys(consumedByKind) as ObjectKind[]) {
    consumedByKind[k] = Math.max(0, Math.floor(num(kindsIn[k], 0)));
  }

  return {
    version: SAVE_VERSION,
    mass: Math.max(1, num(r.mass, 1)),
    energy: Math.max(0, num(r.energy, 0)),
    cores: Math.max(0, Math.floor(num(r.cores, 0))),
    prestiges: Math.max(0, Math.floor(num(r.prestiges, 0))),
    runBestMass: Math.max(1, num(r.runBestMass, num(r.mass, 1))),
    sector: Math.max(0, Math.floor(num(r.sector, 0))),
    upgrades: rec(r.upgrades),
    laws: rec(r.laws),
    achievements: strArr(r.achievements),
    narrativeSeen: strArr(r.narrativeSeen),
    stats: {
      totalConsumed: Math.max(0, Math.floor(num(statsIn.totalConsumed, 0))),
      consumedByKind,
      eventsTriggered: Math.max(0, Math.floor(num(statsIn.eventsTriggered, 0))),
      upgradesPurchased: Math.max(0, Math.floor(num(statsIn.upgradesPurchased, 0))),
      playTime: Math.max(0, num(statsIn.playTime, 0)),
      bestMass: Math.max(1, num(statsIn.bestMass, num(r.mass, 1))),
    },
    settings: settings(r.settings),
    lastSaved: num(r.lastSaved, Date.now()),
  };
}
