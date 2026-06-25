import type { CosmicObject, ObjectKind, SectorDef, EventId, AchievementDef } from '../types';
import { GameState, newSaveData } from '../state/GameState';
import { neutralMods, resetMods } from '../state/runtime';
import { Player } from '../entities/Player';
import { makeCosmicObject } from '../entities/cosmicObject';
import { ParticleSystem } from '../entities/Particles';
import { ObjectPool } from './ObjectPool';
import { Camera } from './Camera';
import { Input } from './Input';
import { Renderer } from '../render/Renderer';
import { AudioEngine } from '../audio/AudioEngine';
import { SaveManager } from '../save/SaveManager';
import { PhysicsSystem } from '../systems/PhysicsSystem';
import { SpawnSystem } from '../systems/SpawnSystem';
import { IdleSystem, type OfflineReport } from '../systems/IdleSystem';
import { EventSystem } from '../systems/EventSystem';
import { NarrativeSystem } from '../systems/NarrativeSystem';
import { AchievementSystem } from '../systems/AchievementSystem';
import { buyUpgrade } from '../systems/UpgradeSystem';
import { buyLaw, performPrestige } from '../systems/PrestigeSystem';
import { upgradeById } from '../data/upgrades';
import { lawById } from '../data/cosmicLaws';
import { SECTORS, sectorForMass } from '../data/sectors';
import { EVENTS } from '../data/events';
import { CONFIG } from '../config';
import { clamp } from '../utils/math';
import { formatNumber } from '../utils/format';
import { RNG } from './RNG';
import { CrazyGames } from '../sdk/CrazyGames';

/** Particle colour index per object kind (see Particles.PARTICLE_COLORS). */
const KIND_PARTICLE: Record<ObjectKind, number> = {
  dust: 3, micro: 2, asteroid: 0, satellite: 1, station: 1,
  moon: 3, planet: 1, gasGiant: 2, star: 2, neutron: 1,
};

/**
 * Central orchestrator. Owns the world, systems, camera, renderer, audio and
 * save, and drives the fixed-step simulation plus the render pass. UI wires the
 * `on*` callbacks to surface toasts/modals; gameplay code never touches the DOM.
 */
export class Game {
  readonly gs: GameState;
  readonly camera = new Camera();
  readonly player = new Player();
  readonly pool = new ObjectPool<CosmicObject>(CONFIG.HARD_MAX_OBJECTS, makeCosmicObject);
  readonly particles = new ParticleSystem();
  readonly renderer: Renderer;
  readonly audio = new AudioEngine();
  readonly input: Input;
  private readonly save = new SaveManager();

  private readonly physics = new PhysicsSystem();
  private readonly spawn = new SpawnSystem();
  private readonly idle = new IdleSystem();
  readonly events = new EventSystem();
  private readonly narrative = new NarrativeSystem();
  private readonly achievements = new AchievementSystem();

  private readonly mods = neutralMods();
  private readonly rngObj = new RNG((Math.random() * 1e9) >>> 0);
  private readonly rng = this.rngObj.next;

  private sector: SectorDef = SECTORS[0]!;
  private autosaveTimer = 0;
  paused = false;
  offlineReport: OfflineReport | null = null;

  // UI hooks (wired by main.ts).
  onToast: (text: string, color?: string) => void = () => {};
  onAchievement: (def: AchievementDef) => void = () => {};
  onEventStart: (id: EventId, name: string, desc: string) => void = () => {};
  onSectorChange: (sector: SectorDef) => void = () => {};

  constructor(canvas: HTMLCanvasElement) {
    this.renderer = new Renderer(canvas);
    this.input = new Input(canvas);
    this.gs = new GameState();

    this.physics.onConsume = (o) => this.handleConsume(o);
    this.events.onStart = (id) => {
      const def = EVENTS[id];
      this.onEventStart(id, def.name, def.description);
      this.audio.event();
      this.camera.addTrauma(0.4);
    };
    this.input.onFirstGesture = () => {
      this.audio.resume();
      if (!this.gs.data.settings.muted) this.audio.startMusic();
    };
  }

  /** Load (or create) the save, apply offline progress, build the world. */
  async init(): Promise<void> {
    await CrazyGames.init();
    const loaded = await this.save.load();
    if (loaded) {
      this.gs.data = loaded;
      this.gs.recompute();
    }
    const gs = this.gs;

    // Offline progress.
    const elapsed = (Date.now() - gs.data.lastSaved) / 1000;
    const report = this.idle.computeOffline(gs, elapsed);
    if (report.mass > 0 || report.energy > 0) {
      this.idle.applyOffline(gs, report);
      this.offlineReport = report;
    }

    this.sector = sectorForMass(gs.data.stats.bestMass);
    gs.data.sector = this.sector.id;
    this.renderer.background.setSector(this.sector);

    // Place the player and frame the camera.
    this.player.pos.x = 0;
    this.player.pos.y = 0;
    this.player.recomputeSize(gs);
    const { w, h } = this.renderer.resize();
    this.camera.setViewport(w, h);
    this.camera.snapTo(0, 0);
    this.camera.zoom = this.desiredZoom();

    this.spawn.prewarm(this.player, this.pool, gs, this.rng, this.camera.halfViewW, this.camera.halfViewH, this.sector, 48);

    this.audio.setVolumes(
      gs.data.settings.master, gs.data.settings.music,
      gs.data.settings.sfx, gs.data.settings.muted,
    );

    // CrazyGames: the player can now play.
    CrazyGames.gameplayStart();
  }

