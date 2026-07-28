{{flutter_js}}
{{flutter_build_config}}

const _splashStart = Date.now();
const _MIN_SPLASH_MS = 1000; // на быстрых устройствах engine грузится за
  // доли секунды — без минимума заглушка мелькает и выглядит как глитч,
  // а не как превью бренда перед входом.

_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();

    const hideSplash = () => {
      const loading = document.getElementById('app-loading');
      if (loading) {
        loading.style.opacity = '0';
        loading.addEventListener('transitionend', () => loading.remove());
      }
    };

    const elapsed = Date.now() - _splashStart;
    const remaining = _MIN_SPLASH_MS - elapsed;
    if (remaining > 0) {
      setTimeout(hideSplash, remaining);
    } else {
      hideSplash();
    }
  },
});
