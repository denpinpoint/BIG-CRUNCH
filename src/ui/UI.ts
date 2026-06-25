import type { Game } from '../core/Game';
import type { AchievementDef, UpgradeCategory } from '../types';
import { el, clear } from './dom';
import { formatNumber, formatTime } from '../utils/format';
import { UPGRADES } from '../data/upgrades';
import { COSMIC_LAWS } from '../data/cosmicLaws';
import { ACHIEVEMENTS } from '../data/achievements';
import { nextSector } from '../data/sectors';
import { nextLockedObject } from '../data/objects';
import { EVENTS } from '../data/events';
import { upgradeCost, canAfford, isMaxed, isUnlocked } from '../systems/UpgradeSystem';
import { lawCost, canAffordLaw, coresForPrestige, canPrestige } from '../systems/PrestigeSystem';
import type { OfflineReport } from '../systems/IdleSystem';

const CATEGORIES: { id: UpgradeCategory | 'all'; label: string }[] = [
  { id: 'all', label: 'All' },
  { id: 'gravity', label: 'Gravity' },
  { id: 'mobility', label: 'Mobility' },
  { id: 'efficiency', label: 'Efficiency' },
  { id: 'automation', label: 'Idle' },
  { id: 'discovery', label: 'Discovery' },
  { id: 'utility', label: 'Utility' },
];

interface UpCardRefs {
  root: HTMLElement;
  cost: HTMLElement;
  lvl: HTMLElement;
  effect: HTMLElement;
}

/**
 * DOM UI layer. Builds the HUD, the non-blocking upgrade drawer, and the modal
 * stack (settings, stats/achievements, prestige, pause, credits, offline). All
 * dynamic numbers refresh in update() with cached element references — no
 * per-frame DOM allocation in steady state.
 */
export class UI {
  private root: HTMLElement;
  private game: Game;

  // HUD refs
  private massEl!: HTMLElement;
  private energyEl!: HTMLElement;
  private coresRow!: HTMLElement;
  private coresEl!: HTMLElement;
  private rateEl!: HTMLElement;
  private sectorEl!: HTMLElement;
  private sectorTagEl!: HTMLElement;
  private unlockHint!: HTMLElement;
  private unlockBarFill!: HTMLElement;
  private comboEl!: HTMLElement;
  private upgBtn!: HTMLElement;
  private upgBadge!: HTMLElement;
  private prestigeBtn!: HTMLElement;
  private prestigeBadge!: HTMLElement;

  // Event banner
  private eventBanner!: HTMLElement;
  private evName!: HTMLElement;
  private evDesc!: HTMLElement;
  private evBarFill!: HTMLElement;

  private toastStack!: HTMLElement;
  private controlsHint!: HTMLElement;

  // Drawer
  private drawer!: HTMLElement;
  private drawerOpen = false;
  private drawerWalletMass!: HTMLElement;
  private drawerWalletEnergy!: HTMLElement;
  private tabRow!: HTMLElement;
  private upgradeList!: HTMLElement;
  private currentTab: UpgradeCategory | 'all' = 'all';
  private cards = new Map<string, UpCardRefs>();
  private builtUpgradeIds = new Set<string>();

  // Modals
  private pauseCount = 0;
  private minimap!: HTMLCanvasElement;
  private minimapCtx!: CanvasRenderingContext2D;

  // Prestige modal live refs
  private prestigeGainEl!: HTMLElement;
  private prestigeBtnBig!: HTMLButtonElement;
  private lawList!: HTMLElement;
  private prestigeCoresEl!: HTMLElement;

  constructor(root: HTMLElement, game: Game) {
    this.root = root;
    this.game = game;
    this.buildHUD();
    this.buildEventBanner();
    this.buildToasts();
    this.buildDrawer();
    this.buildControlsHint();
    this.wireGame();
    this.wireKeys();
  }

