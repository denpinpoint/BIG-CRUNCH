/**
 * Thin, defensive wrapper around the CrazyGames HTML5 SDK (v3).
 *
 * Basic Launch does not require the SDK, and the game must run perfectly
 * without it — so every call is guarded and silently no-ops when the SDK is
 * absent (local dev, offline, or load failure). The structure leaves clear
 * seams for Full Launch additions (ads, data sync, user module) without
 * touching gameplay code.
 */

interface CrazyGamesGame {
  gameplayStart?: () => void;
  gameplayStop?: () => void;
  happytime?: () => void;
  loadingStart?: () => void;
  loadingStop?: () => void;
}
interface CrazyGamesSDK {
  init?: () => Promise<void>;
  game?: CrazyGamesGame;
}
declare global {
  interface Window {
    CrazyGames?: { SDK?: CrazyGamesSDK };
    __cgSdkFailed?: boolean;
  }
}

class CrazyGamesBridge {
  private sdk: CrazyGamesSDK | null = null;
  private initialized = false;
  private gameplayActive = false;

  get available(): boolean {
    return this.sdk !== null;
  }

  /** Best-effort init. Never throws; resolves whether or not the SDK exists. */
  async init(): Promise<void> {
    if (this.initialized) return;
    this.initialized = true;
    try {
      if (window.__cgSdkFailed) return;
      const sdk = window.CrazyGames?.SDK;
      if (!sdk) return;
      if (sdk.init) await sdk.init();
      this.sdk = sdk;
    } catch {
      this.sdk = null;
    }
  }

  /**
   * Marks the moment the player reaches a playable state. CrazyGames measures
   * initial download size up to this event.
   */
  gameplayStart(): void {
    if (this.gameplayActive) return;
    this.gameplayActive = true;
    try {
      this.sdk?.game?.gameplayStart?.();
    } catch {
      /* ignore */
    }
  }

  gameplayStop(): void {
    if (!this.gameplayActive) return;
    this.gameplayActive = false;
    try {
      this.sdk?.game?.gameplayStop?.();
    } catch {
      /* ignore */
    }
  }

  /** Signal a notable positive moment (prestige) — harmless if unsupported. */
  happytime(): void {
    try {
      this.sdk?.game?.happytime?.();
    } catch {
      /* ignore */
    }
  }
}

export const CrazyGames = new CrazyGamesBridge();
