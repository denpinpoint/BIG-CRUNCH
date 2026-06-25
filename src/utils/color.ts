/** Minimal hex-colour helpers for procedural sprite generation. */

function parse(hex: string): [number, number, number] {
  let h = hex.replace('#', '');
  if (h.length === 3) h = h[0]! + h[0]! + h[1]! + h[1]! + h[2]! + h[2]!;
  const n = parseInt(h, 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

export function rgba(hex: string, alpha: number): string {
  const [r, g, b] = parse(hex);
  return `rgba(${r},${g},${b},${alpha})`;
}

export function lighten(hex: string, amt: number): string {
  const [r, g, b] = parse(hex);
  const l = (c: number) => Math.round(c + (255 - c) * amt);
  return `rgb(${l(r)},${l(g)},${l(b)})`;
}

export function darken(hex: string, amt: number): string {
  const [r, g, b] = parse(hex);
  const d = (c: number) => Math.round(c * (1 - amt));
  return `rgb(${d(r)},${d(g)},${d(b)})`;
}