  // ============================ build: HUD =============================
  private buildHUD(): void {
    // Top-left: mass / energy / cores / rate
    this.massEl = el('div', { class: 'stat-mass' });
    const energyRow = el('div', { class: 'stat-row' }, [
      el('span', { class: 'stat-dot c-energy' }),
      (this.energyEl = el('span', { text: '0' })),
      el('span', { class: 'c-rate', text: 'energy' }),
    ]);
    this.coresEl = el('span', { text: '0' });
    this.coresRow = el('div', { class: 'stat-row' }, [
      el('span', { class: 'stat-dot c-cores' }),
      this.coresEl,
      el('span', { class: 'c-rate', text: 'cores' }),
    ]);
    this.rateEl = el('div', { class: 'c-rate' });
    const tl = el('div', { class: 'hud-corner hud-tl' }, [
      this.massEl, energyRow, this.coresRow, this.rateEl,
    ]);

    // Top-right: sector + buttons
    this.sectorEl = el('div', { class: 'sector-name', text: 'Starter Nursery' });
    this.sectorTagEl = el('div', { class: 'sector-tag', text: '' });

    this.upgBadge = el('span', { class: 'badge', text: '0' });
    this.upgBadge.style.display = 'none';
    this.upgBtn = el('button', { class: 'icon-btn', title: 'Upgrades (U)', onClick: () => this.toggleDrawer() }, [
      el('span', { text: '⬆' }), this.upgBadge,
    ]);

    this.prestigeBadge = el('span', { class: 'badge', text: '' });
    this.prestigeBadge.style.display = 'none';
    this.prestigeBtn = el('button', { class: 'icon-btn', title: 'Big Crunch', onClick: () => this.openPrestige() }, [
      el('span', { text: '✦' }), this.prestigeBadge,
    ]);

    const statsBtn = el('button', { class: 'icon-btn', title: 'Stats & Achievements', onClick: () => this.openStats() }, [el('span', { text: '★' })]);
    const settingsBtn = el('button', { class: 'icon-btn', title: 'Settings', onClick: () => this.openSettings() }, [el('span', { text: '⚙' })]);
    const pauseBtn = el('button', { class: 'icon-btn', title: 'Pause (P)', onClick: () => this.openPause() }, [el('span', { text: '⏸' })]);

    const buttons = el('div', { class: 'hud-buttons' }, [
      this.upgBtn, this.prestigeBtn, statsBtn, settingsBtn, pauseBtn,
    ]);
    const tr = el('div', { class: 'hud-corner hud-tr' }, [this.sectorEl, this.sectorTagEl, buttons]);

    // Bottom-right: unlock hint + minimap
    this.unlockHint = el('div', { class: 'unlock-hint' });
    this.unlockBarFill = el('div');
    const unlockBar = el('div', { class: 'unlock-bar' }, [this.unlockBarFill]);
    this.minimap = el('canvas', { attrs: { width: '150', height: '150' } });
    this.minimap.style.cssText = 'margin-top:8px;border-radius:10px;border:1px solid var(--ui-border);background:rgba(6,4,16,0.55);';
    this.minimapCtx = this.minimap.getContext('2d')!;
    const br = el('div', { class: 'hud-corner hud-br' }, [this.unlockHint, unlockBar, this.minimap]);

    // Bottom-left: combo
    this.comboEl = el('div', { class: 'combo' });
    const bl = el('div', { class: 'hud-corner hud-bl' }, [this.comboEl]);

    this.root.append(tl, tr, br, bl);
  }

  private buildEventBanner(): void {
    this.evName = el('div', { class: 'ev-name' });
    this.evDesc = el('div', { class: 'ev-desc' });
    this.evBarFill = el('div');
    const bar = el('div', { class: 'ev-bar' }, [this.evBarFill]);
    this.eventBanner = el('div', { class: 'event-banner' }, [this.evName, this.evDesc, bar]);
    this.root.append(this.eventBanner);
  }

  private buildToasts(): void {
    this.toastStack = el('div', { class: 'toast-stack' });
    this.root.append(this.toastStack);
  }

  private buildControlsHint(): void {
    this.controlsHint = el('div', { class: 'controls-hint' }, [
      el('span', { html: '<span class="key">W</span><span class="key">A</span><span class="key">S</span><span class="key">D</span> / Arrows — Move' }),
      el('span', { html: 'Absorb matter to <b>grow</b>' }),
    ]);
    this.root.append(this.controlsHint);
    setTimeout(() => this.controlsHint.classList.add('show'), 600);
    setTimeout(() => this.controlsHint.classList.remove('show'), 8000);
  }

