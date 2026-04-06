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