  resize(): void {
    const { w, h } = this.renderer.resize();
    this.camera.setViewport(w, h);
  }

  private desiredZoom(): number {
    return clamp(CONFIG.ZOOM_REF_RADIUS / this.player.radius, CONFIG.ZOOM_MIN, CONFIG.ZOOM_MAX);
  }

  // ----------------------------- simulation -----------------------------
  step(dt: number): void {
    const gs = this.gs;
    // Background + camera animate even while paused for a live feel.
    this.renderer.background.update(dt);

    if (this.paused) {
      this.camera.update(this.player.pos.x, this.player.pos.y, this.camera.zoom, dt);
      return;
    }

    gs.data.stats.playTime += dt;

    // Combo decay.
    if (gs.comboTimer > 0) {
      gs.comboTimer -= dt;
      if (gs.comboTimer <= 0) {
        gs.combo = 1;
        gs.comboCount = 0;
      }
    }

    // Movement.
    const dir = TMP_DIR;
    this.input.getMoveVector(dir, this.camera.viewW * 0.5, this.camera.viewH * 0.5);
    this.player.update(dt, dir, gs, this.sector.size);

    // Sector progression.
    const target = sectorForMass(gs.data.stats.bestMass);
    if (target.id > this.sector.id) this.setSector(target);

    // Event modifiers for this frame.
    resetMods(this.mods);
    this.events.update(dt, gs);
    this.events.applyMods(this.mods, gs);

    // Spawning + physics + particles.
    this.spawn.update(
      dt, this.player, this.pool, gs, this.mods, this.rng,
      this.camera.halfViewW, this.camera.halfViewH, this.sector,
      this.events.activeId, gs.combo,
    );
    this.physics.update(dt, this.player, this.pool, this.particles, gs, this.mods, this.rng);
    this.particles.update(dt, this.player.pos.x, this.player.pos.y);

    // Idle generation.
    this.idle.tick(gs, dt);
    gs.noteMass();

    // Narrative + achievements.
    const beat = this.narrative.update(gs);
    if (beat) this.onToast(beat, '#aef3ff');
    const unlocked = this.achievements.check(gs);
    for (const a of unlocked) {
      this.onAchievement(a);
      this.audio.achievement();
    }

    // Camera framing.
    this.camera.update(this.player.pos.x, this.player.pos.y, this.desiredZoom(), dt);

    // Visual float lifetimes.
    this.renderer.updateFloats(dt);

    // Autosave.
    this.autosaveTimer += dt;
    if (this.autosaveTimer >= CONFIG.AUTOSAVE_INTERVAL) {
      this.autosaveTimer = 0;
      void this.save.save(gs.data);
    }
  }

  draw(): void {
    this.renderer.render(
      this.camera, this.player, this.pool, this.particles, this.gs,
      this.events.tint(), this.gs.data.settings.reducedMotion ? 0.4 : this.events.strength(),
    );
    const j = this.input.joystick;
    if (j.active) this.renderer.drawJoystick(j.originX, j.originY, j.curX, j.curY);
  }

  // ----------------------------- consumption ----------------------------
  private handleConsume(o: CosmicObject): void {
    const gs = this.gs;
    const d = gs.derived;

    // Combo ramp.
    gs.comboCount++;
    gs.comboTimer = d.comboWindow;
    gs.combo = Math.min(d.comboCap, 1 + gs.comboCount * 0.05);

    let massGain = o.massValue * d.massValueMult * this.mods.massMult * gs.combo;
    if (o.orbitTier === 'massive') massGain *= 1 + d.massValueBigPct;

    let energyGain = o.energyValue * d.energyValueMult;

    const crit = Math.random() < d.critChance;
    if (crit) {
      const cm = 1 + d.critPower;
      massGain *= cm;
      energyGain *= cm;
    }
    energyGain += massGain * d.transmuteFrac;

    gs.data.mass += massGain;
    gs.data.energy += energyGain;
    gs.data.stats.totalConsumed++;
    gs.data.stats.consumedByKind[o.kind]++;
    gs.noteMass();

    // Juice.
    const sizeFactor = clamp(o.radius / 160, 0.02, 1);
    this.player.thump(0.25 + sizeFactor);
    this.camera.addTrauma(0.05 + sizeFactor * 0.55);
    this.audio.consume(sizeFactor);

    const color = KIND_PARTICLE[o.kind];
    const count = Math.floor(6 + sizeFactor * 34);
    this.particles.burst(
      o.pos.x, o.pos.y, count, color,
      40 + sizeFactor * 80, 140 + sizeFactor * 320,
      1.5 + sizeFactor * 2, 4 + sizeFactor * 6,
      0.6 + sizeFactor * 0.5, 0.9, this.rng,
    );

    // Floating gain for notable meals / combos / crits.
    const notable = massGain >= Math.max(8, gs.data.mass * 0.004) || crit || gs.combo >= 1.5;
    if (notable && !gs.data.settings.reducedMotion) {
      const txt = (crit ? '✦ ' : '+') + formatNumber(massGain);
      const col = crit ? '#ffd166' : o.orbitTier === 'massive' ? '#7df0ff' : '#f4f1ff';
      this.renderer.addFloat(o.pos.x, o.pos.y - o.radius, txt, col, crit ? 24 : 18);
    }

    // Collapse shock on big bodies yanks the field inward.
    if ((o.orbitTier === 'large' || o.orbitTier === 'massive') && d.shockwaveStrength > 0) {
      this.physics.applyShockwave(this.pool, o.pos.x, o.pos.y, this.player.gravityRadius * 1.3, d.shockwaveStrength);
    }
  }