  // ============================ build: drawer ==========================
  private buildDrawer(): void {
    this.drawerWalletMass = el('span', {});
    this.drawerWalletEnergy = el('span', { class: 'c-energy' });
    const head = el('div', { class: 'drawer-head' }, [
      el('div', {}, [
        el('h2', { text: 'UPGRADES' }),
        el('div', { class: 'drawer-wallet' }, [this.drawerWalletMass, this.drawerWalletEnergy]),
      ]),
      el('button', { class: 'icon-btn', title: 'Close', onClick: () => this.toggleDrawer(false) }, [el('span', { text: '✕' })]),
    ]);
    this.tabRow = el('div', { class: 'tab-row' });
    for (const c of CATEGORIES) {
      const t = el('div', { class: 'tab' + (c.id === this.currentTab ? ' active' : ''), text: c.label, onClick: () => this.setTab(c.id) });
      t.dataset.tab = c.id;
      this.tabRow.append(t);
    }
    this.upgradeList = el('div', { class: 'upgrade-list' });
    this.drawer = el('div', { class: 'drawer' }, [head, this.tabRow, this.upgradeList]);
    this.root.append(this.drawer);
  }

  private setTab(id: UpgradeCategory | 'all'): void {
    this.currentTab = id;
    for (const t of Array.from(this.tabRow.children)) {
      (t as HTMLElement).classList.toggle('active', (t as HTMLElement).dataset.tab === id);
    }
    this.rebuildUpgradeList();
  }

  private toggleDrawer(force?: boolean): void {
    this.drawerOpen = force ?? !this.drawerOpen;
    this.drawer.classList.toggle('show', this.drawerOpen);
    if (this.drawerOpen) this.rebuildUpgradeList();
    this.game.audio.click();
  }

  private rebuildUpgradeList(): void {
    clear(this.upgradeList);
    this.cards.clear();
    this.builtUpgradeIds.clear();
    const list = UPGRADES.filter(
      (u) => isUnlocked(u, this.game.gs) && (this.currentTab === 'all' || u.category === this.currentTab),
    );
    for (const def of list) {
      const lvl = el('span', { class: 'up-lvl' });
      const effect = el('div', { class: 'up-effect' });
      const cost = el('div', { class: 'up-cost' });
      const card = el('div', { class: 'up-card', onClick: () => this.buyUpgrade(def.id) }, [
        el('div', { class: 'up-main' }, [
          el('div', { class: 'up-name' }, [el('span', { text: def.name }), lvl]),
          effect,
          el('div', { class: 'up-desc', text: def.description }),
        ]),
        cost,
      ]);
      this.upgradeList.append(card);
      this.cards.set(def.id, { root: card, cost, lvl, effect });
      this.builtUpgradeIds.add(def.id);
    }
    this.refreshDrawer();
  }

  private buyUpgrade(id: string): void {
    if (this.game.buyUpgrade(id)) {
      // If new upgrades became unlocked, rebuild; else just refresh.
      const newlyVisible = UPGRADES.some(
        (u) => isUnlocked(u, this.game.gs) && !this.builtUpgradeIds.has(u.id) &&
          (this.currentTab === 'all' || u.category === this.currentTab),
      );
      if (newlyVisible) this.rebuildUpgradeList();
      else this.refreshDrawer();
    }
  }

  private refreshDrawer(): void {
    const gs = this.game.gs;
    this.drawerWalletMass.textContent = '◆ ' + formatNumber(gs.data.mass);
    this.drawerWalletEnergy.textContent = '✦ ' + formatNumber(gs.data.energy);
    for (const def of UPGRADES) {
      const refs = this.cards.get(def.id);
      if (!refs) continue;
      const lvl = gs.lvl(def.id);
      refs.lvl.textContent = `Lv ${lvl}/${def.maxLevel}`;
      refs.effect.textContent = def.effectLabel(Math.min(lvl + 1, def.maxLevel));
      const maxed = isMaxed(def, gs);
      const afford = canAfford(def, gs);
      refs.root.classList.toggle('afford', afford && !maxed);
      refs.root.classList.toggle('cant', !afford && !maxed);
      refs.root.classList.toggle('maxed', maxed);
      if (maxed) {
        refs.cost.textContent = 'MAX';
        refs.cost.className = 'up-cost maxed';
      } else {
        const c = upgradeCost(def, lvl);
        refs.cost.textContent = (def.currency === 'mass' ? '◆ ' : '✦ ') + formatNumber(c);
        refs.cost.className = 'up-cost ' + def.currency;
      }
    }
  }

