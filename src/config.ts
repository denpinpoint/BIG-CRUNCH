/** Central tunables. Keeping balance knobs in one place eases iteration. */
export const CONFIG = {
  /** Fixed simulation timestep (seconds). 60 Hz logical tick. */
  FIXED_DT: 1 / 60,
  /** Cap on accumulated catch-up steps to avoid spiral-of-death after a stall. */
  MAX_STEPS_PER_FRAME: 5,

  /** Player base stats. */
  PLAYER_BASE_RADIUS: 13,
  PLAYER_RADIUS_GROWTH: 7, // r = base + growth * cbrt(mass)
  PLAYER_BASE_SPEED: 300, // world units / sec
  PLAYER_SPEED_SIZE_BONUS: 1.1, // +per radius unit, keeps apparent speed steady
  PLAYER_ACCEL: 9, // approach rate toward target velocity
  GRAVITY_RADIUS_FACTOR: 3.4,
  GRAVITY_RADIUS_FLAT: 70,
  BASE_ORBIT_CAPACITY: 4,
  BASE_COMBO_WINDOW: 1.6,
  COMBO_BASE_CAP: 3, // combo multiplier ceiling before upgrades
  CONSUME_BASE_SPEED: 1,

  /** Spawning. */
  BASE_MAX_OBJECTS: 90,
  HARD_MAX_OBJECTS: 520, // pool capacity ceiling
  BASE_SPAWN_INTERVAL: 0.28, // seconds between spawn attempts
  SPAWN_MARGIN: 240, // world units beyond view edge to spawn / cull

  /**
   * Camera zoom eases out as the player grows so the singularity holds a roughly
   * constant on-screen size (apparent radius ≈ ZOOM_REF_RADIUS) instead of
   * engulfing the screen. The floor is intentionally tiny: the camera keeps
   * zooming out with growth, conveying scale through the shrinking universe
   * rather than a bloating black hole.
   */
  ZOOM_MIN: 0.02,
  ZOOM_MAX: 1.25,
  ZOOM_REF_RADIUS: 30, // target on-screen player radius (px)

  /** Idle / offline. */
  OFFLINE_MAX_SECONDS: 8 * 3600,
  AUTOSAVE_INTERVAL: 12, // seconds

  /** Events. */
  EVENT_FIRST_DELAY: 75, // seconds before first event
  EVENT_INTERVAL_MIN: 95,
  EVENT_INTERVAL_MAX: 160,

  /** Prestige. Cores earned ~ sqrt(bestMass / divisor). */
  PRESTIGE_UNLOCK_MASS: 250000,
  CORE_DIVISOR: 60000,

  /** Particle budget. */
  MAX_PARTICLES: 1400,
} as const;

export const SAVE_VERSION = 2;
export const SAVE_KEY = 'eventhorizon.save.v1';
