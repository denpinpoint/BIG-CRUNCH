import './styles.css';
import './ui.css';
import { Game } from './core/Game';
import { GameLoop } from './core/GameLoop';
import { UI } from './ui/UI';

/**
 * Entry point. Boots straight into gameplay (CrazyGames "land directly in
 * gameplay" requirement) — the only overlays a new player may see are the
 * dismissable offline-rewards modal and the auto-fading controls hint.
 */
async function main(): Promise<void> {
  const canvas = document.getElementById('game-canvas') as HTMLCanvasElement | null;
  const uiRoot = document.getElementById('ui-root');
  const boot = document.getElementById('boot-screen');
  if (!canvas || !uiRoot) throw new Error('Missing required DOM nodes');

  const bootFill = boot?.querySelector('.boot-bar-fill') as HTMLElement | null;
  if (bootFill) bootFill.style.width = '35%';

  const game = new Game(canvas);
  const ui = new UI(uiRoot, game);

  await game.init();
  if (bootFill) bootFill.style.width = '100%';

  // Reveal the world.
  setTimeout(() => boot?.classList.add('hidden'), 250);
  setTimeout(() => boot?.remove(), 1000);

  if (game.offlineReport) ui.showOffline(game.offlineReport);

  const loop = new GameLoop(
    (dt) => game.step(dt),
    () => {
      game.draw();
      ui.update();
    },
  );
  loop.start();

  // Responsive: handle viewport changes (CrazyGames iframe resizes, rotation).
  let resizeRaf = 0;
  const onResize = (): void => {
    if (resizeRaf) cancelAnimationFrame(resizeRaf);
    resizeRaf = requestAnimationFrame(() => game.resize());
  };
  window.addEventListener('resize', onResize);
  window.addEventListener('orientationchange', onResize);

  // iOS: revive a suspended AudioContext on a user gesture (CrazyGames §3.4).
  document.addEventListener('touchend', () => game.audio.resume(), { passive: true });
  window.addEventListener('pointerdown', () => game.audio.resume(), { once: false, passive: true });

  // Persist on background / unload so progress is never lost.
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'hidden') game.saveNow();
  });
  window.addEventListener('pagehide', () => game.saveNow());
  window.addEventListener('beforeunload', () => game.saveNow());
}

void main().catch((err) => {
  // Surface fatal boot errors instead of a silent black screen.
  console.error(err);
  const boot = document.getElementById('boot-screen');
  if (boot) {
    boot.innerHTML =
      '<div style="color:#ff8a9b;font-family:sans-serif;text-align:center;padding:20px;">' +
      'Something went wrong starting the game.<br/>Please reload the page.</div>';
  }
});