  // ============================ modals ================================
  private makeModal(title: string, sub: string): { overlay: HTMLElement; body: HTMLElement } {
    const body = el('div', {});
    const close = el('button', { class: 'icon-btn modal-close', onClick: () => this.closeOverlay(overlay, true) }, [el('span', { text: '✕' })]);
    const modal = el('div', { class: 'modal' }, [
      close,
      el('h2', { text: title }),
      el('div', { class: 'sub', text: sub }),
      body,
    ]);
    const overlay = el('div', { class: 'overlay' }, [modal]);
    this.root.append(overlay);
    return { overlay, body };
  }

  private openOverlay(overlay: HTMLElement, pause: boolean): void {
    overlay.classList.add('show');
    if (pause) {
      this.pauseCount++;
      this.game.setPaused(true);
    }
    overlay.dataset.pausing = pause ? '1' : '0';
  }

  private closeOverlay(overlay: HTMLElement, _user: boolean): void {
    overlay.classList.remove('show');
    if (overlay.dataset.pausing === '1') {
      this.pauseCount = Math.max(0, this.pauseCount - 1);
      if (this.pauseCount === 0) this.game.setPaused(false);
    }
    this.game.audio.click();
  }

  // ---- Settings ----
  private settingsOverlay: HTMLElement | null = null;
  private exportArea: HTMLTextAreaElement | null = null;
  private openSettings(): void {
    if (!this.settingsOverlay) this.buildSettings();
    if (this.exportArea) this.exportArea.value = this.game.exportSave();
    this.openOverlay(this.settingsOverlay!, true);
    this.game.audio.click();
  }

  private buildSettings(): void {
    const gs = this.game.gs;
    const s = gs.data.settings;
    const { overlay, body } = this.makeModal('SETTINGS', 'Audio, accessibility & data');

    const slider = (label: string, get: () => number, set: (v: number) => void): HTMLElement => {
      const input = el('input', { class: 'slider', attrs: { type: 'range', min: '0', max: '100', value: String(Math.round(get() * 100)) } }) as HTMLInputElement;
      input.addEventListener('input', () => { set(parseInt(input.value, 10) / 100); this.game.applySettings(); });
      return el('div', { class: 'setting' }, [el('label', { text: label }), input]);
    };
    const toggle = (label: string, get: () => boolean, set: (v: boolean) => void): HTMLElement => {
      const t = el('div', { class: 'toggle' + (get() ? ' on' : '') });
      t.addEventListener('click', () => { const nv = !get(); set(nv); t.classList.toggle('on', nv); this.game.applySettings(); });
      return el('div', { class: 'setting' }, [el('label', { text: label }), t]);
    };

    body.append(
      slider('Master Volume', () => s.master, (v) => (s.master = v)),
      slider('Music', () => s.music, (v) => (s.music = v)),
      slider('Sound Effects', () => s.sfx, (v) => (s.sfx = v)),
      toggle('Mute All', () => s.muted, (v) => (s.muted = v)),
      toggle('Reduced Motion', () => s.reducedMotion, (v) => (s.reducedMotion = v)),
      toggle('Show Minimap', () => s.showMinimap, (v) => (s.showMinimap = v)),
    );

    // Data: export / import / reset
    this.exportArea = el('textarea', { class: 'import-box', attrs: { readonly: 'true', spellcheck: 'false' } }) as HTMLTextAreaElement;
    const copyBtn = el('button', { class: 'btn ghost', text: 'Copy Save', onClick: () => { void navigator.clipboard?.writeText(this.exportArea!.value); copyBtn.textContent = 'Copied!'; setTimeout(() => (copyBtn.textContent = 'Copy Save'), 1200); } });
    const importArea = el('textarea', { class: 'import-box', attrs: { placeholder: 'Paste a save code here…', spellcheck: 'false' } }) as HTMLTextAreaElement;
    const importBtn = el('button', { class: 'btn', text: 'Load Save', onClick: () => {
      if (this.game.importSave(importArea.value)) { importBtn.textContent = 'Loaded!'; importArea.value = ''; setTimeout(() => (importBtn.textContent = 'Load Save'), 1200); }
      else { importBtn.textContent = 'Invalid'; setTimeout(() => (importBtn.textContent = 'Load Save'), 1200); }
    } });
    let resetArmed = false;
    const resetBtn = el('button', { class: 'btn', text: 'Reset Everything', onClick: () => {
      if (!resetArmed) { resetArmed = true; resetBtn.textContent = 'Tap again to confirm'; setTimeout(() => { resetArmed = false; resetBtn.textContent = 'Reset Everything'; }, 2500); return; }
      void this.game.hardReset();
      resetArmed = false; resetBtn.textContent = 'Reset Everything';
      this.closeOverlay(overlay, true);
    } });
    (resetBtn as HTMLElement).style.cssText = 'background:rgba(255,93,115,0.25);border-color:var(--danger);';

    body.append(
      el('div', { class: 'sub', attrs: { style: 'margin-top:18px;' }, text: 'EXPORT / IMPORT' }),
      this.exportArea, copyBtn, importArea, importBtn,
      el('div', { attrs: { style: 'height:14px;' } }), resetBtn,
    );
    this.settingsOverlay = overlay;
  }

