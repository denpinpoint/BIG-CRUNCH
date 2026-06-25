/**
 * Number formatting for cosmic-scale values. The player's mass grows across
 * many orders of magnitude, so we use scientific suffixes up to absurd scales.
 */

const SUFFIXES = [
  '',
  'K',
  'M',
  'B',
  'T',
  'Qa',
  'Qi',
  'Sx',
  'Sp',
  'Oc',
  'No',
  'Dc',
  'UDc',
  'DDc',
  'TDc',
  'QaDc',
  'QiDc',
];

/** Format a large number compactly, e.g. 1234 -> "1.23K", 5.2e9 -> "5.20B". */
export function formatNumber(n: number): string {
  if (!isFinite(n)) return '∞';
  if (n < 0) return '-' + formatNumber(-n);
  if (n < 1) return n.toFixed(2);
  if (n < 1000) {
    // Show up to 1 decimal for small numbers, but integers stay clean.
    return n < 10 && n % 1 !== 0 ? n.toFixed(1) : Math.floor(n).toString();
  }
  const tier = Math.floor(Math.log10(n) / 3);
  if (tier < SUFFIXES.length) {
    const scaled = n / Math.pow(1000, tier);
    return scaled.toFixed(2) + SUFFIXES[tier];
  }
  // Beyond named suffixes, fall back to scientific notation.
  return n.toExponential(2).replace('e+', 'e');
}

/** Format a per-second rate. */
export function formatRate(n: number): string {
  return formatNumber(n) + '/s';
}

/** Format a duration in seconds to a compact human string. */
export function formatTime(seconds: number): string {
  seconds = Math.max(0, Math.floor(seconds));
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  if (h > 0) return `${h}h ${m}m`;
  if (m > 0) return `${m}m ${s}s`;
  return `${s}s`;
}

/** Format a short countdown like 0:45 used on event timers. */
export function formatClock(seconds: number): string {
  seconds = Math.max(0, Math.ceil(seconds));
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${m}:${s.toString().padStart(2, '0')}`;
}
