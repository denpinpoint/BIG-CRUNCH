import { CONFIG } from '../config';

/**
 * Fixed-timestep loop with a render pass. Simulation always advances in
 * `FIXED_DT` increments regardless of display refresh rate, so physics behaves
 * identically at 60, 144 or 165 Hz (a CrazyGames requirement). A backlog cap
 * prevents the spiral-of-death after a tab stall.
 */
export class GameLoop {
  private rafId = 0;
  private last = 0;
  private acc = 0;
  private running = false;

  constructor(
    private readonly step: (dt: number) => void,
    private readonly draw: () => void,
  ) {}

  start(): void {
    if (this.running) return;
    this.running = true;
    this.last = performance.now();
    this.rafId = requestAnimationFrame(this.frame);
  }

  stop(): void {
    this.running = false;
    if (this.rafId) cancelAnimationFrame(this.rafId);
  }

  private frame = (now: number): void => {
    if (!this.running) return;
    this.rafId = requestAnimationFrame(this.frame);

    let frameTime = (now - this.last) / 1000;
    this.last = now;
    if (frameTime > 0.25) frameTime = 0.25; // tab was backgrounded; clamp

    this.acc += frameTime;
    let steps = 0;
    while (this.acc >= CONFIG.FIXED_DT && steps < CONFIG.MAX_STEPS_PER_FRAME) {
      this.step(CONFIG.FIXED_DT);
      this.acc -= CONFIG.FIXED_DT;
      steps++;
    }
    if (steps >= CONFIG.MAX_STEPS_PER_FRAME) this.acc = 0;

    this.draw();
  };
}
