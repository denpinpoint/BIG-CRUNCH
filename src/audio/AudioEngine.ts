/**
 * Fully synthesized audio — no copyrighted or external assets. A layered
 * ambient pad for music, plus procedural SFX whose pitch scales with the size
 * of what you devour. Respects master/music/sfx volumes and a global mute, and
 * exposes resume() for the iOS AudioContext-interrupt requirement.
 */
export class AudioEngine {
  private ctx: AudioContext | null = null;
  private masterGain: GainNode | null = null;
  private musicGain: GainNode | null = null;
  private sfxGain: GainNode | null = null;
  private noiseBuffer: AudioBuffer | null = null;

  private musicOn = false;
  private bellTimer: number | null = null;

  private vol = { master: 0.8, music: 0.6, sfx: 0.9, muted: false };
  private lastSfxTime = 0;
  private sfxCount = 0;

  private ensure(): boolean {
    if (this.ctx) return true;
    try {
      const Ctor = window.AudioContext || (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
      if (!Ctor) return false;
      const ctx = new Ctor();
      this.ctx = ctx;
      this.masterGain = ctx.createGain();
      this.musicGain = ctx.createGain();
      this.sfxGain = ctx.createGain();
      this.musicGain.connect(this.masterGain);
      this.sfxGain.connect(this.masterGain);
      this.masterGain.connect(ctx.destination);
      this.applyVolumes();

      // One-shot white-noise buffer reused for explosion textures.
      const len = Math.floor(ctx.sampleRate * 0.6);
      const buf = ctx.createBuffer(1, len, ctx.sampleRate);
      const data = buf.getChannelData(0);
      for (let i = 0; i < len; i++) data[i] = Math.random() * 2 - 1;
      this.noiseBuffer = buf;
      return true;
    } catch {
      return false;
    }
  }

  /** Resume after a user gesture (also satisfies iOS interrupt handling). */
  resume(): void {
    if (!this.ensure()) return;
    if (this.ctx && this.ctx.state === 'suspended') void this.ctx.resume();
  }

  setVolumes(master: number, music: number, sfx: number, muted: boolean): void {
    this.vol = { master, music, sfx, muted };
    this.applyVolumes();
  }

  private applyVolumes(): void {
    if (!this.ctx || !this.masterGain || !this.musicGain || !this.sfxGain) return;
    const t = this.ctx.currentTime;
    const m = this.vol.muted ? 0 : this.vol.master;
    this.masterGain.gain.setTargetAtTime(m, t, 0.05);
    this.musicGain.gain.setTargetAtTime(this.vol.music, t, 0.05);
    this.sfxGain.gain.setTargetAtTime(this.vol.sfx, t, 0.05);
  }

  startMusic(): void {
    if (this.musicOn || !this.ensure() || !this.ctx || !this.musicGain) return;
    this.musicOn = true;
    const ctx = this.ctx;
    const now = ctx.currentTime;

    // Layered drone pad: detuned low oscillators through a soft lowpass.
    const padGain = ctx.createGain();
    padGain.gain.value = 0.16;
    const filter = ctx.createBiquadFilter();
    filter.type = 'lowpass';
    filter.frequency.value = 520;
    filter.Q.value = 0.6;
    padGain.connect(filter);
    filter.connect(this.musicGain);

    const freqs = [55, 82.4, 110, 164.8];
    for (let i = 0; i < freqs.length; i++) {
      const osc = ctx.createOscillator();
      osc.type = i % 2 === 0 ? 'sawtooth' : 'triangle';
      osc.frequency.value = freqs[i]!;
      osc.detune.value = (i - 1.5) * 6;
      osc.connect(padGain);
      osc.start(now);
    }
    // Slow filter sweep LFO for movement.
    const lfo = ctx.createOscillator();
    lfo.frequency.value = 0.05;
    const lfoGain = ctx.createGain();
    lfoGain.gain.value = 220;
    lfo.connect(lfoGain);
    lfoGain.connect(filter.frequency);
    lfo.start(now);

    this.scheduleBell();
  }

  /** Occasional gentle pentatonic bell — cosmic ambience. */
  private scheduleBell(): void {
    if (!this.musicOn) return;
    if (this.bellTimer !== null) clearTimeout(this.bellTimer);
    const delay = 2600 + Math.random() * 4200;
    this.bellTimer = window.setTimeout(() => {
      if (this.ctx && this.ctx.state === 'running') {
        const scale = [220, 261.6, 329.6, 392, 440, 523.2];
        const f = scale[Math.floor(Math.random() * scale.length)]!;
        this.bell(f * (Math.random() < 0.3 ? 2 : 1));
      }
      this.scheduleBell();
    }, delay);
  }

  private bell(freq: number): void {
    if (!this.ctx || !this.musicGain) return;
    const ctx = this.ctx;
    const t = ctx.currentTime;
    const osc = ctx.createOscillator();
    osc.type = 'sine';
    osc.frequency.value = freq;
    const g = ctx.createGain();
    g.gain.setValueAtTime(0, t);
    g.gain.linearRampToValueAtTime(0.12, t + 0.02);
    g.gain.exponentialRampToValueAtTime(0.001, t + 2.4);
    osc.connect(g);
    g.connect(this.musicGain);
    osc.start(t);
    osc.stop(t + 2.5);
  }

  /** Throttle to avoid stacking too many voices on rapid consumption. */
  private canPlaySfx(): boolean {
    if (!this.ctx) return false;
    const now = this.ctx.currentTime;
    if (now - this.lastSfxTime > 0.05) {
      this.lastSfxTime = now;
      this.sfxCount = 0;
    }
    if (this.sfxCount > 6) return false;
    this.sfxCount++;
    return true;
  }

  /** Consume blip — pitch falls as bodies get bigger; big ones add a boom. */
  consume(sizeFactor: number): void {
    if (!this.ensure() || !this.ctx || !this.sfxGain) return;
    if (!this.canPlaySfx()) return;
    const ctx = this.ctx;
    const t = ctx.currentTime;
    const baseFreq = 880 / (1 + sizeFactor * 4);
    const osc = ctx.createOscillator();
    osc.type = 'triangle';
    osc.frequency.setValueAtTime(baseFreq * 1.6, t);
    osc.frequency.exponentialRampToValueAtTime(baseFreq * 0.7, t + 0.12);
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(0.22, t + 0.01);
    g.gain.exponentialRampToValueAtTime(0.0001, t + 0.16);
    osc.connect(g);
    g.connect(this.sfxGain);
    osc.start(t);
    osc.stop(t + 0.18);

    if (sizeFactor > 0.35 && this.noiseBuffer) {
      const src = ctx.createBufferSource();
      src.buffer = this.noiseBuffer;
      const ng = ctx.createGain();
      const nf = ctx.createBiquadFilter();
      nf.type = 'lowpass';
      nf.frequency.value = 400 + (1 - sizeFactor) * 600;
      ng.gain.setValueAtTime(0.18 * sizeFactor, t);
      ng.gain.exponentialRampToValueAtTime(0.0001, t + 0.3 + sizeFactor * 0.3);
      src.connect(nf);
      nf.connect(ng);
      ng.connect(this.sfxGain);
      src.start(t);
      src.stop(t + 0.7);
    }
  }

  private blip(freq: number, dur: number, type: OscillatorType, gain: number): void {
    if (!this.ensure() || !this.ctx || !this.sfxGain) return;
    const ctx = this.ctx;
    const t = ctx.currentTime;
    const osc = ctx.createOscillator();
    osc.type = type;
    osc.frequency.value = freq;
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(gain, t + 0.01);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    osc.connect(g);
    g.connect(this.sfxGain);
    osc.start(t);
    osc.stop(t + dur + 0.02);
  }

  upgrade(): void {
    this.blip(660, 0.12, 'square', 0.14);
    setTimeout(() => this.blip(990, 0.14, 'square', 0.12), 60);
  }
  click(): void {
    this.blip(440, 0.05, 'sine', 0.1);
  }
  achievement(): void {
    this.blip(587, 0.14, 'sine', 0.16);
    setTimeout(() => this.blip(880, 0.2, 'sine', 0.16), 110);
  }
  event(): void {
    if (!this.ensure() || !this.ctx || !this.sfxGain) return;
    const ctx = this.ctx;
    const t = ctx.currentTime;
    const osc = ctx.createOscillator();
    osc.type = 'sawtooth';
    osc.frequency.setValueAtTime(110, t);
    osc.frequency.exponentialRampToValueAtTime(440, t + 0.6);
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(0.18, t + 0.1);
    g.gain.exponentialRampToValueAtTime(0.0001, t + 0.8);
    osc.connect(g);
    g.connect(this.sfxGain);
    osc.start(t);
    osc.stop(t + 0.85);
  }
  prestige(): void {
    if (!this.ensure() || !this.ctx || !this.sfxGain) return;
    const ctx = this.ctx;
    const t = ctx.currentTime;
    const notes = [130.8, 196, 261.6, 392, 523.2];
    notes.forEach((f, i) => {
      const osc = ctx.createOscillator();
      osc.type = 'sine';
      osc.frequency.value = f;
      const g = ctx.createGain();
      const tt = t + i * 0.12;
      g.gain.setValueAtTime(0.0001, tt);
      g.gain.exponentialRampToValueAtTime(0.16, tt + 0.03);
      g.gain.exponentialRampToValueAtTime(0.0001, tt + 1.2);
      osc.connect(g);
      g.connect(this.sfxGain!);
      osc.start(tt);
      osc.stop(tt + 1.3);
    });
  }
}
