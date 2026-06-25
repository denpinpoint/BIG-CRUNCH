import type { Vec2 } from '../utils/math';

interface JoystickState {
  active: boolean;
  pointerId: number;
  originX: number;
  originY: number;
  curX: number;
  curY: number;
  dx: number; // normalized -1..1
  dy: number;
}

/**
 * Unified input: keyboard (WASD / ZQSD / arrows), optional mouse-to-point, and
 * a mobile virtual joystick. Layout-tolerant key handling (QWERTY + AZERTY) per
 * CrazyGames restricted-key guidance; Escape is never bound (it exits the
 * platform's fullscreen).
 */
export class Input {
  private keys = new Set<string>();
  private canvas: HTMLCanvasElement;

  // Mouse steering (desktop, optional): hold to move toward the cursor.
  private mouseSteer = false;
  private mouseX = 0;
  private mouseY = 0;
  private pointerType: string = 'mouse';

  readonly joystick: JoystickState = {
    active: false, pointerId: -1, originX: 0, originY: 0,
    curX: 0, curY: 0, dx: 0, dy: 0,
  };

  /** Fired on the very first user gesture (used to resume AudioContext). */
  onFirstGesture: (() => void) | null = null;
  private firstGestureDone = false;

  /** Optional hook so the UI can react to the pause key. */
  onPauseKey: (() => void) | null = null;

  constructor(canvas: HTMLCanvasElement) {
    this.canvas = canvas;
    window.addEventListener('keydown', this.onKeyDown, { passive: false });
    window.addEventListener('keyup', this.onKeyUp);
    window.addEventListener('blur', this.onBlur);
    canvas.addEventListener('pointerdown', this.onPointerDown);
    canvas.addEventListener('pointermove', this.onPointerMove);
    window.addEventListener('pointerup', this.onPointerUp);
    window.addEventListener('pointercancel', this.onPointerUp);
  }

  private fireFirstGesture(): void {
    if (this.firstGestureDone) return;
    this.firstGestureDone = true;
    this.onFirstGesture?.();
  }

  private onKeyDown = (e: KeyboardEvent): void => {
    this.fireFirstGesture();
    const code = e.code;
    if (
      code === 'ArrowUp' || code === 'ArrowDown' ||
      code === 'ArrowLeft' || code === 'ArrowRight' || code === 'Space'
    ) {
      e.preventDefault();
    }
    if (code === 'KeyP') this.onPauseKey?.();
    this.keys.add(code);
  };

  private onKeyUp = (e: KeyboardEvent): void => {
    this.keys.delete(e.code);
  };

  private onBlur = (): void => {
    this.keys.clear();
    this.mouseSteer = false;
    this.joystick.active = false;
  };

  private onPointerDown = (e: PointerEvent): void => {
    this.fireFirstGesture();
    this.pointerType = e.pointerType;
    const rect = this.canvas.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    if (e.pointerType === 'touch') {
      // Begin a floating joystick wherever the finger lands.
      const j = this.joystick;
      j.active = true;
      j.pointerId = e.pointerId;
      j.originX = x; j.originY = y;
      j.curX = x; j.curY = y;
      j.dx = 0; j.dy = 0;
    } else {
      this.mouseSteer = true;
      this.mouseX = x;
      this.mouseY = y;
    }
  };

  private onPointerMove = (e: PointerEvent): void => {
    const rect = this.canvas.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    if (e.pointerType === 'touch' && this.joystick.active && e.pointerId === this.joystick.pointerId) {
      const j = this.joystick;
      j.curX = x; j.curY = y;
      const dx = x - j.originX;
      const dy = y - j.originY;
      const maxR = 70;
      const len = Math.hypot(dx, dy) || 1;
      const clamped = Math.min(len, maxR);
      j.dx = (dx / len) * (clamped / maxR);
      j.dy = (dy / len) * (clamped / maxR);
    } else if (this.mouseSteer) {
      this.mouseX = x;
      this.mouseY = y;
    }
  };

  private onPointerUp = (e: PointerEvent): void => {
    if (e.pointerId === this.joystick.pointerId) {
      this.joystick.active = false;
      this.joystick.dx = 0;
      this.joystick.dy = 0;
    }
    if (e.pointerType !== 'touch') this.mouseSteer = false;
  };

  private has(...codes: string[]): boolean {
    for (const c of codes) if (this.keys.has(c)) return true;
    return false;
  }

  /**
   * Write the desired movement direction (magnitude 0..1) into `out`.
   * Priority: keyboard → joystick → mouse-steer. `viewCenterX/Y` are used to
   * derive a direction from the mouse cursor.
   */
  getMoveVector(out: Vec2, viewCenterX: number, viewCenterY: number): void {
    let x = 0;
    let y = 0;
    if (this.has('KeyA', 'KeyQ', 'ArrowLeft')) x -= 1;
    if (this.has('KeyD', 'ArrowRight')) x += 1;
    if (this.has('KeyW', 'KeyZ', 'ArrowUp')) y -= 1;
    if (this.has('KeyS', 'ArrowDown')) y += 1;

    if (x !== 0 || y !== 0) {
      const len = Math.hypot(x, y);
      out.x = x / len;
      out.y = y / len;
      return;
    }

    if (this.joystick.active && (this.joystick.dx !== 0 || this.joystick.dy !== 0)) {
      out.x = this.joystick.dx;
      out.y = this.joystick.dy;
      return;
    }

    if (this.mouseSteer && this.pointerType !== 'touch') {
      const dx = this.mouseX - viewCenterX;
      const dy = this.mouseY - viewCenterY;
      const len = Math.hypot(dx, dy);
      if (len > 14) {
        const scale = Math.min(1, len / 160);
        out.x = (dx / len) * scale;
        out.y = (dy / len) * scale;
        return;
      }
    }

    out.x = 0;
    out.y = 0;
  }

  destroy(): void {
    window.removeEventListener('keydown', this.onKeyDown);
    window.removeEventListener('keyup', this.onKeyUp);
    window.removeEventListener('blur', this.onBlur);
    this.canvas.removeEventListener('pointerdown', this.onPointerDown);
    this.canvas.removeEventListener('pointermove', this.onPointerMove);
    window.removeEventListener('pointerup', this.onPointerUp);
    window.removeEventListener('pointercancel', this.onPointerUp);
  }
}