  // ---- Stats & Achievements ----
  private statsOverlay: HTMLElement | null = null;
  private statsBody: HTMLElement | null = null;
  private openStats(): void {
    if (!this.statsOverlay) {
      const { overlay, body } = this.makeModal('CODEX', 'Your cosmic record');
      this.statsOverlay = overlay;
      this.statsBody = body;
    }
    this.renderStats();
    this.openOverlay(this.statsOverlay, true);
  }

  private renderStats(): void {
    const gs = this.game.gs;
    const body = this.statsBody!;
    clear(body);
    const st = gs.data.stats;
    const line = (k: string, v: string) => el('div', { class: 'stat-line' }, [el('span', { text: k }), el('span', { text: v })]);
    body.append(
      line('Current Mass', formatNumber(gs.data.mass)),
      line('Best Mass', formatNumber(st.bestMass)),
      line('Total Consumed', formatNumber(st.totalConsumed)),
      line('Events Witnessed', String(st.eventsTriggered)),
      line('Upgrades Bought', String(st.upgradesPurchased)),
      line('Big Crunches', String(gs.data.prestiges)),
      line('Singularity Cores', formatNumber(gs.data.cores)),
      line('Time Played', formatTime(st.playTime)),
    );
    const grid = el('div', { class: 'ach-grid' });
    for (const a of ACHIEVEMENTS) {
      const got = gs.data.achievements.includes(a.id);
      grid.append(el('div', { class: 'ach' + (got ? ' got' : ' locked') }, [
        el('div', { class: 'a-n', text: a.name }),
        el('div', { class: 'a-d', text: a.description }),
      ]));
    }
    body.append(el('div', { class: 'sub', attrs: { style: 'margin-top:16px;' }, text: `ACHIEVEMENTS (${gs.data.achievements.length}/${ACHIEVEMENTS.length})` }), grid);
  }

  // ---- Prestige ----
  private prestigeOverlay: HTMLElement | null = null;
  private openPrestige(): void {
    if (!this.prestigeOverlay) this.buildPrestige();
    this.renderPrestige();
    this.openOverlay(this.prestigeOverlay!, true);
  }

  private buildPrestige(): void {
    const { overlay, body } = this.makeModal('BIG CRUNCH', 'Collapse this universe into Singularity Cores');
    body.append(el('div', { class: 'prestige-core' }));
    this.prestigeGainEl = el('div', { class: 'cores-gain' });
    body.append(this.prestigeGainEl);
    this.prestigeBtnBig = el('button', { class: 'btn primary', text: 'COLLAPSE THE UNIVERSE', attrs: { style: 'width:100%;margin-top:8px;' }, onClick: () => this.doPrestige() }) as HTMLButtonElement;
    body.append(this.prestigeBtnBig);
    this.prestigeCoresEl = el('div', { class: 'sub', attrs: { style: 'margin-top:14px;' } });
    body.append(this.prestigeCoresEl);
    body.append(el('div', { class: 'sub', attrs: { style: 'margin-top:4px;' }, text: 'COSMIC LAWS — permanent across every universe' }));
    this.lawList = el('div', {});
    body.append(this.lawList);
    this.prestigeOverlay = overlay;
  }

