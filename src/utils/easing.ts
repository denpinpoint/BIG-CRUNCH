/** Easing curves for animation & game feel. All take t in [0,1]. */

export function easeOutCubic(t: number): number {
  const f = t - 1;
  return f * f * f + 1;
}

export function easeInCubic(t: number): number {
  return t * t * t;
}

export function easeOutBack(t: number): number {
  const c1 = 1.70158;
  const c3 = c1 + 1;
  const f = t - 1;
  return 1 + c3 * f * f * f + c1 * f * f;
}

export function easeOutElastic(t: number): number {
  const c4 = (2 * Math.PI) / 3;
  if (t === 0) return 0;
  if (t === 1) return 1;
  return Math.pow(2, -10 * t) * Math.sin((t * 10 - 0.75) * c4) + 1;
}

export function easeInOutQuad(t: number): number {
  return t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
}

export function easeOutQuart(t: number): number {
  return 1 - Math.pow(1 - t, 4);
}
