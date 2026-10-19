{{flutter_js}}
{{flutter_build_config}}

// Moves the loading bar in index.html as Flutter starts up.
const progress = window.splashProgress ?? (() => {});
progress(25, 55);

_flutter.loader.load({
  onEntrypointLoaded: async (engineInitializer) => {
    progress(60, 82);
    const appRunner = await engineInitializer.initializeEngine();
    // Stops at 85%: the app's own loading screen continues from there.
    progress(85, 85);
    await appRunner.runApp();
  },
});