  private renderPrestige(): void {
    const gs = this.game.gs;
    const gain = coresForPrestige(gs);
    const able = canPrestige(gs);
    this.prestigeGainEl.textContent = able ? `+${formatNumber(gain)} Cores` : 'Not ready';
    this.prestigeBtnBig.disabled = !able;
    this.prestigeBtnBig.textContent = able ? 'COLLAPSE THE UNIVERSE' : `Reach ${formatNumber(250000)} mass`;
    this.prestigeCoresEl.textContent = `Singularity Cores: ${formatNumber(gs.data.cores)}`;

    clear(this.lawList);
    for (const law of COSMIC_LAWS) {
      const lvl = gs.law(law.id);
      const maxed = lvl >= law.maxLevel;
      const cost = lawCost(law, lvl);
      const afford = canAffordLaw(law, gs);
      const cardCost = el('div', { class: 'up-cost ' + (maxed ? 'maxed' : 'energy') , text: maxed ? 'MAX' : '✦ ' + formatNumber(cost) });
      const card = el('div', { class: 'up-card ' + (maxed ? 'maxed' : afford ? 'afford' : 'cant'), onClick: () => { if (this.game.buyLaw(law.id)) this.renderPrestige(); } }, [
        el('div', { class: 'up-main' }, [
          el('div', { class: 'up-name' }, [el('span', { text: law.name }), el('span', { class: 'up-lvl', text: `Lv ${lvl}/${law.maxLevel}` })]),
          el('div', { class: 'up-effect', text: law.effectLabel(Math.min(lvl + 1, law.maxLevel)) }),
          el('div', { class: 'up-desc', text: law.description }),
        ]),
        cardCost,
      ]);
      this.lawList.append(card);
    }
  }

  private doPrestige(): void {
    const cores = this.game.doPrestige();
    if (cores > 0) {
      this.renderPrestige();
      this.toast(`Universe collapsed — gained ${formatNumber(cores)} Cores`, 'achieve');
    }
  }

  // ---- Pause & Credits ----
  private pauseOverlay: HTMLElement | null = null;
  private openPause(): void {
    if (!this.pauseOverlay) this.buildPause();
    this.openOverlay(this.pauseOverlay!, true);
  }
  private buildPause(): void {
    const { overlay, body } = this.makeModal('PAUSED', 'The universe waits.');
    const row = el('div', { class: 'modal-row' }, [
      el('button', { class: 'btn primary', text: 'Resume', onClick: () => this.closeOverlay(overlay, true) }),
      el('button', { class: 'btn', text: 'Settings', onClick: () => { this.closeOverlay(overlay, true); this.openSettings(); } }),
      el('button', { class: 'btn ghost', text: 'Credits', onClick: () => this.openCredits() }),
    ]);
    body.append(row);
    this.pauseOverlay = overlay;
  }
  private togglePause(): void {
    if (this.pauseOverlay && this.pauseOverlay.classList.contains('show')) this.closeOverlay(this.pauseOverlay, true);
    else this.openPause();
  }

  private creditsOverlay: HTMLElement | null = null;
  private openCredits(): void {
    if (!this.creditsOverlay) {
      const { overlay, body } = this.makeModal('CREDITS', '');
      body.append(el('div', { class: 'credits-body', html:
        '<b>EVENT HORIZON: EAT THE UNIVERSE</b><br/>' +
        'Design, code & art — a solo cosmic build.<br/><br/>' +
        'Engine: custom TypeScript + HTML5 Canvas.<br/>' +
        'Audio: fully synthesized via the Web Audio API.<br/>' +
        'No external assets. No trackers.<br/><br/>' +
        'Thank you for playing. Now go — <b>eat the universe.</b>' }));
      this.creditsOverlay = overlay;
    }
    this.openOverlay(this.creditsOverlay, true);
  }

