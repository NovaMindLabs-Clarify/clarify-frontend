{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();

    const loading = document.getElementById('app-loading');
    if (loading) {
      loading.style.opacity = '0';
      loading.addEventListener('transitionend', () => loading.remove());
    }
  },
});
