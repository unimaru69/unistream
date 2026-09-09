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

## Lecture saccadée sur Linux : ce qui est écarté

Symptôme (iMac Fedora, AppImage release, 2026-09-08) : la lecture démarre
mais se met en pause ~1 s toutes les 1 à 2 s, en live comme en VOD, avec
une sévérité proportionnelle à la résolution — SD propre, HD occasionnel,
FHD systématique.

**Non résolu.** Ce qui est écarté, avec la preuve :

- **Le rendu logiciel de media_kit.** Le plugin natif annonce son chemin
  sur stderr, sans rebuild ni variable d'environnement :
  `media_kit: VideoOutput: H/W rendering with isolated EGL context…`
  (le cas ici) vs `S/W rendering.`, qui signifierait pas de contexte EGL
  et chaque image recopiée via un buffer RGBA 1080p sur le CPU — à
  vérifier alors côté pilotes hôte (`glxinfo | grep -i renderer` ≠
  `llvmpipe`).

- **Le décodage logiciel.** `top -H -p $(pgrep -f usr/bin/unistream)` :
  seule la colonne `TIME+` est fiable sur un `top -n 1` (les `%CPU` du
  premier passage sont des moyennes depuis le démarrage). Relevé : ~19 s
  de CPU pour tout le process sur 126 s de session, threads `av:h264` à
  4 s chacun. Rien ne sature, en FHD 5,8 Mbps.

- **Impeller.** Flutter active Impeller/GLES par défaut sur Linux, et le
  soupçon était que la texture externe de media_kit_video (frames rendues
  dans le contexte EGL du plugin, passées en EGLImage) y coûte trop cher.
  Faux, pour deux raisons : le switch `enable-impeller=false` est
  **ignoré** par l'embedder Linux de Flutter 3.41 — vérifié en le passant
  par l'environnement, `Using the Impeller rendering backend` continue de
  s'afficher — donc Skia n'est plus atteignable et le test qui semblait
  positif ne l'était pas ; et le lendemain matin, Impeller toujours actif
  et inchangé, le même flux FHD passait proprement.

Ce dernier point est le plus informatif : **le symptôme varie dans le
temps sans que rien ne change dans l'app.** Les deux observations
« ça coupe » / « ça passe » diffèrent par l'heure (21 h 48 un soir de
Ligue des champions vs 07 h 49) et par le contenu (match vs plan quasi
statique). Le badge de l'overlay affiche le débit *demandé*, pas le débit
*servi* — un panel Xtream en heure de pointe reste le suspect à mesurer.

### Mesurer plutôt que deviner

L'instrumentation est embarquée depuis le commit b3c63cf, dans
[`player_stall_diagnostics.dart`](../lib/screens/player/player_stall_diagnostics.dart).
À lancer pendant que ça coupe :

```bash
UNISTREAM_PLAYER_DIAG=1 ./UniStream-x86_64.AppImage 2>&1 | grep player-diag
```

Une ligne par seconde, tirée des compteurs de mpv :

- `for-cache=yes` avec `cache` qui tombe vers 0 et `speed` faible → le
  flux arrive trop lentement (réseau, ou serveur Xtream saturé) ;
- `dec-drop=+N` qui grimpe alors que `cache` reste sain → décodage ;
- `vo-delay=+N` qui grimpe et `vf-fps` très en dessous de `fps` → les
  images ne partent pas à l'écran.

Et en complément, hors app, sur l'URL du flux qui coupe (5,8 Mbps ≈
725 000 octets/s) :

```bash
curl -o /dev/null -w 'debit: %{speed_download} octets/s\n' --max-time 20 'URL_DU_FLUX'
```

### Deux pièges de méthode qui ont coûté des allers-retours

1. `VAR=x ./app` doit être **une seule** commande. `VAR=x` seul sur sa
   ligne n'est qu'une affectation de shell non exportée : le process fils
   ne voit rien, et le test paraît négatif sans avoir eu lieu.
2. Ne jamais valider un correctif sur un symptôme intermittent sans
   vérifier que le correctif est **actif** (ici : la ligne
   `Using the Impeller rendering backend` doit disparaître) et sans
   comparer à contenu et à heure comparables.