  // ---- Offline ----
  showOffline(report: OfflineReport): void {
    const { overlay, body } = this.makeModal('WELCOME BACK', `Away for ${formatTime(report.seconds)}`);
    body.append(
      el('div', { class: 'sub', text: 'Your singularity kept feeding while you were gone:' }),
      el('div', { class: 'stat-line' }, [el('span', { text: 'Mass gained' }), el('span', { text: '+' + formatNumber(report.mass) })]),
      el('div', { class: 'stat-line' }, [el('span', { text: 'Energy gained' }), el('span', { text: '+' + formatNumber(report.energy) })]),
      el('div', { class: 'modal-row' }, [
        el('button', { class: 'btn primary', attrs: { style: 'width:100%;' }, text: 'Continue', onClick: () => this.closeOverlay(overlay, true) }),
      ]),
    );
    this.openOverlay(overlay, false);
  }

  // ============================ toasts ================================
  toast(text: string, type: 'narrative' | 'achieve' = 'narrative', _color?: string): void {
    const t = el('div', { class: `toast ${type}` });
    if (type === 'narrative') t.textContent = text;
    else t.innerHTML = text;
    this.toastStack.append(t);
    while (this.toastStack.children.length > 4) this.toastStack.removeChild(this.toastStack.firstChild!);
    setTimeout(() => t.classList.add('fade'), 3200);
    setTimeout(() => t.remove(), 3800);
  }

  achievementToast(def: AchievementDef): void {
    this.toast(`<span class="a-title">★ ${def.name}</span><div class="a-desc">${def.description}</div>`, 'achieve');
  }

  // ============================ wiring ================================
  private wireGame(): void {
    this.game.onToast = (text) => this.toast(text, 'narrative');
    this.game.onAchievement = (def) => this.achievementToast(def);
    this.game.onSectorChange = (s) => {
      this.sectorEl.textContent = s.name;
      this.sectorTagEl.textContent = s.tagline;
      this.toast(`Entering ${s.name}`, 'narrative');
    };
    this.game.onEventStart = (_id, name) => {
      this.eventBanner.classList.add('show');
      this.evName.textContent = name;
    };
    this.game.input.onPauseKey = () => this.togglePause();
  }

  private wireKeys(): void {
    window.addEventListener('keydown', (e) => {
      if (e.code === 'KeyU' && !e.repeat) this.toggleDrawer();
    });
  }

  // ============================ per-frame =============================
  update(): void {
    const gs = this.game.gs;
    this.massEl.innerHTML = `${formatNumber(gs.data.mass)}<span class="unit">MASS</span>`;
    this.energyEl.textContent = formatNumber(gs.data.energy);
    this.coresRow.style.display = gs.data.cores > 0 || gs.data.prestiges > 0 ? '' : 'none';
    this.coresEl.textContent = formatNumber(gs.data.cores);

    const mr = this.game.massRate();
    const er = this.game.energyRate();
    this.rateEl.textContent = mr > 0 || er > 0 ? `+${formatNumber(mr)} mass/s · +${formatNumber(er)} energy/s` : '';

    // Sector label.
    const sec = this.game.currentSector;
    if (this.sectorEl.textContent !== sec.name) {
      this.sectorEl.textContent = sec.name;
      this.sectorTagEl.textContent = sec.tagline;
    }

    // Next unlock hint.
    this.updateUnlockHint();

    // Combo.
    if (gs.combo > 1.05) {
      this.comboEl.classList.add('show');
      this.comboEl.textContent = `COMBO ×${gs.combo.toFixed(1)}`;
    } else {
      this.comboEl.classList.remove('show');
    }

    // Event banner.
    const ev = this.game.events;
    if (ev.activeId) {
      const def = EVENTS[ev.activeId];
      this.eventBanner.classList.add('show');
      this.evName.textContent = def.name;
      this.evDesc.textContent = def.description;
      this.evBarFill.style.width = `${(ev.remaining / Math.max(0.01, ev.duration)) * 100}%`;
      this.eventBanner.style.color = def.color;
    } else {
      this.eventBanner.classList.remove('show');
    }

    // Badges.
    const affordCount = UPGRADES.reduce((n, u) => n + (isUnlocked(u, gs) && canAfford(u, gs) ? 1 : 0), 0);
    if (!this.drawerOpen && affordCount > 0) {
      this.upgBadge.style.display = '';
      this.upgBadge.textContent = String(affordCount);
      this.upgBtn.classList.add('pulse');
    } else {
      this.upgBadge.style.display = 'none';
      this.upgBtn.classList.remove('pulse');
    }
    if (canPrestige(gs)) {
      this.prestigeBadge.style.display = '';
      this.prestigeBadge.textContent = '✦';
      this.prestigeBtn.classList.add('pulse');
    } else {
      this.prestigeBadge.style.display = 'none';
      this.prestigeBtn.classList.remove('pulse');
    }

    // Drawer affordability while open.
    if (this.drawerOpen) this.refreshDrawer();

    // Live prestige modal.
    if (this.prestigeOverlay && this.prestigeOverlay.classList.contains('show')) this.renderPrestige();

    // Minimap.
    this.minimap.style.display = gs.data.settings.showMinimap ? '' : 'none';
    if (gs.data.settings.showMinimap) this.drawMinimap();
  }