  private setSector(sector: SectorDef): void {
    this.sector = sector;
    this.gs.data.sector = sector.id;
    this.renderer.background.setSector(sector);
    this.onSectorChange(sector);
    this.audio.event();
    this.camera.addTrauma(0.3);
  }

  // ----------------------------- actions --------------------------------
  buyUpgrade(id: string): boolean {
    const def = upgradeById(id);
    if (!def) return false;
    const paid = buyUpgrade(def, this.gs);
    if (paid > 0) {
      this.audio.upgrade();
      this.player.recomputeSize(this.gs);
      return true;
    }
    return false;
  }

  buyLaw(id: string): boolean {
    const def = lawById(id);
    if (!def) return false;
    const ok = buyLaw(def, this.gs);
    if (ok) this.audio.upgrade();
    return ok;
  }

  doPrestige(): number {
    const cores = performPrestige(this.gs);
    if (cores <= 0) return 0;
    this.audio.prestige();
    CrazyGames.happytime();
    // Reset the world.
    this.pool.releaseAll();
    this.particles.clear();
    this.events.reset();
    this.player.pos.x = 0;
    this.player.pos.y = 0;
    this.player.vel.x = 0;
    this.player.vel.y = 0;
    this.player.recomputeSize(this.gs);
    this.sector = SECTORS[0]!;
    this.gs.data.sector = 0;
    this.renderer.background.setSector(this.sector);
    this.camera.snapTo(0, 0);
    this.camera.zoom = this.desiredZoom();
    this.spawn.reset();
    this.spawn.prewarm(this.player, this.pool, this.gs, this.rng, this.camera.halfViewW, this.camera.halfViewH, this.sector, 48);
    void this.save.save(this.gs.data);
    return cores;
  }

  applySettings(): void {
    const s = this.gs.data.settings;
    this.audio.setVolumes(s.master, s.music, s.sfx, s.muted);
    if (!s.muted) this.audio.startMusic();
    void this.save.save(this.gs.data);
  }

  setPaused(p: boolean): void {
    this.paused = p;
    if (p) {
      CrazyGames.gameplayStop();
      void this.save.save(this.gs.data);
    } else {
      CrazyGames.gameplayStart();
    }
  }

  // ----------------------------- save I/O -------------------------------
  exportSave(): string {
    return this.save.exportString(this.gs.data);
  }

  importSave(text: string): boolean {
    const data = this.save.importString(text);
    if (!data) return false;
    this.gs.data = data;
    this.gs.recompute();
    this.player.recomputeSize(this.gs);
    this.sector = sectorForMass(this.gs.data.stats.bestMass);
    this.gs.data.sector = this.sector.id;
    this.renderer.background.setSector(this.sector);
    this.pool.releaseAll();
    this.particles.clear();
    this.spawn.reset();
    this.spawn.prewarm(this.player, this.pool, this.gs, this.rng, this.camera.halfViewW, this.camera.halfViewH, this.sector, 48);
    void this.save.save(this.gs.data);
    return true;
  }

  async hardReset(): Promise<void> {
    await this.save.wipe();
    this.gs.data = newSaveData();
    this.gs.recompute();
    this.player.recomputeSize(this.gs);
    this.sector = SECTORS[0]!;
    this.renderer.background.setSector(this.sector);
    this.pool.releaseAll();
    this.particles.clear();
    this.spawn.reset();
    this.spawn.prewarm(this.player, this.pool, this.gs, this.rng, this.camera.halfViewW, this.camera.halfViewH, this.sector, 48);
  }

  saveNow(): void {
    void this.save.save(this.gs.data);
  }

  /** Passive generation rates, for HUD display. */
  massRate(): number {
    return this.idle.massRate(this.gs);
  }
  energyRate(): number {
    return this.idle.energyRate(this.gs);
  }

  get currentSector(): SectorDef {
    return this.sector;
  }
}

const TMP_DIR = { x: 0, y: 0 };
