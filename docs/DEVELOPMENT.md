# Guide de Développement

## Prérequis

- **Flutter** >= 3.11.4 (stable channel)
- **Dart** >= 3.3
- **Xcode** (pour macOS/iOS)
- **Visual Studio** (pour Windows)

## Installation

```bash
git clone https://github.com/unimaru69/unistream.git
cd unistream
flutter pub get
```

## Génération de code

Le projet utilise Freezed et JSON Serializable pour les modèles :

```bash
# Générer une fois
flutter pub run build_runner build --delete-conflicting-outputs

# Générer en continu (pendant le développement)
flutter pub run build_runner watch
```

Les fichiers générés :
- `*.freezed.dart` — Classes immutables
- `*.g.dart` — Sérialisation JSON

## Localisation

Les fichiers ARB sont dans `lib/l10n/` :
- `app_fr.arb` — Français (langue principale)
- `app_en.arb` — Anglais

Après modification :
```bash
flutter gen-l10n
```

## Lancer l'app

```bash
flutter run -d macos          # macOS
flutter run -d windows        # Windows
flutter run -d linux           # Linux
flutter run -d <device_id>     # iOS simulateur
```

## Tests

```bash
# Tous les tests unitaires + widget
flutter test

# Un fichier spécifique
flutter test test/services/xtream_api_test.dart

# Tests d'intégration
flutter test integration_test/

# Analyse statique
flutter analyze
```

## Structure des dossiers

```
lib/
  core/                 Logger, couleurs, thème, storage keys, cache config
  models/               Freezed: Channel, VodItem, SeriesItem, Episode, Profile, etc.
  providers/            Riverpod: favorites, watchlist, collections, watch_progress, etc.
  services/             XtreamApi, SyncService, WatchProgress, ConnectivityService, EpgReminder
  screens/
    home/               HomeScreen + widgets (app bar, sidebar, stream list, etc.)
    player/             PlayerScreen + widgets (controls, tracks, overlays, etc.)
    epg/                EpgGridScreen + widgets (timeline, program rows, etc.)
    vod/                VodDetailScreen
    settings/           SettingsScreen + sections (cache, appearance, etc.)
    profiles/           ProfileSelectorScreen
  widgets/              Widgets partagés (skeleton, PIN dialog)
  l10n/                 Fichiers localisation générés
  utils/                Helpers (routes, snackbar, stream helpers, etc.)

test/                   Tests unitaires et widget (580+ tests)
integration_test/       Tests d'intégration (flows complets)
docs/                   Documentation (architecture, release)
```

## Conventions

- **Single quotes** pour les strings
- **Curly braces** obligatoires dans les if/else
- **Riverpod** pour le state management (avec codegen via `riverpod_generator`)
- **Freezed** pour les modèles de données immutables
- Imports organisés : dart → packages → relatifs

## CI/CD

GitHub Actions (`.github/workflows/`) :
- `analyze-and-test` : Ubuntu — lint + tests (toujours exécuté)
- `build-macos/windows/linux` : On-demand (tag `[build]` ou workflow dispatch)

## Lecture saccadée sur Linux : Impeller

**Résolu.** Symptôme : la lecture démarre mais se met en pause ~1 s toutes
les 1 à 2 s, en live comme en VOD, avec une sévérité proportionnelle à la
résolution (SD propre, HD occasionnel, FHD systématique).

Cause : Flutter active **Impeller/GLES par défaut sur Linux**, et la
texture vidéo de media_kit_video n'y survit pas. Le plugin rend les frames
de libmpv dans son propre contexte EGL et les passe à Flutter via une
texture externe adossée à un EGLImage ; le chemin external-texture
d'Impeller rend cette présentation assez coûteuse pour bloquer la lecture.
Skia joue le même flux proprement.

Correctif : [`linux/runner/main.cc`](../linux/runner/main.cc) pousse
`enable-impeller=false` dans les engine switches avant le démarrage du
moteur (le point d'entrée le plus haut qui couvre tarball, AppImage,
Flatpak et `flutter run -d linux`). Le runner s'abstient si un switch
`enable-impeller` est déjà présent, donc pour retester Impeller il suffit
de le demander explicitement —

```bash
FLUTTER_ENGINE_SWITCHES=1 FLUTTER_ENGINE_SWITCH_1=enable-impeller=true ./UniStream-x86_64.AppImage
```

### Ce que le diagnostic a coûté, et comment aller plus vite

Trois mécanismes produisent exactement la même saccade et rien ne les
distingue de l'extérieur. Dans l'ordre de coût de vérification :

1. **Le chemin de rendu de media_kit**, que le plugin natif annonce
   lui-même sur stderr — sans rebuild ni variable d'environnement :
   - `media_kit: VideoOutput: H/W rendering with isolated EGL context…`
   - `media_kit: VideoOutput: S/W rendering.` → pas de contexte EGL, chaque
     image recopiée via un buffer RGBA 1080p sur le CPU. Vérifier les
     pilotes GPU de l'hôte (`glxinfo | grep -i renderer` ≠ `llvmpipe`).

2. **Le CPU**, via `top -H -p $(pgrep -f usr/bin/unistream)`. Seule la
   colonne `TIME+` est fiable sur un `top -n 1` (les `%CPU` du premier
   passage sont des moyennes depuis le démarrage). Des threads `av:h264`
   à quelques secondes de CPU sur deux minutes de session excluent le
   décodage logiciel.

3. **Les compteurs internes de mpv**, via
   [`player_stall_diagnostics.dart`](../lib/screens/player/player_stall_diagnostics.dart)
   — une ligne par seconde sur stderr :

   ```bash
   UNISTREAM_PLAYER_DIAG=1 ./UniStream-x86_64.AppImage
   ```

   - `for-cache=yes` avec `cache` qui tombe vers 0 et `speed` faible → le
     flux arrive trop lentement (réseau, ou serveur Xtream).
   - `dec-drop=+N` qui grimpe alors que `cache` reste sain → décodage.
   - `vo-delay=+N` qui grimpe et `vf-fps` très en dessous de `fps` → les
     images ne partent pas à l'écran : c'était le cas ici.

Attention au piège qui a fait perdre un aller-retour : `VAR=x ./app` doit
être **une seule** commande. `VAR=x` sur sa propre ligne ne fait qu'une
affectation de shell, non exportée — le process fils ne voit rien. La
ligne `Using the Impeller rendering backend` dans la sortie dit si le
switch a bien été pris.