  private updateUnlockHint(): void {
    const gs = this.game.gs;
    const bestMass = gs.data.stats.bestMass;
    const nextObj = nextLockedObject(bestMass);
    if (nextObj) {
      this.unlockHint.innerHTML = `Next matter: <b>${nextObj.name}</b><br/>at ${formatNumber(nextObj.mass)} mass`;
      const prev = this.prevUnlockMass(nextObj.mass);
      const frac = (bestMass - prev) / Math.max(1, nextObj.mass - prev);
      this.unlockBarFill.style.width = `${Math.max(0, Math.min(1, frac)) * 100}%`;
      return;
    }
    const ns = nextSector(gs.data.sector);
    if (ns) {
      this.unlockHint.innerHTML = `Next sector: <b>${ns.name}</b><br/>at ${formatNumber(ns.unlockMass)} mass`;
      this.unlockBarFill.style.width = `${Math.min(1, bestMass / ns.unlockMass) * 100}%`;
    } else {
      this.unlockHint.innerHTML = `<b>You are everything.</b>`;
      this.unlockBarFill.style.width = '100%';
    }
  }

  /** Baseline (previous tier's gate) so the progress bar fills tier-to-tier. */
  private prevUnlockMass(target: number): number {
    let last = 0;
    for (const o of OBJECT_MASSES) {
      if (o >= target) break;
      last = o;
    }
    return last;
  }

  private drawMinimap(): void {
    const ctx = this.minimapCtx;
    const size = 150;
    const sector = this.game.currentSector;
    const half = sector.size / 2;
    ctx.clearRect(0, 0, size, size);
    const toMap = (wx: number, wy: number): [number, number] => [
      ((wx + half) / sector.size) * size,
      ((wy + half) / sector.size) * size,
    ];
    // Large bodies.
    const items = this.game.pool.items;
    for (let i = 0; i < items.length; i++) {
      const o = items[i]!;
      if (!o.active || o.radius < 30) continue;
      const [mx, my] = toMap(o.pos.x, o.pos.y);
      ctx.fillStyle = o.glow;
      ctx.globalAlpha = 0.8;
      ctx.fillRect(mx - 1.5, my - 1.5, 3, 3);
    }
    ctx.globalAlpha = 1;
    // Player.
    const [px, py] = toMap(this.game.player.pos.x, this.game.player.pos.y);
    ctx.beginPath();
    ctx.arc(px, py, 3.5, 0, Math.PI * 2);
    ctx.fillStyle = '#54e6ff';
    ctx.fill();
    ctx.beginPath();
    ctx.arc(px, py, 7, 0, Math.PI * 2);
    ctx.strokeStyle = 'rgba(84,230,255,0.4)';
    ctx.stroke();
  }
}

// Object mass ladder for the unlock progress bar baseline.
const OBJECT_MASSES = [0.3, 1.2, 6, 28, 130, 650, 3400, 19000, 110000, 850000];
