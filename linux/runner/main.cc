#include <cstdio>
#include <cstdlib>
#include <cstring>

#include "my_application.h"

// Flutter defaults to the Impeller/GLES backend on Linux, and
// media_kit_video's video texture does not survive it: the plugin renders
// libmpv's frames in its own EGL context and hands Flutter the result as an
// EGLImage-backed external texture, and Impeller's external-texture path
// makes that so expensive that playback stalls for about a second, every
// second or two, in FHD (Fedora / Mesa, H/W rendering, CPU almost idle —
// the cost is entirely on the Flutter side). Skia plays the same stream
// cleanly, so pin Linux to Skia.
//
// The GTK embedder only accepts engine switches through the environment
// (FLUTTER_ENGINE_SWITCHES = count, FLUTTER_ENGINE_SWITCH_<N> = switch),
// which is why this lives here instead of in Dart: it has to be set before
// g_application_run() spins up the engine. Doing it in the runner rather
// than in the AppImage's AppRun also covers the tarball, the Flatpak and
// `flutter run -d linux`.
//
// Appends instead of overwriting — `flutter run` passes its own switches
// (VM service, Dart profiling) the same way — and stands aside if
// something already made an explicit choice about Impeller, so
// `flutter run -d linux --enable-impeller` still means what it says.
static void pin_linux_to_skia() {
  const char* count = getenv("FLUTTER_ENGINE_SWITCHES");
  int n = count != nullptr ? atoi(count) : 0;
  if (n < 0 || n > 64) {
    return;
  }
  char key[64];
  for (int i = 1; i <= n; i++) {
    snprintf(key, sizeof(key), "FLUTTER_ENGINE_SWITCH_%d", i);
    const char* value = getenv(key);
    if (value != nullptr && strstr(value, "enable-impeller") != nullptr) {
      return;
    }
  }
  snprintf(key, sizeof(key), "FLUTTER_ENGINE_SWITCH_%d", n + 1);
  setenv(key, "enable-impeller=false", 1);
  char new_count[16];
  snprintf(new_count, sizeof(new_count), "%d", n + 1);
  setenv("FLUTTER_ENGINE_SWITCHES", new_count, 1);
}

int main(int argc, char** argv) {
  pin_linux_to_skia();
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
